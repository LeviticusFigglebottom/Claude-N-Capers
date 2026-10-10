"""``rig_humanoid``: the one shared character skeleton (docs/contracts/characters.md, D1-01).

Private helper (``_`` prefix): imported by character scripts, never built on its own. Everything
except ``build_rig()`` is pure Python (no ``bpy``), so the body generator, outfit scripts, the
animation solver and tests can use the joint table without Blender.

Axes (docs/art/pipeline.md §6): Blender +Z up, the character faces Blender +Y (= Godot -Z). The
character's right side is Blender +X (``.R`` bones), the left side -X (``.L``). Root at the feet
(origin). Metres.

Rest pose: **A-pose**, upper arms 45 degrees below horizontal, elbows bent 6 degrees forward, palms
facing the thighs (thumbs forward), fingers relaxed (8-10 degrees curl per joint), knees bent ~1.5
degrees forward. Why A-pose: the shoulder deforms far less between rest and the gameplay poses
(guns up, arms down) than from a T-pose, and the slight elbow/knee bends give IK an unambiguous
bend direction.

Bone rolls (deterministic, ``EditBone.align_roll``): every bone's local +Z axis points to the
character's back (Blender -Y = Godot +Z), except ``foot``/``toe`` (+Z = up) and the hand and finger
bones (+Z = back of the hand). Bone +Y runs head -> tail. Consequences: the spine chain, neck and
head are identity rotations in Godot (pointing up, Z back); hinge joints (elbow, knee, finger
joints) flex about their local X axis.

Variants: ``height`` scales the whole skeleton uniformly (1.78 m +-6 %); build/gender/age come
from shape keys on the meshes, so every variant has identical bone names, hierarchy and rest
rotations and animations retarget 1:1 (use ``Skeleton3D.motion_scale`` = height / 1.78 for hip
travel if needed).
"""

from __future__ import annotations

import math

DEFAULT_HEIGHT = 1.78
MAX_HEIGHT_DEVIATION = 0.06          # contract: +-6 %
HEAD_HAND_SCALE = 1.03               # style guide §1
ARMATURE_NAME = "rig_humanoid"

FINGERS = ("thumb", "index", "middle", "ring", "pinky")
SIDES = (("L", -1.0), ("R", 1.0))    # suffix, sign of X

Vec = tuple[float, float, float]


def _bone_order() -> list[tuple[str, str | None]]:
    out: list[tuple[str, str | None]] = [
        ("root", None), ("hips", "root"), ("spine", "hips"), ("chest", "spine"), ("neck", "chest"),
        ("head", "neck"),
    ]
    for sfx, _sx in SIDES:
        out += [(f"clavicle.{sfx}", "chest"), (f"upper_arm.{sfx}", f"clavicle.{sfx}"),
                (f"forearm.{sfx}", f"upper_arm.{sfx}"), (f"hand.{sfx}", f"forearm.{sfx}")]
        for f in FINGERS:
            out += [(f"{f}_01.{sfx}", f"hand.{sfx}"), (f"{f}_02.{sfx}", f"{f}_01.{sfx}"),
                    (f"{f}_03.{sfx}", f"{f}_02.{sfx}")]
    for sfx, _sx in SIDES:
        out += [(f"thigh.{sfx}", "hips"), (f"shin.{sfx}", f"thigh.{sfx}"),
                (f"foot.{sfx}", f"shin.{sfx}"), (f"toe.{sfx}", f"foot.{sfx}")]
    return out


#: All 52 bone names in creation order (parents before children). Exact contract names.
BONES: list[str] = [b for b, _p in _bone_order()]
#: bone -> parent bone (``None`` for ``root``).
PARENT: dict[str, str | None] = dict(_bone_order())
assert len(BONES) == 52 and len(set(BONES)) == 52

#: Typical body radius around each bone at 1.78 m (m). Used to normalise distances when skinning
#: (``_body.skin_weights``) and handy for hitbox sizing. Fingers share one value per finger.
BONE_RADIUS: dict[str, float] = {"root": 0.10, "hips": 0.15, "spine": 0.14, "chest": 0.15,
                                 "neck": 0.05, "head": 0.085}
for _sfx, _sx in SIDES:
    BONE_RADIUS.update({f"clavicle.{_sfx}": 0.05, f"upper_arm.{_sfx}": 0.045, f"forearm.{_sfx}": 0.036,
                        f"hand.{_sfx}": 0.028, f"thigh.{_sfx}": 0.075, f"shin.{_sfx}": 0.048,
                        f"foot.{_sfx}": 0.04, f"toe.{_sfx}": 0.03})
    for _f in FINGERS:
        for _i in (1, 2, 3):
            BONE_RADIUS[f"{_f}_0{_i}.{_sfx}"] = 0.0105 if _f == "thumb" else 0.0088

# Proportions (metres at 1.78 m, before HEAD_HAND_SCALE where noted). Override any of them with
# ``proportions={...}``; keep overrides inside one project-wide skeleton (animations assume it).
DEFAULT_PROPORTIONS: dict[str, float] = {
    "arm_drop_deg": 45.0,       # upper arm below horizontal (A-pose)
    "elbow_bend_deg": 6.0,      # forearm bent forward from the upper-arm line
    "shoulder_x": 0.175,        # shoulder joint half width
    "shoulder_z": 1.432,
    "upper_arm": 0.290,
    "forearm": 0.255,
    "hip_x": 0.090,             # hip joint half width
    "hip_z": 0.925,
    "knee_z": 0.505,
    "ankle_z": 0.085,
    "hand_len": 0.092,          # wrist -> middle knuckle (x HEAD_HAND_SCALE)
    "hand_width": 0.084,        # knuckle width (x HEAD_HAND_SCALE)
    "finger_curl_deg": 9.0,
}

# finger: (lateral position as a fraction of the hand width (+ = thumb side), knuckle offset
# along the hand from hand_len, phalanx lengths). x HEAD_HAND_SCALE.
FINGER_DATA: dict[str, tuple[float, float, tuple[float, float, float]]] = {
    "index": (0.36, -0.004, (0.041, 0.025, 0.021)),
    "middle": (0.12, 0.000, (0.045, 0.028, 0.022)),
    "ring": (-0.12, -0.005, (0.042, 0.027, 0.021)),
    "pinky": (-0.35, -0.014, (0.033, 0.020, 0.019)),
}
FINGER_SPLAY_DEG = {"index": 4.0, "middle": 0.0, "ring": -4.0, "pinky": -9.0}
THUMB_LENS = (0.044, 0.033, 0.027)


# -- tiny vector helpers (pure Python) -------------------------------------------------------
def add(a: Vec, b: Vec) -> Vec:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a: Vec, b: Vec) -> Vec:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a: Vec, k: float) -> Vec:
    return (a[0] * k, a[1] * k, a[2] * k)


def dot(a: Vec, b: Vec) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a: Vec, b: Vec) -> Vec:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def length(a: Vec) -> float:
    return math.sqrt(dot(a, a))


def norm(a: Vec) -> Vec:
    n = length(a)
    return (a[0] / n, a[1] / n, a[2] / n)


def lerp(a: Vec, b: Vec, t: float) -> Vec:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def rotate(v: Vec, axis: Vec, ang: float) -> Vec:
    """Rodrigues rotation of ``v`` about unit ``axis`` by ``ang`` radians."""
    c, s = math.cos(ang), math.sin(ang)
    d = dot(v, axis)
    cr = cross(axis, v)
    return (v[0] * c + cr[0] * s + axis[0] * d * (1 - c),
            v[1] * c + cr[1] * s + axis[1] * d * (1 - c),
            v[2] * c + cr[2] * s + axis[2] * d * (1 - c))


def to_godot(v: Vec) -> Vec:
    """Blender (x, y fwd, z up) -> Godot (x, y up, z back)."""
    return (v[0], v[2], -v[1])


def _props(proportions: dict[str, float] | None) -> dict[str, float]:
    p = dict(DEFAULT_PROPORTIONS)
    if proportions:
        unknown = set(proportions) - set(p)
        if unknown:
            raise ValueError(f"unknown proportions {sorted(unknown)}")
        p.update(proportions)
    return p


def scale_for(height: float) -> float:
    """Uniform skeleton scale for ``height``; raises outside the contract's +-6 %."""
    s = height / DEFAULT_HEIGHT
    if abs(s - 1.0) > MAX_HEIGHT_DEVIATION + 1e-9:
        raise ValueError(f"height {height} m is outside 1.78 m +-6 %")
    return s


def arm_frame(sx: float, proportions: dict[str, float] | None = None) -> dict[str, Vec]:
    """Rest-pose upper-arm frame for side ``sx`` (-1 left, +1 right), unit vectors.

    ``along``: shoulder -> elbow; ``fwd``: thumb side (+Y); ``palm``: palm normal (towards the
    thigh); ``back``: back of the hand (= -palm)."""
    drop = math.radians(_props(proportions)["arm_drop_deg"])
    along = (sx * math.cos(drop), 0.0, -math.sin(drop))
    palm = (-sx * math.sin(drop), 0.0, -math.cos(drop))
    return {"along": along, "fwd": (0.0, 1.0, 0.0), "palm": palm, "back": mul(palm, -1.0)}


def hand_frame(sx: float, height: float = DEFAULT_HEIGHT,
               proportions: dict[str, float] | None = None) -> dict[str, Vec]:
    """Rest-pose hand frame: ``origin`` (wrist), unit ``along`` (to the knuckles), ``fwd`` (thumb
    side), ``palm`` (palmar normal), ``back`` (dorsal normal). Use it to place grips and IK goals."""
    segs = bone_segments(height, proportions)
    wrist, tail, _r = segs[f"hand.{'L' if sx < 0 else 'R'}"]
    along = norm(sub(tail, wrist))
    fwd = (0.0, 1.0, 0.0)
    fwd = norm(sub(fwd, mul(along, dot(fwd, along))))
    palm = norm(cross(along, fwd))
    if dot(palm, arm_frame(sx, proportions)["palm"]) < 0:
        palm = mul(palm, -1.0)
    return {"origin": wrist, "along": along, "fwd": fwd, "palm": palm, "back": mul(palm, -1.0)}


def bone_segments(height: float = DEFAULT_HEIGHT,
                  proportions: dict[str, float] | None = None) -> dict[str, tuple[Vec, Vec, Vec]]:
    """{bone: (head, tail, roll_reference)} in metres, Blender axes, rest pose.

    ``roll_reference`` is the world vector the bone's local +Z is aligned to (``align_roll``)."""
    p = _props(proportions)
    k = scale_for(height)
    hh = HEAD_HAND_SCALE
    back: Vec = (0.0, -1.0, 0.0)
    up: Vec = (0.0, 0.0, 1.0)
    j: dict[str, tuple[Vec, Vec, Vec]] = {}

    def put(name: str, head: Vec, tail: Vec, roll: Vec = back) -> None:
        j[name] = (mul(head, k), mul(tail, k), roll)

    put("root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.15))
    put("hips", (0.0, 0.0, 0.955), (0.0, -0.005, 1.055))
    put("spine", (0.0, -0.005, 1.055), (0.0, -0.015, 1.215))
    put("chest", (0.0, -0.015, 1.215), (0.0, -0.025, 1.465))
    put("neck", (0.0, -0.025, 1.465), (0.0, -0.012, 1.585))
    put("head", (0.0, -0.012, 1.585), (0.0, -0.012, 1.78))
    for sfx, sx in SIDES:
        fr = arm_frame(sx, p)
        along, fwd, palm = fr["along"], fr["fwd"], fr["palm"]
        sh: Vec = (sx * p["shoulder_x"], -0.018, p["shoulder_z"])
        put(f"clavicle.{sfx}", (sx * 0.022, 0.022, 1.425), sh)
        elbow = add(sh, mul(along, p["upper_arm"]))
        bend_axis = norm(cross(along, fwd))           # rotating along towards fwd
        fore = rotate(along, bend_axis, math.radians(p["elbow_bend_deg"]))
        wrist = add(elbow, mul(fore, p["forearm"]))
        put(f"upper_arm.{sfx}", sh, elbow)
        put(f"forearm.{sfx}", elbow, wrist)
        h_fwd = norm(sub(fwd, mul(fore, dot(fwd, fore))))
        h_palm = norm(cross(fore, h_fwd)) if sx > 0 else norm(cross(h_fwd, fore))
        # keep palm pointing towards the thigh (same hemisphere as the arm frame's palm)
        if dot(h_palm, palm) < 0:
            h_palm = mul(h_palm, -1.0)
        h_back = mul(h_palm, -1.0)
        put(f"hand.{sfx}", wrist, add(wrist, mul(fore, p["hand_len"] * hh)), roll=h_back)
        curl_axis = norm(cross(fore, h_palm))          # rotating along towards the palm
        for f in ("index", "middle", "ring", "pinky"):
            lat, koff, lens = FINGER_DATA[f]
            base = add(wrist, mul(fore, (p["hand_len"] + koff) * hh))
            base = add(base, mul(h_fwd, lat * p["hand_width"] * hh))
            d = rotate(fore, mul(h_palm, -1.0) if sx > 0 else h_palm, math.radians(FINGER_SPLAY_DEG[f]))
            d = norm(d)
            pos = base
            for i, ln in enumerate(lens):
                d = norm(rotate(d, curl_axis, math.radians(p["finger_curl_deg"])))
                nxt = add(pos, mul(d, ln * hh))
                put(f"{f}_0{i + 1}.{sfx}", pos, nxt, roll=h_back)
                pos = nxt
        # thumb: metacarpal from the palm's thumb side near the wrist, pointing forward and palmar
        tb = add(wrist, add(mul(fore, 0.020 * hh), add(mul(h_fwd, 0.022 * hh), mul(h_palm, 0.010 * hh))))
        d = norm(add(mul(fore, 0.80), add(mul(h_fwd, 0.45), mul(h_palm, 0.40))))
        th_back = norm(sub(h_back, mul(d, dot(h_back, d))))
        th_axis = norm(cross(d, th_back))
        pos = tb
        for i, ln in enumerate(THUMB_LENS):
            if i > 0:
                d = norm(rotate(d, th_axis, math.radians(10.0)))
            nxt = add(pos, mul(d, ln * hh))
            put(f"thumb_0{i + 1}.{sfx}", pos, nxt, roll=th_back)
            pos = nxt
    for sfx, sx in SIDES:
        hip: Vec = (sx * p["hip_x"], 0.0, p["hip_z"])
        knee: Vec = (sx * (p["hip_x"] + 0.005), 0.012, p["knee_z"])
        ankle: Vec = (sx * (p["hip_x"] + 0.010), -0.012, p["ankle_z"])
        ball: Vec = (sx * (p["hip_x"] + 0.016), 0.132, 0.024)
        toe: Vec = (sx * (p["hip_x"] + 0.018), 0.200, 0.020)
        put(f"thigh.{sfx}", hip, knee)
        put(f"shin.{sfx}", knee, ankle)
        put(f"foot.{sfx}", ankle, ball, roll=up)
        put(f"toe.{sfx}", ball, toe, roll=up)
    return j


def joints(height: float = DEFAULT_HEIGHT, proportions: dict[str, float] | None = None) -> dict[str, Vec]:
    """Named rest-pose points in metres (Blender axes) for placing geometry and IK targets.

    Keys: ``root, pelvis, spine_base, chest_base, neck_base, head_base, head_top, eye.L/R,
    sternum, shoulder.L/R, elbow.L/R, wrist.L/R, knuckles.L/R (middle knuckle), palm.L/R (palm
    centre), grip.L/R (centre of a closed fist / weapon grip), hip.L/R, knee.L/R, ankle.L/R,
    heel.L/R, ball.L/R, toe_tip.L/R``, plus every bone's head as ``<bone>`` and tail as
    ``<bone>:tail``."""
    k = scale_for(height)
    segs = bone_segments(height, proportions)
    out: dict[str, Vec] = {}
    for b, (h, t, _r) in segs.items():
        out[b] = h
        out[b + ":tail"] = t
    out.update({"root": segs["root"][0], "pelvis": segs["hips"][0], "spine_base": segs["spine"][0],
                "chest_base": segs["chest"][0], "neck_base": segs["neck"][0], "head_base": segs["head"][0],
                "head_top": segs["head"][1], "sternum": mul((0.0, 0.085, 1.42), k)})
    for sfx, sx in SIDES:
        out[f"eye.{sfx}"] = mul((sx * 0.0325, 0.0645, 1.666), k)
        out[f"shoulder.{sfx}"] = segs[f"upper_arm.{sfx}"][0]
        out[f"elbow.{sfx}"] = segs[f"forearm.{sfx}"][0]
        out[f"wrist.{sfx}"] = segs[f"hand.{sfx}"][0]
        out[f"knuckles.{sfx}"] = segs[f"middle_01.{sfx}"][0]
        hf = hand_frame(sx, height, proportions)
        out[f"palm.{sfx}"] = add(lerp(hf["origin"], segs[f"hand.{sfx}"][1], 0.55), mul(hf["palm"], 0.016 * k))
        out[f"grip.{sfx}"] = add(lerp(hf["origin"], segs[f"hand.{sfx}"][1], 0.85), mul(hf["palm"], 0.035 * k))
        out[f"hip.{sfx}"] = segs[f"thigh.{sfx}"][0]
        out[f"knee.{sfx}"] = segs[f"shin.{sfx}"][0]
        out[f"ankle.{sfx}"] = segs[f"foot.{sfx}"][0]
        a = segs[f"foot.{sfx}"][0]
        out[f"heel.{sfx}"] = (a[0], a[1] - 0.05 * k, 0.0)
        out[f"ball.{sfx}"] = segs[f"toe.{sfx}"][0]
        out[f"toe_tip.{sfx}"] = segs[f"toe.{sfx}"][1]
    return out


def build_rig(ctx_or_none=None, height: float = DEFAULT_HEIGHT,
              proportions: dict[str, float] | None = None):
    """Create the ``rig_humanoid`` armature (object and data both named so). Blender only.

    Returns the armature object in OBJECT mode, identity transform at the origin. ``ctx_or_none``
    (an ``AssetContext`` or ``None``) is accepted for API symmetry; nothing random is used."""
    import bpy  # noqa: PLC0415 - Blender-only part of an otherwise pure module
    from mathutils import Vector  # noqa: PLC0415

    from lib import scene  # noqa: PLC0415

    del ctx_or_none
    arm = bpy.data.armatures.new(ARMATURE_NAME)
    arm.display_type = "OCTAHEDRAL"
    obj = bpy.data.objects.new(ARMATURE_NAME, arm)
    scene.link(obj)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    segs = bone_segments(height, proportions)
    for bone in BONES:
        head, tail, roll = segs[bone]
        eb = arm.edit_bones.new(bone)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        eb.align_roll(Vector(roll))
        parent = PARENT[bone]
        if parent is not None:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
        eb.use_deform = bone != "root"
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
    obj.select_set(False)
    return obj
