"""PO6-17 assault-event helper clips for the ``humanoid`` library (ENV A's RNG assault events: helicopter rappel
squad and door sniper, turret-van crew, breach charges). Private helper of ``anim_humanoid.py`` (pure numpy).

Clips (names proposed by ENV D, confirmed by ENV A; each is one entry in ``NAMES`` / ``anim_humanoid.CLIPS``, so a
rename is a two-line change plus the test table):

* ``rappel_hang*`` / ``rappel_descend*`` / ``rappel_land``: on a vertical rope ``ROPE_Y`` m in front of the root
  (Blender +Y = Godot -Z), 0.10 m in front of the sternum. Both fists hold the rope line on every frame of the loops
  (HandL / HandR Socket origins on the line, the rope through the fist along the socket's grip axis). The root
  plane is ``RAPPEL_CLEAR`` m below the lowest foot point on the rope (A moves the root down the rope at
  ``rappel_descend``'s speed, 2.5 m/s, and puts it on the floor for ``rappel_land``, whose frame 0 IS
  ``rappel_descend`` frame 0 and whose last frame IS ``idle_alert`` frame 0; ``touch`` = the feet hit the floor).
* ``heli_door_idle*`` / ``heli_door_aim*`` / ``heli_door_fire``: kneeling on the right knee on the helicopter's
  cabin floor at the open door (root plane = the floor / door sill), rifle at the ready / aimed along +Y (Godot -Z)
  with the HandR/Socket weapon convention of ``aim_rifle``. ``HELI_ROOT_IN_SNIPER_SEAT`` places the root relative
  to ENV C's ``prop_police_helicopter`` ``Model/SniperSeat`` marker (which sits on the bench top, not the sill).
* ``van_exit``: from crouched on a vehicle step (``VAN_STEP_Z`` above the root plane, ``VAN_STEP_BACK`` behind the
  final root) forward and down to the floor, ends on ``idle_alert`` frame 0. In place like ``walk_start``: A moves
  the root forward by ``curve.van_exit`` (SOURCE.txt), planted feet are world-still at that root motion.
* ``breach_place`` (from and back to ``idle_alert`` frame 0; ``place`` = the charge pressed on the wall
  ``BREACH_WALL`` ahead of the root) and ``breach_standback`` (from ``breach_place``'s last frame, a side step to the
  left out of the blast line into a braced crouch, head turned away, ends on ``crouch_idle`` frame 0; root motion
  ``curve.breach_standback`` along Godot -X).
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
from _anim import (FPS, TAU, Clip, Keys, LegIK, Pose, Skeleton, Solver, add_rot, arm_fk, hand_on, hand_shape,
                   hold_weapon, rxd, ryd, rzd, smooth, spine, unit, v3, weapon_frame)

# =============================================================================================
# placement constants (m at 1.78 m, Blender clip space: x right, y forward, z up)
# =============================================================================================
ROPE_Y = 0.225                 # the rope: vertical line x = 0, ROPE_Y m in front of the root
RAPPEL_CLEAR = 0.30            # rappel_hang / rappel_descend frame 0: lowest foot point above the root plane
ROPE_PITCH = 18.0              # fist frame pitch that makes the grip axis (the rope through the fist) vertical
TILT_GUIDE = 45.0              # rappel_descend / rappel_land guide fist (left, at the face): knuckles pitched up
TILT_BRAKE = -20.0             # brake fist (right, at the hip): knuckles pitched down
HANG_HIPS = (0.0, 0.002, 1.372)   # rappel_hang hips joint (x, y, z) above the root
DESC_HIPS = (0.0, 0.08, 1.067)     # rappel_descend hips joint
HELI_KNEEL_HIP_Z = 0.40        # heli door kneel: hips joint above the sill / cabin floor
VAN_STEP_Z = 0.45              # van_exit: step top above the root plane
VAN_STEP_BACK = 0.60           # van_exit: the feet on the step are this far behind the final root
VAN_STEP_EDGE = 0.42           # van_exit: the step's front edge, m behind the final root
BREACH_WALL = 0.45             # breach_place: wall plane ahead of the root
BREACH_CHARGE = (0.0, 0.41, 1.10)   # breach_place: charge face centre at `place` (palms on it; 4 cm proud of the wall)
STANDBACK_X = 0.80             # breach_standback: side step to the left (root travel)
#: ENV C prop_police_helicopter (commit 8c1935dc, tools/blender/props/assault_events.py): cabin floor top (rubber mat)
#: at heli y 0.736, Model/SniperSeat at heli (-0.53, 1.08, 0.12) on the rear bench top, -Z out of the left door
#: (-X), the door edge (sill) at heli x -0.78, bench front face at heli z -0.05, roof liner at heli y 1.965.
#: The kneel root in SniperSeat space (Godot axes): on the floor, 0.40 m inside the sill, clear of the bench.
HELI_FLOOR_Y = 0.736
HELI_SEAT = (-0.53, 1.08, 0.12)
HELI_ROOT_IN_SNIPER_SEAT = (0.50, HELI_FLOOR_Y - HELI_SEAT[1], 0.15)
HELI_SILL_AHEAD = 0.40         # the door edge, m ahead of the kneel root
HELI_HEADROOM = 1.965 - HELI_FLOOR_Y

NAMES = ("rappel_hang", "rappel_descend", "rappel_land", "heli_door_idle", "heli_door_aim", "heli_door_fire",
         "van_exit", "breach_place", "breach_standback")
#: one-shot -> (clip, frame) its frame 0 equals / (clip, frame) its last frame equals (-1 = that clip's last frame)
STARTS = {"rappel_land": ("rappel_descend", 0), "breach_place": ("idle_alert", 0), "breach_standback": ("breach_place", -1)}
ENDS = {"rappel_land": ("idle_alert", 0), "van_exit": ("idle_alert", 0), "breach_place": ("idle_alert", 0),
        "breach_standback": ("crouch_idle", 0)}
#: clip -> (root travel total m, Godot direction) for the in-place clips with root motion (SOURCE curve.<clip>)
ROOT_MOTION = {"van_exit": (VAN_STEP_BACK, (0.0, 0.0, -1.0)), "breach_standback": (STANDBACK_X, (-1.0, 0.0, 0.0))}
ROPE_CLIPS = ("rappel_hang", "rappel_descend")
HELI = ("heli_door_idle", "heli_door_aim", "heli_door_fire")


def _src(sk: Skeleton, solver: Solver, name: str, f: int) -> Pose:
    import _anim_d304 as d304  # noqa: PLC0415

    return d304.src_pose(sk, solver, name, f)


def shift(pose: Pose, d) -> None:
    """Translate the whole posed body (hips and every IK goal) by ``d``."""
    d = np.asarray(d, float)
    pose.hip = pose.hip + d
    for g in pose.legs.values():
        g.ankle = g.ankle + d
    for g in pose.arms.values():
        g.wrist = g.wrist + d


def hips_at(sk: Skeleton, pose: Pose, x: float, y: float, z: float) -> None:
    k = sk.scale
    pose.hip = v3(x * k, y * k, z * k - sk.head["hips"][2])


def look(pose: Pose, yaw: float = 0.0, pitch: float = 0.0, tilt: float = 0.0, neck_share: float = 0.35) -> None:
    add_rot(pose, "neck", rzd(yaw * neck_share) @ rxd(-pitch * neck_share))
    add_rot(pose, "head", rzd(yaw * (1 - neck_share)) @ ryd(tilt) @ rxd(-pitch * (1 - neck_share)))


def rope_fist(sk: Skeleton, pose: Pose, sfx: str, z: float, pole, yaw: float | None = None, tilt: float = 0.0) -> None:
    """Fist ``sfx`` round the rope at height ``z`` (m at 1.78 m): the HandL/HandR Socket origin (grip centre) on the
    rope line, the grip axis vertical (the rope runs through the fist), knuckles forward and a little inward;
    ``tilt`` (deg) pitches the knuckles up (a fist above the shoulder: the forearm comes up from below and the rope
    crosses the palm diagonally) or down (negative: the brake fist at the hip)."""
    k = sk.scale
    sx = A.side_x(sfx)
    yw = (sx * 14.0) if yaw is None else yaw
    hold_weapon(sk, pose, weapon_frame(v3(0.0, ROPE_Y * k, z * k), yaw=yw, pitch=ROPE_PITCH + tilt), pole=pole, sfx=sfx,
                twist=0.55, clav=0.7)
    pose.hands[sfx] = hand_shape("grip", 0.95)


# =============================================================================================
# rappel: hang, descend, land
# =============================================================================================
def rappel_hang(sk: Skeleton, f: int, N: int) -> Pose:
    """Hanging on the rope (harness), both fists on it: right above the head, left at the chest; legs slightly bent,
    feet together, toes down; a slow small pendulum sway under the fixed fists, head looking down to the left."""
    k = sk.scale
    u = (f % N) / N
    s1, c1 = math.sin(TAU * u), math.cos(TAU * u)
    s2 = math.sin(2.0 * TAU * u + 0.6)
    pose = Pose()
    hx, hy, hz = HANG_HIPS
    hips_at(sk, pose, hx + 0.010 * s1, hy + 0.014 * c1, hz + 0.004 * s2)
    spine(pose, lean=-1.0 - 1.2 * c1, chest_lean=-2.0, side=-1.4 * s1, hips=(-4.0 + 2.0 * c1, 1.0 * s1, 0.0),
          neck=(8.0, 0.0, 0.0))
    look(pose, yaw=14.0 + 4.0 * s1, pitch=24.0, tilt=-3.0)
    for sfx, sx in A.SIDES:
        # the legs trail the hips' swing a little (pendulum lag)
        lag = 0.016 * math.sin(TAU * u - 0.9)
        ank = v3(sx * 0.065 * k + 0.010 * k * math.sin(TAU * u - 0.7), (0.06 + lag) * k + pose.hip[1] * 0.6,
                 (hz - 0.86) * k)
        pose.legs[sfx] = LegIK(ankle=ank, foot=A.foot_rot(yaw=-sx * 6.0, pitch=-42.0 + 3.0 * c1), toe=A.rad(-6.0),
                               pole=unit(v3(sx * 0.10, 1.0, 0.15)))
    rope_fist(sk, pose, "R", hz + 0.93, pole=v3(0.9, 0.0, -0.45), tilt=55.0)
    rope_fist(sk, pose, "L", hz + 0.30, pole=v3(-0.7, -0.1, -0.8))
    _breathe(pose, f / FPS, N / FPS / 2.0, 1.2)
    return pose


def rappel_descend(sk: Skeleton, f: int, N: int) -> Pose:
    """Sliding down the rope seated in the harness, legs braced forward-down (feet apart, soles forward: skimming
    an absent wall), the brake fist (right) low at the hip and the guide fist (left) high, both on the rope line,
    alternating a little; the body stays in place (A moves the root down at the clip speed)."""
    k = sk.scale
    u = (f % N) / N
    s1, c1 = math.sin(TAU * u), math.cos(TAU * u)
    pose = Pose()
    hx, hy, hz = DESC_HIPS
    hips_at(sk, pose, hx, hy + 0.006 * c1, hz + 0.006 * math.sin(2.0 * TAU * u))
    spine(pose, lean=16.0, chest_lean=3.0, side=1.0, hips=(-30.0, 0.0, 0.0), neck=(4.0, 0.0, 0.0))
    look(pose, yaw=-28.0 + 3.0 * s1, pitch=30.0, tilt=4.0)
    for sfx, sx in A.SIDES:
        flutter = 0.018 * math.sin(TAU * u + (0.0 if sfx == "L" else math.pi))
        ank = v3(sx * 0.19 * k, (0.40 + flutter) * k, (hz - 0.70 + 0.5 * flutter) * k)
        pose.legs[sfx] = LegIK(ankle=ank, foot=A.foot_rot(yaw=-sx * 10.0, pitch=34.0), toe=A.rad(-4.0),
                               pole=unit(v3(sx * 0.30, 0.45, 1.0)))
    a = 0.035 * s1
    rope_fist(sk, pose, "L", hz + 0.70 + a, pole=v3(-0.85, -0.2, -0.5), tilt=TILT_GUIDE)
    rope_fist(sk, pose, "R", hz + 0.06 - a, pole=v3(0.8, -0.5, -0.3), tilt=TILT_BRAKE)
    pose.hands["R"] = hand_shape("grip", 1.0)
    _breathe(pose, f / FPS, N / FPS, 1.4)
    return pose


def _breathe(pose: Pose, t: float, period: float, amount: float) -> None:
    import _anim_humanoid as H  # noqa: PLC0415

    H.breathe(pose, t, period, amount)


def rappel_land(sk: Skeleton, solver: Solver, N: int, touch: int) -> Keys:
    """From ``rappel_descend`` frame 0 (root on the floor, feet RAPPEL_CLEAR above it): the legs swing down under
    the body, the feet touch the floor at ``touch`` (on ``idle_alert`` frame 0's foot places, then planted), the
    knees absorb, the fists slide down and let go of the rope, settles exactly on ``idle_alert`` frame 0."""
    k = sk.scale
    start = _src(sk, solver, "rappel_descend", 0)
    end = _src(sk, solver, "idle_alert", 0)
    ez = float(end.hip[2]) + sk.head["hips"][2]

    def legs_from(p: Pose, dz: float = 0.0, dy: float = 0.0, pitch: float = 0.0) -> None:
        for sfx in ("L", "R"):
            g = end.legs[sfx]
            p.legs[sfx] = LegIK(ankle=g.ankle + v3(0.0, dy * k, dz * k), foot=A.foot_rot(pitch=pitch) @ g.foot,
                                toe=g.toe, pole=g.pole.copy())

    def rope_hands(p: Pose, zl: float, zr: float, shape: float = 1.0) -> None:
        rope_fist(sk, p, "L", zl, pole=v3(-0.85, -0.2, -0.5), tilt=TILT_GUIDE)
        rope_fist(sk, p, "R", zr, pole=v3(0.8, -0.5, -0.3), tilt=TILT_BRAKE)
        for sfx in ("L", "R"):
            p.hands[sfx] = hand_shape("grip", shape)

    # legs swinging down under the body, toes reaching for the floor
    reach = Pose()
    hips_at(sk, reach, 0.0, -0.01, 1.00)
    spine(reach, lean=10.0, chest_lean=3.0, hips=(-12.0, 0.0, 0.0), neck=(6.0, 0.0, 0.0))
    look(reach, yaw=-12.0, pitch=26.0)
    legs_from(reach, dz=0.07, dy=0.04, pitch=-22.0)
    rope_hands(reach, 1.00 + 0.68, 1.00 + 0.07)
    # touch: both feet on idle_alert's places, legs nearly straight
    tch = Pose()
    hips_at(sk, tch, 0.0, -0.01, ez - 0.01)
    spine(tch, lean=8.0, chest_lean=3.0, hips=(-4.0, 0.0, 0.0), neck=(4.0, 0.0, 0.0))
    look(tch, yaw=-6.0, pitch=18.0)
    legs_from(tch)
    rope_hands(tch, ez + 0.70, ez + 0.08)
    # absorb: knees bend, trunk folds a little, fists still on the rope (sliding down with the body)
    absorb = Pose()
    hips_at(sk, absorb, 0.0, -0.05, ez - 0.15)
    spine(absorb, lean=8.0, chest_lean=3.0, hips=(2.0, 0.0, 0.0), neck=(-4.0, 0.0, 0.0), head=(-4.0, 0.0, 0.0))
    legs_from(absorb)
    rope_hands(absorb, ez - 0.15 + 0.80, ez - 0.15 + 0.14, 0.9)
    # release: hands off the rope, arms come back toward the alert carry, rising
    rel = Pose()
    hips_at(sk, rel, 0.0, -0.02, ez - 0.07)
    spine(rel, lean=10.0, chest_lean=3.0, hips=(4.0, 0.0, 0.0), neck=(-2.0, 0.0, 0.0), head=(-2.0, 0.0, 0.0))
    legs_from(rel)
    for sfx, sx in A.SIDES:
        arm_fk(sk, rel, sfx, add=30.0, swing=26.0, flex=58.0, twist=14.0, out=4.0)
        rel.hands[sfx] = hand_shape("loose_fist", 0.6)
    over = end.copy()
    over.hip = over.hip + v3(0.0, 0.0, -0.015 * k)
    add_rot(over, "spine", rxd(-2.0))
    return Keys(solver, [(0, start, "inout"), (touch - 3, reach, "inout"), (touch, tch, "in"), (touch + 5, absorb, "out"),
                         (touch + 15, rel, "inout"), (touch + 20, over, "inout"), (N, end, "inout")])


# =============================================================================================
# helicopter door kneel (sniper)
# =============================================================================================
_AIM_REF: dict = {}


def _aim_ref(sk: Skeleton) -> tuple[np.ndarray, np.ndarray]:
    """(eye, weapon origin) of the standing ``aim_rifle`` pose without sway: the cheek weld the kneel copies."""
    import _anim_humanoid as H  # noqa: PLC0415

    key = round(sk.scale, 6)
    if key not in _AIM_REF:
        pose = H.gun_pose(sk, True, 0.0, sway=0.0)
        s = Solver(sk).solve(pose)
        _R, o = H.rifle_aim_frame(sk, 0.0, 0.0)
        _AIM_REF[key] = (_eye(sk, s), o)
    return _AIM_REF[key]


def _eye(sk: Skeleton, s) -> np.ndarray:
    return s.P["head"] + s.W["head"] @ v3(0.0, 0.085 * sk.scale, 0.085 * sk.scale)


def kneel_legs(sk: Skeleton, pose: Pose, t: float = 0.0, sway: float = 1.0) -> None:
    """Kneeling on the right knee (shin and instep flat on the floor behind), sitting back toward the right heel,
    the left foot planted forward; the pelvis turned a little to the right (bladed toward the rifle)."""
    k = sk.scale
    sw = sway * math.sin(TAU * t / 3.0)
    hips_at(sk, pose, 0.02 + 0.006 * sw, -0.06, HELI_KNEEL_HIP_Z + 0.004 * math.sin(TAU * t / 1.5))
    pose.legs["R"] = LegIK(ankle=v3(0.15 * k, -0.42 * k, 0.085 * k), foot=rxd(-118.0) @ rzd(-14.0), toe=A.rad(22.0),
                           pole=unit(v3(0.20, 1.0, -0.55)))
    pose.legs["L"] = LegIK(ankle=v3(-0.17 * k, 0.33 * k, 0.085 * k), foot=A.foot_rot(yaw=12.0), toe=0.0,
                           pole=unit(v3(-0.35, 1.0, 0.6)))


def heli_gun_pose(sk: Skeleton, t: float = 0.0, sway: float = 1.0, recoil: float = 0.0, ready: float = 0.0) -> Pose:
    """The door kneel with the rifle aimed level along +Y (``ready`` 0) or at the low ready (``ready`` 1: muzzle
    down, stock still in the shoulder, head up looking out); ``recoil`` 0..1 as ``aim_rifle`` / ``fire_rifle``."""
    import _anim_humanoid as H  # noqa: PLC0415

    k = sk.scale
    pose = Pose()
    kneel_legs(sk, pose, t, sway)
    sw = sway
    spine(pose, lean=22.0 + 2.0 * ready, twist=-10.0, chest_lean=8.0, chest_twist=-8.0, chest_side=-2.0,
          neck=(-12.0 + 4.0 * ready, 0.0, 6.0), head=(-6.0 + 6.0 * ready, 8.0 * (1.0 - ready), 6.0),
          hips=(10.0, 0.0, -14.0))
    if ready:
        look(pose, yaw=10.0 * sw * math.sin(TAU * t / 3.0 + 0.4), pitch=-16.0 * ready)
    eye_std, o_std = _aim_ref(sk)
    s = Solver(sk).solve(pose)
    eye = _eye(sk, s)
    o = eye + (o_std - eye_std)
    o = o + v3(0.002 * k * sw * math.sin(TAU * t / 3.0), 0.0, 0.003 * k * sw * math.sin(TAU * t / 1.5))
    R, _o = weapon_frame(o, yaw=0.4 * sw * math.sin(TAU * t / 3.0 + 0.7), pitch=0.35 * sw * math.sin(TAU * t / 1.5 + 1.2))
    if ready:
        # low ready: pivot about the butt in the shoulder, muzzle 32 deg down and a little in
        butt = o + R @ H.RIFLE["butt"] * k
        Rr = rzd(10.0 * ready) @ rxd(-32.0 * ready) @ R
        o = butt - Rr @ H.RIFLE["butt"] * k + v3(0.0, -0.02 * k * ready, -0.05 * k * ready)
        R = Rr
    o = o + R @ v3(0.0, -0.022 * k * recoil, 0.004 * k * recoil)
    R = R @ rxd(3.5 * recoil)
    add_rot(pose, "chest", rxd(1.6 * recoil))
    H.hold_rifle(sk, pose, (R, o))
    if ready:
        pose.hands["R"] = hand_shape("grip", 0.9)
    _breathe(pose, t, 1.5, 0.6 * sway)
    return pose


def heli_door_idle(sk: Skeleton, f: int, N: int) -> Pose:
    return heli_gun_pose(sk, f / FPS * (90.0 / N), ready=1.0)


def heli_door_aim(sk: Skeleton, f: int, N: int) -> Pose:
    return heli_gun_pose(sk, f / FPS * (90.0 / N))


def heli_door_fire(sk: Skeleton, N: int):
    def fn(f: int) -> Pose:
        rec = A.pulse(f / FPS, 1.0 / FPS, (N - 1) / FPS)
        return heli_gun_pose(sk, 0.0, sway=0.0, recoil=rec)
    return fn


# =============================================================================================
# van exit
# =============================================================================================
def root_s(name: str, f: float, N: int) -> float:
    """Root travel (m at 1.78 m, along ROOT_MOTION's direction) at frame ``f`` of ``van_exit`` / ``breach_standback``."""
    total = ROOT_MOTION[name][0]
    if name == "van_exit":
        return total * smooth(3.0, 30.0, f)
    return total * smooth(2.0, 20.0, f)


def _alert_carry(sk: Skeleton, p: Pose, flex: float = 52.0) -> None:
    for sfx, _sx in A.SIDES:
        arm_fk(sk, p, sfx, add=30.0, swing=16.0, flex=flex, twist=14.0)
        p.hands[sfx] = hand_shape("loose_fist", 0.8)


def van_exit(sk: Skeleton, solver: Solver, N: int, step_r: int, step_l: int) -> Keys:
    """Authored in the FINAL root's frame (the landing spot): crouched on the step (top VAN_STEP_Z, feet
    VAN_STEP_BACK behind), the right foot steps forward and down to the floor (``step_r``), the left follows
    (``step_l``) onto idle_alert frame 0's foot places, the body rises into idle_alert frame 0. ``post`` moves the
    body back by the root travel still to come (``root_s``), so frame 0 stands over the root and the clip is in
    place; planted feet are world-still at that root motion."""
    k = sk.scale
    end = _src(sk, solver, "idle_alert", 0)
    ez = float(end.hip[2]) + sk.head["hips"][2]
    sz, sb = VAN_STEP_Z, VAN_STEP_BACK
    foot_l = v3(-0.10 * k, -sb * k, (sz + 0.085) * k)
    foot_r = v3(0.11 * k, (-sb - 0.05) * k, (sz + 0.085) * k)
    pole = {"L": v3(-0.1, 1.0, 0.0), "R": v3(0.1, 1.0, 0.0)}

    def on_step(p: Pose, sfx: str, pos, pitch: float = 0.0, toe: float = 0.0) -> None:
        p.legs[sfx] = LegIK(ankle=pos.copy(), foot=A.foot_rot(yaw=-A.side_x(sfx) * 7.0, pitch=pitch), toe=A.rad(toe),
                            pole=unit(pole[sfx]))

    def end_leg(p: Pose, sfx: str, dz: float = 0.0, dy: float = 0.0, pitch: float = 0.0) -> None:
        g = end.legs[sfx]
        p.legs[sfx] = LegIK(ankle=g.ankle + v3(0.0, dy * k, dz * k), foot=A.foot_rot(pitch=pitch) @ g.foot, toe=g.toe,
                            pole=g.pole.copy())

    def body(p: Pose, y: float, z: float, lean: float, head: float, hipsp: float = 10.0, hand_flex: float = 56.0) -> None:
        hips_at(sk, p, 0.0, y, z)
        spine(p, lean=lean, chest_lean=lean * 0.4, hips=(hipsp, 0.0, 0.0), neck=(-head * 0.4, 0.0, 0.0),
              head=(-head * 0.6, 0.0, 0.0))
        _alert_carry(sk, p, hand_flex)

    # crouched in the doorway on the step, head ducked under the door top
    crouch = Pose()
    body(crouch, -sb + 0.02, sz + 0.80, 26.0, -6.0, hipsp=16.0)
    on_step(crouch, "L", foot_l)
    on_step(crouch, "R", foot_r)
    look(crouch, yaw=8.0, pitch=12.0)
    # weight forward over the left foot, the right foot lifts off the step
    lift = Pose()
    body(lift, -sb + 0.10, sz + 0.76, 24.0, 8.0, hipsp=14.0)
    on_step(lift, "L", foot_l, pitch=0.0)
    on_step(lift, "R", foot_r + v3(0.0, 0.10 * k, 0.10 * k), pitch=-16.0)
    look(lift, pitch=24.0)
    # the right foot clears the step edge, reaching down
    reach = Pose()
    body(reach, -sb + 0.20, sz + 0.62, 18.0, 16.0, hipsp=10.0)
    on_step(reach, "L", foot_l, pitch=-10.0, toe=10.0)
    end_leg(reach, "R", dz=sz * 0.55, dy=-0.30, pitch=8.0)
    look(reach, pitch=26.0)
    # the right foot lands on the floor (step_r): long step down, left heel up on the step
    land_r = Pose()
    body(land_r, -0.22, ez - 0.12, 14.0, 12.0, hipsp=8.0)
    plant_l_heelup = foot_l + v3(0.0, 0.05 * k, 0.03 * k)
    on_step(land_r, "L", plant_l_heelup, pitch=-34.0, toe=34.0)
    end_leg(land_r, "R")
    look(land_r, pitch=16.0)
    # the left foot swings down off the step
    swing_l = Pose()
    body(swing_l, -0.08, ez - 0.08, 8.0, 6.0, hipsp=4.0)
    end_leg(swing_l, "R")
    end_leg(swing_l, "L", dz=0.10, dy=-0.18, pitch=-6.0)
    # the left foot lands (step_l), small settle into idle_alert
    land_l = Pose()
    body(land_l, -0.02, ez - 0.035, 7.0, 2.0, hipsp=2.0)
    end_leg(land_l, "R")
    end_leg(land_l, "L")

    def post(f: int, pose: Pose) -> None:
        shift(pose, v3(0.0, (VAN_STEP_BACK - root_s("van_exit", f, N)) * k, 0.0))
    return Keys(solver, [(0, crouch, "inout"), (6, crouch.copy(), "inout"), (11, lift, "inout"), (13, reach, "inout"),
                         (step_r, land_r, "in"), (step_r + 6, swing_l, "inout"), (step_l, land_l, "in"),
                         (N, end, "inout")], post=post)


# =============================================================================================
# breach charge: place, stand back
# =============================================================================================
def breach_place(sk: Skeleton, solver: Solver, N: int, place: int) -> Keys:
    """From idle_alert frame 0: brings the charge up in both hands, steps in with the left foot, presses it flat on
    the wall BREACH_WALL ahead at BREACH_CHARGE (``place``), holds, lets go, steps back to idle_alert frame 0."""
    k = sk.scale
    start = _src(sk, solver, "idle_alert", 0)
    ez = float(start.hip[2]) + sk.head["hips"][2]
    cx, cy, cz = BREACH_CHARGE

    def hands(p: Pose, y: float, z: float, shape: str, side: bool = False, w: float = 0.075) -> None:
        """Palms forward on the charge face, fingers up (``side``: palms in on the charge's edges, fingers forward)."""
        for sfx, sx in A.SIDES:
            al, pa = (v3(-sx * 0.2, 1.0, 0.45), v3(-sx * 1.0, 0.0, 0.0)) if side else (v3(-sx * 0.25, 0.15, 1.0),
                                                                                    v3(0.0, 1.0, 0.0))
            hand_on(sk, p, sfx, v3((cx + sx * w) * k, y * k, z * k), al, pa,
                    pole=v3(sx * 0.8, -0.3, -0.6), along_share=0.45, palm_off=0.014)
            p.hands[sfx] = hand_shape(shape, 0.8 if shape == "grip" else 1.0)

    def legs(p: Pose, step: float) -> None:
        for sfx in ("L", "R"):
            g = start.legs[sfx]
            d = v3(0.0, step * k, 0.0) if sfx == "L" else v3(0.0, step * 0.35 * k, 0.0)
            p.legs[sfx] = LegIK(ankle=g.ankle + d, foot=g.foot.copy(), toe=g.toe, pole=g.pole.copy())

    def body(p: Pose, y: float, z: float, lean: float, head: float) -> None:
        hips_at(sk, p, 0.0, y, z)
        spine(p, lean=lean, chest_lean=lean * 0.5, hips=(2.0, 0.0, 0.0), neck=(head * 0.4, 0.0, 0.0),
              head=(head * 0.6, 0.0, 0.0))

    # the charge held in front of the belly (fists round its edges)
    carry = Pose()
    body(carry, -0.01, ez, 6.0, 10.0)
    legs(carry, 0.0)
    hands(carry, 0.26, 1.02, "grip", side=True, w=0.11)
    # step in with the left foot, raising the charge
    step = Pose()
    body(step, 0.06, ez - 0.02, 8.0, 6.0)
    legs(step, 0.16)
    hands(step, 0.33, 1.08, "grip", side=True, w=0.11)
    reach = Pose()
    body(reach, 0.08, ez - 0.025, 10.0, 4.0)
    legs(reach, 0.16)
    hands(reach, cy - 0.04, cz, "flat")
    press = reach.copy()
    hands(press, cy, cz, "flat")
    hold = press.copy()
    off = Pose()
    body(off, 0.05, ez - 0.02, 7.0, 6.0)
    legs(off, 0.16)
    hands(off, cy - 0.12, cz - 0.08, "relaxed", side=True, w=0.12)
    back = Pose()
    body(back, 0.0, ez - 0.01, 5.0, 4.0)
    legs(back, 0.0)
    _alert_carry(sk, back, 50.0)
    return Keys(solver, [(0, start, "inout"), (8, carry, "inout"), (16, step, "inout"), (place - 4, reach, "inout"),
                         (place, press, "out"), (place + 2, hold, "inout"), (place + 9, off, "inout"),
                         (N - 2, back, "inout"), (N, start.copy(), "inout")])


def breach_standback(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """From breach_place's last frame (= idle_alert frame 0): a side step to the left out of the blast line (the left
    foot, then the right closes), sinking into a braced crouch, the head and shoulders turned away from the wall
    (left and down), forearms up by the head; settles exactly on crouch_idle frame 0 as the head comes back to the
    front. Authored in the FINAL root's frame; ``post`` adds the root travel still to come (in place, root motion
    along Godot -X by ``curve.breach_standback``)."""
    k = sk.scale
    start = _src(sk, solver, "idle_alert", 0)
    end = _src(sk, solver, "crouch_idle", 0)
    X = STANDBACK_X
    sz = float(start.hip[2]) + sk.head["hips"][2]
    ez = float(end.hip[2]) + sk.head["hips"][2]
    s0 = start.copy()
    shift(s0, v3(X * k, 0.0, 0.0))

    def leg(p: Pose, sfx: str, src: Pose, d=(0.0, 0.0, 0.0), dx: float = 0.0) -> None:
        g = src.legs[sfx]
        p.legs[sfx] = LegIK(ankle=g.ankle + v3(*d) * k + v3(dx * k, 0.0, 0.0), foot=g.foot.copy(), toe=g.toe,
                            pole=g.pole.copy())

    def brace_arms(p: Pose, w: float) -> None:
        for sfx, sx in A.SIDES:
            arm_fk(sk, p, sfx, add=24.0 - 6.0 * w, swing=34.0 + 46.0 * w, flex=60.0 + 50.0 * w, twist=16.0 + 14.0 * w,
                   out=4.0 + 8.0 * w, clav_fwd=6.0 + 6.0 * w)
            p.hands[sfx] = hand_shape("loose_fist", 0.9)

    # weight onto the right foot, the left lifts and the head starts turning away
    lift = Pose()
    hips_at(sk, lift, X + 0.04, -0.01, sz - 0.03)
    spine(lift, lean=6.0, chest_lean=2.0, side=-3.0, twist=6.0, hips=(1.0, 0.0, 0.0))
    look(lift, yaw=30.0, pitch=8.0)
    leg(lift, "R", start, dx=X)
    leg(lift, "L", start, d=(-0.10, 0.0, 0.08), dx=X)
    brace_arms(lift, 0.2)
    # the left foot lands wide to the left, hips moving across and down
    wide = Pose()
    hips_at(sk, wide, X * 0.55, -0.04, sz - 0.12)
    spine(wide, lean=12.0, chest_lean=6.0, side=2.0, twist=14.0, hips=(6.0, 0.0, 0.0))
    look(wide, yaw=55.0, pitch=16.0)
    leg(wide, "R", start, dx=X)
    leg(wide, "L", end, d=(0.04, 0.0, 0.0))
    brace_arms(wide, 0.6)
    # the right foot closes (lifted), crouching
    close = Pose()
    hips_at(sk, close, 0.10, -0.08, ez + 0.08)
    spine(close, lean=16.0, chest_lean=10.0, twist=18.0, hips=(12.0, 0.0, 0.0))
    look(close, yaw=62.0, pitch=24.0)
    leg(close, "L", end, d=(0.02, 0.0, 0.0))
    leg(close, "R", end, d=(0.10, 0.02, 0.07))
    brace_arms(close, 1.0)
    # braced: crouched on crouch_idle's feet, turned away from the blast, head down, forearms by the head
    brace = Pose()
    hips_at(sk, brace, 0.0, -0.10, ez - 0.01)
    spine(brace, lean=18.0, chest_lean=14.0, twist=20.0, chest_twist=6.0, hips=(14.0, 0.0, 0.0))
    look(brace, yaw=66.0, pitch=30.0, tilt=-6.0)
    leg(brace, "L", end)
    leg(brace, "R", end)
    brace_arms(brace, 1.0)
    hold = brace.copy()
    add_rot(hold, "head", rxd(-3.0))

    def post(f: int, pose: Pose) -> None:
        shift(pose, v3(-(X - root_s("breach_standback", f, N)) * k, 0.0, 0.0))
    return Keys(solver, [(0, s0, "inout"), (5, lift, "inout"), (10, wide, "in"), (15, close, "inout"),
                         (19, brace, "out"), (23, hold, "inout"), (N, end, "inout")], post=post)


# =============================================================================================
# factory
# =============================================================================================
#: clips that rest on the floor (Clip.floor, from frame 0): the kneel's right knee / shin on the sill
FLOOR = {"heli_door_idle": 0, "heli_door_aim": 0, "heli_door_fire": 0}


def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N, loop, speed, ev = int(row["frames"]), bool(row["loop"]), float(row["speed"]), dict(row.get("events", {}))
        if name in ("rappel_hang", "rappel_descend", "heli_door_idle", "heli_door_aim"):
            fn = {"rappel_hang": rappel_hang, "rappel_descend": rappel_descend, "heli_door_idle": heli_door_idle,
                  "heli_door_aim": heli_door_aim}[name]
            out[name] = Clip(name, N, loop, (lambda f, fn=fn, N=N: fn(sk, f, N)), speed, None, ev, reach_fix=False)
        elif name == "heli_door_fire":
            out[name] = Clip(name, N, loop, heli_door_fire(sk, N), speed, None, ev, reach_fix=False)
        elif name == "rappel_land":
            out[name] = Clip(name, N, loop, rappel_land(sk, solver, N, int(ev["touch"])), speed, None, ev,
                             reach_fix=False)
        elif name == "van_exit":
            out[name] = Clip(name, N, loop, van_exit(sk, solver, N, int(ev["step_r"]), int(ev["step_l"])), speed,
                             None, ev, reach_fix=False)
        elif name == "breach_place":
            out[name] = Clip(name, N, loop, breach_place(sk, solver, N, int(ev["place"])), speed, None, ev,
                             reach_fix=False)
        else:
            out[name] = Clip(name, N, loop, breach_standback(sk, solver, N), speed, None, ev, reach_fix=False)
        if name in FLOOR:
            out[name].floor = FLOOR[name]
    return out


# =============================================================================================
# checks and SOURCE.txt notes
# =============================================================================================
KEEP = NAMES + ("idle_alert", "crouch_idle")


def _g(p) -> str:
    """Blender (x, y fwd, z up) -> Godot (x, y up, -z fwd) text."""
    return f"({p[0]:.3f},{p[2]:.3f},{-p[1]:.3f})"


def _socket(sk: Skeleton, s, sfx: str) -> np.ndarray:
    _r, t_off = A.grip_offset(sk, sfx)
    return s.P[f"hand.{sfx}"] + s.W[f"hand.{sfx}"] @ sk.B[f"hand.{sfx}"] @ t_off


def rope_err(sk: Skeleton, frames: list) -> float:
    """Worst horizontal distance (m) of either fist's socket origin from the rope line over ``frames``."""
    worst = 0.0
    for s in frames:
        for sfx in ("L", "R"):
            p = _socket(sk, s, sfx)
            worst = max(worst, math.hypot(float(p[0]), float(p[1]) - ROPE_Y * sk.scale))
    return worst


def sternum_gap(sk: Skeleton, s) -> float:
    """Rope line minus the most forward chest skin point (|x| < 5 cm, between the chest and neck joints)."""
    pr = A.probe_for(sk)
    V = pr.posed(s)
    c, n = s.P["chest"], s.P["neck"]
    trunk = np.isin(pr.bi[:, 0], [pr.index["chest"], pr.index["spine"]])      # chest skin, not the fists / forearms
    m = trunk & (V[:, 2] > c[2]) & (V[:, 2] < n[2]) & (np.abs(V[:, 0]) < 0.05 * sk.scale)
    return ROPE_Y * sk.scale - float(V[m, 1].max())


def lowest_skin(sk: Skeleton, frames: list) -> float:
    pr = A.probe_for(sk)
    return min(float(pr.posed(s)[:, 2].min()) for s in frames)


def crown(sk: Skeleton, s) -> float:
    """Top of the head (skin) height."""
    V = A.probe_for(sk).posed(s)
    return float(V[:, 2].max())


def check_row(sk: Skeleton, table: dict, name: str, baked, keep: dict) -> str:
    from _anim_d304 import pose_err  # noqa: PLC0415

    fr = baked.frames
    txt = f" lowest_skin={lowest_skin(sk, fr) * 1000:.1f}mm"
    if name in ROPE_CLIPS:
        txt += f" rope_err={rope_err(sk, fr) * 1000:.1f}mm sternum_gap={sternum_gap(sk, fr[0]) * 100:.1f}cm"
        txt += f" feet_above_root={min(min(float(s.P[f'toe.{x}'][2]) for x in 'LR') for s in fr):.2f}m"
    if name in STARTS:
        src, f = STARTS[name]
        if src in keep:
            sf = keep[src].frames
            txt += f" start_err={pose_err(fr[0], sf[f]):.2f}mm"
    if name in ENDS:
        src, f = ENDS[name]
        if src in keep:
            txt += f" end_err={pose_err(fr[-1], keep[src].frames[f]):.2f}mm"
    if name in HELI:
        txt += f" crown={max(crown(sk, s) for s in fr):.3f}m"
    return txt


def row_extra(row: dict) -> str:
    return f" root_motion={row['root_motion']}" if "root_motion" in row else ""


def source_notes(sk: Skeleton, table: dict, keep: dict) -> dict[str, str]:
    k = sk.scale
    out: dict[str, str] = {}
    for name, (total, d) in ROOT_MOTION.items():
        if name not in table:
            continue
        N = int(table[name]["frames"])
        curve = [root_s(name, float(f), N) * k for f in range(N + 1)]
        out[f"curve.{name}"] = (f"root_m={','.join(f'{x:.4f}' for x in curve)} total_m={curve[-1]:.3f} "
                                f"dir_godot=({d[0]:g},{d[1]:g},{d[2]:g})")
    hang = keep.get("rappel_hang")
    gap = f"{sternum_gap(sk, hang.frames[0]):.2f}" if hang is not None else "0.10"
    out["rappel_assault"] = (
        f"PO6-17 rappel_hang / rappel_descend / rappel_land: the rope is the vertical line at Godot x=0.000 "
        f"z={-ROPE_Y * k:.3f} in root space (straight up and down through the root's y axis offset {ROPE_Y * k:.3f} m "
        f"ahead; {gap} m in front of the sternum in rappel_hang). Both fists hold it on every frame of rappel_hang and "
        f"rappel_descend: the HandL / HandR Socket origins are ON the line (within 1 cm) and the rope runs through the "
        f"fist along the socket's grip axis, so spawn the rope through that line, no rope sockets. Root = the rope "
        f"reference point on the line's foot: the lowest foot point is {RAPPEL_CLEAR:.2f} m above the root plane at "
        f"frame 0 of both loops (hang: right fist above the head, left at the chest, feet together; descend: brake "
        f"fist (right) at the hip, guide fist (left) at the face, legs braced forward-down, feet 0.38 m apart, the rope "
        f"between the knees). rappel_descend in place: move the root straight down at clip.rappel_descend speed_mps "
        f"(2.5 m/s at 1.78 m x motion_scale, AnimTweak.clip_speeds) and loop it; switch to rappel_land with the root "
        f"put on the floor (the feet are then {RAPPEL_CLEAR:.2f} m above it at frame 0 and touch it at `touch`); "
        f"rappel_land frame 0 IS rappel_descend frame 0 and its last frame IS idle_alert frame 0 (no crossfades). "
        f"The fists slide down the rope with the body until ~touch+5 and let go by ~touch+11 (stop drawing the rope "
        f"to the hands then). hang -> descend: crossfade ~0.25 s.")
    rx, ry, rz = HELI_ROOT_IN_SNIPER_SEAT
    out["heli_door_sill"] = (
        f"heli_door_idle / heli_door_aim / heli_door_fire: kneeling on the right knee (shin and instep flat behind), "
        f"left foot forward, the root plane = the floor / door sill the knee rests on (lowest skin on it), facing -Z "
        f"(out of the door: A yaws the root to aim), the door edge {HELI_SILL_AHEAD:.2f} m ahead of the root. Rifle at "
        f"HandR/Socket, the aim_rifle convention (LeftHandIK on the handguard): heli_door_aim aims level along -Z with "
        f"aim_rifle's cheek weld; heli_door_idle holds it at the low ready (muzzle ~32 deg down), head up scanning; "
        f"heli_door_fire = fire_rifle's recoil (shot@0) from heli_door_aim. ENV C prop_police_helicopter (8c1935dc): "
        f"Model/SniperSeat (heli {HELI_SEAT}) is on the rear bench top, {HELI_SEAT[1] - HELI_FLOOR_Y:.3f} m above the "
        f"cabin floor ({HELI_FLOOR_Y} m), not on the sill, and the bench fills the floor under it; put the root at "
        f"SniperSeat.transform * Transform3D(Basis(), Vector3({rx:.2f}, {ry:.3f}, {rz:.2f})) (heli (-0.38, 0.736, "
        f"-0.38): on the cabin floor 0.33 m forward of the bench face, {HELI_SILL_AHEAD:.2f} m inside the left door "
        f"edge, same facing). Cabin headroom {HELI_HEADROOM:.3f} m above the floor: see heli crown= in the check rows.")
    out["van_exit_step"] = (
        f"van_exit: starts crouched (head ducked) on a step whose top is {VAN_STEP_Z:.2f} m above the root plane; in "
        f"place like walk_start: at frame 0 the body stands over the root (the step under the feet, its front edge "
        f"{VAN_STEP_BACK - VAN_STEP_EDGE:.2f} m ahead of the root at frame 0, the root itself on the floor below); A "
        f"moves the root forward (-Z) by curve.van_exit (total {VAN_STEP_BACK:.2f} m) and the clip ends exactly on "
        f"idle_alert frame 0 over the final root. So: put the root at frame 0 on the floor {VAN_STEP_BACK:.2f} m behind "
        f"the landing spot (the feet {VAN_STEP_BACK:.2f} m behind it on the step). step_r = the right foot lands on the "
        f"floor, step_l = the left follows. Planted feet are world-still at that root motion.")
    cx, cy, cz = BREACH_CHARGE
    out["breach_charge"] = (
        f"breach_place: from and back to idle_alert frame 0, root fixed; the wall face (the breach's cops' face) "
        f"{BREACH_WALL:.2f} m ahead of the root (Godot z -{BREACH_WALL:.2f}), the root centred on the charge. Both palms "
        f"press the charge's face at `place` (centre Godot ({cx:.2f},{cz:.2f},{-cy:.2f}): a 4 cm charge on the wall at "
        f"{cz:.2f} m, matching prop_breach_*'s Model/Charge 1.1 m), hold briefly and let go; spawn the charge on the "
        f"wall at `place` (it is not in a hand socket). Root placement: EntryPoint-side, {BREACH_WALL:.2f} m from the "
        f"cops' face, facing it. breach_standback: from breach_place's last frame (= idle_alert frame 0), steps "
        f"{STANDBACK_X:.2f} m to its LEFT (root motion curve.breach_standback along Godot -X; in place like walk_start) "
        f"into a braced crouch, head and shoulders turned away from the wall (frames ~10-23), ends exactly on "
        f"crouch_idle frame 0 (head back to the front): loop crouch_idle until the blast.")
    rows = []
    for name in NAMES:
        b = keep.get(name)
        if b is not None:
            rows.append(f"{name}:{check_row(sk, table, name, b, keep)}")
    if rows:
        out["assault_checks"] = "; ".join(rows)
    return out
