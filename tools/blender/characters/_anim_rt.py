"""RT-D1 Rolling Thunder clips (docs/design/heists/rolling_thunder.md, QC-86) for the ``humanoid`` library: vehicle
occupants and their dismount, the roadside diner's customers and cook. Private helper of ``anim_humanoid.py`` (pure
numpy; wired like ``_anim_bank``).

* ``sit_vehicle`` (loop): seated in a car / armoured-cab bucket seat, lower and more reclined than ``sit_chair``: the
  hips joint ``VEH_HIP_Z`` m above the root plane (the cushion ``VEH_SEAT_Z``), the feet forward in the footwell, both
  hands resting on the thighs; slow breathing, the head looking about (out of the windscreen, the side window, the
  mirror). The root on the footwell floor under the seat centre, facing the vehicle's forward (-Z).
* ``vehicle_exit_l`` / ``vehicle_exit_r`` (one-shot): from ``sit_vehicle`` frame 0, the body turns to the door (the
  character's left / right), the door-side hand takes the door frame, the door-side leg swings out over the sill and
  plants outside (``foot_out``), the seat-side hand pushes off the cushion, the body rises (ducking the roof) and the
  inner leg follows out (``step_r`` / ``step_l``), the door-side foot steps clear (``step_l`` / ``step_r``) and the body
  turns back to the front, ending exactly on ``idle_alert`` frame 0. Authored in the seat's frame; in place like
  ``van_exit``: A moves the root sideways (Godot -X for _l, +X for _r) by ``curve.vehicle_exit_<side>`` (total
  ``EXIT_X`` m), planted feet are world-still at that root motion. The footwell floor is assumed level with the ground
  outside (escort cars; SOURCE ``rt_vehicle_placement``).
* ``sit_eat`` (loop): at a diner booth table (sit_chair's seat ``SEAT_H``, table top ``TABLE_Z``): the left hand rests
  by the plate, the right hand carries a fork from the plate to the mouth (``bite``) a few times per loop and once
  lifts a cup (``sip``).
* ``cook_stove`` (loop): standing at a stove / griddle (top ``STOVE_Z``, front edge ``STOVE_EDGE`` ahead): the right
  hand works a spatula over the griddle (scrape and flip, ``flip``), the left hand rests on the stove rail, a stir, the
  occasional glance up (``look_up``). Root fixed.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
import _anim_humanoid as H
from _anim import FPS, TAU, Clip, Keys, LegIK, Pose, Skeleton, Solver, add_rot, hand_on, hand_shape, rxd, ryd, rzd, \
    smooth, spine, unit, v3

#: the clips this module builds (each one row in anim_humanoid.CLIPS)
NAMES = ("sit_vehicle", "vehicle_exit_l", "vehicle_exit_r", "sit_eat", "cook_stove")
EXITS = ("vehicle_exit_l", "vehicle_exit_r")
KEEP = NAMES

# placement (metres at 1.78 m, Blender axes: x right, y ahead of the root, z up)
#: sit_vehicle: cushion top and the hips joint above the root plane (the footwell floor)
VEH_SEAT_Z = 0.36
VEH_HIP_Z = 0.43
#: the door sill line (the vehicle's side), m beside the seat centre, and its top above the footwell floor
SILL_X = 0.42
SILL_Z = 0.22
#: vehicle_exit_*: the root's sideways travel out of the door (from the seat centre to the standing spot)
EXIT_X = 0.85
#: the door frame point the door-side hand takes (x out from the seat centre, y ahead of the seat centre, height)
FRAME_GRIP = (0.44, 0.12, 1.02)
#: sit_eat: the booth table top and its near edge ahead of the root (the seat is sit_chair's, H.SEAT_H); the plate
#: centre, the glass and the left hand's rest place on the top (x, y)
TABLE_Z = 0.74
TABLE_EDGE = 0.22
PLATE = (0.0, 0.42)
GLASS = (-0.24, 0.40)
REST_L = (-0.15, 0.34)
#: cook_stove: the griddle top and its front edge ahead of the root; the spatula blade's rest point and the left hand on
#: the front rail (x, y)
STOVE_Z = 0.90
STOVE_EDGE = 0.30
SPATULA = (0.12, 0.52)
RAIL_L = (-0.24, 0.36)

#: schedules (s); events are written as frames in anim_humanoid.CLIPS
BITES = (1.6, 3.9)                     # sit_eat: the fork at the lips (bite, bite_2)
SIP = (5.2, 6.1, 6.6, 7.2)             # sit_eat: lift start, at the lips (sip), leave the lips, set down
FLIPS = (1.6, 3.4)                     # cook_stove: the blade turns (flip, flip_2)
STIR = (2.1, 2.9)                      # cook_stove
LOOK_UP_C = (4.3, 5.4)                 # cook_stove


def _cyc(t: float, T: float, n: int, ph: float = 0.0) -> float:
    return math.sin(TAU * n * t / T + ph)


def _win(t: float, T: float, a: float, b: float, edge: float) -> float:
    """Cyclic window weight: 1 inside [a, b] (s) with smoothstep edges ``edge`` wide inside it, 0 outside."""
    w = 0.0
    for sh in (-T, 0.0, T):
        x = t + sh
        w = max(w, A.smooth(a, a + edge, x) * (1.0 - A.smooth(b - edge, b, x)))
    return w


def _shift(pose: Pose, d) -> None:
    """Translate the whole posed body (hips and every IK goal) by ``d``."""
    d = np.asarray(d, float)
    pose.hip = pose.hip + d
    for g in pose.legs.values():
        g.ankle = g.ankle + d
    for g in pose.arms.values():
        g.wrist = g.wrist + d


def _hips_at(sk: Skeleton, pose: Pose, x: float, y: float, z: float) -> None:
    k = sk.scale
    pose.hip = v3(x * k, y * k, z * k - sk.head["hips"][2])


def _foot(sk: Skeleton, pose: Pose, sfx: str, x: float, y: float, lift: float = 0.0, yaw: float = 0.0,
          pitch: float = 0.0, pole=None) -> None:
    """Leg goal: the ankle at (x, y) m (the foot flat, ``lift`` m up), the toes turned ``yaw`` deg (+ = left)."""
    k = sk.scale
    g = sk.ground(sfx)
    if pole is None:
        pole = rzd(yaw) @ v3(A.side_x(sfx) * 0.15, 1.0, 0.3)
    pose.legs[sfx] = LegIK(ankle=v3(x * k, y * k, float(g["ankle"][2]) + lift * k), foot=A.foot_rot(yaw, pitch),
                           toe=0.0, pole=unit(pole))


# =============================================================================================
# sit_vehicle
# =============================================================================================
def vehicle_seated(sk: Skeleton, pose: Pose, yaw: float = 0.0, lean: float = 0.0) -> None:
    """The bucket seat: the hips joint VEH_HIP_Z up, reclined, knees up and forward, the feet in the footwell."""
    k = sk.scale
    H.seated(sk, pose, seat_h=VEH_SEAT_Z, recline=20.0)
    pose.hip = v3(0.0, -0.10 * k, VEH_HIP_Z * k - sk.head["hips"][2])
    spine(pose, hips=(-66.0 + lean, 0.0, yaw), lean=66.0 + 0.5 * lean, chest_lean=-2.0 + 0.4 * lean)
    for sfx, sx in A.SIDES:
        A.plant(sk, pose, sfx, (sx * 0.07 * k, 0.52 * k, 0.0), yaw=-sx * 12.0, pitch=10.0, pivot="heel",
                pole=v3(sx * 0.2, 0.5, 1.0))


def _thigh_hand(sk: Skeleton, pose: Pose, sfx: str, slide: float = 0.0) -> None:
    """The hand resting on the top of the thigh, ~60 % down it, the fingers toward the knee."""
    pre = Solver(sk).solve(pose)
    sx = A.side_x(sfx)
    hp, kn = pre.P[f"thigh.{sfx}"], pre.P[f"shin.{sfx}"]
    d = unit(kn - hp)
    p = hp + (kn - hp) * (0.58 + slide) + v3(-sx * 0.012, 0.0, 0.075) * sk.scale
    hand_on(sk, pose, sfx, p, unit(d + v3(-sx * 0.25, 0.0, -0.15)), v3(0.0, 0.1, -1.0), pole=v3(sx * 0.9, -0.4, -0.2),
            along_share=0.5)
    pose.hands[sfx] = hand_shape("relaxed", 0.9)


def sit_vehicle(sk: Skeleton, f: int, N: int) -> Pose:
    """Seated in the bucket seat, the hands on the thighs; the head looks ahead, out of the side window, into the
    mirror, in held glances; slow breathing."""
    t = f / FPS
    T = N / FPS
    pose = Pose()
    vehicle_seated(sk, pose)
    # head: ahead, a look out of the left window, back, a check of the right / rear-view mirror
    g_l = _win(t, T, 1.6, 3.0, 0.4)
    g_r = _win(t, T, 4.3, 5.2, 0.3)
    H.look(pose, yaw=3.0 * _cyc(t, T, 1, 0.4) + 38.0 * g_l - 24.0 * g_r, pitch=-1.0 + 1.5 * _cyc(t, T, 2, 1.0) - 4.0 * g_r,
           tilt=2.0 * _cyc(t, T, 1, 2.0) - 3.0 * g_l)
    add_rot(pose, "chest", rzd(4.0 * g_l - 2.0 * g_r))
    H.breathe(pose, t, T / 3.0, 0.9)
    _thigh_hand(sk, pose, "L", 0.02 * _cyc(t, T, 1, 0.3))
    _thigh_hand(sk, pose, "R", 0.015 * _cyc(t, T, 2, 1.1))
    return pose


# =============================================================================================
# vehicle_exit_l / _r
# =============================================================================================
def root_s(f: float) -> float:
    """Root travel sideways (m at 1.78 m) at frame ``f`` of vehicle_exit_*: follows the body out of the door."""
    return EXIT_X * smooth(6.0, 41.0, f)


def vehicle_exit(sk: Skeleton, solver: Solver, N: int, side: str, ev: dict) -> Keys:
    """Out of the door on ``side`` ("L" = the character's left), authored in the SEAT's frame (frame 0's root, x
    right, y forward) and shifted by the root travel so far (``post``): the root ends EXIT_X m to that side, the body
    exactly on idle_alert frame 0 over it."""
    import _anim_d304 as d304  # noqa: PLC0415

    k = sk.scale
    s = 1.0 if side == "L" else -1.0           # + = out to the left (Blender -x), the body turns left (+yaw)
    door, inner = ("L", "R") if side == "L" else ("R", "L")
    dx = -s                                    # x sign of "toward the door"
    start = d304.src_pose(sk, solver, "sit_vehicle", 0)
    end = d304.src_pose(sk, solver, "idle_alert", 0)
    _shift(end, v3(dx * EXIT_X * k, 0.0, 0.0))
    ez = float(end.hip[2]) + sk.head["hips"][2]
    f_out, f_in, f_door = int(ev["foot_out"]), int(ev["step_" + inner.lower()]), int(ev["step_" + door.lower()])
    fx, fy, fz = FRAME_GRIP
    frame_pt = v3(dx * fx * k, fy * k, fz * k)

    def frame_hand(p: Pose, w: float = 1.0) -> None:
        """The door-side hand round the door frame (the pillar at the opening's front), fingers up-out, palm forward."""
        hand_on(sk, p, door, frame_pt, unit(v3(dx * 0.55, 0.15, 0.8)), unit(v3(-dx * 0.2, 1.0, 0.0)),
                pole=v3(dx * 0.6, -0.3, -1.0), along_share=0.45, palm_off=0.02)
        p.hands[door] = hand_shape("grip", 0.8 * w)

    def push_hand(p: Pose, x: float, y: float) -> None:
        """The seat-side hand pushes off the cushion beside the hip, palm down, fingers forward-out."""
        hand_on(sk, p, inner, v3(x * k, y * k, (VEH_SEAT_Z + 0.02) * k), unit(v3(dx * 0.4, 0.9, 0.0)),
                v3(0.0, 0.0, -1.0), pole=v3(-dx * 0.9, -0.5, -0.2), along_share=0.5)
        p.hands[inner] = hand_shape("rest_flat", 0.8)

    def end_leg(p: Pose, sfx: str) -> None:
        g = end.legs[sfx]
        p.legs[sfx] = LegIK(ankle=g.ankle.copy(), foot=g.foot.copy(), toe=g.toe, pole=g.pole.copy())

    def body(p: Pose, x: float, y: float, z: float, yaw: float, lean: float, seated_w: float) -> None:
        """Trunk: hips joint at (x, y, z), turned ``yaw`` (deg, + = left), ``lean`` forward; ``seated_w`` 1 = the seat's
        pelvis tilt (rolled back on the cushion), 0 = standing."""
        _hips_at(sk, p, x, y, z)
        hp = -66.0 * seated_w + 8.0 * (1.0 - seated_w)
        sl = 66.0 * seated_w + lean
        spine(p, hips=(hp, 0.0, yaw), lean=sl, chest_lean=0.4 * lean, neck=(-0.25 * lean, 0.0, 0.0),
              head=(-0.3 * lean, 0.0, 0.0))

    # 1 the head turns to the door, the door-side hand reaches the door frame
    look = start.copy()
    body(look, dx * 0.02, -0.10, VEH_HIP_Z, s * 10.0, 0.0, 1.0)
    H.look(look, yaw=s * 40.0, pitch=4.0)
    frame_hand(look, 0.7)
    _thigh_hand(sk, look, inner)
    # 2 the pelvis pivots on the cushion toward the door, the door-side leg lifts over the sill
    swing = Pose()
    body(swing, dx * 0.05, -0.08, VEH_HIP_Z + 0.01, s * 32.0, 6.0, 1.0)
    _foot(sk, swing, door, dx * (SILL_X + 0.06), 0.42, lift=SILL_Z + 0.06, yaw=s * 30.0, pitch=-10.0)
    _foot(sk, swing, inner, dx * 0.04, 0.48, lift=0.0, yaw=s * 18.0)
    H.look(swing, yaw=s * 22.0, pitch=16.0)
    frame_hand(swing)
    push_hand(swing, -dx * 0.06, -0.06)
    # 3 the door-side foot plants outside (foot_out)
    out = Pose()
    body(out, dx * 0.12, -0.04, VEH_HIP_Z + 0.02, s * 48.0, 10.0, 0.9)
    _foot(sk, out, door, dx * (SILL_X + 0.24), 0.30, yaw=s * 42.0)
    _foot(sk, out, inner, dx * 0.10, 0.44, lift=0.0, yaw=s * 30.0)
    H.look(out, yaw=s * 8.0, pitch=14.0)
    frame_hand(out)
    push_hand(out, -dx * 0.02, -0.08)
    # 4 push up off the seat and the frame, ducking the roof, the weight onto the outside foot; the inner foot lifts
    rise = Pose()
    body(rise, dx * 0.40, 0.06, 0.66, s * 44.0, 32.0, 0.35)
    _foot(sk, rise, door, dx * (SILL_X + 0.24), 0.30, yaw=s * 42.0)
    _foot(sk, rise, inner, dx * 0.30, 0.34, lift=SILL_Z + 0.10, yaw=s * 36.0, pitch=-12.0)
    H.look(rise, yaw=s * 6.0, pitch=4.0)
    # the door-side hand lets go of the frame and swings forward for balance
    A.arm_fk(sk, rise, door, add=26.0, swing=34.0, flex=40.0, twist=10.0)
    rise.hands[door] = hand_shape("relaxed", 1.0)
    push_hand(rise, dx * 0.10, -0.02)
    # 5 the inner foot lands on its final place (step_<inner>), the body comes up and starts to turn front
    land = Pose()
    body(land, dx * 0.62, 0.02, ez - 0.10, s * 24.0, 16.0, 0.0)
    _foot(sk, land, door, dx * (SILL_X + 0.24), 0.30, yaw=s * 42.0)
    end_leg(land, inner)
    H.look(land, yaw=-s * 10.0, pitch=4.0)
    for sfx, sx in A.SIDES:
        A.arm_fk(sk, land, sfx, add=32.0, swing=14.0, flex=50.0, twist=14.0)
        land.hands[sfx] = hand_shape("loose_fist", 0.8)
    # 6 the door-side foot lifts and steps clear
    lift = Pose()
    body(lift, dx * 0.76, 0.0, ez - 0.05, s * 10.0, 8.0, 0.0)
    end_leg(lift, inner)
    gd = end.legs[door]
    lift.legs[door] = LegIK(ankle=A.lerp(gd.ankle, v3(dx * (SILL_X + 0.24) * k, 0.30 * k, gd.ankle[2]), 0.45)
                            + v3(0.0, 0.0, 0.10 * k), foot=A.foot_rot(s * 16.0, -8.0) @ gd.foot, toe=0.0,
                            pole=gd.pole.copy())
    H.look(lift, yaw=-s * 4.0, pitch=2.0)
    for sfx, sx in A.SIDES:
        A.arm_fk(sk, lift, sfx, add=31.0, swing=14.0, flex=49.0, twist=14.0)
        lift.hands[sfx] = hand_shape("loose_fist", 0.8)
    # 7 the door-side foot plants (step_<door>), a small settle into idle_alert
    settle = end.copy()
    _shift(settle, v3(dx * 0.015 * k, 0.0, -0.02 * k))
    end_leg(settle, "L")
    end_leg(settle, "R")

    def post(f: int, pose: Pose) -> None:
        _shift(pose, v3(-dx * root_s(f) * k, 0.0, 0.0))
    return Keys(solver, [(0, start, "inout"), (6, look, "inout"), (f_out - 5, swing, "inout"), (f_out, out, "in"),
                         (f_out + 7, rise, "inout"), (f_in, land, "in"), (f_in + 5, lift, "inout"),
                         (f_door, settle, "in"), (N, end, "inout")], post=post)


# =============================================================================================
# sit_eat
# =============================================================================================
def _bump(t: float, T: float, at: float, rise: float, hold: float, fall: float) -> float:
    """0..1 cyclic pulse: up over ``rise`` s ending at ``at``, held ``hold`` s, down over ``fall`` s."""
    w = 0.0
    for sh in (-T, 0.0, T):
        x = t + sh
        w = max(w, smooth(at - rise, at, x) * (1.0 - smooth(at + hold, at + hold + fall, x)))
    return w


def _glass_lip_frame(sk: Skeleton, pre, tilt: float) -> tuple[np.ndarray, np.ndarray]:
    """The glass (hand_glass, origin at the base) at the lips, tipped ``tilt`` deg toward the face, its near rim on the
    lower lip."""
    k = sk.scale
    fwd = pre.W["head"] @ v3(0, 1, 0)
    yaw_h = math.degrees(math.atan2(-float(fwd[0]), float(fwd[1])))
    R = H.level_frame(yaw=yaw_h, pitch=tilt)
    lip = A.bone_point(pre, sk, "head", v3(0.0, 0.112 * k, -0.050 * k))
    rim = v3(0.0, -0.038 * k, 0.098 * k)
    return R, lip - R @ rim + v3(0.0, 0.004 * k, 0.0)


def sit_eat(sk: Skeleton, f: int, N: int) -> Pose:
    """At a diner booth table (sit_chair's seat SEAT_H, top TABLE_Z, near edge TABLE_EDGE ahead): leaning in over the
    plate, the right hand works a fork on the plate and carries it to the mouth (BITES, ``bite`` / ``bite_2`` at the
    lips), the left hand rests by the plate and once lifts the glass to the lips (SIP, ``sip``)."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    H.seated(sk, pose, seat_h=H.SEAT_H, recline=-8.0)
    bites = [_bump(t, T, b, 0.55, 0.25, 0.6) for b in BITES]
    bite = max(bites)
    s0, s1, s2, s3 = SIP
    sip_up = smooth(s0, s1, t) * (1.0 - smooth(s2, s3, t))
    sip = smooth(s1 - 0.1, s1 + 0.2, t) * (1.0 - smooth(s2 - 0.3, s2, t))
    add_rot(pose, "spine", rxd(-(4.0 + 3.0 * bite - 3.0 * sip_up)))
    add_rot(pose, "chest", rxd(-(3.0 + 3.0 * bite)))
    # the eyes on the plate, meeting the fork; a look up across the diner while drinking
    H.look(pose, yaw=3.0 * _cyc(t, T, 1, 0.7) - 6.0 * sip_up, pitch=30.0 - 18.0 * bite - 26.0 * sip_up + 6.0 * sip,
           tilt=2.0 * bite)
    H.breathe(pose, t, T / 4.0, 0.6)
    pre = Solver(sk).solve(pose)
    lips = A.bone_point(pre, sk, "head", v3(0.010 * k, 0.112 * k, -0.045 * k))
    # right: the fork pinched over the plate (pushing food: small strokes), up to the lips at each bite
    stroke = (1.0 - bite) * _cyc(t, T, round(1.1 * T))
    px, py = PLATE
    on_plate = (v3((px + 0.055) * k + 0.02 * k * stroke, (py - 0.05) * k - 0.015 * k * stroke, (TABLE_Z + 0.075) * k),
                unit(v3(-0.55, 0.75, -0.40)), unit(v3(-0.35, 0.15, -0.92)))
    at_mouth = (lips + v3(0.045 * k, 0.085 * k, -0.075 * k), unit(v3(-0.55, -0.35, 0.75)), unit(v3(-0.75, 0.55, -0.35)))
    p, al, pa = H.blend_hand([on_plate, at_mouth], [1.0 - bite, bite])
    hand_on(sk, pose, "R", p, al, pa, pole=v3(0.9, -0.4, -0.5), along_share=0.55, palm_off=0.02)
    pose.hands["R"] = hand_shape("pinch", 1.0)
    # left: resting on the table by the plate; the glass to the lips at the sip
    gx, gy = GLASS
    if sip_up > 1e-4:
        g = H.GRIPS["glass"]
        R0, o0 = H.level_frame(yaw=10.0), v3(gx * k, gy * k, TABLE_Z * k)
        R1, o1 = _glass_lip_frame(sk, pre, 26.0 + 14.0 * sip)
        R = A.mslerp(R0, R1, sip_up)
        o = A.lerp(o0, o1, sip_up) + v3(0.0, -0.04 * k, 0.03 * k) * math.sin(math.pi * sip_up)
        hold = (o + R @ (g["point"] * k), R @ unit(g["along"]), R @ unit(g["palm"]))
    rest = (v3(REST_L[0] * k, REST_L[1] * k, TABLE_Z * k), unit(v3(0.45, 0.88, -0.05)), v3(0.0, 0.0, -1.0))
    reach = smooth(s0 - 0.6, s0, t) * (1.0 - smooth(s3, s3 + 0.6, t))     # the hand goes to the glass and back
    if reach > 1e-4:
        g = H.GRIPS["glass"]
        R0, o0 = H.level_frame(yaw=10.0), v3(gx * k, gy * k, TABLE_Z * k)
        grasp = (o0 + R0 @ (g["point"] * k), R0 @ unit(g["along"]), R0 @ unit(g["palm"]))
        lhand = H.blend_hand([rest, grasp], [1.0 - reach, reach])
        if sip_up > 1e-4:
            lhand = H.blend_hand([lhand, hold], [1.0 - sip_up, sip_up])
        hand_on(sk, pose, "L", *lhand, pole=v3(-0.9, -0.4, -0.5), along_share=A.lerp(0.5, 0.55, reach),
                palm_off=A.lerp(0.012, 0.014, reach))
        pose.hands["L"] = hand_shape("rest_flat", 0.8).blend(hand_shape("grip", 0.55), reach)
    else:
        hand_on(sk, pose, "L", *rest, pole=v3(-0.9, -0.4, -0.5), along_share=0.5, palm_off=0.012)
        pose.hands["L"] = hand_shape("rest_flat", 0.8)
    return pose


# =============================================================================================
# cook_stove
# =============================================================================================
def cook_stove(sk: Skeleton, f: int, N: int) -> Pose:
    """At a griddle (top STOVE_Z, front edge STOVE_EDGE ahead): leaning in, the left hand on the stove's front rail,
    the right hand working a spatula over the griddle in scraping strokes, two flips (FLIPS, ``flip`` / ``flip_2``: the
    blade slides under, lifts and turns over), a stir between them, the occasional glance up (LOOK_UP_C)."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    look_up = _win(t, T, LOOK_UP_C[0], LOOK_UP_C[1], 0.35)
    sway = _cyc(t, T, 1, 0.5)
    pose.hip = v3(0.008 * k * sway, -0.04 * k, -0.025 * k)
    spine(pose, lean=11.0 - 3.0 * look_up, chest_lean=7.0 - 2.0 * look_up, twist=-3.0, hips=(4.0, 0.0, 0.0))
    add_rot(pose, "hips", ryd(1.2 * sway))
    for sfx, sx in A.SIDES:
        A.plant(sk, pose, sfx, v3(sx * 0.055 * k, (0.02 if sfx == "L" else -0.02) * k, 0.0), yaw=-sx * 10.0)
    flips = [_bump(t, T, fl, 0.22, 0.08, 0.30) for fl in FLIPS]
    flip = max(flips)
    turn = max(math.sin(math.pi * A.clamp01((t - fl + 0.05) / 0.45)) if fl - 0.05 <= t <= fl + 0.40 else 0.0
               for fl in FLIPS)
    H.look(pose, yaw=-4.0 + 2.0 * _cyc(t, T, 2, 0.3) + 18.0 * look_up, pitch=36.0 - 8.0 * flip - 38.0 * look_up,
           tilt=2.0 * look_up)
    H.breathe(pose, t, T / 3.0, 0.8)
    # right: the spatula blade on the griddle, scraping fore and aft; the flip lifts and rolls the blade; a stir
    work = (1.0 - flip) * (1.0 - 0.6 * look_up)
    scrape = _cyc(t, T, round(1.0 * T)) * work
    sx0, sy0 = SPATULA
    stir = _win(t, T, STIR[0], STIR[1], 0.3) * (1.0 - flip)
    sa = TAU * 2.0 * t
    circ = v3(0.035 * math.cos(sa), 0.03 * math.sin(sa), 0.0) * stir
    p = v3(sx0 * k, (sy0 + 0.04 * scrape) * k, (STOVE_Z + 0.10 + 0.07 * flip) * k) + circ * k
    roll = 150.0 * turn
    al = rzd(0.0) @ unit(v3(-0.20, 0.80, -0.55))
    pa = unit(v3(-0.95, 0.0, -0.25))
    R = A.rot(al, A.rad(-roll))
    hand_on(sk, pose, "R", p, al, R @ pa, pole=v3(0.9, -0.5, -0.4), along_share=0.5, palm_off=0.025)
    pose.hands["R"] = hand_shape("grip", 0.95)
    # left: the palm on the stove's front rail
    hand_on(sk, pose, "L", v3(RAIL_L[0] * k, RAIL_L[1] * k, STOVE_Z * k), unit(v3(0.5, 0.86, -0.05)), v3(0.0, 0.0, -1.0),
            pole=v3(-0.9, -0.3, -0.5), along_share=0.5, palm_off=0.012)
    pose.hands["L"] = hand_shape("rest_flat", 0.8)
    import _anim_bank as bank  # noqa: PLC0415

    bank._settle(sk, pose, STOVE_Z, STOVE_EDGE, ("L",))
    return pose


# =============================================================================================
# table hook
# =============================================================================================
BUILDERS = {"sit_vehicle": sit_vehicle, "sit_eat": sit_eat, "cook_stove": cook_stove}


def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N, loop, speed, ev = int(row["frames"]), bool(row["loop"]), float(row["speed"]), dict(row.get("events", {}))
        if name in EXITS:
            side = "L" if name.endswith("_l") else "R"
            out[name] = Clip(name, N, loop, vehicle_exit(sk, solver, N, side, ev), speed, None, ev, reach_fix=False)
            continue
        fn = BUILDERS[name]
        out[name] = Clip(name, N, loop, (lambda f, fn=fn, N=N: fn(sk, f, N)), speed, None, ev, reach_fix=True)
    return out


# =============================================================================================
# checks and SOURCE.txt notes
# =============================================================================================
def _lowest(sk: Skeleton, frames: list) -> float:
    pr = A.probe_for(sk)
    return min(float(pr.posed(s)[:, 2].min()) for s in frames)


def check_row(sk: Skeleton, table: dict, name: str, baked, keep: dict) -> str:
    from _anim_d304 import pose_err  # noqa: PLC0415

    fr = baked.frames
    txt = f" lowest_skin={_lowest(sk, fr[::3]) * 1000:.1f}mm"
    if name in EXITS:
        if "sit_vehicle" in keep:
            txt += f" start_err={pose_err(fr[0], keep['sit_vehicle'].frames[0]):.2f}mm"
        if "idle_alert" in keep:
            txt += f" end_err={pose_err(fr[-1], keep['idle_alert'].frames[0]):.2f}mm"
    else:
        root = [float(np.linalg.norm(s.P["root"] - fr[0].P["root"])) for s in fr] if "root" in fr[0].P else [0.0]
        txt += f" root_drift={max(root) * 1000:.2f}mm"
    if name == "sit_vehicle":
        txt += f" hips_z={float(fr[0].P['hips'][2]):.3f}m"
    return txt


def source_notes(sk: Skeleton, table: dict, keep: dict) -> dict[str, str]:
    k = sk.scale
    out: dict[str, str] = {}
    for name in EXITS:
        if name not in table:
            continue
        N = int(table[name]["frames"])
        curve = [root_s(float(f)) * k for f in range(N + 1)]
        gx = -1 if name.endswith("_l") else 1
        out[f"curve.{name}"] = (f"root_m={','.join(f'{x:.4f}' for x in curve)} total_m={curve[-1]:.3f} "
                                f"dir_godot=({gx},0,0)")
    sv = keep.get("sit_vehicle")
    reach = 0.0
    if sv is not None:
        pr = A.probe_for(sk)
        V = pr.posed(sv.frames[0])
        reach = float(V[:, 1].max())
    ev_l = table.get("vehicle_exit_l", {}).get("events", {})
    out["rt_vehicle_placement"] = (
        f"RT-D1 sit_vehicle: a car / armoured-cab bucket seat. The root on the FOOTWELL FLOOR under the seat centre, "
        f"facing the vehicle's forward (-Z); the cushion top {VEH_SEAT_Z:.2f} m above it (hips joint {VEH_HIP_Z:.2f} m), "
        f"the feet {0.52 * k:.2f} m ahead (the body reaches {reach:.2f} m ahead of the root: the pedals / dash clear of "
        f"that), the head ~1.0-1.05 m up (roof liner >= 1.15 m above the footwell). Loop, in place. "
        f"vehicle_exit_l / vehicle_exit_r: frame 0 IS sit_vehicle frame 0, the last frame IS idle_alert frame 0 (no "
        f"crossfades). The body leaves through the door on the character's left (_l, Godot -X) / right (_r, +X): "
        f"A moves the root along curve.vehicle_exit_<side> (total {EXIT_X * k:.2f} m sideways, no turn: the clip ends "
        f"facing the vehicle's forward again, standing beside it). The door must be open with the opening from about "
        f"0.30 m behind to 0.65 m ahead of the seat centre, the sill line {SILL_X:.2f} m beside the seat centre and at "
        f"most {SILL_Z:.2f} m above the footwell, the door frame top >= 1.15 m; the door-side hand takes the door "
        f"frame at ({-FRAME_GRIP[0]:.2f}|{FRAME_GRIP[0]:.2f}, {FRAME_GRIP[2]:.2f}, {-FRAME_GRIP[1]:.2f}) seat space "
        f"(Godot x, y, z; - for _l). The footwell floor is assumed level with the ground outside (no step down; for a "
        f"high armoured cab, play it with the root on the cab floor and drop it to the road after, or use van_exit). "
        f"Keep {EXIT_X + 0.25:.2f} m beside the seat centre clear of other vehicles / walls (the open door swings ahead "
        f"of the standing spot). Events (_l; _r mirrors L/R): foot_out@{ev_l.get('foot_out', '?')} the door-side foot "
        f"on the ground, step_r@{ev_l.get('step_r', '?')} the inner foot, step_l@{ev_l.get('step_l', '?')} the door-side "
        f"foot steps clear. Planted feet are world-still at that root motion. Occupants of the soft escort cars sit in "
        f"sit_vehicle (visible through the glass); police / convoy crew dismount with vehicle_exit_*.")
    return out
