"""Throwables and deployables for ``rig_arms`` (D2-04); the melee sets are routed to ``_arms_melee``.
Private helper of ``_arms_clips``; pure numpy.

Every non-gun item rides the ``weapon`` bone, which carries the *item frame* (Blender weapon axes: X
right, Y forward, Z up), so ENV A attaches the item model identity on the bone exactly like a weapon:

* ``throwable`` (frag / concussion / incendiary): the item frame is the grenade's centre (Z up the
  fuse / spoon, Y forward), closed in the right fist (``_arms_melee.item_hand``, the grip pivot
  ``GRENADE_GRIP`` from the centre). ``draw``: up from below, the left hand pinches the ring on the
  grenade's left side and pulls the pin (``pin_pull``; ENV A hides the model's ``Pin`` there), ``ready``.
  ``idle*`` / ``sprint*``: held at the chest. ``throw``: overhand (wound up behind the shoulder, the left
  arm pointing, ``release`` = the hand's forward-most / fastest point: ENV A hides the model and spawns
  the projectile there), follow-through and both hands off screen at ``done``. ``throw_low``: the same
  underhand (a roll / lob). ``holster``: put back without a throw.
* ``deploy_bag`` / ``deploy_small`` / ``deploy_sentry``: the item frame is the model's carry ``Handle``
  (contract proposal: a ``Handle`` marker; ENV A attaches the model so that marker sits on the bone).
  The bag hangs from its top handle in the right hand, the left hand steadies its side; the small
  box (ECM, trip mine, FAK) lies in the right palm; the sentry case is carried by both side handles
  (``SENTRY_SPAN``). ``draw`` (ready) / ``idle*`` / ``holster`` (gone); ``place`` = the deploy hold
  (DeployableDef.deploy_time_s): the item is lowered and set down out of view (bag, sentry) or reached
  forward and pressed against the wall / door (small), ``place`` = the hold's end (ENV A spawns the
  prefab there and hides the held model), then the empty hands drop off screen (``done``).
"""

from __future__ import annotations

import math

import numpy as np

from _anim import TAU, Skeleton, hand_shape, rxd, rzd, unit, v3
from _arms_choreo import Choreo, Hand, Key, State, as_cam, hand_at
from _arms_melee import _breathe, item_frame, item_hand, melee_fns
from _arms_sets import FPSet

#: the right hand's grip pivot from the grenade centre (item space): 12 mm up the fuse axis, 14 mm
#: to the right (the body is fatter than a pistol grip: its centre sits further from the palm)
GRENADE_GRIP = (0.014, 0.0, 0.012)
#: the pin ring on the grenade's left, near the top (item space)
GRENADE_RING = v3(-0.030, 0.0, 0.040)
#: the sentry case: the left side handle this far left of the right one (item space)
SENTRY_SPAN = 0.36


def item_fns(sk: Skeleton, s: FPSet) -> dict:
    if s.support == "melee":
        return melee_fns(sk, s)
    if s.support == "throw":
        return throw_fns(sk, s)
    return deploy_fns(sk, s)


def _down_l(sk: Skeleton) -> Hand:
    return hand_at(sk, "L", "c", (-0.20, 0.05, -0.60), (0.15, 0.40, -0.90), (0.95, 0.0, 0.25), (-0.5, -0.6, -0.4),
                   "relaxed")


def _sprint_post(N: int, amp: float = 1.0):
    def post(f: int, st: State) -> None:
        ph = f / N
        bob = math.cos(TAU * 2 * ph)
        side = math.sin(TAU * ph)
        R, o = st.wf
        st.wf = (rzd(4.0 * side * amp) @ R @ rxd(4.0 * bob * amp), o + v3(0.014 * side, 0.006 * bob, 0.016 * bob) * amp)
        sw = math.sin(TAU * ph + 0.3 + math.pi)
        if st.L.space == "c":
            st.L = st.L.moved(v3(0.02 * sw, 0.10 * sw, 0.03 * abs(sw)))
    return post


# =============================================================================================
# throwable
# =============================================================================================
THROW_POSES = {
    #        position                 up (fuse)              forward
    "idle": ((0.135, 0.300, -0.185), (-0.20, 0.15, 0.97), (0.0, 0.98, -0.15)),
    "sprint": ((0.150, 0.260, -0.215), (-0.10, 0.30, 0.95), (0.0, 0.95, -0.30)),
    "low": ((0.170, 0.110, -0.520), (0.0, 0.30, 0.95), (0.0, 0.95, -0.30)),
    "pin": ((0.075, 0.320, -0.150), (-0.45, 0.10, 0.89), (0.10, 0.99, 0.0)),
    "wind": ((0.230, -0.010, 0.010), (0.15, -0.55, 0.82), (0.0, 0.82, 0.55)),
    "release": ((0.110, 0.330, 0.000), (0.0, 0.65, 0.76), (0.0, 0.76, -0.65)),
    "follow": ((0.020, 0.330, -0.320), (0.0, 0.95, -0.30), (0.0, -0.30, -0.95)),
    "wind_low": ((0.210, 0.010, -0.420), (0.10, -0.40, 0.91), (0.0, 0.91, 0.40)),
    "release_low": ((0.070, 0.360, -0.210), (0.0, 0.55, 0.83), (0.0, 0.83, -0.55)),
    "follow_low": ((0.050, 0.360, -0.110), (0.0, 0.80, 0.60), (0.0, 0.60, -0.80)),
}


class ThrowKit:
    def __init__(self, sk: Skeleton, s: FPSet) -> None:
        self.sk, self.s = sk, s
        self.grip = item_hand(sk, "grip", 0.62, d=GRENADE_GRIP)
        self.down = _down_l(sk)
        # left arm pointing at the target during the overhand wind-up
        self.point = hand_at(sk, "L", "c", (-0.120, 0.400, -0.120), (0.10, 0.95, 0.10), (0.10, 0.10, -0.99),
                             (-0.7, -0.3, -0.6), "flat")
        # thumb and index on the pin ring (grenade space), then the ring pulled away (camera space)
        self.ring = hand_at(sk, "L", "w", GRENADE_RING + v3(-0.006, -0.004, 0.0), (0.55, 0.30, 0.78),
                            (0.80, 0.10, -0.58), (-0.6, -0.4, -0.7), "pinch", share=0.92, off=0.010)

    def wf(self, key: str, dp=(0.0, 0.0, 0.0)) -> tuple:
        p, up, fw = THROW_POSES[key]
        return item_frame(np.asarray(p, float) + np.asarray(dp, float), up, fw)

    def key(self, f: int, pose: str, left: Hand | None = None, ease: str = "inout", arc_r=(0.0, 0.0, 0.0),
            arc_l=(0.0, 0.0, 0.0), blade: float = 0.0, right: Hand | None = None) -> Key:
        return Key(int(f), self.wf(pose), left if left is not None else self.down,
                   right if right is not None else self.grip, ease=ease, arc_r=arc_r, arc_l=arc_l, blade=blade)


def throw_fns(sk: Skeleton, s: FPSet) -> dict:
    tk = ThrowKit(sk, s)
    out = {}
    for clip in s.clips:
        N = s.frames(clip)
        ev = s.ev(clip)
        if clip == "idle":
            fn = _flag(Choreo([tk.key(0, "idle")], post=lambda f, st, N=N: _breathe(st, f, N)), pin=False)
        elif clip == "sprint":
            fn = _flag(Choreo([tk.key(0, "sprint")], post=_sprint_post(N)), pin=False)
        elif clip == "holster":
            fn = _flag(Choreo([tk.key(0, "idle"), tk.key(N, "low", ease="in", arc_r=(0.03, 0.0, -0.02))]), pin=False)
        elif clip == "draw":
            fn = throw_draw(tk, N, ev)
        elif clip in ("throw", "throw_low"):
            fn = throw_throw(tk, N, ev, clip == "throw_low")
        else:
            raise ValueError(f"{s.name}: no builder for clip {clip}")
        out[clip] = fn
    return out


def _flag(fn, **kw):
    def g(f: int) -> State:
        st = fn(f)
        st.extra.setdefault("item", True)
        for k, v in kw.items():
            st.extra.setdefault(k, v)
        return st
    return g


def throw_draw(tk: ThrowKit, N: int, ev: dict):
    pp = ev["pin_pull"]
    wf_pin = tk.wf("pin")
    pulled = as_cam(tk.ring, wf_pin, wf_pin).moved(v3(-0.120, -0.030, -0.030))
    pulled.shape = hand_shape("pinch")
    keys = [tk.key(0, "low"),
            tk.key(pp - 4, "pin", tk.ring.moved(v3(-0.03, 0.0, -0.02)).with_shape(hand_shape("relaxed")), ease="out",
                   arc_l=(-0.04, 0.0, -0.06)),
            tk.key(pp - 1, "pin", tk.ring),
            tk.key(pp + 2, "pin", pulled, ease="snap"),
            tk.key(N, "idle", tk.down, ease="settle", arc_l=(-0.03, 0.0, 0.02))]
    ch = Choreo(keys)

    def fn(f: int) -> State:
        st = ch(f)
        st.extra["item"] = True
        st.extra["pin"] = f < pp
        return st
    return fn


def throw_throw(tk: ThrowKit, N: int, ev: dict, low: bool):
    rel = ev["release"]
    w = max(3, rel - 5)
    if low:
        keys = [tk.key(0, "idle"),
                tk.key(w, "wind_low", tk.down, ease="inout", blade=-10.0, arc_r=(0.04, -0.02, -0.04)),
                tk.key(rel, "release_low", tk.down, ease="in", blade=8.0, arc_r=(0.0, 0.0, -0.06)),
                tk.key(rel + 4, "follow_low", tk.down, ease="out", blade=8.0),
                tk.key(N, "low", tk.down, ease="inout", arc_r=(0.03, 0.0, 0.0))]
    else:
        keys = [tk.key(0, "idle"),
                tk.key(w, "wind", tk.point, ease="inout", blade=-14.0, arc_r=(0.05, -0.03, 0.04),
                       arc_l=(-0.03, 0.0, -0.04)),
                tk.key(rel, "release", tk.point, ease="in", blade=10.0, arc_r=(0.02, 0.0, 0.03)),
                tk.key(rel + 4, "follow", tk.down, ease="out", blade=14.0, arc_l=(-0.03, 0.0, -0.05)),
                tk.key(N, "low", tk.down, ease="inout", arc_r=(0.03, 0.0, 0.0))]
    open_hand = tk.grip.with_shape(hand_shape("relaxed"))
    ch = Choreo(keys)

    def fn(f: int) -> State:
        st = ch(f)
        if f > rel:                  # the hand opens as the grenade leaves
            st.R = st.R.copy()
            st.R.shape = tk.grip.shape.blend(open_hand.shape, min(1.0, (f - rel) / 3.0))
        st.extra["item"] = f <= rel
        st.extra["pin"] = False
        return st
    return fn


# =============================================================================================
# deployables
# =============================================================================================
DEPLOY_POSES = {
    # handle position, up, forward (camera space)
    "deploy_bag": {
        "idle": ((0.075, 0.380, -0.215), (0.0, 0.10, 0.99), (-0.30, 0.95, 0.0)),
        "low": ((0.100, 0.160, -0.600), (0.0, 0.10, 0.99), (-0.30, 0.95, 0.0)),
        "lift": ((0.080, 0.390, -0.200), (0.0, 0.25, 0.97), (-0.25, 0.96, 0.0)),
        "lower": ((0.070, 0.360, -0.480), (0.0, 0.05, 1.0), (-0.20, 0.98, 0.0)),
        "set": ((0.075, 0.300, -0.610), (0.0, 0.0, 1.0), (-0.15, 0.99, 0.0)),
    },
    "deploy_small": {
        "idle": ((0.065, 0.330, -0.175), (0.0, -0.45, 0.89), (-0.20, 0.88, 0.45)),
        "low": ((0.120, 0.150, -0.540), (0.0, 0.30, 0.95), (-0.20, 0.95, -0.30)),
        "lift": ((0.050, 0.360, -0.130), (0.0, -0.15, 0.99), (-0.10, 0.99, 0.15)),
        "lower": ((0.040, 0.405, -0.115), (0.0, 0.0, 1.0), (-0.05, 1.0, 0.0)),
        "set": ((0.040, 0.420, -0.115), (0.0, 0.0, 1.0), (-0.05, 1.0, 0.0)),
    },
    "deploy_sentry": {
        "idle": ((0.180, 0.340, -0.340), (0.0, 0.10, 0.99), (0.0, 0.99, -0.10)),
        "low": ((0.180, 0.180, -0.640), (0.0, 0.10, 0.99), (0.0, 0.99, -0.10)),
        "lift": ((0.180, 0.350, -0.320), (0.0, 0.15, 0.99), (0.0, 0.99, -0.15)),
        "lower": ((0.180, 0.320, -0.500), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)),
        "set": ((0.180, 0.260, -0.600), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)),
    },
}


class DeployKit:
    def __init__(self, sk: Skeleton, s: FPSet) -> None:
        self.sk, self.s = sk, s
        self.P = DEPLOY_POSES[s.name]
        self.down = _down_l(sk)
        self.free_r = hand_at(sk, "R", "c", (0.18, 0.08, -0.60), (-0.15, 0.40, -0.90), (-0.95, 0.0, 0.25),
                              (0.5, -0.6, -0.4), "relaxed")
        if s.name == "deploy_bag":
            # overhand on the top handle bar (along X), palm down; the left palm on the bag's left side
            self.grip = hand_at(sk, "R", "w", v3(0.0, 0.0, 0.012), (0.0, 0.95, -0.30), (0.0, -0.30, -0.95),
                                (0.7, -0.3, -0.65), hand_shape("grip", 0.85), share=0.55, off=0.016)
            self.help = hand_at(sk, "L", "w", v3(-0.215, 0.0, -0.110), (0.15, 0.30, -0.94), (1.0, 0.0, 0.10),
                                (-0.7, -0.3, -0.6), hand_shape("grip", 0.35), share=0.5, off=0.016)
        elif s.name == "deploy_small":
            # the box in the right palm (palm up, fingers round its right edge); the left fingers on its left end
            self.grip = hand_at(sk, "R", "w", v3(0.010, -0.005, -0.019), (-0.35, 0.94, 0.0), (0.0, 0.0, 1.0),
                                (0.7, -0.4, -0.6), hand_shape("grip", 0.45), share=0.55, off=0.014)
            self.help = hand_at(sk, "L", "w", v3(-0.070, 0.0, 0.0), (0.30, 0.50, 0.81), (0.95, 0.0, -0.30),
                                (-0.7, -0.3, -0.6), hand_shape("grip", 0.4), share=0.75, off=0.012)
        else:
            # both side handles (bars along Y), palms in
            self.grip = hand_at(sk, "R", "w", v3(0.012, 0.0, 0.0), (0.0, 0.40, -0.92), (-1.0, 0.0, 0.0),
                                (0.7, -0.3, -0.65), hand_shape("grip", 0.85), share=0.55, off=0.016)
            self.help = hand_at(sk, "L", "w", v3(-SENTRY_SPAN - 0.012, 0.0, 0.0), (0.0, 0.40, -0.92), (1.0, 0.0, 0.0),
                                (-0.7, -0.3, -0.65), hand_shape("grip", 0.85), share=0.55, off=0.016)

    def wf(self, key: str, dp=(0.0, 0.0, 0.0)) -> tuple:
        p, up, fw = self.P[key]
        return item_frame(np.asarray(p, float) + np.asarray(dp, float), up, fw)

    def key(self, f: int, pose: str, left: Hand | None = None, right: Hand | None = None, ease: str = "inout",
            arc_r=(0.0, 0.0, 0.0), arc_l=(0.0, 0.0, 0.0), dp=(0.0, 0.0, 0.0)) -> Key:
        return Key(int(f), self.wf(pose, dp), left if left is not None else self.help,
                   right if right is not None else self.grip, ease=ease, arc_r=arc_r, arc_l=arc_l)


def deploy_fns(sk: Skeleton, s: FPSet) -> dict:
    dk = DeployKit(sk, s)
    out = {}
    for clip in s.clips:
        N = s.frames(clip)
        ev = s.ev(clip)
        if clip == "idle":
            fn = _flag(Choreo([dk.key(0, "idle")], post=lambda f, st, N=N: _breathe(st, f, N, 0.7)))
        elif clip in ("draw", "holster"):
            a, b = ("low", "idle") if clip == "draw" else ("idle", "low")
            fn = _flag(Choreo([dk.key(0, a), dk.key(N, b, ease="settle" if clip == "draw" else "in")]))
        elif clip == "place":
            fn = deploy_place(dk, N, ev)
        else:
            raise ValueError(f"{s.name}: no builder for clip {clip}")
        out[clip] = fn
    return out


def deploy_place(dk: DeployKit, N: int, ev: dict):
    """The deploy hold: lift, lower / reach, set the item down or press it on, ``place``, hands away."""
    pl = ev["place"]
    small = dk.s.name == "deploy_small"
    let_r = dk.grip.with_shape(hand_shape("relaxed"))
    let_l = dk.help.with_shape(hand_shape("relaxed"))
    wf_set = dk.wf("set")
    after_r = as_cam(let_r, wf_set, wf_set).moved(v3(0.02, -0.06, 0.03 if small else 0.06))
    after_l = as_cam(let_l, wf_set, wf_set).moved(v3(-0.02, -0.06, 0.03 if small else 0.06))
    keys = [dk.key(0, "idle"),
            dk.key(round(pl * 0.18), "lift", ease="inout"),
            dk.key(round(pl * 0.55), "lower", ease="inout", arc_r=(0.0, 0.03, 0.0)),
            dk.key(pl - 3, "set", ease="inout"),
            dk.key(pl, "set", let_l, let_r, ease="out", dp=(0.0, 0.004 if small else 0.0, 0.0 if small else -0.004)),
            Key(pl + 5, wf_set, after_l, after_r, ease="out"),
            Key(N, wf_set, dk.down, dk.free_r, ease="inout")]
    ch = Choreo(keys)

    def fn(f: int) -> State:
        st = ch(f)
        st.extra["item"] = f < pl
        if small and pl - 3 < f <= pl:          # the press: a small push into the wall
            st.extra["press"] = True
        return st
    return fn


_ = (unit,)
