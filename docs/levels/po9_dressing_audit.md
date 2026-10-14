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
| shadow_ledger (greybox) | 0 FAIL, 3 WARN | 0 FAIL, 3 WARN (gameplay prefabs, for review) | PASS |

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

## Reported, not changed

- **WARN door_clear (Shadow Ledger).** Gameplay content inside a door's clear zone:
  - `Gameplay/Server/HackTerminal` is 0.09 m into the CageGate zone.
  - Both gondola `CradleDeck`s sit outside their facade doors. This is by design: you step from the cradle into the door.

  They are mission placements (sl_gameplay.gd, shared with ENV A), so the check only warns on them.
- **Shadow Ledger greybox has very few seats** (4 chairs in the whole building). The dining room, the
  boardroom, the conference room and the break room have tables without chairs. This is expected at
  greybox stage and belongs to SL's G2 dressing pass; furniture_logic will check it then.
- **Glasshouse U2 security office.** The camera-station console has no seat. The CameraOperatorSeat NPC
  stands there and the only office chair belongs to the kit desk beside it. Night Deposit solves this
  with an NPC seat without a collider (D-063, `nd_dress.NPC_SEATS`). Porting that to gh_dress needs a
  check of the operator's animation, so it is left for the lead / ENV A.
- **Glasshouse G9 janitor closet.** The mop sink is 0.21 m into the 1 m door zone. A 1.3 × 1.3 m
  step-in closet cannot keep 1 m clear, so the rule keeps only 0.6 m on the side of rooms under
  2.5 m². With that, the sink passes.

## Visual audit (review shots, opengl3 + xvfb)

These rooms were rendered from two opposite corners each and looked at, beyond what the rule covers:

- Glasshouse: G1, G2, G5, G6, U1, U2, U5, U6, U7.
- Night Deposit: G3, G4, G8, G11, G12, B11.
- Dockside Burn: O1, O2, M1, M2.
- Shadow Ledger: K1, K3, K18, M1, M7, M8.

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
