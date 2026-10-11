"""Boar customisable base mask (``mask_base.boar``, D3-03).

An original wild boar: a broad, heavy, wedge-shaped face with a low scowling brow over small deep
eyes, short pointed ears flicked out at the top corners, a bristle crest of spikes along the top
edge, deep wrinkles over a big round snout that pushes straight forward and ends in a flat,
flared disc with two nostril rims, and two curved tusks rising from the jaw at the snout's sides,
sweeping out and up past the cheeks. Wide jaw, spiky crest and tusks make a squat, heavy read
quite unlike the slim animal masks.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_boar"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.090,
    "bottom": -0.116,
    "side_arc": 0.110,
    "jaw_taper": 0.16,
    "brow": 1.7,
    "cheek": 1.3,
    "nose": 0.0,
    "jaw": 1.2,
    "eye_shape": "almond",
    "eye_width": 0.027,
    "eye_height": 0.0120,
    "eye_spacing": 0.072,
    "eye_tilt_deg": 12.0,
    "mouth": "none",
    "face_half_width": 0.088,
    "wrap_radius": 0.096,
    "res": 0.0090,
    "res_back": 0.016,
    "edge_res": 0.0050,
}

SNOUT_V = -0.058          # snout axis height
SNOUT_LEN = 0.036         # how far the disc stands in front of the root
# right ear: inner base, tip, outer base
EAR = [(0.050, 0.074), (0.118, 0.118), (0.104, 0.036)]
EAR_TIP = (0.118, 0.118)
CREST_N = 7


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # heavy cheeks and jowls
    f += 0.0070 * _g(au - 0.060, 0.024) * _g(v + 0.050, 0.030)
    # the snout's broad root swelling out of the face
    f += 0.0120 * _g(au, 0.030) * _g(v - SNOUT_V, 0.030)
    # ears and crest held up out of the head's backward curve
    lift = _smooth(0.060, 0.130, v)
    f += lift * (0.6 * 3.2 * max(0.0, v - 0.02) ** 2)
    f += 0.30 * max(0.0, au - 0.098) ** 1.1 * _smooth(0.0, 0.05, v)
    return f


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    parts = [shape.outline()]
    tips = []
    ear = EAR + [(0.070, 0.050)]
    parts += [ear, mask.mirror(ear)]
    tips += [EAR_TIP, (-EAR_TIP[0], EAR_TIP[1])]
    # bristle crest: spikes along the top edge, tallest in the middle
    for k in range(CREST_N):
        s = (k - (CREST_N - 1) / 2) / ((CREST_N - 1) / 2)
        cu = 0.050 * s
        h = 0.030 - 0.012 * s * s
        base_v = 0.088 - 0.010 * s * s
        tip = (cu + 0.004 * s, base_v + h)
        parts.append([(cu - 0.0085, base_v - 0.01), tip, (cu + 0.0085, base_v - 0.01), (cu, base_v - 0.03)])
        tips.append(tip)
    return mask.radial_union(parts, centre=(0.0, -0.010), n=420, keep=tips)


def _brow(kit: mask.MaskKit) -> None:
    """Low scowling brow bars meeting in a knot over the snout."""
    pts = [(0.006 + 0.064 * t, 0.016 + 0.018 * t - 0.004 * t * t) for t in (k / 8 for k in range(9))]
    for loop in mask.mirrored(mask.resample(mask.strip(pts, 0.0150, 0.0080), 0.004)):
        kit.plate(loop, hi=0.0050, chamfer=0.0016, edge_res=0.004)


def _wrinkles(kit: mask.MaskKit) -> None:
    """Three arched wrinkles across the top of the snout root."""
    for k in range(3):
        v = -0.010 - 0.0085 * k
        w = 0.026 - 0.002 * k
        pts = [(w * (2 * i / 10 - 1), v + 0.006 * (1 - (2 * i / 10 - 1) ** 2)) for i in range(11)]
        kit.plate(mask.resample(mask.strip(pts, 0.0034, 0.0034), 0.004), hi=0.0022, chamfer=0.0008,
                  edge_res=0.004)


def _snout(kit: mask.MaskKit) -> None:
    """A round snout lofted straight forward from inside the shell, ending in a flared flat disc
    with two raised nostril rims."""
    surf = kit.surf
    t = float(kit.params["thickness"])
    n = 20
    rw, rh = 0.030, 0.024
    root = [(rw * math.cos(2 * math.pi * j / n), SNOUT_V + rh * math.sin(2 * math.pi * j / n)) for j in range(n)]
    y_root = [surf.depth_at(x, z) - 0.6 * t for x, z in root]
    y_end = max(y_root) + SNOUT_LEN
    sections = []
    for k in range(8):
        s = k / 7
        sc = 1.0 - 0.18 * math.sin(math.pi * min(1.0, s * 1.1)) + 0.10 * _smooth(0.75, 1.0, s)
        sec = []
        for j, (x, z) in enumerate(root):
            y = y_root[j] + (y_end - y_root[j]) * s
            sec.append(Vector((x * sc, y, SNOUT_V + (z - SNOUT_V) * sc - 0.004 * s)))
        sections.append(sec)
    kit.loft(sections, cap_start=False)
    c = Vector((0.0, y_end, SNOUT_V - 0.004))
    axis = Vector((0.0, 1.0, 0.0))
    m = kit.mat("primary")
    # disc rim and nostril rims
    mask.lathe(kit.mb, c, axis, [(0.0, -0.002), (0.0290, -0.002), (0.0300, 0.0015), (0.0275, 0.0030),
                                 (0.0, 0.0030)], m, n=24)
    for side in (1, -1):
        nc = c + Vector((side * 0.011, 0.0, 0.001))
        mask.lathe(kit.mb, nc, axis, [(0.0040, 0.002), (0.0068, 0.002), (0.0068, 0.0045), (0.0058, 0.0055),
                                      (0.0040, 0.0055), (0.0040, 0.0030), (0.0, 0.0030)], m, n=12)


def _tusks(kit: mask.MaskKit) -> None:
    """Curved tusks from the jaw beside the snout, out and up past the cheeks."""
    m = kit.mat("primary")
    for side in (1, -1):
        p0 = kit.surf.point(side * 0.044, -0.082, -0.004)
        p3 = p0 + Vector((side * 0.068, 0.034, 0.058))
        path = mask.bezier3(p0, p0 + Vector((side * 0.012, 0.036, -0.004)), p3 + Vector((-side * 0.010, 0.008, -0.030)),
                            p3, 10)
        mask.tube(kit.mb, path, lambda s: 0.0095 * (1 - s) ** 0.8 + 0.0008, m, n=10)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_brow, _wrinkles, _snout, _tusks],
                    surface_extra=_sculpt, outline_fn=_outline, uv_mode="front")
