"""Night harbour water: a tileable ripple map for game/world/materials/shaders/water.gdshader.

Not an ORM PBR material: the shader owns colour, roughness and Fresnel; this texture only carries
the surface motion. One RGB8 PNG (lossless, linear):

* R, G: tangent-space ripple normal X / Y (OpenGL Y+, 0.5 = flat), from a height field of
  gradient fBm (wind ripples, ~0.3-1.5 m) plus a ridged short chop (~0.15 m).
* B: "slick" mask (0 = glassy slick, 1 = rippled), a slow low-frequency field the shader samples
  at a much larger scale to break the surface into calm and wind-roughened patches.

Every lattice period is an integer number of cells per tile, so the texture tiles seamlessly.
"""

from __future__ import annotations

import numpy as np

from texgen import noise as nz, ops, orm
from texgen.materials.base import Ctx


def generate(ctx: Ctx) -> tuple[np.ndarray, dict]:
    """Return (uint8 (H, W, 3) image, stats)."""
    u, v = ctx.u, ctx.v
    # Wind ripples: domain-warped fBm, so crests are not lattice-aligned blobs.
    wu, wv = nz.warp(u, v, float(ctx.p("warp")), ctx.per_m(float(ctx.p("warp_cells_per_m"))), ctx.s("warp"))
    swell = nz.fbm(wu, wv, ctx.per_m(float(ctx.p("ripple_cells_per_m"))), ctx.s("ripple"), octaves=4, gain=0.55)
    chop = nz.ridged(u, v, ctx.per_m(float(ctx.p("chop_cells_per_m"))), ctx.s("chop"), octaves=2, sharpness=1.5)
    height = swell * float(ctx.p("ripple_mm")) * 1e-3 + (chop - 0.5) * float(ctx.p("chop_mm")) * 1e-3
    n = ops.normal_from_height(height, ctx.pixel_m, 1.0)
    # Store the slope in a fixed range (shader rescales): |n.xy| <= slope_range maps to 0..1.
    rng = float(ctx.p("slope_range"))
    rg = np.clip(n[..., :2] / rng, -1.0, 1.0) * 0.5 + 0.5
    slick = ops.remap01(nz.fbm(u, v, ctx.per_m(float(ctx.p("slick_cells_per_m"))), ctx.s("slick"), octaves=3))
    slick = ops.smoothstep(0.25, 0.75, slick)
    img = orm.to_u8(np.concatenate([rg, slick[..., None]], axis=-1))
    stats = {
        "slope_rms": round(float(np.sqrt(np.mean(n[..., 0] ** 2 + n[..., 1] ** 2))), 4),
        "slope_clipped_frac": round(float(np.mean(np.abs(n[..., :2]) > rng)), 4),
        "slick_mean": round(float(slick.mean()), 4),
    }
    return img, stats
