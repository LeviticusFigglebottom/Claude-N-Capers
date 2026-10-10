"""Coated optic lens: thin-film anti-reflection look, a faint purple-to-green tint that drifts
across the glass (stand-in for the angle-dependent coating colour), transparent, few specks."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    film = ops.remap01(nz.fbm(u, v, ctx.per_m(1), ctx.s("film"), octaves=2, gain=0.35))
    f1, _f2, rid, _dx, _dy = nz.worley(u, v, ctx.per_m(60), ctx.s("specks"))
    specks = np.where(rid < 0.06, 1.0 - ops.smoothstep(0.05, 0.15, f1), 0.0)
    dirt = specks * min(1.0, ctx.grime * 4.0)
    tint = ops.lerp(ops.fill(ctx.shape, ctx.col("tint_a")), ops.fill(ctx.shape, ctx.col("tint_b")),
                    film[..., None])
    albedo = ops.lerp(tint, ops.fill(ctx.shape, ctx.col("dirt")), dirt[..., None])
    alpha = ops.lerp(float(ctx.p("alpha")), float(ctx.p("dirt_alpha")), dirt)
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, film) + (ctx.p("dirt_rough") - r1) * dirt
    return Maps(albedo, rough, np.zeros(ctx.shape), np.zeros(ctx.shape), alpha=alpha, ao_strength=0.0)
