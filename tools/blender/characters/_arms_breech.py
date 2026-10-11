"""Break-open, crossbow and lever-action clips for ``rig_arms`` (D-055, B4-18). Private helper of
``_arms_clips``; pure numpy.

The idle / ads_idle / sprint / draw / holster clips are the generic long-gun builders of
``_arms_clips`` (right hand on the grip, left hand on the fore-end). Per mechanism:

* ``break_action`` (double barrel) / ``launcher`` (single-shot 40 mm): fire / fire_ads = recoil only
  (one barrel per click). ``reload`` (= ``reload_empty``): the thumb pushes the top lever and the gun is
  flicked muzzle-down so the ``Breech`` (barrels + fore-end, pivot at the hinge pin) drops open
  (``breech_open``; the left hand rides the fore-end), a small upward flick throws the empties out
  (``eject``), the left hand takes rounds from the belt (off screen) and thumbs them into the chambers
  (``shell_in_1`` / ``shell_in_2``, or ``round_in``), then lifts the fore-end and the gun snaps shut
  (``breech_close``).
* ``crossbow``: fire = recoil + ``string_release``. ``reload`` (= ``reload_empty``): muzzle raised, the
  left hand hooks the ``String`` (``cock``) and pulls it back to the latch (``string_back``), takes a
  bolt from the quiver (``bolt_show``, off screen; the bolt rides the ``magazine`` bone in the hand) and
  lays it on the rail (``bolt_in``).
* ``lever``: the lever cycle is part of fire / fire_ads (``lever_open`` / ``lever_close``, like the pump):
  the fingers in the loop throw the ``Lever`` down and the right hand turns with it
  (``LEVER_HAND_FOLLOW``), so the ``weapon`` bone moves relative to ``hand.R`` during the cycle (the
  sniper-bolt precedent). Shell-by-shell through the right-side loading gate: ``reload_start`` (the
  gun rolls left so the gate faces up), n x ``reload_loop`` (one round, ``round_in``, seamless),
  ``reload_end`` / ``reload_end_empty`` (adds a lever cycle); ``reload`` / ``reload_empty`` are the pieces
  composed for the data's tube (previews; D-053).
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
from _anim import FPS, Skeleton, hand_shape, rxd, smooth, unit, v3
from _arms_choreo import I3, Choreo, Hand, Key, State, as_cam, hand_cam, mag_cam
from _arms_sets import (BREAK_OPEN_DEG, LAUNCHER_OPEN_DEG, LEVER_HAND_FOLLOW, LEVER_OPEN_DEG, STRING_TRAVEL, FPSet,
                        lever_pieces)

SHELL_LEN = {"break_action": 0.068, "launcher": 0.100}


def open_deg(s: FPSet) -> float:
    return LAUNCHER_OPEN_DEG if s.name == "launcher" else BREAK_OPEN_DEG


# =============================================================================================
# break-open
# =============================================================================================
def breech_angle(f: int, ev: dict) -> float:
    """``Breech`` opening 0..1 from breech_open (drops over bo-2..bo+1) / breech_close (bc-3..bc)."""
    op, cl = ev["breech_open"], ev["breech_close"]
    if f <= op - 2 or f >= cl:
        return 0.0
    if f <= op + 1:
        return A.ease_in(smooth(op - 2, op + 1, f), 1.3) if f < op + 1 else 1.0
    if f <= cl - 3:
        # the barrels bounce a little on the hinge stop after dropping
        return 1.0 - 0.06 * max(0.0, A.spring((f - op - 1) / FPS, 7.0, 0.35)) * (1.0 if f < op + 5 else 0.0)
    return 1.0 - A.ease_in(smooth(cl - 3, cl, f), 1.6)


def breech_rot(s: FPSet, a: float) -> np.ndarray:
    return rxd(-open_deg(s) * a)


def breech_point(s: FPSet, a: float, p) -> np.ndarray:
    h = s.markers["hinge"]
    return h + breech_rot(s, a) @ (np.asarray(p, float) - h)


def on_breech(s: FPSet, h: Hand, a: float) -> Hand:
    """A weapon-space hand riding the Breech opened ``a``."""
    return h.turned(breech_rot(s, a), s.markers["hinge"])


def _shell_hand(kit, s: FPSet, wf: tuple, k: int, a: float, depth: float) -> Hand:
    """Left thumb and fingers holding a round behind chamber ``k`` of the open breech (hold ``wf``),
    the hand coming in from below left; ``depth`` = how far the round is in (0 = its nose at the
    chamber mouth, 1 = seated)."""
    from _arms_clips import hand_w  # noqa: PLC0415

    R, o = wf
    c = s.markers["chambers"][k]
    ax = R @ breech_rot(s, a) @ v3(0.0, 1.0, 0.0)               # bore direction, camera space
    up = R @ breech_rot(s, a) @ v3(0.0, 0.0, 1.0)
    mouth = o + R @ breech_point(s, a, c)
    ln = SHELL_LEN[s.name]
    tail = mouth - ax * (ln * (1.0 - depth) + 0.002)            # the round's base, under the thumb
    along = unit(ax * 0.55 + v3(0.40, 0.10, 0.45))
    palm = unit(-up * 0.7 + v3(0.35, 0.0, -0.3))
    pt = tail + up * 0.010 - along * 0.004
    return hand_w(kit.sk, "L", wf, pt, along, palm, (-0.6, -0.45, -0.65), "pinch", share=0.92, off=0.012)


def clip_break_reload(kit, s: FPSet, N: int):
    from _arms_clips import K, hold_frame  # noqa: PLC0415 - circular at import time

    ev = s.ev("reload")
    bo, ej, bc, done = ev["breech_open"], ev["eject"], ev["breech_close"], ev["done"]
    ins = [ev[k] for k in ("shell_in_1", "shell_in_2", "round_in") if k in ev]
    bl = s.blade
    hip = hold_frame(s.hip)
    heavy = s.name == "launcher"
    prep = hold_frame(s.hip, (-0.025, 0.02, 0.020), yaw=6.0, pitch=4.0, roll=4.0)
    # the stock tucked low under the forearm, the action turned toward the eye: the barrels drop
    # open muzzle-down to the left and the chambers face the camera
    flick = A.weapon_frame(v3(0.050, 0.31, -0.175), 17.0, 4.0, 12.0)
    opn = A.weapon_frame(v3(0.045, 0.31, -0.180), 19.0, 7.0, 14.0)
    jolt = A.weapon_frame(v3(0.045, 0.305, -0.165), 18.0, 15.0, 12.0)       # flicked up: the empties fly out
    load = A.weapon_frame(v3(0.040, 0.31, -0.172), 22.0, 9.0, 20.0)
    shut = A.weapon_frame(v3(0.070, 0.28, -0.165), 12.0, 6.0, 8.0)          # stock snapped up to the barrels
    sup = kit.support
    pouch = kit.pouch
    g = kit.grip
    keys = [K(0, hip, sup, g, blade=bl),
            K(bo - 5, prep, sup, g.with_shape(hand_shape("grip", 0.9)), blade=bl),
            K(bo - 2, prep, sup, g.with_shape(hand_shape("grip", 0.9)), blade=bl),
            K(bo, flick, on_breech(s, sup, 1.0), g, blade=bl, ease="snap"),
            K(ej - 3, opn, on_breech(s, sup, 1.0).moved(v3(-0.01, -0.02, -0.01)), g, blade=bl),
            K(ej, jolt, on_breech(s, sup, 1.0).moved(v3(-0.05, -0.04, -0.03)).with_shape(hand_shape("relaxed")), g,
              blade=bl, ease="snap"),
            K(ej + 5, opn, pouch.moved(v3(0.06, 0.12, 0.16)), g, blade=bl, arc_l=(-0.05, 0.0, -0.02))]
    pick = ins[0] - (16 if heavy else 13)
    keys.append(K(pick, load, pouch, g, blade=bl, ease="inout"))
    for k, f_in in enumerate(ins):
        keys.append(K(f_in - 5, load, _shell_hand(kit, s, load, k, 1.0, 0.0), g, blade=bl,
                      arc_l=(-0.05, 0.0, -0.03) if k == 0 else (0.0, 0.0, 0.015)))
        keys.append(K(f_in, load, _shell_hand(kit, s, load, k, 1.0, 1.0), g, blade=bl, ease="out"))
    cl_hand = on_breech(s, sup, 1.0)
    keys += [K(bc - 8, load, cl_hand.moved(v3(-0.02, -0.03, -0.02)).with_shape(hand_shape("grip", 0.5)), g, blade=bl,
               arc_l=(-0.04, 0.0, -0.02)),
             K(bc - 3, load, cl_hand, g, blade=bl),
             K(bc, shut, sup, g, blade=bl, ease="snap"),
             K(bc + 3, hold_frame(s.hip, (-0.015, 0.01, 0.01), yaw=4.0, pitch=3.0, roll=2.0), sup, g, blade=bl),
             K(done, hip, sup, g, blade=bl),
             K(N, hip, sup, g, blade=bl, ease="settle")]
    ch = Choreo(keys)

    def fn(f: int) -> State:
        st = ch(f)
        a = breech_angle(f, ev)
        st.extra["breech"] = a
        # the fore-end hand rides the breech while it moves (open: bo-2..bo+5; close: bc-3..bc)
        if bo - 2 <= f <= bo + 5 or bc - 3 <= f <= bc:
            st.L = on_breech(s, sup.copy(), a)
        st.extra["shell"] = any(pick <= f < f_in for f_in in ins)
        st.extra["chambered"] = sum(1 for f_in in ins if f >= f_in) if f > ej else len(ins)
        return st
    return fn


# =============================================================================================
# crossbow
# =============================================================================================
def string_pos(f: int, ev: dict | None, fire: bool = False) -> float:
    """``String`` position 0 (released, scene pose) .. 1 (latched): fire = 1 -> 0 over frames 0..1;
    reload: 0 until the hook (cock), follows the hand back to the latch by string_back."""
    if fire:
        return 1.0 if f <= 0 else 0.0
    c, sb = ev["cock"], ev["string_back"]
    if f <= c:
        return 0.0
    if f >= sb:
        return 1.0
    return smooth(c, sb, f)


def clip_crossbow_reload(kit, s: FPSet, N: int):
    from _arms_clips import K, hold_frame  # noqa: PLC0415

    ev = s.ev("reload")
    c, sb, bs, bi, done = ev["cock"], ev["string_back"], ev["bolt_show"], ev["bolt_in"], ev["done"]
    m = s.markers
    bl = s.blade
    hip = hold_frame(s.hip)
    tilt = hold_frame(s.reload_tilt)
    pull = hold_frame(s.reload_tilt, (0.0, 0.010, -0.006), pitch=-2.0)
    g = kit.grip
    sup = kit.support

    def hook(t: float, shape="grip") -> Hand:
        """Fingers hooked over the string centre, ``t`` = 0 (released) .. 1 (latched)."""
        p = m["string_rest"] + (m["string_latched"] - m["string_rest"]) * t + v3(-0.004, 0.012, 0.006)
        return kit.left_w(p, (0.25, 0.55, -0.80), (0.0, 0.85, 0.50), pole=(-0.6, -0.5, -0.6),
                          shape=hand_shape(shape, 0.75) if shape == "grip" else shape, share=0.80, off=0.010)
    bolt_grip = kit.left_w(m["magwell"] + v3(-0.004, 0.030, 0.012), (0.35, 0.80, -0.45), (0.25, 0.05, -0.97),
                           pole=(-0.6, -0.4, -0.7), shape="pinch", share=0.92, off=0.010)
    bolt_grip.space = "m"
    pouch = kit.pouch

    def mag_for(hand_c: Hand) -> tuple:
        Rm = hand_c.axes @ bolt_grip.axes.T
        return ("c", Rm, hand_c.wrist - Rm @ bolt_grip.wrist)
    keys = [K(0, hip, sup, g, blade=bl),
            K(c - 5, tilt, hook(0.0, "flat").moved(v3(0.0, 0.03, 0.04)), g, blade=bl, arc_l=(-0.04, 0.0, 0.04)),
            K(c, tilt, hook(0.0), g, blade=bl, ease="out"),
            K(sb, pull, hook(1.0), g, blade=bl, ease="heavy"),
            K(sb + 3, tilt, hook(1.0, "relaxed").moved(v3(-0.02, 0.0, 0.03)), g, blade=bl, ease="out"),
            K(bs, tilt, bolt_grip, g, mag=mag_for(pouch), blade=bl, arc_l=(-0.06, 0.0, 0.0)),
            K(bi - 7, tilt, bolt_grip, g, mag=("w", I3.copy(), v3(-0.004, -0.075, 0.030)), blade=bl,
              arc_m=(-0.07, 0.0, 0.02)),
            K(bi - 3, tilt, bolt_grip, g, mag=("w", I3.copy(), v3(0.0, -0.035, 0.004)), blade=bl),
            K(bi, hold_frame(s.reload_tilt, (0.0, 0.004, 0.003), pitch=0.8), bolt_grip, g, mag=None, blade=bl,
              ease="out"),
            K(bi + 4, tilt, as_cam_stub(bolt_grip), g, blade=bl),
            K(done, hip, sup, g, blade=bl, arc_l=(-0.03, 0.0, -0.04)),
            K(N, hip, sup, g, blade=bl, ease="settle")]
    ch = Choreo(keys)

    def fn(f: int) -> State:
        st = ch(f)
        if bi <= f:
            st.mag = ("w", I3.copy(), np.zeros(3))
        st.extra["string"] = string_pos(f, ev)
        st.extra["bolt"] = f >= bs
        return st
    return fn


def as_cam_stub(h: Hand) -> Hand:
    """The bolt hand after letting go (weapon space, lifted off the rail)."""
    out = h.copy()
    out.space = "w"
    out = out.moved(v3(-0.02, -0.03, 0.035))
    out.shape = hand_shape("relaxed")
    return out


# =============================================================================================
# lever action
# =============================================================================================
def lever_angle(f: int, ev: dict) -> float:
    """``Lever`` opening 0..1 from lever_open (thrown over lo-4..lo) / lever_close (back by lc)."""
    lo, lc = ev["lever_open"], ev["lever_close"]
    if f <= lo - 4 or f >= lc:
        return 0.0
    if f <= lo:
        return A.ease_in(smooth(lo - 4, lo, f) ** 0.85, 1.3)
    if f <= lo + 1:
        return 1.0
    return 1.0 - smooth(lo + 1, lc, f)


def lever_layer(kit, s: FPSet, st: State, f: int, ev: dict, ads: bool = False) -> None:
    a = lever_angle(f, ev)
    st.extra["lever"] = a
    if a <= 0.0:
        return
    pv = s.markers["lever_pivot"]
    st.R = kit.grip.turned(rxd(LEVER_OPEN_DEG * LEVER_HAND_FOLLOW * a), pv)
    st.R.shape = hand_shape("trigger").blend(hand_shape("grip", 0.8), min(1.0, 2.0 * a))
    # the gun rocks back and up a touch on the stroke (the cheek stays on the stock)
    R, o = st.wf
    k = 0.5 if ads else 1.0
    g = math.sin(math.pi * min(1.0, a))
    st.wf = (R @ rxd(2.5 * a * k) @ A.ryd(-2.0 * g * k), o + R @ v3(0.002 * g, -0.006 * a * k, -0.004 * a * k))


def clip_lever_fire(kit, s: FPSet, N: int, ads: bool):
    from _arms_clips import ads_frame, apply_recoil, hold_frame, kick_curve  # noqa: PLC0415

    ev = s.ev("fire_ads" if ads else "fire")
    wf = ads_frame(s) if ads else hold_frame(s.hip)
    rec = s.recoil_ads if ads else s.recoil

    def post(f: int, st: State) -> None:
        apply_recoil(st, rec, kick_curve(f, 9))
        lever_layer(kit, s, st, f, ev, ads)
    sup = kit.support_ads if ads else kit.support
    return Choreo([Key(0, wf, sup, kit.grip, blade=s.blade_ads if ads else s.blade)], post=post)


def _gate_hands(kit, s: FPSet):
    """Left hand with a round: off the gate (loop start/end), at the gate, round pushed in. The gun
    is rolled left so the right-side gate faces up; the hand comes in from below left and the thumb
    pushes the round forward along the tube (authored in camera space for the reload hold)."""
    from _arms_clips import hand_w, hold_frame  # noqa: PLC0415

    m = s.markers
    wf = hold_frame(s.reload_tilt)
    R, o = wf
    gate = o + R @ m["magwell"]
    ax = R @ unit(m["magwell_axis"])
    nrm = R @ v3(1.0, 0.0, 0.0)                     # the gate's outward normal
    along = unit(ax * 0.55 + v3(0.35, 0.05, 0.55))
    palm = unit(-nrm * 0.8 + v3(0.25, 0.0, -0.2))
    pole = (-0.6, -0.45, -0.65)
    tail = gate + nrm * 0.008 - ax * 0.040
    at = hand_w(kit.sk, "L", wf, tail - along * 0.004, along, palm, pole, "pinch", share=0.92, off=0.012)
    pushed = at.moved(m["magwell_axis"] * 0.040)
    away = hand_w(kit.sk, "L", wf, tail - along * 0.07 + v3(-0.02, -0.02, -0.03), along, palm, pole, "pinch",
                  share=0.92, off=0.012)
    return away, at, pushed


def lever_start(kit, s: FPSet, N: int):
    from _arms_clips import K, hold_frame  # noqa: PLC0415

    away, _at, _p = _gate_hands(kit, s)
    tilt = hold_frame(s.reload_tilt)
    return Choreo([K(0, hold_frame(s.hip), kit.support, kit.grip, blade=s.blade),
                   K(N, tilt, away, kit.grip, blade=s.blade, arc_l=(-0.05, 0.0, -0.03))],
                  post=lambda f, st: st.extra.__setitem__("shell", f >= N - 4))


def lever_loop(kit, s: FPSet, N: int):
    from _arms_clips import K, hold_frame  # noqa: PLC0415

    away, at, pushed = _gate_hands(kit, s)
    tilt = hold_frame(s.reload_tilt)
    rin = s.ev("reload_loop")["round_in"]
    push = hold_frame(s.reload_tilt, (0.0, 0.005, -0.002), pitch=0.8, roll=-1.5)
    return Choreo([K(0, tilt, away, kit.grip, blade=s.blade),
                   K(rin - 4, tilt, at, kit.grip, blade=s.blade, arc_l=(0.0, 0.0, 0.02)),
                   K(rin, push, pushed, kit.grip, blade=s.blade, ease="snap"),
                   K(N, tilt, away, kit.grip, blade=s.blade, arc_l=(-0.02, 0.0, -0.03))],
                  post=lambda f, st: st.extra.__setitem__("shell", f < rin or f >= N - 3))


def lever_end(kit, s: FPSet, N: int, empty: bool):
    from _arms_clips import K, hold_frame  # noqa: PLC0415

    away, _a, _p = _gate_hands(kit, s)
    tilt = hold_frame(s.reload_tilt)
    hip = hold_frame(s.hip)
    ev = s.ev("reload_end_empty" if empty else "reload_end")
    if not empty:
        keys = [K(0, tilt, away, kit.grip, blade=s.blade),
                K(ev["done"], hip, kit.support, kit.grip, blade=s.blade, arc_l=(-0.04, 0.0, -0.04)),
                K(N, hip, kit.support, kit.grip, blade=s.blade, ease="settle")]
        return Choreo(keys, post=lambda f, st: st.extra.__setitem__("shell", f < 2))
    pre = hold_frame(s.hip, (-0.015, 0.0, 0.015), yaw=3.0, pitch=4.0, roll=-6.0)
    keys = [K(0, tilt, away, kit.grip, blade=s.blade),
            K(ev["lever_open"] - 6, pre, kit.support, kit.grip, blade=s.blade, arc_l=(-0.04, 0.0, -0.04)),
            K(ev["done"], hip, kit.support, kit.grip, blade=s.blade),
            K(N, hip, kit.support, kit.grip, blade=s.blade, ease="settle")]

    def post(f: int, st: State) -> None:
        st.extra["shell"] = f < 2
        lever_layer(kit, s, st, f, ev)
    return Choreo(keys, post=post)


# =============================================================================================
# entry point
# =============================================================================================
def breech_fns(sk: Skeleton, s: FPSet) -> dict:
    import _arms_clips as CL  # noqa: PLC0415

    kit = CL.Kit(sk, s)
    out = {}
    for clip in s.clips:
        N = s.frames(clip)
        if clip == "idle":
            fn = CL.clip_idle(kit, s, N)
        elif clip == "ads_idle":
            fn = CL.clip_ads_idle(kit, s, N)
        elif clip == "sprint":
            fn = CL.clip_sprint(kit, s, N)
        elif clip in ("draw", "holster"):
            fn = CL.clip_draw(kit, s, N, reverse=clip == "holster")
        elif clip in ("fire", "fire_ads") and s.name == "lever":
            fn = clip_lever_fire(kit, s, N, clip == "fire_ads")
        elif clip in ("fire", "fire_ads"):
            fn = _fire_with_parts(kit, s, N, clip == "fire_ads")
        elif clip in ("reload", "reload_empty") and s.reload == "break":
            fn = clip_break_reload(kit, s, N)
        elif clip in ("reload", "reload_empty") and s.name == "crossbow":
            fn = clip_crossbow_reload(kit, s, N)
        elif clip == "reload_start":
            fn = lever_start(kit, s, N)
        elif clip == "reload_loop":
            fn = lever_loop(kit, s, N)
        elif clip in ("reload_end", "reload_end_empty"):
            fn = lever_end(kit, s, N, clip == "reload_end_empty")
        elif clip in ("reload", "reload_empty"):
            empty = clip == "reload_empty"
            st_n, lp, en, ee, n = lever_pieces(_lever_row(s))
            parts = [(st_n, lever_start(kit, s, st_n))] + [(lp, lever_loop(kit, s, lp))] * n
            parts.append((ee if empty else en, lever_end(kit, s, ee if empty else en, empty)))
            fn = CL.concat(parts)
        else:
            raise ValueError(f"{s.name}: no builder for clip {clip}")
        out[clip] = fn
    return out


def _lever_row(s: FPSet) -> dict:
    from _arms_sets import LEVER_DATA  # noqa: PLC0415
    return LEVER_DATA


def _fire_with_parts(kit, s: FPSet, N: int, ads: bool):
    import _arms_clips as CL  # noqa: PLC0415

    ch = CL.clip_fire(kit, s, N, ads)

    def fn(f: int) -> State:
        st = ch(f)
        if s.name == "crossbow":
            st.extra["string"] = string_pos(f, None, fire=True)
        return st
    return fn


_ = (hand_cam, mag_cam, as_cam)
