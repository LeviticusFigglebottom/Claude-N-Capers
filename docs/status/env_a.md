# ENV A status: Core Systems & AI

Owner: ENV A. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## 2026-10-11 06:30 UTC: P3 gate bugs, Dockside Burn QC-35..42, saw targets
### Done
- QC-37 hand saw targets (G.SAW_TARGET `saw_cut`):
  - saw-capable `safe` (hand_saw_safe_s by size, beaten_by saw) and SAW `drill_point` (effective_duration × hand_saw_drill_point_mult);
  - new `deposit_box` (SmallLoot locked until cut, 6 s) and `padlock` (lockpick or saw, opens its `targets`);
  - saw LOS accepts the target's own collider; `saw_point()`.
- P3 gate 1, police breach: loud police (roles police/special) breach locked doors except BARRED/VAULT (`npc_door_breach_s` 2.5 s, cue.door_breach [R]); breachable doors are nav-linked once loud. Open door leaves no longer collide; units were snagging on the breached SalonBackDoor. Glasshouse seed 3001: no more pile-up, police reach and fight the crew. test_p3_loud test_01 at 3001 then wipes the crew (all 4 in custody in wave 3; at 3007 three of four), which is a balance/gate call.
- P3 gate 2, AI rescue: AI teammates free CLOAKER_DOWNED and TASED crew like a revive (auto and orders; `CrewAiBrain.needs_help`) and shoot a tasing Stinger first (`tasing_stinger_score_mult`).
- Replica phase follows the relayed heist_phase_changed (ENDED before heist_ended).
- QC-35: `AssaultDirector.start_delay_s` / `HeistMission.police_delay_s` (0 = start now). Load-time loud begins after `_on_mission_start`.
- QC-36: `enemy.cartel_gunman`, role `cartel`, `npc_cartel.tscn`, CartelBrain, CartelTweak:
  - spawns on GUARD spawns tagged `cartel`;
  - asleep until a noise, sighting, damage or shout wakes it, and wakes its neighbours;
  - holds its post with cover; never dominated, no pager, no cuffs, no surrender;
  - not in alive_units; `police_budget()` = enemy_cap − cartel alive.
- QC-38: `burn_point` prefab (thermite bag consumed, timed burn, cue.burn_warning + burn_warning_s, device_finished, then a fire volume DoT ignoring armour + nav obstacle).
- QC-41: RappelLinks, one-way NavigationLink3D from each RAPPEL point to the floor below; NpcMotor rappel descent (`rappelling`).
- QC-42: POLICE_SPAWN / ENTRY points tagged `breach_only` are never spawns. A sky test was rejected because Shadow Ledger's stair/lift spawns are indoors by design.
- Test fixes: HUD asserts call `refresh()` (poll race under load).
### Questions for lead
- QA-36: cues for ENV C: `cue.door_breach`, `cue.burn_warning`; anim clip `rappel` for ENV D (NpcMotor.rappelling).
- QA-37: ENV C: tag the Dockside interior ENTRY points `breach_only`; tag cartel GUARD spawns `cartel`.
- QA-38: test_p3_loud test_01 at seed 3001 now fails on crew survival, not on stalls.
- Known: test_a3_07 loopback fails when run after the other `test_a3_0*` files (`--filter=test_a3_0`) at e02b81c too, so it predates this round; it passes alone and in the full suite. Investigating.
### Ready for integration
- yes after the clean-worktree check_all (result in the lead message)

## 2026-10-11 04:00 UTC: D-062 launch_options, D-063 reload range, S1.3 civilian mode, fixes
### Done
- D-062: `HeistRuntime.launch_options` (read-only; the network-safe part travels in the bring-up, and the host's values win on replicas). The loopback test checks `music_track`.
- D-063: `FpViewmodel.shared_reload_ratio_ok` / FpViewmodelTweak `reload_scale_min/max` (0.75–1.35, clip length / reload time). One error per weapon+clip. Out of range today: furnace_ft (×0.50/0.51), cyclone_rotary reload_empty (×0.73).
- S1.3 civilian mode (B5-05):
  - `CrewController.civilian` / `player_mode` / `civilian_changed`; `HeistRuntime.start_mode` (options["start_mode"], else HeistDef.start_mode read defensively).
  - Civilians are undetectable, can't mask up or fire, and use only `civilian_allowed` interactables. Masking (alarm) ends civilian mode.
  - New `gear_pickup` prefab (kind pick_up_gear, item_picked_up(&"item.gear", slot), not consumed).
  - LocalHudModel `player_mode` / `player_mode_changed` and `crew[].mode` (ui_hud v1.6 proposal); replicated (`civ`). Tests: test_s1_3_civilian_mode.gd (5).
- Alarm while casing goes straight CASING → LOUD; the armor bag uses ui.prompt.use_armor_bag.
### Questions for lead
- QA-35 (S1.3 contracts): HeistDef.start_mode, ui_hud v1.6 player_mode + crew[].mode, gameplay_prefabs gear_pickup + `civilian_allowed`. Strings for ENV B: the gear prompt and the civilian block reason. Until they land I use ui.prompt.interact / ui.blocked.state.
- AI teammates never pick up gear: they stay civilian until an alarm (OK for P5?).
### Ready for integration
- yes after the clean-worktree check_all (result in the lead message)

## 2026-10-11 UTC: P4 queue (QB-L2, QB-56..62, D-049/D-052/D-056), FP viewmodel, B4-18 special weapons runtime
### Done (85f2246, 91009d7, be70339, 855c8f0, 31939a5, 388d48b, c90a3e3, + B4-18 commit)
- D-049/D-052: `crew_tase_ended`, replicated HUD captain fields, `HeistLauncher.launch_client` (null on host loss / connection failure), damage v1.1 flags, canonical EnemyDef armour params.
- FP viewmodel (characters.md v1.4): char_arms_fp arms, per-set clips, fire/reload/swap/ADS timing, part travel; clip events parsed from ENV D's SOURCE.txt.
- QB-L2 ModifierPush at launch; QB-56..61 (armor speed, ammo drops, armor bag, doctor bag, team.*, stamina + HUD v1.4, shout range); QB-62: all 15 perk.* mechanics (PerkHooks), modifiers_params.md.
- D-056: `team.damage_reduction_hostage` = PD2 Crew Chief flat absorption `{absorb_per_hostage, max_hostages}`.
- B4-18 runtime (answer sent to ENV B, cc lead): `SpecialWeapons` (params from `WeaponDef.params` merged with `WeaponModDef.params`, read defensively), flamethrower cone + FIRE + `BurnStatus` DoT/panic (L3.4), saw (contact-only, blade wear, `saw_target` group, armor/shield pierce), `WeaponProjectile` (bow/crossbow/launcher: gravity, swept hits, Explosion.apply on impact L3.6, retrievable arrows, replicated via dynamic_root), bow draw (`charge` fire mode, server-capped by elapsed time), minigun spin (`spin`, move_speed_mult), `WeaponPartsAnimator` (Breech/Lever/StringUpper/StringLower/String/Arrow/Blade/Rotor). Batch-3 foley cues `cue.weapon_<anim_set>_draw/ignite/stop/rev/spin_up/spin_down` (where the shooter is simulated, replicated from the authority) and `_impact`/`_explode` from projectiles (crossbow reuses bow_impact). Tests: test_b4_18_special_weapons.gd (7).
- Last phase-4 keys: `movement.sprint_speed_mult` (+ server speed check), `weapon.kill_ammo_drop {every_n_kills}`, `weapon.ammo_pickup_throwable {base_chance, step}`; `CrewWeapons.throwable_count` now starts at the loadout ThrowableDef.count (was always 0). Tests: test_p4_modifier_keys_tail.gd (3).
### In progress
- After the lead's ruling: ui_hud v1.5 `weapon_charge`/`weapon_spin` in LocalHudModel; saw_cut on ENV A prefabs (deposit boxes, padlocks).
### Questions for lead
- QA-34 (B4-18 contract): `WeaponDef.params` + `WeaponModDef.params` (Dictionary; mod params shallow-merged in mod order); fire_modes `&"charge"`, `&"lever"`; gameplay_prefabs group `saw_target` with `saw_cut(seconds, attacker_net_id)`; modifier keys `weapon.saw_wear_mult`, `weapon.saw_damage_mult`, `weapon.saw_shield_pierce`; ui_hud v1.5 `weapon_charge`/`weapon_spin`.
- Gaps: loop cues (flame/saw/minigun fire loops) need a CueEmitter on synced state; a remote human's draw/spin foley plays only on their own peer; throwable_count is not replicated to clients yet.
### Ready for integration
- yes after the clean-worktree `check_all.sh --env a` (result in the lead message)

## 2026-10-10 21:15 UTC: A3-07 co-op, prefab collision fit, C4 (trunk merged)
### Done (61411c3, 9619875, b4138ed)
- A3-07: `HeistNetSync` (service `net_sync`): host bring-up via `Net.lobby_send(&"heist_bring_up")` (seed, resolved variants applied not rolled, map path→net_id table, crew ids, phase, preplan, full snapshot); `HeistLauncher.join_running()`; dynamic spawn/despawn RPCs; 15 Hz changed-key state (doors, glass, cameras, devices, NPC alert/health, crew vitals/inventory/bag, bags, interaction sessions → client HUD progress, known codes, custody); 15 Hz transforms. Two-process ENet loopback test (`test_a3_07_coop_loopback.gd`) asserts parity. Gaps (heist/README "Co-op"): no drop-in (P6), runtime-only interactables (corpse bagging, trade/surrender) absent on replicas, no transform interpolation, deployable inventories not mirrored.
- Lead item 6: prefab box collision fitted from the visual AABB (pivot-aware), or the visual's `Collision`, or `collision_size_override`; C4 now calls `Explosion.apply`.
- QA-31: test_l4_11 reads the Longshot cap from DifficultyDef.
- `check_all.sh --env a` PASS (905 tests, 0 failed).
### In progress
- bag_lift door travel/panel/floor/shaft doors + hack_terminal pause; Wrecker-M, Bulwark stagger, Brandt destination; first-person viewmodel animation (characters.md v1.4); after round 3: `crew_tase_ended`, ui_hud v1.3 captain fields.
### Questions for lead
- QA-32 (visual_slots.md): every collision-fitted prefab now accepts a visual-supplied `Collision` StaticBody3D (not only "visual supplies collision" prefabs); please reflect it in the contract.
- QA-33: the co-op loopback test spawns a second headless Godot process (OS.create_process, ENet localhost 27731+); a single-process two-branch test is not meaningful with process-wide autoloads (Net/Ids/EventBus). OK for CI?
### Ready for integration
- yes; `check_all.sh --env a` result: PASS

## 2026-10-10 20:40 UTC: P3 wave (A3-01..A3-03, A3-06, A3-09, A3-10, D-043 follow-ups, AnimDriver)
### Done (97035c6, 8899bb7, 8e1b83d; trunk 4138f96 merged)
- A3-01 specials, all with capsule placeholders carrying contract node names + EnemyDefs + brains + tests:
  Phantom (charge/kick → CLOAKER_DOWNED, sidestep dodge, 10 s cooldown, never the last player standing, play-dead, ECM-feedback immune),
  Stinger (1 s windup, tase → TASED + involuntary fire ×3 spread 15° up, broken by kill/LOS, pairs),
  Longshot (SNIPER_PERCH only, tracking laser, 1.2 s lock, >30 m halving, bypasses armor gating),
  Bulwark (separate shield body, blocks all but shield-pierce ×0.25, fixates, anchors doorways, bang cue, shield stays on death),
  Wrecker G/B/S (Faceplate 150 → Visor 160 → head; stun-immune; ×1.1 explosives; shared enemy.wrecker cap),
  Corpsman (heal/revive one ally ≤7 m through walls, 3 s cd, no medic-on-medic). Wrecker-M minigun and Bulwark stagger not done.
- A3-06: NPC body armor vs AP, TAC Heavy frontal plate, wall piercing (layer 9), suppression (hunch/dive, 30 s resistance, specials immune), `Explosion.apply` (×(1−d/r)^0.1, LOS).
- A3-02 Commander Brandt + Aegis: Hazardous+, wave ≥ 2, 50%/wave, once per heist (also solo, D-015); 10 shields; resistance 10% +5%/5 s to 50%; per-hit cap 10% max HP (×6 explosives); cannot die; retreats at 20% HP or ≤ 3 shields; assault locked while present; captain_arrived/retreated [R]; HUD warning `captain`.
- A3-03 director: drama (L1.2), stage escalation 50/75/100% (L1.3), specials in waves and between waves, factions by difficulty (L1.5: tac/frd/sentinel/zero), special caps from DifficultyDef.special_limits (L4.11).
- A3-09: bag_lift, hack_terminal, OUT_OF_BOUNDS (oob_respawn spawns, loot returns), HeistMission `schedule_at` + `spawn_guards`, device cues verified; A3-10: rule `weights_by_difficulty` for slot groups, escape_zone escape_type/arrival_delay_s/bag_only, no ladders with a bag.
- D-043: LocalHudModel `custody`/`custody_changed`; masks from `Loadout.mask_descriptor` replicated to all peers; security_camera `mount_mode` (ceiling collision below pivot).
- AnimDriver: drives ENV D's humanoid set when a contract visual exists (capsules unaffected); characters swap in by setting EnemyDef.visual.
- QC (Night Deposit) items: (1) camera collision is already on the room side in ENV A (wall z∈[−0.45,0], ceiling y≤0 via `mount_mode`); (2) laser_grid placeholder posts follow `size_m`; (3) `oob_respawn` spawns are excluded from crew start spawns (A3-09); (4) `HeistMission._on_civilian_dominated(civilian, slot)` / `_on_guard_dominated(npc, slot)`; (5) QC-25 timed spawns via `schedule_at` + `spawn_guards` (example in heist/README.md).
- `check_all.sh --env a` PASS (898 tests, 0 failed, no SCRIPT ERRORs).
### In progress
- Item 6 (prefab collision from visual AABB), A3-07 co-op hardening, C4 → `Explosion.apply`, first-person viewmodel animation (characters.md v1.4).
### Questions for lead
- QA-27 (strings for ENV B): ui.prompt.send_lift/call_lift/start_hack/restart_hack (done by B), ui.blocked.lift_full, ui.prompt.trade_hostage/convert/cable_tie (done), vo.crew.ack_follow/hold/carry_bag/drop_bag/revive, vo.guard.cuff_warning, vo.mercer.abort.
- QA-28 (cues for ENV C): cue.phantom_hum/charge, cue.stinger_windup/arc, cue.longshot_report, cue.bulwark_bang, cue.wrecker_roar/step/plate_crack, cue.corpsman_heal, cue.brandt_arrival, cue.aegis_pulse, cue.bag_lift_start/arrive, cue.hack_start/interrupt/done, cue.escape_arrive.
- QA-29 (groups.md): proposed ids faction.tac/frd/sentinel/zero, enemy.frd_agent, enemy.brandt, enemy.aegis, enemy.wrecker_g/_b/_s, enemy.tac_heavy; `params.visual_variant` per faction; GUARD SpawnPoint tag `scripted` (not spawned at load; mission spawns).
- QA-30 (events.md): `special_spawned` is emitted by the special's brain on start (not the director); a broken tase emits `crew_revived(slot, -1)` (no tase-ended event); Brandt resistance is server-only (ui_hud field?).
- QA-31: DifficultyDef.special_limits has no `enemy.longshot` key (limited only by free perches).
### Ready for integration
- yes; `check_all.sh --env a` result: PASS

## 2026-10-10 19:10 UTC: A2-08, A3-04, A3-05, A3-08 (trunk 0748a0e merged)
### Done (8a9bb6b)
- A2-08: resolver `force_if`, `slot_requires`, rare `min_difficulty`, scalar `weights_by_difficulty` (documented in game/systems/heist/README.md "Variant rule fields (A2-08)" for heist_map.md); window glass collision from the visual's `Glass` AABB; safe `keycard` method (`Safe.reader` or reader `targets`); door `push_bar` (inside = −Z side); camera collision kept in front of the wall pivot.
- A3-04: custody (auto-release 119 s Routine/Tense, trade-only above; release full health/50% ammo), trade (5 s + 30 s/civ kill, locked ANTICIPATION..SUSTAIN, highlighted hostage + `trade_hostage` interaction, auto-trade for solo/AI), police cuffing downed non-shooting players, `incapacitate()` for TASED/CLOAKER_DOWNED, shout-surrender of cops (L5.1 formula), tie, Turncoat converts (`ability.converts_max`), fail `all_custody` only when no release path.
- A3-05: AI orders (follow/hold/carry_bag/drop_bag/revive), contextual `order_menu` (T), stealth follow (`stealth_follow_enabled`), ack voice lines.
- A3-08: ECM feedback built into every ECM; crew_cuffed/uncuffed [R]; `HeistResult.fail_reason`; PreplanResult apply (preplanning.md) + ids via `PreplanPlan.resolve_ids`; `set_input_paused`; local camera current + WeaponVisual viewmodel + mask at Head/Socket (`CrewView`); LocalHudModel `tracked_crew`/`track()`; gamepad look.
- `check_all.sh --env a` PASS (752 tests, 0 failed; validate_level glasshouse PASS).
### In progress
- Next wave: A3-01 + A3-06 specials/piercing/plates/suppression/explosives; A3-02 + A3-03 Brandt/Aegis + director escalation; A3-09 + A3-10 (bag_lift, hack_terminal, OUT_OF_BOUNDS, mission timers, group difficulty weights, escape types, no ladder with bag); animation driver for ENV D's humanoid set (characters.md v1.3). A3-07 co-op after.
### Blocked
- —
### Questions for lead
- QA-21 (crew_intent.md): order routing as implemented: `order_target_net_id` = the AI for follow/hold/drop_bag, the bag for carry_bag, the downed crew for revive; else the AI in the aim cone, else the nearest suitable AI. `order_position == Vector3.ZERO` = "here". Please confirm or add an explicit flag.
- QA-22 (ui_hud.md): add `tracked_crew`/`track(crew)`; custody/trade HUD fields (negotiation_left, auto_release_left, highlighted hostage) are on CustodySystem; add them to LocalHudModel's binding table?
- QA-23 (ENV B for B4-08): `PreplanPlan.resolve_ids(heist_id, ids) -> Dictionary` is called by name; `apply()` should emit the contract keys (old keys still accepted).
- QA-24 (strings for ENV B): ui.blocked.push_bar_outside, ui.prompt.trade_hostage, ui.prompt.convert, ui.prompt.cable_tie, vo.crew.ack_follow/hold/carry_bag/drop_bag/revive.
- QA-25: who sends a remote player's mask descriptor (`CrewView.mask_descriptor`) for custom masks on other peers?
- QA-26: camera collision for ceiling mounts still reaches 7.5 cm above a top-centre pivot; confirm the ceiling convention before I change it.
### Ready for integration
- yes; `check_all.sh --env a` result: PASS

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
