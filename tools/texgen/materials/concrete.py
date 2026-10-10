"""Smooth-finished concrete: cloudy mottling, sparse air pores, rare hairline cracks."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    mott = ops.remap01(nz.fbm(u, v, ctx.per_m(1.5), ctx.s("mott"), octaves=6, gain=0.55))
    blot = nz.fbm(u, v, ctx.per_m(5.0), ctx.s("blot"), octaves=3, kind="value")
    f1, _f2, rid, _dx, _dy = nz.worley(u, v, ctx.per_m(ctx.p("pore_cells_per_m")), ctx.s("pores"))
    dens = float(ctx.p("pore_density"))
    radius = 0.06 + 0.16 * (rid / dens)
    pore = np.where(rid < dens, 1.0 - ops.smoothstep(radius * 0.55, radius, f1), 0.0)
    wu, wv = nz.warp(u, v, 0.06, ctx.per_m(1.0), ctx.s("cw"))
    crk = nz.ridged(wu, wv, ctx.per_m(0.75), ctx.s("crack"), octaves=4, sharpness=10.0)
    crack = ops.smoothstep(0.9, 0.985, crk) * float(ctx.p("crack"))
    crack *= ops.smoothstep(0.45, 0.7, ops.remap01(nz.fbm(u, v, ctx.per_m(1.0), ctx.s("cm"), octaves=2)))

    h = 0.0008 * (mott - 0.5) + 0.0002 * blot - 0.0012 * pore - 0.0008 * crack
    albedo = ops.lerp(ops.fill(ctx.shape, ctx.col("dark")), ops.fill(ctx.shape, ctx.col("light")),
                      (0.35 + 0.5 * mott)[..., None])
    albedo = ops.vary(albedo, blot, 0.06)
    albedo = albedo * (1.0 - 0.35 * pore - 0.4 * crack)[..., None]
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(nz.fbm(u, v, ctx.per_m(2.5), ctx.s("rough"), octaves=4)))
    rough = np.maximum(rough, pore * 0.95)
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.5)
    weather(ctx, m, edge_radius_m=0.006, cavity_radius_m=0.02)
    return m
