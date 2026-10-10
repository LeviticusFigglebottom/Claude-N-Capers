# game/content (ENV B)

Content & progression. Owner: ENV B. Shared API brief for everything under this folder; keep it
current when an API changes.

## Layout
```
content/
  data/                     every balance number (.tres / .csv); no constants in scripts
    weapons/ mods/ melee/ armor/ deployables/ loot/ throwables/ difficulty/ masks/ contacts/ preplanning/
    tweak/                  concealment_curve.tres, display_stats.tres, payout.tres, perk_points.tres, xp_curve.tres
    strings/strings.csv     all player-facing text (columns: keys,en)
    voice/lines.tres        voice line table (VoiceLineTable); text lives in strings.csv
  defs/                     content-side Resource schemas + ContentDB lookup (ContactDef)
  docs/                     design authority: skills.md, perk_decks.md, masks.md, preplanning.md
  masks/                    MaskCatalog, MaskComposer, MaskLocker (+ part defs)
  preplanning/              PreplanBoard, PreplanPlan, PlanVote, PreplanBlueprint
  lobby/                    LobbyState (co-op lobby model), LobbySession (Net glue), LobbyAddress, LobbyTweak
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
  `loot(id) -> LootDef`, `throwable(id) -> ThrowableDef`, `difficulty(d: Enums.Difficulty) -> DifficultyDef`, `mask(id) -> MaskDef`,
  `by_id(kind, id)`, `all_of(kind)`, `all_weapons/all_mods/all_melees/all_armors/all_deployables/
  all_loots/all_throwables/all_difficulties()`, `tweak(name) -> Resource` (`&"concealment_curve"` ...). UI text comes
  from strings.csv `item.<id>.name` (display_name in .tres is a debug fallback). Unknown id →
  `Log.error` + null. Scans `res://content/data/<kind>/` with `ResourceLoader.list_directory`.
* `LoadoutResolver.resolve(loadout: Loadout, profile: PlayerProfile = null) -> Loadout` (returns a resolved
  copy): resolved weapon stats (base + mods, clamps; shell-fed reload totals derived per D-045),
  `concealment_total`, `detection_risk`, `modifiers`, and `mask_descriptor` (D-043 QA-25:
  `mask_descriptor_for(loadout, profile)` = the worn custom mask's `MaskCatalog.descriptor`, {} for presets /
  none; without a profile the loadout's own descriptor is kept while it names the same mask. It is filled on
  the profile loadout by `PlayerProfile.from_dict` and `MaskLocker.equip/save_custom/clear_custom`, and on
  the launch loadout by `LoadoutScreen.current_loadout()`; never saved). `LoadoutResolver.reload_times(stats)
  -> Vector2(tactical, empty)`.
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
  (`CURRENT_VERSION` 5 = the roadmap's "save v2"; **every field, type, default and since-version:
  `content/docs/save_format.md`**; v2 `banked_stealth_mult`, v3 `skill_sets`/`perk_cards`, v4
  `owned_mask_parts`/`custom_masks`, v5 `unlocks`/`achievements`/`pro_job_locks`);
  `load_profile/save_profile/migrate/profile_from_save/apply_heist_payout(p, payout, XpCurve.level_for_xp)`.
  Loading runs migrate -> `ProfileSchema.sanitize` (wrong types -> default + Log.warn) -> from_dict ->
  `ProfileValidator.validate` (unknown ids pruned, illegal skill sets reset, Log.warn each); golden
  migration fixtures in `tests/b/fixtures/save/`.
  `apply_heist_payout` resets the bank when `stealth_bonus_consumed`, then stores
  `stealth_bonus_banked` if > 1.0.
* `ProJobLocks` (`board/pro_job_locks.gd`): failed pro Board contracts persisted in
  `PlayerProfile.pro_job_locks` (`lock/prune/is_locked`); MenuFlow mirrors them into `consumed_contracts`.
* `MaskLocker.grant_unlock(profile, unlock_id)` records the unlock in `PlayerProfile.unlocks` and owns its
  presets; `apply_unlocks(profile)` re-owns them on load. `ContentDB.has(kind, id)` = lookup without an error.
* `ContentDB.inject(kind, key, res)`: tests/tooling only (test-only SkillDef/PerkDeckDef);
  `clear_cache()` drops it.
* `XpCurve.level_for_xp(xp)`, `xp_for_level(level)`. `VoiceLineTable` at `data/voice/lines.tres`.

## App shell and UI (D-024)
* `MenuFlow` (`ui/menus/menu_flow.tscn`) is the app shell; `core/boot.gd` routes to it. Flow (B2-01,
  B4-07, pd2_fidelity C2/C3/C9 order): main menu -> "Safehouse" -> **hub** (`HubMenu`) -> The Board
  (`contract_chosen`) or the planning table (heist select) -> **briefing** -> **pre-planning** -> loadout
  (-> Masks / Skills / Perk Deck and back) -> launch -> HUD -> payday. Back is symmetrical at every
  step; Back from the loadout refunds the confirmed plan's local cash share (re-confirm charges once).
  Every screen focuses its first control when shown (keyboard/gamepad). The menu path shares one
  `PlayerProfile` (`MenuFlow.profile`, slot `profile_slot`). It owns
  launch (`launch(heist_id, difficulty, loadout, seed, plan = {})`: `Net.start_solo` + resolved loadout + HUD/payday
  CanvasLayer + dynamic `HeistLauncher.launch`; stub screen when the launcher is absent), and
  `HeistRuntime.teardown()` + `Net.leave()` after results. Launch options come from the pure
  `MenuFlow.build_launch_options(ai, local_slot, resolved, plan) -> {ai_teammates, loadouts, preplan?}`:
  `options["preplan"]` = the confirmed PreplanResult v1 (`PreplanPlan.apply()`, contract
  `docs/contracts/preplanning.md`, D-038; only when a plan was confirmed). Direct launch:
  `godot --path game -- --heist=<id> [--seed=<n>] [--difficulty=<0..5>]` skips every menu and has no
  pre-planning plan (seed defaults to the time, difficulty to Routine; unknown heist or bad value logs an error and stays on the main menu).
  Parsing: `LaunchArgs.parse(args) -> {direct, heist_id, has_seed, seed, difficulty, errors}`,
  `LaunchArgs.validate_heist(id, known_ids)`. `MenuFlow.direct_launch(parsed) -> bool`.
* **Safehouse hub (B4-07, C9).** `HubMenu` (`ui/hub/hub_menu.tscn`) is the 2D layer of the safehouse:
  station cards + a profile summary (level, XP bar, spending, stash, free skill/perk points). Stations are
  data: `data/ui/hub_stations.tres` (`HubStationList` of `HubStation {id, title_key, desc_key, icon_kind,
  target}`). Ids: `board`, `planning`, `armory`, `masks`, `range`, `crew` (co-op lobby, B4-11).
  **`MenuFlow.open_station(id: StringName) -> bool`** opens one (false + `Log.error` for an unknown id);
  it is the API **ENV C's 3D safehouse interactables call** (find the MenuFlow node, call it with the
  station id), works from any menu state, refunds a confirmed-but-unlaunched plan, and Back on every
  station returns to the hub. Armory = `LoadoutScreen.hub_mode` (no Launch; Masks/Skills/Perk Deck as
  usual). Briefing Back returns to where the contract came from (Board or heist select). After a heist
  (or the stub/sample payday) the flow returns "home": the hub once the safehouse was entered, else the
  main menu (`MenuFlow.show_home()`).
* **Co-op lobby (B4-11).** Crew station `crew` (target `lobby`) -> `LobbyScreen` (`ui/lobby/lobby_screen.tscn`):
  Host (port; default `data/lobby/lobby_tweak.tres` = Net.DEFAULT_PORT), Join (address + port, `LobbyAddress`
  validation), loopback quick-join (`LobbyTweak.loopback_address`), Leave. 4 crew slots from `Net.crew` (host
  calls `Net.fill_with_ai()` so empty seats show as Crew AI): name, HOST/YOU tags, level, ready, loadout summary
  (primary/secondary/armor/deployable/perk deck names), mask name + colours (preset id or custom descriptor),
  and an "illegal loadout" flag. `LobbySession` (`lobby/lobby_session.gd`) is the only Net user (host / join /
  leave / crew registry / `lobby_send` / `lobby_message`; `net` is the Net autoload, tests pass a Net instance
  in its own SceneMultiplayer branch). Messages (`LobbyState`, JSON-safe, sender slot validated, host-only
  kinds from the host slot only): `lobby.ready {ready}`, `lobby.profile_summary {name, level, loadout}`
  (sent at join and on every lobby show; every peer runs `LobbyState.validate_summary`: known ids, resolver
  mod legality, `SkillPoints.validate` at the summary level, perk cards, mask), `lobby.contract {heist,
  difficulty, is_pro}` (host's Board / planning table pick; a new heist/difficulty clears ready + votes),
  `lobby.start {heist, difficulty, is_pro, seed}`, and the PlanVote kinds (`preplan.vote_cast/retract`, logged
  in `vote_log` and replayed into a pre-planning screen opened later, `MenuFlow.replay_lobby_votes`). Start =
  host only, every human slot has a legal summary and is ready (`LobbyState.start_block()`). While a session is
  live the lobby is "home" (`MenuFlow.show_hub()` shows it). Path: lobby -> host contract (Board / planning) ->
  briefing -> pre-planning -> loadout ("Ready Up": saves, re-sends the summary, sets ready, back to the lobby) ->
  Start -> `LobbySession.started` on every peer: the host runs `MenuFlow.launch_coop(info)` = live session (no
  `start_solo`), `build_coop_launch_options(loadouts, plan, pro)` with `loadouts` = `{slot: resolved Loadout}`
  of every legal human slot (`LobbyState.launch_loadouts()`); clients call `HeistLauncher.launch_client` when ENV
  A provides it, else a stub explains it. Tests: `test_lobby_state.gd`, `test_lobby_loopback.gd` (real ENet
  loopback, two branches), `test_lobby_flow.gd`.
* **Pro jobs.** A Board pin's `is_pro` is stored on `MenuFlow.is_pro` (heist select, broker and direct
  launch are never pro), goes into the launch options as `options["is_pro"] = true` (key omitted when
  false; `build_launch_options(ai, slot, resolved, plan, pro)`, `launch_options_for(loadout)`), and into
  `PaydayScreen.is_pro` -> `PayoutCalculator.compute(..., is_pro)` (HeistResult does not carry it).
* **GSR theme + accents (B4-07, D-035).** `ui/theme/caper_theme.tres`: warm-neutral darks, brass house
  accent, chamfered corners (`corner_detail = 1` on top-left/bottom-right), the style guide's cyan
  `#4FD1E8` reserved for focus/highlight, `Screen/colors/background|accent|highlight`, variations
  `PrimaryButton` (`UiBuild.primary(b)`: a screen's main forward action) and `StationButton`. Text
  colours keep >= 4.5:1 contrast on the surfaces they sit on (`test_ui_accent.gd`). Per-heist accents
  (style_guide §3) are data in `data/ui/heist_accents.tres` (`UiHeistAccents`); screens use
  `UiAccent.for_heist(id)` for strips/edges and `UiAccent.text_color(id)` for accent text (lifted to
  4.5:1), plus `UiAccent.strip(color)`, `accent_panel(panel, color)`, `contrast_ratio(a, b)`. Applied on
  the briefing, pre-planning, the Board's contract card and the HUD objectives panel (`Hud.heist_id`,
  set by MenuFlow).
* `HeistCatalog.entries()/ids()`: heists from `HeistRegistry` (core) that have BOTH a HeistDef and
  a map scene (`HeistRegistry.map_scene_path` exists; QB-55, D-049). No placeholder heists: menus, the
  Board, the broker and direct launch only offer playable heists (Shadow Ledger appears with its G1).
  `data/ui/heist_list.tres` (`UiHeistList`) holds per-heist UI data keyed by id (`solo_ai_teammates`),
  plus build-wide `unlocked_difficulties` and the default `solo_ai_teammates`.
  `entries_from(defs, map_exists)` is the pure builder (tests).
* `Hud` binds its widgets DIRECTLY to the node in group `G.LOCAL_HUD_MODEL` (ENV A's LocalHudModel,
  ui_hud.md v1.2; no adapter; v1.2 `custody` drives `CustodyPanel`: negotiation / auto-release timers while in
  custody, a trade hint for the highlighted hostage while free; v1.3 (D-049) `captain_changed` / `captain_present` /
  `captain_resistance` drive `CaptainPanel`: Brandt's name + Aegis resistance bar, and the status panel then drops
  its `captain` warning line), polled while unbound and rediscovered if the model is freed; MenuFlow
  relies on that discovery in heists. `bind(model)` still works. `MockHudModel` (demo/tests) joins the
  same group. `MarkedTargets` draws a diamond per `marked_targets` entry; `InteractionPanel` fills a
  missing `{key}` prompt arg from the `interact` InputMap binding.
* Firing range (`range/firing_range.tscn`, B1-05): the shooter is ENV A's crew member from
  `CrewController.spawn_for_range` (`RangeCrewBridge`, the range's only door into A's runtime), with
  `set_loadout(resolved)` on every swap; panel mode pauses the crew's PlayerInput (`RangeModeInput`).
  Last shot / damage numbers follow `EventBus.damage_applied` from the range's targets with
  attacker = the crew's net id. Ammo is read through a `LocalHudModel` that `track(crew)`s the range's crew
  (`FiringRange.hud_model`, ui_hud.md v1.2), falling back to the crew's weapons. `RangeSpectator` + `RangeDebugGun` are a FALLBACK only (hook missing,
  or `use_fallback_shooter` for tests).

* `BriefingScreen` (`ui/briefing/briefing_screen.tscn`, C2): `setup(heist_id, difficulty)`; signals
  `continue_requested(heist_id, difficulty)`, `back_requested()`. Data: `BriefingModel.build()`;
  contacts are `ContactDef` (`defs/contact_def.gd`, `data/contacts/`, `ContactDef.find(id)/all()`).
* `PreplanningScreen` (`ui/preplanning/preplanning_screen.tscn`, C3): `setup(heist_id, difficulty, profile)`,
  `profile_slot`, `save_on_confirm`; signals `confirmed(plan: Dictionary)` (= the PreplanResult v1 from
  `PreplanPlan.apply()`, cash already charged), `back_requested()`. Plan votes go through
  `Net.lobby_send` / `Net.lobby_message` (`PlanVote.send_cast`, `PreplanPlan.receive_vote`).
* **Pre-planning for ENV A** (contract `docs/contracts/preplanning.md` is authoritative; our notes:
  `content/docs/preplanning.md`): apply `options["preplan"]` as given (keys `PreplanPlan.RESULT_KEYS`).
  Dev path without UI: `PreplanPlan.resolve_ids(heist_id, ids: Array, difficulty = ROUTINE, def = null)
  -> PreplanResult` (ids may be `"asset.<id>@<point id>"`; nothing charged). Points are read from the
  map's `<Map>/Preplan` Marker3Ds (instanced off-tree), else the placeholder blueprint.
* `MaskScreen` (`ui/masks/mask_screen.tscn`, P8): `setup(profile)`, `profile_slot`; signals
  `mask_changed(mask_id)` (after Equip), `back_requested()`; saves the profile itself. Opened from the
  loadout screen's "Masks" button (`LoadoutScreen.masks_requested`); the loadout's mask picker lists
  `MaskLocker.available_ids(profile)` (owned presets + filled `mask.custom.<n>` slots) and
  `refresh_masks()` re-reads it. Design: `content/docs/masks.md`.
* **Masks for ENV A**: `MaskCatalog.resolve(loadout.mask, profile) -> MaskDef` on the owning peer, or
  `MaskCatalog.descriptor(mask_id, profile)` (ids only, JSON-safe) sent to other peers +
  `MaskCatalog.from_descriptor(d)`; then `MaskComposer.instantiate(def) -> Node3D` for the `Head` attachment.
* `SkillPoints` (`progression/skill_points.gd`): `points_for_level`, `cost_of`, `spent_total`,
  `spent_in_subtree`, `can_unlock`, `validate`, `is_legal`. Tree structure: `SkillTreeDef` at
  `data/skills/trees.tres`. Design + param schemas (authoritative, D-031): `content/docs/skills.md`.
* `LoadoutResolver.team_modifier_sources(loadout)` -> `{&"team_skill.<skill id>": grants,
  &"team_perk.<deck>": grants}` (e.g. `team_perk.foreman`) for `Modifiers.set_source(TEAM, ...)`;
  `resolve_modifiers` excludes every `team.*` grant (skills and perk cards). TEAM sources apply to the
  granter too (D-031 QB-35), so there is no personal copy; equal source names from two players count once.
* **LIST keys** (D-031: `weapon.kill_reload_buff`, `weapon.hit_stack_buff`, `weapon.kill_damage_buff`;
  D-034: `defense.post_revive_buff`):
  `resolve_modifiers(loadout)[key]` is an `Array[Dictionary]`, one entry per granting skill or perk card
  (never merged): the granted Dictionary plus `"_source": StringName` = the skill id
  (`&"skill.gunnery.run_and_gun"`) or `&"<deck id>.card<n>"`, sorted by `_source` (ContentDB.sort_ids
  order). Inside one skill the aced Dictionary replaces the basic one. Example:
  `[{"trigger": "auto_kills", ..., "_source": &"skill.gunnery.run_and_gun"}, {"trigger": "headshot_kill",
  ..., "_source": &"skill.marksman.reload_rhythm"}]`. `Modifiers.list()` accepts this Array as one
  source's value; each entry keeps its own `_source` (D-034 QB-38).
* `stealth.concealment_add.suppressed` counts once per suppressed primary/secondary
  (`LoadoutResolver.suppressed_weapon_count`).
* Perk decks: `data/perks/<deck>.tres` (`perk.<deck>`); param schemas: `content/docs/perk_decks.md`.
* `ContentDB` scans each kind folder recursively; resources without an `id` are skipped.

## Rules
Typed GDScript, gdlint clean, no `randi()/randf()`, never assume one player, every string through
`StringTable`, only grant keys from `ModifierKeys.KEYS`.
**Objective ids (D-039)** come from the heist design doc's Objectives section `[tag]`s
(`docs/design/heists/<id>.md`); strings are `objective.<heist>.<tag>`. Read them there, never guess
(`test_strings.test_glasshouse_objectives_follow_the_design_doc`). **Blocked reasons** are `ui.blocked.*`
(D-038 QA-14; no `ui.prompt.blocked.*`). Voice lines requested by id (`vo.<speaker>.<event>`, e.g.
`vo.guard.cuff_warning`) get a `data/voice/lines.tres` entry and `voice.<id>` text;
`test_strings.test_keys_requested_by_systems_exist` scans ENV A/C code for prompt/blocked/voice keys. Code that builds a mod delta starts from
`WeaponStats.make_delta()`; `.tres` deltas spell its zeros out (D-022 QB-5). Tests: `game/tests/b/test_*.gd`.
