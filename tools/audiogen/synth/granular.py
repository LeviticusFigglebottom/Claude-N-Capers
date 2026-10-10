"""Granular engine: overlap-add of windowed grains, from a source buffer or a grain generator."""
from __future__ import annotations

from typing import Callable

import numpy as np

from .core import SR, nsamp


def grain_window(n: int, kind: str = "hann") -> np.ndarray:
    if kind == "perc":  # fast attack, exponential decay (shards, clicks)
        t = np.arange(n) / max(n, 1)
        return np.minimum(t * 40, 1) * np.exp(-t * 6)
    return np.hanning(n)


def cloud(dur: float, times: np.ndarray, make_grain: Callable[[int, np.random.Generator], np.ndarray],
          rng: np.random.Generator, gains: np.ndarray | None = None) -> np.ndarray:
    """Place generated grains at `times` (s). make_grain(i, rng) -> mono grain array."""
    out = np.zeros(nsamp(dur))
    for i, t0 in enumerate(times):
        g = make_grain(i, rng)
        k = int(t0 * SR)
        if k >= out.shape[0]:
            continue
        e = min(out.shape[0], k + g.shape[0])
        out[k:e] += g[: e - k] * (1.0 if gains is None else gains[i])
    return out


def granulate(src: np.ndarray, dur: float, density: float | np.ndarray, grain_s: tuple[float, float],
              rng: np.random.Generator, pitch: tuple[float, float] = (1.0, 1.0),
              scan: tuple[float, float] = (0.0, 1.0), window: str = "hann") -> np.ndarray:
    """Classic granulation of a source buffer: random grain size/pitch, read position scanning
    from scan[0] to scan[1] (fractions of src) over the output duration."""
    n = nsamp(dur)
    out = np.zeros(n)
    dens = np.full(n, float(density)) if np.isscalar(density) else np.asarray(density)
    expected = np.cumsum(dens) / SR
    count = int(expected[-1])
    if count <= 0:
        return out
    starts = np.searchsorted(expected, np.sort(rng.uniform(0, expected[-1], count)))
    for k in starts:
        gl = nsamp(rng.uniform(*grain_s))
        ratio = rng.uniform(*pitch)
        pos = (scan[0] + (scan[1] - scan[0]) * k / n) * (src.shape[0] - gl * ratio - 1)
        idx = pos + np.arange(gl) * ratio
        g = np.interp(idx, np.arange(src.shape[0]), src) * grain_window(gl, window)
        e = min(n, k + gl)
        out[k:e] += g[: e - k]
    return out
