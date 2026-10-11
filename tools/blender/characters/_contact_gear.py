"""Headwear and small gear for the contact busts (QB-50a). Blender only (``mathutils``).

Private helper of ``char_contacts.py``. Everything is fitted to the head by rays (``HeadHull``),
100 % ``head`` weighted unless stated, and built from ring stacks (``Mesh.ring``/``band``/``fan``)
so the topology is fixed and deterministic.

* ``flat_cap``: a tweed flat cap (newsboy without the button): band, a crown that slopes forward
  over a short stiff peak.
* ``fedora``: a felt fedora with a pinched, centre-dented crown, a ribbon band and a brim that
  snaps down at the front and curls up at the sides.
* ``chignon``: a full two-lobe updo high on the back of the head, with a coiled wrap (spiral strand
  grooves on the lobes).
* ``crown_volume``: a soft shell of volume over the crown and upper sides of the hair, gridded along
  the swept-back strands with clump grooves and a broken front hairline.
* ``side_fringe``: a side-swept fringe from the parting across the forehead to behind the ear (two
  strand grooves along the sweep).
* ``moustache``: a thick tapered moustache over the upper lip.
* ``earrings``: small gold studs with a short drop.
* ``heavy_lids``: a lowered upper lid line (liner band over the top of the eyeball).
* ``lenses``: lens discs for ``_gear_kit.glasses`` (same rim layout), glossy so they glint.
* ``lapel_pin``: a small gold bar pin.
"""

from __future__ import annotations

import itertools
import math

import _head
import _outfit as o
from _gear_kit import HEAD_W, HeadHull, _smooth_circ
from _outfit import UP, Fit, Gear, Hull, Mesh, Vector, lerp, smoothstep


def _ring_pts(c: Vector, rad: list[float], th: list[float], z, fwd: float = 0.0, sx: float = 1.0) -> list[Vector]:
    return [Vector((c.x + r * sx * math.sin(a), c.y + r * math.cos(a) + fwd, z(a) if callable(z) else z))
            for a, r in zip(th, rad)]


def _stack(m: Mesh, rings: list[list[Vector]], mat: str, inside: Vector, w: dict = HEAD_W,
           pole: Vector | None = None, mats: list[str] | None = None) -> list[list[int]]:
    """Bands between consecutive rings (outward = away from ``inside``), optional fan to ``pole``."""
    ids = [m.ring(r, w) for r in rings]
    for i in range(len(ids) - 1):
        m.band(ids[i], ids[i + 1], mats[i] if mats else mat, inside=inside)
    if pole is not None:
        p = m.add(pole, w)
        n = len(ids[-1])
        for j in range(n):
            m.face((ids[-1][j], ids[-1][(j + 1) % n], p), mat, inside=inside)
    return ids


def _head_radii(fit: Fit, z_of, th: list[float], c: Vector, clear: float) -> list[float]:
    hh = HeadHull(fit)
    rad = []
    for a in th:
        best = 0.0
        for dz in (0.0, 0.012, 0.024):
            best = max(best, hh.outer_radius(z_of(a) + dz * fit.k, a, c.x, c.y, far=0.4))
        rad.append(best if best > 0 else 0.09 * fit.k)
    return [r + clear * fit.k for r in _smooth_circ(rad, 3)]


# ---------------------------------------------------------------------------------------------
# hats
# ---------------------------------------------------------------------------------------------
def flat_cap(fit: Fit, mat: str, band_mat: str | None = None, n: int = 40) -> tuple[Mesh, dict]:
    """Flat cap: sits low on the brow, the crown pulled forward and down over a short peak."""
    k = fit.k
    eye = fit.eye_centre()
    c = fit.head_centre()
    top = fit.head_top()
    th = [math.tau * i / n for i in range(n)]
    zf = eye.z + 0.040 * k                                   # band bottom at the front

    def zb(a: float) -> float:                               # band dips at the back (cap sits low)
        return zf - 0.022 * k * (1 - math.cos(a)) * 0.5

    rad = _head_radii(fit, zb, th, c, 0.005)
    m = Mesh()
    inside = Vector((c.x, c.y, c.z))

    # crown: low and flat, sloping forward and down so its front edge overhangs the peak
    def z_crown(a: float, f: float) -> float:
        t_back = top + 0.010 * k
        t_front = zf + 0.008 * k
        w_ = smoothstep(-0.1, 1.0, math.cos(a)) ** 1.5
        return lerp(t_back, t_front, w_) * f + zb(a) * (1 - f)

    rb0 = _ring_pts(c, rad, th, lambda a: zb(a))
    r1 = _ring_pts(c, [r * 1.05 + 0.004 * k for r in rad], th, lambda a: zb(a) + 0.018 * k, fwd=0.010 * k)
    r2 = _ring_pts(c, [r * 1.09 + 0.008 * k for r in rad], th, lambda a: z_crown(a, 0.82), fwd=0.034 * k)
    r3 = _ring_pts(c, [r * 1.08 + 0.006 * k for r in rad], th, lambda a: z_crown(a, 0.97), fwd=0.044 * k)
    r4 = _ring_pts(c, [r * 0.75 for r in rad], th,
                   lambda a: lerp(top + 0.012 * k, z_crown(a, 1.0) + 0.007 * k, 0.55), fwd=0.030 * k)
    pole = Vector((c.x, c.y + 0.020 * k, top + 0.014 * k))
    bm = band_mat or mat
    _stack(m, [rb0, r1, r2, r3, r4], mat, inside, pole=pole, mats=[bm, mat, mat, mat])
    # inner lip so the band has thickness from below
    rin = m.ring(_ring_pts(c, [r - 0.004 * k for r in rad], th, lambda a: zb(a) + 0.012 * k), HEAD_W)
    rb0_ids = list(range(n))
    for j in range(n):
        jj = (j + 1) % n
        m.face((rb0_ids[j], rb0_ids[jj], rin[jj], rin[j]), bm, inside=Vector((c.x, c.y, zf + 0.05 * k)))
    # peak: a short stiff brim tucked under the crown front, angled down
    arc = [i for i, a in enumerate(th) if math.cos(a) > 0.30]
    arc.sort(key=lambda i: o.wrap(th[i]))
    tops, bots, otop, obot = [], [], [], []
    tilt = math.radians(24.0)
    for i in arc:
        a = th[i]
        cf = max(0.0, math.cos(a))
        reach = 0.046 * k * ((cf - 0.30) / 0.70) ** 0.6
        p_in = Vector((c.x + rad[i] * math.sin(a), c.y + rad[i] * math.cos(a), zb(a) + 0.001 * k))
        d = Vector((math.sin(a), math.cos(a), 0.0))
        p_out = p_in + (d * math.cos(tilt) - UP * math.sin(tilt)) * reach
        tops.append(m.add(p_in + UP * 0.003 * k, HEAD_W))
        otop.append(m.add(p_out + UP * 0.002 * k, HEAD_W))
        bots.append(m.add(p_in - UP * 0.001 * k, HEAD_W))
        obot.append(m.add(p_out - UP * 0.0015 * k, HEAD_W))
    up_ref = Vector((c.x, c.y + 0.03 * k, zf - 0.3))
    dn_ref = Vector((c.x, c.y + 0.03 * k, zf + 0.3))
    for j in range(len(arc) - 1):
        m.face((tops[j], tops[j + 1], otop[j + 1], otop[j]), mat, inside=up_ref)
        m.face((bots[j], bots[j + 1], obot[j + 1], obot[j]), mat, inside=dn_ref)
        m.face((otop[j], otop[j + 1], obot[j + 1], obot[j]), mat, inside=Vector((c.x, c.y, zf)))
    for e in (0, len(arc) - 1):
        m.face((tops[e], otop[e], obot[e], bots[e]), mat, inside=Vector((c.x, c.y + 0.05 * k, zf)))
    return m, {"top_z": pole.z}


def fedora(fit: Fit, mat: str, band_mat: str, n: int = 48) -> tuple[Mesh, dict]:
    """Fedora: band ring on the head, a tapered crown with a centre dent and front pinch, a ribbon
    and a brim (down at the front, up at the sides and back)."""
    k = fit.k
    eye = fit.eye_centre()
    c = fit.head_centre()
    th = [math.tau * i / n for i in range(n)]
    zf = eye.z + 0.052 * k

    def zb(a: float) -> float:
        return zf - 0.010 * k * (1 - math.cos(a)) * 0.5

    rad = _head_radii(fit, zb, th, c, 0.006)
    m = Mesh()
    inside = Vector((c.x, c.y, zf + 0.04 * k))
    crown_h = 0.110 * k

    def pinch(a: float) -> float:          # narrower at the front (pinched) and slightly at the back
        return 1.0 - 0.10 * max(0.0, math.cos(a)) ** 4 - 0.03 * max(0.0, -math.cos(a)) ** 2

    def z_top(a: float, sx_: float) -> float:
        # top ridge: highest at the sides of the dent, sloping slightly to the front
        return zb(a) + crown_h - 0.018 * k * max(0.0, math.cos(a))

    rings = [_ring_pts(c, rad, th, lambda a: zb(a) - 0.002 * k)]
    for f, grow in ((0.22, 0.990), (0.50, 0.960), (0.80, 0.905), (0.96, 0.850)):
        rings.append(_ring_pts(c, [r * grow * lerp(1.0, pinch(a), f) for r, a in zip(rad, th)], th,
                               lambda a, f=f: lerp(zb(a), z_top(a, 1.0), f)))
    rings.append(_ring_pts(c, [r * 0.76 * pinch(a) for r, a in zip(rad, th)], th,
                           lambda a: z_top(a, 1.0) + 0.003 * k))
    # dent: the top ring is pulled down along the centre line (front-back crease)
    dent_pts = []
    for a, r in zip(th, rad):
        sx_ = abs(math.sin(a))
        rr = r * (0.42 + 0.30 * sx_) * pinch(a)
        dent_pts.append(Vector((c.x + rr * math.sin(a), c.y + rr * math.cos(a),
                                z_top(a, 1.0) - 0.012 * k * (1 - sx_))))
    rings.append(dent_pts)
    pole = Vector((c.x, c.y + 0.004 * k, zb(0.0) + crown_h - 0.040 * k))
    mats = [band_mat, band_mat, mat, mat, mat, mat]
    ids = _stack(m, rings, mat, inside, pole=pole, mats=mats)
    # ribbon lip (a small step proud of the crown above the band)
    del ids
    # brim: 3 rings outward (top surface) + edge + underside back to the head
    def brim_z(a: float, t: float) -> float:
        side = math.sin(a) ** 2
        front = max(0.0, math.cos(a))
        back = max(0.0, -math.cos(a))
        return zb(a) + t * (0.008 * side + 0.010 * back - 0.020 * front ** 2) * k + t * t * 0.006 * side * k

    widths = [0.054 * k * (1.0 + 0.10 * max(0.0, math.cos(a)) - 0.08 * max(0.0, -math.cos(a))) for a in th]
    top_rings, bot_rings = [], []
    for t in (0.0, 0.35, 0.7, 1.0):
        top_rings.append(_ring_pts(c, [r + wd * t for r, wd in zip(rad, widths)], th,
                                   lambda a, t=t: brim_z(a, t) + 0.0035 * k))
        bot_rings.append(_ring_pts(c, [r + wd * t for r, wd in zip(rad, widths)], th,
                                   lambda a, t=t: brim_z(a, t) - 0.0015 * k))
    tid = [m.ring(r, HEAD_W) for r in top_rings]
    bid = [m.ring(r, HEAD_W) for r in bot_rings]
    above = Vector((c.x, c.y, zf + 0.5))
    below = Vector((c.x, c.y, zf - 0.5))
    for i in range(len(tid) - 1):
        m.band(tid[i], tid[i + 1], mat, inside=below)
        m.band(bid[i], bid[i + 1], mat, inside=above)
    # rolled edge
    edge = _ring_pts(c, [r + wd + 0.003 * k for r, wd in zip(rad, widths)], th, lambda a: brim_z(a, 1.0) + 0.001 * k)
    eid = m.ring(edge, HEAD_W)
    m.band(tid[-1], eid, mat, inside=Vector((c.x, c.y, zf)))
    m.band(eid, bid[-1], mat, inside=Vector((c.x, c.y, zf)))
    m.band(bid[0], tid[0], mat, inside=Vector((c.x, c.y, zf)) + Vector((0, 0, 0.0)))
    # ribbon: a slightly proud band over the lower crown, with a bow knot on the left side
    rib0 = _ring_pts(c, [r + 0.0025 * k for r in rad], th, lambda a: zb(a) + 0.002 * k)
    rib1 = _ring_pts(c, [r * 1.0 + 0.0025 * k for r in rad], th, lambda a: zb(a) + 0.026 * k)
    r0i, r1i = m.ring(rib0, HEAD_W), m.ring(rib1, HEAD_W)
    m.band(r0i, r1i, band_mat, inside=inside)
    a = math.radians(-100.0)
    i_b = round(o.wrap(a) / math.tau * n) % n
    p = Vector((c.x + (rad[i_b] + 0.004 * k) * math.sin(a), c.y + (rad[i_b] + 0.004 * k) * math.cos(a), zb(a) + 0.014 * k))
    g = Gear()
    g.prism(o.rounded_rect(0.024 * k, 0.020 * k, 0.004 * k, 2), 0.0, 0.005 * k, band_mat)
    g.bevel(0.0012 * k, 1, 30.0)
    m.extend(g.to_mesh(o.frame_from(p, Vector((math.sin(a), math.cos(a), 0.0))), weights=HEAD_W))
    return m, {"top_z": zb(0.0) + crown_h}


# ---------------------------------------------------------------------------------------------
# hair pieces
# ---------------------------------------------------------------------------------------------
def _ellipsoid(m: Mesh, c: Vector, r: Vector, mat: str, segs: int = 16, rows: int = 8,
               w: dict = HEAD_W, axes: tuple[Vector, Vector, Vector] | None = None, swirl: float = 0.0) -> None:
    """Ellipsoid on ``axes``; ``swirl`` > 0 cuts spiralling strand grooves (fraction of the radius,
    one groove per four segments, fading at the poles) so a bun reads as wound hair."""
    ax = axes or (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    rings = []
    for i in range(1, rows):
        phi = math.pi * i / rows
        ring = []
        for j in range(segs):
            t = math.tau * j / segs
            g = 1.0 - swirl * math.sin(phi) * (0.5 + 0.5 * math.cos((segs // 4) * t + 2.2 * phi)) ** 2
            q = (ax[0] * (r.x * g * math.sin(phi) * math.cos(t)) + ax[1] * (r.y * g * math.sin(phi) * math.sin(t))
                 + ax[2] * (r.z * math.cos(phi)))
            ring.append(m.add(c + q, w))
        rings.append(ring)
    for a_, b_ in itertools.pairwise(rings):
        m.band(a_, b_, mat, inside=c)
    top = m.add(c + ax[2] * r.z, w)
    bot = m.add(c - ax[2] * r.z, w)
    for j in range(segs):
        jj = (j + 1) % segs
        m.face((rings[0][j], rings[0][jj], top), mat, inside=c)
        m.face((rings[-1][j], rings[-1][jj], bot), mat, inside=c)


def chignon(fit: Fit, mat: str, size: float = 1.0, lift: float = 0.0) -> Mesh:
    """An elegant updo at the back of the head: a full two-lobe bun set high on the occiput (the
    upper lobe tucked under the crown volume), a coiled wrap round its base and a short twist. ``size``
    scales the bun, ``lift`` raises it (m, before height scaling)."""
    k = fit.k
    ks = k * size
    eye = fit.eye_centre()
    c = fit.head_centre()
    hh = HeadHull(fit)
    z = eye.z + (0.020 + lift) * k
    hit = hh.cast(Vector((0.0, c.y - 0.5, z)), Vector((0, 1, 0)), 1.0)
    back = hit[0].y if hit[0] is not None else c.y - 0.11 * k
    m = Mesh()
    ctr = Vector((0.0, back - 0.026 * ks, z))
    tilt = math.radians(28.0)       # bun axis leans up/back
    ax_y = Vector((0.0, -math.cos(tilt), math.sin(tilt)))
    ax_z = Vector((0.0, math.sin(tilt), math.cos(tilt)))
    ax_x = Vector((1, 0, 0))
    _ellipsoid(m, ctr, Vector((0.052 * ks, 0.034 * ks, 0.044 * ks)), mat, segs=20, rows=9, axes=(ax_x, ax_z, ax_y),
               swirl=0.07)
    top = ctr + ax_z * (0.026 * ks) + ax_y * (0.004 * ks)
    _ellipsoid(m, top, Vector((0.040 * ks, 0.026 * ks, 0.026 * ks)), mat, segs=16, rows=7, axes=(ax_x, ax_z, ax_y),
               swirl=0.08)
    # coiled wrap: a helix of hair round the bun base (reads as the twisted coil of a chignon)
    pts = []
    turns, steps = 1.5, 36
    for j in range(steps + 1):
        t = j / steps
        a = math.tau * turns * t
        rr = (0.049 - 0.010 * t) * ks
        pts.append(ctr + ax_y * ((0.010 - 0.016 * t) * ks) + ax_x * (rr * math.cos(a)) + ax_z * (rr * 0.86 * math.sin(a)))
    o.tube(m, pts, lambda t: (0.0045 + 0.0035 * math.sin(math.pi * t)) * ks, mat, sides=6, weights=lambda p, t: HEAD_W)
    # base ring where the bun meets the head
    ring = []
    for j in range(17):
        t = math.tau * j / 16
        ring.append(ctr + ax_y * (0.017 * ks) + ax_x * (0.044 * ks * math.cos(t)) + ax_z * (0.038 * ks * math.sin(t)))
    o.tube(m, ring, 0.0060 * ks, mat, sides=6, weights=lambda p, t: HEAD_W, caps=False)
    return m


#: Hairline of ``crown_volume``: (azimuth deg from the front, polar deg from the crown), symmetric.
#: The default follows a scraped-back updo on a bald scalp: the forehead, the temples, over the ears,
#: the nape under the chignon.
CROWN_HAIRLINE = ((0.0, 56.0), (25.0, 62.0), (50.0, 80.0), (70.0, 98.0), (90.0, 106.0), (120.0, 122.0),
                  (150.0, 140.0), (180.0, 146.0))


def _crown_edge(a: float, line: tuple = CROWN_HAIRLINE) -> float:
    """Hairline polar angle (radians from the crown) of ``crown_volume`` at azimuth ``a``."""
    d = abs(math.degrees(o.wrap(a)))
    d = 360.0 - d if d > 180.0 else d
    for (a0, p0), (a1, p1) in itertools.pairwise(line):
        if d <= a1:
            f = smoothstep(0.0, 1.0, (d - a0) / (a1 - a0))
            return math.radians(lerp(p0, p1, f))
    return math.radians(line[-1][1])


def _crown_offset(a: float, ph: float, top: float, sides: float, line: tuple = CROWN_HAIRLINE) -> float:
    """Thickness (m, before height scaling) of ``crown_volume`` at azimuth ``a``, polar angle ``ph``."""
    u = min(1.0, ph / _crown_edge(a, line))
    return 0.0006 + (1.0 - u ** 4) * (top + sides * math.sin(a) ** 2 * math.sin(math.pi * min(1.0, 0.25 + u)) ** 0.8)


#: Swept-back strand flow of ``crown_volume``: the strands run on great circles through the chignon
#: (``_SWEEP_POLE``, back, just above eye height) and its antipode under the brow; ``_SWEEP_CLUMPS``
#: irregular strand clumps separated by grooves ``_SWEEP_GROOVE`` (fraction of the volume) deep.
_SWEEP_POLE = (0.0, -1.0, 0.12)
_SWEEP_CLUMPS = 12
_SWEEP_GROOVE = 0.6


def _sweep_clump(i_max: int, s: float, salt: int = 0) -> tuple[float, float]:
    """(groove, bulge) at azimuth ``s`` (0..1) over ``i_max`` irregular clumps (``_head._h01`` hash)."""
    w = [0.65 + 0.7 * _head._h01(i, 11 + salt) for i in range(i_max)]
    tot = sum(w)
    acc = 0.0
    for i, x in enumerate(w):
        lo, acc = acc, acc + x / tot
        if s < acc or i == i_max - 1:
            f = min(1.0, max(0.0, (s - lo) / (acc - lo)))
            return ((0.6 + 0.4 * _head._h01(i, 12 + salt)) * math.cos(math.pi * f) ** 2,
                    (0.35 + 0.65 * _head._h01(i, 13 + salt)) * math.sin(math.pi * f) ** 1.5)
    return 0.0, 0.0


def crown_volume(fit: Fit, mat: str, top: float = 0.004, sides: float = 0.010, line: tuple = CROWN_HAIRLINE,
                 n_al: int = 48, n_be: int = 11) -> Mesh:
    """Swept-back hair (an updo's backcombed crown) as a shell on rays from the head centre:
    fullest at the upper sides (width rather than height, so the head reads less long) and tucked
    to ~0.6 mm at the hairline ``line`` (see ``CROWN_HAIRLINE``). Over a bald head (``hair: none``)
    it is the whole hair; over a hair cap, ``line`` should end above the cap's edge. ``top``/``sides``
    are the extra volume in metres (before height scaling).

    The grid follows the strands: ``n_al`` columns on great circles from the chignon pole
    (``_SWEEP_POLE``, hidden under the bun) forward to the hairline, ``n_be`` rows along them. Strand
    clumps are cut in as grooves between the columns (subtractive: the envelope is kept) and reach a
    little over the hairline at the front, so the edge breaks up."""
    k = fit.k
    c = fit.head_centre()
    hh = HeadHull(fit)
    pole = Vector(_SWEEP_POLE).normalized()
    e1 = Vector((1.0, 0.0, 0.0))
    e2 = pole.cross(e1).normalized()               # up

    def crown_ang(d: Vector) -> tuple[float, float]:
        return math.atan2(d.x, d.y), math.acos(max(-1.0, min(1.0, d.z)))

    def inside(d: Vector) -> bool:
        a, ph = crown_ang(d)
        return ph < _crown_edge(a, line)

    def dirv(al: float, be: float) -> Vector:
        return (pole * math.cos(be) + (e1 * math.cos(al) + e2 * math.sin(al)) * math.sin(be)).normalized()

    def point(d: Vector, mod: float) -> Vector:
        a, ph = crown_ang(d)
        hit = hh.cast(c + d * 0.4, -d, 0.6)
        base = hit[0] if hit[0] is not None else c + d * 0.1 * k
        return base + d * _crown_offset(a, ph, top, sides, line) * k * mod

    m = Mesh()
    edges = []
    for j in range(n_al):
        al = math.tau * j / n_al
        be = 0.0
        while be < math.pi and inside(dirv(al, be)):
            be += math.radians(2.0)
        lo, hi = be - math.radians(2.0), be
        for _ in range(24):
            mid = 0.5 * (lo + hi)
            lo, hi = (mid, hi) if inside(dirv(al, mid)) else (lo, mid)
        edges.append(lo)
    cols = []
    for j in range(n_al):
        al = math.tau * j / n_al
        edge = edges[j]
        groove, bulge = _sweep_clump(_SWEEP_CLUMPS, j / n_al)
        a_e, _ph = crown_ang(dirv(al, edge))
        front = smoothstep(math.radians(70.0), math.radians(25.0), abs(a_e))
        edge += math.radians(2.5) * front * (bulge - 0.2)            # clumps reach over the hairline
        col = []
        for r in range(1, n_be + 1):
            t = r / n_be
            be = edge * (1.0 - (1.0 - t) ** 1.3)
            fade = smoothstep(math.radians(12.0), math.radians(40.0), be)
            col.append(point(dirv(al, be), 1.0 - _SWEEP_GROOVE * groove * fade))
        cols.append(col)
    ids = [m.ring([cols[j][r] for j in range(n_al)], HEAD_W) for r in range(n_be)]
    inside_c = Vector((c.x, c.y, c.z))
    for a_, b_ in itertools.pairwise(ids):
        m.band(a_, b_, mat, inside=inside_c)
    pc = m.add(point(pole, 1.0), HEAD_W)
    for j in range(n_al):
        m.face((ids[0][j], ids[0][(j + 1) % n_al], pc), mat, inside=inside_c)
    return m


def side_fringe(fit: Fit, mat: str, part_deg: float = 30.0, crown: tuple[float, float] | None = None,
                sweep: float = 1.0) -> Mesh:
    """A side-swept fringe: a soft, lifted sheet of hair from the parting (``part_deg``, + = the
    character's right) across the forehead and down to behind the other ear, framing the face. Lofted
    on the head + hair surface (rays), thick in the middle, tapering at both ends. ``crown`` = the
    (top, sides) of a ``crown_volume`` it lies over; ``sweep`` (0..1) drops the arc lower over the
    forehead and temple (1 = a clear sweep just above the brow)."""
    k = fit.k
    c = fit.head_centre()
    hh = HeadHull(fit)
    side = 1.0 if part_deg >= 0.0 else -1.0
    # path: (theta deg from the front, + = right; phi deg from the crown)
    path = [(part_deg, 30.0), (part_deg * 0.45, 42.0 + 3.0 * sweep), (-side * 6.0, 52.0 + 6.0 * sweep),
            (-side * 30.0, 58.0 + 8.0 * sweep), (-side * 54.0, 66.0 + 10.0 * sweep),
            (-side * 78.0, 76.0 + 14.0 * sweep), (-side * 102.0, 88.0 + 14.0 * sweep)]

    def dirv(th: float, ph: float) -> Vector:
        t_, p_ = math.radians(th), math.radians(ph)
        return Vector((math.sin(p_) * math.sin(t_), math.sin(p_) * math.cos(t_), math.cos(p_)))

    def interp(t: float) -> tuple[float, float]:
        x = t * (len(path) - 1)
        i = min(int(x), len(path) - 2)
        f = x - i
        f = f * f * (3 - 2 * f)
        return (path[i][0] + (path[i + 1][0] - path[i][0]) * f, path[i][1] + (path[i + 1][1] - path[i][1]) * f)

    def under(th: float, ph: float) -> float:      # thickness of the crown volume below the fringe
        return _crown_offset(math.radians(th), math.radians(ph), *crown) * k if crown else 0.0

    def surf(th: float, ph: float) -> tuple[Vector, Vector]:
        d = dirv(th, ph)
        hit = hh.cast(c + d * 0.4, -d, 0.6)
        if hit[0] is None:
            return c + d * 0.1 * k, d
        n = hit[1].normalized()
        return hit[0] + d * under(th, ph), n if n.dot(d) > 0 else -n

    n_rows, n_across = 18, 7
    rows = []
    for r in range(n_rows + 1):
        t = r / n_rows
        th, ph = interp(t)
        p, n = surf(th, ph)
        th2, ph2 = interp(min(1.0, t + 0.02))
        th0, ph0 = interp(max(0.0, t - 0.02))
        tang = (surf(th2, ph2)[0] - surf(th0, ph0)[0]).normalized()
        sd = n.cross(tang).normalized()
        w = (0.022 + 0.046 * math.sin(math.pi * min(1.0, t * 1.25)) ** 0.8) * (1.0 - 0.5 * smoothstep(0.75, 1.0, t)) * k
        lift = (0.0035 + 0.0085 * math.sin(math.pi * t) ** 0.7) * k
        off = under(th, ph)
        tops, bots = [], []
        for a in range(n_across + 1):
            s_ = -1.0 + 2.0 * a / n_across
            q = p + sd * (s_ * 0.5 * w)
            hq = hh.cast(q + n * 0.05, -n, 0.1)
            base = hq[0] + n * off if hq[0] is not None else q
            prof = max(0.0, 1.0 - s_ * s_) ** 0.5
            # strand clumps: two grooves along the sweep (a = 2 and 5), shallow at the root
            groove = (0.30 if a in (2, 5) else 0.0) * smoothstep(0.05, 0.3, t)
            # the leading (lower) edge curls slightly under, the trailing edge blends into the hair
            tops.append(base + n * (0.0008 * k + lift * (0.35 + 0.65 * prof) * (1.0 - groove)))
            bots.append(base + n * (0.0008 * k))
        rows.append(tops + list(reversed(bots[1:-1])))
    m = Mesh()
    ids = [m.ring(rw, HEAD_W) for rw in rows]
    inside = Vector((c.x, c.y, c.z))
    for i in range(len(ids) - 1):
        m.band(ids[i], ids[i + 1], mat, inside=inside)
    for end, ref in ((ids[0], rows[0]), (ids[-1], rows[-1])):
        ctr = sum(ref, Vector()) / len(ref)
        pc = m.add(ctr, HEAD_W)
        nn = len(end)
        for j in range(nn):
            m.face((end[j], end[(j + 1) % nn], pc), mat, inside=inside)
    return m


def moustache(fit: Fit, mat: str, z_off: float = -0.066, half_w: float = 0.034, thick: float = 0.0062) -> Mesh:
    """A thick 'workman' moustache over the upper lip, drooping at the corners. ``z_off`` is the
    centre line relative to the eyes (head-local metres before height scaling)."""
    k = fit.k
    eye = fit.eye_centre()
    hh = HeadHull(fit)
    m = Mesh()
    pts = []
    for i in range(-8, 9):
        u = i / 8.0
        x = u * half_w * k
        z = eye.z + (z_off - 0.017 * u ** 4) * k
        hit = hh.cast(Vector((x, 0.5, z)), Vector((0, -1, 0)), 0.8)
        y = hit[0].y if hit[0] is not None else eye.y + 0.03 * k
        y += 0.0035 * k - 0.004 * k * u * u
        pts.append(Vector((x, y, z)))
    o.tube(m, pts, lambda t: (0.0022 + thick * (1 - (2 * t - 1) ** 2) ** 0.7) * k, mat, sides=8,
           weights=lambda p, t: HEAD_W)
    return m


# ---------------------------------------------------------------------------------------------
# jewellery and glasses
# ---------------------------------------------------------------------------------------------
def earrings(fit: Fit, mat: str, drop: bool = True) -> Mesh:
    k = fit.k
    eye = fit.eye_centre()
    c = fit.head_centre()
    hh = HeadHull(fit)
    m = Mesh()
    for sx in (-1.0, 1.0):
        best = None
        for dy in (0.000, -0.006, -0.012, 0.006):
            for dz in (-0.040, -0.034, -0.046):
                q = Vector((sx * 0.3, c.y + dy * k, eye.z + dz * k))
                hit = hh.cast(q, Vector((-sx, 0, 0)), 0.4)
                if hit[0] is not None and (best is None or sx * hit[0].x > sx * best.x):
                    best = hit[0]
        if best is None:
            continue
        p = best + Vector((sx * 0.0015 * k, 0, 0))
        g = Gear()
        g.cyl(0.0042 * k, 0.003 * k, centre=(0, 0, 0.0015 * k), axis="Z", segs=12, mat=mat)
        g.bevel(0.001 * k, 1, 30.0)
        m.extend(g.to_mesh(o.frame_from(p, Vector((sx, 0.0, 0.0))), weights=HEAD_W))
        if drop:
            d = p + Vector((0.0, 0.0, -0.016 * k))
            o.tube(m, [p - Vector((0, 0, 0.003 * k)), d], 0.0010 * k, mat, sides=5, weights=lambda q, t: HEAD_W)
            _ellipsoid(m, d - Vector((0, 0, 0.004 * k)), Vector((0.0032, 0.0032, 0.0048)) * k, mat, segs=8, rows=5)
    return m


def heavy_lids(fit: Fit, mat: str, build: float, gender: float, age: float, drop: float = 0.5,
               n_u: int = 12) -> Mesh:
    """A lowered upper lid line (a smoky liner band): a thin shell just over the eyeball from the
    lid margin (``_head.EyeShape`` for the body params) down by ``drop`` of the upper opening, so the
    eyes read heavy-lidded and unimpressed instead of wide. Tucked under the lid at the top."""
    k = fit.k
    es = _head.EyeShape.of(build, gender, age)
    rad = (_head.EYE_RADIUS + 0.0009) * k
    m = Mesh()
    for s_ in ("L", "R"):
        e = Vector(fit.J[f"eye.{s_}"])
        sx = 1.0 if e.x > 0 else -1.0
        f = Vector((sx * 0.10, 1.0, 0.0)).normalized()
        up = (Vector((0, 0, 1)) - f * f.z).normalized()
        lat = f.cross(up).normalized() * sx
        rows = []
        for i in range(n_u + 1):
            u = 0.02 + 0.96 * i / n_u
            psi, ep_top = es.angles(1, u)
            _psi, ep_c = es.angles(0, u)
            ep_hi = ep_top + 4.0
            ep_lo = ep_top - drop * (ep_top - ep_c)
            row = []
            for t in (0.0, 0.5, 1.0):
                pp, ee = math.radians(psi), math.radians(lerp(ep_lo, ep_hi, t))
                d = f * (math.cos(pp) * math.cos(ee)) + lat * (math.sin(pp) * math.cos(ee)) + up * math.sin(ee)
                row.append(m.add(e + d * rad, HEAD_W))
            rows.append(row)
        for i in range(n_u):
            for j in range(2):
                m.face((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]), mat, inside=e)
    return m


def lenses(fit: Fit, mat: str = "char_lens") -> Mesh:
    """Lens discs matching ``_gear_kit.glasses`` (same frame plane and rim outline)."""
    k = fit.k
    hh = HeadHull(fit)
    m = Mesh()
    eyes = {s: Vector(fit.J[f"eye.{s}"]) for s in ("L", "R")}
    y_face = -1.0
    for s in ("L", "R"):
        e = eyes[s]
        for dx in (-0.024, 0.0, 0.024):
            for dz in (-0.016, 0.0, 0.016):
                hit = hh.cast(Vector((e.x + dx * k, 0.4, e.z + dz * k)), Vector((0, -1, 0)), 0.6)
                if hit[0] is not None:
                    y_face = max(y_face, hit[0].y)
    y_f = max(y_face, eyes["R"].y + 0.012 * k) + 0.006 * k
    for s in ("L", "R"):
        e = eyes[s]
        outline = o.rounded_rect(0.047 * k, 0.031 * k, 0.011 * k, 3)
        pts = [Vector((e.x + u, y_f - 0.003 * k * (u / (0.025 * k)) ** 2 + 0.0004, e.z - 0.002 * k + v))
               for u, v in outline]
        ctr = sum(pts, Vector()) / len(pts) + Vector((0, 0.0015 * k, 0))
        ids = m.ring(pts, HEAD_W)
        p = m.add(ctr, HEAD_W)
        nn = len(ids)
        for j in range(nn):
            m.face((ids[j], ids[(j + 1) % nn], p), mat, inside=ctr - Vector((0, 0.05, 0)))
    return m


def lapel_pin(hull: Hull, p: Vector, mat: str, k: float = 1.0) -> Mesh:
    g = Gear()
    g.prism(o.rounded_rect(0.026 * k, 0.006 * k, 0.0025 * k, 2), 0.0, 0.0025 * k, mat)
    g.cyl(0.0042 * k, 0.003 * k, centre=(0.013 * k, 0, 0.0035 * k), axis="Z", segs=10, mat=mat)
    g.bevel(0.0008 * k, 1, 30.0)
    mtx, loc = o.surface_frame(hull, p, Vector((0.0, 1.0, 0.0)), lift=0.0005)
    return g.to_mesh(mtx, anchor=loc)


def lips(fit: Fit, mat: str, mouth_dz: float = -0.0745, half_w: float = 0.0185, upper: float = 0.0062,
         lower: float = 0.0078, lift: float = 0.0007) -> Mesh:
    """Lipstick: a thin shell over the lips, cast onto the face (head-local metres before height
    scaling, ``mouth_dz`` = lip line below the eyes). Cupid's bow on the upper lip, a fuller lower lip,
    and a 1 mm parting gap at the lip line so the mouth still reads."""
    k = fit.k
    eye = fit.eye_centre()
    hh = HeadHull(fit)
    m = Mesh()
    nu, nz = 12, 5

    def outline(u: float, top: bool) -> float:     # lip height at u in -1..1
        if top:
            bow = 1.0 - 0.22 * math.exp(-(u / 0.16) ** 2) + 0.10 * math.exp(-((abs(u) - 0.30) / 0.18) ** 2)
            return upper * bow * (1 - u * u) ** 0.65
        return lower * (1 - u * u) ** 0.55

    for top in (True, False):
        grid = []
        for i in range(nu + 1):
            u = -1.0 + 2.0 * i / nu
            x = u * half_w * k
            h = outline(u, top) * k
            row = []
            for j in range(nz + 1):
                f = j / nz
                gap = 0.0006 * k
                z = eye.z + mouth_dz * k + ((gap + h * f) if top else -(gap + h * f))
                hit = hh.cast(Vector((x, 0.5, z)), Vector((0, -1, 0)), 0.8)
                p = hit[0] + hit[1].normalized() * lift * k if hit[0] is not None else Vector((x, eye.y, z))
                row.append(m.add(p, HEAD_W))
            grid.append(row)
        ref = Vector((0.0, eye.y - 0.05 * k, eye.z + mouth_dz * k))
        for i in range(nu):
            for j in range(nz):
                m.face((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]), mat, inside=ref)
    return m
