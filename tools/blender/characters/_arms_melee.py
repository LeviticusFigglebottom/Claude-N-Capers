"""Melee for ``rig_arms`` (D2-04): the gun ``bash`` (PD2 quick melee with the weapon out) and the
melee-weapon sets ``melee_knife`` / ``melee_blunt`` / ``melee_blade`` / ``melee_heavy``. Private helper of ``_arms_clips``
/ ``_arms_items``; pure numpy.

Gun bash (every gun set, ``bash``): the set's own idle (frame 0) moved as one rigid block in camera space
about the grip: a short wind-up (pulled back, canted the other way), a snapped strike (``hit``) and a
recovery that ends exactly on idle frame 0 (``done`` = the last frame). Long guns shove the side of the
gun forward-left, pistols jab canted, heavy guns shove short and slow; akimbo bashes with the right
gun only. Both hands keep their grips (hands on the weapon stay on it).

Melee sets: the melee weapon rides the ``weapon`` bone, which carries the *item frame* (Blender
weapon axes: X right, Y = the edge / striking face, Z = up the handle toward the blade / head; origin
on the handle axis at the grip pivot, i.e. 20 mm below the top of the fist): the hammer-grip hand is
the weapon grip offset turned by the 18 deg grip rake (``item_hand``), so the bone is a fixed
rotation away from the gun grip under hand.R in every melee clip (Godot: the model is authored
upright, handle along +Y, edge toward -Z, origin at the grip pivot; attach it identity on the bone).
Clips: ``idle*``, ``sprint*``, ``draw`` (ready), ``holster`` (gone), ``swing`` (a tap: wind-up, strike
``hit``, recover; ``done`` = back at idle), ``charge_start`` (idle -> the wind-up, held; its length =
MeleeDef.charge_time_s, ``charged`` at the end), ``charge*`` (the held wind-up, trembling; frame 0 ==
charge_start's last frame) and ``charge_swing`` (from the held wind-up: ``hit``, recover to idle).

``melee_heavy`` (characters v1.38: sledgehammer, fire axe) is two-handed: the same clips and item frame, the right
hand at the item origin and the LEFT hand closed round the same handle ``HEAVY_LEFT_Z`` m further down (item
(0, 0, -0.28)), riding the weapon frame (``"w"``) in every clip, so it never lets go; overhead strikes through the
centre of the view, the head about ``HEAVY_HEAD_Z`` m up the handle.
"""

from __future__ import annotations

import dataclasses

import math

import numpy as np

import _anim as A
from _anim import TAU, Skeleton, hand_shape, rxd, ryd, rzd, smooth, unit, v3
from _arms_choreo import Choreo, Hand, Key, State, grip_hand, hand_at
from _arms_sets import FPSet, bash_family

# =============================================================================================
# gun bash
# =============================================================================================
#: family -> (strike offset (camera m), yaw, pitch, roll (deg)) at the hit; the wind-up is WIND x it
BASH_MOVE = {
    "long": (v3(-0.030, 0.075, 0.030), 18.0, -6.0, -32.0),
    "pistol": (v3(-0.030, 0.050, 0.030), 12.0, -15.0, -32.0),
    "bow": (v3(0.050, 0.020, 0.030), -18.0, -4.0, 24.0),
    "heavy": (v3(-0.020, 0.060, 0.025), 10.0, -4.0, -18.0),
}
BASH_WIND = -0.35


def bash_curve(f: int, N: int, hit: int) -> float:
    """0 at frame 0 -> BASH_WIND at the wind-up -> 1 at ``hit`` (snapped) -> held 2 f -> 0 at N."""
    w = max(1, round(hit * 0.55))
    if f <= 0 or f >= N:
        return 0.0
    if f <= w:
        return BASH_WIND * A.ease_out(f / w, 2.0)
    if f <= hit:
        t = (f - w) / max(1, hit - w)
        return BASH_WIND + (1.0 - BASH_WIND) * A.ease_in(t, 1.6)
    if f <= hit + 2:
        return 1.0
    return 1.0 - smooth(hit + 2, N, f)


def move_state(st: State, Rt: np.ndarray, tt: np.ndarray, pivot: np.ndarray, one_handed: bool = False) -> None:
    """Move the whole viewmodel state rigidly (camera space): the weapon frame, the camera-space hands
    (the left one only when ``one_handed`` is False) and the akimbo left gun."""
    def mv(p):
        return pivot + Rt @ (np.asarray(p, float) - pivot) + tt
    R, o = st.wf
    st.wf = (Rt @ R, mv(o))
    for attr in ("L", "R"):
        h: Hand = getattr(st, attr)
        if h.space != "c" or (one_handed and attr == "L"):
            continue
        h = h.copy()
        h.wrist = mv(h.wrist)
        h.axes = Rt @ h.axes
        h.pole = Rt @ h.pole
        setattr(st, attr, h)
    if not one_handed:
        for k in ("wf_l", "mag_l"):
            if k in st.extra:
                Rl, ol = st.extra[k]
                st.extra[k] = (Rt @ Rl, mv(ol))
    if st.mag[0] == "c":
        st.mag = ("c", Rt @ st.mag[1], mv(st.mag[2]))


def bash_fn(sk: Skeleton, s: FPSet, idle_fn, N: int, ev: dict):
    """``bash`` for a gun set from its idle (frame 0)."""
    off, yaw, pitch, roll = BASH_MOVE[bash_family(s.name)]
    hit = ev["hit"]
    one = s.support == "akimbo"

    def fn(f: int) -> State:
        st = idle_fn(0)
        u = bash_curve(f, N, hit)
        if u != 0.0:
            Rt = rzd(yaw * u) @ rxd(pitch * u) @ ryd(roll * u)
            move_state(st, Rt, off * u, st.wf[1].copy(), one)
            st.blade = st.blade + 6.0 * max(0.0, u)          # the shoulder drives the strike
        st.extra["bash"] = u
        return st
    return fn


# =============================================================================================
# melee weapons
# =============================================================================================
def item_frame(pos, blade, edge) -> tuple[np.ndarray, np.ndarray]:
    """Camera-space item frame from the blade (handle -> tip) and edge directions."""
    z = unit(np.asarray(blade, float))
    y = np.asarray(edge, float)
    y = unit(y - z * float(y @ z))
    return np.column_stack([np.cross(y, z), y, z]), np.asarray(pos, float).copy()


#: melee_heavy: the left hand's grip pivot on the handle (item z, m below the right hand) and the head (item z)
HEAVY_LEFT_Z = -0.28
HEAVY_HEAD_Z = 0.55


def item_hand_left(sk: Skeleton, d=(0.0, 0.0, HEAVY_LEFT_Z), pole=(-0.6, -0.4, -0.7)) -> Hand:
    """The LEFT hand closed round the same handle (item Z) as ``item_hand``, its grip pivot ``d`` (item space),
    thumb toward the head: the left hand's weapon-grip offset (``_anim.grip_offset``) turned by the grip rake."""
    R_off, t_off = A.grip_offset(sk, "L")
    axes = R_off.T.copy()
    Q = rxd(A.GRIP_RAKE_DEG)
    shp = dataclasses.replace(hand_shape("grip", 1.0), thumb=MELEE_THUMB, thumb_opp=MELEE_THUMB_OPP)
    return Hand("w", np.asarray(d, float) + Q @ (-axes @ t_off), Q @ axes, unit(np.asarray(pole, float)), shp, 0.6)


def item_hand(sk: Skeleton, shape: str = "grip", amount: float = 1.0, d=(0.0, 0.0, 0.0), pole=(0.7, -0.3, -0.65)) -> Hand:
    """The right hand closed round a handle running along the item frame's Z (the weapon grip offset
    turned by the grip rake), the grip pivot ``d`` (item space) from the item origin."""
    g = grip_hand(sk, pole=pole, shape=hand_shape(shape, amount))
    Q = rxd(A.GRIP_RAKE_DEG)
    return Hand("w", np.asarray(d, float) + Q @ g.wrist, Q @ g.axes, g.pole, g.shape, 0.6)


#: per kind: key poses (camera-space position, blade direction, edge direction)
MELEE_POSES = {
    "melee_knife": {
        "idle": ((0.140, 0.320, -0.170), (-0.30, 0.55, 0.78), (0.10, 0.80, -0.55)),
        "sprint": ((0.165, 0.240, -0.255), (-0.15, 0.75, 0.62), (0.05, 0.62, -0.78)),
        "low": ((0.170, 0.120, -0.500), (0.10, 0.95, 0.25), (0.0, 0.25, -0.95)),
        "wind": ((0.250, 0.270, -0.120), (0.55, 0.10, 0.83), (-0.70, 0.55, -0.20)),
        # D-116 FP audit: the hit higher and the blade across the view (it pointed away and hid behind the fist),
        # the follow-through ends at the lower left edge instead of 40 deg below the eye (out of frame)
        "hit": ((0.040, 0.350, -0.145), (-0.80, 0.55, 0.20), (-0.55, -0.40, -0.70)),
        "follow": ((-0.100, 0.330, -0.150), (-0.75, 0.55, -0.35), (-0.45, -0.60, 0.65)),
        "charged": ((0.230, 0.260, -0.090), (0.35, -0.10, 0.93), (-0.30, 0.90, 0.10)),
        "c_hit": ((0.050, 0.380, -0.140), (-0.10, 0.99, 0.05), (0.0, 0.10, -0.99)),
        "c_follow": ((0.020, 0.360, -0.200), (-0.15, 0.95, -0.25), (0.0, 0.25, -0.97)),
    },
    "melee_blunt": {
        "idle": ((0.150, 0.310, -0.190), (-0.25, 0.45, 0.86), (0.05, 0.88, -0.45)),
        "sprint": ((0.175, 0.230, -0.270), (-0.10, 0.35, 0.93), (0.0, 0.93, -0.35)),
        "low": ((0.170, 0.120, -0.520), (0.10, 0.70, 0.70), (0.0, 0.70, -0.70)),
        "wind": ((0.210, 0.090, 0.010), (0.15, -0.65, 0.75), (0.0, 0.75, 0.65)),
        # D-116 FP audit: hit and follow-through in frame (they were 33 / 44 deg below the eye; the frame edge is 26)
        "hit": ((0.090, 0.360, -0.150), (-0.10, 0.75, -0.65), (0.0, -0.65, -0.75)),
        "follow": ((0.050, 0.325, -0.160), (-0.10, 0.25, -0.96), (0.0, -0.96, -0.25)),
        "charged": ((0.215, 0.070, 0.030), (0.18, -0.75, 0.64), (0.0, 0.64, 0.75)),
        "c_hit": ((0.085, 0.330, -0.150), (-0.08, 0.70, -0.70), (0.0, -0.70, -0.70)),
        "c_follow": ((0.050, 0.320, -0.160), (-0.08, 0.20, -0.97), (0.0, -0.97, -0.20)),
    },
    "melee_blade": {
        "idle": ((0.150, 0.315, -0.180), (-0.35, 0.55, 0.75), (0.10, 0.82, -0.56)),
        "sprint": ((0.170, 0.240, -0.265), (-0.15, 0.55, 0.82), (0.0, 0.82, -0.55)),
        "low": ((0.170, 0.120, -0.510), (0.10, 0.90, 0.40), (0.0, 0.40, -0.90)),
        "wind": ((0.260, 0.160, -0.100), (0.85, -0.20, 0.48), (-0.40, 0.25, 0.88)),
        "hit": ((0.060, 0.330, -0.150), (-0.30, 0.95, -0.05), (-0.95, -0.30, 0.0)),
        # D-116 FP audit: the follow-throughs end at the lower left edge, in frame (they were 44 deg below the eye)
        "follow": ((-0.060, 0.265, -0.125), (-0.95, -0.15, -0.25), (0.15, -0.99, 0.0)),
        "charged": ((0.265, 0.130, -0.080), (0.80, -0.35, 0.50), (-0.45, 0.20, 0.87)),
        "c_hit": ((0.060, 0.330, -0.150), (-0.25, 0.97, -0.05), (-0.97, -0.25, 0.0)),
        "c_follow": ((-0.060, 0.265, -0.125), (-0.95, -0.20, -0.25), (0.20, -0.98, 0.0)),
    },
    # characters v1.38 two-handed (sledgehammer, fire axe): the right hand at the item origin, the left on the
    # handle 0.28 m below it; the head (item z 0.55) over the right shoulder at rest, overhead strikes down through
    # the centre of the view
    "melee_heavy": {
        "idle": ((0.050, 0.392, -0.100), (0.622, 0.628, 0.467), (0.10, 0.99, 0.05)),
        "sprint": ((0.050, 0.399, -0.150), (0.679, 0.607, 0.413), (0.0, 1.0, 0.0)),
        "low": ((0.150, 0.220, -0.480), (0.30, 0.60, 0.74), (0.0, 0.75, -0.60)),
        "wind": ((0.180, 0.200, -0.040), (0.30, -0.60, 0.74), (0.05, 0.78, 0.62)),
        "hit": ((0.200, 0.286, -0.200), (-0.508, 0.857, -0.084), (0.043, -0.072, -0.996)),
        "follow": ((0.100, 0.204, -0.150), (-0.696, 0.683, -0.219), (0.156, -0.154, -0.976)),
        "charged": ((0.150, 0.170, 0.070), (0.10, -0.70, 0.71), (0.0, 0.71, 0.70)),
        "c_hit": ((0.200, 0.286, -0.200), (-0.508, 0.857, -0.084), (0.043, -0.072, -0.996)),
        "c_follow": ((0.100, 0.204, -0.150), (-0.696, 0.683, -0.219), (0.156, -0.154, -0.976)),
    },
}


#: the melee fist's thumb (curls, opposition; deg): over the index / middle fingers, tip ~16 mm from them
MELEE_THUMB, MELEE_THUMB_OPP = (-10.0, -14.0, -12.0), 50.0


class MeleeKit:
    def __init__(self, sk: Skeleton, s: FPSet) -> None:
        self.sk, self.s = sk, s
        self.P = MELEE_POSES[s.name]
        self.grip = item_hand(sk)
        # D-116 FP audit: the thumb wraps over the index and middle fingers. With the gun grip's thumb it stuck out
        # straight, 72 mm off the handle, and read as a pointing finger.
        self.grip = dataclasses.replace(self.grip, shape=dataclasses.replace(self.grip.shape, thumb=MELEE_THUMB,
                                                                       thumb_opp=MELEE_THUMB_OPP))
        # the free left hand: low left guard (off screen at rest), raised a little for the strikes
        self.down = hand_at(sk, "L", "c", (-0.20, 0.06, -0.58), (0.15, 0.40, -0.90), (0.95, 0.0, 0.25),
                            (-0.5, -0.6, -0.4), hand_shape("loose_fist", 0.8))
        self.guard = hand_at(sk, "L", "c", (-0.17, 0.20, -0.40), (0.30, 0.65, -0.70), (0.90, -0.10, 0.40),
                             (-0.6, -0.5, -0.6), hand_shape("loose_fist", 0.9))
        self.two_handed = s.name == "melee_heavy"
        if self.two_handed:   # v1.38: the left hand rides the handle in every clip (weapon space), never free
            self.down = self.guard = item_hand_left(sk)

    def wf(self, key: str, dp=(0.0, 0.0, 0.0)) -> tuple:
        p, b, e = self.P[key]
        return item_frame(np.asarray(p, float) + np.asarray(dp, float), b, e)

    def key(self, f: int, pose: str, left: Hand | None = None, ease: str = "inout", blade: float = 0.0,
            dp=(0.0, 0.0, 0.0), arc=(0.0, 0.0, 0.0)) -> Key:
        return Key(int(f), self.wf(pose, dp), left if left is not None else self.down, self.grip, ease=ease,
                   blade=blade, arc_r=arc)


def _breathe(st: State, f: int, N: int, amp: float = 1.0) -> None:
    ph = f / N
    b = math.sin(TAU * ph * 2.0)
    w = math.sin(TAU * ph + 0.6)
    R, o = st.wf
    st.wf = (rzd(0.6 * w * amp) @ rxd(0.6 * b * amp) @ R, o + v3(0.003 * w, 0.0, 0.004 * b) * amp)


def _tremble(st: State, f: int, N: int, amp: float = 1.0) -> None:
    """Loop-safe strain tremble (whole periods per loop)."""
    ph = f / N
    a = 0.6 * math.sin(TAU * 5 * ph) + 0.35 * math.sin(TAU * 9 * ph + 0.7) + 0.5 * math.sin(TAU * ph)
    b = 0.5 * math.sin(TAU * 7 * ph + 0.3) + 0.3 * math.sin(TAU * 11 * ph) + 0.4 * math.sin(TAU * 2 * ph)
    R, o = st.wf
    st.wf = (rzd(0.5 * a * amp) @ rxd(0.6 * b * amp) @ R, o + v3(0.0012 * a, -0.0010 * b, 0.0012 * b) * amp)


def melee_fns(sk: Skeleton, s: FPSet) -> dict:
    mk = MeleeKit(sk, s)
    out = {}
    for clip in s.clips:
        N = s.frames(clip)
        ev = s.ev(clip)
        if clip == "idle":
            fn = Choreo([mk.key(0, "idle")], post=lambda f, st, N=N: _breathe(st, f, N))
        elif clip == "sprint":
            def post(f: int, st: State, N=N) -> None:
                ph = f / N
                bob = math.cos(TAU * 2 * ph)
                side = math.sin(TAU * ph)
                R, o = st.wf
                st.wf = (rzd(4.0 * side) @ R @ rxd(4.0 * bob), o + v3(0.014 * side, 0.006 * bob, 0.016 * bob))
                if not mk.two_handed:
                    sw = math.sin(TAU * ph + 0.3 + math.pi)
                    st.L = st.L.moved(v3(0.02 * sw, 0.10 * sw, 0.03 * abs(sw)))   # the free arm pumps
            fn = Choreo([mk.key(0, "sprint", mk.down)], post=post)
        elif clip in ("draw", "holster"):
            a, b = ("low", "idle") if clip == "draw" else ("idle", "low")
            fn = Choreo([mk.key(0, a), mk.key(N, b, ease="settle" if clip == "draw" else "in",
                                              arc=(0.03, 0.0, -0.02))])
        elif clip == "swing":
            hit = ev["hit"]
            w = max(2, round(hit * 0.55))
            fn = Choreo([mk.key(0, "idle"),
                         mk.key(w, "wind", mk.guard, ease="out", blade=-6.0, arc=(0.02, -0.02, 0.03)),
                         mk.key(hit, "hit", mk.guard, ease="in", blade=8.0, arc=(0.0, 0.0, 0.03)),
                         mk.key(hit + 3, "follow", mk.guard, ease="out", blade=10.0),
                         mk.key(N, "idle", ease="settle", arc=(0.03, -0.04, -0.06))])
        elif clip == "charge_start":
            w = max(3, round(N * 0.45))
            fn = Choreo([mk.key(0, "idle"),
                         mk.key(w, "wind", mk.guard, ease="inout", blade=-6.0, arc=(0.02, -0.02, 0.03)),
                         mk.key(N, "charged", mk.guard, ease="settle", blade=-8.0)])
        elif clip == "charge":
            fn = Choreo([mk.key(0, "charged", mk.guard, blade=-8.0)], post=lambda f, st, N=N: _tremble(st, f, N))
        elif clip == "charge_swing":
            hit = ev["hit"]
            fn = Choreo([mk.key(0, "charged", mk.guard, blade=-8.0),
                         mk.key(hit, "c_hit", mk.guard, ease="in", blade=12.0, arc=(0.0, 0.0, 0.03)),
                         mk.key(hit + 4, "c_follow", mk.guard, ease="out", blade=12.0),
                         mk.key(N, "idle", ease="settle", arc=(0.03, -0.04, -0.06))])
        else:
            raise ValueError(f"{s.name}: no builder for clip {clip}")
        out[clip] = fn
    return out


_ = (A, Hand, ryd, smooth)
