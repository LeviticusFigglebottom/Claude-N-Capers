"""Pylon customisable base mask (``mask_base.road_cone``, achievement reward, Rolling Thunder).

An original traffic cone worn as a face: the outline is the cone's silhouette (a rounded tip over the
brow widening steadily down the face) standing on a square base flange across the chin. The skin is a
true cone section (each height a circle of the cone's radius, the front line kept upright so it sits
on the face), with a raised lip round the open tip, two moulded reflective collar bands (the stripes,
in RELIEF so the single base surface still reads them: the upper band over the brow, the lower one
across the mouth), fine horizontal moulding ribs between them, and the base flange with a raised
square rim and corner lugs. Two wide oval eye holes sit in the plain orange zone between the bands.
No real maker's mark.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_road_cone"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "brow": 0.0,
    "cheek": 0.0,
    "nose": 0.0,
    "jaw": 0.0,
    "eye_shape": "round",
    "eye_width": 0.030,
    "eye_height": 0.020,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "face_half_width": 0.090,
    "wrap_radius": 0.090,
    "thickness": 0.005,
    "chamfer": 0.0016,
    "res": 0.0095,
    "fit_clearance": 0.0040,
    "res_back": 0.016,
    "edge_res": 0.0060,
}

TIP_V, BASE_V = 0.108, -0.098      # the cone from its tip (over the brow) to the top of the base flange (v)
TIP_R, BASE_R = 0.026, 0.084       # cone radius at the tip and at the base
FLANGE_V = -0.126                  # bottom of the base flange
FLANGE_X = 0.096                   # flange half width (front view)
FLANGE_R = 0.110                   # skin radius under the flange (a flatter curve: the flange is a plate)
Y0 = 0.060                         # front line depth (clears the nose: no crew-fit bulge) (m in front of the eye plane)
EDGE = 0.94                        # outline half width as a share of the cone radius (the visible silhouette)
BANDS = ((0.036, 0.062), (-0.066, -0.040))   # reflective collars (v from, v to)
RIBS = (0.024, -0.025)             # moulding ribs between the bands


def radius(v: float) -> float:
    """Cone radius at height v (the flange below the cone is wider)."""
    if v <= BASE_V:
        return FLANGE_R
    t = (TIP_V - v) / (TIP_V - BASE_V)
    return TIP_R + (BASE_R - TIP_R) * max(0.0, min(1.0, t))


class ConeSurface(mask.FaceSurface):
    """Each height a circle of radius(v) whose front stays on the upright line y = Y0; u is arc length."""

    def width(self, v: float) -> float:
        return radius(v)

    def profile(self, v: float) -> float:
        return Y0

    def features(self, u: float, v: float) -> float:
        return self.extra(u, v) if self.extra is not None else 0.0

    def raw(self, u: float, v: float) -> Vector:
        r = radius(v)
        a = u / r
        lim = 0.49 * math.pi
        over = 0.0
        if abs(a) > lim:  # past the silhouette: carry on straight back (only the fit grid samples here)
            over = (abs(a) - lim) * r
            a = math.copysign(lim, a)
        x = r * math.sin(a)
        y = Y0 - r * (1.0 - math.cos(a)) - over
        return Vector((x, y + self.features(u, v), v))

    def uv_of_x(self, x: float, v: float) -> float:
        r = radius(v)
        return r * math.asin(max(-1.0, min(1.0, x / r)))


def _cone(surf: mask.FaceSurface) -> mask.FaceSurface:
    return ConeSurface(surf.p, surf.extra)


def to_uv(x: float, v: float) -> mask.Point2:
    """Front-view (x, v) -> design (u, v) on the cone."""
    r = radius(v)
    return (r * math.asin(max(-0.999, min(0.999, x / r))), v)


def half_x(v: float) -> float:
    """Outline half width (front view) at height v."""
    return EDGE * radius(v) if v > BASE_V else FLANGE_X


def _silhouette(inset: float = 0.0) -> mask.Loop2:
    """Front-view outline: the cone sides and a rounded tip, then the square flange, inset by ``inset``."""
    pts: list[mask.Point2] = []
    v_top = TIP_V - inset
    n_side = 18
    for k in range(n_side + 1):  # left side (Blender +X), tip to base
        v = v_top - 0.006 - (v_top - 0.006 - (BASE_V + 0.0005)) * k / n_side
        pts.append((half_x(v) - inset, v))
    # flange: out to its corner, down, across, up the other side
    fv0, fv1 = BASE_V, FLANGE_V + inset
    fx = FLANGE_X - inset
    pts += [(fx, fv0 - 0.0005), (fx, fv1 + 0.004), (fx - 0.004, fv1)]
    pts += [(fx - 0.004 - (2 * fx - 0.008) * k / 10, fv1) for k in range(1, 10)]
    pts += [(-fx + 0.004, fv1), (-fx, fv1 + 0.004), (-fx, fv0 - 0.0005)]
    for k in range(n_side + 1):  # right side, base to tip
        v = BASE_V + 0.0005 + (v_top - 0.006 - (BASE_V + 0.0005)) * k / n_side
        pts.append((-(half_x(v) - inset), v))
    tip = half_x(v_top - 0.006) - inset
    for k in range(1, 8):  # the rounded tip, right to left
        a = math.pi * k / 8
        pts.append((-tip * math.cos(a), v_top - 0.006 + 0.006 * math.sin(a)))
    return [to_uv(x, v) for x, v in pts]


def _outline_fn(shape: mask.MaskShape) -> mask.Loop2:
    return mask.oriented(_silhouette(), True)


def _sculpt(u: float, v: float) -> float:
    # a shallow groove where the cone meets the flange
    return -0.0012 * math.exp(-((v - BASE_V) / 0.0022) ** 2)


def _band_loop(v0: float, v1: float, inset: float = 0.0006) -> mask.Loop2:
    """A collar band round the visible cone between heights v0 < v1 (front view, then onto the cone)."""
    n = 12
    pts = [(half_x(v0) - inset, v0)] + [(half_x(v0) - inset - 2 * (half_x(v0) - inset) * k / n, v0)
                                        for k in range(1, n)]
    pts += [(-(half_x(v0) - inset), v0), (-(half_x(v1) - inset), v1)]
    pts += [(-(half_x(v1) - inset) + 2 * (half_x(v1) - inset) * k / n, v1) for k in range(1, n)]
    pts += [(half_x(v1) - inset, v1)]
    return [to_uv(x, v) for x, v in pts]


def _collars(kit: mask.MaskKit) -> None:
    """The two reflective collars (raised, square-edged) and the moulding ribs between them."""
    for v0, v1 in BANDS:
        kit.plate(mask.oriented(_band_loop(v0, v1), True), hi=0.0050, lo=-0.0035, chamfer=0.0006,
                  edge_res=0.006, res=0.03)
    for v in RIBS:
        rib = _band_loop(v - 0.0011, v + 0.0011, inset=0.004)
        kit.plate(mask.oriented(rib, True), hi=0.0012, lo=-0.0025, chamfer=0.0004, edge_res=0.006, res=0.05)


def _tip_lip(kit: mask.MaskKit) -> None:
    """The raised lip round the cone's open tip."""
    outer = mask.oriented(_band_loop(TIP_V - 0.016, TIP_V - 0.006, inset=-0.0004), True)
    kit.plate(outer, hi=0.0034, lo=-0.0035, chamfer=0.0010, edge_res=0.005, res=0.03)


def _flange(kit: mask.MaskKit) -> None:
    """The square base: a raised rim round the flange and a lug at each lower corner."""
    fx = FLANGE_X
    outer = [(fx + 0.0008, BASE_V - 0.0002), (fx + 0.0008, FLANGE_V - 0.0008),
             (-fx - 0.0008, FLANGE_V - 0.0008), (-fx - 0.0008, BASE_V - 0.0002)]
    inner = [(fx - 0.0055, BASE_V - 0.0050), (-fx + 0.0055, BASE_V - 0.0050), (-fx + 0.0055, FLANGE_V + 0.0055),
             (fx - 0.0055, FLANGE_V + 0.0055)]
    outer = mask.resample([to_uv(x, v) for x, v in outer], 0.008)
    inner = mask.resample([to_uv(x, v) for x, v in inner], 0.008)
    kit.plate(mask.oriented(outer, True), holes=[mask.oriented(inner, False)], hi=0.0042, lo=-0.0040,
              chamfer=0.0010, edge_res=0.008, res=0.03)
    for s in (1, -1):
        cx = s * (fx - 0.012)
        lug = mask.disc(*to_uv(cx, FLANGE_V + 0.0115), 0.0042, 16)
        kit.plate(mask.oriented(lug, True), hi=0.0060, lo=0.0020, chamfer=0.0010, edge_res=0.004, res=0.03)


def _eye_rims(kit: mask.MaskKit) -> None:
    """A thin moulded rim round each eye."""
    for side in (1, -1):
        eye = mask.oriented(kit.shape.eye_hole(side), True)
        kit.plate(mask.offset_loop(eye, -0.0035), hi=0.0016, chamfer=0.0006, edge_res=0.003,
                  holes=[mask.oriented(mask.offset_loop(eye, -0.0006), False)])


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_collars, _tip_lip, _flange, _eye_rims],
                    surface_extra=_sculpt, outline_fn=_outline_fn, uv_mode="front", surface_wrap=_cone)
