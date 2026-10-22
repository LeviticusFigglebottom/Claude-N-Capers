"""Ingot customisable base mask (``mask_base.ingot``, achievement reward, Rolling Thunder).

An original cast bar worn as a face: the outline is a bullion bar's tapered trapezoid (narrower at the
brow, wider at the chin, rounded corners), the skin a flat, faintly curved slab whose broad top face rises out of steep
cast draft bevels all round the edge, so the mask reads as a stamped bar rather than a face. Across
the brow a recessed rectangular cartouche is struck into the metal with raised marks in it: an
original six-point star mark between two rules and the fineness numerals "1000"; below the eyes a
second, smaller strike carries a serial number ("0715") and a thin mould seam crosses the chin. The
eyes are long horizontal slots. No real refiner's or assayer's mark.

The slab is a constant-width cylinder (``BarSurface``, no face features), so the trapezoid drawn in
front-view coordinates (x, v) keeps straight sides; the crew fit lifts it clear of every crew face.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask
from base_vault_dial import _digit_loops

ASSET_ID = "mask_base_ingot"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "brow": 0.0,
    "cheek": 0.0,
    "nose": 0.0,
    "jaw": 0.0,
    "eye_shape": "slit",
    "eye_width": 0.036,
    "eye_height": 0.020,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "face_half_width": 0.115,
    "wrap_radius": 0.115,
    "thickness": 0.005,
    "chamfer": 0.0016,
    "res": 0.0100,
    "fit_clearance": 0.0040,
    "res_back": 0.016,
    "edge_res": 0.0060,
}

TOP_V, BOT_V = 0.102, -0.124       # bar ends (v)
TOP_X, BOT_X = 0.074, 0.094       # bar half widths (front view) at the brow end and the chin end
CORNER = 0.016                     # corner radius
Y0 = 0.058                         # slab face depth on the centre line (m in front of the eye plane)
DRAFT = 0.015                      # width of the cast draft bevel round the edge
RISE = 0.0095                      # how far the top face stands above the bevel's foot
CART = (0.0, 0.066, 0.064, 0.024)  # brow cartouche: centre (x, v), half width, half height
SERIAL = (0.0, -0.046, 0.030, 0.011)
STRIKE = 0.0036                    # strike depth of the cartouches


class BarSurface(mask.FaceSurface):
    """Constant width (straight sides in front view), a flat slab face, no face features."""

    def width(self, v: float) -> float:
        return self.W0

    def profile(self, v: float) -> float:
        return Y0 - 0.25 * max(0.0, v - 0.05) ** 2

    def features(self, u: float, v: float) -> float:
        return self.extra(u, v) if self.extra is not None else 0.0


def _bar(surf: mask.FaceSurface) -> mask.FaceSurface:
    return BarSurface(surf.p, surf.extra)


R = PARAMS["wrap_radius"]


def to_uv(x: float, v: float) -> mask.Point2:
    return (R * math.asin(max(-0.999, min(0.999, x / R))), v)


def half_x(v: float) -> float:
    """Trapezoid half width (front view) at height v."""
    return BOT_X + (TOP_X - BOT_X) * (v - BOT_V) / (TOP_V - BOT_V)


def _trapezoid(inset: float) -> mask.Loop2:
    """The bar outline with rounded corners, inset by ``inset`` (front view, then onto the slab)."""
    pts: list[mask.Point2] = []
    rad = max(0.003, CORNER - inset)
    top, bot = TOP_V - inset, BOT_V + inset
    corners = [(half_x(bot) - inset - rad, bot + rad, 270.0), (half_x(top) - inset - rad, top - rad, 0.0),
               (-(half_x(top) - inset - rad), top - rad, 90.0), (-(half_x(bot) - inset - rad), bot + rad, 180.0)]
    for cx, cv, a0 in corners:
        for k in range(7):
            a = math.radians(a0 + 90.0 * k / 6)
            pts.append((cx + rad * math.cos(a), cv + rad * math.sin(a)))
    loop = mask.resample(pts, 0.010)
    return [to_uv(x, v) for x, v in loop]


def _outline_fn(shape: mask.MaskShape) -> mask.Loop2:
    return mask.oriented(_trapezoid(0.0), True)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _box_dist(x: float, v: float, cx: float, cv: float, hx: float, hv: float) -> float:
    """Signed distance to a rectangle (front view, < 0 inside)."""
    dx, dv = abs(x - cx) - hx, abs(v - cv) - hv
    return math.hypot(max(dx, 0.0), max(dv, 0.0)) + min(max(dx, dv), 0.0)


def _sculpt(u: float, v: float) -> float:
    x = R * math.sin(u / R)
    # the cast draft: the top face rises out of a bevel round the edge
    edge = min(half_x(v) - abs(x), TOP_V - v, v - BOT_V)
    t = max(0.0, min(1.0, (edge - 0.001) / DRAFT))       # a straight draft slope with a soft top break
    f = RISE * (t - 0.25 * _smooth(0.75, 1.0, t) * (1.0 - t) * 4.0) - RISE
    # struck cartouches: steep-walled recesses
    for cx, cv, hx, hv in (CART, SERIAL):
        f -= STRIKE * (1.0 - _smooth(-0.0012, 0.0006, _box_dist(x, v, cx, cv, hx, hv)))
    # a faint mould seam across the chin
    f -= 0.0007 * math.exp(-((v + 0.094) / 0.0010) ** 2) * _smooth(0.0, 0.004, edge - DRAFT)
    return f


def _plate(kit: mask.MaskKit, loop: list[mask.Point2], hi: float, lo: float, holes=(), er: float = 0.003) -> None:
    kit.plate(mask.oriented([to_uv(x, v) for x, v in loop], True),
              holes=[mask.oriented([to_uv(x, v) for x, v in h], False) for h in holes],
              hi=hi, lo=lo, chamfer=0.0004, edge_res=er, res=0.04)


def _star(cx: float, cv: float, r0: float, r1: float, points: int = 6) -> list[mask.Point2]:
    out = []
    for k in range(2 * points):
        a = math.pi / 2 + math.pi * k / points
        r = r0 if k % 2 == 0 else r1
        out.append((cx + r * math.cos(a), cv + r * math.sin(a)))
    return out


def _marks(kit: mask.MaskKit) -> None:
    """The struck marks: star between two rules and '1000' in the brow cartouche, '0715' in the serial."""
    cx, cv, _hx, _hv = CART
    floor = 0.0                    # the plates sit on the skin, which is already struck down by STRIKE here
    top = 0.0024                   # so the marks stand 2.4 mm proud of the floor, still under the bar face
    # two rules framing the star (upper half of the cartouche)
    for rv in (cv + 0.0165, cv + 0.0035):
        _plate(kit, [(cx - 0.050, rv - 0.0007), (cx + 0.050, rv - 0.0007), (cx + 0.050, rv + 0.0007),
                     (cx - 0.050, rv + 0.0007)], top, floor - 0.002)
    _plate(kit, _star(cx, cv + 0.010, 0.0062, 0.0030), top + 0.0004, floor - 0.002)
    for ox in (-0.026, 0.026):
        _plate(kit, mask.disc(cx + ox, cv + 0.010, 0.0016, 10), top, floor - 0.002)
    # fineness numerals: the viewer reads left to right toward Blender -X
    for i, d in enumerate((1, 0, 0, 0)):
        c = (cx + 0.0195 - 0.013 * i, cv - 0.011)
        for o, hs in _digit_loops(d, c, (0.0, 1.0), 0.0105, 0.0017):
            _plate(kit, o, top, floor - 0.002, holes=hs, er=0.0012)
    sx, sv, _sh, _sv = SERIAL
    for i, d in enumerate((0, 7, 1, 5)):
        c = (sx + 0.0165 - 0.011 * i, sv)
        for o, hs in _digit_loops(d, c, (0.0, 1.0), 0.0090, 0.0015):
            _plate(kit, o, top, floor - 0.002, holes=hs, er=0.0011)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_marks],
                    surface_extra=_sculpt, outline_fn=_outline_fn, uv_mode="front", surface_wrap=_bar)
