"""P5 NPC ambient clips (D3-02) for the ``humanoid`` library: club dancers, bar staff, bouncer, bank teller,
gallery curator, a texting walker and two cower variants (Afterhours, Gallery Night, Meridian Federal, Rolling
Thunder casting).

Private helper for ``anim_humanoid.py`` (called from ``_anim_humanoid.clips``). Same conventions as the D2-02
NPC set in ``_anim_humanoid``: degrees, the character faces +Y with the root at the feet (in place), props held
per ``_anim_humanoid.GRIPS`` (documented relative to HandR/Socket, or HandL/Socket for left-hand props), furniture
placement in the module constants below (written to SOURCE.txt by ``anim_humanoid._p5_source``).

Planted feet: every foot goal is a fixed ``plant`` (heel lifts pivot about the ball, so the ball never moves);
steps (``steps``) hold each plant exactly, lift and carry the foot in an arc and set it down on its next plant
(no sliding). ``contact_slide`` measures it on the solved skeleton.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
import _anim_humanoid as H
from _anim import (FPS, TAU, Pose, Skeleton, Solver, add_rot, arm_fk, cos_ease, hand_on, hand_shape, neutral,
                   pulse, rxd, smooth, spine, stand, unit, v3)
from _anim_humanoid import breathe, look, prop_hand, tremble

# =============================================================================================
# placement (metres at 1.78 m, Blender axes: x right, y ahead of the root, z up)
# =============================================================================================
#: Dance loops: 8 beats at 120 BPM = 120 frames (a beat every 15 frames, beat 1 on frame 0). Other tempos:
#: speed_scale = bpm / DANCE_BPM (a 124 BPM track -> 1.0333).
DANCE_BPM = 120
DANCE_BEATS = 8
BEAT_F = 15
#: Bar (bartender_wipe / bartender_pour): bar top height and its near edge ahead of the root.
BAR_Z = 1.05
BAR_EDGE = 0.28
#: bartender_wipe: rag circle centre (x, y) on the bar top (the centre drifts +-WIPE_DRIFT in x), radius.
WIPE_C = (0.10, 0.47)
WIPE_DRIFT = 0.07
WIPE_R = 0.075
#: bartender_pour: the bottle and the glass stand here on the bar top (x, y); the bottle starts and ends there.
BOTTLE_AT = (0.27, 0.44)
GLASS_AT = (0.02, 0.42)
BOTTLE_H = 0.30
GLASS_H = 0.10
#: Teller counter (teller_count): top height and near edge; the counted bills are laid down at TELLER_PILE.
COUNTER_Z = 1.00
COUNTER_EDGE = 0.28
TELLER_PILE = (0.25, 0.44)
TELLER_PILE_H = 0.006
#: teller_count taps: the stack's bottom (long) edge stops this far above the counter (the left fingers behind
#: it reach lower and touch first).
TELLER_TAP_CLEAR = 0.016
#: curator_inspect: the painting's centre height and the wall face ahead of the root (frame 0 stance); the
#: curator steps back CURATOR_STEP and returns.
PAINT_Z = 1.55
PAINT_WALL = 0.80
CURATOR_STEP = 0.38
#: cower_stand: a wall face this far behind the root clears the body at every frame (it can back up to it).
COWER_WALL = 0.21
#: walk_text native speed (m/s) and cycle (two steps).
TEXT_SPEED = 1.2


# =============================================================================================
# helpers
# =============================================================================================
def cyc_ease(keys: list[tuple[float, object]], period: float, x: float):
    """Cyclic cosine-eased interpolation of ``(time, value)`` keys (times ascending in [0, period))."""
    n = len(keys)
    x = x % period
    if x < keys[0][0]:
        x += period
    for i in range(n):
        t0, a = keys[i]
        t1, b = keys[(i + 1) % n]
        if i + 1 == n:
            t1 += period
        if t0 <= x <= t1:
            return A.lerp(a, b, cos_ease((x - t0) / max(t1 - t0, 1e-9)))
    return keys[0][1]


def bump(x: float, a: float, b: float, edge: float) -> float:
    """1 on [a, b] with smoothstep edges ``edge`` wide outside it, 0 elsewhere."""
    return smooth(a - edge, a, x) * (1.0 - smooth(b, b + edge, x))


def steps(sk: Skeleton, pose: Pose, sfx: str, plants: list[tuple], f: float, N: int, dur: float, lift: float = 0.05,
          roll: float = 0.0, roll_deg: float = 12.0, yaw: float = 8.0) -> np.ndarray:
    """Cyclic stepping for one foot. ``plants`` = [(land_frame, dx, dy, heel_deg), ...] (frames ascending):
    the foot is set down on plant i at its frame (offset (dx, dy) m from its rest place, heel raised heel_deg
    about the ball), holds it EXACTLY until ``dur`` frames before the next plant, then lifts (arc ``lift`` m) and
    lands on the next one. ``roll`` frames before the lift the heel peels up to ``roll_deg`` (about the ball, so
    the ball stays put). Returns the offset used (m, world)."""
    k = sk.scale
    n = len(plants)
    lands = [float(p[0]) for p in plants]
    x = f % N
    if x < lands[0]:
        x += N
    i = n - 1
    for j in range(n):
        nxt = lands[j + 1] if j + 1 < n else lands[0] + N
        if lands[j] <= x < nxt:
            i = j
            break
    nxt = lands[i + 1] if i + 1 < n else lands[0] + N
    p0, p1 = plants[i], plants[(i + 1) % n]
    off_lift = nxt - dur
    h0 = float(p0[3])
    h_roll = max(h0, roll_deg) if roll > 0 else h0
    if x <= off_lift:
        heel = h0 + (h_roll - h0) * smooth(off_lift - roll, off_lift, x) if roll > 0 else h0
        off = v3(p0[1] * k, p0[2] * k, 0.0)
    else:
        w = (x - off_lift) / dur
        s = smooth(0.12, 0.92, w)
        off = v3(A.lerp(p0[1], p1[1], s) * k, A.lerp(p0[2], p1[2], s) * k, lift * k * math.sin(math.pi * w))
        heel = A.lerp(h_roll, float(p1[3]), smooth(0.25, 0.95, w)) + 10.0 * math.sin(math.pi * w) * (1.0 - float(p1[3]) / 90.0)
    plant_mtp(sk, pose, sfx, off, -A.side_x(sfx) * yaw, heel)
    return off


def plant_mtp(sk: Skeleton, pose: Pose, sfx: str, off, yaw: float, heel: float, pole=None) -> None:
    """Leg goal: the foot at its rest place moved by ``off`` (m, world), turned ``yaw`` (deg, + = toes left) and
    its heel raised ``heel`` deg about the toe joint (the ball, MTP), the toes bent back by the same angle: the
    toes stay exactly where they are (flat) while the heel peels up."""
    J = sk.head[f"toe.{sfx}"]
    R = A.foot_rot(yaw, -max(0.0, heel))
    ankle = J + R @ (sk.head[f"foot.{sfx}"] - J) + np.asarray(off, float)
    if pole is None:
        pole = A.rzd(yaw) @ v3(A.side_x(sfx) * 0.12, 1.0, 0.0)
    pose.legs[sfx] = A.LegIK(ankle=ankle, foot=R, toe=A.rad(max(0.0, heel)), pole=unit(pole))


def heel_plant(sk: Skeleton, pose: Pose, sfx: str, off, yaw: float, heel: float) -> None:
    """A planted foot (offset ``off`` m from its rest place, toes out ``yaw`` deg) with the heel raised ``heel``
    deg about the (fixed) toe joint."""
    k = sk.scale
    plant_mtp(sk, pose, sfx, v3(off[0] * k, off[1] * k, 0.0), -A.side_x(sfx) * yaw, heel)


_DIPS: dict[tuple, float] = {}


def surface_dip(sk: Skeleton, sfx: str, along, palm, shape: tuple, palm_off: float = 0.012, share: float = 0.5) -> float:
    """How far (m) the hand's skin reaches below the ``hand_on`` palm point for a hand pointing ``along`` with the
    palm facing ``palm`` (world) and finger shape ``shape``: raise a resting palm by this so the lowest skin
    (usually the thenar pad) just touches the surface. Cached per orientation."""
    key = (round(sk.scale, 6), sfx, tuple(np.round(along, 4)), tuple(np.round(palm, 4)), shape, palm_off, share)
    if key not in _DIPS:
        probe = A.probe_for(sk)
        bones = {i for b, i in probe.index.items() if b.endswith("." + sfx)
                 and b.startswith(("hand", "thumb", "index", "middle", "ring", "pinky"))}
        pose = neutral(sk)
        sx = A.side_x(sfx)
        p = v3(sx * 0.2 * sk.scale, 0.40 * sk.scale, 1.05 * sk.scale)
        hand_on(sk, pose, sfx, p, along, palm, pole=v3(sx * 0.9, -0.4, -0.35), along_share=share, palm_off=palm_off)
        pose.hands[sfx] = hand_shape(*shape)
        V = probe.posed(Solver(sk).solve(pose))
        z = V[np.isin(probe.bi[:, 0], list(bones)), 2]
        _DIPS[key] = max(0.0, float(p[2] - z.min()))
    return _DIPS[key]


def chest_pt(pre, sk: Skeleton, p) -> np.ndarray:
    k = sk.scale
    return A.bone_point(pre, sk, "chest", v3(p[0] * k, p[1] * k, p[2] * k))


def contact_slide(sk: Skeleton, frames: list, tol: float = 0.002) -> tuple[float, float]:
    """(worst horizontal slide in mm/frame of a heel (carried by the foot) / ball or toe-tip (carried by the toes)
    ground point that touches the floor (z < tol, 2 mm: a heel peeling up rolls, it does not slide) in two consecutive
    frames, lowest such point z in mm)."""
    worst = 0.0
    low = 1e9
    for sfx in ("L", "R"):
        g = sk.ground(sfx)
        prev = None
        for s in frames:
            Wf, Pf = s.W[f"foot.{sfx}"], s.P[f"foot.{sfx}"]
            Wt, Pt = s.W[f"toe.{sfx}"], s.P[f"toe.{sfx}"]
            J = sk.head[f"toe.{sfx}"]
            pts = (Pf + Wf @ (g["heel"] - g["ankle"]), Pt + Wt @ (g["ball"] - J), Pt + Wt @ (g["tip"] - J))
            low = min(low, *(float(p[2]) for p in pts))
            if prev is not None:
                for a, b in zip(prev, pts):
                    if a[2] < tol and b[2] < tol:
                        worst = max(worst, float(np.hypot(*(b - a)[:2])))
            prev = pts
    return worst * 1000.0, low * 1000.0


# =============================================================================================
# dance loops (beat-synced: 8 beats, BEAT_F frames each; beat 1 = frame 0)
# =============================================================================================
def dance_a(sk: Skeleton, f: int, N: int) -> Pose:
    """Low energy: a relaxed step-touch side to side (R out on 1, L touches on 2, L back out on 3, R touches on
    4; twice per loop), knees giving on every beat, shoulders and loose fists swaying with the weight shift."""
    k = sk.scale
    b = f / BEAT_F
    d = 0.15
    pose = Pose()
    # (land frame, dx, dy, heel): touches land on the ball with the heel up
    ro = steps(sk, pose, "R", [(0, d, 0.0, 0.0), (45, 0.0, 0.0, 24.0), (60, d, 0.0, 0.0), (105, 0.0, 0.0, 24.0)],
               f, N, dur=8, lift=0.045, roll=4, roll_deg=10.0, yaw=9.0)
    lo = steps(sk, pose, "L", [(15, d, 0.0, 24.0), (30, 0.0, 0.0, 0.0), (75, d, 0.0, 24.0), (90, 0.0, 0.0, 0.0)],
               f, N, dur=8, lift=0.045, roll=4, roll_deg=10.0, yaw=9.0)
    bias = math.cos(TAU * (b - 0.7) / 4.0)                # +1: weight on the right foot (beats 1-2), -1: on the left
    centre = 0.5 * (ro[0] + lo[0])
    dip = 0.5 + 0.5 * math.cos(TAU * (b - 0.12))           # knees give just after each beat
    pose.hip = v3(centre + 0.05 * k * bias, -0.02 * k, -0.045 * k - 0.022 * k * dip)
    spine(pose, lean=4.0 + 1.5 * dip, side=-3.0 * bias, twist=4.0 * bias, chest_lean=3.0, chest_side=-2.5 * bias,
          chest_twist=3.0 * math.sin(TAU * b / 2.0), hips=(3.0, 5.0 * bias, -3.0 * bias))
    look(pose, yaw=-6.0 * bias, pitch=2.0 + 4.0 * math.cos(TAU * (b - 0.2)), tilt=-3.0 * bias)
    for sfx, sx in A.SIDES:
        ph = math.pi * b + (0.0 if sfx == "R" else math.pi)
        arm_fk(sk, pose, sfx, add=26.0 + 4.0 * sx * bias, swing=24.0 + 9.0 * math.sin(ph), flex=78.0 + 10.0 * math.sin(ph + 0.6),
               twist=24.0, clav_up=2.0 + 3.0 * max(0.0, sx * bias), wrist_flex=8.0)
        pose.hands[sfx] = hand_shape("loose_fist", 0.55)
    breathe(pose, f / FPS, 2.0 * BEAT_F / FPS, 0.6)
    return pose


def dance_b(sk: Skeleton, f: int, N: int) -> Pose:
    """Mid groove: feet planted wide, a knee bounce on every beat and a hip sway every two beats (the off-side
    heel peels up on the sway), alternating forward arm pumps on beats 1-6 and two claps on beats 7 and 8."""
    k = sk.scale
    b = f / BEAT_F
    s = math.sin(math.pi * b - 0.6)                         # sway: + right
    pose = Pose()
    heel_plant(sk, pose, "L", (-0.06, 0.03), 10.0, 16.0 * max(0.0, s) ** 1.5)
    heel_plant(sk, pose, "R", (0.06, -0.03), 12.0, 16.0 * max(0.0, -s) ** 1.5)
    dip = 0.5 + 0.5 * math.cos(TAU * (b - 0.1))
    pose.hip = v3(0.045 * k * s, -0.02 * k, -0.05 * k - 0.028 * k * dip)
    spine(pose, lean=6.0 + 2.0 * dip, side=-3.0 * s, twist=5.0 * math.sin(math.pi * b), chest_lean=4.0,
          chest_side=-3.5 * s, chest_twist=6.0 * math.sin(math.pi * b + 0.4), hips=(4.0, 6.0 * s, -4.0 * s))
    look(pose, yaw=8.0 * math.sin(math.pi * b / 2.0), pitch=1.0 + 5.0 * math.cos(TAU * (b - 0.18)), tilt=-3.0 * s)
    breathe(pose, f / FPS, 2.0 * BEAT_F / FPS, 0.7)
    pre = Solver(sk).solve(pose)
    clap = smooth(5.45, 5.95, b) * (1.0 - smooth(7.55, 7.98, b))
    opn = 0.5 - 0.5 * math.cos(TAU * b)                     # 0 on the beats (the claps)
    Wc = pre.W["chest"]
    for sfx, sx in A.SIDES:
        p_on = 0.5 + 0.5 * math.cos(math.pi * b + (0.0 if sfx == "R" else math.pi))   # 1: this fist forward
        pump = (chest_pt(pre, sk, (sx * (0.17 - 0.07 * p_on), 0.17 + 0.25 * p_on, -0.12 + 0.13 * p_on)),
                Wc @ v3(-sx * 0.35, 0.9, 0.25 * p_on), Wc @ v3(-sx * 0.6, -0.1, -0.8))
        clp = (chest_pt(pre, sk, (sx * (0.022 + 0.11 * opn), 0.33, 0.02 + 0.03 * opn)), Wc @ v3(-sx * 0.15, 0.6, 0.8),
               Wc @ v3(-sx, 0.1, 0.0))
        p, al, pa = H.blend_hand([pump, clp], [1.0 - clap, clap])
        hand_on(sk, pose, sfx, p, al, pa, pole=Wc @ v3(sx * 0.9, -0.35, -0.55), along_share=0.55)
        pose.hands[sfx] = hand_shape("loose_fist", 0.7).blend(hand_shape("flat", 0.4), clap)
    return pose


def dance_c(sk: Skeleton, f: int, N: int) -> Pose:
    """High energy: bouncing on the balls of the feet (heels up on the off-beats, down and knees bent on the beat),
    both arms up over the head pumping with the bounce and swaying every two beats, head banging on the beat."""
    k = sk.scale
    b = f / BEAT_F
    up = 0.5 - 0.5 * math.cos(TAU * (b - 0.08))             # 0 on the beat (down), 1 on the off-beat (up)
    s = math.sin(math.pi * b - 0.4)
    pose = Pose()
    heel_plant(sk, pose, "L", (-0.05, 0.02), 11.0, 4.0 + 15.0 * up + 4.0 * max(0.0, s))
    heel_plant(sk, pose, "R", (0.05, -0.02), 11.0, 4.0 + 15.0 * up + 4.0 * max(0.0, -s))
    pose.hip = v3(0.03 * k * s, -0.025 * k, -0.085 * k + 0.07 * k * up)
    spine(pose, lean=5.0 - 3.0 * up, side=-2.5 * s, twist=4.0 * s, chest_lean=2.0 - 4.0 * up, chest_side=-2.0 * s,
          hips=(4.0 - 2.0 * up, 4.0 * s, -3.0 * s))
    look(pose, yaw=10.0 * math.sin(math.pi * b / 2.0 + 0.3), pitch=-6.0 + 9.0 * (1.0 - up), tilt=-4.0 * s)
    breathe(pose, f / FPS, 2.0 * BEAT_F / FPS, 1.0)
    pre = Solver(sk).solve(pose)
    Wc = pre.W["chest"]
    for sfx, sx in A.SIDES:
        reach = 0.70 + 0.06 * up
        p = chest_pt(pre, sk, (sx * 0.21 + 0.07 * s, 0.07 + 0.03 * (1.0 - up), reach))
        hand_on(sk, pose, sfx, p, Wc @ v3(sx * 0.12 - 0.2 * s, 0.15, 1.0), Wc @ v3(-sx * 0.2, 1.0, 0.0),
                pole=Wc @ v3(sx * 1.0, 0.0, -0.3), along_share=0.5)
        pose.hands[sfx] = hand_shape("loose_fist", 0.5 + 0.4 * (1.0 - up))
    return pose


# =============================================================================================
# bar staff
# =============================================================================================
def _bar_stance(sk: Skeleton, pose: Pose, t: float, T: float, lean: float) -> None:
    k = sk.scale
    pose.hip = v3(0.008 * k * math.sin(TAU * t / T), -0.035 * k, -0.03 * k)
    stand(sk, pose, spread=0.05, stagger_l=0.04, stagger_r=-0.05, yaw_l=10, yaw_r=14)
    spine(pose, lean=lean, chest_lean=0.6 * lean, hips=(3.0, 0.0, -2.0))


def bartender_wipe(sk: Skeleton, f: int, N: int) -> Pose:
    """Behind the bar (top BAR_Z, near edge BAR_EDGE ahead): wiping the bar top with a rag in small circles (one
    per second, the centre drifting across WIPE_C +- WIPE_DRIFT), the left hand flat on the bar; eyes on the bar,
    one glance up at the room mid-loop."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    glance = bump(t, 3.3, 4.2, 0.5)
    _bar_stance(sk, pose, t, T, 17.0 - 5.0 * glance)
    drift = math.sin(TAU * t / T)
    add_rot(pose, "chest", A.rzd(-4.0 * drift))
    look(pose, yaw=6.0 * drift * (1.0 - glance) + 14.0 * glance, pitch=24.0 - 30.0 * glance)
    breathe(pose, t, T / 3.0, 0.8)
    th = TAU * round(T) * t / T                            # one circle per second (clockwise seen from above)
    c = v3((WIPE_C[0] + WIPE_DRIFT * drift) * k, WIPE_C[1] * k, BAR_Z * k)
    o = c + v3(WIPE_R * k * math.cos(th), -WIPE_R * k * math.sin(th), 0.0)
    prop_hand(sk, pose, "rag", H.level_frame(yaw=6.0 * math.sin(th) - 6.0), o, pole=v3(0.85, -0.3, 0.3))
    al, pa = v3(0.35, 0.94, 0.0), v3(0.0, 0.0, -1.0)
    z = BAR_Z * k + surface_dip(sk, "L", al, pa, ("rest_flat", 1.0)) + 0.001 * k
    hand_on(sk, pose, "L", v3(-0.20 * k, 0.40 * k, z), al, pa, pole=v3(-0.9, -0.4, -0.35), along_share=0.5, palm_off=0.012)
    pose.hands["L"] = hand_shape("rest_flat", 1.0)
    return pose


#: bartender_pour keys: (frame, bottle mouth (x, y, z above BAR_Z), tilt deg (top toward -X, the glass)).
_MOUTH_POUR = (GLASS_AT[0] + 0.012, GLASS_AT[1], GLASS_H + 0.045)
POUR_KEYS = [(0, (BOTTLE_AT[0], BOTTLE_AT[1], BOTTLE_H), 0.0),
             (16, (BOTTLE_AT[0] - 0.02, BOTTLE_AT[1] - 0.02, BOTTLE_H + 0.15), 0.0),
             (32, (_MOUTH_POUR[0] + 0.06, _MOUTH_POUR[1], _MOUTH_POUR[2] + 0.03), 70.0),
             (42, _MOUTH_POUR, 108.0),
             (72, _MOUTH_POUR, 122.0),
             (84, (_MOUTH_POUR[0] + 0.05, _MOUTH_POUR[1], _MOUTH_POUR[2] + 0.04), 62.0),
             (98, (BOTTLE_AT[0] - 0.02, BOTTLE_AT[1] - 0.02, BOTTLE_H + 0.12), 0.0),
             (110, (BOTTLE_AT[0], BOTTLE_AT[1], BOTTLE_H), 0.0)]
#: pour_start / pour_end: the bottle passes 100 deg (liquid runs) on the way down / up.
POUR_TILT = 100.0


def pour_bottle(sk: Skeleton, f: float) -> tuple[np.ndarray, np.ndarray, float]:
    """(R, origin, tilt) of the bottle at frame ``f`` of bartender_pour (Blender, metres at scale)."""
    k = sk.scale
    keys = POUR_KEYS
    if f >= keys[-1][0]:
        mouth, tilt = v3(*keys[-1][1]), keys[-1][2]
    else:
        for (f0, m0, a0), (f1, m1, a1) in zip(keys, keys[1:]):
            if f0 <= f <= f1:
                e = cos_ease((f - f0) / (f1 - f0))
                mouth, tilt = A.lerp(v3(*m0), v3(*m1), e), A.lerp(a0, a1, e)
                break
    mouth = mouth + v3(0.0, 0.0, BAR_Z)
    wob = 2.0 * math.sin(TAU * f / 10.0) * smooth(42, 46, f) * (1.0 - smooth(68, 72, f))
    R = A.rzd(-8.0 * smooth(16, 32, f) * (1.0 - smooth(84, 98, f))) @ A.ryd(-(tilt + wob))
    o = mouth * k - R @ v3(0.0, 0.0, BOTTLE_H * k)
    return R, o, tilt


def bartender_pour(sk: Skeleton, f: int, N: int) -> Pose:
    """Pours a drink: the right hand on the bottle standing on the bar at BOTTLE_AT lifts it (``lift``), tips it
    over the glass at GLASS_AT (which the left hand steadies on the bar), pours (``pour_start`` .. ``pour_end``),
    sets it back down at BOTTLE_AT (``set_down``) and rests there, looking up at the customer. Frame 0 = the last
    frame (loop), so it also works played once."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    pouring = smooth(20, 40, f) * (1.0 - smooth(80, 100, f))
    _bar_stance(sk, pose, t, T, 8.0 + 4.0 * pouring)
    add_rot(pose, "chest", A.rzd(4.0 * pouring))
    rest = smooth(108, 122, f) * (1.0 - smooth(N - 10, N + 4, f))
    look(pose, yaw=10.0 * pouring + (-8.0 + 6.0 * math.sin(TAU * 2 * t / T)) * rest, pitch=30.0 * (1.0 - rest) - 2.0 * rest)
    breathe(pose, t, T / 2.0, 0.8)
    R, o, _tilt = pour_bottle(sk, float(f))
    prop_hand(sk, pose, "bottle", R, o, pole=v3(0.8, -0.4, -0.6), twist=0.6)
    prop_hand(sk, pose, "glass", H.level_frame(yaw=-12.0), v3(GLASS_AT[0] * k, GLASS_AT[1] * k, BAR_Z * k),
              pole=v3(-0.9, -0.4, -0.4))
    return pose


# =============================================================================================
# bouncer, teller
# =============================================================================================
def bouncer_idle(sk: Skeleton, f: int, N: int) -> Pose:
    """Door bouncer: wide planted stance, chest up, arms crossed high; slow weight shifts and head turns
    scanning the queue, and once per loop the left wrist comes up for a glance at the watch (``watch``)."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    s = math.sin(TAU * t / T)
    pose = neutral(sk)
    pose.hip = v3(0.022 * k * s, -0.03 * k, -0.034 * k - 0.005 * k * abs(s))
    stand(sk, pose, spread=0.10, stagger_l=0.03, stagger_r=-0.02, yaw_l=14, yaw_r=17)
    spine(pose, lean=-1.5, chest_lean=-3.0, side=-1.2 * s, hips=(-2.0, 1.8 * s, 0.0), neck=(3, 0, 0))
    w = H.windows(t, T, [(-1.0, 6.3), (6.3, 8.5), (8.5, 9.0)], 0.6)[1]
    yaw = cyc_ease([(0.0, 0.0), (1.0, 0.0), (1.8, -34.0), (3.2, -30.0), (4.0, 4.0), (4.9, 28.0), (5.9, 30.0),
                    (6.4, 4.0), (9.2, 4.0)], T, t)
    look(pose, yaw=yaw * (1.0 - w) - 8.0 * w, pitch=-4.0 + 2.0 * math.sin(TAU * 3 * t / T) + 38.0 * w, tilt=3.0 * w)
    breathe(pose, t, T / 3.0, 1.1)
    pre = Solver(sk).solve(pose)
    Wc = pre.W["chest"]
    for sfx, sx in A.SIDES:
        cross = (chest_pt(pre, sk, (-sx * 0.11, 0.18, 0.02 - (0.035 if sx > 0 else 0.0))), Wc @ v3(-sx * 0.95, 0.25, 0.1),
                 Wc @ v3(0.0, -1.0, 0.1))
        p, al, pa = cross
        if sfx == "L" and w > 0.0:
            watch = (chest_pt(pre, sk, (0.03, 0.34, -0.03)), Wc @ v3(0.95, 0.2, 0.3), Wc @ v3(0.1, 0.25, -1.0))
            p, al, pa = H.blend_hand([cross, watch], [1.0 - w, w])
        hand_on(sk, pose, sfx, p, al, pa, pole=Wc @ v3(sx * 0.5, -0.1, -1.0), along_share=0.5)
        pose.hands[sfx] = hand_shape("relaxed", 1.3).blend(hand_shape("relaxed", 0.8), w if sfx == "L" else 0.0)
    return pose


#: teller_count schedule (s): count [0, 4.0), lay the counted bills down (4.0 .. 5.3), square the stack with two
#: taps on the counter (5.3 .. 7.2), back to counting.
TELLER_TAPS = (5.9, 6.3)


def teller_stack(sk: Skeleton, t: float, T: float) -> tuple[np.ndarray, np.ndarray, float]:
    """(R, origin, tap weight) of the cash stack in the left hand at time ``t`` (s)."""
    k = sk.scale
    w_tap = bump(t, 5.55, 6.65, 0.4)
    R_cnt = H.level_frame(yaw=-6.0, pitch=38.0)
    o_cnt = v3(-0.075 * k, 0.33 * k, 1.13 * k) + v3(0.0, 0.0, 0.004 * k * math.sin(TAU * t / 1.0))
    a, b = TELLER_TAPS
    gap = b - a
    h = 0.045 * abs(math.sin(math.pi * (t - a) / gap)) if a - gap / 2 <= t <= b + gap / 2 else 0.045
    R_tap = H.level_frame(yaw=-6.0, pitch=88.0)
    o_tap = v3(-0.06 * k, 0.40 * k, (COUNTER_Z + TELLER_TAP_CLEAR + 0.033 + h) * k)
    return A.mslerp(R_cnt, R_tap, w_tap), A.lerp(o_cnt, o_tap, w_tap), w_tap


def teller_count(sk: Skeleton, f: int, N: int) -> Pose:
    """Bank teller at the counter (top COUNTER_Z, near edge COUNTER_EDGE): the cash stack in the left palm
    (``cash`` at HandL/Socket) tipped toward the eyes, the right thumb flicking bills off its right end into the
    right hand (one every 8 frames for 4 s), then the counted bills laid down on the counter at TELLER_PILE
    (``stack_down``), then the stack squared on its edge with two taps on the counter (``tap_1``, ``tap_2``)."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = neutral(sk)
    pose.hip = v3(0.006 * k * math.sin(TAU * t / T), -0.03 * k, -0.03 * k)
    stand(sk, pose, spread=0.04, stagger_l=0.03, stagger_r=-0.04, yaw_l=9, yaw_r=12)
    w_cnt, w_down, w_sq = H.windows(t, T, [(-0.6, 4.0), (4.0, 5.3), (5.3, 7.3)], 0.5)
    spine(pose, lean=8.0 + 3.0 * w_down, chest_lean=6.0, twist=-3.0 * w_down, chest_twist=-4.0 * w_down, hips=(2.0, 0.0, -2.0))
    glance = bump(t, 7.35, 7.75, 0.3)
    look(pose, yaw=4.0 - 16.0 * w_down + 4.0 * glance, pitch=34.0 + 6.0 * w_down - 30.0 * glance)
    breathe(pose, t, T / 3.0, 0.8)
    Rs, os_, _w = teller_stack(sk, t, T)
    prop_hand(sk, pose, "cash", Rs, os_, pole=v3(-0.9, -0.5, -0.4))
    # right hand: flick (stack space), lay down (counter), square (the stack's right end)
    u = (f % 8) / 8.0
    out = smooth(0.0, 0.45, u) * (1.0 - smooth(0.45, 1.0, u)) * smooth(0.2, 0.5, t) * (1.0 - smooth(3.7, 4.0, t))
    fl = (os_ + Rs @ v3((0.105 + 0.08 * out) * k, -0.01 * k, (0.006 + 0.012 * out) * k), Rs @ v3(-0.25, 0.95, -0.15),
          Rs @ v3(-1.0, 0.0, 0.25))
    press = bump(t, 4.75, 4.95, 0.12)
    al_d, pa_d = v3(-0.35, 0.94, 0.0), v3(0.0, 0.1, -1.0)
    z_d = COUNTER_Z * k + TELLER_PILE_H * k + surface_dip(sk, "R", al_d, pa_d, ("rest_flat", 1.0), share=0.55)
    down = (v3(TELLER_PILE[0] * k, TELLER_PILE[1] * k, z_d + (0.001 + 0.035 * (1.0 - press)) * k), al_d, pa_d)
    sq = (os_ + Rs @ v3(0.10 * k, 0.026 * k, 0.0), Rs @ v3(-0.3, 0.2, 1.0), Rs @ v3(-1.0, 0.0, 0.0))
    p, al, pa = H.blend_hand([fl, down, sq], [w_cnt, w_down, w_sq])
    hand_on(sk, pose, "R", p, al, pa, pole=v3(0.9, -0.5, -0.4), along_share=0.55)
    hs = hand_shape("pinch", 0.9)
    hs.thumb = (10.0 + 26.0 * out, 14.0, 12.0 + 10.0 * out)
    pose.hands["R"] = hs.blend(hand_shape("rest_flat", 1.0), w_down).blend(hand_shape("support", 0.5), w_sq)
    return pose


# =============================================================================================
# curator
# =============================================================================================
#: curator_inspect steps (land frames): back R@93, L@110, forward L@256, R@272 (dur 16 f each).
CURATOR_PLANTS = {"R": [(93, 0.0, -CURATOR_STEP, 0.0), (272, 0.0, 0.0, 0.0)],
                  "L": [(110, 0.0, -CURATOR_STEP, 0.0), (256, 0.0, 0.0, 0.0)]}
CURATOR_DUR = 16


def curator_inspect(sk: Skeleton, f: int, N: int) -> Pose:
    """Gallery curator at a painting (centre PAINT_Z high on a wall PAINT_WALL ahead): leans in close and scans
    it, steps back CURATOR_STEP (two planted steps, right then left), considers it with the head tilting one way
    then the other, steps forward again (left, right) and leans back in. Hands clasped behind the back
    throughout; in place overall (the feet return to their frame-0 plants)."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    d = CURATOR_DUR
    steps(sk, pose, "R", CURATOR_PLANTS["R"], f, N, dur=d, lift=0.06, roll=5, roll_deg=10.0, yaw=7.0)
    steps(sk, pose, "L", CURATOR_PLANTS["L"], f, N, dur=d, lift=0.06, roll=5, roll_deg=10.0, yaw=7.0)
    back = cyc_ease([(0.0, 0.0), (79.0, 0.0), (114.0, -CURATOR_STEP), (238.0, -CURATOR_STEP), (274.0, 0.0)], N, f)
    side = (-0.04 * bump(f, 78, 92, 5) + 0.04 * bump(f, 95, 109, 5) + 0.04 * bump(f, 241, 255, 5)
            - 0.04 * bump(f, 258, 271, 5))
    lean_in = cyc_ease([(0.0, 1.0), (66.0, 1.0), (96.0, 0.0), (250.0, 0.0), (300.0, 1.0)], N, f)
    pose.hip = v3(side * k, (back - 0.02 - 0.035 * lean_in) * k, (-0.016 - 0.006 * lean_in) * k)
    lean, chest = 2.0 + 13.0 * lean_in, 1.0 + 9.0 * lean_in
    tilt = -12.0 * bump(t, 4.4, 5.6, 0.6) + 10.0 * bump(t, 6.3, 7.4, 0.6)
    spine(pose, lean=lean, chest_lean=chest, hips=(2.0 + 3.0 * lean_in, 0.0, 0.0), side=0.25 * tilt)
    scan = lean_in * 0.7 + 0.3
    look(pose, yaw=11.0 * scan * math.sin(TAU * 3 * t / T + 0.4) + 3.0 * math.sin(TAU * t / T),
         pitch=-0.85 * (lean + chest) + 3.0 + 6.0 * scan * math.sin(TAU * 5 * t / T + 1.1), tilt=tilt)
    breathe(pose, t, T / 4.0, 0.8)
    pre = Solver(sk).solve(pose)
    Ws = pre.W["spine"]
    # left hand: back of the hand on the lower back, fingers down-right; the right hand round the left wrist
    pl = A.bone_point(pre, sk, "spine", v3(0.0, -0.165 * k, -0.035 * k))
    hand_on(sk, pose, "L", pl, Ws @ v3(0.45, -0.1, -0.88), Ws @ v3(0.0, -1.0, 0.1), pole=Ws @ v3(-1.0, -0.6, 0.1),
            along_share=0.5)
    pose.hands["L"] = hand_shape("relaxed", 1.2)
    pr = A.bone_point(pre, sk, "spine", v3(-0.03 * k, -0.20 * k, 0.005 * k))
    hand_on(sk, pose, "R", pr, Ws @ v3(-0.85, -0.2, -0.45), Ws @ v3(0.0, 1.0, 0.25), pole=Ws @ v3(1.0, -0.6, 0.1),
            along_share=0.5)
    pose.hands["R"] = hand_shape("grip", 0.6)
    return pose


# =============================================================================================
# walking while texting
# =============================================================================================
def text_upper(sk: Skeleton, pose: Pose, ph: float, f: int) -> None:
    """walk_text: head down at the phone held in both hands at chest height (right hand = ``phone`` grip, the
    left hand round the lower-left edge), thumbs typing; the phone rides half the trunk bob."""
    k = sk.scale
    t = f / FPS
    look(pose, pitch=34.0 + 2.0 * math.sin(TAU * ph * 2.0 + 0.5), yaw=0.0)
    add_rot(pose, "neck", rxd(-6.0))
    pre = Solver(sk).solve(pose)
    o = chest_pt(pre, sk, (0.0, 0.31, -0.07))
    o[2] = 0.5 * o[2] + 0.5 * 1.16 * k
    R = H.facing_frame(o, H.head_eye(pre, sk))
    R = R @ rxd(8.0)
    prop_hand(sk, pose, "phone", R, o, pole=v3(0.8, -0.4, -0.5), twist=0.5)
    hand_on(sk, pose, "L", o + R @ v3(-0.040 * k, 0.010 * k, -0.035 * k), R @ v3(0.25, 0.15, 1.0), R @ v3(1.0, -0.35, 0.0),
            pole=v3(-0.8, -0.4, -0.5), along_share=0.45, palm_off=0.012)
    for sfx, ph0 in (("R", 0.0), ("L", 0.5)):
        tap = max(0.0, math.sin(TAU * (3.5 * t + ph0)))
        hs = hand_shape("phone" if sfx == "R" else "support", 0.9)
        hs.thumb = (8.0 + 6.0 * tap, 18.0 + 22.0 * tap, 14.0 + 18.0 * tap)
        pose.hands[sfx] = hs


def gaits(table: dict) -> dict:
    out = {}
    if "walk_text" in table:
        row = table["walk_text"]
        out["walk_text"] = A.Gait(speed=row["speed"], frames=row["frames"], beta=0.63, lift=0.055, drop=0.035, bob=0.010,
                                  strike=12.0, toeoff=-24.0, lean=3.0, pelvis_yaw=4.0, pelvis_roll=2.5, arm_swing=4.0,
                                  elbow=60.0, sway=0.015, centre={"L": (0.0, -0.04), "R": (0.0, -0.04)},
                                  head_bob_comp=0.5, upper=text_upper)
    return out


# =============================================================================================
# cowering
# =============================================================================================
def cower_seated(sk: Skeleton, f: int, N: int) -> Pose:
    """On a chair (npc_seat: seat SEAT_H), curled forward over the knees, forearms over the crown of the head,
    trembling and rocking slightly."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    H.seated(sk, pose)
    rock = math.sin(TAU * t / T)
    pose.hip = pose.hip + v3(0.0, 0.03 * k, 0.0)
    spine(pose, hips=(-78.0, 0.0, 0.0), lean=94.0 + 2.5 * rock, chest_lean=26.0 + 2.0 * rock, neck=(14, 0, 0),
          head=(18, 0, 3.0 * math.sin(TAU * 2 * t / T)))
    for sfx, sx in A.SIDES:
        plant_mtp(sk, pose, sfx, v3(sx * 0.04 * k, 0.34 * k, 0.0), -sx * 6.0, 10.0, pole=v3(sx * 0.2, 0.5, 1.0))
    tremble(pose, t, 1.3)
    breathe(pose, t, T / 4.0, 1.2)
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        p = A.bone_point(pre, sk, "head", v3(-sx * 0.035 * k, -0.01 * k, 0.17 * k))
        hand_on(sk, pose, sfx, p, pre.W["head"] @ v3(-sx * 0.7, -0.55, -0.1), pre.W["head"] @ v3(0.0, 0.1, -1.0),
                pole=pre.W["chest"] @ v3(sx * 0.7, 0.7, -0.3), along_share=0.4)
        pose.hands[sfx] = hand_shape("claw", 0.6)
    return pose


#: cower_stand flinches (s): a fast recoil (``flinch_1``, ``flinch_2`` at the start of each).
COWER_FLINCH = (1.3, 3.6)


def cower_stand(sk: Skeleton, f: int, N: int) -> Pose:
    """Standing terrified (free-standing; see SOURCE `cower_stand_space` for a wall behind): knees bent, hunched,
    turned half away, both forearms up in front of the face with the palms out; trembling, and twice per loop a
    sharp flinch (recoil down and away, arms tighter)."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    fl = sum(pulse((t - a) % T, 0.10, 0.9) for a in COWER_FLINCH)
    pose = Pose()
    pose.hip = v3((-0.01 - 0.02 * fl) * k, (-0.05 - 0.025 * fl) * k, (-0.075 - 0.05 * fl) * k)
    stand(sk, pose, spread=0.035, stagger_l=0.06, stagger_r=-0.08, yaw_l=8, yaw_r=20)
    spine(pose, lean=10.0 + 9.0 * fl, chest_lean=10.0 + 6.0 * fl, twist=8.0 + 10.0 * fl, chest_twist=6.0 + 8.0 * fl,
          side=1.5 + 2.0 * fl, neck=(6, 0, 0), head=(8.0 + 4.0 * fl, 0, 0))
    look(pose, yaw=20.0 + 16.0 * fl, pitch=6.0 + 8.0 * fl, tilt=-6.0 - 4.0 * fl)
    tremble(pose, t, 1.0 + 0.6 * fl)
    breathe(pose, t, T / 6.0, 1.3)
    pre = Solver(sk).solve(pose)
    Wc = pre.W["chest"]
    for sfx, sx in A.SIDES:
        p = chest_pt(pre, sk, (sx * (0.12 - 0.03 * fl) + 0.02, 0.30 - 0.05 * fl, 0.36 - (0.03 if sx < 0 else 0.0) + 0.02 * fl))
        hand_on(sk, pose, sfx, p, Wc @ v3(-sx * 0.2, 0.3, 1.0), Wc @ v3(sx * 0.2, 1.0, 0.0), pole=Wc @ v3(sx * 0.5, 0.0, -1.0),
                along_share=0.5)
        pose.hands[sfx] = hand_shape("spread", 0.7).blend(hand_shape("claw", 0.5), fl)
    return pose


# =============================================================================================
# registry
# =============================================================================================
STATIONARY = {"dance_a": dance_a, "dance_b": dance_b, "dance_c": dance_c, "bartender_wipe": bartender_wipe,
              "bartender_pour": bartender_pour, "bouncer_idle": bouncer_idle, "teller_count": teller_count,
              "curator_inspect": curator_inspect, "cower_seated": cower_seated, "cower_stand": cower_stand}
#: Standing clips whose hips are lowered where a planted foot would be out of reach.
REACH_FIX = ("dance_a", "dance_b", "dance_c", "bartender_wipe", "bartender_pour", "bouncer_idle", "teller_count",
             "curator_inspect", "cower_stand")


# =============================================================================================
# SOURCE.txt notes (measured on the baked frames)
# =============================================================================================
def _g(p) -> str:
    """Blender (x, y fwd, z up) -> Godot (x, y up, -z fwd), as text."""
    return f"({p[0]:.3f},{p[2]:.3f},{-p[1]:.3f})"


def _skin(sk: Skeleton, frames: list, step: int = 3) -> list[np.ndarray]:
    probe = A.probe_for(sk)
    return [probe.posed(s) for s in frames[::step]]


def source_notes(sk: Skeleton, table: dict, keep: dict) -> dict[str, str]:
    """SOURCE.txt facts for the P5 set: tempo, furniture placement (Godot axes, root space) and clearances."""
    k = sk.scale
    out: dict[str, str] = {}
    foot_x = []
    for n in ("dance_a", "dance_b", "dance_c"):
        if n in keep:
            foot_x += [float(s.P[f"foot.{x}"][0]) for s in keep[n].frames for x in "LR"]
    if foot_x:
        out["dance_sync"] = (
            f"dance_a, dance_b, dance_c: {DANCE_BEATS} beats at {DANCE_BPM} BPM per loop ({DANCE_BEATS * BEAT_F} f, a beat "
            f"every {BEAT_F} f, beat 1 on frame 0; the knees are lowest just after each beat); for a track at B BPM play "
            f"at speed_scale = B / {DANCE_BPM} and start the clip on a downbeat. In place: dance_a step-touches (R steps "
            f"out 0.15 m on beat 1, L touches beside it on 2, L steps back on 3, R touches home on 4, twice per loop; "
            f"feet planted between the steps), dance_b / dance_c keep both balls planted (the heels peel up); ankles "
            f"within Godot x {min(foot_x):.2f}..{max(foot_x):.2f} m (keep ~0.6 m clear around the root)")
    wipe, pour = keep.get("bartender_wipe"), keep.get("bartender_pour")
    if wipe is not None and pour is not None:
        front = max(float(V[V[:, 2] < (BAR_Z - 0.06) * k][:, 1].max()) for b in (wipe, pour) for V in _skin(sk, b.frames, 5))
        rag = np.array([H.prop_frame(sk, s, "rag")[1] for s in wipe.frames])
        b0 = H.prop_frame(sk, pour.frames[0], "bottle")[1]
        sd = int(table["bartender_pour"]["events"]["set_down"])
        b1 = H.prop_frame(sk, pour.frames[sd], "bottle")[1]
        gl = np.array([H.prop_frame(sk, s, "glass")[1] for s in pour.frames])
        ps, pe = (int(table["bartender_pour"]["events"][e]) for e in ("pour_start", "pour_end"))
        mouths = []
        for s in pour.frames[ps:pe + 1]:
            R, o = H.prop_frame(sk, s, "bottle")
            mouths.append(o + R @ v3(0.0, 0.0, BOTTLE_H * k))
        mouths = np.array(mouths)
        rim = gl[0] + v3(0.0, 0.0, GLASS_H * k)
        out["bar_placement"] = (
            f"bartender_wipe / bartender_pour: root on the floor behind the bar, facing it; bar top {BAR_Z:.2f} m high, its "
            f"near edge {BAR_EDGE:.2f} m ahead of the root (Godot z = {-BAR_EDGE:.2f}; 6 cm and more below the top the body stays behind "
            f"z = {-front:.2f}). wipe: the rag (rag_grip) on the bar top in r {WIPE_R} m circles, one per second, the centre "
            f"drifting over Godot x {rag[:, 0].min() + WIPE_R:.2f}..{rag[:, 0].max() - WIPE_R:.2f}, z {-WIPE_C[1]:.2f}; the left "
            f"palm flat on the bar at Godot ({-0.20 * k:.2f}, {BAR_Z:.2f}, {-0.40 * k:.2f}). pour: the bottle (bottle_grip) "
            f"stands on the bar at Godot {_g(b0)} at frame 0 and from set_down@{sd} ({_g(b1)}), lifted at lift@"
            f"{table['bartender_pour']['events']['lift']}; from pour_start@{ps} to pour_end@{pe} it is tipped past "
            f"{POUR_TILT:g} deg with its mouth {float((mouths[:, 2] - rim[2]).min()):.3f}..{float((mouths[:, 2] - rim[2]).max()):.3f} m "
            f"above the glass rim, within {float(np.hypot(*(mouths[:, :2] - rim[:2]).T).max()):.3f} m of the glass axis; the "
            f"glass (glass_grip, LEFT hand) stands at Godot {_g(gl[0])} throughout (moves "
            f"{float(np.linalg.norm(gl - gl[0], axis=1).max()) * 1000:.1f} mm)")
    tel = keep.get("teller_count")
    if tel is not None:
        ev = table["teller_count"]["events"]
        front = max(float(V[V[:, 2] < (COUNTER_Z - 0.06) * k][:, 1].max()) for V in _skin(sk, tel.frames, 5))
        R, o = H.prop_frame(sk, tel.frames[int(ev["tap_1"])], "cash")
        edge = o + R @ v3(0.0, -0.033 * k, 0.0)
        Rc, oc = H.prop_frame(sk, tel.frames[0], "cash")
        out["teller_counter"] = (
            f"teller_count: root on the floor behind the counter, facing it; counter top {COUNTER_Z:.2f} m high, near edge "
            f"{COUNTER_EDGE:.2f} m ahead (Godot z = {-COUNTER_EDGE:.2f}; 6 cm and more below the top the body stays behind z = {-front:.2f}). "
            f"The stack (cash_grip, LEFT hand) is held tipped toward the eyes at Godot {_g(oc)} while counting "
            f"(count_start@{ev['count_start']}..count_end@{ev['count_end']}, a bill flicked every 8 f), tapped on its long edge "
            f"onto the counter at tap_1@{ev['tap_1']} / tap_2@{ev['tap_2']} (its bottom edge {TELLER_TAP_CLEAR * 100:.1f} cm above "
            f"the top at Godot {_g(edge)}: the left fingers behind it touch the counter); the right hand "
            f"lays the counted bills on the counter at Godot ({TELLER_PILE[0] * k:.2f}, {COUNTER_Z:.2f}, {-TELLER_PILE[1] * k:.2f}) "
            f"at stack_down@{ev['stack_down']} (an optional static bill pile there)")
    cur = keep.get("curator_inspect")
    if cur is not None:
        nose = min(PAINT_WALL * k - float(V[:, 1].max()) for V in _skin(sk, cur.frames, 4))
        feet0 = [cur.frames[0].P[f"foot.{x}"] for x in "LR"]
        ret = max(float(np.linalg.norm(cur.frames[-1].P[f"foot.{x}"] - p)) for x, p in zip("LR", feet0))
        back = min(float(s.P[f"foot.{x}"][1]) for s in cur.frames for x in "LR")
        ev = table["curator_inspect"]["events"]
        out["curator_painting"] = (
            f"curator_inspect: the painting's centre {PAINT_Z:.2f} m high on a wall whose face is {PAINT_WALL:.2f} m ahead of "
            f"the root (Godot z = {-PAINT_WALL:.2f}), the root facing it; leaning in, the body comes to {nose:.2f} m from the "
            f"wall; steps back {CURATOR_STEP:.2f} m (step_back_r@{ev['step_back_r']}, step_back_l@{ev['step_back_l']}: the "
            f"ankles reach Godot z = {-back:.2f}) and forward again (step_fwd_l@{ev['step_fwd_l']}, step_fwd_r@"
            f"{ev['step_fwd_r']}); planted steps, the feet back on their frame-0 plants ({ret * 1000:.1f} mm), in place; "
            f"keep {CURATOR_STEP + 0.35:.2f} m clear behind the root")
    cs = keep.get("cower_seated")
    if cs is not None:
        hips = float(cs.frames[0].P["hips"][2])
        out["cower_seated_seat"] = (
            f"cower_seated: the npc_seat chair (seat top {H.SEAT_H:.2f} m, root on the floor under the seat centre), no "
            f"desk; hips joint {hips:.2f} m above the root, feet flat 0.34 m ahead (balls on the floor, heels just up), the "
            f"trunk curled forward over the knees, forearms over the head")
    cst = keep.get("cower_stand")
    if cst is not None:
        rear = -min(float(V[:, 1].min()) for V in _skin(sk, cst.frames, 3))
        out["cower_stand_space"] = (
            f"cower_stand: free-standing, in place; the rearmost skin is {rear:.2f} m behind the root, so a wall face at "
            f"Godot z = +{COWER_WALL:.2f} (or further back) clears it: back it up to a wall there. Flinches at flinch_1@"
            f"{table['cower_stand']['events']['flinch_1']}, flinch_2@{table['cower_stand']['events']['flinch_2']}")
    wt = keep.get("walk_text")
    if wt is not None:
        ph = np.array([H.prop_frame(sk, s, "phone")[1] for s in wt.frames])
        out["walk_text_speed"] = (
            f"walk_text: walking while texting at {table['walk_text']['speed']} m/s native (walk is 1.6), speed_scale = "
            f"v / {table['walk_text']['speed']}; the phone (phone_grip at HandR/Socket, the left hand on its lower-left "
            f"edge) at {ph[:, 2].min():.2f}..{ph[:, 2].max():.2f} m high, {ph[:, 1].mean():.2f} m ahead of the root, screen "
            f"toward the face (head down)")
    bo = keep.get("bouncer_idle")
    if bo is not None:
        s0 = bo.frames[0]
        w = abs(float(s0.P["foot.L"][0] - s0.P["foot.R"][0]))
        out["bouncer_stance"] = (
            f"bouncer_idle: in place, ankles {w:.2f} m apart, arms crossed high on the chest; slow head turns left "
            f"(~2-3 s) and right (~5-6 s); watch@{table['bouncer_idle']['events']['watch']} = mid wristwatch glance "
            f"(the left forearm up across the chest, 6.6..8.4 s)")
    return out
