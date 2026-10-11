# ENV D status: Characters & Art Production

Owner: ENV D. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

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
