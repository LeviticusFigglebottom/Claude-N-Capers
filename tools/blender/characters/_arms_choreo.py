"""Key-pose choreography for the first-person arms (D-034). Private helper of ``_arms_clips``.

Pure numpy. A first-person pose is described in the spaces the viewmodel is authored in:

* the **weapon frame** ``wf = (R, o)`` in camera space (columns = weapon X right, Y muzzle, Z up);
* each hand as a ``Hand``: the wrist (``hand.<s>`` head) and the hand-bone axes, expressed in one of
  three spaces: ``"c"`` camera, ``"w"`` the weapon frame (the hand rides on the weapon: grip,
  handguard, pump, bolt knob ...) or ``"m"`` the magazine frame (the hand carries the magazine);
* the **magazine frame** (weapon axes; seated = the weapon frame), relative to the weapon (``"w"``)
  or free in camera space (``"c"``);
* the torso ``blade`` (yaw of the shoulder line about the neck, deg, + = left shoulder forward:
  shouldered long guns are fired from a bladed stance, the head turned to the front).

``Choreo`` interpolates a list of ``Key``s: the weapon frame by slerp, a hand inside its own space
when both keys share it (so a hand on the handguard stays on the handguard while the gun moves),
otherwise in camera space, with an optional sideways ``arc`` so hands travel on curves. ``realize``
turns a ``State`` into an ``_anim.Pose``: two-bone IK goals for both arms, the clavicles (blade +
the solver's shoulder-girdle follow) and the ``weapon`` / ``magazine`` bones as free bones.

Every clip animates the same transforms (rotation of every bone; location of the clavicles,
``weapon`` and ``magazine``), so switching clips never leaves a stale track behind.
"""

from __future__ import annotations

import dataclasses
import itertools
import math
from collections.abc import Callable
from dataclasses import dataclass, field

import numpy as np

import _anim as A
from _anim import EASES, HandShape, Pose, Skeleton, Solver, hand_shape, mslerp, rzd, unit, v3

I3 = np.eye(3)
#: Torso-yaw pivot (the neck, behind the eye) and the first-person shoulder placement: both
#: shoulders sit a little further back and lower than the anatomical eye offset of rig_humanoid,
#: so the arms enter the view from below at natural angles and the upper arms stay out of frame.
NECK = v3(0.0, -0.095, -0.10)
SHOULDERS = v3(0.0, -0.030, -0.040)
CLAV = 0.6                     # shoulder-girdle follow strength (``_anim.ArmIK.clav``)


# =============================================================================================
# hands
# =============================================================================================
@dataclass
class Hand:
    space: str                 # "c" | "w" | "m"
    wrist: np.ndarray          # hand bone head, in ``space``
    axes: np.ndarray           # hand bone axes (columns), in ``space``
    pole: np.ndarray           # elbow direction, camera space
    shape: HandShape
    twist: float = 0.5

    def copy(self) -> Hand:
        return Hand(self.space, self.wrist.copy(), self.axes.copy(), self.pole.copy(),
                    dataclasses.replace(self.shape, curl=dict(self.shape.curl)), self.twist)

    def moved(self, d) -> Hand:
        h = self.copy()
        h.wrist = h.wrist + np.asarray(d, float)
        return h

    def turned(self, R: np.ndarray, about) -> Hand:
        """Rotate the hand by ``R`` (in its space) about the point ``about``."""
        h = self.copy()
        c = np.asarray(about, float)
        h.wrist = c + R @ (h.wrist - c)
        h.axes = R @ h.axes
        return h

    def with_shape(self, shape: HandShape) -> Hand:
        h = self.copy()
        h.shape = shape
        return h


def hand_at(sk: Skeleton, sfx: str, space: str, point, along, palm, pole, shape: HandShape | str,
            share: float = 0.5, off: float = 0.016, twist: float = 0.5) -> Hand:
    """The palm point (``share`` along the hand bone, ``off`` in front of it) on ``point``, the hand
    pointing ``along`` with the palm facing ``palm`` (all in ``space``)."""
    hb = f"hand.{sfx}"
    axes = A.hand_rot(sk, sfx, unit(np.asarray(along, float)), unit(np.asarray(palm, float))) @ sk.B[hb]
    wrist = np.asarray(point, float) - axes @ v3(0.0, share * sk.length(hb), -off * sk.scale)
    shp = hand_shape(shape) if isinstance(shape, str) else shape
    return Hand(space, wrist, axes, unit(np.asarray(pole, float)), shp, twist)


def grip_hand(sk: Skeleton, pole=(0.7, -0.15, -0.7), shape: HandShape | str = "trigger") -> Hand:
    """The right hand on the weapon grip (``_anim.grip_offset``), weapon space."""
    R_off, t_off = A.grip_offset(sk, "R")
    axes = R_off.T.copy()
    shp = hand_shape(shape) if isinstance(shape, str) else shape
    return Hand("w", -axes @ t_off, axes, unit(np.asarray(pole, float)), shp, 0.6)


# =============================================================================================
# keys and states
# =============================================================================================
@dataclass
class Key:
    f: int
    wf: tuple                              # (R, o) camera space
    L: Hand
    R: Hand
    mag: tuple | None = None               # None = seated; ("w", R, p) weapon-relative; ("c", R, p)
    ease: str = "inout"
    blade: float = 0.0
    arc_l: tuple = (0.0, 0.0, 0.0)         # camera-space bulge of the move into this key (m)
    arc_r: tuple = (0.0, 0.0, 0.0)
    arc_m: tuple = (0.0, 0.0, 0.0)
    sh: tuple = (0.0, 0.0, 0.0)            # extra shoulder offset (both shoulders, camera space)


@dataclass
class State:
    wf: tuple
    L: Hand
    R: Hand
    mag: tuple                             # ("w" | "c", R, p)
    blade: float
    sh: np.ndarray
    extra: dict = field(default_factory=dict)   # per-clip data for post layers / reviews


def _mag_of(k: Key) -> tuple:
    return ("w", I3.copy(), np.zeros(3)) if k.mag is None else (k.mag[0], k.mag[1].copy(), np.asarray(k.mag[2], float))


def mag_cam(wf: tuple, mag: tuple) -> tuple[np.ndarray, np.ndarray]:
    R, o = wf
    sp, Rm, pm = mag
    return (R @ Rm, o + R @ pm) if sp == "w" else (Rm.copy(), pm.copy())


def space_frame(space: str, wf: tuple, mag_c: tuple) -> tuple[np.ndarray, np.ndarray]:
    if space == "c":
        return I3, np.zeros(3)
    if space == "w":
        return wf
    return mag_c


def hand_cam(h: Hand, wf: tuple, mag_c: tuple) -> tuple[np.ndarray, np.ndarray]:
    R, o = space_frame(h.space, wf, mag_c)
    return o + R @ h.wrist, R @ h.axes


def as_cam(h: Hand, wf: tuple, mag_c: tuple) -> Hand:
    w, ax = hand_cam(h, wf, mag_c)
    return Hand("c", w, ax, h.pole.copy(), h.shape, h.twist)


def _blend_hand(a: Hand, b: Hand, t: float) -> Hand:
    return Hand(b.space, a.wrist + (b.wrist - a.wrist) * t, mslerp(a.axes, b.axes, t),
                unit(a.pole + (b.pole - a.pole) * t + v3(0.0, 0.0, 1e-9)), a.shape.blend(b.shape, t),
                a.twist + (b.twist - a.twist) * t)


def blend_states(k0: Key, k1: Key, t: float, u: float) -> State:
    """``t`` = eased fraction (positions / rotations), ``u`` = raw fraction (arcs)."""
    R = mslerp(k0.wf[0], k1.wf[0], t)
    o = k0.wf[1] + (k1.wf[1] - k0.wf[1]) * t
    wf = (R, o)
    m0, m1 = _mag_of(k0), _mag_of(k1)
    bump = math.sin(math.pi * min(1.0, max(0.0, t)))
    if m0[0] == m1[0] == "w":
        mag = ("w", mslerp(m0[1], m1[1], t), m0[2] + (m1[2] - m0[2]) * t)
        if any(k1.arc_m):
            mag = ("w", mag[1], mag[2] + R.T @ (v3(*k1.arc_m) * bump))
    else:
        c0, c1 = mag_cam(k0.wf, m0), mag_cam(k1.wf, m1)
        mag = ("c", mslerp(c0[0], c1[0], t), c0[1] + (c1[1] - c0[1]) * t + v3(*k1.arc_m) * bump)
    mag_c = mag_cam(wf, mag)
    hands = []
    for h0, h1, arc in ((k0.L, k1.L, k1.arc_l), (k0.R, k1.R, k1.arc_r)):
        if h0.space == h1.space and h0.space in ("w", "m"):
            h = _blend_hand(h0, h1, t)
            if any(arc):
                Rs, _o = space_frame(h.space, wf, mag_c)
                h.wrist = h.wrist + Rs.T @ (v3(*arc) * bump)
        else:
            a = as_cam(h0, k0.wf, mag_cam(k0.wf, m0))
            b = as_cam(h1, k1.wf, mag_cam(k1.wf, m1))
            h = _blend_hand(a, b, t)
            h.wrist = h.wrist + v3(*arc) * bump
        hands.append(h)
    return State(wf, hands[0], hands[1], mag, k0.blade + (k1.blade - k0.blade) * t,
                 v3(*k0.sh) + (v3(*k1.sh) - v3(*k0.sh)) * t)


def key_state(k: Key) -> State:
    return State((k.wf[0].copy(), k.wf[1].copy()), k.L.copy(), k.R.copy(), _mag_of(k), k.blade, v3(*k.sh))


def schedule(fs: list[int]) -> list[int]:
    """Strictly increasing key frames for keys listed in choreography order.

    Key frames are laid out from data-driven event frames (fractions of the clip length) plus fixed
    frame offsets, so a shorter clip can collapse two keys onto one frame or even swap them. The
    list order is the intended order: frames that are already strictly increasing are kept as they
    are; otherwise the least-squares shift (rounded) that restores a 1-frame minimum spacing is used
    (isotonic regression of ``f_i - i``, pool adjacent violators), held inside the span
    ``min(fs)..max(fs)`` the keys covered, so the clip keeps its length and never runs past its end.
    """
    n = len(fs)
    if all(b > a for a, b in itertools.pairwise(fs)):
        return list(fs)
    lo, hi = min(fs), max(fs)
    if hi - lo < n - 1:
        raise ValueError(f"{n} keys cannot fit frames {lo}..{hi} 1 frame apart: {fs}")
    blocks: list[list[float]] = []                   # [mean of f_i - i, count]
    for i, f in enumerate(fs):
        blocks.append([float(f - i), 1.0])
        while len(blocks) > 1 and blocks[-2][0] > blocks[-1][0]:
            m1, c1 = blocks.pop()
            m0, c0 = blocks.pop()
            blocks.append([(m0 * c0 + m1 * c1) / (c0 + c1), c0 + c1])
    h = [m for m, c in blocks for _ in range(int(c))]
    out = [math.floor(v + 0.5) + i for i, v in enumerate(h)]
    out = [min(max(g, lo + i), hi - (n - 1 - i)) for i, g in enumerate(out)]
    if any(b <= a for a, b in itertools.pairwise(out)):     # unreachable: kept as a guard
        raise ValueError(f"key schedule {fs} -> {out} is not strictly increasing")
    return out


class Choreo:
    """``f -> State`` from keys (the first key's ease is ignored); ``post(f, state)`` layers
    procedural motion (recoil, sway, pump travel ...) on top. Keys are given in choreography order;
    their frames go through ``schedule`` (strictly increasing, see there)."""

    def __init__(self, keys: list[Key], post: Callable | None = None) -> None:
        fs = schedule([k.f for k in keys])
        self.keys = [k if k.f == f else dataclasses.replace(k, f=f) for k, f in zip(keys, fs)]
        self.post = post

    def __call__(self, f: int) -> State:
        ks = self.keys
        if f <= ks[0].f:
            st = key_state(ks[0])
        elif f >= ks[-1].f:
            st = key_state(ks[-1])
        else:
            st = None
            for k0, k1 in zip(ks[:-1], ks[1:]):
                if k0.f <= f <= k1.f:
                    u = (f - k0.f) / max(1, k1.f - k0.f)
                    st = blend_states(k0, k1, EASES[k1.ease](u), u)
                    break
        if self.post is not None:
            self.post(f, st)
        return st


# =============================================================================================
# state -> pose
# =============================================================================================
def bone_world(sk: Skeleton, bone: str, R: np.ndarray, p: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Weapon-axes frame (columns X right, Y muzzle, Z up) -> (world rotation delta, head) of the
    ``weapon`` / ``magazine`` bone (bone axes X right, Y up, Z back; see ``_arms.segments``)."""
    bone_axes = np.column_stack([R[:, 0], R[:, 2], -R[:, 1]])
    return bone_axes @ sk.B[bone].T, np.asarray(p, float).copy()


def shoulder_frames(sk: Skeleton, blade: float, sh=(0.0, 0.0, 0.0)) -> dict:
    Rb = rzd(-blade)
    out = {}
    for sfx in ("L", "R"):
        cb = f"clavicle.{sfx}"
        out[sfx] = (Rb, NECK + Rb @ (sk.head[cb] - NECK) + SHOULDERS + np.asarray(sh, float))
    return out


def realize(sk: Skeleton, solver: Solver, st: State, base_sh=(0.0, 0.0, 0.0)) -> Pose:
    """``base_sh``: the set's own shoulder offset (``FPSet.sh``), added to the state's."""
    pose = Pose()
    mag_c = mag_cam(st.wf, st.mag)
    for sfx, h in (("L", st.L), ("R", st.R)):
        wrist, axes = hand_cam(h, st.wf, mag_c)
        Dw = axes @ sk.B[f"hand.{sfx}"].T
        A.arm_ik_rot(pose, sfx, wrist, Dw, h.pole, twist=h.twist, clav=CLAV)
        pose.hands[sfx] = h.shape
    for sfx, (Rb, P) in shoulder_frames(sk, st.blade, st.sh + np.asarray(base_sh, float)).items():
        follow = solver._clav_follow(pose, sfx, Rb, P)          # noqa: SLF001 - shared toolkit
        pose.world[f"clavicle.{sfx}"] = (Rb @ follow, P)
    pose.world["weapon"] = bone_world(sk, "weapon", *st.wf)
    pose.world["magazine"] = bone_world(sk, "magazine", *mag_c)
    return pose


def weapon_of(sk: Skeleton, s, ) -> tuple[np.ndarray, np.ndarray]:
    """Camera-space weapon frame carried by a solved ``weapon`` bone (``_anim.Solved``)."""
    Rb = s.W["weapon"] @ sk.B["weapon"]
    return np.column_stack([Rb[:, 0], -Rb[:, 2], Rb[:, 1]]), s.P["weapon"].copy()


def magazine_of(sk: Skeleton, s) -> tuple[np.ndarray, np.ndarray]:
    Rb = s.W["magazine"] @ sk.B["magazine"]
    return np.column_stack([Rb[:, 0], -Rb[:, 2], Rb[:, 1]]), s.P["magazine"].copy()
