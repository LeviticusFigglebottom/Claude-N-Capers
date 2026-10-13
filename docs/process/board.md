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
- D: rifle idle left hand authored fingers-up on the handguard side (PD2 cups underneath); reads odd, not broken.
- D: ADS forearm size vs vm FOV 52 (P investigating).

## Routed findings
- A: loud transition doesn't advance the Glasshouse objective (still "Find the manager's keycard"); NPCs render as grey capsules while casing.
- A (PO-5.x, interim 18:19): civilians no longer body-block (5.2), AI crew leash/cover need LOS + downed bots hold fire (5.3), solo Routine 31 enemies by t=180 (5.4), drill works but 180 s (5.8), police as white capsules (5.7, A diagnosing). B: PO-5.5 no primary (QB-1 yes), 5.6 "{count}/{total}" placeholder + keycard objective in lockdown, 5.9 Brutal unlocked while Tense/Hazardous locked.
- P: FP pistol visible while casing → FIXED (no weapon while casing). B: crosshair hidden while casing (ruling 20:35).

## Cross-env handoffs in flight
- P → B: `MouseCapture` (input_focus.md). B migrates its 4 direct `Input.mouse_mode` writers after P's module is on trunk.
- B ← P: HUD prompt for casing / mask-up (PO-1) and "click to capture" hint (PO-2), via `casing_blocked` signal + `MouseCapture.notifier().changed`.
