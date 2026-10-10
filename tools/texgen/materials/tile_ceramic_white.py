"""Glazed white ceramic wall/floor tile (restrooms), grout lines, slight per-tile tilt."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    tm = float(ctx.p("tile_m"))
    n = max(1, int(round(ctx.tile_m / tm)))
    tm = ctx.tile_m / n
    ix, iy, fx, fy = ops.tile_grid(u, v, n, n)
    d = ops.edge_distance(fx, fy, tm, tm)
    grout = float(ctx.p("grout_mm")) * 1e-3
    face = ops.bevel_profile(d, grout, 0.003)
    rnd = nz.cell_random(ix, iy, n, n, ctx.s("tile"), channels=3)
    tilt = 0.0005 * ((rnd[..., 0] - 0.5) * (fx - 0.5) + (rnd[..., 1] - 0.5) * (fy - 0.5))
    glaze = nz.fbm(u, v, ctx.per_m(5), ctx.s("glaze"), octaves=3)
    gnoise = nz.fbm(u, v, ctx.per_m(80), ctx.s("grout_n"), octaves=2)
    h = face * (0.002 + tilt + 0.00003 * glaze) + (1.0 - face) * 0.0002 * gnoise
    tcol = ctx.col("tile") * 1.0
    tile = ops.vary(tcol, (rnd[..., 2] - 0.5) * 2.0 + 0.5 * glaze, 0.02)
    gcol = ops.vary(ctx.col("grout"), gnoise, 0.08)
    albedo = ops.lerp(gcol, tile, ops.smoothstep(0.0, 0.25, face)[..., None])
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(ctx.p("grout_rough"), ops.lerp(r0, r1, ops.remap01(glaze)), face)
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.003, 0.008), ao_depth_m=0.0015)
    weather(ctx, m, edge_radius_m=0.003, cavity_radius_m=0.006)
    return m
