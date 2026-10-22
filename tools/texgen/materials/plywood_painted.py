"""Painted site-hoarding plywood (RT-C2, Rolling Thunder §3c): `sheets` sheets per 2 m tile (1.0 m x 2.0 m panels,
the hoarding's 2.4 m height reads as the sheets plus the top rail), butt joints with a dark gap, screw rows along the
sheet edges and on the hidden rail line, the ply grain ghosting through a flat exterior paint, weathered: runs from
the top, dirt splash at the foot."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    n = int(ctx.p("sheets"))
    ix, iy, fx, fy = ops.tile_grid(u, v, n, 1)
    sw = ctx.tile_m / n
    sh = ctx.tile_m
    d = ops.edge_distance(fx, fy, sw, sh)
    gap = float(ctx.p("gap_mm")) * 1e-3
    sheet = ops.bevel_profile(d, gap, 0.002)
    # screws: 12 mm in from the vertical edges every 300 mm, and a row on the hidden rail at mid height
    xm, ym = fx * sw, fy * sh
    pitch = 0.3
    best = np.full(ctx.shape, 1e9)
    for line in (0.012, sw - 0.012):
        along = np.mod(ym + pitch * 0.5, pitch) - pitch * 0.5
        best = np.minimum(best, np.hypot(xm - line, along))
    along_x = np.mod(xm + pitch * 0.5, pitch) - pitch * 0.5
    best = np.minimum(best, np.hypot(ym - sh * 0.5, along_x))
    r = 0.004
    screw = np.sqrt(ops.clamp01(1.0 - best / r))
    # ply grain under the paint (along V, the sheet's long side), varying per sheet
    rnd = nz.cell_random(ix, iy, n, 1, ctx.s("sheet"), channels=2)
    grain = nz.fbm(u * 6.0 + rnd[..., 0] * 3.0, v, ctx.per_m(2), ctx.s("grain"), octaves=3)
    low = nz.fbm(u, v, ctx.per_m(1.5), ctx.s("low"), octaves=4)
    paint = ops.vary(ctx.col("paint"), low, 0.05) * (0.97 + 0.06 * rnd[..., 1])[..., None]
    paint = paint * (1.0 + 0.04 * grain)[..., None]
    # rain runs from the top edge and dirt splash at the foot of the sheets (V = 0 is the top of the tile)
    runs = ops.clamp01(nz.fbm(u * 18.0, v, ctx.per_m(1), ctx.s("runs"), octaves=3) * 1.5 - 0.4)
    runs = runs * ops.smoothstep(0.7, 0.0, fy)
    splash = ops.smoothstep(0.85, 1.0, fy) * ops.clamp01(0.5 + nz.fbm(u, v, ctx.per_m(12), ctx.s("splash"), octaves=3))
    albedo = paint * (1.0 - 0.12 * runs - 0.25 * splash)[..., None]
    albedo = ops.lerp(ops.fill(ctx.shape, ctx.col("gap")), albedo, ops.smoothstep(0.0, 0.4, sheet)[..., None])
    albedo = albedo * (1.0 + 0.35 * screw)[..., None]
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(low)) + 0.08 * runs - 0.2 * screw
    h = sheet * (0.002 + 0.00015 * grain) + 0.0012 * screw
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0, ao_radii_m=(0.003, 0.01), ao_depth_m=0.002)
    weather(ctx, m, edge_radius_m=0.003, cavity_radius_m=0.006, wear_lighten=0.05)
    return m
