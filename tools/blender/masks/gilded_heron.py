"""Gilded Heron crew mask (``mask.gilded_heron``, D1-04).

An art-deco heron: a gilded full-face shell with a long faceted dagger beak springing from the
nose bridge, stepped gold feather plates sweeping back over the brows and cheeks, a stepped crest
keel up the forehead to a pointed widow's peak, and dark lacquer eye stripes (the heron's black
eye band) that run from the eyes back to the temples, ending in lacquer plume tips.

Materials (MaskDef colour_a / colour_b): ``M_char_mask_gold`` (metallic 1, roughness 0.3),
``M_char_mask_lacquer_dark`` (roughness 0.4), ``M_char_mask_inner`` (matte inside of the shell).

Pivot: the face centre (see ``_mask_base``): midway between the eye centres at eye depth;
Blender +Y (= Godot -Z) forward. The beak tip is the most forward point.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_gilded_heron"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.098,
    "top_peak": 0.024,
    "bottom": -0.114,
    "chin_point": 0.012,
    "side_arc": 0.108,
    "jaw_taper": 0.34,
    "brow": 1.3,
    "cheek": 0.8,
    "nose": 0.4,
    "jaw": 1.0,
    "eye_shape": "almond",
    "eye_width": 0.036,
    "eye_height": 0.017,
    "eye_tilt_deg": 9.0,
    "mouth": "none",
    "res": 0.010,
    "res_back": 0.016,
    # ornaments
    "beak_tip": (0.0, 0.135, -0.070),
    "beak_root_top": 0.010,
    "beak_root_bottom": -0.056,
    "beak_half_width": 0.0155,
}

EYE_MARGIN = 0.0016  # gold lip left between the eye hole and the lacquer band


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _eye_stripes(kit: mask.MaskKit) -> None:
    """Lacquer band around each eye, sweeping back to a plume tip at the temple."""
    pts = [(0.010, -0.004), (0.012, 0.011), (0.030, 0.0175), (0.056, 0.0185), (0.080, 0.027),
           (0.105, 0.041), (0.090, 0.010), (0.066, -0.012), (0.038, -0.0200), (0.018, -0.016)]
    band = mask.spline_loop(pts, samples=5, sharp=(5,))
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    hole = mask.offset_loop(eye, -EYE_MARGIN)
    for outline, h in ((band, hole), (mask.mirror(band), mask.mirror(hole))):
        kit.plate(outline, holes=[h], hi=0.0010, lo=-0.0015, chamfer=0.0004, mat="accent", edge_res=0.005)


def _brow_feathers(kit: mask.MaskKit) -> None:
    """Three stepped gold feather plates per side, sweeping up and back over the brow."""
    tiers = [((0.004, 0.021), (0.093, 0.043), 0.021, 0.0024),
             ((0.004, 0.037), (0.080, 0.062), 0.022, 0.0036),
             ((0.004, 0.053), (0.058, 0.079), 0.020, 0.0048)]
    for root, tip, width, hi in tiers:
        f = mask.leaf(root, tip, width, bend=0.05, n=8, fullness=0.55)
        for loop in mask.mirrored(f):
            kit.plate(loop, hi=hi, chamfer=0.0007)


def _cheek_feathers(kit: mask.MaskKit) -> None:
    """Three stepped plates per side under the eye, sweeping back toward the ears."""
    tiers = [((0.017, -0.023), (0.100, -0.004), 0.018, 0.0040),
             ((0.019, -0.038), (0.096, -0.024), 0.019, 0.0030),
             ((0.022, -0.053), (0.088, -0.045), 0.017, 0.0020)]
    for root, tip, width, hi in tiers:
        f = mask.leaf(root, tip, width, bend=-0.04, n=8, fullness=0.55)
        for loop in mask.mirrored(f):
            kit.plate(loop, hi=hi, chamfer=0.0007)


def _crest(kit: mask.MaskKit) -> None:
    """Stepped keel up the forehead centre, from the beak root to the widow's peak."""
    p = kit.params
    top = float(p["top"]) + float(p["top_peak"]) - 0.008
    spine = [(0.0, 0.012 + (top - 0.012) * i / 8) for i in range(9)]
    kit.plate(mask.strip(spine, 0.013, 0.004), hi=0.0040, chamfer=0.0008, edge_res=0.006)
    kit.plate(mask.strip(spine[:-1], 0.006, 0.002), hi=0.0065, chamfer=0.0006, edge_res=0.006)


def _chin_chevrons(kit: mask.MaskKit) -> None:
    """Nested deco chevrons on the chin under the beak: gold, lacquer, gold."""
    for (half_u, top_v, tip_v), width, hi, mat in (((0.044, -0.060, -0.090), 0.008, 0.0030, "primary"),
                                                   ((0.040, -0.072, -0.100), 0.004, 0.0012, "accent"),
                                                   ((0.036, -0.081, -0.109), 0.007, 0.0024, "primary")):
        pts = [(-half_u, top_v), (-half_u * 0.5, (top_v + tip_v) * 0.5), (0.0, tip_v),
               (half_u * 0.5, (top_v + tip_v) * 0.5), (half_u, top_v)]
        kit.plate(mask.strip(pts, width, width * 0.6), hi=hi, chamfer=0.0006 if width > 0.005 else 0.0004,
                  mat=mat, edge_res=0.006)


def _beak(kit: mask.MaskKit) -> None:
    """Faceted dagger beak (8-sided section) lofted from inside the shell to a point."""
    p = kit.params
    surf = kit.surf
    tip = Vector(p["beak_tip"])
    rt, rb, w0 = float(p["beak_root_top"]), float(p["beak_root_bottom"]), float(p["beak_half_width"])
    t = float(p["thickness"])

    def profile(s: float) -> list[tuple[float, float]]:
        zt = _lerp(rt, tip.z, s) + 0.008 * math.sin(math.pi * s)
        zb = _lerp(rb, tip.z, s) - 0.003 * math.sin(math.pi * s)
        h = zt - zb
        w = w0 * (1 - s) ** 0.8
        return [(0.0, zt), (-0.5 * w, zt - 0.10 * h), (-w, zt - 0.42 * h), (-0.72 * w, zb + 0.18 * h),
                (0.0, zb), (0.72 * w, zb + 0.18 * h), (w, zt - 0.42 * h), (0.5 * w, zt - 0.10 * h)]

    root = profile(0.0)
    y_root = [surf.depth_at(x, z) - 0.5 * t for x, z in root]
    n = 14
    sections = []
    for k in range(n):
        s = k / n
        sec = []
        for i, (x, z) in enumerate(profile(s)):
            sec.append(Vector((x, _lerp(y_root[i], tip.y, s), z)))
        sections.append(sec)
    faces = kit.loft(sections, tip=tip, cap_start=False)  # open root, hidden inside the shell
    # two-tone: the two keel facets (section edges 3->4 and 4->5) in dark lacquer: a deco gape line
    accent = kit.mat("accent")
    for k in range(len(sections)):  # last k = the tip fan
        for i in (3, 4):
            faces[k * 8 + i].material_index = accent


def build(ctx) -> None:
    mats = mask.materials(ctx)
    mask.build_mask(ctx, ctx.params, mats,
                    ornaments=[_eye_stripes, _brow_feathers, _cheek_feathers, _crest, _chin_chevrons, _beak])
