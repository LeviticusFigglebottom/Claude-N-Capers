"""Painted gypsum board: flat, faint roller orange-peel, eggshell sheen."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    peel = nz.fbm(u, v, ctx.per_m(ctx.p("peel_cells_per_m")), ctx.s("peel"), octaves=2, gain=0.4)
    wave = nz.fbm(u, v, ctx.per_m(1.0), ctx.s("wave"), octaves=4)
    h = peel * ctx.p("peel_mm") * 1e-3 + wave * 0.0003
    mott = nz.fbm(u, v, ctx.per_m(1.5), ctx.s("mott"), octaves=4)
    albedo = ops.vary(ctx.col("base"), mott * 2.0, ctx.p("mottle"))
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(nz.fbm(u, v, ctx.per_m(4.0), ctx.s("rough"), octaves=4)))
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=2.0)
    weather(ctx, m, edge_radius_m=0.02, cavity_radius_m=0.05)
    return m
