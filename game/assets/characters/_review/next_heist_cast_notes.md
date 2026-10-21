# Next-heist cast notes: Rolling Thunder vs Afterhours (ENV D, 2026-10-21; NOTES ONLY, D-144: no build)

Sources: `docs/design/heists/rolling_thunder.md` "Civilian, guard and convoy roster", `afterhours.md` "Staff, civilian
and guard roster", `game/world/characters/p5_cast.json` (heists + tag_map), `characters.json`, the
char_anim_humanoid SOURCE clip list (trunk r252), and the parked D branches.

## Rolling Thunder (D-141; daytime street, loud with a stealth set-up)

**Exists on trunk**
- Vaultline crew `armored_car_crew` a-f + `armored_car_marshal` (amber hi-vis) = `convoy_t1/2/3`, `vl_marshal`
  (p5_cast v10 RT pools / tag_map, 0621b4f2).
- Site guards: Halden `security_officer` a-j (`guard_site_*`); beat cop `patrol_officer` (`cop_plaza/diner`).
- Convoy escorts are EnemyDefs (`patrol_officer`, `tac_light`, `tac_heavy` + frd / sentinel / zero reskins); on
  Routine / Tense A's resolver gives them the D-145.3 duty looks (no armour) automatically, incl. the faction TAC Light
  duty looks (1ea150dd). Nothing to build.
- Street / bus / diner customers reuse the 12 OF day-clothes looks (`bank_customer` a-j, `civilian_customer_a/b`).
- Clips: walk_text, browse, sit, smoke, look (investigate_look), radio_call, bartender_wipe (counter wipe).

**Parked (built, not finished)**
- `origin/wip/d-rt-civilians` 883f0403: `char_p5_street.py`: diner waitress + cook, car-park attendant, street
  pedestrians a-f (8 glbs built; NOT assembled, no p5_cast rows, no tests, no review renders).
- `origin/wip/d-rt-clips` 1ca12c8f: `sit_vehicle`, `vehicle_exit_l` / `_r` in the library (SOURCE + glb; test_anims
  partly updated). A's HINT_CLIPS already maps `sit_vehicle` / `vehicle`.

**Missing**
- Clips `sit_eat` (diner booth) and `cook_stove` (diner cook): A's HINT_CLIPS already names them (`eat`, `cook`), the
  library has neither, so those spawns would play idle today.
- p5_cast tag_map rows `staff_diner` (waitress, cook), `staff_booth` (attendant): the wip looks.
- Twins: civilians 6/9/12 + bus 2-4 + diner 2-5 = up to 21 on 12 looks; the 6 wip pedestrians bring it to 18 (and
  separate the street from the OF bank crowd). Escort seated poses use `sit_vehicle` (wip).
- `vehicle_exit_*` callers are QC-83/86 (A); D only owns the clips.

**If picked:** merge trunk into both wip branches; assemble; p5_cast v15 (pedestrians into `civ_street` / `civ_bus`,
diner / booth tags); `sit_eat`, `cook_stove`; tests: test_p5_cast, test_anims, test_outfits, test_lod; review lineups
via the offline cast tool. Estimate: about 1 D day (half is the 2 new clips).

## Afterhours (D-143; night club, PAGERS lever, crowded)

**Exists on trunk**
- `club_bouncer` / `_b`, `club_bartender` / `_b`, `club_dj`, `club_patron` a-d; off-duty cop = `frd_agent` (plain
  clothes); co-op couriers = the cartel looks (12).
- Clips: bouncer_idle, bartender_wipe / pour, dance_a / b / c, desk_work, sit, queue_idle, smoke, walk_text,
  cower_stand / cower_seated. Bar tops at 1.05 m with staff spawns 0.28 m behind them match bartender_* as authored.

**Missing**
- `dj_mix` (QC-74; the DJ on stage): no clip yet.
- Pool sizes (D-130: no twins while the live count <= the looks):
  - patrons 12-20 + dancers 20-30 (clustered) on **4** patron looks: twins everywhere. Proposal: patron looks to 12
    (night-out wear; the dresses get the v1.24 / v1.30 drape method and check_skirt_drape), and the PO decides if
    dancer clusters may repeat looks inside a 5-body cluster.
  - bouncers: 2 fixed + up to 3 rovers + operator + alley smoker on **2** looks: to at least 5.
  - bartenders: 4 bar + box office + counter on **2** looks: to at least 4.
- No p5_cast `tag_map.afterhours` yet (spawn tags -> ids: `guard_door`, `guard_rope`, `civ_bar_*`, `civ_patron`,
  `civ_dancer`, `civ_dj_*`, `civ_offduty`, `cartel_courier`).
- Perf: up to ~50 civilians alive in one room. CrowdLod (no proxy shadows since D-146) matters most here; add AH views
  to heist_cast_perf when the map exists.

**If picked:** dj_mix; 8 patron looks (with drape checks), 3 bouncer, 2 bartender; tag_map + test_p5_cast pool rows;
lineups. Estimate: about 2 D days (the patron crowd and its drape checks dominate).

## Recommendation from the cast side
Rolling Thunder starts faster: most of its cast exists or is parked half-built, and it needs 2 clips. Afterhours needs
about 13 new looks and 1 clip. Either is fine for D; the PO's pick decides.
