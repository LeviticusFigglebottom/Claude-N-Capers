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
| PP-L-1 | LEAD | P2 ghost run: antechamber laser walk fails on Night Deposit seed 2001 |
Envs append rows as they find issues while playing.
