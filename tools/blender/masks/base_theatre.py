"""Theatre customisable base mask (``mask_base.theatre``, "Footlights", B4-15).

The comedy mask of the classic theatre pair, played big: a smooth, full classic face with high
arched brows, upturned crescent "laughing" eyes squeezed by round apple cheeks, laugh lines, and a
wide open crescent grin framed by a thick rolled lip, its upturned corners pressed into dimples.
Lightly asymmetric: one brow cocked higher and the grin lifted on the same side. Wider in the
cheeks than the visage; the grin and crescent eyes carry the read at distance.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_theatre"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.112,
    "top_peak": 0.003,
    "bottom": -0.122,
    "chin_point": 0.010,
    "side_arc": 0.110,
    "jaw_taper": 0.36,
    "brow": 0.5,
    "cheek": 0.6,
    "nose": 1.0,
    "jaw": 1.1,
    "eye_shape": "crescent",
    "eye_width": 0.038,
    "eye_height": 0.030,
    "eye_spacing": 0.068,
    "eye_v": 0.0,
    "eye_tilt_deg": -6.0,
    "mouth": "none",
    "face_half_width": 0.090,
    "wrap_radius": 0.094,
    "res": 0.0080,
    "res_back": 0.015,
    "edge_res": 0.0045,
}

EYE_U = 0.034
MOUTH_V = -0.066     # centre line of the grin's upper edge
MOUTH_HW = 0.036     # half width (corner to centre)
TILT = 0.0050        # light asymmetry: the grin's -u corner sits this much higher than the +u one
BROW_LIFT = 0.0060   # ... and the -u brow arches this much higher (a cocked brow)
REFINE = [(0.0, -0.072, 0.056, 0.030, 0.0040)]  # the grin, lip roll and laugh lines


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _seg(u: float, v: float, a: tuple[float, float], b: tuple[float, float]) -> float:
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((u - a[0]) * dx + (v - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.hypot(u - a[0] - t * dx, v - a[1] - t * dy)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # round apple cheeks pushed up under the eyes
    f += 0.0115 * _g(au - 0.048, 0.021) * _g(v + 0.034, 0.019)
    # laugh lines: a crease from the nose wing round the cheek to the lip corner
    f -= 0.0022 * _g(_seg(au, v, (0.020, -0.038), (0.044, -0.062)), 0.0030)
    # the lips roll forward around the grin
    f += 0.0045 * _g(au, 0.034) * _g(v - (MOUTH_V - 0.012), 0.020)
    # dimples just past the upturned corners of the grin
    tilt = -TILT * 0.5 * math.copysign(1.0, u)
    f -= 0.0022 * _g(au - (MOUTH_HW + 0.011), 0.0045) * _g(v - (MOUTH_V + 0.014 + tilt), 0.0055)
    # rounded nose tip and nostril wings
    f += 0.0030 * _g(au - 0.012, 0.006) * _g(v + 0.044, 0.006)
    # chin ball with a dimple
    f += 0.0040 * _g(au, 0.020) * _g(v + 0.108, 0.010)
    f -= 0.0010 * _g(au, 0.004) * _g(v + 0.106, 0.004)
    # raised forehead bump between the arched brows (the eyebrows lifted in delight)
    f += 0.0025 * _g(au, 0.030) * _g(v - 0.040, 0.014)
    # temples soften back
    f -= 0.0025 * _g(au - 0.086, 0.015) * _g(v - 0.035, 0.030)
    return f


def _grin() -> mask.Loop2:
    """Wide open crescent grin (CCW): a gently rising upper edge and a deep lower curve; the
    corners turn up."""
    m = 18
    upper: mask.Loop2 = []
    lower: mask.Loop2 = []
    for k in range(m + 1):
        s = -1 + 2 * k / m
        upper.append((MOUTH_HW * s, MOUTH_V + 0.012 * s ** 2 - 0.0015 * (1 - s * s)))
    for k in range(1, m):
        s = 1 - 2 * k / m
        lower.append((MOUTH_HW * 0.94 * s, MOUTH_V + 0.012 * s ** 2 - 0.027 * (1 - s * s) ** 0.85))
    loop = list(reversed(upper)) + list(reversed(lower))
    return mask.oriented([(u, v - TILT * 0.5 * u / MOUTH_HW) for u, v in loop], True)


def _holes(shape: mask.MaskShape) -> list[mask.Loop2]:
    return [_grin()]


def _lip(kit: mask.MaskKit) -> None:
    """Thick rolled lip around the grin."""
    hole = mask.resample(_grin(), 0.003)
    inner = mask.offset_loop(hole, -0.0010)
    outer = mask.offset_loop(hole, -0.0085, max_miter=1.15)
    kit.plate(outer, holes=[inner], hi=0.0036, chamfer=0.0018, edge_res=0.003)


def _brows(kit: mask.MaskKit) -> None:
    """High, sharply arched brows lifted in delight."""
    pts = [(0.010 + 0.064 * t, 0.030 + 0.030 * math.sin(math.pi * (0.15 + 0.85 * t)) - 0.010 * t)
           for t in (k / 10 for k in range(11))]
    brow = mask.strip(pts, 0.0105, 0.0035)
    lifted = mask.strip([(u, v + BROW_LIFT * math.sin(math.pi * min(1.0, 1.4 * (u - 0.010) / 0.064)))
                         for u, v in pts], 0.0105, 0.0035)
    for loop in (brow, mask.mirror(lifted)):
        kit.plate(mask.resample(loop, 0.003), hi=0.0032, chamfer=0.0011, edge_res=0.003)


def _lids(kit: mask.MaskKit) -> None:
    """A slim rim on each crescent eye."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0008)
    outer = mask.offset_loop(eye, -0.0042, max_miter=1.3)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0014, chamfer=0.0005, edge_res=0.003)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_lids, _brows, _lip],
                    surface_extra=_sculpt, holes_fn=_holes, uv_mode="front", refine=REFINE)
