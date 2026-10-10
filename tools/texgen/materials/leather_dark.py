"""Dark brown pebble-grain leather with soft wrinkles and scuffed highs."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    wu, wv = nz.warp(u, v, 0.004, ctx.per_m(20), ctx.s("w"), octaves=2)
    f1, f2, rid, _dx, _dy = nz.worley(wu, wv, ctx.per_m(ctx.p("grain_cells_per_m")), ctx.s("grain"))
    crease = 1.0 - ops.smoothstep(0.0, 0.1, f2 - f1)
    pebble = ops.clamp01(1.0 - f1 * 0.9) ** 0.7
    wu2, wv2 = nz.warp(u, v, 0.08, ctx.per_m(1), ctx.s("w2"))
    wrinkle = ops.smoothstep(0.75, 0.97, nz.ridged(wu2, wv2, ctx.per_m(3), ctx.s("wr"), octaves=3, sharpness=6.0))
    h = 0.00025 * pebble - 0.0002 * crease - 0.0005 * wrinkle
    albedo = ops.vary(ctx.col("base"), nz.fbm(u, v, ctx.per_m(2), ctx.s("tone"), octaves=4), 0.18)
    albedo = albedo * (1.0 + 0.06 * (rid - 0.5))[..., None]
    albedo = ops.lerp(albedo, ops.fill(ctx.shape, ctx.col("crease")), (0.6 * crease + 0.5 * wrinkle)[..., None])
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.clamp01(crease + wrinkle))
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=2.0,
             ao_radii_m=(0.003, 0.01), ao_depth_m=0.0006, ao_strength=0.5)
    weather(ctx, m, edge_radius_m=0.006, cavity_radius_m=0.01, wear_color=ctx.col("scuff"), wear_rough=0.65)
    return m
