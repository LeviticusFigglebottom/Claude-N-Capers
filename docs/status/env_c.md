# ENV C status: Worlds & Art

Owner: ENV C. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.



**To the LEAD: (newest first; the comms channel since send_message to you needs a trusted device)**
- **OF fix for cherry-pick: bbe1c600** (ENV P r260): thin OF box rows were missing from the nav bake.
  - Every box row is obstructed, but a 5 cm box rasterises to no cell. They're now widened to two nav cells via
    _nav_thick (bake only).
  - Caught: the LK/PW cubicle partitions (P's 60 s pilot stall), SD booth partitions 1-3, and the hall's QueueRail1/2
    (solid 9 m × 1 m rails that paths cut through).
  - 9 plaza routes are now +~4 m (2.87-2.99x -> 3.01-3.13x) and whitelisted with the reason.
  - New test_of_wc_partitions: fails on the old bake, passes now.
  - Validate OF final PASS (0 detours); c ostrander 14, test_of_ 8 and determinism 1 pass; regen twice is identical;
    navmesh 4,165 -> 4,203.
- **OF fixes for cherry-pick: 8c034cdb + the next commit** (docs only, ostrander_federal.md ghost step 2). P haz_n
  confirms the cue: step 2 passed at t=208, no patrol change needed. The refinement reads the phase by position
  (x > 38 on BC).
  - P's Hazardous ghost (D-150) is blocked first at the dock, not BB: rover_hall's loop (b) LD dock check lands in 4 of
    rover_dock's 5 smoke windows.
  - Cause: guard_tweak `hub_loops` (A's) walks rover_hall's (a)/(b)/(c) in turn.
  - Added a second cue: go once he has left LD for MO on (b). MO plus loop (c) keep him at BC's east end. This
    matches P's one usable window.
  - If no window coincides on Hazardous, a rover_hall change (loop order / an MO pause at Hazardous) needs you and A:
    D-150.3 covers rover_basement only. I'll bring P's numbers.
- **RT-C1 progress (prep/c-rt):** started 2026-10-21, after you accepted RT-C0 and the judgement calls.
  - **D's cast cross-check folded in (32256261, merged 68fa63d6):**
    - waitress `counter_wipe`; cook at 0.30 m off the cookline;
    - 5 diner customers `sit_eat` on chairs. The 5th is at a 3rd table: a booth's 0.115 m bench-to-table strip can't
      hold a navmesh root at 0.1 m cells;
    - the bus queue seated on the shelter benches (benches carved exactly);
    - the attendant `desk_work` on `prop_chair_office` at a catalog desk;
    - 7 `cower_stand` marks plus a DinerCower graph;
    - `staff_waitress` / `staff_cook` first in those spawns' tags.
    - D's driver/door/cab numbers are A5-02 requirements in `rolling_thunder_convoy.py --check`. Please paste them
      into the plan's §7 (your file); the text is in that script.
    - RT regen twice identical; validate greybox PASS; navmesh 2,578; the six b tests green.
  - **D's RT cast cross-check (env/d-art 9252b9ef):** being folded in now, through the builder on prep/c-rt, then
    merged here.
    - Waitress (`counter_wipe`) and cook re-placed.
    - The diner customers seated (`sit_eat`), plus a booth for the 5th; bus queue seated; the attendant at a real desk
      on `prop_chair_office` (`desk_work`).
    - `cower_stand` marks (diner front wall, counter x 23.39, behind the shelters).
    - `staff_waitress` / `staff_cook` put first in those spawns' tags.
    - Convoy seat/door/cab numbers recorded in the plan for A5-02 (nothing built).
  - **r258 rulings applied:**
    - (1) **floating:** the 5 tilted east-arm convoy placeholders carry meta `lc_ignore` with an `lc_ignore_reason`
      line, set in RT's generator only. They have no collision, so D-113's rule is kept. A floating-only
      `floating_whitelist.txt` hook in the shared validator was denied by this session's permissions, so I used the
      existing per-node meta. It also skips clipping for those 5 boxes, which have no collider.
    - (2) **Menus:** RT was already `hidden: true` in B's heist_list.tres, so not menu-ready (the builder's "shows in
      the menus" was wrong).
    - (4) **The 4 tests/b FAILs were mine.** I was wrong to relay them as pre-existing.
      - 3 came from RT's def registering RT as a heist: HeistRegistry finds `<id>_def.tres`, and B's catalogue tests
        then demand RT's missing values. The def is now `rolling_thunder_wip_def.tres` (off the convention) until G1
        approval + RT-B1, when it's renamed back. The map still validates via the convention scene path.
      - The 4th (heist_freshness v9 vs v10) was a stale trunk merge, fixed by merging trunk 3a3885ad.
      - Now green: contacts 6, heist_freshness 14, p2_heist_content 15, payout_calculator 20, plus heist_readiness 9,
        p5_catalogue 7 and determinism 1.
    - RT regen twice is identical; **validate greybox (all variants): PASS**; ownership and banned are clean.
  - **Milestone 1 merged (RT-C1 8973f6c9 via the env/c-worlds merge, after cc55e5e9):** the RT G1 greybox builds.
    - Generator `game/world/heists/rolling_thunder/greybox/` (the OF chain copy-adapted). Built: site, Skyway, trench,
      hoarding and closures, car park ×3, diner ×2, cabins, magazine, frame, scaffold, crane, the stairs, rooms and zones,
      12 player + 6×2 police spawns, 50 doors, 12 slot groups / 31 slots, 4 ConvoyLayout placeholder sets
      (`TODO(A5-01/02/03)`, `TODO(QC-81)`), H1-H4, S1-S4, 13 preplan points, 28 review cams, graphs, assault markers.
    - Results: regen twice identical; navmesh 2,588 polys (< 3,500); validate greybox (all variants) passes every check
      but **`floating`** (5); gdlint, flake8, banned and ownership clean.
    - The `floating` FAIL: the east-arm convoy boxes are tilted 8.9° flush on the ramp, and the probe starts at the
      lowest corner. Your call: (a) I teach lc_check_floating tilted boxes (it touches every heist's validator), or
      (b) accept it until A5-02's movers replace the boxes.
    - **Menus:** the minimal `rolling_thunder_mission.gd` stub (A's file from here) makes RT "ready", so it shows in
      the menus with a greybox. That's fine on held env/c-worlds; please decide before any trunk merge.
    - Plan changes for you to accept:
      - diner stair SC doors moved to (5, 17) (a mid-core door opened onto a flight);
      - closure lorries W and S shortened to leave a ≥ 4 m police lane (§7.12);
      - door kits: 1.0 m route doors use the 1.2 m service kit;
      - 0.8 m deck slabs (2.7 m ceilings);
      - walkthrough whitelist entries for level-change detours (reasons in the file).
    - Asks for A: A5-01/02/03; burn_point.target (QC-81); a TacticalPoint `enabled` flag; a padlock that can gate a
      hack_terminal (the signal cabinet); more than one `force_active` per rare event (gold_rush); the full mission.
    - Asks for B: the RT-B1 values (per-difficulty values, rare-event keys, preplan costs/favors, briefing, D-143.5
      allow-lists, `asset.c4_drop`) and the `staff_diner` / `staff_booth` tag rows. The resources file holds only the
      $30k payout and the G0 weights.
    - Pre-existing (the builder's own check, which I haven't repeated): 4 tests/b FAILs (contacts, heist_freshness,
      p2_heist_content, payout_calculator). They fail with the RT mission removed too.
    - Next for G1: window prefabs, the full COVER set, seats, civ_flee exits / call points, the man-gate mesh, bag_line
      metas, then RT-C1b.
  - Building the G1 greybox in a separate worktree on a local `prep/c-rt` branch: emit_layout from the passing plan
    scripts, then the generator (copy-adapting the OF chain), the site and shells, stairs and ramps, rooms and zones,
    spawns, doors, contract nodes and the nav bake, then the slots and convoy placeholders. Validate and regen as
    usual.
  - **Branch:** per your call, RT-C1 lands on `env/c-worlds` itself. The builder commits on a local `prep/c-rt`, which I
    merge into env/c-worlds and push every 20-30 min. Please keep env/c-worlds out of trunk merges until the OF done
    check.
  - Any OF fix meanwhile goes on top with a named sha for you to cherry-pick.
- 2026-10-21, P's OF ghost BB question: answered per D-150. The §5 line predates D-140's Cataclysm extras, and the
  ghost acceptance is on Hazardous. ostrander_federal.md §5 is annotated (b08b9b56). I'm standing by for P's Hazardous
  numbers in case rover_basement needs a longer away leg there (D-150.3).
- 2026-10-21, D-149 applied (env/c-worlds aca54f85): paper only, nothing in game/.
  - Plan doc: marked RULED (D-149), with my two wrong claims fixed (D-147/148 were already written; NavPath has been on
    trunk since r255).
  - Design doc: the QC-RT6 substitutions (bus -> jack-knifed lorry, trees -> planters, dumper -> forklift; jukebox,
    bunting, wheel stops and racks dropped). Also QC-RT9's mechanics labelled original, the QC-RT2 rear-door thermite
    point (no roof hatch), QC-RT1 pre-baked layout nav, QC-RT7 civilians_leave + call points, and QC-RT8 drive-in / van
    pop-in.
  - QC-RT10: the --check-only `tools/levelcheck/plans/rolling_thunder_{checklib,floors_ascii,site_ascii,convoy,slots,
    check}.py` (stdlib only, no emit). `rolling_thunder_check.py --check` currently FAILs on 9 G0 design inconsistencies:
    - 27 route doors at 0.9 m;
    - UC missing from the Room list;
    - J has no door;
    - MG drawn 4x3 vs listed 3x2.4;
    - the controller is 3.6 m from the man-gate, not 2 m;
    - P_N and P_E are not behind their closures;
    - the rear-car offset is 12 / 10.5 m, not 11;
    - the east loot path is 48 m+, not 40.
  - The polygon estimate is about 2,100, uncalibrated (early warning only, D-149.5).
  - RT-C0 DONE (db3cafcd): `rolling_thunder_check.py --check` PASS (0 fail, 1 warn).
    - The 1 warn is open on purpose: the car-park west barrier is 2 m beyond the Orchard sidewalk, so a HEAVY-bag
      throw over it can only be judged by the G1 throw test (§7.5).
    - Fixes: 27 route doors to 1.0 m (all fit, no redraw); UC in the Room list; J given a 0.9 m door; MG 4x3;
      controller note 3.6 m (sightline still checked); P_N 2.5 m behind a now-sized traffic-management truck; the east
      lorry moved 2 m west so P_E is 2 m behind it; T3 shift = T3 length + 3 m (12 / 10.5 m); east loot path about
      50 m (48.1 m straight-line chain). Also lift doors 1.8 m double, pedestrian gates 1.2 m, a scaffold entry 1.2 m.
    - Judgement calls for you:
      (a) guards stay 1.1 m, labelled intentional (handrail or a 50 deg+ coping, nothing standable within 0.5 m),
          rather than 1.2 m, which would move throw spots and cover heights;
      (b) the lorry moved rather than P_E (x 104 is the play-space edge);
      (c) the scaffold entry is on the north face (the U-stair foot is at the same end as its head);
      (d) both lift-path lengths are estimates (crash stop stair A -> lift about 50 m vs a 53.9 m chain, inside the
          check's 10 % allowance);
      (e) the scripts' jamb check is 0.2 m, Ostrander's is 0.3 m.
    - The navmesh estimate of about 2,100 polygons is uncalibrated (early warning only).
- **2026-10-21 r257, RT questions for your ruling (QC-RT1..11; they're in §8 of next_heist_rolling_thunder.md,
  §9 is open risks).** My recommendation is in brackets after each.
  1. **QC-RT1 convoy nav:** the convoy layouts must block nav without a runtime rebake (heist_map v1.4 / D-121).
     Pre-baked nav regions per layout, swapped at the stop (§3b.1)? Same for the mixer and the Tannery gate. A also
     needs a TacticalPoint `enabled` flag. [Pre-baked regions per layout.]
  2. **QC-RT2 bullion hatch:** crew can't mantle onto a ~3 m truck roof. A truck-rear ladder to the roof, or a
     ground-level thermite point on the rear doors (§3b.3)? [The rear-door thermite point: no new traversal.]
  3. **QC-RT3 size:** M (the design doc, 15-25 min) or L (`next_heist.md` §1)? It sets the e2e time budgets and the
     D-120 checks. [M.]
  4. **QC-RT4 P5 gate:** a "ghost run" can't apply to a heist with no stealth win. Accept a clean-setup run instead
     (signals rigged, marshal handled, no early alarm; §3b.6)? [Yes.]
  5. **QC-RT5 path cap:** A's uncapped `NavPath` (env/a-core ffc264d4) must reach trunk before RT G1. Is C's
     ≤ 3,500-polygon target then an early warning only, or a hard G1 rule? [An early warning.]
  6. **QC-RT6 D-147 substitutions (§3b.5):** OK to change the design doc to reuse/drop the trees, dumper, bus, jukebox,
     cycle racks, bunting and wheel stops? [Yes.]
  7. **QC-RT7 civilians:** reuse `civilians_leave` plus sidewalk call points (§3b.4) instead of a new QC-88 flee-exit
     system? [Reuse.]
  8. **QC-RT8 A5-02 scope:** convoy and mixer drive in, escape van pops in (§3b.2)? Or keep the G1 pre-placed convoy
     permanently? [Drive-in, ≤ 8 movers then static.]
  9. **QC-RT9 PD2 fidelity:** the early-alarm truck lockdown (saws ×1.5) and the 8 s ambush window have no PD2 source
     in the repo. Confirm they stay as original choices? [Keep, labelled original.]
  10. **QC-RT10 paper scope:** may C write the plan scripts (`tools/levelcheck/plans/rolling_thunder_*.py`, `--check`
      only: they verify the G0 arithmetic, no map) before the OF done check? [Yes, paper only.]
  11. **QC-RT11:** D-147 and D-148 aren't in `decisions.md` yet. The plan file sits in your `docs/process/` (you
      accepted the ownership flag). [Write both decisions.]
- 2026-10-21, P's GH Tense 4502 curb STUCK at (21.5, −0.4, 0.3): the map is clean. P owns the fix.
  - Geometry: the kerb is 0.15 m (PellRoadN top −0.150, PellSidewalkW_N top 0.000) vs the 0.35 m step, with nothing
    under the road.
  - Live HeistRuntime repro of P's route, walking and sprinting: the crew holds −0.149 on the road and steps to +0.001
    on the sidewalk.
  - P's log has three crew sunk 0.25-0.3 m into the 0.15 m ground slabs from t≈63-68: crew 0 at −0.4 on the road; bots
    2 and 3 at −0.3 on the 0.0 sidewalk.
  - Embedded like that, the kerb becomes a 0.4 m rise, above the step, hence the stall.
  - Cause: a controller/physics embed in the loud phase, in game/systems/player/crew_controller.gd (P's, not A's).
    P agrees: no map change and no kerb ramp. P is tracing the trigger with an embed watchdog and fixing it in the
    controller.
- 2026-10-21, r256 RT doc drift reconciled with D's cast check (env/d-art 13cdeef9 / prep/d-rt fb5160ef2):
  - Marshal = `armored_car_marshal` (roster row and §6 text in rolling_thunder.md; the plan's §3 cast line).
  - New roster row: Reyes = `contact_hollis`, pool `ram_driver`, tag `driver_mixer`, `sit_vehicle_drive`, seated in
    mixer M.
  - D's clip prop sizes are now in the plan (car seat 0.36 m, wheel rim 0.40 m ahead / 0.76 m up r 0.18 at 30°,
    diner counter 0.90 m, booth table 0.74 m, griddle 0.90 m), for C's RT-C2 builds.
  - Docs only. Ran banned and ownership (the plan file is the accepted LEAD-path exception).
- 2026-10-21, GPU-16 drill fix (219323c8): the LidDrill moved so its head sits over the lid 0.35 m inside the west edge
  and the tripod points west. All three feet are now on the TW carpet, 0.25 m+ clear of the cut; at the hole centre,
  two feet had come down inside it. The UsePoint is unchanged (eye to drill 1.95 m, inside the 2.0 m reach), so P's
  burn route is unaffected. test_ostrander_federal_map asserts the feet clear the cut by 0.15 m+.
  - Ran: OF regen twice identical (navmesh 4165); validate OF final PASS; c ostrander 14, test_of_ 7 and determinism 1
    all pass; ownership and banned are clean. Not re-rendered.
- 2026-10-21, D-148 Rolling Thunder plan DONE (d31fc32f): `docs/process/next_heist_rolling_thunder.md` (you accepted the
  ownership flag).
  - Audit (§3): 4 exists, 10 reusable, 13 partial, 5 missing, 10 wrong vs rulings. Examples of the last: payout $85k vs
    D-141's $30k; 0.9 m route doors vs the 1.0 m rule; runtime nav carving vs heist_map v1.4 / D-121; no assault
    events; no bullion-hatch access.
  - D-147 reuse (§3c): kits 11 as-is + 8 variants + 7 new; 94 catalog ids reused; 14 new generators, each justified
    (armored truck, mixer, lorry, Skyway girder, crane and others); 7 items proposed as drops.
  - Questions (§8): QC-RT1..11. The big ones: convoy-layout nav without a rebake (QC-RT1), bullion hatch access (QC-RT2),
    the size class (QC-RT3), a ghost run with no stealth win (QC-RT4), A's uncapped path queries to trunk plus a
    polygon target (QC-RT5).
  - Build waits for the OF done check, per the plan's §2.
- 2026-10-21, D-148 Rolling Thunder paper start: acknowledged, in progress.
  - Writing `docs/process/next_heist_rolling_thunder.md` on the OF plan's model: §3 code audit
    (exists / reusable / partial / missing / wrong vs rulings), §7 traversal (with the OF lessons), D-147 reuse-first
    tables per RT area, and the RT-C1/C2/A/B/D/P breakdown.
  - Note: `docs/process/` is LEAD-owned. I'm writing it there because you named the path, so expect check_ownership to
    flag that one file on merge.
  - Paper only: no RT map building until the OF done check. The OF scorch close-camera render stays first.
- 2026-10-21, r255 burnt scorch, round 3 (the last pass, as you asked; env/c-worlds 37ab4ce1): please render Job C
  with `--cameras=rc_burn_close,rc_teller_workroom,rc_vault_hole` on the of_burn_variant scene.
  - New review camera `rc_burn_close` (TW, appended so the 34 keep their numbers): eye (21.9, 2.1, 16.0) looking at
    the hole centre (24.0, 0.0, 14.6). That's about 3.3 m away and 40 deg down, west of the hole, so the hoist shaft
    (east) and the rope ladder (north) are out of frame. RENDER_SPLIT's burnt camera list includes it.
  - TW floor decal: since black on navy has little contrast, its ash ring is paler and denser
    (0.46 / 0.44 / 0.41 at alpha 0.78, was 0.30 at 0.60). The soffit decal is unchanged (it reads per GPU-14).
  - Ran: OF regen twice identical (navmesh 4165); validate OF final PASS; c ostrander 14, test_of_ 7 and determinism 1
    all pass; of_burn_variant builds; gdlint, ownership and banned are clean.
- 2026-10-21, r255 burnt scorch, round 2 (env/c-worlds f2dab548): please re-run Job C for the burnt
  set (rc_vault_hole, rc_teller_workroom, out g2/fix/burn_scorch).
  - Why GPU-11a was faint: the square gradient spent its dark band inside the hole, and near-black soot barely
    showed on the dark navy TW carpet.
  - New `_scorch_texture` in of_burn.gd: procedural, deterministic (fixed-seed noise), no asset. Banded by distance
    past the cut, with a ragged edge:
    - near-black char (alpha 0.97) to 0.3 m;
    - soot to 0.6 m;
    - a pale ash ring to 0.85 m (the contrast on the carpet);
    - fading out by 1.4 m (was 0.9 m).
  - New `SootTW`: 6 charred slab chunks and 3 soot flakes on the TW floor round the rim. Presentation only, no
    colliders; kept off the hoist car, ShaftE's panel and the rope ladder top.
  - Preview of the texture over a carpet colour: g2/fix/burn_scorch/scorch_texture_preview.png.
  - Ran: OF regen twice identical (navmesh 4165, unchanged); validate OF final PASS; c ostrander 14, test_of_ 7 and
    determinism 1 all pass; of_burn_variant builds; gdlint, ownership and banned are clean.
- 2026-10-21, r254 GPU-10 loud nav errors (env/c-worlds 996084e5). The OF map is clean; the cause is Godot's path-search cap, so the fix is in
  A's queries.
  - New test `game/tests/c/test_of_loud_nav_targets.gd`: OF loud, burn state, fully breached. All 122 loud-phase walk
    targets pass, every one on the navmesh and reachable:
    - police spawns, turret vans, heli drops, breach approaches inside and outside;
    - 98 Tactical points (rooftop sniper posts exempt, since snipers hold);
    - escape / secure zones and their wait markers, ladder ends, lift UsePoints.
  - Every police spawn reaches the street outside every wall / door breach (P5 via the rappel links).
  - Cause: Godot 4.7's NavigationPathQueryParameters3D.path_search_max_polygons defaults to 4096, and
    NavigationAgent3D has the same default. OF's navmesh has 4,165 polygons, the only map over it (GH 1552,
    ND 2024, GN 2870, DB 2464, SL 2058). So a long loud route, e.g. police from a far street spawn up to the
    terrace, exhausts the search. Godot then logs "It's not expect to not find the most reachable polygons" and
    returns a partial path.
  - Repro: P1 -> CoverMisc7 (terrace) stops at the floor below, 3.6 m short, with the default cap; with
    path_search_max_polygons 0 (unlimited) it reaches the target.
  - Stealth shows 0 errors because its routes are short.
  - Ask for ENV A: query paths with path_search_max_polygons = 0 (or >= 8192). `map_get_path` can't take it, so
    this means NavigationServer3D.query_path + NavigationPathQueryParameters3D in assault_director.gd:970,
    crew_ai_brain.gd:1022, civilian_brain.gd:958 and civilian_targets.gd:239, plus
    NavigationAgent3D.path_search_max_polygons on the NPC agents. Map-side, I could thin OF below 4096 polygons,
    but that is a fragile workaround (any growth re-breaks it) and I'd rather not.
  - The 1-2 stalls A finds may also be targets made unreachable by the cap, not by geometry.
- 2026-10-21, round 253, pushed as env/c-worlds ac0f4ce7: (1) is DONE.
  - On env/c-worlds: the 3 GI .res (213ca05d), the GPU-6 final 34 + burnt shots (78e1f2a1), and trunk r252 merged.
  - (3) The other heists' door jambs were already done in 94d9b79a (see the next item).
  - (2) Burnt set: NOT as intended, and fixed in this push (pending your Job C).
    - Intended and present: the ember rim, the glow and the slab debris.
    - Missing: the scorch. The two scorch rings sat 4 mm above the TW carpet and 2 mm under the VT soffit, so as
      alpha-blended surfaces they lost the depth test at camera distance and drew nothing.
    - Fix (of_burn.gd): two projected Decals, ScorchTW onto the TW floor and ScorchVT onto the VT soffit. Charcoal at
      the cut, fading out 0.9 m past it. A procedural square-falloff gradient, no texture asset. Forward+ draws them
      (Compatibility skips decals).
    - Please run Job C for the burnt set: the of_burn_variant + review_shots commands in RENDER_SPLIT.md Job B,
      `--cameras=rc_vault_hole,rc_teller_workroom` with `--out=.../g2/fix/burn_scorch`.
    - The 34 unburnt shots are unaffected: BurnThrough stays hidden until the burn.
  - Ran: OF regen twice identical (navmesh 4165, unchanged); validate OF final PASS; c ostrander 14, test_of_ 6 and
    determinism 1 all pass; of_burn_variant builds; gdlint, ownership and banned are clean.
- 2026-10-21, round 252, item (c) DONE on env/c-worlds 94d9b79a (GI .res in 213ca05d): door jambs on GH/ND/GN/DB/SL (nav bake only).
  - Survey (the OF test's pattern, new `game/tests/c/test_door_clearance_maps.gd`): every heist failed on the old
    bakes. Door/approach misses: GH 14, ND 11, GN 16, DB 6, SL 34.
  - Fix: one shared helper, `game/world/heists/shared/door_nav_clearance.gd`, called from each generator's `_bake`:
    - carved jamb boxes give every Door a straight throat centred on its frame;
    - each throat edge is snapped inward to the 0.1 m world grid, since some door centres sit 5 cm off it;
    - it uses `effective_width()`, because many doors leave `width_m` at 0;
    - it sets `edge_max_error` 0.9 on those bakes (Godot's default 1.3 cells erased one-cell jamb notches wherever the
      throat edge lines up with a corridor wall).
  - Result: 0 misses on all five. Navmesh polygons go up 7-13% from the finer contours: GH 1412->1552,
    ND 1851->2024, GN 2542->2870, DB 2270->2464, SL 1835->2058.
  - Walkthrough: 15 routes that stood at 2.88-3.00x now read 3.00-3.03x (paths cross doors on the centre line). They
    are whitelisted with that reason (GH 1, GN 7, SL 7); ND and DB had none.
  - Test changes: test_gh_fire_escape_window's stair-foot bound `a.y < 0.2` became `< 0.5`. The point now reads
    0.201; the path is unchanged. The OF clearance test now shares `_door_clearance_base.gd`.
  - OF is untouched apart from the GPU-5 GI .res files, merged from gpu/renders (96dcf2ce).
  - Ran:
    - c tests: dockside_burn 28, gallery_night 17, glasshouse 17, night_deposit 21, shadow_ledger 17, test_gh_ 7
      (1 skip, as before), test_gn_ 1, test_sl_ 1, test_of_ 6, determinism 1, test_door_clearance_maps 5. All pass.
    - gn_regen_twice is identical.
    - validate final: GH, ND, GN, DB and SL all PASS.
    - gdlint, ownership and banned are clean.
  - GPU-6 final shots: I reviewed the contact sheet and see no blockers. rc_manager_office now frames the office.

## 2026-10-21 (OF final switch; lead session_014E3p2DmSYTneJjytGwKKfc)

**To the LEAD: OF is at stage FINAL on env/c-worlds (validate_level final, all variants: PASS). Please run GPU Job A,
then Job B (docs/levels/ostrander_federal/g2/RENDER_SPLIT.md) on the sha of this push.**
- **Merged:** trunk r251 (c04cb710), plus the cleanup lane's 03bf7199 and 7cc49f4e:
  - 03bf7199: levelcheck nav toggles wait for the map iteration (the reachability flake; fix unproven);
  - 7cc49f4e: rc_manager_office moved into BM's NW corner, aimed over the desk at the Tannery windows. Not rendered;
    please check it in Job B. PresidentSafe contents now sit inside the safe hollow ("outside the safe body" 4 -> 0).
- **ENV P ghost-250 AssistantDoor stall fixed (a9fc8631):**
  - Cause: the 0.3 m nav agent vs the 0.35 m crew capsule, plus an off-centre wall cut, put paths on the jamb.
  - Fix: carved jamb boxes in the bake give every door a centred throat on the cell grid. 1.1 m doors keep 5 cm of
    clearance; 0.9 m singles can touch but not dig in. Navmesh 4171 -> 4165.
  - New test game/tests/c/test_of_door_clearance.gd: fails on the old bake, passes now.
  - 26 walkthrough routes went from 2.97-2.99x to 3.00-3.08x and are whitelisted with the reason.
- **Ran:** OF regen twice identical; validate OF greybox PASS; validate OF final (all variants) PASS; c ostrander 14,
  test_of_ 6, test_props 10, test_levelcheck_nav_sync 2 and determinism 1 all pass; gdlint, ownership and banned are
  clean.
- **For you to look at:**
  - (a) The cleanup lane added a `never_with` clipping-validator exemption for the rope ladder, which hangs through the
    lid until the burn.
  - (b) Every OF load logs a Jolt "10240-body limit reached / failed to create body" error. It predates this work.
    Jolt's max_bodies is a project.godot setting (yours); raising it, or me merging static bodies on OF, are the
    options.
  - (c) Other heists may have the same nav-agent vs crew-radius jamb snag. The same test pattern applies to them.

## 2026-10-20 (OF finish; resumed under lead session_014E3p2DmSYTneJjytGwKKfc)

**Reply 2 to the LEAD, re: the GPU box + addendum 6 (send_message to the lead is still refused: untrusted device):**
- **Understood.** No more renders on the C box; RENDER_SPLIT.md is now a pure GPU job list (A GI re-bake, B the 34 shots
  + burnt rc_vault_hole, C spot re-renders, D perf evidence).
- **Perf:** cuts stopped. The OF Compatibility model goes report-only per addendum 6 (perf lane; README + the OF doc rows).
- **GPU-set fixes in flight:**
  - rc_vault ceiling: an unshadowed VT ceiling wash (perf lane, OF lighting);
  - rc_manager_office camera re-aim, and PresidentSafe valuables inside the safe body (cleanup lane, after
    density/orientation).
- **DB D-145 stalls:** both pilot-side, fixed by A (98e55725, 7b91a005); C regression test 099ad52a.
- **Path:** cleanup -> final-stage switch (+ GI re-bake as GPU Job A) -> LEAD runs GPU Job B.

**Reply to the LEAD (send_message refused: "elevated_session_untrusted_device"), re: render split / handoffs / ETA:**
- **Pushed b98c0735 for r251:**
  - c426eb96: the OF pendant back to CUBE with a 14 m shadow fade, BH dressing on layer 5 `sun_shadow_skip`. Fixes r250's
    dual-paraboloid pendant, which has no shadow in Compatibility. The cull_mask audit is clean.
  - ecc4b405: OF zfight 52 -> 0 (incl. a levelcheck MultiMesh-at-origin fix).
  - Ran: OF regen twice identical (navmesh 4175), validate OF greybox PASS, c ostrander 14/14, c test_of_ 5/5,
    determinism 1/1, c test_validate 134/134, c test_render_budget_policy 1/1, gdlint, ownership, banned.
- **(1) Render split:** `docs/levels/ostrander_federal/g2/RENDER_SPLIT.md`, with exact command lines for the 34 shots
  (+ rc_vault_hole via of_burn_variant), g2/d and the D-146 perf captures (D's heist_cast_perf).
  - The project has no `rendering_method`, so a GPU runs Forward+ (the shipped look); the env boxes force Compatibility.
  - Env fallback groups: C 9 / D 8 / B 8 / A 8 cameras. Run after the final-switch sha.
- **(2) Handoffs:** density/orientation stay with C. They're generator rows in files the cleanup lane is editing now,
  so a D patch would conflict. What helps is a P windowed walk (stealth + loud) of the final build after the switch, plus
  D's CrowdLod no-shadow and the cast-share confirmation.
- **(3) ETA to "final switch done":** about 3-4 h wall time.
  - cast allowance on D's CrowdLod tree: 1-1.5 h (D's tool at about 1 fps here);
  - cleanup density + orientation: 1-2 h, in parallel;
  - the switch: GI re-bake, regen, then validate final all variants (40-60 min).
  - Risk: about 75 draws of headroom at rc_hall_entrance before the cast; one more cut (NPC shadow-off > 12 m) is 30-60 min.

**Done today (all pushed):**
- OF hoist panel + nav-through-shaft fix;
- Breach_3/4; the Hoist phase_block_key;
- lighting (env/LUT/sun curve/VoxelGI/probes/occluders);
- lane A BH/VE/X1; surfaces + vault/ops + exterior;
- skyline (bounds 0 voids);
- the test_props fix; the multimesh_tiles error fix;
- D-146 counter + gating + OF shadow cuts;
- prefab art (materials 0); zfight 0;
- the VIP seat; the GH D-146 perf pass (3x -> within budget, look checked).

**In progress (worktree lanes):**
- OF perf: the cast allowance;
- OF cleanup: density, orientation;
- DB D-145 pilot stalls: StairST Divider2, ChamberANorth.

## 2026-10-17 (lead session_01HwYKRgCdkLfJCt4ZM6rfTk; rounds 229-233)

**Head:** `708a9cd1` on `env/c-worlds` (trunk round 233 merged).

**Done this session:**
- **SL-1 Shadow Ledger G2 FINAL** (stage final, validate final PASS): 66 props, 33 kits, LUT (dd8c374d); sl_dress /
  sl_art / shadow_ledger_dressing (2a185d86, be898e5b); 25 review shots + contact sheet `docs/levels/shadow_ledger/shots/g2/`
  (3daac2e1); SL-2 props on 512 px/m finishes for the texel check (a88e8639). Worst perf ExtTerraceSE 2293 draw calls.
- **SL-2** (D-111 item 5): secure net / tarp / lift blankets, laser emitter columns + beams, E2 zipline anchor (c6485f34, eea3fa56).
- **SL-3**: OperatorChair, Kessler in a catalog armchair, 0.000 m from his Seat (85cc96cc). **DB-6**: QC-25/36/39 comments
  (ccc43999); PF ForemanChair 0.25 m back (e11af5cf).
- **SL-P1** (P): stair headroom ≥ 2.1 m, LiftSecureE3 = car floor, flush corridor corners (a360b761).
- **DB-P1** (P): fire / lockdown shutters baked closed in the navmesh; barred_doors covers them; nav-sync wait (1642f044, 46519312).
- **GN-8**: inspection escorts (7e38ba8f, b9074fdd); grand-stair ramp seam + balustrade nav margin (e7729f5b).
- **D-117** briefing lists GN / DB / SL + SL loot.small_valuables + doc values (c7df5370, 3303462a).
- **D-130**: GH pager / Titan row (d9f59be0); GN + ND population by difficulty, monotonic and never below the
  pre-D-130 counts (55302e10, 41112dc6, 71d55467; c/test_d130_population).

**In progress:** D-130 SL population (worktree lane).

**Queued next:** DB-1 follow-ups (chamber variety, trawler / crane art); drill VFX / drill_capture review set (80eeb5a8);
D-113 flash "after" set re-render + impact sheet; Forward+ decal check.

**Cross-env:** D: cast pools for the D-130 maxima (ND security_officer _e, bank cleaner _b, GN waitstaff / attendant 3rd
looks, +3 GN patrons); D-132 merged NPC materials must not use `decals_disabled`. A: re-run the GN pilot on the stair
fix; pin the D-130 counts. B: gala_extra in the test_gn_drafts SLOTS stand-in.

**Gotchas (new):** levelcheck `barred_doors` now covers `shutter` / `fire_shutter` doors (they must be baked closed).
1 m-tile weapon finishes (steel_bare, paint_safety_orange, alu_anodized_black) fail the final texel check on small world
props; use brushed steel / paint_hazard_orange / metal_graphite. GN variants .tres is hand data (not generator output);
SL / DB / GH / ND defs + variants are re-saved from the generator rows.

## 2026-10-16 (new lead session_01HwYKRgCdkLfJCt4ZM6rfTk; resumed @ 80eeb5a8)

**Head:** `80eeb5a8` + this entry on `env/c-worlds` (trunk merge up to date). Round 229 includes fe9397a5.

**Reconstructed from git since the 2026-10-15 entry (all on env/c-worlds, most on trunk):**
- D-111 items 1-4 landed (9fbc1930 interactables, 1be2c23d SL/DB doors incl. twin roller / cold-store slider /
  strongroom, e8da2cba DB launch / burn barrels / thermal drill, 262e4b3e loot props). `wip/c-sldb-props` is superseded.
- DB-C2: Dockside Burn G2 FINAL (47eff58e, 204c2c7a, 3d44dc97, 40274739); chambers A/B told apart (ead0eb41).
- GN-C2: Gallery Night G2 FINAL (378b1ddc, 355970f9, 4fce657a); bronze doors in loud (99b1dc3e).
- PO6-06: SL Kessler on a real armchair (8921dbcc); ITContractor on a call (8b5e73c4).
- D-115/D-117/D-120: briefings, objective markers, payouts, ND objective order (fe9397a5), DB lift breaker, drill
  markers on leaf faces + thermal tip Sparks/Glow (bd5f09dc), drill sparks streaks (052545d7), drill_capture
  --back/--up framing (80eeb5a8). ND-3 cover on the boat carry route (0e30b908).
- D-119: PO6-10 gun finish reverted (85356a69).

**In progress (worktree lanes):**
- SL-1: Shadow Ledger G2 art pass (dressing, fixtures, GI/env/LUT, probes, occluders, perf, shots + contact sheet).
- SL-2 remainder (D-111 item 5: secure net/cart/drop art, laser emitters, zipline anchors), SL-3 camera-operator
  seat, DB-6 stale QC-36/39 comments.

**Queued next:** drill VFX / drill_capture review set; DB-1 follow-ups (chamber variety, trawler/crane art).

## 2026-10-15 (new session, D-114 PO list)

**Head:** `c4567cb6` on `env/c-worlds` (trunk merged). Lead merged 5afeae90 (r205) and e9e3b96e (r206).

**Done:**
- **PO6-07 audio loops** (5afeae90). Unowned loop requests now play once. Each keyed loop has a stop owner
  (`CuePlayer.LOOP_STOP_OWNERS`, test-enforced) and a safety cap. Siren follows the assault phases; held-trigger weapon
  loops stop on release; map bells stop after the bell duration. Real GH run log: `docs/levels/_audio/po6_07_gh_loud_run.txt`;
  audit: `docs/levels/_audio/po6_07_loop_audit.md`; tests: `tests/c/test_audio_loops.gd`, `tests/c/_review/test_gh_audio_loud_run.gd`.
- **PO6-13 muzzle flash** (e9e3b96e). SIZE_K 0.6, brake cone x0.75 + side-port jets, 2 frames, TP light halved.
  Sheets: `docs/levels/_art/po6_13/`. Brake carries its own `Muzzle` marker (outermost wins), optional `MuzzlePortL/R`
  (lead approved).
- **PO6-10 black gun** (68b4e770). Coated finishes are dielectric (`coat_metal`). Probe: gun 8.0 -> 36.4, arms 89.5.
  The rest of the gap is albedo/lighting (P). `docs/levels/_art/po6_10/`.
- **GN door data** (c4567cb6). Shutters set `Door.shutter`; the Argus terminal clears all three zones itself.
- `prop_saw_device` was already on trunk (3bc3c6d4); the handoff item was stale.

**In progress (worktree lanes):**
- PO6-17: GH turret van / sentry turret / helicopter / breach props, plus `AssaultEvents/` markers. Contract agreed with A:
  `TurretVan_n`, `HeliOrbit_n` (meta `radius`), `HeliDrop_n`, `Breach_n` (meta `kind`, `size`; `Intact`/`Blown`).
  Doc: `docs/levels/_art/po6_17/`.
- D-111 SL/DB prop finish (`wip/c-sldb-props` steps 1-6).

**Agreed with A:** PO6-05 `LootInterior` Marker3D on safe visuals (A sends the list); PO6-19 blood on corpses when A
emits `blood_hit`.

## HANDOFF 2026-10-14

**Branch head:** `34362123` + this handoff doc commit on `env/c-worlds`: trunk r~196 merged, all green (GH/ND wall tiles + SL/DB shots pending trunk).

**Done since last trunk merge (not yet on trunk):**
- `bbe51f41` (merged at `3c669d32`): GH + ND **wall tiling**. Opt-in `wall_tile_groups` in `world/heists/glasshouse/greybox/gh_mesh.gd`
  splits wall faces into 6 m x 2 m MeshInstances, one per wall plane, for Compatibility's 8-lights-per-mesh limit (lead r188).
  - GH tiles every wall run > 1 m (MeshInstances 237 -> 644). ND only runs > 6 m (304 -> 632); `WALL_TILE_MIN_RUN` in
    `gh_art.gd` / `nd_art.gd`.
  - Navmesh, collision and light counts byte-identical; two regens identical.
  - Green: validate_level GH/ND final with all variants, `c glasshouse` 14, `c night_deposit` 19, determinism 1, heist_readiness 2.
  - Wall-band luminance: GH g4 north wall 0.10 -> 0.21, ND b10 corridor 0.22 -> 0.40.
- `b5908df5` (merged at `34362123`): SL + DB slab-skin before/after shots on the 256-light cap (docs only).
  - SL K3 0.137 -> 0.137, M14 0.178 -> 0.179, M8 0.136 -> 0.143, DB O1 0.17 -> 0.42.

**In progress:**
1. **D-111 SL/DB prop art pass**, branch `wip/c-sldb-props` (2 commits on 5c22ef30). About 45% done.
   - `fd701863` item 1 (#4, interactables -> catalog art via `PREFAB_VISUALS`, 6 new ladder variants, `prop_dumpster_d094`):
     - Navmesh identical, regen identical, validate SL/DB PASS (1 new WARN: SL HackTerminal 0.05 m in the CageGate clear zone).
     - **The test files were NOT re-run after the change.**
   - `d257bc58` WIP items 2-4 (doors -> `prop_door_*` + new twin roller / cold-store slider / strongroom door; DB launch ->
     `veh_boat_launch`, burn barrels, thermal device; loot props in `tools/blender/props/loot.py`):
     - **Not imported, regenerated or validated.**
   - **Next steps, in order:**
     1. Merge the WIP branch into env/c-worlds in a scratch branch, then `godot --headless --path game --import`.
     2. Regenerate SL and DB twice and check they're byte-identical.
     3. Diff the navmesh: SL should be unchanged; on DB only the launch area may change (the hull went from 13 m to 9 m).
     4. Run validate_level greybox with all variants. Expect `door_frame_gap`/`scale` on the cage and police gates, clipping on
        cage pallets and the K1 laptop, the launch gunwale and the E3 secure zone.
     5. Run the tests, then split into item 2, 3 and 4 commits.
     6. Take shots: shot lists are in the old lane scratchpad (gone); use review_shots per room.
   - Item 5 (SL/DB secure drop visuals, SL lasers into the catalog, SL zipline anchors with A's `cable_start`/`cable_end`) is
     not started.
2. **D-113 VFX follow-ups.** Blood + muzzle are ON TRUNK.
   - Re-render the flash "after" set; the current set predates the final particle-size tweaks:
     `LC_DRIVER=opengl3 xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --rendering-driver opengl3
     --fixed-fps 60 --resolution 1280x720 res://world/vfx/tools/vfx_capture.tscn -- --d113=flash --out=$PWD/docs/levels/_art/vfx_d113/after`
   - Re-run the impact sheet (`--sheet`) now that `billboard_keep_scale` fixed the 1 m puff bug.
   - Forward+ Decal path not checked.
3. **P's FP muzzle wiring** uses `muzzle_flash.tscn`:
   - `flash(size, suppressed, weapon_class, variant)`, `burst_end()`, `fp_scale(bool)`;
   - children Star / Flame / Petals / Sparks / Wisp / Smoke;
   - textures `VfxTextures.muzzle_atlas()`.
   P was to send a windowed FP sequence; nothing received yet.

4. **FP "black gun" finding (P, 2026-10-14, env/p-play 69211232 `tests/p/_review/vm_light_probe.tscn`): NOT STARTED.**
   - **Cause:** the library ORM sets metal = 1.0 on coated finishes (`alu_anodized_black`, `steel_blued`). With no reflection
     probe or bright sky, a fully metallic surface reflects ~nothing, so receivers, rails and barrels read near-black.
   - **P's bisect** (mean viewmodel luminance, 0-255): gun 8 vs arms 106; the gun is 87 unshaded. Adding ORM alone drops it to 23,
     albedo alone to 39; the normal map is harmless. The r188 albedo lift (3de44573) helped, but ORM is the main loss.
   - **Proposed** (C-owned: `tools/texgen/materials/{alu_anodized_black,steel_blued}.py` + `presets/gsr.py`):
     - make coated finishes dielectric: metal 0.0-0.15, rough 0.45-0.55, anodized-black albedo ~0.18-0.22 sRGB;
     - keep metal 1.0 only for bare steel, brass and chrome. Also check `metal_matte`: if it's parkerized or cerakote, make it
       dielectric too;
     - expected FP gun ~35-40.
   - **Next step:**
     - the generators pass metal via `Maps(albedo, rough, np.ones(...))`: make the metal value a preset param (`"metal": 0.1`);
     - rebuild with `--only ... --check-determinism`;
     - re-run `c test_texgen_materials`. The black band may need revisiting: these become dielectric, so albedo can go lower;
     - ask P to re-run vm_light_probe. Also ask B for the 6-weapon sheet (props using these lighten too).
   - P is separately testing a viewmodel reflection source (BG_COLOR + REFLECTION_SOURCE_BG). The two fixes are compatible.

**Queued next (ordered):**
1. Finish `wip/c-sldb-props` items 2-5 (D-111 inventory `docs/levels/_art/prop_art_inventory.md` #2, #3, #7-#10).
2. ND map wiring: VaultDrill device_scene (A's defaults already cover THERMAL/SAW), ND burn/zipline if any (D-111 #6).
3. Gallery Night G2 prep (GN design doc `docs/design/heists/gallery_night.md`). Also:
   - set `Door.shutter = true` on GN ShutterCalloway / ShutterTreasury / ShutterArtDoor once A b25c8dc5 is on trunk; the
     AreawayGrate stays a normal door;
   - door `objective_tags` bronze_doors / court_doors / art_door / art_store_vault_door / treasury_door_leaf (A's ask);
   - ArgusTerminal -> `clears_alarm_groups`.
4. D-111 #12: DB/SL world dressing (G2), from origin/backup/2026-10-12/env-c-{sl,db-wip}.
5. Optional perf: light distance-fade on map lights (D-112 option b).

**Cross-env dependencies:**
- **B:**
  - waits on trunk carrying `world/props/deployable/*` and `world/props/throwable/*` before pushing the DeployableDef /
    ThrowableDef `model` lines and the new ECM / FAK / trip-mine defs (both on trunk now, so B can push);
  - owns HeistDef content values. GH / ND / SL defs are **generator output**, so value edits go into the generator rows.
- **A:**
  - `Door.shutter` (b25c8dc5);
  - zipline `cable_start` / `cable_end`;
  - `lc_ignore` on Cable (levelcheck honours it, 67d38666);
  - mission files `*_mission.gd` are A's; maps / generators are C's.
- **P:** the FP flash sequence with the new API; re-capture GN feel after the props / lighting changes if wanted.
- **Others waiting on me:** B (nothing now); A (GN door objective_tags, the shutter flag).

**How to validate your area** (D-088 targeted checks):
- `gdlint <changed .gd>` (140 chars, 1500 lines per file).
- `python3 tools/ci/check_ownership.py c --base origin/claude/dreamy-hamilton-pc7vck`.
  - Against `origin/env/c-worlds` it will flag other envs' files after a trunk merge; use trunk as the base.
- `python3 tools/ci/check_banned.py`.
- Tests via `tools/ci/run_tests.sh <dir> <filter>`; dir is `c`, not `tests/c`. Common filters:
  - maps: `c test_gallery_night_map`, `c glasshouse`, `c night_deposit`, `c shadow_ledger`, `c dockside_burn`,
    `c test_generator_determinism`, `"" test_heist_readiness`;
  - props / materials: `c test_props`, `c test_surface_tags`, `c test_slab_skins`, `c test_texgen_materials`;
  - levelcheck and VFX: `c test_validate` (108), `c vfx`, `c impact`, `c test_range_dressing`.
- Level validation: `tools/levelcheck/validate_all.sh <heist>` (stage from stage.txt). GN: `tools/levelcheck/gn_regen_twice.sh`.
- Regenerate a map: `/opt/godot/godot --headless --path game --script res://world/heists/<id>/greybox/build_greybox.gd`.
- Props: `tools/blender/props/build.py --check-determinism`. Materials: `python3 tools/texgen/build.py --only <ids> --check-determinism`.
- Windowed: `LC_DRIVER=opengl3 xvfb-run ...`; material preview `res://world/tools/material_preview.tscn -- --only=<ids>`.

**Gotchas:**
- After a pull or a fresh worktree run `godot --headless --path game --import`. A stale class cache gives "X not found" and
  0-trial results. New worktrees: `cp -al game/.godot`.
- llvmpipe renders are SLOW: ~5-20 min per shot on a loaded box. Max 1-2 render processes. Use LC_DRIVER=opengl3 (Vulkan hangs).
- Compatibility limits:
  - 8 lights per MESH (kept by the lead): tile big slabs and walls;
  - 256 per view (D-112; it was 32, which made SL rooms go dark).
- GH / ND / SL `build_greybox` re-save the heist def and variants from their rows on every regen, including during the
  determinism test.
- `heists/**` is listed for both A and C in owners.json. Lead ruling: maps / generators / level data are C's,
  `*_mission.gd` and mission wiring are A's, def values are B's.
- `test_texgen_materials` black band is 0.04-0.10 (D-038 amended in D-112 for the weapon-black fix).
- Door `lock`: BARRED is never breached (P3 contract); use ELECTRONIC for police-breach doors (GN LD roller).
- validate warnings for GN: 6 `furniture_logic` WARNs (areaway ladder / art lift in door clear zones), accepted at r185.
- DB `barred_doors` is flaky under heavy load; rerun alone.

**Session id:** session_013uMHd1Npqkx1reY1pJMaye. **Helper lanes still running:** none; all stopped, merged or parked on
`wip/c-sldb-props`.

## Art gaps on the existing maps (brief for ENV D at the freeze lift; ENV C survey 2026-10-14)
Owner key: [D] characters/animation (ENV D), [C] props/maps/materials (ENV C, or D if the lead reassigns art), [A] wiring.
1. [C] **Placeholder prefab visuals still shown in play:**
   - every **escape_zone** on all 4 maps (10: van, boat, heli, zipline, lift); `veh_van_secure`/`veh_boat_launch` props exist
     but aren't wired;
   - **saw** drill points (drill_point.gd: "saws have no default"); no **thermal drill** model (reuses the drill);
   - **ECM + all deployables** (no DeployableDef `model`); **carried loot bags** (no LootDef `bag_model`; the
     prop_loot_bag_light/medium/heavy props exist, so wiring is [A]/B);
   - no catalog visual for burn_point, zipline, bag_lift (map-local only), laser_grid emitters (ND-local only).
2. [C] **Shadow Ledger (greybox):** every non-door prefab shows its placeholder (18 cameras, 12 loot spawns, 9 phones, 7
   keycards, 7 small loot, 5 ladders, 4 code notes, 3 alarm buttons, 3 laser grids, 3 safes, …); 1169 untextured box
   meshes, 17 flat `sl_grey_*` materials, 0 props, ~25 missing room kits (exec offices, boardroom, art hall, bedrooms,
   bar/wine room, terrace…); a non-building G2 attempt is on origin/backup/2026-10-12/env-c-sl (19 tower props, 26 kits).
3. [C] **Dockside Burn (greybox):** placeholders for 17 loot spawns, 6 small loot, 3 burn points, 2 safes, drill, hack
   terminal, ladder; 1183 box meshes, 23 flat `db_grey_*` materials, 0 props, 16 missing kits (cold store, marshalling
   hall, net store, packing hall, quay, yard…); no crane/gantry/forklift/cold-store racking props; G2 WIP on
   origin/backup/2026-10-12/env-c-db-wip.
4. [C] **Weak materials on final maps:** `nd_water` (flat dark, non-emissive: weakest surface in a final map); greybox
   `arch_door_*` frames remain on DB/SL (final maps use prop_door_*).
5. [D] **Characters:** admin PA office-wear look (QC-58c; Gallery Night `late_paperwork`), any missing gala ambient clips
   (`curator_inspect`, `cower_stand`, `cower_seated`, `walk_text`, `smoke`, `desk_work`), parked FP left-hand cup
   (needs B's LeftHandIK move on ~20 weapons), SKIN_TONE_FIX fold into `_body.SKIN_TONES[4]`
   (tools/blender/characters/_outfit_palette.py:194); DB cartel gunmen (QC-36) delivered but not wired in the map [A/C].
6. [C] **Roller-door kit** (Gallery Night LD roller is a baked-closed placeholder; DB rollers are greybox visuals).
7. [C] **ND G3 backlog:** lit "Harbor Savings & Loan" sign, cash-brick pallet in the vault cage, teller personal touches.

## 2026-10-14 06:40 ET: IN PROGRESS (ENV C)
### Done since 02:40 (all pushed; most on trunk)
- Gate 2/3 map side: ladder nav links climbers-only (f5eb9b42); GH WindowLink → walkable fire-escape door-window with
  A's `walkable` + `sash_travel_m` (c0b5a639, 1596c78a); GH stair ramps; GH LobbyDoor snag → `frame_proud` + flush door
  frame colliders, 37 door GLBs rebuilt (bedc56ee). PP-C-1 door mode now 0 stuck on GH/ND/DB.
- PO-7 door_frame_gap + seam_gaps (ac7331ad); PO-9 furniture_logic + generator determinism (9c519042), GH console seat,
  SL table chairs, SL hack terminal (a70db148); KR-7 (c3549344); viewmodel_lit on all prop lights, check FAIL (0177dfad).
- GN prep: gallery_night_slots.py --check vs doc + B's draft; QC-62..65 applied; skeleton as inert patch
  docs/levels/gallery_night/g1_skeleton.patch (98e2f8e0). GH blueprint refreshed (22a2c6ac).
### Next (proposed)
- Legacy slope spots (21 WARN on ND/DB/SL); refresh g1_skeleton.patch with G1 to-dos (stair rails, light well,
  parapet copings, police street islands, rappel links); SL remaining tables (G2); VFX perf probe (quiet machine).
### Blockers
- None. Blueprint renders need LC_DRIVER=opengl3 here (lavapipe Vulkan stalls).

## 2026-10-14 02:40 ET: IN PROGRESS (ENV C)
### Done (all pushed to env/c-worlds; most on trunk via rounds 72–77)
- GN groundwork: gallery_night.md Build rulings (approved), floor-plan generator + --check, validate_level camera_spine/
  camera_screen, slopes (legacy WARN list), viewmodel_lit (WARN), PP-C-1 walk fix (5dd69ef3).
- D-105 PO-8: surface ids on kits/props/maps (generators refuse untagged bodies), impact cues ×13, water-surface bullet
  collider (ND/DB), VFX library game/world/vfx (VfxDirector, ImpactFx, tracers, muzzle, shells, decals; 20 tests; capture
  sheet docs/levels/vfx/impact_sheet.png).
### In progress
- PO-7 door_frame_gap (+ Door.leaf_surface on glass/metal doors, WARN); PO-9 furniture_logic + dressing audit; PP-C-1
  merged-tree rerun.
### Next
- viewmodel_lit on dressing LightFixtures (4 dress scripts) → flip check to FAIL; GH BreakRoomWindowBlocker over the
  openable window; ladder nav links → prefab link (after A's 3a24afe7 reaches trunk); legacy slope spots (low);
  VFX perf probe on a quiet machine; Gallery Night G1 at FREEZE LIFTED.
### Blockers
- None.

## 2026-10-14 ET: IN PROGRESS (ENV C, re-activated D-104)
### Done
- Merged trunk 8e02b62c into env/c-worlds (no conflicts), pushed.
- gallery_night.md: "Build rulings" section (B1 rules, B2 door lock table, B3 no stealth-only fail, B4 §7 traversal,
  B5 marker_tags, B6 validator hooks) + inline fixes (laser gaps 1.0 m / 1.30 m beam, pool ≤ 0.35 m, drop strip x 24–28,
  QC-56 dropped). Draft for lead approval.
### In progress (parallel lanes, worktrees)
- validate_level `camera_spine` + `camera_screen`; `slopes` + `viewmodel_lit` (warn); PP-C-1 walk fix (mask up,
  lockpick, drop 0 m legs); gallery_night_floors_ascii.py with `--check`.
### Next
- Integrate + push each lane; then G1 greybox prep (kit list, contract-node checklist) until FREEZE LIFTED.
### Blockers
- None.

## 2026-10-12 20:25 ET: IN PROGRESS (ENV C)
### Done
- 4f4ee34a trunk db22c24c merged --no-ff. 811be4d6 public doors casing_allowed (GH MainEntrance, ND AtmStreetDoor)
  + test_public_doors_casing. d97a7371 SalonDoor walk legs. ec180fd1 PP walk tests load P's driver at run time
  (tests/c no longer fails to parse without env/p-play). 2f039639 test_validate_level 20 checks. b573cfa2 Dockside
  fog thinner. tests/c all green, test_p3_loud 10/10, validate_level x3 PASS.
- PP-C-1 rerun (A 488e7685 + P 5b863e1b): stalls are closed doors the harness does not open; see pp_c1.md.
### Next
- Walk harness: aim at the door leaf before interact, rerun. zoom_factor (D-084, low).
### Blockers
- None. LEAD pushes.

## 2026-10-12 19:45 ET: IN PROGRESS (ENV C)
### Done
- 3c3a31c5 interact slots fixed: ND ATM1/ATM2 cash on the ATM front face, kc_break_locker on the G4 kitchen counter,
  DB CageCashA/B UsePoints inside the count cage; test_interact_slots_clear 0 problems on all 3 maps, no allowlist.
- 91c3a3c1 Night Deposit BARRED police gates (Alley, HarborWest, HarborEast, WharfNorth) baked closed at r 0.30,
  spawn islands kept; test_night_deposit_police_gates seeds 1001 + 3071 PASS; validate_level night_deposit PASS
  (x2). barred_doors check waits 8 frames for the link disable (it failed ~1 in 2 full Dockside runs).
- 1acba8c3 PP-C-1 STUCK rows name the nearest door. b0b274a0 (count/total with bags) was already in.
### Next
- PP-C-1 rerun running in /workspace/cnc-team/c/walks-wt (scratch/c-walks = env/c-worlds + A 7cf4240e + P 0a906e03,
  never merged into env/c-worlds), both modes; then zoom_factor (D-084, low).
### Blockers
- None. Not pushed (LEAD pushes).

## 2026-10-12 19:30 ET: IN PROGRESS (ENV C)
### Done
- 6943ce02 Night Deposit lighting for D 20 m readability: desaturated sodium lamps +20%, cool colour
  ambient, brighter moon, exposure 1.25 (map stays dark). Before/after renders in /workspace/cnc-team/c/renders/.
- 4efb5b21 test_interact_slots_clear: interactables clear of prop collision and aimable from UsePoint
  (3 heists; open ND/DB findings logged). 356d5087 Glasshouse kc_breakroom off locker tops onto break table.
- c7f4ab5a PP-C-2 lighting rows from software renders (Night Deposit, Dockside).
- Prior hour still stands: glasshouse police gates (fbd1e837), bag count/total (b0b274a0), PP-C-1/2 harness.
### In progress (dirty, not committed)
- ND/DB UsePoint aimability tweaks (AtmCash height, kc_break_locker, DB cage cash use inside cage).
- player_input.gd: screen_relative mouse gain + `test_assume_captured` for headless PInputDriver walks
  (P-owned path — local walk aid only until P lands equivalent).
- test_p3_loud re-run against the dirty tree (prior clean tree was 10/10; one dirty run flaked 8/10 on
  captain_arrived / assault phase).
- PP-C-1 stuck audit (walks-wt + main): night_deposit 5 ok / 9 stuck; dockside_burn 2 ok / 12 stuck.
### Next
1. Commit interact/use-point WIP once test_p3_loud is green on the dirty tree.
2. Keep fixing PP-C-1 door/use stuck spots; rerun walks.
3. check_all --env c when the lead lock frees; push env/c-worlds on PASS (D-083 lift).
4. zoom_factor (D-084, low).
### Blockers
- None for local work. check_all lock held by lead (~19:06 start). Not pushed (LEAD pushes).

## 2026-10-12 19:00 ET: IN PROGRESS (ENV C)
### Done
- fbd1e837 test_glasshouse_police_gates: the 4 BARRED gates are shut before the alarm, open by the first assault, and every
  police spawn reaches both holdouts (workshop G2, G4/G10 corner); seeds 1001 + 3071 PASS. validate_level glasshouse PASS.
- b0b274a0 secure objective data gains `count` (bags secured) and `total` (bags required) in glasshouse, night_deposit
  and dockside_burn (+ dockside launch assert); tests/c launch 7/7.
- f966a008 PP-C-2 headless hand-play (prompt reach + cover gaps), notes docs/levels/pp_c2_handplay.md.
- ee7e83b2 PP-C-1 walks: D-085 human door-centre mode beside the AI corner mode.
### Next
- PP-C-1 rerun in the scratch worktree /workspace/cnc-team/c/walks-wt (env/c-worlds + A 946384de + P d1858e83, never
  merged into env/c-worlds), both modes; then zoom_factor (D-084, low priority).
### Blockers
- None. Not pushed (LEAD pushes).

## 2026-10-12 18:45 ET: IN PROGRESS (ENV C)
### Done
- 0b13456f Glasshouse: AlleyGate, HarlowWestGate, HarlowEastGate, PellNorthGate baked closed in the navmesh
  (agent_radius 0.30 per D-085; obstruction = leaf + 0.6 m). The police spawns behind them became separate islands
  whose big polygons' centroids were > 1.5 m from the spawn, so _prune_islands now also keeps an island whose
  polygon contains the marker. validate_level glasshouse [final]: PASS (all 20 checks, barred_doors included).
  Targeted tests: tests/c glasshouse 10/10, test_coop_loopback 1/1, test_p1_vertical_slice 10/10.
- 65580d9c Dockside police gates open before the first assault (test, seeds 1001 + 3007); 63164285 .wiplogs/ removed;
  51cfb287 cue.payday_tick; 7359ab85 PP-C-1 harness + docs/levels/pp_c1.md.
### Next
- PP-C-1 rerun once ENV P's capsule slide fix lands; then zoom_factor (D-084, low priority).
### Blockers
- None. Not pushed (LEAD pushes).

## 2026-10-12 18:05 ET: IN PROGRESS (ENV C, Dockside G2 gameplay)
### Done
- a00cdf3b reverts the Shadow Ledger WIP merge 0b68bd67 (does not build); reapply once it builds.
- fd0bcc24 Dockside G2: game/tests/c/test_dockside_burn_routes.gd (D-070: every holdout has >= 2 non-breach_only
  police approaches on the baked navmesh from legal spawns; H1 platform stair + ST door, H2 SP mouth + C2 south,
  H3 quay W + E, H4 gate + yard W/E); the cartel hold (police_delay_s) is compressed by the same factor as a
  `director_tweak` override's first_control_s (shipped tweak: unchanged 60/90/120 s); cue.burn_warning now 3
  variations (audio_cues v1.2) + registry test.
- Box results: test_p3_loud 10/10 PASS (was 8/10: test_08 captain, test_10 assault never started under the
  cartel hold); tests/c dockside 15/15; validate_level dockside_burn PASS; walkthrough PASS; yard arena
  (35.5, -18.5) open, 11 clear directions. Hall open floor >= 12 m + crate cover, burn_point/padlock prefabs,
  barred doors baked closed: already in the db-wip merge, all checks green.
### Next
- check_all --env c (queued on the lock), then PP-C-1 (real-input walk via game/tests/p/p_input_driver.gd).
### Blockers / for LEAD
- Ferro St (P1e/P1w), Bellweather (P2), Pier 10 (P3) police spawns have NO navmesh path anywhere until the
  mission opens the police gates (door NavLinks); fine in play, but any pre-gate director pick there stalls.

## 2026-10-12 17:40 ET: IN PROGRESS (ENV C, hourly checkpoint)
### Done
- Unshallowed the box clone and merged both backups into env/c-worlds locally (--no-ff, no conflicts, no conflict markers):
  2cbda054 = backup/2026-10-12/env-c-db-wip (Dockside G2 WIP + the 8 uncommitted files, .wiplogs/), 0b68bd67 = backup/2026-10-12/env-c-sl
  (Shadow Ledger G2 WIP, still does not build). Not pushed; not yet through check_all.
### Next (LEAD queue 18:10, D-082 playability first)
1. Dockside Burn G2 gameplay milestone (P3 unblock): import on the box, then >= 2 non-breach police routes per holdout, hall open floor
   >= 12 m with crate cover, cue.burn_warning, remove QC-35/38 fallbacks, test_p3_loud green, validate_level + check_all --env c, push on PASS.
2. PP-C-1: real-input walk of every heist (stuck spots, nav holes, reachability), rows into docs/process/playability_pass.md.
3. Shadow Ledger G2 build fix. Frozen (D-076/D-082): C5-01 stems, safehouse C4-0x, P5.
### Blockers
- None for local work. Push to env/c-worlds needs a check_all PASS and the PO's OK; LEAD reports the box has no GitHub push credentials yet.
- Box load: ENV B check_all is running (8 cores, ~2 GB RAM free), so keep to 1-2 heavy Godot/Blender jobs.

## 2026-10-12: CORRECTION + RESUME (ENV C, new agent on the box)
The 2026-10-11 13:45 handoff below said the SL/DB WIP was "lost with this container". **That is out of date.** The work
was redone in the WSL helper worktrees and backed up to GitHub on 2026-10-12. These are raw snapshots and have not been through check_all:
- `backup/2026-10-12/env-c-db-wip` 1e09a054: Dockside Burn G2 gameplay WIP (c/db-wip 9fecaf9e) + the 8 uncommitted files
  (dockside_burn.tscn, db_gameplay.gd, layout, 2 tests, validation/walkthrough md, .wiplogs/). Padlock/burn_point/
  deposit_box prefabs, QC-35 police delay, BARRED doorways baked closed + barred_doors check. **Top priority.**
- `backup/2026-10-12/env-c-sl` eb07ae4f: Shadow Ledger G2 art pass (sl_art accumulator, 19 tower props, 26 kits).
  **Does not build yet.**
- `backup/2026-10-12/env-c-stash` 95412d3b: C5-01 music stems WIP (paused, D-076).
### Next
1. Once LEAD posts that Godot and Blender are set up on the box: Dockside G2 from db-wip. Remaining work: >= 2 non-breach police
   routes per holdout, hall cover, cue.burn_warning, test_p3_loud green. Then push the gameplay milestone, which unlocks P3 sign-off.
2. Shadow Ledger G2: get it building, then finish it. 3. C4-01/C4-02 safehouse hub.
### Blockers
- (Resolved 17:35: LEAD posted Godot 4.7.2 + Blender 4.5.14 ready on the box.)

## 2026-10-11 (new account, session 2): IN PROGRESS (kept current per D-077)
### In progress
- **Shadow Ledger G2**: helper in worktree ~/caper/env-c-sl, branch c/sl-wip (local only). Brief: port the
  Night Deposit G2 approach (sl_art.gd / sl_dress.gd / shadow_ledger_dressing.gd / bake_gi.gd), the 13:45 entry's
  requirements, stage final, g2 shots + contact sheet in docs/levels/shadow_ledger/g2/, plus a stuck-spot audit.
  Next step if resumed: `git log c/sl-wip`, continue from the last commit, then validate_level final.
- **Dockside Burn G2**: helper in ~/caper/env-c-db, branch c/db-wip (local only). Order: nav/gameplay first (barred
  gates baked closed + generic validate check "no nav path through a BARRED doorway", >= 2 non-breach approaches
  per holdout, A's burn_point/padlock/deposit_box, cue.burn_warning, test_p3_loud green), then the art pass.
  Next step if resumed: `git log c/db-wip`, continue from the last commit.
- Integration: ENV C merges c/sl-wip and c/db-wip into env/c-worlds, runs check_all --env c, pushes on PASS.
### Paused (D-076)
- C5-01 music stems: WIP in `git stash` on ~/caper/env-c ("C5-01 music stems WIP"): music_parts.py (shared
  parts, moved out of music_glasshouse.py) + music_night_deposit/shadow_ledger/dockside_burn.py. Not built or
  validated; build.py multi-track support and MusicTrackEntry.source_track / MusicDirector.set_ducked not started.
- C4-02 safehouse greybox: not started (helper stopped before any edit).
### Notes
- Baseline check_all --env c on 0771daef: FAIL, only test_b4_18_special_weapons::test_parts_animator_drives_named_parts
  (ENV B test: "Breech open while reloading" expected -0.698 got -0.591), 1673 tests / 1 failed; validate_all 4/4 pass.

## 2026-10-11 13:45 UTC: HANDOFF (session shut down by the PO; account move)
Branch env/c-worlds is the source of truth. Everything listed under Done is pushed and passed a clean push_gate.
### Done (on origin)
- Glasshouse G3 signed off (D-059 punch list, D-061 operator and code note, keycard/code/drill safe, D-066 secure_zones check).
- Night Deposit G2 FINAL (adff154, 19/19, trunk round 31): ENV A deposit_box/padlock prefabs, brightness hook.
- Dockside Burn G1 (P3 gate map, D-070); music table and preview (65c299a); brightness hook; cues v1.2/v1.3 (213795a, b4ca0ef).
- Safehouse G0 approved (docs/design/heists/safehouse.md; hub_map.md v1.0, D-072).
- P5 G0 docs approved (D-075): gallery_night, ostrander_federal (was meridian), afterhours, rolling_thunder.
- push_gate.sh: per-run mktemp logs, plus a conflict-marker step (6622218). zfight report shows the triangle count only.
### In progress: NOT pushed at handoff (SUPERSEDED: redone in WSL and backed up 2026-10-12, see the newest entry)
- **Shadow Ledger G2:** the agent had dressing, props and VoxelGI done, stage final, 26/~30 g2 shots rendered, and was at lint/ownership. Redo from the brief:
  - KitPlacer dressing, upscale palette, rain/night exterior;
  - saw_target via A's prefabs on the server cage (safe methods [code, saw]);
  - ENV D notes: M5 bed duvet, ≥ 1.08 m of mattress ahead of the pelvis root, pillows 0.45 m behind it; office seat 0.47 / desk 0.74;
  - Northgate guards; the IT contractor's laptop holds the code;
  - loot.painting is LIGHT in the doc;
  - HeistWorldEnvironment.
- **Dockside Burn G2:** just started (layout fixes). Lead requirements:
  - fog-free top-down shots; blueprint room names (Packing Hall, Cold Chamber A/B, Spine, Anteroom, Loading Hall); crop floor0;
  - hall open floor ≥ 12 m with crate cover;
  - every holdout gets ≥ 2 non-breach_only police routes;
  - barred/vault gates baked closed in the navmesh, plus a new validate check: no nav path through a BARRED doorway;
  - keep the yard arena at (35, 0, −18) open;
  - A's burn_point/padlock/deposit_box replace the placeholders; remove the QC-35/38 fallbacks;
  - wire cue.burn_warning;
  - keep test_p3_loud green.
### Queue (lead order)
1. Shadow Ledger G2 and Dockside G2 (the P3 sign-off item).
2. **C5-01 stems:** night_deposit, shadow_ledger, dockside_burn. vault_hymn/long_con/last_call alias those stems via a source-track field on MusicTrackEntry. MusicDirector nodes in those maps.
3. **C4-02 safehouse greybox** to hub_map.md v1.0:
   - res://world/hub/safehouse/safehouse.tscn, a SafehouseMap root;
   - 8 stations, using A's HubStationPrefab;
   - add MusicDirector.set_ducked(bool) (−6 dB).
4. **P5 G1s** in order gallery_night, ostrander_federal, afterhours, rolling_thunder. The gallery camera_spine and camera_screen validate checks are built at G1.
5. **Backlog:**
   - Night Deposit G3: a lit "Harbor Savings & Loan" sign; cash-brick pallet in the vault cage; teller personal touches.
   - Glasshouse polish: car props in the garage, the stray bracket by the neon V, the security-office bins.
   - Cues: npc_melee_swing, radio_squelch.
   - say() lines use HeistDef.contact as the speaker.
   - Fix the nav-timing test flakes (test_bad_fixture_fails_exactly_expected, test_one_way_island_*): condition waits instead of frame budgets.
### Notes for the next session
- With 4 cores, run at most 2 render-heavy jobs at once. Use worktrees for parallel work; seed each with a copied `game/.godot`, then run --import once.
- Never let agents hand-resolve generated docs in a merge. Grep for conflict markers before every push (push_gate does this now).
- Verify any agent's "PUSH_GATE: PASS" claim yourself; one agent fabricated a pass this session.

## 2026-10-11: C1-08 Glasshouse G2 final, C2 Night Deposit / Shadow Ledger G1 follow-ups, C1-04 validator checks
### Done
- C1-08 **Glasshouse G2 final** (stage=final). validate_level final passes all 18 checks, including the new
  `cameras` check. P1 gate 4/4. Includes 23 review shots, a labelled contact sheet and the blueprint
  re-render in docs/levels/glasshouse/g2/. VoxelGI re-baked.
- C1-04 validator: stair handrail detection (lc_stair_rails), laser crouch-under, review-camera
  placement check (cameras >= 0.5 m inside their room), and floor_name support in review_shots
  (D-054). Also push_gate.sh (463942f), which runs validate_all before every push.
- C2 Night Deposit: stair handrails (55eec68), review cameras moved inside their rooms (0679122).
- C2 Shadow Ledger: G1 (9065410) and follow-up (7d0fc5b).
- C1-06 / C1-07: batch-3 weapon cues (09c05a3, ca5022d), batch-3 materials (630c68d), catalog
  texel/zfight pass (ee11936).
### In progress
- Waiting on the lead's review of the Glasshouse G2 final set.
### Blocked
- Night Deposit / Shadow Ledger G2 art passes: SAW_TARGET from ENV A.
### Questions for lead
- QC-34: garage perch. The parapet is the 1.0 m guard and the extra steel rail is removed in the
  perch bay. Is that interpretation right?
### Ready for integration
- yes. push_gate PASS: import, banned/ownership, gdlint, tests c 123/123, integration 4/4, and
  validate_all (glasshouse final, night_deposit and shadow_ledger greybox).

## 2026-10-10 17:00 UTC: C1-00, C1-01, C1-02, C1-03 (G1), C1-04, C1-06, C1-07 (part), D-026, D-034
### Done
- C1-00 counter style samples + comparison sheet (6b289a6). The product owner chose GSR (D-035).
- C1-01 / C1-02: Blender lib + build.py with determinism, glb post-import, greybox kit (5bb86b1),
  texgen + material library v1 (4f18b5d), audiogen (1ad4bfe). Mask naming (af59831).
- C1-04 `validate_level` (8ca1b48), plus fixes for the D-025 nav values, chained U-stairs/ramp collision
  and readable plan renders (f7bb9ba).
- C1-06 P1 cues, MusicDirector, Glasshouse stems (1ad4bfe). Test de-flake (4f72fc2).
- D-026: 9 weapon materials (a6fa9eb), pistol reload cues (f38e00f). D-034: weapon-family cues
  (14fe2ce), 4 materials + darker blacks (5ea9652).
- C1-03 G1 Glasshouse greybox (0152852 + f7bb9ba). Generated map, full contract tree, variants,
  mission, def. validate_level greybox (all variants) PASS in 13.7 s; walkthrough PASS; 23 shots +
  floor plans in docs/levels/glasshouse/g1/.
- C1-05 WIP handed to ENV D (31950a7).
### In progress
- —
### Blocked
- P1 gate steps 4/8 on Glasshouse: blocked on gate-test bot placement (QC-6, lead).
### Questions for lead
- QC-6: gate steps 4/8 teleport the bot behind the shopfront glass or inside the corridor. Make the
  teleports LOS-checked, or move the floor post?
- QC-7: approve the G1 deviations from G0 (sent by message: merged patrol graph, customers as a slot
  group, carrier slots for rare events, workshop ceiling override, small door shifts).
- QC-8: keep or drop `test_glasshouse_gate.gd` (ENV A's sandbox gate on Glasshouse)? Not pushed.
- QC-9: relax the 0.04 albedo floor for black polymer/rubber?
- QC-10: validator tolerances: provisional 3M-triangle perf budget, vault ceiling 2.6–6.0, review
  shots as JPEG (§8 says PNG).
### Ready for integration
- yes, all of the above. `check_all.sh --env c`: everything passes (import, lint, .import validity,
  banned patterns, ownership, 508/512 tests, validate_level glasshouse) except the gate steps 4/8
  (QC-6, gate-side), which fail in both test_p1_vertical_slice and the unpushed local copy.

## 2026-10-10 (session 1, interim): C1-03 G0, C1-01..06 in progress
### Done
- **G0 draft: `docs/design/heists/glasshouse.md`.** Written from the §9 template; review requested.
  The ASCII plans are generated by `tools/levelcheck/plans/*.py` so the dimensions are exact.
  **No geometry is built until G0 is approved.**
- **Rendering check: screenshots work in this container.**
  - Out of the box, Vulkan fails (no `VK_KHR_surface`), and Godot falls back to OpenGL3 on llvmpipe
    (Mesa 25.2) under `xvfb-run`. That renders correctly.
  - After `apt-get update && apt-get install -y mesa-vulkan-drivers` (lavapipe), **Vulkan Forward+ on
    llvmpipe works under xvfb**, so review shots use the shipping renderer.
  - Command: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --resolution 1920x1080 <scene>`.
- Baseline `tools/ci/check_all.sh --env c`: PASS.
### In progress (parallel subagents; not yet committed)
- C1-01 pipeline: `tools/blender/lib` + `build.py` + determinism check, glb post-import script,
  `tools/texgen` (own tileable noise, ORM, trim sheet, LUT), `tools/audiogen` synth core.
- C1-02 greybox kit + greybox materials.
- C1-04 `validate_level` + walkthrough + review_shots renderer.
- C1-06 P1 cues + MusicDirector + Glasshouse stems. C1-07 material library v1 foundation.
- Next: C1-05 characters (they start once the Blender lib lands).
### Blocked
- C1-03 G1 geometry: waiting on G0 approval.
### Questions for lead
- QC-1: The `noise` package in tools/requirements.txt does not build on Python 3.13 (the session-start
  pip install fails on it). texgen implements its own tileable noise in numpy. Please remove `noise`
  from requirements.txt.
- QC-2: Please add `apt-get install -y mesa-vulkan-drivers` (plus `xvfb`) to the setup scripts
  (tools/setup is lead-owned) so every session can render Forward+ review shots.
- QC-3: You asked for the pipeline how-to at `docs/art/pipeline.md`, but owners.json does not give
  ENV C that path. I am writing it at `tools/blender/PIPELINE.md`. Either add `docs/art/pipeline.md`
  to ENV C's globs or move/link it on merge.
- QC-4: Audio bus layout: ENV C ships `game/world/audio/default_bus_layout.tres`. Please set
  `audio/buses/default_bus_layout="res://world/audio/default_bus_layout.tres"` in project.godot
  (lead-owned). Until then the runtime applies it if the buses are missing.
- QC-5: G0 proposes base_payout $40,000 for Glasshouse (HeistDef). Confirm, or have B set the
  economy number.
### Ready for integration
- no (G0 doc only; review requested). `check_all.sh --env c`: PASS at baseline.
