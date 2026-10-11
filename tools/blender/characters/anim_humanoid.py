"""``char_anim_humanoid``: the shared ``humanoid`` animation library on ``rig_humanoid`` (D1-03).

One glb with the armature ``rig_humanoid`` (1.78 m, ``_rig.build_rig``), a tiny skinned proxy mesh
(``AnimProxy``, 1 triangle, material ``char_skin_1``: it only satisfies the exporter/validator and can
be ignored or deleted) and one glTF animation per clip, all procedural (``_anim_humanoid``), in place,
30 fps. ENV D's assembly tool turns the imported animations into the AnimationLibrary "humanoid".

Clip names in the glb: the contract name, plus the suffix ``-loop`` for looping clips. Godot's scene
importer strips ``-loop`` and sets ``Animation.loop_mode = LOOP_LINEAR`` (verified with Godot 4.7.2),
so the imported names are exactly the contract names. ``CLIPS``/``LOOPS`` below are plain data
(readable with ``lib.meta.read_constants`` without Blender) for tools that want the table: frames,
loop flag, intended locomotion speed and event frames.

Loops: the last frame equals the first (keys at 0..frames inclusive, length = frames / 30 s).
Locomotion clips plant the stance foot exactly: at ``speed`` m/s (for 1.78 m; multiply by
``Skeleton3D.motion_scale``) the feet do not slide. Play them at ``speed_scale = v / speed``.
"""

import _anim as anim
import _anim_humanoid as lib
import _rig as rig

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": True, "skins": True, "morph": False}
ASSET_ID = "char_anim_humanoid"
PARAMS = {"height": 1.78}

# name: frames (at 30 fps), loop, speed (m/s along the travel direction, 0 = stationary), events
# (name -> frame), priority (1 = P1 subset of roadmap C1-05, 2 = the rest delivered by D1-03, 3 = the special
# enemies, P3). Specials, timed from ENV A's data: kick_charge = SpecialTweak.phantom_windup_s (0.5 s, standing,
# then `sprint` plays during the charge); kick_hit lands its kick at `impact`; shield_bang =
# HeavySpecialTweak.bulwark_bang_hold_s (0.8 s), one event per bang; heal_ally = corpsman_heal_lock_s (1.0 s),
# `heal` at the injector jab; dozer_walk cadence = wrecker_step_interval_s (0.55 s per step, step_l/step_r =
# heel strikes). shield_idle = the Bulwark's braced stand (shield_walk's upper body, to blend with it).
# shield_walk / dozer_walk are walks (1.6 m/s native): EnemyDef.move_speed (Bulwark 3.2, Wrecker
# 3.5 m/s) is a run speed, i.e. speed_scale 2.0 / 2.2.
CLIPS = {
    "idle": {"frames": 120, "loop": True, "speed": 0.0, "priority": 1},
    "idle_alert": {"frames": 90, "loop": True, "speed": 0.0, "priority": 2},
    "walk": {"frames": 30, "loop": True, "speed": 1.6, "priority": 1},
    "run": {"frames": 21, "loop": True, "speed": 3.5, "priority": 1},
    "sprint": {"frames": 18, "loop": True, "speed": 5.75, "priority": 2},
    "crouch_idle": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "crouch_walk": {"frames": 27, "loop": True, "speed": 1.5, "priority": 1},
    "strafe_l": {"frames": 18, "loop": True, "speed": 1.2, "priority": 2},
    "strafe_r": {"frames": 18, "loop": True, "speed": 1.2, "priority": 2},
    "walk_back": {"frames": 30, "loop": True, "speed": 1.3, "priority": 2},
    "turn_l": {"frames": 24, "loop": False, "speed": 0.0, "priority": 2, "turn_deg": 90.0},
    "turn_r": {"frames": 24, "loop": False, "speed": 0.0, "priority": 2, "turn_deg": -90.0},
    "aim_rifle": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "aim_pistol": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "fire_rifle": {"frames": 6, "loop": False, "speed": 0.0, "priority": 1, "events": {"shot": 0}},
    "fire_pistol": {"frames": 9, "loop": False, "speed": 0.0, "priority": 1, "events": {"shot": 0}},
    "reload_rifle": {"frames": 72, "loop": False, "speed": 0.0, "priority": 1,
                     "events": {"mag_out": 14, "mag_in": 50, "done": 58}},
    "reload_pistol": {"frames": 45, "loop": False, "speed": 0.0, "priority": 1,
                      "events": {"mag_out": 6, "mag_in": 30, "done": 34}},
    "melee": {"frames": 21, "loop": False, "speed": 0.0, "priority": 2, "events": {"hit": 10}},
    "death_front": {"frames": 54, "loop": False, "speed": 0.0, "priority": 1, "events": {"impact": 35}},
    "death_back": {"frames": 54, "loop": False, "speed": 0.0, "priority": 1, "events": {"impact": 35}},
    "hit_react": {"frames": 15, "loop": False, "speed": 0.0, "priority": 1},
    "surrender": {"frames": 48, "loop": False, "speed": 0.0, "priority": 2},
    "kneel_cuffed": {"frames": 90, "loop": True, "speed": 0.0, "priority": 2},
    "hands_up": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "cower": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "lie_down": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "tied": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "flee": {"frames": 20, "loop": True, "speed": 4.0, "priority": 1},
    "phone_call": {"frames": 120, "loop": True, "speed": 0.0, "priority": 1},
    "radio_call": {"frames": 60, "loop": False, "speed": 0.0, "priority": 1, "events": {"key_on": 11, "key_off": 44}},
    "pager_answer": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "investigate_look": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "smoke": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "lean_wall": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "sit_chair": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "desk_type": {"frames": 60, "loop": True, "speed": 0.0, "priority": 2},
    "browse": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "downed": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "tased": {"frames": 30, "loop": True, "speed": 0.0, "priority": 2},
    "climb_ladder": {"frames": 36, "loop": True, "speed": 0.5, "priority": 2, "axis": "up"},
    "carry_bag_walk": {"frames": 22, "loop": True, "speed": 2.4, "priority": 1},
    "throw_bag": {"frames": 30, "loop": False, "speed": 0.0, "priority": 1, "events": {"release": 15}},
    "interact_low": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "interact_mid": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "interact_high": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "drill_place": {"frames": 45, "loop": False, "speed": 0.0, "priority": 2, "events": {"attach": 27}},
    "kick_charge": {"frames": 15, "loop": False, "speed": 0.0, "priority": 3},
    "kick_hit": {"frames": 21, "loop": False, "speed": 0.0, "priority": 3, "events": {"impact": 6}},
    "shield_walk": {"frames": 28, "loop": True, "speed": 1.6, "priority": 3},
    "shield_idle": {"frames": 108, "loop": True, "speed": 0.0, "priority": 3},
    "shield_bang": {"frames": 24, "loop": False, "speed": 0.0, "priority": 3,
                    "events": {"bang_1": 6, "bang_2": 12, "bang_3": 18}},
    "heal_ally": {"frames": 30, "loop": False, "speed": 0.0, "priority": 3, "events": {"heal": 12}},
    "dozer_walk": {"frames": 33, "loop": True, "speed": 1.6, "priority": 3, "events": {"step_r": 0, "step_l": 16}},
    # NPC ambient set (priority 4, heist casting: night_deposit / shadow_ledger civilians and staff). Props ride
    # HandR/Socket (SOURCE.txt `<prop>_grip`); seated clips share sit_chair's seat (0.47 m) and desk (0.74 m).
    "desk_work": {"frames": 360, "loop": True, "speed": 0.0, "priority": 4},
    "phone_seated": {"frames": 240, "loop": True, "speed": 0.0, "priority": 4},
    "sit_chair_watch": {"frames": 300, "loop": True, "speed": 0.0, "priority": 4},
    "mug_idle": {"frames": 240, "loop": True, "speed": 0.0, "priority": 4, "events": {"sip": 105}},
    "mug_carry_walk": {"frames": 34, "loop": True, "speed": 1.3, "priority": 4},
    "mop": {"frames": 120, "loop": True, "speed": 0.0, "priority": 4},
    "sit_bed_read": {"frames": 300, "loop": True, "speed": 0.0, "priority": 4, "events": {"page_turn": 221}},
    # cartel gunmen: hunched idle with a long gun held low across the body (weapon at HandR/Socket)
    "idle_thug": {"frames": 105, "loop": True, "speed": 0.0, "priority": 4},
}
LOOPS = sorted(name for name, row in CLIPS.items() if row["loop"])
P1 = sorted(name for name, row in CLIPS.items() if row["priority"] == 1)
#: Contract names not delivered by this asset yet (none since the P3 specials).
NOT_YET = []


def export_name(name: str) -> str:
    """Action / glTF animation name: Godot strips the ``-loop`` suffix and sets the loop mode."""
    return f"{name}-loop" if CLIPS[name]["loop"] else name


def build(ctx) -> None:
    import bpy  # noqa: PLC0415

    height = float(ctx.param("height", rig.DEFAULT_HEIGHT))
    arm = rig.build_rig(ctx, height)
    _proxy(ctx, arm)
    sk = anim.Skeleton.humanoid(height)
    _check_rest(sk, arm)
    solver = anim.Solver(sk)
    clips = lib.clips(sk, CLIPS)
    bpy.context.scene.render.fps = anim.FPS
    report = []
    keep = {}
    for name in sorted(CLIPS):
        baked = anim.bake(solver, clips[name])
        if name in ("sit_bed_read", "mop"):
            keep[name] = baked
        anim.write_action(arm, baked, export_name(name))
        c = baked.checks
        row = (f"{name}: {CLIPS[name]['frames']}f {CLIPS[name]['frames'] / anim.FPS:.2f}s"
               f"{' loop' if CLIPS[name]['loop'] else ''} speed={CLIPS[name]['speed']}"
               f" reach_err={c['max_reach_err_m'] * 1000:.1f}mm step={c['max_joint_step_deg']:.1f}deg")
        if "max_foot_slide_mm" in c:
            row += f" slide={c['max_foot_slide_mm']:.3f}mm/f"
        report.append(row)
        print(f"[anim] {row}")
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    bpy.context.scene.frame_set(0)
    (rx, ry, rz), (ox, oy, oz) = anim.grip_offset_godot(sk, "R")
    ctx.source_extra["fps"] = anim.FPS
    ctx.source_extra["clips"] = len(CLIPS)
    ctx.source_extra["loops"] = ",".join(LOOPS)
    ctx.source_extra["loops_marked_by"] = "-loop name suffix (Godot strips it and sets LOOP_LINEAR)"
    ctx.source_extra["handr_weapon_offset_godot"] = (
        f"basis x=({rx[0]:.4f},{rx[1]:.4f},{rx[2]:.4f}) y=({ry[0]:.4f},{ry[1]:.4f},{ry[2]:.4f}) "
        f"z=({rz[0]:.4f},{rz[1]:.4f},{rz[2]:.4f}) origin=({ox:.4f},{oy:.4f},{oz:.4f}) relative to bone hand.R")
    (lx, ly, lz), (px, py, pz) = anim.grip_offset_godot(sk, "L")
    ctx.source_extra["handl_shield_offset_godot"] = (
        f"basis x=({lx[0]:.4f},{lx[1]:.4f},{lx[2]:.4f}) y=({ly[0]:.4f},{ly[1]:.4f},{ly[2]:.4f}) "
        f"z=({lz[0]:.4f},{lz[1]:.4f},{lz[2]:.4f}) origin=({px:.4f},{py:.4f},{pz:.4f}) relative to bone hand.L")
    hx, hy, hz = (float(c) for c in lib.SHIELD_HANDLE * sk.scale)
    ctx.source_extra["shield_grip"] = (
        "shield_idle/shield_walk/shield_bang hold the Bulwark shield at HandL/Socket (the weapon grip convention, "
        "left fist): "
        "the shield pivot = its vertical handle in the fist, socket -Z = the shield face normal (forward), socket +Y = "
        f"up the handle (matches char_bulwark_shield); handle at Godot ({hx:.3f}, {hz:.3f}, {-hy:.3f}) m in the braced "
        f"stance, the shield tilted {lib.SHIELD_PITCH:g} deg top-back and turned {lib.SHIELD_YAW:g} deg; pistol "
        "one-handed at HandR/Socket just outside the shield's right edge")
    _npc_source(ctx, sk, keep)
    for name in sorted(CLIPS):
        row = CLIPS[name]
        extra = f"{row['frames']}f loop={row['loop']} speed_mps={row['speed']}"
        if row.get("events"):
            extra += " events=" + ",".join(f"{k}@{v}" for k, v in sorted(row["events"].items()))
        if "turn_deg" in row:
            extra += f" root_turn_deg={row['turn_deg']}"
        if "axis" in row:
            extra += f" travel_axis={row['axis']}"
        ctx.source_extra[f"clip.{name}"] = extra
    for i, row in enumerate(report):
        ctx.source_extra[f"check.{i:02d}"] = row


def _xform(basis, origin) -> str:
    (x, y, z), (ox, oy, oz) = basis, origin
    return (f"basis x=({x[0]:.4f},{x[1]:.4f},{x[2]:.4f}) y=({y[0]:.4f},{y[1]:.4f},{y[2]:.4f}) "
            f"z=({z[0]:.4f},{z[1]:.4f},{z[2]:.4f}) origin=({ox:.4f},{oy:.4f},{oz:.4f})")


#: Prop conventions in Godot axes (the prop scene's own frame); the grip transform puts that frame relative to
#: HandR/Socket (child Node3D of the Socket with this transform, or prop = socket * grip).
PROP_DOCS = {
    "phone": "phone 0.072 x 0.147 x 0.009 m slab: origin at its centre, +Y = the speaker end, the screen faces +Z, "
             "held to the right ear in phone_call / phone_seated (palm on the back, fingers up the phone)",
    "mug": "mug r 0.041 m, h 0.095 m: origin at the base centre, +Y = up the mug axis, handle toward -X; held around "
           "the body in the right hand (thumb on top); level in mug_carry_walk / mug_idle, tipped to the lips at `sip`",
    "mop": "string mop: origin at the floor end of the shaft (the head's centre on the floor), +Y = up the shaft (length "
           "{length} m), the right fist {r} m up the shaft (the socket, thumb toward the top), the left fist at {l} m "
           "(the HandL weapon-grip convention on the same shaft axes)",
    "book": "open book 0.30 x 0.23 x 0.022 m: origin at its centre, +Y = the top edge, the pages face +Z (toward the "
            "reader); right hand behind the right cover (thumb side over the edge), the left hand behind the left cover "
            "except during the page turn",
}


def _npc_source(ctx, sk, keep: dict) -> None:
    """SOURCE.txt facts for the NPC ambient set (props at HandR/Socket, furniture and bed placement)."""
    import numpy as np  # noqa: PLC0415

    for prop, doc in PROP_DOCS.items():
        basis, origin = lib.prop_in_socket_godot(sk, prop)
        doc = doc.format(length=lib.MOP_LENGTH, r=lib.MOP_GRIP_R, l=lib.MOP_GRIP_L)
        ctx.source_extra[f"{prop}_grip"] = f"{_xform(basis, origin)} relative to HandR/Socket; {doc}"
    ctx.source_extra["npc_seat"] = (
        f"sit_chair, desk_type, desk_work, phone_seated, sit_chair_watch: root on the floor under the seat centre, "
        f"facing the desk; seat top {lib.SEAT_H:.2f} m (pelvis on it, thighs level, feet flat 0.40 m ahead), desk top "
        f"{lib.DESK_Z:.2f} m with its front edge 0.20-0.25 m ahead of the root (keyboard 0.36 m ahead, mouse 0.27 m "
        f"right; phone_seated's note pad 0.10 m left; sit_chair_watch's joystick/mouse 0.21 m right, monitors ahead "
        f"from -25 to +25 deg)")
    bed = keep.get("sit_bed_read")
    if bed is not None:
        s0 = bed.frames[0]
        hips = float(s0.P["hips"][2])
        heel = max(float(s0.P[f"foot.{x}"][1]) for x in "LR")
        probe = anim.probe_for(sk)
        V = probe.posed(s0)
        back = V[(V[:, 2] > 0.15 * sk.scale) & (V[:, 2] < 0.6 * sk.scale)]
        by = float(back[:, 1].min())
        bz = float(back[np.argmin(back[:, 1]), 2])
        v = s0.P["neck"] - s0.P["spine"]
        rec = float(np.degrees(np.arctan2(-v[1], v[2])))
        ctx.source_extra["bed_pose"] = (
            f"sit_bed_read: the root is ON THE MATTRESS TOP under the pelvis (place it at the sleeping surface, e.g. a "
            f"0.55 m bed -> root at y 0.55), facing the foot end; hips joint {hips:.3f} m above the root, buttocks and "
            f"heels on the surface (lowest skin {probe.margin * 1000:.0f} mm above it), ankles {heel:.2f} m ahead "
            f"(mattress >= {heel + 0.25:.2f} m ahead of the root), trunk reclined {rec:.0f} deg on pillows/headboard "
            f"whose face meets the back {-by:.2f} m behind the root at {bz:.2f} m height")
    mop = keep.get("mop")
    if mop is not None:
        pts = np.array([lib.prop_frame(sk, s, "mop")[1] for s in mop.frames])
        ctx.source_extra["mop_sweep"] = (
            f"mop: in place, the head sweeps x {pts[:, 0].min():.2f}..{pts[:, 0].max():.2f} m, "
            f"{pts[:, 1].min():.2f}..{pts[:, 1].max():.2f} m ahead of the root (two sweeps per loop); keep ~1 m clear ahead")
    ctx.source_extra["idle_thug_weapon"] = (
        f"idle_thug: the long gun at HandR/Socket (the weapon grip convention), held low across the body: muzzle "
        f"{-lib.THUG_MUZZLE_PITCH:g} deg below the horizontal, turned {lib.THUG_MUZZLE_YAW:g} deg to the left; the left "
        f"hand loosely under the front of the receiver (0.19 m behind LeftHandIK), not on LeftHandIK")
    ctx.source_extra["mug_carry_walk_speed"] = (
        "mug_carry_walk is a careful carry at 1.3 m/s native (walk is 1.6); speed_scale = v / 1.3")


def _proxy(ctx, arm) -> None:
    """1-triangle mesh skinned to ``hips`` so the exporter writes the skin + animations."""
    import bpy  # noqa: PLC0415

    from lib import scene  # noqa: PLC0415

    mat = ctx.material("char_skin_1", "#E3BFA3", roughness=0.55)
    me = bpy.data.meshes.new("AnimProxy")
    me.from_pydata([(0.0, 0.0, 0.95), (0.004, 0.0, 0.95), (0.0, 0.004, 0.95)], [], [(0, 1, 2)])
    me.materials.append(mat)
    me.uv_layers.new(name="UVMap")
    obj = bpy.data.objects.new("AnimProxy", me)
    scene.link(obj, arm)
    vg = obj.vertex_groups.new(name="hips")
    vg.add([0, 1, 2], 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def _check_rest(sk, arm) -> None:
    """The solver's rest matrices must match Blender's (align_roll) to 1e-5."""
    import numpy as np  # noqa: PLC0415

    for b in arm.data.bones:
        m = np.array([[b.matrix_local[i][j] for j in range(3)] for i in range(3)])
        if float(np.abs(m - sk.B[b.name]).max()) > 1e-5:
            raise AssertionError(f"rest frame mismatch for {b.name}")
