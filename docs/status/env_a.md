# ENV A status: Core Systems & AI

Owner: ENV A. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## 2026-10-17 02:45 UTC: D-130, R229/R230 fixes, anim clips + split, pilot, crew stack (env/a-core d10c9908)
### Done since 00:45 (pushed)
- df7d3727 / da8d9fc4 round-229 reds:
  - gait holds, mask_on, death_back_b, the s2 DifficultyDef ×2 leak;
  - inspectors counted by tag with C's escort markers.
- 58bf1265 test_zz_shared_resource_drift: the last a/ test fails on any cached tweak/def drift.
- 1b326212 D's 190f40c7 clips (aim_<fam>_<gait>, class reloads, cover peek/low by LOS rays, stagger, DB-4
  sit_chair_armed long guns only), each with fallback.
- c1de5907 refactor: anim_driver 1498 → 1209 lines (AnimLayers, HitClips, HeldVisuals, AmbientHints).
- aab638dc prewarm collects its parallel loads before heist start. P's ND load hang and GN seed-99 have the same
  root; fixed by reasoning.
- 5b7c70aa DB [breach]: crew-only, and walking through the open variant door completes it. GN: the doors under the
  shutters are BARRED with them.
- 67ce6d5f / ea0699dc D-130:
  - PagerSystem.cap_for; the HUD pagers_max bug (it always showed 4) fixed;
  - SecurityCamera.titan_min_difficulty; camera delay {1.6, 2.4};
  - difficulty_add on civilian groups pinned on a synthetic map;
  - side: true on bonus steps only; objective data state_changed.
- 74b18a00 DB CREW_STACK: cover claims ≥ cover_taken_m apart; an unseen leader within 1.5 m → the bot's slot.
- d10c9908 pilot:
  - layer-1 paths, and a locked door blocks a first objective;
  - lull reloads; stuck give-up; no out-of-reach F-holds;
  - DB thermite is a tool.
### In progress
- Windowed DB-7 auto_loud (seed 1003) and the GN seed-99 confirm (needs ESCAPE), 7000 s budgets each.
### Next
- ND-1 gate 2 (attempt 24).
- Pin GN/ND/SL population counts when C's D-130 rows land.
- Check the cover-pose ray classification on GH + DB windowed.
### heist_completion
- GN-8: race + load hang fixed, unconfirmed (seed-99 run in progress).
- DB-4: done.
- DB-7: run in progress.
- ND-1: open.

## 2026-10-17 00:45 UTC: new team resume; GN-8 B3 + race fix, B audit logic, round-229 reds (env/a-core df7d3727)
Session session_01EoHohP5E4RVEPzabfnFk8y (lead session_01HwYKRgCdkLfJCt4ZM6rfTk).
### Done (pushed)
- f9fd76eb trunk merge.
- 4b4fef68 B-DB/B-SL audit logic:
  - DB: the burn finds [product] silently; containers_hint once; [cartel] fails with 0 down; [product] on room entry
    (crew eye ≤ 6 m flat, same floor, clear world ray); Reyes payday on [escape] completed.
  - SL: [secure] seeds drives_secured 0. Test: test_bdb_mission_gaps.
- 291ce51d GN-8 lane:
  - B3 inspectors walk to the centrepiece slot and radio the alarm if it is empty.
  - WarmLoader: the director prewarm never overlaps a main-thread load of the same scenes (seed-99 race).
  - GN gaps: wall studies count for [extras]; the loud hack completes vault_drill and server_door; the server keypad
    completes server_door.
  - Tests: test_gn_inspectors_empty_slot, test_gn8_warm_loader, test_gn8_mission_gaps.
- 10572baf D cast: cartel_gunman g..l, dock_worker_c (dock_worker_c PENDING in test_d115 until D 45894565 lands).
- 585008d0 B3 Halberd escorts: guard_inspection_escort spawns, used when C's markers (c-worlds 2133b0aa) exist.
- df7d3727 round-229 a/ reds, tests only:
  - gait-locked holds and mask_on in test_v119 / test_v120; death_back_b variety.
  - test_s2_detection_meter leaked a ×2 DifficultyDef into test_s3_8_cameras (it now mutates a copy).
- Verified on trunk, nothing to do:
  - item 3 (unknown weapons id) is fixed by B ff0be43c.
  - DB-4 / DB-6 / SL-6 / D-4 rows were already done by the previous A.
  - The x5 GH police flake does not reproduce (3/3 green under load).
  - The knife finding is reach/timing, not damage; no ruling needed.
### Open / in progress
- GN-8 seed-99 crash: race fixed, unconfirmed. Needs a seed-99 run that reaches ESCAPE on a quiet box (the pilot loses
  to custody first).
- Pilot lane (worktree agent-aa105032f09babcd6, WIP 19ec7c45): _has_path on nav layer 1 (D-122), reload, vertical
  Door near-check (ND VaultGate), BronzeDoorsE unstick.
- Anim lane (worktree agent-a3830ca90edfdd278): D's 190f40c7 clips (aim_<fam>_<gait>, class reloads, cover peek/low,
  stagger_<fam>, sit_chair_armed for DB-4 armed seated posts), with fallbacks.
- DB-7 windowed auto_loud, ND-1 gate 2 (attempt 24): next once the box is quiet.
### heist_completion statuses
- DB-4 done (seated clip; sit_chair_armed in the anim lane).
- DB-6 A side done.
- SL-6 done.
- D-4 done.
- GN-8: B3 done (escorts pair with C 2133b0aa); audit gaps done; crash race fixed, unconfirmed.
- x5 GH police flake: not reproducing.
- DB-7 / ND-1 open.

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
