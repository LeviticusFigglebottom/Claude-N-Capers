#!/usr/bin/env python3
"""Write ENV D's character material library (D1-02, D-041).

    python3 tools/blender/characters/make_materials.py [--check] [--only char_x,char_y]

For every ``char_*`` id used by ENV D assets (bodies: skin, eyes, hair from ``_body``; masks;
outfits; see ``_outfit_palette.all_char_materials()``) this writes

* ``game/assets/characters/_textures/<id>/tex_<id>_{albedo,orm,normal}.png`` (+ ``.import``,
  ``SOURCE.txt``): small tileable procedural textures, 256 px over 2 m,
* ``game/world/materials/<id>.tres``: an ``ORMMaterial3D`` in ENV C's library format
  (``resource_name = "M_<id>"``, ORM drives AO/roughness/metallic with multipliers 1.0, normal map
  on, mesh UVs, ``metadata/uv_tile_m = 2.0``: 1 UV unit = 2 m, which is what the outfit scripts'
  ``uv.box_project(density=512, texture_px=1024)`` produces). Skin adds a light subsurface scatter.
* The body skins ``char_skin_<tone>[_stubble|_beard]`` are 512 px and carry the face colour baked in
  body-UV space (``tint_atlas``: ``_body.skin_tint`` rasterised over the default body's skin faces;
  the body UVs come from the shared basis, so one atlas fits every body).

Textures are generated with ENV C's ``tools/texgen`` library (used read-only: noise, ops,
``materials.base.Ctx/Maps/finalize`` which enforces the style-guide albedo rules (linear luminance
0.04-0.85, saturation <= 0.75, never near the interactable accent) and the ``godot`` writers).
The generators here are ENV D's: one per material *kind* (cloth, knit, leather, skin, hair, eye,
metal, plastic, gloss; the achievement mask surfaces stone, bronze, canvas, rust, velvet, crinkle, gilt live in
``_mask_surfaces.py``), coloured from the palette, so the glb placeholder colours and the game
materials come from the same numbers. Deterministic (seed = crc32(id), texgen's PNG writer).
Adding a material = adding an id to ``_outfit_palette`` (or ``_body``) and re-running this.
Not an asset script (no ASSET_ID/VARIANTS), so build.py skips it.
"""

from __future__ import annotations

import argparse
import functools
import pathlib
import re
import sys
import zlib

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO / "tools"))

import numpy as np
from texgen import godot, ops, presets
from texgen import io as tio
from texgen import noise as nz
from texgen.materials.base import Ctx, Maps, finalize

from _mask_surfaces import GENERATORS as MASK_GENERATORS
from _mask_surfaces import MASK_KINDS
from _outfit_palette import SKIN_SPECULAR, all_char_materials

MAT_DIR = REPO / "game" / "world" / "materials"
TEX_DIR = REPO / "game" / "assets" / "characters" / "_textures"
TEX_RES = "res://assets/characters/_textures"
SIZE = 256
SKIN_SIZE = 512          # the skin atlas carries the face colour: head tile = 256 px round the head
MASK_SIZE = 512          # mask surface kinds (_mask_surfaces): one tile ~ 12 cm of mask face
HAIR_SIZE = 512          # hair: body hair UVs go twice round the head (_head.hair_uvs): ~0.5 mm/texel across strands
SKIN_RE = re.compile(r"^char_skin_(\d)(_stubble|_beard)?$")
TILE_M = 2.0
FORBIDDEN = {"#4FD1E8"}
#: ORM materials that also glow: id -> (emission sRGB hex, energy). Style guide §3: emissives may
#: exceed the albedo saturation cap (the albedo itself stays in the palette rules). ENV A drives
#: the energy at runtime (Phantom goggles: SpecialTweak.phantom_goggle_energy_idle/charge).
EMISSION = {"char_goggle_glow": ("#3BFF6A", 1.0), "char_prop_ember": ("#FF6A2A", 1.6),
            # D-165: white screen-print fluoresces under the club's UV wash, so the door team's back print reads at
            # 10 m under the magenta / violet floor light
            "char_club_print": ("#D6D2FF", 0.6),
            # D-165 (LEAD): TAC Heavy's back stripes + helmet band, real retroreflective tape: a faint return so the
            # near-black heavy reads from behind on dark maps; subtle, never a light source, no emissive on the front
            "char_retro_tape": ("#E8ECEF", 0.3)}


#: D-116: open long garments (robe, long coats, below the knee) show their inside where they part, a front split
#: gaping on a seated body or a hem flaring on a stride; drawn single-sided, the far panel vanished there and left only
#: its folded hem edge floating as a thin strip. These cloths render both faces (cull_mode = 2, CULL_DISABLED).
DOUBLE_SIDED = {"char_club_coral", "char_club_satin_ivory", "char_club_satin_black",   # D-165 club dresses, skirts
                "char_silk_ice", "char_coat_ice", "char_crew_rook_coat", "char_coat_camel", "char_coat_command",
                # D-116 stride drape: dress and skirt cloths (g.dress, n.skirt). The skirt between the legs folds over
                # on a stride or squat, and a squat or a seat shows the skirt's inside past the hem: single-sided, both
                # read as holes (a hem ring floating round the knees)
                "char_dress_black", "char_satin_wine", "char_satin_sapphire", "char_satin_amethyst", "char_satin_gold",
                "char_satin_teal", "char_silk_graphite", "char_bank_slate_dark", "char_suit_grey",
                # OF-D1: the navy pencil skirt; the long wool coats (below the knee)
                "char_skirt_navy", "char_coat_heather", "char_coat_stone",
                # RT-D1: the waitress's dress; the commuter's long mac
                "char_diner_rose", "char_mac_cherry"}


def srgb_bytes(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def check(mats: dict) -> list[str]:
    """Palette sanity (the per-texel rules are enforced again by texgen's ``finalize``)."""
    errors = []
    for mid, (hexc, rough, metal, kind) in mats.items():
        if not mid.startswith("char_"):
            errors.append(f"{mid}: id must start with char_")
        r, g, b = srgb_bytes(hexc)
        lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if hexc.upper() in FORBIDDEN:
            errors.append(f"{mid}: reserved interactable accent")
        if not 30.0 <= lum <= 240.0:
            errors.append(f"{mid}: 8-bit luminance {lum:.0f} outside 30..240")
        if max(r, g, b) and (max(r, g, b) - min(r, g, b)) / max(r, g, b) > 0.75:
            errors.append(f"{mid}: saturation above 0.75")
        if not 0.0 <= rough <= 1.0 or metal not in (0.0, 1.0):
            errors.append(f"{mid}: roughness/metallic out of range")
        if metal == 1.0 and rough < 0.15:
            errors.append(f"{mid}: metal roughness below 0.15")
        if kind not in ("skin", "eye", "hair", "cloth", "leather", "metal", "plastic", "gloss", *MASK_KINDS):
            errors.append(f"{mid}: unknown kind {kind}")
    return errors


def kind_of(mid: str, kind: str) -> str:
    if kind == "cloth" and mid.startswith("char_knit_"):
        return "knit"
    return kind


# ---------------------------------------------------------------------------------------------
# generators: (ctx, base linear colour, roughness, metallic) -> Maps
# ---------------------------------------------------------------------------------------------
def _cloth(ctx: Ctx, base: np.ndarray, r: float, met: float, knit: bool = False) -> Maps:
    u, v = ctx.u, ctx.v
    heather = nz.fbm(u, v, ctx.per_m(4), ctx.s("heather"), octaves=4)
    slub = nz.value(u, v, (ctx.per_m(2), ctx.per_m(24)), ctx.s("slub"))
    alb = ops.vary(base, 0.6 * heather + 0.4 * (slub - 0.5), 0.07)
    if knit:
        rib = 0.5 + 0.5 * np.cos(2 * np.pi * u * ctx.per_m(16))
        h = 0.0004 * rib + 0.0001 * heather
        alb = alb * (0.94 + 0.08 * rib)[..., None]
    else:
        twill = nz.fbm(u, v, ctx.per_m(12), ctx.s("twill"), octaves=3)
        h = 0.00012 * twill + 0.00025 * nz.fbm(u, v, ctx.per_m(3), ctx.s("drape"), octaves=3)
    rough = np.clip(r + 0.04 * heather, 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), h, normal_strength=0.8,
                ao_radii_m=(0.01, 0.03), ao_depth_m=0.001, ao_strength=0.3)


def _leather(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    u, v = ctx.u, ctx.v
    tone = nz.fbm(u, v, ctx.per_m(3), ctx.s("tone"), octaves=4)
    wu, wv = nz.warp(u, v, 0.06, ctx.per_m(2), ctx.s("w"))
    wrinkle = ops.smoothstep(0.7, 0.97, nz.ridged(wu, wv, ctx.per_m(6), ctx.s("wr"), octaves=3, sharpness=5.0))
    grain = nz.fbm(u, v, ctx.per_m(24), ctx.s("grain"), octaves=2)
    alb = ops.vary(base, 0.7 * tone - 0.4 * wrinkle, 0.10)
    h = 0.00012 * grain - 0.0004 * wrinkle
    rough = np.clip(r + 0.10 * wrinkle + 0.04 * grain, 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), h, normal_strength=1.0,
                ao_radii_m=(0.01, 0.03), ao_depth_m=0.0006, ao_strength=0.4)


def _skin(ctx: Ctx, base: np.ndarray, r: float, met: float, tint: np.ndarray | None = None) -> Maps:
    """GSR skin: low-frequency mottling only (no grain). Broad tone blotches, a warm/olive hue
    drift, a light pore bump and a roughness breakup, times ``tint`` (the face colour in body-UV
    space, ``tint_atlas``) for the ``char_skin_*`` body materials."""
    u, v = ctx.u, ctx.v
    broad = nz.fbm(u, v, ctx.per_m(5), ctx.s("mottle"), octaves=2)
    blot = nz.fbm(u, v, ctx.per_m(8), ctx.s("blot"), octaves=2)
    hue = nz.fbm(u, v, ctx.per_m(3), ctx.s("blush"), octaves=2)
    alb = ops.vary(base, 0.55 * broad + 0.45 * blot, 0.20)
    warm = ops.hex_to_linear("#B0705A")
    olive = ops.hex_to_linear("#B89A6E")
    alb = ops.hue_shift_toward(alb, warm, np.clip(0.10 + 0.30 * blot, 0.0, 0.22))
    alb = ops.hue_shift_toward(alb, olive, np.clip(-0.35 * hue, 0.0, 0.10))
    if tint is not None:                     # the face colour, baked in body-UV space
        alb = alb * tint
    h = 0.00006 * nz.fbm(u, v, ctx.per_m(24), ctx.s("pore"), octaves=2) + 0.00010 * broad
    sheen = nz.fbm(u, v, ctx.per_m(8), ctx.s("sheen"), octaves=2)
    rough = np.clip(r + 0.09 * sheen + 0.03 * blot, 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), h, normal_strength=0.5,
                ao_radii_m=(0.01,), ao_depth_m=0.001, ao_strength=0.1)


@functools.lru_cache(maxsize=1)
def _tint_vertices():
    """Per-vertex skin tint of the default body without and with a full beard shadow, plus the
    body-UV corners of every skin face (UVs come from the shared basis: one atlas fits all bodies)."""
    import dataclasses

    import _body as body

    bd, _hair = body.body_mesh_data(body.body_params({}))
    t0 = np.array(body.skin_tint(bd))
    t1 = np.array(body.skin_tint(dataclasses.replace(bd, params=dict(bd.params, beard_shadow=1.0))))
    uvs = body.face_uvs(bd.faces, bd.face_region, bd.face_mat, bd.face_side, bd.basis, float(bd.params["height"]))
    tris = []
    for f, mt, uv in zip(bd.faces, bd.face_mat, uvs):
        if mt != "skin":
            continue
        for i in range(1, len(f) - 1):
            tris.append(((f[0], f[i], f[i + 1]), (uv[0], uv[i], uv[i + 1])))
    return t0, t1, tris


def tint_atlas(size: int, beard: float) -> np.ndarray:
    """(size, size, 3) linear albedo multipliers in body-UV space (row 0 = top = UV v 1): the
    ``_body.skin_tint`` of every skin vertex rasterised over its faces, white elsewhere, dilated a
    few texels past the UV island borders so bilinear filtering never pulls in white."""
    t0, t1, tris = _tint_vertices()
    tv = t0 * (1.0 + (t1 / t0 - 1.0) * beard)
    acc = np.ones((size, size, 3))
    cov = np.zeros((size, size), dtype=bool)
    for (a, b, c), (ua, ub, uc) in tris:
        ta, tb, tc = tv[a], tv[b], tv[c]
        if (ta == 1.0).all() and (tb == 1.0).all() and (tc == 1.0).all():
            continue
        p = np.array([[ua[0] * size, (1.0 - ua[1]) * size], [ub[0] * size, (1.0 - ub[1]) * size],
                      [uc[0] * size, (1.0 - uc[1]) * size]])
        x0, y0 = np.floor(p.min(0)).astype(int)
        x1, y1 = np.ceil(p.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-12:
            continue
        l0 = ((p[1, 1] - p[2, 1]) * (xs - p[2, 0]) + (p[2, 0] - p[1, 0]) * (ys - p[2, 1])) / d
        l1 = ((p[2, 1] - p[0, 1]) * (xs - p[2, 0]) + (p[0, 0] - p[2, 0]) * (ys - p[2, 1])) / d
        l2 = 1.0 - l0 - l1
        inside = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if not inside.any():
            continue
        col = l0[..., None] * ta + l1[..., None] * tb + l2[..., None] * tc
        sub = acc[y0:y1 + 1, x0:x1 + 1]
        sub[inside] = col[inside]
        cov[y0:y1 + 1, x0:x1 + 1] |= inside
    for _ in range(3):                       # dilate tinted texels outwards
        grown = acc.copy()
        newcov = cov.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.roll(np.roll(acc, dy, 0), dx, 1)
            scov = np.roll(np.roll(cov, dy, 0), dx, 1)
            take = scov & ~newcov
            grown[take] = src[take]
            newcov |= take
        acc, cov = grown, newcov
    return acc


def _hair(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    """GSR hair: strand grain. The texture itself is only mildly elongated along v (so box-projected
    hair gear, buns and fringes, shows no projection seams); the body hair UVs (``_head.hair_uvs``)
    follow the strands and squeeze it across them (u = twice round the combing pole, v slow along
    the strand), which turns the grain into long strands and strand groups. Crest lines catch the
    light and the roughness follows them (streaky, anisotropic-looking highlights)."""
    u, v = ctx.u, ctx.v
    wu = u + 0.003 * nz.fbm(u, v, (8, 8), ctx.s("wave"), octaves=2)          # strands wave a little
    groups = nz.fbm(wu, v, (24, 12), ctx.s("groups"), octaves=2)             # strand groups
    fine = nz.value(wu, v, (192, 96), ctx.s("strand"))                      # single strands
    crest = nz.ridged(wu, v, (96, 48), ctx.s("crest"), octaves=2, sharpness=3.0)
    tone = nz.fbm(u, v, (6, 6), ctx.s("tone"), octaves=2)
    # v ~ 0 is the whorl/crown on the body hair (the strands converge there): calm the fine detail
    calm = ops.smoothstep(0.0, 0.003, np.minimum(v, 1.0 - v))
    fine, crest = fine * calm, 0.5 + (crest - 0.5) * calm
    alb = ops.vary(base, 0.30 * fine + 0.45 * groups + 0.35 * (crest - 0.5) + 0.25 * tone, 0.30)
    h = 0.0011 * groups + 0.00035 * fine + 0.0005 * crest
    rough = np.clip(r - 0.16 * (crest - 0.5) - 0.05 * fine + 0.06 * np.abs(groups), 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), h, normal_strength=2.0,
                ao_radii_m=(0.006, 0.016), ao_depth_m=0.0007, ao_strength=0.45)


def _smooth(ctx: Ctx, base: np.ndarray, r: float, met: float, amount: float = 0.03, brushed: bool = False) -> Maps:
    u, v = ctx.u, ctx.v
    if brushed:
        f = nz.value(u, v, (ctx.per_m(2), ctx.per_m(60)), ctx.s("brush")) - 0.5
    else:
        f = nz.fbm(u, v, ctx.per_m(6), ctx.s("tone"), octaves=3)
    alb = ops.vary(base, f, amount)
    h = 0.00004 * f
    rough = np.clip(r + 0.04 * f, 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), h, normal_strength=0.4,
                ao_radii_m=(0.01,), ao_depth_m=0.001, ao_strength=0.05)


def generate(ctx: Ctx, kind: str, hexc: str, rough: float, metal: float, tint: np.ndarray | None = None) -> Maps:
    base = ops.hex_to_linear(hexc)
    if tint is not None:
        return _skin(ctx, base, rough, metal, tint)
    if kind in ("cloth", "knit"):
        return _cloth(ctx, base, rough, metal, knit=kind == "knit")
    if kind == "leather":
        return _leather(ctx, base, rough, metal)
    if kind == "skin":
        return _skin(ctx, base, rough, metal)
    if kind == "hair":
        return _hair(ctx, base, rough, metal)
    if kind in MASK_GENERATORS:
        return MASK_GENERATORS[kind](ctx, base, rough, metal)
    if kind == "metal":
        return _smooth(ctx, base, rough, metal, 0.04, brushed=True)
    return _smooth(ctx, base, rough, metal, 0.02 if kind in ("eye", "gloss") else 0.03)


def build_one(mid: str, spec: tuple, preset: dict) -> dict:
    hexc, rough, metal, kind = spec
    k = kind_of(mid, kind)
    sk = SKIN_RE.match(mid)
    tint = None
    size, seed_id, extra = SIZE, mid, []
    if k in MASK_KINDS:
        size = MASK_SIZE
        extra = ["use: achievement mask surface grain (MaskMaterialDef, content/docs/masks.md); features "
                 "sized per texture tile (~12 cm of mask at uv_tile 1.5); generator tools/blender/characters/_mask_surfaces.py"]
    if k == "hair":
        size = HAIR_SIZE
        extra = ["uv: body hair along the strands (tools/blender/characters/_head.py hair_uvs); detail along v"]
    if sk:
        # the body skins: one tileable base per tone (same seed for its beard variants) times the
        # face colour atlas at the variant's beard strength
        import _body as body

        strength = next(st for sfx, st, _hi in body.BEARD_LEVELS if sfx == (sk.group(2) or ""))
        size, seed_id = SKIN_SIZE, f"char_skin_{sk.group(1)}"
        tint = tint_atlas(size, strength)
        extra = [f"face colour: _body.skin_tint rasterised in body-UV space (beard strength {strength})"]
    ctx = Ctx(lib_id=mid, size=size, tile_m=TILE_M, seed=zlib.crc32(seed_id.encode("utf-8")),
              params={}, rules=preset["rules"], scales={"wear": 0.0, "grime": 0.0})
    enc = finalize(ctx, generate(ctx, k, hexc, rough, metal, tint))
    d = TEX_DIR / mid
    files = {key: d / f"tex_{mid}_{key}.png" for key in ("albedo", "orm", "normal")}
    tio.write_png(files["albedo"], enc.albedo)
    tio.write_png(files["orm"], enc.orm)
    tio.write_png(files["normal"], enc.normal)
    for key, f in files.items():
        godot.ensure_import(f, "texture", "CompressedTexture2D", godot.IMPORT_PARAMS[key])
    tio.write_text(d / "SOURCE.txt", "\n".join([
        f"generator: python3 tools/blender/characters/make_materials.py --only {mid}",
        "palette: tools/blender/characters/_outfit_palette.py (all_char_materials)",
        f"kind: {k}; colour {hexc}; roughness {rough}; metallic {metal}"
        + (f"; metallic_specular {SKIN_SPECULAR}" if sk else ""),
        f"seed: {ctx.seed} (zlib.crc32('{seed_id}'))",
        f"size_px: {size}; tile_m: {TILE_M} (1 UV unit = {TILE_M} m); texel_density_px_per_m: {size / TILE_M:g}",
        *extra,
        "albedo: sRGB; orm: linear R=AO G=roughness B=metallic; normal: tangent space OpenGL (Y+)",
        "texgen (ENV C, read-only): noise, ops, materials.base.finalize, io, godot",
        "edit policy: generated, never edit by hand",
        "",
    ]))
    tres = MAT_DIR / f"{mid}.tres"
    godot.write_material(tres, mid, f"{TEX_RES}/{mid}", "opaque", TILE_M,
                         specular=SKIN_SPECULAR if sk else None)
    if k == "skin":
        text = tres.read_text(encoding="utf-8")
        text = text.replace("ao_enabled = true\n", "ao_enabled = true\nsubsurf_scatter_enabled = true\n"
                            "subsurf_scatter_strength = 0.25\nsubsurf_scatter_skin_mode = true\n")
        tio.write_text(tres, text)
    if mid in DOUBLE_SIDED:
        text = tres.read_text(encoding="utf-8")
        text = text.replace("ao_enabled = true\n", "ao_enabled = true\ncull_mode = 2\n")
        tio.write_text(tres, text)
    if mid in EMISSION:
        eh, energy = EMISSION[mid]
        r, g_, b = (c / 255.0 for c in srgb_bytes(eh))
        text = tres.read_text(encoding="utf-8")
        text = text.replace("ao_enabled = true\n", "ao_enabled = true\nemission_enabled = true\n"
                            f"emission = Color({r:.4f}, {g_:.4f}, {b:.4f}, 1)\n"
                            f"emission_energy_multiplier = {energy:.1f}\n")
        tio.write_text(tres, text)
    return enc.stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="only validate the palette")
    ap.add_argument("--only", default="", help="comma-separated ids")
    args = ap.parse_args()
    mats = all_char_materials()
    errors = check(mats)
    for e in errors:
        print(f"ERROR {e}")
    if errors:
        return 1
    if args.check:
        print(f"ok: {len(mats)} char_* materials")
        return 0
    only = {x for x in args.only.split(",") if x}
    preset = presets.load("gsr")
    n = 0
    for mid, spec in mats.items():
        if only and mid not in only:
            continue
        stats = build_one(mid, spec, preset)
        if only:
            print(f"{mid}: {stats}")
        n += 1
    print(f"wrote {n} materials: game/world/materials/char_*.tres + game/assets/characters/_textures/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
