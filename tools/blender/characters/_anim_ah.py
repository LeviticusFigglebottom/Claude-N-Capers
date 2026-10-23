"""AH-D1 Afterhours clips (docs/design/heists/afterhours.md, QC-74) for the ``humanoid`` library: the Velvet's DJ.
Private helper of ``anim_humanoid.py`` (pure numpy; wired like ``_anim_rt``).

* ``dj_mix`` (loop): standing at the DJ booth (deck top ``DECK_Z`` above the root plane, the booth's front edge
  ``DECK_EDGE`` ahead), a set at ``BPM``: the left hand rides the mixer's crossfader and channel faders (``FADER``,
  small sideways slides), the right hand nudges the right jog wheel (``JOG``, short arcs on the platter), the knees
  bounce and the head nods on the beat; once per loop the right hand lifts to the right headphone cup and holds it
  against the ear (``cue``), cueing the next track, then goes back to the jog wheel. Root fixed; every motion is periodic
  in the loop, so it closes exactly.
"""

from __future__ import annotations

import math

import numpy as np

import _anim as A
import _anim_humanoid as H
from _anim import FPS, TAU, Clip, Pose, Skeleton, Solver, add_rot, hand_on, hand_shape, ryd, spine, unit, v3

#: the clips this module builds (each one row in anim_humanoid.CLIPS)
NAMES = ("dj_mix",)
KEEP = NAMES

# ---------------------------------------------------------------------------------------------
# the booth (m, root space; Blender x right, y forward, z up). afterhours.md: "the DJ booth (1.0 m deck)" on the 0.3 m
# stage riser; the root stands on the riser, so the deck top is DECK_Z above the root plane.
# ---------------------------------------------------------------------------------------------
DECK_Z = 1.00
DECK_EDGE = 0.30
FADER = (-0.10, 0.44)          # the mixer's faders (left hand)
JOG = (0.24, 0.47)             # the right deck's jog wheel centre (right hand)
JOG_R = 0.05                   # the platter radius the hand works on
BPM = 120.0                    # 16 beats in the 8 s loop: the nod and the bounce close with it
CUE = (2.3, 3.0, 4.2, 4.9)     # right hand: leave the jog, on the headphone cup (cue), leave the cup, back on the jog


def _cyc(t: float, T: float, n: int, ph: float = 0.0) -> float:
    return math.sin(TAU * n * t / T + ph)


def _win(t: float, T: float, a: float, b: float, edge: float) -> float:
    """Cyclic window weight: 1 inside [a, b] (s) with smoothstep edges ``edge`` wide inside it, 0 outside."""
    w = 0.0
    for sh in (-T, 0.0, T):
        x = t + sh
        w = max(w, A.smooth(a, a + edge, x) * (1.0 - A.smooth(b - edge, b, x)))
    return w


def dj_mix(sk: Skeleton, f: int, N: int) -> Pose:
    """At the decks (top DECK_Z, front edge DECK_EDGE ahead): leaning in over the booth, a knee bounce and a head nod
    on every beat (BPM), the left hand sliding the mixer faders, the right hand nudging the jog wheel, and once per
    loop (CUE) the right hand on the headphone cup, the head tipped towards it."""
    t = f / FPS
    T = N / FPS
    k = sk.scale
    beats = round(BPM / 60.0 * T)
    beat = 0.5 + 0.5 * math.cos(TAU * beats * t / T)            # 1 on the beat, 0 between
    cue = _win(t, T, CUE[0], CUE[3], CUE[1] - CUE[0])
    pose = Pose()
    pose.hip = v3(0.006 * k * _cyc(t, T, beats // 4), -0.035 * k, (-0.02 - 0.018 * beat) * k)
    spine(pose, lean=9.0 + 1.5 * beat, chest_lean=6.0, twist=-2.0 + 3.0 * cue, side=-2.5 * cue, hips=(5.0, 0.0, 0.0))
    add_rot(pose, "hips", ryd(1.5 * _cyc(t, T, beats // 2)))
    for sfx, sx in A.SIDES:
        A.plant(sk, pose, sfx, v3(sx * 0.07 * k, (0.01 if sfx == "L" else -0.01) * k, 0.0), yaw=-sx * 8.0)
    H.look(pose, yaw=-3.0 + 3.0 * _cyc(t, T, 1, 0.7) + 6.0 * cue, pitch=30.0 + 7.0 * beat - 10.0 * cue,
           tilt=-9.0 * cue)
    H.breathe(pose, t, T / 4.0, 0.7)
    # left: fingertips on the faders, small sideways slides, a longer crossfade before and after the cue
    fade = 0.012 * _cyc(t, T, beats // 2) + 0.03 * _cyc(t, T, 1, 1.2)
    hand_on(sk, pose, "L", v3((FADER[0] + fade) * k, FADER[1] * k, (DECK_Z + 0.015) * k), unit(v3(0.15, 0.80, -0.58)),
            v3(0.0, 0.25, -0.97), pole=v3(-0.9, -0.3, -0.5), along_share=0.85, palm_off=0.02)
    pose.hands["L"] = hand_shape("relaxed", 1.0)
    # right: the palm on the jog wheel, short arcs (nudges) every other beat
    arc = 0.6 * _cyc(t, T, beats // 2, 0.4)
    p_jog = v3((JOG[0] + JOG_R * 0.6 * math.cos(arc)) * k, (JOG[1] + JOG_R * 0.6 * math.sin(arc)) * k,
               (DECK_Z + 0.012) * k)
    al_jog = unit(v3(-0.25, 0.86, -0.45))
    palm_jog = v3(0.0, 0.0, -1.0)
    hand_on(sk, pose, "R", p_jog, al_jog, palm_jog, pole=v3(0.9, -0.5, -0.4), along_share=0.5, palm_off=0.015)
    pose.hands["R"] = hand_shape("relaxed", 0.8)
    import _anim_bank as bank  # noqa: PLC0415

    before = pose.arms["R"].wrist.copy()
    bank._settle(sk, pose, DECK_Z, DECK_EDGE, ("L", "R"))
    if cue <= 0.0:
        return pose
    # the cue: blend the right hand from its settled spot on the jog wheel to the headphone cup
    p_jog = p_jog + (pose.arms["R"].wrist - before)
    pre = Solver(sk).solve(pose)
    Wh = pre.W["head"]
    p_cup = A.bone_point(pre, sk, "head", v3(0.115 * k, -0.01 * k, 0.075 * k))
    p = (1.0 - cue) * p_jog + cue * p_cup
    al = unit((1.0 - cue) * al_jog + cue * (Wh @ unit(v3(-0.15, -0.25, 0.95))))
    palm = unit((1.0 - cue) * palm_jog + cue * (Wh @ v3(-1.0, 0.0, 0.0)))
    hand_on(sk, pose, "R", p, al, palm, pole=v3(0.9, -0.5 + 0.2 * cue, -0.4 - 0.4 * cue), along_share=0.5,
            palm_off=0.015 + 0.005 * cue)
    pose.hands["R"] = hand_shape("relaxed", 0.8 + 0.4 * cue)
    return pose


# =============================================================================================
# table hook
# =============================================================================================
BUILDERS = {"dj_mix": dj_mix}


def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    out: dict[str, Clip] = {}
    for name in [n for n in NAMES if n in table]:
        row = table[name]
        N, loop, speed, ev = int(row["frames"]), bool(row["loop"]), float(row["speed"]), dict(row.get("events", {}))
        fn = BUILDERS[name]
        out[name] = Clip(name, N, loop, (lambda f, fn=fn, N=N: fn(sk, f, N)), speed, None, ev, reach_fix=True)
    return out


# =============================================================================================
# checks and SOURCE.txt notes
# =============================================================================================
def check_row(sk: Skeleton, table: dict, name: str, baked, keep: dict) -> str:
    fr = baked.frames
    pr = A.probe_for(sk)
    lowest = min(float(pr.posed(s)[:, 2].min()) for s in fr[::3])
    root = [float(np.linalg.norm(s.P["root"] - fr[0].P["root"])) for s in fr] if "root" in fr[0].P else [0.0]
    return f" lowest_skin={lowest * 1000:.1f}mm root_drift={max(root) * 1000:.2f}mm"


def source_notes(sk: Skeleton, table: dict, keep: dict) -> dict[str, str]:
    ev = table.get("dj_mix", {}).get("events", {})
    return {"ah_dj_placement": (
        f"AH-D1 dj_mix (QC-74): the DJ at the booth on the stage riser. The root on the riser floor, facing the booth "
        f"(-Z); the deck top {DECK_Z:.2f} m above the root plane (afterhours.md: the 1.0 m deck), the booth's front edge "
        f"{DECK_EDGE:.2f} m ahead of the root (the hands and forearms rest on the top past it). The left hand works the "
        f"mixer faders at ({FADER[0]:.2f}, {DECK_Z:.2f}, {-FADER[1]:.2f}) and the right hand the right jog wheel at "
        f"({JOG[0]:.2f}, {DECK_Z:.2f}, {-JOG[1]:.2f}) Godot root space (x, y, z): put the mixer and the right deck there. "
        f"{BPM:.0f} BPM: a knee bounce and a head nod on every beat. Event cue@{ev.get('cue', '?')}: the right hand on "
        f"the right headphone cup (club_dj wears over-ear headphones). Loop, in place.")}
