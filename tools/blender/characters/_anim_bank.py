"""OF-D1 bank customers (Ostrander Federal) for the ``humanoid`` library: a queue at the rails, a customer at a teller
window, a customer writing at a check desk. Private helper of ``anim_humanoid.py`` (pure numpy; wired like
``_anim_civ_panic``). All loops, in place (the root never moves), speed 0; every periodic layer closes per loop.

* ``queue_idle`` / ``queue_idle_b`` / ``queue_idle_c`` (150 / 126 / 138 f, the group ``variants.queue_idle``): waiting in
  a queue at the rails, facing forward, the weight shifting foot to foot (the unloaded heel peels up about its ball, so
  no foot slides). ``queue_idle`` = hands clasped in front (the right hand round the left wrist), a glance at the
  wristwatch on the left wrist (``watch``); ``_b`` = the phone (``phone_grip`` at HandR/Socket) in the right hand at the
  chest, the thumb scrolling and typing, head down, one look up at the front of the line (``look_up``); ``_c`` =
  impatient: arms crossed high, the right fingers drumming on the left arm, a big sigh (``sigh``), a look back over the
  left shoulder down the line (``look_back``), a burst of toe taps (right heel planted).
* ``counter_customer`` (180 f): at a teller window, the root ``COUNTER_FACE`` m from the counter's customer face, the
  transaction ledge top ``LEDGE_Z`` m: leaning on the forearms, both palms flat on the ledge; the right hand slides a
  slip forward to the window (``slip_push``) and back, then talks with small open-hand gestures (the heel of the hand
  stays on the ledge) and a nod (``nod``).
* ``check_desk_write`` (150 f): at a standing check desk (top ``DESK_Z`` m, near edge ``DESK_EDGE`` m ahead): the left
  palm flat holding the slip, the right hand writing (resting on its little-finger edge, a pen pinch; no pen prop),
  leaning in; once per loop a look up (``look_up``) while the hand returns to the start of the line.

Hand contact is exact: after the IK goals are set, the lowest skin of each contact hand (``SkinProbe``) is moved onto
the surface plane (``_settle``). SOURCE ``contact.<clip>`` records the plane, the contact frames and the HandL /
HandR Socket origin height above the plane there (what the Godot test checks); ``bank_placement`` the marks.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
import _anim_humanoid as H
import _anim_life as life
import _anim_p5 as p5
from _anim import FPS, TAU, Clip, Pose, Skeleton, Solver, add_rot, arm_fk, hand_on, hand_shape, rxd, ryd, rzd, \
    spine, v3

#: the queue variant group (the first member is the original; A picks one per NPC, SOURCE ``queue_variants``)
GROUPS = {"queue_idle": ("queue_idle", "queue_idle_b", "queue_idle_c")}
#: the clips this module builds (each one row in anim_humanoid.CLIPS)
NAMES = ("queue_idle", "queue_idle_b", "queue_idle_c", "counter_customer", "check_desk_write")
KEEP = NAMES

# placement (metres at 1.78 m, Blender axes: x right, y ahead of the root, z up)
#: teller window: transaction ledge top height and the counter's customer face ahead of the root
LEDGE_Z = 1.05
COUNTER_FACE = 0.30
#: check desk: top height and near edge ahead of the root
DESK_Z = 1.00
DESK_EDGE = 0.25
#: counter_customer: palm points on the ledge at rest (x, y) and where the slip is pushed to (right hand)
REST_L = (-0.13, 0.55)
REST_R = (0.11, 0.56)
PUSH_R = (0.07, 0.70)
#: check_desk_write: the left palm on the slip, the writing line (x from .. to, y)
SLIP_L = (-0.14, 0.42)
LINE = (-0.01, 0.09, 0.40)

#: schedules (s); events are written as frames in anim_humanoid.CLIPS
WATCH = (2.55, 4.1)                    # queue_idle: the left wrist up (watch at the peak)
LOOK_UP_B = (2.3, 3.4)                 # queue_idle_b
SIGH = (0.5, 2.0)                      # queue_idle_c: inhale to 1.15, exhale (sigh) after
LOOK_BACK = (2.45, 3.6)                # queue_idle_c
TAPS = (3.75, 4.45)                    # queue_idle_c: toe taps (4 per second)
SLIDE = (0.9, 1.6, 1.85, 2.5)          # counter_customer: out, hold (slip_push), back
GESTURE = (3.0, 4.5)                   # counter_customer: open-hand gestures (two)
NOD = (4.6, 5.15)                      # counter_customer
LOOK_UP_W = (2.9, 4.0)                 # check_desk_write: look up / carriage return


def _hold(u: float, n: int, ph: float = 0.0, sharp: float = 2.2) -> float:
    """-1..1 with ``n`` whole cycles per loop that dwells at the extremes (the weight rests on one foot, then the other)."""
    s = math.sin(TAU * n * u + ph)
    return math.tanh(sharp * s) / math.tanh(sharp)


def _win(t: float, T: float, a: float, b: float, edge: float) -> float:
    """Cyclic window weight: 1 inside [a, b] (s) with smoothstep edges ``edge`` wide inside it, 0 outside."""
    w = 0.0
    for sh in (-T, 0.0, T):
        x = t + sh
        w = max(w, A.smooth(a, a + edge, x) * (1.0 - A.smooth(b - edge, b, x)))
    return w


def _cyc(t: float, T: float, n: int, ph: float = 0.0) -> float:
    return math.sin(TAU * n * t / T + ph)


# =============================================================================================
# shared: queue stance, surface contact
# =============================================================================================
def _stance(sk: Skeleton, pose: Pose, u: float, n: int, ph: float, amount: float = 0.024, lean: float = 0.0,
            spread: float = 0.05, heel: float = 7.0, tap: tuple | None = None) -> float:
    """Waiting stance: the weight shifting foot to foot (``n`` per loop, dwelling on each foot), the pelvis dropping on
    the unloaded side, its heel peeling up about the ball. ``tap`` = (right toe lift deg) about the planted heel.
    Returns the weight value (-1 = on the left foot, +1 = on the right)."""
    k = sk.scale
    w = _hold(u, n, ph)
    pose.hip = v3(amount * k * w, -0.02 * k, (-0.02 - 0.008 * abs(w)) * k)
    spine(pose, lean=lean, chest_lean=0.5 * lean, hips=(1.5, 0.0, 0.0))
    add_rot(pose, "hips", ryd(2.6 * w))
    add_rot(pose, "spine", ryd(-1.8 * w))
    add_rot(pose, "chest", ryd(-0.9 * w))
    for sfx, sx in A.SIDES:
        h = heel * max(0.0, -sx * w)                   # the unloaded foot's heel
        off = v3(sx * spread * k, (0.02 if sfx == "L" else -0.01) * k, 0.0)
        yaw = -sx * (9.0 if sfx == "L" else 12.0)
        if sfx == "R" and tap is not None:
            # the tapping foot keeps its heel down all loop (toes lift about the heel; one foot function, no pops)
            A.plant(sk, pose, sfx, off, yaw=yaw, pitch=tap[0], pivot="heel")
        else:
            p5.plant_mtp(sk, pose, sfx, off, yaw, h)
    return w


_MASKS: dict[tuple, dict] = {}


def _masks(sk: Skeleton) -> dict:
    """Probe vertex masks: the hand (+ fingers) and forearm skin of each side."""
    key = round(sk.scale, 6)
    if key not in _MASKS:
        probe = A.probe_for(sk)
        out = {}
        for sfx in ("L", "R"):
            hand = {i for b, i in probe.index.items() if b.endswith("." + sfx)
                    and b.startswith(("hand", "thumb", "index", "middle", "ring", "pinky"))}
            arm = {i for b, i in probe.index.items() if b in (f"forearm.{sfx}", f"upper_arm.{sfx}")}
            out[sfx] = np.isin(probe.bi[:, 0], list(hand))
            out["arm" + sfx] = np.isin(probe.bi[:, 0], list(arm))
        _MASKS[key] = out
    return _MASKS[key]


def _settle(sk: Skeleton, pose: Pose, plane: float, edge: float, sides: tuple, iters: int = 2) -> None:
    """Move each IK hand in ``sides`` vertically so the lowest skin of the hand (and of the forearm where it is over the
    surface, past ``edge`` ahead) lies exactly on the plane z = ``plane`` (m)."""
    probe = A.probe_for(sk)
    m = _masks(sk)
    solver = Solver(sk)
    for _it in range(iters):
        V = probe.posed(solver.solve(pose))
        done = True
        over = V[:, 1] > edge * sk.scale
        for sfx in sides:
            dz = plane * sk.scale - float(V[m[sfx] | (m["arm" + sfx] & over), 2].min())
            if abs(dz) > 2e-4:
                done = False
            pose.arms[sfx].wrist = pose.arms[sfx].wrist + v3(0.0, 0.0, dz)
        if done:
            break


# =============================================================================================
# queue_idle (a): hands clasped, a wristwatch glance
# =============================================================================================
QUEUE_GLANCES = {
    "queue_idle": [(0.00, -4.0, 3.0, -1.0), (0.22, 9.0, 1.0, 1.0), (0.78, -12.0, 2.0, 0.5)],
    "queue_idle_b": [(0.00, 2.0, 0.0, 0.0), (0.50, -3.0, 0.0, 0.0)],
    "queue_idle_c": [(0.00, 3.0, -2.0, 0.0), (0.68, -8.0, 0.0, -1.0)],
}


def _clasp(sk: Skeleton, pre) -> tuple[tuple, tuple]:
    """(left, right) hand goals for hands clasped in front of the lower belly: the left hand hangs with its back
    forward, the right hand wraps the left wrist from the front."""
    k = sk.scale
    Wh = pre.W["hips"]
    pl = A.bone_point(pre, sk, "hips", v3(-0.03 * k, 0.165 * k, -0.065 * k))
    left = (pl, Wh @ v3(0.55, 0.05, -0.83), Wh @ v3(0.0, -1.0, 0.05))
    pr = A.bone_point(pre, sk, "hips", v3(-0.04 * k, 0.20 * k, -0.02 * k))
    right = (pr, Wh @ v3(-0.85, 0.05, -0.52), Wh @ v3(0.0, -1.0, 0.1))
    return left, right


def queue_idle(sk: Skeleton, f: int, N: int) -> Pose:
    """Hands clasped in front, the weight shifting; a glance at the wristwatch on the left wrist (WATCH), the head
    otherwise glancing about the hall in short holds."""
    t = f / FPS
    T = N / FPS
    u = f / N
    pose = Pose()
    _stance(sk, pose, u, 1, 0.4)
    w = _win(t, T, WATCH[0], WATCH[1], 0.45)
    lf = life.Life(QUEUE_GLANCES["queue_idle"], T)
    y, p, tl = life.glance(lf.keys, t, T)
    H.look(pose, yaw=y * (1.0 - w) + 12.0 * w, pitch=p * (1.0 - w) + 36.0 * w, tilt=tl * (1.0 - w) - 4.0 * w)
    add_rot(pose, "chest", rzd(life.CHEST_SHARE * lf.yaw(t - life.CHEST_LAG) * (1.0 - w) + 5.0 * w))
    H.breathe(pose, t, T / 3.0, 0.9)
    pre = Solver(sk).solve(pose)
    Wc = pre.W["chest"]
    left, right = _clasp(sk, pre)
    watch = (p5.chest_pt(pre, sk, (0.03, 0.33, -0.05)), Wc @ v3(0.95, 0.2, 0.25), Wc @ v3(0.1, 0.25, -1.0))
    pl, al, pa = H.blend_hand([left, watch], [1.0 - w, w])
    hand_on(sk, pose, "L", pl, al, pa, pole=Wc @ v3(-0.6, -0.2, -0.8), along_share=0.5)
    pose.hands["L"] = hand_shape("relaxed", 1.1)
    # the right hand: round the left wrist; while the watch is up it rests on the belly where the wrist was
    rest = (right[0] + Wc @ v3(0.02 * sk.scale, -0.025 * sk.scale, 0.02 * sk.scale), right[1], right[2])
    pr, ar, prm = H.blend_hand([right, rest], [1.0 - w, w])
    hand_on(sk, pose, "R", pr, ar, prm, pole=Wc @ v3(0.6, -0.2, -0.8), along_share=0.5)
    pose.hands["R"] = hand_shape("grip", 0.55).blend(hand_shape("relaxed", 1.0), w)
    return pose


# =============================================================================================
# queue_idle_b: the phone
# =============================================================================================
def queue_idle_b(sk: Skeleton, f: int, N: int) -> Pose:
    """The phone in the right hand at the chest, head down at it, the thumb scrolling / typing; once per loop a
    look up to the front of the line (LOOK_UP_B), the phone sinking a little. The left arm hangs."""
    t = f / FPS
    T = N / FPS
    u = f / N
    k = sk.scale
    pose = Pose()
    _stance(sk, pose, u, 1, 2.1, amount=0.020)
    w = _win(t, T, LOOK_UP_B[0], LOOK_UP_B[1], 0.35)
    lf = life.Life(QUEUE_GLANCES["queue_idle_b"], T)
    y, _p, _tl = life.glance(lf.keys, t, T)
    H.look(pose, yaw=y * (1.0 - w) - 6.0 * w, pitch=30.0 * (1.0 - w) - 2.0 * w + 1.5 * _cyc(t, T, 2), tilt=3.0 * (1.0 - w))
    add_rot(pose, "neck", rxd(-5.0 * (1.0 - w)))
    H.breathe(pose, t, T / 3.0, 0.8)
    pre = Solver(sk).solve(pose)
    o = p5.chest_pt(pre, sk, (0.075, 0.29, -0.10))
    o[2] = 0.5 * o[2] + 0.5 * 1.13 * k - 0.04 * k * w
    o = o + v3(0.0, -0.02 * k * w, 0.0)
    R = H.facing_frame(o, H.head_eye(pre, sk)) @ rxd(8.0 + 14.0 * w)
    H.prop_hand(sk, pose, "phone", R, o, pole=v3(0.8, -0.4, -0.5), twist=0.5)
    # the thumb: scroll swipes and taps (whole cycles per loop), resting while looking up
    hs = hand_shape("phone", 0.9)
    tap = max(0.0, _cyc(t, T, round(2.6 * T))) * (1.0 - w)
    swipe = (0.5 + 0.5 * _cyc(t, T, round(0.9 * T), 1.0)) * (1.0 - w)
    hs.thumb = (8.0 + 6.0 * tap + 4.0 * swipe, 16.0 + 22.0 * tap + 10.0 * swipe, 12.0 + 18.0 * tap)
    pose.hands["R"] = hs
    arm_fk(sk, pose, "L", add=37.0, swing=3.0 + 2.0 * _cyc(t, T, 1, 0.5), flex=16.0, twist=8.0)
    pose.hands["L"] = hand_shape("relaxed", 1.0)
    return pose


# =============================================================================================
# queue_idle_c: impatient
# =============================================================================================
def queue_idle_c(sk: Skeleton, f: int, N: int) -> Pose:
    """Impatient: arms crossed high, the weight shifting twice per loop; a big sigh (SIGH: inhale, shoulders up, then
    the slump), a look back over the left shoulder down the line (LOOK_BACK), a burst of right toe taps (TAPS), the right
    fingers drumming on the left arm."""
    t = f / FPS
    T = N / FPS
    u = f / N
    k = sk.scale
    pose = Pose()
    tp = _win(t, T, TAPS[0], TAPS[1], 0.12)
    toe = 13.0 * tp * max(0.0, math.sin(TAU * 4.0 * (t - TAPS[0]))) if TAPS[0] <= t <= TAPS[1] else 0.0
    _stance(sk, pose, u, 2, 0.9, amount=0.026, spread=0.06, tap=(toe,))
    # sigh: inhale (chest up, head back) to mid, then the exhale slump
    s0, s1 = SIGH
    mid = s0 + 0.43 * (s1 - s0)
    inhale = A.smooth(s0, mid, t) * (1.0 - A.smooth(mid, mid + 0.35, t))
    slump = A.smooth(mid, mid + 0.35, t) * (1.0 - A.smooth(s1 - 0.5, s1, t))
    add_rot(pose, "spine", rxd(2.5 * inhale - 3.0 * slump))
    add_rot(pose, "chest", rxd(4.0 * inhale - 5.0 * slump))
    pose.hip = pose.hip + v3(0.0, 0.0, (0.004 * inhale - 0.008 * slump) * k)
    back = _win(t, T, LOOK_BACK[0], LOOK_BACK[1], 0.35)
    add_rot(pose, "spine", rzd(8.0 * back))
    add_rot(pose, "chest", rzd(16.0 * back))
    lf = life.Life(QUEUE_GLANCES["queue_idle_c"], T)
    y, p, tl = life.glance(lf.keys, t, T)
    H.look(pose, yaw=y * (1.0 - back) + 52.0 * back, pitch=p - 8.0 * inhale + 10.0 * slump - 2.0 * back,
           tilt=tl + 6.0 * slump + 4.0 * back)
    H.breathe(pose, t, T / 4.0, 0.9)
    pre = Solver(sk).solve(pose)
    Wc = pre.W["chest"]
    for sfx, sx in A.SIDES:
        lift = 0.02 * k * inhale - 0.012 * k * slump
        p = p5.chest_pt(pre, sk, (-sx * 0.11, 0.18, 0.02 - (0.035 if sx > 0 else 0.0))) + v3(0.0, 0.0, lift)
        hand_on(sk, pose, sfx, p, Wc @ v3(-sx * 0.95, 0.25, 0.1), Wc @ v3(0.0, -1.0, 0.1),
                pole=Wc @ v3(sx * 0.5, -0.1, -1.0), along_share=0.5)
        hs = hand_shape("relaxed", 1.3)
        if sfx == "R":
            # the right fingers (on the left upper arm, under the left forearm) drum: index, middle, ring in turn
            for i, fn in enumerate(("index", "middle", "ring")):
                d = max(0.0, _cyc(t, T, round(3.0 * T), -1.1 * i)) * (1.0 - back)
                c = hs.curl[fn]
                hs.curl[fn] = (c[0] - 22.0 * d, c[1] - 10.0 * d, c[2])
        pose.hands[sfx] = hs
    return pose


# =============================================================================================
# counter_customer
# =============================================================================================
def counter_customer(sk: Skeleton, f: int, N: int) -> Pose:
    """At the teller window: leaning on the forearms on the ledge (LEDGE_Z, the counter face COUNTER_FACE ahead), the
    palms flat; the right hand slides a slip to the window (SLIDE, ``slip_push`` at its far point) and back, then two
    small open-hand gestures with the heel of the hand on the ledge (GESTURE) and a nod (NOD)."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    sway = _cyc(t, T, 1, 0.7)
    a0, a1, b0, b1 = SLIDE
    reach = A.smooth(a0, a1, t) * (1.0 - A.smooth(b0, b1, t))
    look_slip = _win(t, T, a0 - 0.2, b1 + 0.1, 0.4)
    pose.hip = v3(0.008 * k * sway, (-0.075 + 0.02 * reach) * k, (-0.045 - 0.006 * reach) * k)
    spine(pose, lean=15.0 + 4.0 * reach, chest_lean=10.0 + 2.0 * reach, twist=-3.0 * reach, hips=(6.0, 0.0, 0.0))
    add_rot(pose, "hips", ryd(1.2 * sway))
    for sfx, sx in A.SIDES:
        p5.plant_mtp(sk, pose, sfx, v3(sx * 0.05 * k, (0.03 if sfx == "L" else -0.02) * k, 0.0), -sx * 10.0, 0.0)
    nod = _win(t, T, NOD[0], NOD[1], 0.2)
    nod_v = math.sin(math.pi * min(1.0, max(0.0, (t - NOD[0]) / (NOD[1] - NOD[0])))) if NOD[0] <= t <= NOD[1] else 0.0
    g = _win(t, T, GESTURE[0], GESTURE[1], 0.3)
    talk = 2.0 * _cyc(t, T, 3, 0.3) + 1.5 * _cyc(t, T, 5, 1.2)
    H.look(pose, yaw=4.0 * _cyc(t, T, 1, 0.2) * (1.0 - look_slip) - 6.0 * look_slip + 2.0 * g,
           pitch=-6.0 + talk * (1.0 - look_slip) + 28.0 * look_slip + 13.0 * nod_v * nod, tilt=2.0 * g)
    H.breathe(pose, t, T / 3.0, 0.8)
    pl = (v3(REST_L[0] * k, REST_L[1] * k, LEDGE_Z * k), v3(0.45, 0.89, -0.05), v3(0.0, 0.0, -1.0))
    hand_on(sk, pose, "L", *pl, pole=v3(-0.9, -0.3, -0.5), along_share=0.5, palm_off=0.012)
    pose.hands["L"] = hand_shape("rest_flat", 0.8)
    # right: rest -> the slip pushed to the window -> rest; gestures: the hand turns about its heel, palm up-in
    rx = A.lerp(REST_R[0], PUSH_R[0], reach)
    ry = A.lerp(REST_R[1], PUSH_R[1], reach)
    gest = g * (0.5 + 0.5 * _cyc(t - GESTURE[0], (GESTURE[1] - GESTURE[0]), 2, -math.pi / 2))
    al = A.unit(v3(-0.35 + 0.15 * gest, 0.93, 0.05 + 0.35 * gest))
    pa = A.unit(v3(-0.55 * gest, 0.1 * gest, -1.0 + 0.6 * gest))
    pa = A.unit(pa - al * float(pa @ al))
    hand_on(sk, pose, "R", v3(rx * k, ry * k, LEDGE_Z * k), al, pa, pole=v3(0.9, -0.3, -0.5), along_share=0.5 - 0.25 * gest,
            palm_off=0.012)
    pose.hands["R"] = hand_shape("rest_flat", 0.8).blend(hand_shape("spread", 0.7), gest)
    _settle(sk, pose, LEDGE_Z, COUNTER_FACE, ("L", "R"))
    return pose


# =============================================================================================
# check_desk_write
# =============================================================================================
def check_desk_write(sk: Skeleton, f: int, N: int) -> Pose:
    """At a standing check desk (DESK_Z, near edge DESK_EDGE ahead): leaning in, the left palm flat on the slip, the
    right hand writing along LINE (letters as small loops, resting on its little-finger edge); once per loop a look
    up (LOOK_UP_W) while the hand goes back to the start of the line."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    w = _win(t, T, LOOK_UP_W[0], LOOK_UP_W[1], 0.35)
    sway = _cyc(t, T, 1, 0.3)
    pose.hip = v3(0.006 * k * sway, -0.05 * k, -0.03 * k)
    spine(pose, lean=13.0 - 3.0 * w, chest_lean=9.0 - 3.0 * w, twist=2.0, hips=(4.0, 0.0, 0.0))
    add_rot(pose, "hips", ryd(1.0 * sway))
    for sfx, sx in A.SIDES:
        p5.plant_mtp(sk, pose, sfx, v3(sx * 0.055 * k, (0.02 if sfx == "L" else -0.01) * k, 0.0), -sx * 10.0, 0.0)
    # the line: written left to right outside the look up, back to its start during it (continuous, closes)
    x0, x1, ly = LINE
    span = T - (LOOK_UP_W[1] - LOOK_UP_W[0])
    since = (t - LOOK_UP_W[1]) % T
    prog = min(1.0, since / span)
    x = x0 + (x1 - x0) * prog if since <= span else x1 + (x0 - x1) * A.smooth(0.0, 1.0, (since - span) / (T - span))
    write = 1.0 - w
    letters = v3(0.006 * _cyc(t, T, round(3.4 * T)), 0.005 * _cyc(t, T, round(5.0 * T), 0.6), 0.0) * write
    pen = v3(x * k, (ly - 0.015 * w) * k, DESK_Z * k) + letters * k
    H.look(pose, yaw=-4.0 * write + 3.0 * w + 4.0 * (x - x0) / (x1 - x0) * write,
           pitch=40.0 * write + 2.0 * w, tilt=3.0 * write)
    H.breathe(pose, t, T / 3.0, 0.7)
    sl = (v3(SLIP_L[0] * k, SLIP_L[1] * k, DESK_Z * k), v3(0.4, 0.92, -0.03), v3(0.0, 0.0, -1.0))
    hand_on(sk, pose, "L", *sl, pole=v3(-0.9, -0.3, -0.5), along_share=0.5, palm_off=0.012)
    pose.hands["L"] = hand_shape("rest_flat", 0.7)
    # the writing hand: on its little-finger edge, fingers forward-left, the palm facing down and in
    hand_on(sk, pose, "R", pen + v3(0.03 * k, -0.07 * k, 0.0), A.unit(v3(-0.45, 0.88, -0.12)),
            A.unit(v3(-0.62, -0.05, -0.78)), pole=v3(0.9, -0.3, -0.45), along_share=0.6, palm_off=0.015)
    hs = hand_shape("pinch", 1.0)
    hs.curl["index"] = (36.0, 38.0, 18.0)
    pose.hands["R"] = hs
    _settle(sk, pose, DESK_Z, DESK_EDGE, ("L", "R"))
    return pose


# =============================================================================================
# table hook
# =============================================================================================
BUILDERS = {"queue_idle": queue_idle, "queue_idle_b": queue_idle_b, "queue_idle_c": queue_idle_c,
            "counter_customer": counter_customer, "check_desk_write": check_desk_write}


def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N, loop, speed, ev = int(row["frames"]), bool(row["loop"]), float(row["speed"]), dict(row.get("events", {}))
        fn = BUILDERS[name]
        # reach_fix lowers the hips where a planted foot is out of reach; the hand goals are world points, so the
        # hands stay on their surfaces
        out[name] = Clip(name, N, loop, (lambda f, fn=fn, N=N: fn(sk, f, N)), speed, None, ev, reach_fix=True)
    return out


# =============================================================================================
# checks and SOURCE.txt notes
# =============================================================================================
#: the contact hands per surface clip: (plane z, {side: [(first frame, last frame), ...]} at 30 fps)
def contacts(table: dict) -> dict[str, tuple[float, dict]]:
    def fr(s: float) -> int:
        return round(s * FPS)

    out = {}
    if "counter_customer" in table:
        n = int(table["counter_customer"]["frames"])
        out["counter_customer"] = (LEDGE_Z, {"L": [(0, n)], "R": [(0, fr(GESTURE[0])), (fr(GESTURE[1]), n)]})
    if "check_desk_write" in table:
        n = int(table["check_desk_write"]["frames"])
        out["check_desk_write"] = (DESK_Z, {"L": [(0, n)], "R": [(0, n)]})
    return out


def _socket(sk: Skeleton, s, sfx: str) -> np.ndarray:
    _r, t_off = A.grip_offset(sk, sfx)
    hb = f"hand.{sfx}"
    return s.P[hb] + s.W[hb] @ sk.B[hb] @ t_off


def _surface(name: str) -> tuple[float, float] | None:
    """(plane z, the surface's near edge ahead of the root) of a surface clip."""
    if name == "counter_customer":
        return LEDGE_Z, COUNTER_FACE
    if name == "check_desk_write":
        return DESK_Z, DESK_EDGE
    return None


def measure(sk: Skeleton, name: str, baked, table: dict) -> dict:
    """Contact facts on the baked frames: the worst hand-skin gap to the plane over the contact frames (mm, + above),
    the deepest skin below the plane over the surface (mm, + = through it), the body's front below the top, the
    socket heights above the plane, the root drift."""
    probe = A.probe_for(sk)
    m = _masks(sk)
    k = sk.scale
    fr = baked.frames
    out: dict = {"root_mm": max(float(np.linalg.norm(s.P.get("root", np.zeros(3)) - fr[0].P.get("root", np.zeros(3))))
                                for s in fr) * 1000.0}
    surf = _surface(name)
    if surf is None:
        return out
    plane, edge = surf
    con = contacts(table).get(name, (plane, {}))[1]
    gap = 0.0
    sock: dict[str, list[float]] = {"L": [], "R": []}
    through = 0.0
    front = -1.0
    arm_gap = 1.0
    for i, s in enumerate(fr):
        V = probe.posed(s)
        for sfx, spans in con.items():
            if any(a <= i <= b for a, b in spans):
                g = float(V[m[sfx], 2].min()) - plane * k
                gap = g if abs(g) > abs(gap) else gap
                sock[sfx].append(float(_socket(sk, s, sfx)[2]) - plane * k)
        over = V[(V[:, 1] > edge * k) & (V[:, 2] > (plane - 0.12) * k)]
        if len(over):
            through = max(through, plane * k - float(over[:, 2].min()))
        below = V[V[:, 2] < (plane - 0.04) * k]
        front = max(front, float(below[:, 1].max()))
        for sfx in ("L", "R"):
            arm = V[m["arm" + sfx] & (V[:, 1] > edge * k)]
            if len(arm):
                arm_gap = min(arm_gap, float(arm[:, 2].min()) - plane * k)
    out.update({"hand_gap_mm": gap * 1000.0, "through_mm": through * 1000.0, "front": front, "arm_gap_mm": arm_gap * 1000.0,
                "socket": {sfx: (min(v), max(v), float(np.median(v))) for sfx, v in sock.items() if v}})
    return out


_MEASURED: dict[str, dict] = {}


def check_row(sk: Skeleton, table: dict, name: str, baked) -> str:
    r = measure(sk, name, baked, table)
    _MEASURED[name] = r
    txt = f" root_drift={r['root_mm']:.2f}mm"
    if "hand_gap_mm" in r:
        txt += (f" hand_gap={r['hand_gap_mm']:.1f}mm through={max(0.0, r['through_mm']):.1f}mm"
                f" forearm_gap={r['arm_gap_mm']:.1f}mm front={r['front']:.3f}m")
        for sfx, (lo, hi, _med) in sorted(r["socket"].items()):
            txt += f" socket_{sfx}={lo * 100:+.1f}..{hi * 100:+.1f}cm"
    return txt


def row_extra(name: str) -> str:
    for g, members in GROUPS.items():
        if name in members:
            return f" variant_of={g}"
    return ""


def _spans(spans: list) -> str:
    return ",".join(f"{a}-{b}" for a, b in spans)


def source_notes(sk: Skeleton, table: dict, keep: dict) -> dict[str, str]:
    k = sk.scale
    out: dict[str, str] = {}
    for g, members in GROUPS.items():
        out[f"variants.{g}"] = ", ".join(m for m in members if m in table)
    per = "/".join(str(int(table[m]["frames"])) for m in GROUPS["queue_idle"] if m in table)
    out["queue_variants"] = (
        "OF-D1 (bank customers in a queue): pick ONE member of variants.queue_idle per NPC with the SAME index rule as "
        "the surrender / civ_panic groups: index = hash(net_id or spawn id) % 3, stable for its life (queue_idle_b <-> "
        "cower_b <-> hands_up_b ... one personality); start each at a random offset (GameRng.stream(&\"anim_variants\"), "
        f"0..length) and/or speed_scale 0.92..1.08; periods {per} f, every layer closes per loop, so a queue never syncs. "
        "In place, facing forward (-Z) toward the front of the line; feet planted (the unloaded heel peels about its ball, "
        "queue_idle_c's toe taps pivot on the right heel). queue_idle = hands clasped, a wristwatch glance (watch event); "
        "queue_idle_b = the phone (phone_grip at HandR/Socket, the same hand_phone prop as phone_call / walk_text) at the "
        "chest, thumbing, one look up (look_up); queue_idle_c = impatient: arms crossed, a sigh (sigh, a breath sound), a "
        "look back down the line (look_back), toe taps. Deaths: the standing ones.")
    q = [keep[n] for n in GROUPS["queue_idle"] if n in keep]
    if q:
        probe = A.probe_for(sk)
        ys = [probe.posed(s)[:, 1] for b in q for s in b.frames[::6]]
        ahead = max(float(v.max()) for v in ys)
        behind = -min(float(v.min()) for v in ys)
        out["queue_spacing"] = (
            f"queue_idle*: the body (skin, all three variants) reaches {ahead:.2f} m ahead of the root and {behind:.2f} m "
            f"behind it: queue marks >= {ahead + behind + 0.35:.2f} m apart along the line (0.85-0.95 m reads as a bank "
            f"queue), the first mark >= {ahead + 0.25:.2f} m behind the rail / stanchion rope it faces")
    con = contacts(table)
    for name, (plane, sides) in con.items():
        r = _MEASURED.get(name)
        if r is None and name in keep:
            r = measure(sk, name, keep[name], table)
        if r is None:
            continue
        txt = f" plane={plane:.3f}"
        for sfx in ("L", "R"):
            if sfx in r["socket"]:
                txt += f" Hand{sfx}={r['socket'][sfx][2]:+.4f}@{_spans(sides[sfx])}"
        out[f"contact.{name}"] = (
            f"{txt} (Hand<side>=the HandL/HandR Socket origin height above the plane in m, median over the contact frames "
            f"@first-last; the palm skin lies on the plane within {abs(r['hand_gap_mm']):.1f} mm there)")
    cc, cw = _MEASURED.get("counter_customer"), _MEASURED.get("check_desk_write")
    ev_c = table.get("counter_customer", {}).get("events", {})
    ev_w = table.get("check_desk_write", {}).get("events", {})
    if cc is not None:
        out["counter_customer_placement"] = (
            f"counter_customer: a teller window. The root on the floor {COUNTER_FACE:.2f} m from the counter's customer face "
            f"(the mark at Godot z = +{COUNTER_FACE:.2f} from the face, facing it, -Z), the transaction ledge top "
            f"{LEDGE_Z:.2f} m high and >= 0.45 m deep (prop_counter_teller: top 1.05 m, its marble edge = the face: "
            f"mark origin 0.70 m from the segment centre). Forearms on the ledge, the palms flat on it: HandL at Godot "
            f"({REST_L[0] * k:.2f}, {LEDGE_Z:.2f}, {-REST_L[1] * k:.2f}), HandR rest ({REST_R[0] * k:.2f}, {LEDGE_Z:.2f}, "
            f"{-REST_R[1] * k:.2f}); the slip is pushed to ({PUSH_R[0] * k:.2f}, {LEDGE_Z:.2f}, {-PUSH_R[1] * k:.2f}) at "
            f"slip_push@{ev_c.get('slip_push', '?')} (the teller window / slot there: keep the ledge clear to "
            f"{PUSH_R[1] + 0.12:.2f} m ahead of the root, e.g. a glass screen's slot); nod@{ev_c.get('nod', '?')}. Below the "
            f"ledge the body stays behind Godot z = {-cc['front']:.2f}; nothing goes through the counter "
            f"(deepest skin {max(0.0, cc['through_mm']):.1f} mm). A paper slip prop is optional (under HandR, on the ledge)")
    if cw is not None:
        out["check_desk_placement"] = (
            f"check_desk_write: a standing check desk. The root on the floor, facing the desk (-Z), its near edge "
            f"{DESK_EDGE:.2f} m ahead (Godot z = {-DESK_EDGE:.2f}), top {DESK_Z:.2f} m high (NOTE prop_check_table's top is "
            f"1.05 m: lower it to 1.00 or ask D for a 1.05 variant). The left palm holds the slip flat at Godot "
            f"({SLIP_L[0] * k:.2f}, {DESK_Z:.2f}, {-SLIP_L[1] * k:.2f}); the right hand writes along x {LINE[0] * k:.2f}.."
            f"{LINE[1] * k:.2f} at z {-LINE[2] * k:.2f} (no pen prop: the pinch shows it; a pen, if added, rides the right "
            f"pinch); look_up@{ev_w.get('look_up', '?')}. Keep the desk top clear 0.30..0.50 m ahead of the root; the "
            f"body stays behind Godot z = {-cw['front']:.2f} below the top; nothing goes through the desk (deepest skin "
            f"{max(0.0, cw['through_mm']):.1f} mm)")
    out["bank_animdriver"] = (
        "OF-D1 AnimDriver mapping (ENV A): a customer at a `queue` mark plays queue_idle* (the variants.queue_idle member "
        "by net_id hash, a random start offset), at a `counter` mark counter_customer, at a `check_desk` mark "
        "check_desk_write; all loops, speed 0, the root on the mark facing its -Z. Leaving a mark: crossfade ~0.25 s to "
        "idle / walk. Panic: the civ_panic rules (panic_start from any of them, crossfade ~0.1 s)")
    return out
