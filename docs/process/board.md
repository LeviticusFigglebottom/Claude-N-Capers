# BOARD (team v3, D-086)

Owner: **LEAD** (only the lead edits this file; envs send updates with `send_message`). Newest first in each section.
Read it at the start of every work session.

## Sessions
| Role | Session id | Branch | Focus now |
|---|---|---|---|
| LEAD | session_014E3p2DmSYTneJjytGwKKfc | claude/dreamy-hamilton-pc7vck | merges, rulings, contracts, gates |
| ENV P | session_01FYVVhNtxKAoQmyfnZ9rb3t | env/p-play | PO-2 mouse capture, PO-1 casing exit, PO-3 bumps |
| ENV B | session_0159qCTRV9CsDQs465nGSW28 | env/b-content | PO-4 UI/UX overhaul (style spec first) |
| ENV A | session_015kTjrZsUFn7gLqNVwAXdkh | env/a-core | PO-5 end-to-end windowed playthrough + blockers |

## Trunk / merge rounds
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
- QP-2 world lights on the viewmodel → render layer 20 `viewmodel_lit` (visual_slots 1.1, D-094).
- QB-4 RangeSpectatorInput as a gameplay owner → OK, input_focus 1.2.
- QP-1 where was the PO's bump → asked the product owner; working assumption: their build predated step-up (round 35).
- QB-1 starter primary in default profile → YES (data only, existing AR; closes PP-P-10).
- QB-2 fonts → built-in font + FontVariation final for this pass.
- QB-3 docs/design/ui/** → B's (owners.json on trunk since aefdfa70).

- QA-PO5-1 objective world markers → APPROVED, ui_hud 1.8 (D-089). A implements LocalHudModel.objective_markers; B draws them.

- QA-PO5-2 tase soft-lock → helpless 30 s → custody, no down (D-093).

## Backlog for dormant envs (wake decision: LEAD)
- D: rifle idle left hand authored fingers-up on the handguard side (PD2 cups underneath); reads odd, not broken.
- D: ADS forearm size vs vm FOV 52 (P investigating).

## Routed findings
- A: loud transition doesn't advance the Glasshouse objective (still "Find the manager's keycard"); NPCs render as grey capsules while casing.
- A (PO-5.x, interim 18:19): civilians no longer body-block (5.2), AI crew leash/cover need LOS + downed bots hold fire (5.3), solo Routine 31 enemies by t=180 (5.4), drill works but 180 s (5.8), police as white capsules (5.7, A diagnosing). B: PO-5.5 no primary (QB-1 yes), 5.6 "{count}/{total}" placeholder + keycard objective in lockdown, 5.9 Brutal unlocked while Tense/Hazardous locked.
- P: FP pistol visible while casing → FIXED (no weapon while casing). B: crosshair hidden while casing (ruling 20:35).

## Cross-env handoffs in flight
- P → B: `MouseCapture` (input_focus.md). B migrates its 4 direct `Input.mouse_mode` writers after P's module is on trunk.
- B ← P: HUD prompt for casing / mask-up (PO-1) and "click to capture" hint (PO-2), via `casing_blocked` signal + `MouseCapture.notifier().changed`.
