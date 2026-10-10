"""Parametric crew-mask generator (D1-04). Private helper: imported by mask scripts, never built.

A mask = one face **shell** (a thick, chamfered surface with eye/mouth holes) plus optional
**ornaments** (raised plates, inlays, lofted parts such as a beak) that conform to the same face
surface. A new crew mask is a param dict plus ornament functions::

    import _mask_base as mask

    ASSET_ID = "mask_porcelain_fox"
    TRI_BUDGET = 8000
    PARAMS = {"coverage": "full", "brow": 1.2, "eye_shape": "almond", "mouth": "slit"}

    def _whiskers(kit: mask.MaskKit) -> None:
        for leaf in [mask.leaf((0.03, -0.03), (0.09, -0.02), 0.008)]:
            for loop in mask.mirrored(leaf):
                kit.plate(loop, hi=0.0015, mat="accent")

    def build(ctx) -> None:
        mats = mask.materials(ctx, primary=("char_mask_porcelain", "#E4DED2", 0.35, 0.0))
        mask.build_mask(ctx, PARAMS, mats, ornaments=[_whiskers])

Axes and pivot (contracts: mask_def.gd "pivot at the face centre, -Z forward")
--------------------------------------------------------------------------------
Blender coordinates, metres. **Origin = the face centre: midway between the two eye centres, at
the depth of the eyes (the cornea plane, i.e. the eye-socket depth of the wearer).** +Y = forward
(out of the face) = Godot -Z; +Z = up = Godot +Y; +X = Godot +X. The eye centres sit at
(±eye_spacing/2 on the face surface, z = eye_v), so with the defaults the eye line is z = 0. The
shell's outer surface crosses the centreline about 20 mm in front of the origin (nose bridge). The
mask attaches to the crew ``Head`` BoneAttachment3D (contracts/characters.md); the character rig
places the attachment at the same face centre.

Design space
------------
Outlines and ornaments are drawn in 2D **(u, v)** face coordinates, both roughly metres:
``v`` = height above the eye line (= Blender z), ``u`` = arc length across the face (0 at the
centreline, + to Blender +X). ``FaceSurface.point(u, v, offset)`` maps them onto the 3D face,
``offset`` metres along the surface normal (0 = the shell's outer skin, -thickness = inner skin).
Reference head: an adult ~1.78 m male, face width ~0.15 m (x = ±W at the cheekbones), forehead to
chin ~0.22 m. Loops are lists of (u, v); any winding is accepted.

Determinism: pure math, no randomness (pass ``ctx.rng`` into your ornaments if you want variation).
Geometry is built with explicit chamfer rings (no bmesh bevel), so UVs are projected last
(``uv.box_project``) per the pipeline rule "chamfer first, UV after".
"""

from __future__ import annotations

import math
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from typing import Any

import bmesh
import bpy
from mathutils import Vector, geometry

from lib import geo, uv

Point2 = tuple[float, float]
Loop2 = list[Point2]

# --- parameters --------------------------------------------------------------------------------
DEFAULTS: dict[str, Any] = {
    # coverage: "full" (forehead to chin) | "half" (forehead to below the nose) | "visor" (eye band)
    "coverage": "full",
    "top": 0.105,            # outline top above the eye line (m)
    "bottom": -0.115,        # outline bottom (chin) for "full"
    "half_bottom": -0.052,   # lower edge for "half"
    "visor_top": 0.042,      # band for "visor"
    "visor_bottom": -0.030,
    "side_arc": 0.105,       # half width of the outline at eye level, as arc length u (m)
    "top_peak": 0.0,         # extra pointed rise at the top centre (widow's peak / crest), m
    "chin_point": 0.0,       # extra pointed drop at the chin, m
    "jaw_taper": 0.30,       # 0 = straight sides, 0.5 = strongly tapered lower outline
    # head / face form (prominence multipliers, 0 = flat, 1 = natural, 2 = exaggerated)
    "face_half_width": 0.080,  # W at the cheekbones (x = ±W at the side of the head)
    "wrap_radius": 0.085,      # horizontal curvature: u -> angle = u / wrap_radius
    "brow": 1.0,
    "cheek": 1.0,
    "jaw": 1.0,
    "nose": 1.0,
    # eyes
    "eye_shape": "almond",   # almond | round | slit | deco (hexagonal, pointed)
    "eye_width": 0.034,
    "eye_height": 0.016,
    "eye_spacing": 0.066,    # centre to centre (arc length)
    "eye_v": 0.0,
    "eye_tilt_deg": 6.0,     # outer corner raised
    # mouth: closed (sculpted lips, no hole) | open | slit | none
    "mouth": "none",
    "mouth_width": 0.046,
    "mouth_height": 0.012,
    "mouth_v": -0.068,
    # shell
    "thickness": 0.005,      # real shell thickness (4-6 mm)
    "chamfer": 0.0015,       # rim chamfer on both skins (edge bevel)
    "res": 0.0085,           # interior triangle size, outer skin
    "res_back": 0.014,       # interior triangle size, inner skin (rarely seen)
    "edge_res": 0.005,       # boundary sampling
}

CORNER_DEG = 35.0  # turning angle above which an outline vertex is kept as a hard corner


def params_with_defaults(params: dict[str, Any] | None) -> dict[str, Any]:
    """DEFAULTS overridden by ``params``. Extra keys (ornament params) are kept and ignored here."""
    out = dict(DEFAULTS)
    out.update(params or {})
    return out


# --- 2D loop helpers ---------------------------------------------------------------------------
def signed_area(loop: Sequence[Point2]) -> float:
    a = 0.0
    n = len(loop)
    for i in range(n):
        x0, y0 = loop[i]
        x1, y1 = loop[(i + 1) % n]
        a += x0 * y1 - x1 * y0
    return a * 0.5


def oriented(loop: Sequence[Point2], ccw: bool) -> Loop2:
    """``loop`` with counter-clockwise (``ccw``) or clockwise winding in (u, v)."""
    pts = [(float(p[0]), float(p[1])) for p in loop]
    if (signed_area(pts) > 0) != ccw:
        pts.reverse()
    return pts


def mirror(loop: Sequence[Point2]) -> Loop2:
    """Mirror across the centreline (u -> -u), keeping the winding."""
    return [(-p[0], p[1]) for p in reversed(loop)]


def mirrored(loop: Sequence[Point2]) -> list[Loop2]:
    """[loop, mirror(loop)]: right and left copies of a one-sided shape."""
    return [list(loop), mirror(loop)]


def point_in_loop(p: Point2, loop: Sequence[Point2]) -> bool:
    x, y = p
    inside = False
    n = len(loop)
    j = n - 1
    for i in range(n):
        xi, yi = loop[i]
        xj, yj = loop[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def _seg_dist(p: Point2, a: Point2, b: Point2) -> float:
    ax, ay = a
    dx, dy = b[0] - ax, b[1] - ay
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / l2))
    ex, ey = ax + t * dx - p[0], ay + t * dy - p[1]
    return math.sqrt(ex * ex + ey * ey)


def _corners(loop: Sequence[Point2], corner_deg: float) -> list[int]:
    n = len(loop)
    out = []
    lim = math.radians(corner_deg)
    for i in range(n):
        a, b, c = loop[i - 1], loop[i], loop[(i + 1) % n]
        a1 = math.atan2(b[1] - a[1], b[0] - a[0])
        a2 = math.atan2(c[1] - b[1], c[0] - b[0])
        d = abs((a2 - a1 + math.pi) % (2 * math.pi) - math.pi)
        if d > lim:
            out.append(i)
    return out


def _resample_open(chain: Sequence[Point2], spacing: float) -> Loop2:
    """Resample an open polyline (both ends kept); returns all points except the last."""
    lens = [0.0]
    for i in range(1, len(chain)):
        lens.append(lens[-1] + math.dist(chain[i - 1], chain[i]))
    total = lens[-1]
    n = max(1, round(total / spacing))
    out: Loop2 = []
    j = 0
    for k in range(n):
        d = total * k / n
        while j < len(lens) - 2 and lens[j + 1] < d:
            j += 1
        seg = lens[j + 1] - lens[j]
        t = 0.0 if seg == 0 else (d - lens[j]) / seg
        a, b = chain[j], chain[j + 1]
        out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def resample(loop: Sequence[Point2], spacing: float, corner_deg: float = CORNER_DEG) -> Loop2:
    """Evenly resample a closed loop at ~``spacing``, keeping hard corners exactly."""
    pts = [(float(p[0]), float(p[1])) for p in loop]
    corners = _corners(pts, corner_deg)
    if not corners:
        return _resample_open(pts + [pts[0]], spacing)
    out: Loop2 = []
    for k, ci in enumerate(corners):
        cj = corners[(k + 1) % len(corners)]
        chain = [pts[ci]]
        i = ci
        while True:
            i = (i + 1) % len(pts)
            chain.append(pts[i])
            if i == cj:
                break
        out.extend(_resample_open(chain, spacing))
    return out


def offset_loop(loop: Sequence[Point2], d: float, max_miter: float = 2.5) -> Loop2:
    """Move every vertex ``d`` to the left of the loop direction (miter join, clamped).

    For a CCW outline (or a CW hole) ``d > 0`` moves into the material."""
    n = len(loop)
    out: Loop2 = []
    for i in range(n):
        a, b, c = loop[i - 1], loop[i], loop[(i + 1) % n]
        e1 = Vector((b[0] - a[0], b[1] - a[1]))
        e2 = Vector((c[0] - b[0], c[1] - b[1]))
        if e1.length == 0 or e2.length == 0:
            out.append(b)
            continue
        e1.normalize()
        e2.normalize()
        n1 = Vector((-e1.y, e1.x))
        n2 = Vector((-e2.y, e2.x))
        m = n1 + n2
        if m.length < 1e-6:
            m = n1
        m.normalize()
        cosh = max(m.dot(n1), 1.0 / max_miter)
        out.append((b[0] + m.x * d / cosh, b[1] + m.y * d / cosh))
    return out


def superellipse(cu: float, cv: float, a: float, b_top: float, b_bottom: float, p: float,
                 n: int = 64, p_bottom: float | None = None) -> Loop2:
    """Closed superellipse loop (CCW) centred at (cu, cv); separate upper/lower half heights."""
    pb = p if p_bottom is None else p_bottom
    out: Loop2 = []
    for i in range(n):
        t = 2 * math.pi * i / n
        c, s = math.cos(t), math.sin(t)
        e = p if s >= 0 else pb
        u = a * math.copysign(abs(c) ** (2 / e), c)
        v = (b_top if s >= 0 else b_bottom) * math.copysign(abs(s) ** (2 / e), s)
        out.append((cu + u, cv + v))
    return out


def almond(cu: float, cv: float, half_w: float, half_h: float, point: float = 1.8,
           tilt_deg: float = 0.0, n: int = 40, lower: float = 1.0) -> Loop2:
    """Eye-like loop: ``point`` 1 = ellipse, 2 = sharp corners; ``lower`` scales the lower lid;
    ``tilt_deg`` rotates it (positive raises the +u corner)."""
    out: Loop2 = []
    ct, st = math.cos(math.radians(tilt_deg)), math.sin(math.radians(tilt_deg))
    for i in range(n):
        t = 2 * math.pi * i / n
        s = math.sin(t)
        x = half_w * math.cos(t)
        y = half_h * math.copysign(abs(s) ** point, s) * (1.0 if s >= 0 else lower)
        out.append((cu + x * ct - y * st, cv + x * st + y * ct))
    return out


def quad_bezier(p0: Point2, p1: Point2, p2: Point2, t: float) -> Point2:
    a = (1 - t) * (1 - t)
    b = 2 * (1 - t) * t
    c = t * t
    return (a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1])


def leaf(root: Point2, tip: Point2, width: float, bend: float = 0.0, n: int = 10,
         root_round: float = 0.35, fullness: float = 0.7) -> Loop2:
    """Feather/leaf plate from ``root`` to a pointed ``tip``.

    ``bend`` bows the spine sideways (fraction of the length, + = to the left of root->tip);
    ``fullness`` <1 shifts the widest point toward the root; ``root_round`` rounds the root end."""
    dx, dy = tip[0] - root[0], tip[1] - root[1]
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    mid = (root[0] + dx * 0.5 + nx * bend * length, root[1] + dy * 0.5 + ny * bend * length)
    left: Loop2 = []
    right: Loop2 = []
    for i in range(n + 1):
        t = i / n
        sp = quad_bezier(root, mid, tip, t)
        t2 = min(1.0, t + 1e-3)
        sp2 = quad_bezier(root, mid, tip, t2)
        tx, ty = sp2[0] - sp[0], sp2[1] - sp[1]
        tl = math.hypot(tx, ty) or 1.0
        px, py = -ty / tl, tx / tl
        w = width * 0.5 * (math.sin(math.pi * min(1.0, t ** fullness)) if t > 0 else 0.0)
        w = max(w, width * 0.5 * root_round * (1 - t) ** 4)
        left.append((sp[0] + px * w, sp[1] + py * w))
        right.append((sp[0] - px * w, sp[1] - py * w))
    loop = left[:-1] + [tip] + list(reversed(right[:-1]))
    return loop


def spline_loop(points: Sequence[Point2], samples: int = 6, sharp: Sequence[int] = ()) -> Loop2:
    """Closed Catmull-Rom loop through ``points``; indices in ``sharp`` stay hard corners."""
    n = len(points)
    sharp_set = set(sharp)
    out: Loop2 = []
    for i in range(n):
        p1, p2 = points[i], points[(i + 1) % n]
        p0 = p1 if i in sharp_set else points[i - 1]
        p3 = p2 if (i + 1) % n in sharp_set else points[(i + 2) % n]
        for k in range(samples):
            t = k / samples
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * (2 * p1[d] + (-p0[d] + p2[d]) * t + (2 * p0[d] - 5 * p1[d] + 4 * p2[d] - p3[d]) * t2
                                    + (-p0[d] + 3 * p1[d] - 3 * p2[d] + p3[d]) * t3) for d in range(2)))
    return out


def strip(points: Sequence[Point2], width0: float, width1: float) -> Loop2:
    """Tapered ribbon along a polyline: width ``width0`` at the start, ``width1`` at the end."""
    n = len(points)
    left: Loop2 = []
    right: Loop2 = []
    for i, p in enumerate(points):
        a = points[max(0, i - 1)]
        b = points[min(n - 1, i + 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        tl = math.hypot(tx, ty) or 1.0
        px, py = -ty / tl, tx / tl
        w = 0.5 * (width0 + (width1 - width0) * i / (n - 1))
        left.append((p[0] + px * w, p[1] + py * w))
        right.append((p[0] - px * w, p[1] - py * w))
    return left + list(reversed(right))


# --- the face surface --------------------------------------------------------------------------
def _gauss(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


class FaceSurface:
    """Analytic outer skin of the mask: ``point(u, v, offset)`` and ``normal(u, v)``.

    Base form: per height v an elliptical cross-section, x = W(v) sin(u/R), y = P(v) - D(v)(1 - cos(u/R)),
    plus forward (+Y) displacements for brow, eye sockets, nose, cheekbones, chin and lips."""

    H = 1e-5

    def __init__(self, p: dict[str, Any]) -> None:
        self.p = p
        self.R = float(p["wrap_radius"])
        self.W0 = float(p["face_half_width"])
        half = float(p["eye_spacing"]) * 0.5
        self.eye_u = half
        self.eye_v = float(p["eye_v"])
        self.mouth_closed = p["mouth"] == "closed"

    # half width and depth falloff of the head cross-section at height v
    def width(self, v: float) -> float:
        if v >= 0:
            return self.W0 * (1 - 0.10 * (min(v, 0.14) / 0.11) ** 2)
        k = 0.36 - 0.06 * float(self.p["jaw"])
        return self.W0 * (1 - k * (min(-v, 0.14) / 0.12) ** 1.8)

    def profile(self, v: float) -> float:
        """Outer-skin depth on the centreline before features (y, m)."""
        y = 0.020
        if v > 0.02:
            y -= 3.2 * (v - 0.02) ** 2
        if v < 0:
            y += 0.010 * math.sin(math.pi * min(-v, 0.13) / 0.13)
        return y

    def features(self, u: float, v: float) -> float:
        p = self.p
        au = abs(u)
        f = 0.0
        # brow ridge across the forehead above the eyes
        f += 0.0055 * p["brow"] * _gauss(v - (self.eye_v + 0.026), 0.013) * _gauss(au, 0.075)
        # eye sockets (recess around the eyes)
        f -= 0.0060 * (0.6 + 0.4 * p["brow"]) * _gauss(au - self.eye_u, 0.020) * _gauss(v - self.eye_v, 0.015)
        # nose ridge from the bridge to the tip
        t = _smooth(self.eye_v + 0.012, self.eye_v - 0.040, v)
        tip_fall = _gauss(max(0.0, (self.eye_v - 0.046) - v), 0.008)
        f += 0.015 * p["nose"] * t * tip_fall * _gauss(au, 0.010 + 0.006 * t)
        # nose wings / bridge fill
        f += 0.004 * p["nose"] * _gauss(au, 0.016) * _gauss(v - (self.eye_v - 0.040), 0.012)
        # cheekbones
        f += 0.0065 * p["cheek"] * _gauss(au - 0.050, 0.022) * _gauss(v - (self.eye_v - 0.030), 0.018)
        # chin
        f += 0.0060 * p["jaw"] * _gauss(au, 0.024) * _gauss(v + 0.100, 0.016)
        if self.mouth_closed:
            mv = float(p["mouth_v"])
            mw = float(p["mouth_width"]) * 0.5
            f += 0.0035 * _gauss(au, mw) * (_gauss(v - mv - 0.006, 0.005) + _gauss(v - mv + 0.006, 0.005))
            f -= 0.0020 * _gauss(au, mw) * _gauss(v - mv, 0.0018)
        return f

    def base(self, u: float, v: float) -> Vector:
        w = self.width(v)
        d = self.R * w / self.W0
        a = u / self.R
        return Vector((w * math.sin(a), self.profile(v) - d * (1 - math.cos(a)) + self.features(u, v), v))

    def normal(self, u: float, v: float) -> Vector:
        h = self.H
        du = self.base(u + h, v) - self.base(u - h, v)
        dv = self.base(u, v + h) - self.base(u, v - h)
        n = dv.cross(du)
        n.normalize()
        return n

    def point(self, u: float, v: float, offset: float = 0.0) -> Vector:
        p = self.base(u, v)
        if offset != 0.0:
            p += self.normal(u, v) * offset
        return p

    def uv_of_x(self, x: float, v: float) -> float:
        """Inverse of the base mapping: u for a given Blender x at height v."""
        w = self.width(v)
        return self.R * math.asin(max(-1.0, min(1.0, x / w)))

    def depth_at(self, x: float, z: float, offset: float = 0.0) -> float:
        """Blender y of the skin (plus ``offset`` along y) under the point (x, z)."""
        return self.base(self.uv_of_x(x, z), z).y + offset


# --- outlines and holes ------------------------------------------------------------------------
class MaskShape:
    """2D outline and holes of the shell in (u, v)."""

    def __init__(self, p: dict[str, Any], surf: FaceSurface) -> None:
        self.p = p
        self.surf = surf

    def outline(self) -> Loop2:
        p = self.p
        cov = p["coverage"]
        a = float(p["side_arc"])
        if cov == "full":
            top, bot, pt, pb = float(p["top"]), -float(p["bottom"]), 2.4, 1.9
        elif cov == "half":
            top, bot, pt, pb = float(p["top"]), -float(p["half_bottom"]), 2.4, 3.5
        elif cov == "visor":
            top, bot, pt, pb = float(p["visor_top"]), -float(p["visor_bottom"]), 5.0, 5.0
        else:
            raise ValueError(f"unknown coverage {cov!r}")
        loop = superellipse(0.0, 0.0, a, top, bot, pt, n=160, p_bottom=pb)
        out: Loop2 = []
        peak, chin, taper = float(p["top_peak"]), float(p["chin_point"]), float(p["jaw_taper"])
        for u, v in loop:
            if v < 0 and cov != "visor":
                u *= 1 - taper * (-v / bot) ** 2
                v -= chin * max(0.0, 1 - abs(u) / 0.035) ** 1.5
            elif v > 0 and cov != "visor":
                v += peak * max(0.0, 1 - abs(u) / 0.040) ** 1.4
            out.append((u, v))
        if cov == "half":  # nose notch: the lower edge rises over the nose
            out = [(u, v + 0.010 * _gauss(u, 0.016)) if v < 0 else (u, v) for u, v in out]
        return out

    def eye_hole(self, side: int) -> Loop2:
        p = self.p
        hw, hh = float(p["eye_width"]) * 0.5, float(p["eye_height"]) * 0.5
        shape = p["eye_shape"]
        tilt = float(p["eye_tilt_deg"])
        cu = self.surf.eye_u
        cv = self.surf.eye_v
        if shape == "almond":
            loop = almond(cu, cv, hw, hh, point=1.7, tilt_deg=tilt, lower=0.85)
        elif shape == "round":
            loop = almond(cu, cv, hw, hh, point=1.0, tilt_deg=tilt)
        elif shape == "slit":
            loop = almond(cu, cv, hw, hh * 0.45, point=2.0, tilt_deg=tilt)
        elif shape == "deco":
            ct, st = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
            pts = [(-hw, 0.0), (-hw * 0.45, hh), (hw * 0.55, hh), (hw, 0.15 * hh),
                   (hw * 0.45, -hh * 0.85), (-hw * 0.5, -hh * 0.85)]
            loop = [(cu + x * ct - y * st, cv + x * st + y * ct) for x, y in pts]
        else:
            raise ValueError(f"unknown eye_shape {shape!r}")
        return loop if side > 0 else mirror(loop)

    def mouth_hole(self) -> Loop2 | None:
        p = self.p
        kind = p["mouth"]
        if kind in ("none", "closed") or p["coverage"] != "full":
            return None
        hw, hh = float(p["mouth_width"]) * 0.5, float(p["mouth_height"]) * 0.5
        mv = float(p["mouth_v"])
        if kind == "open":
            return almond(0.0, mv, hw, hh, point=1.25, lower=1.2)
        if kind == "slit":
            return almond(0.0, mv, hw, max(0.0022, hh * 0.25), point=2.0)
        raise ValueError(f"unknown mouth {kind!r}")

    def holes(self) -> list[Loop2]:
        out = []
        if self.p["coverage"] != "visor" or float(self.p["visor_bottom"]) < self.surf.eye_v:
            out = [self.eye_hole(1), self.eye_hole(-1)]
        m = self.mouth_hole()
        if m is not None:
            out.append(m)
        return out


# --- triangulation and slabs -------------------------------------------------------------------
def triangulate(outer: Loop2, holes: Sequence[Loop2], res: float) -> tuple[list[Point2], list[tuple[int, int, int]], list[list[int]]]:
    """Constrained Delaunay triangulation of a region with interior points on a hex grid.

    Returns (points, triangles, loop_ids) where loop_ids[k] lists the point index of every vertex
    of loop k (outer first, then holes) in loop order."""
    loops = [outer] + list(holes)
    pts: list[Point2] = []
    edges: list[tuple[int, int]] = []
    loop_ids: list[list[int]] = []
    for loop in loops:
        start = len(pts)
        ids = list(range(start, start + len(loop)))
        pts.extend(loop)
        edges.extend((ids[i], ids[(i + 1) % len(ids)]) for i in range(len(ids)))
        loop_ids.append(ids)
    segs = [(loop[i], loop[(i + 1) % len(loop)]) for loop in loops for i in range(len(loop))]
    us = [p[0] for p in outer]
    vs = [p[1] for p in outer]
    dy = res * math.sqrt(3) / 2
    r0 = math.floor(min(vs) / dy)
    r1 = math.ceil(max(vs) / dy)
    min_d = 0.55 * res
    for r in range(r0, r1 + 1):
        v = r * dy
        shift = 0.5 * res if r % 2 else 0.0
        c0 = math.floor((min(us) - shift) / res)
        c1 = math.ceil((max(us) - shift) / res)
        for c in range(c0, c1 + 1):
            q = (c * res + shift, v)
            if not point_in_loop(q, outer) or any(point_in_loop(q, h) for h in holes):
                continue
            if min(_seg_dist(q, a, b) for a, b in segs) < min_d:
                continue
            pts.append(q)
    out_v, _e, out_f, orig_v, _oe, _of = geometry.delaunay_2d_cdt(
        [Vector(p) for p in pts], edges, [], 0, 1e-9)
    remap = [0] * len(pts)
    for oi, origs in enumerate(orig_v):
        for i in origs:
            remap[i] = oi
    new_pts = [(float(v.x), float(v.y)) for v in out_v]
    tris = []
    for f in out_f:
        if len(f) != 3:
            continue
        c = (sum(new_pts[i][0] for i in f) / 3, sum(new_pts[i][1] for i in f) / 3)
        if not point_in_loop(c, outer) or any(point_in_loop(c, h) for h in holes):
            continue
        tris.append((f[0], f[1], f[2]))
    return new_pts, tris, [[remap[i] for i in ids] for ids in loop_ids]


@dataclass
class MaskKit:
    """Everything an ornament function needs. Geometry goes into ``mb`` (one ``Mask`` object)."""

    ctx: Any
    params: dict[str, Any]
    surf: FaceSurface
    shape: MaskShape
    mb: geo.MeshBuilder
    slots: dict[str, int] = field(default_factory=dict)

    def mat(self, role: str) -> int:
        """Builder slot of a material role: ``primary``, ``accent`` or ``inner``."""
        return self.slots[role]

    def plate(self, outline: Sequence[Point2], hi: float = 0.002, lo: float = -0.0015,
              chamfer: float = 0.0006, mat: str = "primary", side_mat: str | None = None,
              holes: Sequence[Sequence[Point2]] = (), res: float = 0.010,
              edge_res: float = 0.006) -> None:
        """Raised plate conforming to the skin: top at ``hi`` above it, walls sinking to ``lo``
        (inside the shell, so no bottom face is built). Chamfered top rim."""
        slab(self.mb, self.surf, outline, holes, lo, hi, chamfer,
             self.mat(mat), self.mat(side_mat or mat), None, res, res, edge_res, bottom=False)

    def loft(self, sections: Sequence[Sequence[Vector]], mat: str = "primary",
             tip: Vector | None = None, cap_start: bool = True) -> list[bmesh.types.BMFace]:
        """Loft closed 3D sections (equal vertex counts) into a solid; optional pointed ``tip``.
        Returns the faces (see :func:`loft`) so callers can re-assign materials per facet."""
        return loft(self.mb, sections, self.mat(mat), tip=tip, cap_start=cap_start)


def _orient(f: bmesh.types.BMFace, expected: Vector) -> None:
    f.normal_update()
    if f.normal.dot(expected) < 0:
        f.normal_flip()


def _outward3(surf: FaceSurface, a: Point2, b: Point2, off: float) -> Vector:
    """3D outward direction of a loop edge a->b whose material lies to its left."""
    du, dv = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(du, dv) or 1.0
    ou, ov = dv / ln, -du / ln
    m = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
    e = 1e-4
    return surf.point(m[0] + ou * e, m[1] + ov * e, off) - surf.point(m[0], m[1], off)


def slab(mb: geo.MeshBuilder, surf: FaceSurface, outer: Sequence[Point2], holes: Sequence[Sequence[Point2]],
         lo: float, hi: float, chamfer: float, mat_top: int, mat_side: int, mat_bottom: int | None,
         res: float, res_back: float, edge_res: float, bottom: bool = True) -> None:
    """Thick surface patch between skin offsets ``lo`` and ``hi`` with chamfered rims.

    Rings, from the top: top face (inset by ``chamfer``) -> 45 deg chamfer -> wall -> (if
    ``bottom``) back chamfer -> bottom face. Faces are oriented outward explicitly."""
    bm = mb.bm
    o = resample(oriented(outer, True), edge_res)
    hs = [resample(oriented(h, False), edge_res) for h in holes]
    loops = [o] + hs
    insets = [offset_loop(lp, chamfer) for lp in loops]

    def face_patch(off: float, r: float, mat: int, flip: bool) -> list[list[bmesh.types.BMVert]]:
        pts, tris, ids = triangulate(insets[0], insets[1:], r)
        verts = [bm.verts.new(surf.point(u, v, off)) for u, v in pts]
        for t in tris:
            f = bm.faces.new([verts[i] for i in t])
            f.material_index = mat
            c = ((pts[t[0]][0] + pts[t[1]][0] + pts[t[2]][0]) / 3, (pts[t[0]][1] + pts[t[1]][1] + pts[t[2]][1]) / 3)
            n = surf.normal(*c)
            _orient(f, -n if flip else n)
        return [[verts[i] for i in lid] for lid in ids]

    def ring(loop2: Loop2, off: float) -> list[bmesh.types.BMVert]:
        return [bm.verts.new(surf.point(u, v, off)) for u, v in loop2]

    def bridge(ra: list, rb: list, loop2: Loop2, off: float, up: float, mat: int) -> None:
        n = len(ra)
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
            f.material_index = mat
            c = ((loop2[i][0] + loop2[j][0]) * 0.5, (loop2[i][1] + loop2[j][1]) * 0.5)
            exp = _outward3(surf, loop2[i], loop2[j], off).normalized() + surf.normal(*c) * up
            _orient(f, exp)

    top_rings = face_patch(hi, res, mat_top, False)
    bot_mat = mat_bottom if mat_bottom is not None else mat_side
    bot_rings = face_patch(lo, res_back, bot_mat, True) if bottom else None
    for k, loop2 in enumerate(loops):
        cur = top_rings[k]
        if chamfer > 0:
            nxt = ring(loop2, hi - chamfer)
            bridge(cur, nxt, loop2, hi, 1.0, mat_top)
            cur = nxt
        if bot_rings is not None:
            if chamfer > 0:
                nxt = ring(loop2, lo + chamfer)
                bridge(cur, nxt, loop2, hi, 0.0, mat_side)
                bridge(nxt, bot_rings[k], loop2, lo, -1.0, mat_side)
            else:
                bridge(cur, bot_rings[k], loop2, hi, 0.0, mat_side)
        else:
            nxt = ring(loop2, lo)
            bridge(cur, nxt, loop2, hi, 0.0, mat_side)


def loft(mb: geo.MeshBuilder, sections: Sequence[Sequence[Vector]], mat: int, tip: Vector | None = None,
         cap_start: bool = True, cap_end: bool = True) -> list[bmesh.types.BMFace]:
    """Solid through closed 3D ``sections`` (same vertex count n, consistent order).

    Ends with a single ``tip`` vertex (pointed) or a flat end cap. Outward orientation is taken
    from each face's offset to its section centroid. Returns the faces in creation order:
    ``faces[s * n + i]`` joins edge i (vertex i -> i+1) of section s to section s+1; then the n
    tip triangles (edge i of the last section), then the caps."""
    bm = mb.bm
    made: list[bmesh.types.BMFace] = []
    rings = [[bm.verts.new(Vector(p)) for p in sec] for sec in sections]
    cents = [sum((Vector(p) for p in sec), Vector()) / len(sec) for sec in sections]
    n = len(rings[0])
    for s in range(len(rings) - 1):
        a, b = rings[s], rings[s + 1]
        axis_c = (cents[s] + cents[s + 1]) * 0.5
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.material_index = mat
            made.append(f)
            fc = (a[i].co + a[j].co + b[j].co + b[i].co) * 0.25
            _orient(f, fc - axis_c)
    axis = cents[-1] - cents[0]
    if tip is not None:
        tv = bm.verts.new(Vector(tip))
        last = rings[-1]
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((last[i], last[j], tv))
            f.material_index = mat
            made.append(f)
            fc = (last[i].co + last[j].co + tv.co) / 3
            _orient(f, fc - cents[-1])
    elif cap_end:
        f = bm.faces.new(rings[-1])
        f.material_index = mat
        made.append(f)
        _orient(f, axis)
    if cap_start:
        f = bm.faces.new(rings[0])
        f.material_index = mat
        made.append(f)
        _orient(f, -axis)
    return made


# --- materials and the whole mask ---------------------------------------------------------------
MatSpec = tuple[str, str, float, float]  # (library id, sRGB hex placeholder, roughness, metallic)

PRIMARY_GOLD: MatSpec = ("char_mask_gold", "#D1A847", 0.30, 1.0)       # MaskDef colour_a (0.82, 0.66, 0.28)
ACCENT_LACQUER: MatSpec = ("char_mask_lacquer_dark", "#1F2026", 0.40, 0.0)  # colour_b, lifted to the albedo floor
INNER_MATTE: MatSpec = ("char_mask_inner", "#2A2724", 0.85, 0.0)


def materials(ctx, primary: MatSpec = PRIMARY_GOLD, accent: MatSpec = ACCENT_LACQUER,
              inner: MatSpec = INNER_MATTE) -> dict[str, bpy.types.Material]:
    """Material roles -> ``M_<id>`` materials (placeholder colours until the library .tres exist)."""
    out = {}
    for role, (lib_id, color, rough, metal) in (("primary", primary), ("accent", accent), ("inner", inner)):
        out[role] = ctx.material(lib_id, color, roughness=rough, metallic=metal)
    return out


Ornament = Callable[[MaskKit], None]


def build_mask(ctx, params: dict[str, Any] | None, mats: dict[str, bpy.types.Material],
               ornaments: Sequence[Ornament] = (), name: str = "Mask") -> bpy.types.Object:
    """Build the shell plus ornaments as one mesh object ``name`` at the face-centre pivot.

    Shell: outer skin + rim chamfers + wall in ``primary``, inner skin in ``inner``. Ornament
    functions receive a :class:`MaskKit`. Afterwards: box-projected UVs (1024 px/m, after all
    chamfers), sharp edges by angle and weighted normals (``geo.finish_hard_surface``).
    Records the pivot definition and triangle count in SOURCE.txt (``ctx.source_extra``)."""
    p = params_with_defaults(params)
    surf = FaceSurface(p)
    shape = MaskShape(p, surf)
    mb = geo.MeshBuilder()
    slots = {role: mb.material(m) for role, m in mats.items()}
    kit = MaskKit(ctx=ctx, params=p, surf=surf, shape=shape, mb=mb, slots=slots)
    t = float(p["thickness"])
    slab(mb, surf, shape.outline(), shape.holes(), -t, 0.0, float(p["chamfer"]),
         slots["primary"], slots["primary"], slots["inner"], float(p["res"]), float(p["res_back"]),
         float(p["edge_res"]), bottom=True)
    print(f"[mask] shell: {mb.tri_count()} tris")
    for fn in ornaments:
        before = mb.tri_count()
        fn(kit)
        print(f"[mask] {fn.__name__}: {mb.tri_count() - before} tris")
    tris = mb.tri_count()
    uv.box_project(mb.bm, density=uv.DENSITY_FIRST_PERSON)
    obj = mb.to_object(name)
    geo.finish_hard_surface(obj, angle_deg=30.0)
    ctx.source_extra["pivot"] = ("face centre: midway between the eye centres at eye (cornea) depth; "
                                 "Blender +Y = Godot -Z = forward, +Z = up")
    ctx.source_extra["tris_lod0"] = tris
    ctx.source_extra["coverage"] = p["coverage"]
    return obj
