"""Blued / black-oxide steel (slides, barrels): dark blue-grey metal, faint machining lines,
holster wear patches polished to bare steel."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather
from texgen.materials.brushed_steel import brushed


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    streak = brushed(ctx, "mach")
    patch = ops.remap01(nz.fbm(u, v, ctx.per_m(10), ctx.s("holster"), octaves=5, gain=0.6))
    amt = float(ctx.p("holster_wear")) * min(1.0, ctx.wear * 3.0)
    thr = 0.86 - 0.1 * amt
    worn = 0.75 * ops.smoothstep(thr, thr + 0.1, patch) if amt > 0 else np.zeros(ctx.shape)
    albedo = ops.vary(ctx.col("base"), streak, 0.04)
    albedo = ops.lerp(albedo, ops.fill(ctx.shape, ctx.col("worn")), worn[..., None])
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(ops.lerp(r0, r1, ops.clamp01(0.5 + streak)), ctx.p("worn_rough"), worn)
    h = 0.000004 * streak - 0.000005 * worn
    m = Maps(albedo, rough, np.ones(ctx.shape), h)
    weather(ctx, m)
    return m
