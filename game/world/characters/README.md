# world/characters (ENV D)

Assembled character scenes for ENV A, in the shape of `docs/contracts/characters.md` v1.1 (D-029).
Everything here except `_tools/` and this README is **generated**; never edit it by hand, and
never open-and-save a character scene in the editor (the editor would re-add the glb's random
imported node ids, see Determinism). Change the Blender script or the assembly tool and regenerate.

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
| `<id>/<id>.tscn` | An **inherited scene** of `assets/characters/char_<id>/char_<id>.glb` (D-067b); `<id>` is the asset id without `char_` (e.g. `security_officer/security_officer.tscn`, Root `SecurityOfficer`). The meshes and skins stay in the imported glb (no per-scene mesh copies); the `.tscn` only stores the differences: root name, blend shape values, `material_override`s, and the added markers, sockets, extra markers and AnimationPlayer. |
| `<id>/<id>_shield.tscn`, `<id>_shield_visual.res` | Bulwark shield props (`Shield` AnimatableBody3D, `Collision` + `Visual`); these still save the visual mesh as a `.res`. |
| `_test/body_base.tscn` | Test fixture from `char_body_base` (always built; `"test": true` in the index). |
| `characters.json` | Index `{characters: [{id, asset, scene, test}], anim_library}` sorted by scene path. |

**Which assets become characters:** every folder `assets/characters/char_<id>/` with
`char_<id>.glb`, except the prefixes `char_anim_` (animation source),
`char_arms_` (first-person arms), `char_mask_` and `char_body_base` (test bodies; only
`char_body_base` is built, as the `_test` fixture). The rule lives in `_tools/character_spec.gd`.

**glb requirement:** the Blender script's `EXPORT` must set `"remove_armature": True`, so the glb
imports as `<root> > Skeleton3D > meshes` (no `rig_humanoid` wrapper node) and every mesh is
parented to the armature. A character glb without a top-level `Skeleton3D` (or with a mesh outside
it) is an assembly **error**: rebuild it with `remove_armature`.

## Scene shape

```
SecurityOfficer (Node3D)
├── Skeleton3D (52 contract bones; inherited from the glb)
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
(`ResourceSaver.set_uid`); ext/sub-resource ids are fixed (`1_glb`, `1_anim`,
`2_<material>` for overrides, `anim_<clip>`; shields: `mesh_visual`, `mat_<surface>`,
`collision_shape`); node `unique_id`s are a hash of the node path; socket transforms are rounded
to 0.1 mm. The glb's imported node ids are random per import, so the assembly drops the scene's
`id_paths` (references into the glb by id); Godot then matches the inherited nodes by path.

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

## Heist casts (`p5_cast.json`, hand-maintained)

The one file that is **not** generated: `heist -> role -> [character ids]` for every heist with a
cast (D3-01 P5 heists; D-115 added glasshouse, night_deposit, dockside_burn and shadow_ledger).
For the D-115 heists the roles are the spawn tags in the design doc's roster table
(`docs/design/heists/<heist>.md`, `### ... roster (spawn data)`), plus `security_operator` (the
camera operator) and `police`, so ENV A's `NpcVisualTweak.heist_tag_characters` can mirror them.
`game/tests/d/test_p5_cast.gd` parses those roster tables and fails when a design role has no
character in `characters.json` with a loadable scene.
