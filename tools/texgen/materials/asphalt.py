"""Worn asphalt: exposed aggregate, binder voids, oil stains, sparse cracks."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    f1, f2, rid, _dx, _dy = nz.worley(u, v, ctx.per_m(ctx.p("stone_cells_per_m")), ctx.s("stones"), jitter=0.9)
    period = ctx.per_m(ctx.p("stone_cells_per_m"))
    aa = period / ctx.size
    stone = ops.smoothstep(0.12 - aa, 0.12 + aa, f2 - f1) * (rid > 0.5)
    dome = stone * ops.clamp01(1.0 - f1) ** 0.5
    void = (rid < 0.12) * (1.0 - ops.smoothstep(0.15, 0.3, f1))
    binder = nz.fbm(u, v, ctx.per_m(3), ctx.s("binder"), octaves=5)
    stain = ops.smoothstep(0.62, 0.85, ops.remap01(nz.fbm(u, v, ctx.per_m(1), ctx.s("stain"), octaves=5)))
    wu, wv = nz.warp(u, v, 0.05, ctx.per_m(1), ctx.s("cw"))
    crack = ops.smoothstep(0.93, 0.99, nz.ridged(wu, wv, ctx.per_m(0.75), ctx.s("crack"), octaves=4, sharpness=10.0))
    crack *= float(ctx.p("crack"))

    h = 0.0015 * dome - 0.0015 * void - 0.003 * crack + 0.0003 * binder
    scol = ops.vary(ctx.col("stone"), (rid - 0.5) * 2.0, 0.18)
    albedo = ops.vary(ctx.col("base"), binder, 0.12)
    albedo = ops.lerp(albedo, scol, (stone * 0.55)[..., None])
    albedo = ops.lerp(albedo, ops.fill(ctx.shape, ctx.col("stain")), (stain * 0.6)[..., None])
    albedo = albedo * (1.0 - 0.4 * void - 0.5 * crack)[..., None]
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r1, r0, stone) - 0.15 * stain
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.004, 0.012), ao_depth_m=0.002)
    weather(ctx, m, edge_radius_m=0.004, cavity_radius_m=0.012, wear_lighten=0.15)
    return m
