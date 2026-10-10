"""Filters: RBJ-cookbook biquads (static and block-time-varying), one-pole, TPT state-variable."""
from __future__ import annotations

import math

import numpy as np
from scipy.signal import lfilter

from .core import SR, as_array

_BLOCK = 32


def biquad_coefs(kind: str, f: float, q: float = 0.707, gain_db: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    f = min(max(f, 5.0), SR * 0.49)
    w0 = 2 * math.pi * f / SR
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2 * max(q, 1e-3))
    amp = 10 ** (gain_db / 40)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bp":  # constant 0 dB peak gain
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "notch":
        b = [1.0, -2 * cw, 1.0]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * amp, -2 * cw, 1 - alpha * amp]
        a = [1 + alpha / amp, -2 * cw, 1 - alpha / amp]
    elif kind in ("lowshelf", "highshelf"):
        sq = 2 * math.sqrt(amp) * alpha
        sgn = 1 if kind == "lowshelf" else -1
        b = [amp * ((amp + 1) - sgn * (amp - 1) * cw + sq),
             sgn * 2 * amp * ((amp - 1) - sgn * (amp + 1) * cw),
             amp * ((amp + 1) - sgn * (amp - 1) * cw - sq)]
        a = [(amp + 1) + sgn * (amp - 1) * cw + sq,
             -sgn * 2 * ((amp - 1) + sgn * (amp + 1) * cw),
             (amp + 1) + sgn * (amp - 1) * cw - sq]
    else:
        raise ValueError(kind)
    b = np.array(b) / a[0]
    a = np.array(a) / a[0]
    return b, a


def _apply(x: np.ndarray, b: np.ndarray, a: np.ndarray) -> np.ndarray:
    return lfilter(b, a, x, axis=0)


def biquad(x: np.ndarray, kind: str, f: float, q: float = 0.707, gain_db: float = 0.0) -> np.ndarray:
    b, a = biquad_coefs(kind, f, q, gain_db)
    return _apply(x, b, a)


def lp(x: np.ndarray, f: float, q: float = 0.707) -> np.ndarray:
    return biquad(x, "lp", f, q)


def hp(x: np.ndarray, f: float, q: float = 0.707) -> np.ndarray:
    return biquad(x, "hp", f, q)


def bp(x: np.ndarray, f: float, q: float = 1.0) -> np.ndarray:
    return biquad(x, "bp", f, q)


def peak(x: np.ndarray, f: float, gain_db: float, q: float = 1.0) -> np.ndarray:
    return biquad(x, "peak", f, q, gain_db)


def lp24(x: np.ndarray, f: float, q: float = 0.707) -> np.ndarray:
    return lp(lp(x, f, 0.54), f, q * 1.3)


def biquad_tv(x: np.ndarray, kind: str, freq: float | np.ndarray, q: float | np.ndarray = 0.707,
              gain_db: float = 0.0) -> np.ndarray:
    """Time-varying biquad (cutoff/Q per sample, updated every 32 samples, DF2T state carried).

    High Q gives the classic resonant sweep. Works on mono or (n, 2) stereo arrays.
    """
    n = x.shape[0]
    fa = as_array(freq, n)
    qa = as_array(q, n)
    y = np.empty_like(x)
    zi = np.zeros((2,) + x.shape[1:])
    for s in range(0, n, _BLOCK):
        e = min(n, s + _BLOCK)
        b, a = biquad_coefs(kind, float(fa[s]), float(qa[s]), gain_db)
        y[s:e], zi = lfilter(b, a, x[s:e], axis=0, zi=zi)
    return y


def resonant_lp(x: np.ndarray, freq: float | np.ndarray, resonance: float = 0.5) -> np.ndarray:
    """Resonant low-pass (resonance 0..1 maps to Q 0.7..12), time-varying cutoff allowed."""
    q = 0.707 + resonance ** 2 * 11.3
    return biquad_tv(x, "lp", freq, q)


def one_pole_lp(x: np.ndarray, f: float) -> np.ndarray:
    c = math.exp(-2 * math.pi * f / SR)
    return lfilter([1 - c], [1, -c], x, axis=0)


def one_pole_hp(x: np.ndarray, f: float) -> np.ndarray:
    return x - one_pole_lp(x, f)


def svf(x: np.ndarray, freq: float | np.ndarray, res: float = 0.3, mode: str = "lp") -> np.ndarray:
    """Zavalishin TPT state-variable filter, per-sample modulation (mono, short sounds only:
    it is a Python loop). mode: lp/bp/hp/notch. res 0..1."""
    n = x.shape[0]
    fa = as_array(freq, n)
    k = 2.0 - 2.0 * min(max(res, 0.0), 0.995)
    g_all = np.tan(np.pi * np.clip(fa, 10, SR * 0.45) / SR)
    ic1 = ic2 = 0.0
    out = np.empty(n)
    xs = x.tolist()
    gs = g_all.tolist()
    for i in range(n):
        g = gs[i]
        a1 = 1.0 / (1.0 + g * (g + k))
        v3 = xs[i] - ic2
        v1 = a1 * ic1 + g * a1 * v3
        v2 = ic2 + g * v1
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        if mode == "lp":
            out[i] = v2
        elif mode == "bp":
            out[i] = v1
        elif mode == "hp":
            out[i] = xs[i] - k * v1 - v2
        else:
            out[i] = xs[i] - k * v1
    return out


def formant(x: np.ndarray, vowel_from: str, vowel_to: str | None = None, q: float = 8.0) -> np.ndarray:
    """Parallel band-pass formant bank, optionally gliding between two vowels."""
    table = {
        "a": (800, 1150, 2900), "e": (400, 1700, 2600), "i": (300, 2200, 3000),
        "o": (450, 800, 2830), "u": (325, 700, 2530), "uh": (600, 1040, 2250),
    }
    f0 = np.array(table[vowel_from], dtype=float)
    f1 = np.array(table[vowel_to or vowel_from], dtype=float)
    n = x.shape[0]
    ramp = np.linspace(0, 1, n)
    out = np.zeros_like(x)
    for i, g in enumerate((1.0, 0.6, 0.3)):
        out += g * biquad_tv(x, "bp", f0[i] + (f1[i] - f0[i]) * ramp, q)
    return out
