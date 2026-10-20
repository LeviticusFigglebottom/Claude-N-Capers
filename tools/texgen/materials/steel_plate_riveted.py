"""Painted vault steel lining (OF-C2): `plates` x `plates` plates per 2 m tile with welded seams, a rivet row in from
every seam, satin enamel with faint orange peel and pristine bank-grade wear."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    n = int(ctx.p("plates"))
    ix, iy, fx, fy = ops.tile_grid(u, v, n, n)
    pm = ctx.tile_m / n
    d = ops.edge_distance(fx, fy, pm, pm)
    seam_w = float(ctx.p("seam_mm")) * 1e-3
    plate = ops.bevel_profile(d, seam_w, 0.003)
    inset = float(ctx.p("rivet_inset_mm")) * 1e-3
    pitch = float(ctx.p("rivet_pitch_mm")) * 1e-3
    r = float(ctx.p("rivet_mm")) * 1e-3 * 0.5
    xm = fx * pm
    ym = fy * pm
    best = np.full(ctx.shape, 1e9)
    for line in (inset, pm - inset):
        along_y = np.mod(ym + pitch * 0.5, pitch) - pitch * 0.5
        best = np.minimum(best, np.hypot(xm - line, along_y))
        along_x = np.mod(xm + pitch * 0.5, pitch) - pitch * 0.5
        best = np.minimum(best, np.hypot(ym - line, along_x))
    rivet = np.sqrt(ops.clamp01(1.0 - best / r))
    halo = ops.smoothstep(r * 1.9, r * 1.0, best) * (1.0 - ops.smoothstep(r * 1.0, r * 0.8, best))
    peel = nz.fbm(u, v, ctx.per_m(60), ctx.s("peel"), octaves=2, gain=0.4)
    rnd = nz.cell_random(ix, iy, n, n, ctx.s("plate"), channels=2)
    warp = nz.fbm(u, v, ctx.per_m(1.0), ctx.s("warp"), octaves=3)
    h = plate * (0.002 + 0.0003 * (rnd[..., 0] - 0.5) * (fx - 0.5) + 0.0002 * warp + 0.00002 * peel) \
        + 0.003 * rivet
    paint = ops.vary(ctx.col("paint"), nz.fbm(u, v, ctx.per_m(2), ctx.s("tone"), octaves=4), 0.05)
    paint = paint * (0.96 + 0.08 * rnd[..., 1])[..., None]
    albedo = ops.lerp(ops.fill(ctx.shape, ctx.col("seam")), paint, ops.smoothstep(0.0, 0.3, plate)[..., None])
    seam_shadow = ops.smoothstep(seam_w * 0.5 + 0.012, seam_w * 0.5, d) * 0.25
    albedo = albedo * (1.0 + 0.45 * rivet - 0.3 * halo - seam_shadow)[..., None]
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(peel)) - 0.05 * rivet + (1.0 - plate) * 0.2
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.003, 0.01), ao_depth_m=0.002)
    weather(ctx, m, edge_radius_m=0.003, cavity_radius_m=0.006, wear_lighten=0.06)
    return m
