# Heist gap audit for D-115 (ENV C, read-only, 2026-10-15)

> Filed by the LEAD into `docs/process/heist_completion.md`. Status since the audit (env/c-worlds):
> GH-1 / GN-5 / DB-4 seats fixed (6738c290), GH-2 roof rappel + bounds fixed (88b5768d), SL-2 / DB-2 D-111 props
> merged, SL-3 ITContractor = phone (approved), SL-5 ruled N/A (D-115). The remaining rows follow the approved order.

**Scope.** I compared each heist's design doc and level docs against its generator tables and the generated `.tscn`.
The tree is `env/c-worlds` @ 4cd43e2f plus uncommitted glasshouse WIP (see GH-2).

**D-115 location.** D-115 and `docs/process/heist_completion.md` exist only on the lead branch
`origin/claude/epic-fermi-k5fa09` (decisions.md:914). They are not on this branch yet.

**How the map numbers were taken.** Node counts come from two headless scripts, kept in this scratchpad:
`audit_maps.gd` (outputs `audit_out.txt`) and `audit_state.gd` (outputs `audit_state.txt`).
- The scripts read the maps through `SceneState`, plus one instantiate pass for the `Seat` markers.
- Seat rule (PO6-06, `StealthTweak.civilian_seat_radius_m` = 0.45): a seated idle counts as served only if a `Seat`
  marker lies within 0.45 m of the spawn.

**Owners.** `owners.json` lists `game/world/heists/**` under both A and C. By convention, C owns the builders,
layout tables, art, markers and audio files; A owns `*_mission.gd`, systems and HeistDef logic.
`game/world/audio/cues.tres` is B's file.

## Cross-cutting (all heists)

| gap | doc reference | evidence (file:line) | owner | size |
|---|---|---|---|---|
| Music stems exist only for Golden Hour. `tracks.tres` points ND/SL/DB/GN at `res://world/audio/music/<id>`, but those folders do not exist. | each doc §Audio/lighting "Music:" (ND:546, SL:772, DB:774, GN:948) | `game/world/audio/music/tracks.tres:15,22,30,58`; only `world/audio/music/glasshouse/` and `assets/audio/music/glasshouse/` exist | C (audiogen) | L (4 tracks) |
| Per-heist ambience cues are missing. The registry has only `cue.amb_glasshouse_interior` and `cue.amb_street_dusk`. | ND §Audio (`amb_bank_night_interior`, `amb_harbor_night`); SL (`amb_shadow_ledger_interior`, `amb_rooftop_rain`); DB (`amb_cold_store`, `amb_dockside_fog`); GN (`amb_gallery_gala`, `amb_art_store`, `amb_uptown_night`) | `game/world/audio/cues.tres:225-226,1762`; ND stands in GH cues (`nd_art.gd:873-887`) | C (sounds) + B (`cues.tres` rows) | M |
| No HeistDef assault-event rows on any heist, GH included. `assault_events` appears only in GH layout, `gh_assault.gd`, C tests and the review tool. | D-114 §5, PO6-17, D-115 item 6 | `grep assault_event game/systems` = 0 hits | A | L |
| Only GH has a stealth e2e flow (`po5_flow_gh_stealth.gd`). Every other heist relies on the generic `auto_loud`. | D-115 item 3 | `game/tests/a/e2e/` | A | M per heist |
| PO6-05 is OK on every map: each `safe` holds its loot as children and no loot sits within 2 m outside a safe. Two exceptions are by design: SL cage drives and DB count-cage cash are siblings of their cage lock, not inside a safe body. | po_playtest PO6-05 | `audit_state.txt` (safe lines) | — | — |

## 1. Golden Hour (`glasshouse`): stage **final** (G2), gates 1+3 passed

Stage evidence: `stage.txt` = final; HEAD `validation.md` PASS.
- Every variant group in the doc's Variable table is present. The map also has `estate`, `manager_present` and
  `safe_state` groups for rare events.
- Counts: 6 ENTRY + 1 RAPPEL + 2 SNIPER_PERCH, 4 POLICE spawns, 6 cameras, 125/125 lights `viewmodel_lit`.
- `AssaultEvents/` has 9 committed markers (plus `RoofRappelAlley`, still uncommitted).

| gap | doc reference | evidence (file:line) | owner | size |
|---|---|---|---|---|
| GH-1 Five seated spawns have no `Seat` within 0.45 m, so they fall back to standing: CivCounterAssociate `desk_work` (nearest seat 7.3 m), Jeweler ×2 `desk_work` (6.2 m), AdminClerk `desk_work` (1.5 m: chair offset), Customer `cust_3` `sit` (6.6 m). | PO6-06; glasshouse.md:200 room list (G2 benches, U5 desk, G5 consult chair) | `glasshouse_layout.gd:483`; `build_greybox.gd:1296,1302,1306,1347` | C (stools/chairs with `Seat`, or move the spawns onto chairs) | S |
| GH-2 Uncommitted PO6-17 WIP: the new `RoofRappelAlley` link makes `bounds` FAIL in the working tree (46 void rays from roof eyes at y 9.65). HEAD passes. | level_standards §7 | `glasshouse_layout.gd:630` (diff); working `docs/levels/glasshouse/validation.md:222-234` | C | S |
| GH-3 Assault-event logic is missing: van arrival, turret, heli orbit and drop, breach blow, nav links. The props and markers are done. | PO6-17; `docs/levels/_art/po6_17/README.md` §6 "Not done here" | no consumer of `AssaultEvents` in `game/systems` | A (D: rope/rappel clips) | L |
| GH-4 The remaining PO6 list (01-03, 08, 14-20) is A/B/P and tracked on the board. Its windowed acceptance needs a real-input P pass. | D-115 items 4-5 | `po_playtest_2026-10-15.md` | A/B/P | M |

Suggested order: GH-2 → GH-1 → (A) GH-3 → P pass.

## 2. Night Deposit (`night_deposit`): stage **final** (G2), gate 2 open

Stage evidence: `stage.txt` = final; `validation.md` PASS (14 floating warnings, all runtime-visual prefabs).
- All Variable-table groups are present, including the `armored_car` rare event.
- Counts: 8 ENTRY, 1 RAPPEL, 1 FLANK, 2 SNIPER_PERCH, 4 POLICE spawns, 12 cameras, 8 deposit boxes,
  `bag_lift` (cash lift).
- Both seated spawns (operator, night manager) have seats.
- `DepositorySafe` holds NightDropBags ×4 inside; `ManagerSafe` holds small_loot ×4 inside.

| gap | doc reference | evidence (file:line) | owner | size |
|---|---|---|---|---|
| ND-1 No `AssaultEvents` node: no TurretVan, HeliOrbit/Drop or Breach markers, and no breach openings in the layout. | PO6-16/17, D-115 item 6; README §5 (GH only) | root children of `night_deposit.tscn` have no `AssaultEvents` | C (markers + openings, same pattern as `gh_assault.gd`) | M |
| ND-2 ND assault-event rows and logic | same | — | A | M |
| ND-3 Gate 2 (`auto_loud` win) still open: attempt 24 hit an empty box. | heist_completion.md (lead branch) | board r174/r186 | A | M |
| ND-4 No `MusicDirector` and no ND stems. The ambience beds use GH cues. | night_deposit.md:531-549 | `nd_art.gd:873-874,882-887` | C (+B cues) | M |
| ND-5 No stealth e2e flow (ND is stealth+loud). | D-115 item 3 | `game/tests/a/e2e/` | A | M |
| ND-6 P windowed real-input pass (no STUCK/snag rows) | D-115 item 4 | — | P | S |

Suggested order: ND-3 (A), with ND-1 in parallel (C) → ND-2 → ND-4 → ND-5/ND-6.

## 3. Shadow Ledger (`shadow_ledger`): stage **greybox** (G1) + material pass; stealth-only

Stage evidence: `stage.txt` = greybox; `validation.md` header "(greybox)"; materials, density, variety, bounds,
perf, lights and zfight are all skipped.
- All 15 variant groups in the doc are present.
- Counts: 11 ENTRY + 1 RAPPEL (doc: no perches), 4 POLICE spawns, 18 cameras, 3 laser grids, 1 zipline,
  5 ladders.
- Loot matches the doc: laptop ×4 slots, drives ×3, ledger books, 2 paintings, archive cash, printout,
  7 small_loot.

| gap | doc reference | evidence (file:line) | owner | size |
|---|---|---|---|---|
| SL-1 **G2 art pass not started:** 0 VoxelGI / 0 ReflectionProbe / 0 Occluder (GH has 1/18/14), 3 `world/props` refs in the map (GH has 145), no dressing kits, no review shot set. | level_standards §1 G2; shadow_ledger.md:749-776 | `shadow_ledger.tscn` node counts; `stage.txt` | C | L |
| SL-2 D-111 door, loot, drill and painting art sits on an **unmerged** branch and was never regenerated (determinism test red until it is). | D-111; heist_completion row | `origin/wip/c-sldb-props` fd701863, d257bc58 ("NOT regenerated") | C | M |
| SL-3 Seated spawns without seats: the CameraStation has no `visual_scene`, so it has no `Seat` (nearest 6.3 m); VictorKessler `sit` (4.1 m); ITContractor `desk_work` (7.0 m). | PO6-06; SL room list (K13, K1, K11) | `shadow_ledger.tscn:20101`; `sl_gameplay.gd:237,352,376`; `shadow_ledger_layout.gd:597` | C | S |
| SL-4 No `Audio` node (ambience beds, CuePlayer), no ambience cues, no music stems. | shadow_ledger.md:749-776 | root children (no `Audio`); `tracks.tres:22` | C (+B cues) | M |
| SL-5 D-115 item 6 (assault events) does not apply to a stealth-only heist: no loud phase (shadow_ledger.md:630). Needs a lead ruling to mark it N/A. | D-115 item 6 | — | LEAD | S |
| SL-6 Mission audit against the doc (295-line mission), plus a stealth e2e flow (none exists). | shadow_ledger.md:664-688; D-115 items 1, 3 | `shadow_ledger_mission.gd`; `game/tests/a/e2e/` | A | M |
| SL-7 Cast/tag map check for the K&M staff, Kessler, contractor and cleaners; then the P windowed pass. | D-115 items 4-5 | — | D, P | S |

Suggested order: SL-2 (merge + regenerate) → SL-3 → SL-1 (GI/probes/occluders, kits, review shots) → SL-4 →
SL-5 ruling → SL-6/SL-7.

## 4. Dockside Burn (`dockside_burn`): stage **greybox** (G1) + material pass; loud-only

Stage evidence: `stage.txt` = greybox; final-stage validator checks skipped.
- All 12 variant groups in the doc are present.
- Loud set: 6 POLICE spawns, 25 ENTRY, 3 RAPPEL, 5 FLANK, 5 SHIELD_ANCHOR, 24 COVER, 4 SNIPER_PERCH
  (S3/S4 as rare slots).
- No cameras and no BODY_HIDE, which is correct for loud-only (dockside_burn.md:612).
- `DispatchSafe` holds small_loot ×3 inside.

| gap | doc reference | evidence (file:line) | owner | size |
|---|---|---|---|---|
| DB-1 **G2 art pass not started:** 0 VoxelGI / 0 probes / 0 occluders, 1 `world/props` ref, no kits, no review set. | level_standards §1 G2; dockside_burn.md:748-831 (Audio/lighting, Review shots) | `dockside_burn.tscn` counts; `stage.txt` | C | L |
| DB-2 D-111 industrial doors (twin roller, cold-store slide, strongroom vault), launch vehicle, burn barrels, drill device and loot art: unmerged and not regenerated. | D-111 | `origin/wip/c-sldb-props` d257bc58 | C | M |
| DB-3 No `AssaultEvents` node. This loud-only heist needs the most: van park spots on Ferro St / the lane, heli orbit over the yard, breach markers on the office block and the warehouse. | PO6-16/17, D-115 item 6 | root children (no `AssaultEvents`) | C markers, A rows/logic | M + M |
| DB-4 Seated spawns without seats: GunmanPlatformA/B `sit` (3.1 m / 1.2 m). | PO6-06 | `dockside_burn_layout.gd:695` | C | S |
| DB-5 No `Audio` node, no ambience cues, no music stems. | dockside_burn.md:748-797 | `tracks.tres:30` | C (+B cues) | M |
| DB-6 Stale TODOs: QC-36 is shipped (`systems/ai/cartel/cartel_brain.gd`) and QC-39 is shipped (`content/data/loot/weapon_crate.tres`, `contraband.tres`). QC-25 (S3 perch valid only from the `fog_lifts` time) still needs a director perch-enable hook. | dockside_burn.md:669-678, 909-913 | `db_gameplay.gd:352,528`; `dockside_burn_resources.gd:31`; `dockside_burn_mission.gd:254` | C (comments), A (perch hook; confirm the cartel spawn uses `cartel_brain`) | S |
| DB-7 Mission audit against the doc (burn/shutters/fire volume, `police_delay`, rare events present in `dockside_burn_mission.gd:44-48,204-246`); windowed `auto_loud` win. | D-115 items 1, 3 | — | A | M |
| DB-8 Cast tags (cartel gunmen, night shift); P pass. | D-115 items 4-5 | — | D, P | S |

Suggested order: DB-2 → DB-4/DB-6 → DB-1 → DB-3 (markers, then A) → DB-5 → DB-7/DB-8.

## 5. Gallery Night (`gallery_night`): stage **greybox** (G1) + full mission logic; GN-C2 props lane partly in

Stage evidence: `stage.txt` = greybox; `validation.md` PASS at greybox with 4 floating warnings.
- All 18 slot groups in `GROUP_ORDER` are present. Scalars are handled by the mission.
- Loud contract: police P1-P5 (`gallery_night_layout.gd:730-736`); 11 ENTRY, RAPPEL, 2 FLANK, 4 anchors, 2 perches
  (`gn_npc.gd:179-205`); oculus and roof-drop nav links (`layout.gd:353-357`).
- 20 cameras; 54/54 lights `viewmodel_lit`.
- Loot: the 4 listed canvases × 3 slots, 23 studies, 8 lockers. `CuratorSafe` holds small_loot ×3 inside.

| gap | doc reference | evidence (file:line) | owner | size |
|---|---|---|---|---|
| GN-1 **G2 art pass (GN-C2) incomplete:** 0 VoxelGI / 0 probes / 0 occluders; only 50 nodes under `Props` (GH has 628); no DirectionalLight / moon; final-stage checks skipped. The GN-C2 props lane has merged (shutters, roller, grate, lift, racks, limo, canvases, safe, boxes); room dressing has not. | level_standards §1 G2; next_heist §6 GN-C2; gallery_night.md:919-1008 | `gallery_night.tscn` counts; `stage.txt` | C | L |
| GN-2 Patron spawns: the map has 5 (GH×2, WG, EG, court); the doc places 12 (GH×4, WG×2, EG×2, EB×2, court×2). The `patrons` roll of 7/9 is silently capped at 5 by `thin_civilians`. | gallery_night.md:519, 832 (`patrons` 3/5/7/9) | `gn_npc.gd:155-159`; `gallery_night_mission.gd:153-159` | C | S |
| GN-3 BODY_HIDE: only the 2 Mews bins exist (capacity 1 each). The doc adds FR crates (2), J (1), FS (1) and PL behind the AHU (2). | gallery_night.md:769, 394/397/404 | `gn_content.gd:458-461` | C | S |
| GN-4 COVER TacticalPoints: 6 in the map, ~50 in the doc (bar, benches, plinths, screens, balustrade posts, crates, AHUs, bins, limos). | gallery_night.md:731 | `gn_npc.gd:200-205` | C | S |
| GN-5 The map has 0 `Seat` markers. Conservator, Curator (`curator_office`) and AdminPA all `desk_work` with no chair. The camera-operator seat comes from the runtime `prop_camera_station` visual and needs a windowed check. The doc gives patrons `sit` as well. | PO6-06; gallery_night.md:514-519 | `gn_npc.gd:173,175,176`; `gn_content.gd:343-347` | C | S |
| GN-6 No `AssaultEvents` node: van spots on Wexley St / the Parade; a heli orbit over the hall that pairs with the oculus; breach markers such as the EB windows and the court French doors. | PO6-16/17, D-115 item 6 | root children (no `AssaultEvents`) | C markers, A logic | M + M |
| GN-7 No `Audio` node, no gala/art-store/uptown ambience cues, no `gallery_night` music stems. | gallery_night.md:919-973 | `tracks.tres:57-58` | C (+B cues) | M |
| GN-8 e2e stealth + loud on real menus (GN-A1). `TODO(QC-57)`: the Vaultline courier still alarms on an empty slot instead of carrying the canvas. | next_heist §6; gallery_night.md:1115,1181 | `game/tests/a/e2e/po5_flow_auto_loud.gd:20-24` | A | M |
| GN-9 Briefing/strings polish (GN-B1, GN-U5 objective list). Strings exist: 20 `objective.gallery_night.*` rows and 12/12 mission VO ids in `lines.tres`. | heist_completion row | `content/data/strings/strings.csv` | B | S |
| GN-10 Cast polish (GN-D1); P windowed pass plus the §7 G1 traversal tests (laser gaps, balcony throws, Mews→LD heavy bag, pool, ladders, snag probe = 0) (GN-P1). | next_heist §7 | — | D, P | M |

Suggested order: GN-2/GN-3/GN-4/GN-5 (one small layout commit, regenerate) → GN-1 (dressing kits, GI, probes,
occluders, moon, review shots; then flip `stage.txt` to final) → GN-6 markers → GN-7 → GN-8/GN-10 → GN-9.

## Suggested overall order (D-115: GN → DB/SL → ND → GH)

1. **GN small layout fixes** (GN-2..5, one regenerate), then **GN G2** (GN-1). This unblocks GN-P1 on G2.
2. **SL/DB:** merge and regenerate `wip/c-sldb-props` (SL-2, DB-2), fix seats and stale TODOs (SL-3, DB-4, DB-6),
   then the G2 passes (SL-1, DB-1).
3. **Assault markers** for DB, GN and ND (DB-3, GN-6, ND-1) with the `gh_assault.gd` pattern. A then writes the
   HeistDef rows and logic once, for all maps.
4. **Audio batch** (cross-cutting): 4 music tracks + 9 ambience cues (C audiogen), cue rows (B), `Audio` nodes on
   SL/DB/GN and a ND MusicDirector.
5. **GH:** commit/fix the RoofRappelAlley `bounds` failure (GH-2) and add seats (GH-1).
6. **SL-5:** lead ruling that assault events are N/A for stealth-only heists.
