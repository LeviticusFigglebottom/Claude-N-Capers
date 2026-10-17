"""Mask surface material kinds (D-ACH): stone, bronze, canvas, rust, velvet,
crinkle, gilt. Used by ``make_materials.py``.

Grain for the achievement-reward ``MaskMaterialDef``s (``content/docs/masks.md``): the mask shader
(``content/masks/mask_surface.gdshader``) keeps only the albedo *luminance* (divided by
``detail_mean``, times the colour pair), the ORM roughness/AO and the normal map, so every feature
here reads in luminance, roughness and relief. One texture tile covers about 12 cm of mask face
(``uv_tile`` ~1.5 over a ~0.18 m wide mask), so feature counts are given per texture tile and
heights in texels (``px`` = ``ctx.pixel_m``: a 1 px rise over 1 texel is a 45 degree slope).
Uses ENV C's texgen read-only (noise, ops, Ctx/Maps). Deterministic: every random draw comes from
``ctx.s(name)`` child seeds.
"""

from __future__ import annotations

import numpy as np
from texgen import noise as nz
from texgen import ops
from texgen.materials.base import Ctx, Maps

MASK_KINDS = ("stone", "bronze", "canvas", "rust", "velvet", "crinkle", "gilt")


def _wrap(d: np.ndarray) -> np.ndarray:
    """Signed tileable offset in [-0.5, 0.5)."""
    return np.mod(d + 0.5, 1.0) - 0.5


def _spots(u: np.ndarray, v: np.ndarray, n: int, seed: int, r0: float, r1: float, share: float,
           jitter: float = 1.0) -> np.ndarray:
    """Soft round dots on a jittered ``n`` x ``n`` grid, ``share`` of the cells lit."""
    f1, _f2, rid, _dx, _dy = nz.worley(u, v, n, seed, jitter=jitter)
    return (1.0 - ops.smoothstep(r0, r1, f1)) * (rid < share)


def stone(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    """Honed limestone: soft cream-grey clouding, faint bedding, fine calcite speckle, sparse fossil
    shell fragments (ribbed crescent arcs) and tiny pores. Flat honed finish."""
    u, v, px = ctx.u, ctx.v, ctx.pixel_m
    cloud = nz.fbm(u, v, 3, ctx.s("cloud"), octaves=5, gain=0.55)
    _wu, wv = nz.warp(u, v, 0.05, 2, ctx.s("bedw"))
    bed = np.sin(2 * np.pi * (2 * wv + 0.25 * cloud))
    f1, _f2, rid, _dx, _dy = nz.worley(u, v, 90, ctx.s("speck"), jitter=0.8)
    dot = 1.0 - ops.smoothstep(0.14, 0.30, f1)
    dark = dot * (rid < 0.22)
    light = dot * (rid > 0.80)
    shell = np.zeros(ctx.shape)
    ribbed = np.zeros(ctx.shape)
    for k, (n, frac) in enumerate(((7, 0.75), (13, 0.45))):
        _g1, _g2, grid, gdx, gdy = nz.worley(u, v, n, ctx.s(f"shell{k}"), jitter=0.5)
        rad = 0.20 + 0.16 * np.mod(grid * 7.31, 1.0)
        ang = 2 * np.pi * np.mod(grid * 3.17, 1.0)
        span = 0.15 + 0.55 * np.mod(grid * 5.53, 1.0)          # how much of the ring survives
        qx, qy = -gdx, -gdy                                      # feature point -> texel (cells)
        dist = np.sqrt(qx * qx + qy * qy) + 1e-6
        facing = (qx * np.cos(ang) + qy * np.sin(ang)) / dist
        thick = 0.018 + 0.03 * np.mod(grid * 11.7, 1.0) * (0.5 + 0.5 * facing)   # thins towards the tips
        arc = (1.0 - ops.smoothstep(thick, thick + 0.025, np.abs(dist - rad))) \
            * ops.smoothstep(-span, -span + 0.12, facing) * (grid < frac)
        arc = arc * ops.smoothstep(-0.35, 0.1, nz.fbm(u, v, 24, ctx.s(f"break{k}"), octaves=2))
        ribs = 0.5 + 0.5 * np.cos(np.arctan2(qy, qx) * 18.0)
        inner = (1.0 - ops.smoothstep(rad - 0.02, rad, dist)) * ops.smoothstep(0.0, 0.3, facing + span) \
            * (grid < frac * 0.6)
        shell = np.maximum(shell, arc)
        ribbed = np.maximum(ribbed, inner * ribs * 0.35)
    pore = _spots(u, v, 40, ctx.s("pore"), 0.05, 0.13, 0.35)
    lumf = 0.55 * cloud + 0.12 * bed - 0.9 * dark + 0.45 * light + 0.40 * shell + 0.12 * ribbed - 0.6 * pore
    alb = ops.vary(base, lumf, 0.22)
    warm = ops.hex_to_linear("#D2BF98")
    alb = ops.hue_shift_toward(alb, warm, np.clip(0.25 * shell + 0.15 * (cloud + 0.3), 0.0, 0.35))
    hone = nz.fbm(u, v, 64, ctx.s("hone"), octaves=2)
    h = px * (0.4 * cloud + 0.35 * shell + 0.25 * ribbed - 0.8 * pore + 0.08 * hone)
    rough = np.clip(r + 0.05 * cloud - 0.10 * shell + 0.08 * pore, 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), h, normal_strength=1.0,
                ao_radii_m=(2 * px, 6 * px), ao_depth_m=1.0 * px, ao_strength=0.5)


def bronze(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    """Statuary bronze: cast undulation, polished warm high points, green-brown patina settled into
    the low areas (mottled), fine casting porosity. The patina is rough and non-metallic."""
    u, v, px = ctx.u, ctx.v, ctx.pixel_m
    wu, wv = nz.warp(u, v, 0.08, 2, ctx.s("w"))
    relief = nz.fbm(wu, wv, 3, ctx.s("relief"), octaves=6, gain=0.55)
    hammer = ops.blur(nz.worley(u, v, 22, ctx.s("hammer"), jitter=0.9)[0], 2.5)  # soft chasing dents
    fine = nz.fbm(u, v, 48, ctx.s("fine"), octaves=3)
    height = relief + 0.12 * hammer
    mot = ops.remap01(nz.fbm(wu, wv, 6, ctx.s("mottle"), octaves=5, gain=0.6))
    low = ops.remap01(-ops.blur(height, 3.0))
    patina = ops.smoothstep(0.40, 0.72, 0.6 * low + 0.55 * mot + 0.10 * fine)
    hi = ops.smoothstep(0.55, 0.85, ops.remap01(height))
    pore = _spots(u, v, 70, ctx.s("pore"), 0.06, 0.16, 0.25)
    alb = ops.vary(base, 0.6 * relief + 0.2 * fine, 0.10)
    gold = ops.hex_to_linear("#E8C27A")
    alb = ops.lerp(alb, alb * (gold / gold.max()) * 1.35, hi[..., None] * 0.45)
    pat_col = ops.vary(ops.hex_to_linear("#4A4D31"), nz.fbm(u, v, 12, ctx.s("pc"), octaves=3), 0.25)
    pat = ops.lerp(pat_col, ops.fill(ctx.shape, ops.hex_to_linear("#3B3122")),
                   ops.smoothstep(0.4, 0.9, mot)[..., None] * 0.6)
    alb = ops.lerp(alb, pat, patina[..., None] * 0.85)
    alb = alb * (1.0 - 0.5 * pore)[..., None]
    crust = nz.fbm(u, v, 96, ctx.s("crust"), octaves=2)
    h = px * (2.5 * height + 0.15 * fine - 0.8 * pore + 0.25 * patina * crust)
    rough = np.clip(r + 0.10 * fine - 0.12 * hi + 0.40 * patina + 0.2 * pore
                    + 0.05 * nz.fbm(u, v, 128, ctx.s("micro"), octaves=2), 0.0, 1.0)  # micro breakup (also dithers BC blocks)
    metal = np.clip(met * (1.0 - 0.75 * patina), 0.0, 1.0)
    return Maps(alb, rough, metal, h, normal_strength=1.0,
                ao_radii_m=(3 * px, 10 * px), ao_depth_m=2.0 * px, ao_strength=0.6)


def canvas(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    """Primed artist's canvas: plain weave (over-under, slubby threads), gesso softening it, then
    impasto oil brush strokes: thick loaded starts, raised side ridges where the bristles push the
    paint aside, bristle grooves along the stroke and a lifted paint lip at the end. The strokes are
    glossier than the bare primer."""
    u, v, px = ctx.u, ctx.v, ctx.pixel_m
    n = 44                                            # threads per tile (~2.7 mm on the mask)
    x, y = u * n, v * n
    ix, iy = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64)
    fx, fy = x - ix, y - iy
    slub_w = 1.0 + 0.25 * nz.value(u, v, (n, 6), ctx.s("slubw"))
    slub_f = 1.0 + 0.25 * nz.value(u, v, (6, n), ctx.s("slubf"))
    tw = np.sin(np.pi * fx) ** 0.6 * slub_w
    tf = np.sin(np.pi * fy) ** 0.6 * slub_f
    top = np.mod(ix + iy, 2) == 0
    weave = np.where(top, tw * (0.7 + 0.3 * np.sin(np.pi * fy)), tf * (0.7 + 0.3 * np.sin(np.pi * fx)))
    weave = 0.75 * weave + 0.25 * np.maximum(tw, tf)
    h = 1.6 * weave
    lum = 0.25 * (weave - 0.6) + 0.10 * nz.fbm(u, v, 4, ctx.s("primer"), octaves=3)
    cover = np.zeros(ctx.shape)
    gloss = np.zeros(ctx.shape)
    rng = nz.make_rng(ctx.s("strokes"))
    flow = nz.fbm(u, v, 2, ctx.s("flow"), octaves=2)      # loosely shared stroke direction
    for li, (g, keep, scale) in enumerate(((5, 0.95, 1.0), (4, 0.75, 1.25), (6, 0.55, 0.8))):
        groove = 3.0 * nz.value(u, v, 24, ctx.s(f"br{li}"))
        for gy in range(g):
            for gx in range(g):
                draw = rng.uniform(size=8)
                if draw[0] > keep:
                    continue
                cx = (gx + 0.15 + 0.7 * draw[1]) / g
                cy = (gy + 0.15 + 0.7 * draw[2]) / g
                a = 0.6 + 2.2 * flow[int(cy * ctx.size) % ctx.size, int(cx * ctx.size) % ctx.size] \
                    + (draw[3] - 0.5) * 1.2
                length = scale * (0.13 + 0.12 * draw[4])
                width = scale * (0.07 + 0.04 * draw[5])
                load = 2.5 + 2.5 * draw[6]
                shade = (draw[7] - 0.5) * 0.28
                phase = 6.28 * draw[7]
                dx, dy = _wrap(u - cx), _wrap(v - cy)
                s = dx * np.cos(a) + dy * np.sin(a)
                t = -dx * np.sin(a) + dy * np.cos(a)
                along = s / length + 0.5                           # 0 = loaded start, 1 = tail
                half = 0.5 * width * (1.0 - 0.12 * np.clip(along, 0.0, 1.0) ** 2)
                tn = np.abs(t) / np.maximum(half, 1e-4)
                bristle = np.sin(t / width * 2 * np.pi * 7.0 + phase + groove)
                # rounded loaded start; the tail breaks up into dry-brush bristle streaks
                start = ops.smoothstep(0.0, 0.06, along + 0.06 * (1.0 - np.sqrt(np.clip(1.0 - tn * tn, 0.0, 1.0))))
                uneven = np.sin(t / width * 2 * np.pi * 11.3 + 1.7 * phase + 0.5 * groove)
                dry = ops.smoothstep(0.55, 1.05, along) * (0.6 - 0.3 * bristle - 0.4 * uneven)
                m = (1.0 - ops.smoothstep(0.85, 1.0, tn)) * start * (1.0 - ops.smoothstep(0.35, 0.6, dry)) \
                    * (1.0 - ops.smoothstep(1.0, 1.06, along))
                if not m.any():
                    continue
                thick = load * (1.0 - 0.6 * np.clip(along, 0.0, 1.0)) * (0.55 + 0.45 * tn ** 3)
                lip = 1.6 * np.exp(-((along - 0.97) / 0.04) ** 2)
                sh = 1.0 + thick + 0.45 * bristle + lip
                h = h * (1.0 - m) + np.maximum(sh, h) * m
                lum = lum * (1.0 - m) + (shade + 0.05 * bristle) * m
                cover = np.maximum(cover, m)
                gloss = np.maximum(gloss, m * (0.6 + 0.4 * ops.smoothstep(0.5, 1.0, tn)))
    alb = ops.vary(base, lum, 1.0)
    rf = nz.fbm(u, v, 16, ctx.s("rf"), octaves=2)
    rough = np.clip(r + 0.10 * (1.0 - cover) - 0.22 * gloss + 0.06 * rf, 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), px * 0.9 * h, normal_strength=1.0,
                ao_radii_m=(2 * px, 6 * px), ao_depth_m=1.5 * px, ao_strength=0.6)


def rust(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    """Weathered container steel: thick marine paint with clouding and sun-faded patches, sharp
    chipped-paint flakes with a grey primer rim over bare rusted steel, rust blooms blistering
    through the paint (scaly) and rust run-off streaks trailing down (+v) from them."""
    u, v, px = ctx.u, ctx.v, ctx.pixel_m
    wu, wv = nz.warp(u, v, 0.06, 3, ctx.s("w"))
    tone = nz.fbm(u, v, 3, ctx.s("tone"), octaves=4)
    fade = ops.smoothstep(0.55, 0.85, ops.remap01(nz.fbm(u, v, 2, ctx.s("fade"), octaves=4)))
    rf = ops.remap01(nz.fbm(wu, wv, 4, ctx.s("bloom"), octaves=6, gain=0.6))
    bloom_f = rf + 0.30 * _spots(u, v, 9, ctx.s("spot"), 0.10, 0.35, 0.45)
    bloom = ops.smoothstep(0.66, 0.74, bloom_f)
    halo = ops.smoothstep(0.56, 0.68, bloom_f) * (1.0 - bloom)
    cf = ops.remap01(nz.fbm(u, v, 6, ctx.s("chip"), octaves=6, gain=0.65))
    chip = ops.smoothstep(0.70, 0.715, cf + 0.12 * halo)
    primer = chip * (1.0 - ops.smoothstep(0.73, 0.76, cf))
    bare = np.maximum(bloom, chip - primer)
    src = ops.blur(np.maximum(bloom, 0.6 * chip), 1.5)
    trail = np.zeros(ctx.shape)
    for k in range(1, 40):
        trail = np.maximum(trail, np.roll(src, k * 3, axis=0) * (0.94 ** k))
    runs = ops.smoothstep(0.45, 0.85, ops.remap01(nz.value(u, v, (70, 3), ctx.s("runs"))
                                                  + 0.4 * nz.value(u, v, (140, 5), ctx.s("runs2"))))
    streak = np.clip(trail * (0.35 + 0.9 * runs), 0.0, 1.0) * (1.0 - bare)
    scale_n = nz.fbm(u, v, 40, ctx.s("scale"), octaves=3)
    paint = ops.vary(base, 0.5 * tone + 0.2 * nz.fbm(u, v, 24, ctx.s("pt"), octaves=2), 0.10)
    paint = ops.lerp(paint, paint * 1.35 + 0.01, fade[..., None] * 0.6)
    rust_a = ops.hex_to_linear("#6E3A1E")
    rust_b = ops.hex_to_linear("#3E2416")
    scale_t = ops.smoothstep(-0.3, 0.5, scale_n + 1.2 * (rf - 0.7))
    rust_col = ops.lerp(ops.fill(ctx.shape, rust_a), ops.fill(ctx.shape, rust_b), scale_t[..., None])
    alb = ops.lerp(paint, ops.lerp(paint, ops.fill(ctx.shape, rust_a), 0.45), streak[..., None] * 0.8)
    alb = ops.lerp(alb, alb * 0.85 + rust_a * 0.08, halo[..., None] * 0.5)
    alb = ops.lerp(alb, ops.fill(ctx.shape, ops.hex_to_linear("#77736A")), primer[..., None])
    alb = ops.lerp(alb, rust_col, bare[..., None])
    blister = ops.remap01(nz.fbm(u, v, 30, ctx.s("blister"), octaves=2))
    h = 2.2 * (1.0 - bare) + 0.6 * primer \
        + bloom * (1.4 * ops.smoothstep(-0.2, 0.6, scale_n) + 0.8 * rf) \
        + halo * 0.9 * blister + 0.25 * tone
    rough = np.clip(r + 0.06 * tone + 0.20 * bare + 0.08 * streak + 0.05 * scale_n * bare, 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), px * h, normal_strength=1.0,
                ao_radii_m=(2 * px, 8 * px), ao_depth_m=1.5 * px, ao_strength=0.6)


def velvet(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    """Jeweller's display-case velvet: dense fine pile (per-fibre speckle), broad crushed-pile patches
    where the nap lies another way (lighter / darker sheen bands, smooth flowing shapes), short tufts;
    very matte. Neutral mid grey: the colour comes from the pair."""
    u, v, px = ctx.u, ctx.v, ctx.pixel_m
    wu, wv = nz.warp(u, v, 0.10, 2, ctx.s("w"), octaves=4)
    nap = nz.fbm(wu, wv, 3, ctx.s("nap"), octaves=4, gain=0.5)            # pile direction field
    sheen = np.sin(2 * np.pi * (1.5 * nap + 0.5 * nz.fbm(wu, wv, 5, ctx.s("sh"), octaves=3)))
    crush = ops.blur(ops.smoothstep(-0.7, 0.9, sheen), 5.0)
    fibre = nz.value(u, v, 256, ctx.s("fibre")) * 0.6 + 0.4 * nz.value(u, v, 128, ctx.s("fibre2"))
    tuft = nz.fbm(u, v, 40, ctx.s("tuft"), octaves=2)
    lum = 0.30 * (crush - 0.5) + 0.12 * fibre + 0.10 * tuft
    alb = ops.vary(base, lum, 1.0)
    h = px * (0.9 * fibre + 0.5 * tuft + 0.6 * crush)
    rough = np.clip(r - 0.10 * crush + 0.04 * fibre, 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), h, normal_strength=0.6,
                ao_radii_m=(1 * px, 3 * px), ao_depth_m=1.0 * px, ao_strength=0.5)


def crinkle(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    """Black crinkle (wrinkle-finish) safe paint: a dense network of fine meandering ridges (the skin
    of the paint shrinking as it cures), slightly glossier ridge tops, satin overall, plus faint
    handling scuffs."""
    u, v, px = ctx.u, ctx.v, ctx.pixel_m
    wu, wv = nz.warp(u, v, 0.012, 24, ctx.s("w"), octaves=3)
    rid = nz.ridged(wu, wv, 40, ctx.s("ridge"), octaves=3, sharpness=2.5)
    rid2 = nz.ridged(wv, wu, 64, ctx.s("ridge2"), octaves=2, sharpness=2.0)
    wr = 0.65 * rid + 0.35 * rid2
    scuff_f = nz.value(u, v, (3, 48), ctx.s("scuff"))
    scuff = ops.smoothstep(0.55, 0.85, scuff_f) * ops.smoothstep(0.5, 0.8, ops.remap01(nz.fbm(u, v, 3, ctx.s("sp"), octaves=3)))
    tone = nz.fbm(u, v, 3, ctx.s("tone"), octaves=3)
    lum = 0.35 * (wr - 0.5) + 0.10 * tone + 0.15 * scuff
    alb = ops.vary(base, lum, 1.0)
    h = px * (2.2 * wr - 0.4 * scuff * wr)
    rough = np.clip(r - 0.12 * (wr - 0.5) + 0.04 * tone - 0.08 * scuff, 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), h, normal_strength=1.0,
                ao_radii_m=(1 * px, 3 * px), ao_depth_m=1.0 * px, ao_strength=0.6)


def gilt(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    """Worn water gilding: square gold-leaf sheets laid in slightly skewed rows (each sheet its own
    tone and a raised overlap seam), burnished; the leaf rubbed through to the red bole on high
    points and along seams, with fine craquelure in the bole. Bole is rough and non-metal."""
    u, v, px = ctx.u, ctx.v, ctx.pixel_m
    n = 3                                                 # leaf sheets per tile (~3.7 cm on the mask)
    jit = 0.015 * nz.value(u, v, (1, n), ctx.s("rowj"))
    ix, iy, fx, fy = ops.tile_grid(u + jit, v, n, n, row_offset=0.37)
    cell = nz.cell_random(ix, iy, n, n, ctx.s("leaf"), channels=2)
    edge = np.minimum(np.minimum(fx, 1.0 - fx), np.minimum(fy, 1.0 - fy)) * (ctx.size / n)  # texels to seam
    seam = 1.0 - ops.smoothstep(0.5, 2.5, edge)
    lap = (ops.smoothstep(0.0, 0.02, fx) * (1.0 - ops.smoothstep(0.02, 0.05, fx))      # overlap ridge on the
           + ops.smoothstep(0.0, 0.02, fy) * (1.0 - ops.smoothstep(0.02, 0.05, fy)))    # leading edges only
    relief = nz.fbm(u, v, 3, ctx.s("relief"), octaves=5)
    wearf = ops.remap01(nz.fbm(u, v, 6, ctx.s("wear"), octaves=6, gain=0.6))
    rub = ops.smoothstep(0.70, 0.78, wearf + 0.10 * relief + 0.25 * seam * ops.remap01(nz.fbm(u, v, 20, ctx.s("sw"), octaves=2)))
    burnish = nz.value(u, v, (2, 60), ctx.s("burnish")) * 0.5 + 0.5 * nz.fbm(u, v, 12, ctx.s("bt"), octaves=2)
    gold = ops.vary(base, 0.35 * (cell[..., 0] - 0.5) + 0.12 * burnish + 0.15 * relief, 0.35)
    gold = gold * (1.0 - 0.10 * seam)[..., None]
    _f1, f2, _rid, _a, _b = nz.worley(u, v, 30, ctx.s("craq"), jitter=1.0)
    craq = 1.0 - ops.smoothstep(0.03, 0.08, f2 - _f1)
    bole = ops.vary(ops.hex_to_linear("#7A3424"), nz.fbm(u, v, 10, ctx.s("bole"), octaves=3) - 0.4 * craq, 0.25)
    alb = ops.lerp(gold, bole, rub[..., None])
    h = px * (1.2 * relief + 0.8 * lap - 0.6 * seam - 0.9 * rub - 0.4 * rub * craq)
    rough = np.clip(r + 0.06 * burnish + 0.08 * seam + 0.45 * rub, 0.0, 1.0)
    metal = np.clip(met * (1.0 - rub), 0.0, 1.0)
    return Maps(alb, rough, metal, h, normal_strength=1.0,
                ao_radii_m=(1 * px, 4 * px), ao_depth_m=1.0 * px, ao_strength=0.5)


GENERATORS = {"stone": stone, "bronze": bronze, "canvas": canvas, "rust": rust,
              "velvet": velvet, "crinkle": crinkle, "gilt": gilt}
