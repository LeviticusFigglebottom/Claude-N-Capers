# PO6 Golden Hour regression, 2026-10-16 (ENV P)

Base: trunk ad54b5fe (round 224) for the menu flows (A's run_po5.sh gh_loud / po6_04, A's po6_gh_capture).
po6_gh_check.tscn (P) on 6c8083c8 + P. All windowed, real input.

| Item | Verdict | Evidence |
|---|---|---|
| PO6-01 drill in one press | PASS: `use SafeDrill (place_drill) -> OK in 3.0 s`, drill state 1 | po6_01_03_drill_placed_timer.png |
| PO6-02 jams 0-2 | PASS: 1 jam at 147 s (56 %), 182 s total | gh_loud log |
| PO6-03 visible timer | PASS: world panel "DRILL 03:00" + HUD objective line | po6_01_03_drill_placed_timer.png |
| PO6-04 silent code route | PASS: code note read (9295), safe opened by code, drills 0, alarms 0 | po6_04_05_code_route_safe_open_loot_inside.png |
| PO6-05 loot inside the safe | PASS: closed = SafeLoot hidden + disabled; open = box inside, "Bag the consignment" | po6_05_safe_closed.png, po6_04_05_* |
| PO6-06 hostages standing at start | PASS: 5 / 5 civilians standing, jeweler working at the bench | 01_po6_20 run log, po6_05_safe_closed.png |
| PO6-07 no looping audio | PASS: no pager loop 2 s after an answer or a failed pager; loud: only `alarm` | po6_gh_check.txt |
| PO6-08 pager freeze / release | PASS: window 11.32 -> 11.32 s over a 1 s hold, answered; 0.6 s hold + release -> pager_failed alarm | po6_gh_check.txt |
| PO6-14 bots carry thrown bags | PASS: bot carrying 1.5 m throw (direct launch: bots are capsules) | 05_po6_14_bot_bag.png |
| PO6-16 cops push in | PARTIAL: cops inside back of house (body-blocked the player in the workshop corridor); the manager office was not on this run's path | po6_16_cop_inside_boh.png |
| PO6-17 assault event | PASS: heli drop (HELICOPTER HUD marker) + breach in one loud run | po6_03_17_loud_drill_heli.png |
| PO6-18 deaths respect the pose | PARTIAL: death_kneel_cuffed plays, dies in place; but the "kneel_cuffed" moment shows an arms-out bind pose and the corpse stays upright on its knees | po6_18_hostage_kneel_death_corpse.png |
| PO6-19 shotgun ragdoll, corpse nudge / blood | PASS: point-blank Brute 12 -> 2.24 m, ragdoll settles; corpse hit nudge 0.08 m + blood | 02-04_po6_19_*.png, po6_19_corpse_blood.png |
| PO6-20 pager outline | PASS outline (through a chair); HUD waypoint not visible in direct launch (no HUD) | 01_po6_20_pager_outline.png |

Harness notes (A): gh_stealth flow FAILs at _enter_boh (SalonBackDoor ui.blocked.casing); run_po5.sh default
heist name "Glasshouse" no longer matches the menu ("Golden Hour"); gh_loud ends FAIL (player downed at t=250 on
the way to the van after bagging; bots in custody). po6_gh_capture shot 03 is taken before the safe is open.
