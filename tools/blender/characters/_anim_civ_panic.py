"""D-116 civilian panic variety for the ``humanoid`` library: per-body variants of the loud civilian set so a Gallery
Night crowd of panicked patrons reads as individuals, not one troupe. Private helper of ``anim_humanoid.py`` (pure
numpy; the approach of ``_anim_surrender``).

Groups (``GROUPS``; the first member is the original, A picks one member per NPC, SOURCE ``civ_panic_variants``):

* ``cower`` / ``cower_b`` / ``cower_c`` (loops, 60 / 52 / 46 f, stationary): the original = crouched on the balls of the
  feet, hunched, forearms crossed over the crown. ``_b`` = squatting low on flat feet (on the heels), knees wide and up,
  the trunk fairly upright with the head tucked down, forearms wrapped over the top of the head with the elbows out
  wide (a wide, compact diamond where ``cower`` is a forward ball), rocking. ``_c`` = standing, pressed back (hips and shoulders back as against a wall, chin up), hands up
  beside the face with the palms out, elbows at the ribs, quick glances left and right that hold. Each period differs
  (60 / 52 / 46) and every periodic layer closes per loop, so a room never re-syncs.
* ``flee`` / ``flee_b`` / ``flee_c`` (loops, 20 f, 4.0 m/s): the SAME gait (``_anim_humanoid.gaits`` "flee": frames,
  speed, foot plants, hips) with another upper body, so A's speed_scale and foot sync work unchanged and the legs are
  identical frame for frame. ``_b`` = hunched, shoulders up, forearms tucked against the chest, head down; ``_c`` =
  looking back over the left shoulder, the left forearm up over the head as a shield, the right arm pumping.
* ``panic_start`` (one-shot, 24 f, in place, ``flinch`` event at the jolt, frame 2): the startle when the alarm or gunfire hits:
  from ``idle`` frame 0 a flinch (shoulders up, head ducked, arms snap up), a duck with a glance toward the noise, and
  down into EXACTLY ``cower`` frame 0. Feet stay on their spots (the heels rise onto the balls).
"""

from __future__ import annotations

import dataclasses
import math

import numpy as np

import _anim as A
from _anim import FPS, TAU, Clip, Keys, Pose, Skeleton, Solver, add_rot, arm_fk, hand_on, hand_shape, plant, rxd, \
    rzd, spine, stand, v3
from _anim_surrender import _breath, _cyc, _tremble

#: variant groups: the original first (A picks a member per NPC, see SOURCE `civ_panic_variants`)
GROUPS = {
    "cower": ("cower", "cower_b", "cower_c"),
    "flee": ("flee", "flee_b", "flee_c"),
}
ORIGINALS = ("cower", "flee")
#: the clips this module builds (each one entry in anim_humanoid.CLIPS)
NAMES = ("cower_b", "cower_c", "flee_b", "flee_c", "panic_start")
#: panic_start: (clip, frame) its first / last frame equals
STARTS = {"panic_start": ("idle", 0)}
ENDS = {"panic_start": ("cower", 0)}
FLEE_VARIANTS = ("flee_b", "flee_c")


def _look(pose: Pose, yaw: float = 0.0, pitch: float = 0.0, tilt: float = 0.0) -> None:
    import _anim_humanoid as H  # noqa: PLC0415

    H.look(pose, yaw=yaw, pitch=pitch, tilt=tilt)


def _hold(u: float, n: int, ph: float = 0.0, sharp: float = 2.6) -> float:
    """-1..1 with ``n`` whole cycles per loop that dwells at the extremes (a glance that holds, then snaps across)."""
    s = math.sin(TAU * n * u + ph)
    return math.tanh(sharp * s) / math.tanh(sharp)


# =============================================================================================
# cower variants
# =============================================================================================
def cower_b(sk: Skeleton, f: int, N: int) -> Pose:
    """Squatting low on flat feet (sitting on the heels), knees wide and up, the trunk fairly upright with the head
    tucked down, forearms wrapped over the top of the head with the elbows out wide; rocks on the heels twice per
    loop, swaying once, trembling."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    rock = _cyc(t, T, 2, 0.0)
    sway = _cyc(t, T, 1, 0.9)
    pose = Pose()
    pose.hip = v3(0.012 * k * sway, (-0.12 - 0.015 * rock) * k, (-0.62 + 0.006 * rock) * k)
    for sfx in ("L", "R"):
        sx = A.side_x(sfx)
        plant(sk, pose, sfx, (sx * 0.09 * k, 0.03 * k, 0.0), yaw=-sx * 22.0, pole=v3(sx * 0.6, 1.0, 0.0))
    spine(pose, lean=14.0 + 3.0 * rock, chest_lean=12.0 + 2.0 * rock, side=1.5 * sway, neck=(22, 0, 0),
          head=(18, 0, 0), hips=(10, 0, 0))
    _tremble(pose, t, T, 1.4)
    _breath(pose, _cyc(t, T, 3, 0.8), 1.4)
    pre = Solver(sk).solve(pose)
    Wh = pre.W["head"]
    for sfx, sx in A.SIDES:
        # forearms wrapped over the top of the head, the hands clasping the crown, elbows out wide
        p = A.bone_point(pre, sk, "head", v3(sx * 0.035 * k, -0.035 * k, 0.16 * k))
        hand_on(sk, pose, sfx, p, Wh @ v3(-sx * 0.45, -0.75, 0.25), Wh @ v3(sx * 0.2, 0.0, -1.0),
                pole=pre.W["chest"] @ v3(sx * 1.0, 0.45, 0.0), along_share=0.45)
        pose.hands[sfx] = hand_shape("relaxed", 1.2)
    return pose


def cower_c(sk: Skeleton, f: int, N: int) -> Pose:
    """Standing pressed back (hips and shoulders back, chin up), hands up beside the face palms out, elbows at the
    ribs; glances left and right (two per loop, each one holds), short fast breaths."""
    t = f / FPS
    T = N / FPS
    u = f / N
    k = sk.scale
    g = _hold(u, 1, 0.6)
    pose = Pose()
    pose.hip = v3(0.008 * k * g, -0.065 * k, -0.05 * k)
    stand(sk, pose, spread=0.05, stagger_l=0.05, stagger_r=0.02, yaw_l=12, yaw_r=9)
    spine(pose, lean=-4.0, chest_lean=-7.0, side=-1.5 * g, neck=(-6, 0, 0), head=(-4, 0, 0), hips=(-5, 0, 0))
    _look(pose, yaw=38.0 * g, pitch=-4.0, tilt=-5.0 * g)
    add_rot(pose, "chest", rzd(6.0 * g))
    _tremble(pose, t, T, 0.9)
    _breath(pose, _cyc(t, T, 4, 0.3), 1.5)
    pre = Solver(sk).solve(pose)
    Wc = pre.W["chest"]
    for sfx, sx in A.SIDES:
        lift = 0.012 * k * _cyc(t, T, 2, 1.0 + sx)
        p = A.bone_point(pre, sk, "chest", v3(sx * 0.20 * k, 0.17 * k, 0.33 * k + lift))
        hand_on(sk, pose, sfx, p, Wc @ v3(sx * 0.15, 0.15, 1.0), Wc @ v3(0.0, 1.0, 0.1),
                pole=Wc @ v3(sx * 0.6, 0.1, -1.0), along_share=0.45, clav=0.7)
        pose.hands[sfx] = hand_shape("spread", 0.8)
    return pose


# =============================================================================================
# flee variants (the flee gait, another upper body)
# =============================================================================================
def _flee_upper_b(sk: Skeleton, pose: Pose, ph: float, f: int) -> None:
    """Hunched: shoulders up and forward, the arms tucked in tight, the forearms clutched across the belly (small
    pumps), head down. (``flee`` holds its forearms up by the head.)"""
    add_rot(pose, "spine", rxd(-10.0))
    add_rot(pose, "chest", rxd(-14.0))
    for sfx, sgn in (("R", 1.0), ("L", -1.0)):
        sw = sgn * 8.0 * math.cos(TAU * ph)
        arm_fk(sk, pose, sfx, add=44.0, swing=12.0 + sw, flex=96.0 + 4.0 * math.sin(TAU * ph), twist=58.0,
               clav_up=14.0, clav_fwd=12.0, wrist_flex=10.0)
        pose.hands[sfx] = hand_shape("loose_fist", 1.0)
    add_rot(pose, "neck", rxd(-16.0))
    add_rot(pose, "head", rxd(-14.0))


def _flee_upper_c(sk: Skeleton, pose: Pose, ph: float, f: int) -> None:
    """Looking back over the left shoulder, the left forearm over the head as a shield, the right arm pumping."""
    add_rot(pose, "chest", rzd(16.0))
    _look(pose, yaw=62.0 + 4.0 * math.sin(TAU * ph), pitch=-4.0, tilt=6.0)
    sw = 30.0 * math.cos(TAU * ph)
    arm_fk(sk, pose, "R", add=30.0, swing=sw + 4.0, flex=84.0 + 10.0 * max(0.0, sw / 30.0), twist=8.0)
    pose.hands["R"] = hand_shape("loose_fist", 1.0)
    pre = Solver(sk).solve(pose)
    Wh = pre.W["head"]
    bob = 0.01 * sk.scale * math.sin(TAU * 2 * ph)
    p = A.bone_point(pre, sk, "head", v3(0.02 * sk.scale, 0.0, 0.17 * sk.scale + bob))
    hand_on(sk, pose, "L", p, Wh @ v3(1.0, 0.25, 0.15), Wh @ v3(0.0, 0.0, -1.0),
            pole=Wh @ v3(-1.0, 0.2, 0.35), along_share=0.5)
    pose.hands["L"] = hand_shape("spread", 0.6)


UPPERS = {"flee_b": _flee_upper_b, "flee_c": _flee_upper_c}


def flee_gait(table_row: dict, upper):
    """The ``flee`` gait (``_anim_humanoid.gaits``) at this row's frames / speed with ``upper`` as its upper body."""
    import _anim_humanoid as H  # noqa: PLC0415

    g = H.gaits({"flee": table_row})["flee"]
    return dataclasses.replace(g, upper=upper)


# =============================================================================================
# panic_start (idle frame 0 -> cower frame 0)
# =============================================================================================
def _feet(sk: Skeleton, pose: Pose, w: float) -> None:
    """Feet from idle's flat stand (w = 0) toward cower's planted balls (w = 1): the heels rise about the balls."""
    k = sk.scale
    for sfx in ("L", "R"):
        sx = A.side_x(sfx)
        plant(sk, pose, sfx, (sx * 0.03 * k * w, -0.03 * k * w, 0.0), yaw=-sx * (6.0 + 4.0 * w), pitch=-30.0 * w,
              toe=30.0 * w, pivot="ball", pole=v3(sx * (0.12 + 0.23 * w), 1.0, 0.0))


def _panic_start(sk: Skeleton, solver: Solver, N: int):
    import _anim_humanoid as H  # noqa: PLC0415

    k = sk.scale
    s = N / 24.0
    start = H._stand_key(sk)
    # 2: the jolt: shoulders up, the knees give, the arms start up (the `flinch` event)
    jolt = Pose()
    jolt.hip = v3(0.0, -0.015 * k, -0.045 * k)
    _feet(sk, jolt, 0.0)
    spine(jolt, lean=3.0, chest_lean=5.0, twist=-4.0, neck=(8, 0, 0), head=(6, -3, -6), hips=(2, 0, 0))
    for sfx, sx in A.SIDES:
        arm_fk(sk, jolt, sfx, add=32.0, swing=30.0, flex=58.0, twist=16.0, clav_up=14.0, clav_fwd=4.0)
        jolt.hands[sfx] = hand_shape("spread", 0.9)
    # 5: the flinch: knees dip, head ducks away, the forearms up in front of the face
    flinch = Pose()
    flinch.hip = v3(0.0, -0.035 * k, -0.10 * k)
    _feet(sk, flinch, 0.1)
    spine(flinch, lean=9.0, chest_lean=11.0, twist=-6.0, neck=(14, 0, 0), head=(10, -4, -8), hips=(5, 0, 0))
    for sfx, sx in A.SIDES:
        arm_fk(sk, flinch, sfx, add=24.0, swing=66.0, flex=118.0, twist=26.0, clav_up=16.0, clav_fwd=6.0)
        flinch.hands[sfx] = hand_shape("spread", 0.9)
    # 10: ducking, a glance toward the noise (left), the forearms rising over the head
    duck = Pose()
    duck.hip = v3(0.0, -0.08 * k, -0.27 * k)
    _feet(sk, duck, 0.5)
    spine(duck, lean=18.0, chest_lean=16.0, twist=8.0, neck=(6, 0, 18), head=(2, 0, 16), hips=(16, 0, 0))
    for sfx, sx in A.SIDES:
        arm_fk(sk, duck, sfx, add=18.0, swing=95.0, flex=125.0, twist=40.0, clav_up=14.0, clav_fwd=6.0)
        duck.hands[sfx] = hand_shape("claw", 0.6)
    # 16: lower, the head turning back down, the hands reaching for the crown
    low = Pose()
    low.hip = v3(0.0, -0.12 * k, -0.44 * k)
    _feet(sk, low, 0.88)
    spine(low, lean=26.0, chest_lean=22.0, twist=2.0, neck=(16, 0, 6), head=(12, 0, 4), hips=(26, 0, 0))
    pre = Solver(sk).solve(low)
    for sfx, sx in A.SIDES:
        p = A.bone_point(pre, sk, "head", v3(-sx * 0.01 * k, 0.05 * k, 0.19 * k))
        hand_on(sk, low, sfx, p, pre.W["head"] @ v3(-sx * 0.75, -0.3, 0.1), pre.W["head"] @ v3(0.0, 0.1, -1.0),
                pole=pre.W["chest"] @ v3(sx * 0.6, 0.8, -0.2), along_share=0.4)
        low.hands[sfx] = hand_shape("claw", 0.6)
    end = H.cower(sk, 0, 60)
    keys = Keys(solver, [(0, start, "inout"), (round(2 * s), jolt, "out"), (round(5 * s), flinch, "inout"),
                         (round(10 * s), duck, "inout"), (round(16 * s), low, "inout"), (N, end, "settle")])
    probe = A.probe_for(sk)

    def fn(f: int) -> Pose:
        # cower is baked with no_sink (lifted where its skin would go below the floor): ramp the same lift in, so the
        # last frame equals cower's baked frame 0 while frame 0 stays idle's (no_sink would lift a standing pose by the
        # probe margin)
        pose = keys(f)
        w = A.smooth(0.0, 10.0 * s, float(f))
        if w <= 0.0:
            return pose
        for _it in range(3):
            low_z = probe.lowest(solver.solve(pose))
            if low_z >= -2e-4:
                break
            A.lift(pose, -low_z * w)
            if w < 1.0:
                break
        return pose
    return fn


# =============================================================================================
# table hook
# =============================================================================================
def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N, loop, speed, ev = int(row["frames"]), bool(row["loop"]), float(row["speed"]), dict(row.get("events", {}))
        if name in UPPERS:
            g = flee_gait(row, UPPERS[name])
            out[name] = Clip(name, N, loop, (lambda f, g=g: g.pose(sk, f)), speed, g, ev)
            continue
        if name == "cower_b":
            fn = (lambda f, N=N: cower_b(sk, f, N))
        elif name == "cower_c":
            fn = (lambda f, N=N: cower_c(sk, f, N))
        else:
            fn = _panic_start(sk, solver, N)
        out[name] = Clip(name, N, loop, fn, speed, None, ev, reach_fix=name == "cower_c")
        if name == "cower_b":
            out[name].no_sink = True          # as cower (panic_start ramps cower's lift in itself)
    return out


# =============================================================================================
# checks and SOURCE.txt notes
# =============================================================================================
KEEP = NAMES + ORIGINALS + ("idle",)
LEG_BONES = ("hips", "thigh.L", "shin.L", "foot.L", "toe.L", "thigh.R", "shin.R", "foot.R", "toe.R")


def _ang(a, b) -> float:
    worst = 0.0
    for bn, q in a.local.items():
        d = abs(float(np.dot(q, b.local[bn])))
        worst = max(worst, 2.0 * math.degrees(math.acos(min(1.0, d))))
    return worst


def _legs_err(a, b) -> float:
    """Worst leg-bone head distance (mm) between two solved frames."""
    return max(float(np.linalg.norm(a.P[n] - b.P[n])) for n in LEG_BONES if n in a.P) * 1000.0


def check_row(name: str, baked, keep: dict) -> str:
    from _anim_d304 import pose_err  # noqa: PLC0415

    fr = baked.frames
    txt = ""
    if name in STARTS:
        src, f = STARTS[name]
        if src in keep:
            txt += f" start_err={pose_err(fr[0], keep[src].frames[f]):.2f}mm"
    if name in ENDS:
        src, f = ENDS[name]
        if src in keep:
            txt += f" end_err={pose_err(fr[-1], keep[src].frames[f]):.2f}mm"
    for g, members in GROUPS.items():
        if name in members and name != members[0] and members[0] in keep:
            orig = keep[members[0]].frames
            n = min(len(fr), len(orig))
            txt += f" max_diff_vs_{members[0]}={max(_ang(fr[i], orig[i]) for i in range(n)):.1f}deg"
            if g == "flee":
                txt += f" legs_err_vs_flee={max(_legs_err(fr[i], orig[i]) for i in range(n)):.2f}mm"
    return txt


def row_extra(name: str) -> str:
    for g, members in GROUPS.items():
        if name in members:
            return f" variant_of={g}"
    return ""


def source_notes(table: dict, keep: dict) -> dict[str, str]:
    out: dict[str, str] = {}
    for g, members in GROUPS.items():
        out[f"variants.{g}"] = ", ".join(m for m in members if m in table)
    per = "/".join(str(int(table[m]["frames"])) for m in GROUPS["cower"] if m in table)
    out["civ_panic_variants"] = (
        "D-116 (loud civilians): pick ONE member of variants.cower and variants.flee per NPC with the SAME index as the "
        "surrender groups: index = hash(net_id or spawn id) % group size, stable for its life (cower_b <-> flee_b <-> "
        "hands_up_b ... one personality). cower* loops: start at a random offset (GameRng.stream(&\"anim_variants\"), "
        f"0..length) and/or speed_scale 0.92..1.08; periods {per} f, every layer closes per loop, so a room never "
        "re-syncs. cower = crouched on the balls, forearms over the crown; cower_b = squatting low on flat feet, "
        "forearms wrapped over the head, elbows out wide, rocking; cower_c = STANDING pressed back, hands up by the face, glancing "
        "around (death by pose: cower / cower_b -> death_crouch; cower_c is standing: the normal deaths). flee* = the "
        "same gait (frames, speed_mps, foot plants and hips identical frame for frame, legs_err_vs_flee ~0), only the "
        "upper body differs: speed_scale = v / 4.0 and any foot-sync / phase logic as for flee; crossfade between "
        "members as between flee and itself (they share the leg phase). panic_start (one-shot, in place, speed 0, "
        "flinch event at the startle peak): play it ONCE when a civilian first panics (alarm raised / gunfire or an "
        "explosion heard / a body or a heister's gun seen in loud), before its first cower* or flee*. It starts on idle "
        "frame 0 (crossfade ~0.1 s from any ambient clip) and ENDS EXACTLY ON cower FRAME 0 (crouched on the balls, "
        "forearms over the crown; 1 cm per bone): then cower plays with no crossfade; cower_b / cower_c crossfade "
        "~0.2 s / ~0.3 s; to flee* crossfade ~0.2 s (the same as cower -> flee today). An NPC already running when the "
        "panic starts skips panic_start.")
    rows = []
    for name in NAMES:
        b = keep.get(name)
        if b is not None:
            rows.append(f"{name}:{check_row(name, b, keep)}")
    if rows:
        out["civ_panic_checks"] = "; ".join(rows)
    return out
