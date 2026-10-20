# PO6-17 RNG assault events: visuals + Golden Hour, Dockside Burn, Night Deposit, Gallery Night markers (ENV C -> ENV A contract)

D-114 §5 / `docs/process/po_playtest_2026-10-15.md` PO6-17. ENV C supplies **visual scenes and map
markers only**; ENV A owns the events (HeistDef rows, `GameRng.stream(&"assault_events")`, spawning,
animation, damage, nav links). Names below are exact. Godot axes: +Y up, -Z forward, metres.

* Source script: `tools/blender/props/assault_events.py` (deterministic; `python3 tools/blender/build.py
  --category props --asset <id>`, then `tools/blender/props/build_props.sh` steps `_make_materials.py` +
  `_scenes.py`). Outputs: `game/assets/props/<id>/<id>.glb` + `SOURCE.txt`; wrapper scenes
  `game/world/props/assault_event/<id>.tscn` (root Node3D, the glb instanced as `Model`).
* Markers inside the props are glTF empties, i.e. **`Node3D`** (same convention as `DropAnchor`,
  `DrillPoint`); all paths are relative to the wrapper root, under `Model/`. The map markers are `Marker3D`.
* Palette: style guide §3 police navy `#1E2A44` + hi-vis `#D7E34A` trim, TAC charcoal `#2B2F33` armour;
  new prop materials `pr_police_navy`, `pr_hivis`, `pr_armor_charcoal`, `pr_soot`, `pr_soot_haze`,
  `pr_emit_police_blue` (`game/world/props/materials/`).
* Tests: `game/tests/c/test_assault_event_props.gd` (node contract + variant depths + GH / DB / ND / GN markers); `test_props.gd`
  (catalog rules: prefab group `assault_event`).

## 1. `res://world/props/assault_event/prop_turret_van.tscn`

Armoured police van, 5.8 x 2.2 x 2.6 m (AABB with push bar and mirrors 6.4 x 2.64 x 2.72). Pivot =
ground, footprint centre. **Nose at +Z** (matches the `TurretVan_<n>` marker: instance it at the
marker's transform), rear doors at -Z. No collision (the event prefab owns it; a 2.4 x 2.6 x 6.0 m box
centred at (0, 1.3, -0.1) covers the body).

| Node | Type | Local position | Notes |
|---|---|---|---|
| `Model/Body` | MeshInstance3D | (0, 0, 0) | shell, cab, wheels, light bar (blue left / red right), roof turret ring |
| `Model/DoorL` | Node3D (hinge pivot) | (1.06, 0.5, -2.9) | van's left rear door (+X). Closed = identity. **Open: rotation.y = -100 deg** |
| `Model/DoorR` | Node3D (hinge pivot) | (-1.06, 0.5, -2.9) | right rear door (-X). **Open: rotation.y = +100 deg** |
| `Model/DoorL/DoorLMesh`, `Model/DoorR/DoorRMesh` | MeshInstance3D | | leaves (move with the pivots) |
| `Model/TurretMount` | Node3D | (0, 2.66, -1.0) | top of the roof ring: put `prop_sentry_turret` here (its pivot = floor). -Z faces the van's rear |
| `Model/ExitPoint` | Node3D | (0, 0, -4.2) | crew dismount point 1.3 m behind the rear doors, on the ground; -Z faces away from the van |

## 2. `res://world/props/assault_event/prop_sentry_turret.tscn`

Police auto-turret on a tripod, 1.25 m tall. Pivot = floor, centre. Rest pose = identity, gun along -Z.

| Node | Type | Local position | Axis |
|---|---|---|---|
| `Model/Base` | MeshInstance3D | (0, 0, 0) | tripod, post, battery box (green LED) |
| `Model/Yaw` | Node3D | (0, 0.75, 0) | **turns about local Y** |
| `Model/Yaw/YawMesh` | MeshInstance3D | | turntable + cradle |
| `Model/Yaw/Pitch` | Node3D | (0, 0.24, 0) under Yaw | **tilts about local X** (+X rotation = muzzle up) |
| `Model/Yaw/Pitch/PitchMesh` | MeshInstance3D | | receiver, ammo box, barrel, shield, red sensor eye |
| `Model/Yaw/Pitch/Muzzle` | Node3D | (0, 0, -0.89) under Pitch | barrel tip; **-Z = fire direction** |

## 3. `res://world/props/assault_event/prop_police_helicopter.tscn`

Light police helicopter (navy + hi-vis, 4-blade main rotor 9 m disc), both cabin doors slid open.
**Nose at -Z.** Pivot = skid bottom under the cabin centre. No collision. ~5.5k triangles (van ~5.6k, turret ~3.2k, breaches 1.6-2.9k).

| Node | Type | Local position | Notes |
|---|---|---|---|
| `Model/Body` | MeshInstance3D | (0, 0, 0) | fuselage, skids, tail, beacon, nose spotlight gimbal |
| `Model/Rotor` | Node3D | (0, 2.65, -0.3) | main rotor pivot on the mast: **spin about local Y** (child `RotorBlades`) |
| `Model/TailRotor` | Node3D | (0.11, 2.25, 6.45) | **spin about local X** (child `TailRotorBlades`) |
| `Model/RopeL` | Node3D | (-1.1, 1.93, -0.3) | rope anchor (davit pulley) over the left door (-X); rope hangs along -Y |
| `Model/RopeR` | Node3D | (1.1, 1.93, -0.3) | rope anchor over the right door (+X) |
| `Model/SniperSeat` | Node3D | (-0.53, 1.08, 0.12) | rear bench end at the open left door, hip height; **-Z points out of the door (-X)** |
| `Model/Spotlight` | Node3D | (0, 0.36, -2.49) | searchlight lens under the nose; **-Z = beam**, rest pitch 30 deg down |

## 4. Breach points

`prop_breach_wall`, `prop_breach_window`, `prop_breach_ceiling` (`res://world/props/assault_event/<id>.tscn`).
**Kind "door"** (Ostrander Federal `Breach_3` / `Breach_4`, LEAD ruling): no scene and no `Visual` child; the marker
(same frame: bottom-centre of the doorway on the room-side face, -Z into the room; meta `kind` "door", `size`, `room`)
carries meta `door`, a NodePath from the marker to the map's `Door` it blows open (the door is the infill: ENV A plays
the charge on its leaves and sets it open). No nav obstruction: the door already stands in its opening.
Common contract (scene kinds):

* **Frame: the `Breach_<n>` marker's.** Origin = the opening on the **room-side surface** (wall/window:
  bottom-centre of the opening; ceiling: centre of the opening on the ceiling underside). **-Z points
  into the room**, +Z is the cops' side. Instance the scene with an identity transform as the marker's
  child (the GH map already does: `Breach_<n>/Visual`).
* `Model/Intact` (Node3D, visible): the infill that closes the map's real opening, **with its own
  collision `Model/Intact/Collision`** (StaticBody3D, layer 1, `metadata/surface` set).
* `Model/Blown` (Node3D, **hidden** in the wrapper): scorched ragged frame (`BlownFrame`), soot decals
  (`Scorch`), rubble and debris thrown into the room. **No collision** (rubble is visual; nothing blocks
  the 1 m opening).
* To blow it: `Intact.visible = false`, disable `Intact/Collision` (e.g. `process_mode = DISABLED` or
  clear `collision_layer`), `Blown.visible = true`.
* Markers (Node3D): `Model/Charge` (breach charge position, on the cops' face), `Model/EntryPoint` (where
  cops stack, cops' side, on their floor), `Model/ExitPoint` (inside, on the room floor). Window and
  ceiling also have `Model/RopeAnchor`.
* **Navigation:** the map navmesh treats an intact breach as wall (baked with the infill as an
  obstruction), so the opening is not walkable. When it blows, ENV A enables a link EntryPoint ->
  ExitPoint (NavigationLink3D; the window and ceiling ones are a rappel / drop, not a walk).

| Scene | Opening (`size`) | Built for | Local markers (marker frame) |
|---|---|---|---|
| `prop_breach_wall` | 1.0 x 2.2 m in a 0.2 m partition (infill occupies z 0 .. +0.2) | GH interior walls: an infilled old doorway (casing + plinth blocks both faces); room face plaster, cops' face drywall | `Charge` (0, 1.1, 0.23), `EntryPoint` (0, 0, 1.1), `ExitPoint` (0, 0, -1.0) |
| `prop_breach_window` | 1.0 x 2.1 m in a 0.4 m exterior wall (z 0 .. +0.4): a 1.0 x 1.2 window over a 0.9 m sill infill + radiator console; blown down to the floor | GH upper facade (brick outside, plaster inside) | `Charge` (0, 1.0, 0.43), `EntryPoint` (0, 0, 1.0) = outside the sill, **in the air** on an upper floor (cops hang on a rope), `RopeAnchor` (0, 4.6, 0.2) = parapet top above, `ExitPoint` (0, 0, -1.0) |
| `prop_breach_ceiling` | 1.2 x 1.2 m through ceiling (0 .. 0.05), plenum and roof slab (top at +0.6) | GH upper floor: a sealed skylight (roof curb + bolted cover, ceiling access panel). `Model/Frame` (the roof curb, always visible, own collision `Frame/CurbCollision`) | local +Z = up, +Y = world north (GH marker basis). `Charge` (0, 0, 0.84) on the cover, `EntryPoint` (0, 1.65, 0.6) on the roof beside the curb, `RopeAnchor` (0, 0.7, 0.8) on the curb, `ExitPoint` (0, 0, -3.0) on the room floor 3 m below |

### Map-sized variants (same nodes, same frame; Dockside Burn / Night Deposit)

The GH scenes are sized to GH's walls; other maps use these variants (same script, only the depths differ). The
Intact infill closes the full wall depth / the ceiling-to-roof depth, and `ExitPoint` lands on the room floor.

| Scene | Opening | Built for | Differs from the base scene |
|---|---|---|---|
| `prop_breach_wall_t40` | 1.0 x 2.2 m in a **0.4 m** exterior wall (infill z 0 .. +0.4) | DB plant / anteroom, ND lot: a doorway blocked up with blockwork (concrete faces, casings both sides) | `Charge` (0, 1.1, 0.43), `EntryPoint` (0, 0, 1.3) |
| `prop_breach_ceiling_p100_d800` | 1.2 x 1.2 m, ceiling underside to roof top **1.0 m** | DB high bay (ceiling 8.0, roof 9.0) | `Charge` (0, 0, 1.24), `EntryPoint` (0, 1.65, 1.0), `RopeAnchor` (0, 0.7, 1.2), `ExitPoint` (0, 0, **-8.0**) |
| `prop_breach_ceiling_p100_d550` | 1.2 x 1.2 m, depth 1.0 m | ND banking hall (ceiling 5.5, roof 6.5) | as d800, `ExitPoint` (0, 0, **-5.5**) |

Ceiling markers may turn about the vertical (layout `yaw`): +Y (the side of the roof `EntryPoint`) is north turned
by the yaw; -Z is always down. All three maps use yaw 0 for their ceilings except where noted.

## 5. Golden Hour markers (`res://world/heists/glasshouse/glasshouse.tscn`)

All under **`AssaultEvents`** (Node3D, root child, group **`assault_events`**). Generated by
`game/world/heists/glasshouse/greybox/build_greybox.gd` (`_build_assault_events`) from
`glasshouse_layout.gd` (`ASSAULT_*` tables); never hand-edit the map. World coordinates (x east, z south).

| Marker (Marker3D) | Position | Orientation / metadata | Notes |
|---|---|---|---|
| `TurretVan_1` | (1.0, -0.15, 21.2) | yaw 90: **+Z (van forward) = east** | Harlow Ave eastbound lane, opposite shop bays A-B (9 m from the shopfront); clear of parked cars |
| `TurretVan_2` | (15.0, -0.15, 24.6) | yaw -90: +Z = west | Harlow Ave westbound lane, opposite the entrance and the salon window. Both clear of escapes E1 (alley) and E2 (Pell St) and the police gates |
| `HeliOrbit_1` | (9.0, 30.0, 8.0) | `radius` = 24.0 (float) | orbit centre over the building; y = flight height of the heli pivot (skids); clears the hotel (17 m) and the garage (10 m) |
| `HeliDrop_1` | (12.6, 7.8, 9.1) | | roof (top 7.8), 1.5 m west of the `Breach_4` skylight curb (the roof is not on the player navmesh) |
| `HeliDrop_2` | (11.0, 0.0, -3.6) | | service alley east of the dumpsters |
| `Breach_1` | (10.6, 0.0, 6.1) | yaw 180 (-Z = south into G5); `kind` "wall", `size` (1.0, 2.2), `room` "G5" | G4 staff corridor -> G5 sales floor (wall `G_Corridor_S`), between the rear island case and the consult chair |
| `Breach_2` | (11.9, 4.2, 7.3) | yaw 90 (-Z = west into U6); `kind` "wall", `size` (1.0, 2.2), `room` "U6" | U7 stock room -> U6 manager office (wall `U_U6_U7`) |
| `Breach_3` | (10.1, 4.2, 11.8) | yaw 0 (-Z = north into U6); `kind` "window", `size` (1.0, 2.1), `room` "U6" | Harlow facade window `ManagerSouthB` -> U6 manager office; cops come down a rope from the parapet (pairs with `HeliDrop_1`) |
| `Breach_4` | (14.9, 7.2, 9.1) | basis = rotation -90 deg about X (-Z = down, +Y = north); `kind` "ceiling", `size` (1.2, 1.2), `room` "U7" | roof -> U7 stock room aisle (ceiling 7.2, roof top 7.8); pairs with `HeliDrop_1` |

Each `Breach_<n>` holds its breach scene as child **`Visual`** (Intact). Metadata on breach markers:
`kind` (String), `size` (Vector2, opening width x height in metres; ceiling: x by north-south),
`room` (String, the GH room id it opens into).

Map changes that make the openings real (all generated): wall openings in `G_Corridor_S` (x 10.1-11.1),
`U_U6_U7` (z 6.8-7.8) and the U6 south window B extended to the floor (`EXT_WALLS`); the roof slab and the
U7 ceiling are cut around a 1.2 m square at `Breach_4`; the static glazing of `ManagerSouthB` is now the
breach scene's (the room dressing still treats it as a window, so U6/U7/G5 dressing is unchanged). The
navmesh is unchanged with the breaches intact (infills are projected obstructions in the bake).

## 6. Dockside Burn markers (`res://world/heists/dockside_burn/dockside_burn.tscn`)

Same contract (`AssaultEvents`, group `assault_events`, root child). Generated by `dockside_burn/greybox/build_greybox.gd`
through the shared `res://world/heists/shared/assault_markers.gd` from `dockside_burn_layout.gd` (`ASSAULT_*`).

| Marker | Position | Orientation / metadata | Notes |
|---|---|---|---|
| `TurretVan_1` | (34.0, 0.0, -46.0) | yaw 90: +Z = east | Ferro St in front of the yard gate (x 31-37), 7.5 m north of the gate spawns; police come along the street from the P1 closures |
| `TurretVan_2` | (55.5, 0.0, 6.0) | yaw 180: +Z = north | east apron opposite the dock roller (z 3.1-9.1); clear of the reefer trailer, the cartel ApronS patrol point and the P3 gangway route |
| `HeliOrbit_1` | (28.0, 32.0, 4.0) | `radius` 26.0 | over the yard and the high bay; 5 m over the Pier 10 crane boom (26.6), inside the crane legs (x 73.5) |
| `HeliDrop_1` | (44.5, 9.0, 13.5) | | high-bay roof by the P5 spawn: **on the police-only roof navmesh island**, which reaches the chambers by the existing QC-41 rappels (the `RAPPEL` skylight TacticalPoints -> runtime `RappelLink`s, and NAV_LINKS `RappelLinkC1/SP/C2`). No new rappel link (rappel count 0 in `AssaultEvents`) |
| `HeliDrop_2` | (36.0, 0.0, -9.0) | | open yard between the hall roller doors and the K4-K6 containers (E1 van escape 10 m south-west) |
| `Breach_1` | (13.5, 3.6, 0.2) | yaw 180 (-Z = south into M1); `window`, (1.0, 2.1), `M1` | M1 count room north window E (was the static `M1WindowE`), opened to the mezzanine floor; rope from the office parapet (8.3) |
| `Breach_2` | (0.2, 0.0, 9.0) | yaw -90 (-Z = east into PL); `wall`, (1.0, 2.2), `PL`; scene `prop_breach_wall_t40` | PL plant west wall from the west lane, north of the compressors (opening z 8.5-9.5) |
| `Breach_3` | (34.0, 0.0, 31.8) | yaw 0 (-Z = north into AN); `wall`, (1.0, 2.2), `AN`; `prop_breach_wall_t40` | AN anteroom south wall from the quay, between the two roller doors (opening x 33.5-34.5) |
| `Breach_4` | (25.0, 8.0, 22.6) | ceiling (+Y north); `ceiling`, (1.2, 1.2), `C1`; `prop_breach_ceiling_p100_d800` | roof hatch over the C1 centre aisle, south of the C1 skylight (roof EntryPoint 1.65 m north, beside `RappelLinkC1`); lands in the aisle 8 m below |
| `Breach_5` | (41.0, 8.0, 22.6) | as Breach_4; `C2` | the same over the C2 aisle; 9.8 m from `HeliDrop_1` |

Generated map changes: openings in `NorthOffice` (13.0-14.0, 3.6-5.7, replacing M1WindowE's 1.2 m window; its static
glazing is gone, the breach scene glazes it), `WestWing` (z 8.5-9.5) and `SouthBay` (x 33.5-34.5); the bay roof slab and
the C1/C2 ceiling are cut round 1.2 m holes at Breach_4/5. Navmesh: 2118 -> **2135** polygons; the only change is on the
police roof island (two curbed hatches, -8.7 m2); M1, PL and AN floor areas are identical to before (the infills are
projected obstructions padded one nav cell into the room so they erode exactly like the wall faces they replace).

## 7. Night Deposit markers (`res://world/heists/night_deposit/night_deposit.tscn`)

Generated by `night_deposit/greybox/build_greybox.gd` through `shared/assault_markers.gd` from
`night_deposit_layout.gd` (`ASSAULT_*`); the art ceilings (`nd_art.gd`) are cut round the hatches and the room dressing
(`nd_dress.gd`) keeps the breach openings clear.

| Marker | Position | Orientation / metadata | Notes |
|---|---|---|---|
| `TurretVan_1` | (4.0, -0.15, 26.0) | yaw 90: +Z = east | Harbor St eastbound lane opposite hall bays 1-2 and the entrance (x 1-7); clear of the parked cars, the quay boat escape and the Harbor St police gates (x -14 / 40) |
| `TurretVan_2` | (32.6, -0.15, 10.0) | yaw 180: +Z = north | Wharf Lane opposite the G11/G12 windows (z 7.1-13.1), clear of the parked car (z <= 4.3) and the lot van escape |
| `HeliOrbit_1` | (12.0, 30.0, 8.0) | `radius` 22.0 | over the bank and Harbor St; clear of the crane-yard gantries (x >= 38.5, 22 m) |
| `HeliDrop_1` | (16.6, 6.5, 15.75) | | hall roof east of the skylight, 1.7 m from Breach_1 (the roof is **not** on the navmesh: ENV A pairs it with Breach_1, 12 m rule) |
| `HeliDrop_2` | (12.0, -0.15, 28.5) | | Harbor St in front of the bank |
| `Breach_1` | (14.9, 5.5, 15.75) | ceiling (+Y north); `ceiling`, (1.2, 1.2), `G9`; `prop_breach_ceiling_p100_d550` | banking hall roof hatch east of the skylight laylight (`RappelSkylight`), between the coffer beams; lands 5.5 m below, clear of the compass rose and the check tables |
| `Breach_2` | (7.75, 3.0, 8.6) | ceiling (+Y north); `ceiling`, (1.2, 1.2), `G8`; `prop_breach_ceiling` | wing-roof hatch over the teller workroom's staff walkway (between stools and teller stations 2/3); roof EntryPoint north of it (clear of the condensers) |
| `Breach_3` | (22.1, 0.0, 0.2) | yaw 180 (-Z = south into G6); `wall`, (1.0, 2.2), `G6`; `prop_breach_wall_t40` | G6 storage (the `srv_ground` rack room) north wall from the staff lot, west of the rack (opening x 21.6-22.6) |

Generated map changes: an opening in `ExtNorth` (x 21.6-22.6), 1.2 m holes through `HallRoof`/`CeilHall` and
`WingRoof`/`CeilWingW` and the G9 / G8 art ceilings. No roof rappel link: both roofs stay off the navmesh (pruned
islands); the ceiling breaches carry the squads down. Navmesh: 1832 -> **1835** polygons; the hall is unchanged, the
difference is G6 / G8 re-dressed round the breach keep-outs (+1.3 m2 free floor). Dressing changes only in G6 and G8.
The VoxelGI (`bake_gi.gd`, xvfb) was not re-baked for the two 1.2 m holes.

## 8. Gallery Night markers (`res://world/heists/gallery_night/gallery_night.tscn`)

Generated by `gallery_night/greybox/build_greybox.gd` through `shared/assault_markers.gd`; the data lives in
`gallery_night/greybox/gn_assault.gd` (`gallery_night_layout.gd` is emitted from the plan tools), which also cuts the
breach openings into the emitted wall runs (and a sill under each ground-floor wall breach).

| Marker | Position | Orientation / metadata | Notes |
|---|---|---|---|
| `TurretVan_1` | (51.0, 0.0, 14.0) | yaw 180: +Z = north | Wexley St opposite the LD / EG east wall (z 11.1-17.1); P3 comes down the street from the north closure, clear of its link and of the E1 Mews van |
| `TurretVan_2` | (-6.0, 0.0, 37.5) | yaw 90: +Z = east | Aldous Parade opposite the Sculpture Court (x -9..-3); clear of the E2 portico limo (x 19-28) and the P1 link (x -38.8) |
| `HeliOrbit_1` | (22.0, 34.0, 15.0) | `radius` 24.0 | over the Great Hall and its oculus; inside the hotel (x 58.4, +22) and the Ostrander (x -16.4, +14) |
| `HeliDrop_1` | (22.0, 11.0, 22.0) | | Great Hall roof south of the oculus, **on the police-only P5 roof island**; reaches the hall by the existing QC-41 `RappelLinkOculus` / `RappelOculus` RAPPEL point (no new link) |
| `HeliDrop_2` | (10.0, 0.0, 37.5) | | Aldous Parade west of the portico |
| `Breach_1` | (14.0, 5.4, 0.2) | yaw 180 (-Z = south into AO); `window`, (1.0, 2.1), `AO` | AO admin office north window (was the 1.0 x 1.5 "AO window N"), next to the SV hack holdout; rope from the roof-deck parapet (+10.1) |
| `Breach_2` | (0.2, 0.0, 9.5) | yaw -90 (-Z = east into WG); `wall`, (1.0, 2.2), `WG`; `prop_breach_wall_t40` | WG Founders' Gallery west wall from the Sculpture Court, north of the French doors (opening z 9.0-10.0) |
| `Breach_3` | (36.0, 0.0, 29.8) | yaw 0 (-Z = north into EB); `wall`, (1.0, 2.2), `EB`; `prop_breach_wall_t40` | EB Benefactors' Room Parade wall between the gameplay windows S1 / S2 (opening x 35.5-36.5) |
| `Breach_4` | (43.8, 0.0, 3.0) | yaw 90 (-Z = west into LD); `wall`, (1.0, 2.2), `LD`; `prop_breach_wall_t40` | LD Loading Dock east wall from Wexley St (opening z 2.5-3.5), clear of the inspector / Vaultline spawns |

Navmesh: 1299 -> **1299** polygons, byte-identical polygons (GN passes `face_pad` 0: its bake already erodes a
projected infill exactly like the wall face). GN is greybox: no dressing to keep clear.

## 9. Review

Shots: `docs/levels/_art/po6_17/*.jpg`, `contact_sheet.jpg`. Re-render:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --rendering-driver opengl3 \
  --resolution 1280x720 --script res://world/props/tools/po6_17_review.gd -- --out=$PWD/docs/levels/_art/po6_17 [--part=props|gh]
```

Not done here (ENV A): event logic, NavigationLinks for blown breaches, rope/rappel and the helicopter's
flight path, van arrival/door animation, turret behaviour and hitboxes, breach charge/explosion VFX + audio.
