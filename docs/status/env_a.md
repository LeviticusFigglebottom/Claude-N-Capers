# ENV A status: Core Systems & AI

Owner: ENV A. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## To the LEAD: (2026-10-22 update, D-153 handover; newest at top)
### (-61) D-166 end to end, AH cast batch, gear bag, RT vehicle holster (2026-10-23)
- **D-166 e2e** (harness PO5_FORCE_CAPTAIN 0bf50ccf + CREW_DMG 0.25, A head + C head, Hazardous): Brandt at wave 2,
  SUSTAIN locked, ONE FADE in each run. Seed 4242: first cash bag t=439 -> escape_wait done / van at t=739 (+300 s) ->
  escape t=745 -> RESULT PASS, payday -> hub. Seed 2: first bag t=626 -> van t=926 -> escape t=929 -> PASS. Product:
  afterhours_mission.captain_waiver (0e068d4d), also on captain_arrived. Harness: the captain hunt yields a frame every pass
  (bbf08c8e: it spun in one frame to 7.8 GB and was OOM-killed) and stops once the escape is marked (a3d04eb1).
  Without forcing, the Hazardous re-runs (1 / 4242 / 6501) died to bot skill before Brandt (accepted; P's windowed read).
- AH cast: idle variants off armed bodies (fae58828); bouncers' post activity, bartender_wipe, the off-duty cop's `sit`
  and SpawnPoint facing through spawn_units (ce1c6084); vip_party spawns the civ_vip guests (scripted CIVILIAN spawns
  skipped at load, HeistMission.spawn_civilians; civ_vip -> club_vip a-f) (e6fcf69a). Mercer's gear line (191a8554),
  the Accountant's lines (871fc204).
- Gear bag (B r308): InteractableComponent.aim_filter; GearPickup only targets crew without gear, off once all are
  geared (ab48b324). a/test_s1_3_civilian_mode 6/6.
- RT shot review: seated vehicle bodies holster; vehicle_exit draws at foot_out (2877b00f). a/test_rt_vehicle_holster 1/1.

### (-60) AH done-check harness table: 5 seeds × {ah_stealth, ah_loud} × {Routine, Hazardous} (2026-10-23, LEAD r306)
Tree: scratch merge of env/a-core 0f1f8c5b (= trunk r306 content on A's side) + env/c-worlds 66248215 + env/d-art
dba5dfa2; the Routine loud re-runs ("r") add C's ProductPrivate fix and A's e1e9d39d. Headless real menus:
`DIRECT=1 HEADLESS=1 run_po5.sh <ah_stealth|ah_loud> <seed> 4800 <out> "Afterhours" <Difficulty>`, no CREW_DMG (as the RT -50
table). ah_stealth = X4StealthRoutes `afterhours` (stated shortcuts: navmesh teleports, crew.stealth_hidden), so its
heist time is short; ah_loud = auto_loud (gear step, then masks and goes loud at once). D-140 = pagered NPCs at load /
pager cap (margin); the 5th on Hazardous is the camera operator (sec_staffed; LEAD: a separate role, the lever working).
Rolled: gear / keycard / code note / escape; seeds 1, 6501: wc / kc_bouncer_board|kc_staff_room / bouncer_log / alley;
2: cloak / vip_bar / staff_board / alley; 7: booth / staff_room / count_board / alley; 4242: booth / bouncer_board /
staff_board / tolley (prod_private on 6501 and 4242).

| Flow | Diff | Seed | D-140 | Result | end (s) | STUCK | Cause |
|---|---|---|---|---|---|---|---|
| ah_stealth | Routine | 1 / 2 / 6501 / 7 / 4242 | 4/4 (0) | PASS ×5 | 15-16 | 0 | won stealth, payday -> hub |
| ah_stealth | Hazardous | 1 / 2 / 6501 / 7 | 5/3 (2) | PASS ×4 | 15-16 | 0 | won stealth |
| ah_stealth | Hazardous | 4242 | 4/3 (1) | PASS | 15 | 0 | won stealth (sec_empty) |
| ah_loud | Routine | 1 | 4/4 | PASS | 937 | 10 | won, back in the 3D hub |
| ah_loud | Routine | 2 | 4/4 | PASS | 992 | 3 | won |
| ah_loud | Routine | 7 | 4/4 | PASS | 970 | 8 | won |
| ah_loud | Routine | 6501 | 4/4 | FAIL | 2056 | 0 | MAP: ProductPrivate inside PrivateShelving (bags unpickable) + harness looped on it (fixed e1e9d39d); custody |
| ah_loud | Routine | 6501r | 4/4 | PASS | 994 | 8 | won (C's marker fix) |
| ah_loud | Routine | 4242 | 4/4 | FAIL | 1356 | 1 | same shelved-parcel loop; custody |
| ah_loud | Routine | 4242r | 4/4 | PASS | 766 | 2 | won, 4 parcels from prod_private |
| ah_loud | Hazardous | 2 | 5/3 | FAIL | 105 | 0 | wave-1 BUILD/SUSTAIN wipe in the club (all 4 down by ~88, pilot cuffed while downed), before the keycard |
| ah_loud | Hazardous | 7 | 5/3 | FAIL | 140 | 0 | the same wave-1 wipe, before the keycard |
| ah_loud | Hazardous | 6501 | 5/3 | FAIL | 447 | 0 | survived wave 1, office t=241; ~180 s lost on the shelved parcels (old map) in wave 2's SUSTAIN; down 3/3 at the safe drill |
| ah_loud | Hazardous | 1 | 5/3 | FAIL | 2413 | 4 | SOFT LOCK: secure done t=676, Brandt arrived in wave 2 -> SUSTAIN never fades (captain_active) -> the van (2nd FADE) never comes |
| ah_loud | Hazardous | 4242 | 4/3 | FAIL | 2413 | 0 | SOFT LOCK: secure done t=571, Brandt (wave 2), same |

**Summary:** stealth 10/10 (D-140 margin 0 Routine, 1-2 Hazardous). Loud Routine 5/5 after C's marker fix (two first
runs lost to the shelved parcels). Loud Hazardous 0/5: two wave-1 wipes (bot skill, as RT's Hazardous), one wave-2 loss
helped by the old marker, and two runs that did everything (safe, 3 bags secured) and then soft-locked: AH's van waits for
the second assault's FADE, and Brandt (captain_min_wave 2, captain_chance 0.5) locks SUSTAIN until he dies. The pilot
does not hunt him; a crew that can't kill him also waits forever. LEAD ruling asked (pilot hunts Brandt, or the AH van
rule while the assault is locked). No tweak changed. SCRIPT ERROR 0 in every run.

### (-59) AH looks, guard idle variants, AH ambient activities; AH loud e2e PASS seeds 1/2 (2026-10-23)
- AH loud e2e on the [secure] fix (9b044447) + C 2c3cbe99: `po5_flow_ah_loud` PASS seed 1 (t=980) and seed 2
  (t=1041): gear -> mask -> loud -> keycard -> office -> safe -> safe_loot -> secure -> escape_wait -> escape, lockdown,
  the stock cage padlock sawn for the parcels. One 1.19 s hitch in anim_driver (3 Godot processes on the box): watching.
- D-165 AH looks (0fe1ff72): heist_tag_characters[afterhours] (+ pools); a/test_ah_cast_looks.
- D 7d86014f guard idle variety: VARIANT_GROUPS idle (idle, idle_b, idle_c) and idle_alert (idle_alert, _b, _c); the
  plain stands vary after the shield remap (`_idle_variant`), never the armed idle_alert_<kind>; walk_start from any
  idle*. a/test_v118_anim_variants 8/8 (with D's clips: idle_b / idle_c per body index; without: the base).
- AH ambient (found by test_anim_driver on C's map): HINT_CLIPS bouncer_idle, dj_mix (fallback browse until QC-74);
  CivilianBrain.KNOWN_ACTIVITIES dance_a/b/c, dj_mix. a/test_anim_driver 30/30 on C+D's tree; test_a1_06_civilians 4/4,
  test_gn_ambient_clips 5/5, test_of_a6_bank_ambient 7/7, test_po6_06 3/3, test_d132_anim_lod 9/9.
- PO-25 shots on C 0872cf0c (1c2e4886): the drill-down rig on the OF lid; AH SafeDrill re-faced by C (audit 4/4).

### (-58) AH [secure] counts the safe cash only; OF drill visuals; auto_loud padlock-first (2026-10-23)
- BUG (found by the AH loud runs on C's 2c3cbe99): `[secure]` used require_loot (any bag), so parcels + count cash
  closed it at t=201 and seed 2 escaped with 4 parcels and the safe shut (heist_ended success). Now `[secure]` counts
  only `loot.cash_bricks` (`safe_secured`, afterhours.md §Required loot); the secure_wait starts on the first cash bag.
  a/test_ah_a1_mission 6/6 (3 parcels secured: [secure] stays ACTIVE, no escape), on C's head a/test_ah_mission_map 4/4,
  a/test_x4_ah_stealth 3/3.
- PO drill report (f80c19d4, 3a3fbba1): DrillPoint shows device art set as `visual_scene` only once placed (OF LidDrill
  stood in the bank); audit: every targeted drill spot on 8 maps faces its target. OF LidDrill's drill-DOWN intent
  needs a drill-down thermal variant + the spot facing down: routed to C (asset owner).
- PO-5 auto_loud (e088b5d1): a bag with no path behind a padlocked gate / cage gets the padlock worked first (AH
  StockCageGate: sawn, 2 jams fixed, open at t=97, the parcels then taken).

### (-57) AH safe cash spawns when the safe opens; ui_hud v1.23 ads_blend (2026-10-23)
- `afterhours_mission.gd`: the safe's bags (safe_bags, +1 count_done) spawn at the safe_loot markers in `open_safe`
  (code / drill / left_open), not at the heist start: nothing in a shut safe (PD2), and what P's route 1 expected.
  P's "contents() empty, 0 bags" (seed 6501): the bags are loose LootBags (loot.cash_bricks) at the marker, not the
  Safe prefab's contents(), and were already there on dafcc0fb. Tests on C's 2c3cbe99: a/test_ah_mission_map 4/4 (no
  cash before the safe opens; >= 4 at safe_loot after the keypad), a/test_x4_ah_stealth 3/3, a/test_ah_a1_mission 6/6.
- PO-22 (6a8932cc): `LocalHudModel.ads_blend` (ui_hud v1.23, written by P's CrewView); a/test_ui_hud_v1_23 1/1.

### (-56) AH e2e: gear step, ah_loud flow, the stealth route + mission-placed loot no longer alarms (2026-10-23)
- Lift strings blocker (LEAD r305): bag_lift.gd lists `ui.prompt.send_lift_to_0..3` whole (5203144d); b/test_strings
  23/0 with B's 16c4ef81, a/test_a3_09_bag_lift 9/0. Built `ui.*` keys never pass the scan (only `vo.*_%s`).
- RT roof release: not reproducible server-side (P retracted: their harness stood outside the shaft); guard
  a/test_rt_lift_roof_release 1/1 (57dbbc29).
- PO-5: auto_loud `_gear_up` (civilian start: the rolled GearPickup before the mask, dd006c14); `po5_flow_ah_loud.gd`
  (gear before mask, loud order gear -> office -> safe -> secure -> escape, lockdown, loud win). Headless seed 1 on C's
  map: geared t=15, keycard t=136, office t=190; map findings sent to C (navmesh through the latched CountWindow, the
  parcels behind StockCageE).
- X4 route `afterhours` (x4_stealth_routes.gd): gear -> mask -> keycard -> office reader -> code note (if rolled) ->
  safe by code, else the drill with its jams fixed -> 3 safe bags (the upper ones of the stack reached from the safe's
  UsePoint) -> the rolled van. New a/test_x4_ah_stealth: seeds 1/2/3 PASS on C's map (fb0bea19 + civilian_allowed,
  scratch tree); SKIPs here until the map is on trunk.
- Fix (game): `HeistMission.spawn_loot` bags are now pre-placed style (`LootBag.moved = false`, S4.1): no guard or
  camera reacts to placed loot until a crew member first picks it up. AH seed 2 (count_running + cam_a): CameraC8 saw
  the count room's two cash bags and raised the alarm 2 s into the heist with nobody near. Affects OF drill parts and
  RT truck cargo the same way (PD2: level loot is not suspicious). Tests: a/test_of_a1_drill_requires 2/2 (asserts it),
  test_ah_a1_mission 6/6, test_s4_stimuli_noise 4/4, test_of_mission_loud 6/6, test_rt_a6_mission 14/14,
  test_a3_09_out_of_bounds 4/4, test_x4_of_stealth 5/5.
- Finding for C: AH has ONE `safe_loot` marker, so 5-7 bags stack 0.4 m apart inside the safe (top ones ~1.3 m up).
  More markers inside the safe would read better.

### (-55) Door.civilian_allowed for AH guest doors (LEAD r305, P G1 casing blocker) (2026-10-23)
- `door.gd`: `@export var civilian_allowed: bool = false` (Interaction group), passed to the interactable in
  `_apply_lock_interaction` (so `relock()` keeps it). Default false = staff door (`ui.blocked.civilian`). C sets it on
  the guest doors (c6589729).
- Tests: new a/test_ah_door_civilian 2/2 (civilian opens a guest door, staff door refused; relock keeps the flag);
  a/test_s1_3_civilian_mode 5/5, a/test_gn_staff_doors 2/2, a/test_a2_01_doors_nav 11/11, a/test_gn_door_relock 4/4,
  a/test_d116_door_breach 2/2, a/test_a1_03_prefab_shapes 7/7. gdlint, ownership, banned clean.

### (-54) BagLift: a send to every other landing on 3+ landing lifts (LEAD r304) (2026-10-23)
- `bag_lift.gd`: with 3+ landings each landing gets one `send_lift` button per other landing (`LandingSend<i>_<j>`,
  stacked above its panel, in `send_buttons[i][j]`), enabled only while the car stands there; the landing panel then
  only calls the car (enabled while the car is elsewhere). 2-landing lifts are unchanged. Same replicated state and
  lockdown gating (`_availability`). Labels: `send_prompt_keys` per landing, fallback `ui.prompt.send_lift_to_<j>`.
- RT `GoodsLift`: `ui.prompt.send_lift_ground` / `ui.prompt.send_lift_deck2` / `ui.prompt.send_lift_roof` (B owns the strings).
- PO-5 auto_loud pilot sends to the landing nearest the secure zone through the send button (`_lift_send`, `_lift_top`).
- `test_of_a2_prefab_enable`: the rappel-link path query now uses the breach layer (follow-up to 88c955bc; was red).
- Tests: a/test_a3_09_bag_lift 9/9 (new `test_three_landings_send_straight_to_the_roof`: ground → roof, 2 bags, one
  send), a/test_rt_a6_mission 14/14, a/test_po6_14_bot_catch_bag 7/7, a/test_of_mission_loud 6/6,
  a/test_of_a2_prefab_enable 5/5, a/test_d105_prefab_surfaces 6/6, c/test_rt_goods_lift_throw 1/1,
  c/test_of_hoist_panel 1/1, c/test_of_cash_lift_throw 1/1. gdlint, ownership, banned clean.

### (-53) AH-A1..A3 on C's G1, the rappel-link nav fix, the VO-coverage fix (2026-10-23)
- **AH-A1 (d7f88cf2, 6b24b1dd, f7b40fd8):** AfterhoursMission (world/heists/afterhours/afterhours_mission.gd).
  - Objectives casing → … → escape, the loud lockdown, escape_wait (2nd FADE + 300 s), rare events, VO hooks on B's ids.
  - test_ah_a1_mission on a synthetic map.
  - f7b40fd8: the gear line is built with "%s" so B's vo_coverage scanner sees it.
- **AH-A2:**
  - 9a335a1d: the co_op_pickup couriers are calm guards on their route and alarm when the product is gone.
  - cef43029: off_duty_cop is a calm police observer with no pager.
  - test_ah_a1_mission 6/6.
- **AH-A3 (63a1e372):** test_ah_mission_map on C's real map.
  - Covers markers, D-143 data, 4 guards, the stealth line by facts, and the loud lockdown on ClubLights / ClubSound.
  - 4/4 on C's env/c-worlds 17b2bf29, after C fixed the courier tags + graph and OffDutyCop POLICE + scripted, both per
    my contract. SKIPs without the map.
- **Rappel links (88c955bc):** the runtime RappelLinks (rappel_links.gd) were on nav layer 1, so the crew pathed down
  skylight drops (OF lantern, 8.6 m).
  - C traced it. Now on Door.NAV_LAYER_BREACH (police / specials only).
  - test_qc41_rappel asserts it.
  - OF auto_loud seed 1: was a timeout with 336 STUCK at the lantern; now PASS at 1250 s, 9 STUCK, none there.

### (-52) All-shipped-heists harness sweep (LEAD r296..299), Routine, headless, real menus (2026-10-23)
Code: env/a-core (trunk r294..299 + A). `DIRECT=1 HEADLESS=1 run_po5.sh <flow> <seed> 3000 <out> "<Heist>" Routine`, plus
the X4 stealth tests.

| Heist | Flow | Seed | Result | Heist time (s) | Cause / note | STUCK | SCRIPT ERR |
|---|---|---|---|---|---|---|---|
| Golden Hour | auto_loud | 1 / 2 | PASS / PASS | 260 / 253 | | 5 / 7 | 0 / 1 (harness) |
| Dockside Burn | auto_loud | 1 / 2 | PASS / PASS | 820 / 1001 | | 3 / 0 | 0 |
| Gallery Night | auto_loud | 1 / 2 | PASS / PASS | 647 / 585 | | 0 / 0 | 0 |
| Shadow Ledger | auto_loud | 1 / 2 | n/a | 11 | stealth-only heist: auto_loud ends at the alarm (stealth_only_alarm), by design | | |
| Nightfall Depository | auto_loud | 1 / 2 | FAIL / FAIL | 774 / 976 | custody after long bag ferries (pick_bag under fire) | 18 / 22 | 0 |
| Nightfall Depository | auto_loud | 1001 (control; passed r266) | PASS | 1087 | seed variance, not a regression | 41 | 0 |
| Ostrander Federal | auto_loud | 1 / 2 | FAIL / PASS | timeout / 1115 | seed 1: nav finding (below) | 341 / 17 | 0 |
| Rolling Thunder | auto_loud | 1 (control) | PASS | 759 | | 19 | 0 |
| Golden Hour | gh_stealth | 1 / 2 / 1001 | FAIL ×3 → PASS (1001, fixed) | 117 | **game bug, fixed:** the operator's pager unanswerable (below) | 0 | harness, fixed |
| Ostrander Federal | of_stealth | 1 / 1002 / 2 | PASS / PASS / FAIL | | seed 2: harness: ties the kc_on_manager curator in the gallery, the rover sees her (restrained alarm) | 0 | 0 |
| GN / ND / SL / OF | test_x4_*_stealth | fixed seeds | PASS ×4 (OF 5/5) | | test_x4_of_loud 3/3; test_x4_of_hard opt-in (5 skipped) | | |

- **Regression found and fixed (game, A): the GH camera operator's pager could not be answered.**
  - Knifed at his station, the body folds over the CameraStation desk, so PagerSystem._follow_body put the prompt at
    the hips, INSIDE the desk's collision box. No eye anywhere had line of sight (InteractionSystem._has_los), and a
    player would have failed the pager the same way.
  - _follow_body now keeps the prompt on the root's side of any static geometry between root and hips.
  - Test: test_s5_pagers::test_pager_prompt_kept_out_of_geometry. gh_stealth 1001 then PASSED end to end (pager
    answered at t=40, escape, hub).
- **Harness fixes:**
  - gh_stealth: the safe-loot lambda read a null component before the safe opened (63 errors).
  - po5_pilot.use: a freed target after an await.
- **Nav finding for C (OF seed 1):** the navmesh path from the upper floor to the vault drops 8.4 m through the atrium
  lantern, at (13.6, 8.6, 26.0) against Geometry/Building/Lantern/CurbW + Glazing. The pilot wedged there 336 times,
  and the run timed out at 2400 s.
- **Not regressions:** ND seeds 1 / 2 (the r266 seed 1001 passes) and the stealth seed-2 harness limits above.

### (-51) D-158 amendment 9 (3585dce5): clean stop keeps RearStop on trucks_2 (2026-10-23)
- Root cause of east's 33 m: trucks_2, not the route. Both routes share the stop geometry (Lead 18.5, T1 27.75,
  T2 39, T3 51, Rear 61, RearStop2 49 along the route). _stop_marker closed the rear car up to RearStop2 on every
  trucks_2 stop.
- Fix: RtTweak.rear_close_up_clean (ships false). A clean stop keeps RearStop on trucks_2 too; the crash stop keeps
  the close-up.
- Test: test_clean_stop_rear_car_holds_back_on_both_routes_and_truck_counts pins the rear stop >= 42 m behind
  LeadStop on north / east × trucks_2 / trucks_3 (clean), RearStop2 on the crash stop, and the knob. d158 13/13; RT
  tests green (rt_a6 14, rt_a5 10, a5_02 4, looks 2, tactical 2, r288 2).
- Re-run, seed 1001 east_clean trucks_2:
  - The rear TAC Heavy is now 43 m from the crew at the stop (was 33).
  - **Routine: PASS** (escort down t+24.8, build t+113.5, won at 522 s).
  - **Hazardous: FAIL, unchanged** (down t+12.9, cuffed t+20.7, custody t+43.0 before build).
  - The ESCORT hit log shows the TAC Heavy is not what downs the pilot: 30 of about 185 damage. The rest comes from
    the T1/T2 security officers and convoy_lead at 6-15 m.
  - Guard #102 sits 14 m from east's ambush cover. It goes ALARMED at t+2 (guard_radio springs the ambush) and is
    shooting at 6 m by t+6.7; the column's crews join at t+8-9.5.

### (-50) RT done-check harness evidence: 5 seeds × {loud, stealth prelude} × {Hazardous, Routine} (2026-10-23)
Code: env/a-core dea7fc07..46bfd037, which equals trunk 9d4bca054 on A's side (amendment 8 knobs live: window from
escort_down, wave 1 without stinger + phantom from Hazardous). Headless real-menu flow:
`DIRECT=1 HEADLESS=1 run_po5.sh <flow> <seed> 3000 <out> "Rolling Thunder" <difficulty>`.
- **auto_loud** = blown: mask up at once, loud, the pilot plays the convoy crash.
- **rt_clean** = the stealth prelude (signals hack, padlocks, crew to the ambush spot unmasked) to the CLEAN stop, then
  loud.
- **No ghost run exists for RT.** It is loud-forced by design: RollingThunderMission raises the "ambush" alarm when the
  8 s window after the stop ends (start_timer(&"window", WINDOW_S) -> raise_alarm(&"ambush")), and the trucks / cargo
  objectives come after it. rt_clean is the stealthiest route there is.
- "esc" / "build" / "cust" are seconds from the convoy's stop: escort down, the first assault BUILD, the human pilot's
  custody (the harness fails on it). "end" = heist time at heist_ended or at the fail.

| Flow | Diff | Seed | Route | esc | build | cust | Result | end (s) | Cause |
|---|---|---|---|---|---|---|---|---|---|
| auto_loud | Hazardous | 1001 | east_crash | 23.8 | 53.5 | 98.4 | FAIL | 141 | custody (pinned at the trucks by wave 1) |
| auto_loud | Hazardous | 4101 | north_crash | 40.3 | 59.8 | 255.1 | FAIL | 296 | custody (1 truck's cargo out, bag carry under fire) |
| auto_loud | Hazardous | 7 | north_crash | 31.0 | 59.8 | 192.0 | FAIL | 234 | custody |
| auto_loud | Hazardous | 2024 | north_crash | 24.3 | 53.8 | 273.2 | FAIL | 314 | custody (3 crew in custody) |
| auto_loud | Hazardous | 42 | north_crash | 22.7 | 52.6 | 87.3 | FAIL | 131 | custody (cuffed while downed) |
| rt_clean | Hazardous | 1001 | east_clean | - | - | 42.7 | FAIL | 232 | custody BEFORE build, escort still up (TAC Heavy 33 m at the stop) |
| rt_clean | Hazardous | 4101 | north_clean | 41.9 | 113.5 | 183.0 | FAIL | 370 | custody |
| rt_clean | Hazardous | 7 | north_clean | 30.0 | 114.0 | 323.2 | FAIL | 495 | custody |
| rt_clean | Hazardous | 2024 | north_clean | 27.9 | 113.6 | 293.6 | FAIL | 511 | custody |
| rt_clean | Hazardous | 42 | north_clean | 38.2 | 113.9 | 292.9 | FAIL | 549 | all_custody |
| auto_loud | Routine | 1001 | east_crash | 11.9 | 41.5 | - | PASS | 517 | won, 4 bags, back in the 3D hub |
| auto_loud | Routine | 4101 | north_crash | 23.2 | 52.8 | - | PASS | 700 | won, 4 bags |
| auto_loud | Routine | 7 | north_crash | 20.7 | 50.6 | - | PASS | 1066 | won |
| auto_loud | Routine | 2024 | north_crash | 11.9 | 41.8 | - | PASS | 753 | won |
| auto_loud | Routine | 42 | north_crash | 63.0 | 59.8 | - | PASS | 820 | won |
| rt_clean | Routine | 1001 | east_clean | 27.9 | 113.9 | - | PASS | 538 | won |
| rt_clean | Routine | 4101 | north_clean | 17.1 | 143.9 | - | PASS | 752 | won |
| rt_clean | Routine | 7 | north_clean | 20.2 | 98.7 | - | PASS | 575 | won |
| rt_clean | Routine | 2024 | north_clean | 14.0 | 141.6 | - | PASS | 677 | won |
| rt_clean | Routine | 42 | north_clean | 146.7 | 143.7 | 730.7 | FAIL | 891 | custody (escort lasted 147 s) |

**Summary:**
- **Routine: 9/10 pass.** All five loud runs win end to end (payday -> the 3D safehouse). The one fail is seed 42
  clean, where the escort fight lasted 147 s.
- **Hazardous: 0/10.** Every seed wins the escort except 1001 east clean, then loses the truck fight after the wave-1
  BUILD. The pilot gets downed, cuffed while downed (L2.12) and goes to custody 87-273 s after the stop.
  - The waves include tac_heavy ×3 and bulwark / longshot. Later waves bring phantom / stinger (allowed from wave 2).
- **Seed 1001 / route_east, clean stop, Hazardous:** still loses to the escort. The TAC Heavy stops 33 m from the stop
  (north: 50 m). The crew is down at t+12.7 / 16.0 and in custody at t+42.7, before the escort is down.
  - The same seed's blown run (east_crash) wins the escort at t+23.8.
  - The same seed's clean stop at Routine wins the escort at t+27.9.
- **STUCK:** one spot, (21.9, 0, -12.8), between Props/Dress/Streets/Forecourt/BinStreet0 and
  Props/Dress/Direct/CarParkBarrier.
  - The pilot wedges there in 7 runs (up to 42 STUCK lines, rauto_loud_7) and slides out. A real map snag for a player
    too (C's dressing).
- **"could not reach":** 0-4 per run. They are pilot targets set aside: a truck's fix_drill from the far side, a bag
  under fire, ctrl_locked's padlock.
- **Errors:** no game SCRIPT ERROR. One harness error: po5_pilot.use read a freed interactable after clearing threats
  (rrt_clean_4101). Fixed in this push.
- **Harness note:** the pilot is a bot. On Hazardous it plays the truck fight worse than a player would (it stands to
  saw / carry under fire). These are bot-skill data next to P's windowed confirm runs.

### (-49) B's mimic dicts checked (2026-10-23)
- perk.anarchist: an empty tick_by_armor ({}) now means CrewHealth's normal delayed regen (handles_armor_regen
  false, no ticks). It used to fall back to anarchist_fallback_tick. A missing field still takes the default table.
- perk.ex_president (store_per_kill 0), perk.gambler (flat heal_bonus), perk.crew_chief (team_dr 0): these were
  already off.
- Test: test_d164_copycat 6/6 (new test_b_mimic_dicts_read_as_off). Regression: perk_armor 6, perk_combat 5,
  perk_team 5, b/test_perk_behaviour 8 (1 skip).

### (-48) A roadmap audit: the rows with no ✅ (LEAD r291) (2026-10-23)
Evidence: the tests under game/tests/a (all green at the time of their entries) and the spec-row audit
docs/status/env_a_fidelity.md (103 rows: S8.7 and L6.2 since built, D-161 5f09d31a and c6e78cb0).

| Row | Verdict | Evidence / what is missing |
|---|---|---|
| A1-01 | DONE | test_a1_01_heist_runtime; test hooks (contracts/test_hooks.md) used by every heist test. |
| A1-02 | DONE | test_a1_02_crew_controller, test_pp_a1_player_input_driver, test_s1_casing_detection (casing rules), net: test_a3_07_coop_loopback. |
| A1-03 | DONE | test_a1_03_prefab_shapes (all P1 prefabs), test_po6_01_drill_place_once, test_po6_02_jam_schedule, test_s10_1b_ladder_bag. |
| A1-04 | DONE | test_s2_detection_meter, test_d128_detection_pd2, test_s4_stimuli_noise, S2/S3 rows covered (fidelity). |
| A1-05 | DONE | test_a1_05_security_officer, test_s5_1_patrol_routes, test_s3_3_guard_radio, test_s3_4_guard_investigate, test_s3_6_guard_one_shot. |
| A1-06 | DONE | test_a1_06_civilians, test_s3_1_civilian_panic, test_s7_shout_and_ties. |
| A1-07 | DONE | test_s5_pagers (juggling), test_po6_08_pager_freeze, test_s6_body_bags, test_s10_loot_bags. |
| A1-08 | DONE | test_l3_weapons, test_a1_08_range_crew, test_l2_survival, test_l3_3_pellet_headshot. |
| A1-09 | DONE | test_l1_assault_director, test_a1_09_police_ai, test_po5_police_assault_push. |
| A1-10 | DONE | test_a1_10_crew_ai, test_l6_ai_teammates, test_l6_1_stealth_bots_wait, test_r288_bot_revive. |
| A1-11 | DONE | test_a1_11_local_hud_model, ui_hud v1.20-v1.22 tests. |
| A1-12 | DONE | test_a1_12_modifier_hooks; the P4 gate's ratchet is empty (UNHOOKED and UNTESTED both {}). |
| A2-01 | DONE | test_a2_01_doors_nav (authorised keycard guard, nav link follows door), test_gn_staff_doors. |
| A2-02 | DONE | test_s8_2_camera_operator (kill / dominate -> cameras off, dispatch to a broken camera), test_s8_1_cameras (Titan). |
| A2-03 | GAP (small) | S8.5 ATM half: "ATMs open in 8 s (consumes the ECM)". DeployableTweak.ecm_atm_open_s exists but nothing reads it; only keycard readers take an ECM. Rest: test_s8_4_ecm, test_s8_6_ecm_feedback, test_s5_6_ecm_pager_delay. |
| A2-04 | DONE | test_s9_7_keypads_codes, test_s9_8_safes (time locks), test_s9_4_saws, test_s9_10_lasers, test_s9_11_zipline_ladder. |
| A2-05 | DONE | test_s3_2_guard_cuffs (cooldown, self-free), test_s3_7_misfire, test_s2_9_marking (Sixth Sense). |
| A2-06 | DONE | test_l2_11_deployables, test_s6_2_body_bag_case, test_s8_4_ecm, test_l2_4_dodge. |
| A2-07 | DONE | test_s6_4_hostage_stimuli, test_s11_3_stealth_only, test_c3_preplanning (spawn, drops, modifier sources). |
| A2-08 | DONE | test_a2_08_variant_rules (force_if, requires, min_difficulty, weights), test_a2_08_prefabs (glass AABB, keycard safe, push-bar door, camera collision). |
| A4-04 | DONE | test_a4_04_ratchet_batch1/2, test_a4_keys_phase24; the gate's UNHOOKED / UNTESTED lists are empty. |
| A5-01 | DONE | test_a5_01_armored_truck (saw, lockdown ×1.5, cargo, QC-81 roof burn point). |
| A5-02 | DONE | test_a5_02_convoy (path, brake / stop, layouts), test_rt_a5_ambush; replicated via HeistNetSync. |
| A5-03 | DONE | test_a5_03_c4_item, test_s9_5_door_charges. |

GAP fix order (LEAD): A2-03's ATM half is the only gap, and it is off every shipped heist's critical path (ND's ATMs
are saw targets).
- **Fixed in this push:** DrillPoint.ecm_atm (ecm_openable / ecm_open_s / open_by_ecm). DeployableSystem's ECM aim
  now also takes an ATM spot; EcmSystem uses the target's own open time (ecm_atm_open_s 8 s); ND's AtmSaw1/2 are
  flagged (generator and tscn).
- Tests: test_s8_4_ecm 8/8 (new: test_s8_5_ecm_on_atm_spot_opens_it). Regressions green: x4_nd_stealth, po5_nd ×2,
  nd_teller, s9_4_saws, po6_01, l2_11, s8_6, d161, qc37.

### (-47) A4-02 re-measure + anim_driver profile (2026-10-23)
- A4-02 was delivered in 26509c96 (entry -35). Re-measured on 5b85146c, Dockside, 4 crew, cap 24 enemies, headless:
  - Frame: avg 7.4 ms, p95 12.2 ms. Process: avg 9.6 ms. Saturated: 4.84 ms per physics tick.
  - Net: transforms 25.8 KB/s at 15 Hz, full state 6.3 KB.
  - Same as the baseline, so D-158..D-164 added nothing measurable.
- CI budgets (test_a4_02_dockside_perf, unchanged, about 2× the baselines): process avg 20 ms, frame p95 40 ms,
  tick 12 ms, xform 96 KB/s, full state 64 KB.
- FrameProf top: anim_driver 2.15 ms/frame (headless is always the FULL AnimLod band; windowed play LODs it),
  npc_motor 0.62, everything else < 0.25.
- anim_driver profile: turn 0.52, choose 0.45, left-hand IK 0.22, hold 0.19, apply 0.18, hint 0.11.
  - TurnInPlace and the tick each ran choose_clip(). Now one _choose_clip_tick() per tick, invalidated when a one-shot
    starts in between.
  - Result: anim_driver 2.15 -> 2.06 ms (small; within noise).
- Anim tests all green (anim_driver 30, d116 clips 21, turn 7, lod 9, ...).

### (-46b) D-158 amendment 8 (4c5b9248, its own commit, sent to P)
- rt_tweak.tres: truck_window_from escort_down; wave1_exclude [stinger, phantom] from Hazardous.
- test_d158_rt_fairness 12/12 checks the shipped values; the tests that change the tweak restore them.

### (-46) D-164 perk.copycat on B's names; item cooldowns run while down (2026-10-23)
- PerkCopycat:
  - Tactical reload: kills per weapon slot refill the holstered magazine from its reserve, then a near-instant swap
    window (CrewWeapons.grant_quick_equip, equip time /10 ◇, server side).
  - Headshot heal on any headshot hit, with its cooldown.
  - Dodge ricochet back at the shooter (the dodged bullet's damage ◇); its cooldown is 0.35 s on LETHAL/CATACLYSM ◇.
  - Grace: health-only immunity after the hit that crosses the threshold, with its cooldown.
- CrewWeapons.refill_mag(ws, free).
- PerkHooks.is_headshot(info) for the kill and damage infos.
- on_dodge now passes {amount, type, attacker, position}.
- Deck-item cooldowns (Stoic flask, Kingpin injector, Sicario, Leech) tick while down, via
  tick_item_cooldown / CrewPerks.tick_item_cooldowns. TagPairs and the pocket ECM are services that already ran.
- Contract row perk.copycat (phase 5). perk_tweak defaults (all behaviours off).
- Tests: test_d164_copycat 5/5 (includes a partial-dict / mimic smoke test over every family's component);
  test_d164_leech 7/7 (+ cooldowns while down, refill_mag / is_headshot).

### (-45) D-164 perk.leech on B's names, ui_hud v1.22 segments, perk_item.mode (2026-10-23)
- PerkLeech:
  - The ampule window: activate heal, armor_off, and segmented health (a hit takes the whole top segment).
  - kills_per_segment restores a segment; team_heal_on_damage_fraction heals teammates when the holder is hit.
  - Cooldown from the window's end, with kill cuts.
  - no_bleedout: the holder stays up at 0 health, at ×zero_health_speed_mult via CrewBuffs, and goes down at the end.
  - usable_while_downed: a temporary revive. It goes back to the same down and bleed-out unless the holder revived a
    teammate or a doctor bag reset the downs.
- CrewHealth: a vetoed down at 0 health no longer goes down.
- PerkItems / perk_item: optional `mode` (B's request; the pocket ECM's jam / feedback) and `segments`
  {count, size} while active.
- Contract row perk.leech (phase 5). perk_tweak defaults (card-1 values).
- Tests: test_d164_leech 5/5, test_ui_hud_v1_21 3/3.
- Known limit: CrewPerks does not tick while DOWNED, so the cooldown pauses while the holder is down.

### (-44) D-164 generic Leech hooks (2026-10-23)
- PerkHooks.veto_down: CrewHealth.take_hit asks it before a down; a component's veto_down() sets the health and keeps
  the holder up.
- PerkHooks.tick_downed: the deck throwable can be used while DOWNED, but only by a component whose
  usable_while_down() is true. CrewPerks.use_throwable skips every other component while down.
- Tests: test_d163_systems 9/9. Regression all green: l2_survival 14, l2_12 9, l2_8 6, skills_b1 8, skills_b3 5,
  c4_last_breath 3, d163_decks 5, d161 5, perk_combat 5, l4_3 9.
- Next: PerkLeech on B's names.

### (-43) D-163 presentation hooks for C (2026-10-23)
- EventBus smoke_cloud_fx(position, radius, duration_s): ThrownItem emits it on every peer when a smoke cloud starts,
  with the cloud's real radius and time left.
- crew_tether_fx(a_slot, b_slot, active): TagPairs emits it on pair form / end, on the server and on clients through
  apply_net_state.
- Both are emitted only when EventBus.has_signal, so the LEAD declares them in event_bus.gd.
- Tests: test_d163_systems 7/7, test_d163_decks 5/5.

### (-42) D-163 decks on B's names, ui_hud v1.21 (2026-10-23)
- perk.sicario (PerkSicario): the smoke bomb (kind smoke_bomb) cloud carries B's params; the cooldown starts when the
  cloud ends, and kills cut it. Twitch, dodge_restores_armor (full refill ◇), in_smoke_effect_mult (Twitch + the
  deck's generic dodge), ally_in_smoke_dodge_add (via the new PerkComponent.ally_dodge_add_for).
- perk.tag_team (PerkTagTeam on TagPairs): kill heals 15 / 7.5, kill_extend_s on holder kills, the Synergy absorb pool
  (until the item is off cooldown), tagged_kill_cooldown_cut_s.
- PerkItems service (SVC_PERK_ITEMS) -> LocalHudModel.perk_item + perk_item_changed (ui_hud v1.21). The pocket ECM
  maps into it; pocket_ecm stays as an alias.
- Contract rows perk.sicario and perk.tag_team (phase 5); perk_tweak defaults.
- Tests: test_d163_decks 5/5, test_ui_hud_v1_21 2/2, plus the regressions in the push report.

### (-41) D-163 name-independent systems (2026-10-23)
- ThrownItem KIND_SMOKE (no fuse; a cloud of radius_m for smoke_s) and SmokeZones: crew inside avoid a bullet at
  crew_bullet_avoid (a dodge), enemies inside hit at ×npc_accuracy_mult. No LOS blocking.
- PerkHooks.on_dodge, plus the generic pooled absorb (the best offer per pool, pools add). Maniac now runs on it.
- TagPairs service: aim-line tag, duration / extend, cooldown / cut, paired_holders, replicated as SVC_TAG_PAIRS.
- Tests: test_d163_systems 6/6. Regression: d162 5/5, d161 5/5, d158 12/12, a3_12 4/4, perk_armor 6/6,
  perk_combat 5/5, l3_6 4/4.
- Next: PerkSicario and PerkTagTeam on B's names, and ui_hud v1.21.

### (-40) Round 290/291 lane: escort knobs on, probe warm-up, pocket ECM, D-162, bot revive A/B (2026-10-23)
- **e26cd387:** D-158 amendment 6, RT escort knobs on (1.5 s engage delay, ×0.7 accuracy for 10 s).
- **788bd236:** ReflectionProbe load warm-up (HeistLauncher host and replica) and the safehouse.tscn path.
  - Windowed: verified on 5 probes (2.3–2.6 s).
  - Glasshouse unverified windowed (llvmpipe never finished loading the map).
- **7e9ed5c2:** the mixer driver uses contact_hollis_rt.
- **D-161 pocket ECM (5f09d31a):** EcmSystem jam / feedback charges and PerkPocketEcm. ui_hud v1.20 (bcdff5aa):
  LocalHudModel.pocket_ecm and throwable_id from the deck throwable.
- **D-162 (0ef6e4eb, 3668b28c):** perk.yakuza / biker / maniac on B's names, the CrewKillFeed, and the 3 contract rows
  (LEAD-granted).
- **Bot revive (47a6868f, b643bdae, 03048be7, f6b41619):**
  - Bots reviving bots is now tested.
  - Cuffer targeting / clear-first are knobs, shipped OFF: the headless A/B (12 + 3 runs) showed no gain anywhere and
    the crew lasting 100–190 s less on the rt_clean seeds that diverged.
### (-39) RT levers as knobs + A/B data (2026-10-23)
- **Knobs, defaults = today** (d046e039, 140c1831), test_d158_rt_fairness 12/12:
  - RtTweak: truck_window_from (stop | escort_down, max 60 s), wave1_exclude (with a minimum difficulty),
    escort_engage_delay_s, escort_accuracy_mult and its window.
  - CrewAiTweak.cover_prefer_behind_leader_m (the LEAD ruled it stays at 0).
  - Generic NpcGunner fields: engage_hold_left, timed hit_chance_mult.
  - HeistMission._on_dismounted hook.
- **A/B** (Po5RtAb, headless, RT Hazardous, seeds 1001–1003, crash and clean stops):
  - The window, wave-1 and cover knobs never engaged: the escort decides each run within ~20 s; cover 4.0 hurt.
  - Escort knobs (1.5 s, ×0.7): escort survived in 4/6 runs vs 2/6, crew lasts ~2× longer, seed 1001 lethal either way.
### (-38) Last Breath, P4 ratchet emptied, LanDiscovery (2026-10-23)
- **Last Breath / One Down (6d8b88bc):** CrewHealth.max_downs is 1 (+ defense.downs_extra) with the "last_breath"
  option. test_c4_last_breath 3/3.
- **P4 ratchet (cb61f6c9, 6fa61711):** behaviour tests for all 25 UNTESTED keys (test_a4_04_ratchet_batch1 10/10,
  test_a4_04_ratchet_batch2 12/12, saw keys in test_b4_18 11/11). The gate reports 174 of 175 keys tested; only the
  parked stealth.pocket_ecm is left. The LEAD shrinks the ratchet.
- **B6-05 LanDiscovery (55eaebd4):** UDP lobby beacon and browser host list. test_b6_05_lan_discovery 3/3. API sent to B.
### (-37) A4-03 closed, C4-03 hub loopback, Door height_m, sentry content (2026-10-23)
- **A4-03 accepted:**
  - Real net bug fixed: HeistNetSync XFORM_KEYFRAME_S 2.0 (3a568f94). Unreliable, change-only transforms had left
    still NPCs stale on clients.
  - OfParity history compare (d9f45ec2) fixed the red test_of_coop_loopback.
  - Soak variants: 4 peers, and 2 humans + 2 bots.
  - 600 s runs: no game leak (wave nodes reclaimed, clients flat); the host creep is the test runner's.
  - The soak now releases custody each round (cloaker kicks bypass the immunity mult).
- **C4-03 (e052a322):** test_c4_03_hub_loopback, host + client on safehouse_g1.
  - All hub checks pass on both peers.
  - Gap found: the client's hub stations need InteractionSystem.local (A, done) plus a CrewController tick in the
    client branch (P, routed via the LEAD). Unreachable today (co-op shows the lobby).
- **75400478:** Door.height_m for C (RT gate leaves 2.4 m).
- **D-157:**
  - 89fcee36: SentryGun finds D's model under Visual/<root> and plays its baked deploy clip.
  - 367cdf1d: B's pickup / mode prompts and cue.sentry_deploy. B is to resolve the {mode} key arg in the panel.
### (-36) D-158 RT fairness, A4-03 soak (2026-10-23)
- **D-158 (32a04e1e), test_d158_rt_fairness 4/4:**
  - Seated vehicle occupants have no detection (NpcBase.can_observe is false while META_SEATED_IN).
  - RT truck window: AssaultDirector.first_build_hold_s. RT's stop sets TRUCK_WINDOW_S 30 ◇, so the wave-1 BUILD comes
    at stop + 30 s or later.
  - Bots take cover, or else crouch at their slot, when the followed human is crouched or at a cover point in combat.
  - Data: rt_clean ×3 and WAIT_CONVOY ×3 Hazardous (seeds 1001–1003) are running.
- **A4-03 (5022eb14):** test_a4_03_soak, a host plus 3 client processes.
  - dev_sandbox PASS (+1.7 MB per peer).
  - Dockside found the CratesK visibility desync, fixed via the codec "vis" key. One NPC (net id 98) is still
    5.2 m off on the clients: open.
  - test_of_coop_loopback fails with or without my change: open.
### (-35) A4-01 audit, A4-02 perf scene, L6.2 bot crew, cancel_reload, police port arms (2026-10-22)
- **A4-01 fidelity audit (5aca6ade, 984b124c):** docs/status/env_a_fidelity.md.
  - 103 A rows at phase ≤ P5: 101 covered, S8.7 held, L6.2 a gap (now built, below).
  - The S10.5 test was added.
  - A3-01..A3-13 were all delivered; their 28 test files are green.
- **A4-02 (26509c96):**
  - PerfMonitors (caperworks/* custom monitors).
  - test_a4_02_dockside_perf: Dockside at the enemy cap, 4 crew. Measured: frame p95 11.8 ms, 4.9 ms per physics tick
    saturated, transforms 25.8 KB/s, full state 6.3 KB. The CI budgets are about 2× those.
  - A 220 ms first metal impact appears only without the VFX prewarm (headless only).
- **L6.2 (c6e78cb0):** BotCrew, the bot abilities (inspire, quick, pied_piper, resilient) and boosts (ammo,
  health, stamina, revive, carry). Pending: the LEAD's Loadout fields and B's defs, pickers and strings.
- **02dffce7:** CrewWeapons.cancel_reload for P.
- **e3b29523:** police run at port arms (hold_rifle_port_run, characters v1.39).

### (-34) D-157 crew sentry; 51 skill keys on A's side; AI crew capsules fixed (2026-10-22)
- **f12e25ba, crew sentry (SentryGun under a DeployablePrefab of kind "sentry"):**
  - Deploy costs 40% ◇ of the owner's ammo; pickup refunds the unused share and restocks.
  - Targeting, turn rate, spread and health all scale with the skill keys; frontal shield; quiet / AP modes.
  - Police target it; NpcGunner shoots it; its state is replicated.
  - Node contract for D: Visual/Base/Yaw/Pitch with Pitch/Gun, Muzzle and Shield.
  - DeployableTweak fallback def until B ships sentry.tres. test_d157_sentry 4/4.
- **The 6 sentry keys are hooked:** 51 of 57 keys on A's side. P has hooked its 5 (67b66fd3). Left: pocket_ecm (held).
- **0df59c67 + dcc9fa5e:** AI crew launched without a heister wear the first heister nobody else wears, instead of
  the capsule placeholder.
  - This only happened with P's direct-launch harness; the menus already hand every bot a heister.
  - PO-5 now logs a "crew looks" line at heist start.

### (-33) A4-04: 45 of 57 unhooked skill keys hooked (B1-B6); seated units animate (2026-10-22)
- **Cherry-pick order:** 5e7fd691 (B1), 06962d04 (B2), c8661419 (exit anim), a48b71e7 (B3), 05477b73 (B4), 48608af4
  (B5 Hot Floor + B6).
- **Tests:**
  - test_skills_b1 8, b2 6, b3 5, b4 11, b56 5.
  - The touched suites are green.
  - The P4 gate is 9/9 with the LEAD's ratchet edit (45 keys out of UNHOOKED; movement.speed_mult and weapon.spread_mult out
    of UNTESTED).
- **Fixed in B4:** a B2 crit no longer adds ×3 on top of NpcBase's D-027 crit (the head multiplier on any zone).
- **Left (12):**
  - 5 ADS / sprint keys in P's files (spec sent via the LEAD).
  - 6 sentry keys: no crew sentry deployable exists; the LEAD decides whether A builds one.
  - pocket_ecm (held).
- **Dismount (c8661419):** a seated unit's AnimationPlayer runs while its body is paused, so the exit clip now plays.
- **Values marked ◇ for the LEAD to tune:**
  - skill_stagger_s and armor_broken_stagger_s, both 0.5.
  - Stockholm: 3 s delay, 15 m range.
  - Mark by aim: 0.5 s.
  - Captive Audience shout range: ×1.5.
  - Playing Possum sight range: 60 m.

### (-32) A4-04 B1 skill keys; RT ambush hand-over; Reyes at the wheel; harness hardening (2026-10-22)
- **A4-04 B1 (5e7fd691), 9 keys hooked and tested:**
  - Keys: Inspire, Swan Song, Berserker, Overkill, Bulletstorm, Bullseye, Kickstarter, Messiah ×2.
  - New services: CrewBuffs (timed Modifiers sources plus tags, replicated via SVC_BUFFS) and SkillTriggers.
  - Tests: test_skills_b1 8/8.
  - Pending: the LEAD's ratchet edit and B's blocked_on_keys removal go in the same round. Next: B2.
- **RT Hazardous rt_clean from the ambush spot (2734500b):** 0/3 at full damage, 0/3 at CREW_DMG 0.5.
  - At half damage, 2 of 3 seeds survive the escort. The bot leaving cover is the limit; P's real-input run judges.
  - Po5EscortLog (30bace84) is now a permanent tool: all units CALM at the stop, alerts at t+0.6 to t+8.1.
- **Reyes (603270a8):** visible in the Mixer, plays sit_vehicle_drive; Seat0 drivers of visible vehicles steer.
- **Harness:**
  - 655a39a1: DIRECT resolves the heist id from the display name.
  - 4eac6054: fail fast on an unknown heist or difficulty.
  - dd3a4477: WAIT_CONVOY waits for the stop itself.
- **Regression sweep on trunk 78a57794:** 5/5 PASS (GH, DB, GN, OF loud, SL stealth), 0 script errors.

### (-31) Round 280: mixer test fixed for C's map (2026-10-22)
- **Round 280 red, now fixed:** a/test_rt_a6 test_phase2_mixer_drives_to_its_stop.
  - Cause: the test added a duplicate Mixer and MixerStop next to C's, and Godot auto-renamed both.
  - Fix (ee4525ff, test only): the test now uses C's own nodes, waits for the MixerPath drive, and adds stand-ins only
    when the map has none.
  - The runtime lookup already matched C's path, `<Slot_route_X>/Convoy/Movers/Mixer` and `<layout>/MixerStop`.
  - Results: 14/14 on a-core, and 14/14 on a scratch merge with c-worlds 41bb3e96.
- **Mixer e2e on trunk 78a57794, Routine seed 1001: 2/2 PASS, 0 script errors.**
  - Crash stop (auto_loud, east_crash): Reyes said the boxed line at 42 s; payday at 543 s.
  - Clean stop (rt_clean, east_clean): clean stop at 188.5 s, boxed line at 191 s; ambush sprung; payday at 578 s.
- **D-154 closed:**
  - Hazardous shield share, pooled across 3 RT runs: 9.0% without the Aegis, 13.3% with them.
  - Seed 1003 alone was 26%, and 10 of its 20 bulwarks were Brandt's Aegis.
  - 333b5bf7: Aegis now get their own `STATS aegis=N` line (B / LEAD).

### (-30) RT P5 gate met; D's motion fixes; the padlock pilot; round 277 merged (2026-10-22)
- **P5 loud-bot gate (LEAD: MET):**
  - Routine 6/6: 1001 583 s / 1002 810 / 1003 778 / 4101 750 / 1004 731 / 4102 791. 4-6 bags; downs 0-3 total per
    run; no custody.
  - Hazardous 1001 (WAIT_CONVOY, CREW_DMG 0.25): PASS, 534 s, 4 bags. Downs 3/0/1/3, one AI teammate in custody.
  - Data only:
    - Hazardous full damage: lost at 546 s while holding for the ride.
    - Early-alarm Hazardous / Cataclysm: wiped at about 110 s.
    - Shield and police counts sent to B (balance review).
- **Backlog (LEAD: parked):**
  - Cataclysm RT is not bot-passable: the pilot charges the intact convoy (14 units at Cataclysm strength) and the
    crew is down in about 20 s.
  - A fight-from-range pilot behaviour would fix it.
- **D's motion strips (PO "inorganic"):**
  - a0a876d4: 8-way sector hysteresis + min hold (neighbouring sectors only); phase carry in the walk / run
    families; the stagger plays out.
  - b435e4c4: the back-group +0.10 offset.
  - Reversals of 135 deg or more crossfade in 0.05 s.
  - df90b80d: the resume carry after a short stop (0.3 s window).
  - Pending: D's v1.27 reversal one-shots.
- **auto_loud:**
  - `WAIT_CONVOY=1` (the planned ambush). It also ends when the crash raises the alarm.
  - The pilot works the padlock of a gate at the end of a short path, or of a locked door on the path.
  - It stays with a placed saw (fixing jams) until the lock is off.
  - pad1002b: gate open at t=81, signals rigged at t=120, then stuck at the magazine wall (b8ac58dd fixes that).
- **718cf2c0:** round 277 merged, then --import.
### (-29) RT VO coverage, D's cast fixes, phase-2 mixer ready, round 276 merged (2026-10-22)
- **VO:**
  - Batch: auto_loud 1004 / 4102 and rt_clean 1005, 3/3 PASS. 25 of the 34 RT lines were said e2e.
  - The other 9 are covered by test_the_nine_lines_the_e2e_does_not_reach, so all 34 are said.
- **d32d344e (D's cast review):**
  - staff_waitress / staff_cook look rows; civ_diner = p5_cast's 14.
  - counter_wipe activity + clip.
  - spawn_units takes the least-used seat (two escorts shared Seat0).
- **f62766cc:** phase-2 mixer. With C's `Mixer` ConvoyVehicle and the layout's `MixerStop` (`MixerPath` optional), the
  tannery_gate doors open and the mixer drives. G1's layout swap stays the fallback until C's map lands.
- **982828a4:** round 276 merged, then --import; RT / cast / anim tests green.
- **Waiting:**
  - QC-85 cue defs in cues.tres (B).
  - C's Mixer map.
  - bonds_courier cab safe (truck art).
### (-28) RT e2e: crash 3/3, clean 3/3, all 3 escapes; D/LEAD items; QC-85 cues; round 275 merged (2026-10-22)
- **Crash stop** (auto_loud), success each:
  - 1001: 584 s, E1.
  - 1002: 811 s, E3.
  - 1003: 779 s, E3.
  - 4101: 751 s, E2 underpass.
- **Clean stop** (po5_flow_rt_clean), success each:
  - 1001: east_clean, 534 s, E1.
  - 1002: north_clean, 704 s, E3.
  - 1003: north_clean, 682 s, E3.
  - Each: signals rigged unseen at about t=31, no alarm before the stop, a guard's radio springs the ambush after it.
- **D / LEAD:**
  - Car exit follows `curve.vehicle_exit_<side>` from SOURCE.txt (`AnimTweak.root_curve`); D's 1.05 m curve is now
    in with round 275.
  - v1.26(a): alert armed moving NPCs hold `hold_<kind>_<gait>`.
  - CivilianBrain knows cook_stove / idle (test_anim_driver was 29/30 on trunk 274).
- **QC-85 (bf48786d):**
  - approach / brake / mixer_ram / signal_click / truck_doors_open.
  - freight_train_pass every 90-150 s, held while a Phantom charge is live.
  - **The cue defs aren't in cues.tres yet (B's file).**
- **c9ad2542:** round 275 merged, then --import; the affected tests are green.
- **Running:** a VO-coverage batch (auto_loud and rt_clean now log `EVENT vo`).
### (-27) RT G1 PLAYS END TO END; B's defs in; round 274 merged; clean-stop flow (2026-10-22)
- **RT G1 end to end:** auto_loud seed 1001, Routine, headless: **RESULT PASS**.
  - Crash stop at t=180, escort down at t=200, truck 1 open at t=390.
  - 4 bags secured by t=464, the ride at t=584, success, back in the hub.
- **fd7b0159:** trunk round 274 (59237213) merged. The rolling_thunder.tscn conflict resolved to trunk's ids with
  the 4x3x8 secure zones kept.
- **98908f0a:** B's 8 convoy EnemyDefs installed, replacing mine.
  - Base def = the patrol car with a pistol; frd / sentinel / zero = that faction's TAC Light with a rifle.
  - New EnemyDef params `character`: the faction files wear tac_light (D's looks). NpcVisuals.def_character_id.
- **2a0e7782 (B's HUD):**
  - An alarm during the drive-in now springs the ambush at the stop, with [trucks] / [escort] / [secure] up in the
    same step (no empty objective line).
  - A bark_director teardown guard.
- **ddae2218 (D):** car occupants play vehicle_exit_<side> from the seat while the root slides out over the clip,
  body paused. Armoured-cab crews keep the 1.6 m step.
- **27ed55a7:** ctrl_locked: the cabinet padlock gates the signal rig (C's TODO(A) on ControllerPadlock).
- **po5_flow_rt_clean (LEAD: A writes it; P's windowed RT-P1 / P5 clean-setup run follows its route):**
  - Stealth prelude with X4 shortcuts: man-gate padlock -> cabinet padlock -> rig hack.
  - Back to the start, the convoy to its clean stop.
  - Then auto_loud springs the ambush and plays the rest.
- **Running:** crash seeds 1002 / 1003 and the clean-stop seed 1001.
### (-26) Handover: trunk merged, convoy EnemyDefs, RT audit gaps, G1 pilot's secure-zone bug (2026-10-22)
- **edca000e:** trunk d1ecb0b6 merged.
- **99cc0b98:** the crash-stop test asserts C's 2-3 real trucks.
- **C's asks were already met** (88873eb23 / 5dfef0e19): ConvoyLayouts does `region_set_map`, so rt_convoy_nav.gd can go.
- **f43cc6be: `enemy.convoy_lead` / `convoy_rear`** (D-153 amended: A writes, B reviews).
  - Routine/Tense use patrol health/damage; Hazardous+ use TAC Light.
  - npc_rifle on every difficulty (EnemyDef has no per-difficulty weapon).
  - The look is patrol_officer until D's ids arrive.
  - The mission swaps only the patrol / TAC Light escorts; the rear TAC Heavy and the Wrecker stay. test_rt_convoy_looks passes.
- **Audit gaps** (31766e43, 27a9f07f, 95e862f3):
  - lift_dead: the goods lift is unpowered (`BagLift.powered`), and the LiftBreaker hack restores it.
  - marshal_early: two checks (`GuardBrain.extend_route`).
  - rush_hour: diner customers 3 -> 5.
  - gold_rush pins trucks_3 and t3_bullion.
  - RT assault event rows on C's markers.
- **6b58399f, G1 pilot bug:** the E1/E2 SecureZone (2.6x2.5x2.2) sat inside the van's collision, so only a bag on the
  roof secured. It is now 4x3x8. **C:** mirror it in `tools/levelcheck/plans/rolling_thunder_content.py`.
- **G1 pilot run 1** (seed 1001, Routine):
  - Crash stop, escort down, both trucks sawn (t=390 / 520), bags picked.
  - 0 secured: the zone bug above. Re-running on 6b58399f.
- **Open:**
  - **Clean-stop e2e:** auto_loud masks at t≈7, so every run is a crash stop. A clean stop needs a stealth prelude:
    the man-gate, the SignalRig hack, then mask at the stop.
  - **bonds_courier cab safe:** waits on the truck art.
  - B's vo_coverage.md is stale for RT (all 34 lines are said).
### (2026-10-21 entries)
### (-25) D-152 items done; RT pilot on C's real convoy gets the trucks open (01:10 UTC)
- **(1) OF vault guard margin, 0cc1558d7:**
  - `hub_loops` gets an optional `dwell_add_s` {point: s} plus `dwell_add_max_difficulty`.
  - guard_vault: +15 s at RCNorth (loop (b)'s RC stop) on Routine / Tense / Hazardous, not above.
  - test_of_a6_hub_loops::test_d152_vault_guard_rc_dwell launches OF on Hazardous and Brutal: 15 s, then none.
    S5.1 patrol suite 7/7.
- **(2) RT seats vs D's table, 5dfef0e19, mine:**
  - `seats()` takes the glb's Node3D empties; it was `as Marker3D`, so 0 seats.
  - Seated units face the vehicle's +Z whatever the empty's rotation, and hold `sit_vehicle`: their AnimDriver keeps
    processing while the body is paused.
  - Car occupants dismount with `vehicle_exit_l` / `_r` by seat side. The armoured-cab crew step out beside the cab, as
    D advised.
  - The Lethal Wrecker is never seated in a car (it starts beside it).
  - Seat **heights / row spacing** (D: car seat y ≈ 0.18, cab ≈ 1.20, rows ≥ 1.2 m) are C's glb data; D's note is
    addressed to C.
- **C's convoy-swap asks, 88873eb23:**
  - Off layouts leave the nav map (Godot merges disabled regions).
  - Safe skips a child BurnPoint as loot. Movers pitch with the road.
  - Drive paths found under Convoy/Paths. The RT tests work with real trucks and the drive-in.
- **RT G1 pilot on C's 552f5b154 + a-core** (local merge; the swap is not on trunk r272):
  - The convoy drives in, the early alarm gives a crash stop, the trucks lock down, ambush and escort complete.
  - The pilot saws both trucks and fixes 3 jams (6a39a4c32: the pilot now revisits a large prefab's own
    interactable).
  - A truck opens at t≈391, cargo spawns, and the first bag is picked.
  - The 2nd pick failed: the bags sat inside the hold's collision. 1fa111f56 spawns them on the rear step.
  - Re-running now. RT end to end: **not yet**. I'll post the result here.
### (-24) RT G1 pilot on r270: blocked on C's convoy swap (trucks); everything before the trucks plays (23:55 UTC)
- **Pilot:** `DIRECT=1 HEADLESS=1 run_po5.sh auto_loud 1001 2400 <out> "Rolling Thunder" Routine` (dfbd94a9c, harness only).
  It launches through MenuFlow.launch because RT is not on the Board yet: hidden, WIP def.
- **First run (r269):**
  - menus → heist → setup (casing done).
  - An early guard_radio alarm gives the crash stop at ETA 180 into `east_crash`: layout swapped, police at once,
    escort down in about 9 s.
  - It then stops at "secure is the only marked objective but no bag source is usable".
- **Why it stops:** **the r270 map still has C's placeholder convoy boxes.** There's no armored_truck, no movers, no
  `<Veh>Stop` markers and no per-layout nav. C has the RT-C2 swap in progress and hasn't pushed it yet. I've asked for an
  ETA and will run the pilot on C's branch merged locally the moment it's up.
- **Found and fixed:** 215cba409, the trucks / escort objective data was re-published every second; now change-only.
- **Also from the run:** charges / thermite "not reachable". C says this is by design: the site's padlocked gate and
  store doors. The pilot doesn't open padlocks; both are optional, and the saw needs no pickup.
- **RT does not play end to end yet.** Don't tell B / P until the trucks are in.
### (-23) r268 merged; D's RT look rows in; the GPU-20c hitch answer is item -21 (22:30 UTC)
- **GPU-20c hitch accumulation:** your r268 note asked for it. It's in item -21: no accumulation in the simulation
  (census t=300 vs t=1200), and the windowed rise is location / phase load.
- **npc_visual_tweak RT (D's list):**
  - The 9 street_pedestrian looks (base, b-i) join civ_street / civ_bus / civ_diner.
  - New rows: `staff_diner` [diner_waitress, diner_cook], `staff_booth` [carpark_attendant], `driver_mixer`
    [contact_hollis].
  - convoy_lead / convoy_rear are NOT mapped (D-149.12: EnemyDef looks).
  - test_cast_look_pools 10/10, tag_first 2/2.
- **test_rt_convoy_looks still SKIPs:** no `enemy.convoy_lead` / `convoy_rear` EnemyDef exists on trunk yet. Who
  writes them, B (data) or D?
- **On the r268 merge:**
  - RT-A5 / A6 / A5-0x: 19/19.
  - B's test_vo_coverage: 10/11. The 11th is B's placeholder (expects at least 30 unsaid RT lines; the mission says
    all 34), and B is asked to flip it.
  - test_heist_readiness: 9/9.
### (-22) RT-A5 ambush hooks + RT-A6 mission stage 1; **merge RT-B1 (env/b-content) with or before this** (21:45 UTC)
- **175b9d877 RT-A5 (QC-83 / D-149.7):**
  - `HeistMission.raise_alarm(reason)`.
  - `spawn_units(enemy_id, count, tag, seated, vehicle)`: a ConvoyVehicle's seats or beside a plain body. Seated units
    are paused, hidden in an armoured cab (replicated as NPC state "hid"), and are not bot targets.
  - `dismount_units`.
  - Mission units sit outside the assault force pool, and non-police ones share the police cap (`police_budget`
    generalises the cartel rule).
  - NPC meta `alarm_reason`: its radio call, or its death in place of a pager, raises that alarm ("ambush").
  - `civilians_flee(&"civ_flee")`: a loud flee to an exit, then despawn.
  - test_rt_a5_ambush: 5 tests. Regressions green: s3 / s5 / l1 / qc36 / l6 / gn_c_gaps / mission timers / coop
    loopback.
- **02da5f92f:**
  - Rare-event `force_active` takes an Array of pins (C's gold_rush ask). Variant rules: 12/12.
  - ConvoyVehicle `drive_started`.
- **9fff6e120 RT-A6 stage 1, `rolling_thunder_mission.gd` (replaces C's stub):**
  - Setup clock: marshal at ETA−75 (−90 on marshal_early), ETA 60 / 30, sighted at −20, convoy_early −45.
  - Signals: the hack done means a clean stop. Otherwise, or after an early alarm, a crash stop.
  - Early alarm: police at once and truck lockdown.
  - The stop: movers drive onto the layout's `<Veh>Stop` markers if the map has them, otherwise the layout pops in. Then
    convoy units, and on a clean stop the 3 s mixer move and the 8 s window ending in `raise_alarm(&"ambush")` with
    dismount 4 s later. A crash means the impact is the alarm and units are out at once.
  - Trucks opened n/N. A truck carrying no cargo spawns cash_bags / gold_bags at its LootAnchor when it opens.
  - Escort down, then [secure] 4 bags, then the ride after escape_eta_s (+20 s heli).
  - bonds_courier bags. Longshot perch lines.
  - **All 34 of B's RT lines are said.**
  - test_rt_a6_mission: 3 tests on C's real G1 map.
- **Merge order:** the mission says B's new `vo.*.rolling_thunder_*` ids.
  - On env/a-core alone, test_vo_coverage `test_no_missing_ids` fails until RT-B1 is merged.
  - Merged locally with env/b-content, 10/11 pass. The 11th is B's placeholder `test_staged_heist_lines_wait_for_their_mission`
    (asserts at least 30 RT lines unsaid; now 0). B is asked to flip it and add RT to HEISTS.
- **Not ready yet (keep RT hidden):** G1 has no `armored_truck` prefabs, only boxes, so [trucks] has nothing to open.
  I've asked C to place truck prefabs per layout for G1, with movers in RT-C2.
- **4563a3879 + 1b7ee472c, stage 2:**
  - Rare events: convoy_early / marshal_early from their effect values, informant_tip reveals, crane_sniper opens S3
    (closed otherwise), Ashby S4 closed below Hazardous, an armored_escort Wrecker in the rear escort, and
    rush_hour / the `civilians` scalar thin the street to 6 / 9 / 12.
  - gold_rush only needs C's data as a force_active Array.
  - Convoy units carry `convoy_lead` / `convoy_tN` / `convoy_rear` spawn tags, so D's RT look rows apply to the
    Vaultline crews. The escorts switch to `enemy.convoy_lead` / `convoy_rear` once those EnemyDefs exist.
  - test_rt_a6_mission: 4 tests.
- **Waiting on others:** the staff_diner / staff_booth tag rows wait for D's look ids (RT-D2).
### (-21) GPU-20c follow-ups done; RT A5-01 / A5-02 / A5-03 in (20:30 UTC)
**1. AI crew killed civilians: fixed, 6fa54bd59.**
- Bots never targeted civilians (the scan only takes HOSTILE_ROLES). The kills were rounds through civilians on the
  line of fire.
- `crew_ai_brain._civilian_in_line`: a bot holds fire when a civilian's body, as a vertical segment from 0.2 to 1.7 m,
  is within `civilian_line_clear_m` (0.6) of the shot line. The line runs from 0.3 m in front of the eye to
  `civilian_line_past_m` (4) beyond the aim point, which covers a miss. At scan the bot also skips that target for
  another.
- New test `test_gpu20c_bot_civilian_fire`: a civilian kept on the bot's line means no round is spent and the civilian
  is unharmed; once the civilian steps aside, the bot kills the cop. It fails without the fix.
- Regression tests: l6 16/16, po6_14 7/7, l2_12 9/9.

**2. Hitch build-up: no accumulation in the simulation, so not a VFX pool leak.**
- Run: headless OF Cataclysm 1037, HITCH_MS=50, CREW_DMG=0 (the pilot survives the long run), with a new CENSUS line
  every 60 s (22af03e38): node classes and the fullest parents.

| t | nodes | GPUParticles3D | Decal | PhysicalBone3D | Area3D | enemies |
|---|---|---|---|---|---|---|
| 303 | 20,768 | 121 | 115 | 588 | 372 | 20 |
| 603 | 19,846 | 131 | 121 | 468 | 308 | 18 |
| 903 | 19,535 | 154 | 121 | 420 | 282 | 16 |
| 1203 | 19,552 | 154 | 121 | 420 | 282 | 16 |

- **Counts:**
  - Decals sit at the pool cap (121).
  - Particle emitters fill their capped pools by about t=900, then stay flat.
  - Bones and areas follow the NPC count.
  - Total nodes go down.
- **Per-system costs:** flat over time (median ms per call in the hitch frames).
- **Hitches per 150 s window:** 67 / 332 / 597 / 214 / 613 / 264 / 171. They follow the phase and action, not elapsed
  time.
- **GPU-20c's windowed data, re-binned:**
  - Median hitch frames are 61-68 ms in every window.
  - The rise in count comes with more draws (median 1,645 -> 2,023) and more process time during the cash-carry phase.
  - VRAM is flat at 2.99 GB, and no pipeline compiles.
- **Reading:** the GPU box's 26/190/439/604/118 is where the run is (the cash-carry route's draw load with 25+ enemies
  near the pilot), not something piling up. GPU-20b on the same tree at 0.046% fits that: a different path.
- Not a C or D-113 issue.
- **To separate place from time,** the GPU box could do a windowed run with `FOCUS` / an early bag carry, so the
  cash-carry route comes early. Same draws early means location.
- **Side note:** the two headless OF Cataclysm 1037 runs at full or 0.25 damage lost to the known Cataclysm wipe
  pattern (pilot downed, cuffed while bots revived, all 3 bots down near Brandt), not a regression.

**3. RT build (D-151), all on env/a-core with tests:**
- **b5f190684:** merged trunk r267.
- **484adf31d A5-01 `armored_truck`:**
  - Safe LARGE with saw + C4, charges_required 4, G.SAW_TARGET.
  - `lockdown()`: saws ×1.5 placed and by hand, via InteractionTweak.truck_lockdown_saw_mult. New Safe
    `hand_saw_duration_s` / `saw_time_mult` and DrillPoint `duration_mult`.
  - Cargo inside until open.
  - QC-81: burn_point `target` plus `fire_volume_size` ZERO means no fire.
  - test_a5_01: 4 tests.
- **e0ee068b6 + b6d288620 A5-02:**
  - `convoy_vehicle` mover: Path3D drive, braking onto its stop marker, static after, `vehicle_stopped`, seats,
    `_net_xform`.
  - `ConvoyLayouts` plus `HeistRuntime.set_layout(id, group)`. Per-group layouts ("convoy", "mixer", "tannery")
    swap their pre-baked nav regions and links, TacticalPoint cover, bodies and prefabs. `convoy_open_nav` marks the
    open road they replace. Everything is off at heist start, and the state replicates in SVC_RUNTIME.
  - test_a5_02: 4 tests. Coop loopback, c11 and C's test_rt_loud_nav_targets are still green.
- **b0caf2b8a A5-03:**
  - `item_pickup` prefab (`item.c4` × count).
  - Pre-planning `item.*` drops become such a box (`params.count`). `asset.c4_drop` can use `drop = &"item.c4"`,
    `drop_params {count: 4}`. B: HUD count.
  - Truck method order: C4 before the saw, offered only to a crew member carrying 4 charges.
  - test_a5_03: 2 tests.
- **For the LEAD:**
  - New prefab kinds `armored_truck`, `convoy_vehicle` and `item_pickup` need `gameplay_prefabs.md` rows. Proposed:
    - armored_truck: Safe exports plus `lockdown()`; visual Body/Door/DrillPoint/LootAnchor (+Cab).
    - convoy_vehicle: `vehicle_kind`, `speed_mps`, `accel_mps2`, `brake_mps2`; `drive(path, stop)` / `park(stop)`;
      visual Body (+Seat0..n).
    - item_pickup: `item_id`, `count`.
  - QC-87c: `lc_context.set_layout_config` treats every `convoy_layout` node as one set. With groups, it could
    iterate per `layout_group`. I've told C.
- **Next:** RT-A5 (QC-83 raise_alarm(reason), spawn_units seated/dismount, the convoy cap share, civilians_leave at
  the alarm), then C's other asks, then rolling_thunder_mission (reported not-ready until G1 plays end to end).
### (-20) GPU-20b: the heist cap is now a flag (17:20 UTC)
- **01633ed17:** auto_loud's heist-time cap is `--po5-heist-cap=<s>`, or `HEIST_CAP=<s>` with run_po5.sh.
  - The default is now **2400 s** (it was a fixed 1500).
  - The FAIL line prints the cap used. Checked: HEIST_CAP=30 on GH gives "no heist end within 30 s".
- **deposit_boxes:** agreed, it's optional. The pilot skips it (no hand saw), and its VaultBox markers are
  skipped via marker_skip_prefixes. It has never blocked anything in my OF runs.
### (-19) Regression sweep on trunk b0bd47a0: 4/4 PASS + SL stealth PASS, once P's cb8be306d is merged (16:55 UTC)
Headless auto_loud, **Routine**, seed 1001, on env/a-core with trunk b0bd47a0 merged.

| heist | first run | root cause | fix | after fix |
|---|---|---|---|---|
| Golden Hour | FAIL (3 downs) | **harness**: `Po5Pilot.next_corner` chose the nearest path leg in 2D, which picked the upstairs leg right overhead. The pilot steered at a point 4.4 m above it and paced the ground floor under fire for 90 s | A **24c02e56c**: nearest leg in 3D, plus test_next_corner_ignores_the_leg_overhead (fails without the fix) | **PASS**, 283 s |
| Nightfall Depository | FAIL (3 downs, 36 STUCK) | **game** (P's crew_ladder_climb.gd): a human climbing up the AreawayLadder never finished stepping off. The Top marker is at x 17.2; CageWest stops the 0.35 m capsule at 17.35, which is 0.151 m out (the check needs < 0.15). The step-off vy keeps the crew off the floor, so `grounded` never turns true, and W stays overridden. A real player is soft-locked; only jump frees them, into the 4 m pit. Deterministic repro: PTraversal.ladder(AreawayLadder) up=false. Likely exposed by the 0d0a1ab05 capsule fix | P **cb8be306d** on env/p-play (a stalled step-off lets go; test in test_p_ladder_free_climb). **Please merge it** | **PASS**, 665 s (local: env/a-core + cb8be306d, six AreawayLadder climbs all OK). Without it: the up climb FAILED again and the re-run looped on the ladder; I stopped it at 1510 s |
| Gallery Night | PASS, 518 s, 0 downs | none | none | PASS |
| Dockside Burn | PASS, 808 s, 0 downs | the errors=1 was **harness**: `Po5Pilot.use` read `comp.kind` after a bot picked the bag up mid-fight (freed) | A **0d868f9ed** | PASS |
| Shadow Ledger stealth | PASS (no PO-5 SL flow, so I ran test_x4_sl_stealth) | none | none | PASS |

- **Game bugs found:** 1, the ladder soft-lock, fixed by P. Any ladder whose Top marker sits closer than about 0.35 m to a wall would have trapped a human the same way.
- **No regressions** from today's other systemic changes: NavPath, glass gunfire plus close-in, cuffs, revive clear, Longshot.
### (-18) Your r264 re-runs: the cuff fix is confirmed; the revive-clear change is not a win-rate lever (15:25 UTC)
Headless on env/a-core 2dbfbb29 (= r264's A side).
- **Cataclysm 2024 (CREW_DMG=0): ends cleanly.**
  - Tase at t=1015 -> DOWNED 1025 -> CUFFED 1029 -> **CUSTODY 1055** (the bleed-out runs while cuffed), then "FAIL
    player in custody at 1056 s".
  - One cuff, no CUFFED <-> DOWNED cycling (it was 15 cycles over 15 min). Still a loss: the accepted Cataclysm
    harness limit.
- **DB Tense ×3 + GH Tense 4501 with the revive clear (2 s on an enemy within 3 m before kneeling):**

| run | result | player downs | end |
|---|---|---|---|
| DB s1 | FAIL | 3 | custody at t=584 (900 damage taken in 554 s loud; tac_light 344) |
| DB s2 | FAIL | 3 | custody at t=719 |
| DB s3 | **PASS** | 2 | heist_ended at 842 s |
| GH 4501 | **PASS** | 0 | heist_ended at 266 s |

- **Read:**
  - The clear behaves as built, and the bots revive fast. In s2 the three downs at t=651 / 666 / 677 were each
    revived in 7-13 s.
  - s2 is lost to down density, not revive behaviour: four downs in 70 s near (43, 0, -25), and a Longshot did
    270 of the 941 damage (6 hits from 30 m and beyond).
  - B's r257 cell (2/3) and this one (1/3) are within 3-seed noise. The tree shifts the RNG streams, so seed-for-seed
    comparisons across trees don't hold.
  - I'd keep the clear (it removes the wipe pattern) and treat DB Tense as accepted at about 2/3, as you ruled.
  - If you want a firmer number: B's ×3 on r264 plus mine is n=6.
### (-17) Your cuff-loop bug (Cataclysm 2024): fixed, for the next round (15:00 UTC)
- **(1) Why it toggled:** L2.12 as built.
  - A police-cuffed downed heister had a 60 s self-free (CustodyTweak.police_cuff_self_free_s ◇) back to DOWNED,
    and the bleed-out was paused while cuffed.
  - The cop at 1 m re-cuffed at once, so the bleed-out only ran in the short DOWNED windows: 15 cycles, about
    15 min.
- **(2) Why no bot came:** they couldn't.
  - Slots 2 and 3 were Phantom-kicked at t=557 and t=568 and bled out at t=587 and t=598. Slot 1 was tased, then
    downed, and in custody at t=614.
  - Cataclysm is trade-only, and a trade needs a free crew member, so nobody came back.
  - Bots do target cuffed teammates: CrewAiBrain.needs_help includes CUFFED, and
    test_l2_12_ai_uncuffs_and_revives_cuffed_downed_human passes.
  - The all-custody fail never fired, because the pilot was CUFFED, not in CUSTODY.
- **Fix:** police cuffs have no self-free, and the bleed-out keeps running while cuffed. A teammate uncuffs (back to
  DOWNED, revivable) in time, else custody. In 2024 the run would now end in all-custody about 30 s after the last
  cuff instead of 15 min later.
  - Stealth guard cuffs (S3.2, the 60 s escape) are unchanged.
  - Tests: l2_12 9/9 (updated: no timer, the bleed-out runs, custody at the end); s3 36/36, l6 18/18, l2_ 55/55,
    l2_9 8/8.
- **Doc ask (yours):** pd2_fidelity L2.12 (b) still says "60 s self-free (◇)". It should read "no self-free; the
  bleed-out keeps running while cuffed; a teammate uncuffs (LEAD 2026-10-21)".
- **Next:** your OK'd DB seed-1 proposal (bots clear enemies within 3 m before kneeling).
### (-16) DB Tense seed-1 custody chain (low priority), headless on 43d8b5a6 (14:20 UTC)
**The chain: a revive pile-up at the secure zone ends in a crew wipe.**
- t=523: the crew carries cash from the cages to the dock (secure zone around (31, 0, -18)), 4 enemies alive.
- t=543: the pilot picks up a cash bag beside the zone. A wave lands: 13 enemies, 3 within 15 m.
- t=546-576: all four crew go down or get tased within 4 m of each other. Bots kneel to revive with enemies 0.6-1.0 m
  away (TEL `nearest_enemy=0.6m`, "bots while down: 1:REVIVE ... 2:REVIVE ... 3:REVIVE").
  - Each revive is broken off or followed by the reviver's own down. One last-stand revive lands (slot 3, t=575).
- t=592-606: all 4 in custody (bleed-out).
- Pilot intake: 610 damage in 549 s loud, 1.11 dmg/s, mostly from under 10 m: tac_light 262, Bulwark 127.5,
  patrol 75, Longshot 45.

**Read: no bug; a tactics gap in the bot revive rule.** PD2 bots do revive under fire, but they are tanky (PD2
team AI takes reduced damage). Ours revive at full exposure with the attacker in arm's reach.

**Proposal (A-owned, small; your call, since DB Tense is accepted at 2/3):** before kneeling, a bot spends up to
crew_ai_tweak.revive_clear_s (2 s) on any enemy within revive_clear_m (3 m) of the downed member. This is the
pilot's REVIVE_THREAT rule applied to bots.
- Last stand (the final revive before custody) skips the clear.
- I'd validate with DB Tense ×3 and GH Tense ×1, not merged before you say so.
### (-15) OF robustness headless (your 12:59 ask), on env/a-core 43d8b5a6 = trunk 40ef789d + A (13:50 UTC)
| run | result | end | how it ended |
|---|---|---|---|
| **Routine 1037**, crew dmg ×1.0 | **PASS** | heist_ended success, time_s **1307.9** | 4 cash secured (t=716 / 911 / 1103 / 1157), secure -> 2 at t=1157, escape. |
| Cataclysm 2024, CREW_DMG=0 | FAIL | custody at t=1476 (budget 1800) | A Stinger tase at t=596 -> DOWNED -> CUFFED. Then 15 cycles CUFFED <-> DOWNED about every 61 s with no rescue, until custody. |
| Cataclysm 4711, CREW_DMG=0 | FAIL | custody at t=1221 | A Phantom kick (CLOAKER_DOWNED) at t=1113 -> downed -> custody. |
- **Both Cataclysm losses are the accepted hardest-difficulty harness limit** (PO, D-148 note). CREW_DMG=0 nulls
  damage, but not tase, cuffs or the Phantom kick.
  - No systems gap: the hoist cycle ran (4711: sent and unloaded at t=1087).
  - The cage re-test fired: "VaultCash has a navmesh path again" at t=705.
  - The t≈1025 "could not reach VaultCash" were the pilot boxed in by live police (Npc_police5 / 6) in a corridor
    mid-fight, not a nav gap.
- **Pilot inefficiency left** (harness, not blocking): 4711 still lost two missed hoist tosses (t=714, 855) to bots
  that caught them before the pilot could pick them up. A drop instead of a throw would be the real fix, but the
  player's G is always a throw; C-held drop is ENV P's input. If you want it, I'd ask P for a "short toss when looking
  down past N°".
- **Game question (yours):** seed 2024's 15 CUFFED <-> DOWNED cycles. A cuffed player goes back to DOWNED every
  60 s (the cuff timeout?) and is re-cuffed at once, with the bots never freeing them on Cataclysm.
  - Per PD2, the arrest should go to custody straight away rather than loop. If the loop isn't intended, I'll look at
    CustodySystem's cuff -> custody path next (A-owned).
### (-14) **OF loud Cataclysm PASSES headless** (hoist7, env/a-core 1057052c = trunk r260 + A) (11:40 UTC)
OF Cataclysm, seed 1037, auto_loud, no FOCUS, CREW_DMG=0, budget 1800:
```
[PO5 917.6s] .../VaultCash/Interactable has a navmesh path again: retrying     (the cash-cage re-test, 9fbfa229)
[PO5 929.5s] hoist: Hoist sent from landing 0 with 1 bag(s) (t=889)  ... x6, each followed by
[PO5 935.6s] hoist: unloading Hoist at landing 1 (1 bag(s) in the car)
[PO5 956.4s] EVENT loot_secured loot.cash_bricks 8000 t=915       ... t=973 / 1028 / 1082 / 1150 / 1208
[PO5 1266.4s] EVENT objective secure -> 2 t=1208
[PO5 1393.6s] EVENT objective escape -> 2 t=1329
[PO5 1393.6s] EVENT heist_ended { "heist_id": &"ostrander_federal", "success": true, "stealth": false, "time_s": 1328.5 ...
[PO5 1403.8s] RESULT PASS (code 0) flow=auto_loud heist=Ostrander Federal seed=1037
```
- **GPU-21, the final windowed proof:** the same command as GPU-20 (item (-11)), on **env/a-core 1057052c or later**
  (or trunk once that is merged). Budget 1800 is enough: the heist ended at 1328 s.
- Run log: scratchpad hoist7/run.log on this box. I can push an excerpt under game/tests/a/e2e/captures/ if you want
  it in the repo.
- This run had no bond_safe; with no FOCUS it is optional, and hoist6 got it at t=777.
### (-13) hoist6 headless, plus the trunk r260 merge (1057052c) (11:20 UTC)
- hoist6 (OF Cataclysm 1037, 1800 s, **no FOCUS**, 7d2cd968):
  - Default pick order: `bond_safe -> 2` at t=777. (d) is confirmed.
  - Gold went up the hoist and was secured twice (t=836 and t=1052).
  - Still FAIL: no cash moved. With the cash cage shut, VaultCash was marked "unreachable for this run (no navmesh
    path)" at t=634. The cage padlock was sawn 6 s later, but that mark was permanent.
  - Fixed in e9bf7650 / 9fbfa229: a "no navmesh path" mark re-tests the path every 10 s and clears once the gate or
    cage opens.
- **GPU-20 (7c7a014b) will likely end the same way.** If it does, re-run it on **1057052c or later**.
- Merged trunk r260 into env/a-core (1057052c). Targeted after the merge: of_mission 20/20, a1_08_npc_gunner 9/9,
  po6_14 7/7, rt_ 7 (1 SKIP: the convoy defs).
- hoist7 is running on the merged head.
### (-12) hoist5 headless: the hoist cycle works; two last pilot gaps fixed (7d2cd968); hoist6 running (10:50 UTC)
- hoist5 (OF Cataclysm 1037, 1700 s, c307fb90): 5 cash bags went up, each cycle "Hoist sent" -> "unloading" ->
  `loot_secured loot.cash_bricks`, about 55 s apart (t=1079 / 1133 / 1191 / 1245 / 1299).
  - Still "no heist end within 1500 s". Two pilot gaps, both fixed in 7d2cd968:
    1. Three tosses missed the car (t=660 / 800 / 939). Each fed a bot that stood at the rope ladder for about 140 s.
       The pilot now picks a missed bag straight back up and tosses again from the next spot round the car.
    2. With the cash done and the gold cage open, the only markers left were `secure` and the stalled
       `deposit_boxes`. The fallback still picked the stalled boxes: 9 min "waiting at deposit_boxes".
       It now falls back to `secure`, whose _fetch_bag takes the gold.
- GPU-20, item (-11) above: 7d2cd968 or later is better. hoist6 (no FOCUS, 1800 s) is running on it.
### (-11) **GPU-20 command: send it now** (the box is idle; every hoist fix is pushed) (10:30 UTC)
Tree: env/a-core **7d2cd968 or later** (see (-12)), either merged onto trunk or env/a-core HEAD as is. OF loud, Cataclysm, seed 1037,
windowed, budget 1800, no FOCUS:
```
CREW_DMG=0 HITCH_MS=50 game/tests/a/e2e/run_po5.sh auto_loud 1037 1800 <out_dir> "Ostrander Federal" Cataclysm
# raw (Windows box):
godot --path game res://tests/a/e2e/po5_runner.tscn -- --po5-flow=auto_loud --po5-seed=1037 --po5-budget=1800 \
  --po5-out=<dir> "--po5-heist=Ostrander Federal" --po5-difficulty=Cataclysm --po5-crew-dmg=0 --po5-hitch-ms=50
```
**New since GPU-19 (0210e889):**
- d6163c75: bots leave a bag lying in the hoist car (in hoist2 they fetched them and stood at the rope ladder).
- b9485fc1 / c307fb90: the pilot unloads the car up top before calling it down, never calls a loaded car, and waits
  for a car on its way up (in hoist3 / hoist4 the same bags rode up and down).
- 5d945bea: escort legs arrive at 3.5 m.
  - (c) has no map snag: the nav path from (4.6, 0, -1.2) is clear. The leg ended 3.25 m out at the van's rear corner.
- (d) bond_safe: the default order is cash, gold, deposit boxes, then bond_safe. The deposit boxes cost a 30 s stall,
  since the pilot has no hand saw. GPU-19 never got that far.
- 711f7a6f / 7971d86d: the glass gunfire fix, plus a guard with no shot line closes in.
  - D's GH Tense case re-run on my head (glasshouse, seed 1002, 240 s): security_officer aim_pistol 455 s -> 5.5 s,
    fire_pistol 0 -> 1.1 s, and both guards fight and die (death_back 454 s).

**What to read in the log:** "hoist: Hoist sent", "hoist: unloading", "EVENT loot_secured loot.cash_bricks",
"EVENT objective secure -> 2", "LOAD pipelines compiled under the loading screen", "HITCHES".
- My headless hoist5 pass (same seed) has been running since 10:18. Its result goes here.
- (send_message to your session is still refused: "trusted device".)
### (-10) Relayed from ENV B: DB Tense on r257 + 60d8c6ab (with P's capsule fix) = 2/3 in both cells
- Plain: 2/3, player downs 3 / 3 / 1 (median 3). With --po5-doctor-bag: 2/3, downs 6 / 2 / 2 (median 2).
- Seed 1 loses in both cells: custody at about 640-690 s.
- No crashes with the engage fix. Details: top of docs/status/env_b.md (57ad5034).
- **A's read:** Tense is now 2/3 without data levers. The doctor bag lowers the median downs but does not flip seed 1.
  I'd keep the data as is (no Bulwark cap change) unless you want 3/3. If you do, look at seed 1's custody chain
  first rather than a global lever.
### (-9) Merge ask: env/a-core 60d8c6ab (pilot engage() vs freed target) for the next round
- ENV B hit signal 11 in po5_pilot.engage again: plain DB Tense s2 on trunk r257 70471c50, which does not carry the
  fix. The crash kills the run.
- B is re-running on r257 + 60d8c6ab (cherry-picked) for now. r257 plain so far: s1 custody at 642 s (3 downs),
  s3 PASS at 889 s.
### (-8) OF hoist-carry validation: two more blockers found and fixed, re-run going (09:15 UTC)
- **hoist2** (headless OF Cataclysm 1037, 1700 s, CREW_DMG=0, 0210e889c): the pilot's hoist routine works.
  - It made 6 trips ("hoist: Hoist sent from landing 0 with 1 bag(s)"), and cash was secured at t=721 and t=725.
  - The run still ended "no heist end within 1500 s": only 2 of 6 bags were secured.
- **Game fix (crew AI, d6163c75f): bots took the bags out of the hoist car.**
  - The PO6-14 rule fetches any bag a human just threw (G / drop_bag is a throw), and that included bags thrown into
    the hoist car. Slots 1-3 then stood at the rope ladder with the cash for 4 min, since a carried bag can't climb.
  - Now a thrown bag lying in a BagLift car rides the lift. New test test_of_bot_leaves_a_bag_in_the_hoist_car fails
    without the fix. po6_14 7/7, l6 15/15, a3_09 bag lift 8/8, po6_15 4/4.
- **Pilot:** the hoist try cap counted trips, not failures, so the pilot gave up after 6 good sends. Fixed.
- **Your call:** a cop in melee range (0.4 s windup + 3.0 s cooldown) cancels every empty-mag reload (3.5-7 s).
  - The pilot sat at 0/131 for 140 s. It now draws its loaded sidearm, else melees (0210e889c).
  - Real players hit the same lockout, and it is PD2-like (a melee shove cancels a reload), so I'm proposing no change.
- **hoist3 is running** with all of this. The GPU command follows when it passes.
### (-7) D-149 A items: QC-RT1 needs one contract edit from you; the escort-look test is in
- **(1) QC-RT1 TacticalPoint `enabled`:** `game/contracts/map/tactical_point.gd` is LEAD-owned, so here is the patch,
  verified locally and not committed.
  - Off = out of its kind's group. Every consumer reads the groups live (HeistMap.get_slots / get_nodes_in_group:
    AssaultDirector.valid_spawn_points, police / crew / suppression cover, flank, perches, RappelLinks, Bulwark
    anchors, AegisCaptain), so no consumer changes.
  - Default true, so maps are unchanged.
  - Test: game/tests/a/test_rt_tactical_point_enabled.gd (on env/a-core). It SKIPs "pending the LEAD contract"
    until you apply the patch, then passes: 2/2 with the patch applied locally.
```diff
--- a/game/contracts/map/tactical_point.gd
+++ b/game/contracts/map/tactical_point.gd
@@ -14,6 +14,26 @@ const _GROUPS: Dictionary = {
 @export var tags: Array[StringName] = []
 ## For ENTRY points: is this a breachable window/door (VariantSlot may toggle).
 @export var breachable: bool = false
+## D-149 QC-RT1: off = out of its kind's group, so no consumer sees it (every lookup reads the groups live). Missions
+## toggle it when a pre-baked nav region swaps in (RT convoy layouts, the mixer, the Tannery gate).
+@export var enabled: bool = true:
+	set(v):
+		enabled = v
+		if is_inside_tree():
+			_sync_group()
+
 
 func _ready() -> void:
-	add_to_group(_GROUPS[kind])
+	_sync_group()
+
+
+func set_enabled(on: bool) -> void:
+	enabled = on
+
+
+func _sync_group() -> void:
+	var g: StringName = _GROUPS[kind]
+	if enabled and not is_in_group(g):
+		add_to_group(g)
+	elif not enabled and is_in_group(g):
+		remove_from_group(g)
```
- **(12) Escort looks:** game/tests/a/test_rt_convoy_looks.gd asserts that enemy.convoy_lead / convoy_rear have a
  character scene (NpcVisuals.def_scene_paths) on every difficulty, so never a capsule. It SKIPs until the EnemyDefs
  exist (RT systems, after the OF done check).
- **D's npc_visual_tweak RT rows:** when prep/d-rt merges.
- **OF first:** the hoist-carry validation run is going (headless 1037, 1700 s). The GPU command follows when it
  passes.
### (-6) OF-done items 1 and 2 (your GPU-18 message)
**1. BondSafe: verified.** Headless OF Cataclysm 1037 auto_loud on env/a-core 13d889844, `FOCUS=bond_safe`
(new --po5-focus), CREW_DMG=0:
```
[PO5 590.6s] EVENT objective vault_breach -> 2 t=563
[PO5 590.7s] EVENT objective bond_safe -> 1 t=563        (appears with the burn-through, 6fcbb559)
[PO5 599.8s] pilot: use BondSafe (place_drill) -> OK in 3.0 s
[PO5 622.3s] pilot: use BondSafe (fix_drill) -> OK in 2.0 s
[PO5 668.0s] EVENT objective bond_safe -> 2 t=638        (completed)
```
- The cash-cage handoff works in the same run:
  - The pilot sawed the CashCage Padlock (place_saw 616 s, fix_drill 637 / 655 s).
  - `[vault_loot]` switched to the cash at t=630 (`vault_loot -> 1 t=630`, the marker update).
  - `use VaultCash (bag_loot) -> OK` at 663 s.
- **New pilot gap after that:** carrying the cash, it tried the rope ladder up for 3+ min ("RopeLadder up -> FAILED"
  ×20). Ladders refuse a carried bag (S10.1b); the doc's way up is the hoist.
  - Harness fix in progress: goto stops at a ladder when carrying a bag, and the pilot takes it up the hoist like a
    player (call the car, drop the bag in, send it, climb empty-handed, carry it on).
  - A validation run is going now. Not game code.
- **Stair stall (b480, Npc_police13/14 on SAFlight2W):** the pilot only side-stepped. It now shoots a live enemy it
  is pressed against (13d889844; new line "pilot: <npc> blocks the way: shoot"). The next GPU run shows whether it
  clears.
- **`goto (3.5, 0.2, -4.3) FAILED` ×4 at 322-335 s:** not failures. These were the pilot's own 4 s carry legs with
  the server-drives bag, progressing each time; the bag was secured at 338 s. Those legs are quiet now.

**2. Heist-load 3.1 s frame (t=0.1): a harness artifact, not what a player sees.**
- PO-5 turned rendering off (`set_fast(true)`) right at "Start Heist". No heist frame rendered under the loading
  screen, so every pipeline compile (78 surface + 49 spec) and anim_driver's first ticks landed on the first frame the
  harness drew.
- In play the render loop stays on: HeistLauncher.launch() awaits two physics frames plus the nav sync with the 3D
  world rendering under MenuFlow's opaque loading screen (CanvasLayer 50), and returns only then.
- 13d889844 makes the harness do the same, rendering through the loading screen and the first 5 heist frames. A new
  line reports where the compiles land:
  `LOAD pipelines compiled under the loading screen N, over the first 5 heist frames M (worst frame X ms)`
- **Ask:** on the next GPU run, if M > 0, those are compiles a player sees: I'll prewarm them (render the crew and NPC
  looks under the loading screen; D's CharacterWarm has the API). If M = 0, nothing to do.
### (-5) Relayed from ENV B: DB Tense ×3 on trunk r256 (3312326b: cap 1 Longshot + my Longshot timing + the revive fixes) = 1/3
- Setup: headless auto_loud ×1.0, no doctor bag.
  - s3 PASS at 873 s with 1 player down. s1 custody at 583 s after 3 downs. s2 custody at 664 s after 3 downs.
  - Revives land (5 and 3). Per run: Longshots 2-3, Bulwarks 11-21, Stingers 4-8. Details at the top of
    docs/status/env_b.md.
- Tense batches since the revive fix: 1/3, 2/3, 1/3, 1/3. The pilot runs out of downs over the ~10 min loud phase.
- B's remaining data levers: Tense Bulwark cap 3 -> 2, or Stinger 1 -> 0 (B's files; your call).
- **Update (08:20), from ENV P:** env/p-play 0d0a1ab0 fixes a shared crew CapsuleShape3D. Any crew member crouching
  (bots crouch in cover) shrank everyone's capsule, so the others sank 0.30 m and a 0.15 m kerb became a 0.45 m wall:
  stuck under fire. That likely fed these "3 downs" losses. **Re-run DB Tense ×3 with P's fix merged before touching
  any data lever.**
- **A's recommendation:**
  0. Merge P's 0d0a1ab0, then re-run DB Tense ×3.
  1. Then run the doctor-bag cell (`--po5-doctor-bag`, harness only). A PD2 player brings a doctor bag to a 10 min
     loud job, and it resets downs; the losses are all "3 downs".
  2. If Tense still sits at about 1/3 with the bag, take the Bulwark cap 3 -> 2. That is the PD2-plausible lever for
     Hard (from memory, not verified: PD2's lower difficulties allow about 2 shields alive at once). Keep the Stinger at
     1: one taser is PD2 Hard's rhythm.
  3. Hazardous+ stays a harness limit, per the PO.
### (-4) Headless check of GPU-17: no code regression between GPU-15's tree and trunk e9c8744f (07:40 UTC)
- Setup: OF Cataclysm 1037 auto_loud, 240 s, HITCH_MS=50, headless on this box, one run after another.
  - Trees: ffc264d4 (GPU-15's A side), trunk e9c8744f (GPU-17's tree) ×2, and env/a-core HEAD 89a831f1c (from the
    main checkout and from a clean worktree), plus single-file reverts on HEAD.

| tree | TEL phys avg | TEL proc avg | heist frames in 240 s | wall |
|---|---|---|---|---|
| ffc264d4 | 56.3 ms | 15.2 ms | n/a (old summary only prints at heist end) | 259 s |
| e9c8744f | 55.0 / 56.8 ms | 15.0 / 13.1 ms | n/a | 259 / 247 s |
| HEAD 89a831f1c | 33.5 / 31.8 / 31.0 ms | 11.7 / 11.6 / 13.3 ms | 18,681 / 20,864 / 20,376 | 247-255 s |
| HEAD, old IK (anim_layers @ffc264d4) | 31.8 ms | 11.4 ms | 19,577 | 246 s |
| HEAD, old OF mission only | 53.0 / 59.8 / 56.0 ms | 12.0-15.1 ms | 18,123 / 15,909 | 246-247 s |

- **ffc264d4 = e9c8744f** within noise. The round-255 merges (B's label clamp, D's uncalled CharacterWarm, P's tests)
  cost nothing measurable. **The GPU-15 -> GPU-17 gap is not in the code.** GPU-17b, your control re-run, should show
  the same.
- **My r256 vault-marker change is the one code effect, in the good direction.** Reverting only
  ostrander_federal_mission.gd brings TEL phys back to ~55 ms.
  - The old mission marked [bond_safe] and the 9 vault-wall boxes from the start: ~10 more live markers.
  - Headless frame rate: ~70 fps with those markers, ~80 fps without, about 1.8 ms per frame. This is the
    HUD/marker path, not navigation: TIME_NAVIGATION_PROCESS stays at 0.0-0.1 ms throughout.
  - The pilot's own path queries are small too (FrameProf po5.nav_path about 1.4 ms in the hitch frames).
- **Caveat on the metric: TEL `phys` is not per-step cost.** 31-56 ms against 12-14 ms frames means it covers more
  than one step's work. Compare trees by frame rate (heist frames / 240 s) and wall time, not by TEL phys.
- **Not the freed-marker flood.** HEAD with the old IK code is just as fast, and none of the headless runs printed
  the set_target error (0 lines).
- **Ask for GPU-17b / GPU-18:** compare the `HITCHES n of m heist frames` line (m / 240 = fps) next to TEL. When the
  vault opens, r256 marks the in-vault loot again, so expect a slightly lower frame rate after the burn.
### (-3) Relayed from ENV B (they can't reach you): DB Tense with the 1-Longshot cap (B 8e88e851)
- Trunk e9c8744f still reads longshot 2: B's cap missed r255, and so did my f01d11db (Longshot timing).
- trunk r255 + cap (env/b-content 417b4a75), no Longshot timing, no doctor bag: **1/3**.
  - s3 PASS at 805 s with 0 player downs. s1 custody at 570 s after 3 downs. s2 all_custody at 684 s.
- My f9b86af0 + cap: **2/3**, downs 3 / 3 / 1.
- So the Tense fix needs both on trunk: B's cap and my timing. Details are at the top of docs/status/env_b.md
  (c9e3eb56).
### (-2) GPU-17 "CPU hitch regression": no runtime code changed between GPU-15's tree and e9c8744f; headless proof running
- Runtime diff from ffc264d4 + C 595f57fe to trunk e9c8744f (game/, excluding tests, tools and docs):
  - B's objective / assault-event marker label clamp (r252): one clampf per label.
  - D's character_warm.gd: nothing calls it yet.
  - P's changes are test files only.
- The two GPU logs follow the same simulation: the TEL crew positions and enemy counts match to 0.3 m.
- GPU-17 is uniformly slower from t=12 s on, before any loud fight: TEL phys 22.1 / 29.9 / 22.1 ms became 34.5 / 42.3 /
  35.3; proc 5.3 / 5.4 / 4.7 became 29.6 / 11.2 / 11.0.
  - FrameProf's per-script totals in GPU-17's HITCH lines add up to only 5-20 ms of 50-95 ms frames.
  - So the time is outside our scripts: the engine's physics step, or the machine itself (another process, power or
    thermal state, or a shader cache rebuild after the update).
- The 21k freed-marker SCRIPT ERRORs (D's run) are fixed in 1d7aef14 (anim_layers / IK).
  - With the same simulation they would hit both GPU runs alike, so they don't explain a GPU-15 vs GPU-17 gap.
- Running now (headless OF Cataclysm 1037, 240 s, HITCH_MS=50, the same box, one after another): ffc264d4, trunk
  e9c8744f, and env/a-core HEAD. Numbers will follow here.
- Suggestion for the GPU box: re-run GPU-15's tree (ffc264d4 + 595f57fe) once now, on the same machine state, next to
  r256. If it is also slow, the regression is the machine.
- New run_po5.sh env: `HITCH_MS=50`, so the GPU box command takes the same flag.
- Pilot BondSafe stand: _marker_stand() takes the nearest prefab's UsePoint (p._use_stand).
  - The GPU-17 stand (13.2, -4, 20.1) was the navmesh end short of the wall, because the vault was shut.
  - With 6fcbb559 the marker only appears once the vault is open. test_of_bond_safe_usable_from_its_use_point checks
    the UsePoint path and the aim.
- All green on HEAD: test_x4_of_loud 3/3, test_x4_of_stealth 5/5, test_of_coop_loopback 1/1 (test_x4_of_hard: 5 opt-in
  skips).
### (-1) Your GPU-15 / anim / D-148 messages
- **guard_vault loops (P step 5): pushed** in 6fd7e59a (with guard_lobby), with tests. P has been told.
- **Anim error flood (anim_layers.gd:75): fixed** in 1d7aef14. The IK never passes a freed LeftHandIK marker; it fades
  out instead.
  - New test test_v121_layers: it reproduces your exact SCRIPT ERROR without the fix and passes with it.
  - Also green: d132_anim_lod 9/9, v123_mask_throw 10/10.
- **BondSafe aim: not a map bug; nothing for C.**
  - The pilot's stand (13.2, -4, 20.1) is outside the vault's west wall. The [bond_safe] marker sent it there before
    the vault opened.
  - That marker is now hidden until the vault is reachable (6fcbb559, item (0) below).
  - New test test_of_bond_safe_usable_from_its_use_point: once the vault is open, the UsePoint is on the navmesh from
    the vault door and the aim from it resolves to the safe. From the old stand it does not. test_of_mission_flow
    10/10.
- **OF Cataclysm budget:** my runs use 1800 s (>= 420 s).
- **test_x4_of_loud 3/3** with the vault-marker change. test_x4_of_hard and test_of_coop_loopback are still running.
- **RT systems audit (D-148):** below, under its own heading. I own no docs/process file, so it lives here.
### Rolling Thunder: ENV A systems audit (D-148, paper; no RT code until the OF done check)
Checked rolling_thunder.md (trunk) against env/a-core game/systems/**. No RT mission or map exists yet.

**1. Convoy vehicles on a route (A5-02 / QC-82; §Convoy, §Budgets "≤ 8 movers"): L.**
- Exists:
  - AssaultTurretVan (director/events/assault_turret_van.gd): a straight-line ease-out drive-in on an AnimatableBody3D,
    with doors and an `on_dismount` callback.
  - AssaultEventEntity: a replicated entity (stage diffs, cues). AssaultHeli: a flight.
  - Transforms replicate (heist_net_sync `_send_xforms`, NetEntityCodec), but clients snap: no interpolation.
- New:
  - A Path3D follower that brakes over the last 12 m and emits `vehicle_stopped`.
  - Client interpolation, and seats or occupants.
  - Nav for a stopped vehicle: maps use pre-baked navmesh, and NavigationObstacle3D only carves at bake time.
- Deps: C (Path3Ds, the 4 ConvoyLayout marker sets, vehicle props with Seat/Body nodes).

**2. Ram / mixer: S on top of 1.**
- The ram is a convoy_vehicle on its own path with a scripted impact that raises `alarm_raised(&"ambush")`.
- Crash layouts are pre-authored markers (doc), so no vehicle physics or damage model is needed. Explosion.apply exists.
- Deps: C (mixer prop, crash markers), B (`cue.mixer_ram`).

**3. Stopping and opening the trucks (A5-01 / QC-80/81/84; §Truck targets): M.**
- Exists:
  - Safe has methods drill / saw / c4 / lockpick / code / keycard, `charges_required` (A5-03), the C4 fuse and blast,
    `saw_cut` + G.SAW_TARGET, `saw_duration_s`, `open_by_device`, and contents on LootAnchor (PO6-05).
  - Door and Padlock reuse Safe's charge helpers. DrillPoint SAW and BurnPoint (thermite) exist.
- New:
  - An `armored_truck`: a Safe subclass with `lockdown()` (saw ×1.5), the truck's own hand-saw time, a roof-hatch
    binding, LOCKPICK cab doors, and Body/DoorL/DoorR/CabDoor/RoofHatch visual nodes.
  - QC-81: BurnPoint gets a `target` (calls `open_by_device`) and a no-fire-volume mode. It has neither today.
  - C4 as a pickup: no generic `item_pickup` exists (keycard_pickup / gear_pickup hard-code their items), and no
    `item.c4` pre-plan drop is registered.
- Deps: C/D (truck mesh), B (`asset.c4_drop`, HUD item count, strings).

**4. Police escort cars and spawns (QC-83b/c, QC-89; §Police spawns, §Specials): M.**
- Exists:
  - AssaultDirector: `valid_spawn_points` (POLICE_SPAWN + ENTRY, skips `breach_only`), LOS and crew-distance rules,
    path-cost choice, `spawn_enemy`, `police_delay_s`.
  - RappelLinks (QC-41 one-way links, police-only islands): covers QC-89's rappel part.
  - Turret-van squad dismount. AnimDriver.play_vehicle_exit exists but has no caller.
- New:
  - A per-unit spawn-point filter (`wrecker_ok`).
  - `police_budget()` subtracts cartel only; convoy units must count too (QC-83c).
  - Seated-occupant spawn.
- Deps: C (spawn / TacticalPoint placement, the P_SKY island), D (`vehicle_exit_l/_r` clips).

**5. Stealth-start ambush (QC-83a/d; §Modes): M.**
- Exists: StealthDirector.raise_alarm(reason, id); HeistMission `_on_alarm`, `schedule_at`, `spawn_guards`,
  `start_timer`, `say`; GuardBrain `walk_to_post`.
  - OF's `armored_car_early` is only 2 Vaultline guards walking to the gate, with no vehicle.
- New:
  - A public HeistMission.raise_alarm(&"ambush") (S).
  - A seated/vehicle state on NPCs: seated pose, hitboxes by vehicle hardness (armoured cab no / soft car through
    glass), and a timed dismount into COMBAT (M).
  - A convoy unit that spots a masked crew member during the 8 s window raises "ambush", not a pager (S).
- Deps: D (`sit_vehicle` and exit clips), B (VO).

**6. Loot from vehicles (§Loot path): S.**
- LootSpawn, the Safe content stow, LootBag throw, SecureZone, the `bag_only` escape, BagLift, HEAVY gold,
  HeistMission.spawn_loot / require_loot.
- The secure zone is static at the escape (doc), so no moving zone is needed.
- Check: the truck's rear-step UsePoint must sit on the per-layout navmesh (depends on 1).

**7. Escape (§Escape): S, polish.**
- EscapeZone: van/heli, `arrival_delay_s`, `bag_only`, activate_escape(tag).
- Arrival is a pop-in today. A drive-in or fly-in could reuse 1 or the AssaultHeli flight.

**Holdouts and level change:** no new system. The director already picks spawns nearest the crew by path cost, so the
fight follows the crew between H1 and H4. The stopped convoy as cover depends on 1's nav answer.

**QC-88 (open-street civilians): M.**
- Today, `civilians_leave` returns 0 once loud.
- New: loud flee to `civ_flee` exits, then despawn; exterior mobile-phone calls via a REASON_PHONE call point and the
  existing `phone_call` clip.

**Proposed A order of work**
1. QC-81 BurnPoint target and no-volume mode (S).
2. HeistMission.raise_alarm, convoy units in police_budget, and the wrecker_ok filter (S).
3. A5-01 armored_truck (M).
4. Generic item_pickup + the c4 pre-plan drop (S-M).
5. QC-83 seated occupants and dismount (M).
6. A5-02 convoy_vehicle with interpolation and the mixer ram (L).
7. QC-88 (M).
8. rolling_thunder_mission.gd after C's G1 (M).

**Questions for the lead / C**
- (a) Nav for stopped vehicles: should C bake one navmesh region set per layout (A switches them), or should A rebake at
  runtime?
- (b) Do seated convoy units count against the enemy cap, or only once they dismount?
- (c) For G1, is "seated = not hittable until dismount" acceptable?
- (d) Are client interpolation and the escape drive-in in A5-02's scope, or polish?
- (e) Who authors the vehicle props with Seat / Body / Door / RoofHatch / LootAnchor nodes: C or D?

### RT design notes: A5-01 / A5-02 / A5-03 (paper; no code on env/a-core until the OF done check)
Inputs: rolling_thunder.md §Convoy and §Truck targets, D-149 (pre-baked nav regions swapped per layout; ≤ 8 movers
that end static; the escape van pops in), and the systems audit below.

**A5-01 `armored_truck` (QC-80, QC-81, lockdown):** `game/systems/prefabs/armored_truck/`, `class_name ArmoredTruck
extends Safe`.
- **Reuse Safe:** `methods` (saw, c4, plus a thermite hatch), `charges_required` (default 4), `open_by_device`,
  contents on `LootAnchor`, `G.SAW_TARGET`, `saw_cut`.
- **New exports:** `hand_saw_s` (60 cash / 90 bullion; overrides InteractionTweak.hand_saw_safe_s[size]),
  `lockdown_saw_mult` (1.5), `hatch_path` (NodePath to a BurnPoint, bullion only), `cab_door_path` (a Door LOCKPICK
  with `small_loot` behind it).
- **`lockdown()`:** server; the saw duration (placed and hand) ×lockdown_saw_mult on top of the current progress
  (sawn seconds kept). C4 and thermite are unchanged. Replicated with `lk` (NetEntityCodec props). Mercer's line is the
  mission's.
- **Visual nodes:** `Body` (cover collider: hard), `DoorL` / `DoorR` (swing on open, the PO-6 swing helper), `CabDoor`,
  `RoofHatch`.
  - Collision is a static box on `world_static`. It joins the pre-baked layout region (D-149.1) rather than carving.
- **QC-81 BurnPoint:** add `@export var target: NodePath` (on burn done -> `target.open_by_device()`) and
  `fire_volume_size == Vector3.ZERO` = no fire volume. Small, independent: it can ship first.
- **Tests:**
  - each method opens the doors and enables the cargo LootSpawn;
  - lockdown mid-saw stretches the remaining time ×1.5;
  - the hatch thermite opens the bullion truck and leaves no fire volume;
  - the cab door is a lockpick and gives the small loot;
  - a client mirror (doors, lk).

**A5-02 `convoy_vehicle` (QC-82):** `game/systems/prefabs/convoy_vehicle/`, `class_name ConvoyVehicle extends
GameplayPrefab`, an AnimatableBody3D root `Body`.
- **API:** `drive(path: Path3D, stop_marker: Node3D, speed_mps := 10.0, brake_m := 12.0)`, which follows the curve
  (PathFollow3D math, no node) and eases into the marker transform over the last `brake_m`. `place_static(marker)`.
  `signal vehicle_stopped(id)`. `state` DRIVING / STOPPED / WRECK.
- **Mission flow:** RollingThunderMission picks the route and stop (clean / crash), calls `drive()` on each vehicle with
  its gap, and on the last `vehicle_stopped` enables the matching pre-baked nav region set and its TacticalPoints
  (TacticalPoint.enabled, D-149 QC-RT1; in r258).
- **Crash stop:** the mixer's path ends at the T-bone marker. Its impact is a scripted event (cue + `alarm_raised(&"ambush")`
  + a soft knockback of the lead car to its crash marker). No vehicle physics.
- **Net:** the host drives. Clients get `trip_t` + path id + stop id through the NetEntityCodec generic props (the BagLift
  pattern) and evaluate the same curve locally, so motion is smooth with no per-frame transforms. Snap on STOPPED.
- **Seats:** `Seat0..n` markers. Occupants are NpcBase in a new SEATED mode (NpcMotor off, attached to the seat, the
  `sit_vehicle` clip, hitboxes by `armoured_cab` hard / soft). `dismount(delay)` -> an exit marker
  (`play_vehicle_exit`, which already exists) -> COMBAT. Spawned through AssaultDirector.spawn_enemy with a
  `convoy_unit` meta, so they count in police_budget() (QC-83c).
- **Tests:**
  - the curve end lands exactly on the marker;
  - the brake profile is monotonic;
  - a client mirror matches the host within 5 cm at three points;
  - vehicle_stopped fires once;
  - a seated unit is unhittable in an armoured cab and dismounts on the alarm;
  - the director budget counts seated units.

**A5-03 C4 item (QC-84, S9.5):** charges already work on Safe / Door / Padlock (`charges_required`,
`consume_charges_for`, a 5 s fuse, the L3.6 blast).
- **New:** a generic `item_pickup` prefab (`item_id`, `count`, `max_carry`; the keycard_pickup / gear_pickup pattern
  generalised; the old two stay as is).
- **New:** an `item.c4` count on CrewInventory, with a HUD count line (B's widget asks for `item_count(item.c4)`).
- **New:** a pre-plan drop kind `item` (PreplanAssets.register_drop + `asset.c4_drop`, B's asset data).
- **Placement:** stays on the target's interaction (place_c4 when the crew carries ≥ 1; each placement consumes one;
  arms at `charges_required`). This is already the Safe path, so ArmoredTruck inherits it.
- **Tests:**
  - a pickup adds charges up to max_carry;
  - 4 charges on a truck arm the fuse and open it;
  - fewer leave it at n/4 (replicated count);
  - a pre-plan drop spawns a pickup with the right count.

**C's RT asks, queued for after OF (paper):**
- **civilians_leave at the alarm (D-149.7, QC-RT7):** HeistMission.civilians_leave(exit_tag) today returns 0 once
  loud. RT needs: on `alarm_raised`, street civilians with a `civ_flee` route run to their sidewalk exit and despawn
  there; the rest take the existing cower / flee.
  - Plan: a loud branch in civilians_leave (walk to the nearest exit tagged `exit_tag`, despawn on arrival), plus
    sidewalk call points (CivilianTargets.add_call_point, REASON_PHONE) for the 911 calls.
  - Test: 3 civilians at the alarm reach two exits and despawn; a call point brings a call.
- **Layout cover enable at the stop:** on the last `vehicle_stopped`, enable the TacticalPoints (COVER /
  SHIELD_ANCHOR / ENTRY) under the active ConvoyLayout (`Gameplay/Convoy/<route>/<clean|crash>`) with
  TacticalPoint.enabled (QC-RT1, in r258), and disable the other three layouts' points. The same call swaps in the
  layout's nav region (D-149.1).
  - Test: after the stop, only the active layout's points are in their groups.
- **Tannery gates on mixer_move:** the gates under the Tannery underpass open (Door.unlock + open, or a nav region
  swap) when the mixer starts its move (`mixer_move`, stop + 3 s on a clean stop, the impact on a crash), so the
  trench has its second exit.
  - Plan: the mission listens to ConvoyVehicle `drive_started` on the mixer and opens the doors tagged
    `tannery_gate`.
  - Test: the gates are shut before the move and open, with their nav link enabled, after it.

**Proposed order once OF is done:**
1. QC-81 BurnPoint.target.
2. A5-03 item_pickup + count.
3. A5-01 ArmoredTruck.
4. A5-02 ConvoyVehicle (static place first, drive second, seats third).
5. HeistMission.raise_alarm + convoy units in police_budget.
6. The RT mission after C's G1.

### (0) OF-done blocker "bond_safe / deposit_boxes not reachable" (Cataclysm loud): fixed in the mission, 6fcbb559
- Cause: both side objectives were ACTIVE from the start, with markers inside the sealed vault.
  - BondSafe (14.7, -4, 20.5) and the vault-wall boxes (VaultBoxN01 = (15.0, -3.0, 13.3)) sit behind the vault's west
    and north walls.
  - The pilot walked to them before the burn-through: the nav path ends 2.5 m short, and its LOS ray hit wall BZ0140.
- Same run, after the burn: the [vault_loot] marker was the cash itself, inside the locked cash cage
  (CashCageGate BARRED; ways in: keypad with the vault code, or C's padlock).
  - The pilot pushed into the cage mesh for 24 s, then skipped the cash for the rest of the run: no bags, budget FAIL.
- Fix (gameplay, PD2-style waypoints):
  - [bond_safe] starts HIDDEN and appears with the vault (open_vault or burn_through).
  - [deposit_boxes] marks only the SD hall's boxes until then (new objective data `marker_skip_prefixes`, honoured by
    LocalHudModel).
  - [vault_loot] marks the cage padlock and keypad until CashCageGate opens, then the cash.
- Also fixed: [vault_gate] no longer completes when a guard walks through the locked gate.
  - Door.npc_open opens it while it stays locked; the new guard_vault loops do this. Before the fix that completed the
    objective and broke test_x4_of_stealth.
- Pilot (harness only): it no longer calls the vault hoist at a box wall. It did that for 450 s in the same run.
- Tests: test_of_mission_flow 9/9 (+2 new: vault side loot markers and the cage handoff; a guard passing the gate);
  test_of_mission 19/19, test_hud_marker_lookups, test_x4_of_stealth 5/5, test_of_a6_hub_loops 3/3,
  test_of_mission_loud 6/6, test_x4_nd_stealth.
  - Still running at push time: test_x4_of_loud, test_x4_of_hard, test_of_coop_loopback, then a headless OF Cataclysm 1037 auto_loud run. Results go in the next status update.
### (1) HITCH lines (your GPU-13 ask), b922571a
- Each HITCH line now carries `shot=1` on screenshot frames, plus `pipelines=[mesh,surface,draw,spec,canvas]` (pipeline
  compilations that frame, from RenderingServer) and `vram=..MB`.
- `HITCHES n of m heist frames over N ms (k of them screenshot frames), worst x ms, without a shot y ms` prints at heist
  end and on budget exit.
- Headless OF Cataclysm 1037: t≈127-131 shows 80-97 ms frames, with police_brain at 29 ms over 65 calls.
  - police_brain now has sub-keys (pick_target / choose_position / move).
  - The GPU t≈129.6 / 176 frames need your next GPU run with these lines: a non-zero `pipelines` count there means a
    shader compile, which is D's prewarm.
### (2) P's ghost line: guard_vault and guard_lobby hub_loops pushed (6fd7e59a).

### (earlier, 05:40 UTC)
### (1) Navmesh polygon cap: done, ffc264d4
- New NavPath.query: NavigationPathQueryParameters3D with path_search_max_polygons = 0 (no cap). Used by the assault
  director, civilian_brain, civilian_targets, crew_ai_brain and the PO-5 pilot. NpcMotor's NavigationAgent3Ds get the
  same (NavPath.configure_agent).
- test_x4_of_loud: "not expect to not find the most reachable polygons" 357 -> **0** (they came from crew_ai_brain's
  paths after the burn-through).
- New test test_nav_path_polygon_cap: OF P1 -> CoverMisc7 reaches the terrace; agent cap lifted.
  - C's pair also routes with the old call here, so the x4 count is the evidence.
- Green: l6 15, a3_05 12, l1_assault_director 7, po6_17 15, x5_ 16, d122, a3_10 ladder, l5_ 8, s5_ 28, po5_ 55,
  integration p1 10 / p3_loud 10.
### (2) DB Tense Longshots
- f01d11db: Routine / Tense laser aim lock 2.5 / 2.0 s and re-aim 4.5 / 3.5 s; Hazardous+ unchanged (1.2 / 2.5); per-hit
  damage kept.
- PD2 cite, charactertweakdata presets.weapon.sniper: aim_delay {0, 0.1}, use_laser, FALLOFF recoil {2,4} / {3,4} / {3,5}
  s at 7 / 35 / 100 m, focus_delay 7. The values come from a decompile summary, not verbatim lines.
  - Tense uses PD2 Hard's mid-range 3.5 s, with a telegraph longer than PD2's.
- New test (Tense: >= 1.9 s lock, >= 3.4 s between shots); l4_7 6/6.
- **Max 1 alive on Tense** is B's file (content/data/difficulty/tense.tres longshot 2 -> 1). I asked B; Routine is
  already 1. Then B re-runs DB Tense x3.
- Harness option for that re-run: --po5-doctor-bag (opt-in, 14f85b5a). The pilot carries a doctor bag and uses it at
  2 downs.
  - Verified on DB Tense s1: deployed at 2 downs and used, downs reset.
  - That run still ended in custody after 5 downs in total.
### (3) GPU prewarm: waiting for GPU-12's HITCH lines.

### (05:00 UTC)
### OF loud hitches (your GPU-8.5 item); env/a-core 8e5412e9
- CPU hitches found headless (OF Cataclysm seed 1037) and fixed:
  - At OF start, the HUD's objective markers took 477 ms in one frame. HeistRuntime.find_by_tag walked the 18k-node map
    with Array.pop_front (O(n) per node), once per tag. Now the walk is linear and the HUD resolves all tags in one walk
    (find_by_tags): 0.6 ms.
  - The alarm frame cost 172 ms in OF's _go_loud: about 8 find_tagged walks. A tag scope around the phase change now
    shares one index: 36 ms.
- Still under investigation: the 200-300 ms frames at t=0.1 / t=4.3 headless (anim_driver / npc_motor first ticks; the
  box is loaded, so the size is unclear). The GPU-side cost (pipeline compiles on first draw of each police character /
  material) can only be measured on your GPU.
- **GPU-box command** (cmd.exe from the repo root, G=godot\Godot_v4.7.2-stable_win64_console.exe, trunk + env/a-core
  >= 8e5412e9). Run `mkdir gpu\renders\a\of_hitch` first:
  `%G% --path game --resolution 1920x1080 res://tests/a/e2e/po5_runner.tscn -- --po5-flow=auto_loud --po5-out=%CD%\gpu\renders\a\of_hitch --po5-budget=240 --po5-heist="Ostrander Federal" --po5-difficulty=Cataclysm --po5-seed=1037 --po5-crew-dmg=0 --po5-hitch-ms=50 > gpu\renders\a\of_hitch.log 2>&1`
  - `--po5-crew-dmg=0` keeps the solo pilot alive, so the loud phase actually runs (Cataclysm downs it in about 20 s).
  - Every frame over 50 ms prints `HITCH frame=.. process=.. physics=.. draws=.. objects=.. spawned=[ids] top: <FrameProf>`.
    A HITCH with small process / physics and big frame is GPU or render-side; `spawned=` names the units spawned in it.
  - At the heist end: `HITCHES n of m heist frames over 50 ms, worst x ms`.
  - Commit the log. Next step, with D (character materials): prewarm what the HITCH lines name (a character render-warm at
    load if spawned= lines line up; spread spawns otherwise).
### DB vs GH Tense damage intake (your ask); headless auto_loud x1.0, solo + 3 bots, on 30a0d429

| run | result | standing loud | damage | dmg/s | Longshot dmg (share) | top source |
|---|---|---|---|---|---|---|
| GH 4501 | WIN | 263 s | 449 | 1.71 | 0 | tac_light 243 |
| GH 4502 | WIN | 239 s | 420 | 1.76 | 90 (21 %) | tac_light 192 |
| GH 4503 | custody | 326 s | 777 | 2.38 | 0 | bulwark 355 (<10 m) |
| DB 1 | custody | 466 s | 973 | 2.09 | 360 (37 %) | longshot 360, tac_light 291 |
| DB 2 | WIN | 899 s | 962 | 1.07 | 450 (47 %) | longshot 450, tac_light 272 |
| DB 3 | custody | 378 s | 728 | 1.92 | 225 (31 %) | tac_light 291, longshot 225 |

- Per second, DB is NOT harsher than GH (1.1-2.1 vs 1.7-2.4 dmg/s; 1.3-1.8 enemies within 20 m vs 1.8-2.7).
- DB is longer. The pilot stands loud 1.5-3.5x as long, so the same per-second intake adds up to 3 downs.
- On DB's open yard, 31-47 % of the damage comes from Longshots at 30 m+; GH has almost none. Per hit they are within
  PD2 Hard (the earlier table), so I would not cut their damage.
- Proposal, harness first: a PD2 player survives a long loud heist with a doctor bag. Our pilot never carries or uses one,
  though the game has doctor bags (heal + reset downs). Let the pilot bring a doctor bag and use it at 2 downs used,
  plus first aid if loadout-legal. I expect that to bring DB to median <= 2 downs.
- Game option if you want DB itself gentler on Tense: cap Longshots to 1 alive on Routine / Tense (DifficultyDef
  special_limits; now about 3-4 per run).
- Your call on both. I do the harness one unless you say no.
- Note: test_of_coop_loopback failed 2 of 5 runs, only inside the full test_of_ batch under load; it passes alone.
  Timing-sensitive two-process test.

### (03:40 UTC)
- Merged r252 (390c6d92). Green: d145_ 15, l6 15, a3_05 12, s8_1_cameras 10, po5_pilot_corner 3, a3_09_bag_lift 8,
  of_a6_hub_loops 3, l2_ 55; earlier x4_of_ 13 (5 skip), of_coop_loopback 1/1.
- Hold-fire set to your number: the pilot fights from the floor on Haz+ only with <= 3 enemies within 20 m.
- P's camera find fixed (3dbea1c4): a prefab-disabled SecurityCamera is no observer (can_observe checks prefab_enabled)
  + test. The X4 escape also brings input-less humans into the zone; the co-op test passed only while that player ended
  in custody.
- B's DB Tense on 0f317b90: the revive bug is gone. 1/3 WIN; the player is revived 3-4 times per run.
  - The 2 losses are custody after the player's 3 downs (around 450-510 s), not bleed-outs.
  - So DB Tense now fails on incoming damage / the pilot's exposure, not on revive logic. Your call: tuning, or accept,
    since the auto_loud pilot charges objectives.
- **Hit grace on Haz+** (GH, auto_loud headless x1.0, solo + 3 bots; grace on = a local edit giving all difficulties 0.45 s
  / bots 0.35 s; pilot holds fire vs crowds). Custody time in s, or WIN; downs player/bot1/bot2/bot3:

  | difficulty | seed | grace ON | grace OFF |
  |---|---|---|---|
  | Hazardous | 4501 | 477 (2/2/1/3) | 822 (1/1/2/2) |
  | Hazardous | 4502 | 1026 (1/1/1/1) | 917 (1/1/1/1) |
  | Brutal | 4501 | **WIN** (1/1/2/2) | 205 (1/3/2/1) |
  | Brutal | 4502 | 145 (1/1/1/2) | 1135 (3/2/1/3) |
  | Lethal | 4501 | 188 (1/2/2/1) | 182 (1/2/1/1) |
  | Lethal | 4502 | 123 (2/2/1/2) | 474 (3/2/1/1) |
  | Cataclysm | 4501 | 1064 (1/1/1/2) | 818 (1/1/1/3) |
  | Cataclysm | 4502 | 1010 (1/1/1/3) | 1000 (1/1/1/2) |

  - Reading: no measurable effect. ON wins 1/8, OFF 0/8. Per pair ON lasts longer 4x, shorter 3x, equal 1x; the
    seed-to-seed spread swamps it.
  - The Lethal / Cataclysm 4502 pairs ran on the newer bot-revive code (0f317b90); the other pairs on e640362d. Each
    pair is like for like.
  - Most Haz+ losses are crew wipes: bots end in custody first, then the cuffed pilot (nobody left to uncuff).
  - Recommendation: extending the grace to Haz+ is a pure PD2-fidelity call (L2.2: PD2 has it on every difficulty);
    the data says it does not change outcomes here. I would extend it for fidelity. Say the word and I will set
    hit_grace_s_by_difficulty to 0.45 everywhere (bots 0.35) with the test flipped.

- (earlier, 02:30)
- DB Tense no-revive, root cause found and fixed (0f317b90, GAME, bots). Reproduced on DB Tense s1 with the new log;
  revives started but were cancelled half done, two ways:
  1. The nearest-AI assignment was recomputed every tick: as bots moved, the patient flipped to another bot, and the
     reviver dropped to FOLLOW and cancelled at 3.1 / 6 s. Now a bot holding a revive keeps it; an order still wins.
  2. A jostled reviver (0.9-3.2 m/s) released interact (the settle-speed check) or walked back past 1.2 m. Now it does
     neither once holding; InteractionSystem's 0.5 m move cancel still applies.
  New test test_l6_1_revive_in_progress_is_kept. Green: l6 15/15, a3_05 orders 12, d134 revive_under_fire, give_way,
  p1_sandbox, l2_8, l4_4.
  Queued after the grace runs: DB Tense s1 / s2 / s3 on 0f317b90.
- (earlier, 02:15)
- Thanks for the decisions.
- (1) Hold-fire with 4+ enemies near: df866e99 already ships the pilot holding fire on Haz+ unless <= 2 enemies are
  within 20 m. I set it to your number (fight back only with <= 3 near) right after the grace runs finish, so they all
  run on one pilot.
- (2) B's DB Tense no-revive:
  - r251 lacks e640362d. Bots in REVIVE mode stalled about 2 m out (body / prop) and never pressed interact; GH Tense
    4501 went FAIL -> PASS with the fix.
  - Already true: a downed human comes first in the revive order (CrewAiBrain._pick_revive_target); a carried bag does
    not block a revive (allowed_with_bag); only tased / downed bots are not free.
  - Next: DB Tense s1 + s3 on my head with the "bots while down" log, to confirm, and the StairST landing reach. Results here.
- Hit grace on Haz+: the first pass (GH 4501, grace on / off) was confounded: the pilot drew fire from the floor, custody
  within seconds of its first down. Re-running with the hold-fire pilot, 2 seeds x 4 difficulties x on / off (16 runs).
  So far Haz 4501 FAIL / FAIL, Brutal 4501 on PASS. Table here when done.

## 2026-10-21 00:05 UTC: GPU-box command lines for the LEAD (A cannot send_message the lead: "trusted device")
Run from the repo root in cmd.exe with `G=godot\Godot_v4.7.2-stable_win64_console.exe`, on trunk >= r251 plus env/a-core
06185eee. Make each out dir first: `mkdir gpu\renders\a\<name>`. The verdict is the `RESULT` line in the log.
1. **OF stealth, real menus**, Routine, seed 18. It saves PNG steps. The flow uses the X4 stealth shortcuts, so it proves
   the menus and the objective chain, not stealth.
   `%G% --path game --resolution 1280x720 res://tests/a/e2e/po5_runner.tscn -- --po5-flow=of_stealth --po5-out=%CD%\gpu\renders\a\of_stealth_18 --po5-budget=1800 --po5-heist="Ostrander Federal" --po5-difficulty=Routine --po5-seed=18 > gpu\renders\a\of_stealth_18.log 2>&1`
2. **OF loud, real menus**, Routine, seed 5, crew damage x0.25 (D-133 gate):
   `%G% --path game --resolution 1280x720 res://tests/a/e2e/po5_runner.tscn -- --po5-flow=of_loud --po5-out=%CD%\gpu\renders\a\of_loud_5 --po5-budget=1800 --po5-heist="Ostrander Federal" --po5-difficulty=Routine --po5-seed=5 --po5-crew-dmg=0.25 > gpu\renders\a\of_loud_5.log 2>&1`
3. **OF real bots, Hazardous, seed 5**: a feel clip of drill parts -> burn-through -> rope ladder (headless reached the
   ladder at about 600 s; x1.0, so expect a loss). The .avi is large MJPEG: commit the log + PNGs unless the clip is wanted.
   `%G% --path game --resolution 1280x720 --fixed-fps 30 --write-movie %CD%\gpu\renders\a\of_haz_5\clip.avi res://tests/a/e2e/po5_runner.tscn -- --po5-flow=auto_loud --po5-out=%CD%\gpu\renders\a\of_haz_5 --po5-budget=900 --po5-heist="Ostrander Federal" --po5-difficulty=Hazardous --po5-seed=5 > gpu\renders\a\of_haz_5.log 2>&1`
### Open for the LEAD
- OF real-bot hard runs (headless, x1.0): Haz 0/3, Cata 0/2.
  - On Cata the pilot was downed at t~19 and in custody ~1 s later.
  - Cause: the pilot fights from the floor on Haz+, so L2.5 lets ~12 police drain the 100 pool.
  - Offer: the pilot holds fire with 4+ enemies near (cuffed -> bot uncuffs); harness only.
- Hit grace on Haz+: GH 4501, grace on / off x Haz / Brutal / Lethal / Cata, running serially; results to follow here.

## 2026-10-20 23:50 UTC: OF co-op parity, hub loops, DB / OF pilot fixes, D-145 Tense vs PD2 Hard (env/a-core 441b6870)
### Done (pushed)
- OF hub loops for rover_hall (BCMid) and rover_gallery (UCMid, loop (c) SA up -> XC -> PR -> XL -> SB down) (b7052ebd).
- OF co-op parity test, host + client process, every milestone (dbe53781). It caught a client bug: BagLift cars did not move on
  clients; they now mirror landing / destination / trip_t (9a0bf994).
- D-145 Tense vs PD2 Hard, LEAD go on (a)-(e) (4a6780f4):
  - PD2 hit grace: 0.45 s, bots 0.35 s, Routine / Tense only.
  - TAC Light / Stinger damage 8 at Tense; TAC Light 80 hp, Patrol / Security Officer 40 hp.
  - A tase downs after 10 s.
  - Bots regen 25 %/s after 3 s.
  - P measured GH Tense 2/3 WIN on it, median 1 down.
- Bots revive over an obstacle: they revive from up to 2.3 m once stalled for 1 s (e640362d; P's GH Tense 4501).
- PO-5 pilot / flow (harness):
  - Pilot fights from the floor only from Hazardous (86fada32).
  - Doorway crossing side and hysteresis (98e55725; B's DB cage and gatehouse stalls). DB Routine seed 2 PASS.
  - No false "not reachable" when the objective ended mid-walk (7b91a005).
  - Fetches the tool bags a DrillPoint is owed (bcafd612; OF drill parts).
  - Climbs ladders with P's free climb (8aea4ae3).
  - Cataclysm / Lethal opened in memory for runs (2daa35d6, 441b6870).
  - Logs bot revive state while the pilot is down (a039c380).
- Trunk r249 merged (6f9c90a1); r250 merged in 4a6780f4.
### In progress
- OF real-bot hard runs (headless auto_loud, x1.0, solo + 3 bots):
  - Haz 5 FAIL three times: drill parts (fixed), the hole ladder (fixed), then custody at 603 s.
  - Haz 1 FAIL: custody at 287 s.
  - Cata 5/6 queued after GH Tense 4501 (revive fix).
- LEAD ask after these: the hit grace on Hazardous+, one headless run each, for the extension decision.
### Needs
- LEAD: the L2.2 row and D-145 text for the hit grace (values above).
- LEAD: this session cannot message the lead session ("trusted device"); reports go through P.
### Gotchas
- Never reorder local commits (`git reset`) while a run reads the working tree. Use a worktree (scratchpad wt_d145).
- A queue script waiting on an "END x" log line must use a run name never used before (old lines match).

## 2026-10-20 18:45 UTC: resume (session_015kTjrZsUFn7gLqNVwAXdkh); OF-A6 phase 2, hub loops, D-145 / D-142 (env/a-core fc48df26)
### Done (pushed)
- Resume: env/a-core fast-forwarded, wip/a-of-a6 merged, trunk r245 (e219930b) merged (a75c0f12).
- OF-A6 phase 2: real-menu e2e flows `po5_flow_of_stealth` / `of_loud` (571aafb8, X4StealthFlow.attach / detach / sink).
  Evidence: game/tests/a/e2e/captures/of_a6_realmenu_2026-10-20/. Stealth seeds 18 / 7 / 6 and loud seeds 5 / 1 / 6 all
  RESULT PASS back to the hub.
- OF mission audit vs the doc: no blocking gap; Breach_3/4 ruled (doc kept, C markers).
- QC-67 teller_count hint alias + guard test: every layout spawn activity has a HINT_CLIPS key (fbbe47ed).
- Po5Pilot BagLift per-landing panel stand (8d486d5c; P's OF burn-run hoist FAIL).
- po5 STATS line: downs / regen / loadouts / police composition (2df6063a).
- Opt-in OF hard probe test_x4_of_hard (CNC_OF_HARD=1): loud Hazardous/Cataclysm x2 at crew dmg x0 PASS (no soft lock),
  stealth Cataclysm PASS.
- D-145: default bots carry corsair_ar (09a2a165); look precedence <faction>_duty -> duty -> <faction> -> base (684889cf).
- OF hub-loop patrols (160b8e07): GuardTweak.hub_loops; rover_dock derived (LaneWest / LaneCorner smoke / TanneryBay),
  rover_basement explicit (RC / SD+SS / CP+PL, never VC).
- Door-kind breaches for OF Breach_3/4 (2e8aae3b).
- Turret-van collider-inside-visual guard test (fc48df26).
- D-142 verified green in a scratch merge (reported; merged by the lead in r245).
### In progress
- Serial windowed queue (scratchpad d145/queue2.sh): GH Tense 1001 -> OF r245 of_stealth s3 -> of_loud s1 -> DB Tense
  1001 -> DB Routine 1001 rerun (7000 s budget). Done: GH Routine 1001 PASS (0 downs). DB Routine 1001 ran out of wall
  budget at t=426 under box load (0 player downs).
### Needs
- D: tac_light_<zero|frd|sentinel>_duty looks (the precedence is in; the plain duty look covers until then).
### Gotchas
- Windowed runs one at a time (LEAD): parallel llvmpipe runs plus headless tests blow wall budgets (12 s frames).
- OF is visible in the menus from r245 (B e42c0f3b); older trees need B's heist_list.tres.

## 2026-10-17 11:10 UTC: D-135 queue close: anim lane, npc_oneshot, VFX hitch root cause, pilot doors (env/a-core 06fab719 + this)
### Done since 02:45 (pushed, all on trunk by round 239)
- Pilot (DB-7):
  - 0ea5bfba / 626bfc14: a closed D-073 door on the step to the next path corner is opened first.
  - 3d803379: the through-link radius is 0.8 m (< THROUGH_PAST_M); the closed-door check has its own LINE_DOOR_M 1.0.
- 2b97d701 anim lane (D-115 / D-116):
  - Police cuff hint is `cuff`; melee plays once only.
  - A crew interaction beats every one-shot; a hit while interacting is a flinch only.
  - LoopResume (aim loops resume their phase after a fire/turn).
  - turn_*_45; door_kick_<fam> at breach start; civ panic variants.
  - Loud coverage: MISMATCH 0, NO_CLIP 0, FROZEN 0–2 one-offs (P to require 2 consecutive samples).
- 61b70043:
  - Turn at speed 1, rig on the clip's root rate, the residual eased over blend_s.
  - Replicated `npc_oneshot` cue + `"ah"` NPC key (net.md v1.3).
  - panic_start before the first cower* (it never played: the first flee* used it up).
- b8cdd674 npc_gunner HITCH root cause:
  - Not gunner code. C's VFX pools grew lazily inside the first shots, and every new GPU resource stalls llvmpipe for seconds.
  - Fix: VfxDirector.prewarm() at heist load (C bb6a06f8, from A's patch) + HeistRuntime._prewarm_vfx().
  - FrameProf npc_gunner.{los,fired,fx,hit} sub-scopes; HITCH lines print drawn=.
  - PO-7 frozen flashes: render loop off → frame_drawn_since (A patch); render loop on → C a3172294.
### Evidence
- DB-7 1003 ×0.25 windowed, before (q4) / after (q6, prewarm):
  - worst npc_gunner frame 17.4 s → 17.6 ms; gunner frames > 500 ms: 8 → 0;
  - start → breach 574 → 244 s real.
- The remaining long frames carry ≤ ~20 ms of script time: llvmpipe draw cost plus spawn-time GPU allocations (police waves, node count +1.3k). Not game code; on real GPUs this is minor.
- DB-7 flow in q6: cartel, breach, product, burn started, cartel done (t=120), thermite fetched. Still running at the cutoff, with no full win yet.
### Not closed (carry to the Ostrander sprint, low priority)
- DB-7 full windowed win: the pilot's final approach to a bag sometimes stops at about 4.6 m (crew bunching). Harness-only.
- ND-1 ×1.0 solo run: waived by LEAD (D-134 + the ND-1 test cover it).
- Spawn-time llvmpipe stalls: if ever needed, prewarm NPC skin/material instances. Not a game bug.

## 2026-10-17 02:45 UTC: D-130, R229/R230 fixes, anim clips + split, pilot, crew stack (env/a-core d10c9908)
### Done since 00:45 (pushed)
- df7d3727 / da8d9fc4 round-229 reds:
  - gait holds, mask_on, death_back_b, the s2 DifficultyDef ×2 leak;
  - inspectors counted by tag with C's escort markers.
- 58bf1265 test_zz_shared_resource_drift: the last a/ test fails on any cached tweak/def drift.
- 1b326212 D's 190f40c7 clips (aim_<fam>_<gait>, class reloads, cover peek/low by LOS rays, stagger, DB-4
  sit_chair_armed long guns only), each with fallback.
- c1de5907 refactor: anim_driver 1498 → 1209 lines (AnimLayers, HitClips, HeldVisuals, AmbientHints).
- aab638dc prewarm collects its parallel loads before heist start. P's ND load hang and GN seed-99 have the same
  root; fixed by reasoning.
- 5b7c70aa DB [breach]: crew-only, and walking through the open variant door completes it. GN: the doors under the
  shutters are BARRED with them.
- 67ce6d5f / ea0699dc D-130:
  - PagerSystem.cap_for; the HUD pagers_max bug (it always showed 4) fixed;
  - SecurityCamera.titan_min_difficulty; camera delay {1.6, 2.4};
  - difficulty_add on civilian groups pinned on a synthetic map;
  - side: true on bonus steps only; objective data state_changed.
- 74b18a00 DB CREW_STACK: cover claims ≥ cover_taken_m apart; an unseen leader within 1.5 m → the bot's slot.
- d10c9908 pilot:
  - layer-1 paths, and a locked door blocks a first objective;
  - lull reloads; stuck give-up; no out-of-reach F-holds;
  - DB thermite is a tool.
### In progress
- Windowed DB-7 auto_loud (seed 1003) and the GN seed-99 confirm (needs ESCAPE), 7000 s budgets each.
### Next
- ND-1 gate 2 (attempt 24).
- Pin GN/ND/SL population counts when C's D-130 rows land.
- Check the cover-pose ray classification on GH + DB windowed.
### heist_completion
- GN-8: race + load hang fixed, unconfirmed (seed-99 run in progress).
- DB-4: done.
- DB-7: run in progress.
- ND-1: open.

## 2026-10-17 00:45 UTC: new team resume; GN-8 B3 + race fix, B audit logic, round-229 reds (env/a-core df7d3727)
Session session_01EoHohP5E4RVEPzabfnFk8y (lead session_01HwYKRgCdkLfJCt4ZM6rfTk).
### Done (pushed)
- f9fd76eb trunk merge.
- 4b4fef68 B-DB/B-SL audit logic:
  - DB: the burn finds [product] silently; containers_hint once; [cartel] fails with 0 down; [product] on room entry
    (crew eye ≤ 6 m flat, same floor, clear world ray); Reyes payday on [escape] completed.
  - SL: [secure] seeds drives_secured 0. Test: test_bdb_mission_gaps.
- 291ce51d GN-8 lane:
  - B3 inspectors walk to the centrepiece slot and radio the alarm if it is empty.
  - WarmLoader: the director prewarm never overlaps a main-thread load of the same scenes (seed-99 race).
  - GN gaps: wall studies count for [extras]; the loud hack completes vault_drill and server_door; the server keypad
    completes server_door.
  - Tests: test_gn_inspectors_empty_slot, test_gn8_warm_loader, test_gn8_mission_gaps.
- 10572baf D cast: cartel_gunman g..l, dock_worker_c (dock_worker_c PENDING in test_d115 until D 45894565 lands).
- 585008d0 B3 Halberd escorts: guard_inspection_escort spawns, used when C's markers (c-worlds 2133b0aa) exist.
- df7d3727 round-229 a/ reds, tests only:
  - gait-locked holds and mask_on in test_v119 / test_v120; death_back_b variety.
  - test_s2_detection_meter leaked a ×2 DifficultyDef into test_s3_8_cameras (it now mutates a copy).
- Verified on trunk, nothing to do:
  - item 3 (unknown weapons id) is fixed by B ff0be43c.
  - DB-4 / DB-6 / SL-6 / D-4 rows were already done by the previous A.
  - The x5 GH police flake does not reproduce (3/3 green under load).
  - The knife finding is reach/timing, not damage; no ruling needed.
### Open / in progress
- GN-8 seed-99 crash: race fixed, unconfirmed. Needs a seed-99 run that reaches ESCAPE on a quiet box (the pilot loses
  to custody first).
- Pilot lane (worktree agent-aa105032f09babcd6, WIP 19ec7c45): _has_path on nav layer 1 (D-122), reload, vertical
  Door near-check (ND VaultGate), BronzeDoorsE unstick.
- Anim lane (worktree agent-a3830ca90edfdd278): D's 190f40c7 clips (aim_<fam>_<gait>, class reloads, cover peek/low,
  stagger_<fam>, sit_chair_armed for DB-4 armed seated posts), with fallbacks.
- DB-7 windowed auto_loud, ND-1 gate 2 (attempt 24): next once the box is quiet.
### heist_completion statuses
- DB-4 done (seated clip; sit_chair_armed in the anim lane).
- DB-6 A side done.
- SL-6 done.
- D-4 done.
- GN-8: B3 done (escorts pair with C 2133b0aa); audit gaps done; crash race fixed, unconfirmed.
- x5 GH police flake: not reproducing.
- DB-7 / ND-1 open.

## 2026-10-16 04:00 UTC: PO6 done, D-115 / D-118 / X-3 / X-4 / X-5 closed (env/a-core f450497c)
### Done (pushed; on trunk through c07f7e69, round 223 has 37bf88f9)
- PO6-01..08, 14..20 (+17b) A-side; D-115 DB-2/3/4/8/12/13/16/17, SL-5/9, QC-36 TODO; D-117 mission VO.
- D-118: CrewWeapons gadget_on / gadget_changed (net "gd"), 3P CrewGadgetVisual, shotgun AMMO runtime
  (ShotgunAmmo; per-shot damage preserved), gadget detection behind StealthTweak (0 by default, S4.2).
- D-cast: heist_tag_characters for GH/ND/DB/SL/GN (GN 1:1 from p5_cast v4), looks dealt round-robin per tag and
  replicated (spawn "look"), HandProps on clip, roster activities, HardHatHandLift (D audit R1).
- X-3 per-heist assault events at C markers (test_x3_*); X-4 stealth e2e ND/SL/GN + forced GN curator-keycard
  (test_x4_*; HeistRuntime options["variant_table"] dev hook); escape objective completes before heist_ended.
- X-5: GH doorway back_off latch, push-slot by net_id, nav-radius doorway test, staff return to marks, seated
  aliases stand without a seat.
- B facts: HeistResult.loot_available, safe / cage objective data open_method.
### Open
- test_x5_gh_police_do_not_park_under_the_crew_upstairs fails ~1 in 3 inside the full `police` filter (passes
  alone): order-dependent leak, bisect lane running.
- Backlog: GN loud pilot probe (below, HANDOFF 2026-10-14), ND loud gate attempt 24 (empty box only), co-op
  ghost rounds, escape vehicles, split HeistRuntime.start(), Stinger cap check.

## 2026-10-15 23:10 UTC: D-115 mission audit, Dockside Burn + Shadow Ledger (read-only)
Owners: A = mission script/systems, B = content, C = map/props/generator. Severity in brackets.
### Dockside Burn
- DB-1 [blocker] no assault events (no AssaultEvents/ markers, empty HeistDef.assault_events). C markers + rows; A verifies runner.
- DB-2 [major, A] loot.contraband counts toward the 4 required bags (doc: pays, does not count). Fix: count cash_bricks + weapon_crate only.
- DB-3 [major, A] cartel reinforcements spawn as ordinary guards (heist_mission.spawn_guards ignores the `cartel` spawn tag). Fix in shared spawn_guards.
- DB-4 [major, C+A] thermite bag fixed at the gate; should start at the chosen spawn (lane / pontoon). C adds bags per spawn, A enables the matching one.
- DB-5 [major, C] count-room cage drill 180 s (LARGE) vs doc 120 s. C size MEDIUM, or A per-safe drill_duration_s override.
- DB-6 [major, A] briefing lines replay in-mission (D-117 §6): VO lane.
- DB-7 [major, C] no music stems.
- DB-8..19 [minor]: placed-saw padlock times (doc vs data, LEAD), brass padlock tell (C), fog_lifts S3 perch timing (A+C, = QC-25), harbor_unit P4 (C doc), cartel body-sighting wake (A), sniper line by perch (A), MC push bar (C), OC double door (C), [containers] optional flag (A), [cartel] kill count includes civilians (A), lift breaker stand-in (C G2), ambience/LUT (C).
### Shadow Ledger
- SL-1 [major, A+C] cage saw 180 s vs doc 90 s. A: Safe saw_duration_s override; C sets 90.
- SL-2 [major, A] camera_warning never said: VO lane.
- SL-3 [major, C] literal briefing string in def (D-117 §4).
- SL-4 [major, C] no music stems.
- SL-5..11 [minor]: [drives] completes only at 3 (doc: 2 required, A), cage_left_open requires at effects level (B/C), E3 escape zone small (C), escape name lift vs service_lift (doc), lasers line late (A), SL assault events N/A stealth-only (LEAD), ambience/LUT (C).

## HANDOFF 2026-10-14
**Branch head:** code head 4f11fb91 (`[QB-58]` runtime deployable skill gate), plus this handoff commit on top.
Everything up to 4f11fb91 is on trunk (round 199, 95f6b5bc); env/a-core has no unmerged code.

**Done since last trunk merge (not yet on trunk):** nothing beyond this status file. Last rounds (196/199, all on trunk):
- 74aa7d36 [PO-12]: the zipline cable is drawn only when both `cable_start` and `cable_end` are set (meta lc_ignore,
  honoured by C's levelcheck 67d38666). Also FLAG_STRONG = EventBus.SHOT_FX_STRONG.
- 70208a8b [D-113]: BloodFx emits the real EventBus.blood_hit / bleed_changed (events.md v1.3); the test shim is gone.
- 4f11fb91 [QB-58]: `DeployableSystem._gate_ok` checks DeployableGate.required_flag at spawn, so a stale save gets
  no gated unit.
- Green before push: validate_all PASS on all 5 maps. Unit tests 0 failed: l2_ 51, l2_11 6, a1_08 9, s5_ 27,
  s6_ 12, po8_shot_fx 10, c_equipment_hooks 2, anim_driver 26, crew_ai 5, gn_ 36, d113 2, qb56_61 14.
  Integration test_p3_loud 10, 0 failed.

**In progress:**
- **GN loud e2e (GN-A1, D-103):** ~60%. No code pending. Probe 3 (seed 1792002290, auto_loud, windowed) ran to
  t≈640 and was stopped for this handoff. From t≈491 the pilot retries
  `Variants/Group_canvas_orchard/Slot_orchard_calloway/Canvas` (bag_loot), which it cannot path to (13.5 m away,
  "could not reach", FAILED after 30 s, repeated). The crew stands still at (13.9, 5.4, 14.4) with 8 enemies within
  15 m.
  - Next step: in game/tests/a/e2e/po5_flow_auto_loud.gd `_pick`, apply the STALL_SKIP_S skip to bag_loot targets
    that fail "could not reach" (blacklist the target node for the run, not the objective). Then check whether
    Slot_orchard_calloway is reachable at all in nav (if not, it is ENV C's: nav/stairs to that gallery).
  - Log: scratchpad gn_loud_probe3.log, lost with the container. Re-run with
    `game/tests/a/e2e/run_po5.sh auto_loud 1792002290 900 <out> "Gallery Night"`.
- **GN stealth e2e:** not started (needs a gn_stealth flow; po5_flow_auto_stealth plus GN objectives).

**Queued next (ordered):**
1. GN loud probe fix above, then gn_stealth flow (D-103 GN-A1, docs/levels/gallery_night/*).
2. P's GN finding (c): crew stacking recheck in GN corridors (seed 1792002290). Also P's re-run list: transit
   single-file ≥1 m, ≥0.6 m personal radius around humans, ND police overlap 0.23 m.
3. ND loud gate attempt 24 (attempt 23 reached t=710, budget-limited). NOT started, per the handoff order; run only
   on an otherwise empty box.
4. Backlog: co-op full-auto "ghost rounds" (P PO-13(e)); escape vehicles (van drive / heli rotors); split
   HeistRuntime.start() across frames; GH G2 jeweler bench marker shift (po9_dressing_audit.md); Stinger cap /
   tase cooldown check vs PD2.

**Cross-env dependencies:**
- I wait on the lead for:
  - the `&"sensor"` alarm reason in events.md;
  - GN camera operator spawn tag (B1 wants gallery_guard_b);
  - whether AS vault doors allow courier NPC authorisation.
- I wait on ENV D: `prop_saw_device` (DrillPoint uses it for Device.SAW when present).
- Others wait on me for:
  - ENV C: nothing open (D-113 done; C uses blood_hit first, flags as the fallback);
  - ENV B: nothing open (gate done).
  - ENV C also places SL zipline anchors so the cable clears geometry.

**How to validate your area:**
- `gdlint <changed files>`; `python3 tools/ci/check_ownership.py a`; `python3 tools/ci/check_banned.py` (no
  `res://world/` in systems: use G.PROPS_DIR).
- `tools/ci/run_tests.sh a <filter>` (l2_, a1_08, s5_, s6_, po8_shot_fx, anim_driver, crew_ai, gn_, d113,
  qb56_61, ...), `tools/ci/run_tests.sh integration test_p3_loud`.
- Level-affecting changes: `bash tools/levelcheck/validate_all.sh` (5 maps, ~5 min). It rewrites
  docs/levels/*/validation.md + walkthrough.md, so run `git checkout -- docs/` before committing.
- Windowed: `game/tests/a/e2e/run_po5.sh <flow> <seed> <budget_s> <out_dir> "<Heist>"` (flows: stealth, auto_loud,
  ...); run.log in out_dir has TEL lines + pilot decisions; captures are PNGs. Max 2 windowed Godot at once.

**Gotchas:**
- New `class_name` scripts need `/opt/godot/godot --headless --path game --import` before tests see them.
- The test framework has no assert_null: use `assert_true(x == null)`.
- Never `pkill -f` / `pgrep -f` with a pattern that matches your own shell (it kills the tool shell, exit 144).
  Kill only exact PIDs from `pgrep -x godot` after checking `ps -o args=`.
- The S3.6 one-shot-unalerted rule kills guards in tests: `set_alert_state(COMBAT)` first when testing damage.
- llvmpipe windowed runs: 2 s hitches on first scene/material use (assault_director, npc_gunner). TEL
  worst_frame spikes are not game logic.
- Leaked ObjectDB / RID warnings at test exit are noise; check the `== N tests, 0 failed` line and SCRIPT ERROR.
- `CrewWeapons` `stats.wall_pierce` is a bool.
- EventBus signals must exist before `Net.replicate_event` (lead-owned core/).

**Session id:** session_015kTjrZsUFn7gLqNVwAXdkh (ENV A). Helper lanes running: none. Worktrees: none. Background
runs: none (GN probe 3 stopped, ND attempt 24 not started).

## 2026-10-14 15:45 UTC — GN-A1 groundwork APIs (D-103 §6), ND loud gate attempts 9–22
### Done (pushed; last 5a67111e)
- GN-A1 APIs, each with a unit test (test_gn_*):
  - Door.relock(lock, close) (replicated `lk`).
  - KeycardReader.set_disabled.
  - LaserGrid.set_enabled / enabled_at_start.
  - AlarmGroups + LootSpawn.alarm_on_take/alarm_group (&"sensor").
  - HackTerminal clears_alarm_group + reconfigure.
  - LootSpawn prompt_key / cut_painting prompt.
  - HeistMission.set_zone_kind (ZoneKinds, replicated) + civilians_leave(exit_tag) (QC-51).
  - KeycardPickup.carrier_tag (QC-52).
  - Staff civilians honour Door.npc_authorized_tags.
- ND loud harness and game fixes (attempts 9–22):
  - BulwarkShield lies flat when dropped.
  - Rare events honour `requires`/`excludes`.
  - NpcMotor separation cost / retire on death.
  - AI formation slots + loud leash.
  - Bot cover/LOS.
  - Per-objective HUD markers.
### In progress (local, tests pending a free box)
- NpcVisuals tag-first resolution + NpcVisualTweak.heist_tag_characters (gallery_night map, B1 list). This is heist-scoped
  because ND already uses guard_hall / guard_rover_*.
- Ambient clips: cower_seated (seated civilians cower in their seat), cower_stand at PatrolPoints tagged `cower`,
  walk_text (`text` activity), curator_inspect (`inspect`).
### Needs
- `&"sensor"` alarm reason in docs/contracts/events.md (lead).
- GN SC camera operator: which spawn tag? (B1 wants gallery_guard_b; security_operator maps to security_officer).
- AS vault door courier authorisation: VAULT locks still exclude NPC authorisation (lead to rule).
### Perf note (ND loud windowed FrameProf)
- There are single-call game-side hitches: assault_director 3–10 s per spawn burst and npc_gunner 7–10 s. They are likely first-use scene loads
  or material compiles under llvmpipe. Candidate: warm the heist's enemy / character / FX scenes at load.

## 2026-10-14 05:25 UTC — D-108 police arrest timing (last freeze gate)
### Done
- D-108: police cuff a downed player only after `CustodyTweak.police_cuff_grace_s` (2.0 s) down without firing
  (CrewHealth.down_s, min with last shot age), then hold `police_cuff_time_s` (1.5 s) at cuff range; the player
  firing, or the cop being hurt / stunned, restarts the hold. Tests: test_l2_12_police_cuffs 8/8.
### pd2_fidelity note for the lead (L2.12)
- L2.12 should read: "Police arrest a downed heister who is not shooting: after 2 s down without firing, a cop at
  arm's length holds a 1.5 s arrest; firing from the floor or hurting / stunning the cop interrupts it (◇ timings)."
- S1.1 (PO-11): while unmasked a shout only marks (stealth.casing_can_mark); it never intimidates civilians.
