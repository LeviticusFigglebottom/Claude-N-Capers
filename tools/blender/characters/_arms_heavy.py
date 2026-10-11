"""Flamethrower, power saw and minigun clips for ``rig_arms`` (D-055, B4-18). Private helper of
``_arms_clips``; pure numpy.

All three are held with the right hand on the rear (pistol) grip and the left hand on a front handle:
the flamethrower's raked front grip (``support="vgrip"``, the mirrored grip offset), the saw's and
minigun's transverse top handle (``support="top"``, palm down). Their idle / ads_idle / sprint /
draw / holster / fire / fire_ads clips are the generic builders of ``_arms_clips`` (``ads_idle`` of
the saw and the minigun is a raised hold without sights, ``FPSet.ads_hold``; fire / fire_ads are 3 f
one-shot shudders the game may restart per damage tick). Hold-to-fire sets:

* flamethrower: ``fire_start`` (valve open, ``ignite``) -> ``fire_hold*`` (braced, a gentle sway and a
  fine vibration; frame 0 == last frame) -> ``fire_end`` (``extinguish``, back to the idle hold).
  ``reload`` / ``reload_empty``: the fuel canister (on ``magazine``) is twisted off and swapped like a
  magazine (mag_out / mag_swap / mag_in; dropped when empty).
* saw: ``rev`` (spin-up: the torque twists the saw) -> ``cut_hold*`` (pushed forward into the cut,
  vibrating) -> ``cut_end``. ``reload`` (= reload_empty): a blade change; the blade (``Blade``, under the
  ``magazine`` bone, spun about its local X by ENV A) comes off the arbor (``nut_off``, ``blade_out``),
  a new one goes on (``blade_in``, ``nut_on``).
* minigun: ``spin_up`` (``spin`` .. ``spun``) -> ``fire_hold*`` -> ``spin_down`` (``stopped``); ``Rotor`` spins
  about its local Z (ENV A). ``reload`` / ``reload_empty``: the ammo box (on ``magazine``) is unhooked and
  replaced (mag_out / mag_swap / mag_in; dropped when empty), then the belt is fed into the chute
  (``belt_seat``). ``sprint*`` is a heavy 24 f jog, ``draw`` is slow.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
from _anim import FPS, TAU, Skeleton, hand_shape, rxd, ryd, rzd, smooth, unit, v3
from _arms_choreo import I3, Choreo, Hand, Key, State
from _arms_sets import FPSet

#: rotor / blade speed for the review renders only (rev/s at full speed); ENV A owns the real spin
REVIEW_SPIN_HZ = {"saw": 3.3, "minigun": 2.2}


def _vibe(st: State, f: int, N: int, amp: float, k=(5, 7), slow: float = 1.0) -> None:
    """Loop-safe vibration: whole periods per loop (``k``) + one slow sway period."""
    ph = f / N
    a = math.sin(TAU * k[0] * ph) * 0.35 + math.sin(TAU * k[1] * ph + 1.1) * 0.25
    b = math.sin(TAU * k[1] * ph) * 0.30 + math.sin(TAU * k[0] * ph + 0.4) * 0.20
    w = math.sin(TAU * ph) * slow
    R, o = st.wf
    st.wf = (rzd(0.5 * w + 0.6 * a * amp) @ R @ rxd(0.9 * b * amp + 0.4 * math.sin(TAU * 2 * ph) * slow)
             @ ryd(0.5 * a * amp),
             o + R @ v3(0.0012 * a * amp, 0.0015 * b * amp, 0.0012 * a * amp) + v3(0.002 * w, 0.0, 0.0))


def _spin(f: int, N: int, mode: str, hz: float) -> float:
    """Review-only rotor angle (rad): spin-up ramps in, spin-down ramps out."""
    t = f / FPS
    T = N / FPS
    if mode == "up":
        return TAU * hz * t * t / (2.0 * T)
    if mode == "down":
        return TAU * hz * (t - t * t / (2.0 * T))
    if mode == "loop":
        return TAU * hz * t
    return 0.0


def heavy_fns(sk: Skeleton, s: FPSet) -> dict:
    import _arms_clips as CL  # noqa: PLC0415

    kit = CL.Kit(sk, s)
    hip = CL.hold_frame(s.hip)
    bl = s.blade
    sup, g = kit.support, kit.grip
    squeeze = g.with_shape(hand_shape("trigger", 1.12))
    hz = REVIEW_SPIN_HZ.get(s.name, 0.0)
    if s.name == "flamethrower":
        brace = CL.hold_frame(s.hip, (-0.008, -0.010, 0.006), pitch=1.5)
        loop_n, start_n, end_n = s.frames("fire_hold"), s.frames("fire_start"), s.frames("fire_end")
        vib = 0.35
    elif s.name == "saw":
        brace = CL.hold_frame(s.hip, (-0.012, 0.050, 0.004), yaw=-2.0, pitch=-5.0, roll=1.0)
        loop_n, start_n, end_n = s.frames("cut_hold"), s.frames("rev"), s.frames("cut_end")
        vib = 1.0
    else:
        brace = CL.hold_frame(s.hip, (-0.010, -0.012, 0.012), pitch=2.0, roll=1.0)
        loop_n, start_n, end_n = s.frames("fire_hold"), s.frames("spin_up"), s.frames("spin_down")
        vib = 0.8

    def loop_clip(N: int):
        def post(f: int, st: State) -> None:
            _vibe(st, f, N, vib, (5, 7) if s.name == "saw" else (6, 9), slow=1.0 if s.name != "saw" else 0.6)
            if s.name == "saw":           # leaning into the cut: a slow push / ease pair per loop
                R, o = st.wf
                p = math.sin(TAU * f / N)
                st.wf = (R @ rxd(-1.2 * p), o + R @ v3(0.0, 0.010 * p, -0.004 * p))
            if s.name == "minigun":       # sustained recoil: pushed back a touch, the climb fought down
                R, o = st.wf
                st.wf = (R @ rxd(0.5 * math.sin(TAU * 2 * f / N)), o + R @ v3(0.0, -0.004, 0.0))
            st.extra["spin"] = _spin(f, N, "loop", hz)
            st.extra["flame"] = True
        return Choreo([Key(0, brace, sup, squeeze, blade=bl)], post=post)

    def start_clip(N: int):
        # the trigger is squeezed; the saw / gun bucks with the motor torque, then settles into the brace
        torque = {"saw": -5.0, "minigun": -3.0}.get(s.name, -1.0)
        kick = CL.hold_frame(s.hip, (-0.006, 0.010, 0.010), yaw=-1.5, pitch=2.0, roll=torque)
        keys = [Key(0, hip, sup, g, blade=bl),
                Key(max(2, N // 3), kick, sup, squeeze, blade=bl, ease="snap"),
                Key(N, brace, sup, squeeze, blade=bl, ease="inout")]

        def post(f: int, st: State) -> None:
            st.extra["spin"] = _spin(f, N, "up", hz)
            st.extra["flame"] = f >= 2
        return Choreo(keys, post=post)

    def end_clip(N: int):
        keys = [Key(0, brace, sup, squeeze, blade=bl),
                Key(max(3, N // 2), CL.hold_frame(s.hip, (0.0, 0.004, -0.004), pitch=-1.0, roll=1.5), sup, g,
                    blade=bl, ease="out"),
                Key(N, hip, sup, g, blade=bl, ease="settle")]

        def post(f: int, st: State) -> None:
            st.extra["spin"] = _spin(f, N, "down", hz)
            st.extra["flame"] = False
        return Choreo(keys, post=post)

    out = {}
    for clip in s.clips:
        N = s.frames(clip)
        if clip == "idle":
            fn = CL.clip_idle(kit, s, N)
        elif clip == "ads_idle":
            fn = CL.clip_ads_idle(kit, s, N)
        elif clip == "sprint" and s.name == "minigun":
            fn = heavy_jog(kit, s, N)
        elif clip == "sprint":
            fn = CL.clip_sprint(kit, s, N)
        elif clip in ("draw", "holster"):
            fn = CL.clip_draw(kit, s, N, reverse=clip == "holster")
        elif clip in ("fire", "fire_ads"):
            fn = CL.clip_fire(kit, s, N, clip == "fire_ads")
        elif clip in ("fire_hold", "cut_hold"):
            fn = loop_clip(N)
        elif clip in ("fire_start", "rev", "spin_up"):
            fn = start_clip(N)
        elif clip in ("fire_end", "cut_end", "spin_down"):
            fn = end_clip(N)
        elif clip in ("reload", "reload_empty") and s.name == "saw":
            fn = blade_change(kit, s, N, s.ev(clip))
        elif clip in ("reload", "reload_empty"):
            fn = CL.clip_mag_reload(kit, s, N, clip == "reload_empty")
        else:
            raise ValueError(f"{s.name}: no builder for clip {clip}")
        out[clip] = fn
    _ = (start_n, end_n, loop_n)
    return out


def heavy_jog(kit, s: FPSet, N: int):
    """Minigun sprint: a heavy jog (24 f, two steps), the gun swinging low across the body."""
    import _arms_clips as CL  # noqa: PLC0415

    def post(f: int, st: State) -> None:
        ph = f / N
        bob = math.cos(TAU * 2 * ph)
        side = math.sin(TAU * ph)
        R, o = st.wf
        st.wf = (rzd(4.0 * side) @ R @ rxd(3.0 * bob) @ ryd(5.0 * side),
                 o + v3(0.016 * side, 0.004 * bob, 0.020 * bob - 0.006))
    wf = CL.hold_frame(s.sprint)
    return Choreo([Key(0, wf, kit.support, kit.grip.with_shape(hand_shape("grip", 0.9)), blade=s.blade * 0.6)],
                  post=post)


# =============================================================================================
# saw blade change
# =============================================================================================
def blade_change(kit, s: FPSet, N: int, ev: dict):
    """The saw rolled right (the blade side up): the left fingers spin the arbor nut off
    (``nut_off``), lift the blade off the arbor (``blade_out``) and carry it down out of view; a
    fresh blade comes up, goes over the arbor (``blade_in``) and the nut is spun back on (``nut_on``)."""
    from _arms_clips import K, hold_frame  # noqa: PLC0415

    m = s.markers
    ab, br = m["arbor"], m["blade_r"]
    no, bo, bi, non, done = ev["nut_off"], ev["blade_out"], ev["blade_in"], ev["nut_on"], ev["done"]
    hip = hold_frame(s.hip)
    tilt = hold_frame(s.reload_tilt)
    work = hold_frame(s.reload_tilt, (0.0, 0.004, 0.006), pitch=1.0, roll=-2.0)
    g = kit.grip
    bl = s.blade

    from _arms_clips import hand_w  # noqa: PLC0415

    R, o = tilt
    arb_c = o + R @ ab
    out_c = R @ v3(-1.0, 0.0, 0.0)                 # the blade's outer face normal (the saw's left side)
    along_c = unit(v3(0.45, 0.35, 0.65) - out_c * 0.2)

    def nut(twist: float) -> Hand:
        """Thumb and index on the arbor nut, the hand coming from below left, wrist turning ``twist``."""
        h = hand_w(kit.sk, "L", tilt, arb_c + out_c * 0.012 - along_c * 0.004, along_c, -out_c,
                   (-0.6, -0.45, -0.65), "pinch", share=0.95, off=0.010)
        return h.turned(rxd(twist), ab)
    # the blade held by its rim on the side nearest the left shoulder, palm on the outer face
    toward = R.T @ unit(v3(-0.6, -0.3, -0.75))
    d = toward - v3(1.0, 0.0, 0.0) * float(toward[0])
    rim_w = ab + unit(d) * br * 0.92
    rim_c = o + R @ rim_w
    on_rim = hand_w(kit.sk, "L", tilt, rim_c + out_c * 0.014, along_c, -out_c, (-0.6, -0.45, -0.65),
                    hand_shape("grip", 0.55), share=0.85, off=0.010)
    on_rim.space = "m"
    pouch = kit.pouch

    def mag_for(hc: Hand) -> tuple:
        Rm = hc.axes @ on_rim.axes.T
        return ("c", Rm, hc.wrist - Rm @ on_rim.wrist)

    def off(d: float) -> tuple:
        return ("w", I3.copy(), v3(-d, 0.0, 0.0))
    top_r = kit.support
    keys = [K(0, hip, top_r, g, blade=bl),
            K(no - 7, tilt, nut(0.0), g, blade=bl, arc_l=(-0.04, 0.0, 0.04)),
            K(no - 3, work, nut(-50.0), g, blade=bl),
            K(no, tilt, nut(-100.0).with_shape(hand_shape("pinch", 0.8)), g, blade=bl),
            K(bo - 5, tilt, on_rim, g, mag=off(0.0), blade=bl, arc_l=(-0.02, 0.0, 0.02)),
            K(bo, work, on_rim, g, mag=off(0.030), blade=bl, ease="out"),
            K(bo + 10, tilt, on_rim, g, mag=mag_for(pouch), blade=bl, arc_m=(-0.08, 0.0, 0.0)),
            K(bi - 12, tilt, on_rim, g, mag=mag_for(pouch.moved(v3(0.02, 0.04, 0.04))), blade=bl),
            K(bi - 5, tilt, on_rim, g, mag=off(0.040), blade=bl, arc_m=(-0.08, 0.0, 0.0)),
            K(bi, work, on_rim, g, mag=None, blade=bl, ease="snap"),
            K(non - 4, tilt, nut(-100.0), g, blade=bl),
            K(non, work, nut(0.0), g, blade=bl, ease="inout"),
            K(non + 3, tilt, nut(0.0).moved(v3(-0.03, 0.0, 0.02)).with_shape(hand_shape("relaxed")), g, blade=bl),
            K(done, hip, top_r, g, blade=bl, arc_l=(-0.03, 0.0, 0.03)),
            K(N, hip, top_r, g, blade=bl, ease="settle")]
    ch = Choreo(keys)

    def fn(f: int) -> State:
        st = ch(f)
        if f >= bi:
            st.mag = ("w", I3.copy(), np.zeros(3))
        st.extra["nut"] = (smooth(no - 7, no, f) if f < bi else 1.0 - smooth(bi + 1, non, f))
        return st
    return fn


_ = (A, smooth)
