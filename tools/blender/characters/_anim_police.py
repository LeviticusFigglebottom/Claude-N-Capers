"""D-116 organic pass, item 2: police combat movement (the crew uses the same clips).

* Per-class third-person reloads beside reload_rifle / reload_pistol / reload_akimbo: ``reload_smg`` (a short box
  magazine), ``reload_shotgun`` (four shells into the tube, then the pump), ``reload_lmg`` (top cover up, box out, a
  fresh box in, the belt laid on the feed tray, cover down) and ``reload_sniper`` (magazine, then the bolt cycled).
  Every hand target is a point of the class reference model (``_arms_sets`` markers, the Blender weapon space the
  third-person WeaponVisual uses: the grip at HandR/Socket). Each starts and ends on aim_rifle frame 0.
* Cover: ``cover_peek_l_<fam>`` / ``cover_peek_r_<fam>`` (standing at a corner: wait at the low ready, lean out
  aimed, scan, back in) and ``cover_low_<fam>`` (crouched behind low cover: rise to aim over it, scan, duck), fam =
  rifle / pistol; 150 f loops, feet planted.
* ``stagger_<fam>``: a stagger-strength hit (36 f): thrown back with the weapon knocked off line, a stumble step back,
  the catch and a step forward, back on aim_<fam> frame 0 (in place: the feet end where they started).

Pure numpy; private helper of ``_anim_humanoid.clips``.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
import _anim_holds as holds
import _anim_humanoid as H
import _arms_sets as sets
from _anim import FPS, TAU, Clip, Keys, Pose, Skeleton, Solver, hand_shape, rxd, ryd, rzd, v3

RELOADS = ("reload_smg", "reload_shotgun", "reload_lmg", "reload_sniper")
COVER = tuple(f"cover_{side}_{fam}" for side in ("peek_l", "peek_r", "low") for fam in ("rifle", "pistol"))
STAGGER = ("stagger_rifle", "stagger_pistol")
NAMES = RELOADS + COVER + STAGGER
#: contract rows (anim_humanoid.CLIPS)
ROWS = {
    "reload_smg": {"frames": 54, "loop": False, "speed": 0.0, "priority": 2,
                   "events": {"mag_out": 10, "mag_in": 36, "done": 44}},
    "reload_shotgun": {"frames": 84, "loop": False, "speed": 0.0, "priority": 2,
                       "events": {"shell": 14, "done": 74}},
    "reload_lmg": {"frames": 120, "loop": False, "speed": 0.0, "priority": 2,
                   "events": {"cover_open": 16, "mag_out": 34, "mag_in": 72, "cover_close": 92, "done": 106}},
    "reload_sniper": {"frames": 78, "loop": False, "speed": 0.0, "priority": 2,
                      "events": {"mag_out": 12, "mag_in": 42, "bolt": 56, "done": 66}},
    **{name: {"frames": 150, "loop": True, "speed": 0.0, "priority": 2} for name in COVER},
    **{name: {"frames": 36, "loop": False, "speed": 0.0, "priority": 2, "events": {"impact": 2}} for name in STAGGER},
}
#: shotgun: the frames each shell goes in (the first is the `shell` event), one every 12 f
SHELLS = (14, 26, 38, 50)
#: class reference markers (Blender weapon space, m)
M = {"smg": sets.SMG.markers, "shotgun": sets.SHOTGUN.markers, "lmg": sets.LMG.markers, "sniper": sets.SNIPER.markers}


# =============================================================================================
# reloads
# =============================================================================================
class _Rel:
    """Key vocabulary of one class reload: the aim stance, the weapon tilted to the magwell, the left hand's moves."""

    def __init__(self, sk: Skeleton, cls: str, o=(0.09, 0.24, 1.30), yaw: float = 10.0, pitch: float = 12.0,
                 roll: float = 28.0) -> None:
        self.sk, self.cls, self.k = sk, cls, sk.scale
        self.m = M[cls]
        self.base = (o, yaw, pitch, roll)

    def aim(self) -> Pose:
        return H.gun_pose(self.sk, True, 0.0, sway=0.0)

    def tilt(self, dz: float = 0.0, dyaw: float = 0.0, dpitch: float = 0.0, droll: float = 0.0,
             lean: float = 7.0) -> tuple[Pose, tuple]:
        k = self.k
        o, yaw, pitch, roll = self.base
        p = H.gun_pose(self.sk, True, 0.0, sway=0.0)
        A.spine(p, lean=lean, twist=-14, chest_lean=6, chest_twist=-10, neck=(10, 0, 4), head=(14, 6, 8),
                hips=(2, 0, -6))
        wf = A.weapon_frame(v3(o[0] * k, o[1] * k, (o[2] + dz) * k), yaw=yaw + dyaw, pitch=pitch + dpitch,
                            roll=roll + droll)
        A.hold_weapon(self.sk, p, wf, pole=v3(0.8, -0.2, -0.6))
        p.hands["R"] = hand_shape("trigger")
        return p, wf

    def on(self, p: Pose, wf: tuple, point, along, palm, shape: str, share: float = 0.6,
           pole=(-0.6, -0.4, -0.7)) -> Pose:
        """The left hand on a weapon-space point (along / palm in weapon space too)."""
        R = wf[0]
        A.hand_on(self.sk, p, "L", A.wf_point(wf, point), R @ v3(*along), R @ v3(*palm), pole=v3(*pole),
                  along_share=share)
        p.hands["L"] = hand_shape(shape)
        return p

    def pouch(self, p: Pose, shape: str, at=(-0.10, 0.12, 1.04)) -> Pose:
        k = self.k
        A.hand_on(self.sk, p, "L", v3(at[0] * k, at[1] * k, at[2] * k), v3(0.1, 0.25, -0.95), v3(0.95, 0.0, 0.1),
                  pole=v3(-0.7, -0.3, -0.6), along_share=0.7)
        p.hands["L"] = hand_shape(shape)
        return p

    def support(self, p: Pose, wf: tuple, cup: bool = True) -> Pose:
        H.rifle_support(self.sk, p, wf, at=self.m["left_ik"], cup=cup)
        return p


def reload_smg(sk: Skeleton, solver: Solver, N: int) -> Keys:
    r = _Rel(sk, "smg", o=(0.09, 0.24, 1.31), pitch=10.0, roll=26.0)
    mw = r.m["magwell"]

    def mag(dz: float, off, shape: str = "grip") -> Pose:
        p, wf = r.tilt(dz=dz)
        return r.on(p, wf, mw + v3(*off), (0.3, 0.5, 0.8), (1.0, 0.0, -0.1), shape)
    p_sup, wf_sup = r.tilt(droll=-16.0, dpitch=-6.0)
    return Keys(solver, [
        (0, r.aim(), "inout"),
        (7, mag(0.0, (-0.03, 0.0, -0.10)), "inout"),
        (12, mag(-0.02, (-0.03, 0.0, -0.17)), "out"),             # mag_out@10: pulled clear
        (20, r.pouch(r.tilt()[0], "relaxed"), "inout"),
        (25, r.pouch(r.tilt()[0], "grip"), "inout"),
        (33, mag(0.0, (-0.03, 0.0, -0.15)), "inout"),
        (37, mag(0.01, (-0.01, 0.0, -0.12), "flat"), "snap"),     # mag_in@36
        (44, r.support(p_sup, wf_sup), "inout"),
        (N, r.aim(), "settle"),
    ])


def reload_sniper(sk: Skeleton, solver: Solver, N: int) -> Keys:
    r = _Rel(sk, "sniper", o=(0.09, 0.26, 1.29), pitch=10.0, roll=24.0)
    mw = r.m["magwell"]
    k = sk.scale

    def mag(dz: float, off, shape: str = "grip") -> Pose:
        p, wf = r.tilt(dz=dz)
        return r.on(p, wf, mw + v3(*off), (0.3, 0.5, 0.8), (1.0, 0.0, -0.1), shape)

    def bolt(back: float) -> Pose:
        """The weapon back up near the shoulder, the right hand stays on the grip (the third-person gun rides
        HandR/Socket, so a right hand on the knob would drag the whole rifle), the left hand reaches over the receiver
        and works the bolt knob (the over-the-top left-hand bolt of precision shooters)."""
        p = H.gun_pose(sk, True, 0.0, sway=0.0)
        A.spine(p, lean=6, twist=-12, chest_lean=5, chest_twist=-10, neck=(6, 0, 4), head=(10, 6, 8), hips=(2, 0, -6))
        wf = A.weapon_frame(v3(0.10 * k, 0.27 * k, 1.34 * k), yaw=6.0, pitch=4.0, roll=-8.0)
        A.hold_weapon(sk, p, wf, pole=v3(0.8, -0.2, -0.6))
        p.hands["R"] = hand_shape("trigger")
        knob = r.m["knob"] + v3(-0.004, -back, 0.012)
        return r.on(p, wf, knob, (0.85, 0.25, 0.45), (0.5, 0.0, -0.85), "pinch", share=0.8, pole=(-0.5, -0.5, -0.7))
    p_sup, wf_sup = r.tilt(droll=-14.0, dpitch=-6.0)
    return Keys(solver, [
        (0, r.aim(), "inout"),
        (8, mag(0.0, (-0.03, 0.0, -0.08)), "inout"),
        (14, mag(-0.02, (-0.03, 0.0, -0.15)), "out"),             # mag_out@12
        (22, r.pouch(r.tilt()[0], "relaxed"), "inout"),
        (28, r.pouch(r.tilt()[0], "grip"), "inout"),
        (38, mag(0.0, (-0.03, 0.0, -0.13)), "inout"),
        (43, mag(0.01, (-0.01, 0.0, -0.10), "flat"), "snap"),     # mag_in@42
        (50, bolt(0.0), "inout"),
        (55, bolt(0.085), "out"),                                  # bolt@56: pulled back
        (60, bolt(0.0), "snap"),                                   # and home
        (66, r.support(p_sup, wf_sup), "inout"),                  # done@66
        (N, r.aim(), "settle"),
    ])


def reload_shotgun(sk: Skeleton, solver: Solver, N: int) -> Keys:
    # the gun rolled to the right so the loading port under the receiver faces the left hand
    r = _Rel(sk, "shotgun", o=(0.08, 0.25, 1.27), yaw=12.0, pitch=10.0, roll=-30.0)
    port = r.m["magwell"] + v3(0.0, 0.0, -0.035)

    def load(push: float, shape: str) -> Pose:
        p, wf = r.tilt()
        return r.on(p, wf, port + v3(0.0, 0.02 * push, 0.0), (0.0, 1.0, 0.25), (0.0, 0.1, 1.0), shape, share=0.45,
                    pole=(-0.5, -0.5, -0.7))

    def pump(back: float) -> Pose:
        p, wf = r.tilt(droll=26.0, dpitch=-4.0)
        H.rifle_support(sk, p, wf, at=r.m["left_ik"] + v3(0.0, -back, 0.0))
        return p
    keys: list = [(0, r.aim(), "inout")]
    for s in SHELLS:
        keys += [(s - 6, r.pouch(r.tilt()[0], "pinch", at=(-0.11, 0.13, 1.02)), "inout"),
                 (s - 1, load(0.0, "pinch"), "inout"),
                 (s, load(1.0, "flat"), "snap")]
    keys += [(58, pump(0.0), "inout"), (64, pump(0.085), "out"), (68, pump(0.0), "snap"),
             (74, pump(0.0), "inout"), (N, r.aim(), "settle")]
    return Keys(solver, keys)


def reload_lmg(sk: Skeleton, solver: Solver, N: int) -> Keys:
    # heavy: the gun held lower and level, canted a little toward the left hand
    r = _Rel(sk, "lmg", o=(0.10, 0.27, 1.20), yaw=12.0, pitch=4.0, roll=12.0)
    m = r.m
    hinge, rear = m["cover_hinge"], m["cover_rear"]

    def cover(up: float, shape: str = "grip") -> Pose:
        """The left hand under the cover's rear edge, the cover swung ``up`` deg about its hinge."""
        p, wf = r.tilt(lean=9.0)
        tip = hinge + rxd(up) @ (rear - hinge)
        # the fingers hook the cover's rear edge from the left side (palm toward the receiver: no wrist flip from the
        # fore-end grip)
        return r.on(p, wf, tip + v3(-0.03, 0.0, -0.005), (0.15, 0.35, 0.92), (1.0, 0.0, 0.2), shape, share=0.6,
                    pole=(-0.6, -0.4, -0.7))

    def box(off, shape: str = "grip") -> Pose:
        p, wf = r.tilt(lean=9.0)
        return r.on(p, wf, m["magwell"] + v3(*off), (0.2, 0.6, 0.75), (1.0, 0.0, 0.0), shape, share=0.55,
                    pole=(-0.6, -0.4, -0.7))

    def feed(shape: str) -> Pose:
        p, wf = r.tilt(lean=9.0)
        return r.on(p, wf, m["feed"] + v3(-0.025, 0.0, 0.005), (0.3, 0.6, 0.75), (1.0, 0.0, -0.2), shape, share=0.55,
                    pole=(-0.6, -0.4, -0.7))
    p_sup, wf_sup = r.tilt(droll=-10.0)
    return Keys(solver, [
        (0, r.aim(), "inout"),
        (5, r.support(*r.tilt(lean=8.0), cup=False), "inout"),   # the hand over the fore-end's side, then up
        (11, cover(0.0), "inout"),
        (17, cover(-75.0), "out"),                                 # cover_open@16
        (26, box((-0.07, 0.0, -0.06)), "inout"),
        (34, box((-0.10, 0.0, -0.17)), "out"),                     # mag_out@34: the box pulled down and away
        (44, r.pouch(r.tilt(lean=9.0)[0], "relaxed", at=(-0.16, 0.16, 0.96)), "inout"),
        (54, r.pouch(r.tilt(lean=9.0)[0], "grip", at=(-0.16, 0.16, 0.96)), "inout"),
        (66, box((-0.10, 0.0, -0.14)), "inout"),
        (72, box((-0.07, 0.0, -0.07), "flat"), "snap"),            # mag_in@72
        (80, feed("pinch"), "inout"),
        (86, cover(-75.0, "flat"), "inout"),
        (92, cover(0.0, "flat"), "snap"),                          # cover_close@92
        (97, r.support(*r.tilt(lean=8.0), cup=False), "inout"),
        (102, r.support(p_sup, wf_sup), "inout"),
        (106, r.support(*r.tilt(droll=-14.0)), "inout"),           # done@106
        (N, r.aim(), "settle"),
    ])


# =============================================================================================
# cover peeks
# =============================================================================================
#: lean out (deg of side bend at the spine + chest), hip shift out (m at 1.78 m), the aimed scan (deg)
PEEK = {"lean": 14.0, "hip": 0.10, "scan": 9.0}
#: the cycle (s of the 5 s loop): in cover, leaning out, aimed (scanning), back in
PEEK_T = (1.3, 1.75, 3.6, 4.05)


def _low_ready(sk: Skeleton, pose: Pose, fam: str) -> None:
    k = sk.scale
    if fam == "rifle":
        R, o = holds.rifle_low_frame(sk, 0.0)
        A.hold_weapon(sk, pose, (R, o), pole=v3(0.75, -0.2, -0.6), twist=0.6)
        H.rifle_support(sk, pose, (R, o))
    else:
        R, o = holds.pistol_low_frame(sk, 0.0)
        H.hold_pistol(sk, pose, (R, o))
    pose.hands["R"] = hand_shape("grip", 0.9)
    del k


def _aimed(sk: Skeleton, pose: Pose, fam: str, wf: tuple) -> None:
    if fam == "rifle":
        H.hold_rifle(sk, pose, wf)
    else:
        H.hold_pistol(sk, pose, wf)


def _turned(wf: tuple, pivot, R: np.ndarray, shift) -> tuple:
    Rw, o = wf
    return R @ Rw, pivot + R @ (o - pivot) + shift


def cover_peek(sk: Skeleton, fam: str, side: str, f: int, N: int) -> Pose:
    """Standing at a corner (cover on the ``side`` the body leans out of: l = out to the left)."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    s = -1.0 if side == "l" else 1.0                       # lean direction in x
    a, b, c, d = (x * T / 5.0 for x in PEEK_T)
    out = A.smooth(a, b, t) * (1.0 - A.smooth(c, d, t))
    pose = Pose()
    H.aim_body(sk, pose, fam == "rifle")
    pose.hip = pose.hip + v3(s * PEEK["hip"] * k * out, 0.0, -0.01 * k * out)
    lean = PEEK["lean"] * out
    A.add_rot(pose, "spine", ryd(s * 0.55 * lean))
    A.add_rot(pose, "chest", ryd(s * 0.45 * lean))
    A.add_rot(pose, "neck", ryd(-s * 0.35 * lean))
    A.add_rot(pose, "head", ryd(-s * 0.3 * lean))
    # in cover: a glance at the edge now and then; out: a scan across the field
    scan = PEEK["scan"] * math.sin(TAU * (t - b) / max(c - b, 0.1)) * A.smooth(b, b + 0.3, t) * (1.0 - A.smooth(c - 0.3, c, t))
    H.look(pose, yaw=-s * 6.0 * (1.0 - out) + scan * out, pitch=0.0)
    pre = Solver(sk).solve(pose)
    chest = pre.P["chest"]
    R_lean = ryd(s * lean)
    aim_wf = (H.rifle_aim_frame if fam == "rifle" else H.pistol_aim_frame)(sk, t, 0.4)
    aimed = _turned(aim_wf, chest, rzd(scan * out) @ R_lean, v3(s * PEEK["hip"] * k * out, 0.0, 0.0))
    if out > 0.5:
        _aimed(sk, pose, fam, aimed)
    else:
        _low_ready(sk, pose, fam)
    H.breathe(pose, t, T / 4.0, 1.0)
    return pose


def cover_low(sk: Skeleton, fam: str, f: int, N: int) -> Pose:
    """Crouched behind low cover: rise to aim over it, scan, duck back down."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    a, b, c, d = (x * T / 5.0 for x in PEEK_T)
    up = A.smooth(a, b, t) * (1.0 - A.smooth(c, d, t))
    pose = Pose()
    H.crouch_base(sk, pose)
    # rising: the hips come up out of the crouch (the knees still bent), the trunk upright to aim over the cover
    pose.hip = pose.hip + v3(0.0, 0.03 * k * up, 0.22 * k * up)
    A.add_rot(pose, "spine", rxd(10.0 * up))
    A.add_rot(pose, "chest", rxd(6.0 * up))
    scan = PEEK["scan"] * math.sin(TAU * (t - b) / max(c - b, 0.1)) * A.smooth(b, b + 0.3, t) * (1.0 - A.smooth(c - 0.3, c, t))
    H.look(pose, yaw=scan * up, pitch=-2.0 * (1.0 - up))
    pre = Solver(sk).solve(pose)
    stand = Pose()
    H.aim_body(sk, stand, fam == "rifle")
    ref = Solver(sk).solve(stand)
    aim_wf = (H.rifle_aim_frame if fam == "rifle" else H.pistol_aim_frame)(sk, t, 0.4)
    # the standing aim frame carried by the chest's height (the cover's top is under the muzzle)
    shift = pre.P["chest"] - ref.P["chest"]
    aimed = _turned(aim_wf, pre.P["chest"], rzd(scan * up), shift)
    if up > 0.5:
        _aimed(sk, pose, fam, aimed)
    else:
        low = (holds.rifle_low_frame if fam == "rifle" else holds.pistol_low_frame)(sk, 0.0)
        low = (low[0], low[1] + shift)
        if fam == "rifle":
            A.hold_weapon(sk, pose, low, pole=v3(0.75, -0.2, -0.6), twist=0.6)
            H.rifle_support(sk, pose, low)
        else:
            H.hold_pistol(sk, pose, low)
        pose.hands["R"] = hand_shape("grip", 0.9)
    H.breathe(pose, t, T / 4.0, 1.0)
    return pose


def _peek_clip(sk: Skeleton, solver: Solver, name: str, N: int) -> Clip:
    """The aimed / low-ready switch above is a hard cut: bake the loop as keys at the cut's edges instead."""
    fam = name.rsplit("_", 1)[1]
    if name.startswith("cover_low"):
        def fn(f: int) -> Pose:
            return cover_low(sk, fam, f, N)
    else:
        side = name.split("_")[2]

        def fn(f: int) -> Pose:
            return cover_peek(sk, fam, side, f, N)
    T = N / FPS
    a, b, c, d = (round(x * T / 5.0 * FPS) for x in PEEK_T)
    # low ready -> aimed is a hand-off between two holds: key the edges (the solver blends them) and the scan between
    frames = [0, a, b] + list(range(b + 6, c - 2, 6)) + [c, d, N]
    keys = [(f, fn(0 if f == N else f), "inout") for f in frames]
    return Clip(name, N, True, Keys(solver, keys), 0.0, None, {}, reach_fix=False)


# =============================================================================================
# stagger
# =============================================================================================
def stagger(sk: Skeleton, solver: Solver, fam: str, N: int) -> Keys:
    k = sk.scale
    rifle = fam == "rifle"
    aim = H.gun_pose(sk, rifle, 0.0, sway=0.0)

    def knocked(lean: float, pitch: float, yaw: float, hip_y: float, step_r: float, step_l: float, support: bool,
                head: float) -> Pose:
        p = Pose()
        H.aim_body(sk, p, rifle)
        p.hip = p.hip + v3(0.0, hip_y * k, -0.02 * k * abs(hip_y) / 0.1)
        A.stand(sk, p, spread=0.04, stagger_l=0.10 * rifle + 0.06 * (not rifle) + step_l,
                stagger_r=-0.10 * rifle - 0.05 * (not rifle) + step_r, yaw_l=8, yaw_r=28 if rifle else 14)
        A.spine(p, lean=lean, twist=-12 if rifle else -3, chest_lean=0.8 * lean, chest_twist=-10 if rifle else 0,
                neck=(0.5 * head, 0, 4), head=(head, 4, 6), hips=(0.3 * lean, 0, -6 if rifle else -3))
        R, o = (H.rifle_aim_frame if rifle else H.pistol_aim_frame)(sk, 0.0, 0.0)
        pivot = o + R @ (H.RIFLE["butt"] * k if rifle else v3(0.0, 0.0, 0.0))
        Rk = rzd(yaw) @ rxd(pitch)
        wf = (Rk @ R, pivot + Rk @ (o - pivot) + v3(0.0, -0.06 * k * (pitch / 40.0), 0.0))
        if rifle:
            A.hold_weapon(sk, p, wf, pole=v3(0.8, -0.2, -0.6))
            p.hands["R"] = hand_shape("trigger")
            if support:
                H.rifle_support(sk, p, wf)
            else:                                           # the support hand flung off the fore-end
                A.arm_fk(sk, p, "L", add=40.0, swing=30.0, flex=50.0, out=20.0)
                p.hands["L"] = hand_shape("spread", 0.6)
        else:
            H.hold_pistol(sk, p, wf, one_hand=not support)
            if not support:
                A.arm_fk(sk, p, "L", add=32.0, swing=30.0, flex=55.0, out=12.0)
                p.hands["L"] = hand_shape("spread", 0.6)
        return p
    return Keys(solver, [
        (0, aim, "inout"),
        (3, knocked(-14.0, 30.0, 10.0, -0.05, 0.0, 0.0, False, -18.0), "inout"),      # impact@2: the peak a frame on
        (9, knocked(-10.0, 22.0, 6.0, -0.12, -0.24, 0.0, False, -10.0), "out"),       # stumble: the right foot back
        (16, knocked(4.0, 10.0, 3.0, -0.14, -0.24, -0.12, False, 0.0), "inout"),     # the left foot back too, caught
        (23, knocked(8.0, 4.0, 0.0, -0.06, -0.08, -0.12, True, 6.0), "inout"),       # weight forward, hands back on
        (29, knocked(5.0, 0.0, 0.0, -0.01, 0.0, 0.0, True, 4.0), "inout"),           # the feet home
        (N, H.gun_pose(sk, rifle, 0.0, sway=0.0), "settle"),
    ])


# =============================================================================================
# registry hooks
# =============================================================================================
def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    makers = {"reload_smg": reload_smg, "reload_shotgun": reload_shotgun, "reload_lmg": reload_lmg,
              "reload_sniper": reload_sniper}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N = int(row["frames"])
        ev = dict(row.get("events", {}))
        if name in makers:
            out[name] = Clip(name, N, False, makers[name](sk, solver, N), 0.0, None, ev, reach_fix=False)
        elif name in COVER:
            out[name] = _peek_clip(sk, solver, name, N)
        else:
            out[name] = Clip(name, N, False, stagger(sk, solver, name.split("_")[1], N), 0.0, None, ev,
                             reach_fix=False)
    return out


def source_notes() -> dict:
    return {"police_combat": (
        "D-116 organic pass, police combat movement (crew too). Reloads per class, each from aim_rifle frame 0 back "
        "to it, the hands on the class reference model's own points: reload_smg (SMG, SPECIAL), reload_shotgun "
        "(SHOTGUN: `shell` = the first of four shells, one every 12 f, then the pump), reload_lmg (LMG: cover_open, "
        "mag_out, mag_in, cover_close), reload_sniper (SNIPER: mag_out, mag_in, `bolt` = the bolt cycled); `done` "
        "is when the weapon is ready (scale the clip so `done` lands on reload completion, as reload_rifle). "
        "Moving: layer the reload's upper body (the weapon_holds bone filter) over the locomotion clip. Cover "
        "(150 f loops, feet planted, the brain's cover post): cover_peek_l_<fam> / cover_peek_r_<fam> stand at a "
        "corner at the low ready and lean out to that side aimed (out from 1.3 s to 4.05 s, aimed 1.75..3.6 s), "
        "cover_low_<fam> crouches behind low cover and rises to aim over it on the same timing; fam = rifle / "
        "pistol by aim family. stagger_<fam> (36 f, impact@2): a stagger-strength hit, thrown back with the "
        "weapon knocked up, a stumble step back and the catch, ending on aim_<fam> frame 0 in place (the feet end "
        "where they started; no root motion)")}
