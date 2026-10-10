# Asset pipeline how-to (Blender -> glb -> Godot)

Owner: **ENV C** (C1-01). Audience: anyone producing models, first of all ENV B for weapons
(B1-03). Rules come from `docs/art/style_guide.md` §2–§6 and `docs/contracts/visual_slots.md`;
this page is the practical recipe. Library API version: `tools/blender/lib/__init__.py`
`__version__` (1.0.0).

```
tools/blender/<folder>/<asset>.py  --build.py-->  game/assets/<category>/<asset_id>/<asset_id>.glb
        (build(ctx) using lib)       (Blender 4.5,        + SOURCE.txt
                                     headless)            + <asset_id>.glb.import  --godot --import-->
                                                            glb_post_import.gd maps M_<id> -> world/materials/<id>.tres
```

## 1. Install

* Blender 4.5 LTS: `bash tools/setup/install_blender.sh` (or any `blender` 4.5.x on PATH, or
  `$BLENDER=/path/to/blender`). Output bytes are only guaranteed with 4.5.
* Godot 4.7.2 at `/opt/godot/godot` (`bash tools/setup/install_godot.sh`).
* System `python3` ≥ 3.10 runs `build.py`; it needs nothing beyond the standard library.

## 2. Write an asset script

One file per asset family in `tools/blender/<folder>/` (weapons: `tools/blender/weapons/`,
owned by ENV B). Files starting with `_` are private helpers (importable from sibling scripts,
never built). A script has two parts:

1. **Metadata**: UPPER_CASE top-level assignments in plain Python (no `bpy`, no imports, no
   helper functions). `build.py` evaluates only these, with the system python, to list assets.
   * `ASSET_ID = "wpn_kestrel_p9"` (+ optional `PARAMS = {...}`), **or**
     `VARIANTS = {asset_id: params_dict, ...}` (comprehensions allowed) for several assets.
   * `TRI_BUDGET = 25000` (optional): the build fails if LOD0 triangles (collision excluded)
     exceed it. Budgets: props 50–8k, hero 20k, characters 35k, FP weapons 25k, wall pieces 500.
   * `EXPORT = {"embed": True, "animations": False, "skins": False, "morph": False}` (optional
     `export_glb` keyword arguments).
2. **`build(ctx)`**: builds the scene. The runner has already reset Blender; afterwards it
   validates, exports and writes SOURCE.txt. Do not export yourself.

### Worked example: a small weapon-like model

`tools/blender/weapons/wpn_example_pistol.py` (illustrative; not checked in):

```python
"""Tiny pistol-like model: two material slots, chamfers, marker empties."""

import math

from lib import geo, uv

ASSET_ID = "wpn_example_pistol"
TRI_BUDGET = 25000          # first-person weapon budget (style guide §5)
PARAMS = {"barrel_len": 0.12}


def build(ctx) -> None:
    # Material slots M_<library_id>. Colour = sRGB placeholder shown until the library .tres exists.
    steel = ctx.material("steel_blued", "#3A3D42", roughness=0.35, metallic=1.0)
    poly = ctx.material("polymer_black", "#2A2B2D", roughness=0.7)

    # Forward (muzzle) = Blender +Y = Godot -Z. Up = Blender +Z = Godot +Y.
    mb = geo.MeshBuilder()
    m_steel = mb.material(steel)
    m_poly = mb.material(poly)
    blen = ctx.param("barrel_len")
    mb.box((-0.0125, -0.06, 0.10), (0.0125, blen, 0.135), mat=m_steel)        # slide
    mb.box((-0.012, -0.05, 0.085), (0.012, blen - 0.01, 0.10), mat=m_poly)     # frame
    grip = [(-0.06, 0.10), (-0.035, 0.10), (-0.01, 0.0), (-0.045, -0.005)]     # side profile (y, z)
    mb.prism(grip, axis="X", start=-0.014, end=0.014, mat=m_poly)
    mb.cylinder(0.006, 0.01, segments=16, centre=(0, blen + 0.005, 0.12), axis="Y", mat=m_steel)
    mb.bevel(0.0015, segments=2)                               # 1) chamfer first ...
    uv.box_project(mb.bm, density=uv.DENSITY_FIRST_PERSON)     # 2) ... then UVs (determinism!)
    geo.finish_hard_surface(mb.to_object("Body"))              # sharp edges + weighted normals

    # Markers: exact names from contracts/visual_slots.md. -Z of a marker in Godot = Blender +Y.
    ctx.marker("Muzzle", (0.0, blen + 0.01, 0.12))
    ctx.marker("Eject", (0.0135, 0.02, 0.125), rotation_euler=(0, 0, -math.pi / 2))
    ctx.marker("SightRail", (0.0, 0.0, 0.135))
    ctx.marker("Magwell", (0.0, -0.035, 0.0))
    ctx.marker("LeftHandIK", (-0.02, -0.03, 0.06))
```

Result (verified): glb nodes `Body, Muzzle, Eject, SightRail, Magwell, LeftHandIK`, materials
`M_steel_blued, M_polymer_black`, byte-identical over repeated builds. In Godot each marker is a
`Node3D` with exactly that name; parent a marker to a mesh/empty with `parent=` to nest it.

## 3. Build

```
python3 tools/blender/build.py --category weapons --list              # what would be built
python3 tools/blender/build.py --category weapons                     # build all
python3 tools/blender/build.py --category weapons --asset wpn_kestrel_p9 [--asset ...]
python3 tools/blender/build.py --category weapons -v                  # show Blender logs
```

`--category` is the script folder. The output folder comes from the asset-id prefix
(`lib/naming.py`): `arch_`→`arch`, `prop_`/`veh_`→`props`, `char_`→`characters`,
`wpn_`/`mod_`→`weapons`, `fx_`→`fx`. Each asset produces
`game/assets/<category>/<asset_id>/<asset_id>.glb`, `SOURCE.txt` and (created or patched in
place, Godot's uid kept) `<asset_id>.glb.import`. Commit all three plus Godot's completed
`.import` after an import. Scripts of a folder build in parallel (`-j`, default 4), one Blender
process per script.

## 4. Determinism check

```
python3 tools/blender/build.py --category weapons --check-determinism
```

Builds everything twice into temp dirs, prints `sha256  path` for every .glb and SOURCE.txt,
fails on any mismatch and notes outputs that differ from the committed copy (= rebuild needed).
How determinism is achieved:

* `scene.reset()` before every asset (factory settings, all datablocks purged, metric units).
* Seeds: `ctx.rng` is `random.Random(zlib.crc32(asset_id))`; `ctx.seed` is the number. Never use
  `hash()`, time, the OS or unseeded randomness.
* Every exporter option is fixed in `lib/export.py`; `lib/glb.py` rewrites the JSON chunk
  canonically (sorted keys, fixed generator string). Binary data is untouched.
* **Rule: chamfer first, UV after.** Blender 4.5 interpolates UVs through bevels with
  heap-address-dependent last-bit noise (bevel modifier and bmesh bevel alike, as soon as the
  mesh already has UVs). `geo.bevel_object()` warns when that happens. Generated UVs
  (`uv.box_project`) are pure math and deterministic. The Bevel *modifier* (`geo.add_bevel`) is
  for look-dev only.
* Second line of defence: build.py runs Blender under `setarch -R` (ASLR off) when available.
  The greybox kit is byte-identical with and without it.

## 5. Godot import and the material library

`build.py` writes `import_script/path="res://world/tools/import/glb_post_import.gd"` (plus
`meshes/generate_lods`, `ensure_tangents`, `create_shadow_meshes`) into each `.glb.import`.
Run `/opt/godot/godot --headless --path game --import`; Godot completes the file and keeps
these params.

`glb_post_import.gd` walks every `MeshInstance3D`. For each surface whose material is named
`M_<id>` it sets `res://world/materials/<id>.tres` on the mesh (`surface_set_material`, saved
with the imported scene). If that file does not exist, the embedded flat-colour placeholder stays
and a warning is printed, so a missing library entry is visible but never a default/null
material. Non-`M_` names are kept with a warning. Library ids are lowercase snake_case; ask ENV C
for new library materials (C1-07) or use an asset-unique id plus embedded textures.

**Embedded textures** (unique assets): `materials.pbr_material(id, albedo, orm=None,
normal=None)` with PNGs (albedo sRGB, ORM linear R=AO G=rough B=metal, normal OpenGL Y+), and
`EXPORT = {"embed": True}`. Use an id that has no library .tres, or the library wins.

## 6. Naming, axes, pivots

* Asset ids `<category>_<name>[_<variant>]` lowercase snake (`lib.naming.check_asset_id`).
  Material slots `M_<library_id>`. Gameplay node names PascalCase, unique per asset
  (`geo.empty` validates).
* Blender is Z-up, the exporter maps to Godot Y-up. **Godot -Z (forward / facing the room /
  muzzle direction) is Blender +Y.** `geo.godot_to_blender()` converts. Meters, scale 1.
* Pivots (visual_slots.md): floor objects bottom-centre, wall-mounted back-centre (back = min
  Blender Y), ceiling-mounted top-centre: call `ctx.pivot("floor"|"wall"|"ceiling")` at the end
  of `build`. Weapons: pivot as ENV B's weapon contract says (typically the grip/hand point).
* Mesh object rotation/scale are applied at export; empties keep their transforms (marker
  orientation matters).

## 7. LOD and collision

* **LOD:** Godot importer auto-LOD (`meshes/generate_lods=true`). Export LOD0 only.
  `lod.decimate_lod()` exists for hand-made exceptions (wire visibility ranges yourself). Small
  clutter/medium props get `visibility_range_end` 25 / 60 m from the scene that places them.
* **Collision** uses Godot's import name suffixes, produced by
  `geo.collision_from_builder(builder, kind)`:
  * `kind="trimesh"` -> node `Collision-colonly` -> `StaticBody3D "Collision"` with a concave
    shape. **Architecture only.**
  * `kind="convex"` -> `Collision-convcolonly` -> `StaticBody3D "Collision"` with a convex hull.
    Props.
  * The collision mesh is dropped on import, carries no material and is excluded from the
    triangle budget. Build it from simple unbevelled geometry (`MeshBuilder.copy()` before
    `bevel()`). Weapons normally ship no collision.

## 8. SOURCE.txt

Written next to each .glb: asset id, script path, params (sorted JSON), seed, Blender and lib
versions, the exact rebuild command, triangle budget and any `ctx.source_extra` facts (stairs
record riser count/height). It has no timestamps, so it is part of the determinism check.

## 9. Library API (tools/blender/lib, v1.0.0)

Blender-only modules import `bpy`; `naming`, `meta`, `lod`, `source`, `glb`, `godot_import` are
pure Python.

| Module | API |
|---|---|
| `scene` | `reset() -> Scene`, `collection()`, `link(obj, parent=None)`, `all_objects()` |
| `naming` | `check_asset_id(id)`, `category_for(id)`, `check_library_id(id)`, `material_name(lib_id)`, `library_id_from_material(name)`, `check_node_name(name)`, `is_collision_name(name)`, `PREFIX_CATEGORY` |
| `materials` | `material(lib_id, color="#RRGGBB"\|(r,g,b) sRGB, roughness=0.8, metallic=0.0, alpha=1.0)`, `pbr_material(lib_id, albedo, orm=None, normal=None)`, `assign(obj, mat, face_indices=None)`, `slot_index(obj, mat)`, `hex_to_srgb`, `srgb_to_linear` |
| `geo` | `MeshBuilder()`: `.material(mat)->int`, `.box(lo, hi, mat)`, `.prism(outer, holes=(), axis="Y", start, end, mat, cap_mat)`, `.cylinder(radius, depth, segments=16, centre, axis="Z", mat)`, `.bevel(width=0.005, segments=1, angle_deg=30)`, `.merge()`, `.transform(m)`, `.translate(v)`, `.copy()`, `.tri_count()`, `.to_object(name, parent=None, location)`; `box_object(...)`, `empty(name, location, rotation_euler, parent)`, `bevel_object(obj, width, segments, angle_deg)`, `finish_hard_surface(obj, bevel=0, segments=1, angle_deg=30)`, `mark_sharp(obj)`, `add_weighted_normals(obj)`, `add_bevel(obj, ...)` (look-dev only), `boolean(obj, cutter, operation="DIFFERENCE")`, `apply_modifiers(obj)`, `tri_count(obj)`, `bounds(objs)`, `align_pivot(objs, mode)`, `collision_from_builder(builder, kind="trimesh"\|"convex", name="Collision")`, `godot_to_blender(v)`, `blender_to_godot(v)` |
| `uv` | `box_project(bm, density=512, texture_px=1024, offset=(0,0,0))`, `box_project_object(obj, density, texture_px, world=False)`, `DENSITY_NEAR=512`, `DENSITY_FAR=256`, `DENSITY_FIRST_PERSON=1024` |
| `lod` | `GODOT_IMPORT_PARAMS`, `VISIBILITY_RANGE_END`, `decimate_lod(obj, ratio, suffix="_LOD1")` |
| `export` | `validate(tri_budget=None) -> warnings`, `export_glb(path, embed=False, animations=False, skins=False, morph=False)` |
| `asset` | `AssetContext` (`asset_id, params, param(k, d), seed, rng, out_dir, glb_path, category, export_options, source_extra, material(...), marker(...), builder(), pivot(mode)`), `seed_for(id)`, `run(script, out_root, ids)` |
| `meta` / `glb` / `source` / `godot_import` | metadata reading, glb canonicalisation + `sha256`, SOURCE.txt, `.glb.import` patching |

UV texel density: `uv = metres * density / texture_px`, so one UV unit is one texture repeat
(1024 px textures repeat every 2 m at 512 px/m). Projection is in asset space; tiles line up
across pieces placed at multiples of the texture period.

## 10. Greybox modular kit (C1-02)

`python3 tools/blender/build.py --category greybox` -> 95 assets in `game/assets/arch/`, all
≤ 300 triangles, materials `M_grey_*` -> `game/world/materials/grey_*.tres`
(regenerate with `python3 tools/blender/greybox/make_materials.py`).

| Family | Ids | Origin / notes |
|---|---|---|
| Walls | `arch_wall_{int,ext}_w{50,100,200,400}_h{300,350,400}` | bottom of the start end on the wall centreline; runs +X; thickness 0.2 / 0.4 centred. Ext: outside face (Godot +Z) `M_grey_wall_ext`, room face (Godot −Z) `M_grey_wall` |
| Walls with openings | `arch_wall_{int,ext}_{door,door_double,door_service,window,window_wide}_w…_h…`, `arch_wall_ext_shop_w400_h…` | door 1.0×2.2 at x 0.5–1.5 (w200); double 2.0×2.2 at 1.0–3.0 (w400); service 1.2×2.2 at 0.4–1.6 (w200); window sill 0.9 head 2.1 (1.0 at 0.5–1.5 / 3.0 at 0.5–3.5); shop sill 0.3 head 2.7, 3.0 wide |
| Doors (prefab `door`) | `arch_door_{single,double,service}_t{20,40}`, frames only: `arch_door_frame_*` | origin bottom-centre of the opening on the wall line. `Frame`, `Leaf` (hinge pivot, rotate Y), `LeafMesh`, `HandleMesh`, `Handle`; double adds `Leaf2`… Frame-only collision |
| Windows (prefab `window`) | `arch_window_w100_h120`, `arch_window_w300_h120`, `arch_window_shop_w300_h240` | origin bottom-centre of the opening (sill); `Frame`, `Glass`; no collision |
| Floors / ceilings | `arch_floor_w{100,200,400}`, `arch_ceiling_w{100,200,400}` | corner origin, extend +X and Godot −Z. Floor top at 0, 0.2 slab (underside `M_grey_ceiling`). Ceiling underside at 0, 0.05 thick |
| Stairs | `arch_stair_straight_f300`, `arch_stair_landing_f{300,350,400,450}`, `arch_stair_u_f{300,350,400,450}` | generated from floor-to-floor: n = ceil(f2f/0.19), riser = f2f/n exactly, tread 0.28, width 1.2, ≤ 16 risers/flight, landing 1.2. Origin bottom of the first riser, centred on the first flight, climbs to Godot −Z; last tread flush with the upper floor. Collision = smooth ramp |
| Railing | `arch_railing_w{100,200}` | 1.05 m, origin bottom of the start end |
| Columns | `arch_column_{sq,rd}40_h{300,350,400}` | bottom-centre |

Architecture collision is trimesh (`Collision`). To add a piece, add a `VARIANTS` entry or a
builder in `tools/blender/greybox/_kit.py`.

## 11. Troubleshooting

| Symptom | Fix |
|---|---|
| `build.py: Blender not found` | install 4.5 or pass `--blender` / set `$BLENDER` |
| `ExportError: mesh without material` / `not named M_<library_id>` | every visible mesh needs `ctx.material(...)` slots |
| `LOD0 has N triangles, budget is M` | simplify, or raise `TRI_BUDGET` within the style-guide limit |
| `MISMATCH` in `--check-determinism` | look for UVs before bevels, randomness not from `ctx.rng`, dict/set iteration feeding geometry, the Bevel modifier |
| Godot shows flat placeholder colours | the `world/materials/<id>.tres` is missing (see the import warning) or the `.glb.import` lacks `import_script/path`: rerun build.py, then `godot --import` |
| Marker missing in Godot | names must be unique PascalCase; do not parent markers to a `Collision-*` object |
| `Could not calculate tangents` | the exporter only does tris/quads; `export_glb` adds a Triangulate step for n-gons automatically |
| Unknown asset ids / wrong folder | id prefix decides `game/assets/<category>/` (`lib/naming.py PREFIX_CATEGORY`) |
