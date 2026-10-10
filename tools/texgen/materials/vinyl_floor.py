"""Vinyl composition tile (back of house): 0.5 m tiles, directional chip mottle, wax scuffs."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    tm = float(ctx.p("tile_m"))
    n = max(1, int(round(ctx.tile_m / tm)))
    tm = ctx.tile_m / n
    ix, iy, fx, fy = ops.tile_grid(u, v, n, n)
    rot = np.mod(ix + iy, 2) == 1
    a_u = nz.fbm(u, v, (ctx.per_m(6), ctx.per_m(45)), ctx.s("au"), octaves=4, gain=0.55)
    a_v = nz.fbm(u, v, (ctx.per_m(45), ctx.per_m(6)), ctx.s("av"), octaves=4, gain=0.55)
    mot = np.where(rot, a_v, a_u)
    speck = nz.value(u, v, ctx.per_m(90), ctx.s("speck"))
    dark = ops.smoothstep(-0.12, -0.25, mot + 0.15 * speck)
    light = ops.smoothstep(0.14, 0.26, mot + 0.15 * speck)
    base = np.where(rot[..., None], ops.fill(ctx.shape, ctx.col("tile_b")), ops.fill(ctx.shape, ctx.col("tile_a")))
    albedo = ops.lerp(base, ops.fill(ctx.shape, ctx.col("chip_dark")), (dark * 0.45)[..., None])
    albedo = ops.lerp(albedo, ops.fill(ctx.shape, ctx.col("chip_light")), (light * 0.4)[..., None])
    d = ops.edge_distance(fx, fy, tm, tm)
    seam = 1.0 - ops.smoothstep(0.0002, 0.0012, d)
    albedo = albedo * (1.0 - 0.25 * seam)[..., None]
    scuff = ops.smoothstep(0.55, 0.9, ops.remap01(nz.fbm(u, v, (ctx.per_m(3), ctx.per_m(1.5)), ctx.s("sc"), octaves=5)))
    h = -0.0006 * seam + 0.00002 * mot
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, scuff) + 0.3 * seam
    albedo = albedo * (1.0 - 0.06 * scuff * min(1.0, ctx.wear * 2.0))[..., None]
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.003,), ao_depth_m=0.0008, ao_strength=0.6)
    weather(ctx, m, edge_radius_m=0.003, cavity_radius_m=0.006)
    return m
