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
import _anim_life as life
from _anim import (FPS, TAU, Clip, Gait, Keys, Pose, Skeleton, Solver, add_rot, arm_fk, cos_ease, hand_on,
                   hand_shape, hold_weapon, leg_fk, neutral, periodic, plant, pulse, rxd, ryd, rzd, smooth, spine,
                   spring, stand, unit, v3, weapon_frame, wf_point)

# Weapon marker positions (Blender weapon space, metres), read from the trunk models
# game/assets/weapons/wpn_kestrel_p9 and wpn_corsair_ar (B1-03 / B4-04).
PISTOL = {"left_ik": v3(-0.025, 0.0115, -0.020), "aim": v3(0.0, -0.030, 0.0665), "magwell": v3(0.0, -0.0227, -0.070),
          "muzzle": v3(0.0, 0.1425, 0.048)}
# D-116 follow-up: RIFLE left_ik = the Corsair's current LeftHandIK (ENV B e18011f4: centred under the fore-end; the
# pre-B (-0.0315, 0.330, 0.067) put the third-person support hand beside the handguard)
RIFLE = {"left_ik": v3(0.0, 0.260, 0.038), "aim": v3(0.0, -0.060, 0.1212), "magwell": v3(0.0, 0.1235, -0.012),
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
    # Isosceles, arms near full reach (PO feedback "weapon hold looks unnatural"): the grip 0.60 m out with
    # the sights just under the eye line; it used to sit 0.47 m out at chin height with the elbows folded.
    o = v3(0.035 * k + 0.003 * k * sw * math.sin(TAU * t / 3.0), 0.60 * k,
           1.545 * k + 0.004 * k * sw * math.sin(TAU * t / 1.5))
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


def rifle_support(sk: Skeleton, pose: Pose, wf, pole=None, at=None, cup: bool = True) -> None:
    """The left hand on the fore-end. ``cup``: the PD2 support grip, the fore-end in the palm (palm up under it), the
    fingers wrapping its far (right) side; False: the hand over its left side (strongly rolled rifles, the melee
    strike, where the cup would twist the forearm through its limit)."""
    R = wf[0]
    p = wf_point(wf, RIFLE["left_ik"] if at is None else at)
    if cup:
        along, palm = v3(0.70, 0.60, 0.30), v3(0.10, -0.05, 0.99)
    else:
        along, palm = v3(0.55, 0.65, 0.35), v3(0.55, -0.1, 0.83)
    hand_on(sk, pose, "L", p, R @ along, R @ palm,
            pole=pole if pole is not None else v3(-0.35, -0.3, -0.9), along_share=0.55, palm_off=0.016)
    pose.hands["L"] = hand_shape("grip", 0.85)


def aim_body(sk: Skeleton, pose: Pose, rifle: bool, lean_k: float = 1.0) -> None:
    """The weapon class's aiming trunk; ``lean_k`` scales its forward lean (spine / chest lean) only, for the run layers
    (v1.37: the class lean stacked on the run's own lean read as a crouch; 0.4 keeps them within the 7 deg)."""
    k = sk.scale
    if rifle:
        pose.hip = v3(-0.01 * k, -0.02 * k, -0.035 * k)
        stand(sk, pose, spread=0.04, stagger_l=0.10, stagger_r=-0.10, yaw_l=8, yaw_r=28)
        spine(pose, lean=4 * lean_k, twist=-12, chest_lean=5 * lean_k, chest_twist=-10, chest_side=-2, neck=(4, 0, 6),
              head=(8, 8, 8), hips=(2, 0, -6))
    else:
        pose.hip = v3(0.0, -0.01 * k, -0.03 * k)
        stand(sk, pose, spread=0.035, stagger_l=0.06, stagger_r=-0.05, yaw_l=8, yaw_r=14)
        spine(pose, lean=6 * lean_k, twist=-3, chest_lean=6 * lean_k, neck=(2, 0, 2), head=(-4, 2, 1), hips=(1, 0, -3))


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
    lf = life.Life(life.GLANCES["idle"], T)          # D-116 organic pass: glances that hold, the body following
    lf.head(pose, t, look)
    for sfx, sx in A.SIDES:
        arm_fk(sk, pose, sfx, add=38.0 - 0.8 * sx * math.sin(TAU * t / T), swing=1.5, flex=13.0, twist=8.0)
        pose.hands[sfx] = hand_shape("relaxed")
    life.fk_arm_lag(pose, lf, t)
    breathe(pose, t, T / 3.0, 0.5)
    return pose


def idle_alert(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = neutral(sk)
    pose.hip = v3(0.0, -0.01 * k, -0.04 * k)
    stand(sk, pose, spread=0.045, stagger_l=0.07, stagger_r=-0.05, yaw_l=7, yaw_r=12)
    spine(pose, lean=6.0, chest_lean=2.0, hips=(1, 0, 0))
    # D-116 organic pass: the head glances and holds, the chest and spine follow it late, the weight shifts once per
    # loop, the arms trail the trunk's turn (they used to sweep with one sine, locked to the head)
    lf = life.Life(life.GLANCES["idle_alert"], T)
    lf.weight(sk, pose, t, shift, 0.010)
    lf.head(pose, t, look)
    for sfx, sx in A.SIDES:
        arm_fk(sk, pose, sfx, add=30.0, swing=14.0, flex=48.0 + 4.0 * math.sin(TAU * 2 * t / T), twist=14.0)
        pose.hands[sfx] = hand_shape("loose_fist", 0.8)
    life.fk_arm_lag(pose, lf, t)
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
    """Standing call: the phone at the right ear in the right hand (GRIPS["phone"], HandR/Socket), the left
    hand gesturing."""
    t = f / FPS
    T = N / FPS
    pose = idle(sk, f, N)
    look(pose, yaw=-6.0, pitch=4.0 + 3.0 * math.sin(TAU * 3 * t / T), tilt=8.0)
    pre = Solver(sk).solve(pose)
    R, o = phone_at_ear(sk, pre)
    prop_hand(sk, pose, "phone", R, o, pole=v3(0.6, -0.1, -1.0))
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
    return downed_pose(sk, f / FPS, N / FPS)


def downed_pose(sk: Skeleton, t: float, T: float, recoil: float = 0.0, sit_up: float = 0.0, gun=None, left=None,
                left_shape: str = "pinch") -> Pose:
    """``downed`` at ``t`` of a ``T`` s loop. D-116 crew downed set (_anim_crew3p): ``recoil`` 0..1 kicks the pistol;
    ``sit_up`` 0..1 brings the trunk up off the left hand; ``gun`` = (dx, dy, dz, pitch, roll) moves the pistol (m in
    the chest offset's axes, deg); ``left(pre, wf) -> (point, along, palm)`` takes the left hand off the floor."""
    k = sk.scale
    pose = Pose()
    br = math.sin(TAU * 3 * t / T)
    hips_rest = sk.head["hips"]
    pose.hip = v3(0.0, -0.05 * k, 0.14 * k - hips_rest[2] + 0.003 * k * br)
    spine(pose, hips=(-44 + 26.0 * sit_up, 0, 0), lean=8.0 + 10.0 * sit_up, chest_lean=6.0 + 1.5 * br, neck=(18 - 8.0 * sit_up, 0, 0),
          head=(6 + 6.0 * sit_up, 0, 2.0 * math.sin(TAU * t / T)))
    pose.legs["L"] = A.LegIK(ankle=v3(-0.20 * k, 0.70 * k, 0.07 * k), foot=rxd(18.0) @ rzd(14.0), toe=0.0, pole=v3(-0.5, 0.3, 1.0))
    pose.legs["R"] = A.LegIK(ankle=v3(0.13 * k, 0.48 * k, 0.085 * k), foot=rzd(-10.0), toe=0.0, pole=v3(0.3, 0.6, 1.0))
    pre = Solver(sk).solve(pose)
    dx, dy, dz, gp, gr = gun if gun is not None else (0.0, 0.0, 0.0, 0.0, 0.0)
    o = A.bone_point(pre, sk, "chest", v3((0.07 + dx) * k, (0.40 + dy) * k, (0.12 + dz) * k)) + v3(0.0, 0.0, 0.004 * k * br)
    wf = weapon_frame(o, yaw=4.0 * math.sin(TAU * t / T), pitch=-2.0 + 1.5 * br + gp, roll=gr)
    if recoil:
        R, o = wf
        o = o + R @ v3(0.0, -0.03 * k * recoil, 0.012 * k * recoil)
        wf = (R @ rxd(9.0 * recoil), o)
    if left is None:
        pl = pre.P["upper_arm.L"] + v3(-0.10 * k, -0.16 * k, 0.0)
        pl[2] = 0.012 * k
        hand_on(sk, pose, "L", pl, v3(-0.35, -0.55, -0.1), v3(0.0, 0.0, -1.0),
                pole=v3(-0.6, -0.8, 0.0), along_share=0.55, palm_off=0.012, clav=0.5)
        pose.hands["L"] = hand_shape("flat", 0.5)
    else:
        lp, la, lpalm = left(pre, wf)
        hand_on(sk, pose, "L", lp, la, lpalm, pole=v3(-0.7, -0.3, -0.6), along_share=0.75)
        pose.hands["L"] = hand_shape(left_shape)
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


#: smoke (D-115): the filter tip at the drag, offset from the head joint (rest axes, m at 1.78 m: x right,
#: y forward, z up; the lips' right half), the cigarette's direction out of the mouth and the finger direction
#: (head axes); between drags the filter tip relative to the chest joint, the direction and the fingers (chest axes).
CIG_LIPS = v3(0.012, 0.110, 0.004)
CIG_DRAG_DIR = v3(0.45, 1.0, -0.45)
CIG_DRAG_FINGERS = v3(0.0, 0.4, 1.0)
CIG_LOW = v3(0.24, 0.22, -0.17)
CIG_LOW_DIR = v3(0.85, 0.20, 0.45)
CIG_LOW_FINGERS = v3(-0.10, 1.0, -0.35)


def _frame_zy(z, y) -> np.ndarray:
    """Rotation with Z along ``z`` and Y as close to ``y`` as possible (columns X, Y, Z)."""
    z = unit(np.asarray(z, float))
    y = unit(np.asarray(y, float) - z * float(z @ np.asarray(y, float)))
    return np.column_stack([np.cross(y, z), y, z])


def smoke(sk: Skeleton, f: int, N: int) -> Pose:
    """Standing, a cigarette between the right index and middle fingers (GRIPS["cigarette"], HandR/Socket):
    one drag per 2 s (the filter tip between the lips), held low at the right side between drags; left arm
    across the waist."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = idle(sk, f, N)
    u = (t / T * 2.0) % 1.0
    up = smooth(0.08, 0.28, u) * (1.0 - smooth(0.50, 0.72, u))
    exhale = smooth(0.55, 0.65, u) * (1.0 - smooth(0.8, 0.95, u))
    look(pose, pitch=-3.0 * exhale + 2.0 * up, yaw=-4.0 * exhale)
    pre = Solver(sk).solve(pose)
    # D-115: the hand carries the cigarette (GRIPS["cigarette"], between index and middle): at the drag its
    # filter tip is between the lips (palm toward the mouth, fingers up); between drags it is held low at
    # the right side, palm in, ember pointing out and up.
    Wh = pre.W["head"]
    lips = A.bone_point(pre, sk, "head", CIG_LIPS * k)
    R_up = _frame_zy(Wh @ CIG_DRAG_DIR, Wh @ CIG_DRAG_FINGERS)
    o_low = A.bone_point(pre, sk, "chest", CIG_LOW * k)
    R_low = _frame_zy(pre.W["chest"] @ CIG_LOW_DIR, pre.W["chest"] @ CIG_LOW_FINGERS)
    prop_hand(sk, pose, "cigarette", A.mslerp(R_low, R_up, up), o_low * (1.0 - up) + lips * up,
              pole=v3(0.6, -0.3, -0.9))
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
                  centre={"L": (0.0, -0.04), "R": (0.0, -0.04)}, arm_swing=17.0, elbow=14.0,
                  upper=lambda sk, pose, ph, f: life.walk_upper(sk, pose, ph, f, arm_lag=0.04)),
        # upright combat run (LEAD 2026-10-22): a jog's knees and hips, a shorter stance with a gentler toe-off (the
        # import's key reduction slides a planted ball on a fast roll: run_start / run_stop keep < 4 mm/frame) and
        # swing ends that do not overshoot (swing_match), so the 8-way runs' feet stay in reach without the reach fix
        # lowering the hips
        "run": g("run", beta=0.28, lift=0.09, lift_skew=0.6, run=True, drop=0.068, bob=0.024, strike=8.0, toeoff=-26.0,
                 swing_match=0.4, lean=7.0, pelvis_yaw=9.0, pelvis_roll=4.0, arm_swing=34.0, arm_add=30.0, elbow=78.0,
                 elbow_swing=12.0, hand="loose_fist", centre={"L": (0.0, -0.07), "R": (0.0, -0.07)}, sway=0.012, swing_toe_up=12.0,
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
        "shield_walk": g("shield_walk", beta=0.64, lift=0.055, drop=SHIELD_WALK_DROP, bob=0.010, strike=10.0, toeoff=-24.0,
                         lean=SHIELD_WALK_LEAN, pelvis_yaw=3.0, pelvis_roll=2.5, width=0.05, toe_out=12.0, sway=0.022,
                         chest_counter=1.0, head_bob_comp=0.8, centre={"L": (0.0, 0.03), "R": (0.0, -0.09)}, upper=_shield_upper,
                         exact_pivot=True),
        "dozer_walk": g("dozer_walk", beta=0.60, lift=0.06, lift_skew=0.7, drop=0.06, bob=0.032, strike=14.0, toeoff=-20.0,
                        flat_at=0.12, heel_rise=0.66, lean=6.0, pelvis_yaw=6.0, pelvis_roll=5.5, width=0.075, toe_out=13.0,
                        sway=0.05, chest_counter=2.0, head_bob_comp=0.9, centre={"L": (0.0, -0.03), "R": (0.0, -0.03)},
                        upper=_dozer_upper, exact_pivot=True),
        "mug_carry_walk": g("mug_carry_walk", beta=0.62, lift=0.06, drop=0.04, bob=0.011, strike=13.0, toeoff=-26.0,
                            lean=2.0, pelvis_yaw=5.0, pelvis_roll=2.5, arm_swing=11.0, elbow=18.0, sway=0.014,
                            centre={"L": (0.0, -0.04), "R": (0.0, -0.04)}, upper=_mug_upper),
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


#: D-116 third-person audit: the weapon hand's low carry while the other hand works (the gun at HandR/Socket stays
#: in the hand, PD2 style): the grip by the right thigh, the muzzle down and forward, clear of the body and the head
LOW_CARRY = {"grip": (0.215, 0.085, 0.86), "yaw": 6.0, "pitch": -62.0, "roll": -8.0}


def low_carry(sk: Skeleton, pose: Pose, sway: float = 0.0, crouch: bool = False) -> None:
    """The right hand holds its weapon low by the thigh (``LOW_CARRY``); ``sway`` (-1..1) swings it a little.
    ``crouch``: the grip follows the pose's hip drop and the muzzle points forward and down, past the knee, instead
    of into the floor."""
    k = sk.scale
    gx, gy, gz = LOW_CARRY["grip"]
    pitch = LOW_CARRY["pitch"]
    if crouch:
        gz = gz + float(pose.hip[2]) / k + 0.10
        gy, pitch = gy + 0.10, -18.0
    wf = weapon_frame(v3(gx * k, (gy + 0.03 * sway) * k, gz * k), yaw=LOW_CARRY["yaw"],
                      pitch=pitch + 6.0 * sway, roll=LOW_CARRY["roll"])
    hold_weapon(sk, pose, wf, pole=v3(0.6, -0.2, -0.7), twist=0.6)
    pose.hands["R"] = hand_shape("grip", 0.9)


def _carry_upper(sk: Skeleton, pose: Pose, ph: float, f: int) -> None:
    """Bag on the back over the left shoulder: the LEFT hand holds the strap at the left shoulder, the right hand keeps
    the weapon at a low carry (D-116 audit: the right hand on the strap stood the rifle up behind the head); the body
    leans forward and slightly right against the load."""
    k = sk.scale
    pre = Solver(sk).solve(pose)
    p = A.bone_point(pre, sk, "chest", v3(-0.10 * k, 0.09 * k, 0.17 * k)) + v3(0.0, 0.0, 0.006 * k * math.cos(TAU * 2 * ph))
    hand_on(sk, pose, "L", p, pre.W["chest"] @ v3(0.25, 0.1, 0.95), pre.W["chest"] @ v3(0.1, -1.0, 0.0),
            pole=pre.W["chest"] @ v3(-0.5, 0.3, -1.0), along_share=0.6)
    pose.hands["L"] = hand_shape("fist", 0.9)
    low_carry(sk, pose, math.sin(TAU * ph))
    add_rot(pose, "chest", ryd(3.0))


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
    return Keys(solver, [(0, _stand_key(sk), "inout"), (12, up, "inout"), (22, up.copy(), "inout"), (36, mid, "inout"),
                         (N, kneel_hands, "settle")])


#: the melee strike's support point: forward on the handguard's left side (the strike swings the rifle through a -70 deg
#: roll, where the centred LeftHandIK cup would flip the left forearm)
MELEE_SUPPORT = v3(-0.0315, 0.330, 0.067)


def _melee(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """Rifle-butt / pistol-whip strike: wind back, lunge with a short step, recover."""
    k = sk.scale
    a = gun_pose(sk, True, 0.0, sway=0.0)
    b = gun_pose(sk, True, 0.0, sway=0.0)
    b.hip = b.hip + v3(0.0, -0.05 * k, -0.02 * k)
    spine(b, lean=0, twist=-28, chest_lean=-2, chest_twist=-18, head=(4, 0, 24), hips=(0, 0, -16))
    wf = weapon_frame(v3(0.20 * k, 0.05 * k, 1.38 * k), yaw=-20.0, pitch=30.0, roll=-30.0)
    hold_weapon(sk, b, wf, pole=v3(0.8, -0.3, -0.5))
    rifle_support(sk, b, wf, at=MELEE_SUPPORT, cup=False)
    c = gun_pose(sk, True, 0.0, sway=0.0)
    c.hip = c.hip + v3(-0.02 * k, 0.14 * k, -0.07 * k)
    stand(sk, c, spread=0.04, stagger_l=0.30, stagger_r=-0.10, yaw_l=6, yaw_r=26)
    spine(c, lean=12, twist=16, chest_lean=8, chest_twist=14, head=(4, 0, -14), hips=(4, 0, 10))
    wf = weapon_frame(v3(0.02 * k, 0.55 * k, 1.42 * k), yaw=30.0, pitch=-10.0, roll=-70.0)
    hold_weapon(sk, c, wf, pole=v3(0.8, -0.3, -0.5))
    rifle_support(sk, c, wf, at=MELEE_SUPPORT, cup=False)
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
# specials (P3): Phantom kick, Bulwark shield, Corpsman heal, Wrecker walk
# =============================================================================================
#: Bulwark shield grip (HandL/Socket = ``grip_offset(sk, "L")``, the weapon convention mirrored): the
#: shield's pivot is its vertical handle, held in the left fist like a pistol grip, so the socket's
#: -Z (Blender +Y "muzzle") is the shield's face normal pointing forward and the socket's +Y runs up
#: the handle (char_bulwark_shield, _special_shield.py: same pivot and axes, attached without
#: rotation). ``SHIELD_HANDLE`` is the handle in body space at the braced stance (1.78 m), carried
#: a little left of centre, tilted ``SHIELD_PITCH`` deg top-back and turned ``SHIELD_YAW`` deg with
#: the trunk (the wrist stays within ~12 deg of straight). ``SHIELD`` mirrors that asset for the
#: review proxy and the bang target: centre panel width, wing width and angle, height, thickness,
#: the face in front of the grip and the panel centre relative to the grip (m, deg).
SHIELD_HANDLE = v3(-0.10, 0.34, 1.08)
SHIELD_PITCH = 8.0
SHIELD_YAW = -4.0
SHIELD = {"w": 0.42, "wing": 0.13, "wing_deg": 24.0, "h": 1.10, "t": 0.022, "face": 0.078, "up": -0.05}


def shield_frame(sk: Skeleton, dx: float = 0.0, dy: float = 0.0, dz: float = 0.0, yaw: float = 0.0,
                 pitch: float = 0.0, roll: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    """The shield (handle) frame: facing +Y (``SHIELD_YAW`` / ``SHIELD_PITCH``), moved by (dx, dy,
    dz) m and turned further (deg)."""
    k = sk.scale
    return weapon_frame(SHIELD_HANDLE * k + v3(dx, dy, dz) * k, yaw=SHIELD_YAW + yaw, pitch=SHIELD_PITCH + pitch,
                        roll=roll)


def hold_shield(sk: Skeleton, pose: Pose, wf) -> None:
    """Left fist on the vertical handle (HandL/Socket convention), elbow down and out."""
    hold_weapon(sk, pose, wf, pole=v3(-0.1, -0.15, -1.0), sfx="L", twist=0.6, clav=0.5)
    pose.hands["L"] = hand_shape("grip")


def shield_pistol_frame(sk: Skeleton, t: float = 0.0, sway: float = 1.0) -> tuple[np.ndarray, np.ndarray]:
    """One-handed pistol just outside the shield's right edge, at the sight line."""
    k = sk.scale
    o = v3(0.33 * k + 0.003 * k * sway * math.sin(TAU * t / 3.0), 0.40 * k,
           1.37 * k + 0.004 * k * sway * math.sin(TAU * t / 1.5))
    return weapon_frame(o, yaw=4.0 + 0.6 * sway * math.sin(TAU * t / 3.0 + 0.7), pitch=0.5 * sway * math.sin(TAU * t / 1.5))


def shield_stance(sk: Skeleton, pose: Pose) -> None:
    """Braced behind the shield: low, wide, left foot forward, the left shoulder turned in."""
    k = sk.scale
    pose.hip = v3(0.01 * k, -0.03 * k, -0.075 * k)
    stand(sk, pose, spread=0.07, stagger_l=0.12, stagger_r=-0.11, yaw_l=8, yaw_r=24)
    spine(pose, lean=7, twist=-4, chest_lean=6, chest_twist=-5, neck=(-5, 0, 4), head=(-5, 0, 5), hips=(4, 0, -4))


def shield_brace(sk: Skeleton, t: float = 0.0, sway: float = 1.0) -> Pose:
    """The braced stance with the shield and the pistol at their rest frames (the base of shield_bang)."""
    pose = Pose()
    shield_stance(sk, pose)
    hold_shield(sk, pose, shield_frame(sk))
    hold_pistol(sk, pose, shield_pistol_frame(sk, t, sway), one_hand=True)
    breathe(pose, t, 1.5, 0.8 * sway)
    return pose


#: shield_walk's mean trunk (its Gait lean, hip drop and ``_shield_upper``'s turn), held by shield_idle so
#: that the two blend without the chest, head or hands moving: lean (deg), hip height (m).
SHIELD_WALK_LEAN = 8.0
SHIELD_WALK_DROP = 0.085


def shield_idle(sk: Skeleton, f: int, N: int) -> Pose:
    """Loop: braced behind the shield, the feet planted wide (``shield_stance``'s feet), the trunk,
    shield and pistol at shield_walk's mean pose (so the two blend). Slow, deep breaths (2 per loop)
    through the chest and shoulders, one weight shift between the feet per loop (the shield follows
    the hips with shield_walk's share, the pistol drifts a few mm at the sight line) and a small
    head scan."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    shield_stance(sk, pose)
    pose.hip = v3(0.0, 0.0, -SHIELD_WALK_DROP * k)
    ln = SHIELD_WALK_LEAN
    spine(pose, lean=ln * 0.5, chest_lean=ln * 0.5, neck=(-ln * 0.45, 0.0, 0.0), head=(-ln * 0.45, 0.0, 0.0),
          hips=(ln * 0.25, 0.0, 0.0))
    add_rot(pose, "spine", rzd(-4.0))
    add_rot(pose, "chest", rzd(-5.0))
    look(pose, yaw=8.0)
    shift(sk, pose, t, T, 0.010)
    hx = pose.hip[0] / k
    hz = pose.hip[2] / k + SHIELD_WALK_DROP
    br = math.sin(TAU * 2.0 * t / T)
    look(pose, yaw=2.5 * math.sin(TAU * t / T + 0.9), pitch=0.6 * math.sin(TAU * 2.0 * t / T + 0.3))
    hold_shield(sk, pose, shield_frame(sk, dx=0.4 * hx, dz=0.55 * hz + 0.0015 * br,
                                       yaw=0.5 * math.sin(TAU * t / T - 0.4)))
    R, o = shield_pistol_frame(sk, 0.0, 0.0)
    o = o + v3((0.3 * hx + 0.003 * math.sin(TAU * t / T + 0.7)) * k, 0.0,
               (0.7 * hz + 0.003 * br + 0.002 * math.sin(TAU * 2.0 * t / T)) * k)
    hold_pistol(sk, pose, (R @ rzd(0.6 * math.sin(TAU * t / T + 1.4)) @ rxd(0.4 * math.sin(TAU * 2.0 * t / T)), o),
                one_hand=True)
    breathe(pose, t, T / 2.0, 1.1)
    return pose


def _shield_upper(sk: Skeleton, pose: Pose, ph: float, f: int) -> None:
    """shield_walk: the trunk stays square and braced; the shield rides the hips with some inertia
    (half the bob, a lagging sway), the pistol stays at the sight line beside its right edge."""
    k = sk.scale
    add_rot(pose, "spine", rzd(-4.0))
    add_rot(pose, "chest", rzd(-5.0))
    look(pose, yaw=8.0)
    hz = (pose.hip[2] / k + SHIELD_WALK_DROP)
    hx = pose.hip[0] / k
    lag = math.cos(TAU * (ph - 0.08))
    wf = shield_frame(sk, dx=0.4 * hx, dz=0.55 * hz, yaw=1.2 * lag, roll=-0.8 * lag)
    hold_shield(sk, pose, wf)
    R, o = shield_pistol_frame(sk, 0.0, 0.0)
    o = o + v3(0.3 * hx * k, 0.0, 0.7 * hz * k)
    hold_pistol(sk, pose, (R @ rxd(0.8 * math.sin(TAU * 2 * (ph - 0.1))), o), one_hand=True)


def _shield_bang(sk: Skeleton, N: int, hits: tuple) -> callable:
    """Braced; the pistol rises over the shield's top right corner and chops its butt down onto the
    rim on every ``hits`` frame (the shield and the trunk jolt on impact), then returns to aim."""
    k = sk.scale
    # the top edge of the centre panel near its right corner, on the panel's mid-plane
    rim = A.wf_point(shield_frame(sk), v3(0.15 * k, (SHIELD["face"] + SHIELD["t"] / 2.0) * k,
                                         (SHIELD["up"] + SHIELD["h"] / 2.0) * k))
    hit_wf = weapon_frame(rim + v3(0.0, 0.0, 0.084 * k), yaw=24.0, pitch=22.0, roll=-8.0)
    top_wf = weapon_frame(rim + v3(0.02 * k, -0.06 * k, 0.25 * k), yaw=18.0, pitch=52.0, roll=-4.0)
    first, last = hits[0], hits[-1]
    gap = min(hits[i + 1] - hits[i] for i in range(len(hits) - 1)) if len(hits) > 1 else 6

    def height(f: int) -> float:
        """0 = at the rim (impact), 1 = top of the chop."""
        best = 1.0
        for h in hits:
            d = f - h
            if -gap / 2.0 <= d <= 0:
                best = min(best, 1.0 - A.ease_in(1.0 + d / (gap / 2.0), 2.2))   # accelerating chop
            elif 0 < d <= gap / 2.0:
                best = min(best, A.ease_out(d / (gap / 2.0), 2.0))              # rebound
        return best

    def fn(f: int) -> Pose:
        t = f / FPS
        pose = shield_brace(sk, t, 0.0)
        aim = shield_pistol_frame(sk, 0.0, 0.0)
        u = height(f)
        chop = (A.mslerp(hit_wf[0], top_wf[0], u), A.lerp(hit_wf[1], top_wf[1], u))
        w = smooth(0.0, first - gap / 2.0, f) * (1.0 - smooth(last + 1.0, N, f))
        wf = (A.mslerp(aim[0], chop[0], w), A.lerp(aim[1], chop[1], w) + v3(0.10 * k, -0.03 * k, 0.06 * k) * math.sin(math.pi * w))
        hold_pistol(sk, pose, wf, one_hand=True)
        jolt = sum(pulse((f - h) / FPS, 0.5 / FPS, 4.0 / FPS) for h in hits if f >= h)
        hold_shield(sk, pose, shield_frame(sk, dz=-0.012 * jolt, dy=0.006 * jolt, pitch=-1.5 * jolt))
        add_rot(pose, "chest", rxd(-1.4 * jolt) @ rzd(-2.0 * w))
        look(pose, yaw=-4.0 * w, pitch=3.0 * w + 1.5 * jolt)
        pose.hip = pose.hip + v3(0.0, 0.0, -0.006 * k * jolt)
        return pose
    return fn


def _heal_ally(sk: Skeleton, solver: Solver, N: int, at: int) -> Keys:
    """Corpsman: drops into a lunge towards the ally in front, jabs an auto-injector with the left
    fist (``heal`` at frame ``at``), holds it for a beat and comes back up. The rifle hangs from the
    right hand pointing at the floor."""
    k = sk.scale

    def rifle_low(pose: Pose, dz: float = 0.0, lean: float = 0.0) -> None:
        wf = weapon_frame(v3(0.215 * k, 0.10 * k + 0.25 * k * lean, (0.99 + dz) * k), yaw=8.0, pitch=-62.0 + 20.0 * lean,
                          roll=-6.0)
        hold_weapon(sk, pose, wf, pole=v3(0.7, -0.3, -0.6), twist=0.6)
        pose.hands["R"] = hand_shape("trigger")

    up = _stand_key(sk)
    stand(sk, up, spread=0.03, stagger_l=0.06, stagger_r=-0.04, yaw_l=8, yaw_r=12)
    spine(up, lean=4, chest_lean=3, neck=(2, 0, 0), head=(4, 0, 0))
    rifle_low(up)
    arm_fk(sk, up, "L", add=32.0, swing=10.0, flex=40.0, twist=16.0)
    up.hands["L"] = hand_shape("fist", 0.8)

    def lunge(depth: float, reach: float, press: float) -> Pose:
        p = Pose()
        p.hip = v3(0.0, 0.07 * k * depth, -0.27 * k * depth - 0.02 * k)
        plant(sk, p, "L", (-0.03 * k, 0.30 * k * depth + 0.06 * k, 0.0), yaw=8.0)
        plant(sk, p, "R", (0.05 * k, -0.24 * k * depth - 0.04 * k, 0.010 * k * depth), yaw=-18.0, pitch=-40.0 * depth, toe=46.0 * depth,
              pivot="ball")
        spine(p, lean=18 * depth, chest_lean=8 * depth, twist=4 * depth, neck=(-6 * depth, 0, 0),
              head=(4 * depth + 6 * press, 0, -3), hips=(12 * depth, 0, 2))
        rifle_low(p, dz=-0.25 * depth, lean=depth)
        pre = Solver(sk).solve(p)
        sh = pre.P["upper_arm.L"]
        tgt = v3(-0.07 * k, sh[1] + (0.30 + 0.20 * reach + 0.07 * press) * k, sh[2] - (0.30 + 0.06 * reach + 0.05 * press) * k)
        hand_on(sk, p, "L", tgt, unit(v3(0.15, 0.55, -0.80 - 0.2 * press)), v3(0.95, 0.15, 0.1),
                pole=v3(-0.75, -0.1, -0.6), along_share=0.55, twist=0.5, clav=0.8)
        hs = hand_shape("fist", 0.95)
        hs.thumb = (hs.thumb[0], hs.thumb[1] + 14.0 * press, hs.thumb[2] + 20.0 * press)   # thumb on the plunger
        p.hands["L"] = hs
        return p

    keys = [(0, up, "inout"), (int(at * 0.62), lunge(0.85, 0.6, 0.0), "inout"), (at - 2, lunge(1.0, 1.0, 0.0), "out"),
            (at, lunge(1.0, 1.0, 1.0), "snap"), (at + 7, lunge(1.0, 0.9, 0.6), "inout"),
            (N, up.copy(), "inout")]
    return Keys(solver, keys)


def _kick_charge(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """Phantom windup (PhantomBrain: phantom_windup_s, motor stopped, facing the target): a tense
    rise, then a deep sprinter's coil with a quick step back, ending leaning into the sprint."""
    k = sk.scale
    a = idle_alert(sk, 0, 90)

    def fists(p: Pose, l_sw: float, r_sw: float, flex: float = 88.0) -> None:
        arm_fk(sk, p, "L", add=26.0, swing=l_sw, flex=flex, twist=18.0, clav_fwd=0.06 * l_sw)
        arm_fk(sk, p, "R", add=26.0, swing=r_sw, flex=flex, twist=18.0, clav_fwd=0.06 * r_sw)
        for s in ("L", "R"):
            p.hands[s] = hand_shape("fist", 0.9)

    rise = Pose()
    rise.hip = v3(0.0, -0.02 * k, -0.02 * k)
    stand(sk, rise, spread=0.045, stagger_l=0.07, stagger_r=-0.05, yaw_l=7, yaw_r=12)
    spine(rise, lean=-2, chest_lean=-4, neck=(-2, 0, 0), head=(-4, 0, 0), hips=(-1, 0, 0))
    fists(rise, 12.0, 8.0, 84.0)
    for s in ("L", "R"):
        rise.D[f"clavicle.{s}"] = ryd(-A.side_x(s) * 8.0)

    def coil(depth: float, fwd: float, heel: float) -> Pose:
        p = Pose()
        p.hip = v3(0.02 * k, (-0.05 + 0.17 * fwd) * k, (-0.13 * depth - 0.02) * k)
        plant(sk, p, "L", (0.0, 0.16 * k, 0.0), yaw=6.0)
        plant(sk, p, "R", (0.03 * k, -0.30 * k, 0.0002 * k * heel), yaw=-10.0, pitch=-heel, toe=1.15 * heel, pivot="ball")
        spine(p, lean=12 + 16 * fwd, chest_lean=8 + 8 * fwd, twist=-6 + 4 * fwd, chest_twist=-4,
              neck=(-14 - 8 * fwd, 0, 2), head=(-12 - 8 * fwd, 0, 3), hips=(10 + 8 * fwd, 0, -6))
        fists(p, 34.0 - 18.0 * fwd, -38.0 + 30.0 * fwd)
        return p

    def step_lift(f: int, pose: Pose) -> None:
        u = (f - 4) / 6.0
        if 0.0 < u < 1.0 and "R" in pose.legs:
            pose.legs["R"].ankle = pose.legs["R"].ankle + v3(0.0, 0.0, 0.06 * k * math.sin(math.pi * u))

    return Keys(solver, [(0, a, "inout"), (4, rise, "inout"), (10, coil(1.0, 0.0, 34.0), "heavy"),
                         (N, coil(0.85, 1.0, 52.0), "snap")], post=step_lift)


def _kick_hit(sk: Skeleton, solver: Solver, N: int, impact: int) -> Keys:
    """Phantom flying kick (PhantomBrain._kick, in range at the end of the sprint): take-off from the
    left foot, right knee chambered, the right leg shoots out sole-first at chest height (``impact``),
    re-chambers, lands staggered with a deep absorb and recovers to an alert crouch."""
    k = sk.scale

    def arms(p: Pose, l_sw: float, r_sw: float, l_out: float = 10.0, r_out: float = 10.0, flex: float = 80.0) -> None:
        arm_fk(sk, p, "L", add=24.0, swing=l_sw, out=l_out, flex=flex, twist=16.0)
        arm_fk(sk, p, "R", add=24.0, swing=r_sw, out=r_out, flex=flex, twist=16.0)
        for s in ("L", "R"):
            p.hands[s] = hand_shape("fist", 0.9)

    run = Pose()
    run.hip = v3(0.0, -0.02 * k, -0.08 * k)
    plant(sk, run, "L", (0.0, 0.20 * k, 0.0), yaw=6.0)
    plant(sk, run, "R", (0.02 * k, -0.30 * k, 0.009 * k), yaw=-8.0, pitch=-44.0, toe=50.0, pivot="ball")
    spine(run, lean=10, chest_lean=6, twist=4, neck=(-8, 0, 0), head=(-8, 0, -2), hips=(6, 0, 6))
    arms(run, -30.0, 36.0)

    take = Pose()
    take.hip = v3(0.0, 0.10 * k, -0.02 * k)
    plant(sk, take, "L", (0.0, 0.20 * k, 0.008 * k), yaw=6.0, pitch=-34.0, toe=39.0, pivot="ball")
    take.legs["R"] = A.LegIK(ankle=v3(0.11 * k, 0.32 * k, 0.52 * k), foot=rxd(-34.0), toe=0.0, pole=v3(0.1, 1.0, 0.7))
    spine(take, lean=-2, chest_lean=-2, neck=(2, 0, 0), head=(2, 0, 0), hips=(-6, 0, 4))
    arms(take, 46.0, -26.0, 14.0, 18.0, 70.0)

    def air(z: float, ext: float) -> Pose:
        p = Pose()
        p.hip = v3(0.0, (0.06 + 0.02 * ext) * k, z * k)
        hz = sk.head["thigh.R"][2] + z * k
        knee_ank = v3(0.11 * k, 0.34 * k, hz - 0.42 * k)
        out_ank = v3(0.09 * k, 0.93 * k, hz - 0.08 * k)
        p.legs["R"] = A.LegIK(ankle=A.lerp(knee_ank, out_ank, ext), foot=rxd(-30.0 + 105.0 * ext), toe=A.rad(-10.0 * ext),
                              pole=v3(0.1, 1.0 - 0.4 * ext, 0.8 + 0.6 * ext))
        p.legs["L"] = A.LegIK(ankle=v3(-0.10 * k, -0.14 * k, hz - 0.62 * k), foot=rxd(-40.0), toe=A.rad(20.0),
                              pole=v3(-0.1, 1.0, -0.1))
        spine(p, lean=-6 - 12 * ext, chest_lean=-2 - 4 * ext, side=2 * ext, neck=(6 + 6 * ext, 0, 0), head=(6 + 6 * ext, 0, -2),
              hips=(-8 - 10 * ext, 0, 8 * ext))
        arms(p, 30.0 + 20 * ext, -24.0 - 14 * ext, 18.0 + 10 * ext, 22.0 + 8 * ext, 60.0 - 20 * ext)
        return p

    land = Pose()
    land.hip = v3(0.01 * k, 0.07 * k, -0.20 * k)
    plant(sk, land, "R", (0.02 * k, 0.30 * k, 0.0), yaw=-8.0)
    plant(sk, land, "L", (-0.03 * k, -0.16 * k, 0.006 * k), yaw=12.0, pitch=-30.0, toe=34.0, pivot="ball")
    spine(land, lean=20, chest_lean=10, neck=(-10, 0, 0), head=(-8, 0, 0), hips=(12, 0, -4))
    arms(land, 20.0, 26.0, 26.0, 26.0, 60.0)

    rec = Pose()
    rec.hip = v3(0.0, 0.04 * k, -0.07 * k)
    plant(sk, rec, "R", (0.02 * k, 0.22 * k, 0.0), yaw=-8.0)
    plant(sk, rec, "L", (-0.03 * k, -0.10 * k, 0.0), yaw=14.0)
    spine(rec, lean=8, chest_lean=4, neck=(-2, 0, 0), head=(2, 0, 0), hips=(4, 0, -4))
    arms(rec, 16.0, 12.0, 6.0, 6.0, 52.0)
    for s in ("L", "R"):
        rec.hands[s] = hand_shape("loose_fist", 0.9)

    return Keys(solver, [(0, run, "inout"), (3, take, "out"), (impact, air(0.17, 1.0), "snap"),
                         (impact + 3, air(0.13, 0.15), "inout"), (impact + 6, land, "heavy"),
                         (impact + 9, land.copy(), "out"), (N, rec, "inout")])


def _dozer_upper(sk: Skeleton, pose: Pose, ph: float, f: int) -> None:
    """dozer_walk: a big gun held low across the hips, carried by the counter-swinging chest; each
    heel strike sends a small shudder up the trunk."""
    k = sk.scale
    shud = 0.0
    for strike in (0.0, 0.5):
        d = (ph - strike) % 1.0
        shud += pulse(d * 1.1, 0.02, 0.16)
    add_rot(pose, "spine", rxd(-1.6 * shud))
    add_rot(pose, "chest", rxd(-1.0 * shud))
    add_rot(pose, "head", rxd(1.6 * shud))
    pose.hip = pose.hip + v3(0.0, 0.0, -0.006 * k * shud)
    pre = Solver(sk).solve(pose)
    Wc = pre.W["chest"]
    o = A.bone_point(pre, sk, "chest", v3(0.12 * k, 0.12 * k, -0.17 * k))
    wf = (Wc @ rzd(12.0) @ rxd(-6.0), o)
    hold_weapon(sk, pose, wf, pole=v3(0.85, -0.25, -0.5), twist=0.6)
    pose.hands["R"] = hand_shape("trigger")
    rifle_support(sk, pose, wf, pole=v3(-0.7, -0.2, -0.7), at=RIFLE["left_ik"] + v3(0.0, -0.08, -0.005))


# =============================================================================================
# civilian / NPC ambient clips (heist casting: night_deposit, shadow_ledger): hand props
# =============================================================================================
# Props held by the NPC clips. Prop axes are Blender prop axes (X right, Y back = Godot +Z... i.e. the
# usual glTF mapping Godot (x, y, z) = Blender (x, z, -y)), metres at 1.78 m. A grip is either
# ``hand_on``-style (the palm point / finger direction / palm normal of the hand in prop space) or
# ``socket`` (the prop rides the weapon grip convention: prop axes = HandR/Socket axes, origin moved
# ``socket`` along the socket's up axis). ``prop_hand`` poses the hand from a prop frame, ``prop_frame``
# reads the prop back off a solved hand and ``prop_in_socket_godot`` documents it relative to HandR/Socket.
#   phone: 0.072 x 0.009 x 0.147 slab, origin at its centre, Z = up (speaker end), the screen faces -Y.
#   mug: origin at the base centre, Z = up (the mug axis), r 0.041, h 0.095, handle on -X.
#   mop: string mop; origin at the floor end of the shaft (the head's centre on the floor), Z = up the
#        shaft, X = the hand-back side; the right fist at MOP_GRIP_R, the left at MOP_GRIP_L up the shaft.
#   book: an open book 0.30 x 0.022 x 0.23, origin at its centre, Z = up (top edge), the pages face -Y.
#   P5 (D3-02, _anim_p5): rag: a folded bar towel 0.20 x 0.13 x 0.022, origin at the centre of its underside, Z = up.
#   bottle: origin at the base centre, Z = up the axis (mouth at 0.30), r 0.04; held from its +X side.
#   glass: a tumbler, origin at the base centre, Z = up, r 0.04, h 0.10; held in the LEFT hand from its -X side.
#   cash: a banknote stack 0.156 x 0.066 x 0.015 (X = the long edge), origin at its centre, Z = the face normal;
#        held in the LEFT palm (palm on the -Z face, fingers along +X).
#   D-115 cigarette: r CIG_R, CIG_LEN long (filter CIG_FILTER), origin at the filter (mouth) end, Z = toward the
#        ember; clamped between the right index and middle fingers (a ``fingers`` grip, measured off CIG_HAND),
#        the filter out on the palm side, Y = along the fingers, X = Y x Z.
PROPS = {"phone": (0.072, 0.009, 0.147), "mug": (0.082, 0.082, 0.095), "book": (0.30, 0.022, 0.23),
         "rag": (0.20, 0.13, 0.022), "bottle": (0.08, 0.08, 0.30), "glass": (0.08, 0.08, 0.10),
         "cash": (0.156, 0.066, 0.015), "cigarette": (0.0084, 0.0084, 0.072)}
CIG_R = 0.0042
CIG_LEN = 0.072
CIG_FILTER = 0.024
#: the filter tip sits this far out of the finger gap on the palm side (m at 1.78 m)
CIG_OUT_PALM = 0.032
#: share of the proximal phalanges (index_01 / middle_01) at which the cigarette crosses the finger gap
CIG_AT = 0.75
#: the smoking hand: index and middle nearly straight (the cigarette between them), ring and pinky curled
CIG_HAND = A.HandShape(curl={"index": (14.0, 16.0, 8.0), "middle": (16.0, 18.0, 8.0), "ring": (48.0, 58.0, 30.0),
                             "pinky": (56.0, 64.0, 32.0)}, thumb=(6.0, 10.0, 8.0), thumb_opp=18.0, spread=-2.0)
MOP_GRIP_R = 0.95
MOP_GRIP_L = 1.25
MOP_LENGTH = 1.40
#: mop sweep: head (x centre, x amplitude, y, y amplitude at the sweep ends), top hand aim (x, x amplitude, y, z)
MOP_HEAD = (0.10, 0.32, 0.62, 0.06)
MOP_TOP = (0.03, 0.07, 0.26, 1.06)
GRIPS = {
    "phone": {"sfx": "R", "point": v3(0.006, 0.0045, -0.022), "along": v3(-0.40, 0.0, 1.0), "palm": v3(0.0, -1.0, 0.0),
              "share": 0.5, "palm_off": 0.014, "shape": ("phone", 1.0)},
    "mug": {"sfx": "R", "point": v3(0.044, 0.0, 0.052), "along": v3(0.0, 1.0, 0.0), "palm": v3(-1.0, 0.0, 0.0),
            "share": 0.55, "palm_off": 0.014, "shape": ("grip", 0.55)},
    "book": {"sfx": "R", "point": v3(0.105, 0.011, -0.045), "along": v3(-0.30, 0.0, 1.0), "palm": v3(0.0, -1.0, 0.0),
             "share": 0.5, "palm_off": 0.013, "shape": ("support", 0.55)},
    "mop": {"sfx": "R", "socket": MOP_GRIP_R, "shape": ("grip", 1.0)},
    # P5 (D3-02)
    "rag": {"sfx": "R", "point": v3(0.0, 0.0, 0.022), "along": v3(0.0, 1.0, 0.0), "palm": v3(0.0, 0.0, -1.0),
            "share": 0.45, "palm_off": 0.012, "shape": ("rest_flat", 1.0)},
    "bottle": {"sfx": "R", "point": v3(0.043, 0.0, 0.15), "along": v3(0.0, 1.0, 0.0), "palm": v3(-1.0, 0.0, 0.0),
               "share": 0.55, "palm_off": 0.014, "shape": ("grip", 0.6)},
    "glass": {"sfx": "L", "point": v3(-0.043, 0.0, 0.048), "along": v3(0.0, 1.0, 0.0), "palm": v3(1.0, 0.0, 0.0),
              "share": 0.55, "palm_off": 0.014, "shape": ("grip", 0.55)},
    "cash": {"sfx": "L", "point": v3(0.0, 0.0, -0.0075), "along": v3(1.0, 0.0, 0.0), "palm": v3(0.0, 0.0, 1.0),
             "share": 0.5, "palm_off": 0.012, "shape": ("support", 0.6)},
    # D-115: between the index and middle fingers of CIG_HAND (the frame comes off the finger bones: cig_grip_bone)
    "cigarette": {"sfx": "R", "fingers": ("index_01", "middle_01"), "shape": ("cig", 1.0)},
}
#: The left hand on the book's left half (book space, like GRIPS).
BOOK_LEFT = {"point": v3(-0.105, 0.011, -0.045), "along": v3(0.30, 0.0, 1.0), "palm": v3(0.0, -1.0, 0.0)}
# seated furniture (shared with sit_chair / desk_type): seat 0.47 m, desk top 0.74 m, keys 0.36 m ahead
SEAT_H = 0.47
DESK_Z = 0.74


def grip_bone(sk: Skeleton, name: str) -> tuple[np.ndarray, np.ndarray]:
    """(R, t): the prop's axes (columns) and origin in ``hand.<sfx>`` bone-local coordinates."""
    g = GRIPS[name]
    k = sk.scale
    hb = f"hand.{g['sfx']}"
    if "socket" in g:
        R_off, t_off = A.grip_offset(sk, g["sfx"])
        return R_off.copy(), t_off + R_off @ v3(0.0, 0.0, -g["socket"] * k)
    if "fingers" in g:
        return cig_grip_bone(sk, g["sfx"], g["fingers"])
    Dw = A.hand_rot(sk, g["sfx"], unit(g["along"]), unit(g["palm"]))
    Ah = Dw @ sk.B[hb]
    local_pt = v3(0.0, g["share"] * sk.length(hb), -g["palm_off"] * k)
    wrist = g["point"] * k - Ah @ local_pt
    return Ah.T.copy(), -Ah.T @ wrist


def prop_hand(sk: Skeleton, pose: Pose, name: str, R: np.ndarray, o: np.ndarray, pole, twist: float = 0.5,
              clav: float = 1.0, shape: tuple | None = None) -> None:
    """Hand IK so that prop ``name`` (held per ``GRIPS``) sits at the world frame (R, o)."""
    g = GRIPS[name]
    k = sk.scale
    if "socket" in g:
        A.hold_weapon(sk, pose, (R, o + R @ v3(0.0, 0.0, g["socket"] * k)), pole, sfx=g["sfx"], twist=twist, clav=clav)
    elif "fingers" in g:
        hb = f"hand.{g['sfx']}"
        Rb, tb = grip_bone(sk, name)
        Ah = R @ Rb.T
        A.arm_ik_rot(pose, g["sfx"], o - Ah @ tb, Ah @ sk.B[hb].T, unit(np.asarray(pole, float)), twist=twist, clav=clav)
    else:
        hand_on(sk, pose, g["sfx"], o + R @ (g["point"] * k), R @ unit(g["along"]), R @ unit(g["palm"]), pole,
                along_share=g["share"], palm_off=g["palm_off"], twist=twist, clav=clav)
    kind, amt = shape or g["shape"]
    pose.hands[g["sfx"]] = CIG_HAND if kind == "cig" else hand_shape(kind, amt)


_CIG_GRIPS: dict[tuple, tuple[np.ndarray, np.ndarray]] = {}


def cig_grip_bone(sk: Skeleton, sfx: str, fingers: tuple[str, str]) -> tuple[np.ndarray, np.ndarray]:
    """(R, t) of the cigarette in ``hand.<sfx>`` bone-local coordinates: it crosses the gap between the two
    fingers' proximal phalanges (CIG_AT along them, CIG_HAND curls) at right angles to them, the filter tip
    CIG_OUT_PALM out on the palm side (bone-local -Z), Z toward the ember, Y along the fingers."""
    key = (round(sk.scale, 6), sfx, fingers)
    if key not in _CIG_GRIPS:
        pose = neutral(sk)
        pose.hands[sfx] = CIG_HAND
        s = Solver(sk).solve(pose)
        hb = f"hand.{sfx}"
        Ah = s.W[hb] @ sk.B[hb]
        pts, dirs = [], []
        for f in fingers:
            b = f"{f}.{sfx}"
            head = s.P[b]
            tail = head + s.W[b] @ (sk.tail[b] - sk.head[b])
            pts.append(Ah.T @ (head + CIG_AT * (tail - head) - s.P[hb]))
            dirs.append(Ah.T @ unit(tail - head))
        side = unit(pts[1] - pts[0])
        along = unit(dirs[0] + dirs[1])
        along = unit(along - side * float(side @ along))
        z = unit(np.cross(side, along))
        if z[2] < 0.0:      # toward the back of the hand (bone-local +Z)
            z = -z
        x = unit(np.cross(along, z))
        centre = 0.5 * (pts[0] + pts[1])
        _CIG_GRIPS[key] = (np.column_stack([x, along, z]), centre - z * (CIG_OUT_PALM * sk.scale))
    R, t = _CIG_GRIPS[key]
    return R.copy(), t.copy()


def prop_frame(sk: Skeleton, s, name: str) -> tuple[np.ndarray, np.ndarray]:
    """The prop's world frame as carried by the solved hand (what the game shows)."""
    g = GRIPS[name]
    hb = f"hand.{g['sfx']}"
    Rb, tb = grip_bone(sk, name)
    Ah = s.W[hb] @ sk.B[hb]
    return Ah @ Rb, s.P[hb] + Ah @ tb


_B2G = np.array([[1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0]])


def prop_in_socket_godot(sk: Skeleton, name: str) -> tuple[tuple, tuple]:
    """The prop's Transform3D relative to HandR/Socket in Godot axes: (basis columns x, y, z), origin."""
    g = GRIPS[name]
    R_off, t_off = A.grip_offset(sk, g["sfx"])
    Rb, tb = grip_bone(sk, name)
    M = _B2G @ (R_off.T @ Rb) @ _B2G.T
    t = _B2G @ (R_off.T @ (tb - t_off))
    return tuple(tuple(float(x) for x in M[:, i]) for i in range(3)), tuple(float(x) for x in t)


def level_frame(yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> np.ndarray:
    """Prop rotation: yaw (deg, + left), then pitch (+ = top tips toward -Y, i.e. back toward the body for a
    prop in front), then roll."""
    return rzd(yaw) @ rxd(pitch) @ ryd(roll)


def facing_frame(o: np.ndarray, eye: np.ndarray) -> np.ndarray:
    """A prop frame whose -Y faces ``eye`` and whose Z is as close to world up as possible."""
    y = unit(o - eye)
    z = unit(v3(0.0, 0.0, 1.0) - y * float(y[2]))
    x = np.cross(y, z)
    return np.column_stack([x, y, z])


def windows(t: float, T: float, spans: list[tuple[float, float]], blend: float) -> list[float]:
    """Cyclic schedule weights: one weight per (start, end) span (seconds, may wrap past T), smoothstep
    edges ``blend`` s wide, normalised to sum 1 (gaps go to the nearest spans)."""
    out = []
    for a, b in spans:
        w = 0.0
        for sh in (-T, 0.0, T):
            x = t + sh
            w = max(w, smooth(a - blend / 2, a + blend / 2, x) * (1.0 - smooth(b - blend / 2, b + blend / 2, x)))
        out.append(w)
    s = sum(out)
    if s < 1e-6:
        return [1.0 / len(out)] * len(out)
    return [w / s for w in out]


def blend_hand(specs: list[tuple], weights: list[float]) -> tuple:
    """Weighted blend of (point, along, palm) hand goals."""
    p = sum(w * s[0] for s, w in zip(specs, weights))
    al = unit(sum(w * unit(s[1]) for s, w in zip(specs, weights)))
    pa = sum(w * unit(s[2]) for s, w in zip(specs, weights))
    pa = unit(pa - al * float(pa @ al))
    return p, al, pa


def track(keys: list[tuple], u: float):
    """Piecewise eased interpolation of ``(u, value)`` keys (u in 0..1 ascending; values arrays/floats)."""
    if u <= keys[0][0]:
        return keys[0][1]
    for (u0, a), (u1, b) in zip(keys, keys[1:]):
        if u <= u1:
            return A.lerp(a, b, cos_ease((u - u0) / max(u1 - u0, 1e-9)))
    return keys[-1][1]


def head_eye(pre, sk: Skeleton) -> np.ndarray:
    k = sk.scale
    return A.bone_point(pre, sk, "head", v3(0.0, 0.085 * k, 0.075 * k))


def phone_at_ear(sk: Skeleton, pre) -> tuple[np.ndarray, np.ndarray]:
    """The phone at the right ear (speaker on the ear, mic toward the mouth, screen on the cheek), carried
    by the solved head."""
    k = sk.scale
    Wh = pre.W["head"]
    R = Wh @ np.column_stack([v3(0.0, -0.8, -0.6), v3(1.0, 0.0, 0.0), v3(0.0, -0.6, 0.8)])
    o = A.bone_point(pre, sk, "head", v3(0.0865 * k, 0.040 * k, -0.012 * k))
    return R, o


# ---------------------------------------------------------------------------------------------
# seated
# ---------------------------------------------------------------------------------------------
def desk_work(sk: Skeleton, f: int, N: int) -> Pose:
    """Seated desk loop (12 s): typing, then mouse work (right hand on a mouse right of the keyboard),
    then leaning in to read papers on the left of the desk (left hand tracking the lines), back to typing.
    Desk top DESK_Z, keyboard 0.36 m ahead of the root, mouse at x 0.30, papers at x -0.22."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    w_type, w_mouse, w_read = windows(t, T, [(-0.6, 3.9), (3.9, 7.0), (7.0, 11.4)], 0.7)
    pose = Pose()
    seated(sk, pose, recline=-6.0 - 8.0 * w_read)
    add_rot(pose, "chest", rxd(-4.0 * w_read) @ rzd(-5.0 * w_mouse + 6.0 * w_read))
    scan = math.sin(TAU * 3 * t / T)
    look(pose, yaw=4.0 * math.sin(TAU * t / T) * w_type - 6.0 * w_mouse + 14.0 * w_read + 3.0 * scan * w_mouse,
         pitch=12.0 * (w_type + w_mouse) + (30.0 + 4.0 * math.sin(TAU * 0.5 * t)) * w_read)
    breathe(pose, t, T / 4.0, 0.7)
    keys_z = (DESK_Z + 0.025) * k
    for sfx, sx in A.SIDES:
        ph = 0.0 if sfx == "R" else 0.31
        tap = max(0.0, math.sin(TAU * (4.0 * t + ph)))
        drift = math.sin(TAU * (1.0 * t + ph))
        typing = (v3(sx * 0.14 * k + 0.02 * k * drift, 0.36 * k, keys_z + 0.012 * k * tap),
                  v3(-sx * 0.25, 0.95, -0.15), v3(-sx * 0.1, 0.1, -1.0))
        if sfx == "R":
            mv = (0.025 * k * math.sin(TAU * 1.3 * t), 0.018 * k * math.sin(TAU * 0.9 * t + 1.0))
            mouse = (v3(0.27 * k + mv[0], 0.33 * k + mv[1], (DESK_Z + 0.030) * k), v3(0.05, 1.0, -0.25),
                     v3(0.0, 0.15, -1.0))
            rest = (v3(0.02 * k, 0.33 * k, (DESK_Z + 0.022) * k), v3(-0.6, 0.8, -0.1), v3(-0.25, 0.1, -1.0))
            p, al, pa = blend_hand([typing, mouse, rest], [w_type, w_mouse, w_read])
            pole = v3(0.9, -0.4, -0.4)
        else:
            line = 0.5 - 0.5 * math.cos(TAU * 3.0 * t / T)
            paper = (v3(-0.14 * k + 0.03 * k * math.sin(TAU * 13.0 * t / T), 0.355 * k - 0.05 * k * line, (DESK_Z + 0.020) * k),
                     v3(0.45, 0.85, -0.2), v3(0.1, 0.1, -1.0))
            idle_kb = (v3(-0.15 * k, 0.33 * k, keys_z - 0.005 * k), v3(0.3, 0.95, -0.15), v3(0.1, 0.1, -1.0))
            p, al, pa = blend_hand([typing, idle_kb, paper], [w_type, w_mouse, w_read])
            pole = v3(-1.0, -0.4, -0.4)
        hand_on(sk, pose, sfx, p, al, pa, pole=pole, along_share=0.5)
        hs = hand_shape("relaxed", 1.0)
        if w_type > 0.0:
            hs.curl["index"] = (10 + 18 * tap * w_type, 22, 10)
            hs.curl["middle"] = (14 + 14 * (1 - tap) * w_type, 26, 12)
        if sfx == "R" and w_mouse > 0.0:
            click = pulse((t - 4.6) % 1.1, 0.05, 0.15) * w_mouse
            hs.curl["index"] = (8 + 14 * click, 14, 6)
        if sfx == "L" and w_read > 0.0:
            hs = hs.blend(hand_shape("flat", 0.6), w_read)
        pose.hands[sfx] = hs
    return pose


def _phone_left_arm(sk: Skeleton, pose: Pose, t: float, T: float, seated_desk: bool) -> None:
    """Free (left) hand while on the phone: seated, it writes on a pad on the desk, then gestures."""
    k = sk.scale
    w_write, w_gest = windows(t, T, [(-0.4, 3.6), (3.6, 7.6)], 0.9)
    gest = smooth(0.0, 1.0, 0.5 + 0.5 * math.sin(TAU * 11.0 * t / T)) * w_gest
    scrib = v3(0.010 * k * math.sin(TAU * 25.0 * t / T), 0.006 * k * math.sin(TAU * 14.0 * t / T + 0.4), 0.0)
    pad = (v3(-0.10 * k, 0.38 * k, (DESK_Z + 0.018) * k) + scrib, v3(0.55, 0.8, -0.3), v3(0.25, 0.0, -1.0))
    air = (v3(-0.21 * k + 0.03 * k * gest, 0.22 * k + 0.05 * k * gest, 0.86 * k + 0.07 * k * gest), v3(0.35, 0.9, 0.15 + 0.3 * gest),
           v3(0.5, 0.0, 0.85))
    p, al, pa = blend_hand([pad, air], [w_write, w_gest])
    hand_on(sk, pose, "L", p, al, pa, pole=v3(-1.0, -0.4, -0.5), along_share=0.5)
    pose.hands["L"] = hand_shape("pinch", 1.0).blend(hand_shape("relaxed", 1.0 - 0.6 * gest), w_gest)


def phone_seated(sk: Skeleton, f: int, N: int) -> Pose:
    """Seated phone call (sit_chair/desk_type seat): the phone at the right ear (GRIPS["phone"], the same
    grip as phone_call), the left hand takes notes on a pad on the desk, then gestures; head tilted into
    the phone, small nods."""
    t = f / FPS
    T = N / FPS
    pose = Pose()
    seated(sk, pose, recline=2.0)
    add_rot(pose, "chest", ryd(2.0))
    w_write, _w = windows(t, T, [(-0.4, 3.6), (3.6, 7.6)], 0.9)
    look(pose, yaw=-6.0 + 6.0 * w_write, pitch=6.0 + 18.0 * w_write + 3.0 * math.sin(TAU * 3 * t / T), tilt=9.0)
    breathe(pose, t, T / 3.0, 0.8)
    pre = Solver(sk).solve(pose)
    R, o = phone_at_ear(sk, pre)
    prop_hand(sk, pose, "phone", R, o, pole=v3(0.6, -0.1, -1.0), twist=0.5)
    _phone_left_arm(sk, pose, t, T, True)
    return pose


def sit_chair_watch(sk: Skeleton, f: int, N: int) -> Pose:
    """Camera operator at the monitor wall: seated, leaning in, the right hand on a mouse/joystick on the
    console (DESK_Z), the left forearm on the console edge; the head moves between screens and dwells."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    seated(sk, pose, recline=-13.0)
    # screens: (start s, end s, yaw, pitch): centre, left, centre-high, right, centre
    shots = [(0.0, 2.4, 0.0, 4.0), (2.4, 4.4, 24.0, 2.0), (4.4, 6.0, 4.0, -8.0), (6.0, 8.6, -22.0, 3.0),
             (8.6, 10.0, -4.0, 6.0)]
    ws = windows(t, T, [(a, b) for a, b, _y, _p in shots], 0.45)
    yaw = sum(w * s[2] for w, s in zip(ws, shots))
    pitch = sum(w * s[3] for w, s in zip(ws, shots))
    add_rot(pose, "chest", rzd(0.25 * yaw))
    look(pose, yaw=0.75 * yaw, pitch=pitch + 1.0 * math.sin(TAU * 0.7 * t))
    breathe(pose, t, T / 3.0, 0.8)
    stick = v3(0.012 * k * math.sin(TAU * 0.8 * t) + 0.008 * k * math.sin(TAU * 2.1 * t), 0.010 * k * math.sin(TAU * 0.6 * t + 1.0), 0.0)
    hand_on(sk, pose, "R", v3(0.21 * k, 0.335 * k, (DESK_Z + 0.036) * k) + stick, v3(0.0, 0.95, -0.3), v3(-0.2, 0.2, -1.0),
            pole=v3(0.9, -0.4, -0.4), along_share=0.55)
    hs = hand_shape("grip", 0.55)
    click = pulse((t - 1.3) % 3.3, 0.06, 0.18)
    hs.curl["index"] = (16 + 18 * click, 20, 8)
    pose.hands["R"] = hs
    hand_on(sk, pose, "L", v3(-0.18 * k, 0.33 * k, (DESK_Z + 0.022) * k), v3(0.55, 0.85, -0.1), v3(0.15, 0.1, -1.0),
            pole=v3(-1.0, -0.3, -0.5), along_share=0.5)
    pose.hands["L"] = hand_shape("relaxed", 1.1)
    return pose


# ---------------------------------------------------------------------------------------------
# standing with a prop
# ---------------------------------------------------------------------------------------------
def _mug_lip_frame(sk: Skeleton, pre, tilt: float) -> tuple[np.ndarray, np.ndarray]:
    """The mug at the lips, tipped ``tilt`` deg toward the face, its near rim on the lower lip."""
    k = sk.scale
    yaw_h = math.degrees(math.atan2(-float((pre.W["head"] @ v3(0, 1, 0))[0]), float((pre.W["head"] @ v3(0, 1, 0))[1])))
    R = level_frame(yaw=yaw_h, pitch=tilt)
    lip = A.bone_point(pre, sk, "head", v3(0.0, 0.112 * k, -0.050 * k))
    rim = v3(0.0, -0.041 * k, 0.095 * k)
    return R, lip - R @ rim + v3(0.0, 0.004 * k, 0.0)


def mug_idle(sk: Skeleton, f: int, N: int) -> Pose:
    """Standing with a mug in the right hand at the waist/chest, level; one sip per loop (raise, sip at
    ``sip``, lower). The left hand hangs relaxed."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = idle(sk, f, N)
    s0, s1, s2, s3 = 2.6, 3.5, 4.6, 5.5            # raise start, at the lips, leave the lips, lowered
    up = smooth(s0, s1, t) * (1.0 - smooth(s2, s3, t))
    sip = smooth(s1 - 0.1, s1 + 0.3, t) * (1.0 - smooth(s2 - 0.3, s2 + 0.1, t))
    look(pose, pitch=-6.0 * sip - 4.0 * up + 6.0 * (1 - up))
    add_rot(pose, "chest", rxd(-1.5 * sip))
    pre = Solver(sk).solve(pose)
    hold_o = A.bone_point(pre, sk, "spine", v3(0.12 * k, 0.29 * k, 0.03 * k + 0.004 * k * math.sin(TAU * t / T)))
    hold_R = level_frame(yaw=12.0)
    lip_R, lip_o = _mug_lip_frame(sk, pre, 32.0 + 10.0 * sip)
    R = A.mslerp(hold_R, lip_R, up)
    o = A.lerp(hold_o, lip_o, up) + v3(0.0, 0.05 * k, 0.0) * math.sin(math.pi * up)
    prop_hand(sk, pose, "mug", R, o, pole=v3(0.7, -0.5, -0.6))
    return pose


def _mug_upper(sk: Skeleton, pose: Pose, ph: float, f: int) -> None:
    """mug_carry_walk: the right hand carries the mug in front of the chest, the elbow bent ~95 deg; the
    mug stays level and rides only half of the trunk bob (a careful carry)."""
    k = sk.scale
    pre = Solver(sk).solve(pose)
    o = A.bone_point(pre, sk, "chest", v3(0.10 * k, 0.30 * k, -0.06 * k))
    o[2] = 0.5 * o[2] + 0.5 * 1.15 * k
    prop_hand(sk, pose, "mug", level_frame(yaw=10.0), o, pole=v3(0.75, -0.5, -0.5), twist=0.5)


def mop(sk: Skeleton, f: int, N: int) -> Pose:
    """Cleaner mopping in place: wide planted stance, the string mop swept side to side in front (two
    sweeps per loop), both fists on the shaft (right lower at MOP_GRIP_R = HandR/Socket, left at the
    top, MOP_GRIP_L), the trunk turning with the sweep, eyes on the floor."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    w = TAU * 2.0 * t / T
    sw = math.sin(w)
    pose = neutral(sk)
    pose.hip = v3(0.018 * k * math.sin(w - 0.5), -0.03 * k, -0.045 * k - 0.006 * k * math.cos(2 * w))
    stand(sk, pose, spread=0.07, stagger_l=0.12, stagger_r=-0.10, yaw_l=10, yaw_r=18)
    spine(pose, lean=11.0, chest_lean=6.0 + 1.5 * math.cos(2 * w), twist=-7.0 * sw, chest_twist=-9.0 * sw, side=-1.5 * sw,
          hips=(4.0, 1.2 * sw, -3.0 * sw))
    look(pose, yaw=10.0 * sw, pitch=26.0 + 3.0 * math.cos(2 * w))
    breathe(pose, t, T / 2.0, 0.8)
    hx, hamp, hy, hyamp = MOP_HEAD
    tx, tamp, ty, tz = MOP_TOP
    head = v3((hx + hamp * sw) * k, (hy + hyamp * math.cos(2 * w)) * k, 0.0)
    top = v3((tx + tamp * math.sin(w - 0.25)) * k, (ty + 0.015 * math.cos(2 * w)) * k, tz * k)
    u = unit(top - head)
    fwd = unit(v3(-0.25 * sw, 1.0, 0.0))
    y = unit(fwd - u * float(fwd @ u))
    R = np.column_stack([np.cross(y, u), y, u])
    prop_hand(sk, pose, "mop", R, head, pole=v3(0.7, -0.6, -0.4))
    A.hold_weapon(sk, pose, (R, head + u * MOP_GRIP_L * k), v3(-0.7, -0.5, -0.5), sfx="L")
    pose.hands["L"] = hand_shape("grip", 1.0)
    return pose


# ---------------------------------------------------------------------------------------------
# reading in bed
# ---------------------------------------------------------------------------------------------
#: sit_bed_read: the root is ON THE MATTRESS TOP (the clip's z = 0 is the sleeping surface under the
#: buttocks and heels); the back reclines on pillows/headboard behind the root.
BED_RECLINE = 30.0
BED_PAGE = (6.3, 8.3)          # page turn span (s); the event (u = 0.54) is where the page passes the spine


def sit_bed_read(sk: Skeleton, f: int, N: int) -> Pose:
    """Kessler reading in bed, propped up on pillows: legs out on the mattress, the trunk reclined
    ~BED_RECLINE deg, an open book in both hands (GRIPS["book"] = HandR/Socket; the left hand on the
    left cover). Once per loop the left hand turns a page (event ``page_turn``)."""
    return _reading(sk, f, N, chair=False)


def sit_chair_read(sk: Skeleton, f: int, N: int) -> Pose:
    """D-116: Kessler reading in the bedside armchair (shadow_ledger.md: the spawn on the armchair's Seat, played like
    sit_chair): seated upright, leaning back a little, the open book held over the lap in both hands, the same page turn
    as sit_bed_read (event ``page_turn``)."""
    return _reading(sk, f, N, chair=True)


#: sit_chair_read: the book's centre from the chest (chest-bone offset, m at 1.78 m) and the extra head pitch (deg)
CHAIR_BOOK = v3(0.0, 0.30, -0.12)
CHAIR_READ_HEAD = 20.0
#: the book raised this far (world up, m at 1.78 m) off the chest offset and its top edge tipped this far (deg)
#: further toward the face than square to the sight line, as (chair, bed): a reading angle, not flat in the lap; the
#: reclined bed read already holds it up at the chest, so it only rises clear of the chin
READ_RAISE = (0.10, 0.03)
READ_TILT = (34.0, 8.0)


def _reading(sk: Skeleton, f: int, N: int, chair: bool) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    hips_rest = sk.head["hips"]
    br = math.sin(TAU * 3 * t / T)
    if chair:
        seated(sk, pose, recline=10.0)
        A.add_rot(pose, "chest", rxd(0.8 * br))
        A.add_rot(pose, "neck", rxd(-0.5 * CHAIR_READ_HEAD))
        A.add_rot(pose, "head", rxd(-0.5 * CHAIR_READ_HEAD))
    else:
        pose.hip = v3(0.0, -0.02 * k, 0.11 * k - hips_rest[2])
        spine(pose, hips=(-86.0, 0, 0), lean=52.0, chest_lean=5.0 + 0.8 * br, neck=(14, 0, 0), head=(12, 0, 0))
        pose.legs["L"] = A.LegIK(ankle=v3(-0.115 * k, 0.835 * k, 0.035 * k), foot=rxd(62.0) @ rzd(16.0), toe=0.0,
                                 pole=v3(-0.25, 0.2, 1.0))
        pose.legs["R"] = A.LegIK(ankle=v3(0.13 * k, 0.76 * k, 0.045 * k), foot=rxd(58.0) @ rzd(-12.0), toe=0.0,
                                 pole=v3(0.35, 0.2, 1.0))
    u0, u1 = BED_PAGE
    turn = clamp((t - u0) / (u1 - u0)) if u0 <= t <= u1 else (1.0 if t > u1 else 0.0)
    # reading: the eyes go down the page, then back up to the top during the turn
    read = 1.0 - cos_ease(turn) if u0 <= t <= u1 else ((t - u1) % T) / (T - (u1 - u0))
    look(pose, yaw=-2.0 + 3.0 * math.sin(TAU * 10 * t / T) * (1.0 - math.sin(math.pi * turn)), pitch=-2.0 + 8.0 * read)
    pre = Solver(sk).solve(pose)
    eye = head_eye(pre, sk)
    off = CHAIR_BOOK if chair else v3(0.0, 0.38, 0.10)
    o = A.bone_point(pre, sk, "chest", off * k) + v3(0.0, 0.0, (READ_RAISE[0 if chair else 1] + 0.006 * br) * k)
    R = facing_frame(o, eye) @ rxd(READ_TILT[0 if chair else 1])
    prop_hand(sk, pose, "book", R, o, pole=v3(0.8, -0.2, -0.8))
    # left hand: hold -> page corner -> sweep across -> back to the cover
    # (u, point, along, palm) in book space; hand rotations are slerped between the keys
    keys = [(0.0, BOOK_LEFT["point"], BOOK_LEFT["along"], BOOK_LEFT["palm"]),
            (0.15, v3(-0.19, -0.02, -0.02), v3(0.2, -0.2, 1.0), v3(1.0, -0.3, 0.0)),
            (0.32, v3(0.125, -0.035, 0.085), v3(0.55, -0.2, 0.8), v3(0.0, 1.0, 0.0)),
            (0.40, v3(0.120, -0.040, 0.085), v3(0.55, -0.2, 0.8), v3(0.0, 1.0, 0.0)),
            (0.54, v3(0.0, -0.14, 0.10), v3(0.0, -0.3, 1.0), v3(0.0, 1.0, 0.3)),
            (0.68, v3(-0.125, -0.04, 0.085), v3(-0.35, -0.2, 0.9), v3(0.2, 1.0, 0.0)),
            (0.82, v3(-0.19, -0.02, -0.02), v3(0.2, -0.2, 1.0), v3(1.0, -0.3, 0.0)),
            (1.0, BOOK_LEFT["point"], BOOK_LEFT["along"], BOOK_LEFT["palm"])]
    p_ = BOOK_LEFT["point"]
    Q = A.hand_rot(sk, "L", unit(BOOK_LEFT["along"]), unit(BOOK_LEFT["palm"]))
    if 0.0 < turn < 1.0:
        for (ua, pa, aa, na), (ub, pb, ab, nb) in zip(keys, keys[1:]):
            if turn <= ub:
                e = cos_ease((turn - ua) / (ub - ua))
                p_ = A.lerp(pa, pb, e)
                Q = A.mslerp(A.hand_rot(sk, "L", unit(aa), unit(na)), A.hand_rot(sk, "L", unit(ab), unit(nb)), e)
                break
    pinch = smooth(0.24, 0.36, turn) * (1.0 - smooth(0.66, 0.76, turn))
    Dw = R @ Q
    share = (0.5 + 0.35 * pinch) * sk.length("hand.L")
    wrist = o + R @ (p_ * k) - (Dw @ sk.B["hand.L"]) @ v3(0.0, share, -0.013 * k)
    A.arm_ik_rot(pose, "L", wrist, Dw, unit(v3(-0.8, -0.3, -0.8)))
    pose.hands["L"] = hand_shape("support", 0.55).blend(hand_shape("pinch", 1.0), pinch)
    return pose




# ---------------------------------------------------------------------------------------------
# cartel gunmen
# ---------------------------------------------------------------------------------------------
THUG_MUZZLE_PITCH = -30.0      # muzzle below the horizontal (deg)
THUG_MUZZLE_YAW = 38.0         # muzzle turned across the body to the left (deg)


def idle_thug(sk: Skeleton, f: int, N: int) -> Pose:
    """Cartel gunman's hunched, menacing idle: shoulders rolled forward, head down and forward, weight on the
    back (right) foot; a long gun held low across the body at HandR/Socket (the rifle grip convention), muzzle
    THUG_MUZZLE_PITCH deg down and THUG_MUZZLE_YAW deg across to the left; the left hand loosely under the
    handguard. Slow weight shift, a glance left then right once per loop. Feet planted."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = neutral(sk)
    sw = math.sin(TAU * t / T)
    glance = math.sin(TAU * t / T + 0.8)
    look_w = smooth(0.25, 0.75, 0.5 + 0.5 * math.sin(TAU * 2 * t / T))
    pose.hip = v3((0.035 + 0.008 * sw) * k, -0.035 * k, -0.035 * k - 0.004 * k * abs(sw))
    stand(sk, pose, spread=0.06, stagger_l=0.10, stagger_r=-0.10, yaw_l=10, yaw_r=24)
    spine(pose, lean=7.0, chest_lean=10.0 + 1.0 * math.sin(TAU * 2 * t / T), side=-2.0, twist=-4.0, chest_twist=-3.0,
          neck=(16, 0, 0), head=(-6, 0, 0), hips=(2.0, 2.5 + 1.0 * sw, -6.0))
    look(pose, yaw=18.0 * glance * look_w, pitch=4.0 - 3.0 * look_w)
    for sfx, sx in A.SIDES:
        pose.D[f"clavicle.{sfx}"] = rzd(sx * 9.0) @ ryd(sx * 3.0)
    breathe(pose, t, T / 2.0, 1.1)
    o = v3(0.15 * k + 0.006 * k * sw, 0.17 * k, 0.93 * k + 0.004 * k * math.sin(TAU * 2 * t / T))
    wf = weapon_frame(o, yaw=THUG_MUZZLE_YAW + 2.0 * sw, pitch=THUG_MUZZLE_PITCH, roll=-12.0)
    hold_weapon(sk, pose, wf, pole=v3(0.8, -0.4, -0.5), twist=0.6, clav=0.6)
    pose.hands["R"] = hand_shape("trigger")
    rifle_support(sk, pose, wf, pole=v3(-0.7, -0.4, -0.6), at=RIFLE["left_ik"] + v3(0.0, -0.19, -0.035))
    pose.hands["L"] = hand_shape("grip", 0.6)
    return pose


# =============================================================================================
# rappel (QC-41: police descending a rope, facing the wall)
# =============================================================================================
RAPPEL_ROPE_D = 0.24           # the rope: vertical line x = 0, RAPPEL_ROPE_D m in front of the root (Blender +Y)
RAPPEL_WALL = 0.80             # wall face (where the balls of the feet brace), m in front of the root
RAPPEL_CONTACT = 4             # frames per hop with the feet on the wall (the body braked, world-still)
RAPPEL_GUIDE_Z = 1.72          # guide (left) fist on the rope at landing, m above the root
RAPPEL_BRAKE = (0.12, 0.07, 1.00)   # brake (right) fist at landing: (x right of, y behind the rope line, height): at the right hip
RAPPEL_HIPS_Z = 0.86           # hips joint at landing, m above the root (seated in the harness, legs to the wall)
RAPPEL_ANKLE = (0.17, 0.48)    # ankle at landing: (x out from the centre line, height above the root)


def rappel_offset(u: float, speed: float, N: int) -> float:
    """Vertical offset (m, at 1.78 m) of the whole body relative to the root at loop phase ``u``. The root
    descends linearly at ``speed``; while the feet are on the wall (the first RAPPEL_CONTACT frames) the body
    is braked (world-still), so it rises against the root at ``speed``; in flight it drops back (cos ease)."""
    tc = RAPPEL_CONTACT / N
    rise = speed * RAPPEL_CONTACT / FPS
    if u < tc:
        return speed * u * N / FPS
    return rise * (1.0 - A.cos_ease((u - tc) / (1.0 - tc)))


def rappel_factory(speed: float):
    def rappel(sk: Skeleton, f: int, N: int) -> Pose:
        """One hop per loop down a vertical rope, facing the wall. In place: ENV A moves the root down at
        ``speed`` (CLIPS) along the rope line. Frame 0 = the feet land on the wall (``land``); they stay
        world-still for RAPPEL_CONTACT frames while the legs absorb and push off, then the feet leave the wall,
        the body drops and the legs reach for the next landing. The left (guide) hand rides the rope high, the
        right (brake) hand holds it at the right hip and squeezes at the landing; slightly seated in the
        harness (pelvis tipped back, trunk leaning away from the wall), looking down over the right shoulder."""
        k = sk.scale
        t = f / FPS
        u = (f % N) / N
        tc = RAPPEL_CONTACT / N
        off = rappel_offset(u, speed, N) * k
        if u < tc:
            w = u / tc
            push = smooth(0.0, 1.0, w)                     # legs: absorb at landing -> extend for the push-off
            hy = 0.03 - 0.07 * push
            hz = -0.025 * math.sin(math.pi * w)
            away, tuck, brake = 0.0, 0.0, math.sin(math.pi * min(1.0, w * 1.4))
        else:
            w = (u - tc) / (1.0 - tc)
            hy = -0.04 - 0.015 * math.sin(math.pi * w) + 0.07 * A.cos_ease(w)
            hz = 0.0
            away = math.sin(math.pi * min(1.0, w * 1.15))  # feet off the wall, back by the landing
            tuck = math.sin(math.pi * w)
            brake = 0.0
        pose = Pose()
        hips_rest = sk.head["hips"]
        pose.hip = v3(0.0, hy * k, (RAPPEL_HIPS_Z + hz) * k - hips_rest[2] + off)
        spine(pose, lean=18.0 - 3.0 * tuck, chest_lean=5.0, side=1.5, hips=(-30.0 + 4.0 * tuck, 0.0, 0.0),
              neck=(6.0, 0.0, 0.0))
        look(pose, yaw=-32.0 + 6.0 * math.sin(TAU * u), pitch=28.0, tilt=4.0)
        breathe(pose, t, N / FPS / 2.0, 1.4)
        ax, az = RAPPEL_ANKLE
        for sfx, sx in A.SIDES:
            ank = v3(sx * ax * k, (RAPPEL_WALL - 0.12 - 0.16 * away) * k, (az + 0.06 * tuck) * k + off)
            pose.legs[sfx] = A.LegIK(ankle=ank, foot=A.foot_rot(yaw=-sx * 8.0, pitch=62.0 - 18.0 * away),
                                     toe=A.rad(-10.0 * (1.0 - away)), pole=unit(v3(sx * 0.35, 0.25, 1.0)))
        d = RAPPEL_ROPE_D * k
        # guide hand: fist on the rope (the rope through the fist like a pistol grip: weapon up = rope up)
        gz = RAPPEL_GUIDE_Z * k + off - 0.02 * k * tuck
        hold_weapon(sk, pose, weapon_frame(v3(0.0, d, gz), yaw=-28.0), pole=v3(-0.7, -0.2, -0.7), sfx="L",
                    twist=0.5, clav=0.8)
        pose.hands["L"] = hand_shape("grip", 0.9)
        bx, by, bz = RAPPEL_BRAKE
        o = v3(bx * k, d - (by + 0.015 * brake) * k, bz * k + off - 0.03 * k * brake)
        hold_weapon(sk, pose, weapon_frame(o, yaw=22.0), pole=v3(0.8, -0.5, -0.4), sfx="R", twist=0.6, clav=0.8)
        pose.hands["R"] = hand_shape("grip", 0.85 + 0.15 * brake)
        return pose
    return rappel


# =============================================================================================
# registry
# =============================================================================================
def clips(sk: Skeleton, table: dict) -> dict[str, Clip]:
    """Every clip of ``table`` (``anim_humanoid.CLIPS``) as a ``Clip``."""
    import _anim_p5 as p5  # noqa: PLC0415 - P5 NPC set (D3-02); imports this module

    solver = Solver(sk)
    G = gaits(table)
    G.update(p5.gaits(table))
    stationary = {
        "idle": idle, "idle_alert": idle_alert, "crouch_idle": crouch_idle, "aim_pistol": aim_pistol,
        "aim_rifle": aim_rifle, "cower": cower, "hands_up": hands_up, "lie_down": lie_down, "tied": tied,
        "kneel_cuffed": kneel_cuffed, "phone_call": phone_call, "pager_answer": pager_answer,
        "investigate_look": investigate_look, "downed": downed, "interact_low": interact("low"),
        "interact_mid": interact("mid"), "interact_high": interact("high"), "browse": browse, "desk_type": desk_type,
        "sit_chair": sit_chair, "smoke": smoke, "lean_wall": lean_wall, "tased": tased, "climb_ladder": climb_ladder,
        "shield_idle": shield_idle, "desk_work": desk_work, "phone_seated": phone_seated,
        "sit_chair_watch": sit_chair_watch, "mug_idle": mug_idle, "mop": mop, "sit_bed_read": sit_bed_read,
        "sit_chair_read": sit_chair_read,
        "idle_thug": idle_thug,
    }
    stationary.update(p5.STATIONARY)
    if "rappel" in table:
        stationary["rappel"] = rappel_factory(float(table["rappel"]["speed"]))
    floor = {"lie_down": 0, "tied": 0, "kneel_cuffed": 0, "downed": 0, "surrender": -14, "sit_bed_read": 0}
    import _anim_d304 as d304  # noqa: PLC0415 - D3-04 polish set; imports this module

    extra = {}
    if any(n in table for n in d304.NAMES):
        # the 8-way and start / stop sets derive from walk / run (and idle): take them from the full table when a
        # caller (review renders) passes a subset
        from anim_humanoid import CLIPS as FULL  # noqa: PLC0415

        extra = d304.clips(sk, solver, table, gaits(FULL), int(FULL["idle"]["frames"]))
    import _anim_assault as assault  # noqa: PLC0415 - PO6-17 assault-event set; imports this module

    extra.update(assault.clips(sk, solver, table))
    import _anim_hitzones as hitzones  # noqa: PLC0415 - D-116 hit-zone flinches; imports this module

    extra.update(hitzones.clips(sk, solver, table))
    import _anim_surrender as surr  # noqa: PLC0415 - D-116 surrender variants; imports this module

    extra.update(surr.clips(sk, solver, table))
    import _anim_civ_panic as civ  # noqa: PLC0415 - D-116 civilian panic variants; imports this module

    extra.update(civ.clips(sk, solver, table))
    import _anim_bank as bank  # noqa: PLC0415 - OF-D1 bank customers; imports this module

    extra.update(bank.clips(sk, solver, table))
    import _anim_rt as rt  # noqa: PLC0415 - RT-D1 Rolling Thunder; imports this module

    extra.update(rt.clips(sk, solver, table))
    import _anim_idle_var as idlev  # noqa: PLC0415 - D polish #2 idle_alert variety; imports this module

    extra.update(idlev.clips(sk, solver, table))
    import _anim_reverse as rev  # noqa: PLC0415 - characters v1.27 locomotion reversals; imports this module

    extra.update(rev.clips(sk, solver, table))
    import _anim_holds as holds  # noqa: PLC0415 - D-116 third-person weapon holds; imports this module

    extra.update(holds.clips(sk, solver, table))
    import _anim_crew3p as crew3p  # noqa: PLC0415 - D-116 crew akimbo / downed / cuffed states; imports this module

    extra.update(crew3p.clips(sk, solver, table))
    import _anim_police as police  # noqa: PLC0415 - D-116 police combat movement; imports this module

    extra.update(police.clips(sk, solver, table))
    import _anim_loco_holds as loco  # noqa: PLC0415 - D-116 frame-locked locomotion holds; imports this module

    out: dict[str, Clip] = {}
    for name, row in table.items():
        N, loop, speed = int(row["frames"]), bool(row["loop"]), float(row["speed"])
        ev = dict(row.get("events", {}))
        if name in loco.NAMES or name in loco.AIM_NAMES or name in loco.PORT_NAMES:
            continue
        if name in extra:
            out[name] = extra[name]
            continue
        if name in G:
            g = G[name]
            out[name] = Clip(name, N, loop, (lambda f, g=g: g.pose(sk, f)), speed, g, ev)
        elif name in stationary:
            fn = stationary[name]
            out[name] = Clip(name, N, loop, (lambda f, fn=fn, N=N: fn(sk, f, N)), speed, None, ev,
                             reach_fix=name in ("idle", "idle_alert", "crouch_idle", "aim_pistol", "aim_rifle",
                                                "investigate_look", "phone_call", "pager_answer", "smoke", "browse",
                                                "mug_idle", "mop", "idle_thug") + p5.REACH_FIX)
        elif name in ("fire_pistol", "fire_rifle"):
            out[name] = Clip(name, N, loop, _fire(sk, name == "fire_rifle", N), speed, None, ev)
        elif name == "shield_bang":
            hits = tuple(sorted(int(v) for e, v in ev.items() if e.startswith("bang")))
            out[name] = Clip(name, N, loop, _shield_bang(sk, N, hits), speed, None, ev, reach_fix=False)
        elif name in ("turn_l", "turn_r", "turn_l_45", "turn_r_45"):
            out[name] = Clip(name, N, loop, _turn(sk, N, 1.0 if name.startswith("turn_l") else -1.0,
                                                  45.0 if name.endswith("_45") else 90.0), speed, None, ev,
                             reach_fix=False)
        else:
            maker = {"reload_pistol": _reload_pistol, "reload_rifle": _reload_rifle,
                     "death_front": lambda s, so, n: _death(s, so, n, True),
                     "death_back": lambda s, so, n: _death(s, so, n, False), "hit_react": _hit_react,
                     "radio_call": _radio_call, "throw_bag": _throw_bag, "drill_place": _drill_place,
                     "surrender": _surrender, "melee": _melee, "kick_charge": _kick_charge,
                     "kick_hit": lambda s, so, n, ev=ev: _kick_hit(s, so, n, int(ev["impact"])),
                     "heal_ally": lambda s, so, n, ev=ev: _heal_ally(s, so, n, int(ev["heal"]))}[name]
            out[name] = Clip(name, N, loop, maker(sk, solver, N), speed, None, ev, reach_fix=False)
        if name in floor:
            out[name].floor = floor[name]
        elif name.startswith("death_"):
            out[name].floor = int(N * 0.62)
        if name.startswith("death_") or name in ("surrender", "cower", "interact_low", "throw_bag", "melee"):
            out[name].no_sink = True
    if any(n in table for n in loco.NAMES + loco.AIM_NAMES + loco.PORT_NAMES):
        # the layers take their base clips' frames: build any base a subset table (review renders) leaves out
        from anim_humanoid import CLIPS as FULL  # noqa: PLC0415

        missing = {src: FULL[src] for src in loco.GAITS.values() if src not in out}
        base = dict(out)
        if missing:
            base.update(clips(sk, missing))
        out.update(loco.clips(sk, solver, table, base))
    return out
