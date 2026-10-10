"""Effects: waveshaping, delay, generated-IR convolution reverb, pan, doppler, dynamics."""
from __future__ import annotations

import math

import numpy as np
from scipy.ndimage import maximum_filter1d, minimum_filter1d, uniform_filter1d
from scipy.signal import fftconvolve, lfilter

from . import filters
from .core import SR, nsamp, seed_for, stereo

# ---------------------------------------------------------------- waveshaping


def drive(x: np.ndarray, amount: float) -> np.ndarray:
    """tanh saturation normalised so small signals keep unity gain."""
    g = max(amount, 1e-3)
    return np.tanh(x * g) / math.tanh(g) if g > 1 else np.tanh(x * g) / g


def hard_clip(x: np.ndarray, level: float = 1.0) -> np.ndarray:
    return np.clip(x, -level, level)


def fold(x: np.ndarray, amount: float) -> np.ndarray:
    """Sine wavefolder."""
    return np.sin(x * amount * math.pi / 2)


def asym(x: np.ndarray, bias: float = 0.2) -> np.ndarray:
    y = np.tanh(x + bias) - math.tanh(bias)
    return y - np.mean(y)


def bitcrush(x: np.ndarray, bits: int = 8, hold: int = 1) -> np.ndarray:
    q = 2 ** (bits - 1)
    y = np.round(x * q) / q
    if hold > 1:
        y = np.repeat(y[::hold], hold, axis=0)[: x.shape[0]]
    return y


# ---------------------------------------------------------------- delay


def delay(x: np.ndarray, time_s: float, feedback: float = 0.35, mix: float = 0.3,
          damp_hz: float = 6000.0, tail_s: float = 0.0) -> np.ndarray:
    """Feedback delay with a low-passed feedback path. Vectorised per delay-length chunk."""
    d = nsamp(time_s)
    n = x.shape[0] + nsamp(tail_s)
    src = np.zeros((n,) + x.shape[1:])
    src[: x.shape[0]] = x
    wet = np.zeros_like(src)
    prev = np.zeros((d,) + x.shape[1:])
    for s in range(d, n, d):
        e = min(n, s + d)
        chunk = src[s - d:e - d] + feedback * prev[: e - s]
        chunk = filters.one_pole_lp(chunk, damp_hz)
        wet[s:e] = chunk
        prev = np.zeros_like(prev)
        prev[: e - s] = chunk
    return src * (1 - mix) + wet * mix


# ---------------------------------------------------------------- reverb (generated IRs)

ROOMS: dict[str, dict] = {
    # rt60 (s) low/mid/high, early reflection spread (s), pre-delay, brightness, early level
    "small_office": {"rt": (0.55, 0.45, 0.25), "er": 0.025, "pre": 0.004, "er_n": 14, "er_gain": 0.7},
    "store": {"rt": (1.0, 0.85, 0.55), "er": 0.045, "pre": 0.008, "er_n": 18, "er_gain": 0.55},
    "alley": {"rt": (1.6, 1.2, 0.5), "er": 0.09, "pre": 0.012, "er_n": 10, "er_gain": 0.8,
              "slap": (0.11, 0.23)},
    "hall": {"rt": (2.6, 2.2, 1.3), "er": 0.06, "pre": 0.02, "er_n": 22, "er_gain": 0.35},
    "plate": {"rt": (1.6, 1.5, 1.1), "er": 0.01, "pre": 0.0, "er_n": 6, "er_gain": 0.2},
}


def generate_ir(room: str, stereo_out: bool = True) -> np.ndarray:
    """Procedural impulse response: seeded early reflections + 3-band exponentially decaying
    filtered noise tail (independent noise per channel for width). Deterministic per room id."""
    p = ROOMS[room]
    rng = np.random.default_rng(seed_for("ir." + room))
    length = max(p["rt"]) * 1.2 + p["pre"] + 0.05
    n = nsamp(length)
    t = np.arange(n) / SR
    chans = []
    for ch in range(2 if stereo_out else 1):
        ir = np.zeros(n)
        # early reflections: sparse taps, decaying, alternating sign, slightly low-passed
        times = np.sort(rng.uniform(0.002, p["er"], p["er_n"])) + p["pre"]
        for i, tt in enumerate(times):
            k = int(tt * SR)
            ir[k] += p["er_gain"] * (0.85 ** i) * (1 if rng.random() > 0.3 else -1)
        for st in p.get("slap", ()):
            k = int((st + p["pre"] + ch * 0.003) * SR)
            if k < n:
                ir[k] += 0.45 * p["er_gain"]
        ir = filters.one_pole_lp(ir, 9000)
        # late tail: band-split noise each with its own decay; onset after early field
        nz = rng.standard_normal(n)
        onset = np.clip((t - p["pre"] - p["er"] * 0.5) / max(p["er"], 0.005), 0, 1)
        bands = (filters.lp(nz, 400), filters.bp(nz, 1800, 0.5), filters.hp(nz, 4500))
        tail = np.zeros(n)
        for band, rt in zip(bands, p["rt"]):
            tail += band * np.exp(-6.907755 * t / rt)
        ir += 0.18 * tail * onset
        chans.append(ir)
    out = np.stack(chans, axis=1) if stereo_out else chans[0]
    return out / (np.sqrt(np.sum(out ** 2) / (2 if stereo_out else 1)) + 1e-12)


_IR_CACHE: dict[tuple[str, bool], np.ndarray] = {}


def reverb(x: np.ndarray, room: str, mix: float = 0.25, stereo_out: bool = True,
           tail: bool = True, predelay_s: float = 0.0, lowcut: float = 150.0) -> np.ndarray:
    """Convolution reverb with a generated IR. Mono in -> stereo out (if stereo_out).
    Returns dry*(1-mix)+wet*mix, extended by the IR length when tail=True."""
    key = (room, stereo_out)
    if key not in _IR_CACHE:
        _IR_CACHE[key] = generate_ir(room, stereo_out)
    ir = _IR_CACHE[key]
    src = x if x.ndim == 1 else x.mean(axis=1) if not stereo_out else x
    src = filters.hp(src, lowcut)
    if predelay_s > 0:
        src = np.concatenate([np.zeros((nsamp(predelay_s),) + src.shape[1:]), src])
    if stereo_out:
        s2 = stereo(src)
        wet = np.stack([fftconvolve(s2[:, c], ir[:, c]) for c in range(2)], axis=1)
        dry = stereo(x)
    else:
        wet = fftconvolve(src if src.ndim == 1 else src.mean(axis=1), ir)
        dry = x if x.ndim == 1 else x.mean(axis=1)
    n = wet.shape[0] if tail else dry.shape[0]
    out = np.zeros((n,) + wet.shape[1:])
    out[: dry.shape[0]] += dry * (1 - mix)
    out += wet[:n] * mix
    return out


# ---------------------------------------------------------------- spatial


def pan(x: np.ndarray, position: float | np.ndarray) -> np.ndarray:
    """Constant-power pan, position -1 (L) .. +1 (R), scalar or per-sample."""
    p = np.clip(np.asarray(position, dtype=float), -1, 1)
    ang = (p + 1) * math.pi / 4
    m = x if x.ndim == 1 else x.mean(axis=1)
    return np.stack([m * np.cos(ang), m * np.sin(ang)], axis=1)


def widen(x: np.ndarray, amount_ms: float = 12.0) -> np.ndarray:
    """Haas-style widening of a mono signal."""
    d = nsamp(amount_ms / 1000)
    left = x
    right = np.concatenate([np.zeros(d), x[:-d]]) if d > 0 else x
    return np.stack([left, right], axis=1) / math.sqrt(2) * 1.2


def doppler(x: np.ndarray, path: np.ndarray, listener: tuple[float, float] = (0.0, 0.0),
            c: float = 343.0, ref_dist: float = 10.0, src_t0: float = 0.0) -> np.ndarray:
    """Render a mono source moving along `path` (n x 2 positions in metres, per output sample).

    Propagation delay -> time warp (pitch shift), 1/r gain, distance air absorption (LP),
    and equal-power pan from bearing. `src_t0` is the time (s) of the source's first sample
    relative to output t=0 (negative = the source started earlier). Returns stereo.
    """
    n = path.shape[0]
    rel = path - np.asarray(listener)
    dist = np.maximum(np.hypot(rel[:, 0], rel[:, 1]), 1.0)
    t_out = np.arange(n) / SR
    t_src = t_out - dist / c
    xs = np.interp((t_src - src_t0) * SR, np.arange(x.shape[0]), x, left=0.0, right=0.0)
    gain = ref_dist / dist
    near = filters.one_pole_lp(xs, 12000)
    far = filters.one_pole_lp(xs, 1200)
    w = np.clip((dist - ref_dist) / 300.0, 0, 1)
    y = (near * (1 - w) + far * w) * gain
    return pan(y, np.clip(rel[:, 0] / dist, -1, 1) * 0.8)


# ---------------------------------------------------------------- dynamics


def envelope(x: np.ndarray, attack_s: float = 0.002, release_s: float = 0.08) -> np.ndarray:
    """Peak envelope: max filter (attack window) then one-pole release smoothing."""
    a = np.abs(x if x.ndim == 1 else np.max(np.abs(x), axis=1))
    a = maximum_filter1d(a, size=max(1, nsamp(attack_s)), origin=0)
    c = math.exp(-1.0 / max(release_s * SR, 1.0))
    return lfilter([1 - c], [1, -c], a)


def limiter(x: np.ndarray, ceiling: float = 0.89, lookahead_s: float = 0.003, release_s: float = 0.06) -> np.ndarray:
    """Look-ahead peak limiter. Gain = min-filter of the per-sample required gain over a centred
    window, smoothed with a moving average of the same width (never exceeds the required gain),
    then a one-pole release that only slows gain recovery."""
    a = np.abs(x if x.ndim == 1 else np.max(np.abs(x), axis=1))
    w = max(3, nsamp(lookahead_s) * 2 + 1)
    g_raw = np.minimum(1.0, ceiling / np.maximum(a, 1e-9))
    g = uniform_filter1d(minimum_filter1d(g_raw, size=w), size=w)
    c = math.exp(-1.0 / max(release_s * SR, 1.0))
    rel = lfilter([1 - c], [1, -c], g - 1.0, zi=[0.0])[0] + 1.0
    g = np.minimum(g, rel)
    return x * (g if x.ndim == 1 else g[:, None])


def compress(x: np.ndarray, threshold_db: float = -18.0, ratio: float = 3.0, attack_s: float = 0.005,
             release_s: float = 0.12, makeup_db: float = 0.0) -> np.ndarray:
    env = envelope(x, attack_s, release_s)
    lvl = 20 * np.log10(np.maximum(env, 1e-9))
    over = np.maximum(lvl - threshold_db, 0)
    gdb = -over * (1 - 1 / ratio) + makeup_db
    g = 10 ** (gdb / 20)
    return x * (g if x.ndim == 1 else g[:, None])


def duck_curve(n: int, hits_s: list[float], depth: float = 0.6, release_s: float = 0.18,
               attack_s: float = 0.004) -> np.ndarray:
    """Sidechain-style gain curve from trigger times (e.g. kick drum positions)."""
    g = np.ones(n)
    t = np.arange(n) / SR
    for h in hits_s:
        k0 = int(h * SR)
        if k0 >= n:
            continue
        k1 = min(n, k0 + nsamp(release_s * 5))
        tt = t[k0:k1] - h
        shape = np.minimum(tt / attack_s, 1.0) * np.exp(-tt / release_s)
        g[k0:k1] = np.minimum(g[k0:k1], 1 - depth * np.maximum(shape, 0))
        # pre-attack dip so the kick transient wins
        kp = max(0, k0 - nsamp(attack_s))
        g[kp:k0] = np.minimum(g[kp:k0], 1 - depth * np.linspace(0, 1, k0 - kp))
    return g
