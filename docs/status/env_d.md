# ENV D status: Characters & Art Production

Owner: ENV D. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## D roadmap audit: the rows with no ✅ (LEAD, 2026-10-23)
Evidence: the tests under game/tests/d (full D suite 206/206 at 2879613c), the review sheets under
game/assets/characters/_review, and this file's session entries.

| Row | Verdict | Evidence / what is missing |
|---|---|---|
| D1-00 | DONE | docs/art/style_samples/{a_gsr,b_noir,c_photo}/officer.png (v1 677fdc8; GSR v2 d93751f after D-035; noir/photo stopped at v1 per D-035). |
| D1-01 | DONE | tools/blender/characters/_rig.py (52 contract bones), _body.py (parametric build/gender/age), char_body_base{,_heavy,_fem,_old} (be6a818); test_rig (5); _review/bodies.png. |
| D1-02 | DONE | security_officer (+b..j), civilian_{customer_a/b, sales/_b, jeweler, clerk, manager}, patrol_officer (+duty, factions), tac_light (+duty, factions), crew_body/_b; test_outfits, test_scenes. |
| D1-03 | DONE | char_anim_humanoid (the P1 subset and far beyond), rig_arms char_arms_fp with the pistol set (now every weapon class); test_anims, test_arms, test_scenes.test_walk_moves_bones. |
| D1-04 | DONE | tools/blender/masks/_mask_base.py + mask_gilded_heron (3059886); test_masks. |
| D1-05 | DONE | game/tests/d (35 files); lineup _review/lineup_godot.png, crew/factions/cartel *_lineup + *_silhouette_30m. |
| D3-01 | DONE | All four P5 casts: GN (curator, attendants a-c, guards a-l, patrons a-j, admin, waiters), OF (tellers, manager, officers, guards, customers), RT (convoy crew a-f, escorts, street, diner), Afterhours (club_bouncer/_b, club_bartender/_b, club_dj, club_patron a-d); test_p5_cast.test_cast_index_covers_every_heist_and_role / test_design_rosters_have_a_cast. |
| D3-02 | DONE | Every characters.md v1.9 clip is in char_anim_humanoid: dance_a/b/c, bartender_wipe/pour, bouncer_idle, teller_count, curator_inspect, walk_text, cower_seated, cower_stand; test_anims. (Whether the club dances fire in game is Afterhours wiring, parked under D-144; the clips exist.) |
| D3-03 | DONE | 34 base shapes (10 + 12 + 12) through _mask_base, all crew-envelope fit (D-073) and all listed in B's content/data/masks/parts/bases.tres; test_masks (base surface, size/symmetry, pivot, front-projected UV0, test_crew_face_envelope_matches_current_crew). |
| D3-04 | DONE | characters.md v1.10: walk_/run_ 8-way (fl/fr/l/r/bl/br/b), walk/run start/stop, hit_react ×4 directions, death_front_b / death_back_b / death_side, downed_crawl, dozer_walk_heavy (Wrecker); test_anims, test_loco_phase. |
| D4-01 | DONE | LOD0 100 %; LOD1 Godot auto LODs to <= 45 % on big surfaces; LOD2 Skeleton3D/CrowdLod at 8-25 %, visibility ranges, no shadow (D-146), zoom-aware (D-084); heisters / contacts / specials keep full meshes by design (D-080); test_lod (7). |
| D4-02 | DONE (as whole looks) | Far more than +8 crowd looks (gala patrons a-j, bank customers, RT street / commuters / diner, club patrons a-d). Variety is pre-built whole looks per pool rather than runtime top/bottom mixing; "no two neighbours match" holds through A's per-pool round-robin deal (NpcVisuals.look_index). test_p5_cast.test_gallery_patron_variety / test_db_sl_pooled_variety. |
| D4-03 | GAP | 6 of 8 heisters (rook, sable, dutch, wren, marten, jay; D-111 added +2). Missing: 2 more heisters with body, outfit, face, FP sleeve, portrait, crew-envelope + mask regen, ids to B for the roster/picker. |

GAP fix order: D4-03 is the only gap and no shipped heist shows it, so it goes after anything the LEAD queues for a
shipped heist. Nothing is Afterhours-only parked: that cast and its clips already exist.

**D4-03 fixed (LEAD-approved picks):** `char_crew_juno` (woman, 1.73 m, fair, blond side part: emerald leather
moto jacket with an asymmetric chrome zip, graphite crew-neck, black jeans, heeled moto boots, grey suede gloves) and
`char_crew_hale` (man, 1.85 m so Dutch stays the tallest, deep skin, bald, moustache: sand canvas chore jacket, navy
henley, dark jeans, brown work boots, yellow work gloves). 26.7k / 26.9k tris. New library materials
char_crew_{juno_jacket,glove_suede,hale_jacket,glove_work}. Hale's moustache joins `Hair` (char_crew.py now joins any
all-hair Headwear, Dutch unchanged). FP sleeves `char_arms_fp_{juno,hale}`; portraits `portraits/{juno,hale}.png`.
Crew face envelope regenerated for 8 heisters (front growth <= 1 cm at the mouth from Hale's moustache) and all 36
masks rebuilt (test_masks, test_crew mask seats green). Review: `_review/crew_lineup.png`, `crew_faces.png`,
`crew_silhouette_30m.png` (the review script now sizes the lineup / silhouette to the roster), `heister_portraits.png`.
Found: `char_crew_rook.glb` on trunk is stale against the current tooling (rebuilds to different bytes, same tris);
left as is.

## To the LEAD: (2026-10-22, latest first; I read your messages, you read this)
- **PO "inorganic" follow-up: in-motion strips from a real loud heist** (`_tools/render_motion_strips`, Glasshouse
  Routine seed 7, all-AI crew, trunk 80245b93 incl. A's v1.26(a)): `_review/d_motion/{crew_sprint,crew_strafe,
  cop_run_gun,cop_stagger}.png` + motion_log.txt (base clip | layer @time | speed per frame, 0.1 s apart). v1.25 /
  v1.26 are live (hold_rifle_sprint over sprint, aim_rifle_walk over strafe, aim_pistol_run over run_*, stagger_pistol).
  **Found (to A):** (1) **8-way thrash**: the base clip changes direction almost every 0.1 s (walk_fl -> walk_bl ->
  walk_fr ..., run_bl -> run_l -> run_fr -> run -> run_b) and each switch restarts the stride (layer @0.00):
  `_locomotion_clip` rounds the smoothed velocity angle to a 45 deg sector every tick with no hysteresis and the switch
  does not carry the phase (the 8-way clips share foot_down R@0.00 / L@0.50). Likely the biggest source of the
  "inorganic" read. (2) **stagger cut**: stagger_pistol (1.2 s) is replaced by the cover post's cover_peek_l after
  0.1-0.3 s. The strafe strip frames poorly (narrow corridor: the camera rays pass the doors).
- **RT cast in place, windowed (trunk 80245b93, Routine seed 1, clean east stop):** `_review/rt_d2_cast/rt_cast_sheet.png`
  (+ log, dismount_0..5). 22 on-foot cast + 8 convoy units. OK: guards, cop_diner, street / bus / diner pools (no twins),
  sit_eat, cook_stove, the attendant at desk_work, escorts in patrol_officer_duty in sit_vehicle, cab crews hidden, the
  dismount along the exit curve into walk_stop. **For A (sent):** (1) the waitress / cook looks are swapped (no
  staff_waitress / staff_cook rows in npc_visual_tweak; civ_diner there has 21 looks, p5_cast 14); (2) `counter_wipe`
  is missing from CivilianBrain.KNOWN_ACTIVITIES (the waitress idles); (3) two escorts per seat (spawn_units(…, 1) always
  takes Seat0).
- **D-153 resume (2026-10-22, new LEAD session_01XAPqm...).** Trunk 59237213 merged (fast-forward).
  - **58cc52e1 vehicle_exit_l/_r EXIT_X 0.85 -> 1.05** (SOURCE curve total 1.050): the outside foot plants past the escort
    car's side (SILL_X + 0.30), the stand-up phases scale with the travel. test_rt_clips 6/6, test_anims 18/18.
  - **Convoy re-probe on C ffd1a4bd** (`_tools/probe_convoy_fit.gd`: trimesh colliders on the real meshes, rays from every
    Seat): all seats face +Z; car seats on the footwell (0.18), cabs on the cab floor (1.20). Car roof top 1.40 over the
    footwell (heads 1.25 / Wrecker 1.28: fits); rear knees about 0.04 m clear of the front seat backs; the exit shoulder
    clears the car side by 0.18 m (Wrecker 0.03). Cabs: roof 1.70 / 2.10, dash 0.92 ahead. **Done on D's side.**
  - **For A:** `dismount_units` teleports 1.6 m out and then plays the in-place exit clip (the NPC sits in mid-air beside the
    car). Keep the root at the seat and move it along `curve.vehicle_exit_<side>`. Escort looks (sent to A):
    Routine/Tense `patrol_officer`, Hazardous+ `tac_light` (faction reskins via the resolver); A's f43cc6be maps both
    defs to patrol_officer on every difficulty (a per-difficulty pick is A's call).
  - **B's RT mask parts** (6: road_cone, ingot bases; armor_plate, hi_vis materials; road_lines, tread patterns): building.
  - v1.25 / v1.26 wiring (anim_layers.update_hold): crew gait holds and NPC aim-on-the-move are wired; **v1.26(a), the NPC
    hold layer while moving alert and not aiming, is not** (that branch is crew-only). Strips in progress.
- **RT convoy fit on the real placements (C's swap 52debb79 / d6a15b78, env/c-worlds 552f5b15), probed in the built
  scene. Mover space: +Z = forward (the cab / the car's front), x across, y up from the ground.**
  | Vehicle | Body (local) | Seats (local) | Facing |
  |---|---|---|---|
  | Lead / Rear `veh_escort_car` | x +/-1.02, y 0..1.58, z -2.33..2.32 | (+/-0.40, 0.45, 0.25) front, (+/-0.40, 0.45, -0.75) rear | -Z (rear) |
  | T1 cab `veh_armored_cab_cash` | cab x +/-1.5, y 0.45..2.90, z 1.65..3.87 | (+/-0.65, 1.56, 2.75) | -Z (rear) |
  | T2 / T3 cab `_bullion` | cab y 0.45..3.30, z 2.40..4.62 | (+/-0.65, 1.56, 3.50) | -Z (rear) |
  1. **A (blocker): `ConvoyVehicle.seats()` finds no seat at all.** The glb exports `Seat0..n` as plain Node3D empties and
     seats() casts `as Marker3D`, so every vehicle reports 0 seats and `spawn_units(seated)` falls back to the
     beside-the-body points: nobody sits. Accept Node3D (`as Node3D`, return Array[Node3D]); the placeholder's Marker3Ds
     still pass.
  2. **C (or A when seating): every seat faces -Z, the vehicle's rear.** spawn_units copies the seat transform and an
     NPC faces its -Z, so they would sit backwards. Rotate the Seat empties 180 deg (facing +Z), or A turns the NPC.
  3. **C: seat height.** sit_vehicle puts the ROOT on the footwell floor (cushion 0.36 above). Car seats at y 0.45 put
     the cushion at 0.81 and a Wrecker's helmet at 1.73, 0.15 m through the 1.58 roof. **Car Seat y = the footwell
     floor, about 0.18** (cushion 0.54; head tops 1.39-1.46, under a liner of about 1.50). **Cab Seat y = the cab floor**:
     if 1.56 is meant as the cushion, use **1.20** (head tops 2.41-2.48, under the 2.90 / 3.30 roofs).
  4. **C: car seat rows 1.0 m apart (z 0.25 / -0.75).** A seated body spans 0.76 m ahead of its root to 0.40 behind, so
     the rear sitters' knees overlap the front seat backs by about 0.16 m. **Rear row to z -0.95** (or front to 0.45).
     Side to side +/-0.40 is fine (half width 0.35-0.40; the car's inside is about +/-0.95).
  5. **Dismount (A, D):** car: vehicle_exit_l / _r move the root 0.85 m out, from x 0.40 to 1.25, which leaves the
     shoulder at the body side (1.02). Walk 0.3 m on after the clip, or ask and I'll lengthen EXIT_X to 1.05 for
     these cars (no caller yet, so it is cheap). Seats at local +x exit with `_l` and -x with `_r` (facing +Z).
     Trucks: the crew is hidden (armoured) and the cab floor is about 1.2 m up, so vehicle_exit (footwell level with the
     road) does not apply. Dismount them standing beside the cab door (the current teleport is right for them).
  6. Wrecker (Lethal `armored_escort`): still too tall for this car's door (it needs a door frame >= 1.50 m above the
     floor; the escort car gives about 1.40 with the floor at 0.18). Keep it out of the seats.
  - **IDLE, can take X** (I can re-run this probe on any later convoy commit in a few minutes).
- **RT diner identity pass (C 0832f69b on env/c-worlds) vs D's clips: fits, with one item for C.**
  - OK: prop_diner_chair keeps the task chair's Seat (0.47 m, seat_fwd 0.12), so the 5 sit_eat customers stay 0.22 m from
    their table edge. The tables keep top 0.74 (0.808 square). prop_diner_counter_w250 is 0.804 deep with a 0.90 top
    (the overhang sits inside the box), so the waitress stays 0.28 m from the staff-side edge. The cook is unchanged. The 7
    stools (0.72 m, dressing, no sitters) are clear of the counter cower marks. The booths have no sitters (if they get
    sitters later: my booth numbers below, entry of 22:00).
  - **C: CowerFrontW / CowerFrontE (z 14.41) still stand under the front window** (opening x 20.0-23.0, sill 0.8 m),
    and the west-wall spots I suggested are now taken by DinerBooth1 (z 18.25-20.65); only z 20.65-21.4 is left
    there. **Simplest fix: set those two points' activity to `cower`** (the crouched family; no wall needed, and the
    back stays below the 0.8 m sill), or move one to (14.41, 0, 21.0), yaw -90.
  - **Convoy swap (A's ConvoyVehicle / ArmoredTruck on C's layout):** not on env/c-worlds yet. I'll run the seat /
    dismount fit on the real placements as soon as it lands; the generic numbers are in the 22:00 entry.
  - AH dj_mix vs the AH booth: no AH map yet; the placement C needs is in SOURCE `ah_dj_placement` (prep/d-ah).
  - **IDLE, watching env/c-worlds for the convoy swap; can take X.**
- **RT convoy dismount vs A's ConvoyVehicle (trunk round 269) and the "Wrecker through a car door":** I CPU-skinned each
  look in sit_vehicle / sit_vehicle_drive / vehicle_exit_l (root on the footwell floor):
  | Look | Seated top | Half width | Through the door band: top | fore / aft (seat space, -z ahead) |
  |---|---|---|---|---|
  | patrol_officer_duty | 1.25 | 0.35 | 1.34 | -0.62 .. +0.13 |
  | tac_light | 1.23 | 0.35 | 1.30 | -0.62 .. +0.13 |
  | tac_heavy | 1.25 | 0.36 | 1.37 | -0.62 .. +0.14 |
  | **wrecker / _sentinel** | 1.28 | 0.40 | **1.45** | -0.64 .. +0.21 |
  | armored_car_crew | 1.21 | 0.35 | 1.28 | -0.62 .. +0.13 |
  - **The Wrecker does not fit a car door**: its helmet passes the frame at 1.45 m above the footwell, and the
    placeholder car (body 1.45 m tall from y 0.05) gives about 1.35. Give the Lethal `armored_escort` Wrecker an
    SUV / van (door frame >= 1.50 m above its floor), or spawn it beside the vehicle (spawn_units' plain-body points),
    never seated in a car. TAC Heavy needs >= 1.42.
  - **For A, in `ConvoyVehicle` / `heist_mission.spawn_units` / `_seat` / `dismount_units`:**
    1. **Facing:** the placeholder's `Seat0..3` markers have identity rotation, and `spawn_units` copies the marker
       transform, so a seated NPC faces -Z, the car's rear (forward is +Z). Rotate the markers 180 deg (or the NPC).
    2. **Height:** the NPC root goes at the marker (y 0.40). sit_vehicle wants the root on the footwell floor (cushion
       0.36 m above it), so occupants would sit 0.36 m too high with their heads through the roof. **Seat marker y = the
       footwell floor (about 0.05-0.10)**, or subtract 0.36.
    3. **Rows:** Seat0/1 (z 0.4) and Seat2/3 (z -0.6) are 1.0 m apart, but a seated body spans 0.76 m ahead of its root
       to 0.40 behind, so a rear sitter's knees go into the front sitter's back. **Rows >= 1.2 m apart** (e.g. z 0.5 /
       -0.7).
    4. **Pose:** `_seat` disables the NPC's processing without a `sit_vehicle` hint, so a visible occupant (car) freezes
       in its spawn pose. Play `sit_vehicle` (or `sit_vehicle_drive` for the driver: the left seat, +X, when facing
       +Z) before pausing, or keep the AnimationPlayer processing.
    5. **Dismount:** `dismount_units` teleports 1.6 m sideways, and `play_vehicle_exit` has no caller. Play
       `vehicle_exit_l` for seats at local +x (the character's left when facing +Z) and `_r` for -x, moving the root
       along SOURCE `curve.vehicle_exit_<side>` (0.85 m), then hand over to the brain. Keep 1.10 m beside the seat clear.
  - **My SOURCE note was wrong:** it said head about 1.0-1.05 m and liner >= 1.15 m, ignoring caps and helmets.
    `rt_vehicle_placement` now gives the measured numbers: liner >= 1.33 m, door frame >= 1.33 / 1.42 / 1.50 m, rows
    >= 1.2 m (SOURCE text only; the clips are byte-identical).
- **RT diner (C's identity pass has not landed on env/c-worlds yet).** Ready-made numbers for when booths and stools arrive:
  - **Booth (sit_eat):** bench seat top 0.47 m (+/- 2 cm), Seat marker 0.12 m forward of the cushion centre (the chair rule),
    table top 0.74 with its near edge **0.22 m ahead of the root**; under the table keep 0.47 m ahead of the root open
    from the floor to 0.70 m (knees and shins); backrest at least 0.35 m behind the root (plain looks reach 0.32-0.34);
    sitters at least 0.80 m apart side to side (half width 0.39-0.40).
  - **Counter stools:** D has no clip for sitting at a 0.90 m counter on a 0.65-0.75 m stool (sit_eat is chair height
    over a 0.74 table). Stools are dressing only, unless you want me to build `sit_stool_eat`.
  - **D data, done here:** `civ_diner` no longer shares the street pool. The 7 back-bag looks (cower_offsets) are out,
    because their bags (0.47-0.56 m behind the root) would cross a chair or booth back. 14 looks for 5 seated diners,
    no twins; test_p5_cast pool row split.
  - **IDLE, can take X.**
- **Polish #2 done: env/d-art efa651788** (merged into prep/d-ah, 932515b54, library rebuilt there with dj_mix too).
  `idle_alert_b` (a wristwatch check and a slow weight shift, 150 f) and `idle_alert_c` (a thumb on the shoulder radio,
  then a look round, 174 f). Frame 0 and the seam ARE idle_alert frame 0 (0.39 mm; the variant layer is zero at the
  seam), so every chain into or out of idle_alert is untouched. Max step 9 deg, the root fixed. Tests: new
  `test_idle_variants` (seam, loop, events, smoothness, floor, root), test_anims (+2 clips), reaction_steps, rt_clips,
  npcs, crew_states, surrender_variants all pass. Windowed: `_review/d_polish/idle_alert_variants.png`.
  **For A, one line to switch it on:** `VARIANT_GROUPS[&"idle_alert"] = [&"idle_alert", &"idle_alert_b", &"idle_alert_c"]`
  (SOURCE `idle_alert_variants`).
- **Polish #3: assessed, no change (not worth its risk).** breach_standback's 5.5 mm is `crouch_idle`'s own frame-0
  toe (the back foot on its ball), which every crouch clip chains through: fixing it re-keys the crouch family for
  an invisible shoe tip. death_kneel's 49 deg is the arms reacting to the hit, in line with the other deaths
  (death_front 40, hit_head 49).
- **RT re-check on trunk 0045c5d6 (C folded the cross-check in): all good except two items.**
  - OK: waitress (24.68, counter_wipe), cook (28.25, cook_stove), bus queue (13.32, sit), the 5 customers on
    prop_chair_task at 19.76 / 21.24 (the chair Seat moves them 0.12 m to 0.22 m from the table edge) with table 2 for the 5th,
    the attendant on prop_chair_office (Seat to -15.65, 0.20 m from the desk's near edge; desk top 0.74 = desk_work),
    and the cower marks at the counter (23.39) and the shelters (12.24), all 0.21 m off their wall.
  - **C: CowerFrontW / CowerFrontE (20.5 / 22.5, z 14.41) sit under the front window** (opening x 20.0-23.0, sill
    0.8 m), so a standing cower leans back into glass. The west wall is solid full height at z 18.5-21.4 (between the
    window and the side door): **(14.41, 0, 19.2) and (14.41, 0, 20.7), yaw -90 (facing +X)**.
  - **C/A: ReyesMixer** stands `idle` on foot at (-39, 0, -15.8) beside the MixerTruck box. The fiction puts him in
    the cab, so once the cab exists: root on the cab floor under the seat, `sit_vehicle_drive`, wheel numbers as in
    the cross-check. Fine as it is for G1.
  - **D data, done here:** p5_cast tag_map.rolling_thunder gains `staff_waitress: [diner_waitress]`,
    `staff_cook: [diner_cook]` (the spawns list them first). **A:** mirror the two rows into heist_tag_characters.
  - **IDLE, can take X.**
- **D-151: prep/d-rt is merged into env/d-art and ready for your next round** (prep/d-rt b221ec3ca + trunk edcb536e;
  no conflicts; the latest prep/d-rt carries the lineups, the g/h/i palette swaps, Reyes, cower offsets, the RT clips
  and the reaction-snap fix).
  - **Per-look and clip tests, all pass:** p5_cast 17/17, cower_offsets, lod, outfits, scenes, skirt_drape, npcs,
    hit_zones, ragdoll, rig, civ_panic, factions, anims 18/18, rt_clips 6/6, reaction_steps, surrender_variants,
    crew_states, of_cast_clips, bank_clips, character_warm. Ownership d and banned are clean.
  - Your order: polish #1 is already in (env/d-art 9c093d472, included here). Next, the cross-check findings into the
    RT cast when C's G2 lands. The D-side data is ready to go: the `staff_waitress` / `staff_cook` tag rows once C
    names the tags. prep/d-ah stays held; it already contains this prep/d-rt.
- **Backlog #1 done (reaction snaps): env/d-art 9c093d472, merge-safe, ready for a normal round.**
  - surrender 55 -> 34 deg per frame, surrender_b 52 -> 32, surrender_c 52 -> 38, mask_on 52 -> 34 (arms), downed_arrested 52 -> 40.
    The first two had an ease-out start (the hands left rest at full speed), now ease-in-out. In the other three a
    folded arm's hand passed next to the shoulder, where the elbow swings round. One extra key per clip (`rise`, `clear`,
    `lower`) keeps the hand clear. Names, lengths, events and the chained first / last poses are unchanged
    (start_err / end_err 0.00 mm); every other clip's SOURCE row is byte-identical. panic_start stays (its 51 deg is
    the designed startle at `flinch`).
  - **Tests:** new `test_reaction_steps` (arm bones <= 42 deg per frame; it fails on the old library at 52-55 deg and
    passes now); test_anims, surrender_variants, civ_panic, crew_states, ragdoll, npcs, bank_clips, of_cast_clips all pass.
    Windowed: `_review/d_polish/reaction_snaps_after.png` (new `render_clip_strip.gd`).
  - **Kept the prep branches merge-clean:** env/d-art merged into prep/d-rt (b221ec3ca) and prep/d-rt into prep/d-ah
    (fa5c5d080), with the library rebuilt on each (the only conflicts were the generated glb / SOURCE / res). RT, AH and
    reaction tests all pass on both. Merge order stays env/d-art -> prep/d-rt -> prep/d-ah.
  - Next: backlog #2 (guard idle variety) needs A's one `VARIANT_GROUPS` row; say go and I build the three clips.
    #3 (breach_standback floor, death_kneel arms) I can do now: **IDLE, can take X / #3.**
- **D backlog, top 3 for the 6 shipped heists (your 17:35 ask). Scan of all 245 library clips: no reach error
  over 1 cm and no foot / contact slide, so the value is in the snaps:**
  1. **WORKING: reaction-clip snaps.** surrender / surrender_b / panic_start snap both forearms 51-55 deg in ONE frame at
     frame 1 (the hands leave idle at full speed: the ease into the hands-up key is `out`, so the wrist jumps 11 cm in
     the first frame from rest). surrender_c snaps 52 deg at f6, mask_on 50-52 deg at f25-28 (the arms drop from the strap
     in 4 frames), downed_arrested 52 deg at f24. **Value:** these are the most-watched reactions in every heist
     (civilians at the alarm, every guard / cop who gives up, the 3 crew masking up at each heist start), and a one-frame
     pop reads as a glitch. Merge-safe: names, lengths, events and the exact chained start / end poses stay; target
     <= 30 deg per frame; tested by test_anims / test_civ_panic / test_surrender_variants / test_crew_states.
  2. **Guard idle variety:** in the stealth coverage, guards spend about 60-70 % of their time in `idle_alert` / `idle` at
     posts and patrol stops (OF Haz 1,079 s of 1,700 s). Three variants (weight shift + watch check, stretch + look
     round, radio thumb), D builds them; A adds one `VARIANT_GROUPS` row (as for cower / queue). **Value:** the
     most-seen NPC pose in every stealth run stops reading as a synchronised troupe.
  3. **Small polish:** breach_standback puts skin 5.5 mm under the floor (the only clip over 5 mm), and death_kneel whips
     the arms 44-49 deg at f6-11. **Value:** visible at the police breach and at every kneeling death; cheap.
- **Older-heist regression after today's AI changes (anim coverage, trunk b0bd47a0): 0 flags in all 5 runs** (no
  FROZEN, MISMATCH, NO_CLIP, SLIDE or STATIC; 0 script errors).
  | Run | Bodies | Flags |
  |---|---|---|
  | ND loud Routine (240 s, 3 crew AI) | 47 (25 patrol, 8 TAC Light, 6 Bulwark, 4 guards, 1 civilian, 3 crew) | 0 |
  | GN loud Routine | 34 (17 civilians, 4 guards, 10 patrol, 3 crew) | 0 |
  | DB loud Routine | 45 (22 patrol, 8 TAC Light, 5 Bulwark, 6 cartel, 1 civilian, 3 crew) | 0 |
  | SL stealth Hazardous (300 s, alarm at 200 s) | 6 (4 guards, 2 civilians) | 0 |
  | GN stealth Hazardous (300 s, alarm at 200 s) | 27 (18 civilians, 5 guards, 4 patrol) | 0 |
  - In stealth, the guards patrol (walk, investigate_look, smoke) and civilians run their ambients (mop, phone_call,
    browse, curator_inspect, desk_work); after the alarm, cower / cower_b / cower_c / cower_stand and flee. Neither SL
    nor GN has a `civ_manager*` spawn, so the harness tie was skipped there (it was covered on OF).
  - **Question for C/A:** an SL **guard** plays `teller_count` (cash counting), probably the reception post, and a GN
    civilian does too. If the reception guard should look busy at the desk, `desk_work` or `check_desk_write` read better
    than counting banknotes.
  - SL Hazardous fielded only 2 civilians on this seed. Not anim; mentioned in case it is unexpected.
  - **IDLE, can take X.**
- **OF done check, anim coverage on trunk b0bd47a0: 0 flags in both runs** (no FROZEN, MISMATCH, NO_CLIP, SLIDE or STATIC).
  - **Stealth at Hazardous** (300 s, seed 1002, no bots; harness ties the manager at 60 s, alarm at 200 s): 29 bodies (19
    civilians, 6 Halden guards, 4 police). Clips seen: guard patrol walk / run / investigate_look / smoke; teller_count,
    queue_idle, phone_call, sit_chair, desk_work; the manager `tied` (shouted and tied as a player would); after the
    alarm cower / cower_b / cower_c, cower_stand, cower_seated and flee_b.
  - **Loud at Routine** (240 s, 3 crew AI): 31 bodies (14 civilians, 4 guards, 10 patrol officers, 3 crew). Clips seen:
    cower variants and flee / panic_start for the civilians, deaths and alert pistol for the guards, and for the police
    alert pistol, strafes and the 8-way run / walk. Routine fields only patrol_officer, which resolves to its D-145.3
    duty look; the coverage tool does not log looks (the GH wave review proved the resolver, 4/4).
  - Tool: `loud_anim_coverage.gd` gained `--stealth`, `--tie-manager-at` and `--alarm-at` (env/d-art 9a72fb855).
    Logs and JSON are local to the run; the numbers above are from them.
  - **IDLE, can take X.**
- **AH lineups for the PO: prep/d-ah dec6cb22e, `game/assets/characters/_review/ah_lineup/`.** Six lit 1920x1080
  sheets, front and 3/4, captioned, the same as RT's: door (7 bouncers and the off-duty cop), bar (6 staff and the DJ),
  patrons_club (a-j, the dancer looks), patrons_gala (the 10 reused gala looks for the VIP and balcony), couriers (12
  cartel), specials (Phantom, Stinger, Bulwark, Wrecker, Corpsman, Longshot, Brandt, Aegis). Tool: `render_rt_lineup.gd
  --heist=afterhours`.
  - Your r262 note: the 16 swaps and their per-look tests were already done (prep/d-ah 8238fdaa3, entry below).
  - Same caveat as RT: rendered with the Compatibility renderer on llvmpipe. Re-run on the GPU box before the PO judges
    skin and satin.
  - **IDLE, can take X.**
- **RT greybox vs D's clips and cast (for C; read-only, origin/env/c-worlds 529d9450, `rolling_thunder_layout_content.gd`).**
  Coordinates are world x, y, z (m); spawn yaw 90 faces -X and 180 faces +Z, as C's spawns use it. Heights match:
  counter 0.90, cookline 0.90, diner tables 0.74, booth desk 0.75 (desk_work 0.74), shelter benches 0.45 (sit 0.47; 2 cm
  is fine). **The positions and activities don't match:**
  1. **Waitress** (25.5, 0, 20.5), activity `idle`. counter_wipe wants the root 0.28 m behind the counter's staff-side
     edge (x 24.40), facing it: **(24.68, 0, 20.5), yaw 90, activity `counter_wipe`** (A: map the hint). The aisle behind,
     2.75 m to the cookline, is fine.
  2. **Cook** (28.55, 0, 17.0) is 0.60 m from the cookline edge (x 27.95). cook_stove wants 0.30 m:
     **(28.25, 0, 17.0)**, yaw 90; the activity `cook_stove` is already right.
  3. **Diner customers** (`civ_diner` x 5): none sits; all are `idle`. Customers 0 and 1 stand at x 18.0 facing the
     booth boxes, 2 and 3 at x 21.6, 0.70 m off the table edge, and 4 at (19.5, 20) at no table. The booth boxes (1.5 x 1.2 x
     1.4 solid, x 15.5-17.0) are 3.1 m from the tables, so no booth is next to a table. sit_eat wants a seat top
     0.47 m (chair or booth bench, Seat at the root, 0.12 m forward of the cushion centre), the table top 0.74, its near
     edge **0.22 m ahead of the root**. For the current tables (0.8 x 0.8 at x 20.5, z 18 / 22): **west seat roots
     (19.88, 0, 18 | 22) facing +X (yaw -90); east (21.12, 0, 18 | 22) facing -X (yaw 90)**; activity `sit_eat`. A 5th
     customer needs a 3rd table or a real booth: two benches facing across a 0.7 m table, each root 0.22 m from the edge.
  4. **Bus queue** (`civ_bus` x 4) stands at z 14.0, 0.55 m in front of the benches (z 12.95-13.45), activity `idle`. The
     roster says sit: **roots at z 13.32** (bench centre + 0.12), x unchanged (1.0 m apart is fine), yaw 180, activity `sit`.
  5. **Car-park attendant** (18.5, 0, -16.2) faces the booth desk (near edge z -15.45) from 0.75 m away, standing `idle`;
     the roster says sit at the desk. desk_work wants an npc chair with its Seat at the root and the desk near edge
     about 0.20 m ahead (keyboard 0.36 m): **(18.5, 0, -15.65)**, yaw 180, prop_chair_office there, activity `desk_work`.
     The real desk must be open below for the knees; the greybox box is solid.
  6. **No cower marks in RT at all.** OF has `cower_stand` points tagged `cower`; RT's patrol data has none (doc §4: the
     street flees, everyone else cowers). cower_stand wants a wall **0.21 m behind the root** (back-bag looks step out
     0.12-0.25 m by cower_offsets), with about 0.7 m clear in front. Candidates: inside the diner front wall (z 14) facing
     +Z; the customer side of the counter, **x 23.39 facing -X** (like OF's CowerCounter); behind the shelters on their
     north face, **z 12.24 facing -Z** (yaw 0; the front holds the bench); in booth AB the attendant uses `cower_seated` on
     the chair from item 5. Diner customers on chairs cower seated too.
  7. **Convoy:** the ConvoyLayout placeholders are only vehicle boxes, with no seats, wheels or `convoy_*` spawns yet. When
     they come (rt_vehicle_placement / test_rt_clips): the driver root goes on the footwell floor under the seat centre,
     cushion 0.36 m above it, **wheel centre 0.40 m ahead and 0.76 m up, rim radius 0.18, face tilted 30 deg**, head
     about 1.0-1.05 m up, roof liner at least 1.15 m. The cars are 1.5 m tall: fine if their floor is at most 0.35 m. Door
     opening 0.30 m behind to 0.65 m ahead of the seat centre, sill at most 0.22 m up, 0.42 m beside the seat centre; keep
     1.10 m beside the seat clear. vehicle_exit assumes the footwell is level with the road, so the 3.2-3.6 m armoured
     cabs need van_exit or a root drop (A).
  8. **Tags (D + C):** `staff_diner` deals [diner_waitress, diner_cook] round-robin, so the cook spawn can get the
     waitress look and vice versa. Proposal: C puts `staff_waitress` / `staff_cook` first in those two spawns' tags; D
     maps them in p5_cast (data only, on prep/d-rt when you say so).
- **Loud screenshot review (NPC anim and clipping):** there are no GH loud captures on any branch (P's GH captures are
  stealth, po6_gh). I reviewed the newest OF loud frames on gpu/renders: `a/of_a6_b1800_partial` (GPU-20),
  `a/of_a5_b1500` and `a/of_r256_b480`, about 35 frames at full resolution where it mattered.
  - **No NPC animation or mesh-clipping defects found.** Firing and aim poses (TAC Light / Heavy, the Zero reskins, the
    crew), the deaths and the lying bodies, civilians cowering and with hands up, and the Commander Brandt wave all
    read correctly. Weapons sit in the hands, and nothing sinks into the floor or walls.
  - **One recurring issue, not an animation bug:** in every `stuck_*` frame the bot pilot is pressed against a TAC unit
    and the camera ends up inside it (a6 `13_stuck_3`: the inside of a Zero TAC Light's plate and arm fills the view;
    a5 `12_stuck_1` is the same). The aim pose's arms and rifle reach about 0.6 m in front of the NPC, more than the
    player-to-NPC capsule gap. **For A/P, low priority:** keep NPCs about 0.8 m from a player root (motor separation),
    or treat it as a harness artefact of the stuck pilot. PD2 lets enemies get this close too.
  - Also seen: a crew AI teammate standing in the player's face (a6 `09_auto_212`). That is crew AI spacing (A).
  - **IDLE, can take X.**
- **AH prep done on `prep/d-ah` 8238fdaa3 (held for AH's turn; branched from prep/d-rt, so merge RT first).**
  - **dj_mix** (dfd7ce9bf), as reported below.
  - **16 finish swaps, 0 new meshes:** bouncers c-g, bartenders c/d, club_waiter/_b (the gala waiters in Velvet violet),
    patrons e-j, frd_agent_offduty. Every swap has the same per-mesh tri counts as its base. `recolor` is now one shared step
    (`_outfit_build.apply_recolor`). There are 3 new library colours (char_satin_silver, _emerald, _coral). p5_cast has
    the AH pools (bouncer 7, bartender 6, patron 20 = 10 club + 10 gala, dancer 10, off-duty, couriers 12) and
    `tag_map.afterhours` (18 spawn tags) for A to mirror.
  - **Checks:** test_p5_cast 17/17, cower_offsets, lod, outfits, scenes, skirt_drape, npcs, hit_zones, ragdoll, rig,
    civ_panic, factions, character_warm, ah_clips and anims all pass; gdlint, ownership d and banned are clean.
    Review: `_review/ah_d1/ah_{door,bar,patrons}_sheet.png` (+ 30 m lineups and silhouettes).
  - **Known limit:** the off-duty cop's FRD letters are geometry, so they show as faint relief on the black leather
    back up close. Removing them is a small recipe option, not a mesh. Say if you want it.
  - **Next:** P's GH/OF loud screenshots, checking for NPC anim and clipping issues.
- **WORKING: AH prep on `prep/d-ah`** (branched from prep/d-rt, so RT merges first and the anim library stays one line).
  - **`dj_mix` is pushed: prep/d-ah dfd7ce9bf.** The DJ at the 1.0 m booth, 120 BPM: left hand on the faders, right on
    the jog wheel, knee bounce and head nod on the beat, and once per loop the right hand to the headphone cup (`cue`@90).
    reach_err is 0 and the max joint step is 10.7 deg. The booth layout is in the SOURCE note `ah_dj_placement`. Tests:
    test_ah_clips 3/3 (new), test_anims 18/18 (253 clips), test_rt_clips 6/6. Review:
    `_review/ah_d1/dj_mix_review.png`.
  - **16 finish swaps:** building now (0 new meshes), with p5_cast pools and tag_map.afterhours staged. Report to follow.
- **RT lineups are already done and ready for the PO:** prep/d-rt de0212248, `game/assets/characters/_review/rt_lineup/`
  (six 1080p sheets; see the entry below). Read them straight from origin/prep/d-rt. I recorded your dancer ruling
  in `afterhours_cast_plan.md`. **IDLE, can take X.**
- **Afterhours cast plan, paper only (D-147): `game/assets/characters/_review/afterhours_cast_plan.md` (env/d-art).**
  Needs 0 new meshes, 16 finish swaps (5 bouncer, 4 bartender, 6 patron, 1 off-duty) and 1 new clip, `dj_mix`.
  Estimate about half a D day; the earlier estimate was 2.
  - Reused as is: the 10 gala `gallery_patron` looks (VIP and balcony crowd), `gallery_waiter` / `_b` (as violet swaps),
    `club_dj`, the cartel looks (couriers), and every special and police look via their EnemyDefs.
  - **PO question:** dancers (30 live) share the 10 club looks. No twin inside a 5-dancer cluster, but looks repeat
    across clusters (D-130 allows it). Accept, or pay for more swaps?
  - **Flag:** the roster's "plain clothes" off-duty cop is `frd_agent`, which wears the FRD windbreaker with marks. The
    plan includes a swap without the marks.
  - **IDLE again, can take X.**
- **RT cast lineups for the PO: prep/d-rt de0212248, `game/assets/characters/_review/rt_lineup/`.** Six lit
  1920x1080 sheets, each look front + 3/4, idle, captioned: convoy, escorts (Routine/Tense duty → Hazardous → Brutal →
  Lethal (+ rare Wrecker) → Cataclysm), street_reused (12 OF looks), street_rt (pedestrians a-i + the 3 staff), site
  (Halden a-j + beat cop), specials (Reyes). The tool is `world/characters/_tools/render_rt_lineup.gd`.
  - Rendered on llvmpipe with the Compatibility renderer. Skin tone 1 reads near-white there (crew_f, pedestrian_f,
    some Halden faces). That is not new, but please re-run it on the GPU box in Forward+ before the PO judges skin; the
    command is in `next_heist_cast_notes.md`.
  - The lineups showed g's camel mac reading close to civilian_customer_a's camel coat, so g is teal now. The cast and
    cower-offset tests pass.
  - Next: the Afterhours cast list against D-147, as a paper doc.
- **IDLE, can take X** (r259). The palette swaps are already done: prep/d-rt daf913b8f has street_pedestrian g/h/i
  (finish-only swaps of a/b/f, 21 looks, zero twins at the top roll; per-look tests all pass; see the D-149 item 1 entry
  below). prep/d-rt is held for the OF done check. Open for any task: RT (lineup renders, more clips) or Afterhours prep
  on paper (dj_mix, the patron, bouncer and bartender looks).
- **D-149 item 3: loud anim coverage on GH and DB at Tense (r257 merged into env/d-art):** no anim flags on either
  map. GH covered 73 bodies and DB 49, with no FROZEN, PLAYER_MISMATCH, NO_CLIP, SLIDE or STATIC flags.
  Evidence: `game/assets/characters/_review/loud_cov_r257/` (README and both JSONs).
  - **Behaviour notes for A, not anim:**
    - GH: the 2 Halden guards aim for 455 s in total and never fire.
    - DB: the 6 cartel gunmen stand idle or sit armed for about 215 s each and aim for 1.4 s in total. That may be fine if the crew never goes to them.
    - DB: the Longshot never aims.
- **D-149 item 1 done: prep/d-rt daf913b8f.** I built `street_pedestrian_g/h/i` as finish-only swaps of a, b and f.
  They use the same meshes (tri counts identical per mesh); only the skin tone, hair colour and garment materials
  change. g has a camel mac, h a cream hoodie with navy joggers, i a grey blazer over ivory. The street, bus and diner
  pool is now 21 looks, so the top roll of 21 live has no twins. Each swap is a new face in the pool, and each gender
  has at least 7. i keeps f's shoulder bag, so its cower offset is 0.14.
  - **Item 2:** test_p5_cast, cower_offsets, lod, outfits, scenes, skirt_drape, npcs, hit_zones, ragdoll, rig, civ_panic
    and character_warm all pass. gdlint, check_ownership d and check_banned are clean.
  - **Evidence:** windowed review `game/assets/characters/_review/rt_d1_cast/rt_street_swaps_{sheet,lineup_30m,silhouette_30m}.png`,
    each base beside its swap. g's first ice-blue mac read as a lab coat, so it is camel now. The tag-map ask to A is now 9 pedestrians, not 6.
  - **Next:** item 3, loud_anim_coverage on GH and DB at Tense.
- **RT re-check vs C's next_heist_rolling_thunder.md (r256): prep/d-rt 840699e64.**
  - RT-D2's clips and the cook / waitress looks are all on prep/d-rt. The diner counter, `prop_counter_sales`, is 0.9 m,
    the height counter_wipe is authored for.
  - **Fixed, one of my misses:** `test_cower_offsets` failed on prep/d-rt. Three pedestrians carry back bags and had no
    offset. They now have offsets: c 0.12, e 0.25 (the deep delivery backpack), f 0.14. The test now also measures
    diner_staff and carpark_attendant. Every per-look D test now passes on prep/d-rt: cower_offsets, lod, outfits,
    scenes, skirt_drape, npcs, hit_zones, ragdoll, rig and civ_panic.
  - **Ruling needed (C §3/§4 vs D-103 §3b.1):** do NOT map `convoy_lead` / `convoy_rear`. A spawn tag beats the
    EnemyDef in NpcVisuals, so any row would give every difficulty the same escort look. That would bypass the D-145.3
    duty looks, the faction reskins and tac_heavy. The escorts are EnemyDefs, so they get a look anyway, never a
    capsule. Please carve these two out of the "every spawn tag maps" rule, and A should test it.
  - **For A, after the merge:** `npc_visual_tweak.tres` RT needs the 6 street_pedestrian looks added to civ_street,
    civ_bus and civ_diner, plus new rows `staff_diner`, `staff_booth` and `driver_mixer` (Reyes = contact_hollis).
    The list is in the notes.
- **RT cast check (your r255 ask): prep/d-rt fb5160ef2** (on 39f981cc7; your note said 83cc1a187, which is now two commits
  back). C's `next_heist_rolling_thunder.md` is on no branch yet, so I checked against `rolling_thunder.md`'s roster
  (trunk e9c8744f) and D-147. Every row has a cast. 6 of the 9 rows reuse existing looks: Halden, patrol_officer, the Vaultline crew and marshal,
  the 12 OF day looks for street, bus and diner, and the escorts and police via A's resolver. The 9 new RT looks were
  built from the outfit kit's library garments, with no new meshes.
  - **One gap, filled by reuse:** Reyes drives the ram mixer himself (crash stop), and nothing cast him. He is now
    `contact_hollis` on pool `ram_driver` / tag `driver_mixer` (proposed tag name, for C), using sit_vehicle_drive.
  - **Doc drift for C:** the roster row says the marshal is `armored_car_crew_b`; the cast is `armored_car_marshal`
    (QC-86's hi-vis variant).
  - **Twins:** at most 21 live (street 12 + bus 4 + diner 5) on 18 looks, so 3 repeats at the top roll only. D-130
    allows it. If the PO wants zero, 3 palette-only swaps cover it (D-147). Not built.
  - Clips: none missing. Checks: test_p5_cast 17/17, test_character_warm 2/2, gdlint, check_ownership d, check_banned
    clean. Evidence: `game/assets/characters/_review/next_heist_cast_notes.md` (RT cast check table) on prep/d-rt.
- **D-148 RT cast / clips: prep/d-rt 39f981cc7** (on top of 83cc1a187; still not on env/d-art).
  - **Built this push:** `sit_eat` and `cook_stove` (implemented in the parked _anim_rt but never registered, so never
    built), `sit_vehicle_drive` (the escort / crew driver: sit_vehicle's seat and glances, both hands on the wheel at
    10 and 2 with small steering), `counter_wipe` (the waitress: bartender_wipe at the diner's 0.9 m counter; the bar
    clip's 1.05 m would leave her hands 15 cm above the top). bartender_wipe now takes height / lean as parameters
    (its own clip identical). Checks: reach error sit_eat 0, cook_stove 5.1 mm, drive 5.5 mm, counter_wipe 0; no skin
    below the floor.
  - **Reused, nothing to build (D-147):** escort officers in cars = the police looks via their EnemyDefs (duty and
    faction variants on Routine / Tense) seated with `sit_vehicle` (passengers) or `sit_vehicle_drive` (drivers); convoy
    guards bailing out = `vehicle_exit_l` / `_r` (crew and police roles); marshal `radio_call`; pedestrians `walk_text`;
    bus queue `sit`; cowering `cower_seated` (booths, shelter benches) / `cower_stand`.
  - **Tests (worktree):** d test_rt_clips 6 (now covers all 7 RT clips: presence, events, floor, loops; new: the
    driver's wrists stay within 12 cm of the wheel rim points, counter_wipe's flat hand 0.15 m below bartender_wipe's),
    test_anims 18 (clip count 248 -> 252), test_p5_cast 17, test_scenes 9. gdlint, check_ownership d, check_banned clean.
  - **For A:** HINT_CLIPS / KNOWN_ACTIVITIES aliases for the new clips (`drive` -> sit_vehicle_drive, `counter_wipe`
    / `wipe` -> counter_wipe; sit_eat / cook already there); seat the driver (Seat0) with sit_vehicle_drive and the
    others with sit_vehicle; the dismount is vehicle_exit_* with curve.vehicle_exit_<side> root motion (existing
    play_vehicle_exit). Check the Wrecker's dismount in the rear escort (bulky body through a car door) once C's car
    exists.
  - **For C (prop sizes the clips assume, from _anim_rt):** car seat cushion 0.36 m over the footwell floor
    (rt_vehicle_placement); steering wheel rim centre 0.40 m ahead / 0.76 m up from the root, radius 0.18, face tilted
    30 deg; diner counter top 0.90 m (waitress root 0.28 m behind its near edge, as the bar rule); booth table top
    0.74 m, near edge 0.22 m ahead of the seated root; griddle top 0.90 m, front edge 0.30 m ahead of the cook.
    (A SOURCE `rt_diner_placement` note will be added on the next library rebuild.)
- **OF loud Cataclysm animation check:** A's gpu/renders/a/of_hitch* stills are first-person HUD frames with almost no
  NPC on screen, so they can't show NPC animation; the logs have no animation warnings. Instead I ran my headless
  `_tools/loud_anim_coverage.tscn` (P's AnimCoverage) on OF, Cataclysm, seed 1037, 3 bots, 240 s, 28-35 NPCs:
  **frozen 0, clip mismatch 0, no clip 0, static 0**; 1 "slide" = the Longshot's heli_door_idle while its helicopter
  moves (riding: correct). Nothing to fix in D's files.
  **For A (real bug, 21,363 errors in 240 s):** `anim_layers.gd:75` `left_hand_ik.set_target(marker if want else
  left_hand_ik.marker, ...)` passes back a FREED marker once the NPC's WeaponVisual is replaced or freed (dropped weapon,
  swap): "Invalid type in function 'set_target' ... (previously freed)" every frame for that NPC. Fix: use
  `left_hand_ik.marker if is_instance_valid(left_hand_ik.marker) else null` as the fallback.
- **RT prep READY: `origin/prep/d-rt` 83cc1a187** (not merged to env/d-art; D-144). On env/d-art 674681736 + the parked
  wip/d-rt-civilians and wip/d-rt-clips (clean merges):
  - 9 looks rebuilt on the current pipeline (byte-identical to the parked glbs) and assembled: diner_waitress,
    diner_cook (staff_diner), carpark_attendant (staff_booth), street_pedestrian a-f.
  - p5_cast v15: the pedestrians join street_civilian / civ_street / civ_bus / civ_diner (18 looks, 6 per gender
    minimum); diner_staff / carpark_attendant pools and the staff_diner / staff_booth tags.
  - Clips from the parked branch: sit_vehicle, vehicle_exit_l / _r. Fixed a type bug in the parked test_rt_clips
    (an Array assigned to a Dictionary aborted the exit test silently; it now runs and passes).
  - Green in the worktree: d test_p5_cast 17, test_scenes 9, test_lod 6, test_rt_clips 5, test_anims 18. Drape: the
    waitress's dress 5-7 leg vertices through in stride (within D-135's <= 12), 0 in cower / seated; pedestrians a / f 0.
  - Still missing for RT (not in either parked branch): the sit_eat and cook_stove clips (A's HINT_CLIPS already
    names them). About half a D day once the PO picks RT.
  - The existing scenes' CrowdLod `cast_shadow = 0` (D-146) from re-assembly was left out of the prep diff; the
    proxy script sets it at runtime anyway.
  Checks run: gdlint (test_p5_cast.gd, test_rt_clips.gd), the tests above, check_skirt_drape, check_ownership d,
  check_banned.
- **r254 merged** (9d2e85d8) into env/d-art 396312586: import clean; d test_character_warm 2/2, test_of_cast_clips 3/3.
  Queue now empty on my side: waiting on GPU-12/13 (hitch log, shader-cache test) and A's CharacterWarm call. Open to
  the next item (OF/PO polish, or the next heist's cast once the PO picks).
- **Character render-warm for the OF loud hitches (for A to call):** `game/world/characters/character_warm.gd`
  (class_name `CharacterWarm`, D-owned):
  - `CharacterWarm.heist_cast_paths(heist) -> PackedStringArray`: every p5_cast look of the heist (pools + tag_map),
    existing scene paths, sorted, unique (OF: 30+).
  - `await CharacterWarm.warm(host, paths, frames := 3) -> int`: draws each scene once off-screen (a SubViewport that
    shares the main World3D, the main viewport's AA settings, the real sun, plus an omni with shadows for the
    positional-shadow variants), full meshes then CrowdLod proxies, then frees everything; returns looks drawn.
  - **A's part:** at heist load (load screen), `paths = heist_cast_paths(heist)` + every EnemyDef the director can spawn
    there at the run's difficulty via `NpcVisuals.def_scene_paths(def, difficulty)` (police, specials, `_duty` and
    faction variants), then `await CharacterWarm.warm(runtime, paths)`. GPU-12's hitch log then shows whether the first
    -spawn hitches are gone.
  - Test `game/tests/d/test_character_warm.gd` (2 tests green): the OF list, and warm draws each look once and frees.
  - Wave framing: close-ups now also need clear lines to the head and hips and try 1.4x the distance (routine_unit3's
    door). A re-run of job 1 is optional.
  Checks run: gdlint (character_warm.gd, test_character_warm.gd, render_d145_wave_review.gd), d test_character_warm,
  check_ownership d, check_banned.
- **GPU-8 review** (origin/gpu/renders gpu/renders/d/*):
  - **QC-67 CLOSED:** queue/qc67_log.txt: the queue customer (bank_customer_d at CustomerQueue1) plays `queue_idle_b`
    (the queue_idle variant group); queue_w_side.png shows him at the mark. The 4 tellers play teller_count (r249 PASS).
  - **D-145.3 wave:** the log is the proof: Routine 4/4 units `patrol_officer_duty`, Hazardous 0/6 `_duty`
    (patrol_officer, tac_light_frd, longshot: armoured, as D-145.3 wants). Framing fixed: close-ups now take the first of
    8 directions with a clear line both ways to the unit's chest (no more sky / ground / door / bollard frames). Please
    re-run job 1 (same command) for clean close-ups.
  - **Faction lineup:** reads right: each duty look drops the carrier and helmet for the soft cap and keeps its faction
    colour and back mark (FRD letters, Sentinel hex, Zero mark). The sheet canvas now matches the pool (no empty columns);
    a re-run is optional.
  - **VIP walk:** the long coat hangs fine mid-stride (sheet tile 2); the higher inside-out count is not a visible defect.
    No change.
  - **OF loud perf** (RX 9070 XT): total 1,580-2,708 draws, under D-146's 4,000; frame avg 16-20 ms, but **every loud view
    has a 87-115 ms worst frame** (GH quiet: max 16-22 ms). The cast is ~1,200 draws loud; "cast casts no shadow" takes
    2,637 -> 1,459 (its cost is mostly shadows of the full-mesh guards, units keep full meshes to 25 m). Per-NPC numbers
    are noisy (one customer at 906): positional shadow maps re-render only on change, so toggling a body skews them.
    **New in heist_cast_perf (this push): the loud wait logs every frame > 50 ms with the NPCs that spawned that frame.**
    That tells A whether the hitches are first-spawn (shader/material compile -> prewarm) or something else.
    GPU job: `godot --path game --resolution 1920x1080 res://world/characters/_tools/heist_cast_perf.tscn --
    --heist=ostrander_federal --loud --view=hall_south_eye` (look for "[CASTPERF] hitch ..." and "loud wait: ...").
  Checks run: gdlint on render_d145_wave_review.gd, render_d130_cast_review.gd, heist_cast_perf.gd; check_ownership d;
  check_banned. Tools only.
- **Next-heist cast notes (notes only, D-144):** `game/assets/characters/_review/next_heist_cast_notes.md`.
  Rolling Thunder: Vaultline / Halden / escorts (duty looks automatic) exist; parked wip/d-rt-civilians (diner staff,
  attendant, 6 pedestrians, built not assembled) and wip/d-rt-clips (sit_vehicle, vehicle_exit_l/r); missing sit_eat +
  cook_stove (A's HINT_CLIPS already names them) and 2 tag_map rows: about 1 D day. Afterhours: club looks exist but
  pools are far short of D-130 (4 patron looks for 30-50 patrons/dancers, 2 bouncers for up to 7, 2 bartenders for 6),
  no tag_map, no dj_mix: about 2 D days. Cast-side view: RT starts faster.
- **r252 merged** (e91fa3c0, OF final art) into env/d-art 22fbee3e: import clean; d test_of_cast_clips 3/3 and
  test_cower_offsets 2/2 still green on the final art (seats, worktops, cower walls unchanged for the cast).
- **OF clip audit: PASS, new test** `game/tests/d/test_of_cast_clips.gd` (3 tests, green on env/d-art = r251 + D). For
  every OF CIVILIAN / GUARD SpawnPoint in the built map (variant slots included): the clip its activity resolves to
  (CivilianBrain KNOWN_ACTIVITIES, else idle; then HINT_CLIPS) exists in char_anim_humanoid with every variant-group
  member, loops, and moves (a bone differs between 1/4 and 3/4 of the loop: no frozen pose); every seated clip has a
  map `Seat` within civilian_seat_radius_m on its floor; every teller_count spawn stands behind a TellerWorktop
  (top 1.00 m, near edge 0.20-0.40 m ahead). Sensitivity: with the edge window at 0.25 m and the motion threshold
  raised, both checks fail. Not duplicated: A's HINT_CLIPS / KNOWN_ACTIVITIES key tests, C's queue-mark test.
  Checks run: gdlint (test file), d test_of_cast_clips, check_ownership d, check_banned.
- Waiting on your GPU box for the 5 command lines below (D-145.3 wave, faction lineup, VIP walk, queue re-check,
  heist_cast_perf). No local renders meanwhile.
- Next-heist cast notes only (D-144): none started; I'll draft them here if you want them, else I take OF/PO polish.

## 2026-10-21: GPU-box queue for the LEAD (cross-session messages to the LEAD are refused: untrusted device)
Run from the repo root on env/d-art 5f7778a2 or later; OUT = any output folder. Send back the output paths.
1. D-145.3 GH loud wave, Routine vs Hazardous (no --fixed-fps; waits for the director's own units):
   `godot --path game --resolution 1280x720 res://world/characters/_tools/render_d145_wave_review.tscn -- --out=OUT`
   -> OUT/d145_wave_sheet.png, d145_wave_{routine,hazardous}_{group,unit0-3}.png, d145_wave_log.txt (unit look ids;
   `*_duty` on Routine = no armour).
2. Faction duty lineup (offline): `godot --path game --script res://world/characters/_tools/render_d130_cast_review.gd
   -- --pool=d145_factions` -> _review/d145_police/d145_factions_*.png
3. VIP walk sheet (offline): the same script with `-- --pool=of_vip` -> _review/of_d1_cast/of_vip_*.png
4. OF queue-customer re-check: `godot --path game --fixed-fps 60 --resolution 1280x720
   res://world/characters/_tools/render_of_qc67_review.tscn -- --out=OUT --no-alarm` -> OUT/queue_w_side.png,
   OUT/qc67_log.txt ("queue ..." lines: each queue_idle customer's clip).
5. heist_cast_perf (5f7778a2): glasshouse views, `*_loud.png`, per-view frame time (avg / max ms over --frames=N,
   default 120, + GPU name). UNVERIFIED by a run here (a headless GH smoke run timed out before measuring; gdlint
   clean): treat the first GPU run as its test. OF after C's cuts: `-- --heist=ostrander_federal --shadows-only
   --view=rc_hall_entrance,rc_hall_counter,rc_hall_from_gallery,hall_south_eye`; GH: `-- --heist=glasshouse --detail
   [--loud]`.

## 2026-10-20: resumed (lead session_014E3p2DmSYTneJjytGwKKfc); OF-D1 QC-67, D-145.3 faction duty, OF cast perf
### Done
- Re-orientation: long-gun grip below 2 mm (P's test_p_finger_clip: every gun < 1 mm) and the SMG re-time were already
  on trunk; D-145.3 police / specials duty looks (f23a384a, 4e62aaef) were already on env/d-art.
- **QC-67 windowed** on C's OF map: `_tools/render_of_qc67_review.tscn` (tellers both sides of the counter, queue
  customers, alarm + the 5 cower points; `--no-alarm`). All 5 cower points are 0.21 m in front of their ledge / wall /
  pillar face (cower_stand's authored distance); the back-bag offset (cower_offsets.json) applies in game. Teller
  placement matches teller_count (worktop 1.00 m / 0.30 m vs 0.28 m). Two activity bugs found and fixed by A: HINT_CLIPS
  alias `teller_count` (fbbe47ed, r246) and CivilianBrain.KNOWN_ACTIVITIES `teller_count` / `queue_idle` (r249).
  Evidence `_review/of_qc67/` (b796da07, 3fe9a7ab).
- **Faction duty looks** `char_tac_light_{frd,sentinel,zero}_duty` (1ea150dd, r247): the duty look in the faction's
  colours and back / chest / arm marks, no helmet decals, no Zero pauldrons or skull mask (`_faction.dress` keys on
  `armored`); characters.json `variant_of: tac_light`, `variant: <faction>_duty` (A's resolver tries `<faction>_duty`
  first on Routine / Tense, 684889cf). test_outfits covers them (chest gap vs the armoured faction look, no faction
  helmet / mask on Headwear); existing looks rebuild byte-identical.
- **OF cast perf** (`_tools/heist_cast_perf.tscn`, `--detail`, `--shadows-only`, `--view=a,b`): pre-r245 hall 6,052
  draws (sun shadows = 73 %); r246 12,885 (6 spot + 1 omni shadowed lights added; shadows = 79 %; cast casts no
  shadows -17 %). Numbers sent to C for D-146. Write-up: `_review/of_cast_perf/of_cast_perf_audit.md`.
### In progress
- Shadow breakdown per light kind on C's rc_hall_* views (320x180: draw counts are resolution-independent).
- Teller + queue re-capture on r249; D-145.3 GH Routine vs Hazardous wave side-by-side
  (`_tools/render_d145_wave_review.tscn`); faction duty lineup (`render_d130_cast_review.gd --pool=d145_factions`).
### Gotchas
- After a trunk merge, `godot --import` BEFORE any windowed run (new class_names otherwise fail to resolve).
- OF on r246+ is ~12k draws: llvmpipe needs 320x180 for perf measurements and ~1 h per heist capture at 960x540;
  keep each background command under the 2 h limit (one step per command).
- `pkill -f <pattern>` matches the calling shell when the pattern is in its own command line: build the pattern
  from two strings.
### Ready for integration
- yes (env/d-art head)

## 2026-10-17 (OF-D1): Ostrander Federal cast + clips
### Done
- **VIP pair** (rare `vip_client`): `bank_vip_client` (camel overcoat, silk scarf; correction 2026-10-20: no attaché was modelled) and `security_bodyguard`
  (Halden close protection: charcoal suit, earpiece, Halden pin). Halden guards g-j added: ten faces, a-j.
- **D-130 pools sized for an L heist**: tellers `npc_bank_teller` a-e, officers `bank_officer` a-d, customers
  `bank_customer` a-j + `civilian_customer_a/b` (twelve faces). New materials: char_skirt_navy, char_knit_mustard,
  char_coat_heather, char_coat_stone and char_canvas_tan. `p5_cast.json` v9 adds `tag_map.ostrander_federal` (the spawn
  tag -> ids map for A), checked by test_p5_cast's `test_of_tag_map` and the OF pool rows (no twins, gender minima).
- **Clips** for the gaps the OF audit found: `queue_idle` / `_b` / `_c` (variant group), `counter_customer` and
  `check_desk_write` (`_anim_bank.py`, test_bank_clips). The skirt looks pass check_skirt_drape and check_seated_clip.
- Review: `game/assets/characters/_review/of_d1_cast/`, `game/assets/characters/_review/of_d1_clips/`.
- Manager name **Lionel Ashgrove** (`bank_manager`) confirmed and sent to B.
### In progress
- QC-67: teller_count / cower placements, once C's OF G1 is on trunk.
### Blocked
- —
### Questions for lead
- `docs/design/heists/ostrander_federal.md` roster: `guard_vip` is now `security_bodyguard` (it was `security_officer_b`),
  `civ_vip` is `bank_vip_client`, and the guard pool is a-j. The manager tags are assumed to be
  `civ_manager_mgr_floor|gallery|vault`. characters.md needs the new clips and looks.
### Ready for integration
- yes

## 2026-10-17 (final, 11:07 UTC): D-135 closed: dress drape + seated re-check; QUEUE CLEAR (6316e628)
- **Long-dress / skirt knee clipping** fixed for all 12 looks (9 dresses, 3 skirts). Method: STRIDE_DRAPE weighting
  (each panel on its thigh, then the shin past the knee) plus knee slack 1.8 cm; the dress/skirt cloths are
  double-sided. Checker `_tools/check_skirt_drape.gd` + test_skirt_drape. Legs through the skirt, worst frame:
  56-145 before, ≤ 12 after (0 in cower/sit). Review `_review/d116_dress_drape/`.
- **Seated re-check** on C's chair Seat (z −0.12, a13f5735): the backrest clip is gone (body on all 5 sampled NPCs,
  outfit on 4; dock_worker's hi-vis vest grazes 2.4 cm, and DB workers don't use these chairs).
- **Civilian panic** wired by A (61b70043); the GN coverage shows cower/b/c and flee/b/c in use, and panic_start plays.
  `_tools/render_crowd_scatter.tscn`, `_review/d116_crowd_scatter/`.
- Open: D1 parked for the PO GPU run. Nothing else carried.

## 2026-10-17 (end): QUEUE CLEAR for the Ostrander Federal start (PO directive 08:40)
Done since the last entry (all on env/d-art, head at this commit):
- **D-132 D1** (per-node material merge) is PARKED on origin/wip/d-d1-merge (2dbd1772; LEAD ruling, D-132 addendum 2).
  Every acceptance item has evidence, but on llvmpipe it saves GN -32 % / loud -12 % draws for +29-45 MB VRAM and
  +~194 MB of meshes. It waits on the PO's real-GPU run: `_tools/README_bench.md` (bench_crowd --preset=both, D1 off
  on env/d-art vs on on the wip branch).
- **SL late_staff** looks npc_km_assistant / npc_km_associate (p5_cast v8; A mirrored). The seated check found that
  C's prop_chair_office / prop_chair_task put every desk_work NPC's back through the backrest; C is adding a
  `Seat` 0.12 m forward on both chair props in all heists. Tool: `_tools/check_seated_clip.gd`.
- **3P loud motion coverage**: `_tools/loud_anim_coverage.tscn`, a headless HeistLauncher run with P's AnimCoverage.
  DB + GN at 300 s: no clip defects, no slides. A has the driver flags (melee mismatch, frozen loops, revive with no clip).
- **turn_l_45 / turn_r_45** (467f0dfb) and **door_kick_<fam>** (ed9a3b5f, impact@75 = npc_door_breach_s): v1.28.
  A wires the driver side.
- **Civilian panic variety** (1aa5eb8f): cower_b/c, flee_b/flee_c, panic_start (idle f0 → cower f0) and
  variants.cower / variants.flee; test_civ_panic. A wires the variant groups; the LEAD writes the v1.29 line.
- `bench_crowd --preset=gn34|loud50|both` + VRAM; `_tools/README_bench.md`.
Open, waiting on others (not D work):
- Seated re-check with check_seated_clip on one NPC per heist, after C's chair Seat lands.
- GN crowd-scatter before/after capture, after A wires the civilian panic groups.
- D1: the PO's GPU run.
Seen, not started (no new scope): long-dress skirts (gallery_patron_d and probably the other dress looks) open up
with the leg showing through when the knees bend in stride / crouch / cower. The seated-drape method (v1.24) could
be extended to it. Raise it again when scope opens.

## 2026-10-17 (later): D-130 cast pools, crowd-LOD fix, DB-4 verified, D-130 perf audit, D-132 D2
- **D-130 pools** (a04f3536, 48a7cc3a; p5_cast v7). GN guards 9 (it already twinned at 5); SL Northgate 9; ND Halden 6;
  SL cleaners 4; ND cleaners 2; GN patrons 12; GN waitstaff 3 and attendants 3 (C's gala_extra). Mirrored by A
  (b6d115f9 + the gala pair pending). Review `_review/d130_cast/`.
- **Crowd LOD shirt bleed** (1b375cb9): CrowdLod drops/tucks LOD2 vertices covered by another surface (4 cm along the
  normal, same facing), so shirts no longer show through jackets at range. All LODs regenerated.
  `_review/lod_review_shirt_*`.
- **DB-4** verified in-game (278dc464, `_review/db4_sit/`). C note: the PF ForemanChair is too close to its desk.
- **Slung gun** (7dc91bd0): cartel slung looks carry `Skeleton3D/Slung`, which A hides while seated (6193917d). v1.27 (LEAD).
- **Perf audit** (`_review/d130_perf_audit.md`, now docs/art + D-132), tool `_tools/bench_crowd.tscn`. Draw calls
  dominate. D2 (87e7bf4b): LOD2 from 15 m crowd / 25 m units → GN 34 draws 1011 → 738, loud 50 2860 → 2524. D3 is
  folded into D1. A owns the animation LOD.
- **D1 in progress** (lane wip/d-d1-merge): Texture2DArray layers + one shader per tier, per-node surface merge.
  Acceptance: 2/10/30 m lineups unchanged.
- Stealth coverage re-run on trunk: clean (54a5c893).
- Gotchas: the test runner hangs on a test-file parse error (LEAD is fixing it); `assert_not_null` doesn't exist.
  `PackedInt32Array` in a Dictionary is a value: write it back after append.

## 2026-10-17: new LEAD session (session_01HwYKRgCdkLfJCt4ZM6rfTk); police combat verified, DB cast to 12, thumb probe
Resumed on origin tip 0e4e2a0f (trunk already merged). Done since the GN-D1 entry, from `git log` (old team, 10-16):
- D-116 organic 3P pass: crew states, mask_on / throw_grenade (lob), carried bag at Back/Socket, FP knife / melee /
  grenade framing, FP akimbo reload, glances + lag on idle/holds, seated drape + sit_chair_read / sit_chair_armed
  (DB-4 clip, v1.24), pistol thumb along the frame (033c1514), frame-locked hold_<kind>_<gait> (a8f4609e, v1.25),
  police combat movement (3ef303da, 21 clips; v1.26 is the LEAD's), DB/SL cast pools (Northgate a-f, cleaners a-c,
  Halden security_officer a-d, cartel a-f), p5_cast civ_worker_packer -> dock_packer (74f15c4c).
This session:
- **Police combat (queue 1)**, verified windowed in lit Glasshouse (`_review/d116_police_combat/`): aim_<fam>_<gait>,
  cover peeks / low cover, stagger, class reloads. Fix (190f40c7): reload_sniper's bolt phase put the right hand on the
  knob, so the 3P gun (at HandR/Socket) pointed at the floor for f50-60. The right hand now stays on the grip and the
  left hand cycles the bolt over the top. ENV A has the anim_driver map (DM, LEAD cc'd).
- **DB-4 (queue 2)**: the clip is sit_chair_armed (v1.24). A's `_ambient_hint` still maps `sit` -> sit_chair; asked A
  to map sit_chair_armed for cartel `sit` posts and armed guards on seats.
- **DB cast (queue 3)** (45894565): cartel_gunman_g..l, so the pool has 12 faces (Cataclysm posts 12; 3 women, 6 slung
  guns), plus dock_worker_c (civ_worker spawns up to 3). p5_cast v5. Review `_review/d115_db_cast/`. A mirrors:
  cartel_gunman.tres visual_alternates, npc_visual_tweak civ_worker. SL already fits its pools (<= 6 guards incl. the
  operator, <= 3 cleaners).
- **FP pistols (queue 4)**: P's PFingerClip long guns are <= 0.9 mm on all 8 (no residuals). New d/test_fp_pistol_thumb
  measures the one-handed firing thumb in the real game pose: the tips are on the frame (gap 0-3.7 mm). On every pistol,
  1-9 web-of-hand vertices go 1.7-4.0 mm into the tang. Thumb angles do not move it; tried in both directions
  (scratch, reverted). Clearing it means lowering the hand seat, which moves P's sights. **QD-1 ruled by the LEAD:** accepted as skin
  compression on a high grip, the seat stays, and the test guards at 4.5 mm.
- Tests: test_police_combat 4/4, test_anims 18/18, test_loco_holds 5/5, test_fp_pistol_thumb 1/1, test_cartel 5/5,
  test_npcs 9/9, test_p5_cast 16/16, test_scenes 9/9, test_lod 6/6.
- Next: SL cast check vs the doc's non-guard roles (IT contractor / Moor / Kessler looks, crowd LODs);
  respond to A's mapping questions.
- Gotcha: `pgrep -f <name>` inside a wait loop matches the loop's own command line. Use `pgrep -f "godot.*<name>"`.

## 2026-10-16: GN-D1 polish (D-115 queue item 3: Gallery Night cast)
- Seven new looks in `char_p5_gallery.py` (crowd LOD2 included, tris 24.4k-31.5k, budget 35k):
  - patrons `gallery_patron_c` (woman 60s, black dress, gold), `_d` (man 30s, all-black dinner suit, open collar),
    `_e` (woman 30s, sapphire satin), `_f` (heavy man 60s, navy dinner suit, wine bow tie), `_g` (woman 40s,
    amethyst satin). With patron/_b and the penthouse guests that makes 9 patron looks (5 women, 4 men) for up to
    9 live patrons;
  - `gallery_waiter` (second waitstaff: wine waistcoat, long black apron);
  - `gallery_conservator` (GN-D-c: knit vest, canvas apron, loupe glasses, staff lanyard; no longer reuses
    attendant_b).
  - New materials `char_satin_sapphire` and `char_satin_amethyst`.
- `p5_cast.json` v4: the gallery_night roles gain `gallery_waitstaff` x2, `gallery_inspector` and
  `gallery_vaultline`; the conservator is `gallery_conservator`. New `tag_map.gallery_night` (spawn tag -> ids)
  is the map ENV A mirrors 1:1 into `NpcVisualTweak.heist_tag_characters.gallery_night`.
- ENV A request (npc_visual_tweak.tres): `civ_admin` -> `gallery_admin` (still `npc_penthouse_guest_a`);
  `civ_attendant` -> both attendant looks; `civ_conservator` and `staff_cs` -> `gallery_conservator`;
  `civ_waitstaff` += `gallery_waiter`; `civ_patron` -> all 9; `guard_inspection` -> guard + guard_b. Hashing the node
  name can still give two NPCs the same look; to avoid twins, A should pick distinct ids per tag.
- Tests: test_p5_cast (+`test_gallery_tag_map`, `test_gallery_patron_variety`) 14/14, test_npcs 9/9, test_scenes
  9/9, test_lod 6/6. Windowed review `_review/gn_d1_cast.png` (`render_gn_d1_review.gd`): the whole cast, idle front,
  mid-walk back, head. The dresses do not clip at the walk frame. Gold satin rendered as canary yellow, so patron_g
  was switched to amethyst.

## 2026-10-15 (later): PO6-18 deaths, PO6-11b pistol support hand, Wasp SMG refit
- **PO6-18** (3fb66f28): death_crouch, death_kneel_cuffed, death_kneel (from surrender f48), death_prone,
  death_downed. Each starts on its source frame and the root stays fixed; checked in test_anims
  `_check_pose_deaths`. Evidence: `_review/po6_18_*`.
- **SMG refit including wasp_pdw** (b33ddb77) on B's 871b6646 finger ridge; P's smg offset is
  (-0.0492, -0.0297, 0.0004).
- **PO6-11b** (8ede90c9): `PISTOL_GRIPS`, fitted against the gun and the firing hand's skin. Evidence: `_review/po6_11b/`.

## 2026-10-15: PO6-09 support hand, SMG re-time, PO6-19 ragdolls (D-114; LEAD session_01XAPqmFJ32zHKLK9Sezymym)
- **PO6-09** (fcd702b7, evidence 6524e268): the "finger detached from the hand" was the support thumb. Rigid hand
  weights kept the whole thumb tube on thumb_01, and thumb_opp -30 lifted it onto the handguard's top edge, away
  from the palm.
  - Fix: `_arms._thenar_blend` (FP arms only; the thumb weight ramps in along the metacarpal) plus every long-gun
    set refitted on all its guns. SupportGrip gains `thumb` and `fingers`.
  - P's PFingerClip worst depth is now ≤ 1.0 mm on all 8 listed guns (it was up to 4.4).
  - test_arms skin check: hull hit + ray parity + 1 mm depth.
  - Evidence: `_review/po6_09/`.
  - ENV P owes in the same merge: the new set_left_hand_grip_offset values (= `SupportGrip.offset`),
    test_p_grip_offset's LONG_GUN_GRIPS, and the hard assert.
- **SMG re-time** (c42b1bd0, after merging origin/env/b-content): the smg left_ik is B's Hornet marker, and
  `LONG_GUN_GRIPS["smg"]` is fitted on hornet, lancet, ferret, hush and mastiff (≤ 0.81 mm). New P offset for smg:
  (-0.0439, -0.0264, 0.0005). The palm-to-marker tolerance for smg is 4 cm (like the saw).
  - Open: wasp_pdw still has a vertical-grip marker in the smg set (lead's call).
- **PO6-19** (6e456fb6): `Skeleton3D/Ragdoll` PhysicalBoneSimulator3D (12 bodies, capped joints, 79.5 kg) on all
  102 characters; the API is in `world/characters/_tools/RAGDOLL.md`. Asks for the lead: name physics layer 11 and
  add contract v1.12.
- Grip-fit tools: scratch Blender scripts (evaluator, PFingerClip-like; fitter: coordinate descent + per-finger
  bisection to contact). They are not in the repo; the method is described above and in `_arms_clips` LONG_GUN_GRIPS.

## HANDOFF 2026-10-14

**Branch head:** env/d-art at the commit that adds this section (on top of 8ac1e97e). It adds this handoff, plus the
shotgun and LMG lit Glasshouse grip captures.

**Done since last trunk merge (not yet on trunk):**
- This commit: `game/assets/characters/_review/grip_glasshouse_{plowman_12,rampart_lmg}_{hip,ads}{,_crop}.png`
  (in-game, Glasshouse, using P's per-set offsets). In ADS the LMG's shroud hides the hand completely; that crop shows
  only the sight. Everything else (51a3ce84 grip, 8ac1e97e Corsair captures, skirt fix 07542fe7) is on trunk as of r202.

**In progress:**
1. **Long-gun support grip (PO spec, `docs/handoff/in_progress.md` §D), about 80%.** 51a3ce84 is on trunk.
   - What it does: `LONG_GUN_GRIPS` in `tools/blender/characters/_arms_clips.py` holds one `SupportGrip` per set
     (along, palm, shift, thumb_opp, ring_pinky, offset). `offset` must equal P's
     `FpViewmodelTweak.set_left_hand_grip_offset[set]`; P landed these in r202.
   - Test: `test_arms._check_support_skin_clear` (skin vs the per-4 mm section convex hull, 2 mm) is green.
   - P's PFingerClip on r202 is stricter (real triangles plus ray parity). Inside vertices / depth: Condor index
     70 / 4.4 mm, Bastion thumb 2 / 3.8 mm and index 15 / 1.9 mm, Corsair thumb 2 / 3.0 mm, Reaper thumb 11 / 1.9 mm,
     Brute 12 / 1.2 mm, Shrike 6 / 1.2 mm, Mule 2 / 0.3 mm, Anvil 0.
   - Why: my grips were tuned on the reference guns in `test_arms.REF_WEAPON` (heron_308, corsair_ar...). The Condor
     and Bastion share a set with those but have different fore-ends.
   - Next step: run P's `test_p_finger_clip` on every gun of each set. Tune the worst gun per set with the Blender
     optimizer (scratch tool, below), moving the thumb a little lower and outward and opening the sniper index.
     Re-run test_arms, then hand P the new offsets. Acceptance: PFingerClip 0 vertices deeper than 2 mm, as a hard
     assert. Not captured yet: the sniper (heron_308) Glasshouse frames, because the run was stopped at the handoff.
2. **SMG re-time for B's fore-end markers, 0%. This blocks B's whole branch.**
   - B's env/b-content f8f17c7a moved LeftHandIK under the fore-end for hornet_9 (Godot (0, 0.016, -0.150)),
     lancet_45 and tern_556. wasp_pdw keeps its vertical grip.
   - d/test_arms goes red on smg_idle / smg_ads_idle (palm 0.052 m off) until D re-times.
   - Next step: merge origin/env/b-content into env/d-art. Set `_arms_sets.py` smg `left_ik` to the hornet marker
     (Blender (0, 0.150, 0.016)). Add an `"smg"` `SupportGrip`, starting from the rifle's (centred markers take the
     long-gun branch in `Kit.__init__` automatically, `abs(left_ik.x) < 0.005`). Tune it with the optimizer
     (`OPT=smg`), rebuild char_arms_fp, run the FP set below, and send P the smg offset. Merge B and D together.

**Queued next:**
1. SMG re-time (above): unblocks B. Lead ruling 2026-10-14: hornet-family gets the same under-fore-end grip.
2. Grip PFingerClip pass (above): the PO's #2 complaint, spec in `docs/handoff/in_progress.md` §D.
3. Sniper Glasshouse grip captures, plus shotgun and LMG again after item 2.
4. GN-D1 leftovers per `docs/process/next_heist.md` §3/§3b (gala clips are delivered; re-check against the contract
   if A asks).

**Cross-env dependencies:**
- B: the SMG markers (f8f17c7a) merge together with the D SMG re-time.
- P: owns `fp_viewmodel_tweak.tres` (per-set grip offsets) and PFingerClip. Every grip change means new offsets for P.
- A: `fp_left_hand_ik.gd` reads `grip_offset(set_id)` (trunk r191 20a4f404).

**How to validate your area:**
- `gdlint` on changed .gd; `python3 tools/ci/check_ownership.py d`; `python3 tools/ci/check_banned.py`.
- FP arms: `bash tools/ci/run_tests.sh d test_arms`; `p test_po4_feel`, `p test_p1_01`, `p test_p1_03`,
  `p test_po4_viewmodel_classes`, `p test_p_grip_offset`, `p test_p_finger_clip` (report);
  `a test_fp_viewmodel`; `b test_pp_left_hand_ik`.
- Rebuild: `python3 tools/blender/build.py --category characters --asset char_arms_fp`, then
  `bash tools/blender/characters/assemble.sh`, then `/opt/godot/godot --headless --path game --import`. Revert the
  unrelated `*_lod.res` churn that assemble leaves behind.
- Windowed: `game/tests/p/_review/hold_capture.tscn -- --out=DIR --weapons=... --heist=glasshouse` (P's). Glasshouse
  runs about 1 fps on llvmpipe, so a full pose set takes about 25 min per gun. For hip + ADS only, force the mask
  (`CrewController.set_masked(true)`) and skip walk/turn/sprint.
- Grip optimizer (scratch, not in the repo): a Blender script that skins the posed Arms, scores finger/thumb
  vertices against the weapon BVH and the same section hull as test_arms, and coordinate-descends `SupportGrip`
  parameters. Rewrite it from this description if the scratch is gone. It uses `CL.Kit.__init__` monkeypatching
  plus `CL.state_fns(sk, s)`, `solver.solve(realize(...))`, `A.apply_frame`, `weapon_of`.

**Gotchas:**
- `test_arms._check_long_gun_support_grip` was defined but never called until 51a3ce84. Check that new `_check_*`
  helpers are actually called (gdlint caps public test methods at 20).
- An AABB section check counts empty corners under round or twin-barrel fore-ends; the convex hull is the right
  test. Mesh signed distance misses fingertips curled into the barrel-underside step (break action).
- A grip's wrist `offset` changes whenever its parameters change; P's tweak must change in the same merge.
- Never commit P's `fp_viewmodel_tweak.tres` from env/d-art (ownership), even when it is patched locally for captures.
- Masks: after any crew head change, regenerate `_crew_face_envelope.json` and refit every mask in the SAME commit.

**Your session id:** session_01EZDt9WkE187YkB8ANEbuhb

## 2026-10-14: seated deaths (D-110, lead-approved)
- `death_seated_slump` (48 f, impact@22) and `death_seated_fall` (60 f, impact@34) in char_anim_humanoid, built in
  `_anim_d304.py`; SOURCE `seated_deaths` + `death_end_poses`. Both start from desk_work frame 0 on the npc chair and the
  root never moves. Slump: head and right forearm on the desk top, hips on the seat. Fall: tips off the chair's left side
  onto the floor (hips 0.5 m, head 1.1 m left), clear of the desk top. test_anims `_check_seated_deaths` (in
  test_d304_polish_set). Windowed Godot evidence: `_review/seated_deaths_windowed.png`. ENV A picks the clip (lead routed).

## 2026-10-14: skirt fix, FP pistol left hand
- Skirt (`_npc.skirt`; bank_officer, npc_bank_teller, npc_bank_night_manager): the thigh weighting ramps in by
  mid-skirt (0.97 at the hem, was 0.85 reached only at the hem), centre mix 0.03, clearance 15 mm. No more thigh
  poke-through in walk/run/cower_stand (`_review/skirt_fix_windowed.png`). Open, and already there before this fix:
  in seated poses the back hem shows as a thin band between the knees.
- FP pistol: the runtime left-hand IK (FpLeftHandIk onto the Kestrel's LeftHandIK) leaves the support fingers
  sticking out flat beside the slide. With pistol skipped, the clip's grip wraps cleanly
  (`_review/pistol_ads_d/left_ik_on_vs_off.png`). Asked ENV P to add pistol/revolver to left_hand_ik_skip_sets.
- Correction: the FP ADS depth change (423c453b) does reach the game (slide 27→22 px); the forearms still fill the
  frame at the 52° viewmodel FOV.

## 2026-10-14: weapon hold / ADS (PO feedback), skin tone fold
- TP `aim_pistol` (+ fire/reload_pistol via gun_pose): isosceles at near-full reach, grip 0.60 m out (was 0.47) with the
  sights just under the eye line (was chin height), torso lean 6/6, head up. Windowed Godot check with weapons at
  HandR/Socket: `_review/tp_aim_pistol_windowed.png`. aim_rifle unchanged (reads correctly).
- FP pistol/revolver ADS (423c453b): shoulders raised/forward, ads_dist 0.42, IK 0 mm. Clear in Blender, but in game
  the ADS frame barely changes (`_review/pistol_ads_d/before_after_ads.png`): something keeps the pistol's depth fixed.
  Asked ENV P (who owns fp_viewmodel).
- SKIN_TONE_FIX folded into `_body.SKIN_TONES[4]` (cf84264c). Library materials unchanged; the 13 skin-5 glbs still embed
  the old placeholder colour until they are next rebuilt (no in-game effect, the import remaps to library materials).
- Proposed to the lead: seated deaths (`death_seated_slump`, `death_seated_fall`) for the corpse that falls through the desk.

## 2026-10-14: GN-D1 (Gallery Night cast; D-110 re-activation)
- Gala ambient clips: `curator_inspect`, `cower_stand`, `cower_seated`, `walk_text`, `smoke`, `desk_work` all exist in
  char_anim_humanoid and are listed in characters.md (v1.7, v1.9, base list). Review sheet
  `_review/gn_d1_gala_clips.png`: all read correctly. Mapping them is ENV A's job (anim_driver / civilian activities).
- QC-58c admin PA: new `char_gallery_admin` → `world/characters/gallery_admin` (teal knit cardigan, pale-blue shirt,
  charcoal trousers, silver glasses, watch, wine gallery staff lanyard). p5_cast.json gains the roles `gallery_admin`
  [gallery_admin] and `gallery_conservator` [gallery_attendant_b] (QC-58b). test_p5_cast checks it
  (`test_admin_pa_office_wear`). Windowed Godot check `_review/gn_d1_admin_windowed.png` (idle, walk_text, desk_work,
  cower_stand, cower_seated).
- Found: the shared `_npc.skirt` loft lets the thighs poke through in walk/cower (bank_officer_b shows it), so the PA
  wears trousers. Fixing the skirt weights is a follow-up.
- Cast check against gallery_night.md: curator, attendants (+_b as conservator), guards (+_b for operator, upper rover
  and smoker), patrons (+ penthouse guests), waitstaff (npc_penthouse_staff), Vaultline (armored_car_crew) all exist
  and are cast. Inspectors reuse gallery_guard (QC-58d).

## 2026-10-12: session 3g (WIP: TAC Light accent, unverified)
- TAC Light (+ frd/sentinel/zero): matte cream (`char_bank_cream`, albedo ~215) placard bars across the front and back
  plates (`char_police.tac_placard`, TAC Light only; Corpsman not affected). A chest/back bar, distinct from TAC
  Heavy's white shoulders. Tris: base 30,108, frd 31,708, sentinel 30,748, zero 32,320 (budget 35,000).
- NOT VERIFIED: the Glasshouse 10/20 m renders were stopped at wrap-up before writing an image. Next: run
  `render_heist_review.gd -- glasshouse tacl 10` and `... 20` behind render.lock and judge TAC Light vs Bulwark.
- `run_tests.sh d` 115 tests, 0 failed.

## 2026-10-12: session 3f (rechecks; local only)
- ND 20 m on ENV C 6943ce02 lighting (scratch worktree of c/repo with D's current characters copied in):
  `_review/heist_night_deposit_20m_c6943_compare.png` (rows: specials before/after, regulars before/after).
  Now read: Stinger (blue cells), Phantom (green goggles), Longshot (hat + drab), TAC Light (olive-grey helmeted
  rifleman), plus everything that read before. Still weak: Bulwark (dark hooded bulk; it reads in game only by its
  shield, which this line-up does not carry) and TAC Light vs Bulwark without the shield. No accent change needed.
- Anim on env/a-core 7cf4240e (scratch worktree, crew_rook, 3.5 m/s, 60 fps): clips now run_l / run_r / run_b
  (no more forward-run moonwalk); spawn frame 1 = idle with blend 0.00, upper_arm.L 38.7 deg off rest (no A-pose).
  Planted-foot speed metric: run_l 0.62, run_r 0.61, run_b 0.24, forward run 0.50 m/s (baseline); same order as the
  forward run, so no strafe-specific slide; the metric itself is coarse (3 cm stance band).
- FP arms (ENV P report: pistol tilted ~40 deg up-left, wrists through the grip): no P renders in p/renders (empty).
  char_arms_fp: 41 bones, `weapon` child of hand.R present; in pistol/rifle idle the `weapon` muzzle is 2 deg up,
  5 deg left, 3.5 deg roll of camera forward; hand.R axes are 131 deg from the weapon axes; wrist skin: 743 verts
  blended hand.R/forearm.R, 0 unweighted. Verdict: attach the WeaponVisual to the `weapon` bone (contract) and fix the
  pose/IK on the P/A side; no D mesh change.

## 2026-10-12: session 3e (PP-D heist readability + anim; local only, no push)
### Render path (works on this GPU-less box)
`flock /workspace/cnc-team/render.lock xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy --path game
--script res://world/characters/_tools/render_heist_review.gd [-- <map> <tag|-> <dist>]` -> Forward+ on Vulkan
llvmpipe (lavapipe). gl_compatibility + LIBGL_ALWAYS_SOFTWARE=1 under xvfb also works; `--headless` never draws.
Line-up: Spawns marker x 16 yaws scored by clear slots; slots on floor only (down ray within 0.25 m of the marker
floor), 0.35 m standing room, eye->head/chest/knee line of sight; camera aims at the line-up centroid.
Group a (L->R): patrol_officer, security_officer, tac_light, cartel_gunman, frd_agent; group b: tac_heavy, stinger,
bulwark, longshot, corpsman, phantom. Crops: `_review/heist_<map>_<d>m_crop.png` (top a, bottom b).
### Readability misses (idle_alert, FOV 75, 720p)
| map | d | does not read | reads |
|---|---|---|---|
| Night Deposit | 10 m | - (all read) | all |
| Night Deposit | 20 m | tac_light / stinger / bulwark (same brown-black under sodium light); longshot (hat only), phantom (green goggles only) | patrol stripes, security shirt, cartel, frd shirt, tac_heavy shoulders, corpsman |
| Night Deposit | 40 m | everything but security shirt (dark fence backdrop); 3 of 6 slots clear | security_officer (faint) |
| Glasshouse | 10 m | bulwark vs tac_light in the alley shadow | rest |
| Glasshouse | 20 m | bulwark; only 3 slots clear (narrow alley) | patrol, security, tac_light shape, tac_heavy, stinger blue |
| Glasshouse | 40 m | not testable: 2 slots clear (alley) - coverage gap | patrol, security |
| Dockside Burn | 10 m | - (fog washes legs, classes still read) | all |
| Dockside Burn | 20 m | stinger / bulwark / longshot in fog | patrol, security, cartel, tac_heavy, corpsman, phantom goggles |
| Dockside Burn | 40 m | all but patrol stripes + security shirt (fog) | patrol, security |
Cause: lighting/fog (ENV C) plus near-black kits; per lead, accents untouched. Known script limit: the line-of-sight
rays ignore vehicles without collision (ND 40 m: one unit behind the parked car).
### Anim (item 2)
- Spawn A-pose blend and >2.2 m/s strafe/back moonwalk were ENV A (anim_driver.gd); fixed by A in c9d4dd98, checked
  in a scratch worktree (see report). An `autoplay idle` try on the D side broke 4 D tests (mask seat, portraits) and
  was reverted. LOD switches mid-fight: no pop issue found (proxy shares the skeleton, weapon stays on HandR/Socket).
### D rows for playability_pass.md
- PP-D-1 LOD pop / skinning: PASS (anim_lod_*.png, fp_pop_*.png). D-080, D-084 in.
- PP-D-2 class readability 10 m: PASS on all three maps.
- PP-D-3 class readability 20 m: FAIL ND + DB for tac_light/stinger/bulwark/longshot (lighting + dark kits; C first).
- PP-D-4 class readability 40 m: FAIL ND + DB (all but patrol/security); GH not testable (no 40 m sight line).
- PP-D-5 spawn A-pose / foot slide: A-side fix c9d4dd98, verify on trunk after merge.

## 2026-10-12: session 3d (TAC Heavy accent; local only, push after round 34 + Aaron's approval)
- TAC Heavy (+ frd/sentinel/zero): shoulder trim is now matte white `char_glove_white` (albedo ~208; the metallic
  `char_aegis_steel` rendered dark without reflections), trim layer 0.92 of the plate, upper-arm plates also white.
  Reads clearly on both shoulders in fp_30m and fp_40m (720p). Tris 31,630-32,786 / 35000 (base 31,630, frd 32,590, sentinel 31,950, zero 32,786). Security officer left as is.
  `run_tests.sh d` 115/0.

## 2026-10-12: session 3c (D-084 self-subscribe; local only, pushes need Aaron's approval)
- CrowdLod subscribes itself: every proxy carries `_tools/crowd_lod_proxy.gd`, which creates one
  `/root/CrowdLodZoom` watcher (`_tools/crowd_lod_zoom.gd`). It calls `CrewView.local_view()` and connects
  `zoom_factor_changed(f)` -> `CrowdLod.apply_zoom_all(tree, f)`; re-checked when a CrewView enters the tree (spawn),
  reset to 1x when the view leaves; late-spawned proxies get the current zoom. No CrewView class / `local_view` /
  signal = no-op (P's b0fceb0c not on trunk yet). Test `test_crowd_lod_subscribes_to_zoom`; `run_tests.sh d` 115/0.
- Accent check at 720p (fp_30m/fp_40m): Corpsman white shoulder caps read clearly at 30 and 40 m. TAC Heavy steel
  trim reads at 30 m, faint at 40 m (mid-grey on near-black). Security white cap band does not read at 30-40 m
  (a few pixels); the light-blue shirt already carries that silhouette. Possible follow-up: brighter TAC Heavy trim.

## 2026-10-12: session 3b (lead rulings D-080, D-084, accents)
### Done (pushed to origin/env/d-art at 4cc3d516)
- 12bc7737 D-080: specials (char_specials.py) keep LOD0/1 only: no CrowdLod, 22 `*_lod.res` removed (LOD res now
  9.1 MB total, was 13 MB); new `test_specials_have_no_lod2`. Closes issue 3 (Corpsman cross).
- 65289015 accents (issue 2): TAC Heavy steel pauldron trim (`char_aegis_steel`, override `shoulder_accent`),
  Corpsman white shoulder caps (single plate, keeps the 35k tri budget on frd/zero), security officer white cap band.
  All faction variants rebuilt; char_tac_heavy rebuilt twice, byte-identical. fp_30m/fp_40m re-rendered.
- 35015f0e D-084: `CrowdLod.zoom_factor_of(view)` (reads `zoom_factor`, default 1.0, clamp >= 1),
  `apply_zoom(character, zoom)` / `apply_zoom_all(tree, zoom)` scale the switch (CrowdLod begin + glb ends) by zoom;
  proxies are in the persistent `crowd_lod` group. Hook for ENV P (CrewView, per frame or on zoom change):
  `CrowdLod.apply_zoom_all(get_tree(), CrowdLod.zoom_factor_of(self))`. Test `test_zoom_scales_crowd_lod_switch`.
- Issue 5 (skinning): `anim_lod_{walk,run,aim_rifle}.png` (top LOD0, bottom forced CrowdLod, mid-clip): the
  skinned proxy follows the pose with no explosion or stretched verts. No fix needed.
- Issue 6 (scope): `scope_40m.png` at 40 m, FOV 75/4: top (zoom ignored) shows CrowdLod, so the far model comes from
  the visibility ranges (camera distance), not mesh LOD; bottom (apply_zoom 4) shows LOD0. Fixed by D-084 once wired.
- D-084 input check: no InputEventMouseMotion / `.relative` in any D-owned file; nothing to change.
- `run_tests.sh d` 114 tests, 0 failed (test_lod 5/5).

## 2026-10-12: session 3 (targeted tests only; lead runs check_all)
### Done (local on env/d-art; push blocked by GitHub 403 for every env, see lead)
- D4-01: D-080 is not in docs/decisions.md, so specials keep the current CrowdLod approach; 13 MB `*_lod.res` kept as is.
- Mask polish (8fa5d3e1): serpent gets a sharp chevron hood crest + keel scale (5610 tris); moth gets thicker antennae
  (spine 3.6 mm, barbs 15 mm, 8 barbs), bigger wings, raised eyespots and veins (7891/8000 tris, width inside
  the 0.30 m test limit). Rebuilt twice, byte-identical. test_masks 9/9; `run_tests.sh d` 112 tests, 0 failed.
- PP-D-1 review renders: `_tools/render_fp_review.gd` -> `game/assets/characters/_review/fp_{10,20,30,40}m.png`,
  `fp_pop_crowd.png` (18.5 vs 21.5 m), `fp_pop_unit.png` (33.5 vs 36.5 m). Eye 1.65 m, vertical FOV 75 (assumed
  default), 1280x720, real visibility ranges (nothing forced).
### PP-D-1: art playability issues (first person)
1. Size: a 1.78 m character is ~95 px tall at 10 m and ~25 px at 40 m (720p). Past 30 m faces and badges are gone;
   only body colour and silhouette tell roles apart.
2. Dark-on-dark: tac_heavy, corpsman and security_officer trousers/armour are near-black; against dark level
   backgrounds the armed units lose their silhouette past ~30 m. Proposal: a lighter shoulder/helmet accent on armed units.
3. Corpsman red cross becomes a red patch at CrowdLod (open since session 2); it is the specials telegraph.
   Waiting on D-080 (specials LOD0/1 only); kept as is for now.
4. LOD pop: fade is disabled (opaque pass, by design), so the switch is a hard cut. At 20 m (crowd) and 35 m (units)
   the change is small (slight loss of hair and hand shape, no colour shift). Low priority; 1 m hysteresis holds.
5. Skinning at distance: the renders are rest pose only. The CrowdLod skinned proxy under a playing clip is not
   reviewed yet. Next: animated render at 20-40 m.
6. ADS: zoomed FOV = fov / magnification, so a 4x scope shows a 40 m CrowdLod at 10 m size. Needs a
   magnification-aware LOD bias (camera, ENV A/P) or larger switch distances. Not yet rendered.
### Next
- Animated CrowdLod render (issue 5), then the ADS render (issue 6). D4-02/D4-03 stay paused (D-076).
### Ready for integration
- needs the lead's check_all run

## 2026-10-11: session 2 (new account), IN PROGRESS
### In progress (resume here)
- D4-01 LODs: `game/world/characters/_tools/crowd_lod.gd` + `assemble_characters.gd::_add_crowd_lod` write
  `Skeleton3D/CrowdLod` (one merged skinned surface, `<id>_lod.res`, material `world/materials/char_crowd_lod.tres`)
  for crowd NPCs (switch 20 m) and armed units (35 m); glb meshes get `visibility_range_end`. LOD1 = Godot auto LOD.
  Assembled (99 scenes, 81 with CrowdLod, re-run byte-identical). `game/tests/d/test_lod.gd` added; the glb-part
  tests skip CrowdLod; `run_tests.sh d` = 112 tests, 0 failed. Review: `game/assets/characters/_review/lod_review.png`
  (top LOD0, bottom LOD2) and `lod_review_30m.png` (render script `_tools/render_lod_review.gd`).
  Found: `ARRAY_FLAG_COMPRESS_ATTRIBUTES` makes the skinned proxy render exploded, so it is off; `*_lod.res` = 13 MB in total.
  Open: the Corpsman's red cross shrinks to a red patch on LOD2 (maybe leave specials with telegraphs at LOD0/1).
- NOT PUSHED: full check_all has not been run on this state (wind-down). Resume: `tools/ci/check_all.sh --env d`
  (restore docs/levels/*/validation.md afterwards); if it prints PASS, push env/d-art; then write the final D4-01 entry.
- D-076: D4-02 / D4-03 paused (not started). Mask polish and touch-ups not started.

## 2026-10-11: HANDOFF (session moving to a new account)
### Done since last entry (all on env/d-art, check_all --env d PASS at e528d192, round-31 trunk merged)
- D-067b dedupe (inherited scenes of the glb, `remove_armature`), D-073 mask fit to the crew face envelope
  (`tools/blender/masks/_crew_face_envelope.json`, 0 poke-through), hair + female-face passes, heister portraits.
- D3-01..04 (anims: 100 clips incl. 8-way walk/run, starts/stops, hit reacts, deaths, crawl), B4-12/15/18,
  D-075 (ostrander_federal, bank_officer, club_bouncer pager role), QC-70 bouncer belt radio.
- 31dfc99b: assembler reads outfit-measured `attach_Head/Back/Hip` (model point) from SOURCE.txt; 98 scenes re-seated.
- 3c2a46a6: heister touch-up (matte skin roughness 0.66 / specular 0.35, tone-5 fix, Dutch beard in Hair, Rook
  pocket square, Odile crown with strand UVs; envelope + 23 masks regen; portraits re-rendered).
### In progress / half-done local work
- None. The tree was clean at handoff; nothing unpushed.
### Queue (lead build order)
1. D4-01 LODs: 3 levels (~100/45/15 % tris), visibility ranges, crowd-friendly lowest LOD, contract node paths identical.
2. D4-03 heisters Juno (emerald #2F5D4A moto jacket, knee boots), Ash (burnt orange #B4532A racing jacket, hood),
   Hale (steel blue #3E5872 puffer gilet, 1.88 m), Vesper (cobalt #2B3F8C cape-coat, silver pixie): FP sleeves,
   portraits, envelope + mask regen; keep clear of interactable cyan / loot highlight; ids + accents + portraits to ENV B.
3. D4-02 crowd variety: +8 outfit variants and a GameRng mix table.
4. Mask polish: serpent (sharper hood crest), moth (thicker antennae, bolder wings).
5. Touch-ups: put SKIN_TONE_FIX {5: "#704D3A"} into `_body.SKIN_TONES[4]` (glb placeholder colour); Rook's coat chest
   welt lands under the long-coat lapel (`_npc.jacket`); Odile is at 34838/35000 tris (little headroom);
   remove leftover "Meridian" comments (`_outfit_palette.py` ~160, `_anim_p5.py` docstring, `anim_humanoid.py` ~112).
### Notes for the next session
- Build with the single-thread Blender wrapper (`blender --threads 1`; multithreaded tangents are nondeterministic).
- check_all --env d takes >10 min; run it in the background with a long timeout; restore docs/levels/*/validation.md after.
- Merge trunk with `-c merge.autostash=false --no-autostash`; always check `git diff --cached --name-only` before committing.
### Ready for integration
- yes (e528d192)

## 2026-10-11: session 1, continued (P3 + D2 batch landed)
### Done (all on env/d-art, check_all --env d green at 4616b1b)
- P3: special models (TAC Heavy, Phantom, Stinger, Bulwark + shield, Aegis, Wrecker 3 head states, Longshot,
  Corpsman, Brandt), special anims (kick, shield walk/bang/idle, heal, dozer walk), cartel gunmen x3 (QC-36).
- FP: 16+ weapon sets (pistol..minigun, akimbo, revolver, shotgun_box, batch-3), melee knife/blunt/blade,
  throwable, deployables, gun bash; lengths data-driven (D-063 ratio rule), order-preserving key scheduling.
- D2-01 faction reskins frd/sentinel/zero + frd_agent; D2-02 heist NPCs per ENV C casting (Halden/Northgate
  guards, cleaners, IT contractor, Helena Moor, Kessler robe/coat) + NPC anims (desk_work, phone_seated,
  sit_chair_watch, mug, mop, sit_bed_read, idle_thug); D2-03 crew heisters Rook/Sable/Dutch/Wren.
- Polish: skin/lips/beard shadow, feminine head + Odile v3, determinism root cause (Blender multithreaded tangents,
  build with --threads 1), mask bases x10, contact portraits.
### In progress / next
- D-067(b) scene mesh dedupe: prototype verified; waiting on ENV C `export_armature_object_remove` option in
  tools/blender/lib/export.py (requested via lead), then one migration commit.
- Female-face pass on _head.py, then rebuild female characters + Odile/Moor renders.
- FP sleeve variants per heister (fp_sleeve in crew SOURCE).
### Blocked
- Dedupe migration on the ENV C export.py change.
### Questions for lead
- See messages: contract proposals for NPC clip names, item anim_set fields, viewmodel near plane 0.02 m.
### Ready for integration
- yes (4616b1b)

## 2026-10-10: session 1 (D1-00 v2, D1-01, D1-04 done; D1-02/03/05 in progress)
### Done
- D1-00: officer style-sample renders v1 (3 styles, 677fdc8); v2 GSR after the lead review and the D-035 lock (d93751f):
  `docs/art/style_samples/a_gsr/officer.png`. head.py/officer.py: rounded facial planes, jaw/neck/collar
  separation, tie knot under the collar. b_noir/c_photo stay at v1 (stopped per D-035).
- D1-01 (be6a818): `tools/blender/characters/_rig.py` (52 contract bones, A-pose, `joints()`, `hand_frame()`),
  `_body.py` (parametric body, shape keys build/gender/age, deterministic skin weights, `body_rings`/`landmarks`
  for garments), `body_base.py` -> `char_body_base{,_heavy,_fem,_old}` (16.6k tris, byte-deterministic).
  Test: `game/tests/d/test_rig.gd`. Review: `game/assets/characters/_review/bodies.png`.
- D1-04 (3059886): `tools/blender/masks/_mask_base.py` (mask base-shape generator) + `mask_gilded_heron`
  -> `game/assets/masks/mask_gilded_heron/mask_gilded_heron.glb` (5.9k tris, pivot at the face centre, -Z forward).
  Test: `game/tests/d/test_masks.gd`. Review: `game/assets/characters/_review/mask_gilded_heron.png`.
### In progress
- D1-02 outfits (security officer x2, civilians x5, patrol, TAC light, crew x2) + `char_*` material library.
- D1-03 humanoid animation set (P1 subset + most P2) + `rig_arms` (`char_arms_fp`) with the pistol FP set.
- D1-05 Godot assembly (`world/characters/<id>/<id>.tscn`, `anim_humanoid.res` library "humanoid"), scene tests, lineup.
- Next: a head-quality pass carrying the officer v2 head forms into `_body.py` (current body faces are below the
  GSR bar), then D-034 FP sets (smg, rifle, shotgun, lmg, sniper).
### Blocked
- —
### Questions for lead
- Note for ENV A: Godot ignores glTF default morph weights; the assembled scenes set `blend_shapes/*` explicitly.
### Ready for integration
- yes (D1-00 v2, D1-01, D1-04); D1-02/03/05 not yet.

## 2026-10-10: (not started)
### Done
- Environment created by lead (D-027).
### In progress
- —
### Blocked
- —
### Questions for lead
- —
### Ready for integration
- no
