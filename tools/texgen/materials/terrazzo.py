"""Polished terrazzo: angular marble chips (two sizes) in a warm cement matrix."""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps, weather


def _chips(ctx: Ctx, u, v, cells_per_m: float, name: str, coverage: float, gap: tuple):
    period = ctx.per_m(cells_per_m)
    f1, f2, rid, _dx, _dy = nz.worley(u, v, period, ctx.s(name), jitter=0.95)
    aa = 0.8 * period / ctx.size
    pick = np.mod(rid * 7.13, 1.0)
    g = gap[0] + (gap[1] - gap[0]) * np.mod(rid * 3.71, 1.0)
    mask = ops.smoothstep(g - aa, g + aa, f2 - f1) * (pick < coverage)
    return mask, rid


def _palette(ctx: Ctx, rid: np.ndarray) -> np.ndarray:
    cols = [ops.hex_to_linear(c) for c in ctx.p("chips")]
    w = np.asarray(ctx.p("chip_weights"), dtype=np.float64)
    edges = np.cumsum(w / w.sum())
    idx = np.searchsorted(edges, np.mod(rid * 11.37, 1.0), side="right")
    idx = np.minimum(idx, len(cols) - 1)
    table = np.stack(cols)
    shade = 1.0 + 0.12 * (np.mod(rid * 5.17, 1.0) - 0.5)
    return table[idx] * shade[..., None]


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    wu, wv = nz.warp(u, v, 0.004, ctx.per_m(10.0), ctx.s("warp"), octaves=2)
    big, rid_b = _chips(ctx, wu, wv, ctx.p("big_cells_per_m"), "big", 0.75, (0.18, 0.55))
    wu2, wv2 = nz.warp(u + 0.37, v + 0.11, 0.003, ctx.per_m(20.0), ctx.s("warp2"), octaves=2)
    small, rid_s = _chips(ctx, wu2, wv2, ctx.p("small_cells_per_m"), "small", 0.55, (0.25, 0.6))
    small = small * (1.0 - big)

    matrix = ops.vary(ctx.col("matrix"), nz.fbm(u, v, ctx.per_m(3.0), ctx.s("mx"), octaves=4), 0.08)
    albedo = ops.lerp(matrix, _palette(ctx, rid_b), big[..., None])
    albedo = ops.lerp(albedo, _palette(ctx, rid_s), small[..., None])
    # Ground flush: only a hair of relief at chip borders.
    h = 0.00004 * (big + small)
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r0, r1, ops.remap01(nz.fbm(u, v, ctx.per_m(2.0), ctx.s("rough"), octaves=4)))
    rough = rough + 0.04 * (1.0 - big - small)
    m = Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0)
    weather(ctx, m, edge_radius_m=0.004, cavity_radius_m=0.01)
    return m
