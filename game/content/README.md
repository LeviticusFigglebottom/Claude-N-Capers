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
  `LoadoutResolver.concealment_breakdown(loadout) -> Dictionary` for UI
  (`primary, secondary, melee, armor, bonus, total, detection_risk`).
  `LoadoutResolver.concealment_bonus(loadout) -> int` / `concealment_bonus_from(loadout, modifiers)`:
  sum of `stealth.concealment_add.<melee|armor|primary|secondary|all|suppressed>` grants (D-022 QB-6); a slot
  qualifier counts only while that slot is filled; added after the per-weapon 30 cap, so the total
  can exceed 120. Empty slot = 30 is a P1-only rule (QB-11; P4 rejects empty weapon slots).
* `StatCalculator.display(stats: WeaponStats) -> Dictionary` PD2-style UI numbers
  (`damage, accuracy, stability, concealment, threat, mag, total_ammo, rof, reload`).
* `StringTable.text(key: StringName, args: Dictionary = {}) -> String` = `tr(key)` + `{name}`
  formatting. Strings: `data/strings/strings.csv` (standard Godot CSV import; the lead registers
  the translation in project.godot, D-021). No runtime registration.
* `PayoutCalculator.compute(result, difficulty_def = null, tweak = null, is_pro = false,
  crew_slot = -1, banked_stealth_mult = 1.0) -> Dictionary` from a HeistResult
  (contracts/events.md). Output shape documented in its header. Stealth bonus (D-022 QB-13, S11.1):
  pass `PlayerProfile.banked_stealth_mult`; the "stealth" XP line spends that bank on a success.
  Output adds `stealth_bonus_consumed: bool` and `stealth_bonus_banked: float` (the tweak's
  `stealth_xp_bonus_mult` after a successful stealth heist, else 1.0). UI string:
  `ui.results.stealth_bonus_banked` ("... +{pct}%").
* `SaveService` / `PlayerProfile`: versioned JSON at `user://profiles/profile_<n>.json`
  (`CURRENT_VERSION` 2; v2 adds `banked_stealth_mult`, default 1.0);
  `load_profile/save_profile/migrate/apply_heist_payout(p, payout, XpCurve.level_for_xp)`.
  `apply_heist_payout` resets the bank when `stealth_bonus_consumed`, then stores
  `stealth_bonus_banked` if > 1.0.
* `ContentDB.inject(kind, key, res)`: tests/tooling only (test-only SkillDef/PerkDeckDef);
  `clear_cache()` drops it.
* `XpCurve.level_for_xp(xp)`, `xp_for_level(level)`. `VoiceLineTable` at `data/voice/lines.tres`.

## App shell and UI (D-024)
* `MenuFlow` (`ui/menus/menu_flow.tscn`) is the app shell; `core/boot.gd` routes to it. It owns
  launch (`launch(heist_id, difficulty, loadout, seed)`: `Net.start_solo` + resolved loadout + HUD/payday
  CanvasLayer + dynamic `HeistLauncher.launch`; stub screen when the launcher is absent), and
  `HeistRuntime.teardown()` + `Net.leave()` after results. Direct launch:
  `godot --path game -- --heist=<id> [--seed=<n>] [--difficulty=<0..5>]` (seed defaults to the
  time, difficulty to Routine; unknown heist or bad value logs an error and stays on the main menu).
  Parsing: `LaunchArgs.parse(args) -> {direct, heist_id, has_seed, seed, difficulty, errors}`,
  `LaunchArgs.validate_heist(id, known_ids)`. `MenuFlow.direct_launch(parsed) -> bool`.
* `HeistCatalog.entries()/ids()`: heists from `HeistRegistry` (core); `data/ui/heist_list.tres`
  (`UiHeistList`) holds per-heist UI data keyed by id (`solo_ai_teammates`, and
  `placeholder_base_payout/placeholder_mode` used only while `HeistRegistry.get_def(id)` is null),
  plus build-wide `unlocked_difficulties` and the default `solo_ai_teammates`.
  `entries_from(defs, list)` is the pure builder (tests).
* `Hud` binds to the node in group `G.LOCAL_HUD_MODEL` (ui_hud.md v1.1), polled while unbound and
  rediscovered if the model is freed; `bind(model)` still works. `MockHudModel` joins the same group.

* `SkillPoints` (`progression/skill_points.gd`): `points_for_level`, `cost_of`, `spent_total`,
  `spent_in_subtree`, `can_unlock`, `validate`, `is_legal`. Tree structure: `SkillTreeDef` at
  `data/skills/trees.tres`. Design + param schemas (authoritative, D-031): `content/docs/skills.md`.
* `LoadoutResolver.team_modifier_sources(loadout)` -> `{&"team_skill.<skill id>": grants,
  &"team_perk.<deck>": grants}` (e.g. `team_perk.foreman`) for `Modifiers.set_source(TEAM, ...)`;
  `resolve_modifiers` excludes every `team.*` grant (skills and perk cards). TEAM sources apply to the
  granter too (D-031 QB-35), so there is no personal copy; equal source names from two players count once.
* **LIST keys** (D-031: `weapon.kill_reload_buff`, `weapon.hit_stack_buff`, `weapon.kill_damage_buff`):
  `resolve_modifiers(loadout)[key]` is an `Array[Dictionary]`, one entry per granting skill or perk card
  (never merged): the granted Dictionary plus `"_source": StringName` = the skill id
  (`&"skill.gunnery.run_and_gun"`) or `&"<deck id>.card<n>"`, sorted by `_source` (ContentDB.sort_ids
  order). Inside one skill the aced Dictionary replaces the basic one. Example:
  `[{"trigger": "auto_kills", ..., "_source": &"skill.gunnery.run_and_gun"}, {"trigger": "headshot_kill",
  ..., "_source": &"skill.marksman.reload_rhythm"}]`. NOTE: `Modifiers.list()` currently expects ONE
  Dictionary per (slot, source); handing this Array to `set_source(slot, &"skills", ...)` needs
  `list()` to also accept an Array value (append each entry, keeping its own `_source`).
* `stealth.concealment_add.suppressed` counts once per suppressed primary/secondary
  (`LoadoutResolver.suppressed_weapon_count`).
* Perk decks: `data/perks/<deck>.tres` (`perk.<deck>`); param schemas: `content/docs/perk_decks.md`.
* `ContentDB` scans each kind folder recursively; resources without an `id` are skipped.

## Rules
Typed GDScript, gdlint clean, no `randi()/randf()`, never assume one player, every string through
`StringTable`, only grant keys from `ModifierKeys.KEYS`. Code that builds a mod delta starts from
`WeaponStats.make_delta()`; `.tres` deltas spell its zeros out (D-022 QB-5). Tests: `game/tests/b/test_*.gd`.
