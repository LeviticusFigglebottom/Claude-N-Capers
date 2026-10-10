# world/characters (ENV D)

Assembled character scenes for ENV A, in the shape of `docs/contracts/characters.md` v1.1 (D-029).
Everything here except `_tools/` and this README is **generated**; never edit it by hand.

## Regenerate (one line)

```
python3 tools/blender/build.py --category characters && tools/blender/characters/assemble.sh --render
```

Order: `build.py` (Blender: glbs + SOURCE.txt) → `godot --headless --path game --import` →
`godot --headless --path game --script res://world/characters/_tools/assemble_characters.gd` →
`godot --import` again (refreshes the uid/filesystem cache) → optional lineup render under xvfb
(`--render`). Then `tools/ci/run_tests.sh d` (`game/tests/d/test_scenes.gd`).

## What the assembly writes

| Output | From |
|---|---|
| `anim_humanoid.res` | `AnimationLibrary` built from `assets/characters/char_anim_humanoid/char_anim_humanoid.glb`: track paths rewritten to `Skeleton3D:<bone>` (relative to the character Root), non-bone tracks dropped, `RESET` skipped, loop mode `LOOP_LINEAR` for looped clips. Empty library (plus a warning) until that glb exists. |
| `<id>/<id>.tscn` | `assets/characters/char_<id>/char_<id>.glb`; `<id>` is the asset id without `char_` (e.g. `security_officer/security_officer.tscn`, Root `SecurityOfficer`). |
| `<id>/<id>_<mesh>.res` | The meshes, saved as binary resources the scene references (a `.tscn` cannot reference a glb's sub-resources; embedding would put megabytes of text in the scene). |
| `_test/body_base.tscn` | Test fixture from `char_body_base` (always built; `"test": true` in the index). |
| `characters.json` | Index `{characters: [{id, asset, scene, test}], anim_library}` sorted by scene path. |

**Which assets become characters:** every folder `assets/characters/char_<id>/` with
`char_<id>.glb` containing a Skeleton3D, except the prefixes `char_anim_` (animation source),
`char_arms_` (first-person arms), `char_mask_` and `char_body_base` (test bodies; only
`char_body_base` is built, as the `_test` fixture). The rule lives in `_tools/character_spec.gd`.

## Scene shape

```
SecurityOfficer (Node3D)
├── Skeleton3D (52 contract bones; the glb's rig_humanoid wrapper is folded away)
│   ├── Body, Hair, <outfit parts>... (MeshInstance3D, skinned; blend_shapes/build|gender|age from SOURCE.txt params)
│   ├── HandR (BoneAttachment3D, hand.R) └── Socket (Marker3D)
│   ├── HandL (BoneAttachment3D, hand.L) └── Socket
│   ├── Head  (BoneAttachment3D, head)   └── Socket
│   ├── Back  (BoneAttachment3D, chest)  └── Socket
│   └── Hip   (BoneAttachment3D, hips)   └── Socket
└── AnimationPlayer (libraries = {"humanoid": anim_humanoid.res}; play "humanoid/<clip>")
```

A BoneAttachment3D's own transform is overwritten by the bone pose every frame, so the attach
offset lives on its `Socket` child. Parent attached models to `<Marker>/Socket`:

| Socket | Where (rest pose, 1.78 m body, scaled with height) | Axes |
|---|---|---|
| `Head/Socket` | face centre: between the eyes at cornea depth (0, 1.666, -0.077); the mask pivot | character axes: -Z forward, +Y up |
| `HandR/Socket`, `HandL/Socket` | the weapon origin in the fist (QB-22), exactly the frame the animation solver uses: `_anim.grip_offset_godot()` (read via python3 at assembly time, else `HAND_SOCKETS` in `_tools/character_spec.gd`) | weapon axes: X right, Y up, -Z muzzle (18-degree grip rake) |
| `Back/Socket` | behind the chest on the spine line (0, 1.30, 0.12) | character axes |
| `Hip/Socket` | right side of the belt (0.17, 1.00, 0) | character axes |

An outfit can override a point with `attach_<head|hand_r|hand_l|back|hip>: [x, y, z]` in its
SOURCE.txt (Godot character space, metres, rest pose, at the asset's own height).

## Determinism

Re-running the assembly gives byte-identical files, also from scratch and after a re-import of the
glbs: assets are visited in sorted order; resource uids are derived from the file path
(`ResourceSaver.set_uid`); ext/sub-resource ids are fixed (`1_anim`, `mesh_<node>`, `skin_0`,
`mat_<surface>`, `anim_<clip>`); node `unique_id`s are a hash of the node path; socket transforms
are rounded to 0.1 mm.

## Loops

Looped clips come from, in order: a `loops:` line in `char_anim_humanoid/SOURCE.txt`, `LOOPS` in
`tools/blender/characters/anim_humanoid.py` (imported with python3, or its quoted names read from
the source), or the `*` list of characters.md (`DEFAULT_LOOPS` in `_tools/character_spec.gd`).

## Lineup render

`--headless` Godot has no renderer. `_tools/render_lineup.gd` runs under
`xvfb-run` (Vulkan lavapipe, see `tools/setup/install_render_deps.sh`) and writes
`assets/characters/_review/lineup_godot.png`, `lineup_silhouette_30m.png` (black silhouettes at
the on-screen size of a 1.78 m figure at 30 m: 1080p, 60-degree vertical FOV, shown 4x) and
`mask_fit_godot.png`. Add `-- --with-tests` to include the test fixtures.
