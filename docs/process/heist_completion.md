# Heist completion (D-115): finish every existing heist before a new one

Owner: LEAD. Each env audits its slice of every heist against `docs/design/heists/<id>.md` and the D-115 "done" list,
and reports a gap list; the LEAD folds the gaps in here as rows (id, heist, owner, gap, status).

| Heist | Id | Stage today | Remaining to "done" (D-115) |
|---|---|---|---|
| Golden Hour | glasshouse | final art; gates 1+3 passed | PO6 list items; assault events wired (PO6-17); polish |
| Nightfall Depository | night_deposit | final art | gate 2 (`auto_loud`, attempt 24 on an empty box); assault events rows |
| Gallery Night | gallery_night | G1 greybox + full mission logic | G2 art (GN-C2); e2e stealth + loud (GN-A1); cast polish (GN-D1); P windowed pass (GN-P1); B briefing/strings (GN-B1, GN-U5 objective list) |
| Dockside Burn | dockside_burn | greybox + material pass | D-111 props/doors/loot (wip/c-sldb-props); G2 art; mission audit vs design doc; e2e flows; cast tags; strings; P pass |
| Shadow Ledger | shadow_ledger | greybox + material pass | same as Dockside Burn |

## Gap rows
| id | heist | owner | gap | status |
|---|---|---|---|---|
| X-1 | all but GH | C (+B rows) | music stems + MusicDirector for ND/SL/DB/GN (tracks.tres points at missing folders) | done (round 221) |
| X-2 | all but GH | C (+B rows) | ambience cues: 9 doc ambiences, SL/DB/GN have no Audio node, ND reuses GH beds | done (round 221) |
| X-3 | ND, DB, GN | C markers, A rows/logic | assault events (D-114 §5); SL N/A (stealth-only) | done: markers (C, earlier) + rows 07c1adf9 + test_x3 8293bb60 (round 223) |
| X-4 | ND, SL, GN | A | stealth e2e flows (only GH has one) | done: test_x4_nd/sl/gn_stealth (A ec76d360, round 223); GN curator-keycard variant test_x4_gn_curator_keycard (A 5138fdb1, round 224) |
| X-5 | all | A | nav agent_radius 0.30 vs NPC capsule 0.35; tellers pushed off marks; GN StaffCO/CS/AO desk_work without seats; GH WorkshopDoor UsePoint police motor snag (7.8, z 5) | done: nav doorway test, mark-return for tellers, GN seats (A 61900a46/2727f197, round 223); x5 GH police flake not reproducing (A, 3/3 green under load; reopen if seen) |
| GH-1 | GH | A, P | PO6-17 logic merge; P real-input pass | in progress |
| ND-1 | ND | A | gate 2 (auto_loud, attempt 24, empty box) | open |
| ND-2 | ND | P | windowed real-input pass | open |
| SL-1 | SL | C | G2 art pass (GI, probes, occluders, dressing, review shots) | open |
| SL-2 | SL | C | D-111 props/doors/loot | items 1-4 done (on trunk); OPEN item 5: secure-drop/net/cart visuals, laser emitters, zipline anchors |
| SL-3 | SL | C | VictorKessler `sit` 4.1 m from a seat; camera station seat visual; ITContractor = phone (doc change APPROVED) | open |
| SL-6 | SL | A | mission audit + stealth e2e | done (A 47d08435 + camera_warning poll, test_sl6_*) |
| DB-1 | DB | C | G2 art pass | done: G2 FINAL (C 40274739, round 227); chamber variety + trawler/crane art follow-ups |
| DB-2 | DB | C | D-111 doors (twin roller, cold-store slider, strongroom), launch, burn barrels, thermal drill | done (9fbc1930, 1be2c23d, e8da2cba, 262e4b3e); wip/c-sldb-props superseded |
| DB-4 | DB | A | cartel `sit` plays no seated clip | done (A c5d4563d, test_db4_cartel_seated) |
| DB-6 | DB | C, A | stale QC-36/39 TODOs (C); QC-25 S3 perch after fog lifts needs a director hook (A) | A side done (e13f762f, test_db6_fog_perch); C TODOs open |
| DB-7 | DB | A | mission audit + windowed auto_loud | open |
| GN-1 | GN | C | G2 (GN-C2): 50 props vs GH 628, GI/probes/occluders, moon light | done: G2 FINAL (C 8a7872c4, round 224); gala dressing top-up optional |
| GN-2 | GN | C | 5 patron spawns vs 12 in doc (7/9 rolls capped) | done (round 219) |
| GN-3 | GN | C | 2 BODY_HIDE spots vs 8 | done (round 219) |
| GN-4 | GN | C | 6 COVER points vs ~50 | done (round 219) |
| GN-8 | GN | A | e2e stealth + loud; QC-57 Vaultline courier; 17 unsaid mission lines (D-117 §6) | mostly done (A 31fcaab4: courier carry + empty-slot alarm, D-117 lines locked, B GN a-d, loud e2e wins on 4242 / 1792002290). OPEN: signal-11 engine crash at LOUD→ESCAPE, GN seed 99 (threaded load suspected); inspectors' empty-slot alarm (B3) not implemented; GN loud pilot loses often (harness) |
| GN-10 | GN | D, P | cast polish; §7 traversal tests | done (round 222, pending tests); GN look map after D lands |
| B-1 | all | B | D-117 names/briefing/unlocks; GH/SL/GN content gaps | DONE r216 |
| D-1 | GH | D | design manager Greta Vossberg (female) vs male civilian_manager; civilian_sales_b + clerk look | done (round 220) |
| D-2 | DB | D | dock_worker, dock_worker_b, dock_packer (civ_worker wears bank outfits) | done (round 220) |
| D-3 | SL, ND, GN | A | NpcVisualTweak maps: SL Northgate guards/cleaner/Helena Moor; ND night manager + armored_car_crew; GN civ_admin → gallery_admin | done (round 222, pending tests); GN look map after D lands |
| D-4 | all | D props, A attach | hand props (phone, mop, mug, cigarette, tray) not attached; no phone/cigarette asset | done (D round 220; A attach 1f5ecc5a, test_d115_cast_hand_props) |
| D-5 | DB, SL, GN | A | unmapped clips: `look` pause, SL seated `desk`, GN curator_inspect / walk_text / smoke | done (round 222, pending tests); GN look map after D lands |
| D-6 | all | D | cast file for GH/ND/SL/DB + test: every design role has a character | done (round 220) |
| D-7 | GH (PO6-17) | C | heli cabin roof +0.1 m + SniperKneel marker | done (round 220) |
| A-DB | DB | A / C | A audit (full table: docs/status/env_a.md on env/a-core 4aca399f): DB-1 no assault events (C markers, A rows); DB-2 contraband counts toward the 4 required bags (A); DB-3 cartel reinforcements spawn as plain guards (A); DB-4 thermite bag ignores chosen spawn (C+A); DB-5 count-cage drill 180 s vs doc 120 s (C); DB-6 briefing lines in-mission (A VO lane); DB-7 no music (C); DB-8 padlocks: placed saw 30/45 s per doc (LEAD ruling: doc wins, DB is loud-only); minors 8-19 in A's table | open |
| A-SL | SL | A / C / B | SL-1..SL-11 (A's 10-15 audit) | done: A confirmed SL-1 3f64d707, SL-2 camera_warning poll, SL-5 MIN_DRIVES=2, SL-6 47d08435, SL-9 lasers poll; SL-4/SL-11 music/ambience done (X-1/X-2); SL-3 literal briefing string → C; SL-7/SL-8 C |
| B-GN | GN | B (A for logic) | D-115 strings audit vs design doc: briefing, objective lines in order (GN-U5), loot names/values, contact lines, payday (GN-B1) | open |
| B-DB | DB | B (A for logic) | D-115 strings audit vs design doc (as B-GN) | open |
| B-SL | SL | B (A for logic) | D-115 strings audit vs design doc (as B-GN) | open |
| ND-3 | ND | C | secure van at (9, 0, 30): last ~15 m of carry route has no cover (P ND-2: 7 downs in 25 s vs 4-7 enemies); add cover props | open |

