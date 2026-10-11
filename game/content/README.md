# game/content (ENV B)

Content & progression. Owner: ENV B. Shared API brief for everything under this folder; keep it
current when an API changes.

## Layout
```
content/
  audio/                    MusicCatalog (+ MusicCatalogTweak / MusicStubTrack): view over C's music table (B5-03)
  data/                     every balance number (.tres / .csv); no constants in scripts
    weapons/ mods/ melee/ armor/ deployables/ loot/ throwables/ difficulty/ masks/ contacts/ preplanning/ heisters/
    tweak/                  concealment_curve.tres, display_stats.tres, payout.tres, perk_points.tres, xp_curve.tres, notoriety.tres
    notoriety/ranks.tres    NotorietyTable: rewards per Notoriety rank (B5-02)
    strings/strings.csv     all player-facing text (columns: keys,en)
    voice/lines.tres        voice line table (VoiceLineTable); text lives in strings.csv
  defs/                     content-side Resource schemas + ContentDB lookup (ContactDef)
  docs/                     design authority: skills.md, perk_decks.md, masks.md, preplanning.md, scoreboard.md
  masks/                    MaskCatalog, MaskComposer, MaskLocker (+ part defs)
  preplanning/              PreplanBoard, PreplanPlan, PlanVote, PreplanBlueprint
  lobby/                    LobbyState (co-op lobby model), LobbySession (Net glue), LobbyAddress, LobbyTweak
  progression/              LoadoutResolver, StatCalculator, PayoutCalculator, XpCurve
  save/                     SaveService, PlayerProfile
  settings/                 GameSettings (options + settings.cfg), InputBindings, InputEventCodec, SettingsApplier
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
* `DeployableGate.required_flag(id)`, `.allowed(id, modifiers)`, `.allowed_for(loadout, id)`,
  `.unlock_card(id)`: deployables that need a modifier FLAG (armor bag: `deploy.armor_bag`); the loadout
  picker locks them until the loadout's skills / perk cards grant it.
* `PayoutCalculator.compute(result, difficulty_def = null, tweak = null, is_pro = false,
  crew_slot = -1, banked_stealth_mult = 1.0) -> Dictionary` from a HeistResult
  (contracts/events.md). Output shape documented in its header. Stealth bonus (D-022 QB-13, S11.1):
  pass `PlayerProfile.banked_stealth_mult`; the "stealth" XP line spends that bank on a success.
  Output adds `stealth_bonus_consumed: bool` and `stealth_bonus_banked: float` (the tweak's
  `stealth_xp_bonus_mult` after a successful stealth heist, else 1.0). UI string:
  `ui.results.stealth_bonus_banked` ("... +{pct}%").
* `SaveService` / `PlayerProfile`: versioned JSON at `user://profiles/profile_<n>.json`
  (`CURRENT_VERSION` 6; the roadmap calls the format "save v2". **Every field, type, default and since-version:
  `content/docs/save_format.md`**; v2 `banked_stealth_mult`, v3 `skill_sets`/`perk_cards`, v4
  `owned_mask_parts`/`custom_masks`, v5 `unlocks`/`achievements`/`pro_job_locks`, v6 `notoriety`/
  `notoriety_xp`/`notoriety_choices`/`held_skill_sets`/`music_choice`);
  `load_profile/save_profile/migrate/profile_from_save/apply_heist_payout(p, payout, XpCurve.level_for_xp)`.
  Loading runs migrate -> `ProfileSchema.sanitize` (wrong types -> default + Log.warn) -> from_dict ->
  `ProfileValidator.validate` (unknown ids pruned, illegal skill sets reset, Log.warn each); golden
  migration fixtures in `tests/b/fixtures/save/`.
  `apply_heist_payout` resets the bank when `stealth_bonus_consumed`, then stores
  `stealth_bonus_banked` if > 1.0. A level gain re-buys skills a Notoriety rank-up held
  (`NotorietySkills.restore`).
* **Notoriety (B5-02, P10; design + numbers `content/docs/notoriety.md`).** `Notoriety` (`progression/notoriety.gd`,
  static):
  * Data: `tweak()` -> `NotorietyTweak` (`data/tweak/notoriety.tres`: `max_rank` 25, `required_level` 100,
    `costs`, `xp_bonus_per_rank`, `xp_bonus_cap`); `table()` / `def_for(rank)` -> `NotorietyDef {rank, rewards,
    unlocks, choices}` (`data/notoriety/ranks.tres`).
  * `cost_for(rank)`, `xp_bonus(rank)`, `roman(n)`, `unlock_id(rank)` (`unlock.notoriety.rank_<n>`).
  * Rank-up: `requirements(p)` (checklist rows `{code: REQ_LEVEL|REQ_CASH|REQ_CAP, met, have, need}`),
    `can_rank_up(p)`, `rank_up(p) -> {ok, reason, rank, cost, granted, choices}`. The rank-up takes the cost
    from spending cash and resets level and XP to 0 (XP moves to `notoriety_xp`, so perk points stay). It holds
    every skill set (`NotorietySkills`) and grants the rank unlock, rewards and plain unlock ids such as
    `unlock.music.*` (D-062).
  * Rewards: `rewards_for(rank)`, `choice_options(p, rank)`, `choose(p, rank, id)`, `pending_choices(p)`,
    `exclusive_ids()` (left out of payday card pools), `apply_rewards(p)` (load-time repair),
    `reward_name(id)`.
  * `NotorietySkills`: `hold(p)`, `restore(p)` (after level gains; always legal), `release(p, set_index)`
    (skill screen refund/respec), `held_points(p, i)`.
  * Payout: `PayoutCalculator.compute(..., notoriety_bonus)` adds the `ui.results.xp.notoriety` XP line (now
    7 lines). `PaydayScreen.compute_payout` passes `Notoriety.xp_bonus(profile.notoriety)`.
  * Co-op: `LobbyState.summary_from` carries `"notoriety": int`. It is validated as 0..25 (missing = 0) and
    shown in `slot_view`.
  * UI: `NotorietyScreen` (`ui/notoriety/`) from the hub profile panel (`HubMenu.notoriety_requested` ->
    `MenuFlow._open_notoriety()`). `NotorietyScreen.level_text(level, rank)` / `badge_text(rank)` give the
    badge text used by the hub and lobby.
* **Music selection (B5-03, D-062; brief `content/docs/music.md`).** `MusicCatalog` (`audio/music_catalog.gd`,
  static) is a read-only view over ENV C's `MusicTrackTable` (`MusicCatalogTweak.table_path` in `data/tweak/music.tres`,
  read as `MusicTrackTable.load_default().all()`, class looked up by name and entries duck-typed). While that table is
  missing it falls back to the stub list in the same `.tres`.
  * `tracks() -> Array[Dictionary]` gives `{id, unlock, default_for_heists}` in id order.
  * `is_unlocked(profile, id)`, `available(profile)`, `display_key(id)` (`music.<id>.name`), `unlock_rank(id)`,
    `default_for(heist)`.
  * `resolve_choice(profile)` gives `profile.music_choice` while it is known and unlocked, else `&""`.
  * `MusicPicker` (`ui/common/`) writes `music_choice` and saves. It sits in the pre-planning bottom bar (solo / host)
    and the lobby (host editable; clients see `LobbyState.host_music()`, the `music` field of the host's summary).
  * Launch options always carry `options["music_track"]` (`build_launch_options(..., music)` /
    `build_coop_launch_options(..., music)`; the host's pick in co-op; `&""` = `HeistDef.music_track`).
  * Hub station `jukebox` opens `JukeboxScreen` (`ui/jukebox/`). It drives C's `MusicDirector.preview(id)` /
    `stop_preview()` via `call()` when that API exists, else Play is disabled with a notice. Leaving stops the preview.
* `ProJobLocks` (`board/pro_job_locks.gd`): failed pro Board contracts persisted in
  `PlayerProfile.pro_job_locks` (`lock/prune/is_locked`); MenuFlow mirrors them into `consumed_contracts`.
* `MaskLocker.grant_unlock(profile, unlock_id)` records the unlock in `PlayerProfile.unlocks` and owns its
  presets; `apply_unlocks(profile)` re-owns them on load. `ContentDB.has(kind, id)` = lookup without an error.
* **Achievements (B4-20 stub).** `AchievementDef` (`defs/achievement_def.gd`; data `data/achievements/*.tres`,
  ContentDB kind `achievements`): `id`, `name_key`/`desc_key`, `condition` {`event`: heist_completed |
  heist_failed | stash_earned | level_reached, filters `heist`, `difficulty_min`, `stealth`, `loud`, `pro`,
  `count`}, `unlock` (granted via `MaskLocker.grant_unlock`), `order`. `Achievements` (`progression/achievements.gd`):
  `all()`, `on_payday(profile, result, payout, is_pro) -> newly unlocked ids` (PaydayScreen._apply, before the
  save), `record(profile, event, ctx)`, `progress/is_unlocked`. State: `PlayerProfile.achievements` (save v5).
  Screen: `AchievementsScreen` (`ui/achievements/`), from the hub profile panel (`HubMenu.achievements_requested`
  -> `MenuFlow._open_achievements()`); payday lists unlocks (`ui.results.achievement_unlocked`).
* **Options (B5-01; brief: `content/docs/options.md`).** `GameSettings.current()` (`settings/game_settings.gd`):
  audio (0..1 per bus), video (window mode, vsync, max FPS, render scale, MSAA, FXAA, brightness, **FOV**),
  controls (**mouse sensitivity x/y, invert Y, pad sensitivity, deadzone, hold/toggle aim/crouch/sprint**),
  accessibility (HUD palette, HUD scale, subtitle size) and input bindings; `get_value/set_value`, signal
  `changed(section, key)`; ENV A reads `fov()`, `mouse_sensitivity()`, `invert_y()`, `pad_sensitivity()`,
  `pad_deadzone()`, `is_toggle(action)`. Defaults/ranges: `data/settings/settings_defaults.tres`
  (`SettingsDefaults`). File `user://settings.cfg` (ConfigFile v1; `GameSettings.root_dir` for tests).
  `apply()` = `SettingsApplier` (AudioServer buses on top of the layout's mix level, window/viewport,
  InputMap) and runs in `MenuFlow._ready`. Rebinding: `InputBindings` (KBM / PAD columns, conflicts that
  ignore project-designed shared keys, swap / keep both, reset per action / all) over `InputEventCodec`
  plain dicts. HUD palettes: `data/ui/hud_palettes.tres` (`HudPaletteSet` / `HudPalette`, ids default,
  deuteranopia, protanopia, tritanopia, high_contrast); `Hud` follows the palette and `hud_scale` live;
  `ColorVision` (Machado 2009 + CIE76) for checks. Screen: `OptionsScreen` (`ui/menus/options_screen.tscn`)
  via `MenuFlow.options_menu` (`MenuOptions`): main menu Options, hub `HubMenu.options_requested`, and the
  `pause` action in a heist (overlay over the HUD; local crew input paused). Strings `ui.options.*`,
  action names `ui.action.<action>`.
* **Scoreboard + awards (B6-02; brief: `content/docs/scoreboard.md`).** `CrewStats` (`progression/crew_stats.gd`):
  per-crew rows (HeistResult.crew keys + `name`, `is_local`, `shots`, `hits`, `headshots`), `has_stat(row, stat)`
  per row (missing = "—" / no award), derived `accuracy`. `HeistAwards.compute(crew_rows, table = null)` (pure;
  data `data/ui/heist_awards.tres`, `HeistAwardTable`): max/min awards with tie-break humans before AI then lowest
  slot, shared `zero` awards, skipped when the stat is missing; `PaydayScreen.awards` / "Crew Honours" section.
  `Hud.scoreboard` (`ScoreboardOverlay`) reads the model's `crew_stats` + `crew_stats_changed` (QB to ENV A;
  `MockHudModel` has them) and shows while `scoreboard` is held (`controls/scoreboard_mode` toggle).
* **Weapon finishes (B7-04).** `FinishDef` (`defs/finish_def.gd`; data `data/finishes/<name>.tres`, ContentDB
  kind `finishes`, id `finish.<name>`, unlock `unlock.finish.<name>`, `default_owned`, `covers_mods`, `order`,
  `layers: Array[FinishLayer]`). `FinishLayer` (`defs/finish_layer.gd`): `slots` (the weapon build scripts'
  `Mats.*` names: polymer, stipple, steel, bare, matte, alu, wood, rubber, tan, olive), `albedo`, `metallic`,
  `roughness`, optional `base_material` (a library Material reference; duplicated), `pattern` (`mottle`, `camo`,
  `patina`, `engrave`, `brushed`; generated NoiseTexture2D), `pattern_color/scale/seed`, `clearcoat`.
  `FinishApplier` (`weapons/`): matches surfaces by their stock material `M_<library_id>` (`SLOT_MATERIALS`) and
  sets `surface_override_material`; never changes meshes or library materials; removes only its own overrides.
  `FinishMaterials`: cached runtime materials (meta `finish_id`). `WeaponVisual.apply_finish(id)` (main gun,
  offhand, mods when covered; kept across `setup()`; &"" = stock) and `apply_loadout_finish(loadout)`.
  `WeaponFinishes` (`progression/`): `all/def/is_known/is_owned/owned`, `equipped/equip(profile, weapon, finish)`
  (locked -> false), `store/persists` (`PlayerProfile.weapon_finishes`, save v7 by B7-01; read with `get()`,
  metadata fallback while absent), `for_loadout`, `stamp(loadout, profile)` / `from_loadout(loadout, weapon)`
  (`Loadout.weapon_finishes`, weapon id -> finish id, lead-approved for contracts round 28; MenuFlow stamps the
  solo launch, `launch_options_for` and the range loadout; co-op goes through the lobby summary's
  `loadout.weapon_finishes` -> `LobbyState.loadout_from_dict`), `sanitize_map`, `source_of(id)` (default /
  achievement / notoriety rank). Workshop: `WorkshopFinishPanel` under the parts (`WorkshopScreen.select_finish`,
  `equip_finish`). Strings `item.finish.<name>.name/.desc`, `ui.workshop.finish.*`.
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
  target}`). Ids: `board`, `planning`, `armory`, `masks`, `range`, `crew` (co-op lobby, B4-11), `jukebox` (B5-03),
  `notoriety` (B6-06 / QC-46: the Old Press -> `NotorietyScreen`; the profile panel button stays). Prompts
  `ui.prompt.station.<id>` (QC-47).
  **`MenuFlow.open_station(id: StringName) -> bool`** opens one (false + `Log.error` for an unknown id);
  it is the API **ENV C's 3D safehouse interactables call** (find the MenuFlow node, call it with the
  station id), works from any menu state, refunds a confirmed-but-unlaunched plan, and Back on every
  station returns to the hub. Armory = `LoadoutScreen.hub_mode` (no Launch; Masks/Skills/Perk Deck as
  usual). Briefing Back returns to where the contract came from (Board or heist select). After a heist
  (or the stub/sample payday) the flow returns "home": the hub once the safehouse was entered, else the
  main menu (`MenuFlow.show_home()`).
* **3D safehouse hub (B6-06, QC-45..49; contract `docs/contracts/hub_map.md` v1.0, D-072).** `MenuFlow.safehouse`
  (`SafehouseHost`, `ui/hub/`) is `show_hub()`'s 3D branch. Data `data/ui/safehouse_hub.tres` (`SafehouseHubTweak`):
  `scene_path` (C's scene; no `res://world/` path in code), `map_class` (`SafehouseMap`, looked up by name),
  stations in group `G.HUB_STATION` and/or under `stations_node` (`Stations`), `station_signals` (`station_requested(id)`,
  A's `station_used(id, crew)`), `use_point_name` (`UsePoint`), `station_cam_name` (`StationCam`: a Marker3D,
  -Z = view direction, meta `station_cam_fov_meta` `fov` in degrees, default `station_cam_fov` 60; the walker's
  OWN camera blends to its transform and FOV over `station_cam_blend_s` 0.35 and is restored on return), A's
  `crew_class.spawn_method` (`CrewController.spawn_for_hub(parent, xform, loadout)`, QC-43; else a stand-in in
  `walker_group` `hub_walker`), markers `ReturnHeist` / `ReturnRange` (root `spawn_transform(id)`, else
  `SafehouseHost.marker_transform`: a Marker3D of that name, else `spawn_marker` `Spawn`), the root's `jukebox`
  (C's MusicDirector: preview target, and `set_ducked(true)` while any station screen but the jukebox's is open,
  `false` on return; called only when the method exists) and `set_jukebox_track(id)`. Station used -> walker
  `set_input_paused(true)`, mouse released, view dimmed, optional StationCam blend, `open_station(id)`; every Back
  -> `show_hub()` -> walker back at that station's UsePoint. Station prompts `ui.prompt.station.<id>` use the
  in-heist prompt format ("Press {key} to ...").
  `SafehouseHud` (centre dot + `InteractionPanel` on the walker's LocalHudModel); Esc / `pause` ->
  `SafehousePauseMenu` (Resume, quick stations, Options, Achievements, Main Menu). Range / heist launch free
  the scene and re-enter at ReturnRange / ReturnHeist. The 2D `HubMenu` stays the fallback (scene, class or
  walker missing; Options `controls/safehouse_hub` = `menu`, `GameSettings.hub_walk()`; co-op lobby). Jukebox
  (QC-48): `JukeboxScreen.preview_target` = the cabinet in 3D, else its own bare MusicDirector. Mock scene:
  `tests/b/mock_safehouse/`, tests `test_hub_3d.gd`.
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
  its `captain` warning line; v1.4 (B4-19, ahead of ENV A) `stamina_changed` / `stamina` 0..1 / `exhausted` drive
  `StaminaBar` above the vitals: shown while stamina < 1 or exhausted, `HudTweak.stamina_exhausted_color` tint
  while exhausted, hidden when the model lacks the fields), polled while unbound and rediscovered if the model is freed; MenuFlow
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
  Dummies (`data/range/range_dummies.tres`) mirror ENV A's EnemyDefs through `enemy_path`: health,
  headshot mult and armour (`RangeDummyDef.armor()` = `NpcHitRules.armor_of(def)`, D-052 canonical keys;
  a mirror reader covers trees without A3-08). `RangeDamageModel` applies them with NpcHitRules /
  BulwarkShield / WreckerArmor semantics; pierce flags are attacker-side only (D-053).

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
* **Chat (B6-03).** `LobbyState.MSG_CHAT` `{"text"}` over `Net.lobby_send`, validated by `ChatLog`
  (`lobby/chat_log.gd`, `LobbyState.chat`): attribution by the sender's crew slot, `clean_text` (control / bidi /
  zero-width characters stripped, spaces collapsed, cut to `LobbyTweak.chat_max_length`), rate limit per slot
  (`chat_rate_count` per `chat_rate_window_s`, clock `LobbyState.now_s`), history cap. `LobbySession.send_chat(text)
  -> OK | R_*`, `chat_history()`, signal `chat_received(entry)`. `Net.lobby_send` keeps working during a heist on the
  same session, so the in-heist chat uses it too (no separate transport). UI: `ChatPanel` (`ui/chat/`), Mode.LOBBY
  (lobby screen) / Mode.OVERLAY (MenuFlow.heist_chat over the HUD in co-op; fades after `chat_fade_after_s`; typing
  pauses the local crew member's input). Lines are plain Labels (no BBCode). Open key: InputMap action `chat`
  (`LobbyTweak.chat_action`; Enter / keypad Enter, D-072; no fallback, T is `order_menu`). `CrewInput` (`ui/common/`) = the shared
  local-input pause with per-overlay holders (options, chat, drop-in). Strings `ui.chat.*`.
* **Drop-in + kick (B6-04, on mocks until ENV A's drop-in lands).** `DropInService` (`lobby/drop_in_service.gd`):
  the interface B's UI binds to by duck typing (group `G.DROP_IN_SERVICE` = `DropInService.GROUP`, `DropInService.find(tree)`): signals
  `join_requested(peer_id, summary)`, `join_progress(peer_id, frac)`, `joined(slot)`, `join_failed(peer_id, reason)`,
  `kicked(slot)`; methods `answer_join(peer_id, accept, reason)`, `kick(slot) -> bool`, `request_join(summary)`,
  `cancel_join()`; reasons `denied|timeout|full|cancelled|host_lost|kicked|off`. `MockDropInService` (`lobby/mock/`).
  UI (`ui/dropin/`): `JoinRequestDialog` (host: name, level + Notoriety badge, Accept / Deny, auto-deny after
  `LobbyTweak.dropin_request_timeout_s`, queue; MenuFlow.heist_join_dialog over the HUD for a co-op host, pauses
  local input while shown), `KickConfirmDialog` (calls `target.kick(slot)`), `DropInJoinScreen` (joining player:
  `LoadoutScreen.compact_mode` pick -> "Joining" progress with Cancel; opened by DropInFlow, below). **Kick (D-072):** `LobbySession.kick(slot)` -> `Net.kick(peer_id)` (host only). `Net.peer_kicked` puts the
  player on the session kick list (`KickList`, `lobby/kick_list.gd`, `LobbyState.kicked`: peer id + normalized profile
  name; cleared with the session) and sends `LobbyState.MSG_KICK` only as a crew notice (every peer remembers the kick;
  `LobbySession.kick_notice` -> a dim `ui.chat.kick_notice` line in `ChatPanel`). The kicked client gets
  `connection_failed(FAIL_KICKED)` from `Net.last_disconnect_reason == &"kicked"` and the lobby shows
  `ui.lobby.error.kicked`. The host re-kicks a kicked peer id / name that comes back (crew change or profile summary;
  Net also re-kicks exact display names), ignores a kicked peer's messages, and `LobbySession.join_decision(peer,
  summary)` auto-denies its drop-in requests with `DropInService.REASON_KICKED`.
  **Drop-in policy (B6-04, PD2):** `LobbyState.dropin_policy` `ask` (default, `LobbyTweak.dropin_default_policy`) /
  `auto` / `off`, set by the host (`LobbySession.set_drop_in_policy`, lobby screen option "Drop-in"; clients see it
  read-only) and replicated as host-only `LobbyState.MSG_SETTINGS {dropin}` (re-sent on crew changes). It lives in the
  lobby session, not GameSettings: it is a property of the hosted lobby that every member sees and the host's
  drop-in path reads, not a per-machine preference. `JoinRequestDialog.gate` (mock / lobby path only; the heist dialog on A's service has none, below) decides first:
  kicked -> deny `kicked`, `off` -> deny `off`, `auto` -> accept, all without a dialog; `ask` shows it (timeout ->
  deny `timeout`). `DropInService.answer_join(peer_id, accept, reason = REASON_DENIED)`; reasons add `kicked`, `off`.
  Strings `ui.dropin.*`, `ui.kick.*`, `ui.lobby.dropin.*`.
* **Drop-in wired to ENV A's HeistDropIn (B6-04).** `DropInFlow` (`ui/dropin/drop_in_flow.gd`, `MenuFlow.drop_in`).
  **Who decides: ENV A** (lead ruling). `MenuFlow.launch_coop` calls `DropInFlow.apply_host_policy(tree,
  lobby.state.dropin_policy)` = `HeistDropIn.ensure(tree).policy = ...` before the launch; from then on A's service
  checks every request (no running heist -> denied, no slot -> full, kicked -> kicked, `validate_summary`, then the
  policy: off denies, auto accepts, ask emits `join_requested`). The heist's `JoinRequestDialog` has **no gate** and
  its `policy` stays ask, so it only shows A's asks and answers each once (auto / off never reach it). The B gate
  (`LobbySession.join_decision`) stays for services that leave the decision to the UI (the mock, tests). The dialog
  calls `answer_join(peer, accept, reason)` when the service takes 3 arguments, else `(peer, accept)`; a
  `join_failed` for a queued peer (cancelled, left) drops that request. The lobby's policy is copied once, at
  launch (it cannot change in the heist: the lobby screen is hidden).
  **Joining client:** the lobby Join panel's "Drop In to a Running Heist" (`LobbyScreen.dropin_button`, `drop_in()`:
  address / port fields, or the code when the address is empty) -> `dropin_requested(address, port)` -> MenuFlow
  opens `DropInJoinScreen` with `DropInFlow` as its service (a duck-typed proxy, not in `G.DROP_IN_SERVICE`). Drop In
  on the compact loadout -> `DropInFlow.request_join(summary)`: `lobby.join(address, port)` (Net.join; the lobby
  advertises the picked loadout), then on the lobby Net's `connected_to_host`: `HeistDropIn.ensure(tree)`
  (`service_provider` in tests) `.request_join(summary)`. A's `join_progress` / `joined(slot)` / `join_failed` are
  passed on. On `joined` MenuFlow hides the menus and spawns the in-heist UI (HUD, payday, chat) like a co-op client
  launch (`_begin_client_heist`, heist / difficulty from `HeistRuntime.current()`, else the lobby contract; `is_pro`
  from the contract) and never calls `launch_client` again. On `join_failed` (or a lobby failure before the request:
  unreachable -> `unreachable`, no slot in time -> `timeout`, host lost, kicked) the screen shows
  `ui.dropin.failed.<reason>`, the session is left (`Net.leave`, A's client does not), and Back returns to the
  lobby's connect view with the reason in its error line (none for `cancelled`). Cancel while connecting just
  leaves; once asked it is A's `cancel_join`. Reason `unreachable` is B-only (`DropInService.REASON_UNREACHABLE`).
  Tests `test_dropin_wiring.gd`.
* **Heister choice (D-073, B6-07).** `Loadout.heister` (&"rook" | &"sable" | &"dutch" | &"wren"; &"" = no preference).
  Data `data/heisters/roster.tres` (`HeisterRoster`: roster order, accents, `portrait_dir`); `Heisters`
  (`progression/heisters.gd`, static): `ids()`, `is_known`, `name_key` (`crew.<id>`, &"" = `ui.heister.any`),
  `display_name`, `accent`, `portrait` (null until ENV D ships `<portrait_dir>/<id>.png`), `next_free`,
  `assign(order, picks, fill)`, `solo(pick, local_slot, ai)`, `solo_ai_slots`, `ai_loadouts(slot -> id)` (ENV A's
  default AI loadout, `CrewWeapons.build_loadout(null)`, + heister). **Rule** (PD2 unique heisters): humans are
  served first-come (the slot whose current pick reached this peer first keeps it; re-sending the same pick keeps
  the place, a changed pick takes a new place); a later conflicting pick is not refused and never blocks Start: it
  falls back to the next free heister after its pick in roster order (wrapping), after every uncontested pick; no
  preference takes the first free one; AI and empty seats take the rest in roster order, lowest slot first.
  Save: `loadout.heister` (save_format.md; additive in v6). Picker: `LoadoutScreen.heister_option` (accent swatch
  icons, accent strip + portrait), `select_heister`, `set_taken_heisters` (co-op: MenuFlow passes
  `LobbyState.heisters_taken_by_others(local_slot)`; taken entries are disabled). Lobby: the summary's
  `loadout.heister` (sanitized as a String, unknown id illegal), `LobbyState.heister_claims`,
  `heister_assignment()`, `heister_of(slot)`, `ai_heisters()`, slot_view `heister` / `heister_pick`; the slot card
  shows "Heister: X" (or "X (Y was taken)"). Launch: `launch_loadouts()` sets each human's assigned heister;
  `MenuFlow.build_launch_options` sets the solo player's and adds AI loadouts for the seats Net.start_solo fills;
  `build_coop_launch_options(..., ai_loadouts)` merges the AI seats' loadouts (ai_teammates still counts the seats
  humans leave). Every launched slot has a distinct heister. Tests `test_heisters.gd`.
* **Throwables (D-073, B6-08).** `data/throwables/` frag / concussion / incendiary / throwing_knife (count 3,
  `anim_set` throwable; values in data/README.md). `ThrowableGate` (`progression/throwable_gate.gd`):
  `perk_item_ids()` (every perk card's `perk.throwable` item_id), `is_pickable(id)`, `pickable()`.
  `LoadoutScreen.throwable_option` (after the deployable; "None" first) lists `pickable()`, so the flask and the
  injector are never offered; `option_ids(o)` lists a picker's ids. Tests `test_throwables.gd`.
* **Lobby codes (B6-05, game_overview §9).** `LobbyCode` (`lobby/lobby_code.gd`, static, pure): `encode(ipv4, port,
  default_port = tweak) -> String` (Crockford base32 + Luhn mod 32 check symbol; 8 symbols for the default port,
  11 otherwise; "" for IPv6 / host names / bad ports), `decode(code) -> {address, port} | {error: E_*}` (case,
  dashes and spaces ignored, O/I/L read as 0/1, pad bits checked), `display(code)` ("ABCD-EFGH"), `normalize`,
  `pick_lan_ipv4(IP.get_local_addresses())` (private LAN IPv4 first). Lobby screen: host header shows the code +
  Copy (`DisplayServer.clipboard_set`) + WAN hint (public address + forwarded UDP port); Join panel has a code
  field (`LobbyScreen.join_by_code()` -> fills address / port -> `join()`). No LAN host list: Net has no
  discovery. Strings `ui.lobby.code.*`.
