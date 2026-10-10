"""``rig_arms``: first-person viewmodel arms (rig, mesh, weapon animation sets), D1-03.

Private helper for ``arms_fp.py``. Pure numpy except ``build_arms_rig`` / ``build_arms_mesh``.

Rig (camera space). Bone ``root`` is the camera origin (the eye point between the eyes of a 1.78 m
``rig_humanoid``), Blender +Y forward = Godot -Z, +Z up. The arm chains reuse the contract names and
the exact rest geometry of ``rig_humanoid`` translated by -eye (``clavicle.L/R, upper_arm.L/R,
forearm.L/R, hand.L/R`` and the 30 finger bones), with the clavicles parented to ``root``. Two helper
bones are added (contract proposal, see the D1-03 report):

* ``weapon`` (child of ``hand.R``, never animated relative to it): its head is the weapon origin and
  its axes are the weapon's Godot axes (bone Y = weapon up, bone Z = weapon back, X = right), at the
  HandR grip offset of ``_anim.grip_offset``. A BoneAttachment3D on ``weapon`` with the weapon scene
  as an identity child places the gun; the same offset applies to ``rig_humanoid``'s HandR.
* ``magazine`` (child of ``weapon``, rest = the ``weapon`` frame): identity while the magazine is
  seated; animated during reloads (drops out, travels in the left hand, is inserted). Put the
  weapon's ``Magwell`` magazine node under a BoneAttachment3D on ``magazine`` with the same
  weapon-space transform it has in the weapon scene.

Animation sets are data (``FPSet``): marker positions of the weapon, the hip / ADS / sprint holds and
the reload choreography; ``fp_clips(set)`` turns any set into clips named ``<set>_<clip>``
(``pistol_idle`` ...). New sets for D-034 (smg, rifle, shotgun, lmg, sniper) are new ``FPSet``
entries, plus at most a new reload beat kind (pump, bolt, shell loop).
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

import _anim as A
import _rig as rig
from _anim import (FPS, TAU, Clip, Keys, Pose, Skeleton, Solver, arm_fk, hand_on, hand_shape, hold_weapon, pulse, rxd,
                   smooth, v3, weapon_frame, wf_point)

ARMATURE_NAME = "rig_arms"
ARM_PREFIXES = ("clavicle", "upper_arm", "forearm", "hand", "thumb", "index", "middle", "ring", "pinky")


def eye_point(height: float = rig.DEFAULT_HEIGHT) -> np.ndarray:
    j = rig.joints(height)
    return (np.array(j["eye.L"]) + np.array(j["eye.R"])) * 0.5


def arm_bones() -> list[str]:
    return [b for b in rig.BONES if b.split("_0")[0].split(".")[0] in ARM_PREFIXES]


BONES: list[str] = ["root", *arm_bones(), "weapon", "magazine"]
PARENT: dict[str, str | None] = {"root": None, "weapon": "hand.R", "magazine": "weapon"}
for _b in arm_bones():
    PARENT[_b] = "root" if _b.startswith("clavicle") else rig.PARENT[_b]


def segments(height: float = rig.DEFAULT_HEIGHT) -> dict:
    """{bone: (head, tail, roll_ref)} in camera space (metres, Blender axes)."""
    eye = eye_point(height)
    segs = rig.bone_segments(height)
    out = {"root": ((0.0, 0.0, 0.0), (0.0, 0.0, 0.1), (0.0, -1.0, 0.0))}
    for b in arm_bones():
        h, t, r = segs[b]
        out[b] = (tuple(np.array(h) - eye), tuple(np.array(t) - eye), r)
    tmp = Skeleton({k: v for k, v in out.items()}, {k: PARENT[k] for k in out}, list(out))
    R_off, t_off = A.grip_offset(tmp, "R")
    B = tmp.B["hand.R"]
    Rw = B @ R_off
    pw = tmp.head["hand.R"] + B @ t_off
    up, back = Rw[:, 2], -Rw[:, 1]
    out["weapon"] = (tuple(pw), tuple(pw + up * 0.06), tuple(back))
    out["magazine"] = (tuple(pw), tuple(pw + up * 0.03), tuple(back))
    return out


def skeleton(height: float = rig.DEFAULT_HEIGHT) -> Skeleton:
    return Skeleton(segments(height), PARENT, BONES, rig.scale_for(height))


# =============================================================================================
# weapon sets (data)
# =============================================================================================
@dataclass
class FPSet:
    """A first-person animation set for one ``WeaponDef.anim_set``. Positions are camera space
    (m, Blender axes: +X right, +Y forward, +Z up); weapon-space markers are Blender weapon axes
    relative to the weapon origin (the firing-hand pivot)."""

    name: str
    markers: dict                       # left_ik, aim, magwell (+ magwell_axis), slide_rear ...
    hip: tuple                          # (pivot, yaw, pitch, roll) at rest
    ads_dist: float                     # AimPoint distance in front of the eye (m)
    sprint: tuple                       # (pivot, yaw, pitch, roll)
    lowered: tuple                      # (pivot, yaw, pitch, roll): drawn-from / holstered-to, off screen
    support: str = "pistol"             # left-hand hold kind
    recoil: dict = field(default_factory=lambda: {"back": 0.028, "up": 0.010, "pitch": 7.0, "roll": 1.5})
    recoil_ads: dict = field(default_factory=lambda: {"back": 0.018, "up": 0.004, "pitch": 3.5, "roll": 0.8})
    clips: dict = field(default_factory=dict)   # clip -> {"frames", "loop", "events"}
    mag_len: float = 0.10               # magazine travel to leave the magwell (m)
    belt: tuple = (-0.13, 0.18, -0.55)  # left hand at the mag pouch (off screen)
    reload_tilt: tuple = ((0.075, 0.34, -0.15), 14.0, 20.0, 28.0)


_P9_RAKE = 18.0
PISTOL = FPSet(
    name="pistol",
    markers={"left_ik": v3(-0.025, 0.0115, -0.020), "aim": v3(0.0, -0.030, 0.0665),
             "magwell": v3(0.0, -0.0227, -0.070), "magwell_axis": rxd(-_P9_RAKE) @ v3(0.0, 0.0, 1.0),
             "slide_rear": v3(0.0, -0.030, 0.050)},
    hip=((0.13, 0.33, -0.18), 4.0, 3.0, -5.0),
    ads_dist=0.40,
    sprint=((0.15, 0.30, -0.23), 26.0, -24.0, -34.0),
    lowered=((0.17, 0.18, -0.55), 10.0, -60.0, -30.0),
    clips={
        "idle": {"frames": 90, "loop": True},
        "ads_idle": {"frames": 90, "loop": True},
        "draw": {"frames": 11, "loop": False, "events": {"ready": 11}},
        "holster": {"frames": 11, "loop": False, "events": {"gone": 11}},
        "fire": {"frames": 6, "loop": False, "events": {"shot": 0}},
        "fire_ads": {"frames": 6, "loop": False, "events": {"shot": 0}},
        "reload": {"frames": 45, "loop": False, "events": {"mag_out": 6, "mag_swap": 15, "mag_in": 29, "done": 38}},
        "reload_empty": {"frames": 63, "loop": False,
                         "events": {"mag_out": 6, "mag_swap": 15, "mag_in": 29, "slide_release": 45, "done": 56}},
        "sprint": {"frames": 18, "loop": True},
    },
)

SETS: dict[str, FPSet] = {"pistol": PISTOL}


# =============================================================================================
# holds
# =============================================================================================
def frame_of(spec: tuple, d_pivot=(0.0, 0.0, 0.0), d_yaw: float = 0.0, d_pitch: float = 0.0,
             d_roll: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    p, yaw, pitch, roll = spec
    return weapon_frame(np.array(p, float) + np.array(d_pivot, float), yaw + d_yaw, pitch + d_pitch, roll + d_roll)


def ads_frame(s: FPSet) -> tuple[np.ndarray, np.ndarray]:
    aim = s.markers["aim"]
    return weapon_frame(v3(0.0, s.ads_dist, 0.0) - aim)


def support(sk: Skeleton, pose: Pose, s: FPSet, wf) -> None:
    R = wf[0]
    if s.support == "pistol":
        hand_on(sk, pose, "L", wf_point(wf, s.markers["left_ik"]), R @ v3(0.55, 0.45, -0.70), R @ v3(0.85, 0.05, 0.25),
                pole=v3(-0.6, -0.2, -0.8), along_share=0.45, palm_off=0.016, clav=0.6)
        pose.hands["L"] = hand_shape("support")
    else:  # handguard / fore-end
        hand_on(sk, pose, "L", wf_point(wf, s.markers["left_ik"]), R @ v3(0.55, 0.65, 0.35), R @ v3(0.55, -0.1, 0.83),
                pole=v3(-0.5, -0.3, -0.8), along_share=0.55, palm_off=0.016, clav=0.6)
        pose.hands["L"] = hand_shape("grip", 0.85)


def hold(sk: Skeleton, s: FPSet, wf, two_hands: bool = True) -> Pose:
    pose = Pose()
    hold_weapon(sk, pose, wf, pole=v3(0.7, -0.1, -0.7), twist=0.6, clav=0.6)
    pose.hands["R"] = hand_shape("trigger")
    if two_hands:
        support(sk, pose, s, wf)
    else:
        left_down(sk, pose)
    return pose


def left_down(sk: Skeleton, pose: Pose, swing: float = 0.0) -> None:
    """Left arm out of view (hanging, slight bend)."""
    arm_fk(sk, pose, "L", add=30.0, swing=8.0 + swing, flex=25.0, twist=10.0)
    pose.hands["L"] = hand_shape("relaxed")


def mag_frame_seated(wf) -> tuple[np.ndarray, np.ndarray]:
    """World (camera-space) frame of the ``magazine`` bone when seated: the weapon frame."""
    return wf[0].copy(), wf[1].copy()


def mag_world(sk: Skeleton, Rm: np.ndarray, pm: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Weapon-axes frame (columns X right, Y muzzle, Z up) at ``pm`` -> (bone world delta, head)."""
    B = sk.B["magazine"]
    # bone axes in weapon terms: X = right, Y = up, Z = back  (see segments())
    bone_axes = np.column_stack([Rm[:, 0], Rm[:, 2], -Rm[:, 1]])
    return bone_axes @ B.T, pm.copy()


# =============================================================================================
# clips
# =============================================================================================
def fp_clips(sk: Skeleton, s: FPSet) -> dict[str, Clip]:
    solver = Solver(sk)
    out: dict[str, Clip] = {}
    for clip, row in s.clips.items():
        N, loop = int(row["frames"]), bool(row["loop"])
        fn = {"idle": _idle, "ads_idle": _ads_idle, "draw": _draw, "holster": _holster, "fire": _fire,
              "fire_ads": _fire_ads, "reload": _reload, "reload_empty": _reload_empty, "sprint": _sprint}[clip]
        out[f"{s.name}_{clip}"] = Clip(f"{s.name}_{clip}", N, loop, fn(sk, solver, s, N), 0.0, None,
                                       dict(row.get("events", {})), reach_fix=False)
    return out


def _with_mag(sk: Skeleton, pose: Pose, wf) -> Pose:
    pose.world["magazine"] = mag_world(sk, *mag_frame_seated(wf))
    return pose


def _idle(sk, solver, s, N):
    def fn(f: int) -> Pose:
        t = f / FPS
        T = N / FPS
        b = math.sin(TAU * t / T * 2.0)
        sway = math.sin(TAU * t / T + 0.6)
        wf = frame_of(s.hip, (0.003 * sway, 0.0, 0.003 * b), d_yaw=0.5 * sway, d_pitch=0.4 * b, d_roll=0.4 * sway)
        return _with_mag(sk, hold(sk, s, wf), wf)
    return fn


def _ads_idle(sk, solver, s, N):
    def fn(f: int) -> Pose:
        t = f / FPS
        T = N / FPS
        b = math.sin(TAU * t / T * 2.0)
        sway = math.sin(TAU * t / T + 0.6)
        R, o = ads_frame(s)
        wf = (R @ rxd(0.15 * b) @ A.rzd(0.15 * sway), o + v3(0.0008 * sway, 0.0, 0.001 * b))
        return _with_mag(sk, hold(sk, s, wf), wf)
    return fn


def _recoil(s: FPSet, base, rec: dict, k: float) -> tuple[np.ndarray, np.ndarray]:
    R, o = base
    o2 = o + R @ v3(0.0, -rec["back"] * k, rec["up"] * k)
    return R @ rxd(rec["pitch"] * k) @ A.ryd(rec["roll"] * k), o2


def _fire(sk, solver, s, N):
    def fn(f: int) -> Pose:
        k = pulse(f / FPS, 1.0 / FPS, (N - 1) / FPS)
        wf = _recoil(s, frame_of(s.hip), s.recoil, k)
        return _with_mag(sk, hold(sk, s, wf), wf)
    return fn


def _fire_ads(sk, solver, s, N):
    def fn(f: int) -> Pose:
        k = pulse(f / FPS, 1.0 / FPS, (N - 1) / FPS)
        wf = _recoil(s, ads_frame(s), s.recoil_ads, k)
        return _with_mag(sk, hold(sk, s, wf), wf)
    return fn


def _draw(sk, solver, s, N, reverse: bool = False):
    lo, hi = frame_of(s.lowered), frame_of(s.hip)

    def fn(f: int) -> Pose:
        u = f / N
        if reverse:
            u = 1.0 - u
        e = A.bezier1(u, 0.0, 1.08)            # fast in, small overshoot settle
        R = A.mslerp(lo[0], hi[0], min(1.0, e))
        o = lo[1] + (hi[1] - lo[1]) * e
        wf = (R, o)
        pose = hold(sk, s, wf, two_hands=True)
        # the support hand joins late (comes up from below)
        j = smooth(0.55, 1.0, u)
        if j < 1.0:
            sup = pose.arms["L"]
            low = v3(-0.16, 0.22, -0.55)
            sup.wrist = low + (sup.wrist - low) * j
            pose.hands["L"] = hand_shape("relaxed").blend(hand_shape("support"), j)
        return _with_mag(sk, pose, wf)
    return fn


def _holster(sk, solver, s, N):
    return _draw(sk, solver, s, N, reverse=True)


def _sprint(sk, solver, s, N):
    def fn(f: int) -> Pose:
        ph = f / N
        bob = math.cos(TAU * 2 * ph)
        side = math.sin(TAU * ph)
        wf = frame_of(s.sprint, (0.012 * side, 0.004 * bob, 0.014 * bob), d_yaw=3.0 * side, d_pitch=2.5 * bob,
                      d_roll=4.0 * side)
        pose = hold(sk, s, wf, two_hands=False)
        left_down(sk, pose, swing=25.0 * math.sin(TAU * ph + 0.3))
        return _with_mag(sk, pose, wf)
    return fn


# -- reloads -----------------------------------------------------------------------------------
def _left_at_mag(sk: Skeleton, pose: Pose, s: FPSet, wf, out: float, shape: str = "pinch") -> None:
    """Left hand holding the magazine whose base is ``out`` m below the magwell, aligned with it."""
    R = wf[0]
    axis = R @ s.markers["magwell_axis"]
    base = wf_point(wf, s.markers["magwell"]) - axis * out
    palm_pt = base - axis * 0.012 + R @ v3(-0.004, -0.010, 0.0)
    hand_on(sk, pose, "L", palm_pt, R @ v3(0.35, 0.90, -0.25), axis,
            pole=v3(-0.7, -0.4, -0.6), along_share=0.35, palm_off=0.014, clav=0.6)
    pose.hands["L"] = hand_shape(shape)


def _reload_keys(sk, solver, s: FPSet, N: int, empty: bool):
    ev = s.clips["reload_empty" if empty else "reload"]["events"]
    hip = frame_of(s.hip)
    tilt = frame_of(s.reload_tilt)
    tilt_in = frame_of(s.reload_tilt, (0.0, 0.0, 0.006), d_pitch=2.0)
    approach_out = 0.07

    def k_hold(wf, two=True, left=None) -> Pose:
        p = hold(sk, s, wf, two_hands=two)
        if left is not None:
            left(p)
        return p

    belt = v3(*s.belt)

    def at_belt(shape):
        def fn(p: Pose) -> None:
            hand_on(sk, p, "L", belt, v3(0.2, 0.3, -0.9), v3(0.95, 0.0, 0.2), pole=v3(-0.7, -0.3, -0.6),
                    along_share=0.5, clav=0.3)
            p.hands["L"] = hand_shape(shape)
        return fn
    keys = [
        (0, k_hold(hip), "inout"),
        (5, k_hold(tilt, two=False, left=lambda p: left_down(sk, p, swing=10.0)), "inout"),
        (13, k_hold(tilt, two=False, left=at_belt("relaxed")), "inout"),
        (16, k_hold(tilt, two=False, left=at_belt("pinch")), "inout"),
        (24, k_hold(tilt, two=False, left=lambda p: _left_at_mag(sk, p, s, tilt, approach_out)), "inout"),
        (ev["mag_in"], k_hold(tilt_in, two=False, left=lambda p: _left_at_mag(sk, p, s, tilt_in, -0.004, "flat")), "snap"),
    ]
    if not empty:
        keys += [(ev["mag_in"] + 4, k_hold(tilt_in, two=False, left=lambda p: _left_at_mag(sk, p, s, tilt_in, 0.03, "flat")), "out"),
                 (ev["done"], k_hold(frame_of(s.reload_tilt, d_pitch=-6.0, d_roll=-14.0)), "inout"),
                 (N, k_hold(hip), "settle")]
    else:
        rel = ev["slide_release"]
        slide = s.markers["slide_rear"]

        def grab(wf, pull):
            def fn(p: Pose) -> None:
                R = wf[0]
                pt = wf_point(wf, slide + v3(-0.018, -pull, 0.012))
                hand_on(sk, p, "L", pt, R @ v3(0.95, -0.05, -0.3), R @ v3(0.3, 0.0, -0.95),
                        pole=v3(-0.7, -0.2, -0.7), along_share=0.62, palm_off=0.02, clav=0.6)
                p.hands["L"] = hand_shape("grip", 0.9)
            return fn
        rack = frame_of(s.reload_tilt, (0.01, 0.03, 0.01), d_roll=-30.0, d_pitch=-4.0)
        rack_push = frame_of(s.reload_tilt, (0.01, 0.06, 0.01), d_roll=-30.0, d_pitch=-4.0)
        keys += [(rel - 7, k_hold(rack, two=False, left=grab(rack, 0.0)), "inout"),
                 (rel, k_hold(rack_push, two=False, left=grab(rack_push, 0.03)), "inout"),
                 (rel + 3, k_hold(rack_push, two=False, left=lambda p: left_down(sk, p, swing=30.0)), "out"),
                 (ev["done"], k_hold(frame_of(s.reload_tilt, d_pitch=-6.0, d_roll=-14.0)), "inout"),
                 (N, k_hold(hip), "settle")]
    return keys, approach_out


def _reload_common(sk, solver, s: FPSet, N: int, empty: bool):
    keys, approach_out = _reload_keys(sk, solver, s, N, empty)
    ev = s.clips["reload_empty" if empty else "reload"]["events"]
    out_f, swap_f, in_f = ev["mag_out"], ev["mag_swap"], ev["mag_in"]
    approach_f = 24
    hold_solver = Solver(sk)
    cache: dict = {}

    def weapon_of(sol) -> tuple[np.ndarray, np.ndarray]:
        Ah = sol.W["hand.R"] @ sk.B["hand.R"]
        R_off, t_off = A.grip_offset(sk, "R")
        return Ah @ R_off, sol.P["hand.R"] + Ah @ t_off

    def hand_L(sol) -> tuple[np.ndarray, np.ndarray]:
        return sol.W["hand.L"] @ sk.B["hand.L"], sol.P["hand.L"]

    def post(f: int, pose: Pose) -> None:
        sol = hold_solver.solve(pose)
        Rw, pw = weapon_of(sol)
        axis = Rw @ s.markers["magwell_axis"]
        if f < out_f:
            Rm, pm = Rw, pw
        elif f < swap_f:
            # mag drops out of the grip and falls away under gravity, tumbling a little
            t = (f - out_f) / FPS
            slide_t = min(1.0, (f - out_f) / 3.0)
            d = s.mag_len * smooth(0.0, 1.0, slide_t) + 0.5 * 9.81 * max(0.0, t - 0.1) ** 2
            if "drop" not in cache:
                cache["drop"] = (Rw.copy(), pw.copy(), axis.copy())
            R0, p0, ax0 = cache["drop"]
            Rm = R0 @ rxd(-60.0 * max(0.0, t - 0.1))
            pm = p0 - ax0 * s.mag_len * smooth(0.0, 1.0, slide_t) + v3(0.0, 0.0, -(d - s.mag_len * smooth(0.0, 1.0, slide_t)))
        elif f < approach_f:
            # new mag rides in the left hand with the offset it has at the approach key
            if "grip" not in cache:
                ap = hold_solver.solve(keys_obj(approach_f))
                Rwa, pwa = weapon_of(ap)
                axa = Rwa @ s.markers["magwell_axis"]
                Rh, ph = hand_L(ap)
                cache["grip"] = (Rh.T @ Rwa, Rh.T @ (pwa - axa * (approach_out + s.mag_len * 0.0)))
            Rh, ph = hand_L(sol)
            Rr, tr = cache["grip"]
            Rm, pm = Rh @ Rr, ph + Rh @ tr
        elif f <= in_f:
            u = smooth(0.0, 1.0, (f - approach_f) / max(1, in_f - approach_f))
            Rm, pm = Rw, pw - axis * approach_out * (1.0 - u)
        else:
            Rm, pm = Rw, pw
        pose.world["magazine"] = mag_world(sk, Rm, pm)

    ks = Keys(solver, keys)

    def keys_obj(f: int) -> Pose:
        return ks(f)
    return Keys(solver, keys, post)


def _reload(sk, solver, s, N):
    return _reload_common(sk, solver, s, N, empty=False)


def _reload_empty(sk, solver, s, N):
    return _reload_common(sk, solver, s, N, empty=True)


# =============================================================================================
# Blender: rig + mesh
# =============================================================================================
def build_arms_rig(height: float = rig.DEFAULT_HEIGHT):
    import bpy  # noqa: PLC0415
    from mathutils import Vector  # noqa: PLC0415

    from lib import scene  # noqa: PLC0415

    arm = bpy.data.armatures.new(ARMATURE_NAME)
    arm.display_type = "OCTAHEDRAL"
    obj = bpy.data.objects.new(ARMATURE_NAME, arm)
    scene.link(obj)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    segs = segments(height)
    for bone in BONES:
        head, tail, roll = segs[bone]
        eb = arm.edit_bones.new(bone)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        eb.align_roll(Vector(roll))
        if PARENT[bone] is not None:
            eb.parent = arm.edit_bones[PARENT[bone]]
            eb.use_connect = False
        eb.use_deform = bone not in ("root", "weapon", "magazine")
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
    obj.select_set(False)
    return obj


# -- mesh (pure part) --------------------------------------------------------------------------
SLEEVE_RINGS = ("upper_arm", "elbow", "forearm", "wrist")
SLEEVE_EASE = {"upper_arm": 0.012, "elbow": 0.011, "forearm": 0.009, "wrist": 0.008}


def _align_ring(ref: list, ring: list) -> list:
    """Rotate ``ring`` (closed loop) so its points best match ``ref`` index by index."""
    n = len(ring)
    best, best_d = 0, None
    for sh in range(n):
        d = sum(float(np.sum((np.array(ref[i]) - np.array(ring[(i + sh) % n])) ** 2)) for i in range(0, n, 4))
        if best_d is None or d < best_d:
            best, best_d = sh, d
    return [ring[(i + best) % n] for i in range(n)]


def hands_data(params: dict) -> dict:
    """Pure-math arm mesh in humanoid space: hands (one Catmull-Clark level above the body's) with
    weights, plus lofted suit sleeves with a turned-in cuff. Returns verts, faces, face material
    ("skin"/"suit"), face uvs (skin only; None for suit), weights."""
    import _body as body  # noqa: PLC0415

    p = body.body_params(params, hide=frozenset(r for r in body.REGIONS if r != "hands"))
    data, _hair = body.body_mesh_data(p)
    w0 = body.body_weights(data)
    md = body.MeshData(verts=[tuple(v) for v in data.blend], faces=list(data.faces), face_region=list(data.face_region),
                       face_mat=list(data.face_mat), face_side=list(data.face_side))
    sub = body.catmull_clark(md)
    nv = len(md.verts)
    weights: list[dict] = [dict(w) for w in w0] + [dict() for _ in range(len(sub.verts) - nv)]

    def avg(ids: list[int]) -> dict:
        acc: dict = {}
        for i in ids:
            for b, x in weights[i].items():
                acc[b] = acc.get(b, 0.0) + x / len(ids)
        return acc
    k = 0
    for f in md.faces:
        n = len(f)
        for i in range(n):
            b_, e1, fp, _e0 = sub.faces[k]
            c = f[(i + 1) % n]
            if not weights[e1]:
                weights[e1] = avg([f[i], c])
            if not weights[fp]:
                weights[fp] = avg(list(f))
            k += 1
    weights = [_top4(w) for w in weights]
    uvs = body.face_uvs(sub.faces, sub.face_region, sub.face_mat, sub.face_side, sub.verts, float(p["height"]))
    verts = [tuple(v) for v in sub.verts]
    faces = [tuple(f) for f in sub.faces]
    mats = ["skin"] * len(faces)
    face_uv: list = list(uvs)
    # sleeves
    rings = body.body_rings(body.body_params(params, hide=frozenset()))
    for sfx, sx in rig.SIDES:
        loops = [rings[f"{r}.{sfx}"] for r in SLEEVE_RINGS]
        for i in range(1, len(loops)):
            loops[i] = _align_ring(loops[i - 1], loops[i])
        cen = [np.mean(np.array(lp), axis=0) for lp in loops]
        offs = [SLEEVE_EASE[r] for r in SLEEVE_RINGS]
        out_loops = []
        for li in range(len(loops) - 1):
            for t in (0.0, 0.25, 0.5, 0.75):
                pts = []
                for a, b in zip(loops[li], loops[li + 1]):
                    pa = np.array(a) + _outward(np.array(a), cen[li]) * offs[li]
                    pb = np.array(b) + _outward(np.array(b), cen[li + 1]) * offs[li + 1]
                    pts.append(pa + (pb - pa) * t)
                out_loops.append(pts)
        wr = [np.array(a) + _outward(np.array(a), cen[-1]) * offs[-1] for a in loops[-1]]
        axis = (cen[-1] - cen[-2]) / np.linalg.norm(cen[-1] - cen[-2])
        out_loops.append(wr)
        cuff = [q + axis * 0.014 + _outward(q, cen[-1] + axis * 0.014) * 0.002 for q in wr]
        out_loops.append(cuff)
        lip = [q + axis * 0.016 - _outward(q, cen[-1] + axis * 0.016) * 0.005 for q in cuff]
        out_loops.append(lip)
        inner = [q - axis * 0.02 - _outward(q, cen[-1]) * 0.003 for q in lip]
        out_loops.append(inner)
        base = len(verts)
        n = len(wr)
        for lp in out_loops:
            verts.extend(tuple(float(c) for c in q) for q in lp)
        pts_side = [np.array(v) for v in verts[base:]]
        cands = [[b for b in (f"upper_arm.{sfx}", f"forearm.{sfx}", f"hand.{sfx}")]] * len(pts_side)
        ws = body.skin_weights([tuple(q) for q in pts_side], float(p["height"]), cands)
        # the cuff and lip follow the forearm (the hand turns inside the cuff)
        for i in range(len(ws)):
            li = i // n
            if li >= len(out_loops) - 3:
                ws[i] = {f"forearm.{sfx}": 0.85, f"hand.{sfx}": 0.15}
        weights.extend(_top4(w) for w in ws)
        nl = len(out_loops)
        loop_c = [np.mean(np.array(lp), axis=0) for lp in out_loops]
        for li in range(nl - 1):
            for j in range(n):
                a = base + li * n + j
                b = base + li * n + (j + 1) % n
                c = base + (li + 1) * n + (j + 1) % n
                d = base + (li + 1) * n + j
                q = (a, b, c, d)
                fa = np.array(verts[a])
                nrm = np.cross(np.array(verts[b]) - fa, np.array(verts[d]) - fa)
                if li == nl - 3:                  # cuff end face: faces the hand
                    want = float(nrm @ axis)
                elif li == nl - 2:                # inside of the cuff: faces the arm
                    want = -float(nrm @ (fa - (loop_c[li] + loop_c[li + 1]) * 0.5))
                else:
                    want = float(nrm @ (fa - (loop_c[li] + loop_c[li + 1]) * 0.5))
                if want < 0.0:
                    q = (d, c, b, a)
                faces.append(q)
                mats.append("suit")
                face_uv.append(None)
    return {"verts": verts, "faces": faces, "mats": mats, "uvs": face_uv, "weights": weights,
            "height": float(p["height"])}


def _outward(p: np.ndarray, c: np.ndarray) -> np.ndarray:
    d = p - c
    n = float(np.linalg.norm(d))
    return d / n if n > 1e-9 else d


def _top4(w: dict) -> dict:
    top = sorted(w.items(), key=lambda kv: (-kv[1], kv[0]))[:4]
    tot = sum(x for _b, x in top) or 1.0
    return {b: x / tot for b, x in sorted(top)}


SUIT_COLOR = "#23262B"


def build_arms_mesh(ctx, arm_obj, params: dict) -> dict:
    """Create the skinned ``Arms`` mesh (skin + suit sleeves) in camera space under ``arm_obj``."""
    import bmesh  # noqa: PLC0415
    import bpy  # noqa: PLC0415

    import _body as body  # noqa: PLC0415
    from lib import scene  # noqa: PLC0415

    d = hands_data(params)
    eye = eye_point(d["height"])
    skin_id = int(body.body_params(params)["skin"])
    m_skin = ctx.material(f"char_skin_{skin_id}", body.SKIN_TONES[skin_id - 1], roughness=0.55)
    m_suit = ctx.material("char_suit_dark", SUIT_COLOR, roughness=0.75)
    me = bpy.data.meshes.new("Arms")
    me.from_pydata([tuple(np.array(v) - eye) for v in d["verts"]], [], d["faces"])
    me.materials.append(m_skin)
    me.materials.append(m_suit)
    me.polygons.foreach_set("material_index", [0 if m == "skin" else 1 for m in d["mats"]])
    me.validate(clean_customdata=False)
    me.update()
    # UVs: skin from the body's tiles; sleeves box-projected at the first-person density
    bm = bmesh.new()
    bm.from_mesh(me)
    layer = bm.loops.layers.uv.new("UVMap")
    suit_faces = [f for f in bm.faces if f.material_index == 1]
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        if f.material_index == 0:
            for loop, uvc in zip(f.loops, d["uvs"][f.index]):
                loop[layer].uv = uvc
    _box_suit(bm, layer, suit_faces)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    obj = bpy.data.objects.new("Arms", me)
    scene.link(obj, arm_obj)
    groups = {}
    for b in BONES:
        if b in ("root", "weapon", "magazine"):
            continue
        groups[b] = obj.vertex_groups.new(name=b)
    per_bone: dict[str, list] = {b: [] for b in groups}
    for vi, w in enumerate(d["weights"]):
        for b, x in sorted(w.items()):
            per_bone[b].append((vi, x))
    for b in groups:
        for vi, x in per_bone[b]:
            groups[b].add([vi], x, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj
    mod.use_vertex_groups = True
    mod.use_bone_envelopes = False
    return {"Arms": obj, "tris": sum(len(f) - 2 for f in d["faces"])}


def _box_suit(bm, layer, faces) -> None:
    """Deterministic box projection for the sleeve faces (1024 px/m on a 1024 px texture)."""
    from lib import uv  # noqa: PLC0415

    k = uv.DENSITY_FIRST_PERSON / 1024.0
    for f in faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            c = loop.vert.co
            u, v = [(c.y, c.z), (c.x, c.z), (c.x, c.y)][ax]
            loop[layer].uv = (u * k, v * k)
