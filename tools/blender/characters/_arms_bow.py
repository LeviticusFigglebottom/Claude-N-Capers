"""Bow clips for ``rig_arms`` (D-055, B4-18: the Thorn compound bow). Private helper of
``_arms_clips``; pure numpy.

The bow is held in the LEFT hand. Its weapon frame (origin = the riser grip, Y = arrow direction,
Z = up along the riser) sits in ``hand.L`` at the mirrored grip offset (``_anim.grip_offset(sk,
"L")`` = SOURCE ``fp.offhand_grip``); the ``weapon`` bone carries that frame every frame, so relative to
``hand.R`` it moves in every bow clip (as in ``sniper_bolt``). The right hand holds the nocked arrow on
the string (fingers hooked under / over the nock) and draws it.

* ``Arrow`` (on ``Magwell``) rides the ``magazine`` bone: identity = nocked at brace height; drawn
  back with the string (``magazine`` = ``BOW_DRAW`` x draw along the weapon's back axis); carried
  by the right hand from the quiver during ``nock`` (visible from ``arrow_show``, on the string at
  ``nocked``). ENV A hides it at ``release`` (the projectile spawns).
* ``StringUpper`` / ``StringLower`` turn about their cam axles so the string's nock point sits
  ``BOW_BRACE + BOW_DRAW x draw`` behind the grip; ``draw`` (0 = brace, 1 = full draw) is listed per
  frame in SOURCE ``curve.bow_<clip>`` (it is also the ``magazine`` bone's back offset / BOW_DRAW
  while the arrow is nocked).

Clips: ``idle*`` (hip: bow low left, canted, arrow nocked), ``ads_idle*`` (bow raised to the
centre, not drawn), ``draw`` / ``holster``, ``draw_string`` (0.7 s from the raised hold to full
draw; its last frame == ``hold`` frame 0), ``hold*`` (full draw, slight tremble), ``release`` (the
shot: string snaps, the bow rolls forward in the open hand, follow-through; ends on the raised hold
with an empty string), ``nock`` (an arrow from the hip quiver onto the rest and the string),
``sprint*``. ``fire`` / ``fire_ads`` = ``release``; ``reload`` / ``reload_empty`` = ``nock``.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
from _anim import TAU, Skeleton, hand_shape, mslerp, rxd, ryd, rzd, smooth, unit, v3
from _arms_choreo import I3, Choreo, Hand, Key, State, as_cam, hand_at
from _arms_sets import BOW_BRACE, BOW_DRAW, BOW_NOCK_Z, FPSet

#: full draw: the nock point just below and right of the eye (camera space), the bow's yaw / pitch / roll
FULL_NOCK = v3(0.040, 0.030, -0.100)
FULL_ROT = (1.5, 3.5, 9.0)
BLADE_FULL = 62.0


def nock_point(d: float) -> np.ndarray:
    """String nock point (weapon space) at draw ``d`` (0 = brace, 1 = full)."""
    return v3(0.0, -BOW_BRACE - BOW_DRAW * d, BOW_NOCK_Z)


def full_frame(dp=(0.0, 0.0, 0.0), yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> tuple:
    """The full-draw bow frame: the nock at FULL_NOCK (+ ``dp``)."""
    R, _o = A.weapon_frame(v3(0.0, 0.0, 0.0), FULL_ROT[0] + yaw, FULL_ROT[1] + pitch, FULL_ROT[2] + roll)
    return R, FULL_NOCK + np.asarray(dp, float) - R @ nock_point(1.0)


class BowKit:
    def __init__(self, sk: Skeleton, s: FPSet) -> None:
        from _arms_clips import hold_frame, left_grip  # noqa: PLC0415

        self.sk, self.s = sk, s
        self.bow = left_grip(sk, v3(0.0, 0.0, 0.0), s.pole_l)
        self.bow_ads = left_grip(sk, v3(0.0, 0.0, 0.0), s.pole_l_ads)
        self.hip = hold_frame(s.hip)
        self.ads = hold_frame(s.ads_hold)
        self.full = full_frame()
        # the right hand off the string (sprint, draw / holster): low right, relaxed
        self.free_r = hand_at(sk, "R", "c", (0.17, 0.10, -0.52), (-0.15, 0.40, -0.90), (-0.95, 0.0, 0.25),
                              (0.5, -0.6, -0.4), "relaxed")

    def string(self, d: float, shape: str = "hook", pole=None) -> Hand:
        """Right fingers hooked on the string at draw ``d``: knuckles vertical, fingers pointing left
        around the string, pads facing back (weapon space)."""
        p = nock_point(d) + v3(0.010, 0.006, -0.004)
        shp = hand_shape("grip", 0.55) if shape == "hook" else hand_shape(shape)
        h = hand_at(self.sk, "R", "w", p, (-0.92, 0.22, -0.30), (-0.30, -0.95, 0.0),
                    pole if pole is not None else self.s.pole_r, shp, share=0.98, off=0.008)
        h.twist = 0.55
        return h

    def arrow_grip(self) -> Hand:
        """Right thumb and index pinching the arrow just ahead of the nock (arrow = magazine space)."""
        p = nock_point(0.0) + v3(0.008, 0.030, 0.010)
        return hand_at(self.sk, "R", "m", p, (-0.55, 0.65, 0.50), (-0.75, -0.10, -0.65), (0.6, -0.5, -0.6),
                       "pinch", share=0.92, off=0.010)


def drawn_mag(d: float) -> tuple:
    """The arrow (magazine bone) pulled back with the string."""
    return ("w", I3.copy(), v3(0.0, -BOW_DRAW * d, 0.0))


def _tremble(f: int, N: int, amp: float) -> tuple[np.ndarray, np.ndarray]:
    """Loop-safe full-draw tremble (zero at f = 0 and f = N): (rotation, offset)."""
    ph = f / N
    a = (0.22 * math.sin(TAU * 7 * ph) + 0.12 * math.sin(TAU * 13 * ph + 0.0) + 0.30 * math.sin(TAU * 2 * ph)) * amp
    b = (0.18 * math.sin(TAU * 9 * ph) + 0.10 * math.sin(TAU * 17 * ph) + 0.25 * math.sin(TAU * 3 * ph)) * amp
    return rzd(a) @ rxd(b), v3(0.0006 * math.sin(TAU * 11 * ph), 0.0, 0.0008 * math.sin(TAU * 5 * ph)) * amp


def bow_idle(bk: BowKit, N: int, ads: bool):
    from _arms_clips import _sway  # noqa: PLC0415

    s = bk.s
    wf = bk.ads if ads else bk.hip
    keys = [Key(0, wf, bk.bow_ads if ads else bk.bow, bk.string(0.0), blade=s.blade_ads if ads else s.blade)]
    return Choreo(keys, post=lambda f, st: (_sway(st, f, N, 0.6 if ads else 1.0), st.extra.update(draw=0.0)))


def bow_sprint(bk: BowKit, N: int):
    s = bk.s
    from _arms_clips import hold_frame  # noqa: PLC0415

    def post(f: int, st: State) -> None:
        ph = f / N
        bob = math.cos(TAU * 2 * ph)
        side = math.sin(TAU * ph)
        R, o = st.wf
        st.wf = (rzd(3.0 * side) @ R @ rxd(2.5 * bob) @ ryd(4.0 * side), o + v3(0.012 * side, 0.004 * bob, 0.014 * bob))
        sw = math.sin(TAU * ph + 0.3 + math.pi)
        st.R = st.R.moved(v3(-0.02 * sw, 0.10 * sw, 0.03 * abs(sw)))      # the free right arm pumps
        st.extra["draw"] = 0.0
        st.extra["arrow"] = True
    return Choreo([Key(0, hold_frame(s.sprint), bk.bow, bk.free_r, blade=s.blade * 0.5)], post=post)


def bow_draw(bk: BowKit, N: int, reverse: bool):
    from _arms_clips import hold_frame  # noqa: PLC0415

    s = bk.s
    lo, hi = hold_frame(s.lowered), bk.hip

    def post(f: int, st: State) -> None:
        u = f / N
        if reverse:
            u = 1.0 - u
        e = A.bezier1(u, 0.0, 1.08)
        st.wf = (mslerp(lo[0], hi[0], min(1.0, e)), lo[1] + (hi[1] - lo[1]) * e)
        j = smooth(0.35, 0.95, u)                      # the right hand finds the string late
        a, b = as_cam(bk.free_r, st.wf, st.wf), as_cam(bk.string(0.0), st.wf, st.wf)
        st.R = Hand("c", a.wrist + (b.wrist - a.wrist) * j, mslerp(a.axes, b.axes, j), unit(a.pole + (b.pole - a.pole) * j),
                    a.shape.blend(b.shape, j), 0.55)
        st.blade = s.blade * (0.5 + 0.5 * min(1.0, max(0.0, e)))
        st.extra["draw"] = 0.0
    return Choreo([Key(0, hi, bk.bow, bk.string(0.0), blade=s.blade)], post=post)


def draw_curve(u: float) -> float:
    """String draw 0..1 over the draw_string clip: a quick start, heavy through the cam peak, the
    let-off settling into the wall (exactly 1 on the last frame)."""
    return A.bezier1(u, 0.55, 1.0)


def bow_draw_string(bk: BowKit, N: int):
    s = bk.s
    full = bk.full

    def fn(f: int) -> State:
        u = f / N
        d = draw_curve(u)
        e = smooth(0.0, 1.0, min(1.0, u * 1.25))           # the bow arm pushes out ahead of the draw
        R = mslerp(bk.ads[0], full[0], e)
        o = bk.ads[1] + (full[1] - bk.ads[1]) * e
        # strain: a small lift and settle while passing the peak weight
        k = math.sin(math.pi * u) * 0.6
        R = R @ rxd(0.8 * k)
        st = State((R, o), bk.bow_ads.copy(), bk.string(d), drawn_mag(d),
                   s.blade_ads + (BLADE_FULL - s.blade_ads) * e, v3(0.0, 0.0, 0.0))
        st.extra["draw"] = d
        return st
    return fn


def bow_hold(bk: BowKit, N: int):
    full = bk.full

    def fn(f: int) -> State:
        Rt, dt = _tremble(f, N, 1.0)
        R, o = full
        st = State((Rt @ R, o + dt), bk.bow_ads.copy(), bk.string(1.0), drawn_mag(1.0), BLADE_FULL, v3(0.0, 0.0, 0.0))
        # the string hand shivers a touch less than the bow (anchored on the jaw)
        st.extra["draw"] = 1.0
        return st
    return fn


def bow_release(bk: BowKit, N: int):
    """frame 0 = full draw; the string snaps forward on frame 1, the right hand follows through
    back past the jaw and opens, the bow rolls forward in the open bow hand and comes back up."""
    s = bk.s
    full = bk.full
    fwd = full_frame((0.0, 0.020, -0.010), pitch=-7.0, roll=-3.0)
    open_l = bk.bow_ads.with_shape(hand_shape("relaxed"))
    thru = Hand("c", *_cam(bk, full, bk.string(1.0)), bk.string(1.0).pole, hand_shape("spread", 0.6), 0.55)
    thru.wrist = thru.wrist + v3(0.035, -0.035, 0.005)
    rest = bk.string(0.0, "relaxed")
    keys = [Key(0, full, bk.bow_ads, bk.string(1.0), blade=BLADE_FULL),
            Key(3, fwd, open_l, thru, blade=BLADE_FULL, ease="snap"),
            Key(7, full_frame((0.0, 0.010, -0.004), pitch=-2.0), bk.bow_ads, thru.moved(v3(0.0, -0.005, -0.01)),
                blade=BLADE_FULL),
            Key(N - 3, bk.ads, bk.bow_ads, rest, blade=s.blade_ads, ease="inout"),
            Key(N, bk.ads, bk.bow_ads, rest, blade=s.blade_ads, ease="settle")]
    ch = Choreo(keys)

    def fn(f: int) -> State:
        st = ch(f)
        st.mag = drawn_mag(1.0) if f == 0 else ("w", I3.copy(), np.zeros(3))
        # string: snaps through brace and vibrates out
        st.extra["draw"] = 1.0 if f == 0 else -0.06 * math.exp(-0.5 * (f - 1)) * math.cos(2.2 * (f - 1))
        st.extra["arrow"] = f == 0
        return st
    return fn


def _cam(bk: BowKit, wf: tuple, h: Hand) -> tuple:
    c = as_cam(h, wf, wf)
    return c.wrist, c.axes


def bow_nock(bk: BowKit, N: int, ev: dict):
    """From the hip hold: the right hand goes to the hip quiver (off screen, ``arrow_show``), brings
    an arrow up, lays it on the rest and snaps the nock onto the string (``nocked``)."""
    from _arms_clips import hold_frame  # noqa: PLC0415

    s = bk.s
    show, nk, done = ev["arrow_show"], ev["nocked"], ev["done"]
    hip = bk.hip
    tilt = hold_frame(s.reload_tilt)
    look = hold_frame(s.reload_tilt, (0.004, 0.0, 0.010), yaw=2.0, pitch=4.0, roll=6.0)
    quiver = hand_at(bk.sk, "R", "c", (0.19, 0.0, -0.56), (-0.10, 0.20, -0.97), (-0.95, -0.1, 0.2),
                     (0.5, -0.6, -0.4), "pinch", share=0.92)
    g = bk.arrow_grip()

    def mag_for(hc: Hand) -> tuple:
        Rm = hc.axes @ g.axes.T
        return ("c", Rm, hc.wrist - Rm @ g.wrist)
    up_c = hand_at(bk.sk, "R", "c", (0.04, 0.24, -0.24), (-0.30, 0.90, 0.20), (-0.75, -0.20, -0.60),
                   (0.6, -0.5, -0.6), "pinch", share=0.92)
    keys = [Key(0, hip, bk.bow, bk.string(0.0, "relaxed"), blade=s.blade),
            Key(5, tilt, bk.bow, bk.string(0.0, "relaxed").moved(v3(0.05, 0.02, -0.04)), blade=s.blade,
                arc_r=(0.03, 0.0, 0.0)),
            Key(show, tilt, bk.bow, g, mag=mag_for(quiver), blade=s.blade, arc_r=(0.06, -0.02, 0.0)),
            Key(show + 6, look, bk.bow, g, mag=mag_for(up_c), blade=s.blade, arc_r=(0.04, 0.0, -0.03)),
            # the shaft laid on the rest, the nock a little behind and above the string
            Key(nk - 4, look, bk.bow, g, mag=("w", rxd(3.0), v3(0.0, -0.045, 0.012)), blade=s.blade,
                arc_m=(0.02, 0.0, 0.02)),
            Key(nk, hold_frame(s.reload_tilt, (0.0, 0.004, 0.012), yaw=2.0, pitch=4.5, roll=6.0), bk.bow, g, mag=None,
                blade=s.blade, ease="snap"),
            Key(nk + 2, look, bk.bow, bk.string(0.0), blade=s.blade),
            Key(done, hip, bk.bow, bk.string(0.0), blade=s.blade),
            Key(N, hip, bk.bow, bk.string(0.0), blade=s.blade, ease="settle")]
    ch = Choreo(keys)

    def fn(f: int) -> State:
        st = ch(f)
        if f < show:
            st.mag = ("w", I3.copy(), np.zeros(3))
        st.extra["draw"] = 0.0
        st.extra["arrow"] = f >= show
        return st
    return fn


def bow_fns(sk: Skeleton, s: FPSet) -> dict:
    bk = BowKit(sk, s)
    out = {}
    for clip in s.clips:
        N = s.frames(clip)
        if clip in ("idle", "ads_idle"):
            fn = bow_idle(bk, N, clip == "ads_idle")
        elif clip == "sprint":
            fn = bow_sprint(bk, N)
        elif clip in ("draw", "holster"):
            fn = bow_draw(bk, N, clip == "holster")
        elif clip == "draw_string":
            fn = bow_draw_string(bk, N)
        elif clip == "hold":
            fn = bow_hold(bk, N)
        elif clip in ("release", "fire", "fire_ads"):
            fn = bow_release(bk, N)
        elif clip in ("nock", "reload", "reload_empty"):
            fn = bow_nock(bk, N, s.ev(clip))
        else:
            raise ValueError(f"bow: no builder for clip {clip}")
        out[clip] = fn
    return out
