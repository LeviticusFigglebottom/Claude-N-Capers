# Shadow Ledger: Kessler & Moor penthouse (shadow_ledger)
Status: APPROVED (lead, 2026-10-10) (D-042)

## Fiction
- **Who:** **Kessler & Moor**, a boutique private-wealth and law practice (two partners, 14 staff)
  on the top two floors of **Calder Tower**, a 42-storey downtown office-and-residence tower on
  Calder Street. Level 41 is the firm; level 42 is the partners' private floor (lounge, study,
  boardroom, a guest suite Victor Kessler uses when he works late). Building security is in the
  ground lobby (off-map); the firm has its own night detail from **Northgate Executive Protection**
  (Security Officers, plus a camera operator in the L41 security room).
- **What:** the **off-book client ledger**: who owns which shell company, which account moves
  whose money. It exists in three forms: the **encrypted drive array** in the server cage (the
  data), the **partners' laptop** that holds the decryption key and a working copy (it travels
  between the partners), and the **printed master books** in Kessler's time-locked study safe.
- **Why / contact:** **The Accountant** (stealth-only data jobs, never seen): *"Kessler & Moor
  wash money for people who would rather it stayed clean. I want their ledger. All of it, and
  nobody may ever know it left the building."* An alarm means the firm wipes the array and
  relocates the books: the job only works if nobody ever knows it happened.
- **Time / weather:** 02:10, heavy rain, low cloud at ~60 m above the roof. The firm is closed:
  night guards, a cleaning crew, sometimes an IT contractor or a partner working late.
- **Handler:** Mercer on comms. A climber rigged the insertion line from **Arden Tower** (west,
  taller) to Calder's roof before the job; the crew starts on the roof (or, with the asset, in the
  L40 service lobby dressed as contractors).

## Modes
- **Stealth-only** (`HeistDef.mode = STEALTH_ONLY`, S11.3). Size M (15–25 min). Phase P2.
- **Alarm = fail.** Any `alarm_raised` plays Mercer's 5 s abort line ("That's the alarm. They're
  wiping the array. It's over.") and then `heist_ended(success = false, fail_reason =
  &"stealth_only_alarm")`. There is no loud phase, no assault and no police spawning (see Loud).
- **It uses the full P2 set:** cameras and the camera operator (S8.1–S8.2), ECM (S8.4–S8.6),
  keycards (S9.6), a code note (S9.7), a saw (S9.4), a time-locked safe (S9.8), a laser grid
  (S9.10), a bag zipline, ladders and a services riser (S9.11), the new `hack_terminal` (QC-12),
  guard cuffs (S3.2) and the 4-pager cap (S5).
- **Because an alarm is final, the heist is generous with routes and demanding with timing:** five
  ways in (roof door, terrace, services riser, window-washer gondola, service level), two
  floors of BOH with a camera-free line on each floor for every camera layout (see Sightlines),
  and a security room laid out so a careful player can work **behind the operator's back**.
- **Casing:** the crew starts unmasked. Only the **L40 service lobby is PUBLIC** (contractor
  cover). The roof and both K&M floors are RESTRICTED, so casing works (slow ×0.35 fill, S1.1)
  but is risky. Unmasked crew cannot climb ladders, so the riser, the gondola ladders and the
  terrace ladder need the mask (S1.1).
- **Being cuffed is effectively the end:** a guard who spots a masked player yells, pauses ~5 s,
  walks over and cuffs (S3.2); his radio call after the cuff raises the alarm. A teammate who kills
  him before the radio saves the run at the cost of a pager. In solo the cuff is a fail. This is
  intended: it is the stealth-only heist's skill check.
- **Sawing is a deliberate last resort.** The cage saw (90 s) runs at the cage gate, 4 m from the camera
  operator's seat through one wall, inside the saw's 12.5 m occluded radius (S4.3), and C3/K10 is
  on two patrol loops. It is there so a bad code roll never makes the job impossible, not as the
  normal way in. The archive safe saw is the optional greed choice: it is far from the security
  room but on the L41 rover's south loop and the cleaner's route.
- **Difficulty notes:** Routine runs 2 guards + operator (60%), 1–2 cleaners. Brutal runs 4 guards
  + operator, 2–3 cleaners, sweeping lasers more often, and the `timelock_extended` event.
  Lethal/Cataclysm run 5 guards; **from Hazardous up the guard count can exceed the pager cap**, so
  ghosting some guards is required. That is intended. Lethal+ cameras are Titan (indestructible,
  S8.1): ECM or the operator only.

## Site
- **Building:** Calder Tower, 42 storeys. The play space is the top: **L40** (service level, only
  the service lobby and its stair are in play), **L41** (offices, floor plate 36 × 24 m between wall
  centre lines; outer face 36.4 × 24.4 m), **L42** (partners' floor, 36 × 18 m, set back from the
  south facade to make the 36 × 6 m terrace on the L41 roof slab), **roof** (36 × 18 m, helipad,
  plant, BMU). Local L40 FFL = 0.0 m; the street is ~160 m below.
- **Neighbours** (all dressing; see the site plan):
  - **Arden Tower** (west, across 20 m of Quarry Lane): 48 storeys, roof 22 m above ours, red
    aircraft beacons. The insertion line runs from its maintenance level to our SW parapet.
  - **Vantage House** (east, across 30 m of Hale Street): roof 12 m **below** ours (at our L40
    level), with plant and Mercer's line anchor. The **E2 line** runs down to it.
  - **North:** open view over Riverside Drive and the Kestrel River (bridges lit, far bank ~600 m).
  - **South:** Calder Street far below, then a skyline of 30–40-storey towers 40–80 m away.
- **Exterior landmarks:**
  1. the **tower crown**: cold-white LED fins on the parapet and the green-lit helipad;
  2. the **double-height reception** with the floating feature stair and the etched glass-teal
     "K&M" logo wall, seen through the north curtain wall and from the gallery and lounge;
  3. the **art hall's red laser grid** across the graphite wall with two lit paintings, visible
     from the gallery through the art-hall doors.
- **Play space:** x −2…+38, z −2…+26, y from L40 FFL to the roof (+11.6, plant roofs +15.4).
  Everything beyond is a long drop or dressing. Each edge is closed as follows (the `bounds`
  validator checks every one):

### Play-space closure

| Edge | Closure |
|---|---|
| Roof parapets N/W/E (z 0, x 0, x 36) and S (z 18, over the terrace) | 1.1 m solid parapet with a **55° sloped coping** (≥ 50°, D-104 slopes; steeper than the 45° walkable slope, so nobody can stand on it; the player's 1.08 m jump apex is below the top). Beyond it a **`MapZone.OUT_OF_BOUNDS`** curtain (0.5 m outside the outer face, from coping height down to −20 m) respawns crew at the roof `oob_respawn` spawns, never an alarm (D-040). |
| Terrace balustrade S/E/W (z 24, x 0, x 36 at L42 level) | 1.1 m laminated glass balustrade with a round handrail (no standing surface), OOB curtain beyond. The terrace (exterior) is fully enclosed by the L42 facade on the north. |
| BMU boarding gates | The two boarding ladders `h` start at hinged gates in the parapet on the BMU track. A gate is open only where the cradle hangs (`gondola` slot); otherwise it is a closed parapet section. |
| Gondola cradles (when hung) | 1.1 m guard rails on three sides; the facade side gap is ≤ 0.15 m. OOB zone under the cradle deck. |
| Curtain wall (every facade) | Laminated glass, **not** a `window` prefab (not breakable, not openable). The only openings are the two **facade access doors** (gondola stops), the terrace sliders and the roof doors. |
| L40 vacant floor | The rest of L40 (refit, sealed) is behind **locked solid fire doors** (`X`, no prefab, no interaction): the S1 east door and Stair A's L40 door. No glazing looks into it. |
| Stairs below L40 | Steel-mesh **security gates** (2.1 m) on the L40 floor landing of both stairs. One flight and the half landing below are modelled behind the mesh, then dark. |
| Lift shafts | Landing doors closed and locked out (no interaction, no gaps). Car positions are a light on the call panel only. |
| Insertion line (W) | Static cable dressing from the SW parapet anchor frame to Arden Tower. Not interactable. |
| E2 line (E) | `zipline` (bags) + the E2 escape zone at the anchor. The cable is visual; the Vantage end and its SECURE zone are beyond the OOB curtain. |
| Down | Street grid at −160 m as low-poly LOD dressing: lit streets with traffic light ribbons, block roofs with plant, the river to the north. Nothing reachable looks into the void. |
| Sideways | Arden Tower facade (W, lit/dark office floors to +22 m), Vantage House roof (E), the south skyline (facades with lit floors and beacons), the open river view (N) closed by the far-bank skyline at ~600 m. |
| Up | Overcast night sky; low cloud lit orange-teal from below by the city; rain. |

Falling cannot happen by geometry. The OOB zones are a safety net only. Bags that land in OOB return
to their last secure-able position (D-040).

### Site plan
1 char = 2 m (x) and 1 row = 2 m (z); origin and axes as the floor plans; heights relative to the
Calder roof. `%` neighbour/dressing, `#` Calder roof parapet, `r` terrace balustrade (L42 level),
`*` helipad, `=` E2 bag/escape line, `-` insertion line (dressing), `:` street canyons far below,
`P1…P4` police spawn directions (contract only; never used, see Loud).

```
   x  -60       -40       -20       0         20        40        60        80        1
 -24  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      ~~ KESTREL RIVER (far below; bridges lit) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 -20  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      
 -16    RIVERSIDE DRIVE (street level, ~160 m below)
      
 -12  
      
  -8  
      %%%%%%%%%%%%%%%%%%%%     :      P3 roof (rappel from heli)
  -4  %%%%%%%%%%%%%%%%%%%%     :                             :
      %%%%%%%%%%%%%%%%%%%%     :                             :       %%%%%%%%%%%%%%%%%%
   0  %%%%%%%%%%%%%%%%%%%%     :    ###################      :       %................%
      %%%%%%%%%%%%%%%%%%%%     :    #           ******#      :       %................%
   4  %%%%%%%%%%%%%%%%%%%%     :    #CALDER     *    *#      :       %................%
      %%%%%%%%%%%%%%%%%%%%     :    #TOWER RF   *pad *#      :       %................%
   8  %% ARDEN TOWER %%%%%     :    #           *E1  *#      :       %.VANTAGE HOUSE..%
      %% 48 st, roof+22 %%     :    #           *    *#      :       %.roof -12 (L40).%
  12  %%%%%%%%%%%%%%%%%%%%insertion line ->     ******#E2 bag+escape %................%
      %%%%%%%%%%%%%%%%%%%%----------#                 #line, -12 m   %.E2 line end....%
  16  %%%%%%%%%%%%%%%%%%%%     :    #P spawn SW       #==============%.[SECURE].......%
      %%%%%%%%%%%%%%%%%%%%     :    rrrrrrrrrrrrrrrrrrr      :       %................%
  20  %%%%%%%%%%%%%%%%%%%%     :    rterrace L42      r      :       %................%
      %%%%%%%%%%%%%%%%%%%%     :    r                 r      :       %................%
  24  %%%%%%%%%%%%%%%%%%%%     :    rrrrrrrrrrrrrrrrrrr      :       %................%
      %%%%%%%%%%%%%%%%%%%%QUARRY LN (20 m)             HALE ST (30 m)%................%
  28  %%%%%%%%%%%%%%%%%%%%     :                             :       %%%%%%%%%%%%%%%%%%
      %%%%%%%%%%%%%%%%%%%%     :P1 Stair A (below) P2 Stair B (below)
  32                                  P4 passenger lifts (L41)
      
  36    CALDER STREET (street level, ~160 m below; LED street lights, traffic)
      
  40  
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  44  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %%%%% SOUTH SKYLINE: 30-40 storey towers, lit floors, beacons %%%%%%%%%%%%%%%%%%%
  48  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  52  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
```

## Floor plans
1 char = 0.5 m. Each character is a **grid point** (x = 0.5·col). Lines are **wall centre lines**:
exterior (curtain wall) 0.4 m, interior 0.2 m, core/stair/shaft walls 0.3 m. Origin is the NW
corner of the floor plate; +x is east and +z is south (river at the top, Calder Street at the
bottom). Rulers are in metres. The plans are generated by
`tools/levelcheck/plans/shadow_ledger_floors_ascii.py` (room rectangles in metres); its `--check`
mode verifies that the rooms tile each footprint exactly, that every door sits on a wall, that
every room has a door, and the stair arithmetic below.

Legend: `#` exterior wall / parapet / solid facade bay, `W` curtain-wall glazing, `|`/`-` interior
wall, `+` wall junction, `D` door, `X` locked door to the sealed vacant floor, `A` **facade access
door** (gondola stop), `r` 1.1 m railing/balustrade, `^ v` U-stair (up-flight, return flight),
`=` (in a stair) the void over the arriving flight at a stair's top floor, `^^^___^^^` feature stair
(flight, landing, flight), `<` feature-stair arrival, `.` reception void, `:` laser grid, `G` guard
post / pause point, `K` keycard slot, `c` code-note slot, `T` laptop slot, `L` loot, `S` safe,
`xxx` server cage (`D` = cage gate), `M` camera-station monitor wall, `o` operator seat, `R`
riser access panel / hatch, `@n` camera Cn, `h` gondola boarding ladder top, `H` terrace ladder,
`~` BMU rail, `P` player spawns, `E1…E3` escapes, `[BH]` bins (`body_container`).

**Vertical data** (`HeistMap.floor_heights = [0.0, 3.6, 8.0, 11.6]`; the roof is listed because
Stair A and the ladders arrive on it; ascending and containing 0.0 per D-040):

| Level | FFL | Ceiling | Floor-to-floor / slab | Notes |
|---|---|---|---|---|
| L40 (service) | 0.0 | 3.0 | 3.6 (0.6 plenum + slab) | service lobby ✓ |
| L41 (offices) | 3.6 | **3.6 reception** (under the gallery); 3.0 offices; 2.7 corridors, WCs, BOH | 4.4 (0.8 over the 3.6 reception; the 1.4 m plenum over 3.0 rooms carries the riser branch ducts and server cooling, as Glasshouse's BOH) | lobby 3.0–4.5 ✓; office 2.6–3.0 ✓ |
| Reception void | 3.6 → 11.0 | 7.4 m double height (to the L42 ceiling) | — | atrium ≤ 10 ✓ |
| L42 (partners) | 8.0 | 3.0; 2.7 corridors, WCs, BOH | 3.6 to the roof (0.6) | residential/office ✓ |
| Roof | 11.6 | head house, riser bay and plant room 3.5 clear (roofs at +15.4) | — | parapet 1.1 m |
| Stairs A and B | 0.0 → 3.6 | U-stair, 2 flights × 10 risers @ 0.180 m, tread 0.28 m (run 2.52 m), width 1.2 m | 20 risers = 3.6 ✓ | landing every 10 ≤ 16 ✓ |
| Stairs A and B | 3.6 → 8.0 | 2 flights × 12 risers @ 0.1833 m, tread 0.28 m (run 3.08 m) | 24 risers = 4.4 ✓ | landing every 12 ≤ 16 ✓ |
| Stair A only | 8.0 → 11.6 | 2 flights × 10 risers @ 0.180 m (run 2.52 m) | 20 risers = 3.6 ✓ | Stair B tops out at L42 |
| Feature stair | 3.6 → 8.0 | straight, 2 flights × 12 risers @ 0.1833 m, tread 0.28, width 1.4 m, landing 1.5 m; x 12.84–20.50, z 0.6–2.0, in the void (no slab above) | 24 risers = 4.4 ✓ | glass balustrades 1.1 m |

**Stair core fit** (both cores identical, 3.0 × 6.0 m centre lines, 0.3 m walls → 2.7 × 5.7 m
clear): flights 1.2 + 0.2 well + 1.2 = 2.6 ≤ 2.7 ✓. Along z (clear z 10.65–16.35): half landing at
the north end, flights, floor landing at the south end. The longest storey (4.4 m) needs 1.30 +
3.08 + 1.30 = 5.68 ≤ 5.70 ✓. Every up-flight **starts at the same edge (z 15.03)**, so the half
landing absorbs the shorter 2.52 m runs (1.86 m deep), and a flight is always one full storey
(≥ 3.6 m) under the flight above it: headroom ≥ 3.3 m ✓. Stair doors (1.0 m) sit on the south
floor landing (z 15.25–16.25), so they open onto a level landing, never a flight. Every stair door
has a 0.15 × 0.6 m vision panel (interior glazing with a purpose: see who is in the stair).

### L40 service level (FFL 0.0; cropped to x 10–32, z 6–18)
```
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2
  6.0 
                  vacant floor (sealed)
  7.0 
          +-----+-----+-----+-----+-----------+
  8.0     |     |     |     |SVC  |S1         |
          |     |     |     |     |           |
  9.0     |     |     |     |     D           |
          |     |     |     |E3   D   P P     |
 10.0     |     |-----+-----|     |           X
          +-----|     |     |-----|           |
 11.0     |ST.A |     |     |ST.B |           |
          |     |     |     |     |           |
 12.0     |^   v|     |     |^   v|           |
          |     | core WCs  |         --------+
 13.0     |^   v|     |     |^   v|S3|S2      |
          |     | (no access)     |  |        |
 14.0     |^   v|     |     |^   v|  |        |
          |     |     |     |     |  D        |
 15.0     |     |     |     |     |  | [BH]   |
          X     |     |     |     D  |        |
 16.0     X     |     |     |     D  |        |
          +gate-+-----+-----+gate-+--+--------+
 17.0 
      
 18.0 
```

### L41 offices (FFL 3.6)
```
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6
  0.0 #WWWWWWWWWWWWW#WWWWWWWWW#WWWWWWWWWWWWWWWWWWWWWWW#WWWWWWWWW#WWWWWWWWWWWWW#
      WK1 KESSLER   |K2 CONF  |K3 RECEPTION        @1 |K4 ASSIST|K5 MOOR      W
  1.0 W             |         | ^^^^^^___^^^^^^^      |         |             W
      W             |         | ^^^^^^___^^^^^^^      |         |             W
  2.0 W     T       |         |                       |         |     T c     W
      A  K          |         |                       |         |             W
  3.0 A             |         |  feature stair        |         |             W
      A             |         |                       |         |             W
  4.0 W             |         |                       |         |             W
      W             |         |         G K           |         |             W
  5.0 W             |         |        =======        |         |             W
      W             |         |                       |         |             W
  6.0 #----------D-------D----|                       |----D-------D----------#
      WK6                     D                       DK7                     W
  7.0 W@2                     D                       D                    @5 W
      #---D----------------    -------DDD---DDD-------    ---------------D----#
  8.0 WK8 OPEN OFFICE      |K9|JAN  |LIFT |LIFT |SVC  |K10K11 SERVER|K12      W
      W@11                 |  |     |     |     |     |  |  xxxxxxxx|         W
  9.0 W                    |  D    R|     |     |     D  |  xL L L x|        cW
      W                    |  |     |     |     |     D  |  x      x|         W
 10.0 W                    |  |     |-----+-----|     |  D  x RACK x|         W
      W                    |  |-----|WC-W |WC-M |-----|@3|  xxxDxxxx|   K     W
 11.0 W                    |G |ST.A |     |     |ST.B |  |          |         W
      W                    |  |     |     |     |     |  | c        |         W
 12.0 W       G            D  |^   v|     |     |^   v|  |          |         W
      W                    |  |     |     |     |     |  |--------------------#
 13.0 W                    |  |^   v|     |     |^   v|  |K13     |K14 |K15   W
      W                    |  |     |     |     |     |  |K      M|    |      W
 14.0 W                    |  |^   v|     |     |^   v|  |       M|    |      W
      W                    |  |     |     |     |     |  D      oM|    |      W
 15.0 W                    |  |     |     |     |     |  |       M|    |      W
      W                    |  D     |     |     |     D  |        |    |      W
 16.0 W                    |  D     |     |     |     D  |c       |    |      W
      #---------D----------    --------D-----D--------    -----------D----D---#
 17.0 WK16 CORRIDOR (C2)                                        G          @4 W
      W                                                                       W
 18.0 #-----D-----------D-----------D--------D-----D-----D-----D--------D-----#
      WK17 ARCHIVE|K18 BREAK  |K19 LIBRARY|K20  |K21  |K22  |K23  |K24        W
 19.0 W           |           |           |     |     |     |     |           W
      W           |           |           |     |     |     |     |           W
 20.0 W           |           |           |     |     |     |     |           W
      W           |           |           |     |     |     |     |           W
 21.0 W           |           |           |     |     |     |     |           W
      W           |           |           |     |     |     |     |           W
 22.0 W           |           |           |     |     |     |     |           W
      W           |           |           |     |     |     |     |           W
 23.0 W S L       |           |           |     |     |     |     |           W
      W           |           |           |     |     |     |     |           W
 24.0 #WWWWWWWWWWW#WWWWWWWWWWW#WWWWWWWWWWW#WWWWW#WWWWW#WWWWW#WWWWW#WWWWWWWWWWW#
```

### L42 partners' floor and terrace (FFL 8.0)
```
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6
  0.0 #WWWWWWWWWWWWWWWWWWWWWWW#WWWWWWWWWWWWWWWWWWWWWWW#WWWWWWWWW#WWWWWWAAAWWWW#
      WM1 LOUNGE              |........ VOID ..r      |M3  :  @7|M4 STUDY     W
  1.0 W K                     |                 <     |    :    |             W
      W                       |................ <     |    :    |             W
  2.0 W                       |                       |    :    |   T         W
      W                       |................r      D    :    |             W
  3.0 W                       |                       D    :    |             W
      W                       |................r      D    :    D             W
  4.0 W                       rrrrrrrrrrrrrrrrr       |    :    |             W
      W                                               |    :    |             W
  5.0 W                         M2 GALLERY            |    :    |             W
      W                                           G   |    :    |             W
  6.0 W                                               |    :    |             W
      W                                               |    :    |             W
  7.0 W                        @6                     |    : L L|       S L   W
      #--------------------    -------DDD---DDD-------+-D---------------------#
  8.0 WM5 BEDROOM  |M6 BATH|M9|LINEN|LIFT |LIFT |SVC  |M10M11 PANTRY|M14      W
      W            |       |  |     |     |     |     |  |          |         W
  9.0 W K          |       |  D    R|     |     |     D  |          |         W
      W            |       |  | K   |     |     |     D  |          |         W
 10.0 W            |       |  |     |-----+-----|     |  D          |         W
      W            |       |  |-----|WC-W |WC-M |-----|  |          |         W
 11.0 W            |---D---|  |ST.A |     |     |ST.B |  |          |         W
      W            |M7     |  |     |     |     |     |  |          |         W
 12.0 W            D       D  |^   v|     |     |=   v|  |----------|    T    W
      W            |       |  |     |     |     |     |  |M12 |M13  |         W
 13.0 #--------------------|  |^   v|     |     |=   v|  |    |     |         W
      WM8 DINING           |  |     |     |     |     |  |    |     |         W
 14.0 W                    |G |^   v|     |     |=   v|  D    |     |         W
      W                    |  |     |     |     |     |  |    |     |         W
 15.0 W                    D  |     |     |     |     |  |    |     |         W
      W                    |  D     |     |     |     D  |    |     |         W
 16.0 W                    |  D     |     |     |     D  |    |     |         W
      W                        --------D-----D--------    -------D-------D----#
 17.0 W                    |M15 TERRACE CORRIDOR (S42)            G           W
      W                    |@8                                                W
 18.0 rWWWWWWWDDD###WWWWWWW#WWWWWWDDDWWWWWWWWWWWWWWWWWWWWWWWWWWWWWDDDWWWWW###Wr
      r           @12                                                         r
 19.0 r                                                                       r
      r                                                                       r
 20.0 r                                                                       r
      r                                                                       r
 21.0 r   TERRACE (exterior; glass balustrade r 1.1 m; OOB zone beyond)       r
      r                                                                       r
 22.0 r                                                                       r
      r                                                                       r
 23.0 r                                                                       r
      r                                                                       r
 24.0 rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr
```

### Roof (11.6)
```
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6
  0.0 #########################################################################
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~h~~   #
  1.0 #~                                                                      #
      #~ [BMU + cradle garage]                                                #
  2.0 #~ BMU rail ~ (N + W parapets)                                          #
      #~                                                                      #
  3.0 #~h                                               ********************* #
      #                                                 *                   * #
  4.0 #                                                 *                   * #
      #                                                 *                   * #
  5.0 #                                                 *                   * #
      #                                                 *                   * #
  6.0 #                                                 *                   * #
      #                                             @10 *                   * #
  7.0 #                                                 *                   * #
      #                       +-----+-------DDD-------+ *                   * #
  8.0 #                       |RISER|R3 PLANT         | *   HELIPAD 10x10   * #
      #                       |     |                 | *      E1 (heli)    * #
  9.0 #                       D    R|                 | *                   * #
      #                       |     |                 | *                   * #
 10.0 #           G           |     |                 | *                   * #
      #                       +-----|                 | *                   * #
 11.0 #                     @9|     |                 | *                   * #
      #                       |HEAD |                 | *                   * #
 12.0 #                       |HSE  D                 | *                   * #
      #                       |St.A |                 | *                   * #
 13.0 #                       |     |                 | ********************* #
      #                       |     |                 |                       #
 14.0 #                       |     |                 |                       #
      #     (insertion line from Arden Tower, W)      |                       #
 15.0 #                       |     |                 |                       #
      #   P P P P             D     |                 |           G           #
 16.0 #                       D     |                 |                       #
      #                       +-----+-----------------+                   E2> #
 17.0 #                                                                       #
      #                                                                    H  #
 18.0 r#######################################################################r
      r                                                                       r
 19.0 r                                                                       r
      r                                                                       r
 20.0 r                                                                       r
      r                                                                       r
 21.0 r   (terrace below, L42 level: 3.6 m down; ladder H at the SE parapet)  r
      r                                                                       r
 22.0 r                                                                       r
      r                                                                       r
 23.0 r                                                                       r
      r                                                                       r
 24.0 rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr
```

L40 notes: only S1/S2/S3, the service lift and Stair B are in play. The core WCs, lifts and janitor
on L40 open onto the vacant floor (not in play). The service lift car (`E3`) waits at L40.

## Room list
Sizes are between wall centre lines. Clear size = minus 0.1–0.2 m per side. Sill heights: offices,
corridors and BOH have a 0.9 m fritted graphite spandrel band inside the curtain wall (sill 0.9);
reception, lounge, gallery, study, dining and the terrace corridor have feature glazing from 0.3 m
(shop-front rule). Partner, conference and boardroom fronts are **frosted** glass (opaque for LOS).

| id | purpose (`RoomVolume.purpose`) | size m | ceiling m | kit | notes |
|---|---|---|---|---|---|
| S1 | lobby (service lift lobby, L40) | 6 × 5 | 3.0 | `service_lobby` | **PUBLIC.** Service lift landing (`E3`), freight dolly, notice board, contractor sign-in clipboard, locked fire door to the vacant floor. `pp_spawn_service` spawns. |
| S2 | storage (refuse, L40) | 4.5 × 4 | 3.0 | `refuse_room` | 2 wheelie bins (`body_container`, BODY_HIDE, 1 body each), recycling cages. Drop zone `pp_drop_refuse`. |
| S3 | corridor (service, L40) | 1.5 × 4 | 3.0 | `corridor_service` | S1 → Stair B. |
| SA | stair (A) | 3 × 6 | open | — | L40 → L41 → L42 → roof. L40 door to the vacant floor locked; mesh gate below L40. Push-bar on the floor side; **lockpick 8 s from the stair side** at L41/L42 (re-entry control). |
| SB | stair (B) | 3 × 6 | open | — | L40 → L41 → L42 (top). L40 door to S3 always open (egress). L41/L42 doors as SA. |
| LF1, LF2 | lift shaft | 3 × 2.5 | — | — | Passenger lifts, **locked out 22:00–06:00** (key switch at the ground lobby). Doors open N into K3 (L41) and M2 (L42); closed, no interaction. |
| SL | lift shaft (service) | 3 × 3 | — | — | Car parked at L40 (`E3`). Landing doors at L41/L42 open into K10/M10 and are **locked out** (the K&M key switch is with ground-lobby security). No interaction on L41/L42. |
| WCW, WCM | restroom | 3 × 6.5 each | 2.7 | `restroom_exec` (SL-1: stone vanity, downlights) | On L41 and L42: 3 stalls/urinals, sink counter, mirror. Doors S. |
| J (L41) | storage (janitor + riser access) | 3 × 3 | 2.7 | `janitor_sl` (SL-1) | Mop sink, cleaner's cart, shelving. **Riser access panel `R`** (1.5 × 1.5 riser in the NE corner; `vent_l41` = panel off). BODY_HIDE (1). |
| K1 | office (partner: Victor Kessler) | 7 × 6 | 3.0 | `office_partner` | Desk, credenza, sofa, bookshelves, bar cart, phone. `kc_kessler`, `lap_kessler`. **Facade access door `A`** on the west wall (gondola west stop; door prefab, lockpick 8 s from the cradle side). |
| K2 | office (conference) | 5 × 6 | 3.0 | `conference_room` | Table for 10, screen, credenza, frosted front. |
| K3 | lobby (reception) | 12 × 7.5 | 3.6 / void 7.4 | `reception_exec` | **Landmark.** Reception desk (1.05 m transaction ledge, 0.72 m work top) with the **fixed guard post**; `kc_reception` in the desk drawer; desk phone + `alarm_button` under the ledge. Feature stair up the north glazing, "K&M" logo wall (east), lounge chairs, lift doors (S). Glass doors W and E (0.9 m). Camera C1. |
| K4 | office (executive assistant) | 5 × 6 | 3.0 | `office_small` | Two desks, partner calendars, printer, phone. |
| K5 | office (partner: Helena Moor) | 7 × 6 | 3.0 | `office_partner` | Desk, meeting table, phone. `lap_moor`, `code_moor_planner`. Windows N and E. |
| K6, K7 | corridor (office, NW and NE) | 12 × 1.5 each | 2.7 | `corridor_office` | End windows W / E. C2, C5. |
| K8 | office (open plan, associates) | 10.5 × 9 | 3.0 | `office_open_law` (SL-1: the shared `office_open` wants a gem scope) | 12 workstations in 3 clusters, 2 printers, plants, coat rack. Doors to K6, K9 and K16. C11. |
| K9 | corridor (C1, west core) | 1.5 × 9 | 2.7 | `corridor_office` | Stair A door, janitor door. |
| K10 | corridor (C3, east core) | 1.5 × 9 | 2.7 | `corridor_service` | Server door (keycard), service lift door, Stair B door, security door. C3 (above the server door, looking N). |
| K11 | server_room | 5.5 × 5 | 2.7 | `server_room_sl` (SL-1: no desk in K11, PO6-06) | **The cage** (3.5 × 2.0 m mesh enclosure at x 27–30.5, z 8.5–10.5, gate on its S side, clear of the server door's swing; `safe` LARGE, `methods [code, saw]`, `code_group cage`): the ledger rack with the **`hack_terminal`** (drive-bay release) and 3 drive-sled `loot_spawn`s (`loot.ledger_drives`), all children of the cage (enabled when it opens). CRAC unit, UPS, cable trays. Door: **keycard** (`keycard_reader` on K10). Vision panel to K12. No facade. `code_contractor` on the contractor's laptop (srv_contractor). |
| K12 | office (IT) | 5 × 5 | 3.0 | `office_it` | Two desks, spares shelving, whiteboard (`code_it_board`), `kc_it`, phone. Vision panel into K11. Windows E. |
| K13 | security_room | 4.5 × 4 | 2.7 | `security_office_sl` (SL-1: the operator's place stays clear) | **`camera_station` with its monitor wall against the solid east wall** (K14 partition); the operator faces **east**, so the door (west) is directly behind him. Key cabinet on the north wall behind him (`kc_security`), logbook on the SW counter (`code_security_log`), lockers, coffee, phone, `alarm_button` on the console. Door unlocked (closed; the operator's coffee runs). No windows. |
| K14 | electrical | 2.5 × 4 | 2.7 | `electrical_sl` (SL-1) | Switchboard, telecom rack. Door S. |
| K15 | storage (copy and mail) | 3.5 × 4 | 3.0 | `copy_room` | Copier, paper stock, shredder, mail sorter. Windows E. |
| K16 | corridor (C2, south spine) | 36 × 1.5 | 2.7 | `corridor_office` | Full-width spine with end windows. C4 (east end). The L41 rover's main loop. |
| K17 | storage (records archive) | 6 × 6 | 3.0 | `archive_records` (SL-1: the shared `storage_archive` is a stock room) | Compact shelving, file boxes, the **document safe** (`safe` MEDIUM, `methods [saw]`, 1 bag `loot.cash`: the partners' cash float). Windows W and S. |
| K18 | break_room | 6 × 6 | 3.0 | `break_room_office` (SL-1: no lockers) | Fridge, counter with sink, microwave, coffee machine, table with 6 chairs, bulletin board, phone. Windows S. |
| K19 | office (law library) | 6 × 6 | 3.0 | `library_law` | Book stacks, reading table, lamps. |
| K20–K23 | office (associates) | 3 × 6 each | 3.0 | `office_small` | Desk, 2 chairs, shelf; one is a paralegal file room. |
| K24 | office (interview room) | 6 × 6 | 3.0 | `meeting_small` | Round table, 4 chairs, screen. Windows S and E. |
| J (L42) | storage (linen and janitor + riser) | 3 × 3 | 2.7 | `linen_janitor` (SL-1) | Linen shelves, the L42 cleaner's cart (`kc_cleaner`), **riser panel `R`** (`vent_l42`). BODY_HIDE (1). |
| M1 | lounge (partners' lounge) | 12 × 7.5 | 3.0 | `lounge_exec` | Bar with backlit teal glass (`kc_lounge`), 2 sofa groups, piano, glass wall over the reception void. Windows N and W (from 0.3 m). Ceiling override 2.6–3.0 (QC-31): a residential lounge, same band as living_room; no `lounge` row in the table. |
| M2 | lobby (gallery / mezzanine) | 56 m² (walkway 8.5 × 3.5 + landing 3.5 × 7.5) | 3.0 | `gallery_mezzanine` | Walkway along the void (1.1 m glass balustrade), feature-stair arrival, lift doors (locked out), sculpture plinths. C6. |
| M3 | gallery (art hall) | 5 × 7.5 | 3.0 | `art_hall` | **Laser grid** across the room at x 26.5 (full 7.5 m width; 0–2.6 m high, 0.9–2.5 m for `lz_static`). West part: sculpture and art dressing. East part: **2 paintings** (`loot_spawn` `loot.painting`, cut from the frame 4 s) and the study door (lockpick 8 s). Double doors from M2 (1.8 m, open), staff door from M10. C7 (NE corner). Picture lights. Ceiling override 3.0–4.5 (D-075): `gallery` is now the top-lit 4.5–6.5 m band; this private art hall keeps the partners' floor 3.0 m ceiling (the retail/lobby band it validated against before). |
| M4 | office (Kessler's private study) | 7 × 7.5 | 3.0 | `study_exec` | Desk (`lap_study`), bookshelves, armchairs, the **study safe** (`safe` MEDIUM, KEYCARD method bound to its reader, `time_lock_s` scalar) on the south wall: 1 bag `loot.ledger_books` + 3 `small_loot` (bearer bonds, watches). **Facade access door `A`** on the north wall (gondola north stop). |
| M5 | bedroom (guest suite) | 6.5 × 5.5 | 3.0 | `bedroom_exec` | Bed, nightstands (`kc_guest`), wardrobe, armchair, bedside phone. `alarm_button` by the bed (used by `kessler_sleepover`). Windows W. |
| M6 | restroom (en-suite) | 4 × 3.5 | 2.7 | `bathroom_ensuite` | Shower, WC, double vanity. Internal (no window). |
| M7 | dressing (suite vestibule / dressing room; QC-30) | 4 × 2 | 2.7 | `dressing_room` | Wardrobes, mirror; the suite's door from M9. Ceiling override 2.6–3.0: a dressing room is residential space (bedroom/bathroom row), no row of its own in the table. |
| M8 | dining_room (private dining) | 10.5 × 5 | 3.0 | `dining_exec` | Table for 10, sideboard, wine fridge; **terrace slider** (S, lockpick 8 s from outside). Windows W and S. Ceiling override 2.6–3.0 (QC-31): private dining is residential space at the 3.0 m partners' floor ceiling; no `dining_room` row in the table. |
| M9 | corridor (W42) | 1.5 × 9 | 2.7 | `corridor_office` | Stair A door, linen door, suite and dining doors. |
| M10 | corridor (E42) | 1.5 × 9 | 2.7 | `corridor_service` | Dead end **with a reason**: it ends at the service lift door and the art-hall staff door. Stair B door, pantry and electrical doors. |
| M11 | break_room (pantry) | 5.5 × 4.5 | 2.7 | `break_room_office` | Catering pantry and staff kitchen: fridge, counter with sink, microwave, coffee, table for 4, bulletin board, phone. |
| M12 | electrical | 2.5 × 4.5 | 2.7 | `electrical_sl` | Sub-board, AV rack. |
| M13 | storage (wine room) | 3 × 4.5 | 2.7 | `wine_room` | Wine racks, humidor (2 `small_loot`). Door S. |
| M14 | office (partners' boardroom) | 5 × 9 | 3.0 | `boardroom` | Table for 12, screen, credenza (`lap_boardroom`). Windows E. |
| M15 | corridor (S42 terrace corridor) | 25.5 × 1.5 | 2.7 | `corridor_glazed` | Glazed to the terrace with 2 sliders (lockpick 8 s from outside). C8 (west end, looking E). |
| X1 | exterior (terrace, L42 level) | 36 × 6 | — | `exterior_terrace` | Planters, loungers, outdoor kitchen, heaters, C12 on a solid facade bay (x 5.5–6.5), **fixed caged ladder** (3.6 m) to the roof at the SE bay (x 34–35). |
| R1 | plant (riser bay, roof) | 3 × 3 | 3.5 | `plant_riser` | Riser hatch + **caged ladder down the riser** (8.0 m, intermediate grating at L42). Padlocked door W to the roof (lockpick 8 s). |
| R2 | stair (A head house) | 3 × 6 | 3.5 | — | Stair A top landing; roof door W (lockpick 8 s from the roof; push bar from inside); door E to R3. |
| R3 | plant | 9 × 9 | 3.5 | `plant_room_roof` (SL-1: the shared `plant_room` wants a boiler) | Lift motor room, AHU, water tank, chiller. Door N to the roof. BODY_HIDE behind the AHU (2). Drop zone `pp_drop_plant`. |
| X2 | exterior (roof) | 36 × 18 | — | `exterior_roof_tower` (SL-1) | Helipad 10 × 10 m (x 25–35, z 3–13; green perimeter lights; the `E1` SECURE net), BMU on the N/W rail with its cradle garage (NW), boarding ladders `h`, insertion-line anchor (SW), E2 line anchor (E), aircraft beacons, roof drains, rain. |

Support-space check (level_standards §2.2): restrooms on L41 and L42 (2 each; L40's core WCs exist on
the vacant side) ✓; break room K18 and pantry M11 ✓; janitor J on both floors ✓; electrical K14/M12
and IT K12/K11 ✓; back entrance: the service lift to the tower's loading dock (via L40) ✓; **2
stair cores** for > 2 floors ✓; fire exits = both stairs; the longest travel to a stair door is ≈ 22 m (K1/K5 corners, M4 via M10) ✓.

## Circulation
- **Public (night):** none on L41/L42. L40 S1 is PUBLIC (the tower's service level).
- **Staff:** service lift (day) → L40 → Stair B, or passenger lifts → K3 reception → K6/K7 →
  rooms. L41 ↔ L42 by the feature stair (partners, guests) or Stair A/B (staff). L42 ↔ roof by
  Stair A only.
- **Guards** (one `tower` PatrolGraph across L41/L42 linked through stair PatrolPoints, plus a
  `roof` graph; ≥ 3 loop options per post):
  - **`post_reception` (fixed, L41):** desk (pause `phone`/`desk`, 30–60 s) and three loops:
    (a) desk → E door → K7 → K10 → K16 → K9 → K6 → W door → desk (the ring);
    (b) desk → W door → K6 → K8 (open office) → K16 → K18 (break) → K16 → K9 → K6 → desk;
    (c) desk → E door → K7 → K12 (IT) → K7 → K4/K5 doors → E door → desk.
  - **`rover_l41`:** the same graph plus the south spurs: (d) K16 → K17 → K16 → K19 → K16;
    (e) K16 → K24 → K16 → K10 → K13 (security, coffee pause) → K10; (f) K16 → K8 → K6 → K1/K2 doors.
  - **`rover_l42`:** (a) M2 landing → M2 walkway → M1 → M9 → M15 → M10 → M3 (west of the lasers,
    pause `look` 8 s facing the study door) → M2; (b) M2 → M3 → M10 → M11 (pantry pause) → M10 → M3
    → M2; (c) M9 → M7/M5 door → M9 → M8 → M15 → M14 → M15 → M9.
  - **`stair_watch` (fire watch, `guard_extra`):** (a) Stair A L41 ↔ L42 ↔ roof door (checks the
    door, pause 6 s); (b) Stair A L42 → M9 → M15 → M10 → Stair B → L41 K10 → K16 → K9 → Stair A;
    (c) Stair B L40 landing (checks the gate) → L41 → L42 → M10 → M15 → M9 → Stair A down → L41 → K16
    → K10 → Stair B.
  - **`roof_watch` (`guard_extra`):** (a) clockwise round the plant block (head house door → N side
    → pad W edge → E2 anchor → S strip); (b) the same anticlockwise; (c) head house door → BMU
    garage → west boarding ladder → back (pause `smoke` 20–40 s under the R3 canopy).
- **Civilians:**
  - cleaners work a floor each with a cart (`staff_clean_l41`: K8 → K16 → K18 → WCs → K3 → K6;
    `staff_clean_l42`: M1 → M2 → M15 → M8 → WCs → M11). Carts block 0.9 m doorways (cover);
  - the IT contractor goes K11 rack ↔ K12 desk ↔ K18 coffee ↔ WC (50–80 s away from the rack);
  - Helena Moor goes K5 desk (phone) ↔ K4 ↔ K18 ↔ WC-W ↔ K3 window (she leaves her laptop on the
    desk for 40–70 s windows);
  - Kessler (rare) stays in M5.
  - A panicked civilian runs to the nearest `phone` or `alarm_button` (S3.1). Phones: K1, K3, K4,
    K5, K12, K13, K18, M5, M11; alarm buttons: K3 desk, K13 console, M5 bedside. Fleeing into a
    stair counts as leaving the map (alarm).

### Staff, civilian and guard roster (spawn data)

| NPC | Count | Presence | Spawn tags | Idle activity | PatrolPoint tags |
|---|---|---|---|---|---|
| Security Officer (reception) | 1 | always (fixed spawn, K3 desk) | `guard_reception` | — (desk pause) | `guard`, `guard_l41` |
| Security Officer (L41 rover) | 0–1 | `guard_post` = `rover_l41` | `guard_rover_l41` | — | `guard`, `guard_l41` |
| Security Officer (L42 rover) | 0–1 | `guard_post` = `rover_l42` | `guard_rover_l42` | — | `guard`, `guard_l42` |
| Security Officer (fire watch) | 0–1 | `guard_extra` = `stair_watch` | `guard_stair` | — | `guard_stair` |
| Security Officer (roof) | 0–1 | `guard_extra` = `roof_watch` | `guard_roof` | — (pause `smoke`) | `guard_roof` |
| Camera operator | 0–1 | `security_room_staffed` | CAMERA_OPERATOR in K13 | `desk_work` | — |
| Cleaner (L41) | 1–2 | always 1; 2nd when `cleaners` = 3 | `civ_cleaner_l41` | `browse` (cleaning) | `staff`, `staff_clean_l41` |
| Cleaner (L42) | 0–1 | `cleaners` ≥ 2 | `civ_cleaner_l42` | `browse` (cleaning) | `staff`, `staff_clean_l42` |
| IT contractor | 0–1 | `server_room` = `srv_contractor` | `civ_it` | `phone` (standing at the racks; no seat in K11, PO6-06) | `staff`, `staff_it` |
| Helena Moor | 0–1 | `late_partner` = `moor_late` | `civ_partner` | `phone` | `staff`, `staff_partner` |
| Victor Kessler | 0–1 | rare `kessler_sleepover` | `civ_kessler` | `sit` (reading in the bedside armchair: on its `Seat` at (3.0, 12.3), back to the M5 south wall, PO6-06 / D-063 npc seat) | — (stays in M5) |

**Totals per difficulty** (guard counts from `guard_post`/`guard_extra` picks, `difficulty_add`):

| Difficulty | Guards (recep. + rovers + extras) | Operator | Pagers to clear everyone | Civilians (cleaners + contractor + Moor) | Notes |
|---|---|---|---|---|---|
| Routine | 1 + 1 + 0 = **2** | 60% | 2–3 | 1–2 + 0–1 + 0–1 = **1–4** | Everything can be killed and answered. |
| Tense | 1 + 1 + 0–1 = **2–3** | 60% | 2–4 | 1–4 | At the cap at worst. |
| Hazardous | 1 + 2 + 0–1 = **3–4** | 60% | 3–5 | 1–5 | Can exceed the cap. |
| Brutal | 1 + 2 + 1 = **4** | 60% | 4–5 | 2–5 | Exceeds the cap when the operator is in. |
| Lethal / Cataclysm | 1 + 2 + 2 = **5** | 60% | 5–6 | 2–5 | 1–2 guards must be ghosted; Titan cameras. |

`kessler_sleepover` adds 1 civilian. Cable ties: 2 per player. Solo (AI wait at the van, D-014)
means **avoiding** civilians, not tying them all.

## Sightlines
- **Reception guard** (K3 desk at (18, 4.3), seated facing S): sees the lift doors, the desk front
  and anyone crossing K3 between the lifts and the desk. The side glass doors (12, 6.75) and
  (24, 6.75) are 68° off his axis, outside the 120° FOV: crossing K3 along its south edge is
  possible while he sits. C1 covers exactly that strip in `cam_a`. The feature stair is behind him.
- **Security room:** the operator faces E at the monitor wall. The door, the key cabinet (N wall,
  west end) and the logbook (SW counter) are all **≥ 120° behind him**: entering quietly while he
  is seated is possible (no movement noise, S1.5). He gets up on his coffee pause (rover passing
  K13 in loop e). **This room is designed to be worked from behind**: it is the key to the hardest
  roll.
- **K10 (C3 corridor):** 9 m straight between Stair B (S end) and the K7 junction (N end). The
  reception ring (loop a) passes it; the security door is in it. Cover: the service-lift recess
  and the stair door recess.
- **K16 (C2 south spine):** 36 m straight. A guard in it sees end to end; cover comes from the 13
  door recesses. The south loop runs here: timing beats speed.
- **Art hall:** the lasers glow red across graphite walls. `rover_l42` pauses at the west part
  facing E (8 s): he looks through the grid at the study door. C7 watches the grid and the doors
  from the NE corner; **the study door beside its mount is blind to it**.
- **Gallery ↔ reception:** the void links them. Anyone on the M2 walkway is visible from K3 and
  vice versa; the reception guard faces S (away). A rover on the gallery sees the whole of K3.
- **Stairs:** 3 × 6 m boxes without cover. The stair-door vision panels show who is on the
  landing; the fire watch is the stair timing puzzle.
- **Roof:** the plant block (R1–R3, 12 × 9 m, 3.8 m high) splits the roof: a guard on the N side
  cannot see the S strip or the head-house door. From the pad he sees the E2 anchor.
- **Gondola:** from a hung cradle the crew can look through the curtain wall into K1 or M4 before
  committing (unmasked casing is not possible there: ladders need the mask).

**Cameras (`security_camera`, 2.6–3.2 m, 60° cone, 20 m):**

| Cam | Mount | Looks at | Notes |
|---|---|---|---|
| C1 | K3, NE corner (23.6, 0.4), 3.2 m | SW: lift doors, desk, the K3 south strip, the W glass door | The E glass door is beside the mount (blind). |
| C2 | K6, W end (0.4, 6.75) | E along K6 to the K3 W door (11.6 m) | Covers the K1/K2 doors. |
| C3 | K10, on the E wall **above the server door** (25.4, 10.6), 2.6 m | N: service-lift door, the K7 junction | **Watches the northern approach; the server door below it and the stretch south to Stair B are blind.** |
| C4 | K16, E end (35.6, 17.25) | W along K16 (to x ≈ 15.6) | |
| C5 | K7, E end (35.6, 6.75) | W along K7: IT, Moor and assistant doors, the K3 E door | |
| C6 | M2, at the J/linen corner (12.4, 7.2) | E along the walkway to the landing and the art-hall doors | The feature-stair top is in view. |
| C7 | M3, NE corner (28.6, 0.4), 2.6 m | WSW across the grid, the M2 doors and the M10 staff door | The study door (29, 3.5) is beside the mount: blind. |
| C8 | M15, W end (10.9, 17.25) | E along M15 (to x ≈ 30.9): WC doors, both sliders, the M10 junction | |
| C9 | roof, head house W wall (12, 11), 3.0 m | WNW over the west roof: BMU garage, west boarding ladder | The riser-bay door (12, 9) and the roof door (12, 15.75) are beside/behind it: blind. |
| C10 | roof, pole at the R3 NE corner (24, 7.5), 3.0 m | E over the helipad (`E1`) | |
| C11 | K8, NW corner (0.4, 8.0) | SE across the open office | |
| C12 | terrace, solid facade bay (6, 18.2) | E along the terrace (x 8–26) | The M8 slider (x 4.5), the E slider (x 30.5) and the ladder (x 34.5) are outside it. |

**Camera layouts and the camera-free line** (each layout leaves a camera-free path west↔east on each
floor and a camera-free drive-bag path from the server door to Stair A and to Stair B, so a ghost
never needs more than 2 ECM windows; see the hardest roll):

| Layout | Cameras | L41 W↔E free path | L42 W↔E free path | Server door → Stair A (roof) | Art hall | Roof |
|---|---|---|---|---|---|---|
| `cam_a` | C1, C3, C6, C9, C11, C12 | K16 south spine | M15 terrace corridor | K10 S → K16 → K9 (C3 looks N) | free (enter from M10) | C9: west (gondola-W ladder) |
| `cam_b` | C2, C5, C7, C8, C10, C11 | K16 south spine | M2 gallery | K10 S → K16 → K9 | C7: ECM or timing | C10: pad |
| `cam_c` | C3, C4, C6, C7, C9, C10 | north: K6 → K3 → K7 | M15 terrace corridor | **K10 S → Stair B up → M10 → M15 → M9 → Stair A** (K16 has C4, K10 N has C3) | C7: ECM or timing | C9 + C10 |

Server door → Stair B (for `esc_service`) is camera-free in every layout: C3 looks N and the stair
door is 5.75 m S of it.

## Stealth routes
All five approaches start on the roof (default spawn, SW corner under the insertion line) except
the service level, which is a spawn choice.

1. **Roof door (Stair A).** Read the roof guard's loop (the plant block hides the S strip), pick the
   head-house door (8 s, blind to C9) → Stair A → L42 (W side) or L41 (W side, K9). Tools: none.
   Risk: the fire watch in Stair A, and the camera on the corridor you exit into.
2. **Terrace.** Walk the S strip to the SE parapet, climb down the caged terrace ladder (3.6 m,
   masked) → pick the E slider (30.5, 8 s, outside C12 but at the edge of C8's range) → M15 → M10
   (Stair B, pantry, art-hall staff door). Or the M8 dining slider (behind C12) → M9. Risk: the L42
   rover's loop (c) through M15/M8; a roof guard at the S parapet sees the terrace.
3. **Services riser** (`vent_open`). Pick the R1 riser-bay door (8 s, blind to C9) → ladder down
   the riser (masked) → the loose panel (`vent_l42`: L42 linen J next to M9 and `kc_cleaner`;
   `vent_l41`: L41 janitor J next to K9 and Stair A). It skips the stairs and the fire watch. With
   `vent_sealed` the riser is a dead end (the panels are bolted from inside).
4. **Window-washer gondola** (`gondola`). Climb down the boarding ladder `h` (masked) into the hung
   cradle, pick the facade access door (8 s, in the rain; no camera sees either facade door, but
   C9 watches the west boarding-ladder top in `cam_a`/`cam_c`):
   - `gon_west_l41` → **K1 Kessler's office** (`kc_kessler`/`lap_kessler` slots), next to K6
     (C2). The 8.0 m ladder passes the M1 lounge glazing at L42.
   - `gon_north_l42` → **M4 the study**, **behind the lasers**: the laptop (`lap_study`) and the
     time-lock safe without crossing the grid.
   - `gon_stowed` → no gondola route.
5. **Service level** (pre-planning `asset.alternate_entry` → `pp_spawn_service`). Start in S1
   unmasked (PUBLIC) → Stair B (always open at L40) → L41 K10 door (8 s) beside the security room
   and the server room. This is the shortest route to the drives and the best one with `esc_service`.
   Risk: K10 is on the reception ring; the fire watch checks the L40 gate.

**Inside, the required line is:** laptop (one of 4 places) + keycard (server door, unless
`srv_contractor`) + cage code (or the saw) + the 45 s hack + 2 of 3 drive bags out.

**Pager budget:** pagers per guard as in the roster table. Routine to Tense can clear the floor
with pagers; from Hazardous up, at least one guard must be avoided. The operator is the most
valuable pager (all cameras off, S8.2) but sits in the busiest corridor.

**The hardest roll and its ghost line** (verifies the level_standards §4 MUST). Cataclysm, `cam_b`
(Titan), operator in, 5 guards (both rovers, fire watch, roof), `lap_study`, `lz_sweep`,
`gon_stowed`, `vent_sealed`, `srv_locked`, keycards `kc_security` + `kc_reception`,
`code_security_log`, `esc_heli`, 3 cleaners, `kessler_sleepover`. Solo, one ECM deployable (2
charges), **no kills, no pagers**:
1. Roof spawn (SW, outside C9). Mask when the roof guard turns N round the plant block. Pick the
   head-house door (blind to C9).
2. Stair A to L42 when the fire watch is on Stair B (vision panel). M9 → M1 → M2 (the gallery is
   camera-free in `cam_b`) → art-hall doors. **ECM #1** (C7): wait for the sweep gap (6 s period),
   cross, pick the study door in C7's blind spot. Take the laptop (LIGHT bag).
3. Out under **ECM #2** (C7) through the sweep gap → M2 → M9 → Stair A up → roof → around the S
   strip → pad. C10 looks E from (24, 7.5): standing just S of the pad at (26, 14) is 73° off its
   axis and the net's SW corner (25–27, 11–13) ≥ 55°, both outside the 60° cone, so throw the bag
   onto that corner from there (1–3 m; secured after 0.5 s).
4. Stair A down to L41 → K9 → **K16** (camera-free in `cam_b`) → K10 → K13 behind the seated
   operator: keycard from the cabinet, read the logbook. Out.
5. Server door from the S (C3 not in `cam_b`): keycard → K11 → cage code → hack 45 s (1–2
   interruptions) → 2 drive bags, each K10 → K16 → K9 → Stair A ×2 → roof → pad, timed against the
   reception ring and the L41 rover. No camera on that path in `cam_b`.
6. Escape at the heli (45 s after the required loot). Total ECM: 2. Cable ties: 0 (the cleaners'
   routes are read and avoided). The other layouts trade C7 for C3/C6 and keep a free line (table
   above), so this is the worst case.

## Loud
**There is no loud phase.** `alarm_raised` (any reason, events.md) → 5 s Mercer abort line →
`heist_ended(fail)`. During those 5 s guards switch to COMBAT and civilians panic; nothing spawns.
The camera "!" tone (7 s unstoppable countdown, S3.5) is therefore the point of no return. Mercer's camera line
(`camera_warning`, D-117 §6) is an EARLY warning: it plays while a camera's meter is filling on a crew member, before
the "!", so the crew can still break line of sight.

The contract nodes still exist so the map validates and a future "loud failure" variant is possible:
- **Police spawns (≥ 3 directions, out of LOS of loot and escapes):** P1 Stair A below the L40
  gate, P2 Stair B below the L40 gate, P3 roof (heli rappel, NW corner), P4 passenger lifts (K3).
- **ENTRY points:** both stair doors on L41/L42, the roof door, the riser-bay door, the lift doors
  (K3/M2), the terrace sliders. **RAPPEL:** roof NW. No sniper perches, no special spawns.

## Loot path
- **Required:** the laptop (`loot.ledger_laptop`, LIGHT) + 2 of the 3 drive bags
  (`loot.ledger_drives`, MEDIUM).
- **Server (K11) → escape:**
  - `esc_service` (E3, L40): K11 → K10 (7 m) → Stair B down one storey → S3 → S1 → service-lift car
    (≈ 24 m in all). The short one.
  - `esc_heli` (E1, pad): K11 → K10 → K16 W → K9 → Stair A up 2 storeys → head house → S strip →
    pad (≈ 60 m: 23 m on L41, ~18 m of stairs, 19 m on the roof; 8.0 m climb). Bags never need a
    ladder (see Requests).
  - `esc_line` (E2, E parapet): as heli, then the S strip E to the anchor (≈ 66 m + climb); the bag
    rides the `zipline` to Vantage House (secured at the far end).
- **Laptop / study → escape:** M4 → M3 (lasers) → M2 → M9 → Stair A (up to the roof, or down).
- **Throw spot: the gallery balustrade → reception (4.4 m drop).** Bags from L42 (study, boardroom,
  art hall) dropped into K3 save a trip through Stair A/B with `esc_service`. They land in C1's
  cone in `cam_a`, and the reception guard sits 2–6 m away: drop when he is on loop (b).
- **Optional:** the 3rd drive bag; `loot.ledger_books` (study safe, time lock); 2 `loot.painting`
  (art hall, behind the lasers); `loot.cash` (archive safe, saw); `small_loot` (study safe ×3,
  wine room ×2, partner desks ×2).
- **Secure zones:** `SECURE_LOOT` on the pad's cargo net (E1, present from the start), at the far
  end of the E2 zipline, and in the service-lift car (E3). Only the active `escape` slot's zone exists.
- **Bodies:** BODY_HIDE in S2 bins (2), both janitor closets (1 each) and behind the R3 AHU (2).

## Objectives
**Stealth** (objective_tag in brackets; ENV B reads these, D-039):
1. *(optional)* Case the roof / service level. Mercer intro and an Accountant line. `[casing]`
2. Find the ledger laptop and bag it. `[laptop]`
3. Get a keycard for the server room. `[keycard]` (skipped with `srv_contractor`)
4. Get into the server room. `[server_door]`
5. Open the cage: code `[cage_code]` (find the note) or saw (90 s). `[cage]`
6. Release the drive bays: `hack_terminal` 45 s, 1–2 interruptions (array resync; re-interact).
   `[hack]`
7. Bag the drives (`loot_spawn` × 3). `[drives]`
8. Secure the laptop and ≥ 2 drive bags at the escape. `[secure]`
9. *(optional)* Open the study safe: keycard swipe → time lock (`time_lock_s`) → bag the books.
   `[study_safe]`
10. *(optional)* Paintings `[paintings]`, archive safe (saw) `[archive_safe]`, small loot.
11. Escape. `[escape]`

**Mission script notes** (`shadow_ledger_mission.gd` on `HeistMission`): find prefabs by
objective_tag. STEALTH_ONLY is A's runtime rule (S11.3, A2-07); the mission only adds the Mercer
lines. `[keycard]` is skipped when `srv_contractor` is active (the reader's targets start open).
`[secure]` completes when the laptop **and** 2 drive bags are secured. Then: `esc_heli` → the heli
lands 45 s later and the ESCAPE zone activates; `esc_line`/`esc_service` → the ESCAPE zone activates
at once. Mercer lines: intro, laptop found, keycard, cage open, hack started / interrupted / done,
lasers, time lock started / open, last pager (4th), camera "!" warning, required loot secured,
escape, abort.

## Variable table
Each variable changes a decision. Rules resolve in this order (heist_map.md §5).

| variable | options (slot ids) | weights | gameplay effect (the decision it changes) |
|---|---|---|---|
| `late_partner` (`civilian_cluster`) | `moor_late`, `moor_gone` | 0.35, 0.65 | **Whether a civilian sits next to the laptop.** With Moor in, the laptop is on her desk: wait for her 40–70 s break or spend a cable tie (she has a desk phone; ECM jams it). |
| `laptop` (`loot_spot`) | `lap_kessler` (K1), `lap_moor` (K5), `lap_study` (M4), `lap_boardroom` (M14) | rule 1 `requires moor_late` → `lap_moor`; rule 2 `excludes moor_late`: 1, 1, 1, 0.75 | **Which floor and which barrier:** K1 is the gondola-west room; K5 is in C5's corridor; the study is behind the lasers (or the gondola-north door); the boardroom is on the L42 rover's loop (c). |
| `server_room` | `srv_locked`, `srv_contractor` | 0.6, 0.4 | **Keycard or civilian.** Locked: you need one of the 2 keycards. Contractor: the door is propped and the code is on his laptop (`code_contractor`), but a civilian works at the rack, so you wait for his coffee window or tie him. |
| `keycard` | `kc_reception` (K3 drawer), `kc_security` (K13 cabinet), `kc_it` (K12), `kc_kessler` (K1), `kc_lounge` (M1 bar), `kc_guest` (M5 nightstand), `kc_cleaner` (L42 J cart) | 1, 0.75, 1, 1, 1, 1, 0.75; **pick 2** | **2 cards, 2 readers (server door, study safe); readers consume them.** Where they are decides the first floor you work, and spending one on the optional safe can cost the server door. `kc_reception` and `kc_security` sit next to observers. |
| `code_note` | `code_it_board` (K12), `code_security_log` (K13), `code_moor_planner` (K5), `code_contractor` (K11 laptop; `requires srv_contractor`) | 1, 1, 1, 1.5; pick 1 | **The cage: code or saw.** Behind the operator, in Moor's office, on the IT whiteboard (gondola/K7 side), or on a working civilian. Without the code the saw is the fallback (noise next to the operator). |
| `guard_post` | `rover_l41`, `rover_l42` (reception is a fixed spawn) | 1, 1; pick 1 (Routine/Tense), 2 (Hazardous+) via `difficulty_add` | **Which floor has a walker.** L41 rover: K16 and the archive/break spurs. L42 rover: the art-hall pause and the boardroom/dining loop. |
| `guard_extra` | `stair_watch`, `roof_watch`, `extra_none` | Routine: none (pick 0); Tense/Hazardous: 1, 1, 2, pick 1; Brutal: 1, 1, 0, pick 1; Lethal+: 1, 1, 0, pick 2 | **Whether the stairs or the roof are walked.** Fire watch: the stairs become a timing puzzle (riser/gondola gain value). Roof watch: the spawn side and the gondola ladders are watched; the terrace is seen from the S parapet. |
| `security_room_staffed` | `sec_staffed`, `sec_empty` | 0.6, 0.4 | **Live cameras or not.** Staffed: kill/dominate him (a pager toward the cap) or live with cameras (ECM). Empty: K13 is free for the cabinet/logbook. |
| `camera` | `cam_a`, `cam_b`, `cam_c` (table in Sightlines) | 1, 1, 1 | **Which corridor and which entry need ECM or timing**, and which W↔E line is free on each floor. |
| `laser_pattern` (heist group, M3 grid) | `lz_static` (3 beams at 1.3/1.7/2.1 m: grid volume y 0.9–2.5, the prefab spreads beams evenly; crouch under, the 1.2 m crouched capsule clears 1.3), `lz_sweep` (3 vertical beams, period 6 s), `lz_timed` (4 beams, off 4 s of every 16 s) | Routine 0.5, 0.2, 0.3; Brutal+ 0.2, 0.4, 0.4 | **Crouch-walk at any time, time a sweep, or wait at the grid** (in C7's cone in `cam_b/c`). It decides whether the gondola-north door is worth it and how risky carrying the laptop/books/paintings back is. |
| `vent_open` | `vent_l42`, `vent_l41`, `vent_sealed` | 0.35, 0.35, 0.3 | **Whether the riser is an entry and where it lands:** L42 next to the gallery side, or L41 next to Stair A and K16 (the server side). |
| `gondola` (heist group) | `gon_west_l41`, `gon_north_l42`, `gon_stowed` | 0.3, 0.3, 0.4 | **A camera-free entry straight into a target room:** Kessler's office (keycard/laptop slots), or the study behind the lasers. |
| `escape` | `esc_heli` (E1 pad), `esc_line` (E2 E parapet), `esc_service` (E3 L40) | 0.4, 0.35, 0.25 | **The whole loot path:** 2 storeys up through Stair A (heli/line) or 1 storey down Stair B (service), which makes the gallery throw and the service spawn valuable. |
| `cleaners` (scalar) | 1, 2, 3 | Routine 0.5/0.5/0; Hazardous 0.2/0.6/0.2; Brutal+ 0/0.5/0.5 | **How many routes a civilian with a cart crosses:** a cleaner on L42 puts a civilian on M1/M2/M15, and the cart can hold `kc_cleaner`. |
| `time_lock_s` (scalar) | 90, 120 | Routine 0.7/0.3; Brutal+ 0.3/0.7 | **How long to hold the study:** shorter than one L42 rover loop (90) or longer (120), which decides whether to start it at all. |

## Rare events

| id | good/bad | chance | effect |
|---|---|---|---|
| `ledger_printout` | good | 6% | Kessler printed a working copy: +1 `loot.ledger_books` bag on the K1 desk. |
| `cage_left_open` | good | 3% (`requires srv_contractor`) | The contractor left the cage open: `[cage]` is skipped. |
| `kessler_sleepover` | bad | 5% | Kessler is in M5, awake and reading. The `alarm_button` is 1 m from his bed; `kc_guest` becomes a trap. |
| `timelock_extended` | bad | 10% (Brutal+, `min_difficulty`) | The study safe's time lock gets +60 s. |

## Escape
- **Heli (E1):** pad, SECURE_LOOT net from the start. The heli is called when the required loot is
  secured and lands 45 s later (ESCAPE zone on the pad). Getaway vehicles are ignored by NPCs (S4.2).
- **Line (E2):** E parapet anchor. Bags go down the `zipline` to Vantage House (secured at the far
  end). The ESCAPE zone at the anchor activates when the required loot is secured (the crew clip on).
- **Service lift (E3):** L40 car. SECURE_LOOT in the car; ESCAPE in the car + S1. Activates when the
  required loot is secured.
- **Walk-out:** none (the crew is on a tower top at 02:00).

## Pre-planning (preplanning.md contract)
`HeistDef.preplanning`: favors 6; `disable`: `asset.ammo_bag_drop`, `asset.doctor_bag_drop` (no loud).

| Point | Category | Params / asset |
|---|---|---|
| `pp_spawn_roof` | spawn | default (spawn_tag `""`), SW roof |
| `pp_spawn_service` | spawn | spawn_tag `preplan_spawn_service` (S1, unmasked) — `asset.alternate_entry` |
| `pp_drop_plant` | drop_zone | R3 behind the AHU — `asset.body_bag_case_drop` |
| `pp_drop_refuse` | drop_zone | S2 — `asset.body_bag_case_drop` |
| `pp_escape_heli` | escape | variant_group `escape`, slot `esc_heli` — `asset.escape_position` (vote) |
| `pp_escape_line` | escape | slot `esc_line` |
| `pp_escape_service` | escape | slot `esc_service` |
| `pp_gondola_west` | insider | variant_group `gondola`, slot `gon_west_l41` — new `asset.gondola_left_hung` |
| `pp_gondola_north` | insider | slot `gon_north_l42` — new `asset.gondola_left_hung` |
| `pp_riser_l41` | insider | variant_group `vent_open`, slot `vent_l41` — new `asset.riser_panel` |
| `pp_riser_l42` | insider | slot `vent_l42` — new `asset.riser_panel` |

Crew assets with no point: `asset.intel_cameras` (reveals `camera`), `asset.intel_guard_posts`,
`asset.intel_keycards`, new `asset.intel_laptop` (reveals `laptop`), `asset.spare_body_bags`,
`asset.extra_cable_ties`. Blueprint: `docs/levels/shadow_ledger/blueprint.png` from the plan renderer.

## Audio/lighting
- **Palette** (style guide §3): **graphite `#2E3136`** dominant (honed stone wall panels, carpet,
  steel trims, the BOH paint), **glass teal `#5D8C8F`** secondary (tinted glass partitions and
  balustrades, the lounge bar backlight, the logo wall), **cold white LED** accent (6500 K linear
  coves, stair-tread lights, the crown fins). Walnut desks and leather stay inside GSR saturation.
- **Time:** 02:10, no sun or moon. Overcast sky lit orange-teal from below by the city. Rain:
  streaks and sheeting on the curtain wall, puddles and splashes on the roof and terrace. Rain is
  **atmosphere only**: no rain scalar, because it would not change a decision.
- **Zones:**
  - executive spaces (K3, M1, M2, M4) in night mode: cold LED coves and logo wall, 3000 K table and
    picture lights in pools, the rest dark (readable shadows for stealth);
  - offices and corridors: 4000 K panels at 30% night level;
  - BOH (K10, K13, K14, J, M10–M12): 5000 K;
  - security room: dim, with the monitor glow;
  - server room: 6500 K plus blue-white rack LEDs;
  - art hall: red laser glow plus 3000 K picture lights;
  - stairs: 5000 K egress lighting with green exit signs;
  - roof: green helipad perimeter lights, red aircraft beacons (BMU and plant), LED crown fins.
  - Every light has a fixture.
- **GI:** VoxelGI per floor (L41/L42 separately; the void shares the L41 volume), ReflectionProbe
  per room, OccluderInstance3D for the core and the plant block.
- **Ambience:** `amb_shadow_ledger_interior` (low HVAC, rain on glass, curtain-wall wind pressure,
  server hum near K11), `amb_rooftop_rain` (heavy rain, gusts, distant traffic far below).
- **Music:** `shadow_ledger`: a stealth bed only (66 BPM, glassy pads, sub pulses, rain-noise
  texture, a ticking motif for the hack and the time lock) plus a **fail sting** on the abort. No
  assault stems are needed for a stealth-only heist.
- **LUT:** `lut_shadow_ledger`: cool, desaturated, teal mids, neutral whites.
- **G2 art pass (SL-1, as built):** every map-built prop carries a Calder catalog model over its unchanged layout
  collider (tools/blender/props/calder.py; `shadow_ledger_dressing.gd` PROP_ART / CHAIR_ART); every kit room is dressed by
  KitPlacer (`sl_dress.gd`, kits in `tools/blender/props/_kits_shadow.py`). Fixtures: executive rooms 3000 K brass downlights
  (pools) and 6500 K linear LEDs over the void, offices / corridors 4000 K panels at the night level, BOH 5000 K panels, the
  server room 6500 K, the security room dim blue, brass picture lights over the art-hall paintings; the stairs and the head
  house keep their map lights in catalog fixtures. 5 shadow-casting fixtures (K3, K8, M1, M2, M4). Lit office floors on
  Arden, Vantage and the south / east skyline (`sl_art.WINDOW_GRIDS`) close the views through the glazing. One soft fill per
  room (meta fill). WorldEnvironment: overcast sky with an orange-teal city glow on the horizon, rain haze (fog), SSAO,
  glow, `lut_shadow_ledger`; one dim directional (CityGlow), no sun or moon. 58 reflection probes, 125 occluders (slabs,
  solid walls), near-range (30 m) interior props for the draw-call budget.

## HeistDef (proposed data, `shadow_ledger_def.tres`)
`id shadow_ledger`, display "Shadow Ledger", contact `contact.accountant`, mode STEALTH_ONLY,
base_payout **$70,000** (D-120), loot `[loot.ledger_laptop,
loot.ledger_drives, loot.ledger_books, loot.painting, loot.cash]` (B to confirm ids),
escape_options `[heli, zipline, service_lift]`, music_track `shadow_ledger`.

**Walkthrough whitelist** (level_standards §6): the vertical pairs L40 spawn ↔ roof targets and
K11 ↔ roof exceed 3× the straight-line distance because Stair A is the only way to the roof. That is
by design (a tower).

## Deviations (G1, approved by the lead with QC-28)
- M7 purpose `dressing` instead of `corridor` (QC-30): the suite vestibule is a dressing room, so its door may swing into it.
- Other G1 deviations (stair doors lockpick both sides, head-house door on the landing, cage contents as siblings of the cage lock, E2 SECURE at the anchor, cleaners slot group, static grid beams 1.27 / 1.8 / 2.33 m with `crouch_under`, two riser ladders, axis-aligned camera mounts) are listed in the G1 report (QC-28).

## Requests (to the lead)
- **QC-15 (ENV B loot):** `loot.ledger_laptop` (LIGHT), `loot.ledger_drives` (MEDIUM),
  `loot.ledger_books` (MEDIUM), `loot.painting` (LIGHT, reusable by `gallery_night`) (weights follow the data, D-117).
- **QC-16 (ENV B assets):** `asset.intel_laptop` (reveals `laptop`), `asset.gondola_left_hung` and
  `asset.riser_panel` (force a slot from the chosen point's params).
- **QC-17 (ENV A):** confirm that carrying a bag on a `ladder` is blocked (the design assumes it is;
  if it isn't, the riser and gondola become loot paths and the escape table changes).
- **QC-18 (ENV A):** per-difficulty **slot** weights (`laser_pattern`, `guard_extra`); A2-08 lists
  per-difficulty scalar weights only. Night Deposit relies on the same thing.
- **QC-19 (ENV A):** `escape_zone.escape_type` values for `heli` (with a landing delay) and a
  line/zipline escape (crew walk into the zone; no player zipline needed).
