"""Locomotion reversal one-shots (characters v1.27, D-153 motion strips) for the ``humanoid`` library. Private helper of
``anim_humanoid.py`` (pure numpy; wired like ``_anim_rt``).

An aiming unit that kites keeps its facing and flips its travel (run <-> run_b, walk <-> walk_back). A crossfade between
the two opposite strides averages them and folds the knees into a squat; these clips replace it with a plant and push:

* ``run_reverse_l`` / ``_r``: run -> run_b; ``run_reverse_back_l`` / ``_r``: run_b -> run; ``walk_reverse_l`` / ``_r``:
  walk -> walk_back; ``walk_reverse_back_l`` / ``_r``: walk_back -> walk. ``_l`` = the LEFT foot is the brake foot.
* Frame 0 IS the source loop at ``u_in`` (the brake foot's touch-down); the last frame IS the target loop at ``u_out``.
* The brake foot lands (``foot_plant`` = frame 0) and stays planted (world-still at the root curve) while the root
  decelerates to 0 (``push``) and accelerates the other way; it lifts on the target loop's schedule and swings into it.
  The other foot, in swing at frame 0, turns round in the air and lands on the target loop's touch-down, by which time
  the root moves at the target speed, so from there it IS the target loop. The trunk leans against the change of
  speed, the pelvis turns a little into the brake foot and the hips shift over it.
* In place: A moves the root along ``curve.<clip>`` (SOURCE: metres along the character's forward per frame, + =
  forward, Godot ``-Z``; signed, with the speed crossing zero once at ``push``).
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

import _anim as A
from _anim import Clip, LegIK, Pose, Skeleton, Solver, add_rot, mslerp, rxd, rzd, smooth, unit, v3

#: name -> (gait family, source loop, target loop, brake foot)
SPECS = {
    "run_reverse_l": ("run", "run", "run_b", "L"),
    "run_reverse_r": ("run", "run", "run_b", "R"),
    "run_reverse_back_l": ("run", "run_b", "run", "L"),
    "run_reverse_back_r": ("run", "run_b", "run", "R"),
    "walk_reverse_l": ("walk", "walk", "walk_back", "L"),
    "walk_reverse_r": ("walk", "walk", "walk_back", "R"),
    "walk_reverse_back_l": ("walk", "walk_back", "walk", "L"),
    "walk_reverse_back_r": ("walk", "walk_back", "walk", "R"),
}
NAMES = tuple(SPECS)
#: per family: clip frames N, ``push`` (the root speed crosses 0; walk: solved so the brake foot lifts on the target
#: loop's lift-off spot, the event is the frame nearest it), the other foot's landing / the root at the target speed, trunk lean (deg, against the change of speed), pelvis turn into the brake foot (deg), hip shift over it (m),
#: the swinging foot's lift bump (m)
TIMING = {
    "run": dict(N=18, push=6, solve_push=False, land=13.0, lean=11.0, turn=8.0, shift=0.03, bump=0.05),
    "walk": dict(N=24, push=11, solve_push=True, land=17.0, lean=5.0, turn=6.0, shift=0.025, bump=0.025),
}
#: the anim_humanoid.CLIPS rows (frames, events)
ROWS = {n: {"frames": TIMING[s[0]]["N"], "loop": False, "speed": 0.0, "priority": 6,
            "events": {"foot_plant": 0, "push": TIMING[s[0]]["push"], "done": TIMING[s[0]]["N"]},
            "root_motion": f"curve.{n}"} for n, s in SPECS.items()}
KEEP = NAMES + ("run_b", "walk_back")
#: the swinging foot's recovery point: between the two contacts, this share of the way toward under the hips (y)
RECOVER_PULL = 0.4
#: ... reached at this share of the swing, raised by this share of the target gait's foot lift (+ the bump)
RECOVER_AT = 0.5
RECOVER_LIFT = 1.0
#: swings shorter than this (frames) are one Hermite (no recovery point)
RECOVER_MIN = 6.0


def _entry(src_frames: int, foot: str) -> int:
    """The source loop frame of the brake foot's touch-down (R at 0, L at frames / 2, rounded up: planted at frame 0)."""
    return 0 if foot == "R" else int(math.ceil(src_frames / 2.0))


def _exit(tgt_frames: int, N: int, land: float, other: str) -> tuple[int, float]:
    """(target loop frame at the clip's last frame, the other foot's exact landing time) so that it touches down on the
    target loop's schedule (R at phase 0, L at 0.5) at ``land`` (rounded to keep the hand-off frame an integer)."""
    off = 0.0 if other == "R" else 0.5
    h = (off * tgt_frames + N - land) % tgt_frames
    h_int = int(round(h)) % tgt_frames
    t_land = N - ((h_int - off * tgt_frames) % tgt_frames)
    return h_int, t_land


class Travel2:
    """Root travel along the SOURCE loop's direction (m at 1.78 m, t in frames): source speed at 0, 0 at ``push``,
    minus the target speed from ``land`` on (Hermite pieces, continuous speed)."""

    def __init__(self, v_s: float, v_t: float, push: float, land: float) -> None:
        s1 = v_s * push / 2.0
        s2 = s1 - v_t * (land - push) / 2.0
        self.knots = [(0.0, 0.0, v_s), (float(push), s1, 0.0), (float(land), s2, -v_t)]

    def __call__(self, t: float) -> float:
        ks = self.knots
        if t <= ks[0][0]:
            return ks[0][1] + ks[0][2] * (t - ks[0][0])
        if t >= ks[-1][0]:
            return ks[-1][1] + ks[-1][2] * (t - ks[-1][0])
        for (t0, s0, v0), (t1, s1, v1) in zip(ks[:-1], ks[1:]):
            if t0 <= t <= t1:
                dur = t1 - t0
                return A.hermite(s0, s1, v0 * dur, v1 * dur, (t - t0) / dur)
        return ks[-1][1]

    def speed(self, t: float) -> float:
        e = 1e-3
        return (self(t + e) - self(t - e)) / (2 * e)


@dataclass
class Reversal:
    """One reversal: the source / target gaits and their reach-fixed loop poses, the hand-off frames and the programs."""

    name: str
    gs: object
    gt: object
    ref_s: list
    ref_t: list
    foot: str
    other: str
    N: int
    h_in: int
    h_out: int
    push: float
    land: float
    lift: float
    s: Travel2
    tm: dict
    sign: float          # +1 forward source (lean back), -1 backward source
    o_lift: float = 0.0  # the other foot lifts here (> 0 when it is still planted at frame 0: walks)

    # ---- loop evaluation -------------------------------------------------------------------------------------
    def _phase_t(self, t: float) -> float:
        """Target loop normalised time at clip time t (exact at N)."""
        return (self.h_out - (self.N - t)) / self.gt.frames

    def _cycle_foot(self, g, sfx: str, cyc: float):
        """(ankle, R, toe rad) of ``sfx`` in loop ``g`` at loop normalised time ``cyc``."""
        off = 0.0 if sfx == "R" else 0.5
        ankle, R, toe, _st = g.foot(self.sk, sfx, (cyc - off) % 1.0)
        return np.array(ankle, dtype=float), np.array(R, dtype=float), float(toe)

    def _src(self, sfx: str, t: float):
        return self._cycle_foot(self.gs, sfx, (self.h_in + t) / self.gs.frames)

    def _tgt(self, sfx: str, t: float):
        return self._cycle_foot(self.gt, sfx, self._phase_t(t))

    # ---- feet ------------------------------------------------------------------------------------------------
    def _planted(self, t: float):
        """The brake foot, planted from frame 0 to ``lift``: its contact world-still (source loop placement, d tied to
        the root travel), the pitch from the strike to flat, then toward the target loop's lift-off pitch."""
        import _anim_d304 as d304  # noqa: PLC0415

        g, sk = self.gs, self.sk
        off = 0.0 if self.foot == "R" else 0.5
        ph0 = ((self.h_in / g.frames) - off) % 1.0
        d0, p0, _l, toe0, _st = d304.foot_params(g, sk, self.foot, ph0)
        ph_l = (self._phase_t(self.lift) - (0.0 if self.foot == "R" else 0.5)) % 1.0
        _d, p_l, _l2, toe_l, _st2 = d304.foot_params(self.gt, sk, self.foot, min(ph_l, self.gt.beta - 1e-4))
        late = smooth(self.lift - 4.0, self.lift, t)
        pitch = p0 * (1.0 - smooth(0.0, 3.0, t)) + p_l * late
        toe = toe0 * (1.0 - smooth(0.0, 3.0, t)) + toe_l * late
        d = d0 - self.s(t)
        ankle, R = d304.place(g, sk, self.foot, d, pitch, 0.0)
        return np.array(ankle, dtype=float), np.array(R, dtype=float), A.rad(toe)

    def _swing(self, t: float, t0: float, t1: float, a_fn, b_fn, bump: float):
        """From program ``a_fn`` at t0 to ``b_fn`` at t1 through a recovery point under the body: two ankle Hermites
        (position and velocity continuous at both ends and at the recovery point, which sits between the two contacts,
        pulled toward the hips and raised by the gait's foot lift + ``bump``), the foot rotation slerped."""
        e = 1e-3
        a0, R0, k0 = a_fn(t0)
        a1, R1, k1 = b_fn(t1)
        v0 = (a0 - a_fn(t0 - e)[0]) / e
        v1 = (b_fn(t1 + e)[0] - a1) / e
        tm = t0 + RECOVER_AT * (t1 - t0)
        pm = 0.5 * (a0 + a1)
        pm[1] *= RECOVER_PULL
        pm[2] = max(a0[2], a1[2]) + (RECOVER_LIFT * self.gt.lift + bump) * self.sk.scale
        vm = (a1 - a0) / (t1 - t0)
        vm[2] = 0.0

        def seg(p0, q0, p1, q1, ta, tb):
            dur = tb - ta
            w = A.clamp01((t - ta) / dur)
            return np.array([A.hermite(p0[i], p1[i], q0[i] * dur, q1[i] * dur, w) for i in range(3)])
        if t1 - t0 < RECOVER_MIN:
            p = seg(a0, v0, a1, v1, t0, t1)
            p[2] += bump * self.sk.scale * math.sin(math.pi * A.clamp01((t - t0) / (t1 - t0))) ** 2
        else:
            p = seg(a0, v0, pm, vm, t0, tm) if t <= tm else seg(pm, vm, a1, v1, tm, t1)
        ws = smooth(0.0, 1.0, A.clamp01((t - t0) / (t1 - t0)))
        return p, mslerp(R0, R1, ws), k0 + (k1 - k0) * ws

    def brake_foot(self, t: float):
        if t <= self.lift:
            return self._planted(t), True
        return self._swing(t, self.lift, float(self.N), self._planted, lambda x: self._tgt(self.foot, x), 0.0), False

    def _src_planted(self, sfx: str, t: float):
        """A foot planted in the source loop at frame 0: contact world-still (d tied to the root travel), pitch and toe on
        the source loop's own schedule."""
        import _anim_d304 as d304  # noqa: PLC0415

        g, sk = self.gs, self.sk
        off = 0.0 if sfx == "R" else 0.5
        ph0 = ((self.h_in / g.frames) - off) % 1.0
        d0, *_ = d304.foot_params(g, sk, sfx, ph0)
        ph = min(ph0 + t / g.frames, g.beta - 1e-4)
        _d, pitch, _l, toe, _st = d304.foot_params(g, sk, sfx, ph)
        ankle, R = d304.place(g, sk, sfx, d0 - self.s(t), pitch, 0.0)
        return np.array(ankle, dtype=float), np.array(R, dtype=float), A.rad(toe)

    def other_foot(self, t: float):
        if t >= self.land:
            return self._tgt(self.other, t), True
        if t <= self.o_lift:
            return self._src_planted(self.other, t), True
        a_fn = (lambda x: self._src_planted(self.other, x)) if self.o_lift > 0.0 else (lambda x: self._src(self.other, x))
        return (self._swing(t, self.o_lift, self.land, a_fn, lambda x: self._tgt(self.other, x), self.tm["bump"]),
                False)

    # ---- pose ------------------------------------------------------------------------------------------------
    def pose(self, f: int) -> Pose:
        k, N = self.sk.scale, self.N
        t = float(f)
        w = smooth(0.0, float(N), t)
        a = self.ref_s[(self.h_in + f) % self.gs.frames]
        b = self.ref_t[(self.h_out - (N - f)) % self.gt.frames]
        import _anim_d304 as d304  # noqa: PLC0415

        pose = d304.blend_pose(a, b, w)
        env = math.sin(math.pi * t / N) ** 2
        sx = A.side_x(self.foot)
        # trunk against the change of speed (back while braking a forward run / pushing backward), pelvis into the
        # brake foot, hips over it
        ln = -self.sign * self.tm["lean"] * env
        add_rot(pose, "spine", rxd(-0.6 * ln))
        add_rot(pose, "chest", rxd(-0.4 * ln))
        add_rot(pose, "head", rxd(0.5 * ln))
        turn = -sx * self.tm["turn"] * env
        add_rot(pose, "hips", rzd(turn))
        add_rot(pose, "spine", rzd(-0.6 * turn))
        add_rot(pose, "chest", rzd(-0.4 * turn))
        pose.hip = pose.hip + v3(sx * self.tm["shift"] * k * env, 0.0, 0.0)
        for sfx, fn in ((self.foot, self.brake_foot), (self.other, self.other_foot)):
            (ankle, R, toe), _st = fn(t)
            pa, pb = a.legs[sfx].pole, b.legs[sfx].pole
            pose.legs[sfx] = LegIK(ankle=ankle, foot=R, toe=toe, pole=unit(A.lerp(pa, pb, w)))
        if f == 0:
            pose.legs = {s: a.legs[s] for s in a.legs}
        if f == N:
            pose.legs = {s: b.legs[s] for s in b.legs}
        return pose

    def stance(self, sfx: str, t: float) -> bool:
        """Is ``sfx`` planted at clip time t (for the slide check)?"""
        if sfx == self.foot:
            return t <= self.lift
        if t <= self.o_lift:
            return True
        if t < self.land:
            return False
        off = 0.0 if sfx == "R" else 0.5
        return (self._phase_t(t) - off) % 1.0 < self.gt.beta

    def root_fwd(self, t: float) -> float:
        """Root travel along the character's forward (m at 1.78 m): + = forward."""
        return self.sign * self.s(t)


def _gaits(sk: Skeleton) -> dict:
    """The four loops' gaits exactly as the library builds them."""
    import _anim_d304 as d304  # noqa: PLC0415
    import _anim_humanoid as H  # noqa: PLC0415
    from anim_humanoid import CLIPS as FULL  # noqa: PLC0415

    G = H.gaits(FULL)
    return {"walk": G["walk"], "run": G["run"], "walk_back": G["walk_back"],
            "run_b": d304.dir_gait(sk, G["run"], d304.RUN_SHAPE, d304.DIRS["b"])}


def reversal(sk: Skeleton, solver: Solver, name: str, gaits: dict | None = None, refs: dict | None = None) -> Reversal:
    import _anim_d304 as d304  # noqa: PLC0415

    fam, src, tgt, foot = SPECS[name]
    tm = TIMING[fam]
    G = gaits or _gaits(sk)
    refs = refs if refs is not None else {}
    for n in (src, tgt):
        if n not in refs:
            refs[n] = d304.ref_cycle(solver, G[n])
    gs, gt = G[src], G[tgt]
    other = "L" if foot == "R" else "R"
    N = tm["N"]
    h_in = _entry(gs.frames, foot)
    h_out, land = _exit(gt.frames, N, tm["land"], other)
    v_s, v_t = gs.speed / A.FPS, gt.speed / A.FPS
    off = 0.0 if foot == "R" else 0.5
    # the brake foot lifts on the target loop's schedule (its own phase = beta), the last time before N
    lift_ph = (off + gt.beta) % 1.0
    t_lift = N - ((h_out / gt.frames - lift_ph) % 1.0) * gt.frames
    r = Reversal(name, gs, gt, refs[src], refs[tgt], foot, other, N, h_in, h_out, float(tm["push"]), land, t_lift,
                 Travel2(v_s, v_t, tm["push"], land), tm, 1.0 if gs.direction[1] > 0 else -1.0)
    r.sk = sk
    # the other foot: still planted at frame 0 in a walk (double support): it lifts on the source loop's schedule
    o_off = 0.0 if other == "R" else 0.5
    o_ph = ((h_in / gs.frames) - o_off) % 1.0
    r.o_lift = (gs.beta - o_ph) * gs.frames if o_ph < gs.beta else 0.0
    # push: the root travel that puts the brake foot's contact on the target loop's lift-off spot when it lifts (so the
    # stance never spreads wider than the target loop's own: no hips lowered for reach)
    r.push = _solve_push(r, v_s, v_t) if tm["solve_push"] else float(tm["push"])
    r.s = Travel2(v_s, v_t, r.push, land)
    return r


def _solve_push(r: Reversal, v_s: float, v_t: float) -> float:
    import _anim_d304 as d304  # noqa: PLC0415

    gs, sk = r.gs, r.sk
    y_t = float(r._tgt(r.foot, r.lift)[0][1])
    off = 0.0 if r.foot == "R" else 0.5
    d0, *_ = d304.foot_params(gs, sk, r.foot, ((r.h_in / gs.frames) - off) % 1.0)
    y0 = float(d304.place(gs, sk, r.foot, 0.0, 0.0, 0.0)[0][1])
    y_d0 = float(d304.place(gs, sk, r.foot, d0, 0.0, 0.0)[0][1])
    dy = (y_d0 - y0) / d0 if abs(d0) > 1e-9 else gs.direction[1]
    want_s = d0 - (y_t - y0) / dy                       # root travel (source direction) at the brake foot's lift
    lo, hi = 2.0, min(r.land, r.lift) - 1.0

    def f(p: float) -> float:
        return Travel2(v_s, v_t, p, r.land)(r.lift) - want_s
    if f(lo) * f(hi) > 0:
        return lo if abs(f(lo)) < abs(f(hi)) else hi
    for _ in range(60):
        m = 0.5 * (lo + hi)
        if f(lo) * f(m) <= 0:
            hi = m
        else:
            lo = m
    return 0.5 * (lo + hi)


def clips(sk: Skeleton, solver: Solver, table: dict) -> dict[str, Clip]:
    import _anim_d304 as d304  # noqa: PLC0415

    out: dict[str, Clip] = {}
    names = [n for n in NAMES if n in table]
    if not names:
        return out
    G, refs = _gaits(sk), {}
    for name in names:
        row = table[name]
        N, ev = int(row["frames"]), dict(row.get("events", {}))
        r = reversal(sk, solver, name, G, refs)
        assert N == r.N and abs(r.push - float(ev["push"])) < 1.0, name
        poses = [r.pose(f) for f in range(N + 1)]
        d304.reach_fix_pinned(solver, poses, (0, N))
        clip = Clip(name, N, False, lambda f, poses=poses: poses[f].copy(), 0.0, None, ev, reach_fix=False)
        clip.reversal = r
        out[name] = clip
    return out


# =============================================================================================
# checks and SOURCE.txt notes
# =============================================================================================
def root_curve(r: Reversal) -> list[float]:
    return [r.root_fwd(float(f)) - r.root_fwd(0.0) for f in range(r.N + 1)]


def slide_mm(sk: Skeleton, r: Reversal, frames: list) -> float:
    """Worst motion (mm/frame) of a planted foot's ankle in world space (root moved by the curve), skipping the frame a
    foot's pivot changes."""
    worst = 0.0
    for sfx in ("L", "R"):
        prev = None
        for f, s in enumerate(frames):
            if not r.stance(sfx, float(f)):
                prev = None
                continue
            gp = sk.ground(sfx)
            pts = [s.P[f"foot.{sfx}"] + s.W[f"foot.{sfx}"] @ (gp[p] - gp["ankle"]) for p in ("heel", "ball")]
            fwd = np.array([0.0, r.root_fwd(float(f)) * sk.scale, 0.0])
            pts = [p + fwd for p in pts]
            i = 0 if float(pts[0][2]) <= float(pts[1][2]) else 1
            if prev is not None and prev[0] == i:
                worst = max(worst, float(np.linalg.norm(pts[i] - prev[1])) * 1000.0)
            prev = (i, pts[i])
    return worst


def hip_drop_mm(r: Reversal, frames: list, keep: dict) -> float:
    """How far (mm) the hips go below the lower of the two loops' lowest hip height."""
    lows = []
    for n in (("run", "run_b") if r.N == TIMING["run"]["N"] else ("walk", "walk_back")):
        if n in keep:
            lows.append(min(float(s.P["hips"][2]) for s in keep[n].frames))
    if not lows:
        return 0.0
    low = min(lows)
    return max(0.0, (low - min(float(s.P["hips"][2]) for s in frames)) * 1000.0)


def check_row(sk: Skeleton, table: dict, name: str, clip: Clip, baked, keep: dict) -> str:
    from _anim_d304 import pose_err  # noqa: PLC0415

    r = clip.reversal
    _fam, src, tgt, _foot = SPECS[name]
    txt = f" slide={slide_mm(sk, r, baked.frames):.2f}mm/f hip_drop={hip_drop_mm(r, baked.frames, keep):.1f}mm"
    if src in keep:
        txt += f" in_err={pose_err(baked.frames[0], keep[src].frames[r.h_in]):.2f}mm"
    if tgt in keep:
        txt += f" out_err={pose_err(baked.frames[r.N], keep[tgt].frames[r.h_out]):.2f}mm"
    return txt


def source_notes(sk: Skeleton, table: dict, clips_: dict, baked_by_name: dict, keep: dict) -> dict[str, str]:
    out: dict[str, str] = {}
    rows = []
    for name in NAMES:
        c = clips_.get(name)
        if c is None or not hasattr(c, "reversal"):
            continue
        r = c.reversal
        _fam, src, tgt, foot = SPECS[name]
        curve = root_curve(r)
        out[f"curve.{name}"] = (f"root_m={','.join(f'{x:.4f}' for x in curve)} total_m={curve[-1]:.3f} "
                                f"dir_godot=(0,0,-1)")
        b = baked_by_name.get(name)
        drop = hip_drop_mm(r, b.frames, keep) if b is not None else float("nan")
        rows.append(f"{name}: {src}->{tgt} brake={foot} frames={r.N} u_in={r.h_in / r.gs.frames:.4f} "
                    f"({src} frame {r.h_in}) u_out={r.h_out / r.gt.frames:.4f} ({tgt} frame {r.h_out}) "
                    f"events=foot_plant@0,push@{table[name]['events']['push']},done@{r.N} other_lands@{r.land:.1f} brake_lifts@{r.lift:.1f} "
                    f"root_total_m={curve[-1]:+.3f} max_hip_drop_mm={drop:.1f}")
    out["loco_reverse"] = (
        "characters v1.27 locomotion reversals (fixed facing; replace the crossfade between opposite strides, which folds "
        "the knees): run_reverse_l/_r run->run_b, run_reverse_back_l/_r run_b->run, walk_reverse_l/_r walk->walk_back, "
        "walk_reverse_back_l/_r walk_back->walk; _l = the left foot brakes. Frame 0 IS the source loop at u_in (the brake "
        "foot's touch-down: R at 0, L at frames/2 rounded up) and the last frame IS the target loop at u_out, so: start "
        "the clip when the source loop reaches u_in (pick _r or _l by whichever brake foot comes next: R at u 0, L at "
        "u 0.5 + 0.5/frames), play it without a crossfade, then switch to the target loop seeked to u_out (no crossfade). "
        "The root follows curve.<clip>: metres along the character's forward (+ = forward, Godot -Z), one value per "
        "frame from 0; its speed equals the source loop's at frame 0, crosses 0 at `push` and equals the target loop's "
        "from the other foot's landing on (planted feet stay world-still at that motion). Use it for a travel reversal "
        "of 135 deg or more; under that, keep the 8-way switch. Events: foot_plant (frame 0), push (the root speed "
        "crosses 0), done (the last frame). Hips: never lower than max_hip_drop_mm below the loops' lowest hip height. "
        + " | ".join(rows))
    return out
