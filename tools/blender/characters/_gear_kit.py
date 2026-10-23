"""Hard gear and headwear for D1-02 characters. Blender only.

Hard pieces are ``_outfit.Gear`` builds (``lib.geo.MeshBuilder`` primitives, bevelled before any
UV work), modelled in a local frame (+Z out of the surface, +Y up, +X = Y x Z) and placed on a
surface frame; all vertices of one piece share the skin weights of its anchor point, so the piece
moves rigidly with the surface it sits on. Headwear is fitted to the head + hair surface by rays
(no head vertex indices) and weighted 100 % to ``head``.
"""

from __future__ import annotations

import itertools
import math

import _outfit as o
from _outfit import Fit, Gear, Hull, Mesh, Vector, clamp, lerp, smoothstep

UP = o.UP
HEAD_W = {"head": 1.0}


class HeadHull(Hull):
    """Skin of the head plus the hair mesh."""

    def __init__(self, fit: Fit) -> None:
        self.bvh = fit.head_bvh


def _smooth_circ(vals: list[float], iters: int = 2) -> list[float]:
    n = len(vals)
    for _ in range(iters):
        vals = [0.25 * vals[i - 1] + 0.5 * vals[i] + 0.25 * vals[(i + 1) % n] for i in range(n)]
    return vals


# =============================================================================================
# belts and things on them
# =============================================================================================
class Belt:
    """A belt ring around ``hull`` (pass the trousers/skirt only: rays go outwards from the body axis)
    at height ``z`` (``drop``: lower at the front). Keeps the sampled
    outer surface so gear can be hung on it with ``frame(theta)``."""

    def __init__(self, fit: Fit, hull: Hull, z: float, height: float = 0.04, thick: float = 0.0055,
                 n: int = 48, drop: float = 0.006, gap: float = 0.0012) -> None:
        k = fit.k
        self.k = k
        self.c = fit.ring_centre("hips")
        self.z = z
        self.h = height * k
        self.t = thick * k
        self.n = n
        th = [2 * math.pi * i / n for i in range(n)]
        zc = [z - drop * k * 0.5 * (1 + math.cos(a)) for a in th]
        r = []
        for a, zz in zip(th, zc):
            rr = max(hull.inner_radius(zz + dz * self.h, a, self.c.x, self.c.y) for dz in (-0.45, 0.0, 0.45))
            r.append(rr + gap * k)
        r = _smooth_circ(r, 3)
        self.theta, self.zc, self.r = th, zc, r

    def point(self, a: float, dz: float = 0.0, out: float = 0.0) -> Vector:
        i = (a % (2 * math.pi)) / (2 * math.pi) * self.n
        i0 = math.floor(i) % self.n
        f = i - math.floor(i)
        r = lerp(self.r[i0], self.r[(i0 + 1) % self.n], f) + out
        z = lerp(self.zc[i0], self.zc[(i0 + 1) % self.n], f) + dz
        return Vector((self.c.x + r * math.sin(a), self.c.y + r * math.cos(a), z))

    def frame(self, a: float, dz: float = 0.0, out: float = 0.0):
        p = self.point(a, dz, self.t + out)
        return o.frame_from(p, Vector((math.sin(a), math.cos(a), 0.0)))

    def mesh(self, mat: str, keepers: bool = True) -> Mesh:
        m = Mesh()
        h, t = self.h, self.t
        ch = min(0.0015 * self.k, t * 0.4)
        prof = [(0.0, -h / 2), (t - ch, -h / 2), (t, -h / 2 + ch), (t, h / 2 - ch), (t - ch, h / 2), (0.0, h / 2)]
        rings = []
        for out, dz in prof:
            rings.append(m.ring([self.point(a, dz, out) for a in self.theta]))
        for a, b in zip(rings, rings[1:] + [rings[0]]):
            n = self.n
            for i in range(n):
                j = (i + 1) % n
                q = (a[i], a[j], b[j], b[i])
                m.face(q, mat)
        # orient outward from the axis
        for fi, f in enumerate(m.f):
            c = sum((m.v[i] for i in f), Vector()) / len(f)
            outward = Vector((c.x - self.c.x, c.y - self.c.y, 0.0))
            prof_i = fi // self.n
            if prof_i == 0:
                outward = Vector((0, 0, -1))
            elif prof_i == len(prof) - 2:
                outward = Vector((0, 0, 1))
            elif prof_i == len(prof) - 1:
                outward = -outward
            if o.newell(m.v, f).dot(outward) < 0:
                m.f[fi] = tuple(reversed(f))
        return m


def buckle(belt: Belt, mat: str = "brass", w: float = 0.058, h: float = 0.046) -> Mesh:
    k = belt.k
    g = Gear()
    w, h = w * k, h * k
    outer = [(w / 2, h / 2), (-w / 2, h / 2), (-w / 2, -h / 2), (w / 2, -h / 2)]
    hole = [(w / 2 - 0.009 * k, h / 2 - 0.008 * k), (w / 2 - 0.009 * k, -h / 2 + 0.008 * k),
            (-w / 2 + 0.009 * k, -h / 2 + 0.008 * k), (-w / 2 + 0.009 * k, h / 2 - 0.008 * k)]
    g.mb.prism(outer, holes=[hole], axis="Z", start=0.0, end=0.006 * k, mat=g._mat(mat))
    g.box((-w / 2 + 0.01 * k, -0.004 * k, -0.001), (w / 2 - 0.006 * k, 0.004 * k, 0.003 * k), mat)   # prong bar
    g.bevel(0.0012 * k, 1, 30.0)
    mtx = belt.frame(0.0, out=-0.001)
    return g.to_mesh(mtx, anchor=belt.point(0.0))


def pouch(belt: Belt, a: float, w: float, h: float, d: float, mat: str, flap_mat: str | None = None,
          dz: float = 0.0, snap: str | None = None) -> Mesh:
    """Belt pouch hung at angle ``a`` (0 front, +pi/2 right)."""
    k = belt.k
    w, h, d = w * k, h * k, d * k
    g = Gear()
    g.box((-w / 2, -h / 2, 0.0), (w / 2, h / 2, d), mat)
    g.box((-w / 2 - 0.002 * k, h / 2 - 0.035 * k, d - 0.002 * k), (w / 2 + 0.002 * k, h / 2 + 0.004 * k, d + 0.006 * k),
          flap_mat or mat)
    g.box((-w / 2 + 0.008 * k, h / 2 - 0.004 * k, -0.004 * k), (w / 2 - 0.008 * k, h / 2 + 0.008 * k, 0.003 * k), flap_mat or mat)
    g.bevel(0.004 * k, 1, 30.0)
    if snap:
        g.cyl(0.0055 * k, 0.004 * k, centre=(0.0, h / 2 - 0.02 * k, d + 0.007 * k), axis="Z", segs=10, mat=snap)
    mtx = belt.frame(a, dz=dz - h * 0.15)
    return g.to_mesh(mtx, anchor=belt.point(a, dz))


def key_ring(belt: Belt, a: float, metal: str = "char_metal_silver", key_mat: str = "brass") -> Mesh:
    """G3: a belt key clip at angle ``a`` with a ring and three keys hanging off it (unbevelled, ~150 tris)."""
    k = belt.k
    g = Gear()
    g.box((-0.006 * k, -0.025 * k, 0.0), (0.006 * k, 0.012 * k, 0.004 * k), metal)              # the clip
    g.cyl(0.011 * k, 0.0025 * k, centre=(0.0, -0.036 * k, 0.006 * k), axis="Z", segs=10, mat=metal)   # ring
    for i, (dx, ln) in enumerate(((-0.008, 0.042), (0.0, 0.050), (0.009, 0.038))):
        g.box(((dx - 0.0035) * k, (-0.044 - ln) * k, (0.007 + 0.002 * i) * k),
              ((dx + 0.0035) * k, -0.044 * k, (0.0095 + 0.002 * i) * k), key_mat)
    mtx = belt.frame(a, dz=-0.01 * k)
    return g.to_mesh(mtx, anchor=belt.point(a))


def radio(belt: Belt, a: float, body_mat: str = "polymer_black", dz: float = 0.0, led: str = "char_led_red") -> Mesh:
    """Handheld radio in a belt clip: body, antenna, two knobs, LED."""
    k = belt.k
    w, h, d = 0.058 * k, 0.105 * k, 0.034 * k
    g = Gear()
    g.box((-w / 2, -h / 2, 0.006 * k), (w / 2, h / 2, 0.006 * k + d), body_mat)
    g.box((-0.012 * k, -0.02 * k, 0.0), (0.012 * k, 0.03 * k, 0.008 * k), body_mat)          # clip
    g.box((-w / 2 + 0.006 * k, -h / 2 + 0.012 * k, 0.006 * k + d - 0.001), (w / 2 - 0.006 * k, -0.005 * k, 0.006 * k + d + 0.002 * k),
          "rubber_black")                                                                   # speaker grille plate
    g.bevel(0.004 * k, 1, 30.0)
    g.cyl(0.0042 * k, 0.085 * k, centre=(-w / 2 + 0.012 * k, h / 2 + 0.042 * k, 0.006 * k + d * 0.5), axis="Y", segs=8,
          mat="rubber_black")
    g.cyl(0.0065 * k, 0.012 * k, centre=(w / 2 - 0.013 * k, h / 2 + 0.006 * k, 0.006 * k + d * 0.5), axis="Y", segs=10,
          mat="rubber_black")
    g.cyl(0.0028 * k, 0.004 * k, centre=(0.0, h / 2 + 0.002 * k, 0.006 * k + d * 0.5), axis="Y", segs=6, mat=led)
    mtx = belt.frame(a, dz=dz - 0.03 * k)
    return g.to_mesh(mtx, anchor=belt.point(a, dz))


def holster(belt: Belt, a: float, mat: str = "polymer_black", grip_mat: str = "rubber_black") -> Mesh:
    """Duty holster with the pistol grip showing (patrol)."""
    k = belt.k
    g = Gear()
    g.box((-0.022 * k, -0.17 * k, 0.012 * k), (0.022 * k, 0.0, 0.052 * k), mat)           # shell
    g.box((-0.03 * k, -0.025 * k, 0.0), (0.03 * k, 0.03 * k, 0.014 * k), mat)              # belt loop
    g.box((-0.016 * k, -0.015 * k, 0.016 * k), (0.016 * k, 0.065 * k, 0.048 * k), grip_mat)  # grip
    g.box((-0.024 * k, -0.03 * k, 0.010 * k), (0.024 * k, 0.012 * k, 0.056 * k), mat)      # hood
    g.bevel(0.004 * k, 1, 30.0)
    mtx = belt.frame(a, dz=-0.03 * k)
    # tilt the gun slightly forward (cant)
    tilt = o.Matrix.Rotation(math.radians(-8.0), 4, "Z")
    return g.to_mesh(mtx @ tilt, anchor=belt.point(a))


def flashlight(belt: Belt, a: float) -> Mesh:
    k = belt.k
    g = Gear()
    g.box((-0.018 * k, -0.02 * k, 0.0), (0.018 * k, 0.02 * k, 0.012 * k), "leather_dark")
    g.bevel(0.003 * k, 1, 30.0)
    g.cyl(0.013 * k, 0.15 * k, centre=(0.0, -0.035 * k, 0.026 * k), axis="Y", segs=12, mat="polymer_black")
    g.cyl(0.017 * k, 0.035 * k, centre=(0.0, -0.12 * k, 0.026 * k), axis="Y", segs=12, mat="polymer_black")
    mtx = belt.frame(a, dz=-0.02 * k)
    return g.to_mesh(mtx, anchor=belt.point(a))


# =============================================================================================
# small hard bits
# =============================================================================================
def button(hull: Hull, p: Vector, mat: str, r: float = 0.0055, toward: Vector | None = None, k: float = 1.0,
           thick: float = 0.0025) -> Mesh:
    mtx, loc = o.surface_frame(hull, p, toward or Vector((0, 1, 0)), lift=0.0)
    g = Gear()
    g.cyl(r * k, thick * k, centre=(0, 0, thick * k * 0.5 - 0.0004), axis="Z", segs=10, mat=mat)
    g.bevel(0.0008 * k, 1, 30.0)
    return g.to_mesh(mtx, anchor=loc)


def shield_badge(hull: Hull, p: Vector, toward: Vector, w: float, h: float, rim_mat: str, fill_mat: str,
                 k: float = 1.0, up: Vector = UP, letter: str | None = None, depth: float = 0.004) -> Mesh:
    """Shield-shaped badge: metal rim + coloured enamel inset (+ an optional raised letter H)."""
    mtx, loc = o.surface_frame(hull, p, toward, up=up)
    g = Gear()
    outline = o.shield_outline(w * k, h * k)
    g.prism(outline, -0.0005, depth * k, rim_mat)
    inner = o.shield_outline(w * k * 0.74, h * k * 0.76)
    inner = [(x, y - h * k * 0.03) for x, y in inner]
    g.prism(inner, depth * k * 0.5, depth * k + 0.0012 * k, fill_mat)
    g.bevel(0.0008 * k, 1, 30.0)
    if letter == "H":
        s = min(w, h) * k * 0.42
        hx, hy, bar = 0.5 * s, 0.62 * s, 0.17 * s
        hl = [(-hx, hy), (-hx, -hy), (-hx + bar, -hy), (-hx + bar, -bar * 0.5), (hx - bar, -bar * 0.5), (hx - bar, -hy),
              (hx, -hy), (hx, hy), (hx - bar, hy), (hx - bar, bar * 0.5), (-hx + bar, bar * 0.5), (-hx + bar, hy)]
        hl = [(x, y - h * k * 0.04) for x, y in reversed(hl)]
        g2 = Gear()
        g2.prism(hl, depth * k, depth * k + 0.0025 * k, rim_mat)
        g2.bevel(0.0005 * k, 1, 30.0)
        out = g.to_mesh(mtx, anchor=loc)
        out.extend(g2.to_mesh(mtx, anchor=loc))
        return out
    return g.to_mesh(mtx, anchor=loc)


def bar(hull: Hull, p: Vector, toward: Vector, w: float, h: float, d: float, mat: str, k: float = 1.0,
        up: Vector = UP, bevel: float = 0.0008) -> Mesh:
    mtx, loc = o.surface_frame(hull, p, toward, up=up)
    g = Gear()
    g.box((-w * k / 2, -h * k / 2, -0.0005), (w * k / 2, h * k / 2, d * k), mat)
    g.bevel(bevel * k, 1, 30.0)
    return g.to_mesh(mtx, anchor=loc)


def speaker_mic(hull: Hull, p: Vector, toward: Vector, k: float = 1.0) -> tuple[Mesh, Vector]:
    """Shoulder speaker-mic; returns the mesh and the cable exit point (bottom)."""
    mtx, loc = o.surface_frame(hull, p, toward)
    w, h, d = 0.038 * k, 0.066 * k, 0.022 * k
    g = Gear()
    g.box((-0.008 * k, -0.01 * k, 0.0), (0.008 * k, 0.03 * k, 0.006 * k), "polymer_black")     # clip
    g.box((-w / 2, -h / 2, 0.005 * k), (w / 2, h / 2, 0.005 * k + d), "polymer_black")
    for i in range(4):
        y = -h / 2 + 0.012 * k + i * 0.0085 * k
        g.box((-w / 2 + 0.007 * k, y, 0.005 * k + d - 0.0005), (w / 2 - 0.007 * k, y + 0.0042 * k, 0.005 * k + d + 0.0016 * k),
              "rubber_black")
    g.box((-w / 2 - 0.003 * k, 0.0, 0.009 * k), (-w / 2 + 0.002 * k, 0.022 * k, 0.022 * k), "rubber_black")   # PTT
    g.bevel(0.003 * k, 1, 30.0)
    g.cyl(0.0035 * k, 0.012 * k, centre=(w / 2 - 0.008 * k, h / 2 + 0.005 * k, 0.016 * k), axis="Y", segs=6, mat="char_led_red")
    mesh = g.to_mesh(mtx, anchor=loc)
    exit_pt = mtx @ Vector((0.0, -h / 2 - 0.004 * k, 0.016 * k))
    return mesh, exit_pt


def coil_cable(fit: Fit, hull: Hull, a: Vector, b: Vector, mid: list[Vector], k: float = 1.0,
               coil_r: float = 0.0068, pitch: float = 0.012, wire_r: float = 0.0017, coil_from: float = 0.0,
               coil_to: float = 0.7) -> Mesh:
    """Coiled radio cable from ``a`` through ``mid`` to ``b``, kept off the hull surface."""
    ctrl = [a] + mid + [b]
    # dense path (Catmull-Rom), pushed out of the hull
    path: list[Vector] = []
    for i in range(len(ctrl) - 1):
        p0 = ctrl[max(i - 1, 0)]
        p1, p2 = ctrl[i], ctrl[i + 1]
        p3 = ctrl[min(i + 2, len(ctrl) - 1)]
        seg = max(2, int((p2 - p1).length / (pitch * k / 10.0)))
        for s in range(seg):
            t = s / seg
            t2, t3 = t * t, t * t * t
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            path.append(q)
    path.append(b)
    path = [o.push_out(q, hull, (coil_r + wire_r + 0.002) * k) for q in path]
    total = sum((path[i + 1] - path[i]).length for i in range(len(path) - 1))
    out: list[Vector] = []
    s_acc = 0.0
    prev_side = None
    for i, p in enumerate(path):
        if i:
            s_acc += (p - path[i - 1]).length
        t = s_acc / max(total, 1e-6)
        tang = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        side = tang.cross(UP if abs(tang.dot(UP)) < 0.9 else Vector((1, 0, 0))).normalized()
        if prev_side is not None and side.dot(prev_side) < 0:
            side = -side
        prev_side = side
        up2 = side.cross(tang)
        amp = coil_r * k * smoothstep(coil_from, coil_from + 0.04, t) * smoothstep(coil_to, coil_to - 0.04, t)
        ang = 2 * math.pi * s_acc / (pitch * k)
        out.append(p + side * (amp * math.cos(ang)) + up2 * (amp * math.sin(ang)))
    m = Mesh()
    o.tube(m, out, wire_r * k, "char_cable_black", sides=4)
    return m


# =============================================================================================
# headwear
# =============================================================================================
def _head_ring(fit: Fit, hh: Hull, z: float, n: int, c: Vector, clearance: float) -> list[float]:
    r = [hh.outer_radius(z, 2 * math.pi * i / n, c.x, c.y, far=0.4) for i in range(n)]
    # fill misses (should not happen around the skull) with neighbours
    for i in range(n):
        if r[i] <= 0.0:
            r[i] = max(r[i - 1], r[(i + 1) % n], 0.08 * fit.k)
    return [x + clearance for x in _smooth_circ(r, 2)]


def peaked_cap(fit: Fit, crown_mat: str, band_mat: str | tuple[str, str], visor_mat: str, cord_mat: str = "brass",
               badge: bool = True, n: int = 40, flare: float = 1.20, rise: tuple[float, float] = (0.034, 0.056),
               band_h: float = 0.040, check_rows: int = 0, badge_mats: tuple[str, str] | None = None,
               visor_reach: float = 0.058, crown_dome: float = 0.008, visor_tilt: float = 24.0) -> tuple[Mesh, dict]:
    """Service (peaked) cap: band, flared crown with a forward-tilted top, glossy visor, chin cord
    with side buttons and a cap badge. Returns (mesh, info with the hat seat).

    Defaults are the Halden Security cap (saucer crown, gold cord). ``flare`` (crown top radius /
    band radius), ``rise`` (crown height above the band at the back/front) and ``crown_dome`` shape
    the crown; ``check_rows`` > 0 with a ``band_mat`` pair builds a chequered (Sillitoe) band of
    that many rows of square-ish checks; ``badge_mats`` = (rim, fill); ``visor_tilt`` = visor droop
    in degrees (kept shallow so the brows and eyes read under the peak)."""
    k = fit.k
    hh = HeadHull(fit)
    eye = fit.eye_centre()
    c = fit.head_centre()
    th = [2 * math.pi * i / n for i in range(n)]
    zb0 = eye.z + 0.046 * k                       # band bottom at the front (clear of the brows)
    band_h = band_h * k
    if isinstance(band_mat, tuple):
        band_a, band_b = band_mat
    else:
        band_a = band_b = band_mat

    def zb(a: float) -> float:
        return zb0 - 0.006 * k * (1 - math.cos(a)) * 0.5

    radii = [max(hh.outer_radius(zb(a) + dz, a, c.x, c.y, far=0.4) for dz in (0.0, band_h * 0.5, band_h)) for a in th]
    radii = [x + 0.0055 * k for x in _smooth_circ(radii, 3)]
    m = Mesh()
    w = HEAD_W

    def ring(rad: list[float], zf, grow: float = 0.0, fwd: float = 0.0) -> list[int]:
        pts = []
        for a, r in zip(th, rad):
            rr = r + grow
            pts.append(Vector((c.x + rr * math.sin(a), c.y + rr * math.cos(a) + fwd, zf(a))))
        return m.ring(pts, w)

    r_band0 = ring(radii, lambda a: zb(a) - 0.001)
    band_rings = [r_band0]
    for row in range(1, max(check_rows, 1)):
        band_rings.append(ring(radii, lambda a, f=row / check_rows: zb(a) + band_h * f))
    r_band1 = ring(radii, lambda a: zb(a) + band_h)
    band_rings.append(r_band1)
    r_welt = ring(radii, lambda a: zb(a) + band_h + 0.004 * k, grow=0.0035 * k)
    crown_top = [x * flare + 0.012 * k for x in radii]

    def z_top(a: float) -> float:
        return zb(a) + band_h + lerp(rise[0], rise[1], 0.5 * (1 + math.cos(a))) * k

    r_c1 = ring([lerp(r, t, 0.55) for r, t in zip(radii, crown_top)],
                lambda a: lerp(zb(a) + band_h, z_top(a), 0.45), fwd=0.006 * k)
    r_c2 = ring(crown_top, lambda a: z_top(a) - 0.004 * k, fwd=0.014 * k)
    r_c3 = ring([t - 0.006 * k for t in crown_top], lambda a: z_top(a) + 0.002 * k, fwd=0.014 * k)
    r_c4 = ring([t * 0.62 for t in crown_top], lambda a: z_top(a) + crown_dome * k - 0.004 * k * math.cos(a),
                fwd=0.012 * k)
    ctr = c + Vector((0.0, 0.012 * k, 0.0))
    top_pole = m.add(Vector((ctr.x, ctr.y, max(z_top(0), z_top(math.pi)) + (crown_dome + 0.001) * k)), w)
    for row, (a_, b_) in enumerate(itertools.pairwise(band_rings)):
        s0 = len(m.f)
        m.band(a_, b_, band_a, inside=ctr + Vector((0, 0, 0.02)))
        if check_rows:
            for i in range(n):
                if (i + row) % 2:
                    m.m[s0 + i] = band_b
    seq = [(r_band1, r_welt, crown_mat), (r_welt, r_c1, crown_mat),
           (r_c1, r_c2, crown_mat), (r_c2, r_c3, crown_mat), (r_c3, r_c4, crown_mat)]
    for a_, b_, mt in seq:
        m.band(a_, b_, mt, inside=ctr + Vector((0, 0, 0.02)))
    m.fan(r_c4, top_pole, crown_mat)
    _orient_out(m, len(m.f) - n, ctr - Vector((0, 0, 0.1)))
    # inner band (thickness) so the cap does not look paper-thin from below
    r_in = ring([r - 0.004 * k for r in radii], lambda a: zb(a) + 0.012 * k)
    for i in range(n):
        j = (i + 1) % n
        m.face((r_band0[i], r_band0[j], r_in[j], r_in[i]), band_a, inside=Vector((c.x, c.y, zb0 + 0.04 * k)))
    # visor: front arc, tilted down
    arc = [a for a in th if math.cos(a) > -0.05] + []
    arc_idx = [i for i, a in enumerate(th) if math.cos(a) > 0.02]
    arc_idx = sorted(arc_idx, key=lambda i: o.wrap(th[i]))
    vi_in_top, vi_out_top, vi_in_bot, vi_out_bot = [], [], [], []
    for i in arc_idx:
        a = th[i]
        cosf = max(0.0, math.cos(a))
        reach = visor_reach * k * cosf ** 0.75
        base_r = radii[i] + 0.001
        p_in = Vector((c.x + base_r * math.sin(a), c.y + base_r * math.cos(a), zb(a) + 0.002 * k))
        d = Vector((math.sin(a), math.cos(a), 0.0))
        tilt = math.radians(visor_tilt)
        p_out = p_in + (d * math.cos(tilt) - UP * math.sin(tilt)) * reach
        p_out.z -= 0.004 * k * cosf
        vi_in_top.append(m.add(p_in + UP * 0.0025 * k, w))
        vi_out_top.append(m.add(p_out + UP * 0.0016 * k, w))
        vi_in_bot.append(m.add(p_in - UP * 0.0012 * k, w))
        vi_out_bot.append(m.add(p_out - UP * 0.0012 * k, w))
    _ = arc
    up_ref = Vector((c.x, c.y + 0.02 * k, zb0 + 0.2))
    down_ref = Vector((c.x, c.y + 0.02 * k, zb0 - 0.2))
    for j in range(len(arc_idx) - 1):
        m.face((vi_in_top[j], vi_in_top[j + 1], vi_out_top[j + 1], vi_out_top[j]), visor_mat, inside=down_ref)
        m.face((vi_in_bot[j], vi_in_bot[j + 1], vi_out_bot[j + 1], vi_out_bot[j]), visor_mat, inside=up_ref)
        m.face((vi_out_top[j], vi_out_top[j + 1], vi_out_bot[j + 1], vi_out_bot[j]), visor_mat, inside=Vector((c.x, c.y, zb0)))
    for ends in ((0, 1), (len(arc_idx) - 1, -1)):
        e = ends[0]
        m.face((vi_in_top[e], vi_out_top[e], vi_out_bot[e], vi_in_bot[e]), visor_mat,
               inside=Vector((c.x, c.y + 0.05 * k, zb0)) - Vector((0, 0, 0)))
    # chin cord (gold braid) above the visor, from side button to side button
    cord_pts = []
    for i in range(-14, 15):
        a = math.radians(5.5 * i)
        r = _interp_circ(radii, a) + 0.0028 * k
        cord_pts.append(Vector((c.x + r * math.sin(a), c.y + r * math.cos(a), zb(a) + 0.009 * k + 0.004 * k * (1 - math.cos(a)))))
    o.tube(m, cord_pts, 0.0021 * k, cord_mat, sides=6, weights=lambda p, t: HEAD_W)
    cord2 = [p + UP * 0.0045 * k for p in cord_pts]
    o.tube(m, cord2, 0.0019 * k, cord_mat, sides=6, weights=lambda p, t: HEAD_W)
    for p in (cord_pts[0], cord_pts[-1]):
        dirv = Vector((p.x - c.x, p.y - c.y, 0.0)).normalized()
        g = Gear()
        g.cyl(0.0048 * k, 0.003 * k, centre=(0, 0, 0.0012 * k), axis="Z", segs=10, mat=cord_mat)
        g.bevel(0.0008 * k, 1, 30.0)
        m.extend(g.to_mesh(o.frame_from(p + UP * 0.002 * k, dirv), weights=HEAD_W))
    if badge:
        a = 0.0
        p = Vector((c.x, c.y + (radii[0] + crown_top[0]) * 0.5 + 0.02 * k, zb(0) + band_h + 0.016 * k))
        nrm = Vector((0.0, 1.0, 0.55)).normalized()
        hit = None
        cap_hull = Hull(fit, [m])
        hit = cap_hull.cast(p + nrm * 0.1, -nrm, 0.2)
        loc = hit[0] if hit[0] is not None else p
        hn = hit[1] if hit[0] is not None else nrm
        if hn.dot(nrm) < 0:
            hn = -hn
        rim_m, fill_m = badge_mats or (cord_mat, "char_sec_burgundy")
        g = Gear()
        g.prism(o.shield_outline(0.024 * k, 0.026 * k), -0.0005, 0.003 * k, rim_m)
        g.prism([(x, y - 0.001 * k) for x, y in o.shield_outline(0.016 * k, 0.017 * k)], 0.0015 * k, 0.0038 * k,
                fill_m)
        g.bevel(0.0007 * k, 1, 30.0)
        m.extend(g.to_mesh(o.frame_from(loc, hn), weights=HEAD_W))
        del a
    info = {"crown_top_z": max(z_top(0), z_top(math.pi)) + 0.009 * k, "band_z": zb0}
    return m, info


def _interp_circ(vals: list[float], a: float) -> float:
    n = len(vals)
    i = (a % (2 * math.pi)) / (2 * math.pi) * n
    i0 = math.floor(i) % n
    f = i - math.floor(i)
    return lerp(vals[i0], vals[(i0 + 1) % n], f)


def _orient_out(m: Mesh, start: int, inside: Vector) -> None:
    for fi in range(start, len(m.f)):
        f = m.f[fi]
        c = sum((m.v[i] for i in f), Vector()) / len(f)
        if o.newell(m.v, f).dot(c - inside) < 0:
            m.f[fi] = tuple(reversed(f))


def helmet(fit: Fit, shell_mat: str, rail_mat: str = "polymer_black", n: int = 36, gap: float = 0.021,
           cup_r: float = 0.036) -> tuple[Mesh, dict]:
    """High-cut ballistic helmet over head + hair: dome rings, a thick rim with high ear cuts,
    side rails, a front shroud, ear-pro cups and a strap. ``gap`` = shell stand-off from the
    head/hair (helmet size), ``cup_r`` = ear-pro cup radius. 100 % head."""
    k = fit.k
    hh = HeadHull(fit)
    eye = fit.eye_centre()
    c = fit.head_centre()
    top = fit.head_top()
    th = [2 * math.pi * i / n for i in range(n)]
    gap = gap * k

    def rim_z(a: float) -> float:
        ca = math.cos(a)
        side = abs(math.sin(a))
        z_front = eye.z + 0.030 * k
        z_back = eye.z - 0.020 * k
        z = lerp(z_back, z_front, 0.5 * (1 + ca))
        # high cut over the ears
        z += 0.034 * k * smoothstep(0.55, 0.95, side) * smoothstep(-0.6, 0.1, ca)
        return z

    levels = 8
    rings_ids: list[list[int]] = []
    w = HEAD_W
    m = Mesh()

    def shell_pt(dirv: Vector) -> Vector:
        dirv = dirv.normalized()
        hit = hh.cast(c + dirv * 0.4, -dirv, 0.4)
        r = (0.4 - hit[3]) if hit[0] is not None else 0.09 * k
        return c + dirv * (r + gap)

    for li in range(levels):
        f = li / levels
        pts = []
        for a in th:
            hz = rim_z(a) - c.z
            e0 = math.atan2(hz, 0.095 * k)
            e = lerp(e0, math.radians(90.0), f)
            d = Vector((math.cos(e) * math.sin(a), math.cos(e) * math.cos(a), math.sin(e)))
            pts.append(shell_pt(d))
        rings_ids.append(m.ring(pts, w))
    for ring in rings_ids[1:]:
        cx, cy = c.x, c.y
        rs = [math.hypot(m.v[i].x - cx, m.v[i].y - cy) for i in ring]
        rs = _smooth_circ(rs, 2)
        for i, r in zip(ring, rs):
            a = math.atan2(m.v[i].x - cx, m.v[i].y - cy)
            m.v[i] = Vector((cx + r * math.sin(a), cy + r * math.cos(a), m.v[i].z))
    pole = m.add(shell_pt(Vector((0.0, -0.05, 1.0))), w)
    inside = Vector((c.x, c.y, eye.z + 0.02 * k))
    for a_, b_ in itertools.pairwise(rings_ids):
        m.band(a_, b_, shell_mat, inside=inside)
    m.fan(rings_ids[-1], pole, shell_mat)
    _orient_out(m, len(m.f) - n, inside)
    # rim: thickness lip
    rim = rings_ids[0]
    rim_in = m.ring([Vector((c.x + (math.hypot(m.v[i].x - c.x, m.v[i].y - c.y) - 0.011 * k) * math.sin(a),
                             c.y + (math.hypot(m.v[i].x - c.x, m.v[i].y - c.y) - 0.011 * k) * math.cos(a),
                             m.v[i].z)) for i, a in zip(rim, th)], w)
    rim_in2 = m.ring([m.v[i] + UP * 0.02 * k for i in rim_in], w)
    s = len(m.f)
    m.band(rim, rim_in, "rubber_black")
    m.band(rim_in, rim_in2, shell_mat)
    for fi in range(s, len(m.f)):
        f = m.f[fi]
        cc = sum((m.v[i] for i in f), Vector()) / len(f)
        want = Vector((0, 0, -1)) if fi - s < n else -(cc - Vector((c.x, c.y, cc.z)))
        if o.newell(m.v, f).dot(want) < 0:
            m.f[fi] = tuple(reversed(f))
    helm_hull = Hull(fit, [m])
    # side rails + front shroud
    for sx in (-1.0, 1.0):
        a = sx * math.radians(98.0)
        p = Vector((c.x + 0.2 * math.sin(a), c.y + 0.2 * math.cos(a), eye.z + 0.048 * k))
        mtx, _loc = o.surface_frame(helm_hull, p, Vector((math.sin(a), math.cos(a), 0.0)), up=UP)
        g = Gear()
        g.box((-0.042 * k, -0.011 * k, -0.002 * k), (0.042 * k, 0.011 * k, 0.009 * k), rail_mat)
        for j in range(4):
            x = -0.033 * k + j * 0.022 * k
            g.box((x - 0.004 * k, -0.012 * k, 0.006 * k), (x + 0.004 * k, 0.012 * k, 0.011 * k), rail_mat)
        g.bevel(0.0018 * k, 1, 30.0)
        m.extend(g.to_mesh(mtx, weights=w))
    p = Vector((c.x, c.y + 0.2, rim_z(0.0) + 0.028 * k))
    mtx, _loc = o.surface_frame(helm_hull, p, Vector((0, 1, 0.15)), up=UP)
    g = Gear()
    g.box((-0.032 * k, -0.018 * k, -0.002 * k), (0.032 * k, 0.018 * k, 0.010 * k), rail_mat)
    g.box((-0.012 * k, -0.012 * k, 0.008 * k), (0.012 * k, 0.012 * k, 0.016 * k), rail_mat)
    g.bevel(0.002 * k, 1, 30.0)
    m.extend(g.to_mesh(mtx, weights=w))
    # ear-pro cups + headband
    cup_pts = []
    for sx in (-1.0, 1.0):
        q = Vector((sx * 0.3, c.y - 0.012 * k, eye.z - 0.012 * k))
        hit = hh.cast(q, Vector((-sx, 0, 0)), 0.4)
        ear = hit[0] if hit[0] is not None else Vector((sx * 0.075 * k, c.y, eye.z))
        cup_c = Vector((ear.x + sx * 0.014 * k, ear.y, ear.z))
        g = Gear()
        g.cyl(cup_r * k, 0.034 * k, centre=(0, 0, 0.017 * k), axis="Z", segs=14, mat="char_tac_helmet")
        g.cyl((cup_r - 0.005) * k, 0.010 * k, centre=(0, 0, 0.036 * k), axis="Z", segs=14, mat="rubber_black")
        g.bevel(0.004 * k, 1, 30.0)
        m.extend(g.to_mesh(o.frame_from(cup_c, Vector((sx, 0, 0)), up=UP), weights=w))
        cup_pts.append(cup_c + Vector((sx * 0.018 * k, 0, 0)))
    info = {"top_z": top + gap}
    return m, info


def glasses(fit: Fit, frame_mat: str, loupe: bool = False, loupe_mat: str = "polymer_black") -> Mesh:
    """Thin-rimmed reading glasses fitted to the face by rays; optional jeweler's loupe on the
    right lens. 100 % head."""
    k = fit.k
    hh = HeadHull(fit)
    m = Mesh()
    w = HEAD_W
    eyes = {s: Vector(fit.J[f"eye.{s}"]) for s in ("L", "R")}
    # frame plane: in front of the brow/cheek surface around both eyes
    y_face = -1.0
    for s in ("L", "R"):
        e = eyes[s]
        for dx in (-0.024, 0.0, 0.024):
            for dz in (-0.016, 0.0, 0.016):
                q = Vector((e.x + dx * k, 0.4, e.z + dz * k))
                hit = hh.cast(q, Vector((0, -1, 0)), 0.6)
                if hit[0] is not None:
                    y_face = max(y_face, hit[0].y)
    y_f = max(y_face, eyes["R"].y + 0.012 * k) + 0.006 * k
    rims = {}
    for s in ("L", "R"):
        e = eyes[s]
        outline = o.rounded_rect(0.050 * k, 0.034 * k, 0.012 * k, 3)
        pts = [Vector((e.x + u, y_f - 0.003 * k * (u / (0.025 * k)) ** 2, e.z - 0.002 * k + v)) for u, v in outline]
        pts.append(pts[0])
        o.tube(m, pts, 0.0017 * k, frame_mat, sides=5, weights=lambda p, t: w, caps=False)
        rims[s] = pts
    # bridge
    br = [Vector((eyes["L"].x + 0.025 * k, y_f + 0.001, eyes["L"].z + 0.006 * k)),
          Vector((0.0, y_f + 0.004 * k, eyes["L"].z + 0.010 * k)),
          Vector((eyes["R"].x - 0.025 * k, y_f + 0.001, eyes["R"].z + 0.006 * k))]
    o.tube(m, br, 0.0016 * k, frame_mat, sides=5, weights=lambda p, t: w)
    # temples to the ears: on the scalp skin (no hair, no ears), so they slip under the hair at the
    # temple and run to the ear root, then hook down behind the ear
    c = fit.head_centre()
    for s, sx in (("L", -1.0), ("R", 1.0)):
        e = eyes[s]
        start = Vector((e.x + sx * 0.026 * k, y_f - 0.004 * k, e.z + 0.006 * k))
        pts = [start]
        for f in (0.15, 0.35, 0.55, 0.75, 0.92):
            y = lerp(start.y, c.y - 0.012 * k, f)
            q = Vector((sx * 0.3, y, start.z - 0.006 * k * f))
            hit = fit.scalp_bvh.ray_cast(q, Vector((-sx, 0, 0)), 0.4)
            x = hit[0].x + sx * 0.0022 * k if hit[0] is not None else start.x
            # the first stretch stands off the temple a little (the hinge), then lies on the skin
            x += sx * 0.003 * k * (1.0 - smoothstep(0.1, 0.5, f))
            pts.append(Vector((x, y, q.z)))
        last = pts[-1]
        pts.append(Vector((last.x - sx * 0.0005 * k, last.y - 0.010 * k, last.z - 0.012 * k)))
        pts.append(Vector((last.x - sx * 0.0010 * k, last.y - 0.014 * k, last.z - 0.026 * k)))
        o.tube(m, pts, 0.0015 * k, frame_mat, sides=5, weights=lambda p, t: w)
    if loupe:
        e = eyes["R"]
        g = Gear()
        g.cyl(0.0125 * k, 0.026 * k, centre=(0, 0, 0.013 * k), axis="Z", segs=14, mat=loupe_mat)
        g.cyl(0.0105 * k, 0.004 * k, centre=(0, 0, 0.0262 * k), axis="Z", segs=14, mat="char_lens")
        g.cyl(0.0140 * k, 0.004 * k, centre=(0, 0, 0.002 * k), axis="Z", segs=14, mat=frame_mat)
        g.bevel(0.0012 * k, 1, 30.0)
        m.extend(g.to_mesh(o.frame_from(Vector((e.x, y_f + 0.001, e.z - 0.002 * k)), Vector((0, 1, 0))), weights=w))
    return m


def knee_pads(fit: Fit, hull: Hull, mat: str = "polymer_black", strap_mat: str = "char_tac_gear") -> Mesh:
    k = fit.k
    m = Mesh()
    for sfx in ("L", "R"):
        kc = fit.ring_centre(f"knee.{sfx}")
        p = kc + Vector((0, 0.2, 0.012 * k))
        mtx, loc = o.surface_frame(hull, p, Vector((0, 1, 0.05)), up=UP)
        g = Gear()
        g.box((-0.045 * k, -0.062 * k, -0.004 * k), (0.045 * k, 0.062 * k, 0.020 * k), mat)
        g.box((-0.034 * k, -0.045 * k, 0.016 * k), (0.034 * k, 0.050 * k, 0.026 * k), mat)
        g.bevel(0.007 * k, 2, 30.0)
        m.extend(g.to_mesh(mtx, anchor=loc))
        # straps above and below the pad
        for dz in (0.045, -0.050):
            ctr = kc + Vector((0, 0, dz * k))
            pts = []
            for i in range(24):
                a = 2 * math.pi * i / 24
                r = hull.outer_radius(ctr.z, a, ctr.x, ctr.y, far=0.3)
                r = (r if r > 0 else 0.06 * k) + 0.002 * k
                pts.append(Vector((ctr.x + r * math.sin(a), ctr.y + r * math.cos(a), ctr.z)))
            pts.append(pts[0])
            o.tube(m, pts, 0.0035 * k, strap_mat, sides=4, caps=False)
    return m


def name_tag(hull: Hull, p: Vector, k: float = 1.0, mat: str = "brass") -> Mesh:
    return bar(hull, p, Vector((0, 1, 0)), 0.062, 0.013, 0.0022, mat, k=k)


__all__ = ["Belt", "HeadHull", "bar", "buckle", "button", "clamp", "coil_cable", "flashlight", "glasses", "helmet",
           "holster", "key_ring", "knee_pads", "name_tag", "peaked_cap", "pouch", "radio", "shield_badge",
           "speaker_mic"]
