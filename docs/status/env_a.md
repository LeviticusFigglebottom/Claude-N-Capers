# ENV A status: Core Systems & AI

Owner: ENV A. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## 2026-10-13 20:10 UTC — PO-5 (D-086 windowed playthrough), team v3
### Done (pushed to env/a-core; last 097d8432)
- Harness `game/tests/a/e2e/` (po5_runner.tscn, po5_flow.gd, po5_pilot.gd, po5_flow_gh_loud.gd): the real game runs
  windowed (xvfb, NOT --headless). Real menu clicks (InputEventMouseButton at the button's screen position): main menu →
  Safehouse → Planning Table → <heist> → <difficulty> → Briefing → Continue → Confirm plan → Start Heist. In the heist the
  pilot plays through PlayerInputDriver only (mouse motion turns, WASD on a navmesh route, F holds, G masks/throws, opens
  doors on its route, shoots enemies in sight). Every stuck spot is logged (slide colliders + rays + screenshot); telemetry
  every 10 s of game time. llvmpipe draws ~1 fps, so between screenshots the harness sets
  RenderingServer.render_loop_enabled=false (the window and input stay real; game time then runs at ~real time).
  Run: `xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540
  res://tests/a/e2e/po5_runner.tscn -- --po5-flow=gh_loud --po5-out=<dir>` (flows: smoke, dump, gh_loud; gh_stealth WIP).
  KNOWN SHORTCUT: the harness sets Input.mouse_mode=CAPTURED itself (PO-5.1; P's MouseCapture is now on trunk, so recheck).
- Fixes (each has a test): PO-5.2 civilians on the floor don't body-block, and a stalled flee cowers. PO-5.3 the AI leash/cover
  needs line of sight to the leader, and downed bots hold fire. PO-5.8 the Glasshouse drill finish really opens the safe
  (it used to set `opened` only). PO-5.11 casing players can open unlocked doors. PO-5.12 a safe opened by its code completes
  the objective. D-089 LocalHudModel.objective_markers + Glasshouse marker_tags (`loot_secure` tag on the van zones). The loud
  transition skips the keycard step. PO-5.7 NPCs wear ENV D characters (NpcVisuals; specials keep their scene visuals).
### PO-5 rows
| Row | Owner | Status | What / where |
|---|---|---|---|
| PO-5.1 | P | trunk MouseCapture (round 36) | game never captured the mouse; harness still forces it, recheck |
| PO-5.2 | A | fixed, verified windowed | fleeing civilian pinned the player in the workshop doorway (7.5,0,4.0) |
| PO-5.3 | A | fixed, verified windowed | AI took "cover" in the alley through walls, custody by t=169; now they follow into the workshop |
| PO-5.4 | A | open | solo+bots Routine: 31 enemies @t=180, 70 @t=520 (KR-1) |
| PO-5.5/5.6/5.9 | B | routed | no primary (QB-1 yes), objective placeholders, difficulty lock order |
| PO-5.7 | A | fixed, verified windowed | capsule NPCs: EnemyDefs had no visual (wiring) |
| PO-5.8 | A | fixed, verified windowed | drill DONE but safe never opened (mission set opened, Safe ignored the drill) |
| PO-5.10 | A/C | minor | workshop door prompt hidden from a 1.7 m diagonal (wall G_Corridor_N_W_02) |
| PO-5.11 | A | fixed | casing players could not open any unlocked door |
| PO-5.12 | A | fixed | safe opened by its keypad code didn't complete the objective |
| PO-5.13 | A | QA-PO5-2 | all crew permanently TASED from t≈312 (long tase = helpless, no bleedout): soft-lock |
| PO-5.14 | A | open | police stand off for minutes (23 enemies, nobody engages) while crew holds the workshop |
### In progress
- KR-1/KR-2 (test_p3_loud test_01/test_10) subagent; Glasshouse stealth flow subagent; loud run to payday → hub.
### Questions for lead
- QA-PO5-2: helpless (long tase / cloaker) not revived in bleedout_time_s → custody, no down counted? (proposed)
### Ready for integration
- yes for pushed lanes (targeted checks per D-088)

## 2026-10-12 ~18:30 ET: D-082 freeze, PP-A-1, D-085, hand-play attempt
### Done (pushed)
- 86757557 PP-A-1: LocalHudModel.dominate_target (guard net id) / dominate_window_s + dominate_prompt_changed;
  NPC net state carries "dom" so clients see the window (test_s5_8 8/8, hud suites 38/38).
  **Ask ENV B:** render a shout prompt / "!" telegraph while dominate_target != 0. LEAD: add the two
  properties to the ui_hud contract.
- 0dab334e S9.5 trip mine deployable (committed before the D-082 freeze; kept, no further work).
- d57383b6 D-085: CrewAiBrain.offset_corners pushes interior nav corners 0.1 m (CrewAiTweak.corner_margin_m)
  off the turn's inner side. test_d085 2/2, a2_01 10/10, crew_ai 4/4. NOTE: the 0.9 m angled-door test also
  passes with margin 0, so it guards regressions but does not reproduce a stall.
### Frozen (D-082)
- Trip mines + remaining A4-04 keys. defense.interact_damage_taken_mult work is in `git stash` (not committed).
- P4 allowlist (game/tests/integration/test_p4_progression.gd, LEAD-owned): hooked keys the lead may drop:
  interaction.speed_mult, interaction.device_fix_speed_mult, defense.healing_received_mult,
  weapon.fire_rate_mult, defense.bleedout_health_mult, loot.small_loot_value_mult, deploy.trip_mine_radius_mult.
### Blocked
- Round 34 not on trunk yet (origin trunk 64f10747, already merged); docs/process/playability_pass.md absent.
- Hand play: launched `--heist=night_deposit --seed=7` on the box display (:3). Renderer is llvmpipe (software
  Vulkan); after ~100 s in CASING the view never changed with mouse/W input and the HUD read Armor 0 / Health 0 /
  Downs 0 / 0/0 ammo. That may just be a slow first frame, not a bug, so nothing is logged as a game issue.
  The process used 2.8 GB RSS with other envs' tests running, so I stopped it. Real hand play needs a GPU
  machine (Aaron's) or a lighter renderer (e.g. --rendering-driver opengl3 / compatibility) to try next.
- Retry with `--rendering-method gl_compatibility --rendering-driver opengl3` at 960x540: the HUD now fills
  in (Armor 20, Health 230, 3 downs, 17/136, AI 1-3 cards, "Unmasked: casing"), but the 3D world draws
  black (llvmpipe + compatibility), so no AI or interaction play was possible. Things seen, not in A's area:
  - [B] objective line shows the raw text "Secure the bags ({count}/{total})" (placeholders not filled in).
  - [P] the FP weapon viewmodel is drawn while unmasked/casing (PD2: no weapon while casing; CrewView only
    hides it for civilians). Could be intended, worth a P check.
  No A issues logged: guards, civilians, pagers and interact timing still need a GPU session.

## 2026-10-12 19:00 ET: S9.5 doors, phase-2/4 keys, L2.4, fidelity table, A4-04 start
### Done (local; targeted tests PASS under timeout; gdlint clean on changed files)
- ecfc2a9a S9.5/A5-03 doors: Door.charges_required (>0) on CODE/ELECTRONIC/BARRED: place_c4 hold, C4 first else
  trip mines (interaction.shaped_charge), fuse, explosion noise/cue/blast, unlock + open (test_s9_ 26/26, door 23/23).
  Shared Safe.charge_source_for / consume_charges_for.
- d65c8ad5 interaction.speed_mult (all holds), interaction.device_fix_speed_mult (fix_drill), defense.healing_received_mult.
- d5054a2c L2.4 melee hits can be dodged; knockback still applied by NpcGunner (test_l2_4 4/4, a3_13, l4_3, p4_perk).
- a0ba851b docs/status/env_a_fidelity.md: 108 A rows, 90 with a referencing test (scan, not a completeness claim) +
  unconsumed key list.
- (next commit) A4-04: weapon.fire_rate_mult (client + server cadence), defense.bleedout_health_mult,
  loot.small_loot_value_mult (test_a4_keys_phase24 5/5, l3_ 38/38, weapon 25/25).
- Push: 403 until ~19:00 ET; then env/a-core pushed to origin (d65c8ad5..78a6fabd).
### In progress / next
- A4-04: remaining unconsumed keys (env_a_fidelity.md list); ENV P must mirror weapon.fire_rate_mult in fp_viewmodel.
- Trip-mine placement runtime (deployable kind trip_mine); B strings for door place_c4 prompt reuse ui.prompt.place_c4.
- PP-A-1 S5.8 HUD cue; confirm D-079 "domination skill" = ability.intimidate_cops.

## 2026-10-12 18:15 ET: D-079 guard domination range / cone / hostages
### Decisions
- D-079 (lead ruling): dominated guards count as hostages (tradeable), PD2 exactly. Domination range 10 m base,
  x1.5 with the domination skill, x1.25 with Crew Chief (multiplicative). Aim cone half-angle =
  max(8°, linear 90° at 0 m -> 30° at 12 m). Replaces 15 m / 20°.
  - Implementation: ShoutSystem.guard_dominate_range_for / guard_dominate_cone_half_deg; StealthTweak keys.
  - Assumption to confirm: "domination skill" = `ability.intimidate_cops` (Turncoat, the PD2 Dominator analog);
    Crew Chief = `ability.shout_range_mult` (foreman card 3 grants 1.25).
  - Dominated guards were already in G.HOSTAGE, so CustodySystem.hostage_candidates includes them (test added).
### Tests
- test_s5_8 7/7, shout suites 16/16; gdlint clean on all changed files.

## 2026-10-12 18:00 ET: A4-01 queue (L3.3 check, S2.7, S1.1, L2.1, S8.3, S9.5 safes)
### Decisions (lead rulings 2026-10-12)
- L3.3: the server checks a claimed HEAD zone: the point must be within CombatTweak.claim_head_tolerance_m (0.45 m)
  of NpcBase.head_position(), else it is downgraded to BODY before the pellet rule (CombatSystem.validate_head_zones).
- S8.3 / S9.5 follow pd2_fidelity.md + PD2 precedent; where spec and key text disagree the spec wins: camera loop 25 s
  (InteractionTweak.camera_loop_active_s; camera_loop_s 5 s stays the station hold time). Domination stays 15 m / 20°.
### Done (local commits, targeted tests PASS under timeout)
- b33e4bdc L3.3 server head check (test_l3_3 3/3)
- 118c516b S2.7 NpcGunner.target_range_for: lerp(80,180,(DR-3)/72) replaces npc_max_range_m (test_s2_7 1/1)
- 7154507b L2.1 defense.health_regen_per_sec in CrewHealth.server_tick (test_l2_survival 14/14)
- 1101d390 S1.1 InteractableComponent.casing_pickup_item (small_loot) + stealth.casing_can_pickup_items (s1_1 8/8)
- d0969fc0 S8.3 CameraStation loops: nearest working camera, one per crew, 25 s (test_s8_3 1/1)
- a952cc04 S9.5/A5-03 (safes): Safe.charges_required; C4 items first, else trip mines with interaction.shaped_charge;
  DeployableSystem.count_of_kind/consume_kind; fallback deployable.trip_mine (count 3) (test_s9_8 4/4)
- bb0e5905 HeistRuntime defers HeistDropIn.ensure at start ("parent busy" add_child gone; dropin 6/6)
- dadb7b1b P1-02/PI-10 casing hop: _on_crew_masked ignores forced masks (duck-typed `mask_forced`, needs ENV P
  4860fdbc on trunk to take effect). P's test_p1_02_casing_hop 3/3 PASS locally with 4860fdbc applied
  temporarily (P files not committed here).
- Regression: test_s1_2 2/2, test_s8_ 30/30, test_a3_13 4/4, test_s5_8 4/4, test_l3_ 38/38.
- Push of env/a-core: 403 (token issue, lead fixing); commits are local.
- Full check_all was started then stopped per the new lead rule (no result). gdlint is not installed on the box.
- Tests still use set_bot_intent/hold_interact: p_input_driver.gd is not on trunk yet.
### Next
- S9.5 doors (charges_required per door type, place/detonate interaction), trip-mine placement runtime, B strings.
- Phase 2/3/4 modifier keys, L2.4, env_a_fidelity.md, A4-04; Env P casing STEALTH-hop fix in heist_runtime.gd when sent.
- Switch tests to p_input_driver.gd once it is on trunk.

## 2026-10-12 17:50 ET: PLAYABILITY LIST (code reading only, Godot not installed)
### State
- env/a-core = fb517093 + this commit; backup (S5.8, L3.3 local work) and trunk merged. **NOT tested, NOT pushed.**
- PP-A-1..13 in the appendix at the end of this file real-input issues + queue needs.
### In progress
- Nothing running. Exact next step: when Godot is ready run `tools/ci/check_all.sh --env a`; push on PASS
  (D-077 flake waiver applies) once GitHub creds exist on the box.
### Queue (>= 2 h)
1. check_all --env a on the merged tree (S5.8 / L3.3 tests incl.) (~30 min)
2. PP-A-1 S5.8 domination cue + real-input shout test (~1 h)
3. L2.1 regen consumer (PP-A-8) (~45 min)
4. S1.1 casing pickup (PP-A-3) (~1 h)
5. S2.7 DR targeting range (PP-A-9) (~1 h)
6. S8.3 camera loop (PP-A-5) (~1 h)
7. HeistDropIn full/was_kicked verify (PP-A-12), GameRng client audit (PP-A-11)
8. S9.5/A5-03 shaped charges + C4 after LEAD ruling
### Questions for lead
- S8.3 duration: tweak says 5 s, fidelity 25 s, modifier_keys text 20 s. Use 25 s?
- S9.5 vs A5-03: shaped charges (trip mines) and C4 as separate paths?
- PP-A-6: accept client-claimed head zone, or add a server check?

## 2026-10-12: WIND DOWN (A4-01 redo, session stopped by the lead)
### Done
- d2ce45f PUSHED: breech parts test polls (wait_until) instead of wait_frames(20) (lead flake); 3/3 targeted runs pass.
- LOCAL ONLY (not pushed: no full check_all has passed on them yet):
  - S5.8 guard domination (GuardBrain.dominate_window_left / can_be_dominated_by / on_shouted / dominate,
    ShoutSystem.guard_target_for, StealthTweak "Guard domination (S5.8)") + test_s5_8_guard_domination (4/4 pass);
    related suites test_s3_3, test_s7_shout, test_s2_9, test_s5_pagers, test_l5_1 pass.
  - L3.3 pellet headshot (CombatSystem.pellet_headshots, applied in validate_and_apply when pellets > 1)
    + test_l3_3_pellet_headshot (2/2 pass).
### Resume step
- Merge origin trunk a2d82434, run `tools/ci/check_all.sh --env a` (ownership: if origin lags, use
  `python3 tools/ci/check_ownership.py a --base claude/dreamy-hamilton-pc7vck`), push if PASS.
### Next (queue order, per lead; S1.2 + fp_viewmodel finish moved to ENV P by D-076; then A4-04 key hooks)
- S2.7 DR targeting range, S1.1 casing pickup, L2.1 regen, S8.3 camera loop, S9.5 shaped
  charges / A5-03 C4, phase-2/3 keys, L2.4, phase-4 keys, docs/status/env_a_fidelity.md, HeistDropIn `full` +
  Net.was_kicked, anim_driver apply_loadout_finish, escape_arrived [R], client GameRng seeding.
### Notes
- check_all ownership step fails while origin trunk lags the local trunk; use
  `python3 tools/ci/check_ownership.py a --base claude/dreamy-hamilton-pc7vck` (D-076).

## 2026-10-11 14:30 UTC: HANDOFF (session shut down by the lead; account move)
### State
- Pushed: env/a-core = 112c7f3 (round 28 content). Nothing newer is on origin.
- NOT pushed (local only in the archived session, 76 commits, HEAD 8784a092, trunk round 30 79f7a67 merged):
  - A4-01 gap fixes with tests: S5.8 guard domination, S2.7 DR target range, L3.3 pellet headshot, S1.2 mask slow-mo,
    S1.1 casing pickup, L2.4 melee dodge, L2.1 regen, S8.3 camera loop, S3.5 alert tone, S9.3 fix-speed mult,
    phase-2 keys, S9.1/S9.2 tests; env_a_fidelity.md updated (100 ✅ / 15 partial / 3 missing).
  - A4-02 perf instrumentation (PerfStats/PerfProbe/PerfTail) + test_a4_02_perf; CrewHealth/CrewPerks max refresh throttled.
  - A4-03 soak harness game/tests/a/soak/ (host + 3 loopback clients with bots, windowed state-capture desync,
    memory/orphan/error gates; CLI soak_host.tscn) + test_a4_03_soak (45 s: 0 desyncs, 0 errors).
  - HeistDropIn full/was_kicked/live policy, AnimDriver v1.9 hints, B7-03 weapon finish hook, untextured_ok on prefab
    runtime materials, CrewController ignores intent RPCs out of the tree.
- Last check_all on 8784a092: 1648 tests 0 failed, gdlint/banned/ownership/validate_level all PASS, but CHECK_ALL printed
  FAIL (step not identified before shutdown), so it was not pushed per the lead's rule.
### For the next ENV A session
- That local work is not recoverable from origin; redo from the A4 dispatch using this list (designs in the fidelity audit).
- Open questions: S4.1 hack stimulus vs D-040; S9.5/A5-03 shaped charges + C4; camera loop = all feeds from the station.
- Clients already seed GameRng with the run seed (HeistRuntime._start_replica). escape_arrived [R] still to propose.

## 2026-10-11 13:00 UTC: A3-13 enemy melee, heister bodies, round 23
### Done
- Pushed fd51e2d and a2bd853: heister third-person bodies (CrewTweak.body_scenes by Loadout.heister), answer_join reason (B f46b038), infiltrator chain in CrewMelee.
- A3-13 enemy close-range melee (NpcGunner): non-special NPCs within npc_melee_range_m strike instead of shooting.
  - Windup, then one MELEE hit of npc_melee_damage[difficulty]; the shove cancels a reload; cooldown between strikes.
  - `defense.melee_counter`: a crew member charging or swinging a melee knocks the unit down and takes nothing.
  - `defense.melee_damage_taken_mult` (CrewHealth) scales the hit.
  - Tests pass, P3 gate 10/10.
- Trunk round 23 (1d053f8) merged.
### Ready for integration
- yes after this entry's clean check_all (result in the lead message).

## 2026-10-11 11:30 UTC: A3-12 melee + throwables, D-069 item FP clips, characters v1.8
### Done
- A3-12 / L3.9 melee (CrewMelee, child `Melee` of the crew):
  - quick swing (MeleeDef.damage) vs charged swing (lerps to charged_damage over charge_time_s / weapon.melee_charge_speed_mult);
  - gun bash without a melee item (CombatTweak bash_*);
  - strike at hit_delay_s on the nearest target in a melee_cone_deg cone with LOS (server);
  - knockdown chance × weapon.melee_knockdown_mult (stun), Bulwark stagger with weapon.shield_knockback, bloodthirst;
  - silent: a stealth melee kill alarms nobody;
  - no melee while casing/downed; a swing cancels a reload; no shooting mid-melee.
- A3-12 throwables (CrewThrowables `Throwables` + ThrownItem, replicated under dynamic_root):
  - frag: fuse → Explosion.apply + noise;
  - concussion: stun in radius with LOS, no damage unless `damage` > 0;
  - incendiary: fire pool on first contact, sets NPCs burning (BurnStatus);
  - throwing_knife: one MELEE hit;
  - a throw takes one from throwable_count, synced to a remote owner (`CrewThrowables.set_count`, also used by ammo pickups);
  - perk-deck flask/injector stay with PerkThrowable;
  - tunables in CombatTweak "Throwables (A3-12)" (◇).
- D-069 FP item clips in FpViewmodel:
  - melee `charge_start` (charged@ on the full charge) → `charge` loop → `swing`/`charge_swing` with hit@ on the gameplay strike;
  - `<set>/bash` with hit@ on the bash strike;
  - deploy `place` with place@ on the deploy hold time (release cancels);
  - throwable `draw` → `throw`/`throw_low` with release@ on the gameplay release; the Pin hides at pin_pull@ and the item at the release;
  - the item model (`model`) replaces the gun during the one-shot.
- characters v1.8:
  - FP heister sleeves: `crew.heister` comes from the Net.crew info `heister` or the launch option `heisters` {slot: id}; FpViewmodelTweak.sleeve_scenes copies the variant's Arms mesh + skin;
  - AnimDriver plays `rappel` while NpcMotor.rappelling (fallback climb_ladder → idle).
- A3-11 hub (QC-43/44):
  - `CrewController.spawn_for_hub`: civilian, unmasked, no weapon drawn (CrewView hides the viewmodel while civilian), own `HubInteraction` InteractionSystem, HUD prompt via `LocalHudModel.track(crew)`;
  - `hub_station` prefab, class `HubStationPrefab` (B's `HubStation` resource owns that name): group `hub_station`, instant press, civilian + casing allowed, `station_used(id, crew)` / `station_requested(id)`.
- QB-B6-02 (D-071): CrewStats service owns the per-crew counters (kills, specials, civilians, downs, plus new shots / hits / headshots per ui_hud v1.7 rules), replicated in the services state. Adds `LocalHudModel.crew_stats` + `crew_stats_changed` and HeistResult crew `name/shots/hits/headshots`.
- D-070:
  - crossbow StringUpper/StringLower latch (−/+18.74°, ×1.3049 Y, held while loaded);
  - bow pull-back sign fixed;
  - Speedloader shown only while reloading;
  - Bulwark takes near-side anchors only;
  - CrewAiBrain drops out-of-tree targets;
  - rappel speed 2.5 m/s (D's clip).
- Melee per lead: knockdown only on charged hits; specials resist it.
- Fixes: the round-18 merge took the old test_s1_3 (restored the D-065 assert); a3_07 polls until `launch_client()` has returned.
- Trunk round 21 (f94d2b6) merged.
- Round 21 follow-ups:
  - FP sleeves read `Loadout.heister` (D-073; carried in the net loadout dict); the launch-option / Net.crew fallback is gone;
  - nothing under the local camera casts shadows (FP weapon rails on the sleeves);
  - audio_cues v1.3 throwable cues: pin, frag, concussion, incendiary + `_incendiary_fire` loop (a CueEmitter on the pool, every peer), knife hit / hit_hard by target;
  - my stats service is `CrewStatsService` (B's `CrewStats` owns the name).
- QB-B6-DROPIN: `HeistDropIn` (extends B's DropInService, node `/root/DropIn`, group G.DROP_IN_SERVICE, `HeistDropIn.ensure(tree)`):
  - host: policy ask / auto / off; checks running heist, slot (full), kicked names, `LobbyState.validate_summary`;
  - accept: the slot's AI crew member becomes the peer's (loadout + modifiers re-pushed, name, CrewAiBrain removed), then a bring-up addressed to the peer (`HeistNetSync.late_bring_up`, `for_peer`; others ignore it);
  - `kick(slot)` uses `Net.kick`; any human leaving mid-heist turns back into an AI teammate (crew_member_left [R]);
  - crew codec replicates owner / AI / name;
  - client entry: `Net.join(...)`, then on `Net.connected_to_host` call `HeistDropIn.ensure(get_tree()).request_join(LobbyState.summary_from(...))`;
  - tests: in-process host logic, plus a two-process loopback drop-in (the client connects after launch).
### Ready for integration
- yes; `check_all.sh --env a` on 578e238 (clean worktree): PASS, 1508 tests, 0 failed, 5 skipped. This entry's later commits are checked before their push.
### Questions for lead
- (answered: Loadout.heister in D-073; throwable cues in audio_cues v1.3; ThrowableDefs coming from B.)

## 2026-10-11 08:30 UTC: round-16 follow-ups, options hooks, D-069 FP left-hand IK, D-063 clean
### Done
- Civilian strings (`ui.prompt.pick_up_gear`, `ui.blocked.civilian`). AI teammates gear up with the first human (P5 ruling, heist README). The lead's `hud_model.refresh()` hotfix is merged (it was the same fix).
- D-068:
  - `loot.<id>` pre-plan drop kinds spawn a LootBag;
  - burn_point also uses a thermite bag lying within burn_bag_radius_m;
  - tool loot (`LootDef.is_tool`) is never secured (`LootManager.is_tool_loot`).
- B5-01 options:
  - CrewView FOV = GameSettings.fov() every frame, with ADS zoom fov / magnification (ads_zoom_rate);
  - PlayerInput: mouse sensitivity x/y, invert_y (mouse + pad), pad sensitivity / deadzone;
  - hold/toggle for aim/crouch/sprint with its own edge detection: intents are built on physics ticks, so just_pressed missed presses; a toggled sprint ends when not running forward.
- D-069:
  - crew camera near 0.02 m;
  - FP left-hand IK (FpLeftHandIk, TwoBoneIK3D upper_arm.L → hand.L) to a `LeftHandGrip` child of the weapon's `LeftHandIK` at left_hand_grip_offset (wrist vs palm, measured from D's baked rifle pose on four guns);
  - off during reload/swap and for bow/akimbo; test: hand within 1.5 cm.
- D-063 re-measured after D's rebuild (bfde340): no weapon is outside 0.75–1.35×.
### In progress / waiting on trunk
- D-069 item FP sets (melee swing/charge hit@, throwable pin_pull/release + Pin hide, deployable place@) and `<set>_bash` hit@: the clips and the `anim_set` fields on Melee/Throwable/DeployableDef are not on trunk yet.
- AnimDriver HINT_CLIPS for D's NPC ambient anims (4355913) once on trunk. A3-11 hub (QC-43/44) after that.

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

## Appendix: ENV A playability issue list (real input vs bot shortcuts)

Owner: ENV A. Written 2026-10-12 ~17:50 ET by **code reading only** on env/a-core fb517093
(Godot not installed on the box: nothing below has been run; every item is a hypothesis to confirm with a
real-input test per D-076). Severity: **H** breaks play, **M** feels wrong / confusing, **L** polish.
Scope: ENV A-owned paths (tools/ci/owners.json: game/systems/** minus player/, fp_viewmodel*, crew_tweak.*).

### 1. Stealth / detection / guard AI
| # | Sev | Issue | Evidence (code) | Needs |
|---|-----|-------|-----------------|-------|
| PP-A-1 | H | **S5.8 domination window is 1.5 s with no player-facing cue.** The window opens in `GuardBrain._on_crew_spotted` (the "!" moment), but nothing in hud_model/anim reads `dominate_window_left`; a human gets no prompt/telegraph and must also aim within a 20° half-cone at 15 m (`ShoutSystem.guard_target_for`, aim from `crew.aim_direction()`). Bots call the API directly; humans will almost always miss it. | guard_brain.gd:616-618, shout_system.gd:142-162, stealth_tweak.gd:179-183 | HUD hint (LocalHudModel field + B prompt string), check shout key path from PlayerInput → server uses the server-side aim; real-input test: walk into view, press shout. |
| PP-A-2 | M | S5.8 window only opens when the guard was not ALARMED/COMBAT, and `_begin_alarm` runs right after on the same call; confirm the guard's radio/pager timeline leaves the 1.5 s usable (domination must cancel the radio call, `dominate()` sets DOMINATED). Also verify `dominate_window_left` is server-only (clients' shout goes via intent RPC; no replication needed if the check is server-side). | guard_brain.gd:479-500, 616-622 | Two-process test: client shouts at a spotting guard. |
| PP-A-3 | H | **S1.1 casing pickups not implemented**: `stealth.casing_can_pickup_items` exists in modifier_keys and in B's plain_sight skill, but nothing in game/systems reads it, so a player with the skill still can't grab small loot while casing. | modifier_keys.gd:24; no consumer in game/systems | Gate in InteractionSystem/LootManager `casing_allowed` path + test. |
| PP-A-4 | M | Casing detection (S1.1/S2.8) is tuned on bot positions; real players linger, strafe and peek. The "within 3 m outside PUBLIC" and ×0.35 fill need a hand-play check at doorways/zone edges (zone boundary flicker could pulse the meter). Casing → alarm STEALTH hop is ENV P's (P1-02) but the alarm side (StealthDirector state change) is mine; coordinate. | stealth/* | Joint test with P1-02. |
| PP-A-5 | M | **S8.3 camera loop is only a hook**: `CameraStation.loop_requested` is emitted, nobody listens; `InteractionTweak.camera_loop_s = 5.0` vs spec 25 s (modifier_keys text says 20 s). A Light Fingers player sees a prompt that does nothing. | camera_station.gd:25,254-256; interaction_tweak.gd:31 | Implement per-camera loop (one at a time per crew) via `SecurityCamera.set_suppressed`, fix the 25 s value + key text (key text is LEAD's contracts file → ask). |

### 2. Combat / damage
| # | Sev | Issue | Evidence | Needs |
|---|-----|-------|----------|-------|
| PP-A-6 | M | **L3.3 pellet headshots trust the client's claimed `zone`.** `_apply_hit` checks distance/target tolerance/LOS but never re-validates HEAD vs BODY; `pellet_headshots` then upgrades every pellet on that target. Fine for honest co-op but a client with lag/misaligned hitboxes (remote NPC interpolation) will get or lose headshots inconsistently. | combat_system.gd:62,125-160 | Server-side head-zone sanity check (head bone/height tolerance) or accept & document. |
| PP-A-7 | M | `claim_target_tolerance_m` / `claim_distance_tolerance_m` were tuned with bots that stand still. Real strafing + client interpolation of NPCs may reject legit hits ("my shots don't register"). | combat_system.gd:_apply_hit | Real-input loopback test with moving NPC; log rejection reasons in PerfStats/debug HUD. |
| PP-A-8 | H | **L2.1 regen**: `defense.health_regen_per_sec` is declared but has no consumer in CrewHealth (base no-regen is tested by test_l2_1_no_health_regen). Skills/perks that grant regen silently do nothing. | modifier_keys.gd:80; no consumer | CrewHealth tick: regen fraction × max while not downed, server-side, replicated with existing health sync; test. |
| PP-A-9 | M | **S2.7 DR loud targeting range not implemented** (no `ai_target_range` anywhere). Police engage at a fixed range regardless of DR, so low-DR players get sniped across maps / high-DR cannot be engaged far. | no symbol in game/systems | `ai_target_range = lerp(80,180,(DR−3)/72)` in NpcGunner/PoliceBrain target pick; test at both ends. |
| PP-A-10 | L | Spread/recoil use shared GameRng streams (`&"spread"`, `&"recoil"`) consumed by the local client; harmless (claims carry results) but means GameRng streams diverge between peers by design. See §3. | crew_weapons.gd:524-587 | Document. |

### 3. Net / drop-in / RNG
| # | Sev | Issue | Evidence | Needs |
|---|-----|-------|----------|-------|
| PP-A-11 | M | **GameRng client seeding**: clients call `GameRng.begin_run(run_seed)` in `_start_replica`, which clears streams, so a client has the same seed but **not the same stream positions** as the host (especially drop-in). Anything a client rolls locally that should match the host (cosmetic or gameplay) will differ. | heist_runtime.gd:221, game_rng.gd:11-14 | Audit client-side `GameRng.stream()` callers; either keep all gameplay rolls server-only (assert) or ship stream positions in the bring-up. |
| PP-A-12 | H | **HeistDropIn `full` + `Net.was_kicked`** policy: the handoff lists them as lost local work; Net.was_kicked exists in core, REASON_FULL in B's DropInService, but the host-side policy needs re-verifying on this tree with a real second client (two-process). | net.gd:217; drop_in_service.gd:42 | Redo/verify + loopback test. |
| PP-A-13 | M | Not-replicated state from QA-20 notes: placed deployables, known codes, pre-plan drops and **interaction progress bars on remote clients** — a joining or remote human sees a teammate drilling with no bar. Re-check what A3-07 covered. | status 2026-10-10 notes | Audit + fix list. |

### 4. Queue items and what each needs
- **S2.7** DR targeting range: implement formula in police target acquisition; tweak keys; test DR 3 vs 75 (≈1 h).
- **S1.1** casing pickup: consumer for `stealth.casing_can_pickup_items` on small loot/items; HUD "Suspicious actions not allowed" still for the rest; test with real walk-up + interact (≈1 h).
- **L2.1** regen: CrewHealth consumer for `defense.health_regen_per_sec`, not while downed/custody; test (≈45 min).
- **S8.3** camera loop: listen to `loop_requested`, loop one camera per crew for 25 s, fix tweak 5.0 → 25.0, ask LEAD about the 20 s key text (≈1 h).
- **S9.5 / A5-03** shaped charges + C4: `interaction.shaped_charge` and trip-mine counts exist in B data, but no trip-mine-as-charge interaction or prefab `charges_required` consumer exists; Safe already has a `c4` method. Open question from the 2026-10-11 handoff (shaped charges vs C4 split) needs a LEAD ruling before coding (≈2 h after ruling).

### 5. Not verified (needs Godot)
Everything above. The local S5.8 and L3.3 tests (test_s5_8_guard_domination, test_l3_3_pellet_headshot) are present
but have not been run on fb517093.

## Headless playability audit (Glasshouse, Night Deposit), test_pp_audit_maps.gd

| Row | Map | Finding | Owner | State |
|---|---|---|---|---|
| PP-A-AUD-1 | both | ATM (small_loot behind drill_point) cash could be taken before sawing/while casing | A | FIXED c9f6d186 (test_pp_small_loot_behind_device) |
| PP-A-AUD-2 | Glasshouse | Slot_kc_breakroom Keycard sits ~0.29 m inside Props/U1/Lockers_1 collision, so you can't aim at it from its UsePoint | C | OPEN (map fix) |
| PP-A-AUD-3 | Glasshouse | "Pager can't be aimed from 1.2 m": an audit artifact. The +Z teleport put the crew outside ExtSouthOut_40, with the wall blocking LOS. From the clear side it aims fine and gets answered (civilian brains frozen in that segment, since otherwise civilian 59 correctly calls it in). No A code change | A | CLOSED (audit fix) |
| PP-A-AUD-4 | both | Detection at 6 m: Glasshouse 2.9 s, Night Deposit 1.8 s to ALARMED. Pager starts at 3.7 s, answered within the window, max=4 | A | OK |
| PP-A-AUD-5 | both | Domination end to end (shout, cuff, hostage) | A | OK |
| PP-A-AUD-6 | both | Civilian intimidate + tie OK. The first failure came from the audit itself (0.8 s shout cooldown and rising edge right after domination), not a game bug | A | OK |
| PP-A-AUD-7 | both | All doors are 0.90 m, which the D-085 0.9 m angled-door follower test covers. No real-map follower run yet | A | OK (covered) |

## Anim fixes (lead priority)
* The first clip snaps in with blend 0, so spawns no longer fade in from the A-pose. Above strafe_max_mps (2.2), movement relative to facing picks run_l / run_r / run_b (falling back to run), so crew no longer moonwalk at 3.5 m/s. Tests: test_first_clip_has_no_fade_in, test_directional_run_above_strafe_speed (17/17 in test_anim_driver). Commit c9d4dd98.

## P handoffs (lead-allowed under D-082)
* B5-01: applied P's patch `test_b5_01_mask_before_ads.patch`. The test now masks before ADS, per the lead's ruling that ADS stays blocked while unmasked. test_b5_01_options_hooks 3/3. Commit 1b5eb843.
* S9.8: `Safe._inner_loot()` counted the safe's own child DrillPoint (Glasshouse WorkshopSafe/SafeDrill) as loot and disabled it, so the safe could never be drilled. It now skips DrillPoint nodes. New test test_child_drill_point_drills_safe_and_unlocks_loot (place, fix jams, safe opens, inner loot enabled) fails before the fix and passes after. test_s9_8_safes 5/5. Commit ddda749e.

## PP-A-1 / PP-A-2 (real input), 2026-10-12 ~19:55 ET
* P's PInputDriver is NOT on trunk; trunk db22c24c was only the docs merge, merged --no-ff as 488e7685. So PP-A-1 is an A-owned driver, `game/tests/a/util/player_input_driver.gd` (PlayerInputDriver). Input goes only through Input.parse_input_event (actions, keys, mouse motion), with mouse-look aim (turn_to / aim_at), capture_mouse() + PlayerInput.test_assume_captured (probed, so it works once P's hook lands), and release_all() in after_each.
* test_pp_a1_player_input_driver: on env/a-core 4 pass, 1 SKIP. mouse_look_aims skips because trunk PlayerInput has no test_assume_captured and headless ignores capture. In a scratch tree with env/p-play's game/systems/player overlaid (not committed): 5/5 pass.
* test_pp_a2_real_domination (PP-A-2): the crew walks up by input, masks by input, waits for the guard's "!", then a real shout tap. The guard is DOMINATED, kneel_cuffed, guard_dominated(slot 0), in G.HOSTAGE, and the hostage count rises. D-079 range and cone are asserted. Control test: with no skill, the guard is not dominated. 2/2 on env/a-core (no mouse-look needed: the map's spawn poses face the guard) and 2/2 in scratch. No teleports or intents. Setup is only the map spawn poses and the domination skill modifier.
* Post-merge targeted (488e7685): anim_driver 17/17, s9_8_safes 5/5, b5_01 3/3, pp_ 6/6, d085 2/2, s5_8 8/8, s7_shout_and_ties 9/9.
