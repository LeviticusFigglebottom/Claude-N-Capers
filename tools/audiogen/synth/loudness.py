"""ITU-R BS.1770-4 loudness (K-weighted LUFS: momentary, short-term, integrated) and true peak."""
from __future__ import annotations

import numpy as np
from scipy.signal import lfilter, resample_poly

from .core import SR

# K-weighting coefficients at 48 kHz (BS.1770-4 Annex 1)
_PRE_B = [1.53512485958697, -2.69169618940638, 1.19839281085285]
_PRE_A = [1.0, -1.69065929318241, 0.73248077421585]
_RLB_B = [1.0, -2.0, 1.0]
_RLB_A = [1.0, -1.99004745483398, 0.99007225036621]


def _kweight(x: np.ndarray) -> np.ndarray:
    x2 = x[:, None] if x.ndim == 1 else x
    return lfilter(_RLB_B, _RLB_A, lfilter(_PRE_B, _PRE_A, x2, axis=0), axis=0)


def _block_power(y: np.ndarray, win: int, hop: int) -> np.ndarray:
    """Mean-square per block summed over channels (L/R weights 1.0)."""
    n = y.shape[0]
    if n < win:
        y = np.pad(y, ((0, win - n), (0, 0)))
        n = win
    cs = np.concatenate([np.zeros((1, y.shape[1])), np.cumsum(y ** 2, axis=0)])
    starts = np.arange(0, n - win + 1, hop)
    return ((cs[starts + win] - cs[starts]) / win).sum(axis=1)


def _lufs(p: np.ndarray | float) -> np.ndarray | float:
    return -0.691 + 10 * np.log10(np.maximum(p, 1e-15))


def integrated(x: np.ndarray) -> float:
    y = _kweight(x)
    p = _block_power(y, int(0.4 * SR), int(0.1 * SR))
    lk = _lufs(p)
    p = p[lk > -70]
    if p.size == 0:
        return -120.0
    rel = _lufs(np.mean(p)) - 10
    p2 = p[_lufs(p) > rel]
    return float(_lufs(np.mean(p2))) if p2.size else -120.0


def short_term_max(x: np.ndarray, window_s: float = 3.0) -> float:
    """Max short-term loudness. For sounds shorter than the window the window shrinks to the
    sound length (min 400 ms = momentary) so one-shots are measured on their own energy."""
    y = _kweight(x)
    win = int(min(window_s, max(0.4, x.shape[0] / SR)) * SR)
    p = _block_power(y, win, int(0.05 * SR))
    return float(np.max(_lufs(p)))


def momentary_max(x: np.ndarray) -> float:
    return short_term_max(x, 0.4)


def true_peak_db(x: np.ndarray) -> float:
    """4x oversampled peak (BS.1770 Annex 2 style, polyphase FIR interpolation)."""
    x2 = x[:, None] if x.ndim == 1 else x
    up = resample_poly(x2, 4, 1, axis=0)
    pk = max(float(np.max(np.abs(up))), float(np.max(np.abs(x2))))
    return 20 * np.log10(max(pk, 1e-12))


def normalize(x: np.ndarray, target_lufs: float, mode: str = "short", ceiling_dbtp: float = -1.0,
              limiter_max_db: float = 6.0) -> np.ndarray:
    """Gain to target loudness (mode 'short' = max short-term, 'integrated'), then keep true peak
    under the ceiling: look-ahead limiting for up to `limiter_max_db` of reduction, then a final
    static trim if anything still exceeds."""
    from . import fx

    cur = short_term_max(x) if mode == "short" else integrated(x)
    y = x * 10 ** ((target_lufs - cur) / 20)
    ceil_lin = 10 ** ((ceiling_dbtp - 0.3) / 20)
    for _ in range(3):
        tp = true_peak_db(y)
        if tp <= ceiling_dbtp:
            break
        excess = tp - ceiling_dbtp
        if excess <= limiter_max_db:
            y = fx.limiter(y, ceil_lin)
        else:
            y = y * 10 ** (-(excess - limiter_max_db) / 20)
            y = fx.limiter(y, ceil_lin)
    tp = true_peak_db(y)
    if tp > ceiling_dbtp:
        y = y * 10 ** ((ceiling_dbtp - tp - 0.05) / 20)
    return y
