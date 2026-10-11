# The Press: crew safehouse (safehouse)
Status: G0 DRAFT: review requested (ENV C, 2026-10-11). Roadmap C4-01; fidelity C9 (P4 hub).

This is the G0 design doc for the explorable 3D safehouse. It follows the level_standards §9 template
wherever a heist section applies. Sections that only make sense for a heist (modes, stealth, loud,
loot, variables, escape) are replaced by **Stations**, **Session flow** and **Contract deviations**.
**ENV B's 2D hub (`HubMenu`, B4-07) stays the fallback** and remains the path for every case the 3D
hub does not cover (see "Session flow").

Sources: pd2_fidelity C9 / C1 / P7; game_overview §3–§4; level_standards §2–§9; heist_map v1.2;
gameplay_prefabs v1.4 (D-065 civilian mode); D-062 / D-069 (music); `MenuFlow.open_station()` and
`data/ui/hub_stations.tres` on `origin/env/b-content`; B's docs `music.md`, `board.md`, `notoriety.md`,
`options.md`; `InteractionTweak` (A).

---

## Fiction
- **What:** the **Halvard Press** works, a 1931 single-storey brick print works on **Tanner Row,
  Westside** (the Board's `westside` district: no contract is ever pinned there, so the crew's home
  block stays off the map). The press closed in 1998. Mercer bought the building through a shell
  company ("Halvard Archive Storage Ltd.") and the crew calls it **the Press**.
- **Why this building:** a print works explains a high power draw, night-time noise, van deliveries
  and a loading bay with a roller door. Nobody looks twice at a panel van backing in at 2 a.m. The
  old freight tunnel under the back yard became the firing range.
- **Who uses it:** Rook, Sable, Dutch and Wren (the playable crew). Mercer runs comms from here.
  The contacts (Odile Vance, Hollis Reyes, The Accountant) never visit. They exist on the Board as pinned
  contact cards.
- **Signs of life (no NPCs in v1):** Rook's oxblood scarf on a coat hook by the lounge door, Wren's
  headphones on the sofa arm, Dutch's thermos on the workshop bench and Sable's ivory gloves folded by
  the mask bench. These match the crew looks in game_overview §4.
- **Time / weather:** fixed **night, ~23:30, light steady rain** (it drums on the rooflights). There is no day
  cycle in v1.
- **Tone:** a lived-in, organised hideout. It is not a lair: industrial bones, a warm crew corner, and
  everything labelled in the old print-works enamel signage with the crew's stencil overpaint.

## Modes
This is not a heist. It has **no variants, police, AI, mission, loot or escape.** It is a solo,
local, walk-around hub scene. The player is unmasked in **civilian mode** (D-065: no mask-up and no
firing), so nobody shoots in the lounge. Each station is an interactable that calls
`MenuFlow.open_station(<id>)`.

## Site
- Lot 28 × 18 m. The building fills it. Tanner Row is to the north (the front door and the loading-bay
  roller door). Party walls are to the east and west, and the yard over the old freight-tunnel portal is to the south.
- **No exterior play space and no exterior review shots.** Every vertical window is wired, frosted
  glass, so no street geometry is needed. The rooflights show only the procedural night sky. The
  `bounds` check passes on geometry and sky alone.
- Landmarks visible from the main circulation (level_standards §3.6 requires ≥ 2):
  1. **The Board**, a 4 × 2.2 m pinned city map on the hall's north wall, lit by two picture lights.
  2. **The Old Press**, a cast-iron platen press with a 1.1 m flywheel under its own pendant. It is the
     Notoriety station.
  3. **The jukebox**, which glows amber through the lounge opening.
  4. **The crew van**, parked in the loading bay with its rear doors open.

## Floor plan
1 char = 0.5 m. Each character is a **grid point** (x = 0.5·col, z = 0.5·row). Lines are **wall
centre lines**: exterior 0.4 m, interior 0.2 m. The origin is the outer NW corner, +x is east and +z is
south (Tanner Row is at the top). The rulers are in metres. There is one floor (`floor_heights = [0.0]`,
`floor_names = ["Ground"]`). There are no stairs, ramps, level changes or railings, so the stair and handrail
rules do not apply.

Legend: `#` exterior wall, `|` `-` interior wall, `D` door (fixed open, see Circulation), blank gap in a
wall = cased opening (no leaf), `R` roller door (closed), `X` fire-exit door (closed), `W` window
(frosted wired glass), `: :` rooflight corners (2 × 2 m), `V` crew van, `P` player spawns,
`p` range-return marker, `=` bench / table, `O` press flywheel. **Stations** `1` board, `2` planning,
`3` armory, `4` masks, `5` jukebox, `6` notoriety, `7` range door, `8` crew phone.

```
   x  0    2    4    6    8    10   12   14   16   18   20   22   24   26   28
   0 ####RRRRRRRR#DD###WWWWW###############WWWWW#####WWWWW####
     #               |             1             |           #
     #     VVVV      |          BOARD            | WS armory #
     #     VVVV      |                           |           #
   2 #     VVVV      |                           |           #
     #     VVVV      | H1 PRINT HALL             |          =#
     #     VVVV      |                           D          =#
     #     VVVV      |                           D         3=#
   4 #     VVVV  P                               D          =#
     #     VVVV                                  |          =#
     #     VVVV   P        :   : :   : :   :     |           #
     #     VVVV                                  |           #
   6 #     VVVV  P               =====           |           #
     #                           =====           |           #
     #            P        :   : ===== :   :     ------------#
     # LB load       |             2             |           #
   8 #----------------8                          | MK masks  #
     #               |                           |           #
     # LG lounge                                 |          =#
     #                                           D         4=#
  10 #                                           |          =#
     #5                   O6                     |           #
     #                                           |           #
     #                  clips                    |           #
  12 # sofa  TV      -------------------------DD--|----------#
     #               D    CO corridor             D          #
     W               D                            D          #
     W               --DD-|--DD--|----D----|--DD--|          #
  14 W               |    |      |         |      |          #
     W               |    |      |         |      |          #
     #               |WC  |ST elec BK bunks|RV    | KS kit   #
     W      kitchen  |    |      |         |      |  store   #
  16 W               |    |      |         |      |          #
     W               |    |      |         |   p  |          #
     W               |    |      |         |      |          #
     #               |    |      |         |      |          #
  18 #########################################77########XXX###
```

Key coordinates (wall centre lines): x = 0, 8, 22, 22.5, 28 and z = 0, 7, 8, 12, 13.5, 18. The south strip
is divided at x = 10.5, 14, 19 and 22.5.

**Vertical data** (`floor_heights = [0.0]`):

| Area | Clear ceiling | Roof | Notes |
|---|---|---|---|
| H1 print hall | **5.0** (rooflight wells to 5.6) | +5.8 flat roof, 3 rooflights 2 × 2 m at x 12/15/18, z 6 | warehouse/industrial band 3.5–6 ✓ |
| LB loading bay | 4.5 | +5.3 | band 3.5–6 ✓ (roller door 3.5 × 3.6 m) |
| WS workshop | 3.5 | +4.2 (WS + MK share a lower roof) | industrial band ✓ (D-048 override if the validator files `workshop` under 2.6–3.0) |
| MK mask room, LG lounge, KS kit store | 3.0 | +3.6 to +4.2 | office/residential band ✓ |
| CO, WC, ST, BK, RV | 2.8 (WC 2.7) | +3.4 | ✓ |

## Room list

Sizes are centre-line dimensions in metres (clear = size minus half of each bounding wall).

| id | purpose (`RoomVolume.purpose`) | size m | ceiling m | kit (new = **bold**) | contents / notes |
|---|---|---|---|---|---|
| LB | `loading_bay` | 8 × 8 | 4.5 | **`loading_bay`** | Spawn room. The crew van (backed in, rear doors open) sits under the closed roller door. The front pedestrian door (closed, locked) is next to it. Also: an empty duffel pile, a rolling tool chest, two pallets of old paper reels (print-works legacy), a work light on a stand, oil-stain decals and a coat rack. A steel slider leaf is parked open on the west face of wall x 8 (z 0.6–3.8). |
| H1 | `workshop_hall` | 14 × 12 | 5.0 | **`safehouse_hall`** | Hub room: **Board (1)**, **planning table (2)**, **Old Press (6)** with the clippings wall, and the **crew phone (8)**. Also old type cases along the walls (a storage dresser of drawers), a filing cabinet, a whiteboard of crew rotas, a drinks trolley, and a pinned print-works fire plan by each opening. High clerestory windows (sill 3.2 m) sit on both sides of the Board. |
| LG | `break_room` | 8 × 10 | 3.0 | **`safehouse_lounge`** (extends `break_room`) | North half: an L-sofa facing a TV on wall z 8, a coffee table, a rug and the **jukebox (5)** on the west wall. South half: a kitchenette with counter and sink under the windows, a fridge, a coffee machine, a microwave, a dining table with 4 chairs, and the bulletin board on wall x 8 (break_room required items ✓). Coat hooks sit by door D6. |
| WS | `workshop` | 6 × 7 | 3.5 | **`armory_workshop`** | The **armory bench (3)** with a weapon pegboard on the east wall. Also a locked gun cabinet ×2 on the north wall (window between them), parts shelving on wall z 7, a bench vise, a cleaning mat, a parts washer and a stool. |
| MK | `workshop` | 6 × 5 | 3.0 | **`mask_room`** | Former darkroom. The **mask bench (4)** with a mask display wall on the east wall. Also a drying line with paint-masking stencils, a paint/finish shelf, a spray booth hood (fixture-only, off) and a seated chair facing the bench. No window. |
| CO | `corridor` | 14.5 × 1.5 (1.3 clear) | 2.8 | `corridor_service` | Service spine from the lounge (D6) to the kit store (D11). It ends at a door, which is a valid corridor end. Fire extinguisher, exit signs over D6 and D11. |
| WC | `restroom` | 2.5 × 4.5 | 2.7 | `restroom_single` + shower | WC, basin and a shower stall against the south wall (plumbing stack shared with the kitchen wall). |
| ST | `electrical` | 3.5 × 4.5 | 2.8 | `electrical_closet` + `storage_archive` | Breaker panel, water heater, router/NAS rack (Mercer's comms), shelving with print-works archive boxes. Required support space. |
| BK | `bunk_room` | 5 × 4.5 | 2.8 | **`bunk_room`** | 2 bunk beds (4 berths), 4 personal lockers (Rook/Sable/Dutch/Wren name tape), a bedside lamp and a duffel under each berth. |
| RV | `range_vestibule` | 3.5 × 4.5 | 2.8 | **`range_vestibule`** | Sound lock in front of the **range door (7)**: ear-defender and eye-protection rack, a sign-in clipboard, ammo crates, a bench and a "LIVE FIRE" lamp over the door. |
| KS | `storage` | 5.5 × 6 | 3.0 | **`kit_store`** | Equipment cage: drill cases, ECM cases, body-bag boxes, thermite crates (inert dressing), and spare duffels. The fire exit `X` is on the south wall. Gives the corridor a reason to end here. |

Support spaces (level_standards §2.2): WC ✓, kitchen in LG ✓, storage/janitor in ST/KS ✓, electrical/IT in ST ✓, a back
entrance (roller door) ✓ and a fire exit (KS) ✓. Single storey, so no stair core is needed.

## Circulation
- **Spawn → hub:** LB → opening O1 (x 8, z 4–7, 3.0 m) → H1. From the spawn the player sees the Board
  ahead-left and the planning table straight ahead under the middle rooflight.
- **Hall ring:** H1 → O2 (x 8, z 9–11.5, 2.5 m) → lounge; H1 → D3 (double, x 22, z 2.6–4.4) → workshop;
  H1 → D4 (x 22, z 9.5) → mask room; H1 → D5 (double, z 12, x 19.85–21.65) → corridor.
- **Service spine:** CO joins LG (D6), WC (D7), ST (D8), BK (D9), RV (D10) and KS (D11, east end).
  The lounge → corridor → hall loop means nothing is a dead end.
- **Doors:** every interior door leaf is **fixed open** against its wall on a hook. They are static props
  placed at the open angle, so no door prefab or runtime is needed, and the validator's swing-arc check
  covers the leaf in its parked pose. The exterior doors (front door, roller door, fire exit) are
  closed, non-interactive and visibly locked (padlock, push-bar chain). The **range door (7)** is the
  only door "used" and it is a station (scene change).
- **Walk times** at PD2 walk speed: spawn → Board ≈ 10 m, spawn → range door ≈ 23 m. No station is more
  than about 6 s of walking from the hall centre.
- Walkthrough bot (level_standards §6): from every PLAYER spawn to every station `UsePoint`, with no
  detour whitelist.

## Stations

Every station is a `SafehouseStation` node under `Stations/`, **named by its station id** (B's exact
ids from `hub_stations.tres`). Common shape:

```
<station_id> (SafehouseStation, Node3D; export station_id: StringName)
├── Visual        the station prop(s) (ENV C)
├── UsePoint      Marker3D on the user side, −Z toward the object (heist_map §5 convention)
├── Interactable  ENV A InteractableComponent (or A's `hub_station` prefab, QC-44)
├── InteractArea  StaticBody3D / Area3D on the interactable layer sized to the station face
└── StationCam    optional Marker3D for a 0.35 s camera blend before the screen opens (QC-45)
```

Interactable settings for every station: `kind = &"hub_station"`, `interaction_time_s = 0` (instant
press), `casing_allowed = true`, `civilian_allowed = true`, `noise = &"silent"`,
`prompt_key = &"ui.prompt.station.<id>"` (QC-47). **Interaction distance:** the standard aimed reach,
`InteractionTweak.reach_m` = **2.0 m** from the eye with a 10° assist cone. Every `UsePoint` is
1.0–1.4 m from the station face, so the station is in reach while the player stands on the UsePoint.
On `completed`, the station emits `SafehouseMap.station_requested(station_id)`, and MenuFlow connects
that signal to `open_station` (QC-45). ENV C never references MenuFlow.

| # | id (B) | Where (x, y, z) / UsePoint, facing | Prompt key | `open_station` → screen | Reads from across the room |
|---|---|---|---|---|---|
| 1 | `board` | Panel 4.0 × 2.2 m on the H1 north wall, centre (15.0, 1.6, 0.23), bottom 0.5 m. UsePoint (15.0, 0, 1.4) facing N | `ui.prompt.station.board` | target `board` → BoardScreen (B4-06) | The largest lit surface in the hall: a painted city map (8 districts, river, bay) with pins in the contact colours (Vance pink, Reyes orange, Accountant green, from contact data). Three contact cards hang on the left edge, the Accountant's as a veiled silhouette. Two 3000 K picture lights and red string between pins. Seen from the spawn through O1. |
| 2 | `planning` | Steel-topped imposing table 3.0 × 1.5 × 0.9 m, centre (15.0, 0, 6.5), 4 stools. UsePoint (15.0, 0, 7.75) facing N (the whole top is the InteractArea, so it works from any side) | `ui.prompt.station.planning` | target `heist_select` → HeistSelect → briefing → pre-planning | The centre of the hall, under the middle rooflight with two green-enamel 2700 K pendants. Blueprints are weighted with mugs, there is a red grease-pencil route, and a model of a building is under a cloth. |
| 3 | `armory` | Workbench 2.4 × 0.8 × 0.9 m on the WS east wall, centre (27.4, 0, 3.5). Pegboard 2.4 × 1.4 m above (bottom 1.2). UsePoint (26.4, 0, 3.5) facing E | `ui.prompt.station.armory` | target `loadout` → LoadoutScreen `hub_mode` (skills, perks and masks open from it) | Framed by double door D3, on the same axis (z 3.5). A 5000 K bench task lamp lights the pegboard of weapon silhouettes (QC-50), so it is the brightest cool pool on the east side. Enamel sign "COMPOSING ROOM" overpainted "ARMORY" above D3 (2.3 m). |
| 4 | `masks` | Bench 1.8 × 0.7 × 0.76 m (desk height, chair 0.45 m facing it) on the MK east wall, centre (27.4, 0, 9.5). Mask wall above: 3 shelves × 6 display busts. UsePoint (26.6, 0, 9.5) facing E | `ui.prompt.station.masks` | target `masks` → MaskScreen | Seen through D4 on the z 9.5 axis: a darkroom red safelight wash with one warm magnifier lamp on the bench, and a wall of masks looking back at the hall (masks on stands, QC-50). Enamel sign "DARKROOM" overpainted "MASKS". |
| 5 | `jukebox` | Jukebox 0.9 × 0.65 × 1.6 m on the LG west wall, centre (0.6, 0, 10.25). UsePoint (1.5, 0, 10.25) facing W | `ui.prompt.station.jukebox` | target `jukebox` → JukeboxScreen (B5-03) | Through O2 on the z 10.25 axis from the hall: an original rounded-top cabinet with an amber `#E39B3A` light bar and a deep-red side glow (never cyan), a slowly cycling emission and a small OmniLight with the cabinet as its fixture. You also *hear* it (see Audio). |
| 6 | `notoriety` (**new id, QC-46**) | The Old Press, footprint 1.4 × 1.0 m, h 1.9 m, centre (11.0, 0, 10.4), flywheel on its west side. The clippings wall (3.0 × 1.5 m) behind it on wall z 12. UsePoint (11.0, 0, 9.1) facing S | `ui.prompt.station.notoriety` | target `notoriety` → NotorietyScreen (B5-02, today reached only from the 2D hub's profile panel) | A hero prop (≤ 20k tris): black cast iron with brass oil cups under its own 2700 K pendant. Behind it, newspaper clippings of the crew's jobs (generated headlines, original papers) and a frame per Notoriety rank (empty frames until ranks exist; static in v1). Seen from the spawn and from the lounge. |
| 7 | `range` | Steel door 1.0 × 2.1 m in the RV south wall, centre (20.75, 1.05, 17.8). UsePoint (20.75, 0, 16.9) facing S | `ui.prompt.station.range` | target `firing_range` → `open_firing_range()` (B's range scene, scene swap) | On one straight axis x = 20.75 from the hall through D5 and D10 (both fixed open). A red "LIVE FIRE" lamp sits over the door at 2.3 m, with a yellow-black hazard frame and a stencilled "RANGE" sign. An enamel "RANGE →" sign hangs over D5 inside the hall. The vestibule's extractor hum is audible from the corridor. The door does not open on screen: the screen fades out (0.3 s) and the range loads. |
| 8 | `crew` (**proposed, see open question 3**) | Wall phone (old black payphone-style landline) and a corkboard of crew polaroids on the H1 west wall, centre (8.2, 1.4, 8.0). UsePoint (9.0, 0, 8.0) facing W | `ui.prompt.station.crew` | target `lobby` → LobbyScreen (B4-11) | Between O1 and O2, so you pass it on the way in. A small 3000 K wall sconce, a long coiled cord and polaroids of four masked figures. |

Not stations: **Options** and **Achievements** (the 2D hub's profile panel) are reached from the pause
menu in the 3D hub (QC-49). Trophies are listed under Future rooms.

## Spawns and session flow
- **Spawns:** `Spawns/` holds 4 PLAYER SpawnPoints in LB at (6.0, 0, 4.0), (6.5, 0, 5.0), (6.0, 0, 6.0) and
  (6.5, 0, 7.0), all facing +x (into the hall). v1 uses only the first one. All 4 exist for the
  co-op future and for the walkthrough bot. Return markers: `ReturnRange` (20.75, 0, 16.4) facing N
  (back from the range) and `ReturnHeist` = the LB spawn (fiction: you just got back in the van).
- **Who spawns:** ENV A's crew member, local and unmasked in **civilian mode**, with no weapon drawn
  (QC-43). The scene has no HeistRuntime and no Net session (an offline solo peer, like the range).
- **Entering:** main menu → "Safehouse" → MenuFlow instances the safehouse scene (QC-45). After a heist's
  payday the flow returns to the safehouse at `ReturnHeist`.
- **Using a station:** the crew's input is paused (`set_input_paused(true)`) and the mouse is released.
  The 3D view stays behind the screen (dimmed, so the safehouse remains "there"). **Back** returns
  control on the spot. No reload, and the position is kept.
- **Leaving the scene:** the range and a heist launch **free** the safehouse. Returning re-instances it
  at the matching return marker.
- **Fallback to the 2D hub (B, unchanged):** used when the safehouse scene or class is missing, when A's
  hub spawn hook is missing (QC-43), when the player picks "menu" for the hub in Options (open question
  6), and for every co-op lobby case (below).

### Co-op
- **v1: the 3D safehouse is solo and local only**, like PD2's own safehouse. **The lobby crew is not
  visible in it.** While a LobbySession is live, `MenuFlow.show_hub()` already shows LobbyScreen
  (B4-11), and that does not change. The `crew` phone (station 8) opens the lobby. Once a session is live,
  the player stays in the lobby UI until they leave the session.
- Possible later work (out of scope, open question 4): lobby members appear as idle crew characters at the
  planning table, using ENV D's crew models and ambient clips. This needs lobby replication of a
  "position/station" field (B/A) and is not designed here.

## Lighting and mood
- **Palette (new, distinct from the four heists):** dominant **aged brick `#7B4A3A`** (limewashed
  in the hall, bare in LB), secondary **print-works green enamel `#2F4A3E`** (signs, pendants,
  doors, the press base trim), accent **warm amber `#E39B3A`** (jukebox, pendant glow, lamp shades).
  Floors: sealed concrete (hall/LB/WS), oak boards (lounge/bunks), terrazzo (WC). Cyan `#4FD1E8`
  appears nowhere in the world (style guide §3).
- **Mood:** warm pools in a dark industrial shell. The crew corner (lounge, press, planning table) is warm
  at 2700–3000 K. Work areas (armory, kit store, LB) are cool at 4000–5000 K. The mask room is the only red
  room. Moonless overcast sky with an orange city glow through the rooflights, rain streaks on the
  rooflight glass (shader) and a soft sodium glow behind the frosted north windows (emissive glass,
  no Light3D, so no fixture is needed).
- **Fixtures (each Light3D has one, §3.7):** H1: 2 × green-enamel pendants over the table (shadowed),
  1 pendant over the press (shadowed), 2 picture lights on the Board (no shadow), 4 high-bay
  fluorescent battens at 4000 K (one bank on, dimmed; the others off but modelled). LB: high-bay at 4000 K
  plus a work light at 5000 K (shadowed). LG: a floor lamp, a table lamp, an under-cabinet strip and the jukebox
  OmniLight. WS: a batten plus a bench task lamp at 5000 K (shadowed). MK: a red safelight plus a magnifier lamp at 3200 K
  (so masks show true colour on the bench). CO/RV: 4000 K bulkheads, plus the LIVE FIRE lamp (red, no shadow). BK:
  a bedside lamp. KS: a 5000 K cage lamp. WC/ST: one fixture each.
- **GI and post:** one VoxelGI over the building (baked via the existing `bake_gi.gd` path, D-046), a
  ReflectionProbe per room, OccluderInstance3D on the shell and interior walls. A new LUT `lut_safehouse`
  gives warm mids and green-tinted shadows. AgX, subtle bloom (the jukebox and pendants should bloom slightly).

## Audio
- **Ambient bed** `cue.amb_safehouse_interior` (Ambience bus, 2D loop, new): low building room tone,
  rain on the roof and rooflights, faint traffic through the north wall, and an occasional pipe tick.
  It is synthesised in `tools/audiogen/`, in the same family as `cue.amb_glasshouse_interior`.
- **Point emitters** (CueEmitter, 3D, Ambience bus, new cues): `cue.amb_fridge_hum` (LG kitchen),
  `cue.amb_wall_clock` (LG), `cue.amb_ballast_buzz` (WS batten), `cue.amb_drip` (WC basin) and
  `cue.amb_range_extractor` (RV, so the range is audible from the corridor). Each has a max distance of
  6–10 m, and no more than 6 are audible at once.
- **Jukebox (diegetic music):** a C-owned `SafehouseJukebox` node holds a `MusicDirector` with
  `listen_to_event_bus = false`, extended (C work in `music_director.gd`) with a `positional_parent`
  so its stem players are `AudioStreamPlayer3D` at the cabinet (Music bus, so the Music slider still
  applies; unit size about 4 m, max distance 30 m, so it is full in the lounge, clearly present in the hall and faint in
  the workshop).
  - On entering, it plays `MusicDirector.preview(track, &"stealth")`, where track = the id MenuFlow passes
    in `set_jukebox_track()` (B's `MusicCatalog.resolve_choice(profile)`). For `&""` (heist default) it
    plays `default_track = &"glasshouse"` (open question 7).
  - At the jukebox station, B's JukeboxScreen previews **through the cabinet** (QC-48): it calls
    `preview(id[, stem])` / `stop_preview()` on the safehouse's `Jukebox` node instead of instancing
    its own MusicDirector. When the screen closes, MenuFlow calls `set_jukebox_track()` with the saved
    choice, so the picked track keeps playing on its stealth stem.
  - The jukebox ducks −6 dB while any *other* station screen is open (UI focus), and stops when the
    safehouse is freed (range or heist launch).
- No voice lines in v1. A Mercer phone line when using the crew phone is in Future scope.

## Contract deviations (non-heist map)
Scene: `game/world/hub/safehouse/safehouse.tscn`. Root: **`SafehouseMap`** (Node3D, C-owned script
`game/world/hub/safehouse_map.gd`). It is **not a HeistMap**. It has no HeistDef, is never in
`HeistRegistry`, and so can never appear in the Board pool or heist select (QB-55 needs a HeistDef and a map).
`SafehouseMap` duck-types the HeistMap fields the tools read: `review_cameras`, `floor_heights`,
`floor_names`.

| heist_map §2 node | Safehouse | Why |
|---|---|---|
| Geometry, Props, Lighting | **kept** | Same rules: no float, no clip, fixtures, materials. |
| Navigation | **kept** | Only for the walkthrough bot's reachability checks (spawn → every UsePoint). No NPC uses it. |
| Rooms | **kept** | RoomVolume per room in the room list (scale, density and variety checks). |
| Spawns | **kept, PLAYER only** (+ `ReturnRange`, `ReturnHeist` markers) | No GUARD / CIVILIAN / POLICE / CAMERA_OPERATOR. |
| ReviewCameras | **kept** | See Review shots. |
| Zones | **omitted** | Sealed interior: nothing is OUT_OF_BOUNDS, and there is no PUBLIC/RESTRICTED/loot/escape. |
| Patrols, Tactical | **omitted** | No AI, no police. |
| Gameplay | **replaced by `Stations`** | SafehouseStation nodes (above). No networked A prefabs. Doors are static props fixed open. |
| Variants, Mission, Preplan | **omitted** | No per-run variables, objectives or assets. Every visit is identical (seeded dressing only). |
| *(new)* `Audio` | added | Ambience bed, point emitters and `Jukebox` (SafehouseJukebox). |
| *(new)* signal `station_requested(id: StringName)` | added | The only API B consumes, mirroring `HubMenu.station_requested`. Plus `set_jukebox_track(id)`, `jukebox` (the preview target), `spawn_transform(return_id) -> Transform3D`. |

`validate_level` gets a **hub profile**: `--scene=res://world/hub/safehouse/safehouse.tscn
--profile=hub`. That runs contract_nodes (the hub list above), floating, clipping, orientation, scale,
navmesh, reachability (spawns → station UsePoints), materials, zfight, lights, density, variety,
bounds, cameras and perf. It skips patrols, variants and lasers. It is added to `validate_all.sh`.
Whether this mini-contract lives in heist_map.md (a "§9 Non-heist maps" section) or in its own
`hub_map.md` is open question 2.

## Review shots
16 fixed `ReviewCameras` (≥ 12 required: ≥ 1 per major room, 1 top-down, 1 per landmark). **Deviation:** there
are 0 exterior shots, because there is no exterior play space. Two rooflight up-shots stand in for them.

| # | Camera | Shows |
|---|---|---|
| 1 | `plan_top` | Top-down plan render (roof hidden) |
| 2 | `spawn_view` | From P1: van in frame left, O1 opening, Board and planning table beyond |
| 3 | `hall_wide_sw` | From the press corner looking NE: Board, table, D3 armory glow (landmarks 1 and 2) |
| 4 | `board_close` | The Board at 2.5 m: pins, contact cards, picture lights |
| 5 | `planning_table` | Table under the rooflight and pendants, stools, blueprints |
| 6 | `old_press` | Press and clippings wall under its pendant (landmark) |
| 7 | `lounge_from_hall` | Through O2 to the jukebox (landmark) and sofa |
| 8 | `lounge_kitchen` | Kitchen half: counter, windows, dining table, bulletin board |
| 9 | `armory_bench` | WS: bench, pegboard, gun cabinets, task lamp |
| 10 | `mask_room` | MK: red safelight, mask wall, bench lamp |
| 11 | `corridor_to_range` | From D5 along x 20.75 through D10 to the LIVE FIRE lamp |
| 12 | `range_vestibule` | RV: range door, ear-defender rack, crates |
| 13 | `bunk_room` | BK bunks, lockers and the bedside lamp |
| 14 | `kit_store` | KS cage, cases, fire exit |
| 15 | `rooflight_up_a` | Rooflight well over the table: rain streaks against the night sky (exterior stand-in) |
| 16 | `rooflight_up_b` | Rooflight well over the press side, with the high-bay battens (exterior stand-in) |

## Performance budgets
The hub has fewer elements than a heist, so its budgets are tighter (architecture.md §10 caps still apply):

| Budget | Value |
|---|---|
| Frame | 60 fps @ 1080p mid-range GPU while walking, and with a station screen open over the 3D view |
| Draw calls per review camera | ≤ 1,000 (target 800) |
| Visible triangles per view | ≤ 1.5 M |
| Shadow-casting lights in any view | ≤ 6 (the §5 rule is ≤ 8) |
| Texture memory | ≤ 512 MB (library materials first; unique textures only for the Board map, clippings and press) |
| GI | 1 VoxelGI, ≤ 11 ReflectionProbes (1 per room), occluders on all walls |
| Load (warm cache) | ≤ 2 s from main menu to control; return from a station ≤ 1 frame (no reload) |
| Audio | ≤ 8 simultaneous voices in the safehouse (bed + ≤ 6 emitters + jukebox stems crossfading) |

## Assets (ENV C unless noted)
- **New hero and station props** (`tools/blender/props/`): `prop_board_citymap` (painted map texture
  generated in texgen from the same district layout as B's `city_map.tres`, read-only; pins and string
  are separate meshes), `prop_imposing_table`, `prop_platen_press` (hero, ≤ 20k tris), `prop_armory_bench`
  + `prop_pegboard`, `prop_mask_bench` + `prop_mask_wall`, `prop_jukebox` (original design),
  `prop_range_door` + `prop_lamp_live_fire`, `prop_wall_phone`, `prop_crew_van` (parked, non-driving).
- **Kits:** 8 new kits (bold in the room list). The rest are reused.
- **Signs:** enamel sign generator (texgen) for "COMPOSING ROOM / ARMORY", "DARKROOM / MASKS",
  "RANGE →", "LIVE FIRE", plus the original print-works fire plan.
- **Dressing that uses other envs' models, read-only:** weapon models on the pegboard (B's
  `assets/weapons/`) and mask meshes on the mask wall. See QC-50.

## Future rooms and features (**OUT OF SCOPE for C4**; listed so the layout leaves room)
- **The Vault** (PD2's offshore/spending vault analog): spending cash shown as physical stacks that
  grow with `PlayerProfile.cash`. Candidate site: KS (the cage becomes a vault door). Needs B data hooks.
- **Trophy shelf / room:** achievements (B4-20) as physical trophies. Candidate site: H1 east wall
  between D3 and D4, or a new mezzanine.
- **Mezzanine office (Mercer's radio desk):** needs stairs, handrails and a second floor height.
- **Profile-driven dressing:** the mask wall shows the player's owned masks, the pegboard shows owned weapons,
  the Notoriety frames fill per rank, and the press plays a "print" animation on rank-up.
- **Ambient crew:** the three non-player heisters idle in the lounge or workshop (ENV D clips).
- **Co-op safehouse** (lobby members walking together).
- **Safehouse upgrades** (PD2 room tiers) and a day cycle.

## Open questions for the lead
1. **Doc location / ownership:** this file is `docs/design/heists/safehouse.md` as instructed, but ENV C's
   owners.json covers `docs/design/heists/**`. Add this path to C's owners, or move it to
   `docs/design/heists/safehouse.md`?
2. **Mini-contract:** do you approve `SafehouseMap` as its own root (not a HeistMap, no HeistDef), with the
   node list and API in "Contract deviations"? Should it be recorded in heist_map.md as "§9 Non-heist
   maps" or in a new `docs/contracts/hub_map.md`?
3. **Crew phone:** your station list has 7 stations, but B's `hub_stations.tres` also has `crew` (→ LobbyScreen).
   I propose the wall phone (station 8) so the 3D hub keeps the co-op entry point. Yes or no?
4. **Co-op:** is it OK that the 3D safehouse is solo-only in v1, with the lobby crew not visible and a live
   lobby falling back to LobbyScreen (as PD2 does)?
5. **Notoriety as a station:** it needs a new B station id and target (QC-46). Should the 2D hub's
   profile-panel button stay as well? I recommend yes.
6. **Quick access:** walking to stations costs time. Should Options get a "Safehouse: walk / menu"
   toggle, and should the 3D pause menu carry a "quick stations" list (the 2D hub cards)?
7. **Default hub music** when `music_choice` is `&""`: the `glasshouse` stealth stem (proposed), or a
   dedicated `safehouse` track in the C music backlog?
8. **Workshop ceiling 3.5 m** under purpose `workshop`: is this a D-048-style per-room override, or is
   `workshop` in the industrial band?
9. **Range door transition:** a 0.3 s fade with no physical door swing (the range is B's separate 100 m
   scene). OK, or do you want a door-open animation first?
10. **Roadmap:** add C4-02 (G1 greybox + hub validator profile + SafehouseStation/Jukebox scripts) and
    C4-03 (G2 art + audio + shots), gated on QC-43/45 for the in-game hookup?

## Cross-env requests
- **QC-43 (A): hub crew spawn without a HeistRuntime.** Add `CrewController.spawn_for_hub(parent,
  xform, loadout) -> Node`, like `spawn_for_range`, but unmasked, in civilian mode (D-065: no mask-up, no fire),
  with no weapon drawn. Interactions must work without `HeistRuntime.interaction`, so it needs a
  standalone InteractionSystem for the hub crew (local authority) using `InteractionTweak.reach_m`. It also needs
  `LocalHudModel.track(crew)` to expose the focused interactable's prompt key and blocked reason.
  `set_input_paused` is reused while a station screen is open.
- **QC-44 (A): `hub_station` prefab** (gameplay_prefabs v1.5): `station_id` export, `Visual`, `UsePoint`,
  `Interactable` (kind `hub_station`, instant, casing + civilian allowed), `signal station_used(station_id,
  crew)`, no net_id. *Alternative:* the lead OKs ENV C composing A's `InteractableComponent` directly in
  the C-owned `SafehouseStation` script. Either works for C.
- **QC-45 (B): MenuFlow 3D hub mode.**
  - Instance the safehouse from a data path (`res://world/hub/safehouse/safehouse.tscn`, kept in B data like
    `MusicCatalogTweak.table_path`), with `SafehouseMap` looked up by name (`UiNav.global_class`).
  - Connect `station_requested` → `open_station`.
  - Pause and resume the crew around station screens, keeping the 3D view dimmed behind (optionally blending
    to `StationCam`).
  - Free the safehouse on range or heist launch, and re-instance it at `ReturnRange` / `ReturnHeist`
    (`spawn_transform(id)`).
  - Fall back to the 2D `HubMenu` when the scene, class or A hook (QC-43) is missing. Co-op lobby
    behaviour is unchanged.
- **QC-46 (B): `notoriety` station.** Add a HubStation with id `notoriety`, target `notoriety` (→ `_open_notoriety`),
  and `ui.hub.station.notoriety(.desc)` strings.
- **QC-47 (B): hub prompts and HUD.** Strings `ui.prompt.station.<id>` for board, planning, armory, masks,
  jukebox, notoriety, range and crew (e.g. "Check the Board", "Plan a job", "Open the armory", "Pick a mask",
  "Choose music", "Notoriety", "Enter the firing range", "Call the crew"). Also a minimal hub HUD:
  a centre dot and the interaction prompt, from LocalHudModel.
- **QC-48 (B): JukeboxScreen preview target.** When MenuFlow hosts the 3D safehouse, give the screen
  the safehouse's `jukebox` (same `preview(track_id, stem)` / `stop_preview()` duck API) instead of a
  private MusicDirector. On close, and on `show_hub`, call `safehouse.set_jukebox_track(
  MusicCatalog.resolve_choice(profile))`.
- **QC-49 (B): safehouse pause menu.** `pause` in the 3D hub opens a panel with Resume, Options,
  Achievements, (optional) Quick stations, and Leave to main menu.
- **QC-50 (B, D): read-only dressing models.** Confirm that ENV C may instance weapon models
  (`assets/weapons/`, B) on the armory pegboard and mask meshes (D's mask set) on the mask wall as
  static, non-interactive dressing. Please name a stable list: about 8 weapons and 18 masks.
