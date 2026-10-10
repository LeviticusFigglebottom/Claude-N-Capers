"""Deterministic procedural animation toolkit for ``rig_humanoid`` and ``rig_arms`` (D1-03).

Private helper (``_`` prefix), never built on its own. Everything above the "Blender glue" section
is numpy + math only (no ``bpy``), so clip definitions can be solved, checked and unit-tested with
the system python. Adopted and refactored from ENV C's WIP (``wip_from_c/_pose.py``/``_anims.py``):
the pose solver idea is kept; the bake no longer shares objects between frames, IK reach is checked
and fixed by lowering the hips, and the gait locks the stance foot exactly (zero sliding).

Axes and spaces (same as ``_rig``): Blender +X right, +Y forward (the character faces +Y = Godot
-Z), +Z up, metres, armature space = world space (the armature object sits at the origin).

How a pose is described (``Pose``)
* ``hip``: offset of the ``hips`` bone head from its rest position (m). The root never moves:
  every clip is **in place**.
* ``D[bone]``: an FK rotation in *rest-world axes*, applied in the parent's posed frame
  (``W[bone] = W[parent] @ D[bone]``). Helpers: ``rx/ry/rz`` (radians) and ``spine()``.
  Conventions: ``rx(-a)`` leans a vertical bone forward, ``ry(+a)`` tilts it to the character's
  right, ``rz(+a)`` turns it to the left; ``rx(+a)`` swings a hanging arm forward.
* ``local[bone]``: a rotation in the bone's own axes (Blender pose-bone space). Hinges flex about
  local X: elbow flexion = ``-a``, knee flexion = ``+a``, finger flexion = ``-a``, toe up = ``+a``.
* ``arms[sfx]`` / ``legs[sfx]``: two-bone IK goals (wrist / ankle position, absolute world
  rotation delta of the hand / foot, a pole = the direction the elbow / knee points).
* ``hands[sfx]``: a ``HandShape`` (finger curls in degrees).

``solve()`` returns, per bone, the world rotation delta ``W`` (posed axes = ``W @ B`` with ``B`` the
rest matrix), the posed head ``P`` and the Blender pose-bone quaternion ``local``
(``L = B^T W_parent^T W B``), plus the hips ``location`` (bone space).

Clips: ``Clip(name, frames, loop, fn, speed)``; ``fn(frame) -> Pose``. ``bake()`` solves every
frame 0..N, forces frame N == frame 0 on loops, keeps quaternion signs continuous and checks for
NaNs. ``Keys`` builds one-shots from key poses (limbs are interpolated as IK goals in chest / world
space, the trunk by slerp), so planted feet stay planted between keys.
"""

from __future__ import annotations

import dataclasses
import math
from collections.abc import Callable
from dataclasses import dataclass, field

import numpy as np

import _rig as rig

FPS = 30
TAU = 2.0 * math.pi
I3 = np.eye(3)
SIDES = (("L", -1.0), ("R", 1.0))


# =============================================================================================
# small math
# =============================================================================================
def v3(x: float, y: float, z: float) -> np.ndarray:
    return np.array((float(x), float(y), float(z)), dtype=np.float64)


def unit(v: np.ndarray) -> np.ndarray:
    n = float(np.linalg.norm(v))
    return v / n if n > 1e-12 else np.asarray(v, dtype=np.float64)


def rad(a: float) -> float:
    return math.radians(a)


def rot(axis, ang: float) -> np.ndarray:
    """Rotation matrix about unit ``axis`` by ``ang`` radians (right hand)."""
    x, y, z = unit(np.asarray(axis, dtype=np.float64))
    c, s = math.cos(ang), math.sin(ang)
    C = 1.0 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


def rx(a: float) -> np.ndarray:
    return rot((1.0, 0.0, 0.0), a)


def ry(a: float) -> np.ndarray:
    return rot((0.0, 1.0, 0.0), a)


def rz(a: float) -> np.ndarray:
    return rot((0.0, 0.0, 1.0), a)


def rxd(a: float) -> np.ndarray:
    return rx(rad(a))


def ryd(a: float) -> np.ndarray:
    return ry(rad(a))


def rzd(a: float) -> np.ndarray:
    return rz(rad(a))


def frame_from(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Orthonormal basis (columns) with first axis ``a`` and second ``b`` made perpendicular."""
    a = unit(np.asarray(a, dtype=np.float64))
    b = np.asarray(b, dtype=np.float64)
    b = unit(b - a * float(a @ b))
    return np.column_stack([a, b, np.cross(a, b)])


def align(a0, b0, a1, b1) -> np.ndarray:
    """The rotation that maps direction ``a0`` onto ``a1`` and the plane (a0, b0) onto (a1, b1)."""
    return frame_from(a1, b1) @ frame_from(a0, b0).T


def mat_to_quat(m: np.ndarray) -> np.ndarray:
    """3x3 rotation -> unit quaternion (w, x, y, z)."""
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0.0:
        s = math.sqrt(t + 1.0) * 2.0
        q = [0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2.0
        q = [(m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s]
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2.0
        q = [(m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s]
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2.0
        q = [(m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s]
    qa = np.array(q, dtype=np.float64)
    qa /= np.linalg.norm(qa)
    if qa[0] < 0.0:
        qa = -qa
    return qa


def quat_to_mat(q: np.ndarray) -> np.ndarray:
    w, x, y, z = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
                     [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
                     [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)]])


def slerp_q(q0: np.ndarray, q1: np.ndarray, t: float) -> np.ndarray:
    d = float(q0 @ q1)
    if d < 0.0:
        q1, d = -q1, -d
    if d > 0.9995:
        q = q0 + (q1 - q0) * t
        return q / np.linalg.norm(q)
    th = math.acos(min(1.0, d))
    s = math.sin(th)
    return (math.sin((1.0 - t) * th) * q0 + math.sin(t * th) * q1) / s


def mslerp(a: np.ndarray, b: np.ndarray, t: float) -> np.ndarray:
    """Slerp between two rotation matrices."""
    if t <= 0.0:
        return a
    if t >= 1.0:
        return b
    return quat_to_mat(slerp_q(mat_to_quat(a), mat_to_quat(b), t))


def mscale(m: np.ndarray, t: float) -> np.ndarray:
    """A fraction ``t`` of rotation ``m`` (same axis)."""
    return mslerp(I3, m, t)


def twist_angle(m: np.ndarray, axis: np.ndarray) -> float:
    """Signed twist of rotation ``m`` about unit ``axis`` (swing-twist decomposition)."""
    q = mat_to_quat(m)
    return 2.0 * math.atan2(float(q[1:] @ axis), float(q[0]))


def angle_of(m: np.ndarray) -> float:
    return 2.0 * math.acos(max(-1.0, min(1.0, float(mat_to_quat(m)[0]))))


# =============================================================================================
# curves
# =============================================================================================
def clamp01(x: float) -> float:
    return 0.0 if x < 0.0 else 1.0 if x > 1.0 else x


def smooth(e0: float, e1: float, x: float) -> float:
    """Smoothstep from 0 at ``e0`` to 1 at ``e1``."""
    if e1 == e0:
        return 1.0 if x >= e1 else 0.0
    t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def cos_ease(t: float) -> float:
    """Cosine ease in-out on [0, 1]."""
    return 0.5 - 0.5 * math.cos(math.pi * clamp01(t))


def ease_in(t: float, p: float = 2.0) -> float:
    return clamp01(t) ** p


def ease_out(t: float, p: float = 2.0) -> float:
    return 1.0 - (1.0 - clamp01(t)) ** p


def bezier1(t: float, y1: float, y2: float) -> float:
    """Cubic Bezier ease with control values y1, y2 (end points 0 and 1), uniform parameter."""
    t = clamp01(t)
    u = 1.0 - t
    return 3.0 * u * u * t * y1 + 3.0 * u * t * t * y2 + t * t * t


def hermite(p0: float, p1: float, m0: float, m1: float, u: float) -> float:
    u2, u3 = u * u, u * u * u
    return ((2 * u3 - 3 * u2 + 1) * p0 + (u3 - 2 * u2 + u) * m0 + (-2 * u3 + 3 * u2) * p1 + (u3 - u2) * m1)


def pulse(t: float, attack: float, decay: float) -> float:
    """0 -> 1 in ``attack`` s (smooth), then exponential-ish decay back to 0 over ``decay`` s."""
    if t <= 0.0:
        return 0.0
    if t < attack:
        return smooth(0.0, attack, t)
    x = (t - attack) / decay
    return 0.0 if x >= 1.0 else (1.0 - x) ** 2 * (1.0 + 2.0 * x) * math.exp(-1.5 * x)


def spring(t: float, freq: float = 3.0, zeta: float = 0.35) -> float:
    """Damped oscillation that starts at 1 (follow-through / settle), t in seconds."""
    if t <= 0.0:
        return 1.0
    w = TAU * freq
    return math.exp(-zeta * w * t) * math.cos(w * math.sqrt(max(1e-6, 1.0 - zeta * zeta)) * t)


def periodic(ph: float, k: int = 1, off: float = 0.0) -> float:
    """sin with ``k`` whole periods per cycle (loop-safe)."""
    return math.sin(TAU * (k * ph + off))


def lerp(a, b, t: float):
    return a + (b - a) * t


# =============================================================================================
# skeleton (rest data)
# =============================================================================================
class Skeleton:
    """Rest data: heads, tails, rest matrices ``B`` (columns = bone X, Y, Z in armature space,
    as Blender builds them with ``align_roll``), parents and a parents-first order."""

    def __init__(self, segs: dict, parent: dict, order: list[str], scale: float = 1.0) -> None:
        self.scale = scale
        self.order = list(order)
        self.parent = dict(parent)
        self.head = {b: np.array(segs[b][0], dtype=np.float64) for b in order}
        self.tail = {b: np.array(segs[b][1], dtype=np.float64) for b in order}
        self.B: dict[str, np.ndarray] = {}
        for b in order:
            y = unit(self.tail[b] - self.head[b])
            r = np.array(segs[b][2], dtype=np.float64)
            z = unit(r - y * float(y @ r))
            self.B[b] = np.column_stack([np.cross(y, z), y, z])
        self.bones = set(order)

    @classmethod
    def humanoid(cls, height: float = rig.DEFAULT_HEIGHT) -> Skeleton:
        return cls(rig.bone_segments(height), rig.PARENT, rig.BONES, rig.scale_for(height))

    def length(self, b: str) -> float:
        return float(np.linalg.norm(self.tail[b] - self.head[b]))

    def seg(self, a: str, b: str) -> float:
        """Distance between two bone heads (limb segment length)."""
        return float(np.linalg.norm(self.head[b] - self.head[a]))

    def axis(self, b: str, i: int) -> np.ndarray:
        """Rest-world direction of the bone's local axis i (0=X, 1=Y, 2=Z)."""
        return self.B[b][:, i].copy()

    def to_world(self, b: str, local_rot: np.ndarray) -> np.ndarray:
        """Bone-local rotation -> the same rotation in rest-world axes."""
        return self.B[b] @ local_rot @ self.B[b].T

    def ground(self, sfx: str) -> dict:
        """Rest contact points under a foot: ``heel`` and ``ball`` (z = 0), ``ankle``."""
        k = self.scale
        ankle = self.head[f"foot.{sfx}"]
        ball = self.head[f"toe.{sfx}"]
        return {"heel": v3(ankle[0], ankle[1] - 0.05 * k, 0.0), "ball": v3(ball[0], ball[1], 0.0),
                "ankle": ankle.copy(), "tip": v3(self.tail[f"toe.{sfx}"][0], self.tail[f"toe.{sfx}"][1], 0.0)}


# =============================================================================================
# pose description
# =============================================================================================
@dataclass
class HandShape:
    """Finger curls (degrees, added to the rest curl) per joint, plus spread and thumb control.

    ``curl[f] = (base, middle, tip)`` for f in index/middle/ring/pinky; ``thumb = (cmc_flex,
    mcp_flex, ip_flex)``; ``thumb_opp``: thumb swing across the palm (deg); ``spread``: extra
    finger fan (deg, + opens)."""

    curl: dict = field(default_factory=lambda: {f: (0.0, 0.0, 0.0) for f in ("index", "middle", "ring", "pinky")})
    thumb: tuple = (0.0, 0.0, 0.0)
    thumb_opp: float = 0.0
    spread: float = 0.0

    def blend(self, other: HandShape, t: float) -> HandShape:
        return HandShape(
            curl={f: tuple(lerp(a, b, t) for a, b in zip(self.curl[f], other.curl[f])) for f in self.curl},
            thumb=tuple(lerp(a, b, t) for a, b in zip(self.thumb, other.thumb)),
            thumb_opp=lerp(self.thumb_opp, other.thumb_opp, t), spread=lerp(self.spread, other.spread, t))


def hand_shape(kind: str, amount: float = 1.0) -> HandShape:
    """Preset hand shapes. ``amount`` scales the curls (0 = rest curl)."""
    a = amount
    if kind == "relaxed":     # idle: soft, slightly closed, pinky curls most
        c = {"index": (14, 18, 8), "middle": (18, 22, 10), "ring": (22, 26, 12), "pinky": (26, 30, 14)}
        th, opp, sp = (4, 8, 6), 6, -2
    elif kind == "fist":
        c = {f: (78, 95, 55) for f in ("index", "middle", "ring", "pinky")}
        th, opp, sp = (18, 30, 35), 34, -3
    elif kind == "loose_fist":  # running / tense
        c = {f: (52, 70, 40) for f in ("index", "middle", "ring", "pinky")}
        th, opp, sp = (12, 22, 25), 24, -3
    elif kind == "trigger":   # pistol / rifle grip, index on the trigger
        c = {"index": (22, 38, 14), "middle": (72, 92, 48), "ring": (76, 94, 50), "pinky": (78, 92, 48)}
        th, opp, sp = (10, 14, 12), 26, -2
    elif kind == "grip":      # closed on a bar / handguard / handle
        c = {"index": (62, 82, 42), "middle": (66, 86, 45), "ring": (68, 88, 46), "pinky": (70, 88, 46)}
        th, opp, sp = (14, 22, 22), 30, -2
    elif kind == "support":   # support hand around a pistol grip, thumb forward
        c = {"index": (58, 72, 34), "middle": (62, 78, 38), "ring": (64, 80, 40), "pinky": (64, 78, 38)}
        th, opp, sp = (4, 6, 4), 14, -3
    elif kind == "flat":      # open hand, fingers together (hands up, pushing)
        c = {f: (2, 2, 0) for f in ("index", "middle", "ring", "pinky")}
        th, opp, sp = (0, -4, -4), 2, 0
    elif kind == "spread":    # open, fingers apart (surrender, falling)
        c = {f: (-4, 0, 0) for f in ("index", "middle", "ring", "pinky")}
        th, opp, sp = (-6, -4, -4), -6, 10
    elif kind == "phone":     # holding a phone to the ear
        c = {"index": (34, 46, 22), "middle": (40, 52, 26), "ring": (46, 58, 30), "pinky": (52, 62, 32)}
        th, opp, sp = (10, 14, 10), 30, -2
    elif kind == "pinch":     # small object between thumb and index (cigarette, pager, card)
        c = {"index": (30, 34, 14), "middle": (38, 44, 18), "ring": (52, 60, 30), "pinky": (60, 66, 34)}
        th, opp, sp = (10, 16, 14), 30, -2
    elif kind == "claw":      # pain / struggling
        c = {f: (30, 55, 45) for f in ("index", "middle", "ring", "pinky")}
        th, opp, sp = (8, 20, 20), 18, 6
    else:
        raise ValueError(kind)
    return HandShape(curl={f: tuple(x * a for x in v) for f, v in c.items()},
                     thumb=tuple(x * a for x in th), thumb_opp=opp * a, spread=sp * a)


@dataclass
class LegIK:
    ankle: np.ndarray                         # world target of the ankle (foot bone head)
    foot: np.ndarray = field(default_factory=lambda: I3.copy())   # world rotation delta of the foot
    toe: float = 0.0                          # toe bend (rad, + = toes up relative to the foot)
    pole: np.ndarray | None = None            # knee direction; None = foot forward


@dataclass
class ArmIK:
    wrist: np.ndarray                         # world target of the wrist (hand bone head)
    hand: np.ndarray                          # world rotation delta of the hand
    pole: np.ndarray = field(default_factory=lambda: v3(0.0, -1.0, -0.4))   # elbow direction
    twist: float = 0.5                        # share of the wrist twist the forearm takes
    clav: float = 1.0                         # clavicle follow strength (0 = locked)


@dataclass
class Pose:
    hip: np.ndarray = field(default_factory=lambda: np.zeros(3))
    D: dict = field(default_factory=dict)
    local: dict = field(default_factory=dict)
    legs: dict = field(default_factory=dict)
    arms: dict = field(default_factory=dict)
    hands: dict = field(default_factory=dict)
    world: dict = field(default_factory=dict)   # bone -> (world rotation delta, head position): free props

    def copy(self) -> Pose:
        """Deep copy (arrays and IK goals are never shared between poses/frames)."""
        return Pose(hip=self.hip.copy(), D={k: m.copy() for k, m in self.D.items()},
                    local={k: m.copy() for k, m in self.local.items()},
                    legs={k: dataclasses.replace(g, ankle=g.ankle.copy(), foot=g.foot.copy(),
                                                 pole=None if g.pole is None else g.pole.copy())
                          for k, g in self.legs.items()},
                    arms={k: dataclasses.replace(g, wrist=g.wrist.copy(), hand=g.hand.copy(), pole=g.pole.copy())
                          for k, g in self.arms.items()},
                    hands={k: dataclasses.replace(h, curl=dict(h.curl)) for k, h in self.hands.items()},
                    world={k: (m.copy(), p.copy()) for k, (m, p) in self.world.items()})


@dataclass
class Solved:
    W: dict            # bone -> world rotation delta (3x3)
    P: dict            # bone -> posed head position
    local: dict        # bone -> pose-bone quaternion (w, x, y, z)
    hip_loc: np.ndarray   # hips pose-bone location (bone space)
    reach: float = 0.0    # worst IK reach error (m)
    loc: dict = field(default_factory=dict)   # bone -> pose-bone location (bone space), free props


# =============================================================================================
# pose helpers (authoring vocabulary)
# =============================================================================================
def side_x(sfx: str) -> float:
    return -1.0 if sfx == "L" else 1.0


def spine(pose: Pose, lean: float = 0.0, side: float = 0.0, twist: float = 0.0, chest_lean: float = 0.0,
          chest_side: float = 0.0, chest_twist: float = 0.0, neck: tuple = (0.0, 0.0, 0.0),
          head: tuple = (0.0, 0.0, 0.0), hips: tuple = (0.0, 0.0, 0.0)) -> None:
    """Trunk FK in degrees. lean > 0 bends forward, side > 0 bends to the right, twist > 0 turns
    left. ``hips``/``neck``/``head`` = (forward pitch, right roll, left yaw)."""
    def r(p: float, s: float, y: float) -> np.ndarray:
        return rzd(y) @ ryd(s) @ rxd(-p)
    pose.D["hips"] = r(*hips)
    pose.D["spine"] = r(lean, side, twist)
    pose.D["chest"] = r(chest_lean, chest_side, chest_twist)
    pose.D["neck"] = r(*neck)
    pose.D["head"] = r(*head)


def add_rot(pose: Pose, bone: str, m: np.ndarray) -> None:
    """Post-multiply an extra rest-world-axes rotation onto ``D[bone]``."""
    pose.D[bone] = pose.D.get(bone, I3) @ m


def arm_fk(sk: Skeleton, pose: Pose, sfx: str, add: float = 38.0, swing: float = 0.0, flex: float = 12.0,
           out: float = 0.0, twist: float = 0.0, clav_up: float = 0.0, clav_fwd: float = 0.0,
           wrist_flex: float = 0.0, wrist_dev: float = 0.0) -> None:
    """Hanging arm in degrees: adduct ``add`` from the A-pose, swing forward ``swing``, abduct
    ``out``, twist the upper arm ``twist`` (+ = internal rotation), bend the elbow ``flex``."""
    sx = side_x(sfx)
    pose.D[f"clavicle.{sfx}"] = rzd(sx * clav_fwd) @ ryd(-sx * clav_up)
    ua = unit(sk.tail[f"upper_arm.{sfx}"] - sk.head[f"upper_arm.{sfx}"])
    pose.D[f"upper_arm.{sfx}"] = rxd(swing) @ ryd(sx * (add - out)) @ rot(ua, rad(-sx * twist))
    pose.local[f"forearm.{sfx}"] = rxd(-flex)
    pose.local[f"hand.{sfx}"] = rxd(-wrist_flex) @ rzd(wrist_dev)
    pose.arms.pop(sfx, None)


def leg_fk(pose: Pose, sfx: str, swing: float = 0.0, out: float = 0.0, knee: float = 0.0, ankle: float = 0.0,
           toe: float = 0.0, twist: float = 0.0) -> None:
    """Free leg in degrees (falls, sitting on a table edge...): ``swing`` forward, ``out`` sideways,
    ``knee`` flexion, ``ankle`` (+ = toes up), ``toe`` bend."""
    sx = side_x(sfx)
    pose.D[f"thigh.{sfx}"] = rxd(swing) @ ryd(-sx * out) @ rzd(-sx * twist)
    pose.local[f"shin.{sfx}"] = rxd(knee)
    pose.local[f"foot.{sfx}"] = rxd(ankle)
    pose.local[f"toe.{sfx}"] = rxd(toe)
    pose.legs.pop(sfx, None)


def hand_rot(sk: Skeleton, sfx: str, along, palm) -> np.ndarray:
    """World rotation delta that points the hand (wrist -> knuckles) along ``along`` with the palm
    facing ``palm``."""
    hf = rig.hand_frame(side_x(sfx), rig.DEFAULT_HEIGHT)
    return align(np.array(hf["along"]), np.array(hf["palm"]), np.asarray(along, float), np.asarray(palm, float))


def arm_ik(sk: Skeleton, pose: Pose, sfx: str, wrist, along, palm, pole=None, twist: float = 0.5,
           clav: float = 1.0) -> None:
    sx = side_x(sfx)
    if pole is None:
        pole = v3(sx * 0.5, -0.5, -0.7)
    pose.arms[sfx] = ArmIK(wrist=np.asarray(wrist, float).copy(), hand=hand_rot(sk, sfx, along, palm),
                           pole=unit(np.asarray(pole, float)), twist=twist, clav=clav)
    pose.D.pop(f"clavicle.{sfx}", None)


def arm_ik_rot(pose: Pose, sfx: str, wrist, hand: np.ndarray, pole, twist: float = 0.5, clav: float = 1.0) -> None:
    pose.arms[sfx] = ArmIK(wrist=np.asarray(wrist, float).copy(), hand=hand.copy(), pole=unit(np.asarray(pole, float)),
                           twist=twist, clav=clav)
    pose.D.pop(f"clavicle.{sfx}", None)


def foot_rot(yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> np.ndarray:
    """Foot world rotation in degrees: yaw (+ = toes turn left), pitch (+ = toes up), roll
    (+ = sole faces left... i.e. the right edge goes down)."""
    return rzd(yaw) @ rxd(pitch) @ ryd(roll)


def plant(sk: Skeleton, pose: Pose, sfx: str, offset=(0.0, 0.0, 0.0), yaw: float = 0.0, pitch: float = 0.0,
          toe: float = 0.0, pole=None, pivot: str = "ankle") -> None:
    """Leg IK goal: the foot at its rest place moved by ``offset`` (m, world), turned by ``yaw``
    (deg, + = toes left) and pitched by ``pitch`` (deg, + = toes up) about ``pivot`` ("ankle",
    "heel" or "ball"). With ``pitch < 0`` about the ball the toes stay flat (``toe`` = -pitch)."""
    g = sk.ground(sfx)
    R = foot_rot(yaw, pitch)
    pv = g[pivot] if pivot != "ankle" else g["ankle"]
    ankle = pv + R @ (g["ankle"] - pv) + np.asarray(offset, float)
    if pole is None:
        pole = rzd(yaw) @ v3(side_x(sfx) * 0.12, 1.0, 0.0)
    pose.legs[sfx] = LegIK(ankle=ankle, foot=R, toe=rad(toe), pole=unit(np.asarray(pole, float)))


def stand(sk: Skeleton, pose: Pose, spread: float = 0.0, stagger_l: float = 0.0, stagger_r: float = 0.0,
          yaw_l: float = 6.0, yaw_r: float = 6.0) -> None:
    """Both feet flat: ``spread`` widens each foot outwards (m), staggers move them forward (m),
    yaw turns the toes outwards (deg)."""
    for sfx, st, yw in (("L", stagger_l, yaw_l), ("R", stagger_r, yaw_r)):
        sx = side_x(sfx)
        plant(sk, pose, sfx, (sx * spread, st, 0.0), yaw=-sx * yw)


def neutral(sk: Skeleton) -> Pose:
    """Relaxed standing pose (the base for most clips)."""
    pose = Pose()
    pose.hip = v3(0.0, 0.0, -0.012 * sk.scale)
    spine(pose)
    stand(sk, pose)
    for sfx in ("L", "R"):
        arm_fk(sk, pose, sfx)
        pose.hands[sfx] = hand_shape("relaxed")
    return pose


# =============================================================================================
# solver
# =============================================================================================
REACH_LIMIT = 0.9995


def _two_bone(p0: np.ndarray, target: np.ndarray, l1: float, l2: float, pole: np.ndarray):
    d_vec = target - p0
    dist = float(np.linalg.norm(d_vec))
    lo, hi = abs(l1 - l2) + 1e-4, (l1 + l2) * REACH_LIMIT
    d = min(max(dist, lo), hi)
    n = unit(d_vec) if dist > 1e-9 else v3(0.0, 0.0, -1.0)
    p = pole - n * float(n @ pole)
    if float(np.linalg.norm(p)) < 1e-6:
        p = np.cross(n, v3(1.0, 0.0, 0.0))
    p = unit(p)
    cos_a = (l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d)
    sin_a = math.sqrt(max(0.0, 1.0 - cos_a * cos_a))
    joint = p0 + n * l1 * cos_a + p * l1 * sin_a
    end = p0 + n * d
    return joint, end, n, p, float(np.linalg.norm(target - end))


class Solver:
    """Solves ``Pose`` objects for one ``Skeleton`` (rest bend planes are cached)."""

    def __init__(self, sk: Skeleton) -> None:
        self.sk = sk
        self.limbs: dict[tuple[str, str], tuple] = {}
        for sfx, _sx in SIDES:
            for kind, (a, b, c) in (("arm", ("upper_arm", "forearm", "hand")), ("leg", ("thigh", "shin", "foot"))):
                a_, b_, c_ = f"{a}.{sfx}", f"{b}.{sfx}", f"{c}.{sfx}"
                if a_ not in sk.bones:
                    continue
                r, j, e = sk.head[a_], sk.head[b_], sk.head[c_]
                u0, f0 = j - r, e - j
                n = unit(e - r)
                p0 = unit((j - r) - n * float(n @ (j - r)))
                bend_n = unit(np.cross(n, p0))
                self.limbs[(kind, sfx)] = (a_, b_, c_, u0, f0, bend_n, sk.seg(a_, b_), sk.seg(b_, c_))

    # -- fingers ---------------------------------------------------------------------------
    def _finger_local(self, b: str, shape: HandShape) -> np.ndarray:
        name, sfx = b.split(".")
        finger, idx = name.split("_0")
        i = int(idx) - 1
        if finger == "thumb":
            flex = shape.thumb[i]
            m = rxd(-flex)
            if i == 0:
                # swing across the palm about the thumb's own Z (towards the palm side)
                m = rzd(side_x(sfx) * -shape.thumb_opp * 0.6) @ rxd(-flex - shape.thumb_opp * 0.5)
            return m
        flex = shape.curl[finger][i]
        m = rxd(-flex)
        if i == 0 and shape.spread:
            fan = {"index": 1.0, "middle": 0.15, "ring": -0.6, "pinky": -1.2}[finger]
            m = rzd(side_x(sfx) * shape.spread * fan) @ m
        return m

    # -- main ------------------------------------------------------------------------------
    def solve(self, pose: Pose) -> Solved:
        sk = self.sk
        W: dict[str, np.ndarray] = {}
        P: dict[str, np.ndarray] = {}
        done: set[str] = set()
        locs: dict[str, np.ndarray] = {}
        reach = 0.0
        for b in sk.order:
            if b in done:
                continue
            par = sk.parent[b]
            if par is None:
                W[b] = pose.D.get(b, I3).copy()
                P[b] = sk.head[b].copy()
                continue
            P[b] = P[par] + W[par] @ (sk.head[b] - sk.head[par])
            if b in pose.world:
                Wd, Pw = pose.world[b]
                W[b] = Wd.copy()
                locs[b] = sk.B[b].T @ W[par].T @ (np.asarray(Pw, float) - P[b])
                P[b] = np.asarray(Pw, float).copy()
                continue
            if b == "hips":
                W[b] = W[par] @ pose.D.get("hips", I3)
                P[b] = P[b] + pose.hip
                continue
            base, _, sfx = b.partition(".")
            if base == "clavicle" and sfx in pose.arms and b not in pose.D:
                W[b] = W[par] @ self._clav_follow(pose, sfx, W[par], P[b])
                continue
            if base == "upper_arm" and sfx in pose.arms:
                reach = max(reach, self._limb(("arm", sfx), pose.arms[sfx], W, P, pose))
                done.update({f"forearm.{sfx}", f"hand.{sfx}"})
                continue
            if base == "thigh" and sfx in pose.legs:
                reach = max(reach, self._limb(("leg", sfx), pose.legs[sfx], W, P, pose))
                done.update({f"shin.{sfx}", f"foot.{sfx}", f"toe.{sfx}"})
                continue
            if b in pose.D:
                W[b] = W[par] @ pose.D[b]
            elif b in pose.local:
                W[b] = W[par] @ sk.to_world(b, pose.local[b])
            elif "_0" in base and sfx in pose.hands:
                W[b] = W[par] @ sk.to_world(b, self._finger_local(b, pose.hands[sfx]))
            else:
                W[b] = W[par].copy()
        local: dict[str, np.ndarray] = {}
        for b in sk.order:
            par = sk.parent[b]
            dw = W[b] if par is None else W[par].T @ W[b]
            local[b] = mat_to_quat(sk.B[b].T @ dw @ sk.B[b])
        hip_loc = sk.B["hips"].T @ pose.hip if "hips" in sk.bones else np.zeros(3)
        return Solved(W, P, local, hip_loc, reach, locs)

    def _clav_follow(self, pose: Pose, sfx: str, w_par: np.ndarray, p_clav: np.ndarray) -> np.ndarray:
        """Clavicle elevation / protraction from where the hand goes (shoulder girdle follow)."""
        sk = self.sk
        ik: ArmIK = pose.arms[sfx]
        if ik.clav <= 0.0:
            return I3
        sx = side_x(sfx)
        sh = p_clav + w_par @ (sk.head[f"upper_arm.{sfx}"] - sk.head[f"clavicle.{sfx}"])
        t_loc = w_par.T @ unit(ik.wrist - sh)          # target direction in the chest's rest frame
        elev = math.degrees(math.asin(max(-1.0, min(1.0, float(t_loc[2])))))
        fwd = float(t_loc[1])
        across = -sx * float(t_loc[0])                  # > 0: reaching across the body
        dist = float(np.linalg.norm(ik.wrist - sh))
        lim = self.limbs[("arm", sfx)]
        stretch = smooth(0.80, 1.0, dist / (lim[6] + lim[7]))
        up = ik.clav * (max(0.0, elev + 15.0) * 0.22)
        fw = ik.clav * (max(0.0, fwd) * 9.0 + max(0.0, across) * 10.0 + stretch * 8.0)
        up, fw = min(up, 24.0), min(fw, 22.0)
        return rzd(sx * fw) @ ryd(-sx * up)

    def _limb(self, key: tuple[str, str], ik, W: dict, P: dict, pose: Pose) -> float:
        sk = self.sk
        kind, sfx = key
        a, b, c, u0, f0, n0, l1, l2 = self.limbs[key]
        par = sk.parent[a]
        P[a] = P[par] + W[par] @ (sk.head[a] - sk.head[par])
        root = P[a]
        if kind == "arm":
            target, end_rot, pole = ik.wrist, ik.hand, ik.pole
        else:
            target, end_rot = ik.ankle, ik.foot
            pole = ik.pole if ik.pole is not None else unit(end_rot @ v3(side_x(sfx) * 0.1, 1.0, 0.0))
        joint, end, n1, p1, err = _two_bone(root, target, l1, l2, pole)
        u1, f1 = joint - root, end - joint
        bend1 = unit(np.cross(n1, p1))
        W[a] = align(u0, n0, u1, bend1)
        Wb = align(f0, n0, f1, bend1)
        if kind == "arm" and ik.twist:
            ax = unit(f1)
            tw = twist_angle(end_rot @ Wb.T, ax)
            tw = (tw + math.pi) % TAU - math.pi
            # near +-180 deg the twist is ambiguous and can flip between frames: fade the share out
            share = ik.twist * (1.0 - smooth(rad(120.0), rad(170.0), abs(tw)))
            Wb = rot(ax, tw * share) @ Wb
        W[b] = Wb
        P[b] = joint
        P[c] = end
        W[c] = end_rot.copy()
        if kind == "leg":
            toe = f"toe.{sfx}"
            if toe in sk.bones:
                W[toe] = W[c] @ sk.to_world(toe, rx(ik.toe))
                P[toe] = end + W[c] @ (sk.head[toe] - sk.head[c])
        return err


# =============================================================================================
# key-pose interpolation (one-shots)
# =============================================================================================
@dataclass
class Canon:
    """A solved pose in interpolatable form: trunk FK, limb goals (arms in the anchor bone's space,
    the chest, or the root for rig_arms; legs in world space), clavicles (anchor-relative), finger
    shapes and the leftover locals."""

    hip: np.ndarray
    D: dict
    local: dict
    arms: dict      # sfx -> (wrist, hand (3x3), pole, twist, clavicle (3x3)), anchor space
    legs: dict      # sfx -> (ankle, foot, toe, pole), world space
    hands: dict


TRUNK = ("root", "hips", "spine", "chest", "neck", "head")
_LIMB_LOCALS = {f"{n}.{sx}" for n in ("upper_arm", "forearm", "hand", "thigh", "shin", "foot", "toe")
                for sx in ("L", "R")}


def anchor_bone(sk: Skeleton) -> str:
    return "chest" if "chest" in sk.bones else "root"


def canon(solver: Solver, pose: Pose) -> Canon:
    sk = solver.sk
    s = solver.solve(pose)
    anc = anchor_bone(sk)
    aW, aP = s.W[anc], s.P[anc]
    arms = {}
    legs = {}
    for sfx, _sx in SIDES:
        if f"upper_arm.{sfx}" in sk.bones:
            ua, fa, hd = (f"{n}.{sfx}" for n in ("upper_arm", "forearm", "hand"))
            sh, el, wr = s.P[ua], s.P[fa], s.P[hd]
            n = unit(wr - sh)
            pole = unit((el - sh) - n * float(n @ (el - sh)))
            ik = pose.arms.get(sfx)
            twist = ik.twist if ik is not None else 0.5
            arms[sfx] = (aW.T @ (wr - aP), aW.T @ s.W[hd], aW.T @ pole, twist, aW.T @ s.W[f"clavicle.{sfx}"])
        if f"thigh.{sfx}" in sk.bones:
            th, sh_, ft, to = (f"{n_}.{sfx}" for n_ in ("thigh", "shin", "foot", "toe"))
            hp, kn, an = s.P[th], s.P[sh_], s.P[ft]
            n = unit(an - hp)
            kpole = unit((kn - hp) - n * float(n @ (kn - hp)))
            toe_q = s.local[to]
            toe_ang = 2.0 * math.atan2(float(toe_q[1]), float(toe_q[0]))
            legs[sfx] = (an.copy(), s.W[ft].copy(), toe_ang, kpole)
    D = {b: pose.D.get(b, I3).copy() for b in TRUNK if b in sk.bones}
    local = {b: m.copy() for b, m in pose.local.items() if b not in _LIMB_LOCALS and not b.startswith("clavicle")}
    return Canon(pose.hip.copy(), D, local, arms, legs,
                 {k: dataclasses.replace(h, curl=dict(h.curl)) for k, h in pose.hands.items()})


def canon_blend(a: Canon, b: Canon, t: float) -> Canon:
    D = {k: mslerp(a.D[k], b.D[k], t) for k in a.D}
    keys = sorted(set(a.local) | set(b.local))
    local = {k: mslerp(a.local.get(k, I3), b.local.get(k, I3), t) for k in keys}
    arms = {}
    for sfx in a.arms:
        wa, ha, pa, twa, cla = a.arms[sfx]
        wb, hb, pb, twb, clb = b.arms[sfx]
        arms[sfx] = (lerp(wa, wb, t), mslerp(ha, hb, t), unit(lerp(pa, pb, t) + v3(0, 0, 1e-9)),
                     lerp(twa, twb, t), mslerp(cla, clb, t))
    legs = {}
    for sfx in a.legs:
        aa, fa, ta, pa = a.legs[sfx]
        ab, fb, tb, pb = b.legs[sfx]
        legs[sfx] = (lerp(aa, ab, t), mslerp(fa, fb, t), lerp(ta, tb, t), unit(lerp(pa, pb, t) + v3(0, 0, 1e-9)))
    hands = {k: a.hands[k].blend(b.hands.get(k, a.hands[k]), t) for k in a.hands}
    return Canon(lerp(a.hip, b.hip, t), D, local, arms, legs, hands)


def from_canon(solver: Solver, c: Canon) -> Pose:
    """Rebuild a ``Pose`` from a ``Canon`` (arm goals are re-expressed once the trunk is solved)."""
    pose = Pose(hip=c.hip.copy(), D={k: m.copy() for k, m in c.D.items()},
                local={k: m.copy() for k, m in c.local.items()},
                hands={k: dataclasses.replace(h, curl=dict(h.curl)) for k, h in c.hands.items()})
    for sfx, (an, ft, toe, pole) in c.legs.items():
        pose.legs[sfx] = LegIK(ankle=an.copy(), foot=ft.copy(), toe=toe, pole=pole.copy())
    trunk = solver.solve(pose)                      # the anchor frame does not depend on the arms
    anc = anchor_bone(solver.sk)
    cw, cp = trunk.W[anc], trunk.P[anc]
    for sfx, (w, h, p, tw, clav_m) in c.arms.items():
        pose.arms[sfx] = ArmIK(wrist=cp + cw @ w, hand=cw @ h, pole=unit(cw @ p), twist=tw, clav=0.0)
        pose.D[f"clavicle.{sfx}"] = _clav_rel(solver, trunk, sfx, cw @ clav_m)
    return pose


def _clav_rel(solver: Solver, trunk: Solved, sfx: str, clav_world: np.ndarray) -> np.ndarray:
    par = solver.sk.parent[f"clavicle.{sfx}"]
    return trunk.W[par].T @ clav_world


EASES: dict[str, Callable[[float], float]] = {
    "linear": lambda t: clamp01(t), "inout": cos_ease, "in": ease_in, "out": ease_out,
    "smooth": lambda t: smooth(0.0, 1.0, t), "snap": lambda t: ease_out(t, 3.0),
    "heavy": lambda t: ease_in(t, 2.4), "settle": lambda t: bezier1(t, 0.9, 1.04),
}


class Keys:
    """One-shot from key poses: ``[(frame, Pose, ease_into_this_key), ...]`` (the first key's ease
    is ignored). ``post(frame, pose)`` (optional) adds procedural layers to the interpolated pose
    before it is solved (recoil, tremble, breathing)."""

    def __init__(self, solver: Solver, keys: list, post: Callable | None = None) -> None:
        self.solver = solver
        self.keys = [(int(f), canon(solver, p), e) for f, p, e in keys]
        self.post = post

    def __call__(self, f: int) -> Pose:
        ks = self.keys
        if f <= ks[0][0]:
            c = ks[0][1]
        elif f >= ks[-1][0]:
            c = ks[-1][1]
        else:
            c = ks[-1][1]
            for (f0, c0, _e0), (f1, c1, e1) in zip(ks[:-1], ks[1:]):
                if f0 <= f <= f1:
                    c = canon_blend(c0, c1, EASES[e1]((f - f0) / max(1, f1 - f0)))
                    break
        pose = from_canon(self.solver, c)
        if self.post is not None:
            self.post(f, pose)
        return pose


# =============================================================================================
# weapons and hand placement
# =============================================================================================
#: Weapon grip convention (both rigs). The weapon's origin (visual_slots.md QB-22: the firing-hand
#: pivot, grip centre plane, mid grip, 20 mm below the grip top) sits at this point of the
#: ``hand.R`` bone, in bone-local metres (X = towards the little-finger side for hand.R, Y = wrist
#: -> knuckles, Z = back of the hand): 76 % along the hand, 12 mm towards the thumb, 30 mm in front
#: of the palm. The grip axis (up the grip) runs along the hand's thumb side; the weapon's grip is
#: assumed raked GRIP_RAKE_DEG (Kestrel P9 18 deg; rifles 18-22 deg).
GRIP_ALONG = 0.76
GRIP_THUMB = 0.012
GRIP_PALM = 0.030
GRIP_RAKE_DEG = 18.0


def grip_offset(sk: Skeleton, sfx: str = "R") -> tuple[np.ndarray, np.ndarray]:
    """(R_off, t_off): the weapon frame (Blender weapon axes X right, Y muzzle, Z up as columns)
    and its origin, in ``hand.<sfx>`` bone-local coordinates."""
    k = sk.scale
    L = sk.length(f"hand.{sfx}")
    r = rad(GRIP_RAKE_DEG)
    sx = side_x(sfx)
    # bone-local thumb-side axis: -X on the right hand, +X on the left (see _rig: Z = back, Y = along)
    g = v3(-sx, 0.0, 0.0)
    along = v3(0.0, 1.0, 0.0)
    right = v3(0.0, 0.0, 1.0) * sx               # the back of the right hand faces the weapon's right
    muzzle = along * math.cos(r) + g * math.sin(r)
    up = -along * math.sin(r) + g * math.cos(r)
    R_off = np.column_stack([right, muzzle, up])
    t_off = v3(-sx * GRIP_THUMB * k, GRIP_ALONG * L, -GRIP_PALM * k)
    return R_off, t_off


def grip_offset_godot(sk: Skeleton, sfx: str = "R") -> tuple[tuple, tuple]:
    """The same offset as a Godot ``Transform3D`` relative to the bone: (basis columns x, y, z),
    origin. Godot weapon axes: X right, Y up, -Z muzzle; bone-local axes are unchanged by export."""
    R_off, t_off = grip_offset(sk, sfx)
    x, y, z = R_off[:, 0], R_off[:, 2], -R_off[:, 1]
    return (tuple(map(float, x)), tuple(map(float, y)), tuple(map(float, z))), tuple(map(float, t_off))


def weapon_frame(origin, yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    """(rotation, origin) of a weapon whose muzzle points along +Y, then yawed (deg, + = left),
    pitched (deg, + = muzzle up) and rolled (deg, + = canted right)."""
    return rzd(yaw) @ rxd(pitch) @ ryd(roll), np.asarray(origin, float).copy()


def wf_point(wf: tuple[np.ndarray, np.ndarray], p) -> np.ndarray:
    """A weapon-space point (Blender weapon axes, metres) in world space."""
    return wf[1] + wf[0] @ np.asarray(p, float)


def hold_weapon(sk: Skeleton, pose: Pose, wf: tuple[np.ndarray, np.ndarray], pole, sfx: str = "R",
                twist: float = 0.6, clav: float = 1.0) -> None:
    """Right-hand IK goal so the weapon origin sits in the hand per ``grip_offset``."""
    R_w, p_w = wf
    R_off, t_off = grip_offset(sk, sfx)
    A = R_w @ R_off.T                       # posed hand bone axes (columns) in world
    Dw = A @ sk.B[f"hand.{sfx}"].T
    wrist = p_w - A @ t_off
    arm_ik_rot(pose, sfx, wrist, Dw, pole, twist=twist, clav=clav)


def hand_on(sk: Skeleton, pose: Pose, sfx: str, point, along, palm, pole, along_share: float = 0.5,
            palm_off: float = 0.014, twist: float = 0.5, clav: float = 1.0) -> None:
    """IK goal that puts the palm surface point (``along_share`` of the hand bone, ``palm_off`` m in
    front of the bone) on ``point`` with the hand pointing ``along`` and the palm facing ``palm``."""
    Dw = hand_rot(sk, sfx, along, palm)
    A = Dw @ sk.B[f"hand.{sfx}"]
    local_pt = v3(0.0, along_share * sk.length(f"hand.{sfx}"), -palm_off * sk.scale)
    arm_ik_rot(pose, sfx, np.asarray(point, float) - A @ local_pt, Dw, pole, twist=twist, clav=clav)


def bone_point(s: Solved, sk: Skeleton, b: str, offset) -> np.ndarray:
    """World position of a point given in rest-world axes relative to bone ``b``'s head, carried
    by the solved bone."""
    return s.P[b] + s.W[b] @ np.asarray(offset, float)


# =============================================================================================
# locomotion (planted feet, zero sliding)
# =============================================================================================
@dataclass
class Gait:
    """A locomotion cycle. ``speed`` m/s along ``direction`` (body space, horizontal unit vector:
    (0, 1) forward, (1, 0) strafe right), ``frames`` per cycle (two steps), ``beta`` = stance share
    of the cycle per foot. The right foot strikes at phase 0, the left at 0.5.

    Stance: the contact point (heel, then ball) moves at exactly ``-speed * direction``. Swing: a
    Hermite curve whose end tangents match the ground speed (no velocity pop at lift-off or
    touch-down) plus a lift arc. ``centre[sfx]`` offsets each foot's stance span (m, body space)."""

    speed: float
    frames: int
    beta: float = 0.6
    direction: tuple = (0.0, 1.0)
    lift: float = 0.08
    lift_skew: float = 0.75
    strike: float = 16.0          # foot pitch at touch-down (deg, + = toes up: heel strike)
    toeoff: float = -32.0         # foot pitch at lift-off (deg, - = heel up: roll over the ball)
    flat_at: float = 0.16         # stance share at which the foot is flat after the strike
    heel_rise: float = 0.58       # stance share at which the heel starts to rise
    swing_match: float = 0.8      # share of the ground speed kept at swing ends
    centre: dict = field(default_factory=lambda: {"L": (0.0, 0.0), "R": (0.0, 0.0)})
    width: float = 0.0            # extra lateral foot offset outwards (m)
    toe_out: float = 6.0          # foot yaw outwards (deg)
    swing_toe_up: float = 8.0     # extra toe lift in mid-swing (deg)
    drop: float = 0.03            # hips lowered (m)
    bob: float = 0.016            # vertical hip bob amplitude (m)
    run: bool = False             # flight phase: hips low at mid-stance
    sway: float = 0.018           # lateral hip shift over the stance foot (m)
    pelvis_yaw: float = 5.0
    pelvis_roll: float = 3.0
    lean: float = 3.0
    chest_counter: float = 1.3    # chest twist against the pelvis yaw (x pelvis yaw)
    arm_swing: float = 16.0
    arm_add: float = 34.0
    elbow: float = 14.0
    elbow_swing: float = 10.0
    arm_lag: float = 0.04         # arm phase delay (cycle share)
    hand: str = "relaxed"
    hand_amount: float = 1.0
    head_bob_comp: float = 0.6    # how much the head counters the trunk pitch bob
    upper: Callable | None = None  # upper(sk, pose, ph, f): override arms / trunk
    exact_pivot: bool = False     # rotate the foot (yaw included) about its contact point: zero slide at
                                  # any toe_out (False keeps the D1-03 formula, exact only for small toe_out)

    @property
    def stride(self) -> float:
        """Ground distance per cycle (m) at the authored speed."""
        return self.speed * self.frames / FPS

    def foot(self, sk: Skeleton, sfx: str, ph: float) -> tuple[np.ndarray, np.ndarray, float, bool]:
        """(ankle, foot rotation, toe bend rad, in stance) for one foot at its own phase
        (0 = touch-down)."""
        k = sk.scale
        T = self.frames / FPS
        D = self.speed * self.beta * T                     # contact travel during stance (m)
        dirv = np.array([self.direction[0], self.direction[1], 0.0])
        sx = side_x(sfx)
        cx, cy = self.centre.get(sfx, (0.0, 0.0))
        base = v3(sx * self.width * k + cx * k, cy * k, 0.0)
        g = sk.ground(sfx)
        yaw = -sx * self.toe_out
        if ph < self.beta:
            u = ph / self.beta
            d = D * (0.5 - u)
            pitch = self.strike * (1.0 - smooth(0.0, self.flat_at, u)) + self.toeoff * smooth(self.heel_rise, 1.0, u)
            lift = 0.0
            stance = True
            toe = max(0.0, -pitch) if self.toeoff < 0 else 0.0
        else:
            w = (ph - self.beta) / (1.0 - self.beta)
            Ts = (1.0 - self.beta) * T
            m = -self.speed * Ts * self.swing_match
            d = hermite(-D / 2.0, D / 2.0, m, m, w)
            pitch = self.toeoff + (self.strike - self.toeoff) * smooth(0.05, 0.9, w)
            pitch += self.swing_toe_up * math.sin(math.pi * w)      # toes up through mid-swing
            lift = self.lift * k * math.sin(math.pi * clamp01(w) ** self.lift_skew)
            stance = False
            toe = max(0.0, -self.toeoff) * (1.0 - smooth(0.0, 0.45, w))
        R = foot_rot(yaw, pitch)
        pivot = g["heel"] if pitch >= 0.0 else g["ball"]
        if self.exact_pivot:
            ankle = pivot + dirv * d + base + R @ (g["ankle"] - pivot) + v3(0.0, 0.0, lift)
        else:
            ankle = pivot + dirv * d + base + R @ rzd(-yaw) @ (g["ankle"] - pivot) + v3(0.0, 0.0, lift)
        return ankle, R, rad(toe), stance

    def contact(self, sk: Skeleton, sfx: str, ph: float) -> np.ndarray | None:
        """World contact point of a stance foot (for the sliding check)."""
        ankle, R, _t, stance = self.foot(sk, sfx, ph)
        if not stance:
            return None
        g = sk.ground(sfx)
        pitch = math.degrees(math.atan2(float((R @ v3(0, 1, 0))[2]), float(np.hypot(*(R @ v3(0, 1, 0))[:2]))))
        pivot = g["heel"] if pitch >= 0 else g["ball"]
        return ankle + R @ (pivot - g["ankle"])

    def pose(self, sk: Skeleton, f: int) -> Pose:
        k = sk.scale
        N = self.frames
        ph = (f % N) / N
        pose = Pose()
        b2 = self.beta / 2.0
        if self.run:
            bob = -self.bob * k * math.cos(TAU * 2.0 * (ph - b2))
        else:
            bob = -self.bob * k * math.cos(TAU * 2.0 * ph)
        sway = self.sway * k * math.cos(TAU * (ph - b2))
        side = np.array([self.direction[1], -self.direction[0], 0.0])   # body right of travel
        del side
        pose.hip = v3(sway, 0.0, -self.drop * k + bob)
        yaw = self.pelvis_yaw * math.cos(TAU * ph)
        roll = -self.pelvis_roll * math.cos(TAU * (ph - b2))
        lean = self.lean
        trunk_pitch = 1.2 * math.cos(TAU * 2.0 * (ph - b2 - 0.1)) * (1.0 if self.run else 0.5)
        spine(pose, lean=lean * 0.5 + trunk_pitch * 0.5, twist=-yaw * 0.45, side=-roll * 0.5,
              chest_lean=lean * 0.5 + trunk_pitch * 0.5, chest_twist=-yaw * (self.chest_counter - 0.45),
              neck=(-lean * 0.45, 0.0, 0.0),
              head=(-lean * 0.45 - trunk_pitch * self.head_bob_comp, roll * 0.3, -yaw * (1.0 - self.chest_counter) * 0.8),
              hips=(lean * 0.25, roll, yaw))
        for sfx, off in (("R", 0.0), ("L", 0.5)):
            ankle, R, toe, _st = self.foot(sk, sfx, (ph + 1.0 - off) % 1.0)
            pose.legs[sfx] = LegIK(ankle=ankle, foot=R, toe=toe,
                                   pole=unit(rzd(-side_x(sfx) * self.toe_out * 0.6) @ v3(side_x(sfx) * 0.08, 1.0, 0.0)))
        aph = ph - self.arm_lag
        for sfx, sgn in (("R", -1.0), ("L", 1.0)):
            sw = sgn * self.arm_swing * math.cos(TAU * aph)
            fwd = max(0.0, sw / max(self.arm_swing, 1e-3))
            arm_fk(sk, pose, sfx, add=self.arm_add, swing=sw + 2.0, flex=self.elbow + self.elbow_swing * fwd,
                   twist=6.0, clav_fwd=1.5 * sw / max(self.arm_swing, 1e-3))
            pose.hands[sfx] = hand_shape(self.hand, self.hand_amount)
        if self.upper is not None:
            self.upper(sk, pose, ph, f)
        return pose


# =============================================================================================
# clips and baking
# =============================================================================================
@dataclass
class Clip:
    name: str
    frames: int                    # duration in frames (keys at 0..frames inclusive)
    loop: bool
    fn: Callable[[int], Pose]
    speed: float = 0.0             # intended locomotion speed (m/s at 1.78 m), 0 = stationary
    gait: Gait | None = None
    events: dict = field(default_factory=dict)   # name -> frame (sound / gameplay sync)
    reach_fix: bool = True         # lower the hips where a planted foot is out of reach
    floor: int | None = None       # from this frame on (negative = from the end) the body rests on z = 0
    no_sink: bool = False          # lift any frame whose skinned body would go below z = 0
    note: str = ""

    @property
    def seconds(self) -> float:
        return self.frames / FPS


@dataclass
class Baked:
    clip: Clip
    frames: list[Solved]
    checks: dict


def fix_hips_for_reach(solver: Solver, poses: list[Pose], loop: bool, margin: float = 0.993,
                       max_drop: float = 0.10) -> None:
    """Lower the hips (smoothly, cyclically for loops) wherever a leg goal is out of reach."""
    sk = solver.sk
    need = np.zeros(len(poses))
    for i, pose in enumerate(poses):
        if not pose.legs:
            continue
        s = solver.solve(pose)
        worst = 0.0
        for sfx, ik in pose.legs.items():
            hip = s.P[f"thigh.{sfx}"]
            lim = solver.limbs[("leg", sfx)]
            L = (lim[6] + lim[7]) * margin
            d = ik.ankle - hip
            horiz = float(np.hypot(d[0], d[1]))
            if horiz >= L:
                continue                    # not fixable by lowering the hips: reported as reach error
            vert_max = math.sqrt(L * L - horiz * horiz)
            worst = max(worst, -d[2] - vert_max)
        need[i] = max(0.0, worst)
    if not need.any():
        return
    n = len(poses)
    # dilate then blur so the correction is smooth and never smaller than needed
    width = 4
    dil = np.array([max(need[(i + j) % n] if loop else need[min(max(i + j, 0), n - 1)]
                        for j in range(-width, width + 1)) for i in range(n)])
    ker = np.array([math.exp(-0.5 * (j / 2.0) ** 2) for j in range(-width, width + 1)])
    ker /= ker.sum()
    out = np.zeros(n)
    for i in range(n):
        acc = 0.0
        for j, kv in zip(range(-width, width + 1), ker):
            idx = (i + j) % n if loop else min(max(i + j, 0), n - 1)
            acc += kv * dil[idx]
        out[i] = min(max(acc, need[i]), max_drop)
    for pose, dz in zip(poses, out):
        pose.hip = pose.hip - v3(0.0, 0.0, float(dz) + (0.0005 if dz > 0 else 0.0))


class SkinProbe:
    """Linear-blend skinning of the base body mesh (``_body``, pure math) for floor contact:
    ``lowest(solved)`` = the lowest posed vertex z. Built once per height."""

    def __init__(self, sk: Skeleton, params: dict | None = None, margin: float = 0.006) -> None:
        import _body as body  # noqa: PLC0415 - heavy, only when floor contact is needed

        p = body.body_params(params or {"height": rig.DEFAULT_HEIGHT * sk.scale})
        data, _hair = body.body_mesh_data(p)
        weights = body.body_weights(data)
        self.margin = margin
        self.verts = np.array(data.blend, dtype=np.float64)
        bones = [b for b in sk.order if b != "root"]
        self.index = {b: i for i, b in enumerate(bones)}
        self.bones = bones
        n = len(self.verts)
        self.w = np.zeros((n, 4))
        self.bi = np.zeros((n, 4), dtype=np.int64)
        for v, wd in enumerate(weights):
            for j, (b, x) in enumerate(sorted(wd.items(), key=lambda kv: -kv[1])[:4]):
                self.bi[v, j] = self.index[b]
                self.w[v, j] = x
        self.heads = np.array([sk.head[b] for b in bones])

    def posed(self, s: Solved) -> np.ndarray:
        W = np.array([s.W[b] for b in self.bones])          # (B, 3, 3)
        P = np.array([s.P[b] for b in self.bones])          # (B, 3)
        out = np.zeros_like(self.verts)
        for j in range(4):
            idx = self.bi[:, j]
            rel = self.verts - self.heads[idx]
            out += self.w[:, j:j + 1] * (np.einsum("nij,nj->ni", W[idx], rel) + P[idx])
        return out

    def lowest(self, s: Solved) -> float:
        return float(self.posed(s)[:, 2].min()) - self.margin


def lift(pose: Pose, dz: float) -> None:
    """Translate the whole posed body vertically (hips and every IK goal)."""
    d = v3(0.0, 0.0, dz)
    pose.hip = pose.hip + d
    for g in pose.legs.values():
        g.ankle = g.ankle + d
    for g in pose.arms.values():
        g.wrist = g.wrist + d


_PROBES: dict[float, SkinProbe] = {}


def probe_for(sk: Skeleton) -> SkinProbe:
    key = round(sk.scale, 6)
    if key not in _PROBES:
        _PROBES[key] = SkinProbe(sk)
    return _PROBES[key]


def bake(solver: Solver, clip: Clip) -> Baked:
    """Solve every frame (0..N inclusive). Loops: frame N is frame 0. Quaternion signs are made
    continuous; NaNs raise. Returns per-frame ``Solved`` plus check results."""
    N = clip.frames
    poses = [clip.fn(f).copy() for f in range(N + 1)]
    if clip.loop:
        poses[N] = poses[0].copy()
    if clip.reach_fix:
        fix_hips_for_reach(solver, poses[:N] if clip.loop else poses, clip.loop)
        if clip.loop:
            poses[N] = poses[0].copy()
    if clip.no_sink:
        # nothing goes through the floor at any frame (lift only, never lower)
        probe = probe_for(solver.sk)
        for f in range(N + 1):
            for _it in range(3):
                low = probe.lowest(solver.solve(poses[f]))
                if low >= -2e-4:
                    break
                lift(poses[f], -low)
    if clip.floor is not None:
        # rest the body on the floor: from frame ``floor`` on, the lowest skinned vertex is at z = 0
        probe = probe_for(solver.sk)
        start = clip.floor if clip.floor >= 0 else N + 1 + clip.floor
        ramp = 4
        for f in range(max(0, start - ramp), N + 1):
            if clip.loop and f == N:
                break
            w = 1.0 if f >= start else (f - (start - ramp)) / ramp
            for _it in range(3):
                low = probe.lowest(solver.solve(poses[f]))
                if abs(low) < 2e-4:
                    break
                lift(poses[f], -low * w if low > 0 else -low)
        if clip.loop:
            poses[N] = poses[0].copy()
    frames: list[Solved] = []
    for pose in poses:
        s = solver.solve(pose)
        frames.append(Solved({b: m.copy() for b, m in s.W.items()}, {b: p.copy() for b, p in s.P.items()},
                             {b: q.copy() for b, q in s.local.items()}, s.hip_loc.copy(), s.reach,
                             {b: x.copy() for b, x in s.loc.items()}))
    if clip.loop:
        frames[N] = Solved({b: m.copy() for b, m in frames[0].W.items()}, {b: p.copy() for b, p in frames[0].P.items()},
                           {b: q.copy() for b, q in frames[0].local.items()}, frames[0].hip_loc.copy(), frames[0].reach,
                           {b: x.copy() for b, x in frames[0].loc.items()})
    max_step = 0.0
    for i in range(1, len(frames)):
        prev, cur = frames[i - 1], frames[i]
        for b, q in cur.local.items():
            if float(q @ prev.local[b]) < 0.0:
                cur.local[b] = -q
            if b in cur.loc:
                continue                # free props (magazine) may teleport off screen
            ang = 2.0 * math.degrees(math.acos(min(1.0, abs(float(cur.local[b] @ prev.local[b])))))
            max_step = max(max_step, ang)
    for s in frames:
        for b, q in s.local.items():
            if not np.all(np.isfinite(q)):
                raise ValueError(f"{clip.name}: NaN in {b}")
        if not np.all(np.isfinite(s.hip_loc)):
            raise ValueError(f"{clip.name}: NaN in the hips location")
    checks = {"max_reach_err_m": max(s.reach for s in frames), "max_joint_step_deg": max_step,
              "min_bone_z_m": min(min(float(p[2]) for p in s.P.values()) for s in frames)}
    if clip.gait is not None:
        checks["max_foot_slide_mm"] = foot_slide(solver, clip, frames)
    return Baked(clip, frames, checks)


def foot_slide(solver: Solver, clip: Clip, frames: list[Solved]) -> float:
    """Worst deviation (mm per frame) of a stance foot's contact point from the ideal ground
    motion (``-speed * direction`` per frame), measured on the solved skeleton."""
    g = clip.gait
    sk = solver.sk
    dirv = np.array([g.direction[0], g.direction[1], 0.0])
    step = -dirv * g.speed / FPS * sk.scale
    worst = 0.0
    for sfx, off in (("R", 0.0), ("L", 0.5)):
        prev = None
        for f, s in enumerate(frames):
            ph = ((f % g.frames) / g.frames + 1.0 - off) % 1.0
            ankle, R, _t, stance = g.foot(sk, sfx, ph)
            if not stance:
                prev = None
                continue
            gp = sk.ground(sfx)
            fwd = R @ v3(0, 1, 0)
            pivot = gp["heel"] if fwd[2] >= 0 else gp["ball"]
            # contact point as carried by the SOLVED foot bone
            cp = s.P[f"foot.{sfx}"] + s.W[f"foot.{sfx}"] @ (pivot - gp["ankle"])
            if prev is not None and prev[1] == (fwd[2] >= 0):
                dev = float(np.linalg.norm((cp - prev[0]) - step)) * 1000.0
                worst = max(worst, dev)
            prev = (cp, fwd[2] >= 0)
    return worst


# =============================================================================================
# Blender glue
# =============================================================================================
def write_action(arm_obj, baked: Baked, action_name: str, bones: list[str] | None = None):
    """Create a Blender action with one LINEAR key per frame for every bone (quaternion; hips also
    location), assign it a slot on ``arm_obj`` and push it to its own NLA track. Returns it."""
    import bpy  # noqa: PLC0415

    act = bpy.data.actions.new(action_name)
    act.use_fake_user = True
    ad = arm_obj.animation_data or arm_obj.animation_data_create()
    ad.action = act
    n = len(baked.frames)
    frames = [float(f) for f in range(n)]
    names = bones or [pb.name for pb in arm_obj.pose.bones]
    for b in names:
        path = f'pose.bones["{b}"].rotation_quaternion'
        for i in range(4):
            fc = act.fcurve_ensure_for_datablock(arm_obj, path, index=i)
            fc.keyframe_points.add(n)
            co = [c for f, s in zip(frames, baked.frames) for c in (f, float(s.local[b][i]))]
            fc.keyframe_points.foreach_set("co", co)
            fc.keyframe_points.foreach_set("interpolation", [1] * n)   # LINEAR
            fc.update()
        if b == "hips" or b in baked.frames[0].loc:
            path = f'pose.bones["{b}"].location'

            def lv(s, i, b=b):
                return float(s.hip_loc[i]) if b == "hips" else float(s.loc.get(b, np.zeros(3))[i])
            for i in range(3):
                fc = act.fcurve_ensure_for_datablock(arm_obj, path, index=i)
                fc.keyframe_points.add(n)
                co = [c for f, s in zip(frames, baked.frames) for c in (f, lv(s, i))]
                fc.keyframe_points.foreach_set("co", co)
                fc.keyframe_points.foreach_set("interpolation", [1] * n)
                fc.update()
    if baked.clip.loop:
        for fc in act.fcurves:
            fc.modifiers.new("CYCLES")
    act.frame_range = (0.0, float(n - 1))
    act.use_frame_range = True
    track = ad.nla_tracks.new()
    track.name = action_name
    strip = track.strips.new(action_name, 0, act)
    strip.extrapolation = "NOTHING"
    track.mute = True
    ad.action = None
    return act


def apply_frame(arm_obj, s: Solved) -> None:
    """Pose the armature with one solved frame (for previews / renders)."""
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
        q = s.local[pb.name]
        pb.rotation_quaternion = (float(q[0]), float(q[1]), float(q[2]), float(q[3]))
        if pb.name == "hips":
            pb.location = tuple(float(x) for x in s.hip_loc)
        elif pb.name in s.loc:
            pb.location = tuple(float(x) for x in s.loc[pb.name])
