"""Walnut veneer, book-matched leaves running along U, satin lacquer."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    nleaf = max(2, int(round(ctx.tile_m / float(ctx.p("leaf_m")))))
    if nleaf % 2:
        nleaf += 1  # book-matching needs an even leaf count to tile
    y = v * nleaf
    k = np.floor(y)
    t = y - k
    odd = np.mod(k, 2) == 1
    t = np.where(odd, 1.0 - t, t)
    pair = np.floor(k / 2.0)
    uu = u + pair * 0.137  # each matched pair comes from a different part of the flitch

    rings = float(ctx.p("rings_per_leaf"))
    warp1 = nz.fbm(uu, t, (ctx.per_m(0.75), 2), ctx.s("g1"), octaves=4, gain=0.5)
    warp2 = nz.fbm(uu, t, (ctx.per_m(4), 6), ctx.s("g2"), octaves=3)
    field = t * rings + 2.2 * warp1 + 0.25 * warp2
    ring = field - np.floor(field)
    late = ops.smoothstep(0.5, 0.8, ring) * (1.0 - ops.smoothstep(0.88, 1.0, ring))
    pores = nz.value(uu, t, (ctx.per_m(4), 96), ctx.s("pores"))
    pores = ops.smoothstep(0.45, 0.9, pores)
    figure = nz.fbm(uu, t, (ctx.per_m(10), 3), ctx.s("fig"), octaves=2)
    tone = ops.remap01(nz.fbm(u, v, (ctx.per_m(1), ctx.per_m(4)), ctx.s("tone"), octaves=3))

    base = ops.lerp(ops.fill(ctx.shape, ctx.col("base")), ops.fill(ctx.shape, ctx.col("light")),
                    (0.55 * tone + 0.25 * ops.remap01(warp2))[..., None])
    albedo = ops.lerp(base, ops.fill(ctx.shape, ctx.col("late")), (late * 0.5)[..., None])
    albedo = albedo * (1.0 - 0.22 * pores + 0.06 * figure)[..., None]
    leaf_m = ctx.tile_m / nleaf
    seam = 1.0 - ops.smoothstep(0.0, 0.0008, np.minimum(t, 1.0 - t) * leaf_m)
    albedo = albedo * (1.0 - 0.3 * seam)[..., None]

    h = -0.00012 * pores - 0.00005 * late - 0.0002 * seam
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, tone) + (ctx.p("pore_rough") - r1) * pores * 0.5
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.003,), ao_depth_m=0.001, ao_strength=0.5)
    weather(ctx, m, edge_radius_m=0.004, cavity_radius_m=0.008)
    return m
