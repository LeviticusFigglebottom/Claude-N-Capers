# ENV A status: Core Systems & AI

Owner: ENV A. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## To the LEAD: (2026-10-21 05:00 UTC update; newest at top)
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
