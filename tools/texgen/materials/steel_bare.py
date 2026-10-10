"""Bare machined steel (barrels, pins, springs, bolt faces): bright, fine machining streaks."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather
from texgen.materials.brushed_steel import brushed


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    streak = brushed(ctx, "mach")
    smudge = ops.smoothstep(0.6, 0.9, ops.remap01(nz.fbm(u, v, ctx.per_m(4), ctx.s("sm"), octaves=5)))
    albedo = ops.vary(ctx.col("base"), streak, ctx.p("streak"))
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.clamp01(0.5 + streak)) + 0.06 * smudge
    h = 0.000004 * streak
    m = Maps(albedo, rough, np.ones(ctx.shape), h)
    weather(ctx, m)
    return m
