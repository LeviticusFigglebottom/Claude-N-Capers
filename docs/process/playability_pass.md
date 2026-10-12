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
| PP-P-8 | A | Safe._inner_loot (safe.gd:129-130, 386-398) disables the safe's own child DrillPoint as if it were loot: SafeDrill never usable; the Safe's place_drill still works (two drill prompts design) |
| PP-P-9 | A/C | Navmesh routes through locked closed doors (Glasshouse SalonDoor, LOCKPICK, loud) - player-facing paths/AI must lockpick or detour; confirm intended (heist_map.md §3) |
| PP-P-10 | B | P1 default loadout has no primary and a suppressed pistol: a player cannot go loud by shooting (by design? confirm) |
| PP-P-11 | P | Hip-fire suppressed pistol reads ~40 deg canted on screen: weapon bone is within ~5 deg of straight; perspective of a long gun 0.36 m from a 70 deg camera (viewmodel FOV ruling needed) |
| PP-P-12 | C | Glasshouse navmesh agent_radius 0.3 (glasshouse.tscn:2579) < crew capsule 0.35 (crew_member.tscn:11): paths hug door jambs, player/bots snag at SalonDoor (12.5,0,9.3) |
| PP-L-1 | LEAD | P2 ghost run: antechamber laser walk fails on Night Deposit seed 2001 |
Envs append rows as they find issues while playing.
