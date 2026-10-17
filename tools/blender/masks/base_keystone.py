"""Keystone customisable base mask (``mask_base.keystone``, achievement reward, Ostrander Federal).

An original carved mascaron on an arch keystone, as on the doors of an old bank: the mask's outline
is the keystone wedge itself (wide, square top, straight sides tapering to a narrower base) framed by
a raised flat margin and a moulded cap band across the top. Carved into the stone in low relief is a
stern face: a heavy frowning brow knotted over the nose, a straight strong nose, hooded lids round
blank carved eyes (the eye holes are the only openings), a set mouth under a drooping leaf moustache
and a short beard of three leaves at the chin. Across the brow the hair turns into stylised
foliage: a fan of curling acanthus leaves round a central upright leaf, a scroll volute at each
temple and a column of curls down each side of the face. Original design, not a copy of a real
building's carving.

The block is a constant-width cylinder (``StoneSurface``, the face features kept), so the wedge
drawn in front-view coordinates (x, v) keeps straight sides; the crew fit lifts it clear of every
crew face.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_keystone"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "brow": 1.6,
    "cheek": 1.3,
    "nose": 1.7,
    "jaw": 1.0,
    "eye_shape": "almond",
    "eye_width": 0.032,
    "eye_height": 0.0130,
    "eye_spacing": 0.068,
    "eye_tilt_deg": -4.0,
    "mouth": "closed",
    "mouth_width": 0.040,
    "mouth_v": -0.074,
    "face_half_width": 0.110,
    "wrap_radius": 0.110,
    "thickness": 0.005,
    "chamfer": 0.0016,
    "res": 0.0110,
    "fit_clearance": 0.0045,
    "res_back": 0.016,
    "edge_res": 0.0075,
}

TOP_V, BOT_V = 0.100, -0.122       # top and base of the wedge (v)
TOP_X, BOT_X = 0.100, 0.064        # half widths (front view x) at the top and the base
Y0 = 0.032                         # block face depth on the centre line (m in front of the eye plane)
MARGIN = 0.0055                    # raised margin width
CAP = 0.015                        # moulded cap band height
REFINE = [(0.0, -0.066, 0.030, 0.026, 0.0050)]  # nose tip, lips


class StoneSurface(mask.FaceSurface):
    """Constant width (straight-sided wedge in front view), a flat block face, face features kept."""

    def width(self, v: float) -> float:
        return self.W0

    def profile(self, v: float) -> float:
        return Y0 - 0.6 * max(0.0, v - 0.04) ** 2 + 0.010 * math.sin(math.pi * min(max(-v, 0.0), 0.12) / 0.12)


def _stone(surf: mask.FaceSurface) -> mask.FaceSurface:
    return StoneSurface(surf.p, surf.extra)


R = PARAMS["wrap_radius"]


def to_uv(x: float, v: float) -> mask.Point2:
    return (R * math.asin(max(-0.999, min(0.999, x / R))), v)


def half_x(v: float) -> float:
    """Wedge half width (front view) at height v."""
    t = (v - BOT_V) / (TOP_V - BOT_V)
    return BOT_X + (TOP_X - BOT_X) * t


def _wedge(inset: float) -> mask.Loop2:
    top, bot = TOP_V - inset, BOT_V + inset
    tx = half_x(top) - inset * 1.05
    bx = half_x(bot) - inset * 1.05
    pts: mask.Loop2 = []
    for k in range(9):  # right side, bottom to top
        v = bot + (top - bot) * k / 8
        pts.append((-(bx + (tx - bx) * k / 8), v))
    for k in range(1, 8):  # top edge, right to left
        pts.append((-tx + 2 * tx * k / 8, top))
    for k in range(9):  # left side, top to bottom
        v = top - (top - bot) * k / 8
        pts.append((tx - (tx - bx) * k / 8, v))
    for k in range(1, 8):  # base, left to right
        pts.append((bx - 2 * bx * k / 8, bot))
    return [to_uv(x, v) for x, v in pts]


def _outline_fn(shape: mask.MaskShape) -> mask.Loop2:
    return mask.oriented(_wedge(0.0), True)


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # knotted frown: the brow swells over the inner eyes, a vertical furrow between them
    f += 0.0035 * _g(au - 0.018, 0.010) * _g(v - 0.020, 0.009)
    f -= 0.0030 * _g(au, 0.0030) * _g(v - 0.022, 0.012)
    # cheeks pulled down beside the nose (nasolabial folds), the stern set of the mouth
    f -= 0.0025 * _g(au - 0.026 - 0.25 * (-0.040 - v), 0.0035) * _smooth(-0.030, -0.040, v) * _smooth(-0.082, -0.072, v)
    # a broad, square chin
    f += 0.0040 * _g(au, 0.026) * _g(v + 0.098, 0.012)
    # the forehead behind the foliage sinks a little so the leaves stand proud
    f -= 0.0020 * _smooth(0.034, 0.050, v) * _smooth(TOP_V - CAP + 0.002, TOP_V - CAP - 0.006, v)
    return f


# --- the stone ----------------------------------------------------------------------------------
def _margin(kit: mask.MaskKit) -> None:
    """Raised flat margin round the wedge and a moulded cap band across the top."""
    outer = mask.oriented(_wedge(-0.0008), True)
    inner = mask.oriented(_wedge(MARGIN), False)
    kit.plate(outer, holes=[inner], hi=0.0030, lo=-0.0040, chamfer=0.0010, edge_res=0.012, res=0.03)
    # cap: two stepped bands (a cornice) inside the margin across the top
    for v0, v1, hi in ((TOP_V - CAP, TOP_V - MARGIN, 0.0042), (TOP_V - CAP - 0.0045, TOP_V - CAP + 0.0005, 0.0022)):
        x0, x1 = half_x(v0) - MARGIN, half_x(v1) - MARGIN
        band = [to_uv(-x0, v0), to_uv(-x1 * 0.5, v1), to_uv(-x1, v1)]
        band = [to_uv(-x0 + 2 * x0 * k / 10, v0) for k in range(11)] + \
               [to_uv(x1 - 2 * x1 * k / 10, v1) for k in range(11)]
        kit.plate(mask.oriented(band, True), hi=hi, lo=-0.0020, chamfer=0.0008, edge_res=0.012, res=0.03)


def _spiral(cx: float, cv: float, r0: float, turns: float, sense: int, start: float,
            n: int = 26) -> list[mask.Point2]:
    """Archimedean spiral from radius r0 inward (sense +1 = counter-clockwise in (u, v))."""
    pts = []
    for k in range(n + 1):
        t = k / n
        a = start + sense * 2 * math.pi * turns * t
        r = r0 * (1 - 0.72 * t)
        pts.append((cx + r * math.cos(a), cv + r * math.sin(a)))
    return pts


def _curl(kit: mask.MaskKit, cx: float, cv: float, r0: float, sense: int, start: float,
          turns: float = 1.25, w: float = 0.0034, hi: float = 0.0040) -> None:
    pts = _spiral(cx, cv, r0, turns, sense, start)
    loop = mask.strip(pts, w, w * 0.45)
    kit.plate(mask.oriented(loop, True), hi=hi, lo=-0.0020, chamfer=0.0008, edge_res=0.0034, res=0.03)


def _leaf_ridge(kit: mask.MaskKit, root: mask.Point2, tip: mask.Point2, bend: float, hi: float) -> None:
    pts = []
    dx, dy = tip[0] - root[0], tip[1] - root[1]
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln, dx / ln
    mid = (root[0] + dx * 0.5 + nx * bend * ln, root[1] + dy * 0.5 + ny * bend * ln)
    for k in range(1, 8):
        pts.append(mask.quad_bezier(root, mid, tip, 0.08 + 0.8 * k / 8))
    kit.plate(mask.oriented(mask.strip(pts, 0.0017, 0.0006), True), hi=hi + 0.0014, lo=hi - 0.0020,
              chamfer=0.0004, edge_res=0.004, res=0.03)


def _acanthus(root: mask.Point2, tip: mask.Point2, width: float, bend: float = 0.0, lobes: int = 3,
              n: int = 30) -> mask.Loop2:
    """Lobed acanthus leaf from ``root`` to a pointed ``tip``: the edge is notched into ``lobes`` lobes."""
    dx, dy = tip[0] - root[0], tip[1] - root[1]
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln, dx / ln
    mid = (root[0] + dx * 0.5 + nx * bend * ln, root[1] + dy * 0.5 + ny * bend * ln)
    left: mask.Loop2 = []
    right: mask.Loop2 = []
    for i in range(n + 1):
        t = i / n
        sp = mask.quad_bezier(root, mid, tip, t)
        sp2 = mask.quad_bezier(root, mid, tip, min(1.0, t + 1e-3))
        tx, ty = sp2[0] - sp[0], sp2[1] - sp[1]
        tl = math.hypot(tx, ty) or 1.0
        px, py = -ty / tl, tx / tl
        w = 0.5 * width * math.sin(math.pi * min(1.0, t ** 0.75)) if t < 1 else 0.0
        w *= 1.0 - 0.45 * abs(math.sin(lobes * math.pi * t)) ** 3 * (1.0 if 0.12 < t < 0.95 else 0.0)
        w = max(w, 0.5 * width * 0.3 * (1 - t) ** 4)
        left.append((sp[0] + px * w, sp[1] + py * w))
        right.append((sp[0] - px * w, sp[1] - py * w))
    return left[:-1] + [tip] + list(reversed(right[:-1]))


def _foliage(kit: mask.MaskKit) -> None:
    """Acanthus fan across the brow, a scroll volute at each temple and a column of curls down each side."""
    top = TOP_V - CAP - 0.005
    leaves = [((0.0, 0.029), (0.0, top), 0.024, 0.0, 3)]
    for s in (1, -1):
        leaves += [((0.006 * s, 0.032), (0.036 * s, top - 0.002), 0.021, -0.10 * s, 3),
                   ((0.010 * s, 0.031), (0.060 * s, 0.072), 0.018, -0.18 * s, 3)]
    for root, tip, w, bend, lobes in leaves:
        kit.plate(mask.oriented(_acanthus(root, tip, w, bend, lobes), True), hi=0.0036, lo=-0.0020,
                  chamfer=0.0009, edge_res=0.0030, res=0.03)
    _leaf_ridge(kit, (0.0, 0.029), (0.0, top), 0.0, 0.0036)
    for s in (1, -1):
        _curl(kit, s * 0.073, 0.057, 0.0125, s, math.pi * (1.0 if s > 0 else 0.0) + s * 0.6, turns=1.35, w=0.0046)
        for k, cv in enumerate((0.032, 0.014, -0.004, -0.022, -0.040)):
            r0 = 0.0095 - 0.0004 * k
            xu = half_x(cv) - MARGIN - r0 - 0.0022
            cu = to_uv(s * xu, cv)[0]
            _curl(kit, cu, cv, r0, s if k % 2 else -s, math.pi * (0.5 + 0.3 * k), turns=1.3, w=0.0040)


def _brows(kit: mask.MaskKit) -> None:
    """Heavy frowning brows: low and thick over the nose, rising to the temples."""
    for loop in mask.mirrored(mask.leaf((0.008, 0.016), (0.060, 0.028), 0.011, bend=-0.06, fullness=0.5)):
        kit.plate(mask.oriented(loop, True), hi=0.0034, chamfer=0.0011, edge_res=0.0035)


def _lids(kit: mask.MaskKit) -> None:
    """Hooded lids: a thick carved rim round each blank eye, heavier along the top."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    cu = sum(p[0] for p in eye) / len(eye)
    cv = sum(p[1] for p in eye) / len(eye)
    outer = mask.almond(cu, cv + 0.0018, 0.0215, 0.0115, point=1.5, tilt_deg=-4.0, lower=0.75)
    inner = mask.offset_loop(eye, -0.0006)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(mask.oriented(o, True), holes=[mask.oriented(h, False)], hi=0.0026, chamfer=0.0009,
                  edge_res=0.0035)


def _moustache(kit: mask.MaskKit) -> None:
    """Drooping leaf moustache under the nose and a three-leaf beard at the chin."""
    for loop in mask.mirrored(mask.leaf((0.003, -0.057), (0.036, -0.082), 0.011, bend=0.18, fullness=0.6)):
        kit.plate(mask.oriented(loop, True), hi=0.0034, chamfer=0.0009, edge_res=0.0035)
    beard = [((0.0, -0.092), (0.0, -0.118), 0.014, 0.0),
             ((0.006, -0.091), (0.026, -0.114), 0.012, -0.10),
             ((-0.006, -0.091), (-0.026, -0.114), 0.012, 0.10)]
    for root, tip, w, bend in beard:
        kit.plate(mask.oriented(mask.leaf(root, tip, w, bend=bend, n=10), True), hi=0.0030, lo=-0.0020,
                  chamfer=0.0008, edge_res=0.0035, res=0.03)
        _leaf_ridge(kit, root, tip, bend, 0.0030)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_margin, _foliage, _brows, _lids, _moustache],
                    surface_extra=_sculpt, outline_fn=_outline_fn, uv_mode="front", refine=REFINE,
                    surface_wrap=_stone)
