"""``char_arms_fp``: first-person arms ``rig_arms`` + the viewmodel animation sets (D1-03, D-034).

One glb: armature ``rig_arms`` (``_arms``: ``root`` = camera origin, the contract arm/finger bones,
helper bones ``weapon`` and ``magazine``), the skinned ``Arms`` mesh (hands at first-person
density, dark crew-suit sleeves ``char_suit_dark`` with a turned-in cuff, skin ``char_skin_2``) and
the clips of every set in ``_arms_sets.SETS`` (pistol, smg, rifle, shotgun, lmg, sniper) named
``<set>_<clip>``; loops carry the ``-loop`` suffix (Godot strips it and sets LOOP_LINEAR). Godot also
replaces '/' in animation names, so the set is a prefix: the assembly tool puts ``<set>_<clip>`` into
an AnimationLibrary "<set>" as ``<clip>`` (played as "rifle/reload").

Godot (after import): ``<root>/rig_arms/Skeleton3D/Arms``. Place the node at the camera (``root`` =
camera origin, -Z forward). Attach the weapon with a BoneAttachment3D on ``weapon`` (identity child)
and the magazine with a BoneAttachment3D on ``magazine``. Every clip keys the same transforms
(rotations of all bones, positions of the clavicles, ``weapon`` and ``magazine``). Events (frame
numbers at 30 fps) and the moving-part conventions are listed in SOURCE.txt.
"""

import _anim as anim
import _arms as arms
import _arms_clips as clips_mod
import _arms_sets as sets

TRI_BUDGET = 12000
EXPORT = {"embed": False, "animations": True, "skins": True, "morph": False}
ASSET_ID = "char_arms_fp"
PARAMS = {"skin": 2}

def notes() -> dict:
    """Contract notes copied into SOURCE.txt (see the D-034 report / characters.md)."""
    return {
        "fp.clips": "<set>_<clip>; all sets: idle*, ads_idle*, sprint* (loops), draw, holster, fire, fire_ads, reload, "
                    "reload_empty; shotgun: reload_start, reload_loop, reload_end, reload_end_empty; sniper: bolt, bolt_ads",
        "fp.camera": "review camera = crew camera: 75 deg vertical FOV (crew_member.tscn), root = eye",
        "fp.fire": "fire/fire_ads start at rest, kick peaks on frame 1; full-auto sets (smg, rifle, lmg) are 3 f "
                   "(<= 1.5 shot intervals) so the game restarts them every shot",
        "fp.shotgun": "pump folded into fire/fire_ads (events pump_back, pump_forward); shell-by-shell = reload_start + "
                      "n x reload_loop (frame 0 == last frame; imports LOOP_LINEAR via Godot's _loop suffix: loop it n x its length) + reload_end (reload_end_empty when the "
                      "tube was empty: adds a pump); reload/reload_empty = the same pieces for 6 rounds (3.4 s / 4.2 s); "
                      "suggested data: reload_start_s 0.4, reload_per_round_s 0.4333, reload_end_s 0.4 (empty 1.2)",
        "fp.sniper": "fire/fire_ads = recoil only (9 f); play bolt (hip) / bolt_ads after each shot (27 f; 9 + 27 = 36 f = "
                     "1.2 s = 50 rpm); during the bolt the right hand leaves the grip and the weapon bone moves "
                     "relative to hand.R (the left hand holds the gun); reload_empty ends with the bolt cycle",
        "fp.lmg": "reload: cover_open, mag_out (box off), mag_in (box on), belt_seat, cover_close; reload_empty adds "
                  "charge (charging handle pulled back by the left hand)",
        "fp.parts": (f"Pump: slides {sets.PUMP_TRAVEL:.3f} m along local +Z (back) between the pump_back ramp and "
                     f"pump_forward; Bolt: handle lifts {sets.BOLT_LIFT_DEG:.0f} deg about the bore axis "
                     f"(bolt_open), slides {sets.BOLT_TRAVEL:.3f} m along +Z (bolt_back), returns (bolt_forward), "
                     f"locks down (bolt_close); Rampart feed cover: opens {clips_mod.COVER_OPEN_DEG:.0f} deg about its "
                     f"front hinge (cover_open .. cover_close; the weapon scene needs a hinged FeedCover pivot); "
                     f"Slide (pistol): slide_release; smg/rifle bolt_release (cocking-handle slap / bolt catch)"),
    }


def export_name(name: str, table: dict) -> str:
    return f"{name}-loop" if table[name]["loop"] else name


def build(ctx) -> None:
    import bpy  # noqa: PLC0415

    table = sets.clip_table()
    arm = arms.build_arms_rig()
    mesh = arms.build_arms_mesh(ctx, arm, {"skin": int(ctx.param("skin", 2))})
    sk = arms.skeleton()
    solver = anim.Solver(sk)
    bpy.context.scene.render.fps = anim.FPS
    clips = {}
    for s in arms.SETS.values():
        clips.update(arms.fp_clips(sk, s))
    if sorted(clips) != sorted(table):
        raise AssertionError(f"clip table out of date: {sorted(set(clips) ^ set(table))}")
    for name in sorted(clips):
        baked = anim.bake(solver, clips[name])
        c = baked.checks
        if c["max_reach_err_m"] > 0.010:
            raise AssertionError(f"{name}: IK reach error {c['max_reach_err_m'] * 1000:.1f} mm")
        anim.write_action(arm, baked, export_name(name, table))
        ctx.source_extra[f"check.{name}"] = (f"reach_err={c['max_reach_err_m'] * 1000:.1f}mm "
                                             f"step={c['max_joint_step_deg']:.1f}deg")
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    (rx, ry, rz), (ox, oy, oz) = anim.grip_offset_godot(sk, "R")
    eye = arms.eye_point()
    ctx.source_extra["tris"] = mesh["tris"]
    ctx.source_extra["root"] = (f"camera origin = rig_humanoid eye midpoint ({eye[0]:.4f},{eye[1]:.4f},{eye[2]:.4f}) "
                                "m Blender")
    ctx.source_extra["weapon_bone"] = (
        f"child of hand.R at the HandR grip offset: basis x=({rx[0]:.4f},{rx[1]:.4f},{rx[2]:.4f}) "
        f"y=({ry[0]:.4f},{ry[1]:.4f},{ry[2]:.4f}) z=({rz[0]:.4f},{rz[1]:.4f},{rz[2]:.4f}) "
        f"origin=({ox:.4f},{oy:.4f},{oz:.4f}); "
        f"identity relative to hand.R except in sniper_bolt, sniper_bolt_ads and sniper_reload_empty")
    ctx.source_extra["loops"] = ",".join(sorted(n for n, r in table.items() if r["loop"]))
    ctx.source_extra["sets"] = ",".join(arms.SETS)
    for k, v in notes().items():
        ctx.source_extra[k] = v
    for name in sorted(table):
        row = table[name]
        extra = f"{row['frames']}f loop={row['loop']}"
        if row.get("events"):
            evs = sorted(row["events"].items(), key=lambda kv: (kv[1], kv[0]))
            extra += " events=" + ",".join(f"{k}@{v}" for k, v in evs)
        ctx.source_extra[f"clip.{name}"] = extra
