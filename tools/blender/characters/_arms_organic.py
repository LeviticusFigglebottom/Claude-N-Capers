"""D-116 follow-up (PO: the FP holds still read "largely inorganic"): a secondary-motion layer over the keyed
reload / draw / holster clips of the gun sets. Key frames, event frames and clip lengths are untouched; the layer
only adds motion between and after keys, and fades to zero at both ends of the clip so every clip still starts and
ends on its keyed pose (idle blends, shell-by-shell pieces chain).

- **Follow-through**: the gun (with every hand and magazine riding it) follows the keyed weapon frame through an
  under-damped spring, so a move overshoots its key a few millimetres / degrees and settles instead of stopping dead.
- **Anticipation**: the spring's target leads the keyed path by a small counter-move against the coming
  acceleration (a wind-up before each big move).
- **Hands**: each wrist follows its keyed path *relative to the gun* through its own spring (a hand that holds the
  gun has no relative motion and stays exactly on its grip; a hand arriving at the mag well / fore-end overshoots and
  settles), and each hand's finger curls follow through a lighter spring (the fingers re-grip after a seat).
- **Seat accents**: at ``mag_in`` / ``shell_in*`` / ``round_in*`` the wrist rolls into the well (a roll about the
  gun's bore that lands at zero on the event frame); at ``slide_release`` / ``bolt_release`` / ``bolt_forward`` /
  ``pump_forward`` the firing hand squeezes and its thumb rides forward (a short flex pulse).
"""

from __future__ import annotations

import dataclasses
import math

import numpy as np

from _anim import FPS, HandShape
from _arms_choreo import Hand, State, as_cam, mag_cam

#: clip-name prefixes the layer applies to (the keyed one-shot handling clips)
CLIPS = ("reload", "draw", "holster")
#: sets left alone: their states carry a second gun / a string in ``State.extra`` that the layer would not move
SKIP_SETS = ("akimbo", "bow")

#: (frequency Hz, damping ratio, gain) of the springs
GUN_POS = (5.5, 0.45, 0.6)
GUN_ROT = (5.0, 0.45, 0.6)
HAND_POS = (6.0, 0.40, 0.6)
HAND_ROT = (6.0, 0.45, 0.5)
FINGERS = (7.0, 0.35, 1.0)
#: anticipation: the spring target is pushed against the keyed acceleration this many frames ahead (s^2 gain)
ANTICIPATE_LEAD = 3
#: smoothing (frames, Gaussian sigma) of the keyed acceleration driving the follow-through / the anticipation
DRIVE_SIGMA, ANTICIPATE_SIGMA = 1.0, 2.5
#: draw: the keyed raise is played over this share of the clip and the rest settles (ready@ stays the last frame)
DRAW_SHARE = 0.8
ANTICIPATE_POS = 0.0015
ANTICIPATE_ROT = 0.0012
#: hard caps on the added offset (m, rad, deg) so the IK reach and the grip contacts stay safe
MAX_GUN_POS, MAX_GUN_ROT = 0.015, math.radians(4.0)
MAX_HAND_POS, MAX_HAND_ROT = 0.015, math.radians(6.0)
MAX_CURL = 12.0
#: frames over which the layer fades in at the clip start and out at its end
FADE = 5
#: seat accents: wrist roll into the well (deg, over this many frames before the event) and the release squeeze
SEAT_EVENTS = ("mag_in", "shell_in", "round_in")
SEAT_ROLL_DEG, SEAT_FRAMES = 7.0, 6
RELEASE_EVENTS = ("slide_release", "bolt_release", "bolt_forward", "pump_forward")
RELEASE_CURL, RELEASE_THUMB, RELEASE_FRAMES = 9.0, 14.0, 7
#: event reactions of the gun: {event prefixes: (velocity change m/s, angular velocity change deg/s)}, in WEAPON
#: axes (X right, Y muzzle, Z up): the pull of a magazine dips the gun, the seat slap kicks it up the magazine axis,
#: a slide / bolt / pump going home jolts it back
EVENT_KICKS = {
    ("mag_out",): ((0.0, 0.0, -0.22), (-40.0, 0.0, 0.0)),
    ("mag_in",): ((0.0, 0.05, 0.30), (55.0, 0.0, 12.0)),
    ("shell_in", "round_in"): ((0.0, 0.06, 0.10), (20.0, 0.0, 0.0)),
    ("slide_release", "bolt_release", "bolt_forward", "pump_forward", "cover_close", "belt_seat"):
        ((0.0, -0.25, 0.05), (45.0, 0.0, -8.0)),
}
#: the alive drift amplitude (m, rad)
DRIFT_M, DRIFT_RAD = 0.0012, math.radians(0.35)
SUBSTEPS = 4
FINGER_NAMES = ("index", "middle", "ring", "pinky")


def applies(s, clip: str) -> bool:
    return (s.name not in SKIP_SETS and s.support not in ("melee", "throw", "deploy")
            and clip.startswith(CLIPS))


# ---------------------------------------------------------------------------------------------
# small rotation helpers
# ---------------------------------------------------------------------------------------------
def _log(R: np.ndarray) -> np.ndarray:
    c = max(-1.0, min(1.0, (np.trace(R) - 1.0) * 0.5))
    a = math.acos(c)
    v = np.array([R[2, 1] - R[1, 2], R[0, 2] - R[2, 0], R[1, 0] - R[0, 1]])
    if a < 1e-6:
        return v * 0.5
    return v * (a / (2.0 * math.sin(a)))


def _exp(w: np.ndarray) -> np.ndarray:
    a = float(np.linalg.norm(w))
    if a < 1e-9:
        return np.eye(3)
    k = w / a
    K = np.array([[0.0, -k[2], k[1]], [k[2], 0.0, -k[0]], [-k[1], k[0], 0.0]])
    return np.eye(3) + math.sin(a) * K + (1.0 - math.cos(a)) * (K @ K)


def _clamp(v: np.ndarray, m: float) -> np.ndarray:
    """Soft limit: unchanged when small, approaching ``m`` smoothly (tanh) instead of flattening at it."""
    n = float(np.linalg.norm(v))
    return v if n < 1e-12 else v * (m * math.tanh(n / m) / n)


def _acc_raw(track: list[np.ndarray], f: int) -> np.ndarray:
    n = len(track)
    g = min(n - 2, max(1, f))
    return (track[g + 1] - 2.0 * track[g] + track[g - 1]) * (FPS * FPS)


def _acc(track: list[np.ndarray], f: int, sigma: float = 0.0) -> np.ndarray:
    """Keyed acceleration (units / s^2) at frame ``f`` (central difference, clamped to the clip), optionally
    Gaussian-smoothed over ``sigma`` frames (a key's corner reads as a push, not as a one-frame spike)."""
    if sigma <= 0.0:
        return _acc_raw(track, f)
    r = math.ceil(2.5 * sigma)
    ws = [math.exp(-0.5 * (k / sigma) ** 2) for k in range(-r, r + 1)]
    acc = sum(w * _acc_raw(track, f + k) for w, k in zip(ws, range(-r, r + 1)))
    return acc / sum(ws)


def _follow(track: list[np.ndarray], prm: tuple, anticipate: float = 0.0,
            kicks: dict | None = None) -> list[np.ndarray]:
    """Offsets of a 2nd-order follower of ``track`` damped on the RELATIVE velocity, so its error is driven by the
    keyed acceleration alone: no lag on a steady move, a lag while it speeds up and an overshoot + settle when it
    stops. ``anticipate`` (s^2) adds a counter-move against the acceleration ``ANTICIPATE_LEAD`` frames ahead.
    ``kicks``: {frame: velocity change} given to the follower on that frame (a seat slap, a release jolt)."""
    hz, zeta, gain = prm
    w = 2.0 * math.pi * hz
    dt = 1.0 / (FPS * SUBSTEPS)
    e = np.zeros_like(track[0])
    v = np.zeros_like(e)
    out = []
    for f in range(len(track)):
        if kicks and f in kicks:
            v = v + kicks[f]
        if f > 0:
            a = _acc(track, f - 1, DRIVE_SIGMA) * 0.5 + _acc(track, f, DRIVE_SIGMA) * 0.5
            for _k in range(SUBSTEPS):
                v = v + (-w * w * e - 2.0 * zeta * w * v - a) * dt
                e = e + v * dt
        out.append(e * gain - _acc(track, f + ANTICIPATE_LEAD, ANTICIPATE_SIGMA) * anticipate)
    return out


def _rv_track(rots: list[np.ndarray]) -> list[np.ndarray]:
    """Rotations as rotation vectors relative to the first (continuous for the < 180 deg turns of a clip)."""
    return [_log(R @ rots[0].T) for R in rots]


def _fade(f: int, n_last: int) -> float:
    def sm(x: float) -> float:
        x = max(0.0, min(1.0, x))
        return x * x * (3.0 - 2.0 * x)
    return sm(f / FADE) * sm((n_last - f) / FADE)


# ---------------------------------------------------------------------------------------------
# the layer
# ---------------------------------------------------------------------------------------------
def _shape_vec(h: HandShape) -> np.ndarray:
    return np.array([c for f in FINGER_NAMES for c in h.curl[f]] + list(h.thumb) + [h.thumb_opp], float)


def _shape_add(h: HandShape, d: np.ndarray) -> HandShape:
    curl = {f: tuple(h.curl[f][j] + float(d[3 * i + j]) for j in range(3)) for i, f in enumerate(FINGER_NAMES)}
    return dataclasses.replace(h, curl=curl, thumb=tuple(h.thumb[j] + float(d[12 + j]) for j in range(3)),
                               thumb_opp=h.thumb_opp + float(d[15]))


def _event_frames(events: dict, names: tuple) -> list[int]:
    return sorted(int(f) for e, f in events.items() if any(e.startswith(n) for n in names))


def _remapped(fn, n_last: int, share: float):
    """``fn`` played over the first ``share`` of the clip, then holding its last key (``Choreo`` takes fractional
    frames: the keyed motion stays smooth, only faster)."""
    end = max(1.0, n_last * share)

    def g(f: int) -> State:
        return fn(min(float(n_last), f / end * n_last))
    return g


class Organic:
    """``f -> State``: the keyed clip ``fn`` (frames 0..``n_last``) with the secondary-motion layer."""

    def __init__(self, fn, n_last: int, events: dict, share: float = 1.0) -> None:
        if share < 1.0:
            fn = _remapped(fn, n_last, share)
        self.fn = fn
        self.n = n_last
        base = [fn(f) for f in range(n_last + 1)]
        self.base = base
        # the gun: position and rotation tracks (camera space), kicked by the handling events
        kp, kr = {}, {}
        for e, fr in events.items():
            for names, (dv, dw) in EVENT_KICKS.items():
                if 0 <= int(fr) <= n_last and any(e.startswith(nm) for nm in names):
                    Rw = base[int(fr)].wf[0]
                    kp[int(fr)] = kp.get(int(fr), 0.0) + Rw @ np.asarray(dv, float)
                    kr[int(fr)] = kr.get(int(fr), 0.0) + Rw @ np.radians(np.asarray(dw, float))
        d_pos = _follow([st.wf[1].copy() for st in base], GUN_POS, ANTICIPATE_POS, kp)
        d_rot = _follow(_rv_track([st.wf[0] for st in base]), GUN_ROT, ANTICIPATE_ROT, kr)
        # alive: a slow drift while the hands work (two incommensurate sines, phase from the clip length)
        ph = 0.37 * n_last
        for f in range(n_last + 1):
            t = f / FPS
            d_pos[f] = d_pos[f] + np.array([math.sin(2.1 * t + ph), math.sin(3.7 * t + 1.3 * ph), 0.0]) * DRIFT_M
            d_rot[f] = d_rot[f] + np.array([math.sin(2.9 * t + 0.5 * ph), 0.0, math.sin(1.9 * t + ph)]) * DRIFT_RAD
        self.gun = [(_clamp(dr, MAX_GUN_ROT), _clamp(dp, MAX_GUN_POS)) for dr, dp in zip(d_rot, d_pos)]
        # the hands, relative to the gun (weapon space): wrist position, axes, finger curls
        self.hand = {}
        for side in ("L", "R"):
            rel_p, rel_R, shp = [], [], []
            for st in base:
                h = st.L if side == "L" else st.R
                c = as_cam(h, st.wf, mag_cam(st.wf, st.mag))
                Rw, ow = st.wf
                rel_p.append(Rw.T @ (c.wrist - ow))
                rel_R.append(Rw.T @ c.axes)
                shp.append(_shape_vec(h.shape))
            dp = _follow(rel_p, HAND_POS)
            dr = _follow(_rv_track(rel_R), HAND_ROT)
            ds = _follow(shp, FINGERS)
            self.hand[side] = [(_clamp(r, MAX_HAND_ROT), _clamp(p, MAX_HAND_POS), np.clip(s, -MAX_CURL, MAX_CURL))
                               for r, p, s in zip(dr, dp, ds)]
        # seat accents end where the magazine / round stops flying free (camera space) before its seat event
        self.seats = []
        for e in _event_frames(events, SEAT_EVENTS):
            free = [f for f in range(max(0, e - 12), min(e, n_last) + 1) if base[f].mag[0] == "c"]
            if free:
                self.seats.append(free[-1] + 1)
        self.releases = _event_frames(events, RELEASE_EVENTS)

    def _seat_roll(self, f: int) -> float:
        """Roll (rad) about the bore of the hand carrying a magazine / round into the well: from the full angle
        ``SEAT_FRAMES`` before the event to zero on it."""
        for e in self.seats:
            if e - SEAT_FRAMES <= f < e:
                u = (e - f) / SEAT_FRAMES
                return math.radians(SEAT_ROLL_DEG) * u * u
        return 0.0

    def _release(self, f: int) -> float:
        for e in self.releases:
            if e <= f < e + RELEASE_FRAMES:
                return math.sin(math.pi * (f - e) / RELEASE_FRAMES)
        return 0.0

    def __call__(self, f: int) -> State:
        g = min(max(int(f), 0), self.n)
        st = self.fn(g)
        k = _fade(g, self.n)
        if k <= 0.0:
            return st
        Rw, ow = st.wf
        mag_c = mag_cam(st.wf, st.mag)
        dR = _exp(self.gun[g][0] * k)
        dp = self.gun[g][1] * k
        new_wf = (dR @ Rw, ow + dp)
        roll = self._seat_roll(g) * k if st.mag[0] == "c" else 0.0
        # the roll into the well: about the bore, through the free magazine (weapon space, before the gun offset)
        Rr = _exp(np.array([0.0, roll, 0.0]))
        piv = Rw.T @ (mag_c[1] - ow)
        rel = self._release(g) * k
        hands = []
        for side, h in (("L", st.L), ("R", st.R)):
            c = as_cam(h, st.wf, mag_c)
            r, p, s = self.hand[side][g]
            wl = Rw.T @ (c.wrist - ow) + p * k
            al = _exp(r * k) @ (Rw.T @ c.axes)
            if roll and h.space != "w":     # the hand carrying the magazine rolls with it
                wl = piv + Rr @ (wl - piv)
                al = Rr @ al
            shape = _shape_add(h.shape, s * k)
            if rel and side == "R":
                d = np.zeros(16)
                d[:12] = RELEASE_CURL * rel
                d[13] = RELEASE_THUMB * rel
                shape = _shape_add(shape, d)
            R2, o2 = new_wf
            hands.append(Hand("c", o2 + R2 @ wl, R2 @ al, h.pole.copy(), shape, h.twist))
        # a magazine held in camera space rides the gun's offset (it is seated in weapon space)
        mag = st.mag
        if mag[0] == "c":
            Rm = Rw @ Rr @ Rw.T @ mag[1]
            mag = ("c", dR @ Rm, ow + dp + dR @ (mag[2] - ow))
        return State(new_wf, hands[0], hands[1], mag, st.blade, st.sh, dict(st.extra))


def apply(s, fns: dict) -> dict:
    """Wrap the set's handling clips (``applies``) with the layer."""
    out = dict(fns)
    for clip, fn in fns.items():
        if applies(s, clip) and clip in s.clips:
            share = DRAW_SHARE if clip == "draw" else 1.0
            out[clip] = Organic(fn, int(s.frames(clip)), dict(s.ev(clip)), share)
    return out
