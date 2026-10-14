# Gallery Night: Halberd Gallery (gallery_night)
Status: APPROVED (lead, 2026-10-11) (D-075). The lead's answers to the G0 open questions are folded in below (see Lead rulings).
Cross-env requests are QC-51..QC-59.

## Fiction
- **Who:** the **Halberd Gallery**, a private Beaux-Arts gallery (built 1908 as the Halberd family's
  picture house, now run by the Halberd Foundation) on the corner of **Aldous Parade** (south, the
  uptown boulevard) and **Wexley Street** (east), with **Pelham Mews** behind it (north) and its own
  walled **Sculpture Court** to the west. The Foundation guards the building with its own in-house
  detail, **Halberd Gallery Security** (ENV D's bottle-green blazer and gold-halberd crest), and runs
  the "Argus" security system: cameras, frame sensors, a laser-guarded **Treasury** and a vault-grade
  **art store** in the basement.
- **What:** four canvases on a collector's **list**: **The Lantern Bearer** (Ines Calloway, the
  centrepiece, unveiled tonight), **The Salt Orchard** (Teodor Wilk, the gallery's poster piece),
  **Widow in Blue** (Henrike Sallow) and **The Tidewater Saint** (Aurel Maske). Where each one is
  tonight varies (on show, in the Treasury, in the art store, on the conservator's bench, in a loan
  crate). Lesser works (studies) on the walls and in the store racks are greed.
- **Why / contact:** **Odile Vance** (fence; jewellery and art jobs; `contact.vance`, Board district
  `uptown`). *"My buyer wants four canvases and the Lantern Bearer above all. Rolled, darling, not
  framed. Frames are for people who want to be caught."* The buyer asked for the Lantern Bearer by
  name (ENV B's loot text), so it is required. Vance pays for every listed canvas and takes the
  studies at a fence's discount.
- **Time / weather:** **23:20**, a clear cold autumn night after rain (wet pavements, no rain
  falling). The **Calloway Unveiling gala** is in its last hour: guests in evening wear on the
  ground floor and in the Sculpture Court, waitstaff at the bar, attendants closing the upper rooms.
  **Last call** comes at a rolled time (Variable table). After it the guests leave and the building
  turns to night mode.
- **Handler:** Mercer on comms. The crew arrives as gala guests at the portico (default), by the
  Mews (driver's side), or on the roof deck (pre-planning spawn choice).

## Modes
- **Stealth + loud** (`HeistDef.mode = STEALTH_OR_LOUD`). Size M (15–25 min stealth, 15–20 min loud).
  Phase P5. It uses the full P2 stealth set (cameras + operator, ECM, keycards, a code door, a
  `hack_terminal`, a laser grid, guard cuffs, the 4-pager cap) and the P3 loud set (all specials,
  Brandt + Aegis, custody, hostages, snipers, AI orders).
- **The gala clock (the heist's signature):** until **last call** the ground-floor public rooms
  (Great Hall, Founders' and Harbour galleries, Drawings Cabinet, Benefactors' Room, cloakroom) and
  the Sculpture Court are **PUBLIC**. The crew can walk them **unmasked** as guests and case, but the
  listed canvases there hang in front of patrons, attendants and a guard. At last call the mission
  walks the guests out through the portico (no alarm), the waitstaff clear the bar, and those zones
  switch to **RESTRICTED** (QC-51). The decision: work BOH and upstairs early while the guests
  distract the guards, or wait for an emptier but fully restricted building. **D-075: approved as
  the signature mechanic** (last call at 8/10/12 min, `last_call_s`).
- **Casing:** unmasked guests may read the wall plaques. Walking within 4 m of a listed canvas marks
  it for the crew (Mercer callout; `[find_canvases]`). Upper galleries, BOH, basement and roof are
  RESTRICTED from the start (slow ×0.35 fill, S1.1). Ladders need the mask.
- **Paintings are LIGHT** (lead ruling D-070, ENV B's rolled-canvas defs): cut from the stretcher in
  4 s (`loot_spawn`, `interaction_time_s 4.0`, silent), carried rolled (×1.0 speed (D-102), sprint and
  jump allowed, throw 4 m).
- **Frame sensors (the hack):** the **Argus** hanging-wire sensors alarm some frames (variable
  `sensor_net`). Cutting an alarmed canvas while the sensors are live raises the alarm. The Argus
  server in the upper server room (`SV`, a CODE door) has a `hack_terminal` (60 s, 1–2
  interruptions) that takes the sensors offline for the rest of the run. Unalarmed frames never need
  it. This is the Framing Frame computer, adapted: optional in stealth, central in loud.
- **Loud: the Argus lockdown.** `alarm_raised` drops steel **shutters** over the Calloway Room arch,
  the Treasury door and the Loading Dock art door, and relocks the art-store vault (keycard reader
  dead). **The same hack lifts the lockdown** (now 120 s, 2–3 interruptions, in the upper BOH
  holdout). The art-store vault door also takes a **thermal drill** (240 s) as the fallback.
- **Difficulty notes:**
  - Routine/Tense: 1–2 guards (hall post + 0–1 rover; `rover_none` 20%) + operator (60%), 3–5 patrons, `sensors_treasury`
    likely.
  - Hazardous/Brutal: 3–4 guards, 5–7 patrons, sweeping/timed lasers favoured, `sensors_all`
    possible, `insurance_inspection` and `vaultline_early` events enabled. **From Brutal the guard
    count plus the operator can exceed the 4-pager cap**: some guards must be ghosted. Intended.
  - Lethal/Cataclysm: 5 guards, Titan cameras (S8.1), `argus_upgrade` enabled.
  - **Solo:** AI teammates wait at the van in stealth (D-014). In loud they carry canvases on
    `carry_bag` orders (LIGHT: no speed penalty worth managing).

## Site
- **Lot:** the gallery is 44 × 30 m (wall centre lines; outer face 44.4 × 30.4 m). Ground FFL 0.0 m.
  Basement under the west and centre bays only (x 0–32, z 0–20). Massing:
  - north service strip (x 0–32, z 0–8): two storeys, flat **roof deck at +9.0** (parapet +10.1);
  - Great Hall (x 12–32, z 8–26): coffered laylight at +9.8, roof +11.0 with a glazed oculus;
  - west and east top-lit galleries: glazed lanterns, roof ridge +13.0 (not walkable, sloped glass);
  - Loading Dock / Conservation Studio (x 32–44, z 0–12): north-light sawtooth roof +9.4/+10.6.
- **Streets and surroundings:**
  - **South: Aldous Parade**, a 22 m boulevard (two carriageways with a planted tree median),
    sidewalks 4 m. The **portico** (at grade, a 1:20 ramp under the red carpet) faces it. Across: the railings and trees of **Linden Park**.
  - **East: Wexley Street**, 14 m (3 + 8 + 3). Across it the **Grand Wexley Hotel** (8 storeys,
    roof terrace +22).
  - **North: Pelham Mews**, an 8 m cobbled service lane. The gallery's loading dock and the
    fire-escape ladder to the roof deck open onto it. Mews house backs (2 storeys, dressing) opposite.
  - **West: the Sculpture Court** (x −16…0, z 0…30), a gravel court with bronzes, a reflecting
    pool and benches, walled 3.0 m (rusticated stone) with a wrought-iron gate onto Aldous Parade
    (x −10…−6). Beyond: the **Ostrander Conservatory** of music (party wall, roof +14).
- **Exterior landmarks:**
  1. the **gilded halberd** over the portico pediment (a 4 m bronze-gilt halberd and the carved
     "HALBERD" frieze), floodlit warm, visible from the whole Parade;
  2. the **lilac gala uplighting** washing the limestone facade and the red carpet (gala only:
     after last call the uplights dim to 20%), visible from the Parade and Wexley Street;
  3. inside, the **Lantern Bearer on the stair landing**: the centrepiece under one spotlight above the
     imperial stair, seen through the bronze doors and from every point of the Great Hall (when
     `cp_landing`; otherwise the empty easel with its "Withdrawn tonight" card).
- **Play space:** x −40…58, z −10…50. Each edge is closed as follows (the `bounds` validator checks
  every one).

### Play-space closure

| Edge | Closure |
|---|---|
| Pelham Mews, west end (x −40) | A 2.4 m solid timber gate across the Mews between the Ostrander back wall and the mews houses (chained). P4 spawns behind it (x −46, z −4). |
| Pelham Mews, north side (z −10) | Mews house backs: 2-storey brick, garages with shut doors, a 2.2 m garden wall. No openings into play. |
| Pelham Mews, east end | Opens onto Wexley Street (the Mews mouth, x 44). |
| Wexley Street, north (z −22) | A parked catering truck and barriers across the street at z −22; the street continues as a vista to a T-junction facade at z −60. P3 spawns behind the truck (x 52, z −28). |
| Wexley Street, east side (x 58) | The Grand Wexley Hotel facade (z −8…30, revolving door locked, lit lobby glazing with blinds) and the next block's facades. No openings into play. |
| Aldous Parade, west end (x −40) | Police barriers and the parked **gala coach** (a liveried shuttle bus) across both carriageways. P1 spawns behind it (x −46, z 44). Beyond: the boulevard as a vista to a bend at x −120 (facade across the axis). |
| Aldous Parade, east end (x 58…74) | Past the Wexley junction, a press van and barriers at x 70. P2 spawns behind them (x 76, z 44). Vista to x 160. |
| Aldous Parade, south (z 50) | Linden Park railings (1.8 m, spear tops), trees behind them, park lamps. Not climbable (railing top is a 45° spear row). |
| Sculpture Court wall (x −16, z 0…30) | 3.0 m stone wall; the Ostrander party wall behind it. The court gate onto the Parade is locked after last call (`padlock`, lockpick 8 s or saw). |
| Roofs | Only the north roof deck (+9.0) is walkable (fire-escape ladder from the Mews; Stair SS head house). The Great Hall roof (+11.0) and the gallery lanterns (+13.0) sit behind 1.1 m parapets with 45° sloped coping (Shadow Ledger rule). The Great Hall roof is a police-only navmesh island (P5) joined to the hall only by one-way rappel links (QC-41). The LD/CS sawtooth roof is pitched glass (no access). |
| Up | Clear night sky, a few high cloud streaks lit orange from the city, a waxing moon low in the west. |
| Far | The uptown skyline over the park (towers 300–800 m away, lit floors), the hotel to the east, the Ostrander to the west. Nothing reachable sees the void. |

### Site plan
1 char = 2 m (x and z), same origin and axes as the floor plans (the gallery's NW corner; +x east,
+z south). `#` the gallery shell, `%` neighbour buildings / dressing blocks, `|` the Sculpture Court
wall, `g` court gate, `a` areaway grate (into PL), `h` fire-escape ladder (Mews → roof deck), `v`
the Mews van (E1), `t` median trees, `P` player spawns (portico default), `P1…P5` police spawns,
`S1`, `S2` sniper perches, `E1`, `E2` escapes.

```
     x -40     -20       0       20      40      60
 -24 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%       %%%%%%%%
     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  P3   %%%%%%%%
 -20 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%       %%%%%%%%
     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% WEXLEY%%%%%%%%
 -16 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% STREET%%%%%%%%
     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%       %%%%%%%%
 -12 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%       %%%%%%%%
     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%       %%%%%%%%
  -8                                                  %%%%%%%%
       PELHAM MEWS (8 m)      h ladder    vvvE1       %%%%%%%%
  -4 P4 X                                             %%%%%%%%
     %%%%%%%%%%%%                                     %%%%%%%%
   0 %%%%%%%%%%%%||||||||#######################      %%%%%%%%
     %%%%%%%%%%%%|SCULPTUREroof deck +9        #      %%%%%%%%
   4 %%%%%%%S2%%%|COURT |#                 LD  #      %%%%%%%%
     %%%%%%%%%%%%|      |#                     #      %%GRAND%
   8 %%OSTRANDER%|      |#                     #      %%WEXLEY
     %%CONSERV.%%|      |# HALBERD GALLERY     #(14 m)%%HOTEL%
  12 %%roof+14%%%|      |#                     #      %%%%%%%%
     %%%%%%%%%%%%|     a|#   galleries +13     #      %%S1 +22
  16 %%%%%%%%%%%%|      |#                     #      %%%%%%%%
     %%%%%%%%%%%%|      |#       GH roof +11   #      %%%%%%%%
  20 %%%%%%%%%%%%|      |#                     #      %%%%%%%%
     %%%%%%%%%%%%|      |#                     #      %%%%%%%%
  24 %%%%%%%%%%%%|      |#                     #      %%%%%%%%
     %%%%%%%%%%%%|      |#                     #      %%%%%%%%
  28 %%%%%%%%%%%%|      |#          P5^        #      %%%%%%%%
     %%%%%%%%%%%%|||gg|||###########P###########      %%%%%%%%
  32                             portico
                                  E2 limo
  36 
        ALDOUS PARADE (boulevard, 22 m, tree median)
  40 
       t  t  t  t  t  t  t  t  t  t  t  t  t  t  t  t  t  t  t
  44   P1 barriers                                        P2
     
  48 
     
  52 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
     %%%%%LINDEN PARK railings + trees%%%%%%%%%%%%%%%%%%%%%%%%
  56 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
```

## Floor plans
1 char = 1 m. Each character is a **grid point** (x = col, z = row). Lines are **wall centre
lines**: exterior 0.5 m (load-bearing limestone, outer face +0.2), interior 0.2 m, art-store vault
walls 0.4 m reinforced (`%`). Origin: the building's NW corner; +x east, +z south (the Mews at the
top, Aldous Parade at the bottom). Rulers in metres. The plans are generated by
`tools/levelcheck/plans/gallery_night_floors_ascii.py` (room rectangles in metres; to be written at
G1 from the draft script used for this doc). Its `--check` mode verifies that the rooms tile each
footprint exactly, that every door sits on a wall, that every room has a door, and the stair
arithmetic below.

Legend: `#` exterior wall, `|`/`-` interior wall, `+` wall junction, `%` vault wall, `D` door
(0.9–1.2 m; `DD` 1.8 m double), `A` wide opening / arch (2.4–4.0 m, no leaf), `S` arch with a
**lockdown shutter** (loud), `R` roller door (3.6 × 4.5 m), `VV` vault door (2.0 × 2.2 m), `W`
window, `^ v` stair flights (up toward the arrow), `l` stair landing, `r` 1.1 m balustrade
(guard with handrail top), `:` laser grid, `=` bar counter (1.1 m), `L` painting slot (list
canvas or study, see Loot), `K` keycard slot, `S K` in CO = office safe and keycard, `H` hack
terminal, `T` thermal-drill point, `G` guard post / pause point, `c` civilian working position,
`[==]` art-store painting racks (pull-out mesh screens), `bb` consignment lockers (`deposit_box`),
`mon`/`o` camera station / operator seat, `h` roof-deck fire-escape ladder top, `P` player spawn.

**Vertical data** (`HeistMap.floor_heights = [-4.2, 0.0, 5.4, 9.0]`, `floor_names = ["Basement",
"Ground", "Upper", "Roof"]`, D-054; ascending and contains 0.0, D-040). The roof deck is listed
because Stair SS and the fire-escape ladder arrive on it.

| Level | FFL | Ceiling | Floor-to-floor / slab | Notes |
|---|---|---|---|---|
| Basement | −4.2 | 3.0 (BOH); **3.4** art store and plant | 4.2 (1.2 m services void under the ground slab: the art store's climate ducts) | storage/corridor 2.6–3.0 ✓; vault and plant 2.6–6.0 ✓ |
| Ground | 0.0 | galleries, vestibule, cloakroom, shop **4.5**; Great Hall **9.8** (atrium, coffered laylight); north BOH strip **3.0**; Loading Dock 4.5 | 5.4 (0.9 m plenum over 4.5 rooms; **2.4 m services void over the 3.0 m BOH strip**, see Lead rulings Q4) | gallery 4.5–6.5 ✓ (D-075; 4.5 is the band floor); lobby/retail 3.0–4.5 ✓; atrium ≤ 10 ✓; office/corridor 3.0 ✓; loading 3.5–6 ✓ |
| Upper | 5.4 | top-lit galleries **6.0** to the laylight; balconies and loggia open to the hall ceiling (4.4 above them); BOH 3.0; Conservation Studio 4.0; Treasury 4.0 | 3.6 to the roof deck (BOH); the galleries rise to the lanterns | gallery 4.5–6.5 ✓ (D-075); balconies/loggia `atrium` ≤ 10 ✓; office 2.6–3.0 ✓; workshop 3.5–6 ✓; vault 2.6–6 ✓ |
| Roof deck | 9.0 | open; head house and lift motor room 2.7 clear | — | parapet 1.1 m |
| Stair SS (service) | −4.2 → 0.0 | U-stair, 2 flights × 12 risers @ 0.175 m, tread 0.28 m (run 3.08 m), width 1.2 m | 24 risers = 4.2 ✓ | landing every 12 ≤ 16 ✓ |
| Stair SS | 0.0 → 5.4 | 2 flights × 15 risers @ 0.180 m, tread 0.28 m (run 3.92 m) | 30 risers = 5.4 ✓ | landing every 15 ≤ 16 ✓ |
| Stair SS | 5.4 → 9.0 | 2 flights × 10 risers @ 0.180 m (run 2.52 m) | 20 risers = 3.6 ✓ | head house on the roof deck |
| Grand (imperial) stair | 0.0 → 2.7 → 5.4 | central flight x 20.8–23.2 (2.4 wide), 15 risers @ 0.180, tread 0.30 (run 4.2 m), rising north from z 14.4 to the half landing (z 8.2–10.2, x 15.0–29.0, +2.7); two return flights x 15.0–16.6 and x 27.4–29.0 (1.6 wide), 15 risers each, rising south to z 14.4 and onto landings (z 14.4–16.4) that join the west and east balconies at +5.4 | 15 + 15 = 5.4 ✓ | landing every 15 ≤ 16 ✓; stone balustrades 1.1 m both sides; headroom under the half landing 2.4 m ✓ (the staff door under it) |
| Areaway ladder | −4.2 → 0.0 | fixed ladder, 4.2 m, from the PL floor to the court grate | — | `ladder` prefab, masked only, no bags (S10.1b) |
| Fire-escape ladder | 0.0 → 9.0 | caged fixed ladder on the north facade (x 10), from the Mews to the roof deck; the bottom 2.4 m is a counterweighted drop section (down by default) | — | `ladder` prefab `height_m 9.0`, masked only, no bags |

**Stair core fit** (SS: 3.0 × 8.0 m centre lines, 0.3 m walls → 2.7 × 7.7 m clear): flights 1.2 +
0.2 well + 1.2 = 2.6 ≤ 2.7 ✓. Along z, the longest storey (5.4 m, 3.92 m run) needs 1.35 floor
landing (it takes the whole 1.0 m stair door at z 6.5–7.5) + 3.92 + 1.30 half landing = 6.57 ≤ 7.70 ✓. Every up-flight starts at the same edge, so the
shorter runs leave a deeper half landing. Headroom under each return flight ≥ 3.3 m ✓ (one storey).
The stair door (1.0 m) is on the **east wall at the south floor landing** (x 3, z 6.5–7.5) on every
level and opens onto a level landing, never a flight. Vision panel 0.15 × 0.6 m in each door.

**Ceiling bands (D-075: no per-room overrides).** The lead added a **`gallery`** purpose of
**4.5–6.5 m** (top-lit) to the validator's scale table, so no room here carries a `ceiling_range`
override:
- **UG1, UG2, UG3** (top-lit picture galleries): a Beaux-Arts picture gallery lit from a laylight
  hangs large canvases up to two high; 6.0 m to the laylight over a 12 × 12 m room is the classic
  proportion (the walls need ~4.2 m of hang plus a cove). The laylight and its lantern attic sit
  above (plenum, not playable). Purpose `gallery`, inside the band.
- **WG, DC, EG, EB** (ground galleries, 4.5 m): purpose `gallery`, on the band floor (4.5).
- **BW, BE, SL** (balconies and loggia, open to the Great Hall's ceiling 4.4 m above them): purpose
  **`atrium`** (≤ 10), since they are the upper edge of the hall's volume, not separate rooms.

Every other room is in its purpose's band. The Great Hall uses `atrium` (≤ 10).

**Wide openings.** Gallery arches (2.4–4.0 m wide, 3.6 m high, no leaf) are openings in the wall,
not `door` prefabs; the three shuttered ones (`S` and the LD art door) carry a `door` prefab with
`kind = "industrial_door"` (D-064 rule: 2.4–4.0 wide × 2.1–4.5 high), `starts_open` true for the
Calloway arch, `lock BARRED` set by the mission on lockdown.

### Basement (FFL −4.2; x 0–32, z 0–20)
```
      012345678901234567890123456789012
    0 #################################
      #^v|LK    |FR FRAMES|QR     |LF #
    2 #^v|      |         |       |   #
      #^v|WC    |         | L     |   #
    4 #^v|      |         |       |   #
      #^v|      |         |       |   #
    6 #  +--D---+----D----+---D---+DD-#
      #  D    BB            T         #
    8 #--+-D------%%%%%%%%%VV%%%%%%%%%#
      #PL PLANT   %AS ART STORE       #
   10 #           %                 bb#
      #           % [==]  [==]  [==]  #
   12 #           % L               bb#
      #           % [==]  [==]  [==]  #
   14 # H^        %                 bb#
      #           % [==]  [==]  [==]  #
   16 #           %             L   bb#
      #       G   % [==]  [==]  [==]  #
   18 #           %       L           #
      #           %                   #
   20 ############%%%%%%%%%%%%%%%%%%%%#
```

Basement notes:
- `VV` at (21–22, 8) is the art-store **vault door** (`door` lock VAULT, `width_m 2.0`, opened by the
  `keycard_reader` beside it; stealth only). `T` (22, 7) is its thermal-drill point (loud, 240 s).
- `bb` are the **consignment lockers** (auction lots awaiting the Friday sale): `deposit_box` ×
  `consignment_lockers` (4/6/8), saw targets, small loot.
- The racks hold **studies** (`loot.painting_study`, `store_paintings` 4/6/8) and the list canvases
  when their slot is `*_store`.
- `H^` (2, 14) marks where PL meets the areaway (QC-64): the ladder stands in a 2 × 2 m **light well** at x −4…−2,
  z 13–15 under the court grate `a` (−4, 14), with a short passage / opening through the basement wall at x 0 into PL.

### Ground floor (FFL 0.0)
```
      012345678901234567890123456789012345678901234
    0 #####W#########W#####W#############RRRR##D###
      #^v|BR   |WC|SC   |RG   |J|E|LF |           #
    2 #^v|     |  |     |     | | |   D LD LOADING#
      #^v|     |  |mon  |     | | |   D           #
    4 #^v|     |  | o   |     | | |   D           #
      #^v|     |  |     |     | | |   |           #
    6 #  +-D---+D-+---D-+-D---+D+D+DD-+ crates    #
      #  D    BC BACK CORRIDOR        D           #
    8 #--+-DD-----+------D------------+           #
      #WG FOUNDERS|  llllllLlllllll   |     L     #
   10 #GALLERY    |  v     ^^^    v   |           #
      #           |  v     ^^^    v   |           #
   12 D           A  v     ^^^    v   +----DD-----#
      D           A  v     ^^^    v   |EG HARBOUR #
   14 #           A        ^^^        |           #
      #           A        rope       |           #
   16 #L     L  L |                   AL          #
      #           |         G         A           #
   18 #    G      |=====              A          L#
      #           |bar   c  c   c     A           #
   20 #--D---+----+                   |    G      #
      #DC    |WCW |                   |           #
   22 #DRAWINGS   D           c  c    |     L     #
      #      |    | GH GREAT HALL     |           #
   24 #      |    |                   +---AAAA----#
      #      +----D                   |EB         #
   26 # L L  |WCM +--D--+--AAA--+-D---+           W
      #      |    |CK   |VE     |GS   |           #
   28 #      |    |     |       |     | L      L  W
      #      |    |     |       |     |           #
   30 #############W##W##DDDD#####W##W##W###W###W##
```

Ground notes:
- The Great Hall's **imperial stair**: half landing `l` (+2.7) against the north wall, central flight
  `^` (rising north), return flights `v` (rising south to the balconies). The centrepiece slot
  `cp_landing` is the `L` on the landing wall (picture centre +2.7 + 1.55 = 4.25 m: its own
  spotlit easel-frame, the validator's `picture` rule measured from the landing).
- `D` (19, 8) is the **staff door under the stair** (BC → Great Hall, LOCKPICK, NPC-authorised),
  2.4 m under the landing soffit.
- `rope` = the velvet rope and stanchions at the stair foot (the upper floor is closed to guests);
  a guard post (`post_hall`) stands at (22, 17).
- The `A` arches into WG (x 12, z 12–16) and EG (x 32, z 16–20) are 4.0 m wide. The EG → EB
  opening (z 24, x 36–40) is 4.0 m.
- `DD` (37–38, 12) is the **LD → EG art door** (2.0 m sliding fire door, KEYCARD reader on the LD
  side; shuttered in loud).
- `D` (0, 12–13) are the **Sculpture Court French doors** (`court_doors` variable).
- LF (art lift) opens S to BC and E to LD (through car).

### Upper floor (FFL 5.4)
```
      012345678901234567890123456789012345678901234
    0 #####W########W#####W########################
      #^v|CO    |AO    |UW|F|SV   |LF |           #
    2 #^v|      |      |  | |     |   D CS        W
      #^v|S K   |      |  | |   H |   D           #
    4 #^v|      | K  c |  | |     |   D (N-light) W
      #^v|      |      |  | |     |   |           #
    6 #  +--D---+---D--+D-+D+--D--+DD-+           W
      #  D    UC UPPER CORRIDOR       D           #
    8 #--+--------+D----------------D-+   L  L    W
      #UG1        |  r             r  |           #
   10 #CALLOWAY   |BWr             rBE|       K   W
      #     L     |  r             r  |           #
   12 #           S  r (void over GH) +---D-------#
      #           S  r             r  |UG3        #
   14 #L          S  l             l  |MARITIME   #
      #     G     |  l             l  |         L #
   16 #           |  l             l  A           #
      #         L |  r             r  A           #
   18 #           |  r             r  A L         #
      #           |  r             r  |     G     #
   20 #---AAA-----+  r             r  |           #
      #UG2 SALLOW |  r             r  |           #
   22 #           |  r             r  |       L   #
      #           |  r             r  |           #
   24 #           |  r             r  +D--+--D----#
      #L    L     |  r             r  |AT |TR     #
   26 #           +--rrrrrrrrrrrrrrr--+   |:::::::#
      #     G     A         G         |   |       #
   28 #         L A   SL SOUTH LOGGIA D   |   L   #
      #           |                   |   |       #
   30 ################W###W###W###W################
```

Upper notes:
- `BW`, `BE` are the 3 m balconies over the Great Hall (x 12–15, x 29–32), `SL` the south loggia
  (z 26–30) above the vestibule. Balustrade `r` 1.1 m (stone, solid to 0.9 m, bronze handrail).
  The return-flight landings `l` (z 14–16) join the balconies.
- `S` (12, 12–14) is the **Calloway arch** (3 m) with its lockdown shutter.
- The **Treasury** (TR) door `D` (39, 24) is KEYCARD + shutter. The laser grid `:` spans the room
  at z 26.5 (x 36.2–43.8, full width, 0–2.6 m), between the door and the painting wall.
- `SV` (server room) door `D` (25, 6) is a **CODE door** (`code_group argus`; `keypad` on the UC
  side). `H` is the Argus `hack_terminal`.
- `CS` (Conservation Studio) is reached from UC (x 32, z 7), the art lift (E door) and UG3 (door
  (36, 12), LOCKPICK).

### Roof deck (+9.0; north strip only)
```
      012345678901234567890123456789012345678901234
    0 #HH#######h######################
      #^v|                        |LM #
    2 #^v| ROOF DECK +9.0         |   #
      #^v|                        |   #
    4 #^v|  AHU  AHU    cond.     |   #
      #^v|                        |   #
    6 #  |        P  P  P  P      +---#
      #  D                            #
    8 #################################
```

Roof notes: `HH` Stair SS head house (roof door `D` (3, 7): LOCKPICK 8 s from the deck, push bar
inside), `LM` lift motor room (locked, no interaction), `h` the fire-escape ladder top (x 10, z 0).
`P` = the roof spawn (`pp_spawn_roof`). The south edge (z 8) is the Great Hall / UG1 wall rising to
+11.0 / +13.0 (no openings); the east edge is the LD/CS sawtooth glass (not walkable). AHUs and
condensers are hard cover.

## Room list
Sizes are between wall centre lines. Gallery windows: the galleries are top-lit and their street
walls are blind arcades (no glazing) except EB, whose three tall windows (sill 0.9) face the Parade
and Wexley St with closed blinds. Vestibule, cloakroom and shop have shop-front glazing from 0.3 m.

| id | purpose (`RoomVolume.purpose`) | size m | ceiling m | kit | notes |
|---|---|---|---|---|---|
| SS | stair | 3 × 8 | open | — | Basement → ground → upper → roof deck. Doors E at every level; head house on the roof. |
| LF | elevator (art lift) | 4 × 6 | — | — | **`bag_lift`** `art_lift`: a 2.6 × 5.6 m car for large canvases, 3 landings (−4.2 / 0.0 / 5.4), 4 bags per cycle, 10 s. Doors S (BB, BC, UC) and E (LD at ground, CS at upper). Staff use it; guards never ride it. |
| LK | locker_room (with WCs) | 7 × 6 | 3.0 | `locker_room` | Staff and attendant lockers, bench, 2 WC cubicles, sink. `cower` points along the lockers. |
| FR | storage (frame store / packing) | 10 × 6 | 3.0 | `storage_frames` | Empty frames on racks, crate timber, packing tables, a pallet truck. BODY_HIDE (2, in empty crates). |
| QR | storage (quarantine) | 8 × 6 | 3.0 | `storage_quarantine` | Incoming loans acclimatise here in **crates** (humidity loggers). `orchard_quarantine` slot: The Salt Orchard back from a loan, in an opened travel crate (cut 4 s; the crate lid is off). |
| BB | corridor (basement) | 29 × 2 | 3.0 | `corridor_service` | Spine; the vault door and its thermal-drill point; camera C12 (E end). |
| PL | plant | 12 × 12 | 3.4 | `plant_climate` | Air-handling units, humidifiers, chillers, the inert-gas suppression cylinders (dressing). **Areaway ladder** `H^` to the court grate. BODY_HIDE (2, behind the AHU). |
| AS | vault (art store) | 20 × 12 | 3.4 | `art_store` | **The vault.** Pull-out mesh painting racks (12 screens), plan chests, the consignment lockers (`deposit_box`). Studies on the screens (`loot_spawn` `loot.painting_study` × `store_paintings`). Slots `cp_store`, `saint_store`. Camera C14 (always live). Vault door on the N wall (x 21–22, z 8), off BB. |
| SS-roof / HH | stair (head house) | 3 × 8 | 2.7 | — | Roof door LOCKPICK. |
| BR | break_room (staff + caterers' servery) | 6 × 6 | 3.0 | `break_room` | Fridge, counter + sink, microwave, coffee, table with 6 chairs, bulletin board, the caterers' glass racks and ice tubs (gala). Window N (Mews). |
| WC | restroom (staff) | 3 × 6 | 3.0 | `restroom_multi` | 2 cubicles, sink. |
| SC | security_room | 6 × 6 | 3.0 | `security_office` | **`camera_station` with its monitor wall on the west wall** (WC partition); the operator sits at (13.5, 3.5) facing **west**. Door S (16, 6) is ≈ 135° off his facing (outside the 120° FOV). Key cabinet on the east wall (`kc_security`), the **guard log** on the NE counter (`code_security_log`), lockers, kettle, phone, `alarm_button` on the console. Window N (Mews, frosted). |
| RG | office (registrar) | 6 × 6 | 3.0 | `office_registrar` | Loans and shipping desk, condition reports, crate labels, `kc_registrar` (desk drawer), phone. Window N. |
| J | janitor | 2 × 6 | 3.0 | `janitor_closet` | Mop sink, cleaner's cart, shelving. BODY_HIDE (1). |
| E1 | electrical | 2 × 6 | 3.0 | `electrical_closet` | Sub-board, the Argus field panel (dressing), telecom. |
| BC | corridor (back corridor) | 29 × 2 | 3.0 | `corridor_service` | BOH spine: SS, BR, WC, SC, RG, J, E1, LF, the WG art-handling door, the staff door under the stair, the LD double door. C5 (W end, looks E). |
| LD | loading (dock) | 12 × 12 | 4.5 | `loading_dock_gallery` | Roller door N (Mews, 3.6 m), personnel door N (LOCKPICK), double door W (BC), the art lift E door, the **art door** S to EG (KEYCARD). Crate staging, an A-frame trolley, a forklift-free dock leveller, a parked art-transport van tail at the roller door (dressing). `xl_crate` slot (L at (38, 9)). |
| GH | atrium (Great Hall) | 20 × 18 | **9.8** (coffered laylight; 5.1 under the balconies) | `great_hall_gala` | **Landmark.** The imperial stair, the gala bar (1.1 m `counter_bar`, x 13–17), cocktail tables, a string-trio stage (dressing), the velvet rope, 2 benches. `cp_landing`. Under the half landing: the staff door. The ceiling median is 9.8 (the void is 252 of 360 m²). C2 (ceiling mount under the east balcony, 5.1 m). |
| VE | lobby (vestibule) | 8 × 4 | 4.5 | `vestibule_bronze` | Bronze outer doors (4 leaves, open until last call, then locked), glass inner screen, the guest list lectern. C1 over the inner screen looking N. |
| CK | reception (cloakroom) | 6 × 4 | 4.5 | `cloakroom` | 0.9 m service counter, coat rails, the **tip jar and cash box** (`small_loot`). An attendant until last call. |
| GS | retail (gift shop) | 6 × 4 | 4.5 | `gift_shop` | Closed for the gala: shutter down on the VE side (shop front, not a door); the door (28, 26) opens from GH (LOCKPICK). Till (`small_loot`), print racks, books. Shop-front glazing to the Parade. |
| WG | gallery (Founders' Gallery) | 12 × 12 | 4.5 | `gallery_hang` | 19th-century portraits. French doors W to the Sculpture Court (`court_doors`), art-handling door N to BC (`DD`, LOCKPICK). `widow_founders` slot + 2 studies. C3. |
| DC | gallery (Drawings Cabinet) | 7 × 10 | 4.5 | `gallery_cabinet` | Low-light room (50 lux) for works on paper: wall vitrines and 2 studies. Dead end **with a reason** (a cabinet room). |
| PWW, PWM | restroom (public) | 5 × 5 each | 3.0 (dropped ceiling; 1.5 m void above, Lead rulings Q4) | `restroom_public` | 3 cubicles each, marble vanity. Doors to GH. |
| EG | gallery (Harbour Gallery) | 12 × 12 | 4.5 | `gallery_hang` | Marine paintings. Arch W (GH), opening S (EB), art door N (LD). `saint_harbour` + 2 studies. C4. |
| EB | gallery (Benefactors' Room) | 12 × 6 | 4.5 | `gallery_hang` | Donor wall, two sofas, the gala's silent-auction table (catalogues). `orchard_benefactors` + 1 study. Windows S and E (blinds). |
| UC | corridor (upper) | 29 × 2 | 3.0 | `corridor_office` | Doors to CO, AO, SV (CODE), UW, FS, LF, CS, BW, BE. C13 (W end, looks E). |
| CO | office (curator) | 7 × 6 | 3.0 | `office_curator` | Margit Sorell's office: desk, reading table with catalogues, a **wall safe** (`safe` SMALL, `methods [drill, lockpick, saw]`, 3 `small_loot`), `code_curator_planner`, phone, window N. Her lanyard keycard is on her, not here (`kc_curator`; approved D-075). |
| AO | office (development / admin) | 7 × 6 | 3.0 | `office_open` | 4 desks, printer, gala seating plans, `code_admin_postit` (monitor post-it), a working PA (`c`, `civ_admin`, rare). |
| SV | server_room (Argus) | 6 × 6 | 3.0 | `server_room` | Racks, UPS, the Argus head-end with the **`hack_terminal`** (`objective_tag hack`). CODE door. No window. |
| UW | restroom (staff) | 3 × 6 | 3.0 | `restroom_single` | WC, sink. |
| FS | storage (frame and plinth store) | 2 × 6 | 3.0 | `storage_frames` | Plinths, spare frames. BODY_HIDE (1). |
| CS | workshop (Conservation Studio) | 12 × 12 | 4.0 | `conservation_studio` | North-light sawtooth glazing, 3 easels, a suction table, a microscope cart, solvents cabinet, `kc_conservator` (bench drawer). `widow_conservation` slot (on the main easel, frame off). A conservator works late (`conservator`). Windows E. |
| BW, BE | atrium (balconies; D-075) | 3 × 18 each | 4.4 (to the hall ceiling) | `gallery_balcony` | Sculpture on plinths, benches, the balustrade (throw spot to the hall). |
| SL | atrium (south loggia; D-075) | 20 × 4 | 4.4 | `gallery_balcony` | Busts, a long bench, 4 tall windows S over the Parade (sill 0.9). Pause point `G` (22, 27). |
| UG1 | gallery (Calloway Room, top-lit) | 12 × 12 | **6.0** (`gallery` 4.5–6.5, D-075) | `gallery_toplit` | The Calloway retrospective. Shuttered arch E (BW), arch S (UG2). `orchard_calloway` + 2 studies. C9. |
| UG2 | gallery (Sallow Room, top-lit) | 12 × 10 | **6.0** | `gallery_toplit` | Portraits. Arches N (UG1) and E (SL). `widow_sallow` + 2 studies. |
| UG3 | gallery (Maritime Room, top-lit) | 12 × 12 | **6.0** | `gallery_toplit` | Arch W (BE), door N (CS, LOCKPICK), doors S to AT and TR. `saint_maritime` + 2 studies. C10. |
| AT | staff_room (attendants' station) | 4 × 6 | 3.0 | `attendant_station` | Lockers for the white gloves, a kettle, the upper `phone` and `alarm_button`, the condition-check torches. Doors N (UG3) and W (SL). |
| TR | vault (Treasury) | 8 × 6 | 4.0 | `treasury_cabinet` | Strong-room cabinet for the most valuable works on show: KEYCARD door + shutter, the **laser grid** across the room, one wall for one painting (`cp_treasury`, centred on the south wall) and 2 vitrines (`display_case`, `glass_breaks_alarm`, Calloway's sketchbooks as small loot). C11 (always live). |
| X1 | exterior (Aldous Parade + portico) | 98 × 22 | — | `exterior_boulevard` | Red carpet, rope lines, lilac uplights, sodium-white street lamps, the median trees, parked limousines, the gala coach. |
| X2 | exterior (Wexley St + Mews) | — | — | `exterior_mews` | Cobbles, the Mews bins (`body_container` ×2, BODY_HIDE), the fire-escape ladder, the caterers' van, the hotel canopy across Wexley St. |
| X3 | exterior (Sculpture Court) | 14 × 30 | — | `exterior_court` | Gravel, 5 bronzes on plinths, a reflecting pool (rim + depth ≤ 0.35 m, a step, not OOB; Build rulings B4), benches, standing heaters and the smokers' ashtray stand (gala), the areaway grate, the gate. |
| X4 | exterior (roof deck) | 25 × 8 + 4 × 2 (S of LM) | — | `exterior_roof` | AHUs, condensers, cable trays, the ladder top, the head house. |
| LM | plant (lift motor room, roof) | 4 × 6 | 2.7 | — | Locked, no door to the crew (BARRED, no interaction); dressing only. |

Support-space check (level_standards §2.2):
- restrooms: public PWW/PWM (ground), staff WC (ground), LK WCs (basement), UW (upper) ✓;
- break room BR (+ AT on the upper floor) ✓; janitor J ✓; electrical E1, IT/server SV ✓;
- loading / back entrance: LD on the Mews ✓;
- 3 floors + roof deck: Stair SS plus the **grand stair** (2 stair cores for > 2 floors; the
  basement's second egress is the areaway ladder, a plausible plant egress, as Night Deposit) ✓;
- fire exits: the portico, the LD personnel door, the court French doors, the roof deck via the
  fire-escape ladder. The longest travel to an exit is ≈ 50 m (UG2 SW corner → UG1 → the Calloway arch → BW →
  grand stair → VE → portico; SL does not open onto the balconies, the plan has wall stubs at x 13–14 / 30–31) ✓
  (no travel limit in level_standards; Stair SS → roof is the second upper egress).

**NPC placement for ENV D's ambient clips (characters.md v1.9, lead note):**
- `curator_inspect`: every listed-canvas slot and every study on a gallery wall hangs with its
  **centre at 1.55 m** (inside the 1.45–1.6 m picture rule). Each gallery wall that the curator or an
  attendant inspects has an **inspection PatrolPoint 0.80 m in front of the wall** (facing it) with
  **≥ 0.73 m clear behind the NPC** (so ≥ 1.53 m from the wall). Benches, plinths and stanchions stay
  ≥ 2.0 m off hung walls. The `cp_landing` easel-frame centre is 1.55 m above the landing.
- `cower_stand`: civilian cower points (`CivilianCower` PatrolPoints, tag `cower`) sit **0.21 m in
  front of a wall**, back to it: along the GH north wall either side of the staff door, the WG/EG
  walls between hung works, the CK counter back wall, the BR and AT walls.
- `cower_seated` for the patrons at the GH benches and EB sofas; `walk_text` for the waitstaff and the
  admin PA between rooms.

## Circulation
- **Public (until last call):** Aldous Parade → portico → VE → GH (bar, stair foot) ↔ WG ↔ DC; GH ↔
  EG ↔ EB; GH ↔ PWW/PWM; CK. GH west → WG French doors → Sculpture Court (when `court_doors_open`)
  and the court gate → Parade. The upper floor is roped off.
- **After last call:** guests leave over 60 s by the portico (QC-51); the bronze doors are locked by
  the hall guard; everything inside is RESTRICTED. The waitstaff move to BR (servery) and leave by
  the LD personnel door at last call + 120 s.
- **Staff:** BC is the BOH spine. Upstairs by SS or the art lift. Attendants use the grand stair
  (they are civilians).
- **Guards** (one `halberd` PatrolGraph across all floors linked through SS and grand-stair points,
  plus a `mews` graph; ≥ 3 loops per post):
  - **`post_hall` (fixed, ground):** the stair foot (22, 17) facing S over the hall (pause `look`,
    30–60 s) with three loops: (a) GH circuit → VE → CK → GH; (b) GH → WG → DC → WG → GH; (c) GH → EG
    → EB → EG → GH. After last call he locks the bronze doors (one scripted pause at VE).
  - **`rover_ground`:** (a) BC W → WG (art door) → GH → staff door → BC E → LD → BC; (b) BC → SC
    (coffee pause, 20 s) → BC → RG → BC; (c) LD → EG (art door) → GH → staff door → BC → LD.
  - **`rover_upper`:** (a) UC → BW → UG1 (pause facing the Calloway hang 8 s) → UG2 → SL → BE → UC;
    (b) UC → BE → UG3 → AT (kettle) → SL → BW → UC; (c) UC → CO door → SV door → CS → UG3 (TR door
    check, 6 s) → BE → UC.
  - **`rover_basement`:** (a) BB W → PL (pause at the areaway ladder) → BB; (b) BB → vault door
    (pause 8 s) → QR → BB E; (c) BB → FR → LK → BB → SS landing.
  - **`dock_smoker` (`mews` graph):** LD personnel door ↔ Mews bins ↔ ladder foot ↔ Mews mouth (pause
    `smoke` 20–40 s). Loop variants: (a) clockwise, (b) via the caterers' van, (c) into LD (crates).
  - **Operator:** seated in SC. **Halberd guards are `enemy.security_officer` with ENV D's
    `gallery_guard` / `gallery_guard_b` visuals** (pagers: `gallery_guard` is a pager role).
- **Civilians:**
  - **Margit Sorell (curator, `gallery_curator`)**: until last call she hosts in GH (`curator_hall`:
    bar ↔ stair foot ↔ WG/EG inspection points, `curator_inspect`) or works upstairs
    (`curator_office`: CO ↔ UG1 inspection ↔ CS ↔ SV door). After last call: CO ↔ UG1 ↔ AS (via
    SS and her keycard; she opens nothing for the crew). **She carries `kc_curator` on her lanyard.**
  - **Attendants (`gallery_attendant`, 2):** posts at the stair rope (until last call), WG/EG (one
    each), then the upper rooms (closing checks with `curator_inspect`), AT break.
  - **Waitstaff (`gallery_waitstaff` = `npc_penthouse_staff`, 1–2):** bar ↔ GH tables ↔ BR (servery),
    `walk_text` between.
  - **Patrons (`gallery_patron`, `_b`, `npc_penthouse_guest_a/_b`; `patrons` 3–9):** GH, WG, EG, EB,
    the Sculpture Court (smokers). `stragglers` (0–2) stay after last call in GH/EB.
  - **Conservator (`conservator` = `cons_late`; reuses `gallery_attendant_b`, QC-58):** CS easel ↔
    microscope ↔ UW ↔ AT kettle (50–80 s away from the easel).
  - A panicked civilian runs to the nearest `phone` / `alarm_button` (S3.1). Phones: CK, RG, SC, CO,
    AO, CS, AT, BR; alarm buttons: SC console, AT, VE lectern. Fleeing out of the portico before last
    call counts as leaving the map (alarm).

### Guard, staff and civilian roster (spawn data)

| NPC (D role id) | Count | Presence | Spawn tags | Idle activity | PatrolPoint tags |
|---|---|---|---|---|---|
| Security Officer, hall (`gallery_guard`) | 1 | always (fixed spawn) | `guard_hall` | `look` | `guard`, `guard_ground` |
| Security Officer, ground rover (`gallery_guard`) | 0–1 | `guard_post` = `rover_ground` | `guard_rover_ground` | — | `guard`, `guard_ground` |
| Security Officer, upper rover (`gallery_guard_b`) | 0–1 | `rover_upper` | `guard_rover_upper` | — | `guard`, `guard_upper` |
| Security Officer, basement rover (`gallery_guard`) | 0–1 | `rover_basement` | `guard_rover_basement` | — | `guard`, `guard_basement` |
| Security Officer, dock smoker (`gallery_guard_b`) | 0–1 | `dock_smoker` | `guard_mews` | `smoke` | `guard_mews` |
| Camera operator (`gallery_guard_b`) | 0–1 | `security_room_staffed` | CAMERA_OPERATOR in SC | `desk_work` | — |
| Insurance inspectors (`gallery_guard`) | 2 | rare `insurance_inspection` (timed spawn at LD, QC-25) | `guard_inspection` | — | `guard` |
| Vaultline couriers (`armored_car_crew`) | 2 | rare `vaultline_early` (timed spawn at LD) | `guard_vaultline` | — | `guard_vaultline` |
| Curator Margit Sorell (`gallery_curator`) | 1 | always; route by `curator_route` | `civ_curator` | `curator_inspect` / `desk_work` | `staff`, `staff_curator` |
| Attendant (`gallery_attendant`) | 2 | always | `civ_attendant` | `curator_inspect` / `browse` | `staff`, `staff_attendant` |
| Waitstaff (`gallery_waitstaff`) | 1–2 | until last call + 120 s | `civ_waitstaff` | `walk_text` / `browse` (bar) | `staff`, `staff_bar` |
| Conservator (`gallery_attendant_b`, QC-58) | 0–1 | `conservator` = `cons_late` | `civ_conservator` | `desk_work` (easel) | `staff`, `staff_cs` |
| Admin PA (cast `gallery_admin`, QC-58c, ENV D 50265303) | 0–1 | rare `late_paperwork` | `civ_admin` | `desk_work` | `staff`, `staff_admin` |
| Patrons (`gallery_patron`) | 3–9 | `patrons` scalar; `stragglers` after last call | `civ_patron` (GH ×4, WG ×2, EG ×2, EB ×2, court ×2) | `browse` / `sit` / `smoke` (court) | `civilian`, `civilian_court` |

**Totals per difficulty** (guards from `guard_post` picks with `difficulty_add`):

| Difficulty | Guards (hall + rovers/smoker) | Operator | Pagers to clear every guard | Civilians before / after last call | Notes |
|---|---|---|---|---|---|
| Routine | 1 + 0–1 = **1–2** | 60% | 1–3 | 7–10 / 4–7 | |
| Tense | 1 + 0–1 = **1–2** | 60% | 1–3 | 8–12 / 4–8 | Same guard_post pick as Routine (GN-B1 Q2: the Variable table rules). |
| Hazardous | 1 + 2 = **3** | 65% | 3–4 | 9–14 / 5–8 | |
| Brutal | 1 + 3 = **4** | 75% | 4–5 | 10–15 / 5–9 | Exceeds the cap with the operator. |
| Lethal / Cataclysm | 1 + 4 = **5** | 75% | 5–6 | 10–15 / 5–9 | Ghost 1–2 guards; Titan cameras. |

Cable ties: 2 per player (+2 with `asset.extra_cable_ties`). The curator is the one civilian worth a
tie (her keycard, QC-52). Solo means **waiting for last call and avoiding** civilians.

## Sightlines
- **Hall guard** (22, 17) facing S: sees VE, the bar, the hall floor and anyone at the stair foot.
  The **staff door under the stair** (19, 8) is 9 m behind him: BC ↔ GH crossings are safe while he
  faces S, and visible while he walks loop (b)/(c) back. The balconies are 5.4 m up and behind his facing.
- **Balconies ↔ hall:** anyone on BW/BE/SL is seen from the hall floor and vice versa. The return
  flights are fully exposed. Upstairs the BOH door from UC to BW (13, 8) is the hidden way onto the
  balconies (the hall guard faces away from it).
- **Security room:** the operator faces W. Door (S, 121° behind-left), key cabinet (E wall) and the
  guard log (NE counter) are outside his 120° cone: SC is worked from behind (as Shadow Ledger K13).
- **BC:** 29 m straight; door recesses for cover (8 doors). C5 at the W end.
- **UC:** 29 m straight; C13 at the W end covers x 3.4–23.4. The SV keypad at (25, 6) is 21.6 m from
  it, **just outside its range**: reached from the BE door (x 30) or the CS door (x 32) it is
  camera-free; reached from SS or the BW door it is not.
- **Galleries:** open 12 × 12 rooms with benches as the only low cover; partition screens
  (2.4 m freestanding walls, 2 per top-lit gallery) break the long lines. The Calloway arch gives a
  14 m line from BW to the UG1 W wall.
- **Treasury:** the grid glows red across the cabinet; C11 sees the door and the grid from the SE
  corner. The painting wall behind the grid is lit by one spot.
- **Mews:** C7 on a pole at the LD roller door covers the Mews from the ladder (x 10) to the mouth.
  The ladder foot is at the edge of the cone (55° off axis, inside) in `cam_a` only.
- **Sculpture Court:** C8 on the WG west wall at 3.0 m covers the French doors and the grate. The
  bronzes and the pool kiosk block it at the SW corner (the gate).

**Cameras** (`security_camera`, 2.6–3.2 m or ceiling, 60° cone, 20 m):

| Cam | Mount | Looks at | Notes |
|---|---|---|---|
| C1 | VE south wall above the bronze doors, 3.2 m (G1, lead r165: the arch spot is 4 m up and fails `scale`) | N into GH: the hall floor, the stair foot | Public until last call (watches masked players only). |
| C2 | GH, ceiling under the E balcony soffit (31, 22), 5.1 m | NW: the bar, the staff-door strip, the WG arch | The stair landing is above its cone. |
| C3 | WG, NE corner (11.6, 8.4) | SW: the room, the French doors | The BC art door beside it is blind. |
| C4 | EG, SE corner (43.6, 23.6) | NW: the room, the LD art door | The EB opening is behind it. |
| C5 | BC, W end (3.4, 7) | E along BC (to x ≈ 23) | SC and RG doors in view; LF/E1/J beyond 20 m. |
| C6 | LD, NW corner (32.4, 0.4) | SE: the roller door, the art door, the crates | The BC double door and the lift door are beside it (blind). |
| C7 | Mews pole (36, −1), 3.2 m | W along the Mews | Ladder foot in view; the Mews mouth (E) is behind it. |
| C8 | Court, WG west wall (−0.4, 9) (QC-65) | S over the court: the French doors, the grate | The gate corner is occluded by the pool kiosk. |
| C9 | UG1, SE corner (11.6, 17.5) (G1, lead r165: z 17.5 so the UG1 screen hides `orchard_calloway`) | NW over the Calloway hang | The shuttered arch is beside it (blind). |
| C10 | UG3, NW corner (32.4, 12.4) | SE: the room, the TR and AT doors | The CS door is beside it (blind). |
| C11 | TR, NE corner (43.6, 24.4), 2.6 m | W/SW: the door, the grid, the painting | **Always live** (`treasury`). |
| C12 | BB, E end (31.6, 7) | W along BB: the vault door, the lift | The SS door at the W end is 29 m away (outside range). |
| C13 | UC, W end (3.4, 7) | E along UC: CO, AO, UW, FS doors, the BW door | SS is behind it; the SV, LF, BE and CS doors are beyond 20 m. |
| C14 | AS, NE corner (31.6, 8.4) | SW over the racks | **Always live**. |

**Camera layouts** (`camera` variable; C11 and C14 always live). Design rule: **no layout watches
both BC (C5) and UC (C13)**, and every layout leaves at least one camera-free entry. **D-075: both
camera-layout rules are approved** (this one and the partition-screen rule in the ghost line below)
and become `validate_level` checks built at G1 (design note; not implemented yet):
- **`camera_spine`:** for every value of the `camera` variable, the enabled `security_camera`s must
  not cover both back-of-house corridors (BC and UC: a camera whose cone reaches either corridor's
  RoomVolume counts for it). Fails naming the layout and the two cameras.
- **`camera_screen`:** every upper list slot (`orchard_calloway`, `widow_sallow`, `saint_maritime`)
  has a partition screen (meta `kind = "partition_screen"`) on the line from its room's camera
  to the slot's centre, in every layout that enables that camera. Fails naming the slot and the camera.

| Layout | Cameras (+ C11, C14) | Camera-free BOH line | Free entry |
|---|---|---|---|
| `cam_a` | C1, C3, C6, C7, C9, C13 | BC free; UC's west half watched (the SV door is outside C13's range when approached from BE/CS) | the court grate (C8 off); the roof deck → SS (the SS door is behind C13's mount) |
| `cam_b` | C2, C4, C6, C8, C10, C12 | BC and UC free (C5/C13 off) | the roof deck → SS; the Mews ladder (C7 off) |
| `cam_c` | C1, C4, C5, C8, C10, C12 | UC free; BC watched (SC needs ECM or the operator) | the LD personnel door (C6/C7 off); the roof deck → SS |

## Stealth routes
Spawns: the portico (default, unmasked guests), the Mews (`pp_spawn_mews`, unmasked, outside the
LD), the roof deck (`pp_spawn_roof`, unmasked on a RESTRICTED roof, masked to move freely).

1. **The gala (front).** Walk in, case the ground galleries and the bar, mark canvases, find which
   ones are on show. The staff door under the stair (LOCKPICK 8 s, masked; QC-56 dropped,
   Build rulings B2) leads into BC → SC (keycard,
   log) / RG / SS. Risk: the hall guard faces the hall; patrons see everything masked in public.
2. **The Sculpture Court.** Public until last call. The French doors into WG are either on the latch
   for the smokers (`court_doors_open`, until last call) or locked (LOCKPICK 8 s, C8). The **areaway
   grate** (`grate_loose`: lift 3 s; `grate_padlocked`: lockpick 8 s or saw) → ladder → PL → BB:
   straight to the art store, skipping the ground floor.
3. **The Mews / loading dock.** The dock smoker's loop; the LD personnel door (LOCKPICK 8 s, C6/C7).
   LD has the art door into EG (KEYCARD) and the art lift. Best with `esc_mews`.
4. **The roof deck.** The fire-escape ladder (masked, 9 m) or the roof spawn → the head-house door
   (LOCKPICK 8 s) → SS → UC: next to SV, CO and CS. Bags never use the ladder (S10.1b): loot leaves
   by the lift or the stairs.

**Inside, the required line is:** find the Lantern Bearer and 1 more listed canvas (D-075) → for each,
the barrier its slot has (public view before last call, sensors, Treasury keycard + lasers, art-store
keycard) → cut (4 s) → carry out.

**Barrier per slot:**

| Slot | Room | Barrier |
|---|---|---|
| `cp_landing` | GH stair landing | Public view until last call (patrons, hall guard, C1/C2); after last call a **static laser curtain** across the landing (QC-53) with a 1.0 m bypass gap at the west return flight (Build rulings B4); sensors in `sensors_upper`/`sensors_all`. |
| `cp_treasury` | TR | Keycard (TR reader) + laser grid (`laser_pattern`) + C11 + frame sensors in every `sensor_net` option. |
| `cp_store`, `saint_store` | AS | Keycard (vault reader) + C14; no sensors (store frames are bare). |
| `orchard_calloway`, `widow_sallow`, `saint_maritime` | UG1/UG2/UG3 | RESTRICTED from the start; upper rover; sensors in `sensors_upper`/`sensors_all`. |
| `widow_founders`, `saint_harbour`, `orchard_benefactors` | WG/EG/EB | Public until last call; hall guard loops; sensors only in `sensors_all`. |
| `widow_conservation` | CS | The conservator (`cons_late`); no sensors (frame off). |
| `orchard_quarantine` | QR | Basement rover; no sensors (crate). |

**Keycards:** 2 cards (`keycard` picks 2 of 4), 3 readers (TR, AS vault, LD → EG art door). Readers
consume cards (D-042 precedent). Spending one on the art door can cost the Treasury.

**Pager budget:** Routine–Hazardous can pager every guard. Brutal+ cannot: the dock smoker and the
basement rover are the natural guards to avoid (their loops are separable). The operator is worth a
pager: killing or dominating him turns every camera off, the two inner ones included (S8.2).

**The hardest roll and its ghost line** (level_standards §4 MUST). Cataclysm, Titan cameras, operator
in, 5 guards (hall, 3 rovers, smoker), `cp_treasury`, `orchard_calloway`, `widow_sallow`, `saint_store`,
`sensor_net = sensors_all` (+ `argus_upgrade`), `laser_pattern = lz_sweep`, keycards `kc_curator` +
`kc_security`, `code_security_log`, `grate_padlocked`, `court_doors_locked`, `curator_hall`,
`cons_gone`, 9 patrons, 2 stragglers, `esc_parade`. Solo, one ECM deployable (2 charges), **no kills,
no pagers, no ties**. The camera layouts are built so that **no layout watches both BC (C5) and UC
(C13)**, C13 does not reach the SV door, and the two inner cameras (C11, C14) are the only
always-live ones; so no layout needs more than one ECM in the BOH spine and one at the Treasury.
Worked for `cam_a`:
1. Portico spawn. Case the hall unmasked. Nothing listed is downstairs on this roll. **Wait for last
   call** (8–12 min): guests leave, the hall guard locks the bronze doors; one straggler stays at the GH
   bar (seated, facing W across the counter) and one on an EB sofa.
2. Mask in VE's west corner (behind C1's mount). When the hall guard walks loop (b) into WG, pick the
   staff door under the stair (19, 8; 8 s; the bar straggler faces W, the door is to his N-E, and C2 is
   not in `cam_a`). BC is free in `cam_a` (C5 off): SC from
   behind the seated operator: `kc_security` from the cabinet, read the guard log. Out.
3. Back through the staff door. When the hall guard walks loop (c) into EG, climb the grand stair
   (the bar straggler faces W; the stair is behind his right shoulder) → east return flight → BE →
   the BE door into UC at x 30, outside C13's range → the SV keypad at x 25 (21.6 m from C13: outside)
   → into SV, door closed → **hack 60 s** (+1 interruption from `argus_upgrade`), silent, off camera.
   Time the keypad and the exit to the upper rover's loop (c) (CS → UG3 side). No ECM used.
4. BE → UG3 (C10 off in `cam_a`) → TR door. **ECM #1** (C11): swipe `kc_security` (3 s) → 1.5 m to
   the grid → wait for the sweep gap (≤ 6 s) → cross (2 s) → cut the Lantern Bearer (4 s) → cross back
   in the next gap → out (≈ 18–20 s in all; the jam is 20 s). The Lantern Bearer is LIGHT: carry it
   through BE.
5. BW → UG1: C9 (SE corner, looking NW) is live; the `orchard_calloway` slot is on the W wall behind a
   2.4 m partition screen at (6, 12–16) that shadows it from C9 (a G1 placement rule, approved D-075 and
   checked by `camera_screen`: **every upper list slot has a screen between it and its room's camera**).
   Cut it after the rover's loop (a) pause ends and he leaves through UG2: that is the second required
   canvas (D-075: the Lantern Bearer + 1). UG2 (no camera) → `widow_sallow` is a bonus.
6. Drop the canvases from BE over the balustrade into the hall's east strip (x 22–28, Build rulings B4 / P GN-P1; out of
   C1's cone: ≥ 70° off its axis, behind the bar straggler), take the stairs down, and carry them along
   the hall's south wall
   (C1's blind band below and behind its mount) into VE and out of the bronze doors (push bar from
   inside) to the limo at the kerb (E2). 1 ECM charge (1 spare), 0 ties, 0 pagers, 0 kills.

`cam_b`: BC and UC free; one ECM covers C10 + C11 together at the TR door. `cam_c`: BC watched (ECM
#1 for SC, 12 m from the staff door), UC free, ECM #2 at the TR door (C10 + C11). Worst case: 2 ECMs.
A roll with `kc_curator` + `kc_conservator` (no `kc_security`) takes the conservator's card from the
CS bench in her 50–80 s absence window (CS is reached from the UC east end, outside C13, or from UG3);
the 1 + 1 rule (D-075) leaves a choice of 3 canvases for the second, so a slot behind the second reader can be skipped. The
G3 ghost bot checks these rolls on 5 seeds (roadmap P5 gate).

## Loud
**Phase outline.** Alarm → lockdown (shutters, vault relock, sensors irrelevant) → CONTROL (first
responders, 20 s) → ANTICIPATION → BUILD → SUSTAIN → FADE (L1.1). Expected run: wave 1 during the
hack (120 s, in H2) or the vault drill (240 s, in H3), wave 2 while canvases move to the lift and
LD, wave 3 during the escape wait.

**On alarm** (Mercer: "That's Argus. Shutters are coming down, the vault's sealed."): the mission
BARs the Calloway arch shutter, the TR shutter and the LD art door, and kills the AS keycard reader.
`[hack]` lifts all three and re-enables the vault door's reader as a plain open (QC-55). Canvases
in public rooms, CS and QR stay reachable without the hack.

### Holdouts (≥ 3 designed; each has ≥ 2 non-breach-only approaches, D-070)

| Holdout | Where | Entrances (chokepoints) | Flanks | Sniper exposure | Strength | Weakness | It matters when |
|---|---|---|---|---|---|---|---|
| **H1 The stair landing** | GH half landing + return flights (+2.7…+5.4), centroid (22, 10) | (1) VE (the bronze doors, P1/P2); (2) the WG arch; (3) the EG arch; (4) the staff door under the stair (from BC) | The oculus rappel lands in the middle of the hall (P5). Balconies above flank from UC. | None (no windows on the hall). | Height over a 20 × 18 m floor; stone balustrades are hard cover. | Four ground entries plus the rappel; open to the balconies. | `cp_landing`; the parade escape wait. |
| **H2 The upper BOH** | UC + SV + CO (+5.4), centroid (20, 5) | (1) SS (from BC and the roof deck); (2) the BW door and (3) the BE door (from the balconies, i.e. the grand stair); (4) the CS door (from UG3/the lift) | Roof-deck police come down SS; balcony pushes from the hall. | CO/AO windows N face the Mews houses (no perch). | A 2 m corridor with doors both ends: short lines, hard walls. | Four approaches at both ends; Stinger country. | **`[hack]`** (120 s, 2–3 interruptions): the loud objective whenever a listed canvas is behind a shutter or in AS. |
| **H3 The basement** | BB + AS (−4.2), centroid (20, 12) | (1) SS; (2) the art lift (only when the crew sends it up); (3) the areaway ladder (FLANK, Phantom) | Phantoms via the areaway into PL. | None. | One stair + one ladder: easiest hold. | Every canvas leaves by SS or the lift; trap-like. | `cp_store`/`saint_store` with the vault drill (240 s) instead of the hack; `orchard_quarantine`. |
| **H4 The loading dock** | LD (+ BC E end), centroid (38, 6) | (1) the roller door (breachable); (2) the personnel door; (3) the BC double door (from inside); (4) the EG art door (after the hack) | The Mews from both ends (P3, P4); the roof deck sees nothing of LD. | S1 (hotel terrace) through the open roller door (~32 m). | Crates as cover; the van at the door; the lift E door inside. | Roller door wide open = S1 lane. | `esc_mews` (the escape wait). |

Not designated but useful: SL (a long gallery over the portico, windows to the Parade: S1/S2 can't
see it, but P1/P2 units can shoot up through the tall windows).

### Police spawns (≥ 3 directions required; 5 designed) and the spawn rule
`SpawnPoint` POLICE; the director spawns at POLICE spawns only (QC-42/D-064: never inside the
building). Interior ENTRY points carry the tag **`breach_only`**. Spawns need no LOS to any crew
member and ≥ 15 m flat distance (DirectorTweak `min_crew_distance_m`); all are ≥ 17 m from every
holdout centroid.

| Spawn (tag) | Position (x, z, y) | Occluder | → H1 | → H2 | → H3 | → H4 |
|---|---|---|---|---|---|---|
| **P1** `police_w` (Aldous Parade west) | (−46, 44, 0) | the gala coach + barriers | 76 | 80 | 74 | 93 |
| **P2** `police_e` (Parade east, by the press van) | (76, 44, 0) | press van + barriers | 64 | 70 | 64 | 52 |
| **P3** `police_n` (Wexley St north) | (52, −28, 0) | the catering truck | 48 | 45 | 51 | 37 |
| **P4** `police_mews` (Mews west, behind the gate) | (−46, −4, 0) | the solid Mews gate | 69 | 66 | 69 | 84 |
| **P5** `police_roof` (Great Hall roof, S end behind the pediment) | (22, 29, +11.0) | the pediment and the roof itself (no crew access) | 19 | 24 | 17 | 28 |

- P5 units reach the interior only by the one-way **rappel** link through the oculus (22, 17) into
  the hall (9.8 m drop; QC-41 links) and by walking the roof to the deck's east edge, from where a
  one-way drop link lands them on the roof deck (+9.0) → SS head-house door (ENTRY, `breach_only`).

### Police entry points (`TacticalPoint`)

| Kind | Where | breachable | Serves |
|---|---|---|---|
| ENTRY (`breach_only`) | the bronze doors (VE), the GS shop door, the EB windows ×3 (glass) | yes | S, E |
| ENTRY (`breach_only`) | the court French doors (WG); the court gate (exterior, padlock) | yes | W |
| ENTRY (`breach_only`) | LD roller door, LD personnel door | yes | N |
| ENTRY (`breach_only`) | SS head-house door (roof deck) | yes | Roof |
| RAPPEL + ENTRY | the oculus (22, 17), glass, breakable; drop 9.8 m into GH | yes | Roof |
| FLANK | the areaway grate → PL (nav layer `vent`, Phantom only) | — | W |
| FLANK | the Mews ladder → roof deck (police only climb it in loud, one-way up; P4 side) | — | N |
| SHIELD_ANCHOR | the portico (22, 32); VE inner screen (22, 25); the Mews at the roller door (37, −3); BC E end (30, 7) | — | Bulwark/Aegis |
| SNIPER_PERCH | S1, S2 (below) | — | — |
| COVER | ~50: bar, benches, plinths, partition screens, balustrade posts, crates, AHUs, Mews bins, the limos | — | all |

### Sniper perches (Longshot, L4.7)

| Perch | Position (x, z, y) | Sees | Distance to the bag route | Blind to |
|---|---|---|---|---|
| **S1** Grand Wexley Hotel roof terrace | (62, 12, +22) | Wexley St, the Mews mouth and east half, the LD roller door (open), the E2 limo at the portico (oblique) | E1 van ~32 m, E2 ~45 m | the court, the Mews west half |
| **S2** Ostrander Conservatory roof | (−24, 4, +14) | the Sculpture Court, the Mews west half, the court gate and the Parade west | E1 van ~62 m, the grate 22 m | Wexley St, the portico (the court wall) |

### Specials
- **Phantom:** the areaway → PL (H3 flank); the Mews ladder.
- **Stinger:** pairs from the roof deck down SS (H2) and from the oculus rappel.
- **Bulwark:** the portico and VE (H1), the roller door (H4).
- **Wrecker:** vehicle-wide routes only: the Parade (VE) and the Mews (roller door).
- **Corpsman:** any group. **Longshot:** S1, S2.
- **Commander Brandt + Aegis** (Lethal+): from P1/P2 along the Parade to the portico anchor; he
  pressures H1 and the parade escape.

## Loot path
- **Required (D-075):** **The Lantern Bearer** (`loot.painting_lantern_bearer`) **+ 1 more listed canvas**
  (any of `loot.painting_salt_orchard`, `loot.painting_widow_in_blue`,
  `loot.painting_tidewater_saint`), both LIGHT, secured at the escape. The other listed canvases, the
  studies and small loot are bonus.
- **Art lift (`bag_lift`, 4 bags, 10 s):** every floor. AS → BB → LF (12 m) → ground → LD (E door) →
  van E1 (8 m). Upper → UC → LF.
- **To E1 (Mews van):** from TR ≈ 30 m on the upper floor + lift + 8 m; from UG1 ≈ 26 m + lift; from
  the landing: GH → staff door → BC → LD ≈ 30 m; from WG ≈ 35 m (art door → BC); from EG via the art
  door (keycard / after the hack) ≈ 14 m.
- **To E2 (portico limo):** from the landing ≈ 25 m; from UG1/UG2/UG3: the balconies → **throw
  over the balustrade into the hall (5.4 m)** → VE → portico ≈ 22 m. In stealth before last call the
  hall is public: a masked crew member with a canvas is seen by everyone; after last call it is empty.
- **Throw spots:** BW/BE/SL balustrades → GH floor; the CS east windows are fixed (no throw); the
  roof deck is not a loot route (ladder).
- **Optional:** studies (`loot.painting_study`, 1–2 per gallery + `store_paintings` in AS), the
  consignment lockers (`deposit_box`, saw), the CO wall safe, the TR vitrines (`display_case`,
  alarmed glass), the cloakroom cash box and the GS till (`small_loot`).
- **Secure zones:** `SECURE_LOOT` at the active escape only (the van's rear doors in the Mews; the
  limo's boot at the portico kerb), present from the start.
- **Bodies:** BODY_HIDE in the Mews bins (2), FR crates (2), J (1), FS (1), PL behind the AHU (2).

## Objectives
**Stealth** (`objective_tag` in brackets; ENV B builds `objective.gallery_night.<tag>` from these):
1. *(optional)* Case the gala. Mercer intro and a Vance line. `[casing]`
2. Find the listed canvases (walk within 4 m of each; `asset.intel_list` reveals them). `[find_canvases]`
3. *(as needed)* Get a keycard for the Treasury or the art store. `[keycard]`
4. *(as needed)* Find the Argus code `[server_code]` and take the frame sensors offline: hack 60 s,
   1–2 interruptions. `[hack]`
5. *(as needed)* Open the Treasury (keycard, then the lasers) `[treasury]` or the art store (keycard)
   `[art_store]`.
6. Cut the Lantern Bearer (4 s). `[centrepiece]`
7. Cut 1 more listed canvas. `[canvases]`
8. Secure the Lantern Bearer and 1 more listed canvas at the escape (D-075). `[secure]`
9. *(optional)* The other listed canvases, studies, the consignment lockers `[lockers]`, the curator's safe
   `[curator_safe]`. `[extras]`
10. Escape. `[escape]`

**Loud** (on `alarm_raised`):
1. Mercer: lockdown. `[lockdown]` (completes at once; it explains the shutters)
2. If a needed canvas is behind a shutter or in AS: **hack the Argus server** (120 s, 2–3
   interruptions; the SV door: code, or drill 60 s `[server_door]`) `[hack]`, **or** thermal-drill the
   vault door (240 s) `[vault_drill]`.
3. Cut the Lantern Bearer and 1 more. `[centrepiece]` `[canvases]`
4. Secure them. `[secure]`
5. Hold until the escape arrives (`escape_eta_s` after `[secure]`; the van returns to the Mews or the
   limo to the kerb). `[escape_wait]`
6. Escape. `[escape]`

**Mission script notes** (`gallery_night_mission.gd` on `HeistMission`):
- Find prefabs by objective_tag; the list canvases are `loot_spawn`s with `objective_tag`
  `canvas_<id>` (only the active slot's exists).
- **Last call** (timer `last_call_s`): Mercer line; guests path to the portico and despawn (QC-51);
  flip the PUBLIC MapZones to RESTRICTED (QC-51); waitstaff leave at +120 s; enable the landing laser
  curtain when `cp_landing` (QC-53). Before the alarm only.
- **Frame sensors:** on `interaction_completed` of an alarmed slot's `loot_spawn` while sensors are
  live → `raise_alarm(&"scripted")` (fallback until QC-54 ships a prefab flag). `[hack]` done →
  sensors off.
- **`[find_canvases]`:** an Area3D (4 m) per list slot; first crew entry → mark + Mercer line.
- **Lockdown:** on `alarm_raised` → BAR the three shutters, disable the AS reader (`kc` no longer
  works), retarget the hack's `duration_s` to 120 and interruptions to 2–3 (QC-55), enable the
  vault's thermal drill point. `device_finished` (hack) → open shutters, open the vault door.
- **`[secure]`:** completes when the Lantern Bearer **and** 1 other list canvas are secured (D-075).
  Studies never count.
- **Escape:** stealth: the escape zone activates on `[secure]`. Loud: `arrival_delay_s =
  escape_eta_s`.
- **Rare-event spawns** (`insurance_inspection`, `vaultline_early`) use the QC-25 timed spawn hook.
- **Mercer lines:** see Audio (VO ids).

## Variable table
Each variable changes a decision. Rules resolve in table order (heist_map.md §5); per-difficulty
weights use A2-08. **Difficulty rows (QC-63):** a "Routine" row also applies at Tense; a "Brutal+" row also applies at
Hazardous (`sensor_net`, `laser_pattern`, `patrons`, `escape_eta_s`).

| variable | options (slot ids) | weights | gameplay effect (the decision it changes) |
|---|---|---|---|
| `last_call_s` (scalar) | 480, 600, 720 | uniform | **How long the gala lasts:** the casing window and how long the ground rooms stay public (dangerous to work masked, safe to walk unmasked). |
| `patrons` (scalar) | 3, 5, 7, 9 | Routine 0.4/0.4/0.2/0; Brutal+ 0/0.3/0.4/0.3 | **How many eyes before last call** (and hostages in loud). |
| `stragglers` (scalar) | 0, 1, 2 | 0.4, 0.4, 0.2 | **Whether the ground floor is empty after last call** or still has a guest who can phone. |
| `centrepiece` (`loot_spot`) | `cp_landing` (GH), `cp_treasury` (TR), `cp_store` (AS) | 0.4, 0.35, 0.25 | **The required canvas's barrier:** public view + laser curtain, keycard + lasers + always-live camera, or keycard into the basement vault. Decides the floor you work and the escape you want. |
| `canvas_orchard` (`loot_spot`) | `orchard_calloway` (UG1), `orchard_benefactors` (EB), `orchard_quarantine` (QR crate) | 1, 1, 0.7 | Upstairs behind the rover and the lockdown shutter, on the public ground floor, or in the basement. |
| `canvas_widow` (`loot_spot`) | `widow_sallow` (UG2), `widow_founders` (WG), `widow_conservation` (CS easel) | 1, 1, 0.7 | As above; CS puts a civilian (conservator) and a keycard slot beside it. |
| `canvas_saint` (`loot_spot`) | `saint_maritime` (UG3), `saint_harbour` (EG), `saint_store` (AS) | 1, 1, 0.7 | As above; `saint_store` makes the art store worth one of the two keycards. |
| `sensor_net` | `sensors_treasury` (TR only), `sensors_upper` (all upper frames + TR + the landing), `sensors_all` (every hung frame) | Routine 0.5/0.35/0.15; Brutal+ 0.2/0.4/0.4 | **Whether the hack is needed in stealth**, and for which canvases. |
| `conservator` (`civilian_cluster`) | `cons_late`, `cons_gone` | 0.5, 0.5 | A civilian in CS (by `widow_conservation` and `kc_conservator`). |
| `keycard` | `kc_curator` (on her lanyard: tie or kill her, QC-52), `kc_security` (SC cabinet), `kc_registrar` (RG desk), `kc_conservator` (CS bench; requires `cons_late`) | 1, 0.75, 1, 1; **pick 2** | **2 cards for 3 readers (TR, AS vault, LD art door):** which door you give up, and whether you must deal with the operator or the curator. |
| `code_note` | `code_security_log` (SC), `code_curator_planner` (CO), `code_admin_postit` (AO) | 1, 1, 1; pick 1 | **The SV door:** behind the operator, in the curator's office, or in the open office (C13's corridor). |
| `guard_post` | `rover_ground`, `rover_upper`, `rover_basement`, `dock_smoker`, `rover_none` (encodes counts as Night Deposit) | Routine/Tense pick 1 (`rover_none` 1 vs 1 each: P(none) = 0.2); Hazardous pick 2; Brutal 3; Lethal+ 4 (`difficulty_add`) | **Which floor and which entry has a walker**: the smoker shuts the Mews; the basement rover makes the grate and the vault slow. |
| `security_room_staffed` | `sec_staffed`, `sec_empty` | Routine 0.6/0.4; Hazardous 0.65/0.35; Brutal+ 0.75/0.25 | Live cameras or not; SC's cabinet and log are free when empty. |
| `camera` | `cam_a`, `cam_b`, `cam_c` (table in Sightlines) | 1, 1, 1 | Which corridor and which entry needs ECM or timing. |
| `laser_pattern` (TR grid) | `lz_static` (3 beams 1.30/1.90/2.50 m, evenly spaced by the prefab: crouch under the 1.30 m beam, Build rulings B4), `lz_sweep` (3 vertical, 6 s, ~2.4 m apart, full room width), `lz_timed` (4 beams, off 4 s of 16 s, full width) (G1, lead r165) | Routine 0.5/0.2/0.3; Brutal+ 0.2/0.4/0.4 | Crouch, time the sweep or wait, in C11's cone. |
| `curator_route` (`civilian_cluster`) | `curator_hall`, `curator_office` | 0.5, 0.5 | **Where the keycard walks:** in the public hall among guests (tie her and every patron sees) or upstairs near CO/SV (quiet tie, near the upper rover). |
| `court_doors` (`locked_door`) | `court_doors_open` (on the latch until last call), `court_doors_locked` | 0.5, 0.5 | **A free way from the court into WG** while the court is public. |
| `areaway` (`vent_open`) | `grate_loose`, `grate_padlocked` (`padlock`: lockpick 8 s or saw) | 0.5, 0.5 | The cost of the basement route (in C8's cone in `cam_b`/`cam_c`). |
| `xl_crate` (`loot_spot`; rare `late_loan` forces it) | `xl_none`, `xl_loan` | 1, 0 (picks `xl_none` unless forced; QC-62) | A loan crate in LD with 2 extra studies. |
| `admin_pa` (`civilian_cluster`; rare `late_paperwork` forces it) | `pa_none`, `pa_late` | 1, 0 (picks `pa_none` unless forced; QC-62) | The admin PA works late in AO beside `code_admin_postit` and C13's corridor. |
| `store_paintings` (scalar) | 4, 6, 8 studies on the AS racks | uniform | Greed in the vault. |
| `consignment_lockers` (scalar) | 4, 6, 8 `deposit_box` | uniform | Small-loot greed against saw noise next to the vault (camera C14). |
| `escape` | `esc_mews` (E1 van), `esc_parade` (E2 limo) | 0.55, 0.45 | **The loot path:** the art lift and LD (BOH), or the grand stair, the hall and the portico (front, throw spots, after last call). In loud: H4 or H1 for the wait. |
| `escape_eta_s` (scalar, loud) | 90, 120, 150 | Routine 0.4/0.4/0.2; Brutal+ 0.2/0.4/0.4 | How long the last holdout lasts. |

## Rare events

| id | good/bad | chance | effect |
|---|---|---|---|
| `curator_tipsy` | good | 5% | Sorell leaves her lanyard on the bar at last call: `kc_curator` becomes a casing-allowed pickup on the GH bar (`force_active` keycard slot params). |
| `late_loan` | good | 5% | A loan crate in LD holds 2 extra studies (`xl_crate`). |
| `insurance_inspection` | bad | 8% (`min_difficulty` Hazardous) | At last call + 180 s two insurance inspectors with Halberd escorts (2 extra guards, pagers) enter by LD and walk to the centrepiece's slot. If it is gone, they raise the alarm. |
| `vaultline_early` | bad | 6% (`min_difficulty` Hazardous; `requires centrepiece: [cp_landing, cp_treasury]`) | At 12:00 elapsed a **Vaultline Armored Transport** crew (2, pagers) arrives at LD to move the Lantern Bearer to the vault: they walk to its slot; if they reach it intact they carry it (a NPC-carried bag, QC-57) towards AS. Steal it before, or from them. |
| `argus_upgrade` | bad | 6% (`min_difficulty` Lethal) | `sensor_net` forced to `sensors_all`; the stealth hack gets +1 interruption. |
| `late_paperwork` | bad | 5% | The admin PA works late in AO (a civilian beside `code_admin_postit` and C13's corridor). |

## Escape
- **Mews van (E1):** in the Mews at the LD roller door (x 37, z −4). Type `van`. Stealth: parked from
  the start; the ESCAPE zone activates on `[secure]`. Loud: it leaves at the alarm and returns after
  `escape_eta_s` (from `[secure]`). SECURE_LOOT at the rear doors. Last holdout H4.
- **Parade limo (E2):** a black gala limousine at the portico kerb (x 22, z 34), the crew's driver in
  a chauffeur's cap. Type `van` (the boot is the secure zone; D-075: approved as a van-type escape
  with a limo visual, no new `escape_type`). Same rules. Last holdout H1 (or the
  portico itself). Before last call the kerb is public (guests waiting for cars): carrying a canvas
  there masked is seen by everyone.
- **Walk-out** (stealth): an unmasked crew with no bags can leave by the portico before last call.

## Pre-planning (preplanning.md contract, D-046 shape)
`Preplan` points (category; `floor` indexes `floor_heights`: 0 Basement, 1 Ground, 2 Upper, 3 Roof;
labels `ui.preplan.point.gallery_night.<point_id>`, D-068):

| Point | Category | Params / asset |
|---|---|---|
| `pp_spawn_portico` | spawn | default (spawn_tag `""`), Aldous Parade at the red carpet (floor 1) |
| `pp_spawn_mews` | spawn | spawn_tag `preplan_spawn_mews` (Mews, by the caterers' van) — `asset.alternate_entry` |
| `pp_spawn_roof` | spawn | spawn_tag `preplan_spawn_roof` (roof deck, floor 3) — `asset.alternate_entry` |
| `pp_drop_court` | drop_zone | Sculpture Court, behind the pool kiosk — body bag case |
| `pp_drop_mews` | drop_zone | by the Mews bins — body bag case, ammo, doctor |
| `pp_drop_roof` | drop_zone | roof deck behind the AHUs (floor 3) — body bag case, ammo, doctor |
| `pp_escape_mews` | escape | variant_group `escape`, slot `esc_mews` — `asset.escape_position` (vote) |
| `pp_escape_parade` | escape | slot `esc_parade` |
| `pp_insider_registrar` | insider | variant_group `keycard`, slot `kc_registrar` (floor 1) — `asset.inside_keycard` |
| `pp_grate` | insider | variant_group `areaway`, slot `grate_loose` — `asset.propped_door` |
| `pp_court_doors` | insider | variant_group `court_doors`, slot `court_doors_open` — `asset.propped_door` |

`HeistDef.preplanning` (contract v1.0 shape; entry keys are PreplanAssetDef fields; costs are Routine
prices × `PreplanTweak.cost_mult`; ◇ = my proposal for ENV B/lead):
```gdscript
preplanning = {
    "favors": 5,
    "disable": [],   # nothing: other heists' located assets are limited by point_ids, the rest by QB-53
    "assets": {
        # library assets limited to this heist's points
        &"asset.body_bag_case_drop": {"point_ids": ["pp_drop_court", "pp_drop_mews", "pp_drop_roof"]},
        &"asset.ammo_bag_drop": {"point_ids": ["pp_drop_mews", "pp_drop_roof"], "tags": [&"loud"]},
        &"asset.doctor_bag_drop": {"point_ids": ["pp_drop_mews", "pp_drop_roof"], "tags": [&"loud"]},
        &"asset.inside_keycard": {"point_ids": ["pp_insider_registrar"], "cost": 1500, "favors": 1},
        &"asset.propped_door": {"point_ids": ["pp_grate", "pp_court_doors"], "max_count": 2,
                                "cost": 1000, "favors": 1},
        # new heist assets (QC-59)
        &"asset.intel_list": {"reveals": [&"centrepiece", &"canvas_orchard", &"canvas_widow",
                                          &"canvas_saint"],
                              "cost": 2000, "favors": 2, "category": &"intel", "tags": [&"stealth"]},  # ◇
        &"asset.intel_sensors": {"reveals": [&"sensor_net"],
                                 "cost": 1200, "favors": 1, "category": &"intel", "tags": [&"stealth"]}, # ◇
    },
}
```
Crew assets with no point that stay on: `asset.intel_cameras` (`camera`), `asset.intel_keycards`
(`keycard`), `asset.intel_guard_posts` (`guard_post`), `asset.extra_cable_ties`,
`asset.spare_body_bags`. Hidden automatically (QB-53): gondola, riser, containers, gangway, lift.
`asset.escape_position` and `asset.alternate_entry` work from the points' params. Blueprint:
`docs/levels/gallery_night/blueprint.png` from the plan renderer.

## Audio/lighting
- **Palette (proposed for style guide §3):** **gallery bone `#DCD5C6`** dominant (limestone, the
  gallery walls' warm off-white plaster, the hall's coffering), **halberd green `#24463A`**
  secondary (the top-lit galleries' silk wall-covering, the Halberd livery, the bronze patina, the
  Treasury's lining), **gilt `#B8913E`** accent (frames, the halberd, the balustrade handrails) plus
  the **gala lilac `#B79CF2`** uplighting (emissive only; it matches ENV B's UI accent for the
  heist). Mood / time: late night, clear after rain, a gala ending. Wear: **pristine** (style guide
  §4, like the bank). All within GSR luminance (bone at 0.66) and saturation.
- **Time:** 23:20, no sun; a waxing moon low in the WSW (direction for the lantern glass sheen).
  Clear sky with thin cloud lit orange by the city. Wet streets (puddle decals, reflective asphalt).
- **Zones:**
  - Great Hall (gala): warm 2700 K chandeliers (3 bronze rings) at 70%, the landing spot (3000 K) on
    the centrepiece, candle-like table lamps; after last call the chandeliers drop to 20% and the
    night-mode wall washers stay (readable shadows);
  - ground galleries: 3000 K picture lights per work, coves; top-lit galleries: the laylight glows
    cold moon-blue from above (night), 3000 K picture lights below, deep shadow between works;
  - Treasury: one 3000 K spot on the painting wall, the red laser glow, the vitrine LEDs;
  - BOH: 4000 K panels (BC, UC, offices), 5000 K in LD, PL, AS (AS: cold 5000 K strips over the racks);
  - security room: monitor glow; server room: 6500 K plus rack LEDs;
  - Conservation Studio: 5600 K daylight-balanced task lamps over the easels (the brightest BOH room);
  - exterior: lilac uplights on the facade (gala; 20% after last call), the gilded halberd's warm
    floods, 3000 K lanterns on the court walls, 4000 K street lamps on the Parade, the hotel's lit
    canopy. Every light has a fixture.
- **GI:** VoxelGI per floor (the hall's void in the ground volume), ReflectionProbe per room,
  OccluderInstance3D for the shell, the stair core and the neighbours.
- **Ambience:** `amb_gallery_gala` (string-trio pad and murmur until last call, glass clinks, then the
  hall's room tone and HVAC hiss; a clock in VE), `amb_uptown_night` (light traffic on the Parade, a
  taxi horn, wet tyres, wind in the median trees), `amb_art_store` (climate-plant drone, humidifier
  ticks).
- **Music:** `gallery_night`: stealth 72 BPM (plucked FM "harpsichord" ostinato, low strings pad,
  a ticking motif that tightens at last call and during the hack); `control` 110 BPM; `anticipation`
  riser; `assault` 136 BPM (driving low strings and synthesized timpani, the harpsichord motif
  distorted); `fade`; `win`/`lose` stingers. One of P5's "music ×3" (C5-01).
- **VO line ids** (`vo.<speaker>.<heist>_<line>`, D-051; ENV B writes the text):
  - **Vance:** `vo.vance.briefing_gallery_night_1..3`, `vo.vance.gallery_night_contact_intro`,
    `vo.vance.gallery_night_centrepiece`, `vo.vance.gallery_night_payday`.
  - **Mercer:** `vo.mercer.briefing_gallery_night_1..2`, `vo.mercer.gallery_night_intro`,
    `vo.mercer.gallery_night_canvas_found` (×4 variants `_saint`, `_widow`, `_orchard`,
    `_lantern`), `vo.mercer.gallery_night_last_call_soon`, `vo.mercer.gallery_night_last_call`,
    `vo.mercer.gallery_night_guests_gone`, `vo.mercer.gallery_night_keycard`,
    `vo.mercer.gallery_night_code_found`, `vo.mercer.gallery_night_sensors_warning`,
    `vo.mercer.gallery_night_hack_started`, `vo.mercer.gallery_night_hack_interrupted`,
    `vo.mercer.gallery_night_sensors_off`, `vo.mercer.gallery_night_lasers`,
    `vo.mercer.gallery_night_treasury_open`, `vo.mercer.gallery_night_art_store_open`,
    `vo.mercer.gallery_night_curator_keycard`, `vo.mercer.gallery_night_inspectors`,
    `vo.mercer.gallery_night_vaultline`, `vo.mercer.gallery_night_last_pager`,
    `vo.mercer.gallery_night_lockdown`, `vo.mercer.gallery_night_shutters_up`,
    `vo.mercer.gallery_night_vault_drill`, `vo.mercer.gallery_night_drill_jam`,
    `vo.mercer.gallery_night_required_secured`, `vo.mercer.gallery_night_van_eta`,
    `vo.mercer.gallery_night_limo_eta`, `vo.mercer.gallery_night_sniper_hotel`,
    `vo.mercer.gallery_night_escape`.
  - Crew barks reuse `vo.crew.*`.
- **LUT:** `lut_gallery_night`: warm ivory mids, green-teal shadows, lifted lilac in the highlights
  outside.

## Review shots
`HeistMap.review_cameras` (level_standards §8; JPEG q85, D-038; each camera ≥ 0.5 m inside its room).
27 shots: 1 top-down, 4 exterior, 3 landmarks (within them), 1 per major room, the security room,
the vault and the Treasury.

| Camera | Shows | Covers |
|---|---|---|
| `rc_top_down` | orthographic plan of the play space | top-down |
| `rc_ext_parade` | from the median looking N: the portico, red carpet, lilac uplights, the **gilded halberd** | exterior 1, landmarks 1–2 |
| `rc_ext_wexley` | from the hotel canopy looking W: the east facade, the Mews mouth | exterior 2 |
| `rc_ext_mews` | from the Mews west looking E: the LD roller door, the ladder, the van | exterior 3 |
| `rc_ext_court` | from the court gate looking N: bronzes, pool, the French doors, the grate | exterior 4 |
| `rc_hall_entry` | from VE through the bronze doors: the hall, the stair, **the Lantern Bearer** | GH, landmark 3 |
| `rc_hall_landing` | from the half landing down over the gala | GH (H1) |
| `rc_balcony` | from BW across the void to BE and SL | BW/BE/SL |
| `rc_founders` | WG | WG |
| `rc_drawings` | DC | DC |
| `rc_harbour` | EG with the art door | EG |
| `rc_benefactors` | EB | EB |
| `rc_cloakroom` | CK + VE | CK, VE |
| `rc_back_corridor` | BC from the W end | BC |
| `rc_security` | SC from behind the operator | SC (security room) |
| `rc_loading` | LD with the roller door and the art lift | LD (H4) |
| `rc_break` | BR (servery) | BR |
| `rc_calloway` | UG1 under the laylight | UG1 |
| `rc_sallow` | UG2 | UG2 |
| `rc_maritime` | UG3 with the TR door | UG3 |
| `rc_treasury` | TR from the door through the grid | TR (vault) |
| `rc_upper_corridor` | UC with the SV keypad | UC (H2) |
| `rc_curator` | CO | CO |
| `rc_conservation` | CS with the easels under north light | CS |
| `rc_art_store` | AS racks and the vault door | AS (vault, H3) |
| `rc_plant` | PL with the areaway ladder | PL |
| `rc_roof_deck` | the roof deck from the ladder top | X4 |

## Budgets
Targets from architecture §10 and D-038 QC-10, checked by the `perf` validator per review camera.

| Budget | Target | Notes |
|---|---|---|
| Draw calls per view | ≤ 2,500 | Worst: `rc_hall_entry`, `rc_hall_landing`, `rc_ext_parade` (limos, trees). Frames, benches, chairs, cocktail tables, rack screens and median trees are MultiMesh per kit item. |
| Triangles per view | ≤ 3M (provisional) | 2 LODs on the bronzes and the chandeliers; skyline LOD dressing. |
| Shadowed lights in any shot | ≤ 8 | Hall: 3 chandeliers + the landing spot; picture lights unshadowed; galleries 2 each (laylight fill unshadowed, `meta fill` ≤ 0.3). |
| Texture memory | ≤ 1.5 GB | Painting canvases: 12 unique 1024² albedo-only textures (the 4 list works + 8 studies, generated by `tools/texgen/` as original abstract-figurative compositions), the rest reuse them with tint/crop variants. |
| NPCs alive | guards ≤ 7 (+2 event), civilians ≤ 16 before last call, police ≤ `max_active_enemies` | Patrons despawn at last call. |
| **Density (kits)** | galleries 0.03–0.06 props/m² (benches, plinths, screens; walls hung at 1 work per 2.5–4 m); hall 0.05–0.10 during the gala; AS racks 70–85% filled; offices per kit minimums | Same-kit rooms (UG1–UG3, WG/EG/EB) must differ in layout hash. |

**Walkthrough whitelist** (level_standards §6): roof spawn ↔ basement targets (> 3× straight line;
the single service stair). By design.

## HeistDef (proposed data, `gallery_night_def.tres`)
`id gallery_night`, display "Gallery Night", contact `contact.vance`, mode STEALTH_OR_LOUD,
base_payout **$105,000** (ENV B's placeholder, accepted), loot `[loot.painting_lantern_bearer,
loot.painting_salt_orchard, loot.painting_widow_in_blue, loot.painting_tidewater_saint,
loot.painting_study]` (`loot.painting_study` new, approved D-075, ENV B adds it, QC-57), escape_options `[van]`,
music_track `gallery_night`, objectives `[casing, find_canvases, keycard, server_code, hack, treasury,
art_store, centrepiece, canvases, secure, extras, lockers, curator_safe, lockdown, server_door,
vault_drill, escape_wait, escape]`, `start_mode` `&"casing"`, preplanning as above. Map
`game/world/heists/gallery_night/gallery_night.tscn`; `floor_heights [-4.2, 0.0, 5.4, 9.0]`,
`floor_names ["Basement", "Ground", "Upper", "Roof"]`.

**Loot table:**

| id | weight | value (base) | where | count | status |
|---|---|---|---|---|---|
| `loot.painting_lantern_bearer` | LIGHT | $2,000 | `centrepiece` slot | 1 (required) | exists (B6-01) |
| `loot.painting_salt_orchard` | LIGHT | $1,700 | `canvas_orchard` slot | 1 | exists |
| `loot.painting_widow_in_blue` | LIGHT | $1,500 | `canvas_widow` slot | 1 | exists |
| `loot.painting_tidewater_saint` | LIGHT | $1,300 | `canvas_saint` slot | 1 | exists |
| `loot.painting_study` | LIGHT | ◇ $700 | 1–2 per gallery (≈ 12) + `store_paintings` (4–8) + `late_loan` (2) | 16–22 | **new**, approved (D-075; ENV B, QC-57) |
| small loot (`loot.small_valuables`, no def) | — | ◇ $600–2,400 per item | lockers (4–8 × 1), CO safe (3), TR vitrines (2), CK cash box (1), GS till (1) | 11–15 | prefab values (ENV C) |

Not used: Shadow Ledger's framed `loot.painting` (same weight, but this heist's generic canvases are
lesser studies valued below the list; D-075 Q6: the new id is approved).

## Requests (to the lead; QC-51..QC-59)
- **QC-51 (ENV A):** the **last-call hook**. (a) `MapZone` kind change at runtime from the mission
  (`HeistMission.set_zone_kind(zone_path, MapZone.Kind.RESTRICTED)`), replicated; (b) **calm
  civilians leaving the map** by a mission order (walk to a PatrolPoint tagged `exit`, despawn,
  no alarm, never counted as a civilian kill), only before `alarm_raised`.
- **QC-52 (ENV A):** a **keycard carried by a civilian**: `keycard_pickup` as a child of an NPC
  spawn (or an NPC export `carried_item`), enabled once the NPC is tied, dominated or dead
  (interaction on the body / tied NPC, 1 s), PD2-faithful. The curator is the first user;
  Ostrander Federal's manager likely the second.
- **QC-53 (ENV A):** mission control of a `laser_grid`: `set_enabled(bool)` (replicated), so the
  landing curtain turns on at last call. Today a grid is always on.
- **QC-54 (ENV A):** frame sensors as data: `loot_spawn.alarm_on_take: bool` + `alarm_group:
  StringName`, and a `hack_terminal` target that clears an alarm group (`AlarmGroups.disable(group)`).
  Raises `alarm_raised(&"sensor")` (a new reason in events.md; until then the mission raises
  `&"scripted"`).
- **QC-55 (ENV A):** `hack_terminal` runtime reconfiguration by the mission (duration and the
  interruption range change at the alarm: 60 s / 1–2 stealth → 120 s / 2–3 loud) and a reader
  method to force a `keycard_reader` dead (`set_disabled(true)`) for the lockdown.
- **QC-56 (ENV A, optional; DROPPED by D-103, Build rulings B2):** a door "held open by staff": an NPC-authorised door that stays open
  for 4 s after an attendant uses it, walkable by an unmasked crew member as a casing-allowed action
  (RESTRICTED beyond). If declined, route 1 uses the lockpick.
- **QC-57 (ENV B, ENV A):** ENV B: `loot.painting_study` (LIGHT ◇ $700, string "A study"), the
  objective strings for the tags above, the VO text, `music.gallery_night.name`. ENV A (only if Q9 is
  kept): an NPC that carries a loot bag and drops it when killed or intimidated (Vaultline).
- **QC-58 (ENV D):** casting notes against `p5_cast.json`: (a) the **camera operator** uses
  `gallery_guard_b`; (b) the **conservator** reuses `gallery_attendant_b` (white gloves) unless D
  wants a lab-coat variant; (c) the **admin PA** (rare) needs an office-wear civilian: reuse a
  Ostrander Federal `bank_customer` look or `npc_penthouse_guest_a` with a cardigan variant; (d) the
  **insurance inspectors** reuse `gallery_guard` (escorts) — or a suit civilian look if D prefers;
  (e) **Vaultline** couriers use `armored_car_crew` / `_b` (pager role) as cast. Ambient clips used:
  `curator_inspect`, `cower_stand`, `cower_seated`, `walk_text`, `smoke`, `desk_work`.
- **QC-59 (ENV B assets):** `asset.intel_list` (reveals the four canvas groups), `asset.intel_sensors`
  (reveals `sensor_net`), and the point overrides for
  `asset.inside_keycard` / `asset.propped_door` on this heist's points (shapes above).

## Cast confirmations (ENV D, `origin/env/d-art` fda27f0, `p5_cast.json`)
- **Halberd Gallery Security: confirmed** as the in-house guard. The name is the gallery's own
  (founder, crest, Foundation), original, and distinct from Halden (Glasshouse/Night Deposit) and
  Northgate (Shadow Ledger). The bottle-green blazer is the heist's secondary colour (palette above).
- **Vaultline Armored Transport: confirmed as is** (Rolling Thunder's company). Gallery Night uses it
  only in the `vaultline_early` rare event, which ties the two P5 heists together.
- Role ids used exactly: `gallery_curator`, `gallery_attendant`, `gallery_waitstaff`, `gallery_guard`,
  `gallery_patron` (+ `armored_car_crew` for the event). The curator is named here **Margit Sorell**
  (D's notes leave her unnamed); she is "the one pale suit at the gala" and the keycard carrier, as D
  modelled.

## Lead rulings (D-075; the G0 open questions, closed)
1. **The gala clock:** approved as the heist's signature mechanic. Last call at 8/10/12 min
   (`last_call_s`) walks the guests out and flips the public zones to RESTRICTED (QC-51).
2. **Camera layouts:** both rules approved, and they become `validate_level` checks built at G1
   (design note only; see Sightlines): **no camera layout watches both back-of-house corridors**
   (BC and UC), and **every upper list canvas has a partition screen between it and its room's
   camera**.
3. **Required loot:** **The Lantern Bearer + 1 more listed canvas**; the rest is bonus (Loot path,
   Objectives and `[secure]` updated).
4. **Services voids:** not covered by the D-075 rulings relayed to ENV C; G1 builds the drafted
   3.0 m BOH ceilings with the services void above (plenum note, Shadow Ledger precedent) and no
   override (`office`/`corridor`/`restroom` are inside their bands).
5. **Ceilings:** the validator's scale table gains **`gallery`** (top-lit, **4.5–6.5 m**), so UG1–UG3
   need no override. The ground galleries (4.5) are `gallery` on the band floor; the balconies and
   the loggia (4.4, open to the hall) are `atrium`. (Same ruling: `hall` 6–9 m, `car_park` 2.2–3.0 m.)
6. **`loot.painting_study`:** approved; ENV B adds it (LIGHT, ◇ $700).
7. **The curator's lanyard keycard** (QC-52): fine (PD2-faithful).
8. **The limo:** approved as a `van`-type escape with a limo visual.
9. **Vaultline (`vaultline_early`):** not covered by the D-075 rulings relayed to ENV C; the rare event
   stays as drafted, with the NPC-carried bag behind QC-57 (until it ships, the G1 greybox falls back
   to the crew raising the alarm on an empty slot, marked `TODO(QC-57)`).

## Build rulings (D-103 / D-104; next_heist.md §3b, §4, §7) — approved (lead, D-103/D-104)
Folded in by ENV C on 2026-10-14. Where this section and an older line above disagree, **this section wins** (the
inline lines touched are marked "Build rulings Bn"). Lock names are `door.gd` `Lock` values.

### B1. Rules every G1/G2 build must meet (next_heist §4)
- Every objective carries `data.marker_tags` (ui_hud 1.8, table B5), casing objectives too.
- Every NPC spawn tag maps to a real character in `NpcVisualTweak.tag_characters` (§3b.1: the tag beats the EnemyDef
  default). Map: `guard_hall`, `guard_rover_ground`, `guard_rover_basement`, `guard_inspection` → `gallery_guard`;
  `guard_rover_upper`, `guard_mews`, the SC `CAMERA_OPERATOR` → `gallery_guard_b`; `guard_vaultline` → `armored_car_crew`
  (`_b` alternating); `civ_curator` → `gallery_curator`; `civ_attendant` → `gallery_attendant`; `civ_conservator` →
  `gallery_attendant_b`; `civ_waitstaff` → `npc_penthouse_staff`; `civ_patron` → `gallery_patron` / `_b` /
  `npc_penthouse_guest_a` / `_b`; `civ_admin` → `npc_penthouse_guest_a` (QC-58c, until D casts a PA). No capsules.
- Key interior lights carry render layer 21 `viewmodel_lit` (`1 << 20`, D-095) on top of their normal layers: the GH
  chandeliers and landing spot, one key per gallery (WG, DC, EG, EB, UG1–3), the TR spot, the CS task lamps, and the
  main panel per BOH room (BC, UC, BB, LD, SC, SV, AS, PL, offices). DC is lit for ADS fights (§7.11), not 50 lux in
  play terms. `validate_level` `viewmodel_lit` warns on misses.
- Director caps per D-099: the Specials list above is gated by difficulty (Routine = regular SWAT + shields only;
  Stinger from Tense; Wrecker/Phantom from Brutal; Corpsman from Overkill-equivalent). H1–H4 are re-checked per
  difficulty at G1 with `auto_loud`.
- Bag weights per D-102: every painting (list canvases and studies) is LIGHT (×1.0, sprint, jump, 4 m throw); body bags
  MEDIUM (×0.75, no sprint, 4 m throw). Throw spots are designed for 4 m.
- Done = `validate_level` PASS (incl. `camera_spine`, `camera_screen`, `slopes`) + PO-3 snag probe 0 + PP-C walk with no
  STUCK rows before G2; windowed `auto_loud` and a stealth flow pass; `test_heist_readiness` lists Gallery Night green.

### B2. Door lock table (§3b.2; QC-56 dropped)
Principle: **public doors NONE** (casing-allowed by default, PO-5.11); **the boundary into BOH LOCKPICK** (masked, 8 s);
**interior BOH doors NONE** (the zone is RESTRICTED, so only masked players use them freely); the three Argus readers
KEYCARD; the server CODE; the art store VAULT. Staff that must pass a locked door are listed in `npc_authorized_tags`
(the §3b.6 staff-role authorisation; guards are authorised today). Doors on routes are ≥ 1.0 m wide (§7.7).

| Door (plan position) | Lock | Notes |
|---|---|---|
| VE bronze outer doors ×4 leaves (x 20–23, z 30) | NONE, `starts_open` | Public. At last call the hall guard closes them and the mission relocks them LOCKPICK from outside (§3b.6 relock API); `push_bar` inside, so the parade escape always walks out. |
| VE inner glass screen, CK (16, 26), PWW/PWM (12, 22 / 12, 25), DC (3, 20), GH↔WG/EG arches | NONE / no leaf | Public; stay unlocked after last call (the zone flip makes them RESTRICTED). |
| Court French doors (0, 12–13) | `court_doors_open`: NONE until last call, then relock LOCKPICK; `court_doors_locked`: LOCKPICK 8 s | `pp_court_doors` (`asset.propped_door`) forces NONE all night. |
| Court gate (exterior) | NONE (open) until last call, then LOCKPICK | Police ENTRY `breach_only`. |
| Areaway grate | `grate_loose`: lift 3 s; `grate_padlocked`: `padlock` (lockpick 8 s or saw) | Grate opening ≥ 1.0 × 1.0 m, ladder on one side (§7.6). |
| GS shop door (from VE) | LOCKPICK 8 s | Closed for the gala. |
| Staff door under the stair (19, 8), GH ↔ BC | LOCKPICK 8 s | `npc_authorized_tags` [`guard`, `staff`]. The route-1 "held open" walk-through is gone (QC-56 dropped). |
| WG art-handling double door (5–6, 8), WG ↔ BC | LOCKPICK 8 s | Staff authorised. |
| LD personnel door (Mews) | LOCKPICK 8 s outside, `push_bar` inside | Police ENTRY. ≥ 1.0 m, step-free to the Mews (§7.3). `npc_authorized_tags` [`guard_mews`, `civ_waitstaff`] (the smoker; the waitstaff leave by it, Circulation). |
| LD roller door (Mews) | BARRED (crew cannot operate) | Police ENTRY `breach_only` (breach opens it); the S1 lane when open. |
| LD → EG art door DD (37–38, 12) | KEYCARD (reader on the LD side) | Lockdown: BARRED; `[hack]` done in loud → NONE (plain open). |
| Roof head-house door (3, 7, roof) | LOCKPICK 8 s from the deck, `push_bar` inside | Police ENTRY `breach_only`. |
| Lift motor room LM | BARRED, no interaction | Dressing. |
| Interior BOH, ground: SS, BR, WC, SC, RG, J, E1, LD ↔ BC double door, LF landing doors | NONE | SC: the operator's FOV, not a lock, protects it. |
| Interior BOH, upper: SS, CO, AO, UW, FS, CS (from UC), BW → UC, BE → UC, AT (N and W) | NONE | |
| UG3 → CS door (36, 12) | LOCKPICK 8 s | Staff authorised (conservator, curator). |
| SV server door (25, 6) | CODE (`code_group argus`, keypad on the UC side) | Loud: drill 60 s (`[server_door]`). |
| TR door (39, 24) | KEYCARD (TR reader) | Lockdown: shutter BARRED; `[hack]` done in loud → shutter up **and** door NONE. Inspectors and couriers (`guard_inspection`, `guard_vaultline`) authorised (they walk to `cp_treasury`). |
| Calloway arch shutter (12, 12–14) | `industrial_door`, `starts_open`, NONE | Lockdown: BARRED; `[hack]` lifts it. |
| AS vault door VV (21–22, 8) | VAULT + `keycard_reader` (stealth) | Lockdown: reader dead; `[hack]` done → plain open; thermal drill 240 s as the loud fallback. Couriers (`guard_vaultline`) authorised. |
| Interior BOH, basement: SS, LK, FR, QR, PL, LF landing doors | NONE | |

### B3. No stealth-only fail (§3b.3)
- `fail_reason` on Gallery Night is **custody** (all humans in custody, L2.9) or **abort** only. Nothing in stealth fails
  the heist: a spotted crew, a sensor alarm, inspectors finding an empty slot or a phone call all raise the alarm and
  the heist **goes loud**.
- **Required canvases always stay reachable.** In loud, `[hack]` lifts every shutter and opens the TR door, the LD art
  door and the AS vault door with no card (B2), and the vault drill is the fallback, so every slot is reachable after
  any stealth mistake (cards spent, curator killed, code note never found).
- **Vaultline (`vaultline_early`) moves, never destroys:** if the couriers reach the centrepiece slot they carry the
  canvas to AS (QC-57 NPC bag). G1 fallback until QC-57 ships (replaces Lead ruling 9's empty-slot alarm): when they
  reach the slot, the slot's `loot_spawn` moves to the `cp_store` rack position (the canvas is "in the vault") and they
  walk back to LD; killing or intimidating them early is a pager event, not a fail. `TODO(QC-57)` stays in the script.
- Insurance inspectors finding the slot empty raise the alarm (loud), never a fail.

### B4. G1 traversal requirements (ENV P review, next_heist §7, adopted D-104)
Player: capsule r 0.35, stand 1.8 / crouch 1.2, step 0.35, max slope 45°, jump apex 1.08 m (heavy 0.27, very heavy
0.07), ladders 2 m/s masked only, no bags, no mantle.

| # | Requirement | Where in this doc | Check |
|---|---|---|---|
| 1 | Laser bypass gaps ≥ 1.0 m; crouch-under beam centres ≥ 1.30 m (lower face ≥ 1.215 m) | `cp_landing` curtain gap 0.8 → **1.0 m**; `lz_static` low beam 1.27 → **1.30 m** | `lasers` + P's walk |
| 2 | Balcony throws land on the hall floor **x 22–28** (east) and the mirrored **x 16–22** (west) (P measured flat throws landing at x 22.2–23.9); balustrade and handrail colliders thin and true to the visual | stealth line step 6 | P: 3 pitches |
| 3 | Mews ↔ LD step-free: Mews grade = LD floor (dock leveller ≤ 0.35 m, dressing) or a ramp ≤ 45° at both doors | LD, X2 | `slopes`, walkthrough |
| 4 | Reflecting pool rim + depth ≤ 0.35 m (or one shallow step), else a raised solid | X3 | P: heavy-bag in/out |
| 5 | Parapet copings ≥ 50°; a 1.2 m parapet / invisible wall between the roof deck and the north-light sawtooth; no walkable slope < 50° outside the play mesh | Roof notes, CS glazing | `slopes` |
| 6 | Ladders: ≥ 1.0 m level landing at each top through the parapet; the areaway grate ≥ 1.0 × 1.0 m with the ladder on one side; the Mews drop section stays down (raises for police only) | Vertical data | P: both ladders |
| 7 | Route doors ≥ 1.0 m (staff door, SV, CO, CS, AT, TR, head house); NPC idle points ≥ 1 m off door centrelines; Stair SS single-file accepted | B2, roster | `doors` |
| 8 | Stairs collide as ramps, not per-tread boxes (SS and the imperial stair) | Vertical data | `stairs` |
| 9 | Velvet-rope runs: one box collider per run (or none), never the posts | GH `rope` | snag probe |
| 10 | Broken windows (EB, SL): frames keep a crew-only collision plane unless a route is intended | Room list | `clipping` |
| 11 | DC lit readable for ADS fights; key lights `viewmodel_lit` | Audio/lighting | `viewmodel_lit` |

**G1 tests (ENV P, windowed real input):** every laser gap walked/crouched; balcony throws at 3 pitches land on the hall
floor; Mews → LD with a heavy bag; pool in/out with a heavy bag; both ladders up and down; PO-3 snag probe = 0.

### B5. Objective `marker_tags` (ui_hud 1.8, D-089)
Map nodes carry these `objective_tags` (only the active variant slot's node exists, so a marker never points at an
inactive slot). The mission passes them as `data.marker_tags`.

| Objective | marker_tags | Tagged nodes |
|---|---|---|
| `casing` | `casing_hall` | a Marker3D at the GH stair foot (the casing objective shows while casing) |
| `find_canvases` | starts `[]`; grows per found slot | no spoiler markers before a find. When the crew marks a slot (or at start with `asset.intel_list`) the mission calls `update_objective_data(&"find_canvases", {"marker_tags": [<found slots' own tags>], "found": n})`; the HUD re-resolves on any data update and the data replicates (QC-60, ENV A 18cc33d0) |
| `keycard` | `keycard` | the active `keycard_pickup`s (`kc_*`), the curator's carried card (QC-52) |
| `server_code` | `code_note` | the active code note |
| `hack`, loud `hack` | `hack` | the SV `hack_terminal` |
| `server_door` (loud) | `server_door` | the SV door's drill point |
| `treasury` | `treasury_door` | the TR `keycard_reader` |
| `art_store` | `vault_reader` | the AS `keycard_reader` |
| `vault_drill` (loud) | `vault_drill` | the AS thermal-drill point |
| `lockdown` (loud) | `shutter` | the three shutters (completes at once) |
| `centrepiece` | `canvas_lantern` | the active centrepiece `loot_spawn` |
| `canvases` | `canvas_orchard`, `canvas_widow`, `canvas_saint` | the active slot of each group |
| `secure` | `secure_mews` / `secure_parade` | the active escape's SECURE_LOOT zone |
| `extras`, `lockers`, `curator_safe` | `lockers`, `curator_safe` | the `deposit_box`es, the CO safe |
| `escape_wait`, `escape` | `escape_mews` / `escape_parade` | the active ESCAPE zone |

### B6. Validator hooks this map sets (D-075, built 2026-10-14)
`camera_spine` (BC and UC, per `camera` layout) and `camera_screen` (`orchard_calloway`, `widow_sallow`,
`saint_maritime`, each behind a `partition_screen`) read HeistMap root meta (`tools/levelcheck/README.md`): `camera_spine_rooms = ["BC", "UC"]`, `camera_screen_slots =
["orchard_calloway", "widow_sallow", "saint_maritime"]`, `camera_layout_group = "camera"` (default). Layout cameras sit
under their `cam_a/b/c` VariantSlot; C11 and C14 sit outside any slot (live in every layout); screens carry meta
`kind = "partition_screen"` and a wall on the line does not count; the
plans and `--check` live in `tools/levelcheck/plans/gallery_night_floors_ascii.py`.

### B7. G1 skeleton choices (lead, round 127)
- **Bronze doors (VE, x 20–23, z 30):** two double doors with a 0.2 m pier between them (no single kit spans 4 m).
- **BC → LD door:** a 1.2 m service door (a 2 m double does not fit the 1.8 m corridor).
- **Stair SS / head-house wall:** 0.4 m thick at x 3.05 where it carries a door (the kit has no 0.3 m frame); the stair-side
  face is unchanged.
- **LD roller door:** a placeholder baked closed in the navmesh until a roller-door kit exists (art brief for ENV D); the
  Mews enters LD by the personnel door only.
- **Art-store vault door:** left open in the nav bake (closed, AS would be unreachable for the validator).
- **`saint_maritime`:** z 16 on the UG3 east wall (was 15) so the UG3 partition screen hides it from C10 (`camera_screen`).
- **Walkthrough whitelist at G1:** Mews → upper floors and roof → the rooms below it (long by plan: one Mews entry at the
  LD east end, one service stair at the far west).
