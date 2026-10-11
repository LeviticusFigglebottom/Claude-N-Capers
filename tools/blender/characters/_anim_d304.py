"""D3-04 animation polish for the ``humanoid`` library: crew locomotion blend set, hit / death variety, a
downed crawl and a heavier Wrecker gait. Private helper of ``anim_humanoid.py`` (pure numpy, no ``bpy``).

Locomotion blend set (priority 6)
* 8-way cycles per gait: ``walk`` (the existing forward walk, unchanged) + ``walk_fl``, ``walk_fr``, ``walk_l``,
  ``walk_r``, ``walk_bl``, ``walk_br``, ``walk_b``; ``run`` + ``run_fl`` ... ``run_b``. Every clip of a gait has the
  forward clip's frame count, speed and stance share (walk: 30 f, 1.6 m/s, beta 0.6; run: 21 f, 3.5 m/s, beta 0.36),
  so the cycles are phase-locked: the right foot touches down at normalised time 0 and the left at 0.5 in every
  direction (a BlendSpace2D with sync, or plain normalised-time blending, never mixes a planted foot with a
  swinging one). Directions are body space, ``dir_deg`` clockwise from forward (Godot root space:
  ``(sin a, 0, -cos a)``). The trunk keeps facing forward (aim); the pelvis turns toward the travel direction
  (front half) or away from it (back half), each foot runs in its own lane beside the travel line (the right foot's
  lane on the right of the line in the front half, so the feet never cross).
* Start / stop one-shots in place (``walk_start``, ``walk_stop``, ``run_start``, ``run_stop``): from ``idle`` frame 0
  into the cycle at a documented hand-off frame, and from a documented cycle frame back to ``idle`` frame 0. The
  stance feet are tied to the root travel curve ``s(t)`` (SOURCE.txt ``curve.<clip>``), so at that root motion they do
  not slide; the hand-off frame equals the cycle frame exactly (feet, trunk, arms).

``Gait`` conventions (``_anim``): the stance contact moves at ``-speed * direction``; ``d`` is the contact's offset
along the travel direction from the foot's stance centre (``D/2`` at touch-down, ``-D/2`` at lift-off, ``D`` = the
stance travel).
"""

from __future__ import annotations

import dataclasses
import math
from dataclasses import dataclass

import numpy as np

import _anim as A
from _anim import (FPS, TAU, Clip, Gait, Keys, LegIK, Pose, Skeleton, Solver, add_rot, arm_fk, hand_on, hand_shape,
                   hermite, mslerp, rxd, ryd, rzd, smooth, spine, unit, v3)

# =============================================================================================
# 8-way direction sets
# =============================================================================================
#: clip suffix -> direction (deg clockwise from forward, + = toward the right)
DIRS = {"fl": -45.0, "fr": 45.0, "l": -90.0, "r": 90.0, "bl": -135.0, "br": 135.0, "b": 180.0}

#: Per-gait base (the forward clip's ``gaits()`` arguments) and the per-direction shape: pelvis yaw toward the travel
#: (deg, front half) / away from it (back half), foot lane half-width (m), foot roll (strike / toe-off pitch, deg),
#: arm swing, lift and lean. Keys: 0 = forward, 45 = front diagonal, 90 = side, 135 = back diagonal, 180 = back.
WALK_SHAPE = {
    0: dict(drop=0.035, hip=0.0, lane=0.10, strike=16.0, toeoff=-30.0, flat_at=0.16, heel_rise=0.58, toe_up=8.0, arm=17.0,
            lift=0.07, lean=3.0, along=-0.04),
    45: dict(drop=0.06, hip=18.0, lane=0.115, strike=12.0, toeoff=-26.0, flat_at=0.16, heel_rise=0.58, toe_up=7.0, arm=13.0,
             lift=0.07, lean=3.0, along=-0.03),
    90: dict(drop=0.13, hip=40.0, lane=0.14, strike=6.0, toeoff=-16.0, flat_at=0.18, heel_rise=0.56, toe_up=5.0, arm=8.0,
             lift=0.075, lean=3.0, along=-0.01),
    135: dict(drop=0.09, hip=20.0, lane=0.115, strike=-6.0, toeoff=8.0, flat_at=0.20, heel_rise=0.72, toe_up=0.0, arm=8.0,
              lift=0.065, lean=2.0, along=0.02),
    180: dict(drop=0.05, hip=0.0, lane=0.10, strike=-10.0, toeoff=12.0, flat_at=0.20, heel_rise=0.75, toe_up=-4.0, arm=8.0,
              lift=0.06, lean=2.0, along=0.04),
}
RUN_SHAPE = {
    0: dict(drop=0.075, hip=0.0, lane=0.10, strike=8.0, toeoff=-40.0, flat_at=0.12, heel_rise=0.45, toe_up=12.0, arm=34.0,
            lift=0.17, lean=9.0, along=-0.07),
    45: dict(drop=0.09, hip=24.0, lane=0.12, strike=6.0, toeoff=-36.0, flat_at=0.12, heel_rise=0.45, toe_up=10.0, arm=26.0,
             lift=0.16, lean=8.0, along=-0.05),
    90: dict(drop=0.12, hip=50.0, lane=0.15, strike=2.0, toeoff=-28.0, flat_at=0.14, heel_rise=0.45, toe_up=6.0, arm=16.0,
             lift=0.14, lean=6.0, along=-0.02),
    135: dict(drop=0.11, hip=24.0, lane=0.12, strike=-14.0, toeoff=-14.0, flat_at=0.30, heel_rise=0.62, toe_up=-4.0, arm=18.0,
              lift=0.14, lean=2.0, along=0.03),
    180: dict(drop=0.08, hip=0.0, lane=0.10, strike=-16.0, toeoff=-16.0, flat_at=0.32, heel_rise=0.62, toe_up=-6.0, arm=20.0,
              lift=0.14, lean=0.0, along=0.05),
}


@dataclass
class DirGait(Gait):
    """A ``Gait`` in any body-space direction with a constant pelvis turn (``hip_yaw`` deg, + = left) that the spine
    undoes (the chest faces forward), feet turned ``foot_yaw`` (deg, + = toes left) and each foot in its own lane:
    ``lane`` = the right foot's lane centre (body space, m; the left foot's is ``-lane``). The hips shift toward the
    stance foot's lane by ``lane_sway`` (m). Always ``exact_pivot`` (the turned feet roll about their contact point)."""

    hip_yaw: float = 0.0
    foot_yaw: float = 0.0
    lane: tuple = (0.10, 0.0)
    lane_sway: float = 0.018

    def foot(self, sk: Skeleton, sfx: str, ph: float):
        d, pitch, lift, toe, stance = foot_params(self, sk, sfx, ph)
        ankle, R = place(self, sk, sfx, d, pitch, lift)
        return ankle, R, A.rad(toe), stance

    def pose(self, sk: Skeleton, f: int) -> Pose:
        pose = super().pose(sk, f)
        k = sk.scale
        ph = (f % self.frames) / self.frames
        b2 = self.beta / 2.0
        lane = np.array([self.lane[0], self.lane[1], 0.0])
        n = float(np.linalg.norm(lane))
        lane_u = lane / n if n > 1e-9 else np.zeros(3)
        pose.hip = pose.hip + lane_u * (self.lane_sway * k * math.cos(TAU * (ph - b2)))
        hy = self.hip_yaw
        pose.D["hips"] = rzd(hy) @ pose.D["hips"]
        pose.D["spine"] = rzd(-hy * 0.6) @ pose.D["spine"]
        pose.D["chest"] = rzd(-hy * 0.4) @ pose.D["chest"]
        for sfx, ik in pose.legs.items():
            sx = A.side_x(sfx)
            ik.pole = unit(rzd(self.foot_yaw - sx * self.toe_out * 0.6) @ v3(sx * 0.08, 1.0, 0.0))
        return pose


def _shape(table: dict, ang: float) -> dict:
    """Interpolated direction shape for |ang| in [0, 180] (piecewise linear between the 45 deg keys)."""
    a = abs(ang)
    keys = sorted(table)
    for a0, a1 in zip(keys[:-1], keys[1:]):
        if a0 <= a <= a1:
            t = (a - a0) / (a1 - a0)
            return {k: table[a0][k] + (table[a1][k] - table[a0][k]) * t for k in table[a0]}
    return dict(table[keys[-1]])


def dir_gait(sk: Skeleton, base: Gait, shape_table: dict, ang: float) -> DirGait:
    """The ``base`` (forward) gait turned to ``ang`` deg (clockwise from forward)."""
    k = sk.scale
    r = math.radians(ang)
    d = np.array([math.sin(r), math.cos(r)])
    sh = _shape(shape_table, ang)
    front = abs(ang) <= 90.0 + 1e-6
    side = 1.0 if ang > 0 else -1.0 if ang < 0 else 0.0
    # pelvis: toward the travel in the front half (+ = left, so travelling right turns it right = negative),
    # away from it in the back half
    hip_yaw = -side * sh["hip"] if front else side * sh["hip"]
    # right foot lane: right of the travel line (front half), left of it (back half: the body faces away)
    perp = np.array([d[1], -d[0]]) if front else np.array([-d[1], d[0]])
    lane_r = perp * sh["lane"]
    rest = {s: sk.ground(s)["ankle"][:2] / k for s, _sx in A.SIDES}
    centre = {"R": tuple(lane_r + d * sh["along"] - rest["R"]), "L": tuple(-lane_r + d * sh["along"] - rest["L"])}
    g = dataclasses.replace(base)
    kw = dict(direction=(float(d[0]), float(d[1])), strike=sh["strike"], toeoff=sh["toeoff"], flat_at=sh["flat_at"],
              heel_rise=sh["heel_rise"], swing_toe_up=sh["toe_up"], arm_swing=sh["arm"], lift=sh["lift"],
              lean=sh["lean"], drop=sh["drop"], centre=centre, width=0.0, sway=0.0, exact_pivot=True)
    fields = {f.name: getattr(g, f.name) for f in dataclasses.fields(Gait)}
    fields.update(kw)
    return DirGait(**fields, hip_yaw=hip_yaw, foot_yaw=0.7 * hip_yaw, lane=(float(lane_r[0]), float(lane_r[1])),
                   lane_sway=base.sway)


# =============================================================================================
# foot parameters (the ``Gait.foot`` maths split into parameters + placement)
# =============================================================================================
def stance_pitch(g: Gait, u: float) -> float:
    return g.strike * (1.0 - smooth(0.0, g.flat_at, u)) + g.toeoff * smooth(g.heel_rise, 1.0, u)


def stance_toe(g: Gait, pitch: float) -> float:
    return max(0.0, -pitch) if g.toeoff < 0 else 0.0


def stance_d(g: Gait) -> float:
    """Contact travel during stance (m at 1.78 m)."""
    return g.speed * g.beta * g.frames / FPS


def foot_params(g: Gait, sk: Skeleton, sfx: str, ph: float) -> tuple:
    """(d m, pitch deg, lift m, toe deg, stance) of one foot at its own phase (0 = touch-down): ``Gait.foot``."""
    k = sk.scale
    T = g.frames / FPS
    D = g.speed * g.beta * T
    flat_toes = isinstance(g, DirGait)          # the toes bend up whenever the foot pitches toes-down (tip on the floor)
    if ph < g.beta:
        u = ph / g.beta
        pitch = stance_pitch(g, u)
        return D * (0.5 - u), pitch, 0.0, max(0.0, -pitch) if flat_toes else stance_toe(g, pitch), True
    w = (ph - g.beta) / (1.0 - g.beta)
    Ts = (1.0 - g.beta) * T
    m = -g.speed * Ts * g.swing_match
    d = hermite(-D / 2.0, D / 2.0, m, m, w)
    pitch = g.toeoff + (g.strike - g.toeoff) * smooth(0.05, 0.9, w) + g.swing_toe_up * math.sin(math.pi * w)
    lift = g.lift * k * math.sin(math.pi * A.clamp01(w) ** g.lift_skew)
    toe = max(0.0, -g.toeoff) * (1.0 - smooth(0.0, 0.45, w))
    if flat_toes:
        toe = max(toe, -pitch * smooth(0.6, 1.0, w))
    return d, pitch, lift, toe, False


def place(g: Gait, sk: Skeleton, sfx: str, d: float, pitch: float, lift: float) -> tuple[np.ndarray, np.ndarray]:
    """(ankle, foot rotation) for foot parameters (``Gait.foot`` placement)."""
    k = sk.scale
    dirv = np.array([g.direction[0], g.direction[1], 0.0])
    sx = A.side_x(sfx)
    cx, cy = g.centre.get(sfx, (0.0, 0.0))
    base = v3(sx * g.width * k + cx * k, cy * k, 0.0)
    gp = sk.ground(sfx)
    yaw = -sx * g.toe_out + getattr(g, "foot_yaw", 0.0)
    R = A.foot_rot(yaw, pitch)
    pivot = gp["heel"] if pitch >= 0.0 else gp["ball"]
    if g.exact_pivot:
        # the flat foot turned about its ankle: heel and ball contacts of that foot (so switching the pivot from the
        # heel to the ball at pitch 0 does not move the foot)
        a0 = gp["ankle"] * v3(1.0, 1.0, 0.0)
        flat = a0 + rzd(yaw) @ (pivot - a0)
        ankle = flat + dirv * d + base + R @ (gp["ankle"] - pivot) + v3(0.0, 0.0, lift)
    else:
        ankle = pivot + dirv * d + base + R @ rzd(-yaw) @ (gp["ankle"] - pivot) + v3(0.0, 0.0, lift)
    return ankle, R


def gait_pole(g: Gait, sfx: str) -> np.ndarray:
    sx = A.side_x(sfx)
    return unit(rzd(getattr(g, "foot_yaw", 0.0) - sx * g.toe_out * 0.6) @ v3(sx * 0.08, 1.0, 0.0))


# =============================================================================================
# start / stop transitions
# =============================================================================================
def herm_curve(p0: float, m0: float, p1: float, m1: float, t0: float, t1: float, bump: float = 0.0):
    """Cubic Hermite between (t0, p0, slope m0 per frame) and (t1, p1, m1), plus ``bump * sin^2`` (zero slopes)."""
    dur = t1 - t0

    def fn(t: float) -> float:
        w = A.clamp01((t - t0) / dur)
        return hermite(p0, p1, m0 * dur, m1 * dur, w) + bump * math.sin(math.pi * w) ** 2
    return fn


class Travel:
    """Root travel ``s(t)`` (m at 1.78 m, t in frames): Hermite pieces with continuous speed. ``knots`` =
    [(frame, s, speed m/frame), ...]; constant speed outside."""

    def __init__(self, knots: list[tuple[float, float, float]]) -> None:
        self.knots = knots

    def __call__(self, t: float) -> float:
        ks = self.knots
        if t <= ks[0][0]:
            return ks[0][1] + ks[0][2] * (t - ks[0][0])
        if t >= ks[-1][0]:
            return ks[-1][1] + ks[-1][2] * (t - ks[-1][0])
        for (t0, s0, v0), (t1, s1, v1) in zip(ks[:-1], ks[1:]):
            if t0 <= t <= t1:
                return herm_curve(s0, v0, s1, v1, t0, t1)(t)
        return ks[-1][1]

    def speed(self, t: float) -> float:
        """m per frame (central difference)."""
        e = 1e-3
        return (self(t + e) - self(t - e)) / (2 * e)


class FootTrack:
    """One foot's program: time segments of (d, pitch, lift, toe, stance) functions (t in frames)."""

    def __init__(self) -> None:
        self.segs: list[tuple[float, float, object]] = []

    def add(self, t0: float, t1: float, fn) -> None:
        self.segs.append((t0, t1, fn))

    def __call__(self, t: float) -> tuple:
        for t0, t1, fn in self.segs:
            if t0 <= t <= t1:
                return fn(t)
        return self.segs[-1][2](t) if t > self.segs[-1][1] else self.segs[0][2](t)

    def end_state(self, t: float, back: bool = True) -> tuple:
        """(values, slopes per frame) at ``t``, slopes one-sided (from before ``t`` if ``back``)."""
        e = 1e-3
        a = self(t)
        b = self(t - e) if back else self(t + e)
        sl = tuple(((x - y) / e if back else (y - x) / e) for x, y in zip(a[:4], b[:4]))
        return a[:4], sl


def stance_fn(g: Gait, s: Travel, d_anchor: float, t_anchor: float):
    """A planted foot: its contact stays where it was at ``t_anchor`` (d moves back with the root travel)."""
    D = stance_d(g)

    def fn(t: float) -> tuple:
        d = d_anchor - (s(t) - s(t_anchor))
        u = 0.5 - d / D
        pitch = stance_pitch(g, u)
        return d, pitch, 0.0, stance_toe(g, pitch), True
    return fn


def gait_fn(sk: Skeleton, g: Gait, sfx: str, phase_of_t):
    """The cycle itself (``phase_of_t(t)`` = the gait phase, R strike at 0, L at 0.5)."""
    off = 0.0 if sfx == "R" else 0.5

    def fn(t: float) -> tuple:
        return foot_params(g, sk, sfx, (phase_of_t(t) - off) % 1.0)
    return fn


def swing_fn(t0: float, t1: float, start: tuple, end: tuple, lift_bump: float, toe_end: float = 0.0):
    """Swing from ``start`` = ((d, pitch, lift, toe), slopes) to ``end`` (same form), Hermite per channel, plus a lift
    bump (m) so the foot clears the floor."""
    (v0, s0), (v1, s1) = start, end
    # lift off and touch down decisively (no skimming the floor while the foot already travels)
    s0 = (s0[0], s0[1], max(s0[2], 0.010), s0[3])
    if abs(s1[0]) > 1e-4:
        s1 = (s1[0], s1[1], min(s1[2], -0.008), s1[3])
    chans = [herm_curve(v0[i], s0[i], v1[i], s1[i], t0, t1, bump=(lift_bump if i == 2 else 0.0)) for i in range(4)]
    del toe_end

    def fn(t: float) -> tuple:
        d, p, lift, toe = (c(t) for c in chans)
        return d, p, max(0.0, lift), max(0.0, toe), False
    return fn


@dataclass
class Transition:
    """A start (idle -> cycle) or stop (cycle -> idle) one-shot. ``ref`` = the cycle's poses (reach-fixed), ``idle0``
    = idle frame 0, ``feet`` = FootTracks, ``s`` = root travel, ``upper_w(f)`` = cycle weight of the upper body,
    ``cycle_frame(f)`` = which cycle frame the upper body follows, ``lean(f)`` extra forward lean (deg)."""

    g: Gait
    ref: list
    idle0: Pose
    feet: dict
    s: Travel
    upper_w: object
    cycle_frame: object
    lean: object
    frames: int

    def pose(self, sk: Skeleton, f: int) -> Pose:
        w = self.upper_w(f)
        cyc = self.ref[self.cycle_frame(f) % len(self.ref)]
        pose = blend_pose(self.idle0, cyc, w)
        idle_legs = self.idle0.legs
        for sfx, track in self.feet.items():
            d, pitch, lift, toe, _st = track(float(f))
            ankle, R = place(self.g, sk, sfx, d, pitch, lift)
            pole = unit(A.lerp(idle_legs[sfx].pole, gait_pole(self.g, sfx), w))
            pose.legs[sfx] = LegIK(ankle=ankle, foot=R, toe=A.rad(toe), pole=pole)
        ln = self.lean(f)
        if ln:
            add_rot(pose, "spine", rxd(-0.6 * ln))
            add_rot(pose, "chest", rxd(-0.4 * ln))
            add_rot(pose, "head", rxd(0.5 * ln))
        return pose


def blend_pose(a: Pose, b: Pose, t: float) -> Pose:
    """Upper body / trunk blend (hip offset, FK rotations, finger shapes); legs and arm IK goals are not blended."""
    out = Pose(hip=A.lerp(a.hip, b.hip, t))
    for key in sorted(set(a.D) | set(b.D)):
        out.D[key] = mslerp(a.D.get(key, A.I3), b.D.get(key, A.I3), t)
    for key in sorted(set(a.local) | set(b.local)):
        out.local[key] = mslerp(a.local.get(key, A.I3), b.local.get(key, A.I3), t)
    for sfx in sorted(set(a.hands) | set(b.hands)):
        ha, hb = a.hands.get(sfx), b.hands.get(sfx)
        out.hands[sfx] = ha.blend(hb, t) if ha is not None and hb is not None else (ha or hb)
    return out


def ref_cycle(solver: Solver, g: Gait) -> list[Pose]:
    """The cycle's poses exactly as ``bake`` builds them (reach fix included)."""
    poses = [g.pose(solver.sk, f).copy() for f in range(g.frames)]
    A.fix_hips_for_reach(solver, poses, True)
    return poses


def ref_idle0(solver: Solver, idle_fn, frames: int) -> Pose:
    poses = [idle_fn(solver.sk, f, frames).copy() for f in range(frames)]
    A.fix_hips_for_reach(solver, poses, True)
    return poses[0]


def _ease_w(f: float, f0: float, f1: float) -> float:
    return smooth(f0, f1, f)


def start_transition(sk: Skeleton, g: Gait, ref: list, idle0: Pose, N: int, h: int, lift_at: float,
                     lean_amp: float, lift_bump: float) -> Transition:
    """idle frame 0 -> the cycle at frame ``h`` (clip frame N). The left foot stays planted from idle until the cycle
    lifts it; the right foot steps once (lifting at ``lift_at``) and lands on the cycle's right touch-down (frame 0);
    the root accelerates from 0 so that it reaches the cycle speed by the time both feet are on the cycle's
    schedule (from then on the cycle runs at its nominal rate)."""
    Nc = g.frames
    D = stance_d(g)
    v = g.speed / FPS
    d_idle = -g.centre["L"][1] * sk.scale
    t_R = N - h                                    # right touch-down (cycle frame 0)
    # left foot: planted from idle until the cycle lifts it (its own phase beta = cycle phase beta + 0.5)
    lift_L_phase = (g.beta + 0.5) % 1.0            # cycle phase of the left lift
    t_L = t_R + ((lift_L_phase * Nc) - Nc if lift_L_phase * Nc > h + 1e-6 else lift_L_phase * Nc)
    # root reaches the cycle speed at t_c = min(t_L, t_R) and then runs at v
    t_c = min(t_L, t_R)
    s_L = d_idle + D / 2.0                         # left contact travel from idle to its lift (u = 1)
    s_c = s_L - v * (t_L - t_c)                    # travel at t_c
    s = Travel([(0.0, 0.0, 0.0), (t_c, s_c, v)])
    feet = {"L": FootTrack(), "R": FootTrack()}
    cyc_phase = lambda t: (h - (N - t)) / Nc       # noqa: E731
    left_stance = stance_fn(g, s, d_idle, 0.0)
    feet["L"].add(0.0, t_L, left_stance)
    feet["L"].add(t_L, N + 1.0, gait_fn(sk, g, "L", cyc_phase))
    right_plant = stance_fn(g, s, d_idle, 0.0)
    feet["R"].add(0.0, lift_at, right_plant)
    cyc_r = FootTrack()
    cyc_r.add(-1e9, 1e9, gait_fn(sk, g, "R", cyc_phase))
    start = feet["R"].end_state(lift_at, back=True)
    end_v, end_s = cyc_r.end_state(t_R, back=True)
    feet["R"].add(lift_at, t_R, swing_fn(lift_at, t_R, start, (end_v, end_s), lift_bump))
    feet["R"].add(t_R, N + 1.0, gait_fn(sk, g, "R", cyc_phase))
    return Transition(g, ref, idle0, feet, s, upper_w=lambda f: smooth(0.0, N - 2.0, f),
                      cycle_frame=lambda f: h - (N - f), lean=lambda f: lean_amp * math.sin(math.pi * f / N) ** 2,
                      frames=N)


def stop_transition(sk: Skeleton, g: Gait, ref: list, idle0: Pose, N: int, h0: int, t_stop: float,
                    lean_amp: float, lift_bump: float, l_land: float | None = None, r_lift: float | None = None,
                    stop_dist: float | None = None) -> Transition:
    """The cycle at frame ``h0`` (= clip frame 0, the right touch-down) -> idle frame 0. The root decelerates to rest
    at ``t_stop``. Walk (``l_land`` None): the right foot stays planted and ends at its idle place, the left foot
    lifts on the cycle's schedule and swings beside it. Run: the swinging left foot lands early (``l_land``) as a
    braking step, the right foot lifts at ``r_lift`` and both end at their idle places."""
    Nc = g.frames
    D = stance_d(g)
    v = g.speed / FPS
    d_idle = -g.centre["L"][1] * sk.scale
    feet = {"L": FootTrack(), "R": FootTrack()}
    cyc_phase = lambda t: (h0 + t) / Nc            # noqa: E731
    cyc = {sfx: gait_fn(sk, g, sfx, cyc_phase) for sfx in ("L", "R")}
    if l_land is None:
        S = D / 2.0 - d_idle                       # the right contact ends at its idle place
        s = Travel([(0.0, 0.0, v), (t_stop, S, 0.0)])
        feet["R"].add(0.0, N + 1.0, stance_fn(g, s, D / 2.0, 0.0))
        # left: the cycle's stance (late) until its lift at u = 1
        dL0, *_ = cyc["L"](0.0)
        left = stance_fn(g, s, dL0, 0.0)
        t_lift = _solve(lambda t: dL0 - s(t) + D / 2.0, 0.0, t_stop)
        feet["L"].add(0.0, t_lift, left)
        start = feet["L"].end_state(t_lift, back=True)
        end = ((d_idle, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 0.0))
        feet["L"].add(t_lift, t_stop, swing_fn(t_lift, t_stop, start, end, lift_bump))
        feet["L"].add(t_stop, N + 1.0, lambda t: (d_idle, 0.0, 0.0, 0.0, True))
    else:
        S = stop_dist
        s = Travel([(0.0, 0.0, v), (t_stop, S, 0.0)])
        # left: in the air at h0; a braking step that lands at l_land and stays until the end at its idle place
        sL = FootTrack()
        sL.add(-1e9, 1e9, cyc["L"])
        start = sL.end_state(0.0, back=False)
        d_land = d_idle + S - s(l_land)
        u_land = 0.5 - d_land / D
        p_land = stance_pitch(g, u_land)
        land = ((d_land, p_land, 0.0, stance_toe(g, p_land)), (-s.speed(l_land), 0.0, -0.002, 0.0))
        feet["L"].add(0.0, l_land, swing_fn(0.0, l_land, start, land, lift_bump * 0.3))
        feet["L"].add(l_land, N + 1.0, stance_fn(g, s, d_land, l_land))
        # right: planted from its touch-down, lifts at r_lift, steps to its idle place
        feet["R"].add(0.0, r_lift, stance_fn(g, s, D / 2.0, 0.0))
        start = feet["R"].end_state(r_lift, back=True)
        end = ((d_idle, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 0.0))
        feet["R"].add(r_lift, t_stop, swing_fn(r_lift, t_stop, start, end, lift_bump))
        feet["R"].add(t_stop, N + 1.0, lambda t: (d_idle, 0.0, 0.0, 0.0, True))
    return Transition(g, ref, idle0, feet, s, upper_w=lambda f: 1.0 - smooth(1.0, t_stop + 2.0, f),
                      cycle_frame=lambda f: h0 + f, lean=lambda f: -lean_amp * math.sin(math.pi * min(1.0, f / t_stop)) ** 2,
                      frames=N)


def _solve(fn, a: float, b: float) -> float:
    """Root of a monotone ``fn`` on [a, b] (bisection)."""
    fa = fn(a)
    for _ in range(60):
        m = 0.5 * (a + b)
        fm = fn(m)
        if (fm > 0) == (fa > 0):
            a, fa = m, fm
        else:
            b = m
    return 0.5 * (a + b)


def reach_fix_pinned(solver: Solver, poses: list[Pose], pinned: tuple[int, ...]) -> float:
    """``fix_hips_for_reach`` for a one-shot whose ``pinned`` frames must stay exact (hand-off frames): the
    correction fades to 0 there (3 frames). Returns the worst correction (m)."""
    copy = [p.copy() for p in poses]
    before = [float(p.hip[2]) for p in copy]
    A.fix_hips_for_reach(solver, copy, False)
    corr = [b - float(p.hip[2]) for b, p in zip(before, copy)]
    n = len(poses)
    for i in range(n):
        w = 1.0
        for p in pinned:
            pi = p if p >= 0 else n + p
            w = min(w, smooth(0.0, 3.0, abs(i - pi)))
        poses[i].hip = poses[i].hip - v3(0.0, 0.0, corr[i] * w)
    return max(corr) if corr else 0.0


def transition_clip(sk: Skeleton, solver: Solver, name: str, N: int, tr: Transition, ev: dict) -> Clip:
    """Bake-ready one-shot: poses precomputed, hips lowered only where a leg is out of reach (never on the hand-off /
    idle frames, which equal the cycle / idle frames exactly)."""
    poses = [tr.pose(sk, f) for f in range(N + 1)]
    reach_fix_pinned(solver, poses, (0, N))
    clip = Clip(name, N, False, lambda f, poses=poses: poses[f].copy(), tr.g.speed, None, ev, reach_fix=False)
    clip.transition = tr
    return clip


# =============================================================================================
# heavier Wrecker gait
# =============================================================================================
def _dozer_heavy_upper(sk: Skeleton, pose: Pose, ph: float, f: int) -> None:
    """dozer_walk_heavy: the shoulders roll over each planted leg (chest side bend + clavicle shrug against the
    pelvis roll), a hard shudder down the trunk at every heel strike and the big gun swinging across the hips with the
    chest twist."""
    import _anim_humanoid as H  # noqa: PLC0415

    k = sk.scale
    shud = 0.0
    for strike in (0.0, 0.5):
        dd = (ph - strike) % 1.0
        shud += A.pulse(dd * 1.1, 0.025, 0.22)
    roll = math.cos(TAU * (ph - 0.30))                 # + = weight over the right leg (mid stance)
    add_rot(pose, "spine", rxd(-2.6 * shud) @ ryd(-2.5 * roll))
    add_rot(pose, "chest", rxd(-1.6 * shud) @ ryd(-4.0 * roll) @ rzd(3.0 * math.sin(TAU * ph)))
    add_rot(pose, "neck", ryd(2.5 * roll))
    add_rot(pose, "head", rxd(2.4 * shud) @ ryd(1.5 * roll))
    pose.hip = pose.hip + v3(0.0, 0.0, -0.012 * k * shud)
    pre = Solver(sk).solve(pose)
    Wc = pre.W["chest"]
    swing = 9.0 * math.sin(TAU * (ph - 0.08))          # gun yaw across the body
    o = A.bone_point(pre, sk, "chest", v3(0.13 * k, 0.13 * k, -0.19 * k)) + v3(0.0, 0.0, -0.012 * k * shud)
    wf = (Wc @ rzd(12.0 + swing) @ rxd(-8.0 + 2.0 * shud), o)
    A.hold_weapon(sk, pose, wf, pole=v3(0.85, -0.25, -0.5), twist=0.6)
    pose.hands["R"] = hand_shape("trigger")
    H.rifle_support(sk, pose, wf, pole=v3(-0.7, -0.2, -0.7), at=H.RIFLE["left_ik"] + v3(0.0, -0.08, -0.005))


def dozer_heavy_gait(table: dict) -> Gait:
    row = table["dozer_walk_heavy"]
    return Gait(speed=row["speed"], frames=row["frames"], beta=0.60, lift=0.05, lift_skew=0.85, drop=0.085, bob=0.045,
                strike=9.0, toeoff=-16.0, flat_at=0.07, heel_rise=0.72, lean=8.0, pelvis_yaw=8.0, pelvis_roll=7.5,
                width=0.09, toe_out=15.0, sway=0.075, chest_counter=2.3, head_bob_comp=0.9, swing_toe_up=5.0,
                centre={"L": (0.0, -0.03), "R": (0.0, -0.03)}, upper=_dozer_heavy_upper, exact_pivot=True)


# =============================================================================================
# hit reacts (directional) and deaths
# =============================================================================================
def _stand(sk: Skeleton) -> Pose:
    import _anim_humanoid as H  # noqa: PLC0415

    return H.idle(sk, 0, 120)


def hit_back(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """Shot in the back: the hips and chest are driven forward, the head and arms lag back, recover."""
    k = sk.scale
    b = _stand(sk)
    b.hip = b.hip + v3(0.0, 0.05 * k, -0.025 * k)
    spine(b, lean=9, chest_lean=11, side=-2, twist=-4, neck=(-12, 0, 0), head=(-10, -3, -6), hips=(5, 0, 0))
    for sfx, sx in A.SIDES:
        arm_fk(sk, b, sfx, add=30.0, swing=-24.0, flex=26.0, out=14.0, clav_up=6.0, clav_fwd=-8.0)
        b.hands[sfx] = hand_shape("spread", 0.7)
    c = _stand(sk)
    c.hip = c.hip + v3(0.0, -0.012 * k, -0.012 * k)
    spine(c, lean=-3, chest_lean=-3, neck=(4, 0, 0), head=(4, 0, 2))
    return Keys(solver, [(0, _stand(sk), "inout"), (3, b, "snap"), (9, c, "inout"), (N, _stand(sk), "inout")])


def hit_side(sk: Skeleton, solver: Solver, N: int, s: float) -> Keys:
    """Shot from the left (``s`` = +1) or the right (-1): the near shoulder is knocked back (the chest turns toward
    the hit), the trunk bends away from it, the near arm clutches in, the far arm flails out."""
    k = sk.scale
    b = _stand(sk)
    b.hip = b.hip + v3(s * 0.045 * k, -0.01 * k, -0.022 * k)
    spine(b, side=s * 7, twist=s * 11, chest_side=s * 6, chest_twist=s * 9, lean=2, chest_lean=-3,
          neck=(-4, -s * 6, -s * 4), head=(-6, -s * 9, -s * 8), hips=(0, -s * 4, s * 5))
    near, far = ("L", "R") if s > 0 else ("R", "L")
    arm_fk(sk, b, near, add=40.0, swing=18.0, flex=40.0, twist=12.0, clav_up=6.0)
    arm_fk(sk, b, far, add=20.0, swing=-6.0, flex=24.0, out=18.0)
    b.hands[near] = hand_shape("claw", 0.7)
    b.hands[far] = hand_shape("spread", 0.8)
    # the near hand comes in to clutch the hit while the trunk starts to recover
    b2 = _stand(sk)
    b2.hip = b2.hip + v3(s * 0.03 * k, -0.006 * k, -0.02 * k)
    spine(b2, side=s * 4, twist=s * 7, chest_side=s * 3, chest_twist=s * 6, lean=4, chest_lean=2,
          neck=(2, -s * 4, -s * 2), head=(4, -s * 5, -s * 4), hips=(0, -s * 2, s * 3))
    arm_fk(sk, b2, near, add=50.0, swing=36.0, flex=74.0, twist=26.0, clav_up=6.0, clav_fwd=6.0)
    arm_fk(sk, b2, far, add=26.0, swing=2.0, flex=24.0, out=10.0)
    b2.hands[near] = hand_shape("claw", 0.9)
    b2.hands[far] = hand_shape("relaxed", 0.9)
    c = _stand(sk)
    c.hip = c.hip + v3(-s * 0.008 * k, 0.0, -0.01 * k)
    spine(c, side=-s * 2.0, twist=-s * 2.5, neck=(2, 0, s * 2), head=(3, s * 2, s * 3))
    arm_fk(sk, c, near, add=40.0, swing=16.0, flex=40.0, twist=12.0)
    return Keys(solver, [(0, _stand(sk), "inout"), (3, b, "snap"), (7, b2, "inout"), (11, c, "inout"),
                         (N, _stand(sk), "inout")])


def _limp_arms(sk: Skeleton, pose: Pose, swing: float = 6.0, flex: float = 18.0, add: float = 24.0, out: float = 4.0):
    for sfx in ("L", "R"):
        arm_fk(sk, pose, sfx, add=add, swing=swing, flex=flex, out=out)
        pose.hands[sfx] = hand_shape("relaxed", 0.7)


def _kneel(sk: Skeleton, pose: Pose, fwd: float, sit: float) -> None:
    """Kneeling on both knees, the feet where they stood (``fwd`` m: how far the knees went forward)."""
    k = sk.scale
    hips_rest = sk.head["hips"]
    pose.hip = v3(0.0, (fwd - 0.05) * k, (0.60 - 0.14 * sit) * k - hips_rest[2])
    for sfx, sx in A.SIDES:
        pose.legs[sfx] = LegIK(ankle=v3(sx * 0.12 * k, (fwd - 0.40) * k, 0.085 * k), foot=rxd(-120.0) @ rzd(-sx * 8.0),
                               toe=A.rad(25.0), pole=v3(sx * 0.15, 1.0, -0.6))


def death_front_b(sk: Skeleton, solver: Solver, N: int, knees: int, impact: int) -> Keys:
    """Crumple: shot in the back, the legs go, the knees hit the floor (``knees``), a dead sway on the knees, then the
    body tips forward onto the face (``impact``), legs folded behind. Ends prone."""
    k = sk.scale
    hips_rest = sk.head["hips"]
    hit = _stand(sk)
    hit.hip = hit.hip + v3(0.0, 0.04 * k, -0.03 * k)
    spine(hit, lean=10, chest_lean=8, neck=(-12, 0, 0), head=(-10, 0, 6), hips=(4, 0, 0))
    for sfx in ("L", "R"):
        arm_fk(sk, hit, sfx, add=28.0, swing=-16.0, flex=30.0, out=8.0)
        hit.hands[sfx] = hand_shape("claw", 0.8)
    sag = _stand(sk)
    sag.hip = v3(0.0, 0.10 * k, 0.74 * k - hips_rest[2])
    for sfx, sx in A.SIDES:
        A.plant(sk, sag, sfx, (0.0, 0.0, 0.0), yaw=-sx * 6.0, pitch=-24.0, toe=24.0, pivot="ball",
                pole=v3(sx * 0.15, 1.0, 0.0))
    spine(sag, lean=14, chest_lean=8, neck=(10, 0, 0), head=(16, 0, 4), hips=(8, 0, 0))
    _limp_arms(sk, sag, swing=10.0, flex=24.0)
    kn = Pose()
    _kneel(sk, kn, 0.40, 0.15)
    spine(kn, lean=16, chest_lean=10, side=3, neck=(16, 0, 0), head=(24, 4, 6), hips=(6, 0, 0))
    _limp_arms(sk, kn, swing=4.0, flex=14.0)
    sway = Pose()
    _kneel(sk, sway, 0.40, 0.45)
    spine(sway, lean=8, chest_lean=6, side=-5, twist=6, neck=(22, -4, 0), head=(28, -6, 10), hips=(2, -3, 4))
    _limp_arms(sk, sway, swing=-2.0, flex=12.0, out=6.0)
    tip = Pose()
    tip.hip = v3(0.02 * k, 0.62 * k, 0.40 * k - hips_rest[2])
    spine(tip, hips=(48, -4, 6), lean=18, chest_lean=10, neck=(10, 0, 0), head=(14, 6, 20))
    for sfx, sx in A.SIDES:
        tip.legs[sfx] = LegIK(ankle=v3(sx * 0.12 * k, 0.0, 0.08 * k), foot=rxd(-130.0) @ rzd(-sx * 8.0), toe=A.rad(20.0),
                              pole=v3(sx * 0.15, 1.0, -0.6))
    _limp_arms(sk, tip, swing=30.0, flex=20.0, out=10.0)
    ground = Pose()
    ground.hip = v3(0.03 * k, 0.86 * k, 0.13 * k - hips_rest[2])
    spine(ground, hips=(88, -3, 5), lean=-3, chest_lean=-2, neck=(-10, 0, 0), head=(-6, -4, -64))
    for sfx, sx in A.SIDES:
        ground.legs[sfx] = LegIK(ankle=v3(sx * (0.16 if sfx == "L" else 0.10) * k, (0.02 if sfx == "L" else 0.10) * k,
                                          0.075 * k), foot=rxd(-150.0) @ rzd(-sx * 12.0), toe=A.rad(30.0),
                                 pole=v3(sx * 0.3, 0.0, -1.0))
    pre = Solver(sk).solve(ground)
    for sfx, sx in A.SIDES:
        # arms limp beside the trunk, palms up (fell without catching himself)
        p = pre.P[f"upper_arm.{sfx}"] + v3(sx * 0.10 * k, -0.42 * k, 0.0)
        p[2] = 0.04 * k
        hand_on(sk, ground, sfx, p, v3(sx * 0.15, -1.0, 0.0), v3(0.0, 0.0, 1.0), pole=v3(sx * 0.6, 0.0, 0.8),
                along_share=0.5, palm_off=0.012, clav=0.3)
        ground.hands[sfx] = hand_shape("relaxed", 0.9)
    impact_p = ground.copy()
    impact_p.hip = impact_p.hip + v3(0.0, 0.0, -0.012 * k)
    add_rot(impact_p, "chest", rxd(3.0))
    add_rot(impact_p, "head", rxd(6.0))
    return Keys(solver, [(0, _stand(sk), "inout"), (4, hit, "snap"), (10, sag, "in"), (knees, kn, "heavy"),
                         (knees + 4, kn.copy(), "out"), (knees + 12, sway, "inout"), (impact - 7, tip, "in"),
                         (impact, impact_p, "heavy"), (impact + 8, ground, "out"), (N, ground, "inout")])


def death_back_b(sk: Skeleton, solver: Solver, N: int, step_r: int, step_l: int, impact: int) -> Keys:
    """Stagger back: shot from the front, two stumbling steps backwards (right ``step_r``, left ``step_l``), the knees
    give and the body sits down and falls onto the back (``impact``). Ends supine, right knee up."""
    k = sk.scale
    hips_rest = sk.head["hips"]
    hit = _stand(sk)
    hit.hip = hit.hip + v3(0.0, -0.035 * k, -0.02 * k)
    spine(hit, lean=-9, chest_lean=-10, side=2, neck=(6, 0, 0), head=(4, 2, 6), hips=(-4, 0, 0))
    for sfx in ("L", "R"):
        arm_fk(sk, hit, sfx, add=26.0, swing=26.0, flex=42.0, out=8.0)
        hit.hands[sfx] = hand_shape("claw", 0.8)

    def stagger(hip_y: float, hip_z: float, r_off, l_off, r_lift: float = 0.0, l_lift: float = 0.0, lean: float = -10):
        p = _stand(sk)
        p.hip = v3(0.0, hip_y * k, hip_z * k)
        A.plant(sk, p, "R", (0.0, r_off * k, r_lift * k), yaw=-6.0, pitch=-14.0 if r_lift else 0.0, toe=10.0 if r_lift else 0.0,
                pivot="ball")
        A.plant(sk, p, "L", (0.0, l_off * k, l_lift * k), yaw=6.0, pitch=-14.0 if l_lift else 0.0, toe=10.0 if l_lift else 0.0,
                pivot="ball")
        spine(p, lean=lean, chest_lean=lean * 0.8, side=3, neck=(8, 0, 0), head=(10, 3, 8), hips=(-6, 0, 0))
        for sfx in ("L", "R"):
            arm_fk(sk, p, sfx, add=20.0, swing=30.0, flex=36.0, out=18.0)
            p.hands[sfx] = hand_shape("spread", 0.7)
        return p
    r_up = stagger(-0.12, -0.04, -0.17, 0.0, r_lift=0.09)
    r_dn = stagger(-0.22, -0.05, -0.34, 0.0)
    l_up = stagger(-0.36, -0.07, -0.34, -0.22, l_lift=0.08, lean=-12)
    l_dn = stagger(-0.46, -0.09, -0.34, -0.52, lean=-12)
    sit = Pose()
    sit.hip = v3(0.0, -0.62 * k, 0.50 * k - hips_rest[2])
    spine(sit, hips=(-22, 0, -4), lean=8, chest_lean=6, neck=(8, 0, 0), head=(12, 0, -6))
    for sfx, sx, y in (("R", 1.0, -0.34), ("L", -1.0, -0.52)):
        A.plant(sk, sit, sfx, (0.0, y * k, 0.0), yaw=-sx * 12.0, pole=v3(sx * 0.3, 1.0, 0.3))
    for sfx in ("L", "R"):
        arm_fk(sk, sit, sfx, add=18.0, swing=40.0, flex=30.0, out=16.0)
        sit.hands[sfx] = hand_shape("spread", 0.6)
    fall = Pose()
    fall.hip = v3(0.0, -0.80 * k, 0.20 * k - hips_rest[2])
    spine(fall, hips=(-62, 0, -6), lean=-4, chest_lean=-4, neck=(12, 0, 0), head=(16, 0, -8))
    for sfx, sx, y in (("R", 1.0, -0.36), ("L", -1.0, -0.50)):
        fall.legs[sfx] = LegIK(ankle=v3(sx * 0.16 * k, y * k, 0.09 * k), foot=rxd(20.0) @ rzd(-sx * 14.0), toe=0.0,
                               pole=v3(sx * 0.3, 0.5, 1.0))
    for sfx in ("L", "R"):
        arm_fk(sk, fall, sfx, add=10.0, swing=60.0, flex=24.0, out=26.0)
        fall.hands[sfx] = hand_shape("spread", 0.6)
    ground = Pose()
    ground.hip = v3(-0.02 * k, -1.02 * k, 0.11 * k - hips_rest[2])
    spine(ground, hips=(-90, 2, -4), lean=-4, chest_lean=-5, neck=(-6, 0, 0), head=(-10, 4, 46))
    ground.legs["R"] = LegIK(ankle=v3(0.20 * k, -0.52 * k, 0.085 * k), foot=rxd(4.0) @ rzd(-16.0), toe=0.0,
                             pole=v3(0.35, 0.3, 1.0))
    ground.legs["L"] = LegIK(ankle=v3(-0.22 * k, -0.20 * k, 0.07 * k), foot=rxd(76.0) @ rzd(18.0), toe=0.0,
                             pole=v3(-0.3, 0.0, 1.0))
    pre = Solver(sk).solve(ground)
    for sfx, sx in A.SIDES:
        p = pre.P[f"upper_arm.{sfx}"] + v3(sx * 0.46 * k, (0.12 if sfx == "L" else -0.16) * k, 0.0)
        p[2] = 0.035 * k
        hand_on(sk, ground, sfx, p, v3(sx * 0.8, 0.3 * sx, 0.0), v3(0.0, 0.0, 1.0), pole=v3(sx * 0.5, 0.0, -1.0),
                along_share=0.5, palm_off=0.012, clav=0.4)
        ground.hands[sfx] = hand_shape("relaxed", 0.8)
    impact_p = ground.copy()
    impact_p.hip = impact_p.hip + v3(0.0, 0.0, -0.012 * k)
    add_rot(impact_p, "chest", rxd(-3.0))
    add_rot(impact_p, "head", rxd(-8.0))
    # the left leg is still bent at the impact and slides out straight during the settle
    impact_p.legs["L"] = LegIK(ankle=v3(-0.20 * k, -0.42 * k, 0.09 * k), foot=rxd(36.0) @ rzd(16.0), toe=0.0,
                               pole=v3(-0.3, 0.3, 1.0))
    return Keys(solver, [(0, _stand(sk), "inout"), (4, hit, "snap"), (step_r - 4, r_up, "inout"), (step_r, r_dn, "in"),
                         (step_l - 4, l_up, "inout"), (step_l, l_dn, "in"), (impact - 13, sit, "inout"),
                         (impact - 6, fall, "in"), (impact, impact_p, "heavy"), (impact + 8, ground, "out"),
                         (N, ground, "inout")])


def death_side(sk: Skeleton, solver: Solver, N: int, impact: int) -> Keys:
    """Spun round: a hit on the left shoulder spins the body ~100 deg to the left on its feet (the feet pivot on the
    balls), the knees fold and it drops onto its left side (``impact``). Ends lying on the left side, knees bent."""
    k = sk.scale
    hips_rest = sk.head["hips"]
    hit = _stand(sk)
    hit.hip = hit.hip + v3(0.01 * k, -0.02 * k, -0.02 * k)
    spine(hit, twist=16, chest_twist=14, side=4, lean=-2, neck=(-4, 4, 6), head=(-6, 6, 10), hips=(0, 0, 6))
    arm_fk(sk, hit, "L", add=22.0, swing=-30.0, flex=34.0, out=24.0)
    arm_fk(sk, hit, "R", add=30.0, swing=24.0, flex=36.0, out=4.0)
    for sfx in ("L", "R"):
        hit.hands[sfx] = hand_shape("claw", 0.8)

    def spun(yaw: float, hip_z: float, lean: float, side: float, knee_pole: float = 0.0) -> Pose:
        p = Pose()
        p.hip = v3(0.0, 0.0, hip_z * k - hips_rest[2])
        spine(p, hips=(lean * 0.4, side * 0.5, yaw), lean=lean, chest_lean=lean * 0.6, side=side, twist=10,
              chest_twist=8, neck=(6, 4, 4), head=(10, 8, 8))
        for sfx, sx in A.SIDES:
            A.plant(sk, p, sfx, (0.0, 0.0, 0.0), yaw=yaw * (0.9 if sfx == "L" else 0.75) - sx * 6.0, pitch=-18.0,
                    toe=18.0, pivot="ball", pole=rzd(yaw) @ v3(sx * 0.2 + knee_pole, 1.0, 0.0))
        return p
    turn = spun(48.0, 0.92, 4.0, -4.0)
    _limp_arms(sk, turn, swing=-10.0, flex=30.0, out=26.0)
    turn.hands["L"] = hand_shape("spread", 0.7)
    turn.hands["R"] = hand_shape("spread", 0.7)
    fold = spun(92.0, 0.64, 18.0, -12.0, knee_pole=-0.4)
    _limp_arms(sk, fold, swing=6.0, flex=24.0, out=20.0)
    # falling onto the left side
    drop = Pose()
    drop.hip = v3(-0.22 * k, 0.05 * k, 0.36 * k - hips_rest[2])
    spine(drop, hips=(20, -55, 100), lean=14, chest_lean=8, side=-8, neck=(4, -6, 0), head=(6, -10, 4))
    A.leg_fk(drop, "L", swing=60.0, out=6.0, knee=80.0, ankle=-20.0)
    A.leg_fk(drop, "R", swing=48.0, out=-2.0, knee=70.0, ankle=-20.0)
    arm_fk(sk, drop, "L", add=34.0, swing=55.0, flex=20.0)
    arm_fk(sk, drop, "R", add=50.0, swing=45.0, flex=30.0)
    for sfx in ("L", "R"):
        drop.hands[sfx] = hand_shape("relaxed", 0.8)
    ground = Pose()
    ground.hip = v3(-0.30 * k, 0.08 * k, 0.17 * k - hips_rest[2])
    spine(ground, hips=(12, -90, 104), lean=10, chest_lean=6, side=9, chest_side=5, neck=(-6, 4, 0), head=(-4, 2, 6))
    A.leg_fk(ground, "L", swing=50.0, out=4.0, knee=86.0, ankle=-28.0)
    A.leg_fk(ground, "R", swing=66.0, out=-6.0, knee=72.0, ankle=-30.0)
    # lying on the left side the body's sagittal plane is the floor: the lower (left) arm flexed forward along the
    # floor, the upper (right) arm drooping forward across the chest onto the floor in front
    arm_fk(sk, ground, "L", add=36.0, swing=78.0, flex=28.0, twist=-10.0)
    arm_fk(sk, ground, "R", add=78.0, swing=50.0, flex=34.0, twist=10.0)
    for sfx in ("L", "R"):
        ground.hands[sfx] = hand_shape("relaxed", 0.9)
    impact_p = ground.copy()
    impact_p.hip = impact_p.hip + v3(0.0, 0.0, -0.012 * k)
    add_rot(impact_p, "head", ryd(-6.0))
    return Keys(solver, [(0, _stand(sk), "inout"), (4, hit, "snap"), (12, turn, "inout"), (21, fold, "inout"),
                         (impact - 6, drop, "in"), (impact, impact_p, "heavy"), (impact + 8, ground, "out"),
                         (N, ground, "inout")])


# =============================================================================================
# downed crawl
# =============================================================================================
CRAWL_HIPS_Y = -0.30          # hips joint, m ahead of the root (the body lies along +Y, head forward)
CRAWL_BETA = 0.6              # hand stance share of the cycle (per hand)
CRAWL_HAND_FRONT = 0.56       # hand touch-down, m ahead of the root
CRAWL_HAND_X = 0.25           # hands' lane, m either side of the centre line
CRAWL_PALM = 0.012            # palm contact point in front of the hand bone (m)


def crawl_hand(sfx: str, ph: float, speed: float, N: int) -> tuple[float, float, bool]:
    """(y, lift, stance) of a hand at its own phase (0 = touch-down)."""
    T = N / FPS
    D = speed * CRAWL_BETA * T
    if ph < CRAWL_BETA:
        return CRAWL_HAND_FRONT - D * ph / CRAWL_BETA, 0.0, True
    w = (ph - CRAWL_BETA) / (1.0 - CRAWL_BETA)
    Ts = (1.0 - CRAWL_BETA) * T
    m = -speed * Ts
    y = hermite(CRAWL_HAND_FRONT - D, CRAWL_HAND_FRONT, m, m, w)
    return y, 0.06 * math.sin(math.pi * w) ** 1.2, False


def downed_crawl(sk: Skeleton, f: int, N: int, speed: float) -> Pose:
    """Bleed-out drag crawl: prone, chest propped on the forearms, the hands reach and pull in turn (planted palms
    stay put while the root moves forward at ``speed``), the body rolls toward the pulling arm, the legs drag with a
    weak contralateral knee draw, the head up looking ahead."""
    k = sk.scale
    ph = (f % N) / N
    hips_rest = sk.head["hips"]
    b2 = CRAWL_BETA / 2.0
    pull_r = math.cos(TAU * (ph - b2))          # +1 mid right pull, -1 mid left pull
    surge = math.cos(TAU * 2.0 * (ph - b2))     # +1 mid pull (either arm)
    pose = Pose()
    pose.hip = v3(0.015 * k * pull_r, CRAWL_HIPS_Y * k, 0.13 * k - hips_rest[2])
    spine(pose, hips=(87.0, 5.0 * pull_r, -4.0 * pull_r), lean=-10.0 - 2.0 * surge, chest_lean=-8.0 - 1.5 * surge,
          side=-3.0 * pull_r, twist=5.0 * pull_r, chest_twist=3.0 * pull_r, neck=(-24.0 + 2.0 * surge, 0.0, 0.0),
          head=(-16.0 + 3.0 * surge, -2.0 * pull_r, 4.0 * pull_r))
    pre = Solver(sk).solve(pose)
    del pre
    for sfx, sx in A.SIDES:
        hph = (ph - (0.0 if sfx == "R" else 0.5)) % 1.0
        y, lift, stance = crawl_hand(sfx, hph, speed, N)
        p = v3(sx * CRAWL_HAND_X * k, y * k, lift * k)
        along = unit(v3(-sx * 0.30, 1.0, -0.15 * lift / 0.06))
        hand_on(sk, pose, sfx, p, along, v3(sx * 0.05, 0.1 * lift / 0.06, -1.0), pole=v3(sx * 0.9, -0.25, -0.5),
                along_share=0.5, palm_off=CRAWL_PALM, clav=0.8)
        pose.hands[sfx] = hand_shape("claw", 0.6) if stance else hand_shape("relaxed", 0.8)
        # legs: drag, the leg opposite the pulling hand draws its knee a little out and up
        draw = max(0.0, math.cos(TAU * (hph - b2)))   # this hand pulls -> the other leg draws
        other = "L" if sfx == "R" else "R"
        A.leg_fk(pose, other, swing=4.0 + 16.0 * draw, out=6.0 + 14.0 * draw, knee=10.0 + 38.0 * draw, ankle=-52.0,
                 twist=-8.0 * draw)
    return pose


def crawl_slide(sk: Skeleton, frames: list, N: int, speed: float) -> float:
    """Worst deviation (mm/frame) of a planted palm's contact point from the ground motion (-speed along +Y)."""
    worst = 0.0
    step = speed / FPS * sk.scale
    for sfx in ("L", "R"):
        prev = None
        for f, s in enumerate(frames):
            hph = ((f % N) / N - (0.0 if sfx == "R" else 0.5)) % 1.0
            if hph >= CRAWL_BETA:
                prev = None
                continue
            b = f"hand.{sfx}"
            local = v3(0.0, 0.5 * sk.length(b), -CRAWL_PALM * sk.scale)
            cp = s.P[b] + s.W[b] @ sk.B[b] @ local
            if prev is not None:
                dev = math.hypot(float(cp[0] - prev[0]), float(cp[1] - prev[1] + step)) * 1000.0
                worst = max(worst, dev)
            prev = cp
    return worst


# =============================================================================================
# factory
# =============================================================================================
LOCO8 = tuple(f"{g}_{s}" for g in ("walk", "run") for s in DIRS)
TRANSITIONS = ("walk_start", "walk_stop", "run_start", "run_stop")
HITS = ("hit_react_back", "hit_react_left", "hit_react_right")
DEATHS = ("death_front_b", "death_back_b", "death_side")
#: Start / stop shape: (hand-off cycle frame, right-foot lift frame or braking-step frame, ...), see ``clips``.
NAMES = LOCO8 + TRANSITIONS + HITS + DEATHS + ("downed_crawl", "dozer_walk_heavy")


def clips(sk: Skeleton, solver: Solver, table: dict, G: dict, idle_frames: int) -> dict[str, Clip]:
    """Every D3-04 clip of ``table`` (``anim_humanoid.CLIPS``) as a ``Clip``. ``G`` = the base gaits (walk, run)."""
    import _anim_humanoid as H  # noqa: PLC0415

    out: dict[str, Clip] = {}
    names = [n for n in NAMES if n in table]
    for name in names:
        row = table[name]
        N, speed, ev = int(row["frames"]), float(row["speed"]), dict(row.get("events", {}))
        if name in LOCO8:
            base, suffix = name.split("_", 1)
            g = dir_gait(sk, G[base], WALK_SHAPE if base == "walk" else RUN_SHAPE, DIRS[suffix])
            assert g.frames == N and abs(g.speed - speed) < 1e-9, name
            out[name] = Clip(name, N, True, (lambda f, g=g: g.pose(sk, f)), speed, g, ev)
        elif name == "dozer_walk_heavy":
            g = dozer_heavy_gait(table)
            out[name] = Clip(name, N, True, (lambda f, g=g: g.pose(sk, f)), speed, g, ev)
        elif name == "downed_crawl":
            out[name] = Clip(name, N, True, (lambda f, N=N, v=speed: downed_crawl(sk, f, N, v)), speed, None, ev,
                             reach_fix=False, floor=0)
        elif name in HITS:
            fn = hit_back(sk, solver, N) if name == "hit_react_back" else hit_side(sk, solver, N, 1.0 if name.endswith("left") else -1.0)
            out[name] = Clip(name, N, False, fn, speed, None, ev, reach_fix=False)
        elif name in DEATHS:
            if name == "death_front_b":
                fn = death_front_b(sk, solver, N, ev["knees"], ev["impact"])
            elif name == "death_back_b":
                fn = death_back_b(sk, solver, N, ev["step_r"], ev["step_l"], ev["impact"])
            else:
                fn = death_side(sk, solver, N, ev["impact"])
            out[name] = Clip(name, N, False, fn, speed, None, ev, reach_fix=False, floor=int(ev["impact"]), no_sink=True)
        elif name in TRANSITIONS:
            base = name.split("_")[0]
            g = G[base]
            ref = ref_cycle(solver, g)
            idle0 = ref_idle0(solver, H.idle, idle_frames)
            h = int(row["handoff"])
            if name == "walk_start":
                tr = start_transition(sk, g, ref, idle0, N, h, lift_at=2.0, lean_amp=4.0, lift_bump=0.03)
            elif name == "run_start":
                tr = start_transition(sk, g, ref, idle0, N, h, lift_at=1.5, lean_amp=10.0, lift_bump=0.06)
            elif name == "walk_stop":
                tr = stop_transition(sk, g, ref, idle0, N, h, t_stop=float(ev["step_l"]), lean_amp=3.0, lift_bump=0.03)
            else:
                tr = stop_transition(sk, g, ref, idle0, N, h, t_stop=float(ev["step_r"]), lean_amp=9.0, lift_bump=0.05,
                                     l_land=float(ev["step_l"]), r_lift=float(ev["step_l"]) + 2.0,
                                     stop_dist=float(row["stop_m"]))
            out[name] = transition_clip(sk, solver, name, N, tr, ev)
    return out


def root_curve(clip: Clip) -> list[float]:
    """Root travel (m at 1.78 m) at frames 0..N of a start / stop clip."""
    tr = clip.transition
    s0 = tr.s(0.0)
    return [tr.s(float(f)) - s0 for f in range(clip.frames + 1)]


# =============================================================================================
# checks and SOURCE.txt notes
# =============================================================================================
#: Clips whose solved frames ``anim_humanoid.build`` keeps for the checks / notes below.
KEEP = ("idle", "walk", "run") + TRANSITIONS + ("downed_crawl", "death_front_b", "death_back_b", "death_side")


def transition_slide(sk: Skeleton, clip: Clip, frames: list) -> float:
    """Worst motion (mm/frame) of a planted foot's contact point in world space (root moved by ``curve``)."""
    tr = clip.transition
    worst = 0.0
    for sfx in ("L", "R"):
        prev = None
        for f, s in enumerate(frames):
            d, pitch, _lift, _toe, st = tr.feet[sfx](float(f))
            if not st:
                prev = None
                continue
            gp = sk.ground(sfx)
            piv = gp["heel"] if pitch >= 0 else gp["ball"]
            cp = s.P[f"foot.{sfx}"] + s.W[f"foot.{sfx}"] @ (piv - gp["ankle"])
            cp = cp + np.array([tr.g.direction[0], tr.g.direction[1], 0.0]) * tr.s(float(f)) * sk.scale
            if prev is not None and prev[1] == (pitch >= 0):
                worst = max(worst, float(np.linalg.norm(cp - prev[0])) * 1000.0)
            prev = (cp, pitch >= 0)
    return worst


def pose_err(a, b) -> float:
    """Worst bone head distance (mm) between two solved frames."""
    return max(float(np.linalg.norm(a.P[k] - b.P[k])) for k in a.P) * 1000.0


def check_row(sk: Skeleton, table: dict, name: str, clip: Clip, baked, keep: dict) -> str:
    """Extra SOURCE check text for a D3-04 clip."""
    if name in TRANSITIONS:
        base = name.split("_")[0]
        h = int(table[name]["handoff"])
        N = clip.frames
        txt = f" slide={transition_slide(sk, clip, baked.frames):.3f}mm/f"
        if base in keep and "idle" in keep:
            cyc, idle = keep[base].frames, keep["idle"].frames
            if name.endswith("start"):
                txt += (f" idle0_err={pose_err(baked.frames[0], idle[0]):.2f}mm"
                        f" handoff_err={pose_err(baked.frames[N], cyc[h]):.2f}mm")
            else:
                txt += (f" handoff_err={pose_err(baked.frames[0], cyc[h]):.2f}mm"
                        f" idle0_err={pose_err(baked.frames[N], idle[0]):.2f}mm")
        return txt
    if name == "downed_crawl":
        return f" palm_slide={crawl_slide(sk, baked.frames, clip.frames, clip.speed):.3f}mm/f"
    return ""


def source_notes(sk: Skeleton, table: dict, clips_: dict, keep: dict) -> dict[str, str]:
    out: dict[str, str] = {}
    out["locomotion_blend"] = (
        "crew 8-way blend set (D3-04): two BlendSpace2D (or two 3x3 grids of AnimationNodeBlend2/3), one per gait, "
        "blend position = the local move direction (x = right, y = forward, unit length) and ONE speed_scale per gait "
        "= v / (clip speed x motion_scale): walk (1.6 m/s, 30 f) at (0,1) walk, (0.71,0.71) walk_fr, (1,0) walk_r, "
        "(0.71,-0.71) walk_br, (0,-1) walk_b, (-0.71,-0.71) walk_bl, (-1,0) walk_l, (-0.71,0.71) walk_fl; run "
        "(3.5 m/s, 21 f) the same with run_*. Every clip of a gait has the same length, speed and stance share and the "
        "right foot down at normalised time 0, the left at 0.5 (`foot_down` in the clip rows), so blend them on one "
        "shared normalised time (BlendSpace2D sync = true, or seek every clip to the same time): the planted foot is "
        "the same foot in every direction. Walk <-> run: crossfade at the walk_run split (or a Blend2 on speed with "
        "both spaces advancing on the same normalised time: walk 1 s and run 0.7 s cycles; R down at 0 in both). "
        "strafe_l / strafe_r (1.2 m/s, 18 f shuffle) and walk_back (1.3 m/s) stay for the single-clip picker; the "
        "8-way set replaces them inside the blend spaces.")
    out["locomotion_transitions"] = (
        "walk_start / run_start: idle frame 0 -> the cycle; the clip's last frame IS walk frame 3 / run frame 4 "
        "(`handoff`), so switch to the cycle at that frame (no crossfade needed). walk_stop / run_stop: the clip's "
        "frame 0 IS walk / run frame 0 (`handoff`: the right heel strike) and the last frame IS idle frame 0. In "
        "place: A moves the root by `curve.<clip>` (root_m per frame, m at 1.78 m x motion_scale; the speed at both "
        "ends equals the cycle speed / 0): planted feet stay world-still at that root motion. Start = accelerate "
        "from 0 to the cycle speed by the right foot's first plant (step_r), then the cycle speed; stop = decelerate "
        "from the cycle speed to 0 at the last plant (walk: step_l, run: step_r), then settle into idle.")
    for name in TRANSITIONS:
        c = clips_.get(name)
        if c is None or not hasattr(c, "transition"):
            continue
        curve = root_curve(c)
        out[f"curve.{name}"] = (f"root_m={','.join(f'{x:.4f}' for x in curve)} total_m={curve[-1]:.3f} "
                                f"handoff={name.split('_')[0]}@{table[name]['handoff']}")
    out["hit_react_dirs"] = (
        "hit reacts by where the shot came from (damage info `direction` = bullet travel, d = direction in the body's "
        "local frame, x right, z back): from the front (d.z > 0.5, travelling toward the back) hit_react; from behind "
        "(d.z < -0.5) hit_react_back; from the left (travelling right, d.x > 0.5) hit_react_left; from the right "
        "hit_react_right. 15 f each, standing on the spot, start and end at idle frame 0's pose.")
    out["death_variants"] = (
        "deaths (feet planted at the start, root never moves): face down = death_front (pitch) and death_front_b "
        "(crumple onto the knees at `knees`, then forward); onto the back = death_back and death_back_b (two steps "
        "back, sits down and falls; the body ends ~1.0-1.9 m behind the root); death_side = spun ~100 deg to the left "
        "and dropped onto the left side (pick it for side hits or at random). `impact` = the body hits the floor. "
        "From the impact on the body rests on the floor (lowest skin vertex at the root plane, nothing below it).")
    ds = []
    for name in ("death_front_b", "death_back_b", "death_side"):
        b = keep.get(name)
        if b is None:
            continue
        s = b.frames[-1]
        hp = s.P["hips"]
        hd = s.P["head"]
        top = max(float(p[2]) for p in s.P.values())
        ds.append(f"{name}: hips ({hp[0]:.2f},{hp[2]:.2f},{-hp[1]:.2f}) head ({hd[0]:.2f},{hd[2]:.2f},{-hd[1]:.2f}) "
                  f"highest joint {top:.2f} m")
    if ds:
        out["death_end_poses"] = "last frame, Godot root space: " + "; ".join(ds)
    out["downed_crawl_pose"] = (
        f"downed_crawl: prone, head toward -Z (forward); hips joint {-CRAWL_HIPS_Y:.2f} m behind the root (Godot z "
        f"+{-CRAWL_HIPS_Y:.2f}), the head ~0.5 m ahead, the feet ~1.2 m behind; the palms plant at z "
        f"{-CRAWL_HAND_FRONT:.2f}, x +-{CRAWL_HAND_X:.2f} and stay world-still while A moves the root forward at speed_mps "
        f"(2 pulls per loop, right hand down at 0, left at 0.5). An NPC / bleed-out crawl (PD2 downed players do not "
        f"crawl): the body rests on the floor every frame.")
    out["dozer_walk_heavy_speed"] = (
        "dozer_walk_heavy: the Wrecker's advance stomp, 1.7 m/s native = 1.8 m/s (EnemyDef.params.advance_speed) on "
        "the 1.88 m Wrecker (motion_scale 1.056): speed_scale 1.0 while advancing; a step every 0.55 s "
        "(HeavySpecialTweak.wrecker_step_interval_s), step_r@0 / step_l@16 = heel strikes. Same gun hold at HandR/Socket "
        "as dozer_walk; to use it set EnemyDef.params.anim_walk_clip = dozer_walk_heavy and clip_speeds 1.7.")
    return out


def row_extra(row: dict) -> str:
    """Extra ``clip.<name>`` SOURCE fields of the D3-04 table keys."""
    extra = ""
    if "dir_deg" in row:
        a = math.radians(row["dir_deg"])
        extra += f" dir_deg={row['dir_deg']:g} dir_godot=({math.sin(a):.3f},0,{-math.cos(a):.3f}) foot_down=R@0.00,L@0.50"
    if "handoff" in row:
        extra += f" handoff_frame={row['handoff']}"
    return extra
