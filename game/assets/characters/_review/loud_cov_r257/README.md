# Loud anim coverage, GH and DB at Tense (D-149 item 3; trunk r257 18f9b5ff merged into env/d-art)

`loud_anim_coverage.tscn` headless, 240 s of game time, seed 1002, `--difficulty=1` (Tense), 3 crew AI.

| Heist | Bodies | FROZEN | PLAYER_MISMATCH | NO_CLIP | SLIDE | STATIC |
|---|---|---|---|---|---|---|
| glasshouse | 73 (8 civilians, 2 Halden, 50 police, 10 specials, 3 crew) | 0 | 0 | 0 | 0 | 0 |
| dockside_burn | 49 (6 cartel, 1 civilian, 33 police, 6 specials, 3 crew) | 0 | 0 | 0 | 0 | 0 |

**No animation defects.** Every clip that played exists and moves. Deaths, cower b/c variants, flee variants, shield
walk, tased, door kick and cover peek all fire. Logs: only the headless dummy renderer's VFX texture error
(`vfx_director.gd:98`) and leaks at exit.

**Behaviour notes for A (not anim; clip time totals across the bodies of that class):**
- GH Halden guards (2): `aim_pistol` 455 s and `fire_pistol` 0 s. They hold aim for most of the run without firing.
- DB cartel gunmen (6): `idle_alert_rifle` 724 s, `idle_thug` 381 s, `sit_chair_armed` 191 s, `aim_rifle` 1.4 s. After the
  alarm they mostly stand, or sit armed, and never engage. That may be by design if the crew never reaches them.
- DB Longshot (1): `idle_alert` 59 s with no aim. The GH Longshot aimed for 44 s and fired.
