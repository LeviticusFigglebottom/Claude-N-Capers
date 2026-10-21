# Ostrander Federal: the Ostrander Plaza main branch (ostrander_federal)
Status: APPROVED (lead, 2026-10-11) (D-075). The lead's answers to the G0 open questions are folded in below (see Lead rulings).
Renamed from `meridian_federal` / "Meridian Federal" (D-075: "Meridian" is used by real banks). The
brass **meridian line** in the hall floor keeps its name: it is a feature, not the bank's name.

## D-136 build notes (OF-C0, ENV C, 2026-10-17)
The G0 design stands (D-075). These are the build-plan fixes from `docs/process/next_heist_ostrander.md` §3 (audit) and
§3b (D-136), with B's data (D-137). Each line names what changed and why.
1. **SD escort descoped (§3b.5):** the SD attendant and 0-1 customer spawn in SD; the manager walks SB alone on
   `mgr_vault`. Changed: Basement notes (SD), Room list (SB), Circulation, the roster (+ SD attendant, SD customer),
   the totals table. PD2 has no escorted customer flows.
2. **Assault events (§3b.6, D-114 §5, PO6-17 / X-3):** new subsection *Assault events* under Loud: 2 turret vans on
   Halloran Avenue, a police heli orbit over the terrace with rappel drops, 4 breach points (2 hall arched bays,
   the XL terrace doors, the HH roof door), with marker names and positions in the GH/DB/ND/GN format.
3. **D-122 breach layer (§3b.7):** new table *Loud-breachable shell doors* (Police entry points): dock roller and
   personnel doors, the fire exit, HH, the XL doors and the bronze/VE doors at lockdown are on `NAV_LAYER_BREACH`;
   the BARRED vault gate and the vault door are not breachable.
4. **D-102 bag carry (§3b.8):** cash and drives MEDIUM (×0.75, no sprint, 4 m throw), gold and drill parts HEAVY
   (×0.5, no sprint, 2 m), bonds LIGHT (sprint, 4 m). Changed: ghost line step 6, Loot path, throw spots.
5. **D-104 laser gap (§3b.8):** `lz_static` bypass gap ≥ **1.0 m** (was 0.8 m); a crouch-under grid's lowest beam
   has its lower face ≥ 1.215 m. Changed: Stealth routes (Lasers).
6. **Copings and glazing ≥ 50° (§3b.8, D-104 slope rule):** parapet copings and the lantern glazing ≥ 50° (45° is
   walkable for our 45° player); the lantern curb gets a sloped top. Changed: Play-space closure, the legend.
7. **Ghost line re-derived (§3b.8, D-102 + D-128):** new subsection *Ghost line timing* with the arithmetic. Result:
   the vault → CQ leg is ≈ 23 s per bag (the old "~25 s" assumed sprinting with cash), the whole bag phase ≈ 230 s,
   and two steps no longer fit as written (bags staged in LD; the E1 throw distance), flagged there with the fix.
8. **Carried keycard 1 s (§3b.2):** the take is `carried_item_s` 1.0 s (was "2 s"); QC-62 = QC-52 `carrier_tag`.
9. **No stealth-only fail; one escape rule (§3b.9/10):** fail = custody/abort only; the drill parts respawn at the
   drop; the hoist stays usable. The loud escape opens on `[secure]` + `escape_eta_s`. Changed: Mission script
   notes, Escape.
10. **D-128 "hidden" claims (§3b.11):** the counter and GA claims are validator-checked by LOS sample (`hide_los`,
    `teller_worktop`, OF-C3). The counter claim **fails as drawn** (a 1.05 m solid front never hides the 1.05 m
    crouched detection point from a standing observer), so the solid bandit-screen base rises to **1.50 m** (QC-g as amended by the LEAD, OF-C1). The GA
    solid base (1.0 m) holds. Changed: the legend, Ground notes, Sightlines.
11. **Loot follows data (§3b.3, D-117 §3, D-137):** values from `game/content/data/loot/*.tres` and B's OF-B1 data;
    `base_payout` **$80,000** (D-137, was $160,000). Changed: Loot table, HeistDef.
12. **Vaultline crew by SA (§3 audit):** NPCs cannot ride `bag_lift`; `armored_car_early` walks LD → BC → SA → BB.
13. **Vault on the ND pattern (§3b.1):** the lockdown cancels the mission's `time_lock` timer (no `Safe` API).
    Changed: Mission script notes, the QC-64 request.
14. **Validator configuration (OF-C3):** new subsection *Levelcheck configuration* under Budgets: the metas and kinds
    the greybox sets for `lasers`, `teller_worktop`, `hide_los` and `bag_line`.

## Fiction
- **Who:** **Ostrander Federal**, the city's clearing bank, at its 1928 main branch on **Ostrander
  Plaza** in the financial district (Board district `financial`). It is a three-storey limestone
  banking house with a basement vault. It faces the plaza and **Halloran Avenue** (south), with
  **Tannery Street** on the east corner and **Ledger Lane**, the service lane, behind it (north).
  Its west party wall adjoins the twelve-storey **Corvino Building**. The bank is open: it is a
  Friday afternoon, so there are customers in the hall, tellers at the counter, officers upstairs and
  the **day manager**, Lionel Ashgrove, on his rounds. Guarding is contracted to **Halden
  Security**: the day officers, plus a camera operator in the security room.
- **What:** the **quarterly consolidation**. Every branch in the region (Harbor Savings & Loan
  among them) sends its surplus to Ostrander Federal's main vault before Monday's **Vaultline Armored
  Transport** run to the reserve. For one weekend the vault holds pallets of strapped cash, the bank's
  own **gold** in the bullion cage, a drawer of **bearer bonds**, and two walls of private
  safe-deposit boxes.
- **Why / contact:** **The Accountant** (bank and corporate jobs, never seen): *"Every dirty dollar
  in this city passes through Ostrander Federal's vault on its way to looking clean. On Friday it all sits in
  one room. Ashgrove carries the card and somebody upstairs has the code. Bring me the consolidation,
  and if you can do it quietly, Monday's run will go out with a vault full of nothing."* The
  Accountant pays for the vault. The boxes, bonds and drives are the crew's own greed.
- **Time / weather:** 15:10 on a Friday in October. Broken cloud after a morning of rain. The plaza
  and the avenue are wet, and a low south-west sun breaks through in shafts. The hall is lit warm,
  and the lantern skylight drops a moving disc of sunlight across the brass meridian line in the
  floor. There is street traffic and a few pedestrians on the plaza.
- **Handler:** Mercer on comms. The crew arrives on foot on the plaza, by Ledger Lane, or by
  Tannery Street (the pre-planning spawn choice). The getaway van waits at the loading dock or on
  Tannery Street. In loud the thermal drill comes by helicopter drop or in Mercer's second van.

## Modes
- **Stealth + loud** (`HeistDef.mode = STEALTH_OR_LOUD`). **Size L** (25–40 min stealth, 25–40 min
  loud). Phase P5. It uses the full stealth set: casing in a working bank, **an NPC-carried keycard**,
  a **computer hunt** for the vault code, a server-room alternative, cameras and the operator, ECM, a
  laser grid, a **long time lock**, saws on deposit boxes and a padlocked cage, cuffs and the
  4-pager cap. In loud it uses the full P3 loud set plus a **thermal drill that burns down through
  the floor into the vault**.
- **How it scales up from Night Deposit** (the small bank, P2), deliberately:

  | | Night Deposit | Ostrander Federal |
  |---|---|---|
  | Time | 02:30, closed | 15:10, **open**: 11–18 civilians, casing in a busy public hall |
  | Keycard | 1 of 5 places, lying around | **carried by the manager** (or 3 fallbacks): take it from a person |
  | Code | a note in 1 of 4 places | **hack the right officer's computer** (1 of 5) or the server rack |
  | Time lock | 60–120 s | **150–270 s** while the bank keeps working above you |
  | Vault | 10 × 10 m, cage + boxes | **20 × 12 m**: cash cage, padlocked **bullion cage**, bond safe, 2 box walls, plus a **customer safe-deposit hall** |
  | Required | 4 bags | **6 bags** (4 on Routine, D-075) |
  | Loud | thermal drill on the door | **thermal drill delivered in 2 bags, burns through the teller-floor "lid"**; the crew goes down a rope ladder and bags come up a hoist |
  | Size | 1 storey + basement, 26 × 20 m | **3 storeys + basement + roof, 48 × 36 m**; double-height hall with an officers' gallery |

- **Stealth:** the bank is open. **PUBLIC:** the plaza, the streets, Ledger Lane, the vestibule,
  the customer side of the banking hall, the ATM vestibule and the customer restrooms. Everything
  else is RESTRICTED. Unmasked, the crew can read the counter, the manager's rounds, the gallery and
  the guards from the hall, and **walk into the back of house through doors staff leave unlocked**
  (detection ×0.35 while trespassing, S1.1). Masking in front of customers is the classic way to
  lose the run: civilians cannot see an unmasked player, but they see a masked one.
- **The vault needs** the **vault keycard** (the vault gate in the basement) **and** the **vault
  code**, which is entered at the time-lock console. The code is on one officer's computer (a
  `hack_terminal`, 45 s). Alternatively, **hack the vault-control rack in the server room** (90 s, 2
  interruptions), which starts the time lock directly. Then the time lock runs `time_lock_s` while
  the crew holds the basement quietly.
- **Loud:** the alarm triggers the vault's **lockdown**. A running time lock is aborted, the console
  dies and the vault door reseals. The crew calls in the **thermal drill** (2 HEAVY tool bags,
  dropped by helicopter on the hall-roof terrace or brought to the dock in Mercer's second van),
  assembles it on **the lid** (the marked vault-roof slab in the teller workroom floor) and holds the
  teller line for 360 s (jams). When it burns through, a **rope ladder** and a **bag hoist** drop
  into the vault. Bags go up the hoist, because bags cannot be carried on ladders (S10.1b).
- **Difficulty notes:**
  - Routine/Tense: 3 guards (lobby + vault + 1 rover) plus the operator (60%), 4–6 customers, time
    lock mostly 150–210 s.
  - Hazardous: 4 guards. **From here the guard count can exceed the pager cap** once the operator
    is in.
  - Brutal: 5 guards, operator 75%, 6–8 customers, sweeping lasers more often, and the
    `armored_car_early` event.
  - Lethal/Cataclysm: 6 guards and Titan cameras (S8.1). ECM or the operator are the only answers to
    cameras. At least two guards must be ghosted.
  - Loud: waves and factions per difficulty (L1.5). Brandt + Aegis come on Lethal+. Two always-on
    sniper perches, plus `tower_sniper` (Hazardous+).
  - **Solo with AI** (L6.1, D-014): in stealth the AI waits at the van, so a solo ghost is one
    player. In loud, AI teammates carry bags only when ordered. The two drill bags and the hoist make
    `carry_bag` orders the solo skill check.

## Site
- **Lot:** the bank is 48 × 36 m (wall centre lines; outer face 48.4 × 36.4 m). Ground FFL = 0.0;
  basement FFL −4.0 under the north 25 m only (the hall and plaza front stand on fill). Massing:
  - **north block** (x 0–48, z 0–17): ground, gallery level, executive level, roof at +12.2
    (parapet 1.1 m);
  - **side wings** (x 0–8 and x 40–48, z 17–36): ground + gallery level, roof at +8.6;
  - **banking hall** (x 8–40, z 17–36): double height to the coffered ceiling at +8.0, roofed at
    +8.6 by the **hall-roof terrace**, with the glazed **lantern skylight** in its middle. The wing
    roofs and the hall roof form one terrace at +8.6, open off the executive lounge.
- **Streets and surroundings:**
  - **South:** **Ostrander Plaza** (z 36–48): granite paving, 5 shallow steps (0.15 m) up to the
    bronze doors, benches, planters, bollards and a news kiosk. Beyond it is **Halloran Avenue** (z
    48–62), four lanes with a 3 m far sidewalk.
  - **East:** **Tannery Street** (x 48–62), two lanes plus a loading bay against the bank's east
    wall (the E2 van). Across it is the six-storey *Belmont Arms* hotel (dressing).
  - **North:** **Ledger Lane** (z −10…0), an 8 m service lane: the bank's loading dock, the
    dumpsters, and **the Corvino Building's rear fire escape**. North of the lane is the five-level
    *Ledger Lane Parking Structure* (top deck +12.0).
  - **West:** the **Corvino Building** (x −20…0), twelve storeys with a setback terrace at +16.0, a
    party wall with no openings at the bank's ground or upper floors.
- **Neighbours** (dressing except where stated):
  - **The Assay Office** (south, across Halloran Avenue, z 64–90): a civic building, roof +14.0.
    Its parapet is sniper perch **S1**.
  - **The Ledger Lane Parking Structure** (north): its top deck is perch **S2** (40, −34, +13.0).
    Its Tannery Street ramp hides the **P4** police spawn.
  - **The Corvino Building** (west): the rear fire escape (a stealth entry when its drop ladder is
    down), the **P5** police roof island on its +16.0 setback, and an office window at +20.0, perch
    **S3** (rare `tower_sniper`).
- **Exterior landmarks:**
  1. the **bronze sunburst** over the bronze doors: a 4 m gilded disc with the bank's
     name cut in the limestone frieze below it, visible from the plaza and the avenue;
  2. the **lantern skylight and the brass meridian line**. The glazed lantern rises over the hall
     roof (seen from the avenue, the terrace and the Corvino windows). Inside, a brass line with
     month marks runs N–S across the hall floor, and the lantern's oculus throws a disc of sunlight
     that crawls across it (seen from the whole hall, the gallery and the vestibule);
  3. the **bronze-and-glass vestibule** and the **teller line of 12 brass-grilled windows**, seen
     from the plaza through the open doors and the arched windows.
- **Play space:** x −16…66, z −14…64 for crew. The police spawns lie beyond the closures (avenue
  ends, lane west end, Tannery north, the Corvino setback). Each edge is closed as follows (the
  `bounds` validator checks every one).

### Play-space closure

| Edge | Closure |
|---|---|
| Halloran Avenue, west (x −16) | A police-style **road-works closure**: water-filled barriers and a parked utility truck across all 4 lanes (the **P1** spawn is behind the truck at (−30, 55)). Vista: the avenue continues to x −120 between office facades, then bends (a facade closes the axis). |
| Halloran Avenue, east (x 66) | A **stalled delivery truck and a bus** across the lanes past the Tannery junction (**P2** behind them at (80, 55)). Vista: the avenue to x 160, closed by the domed Exchange tower facade. |
| Avenue south side (z 62–64) | The Assay Office's 1.2 m stone balustrade and railings; its doors are closed (dressing). Its neighbours are solid facades. |
| Ledger Lane, west (x −16) | A **refuse truck** parked across the lane against the Corvino rear wall (**P3** behind it at (−30, −5)). |
| Ledger Lane, north side (z −10) | The parking structure's ground level: a 2.4 m mesh screen between concrete columns. Its pedestrian door is locked (no interaction); the ramp is on Tannery Street. |
| Tannery Street, north (z −14) | The parking structure's **exit barrier** and a ticket booth across the street mouth. The **P4** spawn is on the ramp behind it at (55, −45). Vista: Tannery continues north to a T-junction facade. |
| Tannery Street, east (x 62) | The Belmont Arms facade (no openings below +4.0: the lobby is round the corner, off-map). Its awnings and lit windows are dressing. |
| Corvino Building (x 0 and west) | A solid party wall. The fire escape (rear, in Ledger Lane) reaches the bank's main roof only (+12.2; `fire_escape` variable). Above +12.2, Corvino's wall continues to its setback at +16.0 (the P5 island, police-only, joined to our roofs by one-way rappel links, QC-68). |
| Main roof (+12.2) and hall-roof terrace (+8.6) | 1.1 m solid parapets with a **coping sloped ≥ 50°** (D-104 slope rule: 45° is walkable for our 45° player, so Shadow Ledger's 45° coping is not enough; nobody stands on it). Toward Tannery Street the terrace parapet (x 48, z 17–36) has a 1.1 m guard (a bag throw spot to E2, see Loot path): solid to 0.5 m, then a **mono-pitch coping** falling 0.6 m outward from the terrace face's 1.1 m top edge (56°; OF-C1 for OF-P1). The terrace side is a plain vertical face to 1.1 m, as on every parapet (above the 1.08 m jump apex: nobody climbs or walks off it). An `OUT_OF_BOUNDS` curtain sits 0.5 m beyond every parapet (D-040). |
| Lantern skylight | A raised 0.6 m curb with a **sloped curb top (≥ 50°)** and glazing **sloped ≥ 50°** above it (D-104: no walkable slope < 50° outside the play mesh; a flat 0.6 m curb is jumpable, apex 1.08 m). It cannot be walked on. It is the police rappel ENTRY into the hall, glass, breakable. |
| Up | Broken cloud, low SW sun. Every visible roof has a parapet and plant. |
| Far | Financial-district towers on every side at 80–300 m (LOD facades with lit floors). Nothing reachable sees the void. |

### Site plan
1 char = 2 m (x) and 1 row = 2 m (z), the same origin and axes as the floor plans (the bank's NW
corner; +x east, +z south). `#` the bank, `%` neighbour buildings, `=` parking structure deck, `f`
the Corvino fire escape, `d` dumpsters (`body_container`), `v` van E1 (dock) / E2 (Tannery bay),
`H` heli net (terrace, E3), `*` lantern, `^` plaza steps, `k` kiosk, `P` player spawns (plaza
default, lane, Tannery), `P1…P5` police spawn groups, `S1…S3` sniper perches.

```
     x -16 -8  0   8   16  24  32  40  48  56  64  72
  -46                                       P4
       ====================================  |    %%%%
  -38  ====== LEDGER LANE PARKING ===========|    %%%%
       ====== STRUCTURE (deck +12) ==========|    %%%%
  -30  ====================S2================| T  %%%%
       ======================================| A  %%%%
  -22  ======================================| N  %%%%
       ======================================| N  %%%%
  -14  ====================================== | E  %%%%
   P3                                          R
   -6   LEDGER LANE     P           d d        Y  %%%%
  %%%%%f    vvv                                   %%%%
    2 %%%%#########################            S  %%%%
  %%%%%%%%#  NORTH BLOCK roof +12.2#  vv       T  %%%%
   10 %%%%#  (executive level +8.6) #  vvE2    .  %%%%
  %%%%%%%%#                        #           P  BELMONT
   18 %%P5#########################           ARMS
  %%%%%%%%# wing #   ******     H  # wing           %%%%
   26 %%S3#  +8.6#   * LANTERN  H  #+8.6#          %%%%
  %%%%%%%%#      #   ******  E3 H  #    #          %%%%
   34 %%%%#     TERRACE +8.6 (hall roof)#          %%%%
  %%%%%%%%##########^^^^^^##############          %%%%
   42  OSTRANDER PLAZA   k   P P P    (bench/planters)
       
   50  HALLORAN AVENUE (4 lanes)
  P1                                            P2
   58  
       
   66  %%%%%%%%%%%%% THE ASSAY OFFICE  S1 %%%%%%%%%%%%%%
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
```
(The site plan is schematic. `ostrander_federal_site_ascii.py` (G1, as for Dockside Burn) generates
the scaled version from the same coordinates as the tables below.)

## Floor plans
1 char = 1 m. Each character is a **grid point** (x = col, z = row). Lines are **wall centre lines**:
exterior 0.4 m, interior 0.2 m, stair/lift cores 0.3 m, **vault walls 0.8 m reinforced**. The origin
is the bank's NW corner; +x is east and +z is south (Ledger Lane at the top, the plaza at the
bottom). Rulers are in metres. The plans were drawn from room rectangles in metres. At G1,
`tools/levelcheck/plans/ostrander_federal_floors_ascii.py` generates them, and its `--check` mode
verifies that the rooms tile each footprint, that every door sits on a wall, that every room has a
door, and the stair arithmetic below (as for Night Deposit, Shadow Ledger and Dockside Burn).

Legend: `#` exterior wall, `|`/`-` interior wall, `+` junction, `D` door (single 0.9 m; doubles
`DD` 1.8 m), `DDDD` the bronze doors / the vestibule inner doors (2 × 1.8 m), `R` roller door
(3.6 × 4.0 m), `W` window or interior glazing, `^ v` U-stair (up-flight, return flight), `=v` the
top floor of a stair (void over the arriving flight), `=` teller counter (customer ledge 1.05 m in front of a
**solid bandit-screen base to 1.50 m**, D-136 §3b.11, QC-g amended; bandit glass above it; teller work top 1.00 m), `g` teller gate, `t` teller station, `T` **the lid**
(thermal-drill point over the vault), `m` the brass meridian line, `G` guard post / pause point,
`c` the manager's desk, `Mo` the camera-station monitor wall, `$$` ATMs, `n` the night
depository slot, `k` code-PC candidate (`code_pc`), `K` keycard reader (vault gate), `GGG` the vault
gate (2.0 m steel grille), `:` laser grid, `TL` time-lock console, `VVV` the vault door (round,
2.4 m), `b` safe-deposit box wall (`deposit_box`), `S` safe, `P` padlock (bullion cage), `x` the
hole under the lid, `SRV` server rack (`server_room` slot), `r` 1.1 m guard (gallery), `.` void,
`*` lantern skylight, `H` heli cargo net (E3), `h` caged ladder (roof → terrace), `p` parapet
(1.1 m, coping ≥ 50°, D-104), `fe` the fire-escape arrival, `rp` the police rappel landing.

**Vertical data** (`HeistMap.floor_heights = [-4.0, 0.0, 5.0, 8.6, 12.2]`, `floor_names =
["Basement", "Ground", "Gallery", "Executive", "Roof"]`, D-054; ascending and containing 0.0, D-040):

| Level | FFL | Ceiling | Floor-to-floor / slab | Notes |
|---|---|---|---|---|
| Basement | −4.0 | 3.2 (vault 3.2) | 4.0 (0.8 vault-grade slab, Night Deposit precedent) | override 2.6–3.2 for the basement corridor, storage, lockers and comms (below) |
| Ground | 0.0 | **banking hall 8.0** (`hall`, D-075); teller workroom, client lounge, vestibules, dock 4.2; offices, BOH 3.0 (dropped ceiling) | 5.0 (4.2 + 0.8 slab; over the 3.0 rooms a 1.2 m plenum carries the HVAC trunks and the bank's pneumatic-tube system, as Shadow Ledger's BOH, D-042) | hall 6–9 ✓ (D-075); banking_hall 3.5–6 ✓ (TW); lobby 3.0–4.5 ✓; warehouse 3.5–6 ✓; office 2.6–3.0 ✓ |
| Gallery | 5.0 | 3.0; the gallery GA stands under the hall ceiling (3.0 headroom) | 3.6 (3.0 + 0.6) | office ✓, lobby ✓ |
| Executive | 8.6 | 3.0 | 3.6 (3.0 + 0.6) | office ✓; the hall-roof terrace is at this level (exterior) |
| Roof | 12.2 | head house 2.7 clear | — | parapet 1.1 m |
| Stairs SA and SB | −4.0 → 0.0 | U-stair, 2 flights × 11 risers @ 0.1818 m, tread 0.28 m (run 2.80 m), width 1.2 m | 22 risers = 4.0 ✓ | landing every 11 ≤ 16 ✓ |
| Stairs SA and SB | 0.0 → 5.0 | 2 flights × 14 risers @ 0.1786 m, tread 0.28 (run 3.64 m) | 28 risers = 5.0 ✓ | landing every 14 ≤ 16 ✓ |
| Stairs SA and SB | 5.0 → 8.6 | 2 flights × 10 risers @ 0.180 m (run 2.52 m) | 20 risers = 3.6 ✓ | SB tops out at Executive |
| Stair SA only | 8.6 → 12.2 | 2 flights × 10 @ 0.180 m (run 2.52 m) | 20 risers = 3.6 ✓ | head house HH |
| Corvino fire escape | street → +12.2 | steel stair (dressing) + the **drop ladder** (`ladder` 3.0 m, lane → first landing) | — | crew only, masked (S1.1), no bags (S10.1b) |
| Roof → terrace ladder | 12.2 → 8.6 | caged `ladder` 3.6 m at (46, 17) | — | no bags |
| Rope ladder (loud, after the burn) | −4.0 → 0.0 | `ladder` 4.0 m through the 1.2 m hole at (24, 14) | — | enabled by the mission (QC-61) |

**Stair core fit** (both cores 3.0 × 7.0 m centre lines, 0.3 m walls → 2.7 × 6.7 m clear): flights
1.2 + 0.2 well + 1.2 = 2.6 ≤ 2.7 ✓. Along z: half landing at the north end, flights, floor landing
at the south end. The longest storey (5.0 m) needs 1.30 + 3.64 + 1.30 = 6.24 ≤ 6.70 ✓. Every
up-flight starts at the same edge (Shadow Ledger rule), so the shorter runs leave a deeper half
landing, and a flight is always one full storey (≥ 3.6 m) under the flight above it: headroom
≥ 3.3 m ✓. Stair doors (1.0 m, with a vision panel) sit on the south floor landing at z 7 and open
onto a level landing, never a flight. **Handrails 1.0 m on both sides of every flight** (D-054: the
1.0–1.1 m band); the well side has a 1.05 m guard with a handrail top.

**Ceiling bands and per-room overrides (D-048, D-075).** The §2.6 table is generic.
- **BH** (banking hall), **8.0 m, purpose `hall` (6.0–9.0, D-075), no override:** a 1928 main-branch
  banking hall is a double-height civic room. The officers' gallery runs along its north side at
  +5.0 under a coffered ceiling and a laylight. The `banking_hall` row (3.5–6.0) describes a branch
  like Night Deposit; this one is the heist's landmark and its loud arena, so the lead added the
  `hall` purpose for it (and for Afterhours' dance hall).

These rooms keep a `ceiling_range` override, for these reasons:
- **Basement BB, RC, SS, LK, CM, CQ** (corridor, storage, lockers, comms), **3.2 m, override
  2.6–3.2:** the Night Deposit precedent (D-040/D-048): a vault-standard basement with a uniform
  3.2 m clear height under the 0.8 m slab, exposed services and no dropped ceiling.
- **XL** (executive lounge), **override 2.6–3.0:** Shadow Ledger QC-31: a lounge has no row in the
  table; same band as `living_room`.
- Every other room is inside its purpose's band: `vault` 2.6–6.0, `plant` 2.6–6.0 (validator
  ranges), `warehouse` 3.5–6.0 (LD), `lobby` 3.0–4.5 (VE, AV, PC, GA), `banking_hall` (TW at 4.2).

**Wide doors.** The dock roller door (3.6 × 4.0 m) is a `door` with `width_m` 3.6 and meta
`kind = "industrial_door"` (D-064 rule). The vault door (2.4 m round) uses the `vault_door` rule
(1.8–2.4 m, D-048). The vault gate (2.0 m grille) is a `door` KEYCARD with `width_m` 2.0.

### Basement (FFL −4.0; footprint x 0–48, z 0–25)
```
      0123456789012345678901234567890123456789012345678
    0 #################################################
      #LK LOCKER|GL|^v|CP COUNT |PL PLANT|CM  |SS  |^v#
    2 #         |  |^v|         |        |  SRV    |^v#
      #         +D-+^v|         |        |    |    |^v#
    4 #         |CQ|^v|         |        |    |    |^v#
      #         |  |  |         |        |    |    |  #
    6 #         |  |  |         |        |    |    |  #
      #----D----+-D+D-+----D----+---D----+-D--+-D--+D-#
    8 #BB BASEMENT CORRIDOR                           #
      #-----D-------+-GGG---------------+-------D-----#
   10 #RC RECORDS   |VC    :            |SD SAFE DEPOS#
      #             |  K   :    G       |             #
   12 #             |      :          TL| bbbbbbbbbbb #
      #             +--------------VVV--+             #
   14 #             |VT VAULT           |             #
      #             |bbbbbbbbbxb [GOLD]P|             #
   16 #             |                   |             #
      #             |                   | bbbbbbbbbbb #
   18 #             |     [CASH CAGE]   |             #
      #             |                   |             #
   20 #             | S                 |             #
      #             |                   |             #
   22 #             |                   | bbbbbbbbbbb #
      #             |bbbbbbbbbbbbbbbbbbb|             #
   24 #             |                   |             #
      #################################################
```

Basement notes:
- **VC, the vault concourse** (20 × 4 m): the keycard **vault gate** `GGG` from BB (x 16–18),
  the **laser grid** across the concourse at x 21 (full 4 m width), the **time-lock console** `TL`
  on the east wall beside the **vault door** `VVV` (x 29–31, z 13). The fixed vault guard's post is
  at `G`.
- **VT, the vault** (20 × 12 m): the **cash cage** in the centre (3 × 5 m mesh room, gate opens
  with the vault; `loot_spawn` `loot.cash_bricks` × `cash_bags`), the **bullion cage** in the NE
  corner (mesh, **padlock** `P`: lockpick 8 s or saw; `loot_spawn` `loot.gold` × `gold_bags`), the
  **bond safe** `S` (SW; `safe` SMALL, `methods [drill, saw, lockpick]`: 1 bag `loot.bearer_bonds`),
  and **two deposit-box walls** `b` (north and south walls; `deposit_box` × `deposit_boxes`,
  G.SAW_TARGET). `x` marks the hole under the lid (loud).
- **SD, the safe-deposit hall** (14 × 16 m): three rows of customer boxes (`deposit_box` × 24
  candidates, 8 active; see Loot), viewing booths along the east wall, the attendant's desk. Door to
  BB only. **D-136 §3b.5:** the SD attendant and 0-1 customer spawn in SD at the start (no escorted customer
  flow down SB). In the `mgr_vault` roll the manager walks SB alone and stops at the attendant's desk.
- **CQ** is the cart queue in front of the **cash lift GL** (`bag_lift`, Basement ↔ Ground, 2 bags,
  8 s). It lands in the loading dock LD.

### Ground floor (FFL 0.0)
```
      0123456789012345678901234567890123456789012345678
    0 #W#RRRR#D########################################
      #LD DOCK  DGL|^v|SR SEC|GR GU|WM|WW|J1|MO MAI|^v#
    2 #         |  |^v|      |     |  |  |  |      |^v#
      #         +D-+^v|  Mo  |     |  |  |  |      |^v#
    4 #  P      |E1|^v|      |     |  |  |  |      |^v#
      #         |  |  |      |     |  |  |  |      |  #
    6 #         |  |  |      |     |  |  |  |      |  #
      #         +-D+D-+--D---+--D--+D-+D-+D-+--D---+D-#
    8 #         DBC BACK CORRIDOR                     D
      #-------+-+---D-------------------D-----+---D---#
   10 #LO LOAN|TW TELLER WORKROOM             |PC CLIE#
      #       |                               |       W
   12 #       D    t t t             t t t    D       #
      #       |                               |       #
   14 #       |               T               |       #
      #       |                               |       W
   16 #       |                               |       #
      #       +===============g===============+       #
   18 #       DBH BANKING HALL                D       #
      #-------+               m               +-------#
   20 #CN1    |                               |BM MANA#
      #       D               m               |       W
   22 #       |                               |       #
      #       |               m               D       #
   24 #-------+                               |   c   W
      #CN2    |               m               |       #
   26 #       D                               |       #
      #       |               m               +-------#
   28 #       |                               |PW WC  #
      #-------+               m               D       #
   30 #AV ATM |               G               |       #
      #       |               m               +-------#
   32 #       D           +-DDDD--+           |NA ACCT#
      # $$  n |           |VE     |           D       W
   34 #       |           |       |           |       #
      #       |           |       |           |       #
   36 ####D#####WWWWWWWW####DDDD####WWWWWWWW###########
```

Ground notes:
- The **teller line** runs the full width of TW at z 17: 12 windows (6 staffed stations `t`, the
  rest closed with brass grilles), a **customer ledge 1.05 m** projecting in front of a **solid bandit-screen
  base to 1.50 m** with bandit glass above it, and a **teller work top 1.00 m whose near edge is 0.28 m in front
  of the teller's stand point** (characters.md v1.9 `teller_count` placement, lead note). The work top is a
  standing counter: levelcheck kind `teller_worktop` (0.95–1.05 m top, 0.45–0.9 m deep, a ≥ 0.9 m clear stand
  zone on the teller side, the solid front checked against the crouch-hide claim; OF-C3). **Why 1.50 m (D-136
  §3b.11, D-128):** a crouched player's detection points are 1.0 and 1.05 m above the feet (StealthTweak
  `los_heights` 1.6 / 1.0 clamped to the crouched eye 1.05). A ray from a standing observer's eye (1.62 m) down to
  the 1.05 m point stays above 1.05 m all the way, so a 1.05 m solid front never hides it. With the crew centre
  d ≈ 0.95 m behind the front (0.6 m work top + 0.35 m capsule radius) and the observer ≥ 2.0 m from the crew
  (inside 2 m PD2 uncovers a crouched player anyway, S2.2), the front must reach 1.05 + (1.62 − 1.05) × 0.95 / 2.0
  = **1.32 m** for an observer straight out from the counter. **QC-g amended (LEAD, OF-C1 build):** `hide_los`
  also samples observers along the counter face (z ≈ 17.75, the ledge's front plus the NPC radius) at the 2.0 m
  flat uncover radius but only ~1.5 m out from the crew, whose sight line to the 1.05 m point crosses the screen
  face at ≈ 1.44 m; the solid base is therefore **1.50 m**, bandit glass 1.50–2.40 m. QC-67 (ENV D probe): the screen
  stands 0.82 m behind the customers' marks (z 16.83–16.93; the 0.52 m ledge runs to the hall face at z 17.45), so the `counter_customer`
  forearms clear it; the work tops are 0.48 m deep. The 1.05 m
  ledge stays as the customers' writing ledge. The teller
  gate `g` (x 24) is LOCKPICK and NPC-authorised.
- **The lid** `T` at (24, 14): a 2.4 × 2.4 m brass-bordered marble panel in the TW floor marking
  the vault roof slab below (the tellers' name for it). In loud the drill is assembled here.
- **SR, the security room:** the camera-station monitor wall `Mo` is against the **north exterior
  wall**. The operator sits facing north, so the door (south, from BC) is directly behind him (the
  Shadow Ledger "work it from behind" layout). The guards' key cabinet (`kc_security`) is on the
  east wall.
- The **brass meridian line** `m` runs N–S at x 24 from the counter to the vestibule.
- **BM, the branch manager's office:** glass front to the hall. Ashgrove's desk `c`
  (`kc_manager_desk`, the planner with the `[code_hint]`), a credenza and a phone.
- **AV, the ATM vestibule** (24 h): 2 ATMs, the night-depository slot `n` (dressing), a street door
  S and a glass door E into the hall (both open during business hours).
- **Exterior doors:** the bronze doors (VE, S), the AV street door, the dock roller door and the
  dock personnel door (N, LOCKPICK), and the **east fire exit** at the BC east end (x 48, z 8:
  `push_bar`, opens only from inside unless propped).

### Gallery level (FFL 5.0)
```
      0123456789012345678901234567890123456789012345678
    0 #################################################
      #BR BREAK |E2|^v|IT    |SV SE|WM|WW|J2|AR ARC|^v#
    2 #         |  |^v|      |     |  |  |  |      |^v#
      #         |  |^v|      | SRV |  |  |  |      |^v#
    4 #         |  |^v|      |     |  |  |  |      |^v#
      #         |  |  |      |     |  |  |  |      |  #
    6 #         |  |  |      |     |  |  |  |      |  #
      #----D----+-D+D-+--D---+--D--+D-+D-+D-+--D---+D-#
    8 #UC UPPER CORRIDOR                              #
      #-----+D+---D---------------+--D--+--D--+D+-----#
   10 #AO1  | |OF OPERATIONS      |CF CO|CO   | |VO   #
      #     | |                   |     |     | |     #
   12 # k   | |   k               |     |     | | k   #
      #     D |                   |     |     | D     #
   14 #     | |                   |     |     | |     #
      #     | |                   |     |     | |     #
   16 #     | |                   |     |     | |     #
      #     | +---------D---------+--D--+-----+ |     #
   18 #-----+ DGA GALLERY     G               D +-----#
      #AO2  | |                               | |TR   #
   20 #     | rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr+ |     #
      # k   | W...............................W |     #
   22 #     D |...............................| D     #
      #     | |...............................| |     #
   24 #     | W...............................W |     #
      #     | |...............................| |     #
   26 #     | |...............................| |     #
      #-----+ W...............................W +-----#
   28 #AO3  | |.......VOID OVER THE BANKING HALL|TT   #
      #     | |...............................| |     #
   30 # k   | W...............................W |     #
      #     D |...............................| D     #
   32 #     | |...............................| |     #
      #     | W...............................W |     #
   34 #     | |...............................| |     #
      #     | |...............................| |     #
   36 #################################################
```

Gallery notes:
- **GA, the officers' gallery** (32 × 3 m) runs along the hall's north side at +5.0 with a **1.1 m
  bronze-and-glass guard** `r` (≥ 1.0 m, D-054; handrail top at 1.1). It looks down on the whole hall
  and is a bag **throw spot** to the hall floor (5.0 m).
- **WL / EL, the loggias** (2 m corridors along the hall's west and east sides) are glazed to the
  hall void (`W`, interior glazing with a purpose: officers watching the floor). Anyone in them is
  visible from the hall, and vice versa.
- Code-PC candidates `k`: AO1, AO2, AO3 (account officers), OF (operations, the supervisor's desk)
  and VO (vault operations). The fifth candidate is on the executive level (EA).
- **SV, the server room:** racks, CRAC, and the **vault-control rack** `SRV` when `server_room =
  srv_gallery`. The other option puts it in the basement CM.

### Executive level (FFL 8.6) and the hall-roof terrace
```
      0123456789012345678901234567890123456789012345678
    0 #################################################
      #BD BOARD |E3|^v|EA ASS|PR PRESIDEN|PN PAN|XW|^v#
    2 #         |  |^v|      |           |      |  |=v#
      #         |  |^v|  k   |      S    |      |  |=v#
    4 #         |  |^v|      |           |      |  |=v#
      #         |  |  |      |           |      |  |  #
    6 #         |  |  |      |           |      |  |  #
      #----D----+-D+D-+--D---+----D------+--D---+D-+D-#
    8 #XC EXEC CORRIDOR                               #
      #-----D---------+-----D-----+-----D-----+---D---#
   10 #XL EXEC LOUNGE |LG LEGAL   |CT TRUST   |RA RECO#
      #               |           |           |       #
   12 #               |           |           |       #
      #               |           |           |       #
   14 #               |           |           |       #
      #               |           |           |       #
   16 #               |           |           |       #
      #WWW-DD---DD----+-WWWW------+-WWWW------+-WWWW--#
   18 p                                             h p
      p                                               p
   20 p TERRACE +8.6 (roof over the hall)             p
      p                                               p
   22 p             *****************                 p
      p             *               *                 p
   24 p             *               *  HHHHHHH        p
      p             *               *  H     H        p
   26 p             *   LANTERN     *  H E3  H        p
      p             *               *  H net H        p
   28 p             *               *  H     H        p
      p             *               *  H     H        p
   30 p             *****************  HHHHHHH        p
      p                                               p
   32 p  planters                                     p
      p                                               p
   34 p                                               p
      p                                               p
   36 ppppppppppppppppppppppppppppppppppppppppppppppppp
```

Executive notes:
- **PR, the president's office** (the president is away: Friday): the **president's wall safe** `S`
  (`safe` MEDIUM, `methods [drill, saw]`; `president_safe` variable), desk, bookshelves, a portrait.
- **EA, the executive assistant's office:** the fifth code-PC candidate `k` (`pc_exec`).
- **XL, the executive lounge:** two pairs of glass doors (`DD`, LOCKPICK from outside) onto the
  **terrace** (+8.6, exterior): planters, benches, the lantern skylight `*` (not walkable), and the
  heli **cargo net** `H` (E3, SECURE_LOOT). The caged ladder `h` comes down from the main roof. As built (G1), the
  net (`SecureTerrace`) is at x 40.5–44.5, z 23.5–28.5, east of the heli's ESCAPE area (x 32.5–38.5, z 24–30, the `H`
  drawn above): the net drawn at x 33–39 was inside C12's cone (see Sightlines), so it moved east; the ESCAPE stayed.

### Roof (+12.2; north block)
```
      0123456789012345678901234567890123456789012345678
    0 ppppppppppppppppppppppppppppppppppppppppppppppppp
      p            |=v|                               p
    2 pfe          |=v|   +-------------+             p
      p            |=v|   |ROOF PLANT   |             p
    4 p            |=v|   |             |   AHU       p
      p            |  |   |             |             p
    6 p            |  |   |             |             p
      p            +D-+   |             |             p
    8 p                   |             |             p
      p                   |             |             p
   10 p                   +------D------+             p
      p                                               p
   12 p     ROOF +12.2                        tank    p
      p                                               p
   14 p rp                                            p
      p                                               p
   16 p                                             h p
      ppppppppppppppppppppppppppppppppppppppppppppppppp
```

Roof notes: **HH** is Stair A's head house (roof door LOCKPICK 8 s from the roof, push bar inside).
`fe` is where the Corvino fire escape's top landing meets the bank's west parapet: a 0.6 m step over
a lowered coping section with a 1.1 m rail on each side. `rp` is the P5 rappel landing (police
only). There is plant (AHU, tank, condensers) and the caged ladder `h` down to the terrace.

## Room list
Sizes are between wall centre lines. Office windows have a 0.9 m sill. The hall's arched windows
(south facade) have a 1.0 m sill and are 5.5 m tall. Glass-fronted offices to the hall (LO, CN1/2,
BM, NA) have clear glass from 0.9 m.

| id | purpose (`RoomVolume.purpose`) | size m | ceiling m | kit | notes |
|---|---|---|---|---|---|
| LK | locker_room (staff, with WCs) | 10 × 7 | 3.2 (override) | `locker_room` | Staff lockers, benches, 3 WC cubicles, sink row. The manager's WC break (`mgr_vault`). No guard loop enters it (staff privacy): the ghost line's room. BODY_HIDE (2, lockers). Drop zone `pp_drop_lockers`. |
| GL | elevator (cash lift) | 3 × 3 | — | — | **`bag_lift`** Basement ↔ Ground, 2 bags, 8 s. B door S (CQ), G door W (LD). |
| CQ | storage (cart queue) | 3 × 4 | 3.2 (override) | `cash_transfer` | Cash carts, sealed-bag shelving. Doors N (lift) and S (BB). |
| SA | stair (A) | 3 × 7 | open | — | Basement → Ground → Gallery → Executive → Roof. |
| CP | cash_office (count room) | 10 × 7 | 3.2 | `count_room` | Counting tables, note counters, a sealer, strap bins. `small_loot` × 4 (strapped cash). |
| PL | plant | 9 × 7 | 3.2 | `plant_room` | Boilers, AHU, vault ventilation. **Areaway grate** to Ledger Lane: the Phantom's vent (nav layer `vent`, FLANK). BODY_HIDE (1). |
| CM | server_room (comms) | 5 × 7 | 3.2 (override) | `server_room` | Telecom frame, alarm panel. `srv_basement`: the vault-control rack `SRV` + the laser controller. |
| SS | storage (supplies) | 5 × 7 | 3.2 (override) | `storage_supplies` | Coin bags, deposit slips, shredder. |
| SB | stair (B) | 3 × 7 | open | — | Basement → Ground → Gallery → Executive (top). The manager's route to SD on `mgr_vault` (alone, D-136 §3b.5). |
| BB | corridor (basement) | 48 × 2 | 3.2 (override) | `corridor_service` | Basement spine; the vault gate is in its south wall. Dead ends at LK (W) and SB (E) have reasons (lockers, stair). |
| RC | storage (records) | 14 × 16 | 3.2 (override) | `storage_archive` | Compact shelving (cover: aisles 1.0 m), archive boxes. The wait room for the time lock. |
| VC | vault (concourse) | 20 × 4 | 3.2 | `vault_antechamber` | Laser grid, TL console, vault gate, vault door, viewing bench. |
| VT | vault | 20 × 12 | 3.2 | `vault_main` | See Basement notes. Round door 2.4 m, VAULT lock, time lock. |
| SD | vault (safe-deposit hall) | 14 × 16 | 3.2 | `deposit_hall` | Customer box rows, viewing booths, attendant desk, phone. |
| LD | warehouse (loading dock / sally port) | 10 × 9 | 4.2 | `sally_port` | Armoured-car transfer: roller door + personnel door N (Ledger Lane), cash carts, the lift door, a bench. |
| E1 | electrical | 3 × 4 | 3.0 | `electrical_closet` | Main board, alarm-bell isolators (dressing). |
| SR | security_room | 7 × 7 | 3.0 | `security_office` | `camera_station` (monitor wall on the N exterior wall), key cabinet (`kc_security`), lockers, coffee, phone, `alarm_button`. |
| GR | locker_room (guards) | 6 × 7 | 3.0 | `locker_room` | Halden lockers, kit bench, the guards' WC. |
| WM, WW | restroom (staff) | 3 × 7 each | 3.0 | `restroom_multi` | 2 cubicles each, sinks. |
| J1 | janitor | 3 × 7 | 3.0 | `janitor_closet` | Mop sink, cart. BODY_HIDE (1). |
| MO | office (mail and operations) | 7 × 7 | 3.0 | `copy_room` | Pneumatic-tube station, mail sorting, copier. |
| BC | corridor (back of house) | 38 × 2 | 3.0 | `corridor_service` | The ground spine. East end: the **fire exit** to Tannery Street (push bar; `door_fire_propped`). |
| LO | office (loans) | 8 × 10 | 3.0 | `office_loan` | 2 desks, files. Hall door (unlocked during hours), TW door (LOCKPICK). |
| TW | banking_hall (teller workroom) | 32 × 8 | 4.2 | `teller_line` | 12 windows, 6 stations, cash drawers (`small_loot` × 6), note counters, **the lid**. Doors to BC × 2 (LOCKPICK, NPC-authorised), to LO and PC, the teller gate. |
| PC | lobby (private-client lounge) | 8 × 10 | 4.2 | `lounge_client` | Armchairs, coffee service, 0–2 clients. Hall door unlocked; **the BC service door is unlocked during hours** (the coffee runs): the front route's way in. |
| CN1, CN2 | office (consultation) | 8 × 5 each | 3.0 | `meeting_small` | Round table, 4 chairs, glass front. |
| AV | lobby (ATM vestibule) | 8 × 7 | 4.2 | `atm_vestibule` | **PUBLIC.** 2 ATMs, night slot, street door, hall door. |
| BH | hall (banking hall; D-075) | 576 m² (32 × 19 less VE) | **8.0** (`hall` 6.0–9.0) | `banking_hall_grand` | **PUBLIC.** The meridian line, 4 check-writing tables, queue rails, 6 benches, the lobby guard post, 2 arched-window bays × 2. The officers' gallery overhead (N). |
| VE | lobby (vestibule) | 8 × 4 | 4.2 | `vestibule_bronze` | **PUBLIC.** Bronze outer doors, glass inner doors (both open during hours). |
| BM | office (branch manager) | 8 × 8 | 3.0 | `office_manager` | See Ground notes. Window E. |
| PW | restroom (customer) | 8 × 4 | 3.0 | `restroom_single` | **PUBLIC.** 2 single WCs off a sink lobby. The safe place to mask up in the hall. Drop zone `pp_drop_restroom`. |
| NA | office (new accounts) | 8 × 5 | 3.0 | `office_small` | Desk, 2 chairs, brochure rack. Window E. |
| BR | break_room | 10 × 7 | 3.0 | `break_room` | Fridge, counter + sink, microwave, coffee, table for 8, bulletin board, phone. Windows N. |
| E2, E3 | electrical (riser) | 3 × 7 | 3.0 | `electrical_closet` | Sub-boards, the riser. |
| IT | office (IT) | 7 × 7 | 3.0 | `office_it` | Desks, spares. |
| SV | server_room | 6 × 7 | 3.0 | `server_room` | Racks, CRAC, UPS. `srv_gallery`: the vault-control rack + the laser controller. **2 `loot.server_drives`** (optional, both rolls). Door LOCKPICK. |
| WM, WW (Gallery) | restroom | 3 × 7 each | 3.0 | `restroom_multi` | |
| J2 | janitor | 3 × 7 | 3.0 | `janitor_closet` | BODY_HIDE (1). |
| AR | storage (archive) | 7 × 7 | 3.0 | `storage_archive` | Ledgers, file boxes. |
| UC | corridor (gallery level) | 48 × 2 | 3.0 | `corridor_office` | End window E (the W end is the party wall). |
| AO1–AO3 | office (account officers) | 6 × 9 each | 3.0 | `office_small` | Desk + PC (`k`), files, visitor chairs. Doors to WL. |
| WL, EL | corridor (loggias) | 2 × 27 each | 3.0 | `corridor_glazed` | Glazed to the hall void. |
| OF | office (operations, open plan) | 20 × 8 | 3.0 | `office_open` | 8 workstations in 2 clusters; the supervisor's PC (`k`). Door S onto the gallery. |
| CF | office (conference) | 6 × 8 | 3.0 | `conference_room` | Table for 8, screen. |
| CO | office (compliance) | 6 × 8 | 3.0 | `office_small` | |
| GA | lobby (officers' gallery) | 32 × 3 | 3.0 headroom (under the 8.0 hall ceiling) | `gallery_mezzanine` | 1.1 m guard, 2 writing desks, a bench. |
| VO | office (vault operations) | 6 × 9 | 3.0 | `office_vault_ops` | The vault schedule desk: `k` (`pc_vault_ops`), `kc_vault_ops` drawer, a key safe (dressing). |
| TR | office (treasury) | 6 × 9 | 3.0 | `office_small` | |
| TT | office (training room) | 6 × 9 | 3.0 | `meeting_small` | |
| BD | office (boardroom) | 10 × 7 | 3.0 | `boardroom` | Table for 14. |
| EA | office (executive assistant) | 7 × 7 | 3.0 | `office_small` | `k` (`pc_exec`). |
| PR | office (president) | 12 × 7 | 3.0 | `office_partner` | The president's safe. |
| PN | break_room (executive pantry) | 7 × 7 | 3.0 | `break_room` | Fridge, counter + sink, coffee, table for 4, bulletin board. |
| XW | restroom (executive) | 3 × 7 | 3.0 | `restroom_single` | |
| XC | corridor (executive) | 48 × 2 | 3.0 | `corridor_office` | |
| XL | lounge (executive) | 16 × 8 | 3.0 (override 2.6–3.0) | `lounge_exec` | Sofas, bar, terrace doors. |
| LG | office (legal) | 12 × 8 | 3.0 | `office_open` | |
| CT | office (trust department) | 12 × 8 | 3.0 | `office_open` | |
| RA | storage (records) | 8 × 8 | 3.0 | `storage_archive` | |
| HH | stair (head house) | 3 × 7 | 2.7 | — | Roof door. |
| X1 | exterior (plaza + avenue) | 82 × 28 | — | `exterior_plaza` | Steps, benches, planters, bollards, kiosk, street lamps, parked cars, traffic (dressing). |
| X2 | exterior (Ledger Lane) | 82 × 10 | — | `exterior_alley` | Dumpsters (`body_container`), the fire escape, the dock apron, C6 pole. |
| X3 | exterior (Tannery Street) | 14 × 78 | — | `exterior_street` | Loading bay (E2), hydrant, parked cars. |
| X4 | exterior (terrace, +8.6) | 48 × 19 | — | `exterior_terrace` | Planters, benches, the lantern, the heli net. |
| X5 | exterior (main roof, +12.2) | 48 × 17 | — | `exterior_roof` | Plant, AHU, tank, the ladder. |

New kits (ENV C builds them at G2): `banking_hall_grand`, `vestibule_bronze`, `lounge_client`,
`deposit_hall`, `office_vault_ops`, `exterior_plaza`. The rest exist or come from the precedents.

Support-space check (level_standards §2.2):
- restrooms on every floor: LK (B), WM/WW + PW (G), WM/WW (Gallery), XW (Executive); about 40
  staff ✓;
- break room BR, pantry PN ✓; janitor J1, J2 ✓; electrical E1, E2, E3 ✓; IT/comms IT, SV, CM ✓;
- the loading dock LD and the cash lift ✓;
- **2 stair cores** for more than 2 floors ✓. Fire exits: the BC east door, SB to the BC east end,
  the VE doors and the AV door. The longest travel to a stair or exit is about 26 m (AO3's SW
  corner to SA) ✓.

## Circulation
- **Public (business hours):** the plaza and the avenue ↔ VE ↔ the hall (queue at the counter,
  check-writing tables, benches, the PW restrooms, the AV vestibule) ↔ by invitation PC, CN1/2,
  LO, NA, BM.
- **Staff:** Ledger Lane → the dock personnel door (badge, NPC-authorised) → BC → everything. TW
  ↔ BC by the two staff doors. Officers use SA/SB to the gallery and executive levels. The manager
  walks SB alone to the basement on `mgr_vault`; the SD attendant and her customer start in SD (no escort,
  D-136 §3b.5).
- **Guards** (one `bank` PatrolGraph across all floors, linked through SA/SB stair points, plus a
  `lane` graph outside; ≥ 3 loops per post, heist_map §4):
  - **`post_lobby` (fixed, BH by the vestibule, facing N):** (a) VE ↔ hall circuit (meridian
    line → windows → PW door → NA door → VE); (b) hall → teller gate → TW → BC → PC → hall; (c) hall
    → LO → TW → BC → SR (coffee pause) → BC → PC → hall.
  - **`post_vault` (fixed, basement):** (a) VC (pause at `G` facing W, 15–30 s) ↔ the gate; (b) BB
    → RC (aisle walk) → BB; (c) BB → SD (chat at the attendant's desk) → BB → CP → BB.
  - **`rover_hall`:** (a) BH ↔ TW (behind the counter) ↔ BC; (b) BC → LD (dock check) → BC →
    MO; (c) BC → SB → BC east (fire-exit check, pause `look`) → BC.
  - **`rover_gallery`:** (a) UC → WL → GA (pause at `G` facing S over the hall) → EL → UC; (b) UC →
    OF → GA → CF/CO → UC; (c) UC → SA up → XC → PR door → XL (terrace doors, pause `look`) → XC → SB
    down → UC.
  - **`rover_basement`:** (a) BB → RC → BB; (b) BB → SD → BB → SS; (c) BB → CP → PL → BB. **Never
    LK** (staff lockers and WCs: the reason).
  - **`rover_dock` (`lane` graph):** (a) the dock apron ↔ Ledger Lane west (refuse truck); (b) the
    apron ↔ the Tannery corner (pause `smoke` 20–40 s facing E); (c) the apron → Tannery bay (E2) →
    back.
- **Civilians:**
  - **Tellers** (3 of the 6 stations, `teller_count` clip at the 1.00 m work top) and one on a
    rotation: station → BC → BR (Gallery, coffee) or WM/WW → station (40–80 s away). In
    `door_fire_propped` a teller smokes outside the east fire exit instead (40–70 s windows).
  - **The manager** (`manager_route`): `mgr_floor` BM desk ↔ hall (greets customers) ↔ TW
    (supervises) ↔ PC lounge; `mgr_gallery` VO ↔ CF meetings ↔ OF ↔ PR (Executive); `mgr_vault`
    SB (alone) → BB → SD (the attendant's desk) ↔ CP ↔ LK (WC, 40–70 s) → SB. Timed, cross-floor stops use A's
    `CivilianRoute` (D-136 §3b.4; fallback: one-floor routes + the GN errand pattern).
  - **SD attendant** (always, 1): at the SD desk (`desk_work`), with 0-1 SD customer at a viewing booth (`sit`).
    Both spawn in SD and stay there (D-136 §3b.5).
  - **Customers** (`customers` scalar): queue rails → counter → check desks → benches → PW → VE.
    Plaza pedestrians (2, `walk_text`) loop the plaza and Tannery corner. Clients in PC (0–2,
    `cower_seated` on alarm). **Cower points** (`cower_stand`) stand 0.21 m in front of a wall or
    the counter front (characters.md v1.9, lead note), along the hall walls and under the gallery.
  - **Officers** (`officers` scalar): at the AO/OF/VO desks, with coffee runs to BR and WC (50–90 s
    away from the desk). An occupied desk with the code PC means waiting for the coffee window or
    spending a cable tie.
  - A panicked civilian runs to the nearest `phone` or `alarm_button` (S3.1). Phones: BM, LO, NA,
    PC, SR, SD desk, BR, VO, EA. Alarm buttons: under the counter at each staffed station, BM desk,
    SR console, SD desk. Leaving through VE, AV or any exterior door counts as leaving the map
    (alarm).

### Staff, civilian and guard roster (spawn data; ENV D cast ids, `p5_cast.json`)

| NPC | D role → cast ids | Count | Presence | Spawn tags | Idle activity | PatrolPoint tags |
|---|---|---|---|---|---|---|
| Security Officer (lobby) | `bank_guard` → `security_officer` | 1 | always | `guard_lobby` | — | `guard`, `guard_ground` |
| Security Officer (vault) | `bank_guard` → `security_officer_b` | 1 | always | `guard_vault` | — | `guard`, `guard_basement` |
| Security Officer (rovers) | `bank_guard` → `security_officer`, `security_officer_b` | 1–4 | `guard_post` = `rover_hall`, `rover_gallery`, `rover_basement`, `rover_dock` | `guard_rover_<post>` | — (`smoke` for dock) | `guard`, per floor |
| Camera operator | `bank_guard` → `npc_bank_guard` (the bare-headed night guard, on the day shift here) | 0–1 | `security_room_staffed` | CAMERA_OPERATOR in SR | `desk_work` | — |
| Teller | `bank_teller` → `npc_bank_teller`, `npc_bank_teller_b` | 3 (+1 rotating) | always | `civ_teller` | `teller_count` | `staff`, `staff_teller` |
| Day manager (Lionel Ashgrove), keycard carrier | `bank_manager` → `bank_manager` | 1 | always; route by `manager_route` | `civ_manager_<route>` | `phone` / `desk_work` | `staff`, `staff_manager_<route>` |
| Customer | `bank_customer` → `bank_customer`, `bank_customer_b` (parent with a backpack), `civilian_customer_a`, `civilian_customer_b` (elderly) | 4–8 hall + 2 plaza | `customers` scalar | `civ_customer`, `civ_plaza` | `browse`, `walk_text` | `civilian` |
| SD attendant | `bank_officer` → `bank_officer_b` | 1 | always (D-136 §3b.5: spawns in SD) | `civ_sd_attendant` | `desk_work` | — (stays in SD) |
| SD customer | `bank_customer` → `bank_customer`, `civilian_customer_b` | 0–1 | part of `customers`: 1 at 6 and 8 | `civ_sd_customer` | `sit` (viewing booth) | — (stays in SD) |
| Private client | `bank_customer` | 0–2 | `pc_clients` (part of `customers`: 1 at 6, 2 at 8) | `civ_client` | `sit` | — (stays in PC) |
| Account officer | **new role `bank_officer`** (QC-67; the lead asks ENV D for it, D-075; until then `npc_bank_teller_b`) | 1–3 | `officers` scalar | `civ_officer` | `desk_work` | `staff`, `staff_gallery` |
| VIP client + bodyguard | `bank_customer` + `bank_guard` (`security_officer_b`) | 0 / 1 + 1 | rare `vip_client` | `civ_vip`, `guard_vip` | `sit` | — (SD) |
| Vaultline crew | `armored_car_crew` → `armored_car_crew`, `armored_car_crew_b` (Rolling Thunder cast, pagers) | 0 / 2 | rare `armored_car_early` | `guard_vaultline` | — | `guard_dock` |
| Police | director | — | loud | POLICE spawns `police_s`, `police_se`, `police_n`, `police_e`, `police_roof` | — | — |

**Security faction: Halden Security, confirmed.** It is ENV D's casting (p5_cast.json notes), and
it is the city's contract guard firm in Glasshouse and Night Deposit. A clearing bank contracting
the same firm as its correspondent branch is plausible. It also keeps the bank_guard badge set
shared, so ENV D needs no new uniform. Vaultline Armored Transport appears only in the rare event.

**Totals per difficulty** (guards from the fixed lobby + vault posts and the `guard_post` picks):

| Difficulty | Guards (fixed + rovers) | Operator | Pagers to clear everyone | Civilians (tellers + manager + customers + officers) | Notes |
|---|---|---|---|---|---|
| Routine | 2 + 1 = **3** | 60% | 3–4 | 4 + 1 + 1 + 6 + 1 = **13** (customers 4–8 → 11–15) | Everything can be killed and answered. |
| Tense | 2 + 1 = **3** | 60% | 3–4 | 12–17 | |
| Hazardous | 2 + 2 = **4** | 60% | 4–5 | 12–18 | Exceeds the cap with the operator. |
| Brutal | 2 + 3 = **5** | 75% | 5–6 | 13–19 | 1–2 guards must be ghosted. |
| Lethal / Cataclysm | 2 + 4 = **6** | 75% | 6–7 | 13–19 | 2–3 ghosted; Titan cameras. |

The civilian column counts tellers + manager + **SD attendant** (D-136 §3b.5) + customers (with the PC clients and the
SD customer) + officers; the 2 plaza pedestrians come on top. **D-130 / D-137 (B's OF-B1 generator block):** expected
guards per tier 3 / 3.4 / 4.2 / 5.2 / 6.3 / 6.6 and civilians 14.4 → 19.4 (Routine → Cataclysm), from real spawn
points; no `pager_max_by_difficulty` or Titan override for OF (Titan from LETHAL, the tweak default). The rows above
are the design-doc baseline picks; B's block is the data.

Cable ties: 2 per player (+2 with `asset.extra_cable_ties`). With 11–18 civilians, **tying the hall
is not a plan**. The hall is cased unmasked and worked around, never subdued. Civilians ≤ 18 + 2 rare
(cap 30, architecture §10).

## Sightlines
- **Lobby guard** (`post_lobby`, BH at (24, 30), standing facing N): sees the whole hall, the counter
  front, the teller gate, the gallery and the WL/EL glazing. The PC door (40, 18) and the LO door
  (8, 18) are 53° off his axis, inside his 120° FOV, but unmasked crew walking into PC raise only
  the slow trespass fill (S1.1). Masked, those doors are used while he is on loop (a)'s window leg
  (facing S) or on loop (c).
- **Behind the counter:** the bandit glass is see-through. A crouched player behind the counter is
  hidden from the hall by the **1.50 m solid bandit-screen base** (not by the 1.05 m ledge: D-128's crouched
  detection point at 1.05 m clears a 1.05 m front from every standing observer; see Ground notes), for observers
  ≥ 2 m from the player (closer, PD2 uncovers a crouched player anyway). Tellers face the hall, so a masked player
  in TW behind them is unseen until a teller turns (rotation) or the hall guard walks loop (b). **Verified by LOS
  sample, not by eye (D-136 §3b.11):** levelcheck `teller_worktop` (solid front height) and `hide_los` (the
  detection points from the BH floor grid); adjust the base if they fail.
- **The gallery and loggias:** a masked player on GA/WL/EL is visible from the hall floor (the
  guard, customers). The gallery guard is 1.1 m high with a **solid bronze base to 1.0 m** and a
  0.1 m glass cap, so a crouched player (1.2 m capsule, eyes below the base top seen from 5 m
  below) crossing GA is hidden from the hall floor (**D-075: the solid base is approved**). **D-128 check:**
  the crouched detection points are +6.0 and +6.05 (1.0 / 1.05 m over the GA floor) against the base top at +6.0.
  From a hall-floor eye (+1.62) the ray rises 4.43 m over the horizontal distance D, so at the base plane (≥ 0.40 m
  in front of the crew: capsule r 0.35 + half the base) it is ≥ 4.43 × 0.40 / D below the point; the 1.05 m point
  is hidden while that is ≥ 0.05 m, i.e. D ≤ 35 m, beyond the crouched max_range (12 m guards, 15 m civilians).
  Observers under the gallery are blocked by the GA slab. **The claim holds;** levelcheck `hide_los` samples it
  on the real geometry (D-136 §3b.11). The loggias are glazed full height: crossing them is timing, not crouching.
- **BC** (38 m straight): a guard in it sees end to end. Cover comes from 10 door recesses and the
  SA/SB landings. `rover_hall` loop (c) walks its full length.
- **SR:** the operator faces N at the monitors. The door, the key cabinet (E wall, south end) and
  the SR coffee counter are ≥ 120° behind him: he can be **approached from behind**.
- **Basement:** BB is 48 m straight. The vault guard at `G` in VC faces W through the gate grille
  along BB's west half. The grid glows red across the concourse. RC's compact shelving gives
  1.0 m aisles that are blind from BB.
- **Ledger Lane:** straight, 82 m. The dock apron is in `rover_dock`'s view on loops (a)/(c) and in
  C6's cone. The dumpsters and the fire-escape foot are behind the C6 pole (blind).
- **Terrace:** the north facade of XL/LG/CT is glazed. The lantern blocks LOS across the terrace
  middle. S1 (Assay Office) sees the south half of the terrace in loud.

**Cameras** (`security_camera`, 60° cone, 20 m; mounts 2.8–3.2 m):

| Cam | Mount (x, z, y) | Looks at | Notes |
|---|---|---|---|
| C1 | BH NE corner (39.6, 17.4, 3.2) | SW: the hall, the VE inner doors, the PW/NA doors | The PC door (40, 18) is beside the mount: blind. |
| C2 | BH SW corner (8.4, 35.6, 3.2) | NE: the counter front, the teller gate, LO/CN doors | The AV hall door (8, 32) is beside it: blind. |
| C3 | TW W end (8.4, 9.4, 3.0) | E along the teller line: stations, **the lid**, the BC door at x 14 | The LO→TW door (8, 12) is below it: blind. |
| C4 | BC E end (47.6, 8.0, 2.8) | W along BC to x ≈ 28: MO, J1, WC doors, the PC service door | **The fire exit (48, 8) and the SB door (46, 7) are beside/behind it: blind.** The SR door (19, 7) is out of range. |
| C5 | LD NE (9.6, 0.4, 3.2) | SW over the dock floor | The lift door (10, 1.5) and the N wall doors are beside it: **the lift → personnel door line is blind**. |
| C6 | Ledger Lane pole (20, −6, 4.0) | W along the lane: the dock doors, the E1 van, the fire-escape foot | The dumpsters at x 26–30 are behind it: blind. |
| C7 | AV NE (7.6, 29.4, 2.8) | SW: ATMs, the street door | PUBLIC zone: unmasked crew are ignored. |
| C8 | UC W end (0.4, 8.0, 2.8) | E along UC to x ≈ 20: BR, E2, SA, IT doors | |
| C9 | GA E end (39.6, 18.5, 3.0) | W along the gallery: OF/CF doors, the WL junction | |
| C10 | VO NE (47.6, 9.4, 2.8) | SW over the VO desk | `pc_vault_ops`, `kc_vault_ops`. |
| C11 | XC E end (47.6, 8.0, 2.8) | W along XC to x ≈ 28: PR, PN, XW doors | EA (19, 7) and the SA door (14, 7) are out of range. |
| C12 | terrace, on the north facade (24, 17.2, +3.0 above 8.6) | S over the terrace and the lantern | The XL doors (x 5–11) are 89° off: blind. The heli net is **outside the cone**: as built it sits at x 40.5–44.5, z 23.5–28.5 (G1, f49df211: moved east of the drawn 33–39 so the E3 bag line, hugging the facade then down the east side, reaches it camera-free; validator `bag_line`). The heli's ESCAPE area stays at x 32.5–38.5, z 24–30. |
| C13 | BB E end (47.6, 8.0, 2.8) | W along BB to x ≈ 28: SD, SS, CM, PL doors | **The vault gate, CQ, SA and LK (x 0–18) are out of range.** |
| C14 | SD NW (34.4, 9.4, 2.8) | SE over the box rows | |
| C15 | CP NW (16.4, 0.4, 2.8) | SE over the counting tables | |
| C16 | PC NE (47.6, 9.4, 2.8) | SW over the lounge | The BC service door (44, 9) is beside it: blind. |

There is **no camera in VC or VT.** The vault is guarded by the gate, the grid, the vault post and
the time lock, and that is a deliberate choice: the bag line from the vault to SA/CQ must be
camera-free in every layout (see below). Cameras see open vaults (S4.4), but the vault door is
seen only from VC.

**Camera layouts** (8 each; `camera` slot group). Each layout leaves a **camera-free bag line from
the vault to SA and CQ** (no BB/VC camera within range), **to E2** (SB → BC east, blind to C4) and
**to E3** (SA → XC west end → XL → the facade-hugging terrace path).

| Layout | Cameras | Front route (PC → BC) | Dock route (lane → LD → BC) | E1 bag line (LD → van) |
|---|---|---|---|---|
| `cam_a` | C1, C3, C6, C8, C11, C12, C13, C14 | free (C4, C16 off) | **C6: ECM or timing** at the dock door | **C6 sees the van: one ECM window** to throw the staged bags |
| `cam_b` | C2, C4, C5, C9, C10, C12, C15, C16 | C16 (door blind) → BC under C4: **ECM, or go E (blind)** to SB | C5 (LD floor) + C4 | free (the lift → door line is blind to C5) |
| `cam_c` | C1, C2, C3, C7, C9, C11, C13, C15 | free | free | free |

## Stealth routes
Four approaches. Two need no tools, and every one needs reading a guard loop.

1. **Front ("walk in like you belong").** Spawn on the plaza (default) and case the hall unmasked:
   the counter, the manager's rounds, the gallery, the lobby guard's loop, the cameras. Enter PC
   (unlocked, RESTRICTED: slow detection only) and take its **BC service door** (unlocked during
   hours). **Mask in J1 or on the SB landing** (no observers, no camera). This is the fastest way to
   BM (manager's desk), SR (operator) and SA. Risk: trespass detection in PC/BC from staff and C16
   (`cam_b`), and `rover_hall` loop (c).
2. **Dock (Ledger Lane).** Spawn in the lane (`pp_spawn_lane`) or walk round. Read `rover_dock`
   (his `smoke` pause at the Tannery corner faces E). Mask behind the dumpsters (behind C6), then
   lockpick the dock personnel door (8 s, in C6's cone in `cam_a`; free with `door_dock_open`) → LD
   → BC or the cash lift. This is the shortest way to the basement and the E1 bag line.
3. **Tannery fire exit** (`door_fire_propped`, or a teammate opens the push bar from inside).
   From Tannery Street (`pp_spawn_tannery`) into the BC east end: blind to C4, next to SB. This is
   the camera-free way to the basement in every layout, and the E2 bag line. The propping teller
   smokes outside: wait for her window or tie her (she is alone).
4. **Roof** (`fire_escape = fe_down`, masked). Climb Corvino's rear fire escape from the lane to the
   bank's main roof (+12.2) → lockpick the HH door (8 s) → SA down. It lands on the Executive level
   (`pc_exec`, the president's safe) and the Gallery (SV, the officers' PCs) without crossing the
   ground floor. It is an entry only: no bags on ladders (S10.1b).

**Inside, the required line is:** the vault keycard (on the manager, or one of 3 places) + the vault
code (the right PC, 45 s) **or** the server hack (90 s) + the vault gate + the grid + the time lock
(150–270 s) + 6 bags out.

**Taking the keycard from the manager** (`kc_on_manager`, QC-62): he is a civilian. Shout him down
(he raises his hands), **tie him** (1 cable tie) and take the card (1 s, `carried_item_s`; QC-62 = QC-52
`carrier_tag`, D-136 §3b.2), or kill him (a civilian
kill penalty; his body is a corpse stimulus). His routes put him alone at predictable points: the BM
office with the door shut (`mgr_floor`, but the glass front faces the hall), CF/PR (`mgr_gallery`),
the LK WC (`mgr_vault`). Reading `[code_hint]` on his desk planner names the officer whose PC holds
the vault code (reveals `code_pc`).

**Time-lock hold:** after the code is entered (or the server hack finishes), the vault opens after
`time_lock_s`. Guards walk VC on `post_vault` loop (a) and ignore the running console and the open
gate (S4.2). Players must not be in VC when he comes. RC and LK are the waiting rooms. This is the
**heist's long tension beat**, and it is longer than any loop, so it is never "just wait at the
door".

**Lasers** (VC, across the concourse at x 21): `lz_static` has a discoverable **bypass gap** at the
south wall, **≥ 1.0 m clear width** (D-104 §7.1; was 0.8 m), passable crouched (QC-24, validator-asserted); a grid
built as crouch-under has its lowest beam's lower face ≥ 1.215 m; `lz_sweep` is a timing window (OF-C1 for OF-P1:
**2 vertical beams half a cycle apart, a 7 s sweep** across the 3.3 m width and back; they cross the centre together
every 3.5 s, so the centre lane is clear **2.6 s** per pass; the 3-beam 8 s sweep left 0.33 s there); `lz_timed` drops
for 6 s every 20 s. Every window is long enough to cross 4 m with a MEDIUM bag (×0.75: 4 m / 2.63 m/s = 1.5 s;
`lz_sweep`'s centre is ≥ 2.0 s, `lz_timed`'s 6 s is 4×). The **laser controller** (with the vault-control
rack, in SV or CM) switches the grid off: `hack_terminal` 20 s, `[lasers]`. ECM does not affect
lasers (S9.10).

**Pager budget:** as the totals table. Routine–Tense can clear the guards with pagers. From
Hazardous up, at least one guard must be avoided. The operator is the most valuable pager (all
cameras off) and sits off BC, a corridor every route crosses.

**The hardest roll and its ghost line** (the level_standards §4 MUST: no kills). **D-150 (2026-10-21):** this line was
written for 6 guards, before D-140's `guard_extra` put 8 on Cataclysm (the two extras walk BB east). There, BB has no
window with both `rover_basement` and the vault guard away (P r257d). So the no-kill ghost acceptance runs on
**Hazardous** (6 guards), and Cataclysm's stealth acceptance is a stealth win with pager kills (D-140); patrols are not
lengthened for a Cataclysm ghost. If Hazardous also lacks the BB window, `rover_basement`'s away leg is lengthened at
Hazardous only (D-150.3). The roll as first written:
Cataclysm, `cam_a` (Titan), operator in, 6 guards (lobby, vault, rovers hall, gallery, basement,
dock), `kc_on_manager` + `mgr_vault`, `code_pc = pc_exec`, `srv_gallery`, `lz_sweep`, `door_none`,
`fe_up`, `customers` 8, `officers` 3, `time_lock_s` 270, `esc_van_dock`, rare `vip_client`. Solo,
one ECM (2 charges), 2 cable ties, **no kills, no pagers**:
1. Plaza spawn. Walk unmasked down Tannery Street into Ledger Lane (PUBLIC). Read `rover_dock`.
2. When he starts his `smoke` pause at the Tannery corner (facing E, 22 m away), mask behind the
   dumpsters (behind C6). **Second cue (D-150 Hazardous ghost, P's ghost_haz data):** `rover_hall` walks his three
   loops in turn from BCMid (guard_tweak `hub_loops`: (a) TW/hall, (b) LD dock check → MO, (c) stair B → fire exit),
   so his (b) dock check lands in most smoke windows. Go only once he has **left LD for MO** on (b): his MO leg and the
   whole of (c) keep him at BC's east end, away from the LD → BC west → SA route. Read the phase by **where he is**
   (east of x 38 on the BC line), not by the time since his last LD visit: he spawns into (b) (LD at t≈11) and passes
   within 8 m of DockCorridorDoor at the hub between loops, so wait outside beside the dock door until he is east. If
   he is heading for LD, or in it, let that window go. (P haz_n, seed 1002: the t=162 window, step 2 done at t=208; no
   patrol change needed.) **ECM #1:** lockpick the dock personnel door (8 s) → LD (no C5 in `cam_a`)
   → BC west end (C4 is off in `cam_a`) → SA down. About 16 s.
3. Basement, BB west (C13 at the east end does not reach x < 28). Wait in LK. When the manager
   (alone on SB, D-136 §3b.5) takes his WC break, shout him down and **tie him** (tie 1), take the keycard (1 s)
   and leave him in a cubicle. No guard loop enters LK.
4. SA up to the Executive level. C11 does not reach EA (x 19). Start the `pc_exec` hack (45 s, 1
   interruption), and wait in E3 while `rover_gallery` passes on loop (c). Re-interact, read the
   code.
5. SA down. When the vault guard is on loop (b)/(c) and `rover_basement` is east, swipe the
   keycard at the gate (`K`), cross the sweep in its gap, enter the code at TL (5 s). Back out and
   wait **270 s in RC** (the shelving aisles are blind from BB; `rover_basement` loop (a) walks the
   centre aisle, so stand in an end aisle).
6. The vault opens. Carry **6 cash bags** (MEDIUM: ×0.75, **no sprint**, D-102), one at a time, each in a window
   when the vault guard is off VC (loops (b)/(c)): VT → VC (the sweep; never leave a bag in VC) → the gate → BB →
   **CQ**, staged in CQ with its door shut (a bag is a guard stimulus within 18 m LOS, S4.1). About 23 s a trip
   (timing below). No camera covers the line.
7. When `rover_hall` is on loop (a) or (c) (not (b), the LD dock check), run the **cash lift** 3 times (2 bags a
   cycle) and stage the bags by the personnel door; then **ECM #2:** throw the 6 bags from the personnel door into
   the E1 van's zone (4 m MEDIUM throw, about 15 s of the 20 s jam). Walk out. The escape opens on 6 secured.
Total: 2 ECM charges, 1 cable tie, 0 kills, 0 pagers. The other layouts drop C6 (`cam_b/c`), so
this is the worst case. The officers, tellers and 8 customers are never crossed: the dock line
avoids the ground floor.

#### Ghost line timing (re-derived, D-136 §3b.8: D-102 speeds, D-128 detection)
Inputs (data, not estimates): walk 3.5 m/s, crouch 2.25 m/s, sprint 5.75 m/s (CrewTweak); MEDIUM ×0.75 = **2.63 m/s,
no sprint**; throw 4 m; ECM jam 20 s per charge (S8.4); `bag_lift` 8 s a trip, send/call hold 1 s, 2 bags; lockpick
8 s; carried card 1 s. D-128 (pd2_fidelity S2.2): a guard fills on a standing masked player in 1.00 s at 10 m (centre)
and never beyond the 20 m standing / 12 m crouched max_range; within 2 m (crouched) or the 5.5 m civilian uncover he is
instant. Distances are path lengths on the floor plans (1 char = 1 m; wall centre lines).

| Step | Path (plan coordinates) | Length | Time |
|---|---|---|---|
| 2 | personnel door lockpick (8 s), then (8, 0) → LD → BC door (10, 8) → SA door (14, 7), walking | 13 m | 8 + 3.7 = **11.7 s** of ECM #1's 20 s (C6 sees the door; the rest is C5/C4-free in `cam_a`) ✓ |
| 6 | cage gate (25, 15.5) → vault door (30, 13) | 6 m | |
| 6 | vault door → along the VC south side (z 12.4) → laser plane x 21 → gate (17, 9) | 14.5 m | |
| 6 | gate → BB (17, 8) → (12, 8) → CQ door (12, 7) → by the lift (11.5, 4.5) | 9.5 m | |
| 6 | **one trip:** 30 m loaded at 2.63 m/s + 30 m back walking at 3.5 m/s + 2 sweep crossings (mean wait ≈ 1 s each at the 2-beam 7 s sweep, worst 2.4 s) + pick/drop ≈ 1 s | 60 m | 11.4 + 8.6 + 2 + 1 = **23 s** (19.6 s sprinting back; 26 s with worst sweep waits) |
| 6 | 6 trips | | **≈ 140 s** to CQ (the old 6 × 25 s = 150 s also covered the lift to LD, assuming sprinting with cash: the loaded carry is now 5.75 / 2.63 = 2.2× slower) |
| 6 | exposure per trip inside the vault guard's VC view (VT exit 6 m + VC 14.5 m loaded, back unloaded) | 20.5 m ×2 | 7.8 + 5.9 = **13.7 s** — at 10 m he fills in 1 s, so every trip needs him off VC (loops (b)/(c)); a loop (a) return means waiting in VT off the door axis |
| 7 | one lift cycle: load 2 (2 × 2 s) + send (1 s) + walk CQ → BB → SA up (11 m flights + landings) → BC → LD (30 m, 8.6 s; the car takes 8 s) + unload 2 by the door (4 s) + call (1 s) + walk back (8.6 s) | | **≈ 27 s**; 3 cycles, the last without the walk back: **≈ 72 s** |
| 7 | throw 6 bags from the personnel door into the E1 zone | 6 × 2.5 s | **≈ 15 s** of ECM #2's 20 s ✓ |
| | **bag phase total** (vault open → 6 secured) | | **≈ 230 s** (old doc ≈ 165 s) |

**Where it no longer fits as written (flags for OF-C1 / OF-A6 / OF-P1):**
1. **Staged bags in LD (old step 7):** the six bags would lie in LD for the whole lift phase (≈ 60–75 s), and LD is on
   `rover_hall` loop (b) (the dock check); a bag is a stimulus within 18 m (S4.1). Fixed above: stage in CQ behind a
   shut door and run the 3 lift cycles + the throw (≈ 90 s) in one `rover_hall` (a)/(c) window. If his loops are
   shorter than ≈ 90 s away from LD, the line needs his loop read twice (stage 2 + 2 + 2 by the door, throwing each
   pair costs an ECM window in `cam_a`, and there is only one charge left): **P to time `rover_hall` in OF-P1**.
2. **The E1 throw distance:** from the personnel-door threshold (8, 0) to the van at the roller door (5, −3) is
   4.2 m, more than the 4 m MEDIUM throw. **The E1 SECURE_LOOT zone's near edge must be ≤ 3.5 m from the threshold**
   (OF-C1 places the van so; levelcheck `bag_line` covers cameras, not throw reach: P verifies the throw). HEAVY gold
   (2 m) cannot be thrown to E1 from inside: it is walked out into C6's cone (ECM or `cam_b/c`).
3. **The vault phase is window-bound, not loop-bound:** 6 × 23 s = 140 s with ≈ 14 s of each trip in the vault
   guard's view means ≈ 6 separate (b)/(c) windows; the solo waits in VT off the door axis between them. Still a
   ghost (no kills, no pagers) but ≈ 3–5 min longer than the old estimate; inside Size L's 25–40 min.
4. Step 5's 270 s RC wait relies on "the end aisle is blind from BB and the centre aisle": marked as a `hide_spot`
   for levelcheck `hide_los` (OF-C3), not trusted by eye.

## Loud
**Phase outline.** Alarm → LOCKDOWN (the vault reseals, a running time lock aborts, QC-64) → CONTROL
(first responders) → ANTICIPATION (+30 s once with a hostage; there will be many) → BUILD → SUSTAIN
→ FADE … (L1.1). Expected in a normal run: wave 1 while the drill bags are fetched, wave 2 during the
360 s drill, wave 3 while bags come up the hoist, wave 4 (L size) during the escape wait.
Escalation (L1.3) makes wave 3 the 100% stage.

**The thermal drill.** `drill_delivery` decides where the 2 bags (`loot.thermal_drill_part`,
HEAVY, tool) arrive, `drill_eta_s` after the alarm (45/60/90 s; Mercer: "Bird's inbound with the
rig."):
- `drop_terrace`: a helicopter drops a crate on the terrace at (20, 33). It is 2 storeys and the
  whole north block away from the lid (SA down: about 60 m), but the terrace is H4.
- `drop_dock`: Mercer's second van backs into Ledger Lane at the dock. About 30 m to the lid through
  LD and BC, in P3's lane.

Assemble: place both bags on the lid (3 s each, `drill_point` THERMAL, `requires_loot` ×2, QC-60)
→ 360 s, jams (S9.3). When it finishes (`device_finished`), the mission plays the burn-through
(the lid drops into the vault; dust) and **enables the rope ladder and the hoist** (`bag_lift`
"hoist", 2 bags, 6 s, vault floor ↔ TW) through the 1.2 m hole (QC-61). If the alarm came after the
vault was already open, the drill is skipped and the vault door stays open.

### Holdouts (5 designed; each has ≥ 2 approaches through open or unlocked openings, D-070)

| Holdout | Where | Approaches (chokepoints) | Flanks | Sniper exposure | Strength | Weakness | It matters when |
|---|---|---|---|---|---|---|---|
| **H1 Teller line** | TW (+ the lid), centroid (24, 13) | (1) the hall over the counter and through the **teller gate** (from VE, AV and the hall windows); (2) the **BC staff doors** at x 14 and x 34 (from the dock, the fire exit, SA/SB); (3) the LO and PC side doors | Lantern rappellers land in the hall in front of the counter. Phantoms come up from PL via SA/BC. The gallery overlooks the counter from +5.0 (police on GA shoot down). | S1 through the arched windows onto the hall floor only (the counter blocks the line into TW). | The 1.05 m counter with bandit glass is 32 m of hard cover facing the hall. One room holds the drill, the hole and the hoist. | Three sides. GA above the counter is the high ground police take. | Always in a drill run: the drill (360 s) and every hoisted bag. |
| **H2 Basement concourse** | BB west + VC, centroid (24, 10, −4) | (1) **SA** (from the ground and the roof); (2) **SB** + BB from the east; (3) CQ / the cash lift (bags) | The PL areaway grate (Phantom vent) opens into BB behind SB. | None (below ground). | A 2 m corridor and a 4 m concourse: short sightlines, two stair mouths 30 m apart. | Two stairs at opposite ends: a pincer. | An alarm after the time lock finished: the vault door is open and bags go to the cash lift or SA. |
| **H3 Loading dock** | LD, centroid (5, 4.5) | (1) the roller and personnel doors from Ledger Lane (P3, P4 via the lane); (2) the BC door (from the ground floor); (3) the cash lift (bags from the basement) | Lane police and the Wrecker at the roller door; ground-floor police through BC. | S2 (47 m) into the lane and onto E1 when the roller door is up. | A 10 × 9 m room with the lift inside it; the van is 4 m away. | The roller door is a 3.6 m breach face. | `esc_van_dock`, `drop_dock`. |
| **H4 Terrace** | the terrace + XL, centroid (36, 27, +8.6) | (1) the XL doors from XC (SA/SB); (2) the caged ladder from the main roof (P5 rappellers) | The lantern splits the terrace. P5 drops onto the main roof and comes down the ladder. | S1 (41 m to the net), S3 (`tower_sniper`, 42 m). | Height: no ground approach. The parapets are hard cover. | Two snipers on the worst roll; the 2-storey bag carry from the lid. | `esc_heli_terrace`, `drop_terrace`. |
| **H5 Fire exit** | BC east + the SB landing, centroid (46, 8) | (1) BC from the west (dock, hall via PC); (2) the **Tannery fire exit** (P2, P4); (3) SB from the basement and the upper floors | Police from Tannery Street and from inside at once. | S2 (44 m) onto the E2 bay. | A short line to E2 (the van is outside the door). | A 2 m corridor with doors on 3 sides. | `esc_van_tannery`. |

Not designated, but useful: **GA** (the gallery is the hall's high ground, a counter-sniping spot for
the lantern rappellers, and a throw spot onto the hall floor), and the **main roof** (a counter-
sniper spot for S2/S3).

### Police spawns (≥ 3 directions required; 5 designed) and the spawn rule
Spawns are `SpawnPoint` POLICE. The director spawns only at POLICE spawns that have no LOS from any
crew member and are ≥ 15 m (flat) from each of them (`min_crew_distance_m` = 15, L1.4). **Police
never spawn inside the building (QC-42, D-064): every ENTRY point on the shell carries the tag
`breach_only`** and is a breach/arrival target, never a spawn candidate (ENV A honours the tag,
878d35f). Flat distances from each spawn to each holdout centroid are all ≥ 25 m:

| Spawn (tag) | Position (x, z, y) | Occluder | → H1 | → H2 | → H3 | → H4 | → H5 |
|---|---|---|---|---|---|---|---|
| **P1** `police_s` (Halloran Ave west) | (−30, 55, 0) | the road-works truck + Corvino's corner | 68 | 66 | 61 | 72 | 92 |
| **P2** `police_se` (Halloran Ave east) | (80, 55, 0) | the stalled truck and bus + the Belmont corner | 70 | 68 | 90 | 52 | 58 |
| **P3** `police_n` (Ledger Lane west) | (−30, −5, 0) | the refuse truck + Corvino's rear wall | 57 | 58 | 36 | 73 | 76 |
| **P4** `police_e` (Tannery St north, garage ramp) | (55, −45, 0) | the ramp wall and the exit barrier booth | 66 | 69 | 70 | 74 | 54 |
| **P5** `police_roof` (Corvino setback, +16.0) | (−14, 20, 16) | Corvino's setback parapet (no crew access) | 39 | 38 | 25 | 50 | 61 |

- P5 units reach our roofs only by **one-way rappel links**: setback → the main roof at `rp` (2,
  14), and setback → the terrace's west end (2, 20). From the terrace they rappel through the
  **lantern** into the hall (8.6 m). This extends QC-41 (QC-68).
- The drill-drop and escape helicopters are dressing (not police).

### Police entry points (`TacticalPoint`; every shell ENTRY tagged `breach_only`)

| Kind | Where | breachable | Serves |
|---|---|---|---|
| ENTRY | the bronze doors (VE, S) and the AV street door | yes (open by day; doors) | S |
| ENTRY | the hall's 4 arched window bays (S facade) | yes (glass) | S |
| ENTRY | the dock roller door and the personnel door (N) | yes | N |
| ENTRY | the BC east fire exit (Tannery) | yes | E |
| ENTRY | the HH roof door (+12.2) and the XL terrace doors (+8.6) | yes | Roof |
| RAPPEL + ENTRY | the lantern skylight over the hall (24, 26), glass, breakable, drop 8.6 m | yes | Roof |
| RAPPEL | Corvino setback → main roof (2, 14) and → terrace (2, 20) (one-way) | — | Roof |
| FLANK | the Ledger Lane areaway grate (30, −1) → PL floor (30, 3, −4), nav layer `vent` (Phantom only) | — | N |
| FLANK | the plaza colonnade → AV → the hall west; Tannery bay → the fire exit | — | S, E |
| SHIELD_ANCHOR | the plaza steps (24, 40); the hall at the meridian line (24, 24); the lane at the dock (5, −4); the Tannery bay (54, 8); the terrace west end (4, 24) | — | Bulwark/Aegis formations |
| COVER | ~70 points: plaza planters, benches, the kiosk, cars, hall check desks, benches, the queue rails (soft), the counter front, pillars under the gallery, TW desks, BC door recesses, LD carts, terrace planters, the lantern curb | — | all |

**Loud-breachable shell doors (D-122, D-136 §3b.7).** Each locked shell door police may come through is a `door` whose
breach NavLink is on `Door.NAV_LAYER_BREACH` (layer 2, police and specials only; crew, bots, civilians and the pilot
query layer 1 and treat it as blocked while it is shut and locked). Each carries its shell ENTRY `TacticalPoint`
(`breach_only`).

| Door | Where (x, z, y) | Lock in stealth | Breach layer |
|---|---|---|---|
| Dock roller door (`industrial_door`, 3.6 m) | (3–6.6, 0, 0) | closed (opens for Vaultline) | yes |
| Dock personnel door | (8, 0, 0) | LOCKPICK (NONE with `door_dock_open`) | yes |
| BC east fire exit (`push_bar`) | (48, 8, 0) | push bar, opens from inside (propped with `door_fire_propped`) | yes |
| HH roof door | (14, 7, 12.2) | LOCKPICK from the roof, push bar inside | yes |
| XL terrace doors (2 pairs, glass) | (5–7 and 10–12, 17, 8.6) | LOCKPICK from the terrace | yes |
| Bronze outer doors (VE S) and the VE inner doors | (22–26, 36, 0) and (22–26, 32, 0) | open in business hours; **the mission shuts and locks them at the lockdown** | yes, from the lockdown |
| AV street door and AV hall door | (4, 36, 0), (8, 32, 0) | open (24 h vestibule); never locked | — (open doorways) |
| **Vault gate** (`GGG`, KEYCARD, BARRED at the lockdown) | (16–18, 9, −4) | KEYCARD | **no** (BARRED, D-073; interior) |
| **Vault door** (`VVV`, VAULT) | (29–31, 13, −4) | VAULT + time lock | **no**: the only loud way in is the floor (the lid) |

### Assault events (D-114 §5, D-136 §3b.6; PO6-17 / X-3 pattern)
ENV C supplies the markers (contract `docs/levels/_art/po6_17/README.md`: Marker3Ds under `AssaultEvents`, group
`assault_events`, built by `world/heists/shared/assault_markers.gd` from an `of_assault.gd` table, never hand-edited);
ENV A wires the HeistDef rows (`GameRng.stream(&"assault_events")`, the X-3 pattern). World coordinates: x east,
z south, y up, the bank's NW corner at the origin (the floor plans' frame).

| Marker (Marker3D) | Position (x, y, z) | Orientation / metadata | Notes |
|---|---|---|---|
| `TurretVan_1` | (16.0, 0.0, 51.0) | yaw 90: +Z (van forward) = east | Halloran Ave eastbound lane opposite the west hall bays (van x 13.1–18.9); clear of the plaza steps (z ≤ 40) and the P1 closure (x −16) |
| `TurretVan_2` | (34.0, 0.0, 58.0) | yaw −90: +Z = west | Halloran Ave westbound lane opposite the east bays (x 31.1–36.9); clear of P2 (x 66) and the Assay Office balustrade (z 62) |
| `HeliOrbit_1` | (28.0, 30.0, 24.0) | `radius` 22.0 | over the terrace and the lantern; the orbit stays at x 6–50 (rotor 4.5 m clear of the Corvino party wall x 0), z 2–46 (clear of the parking deck z ≤ −10 and the Assay Office z ≥ 64); +30 is 18 m over the main roof |
| `HeliDrop_1` | (8.0, 8.6, 32.0) | | **terrace rappel** (+8.6), the SW corner: 5 m west of the lantern curb (x 13), 12 m from the drill crate (20, 33), 28 m from the E3 net (33–39, 24–30), clear of the planters; the terrace is on the crew navmesh, so the cops land on it from the heli's ropes (rappel count 0: no new nav link) |
| `HeliDrop_2` | (30.0, 12.2, 14.0) | | **main roof** (+12.2) south of the roof plant room; reaches the terrace by the caged ladder (46, 17) and the building by the HH door (`Breach_4`) |
| `HeliDrop_3` | (36.0, 0.0, 44.0) | | the plaza east of the steps (ground), clear of the kiosk and the benches |
| `Breach_1` | (11.75, 0.0, 35.8) | yaw 0 (−Z = north into BH); `kind` "window", `size` (1.0, 2.1), `room` "BH" | the west outer arched bay (x 10–13.5): its lower centre panel over the 1.0 m sill; cops from the plaza. Scene: a ground-floor `prop_breach_window` variant with a 1.0 m sill (the base scene's sill is 0.9 m; OF-C2 adds `prop_breach_window_s100` if needed) |
| `Breach_2` | (35.25, 0.0, 35.8) | as `Breach_1`; `room` "BH" | the east outer arched bay (x 33.5–37). The two inner bays stay plain breakable-glass ENTRYs |
| `Breach_3` | (6.0, 8.6, 16.8) | yaw 0 (−Z = north into XL); `kind` "door", `size` (1.8, 2.1), `room` "XL"; meta `door` = the XL west door pair | the XL terrace doors (x 5–7): the event blows the locked pair open (no infill scene: the door is the infill; A plays the charge FX on the leaves and sets it open). **New breach kind "door"** (open question for the lead / A) |
| `Breach_4` | (14.0, 12.2, 6.85) | yaw 0 (−Z = north into HH); `kind` "door", `size` (1.0, 2.1), `room` "HH"; meta `door` = the HH door | the HH roof door (core wall face z 7 − 0.15); pairs with `HeliDrop_2` |

The lantern stays the existing RAPPEL ENTRY (8.6 m into the hall; QC-41 / QC-68); P5's one-way links are unchanged.
No ceiling breach (the hall already has the lantern). The turret vans and drops keep clear of the escape vehicles
(E1 (5, −3), E2 (52, 8)) and the police spawn closures; OF-C1 re-checks every position against the generated geometry
(the PO6-17 README rows are the format).

### Specials and where they come from
- **Phantom** (L4.3): via the **areaway grate** into PL (basement, behind H2, next to SA), and via
  Ledger Lane. `cue.phantom_hum` carries through BB.
- **Stinger** (L4.4): pairs, preferring the **lantern rappel** (into the hall, in front of H1) and the
  lane.
- **Bulwark** (L4.5): the plaza steps and the bronze doors, the lane at the dock. A Bulwark at the
  teller gate or on the hall's meridian anchor is the "pin the counter" moment.
- **Wrecker** (L4.6): vehicle-wide routes only: the plaza (→ VE, the windows) and Ledger Lane (→ the
  roller door).
- **Corpsman** (L4.8): with any group.
- **Longshot** (L4.7): S1 (Assay Office parapet, (24, 66, +14)) and S2 (garage deck, (40, −34,
  +13)) always; S3 (Corvino window, (−6, 24, +20)) with `tower_sniper`.
- **Commander Brandt + Aegis** (L4.9, Lethal+ once): from P1/P2 across the plaza to the hall
  anchor. The plaza gives the formation room. The answer is to hold the counter.

**Sniper lanes:**

| Perch | Position | Sees | Distance to the bag route | Blind to |
|---|---|---|---|---|
| **S1** Assay Office parapet | (24, 66, +14) | the plaza, VE, the hall floor through the arched windows (32 m), the terrace's south half (38 m), the heli net (41 m) | net 41 m, VE 30 m | TW (behind the counter), the lane, Tannery bay |
| **S2** garage top deck | (40, −34, +13) | Ledger Lane, the dock doors (47 m), E1 (47 m), the E2 bay (44 m), the main roof (45 m) | E1 47, E2 44 | the plaza, the terrace (the north block hides it) |
| **S3** Corvino window (`tower_sniper`) | (−6, 24, +20) | the terrace (30 m), the net (42 m), the hall's west arched bay (23 m) | net 42 m | the lane, Tannery |

S1 and S2 are always on (two always-on perches, D-064 Q8). S3 is a VariantSlot child enabled by its
rare event. **Player perches:** the main roof (S2, S3) and GA (the lantern rappellers).

## Loot path
- **Required (D-075):** **≥ 6 bags** secured from the vault (**4 on Routine**; the mission reads the
  difficulty for the `[secure]` target): cash (`loot.cash_bricks`), gold
  (`loot.gold`) and bearer bonds (`loot.bearer_bonds`) all count. Server drives, deposit boxes,
  safes and drawers are bonus. The drill parts are tools (`LootDef.is_tool`, D-068: never count).
- **Vault → E1 (dock van):** VT → VC → the gate → BB (3 m) → CQ → **cash lift** (2 bags, 8 s) → LD
  → the van (4 m). About 30 m plus the lift. **The short one**, and the stealth default.
- **Vault → E2 (Tannery van):** VT → VC → BB east (30 m, past C13's range: the SB door is beside
  it) → SB up one storey → BC east → the fire exit → the van. About 45 m + 1 storey. **Camera-free
  in every layout.**
- **Vault → E3 (heli):** VT → BB → SA up 3 storeys (12.6 m) → XC → XL → the terrace along the
  facade → the net. About 70 m + 3 storeys. **Throw spot:** none on the stair. Bags from the
  terrace's east parapet can be **thrown down to E2** (8.6 m drop to the Tannery bay): this is the
  crossover if the heli is cut off (loud).
- **Loud (drill run):** the vault floor → **hoist** (2 bags, 6 s) → TW → BC → the active escape. The
  hoist cannot be bypassed: the rope ladder is crew-only (S10.1b).
- **Throw spots:** GA → the hall floor (5.0 m); the terrace east parapet → the Tannery bay (E2);
  the LD personnel door → the E1 van. **Bag weights (D-102):** cash and drives MEDIUM (×0.75, no sprint, 4 m
  throw), gold and the drill parts HEAVY (×0.5, no sprint, 2 m throw), bonds LIGHT (×1.0, sprint, 4 m). So a HEAVY
  throw from the terrace parapet must clear the ≥ 50° coping (§7.4, LEAD-amended: a HEAVY bag clears from ≤ 1.5 m off
  the face at all three pitches; PD2 heavy bags are short throws, and the throw spot is marked on the floor), and the E1 zone sits ≤ 3.5 m from
  the personnel-door threshold (ghost line flag 2).
- **Terrace → E2, as built (OF-C1 for OF-P1):** a throw leaves 1.3 m up and 0.7 m ahead of the thrower (LootManager), so
  over the 1.1 m guard with its outward-falling coping (Site) a **HEAVY** bag clears at −20° / 0° / +25° look pitch
  from up to 1.4 m / 1.6 m / 1.6 m off the face (the thrower's centre; ENV P's stand is 0.6 m) and lands at x 49.3–52.6
  (in the E2 zone); a MEDIUM one clears from up to 2.0 m at −20° and beyond 2.3 m at 0° / +25° and lands at
  x 52.3–55.9 (in the zone or ≤ 1.7 m beside it). Physics-checked on the built map
  (`game/tests/c/test_of_bag_throws.gd`, real LootBag bodies). From 2 m back a 2 m HEAVY throw comes down at the face
  itself, so no guard height makes that throw; stand at the parapet. The throw spot is the parapet's south end (z 17–21),
  over the E2 strip (Secure zones).
- **The hole, as built (OF-C1 for OF-P1):** G is always a throw (2–4 m, no player drop), and the 1.2 m opening is
  narrower than any throw, so the hoist rig (it appears with the hoist at the burn) puts **1.5 m guard screens** on the
  hole's W, E and S edges, flush with the edge (the N edge stays open: the ladder top, `hole_rappel`): a bag thrown
  across the hole hits the far screen (the first contact keeps 15 % of its speed) and drops into VT. In the vault the
  rig is a **shaft round the hoist car, open to the south over a 0.6 m sill** (ND's lift-hatch pattern): a bag thrown
  north at the car from the vault floor stops on the backstop and lies in the car. Load the hoist from the south.
- **Optional:** the bullion cage (padlock; gold is HEAVY: ×0.5 speed, no sprint, D-102), the bond safe,
  the vault boxes and the SD hall boxes (saw: noise 15 m, next to the vault post), the president's
  safe (Executive, drill/saw), the server drives (SV, 2 bags, MEDIUM), the teller drawers (`small_loot`
  × 6), the CP strapped cash (`small_loot` × 4).
- **Secure zones:** `SECURE_LOOT` at the active escape only: the E1 van's rear doors (lane), the E2
  van's rear doors (Tannery bay), or the heli net (terrace). Each exists from the start (PD2). As built: E2's zone is
  the bay strip **x 48.2–54.2, z 7.3–21.3** (`SecureTannery` at (51.2, 0, 14.3)), from the van's rear doors north under
  the terrace's SE corner, so the terrace throw lands in it (the van's ESCAPE stays at (51, 6.5)); E3's net
  (`SecureTerrace` at (42.5, 8.6, 26.0), x 40.5–44.5, z 23.5–28.5) is east of the heli's ESCAPE (35.5, 27), out of C12's
  view (Sightlines). The doc's (52, 8) and (36, 27) are the escape points; the zones are where the design's throw spot
  and camera-free line need them.
- **Bodies:** BODY_HIDE in the lane dumpsters (`body_container`, 2 each), LK lockers (2), J1, J2
  and PL (1 each).

## Loot table (ids, weights, counts; ENV B owns values)

| Loot id | Weight | Base value (B) | Where | Count | Status |
|---|---|---|---|---|---|
| `loot.cash_bricks` | MEDIUM | $8,000 | vault cash cage | `cash_bags` 6 / 8 / 10 | data (`cash_bricks.tres`) |
| `loot.gold` | HEAVY | $14,000 | vault bullion cage (padlock) | `gold_bags` 2 / 3 / 4 | data (`gold.tres`) |
| `loot.bearer_bonds` | LIGHT | $7,000 | vault bond safe (1); president's safe (1, `ps_bonds`); +2 with `bond_delivery` | 1–4 | data (`bearer_bonds.tres`) |
| `loot.server_drives` | MEDIUM | $7,500 | SV racks | 2 | data (`server_drives.tres`); optional |
| `deposit_box` prefab (`loot_id` `loot.small_valuables`) | — (small loot) | $1,200–2,000 each (B, D-137) | vault walls (`deposit_boxes` 6 / 9 / 12 of 20 candidates); SD hall (8 of 24) | 14–20 | value per prefab; **no `loot.small_valuables` def** (a def-less id, as ND/SL) |
| `small_loot` | — | $500 (teller drawers), $800 (CP straps) | TW × 6, CP × 4 | 10 | prefab values (B, D-137) |
| `loot.thermal_drill_part` | HEAVY, **is_tool** | $0 | drill delivery (loud) | 2 | B's OF-B1 (on `env/b-content`, QC-65); not on trunk yet |
| `loot.body_bag` | HEAVY | $0 | — | — | data (`body_bag.tres`) |

Values are ENV B's data (D-117 §3: the doc follows the data; D-120 ×4–5 bag values). A full clear of bags is
10 cash + 4 gold + 4 bonds + 2 drives = $80,000 + $56,000 + $28,000 + $15,000 = **$179,000** before the difficulty
multiplier, plus ≈ $30–45k of boxes, drawers and straps; against `base_payout` $80,000 the bags are ≈ 60 % of a full
clear, inside D-120's 39–81 % band.

## Objectives
**Stealth** (objective_tag in brackets; ENV B reads these, D-039):
1. *(optional)* Case the bank. Mercer intro and an Accountant line. `[casing]`
2. Get the vault keycard: from the manager (tie him, take it) or its fallback location. `[keycard]`
3. *(optional)* Read the manager's planner (reveals which officer holds the code). `[code_hint]`
4. Get the vault code: hack the right officer's PC (`hack_terminal` 45 s, 1 interruption; it
   reveals code group `vault`, QC-63) `[code_pc]` **or** hack the vault-control rack (90 s, 2
   interruptions; starts the time lock when it finishes) `[server]`.
5. Open the vault gate (keycard). `[vault_gate]`
6. *(optional)* Switch off the concourse lasers (laser controller, 20 s). `[lasers]`
7. Start the time lock: enter the code at TL (5 s), or finish the server hack. `[time_lock]`
8. Hold until it releases (`time_lock_s`). `[time_lock_wait]`
9. Bag the vault: the cash cage `[vault_loot]`; *(optional)* the bullion cage padlock (lockpick 8 s or
   saw) `[gold_cage]`.
10. Secure ≥ 6 bags (4 on Routine). `[secure]`
11. *(optional)* Saw the deposit boxes `[deposit_boxes]`, open the bond safe `[bond_safe]` and the
    president's safe `[president_safe]`, take the server drives `[server_drives]`.
12. Escape. `[escape]`

**Loud** (on `alarm_raised`):
1. Mercer: "Lockdown. The time lock's dead and the door's sealed. We go through the floor." The
   mission aborts a running time lock and disables TL and the server hack (QC-64). If the vault is
   open, skip to 5.
2. Get the thermal drill: collect both parts at the drop (`drill_eta_s`). `[drill_delivery]`
3. Assemble it on the lid (2 × 3 s) and hold the teller line (360 s, jams). `[vault_drill]`
4. Through the floor: the ladder and the hoist drop in. `[vault_breach]`
5. Bag the vault (`[vault_loot]`, `[gold_cage]`) and send the bags up the hoist.
6. Secure ≥ 6 bags (4 on Routine). `[secure]`
7. Hold until the escape arrives (`escape_eta_s` after `[secure]`). `[escape_wait]`
8. Escape. `[escape]`

**Mission script notes** (`ostrander_federal_mission.gd` on `HeistMission`):
- Find prefabs by objective_tag.
- **Lockdown (Night Deposit pattern, D-136 §3b.1):** the time lock is a mission timer (`start_timer(&"time_lock")`), so
  `alarm_raised` → `cancel_timer(&"time_lock")` and fail `[time_lock_wait]` if it is running, disable TL and the
  vault-control `hack_terminal` (`Interactable.enabled`, `pause(&"lockdown")`), `KeycardReader.set_disabled(true)`,
  the vault gate `relock(Lock.BARRED)`, and shut and lock the bronze/VE doors (D-122 breach layer). After that, schedule the drill delivery: a timed loot spawn of 2 ×
  `loot.thermal_drill_part` at the active `drill_delivery` marker after `drill_eta_s` (QC-60), with
  `cue.escape_arrive_heli` or `_van` and a Mercer line. With `asset.thermal_drill_drop` the bags are
  already at the point.
- **Burn-through:** `device_finished` on the lid's `drill_point` → disable the `lid` prefab (see Map hooks), enable the
  hole's ladder, the hoist (`bag_lift`) and its nav links (QC-61), complete `[vault_breach]`.
- **Code PC:** the active `code_pc` slot holds the `hack_terminal` (`reveals_code_group &"vault"`).
  The other four PCs are props (no interaction; their screens are dark).
- **Escape (one rule, D-136 §3b.10):** stealth: E1/E2 are present from the start, and the ESCAPE zone activates on
  6 secured (4 on Routine). E3: the heli is called on 6 secured and lands 45 s later. **Loud: the escape opens on
  `[secure]` + `escape_eta_s`** (the van leaves at the alarm and returns `escape_eta_s` after `[secure]`; the heli
  likewise, +30 s with `tower_sniper`). Not Night Deposit's assault-fade rule.
- **No stealth-only fail, no soft lock (D-136 §3b.9, D-103 §3b.3, D-093):** the heist fails only on custody or an
  abort. An alarm moves to the loud line; it never fails the run. The drill parts respawn at the active drop if
  destroyed or lost off-map, and the hoist stays usable (never disabled by a bag left in the car or a downed crew).
- **Assault events:** the X-3 rows on the `AssaultEvents` markers above (A wires them, OF-A6).
- **Rare events:** `armored_car_early` (QC-25 timed NPC spawn at 15:00 elapsed at the dock);
  `vip_client` (spawn at start); `bond_delivery` (+2 bond bags in the vault).
- **Mercer lines:** intro, casing tips (manager, gallery, operator), keycard taken, code hint, PC
  found / hack interrupted / code, server hack, gate, lasers off, time lock started / 60 s left /
  open, last pager, camera "!", lockdown, drill inbound / delivered / jam / burn-through, hoist,
  gold cage, required secured, sniper on the Assay Office / the garage / the tower, Brandt, van
  ETA, heli ETA, escape.

### Map hooks the mission binds to (OF-C1 G1 fix for OF-A6; ENV C, 2026-10-17)
The mission finds these by `objective_tag` / route id; the node paths are for art lanes and tests, not for the mission.
- **The lid** `Gameplay/Devices/Lid`: a bare `GameplayPrefab` (no interaction) tagged `lid`, at (24, 0, 14.6). It holds
  the 1.2 × 2.2 m plug over the hole (`Plug`, the 0.8 m slab body, floor surface) and the 2.4 m marble panel
  (`Visual/LidPanel`), so the mission's `set_enabled(false)` at the burn-through hides both and removes the collision on
  every peer (replicated "pe"). Meta `burn_lid` stays on the prefab root for the mission's G1 fallback; levelcheck kind
  `hatch` (it sits in its slab hole like GN's floor hatch). Nothing else is in `Geometry/Building/Lid` any more. Art: the
  burn's dust / scorched rim belongs outside the lid prefab (it vanishes at the burn): on the slab rim in Geometry, or a
  separate prefab that A enables at the burn.
- **Navmesh at the hole (LEAD ruling):** the hole's 1.2 × 2.2 m footprint (x 23.4–24.6, z 13.5–15.7) is a **permanent nav
  hole**, baked from the start: the plug is not navmesh source geometry, and a projected obstruction carves the footprint
  (y −0.2 to +2.0, the D-073 baked-doorway pattern). NPCs walk round the lid before the burn as after it; there is no
  runtime rebake and no toggled region. After the burn the only ways through are A's links: the rope ladder's NavLink,
  the hoist (bags) and the `hole_rappel` RAPPEL link. The nav edge stands ≈ 0.3 m (agent radius) back from the hole edge;
  the drill's UsePoint (25.6, 0, 14.6) and the RAPPEL point (24, 0, 13.3) are on it.
- **Burn prefabs:** the hoist (`hoist`) and the rope ladder (`rope_ladder`, `usable = false`) are placed with
  `enabled_at_start = false`; the G1 metas `starts_disabled` / `hidden` / `burn_height_m` stay (the mission reads them).
- **The hole layout (OF-C1 for OF-P1, §7.7):** the hoist car is **1.0 × 0.75 m** (x, z; 2 bags) against the hole's
  south edge (`Gameplay/Lifts/Hoist` at (24, −3.95, 15.325), car z 14.95–15.7; its UsePoint (25.1, −4, 15.325) east of
  the shaft); the rope ladder hangs 0.04 m inside the north edge (`RopeLadder` at (24, −4, 13.54), yaw 180), so its
  Bottom grab point (24, −4, 13.94) stands **1.01 m clear of the car** and its Top (24, 0, 13.14) is on the TW slab north
  of the hole. **The hoist rig** `Gameplay/Lifts/Hoist/Rig` (map-built static boxes under the hoist, so they appear with
  it at the burn and are absent before it; world_dynamic, layer 2: crew and bags collide, interaction / vision rays
  pass, so the car's bags stay pick-up-able over a screen): `ShaftBackstop` (z 14.92–14.97), `ShaftW` / `ShaftE`
  (x 23.36–23.41 / 24.60–24.65) to 2.4 m above the vault floor, `ShaftSill` (0.6 m, z 15.75–15.8: the open, loading
  side faces south), and the TW guard screens `HoleGuardW` / `HoleGuardE` / `HoleGuardS` (1.5 m, flush with the hole's
  W / E / S edges; the N edge open). Each rig box is a permanent nav obstruction too (the hole carve's pattern), so on the
  TW the nav edge is ≈ 0.35 m back from the W / E / S edges. Art lanes: the car visual must fit 1.0 × 0.75 m inside the
  shaft (the A placeholder is 1.24 m) and the rig's names stay. Levelcheck treats each rig box as its own prop (meta
  `lc_subprop`). **The hoist panel** (OF-C1, ENV P burn run 7df78180): the bag_lift's external `Panel`, a 0.04 × 0.12 m
  riser standing against ShaftE's east face (x 24.65–24.69, floor to 1.2 m, z 15.265–15.385; world_dynamic like the
  rig), its origin and the Interactable at 1.1 m, square in front of the `UsePoint` (25.1, −4, 15.325, facing west);
  bag_lift copies riser and panel to the TW landing (+4 m, against HoleGuardE's east face, flush with ShaftE's). Regression: `game/tests/c/test_of_hoist_panel.gd`.
- **Tags for tools and tests:** `CagedLadder` has `objective_tag = caged_ladder`; `RopeLadder` `rope_ladder`;
  `FireEscapeDropLadder` `fire_escape`. The escape zones keep the tags the mission binds (`secure` / `escape` /
  `escape_wait`; one escape slot is resolved per run, so tag + class is unique in a run); `SecureDock` / `EscapeDock`,
  `SecureTannery` / `EscapeTannery`, `SecureTerrace` / `EscapeTerrace` also carry meta `escape_label` = `E1` / `E2` /
  `E3`. (New groups would be `G` constants, ENV A's contract.)
- **The SD attendant (D-136 §3b.5, LEAD):** `Spawns/SDAttendant`, always, `desk_work`, on the Seat of lane B's
  `ChairSDAttendant` (37, −4, 9.67), facing the desk; the chair is an `npc_seat` (no collider, no nav obstruction).
  Tags `civ_sd_attendant` (this roster's tag; no ENV D look yet: it wins once D maps it) then `civ_teller` (D's teller
  looks today, and the staff doors); never `civ_officer`, which the mission binds to `officer_coffee` when unrouted.
  The 0–1 SD customer is B's `civ_extra` slot `cx_sd` (LateCustomerSD at a viewing booth). Population (D-130 test):
  civilians 15.4 / 16.4 / 17.4 / 18.4 / 19.4 / 20.7, max 22 on every tier (Cataclysm customers 7.5, civ_extra exactly 3).
- **Drill:** `LidDrill` (`vault_drill`) has `requires_loot = loot.thermal_drill_part`, `requires_count = 2` as properties
  (the matching metas stay). **Code PCs:** every `CodePC` (`code_pc`) has `reveals_code_group = vault`.
- **The time-lock console and the vault-control rack have no `targets`:** only the mission opens the vault door
  (D-136.1).
- **The planner** `Gameplay/Markers/CodeHintPlanner`: a `code_note` (`code_hint`, `reveals_variant_group = code_pc`, no
  `code_group`) on Ashgrove's desk (43.9, 0.75, 23.9), read from the hall side.
- **Bonds:** the bond safe holds `VaultBonds` (`loot_spawn`, 1 × `loot.bearer_bonds`, tag `bond_safe`). The rare
  `bond_delivery` spawns at the marker `Gameplay/Markers/BondDelivery` (vault floor, (16.5, −4, 18.0), the open floor E
  of the bond safe; the doc names no spot).
- **Civilian routes** (`CivilianRoute`, LOOP, stops are `CivilianRouteStop`s on the navmesh, every stop ≥ 1.0 m from a
  door centre; `Patrols/Routes/`):

  | route_id | node | binds (bind_tags) | stops (dwell s) | away window |
  |---|---|---|---|---|
  | `mgr_floor` | ManagerFloorRoute | `civ_manager_mgr_floor` | BM desk 20–40 → hall 10–20 → TW 10–20 → PC 10–20 | `mgr_away` at the BM desk |
  | `mgr_gallery` | ManagerGalleryRoute (starts at CF) | `civ_manager_mgr_gallery` | VO 20–40 → CF 30–60 → OF 10–20 → PR 30–60 | `mgr_away` at CF, PR |
  | `mgr_vault` | ManagerVaultRoute | `civ_manager_mgr_vault` | SD desk 30–60 → CP 10–20 → LK WC 40–70 → BC (via SB) 10–20 | `mgr_away` at the LK WC |
  | `officer_coffee` | CoffeeOfficerAO1 | `civ_officer_ao1` | AO1 desk 60–120 → BR coffee 30–60 | `officer_away` |
  | `officer_coffee_of` | CoffeeOfficerOF | `civ_officer_of` | OF desk 60–120 → gallery WC 20–40 | `officer_away` |
  | `officer_coffee_vo` | CoffeeOfficerVO | `civ_officer_vo` | VO desk 60–120 → gallery WC 25–55 | `officer_away` |
  | `teller_rotation` | `Variants/Group_side_door/Slot_<door>/TellerRotation` | `civ_teller_rotating` | station 60–120 → BR 8–15 → station → WW 25–50; **`door_fire_propped`:** station → smoke outside the fire exit (50.5, 0, 6) 30–50 | `teller_away` |

  Each officer spawn carries `civ_officer` plus its desk tag (`civ_officer_ao1` / `_of` / `_vo`), so each officer has
  its own route (a route's stops are fixed, so one shared route would walk every officer to the same desk). The away
  times with the walk come to ≈ 50–90 s (officers), 40–80 s (teller), 47–67 s (smoke), as Circulation asks.

## Variable table
Each variable changes a decision. Rules resolve in this order (heist_map.md §5). Per-difficulty
weights use A2-08 / A3-10 (QC-18).

| variable | options (slot ids) | weights | gameplay effect (the decision it changes) |
|---|---|---|---|
| `manager_route` (`civilian_cluster`) | `mgr_floor`, `mgr_gallery`, `mgr_vault` | 0.45, 0.3, 0.25 | **Where you take the keycard from a person:** in the busy public hall and his glass office (witnesses), upstairs between meetings, or alone in the basement next to the vault post. |
| `keycard` | `kc_on_manager`, `kc_manager_desk` (BM), `kc_vault_ops` (VO), `kc_security` (SR cabinet) | 2, 1, 0.75, 0.75; pick 1 | **Tie a civilian or reach a room:** on the manager (above), his desk in the hall-facing office, the gallery vault-ops desk (C10), or behind the operator. |
| `code_pc` (heist group) | `pc_ao1`, `pc_ao2`, `pc_ao3`, `pc_ops` (OF), `pc_vault_ops` (VO), `pc_exec` (EA) | 1, 1, 1, 0.75, 1, 0.75; pick 1 | **Which floor and which desk:** the west officers (WL, visible from the hall), the open office, vault ops, or the Executive level (roof route). `[code_hint]` reveals it. |
| `officers` (scalar) | 1, 2, 3 | Routine 0.4/0.4/0.2; Brutal+ 0.2/0.4/0.4 | **Whether the code PC has someone at it:** wait for the coffee window or spend a tie. |
| `server_room` | `srv_gallery` (SV), `srv_basement` (CM) | 0.55, 0.45 | **The code-free alternative and the laser switch:** upstairs (far from the vault, near the PCs) or in the basement (next to the vault, on `rover_basement`'s loop). |
| `time_lock_s` (scalar) | 150, 210, 270 (D-075: approved) | Routine 0.4/0.4/0.2; Brutal+ 0.1/0.4/0.5 | **How long to hold the basement** against the vault post's loop, so whether to deal with him first. |
| `guard_post` | `rover_hall`, `rover_gallery`, `rover_basement`, `rover_dock` | 1 each; pick 2 / 3 / 4 / 4 / 4 / 4 rovers by difficulty via `difficulty_add` [1, 2, 3, 3, 3, 3] (D-140 GUARDS lever: 2 fixed posts + rovers + `guard_extra` 0/0/0/0/1/2 = 4 / 5 / 6 / 6 / 7 / 8 guards, pager cap 4; LEAD r246) | **Which route is walked:** the dock, the back corridor, the gallery/Executive (PCs, roof route), or the time-lock wait. |
| `security_room_staffed` | `sec_staffed`, `sec_empty` | Routine–Hazardous 0.6/0.4; Brutal+ 0.75/0.25 | **Live cameras or not.** Staffed: deal with him from behind (a pager) or live with cameras. |
| `camera` | `cam_a`, `cam_b`, `cam_c` (table in Sightlines) | 1, 1, 1 | **Which entry needs ECM or timing,** and whether the E1 bag line needs an ECM window. |
| `laser_pattern` (VC grid) | `lz_static`, `lz_sweep`, `lz_timed` | Routine 0.5/0.2/0.3; Brutal+ 0.2/0.4/0.4 | **Crouch gap, sweep timing or a wait** at the grid, crossed twice per bag. Raises the value of `[lasers]`. |
| `customers` (scalar) | 4, 6, 8 | Routine 0.4/0.4/0.2; Brutal+ 0.1/0.4/0.5 | **Witness density** in the hall and PC: the front route and anything in the hall-facing offices. |
| `side_door` | `door_fire_propped` (east fire exit, a teller smoking), `door_dock_open` (dock personnel door unlocked), `door_none` | 0.3, 0.3, 0.4 | **The first way into the back without a lockpick:** the camera-free east end (with a civilian outside) or the dock (in C6/C5's view). |
| `fire_escape` | `fe_down` (Corvino drop ladder lowered), `fe_up` | 0.45, 0.55 | **Whether the roof route exists:** straight to the Executive/Gallery PCs and SV, skipping the ground. |
| `escape` | `esc_van_dock` (E1), `esc_van_tannery` (E2), `esc_heli_terrace` (E3) | 0.45, 0.3, 0.25 | **The whole loot path and the last holdout** (H3, H5, H4): the lift, the fire exit, or 3 storeys up. |
| `drill_delivery` | `drop_terrace`, `drop_dock` | 0.5, 0.5 | **Loud only: which way the 2 HEAVY bags come** to the lid (60 m down from the terrace, or 30 m through LD), so which holdout you fight from first. |
| `drill_eta_s` (scalar) | 45, 60, 90 | uniform | **How long the first wave lasts before the drill is in reach**: start pushing to the drop now, or hold the counter. |
| `escape_eta_s` (scalar) | 90, 120, 150 | Routine 0.4/0.4/0.2; Brutal+ 0.2/0.4/0.4 | **How long the final holdout lasts**, so whether to secure bags before or during the wait. |
| `cash_bags` (scalar) | 6, 8, 10 | Routine 0.4/0.4/0.2; Brutal+ 0.2/0.4/0.4 | **Whether cash alone meets the 6** or the crew must open the bullion cage (HEAVY gold). |
| `gold_bags` (scalar) | 2, 3, 4 | uniform | **Greed**: HEAVY bags that slow the hoist and stair runs. |
| `deposit_boxes` (scalar) | 6, 9, 12 (vault walls) | uniform | **Small-loot greed** against saw noise 15 m from the vault post. |
| `president_safe` (`extra_loot`) | `ps_bonds` (1 bonds bag + 3 `small_loot`), `ps_empty` | 0.5, 0.5 | **A trip to the Executive level** (roof route or SA) for a LIGHT bag. |

## Rare events

| id | good/bad | chance | effect |
|---|---|---|---|
| `time_lock_glitch` | good | 4% | The lock is in its maintenance window: `time_lock_s` = 30. |
| `bond_delivery` | good | 5% | Vaultline delivered the quarter's bonds early: +2 `loot.bearer_bonds` in the vault. |
| `vip_client` | bad | 6% | A high-value client and a Halden bodyguard visit the SD hall for the whole run: +1 guard (pager) and +1 civilian in the basement. |
| `armored_car_early` | bad | 8% (`min_difficulty` Brutal) | At 15:00 elapsed a Vaultline van reaches the dock with 2 armed crew (pagers) who go LD → BC → **SA** down → BB → the vault gate (QC-25 timed spawn; NPCs cannot ride `bag_lift`, so not by the cash lift; GN errand pattern). Stealth must finish or deal with them. |
| `tower_sniper` | bad | 6% (`min_difficulty` Hazardous) | Loud: perch S3 in the Corvino window is enabled; the heli ETA is +30 s. |

## Escape
- **Van at the dock (E1):** Ledger Lane at the roller door (5, −3). Escape type `van`. Stealth:
  present from the start; the escape opens on 6 secured. Loud: it leaves at the alarm and returns
  `escape_eta_s` after `[secure]`. SECURE_LOOT at the rear doors from the start. Last holdout H3.
- **Van on Tannery Street (E2):** the loading bay at (52, 8), outside the fire exit. Same rules.
  Last holdout H5. The terrace throw spot reaches it: its SECURE_LOOT is the bay strip from the van's rear doors north
  under the terrace's SE corner (x 48.2–54.2, z 7.3–21.3; Loot path).
- **Heli over the terrace (E3):** escape type `heli`, `arrival_delay_s` 45 (stealth) /
  `escape_eta_s` (loud, +30 s with `tower_sniper`). SECURE_LOOT is the cargo net from the start
  (x 40.5–44.5, z 23.5–28.5, east of the heli, out of C12's view); ESCAPE on the heli area (35.5, 27). Last holdout H4.
- **Walk-out:** none (bags in the plaza would be seen).
- **Rule (D-136 §3b.10):** stealth opens the escape on 6 secured (4 on Routine); loud opens it on `[secure]` +
  `escape_eta_s`, whatever the assault phase.

## Pre-planning (preplanning.md contract, D-046 shape)
`Preplan` points (category; `floor` is the index into `floor_heights`: 0 Basement, 1 Ground,
2 Gallery, 3 Executive, 4 Roof; point labels are heist-qualified,
`ui.preplan.point.ostrander_federal.<point_id>`, preplanning.md v1.1):

| Point | Category | Params / asset |
|---|---|---|
| `pp_spawn_plaza` | spawn | default (spawn_tag `""`), the plaza (floor 1) |
| `pp_spawn_lane` | spawn | spawn_tag `preplan_spawn_lane` (Ledger Lane by the dumpsters) — `asset.alternate_entry` |
| `pp_spawn_tannery` | spawn | spawn_tag `preplan_spawn_tannery` (Tannery bay) — `asset.alternate_entry` |
| `pp_drop_lane` | drop_zone | by the dumpsters — body bag case, ammo, doctor |
| `pp_drop_restroom` | drop_zone | PW, the customer restrooms (floor 1) — body bag case only |
| `pp_drop_lockers` | drop_zone | LK (floor 0) — body bag case, ammo, doctor |
| `pp_drop_terrace` | drop_zone | the terrace (floor 3) — ammo, doctor |
| `pp_escape_dock` | escape | variant_group `escape`, slot `esc_van_dock` — `asset.escape_position` (vote) |
| `pp_escape_tannery` | escape | slot `esc_van_tannery` |
| `pp_escape_heli` | escape | slot `esc_heli_terrace` |
| `pp_drill_terrace` | drop_zone | variant_group `drill_delivery`, slot `drop_terrace` (floor 3) — new `asset.thermal_drill_drop` |
| `pp_drill_dock` | drop_zone | variant_group `drill_delivery`, slot `drop_dock` (floor 1) — new `asset.thermal_drill_drop` |
| `pp_fire_exit` | insider | variant_group `side_door`, slot `door_fire_propped` — `asset.propped_door` |
| `pp_dock_door` | insider | variant_group `side_door`, slot `door_dock_open` — `asset.propped_door` |
| `pp_vault_ops` | insider | variant_group `keycard`, slot `kc_vault_ops` (floor 2) — `asset.inside_keycard` |
| `pp_fire_escape` | insider | variant_group `fire_escape`, slot `fe_down` — new `asset.fire_escape_ladder` |

`HeistDef.preplanning` (contract v1.0 shape; entry keys are PreplanAssetDef fields; costs are Routine
prices, scaled by `PreplanTweak.cost_mult`; values marked ◇ are my proposals for ENV B/lead):
```gdscript
preplanning = {
    "favors": 8,                                                                     # size L (D-075)
    "disable": [],
    "assets": {
        # library assets, limited to this heist's points
        &"asset.body_bag_case_drop": {"point_ids": ["pp_drop_lane", "pp_drop_restroom", "pp_drop_lockers"]},
        &"asset.ammo_bag_drop": {"point_ids": ["pp_drop_lane", "pp_drop_lockers", "pp_drop_terrace"]},
        &"asset.doctor_bag_drop": {"point_ids": ["pp_drop_lane", "pp_drop_lockers", "pp_drop_terrace"]},
        &"asset.propped_door": {"point_ids": ["pp_fire_exit", "pp_dock_door"],
                                "exclusive_group": &"side_door", "max_count": 1},
        &"asset.inside_keycard": {"point_ids": ["pp_vault_ops"], "cost": 2500, "favors": 2},   # ◇
        # new heist assets (QC-66)
        &"asset.thermal_drill_drop": {"effect": &"force_variant", "drop": &"loot.thermal_drill_part",
                                      "params": {"count": 2},
                                      "point_ids": ["pp_drill_terrace", "pp_drill_dock"],
                                      "exclusive_group": &"drill_delivery", "max_count": 1,
                                      "cost": 2500, "favors": 2, "tags": [&"loud"]},         # ◇
        &"asset.intel_code_pc": {"reveals": [&"code_pc"], "cost": 2000, "favors": 2,
                                 "category": &"intel", "tags": [&"stealth"]},                 # ◇
        &"asset.manager_schedule": {"reveals": [&"manager_route", &"keycard"], "cost": 1500,
                                    "favors": 1, "category": &"intel", "tags": [&"stealth"]}, # ◇
        &"asset.fire_escape_ladder": {"effect": &"force_variant", "point_ids": ["pp_fire_escape"],
                                      "max_count": 1, "cost": 1500, "favors": 1,
                                      "category": &"access", "tags": [&"stealth"]},           # ◇
    },
}
```
Crew assets with no point that stay on: `asset.intel_cameras` (reveals `camera`),
`asset.intel_guard_posts` (`guard_post`), `asset.intel_keycards` (`keycard`; overlaps
`asset.manager_schedule`, which also gives the route), `asset.extra_cable_ties` (civilians: the
manager and the officers), `asset.spare_body_bags`. The board hides library assets whose groups do
not exist here (laptop, gondola, riser, perches, containers, gangway, lift power) automatically
(QB-53, D-049), so `disable` is empty. `asset.escape_position` and `asset.alternate_entry` work from
the points' params. `asset.thermal_drill_drop` places the 2 bags at the chosen point at the start
**and** forces that `drill_delivery` slot, so the mission skips the timed delivery. It needs `drop`
with a count (`params.count`; preplanning.md v1.1 allows `params`). Blueprint:
`docs/levels/ostrander_federal/blueprint.png` from the plan renderer (5 floors).

## Audio/lighting
- **Palette** (proposed style guide §3 row, QC-69): **limestone `#CBC3B0`** dominant (the facade,
  the hall's walls, pillars and the coffered ceiling), **deep ultramarine `#2F3F6B`** secondary (the
  ceiling coffers' ground, the hall carpet runners, the bank livery, the gallery's leather and the
  vault paint), **meridian bronze `#B8873A`** accent (the sunburst, the meridian line, the teller
  grilles, the vestibule, the vault door's bright-work). The warm sunlight on the line is the hall's
  key light. The bronze sits darker and more orange than Glasshouse's brass (`#C9A227`) so the two
  never read alike. BOH is painted block and vinyl in a cool grey-blue. Wear is **pristine** (style
  guide §4: bank).

  | Heist | Dominant | Secondary | Accent | Mood / time |
  |---|---|---|---|---|
  | ostrander_federal | limestone `#CBC3B0` | deep ultramarine `#2F3F6B` | meridian bronze `#B8873A` | Friday afternoon, broken cloud, low SW sun shafts |

- **Time:** 15:10. The sun is 24° high in the SW (azimuth ~220°). It is **direct and intermittent**
  (the cloud-shadow animation is a slow light-energy curve on the sun, presentation only). Shafts
  come through the south arched windows, and the lantern oculus throws the disc onto the meridian
  line. The streets are wet (puddle decals, reflections).
- **Zones:**
  - the hall: warm 3000 K bronze pendants (all on during business hours) plus daylight; brightest
    and warmest;
  - TW: 3500 K counter lamps over each station;
  - the gallery and loggias: 3500 K wall sconces;
  - offices: 4000 K panels at full level (business hours);
  - BOH (BC, SR, GR, LD): 5000 K; the security room is dim with the monitor glow;
  - the basement: 5000 K utility battens; VC: red laser glow; VT: bright 4000 K strips on the cages;
  - the executive level: 3000 K table lamps and picture lights;
  - exteriors: overcast daylight + sun; the kiosk and the Belmont's awnings lit.
  - Every light has a fixture.
- **GI:** VoxelGI per level band (basement; ground + gallery including the hall; executive),
  ReflectionProbe per room (the hall gets 2), OccluderInstance3D for the shell, the Corvino and
  Belmont facades, the parking structure and the Assay Office.
- **Ambience:** `amb_bank_hall_day` (a large stone room: footsteps on marble, murmurs, the counter's
  note counters and printers, a pneumatic-tube thunk every 40–90 s, the hall clock), `amb_bank_boh`
  (HVAC, fluorescents, distant phones), `amb_vault` (low ventilation, the time-lock clockwork tick
  while it runs), `amb_city_afternoon` (traffic, buses, pigeons on the plaza, wet tyres).
  `cue.alarm_bell` per-heist variant: a deep two-tone bank bell.
- **Music:** `ostrander_federal` (new track "Clearing House", ENV C stems): `stealth` 72 BPM (low strings and a
  clockwork tick that tightens during the time lock), `control`, `anticipation` riser, `assault`
  148 BPM (driving percussion with a brass motif), `fade`, `win`/`lose` stingers (audio_cues.md
  music stems). It joins `MusicTrackTable` with `default_for_heists [ostrander_federal]`.
- **VO line ids** (`vo.<speaker>.<heist>_<line>`, D-051; ENV B writes the text):
  - **The Accountant:** `vo.accountant.briefing_ostrander_federal_1..3`,
    `vo.accountant.ostrander_federal_contact_intro`, `vo.accountant.ostrander_federal_payday`.
  - **Mercer:** `vo.mercer.briefing_ostrander_federal_1..2`, `vo.mercer.ostrander_federal_intro`,
    `vo.mercer.ostrander_federal_case_manager`, `vo.mercer.ostrander_federal_case_gallery`,
    `vo.mercer.ostrander_federal_case_operator`, `vo.mercer.ostrander_federal_keycard`,
    `vo.mercer.ostrander_federal_code_hint`, `vo.mercer.ostrander_federal_pc_found`,
    `vo.mercer.ostrander_federal_hack_interrupt`, `vo.mercer.ostrander_federal_code`,
    `vo.mercer.ostrander_federal_server_hack`, `vo.mercer.ostrander_federal_vault_gate`,
    `vo.mercer.ostrander_federal_lasers_off`, `vo.mercer.ostrander_federal_time_lock_started`,
    `vo.mercer.ostrander_federal_time_lock_60`, `vo.mercer.ostrander_federal_time_lock_open`,
    `vo.mercer.ostrander_federal_last_pager`, `vo.mercer.ostrander_federal_camera_warning`,
    `vo.mercer.ostrander_federal_lockdown`, `vo.mercer.ostrander_federal_drill_inbound`,
    `vo.mercer.ostrander_federal_drill_delivered`, `vo.mercer.ostrander_federal_drill_jam`,
    `vo.mercer.ostrander_federal_burn_through`, `vo.mercer.ostrander_federal_hoist`,
    `vo.mercer.ostrander_federal_gold_cage`, `vo.mercer.ostrander_federal_required_secured`,
    `vo.mercer.ostrander_federal_sniper_assay`, `vo.mercer.ostrander_federal_sniper_garage`,
    `vo.mercer.ostrander_federal_sniper_tower`, `vo.mercer.ostrander_federal_armored_car`,
    `vo.mercer.ostrander_federal_van_eta`, `vo.mercer.ostrander_federal_heli_eta`,
    `vo.mercer.ostrander_federal_escape`.
  - Crew barks reuse the generic `vo.crew.*` set.
- **LUT:** `lut_ostrander_federal`: warm, slightly golden highlights, neutral-cool shadows, soft
  contrast. Daylight with no crushed blacks: it is the brightest heist so far.

## Review shots
`HeistMap.review_cameras` (level_standards §8; JPEG q85, D-038). Each camera is ≥ 0.5 m inside its
room (C1-04 check). There are 34 shots: 1 top-down, 4 exterior, 3 landmarks (covered within those),
1 per major room, the security room, the vault, the deposit hall and the sniper views.

| Camera | Shows | Covers |
|---|---|---|
| `rc_top_down` | orthographic plan of the whole play space | top-down plan |
| `rc_ext_plaza` | from the avenue's far sidewalk: the facade, the **sunburst**, the steps, the plaza | exterior 1, landmark 1 |
| `rc_ext_lane` | Ledger Lane from the west: the dock, the dumpsters, the fire escape, the garage | exterior 2 |
| `rc_ext_tannery` | Tannery Street from the north: the E2 bay, the fire exit, the Belmont | exterior 3 |
| `rc_terrace` | the terrace from the XL doors: the **lantern**, the heli net, the Assay Office beyond | exterior 4 (X4), landmark 2 (outside) |
| `rc_hall_entrance` | from the vestibule: the hall, the **meridian line** with the sun disc, the counter, the gallery | BH, landmark 2 (inside) |
| `rc_hall_counter` | from the counter's east end looking W along the **teller line** | BH, landmark 3 |
| `rc_hall_from_gallery` | from GA down onto the hall floor | GA, BH (loud high ground) |
| `rc_vestibule` | VE from inside the bronze doors | VE |
| `rc_atm` | AV | AV |
| `rc_teller_workroom` | TW from the west: stations, **the lid** | TW (H1) |
| `rc_client_lounge` | PC with the BC service door | PC |
| `rc_manager_office` | BM through its glass front | BM |
| `rc_loan_office` | LO | LO |
| `rc_back_corridor` | BC from the west, the fire exit at the far end | BC (H5) |
| `rc_security_room` | SR behind the operator: the monitor wall | SR (security room) |
| `rc_loading_dock` | LD: the roller door, the lift | LD (H3) |
| `rc_break_room` | BR | BR |
| `rc_officers` | AO2 and the loggia glazing to the hall | AO1–3, WL |
| `rc_operations` | OF | OF |
| `rc_vault_ops` | VO | VO |
| `rc_server_room` | SV | SV |
| `rc_president` | PR with the safe | PR |
| `rc_exec_lounge` | XL to the terrace doors | XL |
| `rc_boardroom` | BD | BD |
| `rc_basement_corridor` | BB from SA toward SB, the vault gate on the right | BB (H2) |
| `rc_concourse` | VC through the gate: the grid, TL, the vault door | VC |
| `rc_vault` | VT from the door: the cash cage, the bullion cage, the box walls | VT (vault) |
| `rc_vault_hole` | VT under the hole: the ladder and the hoist (loud variant) | VT (loud) |
| `rc_deposit_hall` | SD down the box rows | SD |
| `rc_count_room` | CP | CP |
| `rc_records` | RC aisles | RC |
| `rc_roof` | the main roof from HH toward Corvino's fire escape and setback | X5 |
| `rc_sniper_assay` | from S1 over the plaza into the hall windows | sniper LOS check |

## Budgets
Targets from architecture §10 and D-038 QC-10, checked by the `perf` validator per review camera.
Ostrander Federal is the first **L** map: the hall is one 576 m², 8 m high room seen from the
plaza, the gallery and the vestibule.

| Budget | Target | Notes |
|---|---|---|
| Draw calls per view | main ≤ 2,500; total ≤ 4,000 incl. shadow passes and the peak cast (D-146) | Judged on Forward+ on the GPU box (D-146 addendum 6): loud, Cataclysm, 33 NPCs, 1,539–2,258 total in the hall views (map 858–1,481, cast 628–809). The Compatibility fallback, measured with D's heist_cast_perf: 2,197–3,163 with the cast. levelcheck `perf` is a report-only Compatibility early warning (main + light passes + shadow passes, no occlusion, every variant active, 0 to +10 % over the renderer). See docs/levels/ostrander_federal/g2/perf/perf.md. The worst views are `rc_back_corridor`, `rc_teller_workroom`, `rc_hall_entrance` and `rc_hall_counter`. The coffers, teller grilles, queue posts, benches, deposit boxes (44 in SD/VT) and the facade window bays are **MultiMeshInstance3D** per kit item. Shadow levers (OF-C2, D-146): the sun at 2 splits over 30 m (was 4 over 90 m); `RenderBudgetPolicy` (Lighting): dressing, loot, devices, containers and small variant props inside the rooms cast no shadow outside the hall BH, nor do doors between two interior rooms; dressing ranges outside BH/TW are cut to 24 m; the hall's own dressing moves to render layer 5 (`sun_shadow_skip`, visual_slots v1.6), which the sun's shadow_caster_mask leaves out (the pendant still shadows it). The shell, finishes and exterior doors keep casting (no light leaks). |
| Triangles per view | ≤ 3M (provisional, QC-10) | The coffered ceiling is a single trim-sheet mesh with 2 LODs. The far towers are LOD facades. |
| Shadowed lights in any shot | ≤ 8 | The sun (1) + **1** hall pendant (LEAD r246: the other 3 pendants use the same bronze fixture, unshadowed), its shadow (6 cube passes: Compatibility has no dual paraboloid) distance-fades at 14 m (+5 m) since D-146, so only the hall views pay for it. The 6 room fixtures (SR, VT, PR, OF, LD, BB) cast no shadow since D-146. Each re-drew 300 to 430 casters in every hall view (behind the hall walls: lights are not occluded) for a shadow that reads only in its room. The counter lamps, sconces, battens and the 2 warm hall pools are unshadowed. |
| Texture memory | ≤ 1.5 GB | The shared library (limestone, marble, terrazzo, bronze, brass, plaster, carpet, wood veneer) covers ~85%. New: limestone ashlar, the coffer trim sheet, the meridian line inlay. |
| NPCs alive | stealth: guards ≤ 8 (6 + 2 rare), civilians ≤ 22 (19 + 2 plaza + 1 VIP; ≤ 30 cap); loud: police ≤ `DifficultyDef.max_active_enemies`, civilians ≤ 22 | The civilians cower in place in loud: they are the hostage pool. D-136 §3b.5 adds the SD attendant (+1). |
| Exterior traffic | ≤ 12 parked cars (MultiMesh), no moving traffic in play (a distant animated ribbon only) | |
| **Density (kits)** | hall: 0.03–0.06 props/m² (clustered at the counter, the check desks, the benches and the pillars; the meridian line kept clear); TW: station clutter per kit; offices per kit minimums; SD: booths + rows; VT: cages + pallets (≥ 60% of the vault floor clear for the hoist and bag routes) | Same-kit rooms (AO1–3, CN1/2, LG/CT) must differ in layout hash (`variety`). |

**Levelcheck configuration (OF-C3; the map lane sets these at G1).** All opt-in, so other maps are unaffected:
- `lasers`: HeistMap metas `laser_min_gap_m = 1.0` and `laser_crouch_face_m = 1.215` (D-104 §7.1; the defaults stay
  0.8 / 1.22 for the other maps). The VC grid's bypass gap is measured at the walls and to any neighbouring grid
  (between emitters).
- `teller_worktop`: the 12 counter work tops are props with meta `kind = "teller_worktop"` (teller side = local −Z,
  the customer side +Z) and meta `hide_behind = true` (the crouch-hide claim); the bandit glass has meta
  `see_through = true` (or kind `window`/`glass`).
- `hide_los`: Marker3D / Path3D nodes with meta `hide_spot = true` and `hide_from` (room ids): the TW strip behind
  the counter (`hide_from = ["BH"]`), the GA crossing line (`hide_from = ["BH"]`) and the RC end aisle
  (`hide_from = ["BB", "RC"]`, step 5), all `hide_posture = "crouch"`.
- `bag_line`: Path3D / Marker3D chains with meta `bag_line`: `vault_sa_cq` (VT → VC → gate → BB → SA and CQ),
  `vault_e2` (BB east → SB → BC east → fire exit), `vault_e3` (SA → XC west → XL → the facade-hugging terrace path →
  the net), each camera-free in `cam_a/b/c` (`camera_layout_group` = `camera`); the E1 line (LD → van) carries
  `bag_line_layouts = ["cam_b", "cam_c"]` (`cam_a` needs the ECM window by design).

**Walkthrough whitelist** (level_standards §6): the pairs **plaza spawn ↔ the president's safe / `pc_exec`** and **the vault ↔ the
heli net** exceed 3× their straight-line distance (SA is the only way up; a 3-storey climb over a
~20 m plan distance). That is by design (as Shadow Ledger's tower).

## HeistDef (proposed data, `ostrander_federal_def.tres`)
`id ostrander_federal`, display "Ostrander Federal", contact `contact.accountant`, mode
STEALTH_OR_LOUD, base_payout **$80,000** (ENV B, D-137 on the D-120 shape; above SL's $70k as the bigger L job; was
$160,000), loot
`[loot.cash_bricks, loot.gold, loot.bearer_bonds, loot.server_drives]` (`loot.thermal_drill_part`
is a tool; deposit-box valuables are prefab small loot), escape_options `[van, heli]`, music_track
`ostrander_federal`, objectives `[casing, keycard, code_hint, code_pc, server, vault_gate, lasers,
time_lock, time_lock_wait, vault_loot, gold_cage, secure, deposit_boxes, bond_safe, president_safe,
server_drives, drill_delivery, vault_drill, vault_breach, escape_wait, escape]`, preplanning as
above. Map `game/world/heists/ostrander_federal/ostrander_federal.tscn`; `floor_heights [-4.0, 0.0,
5.0, 8.6, 12.2]`, `floor_names ["Basement", "Ground", "Gallery", "Executive", "Roof"]`.

## Requests (to the lead; QC-60..69)
- **QC-60 (ENV A):** thermal-drill **assembly from tool bags**. `drill_point` gains `requires_loot:
  StringName` and `requires_count: int` (each placement consumes one carried bag; the device starts
  when the count is met), so 2 × `loot.thermal_drill_part` assemble on the lid. Also a mission
  **timed loot spawn**: `HeistMission.spawn_loot(loot_id, marker, count)` for the drill delivery
  (the QC-25 hook shape, for bags).
- **QC-61 (ENV A):** **floor breach.** Runtime enabling of pre-placed prefabs (`ladder`, `bag_lift`)
  and their nav links when a device finishes, e.g. `GameplayPrefab.set_enabled(bool)` (disabled =
  hidden, no collision, no interaction, nav links off), plus a one-way police rappel link down the
  hole (QC-41 shape).
- **QC-62 (ENV A):** **NPC-carried keycard.** A civilian SpawnPoint export `carried_item:
  StringName` (`item.keycard`). A restrained (tied or intimidated) or dead carrier offers `take_item`
  (1 s, `carried_item_s`). On death the item stays on the body. No pickpocketing (PD2 has none). **Closed by
  D-136 §3b.2:** QC-62 = QC-52 (`KeycardPickup.carrier_tag = civ_manager_*`).
- **QC-63 (ENV A):** `hack_terminal.reveals_code_group: StringName`: finishing reveals that code
  group exactly as reading a `code_note` does. Plus an intel note that reveals a **variant group**
  on read (the manager's planner → `code_pc`), the same effect as an asset `reveals`.
- **QC-64 (ENV A):** **vault lockdown API.** `Safe.abort_time_lock()` (a running time lock stops and
  the door stays shut; `device_finished` never fires) and a way for the mission to reseal and BAR a
  VAULT door. If Night Deposit's G1 already does this in its mission, please confirm the API. **Closed by D-136
  §3b.1:** no Safe API; the Night Deposit mission-timer pattern (Mission script notes).
- **QC-65 (ENV B loot/strings):** `loot.thermal_drill_part` (HEAVY, `is_tool`, value 0). Please
  confirm `loot.cash_bricks` / `loot.gold` / `loot.bearer_bonds` / `loot.server_drives` for this
  heist and the deposit-box value band ($800–2,400) with or without a `loot.small_valuables` def.
  Also: objective strings `objective.ostrander_federal.<tag>` for the `[tag]`s above, the briefing
  text, the VO text, and the B6-01 stub's "waiting on ENV C" list (all answered here).
- **QC-66 (ENV B assets):** new `asset.thermal_drill_drop` (force_variant + a 2-bag loot drop),
  `asset.intel_code_pc`, `asset.manager_schedule`, `asset.fire_escape_ladder` (shapes above), and
  the per-heist overrides of `asset.propped_door` and `asset.inside_keycard` (point params name
  this heist's groups, like Glasshouse).
- **QC-67 (ENV D cast):** confirm the Ostrander Federal roles as used above (`bank_teller`, `bank_manager`,
  `bank_guard` with Halden badges, `bank_customer`) and the manager's name **Lionel Ashgrove**. Add
  a **`bank_officer`** role (account officers: day office wear in the bank livery; reuse
  `npc_bank_night_manager` re-dressed and `npc_bank_teller_b`, your call). Cast
  `armored_car_crew` (Rolling Thunder) into Ostrander Federal for `armored_car_early` and a `bank_vip_client`
  (any existing customer id in a better coat). Also confirm the ambient placements I sized to:
  `teller_count` (1.00 m top, near edge 0.28 m) and `cower_stand` (wall 0.21 m behind);
  `cower_seated` on hall benches and PC armchairs; `walk_text` for the plaza pedestrians.
- **QC-68 (ENV A):** police rappel from a **neighbour roof**: one-way links from the P5 setback
  (+16.0, police-only island) to the bank's main roof (+12.2) and terrace (+8.6), and from the
  terrace through the lantern into the hall (8.6 m). This is QC-41's mechanism with a longer drop.
  Validator side (mine): reachability through the chain.
- **QC-69 (lead):** add the palette row above to style guide §3 (and `lut_ostrander_federal`).
  Confirm ENV B's UI accent `#6FCF97` (banknote green). It is a UI colour, not a world colour, so it
  does not need to match the palette.

## Lead rulings (D-075; the G0 open questions, closed)
1. **Name:** renamed **Ostrander Federal** (`ostrander_federal`), because "Meridian" is used by real
   banks. Every id follows (heist id, map path, music track, VO ids, objective/preplan strings, LUT
   `lut_ostrander_federal`, display names). The brass **meridian line** in the hall floor keeps its
   name (a feature, not the brand). Files outside ENV C that still say `meridian_federal` are listed
   in ENV C's report to the lead (ENV B content, board, strings, tests; roadmap and overview docs).
2. **Ceilings:** the validator's scale table gains **`hall`** (**6–9 m**), so BH is a `hall` with no
   override. The basement (2.6–3.2, Night Deposit precedent) and XL (2.6–3.0, Shadow Ledger QC-31)
   overrides and the ground floor's 1.2 m plenum are not changed by the D-075 rulings relayed to
   ENV C; they stay as drafted, on their earlier precedents.
3. **Required loot:** **6 bags**, **4 on Routine**.
4. **Time lock:** 150–270 s (150/210/270) approved.
5. **G1 fallbacks** for the floor burn (QC-60/61: a plain THERMAL `drill_point` on the lid and a
   mission-toggled ladder and `bag_lift`, `TODO(QC-61)`) and the carried keycard (QC-62: a
   `keycard_pickup` on the manager's hip, usable only while he is restrained or dead): fine.
6. **Office staff:** the lead asks ENV D for the **`bank_officer`** role (QC-67); until it ships the
   officers use `npc_bank_teller_b`.
7. **Favors:** 8.
8. **Gallery guard:** a **solid base** to 1.0 m (0.1 m glass cap), so a crouched player crossing GA
   is hidden from the hall floor.
