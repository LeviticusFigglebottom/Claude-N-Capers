# ENV A status: Core Systems & AI

Owner: ENV A. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## 2026-10-16 04:00 UTC: PO6 done, D-115 / D-118 / X-3 / X-4 / X-5 closed (env/a-core f450497c)
### Done (pushed; on trunk through c07f7e69, round 223 has 37bf88f9)
- PO6-01..08, 14..20 (+17b) A-side; D-115 DB-2/3/4/8/12/13/16/17, SL-5/9, QC-36 TODO; D-117 mission VO.
- D-118: CrewWeapons gadget_on / gadget_changed (net "gd"), 3P CrewGadgetVisual, shotgun AMMO runtime
  (ShotgunAmmo; per-shot damage preserved), gadget detection behind StealthTweak (0 by default, S4.2).
- D-cast: heist_tag_characters for GH/ND/DB/SL/GN (GN 1:1 from p5_cast v4), looks dealt round-robin per tag and
  replicated (spawn "look"), HandProps on clip, roster activities, HardHatHandLift (D audit R1).
- X-3 per-heist assault events at C markers (test_x3_*); X-4 stealth e2e ND/SL/GN + forced GN curator-keycard
  (test_x4_*; HeistRuntime options["variant_table"] dev hook); escape objective completes before heist_ended.
- X-5: GH doorway back_off latch, push-slot by net_id, nav-radius doorway test, staff return to marks, seated
  aliases stand without a seat.
- B facts: HeistResult.loot_available, safe / cage objective data open_method.
### Open
- test_x5_gh_police_do_not_park_under_the_crew_upstairs fails ~1 in 3 inside the full `police` filter (passes
  alone): order-dependent leak, bisect lane running.
- Backlog: GN loud pilot probe (below, HANDOFF 2026-10-14), ND loud gate attempt 24 (empty box only), co-op
  ghost rounds, escape vehicles, split HeistRuntime.start(), Stinger cap check.

## 2026-10-15 23:10 UTC: D-115 mission audit, Dockside Burn + Shadow Ledger (read-only)
Owners: A = mission script/systems, B = content, C = map/props/generator. Severity in brackets.
### Dockside Burn
- DB-1 [blocker] no assault events (no AssaultEvents/ markers, empty HeistDef.assault_events). C markers + rows; A verifies runner.
- DB-2 [major, A] loot.contraband counts toward the 4 required bags (doc: pays, does not count). Fix: count cash_bricks + weapon_crate only.
- DB-3 [major, A] cartel reinforcements spawn as ordinary guards (heist_mission.spawn_guards ignores the `cartel` spawn tag). Fix in shared spawn_guards.
- DB-4 [major, C+A] thermite bag fixed at the gate; should start at the chosen spawn (lane / pontoon). C adds bags per spawn, A enables the matching one.
- DB-5 [major, C] count-room cage drill 180 s (LARGE) vs doc 120 s. C size MEDIUM, or A per-safe drill_duration_s override.
- DB-6 [major, A] briefing lines replay in-mission (D-117 §6): VO lane.
- DB-7 [major, C] no music stems.
- DB-8..19 [minor]: placed-saw padlock times (doc vs data, LEAD), brass padlock tell (C), fog_lifts S3 perch timing (A+C, = QC-25), harbor_unit P4 (C doc), cartel body-sighting wake (A), sniper line by perch (A), MC push bar (C), OC double door (C), [containers] optional flag (A), [cartel] kill count includes civilians (A), lift breaker stand-in (C G2), ambience/LUT (C).
### Shadow Ledger
- SL-1 [major, A+C] cage saw 180 s vs doc 90 s. A: Safe saw_duration_s override; C sets 90.
- SL-2 [major, A] camera_warning never said: VO lane.
- SL-3 [major, C] literal briefing string in def (D-117 §4).
- SL-4 [major, C] no music stems.
- SL-5..11 [minor]: [drives] completes only at 3 (doc: 2 required, A), cage_left_open requires at effects level (B/C), E3 escape zone small (C), escape name lift vs service_lift (doc), lasers line late (A), SL assault events N/A stealth-only (LEAD), ambience/LUT (C).

## HANDOFF 2026-10-14
**Branch head:** code head 4f11fb91 (`[QB-58]` runtime deployable skill gate), plus this handoff commit on top.
Everything up to 4f11fb91 is on trunk (round 199, 95f6b5bc); env/a-core has no unmerged code.

**Done since last trunk merge (not yet on trunk):** nothing beyond this status file. Last rounds (196/199, all on trunk):
- 74aa7d36 [PO-12]: the zipline cable is drawn only when both `cable_start` and `cable_end` are set (meta lc_ignore,
  honoured by C's levelcheck 67d38666). Also FLAG_STRONG = EventBus.SHOT_FX_STRONG.
- 70208a8b [D-113]: BloodFx emits the real EventBus.blood_hit / bleed_changed (events.md v1.3); the test shim is gone.
- 4f11fb91 [QB-58]: `DeployableSystem._gate_ok` checks DeployableGate.required_flag at spawn, so a stale save gets
  no gated unit.
- Green before push: validate_all PASS on all 5 maps. Unit tests 0 failed: l2_ 51, l2_11 6, a1_08 9, s5_ 27,
  s6_ 12, po8_shot_fx 10, c_equipment_hooks 2, anim_driver 26, crew_ai 5, gn_ 36, d113 2, qb56_61 14.
  Integration test_p3_loud 10, 0 failed.

**In progress:**
- **GN loud e2e (GN-A1, D-103):** ~60%. No code pending. Probe 3 (seed 1792002290, auto_loud, windowed) ran to
  t≈640 and was stopped for this handoff. From t≈491 the pilot retries
  `Variants/Group_canvas_orchard/Slot_orchard_calloway/Canvas` (bag_loot), which it cannot path to (13.5 m away,
  "could not reach", FAILED after 30 s, repeated). The crew stands still at (13.9, 5.4, 14.4) with 8 enemies within
  15 m.
  - Next step: in game/tests/a/e2e/po5_flow_auto_loud.gd `_pick`, apply the STALL_SKIP_S skip to bag_loot targets
    that fail "could not reach" (blacklist the target node for the run, not the objective). Then check whether
    Slot_orchard_calloway is reachable at all in nav (if not, it is ENV C's: nav/stairs to that gallery).
  - Log: scratchpad gn_loud_probe3.log, lost with the container. Re-run with
    `game/tests/a/e2e/run_po5.sh auto_loud 1792002290 900 <out> "Gallery Night"`.
- **GN stealth e2e:** not started (needs a gn_stealth flow; po5_flow_auto_stealth plus GN objectives).

**Queued next (ordered):**
1. GN loud probe fix above, then gn_stealth flow (D-103 GN-A1, docs/levels/gallery_night/*).
2. P's GN finding (c): crew stacking recheck in GN corridors (seed 1792002290). Also P's re-run list: transit
   single-file ≥1 m, ≥0.6 m personal radius around humans, ND police overlap 0.23 m.
3. ND loud gate attempt 24 (attempt 23 reached t=710, budget-limited). NOT started, per the handoff order; run only
   on an otherwise empty box.
4. Backlog: co-op full-auto "ghost rounds" (P PO-13(e)); escape vehicles (van drive / heli rotors); split
   HeistRuntime.start() across frames; GH G2 jeweler bench marker shift (po9_dressing_audit.md); Stinger cap /
   tase cooldown check vs PD2.

**Cross-env dependencies:**
- I wait on the lead for:
  - the `&"sensor"` alarm reason in events.md;
  - GN camera operator spawn tag (B1 wants gallery_guard_b);
  - whether AS vault doors allow courier NPC authorisation.
- I wait on ENV D: `prop_saw_device` (DrillPoint uses it for Device.SAW when present).
- Others wait on me for:
  - ENV C: nothing open (D-113 done; C uses blood_hit first, flags as the fallback);
  - ENV B: nothing open (gate done).
  - ENV C also places SL zipline anchors so the cable clears geometry.

**How to validate your area:**
- `gdlint <changed files>`; `python3 tools/ci/check_ownership.py a`; `python3 tools/ci/check_banned.py` (no
  `res://world/` in systems: use G.PROPS_DIR).
- `tools/ci/run_tests.sh a <filter>` (l2_, a1_08, s5_, s6_, po8_shot_fx, anim_driver, crew_ai, gn_, d113,
  qb56_61, ...), `tools/ci/run_tests.sh integration test_p3_loud`.
- Level-affecting changes: `bash tools/levelcheck/validate_all.sh` (5 maps, ~5 min). It rewrites
  docs/levels/*/validation.md + walkthrough.md, so run `git checkout -- docs/` before committing.
- Windowed: `game/tests/a/e2e/run_po5.sh <flow> <seed> <budget_s> <out_dir> "<Heist>"` (flows: stealth, auto_loud,
  ...); run.log in out_dir has TEL lines + pilot decisions; captures are PNGs. Max 2 windowed Godot at once.

**Gotchas:**
- New `class_name` scripts need `/opt/godot/godot --headless --path game --import` before tests see them.
- The test framework has no assert_null: use `assert_true(x == null)`.
- Never `pkill -f` / `pgrep -f` with a pattern that matches your own shell (it kills the tool shell, exit 144).
  Kill only exact PIDs from `pgrep -x godot` after checking `ps -o args=`.
- The S3.6 one-shot-unalerted rule kills guards in tests: `set_alert_state(COMBAT)` first when testing damage.
- llvmpipe windowed runs: 2 s hitches on first scene/material use (assault_director, npc_gunner). TEL
  worst_frame spikes are not game logic.
- Leaked ObjectDB / RID warnings at test exit are noise; check the `== N tests, 0 failed` line and SCRIPT ERROR.
- `CrewWeapons` `stats.wall_pierce` is a bool.
- EventBus signals must exist before `Net.replicate_event` (lead-owned core/).

**Session id:** session_015kTjrZsUFn7gLqNVwAXdkh (ENV A). Helper lanes running: none. Worktrees: none. Background
runs: none (GN probe 3 stopped, ND attempt 24 not started).

## 2026-10-14 15:45 UTC — GN-A1 groundwork APIs (D-103 §6), ND loud gate attempts 9–22
### Done (pushed; last 5a67111e)
- GN-A1 APIs, each with a unit test (test_gn_*):
  - Door.relock(lock, close) (replicated `lk`).
  - KeycardReader.set_disabled.
  - LaserGrid.set_enabled / enabled_at_start.
  - AlarmGroups + LootSpawn.alarm_on_take/alarm_group (&"sensor").
  - HackTerminal clears_alarm_group + reconfigure.
  - LootSpawn prompt_key / cut_painting prompt.
  - HeistMission.set_zone_kind (ZoneKinds, replicated) + civilians_leave(exit_tag) (QC-51).
  - KeycardPickup.carrier_tag (QC-52).
  - Staff civilians honour Door.npc_authorized_tags.
- ND loud harness and game fixes (attempts 9–22):
  - BulwarkShield lies flat when dropped.
  - Rare events honour `requires`/`excludes`.
  - NpcMotor separation cost / retire on death.
  - AI formation slots + loud leash.
  - Bot cover/LOS.
  - Per-objective HUD markers.
### In progress (local, tests pending a free box)
- NpcVisuals tag-first resolution + NpcVisualTweak.heist_tag_characters (gallery_night map, B1 list). This is heist-scoped
  because ND already uses guard_hall / guard_rover_*.
- Ambient clips: cower_seated (seated civilians cower in their seat), cower_stand at PatrolPoints tagged `cower`,
  walk_text (`text` activity), curator_inspect (`inspect`).
### Needs
- `&"sensor"` alarm reason in docs/contracts/events.md (lead).
- GN SC camera operator: which spawn tag? (B1 wants gallery_guard_b; security_operator maps to security_officer).
- AS vault door courier authorisation: VAULT locks still exclude NPC authorisation (lead to rule).
### Perf note (ND loud windowed FrameProf)
- There are single-call game-side hitches: assault_director 3–10 s per spawn burst and npc_gunner 7–10 s. They are likely first-use scene loads
  or material compiles under llvmpipe. Candidate: warm the heist's enemy / character / FX scenes at load.

## 2026-10-14 05:25 UTC — D-108 police arrest timing (last freeze gate)
### Done
- D-108: police cuff a downed player only after `CustodyTweak.police_cuff_grace_s` (2.0 s) down without firing
  (CrewHealth.down_s, min with last shot age), then hold `police_cuff_time_s` (1.5 s) at cuff range; the player
  firing, or the cop being hurt / stunned, restarts the hold. Tests: test_l2_12_police_cuffs 8/8.
### pd2_fidelity note for the lead (L2.12)
- L2.12 should read: "Police arrest a downed heister who is not shooting: after 2 s down without firing, a cop at
  arm's length holds a 1.5 s arrest; firing from the floor or hurting / stunning the cop interrupts it (◇ timings)."
- S1.1 (PO-11): while unmasked a shout only marks (stealth.casing_can_mark); it never intimidates civilians.

## 2026-10-14 05:00 UTC — PO-12 drills visible, C11, director retreat, ND/stealth gates in progress
### Done (pushed; last 0f1bf19c)
- PO-12: DrillPoint shows the catalog drill (G.PROPS_DIR + drill/prop_drill_device.tscn) while placed; Bit spins,
  red jam mark, removed when done; per-point `device_scene` override.
- C11: two co-op heists on one kept session (teardown notices, heist token, replication member set, Net.clear_ai).
- PO-5: FADE retreat to unseen points; PO-B-C7 client objectives; QC-61 walkable windows + sash_travel_m;
  Glasshouse drill_relock min difficulty; loud flows shoot while downed.
### Needs (for the board / ENV D)
- SAW device prop: saw DrillPoints have no default device visual yet (only the drill exists); ENV D to model
  `prop_saw_device` with a spinning `Bit`/blade node, then DrillPoint uses it for Device.SAW.
### In progress
- ND loud attempt 8 (windowed); gh_stealth iteration (helper); PO-10 NPC separation + PO-11 casing civilians (helpers).

## 2026-10-14 04:05 UTC — civilian fixes for the stealth gate (wander, stairs, shout, yield)
### Done (pushed)
- Civilian wander (PO-5 stealth finding 1): customers pick only public `civilian` PatrolPoints outside
  RESTRICTED / NO_CIVILIAN zones; staff only `staff` points of their home area (staff_floor / staff_boh /
  staff_upper); reach = navmesh path length within civilian_wander_radius_m (same-floor fallback).
- NPC stairs (finding 2): NpcMotor step-up (step_height 0.35), wall_min_slide 0 deg, corner_reach 0.2 m (no
  corner cutting into balustrade/wall ends): no NPC could climb the GH stair before. Walking civilians that
  stall re-path, then give the target up (civilian_walk_stall_*). GH map issue logged for C (ramp colliders).
- Calm NPCs yield (finding 5): a calm civilian/guard that a crew member presses into for 1.5 s steps 1 m
  aside, then returns (StealthTweak npc_yield_*); never while alerted / dominated / tied.
### For pd2_fidelity (lead to record)
- Crew shout (all-round 6 m): affects only civilians on the shouter's floor (|dy| <= shout_floor_dy_m 2.5)
  who can hear it: clear line of sight (other NPCs don't block) or a navmesh path <= 6 m x shout_path_mult
  1.3. Walls and floors block it (PD2: you intimidate who hears/sees you). The cone beyond 6 m already
  required line of sight.

## 2026-10-14 01:50 UTC — freeze gate 1 (gh_loud PASS), PO-8 shot_fx, ND loud, D-102/D-106
### Done (pushed; last bcebbad9)
- GATE 1: gh_loud PASS end to end, windowed, real menus (seed 1791914030): drill jam fixed by the pilot, safe 182 s
  after placing, bags t=250/293, Pell escape, Payday card pick ($40,000) → Continue → Safehouse hub (4f391c1e, fa09ae00).
- ec27e45c PO-8 (D-105): EventBus.shot_fx per pellet/ray on every peer (crew, bots, NPCs, melee) + explosion_fx; 3 new
  reliable [R] facts on HeistNetSync (crew shot replay by seed, NPC/melee impact, explosion); 3P muzzle origins.
- 41025a1a HUD: no markers for disabled objectives (ND lockdown pointed at the server room); 18cc33d0 QC-60 markers
  re-resolve on objective data updates; D-102 equip(slot, redraw) for bag pickup; 68fd1268 ui_hud 1.12 reload progress.
- 5930a66a SL/DB marker_tags (readiness gate); 582b8c5c/e2d5cf6f S10 tests for D-102 carry.
- 1c578b4f pilot stands at the prefab UsePoint (ND keycard behind the teller glass).
### In progress
- ND loud via auto_loud (seed 1791938638): keycard t=65, vault gate t=99, drill next. Stealth win lane (subagent).
- PO-6 door swing: implemented + tests green, HELD: integration test_p3_loud test_01 (crew wipe) A/B vs snap running.
- Prefab metadata/surface lane (subagent).
### Queued
- Gallery Night (D-103) groundwork after the freeze gates; CrewMelee.hit_landed to the attacker's owner (P backlog).

## 2026-10-13 21:05 UTC — PO-5 loud win, D-093, PO-5.14
### Done (pushed; last b9f4b9ef)
- FIRST END-TO-END LOUD WIN, windowed, through the real menus: Glasshouse Routine. The drill opened the safe at 188 s,
  2 bags went in the alley van (t=254/296), escape opened, and walking into it ended the heist on the real Payday screen
  ("HEIST COMPLETE $46,200"). AI crew all alive. Payday → hub click-through gets re-verified on the next run (the harness
  missed the end event; fixed in b9f4b9ef).
- 044a8a59 D-093: helpless (tased / cloaker) members not revived within bleedout_time_s go to custody, no down (+test).
- f7bdc9a1 PO-5.14: police push in during BUILD/SUSTAIN (assault standoff band) instead of hovering in doorways (+test).
- 5ebe9f86 KR-2 fixed (bot unstick vs bodies the navmesh misses); L2.5 shot-age bug (downed bots shot to custody in 0.2 s).
- b9f4b9ef harness: real MouseCapture (click to capture, forced only as a logged FINDING); generic auto_loud flow driven
  by objective_markers.
### In progress (parallel lanes)
- Stealth flow (subagent); KR-3/KR-4 + ND stuck doors (subagent); director caps vs PD2 Normal for PO-5.4/KR-1 (subagent);
  specials wear characters (subagent); Glasshouse loud rerun for payday → hub; ND marker_tags staged (wait for map lane).
### Queued
- ND / SL / DB loud via auto_loud; ND/SL/DB stealth; D-094 viewmodel_lit lights; P's duplicate prop colliders.

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
