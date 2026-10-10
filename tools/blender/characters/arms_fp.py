"""``char_arms_fp``: first-person arms ``rig_arms`` + the pistol viewmodel animation set (D1-03).

One glb: armature ``rig_arms`` (``_arms``: ``root`` = camera origin, the contract arm/finger bones,
helper bones ``weapon`` and ``magazine``), the skinned ``Arms`` mesh (hands at first-person
density, dark crew-suit sleeves ``char_suit_dark`` with a turned-in cuff, skin ``char_skin_2``) and
the clips of every set in ``_arms.SETS`` named ``<set>_<clip>``; loops carry the ``-loop`` suffix
(Godot strips it and sets LOOP_LINEAR). Godot also replaces '/' in animation names, so the set is a
prefix: the assembly tool should put ``pistol_<clip>`` into an AnimationLibrary "pistol" as
``<clip>`` (played as "pistol/idle").

Godot (after import): ``<root>/rig_arms/Skeleton3D/Arms``. Place the node at the camera (``root`` =
camera origin, -Z forward). Attach the weapon with a BoneAttachment3D on ``weapon`` (identity child)
and the magazine with a BoneAttachment3D on ``magazine``.
"""

import _anim as anim
import _arms as arms

TRI_BUDGET = 12000
EXPORT = {"embed": False, "animations": True, "skins": True, "morph": False}
ASSET_ID = "char_arms_fp"
PARAMS = {"skin": 2}

#: Clip table per set: frames, loop, events (plain data; mirrors _arms.SETS for tools).
CLIPS = {
    "pistol_idle": {"frames": 90, "loop": True},
    "pistol_ads_idle": {"frames": 90, "loop": True},
    "pistol_draw": {"frames": 11, "loop": False, "events": {"ready": 11}},
    "pistol_holster": {"frames": 11, "loop": False, "events": {"gone": 11}},
    "pistol_fire": {"frames": 6, "loop": False, "events": {"shot": 0}},
    "pistol_fire_ads": {"frames": 6, "loop": False, "events": {"shot": 0}},
    "pistol_reload": {"frames": 45, "loop": False, "events": {"mag_out": 6, "mag_swap": 15, "mag_in": 29, "done": 38}},
    "pistol_reload_empty": {"frames": 63, "loop": False,
                            "events": {"mag_out": 6, "mag_swap": 15, "mag_in": 29, "slide_release": 45, "done": 56}},
    "pistol_sprint": {"frames": 18, "loop": True},
}
LOOPS = sorted(name for name, row in CLIPS.items() if row["loop"])


def export_name(name: str) -> str:
    return f"{name}-loop" if CLIPS[name]["loop"] else name


def build(ctx) -> None:
    import bpy  # noqa: PLC0415

    arm = arms.build_arms_rig()
    mesh = arms.build_arms_mesh(ctx, arm, {"skin": int(ctx.param("skin", 2))})
    sk = arms.skeleton()
    solver = anim.Solver(sk)
    bpy.context.scene.render.fps = anim.FPS
    clips = {}
    for s in arms.SETS.values():
        clips.update(arms.fp_clips(sk, s))
    if sorted(clips) != sorted(CLIPS):
        raise AssertionError(f"CLIPS table out of date: {sorted(set(clips) ^ set(CLIPS))}")
    for name in sorted(clips):
        if clips[name].frames != CLIPS[name]["frames"] or clips[name].loop != CLIPS[name]["loop"]:
            raise AssertionError(f"{name}: CLIPS table disagrees with _arms.SETS")
        baked = anim.bake(solver, clips[name])
        anim.write_action(arm, baked, export_name(name))
        c = baked.checks
        ctx.source_extra[f"check.{name}"] = (f"reach_err={c['max_reach_err_m'] * 1000:.1f}mm "
                                             f"step={c['max_joint_step_deg']:.1f}deg")
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    (rx, ry, rz), (ox, oy, oz) = anim.grip_offset_godot(sk, "R")
    eye = arms.eye_point()
    ctx.source_extra["tris"] = mesh["tris"]
    ctx.source_extra["root"] = f"camera origin = rig_humanoid eye midpoint ({eye[0]:.4f},{eye[1]:.4f},{eye[2]:.4f}) m Blender"
    ctx.source_extra["weapon_bone"] = (
        f"child of hand.R at the HandR grip offset: basis x=({rx[0]:.4f},{rx[1]:.4f},{rx[2]:.4f}) "
        f"y=({ry[0]:.4f},{ry[1]:.4f},{ry[2]:.4f}) z=({rz[0]:.4f},{rz[1]:.4f},{rz[2]:.4f}) origin=({ox:.4f},{oy:.4f},{oz:.4f})")
    ctx.source_extra["loops"] = ",".join(LOOPS)
    for name in sorted(CLIPS):
        row = CLIPS[name]
        extra = f"{row['frames']}f loop={row['loop']}"
        if row.get("events"):
            extra += " events=" + ",".join(f"{k}@{v}" for k, v in sorted(row["events"].items()))
        ctx.source_extra[f"clip.{name}"] = extra
