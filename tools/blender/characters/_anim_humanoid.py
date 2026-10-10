"""The ``humanoid`` animation library (docs/contracts/characters.md v1.1) as procedural clips.

Private helper for ``anim_humanoid.py`` (D1-03). Pure numpy: ``clips(sk)`` returns ``{name: Clip}``
for every name in ``anim_humanoid.CLIPS`` (frames, loop flag and locomotion speed come from that
table, so the table is the single source of truth). Each clip is a function of the frame number
that returns a ``_anim.Pose``; locomotion uses ``_anim.Gait`` (zero foot sliding at the recorded
speed), one-shots use ``_anim.Keys`` (key poses + eases + procedural layers).

Conventions used below (see ``_anim``): degrees everywhere, the character faces +Y, root at the
feet and never moving (in place). Weapons are placed as frames (``weapon_frame``) and the right
hand is solved so that the weapon origin sits at the ``grip_offset`` of ``hand.R`` (the HandR
attachment convention); the support hand goes to the weapon's ``LeftHandIK`` marker.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
from _anim import (FPS, TAU, Clip, Gait, Keys, Pose, Skeleton, Solver, add_rot, arm_fk, cos_ease, hand_on,
                   hand_shape, hold_weapon, leg_fk, neutral, periodic, plant, pulse, rxd, ryd, rzd, smooth, spine,
                   spring, stand, unit, v3, weapon_frame, wf_point)

# Weapon marker positions (Blender weapon space, metres), read from the trunk models
# game/assets/weapons/wpn_kestrel_p9 and wpn_corsair_ar (B1-03 / B4-04).
PISTOL = {"left_ik": v3(-0.025, 0.0115, -0.020), "aim": v3(0.0, -0.030, 0.0665), "magwell": v3(0.0, -0.0227, -0.070),
          "muzzle": v3(0.0, 0.1425, 0.048)}
RIFLE = {"left_ik": v3(-0.0315, 0.330, 0.067), "aim": v3(0.0, -0.060, 0.1212), "magwell": v3(0.0, 0.1235, -0.012),
         "butt": v3(0.0, -0.307, 0.040), "muzzle": v3(0.0, 0.612, 0.080)}


# =============================================================================================
# shared layers
# =============================================================================================
def breathe(pose: Pose, t: float, period: float, amount: float = 1.0) -> None:
    """Chest rise/fall (+ a little shoulder lift) for ``t`` seconds at ``period`` s per breath."""
    b = math.sin(TAU * t / period)
    add_rot(pose, "chest", rxd(1.1 * amount * b))
    add_rot(pose, "neck", rxd(-0.6 * amount * b))
    for sfx, sx in A.SIDES:
        c = f"clavicle.{sfx}"
        if c in pose.D:
            pose.D[c] = pose.D[c] @ ryd(-sx * 0.8 * amount * b)


def look(pose: Pose, yaw: float = 0.0, pitch: float = 0.0, tilt: float = 0.0, neck_share: float = 0.35) -> None:
    """Turn the head: yaw (+ left), pitch (+ down), tilt (+ right ear down); split neck/head."""
    add_rot(pose, "neck", rzd(yaw * neck_share) @ rxd(-pitch * neck_share))
    add_rot(pose, "head", rzd(yaw * (1 - neck_share)) @ ryd(tilt) @ rxd(-pitch * (1 - neck_share)))


def shift(sk: Skeleton, pose: Pose, t: float, period: float, amount: float = 0.012) -> None:
    """Slow weight shift between the feet (hips sway, pelvis roll, spine compensates)."""
    s = math.sin(TAU * t / period)
    pose.hip = pose.hip + v3(amount * sk.scale * s, 0.0, -0.004 * sk.scale * abs(s))
    add_rot(pose, "hips", ryd(1.4 * s))
    add_rot(pose, "spine", ryd(-1.0 * s))
    add_rot(pose, "chest", ryd(-0.5 * s))


def tremble(pose: Pose, t: float, amount: float = 1.0) -> None:
    """Fear tremor: small, fast, non-repeating-looking (sum of incommensurate-ish sines)."""
    a = amount
    add_rot(pose, "chest", rxd(0.5 * a * math.sin(TAU * 7.0 * t)) @ ryd(0.35 * a * math.sin(TAU * 5.0 * t + 1.0)))
    add_rot(pose, "head", rzd(0.8 * a * math.sin(TAU * 6.0 * t + 0.4)))


# =============================================================================================
# weapon holds
# =============================================================================================
def pistol_aim_frame(sk: Skeleton, t: float = 0.0, sway: float = 1.0) -> tuple[np.ndarray, np.ndarray]:
    k = sk.scale
    sw = sway
    o = v3(0.035 * k + 0.003 * k * sw * math.sin(TAU * t / 3.0), 0.47 * k,
           1.475 * k + 0.004 * k * sw * math.sin(TAU * t / 1.5))
    return weapon_frame(o, yaw=0.6 * sw * math.sin(TAU * t / 3.0 + 0.7), pitch=0.5 * sw * math.sin(TAU * t / 1.5 + 1.2))


def rifle_aim_frame(sk: Skeleton, t: float = 0.0, sway: float = 1.0) -> tuple[np.ndarray, np.ndarray]:
    k = sk.scale
    sw = sway
    o = v3(0.115 * k + 0.002 * k * sw * math.sin(TAU * t / 3.0), 0.255 * k,
           1.395 * k + 0.003 * k * sw * math.sin(TAU * t / 1.5))
    return weapon_frame(o, yaw=0.4 * sw * math.sin(TAU * t / 3.0 + 0.7), pitch=0.35 * sw * math.sin(TAU * t / 1.5 + 1.2))


def pistol_support(sk: Skeleton, pose: Pose, wf, pole=None) -> None:
    R = wf[0]
    hand_on(sk, pose, "L", wf_point(wf, PISTOL["left_ik"]), R @ v3(0.55, 0.45, -0.70), R @ v3(0.85, 0.05, 0.25),
            pole=pole if pole is not None else v3(-0.55, -0.25, -0.8), along_share=0.45, palm_off=0.016)
    pose.hands["L"] = hand_shape("support")


def rifle_support(sk: Skeleton, pose: Pose, wf, pole=None, at=None) -> None:
    R = wf[0]
    p = wf_point(wf, RIFLE["left_ik"] if at is None else at)
    hand_on(sk, pose, "L", p, R @ v3(0.55, 0.65, 0.35), R @ v3(0.55, -0.1, 0.83),
            pole=pole if pole is not None else v3(-0.35, -0.3, -0.9), along_share=0.55, palm_off=0.016)
    pose.hands["L"] = hand_shape("grip", 0.85)


def aim_body(sk: Skeleton, pose: Pose, rifle: bool) -> None:
    k = sk.scale
    if rifle:
        pose.hip = v3(-0.01 * k, -0.02 * k, -0.035 * k)
        stand(sk, pose, spread=0.04, stagger_l=0.10, stagger_r=-0.10, yaw_l=8, yaw_r=28)
        spine(pose, lean=4, twist=-12, chest_lean=5, chest_twist=-10, chest_side=-2, neck=(4, 0, 6),
              head=(8, 8, 8), hips=(2, 0, -6))
    else:
        pose.hip = v3(0.0, -0.01 * k, -0.03 * k)
        stand(sk, pose, spread=0.035, stagger_l=0.06, stagger_r=-0.05, yaw_l=8, yaw_r=14)
        spine(pose, lean=4, twist=-3, chest_lean=4, neck=(2, 0, 2), head=(5, 2, 1), hips=(1, 0, -3))


def hold_pistol(sk: Skeleton, pose: Pose, wf, one_hand: bool = False) -> None:
    hold_weapon(sk, pose, wf, pole=v3(0.55, -0.15, -0.8), twist=0.6)
    pose.hands["R"] = hand_shape("trigger")
    if not one_hand:
        pistol_support(sk, pose, wf)


def hold_rifle(sk: Skeleton, pose: Pose, wf) -> None:
    hold_weapon(sk, pose, wf, pole=v3(0.75, -0.2, -0.6), twist=0.6)
    pose.hands["R"] = hand_shape("trigger")
    rifle_support(sk, pose, wf)


def gun_pose(sk: Skeleton, rifle: bool, t: float = 0.0, sway: float = 1.0, recoil: float = 0.0) -> Pose:
    """Aiming stance with the weapon at the sight line; ``recoil`` 0..1 kicks it back and up."""
    pose = Pose()
    aim_body(sk, pose, rifle)
    k = sk.scale
    R, o = (rifle_aim_frame if rifle else pistol_aim_frame)(sk, t, sway)
    if rifle:
        o = o + R @ v3(0.0, -0.022 * k * recoil, 0.004 * k * recoil)
        R = R @ rxd(3.5 * recoil)
        add_rot(pose, "chest", rxd(1.6 * recoil))
        hold_rifle(sk, pose, (R, o))
    else:
        o = o + R @ v3(0.0, -0.03 * k * recoil, 0.012 * k * recoil)
        R = R @ rxd(9.0 * recoil)
        add_rot(pose, "chest", rxd(1.0 * recoil))
        hold_pistol(sk, pose, (R, o))
    breathe(pose, t, 3.0 / 2.0 if t else 1.5, 0.6 * sway)
    return pose


# =============================================================================================
# stationary loops
# =============================================================================================
def idle(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    pose = neutral(sk)
    shift(sk, pose, t, T, 0.012)
    breathe(pose, t, T / 3.0)
    look(pose, yaw=4.0 * math.sin(TAU * t / T + 0.6), pitch=1.0 + 0.8 * math.sin(TAU * 2 * t / T))
    for sfx, sx in A.SIDES:
        arm_fk(sk, pose, sfx, add=38.0 - 0.8 * sx * math.sin(TAU * t / T), swing=1.5, flex=13.0, twist=8.0)
        pose.hands[sfx] = hand_shape("relaxed")
    breathe(pose, t, T / 3.0, 0.5)
    return pose


def idle_alert(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = neutral(sk)
    pose.hip = v3(0.0, -0.01 * k, -0.04 * k)
    stand(sk, pose, spread=0.045, stagger_l=0.07, stagger_r=-0.05, yaw_l=7, yaw_r=12)
    scan = math.sin(TAU * t / T)
    spine(pose, lean=6.0, chest_lean=2.0, twist=3.0 * scan, chest_twist=5.0 * scan, hips=(1, 0, 0))
    look(pose, yaw=26.0 * scan, pitch=1.0 + 2.0 * math.sin(TAU * 2 * t / T))
    for sfx, sx in A.SIDES:
        arm_fk(sk, pose, sfx, add=30.0, swing=14.0, flex=48.0 + 4.0 * math.sin(TAU * 2 * t / T), twist=14.0)
        pose.hands[sfx] = hand_shape("loose_fist", 0.8)
    breathe(pose, t, T / 4.0, 1.1)
    return pose


def crouch_base(sk: Skeleton, pose: Pose) -> None:
    k = sk.scale
    pose.hip = v3(0.0, -0.10 * k, -0.37 * k)
    stand(sk, pose, spread=0.05, stagger_l=0.07, stagger_r=-0.12, yaw_l=10, yaw_r=16)
    plant(sk, pose, "R", (0.05 * k, -0.12 * k, 0.0), yaw=-16.0, pitch=-24.0, toe=24.0, pivot="ball")
    spine(pose, lean=14.0, chest_lean=12.0, neck=(-14, 0, 0), head=(-10, 0, 0), hips=(14, 0, 0))


def crouch_idle(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    pose = Pose()
    crouch_base(sk, pose)
    pose.hip = pose.hip + v3(0.006 * sk.scale * math.sin(TAU * t / T), 0.0, 0.0)
    look(pose, yaw=10.0 * math.sin(TAU * t / T + 0.3), pitch=-2.0)
    for sfx, sx in A.SIDES:
        arm_fk(sk, pose, sfx, add=26.0, swing=30.0, flex=55.0, twist=18.0, clav_fwd=6.0)
        pose.hands[sfx] = hand_shape("relaxed", 1.3)
    breathe(pose, t, T / 3.0, 1.0)
    return pose


def aim_pistol(sk: Skeleton, f: int, N: int) -> Pose:
    return gun_pose(sk, False, f / FPS)


def aim_rifle(sk: Skeleton, f: int, N: int) -> Pose:
    return gun_pose(sk, True, f / FPS)


def cower(sk: Skeleton, f: int, N: int) -> Pose:
    """Crouched low, hunched, forearms over the head, trembling."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    pose.hip = v3(0.0, -0.14 * k, -0.50 * k)
    stand(sk, pose, spread=0.03, stagger_l=0.02, stagger_r=-0.03, yaw_l=10, yaw_r=10)
    for sfx in ("L", "R"):
        plant(sk, pose, sfx, (A.side_x(sfx) * 0.03 * k, -0.03 * k, 0.0), yaw=-A.side_x(sfx) * 10.0, pitch=-30.0,
              toe=30.0, pivot="ball", pole=v3(A.side_x(sfx) * 0.35, 1.0, 0.0))
    rock = math.sin(TAU * t / T)
    spine(pose, lean=30.0 + 2.0 * rock, chest_lean=26.0, neck=(18, 0, 0), head=(16, 0, 4.0 * math.sin(TAU * 2 * t / T)),
          hips=(30, 0, 0))
    tremble(pose, t, 1.2)
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        # forearms crossed over the crown, palms down, elbows forward-out
        p = A.bone_point(pre, sk, "head", v3(-sx * 0.035 * k, 0.03 * k, 0.17 * k))
        hand_on(sk, pose, sfx, p, pre.W["head"] @ v3(-sx * 0.75, -0.45, -0.1), pre.W["head"] @ v3(0.0, 0.1, -1.0),
                pole=pre.W["chest"] @ v3(sx * 0.6, 0.8, -0.2), along_share=0.4)
        pose.hands[sfx] = hand_shape("claw", 0.6)
    return pose


def hands_up(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = neutral(sk)
    stand(sk, pose, spread=0.02, yaw_l=7, yaw_r=7)
    pose.hip = v3(0.006 * k * math.sin(TAU * t / T), -0.01 * k, -0.018 * k)
    spine(pose, lean=-1.0, chest_lean=-1.5, neck=(3, 0, 0), head=(5, 0, 0))
    look(pose, yaw=8.0 * math.sin(TAU * t / T + 0.5), pitch=-1.0)
    tremble(pose, t, 0.5)
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        jit = 0.006 * k * math.sin(TAU * 2 * t / T + sx)
        p = A.bone_point(pre, sk, "chest", v3(sx * 0.30 * k, 0.07 * k, 0.40 * k + jit))
        hand_on(sk, pose, sfx, p, pre.W["chest"] @ v3(sx * 0.12, 0.08, 1.0), pre.W["chest"] @ v3(0.0, 1.0, 0.0),
                pole=pre.W["chest"] @ v3(sx * 1.0, -0.15, -0.55), along_share=0.45, clav=0.6)
        pose.hands[sfx] = hand_shape("spread", 0.8)
    breathe(pose, t, T / 4.0, 1.4)
    return pose


def lie_down(sk: Skeleton, f: int, N: int) -> Pose:
    """Prone on the floor, hands on the back of the head (PD2 civilian 'get down')."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    br = math.sin(TAU * 3 * t / T)
    hips_rest = sk.head["hips"]
    pose.hip = v3(0.0, 0.80 * k, 0.125 * k - hips_rest[2] + 0.0025 * k * br)
    spine(pose, hips=(90.0, 0, 0), lean=-4.0, chest_lean=-5.0 - 0.8 * br, neck=(-22, 0, 0), head=(-16, 0, -35))
    for sfx, sx in A.SIDES:
        ank = v3(sx * 0.15 * k, 0.80 * k - 0.86 * k, 0.075 * k)
        pose.legs[sfx] = A.LegIK(ankle=ank, foot=rxd(-150.0) @ rzd(-sx * 10.0), toe=A.rad(30.0), pole=v3(sx * 0.2, 0.0, -1.0))
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        p = A.bone_point(pre, sk, "head", pre.W["head"] @ v3(sx * 0.02 * k, -0.115 * k, 0.11 * k) - pre.W["head"] @ v3(0, 0, 0))
        p = pre.P["head"] + pre.W["head"] @ v3(sx * 0.03 * k, -0.105 * k, 0.11 * k)
        hand_on(sk, pose, sfx, p, pre.W["head"] @ v3(-sx * 0.85, 0.0, 0.5), pre.W["head"] @ v3(0.0, 1.0, 0.0),
                pole=v3(sx * 1.0, 0.0, 0.25), along_share=0.45, clav=0.5)
        pose.hands[sfx] = hand_shape("relaxed", 0.6)
    return pose


def kneel_base(sk: Skeleton, pose: Pose, sit: float = 1.0) -> None:
    """Kneeling on both knees, sitting back towards the heels (``sit`` 0..1)."""
    k = sk.scale
    hips_rest = sk.head["hips"]
    pose.hip = v3(0.0, -0.05 * k, (0.60 - 0.12 * sit) * k - hips_rest[2])
    for sfx, sx in A.SIDES:
        ank = v3(sx * 0.12 * k, -0.40 * k, 0.085 * k)
        pose.legs[sfx] = A.LegIK(ankle=ank, foot=rxd(-120.0) @ rzd(-sx * 8.0), toe=A.rad(25.0), pole=v3(sx * 0.15, 1.0, -0.6))


def tied(sk: Skeleton, f: int, N: int) -> Pose:
    """Kneeling, sitting on the heels, wrists tied behind the back, head down."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    kneel_base(sk, pose, sit=1.0)
    rock = math.sin(TAU * t / T)
    spine(pose, lean=10.0 + 2.0 * rock, chest_lean=8.0, neck=(12, 0, 0), head=(14 + 3 * rock, 0, 6 * math.sin(TAU * 2 * t / T)),
          hips=(6, 0, 0))
    breathe(pose, t, T / 4.0, 1.2)
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        p = A.bone_point(pre, sk, "hips", v3(sx * 0.035 * k, -0.17 * k, 0.03 * k))
        hand_on(sk, pose, sfx, p, pre.W["hips"] @ v3(-sx * 0.7, -0.25, -0.6), pre.W["hips"] @ v3(-sx * 0.3, -0.9, 0.2),
                pole=pre.W["hips"] @ v3(sx * 0.6, -0.8, 0.0), along_share=0.3, clav=0.2)
        pose.hands[sfx] = hand_shape("relaxed", 1.4)
    return pose


def kneel_cuffed(sk: Skeleton, f: int, N: int) -> Pose:
    """Kneeling upright (hips off the heels), hands cuffed behind the back, looking around."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    kneel_base(sk, pose, sit=0.0)
    spine(pose, lean=2.0, chest_lean=-2.0, neck=(4, 0, 0), head=(6, 0, 0))
    look(pose, yaw=18.0 * math.sin(TAU * t / T), pitch=2.0)
    breathe(pose, t, T / 3.0, 1.0)
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        p = A.bone_point(pre, sk, "hips", v3(sx * 0.03 * k, -0.16 * k, 0.0))
        hand_on(sk, pose, sfx, p, pre.W["hips"] @ v3(-sx * 0.7, -0.2, -0.65), pre.W["hips"] @ v3(-sx * 0.3, -0.9, 0.2),
                pole=pre.W["hips"] @ v3(sx * 0.6, -0.8, 0.0), along_share=0.3, clav=0.2)
        pose.hands[sfx] = hand_shape("fist", 0.7)
    return pose


def phone_call(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = idle(sk, f, N)
    look(pose, yaw=-6.0, pitch=4.0 + 3.0 * math.sin(TAU * 3 * t / T), tilt=8.0)
    pre = Solver(sk).solve(pose)
    p = pre.P["head"] + pre.W["head"] @ v3(0.085 * k, 0.03 * k, 0.07 * k)
    hand_on(sk, pose, "R", p, pre.W["head"] @ v3(-0.15, 0.25, 0.95), pre.W["head"] @ v3(-1.0, 0.1, 0.0),
            pole=v3(0.6, -0.1, -1.0), along_share=0.6, palm_off=0.02)
    pose.hands["R"] = hand_shape("phone")
    gest = smooth(0.0, 1.0, 0.5 + 0.5 * math.sin(TAU * 2 * t / T))
    arm_fk(sk, pose, "L", add=34.0, swing=8.0 + 26.0 * gest, flex=30.0 + 55.0 * gest, twist=30.0 * gest)
    pose.hands["L"] = hand_shape("relaxed", 1.0 - 0.6 * gest)
    return pose


def pager_answer(sk: Skeleton, f: int, N: int) -> Pose:
    """Crew answering a guard's pager: device held to the mouth with the left hand, head down."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = neutral(sk)
    stand(sk, pose, spread=0.03, stagger_l=0.04, yaw_l=8, yaw_r=10)
    pose.hip = v3(0.004 * k * math.sin(TAU * t / T), 0.0, -0.025 * k)
    spine(pose, lean=5.0, chest_lean=3.0, neck=(10, 0, 4), head=(10, 0, 4))
    talk = math.sin(TAU * 4 * t / T)
    look(pose, pitch=2.0 * talk, yaw=2.0 * math.sin(TAU * t / T))
    pre = Solver(sk).solve(pose)
    p = pre.P["head"] + pre.W["head"] @ v3(-0.025 * k, 0.15 * k, 0.03 * k)
    hand_on(sk, pose, "L", p, pre.W["head"] @ v3(0.35, 0.2, 0.9), pre.W["head"] @ v3(0.25, -0.95, 0.1),
            pole=v3(-0.7, -0.1, -0.9), along_share=0.6, palm_off=0.025)
    pose.hands["L"] = hand_shape("pinch")
    arm_fk(sk, pose, "R", add=36.0, swing=6.0, flex=20.0, twist=10.0)
    pose.hands["R"] = hand_shape("relaxed")
    breathe(pose, t, T / 3.0, 0.8)
    return pose


def investigate_look(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = neutral(sk)
    side = math.sin(TAU * t / T)
    peer = smooth(0.0, 1.0, 0.5 + 0.5 * math.sin(TAU * 2 * t / T - 1.2))
    pose.hip = v3(0.01 * k * side, 0.005 * k * peer, -0.03 * k)
    stand(sk, pose, spread=0.03, stagger_l=0.06, stagger_r=-0.03, yaw_l=6, yaw_r=8)
    spine(pose, lean=4 + 6 * peer, twist=7 * side, chest_twist=12 * side, chest_lean=2 + 4 * peer)
    look(pose, yaw=26.0 * side, pitch=6 * peer, tilt=3 * side)
    arm_fk(sk, pose, "R", add=34.0, swing=8.0, flex=35.0, twist=14.0)
    arm_fk(sk, pose, "L", add=33.0, swing=10.0 + 8 * peer, flex=30.0 + 10 * peer, twist=10.0)
    for sfx in ("L", "R"):
        pose.hands[sfx] = hand_shape("relaxed")
    breathe(pose, t, T / 4.0)
    return pose


def downed(sk: Skeleton, f: int, N: int) -> Pose:
    """Bleed-out: sitting on the floor, leaning back on the left hand, pistol up in the right."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    br = math.sin(TAU * 3 * t / T)
    hips_rest = sk.head["hips"]
    pose.hip = v3(0.0, -0.05 * k, 0.14 * k - hips_rest[2] + 0.003 * k * br)
    spine(pose, hips=(-44, 0, 0), lean=8.0, chest_lean=6.0 + 1.5 * br, neck=(18, 0, 0), head=(6, 0, 2.0 * math.sin(TAU * t / T)))
    pose.legs["L"] = A.LegIK(ankle=v3(-0.20 * k, 0.70 * k, 0.07 * k), foot=rxd(18.0) @ rzd(14.0), toe=0.0, pole=v3(-0.5, 0.3, 1.0))
    pose.legs["R"] = A.LegIK(ankle=v3(0.13 * k, 0.48 * k, 0.085 * k), foot=rzd(-10.0), toe=0.0, pole=v3(0.3, 0.6, 1.0))
    pre = Solver(sk).solve(pose)
    pl = pre.P["upper_arm.L"] + v3(-0.10 * k, -0.16 * k, 0.0)
    pl[2] = 0.012 * k
    hand_on(sk, pose, "L", pl, v3(-0.35, -0.55, -0.1), v3(0.0, 0.0, -1.0),
            pole=v3(-0.6, -0.8, 0.0), along_share=0.55, palm_off=0.012, clav=0.5)
    pose.hands["L"] = hand_shape("flat", 0.5)
    o = A.bone_point(pre, sk, "chest", v3(0.07 * k, 0.40 * k, 0.12 * k)) + v3(0.0, 0.0, 0.004 * k * br)
    wf = weapon_frame(o, yaw=4.0 * math.sin(TAU * t / T), pitch=-2.0 + 1.5 * br)
    hold_pistol(sk, pose, wf, one_hand=True)
    return pose


def interact(level: str):
    def fn(sk: Skeleton, f: int, N: int) -> Pose:
        t = f / FPS
        T = N / FPS
        k = sk.scale
        pose = neutral(sk)
        if level == "low":
            pose.hip = v3(0.0, -0.06 * k, -0.47 * k)
            stand(sk, pose, spread=0.06, stagger_l=0.14, stagger_r=-0.16, yaw_l=8, yaw_r=16)
            plant(sk, pose, "R", (0.06 * k, -0.18 * k, 0.0), yaw=-16.0, pitch=-40.0, toe=40.0, pivot="ball")
            spine(pose, lean=26, chest_lean=16, neck=(4, 0, 0), head=(16, 0, 0), hips=(18, 0, 0))
            zc, yc, along, palm = 0.40, 0.40, v3(0.0, 0.85, -0.5), v3(0.0, 0.3, -1.0)
        elif level == "mid":
            pose.hip = v3(0.0, -0.01 * k, -0.035 * k)
            stand(sk, pose, spread=0.03, stagger_l=0.06, stagger_r=-0.04, yaw_l=8, yaw_r=10)
            spine(pose, lean=10, chest_lean=8, neck=(8, 0, 0), head=(16, 0, 0), hips=(2, 0, 0))
            zc, yc, along, palm = 1.02, 0.40, v3(0.0, 1.0, -0.25), v3(0.0, 0.5, -1.0)
        else:
            pose.hip = v3(0.0, 0.02 * k, -0.005 * k)
            stand(sk, pose, spread=0.02, stagger_l=0.07, stagger_r=-0.03, yaw_l=6, yaw_r=8)
            spine(pose, lean=-4, chest_lean=-6, neck=(-14, 0, 0), head=(-18, 0, 0))
            zc, yc, along, palm = 1.78, 0.30, v3(0.0, 0.4, 1.0), v3(0.0, 1.0, 0.0)
        look(pose, yaw=3.0 * math.sin(TAU * t / T))
        for sfx, sx in A.SIDES:
            ph = 0.0 if sfx == "R" else 0.37
            w = math.sin(TAU * (2 * t / T + ph))
            w2 = math.sin(TAU * (3 * t / T + ph * 2))
            p = v3(sx * 0.085 * k + 0.012 * k * w2, yc * k + 0.015 * k * w, zc * k + 0.012 * k * w2)
            hand_on(sk, pose, sfx, p, unit(along + v3(-sx * 0.35, 0.0, 0.0)), unit(palm + v3(-sx * 0.25, 0.0, 0.0)),
                    pole=v3(sx * 0.9, -0.3, -0.5), along_share=0.6)
            pose.hands[sfx] = hand_shape("pinch" if sfx == "R" else "grip", 0.8 + 0.2 * w)
        breathe(pose, t, T / 2.0, 0.8)
        return pose
    return fn


def browse(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = neutral(sk)
    s = math.sin(TAU * t / T)
    look_ph = math.sin(TAU * 2 * t / T + 0.5)
    pose.hip = v3(0.014 * k * s, -0.01 * k, -0.02 * k)
    stand(sk, pose, spread=0.02, stagger_l=0.04, stagger_r=-0.02, yaw_l=8, yaw_r=5)
    spine(pose, lean=8, chest_lean=6, side=-1.2 * s, hips=(0, 1.2 * s, 0))
    look(pose, yaw=12.0 * look_ph, pitch=14.0, tilt=2.0 * look_ph)
    pre = Solver(sk).solve(pose)
    p = A.bone_point(pre, sk, "chest", v3(-0.12 * k, 0.30 * k, -0.20 * k))
    hand_on(sk, pose, "L", p, v3(0.35, 0.85, 0.1), v3(0.1, 0.0, 1.0), pole=v3(-0.7, -0.3, -0.7), along_share=0.6)
    pose.hands["L"] = hand_shape("relaxed", 0.8)
    point = smooth(0.0, 1.0, 0.5 + 0.5 * math.sin(TAU * 2 * t / T - 1.0))
    arm_fk(sk, pose, "R", add=32.0, swing=12.0 + 30.0 * point, flex=30.0 + 50.0 * point, twist=10 + 20 * point)
    pose.hands["R"] = hand_shape("pinch", 0.6 + 0.4 * point)
    breathe(pose, t, T / 3.0)
    return pose


def seated(sk: Skeleton, pose: Pose, seat_h: float = 0.47, recline: float = 0.0) -> None:
    """Sitting on a chair seat at ``seat_h`` (m), thighs horizontal, feet flat."""
    k = sk.scale
    hips_rest = sk.head["hips"]
    pose.hip = v3(0.0, -0.08 * k, (seat_h + 0.07) * k - hips_rest[2])
    spine(pose, hips=(-86.0 + recline, 0, 0), lean=80.0 - recline * 0.6, chest_lean=4.0)
    for sfx, sx in A.SIDES:
        plant(sk, pose, sfx, (sx * 0.05 * k, 0.40 * k, 0.0), yaw=-sx * 8.0, pole=v3(sx * 0.15, 0.4, 1.0))


def sit_chair(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    seated(sk, pose, recline=8.0)
    look(pose, yaw=10.0 * math.sin(TAU * t / T), pitch=2.0)
    breathe(pose, t, T / 4.0)
    for sfx, sx in A.SIDES:
        p = v3(sx * 0.15 * k, 0.26 * k, 0.60 * k + 0.003 * k * math.sin(TAU * 4 * t / T))
        hand_on(sk, pose, sfx, p, v3(-sx * 0.2, 0.95, -0.2), v3(-sx * 0.15, 0.0, -1.0), pole=v3(sx * 0.9, -0.5, -0.3),
                along_share=0.5)
        pose.hands[sfx] = hand_shape("relaxed")
    return pose


def desk_type(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    seated(sk, pose, recline=-6.0)
    look(pose, yaw=4.0 * math.sin(TAU * t / T), pitch=12.0)
    breathe(pose, t, T / 2.0, 0.7)
    for sfx, sx in A.SIDES:
        ph = 0.0 if sfx == "R" else 0.31
        tap = max(0.0, math.sin(TAU * (8 * t / T + ph)))
        drift = math.sin(TAU * (2 * t / T + ph))
        p = v3(sx * 0.14 * k + 0.02 * k * drift, 0.36 * k, 0.765 * k + 0.012 * k * tap)
        hand_on(sk, pose, sfx, p, v3(-sx * 0.25, 0.95, -0.15), v3(-sx * 0.1, 0.1, -1.0), pole=v3(sx * 1.0, -0.4, -0.4),
                along_share=0.5)
        hs = hand_shape("relaxed", 1.0)
        hs.curl["index"] = (10 + 18 * tap, 22, 10)
        hs.curl["middle"] = (14 + 14 * (1 - tap), 26, 12)
        pose.hands[sfx] = hs
    return pose


def smoke(sk: Skeleton, f: int, N: int) -> Pose:
    """Standing, cigarette in the right hand: one drag per 2 s; left arm across the waist."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = idle(sk, f, N)
    u = (t / T * 2.0) % 1.0
    up = smooth(0.08, 0.28, u) * (1.0 - smooth(0.50, 0.72, u))
    exhale = smooth(0.55, 0.65, u) * (1.0 - smooth(0.8, 0.95, u))
    look(pose, pitch=-3.0 * exhale + 2.0 * up, yaw=-4.0 * exhale)
    pre = Solver(sk).solve(pose)
    mouth = pre.P["head"] + pre.W["head"] @ v3(0.03 * k, 0.11 * k, 0.025 * k)
    low = A.bone_point(pre, sk, "chest", v3(0.16 * k, 0.16 * k, -0.12 * k))
    p = low * (1.0 - up) + mouth * up
    hand_on(sk, pose, "R", p, unit(v3(-0.35, 0.3, 0.8) * up + v3(-0.2, 0.6, 0.3) * (1 - up)),
            unit(v3(-0.4, -0.9, 0.0) * up + v3(-0.6, -0.1, 0.6) * (1 - up)), pole=v3(0.6, -0.3, -0.9), along_share=0.95,
            palm_off=0.0)
    pose.hands["R"] = hand_shape("pinch")
    across = A.bone_point(pre, sk, "spine", v3(0.06 * k, 0.15 * k, 0.02 * k))
    hand_on(sk, pose, "L", across, v3(0.95, 0.2, 0.0), v3(0.0, -0.4, 0.9), pole=v3(-0.5, -0.4, -1.0), along_share=0.5)
    pose.hands["L"] = hand_shape("relaxed", 1.2)
    return pose


def lean_wall(sk: Skeleton, f: int, N: int) -> Pose:
    """Back against a wall 0.2 m behind the heels, one foot up flat against it, arms crossed."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = neutral(sk)
    pose.hip = v3(0.0, -0.10 * k, -0.045 * k)
    stand(sk, pose, spread=0.03, stagger_l=0.14, stagger_r=0.0, yaw_l=14, yaw_r=10)
    pose.legs["R"] = A.LegIK(ankle=v3(0.11 * k, -0.15 * k, 0.33 * k), foot=rxd(-60.0) @ rzd(-10.0), toe=A.rad(15.0),
                             pole=v3(0.35, 1.0, 0.0))
    spine(pose, lean=-8.0, chest_lean=-3.0, side=1.5, neck=(8, 0, 0), head=(8, -3, 0), hips=(-5, -2, 0))
    look(pose, yaw=12.0 * math.sin(TAU * t / T), pitch=2.0)
    breathe(pose, t, T / 4.0)
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        p = A.bone_point(pre, sk, "chest", v3(-sx * 0.10 * k, 0.15 * k, 0.04 * k - (0.03 * k if sx > 0 else 0.0)))
        hand_on(sk, pose, sfx, p, pre.W["chest"] @ v3(-sx * 0.95, 0.2, 0.1), pre.W["chest"] @ v3(0.0, -1.0, 0.1),
                pole=pre.W["chest"] @ v3(sx * 0.5, -0.1, -1.0), along_share=0.5)
        pose.hands[sfx] = hand_shape("relaxed", 1.3)
    return pose


def tased(sk: Skeleton, f: int, N: int) -> Pose:
    """Electrocuted: rigid, arms pulled in and up, high-frequency jitter, head back."""
    t = f / FPS
    k = sk.scale
    pose = neutral(sk)
    pose.hip = v3(0.0, -0.02 * k, -0.06 * k)
    stand(sk, pose, spread=0.04, stagger_l=0.04, yaw_l=10, yaw_r=10)
    j = math.sin(TAU * 10.0 * t)
    j2 = math.sin(TAU * 8.0 * t + 1.3)
    spine(pose, lean=-6 + 2 * j, chest_lean=-4 + 2 * j2, side=2 * j2, neck=(-10 + 3 * j, 0, 0),
          head=(-12 + 4 * j2, 3 * j, 4 * j), hips=(4, 1.5 * j, 0))
    for sfx, sx in A.SIDES:
        arm_fk(sk, pose, sfx, add=10.0 + 4 * j * sx, swing=28.0 + 5 * j2, flex=95.0 + 8 * j, twist=40.0,
               clav_up=12.0 + 3 * j, wrist_flex=30.0)
        pose.hands[sfx] = hand_shape("claw", 1.2)
    return pose


def climb_ladder(sk: Skeleton, f: int, N: int) -> Pose:
    """Climbing a ladder whose rungs are 0.3 m apart, 0.28 m in front of the root. In place:
    rungs move down at ``speed``; each hand/foot holds a rung while it moves down, then reaches
    up two rungs (0.6 m) per cycle."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    rise = 0.6 * k                         # metres per cycle
    hips_rest = sk.head["hips"]
    pose.hip = v3(0.0, -0.02 * k, -0.06 * k + 0.008 * k * math.sin(TAU * 2 * t / T))
    spine(pose, lean=6.0, chest_lean=-2.0, neck=(-10, 0, 0), head=(-8, 0, 0))
    del hips_rest

    def limb_z(ph: float, top: float) -> tuple[float, float]:
        """Height offset (0 = top hold) and reach flag for a limb at its own phase."""
        if ph < 0.7:
            return top - rise * ph / 0.7 * 0.7, 0.0          # holding: moves down with the ladder
        w = (ph - 0.7) / 0.3
        return top - rise * 0.7 + rise * 0.7 * cos_ease(w), math.sin(math.pi * w)
    for sfx, sx in A.SIDES:
        ph_hand = (t / T + (0.0 if sfx == "R" else 0.5)) % 1.0
        ph_foot = (t / T + (0.5 if sfx == "R" else 0.0)) % 1.0
        zh, lift_h = limb_z(ph_hand, 1.82 * k)
        p = v3(sx * 0.17 * k, 0.30 * k - 0.05 * k * lift_h, zh)
        hand_on(sk, pose, sfx, p, v3(-sx * 0.15, 0.4, 0.9), v3(0.0, 1.0, -0.2), pole=v3(sx * 0.8, -0.3, -0.6),
                along_share=0.55)
        pose.hands[sfx] = hand_shape("grip", 1.0 - 0.7 * lift_h)
        zf, lift_f = limb_z(ph_foot, 0.55 * k)
        ank = v3(sx * 0.12 * k, 0.12 * k - 0.06 * k * lift_f, zf + 0.06 * k)
        pose.legs[sfx] = A.LegIK(ankle=ank, foot=rxd(-10.0 + 20.0 * lift_f) @ rzd(-sx * 6.0), toe=0.0,
                                 pole=v3(sx * 0.2, 1.0, 0.1))
    return pose


# =============================================================================================
# locomotion
# =============================================================================================
def gaits(table: dict) -> dict[str, Gait]:
    def g(name: str, **kw) -> Gait | None:
        if name not in table:
            return None
        return Gait(speed=table[name]["speed"], frames=table[name]["frames"], **kw)
    out = {
        "walk": g("walk", beta=0.6, lift=0.07, drop=0.035, pelvis_yaw=7.0, strike=16.0, toeoff=-30.0,
                  centre={"L": (0.0, -0.04), "R": (0.0, -0.04)}, arm_swing=17.0, elbow=14.0),
        "run": g("run", beta=0.36, lift=0.17, lift_skew=0.6, run=True, drop=0.075, bob=0.028, strike=8.0, toeoff=-40.0,
                 lean=9.0, pelvis_yaw=9.0, pelvis_roll=4.0, arm_swing=34.0, arm_add=30.0, elbow=78.0, elbow_swing=12.0,
                 hand="loose_fist", centre={"L": (0.0, -0.07), "R": (0.0, -0.07)}, sway=0.012, swing_toe_up=12.0,
                 heel_rise=0.45, flat_at=0.12),
        "sprint": g("sprint", beta=0.30, lift=0.26, lift_skew=0.55, run=True, drop=0.09, bob=0.03, strike=4.0,
                    toeoff=-46.0, lean=16.0, pelvis_yaw=10.0, pelvis_roll=4.0, arm_swing=46.0, arm_add=28.0, elbow=85.0,
                    elbow_swing=10.0, hand="loose_fist", hand_amount=1.2, centre={"L": (0.0, -0.10), "R": (0.0, -0.10)},
                    sway=0.008, swing_toe_up=14.0, heel_rise=0.35, flat_at=0.1),
        "crouch_walk": g("crouch_walk", beta=0.62, lift=0.06, drop=0.29, bob=0.012, strike=8.0, toeoff=-26.0, lean=22.0,
                         pelvis_yaw=5.0, pelvis_roll=2.0, arm_swing=10.0, arm_add=26.0, elbow=45.0, width=0.03,
                         centre={"L": (0.0, -0.02), "R": (0.0, -0.06)}, head_bob_comp=0.0),
        "strafe_l": g("strafe_l", beta=0.52, lift=0.06, drop=0.07, bob=0.010, direction=(-1.0, 0.0), strike=0.0,
                      toeoff=-14.0, lean=4.0, pelvis_yaw=2.0, pelvis_roll=2.0, arm_swing=3.0, elbow=30.0, toe_out=4.0,
                      centre={"L": (-0.13, 0.03), "R": (0.10, -0.02)}, sway=0.0, swing_toe_up=4.0),
        "strafe_r": g("strafe_r", beta=0.52, lift=0.06, drop=0.07, bob=0.010, direction=(1.0, 0.0), strike=0.0,
                      toeoff=-14.0, lean=4.0, pelvis_yaw=2.0, pelvis_roll=2.0, arm_swing=3.0, elbow=30.0, toe_out=4.0,
                      centre={"L": (-0.10, 0.03), "R": (0.13, -0.02)}, sway=0.0, swing_toe_up=4.0),
        "walk_back": g("walk_back", beta=0.62, lift=0.06, drop=0.05, bob=0.012, direction=(0.0, -1.0), strike=-10.0,
                       toeoff=12.0, flat_at=0.2, heel_rise=0.75, lean=2.0, pelvis_yaw=4.0, arm_swing=8.0, elbow=22.0,
                       centre={"L": (0.0, 0.04), "R": (0.0, 0.04)}, swing_toe_up=-4.0),
        "flee": g("flee", beta=0.36, lift=0.15, lift_skew=0.6, run=True, drop=0.08, bob=0.03, strike=8.0, toeoff=-38.0,
                  lean=6.0, pelvis_yaw=9.0, pelvis_roll=4.0, centre={"L": (0.0, -0.07), "R": (0.0, -0.07)}, sway=0.014,
                  heel_rise=0.45, upper=_flee_upper),
        "carry_bag_walk": g("carry_bag_walk", beta=0.44, lift=0.10, lift_skew=0.65, run=True, drop=0.09, bob=0.022,
                            strike=10.0, toeoff=-30.0, lean=12.0, pelvis_yaw=6.0, pelvis_roll=3.5, arm_swing=26.0,
                            arm_add=30.0, elbow=55.0, hand="loose_fist", centre={"L": (0.0, -0.06), "R": (0.0, -0.06)},
                            sway=0.016, upper=_carry_upper),
    }
    # strafes: the trailing leg must never cross the leading one (see _anim.Gait); walk_back rolls
    # toe-first (strike < 0) and lifts the heel last (toeoff > 0)
    return {k: v for k, v in out.items() if v is not None}


def _flee_upper(sk: Skeleton, pose: Pose, ph: float, f: int) -> None:
    """Panicked run: forearms up near the head, hands open, head ducked."""
    for sfx, sgn in (("R", 1.0), ("L", -1.0)):
        sw = sgn * 18.0 * math.cos(TAU * ph)
        arm_fk(sk, pose, sfx, add=20.0, swing=55.0 + sw, flex=115.0 + 8.0 * math.sin(TAU * ph), twist=30.0, clav_up=10.0)
        pose.hands[sfx] = hand_shape("spread", 0.6)
    add_rot(pose, "neck", rxd(-8.0))
    add_rot(pose, "head", rxd(-6.0))


def _carry_upper(sk: Skeleton, pose: Pose, ph: float, f: int) -> None:
    """Bag on the back: the right hand holds the strap at the right shoulder; the body leans
    forward and slightly left against the load."""
    k = sk.scale
    pre = Solver(sk).solve(pose)
    p = A.bone_point(pre, sk, "chest", v3(0.10 * k, 0.09 * k, 0.17 * k)) + v3(0.0, 0.0, 0.006 * k * math.cos(TAU * 2 * ph))
    hand_on(sk, pose, "R", p, pre.W["chest"] @ v3(-0.25, 0.1, 0.95), pre.W["chest"] @ v3(-0.1, -1.0, 0.0),
            pole=pre.W["chest"] @ v3(0.5, 0.3, -1.0), along_share=0.6)
    pose.hands["R"] = hand_shape("fist", 0.9)
    add_rot(pose, "chest", ryd(-3.0))


# =============================================================================================
# one-shots
# =============================================================================================
def _fire(sk: Skeleton, rifle: bool, N: int) -> callable:
    def fn(f: int) -> Pose:
        t = f / FPS
        rec = pulse(t, 1.0 / FPS, (N - 1) / FPS) if rifle else pulse(t, 1.0 / FPS, (N - 1) / FPS)
        return gun_pose(sk, rifle, 0.0, sway=0.0, recoil=rec)
    return fn


def _reload_pistol(sk: Skeleton, solver: Solver, N: int) -> Keys:
    k = sk.scale
    aim = gun_pose(sk, False, 0.0, sway=0.0)

    def low(dz: float, roll: float, lpos=None, lalong=None, lpalm=None, lshape="pinch", support=False) -> Pose:
        p = gun_pose(sk, False, 0.0, sway=0.0)
        spine(p, lean=7, twist=-3, chest_lean=6, neck=(10, 0, 0), head=(14, 0, 4), hips=(1, 0, -3))
        wf = weapon_frame(v3(0.06 * k, 0.33 * k, (1.24 + dz) * k), yaw=8.0, pitch=18.0, roll=roll)
        hold_pistol(sk, p, wf, one_hand=True)
        if support:
            pistol_support(sk, p, wf)
        elif lpos is not None:
            hand_on(sk, p, "L", lpos(wf), lalong(wf), lpalm(wf), pole=v3(-0.7, -0.3, -0.6), along_share=0.75)
            p.hands["L"] = hand_shape(lshape)
        return p
    pouch = v3(-0.13 * k, 0.07 * k, 0.98 * k)
    at_pouch = (lambda wf: pouch, lambda wf: v3(0.1, 0.3, -0.95), lambda wf: v3(0.95, 0.0, 0.2))
    mag_low = (lambda wf: wf_point(wf, PISTOL["magwell"] + v3(-0.005, -0.01, -0.10)), lambda wf: wf[0] @ v3(0.25, 0.5, 0.85),
               lambda wf: wf[0] @ v3(0.9, -0.2, -0.3))
    mag_in = (lambda wf: wf_point(wf, PISTOL["magwell"] + v3(-0.004, -0.008, -0.035)), lambda wf: wf[0] @ v3(0.25, 0.5, 0.85),
              lambda wf: wf[0] @ v3(0.9, -0.2, -0.3))
    keys = [
        (0, aim, "inout"),
        (7, low(0.0, 22.0, support=False, lpos=at_pouch[0], lalong=at_pouch[1], lpalm=at_pouch[2], lshape="relaxed"), "inout"),
        (15, low(0.0, 22.0, *at_pouch, lshape="pinch"), "inout"),
        (25, low(0.01, 24.0, *mag_low), "inout"),
        (30, low(0.015, 24.0, *mag_in, lshape="flat"), "snap"),
        (34, low(0.01, 20.0, support=True), "inout"),
        (N, gun_pose(sk, False, 0.0, sway=0.0), "settle"),
    ]
    return Keys(solver, keys)


def _reload_rifle(sk: Skeleton, solver: Solver, N: int) -> Keys:
    k = sk.scale
    aim = gun_pose(sk, True, 0.0, sway=0.0)

    def tilted(lmode: str, pitch: float = 12.0, roll: float = 28.0, lshape: str = "grip", dz: float = 0.0) -> Pose:
        p = gun_pose(sk, True, 0.0, sway=0.0)
        spine(p, lean=7, twist=-14, chest_lean=6, chest_twist=-10, neck=(10, 0, 4), head=(14, 6, 8), hips=(2, 0, -6))
        wf = weapon_frame(v3(0.09 * k, 0.24 * k, (1.30 + dz) * k), yaw=10.0, pitch=pitch, roll=roll)
        hold_weapon(sk, p, wf, pole=v3(0.8, -0.2, -0.6))
        p.hands["R"] = hand_shape("trigger")
        R = wf[0]
        if lmode == "mag":           # palm on the magazine below the magwell
            hand_on(sk, p, "L", wf_point(wf, RIFLE["magwell"] + v3(-0.03, 0.0, -0.12)), R @ v3(0.3, 0.5, 0.8),
                    R @ v3(1.0, 0.0, -0.1), pole=v3(-0.6, -0.4, -0.7), along_share=0.6)
        elif lmode == "pouch":
            hand_on(sk, p, "L", v3(-0.10 * k, 0.12 * k, 1.04 * k), v3(0.1, 0.25, -0.95), v3(0.95, 0.0, 0.1),
                    pole=v3(-0.7, -0.3, -0.6), along_share=0.7)
        elif lmode == "insert":
            hand_on(sk, p, "L", wf_point(wf, RIFLE["magwell"] + v3(-0.03, 0.0, -0.17)), R @ v3(0.3, 0.5, 0.8),
                    R @ v3(1.0, 0.0, -0.1), pole=v3(-0.6, -0.4, -0.7), along_share=0.6)
        elif lmode == "push":
            hand_on(sk, p, "L", wf_point(wf, RIFLE["magwell"] + v3(-0.01, 0.0, -0.20)), R @ v3(0.2, 0.9, 0.3),
                    R @ v3(0.2, 0.0, 1.0), pole=v3(-0.6, -0.4, -0.7), along_share=0.45)
        else:
            rifle_support(sk, p, wf)
        p.hands["L"] = hand_shape(lshape)
        return p
    keys = [
        (0, aim, "inout"),
        (9, tilted("mag"), "inout"),
        (16, tilted("mag", dz=-0.02, lshape="grip"), "out"),
        (27, tilted("pouch", lshape="relaxed"), "inout"),
        (33, tilted("pouch", lshape="grip"), "inout"),
        (46, tilted("insert"), "inout"),
        (51, tilted("push", lshape="flat", dz=0.01), "snap"),
        (58, tilted("support", roll=12.0, pitch=6.0), "inout"),
        (N, gun_pose(sk, True, 0.0, sway=0.0), "settle"),
    ]
    return Keys(solver, keys)


def _stand_key(sk: Skeleton) -> Pose:
    return idle(sk, 0, 120)


def _death(sk: Skeleton, solver: Solver, N: int, forward: bool) -> Keys:
    """Collapse: hit jolt, knees buckle, torso falls, impact, small settle. Ends lying on the
    floor (prone for ``forward``, supine otherwise)."""
    k = sk.scale
    hips_rest = sk.head["hips"]
    s = 1.0 if forward else -1.0
    hit = _stand_key(sk)
    hit.hip = hit.hip + v3(0.0, -0.03 * k * s, -0.02 * k)
    spine(hit, lean=-8 * s, chest_lean=-10 * s, side=4, neck=(-8 * s, 0, 0), head=(-12 * s, 4, 10), hips=(-4 * s, 0, 0))
    for sfx in ("L", "R"):
        arm_fk(sk, hit, sfx, add=26.0, swing=25.0 if forward else -10.0, flex=40.0, out=8.0)
        hit.hands[sfx] = hand_shape("claw", 0.8)

    buckle = Pose()
    if forward:
        buckle.hip = v3(0.02 * k, 0.12 * k, 0.56 * k - hips_rest[2])
        spine(buckle, hips=(20, 0, 6), lean=18, chest_lean=12, neck=(8, 0, 0), head=(14, 0, 10))
        for sfx, sx in A.SIDES:
            buckle.legs[sfx] = A.LegIK(ankle=v3(sx * 0.13 * k, -0.30 * k, 0.16 * k), foot=rxd(-62.0), toe=A.rad(55.0),
                                       pole=v3(sx * 0.2, 1.0, -0.4))
    else:
        buckle.hip = v3(-0.01 * k, -0.20 * k, 0.50 * k - hips_rest[2])
        spine(buckle, hips=(-28, 0, -6), lean=-8, chest_lean=-12, neck=(-10, 0, 0), head=(-16, 0, -8))
        for sfx, sx in A.SIDES:
            buckle.legs[sfx] = A.LegIK(ankle=v3(sx * 0.14 * k, 0.12 * k, 0.085 * k), foot=rzd(-sx * 10.0), toe=0.0,
                                       pole=v3(sx * 0.25, 1.0, 0.3))
    for sfx in ("L", "R"):
        arm_fk(sk, buckle, sfx, add=18.0, swing=40.0 if forward else -20.0, flex=35.0, out=12.0)
        buckle.hands[sfx] = hand_shape("spread", 0.6)

    ground = Pose()
    if forward:
        ground.hip = v3(0.04 * k, 0.62 * k, 0.125 * k - hips_rest[2])
        spine(ground, hips=(90, 4, 8), lean=-4, chest_lean=-3, neck=(-8, 0, 0), head=(-6, 4, 62))
        ground.legs["L"] = A.LegIK(ankle=v3(-0.22 * k, -0.26 * k, 0.07 * k), foot=rxd(-150.0) @ rzd(10.0), toe=A.rad(30.0),
                                   pole=v3(-0.3, 0.0, -1.0))
        ground.legs["R"] = A.LegIK(ankle=v3(0.26 * k, -0.18 * k, 0.11 * k), foot=rxd(-135.0) @ rzd(-25.0), toe=A.rad(30.0),
                                   pole=v3(0.6, 0.0, -1.0))
    else:
        ground.hip = v3(-0.03 * k, -0.62 * k, 0.11 * k - hips_rest[2])
        spine(ground, hips=(-90, -2, -6), lean=-5, chest_lean=-6, neck=(-6, 0, 0), head=(-8, 0, -40))
        ground.legs["L"] = A.LegIK(ankle=v3(-0.24 * k, 0.24 * k, 0.07 * k), foot=rxd(78.0) @ rzd(12.0), toe=0.0,
                                   pole=v3(-0.3, 0.0, 1.0))
        ground.legs["R"] = A.LegIK(ankle=v3(0.18 * k, 0.12 * k, 0.12 * k), foot=rxd(55.0) @ rzd(-18.0), toe=0.0,
                                   pole=v3(0.45, 0.4, 1.0))
    pre = Solver(sk).solve(ground)
    for sfx, sx in A.SIDES:
        if forward:
            # left arm flung forward along the floor, right arm tucked by the side
            if sfx == "L":
                p = A.bone_point(pre, sk, "chest", pre.W["chest"] @ v3(0, 0, 0)) + v3(-0.30 * k, 0.32 * k, -0.10 * k)
                p[2] = 0.035 * k
                hand_on(sk, ground, sfx, p, v3(-0.2, 1.0, 0.0), v3(0.0, 0.0, -1.0), pole=v3(-0.6, 0.0, 1.0),
                        along_share=0.5, palm_off=0.012, clav=0.5)
            else:
                p = v3(0.24 * k, pre.P["hips"][1] + 0.05 * k, 0.04 * k)
                hand_on(sk, ground, sfx, p, v3(0.1, -1.0, 0.0), v3(0.0, 0.3, 1.0), pole=v3(0.7, 0.3, 0.6),
                        along_share=0.5, palm_off=0.012, clav=0.3)
        else:
            p = pre.P[f"upper_arm.{sfx}"] + v3(sx * 0.42 * k, -0.18 * k * sx, 0.0)
            p[2] = 0.035 * k
            hand_on(sk, ground, sfx, p, v3(sx * 0.7, 0.0 - 0.6 * sx, 0.0), v3(0.0, 0.0, 1.0), pole=v3(sx * 0.5, 0.0, -1.0),
                    along_share=0.5, palm_off=0.012, clav=0.4)
        ground.hands[sfx] = hand_shape("relaxed", 0.8)

    impact = ground.copy()
    impact.hip = impact.hip + v3(0.0, 0.0, -0.012 * k)
    add_rot(impact, "chest", rxd(3.0 * s))
    add_rot(impact, "head", rxd(6.0 * s))
    keys = [(0, hit.copy(), "inout"), (5, hit, "snap"), (int(N * 0.36), buckle, "inout"), (int(N * 0.66), impact, "heavy"),
            (int(N * 0.80), ground, "out"), (N, ground, "inout")]
    return Keys(solver, keys)


def _hit_react(sk: Skeleton, solver: Solver, N: int) -> Keys:
    k = sk.scale
    a = _stand_key(sk)
    b = _stand_key(sk)
    b.hip = b.hip + v3(0.0, -0.04 * k, -0.025 * k)
    spine(b, lean=-6, chest_lean=-9, side=3, twist=6, neck=(-8, 0, 0), head=(-12, 4, 10), hips=(-3, 0, 0))
    for sfx in ("L", "R"):
        arm_fk(sk, b, sfx, add=28.0, swing=22.0, flex=42.0, out=6.0)
        b.hands[sfx] = hand_shape("claw", 0.8)
    c = _stand_key(sk)
    c.hip = c.hip + v3(0.0, 0.01 * k, -0.02 * k)
    spine(c, lean=4, chest_lean=3, neck=(3, 0, 0), head=(4, 0, 2))
    return Keys(solver, [(0, a, "inout"), (3, b, "snap"), (9, c, "inout"), (N, _stand_key(sk), "inout")])


def _radio_call(sk: Skeleton, solver: Solver, N: int) -> Keys:
    k = sk.scale

    def talk(nod: float) -> Pose:
        p = _stand_key(sk)
        spine(p, lean=3, chest_twist=4, neck=(10 + nod, -4, 8), head=(12 + nod, -8, 14))
        pre = Solver(sk).solve(p)
        q = A.bone_point(pre, sk, "chest", pre.W["chest"] @ v3(-0.07 * k, 0.14 * k, 0.12 * k))
        hand_on(sk, p, "L", q, pre.W["chest"] @ v3(0.3, 0.1, 0.95), pre.W["chest"] @ v3(0.3, -0.95, 0.0),
                pole=v3(-0.6, -0.2, -1.0), along_share=0.7)
        p.hands["L"] = hand_shape("pinch", 0.9)
        p.hands["R"] = hand_shape("relaxed")
        return p
    return Keys(solver, [(0, _stand_key(sk), "inout"), (11, talk(0.0), "inout"), (22, talk(-3.0), "inout"),
                         (33, talk(2.0), "inout"), (44, talk(-2.0), "inout"), (N, _stand_key(sk), "inout")])


def _throw_bag(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """Two-handed heave from the right hip, released at frame 15 forward-up."""
    k = sk.scale

    def both(pose: Pose, centre, yaw: float, along_up: float, pre_twist: float = 0.0) -> None:
        R = rzd(yaw)
        for sfx, sx in A.SIDES:
            p = centre + R @ v3(sx * 0.12 * k, 0.0, 0.0)
            hand_on(sk, pose, sfx, p, R @ v3(-sx * 0.3, 0.3, along_up), R @ v3(-sx * 1.0, 0.0, 0.0),
                    pole=R @ v3(sx * 0.6, -0.5, -0.6), along_share=0.6)
            pose.hands[sfx] = hand_shape("fist", 0.9)

    carry = _stand_key(sk)
    both(carry, v3(0.0, 0.18 * k, 0.95 * k), 0.0, -0.9)
    wind = _stand_key(sk)
    wind.hip = wind.hip + v3(0.03 * k, -0.06 * k, -0.08 * k)
    stand(sk, wind, spread=0.05, stagger_l=0.14, stagger_r=-0.12, yaw_l=10, yaw_r=30)
    spine(wind, lean=22, twist=-24, chest_lean=12, chest_twist=-18, neck=(-6, 0, 10), head=(-10, 0, 16), hips=(6, 0, -14))
    both(wind, v3(0.30 * k, -0.18 * k, 0.72 * k), -40.0, -0.8)
    release = _stand_key(sk)
    release.hip = release.hip + v3(-0.02 * k, 0.10 * k, -0.02 * k)
    stand(sk, release, spread=0.05, stagger_l=0.14, stagger_r=-0.12, yaw_l=10, yaw_r=30)
    plant(sk, release, "R", (0.05 * k, -0.12 * k, 0.0), yaw=-30.0, pitch=-30.0, toe=30.0, pivot="ball")
    spine(release, lean=-6, twist=14, chest_lean=-8, chest_twist=12, neck=(-8, 0, -6), head=(-10, 0, -8), hips=(-2, 0, 10))
    both(release, v3(0.04 * k, 0.52 * k, 1.62 * k), 10.0, 0.9)
    follow = _stand_key(sk)
    follow.hip = follow.hip + v3(-0.02 * k, 0.08 * k, -0.04 * k)
    stand(sk, follow, spread=0.05, stagger_l=0.14, stagger_r=-0.08, yaw_l=10, yaw_r=24)
    spine(follow, lean=8, twist=10, chest_lean=4, chest_twist=6, head=(4, 0, -4))
    for sfx in ("L", "R"):
        arm_fk(sk, follow, sfx, add=30.0, swing=40.0, flex=30.0)
        follow.hands[sfx] = hand_shape("spread", 0.5)
    return Keys(solver, [(0, carry, "inout"), (9, wind, "inout"), (15, release, "in"), (21, follow, "out"),
                         (N, _stand_key(sk), "inout")])


def _drill_place(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """Carry a drill (both hands) to a door at waist-chest height, press it on, let go."""
    k = sk.scale

    def hands(pose: Pose, y: float, z: float, shape: str) -> None:
        for sfx, sx in A.SIDES:
            hand_on(sk, pose, sfx, v3(sx * 0.11 * k, y * k, z * k), v3(-sx * 0.35, 0.8, -0.3), v3(-sx * 1.0, 0.0, 0.0),
                    pole=v3(sx * 0.8, -0.4, -0.6), along_share=0.55)
            pose.hands[sfx] = hand_shape(shape)
    a = _stand_key(sk)
    hands(a, 0.26, 1.00, "grip")
    b = _stand_key(sk)
    b.hip = b.hip + v3(0.0, 0.04 * k, -0.07 * k)
    stand(sk, b, spread=0.03, stagger_l=0.16, stagger_r=-0.06)
    spine(b, lean=14, chest_lean=8, neck=(6, 0, 0), head=(10, 0, 0), hips=(4, 0, 0))
    hands(b, 0.56, 1.08, "grip")
    c = b.copy()
    hands(c, 0.56, 1.08, "flat")
    d = _stand_key(sk)
    spine(d, lean=4, head=(6, 0, 0))
    return Keys(solver, [(0, _stand_key(sk), "inout"), (8, a, "inout"), (22, b, "inout"), (27, b.copy(), "inout"),
                         (32, c, "inout"), (N, d, "inout")])


def _surrender(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """Hands go up, then down to the knees, ending in the kneel_cuffed start pose (hands on head)."""
    k = sk.scale
    up = hands_up(sk, 0, 60)
    kneel_hands = Pose()
    kneel_base(sk, kneel_hands, sit=0.0)
    spine(kneel_hands, lean=2.0, chest_lean=-2.0, neck=(6, 0, 0), head=(8, 0, 0))
    pre = Solver(sk).solve(kneel_hands)
    for sfx, sx in A.SIDES:
        p = pre.P["head"] + pre.W["head"] @ v3(sx * 0.03 * k, -0.06 * k, 0.15 * k)
        hand_on(sk, kneel_hands, sfx, p, pre.W["head"] @ v3(-sx * 0.85, 0.0, 0.4), pre.W["head"] @ v3(0.0, 0.0, -1.0),
                pole=v3(sx * 1.0, 0.0, 0.1), along_share=0.45)
        kneel_hands.hands[sfx] = hand_shape("relaxed", 0.6)
    mid = Pose()
    mid.hip = v3(0.0, 0.0, 0.70 * k - sk.head["hips"][2])
    plant(sk, mid, "L", (0.0, 0.18 * k, 0.0), yaw=8.0)
    mid.legs["R"] = A.LegIK(ankle=v3(0.12 * k, -0.36 * k, 0.14 * k), foot=rxd(-70.0), toe=A.rad(60.0), pole=v3(0.15, 1.0, -0.4))
    spine(mid, lean=10.0, chest_lean=2.0, neck=(4, 0, 0), head=(6, 0, 0))
    mid.arms = {s: a for s, a in kneel_hands.arms.items()}
    mid.hands = dict(kneel_hands.hands)
    end = kneel_cuffed(sk, 0, 60)
    del end
    return Keys(solver, [(0, _stand_key(sk), "inout"), (12, up, "out"), (22, up.copy(), "inout"), (36, mid, "inout"),
                         (N, kneel_hands, "settle")])


def _melee(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """Rifle-butt / pistol-whip strike: wind back, lunge with a short step, recover."""
    k = sk.scale
    a = gun_pose(sk, True, 0.0, sway=0.0)
    b = gun_pose(sk, True, 0.0, sway=0.0)
    b.hip = b.hip + v3(0.0, -0.05 * k, -0.02 * k)
    spine(b, lean=0, twist=-28, chest_lean=-2, chest_twist=-18, head=(4, 0, 24), hips=(0, 0, -16))
    wf = weapon_frame(v3(0.20 * k, 0.05 * k, 1.38 * k), yaw=-20.0, pitch=30.0, roll=-30.0)
    hold_weapon(sk, b, wf, pole=v3(0.8, -0.3, -0.5))
    rifle_support(sk, b, wf)
    c = gun_pose(sk, True, 0.0, sway=0.0)
    c.hip = c.hip + v3(-0.02 * k, 0.14 * k, -0.07 * k)
    stand(sk, c, spread=0.04, stagger_l=0.30, stagger_r=-0.10, yaw_l=6, yaw_r=26)
    spine(c, lean=12, twist=16, chest_lean=8, chest_twist=14, head=(4, 0, -14), hips=(4, 0, 10))
    wf = weapon_frame(v3(0.02 * k, 0.55 * k, 1.42 * k), yaw=30.0, pitch=-10.0, roll=-70.0)
    hold_weapon(sk, c, wf, pole=v3(0.8, -0.3, -0.5))
    rifle_support(sk, c, wf)
    return Keys(solver, [(0, a, "inout"), (6, b, "inout"), (10, c, "snap"), (14, c.copy(), "inout"),
                         (N, gun_pose(sk, True, 0.0, sway=0.0), "settle")])


# =============================================================================================
# turns (in place, the root yaws during the clip)
# =============================================================================================
def _turn(sk: Skeleton, N: int, sign: float, angle: float = 90.0):
    """In-place turn for a root that ENV A yaws by ``sign * angle`` deg over the clip (linear).
    The trunk faces the root's forward throughout; planted feet counter-rotate with the ground
    and step twice (zero sliding when the root turns at angle / duration)."""
    k = sk.scale

    def fn(f: int) -> Pose:
        u = f / N
        pose = neutral(sk)
        lead, trail = ("L", "R") if sign > 0 else ("R", "L")
        for sfx, (t0, t1) in ((lead, (0.10, 0.45)), (trail, (0.45, 0.85))):
            # ground rotation since the foot was planted (it lags the root by -angle*u)
            planted = -sign * angle * u
            step = sign * angle * smooth(t0, t1, u)
            yaw = planted + step                      # foot yaw relative to the root
            lift = 0.06 * k * math.sin(math.pi * clamp(((u - t0) / (t1 - t0))))
            g = sk.ground(sfx)
            pos = rzd(yaw) @ (g["ankle"] * v3(1.0, 1.0, 0.0)) + v3(0.0, 0.0, g["ankle"][2] + lift)
            sx = A.side_x(sfx)
            pose.legs[sfx] = A.LegIK(ankle=pos, foot=rzd(yaw - sx * 6.0) @ rxd(8.0 * math.sin(math.pi * clamp((u - t0) / (t1 - t0)))),
                                     toe=0.0, pole=rzd(yaw) @ v3(sx * 0.1, 1.0, 0.0))
        pose.hip = pose.hip + v3(0.0, 0.0, -0.02 * k * math.sin(math.pi * u))
        look(pose, yaw=sign * 12.0 * math.sin(math.pi * min(1.0, u * 1.6)))
        for sfx, sx in A.SIDES:
            arm_fk(sk, pose, sfx, add=36.0, swing=4.0 * math.sin(math.pi * u) * sx * sign, flex=16.0)
            pose.hands[sfx] = hand_shape("relaxed")
        return pose
    return fn


def clamp(x: float) -> float:
    return 0.0 if x < 0.0 else 1.0 if x > 1.0 else x


# =============================================================================================
# registry
# =============================================================================================
def clips(sk: Skeleton, table: dict) -> dict[str, Clip]:
    """Every clip of ``table`` (``anim_humanoid.CLIPS``) as a ``Clip``."""
    solver = Solver(sk)
    G = gaits(table)
    stationary = {
        "idle": idle, "idle_alert": idle_alert, "crouch_idle": crouch_idle, "aim_pistol": aim_pistol,
        "aim_rifle": aim_rifle, "cower": cower, "hands_up": hands_up, "lie_down": lie_down, "tied": tied,
        "kneel_cuffed": kneel_cuffed, "phone_call": phone_call, "pager_answer": pager_answer,
        "investigate_look": investigate_look, "downed": downed, "interact_low": interact("low"),
        "interact_mid": interact("mid"), "interact_high": interact("high"), "browse": browse, "desk_type": desk_type,
        "sit_chair": sit_chair, "smoke": smoke, "lean_wall": lean_wall, "tased": tased, "climb_ladder": climb_ladder,
    }
    floor = {"lie_down": 0, "tied": 0, "kneel_cuffed": 0, "downed": 0, "surrender": -14}
    out: dict[str, Clip] = {}
    for name, row in table.items():
        N, loop, speed = int(row["frames"]), bool(row["loop"]), float(row["speed"])
        ev = dict(row.get("events", {}))
        if name in G:
            g = G[name]
            out[name] = Clip(name, N, loop, (lambda f, g=g: g.pose(sk, f)), speed, g, ev)
        elif name in stationary:
            fn = stationary[name]
            out[name] = Clip(name, N, loop, (lambda f, fn=fn, N=N: fn(sk, f, N)), speed, None, ev,
                             reach_fix=name in ("idle", "idle_alert", "crouch_idle", "aim_pistol", "aim_rifle",
                                                "investigate_look", "phone_call", "pager_answer", "smoke", "browse"))
        elif name in ("fire_pistol", "fire_rifle"):
            out[name] = Clip(name, N, loop, _fire(sk, name == "fire_rifle", N), speed, None, ev)
        elif name in ("turn_l", "turn_r"):
            out[name] = Clip(name, N, loop, _turn(sk, N, 1.0 if name == "turn_l" else -1.0), speed, None, ev,
                             reach_fix=False)
        else:
            maker = {"reload_pistol": _reload_pistol, "reload_rifle": _reload_rifle,
                     "death_front": lambda s, so, n: _death(s, so, n, True),
                     "death_back": lambda s, so, n: _death(s, so, n, False), "hit_react": _hit_react,
                     "radio_call": _radio_call, "throw_bag": _throw_bag, "drill_place": _drill_place,
                     "surrender": _surrender, "melee": _melee}[name]
            out[name] = Clip(name, N, loop, maker(sk, solver, N), speed, None, ev, reach_fix=False)
        if name in floor:
            out[name].floor = floor[name]
        elif name.startswith("death_"):
            out[name].floor = int(N * 0.62)
        if name.startswith("death_") or name in ("surrender", "cower", "interact_low", "throw_bag", "melee"):
            out[name].no_sink = True
    return out
