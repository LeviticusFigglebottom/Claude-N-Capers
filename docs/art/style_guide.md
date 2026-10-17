# Art and audio style guide

Owner: **LEAD** (ENV C proposes changes via its status file). Every asset in the game, including
ENV B's weapons, follows this guide.

## 1. Art direction

**Direction: "Grounded Stylized Realism" (GSR). LOCKED by the product owner (D-035)**, after the
side-by-side samples in `docs/art/style_samples/`. The `a_gsr` renders are the reference look;
`b_noir`/`c_photo` stay only as history.

* **Real-world proportions and PBR shading.** Forms are *simplified and confident*: chamfered
  edges (2–8 mm bevels that catch light), clean silhouettes, no noisy micro-detail.
* **Detail sits at mid frequency.** Panel lines, seams, wear on edges, grime in cavities. All of it
  is generated procedurally from curvature/AO masks, never from photos.
* **Lighting and colour grading do the heavy lifting.** Each heist has a strong, art-directed mood
  (see §3).
* Characters use realistic proportions with slightly enlarged hands and head (×1.03) for
  readability. Outfits are readable by silhouette at 30 m (a Wrecker must be unmistakable).
* **Reference feel:** a clean modern heist thriller. Readable like a competitive shooter,
  atmospheric like a crime film.

Rejected options (D-035): (B) Neo-noir graphic, (C) Gritty photoreal. GSR may still borrow
heist-specific accent lighting (e.g. Glasshouse neon) and per-heist LUT grading, as already planned
in §3 and §7, while keeping readability first.

**Reference renders:** `docs/art/style_samples/a_gsr/counter.png` (props and materials bar) and
`a_gsr/officer.png` (character bar, once the D1-00 head fix lands). Every new asset is judged
against them.

## 2. Units, scale and grid

* 1 unit = 1 m. +Y up, −Z forward. Real-world sizes (see level_standards.md §2).
* **Modular grid:** 0.5 m snap; wall modules 0.5 / 1 / 2 / 4 m wide × floor-to-floor high; wall
  thickness 0.2 m interior, 0.4 m exterior; door/window openings align to the 0.5 m grid.
* Pivot rules: see contracts/visual_slots.md.

## 3. Colour

* **Global rules:** albedo luminance is limited to 0.04–0.85 (linear sRGB 30–240). Exception (D-038): black polymers, rubber and black paint may go down to 0.02 linear. Metals are
  albedo-coloured with roughness ≥ 0.15. No pure black or pure white. Saturation stays at ≤ 0.75
  except signage, emissives and the **interactable accent**.
* **Interactable accent**: a cool cyan `#4FD1E8` reserved for UI highlights. World surfaces must
  never use it, so highlights always read.
* **Faction colours:** police navy `#1E2A44` + hi-vis `#D7E34A` trim; TAC charcoal `#2B2F33`;
  Phantom goggles green `#3BFF6A` emissive; Stinger electric blue `#59A8FF`; Wrecker black
  `#141518` + hazard yellow `#E6B422` faceplate; Corpsman white `#DADCD8` + red cross
  `#B3261E`; Aegis bubble `#7FC8FF` at 20% alpha. Crew masks are free.
* **Per-heist palettes** (each has 1 dominant, 1 secondary, 1 accent, a LUT and a time of day):

| Heist | Dominant | Secondary | Accent | Mood / time |
|---|---|---|---|---|
| glasshouse | warm ivory `#E8DCC8` | walnut `#5A3B28` | brass `#C9A227` + neon magenta sign `#FF3EA5` | dusk, blue-hour exterior, warm interior |
| night_deposit | slate green `#3F5A52` | marble cream `#D9D2C2` | bank red `#9E2B25` | night, sodium streetlights |
| shadow_ledger | graphite `#2E3136` | glass teal `#5D8C8F` | cold white LED `#CFE3EE` | late night, rain |
| dockside_burn | rust `#7A4A2E` | concrete `#7D7F7C` | flare orange `#FF6B1A` | pre-dawn fog |
| ostrander_federal | limestone `#CBC3B0` | deep ultramarine `#2F3F6B` | meridian bronze `#B8873A` | Friday afternoon 15:10, broken cloud, low SW sun shafts (LUT `lut_ostrander_federal`: warm highlights, clean neutral mids; C, OF-C2) |

## 4. Materials and textures

* **PBR (Godot `StandardMaterial3D` / `ShaderMaterial`):** albedo (sRGB), ORM packed (R = AO,
  G = roughness, B = metallic, linear), normal map in **OpenGL convention (Y+)**, optional
  emission. Godot reads ORM via `ORMMaterial3D`, which is the preferred material.
* **Texel density:** 512 px/m for surfaces within reach (walls, floors, props ≤ 2 m), 256 px/m for
  ceilings and distant geometry, 1024 px/m for first-person weapons and hands. Max texture size
  2048 (weapons 2048, characters 2048 body + 1024 head).
* **Shared material library** (`game/world/materials/`): tiling trim sheets and tileables generated
  by `tools/texgen/`: plaster, painted drywall, concrete, terrazzo, marble, carpet, ceiling tile,
  wood veneer, brushed steel, chrome, brass, glass, rubber, fabric, leather, plastics, brick,
  asphalt and more. Use the library first; per-asset textures only when needed.
* **Wear:** generated from curvature and AO (edge wear, cavity grime) with heist-specific intensity
  (bank: pristine; docks: heavy).
* **Glass:** a shared shader with fake refraction, dirt mask and fresnel; breakable glass swaps to a
  cracked variant and spawns shards (ENV C FX).
* **Decals:** `Decal` nodes for grime, signage, stains and wet floor; projection depth ≤ 0.1 m;
  never cross a door.

## 5. Geometry

* Triangles (LOD0): props 50–8k, hero props ≤ 20k, characters ≤ 35k, first-person weapons ≤ 25k,
  modular wall pieces ≤ 500.
* **LODs:** use Godot importer auto-LOD (`meshes/generate_lods`) plus `visibility_range_end` on
  small clutter (≤ 25 m) and medium props (≤ 60 m).
* **Collision:** simplified `StaticBody3D` boxes or convex hulls named `Collision`. Never use
  trimesh collision on props; only on architecture.
* Normals: weighted normals for bevelled hard-surface models; no smoothing errors.

## 6. Asset pipeline rules (reproducibility)

* **Every asset is produced by a checked-in script.** `tools/blender/<category>/<asset>.py` builds
  the model in Blender (headless) using `tools/blender/lib/` helpers (materials, bevel, UV, export,
  naming). `tools/texgen/` creates textures (Python: numpy, noise, Pillow; or Blender bakes).
  `tools/audiogen/` creates sounds.
* **Deterministic:** fixed seeds (`seed = hash(asset_id)`), no time- or OS-dependent randomness, a
  pinned Blender version (4.5 LTS, `tools/setup/install_blender.sh`). Re-running a script must
  produce a byte-identical file, or at least an identical glTF scene structure (CI checks hashes
  of a sample).
* **One command** regenerates a category: `tools/blender/build.py --category props` (ENV C);
  `tools/blender/build.py --category weapons` (ENV B, using the same lib).
* Outputs go to `game/assets/<category>/<name>/` and are committed. Never edit an output by hand.
  Each output folder contains `SOURCE.txt` naming its generating script and arguments.
* **Export:** glTF 2.0 binary (`.glb`), +Y up, apply transforms, meters, tangents on, no cameras or
  lights, materials exported as names only (Godot side assigns library materials through an import
  script `world/tools/import/glb_post_import.gd` by material-name prefix `M_<library_id>`), or
  embedded textures for unique assets.
* **Naming:** `<category>_<name>[_<variant>]`, e.g. `prop_desk_office_a.glb`, `arch_wall_drywall_2m.glb`,
  `char_security_officer.glb`, `wpn_kestrel_p9.glb`, `mod_suppressor_short.glb`, `tex_marble_cream_albedo.png`
  / `_orm.png` / `_normal.png`, `sfx_pager_beep.ogg`, `mus_glasshouse_assault.ogg`. Lowercase snake_case.
  Material slots `M_<library_id>`.
* **No third-party asset packs, models, textures, HDRIs, fonts or sounds.** Fonts: we use
  open-licence font *software* only if listed in `docs/third_party.md` (fonts are code-like assets;
  this is a lead decision: allowed, logged). Skies are procedural (`ProceduralSkyMaterial` or our
  own sky shader).

## 7. Lighting (Godot 4.7)

* **Interiors:** SDFGI off. Use `VoxelGI` per heist interior (baked in the editor by ENV C, data
  committed) or `LightmapGI` if bake works in the pipeline (ENV C to evaluate in P1 and report).
  Add `ReflectionProbe`s per room and `OccluderInstance3D` for culling.
* **Exteriors:** `DirectionalLight3D` sun/moon matching the heist time of day, plus a procedural sky.
* **Every light has a fixture** (level_standards §3.7). Practical lights: warm 2700–3200 K in
  public/residential, 4000 K offices, 5000–6500 K back-of-house/industrial. Emission on fixtures
  matches the light colour.
* **Post:** filmic tonemap (AgX), per-heist LUT (3D texture generated by `tools/texgen/lut.py`),
  subtle bloom, SSAO/SSIL on, minimal chromatic aberration (none on the HUD).

## 8. VFX

GPUParticles3D with procedural textures: muzzle flash (per weapon family), shell ejection,
impact (per surface material: concrete dust, wood splinters, metal sparks, glass), blood (muted,
dark, non-gory), smoke/flashbang, Stinger arc, ECM burst, Aegis bubble, drill sparks, glass shatter.

## 9. Audio

* **All sounds are synthesized or procedurally generated** in `tools/audiogen/` (Python with numpy
  and scipy: oscillators, noise, filters, FM, granular, convolution with *generated* impulse
  responses). Recording real-world sounds ourselves would be allowed but is not available to us.
  No sample packs.
* Format: generate 48 kHz/24-bit WAV, export OGG Vorbis q6 into `game/assets/audio/` (music q5).
  Loudness: SFX normalised to −18 LUFS short-term peaks −1 dBTP; music −16 LUFS integrated; voice
  −20 LUFS.
* **Readability first:** each special's cue (audio_cues.md) occupies a distinct frequency/rhythm
  niche and must be identifiable over assault music in a blind test (ENV C provides a "mix test"
  scene).
* **Music:** stems per phase (contracts/audio_cues.md), 120–150 BPM loud tracks, beat-synced
  transitions on bar boundaries; stealth tension beds at 60–90 BPM.
* **Voice:** text lines with optional synthesized voice. Mercer gets a "radio-processed" formant
  voice. Heister callouts are short barks. TTS engines count as *code* (allowed if the licence
  permits; lead decision when proposed).
