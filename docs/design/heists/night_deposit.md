# Nightfall Depository: Harbor Savings & Loan (night_deposit)

> D-117: display name "Nightfall Depository"; id `night_deposit` unchanged.
Status: APPROVED (lead, 2026-10-10) (D-040)

## Fiction
- **Who:** Harbor Savings & Loan, Pier District branch. A 1931 stone bank on the corner of Harbor
  Street and Wharf Lane, facing the working harbor. Guarding is contracted to Halden Security
  (Security Officers, plus a camera operator from P2).
- **What:** every Friday night the **Ortega Fisheries Co-op**, a cartel laundering front, drops its
  week of cash takings into the bank's **night depository chute**. The bags sit in the basement
  depository safe until the 06:00 armoured-car run. The Co-op's "special customers" also keep cash
  in the **vault cage**, and their safe-deposit boxes hold whatever the cash doesn't cover.
- **Why / contact:** **The Accountant** (bank and corporate jobs, never seen): *"The Co-op launders
  through Harbor S&L. Take the night drop and the cage. They can't report what they never declared."*
- **Time / weather:** 02:30, dry, harbor fog banks rolling over the quay. Sodium streetlights. The
  bank is closed: the building has only guards, a cleaner, and sometimes a night manager closing
  the books.
- **Handler:** Mercer on comms.

## Modes
- **Stealth + loud.** Size M (15–25 min stealth, 15–25 min loud). Phase P2. It uses the full P2
  stealth set: cameras and the camera operator, ECM, keycards, codes, the time-locked vault, a laser
  grid, saws on deposit boxes, and cuffs.
- **Stealth:** the bank is closed, so the **only PUBLIC spaces are the street, the quay, the staff
  parking lot/alley, and the 24-hour ATM vestibule**. Everything inside is RESTRICTED. Casing means
  reading the hall and the guard rhythm through the ATM vestibule's interior glass and the
  banking-hall windows.
- **The vault needs both** the **antechamber keycard** (the security gate in the basement) **and the
  time-lock code** (entered at the panel, which starts the time lock). Alternatively, **hack the
  time lock from the server room** (`server_room` variant). The time lock then runs for
  `time_lock_s` while the crew holds the basement quietly.
- **Loud:** the alarm triggers the vault's **relock and seismic lockdown**: the panel is dead and
  the round door stays shut. A **thermal drill** on the vault door (360 s, with jams) is the way in.
  The depository safe needs a **saw** (or the drill). The crew holds the basement, which has one stair
  plus the cash lift: a strong but trap-like position.
- **Difficulty notes:**
  - Routine: 2 guards + operator (staffed 60%).
  - Brutal: 3–4 guards + operator, sweeping lasers allowed, and the `armored_car_early` bad event
    enabled.
  - **On Brutal the guard count can exceed the pager cap (4)**, so a ghost run must avoid some
    guards (see Stealth routes). This is intended.

## Site
- **Lot:** 26 × 20 m (wall centre lines; outer face 26.4 × 20.4 m), corner lot. Ground FFL = 0.0 m;
  basement FFL = −4.0 m. Stepped massing: the banking hall roof sits at +6.5 m (parapet +7.3) and the
  back wing/east offices roof at +3.6 m (parapet +4.4). Plant is on the back-wing roof.
- **Streets:**
  - **Harbor Street** runs south: 2 lanes plus parking, 8 m carriageway, 2 m sidewalk.
  - Beyond it is the **quay**: bollards, quay steps down to the water, and the moored escape boat (E2).
  - **Wharf Lane** runs east: 2 lanes, 7 m. North of the building is the **staff parking lot**,
    with the armoured-car bay at the loading door and the basement areaway grate. A 5 m service alley
    runs behind it.
- **Neighbours:**
  - West: *Pell & Sons Ship Chandlery* (closed, party wall, no openings).
  - North across the alley: warehouse backs behind chain-link.
  - East across Wharf Lane: a crane/container yard behind a fence. Its 2-storey crane office is a P3
    sniper perch.
  - South across the water: far-shore lights in the fog.
- **Exterior landmarks:**
  1. the **brass harbor clock** over the bronze entrance doors (lit);
  2. the **mosaic compass rose** in the banking-hall floor, seen through the tall windows and the ATM glass;
  3. the **green-glass ATM vestibule** on the corner, lit 24 h.
- **Play space:** x −14…+40, z −16…+36. The edges are closed by facades, fences, the gated alley
  (west), the crane yard fence (east), and the water (south). See the closure table below.

### Play-space closure (validated by `bounds`)

| Edge | Closure |
|---|---|
| Alley, west end (x −14) | Chained steel gate between the chandlery back wall and the warehouse fence. The P4 police spawn is behind it. |
| Alley / parking lot north (z −16) | Warehouse backs: 2-storey brick, loading docks, chain-link with barbed top (2.4 m). |
| Wharf Lane, north end (z −16) | Lane continues as a vista to a T-junction facade at z −30. A container-truck trailer is parked across it at z −14 (P3 spawn behind it). |
| Wharf Lane / crane yard (x 37+) | 2.4 m palisade fence with a closed gate; stacked containers, two gantry cranes as silhouette. |
| Harbor Street, west end (x −14) | Street continues as a vista: facades to x −45, then a bend (facade across the view axis). Road barriers and a parked utility van block at x −14 (P1 spawn beyond). |
| Harbor Street, east end (x +40) | Past the Wharf Lane T-junction: facades to x +60, then a drawbridge with its gates down (P2 spawn behind the barrier). |
| South (quay, z 32–36) | Quay edge with bollards and a 1.0 m chain railing except at the steps. **The water is a hard boundary:** falling in = an out-of-bounds kill volume that respawns the player at the quay steps (in stealth it is a non-alarm event). Fog limits view at ~120 m, and far-shore lights sit at 300 m. |
| Up | Night sky with a procedural fog layer. Every visible roof has a parapet and plant. |

## Floor plans
1 char = 0.5 m. Each character is a **grid point** (x = 0.5·col). Lines are **wall centre lines**:
exterior 0.4 m, interior 0.2 m, **vault walls 0.6 m reinforced** (`%`). Origin is the NW corner; +x
is east and +z is south (the parking lot is at the top, Harbor St at the bottom). Rulers are in metres.

Legend: `#` exterior wall, `|`/`-` interior wall, `%` vault wall, `D` door, `R` roller door
(sally port, 3.0 m), `W` window, `=` teller counter (1.05 m transaction ledge with 1.2 m bandit
glass above), `r` 1.05 m railing over the stair shaft, `v ^` U-stair (v = flight going down from
ground, ^ = return flight arriving in the basement), `G` guard post, `K` keycard candidate slot,
`L` loot, `S` safe, `TL` time-lock panel, `:::laser:::` laser grid, `H^` areaway ladder hatch,
`SRV` server rack, `#mon` camera station console against a solid wall, `o` operator seat (faces
the monitors), `(@)` mosaic compass rose (landmark), `$ $` ATMs, `v` (in G13) night depository
chute, `lift` cash lift (bags only).

**Vertical data** (`HeistMap.floor_heights = [-4.0, 0.0]`):

| Level | FFL | Ceiling | Floor-to-floor / slab | Notes |
|---|---|---|---|---|
| Basement | −4.0 | 3.2 (vault 3.0) | 4.0 (0.8 slab: heavy vault slab) | storage/plant ✓; per-room ceiling overrides below |
| Ground | 0.0 | **5.5 banking hall** (coffered); 3.0 back wing, offices, teller workroom (the workroom opens to the hall over the counter, with a 3.0 m soffit at z 10) | hall roof +6.5, wing roof +3.6 | banking hall 3.5–6 ✓; office 2.6–3.0 ✓ |
| Stair G2 | −4.0 → 0.0 | U-stair, 2 flights × 11 risers @ 0.1818 m, tread 0.28 m, width 1.2 m, half landing at −2.0 (z 0.2–1.4, full core width), flights side by side | 22 risers = 4.0 exactly ✓ | landing every 11 ≤ 16 ✓; headroom: the ground slab stops over flight 2 (railing `r`), so there is ≥ 2.1 m everywhere |

**Per-room ceiling overrides (D-048):** the generic §2.6 table caps storage/corridor/locker/server
rooms at 3.0 m. These basement rooms carry a `ceiling_range` override of 2.6–3.2 m, for this reason:
- **B1, B6, B14** (storage), **B5, B7, B10** (corridors), **B2/B13** (locker room + WCs), **B4**
  (server room), **B11** (count room), **B12** (depository): a 1931 bank basement built to vault
  standard. It has a uniform 3.2 m clear height under the 0.8 m vault-grade slab, with exposed services
  and no dropped ceiling.
- **B3 (plant):** the validator's confirmed `plant` range of 2.6–6.0 m applies, so no override is needed.

**Keycard (D-048):** one consumable vault keycard opens the B5→B8 vault gate. Every other staff door
(sally personnel door, teller workroom, count room) is a LOCKPICK door that guards and staff open by
badge (NPC-authorised). That is PD2-faithful.

**Validator note:** `contract_nodes` currently requires `floor_heights[0] == 0.0`. That is my
validator, and I will change it to "ascending and contains 0.0" (heist_map.md §7 only fixes the
ground floor at 0.0) before G1.

### Site plan
1 char = 1 m, x = −14 at the left edge, +z is south. `%` neighbour/dressing blocks, `v` van (E1, in
the parking lot by the sally port), `b` boat (E2, at the quay steps), `P` player casing spawns,
`P1…P4` police spawn directions, `[BH]` dumpster (body_container, BODY_HIDE), `=grate` basement
areaway grate + ladder (into B3 plant).

```
   x      -10       0         10        20        30        4
 -16  %% WAREHOUSE BACKS + chain-link (dressing)
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    CRANE YD
 -14                                                     %%%%
        ALLEY (5 m) W->E                                 %%%%
 -12  X gate P4                                   P3     %%%%
      X                                                  %%%%
 -10  _________________________________________: |      |%%%%
                                               : |      |%%%%
  -8                                           : |      |%%%%
                  STAFF PARKING LOT            : |      |%%%%
  -6                                      cars : |      |%%%%
                    vvvv                       : |      |%%%%
  -4                vvvvE1 van                 : |      |%%%%
                    vvvv                       : |      |%%%%
  -2                      [BH]       =grate    : |      |%%%%
                                               : |      |%%%%
   0  %%%%%%%%%%%%%%###########################: |      |%%%%
      %%%%%%%%%%%%%%#                         #: |      |%%%%
   2  %%%%%%%%%%%%%%#                         #: |      |%%%%
      %%%%%%%%%%%%%%#  back wing roof +3.6    #: |      |%%%%
   4  %%%%%%%%%%%%%%#                         #: |WHARF |%%%%
      %%%%%%%%%%%%%%#                         #: |LANE  |%%%%
   6  %%%%%%%%%%%%%%#  HARBOR SAVINGS & LOAN  #: |      |%%%%
      %%%%%%%%%%%%%%#                         #: |      |%%%%
   8  %%%%%%%%%%%%%%#    (1 storey + basement)#: |      |%%%%
      %% PELL & SONS                          #: |      |%%%%
  10  %% CHANDLERY  #                         #: |      |%%%%
      %%%%%%%%%%%%%%#                         #: |      |%%%%
  12  %%%%%%%%%%%%%%#                         #: |P2->  |%%%%
      %%%%%%%%%%%%%%#  banking hall roof +6.5 #: |      |%%%%
  14  %%%%%%%%%%%%%%#                         #: |      |%%%%
      %%%%%%%%%%%%%%#                         #: |      |%%%%
  16  %%%%%%%%%%%%%%#                         #: |      |%%%%
      %%%%%%%%%%%%%%#                         #: |      |%%%%
  18  %%%%%%%%%%%%%%#                         #: |      |%%%%
      %%%%%%%%%%%%%%#                         #: |      |%%%%
  20  %%%%%%%%%%%%%%###########################: |      |%%%%
      _______________________________________________________
  22    SIDEWALK  P P P P
      _______________________________________________________
  24  
      
  26  
        HARBOR STREET (2 lanes + parking)
  28  
       <-P1
  30  
      _______________________________________________________
  32    QUAY  [bollards]  steps
      
  34  ~~~~~~~~~~~~~~~~~~~~bbbbbbE2 boat
      ~~~~~~~~~~~~~~~~~~~~bbbbbb~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  36  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      ~~~~ HARBOR WATER (fog; moored boats, far shore lights)
  38  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  40  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

### Ground floor (FFL 0.0)
```
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6
  0.0 ####RRRRRRR#D########################################
      #G1      lift |G2   |G3     |G4     |G5   |G6       #
  1.0 #             |     |       |       |     |         #
      #             |v  ^ |       |       |     |         #
  2.0 #   L         |     | #mon  | K     |     |         #
      #             |     |       |       |     |         #
  3.0 #             |v  ^ | o     |       |     |         #
      #             |     |       |       |     |         #
  4.0 #             |     |       |       |     |         #
      #             |v  ^ |     K |       |     |         #
  5.0 #             |     |       |       |     |         #
      #             |     |       |       |     |         #
  6.0 #-----------D--  rrrr---D-------D------D-------D----#
      #G7 STAFF CORRIDOR                                  D
  7.0 #                                                   D
      #---D-------------------------------------|----D----#
  8.0 #G8 TELLER WORKROOM                       |G11 LOAN #
      # K                                       |         #
  9.0 #                                         |         W
      #                                         |         W
 10.0 #-D-===================================---|         W
      #G9 BANKING HALL                          D         W
 11.0 #                                         |         W
      #                                         |         #
 12.0 #       G                                 |---------#
      #                                         |G12      #
 13.0 #                   (@)                   | K       W
      #                                         |         W
 14.0 #                                         D         W
      #                                         |         W
 15.0 #                                         |         W
      #                                         |         #
 16.0 #                                         |---------#
      #                                         |G13      #
 17.0 #                                 G       |         #
      #                                         |         #
 18.0 #                |--DDD--|                D         #
      #                |G10    |                |  $ $ v  #
 19.0 #                |       |                |         #
      #                |       |                |         #
 20.0 ##WWWWWWWWWWWWWW####DDD####WWWWWWWWWWWWWW###WWW#DDWW#
```

### Basement (FFL −4.0)
```
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6
  0.0 #####################################################
      #B1 XFER lift |G2   |B2    |B13 |B3 PLANT |B4 SERVER#
  1.0 #             |     |      |    |         |         #
      #             |v  ^ |      |    |         |         #
  2.0 #             |     |      |    |         |         #
      #             |v  ^ |      |--D-|         |         #
  3.0 #             |     |           | H^      |   SRV   #
      #             |--|  |           |         |         #
  4.0 #             |B14  |           |         |         #
      #             |  |  |           |         |         #
  5.0 #             |  |  |           |         |         #
      #             |  |  |           |         |         #
  6.0 #------D------|-D|  ----D------------D---------D----#
      #B5 CORRIDOR                G                       #
  7.0 #                                                   #
      #------D------|-D-|-------DDDDD-------|-D-|----D----#
  8.0 #B6 RECORDS   |B7 |B8 ANTECHAMBER     |B10|B11      #
      #             |   | :::::laser::::TL  |   |         #
  9.0 #             |   |                   |   |         #
      #             |   |                   |   |         #
 10.0 #             |   %%%%%%%%%DDD%%%%%%%%%   |         #
      #             |   %B9 VAULT           %   |         #
 11.0 #             |   %                   %   |         #
      #             |   %                   %   |         #
 12.0 #             |   %|box            box|   |         #
      #             |   %                   %   |         #
 13.0 #             |   %                   %   |         #
      #             |   %                   %   |         #
 14.0 #             |   %                   %   |----D----#
      #             |   %                   %   |B12      #
 15.0 #     K       |   %       [cage]      %   |         #
      #             |   %                   %   |         #
 16.0 #             |   %                   %   |         #
      #             |   %                   %   |         #
 17.0 #             |   %                   %   | S L     #
      #             |   %     L L L         %   |         #
 18.0 #             |   %                   %   |         #
      #             |   %                   %   |         #
 19.0 #             |   %                   %   |         #
      #             |   %                   %   |         #
 20.0 ##################%%%%%%%%%%%%%%%%%%%%%##############
```

Roof: banking-hall skylight laylight (P3 police `RAPPEL`, glass, breakable), back-wing plant
(condensers), reached only by a service ladder from the lot; not playable in P2.

## Room list
Sizes are between wall centre lines.

| id | purpose (`RoomVolume.purpose`) | size m | ceiling m | kit | notes |
|---|---|---|---|---|---|
| G1 | storage (loading / sally port) | 7 × 6 | 3.0 | `sally_port` | Armoured-car transfer room. Roller door (3 m) and steel personnel door (**lockpick**; staff badge readers are NPC-authorised only, D-048) to the lot. **Cash lift** (bags only) to B1 in the NE corner of the plan drawing. Cart, cash trolleys, CCTV-covered. |
| G2 | stair | 3 × 6 | open | — | U-stair to the basement (vertical data). Ground entry is from G7 at x 7–8; the shaft over flight 2 has a railing. |
| G3 | security_room | 4 × 6 | 3.0 | `security_office` | **Camera station** against the solid west wall (G2 partition); the operator faces west. Monitor wall, key cabinet on the east wall (`kc_security`), guard lockers, coffee. No windows (internal). |
| G4 | break_room | 4 × 6 | 3.0 | `break_room` | Fridge, counter with sink, microwave, coffee, table with 4 chairs, **staff lockers** (`kc_break_locker`), bulletin board (`code_break_board`). |
| G5 | electrical | 3 × 6 | 3.0 | `electrical_closet` | Main switchboard, alarm control panel (dressing in P2), telecom. |
| G6 | storage | 5 × 6 | 3.0 | `storage_supplies` | Bank supplies, coin bags, deposit slips, shredder, archive overflow. `srv_ground` variant puts a server rack here. |
| G7 | corridor (staff) | 26 × 1.5 | 3.0 | `corridor_service` | The back-of-house spine. **Fire exit** east to Wharf Lane (push bar, swings out). The stair entry is at x 7–8. |
| G8 | office (teller workroom) | 21 × 2.5 | 3.0 soffit, opens over the counter to the hall | `teller_line` | 6 teller stations behind the counter, cash drawers (`kc_teller_drawer`), note counters. Door to G7 (**lockpick**, NPC-authorised); gate to the hall at x 1 (locked). |
| G9 | banking_hall | 21 × 10 | 5.5 | `banking_hall` | Public by day, **RESTRICTED at night**. Mosaic compass rose (landmark), 4 check-writing tables, queue rails, waiting benches, the harbor clock inside over the doors, tall windows (sill 1.0, 3.5 tall) to Harbor St. Glass-fronted offices G11/G12 on the east side. |
| G10 | corridor (entry vestibule) | 4 × 2 | 3.0 | — | Bronze outer doors and glass inner doors, both locked at night. |
| G11 | office (loan officer) | 5 × 4.5 | 3.0 | `office_loan` | Desk, 2 visitor chairs, file cabinets. Glass front to the hall. Staff door to G7. Window to Wharf Lane. |
| G12 | office (branch manager) | 5 × 4 | 3.0 | `office_manager` | Desk (`kc_manager_desk`, `code_manager_planner`), credenza, small office safe (P2 `safe` SMALL, lockpick skill/drill: `xl_manager_safe`). Glass front to the hall; window to Wharf Lane. |
| G13 | lobby (ATM vestibule, 24 h) | 5 × 4 | 3.0 | `atm_vestibule` | **PUBLIC.** 2 ATMs, night depository chute (drops to B12), card-reader street door (always open at night: card-swipe dressing). Interior glass door to the hall (**lockpick**, in view of C1). |
| B1 | storage (cash transfer) | 7 × 6 | 3.2 | `cash_transfer` | Cash lift landing, cash cages on wheels, sealed-bag shelving. Door to B5. |
| B2 | locker_room (staff, with WCs) | 6 × 6 | 3.2 | `locker_room` | Staff lockers, bench, **2 WC cubicles** (B13), sink row. The only restrooms; one set serves ≤ 50 staff (level_standards §2.2), and the branch has 12. |
| B3 | plant | 5 × 6 | 3.2 | `plant_room` | Boiler, AHU, UPS, water tank. **Areaway ladder hatch** (`H^`) up to the lot grate (`vent_open` variant). |
| B4 | server_room | 5 × 6 | 3.2 | `server_room` | Racks, cooling, console. `srv_basement` variant: the time-lock hack can be done here. |
| B5 | corridor | 26 × 1.5 | 3.2 | `corridor_service` | Basement spine. The vault gate (keycard, 2.0 m wide steel grille) at x 13–15 leads into B8. |
| B6 | storage (records) | 7 × 12.5 | 3.2 | `storage_archive` | Compact shelving, archive boxes, microfiche reader. `code_records_ledger` slot. |
| B7, B10 | corridor (vault inspection passages) | 2 × 12.5 each | 3.2 | `corridor_inspection` | Standard vault-perimeter inspection passages with convex mirrors. They flank the vault and connect B5 to nothing else (dead ends **with a reason**). Each holds a **laser grid** (`laser_inspection` variant) and is a guard pause point. |
| B8 | vault (antechamber) | 10 × 2.5 | 3.2 | `vault_antechamber` | **Laser grid** across the room (pattern variant). **Time-lock panel `TL`** on the east wall by the round vault door. Viewing bench. |
| B9 | vault | 10 × 10 | 3.0 | `vault_main` | Round door (2.2 m, VAULT lock). **Cash cage** in the centre (`loot_spawn` cash bags). **Safe-deposit box walls** east and west (`saw` targets: small loot, `deposit_boxes` count variant). Pallet of **Co-op cash bricks** (bags). |
| B11 | office (cash counting room) | 5 × 6.5 | 3.2 | `count_room` | Counting machines, tables, sealing station. Door to B5 (**lockpick**, NPC-authorised). |
| B12 | vault (night depository) | 5 × 6 | 3.2 | `depository` | The chute from G13 lands in the **depository safe** (`safe` MEDIUM, `S`). Night-drop bags inside (loot). The door is from B11 only (through-room by design: deposits go to counting). |
| B14 | storage (janitor) | 1.5 × 2.5 | ≤ 3.2 (under flight 1) | `janitor_closet` | Mop sink, cart. **BODY_HIDE** (1 body). |
| X1 | exterior (lot + alley) | — | — | `exterior_lot` | Parked staff cars, dumpster (`body_container`, BODY_HIDE), the armoured-car bay markings, areaway grate, light poles (sodium). |
| X2 | exterior (street + quay) | — | — | `exterior_harbor` | Sodium street lights, bollards, benches, quay railings, moored boats, fog. |

Support-space check (level_standards §2.2):
- restrooms (B2/B13, one set for ≤ 50 staff) ✓
- break room G4 ✓
- janitor B14 ✓
- electrical G5 ✓ and IT B4 ✓
- back entrance G1 ✓
- 1 stair core for 2 floors ✓
- fire exit G7 → Wharf Lane ✓; the basement's second egress is the B3 areaway ladder, a plausible
  plant egress

## Circulation
- **Public (night):** street ↔ ATM vestibule G13; street ↔ quay; alley ↔ staff lot. Nothing inside
  is public.
- **Staff:** lot → G1 personnel door (keycard) → G7 → G3/G4/G5/G6/G11 → G8 (keycard) → G9 hall.
  Down: G7 → G2 stair → B5 → B1/B2/B3/B4/B6/B11 → vault gate → B8 → B9.
- **Guards (one `bank` PatrolGraph across both floors, linked through stair points; plus an `exterior` graph):**
  - **Ground loops** through G7 mid:
    - (a) G7 → G8 → G9 hall circuit (compass → windows → vestibule → offices) → G8 → G7;
    - (b) G7 → G1 → G7 → G6;
    - (c) G7 → stair → B5 → B6 → B5 → stair → G7.
  - **Basement loops** through B5 mid:
    - (a) B5 → B8 (outside the lasers) → B5;
    - (b) B5 → B7 → B5 → B10 → B5;
    - (c) B5 → B11 → B12 → B11 → B5 → B1.
  - That gives ≥ 3 loops per post on the shared graph.
  - **Exterior:** lot loop (sally door ↔ cars ↔ grate ↔ alley mouth) for the `rover_exterior` post
    (pause_anim `smoke`).
- **Civilians:** the cleaner works a route (`staff_cleaner` points: G9 hall → G7 → G4 → B2 → B5).
  The night manager sits at G12, walks to G8, then to the B11 count room, and takes coffee in G4.

### Civilian and guard roster (spawn data)

| NPC | Count | Presence | Spawn tags | Idle activity | PatrolPoint tags |
|---|---|---|---|---|---|
| Security Officer (hall) | 1 | always | `guard_hall` | — | `guard` |
| Security Officer (basement) | 1 | always | `guard_basement` | — | `guard` |
| Security Officer (rover) | 0–2 | `guard_post` rovers: `rover_ground`, `rover_basement`, `rover_exterior` | `guard_rover` | — | `guard` |
| Camera operator (P2) | 0–1 | `security_room_staffed` | CAMERA_OPERATOR in G3 | `desk_work` | — |
| Cleaner | 0–1 | `cleaner` | `civ_cleaner` | `browse` (mopping) | `staff`, `staff_cleaner` |
| Night manager | 0–1 | `night_manager` | `civ_manager` | `desk_work` | `staff`, `staff_manager` |

**Totals:**

| Difficulty | Guards | Operator | Pagers (all) | Civilians | Cable ties |
|---|---|---|---|---|---|
| Routine | 2–3 | 60% | ≤ 4 | 0–2 | 2 per player is enough |
| Brutal | 3–4 | 75% | ≤ 5 | 0–2 | — |

On Brutal, pager use can exceed the cap of 4, so at least one guard must be avoided, not killed:
the exterior rover is the natural candidate. That is the intended Brutal skill check.

## Sightlines
- **Hall guard post** (G9, by the compass, facing E): covers the hall, the ATM glass door, the
  G11/G12 glass fronts and the teller counter. The **G8 workroom behind the counter is below his
  sightline** while he is seated (crouched players behind the counter are hidden from him; cameras
  are not fooled).
- **ATM vestibule → hall:** casing view. The interior glass door is lockpickable but sits in camera
  C1's cone and the hall guard's view: the front route needs ECM or a camera loop plus guard timing.
- **G7 staff corridor:** 26 m straight. Same crux as Glasshouse but with more doors. Cover: door
  recesses, the stair entry, the G1 doorway.
- **Basement B5:** 26 m, with the vault gate in the middle. The basement guard pauses at the gate
  facing B8 (lasers glow faint red). The inspection passages B7/B10 are blind from B5 except down
  their own axis.
- **Exterior rover:** the lot loop covers the sally door and the areaway grate. The grate is in his
  view for ~40% of his loop, so the timing window is readable.
- **Cameras (P2 `camera` variant, mounted at 2.6–3.0 m):**
  - C1: G9 NE → ATM door + offices.
  - C2: G9 SW → counter + gate.
  - C3: G7 W end → corridor.
  - C4: G1 → sally door + lift.
  - C5: B5 E end → corridor + vault gate.
  - C6: B8 → vault door + panel.
  - C7: lot pole → parking lot.
  - C8: B11 → count room.

## Stealth routes
1. **Lot / sally port (staff entrance):** case the lot (PUBLIC; the alley gate is closed). Deal with
   the exterior rover (avoid or pager), then lockpick or keycard the G1 personnel door (C4 covers it:
   loop, ECM, or the operator). Then G7 → stair → basement. The keycard and code are upstairs or
   downstairs depending on the roll.
2. **Areaway / plant (vent route):** when `vent_open`, lift the areaway grate (silent, 3 s) in the
   lot → ladder down → B3 plant → B5. It skips the whole ground floor and its cameras, but you still
   need the keycard and code, which may be upstairs (`kc_*` / `code_*` on G). When the vent is shut,
   the grate is padlocked (lockpick 8 s in the rover's loop).
3. **Front (ATM vestibule):** case through the glass (PUBLIC). Pick the interior glass door under
   ECM or with C1 looped while the hall guard faces west on his loop → G9 → teller gate (lockpick) →
   G8 → G7. This is the fastest route to G11/G12 (manager keycard/code).

**Time-lock hold:** after the code is entered (or the server hack **finishes**), the vault opens after
`time_lock_s`. The crew must keep the basement quiet that long: patrols keep coming to B5/B8. This
is the **heist's tension beat**.

**Lasers:** the antechamber grid blocks the panel and the vault door.
- **static:** a discoverable **bypass gap** at the west end of the grid, ≥ 0.8 m clear width, passable upright or crouched (capsule radius 0.35 m, crouched height 1.2 m; validator-asserted, D-048).
- **sweeping:** a timing window.
- **timed-off:** the grid drops for 6 s every 20 s.

ECM does not affect lasers (S9.10). The inspection passages' grids only matter for the B7/B10
shortcut to the vault's rear deposit wall. That is **loud only** (C4 breach, P3); in stealth they
are just guard pause points.

## Loud
- **Chokepoints:** the bronze entrance (glass inner doors), the hall windows (breachable bays ×3),
  the ATM vestibule, the sally roller door (breach), the G7 fire exit, the hall skylight (P3 rappel)
  and the areaway grate.
- **Holdout:** the **basement**. One stair and the cash lift: easy to hold, but every bag has to go
  up that stair or the lift. The ground G7 corridor is the counter-push lane. The hall is exposed to
  the windows.
- **Police entry (`TacticalPoint ENTRY`):** entrance doors, hall window bays ×3, ATM door, sally
  roller door, fire exit, skylight (`RAPPEL`, P3), areaway grate (FLANK).
- **Police spawns (≥ 3 directions, out of LOS of loot and escape):**
  - P1: Harbor St west, behind the barriers.
  - P2: Harbor St east, by the drawbridge.
  - P3: Wharf Lane north, behind the trailer.
  - P4: alley west, behind the gate.
- **Sniper perches (P3):** the crane-yard office roof (covers the lot and the sally door), and a
  moored trawler's wheelhouse on the quay (covers the hall windows and the E2 boat).
- **Special spawns (P3):** Phantom via the areaway, Bulwark through the entrance, Wrecker via the
  sally roller door.

## Loot path
- **Vault (B9) → van (E1, lot):**
  - *Lift:* B9 → B8 → B5 → B1 → **cash lift** (bags only, 2 per cycle, 8 s) → G1 → sally door → van
    (6 m).
  - *Stair:* B5 → G2 stair → G7 → G1 → van.
  - Throw spot: the G1 personnel door to the van.
- **Vault → boat (E2, quay):** up the stair → G7 → G9 hall → main doors (or a breached window) →
  across Harbor St (8 m) → quay steps. A long, exposed crossing; in loud it faces P1/P2 lanes.
- **Depository safe (B12) → B11 → B5 → lift.**
- **Small loot:** safe-deposit boxes (saw, 6 s each, noise 15 m: stealth risk), teller drawers in G8,
  the manager safe (`xl_manager_safe`).
- **Secure zone:** `SECURE_LOOT` at the active escape (van rear doors / boat deck).
- **Cash lift:** needs a prefab. QC-11 asks ENV A for a `bag_lift` (vertical zipline semantics).
  Until it exists, the lift is dressing and bags go up the stair.

## Objectives
**Stealth** (objective_tag in brackets):
1. *(optional)* Case the bank: Mercer intro and an Accountant line. `[casing]`
2. Find the vault keycard. `[keycard]`
3. Find the time-lock code `[code]`, **or** reach the server room to hack the lock `[server]`
   (hack: 3 interactions of 20 s with 2 random interruptions (server reboots), `server_room` variant).
4. Get through the vault gate (keycard) and the antechamber lasers. `[vault_gate]`
5. Start the time lock: enter the code at `TL` (5 s), or finish the hack. `[time_lock]`
6. Hold until the time lock releases (`time_lock_s`). `[time_lock_wait]`
7. Bag the cage and the Co-op pallet (`loot_spawn` cash, 6–8 bags). `[vault_loot]`
8. *(optional)* Saw the depository safe (B12) for the night-drop bags (3–5) `[depository]`; saw
   deposit boxes for small loot.
9. Secure ≥ 4 bags at the escape. `[secure]`
10. Escape. `[escape]`

**Loud** (on `alarm_raised`):
1. Mercer: "They've sealed the vault. Thermal drill, now." The mission disables `TL`. If the vault
   is already open, skip to 3.
2. Place the thermal drill on the vault door (360 s, jams per S9.3). `[vault_drill]`
3. Bag and secure ≥ 4 bags. The cash lift helps. `[secure]`
4. Optional: depository safe (saw, 120 s, or the drill).
5. Hold until the escape arrives:
   - van: at the second assault's FADE or after 300 s, whichever is later;
   - boat: same rule, but the rare `fog_lifts` event delays it by 60 s.
6. Escape.

**Mission script notes:** find prefabs by objective_tag. `alarm_raised` → set the vault lockdown
(the TL panel and server-hack interactions are disabled) and open the police gates. `device_finished`
on the vault drill → open the vault door. The time-lock timer is an objective timer
(`time_lock_s`). Server hack interruptions use `GameRng &"devices"`. Mercer lines: intro, keycard,
code found, lasers, time lock started / 30 s left / open, drill jam, 4th pager, escape ETA.

## Variable table
Each variable changes a decision.

| variable | options (slot ids) | weights | gameplay effect (the decision it changes) |
|---|---|---|---|
| `keycard` | `kc_manager_desk` (G12), `kc_teller_drawer` (G8), `kc_break_locker` (G4), `kc_security` (G3 key cabinet), `kc_records` (B6) | 1, 1, 1, 0.75, 1; pick 1 | **Floor and room you must reach first.** Security room means dealing with the operator. Records is downstairs, so the vent route alone suffices. |
| `code_note` | `code_manager_planner` (G12), `code_break_board` (G4), `code_records_ledger` (B6), `code_on_manager` (the night manager carries it; requires `night_manager`) | 1, 1, 1, 1.5; pick 1 | **Route, or whether you must intimidate the manager** (cable tie + shout window) to read it. `code_on_manager` excludes the others' notes. |
| `server_room` | `srv_basement` (B4), `srv_ground` (G6 storage rack) | 0.6, 0.4 | **The code-free alternative:** hacking avoids the code hunt but costs 60 s plus interruptions and puts a crew member far from the vault (ground variant). |
| `time_lock_s` (scalar) | 60, 90, 120 | Routine 0.4/0.4/0.2; Brutal 0.1/0.4/0.5 | **How long to hold the basement**, which decides whether to clear or pager the basement guard before starting it. |
| `guard_post` | `rover_ground`, `rover_basement`, `rover_exterior`, plus the empty `rover_none` (the 2 base posts are fixed spawns; `rover_none` encodes the rover-count weights, since the resolver rolls counts uniformly: Routine pick 1 with `rover_none` 9/7 against 1 each, so P(no rover) = 0.3; Brutal+ pick 2 with `rover_none` 1, so 1 or 2 rovers at 50/50) | pick 0–1 Routine (0.3/0.7), 1–2 Brutal; `difficulty_add` | **Which route is covered:** exterior locks down the lot/vent, basement makes the time-lock hold harder, ground covers the front. |
| `camera` | `cam_a` (C1, C3, C5, C6), `cam_b` (C2, C4, C5, C7), `cam_c` (C1, C4, C6, C8) | 1, 1, 1 | **Which entry needs a loop/ECM:** C4 covers the sally door, C7 the lot and grate, C1 the ATM door. |
| `security_room_staffed` | `sec_staffed`, `sec_empty` | Routine 0.6/0.4; Brutal 0.75/0.25 | **Kill/dominate the operator** (a pager, which counts toward Brutal's cap) **or live with cameras**. |
| `vent_open` | `vent_open` (grate unlocked), `vent_locked` (padlock: lockpick 8 s) | 0.5, 0.5 | **The cost of the areaway route.** |
| `laser_pattern` (antechamber) | `laser_static`, `laser_sweep`, `laser_timed` | Routine 0.5/0.2/0.3; Brutal 0.2/0.4/0.4 | **Crawl gap, timing, or waiting window** at the panel and vault door; affects how long players stand in C6's cone. |
| `night_manager` (`civilian_cluster`) | `mgr_in` (G12/B11 route), `mgr_out` | 0.5, 0.5 | **An extra civilian** walking G12 → G8 → B11, possibly carrying the code. |
| `cleaner` (`civilian_cluster`) | `cleaner_ground`, `cleaner_basement`, `cleaner_none` | 0.4, 0.3, 0.3 | **A wandering civilian on the route you picked**, with a cart that blocks doorways (cover). |
| `escape` | `esc_van_lot` (E1), `esc_boat_quay` (E2) | 0.6, 0.4 | **Loot path:** the cash lift and sally door, or across the street. Decides whether the front route matters in loud. |
| `depository_bags` (scalar) | 3, 4, 5 | 0.4, 0.4, 0.2 | **Whether the optional depository saw is worth the noise and time.** |
| `deposit_boxes` (scalar) | 4, 6, 8 sawable boxes | uniform | **Small-loot greed** against saw noise next to the vault (15 m). |
| `xl_manager_safe` (`extra_loot`) | `mgr_safe_full` (cash small loot ×4), `mgr_safe_empty` | 0.5, 0.5 | **Time on the ground floor**, near the hall guard, versus the vault. |

## Rare events

| id | good/bad | chance | effect |
|---|---|---|---|
| `time_lock_glitch` | good | 4% | The time lock was left in its maintenance window: `time_lock_s` = 10. |
| `armored_car_early` | bad | 8% (Brutal+ only) | At 12:00 elapsed, the armoured car arrives at the sally port with 2 extra guards (pagers) who enter G1 → B1. Stealth must finish or deal with them. |
| `fog_lifts` | bad | 10% | The fog clears at 08:00: the quay is visible from the P1/P2 lanes, and the boat escape is delayed 60 s in loud. |
| `co_op_courier` | good | 5% | A Co-op runner drops an extra 2 bags in the chute mid-heist (`depository_bags` += 2). |

## Escape
- **Van (E1):** in the staff lot by the sally door. Stealth: parked from the start; escape opens
  after ≥ 4 bags are secured. Loud: it leaves at the alarm and returns per the objectives rule.
- **Boat (E2):** a Co-op fishing launch at the quay steps. Same rules. The secure zone is the deck.

## Pre-planning (P4 board; preplanning.md contract)
`Preplan` points (category):

| Point | Category | Params / asset |
|---|---|---|
| `pp_drop_lot` | drop_zone | by the dumpster: body bag case, ammo (no ECM drop: ECM is a deployable, D-117) |
| `pp_drop_quay` | drop_zone | |
| `pp_spawn_lot` | spawn | spawn_tag `preplan_spawn_lot` |
| `pp_spawn_quay` | spawn | spawn_tag `preplan_spawn_quay` |
| `pp_escape_van` | escape | variant_group `escape`, variant_slot `esc_van_lot` |
| `pp_escape_boat` | escape | variant_group `escape`, variant_slot `esc_boat_quay` |
| `pp_insider_code` | insider | reveals `code_note` |
| `pp_insider_keycard` | insider | reveals `keycard` |
| `pp_vent` | insider | forces `vent_open` |
| `pp_blueprint_cams` | insider | reveals `camera` |

`HeistDef.preplanning`: favors 4; assets with overrides as above (costs set by ENV B's library).

## Audio/lighting
- **Palette** (style guide §3): slate green `#3F5A52` (wall panelling, ATM glass tint, ironwork),
  marble cream `#D9D2C2` (hall marble, columns), bank red `#9E2B25` (carpet runners, logo,
  deposit-box accents); brass fittings within GSR.
- **Time:** night, no sun. Moon low and fog-diffused. Sodium streetlights (~2000 K orange) outside.
  The ATM vestibule is cool LED, a green-white jewel on the corner.
- **Zones:**
  - banking hall: night-mode lighting (25% of the brass pendants on, plus the clock lit); dim and
    shadowy, so stealth is readable;
  - G7/BOH: 4000 K panels; security room: monitor glow;
  - basement: 5000 K utility lights;
  - vault: bright 4000 K strips, high contrast against the red antechamber lasers.
  - Every light has a fixture.
- **Ambience:** `amb_bank_night_interior` (HVAC, clock tick in the hall, fluorescent buzz in the
  basement), `amb_harbor_night` (water lapping, distant foghorn, rigging clinks, gulls muted at night).
- **Music:** `night_deposit` track (stealth 70 BPM, low brass and sub pulses with a ticking motif
  tied to the time lock; assault 140 BPM).
- **LUT:** `lut_night_deposit`: sodium orange highlights, teal-green shadows.

## HeistDef (proposed data, `night_deposit_def.tres`)
`id night_deposit`, display "Nightfall Depository" (D-117), contact `contact.accountant`, mode STEALTH_OR_LOUD,
base_payout **$26,000** (D-120), loot `[loot.cash, loot.cash_bricks,
loot.small_valuables]` (B to confirm ids), escape_options `[van, boat]`, music_track `night_deposit`.

## Requests (to the lead)
- **QC-11 (ENV A prefab):** `bag_lift`, a vertical cash lift. Bags placed in it travel to the other
  landing (8 s, 2 bags per cycle). Same semantics as the P2 `zipline` with a vertical path.
- **QC-12 (ENV A prefab / variant):** the server-hack interaction (3 × 20 s with random reboot
  interruptions) as a configurable `hack_terminal` prefab, or an option on `keypad`.
- **QC-13 (ENV B loot):** `loot.cash_bricks` (MEDIUM bag per the data, D-117; the Co-op pallet) and the small-loot value
  for deposit boxes.
- **QC-14 (ENV A):** the out-of-bounds water kill volume and quay respawn rule (stealth: no alarm),
  if no generic `oob_volume` exists.
