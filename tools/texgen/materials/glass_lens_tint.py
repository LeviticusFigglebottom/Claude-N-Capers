"""Tinted optic lens glass (sights, scopes): ~30 % opaque tinted coating, faint dust specks."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    f1, _f2, rid, _dx, _dy = nz.worley(u, v, ctx.per_m(60), ctx.s("specks"))
    specks = np.where(rid < 0.08, 1.0 - ops.smoothstep(0.05, 0.15, f1), 0.0)
    smear = ops.smoothstep(0.7, 1.0, ops.remap01(nz.fbm(u, v, ctx.per_m(3), ctx.s("smear"), octaves=5)))
    dirt = ops.clamp01(specks + 0.5 * smear) * min(1.0, ctx.grime * 4.0)
    albedo = ops.lerp(ops.fill(ctx.shape, ctx.col("tint")), ops.fill(ctx.shape, ctx.col("dirt")),
                      dirt[..., None])
    alpha = ops.lerp(float(ctx.p("alpha")), float(ctx.p("dirt_alpha")), dirt)
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, smear) + (ctx.p("dirt_rough") - r1) * dirt
    return Maps(albedo, rough, np.zeros(ctx.shape), np.zeros(ctx.shape), alpha=alpha, ao_strength=0.0)
