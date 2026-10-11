"""Demon customisable base mask (``mask_base.demon``, "Horned Fury", B4-15).

An original horned fury (no traditional oni/hannya likeness): a heavy snarling brow knotted down
into a V over narrow, upswept eyes, two short ribbed horns growing out of the brow line and
sweeping up and out, a broad nose with flared nostrils and snarl wrinkles across the bridge, snarl
folds pulling up from the nostrils, and an open snarl whose arched upper lip bares two long fangs
over a row of short teeth, with two small lower fangs. Hard cheekbones and a pointed chin. The
horns are the read at distance.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_demon"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.100,
    "top_peak": 0.012,
    "bottom": -0.122,
    "chin_point": 0.012,
    "side_arc": 0.110,
    "jaw_taper": 0.38,
    "brow": 1.6,
    "cheek": 1.5,
    "nose": 0.55,
    "jaw": 1.2,
    "eye_shape": "almond",
    "eye_width": 0.032,
    "eye_height": 0.0120,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 18.0,
    "mouth": "none",
    "face_half_width": 0.090,
    "wrap_radius": 0.098,
    "res": 0.0085,
    "res_back": 0.015,
    "edge_res": 0.0045,
}

MOUTH_V = -0.076   # the snarl's corners
MOUTH_HW = 0.034
HORN_ROOT = (0.040, 0.066)
REFINE = [(0.0, -0.040, 0.034, 0.022, 0.0040)]  # nostrils and snarl folds


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _seg(u: float, v: float, a: tuple[float, float], b: tuple[float, float]) -> float:
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((u - a[0]) * dx + (v - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.hypot(u - a[0] - t * dx, v - a[1] - t * dy)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # knotted brow: a deep vertical furrow either side of the centre, the glabella bunched forward
    f += 0.0040 * _g(au, 0.007) * _g(v - 0.026, 0.010)
    f -= 0.0030 * _g(au - 0.010, 0.0030) * _g(v - 0.030, 0.012)
    # flared nostrils: round wings with a pit under each
    f += 0.0070 * _g(au - 0.017, 0.0075) * _g(v + 0.042, 0.0070)
    f -= 0.0040 * _g(au - 0.012, 0.0035) * _g(v + 0.049, 0.0030)
    # snarl folds: a ridge from each nostril wing curving down to the mouth corner, a groove outside
    f += 0.0030 * _g(_seg(au, v, (0.024, -0.040), (0.036, -0.068)), 0.0040)
    f -= 0.0022 * _g(_seg(au, v, (0.031, -0.038), (0.044, -0.068)), 0.0030)
    # hard cheekbones
    f += 0.0050 * _g(au - 0.060, 0.016) * _g(v + 0.022, 0.010)
    # the lips pushed forward round the snarl
    f += 0.0035 * _g(au, 0.032) * _g(v - (MOUTH_V + 0.002), 0.020)
    # temples sink back
    f -= 0.0030 * _g(au - 0.086, 0.015) * _g(v - 0.035, 0.030)
    return f


def _snarl() -> mask.Loop2:
    """Open snarl (CCW): the upper lip arched high in the middle, the corners pulled down."""
    m = 18
    upper: mask.Loop2 = []
    lower: mask.Loop2 = []
    for k in range(m + 1):
        s = -1 + 2 * k / m
        upper.append((MOUTH_HW * s, MOUTH_V + 0.017 * (1 - s * s) ** 0.8))
    for k in range(1, m):
        s = 1 - 2 * k / m
        lower.append((MOUTH_HW * 0.92 * s, MOUTH_V - 0.013 * (1 - s * s) ** 0.7))
    return mask.oriented(list(reversed(upper)) + list(reversed(lower)), True)


def _holes(shape: mask.MaskShape) -> list[mask.Loop2]:
    return [_snarl()]


def _solid(kit: mask.MaskKit, loop: mask.Loop2, hi: float) -> None:
    """A closed slab from the shell's inner skin to ``hi`` (teeth that cross the mouth opening)."""
    m = kit.mat("primary")
    t = float(kit.params["thickness"])
    mask.slab(kit.mb, kit.surf, loop, [], -t, hi, 0.0007, m, m, m, 0.006, 0.010, 0.0022, bottom=True)


def _teeth(kit: mask.MaskKit) -> None:
    """Two long upper fangs, short teeth between them and two small lower fangs."""
    top = MOUTH_V + 0.017
    fang = mask.leaf((0.0165, top + 0.004), (0.0175, top - 0.027), 0.0085, bend=0.05, n=8, fullness=0.25,
                     root_round=0.9)
    low = mask.leaf((0.026, MOUTH_V - 0.012), (0.024, MOUTH_V + 0.004), 0.0060, n=6, fullness=0.25,
                    root_round=0.9)
    for loop in mask.mirrored(fang) + mask.mirrored(low):
        _solid(kit, loop, 0.0030)
    for cu in (-0.0058, 0.0058):
        tooth = mask.superellipse(cu, top - 0.0035, 0.0026, 0.0060, 0.0050, 3.0, n=16)
        _solid(kit, tooth, 0.0018)


def _lip(kit: mask.MaskKit) -> None:
    """Rolled lip round the snarl."""
    hole = mask.resample(_snarl(), 0.003)
    kit.plate(mask.offset_loop(hole, -0.0070, max_miter=1.15), holes=[mask.offset_loop(hole, -0.0008)],
              hi=0.0030, chamfer=0.0013, edge_res=0.003)


def _brow(kit: mask.MaskKit) -> None:
    """Heavy snarling brow: two thick blades knotted down into a V over the nose."""
    pts = [(0.011 + 0.079 * t, 0.012 + 0.036 * t - 0.010 * t * t) for t in (k / 10 for k in range(11))]
    blade = mask.strip(pts, 0.0175, 0.0070)
    for loop in mask.mirrored(mask.resample(blade, 0.003)):
        kit.plate(loop, hi=0.0058, chamfer=0.0016, edge_res=0.003)


def _wrinkles(kit: mask.MaskKit) -> None:
    """Snarl wrinkles across the bridge of the nose."""
    for k, v in enumerate((-0.010, -0.018)):
        w = 0.016 - 0.003 * k
        pts = [(w * (2 * i / 8 - 1), v + 0.0035 * (1 - (2 * i / 8 - 1) ** 2)) for i in range(9)]
        kit.plate(mask.resample(mask.strip(pts, 0.0028, 0.0028), 0.0025), hi=0.0016, chamfer=0.0006,
                  edge_res=0.0025)


def _lids(kit: mask.MaskKit) -> None:
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0008)
    outer = mask.offset_loop(eye, -0.0038, max_miter=1.4)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0015, chamfer=0.0005, edge_res=0.003)


def _horns(kit: mask.MaskKit) -> None:
    """Two short ribbed horns growing out of the brow line, sweeping up and out."""
    surf = kit.surf
    n_sec, n_ring = 14, 14
    for side in (1, -1):
        u0, v0 = side * HORN_ROOT[0], HORN_ROOT[1]
        nrm = surf.normal(u0, v0)
        p0 = surf.point(u0, v0, -0.010)
        p1 = p0 + nrm * 0.022 + Vector((side * 0.004, 0.0, 0.004))
        p2 = p0 + Vector((side * 0.050, -0.012, 0.050))

        def bez(s: float, p0: Vector = p0, p1: Vector = p1, p2: Vector = p2) -> Vector:
            return p0 * (1 - s) ** 2 + p1 * 2 * (1 - s) * s + p2 * s * s

        sections = []
        for k in range(n_sec):
            s = k / n_sec
            c = bez(s)
            tan = (bez(min(1.0, s + 0.01)) - bez(max(0.0, s - 0.01))).normalized()
            sx = Vector((1.0, 0.0, 0.0)) * side
            a = (sx - tan * sx.dot(tan)).normalized()
            b = tan.cross(a).normalized()
            r = (0.0160 * (1 - s) ** 0.85 + 0.0012) * (1.0 + 0.06 * math.cos(2 * math.pi * 3.0 * s) * (1 - s))
            r *= 1.0 + 0.12 * max(0.0, 1 - s / 0.25) ** 2  # slightly flared root
            sec = []
            for j in range(n_ring):
                ang = 2 * math.pi * j / n_ring
                sec.append(c + a * (r * math.cos(ang)) + b * (r * 0.85 * math.sin(ang)))
            sections.append(sec)
        kit.loft(sections, tip=p2, cap_start=True)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_lids, _brow, _wrinkles, _lip, _teeth, _horns],
                    surface_extra=_sculpt, holes_fn=_holes, uv_mode="front", refine=REFINE)
