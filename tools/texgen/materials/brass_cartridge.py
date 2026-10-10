"""Cartridge brass (cases, primers): bright, near-polished, light handling tarnish."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather
from texgen.materials.brushed_steel import brushed


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    streak = brushed(ctx, "draw")
    tarn = ops.remap01(nz.fbm(u, v, ctx.per_m(4), ctx.s("tarn"), octaves=6, gain=0.55))
    tarn = ops.smoothstep(0.65, 0.95, tarn) * min(1.0, ctx.grime * 3.0)
    albedo = ops.vary(ctx.col("base"), streak, 0.01)
    albedo = ops.lerp(albedo, ops.fill(ctx.shape, ctx.col("tarnish")), (tarn * 0.35)[..., None])
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.clamp01(0.5 + streak))
    rough = ops.lerp(rough, ctx.p("tarnish_rough"), tarn * 0.6)
    h = 0.000003 * streak
    m = Maps(albedo, rough, np.ones(ctx.shape), h)
    weather(ctx, m, grime_color=ctx.col("tarnish"), grime_rough=0.5)
    return m
