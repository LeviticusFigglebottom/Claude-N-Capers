"""Akimbo clips for ``rig_arms`` (D-050, B4-12). Private helper of ``_arms_clips``; pure numpy.

Two pistols, one per hand. The right gun rides the ``weapon`` bone exactly like the single pistol;
the left gun has no bone: ENV A attaches the second WeaponVisual to ``hand.L`` at the mirrored grip
offset (``_anim.grip_offset(sk, "L")``, SOURCE.txt ``fp.offhand_grip``), so the left hand *is* the
left gun and the clips only have to place ``hand.L`` exactly there.

Authoring: each side is a right-handed ``Choreo`` (weapon frame + the grip hand); the left side is
the mirror image (x -> -x) of its own right-handed choreography, so every clip is written once and
played on two timelines (``fire`` kicks the right gun, ``fire_l`` the left one; the reload events
of the left gun trail the right one by a couple of frames). Camera-space motions that must move both
guns the same way (sprint sway, idle drift) run the left timeline half a cycle out of phase so the
mirror cancels.

PD2 akimbo: hip = both guns forward at either side of the view, canted a little inward; ADS raises
both guns closer together (no sight alignment, the crosshair stays between them). Reload: both guns
tilt inward, both magazines drop, the guns dip below the view to take fresh magazines and come back
(``mag_in_r`` / ``mag_in_l`` happen off screen); ``reload_empty`` adds a thumb slide release per
gun. The right magazine falls on the ``magazine`` bone and is re-seated while the gun is off screen;
the left gun's magazine has no bone (ENV A hides it, or drops a physics copy, at ``mag_out_l`` and
shows it at ``mag_in_l``).
"""

from __future__ import annotations

import dataclasses
import math

import numpy as np

import _anim as A
from _anim import FPS, TAU, Skeleton, hand_shape, mslerp, rxd, ryd, rzd, v3
from _arms_choreo import Choreo, Hand, Key, State, as_cam, grip_hand, hand_at, mag_cam
from _arms_sets import FPSet

MIRROR = np.diag([-1.0, 1.0, 1.0])
#: hand.L bone axes = MIRROR @ hand.R bone axes @ FLIP (``_rig`` builds the left side as the mirror)
FLIP = np.diag([-1.0, 1.0, 1.0])


def mirror_frame(wf: tuple) -> tuple[np.ndarray, np.ndarray]:
    """The mirror image (x -> -x) of a camera-space weapon frame: a proper rotation of the same gun."""
    R, o = wf
    return MIRROR @ R @ MIRROR, MIRROR @ np.asarray(o, float)


def mirror_hand(h: Hand) -> Hand:
    """A camera-space right hand mirrored onto the left side (wrist, bone axes, elbow pole)."""
    if h.space != "c":
        raise ValueError("mirror_hand needs a camera-space hand")
    return Hand("c", MIRROR @ h.wrist, MIRROR @ h.axes @ FLIP, MIRROR @ h.pole, h.shape, h.twist)


#: D-116 (P r225 review): the reload dip. The guns used to drop to ``lowered``, fully below the frame, for
#: ~1 s. PD2's akimbo reload dips but stays partly in view, so the slide tops and the hands stay in the lower
#: third while the magwells (the fresh magazines) are below the frame edge. Same form as ``FPSet.hip``.
RELOAD_DIP = ((0.14, 0.32, -0.19), 8.0, 8.0, -28.0)
#: the seat: the gun pushed up (m) onto the fresh magazine below the frame edge at ``mag_in_<sfx>``
RELOAD_SEAT_M = 0.015


def hold(spec: tuple, dp=(0.0, 0.0, 0.0), yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0):
    p, y0, p0, r0 = spec
    return A.weapon_frame(np.array(p, float) + np.array(dp, float), y0 + yaw, p0 + pitch, r0 + roll)


class Side:
    """The right-handed vocabulary both timelines use."""

    def __init__(self, sk: Skeleton, s: FPSet) -> None:
        self.sk, self.s = sk, s
        self.grip = grip_hand(sk, pole=s.pole_r)
        # D-116 (PO 2026-10-16): the thumb along the frame's left side, not standing off it (_arms_sets.AKIMBO_THUMB)
        self.grip = self.grip.with_shape(dataclasses.replace(hand_shape("trigger"), thumb=tuple(s.grip_thumb[:3]),
                                                             thumb_opp=s.grip_thumb[3]))
        # placeholder left hand of a one-gun timeline (never solved; the mirror replaces it)
        self.idle_l = hand_at(sk, "L", "c", (-0.20, 0.03, -0.60), (0.15, 0.35, -0.92), (0.95, 0.0, 0.25),
                              (-0.5, -0.6, -0.4), "relaxed")
        self.hip = hold(s.hip)
        self.ads = hold(s.ads_hold)

    def key(self, f: int, wf, mag=None, ease: str = "inout", shape: str | None = None, **kw) -> Key:
        g = self.grip if shape is None else self.grip.with_shape(hand_shape(shape))
        return Key(int(f), wf, self.idle_l, g, mag=mag, ease=ease, **kw)


def _phase(f: int, N: int, left: bool, shift: float) -> float:
    return ((f / N) + (shift if left else 0.0)) % 1.0


# =============================================================================================
# per-side timelines (right-handed; ``left`` = this timeline will be mirrored)
# =============================================================================================
def side_idle(sd: Side, N: int, left: bool, ads: bool):
    wf = sd.ads if ads else sd.hip
    # the breathing (2 per loop) stays in phase; the slow weight shift runs mirrored half a cycle
    # out (sin(x + pi) = -sin(x): after the mirror both guns drift the same way)
    def post(f: int, st: State) -> None:
        ph = f / N
        b = math.sin(TAU * ph * 2.0)
        w = math.sin(TAU * ph + 0.6) * (-1.0 if left else 1.0)
        amp = 0.6 if ads else 1.0
        R, o = st.wf
        if ads:
            st.wf = (rxd(0.12 * b * amp) @ rzd(0.10 * w * amp) @ R, o + v3(0.0006 * w, 0.0, 0.0010 * b) * amp)
        else:
            st.wf = (rzd(0.5 * w * amp) @ rxd(0.45 * b * amp) @ R @ ryd(0.4 * w * amp),
                     o + v3(0.003 * w, 0.0, 0.0035 * b) * amp)
    return Choreo([sd.key(0, wf)], post=post)


def side_sprint(sd: Side, N: int, left: bool):
    def post(f: int, st: State) -> None:
        ph = _phase(f, N, left, 0.5)
        bob = math.cos(TAU * 2 * ph)
        side = math.sin(TAU * ph)
        R, o = st.wf
        st.wf = (rzd(3.0 * side) @ R @ rxd(2.5 * bob) @ ryd(4.0 * side),
                 o + v3(0.012 * side, 0.004 * bob, 0.014 * bob))
    return Choreo([sd.key(0, hold(sd.s.sprint), shape="trigger")], post=post)


def side_draw(sd: Side, N: int, reverse: bool):
    lo, hi = hold(sd.s.lowered), sd.hip

    def post(f: int, st: State) -> None:
        u = f / N
        if reverse:
            u = 1.0 - u
        e = A.bezier1(u, 0.0, 1.08)
        st.wf = (mslerp(lo[0], hi[0], min(1.0, e)), lo[1] + (hi[1] - lo[1]) * e)
    return Choreo([sd.key(0, hi)], post=post)


def kick3(f: int, N: int) -> float:
    """Akimbo kick envelope: peak on frame 1, back at rest on frame N (3 f < one shot interval)."""
    if f <= 0 or f >= N:
        return 0.0
    return [0.0, 1.0, 0.28][f] if N == 3 else math.exp(-2.2 * (f - 1)) * (1.0 - f / N)


def apply_recoil(st: State, rec: dict, k: float) -> None:
    R, o = st.wf
    st.wf = (R @ rxd(rec["pitch"] * k) @ ryd(rec["roll"] * k) @ rzd(rec.get("yaw", 0.0) * k),
             o + R @ v3(0.0, -rec["back"] * k, rec["up"] * k))


def side_fire(sd: Side, N: int, ads: bool, active: bool):
    rec = sd.s.recoil_ads if ads else sd.s.recoil
    wf = sd.ads if ads else sd.hip

    def post(f: int, st: State) -> None:
        if active:
            apply_recoil(st, rec, kick3(f, N))
    return Choreo([sd.key(0, wf)], post=post)


# -- reload ------------------------------------------------------------------------------------
def _mag_fall(sd: Side, wf0: tuple, t: float) -> tuple:
    """The magazine ``t`` s after release from a gun at ``wf0`` (camera space, falling + tumbling)."""
    m = sd.s.markers
    R, o = wf0
    ax = R @ m["magwell_axis"]
    p = o - ax * 0.30 * t + R @ v3(0.06 * t, 0.0, 0.0) + v3(0.0, 0.0, -0.5 * 9.81 * t * t)
    return ("c", R @ rxd(-70.0 * t) @ ryd(-40.0 * t), p)


def side_reload(sd: Side, N: int, ev: dict, sfx: str, empty: bool):
    """One gun's reload: tilt in, drop the magazine (``mag_out_<sfx>``), dip below the view, take a
    fresh one (``mag_in_<sfx>``, off screen), come back up (+ slide release on ``reload_empty``)."""
    s = sd.s
    mo, mi, done = ev[f"mag_out_{sfx}"], ev[f"mag_in_{sfx}"], ev["done"]
    hip = sd.hip
    tilt = hold(s.reload_tilt)
    jolt = hold(s.reload_tilt, (0.0, 0.004, 0.006), pitch=2.0, roll=-3.0)        # thumb on the release
    look = hold(s.reload_tilt, (-0.004, 0.0, -0.012), pitch=-6.0, roll=4.0)   # watching the mag fall
    low = hold(RELOAD_DIP)                                                   # the dip: tops still in view
    seat = hold(RELOAD_DIP, (0.0, 0.0, RELOAD_SEAT_M), pitch=2.0)             # pushed up onto the fresh mag
    t_in = max(3, mo - 7)
    keys = [sd.key(0, hip),
            sd.key(t_in, tilt),
            sd.key(mo, jolt, ease="snap"),
            sd.key(mo + 4, look),
            sd.key(mo + 9, look, ease="inout"),
            sd.key(mi - 5, low, ease="in"),
            sd.key(mi, seat, ease="snap"),
            sd.key(mi + 3, low)]
    if empty:
        rel = ev[f"slide_release_{sfx}"]
        rack = hold(s.reload_tilt, (0.01, 0.0, -0.01), yaw=-4.0, pitch=4.0, roll=22.0)
        keys += [sd.key(rel - 7, rack, ease="out"),
                 sd.key(rel - 1, rack, shape="support"),          # thumb reaching the slide stop
                 sd.key(rel, hold(s.reload_tilt, (0.01, 0.010, -0.006), yaw=-4.0, pitch=6.5, roll=21.0),
                        ease="snap", shape="support"),
                 sd.key(rel + 4, rack)]
    keys += [sd.key(done, hip),
             sd.key(N, hip, ease="settle")]
    ch = Choreo(keys)
    cache: dict = {}

    def fn(f: int) -> State:
        st = ch(f)
        if mo < f < mi - 2:                       # falling; re-seated (fresh) while off screen
            if "wf" not in cache:
                cache["wf"] = ch(mo).wf
            st.mag = _mag_fall(sd, cache["wf"], (f - mo) / FPS)
        return st
    return fn


# =============================================================================================
# both guns
# =============================================================================================
def combine(sd: Side, right: State, left: State) -> State:
    """The two-gun state: the right timeline as is, the left hand = the mirrored right hand of the
    left timeline (so the left gun sits at the mirrored grip offset)."""
    mag_l = mag_cam(left.wf, left.mag)
    hand_l = mirror_hand(as_cam(left.R, left.wf, mag_l))
    st = State(right.wf, hand_l, right.R, right.mag, 0.0, v3(0.0, 0.0, 0.0))
    st.extra.update(right.extra)
    st.extra["wf_l"] = mirror_frame(left.wf)
    st.extra["mag_l"] = mirror_frame(mag_l)
    return st


def pair(sd: Side, fr, fl):
    def fn(f: int) -> State:
        return combine(sd, fr(f), fl(f))
    return fn


def akimbo_fns(sk: Skeleton, s: FPSet) -> dict:
    """``{clip: f -> State}`` for the akimbo set (each gun's reload / draw / holster timeline with the D-116
    secondary-motion layer before the two are combined)."""
    import _arms_organic as organic  # noqa: PLC0415

    sd = Side(sk, s)
    out = {}
    for clip in s.clips:
        N = s.frames(clip)
        if clip in ("idle", "ads_idle"):
            ads = clip == "ads_idle"
            out[clip] = pair(sd, side_idle(sd, N, False, ads), side_idle(sd, N, True, ads))
        elif clip == "sprint":
            out[clip] = pair(sd, side_sprint(sd, N, False), side_sprint(sd, N, True))
        elif clip in ("draw", "holster"):
            ch = organic.wrap(s, clip, side_draw(sd, N, clip == "holster"))
            out[clip] = pair(sd, ch, ch)
        elif clip in ("fire", "fire_ads", "fire_l", "fire_ads_l"):
            ads = clip.startswith("fire_ads")
            left = clip.endswith("_l")
            out[clip] = pair(sd, side_fire(sd, N, ads, not left), side_fire(sd, N, ads, left))
        elif clip in ("reload", "reload_empty"):
            ev = s.ev(clip)
            empty = clip == "reload_empty"
            out[clip] = pair(sd, organic.wrap(s, clip, side_reload(sd, N, ev, "r", empty)),
                             organic.wrap(s, clip, side_reload(sd, N, ev, "l", empty)))
        else:
            raise ValueError(f"akimbo: no builder for clip {clip}")
    return out

