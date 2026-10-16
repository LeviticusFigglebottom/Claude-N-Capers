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

#: hold kinds (A maps WeaponDef.weapon_class -> kind, SOURCE ``weapon_holds``) -> loop frames
KINDS = {"rifle": 96, "pistol": 110, "smg": 92, "sniper": 104, "lmg": 100, "akimbo": 106}
NAMES = tuple(f"idle_alert_{kind}" for kind in KINDS) + tuple(f"hold_{kind}" for kind in KINDS)
#: D-116 audit: armed variants of the crew interactions (the left hand works, the weapon stays in the right hand at
#: H.LOW_CARRY): the shared interact_* / throw_bag work with both hands and clipped the held rifle through the arms /
#: the head
ARMED = ("interact_low_armed", "interact_mid_armed", "interact_high_armed", "throw_bag_armed")
#: the work point per interact level (as _anim_humanoid.interact): z, y (m at 1.78 m), hand along, palm
INTERACT = {"low": (0.40, 0.40, (0.0, 0.85, -0.5), (0.0, 0.3, -1.0)),
            "mid": (1.02, 0.40, (0.0, 1.0, -0.25), (0.0, 0.5, -1.0)),
            "high": (1.78, 0.30, (0.0, 0.4, 1.0), (0.0, 1.0, 0.0))}
#: the low ready: rifle turned about its butt (pitch down, yaw left, lowered); pistol about its grip
RIFLE_LOW = {"pitch": -28.0, "yaw": 12.0, "drop": 0.03}
PISTOL_LOW = {"pitch": -38.0, "back": 0.20, "drop": 0.24}
#: per rifle-like kind: the support point (Blender weapon space, the class reference model's LeftHandIK) and extra
#: low-ready pitch (deg): smg = wpn_hornet_9 (also the thumper launcher), sniper = wpn_heron_308
SUPPORT = {"rifle": (None, 0.0), "smg": (v3(0.0, 0.150, 0.016), 4.0), "sniper": (v3(0.0, 0.333, 0.024), -6.0)}
#: the LMG hip carry (wpn_rampart_lmg): grip at the right hip, muzzle forward and a little down and left; the support
#: hand 4 cm behind the LeftHandIK (still on the handguard): the marker is out of reach from a hip-held grip
LMG_HIP = {"grip": (0.16, 0.17, 1.03), "yaw": 10.0, "pitch": -6.0, "roll": -4.0, "left_ik": v3(0.0, 0.253, 0.029)}
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


def _mirror(wf: tuple) -> tuple:
    """The weapon frame mirrored across the body's mid-plane (x): the left gun of an akimbo pair."""
    R, o = wf
    M = A.np.diag([-1.0, 1.0, 1.0])
    return M @ R @ M, M @ o


def lmg_hip_frame(sk: Skeleton, t: float) -> tuple:
    k = sk.scale
    gx, gy, gz = LMG_HIP["grip"]
    o = v3(gx * k, gy * k + 0.004 * k * math.sin(TAU * t / 3.2), gz * k + 0.005 * k * math.sin(TAU * t / 1.6))
    return A.weapon_frame(o, yaw=LMG_HIP["yaw"], pitch=LMG_HIP["pitch"] + 0.6 * math.sin(TAU * t / 1.6),
                          roll=LMG_HIP["roll"])


def _hold(sk: Skeleton, kind: str, f: int, N: int, shift: bool) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    H.aim_body(sk, pose, kind not in ("pistol", "akimbo"))
    if kind == "lmg":                                      # the weight carried low: lean back a little, wider
        A.add_rot(pose, "spine", rxd(4.0))
        pose.hip = pose.hip + v3(0.0, -0.01 * k, -0.012 * k)
    w = math.sin(TAU * t / T)
    if shift:
        pose.hip = pose.hip + v3(SHIFT_M * k * w, 0.0, -0.004 * k * abs(w))
        A.add_rot(pose, "spine", A.ryd(-SHIFT_COUNTER_DEG * w))
    H.look(pose, yaw=14.0 * math.sin(TAU * t / T + 0.9), pitch=-2.0 + 1.5 * math.sin(TAU * 2 * t / T))
    if kind in SUPPORT:
        at, extra = SUPPORT[kind]
        R, o = rifle_low_frame(sk, t)
        if extra:
            butt = o + R @ (H.RIFLE["butt"] * k)
            R2 = rxd(extra) @ R
            R, o = R2, butt - R2 @ (H.RIFLE["butt"] * k)
        A.hold_weapon(sk, pose, (R, o), pole=v3(0.75, -0.2, -0.6), twist=0.6)
        H.rifle_support(sk, pose, (R, o), at=at)
        pose.hands["R"] = hand_shape("grip", 0.9)          # finger off the trigger at the low ready
    elif kind == "lmg":
        wf = lmg_hip_frame(sk, t)
        A.hold_weapon(sk, pose, wf, pole=v3(0.8, -0.1, -0.6), twist=0.6)
        H.rifle_support(sk, pose, wf, at=LMG_HIP["left_ik"], pole=v3(-0.5, -0.2, -0.85))
        pose.hands["R"] = hand_shape("grip", 0.9)
    elif kind == "pistol":
        H.hold_pistol(sk, pose, pistol_low_frame(sk, t))
        pose.hands["R"] = hand_shape("grip", 0.85)
    else:                                                  # akimbo: a pistol low ready in each hand
        wf = pistol_low_frame(sk, t)
        R, o = wf
        o = o + v3(0.11 * k, 0.0, 0.0)
        A.hold_weapon(sk, pose, (R, o), pole=v3(0.55, -0.15, -0.8), twist=0.6)
        A.hold_weapon(sk, pose, _mirror((rzd(-6.0) @ R, o + v3(0.0, 0.0, 0.015 * k))), pole=v3(-0.55, -0.15, -0.8),
                      sfx="L", twist=0.6)
        pose.hands["R"] = hand_shape("grip", 0.85)
        pose.hands["L"] = hand_shape("grip", 0.85)
    H.breathe(pose, t, T / 4.0, 1.1)
    return pose


def interact_armed(sk: Skeleton, level: str, f: int, N: int) -> Pose:
    """The shared interact_<level> stance, the left hand alone on the work point (centred), the right hand at the
    low carry."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = H.interact(level)(sk, f, N)
    zc, yc, along, palm = INTERACT[level]
    w = math.sin(TAU * (2 * t / T + 0.37))
    w2 = math.sin(TAU * (3 * t / T + 0.74))
    p = v3(-0.01 * k + 0.012 * k * w2, yc * k + 0.015 * k * w, zc * k + 0.012 * k * w2)
    H.hand_on(sk, pose, "L", p, H.unit(v3(*along) + v3(0.35, 0.0, 0.0)), H.unit(v3(*palm) + v3(0.25, 0.0, 0.0)),
              pole=v3(-0.9, -0.3, -0.5), along_share=0.6)
    pose.hands["L"] = hand_shape("grip", 0.8 + 0.2 * w)
    H.low_carry(sk, pose, 0.2 * w, crouch=level == "low")
    return pose


def throw_bag_armed(sk: Skeleton, solver: Solver, N: int):
    """The bag heaved one-handed (left) from the left hip forward-up, released at the same frame as throw_bag; the
    weapon stays low in the right hand."""
    k = sk.scale

    def left(pose: Pose, centre, yaw: float, along_up: float) -> None:
        R = rzd(yaw)
        H.hand_on(sk, pose, "L", centre, R @ v3(0.3, 0.3, along_up), R @ v3(1.0, 0.0, 0.0),
                  pole=R @ v3(-0.6, -0.5, -0.6), along_share=0.6)
        pose.hands["L"] = hand_shape("fist", 0.9)
        H.low_carry(sk, pose)

    carry = H._stand_key(sk)                                        # noqa: SLF001 - shared toolkit
    left(carry, v3(-0.12 * k, 0.10 * k, 0.92 * k), 0.0, -0.9)
    wind = H._stand_key(sk)                                         # noqa: SLF001
    wind.hip = wind.hip + v3(-0.03 * k, -0.05 * k, -0.07 * k)
    H.stand(sk, wind, spread=0.05, stagger_l=-0.10, stagger_r=0.12, yaw_l=24, yaw_r=10)
    H.spine(wind, lean=18, twist=22, chest_lean=10, chest_twist=16, neck=(-6, 0, -8), head=(-8, 0, -12), hips=(6, 0, 12))
    left(wind, v3(-0.30 * k, -0.20 * k, 0.70 * k), 40.0, -0.8)
    release = H._stand_key(sk)                                      # noqa: SLF001
    release.hip = release.hip + v3(0.02 * k, 0.09 * k, -0.02 * k)
    H.spine(release, lean=-4, twist=-12, chest_lean=-6, chest_twist=-10, neck=(-8, 0, 6), head=(-10, 0, 8),
            hips=(-2, 0, -8))
    left(release, v3(-0.06 * k, 0.50 * k, 1.55 * k), -10.0, 0.9)
    follow = H._stand_key(sk)                                       # noqa: SLF001
    H.spine(follow, lean=8, twist=-8, chest_lean=4, chest_twist=-5, head=(4, 0, 4))
    H.arm_fk(sk, follow, "L", add=30.0, swing=40.0, flex=30.0)
    follow.hands["L"] = hand_shape("relaxed", 0.8)
    H.low_carry(sk, follow)
    return H.Keys(solver, [(0, carry, "inout"), (9, wind, "inout"), (15, release, "in"), (21, follow, "out"),
                           (N, H._stand_key(sk), "inout")])          # noqa: SLF001


def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N = int(row["frames"])
        kind = name.rsplit("_", 1)[1]
        shift = name.startswith("idle_alert")

        def fn(f: int, N=N, kind=kind, shift=shift) -> Pose:
            return _hold(sk, kind, f, N, shift)
        out[name] = Clip(name, N, True, fn, float(row["speed"]), None, dict(row.get("events", {})), reach_fix=False)
    for name in [n for n in ARMED if n in table]:
        row = table[name]
        N = int(row["frames"])
        if name == "throw_bag_armed":
            out[name] = Clip(name, N, False, throw_bag_armed(sk, solver, N), float(row["speed"]), None,
                             dict(row.get("events", {})), reach_fix=False)
            continue
        level = name.split("_")[1]

        def fa(f: int, N=N, level=level) -> Pose:
            return interact_armed(sk, level, f, N)
        out[name] = Clip(name, N, True, fa, float(row["speed"]), None, dict(row.get("events", {})), reach_fix=False)
    return out


KEEP = NAMES + ARMED


def check_row(name: str, baked) -> str:
    return ""


def source_notes() -> dict:
    return {"weapon_holds": (
        "D-116 third-person weapon holds (crew bots / teammates, armed NPCs): idle_alert_<kind> replaces idle_alert "
        "while the body holds a weapon of that kind and is not aiming (PD2 low ready, both hands on the weapon, the "
        "support hand on the class reference model's LeftHandIK, a slow weight shift); hold_<kind> is the same upper "
        "body without the shift, to layer over walk / run / strafe* with a bone filter (" + ", ".join(UPPER_BONES)
        + "), weight 1.0, blend 0.2 s; aim_rifle / aim_pistol keep priority while aiming. Kinds by "
        "WeaponDef.weapon_class: ASSAULT_RIFLE, SHOTGUN -> rifle; SMG, SPECIAL (launcher) -> smg; SNIPER -> sniper; "
        "LMG -> lmg (a hip carry); PISTOL -> pistol, or akimbo when the weapon is an akimbo pair (a second "
        "WeaponVisual at HandL/Socket, the mirrored grip convention). Start each body's loop at a random offset "
        "(GameRng &\"anim_variants\")"),
        "armed_interactions": (
            "D-116 crew interaction audit: a crew body holding a weapon plays interact_low_armed / interact_mid_armed / "
            "interact_high_armed / throw_bag_armed instead of interact_* / throw_bag (same frames and events: the left "
            "hand does the work, the weapon stays in the right hand at a low carry by the thigh). Unarmed bodies "
            "(civilians, NPCs) keep the shared clips. carry_bag_walk now holds the bag strap with the LEFT hand at the "
            "left shoulder and keeps the weapon low in the right: the carried bag visual belongs on the left shoulder / "
            "back (Back socket), not in the right hand")}
