"""Upholstery fabric: coarse plain weave (stylised mid-frequency), heathered yarn."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    cells = ctx.per_m(ctx.p("weave_cells_per_m"))
    x = u * cells
    y = v * cells
    ix = np.floor(x)
    iy = np.floor(y)
    fx = x - ix
    fy = y - iy
    sign = np.where(np.mod(ix + iy, 2) == 0, 1.0, -1.0)
    prof_x = np.sin(np.pi * fx)
    prof_y = np.sin(np.pi * fy)
    warp_h = prof_x * (0.6 + 0.4 * sign * np.sin(np.pi * fy))
    weft_h = prof_y * (0.6 - 0.4 * sign * np.sin(np.pi * fx))
    on_top = warp_h > weft_h
    weave = np.maximum(warp_h, weft_h)

    slub_u = nz.value(u, v, (ctx.per_m(6), cells), ctx.s("slubu"))
    slub_v = nz.value(u, v, (cells, ctx.per_m(6)), ctx.s("slubv"))
    yarn = np.where(on_top, slub_v, slub_u)
    low = nz.fbm(u, v, ctx.per_m(2), ctx.s("low"), octaves=4)
    heather = ops.smoothstep(0.1, 0.7, yarn + 0.3 * low)
    albedo = ops.lerp(ops.fill(ctx.shape, ctx.col("base")), ops.fill(ctx.shape, ctx.col("heather")),
                      (heather * np.where(on_top, 0.45, 0.25))[..., None])
    albedo = albedo * (0.82 + 0.22 * weave)[..., None]
    h = 0.0007 * weave + 0.0001 * yarn
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r1, r0, weave)
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=0.8,
             ao_radii_m=(0.003, 0.01), ao_depth_m=0.0008, ao_strength=0.6)
    weather(ctx, m, edge_radius_m=0.01, cavity_radius_m=0.02, wear_lighten=0.1)
    return m
