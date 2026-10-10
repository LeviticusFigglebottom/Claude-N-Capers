#!/usr/bin/env python3
"""Godot wrapper scenes + prop catalog for the props library (C1-07). System python, no Blender:

    python3 tools/blender/props/_scenes.py

Reads the ``cat`` dict of every asset in ``tools/blender/props/*.py`` (VARIANTS params) and the built
``.glb`` files, and writes (deterministically, plain text, no uids):

* ``game/world/props/<group>/<asset_id>.tscn``: root Node3D (PascalCase of the id) with the levelcheck
  metas (``kind``, ``mount``, ``support``, ``fixture`` + group ``fixture``), the glb instanced as
  ``Model`` and, for light fixtures, a shadowless ``Light`` (OmniLight3D/SpotLight3D) inside the
  fixture. Prefab visuals (``cat.prefab``) go to ``game/world/props/<prefab>/`` and carry no metas
  (the prefab instance in the map gets them).
* ``game/world/props/prop_catalog.json``: per asset the scene path, metas, placement hints for
  ``KitPlacer`` and the model AABB in Godot space (from the glb accessor bounds, collision excluded).

Catalog ``cat`` keys (all optional): ``kind``, ``prefab``, ``group``, ``place`` (``wall`` floor item
backed to a wall | ``corner`` | ``floor`` free-standing | ``center`` | ``on`` on a host's top |
``seat`` in front of a host, facing it | ``wall_mount`` | ``above_door`` | ``ceiling`` |
``none``), ``mount``, ``support``, ``fixture``, ``light`` {type, color, energy, range, pos, angle},
``z`` (wall_mount centre height), ``hosts`` (kinds), ``clear`` (front clearance m), ``weight``.
"""

from __future__ import annotations

import json
import math
import pathlib
import struct
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE.parent))

from lib import meta  # noqa: E402

GAME = REPO / "game"
PROPS_RES = "res://world/props"
CATALOG = GAME / "world" / "props" / "prop_catalog.json"


def pascal(asset_id: str) -> str:
    return "".join(p[:1].upper() + p[1:] for p in asset_id.split("_"))


def _mat_mul(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def _node_matrix(node: dict) -> list[list[float]]:
    if "matrix" in node:
        m = node["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = node.get("translation", [0, 0, 0])
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    s = node.get("scale", [1, 1, 1])
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[0][0] * s[0], r[0][1] * s[1], r[0][2] * s[2], t[0]],
            [r[1][0] * s[0], r[1][1] * s[1], r[1][2] * s[2], t[1]],
            [r[2][0] * s[0], r[2][1] * s[1], r[2][2] * s[2], t[2]],
            [0, 0, 0, 1]]


def glb_info(glb: pathlib.Path) -> dict:
    """AABB of the visual meshes (Godot space, collision excluded) and named nodes."""
    data = glb.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + length])
    nodes = doc.get("nodes", [])
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    names: list[str] = []

    def visit(idx: int, parent: list[list[float]]) -> None:
        node = nodes[idx]
        name = node.get("name", "")
        if "-col" in name or "-convcol" in name:
            return
        names.append(name)
        m = _mat_mul(parent, _node_matrix(node))
        if "mesh" in node:
            for prim in doc["meshes"][node["mesh"]]["primitives"]:
                acc = doc["accessors"][prim["attributes"]["POSITION"]]
                amin, amax = acc["min"], acc["max"]
                for cx in (amin[0], amax[0]):
                    for cy in (amin[1], amax[1]):
                        for cz in (amin[2], amax[2]):
                            p = [m[i][0] * cx + m[i][1] * cy + m[i][2] * cz + m[i][3] for i in range(3)]
                            for i in range(3):
                                lo[i] = min(lo[i], p[i])
                                hi[i] = max(hi[i], p[i])
        for c in node.get("children", []):
            visit(c, m)

    ident = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
    for root in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        visit(root, ident)
    return {"aabb": [round(v, 4) for v in lo] + [round(hi[i] - lo[i], 4) for i in range(3)], "nodes": sorted(names)}


def _f(v: float) -> str:
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def _color(hx: str) -> str:
    h = hx.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return f"Color({_f(r)}, {_f(g)}, {_f(b)}, 1)"


def _light_node(light: dict) -> list[str]:
    kind = light.get("type", "omni")
    pos = light.get("pos", [0.0, 0.0, 0.0])
    lines = []
    if kind == "spot":
        # local -Z points straight down (rotation -90 deg about X)
        lines.append('[node name="Light" type="SpotLight3D" parent="."]')
        lines.append(f"transform = Transform3D(1, 0, 0, 0, 0, 1, 0, -1, 0, {_f(pos[0])}, {_f(pos[1])}, {_f(pos[2])})")
        lines.append(f"spot_range = {_f(light.get('range', 5.0))}")
        lines.append(f"spot_angle = {_f(light.get('angle', 35.0))}")
        lines.append("spot_angle_attenuation = 0.6")
    else:
        lines.append('[node name="Light" type="OmniLight3D" parent="."]')
        lines.append(f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {_f(pos[0])}, {_f(pos[1])}, {_f(pos[2])})")
        lines.append(f"omni_range = {_f(light.get('range', 4.0))}")
        lines.append("omni_attenuation = 1.2")
    lines.append(f"light_color = {_color(light.get('color', '#FFD9B0'))}")
    lines.append(f"light_energy = {_f(light.get('energy', 1.0))}")
    lines.append("light_size = 0.05")
    lines.append(f"shadow_enabled = {'true' if light.get('shadow', False) else 'false'}")
    return lines


def entry(spec: meta.AssetSpec) -> tuple[dict, str]:
    cat = dict(spec.params.get("cat", {}))
    aid = spec.asset_id
    glb = GAME / "assets" / spec.category / aid / f"{aid}.glb"
    if not glb.exists():
        raise SystemExit(f"_scenes.py: {glb.relative_to(REPO)} missing (build first)")
    info = glb_info(glb)
    prefab = cat.get("prefab", "")
    group = prefab or cat.get("group", "dressing")
    place = cat.get("place", "none" if prefab else "floor")
    mount = cat.get("mount", {"wall_mount": "wall", "above_door": "wall", "ceiling": "ceiling"}.get(place, ""))
    scene = f"{PROPS_RES}/{group}/{aid}.tscn"
    e = {
        "scene": scene,
        "glb": f"res://assets/{spec.category}/{aid}/{aid}.glb",
        "kind": cat.get("kind", ""),
        "prefab": prefab,
        "group": group,
        "place": place,
        "mount": mount,
        "support": bool(cat.get("support", False)),
        "fixture": bool(cat.get("fixture", False)),
        "hosts": list(cat.get("hosts", [])),
        "z": float(cat.get("z", 0.0)),
        "clear": float(cat.get("clear", 0.0)),
        "weight": float(cat.get("weight", 1.0)),
        "aabb": info["aabb"],
        "nodes": info["nodes"],
        "has_light": "light" in cat,
        "top": float(cat.get("top", 0.0)),
        "keepout": [list(z) for z in cat.get("keepout", [])],
        "seat_side": cat.get("seat_side", "front"),
        "standoff": float(cat.get("standoff", 0.0)),
    }
    lines = ['[gd_scene load_steps=2 format=3]', "",
             f'[ext_resource type="PackedScene" path="{e["glb"]}" id="1_model"]', ""]
    groups = ' groups=["fixture"]' if e["fixture"] and not prefab else ""
    lines.append(f'[node name="{pascal(aid)}" type="Node3D"{groups}]')
    if not prefab:
        lines.append(f'metadata/kind = &"{e["kind"]}"')
        if mount:
            lines.append(f'metadata/mount = &"{mount}"')
        if e["support"]:
            lines.append("metadata/support = true")
        if e["fixture"]:
            lines.append("metadata/fixture = true")
        if cat.get("service"):
            lines.append("metadata/service = true")
    lines += ["", '[node name="Model" parent="." instance=ExtResource("1_model")]']
    if "light" in cat:
        lines += [""] + _light_node(cat["light"])
    return e, "\n".join(lines) + "\n"


def write_text(path: pathlib.Path, text: str) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return False
    path.write_text(text, encoding="utf-8", newline="\n")
    return True


def main() -> int:
    specs: list[meta.AssetSpec] = []
    for script in sorted(HERE.glob("*.py")):
        if not script.name.startswith("_"):
            specs.extend(meta.read_specs(script))
    catalog: dict[str, dict] = {}
    changed = 0
    for spec in sorted(specs, key=lambda s: s.asset_id):
        e, text = entry(spec)
        catalog[spec.asset_id] = e
        changed += write_text(GAME / e["scene"].replace("res://", ""), text)
    changed += write_text(CATALOG, json.dumps(catalog, indent=1, sort_keys=True) + "\n")
    print(f"scenes: {len(catalog)} entries, {changed} file(s) written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
