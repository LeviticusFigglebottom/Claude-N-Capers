# Glasshouse: Vossberg Jewelers (glasshouse)
Status: APPROVED (lead, 2026-10-10) (D-023). Required changes 1–4 folded in by ENV C on 2026-10-10.

## Fiction
- **Who:** Vossberg Jewelers, a family-run high-end jeweler (est. 1962, now run by Greta Vossberg)
  on the corner of Harlow Avenue and Pell Street. Two storeys: the shop and workshop below, offices
  above. Guarding is contracted to Halden Security (Security Officers).
- **What:** the Thursday consignment of loose stones and finished estate pieces sits in the workshop
  safe overnight before Friday's private-client viewing. The display cases on the floor are a bonus.
- **Why / contact:** **Odile Vance** (fence) has buyers for the estate pieces and wants them before
  the Friday viewing: *"Vossberg keeps the good things in the back, darling. The windows are for tourists."*
- **Time / weather:** dusk, ~19:40, dry, early autumn. Blue-hour exterior, warm interior. The store
  is open late for the viewing week, so customers are inside when the crew arrives.
- **Handler:** Mercer on comms.

## Modes
- **Stealth + loud.** Size S (8–15 min stealth, 10–18 min loud).
- **Drilling in stealth is a deliberate last resort.** The workshop safe is ~9 m from the floor
  guard's post, through 2 walls. That is inside the drill's 12.5 m occluded noise radius (S4.3), so
  an unskilled drill alerts the floor guard (and the BOH rover). Drilling is viable only after the
  guards are dealt with (pagers) or with silent devices (`stealth.silent_devices`, S9.3). This is
  intended: the keycard is the clean path, and the drill trades pagers or a skill for time.
- **Stealth:** casing as a customer is possible from the street, the sales floor and the alley
  (all PUBLIC). The safe opens with the **manager's keycard** (random location) or with a **drill**
  (noisy: 25 m audible). Required loot: 2 bags. The hard parts: one long staff corridor, many
  civilians, and only 2 cable ties per player.
- **Loud:** the alarm triggers the safe's **lockdown** (keycard reader dead), so the safe needs the
  **drill** (120 s, 1–3 jams). The crew holds the workshop and corridor through one assault wave
  until the van arrives.
- **Difficulty notes:** Routine runs 2 guards and 2–4 customers; Brutal runs 3 guards and 3–5
  customers, plus the `drill_relock` rare event. P2 adds the camera operator and the code note; cameras are live since D-059.

## Site
- **Lot:** 18 × 12 m (wall centre lines; outer face 18.4 × 12.4 m), corner lot on the NE corner
  of a city block. Ground FFL = 0.0 m. Two storeys plus a flat roof with a 1.0 m parapet.
- **Streets:** **Harlow Avenue** runs along the south (4 lanes, 14 m carriageway, 4 m sidewalks).
  **Pell Street** runs along the east (2 lanes plus parking, 8 m carriageway, 3 m sidewalks). The
  **service alley** runs along the north (6 m wide, one-way W→E, dumpsters, HVAC, the fire-escape
  ladder).
- **Neighbours:** west, behind a party wall with no openings, is *Castellan Tailoring* (closed,
  shutters down; exterior dressing only). Across the alley are the backs of the *Kessel Row*
  buildings (fenced yards and back doors; dressing). Across Harlow Ave are a hotel and café facade
  (dressing). Across Pell St is a 3-level parking garage (P3 sniper perch).
- **Exterior landmarks:** (1) the **magenta neon "VOSSBERG" script sign** on the corner fascia above
  the salon windows, visible from both streets; (2) the **circular chandelier display**, a 2.4 m round
  glass case under a brass-and-crystal ring chandelier, centred in the sales floor and visible through
  the shopfront; (3) warm-lit window display boxes along Harlow Ave.
- **Play space:** x −14…+32, z −8…+34 (alley to the far sidewalk of Harlow Ave; the alley west end
  to the garage facade). The edges are closed by facades, parked vehicles, a closed alley gate (west)
  and street dressing. Nothing looks into the void. Each edge is closed as follows (the `bounds`
  validator checks every one):

| Edge | Closure |
|---|---|
| Alley, west end (x −14) | A 2.4 m steel **alley gate** (chained) between the Castellan back wall and the Kessel Row yard wall. Behind it, a 6 m stub of alley ends in a brick wall with a parked dumpster (P4 police spawn hidden behind the gate). |
| Alley, Pell St mouth (x 19–21, z −6…0) | Open to Pell St (it is the alley exit). Beyond it, Pell St north is closed at z −8 by a **parked box truck across the far lane plus construction barriers and a hoarding fence**; the P3 spawn is behind the truck. |
| Alley, north side (z −7) | The Kessel Row backs: continuous 2-storey facades with fenced yards (2.2 m fences). |
| Harlow Ave, west end (x −14) | The street continues as a vista: facades on both sides run to x −40, then a **bend in the avenue** (facade across the view axis at x −45), parked cars, a bus shelter. Players are stopped at x −14 by a road-works fence across the sidewalk and street (barriers + work van). |
| Harlow Ave, east end (x +32) | Same treatment beyond the Pell St intersection: facades to x +55, then a T-junction facade; road-works barriers at x +32. |
| Pell St south of Harlow (x 21–29, z > 30) | Facades on both sides plus a closed **underpass/parking ramp** facade at z 40. |
| South (z 30–32) | Hotel + café facades (3–5 storeys) with a lit hotel canopy. |
| East (x 30–32) | The 3-level parking garage facade (open deck slots show its interior ceilings and parked cars; geometry inside to 6 m depth). |
| Up | Procedural blue-hour sky. Every rooftop seen from street level has a parapet and roof equipment. |


## Floor plans
1 char = 0.5 m. Each character is a **grid point** (x = 0.5·col). Lines are **wall centre lines**:
exterior 0.4 m, interior 0.2 m. Origin is the NW corner of the building. +x is east and +z is south
(alley at the top, Harlow Ave at the bottom). Rulers are in metres.

Legend: `#` exterior wall, `|`/`-` interior wall, `D` door, `W` window, `G` guard post,
`K` keycard candidate slot, `L` loot (`L` on a wall = wall display cases), `S` safe, `(O)` chandelier
display (landmark), `======` sales counter, `^` stair up-flight, `v` return flight, `=` (upper) void
over the up-flight with a 1.05 m railing `rrr`, `H` roof hatch (fixed ladder), `M` monitor wall /
camera station console (U2, against the solid west wall), `o` operator seat (faces the monitors; the
alley window is to the operator's right). Escape `E` and spawns `P` are on the site plan.

**Vertical data** (`HeistMap.floor_heights = [0.0, 4.2]`):

| Level | FFL | Ceiling | Floor-to-floor / slab | Notes |
|---|---|---|---|---|
| Ground | 0.0 | 3.6 sales floor; 3.2 salon; 3.0 back of house (dropped ceiling, plenum above) | 4.2 (0.6 plenum + slab) | retail 3.0–4.5 ✓; office/BOH 2.6–3.0 ✓ |
| Upper | 4.2 | 3.0 | roof slab top 7.8, parapet to 8.8 | office ✓ |
| Stair G8 | 0.0 → 4.2 | U-stair, 2 flights × 12 risers @ 0.175 m, tread 0.28 m, width 1.2 m, half landing at +2.1 (z 0.2–1.4, full core width), headroom ≥ 2.1 everywhere (the flights sit side by side, never stacked) | 24 risers = 4.2 exactly ✓ | landing every 12 ≤ 16 ✓ |

### Site plan
1 char = 1 m, x = −14 at the left edge, +z is south. `%` neighbour/dressing blocks. `v` van
footprint (`E1` alley west, `E2` Pell St kerb). `P` player casing spawns. `P1…P4` police spawn
directions. `[BH]` dumpsters (`body_container`, BODY_HIDE). `F` fire-escape drop ladder to the upper
break-room window. `d` back door. `*`/`NEON` is the corner sign.

```
   x      -10       0         10        20        30 
  -8  %% KESSEL ROW BACKS (fenced yards, dressing)
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        GAR
  -6                                   : |P3 POLIC%%%
      X  P4 POLICE (alley W)           : |(Pell N)%%%
  -4  XgateE1 van                      : |       |%%%
      X    vvvvv     SERVICE ALLEY (6 m) one-way W->E
  -2       vvvvv              hvac     : |       |%%%
                      Fd  [BH][BH]     : |       |%%%
   0  %%%%%%%%%%%%%%###################: |       |%%%
      %%%%%%%%%%%%%%#                 #: |       |%%%
   2  %%%%%%%%%%%%%%#                 #: |PELL   |%%%
      %%%%%%%%%%%%%%#                 #: |STREET |%%%
   4  %%%%%%%%%%%%%%#                 #: |       |%%%
      %% CASTELLAN %#                 #: |       |%%%
   6  %% TAILORING %# VOSSBERG JEWELERS: |       |%%%
      %%%%%%%%%%%%%%#   (2 storeys)   #: |E2 van |%%%
   8  %%%%%%%%%%%%%%#                 #: | vvvv  |%%%
      %%%%%%%%%%%%%%#                 #: | vvvv  |%%%
  10  %%%%%%%%%%%%%%#                 #: |       |%%%
      %%%%%%%%%%%%%%#                 #: |       |%%%
  12  %%%%%%%%%%%%%%##################*: |       |%%%
      _______________________________NEON____________
  14    SIDEWALK  P P P P (casing spawns)
      
  16  _______________________________________________
                                       : |       |
  18                                   : |       |
                                       : |       |
  20                                   : |       |
                                       : |       |
  22    HARLOW AVENUE  (4 lanes)       : |       |
                                       : |       |
  24    P1 POLICE (Harlow W) <-     -> P2 POLICE (Har
                                       : |       |
  26                                   : |       |
                                       : |       |
  28                                   : |       |
                                       : |       |
  30  _________________________________:_|_______|___
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  32  %% HOTEL / CAFE FACADES (dressing; P3 sniper pe
```

### Ground floor (FFL 0.0)
```
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8
  0.0 ######DDD#######WW###################
      #G7 |     |G2        |G3  |G8   |G10#
  1.0 #   D     |  SL      |    |     |   #
      #   |     |          |    |^  v |   D
  2.0 #---+     |          |    |     |   D
      # G1      |          |    |^  v |   #
  3.0 #         |          |    |  +--|   #
      #         |          |    |^ |  |   #
  4.0 #         |          |    |  |  |   #
      #------D-------D-------D---  --D--D-#
  5.0 #G4               G                 #
      #                                   #
  6.0 #--D-----------------------------D--#
      #G5 SALES FLOOR           |G6 SALON #
  7.0 #    ======               |         #
      #     K                   |         W
  8.0 #L                        |         W
      #                  L      |   L L   W
  9.0 #            (O)          |         W
      #L                        |         W
 10.0 #      L                  D         W
      #                         |         W
 11.0 #L                        |         #
      #                  G      |         #
 12.0 #WWWWWWWWWWWWWWWWWWW#DDDD###WWWWWWW##
```

### Upper floor (FFL 4.2)
```
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8
  0.0 ###WWWW#######WWWW######W############
      #U1        |U2       |U3  |G8   |U8 #
  1.0 #          |         |    |     |   #
      #          |M        |    |=  v |   #
  2.0 #          |Mo       |    |     |H  #
      # K        |M        |    |=  v |   #
  3.0 #          |         |    |     |   #
      #          |       K |    |=  v |   #
  4.0 #          |         |    |     |   #
      #-----D---------D------D--rrr   -D--#
  5.0 #U4               G                 #
      #                                   #
  6.0 #-------D------------D----D---------#
      #U5 ADMIN     |U6       |U7         #
  7.0 #             |         |           #
      #             |         |           #
  8.0 #             |         |           W
      #             |         |           W
  9.0 #             | K       |           W
      #             |         |           W
 10.0 #             |   L     |           W
      #             |         |           #
 11.0 #             |         |           #
      #             |         |           #
 12.0 ##WWWW###WWWW####WWWWW#####WWWWWWW###
```

Roof (not playable in P1): parapet 1.0 m, 2 HVAC units, roof hatch over U8 (`H`, fixed ladder,
locked in P1). It is a P3 police `RAPPEL`/`ENTRY` point.

## Room list
Sizes are between wall centre lines. Clear size = minus 0.1–0.2 m per side.

| id | purpose (`RoomVolume.purpose`) | size m | ceiling m | kit | notes |
|---|---|---|---|---|---|
| G1 | storage (receiving) | 5 × 4.5 (minus G7) | 3.0 | `storage_receiving` | Steel back door (service, 1.1 m) to the alley. Shelving, packing bench, dolly, mop sink, delivery crates. Alarm keypad by the back door (dressing in P1, `alarm_button` in loud). |
| G7 | electrical | 2 × 2 | 3.0 | `electrical_closet` | Breaker panel, IT rack and router; the door is in G1. Required support space. |
| G2 | workshop | 5.5 × 4.5 | 3.0 | `workshop_jeweler` | **The safe** (large, floor-anchored, brass-trimmed, on the north wall). Two jeweler benches with lamps and magnifiers, polishing machine, ultrasonic cleaner, tool wall. High barred window (sill 1.8). Door: **lockpick** (8 s). |
| G3 | restroom | 2.5 × 4.5 | 3.0 | `restroom_single` | Accessible WC (toilet, sink, grab bars, mirror) with a small vestibule. Plumbing stacks with U3. |
| G4 | corridor (staff) | 18 × 1.5 | 3.0 | `corridor_service` | Back-of-house spine. Staff door to G5 at x 1.5, the stair foot at x 13–14.5, lobby G10 at the east end. 18 m straight sightline (see Sightlines). |
| G8 | stair | 3 × 4.5 | open to the upper floor | — | U-stair (see vertical data). Railing on the upper void edge. |
| G9 | storage (janitor) | 1.5 × 1.5 | ≤ 3.0 (under the return flight) | `janitor_closet` | Mop bucket, shelf, chemicals. **BODY_HIDE** zone (1 body). |
| G10 | corridor (stair lobby) | 2 × 4.5 | 3.0 | `corridor_service` | **Fire exit** (1.0 m, push bar, swings out) to Pell St. Fire-exit sign. |
| G5 | sales_floor | 13 × 6 | 3.6 | `sales_floor_jewelry` | Chandelier display (landmark, centre), 3 west wall cases, 2 island cases, 1 rear island, sales counter (0.9 m, register, card terminal) with the staff door behind it, consultation table with 2 chairs, bench by the window, shopfront window boxes (sill 0.3). Double glass entry door (1.8 m). |
| G6 | sales_floor (private salon) | 5 × 6 | 3.2 | `salon_private` | By-appointment viewing room: 2 high-value cases, sofa, coffee table, mirror, armchairs, vitrine. Windows to Pell St and Harlow Ave. Door from G5 (variable lock); back door from G4 (lockpick). |
| U1 | break_room | 5.5 × 4.5 | 3.0 | `break_room` | Fridge, counter with sink, microwave and coffee, table with 4 chairs, lockers, bulletin board. North window to the alley with the **fire-escape landing** (variable: open/latched). |
| U2 | security_room | 5 × 4.5 | 3.0 | `security_office` | `camera_station` (P2) with its monitor wall against the solid **west** wall (U1 partition) and the operator seat facing west, so the north alley window is at the operator's right; desk, key cabinet (east wall, `K`), guard lockers, coffee. North window overlooks the **alley and back door**. |
| U3 | restroom | 2.5 × 4.5 | 3.0 | `restroom_single` | Staff WC over G3. High frosted window. |
| U4 | corridor | 18 × 1.5 | 3.0 | `corridor_office` | Upper spine. Stair arrival at x 14.5–16; 1.05 m railing along the void (x 13–14.5). |
| U8 | corridor (upper lobby) | 2 × 4.5 | 3.0 | `corridor_service` | Roof hatch ladder (locked in P1), extinguisher, fire-exit sign pointing down the stair. |
| U5 | office (admin and appraisal) | 7 × 6 | 3.0 | `office_open` | 3 desks (bookkeeping, sales admin, appraisal bench with gem scope), file cabinets, printer, water cooler. Windows to Harlow Ave (sill 0.9). |
| U6 | office (manager) | 5 × 6 | 3.0 | `office_manager` | Greta Vossberg's office: desk, credenza, 2 visitor chairs, bookshelf, wall art, small wall safe (dressing in P1). Windows to Harlow Ave. |
| U7 | storage (stock and archive) | 6 × 6 | 3.0 | `storage_archive` | Packaging stock, archive boxes on shelving, gift-box supplies, ladder. Windows to Pell St. |
| X1 | exterior (alley) | 36 × 6 | — | `exterior_alley` | Dumpsters ×2 (`body_container`, BODY_HIDE), HVAC condensers, fire-escape ladder, pallets, back-door lamp, alley gate (west, closed). |
| X2 | exterior (street) | — | — | `exterior_street` | Sidewalks, street lights (LED 4000 K), parked cars, bus stop on Harlow Ave, trash bins, the neon sign. |

Support-space check (level_standards §2.2): restrooms on both floors ✓, break room ✓, janitor ✓,
electrical/IT ✓, back entrance ✓, 1 stair core (2 floors) ✓, fire exit ✓ (G10 → Pell St; the
upper floor reaches it via the stair, 18 m max travel).

## Circulation
- **Public:** street → double entry door → G5 sales floor ↔ G6 salon (when the salon door is
  unlocked). Customers browse cases, sit at the consultation table and queue at the counter.
- **Staff:** G5 → staff door (behind the counter, x 1.5) → G4 → workshop / receiving / WC / stair →
  U4 → offices, break room, security. The back door (G1) is the staff and delivery entrance from the alley.
- **Guards (PatrolGraphs):**
  - `ground`: G5 entrance ↔ chandelier ↔ counter end ↔ salon door ↔ staff door ↔ G4 west ↔ G4 mid ↔
    workshop door ↔ G4 east ↔ G10 ↔ stair foot. Branches into G1 (receiving), G2 and G6 (back door)
    form 3 loops through G4 mid: (a) G4→G1→G4, (b) G4→G2→G4→G10→G4, (c) G4→staff door→G5→salon→G6 back
    door→G4. That is ≥ 3 loops for each post on the shared graph.
  - `upper`: U4 west ↔ U1 ↔ U4 mid ↔ U2 ↔ U5 ↔ U6 ↔ U7 ↔ U8. It links to `ground` through stair
    PatrolPoints (foot, landing, top). Loops: (a) U4→U1→U4→U2, (b) U4→U5→U4→U6, (c) U4→U7→U8→stair→G4→stair.
  - `alley`: back door ↔ dumpsters ↔ fire-escape ladder ↔ alley mouth (Pell St). Used by the
    `alley_smoker` post (pause_anim `smoke`, 20–40 s).
- **Civilians:** customers wander G5 (`civilian` points at cases, counter queue, consultation seats,
  window boxes) and G6 when it is unlocked. Staff (`staff` points) go counter ↔ G4 ↔ G3 WC ↔ U1 break
  room ↔ U5. The jeweler goes G2 bench ↔ U1 coffee ↔ G3 WC, so he periodically leaves the workshop
  (a 40–70 s absence window).

### Civilian roster (spawn data)

| NPC | Count | Presence | Spawn tags | Idle activity (`SpawnPoint.idle_activity`) | PatrolPoint tags used |
|---|---|---|---|---|---|
| Sales associate (counter) | 1 | always | `civ_staff_counter` | `desk_work` (register) | `staff`, `staff_floor` |
| Sales associate (floor) | 1 | always | `civ_staff_floor` | `browse` (tending cases) | `staff`, `staff_floor` |
| Jeweler | 0–1 | `jeweler` = `jw_working` | `civ_staff_workshop` | `desk_work` (bench) | `staff`, `staff_boh` (G2, U1 coffee, G3 WC) |
| Admin clerk | 0–1 | `admin_clerk` = `clerk_in` | `civ_staff_admin` | `desk_work` | `staff`, `staff_upper` (U5, U1, U3) |
| Manager (Greta Vossberg) | 0–1 | rare event `nervous_manager` | `civ_staff_manager` | `phone` | `staff`, `staff_upper` |
| Customers | 2–5 | scalar `customers` | `civ_customer` | `browse` / `queue` / `sit` | `civilian` (G5 and G6 when unlocked) |

**Civilians in total:** Routine 4–8 (2 associates + 0–2 variable staff + 2–4 customers; +1 if
`nervous_manager`). Brutal 5–9 (3–5 customers). The two associates are what route 1 has to read:
the counter associate works the register end, and the floor associate circulates between the cases
and the salon door. The window to move behind the counter opens when both are at the east half of the floor.

## Sightlines
- **Floor guard post (G5, inside the entrance, facing N):** covers the whole sales floor, the counter
  and the staff door at 11 m. Its blind spots are the salon interior and the strip behind the
  counter's west end while the guard faces the salon door at his pause point.
- **Shopfront:** the street sees into G5 (lit interior at dusk). Guards on the floor see the sidewalk.
  There are no NPC observers on the street in P1, so this is atmosphere only.
- **G4 staff corridor:** an 18 m straight line. Anyone in it is seen end to end. Cover comes from the
  door recesses (G1, G2, G3, janitor) and the stair foot. This is the stealth crux, so timing beats speed.
- **Security office window (U2) → alley:** a guard in U2 (rover_upper pause point; P2 camera
  operator) sees the back door and the dumpsters. The fire-escape ladder is **outside** this cone
  (ladder at x 2, window cone centred at x 8).
- **Workshop:** the door is in G4 and the workshop's only interior view is from that door. A jeweler
  at the bench faces the north wall (safe side), with his back to the door.
- **P2 cameras (designed now):** C1 G5 NE corner → entrance; C2 G5 SW corner → counter/staff door;
  C3 G4 east end → corridor; C4 alley over the back door; C5 G2 over the safe; C6 U4 west end → corridor.

## Stealth routes
1. **Front (customer):** case from the street and the sales floor. When the keycard is behind the
   counter (`kc_counter`), take it **unmasked** (casing-allowed pickup) while the counter staff work
   the far end. Then use the staff door (RESTRICTED: casing detection) → G4 → lockpick the workshop
   (8 s) → safe. Tools: none. Risk: the floor guard and 2 sales associates.
2. **Alley (staff entrance):** case the alley (PUBLIC). The back door is either propped (`back_propped`)
   or picked (8 s, in view of the U2 window if a guard is pausing there). Then G1 → G4 → G2. When
   `xl_delivery` rolls, 2 extra bags sit right by the door. Risk: the `alley_smoker` guard.
3. **Upper (fire escape):** climb the fire-escape ladder (alley) → break-room window (only when
   `ow_breakroom_open`; latched means glass breaks, noise 15 m) → U1. The window is a walk-through
   door-window (PO-5): sill flush with the landing and the U1 floor, clear opening 1.09 × 2.05 m,
   full-height sash; crew, bags and pathing agents pass once it is open or broken (prefab `walkable`
   NavLink), never while it is shut. From U1 → keycard upstairs (U2/U6/U1) →
   stair → G4 → G2. Risk: `rover_upper` and the admin clerk.

Pager budget: Routine 2 guards → ≤ 2 pagers if you kill every guard. Brutal 3 → ≤ 3. In P2 the
camera operator adds 1, which can hit the cap of 4 exactly, so Brutal ghosting in P2 leaves no margin.
Civilian pressure: 4–9 civilians with only 2 cable ties per player (solo: AI teammates wait at the van,
D-014), so solo stealth is about **avoiding** civilians, not tying them all.

## Loud
- **Chokepoints:** the main entrance and shopfront (glass, wide), the back door (alley), the fire exit
  (Pell St), the salon windows (east and south), and the roof hatch (P3).
- **Holdout spots:** the workshop (one door, barred window, but the drill draws fire to it) and
  the G4/G10 corner (cover at the stair, 2 approaches). The sales floor is a kill zone from the shopfront.
- **Police entry (`TacticalPoint ENTRY`):** main door, shopfront window bays ×2 (breachable), back door,
  fire exit, salon east window (breachable), roof hatch (P3, `RAPPEL`).
- **Police spawns (≥ 3 directions, out of LOS of loot/escape):** P1 Harlow Ave west (x −30),
  P2 Harlow Ave east (x +40), P3 Pell St north (z −15), P4 alley west behind the gate (x −16).
- **Sniper perches (P3):** hotel roof across Harlow Ave (covers the shopfront), garage level 2 across
  Pell St (covers the alley mouth and the salon).
- **Special spawns (P3):** Phantom via the alley; Wrecker via Harlow Ave; Bulwark along the shopfront.
- **Cover:** display cases (low, glass: soft cover), the counter, the chandelier plinth, the
  corridor door recesses, the alley dumpsters and parked cars.

## Loot path
- **Safe (G2) → van:** E1 alley van: G2 → G4 → G1 → back door → 8 m to the van (or throw from the back
  door, 4 m + walk). E2 Pell St van: G2 → G4 → G10 fire exit → 6 m to the kerb (bags are visible on
  the street).
- **Upper alternative:** bags carried upstairs can be **thrown from the break-room window** into the
  alley (drop 4.2 m, lands by the dumpsters). The window must be open.
- **Small loot:** display cases on G5 and G6 (break: noise 15 m + `broken_glass` stimulus), the
  register (counter), and manager cash (`xl_manager_cash`).
- **Secure zone:** `SECURE_LOOT` box around the active van. The inactive van slot leaves nothing behind.

## Objectives
**Stealth** (objective_tag in brackets):
1. *(optional)* Case the store. Mercer intro and an Odile line. `[casing]`
2. Find the manager's keycard. `[keycard]` (skipped if `safe_left_open`)
3. Get into the workshop (lockpick the door). `[workshop_door]`
4. Open the safe: keycard swipe (3 s) **or** drill (120 s, noisy). `[safe]`
5. Bag the consignment (safe `loot_spawn`, 4 bags of `loot.jewelry`). `[safe_loot]`
6. Secure ≥ 2 bags at the van. `[secure]` (optional: more bags and small loot)
7. Escape. `[escape]`

**Loud** (on `alarm_raised`):
1. Mercer: "Lockdown. Safe reader's dead, get the drill on it." The mission disables the safe's
   KEYCARD method. If the safe is already open, skip to 3.
2. Drill the safe (120 s; jams per S9.3). `[safe]`
3. Bag and secure ≥ 2 bags. `[secure]`
4. Hold out until the van arrives: the van comes at the first assault's FADE or after 240 s,
   whichever is later, at the rolled `escape` slot. `[escape]`
5. Escape.

**Mission script notes** (`glasshouse_mission.gd` on `HeistMission`): find prefabs by objective_tag;
`on_event(&"alarm_raised")` → set the safe lockdown; `device_finished` on the safe drill → open the safe;
`loot_secured` count ≥ 2 → enable escape; the van arrival is gated by `assault_phase_changed(FADE)` or
a timer. Mercer lines: intro, keycard found, workshop open, drill jam, last pager (4th), van ETA, escape.

## Variable table
Each variable changes a decision.

| variable | options (slot ids) | weights | gameplay effect (the decision it changes) |
|---|---|---|---|
| `keycard` | `kc_counter` (G5 register drawer, behind the counter), `kc_manager` (U6 desk), `kc_security` (U2 key cabinet), `kc_breakroom` (U1 locker), `kc_jeweler` (G2 bench; requires `jw_working`) | 1, 1, 1, 1, 0.75; pick 1 | **Which floor and route you commit to.** Counter = front route, unmasked snatch, but needs the staff looking away. Upstairs = fire-escape or stair infiltration past `rover_upper`. Jeweler's bench = you must deal with the jeweler. |
| `guard_post` | `post_floor` (always), `rover_boh`, `rover_upper`, `alley_smoker` | floor forced; rovers: pick 1, `difficulty_add` Brutal +1 | **Which approach is covered.** The smoker shuts the alley route until his smoke loop ends or you spend a pager. A BOH rover makes G4 timing harder. An upper rover guards the keycard rooms. |
| `back_door` (`locked_door`) | `back_propped` (wedged open), `back_locked` (lockpick 8 s) | 0.3, 0.7; `requires`: `alley_smoker` ⇒ `back_propped` | **The cost of the alley route:** a free entry, or 8 s of picking in the alley in view of the U2 window. |
| `open_window` | `ow_breakroom_open`, `ow_breakroom_latched` | 0.45, 0.55; pick 1 | **Whether the fire-escape route exists quietly.** Latched means breaking glass (noise) or not using the route. It also decides whether bags can be thrown from upstairs. |
| `jeweler` (`civilian_cluster`) | `jw_working` (jeweler at the G2 bench), `jw_gone` | 0.6, 0.4; pick 1 | **Do you spend a cable tie or wait for his coffee/WC break window?** It also enables `kc_jeweler`. |
| `admin_clerk` (`civilian_cluster`) | `clerk_in` (U5 desk), `clerk_out` | 0.5, 0.5 | **The upstairs civilian**: watches the U4 corridor near the U6 keycard spot. |
| `salon` (`locked_door`) | `salon_open`, `salon_locked` (lockpick 8 s, in the floor guard's view) | 0.5, 0.5 | **Top-value small loot:** stroll in while casing, or pick in view of the guard / use the G4 back door (lockpick, masked). |
| `extra_loot` | `xl_delivery` (2 `loot.jewelry` bags in G1 by the back door), `xl_manager_cash` (3 `small_loot` cash in U6), `xl_none` | 0.25, 0.35, 0.40 | **Time versus reward**, placed on different routes (alley vs upstairs), so it biases which route is worth it. |
| `escape` | `esc_alley_west` (E1), `esc_pell` (E2) | 0.65, 0.35 | **The loot path and the throw spots:** back door/window → alley, or fire exit → street (visible). In loud it also decides which side you defend while waiting. |
| `customers` (scalar) | 2, 3, 4, 5 | Routine 0.3/0.4/0.3/0; Brutal 0/0.3/0.4/0.3 | **Casing cover versus the crowd to control.** More eyes on the floor; more hostages in loud. |
| `camera` (live, D-059) | `cam_c1` … `cam_c6`, one camera each; 1–3 live (+1 Brutal/Lethal, +2 Cataclysm) | 1 each | Changes which corridor or angle needs a loop or the operator. `asset.intel_cameras` reveals the live set. |
| `security_room_staffed` **(P2)** | `sec_staffed`, `sec_empty` | 0.6, 0.4 | Kill/dominate the operator (pager) or the cameras stay live. |
| `code_note` **(P2)** | `code_admin` (U5), `code_breakroom` (U1 board), `code_jeweler_notebook` (G2) | 1, 1, 1 | Second stealth way into the safe (code instead of keycard). |

## Rare events

| id | good/bad | chance | effect |
|---|---|---|---|
| `safe_left_open` | good | 3% | Jeweler forgot to close it: `force_active` safe state open; the keycard objective is skipped. |
| `estate_consignment` | good | 6% | +1 `loot.jewelry` bag (high value) in the G6 salon vitrine. |
| `drill_relock` | bad | 10% (Brutal only) | The safe has a relocker: +1 drill jam (max 4). |
| `nervous_manager` | bad | 5% | Greta stays late in U6 (civilian), and on first suspicion she runs straight to the U2 `alarm_button` (no phone call delay). |

## Escape
- **Van** (`secure_zone` + `escape_zone` at the rolled `escape` slot). Stealth: the van is parked from
  the start, and the escape opens after ≥ 2 bags are secured. Loud: the van leaves at the alarm and
  returns at the first assault FADE or after 240 s (whichever is later), same slot.
- **Walk-out** (stealth only, optional P2): an unmasked crew with no bags can leave via the front door.

## Pre-planning (P4 board; listed so the slots exist)
`asset.body_bag_drop` (alley, by the dumpsters), `asset.inside_keycard` (forces `kc_breakroom`),
`asset.van_position` (choose the `escape` slot), `asset.zip_ties_drop` (alley), `asset.propped_door`
(forces `back_propped`). Player spawn alternates: the Harlow Ave sidewalk (default), the alley mouth
(Pell St), the alley west (`preplan_spawn_alley`).

## Audio/lighting
- **Palette** (style guide §3): warm ivory `#E8DCC8` walls and plaster, walnut `#5A3B28` casework and
  doors, brass `#C9A227` trims and the chandelier, neon magenta `#FF3EA5` sign. BOH: painted block and
  vinyl in desaturated greige.
- **Time of day:** blue hour. Sun 4° below the horizon WSW. Sky gradient deep blue to amber at the
  horizon. Street LED lights 4000 K. Neon magenta spill on the corner sidewalk.
- **Zones:** sales floor 2700 K track spots on the cases plus chandelier emission (brightest, warm).
  Salon 2700 K dimmer, lamps. BOH corridor 4000 K ceiling panels. Workshop 5000 K bench task lamps
  (pools of light, dim surroundings). Receiving 5000 K fluorescents, dimmer. Security office dim with
  a cool monitor glow. Break room 3500 K. Offices 4000 K panels plus desk lamps. Every light has a fixture.
- **Global illumination:** VoxelGI for the interior, ReflectionProbe per room, OccluderInstance3D for
  the shell. LightmapGI cannot be baked from a script (editor-only), so VoxelGI is baked by
  `greybox/bake_gi.gd` under xvfb (D-046). **Re-bake it after every geometry regeneration.**
- **Ambience:** `amb_glasshouse_interior` (room tone, HVAC, faint jazz from the sales floor speakers),
  `amb_street_dusk` (traffic, distant city). The alley adds condenser hum.
- **Music:** `glasshouse` (stealth 60–90 BPM bed with a glassy bell motif; assault 120–150 BPM).
- **LUT:** `lut_glasshouse`, warm mids and slightly cool shadows.

## HeistDef (proposed data, `glasshouse_def.tres`)
`id glasshouse`, display "Glasshouse", contact `contact.vance`, mode STEALTH_OR_LOUD, base_payout
proposed **$40,000** (lead/B to confirm), loot `[loot.jewelry, loot.cash]`, escape_options `[van]`,
music_track `glasshouse`.
