# ENV D status: Characters & Art Production

Owner: ENV D. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## 2026-10-11: session 2 (new account), IN PROGRESS
### In progress (resume here)
- D4-01 LODs: `game/world/characters/_tools/crowd_lod.gd` + `assemble_characters.gd::_add_crowd_lod` write
  `Skeleton3D/CrowdLod` (one merged skinned surface, `<id>_lod.res`, material `world/materials/char_crowd_lod.tres`)
  for crowd NPCs (switch 20 m) and armed units (35 m); glb meshes get `visibility_range_end`. LOD1 = Godot auto LOD.
  Assembled once (99 scenes, deterministic). Next: test_lod.gd, run d tests (tri-budget tests may count CrowdLod),
  review render `_review/lod_review.png`, check_all, push.
- D-076: D4-02 / D4-03 paused (not started).

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
