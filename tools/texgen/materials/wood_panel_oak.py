"""Raised-and-fielded oak panelling (OF-C2): stiles and rails framing recessed, bevel-raised fields, the grain running
along the rails (U) and up the stiles and fields (V), satin lacquer. `bays` x `rows` panels per 2 m tile (0.5 m bays,
1 m high panels), so the bays line up on the 0.5 m grid. Tint a duplicate for walnut or a darker executive panelling."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def _grain(ctx: Ctx, a: np.ndarray, b: np.ndarray, name: str) -> tuple[np.ndarray, np.ndarray]:
    """Plain-sawn grain running along `a`, rings across `b` (both in tile units, 0..1): (late wood, pores)."""
    warp = nz.fbm(a, b, (ctx.per_m(0.75), ctx.per_m(2)), ctx.s(name + "w"), octaves=4, gain=0.5)
    fine = nz.fbm(a, b, (ctx.per_m(3), ctx.per_m(10)), ctx.s(name + "f"), octaves=3)
    field = b * float(ctx.p("rings")) + 0.9 * warp + 0.15 * fine
    ring = field - np.floor(field)
    late = ops.smoothstep(0.55, 0.85, ring) * (1.0 - ops.smoothstep(0.9, 1.0, ring))
    pores = ops.smoothstep(0.5, 0.9, nz.value(a, b, (ctx.per_m(3), ctx.per_m(120)), ctx.s(name + "p")))
    return late, pores


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    nx = int(ctx.p("bays"))
    ny = int(ctx.p("rows"))
    ix, iy, fx, fy = ops.tile_grid(u, v, nx, ny)
    pw = ctx.tile_m / nx
    ph = ctx.tile_m / ny
    stile = float(ctx.p("stile_mm")) * 1e-3
    bevel = float(ctx.p("bevel_mm")) * 1e-3
    dx = np.minimum(fx, 1.0 - fx) * pw          # from the bay's side edges (the stiles)
    dy = np.minimum(fy, 1.0 - fy) * ph          # from the bay's top / bottom (the rails)
    in_field = (dx > stile) & (dy > stile)
    is_stile = ~in_field & (dx < dy)
    dfield = np.minimum(dx, dy) - stile          # > 0 inside the field
    groove = 1.0 - ops.smoothstep(0.0, 0.0025, np.abs(dfield))
    raise_t = ops.clamp01(dfield / max(1e-6, bevel))
    h = np.where(in_field, -0.004 + 0.007 * np.sin(raise_t * np.pi * 0.5), 0.0) - 0.0015 * groove
    rnd = nz.cell_random(ix, iy, nx, ny, ctx.s("panel"), channels=3)
    late_u, pores_u = _grain(ctx, u, v, "gu")
    late_v, pores_v = _grain(ctx, v, u, "gv")
    vert = in_field | is_stile
    late = np.where(vert, late_v, late_u)
    pores = np.where(vert, pores_v, pores_u)
    tone = ops.remap01(nz.fbm(u, v, ctx.per_m(1.0), ctx.s("tone"), octaves=3))
    base = ops.lerp(ops.fill(ctx.shape, ctx.col("base")), ops.fill(ctx.shape, ctx.col("light")),
                    (0.4 * tone + 0.35 * rnd[..., 2])[..., None])
    albedo = ops.lerp(base, ops.fill(ctx.shape, ctx.col("late")), (late * 0.55)[..., None])
    slope = np.where(in_field, 1.0 - raise_t, 0.0) * (raise_t > 0.0)
    rail_shade = np.where(~vert & ~in_field, 0.06, 0.0)   # the rails catch less light than the stiles
    albedo = albedo * (1.0 - 0.2 * pores - 0.35 * groove - 0.12 * slope - rail_shade)[..., None]
    h = h - 0.0001 * pores
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, tone) + (ctx.p("pore_rough") - r1) * pores * 0.5 + 0.1 * groove
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
             ao_radii_m=(0.003, 0.01), ao_depth_m=0.004, ao_strength=0.8)
    weather(ctx, m, edge_radius_m=0.004, cavity_radius_m=0.008)
    return m
