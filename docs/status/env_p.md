# ENV P status (Playability)

Newest entry first. Owner: ENV P. Scope: D-076. D-077: commit every 20–30 min; this file says where to resume.

## 2026-10-14 13:55 UTC: product-owner fresh-eyes pass (trunk r146), ranked
Runs: A's PO-5 flows played by input, windowed. GH stealth x2 (one PASS; one observed by po_observer.tscn, 58 rendered
frames, went loud at t=200 when an intimidated, untied civilian pressed the alarm) and ND loud (auto_loud, stuck at the
vault drill). CPU spikes: spike_probe.tscn, headless (llvmpipe frame times in the windowed runs are not usable).
Ranked by what a player would hit, with owner and file:line guess.
1. FIXED by A (cae0d9c6, confirmed with spike_probe): ND 1 Hz stutter for the whole stealth phase: hud_model 45-87 ms every ~1.03 s (50-108 ms frames). The `code`
   marker tag never resolves in the code_on_manager variant (world/heists/night_deposit/night_deposit_mission.gd:67,
   :207) and LocalHudModel re-resolves every tag ~1/s through a full-tree find_by_tag
   (systems/hud_model/local_hud_model.gd:567-580, heist_runtime.gd find_by_tag). Also: no marker for the code.
   A (routed by the lead).
2. RETRACTED: the ND vault drill did finish (objective -> 2 at t=477; the pilot's "waiting N s" is wall time on
   llvmpipe). Left over, minor: a running drill shows "Hold F to interact" + red "Can't do that right now" (no reason). A/B.
3. AI teammates stack inside each other: slots 1-3 within 0.1-0.2 m (TEL crew positions), two heads merged on screen
   in the ND antechamber. A (crew AI follow spacing).
4. First loud frame: 243 ms on ND, 98 ms on GH. assault_director 22-24 ms; ~200 ms outside FrameProf's keys (alarm
   cue/stream load? police spawn instancing?). A (lead routed the profiling). The HUD part of it IS gone (r144
   UiSfx.warm confirmed: hud_model no longer in the first-loud top systems on GH or ND).
5. FIXED (P, 55b5bba6): the weapon stayed up during timed interactions (rifle canted across the view mid-lockpick).
   PD2 holsters it: now lowered after 0.12 s of an interaction, drawn on completion/cancel.
6. GH U2: the knifed camera operator's body lies through the desk and under the chair. A/D (death pose placement).
7. Sound: cue.npc_melee_swing has no definition, so every NPC melee windup plays the placeholder beep
   (systems/combat/npc_gunner.gd:33; missing from the cue registry). Audio-registry owner.
8. HUD: an off-screen objective marker clamps onto the bottom-right ammo / inventory cluster (its label overlaps
   "27 / 120"; "3 m" sits on the item icons). B (content/ui/hud/widgets/objective_markers.gd edge inset, ~:10/:108).
9. HUD: subtitles sit low and faint behind the bottom HUD band (GH "Workshop door's open..."). B.
10. Text: "Your ride's 300.0 seconds out" (float in VO). strings.csv:1712 via night_deposit_mission.gd:332
    (wait_s float; same pattern GH/DB van ETA :1697/:2387). A (mission) or B (format ints).
11. Text: "Secured: 1 bags" (strings.csv:136, hud.gd:402: no singular). B.
12. Payday: "Clean job. Nobody knew we were there." next to 1 civilian killed and a cleanup cost
    (content/ui/results/payday.gd:475 keys only on stealth). B.
13. Prompt: the workshop lockpick shows the generic "Hold F to interact" (ui.prompt.interact) instead of naming the
    action. B/A (prompt_key on the door's InteractableComponent).
14. ND heist start: the camera spawns facing a brown wall at point-blank. A (ND player spawn yaw).
15. Heist start: a 72 ms frame at t~0.22 (hud_model first refresh 26-46 ms), both maps. A.
16. Low: GH, an intimidated civilian who was never tied later pressed the alarm button. Likely PD2-faithful (untied
    civilians recover); A to confirm the rule. Also GH a parked car body over the kerb line by a bollard (low
    confidence, one frame). C/A.
Tools: game/tests/p/_review/po_observer.tscn (frames + automatic flags), spike_probe.tscn (CPU spikes, unresolved markers).

## 2026-10-14 11:20 ET: lit PO-13 sheet, P-FP-STATES, Options hooks, sweeps
- PO-13 lit sheet captures/po13_hold_before_after_lit.png (GH street, 6 classes; Corsair row predates 7a61cd7e).
  7a61cd7e fixed my round-2 regression: rifle hip z -0.135 (stock was inside the 2 cm near plane, test_po4_feel).
- P-FP-STATES (9b915b3d, b4912280): CrewFpStates + eye_downed 0.8 m (eye_position follows; A told), tase jitter /
  buckle, kick fall + roll, hit punch; Reduce Motion; sheet captures/p_fp_states_sheet.png. test_p_fp_states 6/6.
- Options hooks (7babb171): ads_sensitivity on aimed look, screen_shake on camera shakers (duck-typed);
  test_p_options_hooks 2/2. FOV stays vertical (lead ruling, B relabels).
- (e) co-op FX: coop_fx_capture.tscn; A has the full-auto ghost-round bug, C fixed the TP flash (frame guard).
- PO-3 probe skips ladder grab cones (effe1d06); closed-door sweep on trunk r134 + c-worlds: 0 snags x 4 heists.
- Pre-push batch rule (lead): anything touching fp_viewmodel* also runs test_po4_feel and test_p1_01.
- Resume: LobbyDoor rerun after A's AI corner fix; coop_fx rerun after A's ghost-round fix; GN G1 at the freeze lift.

## 2026-10-14 09:00 ET: PO-13 round 2, (e) co-op FX, (d) C-grip clips
- Round 2 (a0b07f70): all-class hip framing (+3 cm right, +2 up, 4 closer; lens guard kept), pistol/revolver sprint
  lowered + canted on screen, pistol ADS shoulders lower/forward (reach ok). D arms/anims 18/18, viewmodel tests green.
- (e) coop_fx_capture.tscn (windowed host + client loopback, dev_sandbox, real heister bodies): own shots FP on both
  peers, the other crew TP, no doubling; captures/e_coop_fx_sheet.png. Sent: A, client full-auto ghost rounds
  (2 client shot_fx per tap vs 1 host replay); C, TP MuzzleFlash never drawn on frames > 50 ms.
- (d) C-grip in draw / reload / reload_empty verified, no change (captures/po13_cgrip_rifle_reload_draw.png).
- Resume: lit before/after sheet (scratchpad hold_lit / hold_lit_before renders) ->
  captures/po13_hold_before_after_lit.png; LobbyDoor rerun after A's AI fix; GN G1 when C's greybox lands.

## 2026-10-14 07:15 ET: D-105 sheets, gate-3 traversal, LobbyDoor, PO-13 round 1
- D-105: six-class gunplay sheet (captures/d105_gunplay_sheet.png; Glasshouse loud, 0 bit1 doubling); C's
  MuzzleFlash/TracerFx in FP (alpha-blended, FP smoke), drop-in mask rpc via net_sync.replicates_to (A confirmed).
- Gate 3: test_p_gh_traversal 3/3 (G8 stairs on C's ramps with/without heavy bag, fire-escape ladder, door-window
  route + bag thrown out). LobbyDoor snag: test_p_gh_lobby_door, player input passes all 15 diagonals; the stall is
  AI steering (A fixing: door-opening corners to the centre line + stall repath). No controller change.
- PO-13: PD2 look sway + breathing (310b4c19), long-gun support hand C-grip (72498a0f), pistol ADS 0.35 m + elbow
  spread (f7fce321), pistol hip framing (56255bb3); before/after sheet captures/po13_hold_before_after.png.
  Open: pistol ADS forearms still dominate (rig arm length caps ads_dist ~0.35: sh / forearm / sleeve rig work).
- KR-9: po13 skips headless. check_ownership char_arms_fp*/** patch applied by the lead.

## 2026-10-14 03:00 ET: D-107 stamina, D-105 in real heists, G1 harness
- D-107 (a6e67fc6, round 81): stamina/jump faithful to PD2 (sprint start > 4, run to 0; regen 1 s after the sprint;
  jumps never blocked, run-jump costs 2; 0.55 s jump cooldown; crouch + jump stands). test_p_d107_stamina 5/5; A's
  QB-60 jump test rewritten under the carve-out (13/13), B HUD green.
- D-102 follow-up 05f65d09: pickup calls CrewWeapons.equip(slot, true) (fire waits the equip time).
- D-105: C's MuzzleFlash / TracerFx used in FP (0c093371): MIX materials (additive is invisible in the viewmodel
  SubViewport), FP-sized smoke (C's world-space smoke fills the screen), C fixed billboard_keep_scale at source.
  gunplay_capture.tscn: Glasshouse loud, real-input fire at distinct surfaces, bit1 doubling check (0 doubled),
  corsair sheet in captures/d105_gunplay_corsair_gh.png; all-classes run in progress (llvmpipe ~17 min/weapon).
- G1 harness (D-104): game/tests/p/p_traversal.gd (PTraversal: gap, crouch bar, balcony throw, ladder, carry) +
  test_p_g1_traversal 5/5 on a synthetic course. Ready for Gallery Night's greybox.
- TODO: re-run test_pp_p12_door_snag alone (glasshouse; interrupted, A's door swing landed in r75).

## 2026-10-14 01:30 ET: Dockside pacing, carry presentation, D-105 FP weapon FX (WIP)
- Round 69 merged D-102. 33407473 removes bag_can_jump (A dropped its fallback, e2d5cf6f).
- Lane (c) Dockside pacing: game/tests/p/_review/bag_run_probe.tscn (real input, nav routes, --old compares).
  36 routes x 2 value sets (seeds 1/1002/2 -> E1/E2/E3): 0 stalls. Heavy x1.5 time, medium x1.75; worst case
  4 crates -> E3 4.2 min solo (was 3.1). Verdict accepted: no tuning; heist docs fixed by lead.
- Lane (a) re-scoped from the decompile (PD2 does not holster on carry): f27019c1 -5 deg camera roll while carrying
  (150 deg/s, Reduce Motion off) + weapon draw on pickup. Asked A for CrewWeapons.re_equip() (fire block).
- Gallery Night traversal review adopted as next_heist.md §7 (D-104); I own the G1 traversal tests.
- D-105 WIP: FpViewmodelFx (muzzle burst + smoke, casings incl. pump/lever/bolt timing, FP tracer from the apparent
  muzzle on EventBus.shot_fx bit1), per-shot viewmodel kick (exact critically damped). test_p_d105_fp_fx 3/3.
  fx_capture.tscn sheet (stand-in shot_fx until A emits). C told to skip bit1 tracers/muzzle.

## 2026-10-14 00:30 ET: D-102 bag carry, melee feel
- 2862fde1: melee-hit camera punch + closed-form landing dip. Pistol ADS closed (matches PD2); left-hand cup PARKED
  (D backlog). PO-3 snag re-run: 0 snags on all 4 heists.
- a890055b D-102: CrewTweak bag_speed_mult 1/0.75/0.5/0.25, bag_can_sprint light only, new bag_jump_mult
  1/1/0.5/0.25 (jump velocity; bags never block a jump), throw 4/4/2/1.2 m, head bob x raw move_speed_modifier
  (speed term normalised to the carried walk speed). bag_can_jump kept all-true (deprecated) until A moves
  test_s10_1_sprint_and_jump_limits_per_weight; test_s10_1_throw_distance_ordering needs <= (light == medium).
  Windowed real-input tests: test_p_d102_bag_carry (4/4).

## 2026-10-13 23:50 ET: lanes done, capture sheets, PD2 data
- Pushed through 338cea18 (trunk round 59 merged). Since 21:30: PP-P-12 door (9bea4dde, subagent: floor-height
  doorway probe, back-off, jamb-gated reach), D-097 recovery timing (recoil_wait), ADS eye relief + enforced band
  (96c142ef), ADS time from WeaponStats.ads_time_s + full-transition crossfade (dd03fe58), PD2 sprint->fire 0.4 s
  (8ea19d09), crouch camera easing (be592ac2), head bob behind B's GameSettings.head_bob() (4f4cfa6d), framing
  follows the playing set + melee_knife framing for B's knife (efe10f6f), d084 de-flakes.
- PD2 data from the Lua decompile (scratchpad pd2src) sent: per-class table (B applied, D-096), vmid / mod steps /
  ADS times (B), LMG drift as camera kick (A consumed, D-099).
- Lane 3 capture sheets: game/tests/p/_review/captures/ (ND + Dockside through the real menu, knife, AR). Harness
  lessons: `--heist=` is MenuFlow's direct-launch flag (use --po_heist); hold keys >= 1 tick (xdotool `key` at
  ~0.1 fps is sub-tick); llvmpipe heists run ~0.1-1 fps, use --fixed-fps 60 and wait in ticks.
- Pistol ADS hands: not fixable P-side (per-set FOV / depth only 27% -> 23% coverage); pose fix proposed for D.
- Running: PO-3 snag probe re-run on all heists (scratchpad po3b/). Open proposals: melee hit feedback, bag carry feel.

## 2026-10-13 21:30 ET: lanes L1/L2/L4/L5, D-095, recoil, landing, d084
- Pushed through 77e198ef (trunk round 50 merged). Done: all-class hip framing (f11b4df1, test_po4_viewmodel_classes),
  late ADS alignment modifier (42dfaf93), D-095 viewmodel_lit = layer 21 (1<<20; layer 20 is FIRST_PERSON_HIDDEN)
  + per-shot muzzle light (13da95e8), PD2 recoil punch (dff06548) + PD2 recovery (77e198ef: the whole burst kick
  returns after release, v 9/s h 5/s, cap 20 deg), landing dip (d638fad3), d084 de-flake, L4 pad ramp (897c39aa).
- PD2 recoil/spread reference table (from the PD2 Lua decompile) sent to B (D-096 data owner); design call to lead:
  PD2 ADS spread is ~3x looser than ours; A's crouch spread mult is backwards (0.75 vs still 0.5; PD2 1.0 / 0.4).
- A pushed bag throws following look pitch (02935de8, bias 25 deg).
- WIP: ADS eye relief per set. res://tests/p/_review/ads_sweep.tscn (`--fixed-fps 60 ... -- --out=DIR
  [--only=ids] [--ads_z=set:z,...]`) measures viewmodel coverage in ADS + thumbnails. Rifle: z -0.06 shows the
  buttstock slab, 0.0..+0.05 shows rear aperture + receiver sliver (PD2). Sweep of 17 weapons x z {0, .03, .06}
  running. L3 door subagent (worktree) still running.
- Windowed tips: `--fixed-fps 60` for any transition capture (llvmpipe ~1 fps otherwise collapses transitions).

## 2026-10-13 20:30 ET: rounds 35-42 merged, viewmodel lanes
- Merged trunk round 42 (892c64b9). Pushed 2c8cc473.
- AR hip pose (61d9e075): measured with res://tests/p/_review/vm_probe.tscn (`-- --out=DIR --primary=weapon.corsair_ar
  --slot=primary [--heist=glasshouse] [--no_ik]`, Vulkan windowed, dumps markers/AABB in camera space): authored rifle
  hip had the gun's rear 0.11 m behind the lens. FpViewmodelTweak.set_hip_offset / set_ads_offset_z per anim_set
  (rifle (0.02,-0.03,-0.16), ADS -0.06). Rifle left hand fingers-up is the authored clip (same with IK off): D's pose.
- L4 (897c39aa, subagent): PD2 pad yaw ramp (PlayerInput gamepad_ramp_*), test_p_l4_look_feel.gd; Options mouse
  slider confirmed a pure multiplier on D-091's 0.0016 gain.
- L3 PP-P-12 door head-on: subagent in a worktree (pending). Next: pistol hip cant / brute_12 left hand (L2),
  movement/ADS transitions review (L5), glasshouse AR capture.

## 2026-10-13 ET: team v3 dispatch (D-086), PO-2 mouse capture
- Queue: PO-2 mouse capture -> PO-1 casing exit -> PO-3 bump/step snags on all 4 heists -> feel pass.
- PO-2: game/systems/player/mouse_capture.gd (`MouseCapture`, D-087, input_focus.md 1.0) is the only writer of
  Input.mouse_mode. PlayerInput registers itself as the gameplay owner while `enabled` (paused / disabled /
  freed = not active), reads mouse look in `_input` (a Control under the captured cursor can no longer swallow
  it), and latches held buttons on capture (the click that captures never fires). Capture drops any stale GUI
  focus. Test game/tests/p/test_po2_mouse_capture.gd (logic headless; capture + real XTest mouse turn +
  release/focus windowed). PInputDriver.capture_mouse no longer writes the mode.
- Windowed runs: `xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game
  res://tests/framework/runner.tscn -- --dir=p --filter=po2`. Vulkan/llvmpipe deadlocks on exit after the runner
  quits (WSI swapchain futex), so wrap in `timeout` and read the `== N tests` line, or use
  `--rendering-driver opengl3`. xdotool (apt) gives real X pointer events.
- Still writing the mode (ENV B migrates): menu_flow.gd:749, menu_options.gd:51/63, join_request_dialog.gd:232/234,
  safehouse_host.gd:348, and range: range_spectator_input.gd:68, range_mode_input.gd:27/44.
- PO-1 (casing exit) ROOT CAUSE, windowed real-flow repro (game/tests/p/_review/po_playthrough.tscn: main menu ->
  2D hub (3D safehouse scene not on this branch) -> planning -> glasshouse -> briefing -> preplanning -> loadout
  "Start Heist", all xdotool clicks; then mouse look, hold real G, W): P/A side works: CAPTURED at spawn, no GUI
  focus owner, G held masks up in 57 ticks (0.9 s game). The gap is UI (ENV B, sent): no "Hold G to mask up" hint
  (ui.hud.mask_up_hint defined, never rendered), no mask progress bar, objective "{count}/{total}" unformatted.
  First repro "failed" only because llvmpipe glasshouse runs ~1 fps = ~1 physics tick/s (30 s wall < 1 s game):
  windowed harnesses must wait in physics ticks, not wall clock.
- PO-3: game/tests/p/_review/po3_snag_probe.tscn (headless, `--fixed-fps 60`, `-- --heist=<id> [--stance ...]
  [--approach=touch] [--selftest]`) sweeps every reachable walkable edge with the real controller: ~150k trials on
  all 4 heists x walk/sprint/crouch/touch: 0 step snags (kerbs 0.10-0.36 m all climbed; one false positive between
  G6 CoffeeTable_1/Armchair_1). Likely the PO played a build before P1-01 step-up (round 35). Notes for C/D: every
  prop has two colliders (X/Collision box + X/Model/Collision convex); quay edges QuayE/QuayW (10.9,-0.47,32.9) and
  Pier9East (57.8,-0.64,41.4) are 0.47-0.69 m drops, check they are meant to be.
- PO-3 windowed: po_playthrough now also turns 180 deg by real mouse, walks W off the glasshouse sidewalk kerb
  (0.25 m, at ~(4.4, 0, 13.2)) and back up it: PASS (y 0.00 -> 0.23).
- PO-4 (b9383a9d): look divides by CrewView.zoom_factor while aiming (PD2 zoom sensitivity); default mouse gain
  0.0025 -> 0.0016 rad/count. test_po4_feel.gd.
- test_p3_loud:test_10_ai_orders_during_assault ("follow: the AI caught up") fails on the pre-PO-2 base 7a417116 too:
  pre-existing, A's (crew AI follow), not caused by P.
- Viewmodel lighting ROOT CAUSE (06fd0301): Camera3D.cull_mask also culls LIGHTS by their `layers`. The PP-P-11
  viewmodel camera sees only VIEWMODEL_LAYER, so no world light ever reached the arms/gun (ambient only: near-black
  at night, pure black on maps without sky ambient). Fix: CrewView adds `ViewmodelKeyLight` (DirectionalLight3D,
  layers = light_cull_mask = VIEWMODEL_LAYER, no shadows) + viewmodel_ambient_mult (FpViewmodelTweak). Verified
  windowed with res://tests/p/_review/vm_probe.tscn (unit map: skin, sleeves, gun highlights now visible).
  Open (QP-2 to lead): world lights (muzzle flash, flashlights, lamps) still never light the viewmodel; options: a
  render-layer bit for lights (C/D set it, vm camera includes it) or P tagging Light3D layers at runtime.
- Still seen: ADS forearms fill the lower third (pose + 52 deg vm FOV), hip pistol sits low-right and reads canted
  (D's anim / lead PP-P-11 ruling). Next: that, ADS transitions, sprint/crouch/jump, door snag
  PP-P-12, brute_12 left hand, 1920x1080 review.

## 2026-10-12 20:25 ET: merge round 34, renders, loud run
- a2ddb786 merge trunk db22c24c (--no-ff). P suite 53 (only the opt-in E2E failed, now skipped by default),
  p4_progression 9/0, slice_b 6/0, b5_01 1 fail pending A's mask patch (ruling: ADS blocked unmasked).
- Viewmodel: gun already rides the `weapon` bone (FpViewmodelTweak.weapon_bone); measured hip pose within ~5 deg
  of camera axes, so the "tilt" is perspective. No P pose change made. New: brute_12 hip left hand floats at the
  barrel tip (LeftHandIK marker ~0.52 m out) - B marker / P IK, open.
- Loud run (CNC_E2E=1): MainEntrance+SalonDoor lockpicked by real input, drill placed on the Safe, 1 jam fixed by
  real input, but the safe was not open after 400 s game time; police down/cuff the AI crew. Open.
- Renders: /workspace/cnc-team/p/renders/01..10 (20:06-20:21 ET).

## 2026-10-12 19:50 ET: PT-02 Glasshouse E2E, PT-03 FP renders, PI-08, lead interrupt
- PT-02 game/tests/p/test_p_glasshouse_e2e.gd (real input; setup: isolate_npc, cameras removed in stealth run).
  Stealth run reaches the escape (keycard, workshop lockpick, safe reader, 2 bags thrown into the van, escape);
  fails only on the casing finding below. Loud run blocked (drill, SalonDoor snag).
- PT-03 renders: /workspace/cnc-team/p/renders/01..09 (scene res://tests/p/_review/fp_capture.tscn).
- PI-24 FIXED 0e1315a8: swap_weapon desynced after 1/2 keys or a failed equip (no-op swap).
- PI-25 FIXED 839c0330: jump latch armed on any held jump, so jump pressed in the air/after teleport was eaten
  (slice step 3 'bot jumped').
- PI-08 FIXED: CrewTweak.deceleration 50 for grounded braking/reversing (sprint stop 0.19 -> <=0.16 s incl. input).
- Routed: C - MainEntrance (glasshouse.tscn:10518) casing_allowed=false: a casing player cannot open the shop's
  public front door. A - Safe._inner_loot (safe.gd:129-130, 386-398) disables the child SafeDrill DrillPoint as if
  it were loot: drill point unusable (the Safe's own place_drill still works). A/C - loud walker stuck on the
  SalonDoor frame at (12.5,0,9.6) (LeafBody overlaps there). A - test_b5_01 line 91 aims unmasked (patch in
  /workspace/cnc-team/p/handoff_env_a/). Viewmodel (P/D): hip pistol canted ~40 deg, ADS forearms fill the lower
  corners with wrists through the grip; no crosshair in renders (HUD not in the capture scene - unverified).

## 2026-10-12 19:xx: PT-01 core-loop playtest (real input)
- No separate "Aaron's playtest list" exists; the P rows in docs/process/playability_pass.md (PP-P-1..3) are done
  via P1-01..03. Played the core loop by real input instead: game/tests/p/test_p_core_loop.gd, 12/12 pass
  (spawn, casing, mask-up hold, walk/sprint/crouch speeds, jump + no bunny-hop on held jump, F while casing,
  aim+fire+reload, sprint vs fire, melee, throw, gamepad bindings, pad mask-up + jump).
- No new P bugs found. Open: throw test is vacuous if the unit-map loadout carries no throwable; ledge (mantle)
  not covered - no mantle mechanic exists to test. Next: PI-08 tuning, PP rows as other envs log them.

## 2026-10-12 22:45 UTC — P1-02 casing audit, P1-03 ADS, D-084, D-085, UI focus, fire_rate_mult
### Done
- 200949ba/b0fceb0c D-084 CrewView.zoom_factor + local_zoom_factor() + zoom_factor_changed.
- 091ea17e P1-02 casing tests: PI-11 (alarm with AI crew) and PI-12 (AI keeps casing) NOT reproduced (pass);
  PI-13 casing_blocked(action) signal added (HUD hint source for ENV B). PI-10 hop patch verified: handoff test
  fails on trunk, passes with /workspace/cnc-team/p/handoff_env_a/pi10_casing_hop_heist_runtime.patch (ENV A).
- 8b770a5a PlayerInput: a focused visible Control (payday grab_focus, menus) blocks ALL polled gameplay input;
  actions held through the UI stay ignored until released (real gamepad LB/RB test).
- a1916bdb fp_viewmodel shot interval x weapon.fire_rate_mult (1.0 when unset) + test.
- d5186bc7 ADS: CrewView.is_aiming(crew) (aim, masked, mobile, not sprinting, not reloading); camera and arms
  share target, FpViewmodelTweak.ads_rate and smoothstep ease (PI-16/17/18) + real-input tests.
- (this commit's parent) D-085 edge assist + door tests: head-on frame-edge hits stalled dead before
  (probe: offsets 0.40-0.60 m stuck at the wall face); now slides to the opening within 0.45 m.
- Casing hides the FP viewmodel (PD2), shown with the draw on mask-up.
- `run_tests.sh p` 32/32; b hub_3d 13/13, b range 35/35; a: fp_viewmodel 15/15, crew_controller 8/8, l6_ai_teammates 11/11, a3_05 12/12.
### In progress
- PI-15 mask-up grace: left as is (PD2 resets on release; design call). PI-19 AimPoint audit DONE (all WeaponDefs have AimPoint; missing one warns once), PI-21 arms step lag DONE (FpViewmodelTweak.step_lag_mult 0.6). Tests: test_p_viewmodel_sights_steps (3/3); run_tests p 35/0; tests/a test_fp_viewmodel 15/0.
### Blocked
- Push of commits after 091ea17e: approval requests interrupted; not pushed (local only).
### Questions for lead
- QP-4: ENV A: CrewWeapons spread uses intent.aim (crew_weapons.gd:514) even while sprinting/reloading; should
  use CrewView.is_aiming(crew) for consistency.
### Ready for integration
- yes; check_all not run (lead rule).

## 2026-10-12 22:20 UTC — P1-01 mouse gain, PI-06, PI-03, UI shoulder gating; LOD bias question
### Done
- Mouse sensitivity bug (real, not headless-only): PlayerInput used InputEventMouseMotion.relative, which the
  canvas_items stretch scales by 1920/window width (xvfb probe: 1080p x1, 1440p x0.75, 4K x0.5, 720p x1.5,
  headless x30). Now screen_relative + test_degrees_per_mouse_count (fails on the old code with 30x). 1328183f.
  Probe project: /workspace/cnc-team/p/mouse_probe. Same bug in ENV B content/range/range_spectator_input.gd:98.
- PI-06 teleport keeps facing + test (failed before fix): 75ccbead. PI-03 diagonal/strafe/standstill: passes, not
  reproduced. PI-02: not reproduced; floor_snap_length unchanged.
- LB/RB shared with ui_payday_prev/next: paused input already blocks them; but a shoulder held through the UI
  close meleed/threw on resume (test failed). Fixed: resume-gated actions until released. p_input_driver gains
  joy_button(). `run_tests.sh p` 17/17; tests/b hub_3d 13/13; gdlint clean on P files.
### In progress
- LOD zoom bias: on hold, see Questions.
- Next: P1-02 casing audit, then P1-03 ADS.
### Blocked
- Push: 403 (permission denied to LeviticusFigglebottom).
### Questions for lead
- QP-3: Godot already divides mesh LOD by zoom (Projection::get_lod_multiplier = 2*tan(fov/2), used for mesh LOD
  selection), so scaling Viewport.mesh_lod_threshold with zoom would double-count (a 4x scope at 40 m would pick
  the LOD of ~2.5 m, not 10 m). Visibility ranges (HLOD, used in world/props/**) are NOT FOV aware and have no
  viewport bias. Proposal: no mesh_lod_threshold change; for HLOD, a P-side zoom factor published by CrewView that
  ENV C/D props read, or accept pop-in through scopes. Which?
### Ready for integration
- yes; check_all not run (lead rule).

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
