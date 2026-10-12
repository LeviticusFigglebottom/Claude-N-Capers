# PP-C-1: real-input walk of every ENV C heist (D-082)

Owner: ENV C. Harness: `game/tests/c/test_pp_c1_walks.gd` (PInputDriver from ENV P a43d33b7, working tree only;
InputMap actions + mouse look, no set_bot_intent). Slot 0 walks the navmesh path from the player spawn to up to 14
gameplay use points (greedy nearest-first), turning at each corner with turn_to_yaw and holding move_forward; a stalled
leg gets an `interact` hold, then a retry; still stalled = STUCK row, and the walk resumes from the target by a logged
setup teleport. Shortcuts: skip_casing, no AI teammates, NPCs despawned, Routine, seed 1001.
Box runs 2026-10-12 ~18:00 ET (run 1: 3/3 heists; run 2 with a 10 s interact hold: glasshouse + night_deposit identical,
then the runner was killed externally, exit 143). Shadow Ledger not walked: its G2 WIP is reverted (does not build).

## Summary
| heist | legs ok / walked | stuck | m walked |
|---|---|---|---|
| glasshouse | 4 / 14 | 10 | 57 |
| night_deposit | 5 / 14 | 9 | 95 |
| dockside_burn | 2 / 14 | 12 | 141 |

## Leading hypothesis (PP-C-1-01, needs confirmation)
Every navmesh is baked with `agent_radius = 0.3` (all four build_greybox.gd), but the crew capsule is `radius = 0.35`
(crew_member.tscn). Path corners at doorways and prop edges therefore sit 0.3 m off the jamb, and the 0.35 m capsule
snags: almost every stall is 0.7-1.0 m before a corner next to a doorway or a display case, with 0.0-0.6 m of progress,
and a 10 s interact hold did not change any row (so these are not closed doors). Impact on players: AI teammates and
any nav-following crew logic (same capsule) jam at doors; a human can steer round it, so the harness overstates it for
humans. Proposed fix (ENV C): re-bake every map at agent_radius 0.35 (+ validate_level, walkthrough, test_p3_loud),
after LEAD confirms the crew capsule is final (ENV P owns the controller).

## Rows (run 1)
| heist | kind | target | detail |
|---|---|---|---|
| glasshouse | STUCK | `Gameplay/DisplayCases/WallCaseB` | at (10.6, 0.0, 12.4): stalled before corner (10.4, 0.2, 11.5) (no progress after interact (0.6 m of 1.2 m)) |
| glasshouse | STUCK | `Gameplay/Misc/PhoneAdmin` | at (1.5, 0.0, 6.4): stalled before corner (1.5, 0.2, 5.400001) (no progress after interact (0.0 m of 1.0 m)) |
| glasshouse | STUCK | `Gameplay/Doors/BreakRoomDoor` | at (3.8, 4.2, 6.4): stalled before corner (3.600002, 4.4, 5.6) (no progress after interact (0.0 m of 0.8 m)) |
| glasshouse | STUCK | `Gameplay/Misc/CameraStation` | at (7.7, 4.2, 4.9): stalled before corner (7.761405, 4.4, 4.149124) (no progress after interact (0.5 m of 0.9 m)) |
| glasshouse | STUCK | `Gameplay/Workshop/WorkshopSafe/SafeLoot` | at (8.2, 4.2, 4.1): stalled before corner (8.400002, 4.4, 5.0) (no progress after interact (0.0 m of 0.9 m)) |
| glasshouse | STUCK | `Gameplay/Doors/WorkshopDoor` | at (7.2, 0.0, 4.1): stalled before corner (7.471429, 0.2, 5.0) (no progress after interact (0.6 m of 0.9 m)) |
| glasshouse | STUCK | `Gameplay/DisplayCases/IslandCaseB` | at (1.8, 0.0, 5.6): stalled before corner (1.727587, 0.2, 6.396551) (no progress after interact (0.0 m of 0.8 m)) |
| glasshouse | STUCK | `Gameplay/Doors/StockDoor` | at (12.6, 0.0, 9.8): stalled before corner (13.5, 0.2, 9.600002) (no progress after interact (0.0 m of 0.9 m)) |
| glasshouse | STUCK | `Gameplay/DisplayCases/SalonCaseB` | at (16.8, 0.0, 5.6): stalled before corner (16.7, 0.2, 6.300001) (no progress after interact (0.0 m of 0.7 m)) |
| glasshouse | STUCK | `Gameplay/Windows/SalonEast` | at (13.4, 0.0, 10.2): stalled before corner (12.6, 0.2, 10.4) (no progress after interact (0.0 m of 0.8 m)) |
| night_deposit | STUCK | `Gameplay/Vault/Box3` | at (9.8, 0.0, 20.4): stalled before corner (9.900002, 0.2, 19.58) (no progress after interact (1.3 m of 1.5 m)) |
| night_deposit | STUCK | `Gameplay/Doors/VaultDoor` | at (14.0, -4.0, 10.4): stalled before corner (13.99762, -3.8, 9.505014) (no progress after interact (0.0 m of 0.9 m)) |
| night_deposit | STUCK | `Gameplay/Doors/VaultGate` | at (14.0, -4.0, 7.9): stalled before corner (14.0, -3.8, 6.9) (no progress after interact (0.0 m of 1.0 m)) |
| night_deposit | STUCK | `Gameplay/Misc/PhoneLoan` | at (23.8, 0.0, 7.1): stalled before corner (23.85, 0.2, 8.6) (no progress after interact (0.0 m of 1.5 m)) |
| night_deposit | STUCK | `Gameplay/Doors/FireExit` | at (23.8, 0.0, 7.9): stalled before corner (23.9, 0.2, 7.100002) (no progress after interact (0.0 m of 0.8 m)) |
| night_deposit | STUCK | `Gameplay/Atms/AtmCash2` | at (24.2, 0.0, 7.0): stalled before corner (22.35714, 0.2, 9.028573) (no progress after interact (1.4 m of 3.8 m)) |
| night_deposit | STUCK | `Gameplay/Misc/AlarmSecurity` | at (21.4, 0.0, 17.8): stalled before corner (20.6, 0.2, 17.7) (no progress after interact (0.0 m of 0.8 m)) |
| night_deposit | STUCK | `Gameplay/Doors/SallyPersonnelDoor` | at (11.7, 0.0, 5.6): stalled before corner (11.6, 0.2, 6.5) (no progress after interact (0.0 m of 0.9 m)) |
| night_deposit | STUCK | `Gameplay/Doors/XferDoor` | at (6.2, 0.0, -0.4): stalled before corner (5.900002, 0.2, 0.299999) (no progress after interact (0.3 m of 0.7 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/GatehouseSouth` | at (29.3, 0.0, -32.5): stalled before corner (27.16243, 0.200001, -31.36127) (no progress after interact (2.5 m of 1.1 m)) |
| dockside_burn | STUCK | `Gameplay/Misc/GoodsLift` | at (5.9, 0.0, -0.4): stalled before corner (5.699997, 0.200001, 0.599998) (no progress after interact (0.0 m of 1.0 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/WSCorridor` | at (18.4, 0.0, 8.7): stalled before corner (17.31458, 0.200001, 6.914587) (no progress after interact (0.2 m of 2.3 m)) |
| dockside_burn | STUCK | `Gameplay/Misc/DispatchSafe` | at (12.2, 0.0, 6.4): stalled before corner (11.88701, 0.200001, 5.599998) (no progress after interact (0.4 m of 0.8 m)) |
| dockside_burn | STUCK | `Gameplay/Misc/DeskCashO1` | at (11.7, 0.0, 5.6): stalled before corner (11.60001, 0.200001, 6.5) (no progress after interact (0.0 m of 0.9 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/O1Front` | at (6.1, 0.0, 0.4): stalled before corner (6.051613, 0.200001, -0.5) (no progress after interact (0.3 m of 0.9 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/StairGround` | at (5.9, 0.0, -0.4): stalled before corner (5.699997, 0.200001, 0.599998) (no progress after interact (0.0 m of 1.0 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/StairMezz` | at (1.8, 0.0, 6.4): stalled before corner (1.300003, 0.200001, 5.700005) (no progress after interact (0.6 m of 0.7 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/MCWest` | at (0.4, 3.6, 6.9): stalled before corner (-0.300003, 3.8, 6.960001) (no progress after interact (0.3 m of 0.7 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/PKPlant` | at (-0.4, 3.6, 7.1): stalled before corner (0.300003, 3.8, 6.900002) (no progress after interact (0.3 m of 0.7 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/PKRoller` | at (12.1, 0.0, 31.6): stalled before corner (11.90001, 0.200001, 32.3) (no progress after interact (0.3 m of 0.7 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/ChamberANorth` | at (12.1, 0.0, 32.4): stalled before corner (12.14763, 0.200001, 31.5) (no progress after interact (0.0 m of 0.9 m)) |
