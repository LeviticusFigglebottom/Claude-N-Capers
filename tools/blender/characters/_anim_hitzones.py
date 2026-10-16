"""D-116 hit-zone flinches for the ``humanoid`` library (PD2-style non-lethal hit reacts by where the bullet landed).
Private helper of ``anim_humanoid.py`` (pure numpy).

Clips (one entry each in ``NAMES`` / ``anim_humanoid.CLIPS``): ``hit_head`` (the head snaps back), ``hit_chest`` (the
torso jolts back, the knees give), ``hit_shoulder_l`` / ``hit_shoulder_r`` (the hit shoulder is knocked back, the chest
twists toward it, that arm goes limp), ``hit_leg_l`` / ``hit_leg_r`` (the hit leg buckles, the body dips onto it, a
small in-place catch step back with that foot that returns to its spot).

Every clip starts and ends exactly on ``idle_alert`` frame 0 (the combat stand), authored as deltas on that pose, the
root never moves and both feet stay planted (except the hit foot's step in the leg flinches). ``impact`` = the peak.
"""

from __future__ import annotations

import dataclasses

import numpy as np

import _anim as A
from _anim import Clip, Keys, Pose, Skeleton, Solver, add_rot, arm_fk, hand_shape, rxd, ryd, rzd, v3

NAMES = ("hit_head", "hit_chest", "hit_shoulder_l", "hit_shoulder_r", "hit_leg_l", "hit_leg_r")
#: The pose every flinch starts and ends on (clip, frame).
SOURCE_POSE = ("idle_alert", 0)
#: idle_alert's arm carry (``_anim_humanoid.idle_alert`` at frame 0).
CARRY = dict(add=30.0, swing=14.0, flex=48.0, twist=14.0)
#: Leg flinch catch step: the hit foot lands this far behind its spot (m at 1.78 m) and lifts this high.
STEP_BACK = 0.07
STEP_LIFT = 0.045


def _src(sk: Skeleton, solver: Solver) -> Pose:
    import _anim_d304 as d304  # noqa: PLC0415

    return d304.src_pose(sk, solver, *SOURCE_POSE)


def trunk(pose: Pose, bone: str, pitch: float = 0.0, roll: float = 0.0, yaw: float = 0.0) -> None:
    """Delta on a trunk bone in degrees (the ``spine()`` axes): pitch > 0 forward, roll > 0 toward the right, yaw > 0
    turns left."""
    add_rot(pose, bone, rzd(yaw) @ ryd(roll) @ rxd(-pitch))


def arm(sk: Skeleton, pose: Pose, sfx: str, hand: str = "loose_fist", amount: float = 0.8, **d) -> None:
    """idle_alert's arm carry with ``d`` added to its ``arm_fk`` angles."""
    a = {key: CARRY.get(key, 0.0) + float(d.get(key, 0.0)) for key in set(CARRY) | set(d)}
    arm_fk(sk, pose, sfx, **a)
    pose.hands[sfx] = hand_shape(hand, amount)


def foot(pose: Pose, base: Pose, sfx: str, k: float, dy: float = 0.0, dz: float = 0.0, pitch: float = 0.0) -> None:
    """The ``sfx`` leg goal of ``base`` moved by (0, dy, dz) m and pitched ``pitch`` deg (+ = toes up)."""
    g = base.legs[sfx]
    pose.legs[sfx] = dataclasses.replace(g, ankle=g.ankle + v3(0.0, dy * k, dz * k), foot=rxd(pitch) @ g.foot,
                                         pole=None if g.pole is None else g.pole.copy())


def hit_head(sk: Skeleton, solver: Solver, N: int, impact: int) -> Keys:
    """Head shot that did not kill (helmet, armour): the head whips back and a little aside, the chest follows a
    touch, the hands jerk up; the head rebounds forward past neutral, settles."""
    k = sk.scale
    base = _src(sk, solver)
    snap = base.copy()
    snap.hip = snap.hip + v3(0.0, -0.012 * k, -0.012 * k)
    trunk(snap, "spine", pitch=-2.0)
    trunk(snap, "chest", pitch=-5.0, yaw=3.0)
    trunk(snap, "neck", pitch=-10.0, yaw=3.0)
    trunk(snap, "head", pitch=-22.0, roll=6.0, yaw=6.0)
    for sfx, _sx in A.SIDES:
        arm(sk, snap, sfx, "spread", 0.7, swing=6.0, flex=18.0, out=6.0, clav_up=5.0)
    hold = base.copy()
    hold.hip = hold.hip + v3(0.0, -0.01 * k, -0.016 * k)
    trunk(hold, "chest", pitch=-3.0, yaw=2.0)
    trunk(hold, "neck", pitch=-7.0, yaw=2.0)
    trunk(hold, "head", pitch=-14.0, roll=4.0, yaw=4.0)
    for sfx, _sx in A.SIDES:
        arm(sk, hold, sfx, "claw", 0.6, swing=4.0, flex=12.0, out=4.0, clav_up=3.0)
    rebound = base.copy()
    rebound.hip = rebound.hip + v3(0.0, 0.004 * k, -0.01 * k)
    trunk(rebound, "chest", pitch=2.0)
    trunk(rebound, "neck", pitch=3.0)
    trunk(rebound, "head", pitch=6.0, roll=-1.5)
    return Keys(solver, [(0, base, "inout"), (impact, snap, "snap"), (impact + 3, hold, "inout"),
                         (impact + 7, rebound, "inout"), (N, base, "inout")])


def hit_chest(sk: Skeleton, solver: Solver, N: int, impact: int) -> Keys:
    """Centre-mass hit: the chest is punched back, hips back and down (knees give), the head lags forward, the
    forearms curl in toward the chest; recovers with a small forward lean."""
    k = sk.scale
    base = _src(sk, solver)
    jolt = base.copy()
    # lead review: a stronger punch than the first cut (hips 3.5 cm / chest 10 deg back read weakest of the six)
    jolt.hip = jolt.hip + v3(0.0, -0.055 * k, -0.035 * k)
    trunk(jolt, "hips", pitch=-5.0)
    trunk(jolt, "spine", pitch=-9.0)
    trunk(jolt, "chest", pitch=-15.0)
    trunk(jolt, "neck", pitch=9.0)
    trunk(jolt, "head", pitch=8.0)
    for sfx, _sx in A.SIDES:
        arm(sk, jolt, sfx, "claw", 0.85, add=-12.0, swing=18.0, flex=28.0, twist=8.0, clav_fwd=9.0)
    curl = base.copy()
    curl.hip = curl.hip + v3(0.0, -0.018 * k, -0.03 * k)
    trunk(curl, "hips", pitch=-1.0)
    trunk(curl, "spine", pitch=3.0)
    trunk(curl, "chest", pitch=2.0)
    trunk(curl, "neck", pitch=3.0)
    trunk(curl, "head", pitch=4.0)
    for sfx, _sx in A.SIDES:
        arm(sk, curl, sfx, "claw", 0.9, add=-6.0, swing=12.0, flex=30.0, twist=10.0, clav_fwd=8.0)
    recover = base.copy()
    recover.hip = recover.hip + v3(0.0, 0.004 * k, -0.012 * k)
    trunk(recover, "spine", pitch=3.0)
    trunk(recover, "chest", pitch=2.0)
    return Keys(solver, [(0, base, "inout"), (impact, jolt, "snap"), (impact + 4, curl, "inout"),
                         (impact + 8, recover, "inout"), (N, base, "inout")])


def hit_shoulder(sk: Skeleton, solver: Solver, N: int, impact: int, sfx: str) -> Keys:
    """Shoulder / arm hit on the ``sfx`` side: that shoulder is knocked back (the chest twists toward the hit side and
    dips it), the hit arm flops back and down, the other arm flares; the head turns toward the hit; the near hand comes
    in toward the hurt shoulder, then the twist recovers a touch past neutral."""
    k = sk.scale
    s = 1.0 if sfx == "L" else -1.0          # + = twist left (the left shoulder goes back)
    far = "R" if sfx == "L" else "L"
    base = _src(sk, solver)
    knock = base.copy()
    knock.hip = knock.hip + v3(0.0, -0.012 * k, -0.018 * k)
    trunk(knock, "hips", yaw=s * 4.0)
    trunk(knock, "spine", yaw=s * 9.0, roll=s * -3.0, pitch=-2.0)
    trunk(knock, "chest", yaw=s * 15.0, roll=s * -5.0, pitch=-3.0)
    trunk(knock, "neck", yaw=-s * 4.0)
    trunk(knock, "head", yaw=s * 6.0, roll=s * -6.0, pitch=-4.0)
    arm(sk, knock, sfx, "spread", 0.7, add=8.0, swing=-22.0, flex=-22.0, twist=-6.0, clav_fwd=-14.0, clav_up=-4.0)
    arm(sk, knock, far, "spread", 0.6, out=14.0, swing=4.0, flex=6.0, clav_up=3.0)
    clutch = base.copy()
    clutch.hip = clutch.hip + v3(0.0, -0.008 * k, -0.02 * k)
    trunk(clutch, "hips", yaw=s * 3.0)
    trunk(clutch, "spine", yaw=s * 6.0, roll=s * -2.0, pitch=2.0)
    trunk(clutch, "chest", yaw=s * 9.0, roll=s * -3.0, pitch=2.0)
    trunk(clutch, "head", yaw=s * 10.0, pitch=8.0, roll=s * -3.0)
    arm(sk, clutch, sfx, "relaxed", 0.9, add=4.0, swing=-10.0, flex=-14.0, clav_fwd=-8.0, clav_up=-3.0)
    arm(sk, clutch, far, "claw", 0.8, add=-4.0, swing=28.0, flex=40.0, twist=12.0, clav_fwd=6.0)
    settle = base.copy()
    settle.hip = settle.hip + v3(0.0, 0.0, -0.008 * k)
    trunk(settle, "spine", yaw=-s * 2.0)
    trunk(settle, "chest", yaw=-s * 3.0)
    trunk(settle, "head", yaw=s * 3.0)
    return Keys(solver, [(0, base, "inout"), (impact, knock, "snap"), (impact + 4, clutch, "inout"),
                         (impact + 8, settle, "inout"), (N, base, "inout")])


def hit_leg(sk: Skeleton, solver: Solver, N: int, impact: int, sfx: str) -> Keys:
    """Leg hit on the ``sfx`` side: the hit leg buckles (the hips drop and sway over it, the trunk hunches toward it),
    then the weight goes onto the other leg, the hit foot lifts and catches the body a short step back, lifts again
    and returns to its spot; the other foot never moves."""
    k = sk.scale
    sx = -1.0 if sfx == "L" else 1.0        # the hit side along x (left = -x)
    good = "R" if sfx == "L" else "L"
    base = _src(sk, solver)
    buckle = base.copy()
    buckle.hip = buckle.hip + v3(sx * 0.03 * k, -0.015 * k, -0.075 * k)
    trunk(buckle, "hips", roll=sx * 6.0, pitch=4.0)
    trunk(buckle, "spine", roll=-sx * 2.0, pitch=8.0)
    trunk(buckle, "chest", roll=-sx * 3.0, pitch=6.0)
    trunk(buckle, "head", pitch=10.0, yaw=-sx * 6.0)
    arm(sk, buckle, sfx, "spread", 0.7, add=-6.0, out=18.0, swing=-6.0, flex=-14.0)
    arm(sk, buckle, good, "spread", 0.6, out=10.0, flex=6.0)
    # weight onto the good leg, the hit foot lifts and pulls back
    lift = base.copy()
    lift.hip = lift.hip + v3(-sx * 0.035 * k, -0.025 * k, -0.06 * k)
    trunk(lift, "hips", roll=-sx * 3.0, pitch=3.0)
    trunk(lift, "spine", roll=sx * 2.0, pitch=6.0)
    trunk(lift, "chest", pitch=4.0)
    trunk(lift, "head", pitch=6.0, yaw=-sx * 4.0)
    foot(lift, base, sfx, k, dy=-STEP_BACK * 0.6, dz=STEP_LIFT, pitch=-12.0)
    arm(sk, lift, sfx, "spread", 0.6, out=12.0, swing=-4.0, flex=-8.0)
    arm(sk, lift, good, "loose_fist", 0.7, out=6.0)
    # the catch: the hit foot plants a short step back, the weight comes back over it
    catch = base.copy()
    catch.hip = catch.hip + v3(sx * 0.01 * k, -0.035 * k, -0.05 * k)
    trunk(catch, "hips", roll=sx * 2.0, pitch=2.0)
    trunk(catch, "spine", pitch=5.0)
    trunk(catch, "chest", pitch=3.0)
    trunk(catch, "head", pitch=4.0)
    foot(catch, base, sfx, k, dy=-STEP_BACK)
    arm(sk, catch, sfx, "loose_fist", 0.7, out=6.0, flex=-4.0)
    # back onto the good leg, the hit foot lifts toward its spot
    back = base.copy()
    back.hip = back.hip + v3(-sx * 0.025 * k, -0.02 * k, -0.035 * k)
    trunk(back, "spine", pitch=3.0)
    trunk(back, "chest", pitch=2.0)
    foot(back, base, sfx, k, dy=-STEP_BACK * 0.4, dz=STEP_LIFT * 0.7, pitch=-6.0)
    home = base.copy()
    home.hip = home.hip + v3(0.0, -0.006 * k, -0.018 * k)
    return Keys(solver, [(0, base, "inout"), (impact, buckle, "snap"), (impact + 3, lift, "inout"),
                         (impact + 5, catch, "in"), (impact + 8, back, "inout"), (impact + 10, home, "in"),
                         (N, base, "inout")])


#: name -> the planted feet ("LR" = both on every frame; the leg flinches step with the hit foot) and the step frames
#: of the hit foot (its plant back, its return to the spot), relative to ``impact``.
STEPS = {"hit_leg_l": ("L", 5, 10), "hit_leg_r": ("R", 5, 10)}


def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N, ev = int(row["frames"]), dict(row.get("events", {}))
        at = int(ev["impact"])
        if name == "hit_head":
            fn = hit_head(sk, solver, N, at)
        elif name == "hit_chest":
            fn = hit_chest(sk, solver, N, at)
        elif name.startswith("hit_shoulder"):
            fn = hit_shoulder(sk, solver, N, at, name[-1].upper())
        else:
            fn = hit_leg(sk, solver, N, at, name[-1].upper())
        out[name] = Clip(name, N, False, fn, float(row["speed"]), None, ev, reach_fix=False)
    return out


# =============================================================================================
# checks and SOURCE.txt notes
# =============================================================================================
KEEP = NAMES + (SOURCE_POSE[0],)


def foot_drift(frames: list, sfx: str) -> float:
    """Worst distance (mm) of the ``sfx`` foot / toe heads from frame 0."""
    s0 = frames[0]
    return max(float(np.linalg.norm(s.P[b] - s0.P[b])) for s in frames for b in (f"foot.{sfx}", f"toe.{sfx}")) * 1000.0


def check_row(sk: Skeleton, table: dict, name: str, baked, keep: dict) -> str:
    from _anim_d304 import pose_err  # noqa: PLC0415

    fr = baked.frames
    txt = ""
    src = keep.get(SOURCE_POSE[0])
    if src is not None:
        s0 = src.frames[SOURCE_POSE[1]]
        txt += f" start_err={pose_err(fr[0], s0):.2f}mm end_err={pose_err(fr[-1], s0):.2f}mm"
    stepping = STEPS.get(name, ("",))[0]
    for sfx in "LR":
        txt += f" drift_{sfx}={foot_drift(fr, sfx):.1f}mm" + ("(step)" if sfx == stepping else "")
    return txt


def source_notes(sk: Skeleton, table: dict, keep: dict) -> dict[str, str]:
    out: dict[str, str] = {}
    have = [n for n in NAMES if n in table]
    if not have:
        return out
    hip_h = float(sk.head["hips"][2])
    out["hit_zones"] = (
        "D-116 non-lethal flinch by hit zone (pick from the damage info `zone` + the hit `position` in the body's root "
        "space): HEAD -> hit_head; BODY -> hit_chest; LIMB above the hips joint (y > "
        f"{hip_h:.2f} m x motion_scale) -> hit_shoulder_l if the hit is on the body's left (root-space x < 0) else "
        "hit_shoulder_r; LIMB below it -> hit_leg_l / hit_leg_r by the same side test. The directional hit_react set "
        "stays the fallback when no zone is known. Each starts and ends exactly on idle_alert frame 0, root fixed, "
        "both feet planted except the hit foot's in-place catch step in hit_leg_* (back "
        f"{STEP_BACK * 100:.0f} cm and home again); `impact` = the peak. Blend: absolute poses, not rest-relative deltas "
        "(do not feed them raw to AnimationNodeAdd2). Standing / idle_alert / unarmed: OneShot full body, weight 1.0, "
        "fade in 0.03 s, out 0.12 s. Over aim_* / fire / locomotion: OneShot filtered to hips, spine, chest, neck, "
        "head (+ clavicle/upper_arm/forearm/hand of the hit side for hit_shoulder_* when the gun hand is not that side), "
        "weight 0.7 (hit_head 0.9); never the legs while moving (hit_leg_* then = its trunk only). For a true layer, "
        "bake an additive copy at load (per track: rest * inverse(frame 0) * key) and Add2 it at 1.0.")
    rows = [f"{n}:{check_row(sk, table, n, keep[n], keep)}" for n in have if n in keep]
    if rows:
        out["hit_zone_checks"] = "; ".join(rows)
    return out
