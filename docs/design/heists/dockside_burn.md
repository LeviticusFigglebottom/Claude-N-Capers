# Dockside Burn: Ortega Cold Storage (dockside_burn)
Status: APPROVED (lead, 2026-10-11) (D-064). The lead's answers to the G0 open questions are folded in below (see Lead rulings).

## Fiction
- **Who:** **Ortega Cold Storage**, Pier 9, the freezer warehouse of the **Ortega Fisheries Co-op**:
  the same cartel laundering front whose night drop the crew took in Night Deposit. The building is a
  1970s single-storey high-bay cold store with a two-storey office block and a fish-packing wing,
  on a concrete pier between Ferro Street (north) and the working harbor (south). On paper it
  freezes the Co-op's catch. In fact it is where the Co-op's shipments land: **product** (bricks of
  contraband, vacuum-packed and boxed as frozen fish), **cash** waiting for the laundering run, and
  **weapons** in shipping containers in the yard. The Co-op guards it with its own **crew of
  gunmen** (L4.10 cartel faction), not a security company.
- **What:** the Co-op's cash (strongroom or count room, varies), the two containers of rifles in
  the yard (which two varies), and the product, which **burns**.
- **Why / contact:** **Hollis "Hammer" Reyes** (fixer; loud jobs, warehouses; `contact.reyes`, Board
  district `docks`): *"The Co-op thinks the harbor's theirs because nobody's ever argued. We're
  arguing. Take the money, take the guns, and torch whatever they were going to sell. I want smoke
  over Pier 9 by sunrise."* Reyes pays for cash and guns. The product must burn; anything of it the
  crew carries out is a bonus his buyer takes at a discount.
- **Time / weather:** 05:10, pre-dawn. Dense harbor fog (visibility ~150 m), still air, cold
  (frost on metal). Sodium yard masts and the cold store's own LED floods. The night shift
  (forklift drivers, a packer) is finishing the last truck.
- **Handler:** Mercer on comms. The crew arrives by van at the yard gate on Ferro Street, by the
  west lane through a cut in the fence, or by launch at the pontoon (pre-planning spawn choice).

## Modes
- **Loud-only** (`HeistDef.mode = LOUD_ONLY`, S11.3). Size M (15–25 min). Phase P3. The runtime
  starts the heist LOUD with the crew masked (no casing, no pagers, no cameras).
- **Two-stage loud.** The heist opens with a **cartel phase**: Co-op gunmen hold the yard and the
  building (`enemy.cartel_gunman`, L4.10: no pagers, cannot be dominated, no cuffs). They start
  unalerted on their posts. Suppressed fire or a melee kill lets the crew thin them out first. Any
  unsuppressed shot, explosion or sighting wakes every gunman. **The police arrive after
  `police_delay_s`** (60–120 s; Mercer: "Gunfire on the docks. Somebody's calling it in."). The
  mission then starts the `AssaultDirector`, which runs from the first CONTROL (first responders) as
  usual. Cartel survivors keep fighting the crew (they and the police ignore each other, as in PD2).
  This needs a director-start hook for LOUD_ONLY heists (QC-35). **D-064 (Q1): approved as written:
  the cartel phase comes first and the police arrive after the rolled `police_delay_s` (60/90/120 s).**
- **It uses the full P3 loud set:** every special (Phantom, Stinger, Bulwark, Wrecker, Longshot,
  Corpsman), Commander Brandt + Aegis, escalation by wave, custody and hostage trades (the night
  shift are the hostages), crowd control, AI teammate orders (`carry_bag`, `hold`), plus the
  device set: **placed saws** on container padlocks (S9.4) with the **`saw_target`** group for the
  hand-held saw (D-057), a **thermal drill** on the strongroom door (S9.3), a **drill or C4** on the
  count-room cash cage (S9.8), lockpicking, and the **thermite bag** for the burn (QC-38).
- **The design goal is the P3 gate's holdout loop:** every objective pins the crew to one of **four
  defensible holdouts** for a timed device, while police come from **five directions** and two
  to four **sniper perches** cover the bag routes. Which holdout matters is a variable (cash
  location, product location, escape), so runs play differently.
- **Difficulty notes:**
  - Routine/Tense: 6 gunmen (3 posts), police delay usually 120 s, waves at stage 50/75/100%.
  - Hazardous/Brutal: 8 gunmen, delay usually 60–90 s, `cartel_reinforcements` enabled
    (Hazardous+), `harbor_unit` (Brutal+).
  - Lethal/Cataclysm: 10/12 gunmen, delay 60 s, Brandt + Aegis in reach of the yard. Faction reskins
    (FRD → Sentinel → Zero Division) come from the director (L1.5).
  - **Solo with AI** (first-class, L6.1): AI teammates carry bags only when ordered. Heavy weapon
    crates and the thermite bag make `carry_bag` orders the solo skill check. This is intended.

## Site
- **Lot:** the Ortega building is 48 × 32 m (wall centre lines; outer face 48.4 × 32.4 m). Ground
  FFL = 0.0 m across the building, yard, lane, aprons and quay deck (one slab level, cold-store drive-in
  doors at grade). Massing:
  - office block (x 0–18, z 0–8): two storeys, roof at +7.2 (parapet top +8.3);
  - marshalling hall (x 18–48, z 0–10): roof +6.6;
  - high-bay cold store (x 18–48, z 10–32): roof +9.0, with evaporator condensers on it;
  - west wing (plant, workshop, packing; x 0–18, z 8–32): roof +5.8.
  The **landing stage** at the quay steps floats at −1.8 m.
- **Streets and surroundings:**
  - **North:** the **yard** (x −8…62, z −34…0), then a solid 2.4 m corrugated-steel fence with the
    open sliding **gate** (x 30–38) and the **gatehouse + weighbridge**. Beyond the fence is
    **Ferro Street** (z −52…−40), crossed overhead by the **rail viaduct** (deck +7.0, z −52…−50).
  - **West:** the 8 m **west lane** (x −8…0) between the building and the solid fence of
    *Bellweather Ice Co.*
  - **East:** the 14 m **east apron** (x 48…62), the **slip** (water, x 62…72), and the swing
    **gangway** (z −14…−12) across to the **Pier 10 container terminal**.
  - **South:** the 12 m **quay** (z 32…44), the **pontoon** with the escape launch, the quay steps
    to the landing stage, then open harbor water.
- **Neighbours** (dressing except where stated):
  - **Bellweather Ice Co.** (west, x −30…−10): a north shed and a main building (roof +8.0) with a
    service yard between them (the **P2** police spawn). Its SE roof corner is sniper perch
    **S2**.
  - **Pier 10 container terminal** (east, across the slip): a rail-mounted **gantry crane** (legs
    at x 76/82, cab at +22 m, sniper perch **S1**), container stacks behind a 2.4 m hoarding at x 84
    (the **P3** spawn behind it).
  - **Rail viaduct** (north, over Ferro Street): a service walkway with a parapet at +7.0, sniper
    perch **S3** (fog-gated, rare event).
  - **Harbor** (south): a moored **trawler** east of the landing stage (it blocks LOS to the P4
    spawn shed). Its wheelhouse is perch **S4** (rare event). Far-shore lights sit in the fog at
    ~400 m.
- **Exterior landmarks:**
  1. the **painted "ORTEGA COLD STORAGE" leaping-fish mural** (12 × 2.2 m) on the high-bay north
     wall above the hall roof (the 2.4 m band between +6.6 and +9.0), lit by two sodium floods, visible from the gate, the yard and Ferro Street;
  2. the **Pier 10 gantry crane**, its orange hazard beacons and boom lights rising out of the fog
     over the slip, visible from the yard, the apron and the quay;
  3. the **condenser vapour plumes**: white plumes from the roof condensers, lit sodium-orange,
     visible from everywhere outside. Inside, the **spine aisle** glows cold blue-white through its
     strip curtains, a landmark from the hall. During and after the burn, the product room's
     **flare-orange fire glow** spills out of its door glazing and over the roof.
- **Play space:** x −8…84, z −46…56 for crew. The police spawn areas lie beyond the closures: the
  Ferro Street ends, the Bellweather service yard, Pier 10 behind its hoarding, the landing-stage
  shed and the high-bay roof. Each edge is closed as follows (the `bounds` validator checks every one).

### Play-space closure

| Edge | Closure |
|---|---|
| Ferro Street, west end (x −12) | Under the viaduct: a row of concrete jersey barriers plus two parked semi-trailers across both lanes. The **P1w** spawn is behind the trailers (x −20, z −46). Beyond, the street continues as a vista to a bend at x −60 (warehouse facades). |
| Ferro Street, east end (x 66) | A closed level-crossing barrier and a parked reefer truck across the lanes. The **P1e** spawn is behind the truck (x 70, z −46). Vista: the street and viaduct continue to x 140, then the viaduct curves away (facade across the axis). |
| Ferro Street, north side (z −52) | Viaduct piers with a 2.4 m palisade between them; the warehouse backs of the next block behind. The viaduct walkway (+7.0) is not reachable (no stair; the S3 perch is police-only). |
| North fence (z −34, x −8…62) | 2.4 m solid corrugated steel (blocks LOS and bullets). Openings: the gate (x 30–38, open) and the lane man-gate (x −4, chained shut; police ENTRY, breachable). |
| West lane / Bellweather (x −8) | 2.4 m solid fence (Bellweather's) with a man-gate at z −14 (P2 ENTRY, chained; police breach it). Bellweather's buildings behind it are dressing (no openings at ground on our side). |
| East apron / slip (x 62) | Quay edge with bollards and a 1.05 m tube railing (guard ≥ 1.0 m, QC-33). The slip water is **`MapZone.OUT_OF_BOUNDS`** (D-040): crew respawn at `oob_respawn` spawns on the quay, and bags return to their last securable position. The gangway gap (x 62, z −14…−12) is the only opening. |
| Gangway | Swing bridge, 3.0 m wide, 1.1 m railings both sides. `gangway_down`: it spans the slip to the Pier 10 apron (x 74–84). `gangway_up`: it is swung parallel to the slip and its gap has a hinged 1.05 m barrier. |
| Pier 10 (x 84) | 2.4 m solid hoarding with a gate at z −16…−12 (P3 ENTRY). The stacks behind (x 88–100) are dressing, 4 high (10.4 m). The crane is dressing except the S1 perch. |
| Quay edge (z 44) | Bollards and a 1.05 m railing, except at the **pontoon ramp** (x 23–25) and the **quay-steps recess** (x 55–59, z 40–44, with a 1.05 m guard around its open top edge). Water beyond is OUT_OF_BOUNDS. |
| Pontoon + ramp | Ramp 2.0 m wide, from the quay (0.0) to the pontoon (−1.8) over 6.0 m (16.7°, under the 40° walkable slope), with 1.05 m rails. Pontoon 16 × 4 m with a 1.05 m rail except on the boat side. The boat's gunwale closes that side. |
| Landing stage (−1.8) | x 52–62, z 44–48, rails 1.05 m on the water sides. The **P4 harbour shed** (x 56–62, closed on N/W/S, open E) is on it. The trawler (x 62–80) closes the east view. |
| High-bay / hall roofs | Not reachable by the crew: the office-roof parapet has the **45° sloped coping** (as Shadow Ledger), so nobody stands on it, and the hall roof (+6.6) sits beyond it. The high-bay roof is a police-only navmesh island (P5) joined to the interior only by one-way rappel links (QC-41). |
| Up | Fog layer from 30 m with a dark-blue pre-dawn sky above. Every visible roof has a parapet and plant. |
| Far | Harbor fog: far-shore lights at ~400 m; the Pier 10 stacks and crane close the east; the Bellweather buildings close the west; the Ferro Street facades close the north. Nothing reachable sees the void. |

### Site plan
1 char = 2 m (x) and 1 row = 2 m (z), the same origin and axes as the floor plans (the NW corner of the
Ortega building; +x east, +z south). `#` the Ortega shell / north fence, `%` neighbour buildings
and container stacks, `|` fences, `g` man-gate / hoarding gate, `K` 40 ft containers K1–K6 (one
high), `k` D1 (two high, player perch), `h` gatehouse (GH), `w` weighbridge (E1 van), `s` quay shed
(QS), `:` pontoon ramp, `=` viaduct (north row), gangway (slip) and pontoon (south), `b` the escape
launch (E3), `v` quay steps, `-` landing stage, `T` trawler (S4), `H` crane legs (S1 at the cab),
`o` culvert outfall (Phantom vent), `~` water (OUT_OF_BOUNDS), `P` player spawns (gate default,
lane, pontoon), `P1…P5` police spawn groups, `S1…S3` sniper perches, `E1…E3` escapes.

```
     x -30  -20  -10  0    10   20   30   40   50   60   70   80   90   100  110  
  -52 =======================================================================
      ====================S3======== RAIL VIADUCT deck +7.0 =================
  -48 
           P1                                           P1
  -44   FERRO STREET
      
  -40                                 PPP
      
  -36                               gate
                 |##################     ###########           |
  -32            |              hhhh                           |
      %%%%%%%%%%%|P          GH h  hwwwww           ~~~~~~     | %%%%%%%
  -28 %         %|    KKKKKKK   hhhhwwwww   KKKKKKK ~~~~~~     | %%%%%%%
      %BW shed  %|     K1           wwwww    K4     ~~~~~~     | %%%%%%%
  -24 %         %|                  wwE1w           ~~~~~~     | %%%%%%%
      %         %|    KKKKKKK       wwwww   KKKKKKK ~~~~~~     | %%%%%%%
  -20 %         %|     K2           wwwww    K5     ~~~~~~     | %%%%%%%
      %%%%%%%%%%%|                  wwwww           ~~~~~~     |
  -16            |    KKKKKKK               KKKKKKK ~~~~~~     |
       P2 yard   g     K3                    K6     ======     g  P3
  -12            |                                  ======     |
      %%%%%%%%%%%|                                  ~~~~~~     |
   -8 %         %|    kkkkkkk                       ~~~~~~ H  H| %%%%%%%
      %         %|    kkkkkkk                       ~~~~~~ H  H| %%%%%%%
   -4 %         %|     D1 x2 high                   ~~~~~~ H  H| %%%%%%%
      %         %|                                  ~~~~~~ H  H| %%%%%%%
    0 %BW ICE CO%|   #########################E APRON~~~~~ HS1H| %%%%%%%
      %         %|   #                       #      ~~~~~~ H  H| %%%%%%%
    4 %roof +8.0%|   #          HALL roof+6.6#      ~~~~~~ H  H| %%%%%%%
      %         %|E2 #                       #      ~~~~~~ H  H|
    8 %         %|   # OFFICE                #      ~~~~~~ H  H|
      %         %|   # + W WING              #      ~~~~~~ H  H|
   12 %         %|   #                       #      ~~~~~~     |
      %         %|   #                       #      ~~~~~~CRANE|
   16 %         %|   #         COLD STORE    #      ~~~~~~     |
      %         %|   #         roof +9.0     #      ~~~~~~     |
   20 %         %|   #         P5 roof spawn #      ~~~~~~     |
      %         %|   #                       #      ~~~~~~     |
   24 %         %|   # PACKING               #      ~~~~~~     |
      %         %|   #                       #      ~~~~~~     |
   28 %         %|   #                       #      ~~~~~~     |
      %         %|   #                       #      ~~~~~~     |
   32 %         %|   #########################      ~~~~~~     |
      %         %|          sssss                   ~~~~~~     |
   36 %         %|   QUAY   sQS s                   ~~~~~~     |
      %      S2 %|          s   s                   ~~~~~~     |
   40 %%%%%%%%%%%|          sssss                vv ~~~~~~     |
                                                 vv ~~~~~~     |
   44             o              :             -----~~~~~~     |
      ~~~~~~~~~~~~~~~~~~~~~~~~~~~:~~~~~~~~~~~~~--P4-TTTTTTTTT~~~~~~~~~~~~~~~~
   48 ~~~~~~~~~~~~~~~~~~~~~~~~~~~:~~~~~~~~~~~~~-----TTTTTTTTT~~~~~~~~~~~~~~~~
      ~~~~~~~~~~~~~~~~~~~~~~~~~~~:~~~~~~~~~~~~~~~~~~TTTTTTTTT~~~~~~~~~~~~~~~~
   52 ~~~~~~~~~~~~~~~~~~~~~~~=========~~~~~~~~~~~~~~~trawler~~~~~~~~~~~~~~~~~
      ~~~~~~~~~~~~~~~~~~~~~~~=====PP==~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   56 ~~~~~~~~~~~~~~~~~~~~~~~bbbbbbbb E3 boat~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   60 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

## Floor plans
1 char = 1 m. Each character is a **grid point** (x = col, z = row). Lines are **wall centre
lines**: exterior 0.4 m, interior 0.2 m, insulated cold-store panels 0.2 m (`%`), strongroom walls
0.4 m reinforced (`%` around SR). The origin is the building's NW corner; +x is east and +z is
south (the yard is at the top, the quay at the bottom). Rulers are in metres. The plans are
generated by `tools/levelcheck/plans/dockside_burn_floors_ascii.py` (room rectangles in metres).
Its `--check` mode verifies that the rooms tile each footprint exactly, that every door sits on a
wall, that every room has a door, and the stair arithmetic below. It follows the Glasshouse/Night Deposit/Shadow Ledger plan tools; `dockside_burn_site_ascii.py` draws the site plan.

Legend: `#` exterior wall, `|`/`-` interior wall, `+` wall junction, `%` insulated cold-store panel /
strongroom wall, `D` door (personnel 0.9–1.2 m; cold-store sliding doors `DDD` 2.4 m), `R` roller
door (3.6 × 4.5 m), `s` strip curtain (open 3 m opening), `V` strongroom vault door (2.0 × 2.2 m),
`T` thermal-drill point, `W` window, `^ v` U-stair (up-flight, return flight), `<<<=<<` the hall
platform stair (flight, landing, flight; rising west), `vvv=vv` the same stair seen from the
platform, `r` 1.05 m guard rail, `L` loot spawn, `S` cash cage (count room), `F` burn point
(product location), `G` cartel post, `c` night-shift worker, `u` culvert floor grate (Phantom
vent), `P` player spawn, `p` roof parapet (1.1 m, 45° coping), `HH` stair head house.

**Vertical data** (`HeistMap.floor_heights = [-1.8, 0.0, 3.6, 7.2]`, `floor_names = ["Landing",
"Ground", "Mezzanine", "Roof"]`, D-054). The landing stage is listed because the quay steps arrive
on it, and every stair chain must run between `floor_heights` entries. It is ascending and contains
0.0 (D-040). **D-064 (Q4): keep the −1.8 Landing entry** (the stair-chain rule needs it).

| Level | FFL | Ceiling | Floor-to-floor / slab | Notes |
|---|---|---|---|---|
| Landing stage | −1.8 | open (exterior) | quay steps 1.8 | floating pontoon deck |
| Ground | 0.0 | office block 3.0; hall 5.8; high bay **8.0** (override); anteroom 5.8; strongroom 3.5; plant / workshop 5.0; packing 4.5; locker / janitor 3.0 | office block 3.6 (0.6 plenum + slab) | warehouse 3.5–6 ✓, office 2.6–3.0 ✓, plant 2.6–6 ✓ |
| Mezzanine (office block + hall platform) | 3.6 | 3.0 (office block); the platform sits under the 5.8 hall ceiling (2.2 headroom) | 3.6 to the roof (0.6) | office 2.6–3.0 ✓; headroom ≥ 2.1 ✓ |
| Roof (office block) | 7.2 | open; head house 2.7 clear | — | parapet 1.1 m |
| Stair ST | 0.0 → 3.6 → 7.2 | U-stair, 2 flights × 10 risers @ 0.180 m per storey, tread 0.28 m (run 2.52 m), width 1.2 m | 20 risers = 3.6 ✓ per storey | landing every 10 ≤ 16 ✓ |
| Hall platform stair | 0.0 → 3.6 | straight, 2 flights × 10 risers @ 0.180, tread 0.28, width 1.2, mid landing 1.2 m; x 22.0–28.24, z 6.8–8.0 | 20 risers = 3.6 ✓ | open both sides: 1.05 m guards with handrail tops (QC-33) |
| External fire stair (west face) | 3.6 → 0.0 | straight, 2 flights × 10 @ 0.180, tread 0.28, width 1.2, mid landing 1.2 m; x −1.4…−0.2, from the MC landing (z 6.0–8.0) north to z −0.24 | 20 risers = 3.6 ✓ | wall side handrail 0.9; open side guard 1.05 m |
| Quay steps | −1.8 → 0.0 | 1 flight × 10 risers @ 0.180, tread 0.30 (run 2.7 m), width 2.0 m, in a recess cut into the quay (x 55–59, z 40.3–43.0) | 10 risers = 1.8 ✓ | walls both sides, handrails 0.9 both sides; 1.05 m guard round the recess top |

**Stair core fit** (ST: 3.0 × 6.0 m centre lines, 0.3 m walls, so 2.7 × 5.7 m clear): flights
1.2 + 0.2 well + 1.2 = 2.6 ≤ 2.7 ✓. Along z: 1.30 floor landing + 2.52 run + 1.30 half landing =
5.12 ≤ 5.70 ✓. The stair door (1.0 m) sits on the south floor landing (z 4.7–6.0), opening onto
the level landing, never a flight. Headroom under the return flight ≥ 3.3 m ✓ (one full storey).

**Per-room ceiling overrides (D-048).** The §2.6 table caps `warehouse` at 3.5–6.0 m. These rooms
carry a `ceiling_range` override of **6.0–9.0 m**:
**Approved (D-064, Q3).**
- **C1, C2** (freezer chambers) and **SP** (spine aisle): a high-bay cold store. Three pallet levels
  at 2.2 m pitch put the top beam at 6.6 m. Evaporator units and sprinkler clearance above that give
  8.0 m clear to the underside of the roof purlins. That is a standard modern cold-store clear height,
  and the racking is the cover layout (see Loud).

Every other room is inside its purpose's band (`plant` 2.6–6.0 and `vault` 2.6–6.0 are the
validator's confirmed ranges; `workshop`, `warehouse` 3.5–6.0).

**Wide doors.** The cold-store sliding doors (2.4 × 3.6 m) and roller doors (3.6 × 4.5 m) are
`door` prefabs with `width_m` 2.4/3.6 and meta `kind = "industrial_door"`. My `scale` check gains an
`industrial_door` rule (width 2.4–4.0, height 2.1–4.5), as Night Deposit's vault-door rule did.
**Approved (D-064, Q3)** and implemented in `game/world/tools/levelcheck/lc_check_scale.gd`
(meta `kind = "industrial_door"`; test in `game/tests/c/test_validate_doors.gd`). Personnel and service doors keep the §2.6 sizes.

### Ground floor (FFL 0.0)
```
      0123456789012345678901234567890123456789012345678
    0 ####W#DW##W##W##########RRRR####RRRR####RRRR#####
      #ST|O1   |O2   |LFDH MARSHALLING HALL           #
    2 #^v|RECEP|SEC  |  D                             #
      #^v|     |     +--+(platform +3.6               R
    4 #^v|     |     |E1| over x18-22)     G          R
      #  |     |     |  |                             R
    6 #DD+D----+--D--+D-+                             R
      DOC CORRIDOR      D   <<<=<<                    #
    8 #---D-----+---D---+                             #
      #PL PLANT |WS SHOPD                             #
   10 #         |       +%%%%DDD%%%%%%+ss+%%%%DDD%%%%%#
      #         |       %C1 CHAMBER A %SP%C2 CHAMBER B#
   12 #         |       %             %  %            #
      #         D       %             %  %            #
   14 D         |       %     F       %  %     F      #
      # u       |       %             D  %            #
   16 #         |       %             D  %            #
      #         |       %             D  %            #
   18 #----+--+D+---D---+ L L L L     %  D L L L L    #
      #LK  |J |         %             %  D            #
   20 #    |  |PK PACK  D             %  D            #
      #    +-D+         D             %  %            #
   22 #    D            D             %  %            #
      #----+            %             %  %            #
   24 #          F      +%%%%%%%+%%%%%+ss+%%%%DDD%%%%%#
      #                 %SR     % AN ANTEROOM         #
   26 #                 %       %                 c c #
      #         L L L   %L L L  V                     #
   28 #                 %       VT        G           D
      #                 %L L L  V                     #
   30 #   c             %       %                     #
      #                 %       %                     #
   32 ######RRRR##D################RRRR######RRRR###D##
```

Ground notes:
- The platform (x 18–22, z 0–8) is drawn on the mezzanine plan. Under it (3.3 m clear under the 0.3 m deck) are the
  goods-lift door (x 18, z 1–2) and the OC double door (x 18, z 7).
- C1/C2/PK each hold **`L` product stacks and an `F` burn point**, but only the active
  `product_location` slot's content exists. The SR `L`s are cash pallets (`cash_strongroom`). The
  PK `L`s are product (`prod_packing`).
- Cold-store doors are **fire shutters**: when the burn finishes, the mission drops the shutters of
  the burning room (BARRED, see Loud).

### Mezzanine (FFL 3.6; office block + hall platform, cropped to x 0–28)
```
      01234567890123456789012345678
    0 ####W##W##W##W########r
      #ST|M2   |M1   DLF#PF r
    2 #^v|BREAK|COUNTD  #   r
      #^v|     |S L L+--#G  r
    4 #^v|     |  G  |M3#   r
      #  |     |     |  #   r
    6 #DD+--D--+--D--+D-#   rrrrrrr
      DMC CORRIDOR      D   vvv=vv
    8 ###################rrrrrrrrrr
```

Mezzanine notes: **PF** is the steel platform inside the hall (4 × 8 m, 1.05 m guard rails with mesh
infill on the open sides). It is reached from MC's east door and by the platform stair (`vvv=vv`,
down to the hall floor at x 28.24). The cash cage `S` in M1 exists only with `cash_countroom`.
The goods lift LF opens west into M1 and east into the hall at ground (`bag_lift`, bags only).

### Roof (7.2; office block only)
```
      0123456789012345678
    0 ppppppppppppppppppp
      pHH|              p
    2 p^v| ROOF +7.2    p
      p^v|              p
    4 p^v| player perch p
      p  |              p
    6 pDD+      P P     p
      p                 p
    8 ppppppppppppppppppp
```

Roof notes: a **player perch** (`perch_roof` slot: the head-house door is unlocked; otherwise it is
LOCKPICK 8 s). It looks north over the yard, the gate and the viaduct (S3), and west over the lane.
The hall and high-bay roofs to the east are not reachable (sloped coping on the parapet).

## Room list
Sizes are between wall centre lines. Office windows have a 0.9 m sill. The hall has a clerestory band
at 4.8–5.5 m on its north wall (exterior). The cold store has no windows (skylights in the roof only).

| id | purpose (`RoomVolume.purpose`) | size m | ceiling m | kit | notes |
|---|---|---|---|---|---|
| O1 | reception (front office) | 6 × 6 | 3.0 | `office_front_desk` | Counter (0.9 m service), waiting bench, tide/ship schedule boards, phone. Front door N (`door_office` variant: unlocked). Windows N. |
| O2 | security_room (dispatch + CCTV) | 6 × 6 | 3.0 | `security_office` | Co-op dispatch desk, CCTV monitors (dressing in loud), key board, radio, gun locker (dressing). Small **gatehouse-style safe** under the desk: `safe` SMALL, `methods [drill, c4]`, 3 `small_loot`. Windows N. |
| ST | stair | 3 × 6 | open | — | Ground → mezzanine → roof (head house). |
| LF | elevator (goods lift) | 3 × 3 | — | — | **`bag_lift`** (`goods_lift` variant powered/dead), 2 bags per cycle, 8 s. Ground door E (hall), mezzanine door W (M1). |
| E1 | electrical | 3 × 3 | 3.0 | `electrical_closet` | Main board, the **lift breaker** (interact 5 s with `lift_dead`), telecom. |
| OC | corridor (office, ground) | 18 × 2 | 3.0 | `corridor_service` | W exterior door (LOCKPICK, lane), E double door to the hall, doors to O1/O2/ST/E1/PL/WS. |
| PL | plant (ammonia compressor room) | 10 × 10 | 5.0 | `plant_refrigeration` | 3 screw compressors, receiver vessel, valve manifolds, control panel. W exterior door (LOCKPICK). **Culvert grate `u`** (Phantom vent exit, nav layer `vent`). |
| WS | workshop (forklift charging) | 8 × 10 | 5.0 | `workshop_forklift` | 2 forklifts on chargers, battery racks, tool benches. Service door (1.2 m) to the hall. |
| LK | locker_room (with WCs) | 5 × 5 | 3.0 | `locker_room` | Workers' lockers, bench, 2 WC cubicles, sink. |
| J | janitor | 3 × 3 | 3.0 | `janitor_closet` | Mop sink, chemicals, shelving. |
| PK | warehouse (packing hall) | 218 m² (18 × 14 less LK/J) | 4.5 | `packing_hall` | Fish packing line: conveyor, stainless tables, ice machines, box stacks. `prod_packing`: product stacks (`L`) + burn point `F`. Roller door + personnel door S (quay); sliding door E to C1. |
| H | warehouse (marshalling hall) | 30 × 10 | 5.8 | `marshalling_hall` | Dispatch staging: pallet lanes, pallet jacks, wrapped pallets (cover), dock leveller plates. 3 roller doors N (yard), 1 roller E (apron). Contains **PF** (platform). Clerestory windows N. |
| PF | (part of H) platform | 4 × 8 (at +3.6) | 2.2 headroom | — | Steel foreman's platform; RoomVolume H covers it (H's ceiling median stays 5.8: the platform is 32 of 300 m²). |
| C1 | warehouse (freezer chamber A) | 14 × 14 | **8.0** (override 6.0–9.0) | `cold_store_racked` | 4 racking rows (2.7 m deep, 3-level, 3.0 m aisles), frosted product boxes. Doors: hall N, PK W, SP E. Skylight + RAPPEL over the centre aisle. `prod_chamber_a`. |
| SP | warehouse (spine aisle) | 3 × 14 | **8.0** (override 6.0–9.0) | `cold_store_aisle` | Strip curtains N and S (3 m, walkable, block LOS). Doors to C1 and C2. Skylight + RAPPEL. |
| C2 | warehouse (freezer chamber B) | 13 × 14 | **8.0** (override 6.0–9.0) | `cold_store_racked` | As C1, mirrored. Doors: hall N, SP W, AN S. `prod_chamber_b`. |
| SR | vault (blast-freezer strongroom) | 8 × 8 | 3.5 | `strongroom_freezer` | The Co-op's cash: shrink-wrapped pallets of cash bricks (`cash_strongroom`: `loot_spawn` `loot.cash_bricks` × `cash_bags`). **Vault door `V`** (2.0 × 2.2, `door` lock VAULT), opened by the **thermal drill** at `T` (`drill_point` THERMAL, 240 s, jams). With `cash_countroom` it is an empty strongroom (fish blocks), and the door stays shut. |
| AN | warehouse (anteroom / quay dock) | 22 × 8 | 5.8 | `quay_dock` | Dock for the quay side: pallet stacks, wrapping machine, a forklift. 2 roller doors S (quay), personnel doors S and E. Strip curtain N (SP), sliding door N (C2), vault door W (SR). Night-shift workers `c`. |
| M1 | cash_office (count room) | 6 × 6 | 3.0 | `count_room` | Counting tables, money counters, vacuum sealer. `cash_countroom`: **cash cage** (`safe` LARGE, `methods [drill, c4]`, drill 120 s) with the cash-brick `loot_spawn`s as its contents. Goods-lift door E. Windows N. |
| M2 | break_room | 6 × 6 | 3.0 | `break_room` | Fridge, counter + sink, microwave, coffee, table with 6 chairs, bulletin board (shift rota), TV. Windows N. |
| M3 | restroom | 3 × 3 | 3.0 | `restroom_single` | WC, sink. |
| MC | corridor (mezzanine) | 18 × 2 | 3.0 | `corridor_service` | W door to the external fire stair landing (LOCKPICK from outside, push bar inside); E door to PF. |
| HH | stair (head house) | 3 × 6 | 2.7 | — | Roof door (`perch_roof` → unlocked; else LOCKPICK). |
| GH | office (gatehouse) | 6 × 4 | 2.7 | `gatehouse` | Weighbridge console, gate controls, heater, kettle, phone, window to the weighbridge. Doors N/S. |
| QS | storage (quay net store) | 8 × 6 | 3.0 | `net_store` | Nets, floats, fish boxes, rope reels; doors W and E, window S (to the pontoon). Holdout H3. Drop zone `pp_drop_quay`. |
| X1 | exterior (yard) | 70 × 34 | — | `exterior_yard` | Containers K1–K6 (+ D1 double stack), weighbridge, sodium masts, a reach stacker, pallets of ice bins, a parked reefer trailer (cover). |
| X2 | exterior (west lane) | 8 × 78 | — | `exterior_lane` | Parked flatbed, skips, the fire stair, roller-shutter-faced Bellweather fence. Escape E2. |
| X3 | exterior (east apron + gangway) | 14 × 78 | — | `exterior_apron` | Dock-door canopy, bollards, a forklift, tyre-fendered quay edge, the gangway. |
| X4 | exterior (quay, pontoon, landing stage) | 70 × 12 (+ pontoon 16 × 4, stage 10 × 4) | — | `exterior_quay` | Bollards, net stacks, ice-bin pallets, QS, the pontoon and launch (E3), the quay steps, the P4 shed. |
| X5 | exterior (roof, office block) | 15 × 8 | — | `exterior_roof` | HVAC units, vent stacks; player perch. |

Support-space check (level_standards §2.2):
- restrooms: LK (ground, 2 WCs) and M3 (mezzanine); the night shift is ≤ 10 people ✓;
- break room M2 ✓; janitor J ✓; electrical E1 ✓, with IT/CCTV in O2 ✓;
- loading and back entrances: the hall roller doors (yard), the dock door (apron), the AN and PK
  roller doors (quay) ✓;
- the office block has 2 floors plus a roof: stair ST plus the external fire stair (2 egress
  routes) ✓;
- fire exits: OC west door, MC west door (fire stair), and every personnel door in the warehouse.
  The longest travel to an exit is ≈ 24 m (the C1 NE corner to the PK quay door) ✓.

## Circulation
- **Public:** none (a private yard at 05:10).
- **Night shift (civilians, `civ_worker`):** forklift drivers between AN, SP and H (wrapping and
  staging pallets), and a packer in PK. On the alarm they cower. They are the heist's **hostages**
  (L5.3 anticipation bonus, L2.10 trades). They count as civilian kills. A fleeing worker runs to the
  nearest exterior door and off the map (no alarm effect; it's already loud).
- **Cartel (before contact):** one `cartel` PatrolGraph across the yard, hall, mezzanine and quay,
  with ≥ 3 loops per post (heist_map §4):
  - `post_gate`: GH ↔ weighbridge (pause `smoke`) → gate (look out at Ferro St) → K3/K6 ends.
  - `post_yard_w`: K1–K3 alleys → D1 → lane north end.
  - `post_yard_e`: K4–K6 alleys → apron → gangway head (pause `look`).
  - `post_hall`: H floor ↔ dock door ↔ SP mouth (pause at the strip curtain).
  - `post_platform`: PF ↔ M1 ↔ M2 (coffee pause).
  - `post_dock`: AN ↔ SR door (pause `look`) ↔ quay roller doors.
  - `post_quay`: QS ↔ pontoon ramp ↔ quay steps top.
  On wake they leave the graph and fight from COVER points near their post (`cartel_<post>` tags).
- **Crew:** the yard (spawn) → building by any of 3 sides. The loot flows depend on the escape (see
  Loot path).
- **Police lanes** (after `police_delay_s`; spawns and entries in Loud):
  - **N:** gate → yard → hall roller doors / the office front door.
  - **W:** Bellweather man-gate → lane → OC/PL/MC fire-stair doors and the PK side of the quay.
  - **E:** gangway → apron → dock door, the AN east door, the yard east.
  - **S:** quay steps → quay → AN/PK roller doors, QS.
  - **Roof:** rappel into C1, SP and C2.

### Cartel, civilian and police roster (spawn data)

| NPC | Count | Presence | Spawn tags | Idle activity | PatrolPoint tags |
|---|---|---|---|---|---|
| Cartel gunman (gate) | 2 | `guard_post` = `post_gate` | `cartel_gate` | `smoke` | `cartel`, `cartel_yard` |
| Cartel gunman (yard west) | 2 | `post_yard_w` | `cartel_yard_w` | — | `cartel`, `cartel_yard` |
| Cartel gunman (yard east) | 2 | `post_yard_e` | `cartel_yard_e` | — | `cartel`, `cartel_yard` |
| Cartel gunman (hall) | 2 | `post_hall` | `cartel_hall` | — | `cartel`, `cartel_hall` |
| Cartel gunman (platform / count room) | 2 | `post_platform` | `cartel_platform` | `sit` (M2) | `cartel`, `cartel_mezz` |
| Cartel gunman (quay dock) | 2 | `post_dock` | `cartel_dock` | — | `cartel`, `cartel_dock` |
| Cartel gunman (quay) | 2 | `post_quay` | `cartel_quay` | `smoke` | `cartel`, `cartel_quay` |
| Cartel reinforcements | 4 | rare `cartel_reinforcements` (timed spawn at the gate, QC-25 hook) | `cartel_reinf` | — | — |
| Night-shift worker | 1–3 | `night_shift` scalar | `civ_worker` (AN ×2, PK ×1, H ×1 candidates) | `browse` (forklift / packing) | `staff`, `staff_dock` |
| Police | director | after `police_delay_s` | POLICE spawns `police_n`, `police_w`, `police_e`, `police_s`, `police_roof` | — | — |

**Totals per difficulty:**

| Difficulty | Cartel posts (gunmen) | `police_delay_s` weights 60/90/120 | Civilians | Special perches active |
|---|---|---|---|---|
| Routine | 3 (6) | 0.1 / 0.3 / 0.6 | 1–3 | S1, S2 |
| Tense | 3 (6) | 0.2 / 0.4 / 0.4 | 1–3 | S1, S2 |
| Hazardous | 4 (8) | 0.3 / 0.5 / 0.2 | 1–3 | S1, S2 (+S3 fog_lifts) |
| Brutal | 4 (8) (+4 reinforcements) | 0.5 / 0.4 / 0.1 | 1–3 | + S4 `harbor_unit` |
| Lethal | 5 (10) | 0.7 / 0.3 / 0 | 1–3 | as Brutal |
| Cataclysm | 6 (12) | 1 / 0 / 0 | 1–3 | as Brutal |

**Enemy cap (D-064, Q5):** cartel gunmen count against `DifficultyDef.max_active_enemies`. The
director's police quota is reduced by the number of cartel gunmen alive, so at Cataclysm the 12 (16
with reinforcements) gunmen plus police never exceed the cap. ENV A enforces this (director side);
the map and the mission do nothing extra.

## Sightlines
- **The yard is the kill zone.** It is 70 m wide and open between the two container blocks. The
  weighbridge lane (x 30–38) runs straight from the gate to the hall's middle roller door. Cover:
  the containers (hard, 2.6 m), D1 (5.2 m), the reach stacker, the reefer trailer, ice-bin pallets
  (soft), and the weighbridge kerbs (0.3 m).
- **Gate → hall:** a 34 m straight line from the gate to roller door 2 (x 32–35.6). Police from P1
  reach it in ~45 m. A player on PF sees the yard only through the open roller doors (clerestory too high).
- **Hall:** a 30 × 10 m open floor. PF overlooks all of it from +3.6. The platform stair is exposed
  to the whole hall. The SP strip curtains block LOS but not movement (AI and players see nothing
  through them; they are a "curtain of cover" both ways).
- **Cold-store chambers:** racking rows run N–S. 3.0 m aisles give 14 m sightlines along each aisle
  and none across. Rappellers land in the centre aisle under each skylight.
- **Anteroom:** 22 m W–E. The strongroom door is at its W end. The two quay roller doors (when
  breached) look straight in from the quay. Pallet stacks (1.6 m wrapped) are the cover.
- **Quay:** 70 m long, 12 m deep, flat. QS and the net stacks are the only hard cover. S2 sees
  most of it.
- **Lane:** 8 m wide, 78 m long, straight. The fire stair and the flatbed are the cover. S2 looks
  straight down it from the south (35 m to E2).

**Sniper lanes (Longshot, L4.7: red laser, 1.2 s aim lock, bypasses armor gating; damage halved
beyond 30 m except on Cataclysm):**

| Perch | Position (x, z, y) | Sees | Distance to the bag route | Blind to |
|---|---|---|---|---|
| **S1** Pier 10 crane cab | (79, 0, +22) | east apron, gangway, yard east (K4–K6), the hall roller doors, weighbridge/E1, quay east (x 48–62), landing stage | E1 56 m, K4–K6 41 m, apron 34 m, hall doors 50 m | the quay west of x 48 and the pontoon (the high bay blocks it), the lane |
| **S2** Bellweather roof SE | (−14, 38, +8.6) | the whole lane (E2 35 m), quay x −8…40, QS (33 m), the pontoon and launch (E3 43 m), the PK and AN quay doors | E3 43 m, QS 33 m, E2 35 m | the yard (Bellweather's main roof plant blocks it), the apron |
| **S3** viaduct walkway (rare `fog_lifts`) | (10, −50, +7) | yard west and centre, the gate, GH/E1 (36 m), K1–K3 (30 m), the office block N facade and M1 windows, the roof perch (54 m) | E1 36 m, K1–K3 30 m | everything south of the building |
| **S4** trawler wheelhouse (rare `harbor_unit`) | (70, 50, +4.5) | the quay east half, the AN quay doors, the landing stage | AN doors ~38 m | the pontoon (QS and the net stacks block it), the yard |

The perches are `TacticalPoint` SNIPER_PERCH (the Longshot spawns there via `SpecialSpawner`). S3 and
S4 are VariantSlot children, enabled by their rare events. **D-064 (Q8): the two always-on perches
(S1, S2) are enough** for the P3 gate. **Player perches:** the office roof
(`perch_roof`, +7.2) has LOS to S3 (54 m) and the yard. D1's top (`perch_stack`, +5.2) has LOS to S1
(73 m, through fog) and the whole yard. Counter-sniping a Longshot is the player answer.

## Stealth routes
**None.** Dockside Burn is loud-only (S11.3): the crew starts masked and the heist is LOUD from the
first frame. The template section is kept for the format. The equivalent decision is the
**approach**. Each is a pre-planning spawn choice, and each meets a different first fight:

1. **Gate (default, `pp_spawn_gate`).** Ferro Street, outside the gate. The van and the thermite
   bag are here. Fight through `post_gate` and the yard posts. The short way to the containers and
   to E1. The long way to the quay.
2. **West lane (`pp_spawn_lane`, `asset.alternate_entry`).** Through a cut in the fence at the lane
   north end. Into the office block (OC west door, LOCKPICK 8 s) or PL (west door). Bypasses the
   yard posts and is the shortest way to the count room. The thermite bag comes with you.
3. **Pontoon (`pp_spawn_pontoon`, `asset.alternate_entry`).** By launch at the pontoon (−1.8). Up
   the ramp → QS → the AN personnel door (LOCKPICK, or `door_quay` open). Straight into the
   strongroom side. The yard and its containers are 60–100 m away.

Cartel posts start unalerted, so a crew with suppressed weapons can take 2–4 gunmen quietly before
the fight wakes (there are no pagers; a gunman who sees a body or a crew member shouts and wakes
the rest).

## Loud
**Phase outline.** Cartel phase (0 → `police_delay_s`) → first CONTROL (20 s, first responders) →
ANTICIPATION (30 s; +30 s once with a hostage) → BUILD → SUSTAIN → FADE → CONTROL … (L1.1). Expected
in a normal run: wave 1 during the first timed device (strongroom drill or count-room cage),
wave 2 while bags move and the burn runs, and wave 3 during the escape wait. Escalation (L1.3)
makes wave 3 the 100% stage.

### Holdouts (≥ 3 required by the P3 gate; 4 designed)

| Holdout | Where | Entrances (chokepoints) | Flanks | Sniper exposure | Strength | Weakness | It matters when |
|---|---|---|---|---|---|---|---|
| **H1 Platform + count room** | PF + M1/MC (+3.6), centroid (16, 3) | (1) the **platform stair** (1.2 m, 6.2 m long in the open); (2) the **ST stair door** at OC (from the OC corridor: the lane door and the hall double door); (3) the **MC west door** (external fire stair from the lane) | The whole hall floor shoots up at PF through the mesh guard (soft cover). The roof rappellers land in C1/C2 and come through the hall doors. | None inside. M1's N windows face the viaduct (S3, `fog_lifts` only). | Height and one hard room (M1, 6 × 6, 2 doors + the lift). Attackers must climb a 3.6 m stair under fire. | 3 entrances at 3 different ground points. A Bulwark on the platform stair blocks the bag route. | `cash_countroom` (the cage drill, 120 s); bags go down the lift. |
| **H2 Anteroom + strongroom** | AN + SR (ground), centroid (30, 28) | (1) **SP mouth** (3 m strip curtain, from the hall); (2) the **C2 south door** (2.4 m); (3) **2 quay roller doors** (police breach them: ENTRY, breachable); (4) the **S and E personnel doors** | Roof rappel into C1/C2/SP (20–25 m away) arrives through (1)/(2). The water group (P4, 32 m) arrives through (3)/(4). | The quay doors when open: S2 (51 m), S4 (rare). | Pallet stacks for cover; the strongroom is an 8 × 8 last-stand box with one door once open. | **Six entries**: the hard holdout. | `cash_strongroom` (thermal drill, 240 s). Burning C2's product first **drops C2's shutters** and removes entry (2) and the C2 rappel route. |
| **H3 Quay shed** | QS (exterior quay), centroid (18, 37) | (1) quay west (from the lane, P2); (2) quay east (from the steps, P4, 40 m); (3) the PK and AN quay doors behind (from inside the building) | Crossfire along the quay from both ends. Rappellers leave the building through the AN doors. | S2 (33 m) on the shed's open sides and the ramp; S4 (rare) on the east half. | 8 m from the pontoon ramp; QS walls are hard cover; net stacks. | Open quay; S2 always covers the ramp. | `esc_boat` (the escape wait), and the loot staging for the boat. |
| **H4 Gatehouse + weighbridge** | GH + the weighbridge between K-blocks, centroid (30, −28) | (1) the **gate** (P1, 44–53 m); (2) the yard west (lane, P2); (3) the yard east (apron/gangway, P3) | Both container blocks are flanking lanes: police come down the container alleys. | S1 (56 m to E1); S3 (36 m, `fog_lifts`). | Containers give lanes the crew can collapse to; the van is at E1. | Exposed to the gate's straight line; 2 snipers on the worst roll. | `esc_van_gate` (the escape wait), and container loot staging. |

Not designated, but useful: the **office roof perch** (one stair door; counter-sniper position)
and **D1's top** (ladder; no bags on ladders, S10.1b).

### Police spawns (≥ 3 directions required; 5 designed) and the spawn rule
Spawns are `SpawnPoint` POLICE (groups by tag). The director spawns at POLICE spawns **and ENTRY
points** that have **no LOS from any active crew member and are ≥ 15 m (flat) from each of them**
(DirectorTweak `min_crew_distance_m` = 15, L1.4). It picks the nearest valid one to the crew
centroid by path cost. So the direction is emergent: it follows where the crew stands and which
entries are currently out of sight. The table gives flat distances from each spawn to each holdout
centroid. All are ≥ 23 m (≥ 15 m required), so a crew inside a holdout never blocks every spawn.

| Spawn (tag) | Position (x, z, y) | Occluder (out of LOS of loot and escapes) | → H1 | → H2 | → H3 | → H4 |
|---|---|---|---|---|---|---|
| **P1e** `police_n` (Ferro St east) | (70, −46, 0) | the parked reefer truck + the solid fence | 73 | 84 | 98 | 44 |
| **P1w** `police_n` (Ferro St west) | (−20, −46, 0) | semi-trailers under the viaduct + the solid fence | 61 | 89 | 91 | 53 |
| **P2** `police_w` (Bellweather service yard) | (−24, −14, 0) | Bellweather's sheds + the solid fence | 43 | 68 | 66 | 56 |
| **P3** `police_e` (Pier 10, `gangway_down` only) | (90, −14, 0) | the 2.4 m hoarding + container stacks | 76 | 73 | 88 | 62 |
| **P4** `police_s` (landing-stage shed, water) | (57, 46, −1.8) | the shed's N/W/S walls, the trawler hull and the 1.8 m quay edge | 59 | 32 | 40 | 79 |
| **P5** `police_roof` (high-bay roof NE) | (46, 12, +9.0) | the roof itself (no crew access); condensers | 31 | 23 | 38 | 43 |

- P3's POLICE spawns are children of the `gangway_down` slot. With `gangway_up` they do not exist,
  and P1e/P4 take that pressure.
- P4 is "police boats" in the fiction: a harbour RIB is moored at the shed (dressing). Units spawn
  on the stage and come up the quay steps; no boat AI is needed.
- P5 units reach the interior only through the one-way **rappel links** at the skylights (QC-41).
- **QC-42 (D-064): police never spawn inside the building.** Police units spawn only at the
  exterior POLICE spawns above and enter the building only through ENTRY `TacticalPoint`s (breach
  of a door or roller door, rappel through a skylight, an open door). Every ENTRY point on the
  building shell carries the tag `breach_only` (a breach target, never a spawn candidate); ENV A's
  director honours it. Every holdout still has an entry it cannot watch, because the breach comes
  from outside the wall the crew is holding.

### Police entry points (`TacticalPoint`)

| Kind | Where | breachable | Serves |
|---|---|---|---|
| ENTRY | the gate (x 34, z −34); the lane man-gate (x −4, z −34) | man-gate yes | N |
| ENTRY | the Bellweather man-gate (x −8, z −14) | yes | W |
| ENTRY | the gangway W end (x 62, z −13) (`gangway_down`) | — | E |
| ENTRY | the quay steps top (x 57, z 40) | — | S |
| ENTRY | hall roller doors ×3 (N), dock roller door (E) | yes | N, E |
| ENTRY | O1 front door, OC west door, PL west door, MC fire-stair door (+3.6) | yes (lockpick doors) | N, W |
| ENTRY | AN roller doors ×2, AN personnel doors S and E, PK roller and personnel doors | yes | S, E |
| RAPPEL + ENTRY | skylights over C1 (25, 17), SP (33.5, 17) and C2 (41, 17); glass, breakable; rappel drop 8.0 m | yes | Roof |
| FLANK | culvert: the quay outfall (−6, 44) → PL floor grate (2, 15), nav layer `vent` (Phantom only) | — | W/S |
| FLANK | the container alleys (K1–K3 and K4–K6 rows); the lane behind the fire stair | — | yard, lane |
| SHIELD_ANCHOR | the weighbridge (34, −26); outside hall roller door 2 (34, −3); the quay outside AN (36, 36); the lane at the fire stair (−4, 2); the hall floor at the SP mouth (33.5, 9) | — | Bulwark/Aegis formations |
| COVER | ~60 points: container corners, the reach stacker, the weighbridge kerbs, hall pallets, racking ends, AN pallet stacks, QS corners, bollards, net stacks | — | all |

### Specials (P3) and where they come from
- **Phantom** (L4.3): via the **culvert** into PL (behind H1's ST door and next to the lane), and
  via the lane. `cue.phantom_hum` carries through the plant room.
- **Stinger** (L4.4): pairs, preferring the **roof rappel** (into the chambers, the H2 flank) and
  the lane.
- **Bulwark** (L4.5): the wide entries: the gate, the hall roller doors, the AN quay doors. They
  anchor at the SHIELD_ANCHOR points; a Bulwark on the platform stair or in the SP mouth is the
  "block the bag route" moment.
- **Wrecker** (L4.6): vehicle-wide routes only: the gate (P1) and the gangway (P3), so it comes
  through the yard and the hall roller doors, never through the culvert or the lane doors.
- **Corpsman** (L4.8): with any group.
- **Longshot** (L4.7): S1, S2 (always); S3 (`fog_lifts`); S4 (`harbor_unit`).
- **Commander Brandt + Aegis** (L4.9, Lethal+ once per heist): from P1. They take the weighbridge
  anchor and push into the hall. The open yard gives the formation room, and the crew's answer
  is to hold H1/H2 until he retreats.

### Fire shutters (the burn as a level change)
When a burn point finishes (`device_finished(&"thermite")`, QC-38), the mission plays a **warning
cue** (klaxon + Mercer: "Shutters coming down!") and starts a **5 s countdown**; then it **closes and
BARs the burning room's doors** (fire shutters: `door` prefabs locked BARRED at runtime, nav links
off). **D-064 (Q6): the fire damages players** in the burning room's fire volume as damage over time
(fire ignores armour, L3.4). The shutters are the main level change (the fire volume is the reason
not to stay inside):
- `prod_chamber_a` burned: C1's hall, PK and SP doors close. The hall↔PK flank through C1 and the
  C1 rappel route are gone.
- `prod_chamber_b` burned: C2's hall, SP and AN doors close. **H2 loses two entries.**
- `prod_packing` burned: PK's C1 door, roller and personnel doors close (the PL/WS doors from PK
  too). The quay↔lane short cut through the building is gone.
Burning early trades the remaining product bags (greed) for a smaller map.

## Loot path
- **Required** (the escape is called when both are done; **D-064, Q2: approved**): **the burn**
  (thermite on the product room's burn point) **and ≥ 4 bags secured** from cash bricks
  (`loot.cash_bricks`, MEDIUM) and/or weapon crates (`loot.weapon_crate`, HEAVY). Extra bags and
  product (`loot.contraband`) are a bonus: they pay but do not count toward the 4.
- **The thermite bag** (`loot.thermite`, HEAVY, no value, consumed) starts at the crew's spawn (or at a
  `asset.thermite_drop` point) and must be carried to the active burn point. The routes from the
  gate spawn: C1 ≈ 45 m (yard → hall → C1), C2 ≈ 52 m, PK ≈ 60 m (through the hall, OC and WS, or
  round by the lane).
- **Cash, strongroom (SR) →**
  - E3 boat: SR → AN → a quay roller door → quay → ramp → launch (≈ 39 m). **The short one.**
  - E1 van: SR → AN → SP → hall → roller door 2 → yard → weighbridge (≈ 60 m).
  - E2 van: SR → AN → SP → C1 → PK → PL → lane door → E2 (≈ 65 m), or round the quay and the lane (≈ 80 m).
- **Cash, count room (M1) →**
  - E2 van: M1 → MC → ST down → OC → lane door → E2 (≈ 22 m + one storey). **The short one.**
  - E1 van: M1 → **goods lift** (8 s, 2 bags) → hall → roller door → weighbridge (≈ 40 m). With
    `lift_dead`, reset the breaker in E1 (5 s) or carry the bags down ST.
  - **Throw spot:** the PF guard rail → the hall floor (3.6 m drop). It saves the stair; it lands bags in
    the hall's crossfire.
- **Weapon crates (HEAVY: ×0.5 speed, no sprint, jump ×0.5, 2 m throw (D-102)) →**
  - from K1–K3: E1 ≈ 26 m, E2 ≈ 30 m, E3 ≈ 106 m (the lane and the quay);
  - from K4–K6: E1 ≈ 18 m, E3 ≈ 102 m (the apron and the quay; S1 covers the apron).
- **Product →** from its room to the escape, then burn the rest (or burn first and lose it).
- **Optional:** the 3rd/4th bags beyond the required 4, the product bags, the O2 dispatch safe
  (`small_loot` ×3), and `small_loot` cash on desks (O1, O2, M1).
- **Secure zones:** `SECURE_LOOT` at the active escape only: the van's rear doors (E1 weighbridge or
  E2 lane) or the launch's deck (E3). It exists from the start, so bags can be secured before
  the escape arrives (PD2).
- **Bodies:** not used (no BODY_HIDE zones in a loud-only map).

## Objectives
**Loud** (objective_tag in brackets; ENV B reads these, D-039):
1. *(optional)* Thin out the Co-op before the police come. Mercer intro and a Reyes line. `[cartel]`
2. Get into the warehouse: the open door (`warehouse_entry`), lockpick a personnel door (8 s), or
   cut a roller-door padlock (`saw_target` / placed saw 30 s). `[breach]`
3. Find the product (C1, C2 or PK). `[product]`
4. Bring the thermite and burn the product: place the bag on the burn point (3 s) → it burns 30 s
   → fire shutters. `[burn]`
5. Get the cash: the **thermal drill** on the strongroom door (240 s, jams) `[strongroom]` **or** the
   count-room cage (drill 120 s, jams; or C4) `[count_cage]`.
6. Find the weapons: saw the container padlocks (placed saw 45 s, or the hand-held saw via
   `saw_target`); 2 of the 6 containers hold 2 crates each. `[containers]`
7. Secure ≥ 4 bags (cash and/or weapon crates). `[secure]`
8. Hold until the escape arrives (`escape_eta_s` after `[burn]` and `[secure]`). `[escape_wait]`
9. *(optional)* More bags: product, extra cash, extra crates, the dispatch safe.
10. Escape. `[escape]`

**Mission script notes** (`dockside_burn_mission.gd` on `HeistMission`):
- Find prefabs by objective_tag.
- **Police delay:** at start the mission holds the director (QC-35) and starts it after
  `police_delay_s` (timer); the rare `police_tipped` starts it at once.
- **Cartel wake:** ENV A's cartel AI does this (QC-36); the mission only says Mercer's line on the
  first `npc_alerted` of a cartel NPC.
- **Burn:** `device_finished(&"thermite")` → warning cue + Mercer line → 5 s countdown → close and BAR
  the burning room's doors (fire shutters), enable its fire volume (fire DoT, ignores armour; D-064),
  complete `[burn]`.
- **Escape:** when `[burn]` and `[secure]` are done, the active `escape_zone` gets
  `arrival_delay_s = escape_eta_s` (+30 s with `fog_lifts` for the boat) and activates.
- **`cartel_reinforcements`:** a timed NPC spawn at 180 s (QC-25 hook) at the gate.
- **Mercer lines:** intro, cartel awake, police called, breach, product found, thermite reminder,
  burn started / done, strongroom drill started / jam / done, cage drill, lift dead, containers
  hint, weapons found, sniper on the crane / on the roof, gangway, reinforcements, fog lifting,
  required loot secured, escape called / ETA / arrived.

## Variable table
Each variable changes a decision. Rules resolve in this order (heist_map.md §5). Per-difficulty
weights use A2-08 / A3-10 (QC-18).

| variable | options (slot ids) | weights | gameplay effect (the decision it changes) |
|---|---|---|---|
| `guard_post` (cartel posts) | `post_gate`, `post_yard_w`, `post_yard_e`, `post_hall`, `post_platform`, `post_dock`, `post_quay` | 1 each; pick 3 (Routine/Tense), 4 (Hazardous/Brutal), 5 (Lethal), 6 (Cataclysm) via `difficulty_add` | **Where the first fight is and which approach is clean.** A quiet quay makes the pontoon spawn strong; posts on both yard blocks make the gate approach a two-sided fight. |
| `cash_location` | `cash_strongroom` (SR), `cash_countroom` (M1 cage) | 0.6, 0.4 | **Which holdout you hold:** H2 (240 s thermal drill, six entries, short boat route) or H1 (120 s drill, three entries on height, short lane route). |
| `cash_bags` (scalar) | 4, 6, 8 | Routine 0.3/0.5/0.2; Brutal+ 0.2/0.4/0.4 | **Whether cash alone meets the 4 required**, or the crew must also open containers under fire. |
| `weapons_containers` (`loot_spot`) | `k1`, `k2`, `k3` (west block), `k4`, `k5`, `k6` (east block) | 1 each; **pick 2** | **Which side of the yard you work, and how many padlocks you saw before finding them.** The weapons containers carry the Co-op's brass padlock (readable, not signposted); the others have only a customs seal. East-block crates are in S1's lane. |
| `product_location` | `prod_chamber_a` (C1), `prod_chamber_b` (C2), `prod_packing` (PK) | 1, 1, 0.8 | **Where the thermite goes and which part of the map the fire shutters close** (see Loud). C2 next to H2 is the "burn early to shrink the holdout" roll. |
| `product_bags` (scalar) | 4, 6, 8 | uniform | **The greed before the burn:** bag product (time under fire) or burn now. |
| `warehouse_entry` | `door_office` (O1 front door unlocked), `door_quay` (AN S personnel door propped), `door_dock` (the E dock roller door up) | 0.35, 0.35, 0.3 | **The first way in without an 8 s lockpick or a padlock cut**, on the office side, the strongroom side, or the apron (in S1's view). |
| `east_gangway` | `gangway_down`, `gangway_up` | 0.6, 0.4 | **Whether the east is a police direction (P3).** Down: the apron and the dock door are a flank, and E1/K4–K6 get pressure from two sides. Up: P1e and P4 take that weight. |
| `goods_lift` | `lift_powered`, `lift_dead` | 0.6, 0.4; `force_if: [{"if": {"cash_location": ["cash_strongroom"]}, "then": ["lift_powered"]}]` (resolved after `cash_location`) | **How count-room cash comes down:** the lift (8 s, 2 bags), the E1 breaker reset (5 s, in the OC corridor's crossfire), the PF throw, or ST. |
| `player_perch` | `perch_roof` (head-house door unlocked), `perch_stack` (D1 ladder in place), `perch_none` | 0.3, 0.3, 0.4 | **Whether a counter-sniper position exists** for S1/S3 (and where). Forced by `asset.sniper_position`. |
| `escape` | `esc_van_gate` (E1), `esc_van_lane` (E2), `esc_boat` (E3) | 0.4, 0.3, 0.3 | **The whole loot path and the last holdout** (H4, the lane, H3). Strongroom cash + boat or count-room cash + lane = short; the crossed pairs mean a long haul. |
| `night_shift` (scalar) | 1, 2, 3 workers | uniform | **Hostages for the trade and the anticipation bonus**, and civilians in the line of fire (kill penalty). |
| `police_delay_s` (scalar) | 60, 90, 120 | per difficulty (Roster table) | **How much of the cartel fight happens before the police**: on 120 the crew can breach and start a device before the first CONTROL; on 60 the cartel and the first responders overlap. |
| `escape_eta_s` (scalar) | 90, 120, 150 | Routine 0.4/0.4/0.2; Brutal+ 0.2/0.4/0.4 | **How long the final holdout lasts**, which decides whether to secure bags before or during the escape wait. |

## Rare events

| id | good/bad | chance | effect |
|---|---|---|---|
| `informant_tip` | good | 6% | Reyes knows the containers: reveals `weapons_containers` (as `asset.intel_containers`). |
| `extra_container` | good | 5% | A third weapons container: `weapons_containers` picks 3. |
| `police_tipped` | bad | 6% | Someone called it in early: `police_delay_s` = 0 (the director starts at once). |
| `cartel_reinforcements` | bad | 8% (`min_difficulty` Hazardous) | At 180 s a Co-op pickup arrives at the gate with 4 gunmen (timed spawn, QC-25). |
| `fog_lifts` | bad | 10% | The fog thins at 6 min elapsed: the S3 viaduct perch is enabled and the boat ETA is +30 s. |
| `harbor_unit` | bad | 6% (`min_difficulty` Brutal) | A harbour police boat is already moored: P4 is valid from the first CONTROL and the S4 trawler perch is enabled. |

## Escape
- **Van at the gate (E1):** on the weighbridge. Escape type `van`, `arrival_delay_s = escape_eta_s`.
  It leaves at the alarm (the crew's van drops them and pulls out) and returns. SECURE_LOOT at the rear
  doors from the start; ESCAPE zone round the van when it arrives. Last holdout H4.
- **Van in the lane (E2):** by the office block west door (x −4, z 6). Same rules. The lane is S2's
  lane (35 m), and P2 is 43 m up the lane.
- **Boat at the pontoon (E3):** the Co-op's own launch, stolen. Escape type `boat`,
  `arrival_delay_s = escape_eta_s` (+30 s with `fog_lifts`). SECURE_LOOT on its deck; ESCAPE on the
  pontoon and the deck. Last holdout H3.
- **Walk-out:** none.

## Pre-planning (preplanning.md contract, D-046 shape)
`Preplan` points (category; `floor` is the index into `floor_heights`: 0 Landing, 1 Ground,
2 Mezzanine, 3 Roof; point labels are heist-qualified, `ui.preplan.point.dockside_burn.<point_id>`, ENV B B5-04):

| Point | Category | Params / asset |
|---|---|---|
| `pp_spawn_gate` | spawn | default (spawn_tag `""`), Ferro St at the gate (floor 1) |
| `pp_spawn_lane` | spawn | spawn_tag `preplan_spawn_lane` (lane north end) — `asset.alternate_entry` |
| `pp_spawn_pontoon` | spawn | spawn_tag `preplan_spawn_pontoon` (pontoon, floor 0) — `asset.alternate_entry` |
| `pp_drop_gatehouse` | drop_zone | behind GH — `asset.ammo_bag_drop`, `asset.doctor_bag_drop`, new `asset.thermite_drop` |
| `pp_drop_lane` | drop_zone | by the fire stair — ammo, doctor, thermite |
| `pp_drop_quay` | drop_zone | inside QS — ammo, doctor, thermite |
| `pp_drop_platform` | drop_zone | PF (floor 2) — ammo, doctor (no thermite: no bags up the stair before the burn) |
| `pp_escape_gate` | escape | variant_group `escape`, slot `esc_van_gate` — `asset.escape_position` (vote) |
| `pp_escape_lane` | escape | slot `esc_van_lane` |
| `pp_escape_boat` | escape | slot `esc_boat` |
| `pp_perch_roof` | drop_zone | variant_group `player_perch`, slot `perch_roof` (floor 3) — new `asset.sniper_position` |
| `pp_perch_stack` | drop_zone | variant_group `player_perch`, slot `perch_stack` (at D1's foot) — new `asset.sniper_position` |
| `pp_gangway` | insider | variant_group `east_gangway`, slot `gangway_up` — new `asset.gangway_raised` |

`HeistDef.preplanning` (contract v1.0 shape; entry keys are PreplanAssetDef fields; costs are Routine
prices, scaled by `PreplanTweak.cost_mult`; values marked ◇ are my proposals for ENV B/lead):
```gdscript
preplanning = {
    "favors": 5,
    "disable": [&"asset.body_bag_case_drop", &"asset.spare_body_bags",
                &"asset.intel_cameras", &"asset.intel_keycards"],
    "assets": {
        # library assets, limited to this heist's points
        &"asset.ammo_bag_drop": {"point_ids": ["pp_drop_gatehouse", "pp_drop_lane",
                                               "pp_drop_quay", "pp_drop_platform"]},
        &"asset.doctor_bag_drop": {"point_ids": ["pp_drop_gatehouse", "pp_drop_lane",
                                                 "pp_drop_quay", "pp_drop_platform"]},
        # new heist assets (QC-40)
        &"asset.sniper_position": {"effect": &"force_variant", "drop": &"ammo_bag",
                                   "point_ids": ["pp_perch_roof", "pp_perch_stack"],
                                   "exclusive_group": &"player_perch", "max_count": 1,
                                   "cost": 2000, "favors": 2, "tags": [&"loud"]},   # ◇
        &"asset.thermite_drop": {"drop": &"loot.thermite",                 # needs a bag drop kind (QC-40)
                                 "point_ids": ["pp_drop_gatehouse", "pp_drop_lane", "pp_drop_quay"],
                                 "max_count": 1, "cost": 1500, "favors": 1, "tags": [&"loud"]},          # ◇
        &"asset.gangway_raised": {"effect": &"force_variant", "point_ids": ["pp_gangway"],
                                  "max_count": 1, "cost": 2500, "favors": 2, "category": &"access"},  # ◇
        &"asset.intel_containers": {"reveals": [&"weapons_containers"],
                                    "cost": 1500, "favors": 1, "category": &"intel"},                 # ◇
        &"asset.lift_power": {"force_variants": {"goods_lift": [&"lift_powered"]},
                              "cost": 1000, "favors": 1, "category": &"access"},                      # ◇
    },
}
```
Crew assets with no point that stay on: `asset.intel_guard_posts` (it reveals the cartel posts: their slot
group is the standard `guard_post`), `asset.extra_cable_ties` (hostages for trades). The board hides library
assets whose groups do not exist here (cameras, keycards, laptop, gondola, riser) automatically
(QB-53, D-049); `disable` lists the two that would otherwise show (body bags) plus two for clarity.
`asset.escape_position` and `asset.alternate_entry` work from the points' params as on every heist.
Blueprint: `docs/levels/dockside_burn/blueprint.png` from the plan renderer.

## Audio/lighting
- **Palette** (style guide §3): **rust `#7A4A2E`** dominant (corrugated cladding, the containers,
  steel doors and the crane), **concrete `#7D7F7C`** secondary (yard and quay slab, the cold-store floor,
  block walls), **flare orange `#FF6B1A`** accent (hazard beacons, the crane's warning lights, the
  thermite and the burn). Cold-store interiors are frosted off-white insulated panels within the GSR
  luminance cap (≤ 0.85). Wear is **heavy** (style guide §4: docks): rust streaks, frost, fish-scale grime.
- **Time:** 05:10, pre-dawn. The sun is 8° below the horizon to the east (no direct light). The sky
  is a dark blue-grey gradient, lighter in the east. **Volumetric fog** (density tuned to ~150 m
  visibility) lit sodium-orange near the masts.
- **Zones:**
  - yard and quay: 2000 K sodium masts (4 shadowed, the rest unshadowed) and the mural floods;
  - hall: 5000 K high-bay LED, half on;
  - chambers and spine: 6000 K cold LED strips along the aisles, blue-white, frost haze;
  - AN: 5000 K;
  - plant room: 4000 K with green control-panel LEDs;
  - office block: 3500 K panels (break room) and 4000 K (offices); the O2 monitor glow;
  - the strongroom: one caged bulkhead light; the thermal drill's glow while it runs;
  - the burn: flare-orange fire light (an animated OmniLight on a fire-VFX fixture) through the
    shutters' vision slots and the skylights.
  - Every light has a fixture.
- **GI:** VoxelGI for the building interior (ground + mezzanine), ReflectionProbe per room,
  SDFGI off. OccluderInstance3D for the building shell, Bellweather, the Pier 10 stacks and each
  container block.
- **Ambience:** `amb_dockside_fog` (water slap, foghorn every 40–70 s, distant gulls, rigging, the
  condenser drone, the crane's hum), `amb_cold_store` (evaporator fans, compressor thump from PL,
  ice ticks, strip-curtain flutter).
- **Music:** `dockside_burn`, a loud-only track: `stealth` stem unused; `control` (110 BPM, low
  synth ostinato and metallic hits) also plays through the cartel phase; `anticipation` riser;
  `assault` (150 BPM, driving percussion with synthesized container clangs and a fog-horn motif);
  `fade`; `win`/`lose` stingers (audio_cues.md music stems).
- **VO line ids** (`vo.<speaker>.<heist>_<line>`, D-051; ENV B writes the text):
  - **Reyes:** `vo.reyes.briefing_dockside_burn_1..3`, `vo.reyes.dockside_burn_contact_intro`,
    `vo.reyes.dockside_burn_payday`.
  - **Mercer:** `vo.mercer.briefing_dockside_burn_1..2`, `vo.mercer.dockside_burn_intro`,
    `vo.mercer.dockside_burn_cartel_awake`, `vo.mercer.dockside_burn_police_called`,
    `vo.mercer.dockside_burn_breach`, `vo.mercer.dockside_burn_product_found`,
    `vo.mercer.dockside_burn_thermite_reminder`, `vo.mercer.dockside_burn_burn_started`,
    `vo.mercer.dockside_burn_burn_done`, `vo.mercer.dockside_burn_strongroom_drill`,
    `vo.mercer.dockside_burn_drill_jam`, `vo.mercer.dockside_burn_strongroom_open`,
    `vo.mercer.dockside_burn_count_cage`, `vo.mercer.dockside_burn_lift_dead`,
    `vo.mercer.dockside_burn_containers_hint`, `vo.mercer.dockside_burn_weapons_found`,
    `vo.mercer.dockside_burn_sniper_crane`, `vo.mercer.dockside_burn_sniper_roof`,
    `vo.mercer.dockside_burn_gangway`, `vo.mercer.dockside_burn_reinforcements`,
    `vo.mercer.dockside_burn_fog_lifts`, `vo.mercer.dockside_burn_required_secured`,
    `vo.mercer.dockside_burn_van_eta`, `vo.mercer.dockside_burn_boat_eta`,
    `vo.mercer.dockside_burn_escape`.
  - Crew barks reuse the generic `vo.crew.*` set.
- **LUT:** `lut_dockside_burn`: cold blue-grey shadows, sodium-orange highlights, slightly crushed
  blacks in the fog.

## Review shots
`HeistMap.review_cameras` (level_standards §8; JPEG q85, D-038). Each camera is ≥ 0.5 m inside its
room (C1-04 check). There are 26 shots: 1 top-down, 4 exterior, 3 landmarks (covered within those),
1 per major room, the strongroom (vault), and the sniper views.

| Camera | Shows | Covers |
|---|---|---|
| `rc_top_down` | orthographic plan of the whole play space | top-down plan |
| `rc_ext_gate` | from Ferro Street through the gate: weighbridge, GH, the hall roller doors, the **mural** | exterior 1, landmark 1 |
| `rc_ext_yard_east` | from K6 looking E: the apron, the gangway, the **crane** in fog | exterior 2, landmark 2 |
| `rc_ext_quay` | from the pontoon looking N: the quay, QS, the AN/PK doors, the **vapour plumes** | exterior 3, landmark 3 |
| `rc_ext_lane` | from the lane's north end looking S: the fire stair, the Bellweather fence, E2 | exterior 4 |
| `rc_yard_west` | the K1–K3 alleys and D1 with its ladder | yard |
| `rc_gatehouse` | GH interior through to the weighbridge | GH (H4) |
| `rc_hall_platform` | from PF over the hall: the roller doors, the SP strip-curtain glow | H, PF (H1), landmark (spine) |
| `rc_hall_floor` | from the dock door looking W: the platform, its stair, the lift door | H |
| `rc_chamber_a` | C1 down the centre aisle under the skylight | C1 |
| `rc_chamber_b` | C2 down the centre aisle | C2 |
| `rc_spine` | SP from the hall end through both strip curtains | SP |
| `rc_anteroom` | AN from the E door: the vault door, the quay roller doors, pallets | AN (H2) |
| `rc_strongroom` | inside SR: cash pallets, the frosted vault door | SR (vault) |
| `rc_packing` | PK: the packing line and the quay doors | PK |
| `rc_plant` | PL: compressors, the culvert grate | PL |
| `rc_workshop` | WS: forklifts on charge | WS |
| `rc_reception` | O1 | O1 |
| `rc_dispatch` | O2 with the CCTV monitors | O2 (security room) |
| `rc_count_room` | M1 with the cash cage and the lift door | M1 (H1) |
| `rc_break_room` | M2 | M2 |
| `rc_locker_room` | LK | LK |
| `rc_quay_shed` | QS interior looking at the pontoon window | QS (H3) |
| `rc_landing_stage` | from the quay steps down to the stage, the P4 shed, the trawler | X4 |
| `rc_roof_perch` | from the office roof toward the viaduct (S3) | X5, player perch |
| `rc_sniper_crane` | from S1's cab over the yard and apron (what the Longshot sees) | sniper LOS check |

## Budgets
Targets from architecture §10 and D-038 QC-10, checked by the `perf` validator per review camera.

| Budget | Target | Notes |
|---|---|---|
| Draw calls per view | ≤ 2,500 | The worst views are `rc_ext_gate`, `rc_hall_platform` and `rc_sniper_crane`. Containers, pallets, racking, ice bins and bollards are **MultiMeshInstance3D** per kit item. |
| Triangles per view | ≤ 3M (provisional, QC-10) | Racking uses 2 LODs; Pier 10 stacks and the far facades are low-poly LOD dressing. |
| Shadowed lights in any shot | ≤ 8 | 4 sodium masts (yard), 1 per chamber, 1 AN, 1 hall; the rest unshadowed. The fire light is shadowless. |
| Texture memory | ≤ 1.5 GB | The shared library (corrugated steel, concrete, insulated panel, rust trims) covers ~90% of surfaces. |
| NPCs alive | police + cartel ≤ `DifficultyDef.max_active_enemies`, civilians ≤ 3 | D-064 (Q5): the gunmen count against the cap; the director's police quota is reduced by the cartel alive count (ENV A). |
| Fog | one volumetric fog (WorldEnvironment), no per-room FogVolumes | Exteriors only via a height falloff; interiors get a light haze in the chambers. |
| Fire VFX | ≤ 3 GPUParticles3D emitters × 2,000 particles per burning room, 1 OmniLight | Only one room burns per run. |
| **Density (kits)** | hall 0.04–0.08 props/m² (pallet groups by the doors); chambers: racking bays 70–85% filled, aisles clear (3.0 m); AN 0.05–0.10; yard: clutter in clusters at the container ends, the masts and the fence (no uniform scatter); offices/break room per their kit minimums | Same-kit rooms (C1/C2) must differ in layout hash (the `variety` check). |

**Walkthrough whitelist** (level_standards §6): none expected. The longest crew path relative to
its straight line is pontoon → K1 (≈ 102 m for a 75 m straight line, 1.4×).

## HeistDef (proposed data, `dockside_burn_def.tres`)
`id dockside_burn`, display "Dockside Burn", contact `contact.reyes`, mode LOUD_ONLY, base_payout
**$95,000** (D-064, Q7: a placeholder, like the loot values below; ENV B balances them in P6),
loot `[loot.cash_bricks, loot.weapon_crate, loot.contraband]` (the new ids are B to confirm; `loot.thermite` is a
tool bag, not payout loot), escape_options `[van, boat]`, music_track `dockside_burn`, objectives
`[cartel, breach, product, burn, strongroom, count_cage, containers, secure, escape_wait, escape]`,
preplanning as above. Map `game/world/heists/dockside_burn/dockside_burn.tscn`;
`floor_heights [-1.8, 0.0, 3.6, 7.2]`, `floor_names ["Landing", "Ground", "Mezzanine", "Roof"]`.

## Requests (to the lead)
- **QC-35 (ENV A):** a director-start hook for LOUD_ONLY heists. Today `AssaultDirector` begins
  on load when the phase is LOUD. The mission needs to hold it and call `begin()` after
  `police_delay_s` (the cartel phase), e.g. `HeistMission` API `hold_police()` / `start_police()`, or
  a `HeistDef`/DirectorTweak `first_control_delay_s`.
- **QC-36 (ENV A, ENV D):** `enemy.cartel_gunman` (groups.md already reserves the id): EnemyDef + AI
  per L4.10 (no pager, not dominatable, no cuffs, hostile to the crew only). It must **start
  unalerted on GUARD spawns with a PatrolGraph** and wake on gunfire, explosions, sightings or a
  shout. It does not count in `alive_units()` (police). ENV D: the model (Co-op workwear + plate
  carrier, 3 head variants).
- **QC-37 (ENV A):** `saw_target` implementers (D-057). (a) `drill_point` with device SAW and `safe`
  with the `saw` method join the group, so a hand-held saw's `saw_cut(seconds)` advances the placed-saw
  progress. (b) A small **`padlock`** prefab (`saw_target`, bound `targets`, opens a door or roller
  door when cut) for the roller-door chains. Night Deposit and Shadow Ledger G2 are already blocked
  on SAW_TARGET.
- **QC-38 (ENV A):** a **`burn_point`** prefab: it accepts a carried `loot.thermite` bag (place
  3 s, the bag is consumed) and runs `duration_s` (30 s, **no jams**, `device_started/finished`
  kind `&"thermite"`), then enables a child **fire volume**: fire damage per L3.4 (ignores armor,
  DoT ◇ 20/s inside), a nav obstacle, and AI avoidance. Fallback for G1: a `drill_point` THERMAL
  with `duration_s` 30 and no bag (so the greybox mission works) until it exists.
- **QC-39 (ENV B loot/strings):** `loot.weapon_crate` (HEAVY, PD2 weapons-bag value shape ◇ 2,000),
  `loot.contraband` (MEDIUM, ◇ 1,400), `loot.thermite` (HEAVY, value 0, excluded from payout and
  from the `[secure]` count), plus objective strings for the `[tag]`s above and the VO text.
- **QC-40 (ENV B assets):** `asset.sniper_position`, `asset.thermite_drop`, `asset.gangway_raised`,
  `asset.intel_containers` and `asset.lift_power` (shapes above). `asset.thermite_drop` needs a
  **bag drop kind** (`drop` = a loot id: ENV A spawns a loot bag at the point, not a deployable).
- **QC-41 (ENV A):** rappel. One-way `NavigationLink3D`s from the roof POLICE spawns (+9.0) through
  the skylight ENTRY points to the chamber floors (8.0 m), with a rappel animation, so the P5
  island validates as reachable for police. (This is also Night Deposit's P3 skylight.) Validator
  side (mine): the reachability check treats police-only islands as reachable through one-way links.
- **QC-42 (ENV A/lead):** the director treats every ENTRY point as a spawn candidate. Is that
  intended for interior ENTRY points (the AN quay doors, the MC fire-stair door), or should they
  be breach targets only (tag `breach_only`)? The holdout design works with either, but the
  distances above assume the current behaviour.

## Lead rulings (D-064; the G0 open questions, closed)
1. **Cartel phase:** approved. Cartel first; the police come after the rolled `police_delay_s`
   (60/90/120 s; `police_tipped` = 0).
2. **Required loot:** the burn + 4 secured bags (cash and/or weapon crates). Extra bags and product
   are a bonus.
3. **High-bay ceiling override** 6.0–9.0 m for C1, C2, SP: approved. The **`industrial_door`** scale
   rule (2.4–4.0 m wide × 2.1–4.5 m high) is approved and implemented in the validator's scale check.
4. **floor_heights:** keep the −1.8 Landing (the stair-chain rule needs it).
5. **Cataclysm cap:** cartel gunmen count against `DifficultyDef.max_active_enemies`; the director's
   police quota is reduced by the cartel alive count. ENV A enforces it; documented only here.
6. **Fire:** damages players (fire ignores armour) as damage over time inside the fire volume.
   Telegraph: a warning cue, then the shutters drop after a 5 s countdown. The shutters are the main
   level change.
7. **Payout:** $95k base and the loot values are placeholders; ENV B balances them in P6.
8. **Perches:** the two always-on perches (S1, S2) are enough.
- **QC-42:** yes: police never spawn inside the building, only via ENTRY TacticalPoints (breach,
  rappel, doors). Building ENTRY points carry the tag `breach_only`.
- **QC-37:** the map adds the `G.SAW_TARGET` group and saw metadata now on the padlocks and other
  saw-able things; ENV A ships `saw_cut()` later.
- **QC-35/36/38/39/40/41** are routed to ENV A/B/D. Until they ship, the G1 greybox uses placeholders
  that degrade gracefully (each marked with a `TODO(QC-nn)` in the code; listed in
  `docs/levels/dockside_burn/validation.md` notes and the G1 report).
