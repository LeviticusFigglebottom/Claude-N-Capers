"""Injection-moulded black polymer (frames, furniture): fine spark-eroded grain, satin-matte."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    grain = nz.fbm(u, v, ctx.per_m(ctx.p("grain_cells_per_m")), ctx.s("grain"), octaves=2, gain=0.45)
    low = nz.fbm(u, v, ctx.per_m(4), ctx.s("low"), octaves=4)
    albedo = ops.vary(ctx.col("base"), low + 0.4 * grain, 0.05)
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(grain + 0.4 * low))
    h = 0.00002 * grain + 0.00003 * low
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0)
    weather(ctx, m, edge_radius_m=0.001, cavity_radius_m=0.003, wear_lighten=0.25, wear_rough=0.42)
    return m
