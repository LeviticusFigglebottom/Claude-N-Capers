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
| X-1 | all but GH | C (+B rows) | music stems + MusicDirector for ND/SL/DB/GN (tracks.tres points at missing folders) | open |
| X-2 | all but GH | C (+B rows) | ambience cues: 9 doc ambiences, SL/DB/GN have no Audio node, ND reuses GH beds | open |
| X-3 | ND, DB, GN | C markers, A rows/logic | assault events (D-114 §5); SL N/A (stealth-only) | open |
| X-4 | ND, SL, GN | A | stealth e2e flows (only GH has one) | open |
| X-5 | all | A | nav agent_radius 0.30 vs NPC capsule 0.35; tellers pushed off marks; GN StaffCO/CS/AO desk_work without seats; GH WorkshopDoor UsePoint police motor snag (7.8, z 5) | open |
| GH-1 | GH | A, P | PO6-17 logic merge; P real-input pass | in progress |
| ND-1 | ND | A | gate 2 (auto_loud, attempt 24, empty box) | open |
| ND-2 | ND | P | windowed real-input pass | open |
| SL-1 | SL | C | G2 art pass (GI, probes, occluders, dressing, review shots) | open |
| SL-2 | SL | C | D-111 props/doors/loot | landing |
| SL-3 | SL | C | VictorKessler `sit` 4.1 m from a seat; camera station seat visual; ITContractor = phone (doc change APPROVED) | open |
| SL-6 | SL | A | mission audit + stealth e2e | open |
| DB-1 | DB | C | G2 art pass | open |
| DB-2 | DB | C | D-111 doors (twin roller, cold-store slider, strongroom), launch, burn barrels, thermal drill | landing |
| DB-4 | DB | A | cartel `sit` plays no seated clip | open |
| DB-6 | DB | C, A | stale QC-36/39 TODOs (C); QC-25 S3 perch after fog lifts needs a director hook (A) | open |
| DB-7 | DB | A | mission audit + windowed auto_loud | open |
| GN-1 | GN | C | G2 (GN-C2): 50 props vs GH 628, GI/probes/occluders, moon light | open |
| GN-2 | GN | C | 5 patron spawns vs 12 in doc (7/9 rolls capped) | open |
| GN-3 | GN | C | 2 BODY_HIDE spots vs 8 | open |
| GN-4 | GN | C | 6 COVER points vs ~50 | open |
| GN-8 | GN | A | e2e stealth + loud; QC-57 Vaultline courier; 17 unsaid mission lines (D-117 §6) | open |
| GN-10 | GN | D, P | cast polish; §7 traversal tests | open |
| B-1 | all | B | D-117 names/briefing/unlocks; GH/SL/GN content gaps | DONE r216 |
| D-1 | GH | D | design manager Greta Vossberg (female) vs male civilian_manager; civilian_sales_b + clerk look | open |
| D-2 | DB | D | dock_worker, dock_worker_b, dock_packer (civ_worker wears bank outfits) | open |
| D-3 | SL, ND, GN | A | NpcVisualTweak maps: SL Northgate guards/cleaner/Helena Moor; ND night manager + armored_car_crew; GN civ_admin → gallery_admin | open |
| D-4 | all | D props, A attach | hand props (phone, mop, mug, cigarette, tray) not attached; no phone/cigarette asset | open |
| D-5 | DB, SL, GN | A | unmapped clips: `look` pause, SL seated `desk`, GN curator_inspect / walk_text / smoke | open |
| D-6 | all | D | cast file for GH/ND/SL/DB + test: every design role has a character | open |
| D-7 | GH (PO6-17) | C | heli cabin roof +0.1 m + SniperKneel marker | open |
