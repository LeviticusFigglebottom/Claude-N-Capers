"""Visage customisable base mask (``mask_base.visage``, QB-50b).

The classic theatre face: a calm, neutral, full-face human visage with a straight nose, soft
cheekbones, sculpted closed lips (cupid's bow, philtrum, fuller lower lip) and quiet lids. No
ornaments: the large, smooth planes are the cleanest canvas in the set for colour pairs and
patterns. A finer mesh is used where the face is sculpted (lips, nostrils, lids).

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_visage"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.110,
    "top_peak": 0.004,
    "bottom": -0.121,
    "chin_point": 0.002,
    "side_arc": 0.103,
    "jaw_taper": 0.33,
    "brow": 0.85,
    "cheek": 1.0,
    "nose": 1.15,
    "jaw": 1.15,
    "eye_shape": "almond",
    "eye_width": 0.033,
    "eye_height": 0.0135,
    "eye_tilt_deg": 3.0,
    "mouth": "none",
    "res": 0.0075,
    "res_back": 0.014,
    "edge_res": 0.0045,
}

EYE_U = 0.033  # half the default eye spacing


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _seg(u: float, v: float, a: tuple[float, float], b: tuple[float, float]) -> float:
    """Distance from (u, v) to segment a-b."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((u - a[0]) * dx + (v - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.hypot(u - a[0] - t * dx, v - a[1] - t * dy)


def _sculpt(u: float, v: float) -> float:
    """Extra forward displacement (m) on top of the base face: lips, philtrum, nostrils, lids."""
    au = abs(u)
    mv = -0.067  # mouth line
    f = 0.0
    # upper lip with a cupid's bow (its edge rises either side of the centre), fuller lower lip
    bow = 0.0012 * _g(au - 0.0065, 0.0035) - 0.0004 * _g(au, 0.003)
    f += 0.0030 * _g(au, 0.0175) * _g(v - (mv + 0.0042 + 0.5 * bow), 0.0034 + 0.4 * bow)
    f += 0.0042 * _g(au, 0.0150) * _g(v - (mv - 0.0062), 0.0046)
    # lip parting line and the corners of the mouth tucked in
    f -= 0.0014 * _g(au, 0.0215) * _g(v - mv, 0.0014)
    f -= 0.0016 * _g(au - 0.0225, 0.0040) * _g(v - mv, 0.0045)
    # chin crease under the lower lip
    f -= 0.0010 * _g(au, 0.014) * _g(v - (mv - 0.0165), 0.0035)
    # philtrum: two soft ridges from the upper lip to the nose
    t = max(0.0, min(1.0, (v - (mv + 0.008)) / 0.012))
    f += 0.0007 * math.sin(math.pi * t) * _g(au - 0.0045, 0.0022)
    # nostril wings and the alar crease around them
    f += 0.0030 * _g(au - 0.0125, 0.0055) * _g(v + 0.045, 0.0050)
    f -= 0.0014 * _g(au - 0.0195, 0.0025) * _g(v + 0.043, 0.0070)
    # soft nasolabial folds
    f -= 0.0010 * _g(_seg(au, v, (0.022, -0.041), (0.032, -0.070)), 0.0035)
    # upper-lid fold and a gentle lower-lid swell
    f += 0.0010 * _g(au - EYE_U, 0.017) * _g(v - 0.0115, 0.0030)
    f += 0.0008 * _g(au - EYE_U, 0.015) * _g(v + 0.0105, 0.0035)
    # temples soften back
    f -= 0.0025 * _g(au - 0.085, 0.015) * _g(v - 0.035, 0.030)
    return f


REFINE = [
    (0.0, -0.068, 0.032, 0.019, 0.0028),   # lips
    (0.0, -0.044, 0.030, 0.012, 0.0040),   # nostrils, nose tip
    (0.0, -0.010, 0.010, 0.032, 0.0045),   # nose ridge
]


def _lids(kit: mask.MaskKit) -> None:
    """A slim, low lid rim around each eye: a crisp edge without breaking the canvas."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0008)
    outer = mask.offset_loop(eye, -0.0038)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0009, chamfer=0.0004, edge_res=0.0035)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_lids],
                    surface_extra=_sculpt, uv_mode="front", refine=REFINE)
