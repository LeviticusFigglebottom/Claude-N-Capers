"""Carbon fibre, 2x2 twill under a clear coat (arrows, bow limbs).

Warp tows run along V, weft tows along U; a warp tow is on top where (i + j) mod 4 < 2, which
gives the diagonal twill steps. Each tow gets a rounded cross-section and fine fibre striations
along its own direction, so the normal map carries the anisotropic sheen; warp and weft also get
slightly different albedo (the "checker" a twill shows under light). The material's clear coat
(``clearcoat`` in the preset) adds the glossy top layer.
"""

import numpy as np

from texgen import noise as nz, ops
from texgen.materials.base import Ctx, Maps


def generate(ctx: Ctx) -> Maps:
    u, v = ctx.u, ctx.v
    n = ctx.per_m(ctx.p("tows_per_m"))
    x = u * n
    y = v * n
    i = np.floor(x)
    j = np.floor(y)
    fx = x - i
    fy = y - j
    warp_top = np.mod(i + j, 4) < 2
    prof_x = np.sin(np.pi * fx) ** 0.6   # warp tow cross-section (tow runs along V)
    prof_y = np.sin(np.pi * fy) ** 0.6   # weft tow cross-section (tow runs along U)
    fib_v = nz.value(u, v, (ctx.size // 2, ctx.per_m(8)), ctx.s("fibv"))
    fib_u = nz.value(u, v, (ctx.per_m(8), ctx.size // 2), ctx.s("fibu"))
    tow = np.where(warp_top, prof_x + 0.08 * fib_v, prof_y + 0.08 * fib_u)
    h = 0.00012 * tow

    low = nz.fbm(u, v, ctx.per_m(3), ctx.s("low"), octaves=3)
    base = ctx.col("base")
    sheen = ctx.col("sheen")
    albedo = np.where(warp_top[..., None], ops.fill(ctx.shape, base), ops.fill(ctx.shape, sheen))
    albedo = albedo * (0.85 + 0.2 * tow + 0.04 * low)[..., None]
    r0, r1 = ctx.p("rough")
    rough = ops.lerp(r1, r0, tow)
    return Maps(albedo, rough, np.zeros(ctx.shape), h, normal_strength=1.0,
                ao_radii_m=(0.001,), ao_depth_m=0.0001, ao_strength=0.4)
