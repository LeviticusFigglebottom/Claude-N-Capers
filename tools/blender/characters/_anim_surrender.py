"""D-116 surrender variety for the ``humanoid`` library: variants of the surrender family so a group of cops / guards
giving up together reads as individuals, not a synchronised troupe. Private helper of ``anim_humanoid.py`` (pure numpy).

Groups (``GROUPS``; the first member is the original, A picks one member per NPC):

* ``hands_up`` / ``hands_up_b`` / ``hands_up_c`` (loops, 60 / 82 / 98 f): the original (hands high beside the head,
  palms forward); ``_b`` hands lower and wider at ear height with bent elbows, head bowed, the weight on the right leg;
  ``_c`` arms high and narrow, nearly straight, the left hand a little higher, looking around. Feet on the floor at the
  root like the original; nothing chains into hands_up (A crossfades in and out), so frame 0 is free.
* ``surrender`` / ``surrender_b`` / ``surrender_c`` (one-shots, 48 / 54 / 42 f): from ``idle`` frame 0 (the
  original's start) to EXACTLY the original's last frame (on both knees, hands on the head: ``death_kneel`` starts there).
  ``_b`` = slow and reluctant: hands up at ear height, a look over the shoulder, the right foot forward and the LEFT knee
  down first, the hands stay raised until both knees are down, then onto the head. ``_c`` = quick and compliant: the
  hands go straight onto the head standing, a squat with both feet planted, both knees down together, head bowed.
* ``kneel_cuffed`` / ``kneel_cuffed_b`` / ``kneel_cuffed_c`` (loops, 90 / 104 / 118 f): frame 0 IS ``kneel_cuffed``
  frame 0 (``death_kneel_cuffed`` starts there); the variant layer fades in over the first ``ENV_RAMP`` of the loop
  and out over the last. ``_b`` slumps back onto the right heel (weight on the right knee), head down, slow sighs;
  ``_c`` stays upright and restless, looking over both shoulders, tugging at the cuffs.
* ``surrender_idle`` / ``surrender_idle_b`` / ``surrender_idle_c`` (NEW loops, 96 / 110 / 84 f): the held surrender.
  Frame 0 of each IS ``surrender``'s last frame (kneeling, hands on the head), so A plays one after any surrender
  variant without a crossfade (instead of freezing on the one-shot's last frame). ``surrender_idle`` = heavy breathing,
  small looks; ``_b`` hunched, head bowed, sitting back onto the left heel; ``_c`` restless, looking around, the weight
  swapping knees and the right hand re-gripping on the head.

Loop periods are deliberately unrelated (60/82/98, 90/104/118, 96/110/84 frames) and every periodic layer (breathing,
tremble, looks) completes whole cycles per loop, so a loop closes exactly and two variants never re-sync.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
from _anim import FPS, TAU, Clip, Keys, Pose, Skeleton, Solver, add_rot, hand_on, hand_shape, neutral, plant, rxd, \
    ryd, smooth, spine, stand, v3

#: variant groups: the original first (A picks a member per NPC, see SOURCE `surrender_variants`)
GROUPS = {
    "hands_up": ("hands_up", "hands_up_b", "hands_up_c"),
    "surrender": ("surrender", "surrender_b", "surrender_c"),
    "kneel_cuffed": ("kneel_cuffed", "kneel_cuffed_b", "kneel_cuffed_c"),
    "surrender_idle": ("surrender_idle", "surrender_idle_b", "surrender_idle_c"),
}
ORIGINALS = ("hands_up", "surrender", "kneel_cuffed")
#: the clips this module builds (each one entry in anim_humanoid.CLIPS)
NAMES = tuple(n for g in GROUPS.values() for n in g if n not in ORIGINALS)
#: clip -> (clip, frame) its frame 0 equals (-1 = that clip's last frame)
STARTS = {"surrender_b": ("surrender", 0), "surrender_c": ("surrender", 0), "kneel_cuffed_b": ("kneel_cuffed", 0),
          "kneel_cuffed_c": ("kneel_cuffed", 0), "surrender_idle": ("surrender", -1),
          "surrender_idle_b": ("surrender", -1), "surrender_idle_c": ("surrender", -1)}
#: one-shot -> (clip, frame) its last frame equals
ENDS = {"surrender_b": ("surrender", -1), "surrender_c": ("surrender", -1)}
#: share of a chained loop over which the variant layer fades in (and, mirrored, out before the seam)
ENV_RAMP = 0.16


def _env(u: float) -> float:
    """Variant layer weight over a chained loop: 0 at the seam (frame 0 = the original's frame 0), 1 in the middle."""
    return smooth(0.0, ENV_RAMP, u) * (1.0 - smooth(1.0 - ENV_RAMP, 1.0, u))


def _cyc(t: float, T: float, n: int, ph: float = 0.0) -> float:
    """sin with ``n`` whole cycles per loop of ``T`` s (closes exactly)."""
    return math.sin(TAU * n * t / T + ph)


def _breath(pose: Pose, b: float, amount: float) -> None:
    """``_anim_humanoid.breathe`` with the breath value ``b`` (-1..1) given (free period / phase)."""
    add_rot(pose, "chest", rxd(1.1 * amount * b))
    add_rot(pose, "neck", rxd(-0.6 * amount * b))
    for sfx, sx in A.SIDES:
        c = f"clavicle.{sfx}"
        if c in pose.D:
            pose.D[c] = pose.D[c] @ ryd(-sx * 0.8 * amount * b)


def _tremble(pose: Pose, t: float, T: float, amount: float) -> None:
    """``_anim_humanoid.tremble`` with each frequency rounded to whole cycles per loop (closes exactly)."""
    def hz(f: float) -> float:
        return max(1, round(f * T)) / T
    a = amount
    add_rot(pose, "chest", rxd(0.5 * a * math.sin(TAU * hz(7.0) * t)) @ ryd(0.35 * a * math.sin(TAU * hz(5.0) * t + 1.0)))
    add_rot(pose, "head", A.rzd(0.8 * a * math.sin(TAU * hz(6.0) * t + 0.4)))


def _look(pose: Pose, yaw: float = 0.0, pitch: float = 0.0, tilt: float = 0.0) -> None:
    import _anim_humanoid as H  # noqa: PLC0415

    H.look(pose, yaw=yaw, pitch=pitch, tilt=tilt)


# =============================================================================================
# hands_up
# =============================================================================================
#: per variant: stance, trunk, head, hands (chest-relative wrist goal, metres at 1.78 m), loop layers
HANDS_UP = {
    "hands_up_b": {
        "spread": 0.035, "stag_l": 0.07, "stag_r": -0.02, "yaw_l": 14, "yaw_r": 6, "hip": (0.030, -0.005, -0.028),
        "hip_roll": 3.5, "lean": 4.0, "chest_lean": 3.0, "side": -2.5, "neck": 10.0, "head": 12.0, "tilt": -4.0,
        "look": 5.0, "look_n": 1, "look_ph": 2.1, "pitch": 6.0,
        "hand": (0.36, 0.13, 0.30), "asym": -0.035, "along": (0.30, 0.25, 1.0), "pole": (1.0, 0.25, -0.75),
        "bob": 0.010, "breaths": 5, "breath_ph": 1.3, "breath_amt": 1.6, "trem": 0.7, "shape": ("spread", 0.55),
    },
    "hands_up_c": {
        "spread": 0.05, "stag_l": -0.02, "stag_r": 0.04, "yaw_l": 5, "yaw_r": 9, "hip": (-0.012, 0.0, -0.012),
        "hip_roll": -1.5, "lean": -2.5, "chest_lean": -3.5, "side": 1.0, "neck": -2.0, "head": -1.0, "tilt": 3.0,
        "look": 30.0, "look_n": 2, "look_ph": 0.7, "pitch": -3.0,
        "hand": (0.21, 0.04, 0.53), "asym": 0.04, "along": (0.04, 0.02, 1.0), "pole": (1.0, -0.35, -0.35),
        "bob": 0.005, "breaths": 6, "breath_ph": 2.6, "breath_amt": 1.2, "trem": 0.35, "shape": ("spread", 1.0),
    },
}


def hands_up_v(sk: Skeleton, f: int, N: int, v: dict, look_add: float = 0.0) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = neutral(sk)
    stand(sk, pose, spread=v["spread"], stagger_l=v["stag_l"], stagger_r=v["stag_r"], yaw_l=v["yaw_l"], yaw_r=v["yaw_r"])
    hx, hy, hz = v["hip"]
    sway = math.sin(TAU * t / T + v["look_ph"])
    pose.hip = v3(hx * k + 0.007 * k * sway, hy * k - 0.01 * k, hz * k)
    spine(pose, lean=v["lean"], side=v["side"], chest_lean=v["chest_lean"], neck=(v["neck"], 0, 0),
          head=(v["head"], v["tilt"], 0), hips=(0.0, v["hip_roll"], 0.0))
    _look(pose, yaw=v["look"] * _cyc(t, T, v["look_n"], v["look_ph"]) + look_add, pitch=v["pitch"])
    _tremble(pose, t, T, v["trem"])
    pre = Solver(sk).solve(pose)
    ax, ay, az = v["hand"]
    for sfx, sx in A.SIDES:
        jit = v["bob"] * k * _cyc(t, T, 2, sx + v["breath_ph"])
        p = A.bone_point(pre, sk, "chest", v3(sx * ax * k, ay * k, (az + sx * v["asym"] * 0.5) * k + jit))
        lx, ly, lz = v["along"]
        px, py, pz = v["pole"]
        hand_on(sk, pose, sfx, p, pre.W["chest"] @ v3(sx * lx, ly, lz), pre.W["chest"] @ v3(0.0, 1.0, 0.0),
                pole=pre.W["chest"] @ v3(sx * px, py, pz), along_share=0.45, clav=0.6)
        pose.hands[sfx] = hand_shape(*v["shape"])
    _breath(pose, _cyc(t, T, v["breaths"], v["breath_ph"]), v["breath_amt"])
    return pose


# =============================================================================================
# kneeling bases
# =============================================================================================
def _kneel(sk: Skeleton, pose: Pose, w: float, hip=(0.0, 0.0, 0.0)) -> None:
    """``kneel_base(sit=0)`` (knees down, hips off the heels) with the hips moved by ``w * hip`` (m at 1.78 m)."""
    import _anim_humanoid as H  # noqa: PLC0415

    H.kneel_base(sk, pose, sit=0.0)
    pose.hip = pose.hip + w * v3(*hip) * sk.scale


def _hands_on_head(sk: Skeleton, pose: Pose, dx: float = 0.0, dy: float = 0.0, dz: float = 0.0, r_off=(0.0, 0.0, 0.0),
                   shape: float = 0.6) -> None:
    """Both palms on the back of the head (``surrender``'s end grip), moved by (dx, dy, dz) / ``r_off`` (right)."""
    k = sk.scale
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        ox, oy, oz = (dx, dy, dz) if sfx == "L" else (dx + r_off[0], dy + r_off[1], dz + r_off[2])
        p = pre.P["head"] + pre.W["head"] @ v3(sx * (0.03 + ox) * k, (-0.06 + oy) * k, (0.15 + oz) * k)
        hand_on(sk, pose, sfx, p, pre.W["head"] @ v3(-sx * 0.85, 0.0, 0.4), pre.W["head"] @ v3(0.0, 0.0, -1.0),
                pole=v3(sx * 1.0, 0.0, 0.1), along_share=0.45)
        pose.hands[sfx] = hand_shape("relaxed", shape)


def kneel_hands(sk: Skeleton) -> Pose:
    """``_surrender``'s last key (kneeling upright, hands on the head), rebuilt (identical numbers)."""
    pose = Pose()
    _kneel(sk, pose, 0.0)
    spine(pose, lean=2.0, chest_lean=-2.0, neck=(6, 0, 0), head=(8, 0, 0))
    _hands_on_head(sk, pose)
    return pose


def _cuffed_hands(sk: Skeleton, pose: Pose, dx: float = 0.0, dz: float = 0.0) -> None:
    k = sk.scale
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        p = A.bone_point(pre, sk, "hips", v3(sx * 0.03 * k + dx * k, -0.16 * k, dz * k))
        hand_on(sk, pose, sfx, p, pre.W["hips"] @ v3(-sx * 0.7, -0.2, -0.65), pre.W["hips"] @ v3(-sx * 0.3, -0.9, 0.2),
                pole=pre.W["hips"] @ v3(sx * 0.6, -0.8, 0.0), along_share=0.3, clav=0.2)
        pose.hands[sfx] = hand_shape("fist", 0.7)


# =============================================================================================
# kneel_cuffed variants (frame 0 = kneel_cuffed frame 0)
# =============================================================================================
KNEEL_CUFFED = {
    "kneel_cuffed_b": {"hip": (0.045, -0.035, -0.07), "roll": 7.0, "lean": 9.0, "side": -4.0, "chest_lean": 7.0,
                       "neck": 10.0, "head": 16.0, "tilt": 5.0, "look": 6.0, "look_n": 1, "look_ph": 1.9,
                       "breaths": 3, "breath_ph": 0.0, "breath_amt": 1.6, "cuff_dz": -0.02, "fidget": 0.0},
    "kneel_cuffed_c": {"hip": (-0.012, 0.012, 0.012), "roll": -2.0, "lean": -3.0, "side": 1.0, "chest_lean": -3.0,
                       "neck": -3.0, "head": -4.0, "tilt": 0.0, "look": 38.0, "look_n": 2, "look_ph": 0.0,
                       "breaths": 5, "breath_ph": 0.0, "breath_amt": 1.1, "cuff_dz": 0.035, "fidget": 1.0},
}


def kneel_cuffed_v(sk: Skeleton, f: int, N: int, v: dict) -> Pose:
    t = f / FPS
    T = N / FPS
    u = f / N
    w = _env(u)
    pose = Pose()
    sway = math.sin(math.pi * u) ** 2                       # 0 at the seam: the weight settles in and back out
    _kneel(sk, pose, w * (0.6 + 0.4 * sway), v["hip"])
    spine(pose, lean=2.0 + w * v["lean"], side=w * v["side"], chest_lean=-2.0 + w * v["chest_lean"],
          chest_twist=w * 0.25 * v["look"] * _cyc(t, T, v["look_n"], v["look_ph"]),
          neck=(4 + w * v["neck"], 0, 0), head=(6 + w * v["head"], w * v["tilt"], 0), hips=(0.0, w * v["roll"], 0.0))
    yaw = (1.0 - w) * 18.0 * math.sin(TAU * t / T) + w * v["look"] * _cyc(t, T, v["look_n"], v["look_ph"])
    _look(pose, yaw=yaw, pitch=2.0)
    b = (1.0 - w) * math.sin(TAU * 3 * t / T) + w * _cyc(t, T, v["breaths"], v["breath_ph"])
    _breath(pose, b, 1.0 + w * (v["breath_amt"] - 1.0))
    # the hips' pose (kneel_base + hips) must be set before the hands are solved relative to them
    tug = w * v["fidget"] * max(0.0, _cyc(t, T, 3, -0.5)) ** 3
    _cuffed_hands(sk, pose, dx=0.0, dz=w * v["cuff_dz"] - 0.025 * tug)
    if v["fidget"]:
        add_rot(pose, "chest", ryd(3.0 * tug))
    return pose


# =============================================================================================
# surrender_idle (frame 0 = surrender's last frame)
# =============================================================================================
SURRENDER_IDLE = {
    "surrender_idle": {"hip": (0.0, 0.0, 0.0), "roll": 0.0, "lean": 1.0, "chest_lean": 1.0, "neck": 1.0, "head": 2.0,
                       "tilt": 0.0, "look": 10.0, "look_n": 1, "look_ph": 0.0, "breaths": 5, "breath_amt": 1.5,
                       "swap": 0.0, "regrip": 0.0, "env": False},
    "surrender_idle_b": {"hip": (-0.04, -0.04, -0.07), "roll": -6.0, "lean": 12.0, "chest_lean": 9.0, "neck": 12.0,
                         "head": 14.0, "tilt": -4.0, "look": 5.0, "look_n": 1, "look_ph": 2.4, "breaths": 4,
                         "breath_amt": 1.3, "swap": 0.0, "regrip": 0.0, "env": True},
    "surrender_idle_c": {"hip": (0.0, 0.015, 0.01), "roll": 0.0, "lean": -2.0, "chest_lean": -2.0, "neck": -2.0,
                         "head": -3.0, "tilt": 2.0, "look": 34.0, "look_n": 2, "look_ph": 0.9, "breaths": 4,
                         "breath_amt": 1.2, "swap": 1.0, "regrip": 1.0, "env": True},
}


def surrender_idle_v(sk: Skeleton, f: int, N: int, v: dict) -> Pose:
    t = f / FPS
    T = N / FPS
    u = f / N
    w = _env(u)
    k = sk.scale
    pose = Pose()
    _kneel(sk, pose, w, v["hip"])
    swap = v["swap"] * math.sin(TAU * t / T)                 # weight from knee to knee once per loop (0 at the seam)
    pose.hip = pose.hip + v3(0.03 * k * swap, 0.0, -0.006 * k * abs(swap))
    roll = w * v["roll"] + 4.0 * swap
    spine(pose, lean=2.0 + w * v["lean"], side=-2.0 * swap, chest_lean=-2.0 + w * v["chest_lean"],
          neck=(6 + w * v["neck"], 0, 0), head=(8 + w * v["head"], w * v["tilt"], 0), hips=(0.0, roll, 0.0))
    # the original's layers run from frame 0 (zero there); a variant's phase-shifted layers fade in with w
    lw = w if v["env"] else 1.0
    _look(pose, yaw=lw * v["look"] * _cyc(t, T, v["look_n"], v["look_ph"]), pitch=0.0)
    _breath(pose, _cyc(t, T, v["breaths"]), v["breath_amt"] * (0.6 + 0.4 * lw))
    # the right hand lifts off the head and re-grips once mid-loop
    g = v["regrip"] * w * A.pulse(max(0.0, u - 0.40) * T, 0.35, 0.7)
    _hands_on_head(sk, pose, dz=0.0, r_off=(0.03 * g, 0.05 * g, 0.06 * g), shape=0.6)
    return pose


# =============================================================================================
# surrender variants (idle frame 0 -> surrender's last frame)
# =============================================================================================
def _raise_hands(sk: Skeleton, pose: Pose) -> None:
    """Hands raised at ear height, palms forward, elbows down and out (``hands_up_b``'s hands) on ``pose``'s chest."""
    k = sk.scale
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        p = A.bone_point(pre, sk, "chest", v3(sx * 0.35 * k, 0.12 * k, 0.28 * k))
        hand_on(sk, pose, sfx, p, pre.W["chest"] @ v3(sx * 0.3, 0.25, 1.0), pre.W["chest"] @ v3(0.0, 1.0, 0.0),
                pole=pre.W["chest"] @ v3(sx * 1.0, 0.25, -0.75), along_share=0.45, clav=0.6)
        pose.hands[sfx] = hand_shape("spread", 0.55)


def _kneel_hands_up(sk: Skeleton, lean: float = 3.0, head: float = 4.0) -> Pose:
    """Both knees down, hands still raised at ear height."""
    pose = Pose()
    _kneel(sk, pose, 0.0)
    spine(pose, lean=lean, chest_lean=2.0, neck=(6, 0, 0), head=(head, 0, 0))
    _raise_hands(sk, pose)
    return pose


def _surrender_b(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """Slow, reluctant: hands up at ear height, a look back over the right shoulder, the right foot steps forward and
    the LEFT knee goes down first (the original lowers the right), hands raised until both knees are down."""
    import _anim_humanoid as H  # noqa: PLC0415

    k = sk.scale
    v = HANDS_UP["hands_up_b"]
    up = hands_up_v(sk, 0, 82, v)
    glance = hands_up_v(sk, 0, 82, v, look_add=-28.0)
    kup = _kneel_hands_up(sk)
    mid = Pose()
    mid.hip = v3(0.0, 0.02 * k, 0.72 * k - sk.head["hips"][2])
    plant(sk, mid, "R", (0.0, 0.20 * k, 0.0), yaw=-8.0)
    mid.legs["L"] = A.LegIK(ankle=v3(-0.12 * k, -0.36 * k, 0.14 * k), foot=rxd(-70.0), toe=A.rad(60.0),
                            pole=v3(-0.15, 1.0, -0.4))
    spine(mid, lean=8.0, chest_lean=3.0, neck=(8, 0, 0), head=(10, 0, 0))
    _raise_hands(sk, mid)
    end = kneel_hands(sk)
    s = N / 54.0
    return Keys(solver, [(0, H._stand_key(sk), "inout"), (round(11 * s), up, "inout"), (round(20 * s), glance, "inout"),
                         (round(27 * s), up.copy(), "inout"), (round(38 * s), mid, "inout"),
                         (round(46 * s), kup, "inout"), (N, end, "settle")])


def _surrender_c(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """Quick, compliant: hands straight onto the head while still standing, a squat on both planted feet, both knees
    down together, head bowed, then upright into the original's end pose."""
    import _anim_humanoid as H  # noqa: PLC0415

    k = sk.scale
    stand_hh = neutral(sk)
    stand(sk, stand_hh, spread=0.02, yaw_l=8, yaw_r=8)
    spine(stand_hh, lean=4.0, chest_lean=0.0, neck=(10, 0, 0), head=(12, 0, 0))
    _hands_on_head(sk, stand_hh, shape=0.8)
    squat = Pose()
    squat.hip = v3(0.0, -0.06 * k, -0.40 * k)
    stand(sk, squat, spread=0.06, stagger_l=0.02, stagger_r=0.0, yaw_l=14, yaw_r=14)
    for sfx in ("L", "R"):
        sx = A.side_x(sfx)
        plant(sk, squat, sfx, (sx * 0.06 * k, 0.0, 0.0), yaw=-sx * 14.0, pitch=-20.0, toe=20.0, pivot="ball",
              pole=v3(sx * 0.3, 1.0, 0.0))
    spine(squat, lean=18.0, chest_lean=8.0, neck=(12, 0, 0), head=(14, 0, 0), hips=(16, 0, 0))
    _hands_on_head(sk, squat, shape=0.8)
    down = Pose()
    _kneel(sk, down, 0.0)
    down.hip = down.hip + v3(0.0, 0.04 * k, -0.02 * k)
    spine(down, lean=14.0, chest_lean=8.0, neck=(14, 0, 0), head=(16, 0, 0), hips=(6, 0, 0))
    _hands_on_head(sk, down, shape=0.7)
    end = kneel_hands(sk)
    # the hands come up in front of the chest first (a straight path from hanging to beside the head passes next to the
    # shoulder, where the folded arm's elbow swings round: a one-frame 50 deg upper-arm snap)
    rise = H._stand_key(sk)
    spine(rise, lean=2.0, neck=(4, 0, 0), head=(4, 0, 0))
    for sfx, sx in A.SIDES:
        hand_on(sk, rise, sfx, v3(sx * 0.23 * k, 0.31 * k, 1.40 * k), A.unit(v3(0.0, 0.4, 1.0)), v3(0.0, 1.0, 0.0),
                pole=v3(sx * 0.8, -0.3, -0.5), along_share=0.5)
        rise.hands[sfx] = hand_shape("relaxed", 0.6)
    s = N / 42.0
    return Keys(solver, [(0, H._stand_key(sk), "inout"), (round(5 * s), rise, "inout"),
                         (round(9 * s), H.hands_up(sk, 0, 60), "inout"),
                         (round(13 * s), stand_hh, "inout"),
                         (round(19 * s), squat, "inout"), (round(29 * s), down, "heavy"), (N, end, "settle")])


# =============================================================================================
# table hook
# =============================================================================================
#: Clip.floor per clip (surrender variants: from the frame both knees are down; kneels: every frame)
FLOOR = {"surrender_b": -9, "surrender_c": -13, "kneel_cuffed_b": 0, "kneel_cuffed_c": 0, "surrender_idle": 0,
         "surrender_idle_b": 0, "surrender_idle_c": 0}


def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N, loop, speed, ev = int(row["frames"]), bool(row["loop"]), float(row["speed"]), dict(row.get("events", {}))
        if name in HANDS_UP:
            fn = (lambda f, v=HANDS_UP[name], N=N: hands_up_v(sk, f, N, v))
        elif name in KNEEL_CUFFED:
            fn = (lambda f, v=KNEEL_CUFFED[name], N=N: kneel_cuffed_v(sk, f, N, v))
        elif name in SURRENDER_IDLE:
            fn = (lambda f, v=SURRENDER_IDLE[name], N=N: surrender_idle_v(sk, f, N, v))
        elif name == "surrender_b":
            fn = _surrender_b(sk, solver, N)
        else:
            fn = _surrender_c(sk, solver, N)
        out[name] = Clip(name, N, loop, fn, speed, None, ev, reach_fix=False)
        if name in FLOOR:
            out[name].floor = FLOOR[name]
        if name.startswith("surrender"):
            out[name].no_sink = True
    return out


# =============================================================================================
# checks and SOURCE.txt notes
# =============================================================================================
KEEP = NAMES + ORIGINALS + ("idle",)


def _ang(a, b) -> float:
    """Worst bone rotation difference (deg) between two solved frames (pose-bone locals)."""
    worst = 0.0
    for bn, q in a.local.items():
        d = abs(float(np.dot(q, b.local[bn])))
        worst = max(worst, 2.0 * math.degrees(math.acos(min(1.0, d))))
    return worst


def _src_frame(keep: dict, name: str, f: int):
    b = keep.get(name)
    return None if b is None else b.frames[f]


def check_row(name: str, baked, keep: dict) -> str:
    from _anim_d304 import pose_err  # noqa: PLC0415

    fr = baked.frames
    txt = ""
    if name in STARTS:
        src, f = STARTS[name]
        s = _src_frame(keep, src, f)
        if s is not None:
            txt += f" start_err={pose_err(fr[0], s):.2f}mm"
    if name in ENDS:
        src, f = ENDS[name]
        s = _src_frame(keep, src, f)
        if s is not None:
            txt += f" end_err={pose_err(fr[-1], s):.2f}mm"
    group = next(g for g, members in GROUPS.items() if name in members)
    orig = keep.get(GROUPS[group][0])
    if orig is not None and name != GROUPS[group][0]:
        n = min(len(fr), len(orig.frames))
        txt += f" max_diff_vs_{GROUPS[group][0]}={max(_ang(fr[i], orig.frames[i]) for i in range(n)):.1f}deg"
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
    out["surrender_variants"] = (
        "D-116: pick ONE member of each variants.<group> per NPC, stable for its life: index = hash(net_id or spawn "
        "id) % group size (the same index across groups keeps a character's personality: hands_up_b -> surrender_b -> "
        "surrender_idle_b -> kneel_cuffed_b). Loops (hands_up*, kneel_cuffed*, surrender_idle*): start each NPC at a "
        "random offset (GameRng, 0..length) and/or speed_scale 0.92..1.08; the periods differ (60/82/98, 90/104/118, "
        "96/110/84 f) and every layer closes per loop, so they never re-sync. Chains: every surrender* starts on idle "
        "frame 0 and ends EXACTLY on surrender's last frame (death_kneel starts there for all three); surrender_idle* "
        "frame 0 IS that frame: after any surrender* one-shot, play a surrender_idle* loop without a crossfade instead "
        "of holding the last frame (death by pose: surrender_idle* -> death_kneel, crossfade ~0.15 s mid-loop). "
        "kneel_cuffed_b/_c frame 0 IS kneel_cuffed frame 0 (death_kneel_cuffed; the variant layer fades in / out over "
        f"the first / last {ENV_RAMP:.0%} of the loop); hands_up* frame 0 differs (crossfade in / out as for "
        "hands_up). "
        "No events in the family (as the originals). Wherever A lists an original (AnimTweak.hard_hat_lift_clips, "
        "death_by_pose, anim_driver clip sets), list its variants too.")
    rows = []
    for name in NAMES:
        b = keep.get(name)
        if b is not None:
            rows.append(f"{name}:{check_row(name, b, keep)}")
    if rows:
        out["surrender_variant_checks"] = "; ".join(rows)
    return out
