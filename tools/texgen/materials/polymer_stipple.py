"""Grip stippling on black polymer: dense raised pyramids/dots, rougher between, tops polished
slightly by handling (wear lightens and smooths the peaks)."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    period = ctx.per_m(ctx.p("stipple_cells_per_m"))
    f1, _f2, rid, _dx, _dy = nz.worley(u, v, period, ctx.s("stip"), jitter=0.7)
    dome = ops.clamp01(1.0 - f1 / (0.55 + 0.1 * rid)) ** 0.8
    low = nz.fbm(u, v, ctx.per_m(4), ctx.s("low"), octaves=4)
    h = float(ctx.p("stipple_mm")) * 1e-3 * dome + 0.00003 * low
    albedo = ops.vary(ctx.col("base"), low, 0.05)
    albedo = albedo * (0.93 + 0.1 * dome)[..., None]
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r1, r0, dome)
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.0008, 0.002), ao_depth_m=0.0003, ao_strength=0.6)
    weather(ctx, m, edge_radius_m=0.0008, cavity_radius_m=0.002, wear_lighten=0.3, wear_rough=0.45)
    return m
