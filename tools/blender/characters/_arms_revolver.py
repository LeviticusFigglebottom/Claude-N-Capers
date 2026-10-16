"""Revolver (speedloader) reload for ``rig_arms`` (D-050, B4-12). Private helper of ``_arms_clips``.

Pure numpy. The other revolver clips (idle, ads_idle, sprint, draw, holster, fire, fire_ads) are the
generic pistol-hold builders of ``_arms_clips`` with the revolver's heavier recoil.

Moving parts (weapon space = Blender weapon axes X right, Y muzzle, Z up; see ``_arms_sets``):

* ``Crane``: pivot on the hinge line (``markers["hinge"]``, parallel to the bore); opens
  ``CRANE_OPEN_DEG`` to the left (``crane_rot``; Godot: + about the Crane's local Z) between the
  ``crane_open`` ramp (crane_open - 2 .. crane_open + 1) and the ``crane_close`` ramp
  (crane_close - 3 .. crane_close).
* ``Cylinder`` (child of Crane): turns ``CYLINDER_STEP_DEG`` per shot (ENV A, on ``shot``).
* the ejector: the left palm pushes the rod in (eject - 3 .. eject), the extractor star lifts the six
  cases out (ENV A spawns the casings at ``eject``).
* ``Speedloader``: rides the ``magazine`` bone. Its weapon-scene transform is the loaded pose against
  the rear face of the **closed** cylinder (``magazine`` identity), so with the crane open the bone
  carries it exactly onto the cylinder at ``speedloader_in`` (bone = the crane rotation about the
  hinge). It is visible from ``loader_show`` (picked from the belt, off screen) to ``crane_close``:
  after ``speedloader_in`` it is twisted, released (``loader_drop``) and falls away empty; the bone
  snaps back to identity at ``crane_close``. The loader's rounds move into the cylinder at
  ``speedloader_in``.
"""

from __future__ import annotations

import numpy as np

import _anim as A
from _anim import FPS, Skeleton, hand_shape, ryd, smooth, unit, v3
from _arms_choreo import I3, Choreo, Hand, Key, State, hand_at, hand_cam, mag_cam
from _arms_sets import CRANE_OPEN_DEG, FPSet

EJECT_STROKE = 0.020
LOADER_TWIST_DEG = 28.0


def crane_rot(a: float) -> np.ndarray:
    """Crane rotation, ``a`` = 0 (closed) .. 1 (open): the cylinder swings out to the left."""
    return ryd(-CRANE_OPEN_DEG * a)


def crane_frame(s: FPSet, a: float) -> tuple[np.ndarray, np.ndarray]:
    """(R, t) weapon-relative transform of the Crane opened ``a``: p -> R p + t."""
    h = s.markers["hinge"]
    R = crane_rot(a)
    return R, h - R @ h


def crane_point(s: FPSet, a: float, p) -> np.ndarray:
    R, t = crane_frame(s, a)
    return R @ np.asarray(p, float) + t


def crane_angle(f: int, ev: dict) -> float:
    op, cl = ev["crane_open"], ev["crane_close"]
    if f <= op - 2 or f >= cl:
        return 0.0
    if f <= op + 1:
        return A.ease_out(smooth(op - 2, op + 1, f), 1.6)
    if f <= cl - 3:
        return 1.0
    return 1.0 - A.ease_in(smooth(cl - 3, cl, f), 1.6)


def eject_stroke(f: int, ev: dict) -> float:
    e = ev["eject"]
    if f <= e - 3 or f >= e + 4:
        return 0.0
    return smooth(e - 3, e, f) if f <= e else 1.0 - smooth(e, e + 4, f)


class RevolverKit:
    def __init__(self, sk: Skeleton, kit) -> None:
        self.sk, self.kit, self.s = sk, kit, kit.s
        m = self.s.markers
        # left hand on the speedloader, loader ("m") space: palm on the knob, fingers across the
        # loader body to its far (right) side, so the forearm stays left of the gun
        knob = m["loader"] + v3(-0.010, -0.036, 0.000)
        self.on_loader = hand_at(sk, "L", "m", knob, (0.92, 0.10, -0.38), (0.10, 0.99, 0.0),
                                 (-0.7, -0.3, -0.6), hand_shape("grip", 0.55), share=0.42, off=0.014)
        # cradle: the support hand slides forward under the cylinder, fingers ready to push it out
        self.cradle = kit.support.moved(v3(0.004, 0.022, 0.010))

    def fit_loader_hand(self, wf: tuple, seat: tuple) -> None:
        """Re-aim the loader hand for the loading hold ``wf``: fingers pointing up in the view and
        over the loader, so the left forearm hangs below the loader instead of across the gun."""
        Rl = wf[0] @ seat[1]
        palm = v3(0.0, 1.0, 0.0)
        up = Rl.T @ unit(v3(0.35, -0.25, 1.0))           # camera up-right-ish, in loader space
        along = unit(up - palm * float(up @ palm))
        knob = self.s.markers["loader"] + v3(0.0, -0.036, 0.0)
        self.on_loader = hand_at(self.sk, "L", "m", knob, along, palm, (-0.45, -0.15, -0.88),
                                 hand_shape("grip", 0.55), share=0.40, off=0.014)

    def loader_w(self, a: float, back: float = 0.0, twist: float = 0.0) -> tuple:
        """Speedloader frame (weapon-relative) on the cylinder opened ``a``, ``back`` m behind it,
        twisted ``twist`` deg about the cylinder axis."""
        R, t = crane_frame(self.s, a)
        c = R @ self.s.markers["loader"] + t                      # loader centre on the cylinder axis
        Rt = ryd(twist)
        Rm = Rt @ R
        pm = Rt @ (t - c) + c + v3(0.0, -back, 0.0)
        return ("w", Rm, pm)

    def hand_on(self, mag: tuple) -> Hand:
        """The left hand holding a loader whose weapon-relative frame is ``mag``."""
        _sp, Rm, pm = mag
        g = self.on_loader
        return Hand("w", pm + Rm @ g.wrist, Rm @ g.axes, g.pole.copy(), g.shape, g.twist)

    def mag_for(self, hand_c_wrist, hand_c_axes) -> tuple:
        g = self.on_loader
        Rm = hand_c_axes @ g.axes.T
        return ("c", Rm, hand_c_wrist - Rm @ g.wrist)

    def rod_hand(self, push: float) -> Hand:
        """Left palm on the ejector-rod tip of the open crane (pushed ``push`` m in)."""
        tip = crane_point(self.s, 1.0, self.s.markers["rod_tip"]) + v3(0.0, 0.006 - push, 0.0)
        return hand_at(self.sk, "L", "w", tip, (0.55, 0.0, 0.84), (0.0, -1.0, 0.0), (-0.6, -0.3, -0.75),
                       "flat", share=0.20, off=0.016)

    def push_hand(self, a: float, away: float = 0.0) -> Hand:
        """Left fingers on the left side of the cylinder (crane opened ``a``) to swing it shut."""
        m = self.s.markers
        R, _t = crane_frame(self.s, a)
        p = crane_point(self.s, a, m["cyl"] + v3(-m["cyl_r"] - 0.004 - away, 0.006, 0.004))
        return hand_at(self.sk, "L", "w", p, R @ v3(0.15, 0.55, 0.82), R @ v3(1.0, 0.0, -0.1),
                       (-0.6, -0.35, -0.7), "flat", share=0.80, off=0.010)


#: D-116 follow-up: the eject / load holds sit this much further from the eye (m) than the first cut, so under P's
#: one-handed hip framing the right forearm does not fill the lower screen while the cylinder is worked
DEEP = 0.08


def clip_speedloader(kit, s: FPSet, N: int, ev: dict):
    """One reload clip (reload == reload_empty): crane_open, eject, loader_show, speedloader_in,
    loader_drop, crane_close, done."""
    from _arms_clips import hold_frame  # noqa: PLC0415 - circular at import time

    sk = kit.sk
    rk = RevolverKit(sk, kit)
    co, ej, sl, cc, done = ev["crane_open"], ev["eject"], ev["speedloader_in"], ev["crane_close"], ev["done"]
    show, drop = ev["loader_show"], ev["loader_drop"]
    bl = s.blade
    hip = hold_frame(s.hip)
    tilt = hold_frame(s.reload_tilt)
    flick = hold_frame(s.reload_tilt, (-0.006, 0.0, 0.004), yaw=4.0, pitch=2.0, roll=-14.0)
    # muzzle up: eject (D-116 follow-up: high enough that the cylinder and the rod hand stay in frame under P's
    # one-handed hip framing)
    up = A.weapon_frame(v3(0.050, 0.30 + DEEP, -0.075), 8.0, 68.0, -12.0)
    up_push = A.weapon_frame(v3(0.050, 0.30 + DEEP, -0.082), 8.0, 66.0, -12.0)
    # muzzle down and to the left, in front of the right forearm: the open cylinder faces the eye
    down = A.weapon_frame(v3(0.050, 0.30 + DEEP, -0.105), 50.0, -38.0, 18.0)
    load = A.weapon_frame(v3(0.045, 0.30 + DEEP, -0.100), 50.0, -34.0, 20.0)
    grip = kit.grip
    pouch = kit.pouch
    pre = rk.loader_w(1.0, back=0.032)
    seat = rk.loader_w(1.0)
    rk.fit_loader_hand(load, seat)
    twist = rk.loader_w(1.0, twist=LOADER_TWIST_DEG)
    keys = [Key(0, hip, kit.support, grip, blade=bl),
            Key(co - 4, tilt, rk.cradle, grip, blade=bl),
            Key(co, flick, rk.cradle, grip, blade=bl, ease="snap"),
            Key(ej - 6, up, rk.rod_hand(0.0), grip, blade=bl, arc_l=(-0.04, 0.0, 0.03)),
            Key(ej, up_push, rk.rod_hand(EJECT_STROKE), grip, blade=bl, ease="snap"),
            Key(ej + 3, up, rk.rod_hand(0.0).moved(v3(0.0, 0.02, 0.0)), grip, blade=bl),
            Key(ej + 6, down, pouch.moved(v3(0.07, 0.10, 0.12)), grip, blade=bl, arc_l=(-0.03, 0.0, 0.0)),
            Key(show, down, pouch, grip, blade=bl),
            Key(sl - 4, load, rk.hand_on(pre), grip, blade=bl, arc_l=(-0.06, 0.0, -0.02)),
            Key(sl, load, rk.hand_on(seat), grip, blade=bl, ease="snap"),
            Key(drop - 1, load, rk.hand_on(twist), grip, blade=bl),
            Key(cc - 6, tilt, rk.push_hand(1.0, 0.045).with_shape(hand_shape("relaxed")), grip, blade=bl,
                arc_l=(-0.04, -0.02, 0.0)),
            Key(cc - 4, tilt, rk.push_hand(1.0, 0.012), grip, blade=bl),
            Key(cc, flick, rk.push_hand(0.0), grip, blade=bl, ease="snap"),
            Key(done, hip, kit.support, grip, blade=bl, arc_l=(-0.02, 0.0, -0.03)),
            Key(N, hip, kit.support, grip, blade=bl, ease="settle")]
    ch = Choreo(keys)
    cache: dict = {}

    def loader_from(st: State) -> tuple:
        w, ax = hand_cam(st.L, st.wf, mag_cam(st.wf, ("w", I3.copy(), np.zeros(3))))
        return rk.mag_for(w, ax)

    def fn(f: int) -> State:
        st = ch(f)
        a = crane_angle(f, ev)
        st.extra["crane"] = a
        st.extra["eject"] = eject_stroke(f, ev)
        st.extra["loader"] = show <= f < cc
        if cc - 3 <= f <= cc:                       # the fingers ride the closing cylinder
            st.L = rk.push_hand(a)
        if show <= f <= drop:                       # the loader is carried by the hand
            st.mag = loader_from(st)
        elif drop < f < cc:                         # released: falls away (camera space)
            if "m" not in cache:
                cache["m"] = loader_from(ch(drop))
            _sp, Rm, pm = cache["m"]
            t = (f - drop) / FPS
            st.mag = ("c", Rm @ A.rxd(-60.0 * t), pm + v3(-0.10 * t, 0.0, -0.5 * 9.81 * t * t))
        else:
            st.mag = ("w", I3.copy(), np.zeros(3))
        return st
    return fn
