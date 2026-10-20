"""Frosted (acid-etched) privacy glass (D-142): a milky, mostly opaque pane with a fine etched stipple,
a faint cloudy variation and a slightly clearer wiped band. It reads obscured from both sides; stealth
vision treats it as opaque (the map leaves its collider out of `see_through`)."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    etch = ops.remap01(nz.fbm(u, v, ctx.per_m(96.0), ctx.s("etch"), octaves=2))
    cloud = ops.remap01(nz.fbm(u, v, ctx.per_m(1.5), ctx.s("cloud"), octaves=4, gain=0.55))
    wipe = ops.remap01(nz.fbm(u, v, (ctx.per_m(0.75), ctx.per_m(6)), ctx.s("wipe"), octaves=3))
    tint = ops.fill(ctx.shape, ctx.col("tint"))
    shade = ops.fill(ctx.shape, ctx.col("shade"))
    albedo = ops.lerp(tint, shade, (0.35 * cloud + 0.25 * etch)[..., None])
    clear = ops.smoothstep(0.75, 1.0, wipe) * float(ctx.p("wipe_clear"))
    a0, a1 = ctx.p("alpha")
    alpha = ops.lerp(a0, a1, 0.6 * cloud + 0.4 * etch) - clear
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, etch)
    h = 0.00002 * (etch - 0.5)
    return Maps(albedo, rough, np.zeros(ctx.shape), h, alpha=ops.clamp01(alpha), ao_strength=0.0)
