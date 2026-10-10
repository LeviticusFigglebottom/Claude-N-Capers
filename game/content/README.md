# game/content (ENV B)

Content & progression. Owner: ENV B. Shared API brief for everything under this folder; keep it
current when an API changes.

## Layout
```
content/
  data/                     every balance number (.tres / .csv); no constants in scripts
    weapons/ mods/ melee/ armor/ deployables/ loot/ difficulty/ masks/
    tweak/                  concealment_curve.tres, display_stats.tres, payout.tres, xp_curve.tres
    strings/strings.csv     all player-facing text (columns: keys,en)
    voice/lines.tres        voice line table (VoiceLineTable); text lives in strings.csv
  defs/                     content-side Resource schemas + ContentDB lookup
  progression/              LoadoutResolver, StatCalculator, PayoutCalculator, XpCurve
  save/                     SaveService, PlayerProfile
  strings/                  StringTable
  ui/                       every UI scene (menus, HUD, results); hud/mock/ = LocalHudModel mock
```

## Ids (contracts/groups.md style `domain.snake_name`)
`weapon.kestrel_p9`, `mod.p9_suppressor`, `mod.p9_reflex_sight`, `mod.p9_extended_mag` (+ stock
defaults `mod.p9_stock_barrel` etc. if needed), `melee.folding_knife`, `armor.tailored_suit`,
`armor.patrol_vest`, `deployable.doctor_bag`, `deployable.ammo_bag`, `deployable.body_bag_case`,
`loot.jewelry`, `loot.cash`, `loot.body_bag`, `mask.<name>`. Difficulty files are
`difficulty/<routine|tense|hazardous|brutal|lethal|cataclysm>.tres`.

## Public APIs (static unless noted)
* `ContentDB` (`defs/content_db.gd`): `weapon(id) -> WeaponDef`, `mod(id) -> WeaponModDef`,
  `melee(id) -> MeleeDef`, `armor(id) -> ArmorDef`, `deployable(id) -> DeployableDef`,
  `loot(id) -> LootDef`, `difficulty(d: Enums.Difficulty) -> DifficultyDef`, `mask(id) -> MaskDef`,
  `by_id(kind, id)`, `all_of(kind)`, `all_weapons/all_mods/all_melees/all_armors/all_deployables/
  all_loots/all_difficulties()`, `tweak(name) -> Resource` (`&"concealment_curve"` ...). UI text comes
  from strings.csv `item.<id>.name` (display_name in .tres is a debug fallback). Unknown id →
  `Log.error` + null. Scans `res://content/data/<kind>/` with `ResourceLoader.list_directory`.
* `LoadoutResolver.resolve(loadout: Loadout) -> Loadout` (returns a resolved copy): resolved
  weapon stats (base + mods, clamps), `concealment_total`, `detection_risk`, `modifiers`.
  `LoadoutResolver.concealment_breakdown(loadout) -> Dictionary` for UI.
* `StatCalculator.display(stats: WeaponStats) -> Dictionary` PD2-style UI numbers
  (`damage, accuracy, stability, concealment, threat, mag, total_ammo, rof, reload`).
* `StringTable.text(key: StringName, args: Dictionary = {}) -> String` = `tr(key)` + `{name}`
  formatting. Strings: `data/strings/strings.csv` (standard Godot CSV import; the lead registers
  the translation in project.godot, D-021). No runtime registration.
* `PayoutCalculator.compute(result: Dictionary) -> Dictionary` from a HeistResult
  (contracts/events.md). Output shape documented in its header.
* `SaveService` / `PlayerProfile`: versioned JSON at `user://profiles/profile_<n>.json`;
  `load_profile/save_profile/migrate/apply_heist_payout(p, payout, XpCurve.level_for_xp)`.
* `XpCurve.level_for_xp(xp)`, `xp_for_level(level)`. `VoiceLineTable` at `data/voice/lines.tres`.

## Rules
Typed GDScript, gdlint clean, no `randi()/randf()`, never assume one player, every string through
`StringTable`, only grant keys from `ModifierKeys.KEYS`. Tests: `game/tests/b/test_*.gd`.
