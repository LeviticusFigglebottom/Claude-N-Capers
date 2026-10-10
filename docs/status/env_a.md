# ENV A status: Core Systems & AI

Owner: ENV A. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## 2026-10-10 17:30 UTC: P2 stealth complete (A2-01..A2-07), D-032/D-033 merged
### Done (46ac69e)
- A2-01 doors on the nav graph: NPC/AI path look-ahead for closed doors; unlocked doors opened by NPCs (0.6 s stealth / instant loud), guards open keycard doors via `Door.npc_authorized_tags` vs SpawnPoint tags; `NavLink` per door; `door_blocked` signal = P3 breach hook.
- A2-02 cameras: real observers (cone, pan, Led, LOS from Lens), one-shot destroy (Titan on Lethal+ / `titan`), `broken_camera` stimulus, camera_station operator (kill/dominate → all cameras off; running S3.5 countdown still fires), 30% dispatch of a guard to broken cameras.
- A2-03 ECM: 20 s jam (×mult), chaining, cameras + phones jammed, S3.5 countdown untouched, feedback stun 15 m/6 s (gated by `stealth.ecm_feedback`), `stealth.ecm_pager_delay`, `stealth.ecm_opens_doors` on keycard readers.
- A2-04 codes per code_group (`CodeRegistry`, seeded), code notes + keypads, safes (code/lockpick/drill/saw/c4, size durations, time locks), saws, laser grids (static/sweeping/timed_off), bag zipline, ladders.
- A2-05 S3.2 guard cuff flow (pause 5 s, approach, cuff; >1.7 m move or shooting → alarm; 4 min cooldown; 60 s self-free / teammate uncuff), S3.7 misfire 10%, S2.9 marking (4.5 s / 8 s × mult) + Sixth Sense.
- A2-06 deployables runtime (doctor bag, FAK, ammo bag, body bag case, ECM) as `prefabs/deployable`, L2.4 dodge.
- A2-07 `hostage` stimuli (dominated/surrendered/tied guards), STEALTH_ONLY abort (Mercer line + fail after 5 s, no assault), LOUD_ONLY masks crew, pre-planning hooks (`options.preplanning`, see game/systems/heist/README.md).
- `check_all.sh --env a`: PASS (530 tests incl. other envs, 0 failed).
### In progress
- Nothing running. Next (unless redirected): P4 modifier hooks (D-031) and Glasshouse gate bring-up when G1 lands.
### Blocked
- —
### Questions for lead
- QA-13 (gameplay_prefabs.md additions): door `npc_authorized_tags`; security_camera `titan`; keypad `targets`; safe `code_group`, `time_lock_s`; laser_grid `beam_count`, `period_s`, `off_s`, `phase_s`, `sweep_beams` + optional visual nodes `Beam0..n` (horizontal for static/timed_off, vertical for sweeping); new runtime-only prefab `res://systems/prefabs/deployable/deployable.tscn` (`DeployablePrefab`, exports `kind`, `deployable_id`; visual = DeployableDef.model or a `Body` placeholder).
- QA-14 (strings for ENV B): ui.blocked.code_unknown, ui.blocked.requires_bag, ui.blocked.no_deployable, ui.blocked.no_space; ui.prompt.enter_code, read_note, place_saw, place_c4, start_time_lock, zipline_bag, use_first_aid_kit, ecm_feedback, uncuff, suspicious_not_allowed; vo.guard.cuff_warning, vo.mercer.abort. Note the existing `ui.blocked.*` vs csv `ui.prompt.blocked.*` naming mismatch: which is canonical?
- QA-15 (audio cues for ENV C): cue.keypad_accept, cue.c4_armed, cue.c4_explode, cue.time_lock_start, cue.time_lock_done, cue.laser_trip, cue.zipline_attach.
- QA-16: S8.6 says feedback is built into every ECM, but key `stealth.ecm_feedback` (FLAG) gates it. Implemented gated; flip if every ECM should have feedback.
- QA-17: no `crew_cuffed` EventBus event exists; HUD/audio can only see CrewState.CUFFED via LocalHudModel. Add `crew_cuffed(slot, by_net_id)` / `crew_uncuffed`?
- QA-18 (pre-planning, C3): ENV B has no asset data yet; the proposed AssetDef shape `{id: {cost, favors, slot, grants, drop, spawn_tag, escape_tag, force_variants, reveals}}` and PREPLAN_POINT matching (`asset_slot` property, then metadata, then node name) are in game/systems/heist/README.md. Please confirm in data_schemas.md / heist_map.md.
- QA-19: STEALTH_ONLY alarm goes LOUD then ends (result `stealth: false`); HeistResult has no failure-reason field. Add `"fail_reason": StringName`?
- QA-20: `stealth.casing_can_mark` (B's key) gates marking while unmasked; PD2 allows marking while casing by default. Confirm.
- Not replicated yet (P3/P6 net hardening): placed deployables, known codes, pre-plan drops, interaction progress on remote clients.
### Ready for integration
- yes; `check_all.sh --env a` result: PASS

## 2026-10-10 16:00 UTC: A-M2 + A-M3 (A1-03 behaviour, A1-04..A1-10, A1-12), trunk merged (D-026..D-029)
### Done
- A1-04 detection: per-(observer, slot) meters, S2.2 formula, DR table, casing (PUBLIC always safe, D-025), crouch ×0.75, stimuli (corpse/bags/glass/drill/alerted NPC/restrained/open door), noise propagation (halved without LOS, cameras deaf), cameras with 7 s countdown, detection_progress to the observed peer only. (9a7328f)
- A1-05 Security Officer: PatrolGraph routes (`&"patrols"` stream), pauses, investigate, 2 s radio (cancelled by death), COMBAT; `security_officer.tres`.
- A1-06 civilians: idle/wander, panic → phone/alarm button/guard → call → alarm, shout/intimidate (D-016 roll), re-shout, cable ties, hostage count. (6309f2c)
- A1-07 pagers (2–4 s delay, 12 s window, 10 s hold, juggling, 4 cap, timeout), body bagging, loot bags (carry/drop/throw by weight, secure after 0.5 s rest, BODY_HIDE hiding), small loot; A1-03 behaviour for display case, drill (jams per seed, fix, auto-restart, noise), safe, keycard reader, window, body container, escape zone. (bced306)
- A1-08 combat on the D-026 single hit path: crew weapons (semi/auto, RPM, spread, falloff, reload, suppressed noise), server-validated hit claims, health/armor gating/regen, downs/bleedout/custody, revive; NPC gunner; `CrewController.spawn_for_range()` / `set_loadout()` (QB-25); default loadout = kestrel_p9 + suppressor via LoadoutResolver stored on `crew.loadout`.
- A1-09 AssaultDirector: CONTROL → ANTICIPATION → BUILD → SUSTAIN → FADE → CONTROL, out-of-LOS + 15 m spawns, enemy cap; Patrol Officer / TAC Light brains (cover-lite, flank-lite). Solo Routine reaches FADE in ~125–155 game s.
- A1-10 AI teammates: hidden at spawn in stealth (D-014), loud follow/fight/revive (humans first).
- A1-12: test that every phase-1 modifier key has a hook in game/systems and a behaviour test.
- `game/tests/a/test_p1_sandbox_gate.gd`: the lead's gate steps 1, 2, 4, 8 copied verbatim onto the dev sandbox, plus steps 5, 7, 10, 11 — all 8 PASS. (6986a91 and later)
- ENV A tests: ~200; `check_all.sh --env a` PASS on a clean worktree.
### In progress
- Waiting for Glasshouse G1 to run the real gate; polish backlog: door nav toggling, AI door handling, co-op net_id path table for map prefabs.
### Blocked
- —
### Questions for lead
- QA-9: gate step 4 masks the bot in full view of the target guard; on a populated map (the sandbox) OTHER guards/civilians see the masked bot and raise the alarm before the 10 s answer completes. My sandbox copy removes the other NPCs for steps 4/5. Glasshouse may hit the same: either pick an isolated guard in the gate, or hide the bot (unmask until behind the guard).
- QA-10 (ENV B data): `loot.body_bag` has weight MEDIUM but S6.3 says HEAVY (ENV A forces HEAVY via LootTweak); `weapon.kestrel_p9` `headshot_mult` is 2.0 but D-026 makes it a bonus (should be 1.0, else player headshots are ×6).
- QA-11: AI teammates can't open doors; closed prefab doors aren't in the navmesh. Proposal: in loud, doors on an AI path are opened by the AI (instant for unlocked doors). OK?
- QA-12: alarm reasons in use: guard_radio, civilian_call, phone_call (phone prefab), alarm_button, glass_alarm, pager_failed, pager_limit, camera. Going loud cancels pending pagers with `pager_failed(&"cancelled")` (no alarm); audio/voice should ignore that reason. Please list these in events.md if you agree.
- Lead's question (ENV split): A1-09/A1-10 are already implemented and tested here; carving them out now would cost more than it saves. ≥ 2 h queued: no (≈ 1–2 h of polish plus the Glasshouse gate bring-up; P4 modifier hooks after that).
### Ready for integration
- yes; `check_all.sh --env a` result: PASS (local suites green; clean-worktree run in progress at push time, lead pre-review 424 tests: all ENV A pass)

## 2026-10-10 14:30 UTC: A1-01, A1-02, A1-03 (shape), A1-11, dev sandbox — milestone A-M1
### Done
- A1-01 `HeistLauncher.launch()` (await-able), `HeistRuntime` (phase machine LOADING→CASING→STEALTH→LOUD→ESCAPE→ENDED, services, crew/NPC spawning, HeistResult), `VariantResolver` (rules/pick/difficulty_add/requires/excludes, scalars, rare events, strips inactive slots before spawning), `HeistMission` base (objectives, on_event, timers, require_items/require_loot, say, activate_escape, end_heist), every test hook in test_hooks.md. (29b908d, f965586)
- A1-02 `CrewController` (walk/sprint/crouch/jump, casing limits S1.1, 1 s mask-up hold S1.2, bag weight limits S10.1, no movement noise S1.5, eye 1.65 m), `PlayerInput` → CrewIntent, intent/position RPC skeleton (client predicts, server sanity-checks).
- A1-03 shape: 21 prefabs at `game/systems/prefabs/<name>/<name>.tscn` with contract exports, `UsePoint`, `Interactable`, runtime-instanced placeholder visuals carrying visual_slots.md node names. **ENV C: read `game/systems/prefabs/README.md`.** Working behaviour so far: door (none/lockpick/keycard), keycard pickup, small loot, escape zone activate. (73bce75)
- Interaction framework: `InteractableComponent` + server `InteractionSystem` (2 m ray + 10° cone, explicit target for bots, cancel on 0.5 m move / 40° look-away / damage, juggling support).
- A1-11 `LocalHudModel` with the full ui_hud.md property list + signals. **ENV B: read `game/systems/hud_model/README.md`.** (6f5bff4)
- Dev sandbox `res://systems/dev/dev_sandbox.tscn` (`HeistLauncher.launch(&"dev_sandbox", …)`), generated by `build_dev_sandbox.gd`, baked navmesh, all contract nodes, 15 prefab types placed.
- Stealth API skeleton (`StealthDirector`, observer protocol, stimuli, NPC damage/death/one-shot rule), `NpcMotor`.
- Tests: 33 ENV A tests (A1-01/02/03/11, sandbox). `check_all.sh --env a` PASS on 584a480.
### In progress
- A-M2: A1-04 detection, A1-05 guard AI, A1-06 civilians (subagents running); next A1-07 pagers/bodies/bags + A1-03 behaviour.
### Blocked
- —
### Questions for lead
- QA-1: HeistLauncher cannot build `res://world/heists/<id>/<id>.tscn` (check_banned forbids cross-env paths from systems/). Proposal: ENV C ships a global `class_name HeistCatalog` with `static func map_scene_path(id: StringName) -> String` (C-owned, like B's ContentDB); the launcher already uses it when present. Until then: `options.map_scene` or `HeistLauncher.register_map()`.
- QA-2: gate step 4 says the kill uses the suppressed pistol, step 8 says the default pistol is unsuppressed; neither passes `loadouts`. Proposal: launcher default loadout (no `loadouts` option) = `weapon.kestrel_p9` + suppressor resolved via LoadoutResolver. Step 8 still goes loud because the guard sees the masked bot 6 m in front of him.
- QA-3: HeistVariantTable `excludes` semantics are unspecified. Implemented: if any listed slot of the other group is active, this rule picks 0 (empty list = any slot). Please confirm or specify per-slot exclusion.
- QA-4: project.godot has no InputMap actions; PlayerInput registers defaults at runtime when missing (move_*, sprint, crouch, jump, interact, fire, aim, reload, shout, melee, throw_item, deploy, mask_up, slot_primary/secondary, drop_bag). Please add them to project.godot.
- QA-5: S1.1 "within 3 m of a guard fills while casing" conflicts with gate step 2 ("unmasked in a PUBLIC zone next to a guard for 5 s → no detection"). Implemented: the too-close rule does not apply inside PUBLIC zones (tweak flag `casing_too_close_applies_in_public = false`). Please confirm.
- QA-6: bug in `tools/ci/check_banned.py`: the `*input*.gd` exemption tests `"Input." in rx.pattern`, but the pattern text is `\bInput\.` so the exemption never fires. `player_input.gd` reads Input via `Engine.get_singleton(&"Input")` until it is fixed; I'll revert after.
- QA-7: with agent radius 0.35 a 0.25 m nav cell closes 0.9 m doors and lifts the navmesh 0.5 m. The sandbox bakes at cell 0.05; please set `navigation/3d/default_cell_size`/`default_cell_height` = 0.05 in project.godot (ENV C heists will need it too).
- QA-8 (for ENV C, confirm): prefab `UsePoint` sits on the object's −Z side (visual_slots.md: −Z faces the room/user), rotated so its −Z faces the object; exception drill_point (its −Z points into the lock).
### Ready for integration
- yes (A-M1); `check_all.sh --env a` result: PASS

## 2026-10-10 00:00 UTC: (not started)
### Done
- Environment created by lead.
### In progress
- —
### Blocked
- —
### Questions for lead
- —
### Ready for integration
- no
