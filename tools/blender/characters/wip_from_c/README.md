# Handoff: C1-05 characters WIP (ENV C → ENV D, D-027/D-028)

This is the unchanged work-in-progress of ENV C's characters subagent. It was stopped mid-task on
2026-10-10 when C1-05 moved to ENV D. **It has not been built, validated or reviewed. Treat it as
input, not as a deliverable.** The lead moves it into ENV D's `tools/blender/characters/`.

## What's here
- `characters/rig.py`: the `rig_humanoid` joint table, with the exact bone names from
  characters.md, finger chains, A-pose rest, 1.78 m default, head/hands ×1.03, and
  `create_armature()`. Its docstring documents the axes (Blender +Y = Godot −Z).
- `characters/_body.py`: the procedural base-mesh generator. Weights are computed in Python for
  determinism, so automatic weights are not used.
- `characters/_outfits.py`, `_dress.py`, `_gear.py`: outfit and gear meshes for Security Officer,
  civilians, Patrol Officer, TAC Light and crew body (parametric colours).
- `characters/_pose.py`, `_anims.py`: procedural pose and animation solver (gait, IK) for the P1
  animation list.
- `characters/_blend.py`: Blender glue (armature, skinning, actions, export).
- `world_characters/materials/palette.json`: the outfit and skin palette draft (was
  `game/world/characters/materials/`).

About 3.7k lines in total. No asset scripts (`ASSET_ID`) and no glb/tscn outputs exist yet.

## Known state and gaps (as of the stop)
- Never run end to end through `tools/blender/build.py`. Determinism is unverified.
- The agent was in the middle of fixing a messy forearm edge loop and a shared-object mutation
  in the animation `bake` step, and then planned to check IK reach errors and foot sliding.
- Missing: the per-character asset scripts, the Godot `world/characters/<id>/<id>.tscn` scenes
  (Skeleton3D, AnimationPlayer library "humanoid", BoneAttachment3D HandR/HandL/Head/Back/Hip),
  the tests, and the review renders.
- It uses `tools/blender/lib` v1.0.0 (ENV C, read-only for D). Rule from docs/art/pipeline.md:
  bevel before UVs.
