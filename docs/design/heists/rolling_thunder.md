# Rolling Thunder: the Vaultline convoy (rolling_thunder)
Status: G0 DRAFT: review requested (ENV C, 2026-10-11). Open questions for the lead are at the end
(Open questions); cross-env requests are QC-80..QC-89.

## Fiction
- **Who:** **Vaultline Armored Transport**, the cash-in-transit company that moves Southfield's money.
  ENV D cast and dressed its crews in D3-01: sand shirts, black ballistic vests, brown caps and the
  **amber Vaultline mark**. Every second Friday, Vaultline runs the **Southfield consolidation
  convoy**. It collects the week's takings from the Southfield cash centre and a bullion dealer's
  stock, then drives them to the reserve vault at Meridian Federal. That is the P5 bank, a
  deliberate tie-in. On bullion runs Vaultline pays the city for a **police escort**: a car in
  front and one behind.
- **Name ruling (ENV D's invention): confirmed, "Vaultline Armored Transport".** Reasons:
  - It is an original compound. It is not PD2's GenSec or any armoured-car operator I know of.
  - It reads as a cash-in-transit company at a glance.
  - It does not clash with our other security firms (Halden Security, Halberd Gallery Security,
    Northgate).
  - D's sand/black/amber livery already sits on two finished characters and on their `SOURCE.txt`.
  - The amber mark doubles as this heist's accent colour (palette below).
  - Renaming would cost D a rebuild for no gain.
- **What:** the convoy is two or three Vaultline trucks:
  - **cash vans** carry shrink-wrapped cash bricks;
  - **bullion trucks** carry gold bars;
  - on a lucky day, a courier's case of bearer bonds.
- **Why / contact:** **Hollis "Hammer" Reyes** (fixer: loud jobs, armoured trucks; `contact.reyes`,
  Board district `southfield`, anchor (0.14, 0.86) in `city_map.tres`): *"Vaultline puts it in
  their brochure: 'Never opened on the road.' Forty years. I'd like to be in the next edition.
  They stop at Tannery and Orchard. I'll make sure they stop. You make sure they open."* Reyes
  drives the **ram truck** himself: a stolen cement mixer, waiting inside the construction site.
  He pays per bag.
- **Time / weather:** 16:50 on a dry, windy autumn Friday. This is **the first daylight heist**.
  - The sun is low in the WSW (azimuth 245°, elevation 9°), so it shines straight down Tannery
    Road from the west.
  - Long raking shadows run under the Skyway. Dust and leaves blow in gusts.
  - The Friday-afternoon street is busy: pedestrians, a bus queue, the diner.
- **Handler:** Mercer on comms, plus Reyes on the radio from the mixer cab. The crew arrives on foot,
  **unmasked**, at the bus interchange (default), in the car park, or in the underpass (pre-planning
  spawn choice). The crew's gear (the placed saw rig, ammo and doctor bags) is pre-staged.

## Modes
- **Loud, with a stealth-start ambush.** `HeistDef.mode = STEALTH_OR_LOUD`, because the heist
  starts in the STEALTH phase with the crew in casing mode. But **there is no stealth win**:
  - the trucks only exist after the convoy stops;
  - every route through the ambush ends in `alarm_raised`.
  - The Board and briefing label it "Loud (ambush start)"; see Open question 1.
  - Size M (15–25 min). Phase P5.
- **Phase 1: Setup (stealth, `convoy_eta_s` = 150/180/210 s from the start).** Mercer counts the
  convoy in, and the countdown is an objective timer on `[convoy]`.
  - The street is **PUBLIC**. Pedestrians walk and civilians wait at the bus stops and sit in the
    diner. Casing rules apply (S1.1): the crew can walk anywhere public unseen, but cannot
    interact or carry bags.
  - The construction site, the diner's back of house, the car park booth and plant room, and the
    rail lane are **RESTRICTED**.
  - The work (rigging the signals, raiding the site stores, dealing with the marshal) needs the
    crew **masked** and **out of sight**:
    - civilians who see a masked player panic and call the police (S7);
    - the beat cop (`cop_on_scene`), the site guard (Halden Security, pager) and the site camera
      detect a masked crew member by the standard rules.
  - Clean masking spots are the site interior, the car park stair cores and Deck 2, and the
    underpass.
  - **Any alarm in this phase is an "early alarm"** (below).
- **The stop trigger** is the **junction signals**. When the convoy reaches its arm of the junction:
  - **Signals rigged (`[signals]` done) and no alarm: the clean stop.** The light goes red and the
    convoy halts in line at the stop line of its arm (`stop_clean_<route>`).
    - 3 s later Reyes noses the mixer out of the site's Tannery gate and across the front of the
      convoy. The rear escort car boxes the trucks in from behind.
    - The **ambush window** (`ambush_window_s` = 8 s) opens. The escorts sit in their cars and the
      Vaultline crews in their armoured cabs.
    - Any crew shot, explosion, or masked crew member seen by a convoy unit **springs the ambush**
      (`alarm_raised(&"ambush")`). Otherwise the escort "makes" the crew at the end of the window
      and the mission raises the same alarm (QC-83).
    - The escort cars are soft (windows break, L3 damage applies), so the window is the crew's
      free first volley. The armoured cabs stop bullets. The Vaultline crews dismount
      `dismount_delay_s` (4 s) after the alarm.
  - **Signals not rigged and no alarm: the crash stop.** The convoy runs the green, and Reyes rams
    the lead escort with the mixer in the middle of the junction (`stop_crash_<route>`).
    - The trucks jam behind it, skewed.
    - The impact raises the alarm at once. There is no window, and the convoy units dismount
      immediately.
- **Early alarm** (an alarm before the convoy arrives): the police are called and Vaultline is
  warned. The convoy still comes, because Vaultline's policy is to push through to the depot.
  - `police_delay_s` drops to **0**, so the director starts at once and first responders are on
    the street before the convoy.
  - At `convoy_eta_s` the convoy arrives **alerted**: Reyes rams it (crash stop) and every convoy
    unit dismounts into cover.
  - **The trucks are in lockdown:** deadbolts thrown, so saw times are ×1.5 (C4 and thermite are
    unchanged).
  - Mercer: "They know. Reyes, you're on. Everybody else, find cover and wait for it."
  - This is the price of a sloppy setup, and the most dangerous way to play the heist.
- **Phase 2: Loud.** After the ambush the convoy units fight from the vehicles as cover.
  - The police come after `police_delay_s` (45/60/90 s, rolled per difficulty; 0 after an early
    alarm). Then the `AssaultDirector` runs from the first CONTROL as usual (QC-35, already in
    `HeistMission.police_delay_s`).
  - The crew opens the trucks (placed saw, hand saw, C4, thermite on the bullion roof hatch), bags
    the cargo, secures ≥ 4 bags and holds for the escape.
- **It uses the full P3 loud set:** every special, Brandt + Aegis, escalation, custody and hostage
  trades (the street is full of civilians), AI orders, and the device set:
  - **placed saws** on the truck rear doors (`saw_target` for the hand-held saw, D-057);
  - **C4** (4 charges per truck, PD2);
  - **thermite** on the bullion roof hatch (`burn_point`, QC-38 + QC-81);
  - padlocks and lockpicking in the setup.
- **The design goal is the P3/P5 holdout loop on an open street:**
  - Each truck pins the crew to a spot in the convoy queue for a timed device.
  - **Four holdouts** frame the junction, and police come from **six directions**.
  - Two to four sniper perches cover the bag routes.
  - Where the convoy stops is a variable (route × clean or crash), so which holdout matters changes
    every run.
- **Difficulty notes:**
  - Routine/Tense: 2 trucks (70%), patrol-car escorts, police delay usually 90 s.
  - Hazardous/Brutal: 2–3 trucks, TAC escorts (with a TAC Heavy in the rear car), delay usually
    60 s, S4 always on.
  - Lethal/Cataclysm: 3 trucks usually; Brandt + Aegis in reach of the junction. Faction reskins
    come from the director (L1.5). The rare `armored_escort` puts a Wrecker in the rear escort.
  - **Solo with AI** (first-class, L6.1): AI teammates stay at the spawn during the setup (they are
    "in the van") and join on the alarm. Bags only move on `carry_bag` orders. Gold is HEAVY, which
    makes the heli escape the solo skill check.

## Site
- **Lot:** a city **crossroads under an elevated expressway**, with the public street as the play
  space. Ground FFL = 0.0 at the junction.
  - The origin is the **junction centre**; +x is east, +z is south.
  - **Orchard Avenue** (N–S): a 20 m carriageway (x −10…10) with a 2 m kerbed median (x −1…1),
    4 m sidewalks (x −14…−10, 10…14), and right-hand traffic, so southbound uses the west lanes.
  - **Tannery Road** (E–W): a 16 m carriageway (z −8…8) with 3 m sidewalks (z −11…−8, 8…11).
  - **Overhead:** the **Southfield Skyway**, an elevated expressway (deck x −13…13, deck top
    +9.0, girder soffit +7.6). It follows Orchard for the whole play space.
    - Concrete piers stand in the median at z −72, −40, 30 and 62 (2.0 × 3.0 m).
    - The junction span (z −40…30) is a 70 m **steel box girder painted "Skyway green"**.
  - **The east arm** runs flat to x 34, then **dips** down a 32 m ramp (x 34…66, 0.0 → −5.0, 8.9°).
    - It passes under the **rail bridge** (x 66…84) in the **Tannery underpass** (−5.0, clear
      height 4.6 m, height bar 4.4 m at x 62).
    - It continues at −5.0 in the east cut (x 84…104).
    - The ramp's retaining walls (z −11 and z 11) rise from 0 to 5.0 m. At street level they carry
      a 1.1 m parapet railing.
- **Corners and neighbours:**
  - **NE: the Southfield Park & Ride** (x 16…52, z −50…−14), a 1970s open-sided multi-storey car
    park.
    - Ground (0.0), Deck 2 (+3.5) and Roof (+7.0), with two stair cores, a goods/passenger lift and
      stacked straight ramps.
    - It is holdout **H1** and the E1 and E3 escapes.
  - **NW: Tanner's Reach**, a housing development on a building site (x −60…−14, z −56…−11) behind
    a 2.4 m painted plywood **hoarding**.
    - Inside are the half-built concrete **frame** (ground slab plus the first-floor slab at +3.5),
      the site cabins, the demolition contractor's **explosives magazine**, a **tower crane**, and
      the **junction signal controller** (its footpath corner was fenced into the site during the
      works).
    - Reyes's **mixer** waits inside the Tannery gate.
    - It is holdout **H3** and the stealth playground.
  - **SE: the Halfway Diner** (x 14…34, z 14…32), a two-storey 1950s brick corner diner with a back
    yard. Next door are a laundromat (x 34…50) and Southfield Tyres (x 52…64), both dressing.
    It is holdout **H2**.
  - **SW: the Southfield bus interchange**, a paved plaza (x −60…−14, z 11…30) with bus shelters,
    benches, trees and the **cast-iron clock pillar**. Behind it is **Ashby House** (x −60…−24,
    z 30…50), a 4-storey 1960s office block (roof +14.4, sniper perch S4). This is the default
    player spawn.
  - **East:** the **freight line** (tracks at x 70 and x 80) runs N–S on a low bank (rail level
    +1.2) between 1.8 m palisades (x 64 and x 86) and crosses the underpass on the rail bridge.
    - The **rail access lane** (x 52…64, z −90…−14) runs behind the car park. It is a police
      flank and the P_NE spawn route.
    - A **signal gantry** over the tracks is sniper perch S2.
- **Exterior landmarks:**
  1. **The Skyway's green box girder** over the junction: 70 m long and riveted, with a row of
     sodium tubes under it that are on even in daylight, and the "SOUTHFIELD SKYWAY" name band on
     its fascia. It is visible from everywhere.
  2. **The clock pillar** on the plaza: 6 m of cast iron and a four-faced clock **set to the
     convoy's ETA by fiction** (it's slow). Its face reads from the junction, the car park and the
     diner.
  3. **The tower crane** over Tanner's Reach: a 42 m mast, the jib swinging slowly in the wind,
     and a red aviation light. It is a skyline marker from every arm and perch S3 (rare).
  4. **The Halfway Diner's neon** "HALFWAY · OPEN 24 HRS" sign on the corner chamfer, half-lit
     in the low sun. It is the warm landmark of the SE corner.
- **Play space:** x −80…104, z −90…72 for crew, the underpass cut at −5.0 included. Police spawns
  lie beyond the closures:
  - the Orchard north and south ends;
  - Tannery west;
  - the underpass east;
  - the rail lane north end;
  - the Skyway deck.

  Each edge is closed as follows (the `bounds` validator checks every one).

### Play-space closure

| Edge | Closure |
|---|---|
| Orchard north (z −90) | A **traffic-management truck** with an arrow board and water-filled barriers across the northbound lanes (x 1…10); the **P_N** spawn is behind it (6, −86). The southbound lanes (x −10…−1) stay open as the **convoy lane** for `route_north`. Beyond z −92 is an `OUT_OF_BOUNDS` zone (D-040, respawn at `oob_respawn` spawns on the north sidewalks). Vista: Orchard continuing under the Skyway to a bend at z −200 (facades). |
| Orchard south (z 72) | A **stalled articulated bus** across the carriageway (x −8…10, z 64…66) and barriers on both sidewalks; **P_S** behind it (0, 68). Vista to z −250 under the Skyway (OOB beyond z 72). |
| Tannery west (x −80) | An articulated lorry across the road (x −76…−74) and barriers on the sidewalks; **P_W** behind (−78, 0). Vista: Tannery to x −300, the low sun at the end of it. |
| Underpass east (x 104, −5.0) | A **jack-knifed lorry** across the eastbound lanes (z 0…8, x 98…102), leaving the westbound lanes (z −8…0) as the **convoy lane** for `route_east`; **P_E** behind it (102, 4, −5.0). OOB beyond x 104. The cut walls (5 m) close the sides. |
| Rail palisades (x 64 / x 86) | 1.8 m steel palisade (bars, see-through, bullet-transparent); the tracks are dressing and not reachable (no gate on our side). |
| Rail lane north (z −90) | Palisade gate (P_NE ENTRY, breachable). **P_NE** behind it (60, −76) under a footbridge. |
| West / north neighbours | Warehouse facades with no openings at ground (x < −62); Tanner's Reach hoarding (2.4 m, solid, blocks LOS and bullets) except its three gates. |
| Ashby House, laundromat, tyre shop | Closed facades: Ashby's lobby doors locked (dressing glass, unbreakable), the laundromat shutter down, the tyre shop roller shutter down. Their roofs are not reachable (no stair; S4 is police-only). |
| Skyway deck (+9.0) | Concrete parapets 1.1 m; reachable only by police (P_SKY spawn island on the deck at z −84; one-way rappel links to the street, QC-89). No crew access. |
| Up | Open sky, low sun; the Skyway deck overhead along Orchard; every visible roof has a parapet and plant. |
| Far | Southfield streets in every direction (facades closing each vista), the Skyway curving away north and south. Nothing reachable sees the void. |

### Site plan
1 char = 2 m (x) and 1 row = 2 m (z). The origin is the junction centre (+x east, +z south), the
same as all coordinates in this doc. The plan comes from `tools/levelcheck/plans/rolling_thunder_site_ascii.py`
(G1; drafted for G0).

Legend:
- **Streets and structures:** `.` sidewalk; `:` Skyway deck edge (overhead, +9.0; drawn over the
  outer sidewalk column); `O` Skyway pier; `w` underpass ramp retaining wall (street level with a
  1.1 m parapet); `H` rail tracks (+1.2); `|` hoarding, palisade or yard wall; `g` gate; `K` closure
  vehicle.
- **Buildings:** `#` building shell (car park, diner); `%` neighbour building (dressing).
- **Construction site:** `F` concrete frame; `S` scaffold stair tower; `c` site cabins; `m`
  explosives magazine; `T` tower crane base; `M` Reyes's mixer; `X` junction signal controller;
  `b` bus shelter; `Q` clock pillar.
- **Gameplay markers:** `P` player spawns (plaza default, car park, underpass); `PN PS PW PE PNE
  PSKY` police spawn groups; `S1…S4` sniper perches; `E1…E3` escapes; `H1…H4` holdouts.

```
      -80  -70  -60  -50  -40  -30  -20  -10  0    10   20   30   40   50   60   70   80   90   100
  -92 %%%%%%%%%                        :.          .:                   |     |  H    H  |
      %%%%%%%%%                        :.  PSKY    .:                   |     |  H    H  |
  -88 %%%%%%%%%                        :.     KKKKK.:                   |     |  H    H  |
      %%%%%%%%%                        :.          .:                   |     |  H    H  |
  -84 %%%%%%%%%                        :.        PN.:                   |     |  H    H  |
      %%%%%%%%%                        :.          .:                   |     |  H    H  |
  -80 %%%%%%%%%                        :.          .:                   |     |  H    H  |
      %%%%%%%%%                        :.          .:                   |  PNE|  H    H  |
  -76 %%%%%%%%%                        :.          .:                   |     |  H    H  |
      %%%%%%%%%                        :.          .:                   |     |  H    H  |
  -72 %%%%%%%%%                        :.     O    .:                   |     |  H    H  |
      %%%%%%%%%                        :.     O    .:                   |     |  H    H  |
  -68 %%%%%%%%%                        :.          .:                   |     |  H    H  |
      %%%%%%%%%                        :. ORCHARD  .:                   |     |  H    H  |
  -64 %%%%%%%%%                        :.          .:                   |     |  H    H  |
      %%%%%%%%%                        :.          .:                   |     |  H    H  |
  -60 %%%%%%%%%                        :.          .:                   |     |  H    H  |
      %%%%%%%%%                        :.          .:                   |     |  H    H  |
  -56 %%%%%%%%% |||||||||||||||||||||||:.          .:                   |     |  H    H  |
      %%%%%%%%% | TANNER'S REACH SITE |:.          .:                   |     |  H    H  |
  -52 %%%%%%%%% |                 mm  |:.          .:                   |     |  H    H  |
      %%%%%%%%% |    FFFFFFFFFFFF mm  |:.          .: ##################|     |  H    H  |
  -48 %%%%%%%%% |    F          F     g:.          .: #         P      #|     |  H    H  |
      %%%%%%%%% |    F          F     g:.          .: # CAR PARK       #|     |  H    H  |
  -44 %%%%%%%%% |    F          F     g:.          .: #                #|     |  H    H  |
      %%%%%%%%% |    F    H3    F     g:.          .: #                #|     |  H    H  |
  -40 %%%%%%%%% |    F          F     |:.     O    .: #     E3         #|     |  H    H  |
      %%%%%%%%% |    F          F     |:.     O    .: #                #|     |  H    H  |
  -36 %%%%%%%%% |    F          F     |:.          .: #      H1        #|     |  H    H  |
      %%%%%%%%% |    F          F     |:.          .: #                #|     |  H    H  |
  -32 %%%%%%%%% |    FFFFFFFFFFFF     |:.          .: #                #|     |  H    H  |
      %%%%%%%%% |           SS        |:.          .: #  E1            #|     |  H    H  |
  -28 %%%%%%%%% |           SS  S3    |:.          .: #                #|     |  H    H  |
      %%%%%%%%% |cccccc     SS TT     |:.          .: #                #|     |  H    H  |
  -24 %%%%%%%%% |cccccc        TT     |:.          .: #                #|     |  H S2 H  |
      %%%%%%%%% |cccccc               |:.          .: #                #|     |  H    H  |
  -20 %%%%%%%%% |cccccc               |:.          .S1#                #|     |  H    H  |
      %%%%%%%%% |cccccc     MMMM      |:.          .: #                #|     |  H    H  |
  -16 %%%%%%%%% |           MMMM      g:.          .: ###   ############|     |  H    H  |
                |                    X|:.          .:          wwwwwwwwwwwwwwwwwwHwwwwHwwwwwwwwwwww
  -12 ..........||||||||||||ggg||||||||:.          .:............................H....H............
      .................................:.          .:............................H....H............
   -8   K                              :.          .:                            H    H
        K                              :.          .:                          UNDERPASS
   -4   K       TANNERY RD  W          :.          .:                            H    H    E2
        K                              :.          .:           RAMP 0>-5        H    H
    0 PWK                              :.          .:                            H    H        KK
        K                              :.          .:                            H H4 H        KKPE
    4   K                              :.          .:                            H    H        KK
        K                              :.          .:                            H    H        KK
    8 .................................:.          .:............................H....H.....P......
      .................................:.          .:............................H....H............
   12                     bbbbb        :.          .:          wwwwwwwwwwwwwww|wwHwwwwHww|wwwwwwwww
      %%%%%%%%%                        :.          .:##########%%%%%%%% %%%%%%|  H    H  |
   16 %%%%%%%%%                P      b:.          .:# DINER  #%%%%%%%% %%%%%%|  H    H  |
      %%%%%%%%%                       b:.          .:#        #%%%%%%%% %%%%%%|  H    H  |
   20 %%%%%%%%%        PLAZA      Q   b:.          .:#        #%%%%%%%% %%%%%%|  H    H  |
      %%%%%%%%%                       b:.          .:#   H2   #%LAUNDRY %TYRES|  H    H  |
   24 %%%%%%%%%                       b:.          .:#        #%%%%%%%% %%%%%%|  H    H  |
      %%%%%%%%%                        :.          .:#        #%%%%%%%% %%%%%%|  H    H  |
   28 %%%%%%%%%                        :.          .:#        #%%%%%%%% %%%%%%|  H    H  |
      %%%%%%%%% %%%%%%%%%%%%%%%%%%     :.     O    .:##########%%%%%%%% %%%%%%|  H    H  |
   32 %%%%%%%%% %%%%%%%%%%%%%%%%%%     :.     O    .:||||||||||         %%%%%%|  H    H  |
      %%%%%%%%% %%%%%%%%%%%%%%%%%%     :.          .:|        |         %%%%%%|  H    H  |
   36 %%%%%%%%% %%%%%%%%%%%%%%%S4%     :.          .:|        |               |  H    H  |
      %%%%%%%%% %%%%%%%%%%%%%%%%%%     :.          .:||||||||||               |  H    H  |
   40 %%%%%%%%% %ASHBY HSE%%%%%%%%     :.          .:                         |  H    H  |
      %%%%%%%%% %%%%%%%%%%%%%%%%%%     :.          .:                         |  H    H  |
   44 %%%%%%%%% %%%%%%%%%%%%%%%%%%     :. ORCHARD  .:                         |  H    H  |
      %%%%%%%%% %%%%%%%%%%%%%%%%%%     :.          .:                         |  H    H  |
   48 %%%%%%%%% %%%%%%%%%%%%%%%%%%     :.          .:                         |  H    H  |
      %%%%%%%%%                        :.          .:                         |  H    H  |
   52 %%%%%%%%%                        :.          .:                         |  H    H  |
      %%%%%%%%%                        :.          .:                         |  H    H  |
   56 %%%%%%%%%                        :.          .:                         |  H    H  |
      %%%%%%%%%                        :.          .:                         |  H    H  |
   60 %%%%%%%%%                        :.          .:                         |  H    H  |
      %%%%%%%%%                        :.     O    .:                         |  H    H  |
   64 %%%%%%%%%                        :. KKKKKKKKK.:                         |  H    H  |
      %%%%%%%%%                        :.          .:                         |  H    H  |
   68 %%%%%%%%%                        :.          .:                         |  H    H  |
      %%%%%%%%%                        :.     PS   .:                         |  H    H  |
```

## Floor plans
1 char = 1 m. Each character is a **grid point** (x = col, z = row) and lines are **wall centre
lines**: exterior 0.3–0.4 m, interior 0.15–0.2 m. Every building plan uses **local** coordinates
from its own NW corner. Conversions to site coordinates are given per building. The plans are
generated by `tools/levelcheck/plans/rolling_thunder_floors_ascii.py` (room rectangles in metres). As
with the Dockside Burn tool, its `--check` mode verifies that:
- the rooms tile each footprint;
- every door is on a wall;
- every room has a door;
- the stair and ramp arithmetic below holds.

Legend:
- **Walls and openings:** `#` exterior or core wall; `|`/`-` interior wall; `D` door (personnel
  0.9 m, service 1.0–1.2 m; diner front `DD` 1.8 m double); `W` window; `g` gate; `r` 1.1 m guard
  barrier (open car-park façade, ramp edges, slab-edge protection); `p` roof parapet 1.1 m.
- **Stairs and ramps:** `^v` U-stair; `vv`/`==` the scaffold stair seen from above; `A` ramp
  surface rising north (car park); `v` where a ramp arrives from below; `L` ladder (site frame, no
  bags; S10.1b).
- **Structure and fittings:** `o` column; `=` diner counter (0.9 m, service); `$` till; `S` small
  safe or pay station; `+` heli pad marking; `l` roof lighting column; `k` skip (`body_container`).
- **Gameplay:** `cc` parked cars (cover); `bb` booths; `tt` tables; `G` site-guard post; `C` site
  camera position (`camera` slot); `P` player spawn; `d` drop zone; `E` escape; `H1…H4` holdout
  centroid.
- **Site plans** reuse the site-plan letters: `S` scaffold stair tower, `T` crane base, `M`
  mixer, `X` signal controller, `%` magazine walls (`MG`); `L` there is the frame ladder and the
  thermite slot in C4.

**Vertical data** (`HeistMap.floor_heights = [-5.0, 0.0, 3.5, 7.0]`, `floor_names = ["Underpass",
"Street", "Upper", "Roof"]`, D-054). The list is ascending and contains 0.0 (D-040).
- **Underpass:** reached by the road and sidewalk ramps only (8.9°, walkable). It is listed so the
  HUD and the minimap name it (QC-87).
- **Upper:** the car park's Deck 2, the diner's first floor and the site frame's first-floor slab
  share +3.5.
- **Roof:** the car park roof (+7.0).
- The Skyway deck (+9.0), Ashby's roof (+14.4) and the rail bank (+1.2) are police-only and not
  listed (as Dockside's high-bay roof).

| Level | FFL | Ceiling | Floor-to-floor / slab | Notes |
|---|---|---|---|---|
| Underpass | −5.0 | open (bridge soffit −0.4: 4.6 m clear) | road ramp 5.0 over 32 m | exterior |
| Street | 0.0 | car park 2.7 (new purpose `car_park`, QC-87); booth/WC 2.6; car-park plant 2.7; diner dining 3.0, kitchen/store/office/WC 2.8; site cabins 2.6; frame underside 3.2 (exterior) | car park 3.5 (0.3 slab + 0.5 downstand beams); diner 3.5 (0.5–0.7 plenum + slab) | office 2.6–3.0 ✓, restaurant 3.0–4.5 ✓, kitchen 2.6–3.0 ✓ |
| Upper | 3.5 | car park 2.7; diner function room 3.0, others 2.8; frame slab open | car park 3.5 to the roof | ✓ |
| Roof | 7.0 | open; head houses 2.7 clear | — | parapet 1.1 m |
| Car park stairs A, B | 0.0 → 3.5 → 7.0 | U-stair, 2 flights × 10 risers @ 0.175 m per storey, tread 0.28 m (run 2.52 m), width 1.2 m | 20 risers = 3.5 ✓ per storey | landing every 10 ≤ 16 ✓; headroom ≥ 3.2 ✓ |
| Car park ramps R1 (0 → 3.5), R2 (3.5 → 7.0) | stacked in the strip x 27…33, z 6…30 (local) | 3.5 m rise over 24 m run = 8.3° (1:6.9) | — | walkable (< 40°); headroom between stacked ramps 3.5 − 0.3 = 3.2 m ✓; 1.1 m guards on both open sides |
| Diner stair SC | 0.0 → 3.5 | U-stair, 2 flights × 10 @ 0.175, tread 0.28, width 1.2 | 20 risers = 3.5 ✓ | as car park core fit |
| Site scaffold stair tower | 0.0 → 3.5 | 2 flights × 10 @ 0.175, tread 0.28, width 1.2, half landing 1.2 m; 4 × 6 m tower | 20 risers = 3.5 ✓ | 1.1 m guard rails + toe boards, mesh-clad tower |
| Site ladder | 0.0 → 3.5 | 3.5 m ladder at the frame's NW corner (`ladder` prefab) | — | no bags (S10.1b) |

**Stair core fit** (car park A and B, diner SC: 3.0 × 6.0 m centre lines, 0.15 m walls, so 2.7 × 5.7 m
clear):
- across: flights 1.2 + 0.2 well + 1.2 = 2.6 ≤ 2.7 ✓;
- along z: 1.30 floor landing + 2.52 run + 1.30 half landing = 5.12 ≤ 5.70 ✓.

As in Dockside Burn, the door sits on the level landing and never on a flight.

**Ramp fit (car park).** R1 rises north from z 30 (0.0) to z 6 (+3.5) and R2 rises north from z 30
(+3.5) to z 6 (+7.0), directly above R1. Each is 6.0 m wide.
- At every z the two ramp surfaces are exactly 3.5 m apart, so the clear height over R1 is
  3.5 − 0.3 = 3.2 m.
- Cars (and crew) arrive on each level at the north end and leave from the south end: a one-way
  loop.
- The south turning area (z 30…36, x 27…33) is open at ground and on Deck 2.

### Southfield Park & Ride: Ground (FFL 0.0)
Local origin = the car park's NW corner (site 16, −50): **site x = local x + 16, site z = local z − 50**.
```
      0123456789012345678901234567890123456
    0 #######rrrrrrrrrrrrrrrrrrrrrrrrrrrrr#
      #ST#LF#                             #
    2 #^v#  #                             #
      #^v#DD#                             #
    4 D^v#   P P                          #
      #  D                                #
    6 #### o     o    o    o     r     r  #
      r                          r AAA r  #
    8 r           cc             r     r  #
      r                          r AAA r  #
   10 r                          r     r  #
      r                          r AAA r  #
   12 rcc  o     o    o    o     r     r  #
      r                          r AAA r  #
   14 r                cc        r     r  #
      r                          r AAA r  D
   16 r                          r     r  #
      r                          r AAA r  #
   18 r    o     o    o    o     r     r  #
      r                          r AAA r  #
   20 r      E1                  r     r  #
      r                          r AAA r  #
   22 r           cc             r     r  #
      r                          r AAA r  #
   24 rcc  o     o    o    o     r     r  #
      r                          r AAA r  #
   26 r                          r     r  #
      r                          r AAA r  #
   28 r                          r     r  #
      r        S                 r AAA r  #
   30 ##W###     o  ###D####     r     r###
      #    #        #      #           DSB#
   32 #AB  #     #D##      #           #^v#
      W    D     #  # PL   #           #^v#
   34 #    #     #WC#      #           #^v#
      #    #  _  #  #      #           #  #
   36 ######     ###########rrrrrrrrrrrrrrr
```

Ground notes:
- **Façades:**
  - The north and west façades are **open** behind a 1.1 m steel crash barrier with mesh infill
    (`r`). It is a throw spot from the Orchard sidewalk into the west bays.
  - The south façade is open east of the plant room.
  - The east façade (rail side) is a solid fire wall with one push-bar door (local 36, 15).
- **Entrance and pedestrian doors:**
  - The **entrance** (local x 6…10, site x 22…26) has a barrier arm `_` and a 2.4 m height bar.
  - Stair A has a pedestrian door onto the Orchard sidewalk (local 0, 4) and one onto the lobby
    (local 3, 5).
  - The **lift** LF serves 0.0, 3.5 and 7.0 (`bag_lift`, 2 bags, 8 s per floor).
- **Attendant booth AB:** windows N and W, plus the **pay station** `S` (local 9, 29: `safe` SMALL,
  `methods [saw, drill, c4]`, `small_loot` ×2).
- **Escape and ramp:** E1 (the escape van) waits in the west aisle. The ramp R1 foot is at the south
  turning area.

### Southfield Park & Ride: Deck 2 (FFL 3.5; holdout H1)
```
      0123456789012345678901234567890123456
    0 #######rrrrrrrrrrrrrrrrrrrrrrrrrrrrr#
      #ST#LF#                             #
    2 #^v#  #                             #
      #^v#DD#                             #
    4 #^v#                         v      #
      #  D                                #
    6 #### o     o    o    o     r     r  #
      r                          r AAA r  #
    8 r           cc             r     r  #
      r                          r AAA r  #
   10 r                          r     r  #
      r                          r AAA r  #
   12 r    o     o    o    o     r     r  #
      r                          r AAA r  #
   14 r       H1                 r     r  #
      r                          r AAA r  #
   16 rcc                        r     r  #
      r                          r AAA r  #
   18 r    o     o    o    o     r     r  #
      r                          r AAA r  #
   20 r                cc        r     r  #
      r                          r AAA r  #
   22 r                          r     r  #
      r                          r AAA r  #
   24 r    o     o    o    o     r     r  #
      r                          r AAA r  #
   26 r                          r     r  #
      r                          r AAA r  #
   28 r                          r     r  #
      r                          r AAA r  #
   30 r    o     o    o    o     r     r###
      r                                DSB#
   32 r                                #^v#
      r            d        cc         #^v#
   34 r                                #^v#
      r                                #  #
   36 rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr####
```

Deck 2 notes:
- **Façades:**
  - The whole north, west and south façade is a 1.1 m crash barrier with mesh infill (`r`, a guard
    with a handrail top, QC-33): **the holdout's firing line**.
  - West: the Orchard north arm and the `route_north` queue, at 22–40 m.
  - South: the forecourt and the east-arm queue, 10–20 m away and 3.5–8 m below.
- **Ramps:** R1 arrives at `v` (north end of the strip), and R2 leaves from the south turning area.
- **Drop zone:** `d` is `pp_drop_carpark` (south bays, by stair B).
- **Bags:** they go down by the lift, the ramps, or a throw over the south barrier to the forecourt
  (3.5 m drop) for E1.

### Southfield Park & Ride: Roof (FFL 7.0; escape E3)
```
      0123456789012345678901234567890123456
    0 #######pppppppppppppppppppppppppppppp
      #HH#LF#                             p
    2 #^v#  #                             p
      #^v#D##                             p
    4 #^v#   P P                   v      p
      #  D                                p
    6 #### l                     l     r  p
      p                          r AAA r  p
    8 p                          r     r  p
      p         +++++++++++++    r AAA r  p
   10 p         +           +    r     r  p
      p         +           +    r AAA r  p
   12 p         +           +    r     r  p
      p         +  HELI     +    r AAA r  p
   14 p         +           +    r     r  p
      p         +   E3      +    r AAA r  p
   16 p         +           +    r     r  p
      p         +  PAD      +    r AAA r  p
   18 p         +           +    r     r  p
      p         +           +    r AAA r  p
   20 p         +           +    r     r  p
      p         +           +    r AAA r  p
   22 p         +           +    r     r  p
      p         +++++++++++++    r AAA r  p
   24 p                          r     r  p
      p                          r AAA r  p
   26 p                          r     r  p
      p                          r AAA r  p
   28 p                          r     r  p
      p                          r AAA r  p
   30 p    l               l     r     ####
      p                                DHH#
   32 p                                #^v#
      p                                #^v#
   34 p                                #^v#
      p                                #  #
   36 ppppppppppppppppppppppppppppppppp####
```

Roof notes:
- **Parapet:** 1.1 m concrete (`p`) all round.
- **Heli pad:** E3 is a 12 × 14 m pad painted by Reyes's people (`+`). Lighting columns `l` stand
  at the bay corners, clear of the pad.
- **Head houses:** HH (stair A) is the `perch_carpark_roof` slot: its roof door is unlocked;
  otherwise it is LOCKPICK 8 s. HH (stair B) is always unlocked (it is the escape route).
- **Lift and ramp:** the lift tops out here, and R2 arrives at `v`.
- **Player perch:** it sees S1 (26 m) and S2 (41 m), all of the east arm and the north arm beyond
  the Skyway's edge.

### Halfway Diner: Ground (FFL 0.0) and back yard
Local origin = the diner's NW corner (site 14, 14): **site x = local x + 14, site z = local z + 14**.
```
      012345678901234567890
    0 #WW#DDWWWWWW#|##W#D##
      #DR DINING   |K KITCH
    2 W         =  |      #
      W         =  |      #
    4 W bb  cc  =$ | kk   #
      #         =  |      #
    6 #         =  |      #
      #         =  |      #
    8 D bb  cc  =  ---D----
      #         =  DBC    #
   10 W      H2 =  ---D----
      #            |ST  |E#
   12 ---|D|--|--D-|    -D#
      #W1DR|SC|OF  |      #
   14 #  | |^v|    |      #
      ---- D^v| S  |      #
   16 #W2D |^v|    |      #
      #  | |  |    |      #
   18 |##|D|##|####|##D###|
      |                   |
   20 |             BB    |
      | YARD              |
   22 g                   |
      |                   g
   24 |                   |
      |                   |
   26 |||||||||||||||||||||
```

### Halfway Diner: Upper (FFL 3.5; holdout H2)
```
      012345678901234567890
    0 #WW###WWWWWW#|##WW###
      #U1 FUNCTION |U2 STOR
    2 W            |      #
      W            |      #
    4 W            |      #
      #            D      #
    6 #    H2      |      #
      #            |      #
    8 W            |      #
      W tt    tt   |      #
   10 W            --------
      #            D      #
   12 ---|D|--|--D-|U3 DRY#
      #U4DR|SC|U5  |      #
   14 #  | |^v|    |      #
      ---- D^v|    |      #
   16 #  | |^v|    |      #
      #  | |  |    |      #
   18 ###|#|##|####|#######
```

Diner notes:
- **Doors:**
  - The **front double door** (local 4–5, 0) faces Tannery and the junction. The **side door**
    (0, 8) opens onto Orchard. The kitchen's delivery door (18, 0) opens onto Tannery.
  - The rear lobby R has the push-bar fire exit (4, 18), and the store has a service door (16, 18).
    Both open into the **yard**.
  - The yard has gates W (onto Orchard, 0, 22) and E (into the laundromat yard and the alley,
    20, 23).
- **Windows:** the dining room and the function room have **shopfront glazing** N and W (sill 0.8 m;
  breakable: `window` prefabs).
- **Upstairs:** U1 is the owners' function room, used for parties and closed today. It has the same
  two glazed faces, 3.5 m above the junction. **The holdout's guns face the junction and the east
  arm.**
- **Loot:** the dining-room till `$` (`small_loot`), and the office safe `S` (`safe` SMALL,
  `methods [drill, saw, c4]`, `small_loot` ×2).
- **Body hiding:** the yard bins `BB` are a `body_container` (capacity 2) for a marshal or guard
  body in the setup.

### Tanner's Reach construction site: Street (FFL 0.0)
Local origin = the hoarding's NW corner (site −60, −56): **site x = local x − 60, site z = local z − 56**.
```
      01234567890123456789012345678901234567890123456
    0 |||||||||||||||||||||||||||||||||||||||||||||||
      |                                             |
    2 |             pile caps, rebar                |
      |                                             |
    4 |                                   %%%%%     |
      |                                   %MG %     |
    6 |         L     o     o     o     o %   %     |
      |                                   %%D%%     |
    8 |           FG FRAME (under slab +3.5)        |
      |                                             |
   10 |                                             g
      |         o     o     o     o     o           g
   12 |                             G               g
      |                                             g
   14 |                                             g
      |             formwork stacks                 g
   16 |         o     o     o     o     o           |
      |                                             |
   18 |                   H3                        |
      |                                             |
   20 |                                       G     |
      |         o     o     o     o     o           |
   22 |                                             |
      |                                             |
   24 |                                             |
      |                                   C         |
   26 |         o     o     o SSSSS     o           |
      |                       S   S                 |
   28 |  C                    S^v S                 |
      |                       S^v S                 |
   30 | ##W|#W|##|###         S^v S TTTTT           |
      | #C1|C2|C3|C4#         S   S T   T           |
   32 | #  |  |  |  #         SSSSS T   T           |
      | #  |  |  |  #               T   T           |
   34 | #  |  |  |  #               TTTTT           |
      | #  |  |  | L#                               |
   36 | #  |  |  |  #                               |
      | #  |  |  |  #  G                            |
   38 | #  |  |  |  #         MMMMMMMM              |
      | #D#|D#|D#|D##         MMMMMMMM              |
   40 |                       MMMMMMMM        d     g
      |               k       MMMMMMMM              |
   42 |                                             |
      |                                           X |
   44 |                                             |
      ||||||||||||||||||||||||gggggg|||||||||||||||||
```

### Tanner's Reach construction site: Upper (the frame's first-floor slab, FFL 3.5; holdout H3)
```
      01234567890123456789012345678901234567890123456
    6           Lrrrrrorrrrrorrrrrorrrrro
                r                       r
    8           r                       r
                r F1 SLAB +3.5          r
   10           r                       r
                o     o     o     o     o
   12           r                       r
                r  starter bars         r
   14           r                       r
                r                       r
   16           o     o     o     o     o
                r                       r
   18           r         H3            r
                r                       r
   20           r                       r
                o  P Po     o     o     o
   22           r                 pallets
                r                       r
   24           r                       r
                r                       r
   26           orrrrrorrrrrorS  SSrrrrro
                              S   S
   28                         Svv S
                              S== S
   30                         S   S
                              S   S
   32                         SSSSS
```

Site notes:
- **The frame (F, local 10…34 × 6…26, 24 × 20 m):**
  - It is a cast first-floor slab on a 6 × 5 m column grid, with no walls.
  - Under the slab, ground is a covered yard (3.2 m clear; formwork and rebar stacks as cover).
  - On the slab: starter bars, pallets of blocks, a mortar mixer.
  - Every open slab edge has **edge protection**: a 1.1 m double guard rail plus a toe board and
    mesh (`r`; QC-33 guard ≥ 1.0 m).
  - It is reached by the **scaffold stair tower** (S, bags allowed) and the **ladder** (L, no
    bags).
- **Cabins (C1…C4, single-storey 3 × 9 m units):** each has a door S and windows N.
  - C1: site office.
  - C2: welfare / mess.
  - C3: WCs.
  - C4: tool store (LOCKPICK 8 s). In `stores_thermite`/`stores_both` it holds the **thermite bag**
    (`loot.thermite`; a thermic-lance kit in the fiction), at `L`.
- **Magazine (MG):** a 3 × 2.4 m steel explosives store with a padlocked door (`padlock`: lockpick
  8 s or the hand saw; G.SAW_TARGET). In `stores_c4`/`stores_both` it holds **two boxes of
  breaking charges** (`item.c4` ×4 each, QC-84). One box opens one truck by C4.
- **Signal controller (X):** a street cabinet in the hoarding's SE corner at local (44, 43), site
  (−16, −13).
  - Its door is a `padlock` (`ctrl_locked`: lockpick 8 s or saw; `ctrl_open`: ajar).
  - Inside is a `hack_terminal` "signal rig": `duration_s` 15, `interruptions` 0–1 (◇), objective
    `[signals]`, silent.
  - It sits 2 m from the Orchard man-gate: a pedestrian on the sidewalk can see through the gate's
    mesh panel. That is the setup's tension point.
- **Crane and mixer:**
  - Crane base T: the mast ladder is caged and locked (dressing); the cab is S3 (police only,
    rare).
  - Mixer M is Reyes's ram truck: dressing until it moves (QC-82).
- **Site markers:**
  - `k` is the skip (`body_container`, capacity 2).
  - `G` are the guard posts (`guard_post`); `C` are the camera slots (`camera`).
  - `d` is `pp_drop_site`.

## Room list
Sizes are between wall centre lines (m).

| id | purpose (`RoomVolume.purpose`) | size m | ceiling m | kit | notes |
|---|---|---|---|---|---|
| CP-G | car_park (QC-87; else `garage` with a 2.7 override) | 36 × 36 less cores/booth/plant | 2.7 | `car_park_deck` | Ground: 2 aisles, 5 m bays, ramp foot, E1 van in the west aisle. Concrete columns, painted bay lines, wheel stops, pay signs, fire extinguisher points, sodium-white LED battens. |
| CP-2 | car_park | 36 × 36 less cores | 2.7 | `car_park_deck` (layout differs) | Deck 2: H1. Parked cars (cover, 12–18 per deck), the barrier façade, the stair-B drop zone. |
| CP-R | roof | 36 × 36 | open | `car_park_roof` | Heli pad, lighting columns, 4 parked cars on the east half, head houses. |
| STA, STB | stair | 3 × 6 | open | — | `ST`/`SB` on the plans; U-stairs 0 → 3.5 → 7.0; head houses on the roof. STA has a street door to Orchard. |
| LF | elevator | 3 × 3 | — | — | `bag_lift` (`goods_lift`: powered/dead), 3 landings (0.0/3.5/7.0), 2 bags, 8 s per floor. |
| AB | office (attendant booth) | 5 × 6 | 2.6 | `attendant_booth` | Desk, CCTV monitor (dressing), kettle, heater, barrier controls; windows N and W. The attendant (civilian). |
| CWC | restroom | 3 × 4 | 2.6 | `restroom_single` | Staff WC off the south aisle. |
| CPL | plant | 7 × 6 | 2.7 | `plant_carpark` | Sprinkler pump set, main electrical board, ventilation fans; the lift breaker (5 s with `lift_dead`). |
| DR | restaurant (dining room) | 13 × 12 | 3.0 | `diner_dining` | Booths `bb` along the glazing, tables, counter (0.9 m) with stools, till, pie case, jukebox (dressing), neon. Civilians cower in the booths (`cower_seated`). |
| K | kitchen | 7 × 8 | 2.8 | `kitchen_commercial` | Griddle line, fryers, prep tables, walk-in fridge door (dressing), pass to the counter; delivery door N. |
| BC | corridor (service) | 7 × 2 | 2.8 | `corridor_service` | Behind-the-counter link: DR, K, ST. |
| ST | storage (dry store) | 7 × 8 less E | 2.8 | `storage_receiving` | Shelving, sacks, crates; service door S to the yard. |
| E | electrical | 2 × 2 | 2.8 | `electrical_closet` | Fused board, meters. |
| W1, W2 | restroom | 3 × 3 each | 2.8 | `restroom_single` | Customer WCs off the rear lobby. |
| R | corridor (rear lobby) | 2 × 6 | 2.8 | `corridor_service` | From DR to the fire exit S; stair door. |
| SC | stair | 3 × 6 | open | — | 0 → 3.5. |
| OF | office | 5 × 6 | 2.8 | `office_manager` | Desk, safe `S`, rota board, CCTV recorder (dressing). Door to the back of the counter. |
| U1 | restaurant (function room) | 13 × 12 | 3.0 | `function_room` | Stacked chairs, folded tables `tt`, a small bar (dressing), bunting. The holdout's firing positions at the glazing. |
| U2 | storage | 7 × 10 | 2.8 | `storage_archive` | Old furniture, boxes of menus, Christmas decorations. |
| U3 | storage (dry goods overflow) | 7 × 8 | 2.8 | `storage_receiving` | Shelving. |
| U4 | restroom | 3 × 3 | 2.8 | `restroom_single` | WC for the function room. |
| J | janitor | 3 × 3 | 2.8 | `janitor_closet` | Mop sink, buckets (U-level, under U4's partition). |
| U5 | staff_room | 5 × 6 | 2.8 | `break_room` | Staff break room: fridge, table + chairs, counter + sink, microwave, coffee, bulletin board. |
| YD | exterior (diner yard) | 20 × 8 | — | `exterior_yard_small` | Bins (`body_container`), crates, waste oil, the staff smoking chair. |
| C1 | office (site office) | 3 × 9 | 2.6 | `site_office` | Plan table, drawings on the wall, kettle, hard-hat rack, the site's radio. |
| C2 | break_room (welfare) | 3 × 9 | 2.6 | `break_room` | Mess table, microwave, fridge, sink, notice board. |
| C3 | restroom | 3 × 9 | 2.6 | `site_wc` | 3 WC cubicles, wash trough. |
| C4 | storage (tool store) | 3 × 9 | 2.6 | `site_tool_store` | Racks of tools, gas bottles (dressing), the thermite bag slot. LOCKPICK door. |
| MG | — (a container prop, no RoomVolume) | 3 × 2.4 | 2.2 inside | — | The steel explosives magazine; padlocked door. Its 2.2 m interior is below every room band, so it is a prop, not a room. The C4 boxes are `item_pickup`s (QC-84) reached from the open door's UsePoint. |
| FG | exterior (frame, ground) | 24 × 20 | 3.2 (slab soffit) | `site_frame_ground` | Columns, formwork stacks, rebar bundles, a dumper truck (cover). |
| F1 | exterior (frame slab +3.5) | 24 × 20 | open | `site_frame_slab` | Edge protection, block pallets, starter bars, a mortar mixer. H3. |
| X1 | exterior (Orchard Ave + junction + Tannery west) | — | — | `exterior_street` | Signals on gantries, lamp posts, parked cars, bins, a newsstand, Skyway piers. |
| X2 | exterior (east arm, ramp, underpass, cut) | 20 + 32 + 18 + 20 × 22 | — (underpass soffit 4.6) | `exterior_underpass` | Retaining walls with drainage channels, height bar, underpass fluorescents, graffiti-free (Southfield council keeps it painted), E2. |
| X3 | exterior (plaza + bus interchange) | 46 × 19 | — | `exterior_plaza` | Bus shelters with benches (`cower_seated` spots), the clock pillar, trees in grates, cycle racks, a ticket machine. |
| X4 | exterior (Tanner's Reach yard) | 46 × 45 less buildings | — | `exterior_site` | Hoarding, crane base, skip, cabins' steps, site lighting masts, the mixer. |
| X5 | exterior (rail lane) | 12 × 76 | — | `exterior_lane` | Palisade, cable troughs, a rail maintenance van (cover). |
| X6 | exterior (car park forecourt, x 34…52, z −14…−11) | 18 × 3 | — | `exterior_street` | Railing over the ramp drop (1.1 m), bollards; throw spot down into the trench. |

Support-space check (level_standards §2.2):
- **Car park:** there is one attendant. Booth AB serves as the staff space (kettle), with WC CWC
  and plant CPL (electrical + sprinklers). Two stair cores are required for 3 levels, and there are
  2 ✓.
- **Diner:** restrooms W1/W2 (ground, customers) and U4 (upper) ✓; break room U5 ✓; janitor J ✓;
  electrical E ✓.
  - The loading/back entrance is the kitchen delivery door plus the yard service door ✓.
  - The diner has one stair for its 2 floors ✓. The fire exit is R's push-bar door to the yard ✓.
- **Site:** welfare C2 ✓, WCs C3 ✓, office C1 ✓, store C4 ✓. Electrical is a temporary
  distribution board on the hoarding (dressing).

## Circulation
- **Public (setup phase):**
  - **Pedestrians** (`civilian`, `walk_text` clip from characters.md v1.9) walk PatrolPoints
    tagged `civilian` along all four sidewalks, through the plaza and down the underpass sidewalks.
    ≥ 3 loop options per graph.
  - A **bus queue** (2–4) sits or stands at the plaza shelters.
  - **Diner customers** (2–5) sit in the booths, and a **waitress** and a **cook** work the
    counter and the kitchen.
  - The **car-park attendant** stays in AB.
  - Cars are parked (static props; no traffic AI).
  - The civilians cannot detect a crew member in casing mode (S1.1). A **masked** crew member in
    their view makes them panic: they flee, and a caller phones the police (alarm, S7).
- **Restricted:** the site behind its hoarding (the guard and camera) and the diner's back of
  house. The car park booth and plant room. The rail lane.
- **Site guard (Halden Security, `security_officer`, pager):** one `site` PatrolGraph with ≥ 3
  loops per post (heist_map §4):
  - `post_site_gate`: the Orchard gates ↔ the controller corner ↔ the Tannery gate (the mixer:
    pause `look`) ↔ the skip;
  - `post_site_frame`: FG aisles → the scaffold stair → F1 slab edge (pause `look` over Orchard) →
    back;
  - `post_site_cabins`: C1 ↔ C2 (coffee pause, `sit`) ↔ the magazine ↔ the crane base.
- **Route marshal (Vaultline `armored_car_crew`, pager; scripted spawn):** at `convoy_eta_s` − 75 s
  (− 90 with `marshal_early`), a Vaultline scout car pulls up at the stop line of the convoy's arm.
  - The marshal gets out and walks one of three checks (`marshal_walk`), radio on, until the convoy
    arrives:
    - `marshal_carpark`: the forecourt, the entrance and stair A;
    - `marshal_site_corner`: the Orchard sidewalk past the man-gate and the controller;
    - `marshal_plaza`: the shelters and the clock.
  - He sees by guard rules. If he sees a masked crew member, the radio goes out and it is an
    **early alarm**.
  - If he is killed or dominated, his pager goes off (S5). His car is cover later.
- **Beat cop (`cop_on_scene`, `patrol_officer` in stealth):** stands at the plaza or the diner
  corner. He detects like a guard but has no pager. If he sees a masked crew member, it is an early
  alarm.
- **Loud:** civilians flee to the four closures (`civ_flee` exits, QC-88).
  - Those who cannot reach an exit cower: diner customers in the booths (`cower_seated`); bus
    queuers on the shelter benches (`cower_seated`); others against walls (`cower_stand`, placed
    0.21 m in front of a wall per characters.md v1.9: the diner walls, the car-park cores, the
    shelter backs, Ashby's facade).
  - They are the heist's **hostages** (L5.3, L2.10) and count as civilian kills.
- **Crew:** from the spawn to the ambush positions, then to the convoy queue and back to the
  escape (see Loot path).
- **Police lanes** (after `police_delay_s`; spawns and entries in Loud):
  - **N:** Orchard north under the Skyway → the north-arm queue, the car park west face, stair A.
  - **S:** Orchard south → the plaza, the diner front, the junction.
  - **W:** Tannery west, out of the low sun → the site's Tannery gate, the plaza, the junction.
  - **E:** the underpass (−5.0) → up the ramp → the east-arm queue, the forecourt.
  - **NE:** the rail lane → the car park fire door and the forecourt.
  - **Skyway:** rappel to the Orchard sidewalks at the junction span.

### Civilian, guard and convoy roster (spawn data)

| NPC | Count | Presence | Spawn tags | Idle activity | PatrolPoint tags |
|---|---|---|---|---|---|
| Pedestrian | `civilians` scalar (6/9/12) | always | `civ_street` (sidewalks ×12, plaza ×4) | `walk_text` (D clip), `browse` at the newsstand | `civilian`, `civ_street` |
| Bus queue | 2–4 | always | `civ_bus` (shelters) | sit (shelter benches) | — |
| Diner customer | 2–5 | always | `civ_diner` (booths) | sit, eat | — |
| Diner staff (waitress, cook) | 2 | always | `staff_diner` | counter wipe / cook | `staff`, `staff_diner` |
| Car-park attendant | 1 | always | `staff_booth` | sit (desk) | — |
| Site guard (Halden, `security_officer`) | 1 (Routine/Tense), 2 (Hazardous+) | `guard_post` = `post_site_*` | `guard_site_gate`, `guard_site_frame`, `guard_site_cabins` | `smoke` (gate), `sit` (C2) | `guard`, `site` |
| Beat cop (`patrol_officer`) | 0–1 | `cop_on_scene` | `cop_plaza`, `cop_diner` | `look` | — |
| Route marshal (Vaultline, `armored_car_crew_b`) | 1 | scripted, ETA − 75 s | `scripted` + `vl_marshal` | `radio_call` | `vl_marshal`, `marshal_*` |
| Escort (lead car) | 2 | at the stop (QC-83) | `convoy_lead` (seated) | seated | — |
| Vaultline crew (per truck: driver + custodian) | 2 × trucks | at the stop | `convoy_t1`, `convoy_t2`, `convoy_t3` (seated, armoured cab) | seated | — |
| Escort (rear car) | 2–3 | at the stop | `convoy_rear` (seated) | seated | — |
| Police | director | after `police_delay_s` | POLICE spawns `police_n`, `police_s`, `police_w`, `police_e`, `police_ne`, `police_sky` | — | — |

**Convoy units per difficulty** (escort roles are ENV D's `convoy_escort` cast: `patrol_officer`,
`tac_light`, `tac_heavy` plus faction reskins; Vaultline crew are `armored_car_crew` /
`armored_car_crew_b` on `enemy.security_officer`, QC-83):

| Difficulty | Lead escort | Trucks (weights 2/3) | Vaultline crew | Rear escort | `police_delay_s` weights 45/60/90 | Perches active |
|---|---|---|---|---|---|---|
| Routine | patrol car: 2 Patrol Officers | 0.7 / 0.3 | 4–6 | patrol car: 2 Patrol Officers | 0.1 / 0.3 / 0.6 | S1, S2 |
| Tense | as Routine | 0.7 / 0.3 | 4–6 | as Routine | 0.2 / 0.4 / 0.4 | S1, S2 |
| Hazardous | SUV: 2 TAC Light | 0.4 / 0.6 | 4–6 | SUV: 2 TAC Light + 1 TAC Heavy | 0.3 / 0.5 / 0.2 | + S4 |
| Brutal | as Hazardous (FRD) | 0.4 / 0.6 | 4–6 | as Hazardous (FRD) | 0.5 / 0.4 / 0.1 | + S4 (+ S3 `crane_sniper`) |
| Lethal | as Hazardous (Sentinel) | 0.2 / 0.8 | 4–6 | + `armored_escort` Wrecker (rare) | 0.7 / 0.3 / 0 | as Brutal |
| Cataclysm | as Hazardous (Zero) | 0.2 / 0.8 | 4–6 | as Lethal | 1 / 0 / 0 | as Brutal |

**Enemy cap:** convoy units count against `DifficultyDef.max_active_enemies`. The director's police
quota is reduced by the convoy units alive, as D-064 Q5 did for the cartel. ENV A's existing rule
applies (QC-83).

## Convoy
- **Composition** (in driving order): a lead escort car (5 m), then Truck 1 (always a **cash van**,
  `vl_cash`, 7.5 m), Truck 2 (always a **bullion truck**, `vl_bullion`, 9 m), Truck 3 (with
  `trucks_3`: cash or bullion by `cargo_t3`, 7.5/9 m), then the rear escort car (5 m). The gaps are
  3 m.
- **Routes** (`convoy_route`):
  - `route_north`: southbound down **Orchard Avenue** under the Skyway, in the west lanes
    (x −6), through the north closure's convoy lane.
    - **Clean stop:** a queue from the north stop line (z −14) back to z −52 (2 trucks) or
      z −63 (3 trucks).
      - Lead car z −16…−21.
      - T1 z −24…−31.5 (rear doors north).
      - T2 z −34.5…−43.5.
      - T3 z −46.5…−55.5.
      - Rear car z −58.5…−63.5.
    - The whole queue is **under the Skyway deck** (shaded, out of S1's view).
  - `route_east`: westbound up out of the **Tannery underpass**, in the north lanes (z −4), through
    the east closure's convoy lane.
    - **Clean stop:** a queue from the east stop line (x 14) back along the ramp.
      - Lead car x 16…21.
      - T1 x 24…31.5 at 0.0 (rear doors east).
      - T2 x 34.5…43.5, the start of the ramp (−0.1…−1.5 m).
      - T3 x 46.5…55.5 (−2.0…−3.4).
      - Rear car x 58.5…63.5 (−3.8…−4.6).
    - The rear of the queue is **in the trench** between the retaining walls: the car park
      forecourt and the diner look down on it, and S2 looks along it.
  - **Crash stops** (`stop_crash_north` / `stop_crash_east`): Reyes T-bones the lead car in the
    junction centre (car at (−2, 2) or (4, −2)). The trucks jam skewed behind it.
    - North: T1 (−6, −8…−16), T2 (−5, −19…−28), T3 (−5, −31…−39), rear car (−6, −42…−47).
    - East: T1 x 9…17, T2 x 20…29, T3 x 32…40, rear car x 43…48, all within 1.1 m of z −4 and
      yawed 10–25°.
    - The mixer ends up across the junction: **hard cover in the middle of the arena**.
- **The four layouts** (two routes × clean/crash) are `ConvoyLayout` marker sets under
  `Gameplay/Convoy/<route>/<clean|crash>`. They are not VariantSlots, because clean or crash is
  decided at runtime.
  - The resolver keeps only the active route's sets.
  - The mission places each vehicle prefab at its marker after the drive-in. The drive-in is a
    `convoy_vehicle` mover along a Path3D from the closure to the marker, 10 m/s, braking over
    the last 12 m (QC-82).
  - **The validator tests all four layouts** as pseudo-variants for reachability and the walkthrough
    (QC-87, my side).
- **Timing:**
  - The convoy is in sight at ETA − 20 s: Mercer and Reyes call it, and it shows on the HUD
    marker.
  - It reaches the stop line at ETA.
  - Clean stop: stop + 3 s, the mixer moves; stop + 8 s, the window ends.
  - Crash stop: the impact is the alarm.
- **After the stop the vehicles are static:**
  - They are **hard cover** (trucks: hard all round; escort cars: soft through the glass, hard
    on the engine block) and navmesh obstacles (carved, QC-82).
  - Escort cars burn out under explosives (dressing).
  - They never move again. The trucks cannot reverse, because the rear car blocks them.

## Sightlines
- **The junction is the arena:** 20 × 16 m of open carriageway under the green girder.
  - Its cover is the Skyway piers in the median (2 × 3 m concrete; the nearest at z −40 and 30,
    so the junction span itself is pier-free), the signal gantries' bases, parked cars, the
    newsstand, the bus shelters, and **the convoy itself** once stopped.
  - The mixer (crash or clean) is the biggest single cover piece.
- **The low sun:** it shines straight down Tannery from the west at 9°.
  - A crew member facing west (toward P_W and the site's Tannery gate) looks into glare: bloom and
    lens flare from the LUT, and police from the west are backlit silhouettes.
  - Facing east, everything is lit. The underpass mouth is a dark hole against bright retaining
    walls.
  - This is a deliberate readability tradeoff (style guide §7: readability first). The glare is a
    post-process **bloom** only, never a gameplay blind.
- **North arm (under the Skyway):** shade, with sodium tubes on the girder.
  - From Deck 2's west barrier (H1) the queue is 22–40 m away and fully visible; from the site
    frame slab (H3) across Orchard, 20–45 m.
  - The Skyway deck (S1, P_SKY) **cannot** see under itself: the `route_north` queue is the
    sniper-safe stop.
- **East arm and trench:**
  - From the forecourt railing and the Deck 2 south barrier, the queue is 3–20 m away and up to 8 m
    below: a plunging field of fire into the trench.
  - From the diner's U1 glazing (H2) it is 12–45 m.
  - From the underpass mouth (H4) the whole trench is a straight 50 m lane.
  - S2 (rail gantry) looks straight along the trench from the east.
- **The site:** the 2.4 m solid hoarding blocks every street view at eye height.
  - Only the frame slab (+3.5) and the crane see out.
  - Inside, the frame's columns and the formwork stacks give a short-range cover maze.
  - The controller corner is seen from the Orchard sidewalk through the man-gate's mesh panel
    (1.2 × 1.0 m). That is the setup's exposure.
- **The underpass:** 18 m long and 4.6 m high, lit by fluorescent tubes.
  - From the west mouth, the whole ramp and the junction are visible up a slope.
  - From the east cut, P_E is only 27 m away behind the lorry.

**Sniper lanes (Longshot, L4.7: red laser, 1.2 s aim lock, bypasses armor gating; damage halved
beyond 30 m except on Cataclysm):**

| Perch | Position (x, z, y) | Sees | Distance to the bag route | Blind to |
|---|---|---|---|---|
| **S1** Skyway east parapet | (12, −20, +10.1) | the east arm and the whole east-arm queue, the car park west + south faces and Deck 2's west bays, the forecourt, the diner front and U1 glazing (35 m), the plaza east half | car park entrance 13 m, E1 path 15–20 m, east T1 22 m, diner door 36 m | **the whole north arm under the deck** (it is on top of it), the site interior below the frame slab, the underpass |
| **S2** rail signal gantry | (75, −24, +7.5) | the trench and the underpass west mouth (looking SW along it), the forecourt, the car park east fire door and stair B, the rail lane | E2 path in the trench 20–45 m, east T3 31 m, forecourt 34 m | the junction (the car park blocks it), the north arm, the plaza |
| **S3** crane cab (rare `crane_sniper`, Brutal+) | (−28, −24, +30) | everything outside except under the Skyway deck: the site, the plaza, the junction edges, the car park roof (E3, 61 m) | E3 61 m, the site 10–30 m | the north arm (under the deck), the underpass |
| **S4** Ashby House roof (Hazardous+) | (−30, 36, +15.5) | the plaza, the junction from the SW, Orchard south, the diner front | plaza spawn 20 m, junction 47 m | the east trench, the car park interior, the north arm |

The perches are `TacticalPoint` SNIPER_PERCH. S3 is a VariantSlot child enabled by its rare event, and
S4 by a `min_difficulty` rule (Hazardous). **Two always-on perches (S1, S2)**, as D-064 Q8 ruled for
Dockside.

**Player perches:**
- the **car park roof** (`perch_carpark_roof`, +7.0) sees S1 (26 m) and S2 (41 m);
- the **frame slab's NE corner** (`perch_frame`, +3.5) sees S4 (86 m) and S3 (26 m, rare).

Counter-sniping is the player answer.

## Stealth routes
The setup is a short stealth game with **one required job** (the signals, for the clean stop), two
optional ones (the C4 and the thermite in the site), and **one moving threat** (the route marshal).
**Pager budget:**
- 1–2 site guards plus the marshal is 2–3 pagers at most. That is under the cap of 4, so a crew can
  kill everything in the setup.
- Every kill risks a body seen by a pedestrian through the man-gate or the Tannery gate (bodies are
  a stimulus for guards, and civilians who see a body panic: S6/S7).
- Masked bodies near PUBLIC lines are the real risk.

1. **Over the hoarding line (default, from the plaza).** Walk unmasked up the Orchard sidewalk past
   the controller corner (PUBLIC), reading the site guard's loop through the man-gate's mesh.
   - Then mask up out of sight inside the man-gate: lockpick the gate's padlock (8 s) when the
     sidewalk is empty.
   - Inside: pick or cut the controller cabinet (8 s), then rig it (15 s, 0–1 interruptions).
   - The guard's `post_site_gate` loop passes within 6 m every ~40 s. Answer his pager or let him
     walk by behind the cabins.
   - The magazine and C4 tool store are 30–45 m deeper in, past `post_site_cabins` and the camera.
2. **Through the car park (`pp_spawn_carpark`).** Spawn on Deck 2's stair lobby and **mask in
   stair A** (no civilians).
   - Cross Orchard **masked only when the sidewalk is clear and the marshal is not on
     `marshal_carpark`**: 26 m of open street, in S1's empty perch view (no sniper in the setup).
   - The site's Orchard vehicle gate (z −46…−41) is chained (LOCKPICK 8 s) and out of the
     pedestrian loop. It puts the crew at the magazine first.
   - The return trip to H1 is the shortest ambush position for `route_north`.
3. **Under the street (`pp_spawn_underpass`).** Spawn on the underpass sidewalk and mask in the
   underpass (few pedestrians; it is a dark tunnel).
   - Hold the east arm for `route_east`. The signals still need someone at the controller (88 m
     away across the junction), so this spawn suits a split crew or a crew that accepts the crash
     stop.

**Choosing not to rig the signals** is a legitimate plan. The crew skips the site, takes ambush
positions, and accepts the crash stop: no window, no lockdown, convoy alerted on impact.

**Lasers, cameras, keycards:** none in the street. The site has 1–2 cameras (`camera` slot) that
see the cabins, the magazine or the Orchard gate. There is no camera operator, so a camera that
sees a masked crew member raises the alarm.

## Loud
**Phase outline.** The ambush (or the crash) → the convoy fight (0 → `police_delay_s`) → first
CONTROL (20 s, first responders) → ANTICIPATION (30 s; +30 s once with a hostage) → BUILD → SUSTAIN →
FADE → CONTROL … (L1.1). Expected in a normal run:
- wave 1 during the first truck's saw (120–180 s);
- wave 2 while bags move to the escape and the second truck opens;
- wave 3 during the escape wait.

Escalation (L1.3) makes wave 3 the 100% stage.

### Holdouts (≥ 3 required; 4 designed, each with ≥ 2 non-`breach_only` approaches per D-070)

| Holdout | Where | Entrances (chokepoints) | Flanks | Sniper exposure | Strength | Weakness | It matters when |
|---|---|---|---|---|---|---|---|
| **H1 Car park Deck 2** | CP-2 (+3.5), centroid (35, −32) | (1) **R1 ramp** top (north end, 6 m wide, from the ground loop); (2) **stair A** (from the Orchard street door and the ground lobby); (3) **stair B** (from the south aisle and the rail-lane fire door); (4) **R2** down from the roof (rappel-free: police reach the roof only through the stairs and ramps) | The ground deck below fills with police from the entrance and the fire door. They come up three ways at once. | S1 sees the west bays (6–26 m); S2 sees the stair B corner (26 m). The deck interior is covered. | Height over both queues: north arm 22–40 m, east arm 10–20 m. Parked cars and columns. The lift moves bags down without the crew. | Four ways up, and the R1 ramp is a 6 m wide open lane. A Bulwark at the R1 top blocks it. | `route_north` (clean or crash), the T1/T2 saws on the east arm, `esc_van_carpark` (E1 below), and the climb to E3. |
| **H2 Halfway Diner** | DR + U1, centroid (24, 23) | (1) the **front double door** (Tannery); (2) the **side door** (Orchard); (3) the **kitchen delivery door**; (4) the **yard** (two gates → R fire exit and the ST service door); (5) the shopfront glazing (breakable, ENTRY) | Police from P_S and P_W reach the yard through the Orchard yard gate behind the holdout; P_E come up the ramp to the front. | S1 sees the front and U1's glazing (35 m); S4 sees the front from the SW (Hazardous+). | Two floors; U1 looks down on the junction and the east arm (12–45 m). The kitchen and store are hard rooms. Civilians cowering inside are hostages. | Glass everywhere: it breaks and the shopfront is an ENTRY. | `route_east` crash and clean (T1/T2 30–45 m away), and the hostage trade (L2.10). |
| **H3 Tanner's Reach frame** | F1 slab (+3.5) and FG, centroid (−38, −40) | (1) the **scaffold stair tower** (1.2 m, mesh-clad); (2) the **ladder** (no bags); (3) under-slab FG from the three site gates: the Orchard vehicle gate (breachable), the Orchard man-gate, the Tannery gate (open once the mixer has gone) | Police from P_N come through the Orchard vehicle gate; P_W through the Tannery gate. The hoarding hides their approach until they're inside. | S3 (rare) 19 m; S1 sees only the slab's NE corner over the hoarding (35 m). | The slab is out of street LOS; one stair (bags) and one ladder up; edge protection is soft cover only. | Only one bag route down (the stair); the slab's south edge faces the Tannery gate. | `route_north` (the queue is 20–45 m across Orchard), the C4/thermite pick-ups, and the setup. |
| **H4 Tannery underpass** | the underpass (−5.0) under the rail bridge, centroid (75, 0) | (1) **the west mouth** up the ramp (16 m wide, from the junction); (2) **the east cut** (from P_E, 27 m); (3) the sidewalk ramps (both sides) | Police come down the ramp from the junction and from P_E simultaneously. The rail lane cannot reach it (palisade). | S2 down the trench (the west mouth, 20–25 m); nothing sees inside the box. | Concrete box: 4.6 m soffit, abutments, the rail bridge's piers as cover. The van (E2) is right there. | A tunnel: two ends, both open, nowhere to go up. Grenades and the Stinger thrive. | `route_east` (T3 and the rear car are at the ramp foot) and `esc_van_underpass` (E2). |

Not designated, but useful:
- the **car park roof** (E3's last stand: two head houses plus R2; S1 and S2 both see it);
- the **plaza shelters and the clock pillar** (low cover at the default spawn).

### Police spawns (≥ 4 directions required; 6 designed) and the spawn rule
Spawns are `SpawnPoint` POLICE (grouped by tag). The director spawns at POLICE spawns **and
non-`breach_only` ENTRY points** that have **no LOS from any active crew member and are ≥ 15 m
(flat) from each of them** (DirectorTweak `min_crew_distance_m` = 15, L1.4). It picks the nearest
valid one to the crew centroid by path cost. **Police never spawn inside a building** (D-064/QC-42):
- every ENTRY point on the car park, the diner and the cabins carries `breach_only`;
- the street-closure ENTRY points do not.

The table gives flat distances from each spawn to each holdout centroid. All are ≥ 23 m.

| Spawn (tag) | Position (x, z, y) | Occluder (out of LOS of loot and escapes) | → H1 | → H2 | → H3 | → H4 |
|---|---|---|---|---|---|---|
| **P_N** `police_n` (Orchard north) | (6, −86, 0) | the traffic-management truck + its arrow board | 61 | 110 | 64 | 110 |
| **P_S** `police_s` (Orchard south) | (0, 68, 0) | the stalled articulated bus | 106 | 51 | 115 | 101 |
| **P_W** `police_w` (Tannery west) | (−78, 0, 0) | the articulated lorry + the low sun behind it | 117 | 105 | 57 | 153 |
| **P_E** `police_e` (underpass east) | (102, 4, −5.0) | the jack-knifed lorry, the cut walls | 76 | 80 | 147 | 27 |
| **P_NE** `police_ne` (rail lane north) | (60, −76, 0) | the palisade gate + a rail maintenance van | 51 | 105 | 104 | 78 |
| **P_SKY** `police_sky` (Skyway deck) | (0, −84, +9.0) | the deck itself (no crew access); one-way rappel links (QC-89) | 63 | 110 | 58 | 113 |

- P_E's 27 m to H4 is the tightest. The crew holding the underpass sees the lorry, so the rule
  pushes P_E spawns to its far side (still ≥ 15 m).
- P_SKY units reach the street only through the two **rappel** points at the junction span:
  (−13, −26) onto the west sidewalk by the site's man-gate, and (13, 20) onto the east sidewalk by
  the diner (drop 9.0 m).

### Police entry points (`TacticalPoint`)

| Kind | Where | breachable | Serves |
|---|---|---|---|
| ENTRY | the 4 street closures (convoy lanes and sidewalks) and the rail-lane gate (60, −72) | rail gate yes | N, S, W, E, NE |
| ENTRY (`breach_only`) | car park: entrance (24, −14), stair A street door (16, −46), fire door (52, −35) | fire door, stair door yes | N, E, NE |
| ENTRY (`breach_only`) | diner: front double door, side door, kitchen delivery door, R fire exit, ST service door, the shopfront bays ×4 (N ×2, W ×2) | yes | S, W, E |
| ENTRY | the site gates: Orchard vehicle gate (−14, −43), Orchard man-gate (−14, −16), Tannery gate (−33, −11) | yes (chained) | N, W |
| ENTRY | the diner yard gates (14, 36) and (34, 37) | yes | S, E |
| RAPPEL + ENTRY | Skyway deck edge → sidewalk at (−13, −26) and (13, 20) (drop 9.0 m, one-way) | — | Skyway |
| FLANK | storm drain: the plaza gully (−40, 14) → the underpass sump (75, 9, −5.0), nav layer `vent` (Phantom only) | — | W/E |
| FLANK | the rail lane behind the car park; the yard alley behind the diner and the laundromat | — | NE, S |
| SHIELD_ANCHOR | the junction centre (0, 0); the car park entrance (24, −11); the underpass west mouth (64, 0, −5.0); the site's Tannery gate (−33, −8); the diner front (24, 11); the Orchard north arm by the pier (−3, −40) | — | Bulwark/Aegis formations |
| COVER | ~70 points: the convoy vehicles (per layout, children of the layout set), Skyway piers, parked cars, shelters, newsstand, car park columns and cars, diner booths and counter, frame columns, formwork stacks, cabins, underpass abutments | — | all |

### Specials (P3) and where they come from
- **Phantom** (L4.3): through the **storm drain** (plaza ↔ underpass), so it appears in the holdout
  nobody watches. It also uses the rail lane. `cue.phantom_hum` carries in the underpass's echo.
- **Stinger** (L4.4): in pairs, preferring the **Skyway rappel** (onto the sidewalks beside the
  queues) and the rail lane into the car park.
- **Bulwark** (L4.5): the wide entries: the junction from any arm, the car park entrance and R1,
  and the underpass west mouth. It anchors at the SHIELD_ANCHOR points. A Bulwark at the R1 top or
  in the underpass mouth is the "block the bag route" moment.
- **Wrecker** (L4.6): vehicle-wide routes only: the four street closures (P_N, P_S, P_W, P_E),
  never the rail lane, the stairs or the rappel. With `armored_escort` (Lethal+), one is in the
  rear escort car and dismounts with the convoy.
- **Corpsman** (L4.8): with any group.
- **Longshot** (L4.7): S1 and S2 (always); S4 (Hazardous+); S3 (`crane_sniper`).
- **Commander Brandt + Aegis** (L4.9, Lethal+ once per heist): from P_S or P_N. They take the
  junction-centre anchor under the girder: the whole arena is his. The crew's answer is to hold H1
  or H2 until he retreats.

### Truck targets (the level change)
Each truck is an **`armored_truck`** prefab (QC-80): a vehicle-shaped `safe` LARGE with rear doors, in
group **`G.SAW_TARGET`**, opened by any one method. The cargo is a `loot_spawn` behind the doors,
enabled when they open, with its UsePoint on the rear step. No interior navmesh is needed.

| Truck | Placed saw (`drill_point` SAW, jams per S9.3/S9.4) | Hand saw (`saw_cut`, `hand_saw_truck_s` ◇) | C4 (`charges_required` ◇ 4, PD2) | Thermite | Cargo |
|---|---|---|---|---|---|
| `vl_cash` (cash van) | 120 s ◇ on the rear-door lock | 60 s of cutting ◇ | 4 charges (`item.c4` from the magazine, or trip mines with `interaction.shaped_charge`), 5 s fuse, L3.6 blast | — | `loot.cash_bricks` × `cash_bags` (4/5/6); a cab `small_loot` pouch ($800 ◇) behind the cab door (LOCKPICK 8 s) |
| `vl_bullion` (bullion truck) | 180 s ◇ | 90 s ◇ | 4 charges | **roof hatch** `burn_point` (QC-81): place the thermite bag (3 s), 45 s burn ◇, no jams, `cue.burn_warning`, then the hatch drops and the rear doors unlock; **no** fire volume | `loot.gold` × `gold_bags` (3/4) |

- **Lockdown** (early alarm): saw times ×1.5 (placed and hand). C4 and thermite are unchanged.
  Mercer: "Deadbolts are thrown. Saw's going to take longer."
- **The box-in is the level change.** The stopped convoy plus the mixer turns an open street into
  lanes. Clean stops build a **wall of steel** along the queue (cover on one side, a shooting gallery
  on the other). Crash stops scatter vehicles over the junction.
- **G1 fallback until QC-80/81 ship:**
  - a `safe` LARGE with `methods [saw, c4]` inside a static truck mesh, plus a `drill_point` SAW
    targeting it;
  - for the bullion hatch, a `drill_point` THERMAL with `duration_s` 45 and no bag;
  - each marked `TODO(QC-80)` / `TODO(QC-81)`, as Dockside did.

## Loot path
- **Required** (the escape is called when it is done): **≥ 4 bags secured** from cash bricks
  (`loot.cash_bricks`, MEDIUM) and/or gold (`loot.gold`, HEAVY). Extra bags, bearer bonds and small
  loot are a bonus.
- **Throw spots:**
  - the **car park west barrier** (from the Orchard sidewalk into the west bays, then 4 m to E1's
    aisle);
  - the **forecourt railing** (bags thrown down into the trench toward E2, 2–5 m drop);
  - the **Deck 2 south barrier** (down to the forecourt, 3.5 m);
  - over the **frame slab edge protection** (down to FG, 3.5 m).
- **Distances, `route_north` clean** (the T1 rear doors at (−6, −32), T2 at (−6, −44), T3 at
  (−6, −56)):
  - **E1 van (car park ground, (23, −30)):** across Orchard to stair A's street door (16, −46),
    through the lobby and the north aisle (T2 ≈ 42 m), or round by the entrance (T1 ≈ 65 m).
    **The short one.** Or throw over the west barrier at (16, −30): T1 ≈ 24 m to the barrier,
    then 8 m inside.
  - **E2 van (underpass east, (92, −4, −5.0)):** down the north arm, across the junction, down
    the ramp (T1 ≈ 125 m). **The long haul**, S1-exposed on the east arm.
  - **E3 heli (car park roof, (32, −34, +7.0)):** to stair A and up two storeys (T2 ≈ 42 m +
    2 storeys, or the lift: 2 bags, 16 s), or up R1 + R2 (≈ 110 m).
- **Distances, `route_east` clean** (T1 rear (33, −4), T2 (45, −4, −1.7), T3 (56, −4, −3.4)):
  - **E1:** T1 → entrance (24, −14) → van: ≈ 35 m; T3 ≈ 50 m uphill.
  - **E2:** T1 ≈ 60 m, T3 ≈ 36 m, all downhill in the trench (S2's lane). **The short one**
    for the rear trucks.
  - **E3:** T1 → entrance → lift ≈ 40 m + 16 s; by the ramps ≈ 95 m.
- **Crash stops** (the junction, ~(0, 0)): E1 ≈ 45 m, E2 ≈ 95 m, E3 ≈ 50 m + lift.
- **Gold is HEAVY** (×0.75 speed, no sprint, 3 m throw): on the long routes, `carry_bag` orders and
  the lift decide the run.
- **Optional:**
  - the other trucks;
  - the cab pouches;
  - the bonds (`bonds_courier`);
  - the car park pay station (`safe` SMALL);
  - the diner till and office safe;
  - the site office's petty-cash tin (`small_loot`).
- **Secure zones:** `SECURE_LOOT` at the active escape only: the van's rear doors (E1, E2) or the
  heli's hover zone over the pad (E3, `escape_type` heli, a bag thrown in secures it). It exists
  from the start, so bags can be secured before the escape arrives (PD2).
- **Bodies (setup only):** body bags work. The containers are the site skip and the diner yard
  bins (`body_container`, capacity 2 each). A body in the street is seen by pedestrians.

## Objectives
**Setup** (stealth start; objective_tag in brackets; ENV B reads these, D-039):
1. *(optional)* Case the junction. Mercer intro and a Reyes line. `[casing]`
2. **Rig the junction signals** before the convoy arrives:
   - the controller cabinet: lockpick 8 s or cut the padlock (`saw_target`);
   - the rig: `hack_terminal` 15 s, 0–1 interruptions.

   It is optional, but without it the stop is a crash. `[signals]`
3. *(optional)* Raid the site stores:
   - breaking charges from the magazine (padlock: lockpick 8 s or saw; `item.c4` ×4 per box)
     `[charges]`;
   - the thermite bag from the tool store (LOCKPICK 8 s) `[thermite]`.
4. *(optional)* Deal with the Vaultline route marshal: avoid him, or kill or dominate him and answer
   his pager. `[marshal]`
5. Take your positions: the convoy arrives in `convoy_eta_s` (objective timer). `[convoy]`

**Loud** (from the ambush, the crash or an early alarm):
6. Spring the ambush: the convoy stops (clean or crash) and the alarm is raised. `[ambush]`
7. *(optional)* Take down the escort and the Vaultline crews (bonus line). `[escort]`
8. Open the trucks: placed saw, hand saw, C4 (4 charges) or thermite on a bullion hatch. The
   objective data shows the trucks opened (n/N). `[trucks]`
9. Bag the cargo. `[cargo]`
10. Secure ≥ 4 bags (cash and/or gold). `[secure]`
11. Hold until the escape arrives (`escape_eta_s` after `[secure]`). `[escape_wait]`
12. *(optional)* More bags: the other trucks, bonds, pouches, the pay station, the diner safe.
13. Escape. `[escape]`

**Mission script notes** (`rolling_thunder_mission.gd` on `HeistMission`):
- **Setup clock:** `schedule_at(convoy_eta_s − 75, &"marshal", …)` (−90 with `marshal_early`)
  spawns the marshal with `spawn_guards(1, &"vl_marshal")`. `schedule_at(convoy_eta_s − 20,
  &"convoy_sighted", …)` → the Mercer and Reyes lines. `schedule_at(convoy_eta_s, &"convoy", …)`
  → the drive-in (QC-82). `convoy_early` subtracts 45 s.
- **Alarm handling:** `_on_alarm(reason)` before `convoy` → **early alarm**:
  - `police_delay_s = 0`;
  - set the convoy to `alerted` (crash layout, immediate dismount, `lockdown()` on every truck);
  - Mercer line.

  After `convoy`, `_on_alarm` → `[ambush]` complete.
- **Clean stop:**
  - the `[signals]` hack completes (`device_finished(&"hack")`) before the convoy → clean layout;
  - at the stop, spawn the convoy units **seated** (QC-83) and start the 3 s mixer move and the 8 s
    window;
  - a convoy unit's `npc_alerted`, any crew shot near the convoy, or the window's end →
    `raise_alarm(&"ambush")` (QC-83);
  - `dismount_delay_s` 4 s.
- **Crash stop:** the mixer move and the impact → `raise_alarm(&"ambush")`, with units dismounting
  at once.
- **Police delay:** set `police_delay_s` in `_on_mission_start()` from the rolled scalar
  (45/60/90). It runs from the alarm (QC-35, already in the API).
- **Trucks:** `device_finished` on a truck → `update_objective_data(&"trucks", {opened, total})`.
  Mercer lines per method. The bullion `burn_point` → the truck's `open_by_device()` (QC-81).
- **Escape:** when `[secure]` is done, the active `escape_zone` gets
  `arrival_delay_s = escape_eta_s` and activates (`activate_escape`).
- **Mercer and Reyes lines:**
  - setup: intro, ETA 60 and 30, marshal arriving, signals rigged and reminder, C4 found, thermite
    found;
  - the stop: convoy sighted, stopped, go, alerted, crash, escort down, police called;
  - devices and loot: saw, jam, truck open, C4 armed, thermite burning, gold, bonds, lift dead;
  - snipers: Skyway, rail;
  - endgame: required secured, van and heli ETAs, escape.
- **Reyes** (`SPEAKER` `reyes` on the radio): in position, ram, boxed in, payday.

## Variable table
Each variable changes a decision. Rules resolve in this order (heist_map.md §5). Per-difficulty
weights use A2-08 / A3-10 (QC-18).

| variable | options (slot ids) | weights | gameplay effect (the decision it changes) |
|---|---|---|---|
| `convoy_route` | `route_north`, `route_east` | 0.55, 0.45 | **Where the fight is and which holdouts matter.** North: the queue under the Skyway (S1-blind), held from H1/H3, E1 short. East: the queue in the trench, held from H1/H2/H4, E2 short for the rear trucks. |
| `truck_count` | `trucks_2`, `trucks_3` | per difficulty (Convoy units table) | **How much there is to open and how far the queue reaches** (the 3rd truck puts the rear car 11 m further back: on the east route, deep in the trench). |
| `cargo_t3` | `t3_cash`, `t3_bullion` | 0.5, 0.5; `requires: {truck_count: [trucks_3]}` | **Whether the third truck is a fast saw (cash, MEDIUM) or a long saw/thermite target with HEAVY gold.** |
| `cash_bags` (scalar) | 4, 5, 6 per cash van | Routine 0.3/0.5/0.2; Brutal+ 0.2/0.4/0.4 | **Whether one cash van alone meets the 4 required.** |
| `gold_bags` (scalar) | 3, 4 per bullion truck | 0.5, 0.5 | **How much HEAVY loot is worth the haul.** |
| `controller` | `ctrl_locked`, `ctrl_open` | 0.7, 0.3 (forced by `asset.signal_insider`) | **How long the crew stands at the setup's exposed corner** (8 s lockpick or noisy saw, vs walk in and rig). |
| `site_stores` | `stores_c4`, `stores_thermite`, `stores_both` | 0.4, 0.3, 0.3 | **Which truck methods exist without pre-planning**, and whether the deep site trip (magazine 30 m, tool store 45 m from the gate) is worth the guard and camera. |
| `guard_post` (site) | `post_site_gate`, `post_site_frame`, `post_site_cabins` | 1 each; pick 1 (Routine/Tense), 2 (Hazardous+) via `difficulty_add` | **Which part of the site is watched**: the controller corner, the slab (H3 later), or the stores. |
| `camera` (site) | `cam_mast_cabins`, `cam_magazine`, `cam_gate` | 1 each; pick 1 (Routine–Hazardous), 2 (Brutal+) | **Where you cannot be masked in the site.** No operator, so it is an alarm, not a loop. |
| `cop_on_scene` | `cop_plaza`, `cop_diner`, `cop_none` | 0.4, 0.3, 0.3 | **Whether the default spawn is watched** and whether the diner (H2) is a safe place to mask up. |
| `marshal_walk` | `marshal_carpark`, `marshal_site_corner`, `marshal_plaza` | 1, 1, 1 (revealed by `asset.intel_route`) | **Which ambush position the last 75 s are dangerous in**, and whether the controller job must be finished before he arrives. |
| `goods_lift` | `lift_powered`, `lift_dead` | 0.6, 0.4 (no `force_if`: a dead lift with the heli is the intended hard roll; `asset.lift_power` is the answer) | **How bags reach the roof or come down from Deck 2:** the lift (8 s per floor, 2 bags), the plant-room breaker (5 s, on the ground deck in the crossfire), or the ramps. |
| `player_perch` | `perch_carpark_roof`, `perch_frame`, `perch_none` | 0.3, 0.3, 0.4 | **Whether a counter-sniper position exists** for S1/S2 (roof) or S3/S4 (frame). Forced by `asset.sniper_position`. |
| `escape` | `esc_van_carpark` (E1), `esc_van_underpass` (E2), `esc_heli_roof` (E3) | 0.4, 0.35, 0.25 | **The whole loot path and the last holdout.** North + E1 or east + E2 is short; the crossed pairs are a long haul; the heli is always a climb. |
| `convoy_eta_s` (scalar) | 150, 180, 210 | uniform | **How much of the setup you can do**: signals only, or signals + stores + positions. |
| `police_delay_s` (scalar) | 45, 60, 90 | per difficulty (Convoy units table) | **How long the convoy fight lasts before CONTROL**: on 90 the crew can start a saw before the first responders. |
| `escape_eta_s` (scalar) | 90, 120, 150 | Routine 0.4/0.4/0.2; Brutal+ 0.2/0.4/0.4 | **How long the final holdout lasts.** |
| `civilians` (scalar) | 6, 9, 12 pedestrians | uniform | **How many eyes in the setup** and hostages (and kill penalties) in loud. |

## Rare events

| id | good/bad | chance | effect |
|---|---|---|---|
| `bonds_courier` | good | 8% | T1's cab carries a courier case: 2 bags of `loot.bearer_bonds` (LIGHT) in a cab safe (`safe` SMALL, `methods [drill, saw, c4]`). |
| `informant_tip` | good | 6% | Reyes's contact at Vaultline: reveals `convoy_route` and `marshal_walk` (as `asset.intel_route`). |
| `gold_rush` | good | 4% | A third truck and it's bullion: forces `trucks_3` + `t3_bullion`. |
| `marshal_early` | bad | 8% | The marshal arrives at ETA − 90 s and walks two checks instead of one. |
| `convoy_early` | bad | 6% | The convoy is 45 s early (Mercer warns at the 60 s mark). |
| `crane_sniper` | bad | 8% (`min_difficulty` Brutal) | A police marksman is in the crane cab: S3 is enabled from the first CONTROL. |
| `armored_escort` | bad | 6% (`min_difficulty` Lethal) | A Wrecker rides in the rear escort and dismounts with the convoy. |
| `rush_hour` | bad | 6% | `civilians` = 12 and +2 diner customers: more eyes in the setup, more cowering in the crossfire. |

## Escape
- **Van in the car park (E1):** in the ground deck's west aisle (23, −30).
  - Escape type `van`, `arrival_delay_s = escape_eta_s`. It drives in through the entrance from
    Tannery (east arm) once called.
  - SECURE_LOOT at the rear doors from the start; the ESCAPE zone round the van when it arrives.
  - The last holdout is the ground deck, with H1 overhead.
- **Van in the underpass (E2):** in the east cut (92, −4, −5.0), behind the lorry's gap.
  - Same rules. The last holdout is H4.
  - P_E is 10 m beyond the lorry: the van arrives through the police's own lane (it is "Reyes's
    nephew in a borrowed council van", so the police let it pass).
- **Heli on the car park roof (E3):** escape type `heli` over the pad (32, −34, +7.0),
  `arrival_delay_s = escape_eta_s` + 20 s (approach).
  - SECURE_LOOT is the hover zone (bags thrown in); ESCAPE is the pad.
  - The last holdout is the roof: two head houses and R2, with S1 and S2 both on it.
- **Walk-out:** none.

## Pre-planning (preplanning.md contract, D-046 shape)
`Preplan` points (category; `floor` is the index into `floor_heights`: 0 Underpass, 1 Street,
2 Upper, 3 Roof; point labels are heist-qualified, `ui.preplan.point.rolling_thunder.<point_id>`,
preplanning.md v1.1):

| Point | Category | Params / asset |
|---|---|---|
| `pp_spawn_plaza` | spawn | default (spawn_tag `""`), the bus interchange (floor 1) |
| `pp_spawn_carpark` | spawn | spawn_tag `preplan_spawn_carpark` (Deck 2 stair-A lobby, floor 2) — `asset.alternate_entry` |
| `pp_spawn_underpass` | spawn | spawn_tag `preplan_spawn_underpass` (underpass north sidewalk, floor 0) — `asset.alternate_entry` |
| `pp_drop_site` | drop_zone | inside the Orchard man-gate behind the cabins' line — ammo, doctor, thermite, body bags |
| `pp_drop_carpark` | drop_zone | Deck 2 south bays by stair B (floor 2) — ammo, doctor, thermite, C4 |
| `pp_drop_diner_yard` | drop_zone | the diner yard (floor 1) — ammo, doctor, body bags |
| `pp_drop_underpass` | drop_zone | the underpass north abutment (floor 0) — ammo, doctor, thermite, C4 |
| `pp_escape_carpark` | escape | variant_group `escape`, slot `esc_van_carpark` — `asset.escape_position` (vote) |
| `pp_escape_underpass` | escape | slot `esc_van_underpass` |
| `pp_escape_roof` | escape | slot `esc_heli_roof` (floor 3) |
| `pp_perch_roof` | drop_zone | variant_group `player_perch`, slot `perch_carpark_roof` (floor 3) — `asset.sniper_position` |
| `pp_perch_frame` | drop_zone | variant_group `player_perch`, slot `perch_frame` (floor 2) — `asset.sniper_position` |
| `pp_signals` | insider | variant_group `controller`, slot `ctrl_open` — new `asset.signal_insider` |

`HeistDef.preplanning` (contract v1.0 shape; entry keys are PreplanAssetDef fields; costs are Routine
prices, scaled by `PreplanTweak.cost_mult`; values marked ◇ are my proposals for ENV B/lead):
```gdscript
preplanning = {
    "favors": 5,
    "disable": [&"asset.intel_keycards", &"asset.intel_laptop"],
    "assets": {
        # library assets, limited to this heist's points
        &"asset.ammo_bag_drop": {"point_ids": ["pp_drop_site", "pp_drop_carpark",
                                               "pp_drop_diner_yard", "pp_drop_underpass"]},
        &"asset.doctor_bag_drop": {"point_ids": ["pp_drop_site", "pp_drop_carpark",
                                                 "pp_drop_diner_yard", "pp_drop_underpass"]},
        &"asset.body_bag_case_drop": {"point_ids": ["pp_drop_site", "pp_drop_diner_yard"]},
        &"asset.thermite_drop": {"point_ids": ["pp_drop_site", "pp_drop_carpark",
                                               "pp_drop_underpass"]},                      # library (B5-04), our points
        &"asset.sniper_position": {"point_ids": ["pp_perch_roof", "pp_perch_frame"]},     # library (B5-04), our points
        # asset.lift_power works as-is: our lift's group is the standard `goods_lift`
        # new heist assets (QC-84/85)
        &"asset.c4_drop": {"drop": &"item.c4", "params": {"count": 4},                    # needs an item drop kind (QC-84)
                           "point_ids": ["pp_drop_carpark", "pp_drop_underpass"],
                           "max_count": 1, "cost": 2000, "favors": 2, "tags": [&"loud"]},          # ◇
        &"asset.signal_insider": {"effect": &"force_variant", "point_ids": ["pp_signals"],
                                  "max_count": 1, "cost": 1500, "favors": 1, "category": &"access",
                                  "tags": [&"stealth"]},                                            # ◇
        &"asset.intel_route": {"reveals": [&"convoy_route", &"marshal_walk"],
                               "cost": 1500, "favors": 1, "category": &"intel"},                   # ◇
    },
}
```
- **Crew assets with no point that stay on:**
  - `asset.intel_guard_posts` reveals the site guard posts (`guard_post`);
  - `asset.intel_cameras` reveals the site cameras (`camera`);
  - `asset.extra_cable_ties` (the street is full of hostages);
  - `asset.spare_body_bags` (setup bodies);
  - `asset.lift_power`.
- **Hidden automatically** (QB-53, D-049): library assets whose groups do not exist here (gondola,
  riser, containers, gangway). `disable` lists the two that would otherwise show only by name.
- `asset.escape_position` and `asset.alternate_entry` work from the points' params as on every
  heist.
- **Wished for** (preplanning content doc): an "escape driver" timer upgrade. It is not
  expressible yet and is left out.
- **Blueprint:** `docs/levels/rolling_thunder/blueprint.png` from the plan renderer.

## Audio/lighting
- **Palette** (proposed style guide §3 row, below):
  - **expressway concrete `#8C877D`** dominant: the Skyway piers and deck, the retaining walls, the
    car park, kerbs. It is warm and sunlit, unlike Dockside's cool `#7D7F7C`.
  - **Skyway green `#4E6B5C`** secondary: the box girder, the signal gantries, the railings, the
    car park barriers, the hoarding's developer graphics.
  - **signal amber `#FFB000`** accent: the traffic signals, the hazard beacons on the mixer and
    the TM truck, and **the Vaultline mark** on the trucks and crews.
  - Vaultline's sand/black livery sits on top as a faction colour (D3-01).
  - Wear is **medium** (style guide §4): road grime, tyre marks, dust on the kerbs, rust bleed
    under the girder's rivets.
- **Time:** 16:50, low autumn sun.
  - The `DirectionalLight3D` is at azimuth 245°, elevation 9°, warm 3800 K, with shadows (the one
    shadowed sun).
  - The procedural sky has a bright amber horizon in the WSW and blue overhead with high cirrus.
  - **No fog**: a light dust haze (height-falloff fog, density low) catches the sun down Tannery.
- **Zones:**
  - streets and plaza: the sun, plus unshadowed sodium-white lamp posts that are off (daylight).
    The girder's sodium tubes are on (fixture rule), so the north arm reads amber in the shade.
  - underpass: 5000 K fluorescent battens, two shadowed; a dark tunnel against the bright cut.
  - car park: 4500 K LED battens on the decks (on: the deck interior is dim); the sun slants
    through the west and south barriers in long stripes.
  - diner: 2900 K pendants over the booths, the neon sign (magenta-red and amber), a 4000 K
    kitchen.
  - site: low sun over the hoarding; cabins 4000 K.
  - Every light has a fixture.
- **GI:** VoxelGI for the car park and the diner interiors, ReflectionProbe per room, SDFGI off.
  OccluderInstance3D for the car park, the diner block, the hoarding, Ashby House and the Skyway
  deck.
- **Ambience:**
  - `amb_skyway_street`: Skyway traffic rumble overhead (expansion-joint thumps every 3–6 s), wind
    gusts with leaves and grit, distant city traffic, a bus idling, pigeons under the girder;
  - `amb_underpass` (echoing drips, the fluorescent buzz, a freight train passing over every 90–150
    s: rumble plus wheel squeal);
  - `amb_diner` (griddle, radio, cutlery);
  - `amb_site` (a generator, scaffold clanks in the wind).
  - **Freight trains also pass during loud**: they mask the Phantom hum for 6 s (readability: the
    train never overlaps `cue.phantom_charge`, ENV A to suppress the train cue during a charge, or
    I simply never schedule it during an assault BUILD).
- **Cues:** `cue.convoy_approach` (diesel engines plus a two-tone Vaultline horn, 3D), `cue.convoy_brake`
  (air-brake hiss), `cue.mixer_ram` (impact, glass, metal), `cue.signal_click` (relay clunk when the
  rigged lights switch), `cue.truck_doors_open` (heavy bolt plus hinges); audio_cues v1.4 additions
  (QC-85 lists them for the lead). `cue.door_breach`, `cue.burn_warning`, `cue.escape_arrive_van` and
  `cue.escape_arrive_heli` exist.
- **Music:** `rolling_thunder`, one of the three P5 tracks (D-062):
  - `stealth` (78 BPM): a ticking hi-hat clock motif over a low synth pad, used for the setup
    countdown and rising at ETA − 30 s;
  - `control` (112 BPM);
  - `anticipation` riser;
  - `assault` (148 BPM): driving percussion, diesel-drone bass and a two-note signal-chime motif;
  - `fade`;
  - `win`/`lose` stingers (audio_cues.md music stems).
- **VO line ids** (`vo.<speaker>.<heist>_<line>`, D-051; ENV B writes the text):
  - **Reyes:** `vo.reyes.briefing_rolling_thunder_1..3`, `vo.reyes.rolling_thunder_contact_intro`,
    `vo.reyes.rolling_thunder_in_position`, `vo.reyes.rolling_thunder_convoy_sighted`,
    `vo.reyes.rolling_thunder_ram`, `vo.reyes.rolling_thunder_boxed_in`,
    `vo.reyes.rolling_thunder_payday`.
  - **Mercer:** `vo.mercer.briefing_rolling_thunder_1..2`, `vo.mercer.rolling_thunder_intro`,
    `vo.mercer.rolling_thunder_eta_60`, `vo.mercer.rolling_thunder_eta_30`,
    `vo.mercer.rolling_thunder_marshal_arrives`, `vo.mercer.rolling_thunder_signals_rigged`,
    `vo.mercer.rolling_thunder_signals_reminder`, `vo.mercer.rolling_thunder_c4_found`,
    `vo.mercer.rolling_thunder_thermite_found`, `vo.mercer.rolling_thunder_convoy_sighted`,
    `vo.mercer.rolling_thunder_convoy_stopped`, `vo.mercer.rolling_thunder_ambush_go`,
    `vo.mercer.rolling_thunder_convoy_alerted`, `vo.mercer.rolling_thunder_crash_stop`,
    `vo.mercer.rolling_thunder_escort_down`, `vo.mercer.rolling_thunder_police_called`,
    `vo.mercer.rolling_thunder_truck_saw`, `vo.mercer.rolling_thunder_saw_jam`,
    `vo.mercer.rolling_thunder_lockdown`, `vo.mercer.rolling_thunder_truck_open`,
    `vo.mercer.rolling_thunder_c4_armed`, `vo.mercer.rolling_thunder_thermite_burning`,
    `vo.mercer.rolling_thunder_gold`, `vo.mercer.rolling_thunder_bonds`,
    `vo.mercer.rolling_thunder_lift_dead`, `vo.mercer.rolling_thunder_sniper_skyway`,
    `vo.mercer.rolling_thunder_sniper_rail`, `vo.mercer.rolling_thunder_sniper_crane`,
    `vo.mercer.rolling_thunder_required_secured`, `vo.mercer.rolling_thunder_van_eta`,
    `vo.mercer.rolling_thunder_heli_eta`, `vo.mercer.rolling_thunder_escape`.
  - Crew barks reuse the generic `vo.crew.*` set. The marshal's pager uses the generic pager lines.
- **LUT:** `lut_rolling_thunder`: warm amber highlights, teal-green shadows under the Skyway, a
  gently lifted haze in the distance, and strong bloom on the sun axis down Tannery.

### Proposed style guide §3 row

| Heist | Dominant | Secondary | Accent | Mood / time |
|---|---|---|---|---|
| rolling_thunder | expressway concrete `#8C877D` | Skyway green `#4E6B5C` | signal amber `#FFB000` (signals, beacons, the Vaultline mark) | late afternoon, low autumn sun down Tannery, dust haze |

Checks:
- all albedos sit within 0.04–0.85 luminance;
- Skyway green saturation is 0.27;
- amber is used only on signage and emissives (signals, beacons, the printed Vaultline mark), so it
  may exceed the 0.75 saturation cap;
- none is close to the interactable cyan `#4FD1E8`;
- it is distinct from Dockside (rust/cool concrete/flare orange) and from police navy/hi-vis.

ENV B's UI accent for the heist (road-sign lime `#B8D648`, `heist_accents.tres`) is a UI colour, not
a world colour, and stays as B set it.

## Review shots
`HeistMap.review_cameras` (level_standards §8; JPEG q85, D-038). Each camera is ≥ 0.5 m inside its
room (C1-04 check). The **convoy is shown in its `route_north` clean layout** for G1/G2. G3 adds a
set per layout. There are 28 shots: 1 top-down, 5 exterior, 4 landmarks (covered within those),
1 per major room, the trucks (the "vault"), and the sniper views.

| Camera | Shows | Covers |
|---|---|---|
| `rc_top_down` | orthographic plan of the whole play space | top-down plan |
| `rc_ext_junction` | from the plaza looking NE: the junction, the **green girder**, the car park, the diner corner | exterior 1, landmark 1 |
| `rc_ext_north_arm` | from the junction looking N under the Skyway: the convoy queue, piers, the site hoarding | exterior 2 |
| `rc_ext_east_arm` | from the forecourt railing looking E: the ramp, the trench, the underpass mouth, the rail bridge | exterior 3 |
| `rc_ext_plaza` | the shelters and the **clock pillar**, Ashby House behind | exterior 4, landmark 2 |
| `rc_ext_tannery_west` | from the junction looking W down Tannery **into the sun**: the site's Tannery gate, the **crane**, P_W's lorry | exterior 5, landmark 3 (and the glare check) |
| `rc_diner_neon` | the diner corner from the east-arm sidewalk: the **neon**, the shopfront | landmark 4, diner exterior |
| `rc_convoy_cash` | the `vl_cash` rear doors, saw point and the cab | truck (cash) |
| `rc_convoy_bullion` | `vl_bullion` from above-behind: the roof hatch burn point, rear doors | truck (bullion, the "vault") |
| `rc_carpark_ground` | CP-G from the entrance: aisles, booth, E1 van | CP-G |
| `rc_carpark_deck2` | CP-2 from the stair B corner looking NW over the barrier to the north arm | CP-2 (H1) |
| `rc_carpark_ramp` | R1 from the south turning area | ramps |
| `rc_carpark_roof` | the heli pad and head houses, the Skyway beyond | CP-R (E3) |
| `rc_carpark_booth` | AB interior with the pay station through the window | AB |
| `rc_carpark_plant` | CPL | CPL |
| `rc_carpark_stair` | STA from the Deck 2 landing | STA |
| `rc_diner_dining` | DR from the side door: booths, counter, glazing | DR (H2) |
| `rc_diner_kitchen` | K | K |
| `rc_diner_function` | U1 at the glazing over the junction | U1 (H2) |
| `rc_diner_office` | OF with the safe | OF |
| `rc_diner_staff` | U5 | U5 |
| `rc_site_controller` | the controller corner from inside the man-gate | X4, setup |
| `rc_site_frame` | FG under the slab, the scaffold stair | FG |
| `rc_site_slab` | F1 from the stair head: edge protection, Orchard beyond | F1 (H3) |
| `rc_site_cabins` | the cabin row, the magazine, the camera mast | C1–C4, MG |
| `rc_site_welfare` | C2 interior | C2 |
| `rc_underpass` | from the west mouth into the underpass: E2 in the cut, the lorry | X2 (H4) |
| `rc_sniper_skyway` | from S1 over the east arm and the car park (what the Longshot sees) | sniper LOS check |

## Budgets
Targets from architecture §10 and D-038 QC-10, checked by the `perf` validator per review camera.

| Budget | Target | Notes |
|---|---|---|
| Draw calls per view | ≤ 2,500 | The worst views are `rc_ext_junction`, `rc_ext_tannery_west` and `rc_sniper_skyway`. Parked cars, bollards, lamp posts, barriers, railing posts and car-park columns are **MultiMeshInstance3D** per kit item; convoy vehicles are 5–7 unique meshes. |
| Triangles per view | ≤ 3M (provisional, QC-10) | The Skyway deck and girder use 2 LODs; far facades are low-poly LOD dressing; vehicles 20–40k at LOD0 (hero props). |
| Shadowed lights in any shot | ≤ 8 | The sun (1), 2 underpass battens, 1 per car-park deck, 1 diner, 1 site mast; the rest unshadowed. |
| Texture memory | ≤ 1.5 GB | The shared library (concrete, asphalt, painted steel, plywood, brick, glass) covers ~90% of surfaces; the Vaultline livery and the diner neon are the unique sets. |
| NPCs alive | police + convoy ≤ `DifficultyDef.max_active_enemies`; civilians ≤ 20 | The convoy units count against the cap (as D-064 Q5); pedestrians are despawned when they reach a `civ_flee` exit. |
| Fog / haze | one WorldEnvironment height fog (low density dust haze), no FogVolumes | Exteriors only. |
| Vehicles | ≤ 8 convoy/closure vehicles moving at once (the drive-in), then static | Movers are AnimatableBody3D on Path3D (QC-82); no physics vehicles. |
| **Density (kits)** | streets: clutter in clusters at corners, shelters, the newsstand and the piers (no uniform scatter); car park decks 12–18 parked cars per deck, bays 40–60% filled; diner per kit minimums; site: stacks at the frame edges and the cabins | Same-kit rooms (CP-G/CP-2, W1/W2, C1–C4) must differ in layout hash (the `variety` check). |

**Walkthrough whitelist** (level_standards §6): **R1 + R2 to the roof** from the car park spawn
(a ≈ 70 m path for a 7 m rise and a ≈ 20 m straight line: 3.5×, the ramp loop). This is whitelisted
because the stairs and the lift are the direct routes. Nothing else is expected.

## HeistDef (proposed data, `rolling_thunder_def.tres`)
- **Identity:** `id rolling_thunder`, display "Rolling Thunder", contact `contact.reyes`, mode
  `STEALTH_OR_LOUD` (stealth-start ambush; Open question 1).
- **Payout:** base_payout **$85,000** (ENV B's B6-01 placeholder, accepted; P6 balance).
- **Loot:** `[loot.cash_bricks, loot.gold, loot.bearer_bonds]`. **No new loot ids**: all three exist
  (B6-01). `loot.thermite` is a tool bag (D-068).
- **Data:** escape_options `[van, heli]`, music_track `rolling_thunder`, objectives `[casing,
  signals, charges, thermite, marshal, convoy, ambush, escort, trucks, cargo, secure, escape_wait,
  escape]`, preplanning as above.
- **Map:** `game/world/heists/rolling_thunder/rolling_thunder.tscn`; `floor_heights [-5.0, 0.0, 3.5,
  7.0]`, `floor_names ["Underpass", "Street", "Upper", "Roof"]`.

## Requests (to the lead; QC-80..QC-89)
- **QC-80 (ENV A): `armored_truck` prefab.** A vehicle-shaped `safe` LARGE (it extends or composes
  `Safe`).
  - Methods `[saw, c4]` (+ `thermite` through a bound `burn_point`, QC-81) and group
    **`G.SAW_TARGET`** (`saw_cut`, `hand_saw_truck_s` ◇ 60/90 by `size`).
  - `charges_required: int` (◇ 4, PD2) for C4: `item.c4` or trip mines with
    `interaction.shaped_charge`, each placement adding one.
  - `lockdown()` multiplies the saw times by `lockdown_saw_mult` (◇ 1.5).
  - Visual nodes `Body`, `DoorL`, `DoorR`, `DrillPoint` (the rear lock), `LootAnchor`, `CabDoorL/R`,
    optional `RoofHatch`.
  - Vehicle collision fitted to `Body` (layer 1), a carved nav obstacle, and cover.
  - `loot_spawn` children enabled on open (as `Safe`).
  - Cab doors are ordinary `door` prefabs (LOCKPICK) parented to it.
- **QC-81 (ENV A): `burn_point` `target: NodePath`** (on finish → `target.open_by_device()`) and
  `fire_volume_size = Vector3.ZERO` meaning no fire volume. It is for the bullion roof hatch:
  thermite through the roof, no lingering fire.
- **QC-82 (ENV A): `convoy_vehicle` mover.**
  - An `AnimatableBody3D` vehicle that drives along a `Path3D` to a target marker at a set speed
    with braking, replicated (server-authoritative transform; clients interpolate).
  - It ends static, carves the navmesh (or adds a `NavigationObstacle3D`), and emits
    `vehicle_stopped(id)`.
  - It is used for the escort cars, the trucks (carrying their `armored_truck`), Reyes's mixer,
    and the marshal's scout car.
  - A mission API `drive_to(vehicle, path, marker, speed)`, or a prefab export plus `start()`.
  - Seats: `Seat0..n` markers whose occupants are hidden or seated until dismount (QC-83).
- **QC-83 (ENV A): mission hooks for the ambush.**
  - (a) `HeistMission.raise_alarm(reason: StringName)` (STEALTH → LOUD from the mission:
    `&"ambush"`).
  - (b) `spawn_units(enemy_id, count, spawn_tag, seated: bool, vehicle: Node)`. Police roles count
    as police (`alive_units`, director quota, cap); Vaultline crews are `enemy.security_officer`
    with the D visual from the SpawnPoint's `visual_variant` (D-063 casting). Seated units are
    inside their vehicle (armoured cab = not hittable; soft car = hittable through the glass) and
    dismount `dismount_delay_s` after the alarm, or at once.
  - (c) The convoy units share `max_active_enemies` with police (the D-064 Q5 rule).
  - (d) A convoy unit's detection of a masked crew member during the window raises the ambush
    alarm, not a pager call.
- **QC-84 (ENV A + ENV B): C4 as an item.**
  - An `item_pickup` prefab (`item_id`, `count`; the `keycard_pickup` shape generalised) granting
    `item.c4` ×4 from the magazine boxes.
  - A HUD count for `item.c4` (B), and trip mines counting as shaped charges toward
    `charges_required` (`interaction.shaped_charge`).
  - Pre-planning `drop` of an **item** kind (`item.c4`, `params.count`): the crew member who takes
    it gets the charges (preplanning.md v1.2).
- **QC-85 (ENV B): content.**
  - Objective strings for the 13 `[tag]`s.
  - The VO text for the lines above, with Reyes as an in-heist radio speaker (`vo.reyes.*` from
    `HeistMission.say(…, &"reyes")`).
  - Assets `asset.c4_drop`, `asset.signal_insider`, `asset.intel_route`, and the point labels.
  - Confirm the loot table (cash bricks / gold / bonds; no new ids) and $85k.
  - The Board/briefing label "Loud (ambush start)" (Open question 1).
  - The cue ids `cue.convoy_approach`, `cue.convoy_brake`, `cue.mixer_ram`, `cue.signal_click`,
    `cue.truck_doors_open` go to the lead for audio_cues v1.4. I make the sounds.
- **QC-86 (ENV D): animation and casting.**
  - Clips: a vehicle-seated idle (`sit_vehicle`), dismount (`vehicle_exit_l` / `_r`, ~1.5 s, for
    `armored_car_crew*` and the police roles), and `radio_call` standing (exists) for the marshal.
  - An optional marshal visual variant: a hi-vis tabard over the Vaultline uniform (`armored_car_crew_b`
    base) so he reads as "the advance man" at 30 m.
  - A diner cook and waitress from the generic civilian set (no new models needed if D has an apron
    variant).
  - Cower placements follow characters.md v1.9 (`cower_seated` in booths and on shelter benches;
    `cower_stand` 0.21 m in front of a wall).
- **QC-87 (lead; ENV C validator): scale and validation.**
  - (a) A new room purpose **`car_park`** with ceiling 2.2–3.0 m (car-park clear heights; `garage`
    is 3.5–6.0).
  - (b) Accept a floor reached only by road and sidewalk ramps (the −5.0 Underpass). It is listed
    for HUD names; there is no stair chain to check.
  - (c) My side: `--variants=all` also iterates the four convoy layouts as pseudo-variants
    (reachability and walkthrough per layout).
- **QC-88 (ENV A): civilians on an open street.**
  - Fleeing civilians path to `civ_flee` exits (CIVILIAN SpawnPoints tagged `civ_flee` at the
    closures) and despawn there.
  - Pedestrians use the `civilian` PatrolPoints with `walk_text`.
  - Exterior civilians who see a masked crew member call the police **by mobile phone** after the
    `phone_call` clip (no `phone` prefab in the street), on the same timing as a phone run.
- **QC-89 (ENV A): Skyway police island.**
  - One-way rappel links from the deck (+9.0) to the sidewalks (reuses QC-41's rappel), and P_SKY as
    a police-only navmesh island.
  - The Longshot at S1 on the same island.
  - Wrecker spawns restricted to vehicle-wide spawns (`wrecker_ok` tag on P_N, P_S, P_W, P_E).

## Open questions (for the lead)
1. **Mode:** `STEALTH_OR_LOUD` with no stealth win (every run ends loud), or a new `HeistMode`
   (e.g. `AMBUSH`)?
   - I propose no new mode; a run never earns the stealth bonus (S11.1: it never completes in
     stealth).
   - The Board and briefing show "Loud (ambush start)" from a `HeistDef` display tag (ENV B).
2. **Early-alarm penalty:** police at once, convoy alerted, crash stop and truck lockdown (saws
   ×1.5). Is the combination right, or too harsh?
3. **Ambush window:** 8 s (escorts seated), with dismount 4 s after the alarm. These numbers are ◇.
4. **Required loot:** 4 bags (as Dockside). Two trucks always give ≥ 7 bags.
5. **Truck numbers** (◇): the placed saw 120/180 s, the hand saw 60/90 s, C4 4 charges (PD2),
   thermite 45 s.
6. **`car_park` purpose** (QC-87a) and the ramp-only Underpass floor (QC-87b).
7. **First daylight heist:**
   - one shadowed sun plus a low-sun glare axis down Tannery;
   - glare is bloom only, never a gameplay blind;
   - OK, or should the sun be higher?
8. **Reyes in the mixer** speaks in-heist (speaker `reyes`). He is a cameo, not an NPC model:
   the mixer's cab is tinted.
9. **Perches:** S1 and S2 always on, S4 from Hazardous, S3 rare from Brutal.
10. **Vaultline** name confirmed as above (no rename).
