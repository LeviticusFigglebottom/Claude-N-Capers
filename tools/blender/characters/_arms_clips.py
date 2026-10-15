"""First-person clips for every ``FPSet`` (D1-03 pistol, D-034 smg / rifle / shotgun / lmg / sniper,
D-050 akimbo (``_arms_akimbo``) / revolver (speedloader: ``_arms_revolver``) / pistol fire_auto).
Private helper of ``_arms``; pure numpy. ``fp_clips(sk, set)`` -> ``{<set>_<clip>: Clip}``.

Shared clips (all sets): ``idle*``, ``ads_idle*``, ``sprint*`` (loops), ``draw``, ``holster``,
``fire``, ``fire_ads``, ``reload``, ``reload_empty``. Per-mechanism extras:

* shotgun (pump): the pump stroke is part of ``fire`` / ``fire_ads`` (PD2 cycles pump guns inside
  the fire animation; events ``pump_back`` / ``pump_forward``). Shell-by-shell: ``reload_start``,
  ``reload_loop`` (one shell; first frame == last frame so the game can replay it per round),
  ``reload_end`` / ``reload_end_empty`` (with a pump); ``reload`` / ``reload_empty`` are the same
  pieces composed for the data's 6 rounds (whole-reload fallback, matches reload_time_s).
* sniper (bolt): ``fire`` / ``fire_ads`` are the recoil only; ``bolt`` / ``bolt_ads`` is the
  right-hand bolt cycle the game plays after each shot (fire 9 f + bolt 27 f = 1.2 s = 50 rpm).
  During the bolt the right hand leaves the grip: the ``weapon`` bone is animated relative to
  ``hand.R`` (the left hand holds the gun). ``reload_empty`` ends with the same bolt cycle.
* lmg (belt box): ``reload`` opens the feed cover, swaps the box, seats the belt and closes the
  cover; ``reload_empty`` adds a charging-handle pull.
"""

from __future__ import annotations

import dataclasses
import math

import numpy as np

import _anim as A
from _anim import FPS, TAU, Clip, HandShape, Skeleton, Solver, hand_shape, mslerp, rxd, ryd, rzd, smooth, unit, v3, weapon_frame
from _arms_choreo import I3, Choreo, Hand, Key, State, as_cam, grip_hand, hand_at, mag_cam, realize
from _arms_sets import (BOLT_LIFT_DEG, BOLT_TRAVEL, PISTOL_AUTO_RECOIL, PUMP_TRAVEL, SHELL_END, SHELL_END_EMPTY,
                        SHELL_LOOP, SHELL_START, SHOTGUN_BOX_CHARGE, SHOTGUN_SHELLS, FPSet)

#: Magazine held by its base: index straight up the front edge, the other fingers wrapped round it.
MAG_BASE_SHAPE = HandShape(curl={"index": (72.0, 12.0, 6.0), "middle": (80.0, 58.0, 30.0), "ring": (84.0, 62.0, 32.0),
                                 "pinky": (86.0, 62.0, 30.0)}, thumb=(10.0, 22.0, 16.0), thumb_opp=34.0, spread=-3.0)
COVER_OPEN_DEG = 78.0
HAND_COVER = 0.42           # the left hand lifts the feed cover this far, then it flips open
CHARGE_TRAVEL = 0.085


# =============================================================================================
# holds
# =============================================================================================
def hold_frame(spec: tuple, dp=(0.0, 0.0, 0.0), yaw: float = 0.0, pitch: float = 0.0,
               roll: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    p, y0, p0, r0 = spec
    return weapon_frame(np.array(p, float) + np.array(dp, float), y0 + yaw, p0 + pitch, r0 + roll)


def ads_frame(s: FPSet) -> tuple[np.ndarray, np.ndarray]:
    if s.ads_hold is not None:              # no sights (saw, minigun, bow): a raised hold instead
        return hold_frame(s.ads_hold)
    return weapon_frame(v3(0.0, s.ads_dist, 0.0) - s.markers["aim"])


TWIST = 0.35


@dataclasses.dataclass(frozen=True)
class SupportGrip:
    """One long-gun set's support grip under its fore-end (weapon axes; tuned against its reference model's skin)."""
    along: tuple[float, float, float]     # palm direction toward the fingers
    palm: tuple[float, float, float]      # palm normal (up into the fore-end)
    shift: tuple[float, float, float]     # target point from LeftHandIK (m)
    thumb_opp: float                      # thumb opposition (deg; less negative = lying further round the near side)
    ring_pinky: float                     # ring / pinky closed further than the grip curl (deg; pinky x 1.3): they
                                          # sit further out round the fore-end's far side
    offset: tuple[float, float, float]    # the resulting wrist from LeftHandIK, Godot marker axes (ENV P's per-set
                                          # FpViewmodelTweak.set_left_hand_grip_offset: must match)
    curl: float = 0.60                    # the "grip" hand shape amount (finger closure)
    index_open: float = 0.0               # index opened from the grip curl (deg; base / middle / tip x 1 / 0.8 / 0.4)
    thumb: tuple[float, float, float] = (4.0, 6.0, 4.0)   # thumb flex (cmc, mcp, ip; deg)
    fingers: tuple = ()                   # PO6-09: per-finger "grip" amounts (index, middle, ring, pinky), each closed
                                          # until it rests on the set's tightest fore-end; replaces curl / index_open /
                                          # ring_pinky when given


#: PO review 2026-10-14 (lead): the gun rests in the support hand, fingers wrapping the far side with only the tips
#: showing below the handguard top, the thumb forward along the near side, 2-5 mm clear of the skin. One grip per set
#: because the fore-ends differ (round tube, slab handguard, wide shroud); test_arms checks the skin.
#: PO6-09 (2026-10-15): refitted on EVERY gun of each set (each LeftHandIK on the set's marker, as the runtime IK
#: does): the palm, wrist and thumb flex by coordinate descent, then each finger and the thumb opposition closed until
#: the tightest fore-end of the set is within 0.8 mm of skin (ENV P's PFingerClip limit is 2 mm). The thumb now
#: lies low along the near side next to the palm (thumb_opp -30 lifted it to the top edge, apart from the hand).
#: smg (B's under-fore-end markers, lead 2026-10-14): fitted on hornet / lancet / ferret / hush / mastiff; the short
#: fore-ends leave no room ahead of the magazine, so the palm cups the lower-left corner, fingers across, thumb up the side.
LONG_GUN_GRIPS: dict[str, SupportGrip] = {
    "rifle": SupportGrip((0.6, 0.8, -0.25), (0.0, -0.1, 1.0), (-0.005, 0.0, 0.003), -8.31, 0.0,
                (-0.0381, 0.0021, 0.0426), thumb=(16.0, -18.0, 4.0), fingers=(0.272, 0.523, 0.637, 0.806)),
    "shotgun": SupportGrip((1.1125, 0.95, -0.35), (0.05, -0.2, 1.0), (-0.0055, -0.002, 0.006), -29.37, 0.0,
                (-0.0482, 0.0048, 0.035), thumb=(4.0, 7.5, 4.0), fingers=(0.586, 0.717, 0.771, 1.348)),
    "lmg": SupportGrip((0.9375, 0.875, -0.375), (-0.075, 0.0, 1.0), (0.004, 0.004, -0.0035), 2.22, 0.0,
                (-0.0349, -0.0023, 0.0334), thumb=(4.0, -12.0, 4.0), fingers=(0.53, 0.668, 1.348, 1.348)),
    "sniper": SupportGrip((0.5, 0.65, -0.1), (0.075, -0.1375, 1.0), (-0.004, 0.004, -0.002), -17.12, 0.0,
                (-0.0382, -0.0094, 0.0371), thumb=(28.0, -18.0, 4.0), fingers=(0.22, 0.539, 0.649, 0.837)),
    "break_action": SupportGrip((0.725, 0.8, -0.25), (-0.1, 0.05, 1.0), (0.0, 0.004, 0.002), -6.7, 0.0,
                (-0.0351, 0.0002, 0.037), thumb=(4.0, 6.0, 4.0), fingers=(0.462, 0.595, 0.736, 1.348)),
    "lever": SupportGrip((0.7875, 0.8, -0.3125), (0.05, 0.1, 1.0), (-0.006, 0.0, 0.001), -7.34, 0.0,
                (-0.0435, 0.0015, 0.0388), thumb=(4.0, 6.0, 4.0), fingers=(0.48, 0.661, 0.759, 1.348)),
    "smg": SupportGrip((0.85, 0.4, 0.0), (0.3, -0.2, 1.0), (0.005, 0.018, -0.013), 14.68, 0.0,
                (-0.0439, -0.0264, 0.0005), thumb=(-20.0, -24.0, 4.0), fingers=(0.713, 0.78, 1.348, 0.87)),
    "shotgun_box": SupportGrip((0.825, 0.725, -0.325), (0.075, -0.125, 1.0), (-0.006, 0.004, 0.0), -27.0, 0.0,
                (-0.0479, 0.0015, 0.03), thumb=(4.0, 12.0, 4.0), fingers=(0.558, 0.666, 0.717, 1.348)),
}


def cup_shape(g: SupportGrip) -> HandShape:
    """The long-gun support hand: fingers closed round the fore-end (ring and pinky more), the thumb open along it."""
    shape = hand_shape("grip", g.curl)
    curl = dict(shape.curl)
    if g.fingers:
        full = hand_shape("grip", 1.0).curl
        curl = {f: tuple(x * a for x in full[f]) for f, a in zip(("index", "middle", "ring", "pinky"), g.fingers)}
        return dataclasses.replace(shape, curl=curl, thumb=g.thumb, thumb_opp=g.thumb_opp)
    for f, extra in (("index", -g.index_open * 1.0), ("ring", g.ring_pinky), ("pinky", g.ring_pinky * 1.3)):
        b, m, t = curl[f]
        curl[f] = (b + extra, m + extra * 0.8, t + extra * 0.4)
    return dataclasses.replace(shape, curl=curl, thumb=g.thumb, thumb_opp=g.thumb_opp)


def long_gun(s: FPSet) -> bool:
    return s.support != "pistol"


class Kit:
    """The hand vocabulary of one set (hands in weapon / camera / magazine space)."""

    def __init__(self, sk: Skeleton, s: FPSet) -> None:
        self.sk, self.s = sk, s
        m = s.markers
        self.grip = grip_hand(sk, pole=s.pole_r)
        if s.support == "pistol":
            self.support = hand_at(sk, "L", "w", m["left_ik"], (0.55, 0.45, -0.70), (0.85, 0.05, 0.25),
                                   s.pole_l, "support", share=0.45, off=0.016)
        elif s.support == "vgrip" and "left_palm" in m:   # a vertical front grip, palm on LeftHandIK (D2-04)
            self.support = left_vgrip(sk, m["left_palm"], s.pole_l)
        elif s.support in ("vgrip", "bow"):        # a pistol-style front grip / the bow riser (D-055)
            self.support = left_grip(sk, m.get("vgrip", m["left_ik"]), s.pole_l)
        elif s.support == "top":                   # a transverse top handle, palm down (saw)
            self.support = hand_at(sk, "L", "w", m.get("top_bar", m["left_ik"]), (0.20, 0.95, -0.25), (0.05, 0.10, -0.99),
                                   s.pole_l, hand_shape("grip", 0.85), share=0.55, off=0.017)
        elif abs(float(m["left_ik"][0])) < 0.005:  # LeftHandIK under the fore-end (B, e18011f4): PD2 support grip,
            # the fore-end resting in the palm, fingers wrapping its far (right) side with the tips below its top,
            # the thumb lying forward along its near (left) side. The wrist sits at the set's SupportGrip.offset from
            # the marker (FpViewmodelTweak.set_left_hand_grip_offset, ENV P), so the runtime left-hand IK target IS
            # this wrist and the game shows the grip unchanged.
            g = LONG_GUN_GRIPS[s.name]
            self.support = hand_at(sk, "L", "w", np.asarray(m["left_ik"], float) + np.asarray(g.shift), g.along,
                                   g.palm, s.pole_l, cup_shape(g), share=0.55, off=0.014, twist=0.0)
        else:
            self.support = hand_at(sk, "L", "w", m["left_ik"], (0.30, 0.45, 0.84), (0.75, 0.62, -0.10),
                                   s.pole_l, hand_shape("grip", 0.80), share=0.55, off=0.018)
        self.support_ads = self.support.copy()
        self.support_ads.pole = unit(np.asarray(s.pole_l_ads, float))
        self.down = hand_at(sk, "L", "c", (-0.20, 0.03, -0.60), (0.15, 0.35, -0.92), (0.95, 0.0, 0.25),
                            (-0.5, -0.6, -0.4), "relaxed", share=0.5)
        self.ready = hand_at(sk, "L", "c", (-0.10, 0.16, -0.40), (0.35, 0.60, -0.70), (0.90, -0.10, 0.40),
                             (-0.6, -0.5, -0.6), "relaxed", share=0.5)
        self.pouch = hand_at(sk, "L", "c", s.pouch, (0.30, 0.45, -0.85), (0.95, -0.05, 0.25),
                             (-0.65, -0.45, -0.6), "relaxed", share=0.5)
        self.mag_grip = self._mag_grip() if s.mag else None

    # -- magazine in the left hand (magazine space = weapon axes of the magazine frame) --------
    def _mag_grip(self) -> Hand:
        s, m = self.s, self.s.markers
        mg, ax = s.mag, m["magwell_axis"]
        kind = mg["grip"]
        if kind == "side":        # palm on the left face, fingers wrapped round the front edge
            pt = m["magwell"] - ax * (0.62 * -mg["bottom"]) + v3(-mg["hw"] - 0.002, -0.006, 0.0)
            return hand_at(self.sk, "L", "m", pt, unit(v3(0.0, 0.62, 0.0) + ax * 0.78), v3(1.0, 0.0, 0.05),
                           (-0.6, -0.5, -0.6), hand_shape("grip", 0.72), share=0.42, off=0.012)
        if kind == "box":         # belt box: palm on its left side, fingers under the bottom front
            pt = m["magwell"] + v3(mg.get("cx", 0.0) - mg["hw"] - 0.012, 0.0, mg["bottom"] * 0.55)
            return hand_at(self.sk, "L", "m", pt, v3(0.0, 0.85, -0.52), v3(1.0, 0.0, 0.1),
                           (-0.6, -0.5, -0.6), hand_shape("grip", 0.55), share=0.5, off=0.012)
        # "base": palm under the base, index along the front, fingers wrapped round the body
        pt = m["magwell"] - ax * (-mg["bottom"] + 0.004) + v3(-0.003, 0.004, 0.0)
        along = unit(v3(-0.30, 0.95, 0.0) - ax * float(ax @ v3(-0.30, 0.95, 0.0)))
        return hand_at(self.sk, "L", "m", pt, along, ax, (-0.6, -0.4, -0.7), MAG_BASE_SHAPE, share=0.62, off=0.014)

    def mag_out(self, d: float, tilt: float = 0.0) -> tuple:
        """Magazine ``d`` m out of the magwell along its axis (weapon-relative), tilted ``tilt``
        deg about the weapon X axis around the magwell."""
        m = self.s.markers
        ax = m["magwell_axis"]
        R = rxd(tilt)
        mw = m["magwell"]
        return ("w", R, mw - R @ mw - ax * d)

    def mag_for_hand(self, hand_c: Hand) -> tuple:
        """The camera-space magazine frame that puts ``mag_grip`` on the camera-space hand."""
        g = self.mag_grip
        Rm = hand_c.axes @ g.axes.T
        return ("c", Rm, hand_c.wrist - Rm @ g.wrist)

    def left_c(self, point, along, palm, pole=(-0.6, -0.4, -0.65), shape="relaxed", share=0.5) -> Hand:
        return hand_at(self.sk, "L", "c", point, along, palm, pole, shape, share=share)

    def left_w(self, point, along, palm, pole=(-0.6, -0.4, -0.65), shape="grip", share=0.5, off=0.016) -> Hand:
        return hand_at(self.sk, "L", "w", point, along, palm, pole, shape, share=share, off=off)

    def right_w(self, point, along, palm, pole=(0.75, -0.2, -0.65), shape="pinch", share=0.5, off=0.016) -> Hand:
        h = hand_at(self.sk, "R", "w", point, along, palm, pole, shape, share=share, off=off)
        h.twist = 0.6
        return h


def left_grip(sk: Skeleton, at, pole) -> Hand:
    """The left hand on a pistol-style grip whose pivot is ``at`` (weapon space): the mirrored
    weapon grip offset (``_anim.grip_offset(sk, "L")``, the akimbo offhand convention)."""
    R_off, t_off = A.grip_offset(sk, "L")
    axes = R_off.T.copy()
    return Hand("w", np.asarray(at, float) - axes @ t_off, axes, unit(np.asarray(pole, float)),
                hand_shape("grip", 0.9), 0.5)


#: palm centre of a gripping hand: half way along the hand bone, this far in front of it (m); the
#: midpoint of ``hand.<s>`` and ``middle_01.<s>`` sits ~19 mm from a marker the palm is placed on
PALM_SHARE, PALM_OFF = 0.5, 0.018


def left_vgrip(sk: Skeleton, palm_w, pole) -> Hand:
    """The left hand closed round a VERTICAL front grip (D2-04: crossbow, flamethrower, minigun) with its
    palm centre on ``palm_w`` (the weapon's LeftHandIK): the mirrored grip offset turned upright (the
    pistol grip's 18 deg rake removed) and moved so the palm lands on the marker."""
    h = left_grip(sk, v3(0.0, 0.0, 0.0), pole)
    h = h.turned(rxd(A.GRIP_RAKE_DEG), v3(0.0, 0.0, 0.0))
    palm = h.wrist + h.axes @ v3(0.0, PALM_SHARE * sk.length("hand.L"), -PALM_OFF * sk.scale)
    return h.moved(np.asarray(palm_w, float) - palm)


def hand_w(sk: Skeleton, sfx: str, wf: tuple, point, along, palm, pole, shape, share: float = 0.5,
           off: float = 0.016) -> Hand:
    """A hand authored in camera space for the weapon hold ``wf`` (``hand_at`` arguments), stored in
    weapon space so it stays on the weapon when the hold moves (D-055)."""
    h = hand_at(sk, sfx, "c", point, along, palm, pole, shape, share=share, off=off)
    R, o = wf
    return Hand("w", R.T @ (h.wrist - o), R.T @ h.axes, h.pole, h.shape, h.twist)


def K(f, wf, L, R, **kw) -> Key:
    return Key(int(f), wf, L, R, **kw)


# =============================================================================================
# generic clips
# =============================================================================================
def _sway(st: State, f: int, N: int, amp: float = 1.0, ads: bool = False) -> None:
    ph = f / N
    b = math.sin(TAU * ph * 2.0)               # breathing (2 per loop)
    w = math.sin(TAU * ph + 0.6)               # slow figure-eight weight shift
    R, o = st.wf
    if ads:
        aim_pt = o.copy()
        Rs = rxd(0.12 * b * amp) @ rzd(0.10 * w * amp)
        st.wf = (Rs @ R, o + v3(0.0006 * w, 0.0, 0.0010 * b) * amp)
        _ = aim_pt
    else:
        st.wf = (rzd(0.5 * w * amp) @ rxd(0.45 * b * amp) @ R @ ryd(0.4 * w * amp),
                 o + v3(0.003 * w, 0.0, 0.0035 * b) * amp)


def _static(kit: Kit, s: FPSet, wf, blade: float, ads: bool = False) -> list[Key]:
    return [K(0, wf, kit.support_ads if ads else kit.support, kit.grip, blade=blade)]


def clip_idle(kit: Kit, s: FPSet, N: int):
    ch = Choreo(_static(kit, s, hold_frame(s.hip), s.blade), post=lambda f, st: _sway(st, f, N))
    return ch


def clip_ads_idle(kit: Kit, s: FPSet, N: int):
    return Choreo(_static(kit, s, ads_frame(s), s.blade_ads, True), post=lambda f, st: _sway(st, f, N, 0.6, ads=True))


def clip_sprint(kit: Kit, s: FPSet, N: int):
    def post(f: int, st: State) -> None:
        ph = f / N
        bob = math.cos(TAU * 2 * ph)
        side = math.sin(TAU * ph)
        R, o = st.wf
        st.wf = (rzd(3.0 * side) @ R @ rxd(2.5 * bob) @ ryd(4.0 * side),
                 o + v3(0.012 * side, 0.004 * bob, 0.014 * bob))
        if s.support == "pistol":     # free left arm pumps below the view
            sw = math.sin(TAU * ph + 0.3)
            st.L = st.L.moved(v3(0.02 * sw, 0.10 * sw, 0.03 * abs(sw)))
    wf = hold_frame(s.sprint)
    left = kit.down if s.support == "pistol" else kit.support
    return Choreo([K(0, wf, left, kit.grip.with_shape(hand_shape("grip", 0.9)), blade=s.blade * 0.6)], post=post)


def clip_draw(kit: Kit, s: FPSet, N: int, reverse: bool = False):
    lo, hi = hold_frame(s.lowered), hold_frame(s.hip)
    pistol = s.support == "pistol"

    def post(f: int, st: State) -> None:
        u = f / N
        if reverse:
            u = 1.0 - u
        e = A.bezier1(u, 0.0, 1.08)                   # fast in, small overshoot settle
        st.wf = (mslerp(lo[0], hi[0], min(1.0, e)), lo[1] + (hi[1] - lo[1]) * e)
        if True:                                      # the support hand joins late, from below
            j = smooth(0.3, 0.95, u) if pistol else smooth(0.2, 0.85, u)
            sup = kit.support
            low = kit.ready
            mag_c = (st.wf[0], st.wf[1])
            a = as_cam(low, st.wf, mag_c)
            b = as_cam(sup, st.wf, mag_c)
            st.L = Hand("c", a.wrist + (b.wrist - a.wrist) * j, mslerp(a.axes, b.axes, j),
                        unit(a.pole + (b.pole - a.pole) * j), low.shape.blend(sup.shape, j), 0.5)
        st.blade = s.blade * (0.6 + 0.4 * min(1.0, max(0.0, e)))
    return Choreo([K(0, hi, kit.support, kit.grip, blade=s.blade)], post=post)


def kick_curve(f: int, N: int) -> float:
    """Recoil envelope: 0 at frame 0, peak on frame 1, spring return (small overshoot), 0 at N."""
    if f <= 0 or f >= N:
        return 0.0
    if N <= 3:                                        # full-auto: back near rest by the next shot
        return [0.0, 1.0, 0.22][f]
    t = (f - 1) / FPS
    win = 1.0 - smooth(0.55 * N, float(N), float(f))
    return A.spring(t, freq=4.2, zeta=0.5) * win


def apply_recoil(st: State, rec: dict, k: float) -> None:
    R, o = st.wf
    o2 = o + R @ v3(0.0, -rec["back"] * k, rec["up"] * k)
    st.wf = (R @ rxd(rec["pitch"] * k) @ ryd(rec["roll"] * k) @ rzd(rec.get("yaw", 0.0) * k), o2)


def clip_fire(kit: Kit, s: FPSet, N: int, ads: bool, scale: float = 1.0):
    wf = ads_frame(s) if ads else hold_frame(s.hip)
    rec = {k: v * scale for k, v in (s.recoil_ads if ads else s.recoil).items()}
    kick_n = 9 if s.name == "shotgun" else N

    def post(f: int, st: State) -> None:
        apply_recoil(st, rec, kick_curve(f, kick_n))
        if s.name == "shotgun":
            _pump_layer(kit, s, st, f, s.ev("fire_ads" if ads else "fire"), ads)
    return Choreo(_static(kit, s, wf, s.blade_ads if ads else s.blade, ads), post=post)


# =============================================================================================
# shotgun: pump and shells
# =============================================================================================
def pump_travel(f: int, ev: dict) -> float:
    """Pump position 0..1 (1 = fully back) from the pump_back / pump_forward events."""
    b, fw = ev["pump_back"], ev["pump_forward"]
    t0 = b - 4
    if f <= t0:
        return 0.0
    if f <= b:
        return A.ease_in(smooth(t0, b, f) ** 0.8, 1.4)
    if f <= b + 1:
        return 1.0
    return 1.0 - A.ease_out((f - b - 1) / max(1, fw - b - 1), 1.6) if f < fw else 0.0


def _pump_layer(kit: Kit, s: FPSet, st: State, f: int, ev: dict, ads: bool = False) -> None:
    p = pump_travel(f, ev)
    st.extra["pump"] = p
    if p <= 0.0:
        return
    st.L = st.L.moved(v3(0.0, -PUMP_TRAVEL * p, 0.0)) if st.L.space == "w" else st.L
    # the gun dips and rolls a little into the stroke
    R, o = st.wf
    g = math.sin(math.pi * min(1.0, p))
    k = 0.5 if ads else 1.0
    st.wf = (R @ rxd(-2.0 * p * k) @ ryd(-3.5 * g * k), o + R @ v3(0.004 * g, -0.010 * p * k, -0.006 * p * k))


def _shell_hands(kit: Kit, s: FPSet):
    """Left hand with a shell: below the loading port (start of a loop) and at the port."""
    m = s.markers
    port = m["magwell"]
    at_port = kit.left_w(port + v3(-0.006, -0.040, -0.024), (0.10, 0.85, 0.50), (0.15, -0.30, 0.94),
                         pole=(-0.6, -0.45, -0.65), shape="pinch", share=0.92, off=0.010)
    pushed = at_port.moved(v3(0.0, 0.040, 0.012))
    below = kit.left_w(port + v3(-0.075, -0.075, -0.10), (0.25, 0.70, 0.65), (0.35, -0.35, 0.87),
                       pole=(-0.6, -0.45, -0.65), shape="pinch", share=0.92, off=0.010)
    return below, at_port, pushed


def shells_start(kit: Kit, s: FPSet, N: int):
    below, _at, _p = _shell_hands(kit, s)
    tilt = hold_frame(s.reload_tilt)
    def post(f: int, st: State) -> None:
        st.extra["shell"] = f >= N - 4
    return Choreo([K(0, hold_frame(s.hip), kit.support, kit.grip, blade=s.blade),
                   K(N, tilt, below, kit.grip, blade=s.blade, arc_l=(-0.04, -0.02, -0.06))], post=post)


def shells_loop(kit: Kit, s: FPSet, N: int):
    below, at_port, pushed = _shell_hands(kit, s)
    tilt = hold_frame(s.reload_tilt)
    sin_ = s.ev("reload_loop")["shell_in"]
    tilt_push = hold_frame(s.reload_tilt, (0.0, 0.004, 0.003), pitch=1.0)
    return Choreo([K(0, tilt, below, kit.grip, blade=s.blade),
                   K(sin_ - 3, tilt, at_port, kit.grip, blade=s.blade, arc_l=(-0.01, 0.0, -0.015)),
                   K(sin_, tilt_push, pushed, kit.grip, blade=s.blade, ease="snap"),
                   K(N, tilt, below, kit.grip, blade=s.blade, arc_l=(-0.025, 0.0, -0.02))],
                  post=lambda f, st: st.extra.__setitem__("shell", f < sin_ or f >= N - 2))


def shells_end(kit: Kit, s: FPSet, N: int, empty: bool):
    below, _a, _p = _shell_hands(kit, s)
    tilt = hold_frame(s.reload_tilt)
    hip = hold_frame(s.hip)
    ev = s.ev("reload_end_empty" if empty else "reload_end")
    if not empty:
        keys = [K(0, tilt, below, kit.grip, blade=s.blade),
                K(ev["done"], hip, kit.support, kit.grip, blade=s.blade, arc_l=(-0.03, 0.0, -0.05)),
                K(N, hip, kit.support, kit.grip, blade=s.blade, ease="settle")]
        return Choreo(keys, post=lambda f, st: st.extra.__setitem__("shell", f < 3))
    pre = hold_frame(s.hip, (-0.02, 0.0, 0.02), yaw=4.0, pitch=3.0, roll=-8.0)
    keys = [K(0, tilt, below, kit.grip, blade=s.blade),
            K(ev["pump_back"] - 6, pre, kit.support, kit.grip, blade=s.blade, arc_l=(-0.03, 0.0, -0.05)),
            K(ev["done"], hip, kit.support, kit.grip, blade=s.blade),
            K(N, hip, kit.support, kit.grip, blade=s.blade, ease="settle")]
    def post(f: int, st: State) -> None:
        st.extra["shell"] = f < 3
        _pump_layer(kit, s, st, f, ev)
    return Choreo(keys, post=post)


def concat(parts: list[tuple[int, Choreo]]):
    """Play choreographies back to back (each for its frame count)."""
    def fn(f: int) -> State:
        base = 0
        for i, (n, ch) in enumerate(parts):
            if f <= base + n or i == len(parts) - 1:
                return ch(f - base)
            base += n
        raise AssertionError
    return fn


# =============================================================================================
# magazine reloads (pistol, smg, rifle, sniper)
# =============================================================================================
def _fall(kit: Kit, st0: State, t: float) -> tuple:
    """Free-falling magazine ``t`` s after release (camera space), from the state's mag frame."""
    Rm, pm = mag_cam(st0.wf, st0.mag)
    ax = Rm @ kit.s.markers["magwell_axis"]
    p = pm - ax * 0.35 * t + v3(0.0, 0.0, -0.5 * 9.81 * t * t)
    return ("c", Rm @ rxd(-80.0 * t), p)


def clip_mag_reload(kit: Kit, s: FPSet, N: int, empty: bool):
    ev = s.ev("reload_empty" if empty else "reload")
    o, sw, i, done = ev["mag_out"], ev["mag_swap"], ev["mag_in"], ev["done"]
    hip = hold_frame(s.hip)
    tilt = hold_frame(s.reload_tilt)
    tilt_out = hold_frame(s.reload_tilt, (0.0, 0.0, -0.004), pitch=-1.5, roll=2.0)
    tilt_in = hold_frame(s.reload_tilt, (0.0, 0.003, 0.010), pitch=2.5, roll=-1.5)
    mg = s.mag
    clear = mg["top"] + 0.012                         # fully out of the magwell
    g = kit.mag_grip
    bl = s.blade
    keys = [K(0, hip, kit.support, kit.grip, blade=bl)]
    drop = empty or s.support == "pistol"          # PD2 pistols always drop the magazine
    if s.support != "pistol":                      # reach the seated magazine
        keys.append(K(o - 6, tilt, g, kit.grip, mag=kit.mag_out(0.0), blade=bl, arc_l=(-0.03, -0.01, -0.06)))
    rock = float(mg.get("rock", 0.0))              # rock-in drum / box (D-058): front lip first
    if not drop and rock:
        # tactical: rock the drum forward off its front lip, then down and away to the pouch
        keys.append(K(o, tilt_out, g, kit.grip, mag=kit.mag_out(0.006, rock * 0.6), blade=bl, ease="snap"))
        keys.append(K(o + 4, tilt_out, g, kit.grip, mag=kit.mag_out(clear + 0.02, rock), blade=bl))
    elif not drop:
        # tactical: pull the magazine, carry it down to the pouch, come back with a fresh one
        keys.append(K(o, tilt_out, g, kit.grip, mag=kit.mag_out(clear * 0.55), blade=bl, ease="snap"))
        keys.append(K(o + 3, tilt_out, g, kit.grip, mag=kit.mag_out(clear + 0.02, -6.0), blade=bl))
    if not drop:
        keys.append(K(sw, tilt, g, kit.grip, mag=kit.mag_for_hand(kit.pouch), blade=bl, arc_m=(-0.05, 0.0, 0.0)))
    elif drop:
        # the release is pressed, the magazine drops free; the left hand goes for the pouch
        let_go = (kit.support.moved(v3(-0.035, -0.01, -0.03)) if s.support == "pistol"
                  else g.moved(v3(-0.03, 0.0, 0.0))).with_shape(hand_shape("relaxed"))
        keys.append(K(o, tilt_out, let_go, kit.grip, mag=kit.mag_out(0.0), blade=bl, ease="snap"))
        keys.append(K(sw, tilt, g.with_shape(hand_shape("grip", 0.5)), kit.grip,
                      mag=kit.mag_for_hand(kit.pouch), blade=bl, arc_l=(-0.06, 0.0, 0.0)))
    # fresh magazine up under the magwell, aligned, then seated
    if rock:
        # rock-in: the drum comes up canted forward, its front lip hooks into the magwell, then the left
        # hand rocks it back against the gun (tilt_in: the right hand meets it) until it latches at mag_in
        keys.append(K(i - 11, tilt, g, kit.grip, mag=kit.mag_out(clear + 0.035, rock), blade=bl,
                      arc_m=(-0.05, -0.02, -0.03)))
        keys.append(K(i - 5, tilt, g, kit.grip, mag=kit.mag_out(0.004, rock * 0.85), blade=bl, ease="inout"))
    else:
        keys.append(K(i - 9, tilt, g, kit.grip, mag=kit.mag_out(clear + 0.045, -4.0), blade=bl,
                      arc_m=(-0.05, -0.02, -0.03)))
        keys.append(K(i - 3, tilt, g, kit.grip, mag=kit.mag_out(clear * 0.5), blade=bl, ease="inout"))
    seat = g if mg["grip"] == "base" else g.with_shape(hand_shape("grip", 0.45))
    keys.append(K(i, tilt_in, seat, kit.grip, mag=None, blade=bl, ease="snap"))
    after = i + 4
    keys.append(K(after, tilt, g.moved(-s.markers["magwell_axis"] * 0.025).with_shape(hand_shape("relaxed")),
                  kit.grip, blade=bl, ease="out"))
    if empty or "belt_seat" in ev:
        after = _release_keys(kit, s, ev, keys, after)
    keys.append(K(done, hip, kit.support, kit.grip, blade=bl, arc_l=(-0.03, 0.0, -0.04)))
    keys.append(K(N, hip, kit.support, kit.grip, blade=bl, ease="settle"))

    ch = Choreo(keys)
    drop_from: dict = {}

    def fn(f: int) -> State:
        st = ch(f)
        if drop and o < f < sw:
            if "st" not in drop_from:
                drop_from["st"] = ch(o)
            st.L = as_cam(st.L, st.wf, mag_cam(st.wf, st.mag))     # the hand lets go of the falling mag
            st.mag = _fall(kit, drop_from["st"], (f - o) / FPS)
        if s.name == "sniper" and empty:
            _bolt_layer(kit, s, st, f, ev)
        return st
    return fn


def _release_keys(kit: Kit, s: FPSet, ev: dict, keys: list, after: int) -> int:
    """The empty-reload finisher between mag_in and done (adds keys, returns the last frame)."""
    bl = s.blade
    m = s.markers
    if s.support == "pistol":
        rel = ev["slide_release"]
        slide = m["slide_rear"]

        def grab(pull: float) -> Hand:
            return kit.left_w(slide + v3(-0.018, -pull, 0.012), (0.95, -0.05, -0.30), (0.30, 0.0, -0.95),
                              pole=(-0.7, -0.2, -0.7), shape=hand_shape("grip", 0.9), share=0.62, off=0.02)
        rack = hold_frame(s.reload_tilt, (0.01, 0.03, 0.01), pitch=-4.0, roll=-30.0)
        rack_back = hold_frame(s.reload_tilt, (0.01, 0.045, 0.01), pitch=-4.0, roll=-30.0)
        beside = kit.left_w(slide + v3(-0.075, 0.01, -0.01), (0.25, 0.35, 0.90), (1.0, 0.0, -0.1),
                            pole=(-0.7, -0.3, -0.65), shape="relaxed", share=0.5)
        keys.append(K(rel - 9, rack, beside, kit.grip, blade=bl, arc_l=(-0.03, 0.0, 0.0)))
        keys.append(K(rel - 5, rack, grab(0.0), kit.grip, blade=bl, arc_l=(-0.01, 0.0, 0.03)))
        keys.append(K(rel - 1, rack_back, grab(0.032), kit.grip, blade=bl))
        keys.append(K(rel + 3, rack_back, grab(0.032).moved(v3(-0.05, -0.04, 0.03)).with_shape(hand_shape("relaxed")),
                      kit.grip, blade=bl, ease="snap"))
        return rel + 3
    if s.name == "smg":             # HK slap: the locked-back cocking handle slapped down
        rel = ev["bolt_release"]
        knob_b, knob = m["cock_back"], m["cock"]
        hold = hold_frame(s.reload_tilt, (0.0, 0.01, 0.0), pitch=2.0, roll=-10.0)

        def at(p, shape) -> Hand:
            return kit.left_w(p + v3(-0.010, 0.0, 0.004), (0.25, 0.55, 0.80), (0.92, -0.05, -0.38),
                              pole=(-0.6, -0.35, -0.7), shape=shape, share=0.55, off=0.012)
        keys.append(K(rel - 9, hold, at(knob_b + v3(-0.02, -0.02, 0.03), hand_shape("flat")), kit.grip, blade=bl,
                      arc_l=(-0.03, 0.0, 0.03)))
        keys.append(K(rel - 3, hold, at(knob_b, hand_shape("grip", 0.6)), kit.grip, blade=bl))
        keys.append(K(rel, hold_frame(s.reload_tilt, (0.0, 0.012, -0.004), pitch=1.0, roll=-11.0),
                      at(knob + v3(0.0, 0.006, -0.006), hand_shape("grip", 0.4)), kit.grip, blade=bl, ease="snap"))
        keys.append(K(rel + 4, hold, at(knob + v3(-0.03, 0.02, -0.02), hand_shape("relaxed")), kit.grip, blade=bl,
                      ease="out"))
        return rel + 4
    if s.name == "rifle":           # palm slaps the bolt catch
        rel = ev["bolt_release"]
        catch = m["catch"]
        hold = hold_frame(s.reload_tilt, (0.0, 0.0, 0.01), pitch=3.0, roll=-6.0)

        def at(p, shape) -> Hand:
            return kit.left_w(p, (0.0, 0.55, 0.84), (1.0, 0.05, 0.0), pole=(-0.6, -0.4, -0.7), shape=shape,
                              share=0.40, off=0.012)
        keys.append(K(rel - 6, hold, at(catch + v3(-0.04, -0.01, 0.0), hand_shape("flat")), kit.grip, blade=bl))
        keys.append(K(rel, hold_frame(s.reload_tilt, (0.004, 0.0, 0.006), pitch=2.0, roll=-4.0),
                      at(catch, hand_shape("flat")), kit.grip, blade=bl, ease="snap"))
        keys.append(K(rel + 4, hold, at(catch + v3(-0.04, 0.01, -0.01), hand_shape("relaxed")), kit.grip, blade=bl,
                      ease="out"))
        return rel + 4
    if s.name == "shotgun_box":     # D-058: rack the charging handle (left side) and let it fly home
        rel = ev["bolt_release"]
        cock = m["cock"]
        hold = hold_frame(s.reload_tilt, (0.0, 0.01, 0.0), pitch=2.0, roll=-12.0)

        def on_handle(back: float, shape) -> Hand:
            return kit.left_w(cock + v3(-0.010, -SHOTGUN_BOX_CHARGE * back, 0.004), (0.25, 0.55, 0.80),
                              (0.92, -0.05, -0.38), pole=(-0.6, -0.35, -0.7), shape=shape, share=0.55, off=0.012)
        keys.append(K(rel - 12, hold, on_handle(0.0, hand_shape("flat")).moved(v3(-0.03, -0.01, 0.02)), kit.grip,
                      blade=bl, arc_l=(-0.03, 0.0, 0.03)))
        keys.append(K(rel - 7, hold, on_handle(0.0, hand_shape("grip", 0.65)), kit.grip, blade=bl))
        keys.append(K(rel - 1, hold_frame(s.reload_tilt, (0.0, 0.004, 0.0), pitch=1.5, roll=-13.0),
                      on_handle(1.0, hand_shape("grip", 0.65)), kit.grip, blade=bl, ease="in"))
        keys.append(K(rel + 4, hold, on_handle(1.0, hand_shape("relaxed")).moved(v3(-0.035, 0.01, 0.02)), kit.grip,
                      blade=bl, ease="out"))
        return rel + 4
    if "belt_seat" in ev:           # minigun: feed the new belt into the feed chute (D-055)
        seat = ev["belt_seat"]
        feed = m["feed"]

        def at_feed(dz: float, shape) -> Hand:
            return kit.left_w(feed + v3(-0.012, 0.0, 0.004 + dz), (0.55, 0.45, 0.70), (0.75, 0.05, -0.65),
                              pole=(-0.5, -0.3, -0.8), shape=shape, share=0.92, off=0.010)
        look = hold_frame(s.reload_tilt, (0.0, 0.02, -0.02), yaw=-3.0, pitch=-6.0, roll=-4.0)
        keys.append(K(seat - 9, look, at_feed(-0.07, "pinch"), kit.grip, blade=bl, arc_l=(-0.03, 0.0, 0.0)))
        keys.append(K(seat - 3, look, at_feed(-0.02, "pinch"), kit.grip, blade=bl))
        keys.append(K(seat, hold_frame(s.reload_tilt, (0.0, 0.02, -0.024), yaw=-3.0, pitch=-6.5, roll=-4.0),
                      at_feed(0.0, "pinch"), kit.grip, blade=bl, ease="snap"))
        keys.append(K(seat + 5, look, at_feed(0.03, "relaxed").moved(v3(-0.03, 0.0, 0.0)), kit.grip, blade=bl,
                      ease="out"))
        return seat + 5
    if s.name == "sniper":          # the bolt cycle (right hand); the left hand back on the stock
        b0 = ev["bolt_open"] - 10
        hold = _bolt_hold(s, ads=False)
        keys.append(K(b0, hold, kit.support.moved(v3(0.0, -0.07, 0.0)), kit.grip, blade=bl, arc_l=(-0.03, 0.0, -0.04)))
        _bolt_keys(kit, s, ev, keys, hold)
        return ev["bolt_close"] + 8
    return after


# =============================================================================================
# sniper bolt
# =============================================================================================
def knob_at(s: FPSet, lift: float, back: float) -> np.ndarray:
    """Bolt knob centre (weapon space) with the handle lifted ``lift`` (0..1) and the bolt
    ``back`` (0..1) of its travel."""
    m = s.markers
    k0, bore = m["knob"], m["bore"]
    r = k0 - bore
    a = math.radians(-BOLT_LIFT_DEG * lift)
    c, sn = math.cos(a), math.sin(a)
    rr = v3(r[0] * c + r[2] * sn, r[1], -r[0] * sn + r[2] * c)
    return bore + rr - v3(0.0, BOLT_TRAVEL * back, 0.0)


def bolt_state(f: int, ev: dict) -> tuple[float, float]:
    """(lift, back) of the bolt at frame ``f`` from the bolt_open / back / forward / close events."""
    o, b, fw, c = ev["bolt_open"], ev["bolt_back"], ev["bolt_forward"], ev["bolt_close"]
    if f <= o - 2 or f >= c + 1:
        return 0.0, 0.0
    if f <= o + 1:
        return smooth(o - 2, o + 1, f), 0.0
    if f <= b:
        return 1.0, smooth(o + 1, b, f)
    if f <= fw:
        return 1.0, 1.0
    if f <= c - 2:
        return 1.0, 1.0 - smooth(fw, c - 2, f)
    return 1.0 - smooth(c - 2, c + 1, f), 0.0


def _bolt_hand(kit: Kit, s: FPSet, lift: float, back: float) -> Hand:
    k = knob_at(s, lift, back)
    a = math.radians(-BOLT_LIFT_DEG * lift)
    # pinch the knob from behind: palm faces forward-left, fingers up, knob between thumb and index
    along = v3(-0.25, 0.25, 0.93)
    palm = v3(-0.35, 0.93, -0.10)
    Ry = np.array([[math.cos(a), 0.0, math.sin(a)], [0.0, 1.0, 0.0], [-math.sin(a), 0.0, math.cos(a)]])
    Rh = A.ryd(math.degrees(a) * 0.35)                  # the wrist follows the handle only partly
    return kit.right_w(k + Ry @ v3(0.006, -0.014, -0.006), Rh @ along, Rh @ palm, pole=(0.8, -0.35, -0.5),
                       shape=hand_shape("pinch", 1.0), share=0.92, off=0.020)


def _bolt_hold(s: FPSet, ads: bool):
    if ads:
        R, o = ads_frame(s)
        return weapon_frame(o + v3(0.025, 0.035, -0.055), 3.0, -4.0, -16.0)
    return hold_frame(s.hip, (-0.03, 0.06, -0.01), yaw=6.0, pitch=2.0, roll=-25.0)


def _bolt_keys(kit: Kit, s: FPSet, ev: dict, keys: list, hold) -> None:
    bl = s.blade
    o, c = ev["bolt_open"], ev["bolt_close"]
    sup_b = kit.support.moved(v3(0.0, -0.07, 0.0))
    keys.append(K(o - 3, hold, sup_b, _bolt_hand(kit, s, 0.0, 0.0), blade=bl, arc_r=(0.03, -0.02, -0.04)))
    # the knob path itself is laid by _bolt_layer; the keys only carry the weapon
    keys.append(K(c + 2, hold, sup_b, _bolt_hand(kit, s, 0.0, 0.0), blade=bl))
    keys.append(K(c + 8, hold_frame(s.hip), kit.support, kit.grip, blade=bl, arc_r=(0.03, -0.02, -0.04)))


def _bolt_layer(kit: Kit, s: FPSet, st: State, f: int, ev: dict) -> None:
    lift, back = bolt_state(f, ev)
    st.extra["bolt"] = (lift, back)
    if ev["bolt_open"] - 2 < f < ev["bolt_close"] + 1:
        st.R = _bolt_hand(kit, s, lift, back)


def clip_bolt(kit: Kit, s: FPSet, N: int, ads: bool):
    ev = s.ev("bolt_ads" if ads else "bolt")
    base = ads_frame(s) if ads else hold_frame(s.hip)
    hold = _bolt_hold(s, ads)
    bl = s.blade_ads if ads else s.blade
    sup = kit.support_ads if ads else kit.support
    sup_b = sup.moved(v3(0.0, -0.07, 0.0))           # the support hand slides back on the stock
    keys = [K(0, base, sup, kit.grip, blade=bl),
            K(ev["bolt_open"] - 3, hold, sup_b, _bolt_hand(kit, s, 0.0, 0.0), blade=bl,
              arc_r=(0.03, -0.02, -0.04)),
            K(ev["bolt_close"] + 2, hold, sup_b, _bolt_hand(kit, s, 0.0, 0.0), blade=bl),
            K(ev["done"], base, sup, kit.grip, blade=bl, arc_r=(0.03, -0.02, -0.03)),
            K(N, base, sup, kit.grip, blade=bl, ease="settle")]
    ch = Choreo(keys, post=lambda f, st: _bolt_layer(kit, s, st, f, ev))
    return ch


# =============================================================================================
# lmg belt box
# =============================================================================================
def cover_angle(f: int, ev: dict) -> float:
    """Feed-cover opening 0..1 from cover_open / cover_close."""
    op, cl = ev["cover_open"], ev["cover_close"]
    if f <= op - 5 or f >= cl:
        return 0.0
    if f <= op:
        return A.ease_out(smooth(op - 5, op, f), 1.5)
    if f <= cl - 5:
        return 1.0
    return 1.0 - A.ease_in(smooth(cl - 5, cl, f), 1.8)


def cover_point(s: FPSet, ang: float, local) -> np.ndarray:
    """A point given relative to the closed cover, with the cover opened ``ang`` (0..1)."""
    h = s.markers["cover_hinge"]
    return h + rxd(-COVER_OPEN_DEG * ang) @ (np.asarray(local, float) - h)


def clip_box_reload(kit: Kit, s: FPSet, N: int, empty: bool):
    ev = s.ev("reload_empty" if empty else "reload")
    m = s.markers
    bl = s.blade
    hip = hold_frame(s.hip)
    tilt = hold_frame(s.reload_tilt)
    look = hold_frame(s.reload_tilt, (0.0, 0.04, -0.05), yaw=-4.0, pitch=-12.0, roll=-6.0)  # cover / belt work
    g = kit.mag_grip
    co, mo, mi, seat, cc, done = (ev[k] for k in ("cover_open", "mag_out", "mag_in", "belt_seat", "cover_close",
                                                    "done"))

    def on_cover(ang: float, shape="grip") -> Hand:
        """Fingers hooked under the cover's rear edge from the left, palm down (the hand lets go
        at ``HAND_COVER`` of the opening; the cover flips fully open on its own)."""
        rear = cover_point(s, ang, m["cover_rear"] + v3(-0.020, 0.030, 0.006))
        R = rxd(-COVER_OPEN_DEG * ang)
        return kit.left_w(rear, R @ v3(0.80, 0.55, -0.10), R @ v3(0.10, 0.05, -0.99), pole=(-0.35, -0.25, -0.9),
                          shape=hand_shape(shape, 0.5) if shape == "grip" else shape, share=0.62, off=0.014)

    def slap() -> Hand:
        top = m["cover_rear"] + v3(-0.004, 0.070, 0.004)
        return kit.left_w(top, (0.75, 0.65, 0.0), (0.05, 0.0, -1.0), pole=(-0.35, -0.25, -0.9), shape="flat",
                          share=0.45, off=0.014)

    feed = m["feed"]
    at_feed = kit.left_w(feed + v3(-0.012, 0.0, 0.004), (0.55, 0.25, 0.80), (0.65, 0.05, -0.75),
                         pole=(-0.4, -0.3, -0.85), shape="pinch", share=0.92, off=0.010)
    belt_up = kit.left_w(feed + v3(-0.020, 0.0, 0.050), (0.55, 0.25, 0.80), (0.65, 0.05, -0.75),
                         pole=(-0.4, -0.3, -0.85), shape="pinch", share=0.92, off=0.010)
    belt_low = kit.left_w(m["magwell"] + v3(-0.05, 0.0, 0.02), (0.30, 0.35, 0.88), (0.85, 0.05, -0.50),
                          pole=(-0.4, -0.3, -0.85), shape="pinch", share=0.92, off=0.010)
    keys = [K(0, hip, kit.support, kit.grip, blade=bl),
            K(co - 9, look, on_cover(0.0), kit.grip, blade=bl, arc_l=(-0.04, 0.0, 0.05)),
            K(co, look, on_cover(HAND_COVER), kit.grip, blade=bl, ease="out"),
            K(co + 4, look, on_cover(HAND_COVER, "relaxed").moved(v3(-0.03, 0.0, -0.01)), kit.grip, blade=bl),
            # strip the old belt out of the tray, then pull the box
            K(co + 12, look, at_feed, kit.grip, blade=bl, arc_l=(-0.03, 0.0, 0.03)),
            K(co + 18, look, belt_low.moved(v3(-0.03, 0.0, 0.0)), kit.grip, blade=bl),
            K(mo - 7, tilt, g, kit.grip, mag=kit.mag_out(0.0), blade=bl, arc_l=(-0.03, 0.0, -0.03)),
            K(mo, tilt, g, kit.grip, mag=kit.mag_out(0.035, 4.0), blade=bl, ease="snap"),
            K(mo + 8, tilt, g, kit.grip, mag=kit.mag_out(0.12, 12.0), blade=bl, arc_m=(-0.04, 0.0, 0.0)),
            K(mo + 22, tilt, g, kit.grip, mag=kit.mag_for_hand(kit.pouch), blade=bl, arc_m=(-0.06, 0.0, 0.0)),
            # the fresh box comes up and is hooked on
            K(mi - 16, tilt, g, kit.grip, mag=kit.mag_out(0.10, 10.0), blade=bl, arc_m=(-0.06, -0.02, -0.03)),
            K(mi - 5, tilt, g, kit.grip, mag=kit.mag_out(0.025, 3.0), blade=bl),
            K(mi, hold_frame(s.reload_tilt, (0.0, 0.0, 0.008), pitch=1.5), g, kit.grip, mag=None, blade=bl,
              ease="snap"),
            # seat the belt in the tray
            K(mi + 7, look, belt_low, kit.grip, blade=bl, arc_l=(-0.03, 0.0, 0.0)),
            K(seat - 3, look, belt_up, kit.grip, blade=bl),
            K(seat, look, at_feed, kit.grip, blade=bl, ease="snap"),
            # close the cover and slap it
            K(cc - 8, look, on_cover(HAND_COVER, "flat"), kit.grip, blade=bl, arc_l=(-0.02, 0.0, 0.03)),
            K(cc, hold_frame(s.reload_tilt, (0.0, 0.04, -0.056), yaw=-4.0, pitch=-13.0, roll=-6.0), slap(),
              kit.grip, blade=bl, ease="in"),
            K(cc + 4, look, slap().moved(v3(-0.01, 0.0, 0.025)).with_shape(hand_shape("relaxed")), kit.grip, blade=bl,
              ease="out")]
    if empty:
        ch_f = ev["charge"]
        ch_pt = m["charge"]

        def on_handle(back: float, shape="grip") -> Hand:
            return kit.left_w(ch_pt + v3(0.010, -CHARGE_TRAVEL * back, 0.012), (0.85, 0.35, -0.40),
                              (0.20, 0.10, -0.97), pole=(-0.5, -0.4, -0.75),
                              shape=hand_shape(shape, 0.8) if shape == "grip" else shape, share=0.75, off=0.012)
        keys += [K(ch_f - 9, look, on_handle(0.0), kit.grip, blade=bl, arc_l=(0.0, 0.0, 0.05)),
                 K(ch_f, look, on_handle(1.0), kit.grip, blade=bl, ease="snap"),
                 K(ch_f + 3, look, on_handle(1.0, "relaxed").moved(v3(-0.02, 0.0, 0.03)), kit.grip, blade=bl)]
    keys += [K(done, hip, kit.support, kit.grip, blade=bl, arc_l=(-0.04, 0.0, -0.03)),
             K(N, hip, kit.support, kit.grip, blade=bl, ease="settle")]
    ch = Choreo(keys)

    def fn(f: int) -> State:
        st = ch(f)
        st.extra["cover"] = cover_angle(f, ev)
        return st
    return fn


# =============================================================================================
# entry point
# =============================================================================================
def state_fns(sk: Skeleton, s: FPSet) -> dict:
    """``{clip: f -> State}`` for every clip of the set (errors name the set and its clip lengths). The gun
    ``bash`` (D2-04, ``_arms_melee.bash_fn``) is layered on the set's own idle for every gun set; the
    non-gun sets (melee, throwable, deployables) are ``_arms_items``."""
    try:
        if s.support in ("melee", "throw", "deploy"):
            from _arms_items import item_fns  # noqa: PLC0415 - imports this module
            return item_fns(sk, s)
        if "bash" not in s.clips:
            return _state_fns(sk, s)
        import dataclasses  # noqa: PLC0415

        from _arms_melee import bash_fn  # noqa: PLC0415 - imports this module
        out = _state_fns(sk, dataclasses.replace(s, clips={c: r for c, r in s.clips.items() if c != "bash"}))
        out["bash"] = bash_fn(sk, s, out["idle"], s.frames("bash"), s.ev("bash"))
        return out
    except ValueError as e:
        lengths = {c: s.frames(c) for c in s.clips}
        raise ValueError(f"{s.name} (clip frames {lengths}): {e}") from e


def _state_fns(sk: Skeleton, s: FPSet) -> dict:
    if s.support == "akimbo":
        from _arms_akimbo import akimbo_fns  # noqa: PLC0415 - imports this module
        return akimbo_fns(sk, s)
    if s.name in ("break_action", "launcher", "crossbow", "lever"):
        from _arms_breech import breech_fns  # noqa: PLC0415 - imports this module
        return breech_fns(sk, s)
    if s.name == "bow":
        from _arms_bow import bow_fns  # noqa: PLC0415 - imports this module
        return bow_fns(sk, s)
    if s.name in ("flamethrower", "saw", "minigun"):
        from _arms_heavy import heavy_fns  # noqa: PLC0415 - imports this module
        return heavy_fns(sk, s)
    kit = Kit(sk, s)
    out = {}
    for clip in s.clips:
        N = s.frames(clip)
        if clip == "idle":
            fn = clip_idle(kit, s, N)
        elif clip == "ads_idle":
            fn = clip_ads_idle(kit, s, N)
        elif clip == "sprint":
            fn = clip_sprint(kit, s, N)
        elif clip == "draw":
            fn = clip_draw(kit, s, N)
        elif clip == "holster":
            fn = clip_draw(kit, s, N, reverse=True)
        elif clip in ("fire", "fire_ads"):
            fn = clip_fire(kit, s, N, clip == "fire_ads")
        elif clip in ("fire_auto", "fire_auto_ads"):
            fn = clip_fire(kit, s, N, clip == "fire_auto_ads", PISTOL_AUTO_RECOIL)
        elif clip in ("bolt", "bolt_ads"):
            fn = clip_bolt(kit, s, N, clip == "bolt_ads")
        elif clip == "reload_start":
            fn = shells_start(kit, s, N)
        elif clip == "reload_loop":
            fn = shells_loop(kit, s, N)
        elif clip in ("reload_end", "reload_end_empty"):
            fn = shells_end(kit, s, N, clip == "reload_end_empty")
        elif clip in ("reload", "reload_empty") and s.reload == "shells":
            empty = clip == "reload_empty"
            parts = [(SHELL_START, shells_start(kit, s, SHELL_START))]
            parts += [(SHELL_LOOP, shells_loop(kit, s, SHELL_LOOP))] * SHOTGUN_SHELLS
            n_end = SHELL_END_EMPTY if empty else SHELL_END
            parts.append((n_end, shells_end(kit, s, n_end, empty)))
            fn = concat(parts)
        elif clip in ("reload", "reload_empty") and s.reload == "speedloader":
            from _arms_revolver import clip_speedloader  # noqa: PLC0415 - imports this module
            fn = clip_speedloader(kit, s, N, s.ev(clip))
        elif clip in ("reload", "reload_empty") and s.reload == "box":
            fn = clip_box_reload(kit, s, N, clip == "reload_empty")
        elif clip in ("reload", "reload_empty"):
            fn = clip_mag_reload(kit, s, N, clip == "reload_empty")
        else:
            raise ValueError(f"{s.name}: no builder for clip {clip}")
        out[clip] = fn
    return out


def fp_clips(sk: Skeleton, s: FPSet) -> dict[str, Clip]:
    solver = Solver(sk)
    out: dict[str, Clip] = {}
    for clip, fn in state_fns(sk, s).items():
        row = s.clips[clip]
        N, loop = int(row["frames"]), bool(row["loop"])

        def pose_fn(f: int, fn=fn):
            return realize(sk, solver, fn(f), s.sh)
        name = f"{s.name}_{clip}"
        out[name] = Clip(name, N, loop, pose_fn, 0.0, None, dict(row.get("events", {})), reach_fix=False)
    return out


_ = (I3, ryd, smooth)
