"""Lay-in acoustic ceiling tiles in an exposed T-bar grid (256 px/m)."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    tm = float(ctx.p("tile_m"))
    n = max(1, int(round(ctx.tile_m / tm)))
    ix, iy, fx, fy = ops.tile_grid(u, v, n, n)
    d = ops.edge_distance(fx, fy, tm, tm)
    half_grid = float(ctx.p("grid_mm")) * 0.5e-3
    tile_face = ops.smoothstep(half_grid, half_grid + 0.006, d)
    grid = 1.0 - ops.smoothstep(half_grid - 0.002, half_grid, d)

    wu, wv = nz.warp(u, v, 0.01, ctx.per_m(6), ctx.s("w"))
    fiss = nz.ridged(wu, wv, ctx.per_m(9), ctx.s("fiss"), octaves=2, sharpness=12.0)
    fiss = ops.smoothstep(0.55, 0.95, fiss)
    f1, _f2, rid, _dx, _dy = nz.worley(u, v, ctx.per_m(40), ctx.s("pits"))
    pits = np.where(rid < 0.35, 1.0 - ops.smoothstep(0.08, 0.2, f1), 0.0)
    stipple = nz.value(u, v, ctx.per_m(64), ctx.s("stip"))
    detail = np.maximum(fiss, pits)

    h = -0.008 * tile_face - 0.0012 * detail * tile_face + 0.0002 * stipple * tile_face
    tile = ops.vary(ctx.col("tile"), stipple, 0.03)
    tile = tile * (1.0 - 0.1 * detail)[..., None]
    shade = nz.cell_random(ix, iy, n, n, ctx.s("shade"))
    tile = tile * (0.97 + 0.04 * shade)[..., None]
    albedo = ops.lerp(tile, ops.fill(ctx.shape, ctx.col("grid")), grid[..., None])
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(ops.lerp(r0, r1, ops.remap01(stipple)), ctx.p("grid_rough"), grid)
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.008, 0.02), ao_depth_m=0.006, ao_strength=0.6)
    weather(ctx, m, edge_radius_m=0.01, cavity_radius_m=0.03)
    return m
