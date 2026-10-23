"""D polish #2 (LEAD 2026-10-21): ``idle_alert`` variety for the ``humanoid`` library. In the stealth coverage runs the
guards spend most of their time in ``idle_alert`` at posts and patrol stops, so a group reads as one synchronised troupe.
Private helper of ``anim_humanoid.py`` (pure numpy; wired like ``_anim_rt``).

* ``idle_alert_b`` (loop, ``FRAMES_B``): a wristwatch check (the left forearm comes up and turns the watch face in, the
  head drops to it and holds) and a slow weight shift onto the right leg.
* ``idle_alert_c`` (loop, ``FRAMES_C``): a thumb on the shoulder radio (the right hand to the left breast, the head tips
  towards it as if listening), then a long look round over the left shoulder with the chest following.
* ``idle_b`` / ``idle_c`` (LEAD 2026-10-23: calm guards at posts play ``idle``, not ``idle_alert``, so the most-seen
  stealth pose needs its own variety): ``idle_b`` (``FRAMES_IB``) a wristwatch check and a weight shift; ``idle_c``
  (``FRAMES_IC``) a stretch (shoulders rolled back, the chest opening, the head rolling side to side), then a look round
  over the right shoulder. ``idle`` is shared with civilians and unmasked crew, so neither variant uses guard gear (no
  radio). Same seam rule on ``idle`` (120 f): ``idle: [idle, idle_b, idle_c]`` (SOURCE ``idle_variants``).

Both are ``idle_alert`` (its own glances, breathing and arm lag, at the variant's loop length) plus a variant layer that
is zero at the loop seam (``_env`` ramps over ``ENV_RAMP`` of the loop). So frame 0 IS ``idle_alert`` frame 0 and every
clip that chains into or out of ``idle_alert`` chains into a variant unchanged. The loop lengths (90 / 150 / 174 f) are
unrelated, so three guards never re-sync. ENV A: a ``VARIANT_GROUPS`` row ``idle_alert: [idle_alert, idle_alert_b,
idle_alert_c]`` (SOURCE ``idle_alert_variants``), as for cower / queue_idle.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
import _anim_humanoid as H
from _anim import FPS, Clip, Pose, Skeleton, Solver, add_rot, rxd, ryd, rzd, smooth, v3

NAMES = ("idle_alert_b", "idle_alert_c", "idle_b", "idle_c")
KEEP = NAMES
FRAMES_B = 150   # = anim_humanoid.CLIPS row (literal there: the build reads the table without imports)
FRAMES_C = 174
FRAMES_IB = 162
FRAMES_IC = 198
ENV_RAMP = 0.12
#: idle_alert_b: the watch check window (fractions of the loop: rise, held, lower) and the weight shift's peak
WATCH = (0.30, 0.38, 0.56, 0.64)
SHIFT_PEAK = 0.75
#: idle_alert_c: the radio press window, then the look round
RADIO = (0.18, 0.25, 0.40, 0.47)
LOOK = (0.58, 0.66, 0.80, 0.88)
#: idle_b: the watch check window and the weight shift's peak; idle_c: the stretch, then the look round (right)
WATCH_I = (0.26, 0.35, 0.50, 0.59)
SHIFT_PEAK_I = 0.78
STRETCH = (0.14, 0.24, 0.42, 0.52)
LOOK_I = (0.60, 0.68, 0.80, 0.88)


def _env(u: float) -> float:
    return smooth(0.0, ENV_RAMP, u) * (1.0 - smooth(1.0 - ENV_RAMP, 1.0, u))


def _win(u: float, w: tuple) -> float:
    return smooth(w[0], w[1], u) * (1.0 - smooth(w[2], w[3], u))


def _arm_delta(sk: Skeleton, pose: Pose, sfx: str, w: float, swing: float = 0.0, add: float = 0.0, flex: float = 0.0,
               twist: float = 0.0, wrist: float = 0.0) -> None:
    """Add ``w`` x (forward swing, adduction, elbow flex, upper-arm twist, wrist flex) degrees on top of an FK arm."""
    if w <= 0.0:
        return
    sx = A.side_x(sfx)
    ua = A.unit(sk.tail[f"upper_arm.{sfx}"] - sk.head[f"upper_arm.{sfx}"])
    key = f"upper_arm.{sfx}"
    pose.D[key] = rxd(swing * w) @ ryd(sx * add * w) @ pose.D.get(key, np.eye(3)) @ A.rot(ua, A.rad(-sx * twist * w))
    fk = f"forearm.{sfx}"
    pose.local[fk] = pose.local.get(fk, np.eye(3)) @ rxd(-flex * w)
    hk = f"hand.{sfx}"
    pose.local[hk] = pose.local.get(hk, np.eye(3)) @ rxd(-wrist * w)


def idle_alert_b(sk: Skeleton, f: int, N: int) -> Pose:
    """idle_alert + a wristwatch check (left arm) and a slow weight shift onto the right leg."""
    u = f / N
    k = sk.scale
    pose = H.idle_alert(sk, f, N)
    env = _env(u)
    watch = _win(u, WATCH) * env
    _arm_delta(sk, pose, "L", watch, swing=40.0, add=0.0, flex=40.0, twist=70.0)
    add_rot(pose, "head", rxd(-22.0 * watch) @ rzd(10.0 * watch))
    add_rot(pose, "neck", rxd(-8.0 * watch))
    shift = math.exp(-((u - SHIFT_PEAK) / 0.12) ** 2) * env
    pose.hip = pose.hip + v3(0.035 * k * shift, 0.0, -0.008 * k * shift)
    add_rot(pose, "hips", ryd(-3.0 * shift))
    add_rot(pose, "chest", ryd(2.0 * shift))
    return pose


def idle_alert_c(sk: Skeleton, f: int, N: int) -> Pose:
    """idle_alert + a thumb on the shoulder radio (right hand to the left breast, the head tipped to listen), then a
    long look round over the left shoulder."""
    u = f / N
    pose = H.idle_alert(sk, f, N)
    env = _env(u)
    radio = _win(u, RADIO) * env
    _arm_delta(sk, pose, "R", radio, swing=35.0, add=20.0, flex=65.0, twist=70.0)
    add_rot(pose, "head", ryd(-12.0 * radio) @ rxd(6.0 * radio))
    look = _win(u, LOOK) * env
    add_rot(pose, "chest", rzd(14.0 * look))
    add_rot(pose, "neck", rzd(14.0 * look))
    add_rot(pose, "head", rzd(18.0 * look))
    return pose


def idle_b(sk: Skeleton, f: int, N: int) -> Pose:
    """idle + a wristwatch check (the hanging left arm comes up, the forearm turned so the face looks in, the head
    drops to it) and a slow weight shift onto the right leg."""
    u = f / N
    k = sk.scale
    pose = H.idle(sk, f, N)
    env = _env(u)
    watch = _win(u, WATCH_I) * env
    _arm_delta(sk, pose, "L", watch, swing=48.0, add=-6.0, flex=88.0, twist=72.0)
    add_rot(pose, "head", rxd(-24.0 * watch) @ rzd(12.0 * watch))
    add_rot(pose, "neck", rxd(-9.0 * watch))
    add_rot(pose, "chest", rzd(4.0 * watch))
    shift = math.exp(-((u - SHIFT_PEAK_I) / 0.12) ** 2) * env
    pose.hip = pose.hip + v3(0.032 * k * shift, 0.0, -0.008 * k * shift)
    add_rot(pose, "hips", ryd(-3.0 * shift))
    add_rot(pose, "chest", ryd(2.0 * shift))
    return pose


def idle_c(sk: Skeleton, f: int, N: int) -> Pose:
    """idle + a stretch (the shoulders roll back, the chest opens and lifts, the head rolls to one side and the other),
    then a long look round over the right shoulder, the chest following."""
    u = f / N
    pose = H.idle(sk, f, N)
    env = _env(u)
    st = _win(u, STRETCH) * env
    s0, s1 = STRETCH[1], STRETCH[2]
    roll = math.sin(math.pi * 2.0 * min(1.0, max(0.0, (u - s0) / (s1 - s0)))) * st
    # +x = back (idle_b's -x drops the head to the watch): the chest opens and lifts, the head tips back and rolls
    add_rot(pose, "spine", rxd(4.0 * st))
    add_rot(pose, "chest", rxd(7.0 * st))
    add_rot(pose, "neck", rxd(8.0 * st) @ ryd(9.0 * roll))
    add_rot(pose, "head", ryd(12.0 * roll) @ rxd(6.0 * st))
    for sfx in ("L", "R"):
        _arm_delta(sk, pose, sfx, st, swing=-16.0, add=-8.0, flex=10.0, twist=-12.0)
    look = _win(u, LOOK_I) * env
    add_rot(pose, "chest", rzd(-14.0 * look))
    add_rot(pose, "neck", rzd(-14.0 * look))
    add_rot(pose, "head", rzd(-20.0 * look))
    return pose


BUILDERS = {"idle_alert_b": idle_alert_b, "idle_alert_c": idle_alert_c, "idle_b": idle_b, "idle_c": idle_c}


def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N, loop, speed, ev = int(row["frames"]), bool(row["loop"]), float(row["speed"]), dict(row.get("events", {}))
        fn = BUILDERS[name]
        out[name] = Clip(name, N, loop, (lambda f, fn=fn, N=N: fn(sk, f, N)), speed, None, ev, reach_fix=True)
    return out


def check_row(sk: Skeleton, table: dict, name: str, baked, keep: dict) -> str:
    from _anim_d304 import pose_err  # noqa: PLC0415

    base = "idle_alert" if name.startswith("idle_alert") else "idle"
    txt = ""
    if base in keep:
        txt += f" start_err={pose_err(baked.frames[0], keep[base].frames[0]):.2f}mm"
    return txt


def source_notes(sk: Skeleton, table: dict, keep: dict) -> dict[str, str]:
    return {"idle_alert_variants": (
        "D polish #2: idle_alert, idle_alert_b, idle_alert_c (loops 90 / 150 / 174 f, speed 0, in place). b = a wristwatch "
        "check and a slow weight shift; c = a thumb on the shoulder radio, then a look round. Frame 0 of each IS "
        "idle_alert frame 0 and the variant layer is zero at the seam, so anything that chains into or out of "
        "idle_alert chains into a variant unchanged. ENV A: VARIANT_GROUPS idle_alert: [idle_alert, idle_alert_b, "
        "idle_alert_c] (the per-body index, as for cower / queue_idle)."),
        "idle_variants": (
        "D polish #2 (calm posts): idle, idle_b, idle_c (loops 120 / 162 / 198 f, speed 0, in place). b = a wristwatch "
        "check and a slow weight shift; c = a stretch (shoulders back, the head rolling), then a look round over the right "
        "shoulder. idle is shared with civilians and unmasked crew, so no guard gear is used. Frame 0 of each IS idle "
        "frame 0 and the variant layer is zero at the seam. ENV A: VARIANT_GROUPS idle: [idle, idle_b, idle_c] (the "
        "per-body index, as for cower / queue_idle; idle_b <-> idle_alert_b, idle_c <-> idle_alert_c: one personality).")}
