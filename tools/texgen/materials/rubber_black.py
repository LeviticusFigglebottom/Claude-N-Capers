"""Moulded black rubber: fine stipple, scuffed lighter where worn."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    stip = nz.fbm(u, v, ctx.per_m(60), ctx.s("stip"), octaves=2, gain=0.4)
    low = nz.fbm(u, v, ctx.per_m(2), ctx.s("low"), octaves=4)
    scuff = ops.smoothstep(0.6, 0.9, ops.remap01(nz.fbm(u, v, (ctx.per_m(4), ctx.per_m(1)), ctx.s("sc"), octaves=4)))
    scuff = scuff * min(1.0, ctx.wear * 2.0)
    albedo = ops.vary(ctx.col("base"), low + 0.5 * stip, 0.08)
    albedo = albedo * (1.0 + 0.35 * scuff)[..., None]
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(stip)) - 0.1 * scuff
    h = 0.00005 * stip + 0.0002 * low
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0)
    weather(ctx, m, wear_lighten=0.2)
    return m
