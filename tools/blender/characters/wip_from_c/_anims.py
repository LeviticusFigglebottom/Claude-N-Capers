"""Animation library "humanoid" (docs/contracts/characters.md), procedural, 30 fps, in place.

Every clip is a function of the frame number that builds a ``PoseSpec`` (see ``_pose.py``);
locomotion feet follow planted ground trajectories (stance foot moves backwards at exactly the
authored speed, heel strike / toe-off roll about heel and ball), solved with analytic leg IK, so
feet do not slide relative to the ground when the character moves at ``SPEEDS[name]``. Looping
clips are periodic (frame N == frame 0). One-shots blend between solved key poses.
"""

from __future__ import annotations

import math
from collections.abc import Callable

import numpy as np

import rig
from _pose import (I3, ArmIK, LegIK, PoseSpec, Skeleton, Solved, align, blend_solved, deg, rot, rx, ry, rz,
                   solve, unit, world_from_local)

FPS = 30
TAU = 2.0 * math.pi

# Authored ground speeds (m/s at scale 1.0) of the locomotion loops; multiply by the character
# scale (Skeleton3D.motion_scale) to get the in-game speed with zero foot sliding.
SPEEDS = {"walk": 1.4, "run": 3.5, "sprint": 5.6, "crouch_walk": 1.2, "strafe_l": 1.2, "strafe_r": 1.2,
          "walk_back": 1.2, "flee": 3.2, "carry_bag_walk": 1.3}


def smooth(e0: float, e1: float, x: float) -> float:
    if e1 == e0:
        return 1.0 if x >= e1 else 0.0
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def v3(x, y, z) -> np.ndarray:
    return np.array([x, y, z], dtype=np.float64)


# ------------------------------------------------------------------------------------------
# building blocks
# ------------------------------------------------------------------------------------------
def side_x(sfx: str) -> float:
    return -1.0 if sfx == "L" else 1.0


def arm_rest(sk: Skeleton, sfx: str) -> dict:
    fr = rig.arm_frame(side_x(sfx))
    return {k: np.array(v) for k, v in fr.items()}


def hand_rot(sk: Skeleton, sfx: str, a_dir, p_dir) -> np.ndarray:
    """World rotation delta that points the fingers along ``a_dir`` and the palm along ``p_dir``."""
    fr = arm_rest(sk, sfx)
    return align(fr["a"], fr["p"], np.asarray(a_dir, float), np.asarray(p_dir, float))


def arm_fk(sk: Skeleton, spec: PoseSpec, sfx: str, add: float = 40.0, swing: float = 0.0, flex: float = 12.0,
           clav_up: float = 0.0, clav_fwd: float = 0.0, wrist: float = 0.0, out: float = 0.0) -> None:
    """Hanging arm: adduct from the A-pose by ``add`` deg, swing forward ``swing`` deg, bend the
    elbow ``flex`` deg (forearm comes forward)."""
    sx = side_x(sfx)
    spec.D[f"clavicle.{sfx}"] = rz(-sx * deg(clav_fwd)) @ ry(-sx * deg(clav_up))
    spec.D[f"upper_arm.{sfx}"] = rx(deg(swing)) @ ry(sx * deg(add - out))
    fa = unit(sk.tail[f"forearm.{sfx}"] - sk.head[f"forearm.{sfx}"])
    hinge = unit(np.cross(fa, v3(0, 1, 0)))     # rotating about it brings the forearm forward
    spec.D[f"forearm.{sfx}"] = rot(hinge, deg(flex))
    spec.D[f"hand.{sfx}"] = rot(hinge, deg(wrist))


def legs_ik(sk: Skeleton, spec: PoseSpec, feet: dict) -> None:
    """``feet``: sfx -> (ankle target, foot rotation, toe bend, pole)."""
    for sfx, (ank, frot, toe, pole) in feet.items():
        spec.legs[sfx] = LegIK(ankle=ank, foot=frot, toe=toe, pole=pole)


def stand_feet(sk: Skeleton, spread: float = 0.0, stagger_l: float = 0.0, stagger_r: float = 0.0,
               yaw_l: float = 0.0, yaw_r: float = 0.0) -> dict:
    k = sk.scale
    out = {}
    for sfx, stag, yaw in (("L", stagger_l, yaw_l), ("R", stagger_r, yaw_r)):
        sx = side_x(sfx)
        ank = sk.head[f"foot.{sfx}"] + v3(sx * spread * k, stag * k, 0.0)
        out[sfx] = (ank, rz(-sx * deg(yaw)), 0.0, v3(sx * 0.12, 1.0, 0.0))
    return out


def curl(spec: PoseSpec, sfx: str, c: float, thumb: float | None = None, index: float | None = None) -> None:
    th = c * 0.8 if thumb is None else thumb
    ix = c if index is None else index
    spec.curl[sfx] = (th, ix, c, c * 1.05, c * 1.1)


def spine(spec: PoseSpec, lean: float = 0.0, side: float = 0.0, twist: float = 0.0, chest_lean: float = 0.0,
          chest_twist: float = 0.0, chest_side: float = 0.0, neck: tuple = (0, 0, 0), head: tuple = (0, 0, 0),
          hips: tuple = (0, 0, 0)) -> None:
    """Angles in degrees. lean > 0 bends forward. twist > 0 turns left. side > 0 bends right.
    ``hips``/``neck``/``head`` = (forward pitch, right roll, left yaw)."""
    spec.D["hips"] = rz(deg(hips[2])) @ ry(deg(hips[1])) @ rx(-deg(hips[0]))
    spec.D["spine"] = rz(deg(twist)) @ ry(deg(side)) @ rx(-deg(lean))
    spec.D["chest"] = rz(deg(chest_twist)) @ ry(deg(chest_side)) @ rx(-deg(chest_lean))
    spec.D["neck"] = rz(deg(neck[2])) @ ry(deg(neck[1])) @ rx(-deg(neck[0]))
    spec.D["head"] = rz(deg(head[2])) @ ry(deg(head[1])) @ rx(-deg(head[0]))


def default_spec(sk: Skeleton) -> PoseSpec:
    spec = PoseSpec()
    spec.hip = v3(0, 0, -0.012 * sk.scale)
    spine(spec)
    legs_ik(sk, spec, stand_feet(sk))
    for sfx in ("L", "R"):
        arm_fk(sk, spec, sfx)
        curl(spec, sfx, 0.3)
    return spec


def bone_frame(sol: Solved, sk: Skeleton, b: str) -> tuple[np.ndarray, np.ndarray]:
    """(world rotation, world head position) of bone b in a solved pose (rest-relative axes)."""
    return sol.W[b], sol.P[b]


def at_bone(sol: Solved, sk: Skeleton, b: str, offset) -> np.ndarray:
    """World point at ``offset`` (rest-world axes, relative to the bone head) moved with bone b."""
    return sol.W[b] @ np.asarray(offset, float) + sol.P[b]


def arm_to(sk: Skeleton, spec: PoseSpec, sfx: str, wrist, a_dir, p_dir, pole=None, twist: float = 0.5) -> None:
    sx = side_x(sfx)
    if pole is None:
        pole = v3(sx * 0.6, -0.4, -0.7)
    spec.arms[sfx] = ArmIK(wrist=np.asarray(wrist, float), hand=hand_rot(sk, sfx, a_dir, p_dir),
                           pole=np.asarray(pole, float), twist_share=twist)


# ------------------------------------------------------------------------------------------
# weapon holds
# ------------------------------------------------------------------------------------------
# Hand placement relative to the weapon frame (x right, y muzzle forward, z up), metres at scale 1.
GRIP_R = {"wrist": v3(0.008, -0.060, -0.032), "a": v3(0.05, 0.62, -0.78), "p": v3(-1.0, 0.0, 0.05)}
RIFLE_L = {"wrist": v3(-0.035, 0.24, -0.045), "a": v3(0.55, 0.80, 0.15), "p": v3(0.35, -0.05, 0.93)}
PISTOL_L = {"wrist": v3(-0.050, -0.045, -0.050), "a": v3(0.45, 0.55, -0.70), "p": v3(0.95, 0.0, 0.2)}


def weapon_frame(origin, yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    """(rotation, origin) of a weapon whose muzzle points along +Y rotated by yaw (left +),
    pitch (up +) and roll (right side down +), degrees."""
    R = rz(deg(yaw)) @ rx(deg(pitch)) @ ry(deg(roll))
    return R, np.asarray(origin, float)


def hold(sk: Skeleton, spec: PoseSpec, sfx: str, wf, grip: dict, pole=None) -> None:
    R, o = wf
    k = sk.scale
    wrist = o + R @ (grip["wrist"] * k)
    arm_to(sk, spec, sfx, wrist, R @ grip["a"], R @ grip["p"], pole)


def rifle_origin(sk: Skeleton) -> np.ndarray:
    k = sk.scale
    return v3(0.13 * k, 0.24 * k, 1.33 * k)


def pistol_origin(sk: Skeleton) -> np.ndarray:
    k = sk.scale
    return v3(0.04 * k, 0.47 * k, 1.38 * k)


def aim_stance(sk: Skeleton, spec: PoseSpec, rifle: bool) -> None:
    k = sk.scale
    spec.hip = v3(0.0, -0.01 * k, -0.035 * k)
    legs_ik(sk, spec, stand_feet(sk, spread=0.03, stagger_l=0.09, stagger_r=-0.08, yaw_l=8, yaw_r=18))
    if rifle:
        spine(spec, lean=5, twist=-10, chest_lean=3, chest_twist=-6, neck=(4, 3, 8), head=(4, 8, 6), hips=(0, 0, 14))
    else:
        spine(spec, lean=4, twist=-4, chest_lean=2, neck=(3, 0, 2), head=(2, 0, 2), hips=(0, 0, 6))
    for sfx in ("L", "R"):
        curl(spec, sfx, 0.82)
    curl(spec, "R", 0.85, thumb=0.6, index=0.45)


def gun_pose(sk: Skeleton, rifle: bool, t: float = 0.0, recoil: float = 0.0, sway: float = 1.0) -> PoseSpec:
    spec = PoseSpec()
    aim_stance(sk, spec, rifle)
    k = sk.scale
    br = math.sin(TAU * t)
    spec.D["chest"] = spec.D["chest"] @ rx(-deg(0.6 * br * sway))
    if rifle:
        o = rifle_origin(sk) + v3(0, -0.035 * k * recoil, 0.004 * k * br * sway)
        wf = weapon_frame(o, yaw=0.3 * br * sway, pitch=0.4 * math.sin(TAU * t + 1.0) * sway + 6 * recoil)
        hold(sk, spec, "R", wf, GRIP_R, pole=v3(0.8, -0.2, -0.6))
        hold(sk, spec, "L", wf, RIFLE_L, pole=v3(-0.3, -0.2, -1.0))
    else:
        o = pistol_origin(sk) + v3(0, -0.03 * k * recoil, 0.005 * k * br * sway + 0.01 * k * recoil)
        wf = weapon_frame(o, yaw=0.4 * br * sway, pitch=0.5 * math.sin(TAU * t + 1.0) * sway + 14 * recoil)
        hold(sk, spec, "R", wf, GRIP_R, pole=v3(0.7, -0.3, -0.7))
        hold(sk, spec, "L", wf, PISTOL_L, pole=v3(-0.7, -0.3, -0.7))
    return spec


# ------------------------------------------------------------------------------------------
# locomotion
# ------------------------------------------------------------------------------------------
def foot_on_cycle(sk: Skeleton, sfx: str, ph: float, cfg: dict) -> tuple:
    """Ankle target, foot rotation, toe bend for one foot at cycle phase ph (0 = heel strike)."""
    k = sk.scale
    S = cfg["speed"] * cfg["frames"] / FPS * k
    beta = cfg["beta"]
    dirv = np.asarray(cfg.get("dir", (0.0, 1.0, 0.0)), float)
    strike, toeoff = deg(cfg.get("strike", 12.0)), deg(cfg.get("toeoff", -28.0))
    centre = cfg.get("centre", -0.03) * k
    g = sk.ground_points(sfx)
    sx = side_x(sfx)
    base = v3(sx * cfg.get("width", 0.0) * k, cfg.get("stagger", {}).get(sfx, 0.0) * k, 0.0)
    if ph < beta:
        us = ph / beta
        d = S * beta * (0.5 - us)
        pitch = strike * (1 - smooth(0.0, 0.2, us)) + toeoff * smooth(0.55, 1.0, us)
        lift = 0.0
        toe = -min(pitch, 0.0)
    else:
        uw = (ph - beta) / (1 - beta)
        e = uw * uw * (3 - 2 * uw)
        d = S * beta * (-0.5 + e)
        pitch = toeoff + (strike - toeoff) * smooth(0.15, 0.95, uw)
        lift = cfg["lift"] * k * math.sin(math.pi * min(1.0, uw ** cfg.get("lift_skew", 0.8)))
        toe = -toeoff * (1 - smooth(0.0, 0.5, uw))
    shift = dirv * (d + centre) + base
    pivot = g["heel"] if pitch > 0 else g["ball"]
    R = rx(pitch)
    ankle = pivot + shift + R @ (g["ankle"] - pivot) + v3(0, 0, lift)
    return ankle, R, toe


def locomotion(sk: Skeleton, f: int, cfg: dict) -> PoseSpec:
    N = cfg["frames"]
    ph = (f % N) / N
    k = sk.scale
    spec = PoseSpec()
    beta = cfg["beta"]
    run = cfg.get("run", False)
    if run:
        bob = cfg["bob"] * k * math.cos(TAU * 2 * (ph - beta / 2) + math.pi)
    else:
        bob = -cfg["bob"] * k * math.cos(TAU * 2 * ph)
    sway = cfg.get("sway", 0.015) * k * math.cos(TAU * (ph - beta / 2))
    spec.hip = v3(sway, 0.0, -cfg["drop"] * k + bob)
    yaw = cfg.get("yaw", 5.0) * math.cos(TAU * ph)
    roll = -cfg.get("roll", 3.0) * math.cos(TAU * (ph - beta / 2))
    lean = cfg.get("lean", 3.0)
    spine(spec, lean=lean * 0.5, twist=-yaw * 0.5, chest_lean=lean * 0.5, chest_twist=-yaw * 0.9,
          side=-roll * 0.5, neck=(-lean * 0.4, 0, yaw * 0.35), head=(-lean * 0.4, 0, yaw * 0.35),
          hips=(lean * 0.3, roll, yaw))
    feet = {}
    for sfx, off in (("R", 0.0), ("L", 0.5)):
        ank, R, toe = foot_on_cycle(sk, sfx, (ph + off) % 1.0, cfg)
        sx = side_x(sfx)
        feet[sfx] = (ank, R, toe, v3(sx * 0.1, 1.0, 0.0))
    legs_ik(sk, spec, feet)
    swing = cfg.get("arm_swing", 18.0)
    flex = cfg.get("arm_flex", 15.0)
    for sfx, sgn in (("R", -1.0), ("L", 1.0)):
        sw = sgn * swing * math.cos(TAU * ph)
        arm_fk(sk, spec, sfx, add=cfg.get("arm_add", 40.0), swing=sw,
               flex=flex + cfg.get("flex_swing", 8.0) * max(0.0, sw / max(swing, 1e-3)))
        curl(spec, sfx, cfg.get("curl", 0.35))
    if "arms" in cfg:
        cfg["arms"](sk, spec, f, ph)
    return spec


WALK = {"frames": 30, "speed": SPEEDS["walk"], "beta": 0.58, "lift": 0.07, "bob": 0.014, "drop": 0.045,
        "yaw": 5.0, "roll": 3.0, "lean": 3.0, "arm_swing": 17.0, "arm_flex": 14.0, "width": 0.0}
RUN = {"frames": 20, "speed": SPEEDS["run"], "beta": 0.38, "lift": 0.20, "lift_skew": 0.55, "bob": 0.03,
       "drop": 0.09, "run": True, "yaw": 8.0, "roll": 4.0, "lean": 9.0, "arm_swing": 32.0, "arm_flex": 70.0,
       "flex_swing": 20.0, "strike": 8.0, "toeoff": -32.0, "centre": -0.05, "curl": 0.65, "sway": 0.01}
SPRINT = {"frames": 18, "speed": SPEEDS["sprint"], "beta": 0.32, "lift": 0.28, "lift_skew": 0.5, "bob": 0.035,
          "drop": 0.11, "run": True, "yaw": 9.0, "roll": 4.0, "lean": 16.0, "arm_swing": 42.0, "arm_flex": 80.0,
          "flex_swing": 15.0, "strike": 4.0, "toeoff": -38.0, "centre": -0.08, "curl": 0.75, "sway": 0.008}
CROUCH_WALK = {"frames": 36, "speed": SPEEDS["crouch_walk"], "beta": 0.62, "lift": 0.06, "bob": 0.012,
               "drop": 0.30, "yaw": 4.0, "roll": 2.0, "lean": 22.0, "arm_swing": 10.0, "arm_flex": 35.0,
               "arm_add": 30.0, "width": 0.03, "strike": 6.0, "toeoff": -20.0, "centre": 0.0}
STRAFE = {"frames": 16, "speed": SPEEDS["strafe_l"], "beta": 0.44, "lift": 0.06, "bob": 0.01, "drop": 0.05,
          "yaw": 0.0, "roll": 2.0, "lean": 3.0, "arm_swing": 4.0, "arm_flex": 20.0, "width": 0.07,
          "strike": 0.0, "toeoff": -12.0, "centre": 0.0, "stagger": {"R": 0.03, "L": -0.02}}
WALK_BACK = {"frames": 32, "speed": SPEEDS["walk_back"], "beta": 0.6, "lift": 0.06, "bob": 0.012, "drop": 0.05,
             "dir": (0.0, -1.0, 0.0), "yaw": 4.0, "roll": 2.0, "lean": 1.0, "arm_swing": 10.0, "arm_flex": 18.0,
             "strike": -6.0, "toeoff": -14.0, "centre": 0.06}


def flee_arms(sk: Skeleton, spec: PoseSpec, f: int, ph: float) -> None:
    for sfx, sgn in (("R", 1.0), ("L", -1.0)):
        sw = sgn * 25.0 * math.cos(TAU * ph)
        arm_fk(sk, spec, sfx, add=28.0, swing=35.0 + sw, flex=95.0 + 10 * math.sin(TAU * ph), clav_up=8.0)
        curl(spec, sfx, 0.25)
    spec.D["head"] = spec.D["head"] @ rz(deg(18.0 * math.sin(TAU * ph * 0.5) ** 2 * (1 if f < 10 else -1)))


FLEE = dict(RUN, speed=SPEEDS["flee"], lean=4.0, arms=flee_arms)


def carry_arms(sk: Skeleton, spec: PoseSpec, f: int, ph: float) -> None:
    pre = solve(sk, spec)
    k = sk.scale
    sh = pre.P["upper_arm.R"]
    wrist = at_bone(pre, sk, "chest", v3(0.10 * k, 0.07 * k, 0.17 * k)) + v3(0, 0, 0.005 * k * math.cos(TAU * 2 * ph))
    del sh
    arm_to(sk, spec, "R", wrist, v3(-0.3, 0.2, 0.95), v3(-0.2, -0.95, 0.0), pole=v3(0.4, 0.2, -1.0))
    curl(spec, "R", 0.9)
    spec.D["chest"] = spec.D["chest"] @ ry(deg(-4.0))


CARRY = dict(WALK, speed=SPEEDS["carry_bag_walk"], frames=32, lean=6.0, drop=0.055, arms=carry_arms)
CARRY["arm_swing"] = 12.0


# ------------------------------------------------------------------------------------------
# static / looping poses
# ------------------------------------------------------------------------------------------
def idle(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    spec = default_spec(sk)
    k = sk.scale
    br = math.sin(TAU * t * 3)       # 3 breaths per loop
    shift = math.sin(TAU * t)
    spec.hip = v3(0.012 * k * shift, 0.0, -0.014 * k + 0.002 * k * br)
    spine(spec, lean=1.0, chest_lean=-1.2 * br, side=-1.0 * shift, neck=(0, 0.5 * shift, 0),
          head=(-1.0 + 0.6 * br, 0.8 * shift, 3.0 * math.sin(TAU * t + 0.6)), hips=(0, 1.2 * shift, 0))
    for sfx in ("L", "R"):
        arm_fk(sk, spec, sfx, add=41.0, swing=2.0 + 1.0 * br, flex=12.0 + 2.0 * br, clav_up=0.8 * br)
    return spec


def idle_alert(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    spec = default_spec(sk)
    k = sk.scale
    br = math.sin(TAU * t * 3)
    scan = math.sin(TAU * t)
    spec.hip = v3(0.0, -0.01 * k, -0.06 * k + 0.002 * k * br)
    legs_ik(sk, spec, stand_feet(sk, spread=0.04, stagger_l=0.06, stagger_r=-0.05, yaw_l=6, yaw_r=10))
    spine(spec, lean=7.0, chest_lean=2.0 - 1.0 * br, twist=4.0 * scan, chest_twist=6.0 * scan,
          neck=(-2, 0, 8.0 * scan), head=(-2, 0, 14.0 * scan))
    for sfx in ("L", "R"):
        arm_fk(sk, spec, sfx, add=33.0, swing=18.0, flex=55.0, clav_up=2.0)
        curl(spec, sfx, 0.55)
    return spec


def crouch_idle(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    spec = default_spec(sk)
    k = sk.scale
    br = math.sin(TAU * t * 2)
    spec.hip = v3(0.0, -0.06 * k, -0.33 * k + 0.003 * k * br)
    legs_ik(sk, spec, stand_feet(sk, spread=0.05, stagger_l=0.06, stagger_r=-0.08, yaw_l=8, yaw_r=12))
    spine(spec, lean=16.0, chest_lean=8.0 - 1.2 * br, neck=(-14, 0, 0), head=(-8, 0, 3 * math.sin(TAU * t)))
    for sfx in ("L", "R"):
        arm_fk(sk, spec, sfx, add=28.0, swing=24.0, flex=55.0, clav_up=1.0 * br)
        curl(spec, sfx, 0.45)
    return spec


def aim_rifle(sk, f, N):
    return gun_pose(sk, True, f / N)


def aim_pistol(sk, f, N):
    return gun_pose(sk, False, f / N)


def recoil_curve(f: int, N: int, peak: int = 1) -> float:
    if f <= peak:
        return f / max(peak, 1)
    return math.exp(-4.0 * (f - peak) / (N - peak)) * (1 - (f - peak) / (N - peak))


def fire_rifle(sk, f, N):
    return gun_pose(sk, True, 0.0, recoil_curve(f, N, 1), sway=0.0)


def fire_pistol(sk, f, N):
    return gun_pose(sk, False, 0.0, recoil_curve(f, N, 1), sway=0.0)


def cower(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    k = sk.scale
    spec = default_spec(sk)
    shake = math.sin(TAU * t * 6) * 0.6
    spec.hip = v3(0.0, -0.12 * k, -0.52 * k)
    legs_ik(sk, spec, stand_feet(sk, spread=0.03, stagger_l=0.03, stagger_r=-0.02, yaw_l=10, yaw_r=10))
    for sfx in ("L", "R"):
        a, R, toe, pole = spec.legs[sfx].ankle, spec.legs[sfx].foot, 0.0, spec.legs[sfx].pole
        spec.legs[sfx] = LegIK(ankle=a + v3(0, -0.02 * k, 0.065 * k), foot=R @ rx(deg(-40)), toe=deg(40), pole=pole)
    spine(spec, lean=34.0, chest_lean=22.0 + shake, neck=(18, 0, 0), head=(14, 0, 4 * math.sin(TAU * t)))
    pre = solve(sk, spec)
    for sfx in ("L", "R"):
        sx = side_x(sfx)
        wrist = at_bone(pre, sk, "head", v3(sx * 0.07 * k, -0.02 * k, 0.17 * k))
        arm_to(sk, spec, sfx, wrist, v3(-sx * 0.6, -0.3, -0.4), v3(-sx * 0.2, 0.2, -1.0),
               pole=v3(sx * 0.2, 1.0, -0.5))
        curl(spec, sfx, 0.35)
    return spec


def hands_up(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    k = sk.scale
    spec = default_spec(sk)
    br = math.sin(TAU * t * 2)
    spec.hip = v3(0.008 * k * math.sin(TAU * t), 0, -0.015 * k)
    spine(spec, lean=-2.0, chest_lean=-1.0 * br, head=(4.0, 0, 6 * math.sin(TAU * t)))
    pre = solve(sk, spec)
    for sfx in ("L", "R"):
        sx = side_x(sfx)
        wrist = at_bone(pre, sk, "chest", v3(sx * 0.33 * k, 0.05 * k, 0.33 * k + 0.008 * k * br))
        arm_to(sk, spec, sfx, wrist, v3(sx * 0.15, 0.05, 1.0), v3(0, -1, 0), pole=v3(sx, -0.3, -0.6))
        curl(spec, sfx, 0.15)
    return spec


def lie_down(sk: Skeleton, f: int, N: int) -> PoseSpec:
    """Prone on the floor, hands behind the head (PD2 civilian 'down')."""
    t = f / N
    k = sk.scale
    spec = PoseSpec()
    br = math.sin(TAU * t * 2)
    hip_rest = sk.head["hips"]
    spec.hip = v3(0, 0.0, 0.115 * k + 0.002 * k * br) - v3(0, 0, hip_rest[2])
    spec.hip += v3(0, 0.80 * k, 0)
    spine(spec, hips=(90.0, 0, 0), lean=-4.0, chest_lean=-6.0 - 0.8 * br, neck=(-20, 0, 0), head=(-10, 0, -38))
    hip_w = spec.hip + hip_rest
    feet = {}
    for sfx in ("L", "R"):
        sx = side_x(sfx)
        ank = v3(sx * 0.16 * k, hip_w[1] - 0.80 * k, 0.085 * k)
        feet[sfx] = (ank, rx(deg(-165)), 0.0, v3(0, 0, -1))
    legs_ik(sk, spec, feet)
    pre = solve(sk, spec)
    for sfx in ("L", "R"):
        sx = side_x(sfx)
        wrist = at_bone(pre, sk, "head", v3(sx * 0.05 * k, -0.11 * k, 0.12 * k))
        arm_to(sk, spec, sfx, wrist, v3(-sx * 0.8, 0.0, 0.6), v3(0, 0, -1), pole=v3(sx, 0, 0.3))
        curl(spec, sfx, 0.3)
    return spec


def tied(sk: Skeleton, f: int, N: int) -> PoseSpec:
    """Kneeling, sitting on the heels, wrists tied behind the back."""
    t = f / N
    k = sk.scale
    spec = PoseSpec()
    rock = math.sin(TAU * t)
    hip_rest = sk.head["hips"]
    spec.hip = v3(0, -0.02 * k, 0.40 * k - hip_rest[2] + 0.004 * k * rock)
    spine(spec, lean=8.0 + 2.0 * rock, chest_lean=6.0, neck=(10, 0, 0), head=(14 + 3 * rock, 0, 6 * math.sin(TAU * t + 1)),
          hips=(8, 0, 0))
    feet = {}
    for sfx in ("L", "R"):
        sx = side_x(sfx)
        ank = v3(sx * 0.11 * k, -0.30 * k, 0.085 * k)
        feet[sfx] = (ank, rx(deg(-165)), 0.0, v3(sx * 0.1, 1.0, -0.2))
    legs_ik(sk, spec, feet)
    pre = solve(sk, spec)
    for sfx in ("L", "R"):
        sx = side_x(sfx)
        wrist = at_bone(pre, sk, "hips", v3(sx * 0.03 * k, -0.17 * k, 0.04 * k))
        arm_to(sk, spec, sfx, wrist, v3(-sx * 0.6, -0.3, -0.6), v3(-sx * 0.2, -1, 0.2), pole=v3(sx * 0.6, -0.8, 0.1))
        curl(spec, sfx, 0.5)
    return spec


def phone_call(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    k = sk.scale
    spec = idle(sk, f, N)
    spine(spec, lean=2.0, chest_lean=-0.8 * math.sin(TAU * t * 3), neck=(0, -6, 0),
          head=(4 + 3 * math.sin(TAU * t * 2), -8, 10 * math.sin(TAU * t)), side=-1.0 * math.sin(TAU * t))
    pre = solve(sk, spec)
    wrist = at_bone(pre, sk, "head", v3(0.075 * k, 0.02 * k, 0.02 * k))
    arm_to(sk, spec, "R", wrist, v3(-0.25, 0.25, 0.95), v3(-1.0, 0.1, 0.0), pole=v3(0.6, -0.2, -1.0), twist=0.6)
    curl(spec, "R", 0.75, thumb=0.6)
    gest = 0.5 + 0.5 * math.sin(TAU * t * 2)
    arm_fk(sk, spec, "L", add=36.0, swing=12.0 + 22.0 * gest, flex=40.0 + 40.0 * gest)
    curl(spec, "L", 0.3)
    return spec


def pager_answer(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    k = sk.scale
    spec = idle(sk, f, N)
    spine(spec, lean=4.0, chest_lean=2.0, neck=(8, 0, 4), head=(10 + 2 * math.sin(TAU * t * 2), 0, 6))
    pre = solve(sk, spec)
    wrist = at_bone(pre, sk, "head", v3(-0.045 * k, 0.12 * k, -0.05 * k))
    arm_to(sk, spec, "L", wrist, v3(0.3, 0.3, 0.9), v3(0.2, -1.0, 0.2), pole=v3(-0.6, -0.2, -1.0))
    curl(spec, "L", 0.75, thumb=0.5)
    arm_fk(sk, spec, "R", add=39.0, swing=4.0, flex=14.0)
    return spec


def investigate_look(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    k = sk.scale
    spec = default_spec(sk)
    look = math.sin(TAU * t)
    peer = 0.5 + 0.5 * math.sin(TAU * t * 2 - 1.2)
    spec.hip = v3(0.008 * k * look, 0.0, -0.03 * k)
    legs_ik(sk, spec, stand_feet(sk, spread=0.03, stagger_l=0.05, stagger_r=-0.04, yaw_l=5, yaw_r=8))
    spine(spec, lean=4 + 6 * peer, twist=8 * look, chest_twist=14 * look, chest_lean=2 + 4 * peer,
          neck=(4 * peer, 0, 12 * look), head=(6 * peer, 2 * look, 22 * look))
    arm_fk(sk, spec, "R", add=37.0, swing=6.0, flex=30.0)
    arm_fk(sk, spec, "L", add=38.0, swing=8.0 + 6 * peer, flex=25.0 + 10 * peer)
    return spec


def downed(sk: Skeleton, f: int, N: int) -> PoseSpec:
    """Sitting on the floor, leaning back on the left hand, pistol up in the right hand."""
    t = f / N
    k = sk.scale
    spec = PoseSpec()
    br = math.sin(TAU * t * 3)
    hip_rest = sk.head["hips"]
    spec.hip = v3(0.0, 0.0, 0.13 * k - hip_rest[2] + 0.003 * k * br)
    spine(spec, hips=(-28, 0, 0), lean=14.0, chest_lean=10.0 + 1.5 * br, neck=(8, 0, 0), head=(4, 0, 4 * math.sin(TAU * t)))
    feet = {
        "L": (v3(-0.16 * k, 0.75 * k, 0.07 * k), rx(deg(20)) @ rz(deg(10)), 0.0, v3(-0.2, 0.3, 1.0)),
        "R": (v3(0.10 * k, 0.48 * k, 0.085 * k), rz(deg(-8)), 0.0, v3(0.2, 0.6, 1.0)),
    }
    legs_ik(sk, spec, feet)
    pre = solve(sk, spec)
    hand_l = v3(-0.25 * k, -0.22 * k, 0.07 * k)
    arm_to(sk, spec, "L", hand_l, v3(-0.4, -0.3, -0.85), v3(0, 0, -1), pole=v3(-0.8, -0.6, 0.0))
    curl(spec, "L", 0.15)
    o = at_bone(pre, sk, "chest", v3(0.06 * k, 0.45 * k, 0.08 * k)) + v3(0, 0, 0.004 * k * br)
    wf = weapon_frame(o, yaw=2.0 * math.sin(TAU * t), pitch=-4.0 + 1.5 * br)
    hold(sk, spec, "R", wf, GRIP_R, pole=v3(0.7, -0.3, -0.6))
    curl(spec, "R", 0.85, thumb=0.6, index=0.45)
    return spec


def interact(height: str):
    def fn(sk: Skeleton, f: int, N: int) -> PoseSpec:
        t = f / N
        k = sk.scale
        spec = default_spec(sk)
        work = math.sin(TAU * t * 3)
        work2 = math.sin(TAU * t * 2 + 1.0)
        if height == "low":
            spec.hip = v3(0.0, -0.08 * k, -0.42 * k)
            legs_ik(sk, spec, stand_feet(sk, spread=0.06, stagger_l=0.12, stagger_r=-0.12, yaw_l=8, yaw_r=14))
            ankR = spec.legs["R"]
            spec.legs["R"] = LegIK(ankle=ankR.ankle + v3(0, 0, 0.075 * k), foot=rx(deg(-45)), toe=deg(45), pole=ankR.pole)
            spine(spec, lean=30, chest_lean=16, neck=(10, 0, 0), head=(14, 0, 0))
            zc, yc = 0.42, 0.36
        elif height == "mid":
            spec.hip = v3(0.0, -0.01 * k, -0.025 * k)
            spine(spec, lean=8, chest_lean=6, neck=(10, 0, 0), head=(14, 0, 0))
            zc, yc = 1.02, 0.38
        else:
            spec.hip = v3(0.0, 0.01 * k, -0.005 * k)
            legs_ik(sk, spec, stand_feet(sk, spread=0.02, stagger_l=0.05, stagger_r=-0.03))
            spine(spec, lean=-4, chest_lean=-6, neck=(-14, 0, 0), head=(-16, 0, 0))
            zc, yc = 1.74, 0.30
        for sfx, ph in (("R", 0.0), ("L", 1.7)):
            sx = side_x(sfx)
            w = math.sin(TAU * t * 3 + ph)
            wrist = v3(sx * 0.10 * k + 0.015 * k * w, yc * k + 0.02 * k * work2, zc * k + 0.02 * k * w)
            a = v3(-sx * 0.25, 0.9, -0.35 if height != "high" else 0.6)
            p = v3(-sx * 0.3, 0.0, -1.0) if height != "high" else v3(-sx * 0.2, 1.0, 0.0)
            arm_to(sk, spec, sfx, wrist, a, p, pole=v3(sx * 0.8, -0.3, -0.6))
            curl(spec, sfx, 0.45 + 0.2 * work)
        return spec
    return fn


def browse(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    k = sk.scale
    spec = default_spec(sk)
    shift = math.sin(TAU * t)
    look = math.sin(TAU * t * 2 + 0.5)
    spec.hip = v3(0.015 * k * shift, -0.01 * k, -0.02 * k)
    legs_ik(sk, spec, stand_feet(sk, spread=0.02, stagger_l=0.04, stagger_r=-0.02, yaw_l=8, yaw_r=4))
    spine(spec, lean=10, chest_lean=8, side=-1.5 * shift, neck=(12, 0, 6 * look), head=(16, 2 * look, 10 * look),
          hips=(0, 1.5 * shift, 0))
    arm_to(sk, spec, "L", v3(-0.16 * k, 0.40 * k, 0.97 * k), v3(0.2, 0.9, -0.3), v3(0.1, 0.1, -1.0),
           pole=v3(-0.8, -0.2, -0.6))
    curl(spec, "L", 0.25)
    point = 0.5 + 0.5 * math.sin(TAU * t * 2 - 1.0)
    arm_fk(sk, spec, "R", add=34.0, swing=10.0 + 30.0 * point, flex=30.0 + 50.0 * point)
    curl(spec, "R", 0.5, index=0.5 - 0.4 * point)
    return spec


def seated(sk: Skeleton, spec: PoseSpec, seat_h: float = 0.47, lean: float = 0.0) -> None:
    k = sk.scale
    hip_rest = sk.head["hips"]
    spec.hip = v3(0.0, -0.06 * k, seat_h * k + 0.04 * k - hip_rest[2])
    spine(spec, hips=(-80 + lean, 0, 0), lean=78.0 - lean * 0.2, chest_lean=0.0, neck=(0, 0, 0), head=(0, 0, 0))
    feet = {}
    for sfx in ("L", "R"):
        sx = side_x(sfx)
        feet[sfx] = (v3(sx * 0.13 * k, 0.40 * k, 0.085 * k), rz(-sx * deg(6)), 0.0, v3(sx * 0.1, 0.4, 1.0))
    legs_ik(sk, spec, feet)


def desk_type(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    k = sk.scale
    spec = PoseSpec()
    seated(sk, spec, lean=4.0)
    spec.D["chest"] = spec.D["chest"] @ rx(-deg(6.0))
    spec.D["head"] = rz(deg(4 * math.sin(TAU * t))) @ rx(-deg(10.0))
    for sfx, ph in (("R", 0.0), ("L", 2.1)):
        sx = side_x(sfx)
        tap = max(0.0, math.sin(TAU * t * 6 + ph))
        wrist = v3(sx * 0.13 * k, 0.33 * k + 0.01 * k * math.sin(TAU * t * 2 + ph), 0.76 * k + 0.012 * k * tap)
        arm_to(sk, spec, sfx, wrist, v3(-sx * 0.25, 0.95, -0.15), v3(-sx * 0.05, 0.1, -1.0), pole=v3(sx, -0.5, -0.4))
        curl(spec, sfx, 0.35 + 0.15 * tap)
    return spec


def sit_chair(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    k = sk.scale
    spec = PoseSpec()
    br = math.sin(TAU * t * 3)
    seated(sk, spec, lean=-6.0)
    spec.D["chest"] = spec.D["chest"] @ rx(deg(1.2 * br))
    spec.D["head"] = rz(deg(8 * math.sin(TAU * t))) @ rx(-deg(2.0))
    for sfx in ("L", "R"):
        sx = side_x(sfx)
        wrist = v3(sx * 0.16 * k, 0.27 * k, 0.62 * k + 0.003 * k * br)
        arm_to(sk, spec, sfx, wrist, v3(-sx * 0.15, 0.95, -0.25), v3(-sx * 0.1, 0.0, -1.0), pole=v3(sx, -0.6, -0.3))
        curl(spec, sfx, 0.35)
    return spec


def smoke(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    k = sk.scale
    spec = idle(sk, f, N)
    # puff: raise 0.15-0.3, hold to 0.45, lower by 0.6; twice per loop
    u = (t * 2) % 1.0
    up = smooth(0.10, 0.25, u) * (1 - smooth(0.45, 0.62, u))
    spine(spec, lean=1.0, head=(-4 * up, 0, 4 * math.sin(TAU * t)), neck=(-2 * up, 0, 0))
    pre = solve(sk, spec)
    mouth = at_bone(pre, sk, "head", v3(0.02 * k, 0.12 * k, 0.04 * k))
    low = at_bone(pre, sk, "chest", v3(0.16 * k, 0.16 * k, -0.03 * k))
    wrist = low * (1 - up) + (mouth + v3(0.02 * k, -0.05 * k, -0.07 * k)) * up
    arm_to(sk, spec, "R", wrist, v3(-0.4, 0.4, 0.8 * up - 0.2 * (1 - up)), v3(-0.6, -0.6, 0.2),
           pole=v3(0.7, -0.2, -0.8))
    curl(spec, "R", 0.4, index=0.25)
    cross = at_bone(pre, sk, "chest", v3(0.06 * k, 0.15 * k, -0.08 * k))
    arm_to(sk, spec, "L", cross, v3(0.95, 0.2, 0.1), v3(0, -0.3, 1.0), pole=v3(-0.5, -0.3, -1.0))
    curl(spec, "L", 0.5)
    return spec


def lean_wall(sk: Skeleton, f: int, N: int) -> PoseSpec:
    t = f / N
    k = sk.scale
    spec = default_spec(sk)
    br = math.sin(TAU * t * 3)
    spec.hip = v3(0.0, -0.07 * k, -0.035 * k)
    feet = stand_feet(sk, spread=0.03, stagger_l=0.12, stagger_r=0.0, yaw_l=12, yaw_r=10)
    # right foot up against the wall behind
    ankR = v3(0.11 * k, -0.17 * k, 0.32 * k)
    feet["R"] = (ankR, rx(deg(-55)), deg(10), v3(0.3, 1.0, 0.0))
    feet["L"] = (feet["L"][0] + v3(0, 0.08 * k, 0), feet["L"][1], 0.0, feet["L"][3])
    legs_ik(sk, spec, feet)
    spine(spec, lean=-7.0, chest_lean=-3.0 - 1.0 * br, side=1.5, neck=(6, 0, 0),
          head=(6, -3, 10 * math.sin(TAU * t)), hips=(-4, -2, 0))
    pre = solve(sk, spec)
    for sfx in ("L", "R"):
        sx = side_x(sfx)
        wrist = at_bone(pre, sk, "chest", v3(-sx * 0.06 * k, 0.17 * k, 0.03 * k - 0.04 * k * (sx > 0)))
        arm_to(sk, spec, sfx, wrist, v3(-sx * 0.95, 0.15, 0.15), v3(0, -1.0, 0.2), pole=v3(sx * 0.6, -0.2, -1.0))
        curl(spec, sfx, 0.55)
    return spec


# ------------------------------------------------------------------------------------------
# keyed one-shots (key poses solved once, slerped)
# ------------------------------------------------------------------------------------------
def ease(x: float) -> float:
    return x * x * (3 - 2 * x)


def keyed(sk: Skeleton, keys: list[tuple[int, PoseSpec]], f: int, cache: dict) -> Solved:
    sol = []
    for i, (kf, spec) in enumerate(keys):
        if i not in cache:
            cache[i] = solve(sk, spec)
        sol.append((kf, cache[i]))
    if f <= sol[0][0]:
        return sol[0][1]
    for (f0, s0), (f1, s1) in zip(sol[:-1], sol[1:]):
        if f0 <= f <= f1:
            return blend_solved(s0, s1, ease((f - f0) / (f1 - f0)))
    return sol[-1][1]


def kp_stand(sk: Skeleton) -> PoseSpec:
    return idle(sk, 0, 90)


def kp_kneel_fall(sk: Skeleton, forward: bool) -> PoseSpec:
    k = sk.scale
    spec = PoseSpec()
    hip_rest = sk.head["hips"]
    if forward:
        spec.hip = v3(0.0, 0.12 * k, 0.52 * k - hip_rest[2])
        spine(spec, hips=(25, 0, 6), lean=20, chest_lean=12, neck=(10, 0, 0), head=(20, 0, 10))
        feet = {s: (v3(side_x(s) * 0.12 * k, -0.22 * k, 0.17 * k), rx(deg(-60)), deg(60), v3(0, 1, -0.3)) for s in ("L", "R")}
    else:
        spec.hip = v3(0.0, -0.18 * k, 0.48 * k - hip_rest[2])
        spine(spec, hips=(-30, 0, -6), lean=-10, chest_lean=-14, neck=(-12, 0, 0), head=(-18, 0, -10))
        feet = {s: (v3(side_x(s) * 0.14 * k, 0.15 * k, 0.085 * k), I3, 0.0, v3(side_x(s) * 0.2, 1, 0.3)) for s in ("L", "R")}
    legs_ik(sk, spec, feet)
    for sfx in ("L", "R"):
        arm_fk(sk, spec, sfx, add=20.0, swing=30.0 if forward else -25.0, flex=35.0, out=-15)
        curl(spec, sfx, 0.2)
    return spec


def kp_ground(sk: Skeleton, forward: bool) -> PoseSpec:
    k = sk.scale
    spec = PoseSpec()
    hip_rest = sk.head["hips"]
    if forward:
        spec.hip = v3(0.05 * k, 0.55 * k, 0.11 * k - hip_rest[2])
        spine(spec, hips=(90, 3, 8), lean=-6, chest_lean=-4, neck=(-10, 0, 0), head=(-5, 0, 50))
        feet = {"L": (v3(-0.20 * k, -0.30 * k, 0.085 * k), rx(deg(-165)), 0.0, v3(0, 0, -1)),
                "R": (v3(0.24 * k, -0.22 * k, 0.11 * k), rx(deg(-150)) @ rz(deg(-20)), 0.0, v3(0.6, 0, -1))}
        legs_ik(sk, spec, feet)
        arm_fk(sk, spec, "L", add=-30.0, swing=150.0, flex=40.0)
        arm_fk(sk, spec, "R", add=10.0, swing=-20.0, flex=20.0, out=0)
    else:
        spec.hip = v3(-0.03 * k, -0.75 * k, 0.11 * k - hip_rest[2])
        spine(spec, hips=(-90, -2, -6), lean=4, chest_lean=4, neck=(6, 0, 0), head=(4, 0, -40))
        feet = {"L": (v3(-0.22 * k, 0.12 * k, 0.095 * k), rx(deg(70)), 0.0, v3(-0.3, 0, 1)),
                "R": (v3(0.16 * k, 0.05 * k, 0.15 * k), rx(deg(50)) @ rz(deg(-15)), 0.0, v3(0.4, 0.3, 1))}
        legs_ik(sk, spec, feet)
        arm_fk(sk, spec, "L", add=-10.0, swing=-40.0, flex=25.0)
        arm_fk(sk, spec, "R", add=-35.0, swing=-70.0, flex=45.0)
    for sfx in ("L", "R"):
        curl(spec, sfx, 0.35)
    return spec


def death(forward: bool):
    def fn(sk: Skeleton, f: int, N: int, cache: dict) -> Solved:
        if "keys" not in cache:
            cache["keys"] = [(0, kp_stand(sk)), (int(N * 0.42), kp_kneel_fall(sk, forward)), (int(N * 0.8), kp_ground(sk, forward)),
                             (N, kp_ground(sk, forward))]
        return keyed(sk, cache["keys"], f, cache)
    return fn


def hit_react(sk: Skeleton, f: int, N: int, cache: dict) -> Solved:
    if "keys" not in cache:
        a = kp_stand(sk)
        b = kp_stand(sk)
        k = sk.scale
        b.hip = b.hip + v3(0, -0.035 * k, -0.02 * k)
        spine(b, lean=-6, chest_lean=-10, neck=(-8, 0, 0), head=(-12, 0, 8), side=3)
        for sfx in ("L", "R"):
            arm_fk(sk, b, sfx, add=30.0, swing=25.0, flex=40.0)
        c = kp_stand(sk)
        cache["keys"] = [(0, a), (3, b), (N, c)]
    return keyed(sk, cache["keys"], f, cache)


def radio_call(sk: Skeleton, f: int, N: int, cache: dict) -> Solved:
    if "keys" not in cache:
        k = sk.scale
        a = kp_stand(sk)
        b = idle(sk, 0, 90)
        spine(b, lean=2, neck=(10, -6, -10), head=(16, -8, -18))
        pre = solve(sk, b)
        # radio clip on the left chest
        wrist = at_bone(pre, sk, "chest", v3(-0.05 * k, 0.14 * k, 0.02 * k))
        arm_to(sk, b, "L", wrist, v3(0.25, 0.3, 0.92), v3(0.3, -0.95, 0.0), pole=v3(-0.6, -0.3, -1.0))
        curl(b, "L", 0.6, thumb=0.4)
        c = idle(sk, 0, 90)
        spine(c, lean=2, neck=(8, -5, -8), head=(12, -6, -14))
        c.arms = dict(b.arms)
        c.curl = dict(b.curl)
        cache["keys"] = [(0, a), (12, b), (N - 14, c), (N, kp_stand(sk))]
    return keyed(sk, cache["keys"], f, cache)


def throw_bag(sk: Skeleton, f: int, N: int, cache: dict) -> Solved:
    if "keys" not in cache:
        k = sk.scale
        a = kp_stand(sk)
        a.hip = a.hip + v3(0, -0.03 * k, -0.03 * k)
        spine(a, lean=6, twist=-20, chest_twist=-18)
        arm_to(sk, a, "R", v3(0.30 * k, -0.15 * k, 0.95 * k), v3(0.1, -0.3, -0.9), v3(-0.3, 1, 0))
        arm_to(sk, a, "L", v3(0.05 * k, 0.15 * k, 1.0 * k), v3(0.6, 0.2, -0.7), v3(1, 0, 0))
        b = kp_stand(sk)
        b.hip = b.hip + v3(0, 0.08 * k, -0.04 * k)
        legs_ik(sk, b, stand_feet(sk, stagger_l=0.18, stagger_r=-0.10))
        spine(b, lean=10, twist=16, chest_twist=14, head=(-4, 0, -6))
        arm_to(sk, b, "R", v3(0.10 * k, 0.62 * k, 1.62 * k), v3(-0.1, 0.8, 0.6), v3(0, 0.3, -1.0), pole=v3(0.8, -0.3, -0.4))
        arm_fk(sk, b, "L", add=35.0, swing=-20.0, flex=25.0)
        cache["keys"] = [(0, kp_stand(sk)), (9, a), (16, b), (N, kp_stand(sk))]
    return keyed(sk, cache["keys"], f, cache)


def drill_place(sk: Skeleton, f: int, N: int, cache: dict) -> Solved:
    if "keys" not in cache:
        k = sk.scale
        a = kp_stand(sk)
        arm_to(sk, a, "R", v3(0.10 * k, 0.28 * k, 1.02 * k), v3(-0.3, 0.6, -0.7), v3(-1, 0, 0.3))
        arm_to(sk, a, "L", v3(-0.10 * k, 0.28 * k, 1.02 * k), v3(0.3, 0.6, -0.7), v3(1, 0, 0.3))
        b = kp_stand(sk)
        b.hip = b.hip + v3(0, 0.03 * k, -0.06 * k)
        legs_ik(sk, b, stand_feet(sk, stagger_l=0.15, stagger_r=-0.06))
        spine(b, lean=14, chest_lean=8, neck=(8, 0, 0), head=(10, 0, 0))
        arm_to(sk, b, "R", v3(0.09 * k, 0.55 * k, 1.05 * k), v3(-0.2, 0.9, -0.2), v3(-1, 0, 0.2))
        arm_to(sk, b, "L", v3(-0.09 * k, 0.55 * k, 1.05 * k), v3(0.2, 0.9, -0.2), v3(1, 0, 0.2))
        for s in (a, b):
            curl(s, "R", 0.75)
            curl(s, "L", 0.75)
        c = PoseSpec(hip=b.hip.copy(), D=dict(b.D), legs=dict(b.legs), arms=dict(b.arms), curl={})
        curl(c, "R", 0.1)
        curl(c, "L", 0.1)
        cache["keys"] = [(0, kp_stand(sk)), (8, a), (22, b), (28, c), (N, kp_stand(sk))]
    return keyed(sk, cache["keys"], f, cache)


def reload_rifle(sk: Skeleton, f: int, N: int, cache: dict) -> Solved:
    if "keys" not in cache:
        k = sk.scale
        base = gun_pose(sk, True, 0.0, sway=0.0)

        def tilted(roll: float, pitch: float, lpos=None, lgrip=None, lcurl=0.8) -> PoseSpec:
            s = gun_pose(sk, True, 0.0, sway=0.0)
            o = rifle_origin(sk) + v3(-0.04 * k, 0.0, -0.06 * k)
            wf = weapon_frame(o, pitch=pitch, roll=roll, yaw=8)
            hold(sk, s, "R", wf, GRIP_R, pole=v3(0.8, -0.2, -0.6))
            if lpos is None:
                hold(sk, s, "L", wf, lgrip, pole=v3(-0.5, -0.2, -1.0))
            else:
                arm_to(sk, s, "L", lpos, v3(0.3, 0.4, -0.85), v3(0.6, 0, 0.2), pole=v3(-0.6, -0.2, -0.8))
            curl(s, "L", lcurl)
            return s
        magwell = {"wrist": v3(-0.03, 0.07, -0.12), "a": v3(0.4, 0.6, 0.7), "p": v3(0.9, 0.0, -0.3)}
        pouch = v3(-0.06 * k, 0.17 * k, 1.12 * k)
        keys = [(0, base), (10, tilted(25, 10, lgrip=magwell)), (22, tilted(25, 10, lpos=pouch, lcurl=0.7)),
                (34, tilted(25, 10, lpos=pouch + v3(0, 0.02 * k, -0.02 * k), lcurl=0.85)),
                (48, tilted(25, 12, lgrip=magwell, lcurl=0.85)), (56, tilted(22, 14, lgrip=magwell, lcurl=0.4)),
                (N, gun_pose(sk, True, 0.0, sway=0.0))]
        cache["keys"] = keys
    return keyed(sk, cache["keys"], f, cache)


def reload_pistol(sk: Skeleton, f: int, N: int, cache: dict) -> Solved:
    if "keys" not in cache:
        k = sk.scale

        def p(dz: float, roll: float, lpos=None, lgrip=None, lcurl=0.8) -> PoseSpec:
            s = gun_pose(sk, False, 0.0, sway=0.0)
            o = pistol_origin(sk) + v3(0.0, -0.15 * k, -0.12 * k + dz * k)
            wf = weapon_frame(o, pitch=15, roll=roll, yaw=6)
            hold(sk, s, "R", wf, GRIP_R, pole=v3(0.7, -0.3, -0.7))
            if lpos is not None:
                arm_to(sk, s, "L", lpos, v3(0.3, 0.4, -0.85), v3(0.6, 0, 0.2), pole=v3(-0.6, -0.2, -0.8))
            else:
                hold(sk, s, "L", wf, lgrip, pole=v3(-0.6, -0.3, -0.8))
            curl(s, "L", lcurl)
            return s
        butt = {"wrist": v3(-0.02, -0.08, -0.16), "a": v3(0.3, 0.3, 0.9), "p": v3(0.9, 0.0, -0.3)}
        pouch = v3(-0.12 * k, 0.12 * k, 1.0 * k)
        cache["keys"] = [(0, gun_pose(sk, False, 0.0, sway=0.0)), (8, p(0.0, 20, lpos=pouch, lcurl=0.4)),
                         (16, p(0.0, 20, lpos=pouch + v3(0, 0, -0.02 * k), lcurl=0.85)),
                         (27, p(0.02, 20, lgrip=butt, lcurl=0.85)), (33, p(0.03, 15, lgrip=butt, lcurl=0.5)),
                         (N, gun_pose(sk, False, 0.0, sway=0.0))]
    return keyed(sk, cache["keys"], f, cache)


# ------------------------------------------------------------------------------------------
# registry
# ------------------------------------------------------------------------------------------
def loco(cfg: dict) -> Callable:
    def fn(sk: Skeleton, f: int, N: int) -> PoseSpec:
        return locomotion(sk, f, cfg)
    return fn


def strafe(direction: float) -> Callable:
    cfg = dict(STRAFE, dir=(direction, 0.0, 0.0))
    return loco(cfg)


# name: (frames, loop, function, keyed?)
ANIMS: dict[str, tuple[int, bool, Callable, bool]] = {
    "idle": (90, True, idle, False),
    "idle_alert": (60, True, idle_alert, False),
    "walk": (WALK["frames"], True, loco(WALK), False),
    "run": (RUN["frames"], True, loco(RUN), False),
    "sprint": (SPRINT["frames"], True, loco(SPRINT), False),
    "crouch_idle": (60, True, crouch_idle, False),
    "crouch_walk": (CROUCH_WALK["frames"], True, loco(CROUCH_WALK), False),
    "strafe_l": (STRAFE["frames"], True, strafe(-1.0), False),
    "strafe_r": (STRAFE["frames"], True, strafe(1.0), False),
    "walk_back": (WALK_BACK["frames"], True, loco(WALK_BACK), False),
    "aim_pistol": (60, True, aim_pistol, False),
    "aim_rifle": (60, True, aim_rifle, False),
    "fire_pistol": (9, False, fire_pistol, False),
    "fire_rifle": (6, False, fire_rifle, False),
    "reload_pistol": (45, False, reload_pistol, True),
    "reload_rifle": (72, False, reload_rifle, True),
    "death_front": (45, False, death(True), True),
    "death_back": (45, False, death(False), True),
    "hit_react": (15, False, hit_react, True),
    "cower": (60, True, cower, False),
    "hands_up": (60, True, hands_up, False),
    "lie_down": (60, True, lie_down, False),
    "tied": (60, True, tied, False),
    "flee": (FLEE["frames"], True, loco(FLEE), False),
    "phone_call": (90, True, phone_call, False),
    "radio_call": (60, False, radio_call, True),
    "pager_answer": (60, True, pager_answer, False),
    "investigate_look": (120, True, investigate_look, False),
    "downed": (60, True, downed, False),
    "carry_bag_walk": (CARRY["frames"], True, loco(CARRY), False),
    "throw_bag": (30, False, throw_bag, True),
    "interact_low": (60, True, interact("low"), False),
    "interact_mid": (60, True, interact("mid"), False),
    "interact_high": (60, True, interact("high"), False),
    "drill_place": (40, False, drill_place, True),
    "browse": (120, True, browse, False),
    "desk_type": (60, True, desk_type, False),
    "sit_chair": (90, True, sit_chair, False),
    "smoke": (120, True, smoke, False),
    "lean_wall": (90, True, lean_wall, False),
}


def bake(sk: Skeleton, name: str) -> list[Solved]:
    """Solved pose for every frame 0..N (inclusive). Loops end exactly on their first frame."""
    N, loop, fn, is_keyed = ANIMS[name]
    cache: dict = {}
    out: list[Solved] = []
    for f in range(N + 1):
        s = fn(sk, f, N, cache) if is_keyed else solve(sk, fn(sk, f, N))
        out.append(Solved(s.W, s.P, {b: q.copy() for b, q in s.local.items()}, s.hip_loc.copy()))
    if loop:
        out[-1] = Solved(out[0].W, out[0].P, {b: q.copy() for b, q in out[0].local.items()}, out[0].hip_loc.copy())
    # quaternion sign continuity
    prev = None
    for s in out:
        if prev is not None:
            for b, q in s.local.items():
                if float(q @ prev.local[b]) < 0:
                    s.local[b] = -q
        prev = s
    return out


def world_pose(sk: Skeleton, s: Solved):
    if s.W:
        return s.W, s.P
    return world_from_local(sk, s)
