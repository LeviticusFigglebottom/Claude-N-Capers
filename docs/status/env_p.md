# ENV P status (Playability)

Newest entry first. Owner: ENV P. Scope: D-076. D-077: commit every 20–30 min; this file says where to resume.

## 2026-10-12 22:05 UTC — P1-01 (step-up/snap, PI-04, PI-05), PInputDriver, PI-10 handoff
### Done
- PInputDriver (game/tests/p/p_input_driver.gd) + self-test 5/5: a43d33b7, uids 6b858a0b. PlayerInput gets a
  test-only `test_assume_captured` (headless cannot capture the mouse). Mouse gain is calibrated at run time
  because headless stretch scales motion ~30x.
- CrewController.mask_forced for ENV A's hop fix: 4860fdbc. Handoff for ENV A (owner of heist_runtime.gd):
  /workspace/cnc-team/p/handoff_env_a/ (patch + test_p1_02_casing_hop.gd, which fails on trunk: STEALTH -> LOUD).
- P1-01: WIP step-up/snap passes as written; test_p1_01_ground ported to real input (human); PI-05 jump latch and
  PI-04 uncrouch headroom fixed with tests. `run_tests.sh p`: 13 tests, 0 failed (local run).
- PI-23 was wrong: slot 1 IS an AI in that launch (test passes).
### In progress
- Next: PI-02 snap length, PI-03 step probe, PI-06 teleport look resync.
### Blocked
- check_all not run (lead rule 17:55 ET). Push: see report.
### Questions for lead
- none new
### Ready for integration
- yes for P1-01 items above; check_all not run by rule; `run_tests.sh p` 13/13.

## 2026-10-12 21:55 UTC — P1-01 / P1-02 / P1-03 issue list + queue (code read only, Godot not installed)
### Done
- Playability issue list + 2h+ fix queue below (this commit). Built by reading code only; nothing run.
### In progress
- P1-01: WIP step-up/snap (6d447827) + test_p1_01_ground.gd still UNTESTED. Exact next step: once Godot is on
  the box, `tools/ci/run_tests.sh a,p`, then fix whatever test_p1_01_ground reports, then PI-01..PI-05 below.
### Blocked
- All runtime verification: Godot 4.7.2 not installed on the box (lead is setting it up).
- Push: P does not push (D-077); lead merges env/p-play locally.
### Questions for lead
- QP-1: The casing->STEALTH hop fix (PI-12) is in game/systems/heist/heist_runtime.gd (ENV A / lead file). OK for P
  to send the 3-line patch to you, or does A take it?
- QP-2: Real-input tests (PI-20) need a helper that injects InputEventAction into PlayerInput instead of
  HeistRuntime.set_bot_intent. Proposed: game/tests/p/p_input_driver.gd (P-owned). Agree?
### Ready for integration
- no; `check_all.sh --env p` result: not run (no Godot)

### Playability issue list
Legend: P0 = blocks normal play, P1 = clearly wrong feel, P2 = polish. "Verified" = confirmed by reading the code
path end to end; "Hypothesis" = needs a run to confirm. Line numbers are at dbfc7281.

#### Movement, step-up, floor snap (P1-01)
- **PI-01 [P0, Verified-by-read, unrun]** crew_controller.gd:429-447 / test_p1_01_ground.gd (whole file). The
  step-up/snap-down WIP has never run. Symptom today on trunk: curbs, door sills and stair risers block a walking
  player (no jump while casing, so casing players are stuck). Fix: run the test, iterate on `_step_up_rise`.
- **PI-02 [P1, Hypothesis]** crew_controller.gd:105-107 + 481-488. Engine `floor_snap_length` = 0.35 m AND the
  custom `_snap_down` both pull the body down. Symptom: a double snap / small stutter walking off curbs; also
  move_and_slide may snap 0.35 m down after a jump's first tick lands near a ledge. Fix: set floor_snap_length to
  ~0.05 (or 0) and leave step-down to `_snap_down`; re-run the step series.
- **PI-03 [P1, Hypothesis]** crew_controller.gd:452-476. Step probe uses one tick of motion (~6 cm at walk,
  ~10 cm sprint) and requires >= 25% forward travel at step height (l.466). Symptom: diagonal approach / strafing
  into a curb, or very low speed (just started walking), fails to step and grinds on the face. Fix: probe with
  max(h_motion, capsule_radius*0.5) along the wish direction, then move only the real h_motion.
- **PI-04 [P1, Verified-by-read]** crew_controller.gd:548-559 `_apply_stance`. Un-crouching has no headroom check.
  Symptom: standing up under a desk/vent pushes the capsule into the ceiling (stuck or popped through). Fix:
  test_move up by (height_standing - height_crouched) before growing; stay crouched if blocked.
- **PI-05 [P1, Verified-by-read]** crew_controller.gd:411-415. `_jump_latch = i.jump and not grounded` releases the
  latch on the landing tick, so holding Space auto-bunny-hops (one stamina cost each). Fix: latch = i.jump (release
  required). Add a test that holds jump for 2 s and counts takeoffs == 1.
- **PI-06 [P1, Verified-by-read]** crew_controller.gd:325-331 vs player_input.gd:29-30, 103-107. `teleport()` sets
  look_yaw, but PlayerInput keeps its own `_yaw/_pitch` (synced only in _ready / set_paused), and the next intent
  overwrites the crew's yaw. Symptom: after spawn-at-van, custody release or any server teleport the view snaps
  back to the old facing. Fix: PlayerInput re-syncs from the crew when a `teleported` signal fires (add signal).
- **PI-07 [P1, Hypothesis]** player_input.gd:48-56, 89-100; crew_controller.gd:368-372. Mouse look is accumulated
  in _unhandled_input but only applied to Head/body in _physics_process (60 Hz) with no interpolation. Symptom: look
  feels laggy/juddery on 120-240 Hz monitors. Fix: apply the local human's yaw/pitch to the camera every rendered
  frame (presentation only, in CrewView._process) and keep physics on the tick value; enable physics interpolation
  for the body.
- **PI-08 [P2, Verified-by-read]** crew_controller.gd:401-405. Same `acceleration` (30 m/s^2) for start and stop,
  air_control 0.3 scales both; no friction distinction. Symptom: slight ice on stop at sprint (0.19 s), floaty air
  strafing. Fix: separate `deceleration` tweak (~40) - tuning item after playtest.

#### Casing mode (P1-02)
- **PI-10 [P1, Verified-by-read]** heist_runtime.gd:572-575 + stealth_director.gd:327-335. Getting spotted while
  casing force-masks (`set_masked(true)` l.329) -> crew_masked -> `_on_crew_masked` moves CASING -> STEALTH before
  the alarm. When that detection then raises the alarm (camera countdown, guard call), the phase goes
  CASING -> STEALTH -> LOUD: this is the STEALTH hop players see (HUD/music flash "stealth"). The comment at l.573
  claims no hop but only the `went_loud` path is guarded. Fix: `_on_crew_masked` ignores forced masks (pass
  `forced` through EventBus.crew_masked or check a `forced` flag); only a voluntary mask-up enters STEALTH; detection
  stays CASING until alarm -> LOUD. Needs lead/A sign-off (QP-1).
- **PI-11 [P1, Hypothesis]** heist_runtime.gd:557-562 vs crew_ai_brain.gd:259-261. If any alarm_raised listener
  masks a crew member before HeistRuntime's handler runs (signal connection order), `went_loud` is still false
  and the hop happens too. Fix: set went_loud at the very top (it is), and in addition make `_on_crew_masked`
  defer phase change by one tick / check alarm. Verify with a test: casing -> alarm, record every
  heist_phase_changed, assert exactly [CASING->LOUD].
- **PI-12 [P1, Verified-by-read]** crew_ai_brain.gd:259-261. An AI teammate outside STEALTH_WAIT masks itself on
  its first think while the humans are still casing -> CASING -> STEALTH immediately at heist start. Symptom: AI
  crew "breaks" casing for everyone. Fix (A file, via lead): AI mirrors leader.masked in casing.
- **PI-13 [P1, Verified-by-read]** crew_controller.gd:376-410. Casing blocks crouch/sprint/jump silently. Symptom:
  player presses Ctrl/Shift/Space and nothing happens, no hint. Fix: HUD hint (ENV B) driven by a new
  `casing_blocked(action)` signal from CrewController (P side).
- **PI-14 [P2, Verified-by-read]** crew_tweak.gd:48-49. `mask_slowmo_duration_s/scale` exist but nothing reads them
  (grep). Symptom: mask-up has none of the PD2 slow-mo beat (S1.2 mask-up feel, moved to P by D-076). Fix: local
  presentation-only time effect (camera FOV punch + audio) - do NOT touch Engine.time_scale in co-op.
- **PI-15 [P2, Verified-by-read]** crew_controller.gd:513-519. Releasing G at 99% resets mask_progress to 0 with no
  grace. Fix: decay at 3x rate instead of reset.

#### Aiming / ADS / viewmodel (P1-03)
- **PI-16 [P1, Verified-by-read]** crew_view.gd:145-147 vs fp_viewmodel.gd:637-639. Camera zoom follows intent.aim
  always, but the arms drop out of ADS during RELOAD/SWAP. Symptom: zoomed-in FOV with the gun at the hip while
  reloading. Fix: one shared ADS weight (CrewView reads FpViewmodel.ads_weight when the arms exist).
- **PI-17 [P1, Verified-by-read]** crew_view.gd:146 (CrewTweak.ads_zoom_rate 8/s) vs fp_viewmodel.gd:639
  (FpViewmodelTweak.ads_rate). Two rates, linear move_toward. Symptom: FOV and sights arrive at different times,
  linear (robotic) ADS. Fix: one rate, smoothstep ease on the shared weight.
- **PI-18 [P1, Verified-by-read]** player_input.gd:108-112; crew_controller.gd:380-385. Aim and sprint can both
  be held: viewmodel plays sprint (fp_viewmodel.gd:626) while the camera zooms. Fix: aim cancels sprint (PD2), in
  `_simulate` (`can_sprint and not i.aim`), aim while casing ignored.
- **PI-19 [P2, Verified-by-read]** fp_viewmodel.gd:650-656. ADS alignment silently skipped when the weapon has no
  `AimPoint`. Symptom: sights off-axis on those guns. Fix: Log.warn once per weapon + a test over every WeaponDef.
- **PI-21 [P2, Hypothesis]** fp_viewmodel.gd:642-649. Bob is driven by horizontal speed only; step-ups now move
  `Head` (crew_controller.gd:421) but the arms get no matching dip/lag. Symptom: arms rigid vs camera on stairs.
  Fix: small vertical lag from `_step_offset` into the viewmodel offset.

#### Tests that use bot shortcuts instead of real input
- **PI-20 [P0 for D-076]** game/tests/p/test_p1_01_ground.gd:48,68,75,220 and every test under tests/a +
  tests/integration: movement is driven through `HeistRuntime.set_bot_intent`, which bypasses PlayerInput entirely
  (player_input.gd:97-99 returns early). So input mapping, toggles, look, the F/G contextual keys and PI-05/PI-06
  are never exercised. Fix: P-owned driver that presses actions via Input.parse_input_event(InputEventAction) and
  mouse motion, used by all P tests (QP-2).
- **PI-22 [P1]** test_p1_01_ground.gd:211 `c.set_masked()` and :212 teleport onto the block: mask by holding G for
  mask_up_time_s and reach the block by walking a ramp/stairs.
- **PI-23 [P1, Hypothesis]** test_p1_01_ground.gd:168-203 asserts slot 1 is AI but the launch passes
  `crew_ai: false` (l.15); the AI half is driven by bot intents, not CrewAiBrain. Likely fails or tests nothing AI.
  Fix: launch with crew_ai true and order the AI to follow over the stairs.
- **PI-24 [P1]** Shortcut load elsewhere (set_bot_intent / teleport_crew / isolate_npc call counts):
  integration/test_p1_vertical_slice_b.gd 26, integration/test_p3_loud.gd 24, a/test_p1_sandbox_gate.gd 19,
  a/test_a3_05_ai_orders.gd 16, integration/test_p1_vertical_slice.gd 13, a/test_a1_02_crew_controller.gd 13.
  Those are A/lead files: P writes a real-input "walk the slice" test in tests/p instead of editing them.

### Fix queue (ordered; estimates are hands-on time with Godot available)
1. P1-01a (30 min) run test_p1_01_ground, fix failures in the WIP; PI-23 test fix; commit.
2. P1-01b (20 min) PI-02 snap length, PI-03 probe length; re-run step series + stairs.
3. P1-01c (20 min) PI-05 jump latch + test; PI-04 uncrouch headroom + test.
4. P1-01d (30 min) PI-20 input driver; port test_p1_01_ground to it; PI-22.
5. P1-01e (20 min) PI-06 teleport/look resync + real-input test; PI-07 render-rate look (measure first).
6. P1-02a (30 min) casing audit test: casing -> spotted -> alarm, casing -> alarm, AI crew present; record phases
   (PI-10/11/12); patch to lead (QP-1).
7. P1-02b (20 min) PI-13 signal, PI-15 mask grace, PI-14 mask-up beat (presentation only).
8. P1-03a (30 min) PI-16/17 shared eased ADS weight + test (FOV and arms reach 1.0 together, drop together on reload).
9. P1-03b (20 min) PI-18 aim cancels sprint; PI-19 AimPoint audit over all WeaponDefs; PI-21 arms step lag.
10. Then PI-08 tuning and Aaron's playtest list.
Total ~4 h.

## Previous: Current (resume here)
1. **P1-01 step-up and ground feel**: IN PROGRESS.
   - Done (WIP, untested): CrewTweak `step_height_m` 0.35, `max_slope_deg` 45, `step_smooth_rate` 14;
     CrewController `_move_grounded` (step-up via test_move up/forward/down + walkable ray, snap-down
     along step/ramp edges, `_grounded` flag, camera-only `_step_offset` on `Head`).
   - Next: write game/tests/p/test_p1_01_ground.gd (5/10/15/20/30/40 cm step series, ramp, steep
     ramp, stairs up/down, AI slot, camera jitter) with real intents; iterate; run `run_tests.sh a,p`.
2. P1-02 casing-mode audit: not started.
3. P1-03 ADS audit: not started.
- Baseline `tools/ci/run_tests.sh a` before any change: `== 627 tests, 1 failed, 1 skipped ==`
  (failing test name cut off by my log tail; identify on the next full run).

## 2026-10-11: created
- ENV P created by the lead (D-076). Queue: step-up/floor snap, casing-mode audit, ADS audit, then the product
  owner's playtest list.
