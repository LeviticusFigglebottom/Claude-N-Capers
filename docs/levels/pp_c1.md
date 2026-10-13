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


## Rerun 2026-10-12 19:52-20:14 ET (scratch/c-walks = env/c-worlds d97a7371 + A 488e7685 + P 5b863e1b)
| heist | corners (AI path) ok / stuck | doors (human) ok / stuck |
|---|---|---|
| glasshouse | 4 / 10 | 1 / 13 |
| night_deposit | 4 / 10 | 3 / 11 |
| dockside_burn | 2 / 12 | 2 / 12 |
| Glasshouse SalonDoor (opened by setup), 6 crossings each | stealth 6/6, loud 6/6 | stealth 6/6, loud 6/6 |

Reading: nearly every stall is 0.4-0.7 m in front of a door with 0.0 m progress after a 10 s interact hold, in both
modes; the SalonDoor frame, once open, passes every crossing. So the stalls are CLOSED doors that the harness's
interact hold does not open (the player is not aimed at the leaf), not capsule snags. SalonDoor frame: not a real snag.
All rows are the human player (slot 0 via PInputDriver); "AI" = the nav-corner path, no AI follower or guard was
driven. Next harness fix: aim at the door leaf before the interact hold.

| glasshouse | STUCK-AI | `Gameplay/DisplayCases/WallCaseB` | at (10.6, 0.0, 12.4), nearest door `MainEntrance` 0.8 m: stalled before corner (10.4, 0.2, 11.5) (no progress after interact (0.8 m of 1.3 m)) |
| glasshouse | STUCK-AI | `Gameplay/Misc/PhoneAdmin` | at (1.5, 0.0, 6.4), nearest door `StaffDoor` 0.4 m: stalled before corner (1.5, 0.2, 5.400001) (no progress after interact (0.0 m of 1.0 m)) |
| glasshouse | STUCK-AI | `Gameplay/Doors/BreakRoomDoor` | at (3.7, 4.2, 6.4), nearest door `AdminDoor` 0.5 m: stalled before corner (3.700001, 4.4, 5.6) (no progress after interact (0.0 m of 0.8 m)) |
| glasshouse | STUCK-AI | `Gameplay/Misc/CameraStation` | at (7.7, 4.2, 4.9), nearest door `SecurityDoor` 0.5 m: stalled before corner (7.761405, 4.4, 4.149124) (no progress after interact (0.5 m of 0.9 m)) |
| glasshouse | STUCK-AI | `Gameplay/Workshop/WorkshopSafe/SafeLoot` | at (8.2, 4.2, 4.1), nearest door `SecurityDoor` 0.4 m: stalled before corner (8.400002, 4.4, 5.0) (no progress after interact (0.1 m of 0.9 m)) |
| glasshouse | STUCK-AI | `Gameplay/Doors/WorkshopDoor` | at (7.3, 0.0, 4.1), nearest door `WorkshopDoor` 0.4 m: stalled before corner (7.471429, 0.2, 5.0) (no progress after interact (0.0 m of 0.9 m)) |
| glasshouse | STUCK-AI | `Gameplay/DisplayCases/IslandCaseB` | at (1.2, 0.0, 5.6), nearest door `StaffDoor` 0.5 m: stalled before corner (1.700001, 0.2, 6.300001) (no progress after interact (0.0 m of 0.8 m)) |
| glasshouse | STUCK-AI | `Gameplay/Doors/StockDoor` | at (12.6, 0.0, 9.8), nearest door `SalonDoor` 0.4 m: stalled before corner (13.5, 0.2, 9.600002) (no progress after interact (0.0 m of 0.9 m)) |
| glasshouse | STUCK-AI | `Gameplay/DisplayCases/SalonCaseB` | at (16.2, 0.0, 5.6), nearest door `SalonBackDoor` 0.5 m: stalled before corner (16.56552, 0.2, 6.255173) (no progress after interact (0.5 m of 0.7 m)) |
| glasshouse | STUCK-AI | `Gameplay/Windows/SalonEast` | at (13.4, 0.0, 10.3), nearest door `SalonDoor` 0.5 m: stalled before corner (12.6, 0.2, 10.4) (no progress after interact (0.0 m of 0.8 m)) |
| night_deposit | STUCK-AI | `Gameplay/Vault/Box3` | at (9.3, 0.0, 20.6), nearest door `MainEntrance` 1.3 m: stalled before corner (9.900002, 0.2, 18.0) (no progress after interact (0.0 m of 2.6 m)) |
| night_deposit | STUCK-AI | `Gameplay/Doors/VaultDoor` | at (14.0, -4.0, 10.4), nearest door `VaultDoor` 0.4 m: stalled before corner (13.99663, -3.8, 9.50491) (no progress after interact (0.0 m of 0.9 m)) |
| night_deposit | STUCK-AI | `Gameplay/Doors/VaultGate` | at (14.0, -4.0, 7.9), nearest door `VaultGate` 0.4 m: stalled before corner (14.0, -3.8, 6.9) (no progress after interact (0.0 m of 1.0 m)) |
| night_deposit | STUCK-AI | `Gameplay/Doors/ElectricalDoor` | at (8.4, -2.0, 1.0), nearest door `SallyPersonnelDoor` 3.3 m: stalled before corner (8.0, 0.2, 4.400002) (no progress after interact (0.0 m of 3.4 m)) |
| night_deposit | STUCK-AI | `Gameplay/Misc/PhoneLoan` | at (23.3, 0.0, 7.1), nearest door `LoanCorridorDoor` 0.5 m: stalled before corner (23.60455, 0.2, 8.0) (no progress after interact (0.5 m of 0.9 m)) |
| night_deposit | STUCK-AI | `Gameplay/Atms/AtmCash2` | at (20.2, 0.0, 7.0), nearest door `ElectricalDoor` 1.3 m: stalled before corner (22.35714, 0.2, 9.028573) (no progress after interact (0.0 m of 2.9 m)) |
| night_deposit | STUCK-AI | `Gameplay/Doors/AtmInnerDoor` | at (23.4, 0.0, 17.6), nearest door `AtmInnerDoor` 2.4 m: stalled before corner (21.7, 0.2, 18.0) (no progress after interact (0.0 m of 1.8 m)) |
| night_deposit | STUCK-AI | `Gameplay/Misc/AlarmSecurity` | at (21.7, 0.0, 18.0), nearest door `AtmInnerDoor` 0.7 m: stalled before corner (20.4, 0.2, 18.0) (no progress after interact (0.0 m of 1.3 m)) |
| night_deposit | STUCK-AI | `Gameplay/Doors/SallyPersonnelDoor` | at (13.2, 0.0, 1.5), nearest door `WCDoor` 4.4 m: stalled before corner (12.88868, 0.2, 2.577657) (no progress after interact (0.0 m of 1.1 m)) |
| night_deposit | STUCK-AI | `Gameplay/Doors/XferDoor` | at (6.0, 0.0, -0.9), nearest door `SallyPersonnelDoor` 0.9 m: stalled before corner (5.900002, 0.2, 0.299999) (no progress after interact (0.0 m of 1.2 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Doors/GatehouseSouth` | at (27.2, 0.0, -32.4), nearest door `GatehouseNorth` 0.4 m: stalled before corner (27.18333, 0.200001, -31.71668) (no progress after interact (0.4 m of 0.8 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Misc/GoodsLift` | at (5.9, 0.0, -0.4), nearest door `O1Front` 0.4 m: stalled before corner (5.699997, 0.200001, 0.599998) (no progress after interact (0.0 m of 1.0 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Doors/WSCorridor` | at (18.4, 0.0, 6.7), nearest door `OCHall` 0.5 m: stalled before corner (17.31458, 0.200001, 6.914587) (no progress after interact (0.6 m of 1.1 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Misc/DispatchSafe` | at (12.2, 0.0, 6.4), nearest door `O2Corridor` 0.4 m: stalled before corner (11.88701, 0.200001, 5.599998) (no progress after interact (0.5 m of 0.8 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Misc/DeskCashO1` | at (11.8, 0.0, 5.6), nearest door `O2Corridor` 0.4 m: stalled before corner (11.60001, 0.200001, 6.5) (no progress after interact (0.0 m of 0.9 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Doors/O1Front` | at (7.7, 0.0, 0.6), nearest door `O1Front` 1.8 m: stalled before corner (6.051613, 0.200001, -0.5) (no progress after interact (2.6 m of 2.8 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Doors/StairMezz` | at (1.2, 0.0, 6.4), nearest door `StairGround` 0.5 m: stalled before corner (1.500003, 0.200001, 5.700005) (no progress after interact (0.0 m of 0.7 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Doors/MCWest` | at (1.5, 3.6, 6.7), nearest door `StairMezz` 0.7 m: stalled before corner (0.300003, 3.8, 6.900002) (no progress after interact (0.0 m of 1.2 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Doors/PKPlant` | at (-0.7, 3.6, 7.0), nearest door `MCWest` 0.7 m: stalled before corner (0.300003, 3.8, 6.900002) (no progress after interact (0.0 m of 1.0 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Doors/PKRoller` | at (9.0, 0.0, 18.8), nearest door `PKPlant` 0.8 m: stalled before corner (10.14927, 0.200001, 20.48335) (no progress after interact (0.0 m of 2.0 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Doors/ChamberANorth` | at (7.8, 0.0, 32.7), nearest door `PKRoller` 0.7 m: stalled before corner (11.5, 0.200001, 32.6) (no progress after interact (0.0 m of 3.7 m)) |
| dockside_burn | STUCK-AI | `Gameplay/Doors/HallRoller3` | at (24.9, 0.0, 8.6), nearest door `ChamberANorth` 1.6 m: stalled before corner (26.52907, 0.200001, 9.040011) (no progress after interact (0.0 m of 1.7 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/DisplayCases/WallCaseB` | at (10.6, 0.0, 12.4), nearest door `MainEntrance` 0.8 m: stalled before corner (11.25, 0.2, 11.0) (no progress after interact (1.3 m of 1.5 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/Misc/PhoneAdmin` | at (1.5, 0.0, 6.4), nearest door `StaffDoor` 0.4 m: stalled before corner (1.5, 0.2, 5.0) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/Doors/BreakRoomDoor` | at (4.2, 4.2, 6.4), nearest door `AdminDoor` 0.4 m: stalled before corner (4.0, 4.4, 5.0) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/Misc/CameraStation` | at (3.0, 4.2, 4.9), nearest door `BreakRoomDoor` 0.4 m: stalled before corner (3.0, 4.4, 3.5) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/Workshop/WorkshopSafe/SafeLoot` | at (7.9, 4.2, 4.1), nearest door `SecurityDoor` 0.4 m: stalled before corner (8.0, 4.4, 5.5) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/Doors/WorkshopDoor` | at (7.4, 0.0, 4.1), nearest door `WorkshopDoor` 0.4 m: stalled before corner (7.5, 0.2, 5.5) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/DisplayCases/IslandCaseB` | at (7.5, 0.0, 4.9), nearest door `WorkshopDoor` 0.4 m: stalled before corner (7.5, 0.2, 3.5) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/Doors/StockDoor` | at (12.6, 0.0, 9.9), nearest door `SalonDoor` 0.4 m: stalled before corner (14.0, 0.2, 10.0) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/Doors/UpperLobbyDoor` | at (13.0, 4.2, 5.6), nearest door `StockDoor` 0.4 m: stalled before corner (13.0, 4.4, 7.0) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/Doors/LobbyDoor` | at (17.0, 4.2, 4.9), nearest door `UpperLobbyDoor` 0.4 m: stalled before corner (17.0, 4.4, 3.5) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/Doors/SalonBackDoor` | at (17.0, 0.0, 4.9), nearest door `LobbyDoor` 0.4 m: stalled before corner (17.0, 0.2, 3.5) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/DisplayCases/SalonCaseB` | at (17.3, 0.0, 4.9), nearest door `LobbyDoor` 0.5 m: stalled before corner (17.0, 0.2, 3.5) (no progress after interact (0.0 m of 1.4 m)) |
| glasshouse | STUCK-DOOR | `Gameplay/Windows/SalonEast` | at (13.4, 0.0, 9.9), nearest door `SalonDoor` 0.4 m: stalled before corner (12.0, 0.2, 10.0) (no progress after interact (0.0 m of 1.4 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Vault/Box3` | at (9.8, 0.0, 20.4), nearest door `MainEntrance` 0.8 m: stalled before corner (10.5, 0.2, 19.0) (no progress after interact (1.3 m of 1.5 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Doors/VaultDoor` | at (14.0, -4.0, 10.4), nearest door `VaultDoor` 0.4 m: stalled before corner (14.0, -3.8, 9.0) (no progress after interact (0.0 m of 1.4 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Doors/VaultGate` | at (14.0, -4.0, 7.9), nearest door `VaultGate` 0.4 m: stalled before corner (14.0, -3.8, 6.5) (no progress after interact (0.0 m of 1.4 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Doors/ElectricalDoor` | at (11.8, -4.0, 6.4), nearest door `LockerRoomDoor` 0.4 m: stalled before corner (12.0, -3.8, 5.0) (no progress after interact (0.0 m of 1.4 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Misc/PhoneLoan` | at (23.7, 0.0, 6.4), nearest door `StorageDoor` 0.5 m: stalled before corner (23.5, 0.2, 5.0) (no progress after interact (0.0 m of 1.4 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Doors/FireExit` | at (23.9, 0.0, 7.9), nearest door `LoanCorridorDoor` 0.6 m: stalled before corner (23.5, 0.2, 6.5) (no progress after interact (1.1 m of 2.6 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Atms/AtmCash2` | at (28.2, 0.0, 6.8), nearest door `FireExit` 2.2 m: stalled before corner (27.0, 0.2, 6.75) (no progress after interact (0.0 m of 1.2 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Doors/AtmInnerDoor` | at (23.4, 0.0, 17.6), nearest door `AtmInnerDoor` 2.4 m: stalled before corner (21.7, 0.2, 18.0) (no progress after interact (0.0 m of 1.8 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Misc/AlarmSecurity` | at (21.7, 0.0, 18.0), nearest door `AtmInnerDoor` 0.7 m: stalled before corner (20.0, 0.2, 18.0) (no progress after interact (0.0 m of 1.7 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Doors/SallyPersonnelDoor` | at (13.2, 0.0, 1.5), nearest door `WCDoor` 4.4 m: stalled before corner (12.88868, 0.2, 2.577657) (no progress after interact (0.0 m of 1.1 m)) |
| night_deposit | STUCK-DOOR | `Gameplay/Doors/XferDoor` | at (6.0, 0.0, -0.7), nearest door `SallyPersonnelDoor` 0.7 m: stalled before corner (6.0, 0.2, 1.0) (no progress after interact (0.0 m of 1.7 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Doors/GatehouseSouth` | at (26.8, 0.0, -32.4), nearest door `GatehouseNorth` 0.4 m: stalled before corner (27.0, 0.200001, -31.0) (no progress after interact (0.0 m of 1.4 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Misc/GoodsLift` | at (5.9, 0.0, -0.4), nearest door `O1Front` 0.4 m: stalled before corner (6.0, 0.200001, 1.0) (no progress after interact (0.0 m of 1.4 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Doors/WSCorridor` | at (18.4, 0.0, 6.7), nearest door `OCHall` 0.5 m: stalled before corner (17.0, 0.200001, 7.0) (no progress after interact (0.0 m of 1.4 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Misc/DispatchSafe` | at (12.2, 0.0, 6.4), nearest door `O2Corridor` 0.4 m: stalled before corner (12.0, 0.200001, 5.0) (no progress after interact (0.0 m of 1.4 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Misc/DeskCashO1` | at (11.8, 0.0, 5.6), nearest door `O2Corridor` 0.4 m: stalled before corner (12.0, 0.200001, 7.0) (no progress after interact (0.0 m of 1.4 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Doors/StairGround` | at (4.0, 0.0, 5.6), nearest door `O1Corridor` 0.4 m: stalled before corner (4.0, 0.200001, 7.0) (no progress after interact (0.0 m of 1.4 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Doors/StairMezz` | at (1.3, 0.0, 6.7), nearest door `StairGround` 0.7 m: stalled before corner (1.5, 0.200001, 5.0) (no progress after interact (0.0 m of 1.7 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Doors/MCWest` | at (1.5, 3.6, 6.7), nearest door `StairMezz` 0.7 m: stalled before corner (1.5, 3.8, 5.0) (no progress after interact (0.0 m of 1.7 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Doors/PKPlant` | at (-1.0, 3.6, 7.6), nearest door `MCWest` 1.2 m: stalled before corner (1.0, 3.8, 7.0) (no progress after interact (0.0 m of 2.1 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Doors/PKRoller` | at (9.1, 0.0, 20.1), nearest door `PKPlant` 2.1 m: stalled before corner (9.0, 0.200001, 17.0) (no progress after interact (0.0 m of 3.1 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Doors/ChamberANorth` | at (7.8, 0.0, 32.7), nearest door `PKRoller` 0.7 m: stalled before corner (12.0, 0.200001, 33.0) (no progress after interact (0.0 m of 4.2 m)) |
| dockside_burn | STUCK-DOOR | `Gameplay/Doors/HallRoller3` | at (24.2, 0.0, 9.3), nearest door `ChamberANorth` 0.7 m: stalled before corner (24.2, 0.200001, 11.0) (no progress after interact (0.0 m of 1.7 m)) |
