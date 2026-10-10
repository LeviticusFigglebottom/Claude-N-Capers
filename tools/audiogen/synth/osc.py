"""Band-limited oscillators (polyBLEP), FM operators, additive partials.

All functions take a frequency that is a scalar or a per-sample array (Hz) and return float64.
"""
from __future__ import annotations

import numpy as np
from scipy.signal import lfilter

from .core import SR, as_array, nsamp


def phase_of(freq: float | np.ndarray, n: int, phase0: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    f = as_array(freq, n)
    dt = np.abs(f) / SR
    ph = (phase0 + np.concatenate(([0.0], np.cumsum(f[:-1] / SR)))) % 1.0
    return ph, np.clip(dt, 1e-9, 0.5)


def polyblep(p: np.ndarray, dt: np.ndarray) -> np.ndarray:
    """Polynomial band-limited step residual for phase p in [0,1) and increment dt."""
    y = np.zeros_like(p)
    m1 = p < dt
    x = p[m1] / dt[m1]
    y[m1] = x + x - x * x - 1.0
    m2 = p > 1.0 - dt
    x = (p[m2] - 1.0) / dt[m2]
    y[m2] = x * x + x + x + 1.0
    return y


def sine(freq: float | np.ndarray, dur: float, phase0: float = 0.0) -> np.ndarray:
    ph, _ = phase_of(freq, nsamp(dur), phase0)
    return np.sin(2 * np.pi * ph)


def saw(freq: float | np.ndarray, dur: float, phase0: float = 0.0) -> np.ndarray:
    ph, dt = phase_of(freq, nsamp(dur), phase0)
    return 2.0 * ph - 1.0 - polyblep(ph, dt)


def square(freq: float | np.ndarray, dur: float, pw: float = 0.5, phase0: float = 0.0) -> np.ndarray:
    ph, dt = phase_of(freq, nsamp(dur), phase0)
    naive = np.where(ph < pw, 1.0, -1.0)
    return naive + polyblep(ph, dt) - polyblep((ph + 1.0 - pw) % 1.0, dt)


def triangle(freq: float | np.ndarray, dur: float, phase0: float = 0.0) -> np.ndarray:
    """Leaky-integrated band-limited square (classic BLEP triangle)."""
    n = nsamp(dur)
    ph, dt = phase_of(freq, n, phase0)
    sq = np.where(ph < 0.5, 1.0, -1.0) + polyblep(ph, dt) - polyblep((ph + 0.5) % 1.0, dt)
    tri = lfilter([1.0], [1.0, -0.9995], sq * 4.0 * dt)
    tri -= np.mean(tri)
    pk = np.max(np.abs(tri)) or 1.0
    return tri / pk


def supersaw(freq: float | np.ndarray, dur: float, voices: int = 5, detune_cents: float = 14.0,
             rng: np.random.Generator | None = None) -> np.ndarray:
    n = nsamp(dur)
    f = as_array(freq, n)
    out = np.zeros(n)
    for i in range(voices):
        c = (i - (voices - 1) / 2) / max(1, (voices - 1) / 2) * detune_cents
        p0 = float(rng.random()) if rng is not None else i / voices
        out += saw(f * 2 ** (c / 1200.0), dur, p0)
    return out / np.sqrt(voices)


def fm(carrier: float | np.ndarray, ratio: float, index: float | np.ndarray, dur: float,
       feedback: float = 0.0) -> np.ndarray:
    """Two-operator phase-modulation FM; `index` may be an envelope array."""
    n = nsamp(dur)
    fc = as_array(carrier, n)
    ph_c, _ = phase_of(fc, n)
    ph_m, _ = phase_of(fc * ratio, n)
    mod = np.sin(2 * np.pi * ph_m)
    if feedback:
        mod = np.sin(2 * np.pi * ph_m + feedback * mod)
    return np.sin(2 * np.pi * ph_c + as_array(index, n) * mod)


def partials(freqs: list[float], amps: list[float], decays: list[float], dur: float,
             rng: np.random.Generator | None = None) -> np.ndarray:
    """Additive bank of exponentially decaying sines (bells, metal, glass)."""
    t = np.arange(nsamp(dur)) / SR
    out = np.zeros_like(t)
    for f, a, d in zip(freqs, amps, decays):
        if f >= SR * 0.45:
            continue
        p0 = float(rng.random()) * 2 * np.pi if rng is not None else 0.0
        out += a * np.sin(2 * np.pi * f * t + p0) * np.exp(-t / max(d, 1e-4))
    return out
