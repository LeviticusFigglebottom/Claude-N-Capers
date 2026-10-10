"""Pose solver for ``rig_humanoid`` (pure numpy).

A pose is described in intuitive terms (``PoseSpec``): a hip offset, rotations of the spine
chain and of FK limbs in *rest-world axes* (Blender axes: +X right, +Y forward, +Z up), and IK
targets for ankles (+ foot orientation) and wrists (+ hand orientation, elbow pole). ``solve()``
turns it into per-bone local quaternions (Blender pose-bone space) plus the hips location, ready
to be keyed. Every bone's world rotation delta is ``W_bone = W_parent @ D_bone``; the local pose
rotation is ``L = B^T D B`` with ``B`` the bone's rest matrix.

Rotation helpers: ``rx(a)`` pitches about +X (positive leans a vertical bone backwards, swings a
hanging leg/arm forwards), ``ry(a)`` rolls about +Y (positive tips +Z towards +X... i.e. the
character's right side goes down), ``rz(a)`` yaws about +Z (positive turns left).
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

import rig

I3 = np.eye(3)


def unit(v: np.ndarray) -> np.ndarray:
    n = float(np.linalg.norm(v))
    return v / n if n > 1e-12 else v


def rot(axis, ang: float) -> np.ndarray:
    a = unit(np.asarray(axis, dtype=np.float64))
    x, y, z = a
    c, s = math.cos(ang), math.sin(ang)
    C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


def rx(a: float) -> np.ndarray:
    return rot((1, 0, 0), a)


def ry(a: float) -> np.ndarray:
    return rot((0, 1, 0), a)


def rz(a: float) -> np.ndarray:
    return rot((0, 0, 1), a)


def deg(a: float) -> float:
    return math.radians(a)


def frame_from(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Orthonormal basis with first axis ``a`` and second axis ``b`` projected perpendicular."""
    a = unit(a)
    b = unit(b - a * (a @ b))
    return np.column_stack([a, b, np.cross(a, b)])


def align(a0, b0, a1, b1) -> np.ndarray:
    """Rotation mapping the frame (a0, b0) onto (a1, b1)."""
    return frame_from(np.asarray(a1, float), np.asarray(b1, float)) @ frame_from(np.asarray(a0, float), np.asarray(b0, float)).T


def mat_to_quat(m: np.ndarray) -> np.ndarray:
    """3x3 rotation -> quaternion (w, x, y, z), w >= 0 not enforced (caller keeps continuity)."""
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        q = [0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = [(m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s]
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = [(m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s]
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = [(m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s]
    q = np.array(q)
    return q / np.linalg.norm(q)


def quat_to_mat(q: np.ndarray) -> np.ndarray:
    w, x, y, z = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
                     [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
                     [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)]])


def slerp(q0: np.ndarray, q1: np.ndarray, t: float) -> np.ndarray:
    d = float(q0 @ q1)
    if d < 0:
        q1, d = -q1, -d
    if d > 0.9995:
        q = q0 + (q1 - q0) * t
        return q / np.linalg.norm(q)
    th = math.acos(min(1.0, d))
    s = math.sin(th)
    return (math.sin((1 - t) * th) * q0 + math.sin(t * th) * q1) / s


# ------------------------------------------------------------------------------------------
@dataclass
class LegIK:
    ankle: np.ndarray                       # world target of the ankle (foot bone head)
    foot: np.ndarray = field(default_factory=lambda: I3.copy())   # world rotation delta of the foot
    toe: float = 0.0                        # toe bend (rad, + = toes up relative to the foot)
    pole: np.ndarray = field(default_factory=lambda: np.array([0.0, 1.0, 0.0]))


@dataclass
class ArmIK:
    wrist: np.ndarray                       # world target of the wrist (hand bone head)
    hand: np.ndarray                        # world rotation delta of the hand
    pole: np.ndarray = field(default_factory=lambda: np.array([0.0, -1.0, -0.5]))
    twist_share: float = 0.5                # part of the wrist twist the forearm takes


@dataclass
class PoseSpec:
    hip: np.ndarray = field(default_factory=lambda: np.zeros(3))     # offset of the hips head (m)
    D: dict = field(default_factory=dict)       # bone -> 3x3 rotation in rest-world axes (FK)
    legs: dict = field(default_factory=dict)    # "L"/"R" -> LegIK
    arms: dict = field(default_factory=dict)    # "L"/"R" -> ArmIK
    curl: dict = field(default_factory=dict)    # "L"/"R" -> (thumb, index, middle, ring, pinky) 0..1


class Skeleton:
    """Rest data for one rig scale (heads, tails, rest matrices B as Blender computes them)."""

    def __init__(self, scale: float = 1.0, rest_mats: dict | None = None) -> None:
        self.scale = scale
        table = rig.joints(scale)
        self.order = rig.bone_order()
        self.parent = {b: p for b, p in self.order}
        self.head = {b: np.array(t[0], dtype=np.float64) for b, t in table.items()}
        self.tail = {b: np.array(t[1], dtype=np.float64) for b, t in table.items()}
        self.B: dict[str, np.ndarray] = {}
        for b, (h, t, roll) in table.items():
            if rest_mats is not None:
                self.B[b] = np.array(rest_mats[b], dtype=np.float64)
            else:
                y = unit(np.array(t) - np.array(h))
                z = unit(np.array(roll) - y * (y @ np.array(roll)))
                self.B[b] = np.column_stack([np.cross(y, z), y, z])
        hh = rig.HEAD_HAND_SCALE
        self.hand_scale = hh * scale
        # finger curl axes (rest-world) per side: rotate a towards p
        self.curl_axis = {}
        for sfx, sx in rig.SIDES:
            fr = rig.arm_frame(sx)
            self.curl_axis[sfx] = unit(np.cross(np.array(fr["a"]), np.array(fr["p"])))

    def length(self, b: str) -> float:
        return float(np.linalg.norm(self.tail[b] - self.head[b]))

    def ground_points(self, sfx: str) -> dict:
        """Rest heel / ball contact points under a foot."""
        ankle = self.head[f"foot.{sfx}"]
        ball = self.head[f"toe.{sfx}"]
        k = self.scale
        return {"heel": np.array([ankle[0], ankle[1] - 0.06 * k, 0.0]),
                "ball": np.array([ball[0], ball[1], 0.0]), "ankle": ankle}


@dataclass
class Solved:
    """Per-bone world rotation deltas + world head positions and local quats."""

    W: dict
    P: dict
    local: dict
    hip_loc: np.ndarray


def _two_bone(p0, target, l1, l2, pole):
    d_vec = target - p0
    d = float(np.linalg.norm(d_vec))
    d = min(max(d, abs(l1 - l2) + 1e-4), l1 + l2 - 1e-4)
    dirn = unit(d_vec)
    perp = unit(pole - dirn * (dirn @ pole))
    cos_a = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    sin_a = math.sqrt(max(0.0, 1 - cos_a * cos_a))
    joint = p0 + dirn * l1 * cos_a + perp * l1 * sin_a
    end = p0 + dirn * d
    return joint, end


def _twist_about(Rm: np.ndarray, axis: np.ndarray) -> float:
    """Signed twist angle of rotation Rm about ``axis`` (swing-twist decomposition)."""
    q = mat_to_quat(Rm)
    proj = float(np.dot(q[1:], axis))
    return 2.0 * math.atan2(proj, q[0])


def solve(sk: Skeleton, spec: PoseSpec) -> Solved:
    W: dict[str, np.ndarray] = {}
    P: dict[str, np.ndarray] = {}

    def place(b: str) -> None:
        par = sk.parent[b]
        if par is None:
            P[b] = sk.head[b].copy()
        else:
            P[b] = W[par] @ (sk.head[b] - sk.head[par]) + P[par]

    for b, par in sk.order:
        if b == "root":
            W[b] = I3.copy()
            P[b] = sk.head[b].copy()
            continue
        if b == "hips":
            W[b] = spec.D.get("hips", I3)
            P[b] = sk.head[b] + spec.hip
            continue
        sfx = b[-1] if b[-2:] in (".L", ".R") else ""
        place(b)
        base = b.split(".")[0]
        if base == "thigh" and sfx in spec.legs:
            _solve_leg(sk, spec.legs[sfx], sfx, W, P)
            continue
        if base in ("shin", "foot", "toe") and sfx in spec.legs:
            continue   # solved with the thigh
        if base == "upper_arm" and sfx in spec.arms:
            _solve_arm(sk, spec.arms[sfx], sfx, W, P)
            continue
        if base in ("forearm", "hand") and sfx in spec.arms:
            continue
        D = spec.D.get(b)
        if D is None:
            D = _finger_curl(sk, spec, b, sfx)
        W[b] = W[par] @ D
    # finger / thumb positions after the hand was solved
    for b, par in sk.order:
        if b not in P:
            P[b] = W[par] @ (sk.head[b] - sk.head[par]) + P[par]
    local = {}
    for b, par in sk.order:
        Dw = W[b] if par is None else W[par].T @ W[b]
        local[b] = mat_to_quat(sk.B[b].T @ Dw @ sk.B[b])
    hip_loc = sk.B["hips"].T @ spec.hip
    return Solved(W, P, local, hip_loc)


def _finger_curl(sk: Skeleton, spec: PoseSpec, b: str, sfx: str) -> np.ndarray:
    name = b.split(".")[0]
    if "_0" not in name or sfx not in spec.curl:
        return I3
    finger, idx = name.split("_0")
    idx = int(idx)
    curls = dict(zip(rig.FINGERS, spec.curl[sfx]))
    c = curls.get(finger, 0.0)
    if finger == "thumb":
        # thumb folds across the palm: about its own lateral axis
        th_dir = unit(sk.tail[b] - sk.head[b])
        fr = rig.arm_frame(-1.0 if sfx == "L" else 1.0)
        ax = unit(np.cross(th_dir, np.array(fr["p"])))
        ang = [0.35, 0.55, 0.6][idx - 1] * c
        return rot(ax, ang)
    ang = [1.15, 1.45, 0.95][idx - 1] * c - [0.0, 0.0, 0.0][idx - 1]
    return rot(sk.curl_axis[sfx], ang)


def _solve_leg(sk: Skeleton, ik: LegIK, sfx: str, W: dict, P: dict) -> None:
    th, sh, ft, to = (f"{n}.{sfx}" for n in ("thigh", "shin", "foot", "toe"))
    hip = P[th]
    l1, l2 = sk.length(th), sk.length(sh)
    knee, ankle = _two_bone(hip, np.asarray(ik.ankle, float), l1, l2, np.asarray(ik.pole, float))
    rest_pole = np.array([0.0, 1.0, 0.0])
    u0 = sk.tail[th] - sk.head[th]
    W[th] = align(u0, rest_pole, knee - hip, ik.pole)
    v0 = sk.tail[sh] - sk.head[sh]
    W[sh] = align(v0, rest_pole, ankle - knee, ik.pole)
    P[sh] = knee
    P[ft] = ankle
    W[ft] = ik.foot
    W[to] = ik.foot @ rx(ik.toe)
    P[to] = W[ft] @ (sk.head[to] - sk.head[ft]) + ankle


def _solve_arm(sk: Skeleton, ik: ArmIK, sfx: str, W: dict, P: dict) -> None:
    ua, fa, hd = (f"{n}.{sfx}" for n in ("upper_arm", "forearm", "hand"))
    sh = P[ua]
    l1, l2 = sk.length(ua), sk.length(fa)
    elbow, wrist = _two_bone(sh, np.asarray(ik.wrist, float), l1, l2, np.asarray(ik.pole, float))
    rest_pole = np.array([0.0, -1.0, 0.0])
    u0 = sk.tail[ua] - sk.head[ua]
    W[ua] = align(u0, rest_pole, elbow - sh, ik.pole)
    v0 = sk.tail[fa] - sk.head[fa]
    W_fore = align(v0, rest_pole, wrist - elbow, ik.pole)
    # give the forearm part of the wrist's twist about the forearm axis (less candy-wrapping)
    rel = W_fore.T @ ik.hand
    axis_local = unit(v0)
    tw = _twist_about(rel, axis_local)
    W_fore = W_fore @ rot(axis_local, tw * ik.twist_share)
    W[fa] = W_fore
    P[fa] = elbow
    P[hd] = wrist
    W[hd] = ik.hand


def blend_solved(a: Solved, b: Solved, t: float) -> Solved:
    local = {k: slerp(a.local[k], b.local[k], t) for k in a.local}
    return Solved({}, {}, local, a.hip_loc * (1 - t) + b.hip_loc * t)


def world_from_local(sk: Skeleton, s: Solved) -> tuple[dict, dict]:
    """Recompute world deltas/positions from local quats (for blended poses)."""
    W: dict = {}
    P: dict = {}
    for b, par in sk.order:
        Dw = sk.B[b] @ quat_to_mat(s.local[b]) @ sk.B[b].T
        if par is None:
            W[b] = Dw
            P[b] = sk.head[b].copy()
        else:
            W[b] = W[par] @ Dw
            if b == "hips":
                P[b] = sk.head[b] + sk.B["hips"] @ s.hip_loc
            else:
                P[b] = W[par] @ (sk.head[b] - sk.head[par]) + P[par]
    return W, P
