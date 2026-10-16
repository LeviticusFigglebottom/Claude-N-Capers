"""D-116 follow-up (organic, third person): weapon-class holds for crew bots / teammates and armed NPCs.

Outside aiming, the shared ``idle_alert`` / ``walk`` / ``run`` clips hold no weapon: both hands are loose fists, so a
rifle at ``HandR/Socket`` hangs from one hand. These clips hold the weapon two-handed at a PD2 low ready:

* ``idle_alert_rifle`` / ``idle_alert_pistol``: full body standing loops (96 / 110 f): the low ready, the support hand
  cupped on the weapon's LeftHandIK, a slow weight shift from foot to foot (hips and spine counter), breathing and a
  look scan.
* ``hold_rifle`` / ``hold_pistol``: the same upper body without the weight shift (legs = the plain stand), for A to
  layer over locomotion (walk / run / strafe) with a bone filter: spine, chest, neck, head, clavicle.*, upper_arm.*,
  forearm.*, hand.* and the fingers (SOURCE ``weapon_holds``).

The support hand sits on the trunk weapons' current LeftHandIK (``_anim_humanoid.RIFLE`` / ``PISTOL``).
"""

from __future__ import annotations

import math

import _anim as A
import _anim_humanoid as H
from _anim import FPS, TAU, Clip, Pose, Skeleton, Solver, hand_shape, rxd, rzd, v3

NAMES = ("idle_alert_rifle", "idle_alert_pistol", "hold_rifle", "hold_pistol")
#: the low ready: rifle turned about its butt (pitch down, yaw left, lowered); pistol about its grip
RIFLE_LOW = {"pitch": -28.0, "yaw": 12.0, "drop": 0.03}
PISTOL_LOW = {"pitch": -38.0, "back": 0.20, "drop": 0.24}
#: the weight shift: hips side to side (m at 1.78 m) over one loop, with the spine leaning against it (deg)
SHIFT_M, SHIFT_COUNTER_DEG = 0.016, 2.2
#: the bones A layers from hold_* over locomotion
UPPER_BONES = ("spine", "chest", "neck", "head", "clavicle.L", "clavicle.R", "upper_arm.L", "upper_arm.R",
               "forearm.L", "forearm.R", "hand.L", "hand.R", "fingers of both hands")


def rifle_low_frame(sk: Skeleton, t: float) -> tuple:
    R, o = H.rifle_aim_frame(sk, t, 0.6)
    k = sk.scale
    pivot = o + R @ (H.RIFLE["butt"] * k)
    Rl = rzd(RIFLE_LOW["yaw"]) @ rxd(RIFLE_LOW["pitch"]) @ R
    ol = pivot - Rl @ (H.RIFLE["butt"] * k) + v3(0.0, 0.0, -RIFLE_LOW["drop"] * k)
    return Rl, ol


def pistol_low_frame(sk: Skeleton, t: float) -> tuple:
    R, o = H.pistol_aim_frame(sk, t, 0.5)
    k = sk.scale
    Rl = rxd(PISTOL_LOW["pitch"]) @ R
    return Rl, o + v3(0.0, -PISTOL_LOW["back"] * k, -PISTOL_LOW["drop"] * k)


def _hold(sk: Skeleton, rifle: bool, f: int, N: int, shift: bool) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    H.aim_body(sk, pose, rifle)
    w = math.sin(TAU * t / T)
    if shift:
        pose.hip = pose.hip + v3(SHIFT_M * k * w, 0.0, -0.004 * k * abs(w))
        A.add_rot(pose, "spine", A.ryd(-SHIFT_COUNTER_DEG * w))
    H.look(pose, yaw=14.0 * math.sin(TAU * t / T + 0.9), pitch=-2.0 + 1.5 * math.sin(TAU * 2 * t / T))
    wf = rifle_low_frame(sk, t) if rifle else pistol_low_frame(sk, t)
    if rifle:
        H.hold_rifle(sk, pose, wf)
        pose.hands["R"] = hand_shape("grip", 0.9)          # finger off the trigger at the low ready
    else:
        H.hold_pistol(sk, pose, wf)
        pose.hands["R"] = hand_shape("grip", 0.85)
    H.breathe(pose, t, T / 4.0, 1.1)
    return pose


def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N = int(row["frames"])
        rifle = name.endswith("rifle")
        shift = name.startswith("idle_alert")

        def fn(f: int, N=N, rifle=rifle, shift=shift) -> Pose:
            return _hold(sk, rifle, f, N, shift)
        out[name] = Clip(name, N, True, fn, float(row["speed"]), None, dict(row.get("events", {})), reach_fix=False)
    return out


KEEP = NAMES


def check_row(name: str, baked) -> str:
    return ""


def source_notes() -> dict:
    return {"weapon_holds": (
        "D-116 third-person weapon holds (crew bots / teammates, armed NPCs): idle_alert_rifle / idle_alert_pistol "
        "replace idle_alert while the body holds a rifle- / pistol-class weapon (AnimDriver.weapon_kind) and is not "
        "aiming: PD2 low ready, both hands on the weapon (support hand on its LeftHandIK), a slow weight shift. "
        "hold_rifle / hold_pistol: the same upper body without the weight shift, to layer over walk / run / strafe* "
        "with a bone filter (" + ", ".join(UPPER_BONES) + "), weight 1.0, blend 0.2 s; aim_rifle / aim_pistol keep "
        f"priority while aiming. Loops: idle_alert_rifle {96} f, idle_alert_pistol {110} f, hold_* {96} f "
        "(start each body at a random offset, GameRng &\"anim_variants\")")}

