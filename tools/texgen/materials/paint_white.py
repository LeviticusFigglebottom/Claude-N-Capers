"""White enamel paint (sight dots, index marks, markings): smooth, slight orange peel."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    peel = nz.fbm(u, v, ctx.per_m(120), ctx.s("peel"), octaves=2, gain=0.4)
    low = nz.fbm(u, v, ctx.per_m(3), ctx.s("low"), octaves=4)
    albedo = ops.vary(ctx.col("base"), low, 0.02)
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(peel + 0.5 * low))
    h = 0.00002 * peel
    m = Maps(albedo, rough, np.zeros(ctx.shape), h)
    weather(ctx, m)
    return m
