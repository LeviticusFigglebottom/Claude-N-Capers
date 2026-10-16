"""D-116 follow-up (third person, crew bots / teammates): akimbo firing set, downed (bleed-out) actions and the cuffed
crew state. Private helper of ``anim_humanoid.py`` (pure numpy).

Akimbo (a single pistol at ``HandR/Socket`` AND at ``HandL/Socket``, the mirrored grip convention of ``hold_akimbo``):

* ``aim_akimbo`` (90 f loop): both arms out, the guns side by side at the sight line, toed in a little and canted
  outward, the two hands swaying out of phase.
* ``fire_akimbo`` / ``fire_akimbo_l`` (9 f, ``shot`` @0): the right / left gun kicks; A alternates them per shot
  (right first, PD2). Frame 0 and the last frame = ``aim_akimbo`` frame 0.
* ``reload_akimbo`` (60 f; ``mag_out`` @8, ``mag_in`` @32, ``done`` @46): both guns come in and roll inward (the
  magazines drop), go down to the hips with the grips over the belt pouches, are pushed down onto fresh magazines
  and come back up to the aim.

Downed (``downed``: sitting on the floor, leaning back on the left hand, the secondary pistol one-handed in the right):

* ``downed_fire`` (9 f, ``shot`` @0): the pistol kicks from ``downed`` frame 0 (PD2: a downed heister keeps shooting).
* ``downed_reload`` (45 f; ``mag_out`` @6, ``mag_in`` @28, ``done`` @34): sits up off the left hand, the pistol
  tipped in towards the chest, the left hand takes a magazine from the belt and seats it, then leans back again.
* ``downed_getup`` (40 f, ``up`` @34): revived: forward onto the right knee, the left hand pushing off the floor, up
  to the pistol low ready (``hold_pistol`` frame 0; A crossfades into the current weapon's hold).
* ``downed_arrested`` (40 f, ``disarm`` @6): police arrest of a downed heister (pd2_fidelity L2.12): the pistol
  is taken (A hides the weapon at ``disarm``), hands up, onto one knee, standing with the wrists behind the back,
  ending EXACTLY on ``crew_cuffed`` frame 0.

Cuffed crew (PD2: a cuffed heister stands, wrists cuffed behind the back, until uncuffed or self-freed):

* ``crew_cuffed`` (120 f loop): standing, wrists together behind the back, a weight shift, looks around, a tug at
  the cuffs.
* ``crew_cuffed_enter`` (18 f): standing (``idle`` frame 0) -> ``crew_cuffed`` frame 0 (cuffed by a guard).
* ``crew_cuffed_free`` (24 f, ``free`` @8): from ``crew_cuffed`` frame 0, a strain, the wrists snap apart, the arms
  come forward, ending on ``idle_alert`` frame 0.
"""

from __future__ import annotations

import math

import _anim as A
import _anim_holds as holds
import _anim_humanoid as H
from _anim import FPS, TAU, Clip, Keys, Pose, Skeleton, Solver, hand_shape, pulse, rxd, rzd, v3

AKIMBO = ("aim_akimbo", "fire_akimbo", "fire_akimbo_l", "reload_akimbo")
DOWNED = ("downed_fire", "downed_reload", "downed_getup", "downed_arrested")
CUFFED = ("crew_cuffed", "crew_cuffed_enter", "crew_cuffed_free")
#: D-116 round 228: the mask-up and the grenade throw as teammates see them
ACTIONS = ("mask_on", "throw_grenade")
NAMES = AKIMBO + DOWNED + CUFFED + ACTIONS
KEEP = NAMES
#: the akimbo aim: the right gun's grip (m at 1.78 m; the left mirrors it), toe-in yaw and outward cant (deg)
AKIMBO_AIM = {"grip": (0.105, 0.56, 1.53), "toe_in": 3.0, "cant": 8.0}
#: the downed loop the downed_* clips start from
DOWNED_FRAMES = 90
#: the crew_cuffed loop
CUFFED_FRAMES = 120


# ---------------------------------------------------------------------------------------------------------------------
# akimbo
# ---------------------------------------------------------------------------------------------------------------------
def akimbo_frame(sk: Skeleton, t: float, sway: float, phase: float = 0.0, recoil: float = 0.0) -> tuple:
    """The right gun's aim frame (the left gun is ``holds._mirror`` of the frame built with its own phase)."""
    k = sk.scale
    gx, gy, gz = AKIMBO_AIM["grip"]
    o = v3(gx * k + 0.003 * k * sway * math.sin(TAU * t / 3.0 + phase), gy * k,
           gz * k + 0.004 * k * sway * math.sin(TAU * t / 1.5 + phase))
    R, o = A.weapon_frame(o, yaw=AKIMBO_AIM["toe_in"] + 0.6 * sway * math.sin(TAU * t / 3.0 + 0.7 + phase),
                          pitch=0.5 * sway * math.sin(TAU * t / 1.5 + 1.2 + phase), roll=AKIMBO_AIM["cant"])
    o = o + R @ v3(0.0, -0.03 * k * recoil, 0.012 * k * recoil)
    return R @ rxd(9.0 * recoil), o


def akimbo_hold(sk: Skeleton, pose: Pose, wf_r: tuple, wf_l_unmirrored: tuple, shape: str = "trigger") -> None:
    A.hold_weapon(sk, pose, wf_r, pole=v3(0.55, -0.15, -0.8), twist=0.6)
    A.hold_weapon(sk, pose, holds._mirror(wf_l_unmirrored), pole=v3(-0.55, -0.15, -0.8), sfx="L",  # noqa: SLF001
                  twist=0.6)
    pose.hands["R"] = hand_shape(shape)
    pose.hands["L"] = hand_shape(shape)


def akimbo_pose(sk: Skeleton, t: float, sway: float = 1.0, rec_r: float = 0.0, rec_l: float = 0.0) -> Pose:
    pose = Pose()
    H.aim_body(sk, pose, False)
    A.spine(pose, lean=6, twist=0, chest_lean=6, neck=(2, 0, 0), head=(-4, 0, 0), hips=(1, 0, 0))
    A.add_rot(pose, "chest", rxd(0.8 * (rec_r + rec_l)))
    akimbo_hold(sk, pose, akimbo_frame(sk, t, sway, 0.0, rec_r), akimbo_frame(sk, t, sway, 2.1, rec_l))
    H.breathe(pose, t, 1.5, 0.6 * sway)
    return pose


def _fire_akimbo(sk: Skeleton, N: int, left: bool):
    def fn(f: int) -> Pose:
        rec = pulse(f / FPS, 1.0 / FPS, (N - 1) / FPS)
        return akimbo_pose(sk, 0.0, 0.0, 0.0 if left else rec, rec if left else 0.0)
    return fn


def _reload_akimbo(sk: Skeleton, solver: Solver, N: int) -> Keys:
    k = sk.scale
    aim = akimbo_pose(sk, 0.0, 0.0)

    def at(o: tuple, pitch: float, roll: float, yaw: float, lean: float, shape: str = "grip") -> Pose:
        p = Pose()
        H.aim_body(sk, p, False)
        A.spine(p, lean=lean, chest_lean=0.6 * lean, neck=(8, 0, 0), head=(10 + 0.5 * lean, 0, 0), hips=(1, 0, 0))
        wf = A.weapon_frame(v3(o[0] * k, o[1] * k, o[2] * k), yaw=yaw, pitch=pitch, roll=roll)
        akimbo_hold(sk, p, wf, wf, shape)
        return p
    tip = at((0.12, 0.40, 1.32), 28.0, -38.0, 10.0, 8.0)                 # rolled in: the magazines fall out
    hips = at((0.21, 0.13, 0.98), -4.0, -6.0, 4.0, 14.0)                 # grips over the belt pouches
    seat = at((0.21, 0.13, 0.94), -4.0, -6.0, 4.0, 16.0)                 # pushed down onto the fresh magazines
    up = at((0.11, 0.42, 1.36), 16.0, 0.0, 6.0, 8.0, "trigger")
    return Keys(solver, [(0, aim, "inout"), (8, tip, "inout"), (18, hips, "inout"), (26, seat, "in"),
                         (32, seat, "inout"), (44, up, "inout"), (N, akimbo_pose(sk, 0.0, 0.0), "settle")])


# ---------------------------------------------------------------------------------------------------------------------
# downed
# ---------------------------------------------------------------------------------------------------------------------
def _floored(sk: Skeleton, solver: Solver, pose: Pose) -> Pose:
    """``pose`` resting on the floor (lowest skinned vertex at z = 0), as the bake rests ``downed``."""
    probe = A.probe_for(sk)
    for _it in range(3):
        low = probe.lowest(solver.solve(pose))
        if abs(low) < 2e-4:
            break
        A.lift(pose, -low)
    return pose


def _downed0(sk: Skeleton) -> Pose:
    return H.downed(sk, 0, DOWNED_FRAMES)


def _downed_fire(sk: Skeleton, N: int):
    def fn(f: int) -> Pose:
        return H.downed_pose(sk, 0.0, DOWNED_FRAMES / FPS, recoil=pulse(f / FPS, 1.0 / FPS, (N - 1) / FPS))
    return fn


def _downed_reload(sk: Skeleton, solver: Solver, N: int) -> Keys:
    k = sk.scale
    T = DOWNED_FRAMES / FPS

    def sit(lmode: str, shape: str, up: float = 1.0) -> Pose:
        def left(pre, wf):
            if lmode == "pouch":
                hp = A.bone_point(pre, sk, "hips", v3(-0.13 * k, 0.04 * k, 0.06 * k))
                return hp, v3(0.1, 0.3, -0.95), v3(0.95, 0.0, 0.2)
            off = H.PISTOL["magwell"] + v3(-0.004, -0.008, -0.10 if lmode == "mag" else -0.035)
            return A.wf_point(wf, off), wf[0] @ v3(0.25, 0.5, 0.85), wf[0] @ v3(0.9, -0.2, -0.3)
        return H.downed_pose(sk, 0.0, T, sit_up=up, gun=(-0.04 * up, -0.16 * up, -0.06 * up, 24.0 * up, 22.0 * up),
                             left=left, left_shape=shape)
    keys = [(0, _downed0(sk), "inout"), (6, sit("pouch", "relaxed"), "inout"), (13, sit("pouch", "pinch"), "inout"),
            (22, sit("mag", "pinch"), "inout"), (28, sit("in", "flat"), "snap"), (34, sit("in", "flat"), "inout"),
            (39, sit("pouch", "relaxed", 0.5), "inout"), (N, _downed0(sk), "settle")]   # back down past the belt
    return Keys(solver, keys)


def _one_knee(sk: Skeleton, pose: Pose, rise: float = 0.0) -> None:
    """On the right knee, the left foot planted forward (``rise`` 0..1 lifts the hips towards standing)."""
    k = sk.scale
    hips_rest = sk.head["hips"]
    pose.hip = v3(0.0, -0.02 * k, (0.56 + 0.20 * rise) * k - hips_rest[2])
    pose.legs["R"] = A.LegIK(ankle=v3(0.12 * k, -0.36 * k, 0.085 * k), foot=rxd(-115.0), toe=A.rad(30.0),
                             pole=v3(0.1, 1.0, -0.6))
    pose.legs["L"] = A.LegIK(ankle=v3(-0.13 * k, 0.32 * k, 0.085 * k), foot=rzd(4.0), toe=0.0,
                             pole=v3(-0.1, 1.0, 0.3))


def _cuffed_arms(sk: Skeleton, pose: Pose, apart: float = 0.0) -> None:
    """Wrists together behind the back at the small of the back (``apart`` m pulls them apart: a tug)."""
    k = sk.scale
    pre = Solver(sk).solve(pose)
    for sfx, sx in A.SIDES:
        p = A.bone_point(pre, sk, "hips", v3(sx * (0.03 + apart) * k, -0.17 * k, 0.06 * k))
        H.hand_on(sk, pose, sfx, p, pre.W["hips"] @ v3(-sx * 0.7, -0.2, -0.65), pre.W["hips"] @ v3(-sx * 0.3, -0.9, 0.2),
                  pole=pre.W["hips"] @ v3(sx * 0.6, -0.8, 0.0), along_share=0.3, clav=0.2)
        pose.hands[sfx] = hand_shape("fist", 0.7)


def crew_cuffed(sk: Skeleton, f: int, N: int) -> Pose:
    t = f / FPS
    T = N / FPS
    k = sk.scale
    pose = Pose()
    w = math.sin(TAU * t / T)
    pose.hip = v3(0.012 * k * w, 0.0, -0.02 * k - 0.004 * k * abs(w))
    A.stand(sk, pose, spread=0.04, stagger_l=0.03, stagger_r=-0.04, yaw_l=8, yaw_r=10)
    tug = A.smooth(0.0, 1.0, math.sin(TAU * 2 * t / T + 1.0)) ** 3      # two short tugs per loop
    A.spine(pose, lean=3.0 + 3.0 * tug, side=-1.8 * w, chest_lean=-3.0 + 2.0 * tug, neck=(4, 0, 0), head=(4, 0, 0))
    H.look(pose, yaw=24.0 * math.sin(TAU * t / T + 0.4), pitch=2.0 + 4.0 * tug)
    H.breathe(pose, t, T / 5.0, 1.0)
    _cuffed_arms(sk, pose, 0.012 * tug)
    return pose


def _stand_ready(sk: Skeleton) -> Pose:
    return holds._hold(sk, "pistol", 0, holds.KINDS["pistol"], False)   # noqa: SLF001


def _chest_low(sk: Skeleton, pose: Pose, pitch: float) -> tuple:
    """A pistol low ready relative to the chest (kneeling / rising bodies, where the standing frame is out of place)."""
    k = sk.scale
    pre = Solver(sk).solve(pose)
    o = A.bone_point(pre, sk, "chest", v3(0.07 * k, 0.34 * k, -0.12 * k))
    return A.weapon_frame(o, yaw=6.0, pitch=pitch)


def _downed_getup(sk: Skeleton, solver: Solver, N: int) -> Keys:
    k = sk.scale
    start = _floored(sk, solver, _downed0(sk))
    push = H.downed_pose(sk, 0.0, DOWNED_FRAMES / FPS, sit_up=1.0, gun=(0.0, -0.10, -0.06, -20.0, 0.0))
    _floored(sk, solver, push)
    kneel = Pose()
    _one_knee(sk, kneel)
    A.spine(kneel, lean=16, chest_lean=6, neck=(-6, 0, 0), head=(-4, 0, 0))
    pre = Solver(sk).solve(kneel)
    H.hand_on(sk, kneel, "L", A.bone_point(pre, sk, "thigh.L", v3(0.0, 0.30 * k, 0.04 * k)), v3(0.0, 0.6, -0.8),
              v3(0.0, 0.2, -1.0), pole=v3(-0.7, -0.3, -0.6), along_share=0.5)
    kneel.hands["L"] = hand_shape("flat", 0.6)
    H.hold_pistol(sk, kneel, _chest_low(sk, kneel, -30.0), one_hand=True)
    rise = Pose()
    _one_knee(sk, rise, 0.8)
    rise.legs["R"] = A.LegIK(ankle=v3(0.12 * k, -0.18 * k, 0.10 * k), foot=rxd(-40.0), toe=A.rad(20.0),
                             pole=v3(0.1, 1.0, 0.0))
    A.spine(rise, lean=22, chest_lean=6, neck=(-8, 0, 0), head=(-6, 0, 0))
    H.hold_pistol(sk, rise, _chest_low(sk, rise, -34.0))
    return Keys(solver, [(0, start, "inout"), (10, push, "inout"), (20, kneel, "inout"), (30, rise, "inout"),
                         (N, _stand_ready(sk), "settle")])


def _downed_arrested(sk: Skeleton, solver: Solver, N: int) -> Keys:
    start = _floored(sk, solver, _downed0(sk))
    give = H.downed_pose(sk, 0.0, DOWNED_FRAMES / FPS, sit_up=0.6, gun=(0.0, 0.0, 0.04, 30.0, 0.0))   # the pistol raised
    _floored(sk, solver, give)
    give.hands["R"] = hand_shape("flat", 0.7)                                                   # handed over
    k = sk.scale

    def belt(pre, wf):
        return A.bone_point(pre, sk, "hips", v3(-0.13 * k, 0.06 * k, 0.12 * k)), v3(0.1, 0.3, -0.95), v3(0.95, 0.0, 0.2)
    lift = H.downed_pose(sk, 0.0, DOWNED_FRAMES / FPS, sit_up=1.0, gun=(0.0, 0.0, 0.10, 50.0, 0.0), left=belt,
                         left_shape="relaxed")
    _floored(sk, solver, lift)
    lift.hands["R"] = hand_shape("flat", 0.7)
    hands_up = Pose()
    _one_knee(sk, hands_up)
    A.spine(hands_up, lean=6, neck=(4, 0, 0), head=(8, 0, 0))
    for sfx, sx in A.SIDES:
        A.arm_fk(sk, hands_up, sfx, add=20.0, swing=60.0, flex=95.0, twist=-20.0)
        hands_up.hands[sfx] = hand_shape("flat", 0.6)
    kneel_c = Pose()
    _one_knee(sk, kneel_c, 0.2)
    A.spine(kneel_c, lean=10, neck=(6, 0, 0), head=(10, 0, 0))
    _cuffed_arms(sk, kneel_c)
    return Keys(solver, [(0, start, "inout"), (6, give, "inout"), (11, lift, "inout"), (19, hands_up, "inout"),
                         (29, kneel_c, "inout"),
                         (N, crew_cuffed(sk, 0, CUFFED_FRAMES), "settle")])



def _cuffed_enter(sk: Skeleton, solver: Solver, N: int) -> Keys:
    mid = H._stand_key(sk)                                              # noqa: SLF001
    A.spine(mid, lean=4, chest_lean=-2, head=(6, 0, -10))
    for sfx, _sx in A.SIDES:
        A.arm_fk(sk, mid, sfx, add=24.0, swing=-30.0, flex=40.0, twist=10.0)
    return Keys(solver, [(0, H._stand_key(sk), "inout"), (8, mid, "inout"),                     # noqa: SLF001
                         (N, crew_cuffed(sk, 0, CUFFED_FRAMES), "settle")])


def _cuffed_free(sk: Skeleton, solver: Solver, N: int) -> Keys:
    strain = crew_cuffed(sk, 0, CUFFED_FRAMES)
    A.spine(strain, lean=10, chest_lean=6, neck=(10, 0, 0), head=(12, 0, 0))
    _cuffed_arms(sk, strain, 0.03)
    snap = H._stand_key(sk)                                             # noqa: SLF001
    A.spine(snap, lean=-2, chest_lean=-4, head=(-4, 0, 0))
    for sfx, _sx in A.SIDES:
        A.arm_fk(sk, snap, sfx, add=40.0, swing=-18.0, flex=30.0, twist=8.0)
        snap.hands[sfx] = hand_shape("relaxed")
    return Keys(solver, [(0, crew_cuffed(sk, 0, CUFFED_FRAMES), "inout"), (6, strain, "in"), (9, snap, "out"),
                         (N, H.idle_alert(sk, 0, 120), "settle")])


# ---------------------------------------------------------------------------------------------------------------------
# mask-up and grenade throw
# ---------------------------------------------------------------------------------------------------------------------
def _hands_at_face(sk: Skeleton, pose: Pose, y: float, z: float, half: float, back: float = 0.0,
                   shape: str = "grip") -> None:
    """Both hands at the sides of a mask held ``y`` m in front of the face, ``z`` m up (at 1.78 m), ``half`` m apart
    from the centre; ``back`` tips the fingers back over the head (the strap)."""
    k = sk.scale
    for sfx, sx in A.SIDES:
        H.hand_on(sk, pose, sfx, v3(sx * half * k, y * k, z * k), H.unit(v3(0.0, -back, 1.0)), v3(-sx, -0.25, 0.0),
                  pole=v3(sx * 0.8, 0.1, -0.6), along_share=0.5)
        pose.hands[sfx] = hand_shape(shape, 0.7)


def _mask_on(sk: Skeleton, solver: Solver, N: int) -> Keys:
    """Hands to the face, mask on (``mask_on``: A shows the mask at Head/Socket), strap pulled back, idle_alert."""
    look_at = H._stand_key(sk)                                          # noqa: SLF001
    A.spine(look_at, lean=4, chest_lean=2, neck=(10, 0, 0), head=(12, 0, 0))
    _hands_at_face(sk, look_at, 0.30, 1.40, 0.10)
    lift = H._stand_key(sk)                                             # noqa: SLF001
    A.spine(lift, lean=2, neck=(4, 0, 0), head=(4, 0, 0))
    _hands_at_face(sk, lift, 0.20, 1.58, 0.09)
    press = H._stand_key(sk)                                            # noqa: SLF001
    A.spine(press, lean=1, neck=(0, 0, 0), head=(-2, 0, 0))
    _hands_at_face(sk, press, 0.10, 1.63, 0.085, shape="flat")
    strap = H._stand_key(sk)                                            # noqa: SLF001
    A.spine(strap, lean=0, neck=(-4, 0, 0), head=(-6, 0, 0))
    _hands_at_face(sk, strap, 0.0, 1.70, 0.09, back=0.4, shape="pinch")
    down = H._stand_key(sk)                                             # noqa: SLF001
    A.spine(down, lean=2, head=(2, 0, 0))
    k = sk.scale
    for sfx, sx in A.SIDES:                                             # forward and down in front of the chest
        H.hand_on(sk, down, sfx, v3(sx * 0.16 * k, 0.24 * k, 1.28 * k), H.unit(v3(0.0, 1.0, -0.3)), v3(-sx, 0.0, 0.0),
                  pole=v3(sx * 0.8, -0.2, -0.6), along_share=0.5)
        down.hands[sfx] = hand_shape("relaxed")
    return Keys(solver, [(0, H._stand_key(sk), "inout"), (8, look_at, "inout"), (14, lift, "inout"),       # noqa: SLF001
                         (18, press, "snap"), (23, strap, "inout"), (27, down, "inout"),
                         (N, H.idle_alert(sk, 0, 120), "settle")])


def _throw_grenade(sk: Skeleton, solver: Solver, N: int, release: int) -> Keys:
    """Overhand with the LEFT arm (the weapon stays low in the right hand, H.low_carry): wound up behind the left
    shoulder, released forward-high at ``release``, follow-through across the body."""
    k = sk.scale

    def left(pose: Pose, p, along, shape: str) -> None:
        H.hand_on(sk, pose, "L", v3(p[0] * k, p[1] * k, p[2] * k), H.unit(v3(*along)), v3(0.9, 0.0, 0.3),
                  pole=v3(-0.8, -0.4, -0.4), along_share=0.6)
        pose.hands["L"] = hand_shape(shape, 0.9)
        H.low_carry(sk, pose)
    start = H._stand_key(sk)                                            # noqa: SLF001
    left(start, (-0.16, 0.18, 1.12), (0.1, 0.5, 0.85), "fist")
    wind = H._stand_key(sk)                                             # noqa: SLF001
    H.stand(sk, wind, spread=0.05, stagger_l=-0.10, stagger_r=0.12, yaw_l=24, yaw_r=10)
    A.spine(wind, lean=-6, twist=26, chest_lean=-4, chest_twist=18, neck=(-4, 0, -14), head=(-6, 0, -18), hips=(0, 0, 10))
    left(wind, (-0.24, -0.20, 1.62), (0.0, -0.4, 0.9), "fist")
    rel = H._stand_key(sk)                                              # noqa: SLF001
    rel.hip = rel.hip + v3(0.0, 0.07 * k, -0.02 * k)
    A.spine(rel, lean=10, twist=-10, chest_lean=6, chest_twist=-8, neck=(-6, 0, 6), head=(-8, 0, 8), hips=(0, 0, -8))
    left(rel, (-0.10, 0.48, 1.62), (0.0, 0.9, 0.4), "relaxed")
    follow = H._stand_key(sk)                                           # noqa: SLF001
    A.spine(follow, lean=14, twist=-14, chest_lean=6, chest_twist=-8, head=(4, 0, 6))
    left(follow, (0.08, 0.36, 1.06), (0.3, 0.6, -0.75), "relaxed")
    end = H._stand_key(sk)                                              # noqa: SLF001
    H.low_carry(sk, end)
    return Keys(solver, [(0, start, "inout"), (release - 5, wind, "inout"), (release, rel, "in"),
                         (release + 5, follow, "out"), (N, end, "inout")])


# ---------------------------------------------------------------------------------------------------------------------
# table hooks
# ---------------------------------------------------------------------------------------------------------------------
def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N = int(row["frames"])
        ev = dict(row.get("events", {}))
        loop = bool(row["loop"])
        if name == "aim_akimbo":
            fn = (lambda f, N=N: akimbo_pose(sk, f / FPS))
            out[name] = Clip(name, N, loop, fn, 0.0, None, ev)
        elif name in ("fire_akimbo", "fire_akimbo_l"):
            out[name] = Clip(name, N, loop, _fire_akimbo(sk, N, name.endswith("_l")), 0.0, None, ev)
        elif name == "reload_akimbo":
            out[name] = Clip(name, N, loop, _reload_akimbo(sk, solver, N), 0.0, None, ev, reach_fix=False)
        elif name == "downed_fire":
            out[name] = Clip(name, N, loop, _downed_fire(sk, N), 0.0, None, ev, reach_fix=False, floor=0)
        elif name == "downed_reload":
            out[name] = Clip(name, N, loop, _downed_reload(sk, solver, N), 0.0, None, ev, reach_fix=False, floor=0)
        elif name == "crew_cuffed":
            out[name] = Clip(name, N, loop, (lambda f, N=N: crew_cuffed(sk, f, N)), 0.0, None, ev)
        else:
            maker = {"downed_getup": _downed_getup, "downed_arrested": _downed_arrested,
                     "crew_cuffed_enter": _cuffed_enter, "crew_cuffed_free": _cuffed_free, "mask_on": _mask_on,
                     "throw_grenade": lambda s_, so, n, ev=ev: _throw_grenade(s_, so, n, int(ev["release"]))}[name]
            out[name] = Clip(name, N, loop, maker(sk, solver, N), 0.0, None, ev, reach_fix=False,
                             no_sink=name.startswith("downed_"))
    return out


def check_row(name: str, baked) -> str:
    return ""


def source_notes() -> dict:
    return {"crew_states": (
        "D-116 third-person crew states. Akimbo: aim_akimbo while aiming an akimbo pair (a single pistol visual at "
        "HandR/Socket and at HandL/Socket); fire_akimbo / fire_akimbo_l alternate per shot, right first (each starts "
        "and ends on aim_akimbo f0); reload_akimbo (mag_out, mag_in, done like reload_pistol). Downed: downed_fire per "
        "shot from the floor, downed_reload, both from downed f0 back to downed f0; downed_getup on revive (ends on "
        "hold_pistol f0: crossfade 0.2 s into the current weapon's hold); downed_arrested when police cuff a downed "
        "heister (hide the weapon at disarm; ends on crew_cuffed f0). Cuffed: crew_cuffed loop while cuffed (standing, "
        "wrists behind the back), crew_cuffed_enter when cuffed standing (stealth guard cuffs), crew_cuffed_free on "
        "uncuff or self-free (ends on idle_alert f0). Custody: no body on the map, no clip"),
        "crew_actions": (
            "D-116 round 228, as teammates see them. mask_on (30 f, mask_on@18): from idle f0, both hands bring the "
            "mask up to the face and press it on (show the mask at Head/Socket at mask_on), pull the strap back, end "
            "on idle_alert f0. Play it while the mask-up hold runs, scaled to Tweak.crew().mask_up_time_s (1.0 s = "
            "the clip's length), so crew_masked lands at its end. throw_grenade (24 f, release@11, done@24, the FP "
            "throwable_throw timing): an overhand with the LEFT arm, the weapon kept low in the right hand. Hide the "
            "held grenade and spawn the projectile at release (HandL/Socket)")}
