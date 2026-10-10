"""`rig_humanoid`: the one shared character skeleton (docs/contracts/characters.md).

Not an asset script (no ASSET_ID): character scripts import it. The joint table is pure Python so
the body generator and the animation solver (``_anim.py``) can use it without Blender;
``create_armature()`` needs bpy.

Axes are Blender's: +Z up, +Y forward (= Godot -Z), the character's left side is -X
(``.L`` bones), right side +X (``.R``). Root at the feet (origin). Rest pose is an A-pose (arms
45 degrees below horizontal, palms facing the thighs, fingers slightly curled). Default height
1.78 m; variants scale the whole skeleton uniformly (``scale``), so every animation retargets 1:1
and Godot's ``Skeleton3D.motion_scale`` = ``scale`` keeps hip motion in proportion. Head and hands
are 1.03x realistic size (style guide §1).
"""

from __future__ import annotations

import math

DEFAULT_HEIGHT = 1.78
HEAD_HAND_SCALE = 1.03
ARM_DROP_DEG = 45.0

FINGERS = ("thumb", "index", "middle", "ring", "pinky")
SIDES = (("L", -1.0), ("R", 1.0))

# (bone, parent) in creation order. Exact contract names.
_CORE = [
    ("root", None), ("hips", "root"), ("spine", "hips"), ("chest", "spine"), ("neck", "chest"),
    ("head", "neck"),
]


def bone_order() -> list[tuple[str, str | None]]:
    out = list(_CORE)
    for sfx, _sx in SIDES:
        out += [(f"clavicle.{sfx}", "chest"), (f"upper_arm.{sfx}", f"clavicle.{sfx}"),
                (f"forearm.{sfx}", f"upper_arm.{sfx}"), (f"hand.{sfx}", f"forearm.{sfx}")]
        for f in FINGERS:
            out += [(f"{f}_01.{sfx}", f"hand.{sfx}"), (f"{f}_02.{sfx}", f"{f}_01.{sfx}"),
                    (f"{f}_03.{sfx}", f"{f}_02.{sfx}")]
    for sfx, _sx in SIDES:
        out += [(f"thigh.{sfx}", "hips"), (f"shin.{sfx}", f"thigh.{sfx}"), (f"foot.{sfx}", f"shin.{sfx}"),
                (f"toe.{sfx}", f"foot.{sfx}")]
    return out


BONE_NAMES = [b for b, _p in bone_order()]


# -- tiny vector helpers (no numpy needed) --------------------------------------------------
def _add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _mul(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def _norm(a):
    n = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])
    return (a[0] / n, a[1] / n, a[2] / n)


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _rot(v, axis, ang):
    """Rodrigues rotation of v about unit axis by ang radians."""
    c, s = math.cos(ang), math.sin(ang)
    d = v[0] * axis[0] + v[1] * axis[1] + v[2] * axis[2]
    cr = _cross(axis, v)
    return (v[0] * c + cr[0] * s + axis[0] * d * (1 - c),
            v[1] * c + cr[1] * s + axis[1] * d * (1 - c),
            v[2] * c + cr[2] * s + axis[2] * d * (1 - c))


def arm_frame(sx: float) -> dict[str, tuple[float, float, float]]:
    """Rest-pose arm/hand frame for side ``sx`` (-1 left, +1 right).

    ``a`` along the arm towards the fingers, ``l`` towards the thumb/index side (forward),
    ``p`` palm normal (palmar side, towards the thigh), ``d`` = -p (back of the hand)."""
    drop = math.radians(ARM_DROP_DEG)
    a = (sx * math.cos(drop), 0.0, -math.sin(drop))
    l_ = (0.0, 1.0, 0.0)
    p = (-sx * math.sin(drop), 0.0, -math.cos(drop))
    return {"a": a, "l": l_, "p": p, "d": _mul(p, -1.0)}


# Finger layout on the hand (fractions are of the hand scale): lateral offset along l (index +),
# knuckle distance from the wrist along a, phalanx lengths.
HAND_LEN = 0.095            # wrist -> middle knuckle line
HAND_WIDTH = 0.086          # knuckle width
FINGER_DATA = {
    # name: (lateral l, phalanx lengths)
    "index": (3.0 / 8.0, (0.040, 0.024, 0.020)),
    "middle": (1.0 / 8.0, (0.044, 0.028, 0.021)),
    "ring": (-1.0 / 8.0, (0.041, 0.026, 0.020)),
    "pinky": (-3.0 / 8.0, (0.032, 0.019, 0.018)),
}
THUMB_LENS = (0.046, 0.034, 0.029)
FINGER_REST_CURL = math.radians(9.0)    # per joint, towards the palm
THUMB_REST_CURL = math.radians(10.0)


def joints(scale: float = 1.0) -> dict[str, tuple[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float]]]:
    """{bone: (head, tail, roll_reference)} in metres for a skeleton of height 1.78 * scale.

    ``roll_reference`` is the vector the bone's local Z axis is aligned to (Blender align_roll)."""
    k = scale
    hh = HEAD_HAND_SCALE
    back = (0.0, -1.0, 0.0)
    up = (0.0, 0.0, 1.0)
    j: dict[str, tuple] = {}

    def put(name, head, tail, roll=back):
        j[name] = (_mul(head, k), _mul(tail, k), roll)

    put("root", (0, 0, 0), (0, 0, 0.15))
    put("hips", (0, 0.0, 0.96), (0, -0.005, 1.06))
    put("spine", (0, -0.005, 1.06), (0, -0.015, 1.22))
    put("chest", (0, -0.015, 1.22), (0, -0.02, 1.47))
    put("neck", (0, -0.02, 1.47), (0, 0.0, 1.565))
    put("head", (0, 0.0, 1.565), (0, 0.0, 1.765))
    for sfx, sx in SIDES:
        fr = arm_frame(sx)
        a, l_, p = fr["a"], fr["l"], fr["p"]
        put(f"clavicle.{sfx}", (sx * 0.025, 0.02, 1.43), (sx * 0.16, -0.02, 1.445))
        sh = (sx * 0.175, -0.02, 1.425)
        elbow = _add(sh, _mul(a, 0.29))
        elbow = _add(elbow, (0.0, -0.012, 0.0))
        fore_dir = _norm(_add(_mul(a, 0.255), (0.0, 0.03, 0.0)))
        wrist = _add(elbow, _mul(fore_dir, 0.255))
        put(f"upper_arm.{sfx}", sh, elbow)
        put(f"forearm.{sfx}", elbow, wrist)
        hand_tail = _add(wrist, _mul(a, HAND_LEN * hh))
        put(f"hand.{sfx}", wrist, hand_tail, roll=fr["d"])
        lat_axis = _norm(_cross(a, p))  # bending axis for curl: rotating a towards p
        for f, (lat, lens) in FINGER_DATA.items():
            knuckle_back = {"index": -0.003, "middle": 0.0, "ring": -0.004, "pinky": -0.012}[f]
            base = _add(wrist, _mul(a, (HAND_LEN + knuckle_back) * hh))
            base = _add(base, _mul(l_, lat * HAND_WIDTH * hh))
            d = a
            pos = base
            for i, ln in enumerate(lens):
                d = _norm(_rot(d, lat_axis, FINGER_REST_CURL))
                nxt = _add(pos, _mul(d, ln * hh))
                put(f"{f}_0{i + 1}.{sfx}", pos, nxt, roll=fr["d"])
                pos = nxt
        # Thumb: metacarpal from near the wrist on the index side, palmar.
        tb = _add(wrist, _add(_mul(a, 0.022 * hh), _add(_mul(l_, 0.024 * hh), _mul(p, 0.010 * hh))))
        d = _norm(_add(_mul(a, 0.62), _add(_mul(l_, 0.62), _mul(p, 0.48))))
        pos = tb
        th_axis = _norm(_cross(d, l_))
        for i, ln in enumerate(THUMB_LENS):
            if i > 0:
                d = _norm(_rot(d, th_axis, -THUMB_REST_CURL))
            nxt = _add(pos, _mul(d, ln * hh))
            put(f"thumb_0{i + 1}.{sfx}", pos, nxt, roll=_mul(l_, -1.0))
            pos = nxt
    for sfx, sx in SIDES:
        hip = (sx * 0.095, 0.0, 0.925)
        knee = (sx * 0.1, 0.012, 0.505)
        ankle = (sx * 0.105, -0.01, 0.085)
        ball = (sx * 0.11, 0.135, 0.022)
        toe = (sx * 0.11, 0.205, 0.022)
        put(f"thigh.{sfx}", hip, knee)
        put(f"shin.{sfx}", knee, ankle)
        put(f"foot.{sfx}", ankle, ball, roll=up)
        put(f"toe.{sfx}", ball, toe, roll=up)
    return j


def create_armature(name: str = "rig_humanoid", scale: float = 1.0):
    """Create the armature object (Blender only). Returns the object, in OBJECT mode."""
    import bpy  # noqa: PLC0415 - Blender-only part of an otherwise pure module
    from mathutils import Vector  # noqa: PLC0415

    from lib import scene  # noqa: PLC0415

    arm = bpy.data.armatures.new(name)
    arm.display_type = "STICK"
    obj = bpy.data.objects.new(name, arm)
    scene.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    table = joints(scale)
    for bone, parent in bone_order():
        head, tail, roll = table[bone]
        eb = arm.edit_bones.new(bone)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        eb.align_roll(Vector(roll))
        if parent is not None:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = (Vector(arm.edit_bones[parent].tail) - Vector(head)).length < 1e-6
        eb.use_deform = True
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return obj
