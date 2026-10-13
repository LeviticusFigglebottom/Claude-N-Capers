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
- 2026-10-13 18:35: **round 37 ON ORIGIN**: env/b-content e8f0537c (MouseCapture migration done, KR-5/KR-6 fixed, skill tabs, objective flash, Reduce Motion), env/p-play a9f18319 (PO-1 verified via real flow: capture + G mask-up work, cause was missing UI hints; PO-3 probe: 0 snags on ~150k edges). Targeted tests green.
- 2026-10-13 18:40: **round 36 ON ORIGIN** 3533f4d7: env/p-play 6596da59 (PO-2 MouseCapture), env/b-content ce7abdc0 (PO-4 "Case File" first pass). p 60/0, b 809 with known red routed to B:
  - KR-5 test_pp_full_loop:test_full_loop_mouse_keyboard "back in the hub" after payday
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
- QB-4 RangeSpectatorInput as a gameplay owner → OK, input_focus 1.2.
- QP-1 where was the PO's bump → asked the product owner; working assumption: their build predated step-up (round 35).
- QB-1 starter primary in default profile → YES (data only, existing AR; closes PP-P-10).
- QB-2 fonts → built-in font + FontVariation final for this pass.
- QB-3 docs/design/ui/** → B's (owners.json on trunk since aefdfa70).

- QA-PO5-1 objective world markers → APPROVED, ui_hud 1.8 (D-089). A implements LocalHudModel.objective_markers; B draws them.

## Routed findings
- A: loud transition doesn't advance the Glasshouse objective (still "Find the manager's keycard"); NPCs render as grey capsules while casing.
- A (PO-5.x, interim 18:19): civilians no longer body-block (5.2), AI crew leash/cover need LOS + downed bots hold fire (5.3), solo Routine 31 enemies by t=180 (5.4), drill works but 180 s (5.8), police as white capsules (5.7, A diagnosing). B: PO-5.5 no primary (QB-1 yes), 5.6 "{count}/{total}" placeholder + keycard objective in lockdown, 5.9 Brutal unlocked while Tense/Hazardous locked.
- P: FP pistol + crosshair visible while casing (PD2: no weapon out).

## Cross-env handoffs in flight
- P → B: `MouseCapture` (input_focus.md). B migrates its 4 direct `Input.mouse_mode` writers after P's module is on trunk.
- B ← P: HUD prompt for casing / mask-up (PO-1) and "click to capture" hint (PO-2), via `casing_blocked` signal + `MouseCapture.notifier().changed`.
