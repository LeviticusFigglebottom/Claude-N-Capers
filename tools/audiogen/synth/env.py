"""Envelopes: ADSR, exponential decay, breakpoint segments."""
from __future__ import annotations

import numpy as np

from .core import SR, nsamp


def adsr(dur: float, a: float, d: float, s: float, r: float, curve: float = 3.0) -> np.ndarray:
    """ADSR over a total duration `dur` (release starts at dur - r). Exponential-ish curves."""
    n = nsamp(dur)
    t = np.arange(n) / SR
    a = max(a, 1e-5)
    base = np.where(t < a, np.clip(t / a, 0, 1) ** 0.7,
                    s + (1 - s) * np.exp(-np.maximum(t - a, 0) * curve / max(d, 1e-5)))
    rel_t = max(0.0, dur - r)
    k = min(n - 1, int(rel_t * SR))
    vrel = base[k]
    return np.where(t < rel_t, base, vrel * np.exp(-np.maximum(t - rel_t, 0) * curve / max(r, 1e-5)))


def exp_decay(dur: float, t60: float, attack: float = 0.0005) -> np.ndarray:
    n = nsamp(dur)
    t = np.arange(n) / SR
    e = np.exp(-6.907755 * t / max(t60, 1e-5))
    if attack > 0:
        e *= np.clip(t / attack, 0, 1)
    return e


def segments(points: list[tuple[float, float]], dur: float, shape: str = "lin") -> np.ndarray:
    """Breakpoint envelope from (time_s, value) pairs; shape 'lin' or 'exp' (log-domain)."""
    n = nsamp(dur)
    t = np.arange(n) / SR
    ts = np.array([p[0] for p in points])
    vs = np.array([p[1] for p in points], dtype=np.float64)
    if shape == "exp":
        return np.exp(np.interp(t, ts, np.log(np.maximum(vs, 1e-6))))
    return np.interp(t, ts, vs)


def lfo(rate: float, dur: float, depth: float = 1.0, phase: float = 0.0, shape: str = "sine") -> np.ndarray:
    t = np.arange(nsamp(dur)) / SR
    p = (rate * t + phase) % 1.0
    if shape == "tri":
        return depth * (4 * np.abs(p - 0.5) - 1)
    if shape == "square":
        return depth * np.where(p < 0.5, 1.0, -1.0)
    return depth * np.sin(2 * np.pi * p)
