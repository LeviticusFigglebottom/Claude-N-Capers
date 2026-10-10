# Contract: data schemas (v1.0)

Schemas are in `game/contracts/data/*.gd` (lead). Data instances are `.tres` files owned by the env
listed. All data ids follow `groups.md`. The code headers are authoritative for field lists.

| Schema | Data owner | Location | Consumers |
|---|---|---|---|
| WeaponStats / WeaponDef / WeaponModDef | B | `content/data/weapons/`, `content/data/mods/` | A (firing), B (UI) |
| MeleeDef, ThrowableDef, DeployableDef, ArmorDef | B | `content/data/<kind>/` | A |
| Loadout | B (resolver) | runtime + save | A |
| SkillDef, PerkDeckDef | B | `content/data/skills/`, `content/data/perks/` | B (UI + resolver) |
| LootDef | B (values), C (bag models) | `content/data/loot/` | A, B |
| DifficultyDef | B | `content/data/difficulty/` | A, B |
| EnemyDef | A | `systems/ai/data/enemies/` | A, B (firing range dummies read health/plates) |
| HeistDef, HeistVariantTable | C | `world/heists/<id>/` | A, B |

## Weapons and mods
* `WeaponDef.base` = stats with stock parts. Resolved stats = `base.plus(mod.delta)` for each equipped
  mod, then clamps (concealment 0–30, spread ≥ 0, mag ≥ 1), then skill modifiers are applied **at
  runtime by A** (mods are baked into resolved stats; skills are not, so the UI can show both).
* Each mod attaches its model at the weapon-model marker for its type:
  BARREL→`BarrelMount`, BARREL_EXT/SUPPRESSOR→`Muzzle`, SIGHT→`SightRail`, GADGET→`SideRail`,
  GRIP→`GripMount`, FOREGRIP→`Underbarrel`, STOCK→`StockMount`, MAGAZINE→`Magwell`,
  BODY/BOLT/AMMO/CHARM/SKIN→ model swap or material (B decides per weapon).
* ENV B's `LoadoutResolver.resolve(loadout) -> Loadout` is the single implementation of stat
  resolution, concealment totals, and DR (lookup in the PD2-style curve). ENV A must not reimplement it.
