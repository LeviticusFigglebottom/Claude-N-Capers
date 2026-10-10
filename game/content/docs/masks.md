# Masks: customisation design (B2-03, pd2_fidelity P8 / P9 / C5)

Owner: ENV B. Schema `MaskDef` is the lead's (`game/contracts/data/mask_def.gd`, D-019); meshes and
pattern textures are ENV D's (D-027, D-029). This file is the authority for the mask data model,
ids and lookup API.

## Model
PD2 builds a mask from **base shape × material × colour pair × pattern**. We do the same.

| Part | Id | Data | What it holds |
|---|---|---|---|
| Base shape | `mask_base.<name>` | `data/masks/parts/bases.tres` (`MaskBaseDef`) | `model_path` = ENV D glb `res://assets/masks/mask_base_<name>.glb`; placeholder shape numbers |
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
