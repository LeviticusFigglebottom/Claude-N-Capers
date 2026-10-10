"""Owl customisable base mask (``mask_base.owl``, QB-50b).

A horned owl: a round, heart-topped facial disc bordered by a raised ruff rim, two concave
dishes around large stepped round eye rings, a short hooked beak between them, feathered ear
tufts rising from the upper corners and a V of scalloped brow feathers. Broad and round in the
silhouette, with the tufts as its read at distance.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_owl"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.082,
    "bottom": -0.090,
    "chin_point": 0.014,
    "side_arc": 0.122,
    "jaw_taper": 0.22,
    "brow": 0.6,
    "cheek": 0.6,
    "nose": 0.0,
    "jaw": 0.6,
    "eye_shape": "round",
    "eye_width": 0.035,
    "eye_height": 0.033,
    "eye_spacing": 0.072,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "face_half_width": 0.088,
    "wrap_radius": 0.105,
    "res": 0.0098,
    "res_back": 0.015,
}

EYE_U = 0.036
TUFT = [(0.034, 0.064), (0.090, 0.140), (0.120, 0.036)]
TUFT_TIP = (0.090, 0.140)


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # the two concave dishes of the facial disc, centred a little below each eye
    d = math.hypot(au - EYE_U, (v + 0.006) * 0.9)
    f -= 0.0100 * _g(d, 0.040)
    # a ridge down the centre between the dishes, carrying the beak
    f += 0.0045 * _g(au, 0.010) * _smooth(0.05, 0.0, v) * _smooth(-0.095, -0.03, v)
    # keep the tufts standing up instead of following the skull back
    f += _smooth(0.07, 0.15, v) * 0.55 * 3.2 * max(0.0, v - 0.02) ** 2
    return f


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    face = [(u, v - 0.010 * _g(u, 0.018)) if v > 0 else (u, v) for u, v in shape.outline()]
    tuft = mask.spline_loop(TUFT, samples=6, sharp=(1,))
    return mask.radial_union([face, tuft, mask.mirror(tuft)], centre=(0.0, -0.005), n=400,
                             keep=[TUFT_TIP, (-TUFT_TIP[0], TUFT_TIP[1])])


def _disc_rim(kit: mask.MaskKit) -> None:
    """Raised ruff rim around the facial disc: the outline band below the tufts."""
    outline = mask.resample(mask.oriented(_outline(kit.shape), True), 0.004)
    outer = mask.offset_loop(outline, 0.0030)
    inner = mask.offset_loop(outline, 0.0120)
    idx = [i for i, (u, v) in enumerate(outline) if v < 0.058 - 0.25 * abs(u)]
    # clockwise from the top: right side, chin, left side
    idx.sort(key=lambda i: (math.pi / 2 - math.atan2(outline[i][1] + 0.005, outline[i][0])) % (2 * math.pi))
    band = [outer[i] for i in idx] + [inner[i] for i in reversed(idx)]
    kit.plate(band, hi=0.0034, chamfer=0.0010, edge_res=0.004)


def _eye_rings(kit: mask.MaskKit) -> None:
    """Large stepped round eye rings: a broad low ring and a tall inner lip."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    hole = mask.offset_loop(eye, -0.0010)
    mid = mask.offset_loop(eye, -0.0060)
    out = mask.offset_loop(eye, -0.0125)
    for o, h, hi in ((out, mid, 0.0026), (mid, hole, 0.0060)):
        for oo, hh in ((o, h), (mask.mirror(o), mask.mirror(h))):
            kit.plate(oo, holes=[hh], hi=hi, chamfer=0.0008, edge_res=0.004)


def _brow_feathers(kit: mask.MaskKit) -> None:
    """A V of scalloped feathers over the brows, pointing down to the beak."""
    rows = [((0.006, 0.020), (0.070, 0.062), 0.014, 0.0030),
            ((0.006, 0.036), (0.062, 0.078), 0.014, 0.0024),
            ((0.006, 0.052), (0.046, 0.086), 0.012, 0.0018)]
    for tip, root, w, hi in rows:
        f = mask.leaf(root, tip, w, bend=-0.06, n=8, fullness=0.45)
        for loop in mask.mirrored(f):
            kit.plate(loop, hi=hi, chamfer=0.0007)


def _tuft_feathers(kit: mask.MaskKit) -> None:
    """Two raised feather blades in each ear tuft."""
    for root, tip, w in (((0.058, 0.068), (0.086, 0.126), 0.013), ((0.082, 0.058), (0.100, 0.108), 0.011)):
        f = mask.leaf(root, tip, w, bend=0.05, n=8, fullness=0.55)
        for loop in mask.mirrored(f):
            kit.plate(loop, hi=0.0024, chamfer=0.0006, edge_res=0.004)


def _beak(kit: mask.MaskKit) -> None:
    """Short hooked beak: a rounded ridge leaving the face between the eyes and hooking down."""
    surf = kit.surf
    t = float(kit.params["thickness"])
    z0 = -0.004
    y0 = surf.depth_at(0.0, z0) - 0.5 * t
    p0 = Vector((0.0, y0, z0))
    p1 = Vector((0.0, surf.depth_at(0.0, -0.018) + 0.024, -0.014))
    p2 = Vector((0.0, surf.depth_at(0.0, -0.044) + 0.014, -0.046))

    def bez(s: float) -> Vector:
        return p0 * (1 - s) ** 2 + p1 * 2 * (1 - s) * s + p2 * s * s

    n = 12
    sections = []
    for k in range(n):
        s = k / n
        c = bez(s)
        tan = (bez(min(1.0, s + 0.01)) - bez(max(0.0, s - 0.01))).normalized()
        up = Vector((0.0, -tan.z, tan.y))  # perpendicular to the path in the YZ plane, pointing up/back
        if up.z < 0:
            up = -up
        side = Vector((1.0, 0.0, 0.0))
        w = 0.0155 * (1 - s) ** 0.6 + 0.0008
        h = 0.0125 * (1 - s) ** 0.7 + 0.0008
        sec = []
        for j in range(10):
            a = 2 * math.pi * j / 10
            ca, sa = math.cos(a), math.sin(a)
            # keel on top (pointed), rounder underneath
            hh = h * (1.0 + 0.25 * max(sa, 0.0) ** 3) if sa > 0 else h * 0.75
            ww = w * (1.0 - 0.35 * max(sa, 0.0) ** 2)
            sec.append(c + side * (ww * ca) + up * (hh * sa) - up * 0.15 * h)
        sections.append(sec)
    kit.loft(sections, tip=p2 + Vector((0.0, -0.004, -0.004)), cap_start=False)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_disc_rim, _eye_rings, _brow_feathers, _tuft_feathers, _beak],
                    surface_extra=_sculpt, outline_fn=_outline, uv_mode="front")
