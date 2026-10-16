"""D-116 organic third-person pass (PO standing feedback: the NPCs read "largely inorganic", Fallout NV): life layers
for the guard / police loops. Private helper of ``_anim_humanoid`` / ``_anim_holds`` (pure numpy).

* ``glance``: a looped list of look targets (yaw / pitch / tilt). The head moves to each with a quick ease-out
  (eyes-and-head lead, ~0.35 s, a 6 % overshoot that settles) and holds there, instead of a sine sweep that never stops.
* ``Life`` per clip: the chest and spine follow the head's yaw with delays (overlap), a slow weight shift between the
  feet, breathing, and the arms trailing the trunk's turn (lag) so they settle a few frames after the body stops.
* ``walk_upper`` (Gait ``upper`` hook): the hands trail the forearm swing (wrist lag), the elbow flex peaks after the
  forward swing (overlap), a small shoulder roll with the arm swing.

Everything is a periodic function of t over the loop length T (whole cycles), so every loop still closes exactly.
"""

from __future__ import annotations

import math

import _anim as A
from _anim import TAU, Pose, add_rot, rxd, ryd, rzd

#: head move time (s) to a new glance target, and the overshoot share past it
GLANCE_MOVE = 0.38
GLANCE_OVERSHOOT = 0.06
#: delays (s) after the head: the chest, then the spine, then the arms
CHEST_LAG, SPINE_LAG, ARM_LAG = 0.10, 0.20, 0.16
#: share of the head yaw the chest / spine take
CHEST_SHARE, SPINE_SHARE = 0.22, 0.12

#: per clip: the glance targets as (loop fraction the move starts at, yaw deg + left, pitch deg + down, tilt deg)
GLANCES = {
    "idle": [(0.00, -10.0, 2.0, -1.5), (0.22, 6.0, 4.0, 0.0), (0.48, 22.0, 1.0, 2.0), (0.70, -2.0, 6.0, -1.0)],
    "idle_alert": [(0.00, -26.0, 1.0, -2.0), (0.27, 14.0, 3.0, 1.0), (0.50, 32.0, -1.0, 2.5), (0.78, -6.0, 4.0, 0.0)],
    "hold_rifle": [(0.00, -16.0, -1.0, -1.0), (0.30, 10.0, 1.0, 0.5), (0.55, 24.0, -2.0, 1.5), (0.80, -4.0, 2.0, 0.0)],
    "hold_pistol": [(0.00, -20.0, 0.0, -1.5), (0.26, 8.0, 2.0, 0.5), (0.52, 26.0, -1.0, 2.0), (0.76, -8.0, 3.0, 0.0)],
}
#: the hold kinds without their own list use the rifle's (smg, sniper, lmg) or the pistol's (akimbo)
GLANCE_ALIAS = {"smg": "hold_rifle", "sniper": "hold_rifle", "lmg": "hold_rifle", "rifle": "hold_rifle",
                "pistol": "hold_pistol", "akimbo": "hold_pistol"}


def _ease_out_overshoot(x: float) -> float:
    """0 -> 1 in x = 0..1: fast start, a small overshoot past 1 that settles back (head turns)."""
    x = min(max(x, 0.0), 1.0)
    e = 1.0 - (1.0 - x) ** 3
    return e + GLANCE_OVERSHOOT * math.sin(math.pi * x) * x


def glance(keys: list, t: float, T: float) -> tuple[float, float, float]:
    """The head target at ``t`` of a ``T`` s loop: the key in force, moving from the previous one over GLANCE_MOVE."""
    u = (t / T) % 1.0
    n = len(keys)
    i = max(j for j in range(n) if keys[j][0] <= u) if u >= keys[0][0] else n - 1
    prev = keys[i - 1]
    cur = keys[i]
    since = (u - cur[0]) % 1.0 * T
    e = _ease_out_overshoot(since / GLANCE_MOVE)
    return tuple(prev[k] + (cur[k] - prev[k]) * e for k in (1, 2, 3))


class Life:
    """The organic layers of one looped clip (``keys`` = its glance list, ``T`` = its length in s)."""

    def __init__(self, keys: list, T: float) -> None:
        self.keys, self.T = keys, T

    def yaw(self, t: float) -> float:
        return glance(self.keys, t, self.T)[0]

    def head(self, pose: Pose, t: float, look) -> None:
        """Head on the glance (``look`` = _anim_humanoid.look), the chest and spine following it with delays."""
        y, p, tl = glance(self.keys, t, self.T)
        look(pose, yaw=y, pitch=p, tilt=tl)
        add_rot(pose, "chest", rzd(CHEST_SHARE * self.yaw(t - CHEST_LAG)))
        add_rot(pose, "spine", rzd(SPINE_SHARE * self.yaw(t - SPINE_LAG)))

    def trunk_turn(self, t: float) -> float:
        """The trunk's yaw (deg) at ``t``: what the arms and a held weapon follow."""
        return CHEST_SHARE * self.yaw(t - CHEST_LAG) + SPINE_SHARE * self.yaw(t - SPINE_LAG)

    def arm_lag(self, t: float) -> float:
        """How far (deg) the arms trail the trunk: the trunk's turn ARM_LAG s ago minus now (a lag that settles)."""
        return self.trunk_turn(t - ARM_LAG) - self.trunk_turn(t)

    def weight(self, sk, pose: Pose, t: float, shift, amount: float = 0.010) -> None:
        """One weight shift per loop (``shift`` = _anim_humanoid.shift)."""
        shift(sk, pose, t, self.T, amount)


def fk_arm_lag(pose: Pose, life: Life, t: float, gain: float = 0.55) -> None:
    """FK arms (unarmed idles): each arm hangs back by the trunk's recent turn, about the vertical."""
    lag = gain * life.arm_lag(t)
    for sfx in ("L", "R"):
        add_rot(pose, f"upper_arm.{sfx}", rzd(lag))


def lag_weapon(wf: tuple, pivot, life: Life, t: float, breath_z: float = 0.0) -> tuple:
    """A held weapon frame turned about the vertical through ``pivot`` (the chest) by the trunk's turn delayed by
    ARM_LAG (the arms carry it a moment late), plus ``breath_z`` m of lift."""
    R, o = wf
    a = life.trunk_turn(t - ARM_LAG)
    Rz = rzd(a)
    o2 = pivot + Rz @ (o - pivot)
    o2 = o2 + A.v3(0.0, 0.0, breath_z)
    return Rz @ R, o2


def walk_upper(sk, pose: Pose, ph: float, f: int, arm_lag: float = 0.0, arm_swing: float = 17.0) -> None:
    """Gait ``upper`` hook for the walk: wrist lag, elbow overlap and a shoulder roll on the arm swing (phase ``ph``)."""
    aph = ph - arm_lag
    for sfx, sgn in (("R", -1.0), ("L", 1.0)):
        # the hand trails the forearm: it flexes back as the arm swings forward and flicks through at the reversal
        # (forearm / hand are bone-local in arm_fk: post-multiply there; a bone-local -x rotation flexes)
        hand = sgn * 7.0 * math.cos(TAU * (aph - 0.10))
        pose.local[f"hand.{sfx}"] = pose.local.get(f"hand.{sfx}", A.np.eye(3)) @ rxd(hand)
        # the elbow bends a moment after the forward swing peaks (overlap), not with it
        el = 4.0 * max(0.0, sgn * math.cos(TAU * (aph - 0.07)))
        pose.local[f"forearm.{sfx}"] = pose.local.get(f"forearm.{sfx}", A.np.eye(3)) @ rxd(-el)
        # the shoulder rolls forward a little with the arm
        add_rot(pose, f"clavicle.{sfx}", ryd(A.side_x(sfx) * 1.2 * sgn * math.cos(TAU * (aph - 0.03))))
    del sk, f, arm_swing
