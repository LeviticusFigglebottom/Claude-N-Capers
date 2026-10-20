"""Dressed limestone ashlar (OF-C2): running-bond blocks with chamfered, slightly recessed joints, per-block tone,
fine fossil specks and soft cloudy bedding. Neutral enough for the banking hall, the concourse and the corridors
(tint it on a duplicate for a warmer or greyer stone). Block counts tile exactly in 2 m."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    nb = int(ctx.p("blocks_per_row"))
    rows = int(ctx.p("courses"))
    if rows % 2:
        raise ValueError("limestone_ashlar: courses must be even for running bond to tile")
    ix, iy, fx, fy = ops.tile_grid(u, v, nb, rows, row_offset=0.5)
    bw = ctx.tile_m / nb
    bh = ctx.tile_m / rows
    chip = nz.fbm(u, v, ctx.per_m(18), ctx.s("chip"), octaves=3)
    d = ops.edge_distance(fx, fy, bw, bh) + 0.0015 * chip
    joint = float(ctx.p("joint_mm")) * 1e-3
    cham = float(ctx.p("chamfer_mm")) * 1e-3
    face = ops.bevel_profile(d, joint, cham)

    rnd = nz.cell_random(ix, iy, nb, rows, ctx.s("block"), channels=4)
    bed = ops.remap01(nz.fbm(u, v, (ctx.per_m(1.5), ctx.per_m(4)), ctx.s("bed"), octaves=5, gain=0.55))
    cloud = ops.remap01(nz.fbm(u, v, ctx.per_m(2.0), ctx.s("cloud"), octaves=6, gain=0.55))
    f1, _f2, rid, _dx, _dy = nz.worley(u, v, ctx.per_m(60), ctx.s("fossil"))
    fossil = np.where(rid < 0.25, 1.0 - ops.smoothstep(0.05, 0.16, f1), 0.0)
    pits_f1, _p2, pits_r, _a, _b = nz.worley(u, v, ctx.per_m(140), ctx.s("pits"))
    pits = np.where(pits_r < 0.2, 1.0 - ops.smoothstep(0.06, 0.2, pits_f1), 0.0)
    fine = nz.fbm(u, v, ctx.per_m(40), ctx.s("fine"), octaves=3)

    h = face * (0.006 + 0.0004 * (rnd[..., 2] - 0.5) + 0.0002 * fine - 0.0004 * pits) \
        + (1.0 - face) * (0.0004 * chip)

    light = ctx.col("stone_light")
    mid = ctx.col("stone")
    dark = ctx.col("stone_dark")
    t = rnd[..., 3]
    bcol = np.where((t < 0.5)[..., None], ops.lerp(dark, mid, (t / 0.5)[..., None]),
                    ops.lerp(mid, light, ((t - 0.5) / 0.5)[..., None]))
    bcol = ops.lerp(bcol, bcol * 0.93, (0.6 * bed + 0.4 * cloud)[..., None] * float(ctx.p("bedding")))
    bcol = ops.vary(bcol, fine, 0.03)
    bcol = bcol * (1.0 - 0.18 * fossil - 0.25 * pits)[..., None]
    shade = ops.smoothstep(cham + joint * 0.5, joint * 0.5, d) * 0.18
    bcol = bcol * (1.0 - shade)[..., None]
    jcol = ops.vary(ctx.col("joint"), chip, 0.06)
    albedo = ops.lerp(jcol, bcol, ops.smoothstep(0.0, 0.25, face)[..., None])
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(ctx.p("joint_rough"), ops.lerp(r0, r1, cloud), face) + 0.05 * pits
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.004, 0.012), ao_depth_m=0.004)
    weather(ctx, m, edge_radius_m=0.004, cavity_radius_m=0.012)
    return m
