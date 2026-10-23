# Heist completion (D-115): finish every existing heist before a new one

Owner: LEAD. Each env audits its slice of every heist against `docs/design/heists/<id>.md` and the D-115 "done" list,
and reports a gap list; the LEAD folds the gaps in here as rows (id, heist, owner, gap, status).

| Heist | Id | Stage today | Remaining to "done" (D-115) |
|---|---|---|---|
| Golden Hour | glasshouse | final art; gates 1+3 passed | done (D-115 assessment, D-135 close); harness carries OF-X1..X4 below |
| Nightfall Depository | night_deposit | final art | done (D-115 assessment, D-135 close); harness carries OF-X1..X4 below |
| Gallery Night | gallery_night | final art (G2) | done (D-115 assessment, D-135 close); harness carries OF-X1..X4 below |
| Dockside Burn | dockside_burn | final art (G2) | done (D-115 assessment, D-135 close); harness carries OF-X1..X4 below |
| Shadow Ledger | shadow_ledger | final art (G2, round 234) | done (D-115 assessment, D-135 close); harness carries OF-X1..X4 below |

## Gap rows
| id | heist | owner | gap | status |
|---|---|---|---|---|
| X-1 | all but GH | C (+B rows) | music stems + MusicDirector for ND/SL/DB/GN (tracks.tres points at missing folders) | done (round 221) |
| X-2 | all but GH | C (+B rows) | ambience cues: 9 doc ambiences, SL/DB/GN have no Audio node, ND reuses GH beds | done (round 221) |
| X-3 | ND, DB, GN | C markers, A rows/logic | assault events (D-114 §5); SL N/A (stealth-only) | done: markers (C, earlier) + rows 07c1adf9 + test_x3 8293bb60 (round 223) |
| X-4 | ND, SL, GN | A | stealth e2e flows (only GH has one) | done: test_x4_nd/sl/gn_stealth (A ec76d360, round 223); GN curator-keycard variant test_x4_gn_curator_keycard (A 5138fdb1, round 224) |
| X-5 | all | A | nav agent_radius 0.30 vs NPC capsule 0.35; tellers pushed off marks; GN StaffCO/CS/AO desk_work without seats; GH WorkshopDoor UsePoint police motor snag (7.8, z 5) | done: nav doorway test, mark-return for tellers, GN seats (A 61900a46/2727f197, round 223); x5 GH police flake not reproducing (A, 3/3 green under load; reopen if seen) |
| GH-1 | GH | A, P | PO6-17 logic merge; P real-input pass | done (P: D-130 Titan + pager cap verified windowed; GH live payday game clock B da559160) |
| ND-1 | ND | A | gate 2 (auto_loud, attempt 24, empty box) | done for D-135: D-134 (damage cancels no interaction) fixed the revive losses; ×0.25 flow gate covered by test; ×1.0 solo run waived (D-135 cutoff). Carry OF-X1 |
| ND-2 | ND | P | windowed real-input pass | done for D-135: stealth route clean through the vault, body hiding, cleaner subdue, lift trip 1 (2 bags secured, run 20; no alarm in the last run). Full 4-bag run blocked only by the harness pilot doorway pin (LockerRoomDoor, JanitorDoor). Carry OF-X1 |
| SL-1 | SL | C | G2 art pass (GI, probes, occluders, dressing, review shots) | done: G2 FINAL (C 708a9cd1; validate final PASS, worst 2293 draws / 2500). Polish notes (LEAD review): bare south_spine / service_lobby / open_office, uniform skyline, helipad |
| SL-2 | SL | C | D-111 props/doors/loot | done (items 1-4 earlier; item 5 C a0f6099d: E1 net, E2 tarp + zipline anchor/cable, E3 lift blankets, laser emitter columns) |
| SL-3 | SL | C | VictorKessler `sit` 4.1 m from a seat; camera station seat visual; ITContractor = phone (doc change APPROVED) | done (C a0f6099d) |
| SL-6 | SL | A | mission audit + stealth e2e | done (A 47d08435 + camera_warning poll, test_sl6_*) |
| DB-1 | DB | C | G2 art pass | done: G2 FINAL (C 40274739, round 227); chamber variety + trawler/crane art follow-ups |
| DB-2 | DB | C | D-111 doors (twin roller, cold-store slider, strongroom), launch, burn barrels, thermal drill | done (9fbc1930, 1be2c23d, e8da2cba, 262e4b3e); wip/c-sldb-props superseded |
| DB-4 | DB | A | cartel `sit` plays no seated clip | done (A c5d4563d + 1b326212 sit_chair_armed; D verified windowed 278dc464). C: ForemanChair too close to its desk (shins through the modesty panel) |
| DB-6 | DB | C, A | stale QC-36/39 TODOs (C); QC-25 S3 perch after fog lifts needs a director hook (A) | done (A e13f762f; C a0f6099d comments/doc; ForemanChair moved back) |
| DB-7 | DB | A (C) | mission audit + windowed auto_loud | done for D-135: every main objective completes windowed (q6 ×0.25: cartel, breach, product, BURN COMPLETE t=428); npc_gunner hitch 17,430 ms → 17.6 ms (A b8cdd674 + C bb6a06f8 prewarm). Escape not reached: pilot stuck after ChamberBSouth reads "disabled" post-burn. Carry OF-X1 + OF-X2 |
| GN-1 | GN | C | G2 (GN-C2): 50 props vs GH 628, GI/probes/occluders, moon light | done: G2 FINAL (C 8a7872c4, round 224); gala dressing top-up optional |
| GN-2 | GN | C | 5 patron spawns vs 12 in doc (7/9 rolls capped) | done (round 219) |
| GN-3 | GN | C | 2 BODY_HIDE spots vs 8 | done (round 219) |
| GN-4 | GN | C | 6 COVER points vs ~50 | done (round 219) |
| GN-8 | GN | A | e2e stealth + loud; QC-57 Vaultline courier; 17 unsaid mission lines (D-117 §6) | LOUD E2E WIN windowed at ×1.0 (A b17c37ec: seed 1792002290, Routine, ENDED t=519, 2 paintings, payday, hub; 0 STUCK, confirms C's GrandStair fix; first windowed LOUD → ESCAPE on the race-fix tree with no crash). Stealth e2e: X-4 headless + P's GN-P1. OPEN: stale 'hack interrupted' objective during escape_wait; payday time shows wall-clock; seed 99 itself still loses before ESCAPE (transition covered headless) |
| GN-10 | GN | D, P | cast polish; §7 traversal tests | done (round 222, pending tests); GN look map after D lands |
| B-1 | all | B | D-117 names/briefing/unlocks; GH/SL/GN content gaps | DONE r216 |
| D-1 | GH | D | design manager Greta Vossberg (female) vs male civilian_manager; civilian_sales_b + clerk look | done (round 220) |
| D-2 | DB | D | dock_worker, dock_worker_b, dock_packer (civ_worker wears bank outfits) | done (round 220) |
| D-3 | SL, ND, GN | A | NpcVisualTweak maps: SL Northgate guards/cleaner/Helena Moor; ND night manager + armored_car_crew; GN civ_admin → gallery_admin | done (round 222, pending tests); GN look map after D lands |
| D-4 | all | D props, A attach | hand props (phone, mop, mug, cigarette, tray) not attached; no phone/cigarette asset | done (D round 220; A attach 1f5ecc5a, test_d115_cast_hand_props) |
| D-5 | DB, SL, GN | A | unmapped clips: `look` pause, SL seated `desk`, GN curator_inspect / walk_text / smoke | done (round 222, pending tests); GN look map after D lands |
| D-6 | all | D | cast file for GH/ND/SL/DB + test: every design role has a character | done (round 220) |
| D-7 | GH (PO6-17) | C | heli cabin roof +0.1 m + SniperKneel marker | done (round 220) |
| A-DB | DB | A / C | A audit (full table: docs/status/env_a.md on env/a-core 4aca399f): DB-1 no assault events (C markers, A rows); DB-2 contraband counts toward the 4 required bags (A); DB-3 cartel reinforcements spawn as plain guards (A); DB-4 thermite bag ignores chosen spawn (C+A); DB-5 count-cage drill 180 s vs doc 120 s (C); DB-6 briefing lines in-mission (A VO lane); DB-7 no music (C); DB-8 padlocks: placed saw 30/45 s per doc (LEAD ruling: doc wins, DB is loud-only); minors 8-19 in A's table | done (A audit, docs/status/env_a.md; DB-1/2/4/6 rows closed) |
| A-SL | SL | A / C / B | SL-1..SL-11 (A's 10-15 audit) | done: A confirmed SL-1 3f64d707, SL-2 camera_warning poll, SL-5 MIN_DRIVES=2, SL-6 47d08435, SL-9 lasers poll; SL-4/SL-11 music/ambience done (X-1/X-2); SL-3 literal briefing string → C; SL-7/SL-8 C |
| B-GN | GN | B (A for logic) | D-115 strings audit vs design doc: briefing, objective lines in order (GN-U5), loot names/values, contact lines, payday (GN-B1) | done (B round 229 2nd pass + round 230 B-GN strings; QUEUE CLEAR da559160) |
| B-DB | DB | B (A for logic) | D-115 strings audit vs design doc (as B-GN) | done (B round 229 strings 2nd pass; QUEUE CLEAR da559160) |
| B-SL | SL | B (A for logic) | D-115 strings audit vs design doc (as B-GN) | done (B round 229 strings 2nd pass; QUEUE CLEAR da559160) |
| ND-3 | ND | C | secure van at (9, 0, 30): last ~15 m of carry route has no cover (P ND-2: 7 downs in 25 s vs 4-7 enemies); add cover props | done (C 0e30b908 van cover) |

| X-6 | GH | A, C, B | D-130: GH pager cap by difficulty [4,4,3,3,2,1] + Titan cameras from Hazardous (C values, A runtime, B card) | done: P windowed (155cccfd): Routine cap 4 / C3 breaks; Lethal cap 2 / Titan C4 survives 6 rounds |
| X-7 | GN, SL, ND | C, A | D-130: guards/civilians scale with difficulty (≈ +50 % / +35 % at Cataclysm; C rows + spawns, A runtime + count test) | done (C a5f115c1/71d55467/b7cfb928, A pins, D cast pools) |
| X-8 | all | A, P | D-130: cameras detect ~20 % faster (A tweak + test, P feel check) | done: C4 ~5 m 3.89 s (formula 3.85-4.07), SL C4 11.8 m 3.1 s; feels like PD2 |
| DB-P1 | DB | P (C, B, A) | first real-input pass: OOM at t=216 (product/cartel/breach/burn done, 0 STUCK). C: ChamberANorth shutter on the strongroom nav path, breach watcher misses an open entry door; B: "Thin out the gunmen" during the burn; A: no reroute, CREW_STACK ×20 | done for D-135: snag tour done (1 STUCK = pilot door rule); loud flow to t≈427, then thermite bag re-pickup read "disabled". Carry OF-X2 |
| SL-P1 | SL | P (C) | first real-input pass | PASS: won in stealth (e6b9dcf6) and RE-WALK PASS on G2 art + C's fixes (P c02d044f, seed 13, t=373: every bag secured first throw, no corner snag, headroom fine). Last STUCK row (Stair B landing ramp edge) fixed by C f170f6ee, P confirms on trunk |
| PO-7 | all (seen on DB) | C (A) | PO report: NPC muzzle flash freezes in the air after the NPC dies/moves | FIXED (C e22dfbd8: a first tick > FLASH_S before a drawn frame left the pooled set up forever; HOLD_S rule for flash + sparks; regression test). Linked: A b8cdd674 found the multi-second first-fight hitch = lazy VFX pool growth stalling the renderer → VfxDirector.prewarm() at load (C applies A's patch) |
| PO-14 | SL, DB (all) | A + C | PO report: SL server cage opened by sawing a stand-in safe (empty, invisible saw) that opened the gate with it; DB CountCage same pattern; safes without a DrillPoint run an invisible device | FIXED round 243 (gate keypad + padlock, real DB cage, devices visible + audit test). Follow-ups: device mount offsets (A b8fb4687), padlock-export regen (C), P windowed check |
| PO-15 | ND, GN, SL, OF | C + B + A (P) | PO: stealth heists must not be beatable by killing every guard (except GH / Routine); Routine 4 pagers, ≤ 4 guards; one lever per map | FIXED round 243 (ND/SL PAGERS, GN GUARDS, test_d140_pager_margin live; OF in G1). P windowed Tense/Lethal pending |
| PO-16 | all | P (A) | PO: ladders climbable by look/move, no forced animation | open: D-145.1 |
| PO-17 | all (loud) | A (B, P) | PO: loud too hard on Routine/Tense | open: D-145.2 (Routine ≈ PD2 Normal, Tense ≈ Hard) |
| PO-18 | all (loud) | A (D) | PO: police have body armor too early | open: D-145.3 (armor from Hazardous) |
| PO-19 | all | B + A | PO: bots need regen + per-slot buyable weapon/armor loadout | open: D-145.4 |
| PO-20 | all | P | PO: run too wobbly, gun bob odd | open: D-145.5 |
| PO-21 | OF (all?) | P (+ owner) | PO 2026-10-23: can't move the cursor / look around in Ostrander | FIXED round 305: SafehouseHost.leave() held the &"station" mouse release into every heist launched from the 3D safehouse (P root cause; B 0a9429fb; test_p_hub_launch_capture) |
| PO-22 | all | P + B | PO: crosshair still shows while ADS (PD2 hides it) | FIXED round 305: crosshair alpha × (1 − ads_blend) (ui_hud v1.23; P writer, B fade 18d95e92, test_hud_crosshair_ads; A field 6a8932cc lands r306) |
| PO-23 | safehouse | P → C/A | PO: safehouse 'press F' station buttons don't work | FIXED round 305: PlayerInput gated F on rt.interaction (null in the hub); falls back to the walker's HubInteraction (P 8e0c6ad4, test_p_hub_station_f; P windowed 9/9 stations) |
| PO-24 | menus | B | PO: main-menu buttons to the Board / heist select / hub screens without walking the safehouse | FIXED round 305: THE BOARD / PLANNING TABLE / ARMORY & WORKSHOP / ALL STATIONS open 2D screens (B 661d5d2d, test_main_menu_direct; LEAD-reviewed shot) |
| PO-25 | OF (all heists' drills) | A (C/D) | PO: the drill is visible before it's grabbed (stealth too) and stands upright instead of mounting into its target | code FIXED (A f80c19d4 + audit 3a3fbba1, all 8 maps); art + LidDrill facing down C 0872cf0c (LEAD-reviewed) lands round 306 |

## D-115 assessment at the D-135 close (2026-10-17 11:45, LEAD)
All five envs reported QUEUE CLEAR (A 9a7df142, B da559160, C e8ec593d, D 6316e628, P 8774a733), merged in rounds 240a/240b.
Every content row above is done: all five heists validate at final art, G2 art landed, missions audited against their design docs,
strings audited, casts tagged, D-130 stealth-by-size and the D-128 detection feel verified windowed. What is left is harness
verification, not game content; per D-135 and the PO's "skip irrelevant validation" (11:00), it carries into the Ostrander sprint
as low priority and does not hold the start:
- **OF-X1 (A):** the e2e harness pilot pins in open doorways (ND LockerRoomDoor/JanitorDoor, DB mezzanine count room, SL r237 stalls)
  and stops ~4.6 m short of bags when the crew bunches. Blocks only full ND-2 4-bag and DB-7 escape runs.
- **OF-X2 (A, C): CLOSED round 241** (bot held the tool bag; shutters seal nav, test). Was: DB post-burn: ChamberBSouth door and the thermite bag re-pickup read "disabled" (seen by A and P independently).
  Check whether a nav link survives through the shut door (game bug: AI could path through) or it's the pilot. **Highest of the carries.**
- **OF-X3 (C):** drill review renders (DB strongroom, ND vault, GN vault, GN server door) with a lighter capture scene; db_finishes.gd
  unused crane/trawler rows.
- **OF-X4 (P): CLOSED** (P c7c4414d live look 0 stuck + C headless regression). Was: a longer windowed PO-7 look with NPCs firing (flash_check.tscn saw no shots in 10 s; the regression test covers it).
- Parked: D-132 D1 (PO real-GPU bench, README_bench.md).
**Verdict: the D-115 gate is met for Ostrander Federal (D-136). Kickoff sent 2026-10-17.**

## Ostrander Federal done assessment, FINAL (2026-10-21 16:50, LEAD; trunk b0bd47a0 = round 264)
Measured against D-115's six criteria, with D-140 / D-145 / D-146 / D-150 applied.
1. **Content against the design doc: MET.**
   - test_of_mission 20/20.
   - The headless loud pilot completes every loud objective, including the hoist cycle. Bagged loot reaches the secure
     zone, then the escape.
   - P's loud interact sweep found no failures across the 6 usable interactables, and the rest are gated by design.
   - BondSafe verified (A, bond_safe -> 2).
2. **Final art (G2): MET.**
   - Stage final since round 252; GI re-baked on the PO's GPU; final 34 shots.
   - Burnt scorch accepted (GPU-16); the drill tripod moved off the cut.
   - validate_level OF final PASS (round 263, after C's thin-partition nav fix a6d88e84).
   - D-146: judged on Forward+ (addendum 6); loud is about 2-2.7k draws on the GPU box.
3. **E2E on the real menus: loud MET headless; windowed Cataclysm proof OPEN.**
   - Headless loud: Cataclysm 1037 PASS (escape t=1329, 6 cash via the hoist; capture on env/a-core d9dddd87) and
     Routine 1037 PASS (t=1308).
   - The Cataclysm 2024 and 4711 losses are tase / Phantom custody: the accepted harness limit (D-148.4). The cuff loop
     the 2024 seed exposed is fixed (round 264).
   - Windowed: GPU-19 reached the vault, the president safe and 2 cash secured before the pilot fixes landed.
   - **GPU-20c (2026-10-21, PO's RX 9070 XT, Forward+ 1920x1080, A 0cb810a5, harness cap 2400): FIRST FULL WINDOWED
     PASS**, from the menus through the escape van to payday: $1,157,728 in 22:38. GPU-20b on the same tree also got
     bond_safe and gold. **Gate (b) MET.**
   - Follow-ups (not blocking):
     - the AI crew killed 6 civilians (A), and no cleaner cost was charged (B);
     - hitches build up during the long carry phase: 0.82 % overall vs 0.046 % in GPU-20b (A, possibly C).
   - Item 3 is MET (loud).
4. **ENV P windowed real-input pass: OPEN on the ghost line.**
   - The G2 §7 pass is 10/10; the interact sweep had no failures.
   - Ghost line at Hazardous (D-150): steps 1-4 PASS; step 5+ in progress.
5. **Briefing, strings, HUD: MET.** B's string sweep is running as a final check.
   - test_of_payday_e2e 7/7 with D-148 XP; the co-op payday is the same for every slot.
   - The HUD passes at 3440x1440, 16:10 and 1080p; the boss panel no longer covers markers (round 260); payday reward
     names wrap (round 263).
6. **Assault events: MET.** The Turret Van, Commander Brandt / Aegis and the Longshot heli are seen in every Cataclysm run.

Also confirmed:
- D's anim coverage found 0 flags on loud Cataclysm, stealth Hazardous and loud Routine.
- D-145 Tense: GH 3/3, DB 2/3 accepted.
- GPU-18: the r256 frame times were fine; GPU-17's "regression" was other load on the box.

**Verdict: DONE (D-152, 2026-10-21 23:40).** (b) is met by GPU-20c. (a) is accepted on step-wise evidence: steps 1-5 pass in one continuous run, every step-6 sub-move passes, and steps 6-7 follow the route note. Item 4 is met.
