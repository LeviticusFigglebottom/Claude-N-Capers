# Playability pass (D-082)

Owner: LEAD. Goal: the game is practically playable start to finish, proven by a test suite that plays like a person.

## Real-player suite rules
- Input only through `Input.parse_input_event` (key/mouse button/mouse motion) from a `PlayerInputDriver` (ENV A core,
  ENV P runner under `game/tests/p/real/`). No `teleport_crew`, no `CrewIntent` injection, no direct state writes.
- The driver steers by mouse motion toward nav-path waypoints and presses keys with human timings (holds, taps).
- Each heist gets a full stealth run and a loud run from main menu → hub → loadout → heist → payday → hub.
- Failures are logged as issues below with a repro seed.

## Issue list (initial, team-built; ids PP-<env>-n)
| id | owner | issue |
|---|---|---|
| PO-1 | P (+A) | **Product owner:** cannot leave casing mode. Reproduce windowed: hold G (mask_up). Suspects: a focused/visible Control blocking all polled gameplay input (8b770a5a rule), mask-up gated on something else, no on-screen prompt. Fix + windowed test + HUD prompt (B) |
| PO-2 | P (+B) | **Product owner:** the game never captures the mouse, so you cannot turn. Root cause: nothing writes MOUSE_MODE_CAPTURED in a heist (only safehouse_host); tests fake it (test_assume_captured). Fix per input_focus.md (D-087) |
| PO-3 | P (+A) | **Product owner:** cannot walk up a slight bump in the road. Step-up landed in round 35 (P1-01) but was only tested on test geometry: walk every road/curb/kerb/ramp/threshold on all 4 heists windowed; fix in controller (P) or collision (A, D-086) |
| PO-4 | B | **Product owner:** UIs are cluttered, unintuitive, uninspired/unstyled. Full UI/UX overhaul: style spec `docs/design/ui/style.md` (GSR-consistent, heist-thriller identity), HUD declutter, menu/hub/loadout/payday flows, first-time guidance (control hints: hold G to mask up, click to capture, Esc pause) |
| PO-5 | A | End-to-end windowed playthrough as a person: main menu → hub → loadout → Glasshouse stealth win and loud win → payday → hub, then Night Deposit / Shadow Ledger / Dockside. Every blocker becomes a row here (open items from round 35: loud safe drill never opens in 400 s, police cuff AI crew, brute_12 left hand) |
| PP-B-1 | B | Duplicate Career / Notoriety buttons in the hub |
| PP-B-2 | B | Hub cards off-screen at 1280×720 |
| PP-B-3 | B | Payday card auto-picks after 30 s (PD2: player picks; review timer) |
| PP-P-1 | P | Step-up / snap-down on 5–40 cm steps, ramps, stairs untested (P1-01) |
| PP-P-2 | P | Spurious STEALTH hop when the alarm fires while casing (P1-02) |
| PP-P-3 | P | ADS audit: sway, FOV, sensitivity, transitions (P1-03) |
| PP-A-1 | A | Real-input driver + mouse-look aim that a test can use (blocks the suite) |
| PP-A-2 | A | Domination per D-079 (range/cone/hostage count) verified by real shouting |
| PP-C-1 | C | Walk every heist by real input: stuck spots, nav holes, doors, ladders, objective reachability |
| PP-C-2 | C | Dockside Burn: ≥2 non-breach approaches per holdout, hall cover (P3 blocker) |
| PP-D-1 | D | Special/enemy readability at 10–40 m in real lighting (D-080) |
| PP-P-4 | P | FIXED 0e1315a8 (PI-24): swap button did nothing after picking a slot with 1/2 or a failed equip |
| PP-P-5 | P | FIXED 839c0330 (PI-25): jump pressed in the air / held through landing was eaten by the jump latch |
| PP-P-6 | P | FIXED 5b863e1b (PI-08): icy stop from sprint (0.19 s); grounded deceleration 50 |
| PP-P-7 | C | Glasshouse MainEntrance (glasshouse.tscn:10518) not openable while casing (casing_allowed=false); ruling: public doors open unmasked (C) |
| PP-P-8 | A | FIXED by A ddda749e: Safe._inner_loot (safe.gd:129-130, 386-398) disables the safe's own child DrillPoint as if it were loot: SafeDrill never usable; the Safe's place_drill still works (two drill prompts design) |
| PP-P-9 | A/C | Navmesh routes through locked closed doors (Glasshouse SalonDoor, LOCKPICK, loud) - player-facing paths/AI must lockpick or detour; confirm intended (heist_map.md §3) |
| PP-P-10 | B | P1 default loadout has no primary and a suppressed pistol: a player cannot go loud by shooting (by design? confirm) |
| PP-P-11 | P | FIXED (Lead ruling 20:23): separate PD2-style viewmodel camera, fixed 52 deg (FpViewmodelTweak.viewmodel_fov_deg), world FOV/ADS no longer stretch the gun. Shotgun left hand: marker is B-exact (-0.026,0.046,-0.33) in weapon space; the 0.52 m was camera depth (weapon bone 0.20 m + 0.33), IK reaches it (influence 1) - no reach error |
| PP-P-12 | P | Nav radius 0.30 < capsule 0.35 is intended (D-085). SalonDoor passes 24/24 once open (C); not a real snag - SKIPPED by Lead. Note: a head-on approach from 0.55 m off the doorway (z 9.3/10.7) still stops (edge_assist_m 0.45); WIP test in /workspace/cnc-team/p/wip/ |
| PP-L-1 | LEAD | P2 ghost run: antechamber laser walk fails on Night Deposit seed 2001 |
Envs append rows as they find issues while playing.
