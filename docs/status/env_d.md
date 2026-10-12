# ENV D status: Characters & Art Production

Owner: ENV D. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

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
