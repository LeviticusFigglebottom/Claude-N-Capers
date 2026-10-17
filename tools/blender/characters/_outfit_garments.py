"""Soft garments for D1-02 characters: shirts and knits, collars, cuffs, trousers, shoes, gloves,
tailored jackets and coats, skirts and dresses, gilet, apron. Blender only (``mathutils``).

Every builder takes the character's ``Fit`` and returns plain ``_outfit.Mesh`` data (skinned later
by nearest-skin weights). Sizes are metres at 1.78 m and scale with ``fit.k``.
"""

from __future__ import annotations

import itertools
import math
from collections.abc import Callable

import _outfit as o
from _outfit import Fit, Hull, Mesh, Shell, Vector, clamp, lerp, smoothstep

UP = o.UP


# =============================================================================================
# helpers
# =============================================================================================
def _arm_param(fit: Fit, p: Vector, sfx: str) -> float:
    """0 at the shoulder joint, 1 at the elbow, 2 at the wrist (projected on the bones)."""
    sh, el, wr = Vector(fit.J[f"shoulder.{sfx}"]), Vector(fit.J[f"elbow.{sfx}"]), Vector(fit.J[f"wrist.{sfx}"])
    a = (p - sh).dot((el - sh).normalized()) / (el - sh).length
    if a <= 1.0:
        return a
    return 1.0 + (p - el).dot((wr - el).normalized()) / (wr - el).length


def _side(p: Vector) -> str:
    return "R" if p.x > 0 else "L"


def classify_loops(m: Mesh) -> dict[str, list[int]]:
    """Name a garment's boundary loops: neck/top (highest centred), hem (lowest centred),
    ``cuff.R``/``cuff.L``/``leg.R``/``leg.L`` by side and height."""
    out: dict[str, list[int]] = {}
    centred = []
    for loop in o.boundary_loops(m.f):
        c = o.loop_centre(m, loop)
        if abs(c.x) < 0.05:
            centred.append((c.z, loop))
        else:
            side = "R" if c.x > 0 else "L"
            kind = "leg" if c.z < 0.75 else "cuff"
            key = f"{kind}.{side}"
            if key in out:
                key += "_2"
            out[key] = loop
    centred.sort(key=lambda t: t[0])
    if centred:
        out["hem"] = centred[0][1]
        out["top"] = centred[-1][1]
        for i, (_z, loop) in enumerate(centred[1:-1]):
            out[f"mid{i}"] = loop
    return out


class Neck:
    """The neck surface between the body rings ``neck`` (base) and ``neck_top``."""

    def __init__(self, fit: Fit) -> None:
        self.base = fit.ring("neck")
        self.top = fit.ring("neck_top")
        self.cb = sum(self.base, Vector()) / len(self.base)
        self.ct = sum(self.top, Vector()) / len(self.top)
        self.ang_b = sorted((o.angle_of(p.x - self.cb.x, p.y - self.cb.y), i) for i, p in enumerate(self.base))
        self.ang_t = sorted((o.angle_of(p.x - self.ct.x, p.y - self.ct.y), i) for i, p in enumerate(self.top))

    @staticmethod
    def _interp(pts: list[Vector], angs: list[tuple[float, int]], th: float) -> Vector:
        th = o.wrap(th)
        n = len(angs)
        for j in range(n):
            a0, i0 = angs[j]
            a1, i1 = angs[(j + 1) % n]
            span = o.wrap(a1 - a0) if j == n - 1 else a1 - a0
            d = o.wrap(th - a0)
            if 0.0 <= d <= span + 1e-12:
                t = d / span if span > 1e-12 else 0.0
                return pts[i0].lerp(pts[i1], t)
        return pts[angs[0][1]]

    def point(self, th: float, t: float, radial: float = 0.0) -> Vector:
        p = self._interp(self.base, self.ang_b, th).lerp(self._interp(self.top, self.ang_t, th), t)
        c = self.cb.lerp(self.ct, t)
        r = Vector((p.x - c.x, p.y - c.y, 0.0))
        r = r.normalized() if r.length > 1e-9 else Vector((math.sin(th), math.cos(th), 0.0))
        return p + r * radial

    def radial(self, th: float) -> Vector:
        return Vector((math.sin(th), math.cos(th), 0.0))

    def axis(self, z: float) -> Vector:
        t = clamp((z - self.cb.z) / max(self.ct.z - self.cb.z, 1e-4), -1.0, 2.0)
        return self.cb.lerp(self.ct, t)


# =============================================================================================
# upper body: shirts, knits
# =============================================================================================
def upper_shell(fit: Fit, mat: str | Callable[[Vector, str], str], bottom_z: float, sleeve: float = 2.0,
                base: float = 0.0055, ease: float = 1.0, arm_ease: float = 1.0, waist_blouse: float = 0.004,
                hull: Hull | None = None, min_off: float = 0.003, iters: int = 5,
                top_cut: Callable[[Vector], bool] | None = None, sleeveless: bool = False,
                extra: Callable[[Vector, str], float] | None = None) -> Shell:
    """Torso (+ sleeves) shell from the neck ring down to ``bottom_z``. ``sleeve`` is the arm
    parameter of the cuff (1 = elbow, 2 = wrist; 0.5 = short sleeve). ``top_cut(c)`` removes faces
    (necklines, armholes)."""
    k = fit.k
    waist = fit.ring_centre("waist").z

    def keep(r: str, c: Vector, _i: int) -> bool:
        if top_cut is not None and top_cut(c):
            return False
        if r in ("torso", "pelvis"):
            return c.z > bottom_z
        if sleeveless:
            return False
        if r in ("upper_arms", "forearms"):
            return _arm_param(fit, c, _side(c)) < sleeve
        return False

    faces = fit.faces_where(keep)

    def off(p: Vector, _n: Vector, r: str) -> float:
        d = base * ease
        if r in ("torso", "pelvis", "neck"):
            d += waist_blouse * smoothstep(waist + 0.16 * k, waist - 0.02 * k, p.z) * ease
            d += 0.002 * ease * smoothstep(-0.02, -0.10, p.y - fit.ring_centre("chest").y)   # back ease
        else:
            a = _arm_param(fit, p, _side(p))
            d += arm_ease * (0.0015 + 0.0045 * smoothstep(0.6, 2.0, a))
        if extra is not None:
            d += extra(p, r)
        return d

    sh = Shell(fit, faces, off, mat)
    o.drape(sh.mesh, hull or Hull(fit), min_off, max_off=0.05, iters=iters)
    return sh


def box_out(m: Mesh, z_full: float, z_zero: float, side_add: float, front_add: float, back_add: float,
            power: float = 4.0, z_min: float = -1.0) -> dict:
    """Make a torso shell boxy (stab vests, plate carriers): below ``z_full`` every vertex is pushed
    out to a superellipse cross-section (exponent ``power``) that encloses the shell's own widest
    extents plus ``side_add`` / ``front_add`` / ``back_add``; the effect fades out up to ``z_zero``
    (shoulders and armholes stay fitted). Vertices are only ever moved outwards. Returns the box."""
    rows = [p for p in m.v if z_min < p.z < z_zero]
    if not rows:
        return {}
    hw = max(abs(p.x) for p in rows) + side_add
    yf = max(p.y for p in rows) + front_add
    yb = min(p.y for p in rows) - back_add
    cy, hd = 0.5 * (yf + yb), 0.5 * (yf - yb)
    for i, p in enumerate(m.v):
        if p.z >= z_zero or p.z <= z_min:
            continue
        f = smoothstep(z_zero, z_full, p.z)
        dx, dy = p.x, p.y - cy
        r = math.hypot(dx, dy)
        if r < 1e-6:
            continue
        sa, ca = abs(dx) / r, abs(dy) / r
        r_box = ((sa / hw) ** power + (ca / hd) ** power) ** (-1.0 / power)
        r_new = max(r, lerp(r, r_box, f))
        m.v[i] = Vector((dx * r_new / r, cy + dy * r_new / r, p.z))
    return {"half_w": hw, "front_y": yf, "back_y": yb, "cy": cy}


def bottom_tuck(m: Mesh, loop: list[int], z: float) -> None:
    o.straighten_loop(m, loop, iters=3)
    for v in loop:
        m.v[v] = Vector((m.v[v].x, m.v[v].y, z))


def cuff_band(m: Mesh, loop: list[int], hull: Hull, length: float, lift: float, mat: str,
              rows: int = 2) -> list[int]:
    """A slightly raised band running ``length`` back into the garment from the opening ``loop``
    (shirt cuffs, knit ribbing, waistbands). Returns the band's outer edge ring."""
    nrm = o.vertex_normals(m.v, m.f)
    inward: dict[int, Vector] = {i: Vector() for i in loop}
    sl = set(loop)
    for f in m.f:
        c = sum((m.v[i] for i in f), Vector()) / len(f)
        for i in f:
            if i in sl:
                inward[i] += c - m.v[i]
    rings_pts: list[list[Vector]] = []
    for r in range(rows + 1):
        s = length * r / rows
        pts = []
        for v in loop:
            n = nrm[v]
            t = inward[v] - n * inward[v].dot(n)
            t = t.normalized() if t.length > 1e-9 else Vector()
            q = m.v[v] + t * s + n * 0.01
            hit = hull.cast(q, -n, 0.05)
            base = hit[0] if hit[0] is not None else m.v[v] + t * s
            pts.append(base + n * lift)
        rings_pts.append(pts)
    ids = [m.ring(pts) for pts in rings_pts]
    # orientation: same winding as the garment faces next to the loop
    for a, b in itertools.pairwise(ids):
        k = len(loop)
        for i in range(k):
            j = (i + 1) % k
            m.f.append((a[i], a[j], b[j], b[i]))
            m.m.append(mat)
    return ids[0]


def fix_band_winding(m: Mesh, first_face: int, outward_ref: Callable[[Vector], Vector]) -> None:
    """Flip faces from ``first_face`` on whose normals point against ``outward_ref(centroid)``."""
    for fi in range(first_face, len(m.f)):
        f = m.f[fi]
        c = sum((m.v[i] for i in f), Vector()) / len(f)
        if o.newell(m.v, f).dot(outward_ref(c)) < 0:
            m.f[fi] = tuple(reversed(f))


def shirt_collar(m: Mesh, fit: Fit, neck_ids: list[int], hull: Hull, mat: str, point_len: float = 0.062,
                 back_len: float = 0.034, stand: float = 0.60, spread: float = 0.30, cols: int = 44) -> None:
    """Stand + fold-over collar with points, on the shirt's neck ring (``neck_ids`` = shell vertex
    ids of the body ring ``neck``, in ring order)."""
    k = fit.k
    nk = Neck(fit)
    thetas = [o.angle_of(m.v[i].x - nk.cb.x, m.v[i].y - nk.cb.y) for i in neck_ids]

    def t_top(th: float) -> float:
        return lerp(stand - 0.16, stand, smoothstep(0.0, 1.2, abs(o.wrap(th))))

    rad = 0.0045 * k
    r1 = m.ring([nk.point(th, 0.30, rad) for th in thetas])
    r2 = m.ring([nk.point(th, t_top(th), rad) for th in thetas])
    f0 = len(m.f)
    m.band(neck_ids, r1, mat)
    m.band(r1, r2, mat)
    fix_band_winding(m, f0, lambda c: (c - nk.axis(c.z)) * Vector((1, 1, 0)) + Vector((0, 0, 0.001)))
    # fold-over part: open sheet around the back, collar points at the front
    stand_hull = Hull(fit, [m])
    rows = 4
    grid: list[list[int]] = []
    for j in range(rows):
        tj = j / (rows - 1)
        th0 = lerp(0.075, spread, tj ** 0.9)
        row = []
        for c in range(cols + 1):
            frac = c / cols
            th = th0 + frac * (2 * math.pi - 2 * th0)
            ff = smoothstep(1.1, 0.15, abs(o.wrap(th)))           # 1 at the front
            top = nk.point(th, t_top(th) + 0.02, rad + 0.0022 * k)
            length = lerp(back_len, point_len, ff) * k
            if c in (0, cols):
                length += 0.010 * k * tj
            drop = length * tj
            out = (0.003 + 0.016 * tj + 0.008 * ff * tj) * k
            p = top + nk.radial(th) * out - UP * drop
            if j > 0:
                p = o.push_out(p, stand_hull, 0.0024 * k)
            row.append(m.add(p))
        grid.append(row)
    f0 = len(m.f)
    for a, b in itertools.pairwise(grid):
        m.band(a, b, mat, closed=False)
    fix_band_winding(m, f0, lambda c: (c - nk.axis(c.z + 0.03)) + Vector((0, 0, 0.02)))


def band_collar(m: Mesh, fit: Fit, neck_ids: list[int], mat: str, height: float = 0.5, rad: float = 0.006,
                roll: float = 0.0) -> list[int]:
    """Plain stand collar / knit neckband on the neck ring; returns its top ring."""
    nk = Neck(fit)
    thetas = [o.angle_of(m.v[i].x - nk.cb.x, m.v[i].y - nk.cb.y) for i in neck_ids]
    r1 = m.ring([nk.point(th, height * 0.5, rad * fit.k + roll * 0.5) for th in thetas])
    r2 = m.ring([nk.point(th, height, rad * fit.k + roll) for th in thetas])
    f0 = len(m.f)
    m.band(neck_ids, r1, mat)
    m.band(r1, r2, mat)
    fix_band_winding(m, f0, lambda c: (c - nk.axis(c.z)) * Vector((1, 1, 0)) + Vector((0, 0, 0.001)))
    return r2


# =============================================================================================
# lower body: trousers, skirts
# =============================================================================================
def trousers(fit: Fit, mat: str, top_z: float, hem_r: float = 0.060, base: float = 0.0065,
             hull: Hull | None = None, seat: float = 0.004, extra: Callable[[Vector, str], float] | None = None,
             shorts: bool = False) -> Shell:
    """Trouser shell: pelvis + legs down to the ankle ring, then straightened below the knee."""
    k = fit.k

    def keep(r: str, c: Vector, _i: int) -> bool:
        if r in ("torso", "pelvis"):
            return c.z < top_z
        if shorts:
            return r == "thighs"
        return r in ("thighs", "shins")

    faces = fit.faces_where(keep)

    def off(p: Vector, n: Vector, r: str) -> float:
        d = base
        if r in ("pelvis", "torso", "thighs"):
            d += seat * smoothstep(0.2, -0.6, n.y) * smoothstep(0.65 * k, 0.85 * k, p.z)
        if extra is not None:
            d += extra(p, r)
        return d

    sh = Shell(fit, faces, off, mat)
    m = sh.mesh
    if not shorts:
        for sfx in ("L", "R"):
            kc = fit.ring_centre(f"knee.{sfx}")
            ac = fit.ring_centre(f"ankle.{sfx}")
            axis = (ac - kc)
            ln = axis.length
            axis.normalize()
            knee_r = sum((p - kc).length for p in fit.ring(f"knee.{sfx}")) / 32.0 + base
            for i, v in enumerate(sh.src):
                if fit.VR[v] != "shins":
                    continue
                p = m.v[i]
                if (p.x > 0) != (sfx == "R"):
                    continue
                s = (p - kc).dot(axis) / ln
                if s < -0.15:
                    continue
                foot = kc + axis * (s * ln)
                rv = p - foot
                rr = rv.length
                target = lerp(knee_r + 0.004 * k, hem_r * k, smoothstep(0.0, 1.0, s))
                w = smoothstep(-0.15, 0.25, s)
                newr = max(rr, lerp(rr, target, w))
                m.v[i] = foot + rv.normalized() * newr
    o.drape(m, hull or Hull(fit), 0.003 * k, max_off=0.06, iters=4)
    return sh


def trouser_hems(sh: Shell, fit: Fit, shoes_hull: Hull, mat: str, z_back: float = 0.042,
                 rows: int = 2) -> dict[str, list[int]]:
    """Extend each trouser leg below the ankle ring to a hem that is low at the heel and rests on
    the instep at the front (a smooth line), pushed clear of the shoe. Returns the hem loops."""
    m = sh.mesh
    k = fit.k
    out = {}
    for loop in o.boundary_loops(m.f):
        c = o.loop_centre(m, loop)
        if c.z > 0.3 * k:
            continue
        sfx = "R" if c.x > 0 else "L"
        rmax = max(math.hypot(m.v[v].x - c.x, m.v[v].y - c.y) for v in loop)
        hit = shoes_hull.cast(Vector((c.x, c.y + rmax, 0.4)), Vector((0, 0, -1)), 0.6)
        z_front = (hit[0].z + 0.006 * k) if hit[0] is not None else 0.08 * k
        z_front = max(z_front, z_back * k + 0.01 * k)
        prev = list(loop)
        for j in range(1, rows + 1):
            t = j / rows
            ids = []
            for v in loop:
                p = m.v[v]
                rv = Vector((p.x - c.x, p.y - c.y, 0.0))
                rr = rv.length
                rv.normalize()
                f = smoothstep(-0.3, 1.0, rv.y)
                ze = lerp(z_back * k, z_front, f)
                q = Vector((c.x + rv.x * rr * (1 + 0.03 * t), c.y + rv.y * rr * (1 + 0.03 * t), lerp(p.z, min(ze, p.z - 0.004), t)))
                q = o.push_out(q, shoes_hull, 0.004 * k)
                ids.append(m.add(q))
            for i in range(len(loop)):
                jj = (i + 1) % len(loop)
                m.f.append((prev[jj], prev[i], ids[i], ids[jj]))
                m.m.append(mat)
            prev = ids
        out[sfx] = prev
    return out


# =============================================================================================
# feet and hands
# =============================================================================================
def shoes(fit: Fit, mat: str, sole_mat: str, top_z: float = 0.095, base: float = 0.0065, toe: float = 0.014,
          sole_h: float = 0.016, welt: float = 0.0045, heel: float = 0.0, boot: bool = False,
          arch: float | None = None, toe_h: float | None = None, cap_line: bool | None = None,
          edge_mat: str | None = None) -> Mesh:
    """Shoes (or boots with ``boot`` and a higher ``top_z``): an offset shell of the foot with a
    longer, flatter toe box, a sole with a protruding welt edge (chamfered top and bottom), a
    separate heel block (the sole edge steps up by ``arch`` under the instep, so the heel and the
    forefoot sole read from the side) and a rolled collar on the opening. Dress shoes get a toe-cap
    seam (``cap_line``) and a toe box flattened to ``toe_h`` at the tip; ``edge_mat`` colours the
    sole edge (dress shoes: a dark leather edge; boots: ``sole_mat``)."""
    k = fit.k
    sole_top = sole_h * k
    arch = (0.009 if boot else 0.007) if arch is None else arch
    toe_h = (0.046 if boot else 0.036) if toe_h is None else toe_h
    cap_line = (not boot) if cap_line is None else cap_line
    edge_mat = edge_mat or (sole_mat if boot else "leather_dark")

    def keep(r: str, c: Vector, _i: int) -> bool:
        if r == "feet":
            return c.z > sole_top * 0.7
        if r == "shins":
            return c.z < top_z * k
        return False

    faces = fit.faces_where(keep)
    out = Mesh()
    for sfx in ("L", "R"):
        sx = 1.0 if sfx == "R" else -1.0
        ball = Vector(fit.J[f"ball.{sfx}"])
        tip = Vector(fit.J[f"toe_tip.{sfx}"])
        side_faces = [fi for fi in faces if (sum((fit.P[v] for v in fit.F[fi]), Vector()).x > 0) == (sx > 0)]

        def off(p: Vector, n: Vector, r: str) -> float:
            d = base * k
            if r == "shins":
                d += 0.002 * k if boot else 0.0
            return d

        sh = Shell(fit, side_faces, off, mat)
        m = sh.mesh
        for i, p in enumerate(m.v):
            f = smoothstep(ball.y - 0.04 * k, tip.y + 0.01 * k, p.y)
            q = Vector((p.x, p.y + toe * k * f, p.z))
            # toe box: flat-topped, sloping down to ``toe_h`` at the tip, forefoot a little wider
            ft = smoothstep(ball.y - 0.02 * k, tip.y + 0.02 * k, p.y)
            cap = lerp(0.075 * k, toe_h * k, ft)
            if q.z > sole_top + 0.004 * k and ft > 0.0:
                q.z = lerp(q.z, min(q.z, cap), smoothstep(0.0, 0.4, ft))
            q.x += (p.x - ball.x) * 0.10 * f
            if heel:
                q.z += heel * smoothstep(ball.y, ball.y - 0.12 * k, p.y)
            m.v[i] = q
        o.drape(m, Hull(fit), 0.003 * k, max_off=0.05, iters=3)
        loops = o.boundary_loops(m.f)
        loops.sort(key=lambda lp: o.loop_centre(m, lp).z)
        bottom, top = loops[0], loops[-1]
        # sole: flatten the bottom loop to the sole top, then welt, chamfered edge and bottom
        o.straighten_loop(m, bottom, iters=2)
        for v in bottom:
            m.v[v] = Vector((m.v[v].x, m.v[v].y, sole_top))
        c = o.loop_centre(m, bottom)
        y_back = min(m.v[v].y for v in bottom)
        heel_front = y_back + 0.058 * k
        ball_back = ball.y - 0.035 * k
        ring_w, ring_t, ring_s, ring_b, ring_i = [], [], [], [], []
        ch = min(0.0025 * k, sole_top * 0.2)
        for v in bottom:
            p = m.v[v]
            r = Vector((p.x - c.x, p.y - c.y, 0.0))
            r.normalize()
            # the instep: sole edge steps up between the heel block and the forefoot sole
            lift = arch * k * smoothstep(heel_front - 0.002 * k, heel_front + 0.004 * k, p.y) * \
                smoothstep(ball_back + 0.01 * k, ball_back - 0.006 * k, p.y)
            z_b = heel * 1.0 if (heel and p.y < c.y - 0.03 * k) else lift
            wo = welt * k
            ring_w.append(m.add(Vector((p.x + r.x * (wo - ch), p.y + r.y * (wo - ch), sole_top))))
            ring_t.append(m.add(Vector((p.x + r.x * wo, p.y + r.y * wo, sole_top - ch))))
            ring_s.append(m.add(Vector((p.x + r.x * wo, p.y + r.y * wo, z_b + ch))))
            ring_b.append(m.add(Vector((p.x + r.x * (wo - ch), p.y + r.y * (wo - ch), z_b))))
            # D-115 clip audit: only the sole's outer band steps up at the instep; inside the upper's outline the
            # bottom stays on the ground, else the foot's skin (sole at z = 0) hung below the lifted arch and showed
            # whenever a sole faced the camera (kneel_cuffed, surrender, death_crouch)
            z_i = z_b if (heel and p.y < c.y - 0.03 * k) else 0.0
            ring_i.append(m.add(Vector((p.x - r.x * 0.002 * k, p.y - r.y * 0.002 * k, z_i))))
        nb = len(bottom)
        for i in range(nb):
            j = (i + 1) % nb
            m.f.append((bottom[j], bottom[i], ring_w[i], ring_w[j]))
            m.m.append(sole_mat)
            for ra, rb in ((ring_w, ring_t), (ring_t, ring_s), (ring_s, ring_b)):
                m.f.append((ra[j], ra[i], rb[i], rb[j]))
                m.m.append(edge_mat)
        pole = m.add(Vector((c.x, c.y, 0.0)))
        for i in range(nb):
            j = (i + 1) % nb
            m.f.append((ring_b[j], ring_b[i], ring_i[i], ring_i[j]))
            m.m.append(sole_mat)
            m.f.append((ring_i[j], ring_i[i], pole))
            m.m.append(sole_mat)
        o.straighten_loop(m, top, iters=2)
        o.hem(m, top, thick=0.004 * k, depth=0.012 * k)
        if cap_line:
            # toe-cap seam across the toe box (a cap-toe dress shoe)
            sh_hull = Hull(fit, [m], body_regions=set())
            y_cap = tip.y + toe * k - 0.04 * k
            hw = 0.05 * k
            path = []
            for t in range(9):
                x = ball.x + sx * 0.004 * k + lerp(-hw, hw, t / 8)
                hit = sh_hull.cast(Vector((x, y_cap - 0.006 * k * math.cos(math.pi * (t / 8 - 0.5)), 0.2)),
                                   Vector((0, 0, -1)), 0.4)
                if hit[0] is not None and hit[0].z > sole_top + 0.006 * k:
                    path.append(hit[0])
            if len(path) >= 3:
                o.strip(m, sh_hull, path, 0.0022 * k, 0.0012 * k, mat, segs_across=1, chamfer=0.0008 * k,
                        cast_back=0.03)
        out.extend(m)
    return out


def gloves(fit: Fit, mat: str, cuff_len: float = 0.045, base: float = 0.0022, cuff_off: float = 0.004) -> Mesh:
    """Gloves: hand shell plus a cuff over the wrist."""
    k = fit.k

    def keep(r: str, c: Vector, _i: int) -> bool:
        if r == "hands":
            return True
        if r == "forearms":
            sfx = _side(c)
            return _arm_param(fit, c, sfx) > 2.0 - cuff_len / 0.255
        return False

    faces = fit.faces_where(keep)

    def off(p: Vector, n: Vector, r: str) -> float:
        if r == "forearms":
            return (base + cuff_off) * k
        return base * k

    sh = Shell(fit, faces, off, mat)
    m = sh.mesh
    for loop in o.boundary_loops(m.f):
        o.straighten_loop(m, loop, iters=2)
        o.hem(m, loop, thick=0.002 * k, depth=0.008 * k)
    return m


# =============================================================================================
# details: placket, pockets, tie
# =============================================================================================
def front_path(hull: Hull, x: float, z0: float, z1: float, step: float = 0.02, lift: float = 0.0) -> list[Vector]:
    n = max(2, int(abs(z1 - z0) / step) + 1)
    pts = []
    for i in range(n):
        z = lerp(z0, z1, i / (n - 1))
        hit = hull.cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
        pts.append(hit[0] + Vector((0, lift, 0)) if hit[0] is not None else Vector((x, 0.1, z)))
    return pts


def pocket(m: Mesh, hull: Hull, x: float, z: float, w: float, h: float, mat: str, flap: bool = True,
           flap_mat: str | None = None, k: float = 1.0) -> Vector:
    """Chest pocket (front) with an optional pointed flap. Returns the flap tip point (button)."""
    org = Vector((x, 0.0, z))
    u, v = Vector((1, 0, 0)), Vector((0, 0, 1))
    o.patch(m, hull, org, u, v, o.rounded_rect(w * k, h * k, 0.008 * k, 2), 0.0022 * k, mat,
            cast_dir=Vector((0, -1, 0)), rings=2, chamfer=0.002 * k)
    tip = org
    if flap:
        fz = z + h * k * 0.5 - 0.012 * k
        o.patch(m, hull, Vector((x, 0.0, fz)), u, v,
                o.rounded_rect((w + 0.006) * k, 0.036 * k, 0.005 * k, 2, point=0.012 * k),
                0.0045 * k, flap_mat or mat, cast_dir=Vector((0, -1, 0)), rings=2, chamfer=0.002 * k)
        tip = Vector((x, 0.0, fz - 0.018 * k - 0.012 * k + 0.004 * k))
    return tip


def tie(m: Mesh, hull: Hull, fit: Fit, z_top: float, z_tip: float, mat: str, width: float = 0.078) -> Vector:
    """Tie blade from under the knot down to ``z_tip``; returns the knot centre."""
    k = fit.k
    path = front_path(hull, 0.0, z_top, z_tip, step=0.018 * k)

    def hw(t: float) -> float:
        body_w = lerp(0.016, width * 0.5, smoothstep(0.0, 0.85, t) ** 0.8) * k
        return body_w * (1.0 - 0.92 * smoothstep(0.93, 1.0, t))

    o.strip(m, hull, path, hw, 0.0035 * k, mat, side_hint=Vector((1, 0, 0)), segs_across=2, chamfer=0.0025 * k)
    return path[0]


# =============================================================================================
# tailored jackets, coats, knits, gilet, dress, apron, vests
# =============================================================================================
def delete_faces(m: Mesh, pred: Callable[[Vector], bool]) -> None:
    """Remove faces whose centroid matches ``pred`` and drop unused vertices (ids are remapped)."""
    keep_f = []
    for f, mt in zip(m.f, m.m):
        c = sum((m.v[i] for i in f), Vector()) / len(f)
        if not pred(c):
            keep_f.append((f, mt))
    used = sorted({i for f, _mt in keep_f for i in f})
    remap = {v: n for n, v in enumerate(used)}
    m.v = [m.v[i] for i in used]
    m.w = [m.w[i] for i in used]
    m.a = [m.a[i] for i in used]
    m.f = [tuple(remap[i] for i in f) for f, _mt in keep_f]
    m.m = [mt for _f, mt in keep_f]


def snap_opening(m: Mesh, half_w: Callable[[float], float], cy: float, z0: float, z1: float, hull: Hull | None = None,
                 clearance: float = 0.004) -> None:
    """Straighten the edges of a front opening: boundary vertices in front (y > cy) with z in
    [z0, z1] move sideways onto x = +-half_w(z)."""
    for loop in o.boundary_loops(m.f):
        for v in loop:
            p = m.v[v]
            if p.y < cy or not z0 <= p.z <= z1:
                continue
            w = half_w(p.z)
            if abs(abs(p.x) - w) > 0.03:
                continue
            q = Vector((math.copysign(w, p.x) if abs(p.x) > 1e-6 else w, p.y, p.z))
            m.v[v] = o.push_out(q, hull, clearance) if hull is not None else q


#: D-116: a below-knee coat's share of thigh weight that moves to the shin past the knee (seated drape)
SEATED_SHIN = 0.8
#: the seated drape's centre band (m) mixing both legs: near zero, so each front-split edge (at the centre line) stays
#: on its own leg seated; a wider band left both edges half on each thigh, a strip from the waist to between the knees
SEATED_CENTRE = 0.008

#: D-116 stride drape (dresses and skirts to the knee or longer): ``skirt_weights`` arguments. Each side of the skirt
#: lies on its own thigh from just below the crease (short ramps, near-full thigh share), so a striding or squatting
#: thigh carries the cloth over it instead of piercing a panel that lags on the hips; past the knee the cloth moves to
#: the shin (a bent knee leaves the calf inside, and a squat's shins keep a hem that falls instead of a disc level with
#: the thighs); the centre band mixing both legs is narrow (each leg's panel splits at its own inner edge and the
#: cloth between the legs stretches); the back keeps a little hips weight (seated, the back panel stays under the seat).
STRIDE_DRAPE = {"thigh_max": 0.98, "centre_w": 0.008, "ramp": 0.45, "front_ramp": 0.3, "back_relax": 0.0,
                "shin_max": 0.9, "knee_band": 0.07}
#: the stride drape's knee slack (m, scaled by fit.k): the cloth over the front and sides of each knee stands this much
#: further out, so the knee cap, which the cloth's thigh-to-shin blend pulls in at deep bends, stays under it
KNEE_SLACK = 0.022


def stride_drape(fit: Fit, z_top: float, hem_z: float) -> Callable[[Vector, float], dict]:
    """``skirt_weights`` for a dress or skirt down to ``hem_z`` (D-116 stride drape, see ``STRIDE_DRAPE``)."""
    return o.skirt_weights(fit, z_top, hem_z, **STRIDE_DRAPE)


def knee_slack(m: Mesh, rings: list[list[int]], fit: Fit, amount: float = KNEE_SLACK) -> None:
    """Push the lofted skirt ``rings`` out round each knee (``amount`` * k over the front and outer side, half behind,
    easing to nothing 9 cm above and 12 cm below), away from that knee's axis, so a bent knee stays under the cloth."""
    k = fit.k
    for sx, sfx in ((1.0, "R"), (-1.0, "L")):
        kn = Vector(fit.J[f"knee.{sfx}"])
        for ring in rings[1:]:
            for v in ring:
                p = m.v[v]
                if p.x * sx < 0.01 * k:
                    continue
                d = Vector((p.x - kn.x, p.y - kn.y, 0.0))
                if d.length < 1e-6:
                    continue
                d.normalize()
                # full over the front, half behind (the back of a bent knee bulges too); none on the inner side, where
                # it would cross the cloth between the knees
                front = (0.5 + 0.5 * smoothstep(-0.5, 0.3, d.y)) * smoothstep(-0.6, 0.0, d.x * sx)
                band = (smoothstep(kn.z + 0.09 * k, kn.z + 0.01 * k, p.z)
                        * smoothstep(kn.z - 0.12 * k, kn.z - 0.03 * k, p.z))
                s = amount * k * front * band
                if s > 1e-5:
                    m.v[v] = p + d * s


def jacket(fit: Fit, hull: Hull, mat: str, hem_z: float, button_z: float, neck_w: float = 0.075, base: float = 0.011,
           sleeve: float = 1.95, flare: float = 0.08, open_below: float = 0.03, lapel_w: float = 0.055,
           collar_mat: str | None = None, lapel_mat: str | None = None, min_off: float = 0.004,
           shoulder_pad: float = 0.006, keep_shape: float = 0.6, tail_thigh: float = 0.55,
           tail_centre: float = 0.11) -> tuple[Mesh, dict]:
    """Tailored jacket / coat: torso + sleeves shell over ``hull`` (shirt etc.), lofted tails down to
    ``hem_z``, a V opening from ``button_z`` to the neck, a front split below the button, lapels and
    a collar band round the back of the neck. Returns (mesh, info).

    Tail weights (``tail_thigh``, ``tail_centre``): the tails stay mostly on ``hips`` (at most
    ``tail_thigh`` thigh at the hem) and mix both thighs within ``tail_centre`` of the centre line,
    so the front split stays nearly closed on run/walk strides."""
    k = fit.k
    hips = fit.ring_centre("hips")
    nk = Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y

    def extra(p: Vector, r: str) -> float:
        d = 0.0
        if r in ("torso", "neck"):
            # shoulder pads: more volume over the shoulder tops
            for sfx in ("L", "R"):
                sh = Vector(fit.J[f"shoulder.{sfx}"])
                dd = (p - sh - Vector((0, 0, 0.04 * k))).length
                d += shoulder_pad * smoothstep(0.10 * k, 0.03 * k, dd)
        return d

    sh = upper_shell(fit, mat, bottom_z=hips.z, sleeve=sleeve, base=base, waist_blouse=0.0, hull=hull,
                     min_off=min_off, iters=6, extra=extra)
    m = sh.mesh
    loops = classify_loops(m)
    bottom = loops["hem"]
    o.straighten_loop(m, bottom, iters=3)
    for v in bottom:
        m.v[v] = Vector((m.v[v].x, m.v[v].y, hips.z))
    for key in ("cuff.L", "cuff.R"):
        if key in loops:
            o.straighten_loop(m, loops[key], iters=2)
    rows = max(2, int((hips.z - hem_z) / (0.035 * k)))
    knee_z = min(Vector(fit.J["knee.L"]).z, Vector(fit.J["knee.R"]).z)
    if hem_z < knee_z - 0.03 * k:
        # D-116 seated drape (long coats, robes): the front lies on the thighs (lap) from below the crease, the cloth
        # past the knees falls with the shins, the back stays under the seat on the hips; mixed across a wide centre
        # band so the front split stays near closed on strides
        wts = o.skirt_weights(fit, hips.z, hem_z, thigh_max=0.92, centre_w=SEATED_CENTRE, ramp=0.7, back_relax=0.75,
                              front_ramp=0.35, shin_max=SEATED_SHIN)
    else:
        wts = o.skirt_weights(fit, hips.z, hem_z, tail_thigh, tail_centre)
    o.loft_down(m, bottom, lambda th: hem_z - 0.01 * k * math.cos(th), hull, rows, clearance=0.012 * k,
                flare=flare, centre=hips, weights=wts, keep_shape=keep_shape)

    def v_half(z: float) -> float:
        t = clamp((z - button_z) / max(neck_z - button_z, 1e-3), 0.0, 1.0)
        return lerp(0.004 * k, neck_w * k, t ** 0.95)

    def split_half(z: float) -> float:
        t = clamp((button_z - z) / max(button_z - hem_z, 1e-3), 0.0, 1.0)
        return lerp(0.004 * k, open_below * k + 0.004 * k, t)

    def in_opening(c: Vector) -> bool:
        if c.y < cy:
            return False
        if c.z >= button_z:
            return abs(c.x) < v_half(c.z) and c.z < neck_z + 0.08
        return abs(c.x) < split_half(c.z)

    delete_faces(m, in_opening)
    snap_opening(m, v_half, cy, button_z, neck_z + 0.02, hull, min_off)
    snap_opening(m, split_half, cy, hem_z - 0.05, button_z, hull, min_off)
    o.drape(m, hull, min_off, max_off=0.08, iters=2)
    jh = Hull(fit, [m])
    # lapels: raised bands just outside the V edges, widening towards a squared top that stops
    # short of the collar (the notch); the front (roll) edge stands proud of the outer edge
    lap = Mesh()
    lap_top = neck_z - 0.045 * k
    n = 10

    def lap_w(t: float) -> float:
        return lapel_w * k * (0.22 + 0.78 * smoothstep(0.0, 0.8, t))

    def roll(o_: float) -> float:
        return lerp(1.0, 0.5, (o_ + 1.0) * 0.5)

    for sx in (-1.0, 1.0):
        path = []
        widths = []
        for i in range(n):
            t = i / (n - 1)
            z = lerp(button_z + 0.004, lap_top, t)
            w = lap_w(t)
            x = sx * (v_half(z) + w * 0.5 + 0.002)
            hit = jh.cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
            path.append(hit[0] if hit[0] is not None else Vector((x, 0.1, z)))
            widths.append(w * 0.5)
        o.strip(lap, jh, path, lambda t, ws=widths: ws[min(round(t * (len(ws) - 1)), len(ws) - 1)],
                0.0055 * k, lapel_mat or mat, side_hint=Vector((sx, 0, 0)), segs_across=2, chamfer=0.003 * k,
                profile=roll)
    # collar: front ends running up the V edge from just above the lapel tops (the gap between
    # them is the notch), then a band round the back of the neck
    cmat = collar_mat or lapel_mat or mat
    for sx in (-1.0, 1.0):
        path = []
        for i in range(4):
            z = lerp(lap_top + 0.016 * k, neck_z - 0.006 * k, i / 3)
            x = sx * (v_half(z) + 0.011 * k + 0.002)
            hit = jh.cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
            path.append(hit[0] if hit[0] is not None else Vector((x, 0.1, z)))
        o.strip(lap, jh, path, 0.011 * k, 0.005 * k, cmat, side_hint=Vector((sx, 0, 0)), segs_across=1,
                chamfer=0.0025 * k, profile=roll)
    cpath = []
    for i in range(21):
        th = lerp(0.42, 2 * math.pi - 0.42, i / 20)
        cpath.append(nk.point(th, 0.12, 0.012 * k))
    o.strip(lap, Hull(fit, [m]), cpath, 0.022 * k, 0.005 * k, cmat, side_hint=UP,
            segs_across=2, chamfer=0.003 * k, cast_back=0.06)
    o.hem_all(m, thick=0.004 * k, depth=0.016 * k)
    m.extend(lap)
    return m, {"v_half": v_half, "button_z": button_z, "neck_z": neck_z, "hull": jh}


def knit_top(fit: Fit, hull: Hull, mat: str, bottom_z: float, sleeve: float = 2.0, base: float = 0.008,
             rib: float = 0.05, neck: str = "crew", rib_mat: str | None = None) -> Mesh:
    """Sweater/jumper worn over the trouser waist: shell + ribbed hem/cuffs + crew or roll neck."""
    k = fit.k
    sh = upper_shell(fit, mat, bottom_z=bottom_z, sleeve=sleeve, base=base, waist_blouse=0.006, hull=hull,
                     iters=6, min_off=0.004 * k)
    m = sh.mesh
    loops = classify_loops(m)
    bottom_tuck(m, loops["hem"], bottom_z)
    mh = Hull(fit, [m])
    for key in ("hem", "cuff.L", "cuff.R"):
        if key in loops:
            if key != "hem":
                o.straighten_loop(m, loops[key], iters=2)
            cuff_band(m, loops[key], mh, rib * k, 0.0025 * k, rib_mat or mat)
    if neck == "crew":
        band_collar(m, fit, sh.ring("neck"), rib_mat or mat, height=0.28, rad=0.007)
    elif neck == "roll":
        band_collar(m, fit, sh.ring("neck"), rib_mat or mat, height=0.75, rad=0.012, roll=0.006 * k)
    o.hem_all(m, thick=0.004 * k, depth=0.014 * k)
    return m


def gilet(fit: Fit, hull: Hull, mat: str, bottom_z: float, base: float = 0.012, quilt: float = 0.010,
          pitch: float = 0.065, zip_mat: str = "chrome") -> tuple[Mesh, Mesh]:
    """Quilted sleeveless puffer vest with a stand collar and a front zip. Returns (soft, zip).

    Quilting: horizontal stitch lines snapped to the body's own vertex rows (about every ``pitch``)
    are pinched in to the base offset while the channels between them puff out by ``quilt``, so the
    grooves land exactly on edge loops and read as crisp channels instead of aliasing."""
    k = fit.k
    rows = sorted({round(fit.P[v].z, 4) for f, r in zip(fit.F, fit.FR) if r == "torso" for v in f
                   if abs(fit.P[v].x) < 0.02 * k and fit.P[v].y > 0.0})
    seams: list[float] = []
    for z in rows:
        if z <= bottom_z + 0.03 * k:
            continue
        if not seams or z - seams[-1] >= pitch * k * 0.85:
            seams.append(z)

    def extra(p: Vector, r: str) -> float:
        d = min((abs(p.z - z) for z in seams), default=1.0)
        return quilt * k * (1.0 - smoothstep(0.008 * k, 0.003 * k, d))

    sh = upper_shell(fit, mat, bottom_z=bottom_z, base=base, sleeveless=True, hull=hull, iters=1, extra=extra,
                     min_off=0.006 * k, waist_blouse=0.006)
    m = sh.mesh
    loops = classify_loops(m)
    bottom_tuck(m, loops["hem"], bottom_z)
    for key in ("cuff.L", "cuff.R"):
        if key in loops:
            o.straighten_loop(m, loops[key], iters=3)
    band_collar(m, fit, sh.ring("neck"), mat, height=0.62, rad=0.020, roll=0.004 * k)
    o.hem_all(m, thick=0.008 * k, depth=0.016 * k)
    z = Mesh()
    hh = Hull(fit, [m])
    nk = Neck(fit)
    path = front_path(hh, 0.0, nk.point(0.0, 0.55).z, bottom_z + 0.004, step=0.02 * k)
    o.strip(z, hh, path, 0.0045 * k, 0.0025 * k, zip_mat, segs_across=1, chamfer=0.001 * k)
    return m, z


def dress(fit: Fit, mat: str, hem_z: float, sleeve: float = 0.42, scoop: float = 0.055, flare: float = 0.16,
          base: float = 0.005) -> Mesh:
    """Fitted dress: bodice with short sleeves and a scoop neckline, A-line skirt to ``hem_z``."""
    k = fit.k
    hips = fit.ring_centre("hips")
    nk = Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y

    def cut(c: Vector) -> bool:
        if c.y < cy - 0.02:
            return c.z > neck_z + 0.03 - 0.025 * k
        return c.z > neck_z - scoop * k * smoothstep(0.09 * k, 0.0, abs(c.x)) + 0.004

    sh = upper_shell(fit, mat, bottom_z=hips.z - 0.03 * k, sleeve=sleeve, base=base, waist_blouse=0.0,
                     top_cut=cut, iters=5)
    m = sh.mesh
    loops = classify_loops(m)
    bottom = loops["hem"]
    o.straighten_loop(m, bottom, iters=3)
    z0 = hips.z - 0.03 * k
    for v in bottom:
        m.v[v] = Vector((m.v[v].x, m.v[v].y, z0))
    for key in ("cuff.L", "cuff.R", "top"):
        if key in loops:
            o.straighten_loop(m, loops[key], iters=3)
    rows = max(3, int((z0 - hem_z) / (0.035 * k)))
    # D-116 stride drape: the skirt rides each thigh, past the knee each shin, with slack over the knees (walk, run,
    # flee, crouch and cower tore it open on the old hips-to-thigh blend: knees and shins through the cloth)
    rings = o.loft_down(m, bottom, lambda th: hem_z, Hull(fit), rows, clearance=0.012 * k, flare=flare, centre=hips,
                        weights=stride_drape(fit, z0, hem_z), keep_shape=0.3)
    knee_slack(m, rings, fit)
    o.hem_all(m, thick=0.003 * k, depth=0.012 * k)
    return m


def apron(fit: Fit, hull: Hull, mat: str, z_top: float, z_hem: float, bib_w: float = 0.25, skirt_w: float = 0.46,
          strap_mat: str | None = None) -> Mesh:
    """Bib apron: a front panel cast onto ``hull`` that hangs straight below the hips, neck strap
    and waist ties round the back."""
    k = fit.k
    hips = fit.ring_centre("hips")
    waist = fit.ring_centre("waist").z
    m = Mesh()
    nj = max(8, int((z_top - z_hem) / (0.03 * k)))
    ni = 12
    grid: list[list[int]] = []
    y_prev = [None] * (ni + 1)
    zw = waist + 0.02 * k
    wts = o.skirt_weights(fit, hips.z, z_hem)
    for j in range(nj + 1):
        z = lerp(z_top, z_hem, j / nj)
        hw = lerp(bib_w, skirt_w, smoothstep(zw + 0.05 * k, zw - 0.03 * k, z)) * 0.5 * k
        row = []
        for i in range(ni + 1):
            x = lerp(-hw, hw, i / ni)
            hit = hull.cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
            y = hit[0].y + 0.005 * k if hit[0] is not None else -1.0
            if z < hips.z and y_prev[i] is not None:
                y = max(y, y_prev[i] - 0.002 * k)
            if y < -0.5:
                y = y_prev[i] if y_prev[i] is not None else 0.1
            y_prev[i] = y
            p = Vector((x, y, z))
            w = wts(p, 0.0) if z < hips.z else None
            row.append(m.add(p, w))
        grid.append(row)
    for a, b in itertools.pairwise(grid):
        for i in range(ni):
            m.face((a[i], a[i + 1], b[i + 1], b[i]), mat, inside=Vector((0.0, -0.2, 1.0)))
    o.hem_all(m, thick=0.003 * k, depth=0.010 * k)
    # neck strap (tube from the bib top corners round the back of the neck) and waist tie
    nk = Neck(fit)
    sm = strap_mat or mat
    for sx in (-1.0, 1.0):
        p0 = m.v[grid[0][0 if sx < 0 else ni]] + Vector((0, -0.003 * k, 0.0))
        pts = [p0]
        for t in (0.25, 0.5, 0.75, 1.0):
            th = sx * lerp(0.55, math.pi, t)
            q = nk.point(th, 0.15, 0.010 * k)
            pts.append(p0.lerp(q, 0.5) + Vector((0, 0, 0.0)) if t == 0.25 else q)
        pts = [o.push_out(q, hull, 0.006 * k) for q in pts]
        o.tube(m, pts, 0.004 * k, sm, sides=5)
    return m
