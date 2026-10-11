"""Cat customisable base mask (``mask_base.cat``, D3-03).

An original feline: a round, wide-cheeked face with no snout, two broad triangular ears set far
apart with rounded tips and a hollow inside, large almond eyes slanting up under a tabby "M" of
raised stripes on the brow, a small triangular nose pad over a split upper lip, two plump whisker
pads, and three raised whiskers fanning out from each pad. The wide flat face under two set-apart
ears reads as a cat at distance, distinct from the long-snouted, tall-eared vulpine.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_cat"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.090,
    "bottom": -0.104,
    "chin_point": 0.006,
    "side_arc": 0.108,
    "jaw_taper": 0.46,
    "brow": 0.8,
    "cheek": 1.4,
    "nose": 0.0,
    "jaw": 0.6,
    "eye_shape": "almond",
    "eye_width": 0.038,
    "eye_height": 0.0175,
    "eye_spacing": 0.070,
    "eye_tilt_deg": 14.0,
    "mouth": "none",
    "face_half_width": 0.084,
    "res": 0.0085,
    "res_back": 0.015,
    "edge_res": 0.0050,
}

# right ear: inner base, (rounded) tip, outer base, in (u, v)
EAR = [(0.020, 0.080), (0.058, 0.120), (0.080, 0.136), (0.096, 0.120), (0.106, 0.048)]
EAR_TIP = (0.082, 0.134)
PAD = (0.017, -0.056)   # whisker pad centre (right)
REFINE = [(0.0, -0.050, 0.040, 0.026, 0.0045)]


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _ear_axis(u: float, v: float) -> tuple[float, float]:
    """(along, across) of (|u|, v) relative to the ear's centre line (0 at the base, 1 at the tip)."""
    bx, by = 0.064, 0.070
    tx, ty = EAR_TIP
    dx, dy = tx - bx, ty - by
    ln = math.hypot(dx, dy)
    ax, ay = dx / ln, dy / ln
    px, py = abs(u) - bx, v - by
    return (px * ax + py * ay) / ln, -px * ay + py * ax


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # stand the ears up out of the head's backward curve
    lift = _smooth(0.070, 0.150, v)
    f += lift * (0.70 * 3.2 * max(0.0, v - 0.02) ** 2 + 0.008 * _g(au - 0.07, 0.04))
    along, across = _ear_axis(u, v)
    if -0.2 < along < 1.1:
        f -= 0.0060 * _g(across, 0.013 * (1.2 - 0.8 * max(0.0, along))) * _smooth(-0.1, 0.3, along) * _smooth(1.0, 0.6, along)
    # the muzzle: two plump whisker pads and a short bridge to the nose
    f += 0.0090 * _g(math.hypot(au - PAD[0], (v - PAD[1]) * 1.15), 0.016)
    f += 0.0050 * _g(au, 0.012) * _smooth(0.0, -0.030, v) * _smooth(-0.060, -0.040, v)
    # the split upper lip between the pads, and the chin tucked under
    f -= 0.0022 * _g(au, 0.0022) * _g(v + 0.060, 0.010)
    f += 0.0030 * _g(au, 0.016) * _g(v + 0.084, 0.010)
    # full round cheeks out to the sides
    f += 0.0045 * _g(au - 0.070, 0.020) * _g(v + 0.030, 0.026)
    return f


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    ear = mask.spline_loop(EAR, samples=5, sharp=(0, 4))
    return mask.radial_union([shape.outline(), ear, mask.mirror(ear)], centre=(0.0, -0.008), n=420)


def _lids(kit: mask.MaskKit) -> None:
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0010)
    outer = mask.offset_loop(eye, -0.0045, max_miter=1.6)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0018, chamfer=0.0006, edge_res=0.004)


def _tabby(kit: mask.MaskKit) -> None:
    """Tabby "M": a centre stripe and two curved stripes each side over the brow."""
    kit.plate(mask.leaf((0.0, 0.040), (0.0, 0.084), 0.0085, n=8, fullness=0.5), hi=0.0020, chamfer=0.0007,
              edge_res=0.004)
    for root, tip, w in (((0.012, 0.034), (0.026, 0.080), 0.0075), ((0.030, 0.036), (0.052, 0.072), 0.0070),
                         ((0.068, 0.020), (0.094, 0.044), 0.0080)):
        for loop in mask.mirrored(mask.leaf(root, tip, w, bend=-0.10, n=8, fullness=0.5)):
            kit.plate(loop, hi=0.0020, chamfer=0.0007, edge_res=0.004)


def _nose(kit: mask.MaskKit) -> None:
    """Small inverted-triangle nose pad with rounded corners."""
    tri = mask.spline_loop([(-0.0105, -0.034), (0.0105, -0.034), (0.0, -0.047)], samples=8)
    kit.plate(tri, hi=0.0040, chamfer=0.0015, edge_res=0.0030)


def _whiskers(kit: mask.MaskKit) -> None:
    """Three raised whiskers fanning from each pad, with three whisker dots on the pad."""
    for k, (dv, ang) in enumerate(((0.006, 10.0), (0.0, -4.0), (-0.006, -18.0))):
        a = math.radians(ang)
        r0 = (PAD[0] + 0.012, PAD[1] + dv)
        pts = [(r0[0] + 0.044 * t * math.cos(a), r0[1] + 0.044 * t * math.sin(a) - 0.006 * t * t * (k - 1))
               for t in (i / 8 for i in range(9))]
        for loop in mask.mirrored(mask.resample(mask.strip(pts, 0.0030, 0.0012), 0.005)):
            kit.plate(loop, hi=0.0018, chamfer=0.0006, edge_res=0.005)
    for du, dv in ((0.006, 0.004), (0.012, -0.001), (0.006, -0.006)):
        for loop in mask.mirrored(mask.disc(PAD[0] + du - 0.004, PAD[1] + dv, 0.0018, 8)):
            kit.plate(loop, hi=0.0012, chamfer=0.0005, edge_res=0.004)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_lids, _tabby, _nose, _whiskers],
                    surface_extra=_sculpt, outline_fn=_outline, uv_mode="front", refine=REFINE)
