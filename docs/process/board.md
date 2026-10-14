# BOARD (team v3, D-086)

Owner: **LEAD** (only the lead edits this file; envs send updates with `send_message`). Newest first in each section.
Read it at the start of every work session.

## Sessions
| Role | Session id | Branch | Focus now |
|---|---|---|---|
| LEAD | session_014E3p2DmSYTneJjytGwKKfc | claude/dreamy-hamilton-pc7vck | merges, rulings, contracts, gates |
| ENV P | session_01FYVVhNtxKAoQmyfnZ9rb3t | env/p-play | PO-2 mouse capture, PO-1 casing exit, PO-3 bumps |
| ENV B | session_0159qCTRV9CsDQs465nGSW28 | env/b-content | PO-4 UI/UX overhaul (style spec first) |
| ENV C | session_013uMHd1Npqkx1reY1pJMaye | env/c-worlds | D-104: levelcheck groundwork, PP-C-1 walk test fix, Gallery Night plan/doc; greybox at freeze-lift |
| ENV A | session_015kTjrZsUFn7gLqNVwAXdkh | env/a-core | PO-5 end-to-end windowed playthrough + blockers |

## Trunk / merge rounds
- 2026-10-14 08:00: **round 87 ON ORIGIN**: env/p-play 11d47b5f (G1 traversal harness PTraversal: gap/throw_bag/ladder/carry, real input). p g1_traversal 5/5 green. Open (P): re-verify test_pp_p12_door_snag after door swing.
- 2026-10-14 07:50: **round 86 ON ORIGIN**: env/c-worlds c3b64dc0 (GH break-room WindowLink removed: unpassable 0.9 m sill caused the U1 window stall). glasshouse map + validate_level green. QC-61 ruled (see Open questions).
- 2026-10-14 07:40: gate 1 re-confirmed: gh_loud PASS on the door-swing build (seed 1791914030; PO-6 swing, PO-8 shot_fx+VfxDirector, surfaces, ladder layer, pierce fix; safe 182 s, bags 253/295, Payday → hub). ND loud attempt 5 started.
- 2026-10-14 07:35: **round 85 ON ORIGIN**: env/p-play d1f6f732 (FP uses C's MuzzleFlash/tracer scenes with MIX materials; gunplay_capture tool: in-heist windowed check, no bit1 doubling) + LEAD G.VFX_DIR hotfix (banned hard paths). p d105, c vfx 20, a fp_viewmodel green. Six-class sheet pending (P). Real-GPU perf probe for impact_fx §3 1.5 ms still open.
- 2026-10-14 07:15: **round 84 ON ORIGIN**: env/c-worlds f5eb9b42 (ND AreawayLadderLink + GH FireEscapeLadderLink moved to nav layer 'ladder'; layer-1 agents no longer path over them). ND/GH maps + validate_level + a3_10/ladder green. Unblocks gate 2 (ND loud attempt 5). Open (C): GH/ND generators are NOT deterministic (dressing order/navmesh drift between regens) → violates level_standards §6b; C lane to fix.
- 2026-10-14 07:05: **round 83 ON ORIGIN**: env/b-content a08dbc44 (PO-B-C2 MenuFlow handles host_lost → lobby + message; C3 joining focus; C4 join/leave HUD toasts; coop_capture harness) + LEAD log.gd (PO-B-C5: peer id only from a connected peer). PO-B-C1 already fixed r80. b coop_host_lost/hud_queue/lobby/ui_hud/menu, a3_07, coop green.
- 2026-10-14 06:50: **round 82 ON ORIGIN**: env/a-core (HeistRuntime creates a VfxDirector on host + replicas, cleared on teardown; ShotFx.surface_of delegates to ImpactFx). Gunplay FX now end-to-end in heists (shot_fx emitted on every peer since r72). a po8/d105/a1_01/a3_07, c vfx 20, P1 slice green. Next: P windowed in-heist FX check.
- 2026-10-14 06:35: **round 81 ON ORIGIN**: env/p-play b7026a82 (D-107 stamina/jump per PD2; QB-60 jump test rewritten under carve-out, A to review). p d107 5/5, a qb56_61 13/13, a1_02 8/8, b ui_hud 17/17 green.
- 2026-10-14 06:20: **round 80 ON ORIGIN**: LEAD net.gd (ENet peer timeout 32/15 s/60 s on both sides; Log.warn when a human slot falls back to AI) + env/a-core (HeistLauncher loads the map on a worker thread). Fixes B's co-op finding: host bring-up stall (~40 s llvmpipe) dropped the client. a1_01/a3_07/coop/b lobby green. Remaining: HeistRuntime.start() one-frame stall (not split before freeze gates); B fixes MenuFlow host_lost.
- 2026-10-14 06:00: **round 79 ON ORIGIN**: env/c-worlds 5dd69ef3 (PO-8 VFX library game/world/vfx: ImpactFx/VfxDirector/decals/TracerFx/MuzzleFx/ShellFx/explosions, EFFECTS_SCALE caps; PP-C-1 walk fix). vfx_surface_of 7 + vfx_pools 13 + surface_tags + validate_level green; capture sheet reviewed. A next: instance vfx_director.tscn per heist + shot_fx emission. Open: GH BreakRoomWindowBlocker blocks the fire-escape window (C fixes); 1.5 ms perf probe needs a quiet machine.
- 2026-10-14 05:45: **round 78 ON ORIGIN**: env/a-core A3-10 (Ladder prefab owns a bidirectional NavLink on nav layer 4 'ladder'; layer-1 agents never path over ladders); project.godot names nav layer_4. a3_10/ladder/a2_01 + c validate_level green. C next: remove hand-built ladder links (ND AreawayLadderLink, GH FireEscapeLadderLink).
- 2026-10-14 05:30: **round 77 ON ORIGIN**: env/c-worlds 5676a8ce (water-surface bullet collider on ND + DB, layer 5 hitboxes only, navmesh identical). c water/ND/DB/surface_tags + int test_p3_loud green.
- 2026-10-14 05:15: **round 76 ON ORIGIN**: env/p-play bacd6541 (D-105 FP muzzle burst/smoke/casings/tracer/per-shot kick; D-102 redraw on bag pickup). p d105/d102 + a fp_viewmodel green. D-107 (stamina/jump PD2) ruled.
- 2026-10-14 04:45: **round 75 ON ORIGIN**: env/a-core 8745cb79 (PO-6 door swing: set_open(open, instant, breach), physics ease-out, blocked leaf pauses, breach 0.15 s, replicated is_open+breach; D-105 prefab surfaces + Door.leaf_surface). po6/d105/a1_03/po8/a2_01/s9_5/qc37/a3_07 + c validate_doors/glasshouse/shadow_ledger green. test_p3_loud test_01 → FIXED (LEAD): bisect pinned r72 env/c-worlds (data-only: timing), real cause the no-wipe check counted TASED crew as down (min standing 0 = 1 downed + 3 tased); now NORMAL/TASED/SWAN_SONG count as on feet, min standing 3, 2/2 green.
- 2026-10-14 04:30: **round 74 ON ORIGIN**: env/b-content (D-106 skill-boosted armory/loadout stats + With Skills/Base toggle). b targeted green. KNOWN RED since round 72: integration test_p3_loud test_01 crew wipe (deterministic, 3/3); bisecting.
- 2026-10-14 04:15: **round 73 ON ORIGIN**: env/a-core (bulwark pierce recursion fix: PIERCED_KEY exclusion + MAX_PIERCES 3, stacked-shield regression test; auto_loud stops toggling doors near markers). l4_5/l3_4/po5_bulwark/l3_6 green.
- 2026-10-14 04:00: **round 72 ON ORIGIN** (c49a3a08): env/a-core, env/c-worlds (surface ids on kits/props/maps, impact audio cues), env/b-content, env/p-play. a/c targeted green; b/p/int tail still running at push.
- 2026-10-14 03:20: **round 71 ON ORIGIN**: env/a-core (QC-60 markers re-resolve on data updates; CrewWeapons.equip(redraw)), env/p-play (carry tilt -5°, re-equip on pickup, bag_can_jump removed), env/c-worlds (gallery_night_floors_ascii.py --check, camera_spine/screen validators, doc fixes). a/p/P1 slice green; slice_b + readiness still running at push.
- 2026-10-14 03:00: **FREEZE GATE 1/3 PASSED: gh_loud** (A, windowed, real menus, seed 1791914030: Glasshouse loud → payday card → Continue → Safehouse hub, RESULT PASS). Gates left: gh_stealth win, ND loud (auto_loud running).
- 2026-10-14 03:00: **round 70 ON ORIGIN**: env/a-core (SL/DB objective marker_tags; release-run harness fixes), env/c-worlds (gallery_night.md Build rulings, approved), EventBus SHOT_FX_* flag constants. test_heist_readiness: all 4 heists PASS (no pending). a/c targeted green.
- 2026-10-14 02:40: **round 69 ON ORIGIN**: env/p-play (D-102 PD2 bag carry), env/a-core (s10 tests for D-102, SL/DB marker lane in progress), env/b-content. a carry tests 43/0, p 88/0, P1 slice 10/0 (slice_b still running at push). D-104 ENV C re-activated; Gallery Night §7 requirements.
- 2026-10-14 02:20: **round 68 ON ORIGIN**: env/b-content (failure paths with fail reasons + "what you lost", Quick Play Continue, colour-blind palette roles for all new widgets), env/p-play (melee punch, spring fix), env/a-core (stealth harness WIP). b targeted + p 84/0 green.
- 2026-10-14 02:05: P PO-3 snag probe re-run on current maps: 0 snags on all 4 heists.
- 2026-10-14 02:00: **round 67 ON ORIGIN**: env/a-core (ui_hud 1.9-1.11 HUD-model fields live: local_net_id, revive_progress/reviver_slot, crew-row bleedout_s/revive_progress; qb_b6_02 gate red FIXED; ND early-objective = HUD presentation, routed to B), env/b-content (pause job card, teammate state badges, per-kind objective marker icons). a/b targeted green. gh_loud release run in progress at A.
- 2026-10-14 01:45: **round 66 ON ORIGIN**: env/b-content (save v8: existing profiles get the starter AR equipped into an empty primary; pause menu job card), env/p-play (Dockside real-menu capture sheet: all PASS). Freeze-unlock still open: gh_loud payday→hub, gh_stealth win, ND loud win (A).
- 2026-10-14 01:00: **round 65 ON ORIGIN**: env/b-content (radial interaction ring, hostage/trade strip, Tab loot-secured list), plus A/P merge commits. b targeted + p 83/0 green.
- 2026-10-14 00:50: full gate on round 57 (adaae46b): 1854 tests, 3 failed (B: ui.action.dismiss_tip string ×2; qb_b6_02 crew stats shots/hits, likely PD2 spread vs test aim). **validate_level: all 4 maps PASS** (first time). Routed to B.
- 2026-10-14 00:40: **round 64 ON ORIGIN**: env/b-content (hit/headshot/kill markers + damage arcs + low-health vignette/heartbeat, payday XP bar, downed-state screen, equipment icon chips, assault phase strip, loading screen with tips). ui_hud 1.9/1.10 (local_net_id, revive_progress/reviver_slot → A). b targeted + P1 slice green.
- 2026-10-14 00:20: **round 63 ON ORIGIN**: env/p-play (knife melee framing eased per playing set), env/a-core (gh_stealth WIP harness). p + fp_viewmodel/d069 green.
- 2026-10-14 00:10: **round 62 ON ORIGIN**: env/b-content (all 64 mods on PD2 accuracy/stability steps, mod ADS deltas zeroed, PD2 ADS times, LMG drift values, 21:9 in-heist HUD captures uw_*), lead P4 goldens to match (9/0). b/a/p targeted green.
- 2026-10-13 23:55: **round 61 ON ORIGIN**: env/a-core 0ca5ff38 (Bulwark shield clips, all-NPC spawn-yaw snap fix). a targeted + P1 slice green. gh_loud release check running at A (seed 1791914030).
- 2026-10-13 23:45: **round 60 ON ORIGIN**: env/a-core (D-095 key interior lights on viewmodel_lit across all 4 maps; A4-02 probe: real characters cost ≈ +0.02 ms/NPC CPU vs capsules). Map tests + d095 green. Pending: B's PD2 mod rescale (802ae2b1) lands with lead P4 goldens once ADS deltas are zeroed.
- 2026-10-13 23:30: **round 59 ON ORIGIN**: env/p-play 4f4cfa6d (subtle PD2 head bob behind GameSettings.head_bob, d084 race fixed, ultrawide vm framing checked), env/a-core 0c7f0f66 (LMG drift consumed from WeaponStats bias), env/b-content (head_bob setting). p 83/0, a/b targeted green.
- 2026-10-13 23:15: **round 58 ON ORIGIN**: env/a-core 7a6c25e0 (D-099: corpses leave G.ENEMY; loud director despawns unseen bodies after 30 s); lead applied A's condition-based tie patch to test_p3_loud test_09 (flake), p3_loud 10/0 ×2.
- 2026-10-13 22:45: **round 57 ON ORIGIN**: env/p-play (ADS time from weapon data + clip crossfade, PD2 sprint→fire exit, crouch camera easing), env/b-content (folding-knife model, onboarding replace fix), env/a-core. D-099 WeaponStats.recoil_horizontal_bias_deg. p 82/0, b/a targeted green. Round 56 (A's director/specials/KR fixes) pushed before it. Full gate on round 57 running in background.
- 2026-10-13 22:25: **round 56 ON ORIGIN**: env/a-core (ALL known reds fixed: KR-1 director force model, KR-3 ND zfight, KR-4 SL barred doors; specials wear characters; ND objective markers; D-097 stance spread 1.0/1.0/0.4 + uniform radius), env/p-play 96c142ef (ADS eye relief, enforced for all 34 weapons), env/b-content. D-099. Full gate started in background.
- 2026-10-13 22:10: **round 55 ON ORIGIN**: env/b-content 673150c9; lead flipped window/stretch/aspect="expand" (D-098; 21:9 fills the window). b UI tests + p 79/0 + P1 slice green.
- 2026-10-13 22:00: **round 54 ON ORIGIN**: env/p-play 5cff3a32 (fp_viewmodel tick regression from 42dfaf93 fixed; a test_fp_viewmodel 15/0, p 79/0). Routed to B: folding knife has no model (empty-fist melee).
- 2026-10-13 21:55: **round 53 ON ORIGIN**: env/p-play 9bea4dde (PP-P-12 door snag FIXED, PD2 recoil timing), env/b-content (PD2 recoil/spread on all 36 weapons, 16:10 hub card fix, dismiss_tip). Lead: P4 goldens updated to PD2 values (D-097), D-098. stretch aspect=expand held until B's HUD passes test_pp_hud_720p under it. p 79/0, b targeted, P4 9/0.
- 2026-10-13 21:40: **round 52 ON ORIGIN**: env/a-core 2f7a8991 (release e2e run_po5.sh + seed hook, bag throws follow camera pitch), env/p-play 77e198ef (PD2 recoil recovery, d084 de-flaked), env/b-content (onboarding on dismiss_tip). p 74/0, a targeted, P1 slice 10/0.
- 2026-10-13 21:20: **round 51 ON ORIGIN**: env/a-core (D-093 helpless→custody, PO-5.14 police push in, harness real capture + auto_loud; FIRST END-TO-END LOUD WIN windowed via real menus → payday), env/p-play (recoil eased kick, landing dip), env/b-content (first-time onboarding cards, Tab sheet fixes), D-096 dismiss_tip action. p 73/0, a/b targeted green, P1 slice 10/0.
- 2026-10-13 21:15: **round 50 ON ORIGIN**: env/p-play 13da95e8 (viewmodel camera sees viewmodel_lit layer 21; new per-shot muzzle-flash light). p 72/0.
- 2026-10-13 21:10: **round 49 ON ORIGIN**: env/p-play 42dfaf93 (ADS sights aligned on the current animated pose; centred from 0.1 s). Tip for all: windowed visual checks use `--fixed-fps 60`.
- 2026-10-13 21:05: **round 48 ON ORIGIN**: env/p-play f11b4df1 (hip framing for all 34 FP guns, enforced by test_po4_viewmodel_classes; brute_12 hand on the fore-end).
- 2026-10-13 21:00: **round 47 ON ORIGIN**: env/b-content 7d29463b (pre-planning restyled, 4K pass clean, breadcrumbs, hub/payday polish; h01-h04 live captures). Targeted b green.
- 2026-10-13 20:50: full gate on round 40 (1916db6e): 1817 tests, 3 failed, all known: options_palettes (FIXED r41), p3_loud test_10 (FIXED r43), p3_loud test_01 (KR-1, A); validate_level KR-3 night_deposit zfight + KR-4 shadow_ledger barred_doors still open (A).
- 2026-10-13 20:45: **round 46 ON ORIGIN**: env/b-content 934e355a (review PNGs in game/content/ui/_review/after/: r_* restyled screens, h01 casing with real NPCs + hints, h02 masked with objective markers; refusal cue; perk grid pad scroll). Targeted b green.
- 2026-10-13 20:35: **round 45 ON ORIGIN**: env/p-play 2c8cc473 (corsair AR hip pose in front of the lens, PD2 pad yaw ramp; Options slider is a multiplier on D-091 gain). p 70/0.
- 2026-10-13 20:25: **round 44 ON ORIGIN**: env/b-content 8070c7c7 (8 screen families restyled to Case File, 720p fixes, objective-marker label/priority fixes; B full dir 824/0).
- 2026-10-13 20:35: **round 43 ON ORIGIN**: env/a-core 5ebe9f86 (KR-2 FIXED: bot unstick on Dockside van; L2.5 downed bots no longer count pre-down shots; KR-1 partly, director pressure under review), env/p-play 0cb3e25f (viewmodel lit: key light on the vm layer, D-094). p 63/0, a targeted + P1 slice green.
- 2026-10-13 20:15: **round 42 ON ORIGIN**: env/a-core 097d8432 (ui_hud 1.8 objective_markers live; lockdown advances the Glasshouse objective; PO-5.7 NpcVisuals: police/guards/civilians wear the real character models, no more capsules), env/b-content 350040b1 (casing guidance strings, briefing timeline, pad glyphs). Lead hotfix: G.CHARACTERS_DIR contract constant (banned hard path in npc_visuals.gd). Targeted a/b + P1 slice 10/0 green.
- 2026-10-13 20:00: **round 41 ON ORIGIN**: env/b-content 4641bae1 (mask-up ring, weapon HUD hidden until masked, lockdown objective skip, difficulties unlock in order, 10 UI cues + UiSfx, ObjectiveMarkers widget awaiting A's model). Targeted b + c audio green. Full gate on round 40 running in background.
- 2026-10-13 19:55: **round 40 ON ORIGIN**: env/a-core d485b51f (PO-5.8 safe actually opens after the drill, 5.11 unlocked doors open while casing, 5.12 keypad safe objective, 5.2 civilians, 5.3 bots follow/hold fire). Targeted a/c/integration/b green; P1 slice 10/0. D-093 tase soft-lock ruling.
- 2026-10-13 19:40: **round 39 ON ORIGIN**: env/b-content 29112dd9 (loadout slot cards + picker grid + stat bars, main-menu mask hero, payday count-up, heister names fix). Targeted b files green. Routed: P, AR viewmodel canted/black in B's h03 capture (top priority).
- 2026-10-13 19:05: **round 38 ON ORIGIN**: env/b-content a7be953b (frameless HUD, heister names, starter AR weapon.corsair_ar, main-menu mask hero), env/p-play c1b3c2ad (D-091 sensitivity, windowed kerb walk PASS). Targeted b files, p 62/0, P1 slice 10/0 green. D-092 parallel lanes dispatched to all envs.
- 2026-10-13 18:35: **round 37 ON ORIGIN**: env/b-content e8f0537c (MouseCapture migration done, KR-5/KR-6 fixed, skill tabs, objective flash, Reduce Motion), env/p-play a9f18319 (PO-1 verified via real flow: capture + G mask-up work, cause was missing UI hints; PO-3 probe: 0 snags on ~150k edges). Targeted tests green.
- 2026-10-13 18:40: **round 36 ON ORIGIN** 3533f4d7: env/p-play 6596da59 (PO-2 MouseCapture), env/b-content ce7abdc0 (PO-4 "Case File" first pass). p 60/0, b 809 with known red routed to B:
  - KR-5 test_pp_full_loop:test_full_loop_mouse_keyboard "back in the hub" after payday
  - (KR-5/KR-6 FIXED in round 37.)
  - KR-2 note: P shows test_p3_loud:test_10 fails identically on pre-PO-2 base 7a417116 → A's crew-AI follow.
  - KR-6 test_pp_gamepad_flow:test_board_take_contract_gamepad_only, d-pad focus lands on Pin2, not Take
- 2026-10-13 17:40: **round 35 ON ORIGIN** = all five env branches (a, b, c, d, p) as left by the Grok team + D-086..D-088 docs
  + lead fixes (lint, P4 ratchet shrink, crowd-LOD material exemption). Full gate 1803 tests: pushed with **known red** (D-088),
  each routed to ENV A:
  - KR-1 `test_p3_loud.gd:test_01` "at least one crew member always on its feet" (likely eef2e200: police never cuff AI crew)
  - KR-2 `test_p3_loud.gd:test_10` "follow: the AI caught up with the human"
  - KR-3 validate_level night_deposit zfight: KitchenCounter vs Slot_kc_break_locker keycard @ (15.8, 0.9, 0.6) (3c3a31c5 moved it)
  - KR-4 validate_level shadow_ledger barred_doors: StairAGate (14.14, 0.15, 15.10), StairBGate (23.13, 0.15, 15.10) navmesh crosses BARRED doorway
  - Info for A (PP-C-1 walk rows, not failures): night_deposit STUCK-DOOR at AtmInnerDoor (23.4,0,17.6), AlarmSecurity (21.7,0,18.0), SallyPersonnelDoor (13.2,0,1.5).

## Rules in force
- D-088: targeted checks only before env pushes; the full gate runs at the lead per merge round, in the background.

## Open questions (id → answer)
- QC-61 (C): is the GH fire escape a real stealth entry? → YES (glasshouse.md route 3, open_window variable). PD2 has no mantle: make the break-room window a walkable fire-escape door-window (sill ≤ 0.35 m, opening ≥ 1.0 × 1.9 m), restore a layer-1 link only through the opening when ow_breakroom_open; latched = glass breaks (noise 15 m) then passable. C builds map; A checks the glass/noise interaction. Stairs (NPC wedge at 0.175 m riser): invisible ramp colliders through the nosings on GH + ND flights (C), now, ahead of determinism.
- QP-2/QP-3 world lights on the viewmodel → render layer **21** `viewmodel_lit` (visual_slots 1.2, D-095; 20 was taken).
- QB-4 RangeSpectatorInput as a gameplay owner → OK, input_focus 1.2.
- QP-1 where was the PO's bump → asked the product owner; working assumption: their build predated step-up (round 35).
- QB-1 starter primary in default profile → YES (data only, existing AR; closes PP-P-10).
- QB-2 fonts → built-in font + FontVariation final for this pass.
- QB-3 docs/design/ui/** → B's (owners.json on trunk since aefdfa70).

- QA-PO5-1 objective world markers → APPROVED, ui_hud 1.8 (D-089). A implements LocalHudModel.objective_markers; B draws them.

- QA-PO5-2 tase soft-lock → helpless 30 s → custody, no down (D-093).

## Backlog for dormant envs (wake decision: LEAD)
- C: PP-C-1 walk test can't pass LOCKPICK doors unmasked and chains 0 m legs after teleports (ND STUCK-DOOR rows are test artefacts, maps are fine; A 21:49).
- D (parked after P's D-101 attempt 00:55): rifle-family left-hand cup needs B to move LeftHandIK below the fore-end on ~20 weapons + re-timed lever clip; cosmetic. Pistol ADS forearm size: closed, matches PD2 within the rig's proportions.

## Routed findings
- gh_stealth lane (A, ~20 runs; best: bag 1 secured undetected at t=243; all failures civilians): A fixes civilian wander scope, stair-foot pin, shout LOS/same floor, calm NPCs yield. C: GH break-room WindowLink + BreakRoomWindowBlocker (walker stuck at U1 window, ow_breakroom_open, seed 1791937091) + stair-foot corner (13.4-13.8,0,4.8). B: HUD per-frame cost (7-20 s process frames masked on llvmpipe; onboarding card) profile + budget test.
- A (gate70, 04:xx): CHECK_ALL FAIL on GDScript runtime errors only (1897 tests 0 failed, 4 levels PASS): bulwark_shield.gd take_hit↔deliver_hit infinite pierce recursion (overlapping shields ping-pong; _trace_behind excludes only its own RID). Routed to A ahead of door swing. → FIXED r73 (A 35baf6dd).
- (DONE r70) SL/DB marker_tags; test_heist_readiness green on all 4 heists.
- A: loud transition doesn't advance the Glasshouse objective (still "Find the manager's keycard"); NPCs render as grey capsules while casing.
- A (PO-5.x, interim 18:19): civilians no longer body-block (5.2), AI crew leash/cover need LOS + downed bots hold fire (5.3), solo Routine 31 enemies by t=180 (5.4), drill works but 180 s (5.8), police as white capsules (5.7, A diagnosing). B: PO-5.5 no primary (QB-1 yes), 5.6 "{count}/{total}" placeholder + keycard objective in lockdown, 5.9 Brutal unlocked while Tense/Hazardous locked.
- P: FP pistol visible while casing → FIXED (no weapon while casing). B: crosshair hidden while casing (ruling 20:35).

## Cross-env handoffs in flight
- P → B: `MouseCapture` (input_focus.md). B migrates its 4 direct `Input.mouse_mode` writers after P's module is on trunk.
- B ← P: HUD prompt for casing / mask-up (PO-1) and "click to capture" hint (PO-2), via `casing_blocked` signal + `MouseCapture.notifier().changed`.
