"""Black hard-anodized aluminium (receivers, rails, optic bodies): dark satin metal, very fine
isotropic grain, sparse edge-wear flecks to bright bare aluminium."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    grain = nz.fbm(u, v, ctx.per_m(250), ctx.s("grain"), octaves=2, gain=0.45)
    low = nz.fbm(u, v, ctx.per_m(3), ctx.s("low"), octaves=4)
    fleck = ops.remap01(nz.fbm(u, v, ctx.per_m(12), ctx.s("fleck"), octaves=5, gain=0.6))
    amt = float(ctx.p("edge_wear")) * min(1.0, ctx.wear * 3.0)
    thr = 0.88 - 0.08 * amt
    worn = 0.8 * ops.smoothstep(thr, thr + 0.06, fleck) if amt > 0 else np.zeros(ctx.shape)
    albedo = ops.vary(ctx.col("base"), low + 0.4 * grain, 0.05)
    albedo = ops.lerp(albedo, ops.fill(ctx.shape, ctx.col("worn")), worn[..., None])
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(ops.lerp(r0, r1, ops.remap01(grain + 0.5 * low)), ctx.p("worn_rough"), worn)
    h = 0.000006 * grain - 0.00001 * worn
    m = Maps(albedo, rough, np.ones(ctx.shape), h)
    weather(ctx, m)
    return m
