"""3D colour-grading LUTs for Godot's ``Environment.adjustment_color_correction``.

Layout: an N x N*N RGB PNG (N = 32): slice b (blue) occupies columns [b*N, (b+1)*N); inside a
slice, x = red index, y (row, top = 0) = green index. It is imported with the ``3d_texture``
importer (``slices/horizontal = N``, lossless, no mipmaps), producing a ``CompressedTexture3D``.

Godot samples the LUT with the post-tonemap, sRGB-encoded colour as the 3D coordinate (no
half-texel remap), so texel i holds the grade of the input ``(i + 0.5) / N``. With linear filtering
this reproduces the grade exactly across the interior of the cube (identity LUT = identity).
"""

from __future__ import annotations

import numpy as np

from texgen import orm

LUT_SIZE = 32


def _luma(c: np.ndarray) -> np.ndarray:
    return c[..., 0] * 0.2126 + c[..., 1] * 0.7152 + c[..., 2] * 0.0722


def grade(c: np.ndarray, p: dict) -> np.ndarray:
    """Apply a grade (preset dict, see presets/gsr.py ``luts``) to display-space colours (..., 3)."""
    out = c.copy()
    if not p:
        return out
    slope = np.asarray(p.get("slope", (1.0, 1.0, 1.0)))
    offset = np.asarray(p.get("offset", (0.0, 0.0, 0.0)))
    power = np.asarray(p.get("power", (1.0, 1.0, 1.0)))
    out = np.power(np.clip(out * slope + offset, 0.0, 1.0), power)
    y = _luma(out)[..., None]
    sh = np.clip(1.0 - y / 0.5, 0.0, 1.0) ** 2
    hi = np.clip((y - 0.5) / 0.5, 0.0, 1.0) ** 2
    out = out + sh * np.asarray(p.get("shadow_tint", (0, 0, 0))) + hi * np.asarray(p.get("highlight_tint", (0, 0, 0)))
    pivot = float(p.get("pivot", 0.45))
    out = pivot + (out - pivot) * float(p.get("contrast", 1.0))
    y = _luma(out)[..., None]
    out = y + (out - y) * float(p.get("saturation", 1.0))
    return np.clip(out, 0.0, 1.0)


def build(p: dict, n: int = LUT_SIZE) -> np.ndarray:
    """Return the uint8 (n, n*n, 3) strip image for grade ``p``."""
    axis = (np.arange(n, dtype=np.float64) + 0.5) / n
    g, b, r = np.meshgrid(axis, axis, axis, indexing="ij")  # [g, b, r]
    cube = np.stack([r, g, b], axis=-1)
    graded = grade(cube, p)                       # (g, b, r, 3)
    strip = graded.reshape(n, n * n, 3)           # rows = g, cols = b*n + r
    return orm.to_u8(strip)
