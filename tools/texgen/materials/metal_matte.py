"""Bead-blasted / matte-finished metal (rails, mounts, suppressor tubes): isotropic fine grain."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    grain = nz.fbm(u, v, ctx.per_m(250), ctx.s("grain"), octaves=2, gain=0.45)
    low = nz.fbm(u, v, ctx.per_m(3), ctx.s("low"), octaves=4)
    albedo = ops.vary(ctx.col("base"), low + 0.5 * grain, 0.04)
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(grain + 0.5 * low))
    h = 0.000008 * grain
    # PO6-10: a coated (cerakote-style) finish is a dielectric; coat_metal = 1.0 keeps bare matte metal.
    m = Maps(albedo, rough, np.full(ctx.shape, float(ctx.p("coat_metal", 1.0))), h)
    weather(ctx, m, wear_lighten=0.1, wear_rough=0.4)
    return m
