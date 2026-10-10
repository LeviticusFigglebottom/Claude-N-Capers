"""Satin brass with soft tarnish blooms."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather
from texgen.materials.brushed_steel import brushed


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    streak = brushed(ctx, "b")
    tarn = ops.remap01(nz.fbm(u, v, ctx.per_m(1.5), ctx.s("tarn"), octaves=6, gain=0.55))
    tarn = ops.smoothstep(0.62, 0.95, tarn) * min(1.0, ctx.grime * 1.5)
    albedo = ops.vary(ctx.col("base"), streak, 0.015)
    albedo = ops.lerp(albedo, ops.fill(ctx.shape, ctx.col("tarnish")), (tarn * 0.4)[..., None])
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.clamp01(0.5 + streak))
    rough = ops.lerp(rough, ctx.p("tarnish_rough"), tarn * 0.7)
    h = 0.000006 * streak
    m = Maps(albedo, rough, np.ones(ctx.shape), h)
    weather(ctx, m, grime_color=ctx.col("tarnish"), grime_rough=0.6)
    return m
