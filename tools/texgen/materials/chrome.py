"""Polished chrome with faint smudges."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    smudge = ops.smoothstep(0.5, 0.85, ops.remap01(nz.fbm(u, v, ctx.per_m(2.5), ctx.s("sm"), octaves=5)))
    albedo = ops.vary(ctx.col("base"), smudge, -float(ctx.p("smudge")))
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, smudge)
    h = np.zeros(ctx.shape)
    m = Maps(albedo, rough, np.ones(ctx.shape), h)
    weather(ctx, m)
    return m
