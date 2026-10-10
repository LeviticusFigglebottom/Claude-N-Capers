"""Hand-troweled plaster, painted (eggshell). Very low-frequency undulation + soft trowel marks."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    und = nz.fbm(u, v, ctx.per_m(1.5), ctx.s("und"), octaves=6, gain=0.55)
    wu, wv = nz.warp(u, v, 0.05, ctx.per_m(1.0), ctx.s("warp"))
    trow = ops.remap01(nz.ridged(wu, wv, (ctx.per_m(1.5), ctx.per_m(2.5)), ctx.s("trowel"),
                                 octaves=3, sharpness=4.0))
    h = und * ctx.p("undulation_mm") * 2e-3 + trow * ctx.p("trowel_mm") * 1e-3
    mott = nz.fbm(u, v, ctx.per_m(2.0), ctx.s("mott"), octaves=5)
    albedo = ops.vary(ctx.col("base"), mott * 2.0, ctx.p("mottle"))
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(nz.fbm(u, v, ctx.per_m(3.0), ctx.s("rough"), octaves=4)))
    rough = rough - 0.06 * trow
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=4.0)
    weather(ctx, m, edge_radius_m=0.02, cavity_radius_m=0.05)
    return m
