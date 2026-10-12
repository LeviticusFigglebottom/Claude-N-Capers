# Masks: customisation design (B2-03, pd2_fidelity P8 / P9 / C5)

Owner: ENV B. Schema `MaskDef` is the lead's (`game/contracts/data/mask_def.gd`, D-019); meshes and
pattern textures are ENV D's (D-027, D-029). This file is the authority for the mask data model,
ids and lookup API.

## Model
PD2 builds a mask from **base shape × material × colour pair × pattern**. We do the same.

| Part | Id | Data | What it holds |
|---|---|---|---|
| Base shape | `mask_base.<name>` | `data/masks/parts/bases.tres` (`MaskBaseDef`) | `model_path` = ENV D glb `res://assets/masks/mask_base_<name>/mask_base_<name>.glb`; `requires_model` (hidden until the glb exists, B4-15); placeholder shape numbers |
| Material | `mask_material.<name>` | `data/masks/parts/materials.tres` (`MaskMaterialDef`) | `material_id` = shared library id (`world/materials/<id>.tres`), `library_material` ref, metallic/roughness/grain |
| Colour pair | `mask_colors.<name>` | `data/masks/parts/colors.tres` (`MaskColorDef`) | `color_a` (base), `color_b` (pattern areas) |
| Pattern | `mask_pattern.<name>` | `data/masks/parts/patterns.tres` (`MaskPatternDef`) | `texture_id`/`texture_path` (ENV D), `procedural` fallback, `scale` |

Part lists are `MaskPartList` resources **without an `id`**, so ContentDB's `masks` index only holds
`MaskDef` presets. List order is the UI order. Names: strings.csv `item.<part id>.name`.
Tuning (slot count, preview, placeholder grid, default composition): `data/masks/mask_tweak.tres`.

A **composition** is `{"base": id, "material": id, "colors": id, "pattern": id}` (Strings).

## Mask ids (Loadout.mask)
* `mask.<name>`: a preset `MaskDef` file in `data/masks/` (e.g. `mask.gilded_heron`). Presets fill
  `material_id` (library id), `color_a/b`, `pattern_id` (pattern part id) and may set
  `metadata/mask_base` (base part id, for the placeholder shape and the editor).
* `mask.custom.<n>`: the player's custom slot n, `PlayerProfile.custom_masks[n]` (a composition;
  `{}` = empty), n < `MaskTweak.custom_slot_count` (6).
* `""`: no mask.

## Runtime MaskDef (`MaskComposer.compose(comp, id)`)
`id` = the mask id, `model` = the base's glb if it exists (else null), `material_id` = the material's
library id, `color_a/b` = the pair, `pattern_id` = the pattern part id, `unlock` = "", meta
`composition` = the composition. Invalid compositions return null + `Log.error`.

## API for ENV A (attach on crew `Head`, characters.md)
```gdscript
# Owning peer (has the PlayerProfile):
var def: MaskDef = MaskCatalog.resolve(loadout.mask, profile)   # null = no mask
# Replication (ids only, JSON-safe; other peers have no profile):
var desc: Dictionary = MaskCatalog.descriptor(loadout.mask, profile)  # {"preset": id} or composition + "id"
var def2: MaskDef = MaskCatalog.from_descriptor(desc)
# Visual: Node3D "Mask", pivot face centre, -Z forward; mask material applied (model or placeholder).
var node: Node3D = MaskComposer.instantiate(def)
```
`MaskComposer.build_material(def)` alone gives the `ShaderMaterial` (`content/masks/mask_surface.gdshader`).

## Ownership and unlocks (P9 stub)
A part is owned when `default_owned` in data or listed in `PlayerProfile.owned_mask_parts`
(`MaskLocker.grant_part(profile, id)`; payday card drops call this later). Presets: owned when
`unlock` is empty or the id is in `owned_masks`. `MaskLocker.save_custom` refuses unowned parts.
`MaskLocker.available_ids(profile)` lists every equippable id (for pickers);
`MaskCatalog.display_name(id)` names it. `MaskLocker.equip(profile, id)` writes `Loadout.mask`.

## Save (v4)
`PlayerProfile.owned_mask_parts: Array[String]`, `custom_masks: Array[Dictionary]`.
`SaveService` v3 → v4 adds both empty; an equipped preset stays equipped.

## UI
`res://content/ui/masks/mask_screen.tscn` (`MaskScreen`, a UiScreen): `setup(profile)`,
`profile_slot`, signals `back_requested`, `mask_changed(mask_id)`. Left: owned presets and the custom
slots; centre: `MaskPreview` (SubViewport, auto spin, mouse drag / right stick / ui_left-right when
focused); right: part pickers (locked parts disabled), "Save into" slot, Save, Equip. Every change
is saved via SaveService.

## Placeholder and shader contract (until ENV D ships meshes/textures)
* Placeholder: `MaskComposer.placeholder_mesh(base)`: an original procedural face plate
  (superellipse outline, eye holes, snout, brow, optional ears) from the `MaskBaseDef` numbers.
* UV0 drives patterns: x across the face (0 = viewer's left looking at the front), y forehead (0) to
  chin (1), roughly front-projected. ENV D meshes must follow this so patterns line up, and use one
  surface (the mask material is applied as `material_override`).
* Pattern textures: red channel = pattern mask (0 → `color_a`, 1 → `color_b`) over UV0.

## B4-15 batch (masks content)
* **Colour pairs** (+6, every channel ≥ 0.12, style guide albedo floor, tested): Tide and Coral
  (default), Saffron and Plum, Frost and Slate (default), Oxblood and Brass, Mint Graphite, Sulfur and Ash.
* **Patterns** (+6, procedural in `mask_surface.gdshader`, `MaskPatternDef.Procedural` ids 8–13; the
  enum is append-only because saved data and the shader use the number): `scales` (8, offset
  scale rows), `circuit` (9, traces between grid cells + pads, decided by a per-cell hash so every
  peer draws the same board), `prowl` (10, wavy stripes growing in from the sides), `halftone`
  (11, 45° dot screen growing toward the chin, default-owned), `crackle` (12, jittered cell
  borders), `starburst` (13, rays from above the nose; `scale` = half the ray count). Each also has
  a `texture_id`/`texture_path` (`tex_mask_pattern_<name>`) that ENV D may supply later; the texture
  wins when present.
* **Materials** (+3, library ids that exist): `porcelain` → `tile_ceramic_white`, `ink_lacquer` →
  ENV D's `char_mask_lacquer_dark`, `stipple` → `polymer_stipple` (default-owned). `detail_mean`
  is the measured mean linear luminance of the library albedo (clamped to 0.05).
* **Presets** (+6, `data/masks/<name>.tres`, model = the base's ENV D glb, `metadata/mask_base`,
  colours equal to a colour pair so `composition_of` round-trips): Porcelain Vigil (visage), Tide
  Runner (vulpine), Night Circuit (owl, **locked: `unlock.payday_card`**), Sulfur Brute (bruiser),
  Oxblood Herald (heron, **locked: `unlock.achievement.cataclysm_clear`**), Paper Saint (visage).

### Preset unlocks
`MaskDef.unlock` ids: `unlock.payday_card` (`MaskCatalog.UNLOCK_PAYDAY`): the preset joins the
payday card `mask_part` pool (`PaydayCards.pool`, card detail "Complete mask") and the card grant
calls `MaskLocker.grant_preset` (adds to `owned_masks`). `unlock.achievement.<name>`: granted by
`MaskLocker.grant_unlock(profile, unlock_id)`; the achievement system is a stub, nothing calls it
yet. `MaskLocker.is_drop_owned(profile, id)` answers ownership for both preset and part ids.
`unlock.notoriety.rank_<n>` (B5-02): granted by a Notoriety rank-up. Presets: Ledger Regent (rank X) and
The Last Word (rank XXV). Notoriety also grants 10 colour pairs and 3 materials (Carbon Weave, Night
Anodized, Crown Gold) that never drop from payday cards (`Notoriety.exclusive_ids`); see
`content/docs/notoriety.md`.

### Payday card tiers
New rarer parts carry tiers in `data/payday/card_table.tres` `item_tiers`: rare (2) porcelain,
starburst, Night Circuit and the skull/gasmask/demon request slots; uncommon (1) the rest listed
there. Request slots carry their tier ahead of the mesh, so they drop at the right rarity the day
they light up.

## Batch-3 bases (ENV D D3-03, B7-02)
Twelve more base slots (`ram`, `stag`, `cat`, `boar`, `serpent`, `moth`, `knight`, `doll`, `sunburst`, `geo`,
`robot`, `jester`) with `requires_model = true` until their glb lands. Most sit behind an unlock id
(`MaskPartDef.unlock`: achievements or Notoriety ranks; owned via `MaskLocker.grant_unlock` / `apply_unlocks`,
never payday drops); `cat` and `boar` are payday drops. Mapping: `content/docs/achievements.md`.

## Requested bases (ENV D request spec, B4-15)
`bases.tres` holds five **request slots** with `requires_model = true`. Such a base is **hidden**
(`MaskCatalog.is_available` false): not in `MaskCatalog.parts()` (pickers, the mask screen, the
payday pool, any random choice), not grantable, not composable, never a placeholder. It lights up
with no data change as soon as `model_path` exists. `MaskCatalog.all_parts()` / `is_known()` see
them (data checks, docs). Strings exist already.

| Id | Name | Brief (original designs; no real-world brand or film likeness) |
|---|---|---|
| `mask_base.skull` | Grin Skull | stylised skull face plate, deep round sockets, nasal notch, tooth row relief (no lower jaw gap) |
| `mask_base.theatre` | Footlights | stage mask: smooth oval, high arched brows, carved smile, lightly asymmetric |
| `mask_base.gasmask` | Filter Face | full-face respirator look: big round lenses, single front filter canister, strap stubs at the sides |
| `mask_base.demon` | Horned Fury | snarling brow, two short swept horns, flared nostrils, fang relief (original, not a cultural replica) |
| `mask_base.goalie` | Crease Guard | rigid sports-style face guard: domed, many small vent holes, raised ribs |

Conventions every request must follow (same as the five shipped bases):
* **Path**: `res://assets/masks/mask_base_<name>/mask_base_<name>.glb` (+ `SOURCE.txt`), generated by
  `tools/blender/masks/base_<name>.py`.
* **Pivot**: face centre, midway between the eye centres at eye (cornea) depth; −Z forward, +Y up;
  seats on the crew `Head/Socket` (characters.md).
* **UV0**: front planar along −Z, x 0..1 = viewer's left to right (+X..−X), y 0..1 = top to bottom,
  so procedural patterns line up across every base; one UV island set, no overlaps on the front.
* **One surface / one material slot `M_char_mask_base`**; the game replaces it with the mask shader as
  `material_override` (colour pair × pattern × material grain), so no baked colour.
* Size: face half width about 0.08–0.10 m; tri budget 8000 LOD0, like the shipped bases.
