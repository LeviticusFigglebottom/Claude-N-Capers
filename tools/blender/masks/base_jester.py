"""Jester customisable base mask (``mask_base.jester``, D3-03).

An original jester: a sly, narrow face with high round cheeks and a long pointed chin, mischievous
upswept eyes each set in a raised harlequin diamond, thin arched brows, a single tear under the
left eye, and a thin crescent grin cut right through the shell with a rolled lip, its points
curling up into the cheeks. A three-pointed cap edge rises from the brow: a flange off the shell's
top edge (``_mask_base.RimSurface``) whose three points curl outward, each tipped with a round bell.
The three belled points are the read at distance.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_jester"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.094,
    "bottom": -0.110,
    "chin_point": 0.020,
    "side_arc": 0.100,
    "jaw_taper": 0.50,
    "brow": 0.5,
    "cheek": 1.6,
    "nose": 0.6,
    "jaw": 0.7,
    "eye_shape": "almond",
    "eye_width": 0.033,
    "eye_height": 0.0130,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 18.0,
    "mouth": "none",
    "res": 0.0085,
    "res_back": 0.015,
    "edge_res": 0.0050,
}

CENTRE = (0.0, -0.004)
TUCK = 0.0015
BAND = 0.010
# cap points: (root angle deg, tip (u, v), width at the root, bend) for the right side and centre
POINTS = [(90.0, (0.010, 0.170), 0.036, -0.10), (40.0, (0.120, 0.130), 0.040, 0.18)]
BELL_R = 0.0088
GRIN_V = -0.064
GRIN_HW = 0.046


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # high round cheek apples pushed up by the grin
    f += 0.0070 * _g(math.hypot(au - 0.046, v + 0.036), 0.017)
    # the grin's corners pressed into the cheeks
    f -= 0.0030 * _g(math.hypot(au - 0.050, v + 0.050), 0.0055)
    # long pointed chin
    f += 0.0050 * _g(au, 0.018) * _g(v + 0.104, 0.018)
    return f


def _grin() -> mask.Loop2:
    """Thin crescent grin (CCW): both arcs sag in the middle, the points curl up."""
    m = 20
    upper: mask.Loop2 = []
    lower: mask.Loop2 = []
    for k in range(m + 1):
        s = -1 + 2 * k / m
        upper.append((GRIN_HW * s, GRIN_V - 0.016 * (1 - s * s) + 0.010 * s ** 4))
    for k in range(1, m):
        s = 1 - 2 * k / m
        lower.append((GRIN_HW * 0.94 * s, GRIN_V - 0.024 * (1 - s * s) ** 0.9 + 0.009 * s ** 4))
    return mask.oriented(upper + lower, True)


def _holes(shape: mask.MaskShape) -> list[mask.Loop2]:
    return [_grin()]


def _point_loops() -> list[tuple[mask.Loop2, mask.Point2]]:
    """The cap points in (u, v), each with its tip."""
    out = []
    for ang, tip, w, bend in POINTS:
        a = math.radians(ang)
        root = (CENTRE[0] + 0.070 * math.cos(a), CENTRE[1] + 0.070 * math.sin(a))
        for side in ((1,) if ang == 90.0 else (1, -1)):
            r = (side * root[0], root[1])
            t = (side * tip[0], tip[1])
            loop = mask.leaf(r, t, w, bend=bend * side, n=12, fullness=0.35, root_round=0.9)
            out.append((loop, t))
    return out


def _cap(kit: mask.MaskKit) -> None:
    """The three-pointed cap edge and a bell on each point."""
    outline = kit.shape.outline()
    t = float(kit.params["thickness"])
    rim = mask.RimSurface(kit.surf, outline, centre=CENTRE, inset=0.0015, depth=-t + 0.0015, tilt=0.18)
    m = kit.mat("primary")
    pts = _point_loops()
    a0, a1 = math.radians(12.0), math.radians(168.0)
    # outer contour over the cap's angular span: the farther of the band (a strip just above the
    # shell edge) and the points per ray, the point tips kept exactly; back along an inner arc
    # tucked under the shell rim
    loops = [lp for lp, _t in pts]
    outer = []
    for k in range(181):
        phi = a0 + (a1 - a0) * k / 180
        r_o = mask.ray_radius(CENTRE, phi, outline)
        r = max([r_o + BAND * math.sin(math.pi * k / 180) ** 0.3] + [mask.ray_radius(CENTRE, phi, lp) for lp in loops])
        outer.append((phi, (CENTRE[0] + r * math.cos(phi), CENTRE[1] + r * math.sin(phi))))
    for _lp, tp in pts:
        outer.append((math.atan2(tp[1] - CENTRE[1], tp[0] - CENTRE[0]), tp))
    outer.sort(key=lambda e: e[0])
    tips = {tp for _lp, tp in pts}
    contour = [q for _a, q in outer
               if q in tips or all(math.dist(q, tp) > 0.002 for tp in tips)]
    inner = []
    for k in range(25):
        phi = a1 - (a1 - a0) * k / 24
        r = mask.ray_radius(CENTRE, phi, outline) - TUCK
        inner.append((CENTRE[0] + r * math.cos(phi), CENTRE[1] + r * math.sin(phi)))
    mask.slab(kit.mb, rim, mask.oriented(contour + inner, True), [], -0.0028, 0.0, 0.0010, m, m, m,
              0.03, 0.03, 0.006, bottom=True)
    # a raised hem along the cap's lower edge
    hem_o = [(CENTRE[0] + (mask.ray_radius(CENTRE, p, outline) + 0.0085) * math.cos(p),
              CENTRE[1] + (mask.ray_radius(CENTRE, p, outline) + 0.0085) * math.sin(p))
             for p in (a0 + 0.08 + (a1 - a0 - 0.16) * k / 48 for k in range(49))]
    hem_i = [(CENTRE[0] + (mask.ray_radius(CENTRE, p, outline) + 0.0015) * math.cos(p),
              CENTRE[1] + (mask.ray_radius(CENTRE, p, outline) + 0.0015) * math.sin(p))
             for p in (a1 - 0.08 - (a1 - a0 - 0.16) * k / 48 for k in range(49))]
    mask.slab(kit.mb, rim, mask.oriented(hem_o + hem_i, True), [], -0.001, 0.0022, 0.0008, m, m, None,
              0.03, 0.03, 0.005, bottom=False)
    for _lp, (tu, tv) in pts:
        c = rim.point(tu, tv, -0.002)
        d = Vector((tu - CENTRE[0], 0.0, tv - CENTRE[1])).normalized()
        mask.sphere(kit.mb, c + d * (BELL_R * 0.6), BELL_R, m, n=14, rings=7, axis=d)
        # the bell's mouth: a slot ring round its outer end
        mask.lathe(kit.mb, c + d * (BELL_R * 1.15), d, [(0.0, -0.0012), (0.0062, -0.0012), (0.0068, 0.0006),
                                                         (0.0, 0.0006)], m, n=14)


def _diamonds(kit: mask.MaskKit) -> None:
    """A raised harlequin diamond round each eye, the eye cut through it."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    cu = kit.surf.eye_u
    dia = [(cu, 0.042), (cu + 0.025, 0.0), (cu, -0.040), (cu - 0.025, 0.0)]
    hole = mask.offset_loop(eye, -0.0010)
    for o, h in ((dia, hole), (mask.mirror(dia), mask.mirror(hole))):
        kit.plate(o, holes=[h], hi=0.0020, chamfer=0.0008, edge_res=0.006)


def _brows_tear(kit: mask.MaskKit) -> None:
    """Thin arched brows above the diamonds, and one tear under the left eye."""
    pts = [(0.012 + 0.050 * t, 0.046 + 0.010 * math.sin(math.pi * t) + 0.004 * t) for t in (k / 8 for k in range(9))]
    for loop in mask.mirrored(mask.resample(mask.strip(pts, 0.0032, 0.0018), 0.004)):
        kit.plate(loop, hi=0.0022, chamfer=0.0008, edge_res=0.004)
    cu = -kit.surf.eye_u
    tear = mask.leaf((cu, -0.060), (cu + 0.0005, -0.042), 0.0085, n=8, fullness=0.35, root_round=1.0)
    kit.plate(tear, hi=0.0022, chamfer=0.0009, edge_res=0.003)


def _lip(kit: mask.MaskKit) -> None:
    hole = mask.resample(_grin(), 0.003)
    kit.plate(mask.offset_loop(hole, -0.0050, max_miter=1.2), holes=[mask.offset_loop(hole, -0.0008)],
              hi=0.0026, chamfer=0.0010, edge_res=0.0035)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_diamonds, _brows_tear, _lip, _cap],
                    surface_extra=_sculpt, holes_fn=_holes, uv_mode="front")
