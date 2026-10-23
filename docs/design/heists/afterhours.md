# Afterhours: the Velvet nightclub (afterhours)
Status: APPROVED (lead, 2026-10-11) (D-075). The lead's answers to the G0 open questions are folded in below (see Lead rulings).
Cross-env requests QC-70..76 are at the end.

## Fiction
- **Who:** **The Velvet**, the busiest late club in midtown, in the shell of the **Ardmore Picture
  House** (1928) on the corner of Marlin Avenue and Tolley Street. The old auditorium is the dance
  hall, the old screen arch frames the DJ stage, and the old dress circle is the VIP balcony. On paper
  the club belongs to the promoter **Anton Crale**. In fact it is the **Ortega Fisheries Co-op**'s
  midtown laundry (the cartel front of Night Deposit and Dockside Burn). The door take and the bar
  receipts wash the Co-op's cash, and the VIP sells its product. The Velvet employs its own **door
  team** of bouncers (radios, no security company). Crale is not in tonight. His office runs itself.
- **What:** after Pier 9 burned, the Co-op moved its **cash float** to Crale's **office safe** (upper
  floor, keycard door, combination lock). Its last **product** is somewhere in the building (sealed
  parcels; where varies). The night's **count** may still be on the tables upstairs.
- **Why / contact (D-075):** **The Accountant** (`contact.accountant`, Board district `midtown`; bank
  and corporate jobs, never seen). Laundering is his trade, and the Velvet is a laundry: *"The Co-op
  washes its money through a dance floor. Door take, bar receipts, bottle service: I've read their
  books, and the numbers dance better than the customers. Since Pier 9 the float sits in Crale's
  safe. Walk in like you came to dance, and bring me the safe."* The Accountant pays for the safe's
  cash; the product and the count are the crew's own greed. He has a bartender on the payroll who
  stashed the crew's gear in the front of house before the doors opened. (Reyes runs Rolling
  Thunder; the Co-op arc's loud jobs stay his.)
- **Time / weather:** Saturday, 00:40, late autumn. The rain stopped an hour ago: wet asphalt and
  sidewalks reflecting the marquee neon, puddles in the alley, no rain falling (atmosphere only, no
  scalar). The club is at peak: a queue on the sidewalk, a full dance floor.
- **Handler:** Mercer on comms. The crew starts **inside, unmasked and without gear** (civilian mode,
  D-065), just past the door in the foyer.

## Modes
- **Stealth + loud** (`HeistDef.mode = STEALTH_OR_LOUD`) with **`start_mode = &"civilian"`**
  (D-065, S1.3). Size M (15–25 min stealth, 15–25 min loud). Phase P5.
- **Three player modes, in order** (ui_hud v1.6 `player_mode_changed`):
  1. **civilian** (start): undetectable everywhere (detection ×0, guards and cameras included); no
     mask, no weapons, no bags. Only interactions with `civilian_allowed = true` work; everything else
     shows `ui.blocked.civilian`. **Laser grids still trip.**
  2. **casing** (after the `gear_pickup`): the S1.1 rules. Civilians never detect you; guards and
     cameras fill at ×0.35 inside RESTRICTED zones or within 3 m of a guard outside PUBLIC. Only
     `casing_allowed` interactions (keycard pickup, code notes, mask up).
  3. **masked**: everything allowed; everyone, including the dance-floor crowd, detects you.
- **What civilian mode is for here:** a risk-free scouting walk of the **front of house** (D-075:
  civilians stay front-of-house). The crew can walk the guest side (foyer, hall, under-circle, WCs,
  the VIP side through the rope gate, the smokers' passage), watch the floor and VIP guards, spot the
  hall cameras, and walk out the front to the alley. They cannot open staff doors or touch anything.
  **The heist starts where the gear is** (`gear_drop`, 4 places, all reachable without a staff
  door): picking it up switches that player to casing on the spot, so the gear's location decides
  where each player becomes detectable.
- **Civilian-allowed set** (ENV C sets `civilian_allowed` per instance; D-075):
  - the `gear_pickup` (true by contract);
  - guest doors with lock NONE: the entrance doors, the hall doors, the patrons' and VIP WC doors,
    the VIP rope gate (a guest door: the VIP side is guest space, RESTRICTED only for casing and
    masked players), and the hall's push-bar fire exits to the smokers' passage.
  - **Not staff doors**, locked or not: the east bar service door, the backstage door, the box-office
    staff flap, the VIP staff door, the G13 push-bar doors and the staff entrance. Behind them is
    casing or masked work.
  - Nothing else: no keycards, notes, small loot, lockpicks, windows, ladders.
- **Stealth:** the front of house (sidewalk, foyer, hall, under-circle, WCs, smokers' passage) is
  **PUBLIC** and packed with civilians. The back of house, the stage, the VIP side (balcony, VIP
  lounge) and the whole upper staff wing are **RESTRICTED**. **Masking in front of the crowd is
  suicide** (40+ civilian observers). The job is done masked in the back of house and the upper
  wing, unmasked (casing) everywhere in public. The safe opens with the **combination** (code note) or
  a **drill**. The office door needs the **keycard**. Required: **3 bags of the Co-op's cash.**
- **Loud:** the alarm cuts the music and brings the house lights up. The crowd **stampedes** for the
  exits (main doors, the west fire exits), and the safe's keypad goes dead (lockdown), so the safe
  needs the **drill** (120 s, jams) or C4. The crew holds the office suite, then moves bags down the
  staff stair to the van while the police come in through the emptied club.
- **The music does not hide noise.** S4.3 is a hard rule: drills, saws, glass and unsuppressed shots
  carry their full radius under the club music. Diegetic music is atmosphere only.
- **Difficulty notes:**
  - Routine/Tense: 3 bouncers (door, VIP rope, 1 rover) + operator (60%); patrons 12–14 + 4 dancer
    clusters.
  - Hazardous/Brutal: 4 bouncers (2 rovers) + operator (75%); 16–18 patrons + 5 clusters; sweeping
    lasers more likely; `co_op_pickup` (Brutal+).
  - Lethal/Cataclysm: 5 bouncers (3 rovers); 20 patrons + 6 clusters; Titan cameras.
  - **The door bouncer is effectively untouchable** (he stands among the queue on a PUBLIC sidewalk),
    so the pager budget is spent on the rest. From Hazardous up the guards exceed the pager cap:
    ghost at least one rover (see Stealth routes).
  - **Solo with AI** (D-014): AI teammates start at the van (`esc_*` slot) and wait there in stealth.
    The civilian start, the gear and the masked work are the human players' job. Nothing in the
    design assumes one player: every crew member uses the same `gear_pickup`.

## Site
- **Lot:** 36 × 28 m (wall centre lines; outer face 36.4 × 28.4 m), corner lot. Ground FFL = 0.0 m;
  upper FFL = +4.2 m. Massing:
  - **auditorium** (hall, x 0–26, z 7–21): one tall volume, roof +8.8, parapet +9.8;
  - **front block** (x 0–26, z 21–28) and **east wing** (x 26–36, z 7–28): two storeys, roof +8.0,
    parapet +9.0;
  - **back-of-house strip** (x 0–36, z 0–7): single storey, flat roof at **+4.2** with a 1.1 m
    parapet (the BOH roof, reachable; see Stealth routes).
- **Streets:**
  - **Marlin Avenue** (south): 4 lanes, 14 m carriageway (z 32–46), 4 m sidewalk (z 28–32) with the
    queue barriers and a red runner under the marquee.
  - **Tolley Street** (east): 2 lanes plus parking, 8 m carriageway (x 38–46), 2 m sidewalks.
  - **Lamplighter Lane** (north): the 6 m service alley (z −6…0), one-way W→E, dumpsters, the loading
    door, a drop ladder to the BOH roof.
  - **The smokers' passage** (west): a 3 m gated side passage (x −3…0) between the Velvet and the
    Hallam warehouse wall. The hall's fire exits open into it. Its south end on Marlin Ave is a roped
    smokers' area (PUBLIC); its north gate to the alley is the `side_gate` variable.
- **Neighbours** (dressing except where stated):
  - west, behind the passage: **Hallam Furniture** (closed warehouse; blank brick wall, no openings);
  - north, across the alley: **Keston Row** tenement backs (fenced yards, fire escapes, lit kitchen
    windows); its roof parapet is the rare sniper perch **S3**;
  - east, across Tolley St: a 4-storey office building (dark, lobby lit); its roof is perch **S2**;
  - south, across Marlin Ave: the **Corliss Hotel** (roof perch **S1**), an all-night diner and
    apartments.
- **Exterior landmarks:**
  1. the **marquee**: the picture house's triangular canopy, re-lettered **VELVET** in magenta neon,
     with chaser bulbs, over the entrance and the queue (visible from both streets);
  2. the **vertical blade sign** on the corner (old ARDMORE letters dark, a new VELVET script lit)
     rising past the roofline, visible from Tolley St and the alley mouth;
  3. **inside: the gilded proscenium arch** (the old screen arch, 14 m wide) framing the DJ stage, and
     the **mirror ball** over the dance floor; both are seen from the foyer doors, the bars, the
     balcony and the BOH stage door. The **balcony's curved brass rail** is the third read.
- **Play space:** x −20…+64, z −24…+56. Each edge is closed as follows (the `bounds` validator checks
  every one).

### Play-space closure

| Edge | Closure |
|---|---|
| Alley, west end (x −12) | A 2.4 m chained steel gate between the Hallam back wall and the Keston Row yard wall; a dumpster and a parked delivery trike behind it. The **P4** spawn is behind the gate (x −18). |
| Alley, Tolley St mouth (x 36–38) | Open to Tolley St (it is the alley exit). |
| Alley, north side (z −6) | Keston Row backs: continuous 3-storey facades, 2.2 m yard fences, fire escapes (dressing, not climbable). |
| Tolley St, north (z −24) | A **parked refuse truck across both lanes** plus barriers; the **P3** spawn is behind it (x 42, z −22). Beyond: the street continues as a vista to a facade across the axis at z −60. |
| Tolley St, east side (x 46…64) | The office building and its neighbours (4–6 storeys), lobbies lit, no openings at street level except a locked lobby door. |
| Marlin Ave, west end (x −20) | Road-works fence across sidewalk and carriageway, a parked works van; the **P1** spawn beyond. Vista: facades to x −60, then a bend. |
| Marlin Ave, east end (x 64) | A stopped night bus across the far lanes plus barriers at the Tolley junction's far side; the **P2** spawn beyond. Vista to a T-junction facade at x 110. |
| South (z 48…56) | Hotel, diner and apartment facades (3–6 storeys), the hotel canopy lit. |
| Smokers' passage | South end: a 1.1 m rope barrier and the open gate (PUBLIC); north end: the `side_gate` (2.2 m steel, chained or open). Walls on both sides are 6–9 m blank brick. |
| BOH roof (+4.2) | 1.1 m parapet on its north (alley) edge with the drop-ladder hoops at x 30; the hall's north wall (to +9.8) and the east wing (to +9.0) close it on the south and east; the west end is the Hallam wall (+8.0). |
| Up | Overcast night sky lit orange from below, wet. Every visible roof has a parapet and plant. |

### Site plan
1 char = 2 m (x, the ruler marks x −20…60), 1 row = 2 m (z). Same origin and axes as the floor plans (the Velvet's NW corner;
+x east, +z south). `#` the Velvet, `%` neighbours, `|` Tolley St kerbs, `_` Marlin Ave kerbs,
`:` the smokers' passage (and `::::` the refuse truck across Tolley St, z −18), `g` its gates, `D` hall fire exits, `X` the alley west gate, `R` loading
roller door, `F` drop ladder (alley → BOH roof), `d` staff door (Tolley St), `N` the marquee, `G` the
door bouncer, `q` the queue, `s` smokers, `P` the queue-side casing area (the crew spawns inside, see
the ground plan), `v` van footprints (`E1` alley, `E2` Tolley St), `[BH]` dumpsters (BODY_HIDE),
`P1…P4` police spawn groups, `S1…S3` sniper perches.

```
      x -20       0         20        40        60
   -24  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%|   |%%%%%%%%
   -22  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%|P3 |%%%%%%%%
   -20  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%|   |%%%%%%%%
   -18  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%|::::%%%%%%%%
   -16  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%|   |%%%%%%%%
   -14  %%%KESTON ROW BACKS (S3)%%%%%|   |%%%%%%%%
   -12  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%|   |%%%%%%%%
   -10  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%|   |%%%%%%%%
    -8  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%|   |%%%%%%%%
    -6  %%%%%%%% g                   |   |%%%%%%%%
    -4  %P4%X%LAMPLIGHTER LN -> vvvvv|   |%%%%%%%%
    -2  %%%%X%%% :  [BH]    [BH]vE1vv|   |%%%%%%%%
     0  %%%%%%%% :###############FR# |   |%%%%%%%%
     2  %%%%%%%% :#                # |   |%%%%%%%%
     4  %%%%%%%% :#                # |   |%S2%%%%%
     6  %%%%%%%% :#                # |TOLLEY%%%%%%
     8  %%%%%%%% D#                # |ST |%OFFICES
    10  %HALLAM% :#  THE VELVET    # |   |%%%%%%%%
    12  %FURNITURE#                # |   |%%%%%%%%
    14  %%%%%%%% :#  36 x 28 m     #d|vvv|%%%%%%%%
    16  %%%%%%%% :#                # |vE2|%%%%%%%%
    18  %%%%%%%% D#  (floor plans) # |vvv|%%%%%%%%
    20  %%%%%%%% :#                # |   |%%%%%%%%
    22  %%%%%%%% :#                # |   |%%%%%%%%
    24  %%%%%%%% s#                # |   |%%%%%%%%
    26  %%%%%%%% s################## |   |%%%%%%%%
    28  _________g_____NNNNNNNNNNNN__+___+________
    30               GqqqPPPP        |   |
    32                               |   |
    34                               |   |
    36                               |   |
    38             MARLIN AVENUE (4 lanes) ->
    40  P1                           |   |    P2
    42                               |   |
    44                               |   |
    46  _____________________________+___+________
    48  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    50  %%HOTEL S1%%%%%DINER + APARTMENTS%%%%%%%%%
    52  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    54  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
```

## Floor plans
1 char = 1 m. Each character is a **grid point** (x = col, z = row). Lines are **wall centre
lines**: exterior 0.4 m, interior 0.2 m (the hall's walls are 0.4 m: the old auditorium). Origin is
the NW corner; +x is east and +z is south (the alley is at the top, Marlin Ave at the bottom).
Rulers are in metres. The plans were drawn from room rectangles (in metres) that tile the footprint
exactly; at G1 they become `tools/levelcheck/plans/afterhours_floors_ascii.py` with the same
`--check` mode as the other heists (tiling, doors on walls, every room has a door, stair
arithmetic).

Legend: `#` exterior wall, `|`/`-` interior wall, `+` junction, `D` door (doors drawn on a wall
line; `DD` = double door), `R` roller door, `W` window, `m` **one-way mirror** (count room → hall),
`p` projection ports (security room → hall), `=` bar counter (in G2/U2: the box-office and VIP-bar
counters), `:`/`_` the DJ stage riser edge (0.3 m, one step), `(*)` mirror ball, `(DJ)` DJ booth,
`r` the balcony guard (1.05 m), `.` (upper) the hall void, `,` the BOH roof (+4.2), `^ v` U-stair
(up-flight, return flight), `=` in a stair: the void over the arriving flight, `G` guard post /
pause point, `K` keycard slot, `c` code-note slot, `g` gear slot, `L` loot, `S` safe, `~` laser
grid, `Mo` camera-station monitor wall + operator seat, `P` player spawns, `F` drop-ladder top.
Cameras are listed with coordinates under Sightlines (not drawn, to keep the plans readable).
G20 is the 2 m corridor x 26–28, z 7–21 (the `G` in it is the BOH rover's pause point).

**Vertical data** (`HeistMap.floor_heights = [0.0, 4.2]`, `floor_names = ["Ground", "Balcony"]`,
D-054; ascending and containing 0.0, D-040):

| Level | FFL | Ceiling | Floor-to-floor / slab | Notes |
|---|---|---|---|---|
| Ground | 0.0 | **8.0 hall G6** (`hall`, D-075, below); 3.6 under-circle G7, foyer G1, box office G2, loading G21; 3.0 BOH, WCs, offices | 4.2 (0.6 slab under the upper floor; BOH ceilings 3.0 + 1.2 plenum to the BOH roof slab at +4.2) | hall 6–9 ✓ (D-075); lobby/bar 3.0–4.5 ✓; office/BOH 2.6–3.0 ✓; loading 3.5–6.0 ✓ |
| Balcony (upper) | 4.2 | balcony U1 open to the hall ceiling (3.8 clear); VIP lounge U2 3.2; staff wing, U4, U5 3.0 | roof slab top +8.0 (0.6–0.8 plenum + slab) | bar 3.0–4.5 ✓; office 2.6–3.0 ✓ |
| BOH roof | 4.2 | open (exterior) | — | parapet 1.1 m; same level as the upper floor (no stair) |
| DJ stage | +0.3 | — | one 0.3 m step (walkable max climb, heist_map §3), not a stair | no railing needed (≤ 0.3 m drop) |
| Grand stair G8 | 0.0 → 4.2 | U-stair, 2 flights × 12 risers @ 0.175 m, tread 0.28 m (run 3.36 m), **flight width 1.5 m** (public), half landing 1.5 m at the north end, floor landings at the south end | 24 risers = 4.2 ✓ | landing every 12 ≤ 16 ✓; flights side by side, headroom ≥ 2.1 ✓ |
| Staff stair G22 | 0.0 → 4.2 | U-stair, 2 flights × 12 risers @ 0.175 m, tread 0.28 m, width 1.2 m, half landing 1.3 m at the north end, floor landings at the south end | 24 risers = 4.2 ✓ | landing every 12 ≤ 16 ✓ |

**Stair core fit.**
- **G8** (4 × 7 m centre lines, 0.3 m walls → 3.7 × 6.7 m clear): flights 1.5 + 0.2 well + 1.5 =
  3.2 ≤ 3.7 ✓. Along z: half landing 1.5 + run 3.36 + floor landing 1.84 = 6.7 ✓. The ground foot
  opens east to the foyer through a 2 m opening (z 26–28); the top landing's door is the **VIP rope
  gate** east into U2 at (10, 27).
- **G22** (3 × 7 m → 2.7 × 6.7 m clear): flights 1.2 + 0.2 + 1.2 = 2.6 ≤ 2.7 ✓. Along z: 1.3 + 3.36
  + 2.04 = 6.7 ✓. The doors (1.0 m) are on the south floor landings: ground → G25 at (34, 14), upper
  → U6 at (34, 14).

**Handrails and guards (QC-33, D-054).** Handrails are 1.0 m on both sides of every flight (inside the
1.0–1.1 m band). Open sides and edges get guards with a top ≥ 1.0 m: the **balcony front** (z 15,
x 0–26: 1.05 m, glass infill under the original curved brass rail, which is the handrail), the
grand-stair well (1.05 m), and the BOH roof parapet (1.1 m, which is the guard; no extra rail, as
QC-34). The stage riser (0.3 m) needs none.

**Ceiling band (D-075: no override).** The §2.6 table caps `bar` (and `lobby`) at 4.5 m. **G6, the
main hall, uses the new purpose `hall` (6.0–9.0 m)** that the lead added to the validator's scale
table (design value 8.0 m). Reason: it is the
1928 picture-house auditorium. The original volume was sized for sightlines from the dress circle
(+4.2) over the stalls to the screen; the circle needs ≥ 3.4 m over its rear rows, and the club's
lighting truss hangs at 6.5 m under the plaster coffers. The hall's double height is also what makes
the balcony a holdout and a casing view. Every other room is inside its purpose's band (G7, U1 and U2
are `bar` at 3.6 / 3.8 / 3.2 m).

### Ground floor (FFL 0.0)
```
      0         1         2         3      
      0123456789012345678901234567890123456
   0  #########WW#####WW###########RRR##D##
   1  #L L L  |     |     |    |ED        #
   2  # G10   |G11  |G12  |G14 +-+ G21    #
   3  # STOCK |GREEN|STAFF|LKR |J| LOADING#
   4  #       | g L |K c  | g  | |        #
   5  #---D---+--D--+--D--+-D--+D+---D----#
   6  D  G13 BACK CORRIDOR   G            D
   7  #------------D------------+ +----+--#
   8  D      :   (DJ) K  :    = | |G23 |^v#
   9  #      :  STAGE    :    = | |BAR |^v#
  10  # =    _____________    = | D    |^v#
  11  # =                     = D |STORE^v#
  12  # = G6                G = |G|    |  #
  13  # =         (*)         = | |    |  #
  14  # =                     = | +----+D-#
  15  # =. . . . . . . . . . . .| DG25    D
  16  # =      DANCE FLOOR      | |STAFF  #
  17  # =                       | +---D---#
  18  #                         | |G24    #
  19  D   G7 UNDER-CIRCLE       | |BOUNC. W
  20  #                         | | K c   W
  21  #D-+D-+---+-DD-----DD-+---+D+--+-D--#
  22  #  |  |^ v|           |   |    |    #
  23  #3a|3b|^ v|  G1 FOYER =G2 |G26 |G27 W
  24  #  |  |^ v|           =   D    |    W
  25  #  |  |^ v|           =   |    |    W
  26  #  |  |               |g  | S  |    #
  27  #  |  |        P P P PD   |    |    #
  28  ###########W##DD#DD##W###############
```

Ground notes:
- **G6 / G7** are one open space: the circle front at z 15 (drawn `. . .`) is the soffit line, not a
  wall. G6 is double height (8.0); G7 sits under the balcony (3.6). They are two RoomVolumes.
- The **stage** (x 7–19, z 7–10, +0.3) holds the DJ booth (1.0 m deck), speaker stacks either side,
  and the backstage door (13, 7) into G13. `kc_dj_booth` is the `K` beside the decks.
- **Main bar** (west wall, x 2, z 10–17): 1.05 m bar top, 0.6 m back bar, 1.0 m clear staff aisle;
  bar flap at z 18. **East bar** (x 24, z 8–14): the same, with its **service door (26, 11)** into
  G20: the classic staff route.
- Fire exits: two push-bar doors in the hall's west wall (0, 8) and (0, 19) to the smokers' passage;
  G13 has push-bar doors at both ends (0, 6) and (36, 6).
- The **G10 stock cage** (`L L L`, x 1–5, z 1) is a 4 × 1.5 m steel mesh cage on the north wall
  (padlocked gate: lockpick 8 s or saw).
- G16 (electrical, `E`) opens into the loading bay G21 at (27, 1).

### Balcony floor (FFL 4.2)
```
      0         1         2         3      
      0123456789012345678901234567890123456
   0  ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,F,,,,,,
   1  ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,|,,,,,,
   2  ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
   3  ,,,,BOH ROOF +4.2 (single storey),,,,
   4  ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
   5  ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
   6  ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
   7  ..........................###WWW#####
   8  ..........................#      |=v#
   9  ..........................m U10  |=v#
  10  ....HALL VOID (+8.0)......m COUNT|=v#
  11  ..........................m      |=v#
  12  ..........................m L L c|  #
  13  ..........................#      |  #
  14  ..........................#---D--+D-#
  15  #rrrrrrrrrrrrrrrrrrrrrrrrr+   U6  G #
  16  #                         + +-------#
  17  #             G           | |  c    W
  18  # U1 BALCONY              D D U9    W
  19  #                         | |    S  W
  20  #                         | |       W
  21  #D-+D-+---+-   ---   -+p-p+ +---D---#
  22  #  |  |= v|           |   | |~~~~~~ W
  23  #4a|4b|= v|           |U5 | |       W
  24  #  |  |= v| U2 VIP    |SEC| | U12 L #
  25  #  |  |= v| LOUNGE    |   | +-------#
  26  #  |  | G |           |   D D U13   #
  27  #  |  |   D=====K=====|Mo | |       #
  28  ############WWW##WWW#################
```

Upper notes:
- **U1** is the old dress circle (flat-floored in the conversion): VIP booths along the brass rail,
  facing the stage. It opens south into **U2** through two 3 m openings (x 12–14 and 18–20).
- **U8** (the stair top, x 6–10) is a landing: the VIP **rope gate** (10, 27) is a 1.0 m `door`,
  lock NONE, `civilian_allowed`, with the `post_rope` bouncer (`G`) beside it.
- **U5**, the projection box, is the **security room**: the camera station's monitor wall `Mo` is on
  the solid south wall; the operator faces south, with his back to the two projection ports `p`
  (0.4 × 0.3 m glazed slots at 1.5 m) that look north over the balcony into the hall. Door from U6b
  (26, 26) only.
- **U10** (count room) has a one-way mirror `m` over the hall (x 26, z 9–12, sill 0.9) and a north
  window (z 7, x 29–31, sill 0.9) onto the BOH roof.
- **U6 / U6b** is one L-shaped staff corridor (two RoomVolumes). The **VIP staff door** (26, 18)
  links the balcony's east end to U6b (LOCKPICK, NPC-authorised).
- **U9**, Crale's office: the **keycard door** (28, 18), the **safe** `S` (LARGE, against the internal
  south wall), the desk (`c` = `code_office_blotter`), windows east to Tolley St. **U12** (his private
  room) opens only from U9 (32, 21); the laser grid `~` runs across it in front of the shelving.

## Room list
Sizes are between wall centre lines. Clear size = minus 0.1–0.2 m per side. Kits marked ◇ are new
club kits (ENV C builds them with the G1/G2 work).

| id | purpose (`RoomVolume.purpose`) | size m | ceiling m | kit | notes |
|---|---|---|---|---|---|
| G1 | lobby (foyer) | 12 × 7 | 3.6 | `club_foyer` ◇ | Two double entrance doors (1.8 m) to Marlin Ave, two curtained double doors into the hall (z 21). Terrazzo floor with the old ARDMORE mosaic, poster cases (`W` at x 11, 21), velvet ropes, a bench. **Default player spawn** (`P`). PUBLIC. |
| G2 | reception (box office + cloakroom) | 4 × 7 | 3.6 | `club_box_office` ◇ | Counter (1.05 m) on the foyer side with cash window; coat rails; ticket stubs. Door (22, 27) from the foyer (staff flap, not `civilian_allowed`) and (26, 24) to G26. `gear_cloak` slot: a checked holdall on the counter's cloakroom hatch, taken **across the counter from the foyer** (no door). RESTRICTED behind the counter. |
| G3a, G3b | restroom (patrons) | 3 × 7 each | 3.0 | `restroom_multi` ◇ | 3 cubicles + basin row each. Doors from G7. PUBLIC. `gear_wc`: a holdall in the end cubicle's duct panel in G3b. |
| G6 | hall (main hall: stage + dance floor; D-075) | 26 × 8 | **8.0** (`hall` 6.0–9.0) | `club_hall` ◇ | Stage riser, DJ booth, speaker stacks, LED dance floor (12 × 6 under the mirror ball), lighting truss at 6.5 m, east bar. Fire exit (0, 8). PUBLIC (stage RESTRICTED). |
| G7 | bar (under-circle lounge) | 26 × 6 | 3.6 | `club_lounge` ◇ | Booths with banquettes, high tables, the south end of the main bar, cigarette-machine alcove. Fire exit (0, 19). PUBLIC. `gear_booth`: a holdall under the banquette of the reserved corner booth (east end). |
| G8 | stair (grand stair) | 4 × 7 | open | — | Public U-stair to the VIP side (vertical data). |
| G10 | storage (bar stock) | 8 × 5 | 3.0 | `storage_bar_stock` ◇ | Spirits and mixer shelving, crates, the **steel stock cage** (`prod_stock`). Door to G13. |
| G11 | staff_room (green room) | 6 × 5 | 3.0 | `green_room` ◇ | DJs' room: sofa, mirror with bulbs, rider table, flight cases (`prod_green`). High window N. |
| G12 | break_room (staff room) | 6 × 5 | 3.0 | `break_room` | Fridge, counter + sink, coffee, microwave, table + 4 chairs, rota board (`code_staff_board`), key hooks (`kc_staff_room`). High window N. |
| G13 | corridor (back corridor) | 36 × 2 | 3.0 | `corridor_service` | BOH spine: keg trolleys, stacked crates (cover). Push-bar doors at both ends (passage, Tolley St). Backstage door to the stage. |
| G14 | locker_room (with staff WCs) | 5 × 5 | 3.0 | `locker_room` | Staff lockers, bench, 2 WC cubicles, sink. |
| G15 | janitor | 2 × 3 | 3.0 | `janitor_closet` | Mop sink, cart, chemicals. **BODY_HIDE** (1). |
| G16 | electrical | 2 × 2 | 3.0 | `electrical_closet` | Main board, the club's sound/light dimmer racks, telecom. Door from G21. |
| G20 | corridor (east corridor) | 2 × 14 | 3.0 | `corridor_service` | Behind the east bar; links G13, G23, G25, G26. |
| G21 | loading (bar deliveries) | 9 × 5 | 3.6 | `loading_bar` ◇ | Roller door (3.0 × 3.0, alley), personnel door N (`rear_door` variable), keg racks, bottle-bank bins, a hand truck. |
| G22 | stair (staff stair) | 3 × 7 | open | — | Ground ↔ upper staff wing. |
| G23 | storage (bar store / ice room) | 5 × 7 | 3.0 | `storage_ice` ◇ | Ice machines, glass-wash, bar-back shelving, CO₂ cylinders. |
| G24 | staff_room (door team room) | 8 × 4 | 3.0 | `door_team_room` ◇ | Radio chargers, lockers, first-aid, the **key board** (`kc_bouncer_board`) and the door log (`code_bouncer_log`). Windows E. |
| G25 | lobby (staff entrance) | 8 × 3 | 3.0 | `staff_entrance` ◇ | Staff door to Tolley St (36, 15) (`d` on the site plan; LOCKPICK from outside, NPC-authorised; push bar inside, `one_way`), clock-in terminal, notice board. Stair door. |
| G26 | cash_office (door office) | 5 × 7 | 3.0 | `count_room` | The door take: a **drop safe** (`safe` SMALL, `methods [drill, saw]`, `small_loot` ×3), till trays. Door from G20 and G2. |
| G27 | storage (event stock) | 5 × 7 | 3.0 | `storage_supplies` | Merch boxes, spare furniture, banners. **BODY_HIDE** (2). Windows E (frosted). |
| U1 | bar (VIP balcony) | 26 × 6 | 3.8 (under the hall ceiling) | `vip_balcony` ◇ | Booths along the 1.05 m brass rail, bottle-service tables, the VIP staff door at the east end. RESTRICTED (VIP). |
| U2 | bar (VIP lounge) | 12 × 7 | 3.2 | `vip_lounge` ◇ | VIP bar on the south wall (1.05 m; `kc_vip_bar` behind the register), sofas, a mirrored wall, windows over the marquee. RESTRICTED (VIP). |
| U4a, U4b | restroom (VIP) | 3 × 7 each | 3.0 | `restroom_multi` ◇ | 2 cubicles + basins each, over G3 (plumbing stacks). Doors from U1. |
| U5 | security_room (projection box) | 4 × 7 | 3.0 | `security_office` | The camera station on the south wall, operator seat facing south, the projection ports behind him, an old projector kept as dressing, key cabinet (dressing). |
| U6, U6b | corridor (staff wing) | 10 × 2 + 2 × 12 | 3.0 | `corridor_office` | L-shaped: stair door, count room, office (keycard door), VIP staff door, projection box, staff WC. |
| U7 | stair | 3 × 7 | open | — | Top of the staff stair. |
| U9 | manager_office (Crale's office) | 8 × 5 | 3.0 | `office_manager` | Desk (`code_office_blotter`), leather sofa, drinks cabinet, CCTV repeater (dressing), **the safe** (LARGE, `methods [code, drill, c4]`). Windows E (sill 0.9). |
| U10 | cash_office (count room) | 7 × 7 | 3.0 | `count_room` | Counting tables, note counters, vacuum sealer, whiteboard (`code_count_board`), desk (`kc_count_room`), `count_running` cash. One-way mirror W, window N (`open_window`). Door LOCKPICK (NPC-authorised). |
| U12 | living_room (Crale's private room) | 8 × 4 | 3.0 | `private_lounge` ◇ | Day bed, wardrobe, shelving with locked boxes (`prod_private`), the **laser grid** across the room. Window E. |
| U13 | restroom (staff, upper) | 8 × 3 | 3.0 | `restroom_multi` ◇ | 2 cubicles, basins, a cleaner's cupboard. |
| X1 | exterior (alley + BOH roof) | 56 × 6 (+ roof 36 × 7) | — | `exterior_alley` | Dumpsters ×2 (`body_container`), the van slot E1, drop ladder, HVAC condensers on the roof. |
| X2 | exterior (streets + passage) | — | — | `exterior_street` | Marquee, queue barriers, the blade sign, street lights (LED 4000 K), parked cars, van slot E2, the smokers' passage. |

Support-space check (level_standards §2.2):
- restrooms: patrons G3a/b and VIP U4a/b (each a men's/women's pair), staff G14 and U13 ✓;
- break room G12 ✓; janitor G15 ✓; electrical G16 ✓ (IT/CCTV in U5 ✓);
- loading/back entrance G21 + staff entrance G25 ✓;
- 2 floors: two stair cores (G8 public, G22 staff) ✓; fire exits: the hall (×2) to the passage, G13
  at both ends, the main doors; longest travel ≈ 30 m (U12 → U6 → G22 → G25 staff door) ✓.

## Circulation
- **Public:** Marlin Ave queue → door check (`post_door`) → G1 foyer → G7/G6 (bars, dance floor,
  booths, WCs) → the hall fire exits to the smokers' passage (patrons smoke there and come back).
  VIP patrons go G1 → G8 → rope gate → U2/U1.
- **Staff:** bartenders G6/G7 bars ↔ east bar door → G20 → G23 (ice) / G13 → G10 (stock) / G12 (break)
  / G14 (lockers). The box office G2 ↔ G26. The VIP bartender U2 ↔ VIP staff door → U6b → G22 →
  G23. The DJ: stage ↔ backstage door ↔ G11. Deliveries: alley → G21.
- **Guards (PatrolGraphs, heist_map §4; ≥ 3 loops per post on shared graphs):**
  - `foh` (`rover_floor`): G1 → hall doors → west bar → stage front (pause: faces the crowd) → east
    bar (pause `G`, 15 s) → G7 booths → WCs → G1. Loops: (a) G1 → G7 → G1; (b) G7 → west bar →
    stage → east bar → G7; (c) G6 → east bar door → G20 → G13 → stage door → stage → G6 (he checks
    the back on loop c). It links to `boh` through the east bar door and the stage door.
  - `boh` (`rover_boh`): G13 west end → G10 → G13 mid (pause `G`) → G11/G12 doors → G13 east → G21 →
    G20 (pause `G`) → G25 → G24 → G25 → G20 → G13. Loops: (a) G13 → G10 → G13 → G12; (b) G13 → G21 →
    G13; (c) G13 → G20 → G25 → G24 → G25 → G20 → G13. Stair points join `upper`.
  - `upper` (`rover_upper`): U6 east (pause `G`) → U10 door → U6b → office door → VIP staff door →
    balcony (pause `G` at the rail, 10 s) → U2 → U1 → staff door → U6b south → U5 door → U13 → U6b →
    U6. Loops: (a) U6 → U10 → U6 → U6b → U6; (b) U6b → VIP door → U1 → U2 → U1 → U6b; (c) U6b → U5
    → U13 → U6b → stair → G25 → G20 → G25 → stair.
  - `alley` (`alley_smoker`): G21 personnel door ↔ dumpsters ↔ drop ladder ↔ alley mouth (pause
    `smoke` 20–40 s).
  - Fixed posts: `post_door` (sidewalk at the rope, `bouncer_idle`, faces the street, turns to the
    doors every 30–45 s) and `post_rope` (U8 stair top, `bouncer_idle`).
- **Civilian flows:** patrons wander `civilian` points (bars, booths, WCs, foyer, passage, dance-floor
  edge). Dancers stay in their clusters. Bartenders hold `staff_bar` points and make stock runs
  (one bartender every 60–90 s: east bar → G20 → G23 → back; 20–30 s). Under `count_running` a
  bartender (the counter) sits in U10 and takes a WC break every 90–120 s (U13).

### Staff, civilian and guard roster (spawn data)
Character ids are ENV D's `p5_cast.json` roles (`afterhours`): `club_bouncer`, `club_bartender`,
`club_dj`, `club_patron`. Ambient clips per characters.md v1.9 (D3-02).

| NPC | Role (D's ids) | Count | Presence | Spawn tags | Idle activity | PatrolPoint tags |
|---|---|---|---|---|---|---|
| Door bouncer | `club_bouncer` | 1 | always (fixed GUARD) | `guard_door` | `bouncer_idle` | — (post) |
| Rope bouncer | `club_bouncer_b` | 1 | always (fixed GUARD) | `guard_rope` | `bouncer_idle` | `guard_rope` |
| Floor bouncer | `club_bouncer` | 0–1 | `guard_post` = `rover_floor` | `guard_floor` | — | `guard`, `guard_foh` |
| BOH bouncer | `club_bouncer_b` | 0–1 | `rover_boh` | `guard_boh` | — | `guard`, `guard_boh` |
| Upper bouncer | `club_bouncer` | 0–1 | `rover_upper` | `guard_upper` | — | `guard`, `guard_upper` |
| Alley smoker | `club_bouncer_b` | 0–1 | `alley_smoker` | `guard_alley` | — (pause `smoke`) | `guard_alley` |
| Camera operator | `club_bouncer_b` | 0–1 | `security_room_staffed` | CAMERA_OPERATOR in U5 | `desk_work` | — |
| Bartenders | `club_bartender`, `club_bartender_b` | 4 | always: main bar 2, east bar 1, VIP bar 1 | `civ_bar_main`, `civ_bar_east`, `civ_bar_vip` | `bartender_wipe` / `bartender_pour` | `staff`, `staff_bar` |
| Box office / cloak | `club_bartender_b` | 1 | always | `civ_box_office` | `desk_work` | `staff`, `staff_front` |
| Counter (count room) | `club_bartender` | 0–1 | `count_room` = `count_running` | `civ_count` | `desk_work` | `staff`, `staff_upper` |
| DJ | `club_dj` | 1 | `dj_set`: on stage (`dj_on`) or in G11 (`dj_break`) | `civ_dj_stage` / `civ_dj_green` | `dj_mix` (QC-74) / `sit` | `staff`, `staff_dj` |
| Patrons | `club_patron` … `_d` | 12–20 | scalar `crowd` | `civ_patron` (bars, booths, foyer, WCs, passage, balcony, VIP) | `walk_text`, `queue`, `sit`, `smoke` | `civilian` |
| Dancers | `club_patron` … `_d` | 4–6 clusters × 5 | scalar `dance_clusters` | `civ_dancer` (cluster spawns on the dance floor) | `dance_a` / `dance_b` / `dance_c` | — (stay) |
| Queue | — | — | dressing only | — | — | — |
| Off-duty cop | `club_offduty_cop` (plain clothes: leather jacket, belt shield + holster) | 0–1 | rare `off_duty_cop` | `civ_offduty` (U1 booth; POLICE + `scripted`, spawned by the mission) | `sit` | `civilian` |
| Co-op couriers | `club_courier` (a bare-faced pair) | 0–2 | rare `co_op_pickup` (timed) | `cartel_courier` + `scripted` (walk in calm, A 9a335a1d) | — | `courier` |
| VIP party guests | `club_vip` pool (gold wristbands) | +6 | rare `vip_party` | U1 / U2 | `walk_text`, `sit` | `civilian` |

**Ambient-clip placement (characters.md v1.9, lead note).** Props are sized to D's clips:
- **Bar tops are 1.05 m** (inside the 1.05–1.1 m bar band) on every bar (main, east, VIP, box
  office). Bartender SpawnPoints and `staff_bar` PatrolPoints sit **0.28 m behind the bar top's near
  (staff-side) edge**, facing the counter, so `bartender_wipe` / `bartender_pour` land on the top.
  The staff aisle behind each bar is 1.0 m clear, so the back bar does not clip the root.
- `dance_a/b/c` and `bouncer_idle`, `walk_text` need no prop. Dancer spawns keep ≥ 0.7 m between
  roots (shoulder clearance) and stay ≥ 1.0 m inside the dance-floor edge.
- **`cower_stand` wants a wall 0.21 m behind the root.** The loud `cower` points (where intimidated
  civilians drop) are placed 0.21 m off walls along the hall's west and south walls, the G7 booth
  backs (the banquette back counts as the wall, 1.1 m high), the foyer walls and the VIP lounge's
  mirrored wall; `cower_seated` points are in the booths.

**Totals per difficulty:**

| Difficulty | Bouncers (fixed + rovers) | Operator | Pagers to clear the touchable ones | Civilians (staff + patrons + dancers) | Notes |
|---|---|---|---|---|---|
| Routine / Tense | 2 + 1 = **3** | 60% | 2–3 (the door bouncer is untouchable) | 6–7 + 12–14 + 20 = **38–41** | Everything inside can be pagered. |
| Hazardous | 2 + 2 = **4** | 75% | 3–4 | 6–7 + 16 + 25 = **47–48** | At the cap. |
| Brutal | 2 + 2 = **4** | 75% | 3–4 | 6–7 + 18 + 25 = **49–50** | `co_op_pickup` can add 2 unpagerable gunmen. |
| Lethal / Cataclysm | 2 + 3 = **5** | 75% | 4–5 | 6–7 + 20 + 30 = **56–57** (≤ 50 alive at start: patrons are capped by the budget, see Budgets) | 1 rover must be ghosted; Titan cameras. |

Cable ties: 2 per player. The crowd is never tied: it is avoided (casing) and stampedes in loud.

## Sightlines
- **Door bouncer (sidewalk, facing S):** he sees the queue, the street and, when he turns to the
  doors, the foyer through the glass doors (to z 21). Anything masked in G1 is seen.
- **Rope bouncer (U8, facing E at the gate):** covers the gate, the U2 west half and the stair's top
  flight. The VIP staff door (26, 18) is 17 m away across U1 and **outside his view** when he faces
  the gate (he turns to the stair every 20–30 s).
- **East bar → G20 (the staff door):** the door (26, 11) is behind the east bartender's back while
  she serves (she faces west); the floor bouncer's pause point by the east bar faces the dance floor.
  Casing players are invisible to the crowd and the bartender (civilians never detect casing); only
  the floor bouncer's pause and camera C3 matter.
- **G13 back corridor:** 36 m straight. Anyone in it is seen end to end; cover comes from the door
  recesses, the keg trolleys and the crate stacks at x 9 and x 24 (1.4 m, crouch cover).
- **G20:** 14 m straight from G13 to the box office; the BOH rover pauses at its middle facing N.
- **Projection box (U5):** the operator faces the monitors (south). Through the ports, the box sees
  the balcony and the hall; nobody inside looks through them unless the rover pauses there (loop c).
- **Count-room mirror (U10 → hall):** one-way. The counter at the tables faces west toward the
  mirror, i.e. **away from the door** (S): entering behind him is possible.
- **U6b:** 12 m straight; the office door, the VIP staff door and the U5 door all open into it.
- **The crowd:** 30+ observers in the hall. They are the reason the front of house is casing-only.
  Masked crossing of the hall is never a route (see the hardest roll).

### Cameras, keycards and codes
**Cameras** (`security_camera`, 2.6–3.2 m, 60° cone, 20 m; Titan from Lethal):

| Cam | Mount (x, z, y) | Looks at | Blind spots |
|---|---|---|---|
| C1 | G1 NE corner (21.6, 21.4, 3.2) | SW: entrance doors, the box-office counter | Behind the counter's west end. Always on (the door camera). |
| C2 | G13 W end (0.4, 6, 2.8) | E along G13 (to x ≈ 20) | The far east end, G21's door. |
| C3 | G20 N end (27, 7.4, 2.8) | S along G20: east bar door, G23 door, G25 door | The G13/G20 corner under the mount. |
| C4 | G21 NE (35.6, 0.4, 3.2) | SW: roller door, personnel door, the G13 door | The G16 door beside the mount. |
| C5 | alley, G21 wall (33, −0.4, 3.0) | W along the alley: E1, the drop ladder, the dumpsters | The alley mouth to its east. |
| C6 | G25 NW (28.4, 14.4, 2.8) | E along G25: the staff street door and the staff-stair door | The G20 door beside the mount. |
| C7 | U6b S end (27, 27.6, 2.8) | N along U6b: U13, U5, office and VIP staff doors | The U6 leg. |
| C8 | U10 NE (32.6, 7.4, 2.8) | W: the count tables, the mirror, the window | **The door (30, 14) and the whiteboard beside it** (68° off axis). |
| C9 | G10 NW (0.4, 0.4, 2.8) | SE: the stock cage | The door (4, 5) beside the cone. |
| C10 | U1 E end (25.6, 15.4, 3.0) | W along the balcony and the VIP staff door | The door is under the mount (blind); the cone covers the approach. |

Camera layouts (`camera` variable). The U6 leg and the staff stair have no camera in any layout, and
each layout leaves a ghost line from the gear to the safe and from the safe to each van with ≤ 2 ECM
charges:

| Layout | Cameras | In (FOH → office) | Bags out |
|---|---|---|---|
| `cam_a` | C1, C2, C5, C7, C8 | east bar door → G20 → G25 → stair → U6 free; **C7 sees the office door** (ECM, or the 2 m crossing timed) | stair → G25 → G20 → G13 east half (past C2's 20 m) → G21 free; **C5 sees E1** (ECM for the drops) or E2 via the staff door, free |
| `cam_b` | C1, C3, C4, C9, C10 | casing across G20 under C3 (×0.35, a 3 s crossing), or backstage → G13 → G20; upstairs free | stair → G25 → staff door (push bar) → Tolley St → the alley mouth → E1, or straight to E2: free |
| `cam_c` | C1, C3, C6, C8, C10 | casing through G20/G25 under C3/C6 (×0.35); upstairs free | stage the bags inside the stair at the ground landing (no camera), then **one ECM** for the G25 leg (C6) out of the staff door; the alley (C5 off) and Tolley St are free |

**Keycard** (`keycard`, one consumable card; reader on the office door U9; D-048: every other staff
door is LOCKPICK and NPC-authorised):

| Slot | Where | Who is near | Mode to take it |
|---|---|---|---|
| `kc_staff_room` | G12 key hooks by the rota | bartenders on stock runs | casing (RESTRICTED) |
| `kc_bouncer_board` | G24 key board | BOH rover (loop c) | casing |
| `kc_vip_bar` | U2, behind the VIP register | VIP bartender (civilian: blind to casing), rope bouncer 9 m | casing, from behind the bar flap |
| `kc_count_room` | U10 desk | the counter (`count_running`) | casing or masked |
| `kc_dj_booth` | stage, beside the decks | the DJ (civilian), the whole crowd (blind to casing), floor bouncer | casing; `slot_requires` `dj_break` (the DJ's bag is on the booth only when he is off stage) |

**Code** (`code_note`, the safe combination; reading is a `casing_allowed` interaction, QC-75):
`code_staff_board` (G12 rota), `code_bouncer_log` (G24 log), `code_count_board` (U10 whiteboard),
`code_office_blotter` (U9 desk, behind the keycard door, so it saves only the drill).

## Stealth routes
Every route starts in civilian mode at the foyer (or a pre-planning spawn). **Phase 1, scout
(civilian, front of house only, D-075):** walk the guest side, read the hall, the floor and rope
bouncers, the hall cameras and the VIP bar; the back of house is scouted as casing. **Phase 2, gear:** go to the gear (`gear_drop`) and pick it up → casing. **Phase 3,
work:** casing for keycards and notes, masked for doors, the safe and the bags.

1. **East bar service door (FOH → BOH).** Gear at `gear_cloak`, `gear_wc` or `gear_booth` (all FOH). As casing, slip
   behind the east bar when the floor bouncer is at the stage end (his loop b), through the service
   door into G20 (RESTRICTED: ×0.35 fill from the BOH rover and C3). Keycard in G12/G24, then **mask on
   the G22 staff stair's half landing** (an enclosed core: no camera, no civilian route; only the upper rover crosses it,
   on his loop c, so mask while he is on loop a or b) → U6 → U6b → office. Risk: the BOH rover's G20 pause, C3 in
   `cam_b`. (r305, P's wait-unseen: G23 is not a mask spot. The east bartender's stock runs keep it observed, with no
   2 s unseen window in 240 s.)
2. **Backstage.** With `dj_break` the stage is empty: up the 0.3 m step behind the speaker stack,
   the backstage door (13, 7) into G13 mid (C2 looks E from the west end: the door is 13 m in, inside
   its cone in `cam_a`). `kc_dj_booth` is on the way. With `dj_on` the DJ stands 3 m from the
   door (a civilian: harmless while casing, a witness once masked).
3. **Alley and BOH roof.** Walk out the front (civilian, PUBLIC), round Tolley St into the alley
   (`gear_van`: the van is here; `side_gate` open: through the passage instead). Then either the
   loading personnel door (`rear_propped`, or lockpick 8 s in C5's view and the smoker's loop) → G21
   → G13; or, **masked**, the drop ladder `F` (ladders need the mask) → BOH roof → the count-room
   window (`ow_count_open`; latched = break glass, 15 m noise next to the counter) → U10 →
   `kc_count_room` / `code_count_board` → U6 → office. The roof route skips both floors' corridors
   and is the best throw path (below).
4. **VIP side.** Grand stair → rope gate (a guest door, civilian-allowed: the rope bouncer cannot
   stop an undetectable civilian; a casing player is in RESTRICTED VIP under ×0.35). `kc_vip_bar` from behind
   the bar, then the **VIP staff door** (lockpick 8 s, masked) at the balcony's east end when the
   rope bouncer faces the stair and C10 is off or jammed → U6b → office (3 m). The shortest line to
   the office; the most eyes on it (VIP patrons see a masked player).

**Inside the office:** keycard (3 s swipe) → read `code_office_blotter` if it is the code slot → the
safe keypad (5 s) **or** the drill (120 s, jams). **The drill is a deliberate last resort**: the safe
is 6 m from the upper rover's U6 pause and 7 m from the operator through two walls, inside the
drill's 12.5 m occluded radius (S4.3). The club music does not mask it.

**Pager budget.** The door bouncer stands in the queue (PUBLIC, 10+ civilian witnesses): killing him
is an alarm by witnesses, so he is never a pager. D-143 fixes 4 guards at load on every seed (the door and rope posts
+ 2 rovers), so the touchable carriers are the rope bouncer and the 2 rovers, plus the operator from Tense
(`sec_staffed` is forced off on Routine). Against pager_max [4, 3, 3, 2, 2, 1]: Routine 3 touchable, all answerable;
Tense/Hazardous 3–4 vs 3, avoid one; Brutal/Lethal vs 2, avoid one or two; Cataclysm vs 1, avoid all but one (a
public-floor rover, `rover_floor`, is the easiest to leave alone).

**The hardest roll and its ghost line** (level_standards §4 MUST). Cataclysm, `cam_a` (Titan),
operator in, rovers `rover_boh` + `rover_upper` (D-143: exactly 2), `gear_van`, `kc_bouncer_board`,
`code_count_board`, `count_running`, `dj_on`, `rear_locked`, `ow_count_latched`, `gate_chained`,
`esc_alley`, `crowd` 20 + 6 clusters, `off_duty_cop`. Solo, one ECM (2 charges), no kills, no
pagers, no cable ties:
1. **Civilian:** out the front, Tolley St, the alley to the van at E1; pick up the gear (→ casing;
   the alley is PUBLIC, so C5 cannot fill on a casing player there).
2. Back round to the foyer (public), through the crowd (civilians never detect casing) to the east
   bar; behind the bar while the bartender serves the far end → service door → G20 (C3 is not in
   `cam_a`) → G24: the key board, taken while the BOH rover is on loop a/b (casing, ×0.35) → G25
   (C6 not in `cam_a`) → staff stair → U6.
3. Mask in U6 (no camera) when the upper rover reaches the balcony on his loop b (≥ 25 s from U6, plus his 10 s rail
   pause). **ECM #1** (20 s, every camera: C8 in U10 and C7 on U6b) → lockpick the U10 door (8 s; picking a lock is
   masked work, LEAD r305 ruling) → in: the counter faces the mirror (W) with his back to the door, the whiteboard is
   on the south wall beside it: read the code (2 s) and step out (2 s).
4. U6 → U6b to the office door (~6 m, 2 s): swipe (3 s) → in. That is 17 s of the 20 s jam (3 s spare) and ~17 s of
   the rover's ≥ 35 s away (18 s spare). U9 has no camera: keypad (5 s) → bag. Stage the bags inside U9.
5. On the upper rover's loop b (balcony, ≥ 25 s away), each bag: U9 → U6b (the 2 m from the door to
   the U6 corner is < 1 s in C7's cone at ≥ 9.6 m) → U6 → stair → G25 → G20 → G13 east half (past
   C2's 20 m reach) → G21 (no camera in `cam_a`). Lockpick the personnel door once from inside (8 s; C5 is fixed on
   the wall beside it and looks out over the alley, not along the wall) and stage the 3 bags inside it. Time each G20 leg to
   the BOH rover's loop a (G13 west half).
6. **ECM #2** for C5: the 3 bags out of the door into the van's SECURE zone (4 m throws, ≈ 12 s),
   then walk to the van. The off-duty cop sits in a U1 booth and never enters the staff wing.

Total: 2 ECM charges. `cam_b` and `cam_c` need 0–1 (layout table above).

## Loud
**Alarm sequence (the level change).** On `alarm_raised` the mission:
1. cuts the club sound (`cue.club_power_down`, the diegetic loop stops, 0.4 s) and switches the hall
   from **club lighting** to **house lights** (4000 K work lights on the truss; the moving heads and
   the dance floor go dark);
2. the DJ shouts on the mic (`vo.dj.afterhours_alarm`, diegetic, 3D at the stage);
3. **the stampede**: every patron and dancer not intimidated within the first 2 s turns PANICKED and
   flees to the nearest `civ_exit` point (the main doors → Marlin Ave; the hall fire exits → the
   passage → Marlin Ave; G13's doors are staff-only exits for staff) and **despawns there** (QC-71).
   The doors flow for ~25–40 s. Players can shout the nearest ones down as hostages (they `cower_stand`
   at the walls);
4. locks the safe keypad (lockdown: the CODE method is disabled; drill or C4 only) and the office
   keycard reader stays live (the office is the holdout, not a vault);
5. starts the director as usual (first CONTROL with first responders from Marlin Ave and Tolley St).

**Phase outline:** the stampede (0–40 s) overlaps CONTROL; wave 1 arrives while the safe drill runs;
wave 2 while bags go down the staff stair; wave 3 during the escape wait (FADE rule in Escape).

### Holdouts

| Holdout | Where | Entrances (chokepoints) | Flanks | Sniper exposure | Strength | Weakness | It matters when |
|---|---|---|---|---|---|---|---|
| **H1 Office suite** | U9 + U12 + U6b, centroid (31, 18, +4.2) | (1) the staff stair door (34, 14) via U6; (2) the VIP staff door (26, 18) from the balcony; (3) the U10 window (breach_only ENTRY from the BOH roof) | The balcony (police from the grand stair) reaches (2); the BOH roof reaches (3). | **S2** (Tolley St roof) through the U9 east windows (22 m). | Three entries at three different points of one short corridor; the office is a hard room. | S2 sees into the office; the drill sits in the window's line. | Always: the safe drill (120 s) in loud. |
| **H2 Balcony + VIP** | U1 + U2, centroid (13, 20, +4.2) | (1) the grand stair rope gate; (2) the VIP staff door; (3) the whole hall below (fire up over the rail) | Police in the hall shoot up through the glass guard (soft cover). | None (no exterior windows except U2's south windows: S1 at 30 m). | Height over the hall; the brass rail and booths are cover. | Three directions plus the open rail. | The bag route if the crew uses the grand stair; a strong spot to wait out a wave. |
| **H3 Loading + back corridor** | G21 + G13 east, centroid (31, 4) | (1) the roller door and personnel door (alley); (2) G13 west (the passage door, the stage door); (3) G20 from the south | Police from the stage and the passage come along the 36 m corridor. | **S3** (rare) over the alley. | The van E1 is 6 m away; crates and kegs. | The corridor is long and straight. | `esc_alley`: the escape wait. |
| **H4 Staff entrance** | G25 + G24, centroid (32, 17) | (1) the staff door (Tolley St); (2) G20; (3) the staff stair | Police from Tolley St are at the door; from inside via G20. | **S2** sees the staff door and E2 (16 m). | Short bag route from the stair (6 m) to E2. | Tolley St is a straight police lane (P3). | `esc_tolley`: the escape wait. |

### Police spawns (≥ 3 directions; 4 designed) and the spawn rule
Police **never spawn inside the building** (D-064, QC-42): they spawn only at the exterior POLICE
spawns below and enter through ENTRY `TacticalPoint`s. **Every ENTRY on the building shell carries
the tag `breach_only`** (a breach target, never a spawn candidate). The director picks the nearest
valid spawn with no crew LOS and ≥ 15 m from every crew member (L1.4).

| Spawn (tag) | Position (x, z, y) | Occluder | → H1 | → H2 | → H3 | → H4 |
|---|---|---|---|---|---|---|
| **P1** `police_w` (Marlin Ave west) | (−30, 40, 0) | road-works van + fence | 65 | 48 | 70 | 66 |
| **P2** `police_e` (Marlin Ave east) | (60, 40, 0) | the night bus + barriers | 36 | 51 | 48 | 36 |
| **P3** `police_n` (Tolley St north) | (42, −22, 0) | the refuse truck + Keston Row corner | 40 | 49 | 26 | 38 |
| **P4** `police_alley` (alley west, behind the gate) | (−18, −4, 0) | the chained gate + dumpster | 54 | 39 | 49 | 54 |

All flat distances ≥ 26 m (≥ 15 m required), so a crew inside a holdout never blocks every spawn.

### Police entry points (`TacticalPoint`)

| Kind | Where | breachable | `breach_only` | Serves |
|---|---|---|---|---|
| ENTRY | the main entrance doors ×2 (G1) | — (glass, open in loud) | yes | P1, P2 |
| ENTRY | hall fire exits (0, 8), (0, 19) from the passage | yes (push-bar, one-way) | yes | P1, P4 |
| ENTRY | G13 doors (0, 6) and (36, 6) | yes | yes | P4, P3 |
| ENTRY | G21 roller door and personnel door (alley) | yes | yes | P3, P4 |
| ENTRY | staff door (36, 15) Tolley St | yes | yes | P2, P3 |
| ENTRY | the U10 window from the BOH roof (+4.2; police reach the roof by the drop ladder) | yes (glass) | yes | P3, P4 |
| ENTRY | the smokers' passage gates (S and N) | N gate: yes (chain) | — (exterior) | P1, P4 |
| FLANK | the BOH roof (drop ladder) → the U10 window; the passage → the fire exits | — | — | Phantom, Stinger |
| SHIELD_ANCHOR | Marlin Ave under the marquee (16, 30); Tolley St at the staff door (38, 15); the foyer at the hall doors (16, 22); the alley at E1 (30, −3) | — | — | Bulwark / Aegis |
| COVER | ~50 points: bar ends, booth backs, the speaker stacks, the stage edge, the balcony rail, the crates and kegs in G13/G21, dumpsters, parked cars, the marquee pillars | — | — | all |

### Sniper perches (`SNIPER_PERCH`)

| Perch | Position (x, z, y) | Sees | Distance to the bag route | Blind to |
|---|---|---|---|---|
| **S1** Corliss Hotel roof | (−10, 50, +18) | the marquee, the main doors, Marlin Ave, the passage's south end, the U2 windows | main doors 25 m, U2 30 m | the alley, Tolley St |
| **S2** office roof across Tolley | (52, 4, +14) | Tolley St, the staff door and E2 (16 m), the U9/U12 east windows (20 m), the alley mouth | E2 16 m, U9 22 m | the alley west of x 30, Marlin Ave |
| **S3** Keston Row parapet (rare `rooftop_watch`) | (24, −14, +10) | the alley, E1 (14 m), the drop ladder, the BOH roof, the U10 window | E1 14 m | everything south of z 7 |

### Specials
- **Phantom** (L4.3): via the passage and the hall fire exits, and over the BOH roof to the U10 window.
- **Stinger** (L4.4): pairs, from the alley (G21) and the staff door.
- **Bulwark** (L4.5): the main doors (foyer anchor) and Tolley St; a Bulwark in G20 or on the staff
  stair is the "block the bag route" moment.
- **Wrecker** (L4.6): vehicle-wide routes only: Marlin Ave through the main doors into the hall, and
  Tolley St through the staff door.
- **Corpsman** (L4.8): with any group. **Longshot** (L4.7): S1, S2 (always), S3 (`rooftop_watch`).
- **Commander Brandt + Aegis** (L4.9, Lethal+): from P2 via Marlin Ave into the emptied hall. The
  hall is the arena he gets; the crew answers from the balcony (H2) or holds H1.

### Saw targets (`G.SAW_TARGET`, D-057; ENV A ships `saw_cut`, the map adds the group + metadata now)
- the **stock cage padlock** (G10, `prod_stock`): saw 20 s (or lockpick 8 s);
- the **smokers' passage north gate chain** (`gate_chained`): saw 20 s (or lockpick 8 s);
- the **door drop safe** in G26 (`safe` SMALL, `methods [drill, saw]`): saw 60 s;
- the **U12 lock boxes** (`prod_private`, 3 boxes, LOCKPICK 6 s each or saw 15 s): the parcels inside;
- (police only) the alley west gate is a breach, not a saw target.
Saw noise is the S4.3 saw radius; in stealth a saw anywhere in the BOH reaches the BOH rover.

## Loot path
- **Required** (the escape opens when it is done): **3 bags of `loot.cash_bricks` from the office
  safe secured.** The safe holds `safe_bags` (4–6). Everything else is a bonus.
- **Safe (U9) →**
  - **E2 Tolley St van:** U9 → U6b → U6 → staff stair down → G25 → staff door → 4 m to the kerb
    (≈ 25 m + one storey). **The short one**, but the staff door is lockpick-from-outside and in S2's
    lane in loud.
  - **E1 alley van:** U9 → U6 → staff stair → G25 → G20 → G13 → G21 → personnel door → E1 (≈ 45 m +
    one storey). Or **through the count room**: U9 → U6 → U10 → the window → the BOH roof → **throw
    from the parapet into the alley** (4.2 m drop + 1.1 m parapet; lands 2–4 m from E1). Only with
    `ow_count_open` (or broken glass). **The best stealth throw spot.**
  - **Not the grand stair:** carrying a bag through the VIP side and the public foyer means a masked
    player in front of the crowd.
- **Product** (`product_location`) → G10 or G11 → G13 → G21 → E1 (≈ 25–30 m), or G13 → G20 → G25 →
  E2 (≈ 35 m). `prod_private`: with the safe bags (H1).
- **Count room cash** (`count_running`): U10 → the window (open) → roof → alley; or with the safe bags.
- **Small loot:** bar tills ×3 (main, east, VIP), the box-office till and the G26 drop safe, the
  cloakroom tip jar, bottle-service cash on VIP tables, the U9 desk drawer.
- **Secure zones:** `SECURE_LOOT` at the active escape only (the van's rear doors). It exists from
  the start (bags can be secured before the escape is called, PD2).
- **Bodies:** BODY_HIDE in G15 (1), G27 (2), the alley dumpsters (2 × `body_container`).

### Loot table

| id | Weight | Base | Where | Count | Status |
|---|---|---|---|---|---|
| `loot.cash_bricks` | MEDIUM | $8,000 (D-120) | office safe (U9) | `safe_bags` 4–6 (+1 `count_done`) | existing (B) |
| `loot.parcels` | LIGHT | $7,500 (D-120) | `product_location`: G10 cage / G11 flight cases / U12 boxes | `product_bags` 3–5 (+2 `extra_product`) | existing (B6-01; "Sealed Parcels") |
| `loot.cash` | LIGHT | $6,500 (D-120) | U10 count tables (`count_running`) | 2 | existing |
| `small_loot` (prefab values ◇) | — | till $600; drop safe $900 ×3; bottle-service cash $800; desk drawer $1,200; tip jar $300 | as above | ~12 pickups | values for ENV B (D-068: $600–1,500 range) |
| `loot.body_bag` | HEAVY | 0 | — | — | existing |

No new LootDef is needed. `loot.parcels` is the "coke LIGHT" of the roadmap: the fiction calls it
the Co-op's product, sealed parcels in vacuum wrap; the game never names a real drug.

## Objectives
**Stealth** (objective_tag in brackets; ENV B builds `objective.afterhours.<tag>` from these, D-039):
1. *(optional)* Look around the club. Mercer intro and an Accountant line. `[casing]`
2. Get the gear the insider left (`gear_drop`). Completes on the first pickup; Mercer names the place
   (or the `asset.gear_drop` choice). `[gear]`
3. Find the office keycard. `[keycard]`
4. Get into Crale's office (the keycard door). `[office]`
5. Find the safe combination `[safe_code]` (skipped once the safe is open; the drill also completes
   `[safe]`).
6. Open the safe: keypad (5 s) **or** drill (120 s, jams). `[safe]`
7. Bag the Co-op's cash (safe `loot_spawn`, `loot.cash_bricks` × `safe_bags`). `[safe_loot]`
8. Secure ≥ 3 cash bags at the van. `[secure]`
9. *(optional)* Find the product and take it (`loot.parcels`). `[product]`
10. *(optional)* The count room's cash (`count_running`). `[count_room]`
11. Escape. `[escape]`

**Loud** (on `alarm_raised`):
1. Mercer: "Music's off, lights are up, and the safe just locked itself. Drill it." The mission
   disables the safe's CODE method. If the safe is already open, skip to 3.
2. Get into the office (keycard, or **C4/breach the door**: the keycard door becomes breachable in
   loud) `[office]` and drill the safe (120 s, jams per S9.3) or C4 it (S9.8). `[safe]`
3. Bag and secure ≥ 3 cash bags. `[secure]`
4. Hold until the van arrives: at the **second assault's FADE or 300 s** after `[secure]`'s first
   bag, whichever is later, at the rolled `escape` slot; if a captain is active when the 300 s runs out, the van
   comes then (D-166: a captain holds SUSTAIN, so the FADE may never come). `[escape_wait]`
5. Escape. `[escape]`

**Mission script notes** (`afterhours_mission.gd` on `HeistMission`):
- `start_mode = &"civilian"` is ENV A's runtime rule (D-065); the mission does not switch modes. It
  listens to `item_picked_up(&"item.gear", slot)` to complete `[gear]` (first pickup) and to play
  Mercer's gear line once.
- Find prefabs by objective_tag. `[keycard]` completes on the keycard pickup, `[office]` on the
  reader opening the office door, `[safe_code]` on the code note read.
- **On `alarm_raised`:** call the map's `ClubSound.cut()` and `ClubLights.set_state(&"house")`
  (map nodes, ENV C), set the safe lockdown (disable CODE), make the office door breachable, start
  the stampede (ENV A's flee rule does the rest, QC-71). Mercer line.
- **`co_op_pickup`:** a timed NPC spawn (QC-25) of 2 couriers at 14:00 at the loading door (stealth
  only; they walk G21 → G13 → the product room and back; if the product is gone or they see a body or
  a masked player, they raise the alarm).
- **Escape:** `[secure]` (3 cash bags) activates the active `escape_zone` (stealth: present;
  loud: the FADE/300 s rule above).
- **Mercer lines:** intro (civilian), gear location, gear picked up, keycard found, office open, code
  found, safe open, drill started / jam / done, product found, count room, last pager (4th), lasers,
  music cut (alarm), crowd out, required loot secured, van ETA, escape, couriers arriving, off-duty
  cop spotted.

## Variable table
Each variable changes a decision. Rules resolve in this order (heist_map.md §5); per-difficulty
weights use A2-08 (QC-18).

| variable | options (slot ids) | weights | gameplay effect (the decision it changes) |
|---|---|---|---|
| `gear_drop` (heist group) | `gear_wc` (G3b, a duct panel in the patrons' WC), `gear_cloak` (G2, across the cloakroom counter from the foyer), `gear_booth` (G7, under the reserved booth's banquette), `gear_van` (the van at the active `escape` slot) | 1, 1, 1, 1 | **Where each player becomes detectable and which route starts there.** Every slot is reachable in civilian mode without a staff door (D-075). WC/booth: casing starts in the public lounge next to the east bar service door. Cloak: at a public counter, next to C1. Van: outside, so the alley/roof routes are natural and the front needs a walk back in. Forced by `asset.gear_drop`. |
| `dj_set` (`civilian_cluster`) | `dj_on` (on stage), `dj_break` (in G11; a set plays from the booth) | 0.65, 0.35 | **Whether the backstage door has a witness and whether `kc_dj_booth` exists.** With `dj_break` the green room holds a civilian (`prod_green` gets harder). |
| `keycard` | `kc_staff_room`, `kc_bouncer_board`, `kc_vip_bar`, `kc_count_room`, `kc_dj_booth` (`slot_requires` `dj_break`) | 1, 1, 1, 0.75, 0.75; pick 1 | **Which side you work first**: BOH ground, the VIP bar, the upper wing or the stage. |
| `code_note` | `code_staff_board`, `code_bouncer_log`, `code_count_board`, `code_office_blotter` | 1, 1, 1, 0.5; pick 1 | **Code or drill**, and whether a second room must be visited (the blotter is free once in the office). |
| `count_room` (`extra_loot`) | `count_running` (the counter in U10, 2 `loot.cash`, small loot), `count_done` (U10 empty, +1 safe bag) | 0.6, 0.4 | **A civilian next to `kc_count_room` and the window route**, against a quiet room and a bigger safe. |
| `product_location` | `prod_stock` (G10 cage, padlock), `prod_green` (G11 cases), `prod_private` (U12, behind the lasers) | 1, 0.8, 1 | **Greed and route:** ground BOH next to the loading bay, the green room (with the DJ on break), or inside H1 behind a laser grid. |
| `product_bags` (scalar) | 3, 4, 5 | uniform | **How many LIGHT trips** the bonus is worth. |
| `safe_bags` (scalar) | 4, 5, 6 | Routine 0.4/0.4/0.2; Brutal+ 0.2/0.4/0.4 | **Time in the office suite** beyond the 3 required. |
| `laser_pattern` (U12 grid) | `lz_static` (3 beams; bypass gap ≥ 0.8 m crouched, QC-24), `lz_sweep` (period 6 s), `lz_timed` (off 4 s every 16 s) | Routine 0.5/0.2/0.3; Brutal+ 0.2/0.4/0.4 | **Crouch, time or wait** for `prod_private`, inside the drill's earshot of the upper rover. |
| `guard_post` | `rover_floor`, `rover_boh`, `rover_upper`, `alley_smoker` (+ fixed `post_door`, `post_rope` spawns) | 1 each; pick exactly 2 at every difficulty (D-143: 4 guards; no `difficulty_add`) | **Which route is walked:** the floor rover watches the east bar and the stage; BOH covers G13/G20; upper covers the office corridor and the VIP door; the smoker shuts the alley. |
| `security_room_staffed` | `sec_staffed`, `sec_empty` | Routine 0.6/0.4; Hazardous+ 0.75/0.25 | **Live cameras or a pager**: the operator sits 7 m from the office, behind the U5 door on U6b. |
| `camera` | `cam_a`, `cam_b`, `cam_c` (Sightlines) | 1, 1, 1 | **Which corridor needs ECM or timing.** C1 is in every layout. `asset.intel_cameras` reveals it. |
| `rear_door` (`locked_door`) | `rear_propped`, `rear_locked` (lockpick 8 s) | 0.35, 0.65; `force_if` `alley_smoker` ⇒ `rear_propped` (the smoker props it) | **The cost of the alley door.** |
| `open_window` | `ow_count_open`, `ow_count_latched` | 0.4, 0.6 | **The roof route and the throw spot exist quietly** (latched = glass, 15 m noise beside the counter). Forced by `asset.count_window`. |
| `side_gate` | `gate_open`, `gate_chained` (lockpick 8 s / saw 20 s) | 0.4, 0.6 | **Whether the smokers' passage is a quick way to the alley** for civilians and a police lane from the alley. |
| `escape` | `esc_alley` (E1), `esc_tolley` (E2) | 0.55, 0.45 | **The whole loot path and the last holdout** (H3 or H4); alley = the roof throw; Tolley = the short stair-to-door run in S2's lane. |
| `crowd` (scalar) | patrons 12, 14, 16, 18, 20 | Routine 12/14; Hazardous 16; Brutal 18; Lethal+ 20 (by difficulty) | **Hostages and witnesses**: more casing cover is irrelevant (civilians never see casing), more bodies in loud crossfire and at the stairs. |
| `dance_clusters` (scalar) | 4, 5, 6 (× 5 dancers) | by difficulty (as the totals table) | Atmosphere and loud civilian pressure; the stampede's length (≈ 5 s per cluster at the doors). |

## Rare events

| id | good/bad | chance | effect |
|---|---|---|---|
| `count_left_open` | good | 3% | Mid-count, Crale's safe was left open: `force_active` safe open; `[safe_code]`/`[safe]` skipped (the keycard is still needed for the door). |
| `extra_product` | good | 6% | +2 `loot.parcels` at the active product location. |
| `vip_party` | bad | 8% | A birthday booking: +6 VIP patrons (D's `club_vip` pool, gold wristbands) on U1/U2 and a second rope bouncer on the balcony (`guard_extra`, a pager); the VIP route is crowded, the bottle-service small loot doubles. |
| `off_duty_cop` | bad | 6% (`min_difficulty` Hazardous) | A plain-clothes cop (D's `club_offduty_cop` look: leather jacket, belt shield + holster) in a U1 booth: a **police-preset observer** (S2.2: 0.6 s min-time) who radios the alarm on seeing a masked player (no pager; QC-76). |
| `co_op_pickup` | bad | 8% (`min_difficulty` Brutal) | At 14:00 two Co-op couriers (D's bare-faced `club_courier` pair) walk in calm at the loading door for the product (see the mission notes); a missing product raises the alarm. In loud they fight the crew. |
| `rooftop_watch` | bad | 8% | The S3 Keston Row perch is enabled in loud. |

## Escape
- **Van in the alley (E1):** at the loading door (x 28–33, z −4). Stealth: parked from the start
  (the AI teammates wait here, D-014); the escape opens when `[secure]` is done. Loud: it leaves at
  the alarm and returns at the second assault's FADE or 300 s after the first secured bag, whichever
  is later. Last holdout H3.
- **Van on Tolley St (E2):** at the kerb by the staff door (x 39–41, z 14–20). Same rules. Last
  holdout H4.
- **No walk-out** (D-075): every crew member leaves through the active escape zone (the van), as in
  PD2. Walking out the front door in civilian mode is part of scouting, not an escape.

## Pre-planning (preplanning.md contract, D-046 shape)
`Preplan` points (category; `floor` is the index into `floor_heights`: 0 Ground, 1 Balcony; labels
are heist-qualified, `ui.preplan.point.afterhours.<point_id>`, preplanning.md v1.1):

| Point | Category | Params / asset |
|---|---|---|
| `pp_spawn_foyer` | spawn | default (spawn_tag `""`), G1 (floor 0) |
| `pp_spawn_vip` | spawn | spawn_tag `preplan_spawn_vip` ("on the list": U2, floor 1) — `asset.alternate_entry` |
| `pp_spawn_alley` | spawn | spawn_tag `preplan_spawn_alley` (the alley by E1, as "deliverymen") — `asset.alternate_entry` |
| `pp_gear_wc` | insider | variant_group `gear_drop`, slot `gear_wc` — new `asset.gear_drop` |
| `pp_gear_cloak` | insider | slot `gear_cloak` — `asset.gear_drop` |
| `pp_gear_booth` | insider | slot `gear_booth` — `asset.gear_drop` |
| `pp_gear_van` | insider | slot `gear_van` — `asset.gear_drop` |
| `pp_insider_keycard` | insider | variant_group `keycard`, slot `kc_staff_room` — `asset.inside_keycard` (library, point override) |
| `pp_back_door` | insider | variant_group `rear_door`, slot `rear_propped` — `asset.propped_door` (library, point override) |
| `pp_count_window` | insider | variant_group `open_window`, slot `ow_count_open` (floor 1) — new `asset.count_window` |
| `pp_drop_alley` | drop_zone | by the dumpsters — body bag case, ammo, doctor |
| `pp_drop_roof` | drop_zone | BOH roof by the drop ladder (floor 1) — ammo, doctor |
| `pp_drop_tolley` | drop_zone | the staff-door recess on Tolley St — body bag case, ammo, doctor |
| `pp_escape_alley` | escape | variant_group `escape`, slot `esc_alley` — `asset.escape_position` (vote) |
| `pp_escape_tolley` | escape | slot `esc_tolley` |

All three spawns are **civilian** (start_mode applies to every PLAYER spawn).

`HeistDef.preplanning` (contract v1.0 shape; costs are Routine prices, scaled by
`PreplanTweak.cost_mult`; ◇ = my proposals for ENV B/lead):
```gdscript
preplanning = {
    "favors": 5,
    "disable": [],
    "assets": {
        # library assets, limited to this heist's points
        &"asset.body_bag_case_drop": {"point_ids": ["pp_drop_alley", "pp_drop_tolley"]},
        &"asset.ammo_bag_drop": {"point_ids": ["pp_drop_alley", "pp_drop_roof", "pp_drop_tolley"]},
        &"asset.doctor_bag_drop": {"point_ids": ["pp_drop_alley", "pp_drop_roof", "pp_drop_tolley"]},
        &"asset.inside_keycard": {"point_ids": ["pp_insider_keycard"]},     # force kc_staff_room
        &"asset.propped_door": {"point_ids": ["pp_back_door"]},             # force rear_propped
        # new heist assets (QC-72)
        &"asset.gear_drop": {"effect": &"force_variant",
                             "point_ids": ["pp_gear_wc", "pp_gear_cloak", "pp_gear_booth", "pp_gear_van"],
                             "exclusive_group": &"gear_drop", "max_count": 1,
                             "cost": 1000, "favors": 1, "category": &"access", "tags": [&"stealth"]},  # ◇
        &"asset.count_window": {"effect": &"force_variant", "point_ids": ["pp_count_window"],
                                "max_count": 1, "cost": 1500, "favors": 1, "category": &"access",
                                "tags": [&"stealth"]},                                                   # ◇
        &"asset.intel_safe_code": {"reveals": [&"code_note"], "cost": 1500, "favors": 1,
                                   "category": &"intel"},                                                # ◇
        &"asset.intel_product": {"reveals": [&"product_location"], "cost": 1200, "favors": 1,
                                 "category": &"intel"},                                                  # ◇
    },
}
```
Crew assets with no point that stay on: `asset.intel_cameras`, `asset.intel_keycards`,
`asset.intel_guard_posts`, `asset.extra_cable_ties`, `asset.spare_body_bags`. The board hides library
assets whose groups do not exist here (laptop, gondola, riser, containers, gangway, perch) by QB-53.
`asset.escape_position` and `asset.alternate_entry` work from the points' params as on every heist.
Blueprint: `docs/levels/afterhours/blueprint.png` from the plan renderer.

## Audio/lighting
- **Palette** (proposed style guide §3 row, below): **velvet plum `#5E3468`** dominant (velvet
  upholstery, wall drapes, the carpet runners, the bouncers' and bartenders' violet), **black lacquer
  `#3E3A42`** secondary (lacquered bar fronts, the stage, black-painted BOH ceilings; GSR black-paint
  exception), **velvet magenta neon `#F76BD3`** accent (the marquee, the blade sign, the bar
  backlights; it is ENV B's heist accent, so the UI and the world agree). Gilded plaster (the
  proscenium, the circle front) and the brass rail stay inside GSR saturation. **No club light may use
  the interactable cyan `#4FD1E8`**: the dance rig uses violet, magenta, amber and UV blue `#5B4BFF`.
  Wear: medium (sticky floors, scuffed lacquer, taped cables), BOH heavy.
- **Time:** 00:40, no sun or moon; overcast sky lit orange from below; wet surfaces with puddle
  reflections (screen-space + ReflectionProbe); no rain falling.
- **Two lighting states in the hall** (`ClubLights`, map node; both validated, both in the review
  shots):
  - **club** (stealth): moving heads and wash on the truss (unshadowed SpotLights), the mirror ball
    (one shadowless SpotLight + an animated projector decal), the LED dance floor (emissive), bar
    backlights 2700 K, booth lamps 2200 K; the hall is dark between pools (readable silhouettes);
  - **house** (loud): 4000 K work lights on the truss (4 shadowed), every pool even; the dance floor
    and heads off.
- **Zones:** foyer 2700 K brass pendants + the marquee spill through the doors; VIP lounge 2400 K
  sconces and a magenta cove; balcony: rail uplights; BOH 5000 K fluorescents (G13, G21), 4000 K
  (staff rooms); security room: monitor glow + the hall's colour through the ports; count room 4000 K
  desk lamps; Crale's office 2700 K lamps; the alley a sodium lamp over the loading door; Tolley St
  LED 4000 K. Every light has a fixture (the truss fixtures are meshes tagged `fixture`).
- **GI:** VoxelGI for the interior with the hall lights in `DYNAMIC` bake mode so the house-lights
  switch re-lights GI without a re-bake; ReflectionProbe per room; OccluderInstance3D for the shell
  and the hall walls. Re-bake after every geometry regeneration (D-046).
- **Ambience:** `amb_afterhours_club` (crowd walla, glass clinks, bass bleed through walls, HVAC),
  `amb_afterhours_boh` (fridge hum, keg compressor, muffled kick drum), `amb_street_wet_night`
  (tyres on wet asphalt, distant sirens, the queue's chatter). After the stampede the club ambience
  drops to an empty-room tone.
- **Music:** `afterhours` (proposed name for ENV B's `music.afterhours.name`: "Velvet Rope").
  - **Diegetic stem `club`** (new, ENV C): a 120 BPM four-on-the-floor house loop (16 bars, 32.0 s) played **by the
    club's speakers**, not by the MusicDirector: 6 `AudioStreamPlayer3D`s in the hall (stacks, balcony,
    VIP, foyer) under a map node `ClubSound`, on the **Ambience** bus (D-075: it is world audio, so the
    ambience slider governs it, not the music slider), with wall occlusion low-pass for the BOH.
  - **MusicDirector interaction** (ENV C; D-062/D-069 hooks): in civilian/casing/stealth the
    MusicDirector plays the selected track's `stealth` stem **ducked** (`set_ducked(true)`, −14 dB)
    while the local listener is inside the `club_sound` area (hall, G7, foyer, balcony, VIP) and at
    full level elsewhere (BOH, upper wing, alley, streets). On `alarm_raised` the mission calls
    `ClubSound.cut()` (`cue.club_power_down`), the MusicDirector un-ducks and runs `control` →
    `anticipation` → `assault` → `fade` as usual. The `club` stem and the assault stem share the
    tempo grid (120 → 128 BPM assault), so the cut lands on a bar line.
  - **One beat for the club (LEAD r305):** 120 BPM, the tempo D's dancers (`dance_a/b/c`) and the DJ's `dj_mix`
    are authored at (DANCE_BPM 120, 16-beat loops), so the floor stays on the beat. The four club-side beds
    (`amb_afterhours_club_music`, `amb_afterhours_club`, `amb_afterhours_boh`, `amb_street_wet_night`) are 32.0 s,
    a whole number of 120 BPM bars, and their bass bleed beats with the loop. The score keeps its own 128 BPM grid.
  - If the host picked another `music_track` (D-062), only the score changes: the club's own loop
    stays Afterhours' (it is world audio).
  - Score stems: `stealth` (72 BPM, sub-bass pulses that sit under the club loop), `control`,
    `anticipation`, `assault` (128 BPM, the club loop's bassline driven into a full assault),
    `fade`, `win`/`lose`.
- **New cues** (ENV C produces; audio_cues.md additions proposed to the lead): `cue.club_power_down`
  (needle drag + power-down whine + crowd gasp), `cue.crowd_stampede` (looping screams and
  footfalls at the hall doors, stops when the last fleeing civilian despawns), `cue.dj_mic_feedback`
  (the mic squeal under the DJ's line).
- **VO line ids** (`vo.<speaker>.<heist>_<line>`, D-051; ENV B writes the text):
  - **The Accountant:** `vo.accountant.briefing_afterhours_1..3`,
    `vo.accountant.afterhours_contact_intro`, `vo.accountant.afterhours_payday`.
  - **Mercer:** `vo.mercer.briefing_afterhours_1..2`, `vo.mercer.afterhours_intro`,
    `vo.mercer.afterhours_gear_location`, `vo.mercer.afterhours_gear_picked`,
    `vo.mercer.afterhours_keycard_found`, `vo.mercer.afterhours_office_open`,
    `vo.mercer.afterhours_code_found`, `vo.mercer.afterhours_safe_open`,
    `vo.mercer.afterhours_drill_started`, `vo.mercer.afterhours_drill_jam`,
    `vo.mercer.afterhours_product_found`, `vo.mercer.afterhours_count_room`,
    `vo.mercer.afterhours_last_pager`, `vo.mercer.afterhours_lasers`,
    `vo.mercer.afterhours_music_cut`, `vo.mercer.afterhours_crowd_out`,
    `vo.mercer.afterhours_required_secured`, `vo.mercer.afterhours_van_eta`,
    `vo.mercer.afterhours_escape`, `vo.mercer.afterhours_couriers`,
    `vo.mercer.afterhours_off_duty_cop`.
  - **DJ** (diegetic, 3D at the stage; new speaker id `dj`): `vo.dj.afterhours_alarm`
    ("Lights! Everybody out, out, OUT!"), `vo.dj.afterhours_shoutout_1..3` (ambient mic lines during
    the set, every 3–5 min).
  - Crew barks reuse the generic `vo.crew.*` set.
- **LUT:** `lut_afterhours`: deep violet shadows, magenta-pink highlights, warm skin protected; the
  house-lights state reads flatter and greener (no LUT swap; the lighting does it).

## Review shots
`HeistMap.review_cameras` (level_standards §8; JPEG q85, D-038). Each camera is ≥ 0.5 m inside its
room. 27 shots: 1 top-down, 4 exterior, the landmarks, 1 per major room, the security room, both
hall lighting states and the crowd.

| Camera | Shows | Covers |
|---|---|---|
| `rc_top_down` | orthographic plan of the play space | top-down plan |
| `rc_ext_marquee` | from across Marlin Ave: the marquee, the queue, the door bouncer, the blade sign | exterior 1, landmarks 1–2 |
| `rc_ext_tolley` | Tolley St from the north: the staff door, E2, the blade sign | exterior 2 |
| `rc_ext_alley` | the alley from its west gate: E1, the loading door, the drop ladder | exterior 3 |
| `rc_ext_passage` | the smokers' passage from Marlin Ave, the fire exits | exterior 4 |
| `rc_boh_roof` | the BOH roof from the ladder top toward the count-room window | X1 roof |
| `rc_foyer` | G1 from the entrance: hall doors, the box office, the grand stair | G1, G2, G8 |
| `rc_hall_club` | from the G7 booths: dance floor, the **proscenium + DJ**, the mirror ball, **club lights** | G6, landmark 3 |
| `rc_hall_house` | the same frame in **house lights** | G6 (loud state) |
| `rc_hall_crowd` | low, from the dance-floor edge into a full Cataclysm crowd | crowd density / perf |
| `rc_main_bar` | the main bar and back bar with two bartenders | G6/G7 bar, the bar-top height |
| `rc_east_bar` | the east bar and its service door | G6 (route 1) |
| `rc_under_circle` | G7 booths and the WC doors | G7 |
| `rc_balcony` | U1 from the east end along the brass rail over the hall | U1, landmark (rail) |
| `rc_vip_lounge` | U2 with the VIP bar and the rope gate | U2, U8 |
| `rc_projection_box` | U5: monitors, the operator seat, the ports | U5 (security room) |
| `rc_office` | U9: the safe, the desk, the keycard door | U9 (safe) |
| `rc_private_room` | U12 with the laser grid | U12 |
| `rc_count_room` | U10: tables, the one-way mirror onto the hall | U10 |
| `rc_upper_corridor` | U6b from the south: the office, VIP and U5 doors | U6/U6b |
| `rc_back_corridor` | G13 from the west end (36 m) | G13 |
| `rc_east_corridor` | G20 from the north | G20 |
| `rc_stock_room` | G10 with the cage | G10 |
| `rc_green_room` | G11 | G11 |
| `rc_staff_room` | G12 | G12 |
| `rc_loading` | G21 from the roller door | G21 |
| `rc_door_team` | G24 with the key board | G24 |

## Budgets
Targets from architecture §10 and D-038 QC-10, checked by the `perf` validator per review camera.

| Budget | Target | Notes |
|---|---|---|
| Draw calls per view | ≤ 2,500 | Worst: `rc_hall_crowd`, `rc_hall_club`, `rc_balcony`. Booths, bar stools, bottles and glasses are **MultiMeshInstance3D** per kit item; the bottle walls are one mesh per back bar. |
| Triangles per view | ≤ 3M (provisional, QC-10) | Characters ≤ 35k each at LOD0; dancers beyond 15 m use LOD1/2. |
| Shadowed lights in any shot | ≤ 8 | Club state: 0–2 shadowed in the hall (the heads are unshadowed); house state: 4 truss work lights; 1 per BOH room in view. Both states are measured. |
| Texture memory | ≤ 1.5 GB | The shared library (velvet, lacquer, terrazzo, gilded plaster, brick) covers ~90%. |
| **Crowd density** | dance floor 0.28–0.42 dancers/m² (20–30 on 72 m², roots ≥ 0.7 m apart); bars ≤ 1 patron per 1.2 m of bar front; booths ≤ 4 per booth; walkable lanes ≥ 1.2 m kept clear round the dance floor and to both hall doors | The lanes are what the stampede and the police use; the validator's navmesh check runs with the crowd spawns as obstacles. |
| **Civilians alive** | ≤ 50 at start (staff + patrons + dancers), ≤ 22 with individual perception + ≤ 6 cluster observers (QC-71); after the stampede ≤ 12 (hostages + cowering staff) | Patrons beyond the cap are not spawned (the `crowd` scalar is clamped by the budget). |
| Animation | dancers: AnimationTree on `dance_a/b/c` with per-cluster phase offsets; update at 15 Hz beyond 15 m, 7.5 Hz beyond 30 m; no IK | ENV A/D own the playback; the map supplies the spawns. |
| NPCs alive (loud) | police ≤ `DifficultyDef.max_active_enemies`; the 0–2 couriers count against it (D-064 rule) | |
| VFX | mirror-ball decal ×1, dance-floor emissive (shader, no particles), haze: one FogVolume over the hall (density 0.02) | Off in house lights. |
| **Density (kits)** | hall: furniture at the walls and under the circle, the dance floor clear; BOH: clutter at doors, crates in clusters; offices/break room per their kit minimums | Same-kit rooms (G3a/G3b, U4a/U4b, U13) differ in layout hash (`variety`). |

**Walkthrough whitelist** (level_standards §6): the BOH roof ↔ ground targets exceed 3× the
straight-line distance (the roof is reached only by the drop ladder from the alley). By design.

## HeistDef (proposed data, `afterhours_def.tres`)
`id afterhours`, display "Afterhours", contact `contact.accountant` (D-075), mode STEALTH_OR_LOUD,
**`start_mode &"civilian"`** (D-065), base_payout **$40,000** (D-143.1),
loot `[loot.cash_bricks, loot.parcels, loot.cash]`, escape_options `[van]` (D-143.3, ruling 9), music_track
`afterhours`, objectives `[casing, gear, keycard, office, safe_code, safe, safe_loot, secure,
product, count_room, escape_wait, escape]`, preplanning as above. Map
`game/world/heists/afterhours/afterhours.tscn`; `floor_heights [0.0, 4.2]`,
`floor_names ["Ground", "Balcony"]`.

## Proposed style guide §3 row (lead owns the guide)

| Heist | Dominant | Secondary | Accent | Mood / time |
|---|---|---|---|---|
| afterhours | velvet plum `#5E3468` | black lacquer `#3E3A42` | velvet magenta neon `#F76BD3` (+ gilded plaster, brass) | midnight, wet streets after rain; club light inside, house lights in loud |

Checks: plum albedo luminance ≈ 0.058 linear and lacquer ≈ 0.044 (inside 0.04–0.85; lacquer is
black paint and could go to 0.02); plum saturation 0.50 (≤ 0.75); the magenta is emissive/signage
only (exempt). It differs from Glasshouse's magenta sign by context: Glasshouse is ivory-and-walnut
with one neon script; Afterhours is a dark violet interior where the magenta is the light.

## Requests (to the lead)
- **QC-70 (ENV D):** add `club_bouncer` to `p5_cast.json`'s `pager_roles` (the Velvet's bouncers are
  its guards: GUARD spawns with pagers on `Hip/Socket`). `club_bouncer_b` is also the camera
  operator. Please confirm the hip seat on `club_bouncer` works for the pager prop.
- **QC-71 (ENV A):** the crowd. (a) **`crowd_cluster`** CIVILIAN spawns: 5 dancers that share one
  perception observer at the cluster centroid (civilian preset) with **reduced perception** (D-075: a
  crowd-noise multiplier on its detection rate, `crowd_perception_mult` ◇ 0.5; not zero), dance in place (no avoidance while
  idle), and panic together; (b) **loud flee-to-exit**: in LOUD, PANICKED civilians path to the
  nearest PatrolPoint tagged `civ_exit` and **despawn** there (no alarm effect, no kill penalty);
  intimidated ones stay as hostages; (c) a hard cap on civilians alive (the budget's 50).
- **QC-72 (ENV B):** assets `asset.gear_drop`, `asset.count_window`, `asset.intel_safe_code`,
  `asset.intel_product` (shapes above); point overrides for `asset.inside_keycard` /
  `asset.propped_door`; strings `objective.afterhours.<tag>` for the tags above,
  `ui.preplan.point.afterhours.*`, `music.afterhours.name` ("Velvet Rope" ◇), the VO text (the Accountant,
  Mercer, the new speaker `dj`), and the `small_loot` values. No new LootDef.
- **QC-73 (ENV A):** idle activities for the ambient clips (characters.md v1.9): `dance_a/b/c`,
  `bartender_wipe`, `bartender_pour`, `bouncer_idle`, `walk_text`, `cower_stand` (wall 0.21 m
  behind), `cower_seated`, and `dj_mix` (QC-74), selectable by `SpawnPoint.idle_activity`.
- **QC-74 (ENV D):** a `dj_mix` loop for `club_dj` at a 1.0 m deck (hands on the decks, head nod,
  one hand to the headphones), with its placement numbers (deck height and near-edge offset) in
  characters.md like the bartender clips. Until then the DJ uses `bartender_wipe` at the deck.
- **QC-75 (ENV A):** civilian mode details: (a) at the alarm every crew member auto-masks with
  their full loadout (D-075; ENV A already does this); (b) `door` honours the per-instance `civilian_allowed` export for lock NONE
  doors; (c) `code_note` reading is `casing_allowed` (taking a picture of a whiteboard), as keycard
  pickups are; (d) civilian players cannot carry bags (as casing).
- **QC-76 (ENV A):** `off_duty_cop`: a stealth **police-preset observer** among the civilians (no pager,
  not dominatable in stealth, radios the alarm 3 s after a masked-player detection unless killed
  first; fights in loud), using ENV D's `club_offduty_cop` look (not `frd_agent` / the FRD windbreaker). Also confirm that `enemy.cartel_gunman`
  (QC-36) works in a STEALTH phase as an observer for `co_op_pickup` (spawned by the QC-25 timed
  hook).

## Lead rulings (D-075; the G0 open questions, closed)
1. **Main hall ceiling:** the validator's scale table gains **`hall`** (6–9 m); G6 is a `hall` with no
   override.
2. **Civilian-mode doors:** staff doors are **not** `civilian_allowed`; civilians stay front-of-house.
   Only guest doors are civilian-allowed (the VIP rope gate is a guest door). The `gear_drop` slots
   moved to the front of house (`gear_wc`, `gear_cloak` across the counter, `gear_booth`,
   `gear_van`) so every one is reachable without a staff door.
3. **Required loot:** **3 safe cash bags** (`loot.cash_bricks` from the office safe); product and count
   cash are bonus.
4. **Crowd:** dancer clusters get **reduced perception** (a crowd-noise multiplier on the cluster
   observer), not none (QC-71a).
5. **Civilian mode at the alarm:** every crew member auto-masks with their full loadout (ENV A
   already does this; QC-75a closed).
6. **Contact:** **The Accountant** (`contact.accountant`), not Reyes: laundering fits him, and Reyes
   runs Rolling Thunder. Fiction, briefing, the casing line and the VO speaker ids
   (`vo.accountant.*`) are updated. ENV B's stub and catalogue test still say `contact.reyes`
   (listed in ENV C's report to the lead).
7. **floor_names:** `["Ground", "Balcony"]`.
8. **Club speakers:** on the **Ambience** bus.
9. **No stealth walk-out:** escape only through the escape zone, as in PD2.
