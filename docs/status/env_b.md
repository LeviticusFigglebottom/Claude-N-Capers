# ENV B status: Content & Progression

Owner: ENV B. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## 2026-10-11 UTC (5): B6 follow-ups, D-074/D-075, B7-01..B7-04
### Done
- B7-03 contact radio: `ContactRadio`, `RadioLinePicker` (GameRng `radio` stream), `RadioTweak`, `SubtitleOverlay`.
  - The heist contact speaks objective / alarm / assault / escape / loot facts (one voice per heist, lead).
  - Guard and crew subtitles sit behind `accessibility/subtitles_all_speakers` (default off).
  - Mercer's old generic alarm / assault / loot / escape lines are retired.
- B7-01 career + save v7: `PlayerProfile.career` and `weapon_finishes`; `Career.record` on the payday path; career screen; v7 golden fixtures.
- B7-02 achievements: 41 achievements; reward masks via `MaskPartDef.unlock`.
  - clean_lines, headhunter and trigger_discipline stay locked until shots/hits/headshots reach HeistResult.
- B7-04 weapon finishes: 12 finishes (`finish.<name>` ↔ `unlock.finish.<name>`), `FinishApplier`, workshop picker, `Loadout.weapon_finishes` (D-074).
  - The persistence test now saves and loads the real v7 field.
- D-075: Ostrander Federal rename, Afterhours contact = Accountant, `loot.painting_study`.
- Drop-in: `DropInFlow.apply_live_policy` applies a host's Options change mid-heist.
- `check_all.sh --env b` @ 541a21dc (trunk 2eb3b2e merged): PASS (1673 tests, 0 failed, 5 skipped).
### In progress
- —
### Blocked
- P5 contract data waits for ENV C's G0 docs to be marked APPROVED.
### Notes
- A test runner whose script fails to parse hangs instead of failing. Run suites under `timeout` and watch the log's age, not the CPU load.
### Questions for lead
- Placement of a `profile` hub station (C/A).
- Should ProfileValidator drop unknown finish ids?
- Should achievement reward parts be excluded from payday cards?
### Ready for integration
- yes

## 2026-10-11 UTC (4): B5-01..B5-05 pull-forwards
### Done
- B5-01 options (merge f3340b8).
  - `GameSettings` saves to user://settings.cfg and has key/pad rebinding with conflict detection, plus audio, video and accessibility settings.
  - Five colour-blind HUD palettes, tested for contrast under simulated colour blindness (Machado).
  - In a heist, `pause` opens options as an overlay.
  - Hooks for A and C are in content/docs/options.md and were routed by the lead.
- B5-02 Notoriety (merge 2d84679).
  - Ranks I–XXV need level 100 and spending cash ◇; +2%/rank XP, capped at +30%.
  - Skill builds are held after a rank-up and re-bought as levels return. Cosmetic and music unlocks.
  - Save v6 adds notoriety fields and `music_choice`.
- B5-03 music (merge e16c4ff).
  - `MusicCatalog` reads C's table, or a stub list until it lands.
  - Picker in pre-planning and the lobby; the `options["music_track"]` launch option.
  - A jukebox station; Play is disabled until C's `MusicDirector.preview` exists.
- B5-04 Dockside Burn (merge ac2d797): loot, 5 pre-planning assets, 10 objectives, 31 VO lines, a Reyes contract ($95k placeholder), and a HeistDef proposal for C.
- B5-05 civilian UI (f417e8f, strings in 5368092).
  - The HUD follows ui_hud v1.6 `player_mode`: a Civilian badge, gear widgets hidden, teammate mode shown.
  - The loadout screen shows a civilian-start notice.
- `check_all.sh --env b` @ e16c4ff: PASS (1384 tests, 0 failed, 5 skipped).
### In progress
- —
### Blocked
- Thermite → `LootDef.is_tool` waits for D-068 on origin.
### Notes
- check_all rewrites docs/levels/*/validation.md. Run `git checkout -- docs/levels` after every run.
- A "Unexpected NUL character" warning prints at Godot startup in test runs. Nothing fails; source not found yet.
### Questions for lead
- See the B5-03 report: lobby summary `music` field, scrolling hub station list, placeholder track names.
### Ready for integration
- yes

## 2026-10-11 UTC (3): D-057 params, D-058, armor bag gating, ChargingHandle
### Done
- D-057 (ed9f77e, b1123d0): special-weapon `params` with A's numbers. Bow `charge`, Shrike `lever`, and arrow/bolt armor pierce. Both Furnace nozzles carry full flame blocks.
- D-058 (ed9f77e, d6ba8e4): Harrow/Brute use `anim_set` `shotgun_box`. Their chargers are now `ChargingHandle` nodes; the models are rebuilt, the build is deterministic, and there's a test.
- Armor bag (c6253b4): `deployable.armor_bag` plus `DeployableGate`. The loadout picker shows it locked until perk card 6 (Go Bag) grants `deploy.armor_bag`.
- `ui.escape.heli/line/lift` strings.
- 541d542: restored trunk's night_deposit validation.md, which check_all regenerated and b1123d0 picked up by mistake.
- `check_all.sh --env b` @ c6253b4: tests 1246 / 0 failed / 5 skipped, gdlint and validate_level PASS; only ownership failed (that report). Ownership is OK at 541d542.
### In progress
- —
### Blocked
- —
### Notes
- Closed by lead/A: TeamModifiers reads the D-056 fields, the modifier_keys text is fixed, and A's armor bag prompt switches on its next push.
- check_all rewrites docs/levels/*/validation.md. Never `git add -A` after a check run.
### Questions for lead
- Queue is under 2 h. Ready for P5/P6 pull-forwards.
### Ready for integration
- yes

## 2026-10-11 UTC (2): round 7 (D-056), D-052 lobby, A3-08 range, QB-50a
### Done
- D-056 (round-7 merge): MenuFlow no longer calls ModifierPush (A pushes on the server).
  - Every granted key is in test_perk_wiring HOOKED; perk_decks.md coverage is all ✅, with field names checked against modifiers_params.md.
  - `team.damage_reduction_hostage` is now `{absorb_per_hostage, max_hostages}`: Foreman card 9 is 5/4 ◇, Zip & Tie aced is 5/8.
  - Added `ui.prompt.use_armor_bag`.
- D-052: LobbySession uses `Net.connection_failed` (new reason `unreachable`) and `Net.host_lost`, and `Net.join` carries the profile name. Loopback tests added.
- A3-08: the range reads `NpcHitRules.armor_of` only. Removed `_armor_of_mirror`, the stand-in health/headshot arrays and `shield_stopgap`.
- QB-50a: `portrait_texture` set on vance (odile, provisional), reyes (hollis) and accountant.
- data README: Plowman reload numbers per D-045 (3.4 / 4.2 s).
- `check_all.sh --env b`: PASS (1238 tests, 0 failed, 5 skipped).
### In progress
- —
### Blocked
- Batch-3 special mechanics wait on ENV A; anim sets wait on D.
### Notes
- ENV A's TeamModifiers.hostage_reduced still reads `{per, max}` with value-based shape detection. Until A switches to the D-056 fields, the hostage absorption from our data does nothing.
- Proposed: a `deployable.armor_bag` DeployableDef plus loadout-picker gating on `deploy.armor_bag`. A's fallback def covers it for now.
### Questions for lead
- —
### Ready for integration
- yes; `check_all.sh --env b` result: PASS

## 2026-10-11 UTC: B4-14, B4-16..B4-20, D-050/D-053/D-055 follow-ups
### Done
- B4-14 QB-L2 (afacf75): `ModifierPush.push(loadouts)` sets the per-slot `loadout` source and the TEAM sources at launch (solo and co-op host). D-050: Warden akimbo flag.
- B4-16 (9ca14ff): save v5 with unlocks, achievements and pro_job_locks; ProfileSchema type sanitizing; ProfileValidator pruning; golden migration fixtures v0..v4 plus a damaged v5; save_format.md.
- B4-17 (a713639): Workshop 3D orbit view with picker, turntable, slot focus, live deltas and DR preview, equip/buy.
- B4-19 (e6ba2a7): StaminaBar on ui_hud v1.4 plus MockHudModel demo steps.
- B4-20 (495cafb): achievements stub (8 defs), hooked on the payday apply path; the cataclysm_clear unlock; achievements screen.
- B4-18 (merge 91f947d): armory batch 3 with 19 weapons (36 total), 89 mods, models on the pipeline, previews, strings and tests.
- B4-12/B4-04 (8ac82cd, acd8fea): `fire_cue_suppressed` only on weapons with a SUPPRESSOR slot; test_armory enforces it.
### In progress
- Round-7 follow-ups once A's server-side push is on trunk: drop the MenuFlow ModifierPush calls, hooked keys and coverage, `ui.prompt.use_armor_bag`, D-056.
### Blocked
- Batch-3 special mechanics (bow/crossbow, launcher, flamethrower, saw, minigun, lever) wait on ENV A's answers. Anim sets wait on D.
### Notes
- The batch-3 tests tolerate missing anim sets.
### Questions for lead
- —
### Ready for integration
- yes; `check_all.sh --env b` @ 91f947d: PASS (1202 tests, 0 failed, 6 skipped)

## 2026-10-10 20:20 UTC — D-043..D-047 follow-ups, B4-07 hub + GSR theme
### Done
- D-045 (35b3bcc): shell-fed reload times are derived by LoadoutResolver after mods (Plowman 0.4/0.4333/0.4/1.2 → 3.4/4.2 s); no raw reload deltas on shell-fed mods; test_armory uses the same formula.
- D-043 (8079505): strings and vo.crew.ack_* lines for every CrewOrders.ORDERS entry, with a test.
- D-044 (dfe064d): Rampart FeedCover hinged at the rear, opening 78° about local X; SightRail rides on it.
- D-043 QA-25 (88059db): `Loadout.mask_descriptor` is filled by `LoadoutResolver.resolve(loadout, profile)`.
- HUD v1.2 (25ba839): CustodyPanel. The range reads ammo via `LocalHudModel.track(crew)`.
- D-046 final (beddea7, e9e5e5b): category `spawn`; merge() takes `{favors, disable, assets}` only; favors come from the HeistDef; `resolve_ids` returns {} when nothing is accepted; `asset.inside_keycard` and `asset.propped_door` (force_variant, limited to their points); 9 Glasshouse point strings.
- B4-07 (67e3e1d, merged in fdbea9d): safehouse hub.
  - Stations board, planning, armory, masks and range; `MenuFlow.open_station(id)` for ENV C's 3D hub.
  - Board → briefing → pre-planning → loadout with is_pro threaded into the launch options and the payday XP.
  - GSR theme: warm darks, brass PrimaryButton, chamfers, cyan focus.
  - Per-heist accents via `UiAccent`; WCAG contrast test.
- `check_all.sh --env b` @ fdbea9d: PASS (849 tests, 0 failed, 4 skipped).
### In progress
- —
### Blocked
- —
### Notes
- After the D-047 trunk merge, take the lead's versions of test_masks.test_placeholder_visual (it currently logs a SCRIPT ERROR at :163 with D's real meshes) and test_preplan_screen; review the new lift/hack strings.
### Questions for lead
- Open from the earlier entry: QB-PC1/2 (payday cards), QB-BRD2/3 (board co-op, broker prices), QB-52..55 (small loot, intel_laptop scope, Night Deposit points, placeholder heists in the menus).
### Ready for integration
- yes; `check_all.sh --env b` result: PASS

## 2026-10-10 19:40 UTC — B4-05, B4-06, B4-08, B4-09, B4-10, QB-50b; B4-07 in progress
### Done
- B4-08 (49d6cc7, 7df8a7a, 539c53d), D-038/D-039 follow-ups:
  - Glasshouse objective ids come from the G0 `[tag]`s; the guessed keys are removed and the rule is in the README.
  - QA-14 strings added, plus keys A's code already used but we lacked. A test scans systems/world/core for prompt, blocked and voice keys and fails on any missing one.
  - `ui.prompt.blocked.*` renamed to `ui.blocked.*`.
  - QA-16: the deprecated key is rejected by validation and a data-scan test.
  - PreplanResult v1 exactly per preplanning.md: drops[].kind, spawn_tag, escape_tag, reveals, force_variants, cash_spent; `resolve_ids()`; points from `<Map>/Preplan` instanced off-tree; split payment for voted assets; votes via `Net.lobby_send`.
- B4-05 payday card pick (f7e51d6):
  - Three cards (cash, XP, weapon mod, mask part), deterministic from (run seed, slot), with tiers per difficulty. The `progression.card_drop_quality_add` shift applies.
  - Never offers an owned item. 30 s auto-pick; successful heists only.
- B4-06 the Board + broker (d9f8377):
  - City map drawn in code; 8 staggered rotating contracts (600 s), deterministic from the time bucket.
  - Lethal and Cataclysm need level 80; pro jobs 20% from Tense up.
  - Broker costs $12k–$360k ◇ + 5% of the payout.
- B4-09 Night Deposit (5d44618):
  - `loot.cash_bricks` (MEDIUM, $1,600 ◇).
  - 12 objective strings from the doc's tags, plus Accountant briefing lines and Mercer's closing line.
- B4-10 Shadow Ledger (6ab8a80):
  - Loot `ledger_laptop` (LIGHT), `ledger_drives`, `ledger_books` and `painting` (MEDIUM), values ◇.
  - Assets `intel_laptop`, `gondola_left_hung` and `riser_panel` per the doc.
  - 13 objective strings, plus briefing lines.
- QB-50b (1af10b6, 3ec98cb): mask base mesh paths use the pipeline layout; the placeholder UV now has u=0 at +X (matching D's meshes); the mask preview starts at a 35° 3/4 view.
- `check_all.sh --env b`:
  - B4-08 and B4-10 each passed the full check on their own commits (725 tests, 0 failed).
  - The merged HEAD with trunk, after B4-10, is being re-run now.
### In progress
- B4-07: safehouse hub UI layer (stations + `MenuFlow.open_station(id)` for ENV C's 3D hub), Board wired into the flow with is_pro, and the GSR theme / per-heist accent pass.
### Blocked
- —
### Questions for lead
- QB-PC1: should an unpicked payday card survive a quit? That needs a save v5 `pending_card`; today quitting forfeits it.
- QB-PC2: boosts and skins are omitted from the card table until those systems exist. OK?
- QB-BRD1: the Board replaces heist select as the job source (B4-07 wires it; heist select stays at the planning table for now). Who enforces the pro-job "no restart" on failure: MenuFlow or A?
- QB-BRD2: in co-op, should clients see the host's board (seed + bucket via lobby) or their own?
- QB-BRD3: broker prices and level gates are placeholders and need a balance pass.
- QB-52: Night Deposit and Shadow Ledger small loot: add a `loot.small_valuables` def, or just a cash amount via HeistResult `small_loot`? What values?
- QB-53: `asset.intel_laptop` shows on every heist, since generic assets aren't filtered. Should heists without a `laptop` variant `disable` it (ENV C), or should it be a heist-only asset?
- QB-54: Night Deposit's preplan points (`pp_insider_code`, `pp_insider_keycard`, `pp_vent`) have no library asset. Should ENV C define them in HeistDef.preplanning, or should B add library assets?
- QB-55: placeholder heists (Night Deposit, Shadow Ledger) show in the menus but fail to launch until their map and def exist. Keep them visible, or hide them until G1?
- For ENV C: Glasshouse `HeistDef.preplanning` still uses the old shape (ignored with one warning), and its map has no `<Map>/Preplan` node yet.
- For ENV A: PreplanAssets still reads `options["preplanning"]` with the old shape. The contract's DifficultyDef asset-cost multiplier doesn't exist, so it lives in `PreplanTweak.cost_mult` for now.
### Ready for integration
- yes after the HEAD re-run passes (see the next message to the lead)

## 2026-10-10 18:40 UTC — range on A's runtime, HUD adapter removed, D-034 follow-ups, B2-01/02/03
### Done
- Range on ENV A's crew and weapon runtime (6b7c1af).
  - `CrewController.spawn_for_range` + `set_loadout` on every swap. The WeaponVisual viewmodel is on the crew camera.
  - Last-shot readouts come from our targets' `damage_applied`, filtered to the crew's net id. Ammo is read from the crew's weapons.
  - Panel/aim mode pauses `PlayerInput.enabled`. The test camera and debug gun are FALLBACK ONLY.
  - A headless test drives a real CrewIntent shot and checks exactly one `damage_applied` for 35 damage.
- HUD binds LocalHudModel directly; HudModelAdapter deleted (dd1f97e). A new MarkedTargets widget was added. Tested against a real HeistRuntime on a test map (vitals, ammo, Stinger warning, masked).
- D-034 follow-ups (d1dae61).
  - `defense.post_revive_buff` LIST entries are granted per skill.
  - Plowman shell-by-shell reload: start 0.4, per round 0.5, end 0.4 ◇. Its full reload times are now derived from those.
  - Pellet display exponent 1 (Plowman shows 160).
  - `data/tweak/perk_points.tres` (500 XP per point).
- B2-02 briefing screen (38fd559).
  - ContactDef for vance, reyes, accountant and mercer, with drawn placeholder portrait silhouettes.
  - Shows objectives, loot at difficulty, contract pay and escape options.
  - "Play Briefing" emits local `voice_line_requested` with subtitles; 8 original Glasshouse briefing lines.
- B2-01 pre-planning (b149a9a).
  - 10 generic assets (drops, insider info, cable ties, body bags, alternate entry, voted van position). Cost ×1…×13 by difficulty, 10 favors.
  - PreplanPlan validation and `apply()` hand-off dict; PlanVote with host tie-break.
  - A blueprint drawn in code on a placeholder Glasshouse plan (shown with a banner until real map data exists). Doc: `content/docs/preplanning.md`.
- B2-03 mask customization (c110a03).
  - 5 bases, 9 materials (library refs), 10 colour pairs, 8 patterns. Custom masks go in 6 slots; owned parts are tracked.
  - `MaskComposer`/`MaskCatalog.resolve/descriptor/from_descriptor` for ENV A. Save format v4.
  - Mask screen with an orbit preview and an original pattern shader. Doc: `content/docs/masks.md`.
- Tests use a per-process SaveService root (8eeb53c). Parallel runs in several checkouts shared `user://test_profiles` and flaked.
- `check_all.sh --env b` @ 8eeb53c: PASS (551 tests, 0 failed, 8 skipped).
### In progress
- Wiring the flow heist select → briefing → pre-planning → loadout → launch, the Masks button, and the loadout mask-picker fix for custom masks.
### Blocked
- —
### Questions for lead
- For ENV A:
  - QB-46: Please document a way to pause and resume a crew member's input (the range sets `PlayerInput.enabled`), e.g. `CrewController.set_input_paused(bool)`.
  - QB-47: Who makes the crew camera current, and who attaches `CrewController.weapon_visual`? The range does both itself; heists need an owner.
  - QB-48: Could LocalHudModel track a crew member without a HeistRuntime (a `tracked_crew` node)?
  - QB-49: There is no gamepad look on `PlayerInput`.
- QB-PP1: PREPLAN_POINT node contract.
  - Proposal: a Marker3D in `G.PREPLAN_POINT`, named by point id, with metadata category/label/floor/params (spawn_tag, variant_group, variant_slot).
  - Who bakes the menu blueprint resource: ENV C via HeistRegistry, or B under `data/preplanning/blueprints/`?
- QB-PP2: should HeistLauncher take `options["preplan"] = PreplanPlan.apply()`? The shape is in `content/docs/preplanning.md`; applying it is A2-07.
- QB-PP3: who pays for a voted plan? The stub charges the host.
- QB-PP4: co-op plan votes need a lobby message relay in the Net API, e.g. `Net.lobby_send(kind, data)` plus a `lobby_message` signal. Until then: solo/host only.
- QB-PP5: should the `HeistDef.preplanning` merge format (favors, disable, `asset.<id>` overrides) be recorded in heist_def.gd and data_schemas.md? A Glasshouse sketch for ENV C is in the doc.
- QB-50 (art): contact portraits for ENV D/C go in `content/data/contacts/<name>.tres` `portrait_scene`/`portrait_texture`. The mask base meshes are `assets/masks/mask_base_<heron|visage|vulpine|bruiser|owl>.glb` (face-centre pivot, −Z, front-projected UV0), plus optional pattern textures. See `content/docs/masks.md`.
- QB-51: ENV A should rely on content classes `MaskCatalog.resolve/from_descriptor` + `MaskComposer.instantiate` to attach masks. Record this in characters.md?
### Ready for integration
- yes (everything up to 8eeb53c); `check_all.sh --env b` result: PASS

## 2026-10-10 17:30 UTC — B4-03, B4-04, D-031 key grants; state-tolerant tests for A-M2/M3
### Done
- State-tolerant tests (8554760). The range accepts either the real crew or the temporary camera; the HUD binds a v1.1 model directly or an A1-11 model through the adapter. Verified on a trial merge with origin/env/a-core.
- D-031 (1a48390). Every requested key is granted and `blocked_on_keys` is empty; the strict test is restored as `test_no_blocked_parts_and_every_requested_key_is_granted`.
  - LIST merge: see QB-38.
  - Routing: `team_perk.<deck>` for perk `team.*`; `team_skill.<id>` for skills; neither duplicated in personal modifiers.
  - Hustler vests are Light, Patrol and Heavy only.
  - The suppressed concealment qualifier counts once per suppressed weapon.
- B4-03 (d3796a1). Skill tree screen and perk deck screen, opened from the loadout screen.
  - Tiers, basic/aced, and a refund that is blocked if it would break a tier gate (PD2 style).
  - Free respec with confirmation; 3 skill sets.
  - Save format v3 (`skill_sets`, `active_skill_set`, `perk_cards`) with a 2→3 migration.
  - Perk points = floor(total XP / 500) ◇. Each deck keeps its own card progress, unlocked in order.
- B4-04 (59a7bdc..ac7447d). Six weapons with models and previews:
  - Warden .45 (pistol), Hornet 9 (SMG, secondary), Corsair (AR), Plowman 12 (pump shotgun, 10 pellets), Rampart (LMG), Heron .308 (bolt sniper: AP, shield and wall pierce, falloff min 1.35).
  - 30 mods (shared rail reflex and prism optics) and stock parts. Deterministic: 92/92 identical files.
  - Throwables `throwable.steady_flask` and `throwable.boss_injector` exist for the perk decks.
  - P9 previews re-rendered with the library materials.
- `check_all.sh --env b` on a fresh merge with trunk 5d1cc0f: PASS (326 tests, 0 failed, 7 skipped).
### In progress
- —
### Next (queued, ≥2 h)
- After A-M2/M3 land on trunk: switch the range to the real crew and weapon runtime (debug camera only as a fallback), delete HudModelAdapter, bind the HUD directly.
- Apply `progression.xp_mult` in PayoutCalculator.
- Pending lead answers below: shotgun per-shell reload, shotgun display damage.
### Blocked
- —
### Questions for lead
- QB-38 (LIST emit shape; core change needed). `Loadout.modifiers[key]` holds `Array[Dictionary]` for the LIST keys:
  - One deep-copied entry per granting skill or card, each tagged `"_source": StringName` (a skill id, or `perk.<deck>.card<n>`).
  - Entries are sorted by `ContentDB.id_less`; within one skill the aced dict replaces the basic one.
  - `Modifiers.list()` currently casts `values[key] as Dictionary`. Please make it accept an Array: append each entry and keep its own `_source`, setting `_source` to the source name only when the entry has none.
- QB-39. `defense.post_revive_buff` (PARAMS, last-wins) is granted by two skills, Back on Your Feet and Second Lease, so one overrides the other. Should it become LIST, or should we merge the grant?
- QB-40 (schema additions marked ◇ in skills.md; please confirm):
  - `weapon.kill_reload_buff.mag_falloff_from` (Run and Gun: "per round above 20").
  - Bulletstorm duration = lerp(base, max, fraction of the refill taken).
  - `weapon.melee_bloodthirst.max_mult` = 17.0 (+1600%).
- QB-41 (materials, ENV C). The new weapons also need `alu_anodized_black`, `polymer_tan`, `polymer_olive` and `glass_lens_coated`. Library `polymer_black`, `rubber_black` and `metal_matte` also render quite light on weapons.
- QB-42 (ENV D anim sets, ENV C cues). Viewmodel sets `smg`, `rifle`, `shotgun`, `lmg` and `sniper`, plus `cue.weapon_<set>_fire(_suppressed)` for each. Should the Warden .45 share the pistol set? Animated parts for ENV A: the shotgun `Pump` (slides +Z) and the sniper `Bolt`.
- QB-43. Shotgun reload is whole-tube today; PD2 loads shell by shell. Add `WeaponStats.reload_per_round_s` (or similar)? Separately, the display damage for pellets shows 16 instead of a PD2-style 160. B will set `damage_pellet_exponent = 1` in our display tweak unless you object.
- QB-44. Record in visual_slots.md: `Magwell` sits at the loading port on tube-fed weapons; bipods are a flat recoil bonus until a deploy mechanic exists.
- QB-45. Perk points: floor(XP / 500) from all XP (◇, about 23k points by level 100). Is that OK? The setting lives in `data/ui/progression_ui.tres`; move it to `data/tweak/`?
### Ready for integration
- yes (B4-03, B4-04, D-031 grants); `check_all.sh --env b` result: PASS

## 2026-10-10 16:30 UTC — B4-01 skills, B4-02 perk decks (P4 pulled forward, D-027)
### Done
- D-027 crit rule on range targets (crit ⇒ head mult on any zone; stacks on head), with a test.
- B4-02 (358df11): 14 perk decks × 9 cards in `data/perks/`.
  - Costs 200…4000, totalling 13,700.
  - Shared cards 2/4/6/8 are identical in every deck: Headhunter `weapon.headshot_mult.all` 1.25, Low Profile `stealth.concealment_add.all` 1, Go Bag `weapon.ammo_pickup_mult.all` 1.35, Hustle `weapon.damage_mult.all` 1.05.
  - Signature mechanics use their `perk.*` PARAMS key, with each upgrading card granting the FULL dict (last-wins).
  - Health/armor/dodge cards grant cumulative ratios so the running product equals PD2's additive total (e.g. Bulk = 2.0 health).
  - **Param schemas for review: `game/content/docs/perk_decks.md`.**
- B4-01 (53d0cec): 90 SkillDefs in `data/skills/<tree>/<subtree>/`, plus `SkillTreeDef` (`data/skills/trees.tres`).
  - Tiers 1/2/2/1; costs 1/3, 2/4, 3/6, 4/8 (46 per subtree, 138 per tree); gates 0/1/3/18 counted on lower tiers only; 120 points at level 100; free respec.
  - `SkillPoints.validate/can_unlock/is_legal` handle host legality (architecture §11).
  - Team skills: `team.*` grants are routed through `LoadoutResolver.team_modifier_sources()` as `team_skill.<id>` (non-stacking). `resolve_modifiers` excludes them.
  - Expressibility: 32 skills fully expressible, 29 partial, 29 blocked on keys. Every tier 3–4 skill has a "decision it changes" note.
  - **Full design, mapping conventions and requested keys: `game/content/docs/skills.md`.**
- ContentDB now scans kind folders recursively (needed for the skills layout).
- `check_all.sh --env b` @ ea708fa: PASS (266 tests, 0 failed, 7 skipped).
### In progress
- B4-03 skill tree + perk deck UI (subagent).
- B4-04 armory expansion: 6 weapons + mods + models, the 2 deck throwables, and P9 re-render with ENV C's materials (subagent).
### Blocked
- —
### Questions for lead
- QB-31 (keys for skills): 71 requested keys, grouped with types, semantics and the skills that need them, in `content/docs/skills.md` "Requested keys". 29 skills stay inert until keys exist; a test fails as a reminder when a requested key gets registered. Two of them (`weapon.kill_reload_buff`, `weapon.hit_stack_buff`) are wanted by several skills, which a last-wins PARAMS key can't carry. They need a list-valued or per-source PARAMS design.
- QB-32 (keys for perks): `progression.xp_mult` (MULT), `movement.armor_penalty_mult` (MULT), `deploy.armor_bag` (FLAG), `interaction.doctor_bag_speed_mult` (MULT), `progression.card_drop_quality_add` (ADD), `ability.shout_range_mult` (MULT), optionally `team.armor_regen_delay_mult` (MULT). See `content/docs/perk_decks.md`.
- QB-33: perk param schemas (14 `perk.*` keys plus `team.damage_reduction_hostage`) are proposed in `content/docs/perk_decks.md` for review. ENV A implements them. The registry descriptions of `perk.rogue_dodge_stack` and `perk.crook` should be reworded to match the decks.
- QB-34 (stacking): PD2 adds skill and perk percentage bonuses; our MULT multiplies across sources. Keep multiplicative (the deck cards then use cumulative ratios), or switch some keys to additive semantics?
- QB-35: do `team.*` grants also apply to the granting player? Our TEAM source does apply to them, and we strip `team.*` from personal sources to avoid double counting. Perk-deck `team.*` grants (Foreman) currently stay on the personal source. Should they also go to a TEAM source, e.g. `team_perk.<deck>`?
- QB-36: is `interaction.revive_speed_mult` a time multiplier (lower = faster), like the other interaction keys? Rally Cry assumes so.
- QB-37: Hustler armor tiers: "mid vests only" (fidelity table) vs "all ballistic vests" (research). We used all vests except the suit.
### Ready for integration
- yes (B4-01, B4-02); `check_all.sh --env b` result: PASS
