"""Matte moulded plastic (fine spark-eroded texture)."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    stip = nz.fbm(u, v, ctx.per_m(64), ctx.s("stip"), octaves=2, gain=0.4)
    low = nz.fbm(u, v, ctx.per_m(2), ctx.s("low"), octaves=4)
    albedo = ops.vary(ctx.col("base"), low, 0.04)
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(stip + 0.5 * low))
    h = 0.00004 * stip
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0)
    weather(ctx, m)
    return m
