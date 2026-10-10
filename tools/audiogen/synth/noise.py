"""White / pink / brown noise and crackle."""
from __future__ import annotations

import numpy as np
from scipy.signal import lfilter

from .core import nsamp


def white(dur: float, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(nsamp(dur)) * 0.5


def pink(dur: float, rng: np.random.Generator) -> np.ndarray:
    """-3 dB/oct via the classic 3-pole/3-zero approximation (Kellet/RBJ)."""
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1.0, -2.494956002, 2.017265875, -0.522189400]
    y = lfilter(b, a, rng.standard_normal(nsamp(dur) + 4800))[4800:]
    return y / (np.std(y) + 1e-12) * 0.5


def brown(dur: float, rng: np.random.Generator) -> np.ndarray:
    y = lfilter([1.0], [1.0, -0.997], rng.standard_normal(nsamp(dur) + 9600))[9600:]
    y = lfilter([1.0, -1.0], [1.0, -0.9995], y)  # remove DC drift
    return y / (np.std(y) + 1e-12) * 0.5


def crackle(dur: float, rng: np.random.Generator, density: float = 200.0) -> np.ndarray:
    """Sparse random impulses (vinyl/static crackle), density in impulses per second."""
    n = nsamp(dur)
    y = np.zeros(n)
    k = rng.poisson(density * dur)
    idx = rng.integers(0, n, k)
    y[idx] = rng.uniform(-1, 1, k)
    return y
