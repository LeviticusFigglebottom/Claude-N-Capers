"""Powder-coated / painted steel (safes, doors, cabinets): orange peel, chipped to bare steel."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    peel = nz.fbm(u, v, ctx.per_m(70), ctx.s("peel"), octaves=2, gain=0.4)
    n = nz.fbm(u, v, ctx.per_m(4), ctx.s("chips"), octaves=7, gain=0.6)
    amount = float(ctx.p("chip")) * ctx.wear
    thr = 0.42 - 0.12 * amount
    chips = ops.smoothstep(thr, thr + 0.01, n) if amount > 0 else np.zeros(ctx.shape)
    wu, wv = nz.warp(u, v, 0.02, ctx.per_m(2), ctx.s("sw"))
    scr = nz.ridged(wu, wv, (ctx.per_m(1), ctx.per_m(8)), ctx.s("scr"), octaves=2, sharpness=40.0)
    scr = ops.smoothstep(0.6, 0.9, scr) * ops.smoothstep(0.55, 0.7, ops.remap01(
        nz.fbm(u, v, ctx.per_m(2), ctx.s("sm"), octaves=3))) * amount
    bare = ops.clamp01(chips + scr)
    paint = ops.vary(ctx.col("paint"), nz.fbm(u, v, ctx.per_m(2), ctx.s("tone"), octaves=4), 0.06)
    steel = ops.vary(ctx.col("steel"), nz.value(u, v, (ctx.per_m(3), ctx.size // 8), ctx.s("st")), 0.06)
    albedo = ops.lerp(paint, steel, bare[..., None])
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(ops.lerp(r0, r1, ops.remap01(peel)), ctx.p("steel_rough"), bare)
    metal = bare
    h = 0.00015 * (1.0 - bare) + 0.00002 * peel
    m = Maps(albedo, rough, metal, h, normal_strength=1.0, ao_radii_m=(0.003,), ao_depth_m=0.0005,
             ao_strength=0.4)
    weather(ctx, m, edge_radius_m=0.004, cavity_radius_m=0.006, wear_lighten=0.05)
    return m
