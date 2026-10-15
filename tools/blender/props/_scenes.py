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
  ``KitPlacer``, the model AABB in Godot space (from the glb accessor bounds, collision excluded) and
  the bullet ``surface`` id (PO-8).
* PO-8 (impact_fx.md §1): every imported collision body (``Collision-colonly`` / ``-convcolonly``)
  gets ``metadata/surface`` in the wrapper: ``game/world/materials/surface_map.json`` ``props``
  override, else ``cat.surface``, else the surface of the glb material covering the most area.

Catalog ``cat`` keys (all optional): ``kind``, ``prefab``, ``group``, ``place`` (``wall`` floor item
backed to a wall | ``corner`` | ``floor`` free-standing | ``center`` | ``on`` on a host's top |
``seat`` in front of a host, facing it | ``wall_mount`` | ``above_door`` | ``ceiling`` |
``none``), ``mount``, ``support``, ``fixture``, ``light`` {type, color, energy, range, pos, angle},
``z`` (wall_mount centre height), ``hosts`` (kinds), ``clear`` (front clearance m), ``weight``,
``leaf_script`` (a LEAF_SCRIPTS key: a visual-only script set on the glb's ``Leaf`` node, GN-C2 shutters),
``leaf2`` (true: the same script on ``Leaf2`` too, D-111 Dockside Burn twin rollers / sliders),
``hidden`` (top-level glb node names the wrapper hides, e.g. a breach point's ``Blown`` state, PO6-17).
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
SURFACE_MAP = GAME / "world" / "materials" / "surface_map.json"
COLLISION_SUFFIXES = ("-convcolonly", "-colonly", "-convcol", "-col")
# Visual-only scripts a wrapper may put on the model's `Leaf` (cat ``leaf_script``).
LEAF_SCRIPTS = {"shutter": "res://world/props/shutter_leaf.gd", "slide": "res://world/props/slide_leaf.gd"}
_SURFACES: dict = {}


def surface_map() -> dict:
    if not _SURFACES:
        _SURFACES.update(json.loads(SURFACE_MAP.read_text(encoding="utf-8")))
    return _SURFACES


def surface_for(mat_id: str) -> str:
    """Same rule as SurfaceTags.for_id (game/world/materials/surface_tags.gd)."""
    mats = surface_map()["materials"]
    key = mat_id[2:] if mat_id.startswith("M_") else mat_id
    probe = key
    while probe:
        if probe in mats:
            return mats[probe]
        cut = probe.find("_")
        if cut < 0:
            break
        probe = probe[cut + 1:]
    for kw, sid in surface_map()["keywords"]:
        if kw in key:
            return sid
    return ""


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
    mesh_paths: list[str] = []

    collisions: list[str] = []
    areas: dict[str, float] = {}
    blob = data[20 + length + 8:]

    def accessor(i: int) -> list:
        acc = doc["accessors"][i]
        bv = doc["bufferViews"][acc["bufferView"]]
        fmt = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[acc["componentType"]]
        ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc["type"]]
        size = struct.calcsize(fmt)
        stride = bv.get("byteStride", size * ncomp)
        base = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
        return [struct.unpack_from("<" + fmt * ncomp, blob, base + k * stride) for k in range(acc["count"])]

    def add_area(prim: dict, m: list[list[float]]) -> None:
        mat = prim.get("material")
        mname = doc["materials"][mat].get("name", "") if mat is not None else ""
        pos = [[m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] for i in range(3)]
               for p in accessor(prim["attributes"]["POSITION"])]
        idx = [t[0] for t in accessor(prim["indices"])] if "indices" in prim else list(range(len(pos)))
        total = 0.0
        for k in range(0, len(idx) - 2, 3):
            a, b, c = pos[idx[k]], pos[idx[k + 1]], pos[idx[k + 2]]
            u = [b[i] - a[i] for i in range(3)]
            v = [c[i] - a[i] for i in range(3)]
            x = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
            total += 0.5 * math.sqrt(x[0] * x[0] + x[1] * x[1] + x[2] * x[2])
        areas[mname] = areas.get(mname, 0.0) + total

    def visit(idx: int, parent: list[list[float]], path: str = "") -> None:
        node = nodes[idx]
        name = node.get("name", "")
        if "-col" in name or "-convcol" in name:
            stripped = name
            for suf in COLLISION_SUFFIXES:
                if stripped.endswith(suf):
                    stripped = stripped[:-len(suf)]
                    break
            collisions.append(f"{path}/{stripped}" if path else stripped)
            return
        names.append(name)
        if "mesh" in node:
            mesh_paths.append(f"{path}/{name}" if path else name)
        m = _mat_mul(parent, _node_matrix(node))
        if "mesh" in node:
            for prim in doc["meshes"][node["mesh"]]["primitives"]:
                add_area(prim, m)
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
            visit(c, m, f"{path}/{name}" if path else name)

    ident = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
    for root in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        visit(root, ident)
    votes: dict[str, float] = {}
    for mname, area in areas.items():
        sid = surface_for(mname)
        if sid:
            votes[sid] = votes.get(sid, 0.0) + area
    surface = max(sorted(votes), key=lambda k: votes[k]) if votes else ""
    return {"aabb": [round(v, 4) for v in lo] + [round(hi[i] - lo[i], 4) for i in range(3)], "nodes": sorted(names),
            "meshes": mesh_paths, "collisions": collisions, "surface": surface}


def visibility_end(e: dict) -> float:
    """style guide §5: small clutter 25 m, medium props 60 m; large / exterior / prefabs: none."""
    if e["prefab"] or e["group"] == "exterior" or e["kind"] in ("neon_sign", "car"):
        return 0.0
    size = max(e["aabb"][3:6])
    if e["kind"] == "light_fixture" and size > 1.5:
        return 0.0
    if size <= 0.6 or e["place"] == "on":
        return 25.0
    if size <= 3.0:
        return 60.0
    return 0.0


VIEWMODEL_LIT_LAYER = 1 << 20  # render layer 21 `viewmodel_lit` (visual_slots v1.2, D-095)
LIGHT_LAYERS = 1 | VIEWMODEL_LIT_LAYER


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
    # render layers 1 + 21 `viewmodel_lit` (1 << 20 = CrewView.VIEWMODEL_LIT_LAYER, D-095): every prop
    # light also lights the first-person arms/gun, so any map dressed from the library inherits it
    lines.append(f"layers = {LIGHT_LAYERS}")
    lines.append(f"light_color = {_color(light.get('color', '#FFD9B0'))}")
    lines.append(f"light_energy = {_f(light.get('energy', 1.0))}")
    lines.append("light_size = 0.05")
    if "specular" in light:
        lines.append(f"light_specular = {_f(light['specular'])}")
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
        "surface": surface_map()["props"].get(aid, cat.get("surface", info["surface"])) or "concrete",
    }
    if cat.get("pin_only"):
        # only used where a kit pins it (or a map anchors it): unpinned kit picks of its kind (and
        # their RNG draws) stay exactly as they were before it existed
        e["pin_only"] = True
    leaf_script = LEAF_SCRIPTS[cat["leaf_script"]] if "leaf_script" in cat else ""
    lines = [f'[gd_scene load_steps={3 if leaf_script else 2} format=3]', "",
             f'[ext_resource type="PackedScene" path="{e["glb"]}" id="1_model"]']
    if leaf_script:
        lines.append(f'[ext_resource type="Script" path="{leaf_script}" id="2_leaf"]')
    lines.append("")
    # a visual that carries a light is its fixture (levelcheck `lights`: fixture ancestor)
    if prefab and "light" in cat:
        e["fixture"] = True
    groups = ' groups=["fixture"]' if e["fixture"] else ""
    lines.append(f'[node name="{pascal(aid)}" type="Node3D"{groups}]')
    if prefab and e["fixture"]:
        lines.append("metadata/fixture = true")
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
    vis = visibility_end(e)
    e["visibility_range_end"] = vis
    if vis > 0.0:
        for mp in info["meshes"]:
            parent, _, leaf = ("Model/" + mp).rpartition("/")
            lines += ["", f'[node name="{leaf}" parent="{parent}"]', f"visibility_range_end = {_f(vis)}",
                      f"visibility_range_end_margin = {_f(vis * 0.1)}", "visibility_range_fade_mode = 1"]
    for cp in info["collisions"]:
        parent, _, leaf = ("Model/" + cp).rpartition("/")
        lines += ["", f'[node name="{leaf}" parent="{parent}"]', f'metadata/surface = &"{e["surface"]}"']
    if leaf_script:
        lines += ["", '[node name="Leaf" parent="Model"]', 'script = ExtResource("2_leaf")']
        if cat.get("leaf2"):
            lines += ["", '[node name="Leaf2" parent="Model"]', 'script = ExtResource("2_leaf")']
    hidden = [str(h) for h in cat.get("hidden", [])]
    for hn in hidden:
        if hn not in info["nodes"]:
            raise SystemExit(f"_scenes.py: {aid}: hidden node `{hn}` not in the glb")
        lines += ["", f'[node name="{hn}" parent="Model"]', "visible = false"]
    if "light" in cat:
        lines += [""] + _light_node(cat["light"])
    if vis > 0.0 or info["collisions"] or leaf_script or hidden:
        lines += ["", '[editable path="Model"]']
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
