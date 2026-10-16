"""D-116 organic pass, item 1: the crew's weapon holds on the move, as teammates see them all heist long.

``hold_<kind>`` (``_anim_holds``) is a standing upper body that A layers over the locomotion clip on its own clock, so the
gait's trunk motion (pelvis counter-twist, bob, the start / stop lean) is overwritten and nothing in the upper body
follows the steps. These layers are frame-locked to their base clip (A sets the layer time to the locomotion clip's;
SOURCE ``locomotion_holds``):

* ``hold_<kind>_<gait>`` for gait = walk / run / sprint / crouch (base walk / run / sprint / crouch_walk) and the four
  one-shots walk_start / walk_stop / run_start / run_stop. Same frames as the base clip, loops where it loops.
* Each frame takes the base clip's own trunk at that frame (hips, spine, chest, neck, head: the counter-twist, the bob,
  the lean) plus the weapon class's trunk set (``H.aim_body``: the rifle blade), then puts the weapon in the hands.
* The weapon rides the chest a couple of frames late (``LAG``) and follows only part of its turn (``FOLLOW``: the arms
  absorb the counter-twist, the muzzle stays near the travel line), plus a spring (``SPRING``) driven by the root's
  acceleration (swings back on a start, overshoots forward on a stop, then settles) and the chest's vertical bob.
* Sprint: the PD2 sprint carry. Long guns diagonal across the chest (muzzle up and left, the support hand on the
  fore-end by the left shoulder), the LMG across the belly, the pistol tucked at the chest in the right hand with the
  left arm pumping (the base sprint's arm), akimbo both guns low, pumping with the arms.

Pure numpy; private helper of ``_anim_humanoid.clips``.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
import _anim_holds as holds
from _anim import FPS, TAU, Clip, Pose, Skeleton, Solver, hand_shape, rxd, ryd, rzd, v3

#: layer gait -> base clip
GAITS = {"walk": "walk", "run": "run", "sprint": "sprint", "crouch": "crouch_walk", "walk_start": "walk_start",
         "walk_stop": "walk_stop", "run_start": "run_start", "run_stop": "run_stop"}
NAMES = tuple(f"hold_{kind}_{g}" for kind in holds.KINDS for g in GAITS)
#: frames the weapon trails the chest, per gait family
LAG = {"walk": 2, "run": 2, "sprint": 1, "crouch": 2}
#: share of the chest's turn the weapon follows (yaw, pitch, roll); the rest is taken up by the arms
FOLLOW = {"walk": (0.45, 0.6, 0.5), "run": (0.45, 0.6, 0.5), "sprint": (0.9, 1.0, 0.9), "crouch": (0.45, 0.35, 0.5)}
#: the weapon's spring against the body: natural frequency (Hz), damping ratio, gains on the root's forward
#: acceleration and the chest's vertical acceleration, the largest offset (m at 1.78 m), the muzzle pitch per metre of
#: vertical offset (deg / m: it trails the bob)
SPRING = {"hz": 2.2, "zeta": 0.38, "fwd": 1.0, "up": 0.55, "max": 0.04, "pitch_per_m": 140.0}
#: the spring's share per kind (long guns swing less: the support arm is near its reach on the LMG / sniper)
SPRING_KIND = {"lmg": 0.45, "sniper": 0.6}
#: the LMG support hand on the move: further back on the handguard than LMG_HIP's (the hip-carry reach limit)
LMG_MOVE_SUPPORT = v3(0.0, 0.213, 0.029)
#: sprint carry frames (grip origin m at 1.78 m, yaw / pitch / roll deg) for an upright body; the chest carries them
SPRINT_CARRY = {
    "rifle": ((0.08, 0.24, 1.19), 50.0, 48.0, -58.0),
    "smg": ((0.08, 0.22, 1.21), 46.0, 50.0, -55.0),
    "sniper": ((0.07, 0.24, 1.17), 52.0, 46.0, -60.0),
    "lmg": ((0.12, 0.26, 1.16), 40.0, 32.0, -40.0),
    "pistol": ((0.12, 0.22, 1.20), 6.0, 62.0, -12.0),
    "akimbo": ((0.17, 0.20, 1.02), 4.0, -28.0, -6.0),
}
#: sprint pump (m at 1.78 m) of the pistol / akimbo gun hands along with the stride
SPRINT_PUMP = 0.045


def _family(gait: str) -> str:
    return gait.split("_")[0]


def _euler(M: np.ndarray) -> tuple[float, float, float]:
    """(yaw, pitch, roll) deg with M = rzd(yaw) @ rxd(pitch) @ ryd(roll) (the ``A.weapon_frame`` order)."""
    pitch = math.degrees(math.asin(max(-1.0, min(1.0, float(M[2, 1])))))
    yaw = math.degrees(math.atan2(-float(M[0, 1]), float(M[1, 1])))
    roll = math.degrees(math.atan2(-float(M[2, 0]), float(M[2, 2])))
    return yaw, pitch, roll


def _scaled(M: np.ndarray, share: tuple) -> np.ndarray:
    y, p, r = _euler(M)
    return rzd(share[0] * y) @ rxd(share[1] * p) @ ryd(share[2] * r)


def low_frames(sk: Skeleton, kind: str) -> list[tuple[str, tuple]]:
    """The standing low-ready weapon frame(s) of ``kind`` (``_anim_holds._hold`` without the glances, lag and breath)."""
    k = sk.scale
    if kind in holds.SUPPORT:
        R, o = holds.rifle_low_frame(sk, 0.0)
        _at, extra = holds.SUPPORT[kind]
        if extra:
            butt = o + R @ (holds.H.RIFLE["butt"] * k)
            R = rxd(extra) @ R
            o = butt - R @ (holds.H.RIFLE["butt"] * k)
        return [("R", (R, o))]
    if kind == "lmg":
        return [("R", holds.lmg_hip_frame(sk, 0.0))]
    R, o = holds.pistol_low_frame(sk, 0.0)
    if kind == "pistol":
        return [("R", (R, o))]
    o = o + v3(0.11 * k, 0.0, 0.0)
    return [("R", (R, o)), ("L", holds._mirror((rzd(-6.0) @ R, o + v3(0.0, 0.0, 0.015 * k))))]   # noqa: SLF001


def sprint_frames(sk: Skeleton, kind: str) -> list[tuple[str, tuple]]:
    k = sk.scale
    p, yaw, pitch, roll = SPRINT_CARRY[kind]
    wf = A.weapon_frame(v3(p[0] * k, p[1] * k, p[2] * k), yaw, pitch, roll)
    if kind != "akimbo":
        return [("R", wf)]
    return [("R", wf), ("L", holds._mirror(wf))]                       # noqa: SLF001


def grip(sk: Skeleton, pose: Pose, kind: str, frames: list, sprint: bool) -> None:
    """The hands on the weapon(s) (as ``_anim_holds._hold``; the sprint pistol one-handed, the left arm left free)."""
    for sfx, _wf in frames:
        for b in ("clavicle", "upper_arm", "forearm", "hand"):
            pose.local.pop(f"{b}.{sfx}", None)
            pose.D.pop(f"{b}.{sfx}", None)
    wf = frames[0][1]
    if kind in holds.SUPPORT:
        at, _extra = holds.SUPPORT[kind]
        A.hold_weapon(sk, pose, wf, pole=v3(0.75, -0.2, -0.6), twist=0.6)
        if sprint:
            _clear(pose, "L")
            holds.H.rifle_support(sk, pose, wf, at=at, pole=v3(-0.6, -0.3, -0.75))
        else:
            _clear(pose, "L")
            holds.H.rifle_support(sk, pose, wf, at=at)
        pose.hands["R"] = hand_shape("grip", 0.9)
    elif kind == "lmg":
        _clear(pose, "L")
        A.hold_weapon(sk, pose, wf, pole=v3(0.8, -0.1, -0.6), twist=0.6)
        holds.H.rifle_support(sk, pose, wf, at=LMG_MOVE_SUPPORT, pole=v3(-0.5, -0.2, -0.85))
        pose.hands["R"] = hand_shape("grip", 0.9)
    elif kind == "pistol":
        if sprint:
            A.hold_weapon(sk, pose, wf, pole=v3(0.55, -0.1, -0.85), twist=0.6)
        else:
            _clear(pose, "L")
            holds.H.hold_pistol(sk, pose, wf)
        pose.hands["R"] = hand_shape("grip", 0.85)
    else:
        A.hold_weapon(sk, pose, wf, pole=v3(0.55, -0.15, -0.8), twist=0.6)
        A.hold_weapon(sk, pose, frames[1][1], pole=v3(-0.55, -0.15, -0.8), sfx="L", twist=0.6)
        pose.hands["R"] = hand_shape("grip", 0.85)
        pose.hands["L"] = hand_shape("grip", 0.85)


def _clear(pose: Pose, sfx: str) -> None:
    for b in ("clavicle", "upper_arm", "forearm", "hand"):
        pose.local.pop(f"{b}.{sfx}", None)
        pose.D.pop(f"{b}.{sfx}", None)


def _trunk_set(sk: Skeleton, kind: str) -> Pose:
    """The weapon class's own trunk (rifle blade / pistol lean) as world-axes deltas to compose onto the gait's."""
    p = Pose()
    holds.H.aim_body(sk, p, kind not in ("pistol", "akimbo"))
    return p


def _spring(acc: list[np.ndarray], loop: bool, k: float) -> list[np.ndarray]:
    """Offsets of a damped spring driven by ``-acc`` (per frame), periodic for loops (three passes, the last kept)."""
    w = TAU * SPRING["hz"]
    z = SPRING["zeta"]
    dt = 1.0 / FPS
    n = len(acc) - 1 if loop else len(acc)
    x = np.zeros(3)
    v = np.zeros(3)
    out: list[np.ndarray] = [np.zeros(3)] * len(acc)
    for _pass in range(3 if loop else 1):
        for i in range(n):
            for _sub in range(4):
                a = -w * w * x - 2.0 * z * w * v - acc[i]
                v = v + a * dt / 4.0
                x = x + v * dt / 4.0
            out[i] = np.clip(x, -SPRING["max"] * k, SPRING["max"] * k)
    if loop:
        out[-1] = out[0]
    return out


def layer_clip(sk: Skeleton, solver: Solver, kind: str, gait: str, base: Clip) -> Clip:
    """``hold_<kind>_<gait>`` over ``base``: see the module docstring."""
    k = sk.scale
    N = base.frames
    loop = base.loop
    fam = _family(gait)
    sprint = fam == "sprint"
    poses = [base.fn(f) for f in range(N + 1)]
    if base.reach_fix:                                     # the hips the base clip bakes with (A.bake does the same)
        A.fix_hips_for_reach(solver, poses[:N] if loop else poses, loop)
        if loop:
            poses[N] = poses[0].copy()
    trunk = None if sprint else _trunk_set(sk, kind)
    if trunk is not None:
        for p in poses:
            for b in ("spine", "chest", "neck", "head"):
                p.D[b] = p.D.get(b, np.eye(3)) @ trunk.D.get(b, np.eye(3))
    solved = [solver.solve(p) for p in poses]
    # the reference chest: the class's standing trunk (the frames above are authored for it) or an upright stand
    ref = Pose()
    if trunk is not None:
        holds.H.aim_body(sk, ref, kind not in ("pistol", "akimbo"))
    else:
        holds.H.stand(sk, ref)
    S0 = solver.solve(ref)
    W0, P0 = S0.W["chest"], S0.P["chest"]
    frames0 = sprint_frames(sk, kind) if sprint else low_frames(sk, kind)
    # the spring's drive: the root's forward acceleration (starts / stops) and the chest's vertical acceleration
    tr = getattr(base, "transition", None)
    s = [tr.s(float(f)) if tr is not None else 0.0 for f in range(N + 1)]
    cz = [float(sv.P["chest"][2]) for sv in solved]

    def d2(vals: list[float], i: int) -> float:
        if loop:
            n = N
            return (vals[(i + 1) % n] - 2.0 * vals[i % n] + vals[(i - 1) % n]) * FPS * FPS
        if i <= 0 or i >= N:
            return 0.0
        return (vals[i + 1] - 2.0 * vals[i] + vals[i - 1]) * FPS * FPS
    acc = [v3(0.0, SPRING["fwd"] * d2(s, i), SPRING["up"] * d2(cz, i)) for i in range(N + 1)]
    off = [x * SPRING_KIND.get(kind, 1.0) for x in _spring(acc, loop, k)]
    lag = LAG[fam]
    share = FOLLOW[fam]
    ph_of = (lambda f: f / N) if loop else (lambda f: f / N)

    def fn(f: int) -> Pose:
        pose = poses[f].copy()
        fl = (f - lag) % N if loop else max(0, f - lag)
        Sl = solved[fl]
        Q = Sl.W["chest"] @ W0.T
        Qs = _scaled(Q, share)
        o_off = off[f]
        pitch = SPRING["pitch_per_m"] * float(o_off[2]) / k
        out = []
        for sfx, (R0, o0) in frames0:
            R = Qs @ R0 @ rxd(pitch)
            o = Sl.P["chest"] + Qs @ (o0 - P0) + o_off
            if sprint and kind in ("pistol", "akimbo"):
                sgn = 1.0 if sfx == "R" else -1.0
                pump = SPRINT_PUMP * k * math.cos(TAU * (ph_of(f) - 0.08)) * sgn
                o = o + v3(0.0, pump, 0.4 * abs(pump))
            out.append((sfx, (R, o)))
        grip(sk, pose, kind, out, sprint)
        return pose
    return Clip(f"hold_{kind}_{gait}", N, loop, fn, 0.0, None, dict(base.events), reach_fix=False)


def clips(sk: Skeleton, solver: Solver, table: dict, base: dict[str, Clip]) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        rest = name[len("hold_"):]
        kind = next(kd for kd in holds.KINDS if rest.startswith(kd + "_"))
        gait = rest[len(kind) + 1:]
        src = GAITS[gait]
        if src not in base:
            continue
        out[name] = layer_clip(sk, solver, kind, gait, base[src])
    return out


def rows(table: dict) -> dict:
    """The contract rows (anim_humanoid.CLIPS): same frames / loop / events as the base clip, stationary."""
    out = {}
    for kind in holds.KINDS:
        for gait, src in GAITS.items():
            r = table[src]
            row = {"frames": r["frames"], "loop": r["loop"], "speed": 0.0, "priority": 2}
            if r.get("events"):
                row["events"] = dict(r["events"])
            out[f"hold_{kind}_{gait}"] = row
    return out


def source_notes() -> dict:
    return {"locomotion_holds": (
        "D-116 organic crew locomotion: hold_<kind>_<gait> (kind = the weapon_holds kinds; gait = walk, run, sprint, "
        "crouch, walk_start, walk_stop, run_start, run_stop) is the upper-body layer (the weapon_holds bone filter) "
        "over the base clip walk / run / sprint / crouch_walk / walk_start / walk_stop / run_start / run_stop, with "
        "the same frames, loop flag and events as its base, and FRAME-LOCKED to it: each frame carries the base "
        "clip's own trunk at that frame (counter-twist, bob, start / stop lean) and the weapon riding the chest a "
        "couple of frames late, with a spring on starts / stops. Play it instead of hold_<kind> while the locomotion "
        "clip is: walk, walk_* and walk_back (30 f, the right foot down at 0) -> _walk; run and run_* -> _run; sprint "
        "-> _sprint (the PD2 sprint carry: long guns across the chest, the pistol tucked at the chest); crouch_walk -> "
        "_crouch; walk_start / walk_stop / run_start / run_stop -> the same-named layer. Set the layer time to the "
        "locomotion clip's playback position every tick (never a random offset). strafe_l / strafe_r (18 f) keep "
        "hold_<kind>")}
