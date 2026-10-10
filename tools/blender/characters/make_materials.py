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

Textures are generated with ENV C's ``tools/texgen`` library (used read-only: noise, ops,
``materials.base.Ctx/Maps/finalize`` which enforces the style-guide albedo rules (linear luminance
0.04-0.85, saturation <= 0.75, never near the interactable accent) and the ``godot`` writers).
The generators here are ENV D's: one per material *kind* (cloth, knit, leather, skin, hair, eye,
metal, plastic, gloss), coloured from the palette, so the glb placeholder colours and the game
materials come from the same numbers. Deterministic (seed = crc32(id), texgen's PNG writer).
Adding a material = adding an id to ``_outfit_palette`` (or ``_body``) and re-running this.
Not an asset script (no ASSET_ID/VARIANTS), so build.py skips it.
"""

from __future__ import annotations

import argparse
import pathlib
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

from _outfit_palette import all_char_materials

MAT_DIR = REPO / "game" / "world" / "materials"
TEX_DIR = REPO / "game" / "assets" / "characters" / "_textures"
TEX_RES = "res://assets/characters/_textures"
SIZE = 256
TILE_M = 2.0
FORBIDDEN = {"#4FD1E8"}
#: ORM materials that also glow: id -> (emission sRGB hex, energy). Style guide §3: emissives may
#: exceed the albedo saturation cap (the albedo itself stays in the palette rules). ENV A drives
#: the energy at runtime (Phantom goggles: SpecialTweak.phantom_goggle_energy_idle/charge).
EMISSION = {"char_goggle_glow": ("#3BFF6A", 1.0)}


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
        if kind not in ("skin", "eye", "hair", "cloth", "leather", "metal", "plastic", "gloss"):
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


def _skin(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    u, v = ctx.u, ctx.v
    mott = nz.fbm(u, v, ctx.per_m(5), ctx.s("mottle"), octaves=4)
    blush = nz.fbm(u, v, ctx.per_m(1), ctx.s("blush"), octaves=2)
    warm = ops.hex_to_linear("#B0705A")
    alb = ops.vary(base, 0.5 * mott, 0.05)
    alb = ops.hue_shift_toward(alb, warm, np.clip(0.12 * (blush + 0.3), 0.0, 0.12))
    h = 0.00008 * nz.fbm(u, v, ctx.per_m(20), ctx.s("pore"), octaves=2)
    rough = np.clip(r + 0.05 * mott, 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), h, normal_strength=0.5,
                ao_radii_m=(0.01,), ao_depth_m=0.001, ao_strength=0.1)


def _hair(ctx: Ctx, base: np.ndarray, r: float, met: float) -> Maps:
    u, v = ctx.u, ctx.v
    strands = nz.value(u, v, (ctx.per_m(40), ctx.per_m(2)), ctx.s("strand"))
    clump = nz.fbm(u, v, ctx.per_m(6), ctx.s("clump"), octaves=3)
    alb = ops.vary(base, 0.8 * (strands - 0.5) + 0.3 * clump, 0.16)
    h = 0.0002 * strands
    rough = np.clip(r + 0.08 * (strands - 0.5), 0.0, 1.0)
    return Maps(alb, rough, np.full(ctx.shape, met), h, normal_strength=0.6,
                ao_radii_m=(0.008,), ao_depth_m=0.0005, ao_strength=0.3)


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


def generate(ctx: Ctx, kind: str, hexc: str, rough: float, metal: float) -> Maps:
    base = ops.hex_to_linear(hexc)
    if kind in ("cloth", "knit"):
        return _cloth(ctx, base, rough, metal, knit=kind == "knit")
    if kind == "leather":
        return _leather(ctx, base, rough, metal)
    if kind == "skin":
        return _skin(ctx, base, rough, metal)
    if kind == "hair":
        return _hair(ctx, base, rough, metal)
    if kind == "metal":
        return _smooth(ctx, base, rough, metal, 0.04, brushed=True)
    return _smooth(ctx, base, rough, metal, 0.02 if kind in ("eye", "gloss") else 0.03)


def build_one(mid: str, spec: tuple, preset: dict) -> dict:
    hexc, rough, metal, kind = spec
    k = kind_of(mid, kind)
    ctx = Ctx(lib_id=mid, size=SIZE, tile_m=TILE_M, seed=zlib.crc32(mid.encode("utf-8")),
              params={}, rules=preset["rules"], scales={"wear": 0.0, "grime": 0.0})
    enc = finalize(ctx, generate(ctx, k, hexc, rough, metal))
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
        f"kind: {k}; colour {hexc}; roughness {rough}; metallic {metal}",
        f"seed: {ctx.seed} (zlib.crc32('{mid}'))",
        f"size_px: {SIZE}; tile_m: {TILE_M} (1 UV unit = {TILE_M} m); texel_density_px_per_m: {SIZE / TILE_M:g}",
        "albedo: sRGB; orm: linear R=AO G=roughness B=metallic; normal: tangent space OpenGL (Y+)",
        "texgen (ENV C, read-only): noise, ops, materials.base.finalize, io, godot",
        "edit policy: generated, never edit by hand",
        "",
    ]))
    tres = MAT_DIR / f"{mid}.tres"
    godot.write_material(tres, mid, f"{TEX_RES}/{mid}", "opaque", TILE_M)
    if k == "skin":
        text = tres.read_text(encoding="utf-8")
        text = text.replace("ao_enabled = true\n", "ao_enabled = true\nsubsurf_scatter_enabled = true\n"
                            "subsurf_scatter_strength = 0.25\nsubsurf_scatter_skin_mode = true\n")
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
        build_one(mid, spec, preset)
        n += 1
    print(f"wrote {n} materials: game/world/materials/char_*.tres + game/assets/characters/_textures/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
