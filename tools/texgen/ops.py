"""Image operations on float arrays (all tile-safe: filters use wrap-around borders)."""

from __future__ import annotations

import numpy as np
from scipy import ndimage

# ---------------------------------------------------------------------------- scalar helpers


def clamp01(x: np.ndarray) -> np.ndarray:
    return np.clip(x, 0.0, 1.0)


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def remap01(x: np.ndarray) -> np.ndarray:
    """Stretch to exactly [0, 1] (min/max; deterministic)."""
    lo = float(x.min())
    hi = float(x.max())
    if hi - lo < 1e-12:
        return np.zeros_like(x)
    return (x - lo) / (hi - lo)


def levels(x: np.ndarray, in_lo: float = 0.0, in_hi: float = 1.0, gamma: float = 1.0,
           out_lo: float = 0.0, out_hi: float = 1.0) -> np.ndarray:
    """Photoshop-style levels."""
    t = clamp01((x - in_lo) / max(1e-9, in_hi - in_lo))
    t = np.power(t, 1.0 / gamma)
    return out_lo + (out_hi - out_lo) * t


def blend(base: np.ndarray, top: np.ndarray, mode: str = "normal", opacity=1.0) -> np.ndarray:
    """Blend ``top`` over ``base``. ``opacity`` may be a scalar or a mask (H, W)."""
    if mode == "normal":
        r = top
    elif mode == "multiply":
        r = base * top
    elif mode == "screen":
        r = 1.0 - (1.0 - base) * (1.0 - top)
    elif mode == "overlay":
        r = np.where(base < 0.5, 2.0 * base * top, 1.0 - 2.0 * (1.0 - base) * (1.0 - top))
    elif mode == "add":
        r = base + top
    elif mode == "soft_light":
        r = (1.0 - 2.0 * top) * base * base + 2.0 * top * base
    else:
        raise ValueError(f"unknown blend mode {mode}")
    op = np.asarray(opacity)
    if op.ndim == 2 and np.ndim(base) == 3:
        op = op[..., None]
    return base + (r - base) * op


def blur(x: np.ndarray, sigma_px: float) -> np.ndarray:
    """Gaussian blur with wrap-around (tileable). Works on (H, W) or (H, W, C)."""
    if sigma_px <= 0:
        return x
    if x.ndim == 3:
        return np.stack([ndimage.gaussian_filter(x[..., c], sigma_px, mode="wrap")
                         for c in range(x.shape[2])], axis=-1)
    return ndimage.gaussian_filter(x, sigma_px, mode="wrap")


# ---------------------------------------------------------------------------- height-derived masks


def normal_from_height(height_m: np.ndarray, pixel_m: float, strength: float = 1.0) -> np.ndarray:
    """Tangent-space normal in the OpenGL convention (Y+ = green up = towards the top of the image).

    ``height_m`` is surface height in metres, ``pixel_m`` the size of one texel in metres.
    Returns float (H, W, 3) unit vectors.
    """
    dx = (np.roll(height_m, -1, axis=1) - np.roll(height_m, 1, axis=1)) / (2.0 * pixel_m)
    drow = (np.roll(height_m, -1, axis=0) - np.roll(height_m, 1, axis=0)) / (2.0 * pixel_m)
    # Image rows grow downward; tangent +Y points up the image, so dh/dy_up = -dh/drow.
    nx = -dx * strength
    ny = drow * strength
    nz = np.ones_like(height_m)
    n = np.stack([nx, ny, nz], axis=-1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def cavity(height_m: np.ndarray, pixel_m: float, radius_m: float) -> np.ndarray:
    """How far each texel sits below its blurred neighbourhood, in metres (>= 0)."""
    sigma = max(0.5, radius_m / pixel_m)
    return np.maximum(blur(height_m, sigma) - height_m, 0.0)


def ao_from_height(height_m: np.ndarray, pixel_m: float, radii_m=(0.004, 0.012, 0.04),
                   strength: float = 1.0, depth_ref_m: float = 0.004) -> np.ndarray:
    """Cheap multi-scale cavity AO approximation in [0, 1] (1 = unoccluded)."""
    occ = np.zeros_like(height_m)
    for r in radii_m:
        occ += cavity(height_m, pixel_m, r) / max(1e-9, depth_ref_m)
    occ /= len(radii_m)
    return clamp01(1.0 - strength * occ / (1.0 + occ))


def curvature(height_m: np.ndarray, pixel_m: float, radius_m: float,
              ref_height_m: float = 0.001) -> np.ndarray:
    """Signed curvature in [-1, 1]: >0 convex (edges, ridges), <0 concave (cavities).

    Absolute, not self-normalized: a step of ``ref_height_m`` seen at ``radius_m`` scores ~0.4, so
    nearly flat textures (brushing, peel) do not sprout wear everywhere.
    """
    sigma = max(0.5, radius_m / pixel_m)
    hb = blur(height_m, sigma)
    lap = ndimage.laplace(hb, mode="wrap")
    return np.clip(-lap * sigma * sigma / ref_height_m, -1.0, 1.0)


def edge_mask(height_m: np.ndarray, pixel_m: float, radius_m: float, lo: float = 0.15,
              hi: float = 0.6, ref_height_m: float = 0.001) -> np.ndarray:
    return smoothstep(lo, hi, curvature(height_m, pixel_m, radius_m, ref_height_m))


def cavity_mask(height_m: np.ndarray, pixel_m: float, radius_m: float, lo: float = 0.1,
                hi: float = 0.6, ref_height_m: float = 0.001) -> np.ndarray:
    return smoothstep(lo, hi, -curvature(height_m, pixel_m, radius_m, ref_height_m))


# ---------------------------------------------------------------------------- tiles / patterns


def tile_grid(u: np.ndarray, v: np.ndarray, nx: int, ny: int, row_offset: float = 0.0):
    """Rectangular tiling (nx * ny tiles per texture tile), optional running-bond offset.

    Returns (ix, iy, fx, fy): integer tile index and in-tile fraction in [0, 1).
    """
    y = v * ny
    iy = np.floor(y).astype(np.int64)
    x = u * nx + row_offset * np.mod(iy, 2)
    ix = np.floor(x).astype(np.int64)
    return np.mod(ix, nx), np.mod(iy, ny), x - np.floor(x), y - np.floor(y)


def edge_distance(fx: np.ndarray, fy: np.ndarray, w_m: float, h_m: float) -> np.ndarray:
    """Distance in metres from the nearest tile border, for a tile of w_m x h_m."""
    return np.minimum(np.minimum(fx, 1.0 - fx) * w_m, np.minimum(fy, 1.0 - fy) * h_m)


def bevel_profile(dist_m: np.ndarray, gap_m: float, bevel_m: float) -> np.ndarray:
    """0 inside the gap (grout), rising to 1 across a bevel of ``bevel_m``."""
    t = clamp01((dist_m - gap_m * 0.5) / max(1e-6, bevel_m))
    return np.sin(t * np.pi * 0.5)


# ---------------------------------------------------------------------------- colour


def srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, np.power((c + 0.055) / 1.055, 2.4))


def linear_to_srgb(c):
    c = np.clip(np.asarray(c, dtype=np.float64), 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def hex_to_linear(h: str) -> np.ndarray:
    h = h.lstrip("#")
    srgb = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    return srgb_to_linear(srgb)


def luminance(rgb_lin: np.ndarray) -> np.ndarray:
    return rgb_lin[..., 0] * 0.2126 + rgb_lin[..., 1] * 0.7152 + rgb_lin[..., 2] * 0.0722


def tint(color_lin: np.ndarray, value: np.ndarray) -> np.ndarray:
    """Broadcast a colour (3,) by a scalar field (H, W) -> (H, W, 3)."""
    return np.asarray(color_lin)[None, None, :] * value[..., None]


def fill(shape, color_lin) -> np.ndarray:
    return np.broadcast_to(np.asarray(color_lin, dtype=np.float64), (*shape, 3)).copy()


def vary(color_lin: np.ndarray, field: np.ndarray, amount: float) -> np.ndarray:
    """Multiply a colour (3,) or image by (1 + amount * field), field roughly in [-1, 1]."""
    c = np.asarray(color_lin)
    if c.ndim == 1:
        c = c[None, None, :]
    return c * (1.0 + amount * field)[..., None]


def hue_shift_toward(rgb_lin: np.ndarray, target_lin: np.ndarray, t) -> np.ndarray:
    """Blend chromaticity toward ``target`` while preserving luminance."""
    lum = luminance(rgb_lin)[..., None]
    tl = float(luminance(np.asarray(target_lin)))
    tgt = np.asarray(target_lin)[None, None, :] * (lum / max(tl, 1e-6))
    tt = np.asarray(t)
    if tt.ndim == 2:
        tt = tt[..., None]
    return rgb_lin + (tgt - rgb_lin) * tt


def enforce_albedo_rules(rgb_lin: np.ndarray, lum_min: float, lum_max: float,
                         sat_max: float) -> np.ndarray:
    """Clamp per-texel luminance (linear) and HSV saturation (of the sRGB-encoded value)."""
    out = np.clip(rgb_lin, 0.0, 1.0)
    s = linear_to_srgb(out)
    mx = s.max(axis=-1, keepdims=True)
    mn = s.min(axis=-1, keepdims=True)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    k = np.where(sat > sat_max, sat_max / np.maximum(sat, 1e-6), 1.0)
    s = mx - (mx - s) * k
    out = srgb_to_linear(s)
    for _ in range(3):
        lum = luminance(out)[..., None]
        hi = lum > lum_max
        out = np.where(hi, out * (lum_max / np.maximum(lum, 1e-6)), out)
        lum = luminance(out)[..., None]
        lo = lum < lum_min
        out = np.where(lo, out + (lum_min - lum), out)
        out = np.clip(out, 0.0, 1.0)
    return out
