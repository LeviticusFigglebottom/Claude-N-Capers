"""Brushed stainless steel; brushing runs along U."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def brushed(ctx: Ctx, seed_name: str) -> np.ndarray:
    u, v = ctx.u, ctx.v
    s1 = nz.value(u, v, (ctx.per_m(1.5), ctx.size // 8), ctx.s(seed_name + "1"))
    s2 = nz.value(u, v, (ctx.per_m(4), ctx.size // 4), ctx.s(seed_name + "2"))
    s3 = nz.value(u, v, (ctx.per_m(0.75), ctx.size // 16), ctx.s(seed_name + "3"))
    return 0.35 * s1 + 0.4 * s2 + 0.25 * s3


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    streak = brushed(ctx, "b")
    smudge = ops.smoothstep(0.55, 0.85, ops.remap01(nz.fbm(u, v, ctx.per_m(2), ctx.s("sm"), octaves=5)))
    albedo = ops.vary(ctx.col("base"), streak, ctx.p("streak"))
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.clamp01(0.5 + streak)) + 0.06 * smudge
    h = 0.000006 * streak
    m = Maps(albedo, rough, np.ones(ctx.shape), h, normal_strength=1.0)
    weather(ctx, m, edge_radius_m=0.004, cavity_radius_m=0.01)
    return m
