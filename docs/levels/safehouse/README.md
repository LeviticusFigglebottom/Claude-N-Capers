# Safehouse ("The Press"): G1 greybox (C4-02)

Design: docs/design/heists/safehouse.md (G0 approved, D-070). Contract: docs/contracts/hub_map.md v1.2 (root
`SafehouseMap extends HeistMap`, data only: no HeistDef, never on the Board).

* Scene: `game/world/hub/safehouse/safehouse_g1.tscn` (**staged**: hub_map's `safehouse.tscn` path makes B's
  SafehouseHost enter the 3D hub, which fails 22 of B's 2D-hub tests; it moves to that path once B pins them),
  generated (never hand-edit) by
  `game/world/hub/safehouse/greybox/build_safehouse.gd` from `safehouse_layout.gd` (the G0 tables).
  Determinism: `tools/levelcheck/sh_regen_twice.sh`.
* Validate: `tools/levelcheck/validate_all.sh --hub` (greybox PASS; `validation.md`, `walkthrough.md` here:
  7 starts (P1-P4, Spawn, ReturnHeist, ReturnRange) x 9 station UsePoints, 63 / 63 walks ok).
* Shots: `g1/` (16 review cameras + `plan_floor0.jpg`), compatibility renderer (opengl3).
* Tests: `game/tests/c/test_safehouse_contract.gd`; B's `game/tests/b/test_hub_3d.gd`.

## G1 deviations from the G0 (for the LEAD)
* **Room purposes** use the levelcheck ceiling table's existing purposes: LB `loading`, H1 `workshop`, MK `office`
  (the G0's `workshop` band starts at 3.5 m and MK is 3.0 m), BK `bedroom`, RV `corridor`. The G0's new dressing
  kits (`loading_bay`, `safehouse_hall`, `mask_room`, ...) are G2 work; G1 rooms carry existing kits only where one
  fits (break_room, corridor_service, restroom_single, electrical_closet).
* **Stations:** the G0 table's centres and UsePoints. Several UsePoints are closer than the G0's "1.0-1.4 m from
  the face" line (planning 0.5 m, armory / masks 0.6 / 0.45 m); the test holds the real requirement instead (the
  Interactable within the 2.0 m reach of the standing eye on the UsePoint, in sight). The mask bench's chair is G2
  dressing and must not sit on the UsePoint.
* **`profile`** (hub_map v1.1, the career screen): the lounge bulletin board on wall x 8, centre (7.9, 1.4, 15.0),
  UsePoint (6.8, 0, 15.0) facing E (the LEAD's C4-02 ruling).
* **Wall-hung stations** (board, crew, profile) pivot on the wall face at mounting height (visual_slots wall pivot);
  their UsePoints are on the floor below.
* **Lighting** is the environment only at G1 (no Light3D). Fixtures, GI, the LUT, the audio bed and emitters and the
  positional jukebox are C4-03.
