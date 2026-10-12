# PP-C-2: headless scripted hand-play, Night Deposit + Dockside Burn (2026-10-12 ~18:35 ET)

Harness: `game/tests/c/test_pp_c2_handplay.gd` (PInputDriver real input incl. ENV P's screen_relative mouse fix
1328183f, working tree only; ENV P's edge-assist slide d5d9b519 NOT applied in this run). Same route as PP-C-1 (14 use
points, nearest-first, nav corners, interact hold on a stall). Added: at each reached use point the player mouse-looks
(yaw + pitch) at the Interactable and checks the prompt (InteractionSystem.aimed_component); cover sampled every ~1 m
(static collider within 2.5 m at 1.0 m height, 8 directions), >= 15 m without = COVER row. **Lighting not judged**: no
GPU on the box, the world renders black. Night Deposit came from a run that was killed externally after the Night Deposit
test (exit 143); Dockside was rerun on its own (exit 0).

## Summary
| heist | legs ok / walked | stuck | prompts ok / checked | no-cover stretches |
|---|---|---|---|---|
| night_deposit | 5 / 14 | 9 | 5 / 5 | 0 |
| dockside_burn | 1 / 14 | 13 | 1 / 1 | 1 |

## What a player would hit
- **Stuck at doorways / prop edges** (same rows as PP-C-1; corner-following steering): Night Deposit vault door + vault
  gate (y -4), FireExit, SallyPersonnelDoor, XferDoor, the ATM/phone/alarm corners; Dockside StairGround, StairMezz,
  O1Front, WSCorridor, GatehouseSouth, GoodsLift, DispatchSafe/DeskCashO1 in the office. See pp_c1.md for the D-085 rerun
  with ENV P's edge assist in both modes.
- **Interact prompts**: every use point that was reached showed its prompt from the use point (6/6). Not checked on the
  stuck legs (the player never got there), so prompt reach in the vault and office is still open.
- **No cover**: Dockside, from the weighbridge (26.5, -16.9) up to the hall roller doors (25.2, -1.5): 16 m of open yard
  with nothing within 2.5 m. That is the yard arena the P3 tests need to stay open (keep it), but it is the crew's way
  in from the gate under police fire; a reach-stacker or a pallet stack at about z -9 would break it up without closing
  the arena at (35, -18). For LEAD to rule on.

## Rows
| heist | kind | target | detail |
|---|---|---|---|
| night_deposit | STUCK | `Gameplay/Vault/Box3` | at (9.8, 0.0, 20.4): stalled before corner (9.900002, 0.2, 19.58) (no progress after interact (1.3 m of 1.5 m)) |
| night_deposit | STUCK | `Gameplay/Doors/VaultDoor` | at (14.0, -4.0, 10.4): stalled before corner (13.99581, -3.8, 9.504824) (no progress after interact (0.0 m of 0.9 m)) |
| night_deposit | STUCK | `Gameplay/Doors/VaultGate` | at (13.8, -4.0, 7.9): stalled before corner (14.0, -3.8, 6.9) (no progress after interact (0.3 m of 1.0 m)) |
| night_deposit | STUCK | `Gameplay/Misc/PhoneLoan` | at (23.7, 0.0, 7.1): stalled before corner (23.85, 0.2, 8.6) (no progress after interact (0.0 m of 1.5 m)) |
| night_deposit | STUCK | `Gameplay/Doors/FireExit` | at (23.8, 0.0, 7.9): stalled before corner (23.9, 0.2, 7.100002) (no progress after interact (0.0 m of 0.8 m)) |
| night_deposit | STUCK | `Gameplay/Atms/AtmCash2` | at (24.2, 0.0, 7.0): stalled before corner (22.35714, 0.2, 9.028573) (no progress after interact (1.4 m of 3.8 m)) |
| night_deposit | STUCK | `Gameplay/Misc/AlarmSecurity` | at (21.4, 0.0, 17.8): stalled before corner (20.6, 0.2, 17.7) (no progress after interact (0.0 m of 0.8 m)) |
| night_deposit | STUCK | `Gameplay/Doors/SallyPersonnelDoor` | at (11.7, 0.0, 5.6): stalled before corner (11.6, 0.2, 6.5) (no progress after interact (0.0 m of 0.9 m)) |
| night_deposit | STUCK | `Gameplay/Doors/XferDoor` | at (6.2, 0.0, -0.4): stalled before corner (5.900002, 0.2, 0.299999) (no progress after interact (0.3 m of 0.7 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/GatehouseSouth` | at (29.3, 0.0, -32.5): stalled before corner (27.16243, 0.200001, -31.36127) (no progress after interact (2.5 m of 1.1 m)) |
| dockside_burn | COVER | `-` | at (26.5, 0.0, -16.9): 16 m walked with no cover within 2.5 m (ends at 25.2, -1.5) |
| dockside_burn | STUCK | `Gameplay/Misc/GoodsLift` | at (5.9, 0.0, -0.4): stalled before corner (5.699997, 0.200001, 0.599998) (no progress after interact (0.0 m of 1.0 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/WSCorridor` | at (18.4, 0.0, 8.7): stalled before corner (17.31458, 0.200001, 6.914587) (no progress after interact (0.2 m of 2.3 m)) |
| dockside_burn | STUCK | `Gameplay/Misc/DispatchSafe` | at (12.2, 0.0, 6.4): stalled before corner (11.88701, 0.200001, 5.599998) (no progress after interact (0.4 m of 0.8 m)) |
| dockside_burn | STUCK | `Gameplay/Misc/DeskCashO1` | at (2.0, 0.0, 6.5): stalled before corner (4.199997, 0.200001, 5.599998) (no progress after interact (0.0 m of 2.3 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/O1Front` | at (6.8, 0.0, 2.4): stalled before corner (6.572494, 0.200001, 1.518412) (no progress after interact (0.0 m of 0.9 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/StairGround` | at (6.0, 0.0, -0.7): stalled before corner (5.900009, 0.200001, 0.0) (no progress after interact (0.0 m of 0.7 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/StairMezz` | at (2.5, 0.0, 6.5): stalled before corner (1.300003, 0.200001, 5.700005) (no progress after interact (0.0 m of 1.4 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/MCWest` | at (1.5, 3.6, 6.7): stalled before corner (0.300003, 3.8, 6.900002) (no progress after interact (0.0 m of 1.2 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/PKPlant` | at (-0.6, 0.0, 10.0): stalled before corner (0.300003, 3.8, 6.900002) (no progress after interact (0.0 m of 3.2 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/PKRoller` | at (9.2, 0.0, 20.3): stalled before corner (10.14927, 0.200001, 20.48335) (no progress after interact (0.0 m of 1.0 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/ChamberANorth` | at (7.8, 0.0, 32.7): stalled before corner (11.5, 0.200001, 32.6) (no progress after interact (0.0 m of 3.7 m)) |
| dockside_burn | STUCK | `Gameplay/Doors/HallRoller3` | at (24.5, 0.0, 9.0): stalled before corner (26.52907, 0.200001, 9.040011) (no progress after interact (0.0 m of 2.1 m)) |
