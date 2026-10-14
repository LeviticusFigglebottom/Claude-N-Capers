# PO-9 dressing audit: furniture logic on the four heists

Product owner (D-105): "unnatural prop placement (two chairs facing each other in front of a desk)".
Owner: ENV C. Rule: `validate_level` check `furniture_logic` (spec and tolerances in
`tools/levelcheck/README.md`). Fixes go in the generators and kits, never in the generated scenes.

## Why the existing `orientation` check missed it

`orientation` (final stage only) trusts the authored `faces` meta. It checks that a chair's −Z points
at the centre of the node its `faces` link names, within ±20°. The Glasshouse U6 visitor chair was linked
to the manager's desk and pointed at it, so it passed. The check never asks:

- which side of the desk the chair is on (knee hole or modesty panel side);
- what kind of chair it is (desk chair or visitor chair);
- whether two seats face each other.

A chair with no link only fails within 1 m of a desk. The two greybox maps (Dockside Burn, Shadow
Ledger) never run `orientation` at all. `furniture_logic` runs at every stage. It ignores `faces` and
infers each seat's nearest desk, table or counter, the seat's facing and the desk's user side from
geometry and prop ids.

## Before → after (furniture_logic, all variants)

| heist | before | after | validate_level (all 25 checks, --variants=all) |
|---|---|---|---|
| glasshouse (final) | 2 FAIL | 0 | PASS |
| night_deposit (final) | 4 FAIL | 0 | PASS |
| dockside_burn (greybox) | 1 FAIL | 0 | PASS |
| shadow_ledger (greybox) | 0 FAIL, 3 WARN | 0 FAIL, 2 WARN after follow-up #10 (the gondola cradles, by design) | PASS |

Follow-ups #8–#10 (lead-assigned) re-ran validate_level on glasshouse (final) and shadow_ledger (greybox)
with `--variants=all`. Both PASS. Glasshouse furniture_logic has 0 FAIL / 0 WARN. Shadow Ledger
furniture_logic has 0 FAIL and only the 2 cradle WARNs.

## Findings and fixes

| # | heist / spot | finding | how found | fix (source file) | images |
|---|---|---|---|---|---|
| 1 | Glasshouse U6 manager's office | The only chair at the executive desk was a visitor chair standing at the knee hole, the drawer side, facing the drawers. The manager had no chair, so it read as two chairs facing each other with the desk between. `seat_side` caught it. | rule + shots | Desk turned 180° so the manager's side faces ManagerDoor with his back to the windows. This matches the Manager NPC spawn (9.5, 9.85, facing the door). His office chair is rolled out to the east end of the knee-hole side, clear of the NPC spot. Two visitor chairs go across the desk on the modesty-panel side, toed in, clear of the kc_manager UsePoint (`glasshouse_layout.gd` ANCHORS). | `glasshouse/po9/gh_u6_manager_desk_{before,after}.jpg`, `gh_u6_from_windows_{before,after}.jpg` |
| 2 | Glasshouse U5 admin office | The sales-admin desk chair stood 0.11 m into the PhoneAdmin UsePoint (`use_point`). The code_admin note's UsePoint is on its other side, and the desk's colliders leave no room to tuck the chair in between the two. | rule | The chair is pushed back from the desk (4.15 / 7.65), as if someone just stood up, clear of both standing spots (`glasshouse_layout.gd`). | `glasshouse/po9/gh_u5_admin_chair_{before,after}.jpg` |
| 3 | Night Deposit G8 teller line | All four teller stools faced the back wall, 165–172° away from their counter (`seat_facing`). | rule | Stools turned to face their counter. They stay parked off the staff walkway (`night_deposit_dressing.gd`). | `night_deposit/po9/nd_g8_teller_stools_{before,after}.jpg` (round stools: the change shows in the base and foot-ring) |
| 4 | Dockside Burn M1 count room | The counting table covered the CageCashA UsePoint by 0.20 m, so the user would stand inside the table (`use_point`). | rule | Table and its chair moved 0.35 m east (`dockside_burn_layout.gd`). | `dockside_burn/po9/db_m1_counting_table_{before,after}.jpg` |
| 5 | KitPlacer rule (every kit room) | Visitor chairs (`seat_side: "back"`) could be placed on either end of a desk, where two of them face each other across it. That is the product owner's arrangement. | code review | `kit_placer.gd` `_try_seat`: at a desk, visitors sit only on the far side and spread along it; the ends stay legal only around tables. No current room changed, because the existing offices anchor their chairs, but every future kit room (Gallery Night) gets it right. | – |
| 6 | Glasshouse U4 upper corridor (drift, determinism commit) | After the determinism regen, a kit picture hung over the stair void, where the wall has a gap the kit room did not know about (`floating`). | validate_level | `gh_dress.gd` `_room_gaps`: interior wall gaps become full-height openings in the KitRoom. | – |
| 7 | Night Deposit X1 lot (drift, determinism commit) | A facade-backed crate sat inside the 0.05 m granite plinth (`zfight`). | validate_level | `KitRoom.relief` plus `nd_dress.gd` `PLINTH_RELIEF`: floor props backed against the facade stand in front of the plinth. | – |
| 8 | Glasshouse U2 security office (follow-up) | The camera-station console had no seat. The CameraOperatorSeat NPC stood at it, and the only office chair belonged to the kit's guard desk beside it. | audit | Done the D-063 way, as at Night Deposit. A `prop_chair_task` NPC seat (OperatorChair) now stands on the CameraOperatorSeat spawn (6.85, 4.2, 2.0), facing the console (yaw 90, `faces` → CameraStation). It has no collider and no navmesh obstruction, so the seated operator owns it (`gh_dress.gd` `NPC_SEATS`, the `faces_node` meta). The NPC seat fills the kit's required chair, so the guard desk and its office chair are now anchored where the kit had put them (`glasshouse_layout.gd` ANCHORS). | `glasshouse/po9/gh_u2_operator_seat_{before,after}.jpg`, `gh_u2_operator_seat_side_{before,after}.jpg` |
| 9 | Shadow Ledger tables (follow-up) | The conference room, break room, dining room and boardroom had tables with no chairs. | audit | 25 greybox chairs, each 0.225 m off its table edge and facing it (`shadow_ledger_layout.gd` CHAIRS). K2 conference: 3 a side; the south end is the door zone. K18 break room: 2 on the counter side and 1 at each end; the K18Break patrol spot is north. M8 dining: 2 a side and 1 at each end; the M8Dining patrol spot is south of the middle. M14 boardroom: 4 a side and the head at the north end; the south end is the door and patrol spot. seat_pair passes because a table lies between every pair of facing seats. | `shadow_ledger/po9/sl_{k2_conference,k18_break,m8_dining,m14_boardroom}_chairs_{before,after}.jpg` |
| 10 | Shadow Ledger K11 server cage (follow-up) | `Gameplay/Server/HackTerminal` stood 0.09 m into the CageGate's door zone (WARN). Its back already touched the cage's north panel, so it could not move north on its own. | rule | The cage's north panel moves 0.1 m north (`CAGE` box z 8.5 → 8.4, `shadow_ledger_layout.gd`). The terminal moves from z 9.05 to 8.95 (`sl_gameplay.gd`). It is now clear of the door zone and clear of the panel (clipping PASS). Its UsePoint moves with it and stays reachable: walkthrough ok, test_interact_slots_clear passes. | – (the closed gate blocks the view from the corridor) |
| 11 | Shadow Ledger remaining tables (follow-up) | Moor's meeting table (K5), the interview table (K24) and the pantry table (M11) had no chairs. | audit | 9 greybox chairs, each 0.225 m off its table edge and facing it (`shadow_ledger_layout.gd` CHAIRS). K5: north, west and east. The south side is 0.2 m off the wall. The phone, bracelet and code-note UsePoints at z 3.05 stay clear. K24: the classic interview layout, with the interviewee on the door side and two interviewers across the table. The K24Interview patrol spot inside the door stays clear. M11: west, east and south. The M11Pantry patrol spot and the phone are on the north side, and the west seat is outside the PantryDoor clear zone. | `shadow_ledger/po9/sl_{k5_moor_meeting,k24_interview,m11_pantry}_chairs_{before,after}.jpg` |
| 12 | Shadow Ledger desks (follow-up) | The room-list scan found 11 SL desks with no seat: the two K4 assistant desks, the three K8 open-office pods, the two K12 IT desks and the K20–K23 associates' desks. | audit (room list + desk/table scan) | 20 greybox chairs (`shadow_ledger_layout.gd` CHAIRS). K4: one chair behind each desk with its back to the window, as at Kessler's and Moor's desks; the phone UsePoint is on the room side. K8: four seats per 2.4 × 1.6 pod. Pod A's north pair sits 0.3 m and 0.1 m east of its desk centres, clear of the K8North patrol spot by the north door. K12: both desks are worked from the north side. Desk A's seat is rolled to the west end, out of the ITDoor swing. Desk B's seat is between the desks, east of the K12IT patrol spot. The kc_it, PhoneIT and code-note UsePoints stay clear. K20–K23: each desk is 0.65 m off the window, too close for a chair behind it, so the seat is on the room side, facing the desk and the window. | `shadow_ledger/po9/sl_{k4_assistant,k8_open_office,k8_open_office_nw,k12_it,k21_associate}_chairs_{before,after}.jpg` (K21 stands for K20–K23) |
| 13 | Dockside Burn O1 reception, gatehouse (follow-up) | The O1 reception counter had no seat for the receptionist, and the gatehouse console had no seat for the gate man. | audit | 2 greybox chairs (`dockside_burn_layout.gd` CHAIRS). One is on the staff side of the reception counter; the DeskCashO1 UsePoint is on the front-door side. The other is at the console, facing the window, clear of both gatehouse door zones. | `dockside_burn/po9/db_{o1_reception,gatehouse}_chairs_{before,after}.jpg` |

## Reported, not changed

- **WARN door_clear (Shadow Ledger).** Both gondola `CradleDeck`s sit outside their facade doors. This
  is by design: you step from the cradle into the door. They are variant content, so the check only
  warns on them. The HackTerminal WARN is fixed (#10).
- The Shadow Ledger table chairs and the Glasshouse U2 operator seat were first reported here. They are
  now fixed (#8, #9). The other Shadow Ledger tables (pantry, interview room, Moor's meeting table) and
  the unseated SL desks are fixed in #11 and #12, and two Dockside Burn seats in #13.
- **Seat scan, not changed** (every desk, table and counter on the four maps, by room):
  - **Glasshouse G2 jeweler's benches** have no stools. The kit's stool is at the polishing
    workbench. Stools were tried, but the bench fronts are mission standing spots: the
    `jw_working` Jeweler at (8.5, 1.45), the `code_jeweler_notebook` UsePoint at (8.2, 1.45) and the
    `kc_jeweler` UsePoint at (9.75, 1.45). A stool there fails `use_point`, and its collider moves
    the Jeweler off the navmesh. This needs a mission-side move of those spots (ENV A / lead) first.
  - **Shadow Ledger K13 camera station**: the CAMERA_OPERATOR NPC works it standing. A greybox
    chair has a collider, which would push the NPC off its spot. The collider-less NPC seat (as at
    Glasshouse U2, #8) is for SL's G2 dressing pass.
  - **Standing-height work surfaces** need no seat: the sales, service and kitchen counters (GH G5,
    ND G4, the SL K13 security counter, the SL terrace kitchen), the ND G9 check-writing tables
    (1.1 m), the GH U5 appraisal workbench (1.0 m), the DB tool and packing benches, and the SL M1
    home bar between its sofas.
  - **Night Deposit B9 inspection table**: it stands inside the box vault. The seat for viewing
    is the B8 viewing bench outside it.
- **Glasshouse G9 janitor closet.** The mop sink is 0.21 m into the 1 m door zone. A 1.3 × 1.3 m
  step-in closet cannot keep 1 m clear, so the rule keeps only 0.6 m on the side of rooms under
  2.5 m². With that, the sink passes.

## Visual audit (review shots, opengl3 + xvfb)

These rooms were rendered from two opposite corners each and looked at, beyond what the rule covers:

- Glasshouse: G1, G2, G5, G6, U1, U2, U5, U6, U7.
- Night Deposit: G3, G4, G8, G11, G12, B11.
- Dockside Burn: O1, O2, M1, M2; the gatehouse (#13, one view).
- Shadow Ledger: K1, K3, K18, M1, M7, M8; K4, K5, K8 (two views), K12, K21, K24 and M11 (#11, #12, one view each).

Nothing else was implausible enough to move: no floating chairs, no monitors facing walls and no bins
in doorways. The G11/G12 loan and manager offices have their officer behind the desk and two visitors
in front. The break rooms have four chairs set round their tables.

The after shots were taken before the final PO-7 merge, which did not change these rooms. The
Night Deposit G8 credenzas differ between the two shots because of the one-time determinism drift.

## Rule summary

See `tools/levelcheck/README.md` (furniture_logic row). Fail-level rules:

- seat_facing (1.2 m, 45°)
- seat_side
- seat_pair (2.4 m, 45°, no table between)
- door_clear (leaf width × 1.0 m each side, 0.6 m into rooms under 2.5 m², intrusion > 0.05 m)
- use_point (0.4 × 1.4 × 0.4 m standing box, > 0.05 m)
- duplicate (≤ 5 cm, ≤ 5°)
- wall_back (wall units back within 0.15 m; nothing facing the shell closer than 0.1 m for seats, 0.3 m for monitors, 0.15 m for wall units)

Warn-level:

- overlap (visual boxes interpenetrating > 5 cm). The boxes of L-shaped and open furniture overlap legitimately, and the clipping check already fails real collider penetration.
- door_clear and use_point on gameplay prefabs and variant content.
