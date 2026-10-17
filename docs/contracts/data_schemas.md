# Contract: data schemas (v1.4)

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

## v1.1: HeistDef.assault_events (D-114 §5, PO6-17)
`HeistDef.assault_events: Array[Dictionary] = []`, the heist's RNG assault event rows (producer C in the heist's
`<id>_def.tres`, or A's tweak meanwhile; consumer A's AssaultEventRunner). Row = ENV A's `AssaultEventsTweak` row:
```
{ "kind": StringName,        # &"turret_van" | &"heli" | &"breach" (AssaultEventsTweak.KINDS; other kinds are ignored)
  "weight": float,           # relative pick weight among eligible rows
  "min_wave": int,           # first assault wave the row may fire in
  "cooldown_s": float,       # heist-clock seconds before this row may fire again
  "max_per_heist": int,      # cap on firings of this row per heist
  "params": Dictionary }     # merged over AssaultEventsTweak.kind_defaults[kind] (row wins)
```
**Precedence:** when a HeistDef has a non-empty `assault_events`, those rows **replace** the
`AssaultEventsTweak.heists[heist_id].events` rows for that heist; an empty array falls back to the tweak (the tweak is the
fallback, today the only source for `glasshouse`). Global timing (roll interval, chance per difficulty, min gap,
max active) stays in the tweak. Run options `assault_events: false` (off) and `assault_events_tweak` (test tweak) still win.


## v1.2: scoped sights (D-118 follow-up; P's FP scope overlay)
WeaponStats gains `is_scope: bool` (merged OR; true for magnified optics with magnification ≥ 3.5 — P's FP overlay at full
ADS), `scope_reticle: StringName` (&"duplex" default / &"mildot" / &"chevron" / &"dot"; last non-empty wins) and
`scope_reticle_color: Color` (alpha 0 = default near-black, bright = illuminated; last alpha > 0 wins). ENV B sets them on
sight-mod deltas; make_delta() needs no change (defaults contribute nothing).

## v1.3: HeistDef stealth difficulty fields (D-130)
* `pager_max_by_difficulty: Array[int] = []`: pagers the crew may answer, indexed by `Enums.Difficulty`; empty =
  `StealthTweak.pager_max_answers`. Producer C (the heist's def / generator row), consumers A (PagerSystem,
  LocalHudModel `pagers_max`), B (briefing/difficulty card).
* `camera_titan_min_difficulty: int = -1`: cameras are Titan (indestructible) from this `Enums.Difficulty`; -1 =
  `StealthTweak.camera_titan_min_difficulty`. A camera's own `titan` export still wins. Producer C, consumers A
  (`SecurityCamera.is_titan()`), B (card).
**v1.3 precedence (LEAD, round 231):** the run's pager cap is (1) a rolled `pager_max_answers` variant scalar, else (2)
`HeistDef.pager_max_by_difficulty[difficulty]`, else (3) `StealthTweak.pager_max_answers` (A's `PagerSystem.cap_for`).
Every reader (B's BriefingIntel, the HUD) uses the same order.

## v1.4 (D-139 heist freshness, B 1622ac1f)
- **PlayerProfile v9:** new field `freshness`:
  `{"recent": [heist_id String, oldest first, ≤ PayoutTweak.freshness_memory], "runs": int ≥ 0, "last_run": {heist_id: int ≥ 0}, "completed": [heist_id]}`.
  ProfileSchema kind FRESHNESS: a bad list is emptied, a bad counter dropped (each with a warning).
  Migration 8 → 9: empty memory; every `career.heists` id with `won > 0` enters `completed` with `last_run = 0` (the rotation
  bonus ramps from the migration, it does not grant +10 % at once); an existing `freshness` key is kept.
  `SaveService.CURRENT_VERSION = 9`; golden fixture v8 added.
- **PayoutTweak:** `freshness_memory: int = 10`, `repeat_step = 0.10`, `repeat_floor = 0.10`, `rotation_step = 0.01`,
  `rotation_cap = 0.10`.
- **PayoutCalculator.compute():** 9th arg `freshness: float = 1.0`. Output adds `freshness` (the mult) and
  `freshness_money` (signed int). `gross = round(subtotal × crew_alive_mult) + freshness_money`; the civilian penalty comes
  after, unscaled; stash/spending from that gross. `xp_lines` has **8** entries; the 8th, `ui.results.xp.freshness`, is
  `round(running × (mult − 1))`, the last multiplicative step, applied on failure too (`XP_FRESHNESS`).
- **HeistFreshness** (`content/progression/heist_freshness.gd`): evaluated per player from their own profile before
  compute, recorded after the payday is applied.
