# tools/texgen: procedural textures, material library, LUTs (ENV C)

Pure Python (numpy, scipy, Pillow). No photos, no third-party textures, no `noise` package
(`noise.py` is our own tileable implementation). Every output is deterministic and committed.

```bash
python3 tools/texgen/build.py                       # everything (~2 min on 4 cores)
python3 tools/texgen/build.py --only brick_red       # one material (comma-separate or repeat --only)
python3 tools/texgen/build.py --check-determinism    # build, rebuild into a temp dir in a fresh process, compare sha256
python3 tools/texgen/build.py --list                 # library ids, sizes, tile size, texel density
python3 tools/texgen/build.py --jobs 2               # limit worker processes (default min(4, cpus))
python3 tools/texgen/build.py --preset gsr           # art-direction preset (default gsr)
/opt/godot/godot --headless --path game --import     # then let Godot import the PNGs
```

Preview / contact sheet (Godot, Vulkan via lavapipe under xvfb):

```bash
xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --path game --resolution 1920x1080 \
  res://world/tools/material_preview.tscn -- --out=docs/levels/_materials/material_preview_v1.jpg
# options: --only=marble_cream,brass (close-up, 3 per row)  --env=glasshouse  --cols=8  --quality=0.85
```

## Outputs

| Output | Path |
|---|---|
| Textures | `game/assets/textures/<lib_id>/tex_<lib_id>_{albedo,orm,normal}.png` + `.png.import` + `SOURCE.txt` |
| Materials | `game/world/materials/<lib_id>.tres` (ORMMaterial3D, `resource_name = "M_<lib_id>"`) |
| Trim table | `game/assets/textures/trim_interior/trim_table.json` |
| LUTs | `game/assets/luts/lut_<name>.png` (+ `.import`: `3d_texture`) |
| Environments | `game/world/lighting/env_<name>.tres`, `game/world/lighting/sun_<name>.tscn` |

`grey_*.tres` in `game/world/materials/` are the greybox materials (another generator); texgen never
writes them.

## UV and texel-density convention (READ THIS if you UV-map in Blender)

* **1 UV unit = 2.0 m of surface, for every library material.** (`library.TILE_M`; equivalently
  texture width in px / texel density in px/m: 1024 px / 512 px/m = 512 px / 256 px/m = 2 m.)
* Texture size sets the density: **1024 px = 512 px/m** (walls, floors, props within reach),
  **512 px = 256 px/m** (`ceiling_tile`; plus `chrome`, `rubber_black`, `plastic_matte`,
  `glass_clear`, which have almost no texture detail). Because the UV scale is the same for all,
  a mesh can swap materials without re-unwrapping.
* **Blender lib:** world-scaled UVs are `uv = world_metres / 2.0` (i.e. metres x 0.5). Anchor UVs
  to **world** coordinates (not per-object 0..1) so tile seams, brick courses and slab joints line
  up across modules on the 0.5 m grid: every patterned library material has its joints at whole
  fractions of 2 m (tiles 0.2 / 0.5 / 1.0 m, 9 bricks x 26 courses per 2 m).
* **Orientation:** U runs horizontally along a wall (and along the length of a trim strip);
  V runs up the wall. The image's top row is Blender `v = 1` (glTF/Godot `v = 0`). Directional
  materials (wood grain, brushing, bricks, carpet rows) run **along U**.
* Floors/ceilings: U = world X, V = world -Z (any consistent planar projection works; the
  materials are isotropic or grid-aligned).
* **First-person weapon materials (D-026) are the exception: 1 UV unit = 1.0 m, 1024 px/m.**
  `polymer_black`, `polymer_stipple`, `steel_blued`, `steel_bare`, `metal_matte`, `paint_white`,
  `brass_cartridge` are 1024 px textures covering 1 m (`library.py` `tile_m: 1.0`), which is exactly
  what `tools/blender/lib/uv.box_project(density=1024)` produces (uv = metres x 1024 / 1024).
  `glass_lens_tint` is 512 px over 1 m (512 px/m; it is featureless, same UV scale).
  `emissive_reticle_red` is an untextured emissive `StandardMaterial3D` (a reticle is a tiny
  emissive mesh; emission, not unshaded, so its HDR value reaches the glow pass).
* Every textured library material stores its tile size as `metadata/uv_tile_m` (2.0 or 1.0);
  `material.get_meta(&"uv_tile_m")` tells tools which scale to use.
* Godot materials use mesh `UV1` (triplanar OFF). The preview tool alone uses world triplanar at
  `uv1_scale = 1 / uv_tile_m` to emulate this convention.

### Trim sheet `trim_interior`

`trim.py` stacks horizontal strips; each borrows the surface of a library material and adds a baked
moulding profile (normal + AO). Strip heights are in pixels at 512 px/m, so a strip's V extent equals
its real height (`height_m`); map a strip onto geometry of that height for the right density. U repeats
every 2 m. Each strip has 4 px padding rows above/below (replicated edge rows) against mip bleed; the
table gives ranges **without** padding. `trim_table.json` gives, per strip: `name`,
`source_material`, `profile`, `height_m`, `px_top`/`px_bottom`, `v_top_gltf`/`v_bottom_gltf`
(top = 0) and `v_min_blender`/`v_max_blender` (bottom = 0). Strips (v1): baseboard, crown_cornice,
door_casing, chair_rail, wood_trim, wood_trim_wide, metal_edge, chrome_band, brass_inlay,
rubber_strip, rubber_bumper, metal_kickplate, plastic_edge, picture_rail. Rows below the last strip
are flat trim paint.

## Map conventions

* **Albedo** sRGB PNG (RGBA for `glass_clear`, alpha = opacity). Import: VRAM, BPTC
  (`compress/high_quality=true`) because S3TC/BC1 tints dark neutrals green.
* **ORM** linear PNG: R = AO, G = roughness, B = metallic. Materials set `metallic = 1`,
  `roughness = 1` (multipliers) and `ao_enabled = true`, so the texture drives all three.
* **Normal** tangent space, **OpenGL convention (Y+, green up)**; import `compress/normal_map=1`,
  `normal_map_invert_y=false`.
* `.import` files are written by build.py with the parameters above. Godot adds uid/paths on import;
  later builds only patch the parameters they own (and rewrite the file, keeping the uid, if Godot
  auto-imported it with the wrong importer), so rebuilding does not churn uids.

## Colour rules (style_guide.md §3), enforced in `materials/base.py:finalize`

* Albedo per-texel **linear luminance clamped to 0.04–0.85** (inside the sRGB 30–240 band too).
* HSV **saturation ≤ 0.75** (of the sRGB-encoded value).
* **Metals** (metallic > 0.5): roughness ≥ 0.15.
* The build **fails** if any albedo texel is within RGB distance 40 of the interactable accent `#4FD1E8`.
* `SOURCE.txt` records luminance/roughness/metal/AO stats per material.

## Art direction is a preset

`presets/gsr.py` ("Grounded Stylized Realism", provisional, D-012) holds every colour (sRGB hex),
roughness range, pattern size, wear/grime amount, the LUT grades and the environment settings.
Generators never hard-code colours. To change direction: copy `gsr.py` to `presets/<name>.py`,
edit, `build.py --preset <name>`. Global `scales.wear` / `scales.grime` scale all weathering (bank
pristine ~0.3, docks heavy ~1.8). Per-material `wear`, `grime`, `grime_color`, `grime_darken`,
`grime_low`, `relief_ref_mm` tune `materials/base.py:weather`.

## Modules

| Module | What |
|---|---|
| `noise.py` | Tileable gradient (Perlin) / value noise, fBm, ridged, Worley (F1, F2, cell id), domain warp, per-cell random. Periodic lattices; seeded only via `Generator(PCG64(seed))`; child seeds via crc32. |
| `ops.py` | levels, blend modes, wrap-around blur, normal-from-height (OpenGL Y+), AO-from-height (multi-scale cavity), curvature / edge / cavity masks, tile grids + bevel profiles, sRGB/linear, albedo rule enforcement. |
| `orm.py` | ORM packing and deterministic float→uint8. |
| `io.py` | Deterministic PNG writer (no metadata, zlib level 9, no optimize pass), text writer, sha256. Import as `from texgen import io as tio`. |
| `materials/<lib_id>.py` | One generator per material: `generate(ctx) -> Maps` (albedo linear, roughness, metallic, height in metres, options). |
| `materials/base.py` | `Ctx` (preset params, seed, coords, `per_m()` tile-safe frequencies), `Maps`, `weather()` (edge wear / cavity grime from height), `finalize()` (rules, AO, normal, encoding). |
| `trim.py` | Trim sheet + UV table. |
| `lut.py` | 3D LUT strip generation and grade ops. |
| `godot.py` | `.tres` / `.tscn` / `.import` writers. |
| `library.py` | Library table: ids, sizes, `TILE_M`. |
| `build.py` | CLI. |

## Adding a material

1. Add `materials/<lib_id>.py` with `generate(ctx)`; use `ctx.per_m(cells_per_metre)` for every
   lattice period (integer cells per tile keeps it seamless) and `ctx.col("<key>")` for colours.
2. Add its parameters under `presets/gsr.py["materials"]["<lib_id>"]` and an entry in `library.py`.
3. `build.py --only <lib_id>`, `godot --import`, preview with `--only=<lib_id>`, look at it.

Seeds: `zlib.crc32(lib_id)`; sub-features use `ctx.s("<feature>")`.

## LUTs (`lut.py`)

32³ LUT stored as a 1024 x 32 strip: slice b (blue) occupies columns `[32b, 32b+32)`; x = red,
y (top = 0) = green. Imported with `importer="3d_texture"`, `slices/horizontal=32`, lossless, no mips
→ `CompressedTexture3D`, assigned to `Environment.adjustment_color_correction`. Godot samples it with
the post-tonemap **sRGB-encoded** colour and no half-texel remap, so texel i stores
`grade((i + 0.5) / 32)`. Verified in Godot 4.7.2: the neutral LUT reproduces inputs within 1/255
across the range, except the extreme ends clamp (0 → 4/255, 255 → 251/255).

Grades (`presets/gsr.py["luts"]`): `neutral` (identity) and `glasshouse` (dusk: warm highlights,
slightly cool shadows, gentle contrast 1.06 around 0.45, saturation 1.04).

## Environment

`env_glasshouse.tres`: procedural blue-hour sky (`ProceduralSkyMaterial`), sky ambient + reflections,
AgX tonemap, SSAO, SSIL, subtle screen-blend glow, faint exponential fog, colour correction =
`lut_glasshouse`. The sky's sun disc follows the scene's `DirectionalLight3D`; instance
`sun_glasshouse.tscn` (4° elevation, azimuth 250°, warm `#FF9E66`, energy 0.35) in the level.

## Determinism

Byte-identical across runs and processes (verified with `--check-determinism`, which rebuilds in a
fresh process with a different `PYTHONHASHSEED` and compares sha256 of every PNG/JSON/SOURCE.txt).
Results depend on numpy's float maths: a numpy/Pillow major upgrade may change bytes. Rebuild
everything and commit if it does.
