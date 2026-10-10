"""ORM packing: R = ambient occlusion, G = roughness, B = metallic. Linear (no sRGB curve)."""

from __future__ import annotations

import numpy as np


def pack(ao: np.ndarray, roughness: np.ndarray, metallic: np.ndarray) -> np.ndarray:
    """Return an (H, W, 3) uint8 ORM image. Inputs are floats in [0, 1]."""
    stack = np.stack([ao, roughness, metallic], axis=-1)
    return to_u8(stack)


def to_u8(x: np.ndarray) -> np.ndarray:
    """Float [0, 1] -> uint8 with round-half-up (no dithering, fully deterministic)."""
    return np.floor(np.clip(x, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def unpack(img: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    f = img.astype(np.float64) / 255.0
    return f[..., 0], f[..., 1], f[..., 2]
