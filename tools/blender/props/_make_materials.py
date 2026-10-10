#!/usr/bin/env python3
"""Prop material library (C1-07). Run with the system python (numpy + Pillow), not Blender:

    python3 tools/blender/props/_make_materials.py              # detail textures + .tres + patch imports
    python3 tools/blender/props/_make_materials.py --imports    # only patch the prop .glb.import files

Writes (all deterministic, no timestamps):

* ``game/assets/props/_detail/tex_detail_<src>.png``: neutral luminance detail (mean ~0.8 linear)
  derived from the library albedo ``<src>`` (texgen output), so a tint keeps the library's grain,
  weave or brush detail. Greyscale PNG, 1024 px = 2 m (UV convention of tools/texgen/README.md).
* ``game/world/props/materials/pr_<key>.tres``: ORMMaterial3D (detail albedo x tint + the library
  ORM and normal maps) for ``_matlib.TINTED``; StandardMaterial3D emissives (meta
  ``untextured_ok``) for ``_matlib.EMISSIVE``.
* ``_subresources`` in every ``game/assets/{props,arch}/prop_*|veh_*`` ``.glb.import``: each
  ``M_pr_<key>`` glTF material is replaced at import by ``res://world/props/materials/pr_<key>.tres``
  (Godot's ``use_external``). Library ids (``M_<library_id>``) are left to glb_post_import.gd.
"""

from __future__ import annotations

import json
import pathlib
import struct
import sys

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO / "tools"))

import _matlib  # noqa: E402
from texgen import godot as tgodot  # noqa: E402
from texgen import io as tio  # noqa: E402

GAME = REPO / "game"
LIB_TEX = GAME / "assets" / "textures"
DETAIL_DIR = GAME / "assets" / "props" / "_detail"
MAT_DIR = GAME / "world" / "props" / "materials"
MAT_RES = "res://world/props/materials"
DETAIL_RES = "res://assets/props/_detail"
DETAIL_MEAN = 0.8  # linear mean of every detail texture


def _srgb_to_lin(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _lin_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def _hex_lin(hx: str) -> tuple[float, float, float]:
    h = hx.lstrip("#")
    srgb = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    return tuple(float(x) for x in _srgb_to_lin(srgb))


def make_detail(src: str) -> pathlib.Path:
    """Luminance detail of a library albedo, normalised to DETAIL_MEAN, contrast-limited."""
    path = LIB_TEX / src / f"tex_{src}_albedo.png"
    img = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0
    lin = _srgb_to_lin(img)
    lum = lin @ np.array([0.2126, 0.7152, 0.0722])
    rel = lum / max(lum.mean(), 1e-6)
    rel = np.clip(1.0 + (rel - 1.0) * 0.9, 0.55, 1.22)
    out = np.clip(rel * DETAIL_MEAN, 0.0, 0.98)
    q = np.round(_lin_to_srgb(out) * 255.0).astype(np.uint8)
    dst = DETAIL_DIR / f"tex_detail_{src}.png"
    dst.parent.mkdir(parents=True, exist_ok=True)
    tio.write_png(dst, q)
    tgodot.ensure_import(dst, "texture", "CompressedTexture2D", tgodot.IMPORT_PARAMS["albedo"])
    return dst


def _color(rgb: tuple[float, float, float], alpha: float = 1.0) -> str:
    return f"Color({rgb[0]:.4f}, {rgb[1]:.4f}, {rgb[2]:.4f}, {alpha:g})"


def write_tinted(key: str, spec: dict) -> None:
    src = spec["source"]
    target = np.array(_hex_lin(spec["color"]))
    tint_lin = np.clip(target / DETAIL_MEAN, 0.0, 1.0)
    tint_srgb = tuple(float(x) for x in _lin_to_srgb(tint_lin))
    pid = _matlib.prop_id(key)
    lines = [
        '[gd_resource type="ORMMaterial3D" load_steps=4 format=3]',
        "",
        f'[ext_resource type="Texture2D" path="{DETAIL_RES}/tex_detail_{src}.png" id="1_albedo"]',
        f'[ext_resource type="Texture2D" path="res://assets/textures/{src}/tex_{src}_orm.png" id="2_orm"]',
        f'[ext_resource type="Texture2D" path="res://assets/textures/{src}/tex_{src}_normal.png" id="3_normal"]',
        "",
        "[resource]",
        f'resource_name = "M_{pid}"',
        "texture_filter = 5",
        f"albedo_color = {_color(tint_srgb)}",
        'albedo_texture = ExtResource("1_albedo")',
        "metallic = 1.0",
        f"roughness = {min(1.0, float(spec.get('roughness', 1.0))):.3f}",
        'orm_texture = ExtResource("2_orm")',
        "normal_enabled = true",
        f"normal_scale = {float(spec.get('normal_scale', 1.0)):.3f}",
        'normal_texture = ExtResource("3_normal")',
        "ao_enabled = true",
        "metadata/uv_tile_m = 2.0",
        f'metadata/prop_material_source = "{src}"',
    ]
    tio.write_text(MAT_DIR / f"{pid}.tres", "\n".join(lines) + "\n")


def write_glass(key: str, spec: dict) -> None:
    src = spec["source"]
    pid = _matlib.prop_id(key)
    col = _hex_srgb(spec["color"])
    lines = [
        '[gd_resource type="ORMMaterial3D" load_steps=4 format=3]',
        "",
        f'[ext_resource type="Texture2D" path="res://assets/textures/{src}/tex_{src}_albedo.png" id="1_albedo"]',
        f'[ext_resource type="Texture2D" path="res://assets/textures/{src}/tex_{src}_orm.png" id="2_orm"]',
        f'[ext_resource type="Texture2D" path="res://assets/textures/{src}/tex_{src}_normal.png" id="3_normal"]',
        "",
        "[resource]",
        f'resource_name = "M_{pid}"',
        "transparency = 1",
        "depth_draw_mode = 1",
        "texture_filter = 5",
        f"albedo_color = {_color(col, spec['alpha'])}",
        'albedo_texture = ExtResource("1_albedo")',
        "metallic = 1.0",
        "roughness = 1.0",
        'orm_texture = ExtResource("2_orm")',
        "normal_enabled = true",
        "normal_scale = 1.0",
        'normal_texture = ExtResource("3_normal")',
        "ao_enabled = true",
        "metadata/uv_tile_m = 2.0",
    ]
    tio.write_text(MAT_DIR / f"{pid}.tres", "\n".join(lines) + "\n")


def write_emissive(key: str, spec: dict) -> None:
    pid = _matlib.prop_id(key)
    col = _hex_srgb(spec["color"])
    emi = _hex_srgb(spec["emission"])
    lines = [
        '[gd_resource type="StandardMaterial3D" format=3]',
        "",
        "[resource]",
        f'resource_name = "M_{pid}"',
        f"albedo_color = {_color(col)}",
        "roughness = 0.45",
        "emission_enabled = true",
        f"emission = {_color(emi)}",
        f"emission_energy_multiplier = {float(spec['energy']):.2f}",
        "metadata/uv_tile_m = 2.0",
        "metadata/untextured_ok = true",
    ]
    tio.write_text(MAT_DIR / f"{pid}.tres", "\n".join(lines) + "\n")


def _hex_srgb(hx: str) -> tuple[float, float, float]:
    h = hx.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def glb_material_names(glb: pathlib.Path) -> list[str]:
    data = glb.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + length])
    return sorted({m.get("name", "") for m in doc.get("materials", [])})


def _subresources_text(names: list[str]) -> str:
    """The `_subresources` value exactly as Godot writes it back (multi-line, sorted keys), so a
    rebuild after an import changes nothing."""
    if not names:
        return "{}"
    mats = []
    for n in names:
        path = f"{MAT_RES}/{n[2:]}.tres"
        mats.append(f'"{n}": {{\n"use_external/enabled": true,\n"use_external/fallback_path": "{path}",\n'
                    f'"use_external/path": "{path}"\n}}')
    return '{\n"materials": {\n' + ",\n".join(mats) + "\n}\n}"


def patch_import(glb: pathlib.Path) -> bool:
    """Point every M_pr_<key> material of ``glb`` at its prop material (use_external)."""
    names = [n for n in glb_material_names(glb) if n.startswith("M_" + _matlib.PROP_PREFIX)]
    value = _subresources_text(names)
    imp = glb.with_name(glb.name + ".import")
    if not imp.exists():
        return False
    old = imp.read_text(encoding="utf-8")
    lines = old.split("\n")
    out: list[str] = []
    i = 0
    done = False
    section = ""
    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if s.startswith("[") and s.endswith("]") and not line.startswith("_"):
            section = s
        if section == "[params]" and line.startswith("_subresources="):
            depth = line.count("{") - line.count("}")
            while depth > 0 and i + 1 < len(lines):
                i += 1
                depth += lines[i].count("{") - lines[i].count("}")
            out.append(f"_subresources={value}")
            done = True
        else:
            out.append(line)
        i += 1
    if not done:
        while out and out[-1] == "":
            out.pop()
        out += [f"_subresources={value}", ""]
    new = "\n".join(out)
    if new != old:
        imp.write_text(new, encoding="utf-8", newline="\n")
        return True
    return False


def all_prop_glbs() -> list[pathlib.Path]:
    out = []
    for cat in ("props",):
        out += sorted((GAME / "assets" / cat).glob("*/*.glb"))
    return out


def main() -> int:
    only_imports = "--imports" in sys.argv
    if not only_imports:
        for src in _matlib.DETAIL_SOURCES:
            make_detail(src)
        MAT_DIR.mkdir(parents=True, exist_ok=True)
        for key, spec in sorted(_matlib.TINTED.items()):
            if spec["source"] not in _matlib.DETAIL_SOURCES:
                raise SystemExit(f"{key}: detail source {spec['source']} not in DETAIL_SOURCES")
            write_tinted(key, spec)
        for key, spec in sorted(_matlib.EMISSIVE.items()):
            write_emissive(key, spec)
        for key, spec in sorted(_matlib.GLASS.items()):
            write_glass(key, spec)
        print(f"materials: {len(_matlib.TINTED) + len(_matlib.EMISSIVE)} prop materials, "
              f"{len(_matlib.DETAIL_SOURCES)} detail textures")
    changed = sum(patch_import(g) for g in all_prop_glbs())
    print(f"imports: {changed} .glb.import file(s) patched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
