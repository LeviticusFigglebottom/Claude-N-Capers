# ENV D status: Characters & Art Production

Owner: ENV D. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

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
