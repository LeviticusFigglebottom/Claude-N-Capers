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

## RT cast check vs the design roster and reuse-first (D-147, D-148; prep/d-rt, 2026-10-21)
C's `next_heist_rolling_thunder.md` is not on any branch yet; checked against `rolling_thunder.md` "Civilian, guard
and convoy roster" (trunk e9c8744f). Every roster row has a cast; only one gap, filled by reuse:

| Roster row | Cast (prep/d-rt) | New? |
|---|---|---|
| Pedestrian, bus queue, diner customer (`civ_street` / `civ_bus` / `civ_diner`) | 12 OF day looks + 6 street pedestrians (18) | 6 looks built from the outfit kit (library garments + palette, no new meshes) |
| Diner staff (`staff_diner`) | `diner_waitress`, `diner_cook` | 2 kit looks |
| Car-park attendant (`staff_booth`) | `carpark_attendant` | 1 kit look |
| Site guard (`guard_site_*`) | Halden `security_officer` a-j | reused |
| Beat cop (`cop_plaza` / `cop_diner`) | `patrol_officer` | reused |
| Route marshal (`vl_marshal`) | `armored_car_marshal` (QC-86 hi-vis variant of the crew uniform) | reused (the doc row still says `armored_car_crew_b`) |
| Vaultline crew (`convoy_t1-3`) | `armored_car_crew` a-f | reused |
| Escorts (`convoy_lead` / `convoy_rear`), police, Lethal `armored_escort` | director EnemyDefs: A's resolver picks the look per difficulty (D-145.3 duty looks, frd/sentinel/zero reskins, `wrecker*`) | reused, no tag_map row needed |
| **Reyes in the mixer cab** (fiction, crash stop) | **`contact_hollis`** (Hollis "Hammer" Reyes) on pool `ram_driver` / tag `driver_mixer` | reused; **added now** (the tag name is a proposal to C) |

Clips: walk_text, browse, sit, sit_eat, counter_wipe, cook_stove, smoke, look, radio_call, sit_vehicle (seated crew /
escorts), sit_vehicle_drive (drivers, Reyes), vehicle_exit_l / _r (dismount, QC-83/86 callers are A's). Nothing missing.

Twins: street 12 + bus 4 + diner 5 = 21 live at most on 18 looks, so at most 3 repeats, and only at the maximum roll;
the diner is a separate interior. D-130 allows it (no twins only while live <= looks). If the PO wants zero, 3 palette
swaps of existing pedestrians (finish only, D-147) cover it; not built.

### Re-check vs C's `docs/process/next_heist_rolling_thunder.md` (trunk 3312326b, round 256)
- RT-D2 clips (`sit_vehicle`, `vehicle_exit_l/_r`, `sit_eat`, `cook_stove`) and the cook + waitress looks: on prep/d-rt
  (plus `sit_vehicle_drive`, `counter_wipe`; the diner `prop_counter_sales` is 0.9 m = COUNTER_Z).
- Cower placements: `test_cower_offsets` now also measures `diner_staff` / `carpark_attendant`; the back-bag pedestrians
  needed offsets (c 0.12, e 0.25 for the deep delivery backpack, f 0.14). Staff and the others: 0.
- **Do not map `convoy_lead` / `convoy_rear`** (C §3 "cast tags" and §4 ask to add them): NpcVisuals puts the
  SpawnPoint tag before the EnemyDef (D-103 §3b.1), so any tag row would pin one look on every difficulty and bypass the
  D-145.3 duty looks, the frd / sentinel / zero reskins and `tac_heavy`. The escorts are director EnemyDefs, so they never
  fall back to capsules. The PO-5.7 "every spawn tag maps" rule needs an exception for these two tags, with a test (A).
- For A once prep/d-rt merges, in `npc_visual_tweak.tres` `heist_tag_characters.rolling_thunder`: civ_street, civ_bus and
  civ_diner get the 6 `street_pedestrian*` (18 looks); add `staff_diner`, `staff_booth` and `driver_mixer` from p5_cast.

### Zero twins at the top roll (D-149 item 1; finishes only, D-147)
`street_pedestrian_g` / `_h` / `_i` are finish swaps of a / b / f: the same body params, hair style, age and garment
meshes (identical tri counts per mesh), with only skin tone, hair colour and garment materials changed (`recolor` in
char_p5_street.py). g = camel mac over a navy roll-neck, brown bob; h = cream hoodie, navy joggers, blond; i = grey
blazer over ivory silk, dark hair. The street pool is now 21 looks (21 live at most), with unique faces and at least 7
of each gender (test_p5_cast). i keeps f's shoulder bag, so its cower offset is 0.14. Review:
`rt_d1_cast/rt_street_swaps_{sheet,lineup_30m,silhouette_30m}.png` (each base beside its swap). g's first ice-blue mac
read as a lab coat, so it is camel now.
