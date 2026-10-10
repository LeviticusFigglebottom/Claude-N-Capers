"""Commercial loop-pile carpet tiles (0.5 m), quarter-turned, heathered yarn."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    tm = float(ctx.p("tile_m"))
    n = max(1, int(round(ctx.tile_m / tm)))
    ix, iy, fx, fy = ops.tile_grid(u, v, n, n)
    rot = np.mod(ix + iy, 2) == 1
    across = np.where(rot, fx, fy)
    rows = float(ctx.p("rows_per_tile"))
    loops = 0.5 + 0.5 * np.cos(2.0 * np.pi * across * rows)
    # Loops broken up along the row direction.
    knots_u = nz.value(u, v, (ctx.per_m(rows / tm), ctx.per_m(8)), ctx.s("ku"))
    knots_v = nz.value(u, v, (ctx.per_m(8), ctx.per_m(rows / tm)), ctx.s("kv"))
    knots = np.where(rot, knots_v, knots_u)
    streak_u = nz.fbm(u, v, (ctx.per_m(3), ctx.per_m(48)), ctx.s("su"), octaves=3)
    streak_v = nz.fbm(u, v, (ctx.per_m(48), ctx.per_m(3)), ctx.s("sv"), octaves=3)
    streak = np.where(rot, streak_v, streak_u)
    yarn_u = nz.gradient(u, v, (ctx.per_m(12), ctx.per_m(rows / tm)), ctx.s("yu"))
    yarn_v = nz.gradient(u, v, (ctx.per_m(rows / tm), ctx.per_m(12)), ctx.s("yv"))
    yarn = np.where(rot, yarn_v, yarn_u)
    fleck = nz.gradient(u, v, ctx.per_m(90), ctx.s("fleck"))
    heather = ops.remap01(0.7 * yarn + 0.5 * fleck + 0.3 * streak)

    d = ops.edge_distance(fx, fy, tm, tm)
    seam = 1.0 - ops.smoothstep(0.0005, 0.0025, d)
    h = 0.0012 * loops * (0.75 + 0.25 * knots) + 0.0002 * streak - 0.0015 * seam

    a = ops.fill(ctx.shape, ctx.col("heather_a"))
    b = ops.fill(ctx.shape, ctx.col("heather_b"))
    albedo = ops.lerp(a, b, ops.smoothstep(0.2, 0.8, heather)[..., None])
    albedo = ops.lerp(albedo, ops.fill(ctx.shape, ctx.col("base")), 0.35)
    tile_shade = nz.cell_random(ix, iy, n, n, ctx.s("shade"))
    albedo = albedo * (0.94 + 0.12 * tile_shade + 0.08 * (loops - 0.5))[..., None]
    albedo = ops.lerp(albedo, ops.fill(ctx.shape, ctx.col("seam")), seam[..., None] * 0.6)
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, 1.0 - loops * 0.6)
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.003, 0.008), ao_depth_m=0.0015, ao_strength=0.8)
    weather(ctx, m, edge_radius_m=0.01, cavity_radius_m=0.03, grime_rough=0.98)
    return m
