"""Cream marble in 1 m polished slabs: cloudy base, long meandering primary veins with soft
halos, sparse branching secondary veins. Each slab is cut from a different part of the block."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather

# Integer (u, v) frequencies of the vein "strata" per tile; integers keep the field tileable.
_DIRS = ((1, 1), (1, -1), (2, 1), (1, 2))
_CROSS = (3, -2)


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    n = max(1, int(round(ctx.tile_m / float(ctx.p("slab_m")))))
    ix, iy, fx, fy = ops.tile_grid(u, v, n, n)
    off = nz.cell_random(ix, iy, n, n, ctx.s("slab"), channels=3)
    su = u + off[..., 0]
    sv = v + off[..., 1]

    turb = nz.fbm(su, sv, ctx.per_m(1.0), ctx.s("turb"), octaves=6, gain=0.55)
    width = ops.remap01(nz.fbm(su, sv, ctx.per_m(1.5), ctx.s("width"), octaves=3))
    primary = np.zeros(ctx.shape)
    for k, (a, b) in enumerate(_DIRS):
        sel = np.floor(off[..., 2] * len(_DIRS)) == k
        phase = a * su + b * sv + 0.45 * turb
        line = 1.0 - np.abs(np.sin(2.0 * np.pi * phase))
        core = np.power(line, 30.0 + 120.0 * width)
        halo = np.power(line, 5.0) * 0.35
        primary = np.where(sel, np.maximum(core, halo), primary)

    turb2 = nz.fbm(su, sv, ctx.per_m(1.5), ctx.s("turb2"), octaves=6, gain=0.6)
    a2, b2 = _CROSS
    line2 = 1.0 - np.abs(np.sin(2.0 * np.pi * (a2 * su + b2 * sv + 0.9 * turb2)))
    sec = np.power(line2, 90.0)
    presence = ops.smoothstep(0.5, 0.8, ops.remap01(nz.fbm(su, sv, ctx.per_m(1.0), ctx.s("pres"), octaves=3)))
    sec = sec * presence

    cloud = ops.remap01(nz.fbm(su, sv, ctx.per_m(2.0), ctx.s("cloud"), octaves=6, gain=0.55))
    base = ops.lerp(ops.fill(ctx.shape, ctx.col("base")), ops.fill(ctx.shape, ctx.col("base2")),
                    ops.smoothstep(0.3, 0.85, cloud)[..., None])
    gold = ops.smoothstep(0.5, 0.8, ops.remap01(nz.fbm(su, sv, ctx.per_m(1.5), ctx.s("gold"), octaves=3)))
    vcol = ops.lerp(ops.fill(ctx.shape, ctx.col("vein")), ops.fill(ctx.shape, ctx.col("vein_gold")),
                    gold[..., None])
    vmask = ops.clamp01(primary * 0.85 + sec * 0.55)
    albedo = ops.lerp(base, vcol, vmask[..., None])

    d = ops.edge_distance(fx, fy, ctx.tile_m / n, ctx.tile_m / n)
    seam = 1.0 - ops.bevel_profile(d, 0.0015, 0.0015)
    albedo = albedo * (1.0 - 0.25 * float(ctx.p("seam")) * seam)[..., None]
    h = -0.001 * seam + 0.00002 * vmask
    r0, r1 = ctx.p("rough")
    etch = ops.smoothstep(0.6, 0.85, ops.remap01(nz.fbm(u, v, ctx.per_m(1.5), ctx.s("etch"), octaves=5)))
    rough = ops.lerp(r0, r1, cloud) + (ctx.p("etch_rough") - r1) * etch * 0.6 + 0.5 * seam
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0)
    weather(ctx, m, edge_radius_m=0.004, cavity_radius_m=0.006)
    return m
