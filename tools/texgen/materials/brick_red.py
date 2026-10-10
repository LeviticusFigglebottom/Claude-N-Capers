"""Red brick, running bond, recessed mortar. Course/brick counts chosen to tile exactly."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    nb = int(ctx.p("bricks_per_row"))
    rows = int(ctx.p("courses"))
    if rows % 2:
        raise ValueError("brick_red: courses must be even for running bond to tile")
    ix, iy, fx, fy = ops.tile_grid(u, v, nb, rows, row_offset=0.5)
    bw = ctx.tile_m / nb
    bh = ctx.tile_m / rows
    chip = nz.fbm(u, v, ctx.per_m(25), ctx.s("chip"), octaves=3)
    d = ops.edge_distance(fx, fy, bw, bh) + 0.003 * chip
    mortar = float(ctx.p("mortar_mm")) * 1e-3
    face = ops.bevel_profile(d, mortar, 0.004)

    rnd = nz.cell_random(ix, iy, nb, rows, ctx.s("brick"), channels=4)
    tilt = 0.0006 * ((rnd[..., 0] - 0.5) * (fx - 0.5) + (rnd[..., 1] - 0.5) * (fy - 0.5))
    pits_f1, _f2, pits_r, _dx, _dy = nz.worley(u, v, ctx.per_m(40), ctx.s("pits"))
    pits = np.where(pits_r < 0.3, 1.0 - ops.smoothstep(0.08, 0.22, pits_f1), 0.0)
    surf = nz.fbm(u, v, ctx.per_m(12), ctx.s("surf"), octaves=4)
    mortar_n = nz.fbm(u, v, ctx.per_m(60), ctx.s("mn"), octaves=2)

    h = face * (0.008 + tilt + 0.0004 * surf - 0.0008 * pits) + (1.0 - face) * 0.0004 * mortar_n

    dark = ctx.col("brick_dark")
    mid = ctx.col("brick")
    orange = ctx.col("brick_orange")
    t = rnd[..., 2]
    bcol = np.where((t < 0.5)[..., None], ops.lerp(dark, mid, (t / 0.5)[..., None]),
                    ops.lerp(mid, orange, ((t - 0.5) / 0.5)[..., None]))
    bcol = bcol * (0.9 + 0.2 * rnd[..., 3])[..., None]
    bcol = ops.vary(bcol, surf, 0.12)
    burn = ops.smoothstep(0.004, 0.0, d - mortar * 0.5) * 0.25
    bcol = bcol * (1.0 - burn - 0.3 * pits)[..., None]
    mcol = ops.vary(ctx.col("mortar"), mortar_n, 0.1)
    albedo = ops.lerp(mcol, bcol, ops.smoothstep(0.0, 0.3, face)[..., None])
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(ctx.p("mortar_rough"), ops.lerp(r0, r1, ops.remap01(surf)), face)
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.005, 0.015), ao_depth_m=0.006)
    weather(ctx, m, edge_radius_m=0.004, cavity_radius_m=0.015)
    return m
