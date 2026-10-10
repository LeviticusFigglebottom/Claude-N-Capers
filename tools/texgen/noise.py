"""Seamlessly tileable noise on periodic lattices.

All functions take normalized texture coordinates ``u`` (columns) and ``v`` (rows) in [0, 1)
(any real value works; the lattice wraps) and an integer ``period`` (or ``(px, py)`` tuple for
anisotropic noise) giving the number of lattice cells across one texture tile. Because the lattice
is indexed modulo the period, every function tiles perfectly at u, v = 0/1.

Randomness comes only from ``numpy.random.Generator(PCG64(seed))``; never from global state.
"""

from __future__ import annotations

import zlib

import numpy as np

Period = int | tuple[int, int]


def make_rng(seed: int) -> np.random.Generator:
    """The only RNG constructor used by texgen."""
    return np.random.Generator(np.random.PCG64(int(seed) & 0xFFFFFFFFFFFFFFFF))


def sub_seed(seed: int, name: str) -> int:
    """Derive a stable child seed (crc32, never Python's salted hash())."""
    return (int(seed) * 1_000_003 + zlib.crc32(name.encode("utf-8"))) & 0xFFFFFFFF


def coords(size: int | tuple[int, int]) -> tuple[np.ndarray, np.ndarray]:
    """Normalized (u, v) grids of shape (H, W); u varies along columns, v along rows."""
    if isinstance(size, int):
        w = h = size
    else:
        w, h = size
    u = np.arange(w, dtype=np.float64) / w
    v = np.arange(h, dtype=np.float64) / h
    return np.meshgrid(u, v, indexing="xy")


def _period(period: Period) -> tuple[int, int]:
    if isinstance(period, tuple):
        return max(1, int(period[0])), max(1, int(period[1]))
    p = max(1, int(period))
    return p, p


def _fade(t: np.ndarray) -> np.ndarray:
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def _lattice(u: np.ndarray, v: np.ndarray, px: int, py: int):
    x = u * px
    y = v * py
    x0 = np.floor(x)
    y0 = np.floor(y)
    fx = x - x0
    fy = y - y0
    ix0 = np.mod(x0.astype(np.int64), px)
    iy0 = np.mod(y0.astype(np.int64), py)
    ix1 = np.mod(ix0 + 1, px)
    iy1 = np.mod(iy0 + 1, py)
    return fx, fy, ix0, iy0, ix1, iy1


def gradient(u: np.ndarray, v: np.ndarray, period: Period, seed: int) -> np.ndarray:
    """Perlin-style gradient noise, roughly in [-1, 1], zero at lattice points."""
    px, py = _period(period)
    ang = make_rng(seed).uniform(0.0, 2.0 * np.pi, size=(py, px))
    gx = np.cos(ang)
    gy = np.sin(ang)
    fx, fy, ix0, iy0, ix1, iy1 = _lattice(u, v, px, py)
    n00 = gx[iy0, ix0] * fx + gy[iy0, ix0] * fy
    n10 = gx[iy0, ix1] * (fx - 1.0) + gy[iy0, ix1] * fy
    n01 = gx[iy1, ix0] * fx + gy[iy1, ix0] * (fy - 1.0)
    n11 = gx[iy1, ix1] * (fx - 1.0) + gy[iy1, ix1] * (fy - 1.0)
    sx = _fade(fx)
    sy = _fade(fy)
    a = n00 + sx * (n10 - n00)
    b = n01 + sx * (n11 - n01)
    return (a + sy * (b - a)) * 1.41421356


def value(u: np.ndarray, v: np.ndarray, period: Period, seed: int) -> np.ndarray:
    """Smooth value noise in [-1, 1]."""
    px, py = _period(period)
    vals = make_rng(seed).uniform(-1.0, 1.0, size=(py, px))
    fx, fy, ix0, iy0, ix1, iy1 = _lattice(u, v, px, py)
    sx = _fade(fx)
    sy = _fade(fy)
    a = vals[iy0, ix0] + sx * (vals[iy0, ix1] - vals[iy0, ix0])
    b = vals[iy1, ix0] + sx * (vals[iy1, ix1] - vals[iy1, ix0])
    return a + sy * (b - a)


_BASIS = {"gradient": gradient, "value": value}


def fbm(u: np.ndarray, v: np.ndarray, period: Period, seed: int, octaves: int = 5,
        gain: float = 0.5, lacunarity: int = 2, kind: str = "gradient") -> np.ndarray:
    """Fractal Brownian motion. ``lacunarity`` must be an integer to stay tileable."""
    px, py = _period(period)
    fn = _BASIS[kind]
    total = np.zeros_like(u)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        f = int(lacunarity) ** o
        total += amp * fn(u, v, (px * f, py * f), sub_seed(seed, f"oct{o}"))
        norm += amp
        amp *= gain
    return total / norm


def ridged(u: np.ndarray, v: np.ndarray, period: Period, seed: int, octaves: int = 5,
           gain: float = 0.5, lacunarity: int = 2, sharpness: float = 2.0) -> np.ndarray:
    """Ridged multifractal in [0, 1]: sharp crests where the gradient noise crosses zero."""
    px, py = _period(period)
    total = np.zeros_like(u)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        f = int(lacunarity) ** o
        n = 1.0 - np.abs(gradient(u, v, (px * f, py * f), sub_seed(seed, f"ridge{o}")))
        total += amp * np.power(np.clip(n, 0.0, 1.0), sharpness)
        norm += amp
        amp *= gain
    return total / norm


def worley(u: np.ndarray, v: np.ndarray, period: Period, seed: int, jitter: float = 1.0):
    """Periodic cellular noise.

    Returns ``(f1, f2, cell_rand, nearest_dx, nearest_dy)``: distances to the nearest and second
    nearest feature point (in cell units), a per-cell random value in [0, 1) for the nearest
    feature, and the offset to the nearest feature point (cell units).
    """
    px, py = _period(period)
    rng = make_rng(seed)
    jitter = float(np.clip(jitter, 0.0, 1.0))
    pts = 0.5 + (rng.uniform(0.0, 1.0, size=(py, px, 2)) - 0.5) * jitter
    cell_rand = rng.uniform(0.0, 1.0, size=(py, px))
    x = u * px
    y = v * py
    cx = np.floor(x).astype(np.int64)
    cy = np.floor(y).astype(np.int64)
    f1 = np.full(u.shape, np.inf)
    f2 = np.full(u.shape, np.inf)
    rid = np.zeros(u.shape)
    ndx = np.zeros(u.shape)
    ndy = np.zeros(u.shape)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            nx = cx + ox
            ny = cy + oy
            ix = np.mod(nx, px)
            iy = np.mod(ny, py)
            dx = nx + pts[iy, ix, 0] - x
            dy = ny + pts[iy, ix, 1] - y
            d = np.sqrt(dx * dx + dy * dy)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            rid = np.where(closer, cell_rand[iy, ix], rid)
            ndx = np.where(closer, dx, ndx)
            ndy = np.where(closer, dy, ndy)
            f1 = np.where(closer, d, f1)
    return f1, f2, rid, ndx, ndy


def warp(u: np.ndarray, v: np.ndarray, amount: float, period: Period, seed: int,
         octaves: int = 3) -> tuple[np.ndarray, np.ndarray]:
    """Domain warp: offset (u, v) by a tileable fBm vector field. The result stays tileable."""
    du = fbm(u, v, period, sub_seed(seed, "wu"), octaves=octaves)
    dv = fbm(u, v, period, sub_seed(seed, "wv"), octaves=octaves)
    return u + amount * du, v + amount * dv


def cell_random(ix: np.ndarray, iy: np.ndarray, nx: int, ny: int, seed: int,
                channels: int = 1) -> np.ndarray:
    """Random value(s) in [0, 1) for integer tile indices (wrapped to an nx * ny grid)."""
    table = make_rng(seed).uniform(0.0, 1.0, size=(ny, nx, channels))
    out = table[np.mod(iy, ny), np.mod(ix, nx)]
    return out[..., 0] if channels == 1 else out
