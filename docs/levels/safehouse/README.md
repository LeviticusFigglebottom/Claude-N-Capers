# Safehouse ("The Press"): G1 greybox (C4-02)

Design: docs/design/heists/safehouse.md (G0 approved, D-070). Contract: docs/contracts/hub_map.md v1.2 (root
`SafehouseMap extends HeistMap`, data only: no HeistDef, never on the Board).

* Scene: `game/world/hub/safehouse/safehouse.tscn` (hub_map's path since G3; B's 2D-hub tests pin the 2D menu with
  `SafehouseHost.menu_hub_only`, b-content 4b75c578), generated (never hand-edit) by
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

## C4-03 G2 art pass (validate --hub final PASS)
* **Lighting** (`sh_lighting.gd`): the night environment and `lut_safehouse` (texgen gsr preset), 24 catalog fixtures
  at the G0's colour temperatures (2700-3000 K crew corner, 4000-5000 K work areas, the red mask-room safelight; the
  hall's south high-bays modelled but off), the LIVE FIRE lamp and the jukebox glow. 5 shadow casters (two table
  pendants, the press pendant, the LB work light, the armory bench lamp). One interior VoxelGI
  (`bake_safehouse_gi.gd`, needs xvfb + Vulkan), 10 reflection probes, 42 occluders.
* **Finishes** (`sh_finish.gd`): sealed concrete (hall, LB, workshop, store), bare brick (LB, workshop, kit store),
  limewashed walls elsewhere, oak boards (lounge, bunks), terrazzo and tile (WC), green-enamel doors, frosted windows.
  The stations and the van are library-material stand-ins until their art lands.
* **Dressing** (`sh_dress.gd`, KitPlacer): 125 props from 9 new kits (`tools/blender/props/_kits_safehouse.py`) and
  the shared corridor and restroom kits; every station body, UsePoint approach, spawn, review-camera standpoint and
  circulation lane is kept clear (walkthrough 63/63).
* **Audio**: the jukebox plays positionally at the cabinet (`MusicDirector.positional_parent`, 4 m unit size, 30 m);
  the interior bed and 5 point emitters (`tools/audiogen/cues_safehouse.py`). `SafehouseMap.start_ambience()` plays
  only registered cues, so they are silent until B's cue rows land.
* **Built by C (C4-03):** the green-enamel pendants (prop_sh_pendant_enamel), the work light on its stand
  (prop_sh_work_light), the crew van with its rear doors open (veh_sh_crew_van; tools/blender/props/safehouse.py).
* **D's hero props (D-159, G3):** the Old Press, the jukebox cabinet, the Board's painted map and the planning table
  (its brass lamp lit by `ART_LIGHTS`) are station art
  (`safehouse_layout.gd` `STATION_ART`: under each station's Visual, aligned to the greybox parts they replace); the
  bunk beds, gun cabinets, PPE rack, drying line and type cases are pinned in the kits. C's placement hints over D's
  `cat` (bunks, cabinets and type cases backed to a wall, the PPE rack at 1.5 m): `_scenes.py` `CAT_OVERRIDES`.

## G3 todo
* **Black faces: solved (2026-10-23).** Library ORM materials carry `metallic = 1`, so ORM.b decides metalness and a
  bare metal (`steel_bare`) has no diffuse. With the environment's reflections disabled it showed only its
  ReflectionProbe, which (UPDATE_ONCE) renders ~14-20 frames after a camera first sees it: until then it read black.
  Fixes: the steel planning-table stand-in became painted, then D's hero table; the environment reflects the dim night sky, the Old
  Press is D's art, `review_shots` warms every UPDATE_ONCE probe first, and levelcheck `metal_reflection` (final)
  fails a metal with no reflection source.