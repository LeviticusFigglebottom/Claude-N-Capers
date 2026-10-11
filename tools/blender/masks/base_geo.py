"""Geo customisable base mask (``mask_base.geo``, D3-03).

An original low-poly face: the whole mask is cut from flat triangular facets, like a faceted gem
or an early real-time model. A hand-placed coarse triangulation of half a face (dense round the
eyes, nose and mouth, broad over the forehead and cheeks) is mirrored, each facet is a raised flat
plate separated from its neighbours by a fine groove, the outline is a polygon and the eyes are
hexagons. The facet corners are sampled from the crew-fitted face skin, so the facets follow the
fit (with extra clearance for the flat chords); the shell under the plates uses the same facets
(``build_mask(surface_wrap=...)``). A crisp, angular silhouette next to the organic bases, and a
canvas where patterns break across facets.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector, geometry

import _mask_base as mask

ASSET_ID = "mask_base_geo"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "side_arc": 0.102,
    "brow": 1.5,
    "cheek": 1.4,
    "nose": 1.5,
    "jaw": 1.0,
    "eye_shape": "deco",
    "eye_width": 0.038,
    "eye_height": 0.022,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 4.0,
    "mouth": "none",
    "res": 0.0085,
    "res_back": 0.016,
    "edge_res": 0.0060,
    # flat facets are chords of the fitted skin: keep them clear of the crew faces too
    "fit_clearance": 0.0065,
}

# right half (u >= 0): the polygon outline from the top of the centre line round to the chin
OUTLINE_R = [(0.0, 0.110), (0.036, 0.104), (0.068, 0.086), (0.090, 0.056), (0.102, 0.018), (0.100, -0.022),
             (0.088, -0.058), (0.066, -0.090), (0.036, -0.112), (0.0, -0.122)]
# interior corners on the centre line (top to bottom) and on the right half
CENTRE_PTS = [(0.0, 0.070), (0.0, 0.032), (0.0, 0.008), (0.0, -0.020), (0.0, -0.044), (0.0, -0.060),
              (0.0, -0.080), (0.0, -0.100)]
INNER_PTS = [(0.034, 0.074), (0.062, 0.054), (0.024, 0.040), (0.050, 0.032), (0.078, 0.020), (0.074, -0.010),
             (0.056, -0.030), (0.030, -0.026), (0.013, -0.044), (0.034, -0.054), (0.062, -0.062), (0.020, -0.072),
             (0.042, -0.086), (0.018, -0.102)]
GROOVE = 0.0008  # half width of the groove between facet plates


def _outline() -> mask.Loop2:
    right = OUTLINE_R
    left = [(-u, v) for u, v in reversed(right[1:-1])]
    return mask.oriented(list(reversed(right)) + list(reversed(left)), True)


def _facets(eye: mask.Loop2) -> tuple[list[mask.Point2], list[tuple[int, int, int]]]:
    """Right-half triangulation (constrained by the half outline and the eye), then mirrored."""
    half = [(u, v) for u, v in OUTLINE_R] + list(reversed(CENTRE_PTS))
    pts = list(half) + list(eye) + list(INNER_PTS)
    edges = [(i, (i + 1) % len(half)) for i in range(len(half))]
    e0 = len(half)
    edges += [(e0 + i, e0 + (i + 1) % len(eye)) for i in range(len(eye))]
    out_v, _e, out_f, _ov, _oe, _of = geometry.delaunay_2d_cdt([Vector(p) for p in pts], edges, [], 0, 1e-9)
    verts = [(float(v.x), float(v.y)) for v in out_v]
    tris = []
    for f in out_f:
        if len(f) != 3:
            continue
        c = (sum(verts[i][0] for i in f) / 3, sum(verts[i][1] for i in f) / 3)
        if not mask.point_in_loop(c, half) or mask.point_in_loop(c, eye):
            continue
        tris.append(_ccw(verts, f))
    # mirror: centre-line vertices are shared
    all_v = list(verts)
    mirror_of = {}
    for i, (u, v) in enumerate(verts):
        if abs(u) < 1e-9:
            mirror_of[i] = i
        else:
            mirror_of[i] = len(all_v)
            all_v.append((-u, v))
    all_t = list(tris) + [(mirror_of[a], mirror_of[c], mirror_of[b]) for a, b, c in tris]
    return all_v, all_t


def _ccw(verts: list[mask.Point2], f) -> tuple[int, int, int]:
    a, b, c = f
    (x0, y0), (x1, y1), (x2, y2) = verts[a], verts[b], verts[c]
    return (a, b, c) if (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0) > 0 else (a, c, b)


class FacetSurface:
    """Planar facets through the fitted skin: each design point is the barycentric blend of its
    facet's three corners on the real skin (at the same offset), so every facet is flat and
    neighbouring facets meet exactly along shared edges."""

    H = 1e-5
    CELL = 0.01

    def __init__(self, surf: mask.FaceSurface) -> None:
        self.surf = surf
        self.p = surf.p
        self.eye_u, self.eye_v = surf.eye_u, surf.eye_v
        self.fit = surf.fit
        eye = mask.oriented(mask.MaskShape(surf.p, surf).eye_hole(1), True)
        self.verts, self.tris = _facets(eye)
        self.grid: dict[tuple[int, int], list[int]] = {}
        for ti, (a, b, c) in enumerate(self.tris):
            us = [self.verts[i][0] for i in (a, b, c)]
            vs = [self.verts[i][1] for i in (a, b, c)]
            for gx in range(math.floor(min(us) / self.CELL) - 1, math.floor(max(us) / self.CELL) + 2):
                for gy in range(math.floor(min(vs) / self.CELL) - 1, math.floor(max(vs) / self.CELL) + 2):
                    self.grid.setdefault((gx, gy), []).append(ti)
        self._corner: dict[tuple[int, float], Vector] = {}

    def _bary(self, ti: int, u: float, v: float) -> tuple[float, float, float]:
        a, b, c = self.tris[ti]
        (x0, y0), (x1, y1), (x2, y2) = self.verts[a], self.verts[b], self.verts[c]
        det = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        l0 = ((y1 - y2) * (u - x2) + (x2 - x1) * (v - y2)) / det
        l1 = ((y2 - y0) * (u - x2) + (x0 - x2) * (v - y2)) / det
        return l0, l1, 1.0 - l0 - l1

    def facet(self, u: float, v: float) -> tuple[int, tuple[float, float, float]]:
        cands = self.grid.get((math.floor(u / self.CELL), math.floor(v / self.CELL))) or range(len(self.tris))
        best, best_b, best_m = -1, (0.0, 0.0, 0.0), -1e9
        for ti in cands:
            bc = self._bary(ti, u, v)
            m = min(bc)
            if m > best_m:
                best, best_b, best_m = ti, bc, m
        return best, best_b

    def corner(self, i: int, offset: float) -> Vector:
        key = (i, offset)
        if key not in self._corner:
            u, v = self.verts[i]
            self._corner[key] = self.surf.point(u, v, offset)
        return self._corner[key]

    def point(self, u: float, v: float, offset: float = 0.0) -> Vector:
        ti, (l0, l1, l2) = self.facet(u, v)
        a, b, c = self.tris[ti]
        return self.corner(a, offset) * l0 + self.corner(b, offset) * l1 + self.corner(c, offset) * l2

    def normal(self, u: float, v: float) -> Vector:
        ti, _bc = self.facet(u, v)
        a, b, c = self.tris[ti]
        pa, pb, pc = self.corner(a, 0.0), self.corner(b, 0.0), self.corner(c, 0.0)
        n = (pb - pa).cross(pc - pa)
        n.normalize()
        if n.dot(self.surf.normal(u, v)) < 0:
            n.negate()
        return n


def _wrap(surf: mask.FaceSurface) -> FacetSurface:
    return FacetSurface(surf)


def _outline_fn(shape: mask.MaskShape) -> mask.Loop2:
    return _outline()


def _plates(kit: mask.MaskKit) -> None:
    """Every facet as a raised flat plate, inset by the groove."""
    fs: FacetSurface = kit.surf
    for a, b, c in fs.tris:
        tri = [fs.verts[a], fs.verts[b], fs.verts[c]]
        inset = mask.offset_loop(mask.oriented(tri, True), GROOVE, max_miter=4.0)
        kit.plate(inset, hi=0.0020, lo=-0.0012, chamfer=0.0007, res=0.08, edge_res=0.08)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_plates], outline_fn=_outline_fn,
                    surface_wrap=_wrap, uv_mode="front")
