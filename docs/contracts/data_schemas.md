# Contract: data schemas (v1.0)

Schemas are in `game/contracts/data/*.gd` (lead). Data instances are `.tres` files owned by the env
listed. All data ids follow `groups.md`. The code headers are authoritative for field lists.

| Schema | Data owner | Location | Consumers |
|---|---|---|---|
| WeaponStats / WeaponDef / WeaponModDef | B | `content/data/weapons/`, `content/data/mods/` | A (firing), B (UI) |
| MeleeDef, ThrowableDef, DeployableDef, ArmorDef, MaskDef | B (MaskDef mesh: C) | `content/data/<kind>/` | A |
| Loadout | B (resolver) | runtime + save | A |
| SkillDef, PerkDeckDef | B | `content/data/skills/`, `content/data/perks/` | B (UI + resolver) |
| LootDef | B (values), C (bag models) | `content/data/loot/` | A, B |
| DifficultyDef | B | `content/data/difficulty/` | A, B |
| EnemyDef | A | `systems/ai/data/enemies/` | A, B (firing range dummies read health/plates) |
| HeistDef, HeistVariantTable | C | `world/heists/<id>/` | A, B |

## Weapons and mods
* `WeaponDef.akimbo: bool` (D-050): a pair of guns; Modifiers queries add the `akimbo` qualifier from it.
  Akimbo pairs are PISTOL class in the primary slot (PD2); anim_set `akimbo`.
* `WeaponDef.base` = stats with stock parts. Resolved stats = `base.plus(mod.delta)` for each equipped
  mod, then clamps (concealment 0–30, spread ≥ 0, mag ≥ 1), then skill modifiers are applied **at
  runtime by A** (mods are baked into resolved stats; skills are not, so the UI can show both).
* Each mod attaches its model at the weapon-model marker for its type:
  BARREL→`BarrelMount`, BARREL_EXT/SUPPRESSOR→`Muzzle`, SIGHT→`SightRail`, GADGET→`SideRail`,
  GRIP→`GripMount`, FOREGRIP→`Underbarrel`, STOCK→`StockMount`, MAGAZINE→`Magwell`,
  BODY/BOLT/AMMO/CHARM/SKIN→ model swap or material (B decides per weapon).
* Stock (default) parts are named `Stock<ModType>` in model scenes (`StockSight`, `StockMagazine`, `StockBarrel`...) and are hidden when a mod of that type is equipped.
* ENV B's `LoadoutResolver.resolve(loadout) -> Loadout` is the single implementation of stat
  resolution, concealment totals, and DR (lookup in the PD2-style curve). ENV A must not reimplement it.

## Strings
`game/content/data/strings/strings.csv` (ENV B), header `keys,en`, Godot's default CSV translation importer.
The lead registers the generated `strings.en.translation` in `project.godot` (internationalization/locale/translations)
when it first merges. No runtime Translation registration.

## Shell-by-shell reload timing (D-045)
For weapons with `reload_per_round_s > 0`:
`reload_time_s = reload_start_s + mag_size × reload_per_round_s + reload_end_s` (full top-up, PD2-style), and
`reload_empty_time_s = reload_start_s + mag_size × reload_per_round_s + reload_end_empty_s` (adds the pump).
ENV B's resolver **derives** both after mods (a mod changing `mag_size` changes the totals; mods don't add raw reload time
to shell weapons). ENV A's runtime loads shells one by one and may be interrupted by firing; the derived totals exist
for UI and animation length checks. Plowman: start 0.4, per 0.4333, end 0.4, end_empty 1.2 → 3.4 s / 4.2 s at 6 shells.

## WeaponStats addition (D-099)
`recoil_horizontal_bias_deg: float = 0.0`: signed per-shot mean of the horizontal kick (deg, + = right); additive in `plus()`; 0 for every weapon except PD2-drifting LMGs. Producer B (data), consumer A (CrewWeapons).
