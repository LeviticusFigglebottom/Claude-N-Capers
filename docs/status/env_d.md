# ENV D status: Characters & Art Production

Owner: ENV D. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

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
