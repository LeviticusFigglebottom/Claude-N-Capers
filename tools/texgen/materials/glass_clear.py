"""Clear float glass: near-transparent, faint green tint, dust and wiping streaks in alpha."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    dust = ops.remap01(nz.fbm(u, v, ctx.per_m(2.0), ctx.s("dust"), octaves=6, gain=0.6))
    wipe = ops.remap01(nz.fbm(u, v, (ctx.per_m(0.75), ctx.per_m(6)), ctx.s("wipe"), octaves=3))
    dirt = ops.clamp01(ops.smoothstep(0.68, 0.98, dust) * 0.7 + ops.smoothstep(0.7, 1.0, wipe) * 0.3)
    dirt = dirt * min(1.0, ctx.grime * 2.0)
    albedo = ops.lerp(ops.fill(ctx.shape, ctx.col("tint")), ops.fill(ctx.shape, ctx.col("dirt")),
                      dirt[..., None])
    alpha = ops.lerp(float(ctx.p("alpha")), float(ctx.p("dirt_alpha")), dirt)
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(wipe)) + (ctx.p("dirt_rough") - r1) * dirt
    ripple = nz.fbm(u, v, (ctx.per_m(0.5), ctx.per_m(3)), ctx.s("ripple"), octaves=2)
    h = 0.00004 * ripple
    return Maps(albedo, rough, np.zeros(ctx.shape), h, alpha=alpha, ao_strength=0.0)
