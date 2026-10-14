"""Shark customisable base mask (``mask_base.shark``, D-111).

An original shark: a long, rounded snout lofted forward from the brow and the cheeks to a blunt
point, small round eyes set wide on the sides of the head, three gill slits cut into each cheek,
a wide crescent mouth under the snout with a row of triangular teeth along each lip, and a swept
dorsal fin rising from the top of the forehead. The forward wedge of the snout with the fin above
is the read at distance.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_shark"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.100,
    "bottom": -0.112,
    "chin_point": 0.0,
    "side_arc": 0.100,
    "jaw_taper": 0.42,
    "brow": 0.5,
    "cheek": 0.4,
    "nose": 0.0,
    "jaw": 0.6,
    "eye_shape": "round",
    "eye_width": 0.022,
    "eye_height": 0.0180,
    "eye_spacing": 0.100,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "res": 0.0090,
    "res_back": 0.016,
    "edge_res": 0.0050,
}

SNOUT_TIP = (0.0, 0.108, -0.020)   # Blender (x, y, z) of the snout's point
SNOUT_ROOT = (0.0, -0.020)          # (u, v) centre of the snout's root on the face
SNOUT_HALF = (0.022, 0.024)         # root half width / half height
MOUTH_V = -0.074                    # mouth centre line
MOUTH_HALF = 0.032                  # half width of the mouth
FIN = [(0.006, 0.084), (0.010, 0.104), (-0.022, 0.176), (-0.034, 0.180), (-0.038, 0.164), (-0.044, 0.110), (-0.040, 0.088)]


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # three gill slits on each cheek: narrow grooves slanting down and back
    for k in range(3):
        c = 0.058 + 0.010 * k
        d = (au - c) - 0.18 * (v + 0.050)
        f -= 0.0030 * _g(d, 0.0016) * _smooth(-0.085, -0.070, v) * _smooth(-0.020, -0.034, v)
    # the head: a broad wedge pushing the centre of the face forward toward the snout, flattest on top
    f += 0.050 * _g(au, 0.034 + 0.012 * _smooth(-0.020, 0.060, v)) * _g(v + 0.020, 0.050)
    # a soft ridge running from the snout root up over the brow
    f += 0.004 * _g(au, 0.018) * _smooth(-0.010, 0.020, v) * _smooth(0.090, 0.060, v)
    return f


def _mouth_hole(shape: mask.MaskShape) -> list[mask.Loop2]:
    """A crescent mouth: wide, the corners turned down."""
    top, bot = [], []
    for k in range(25):
        t = -1.0 + 2.0 * k / 24
        u = MOUTH_HALF * t
        top.append((u, MOUTH_V + 0.004 - 0.010 * t * t))
        bot.append((u, MOUTH_V - 0.008 - 0.004 * t * t))
    loop = top + list(reversed(bot))
    return [mask.oriented(mask.resample(loop, 0.003), False)]


def _teeth(kit: mask.MaskKit) -> None:
    """A row of triangular teeth along each lip, pointing into the mouth."""
    for k in range(9):
        t = -0.85 + 1.7 * k / 8
        u = MOUTH_HALF * t
        ytop = MOUTH_V + 0.004 - 0.010 * t * t
        kit.plate([(u - 0.0032, ytop + 0.002), (u + 0.0032, ytop + 0.002), (u, ytop - 0.0062)], hi=0.0016,
                  lo=-0.0010, chamfer=0.0004, edge_res=0.003, res=0.02)
    for k in range(8):
        t = -0.78 + 1.56 * k / 7
        u = MOUTH_HALF * t
        ybot = MOUTH_V - 0.008 - 0.004 * t * t
        kit.plate([(u - 0.0030, ybot - 0.002), (u, ybot + 0.0058), (u + 0.0030, ybot - 0.002)], hi=0.0016,
                  lo=-0.0010, chamfer=0.0004, edge_res=0.003, res=0.02)


def _snout(kit: mask.MaskKit) -> None:
    """The snout: a rounded loft from an ellipse sunk in the shell to a blunt point."""
    surf = kit.surf
    t = float(kit.params["thickness"])
    tip = Vector(SNOUT_TIP)
    cu, cv = SNOUT_ROOT
    a, b = SNOUT_HALF
    n, rows = 16, 12
    ring0 = []
    for j in range(n):
        ang = 2 * math.pi * j / n
        u, v = cu + a * math.cos(ang), cv + b * math.sin(ang)
        ring0.append(surf.point(u, v, -0.5 * t))
    c0 = sum(ring0, Vector()) / n
    sections = []
    for k in range(rows):
        s = k / rows
        # the snout stays round and full, then rounds off quickly toward the point
        shrink = math.cos(0.5 * math.pi * s ** 1.6)
        centre = c0.lerp(tip, s)
        centre.z += 0.006 * math.sin(math.pi * s)
        sec = []
        for q in ring0:
            d = q - c0
            sec.append(Vector((centre.x + d.x * shrink, centre.y + d.y * shrink * 0.3, centre.z + d.z * shrink * 0.9)))
        sections.append(sec)
    kit.loft(sections, tip=tip, cap_start=False)


def _fin(kit: mask.MaskKit) -> None:
    """The dorsal fin: a thin swept plate in the centre plane, rooted in the top of the shell."""
    surf = kit.surf
    t = float(kit.params["thickness"])
    y0 = surf.depth_at(0.0, 0.094) - t
    half = 0.0045
    poly = [Vector((0.0, y0 + dy, z)) for dy, z in FIN]
    sections = [[p + Vector((-half, 0.0, 0.0)) for p in poly], [p + Vector((half, 0.0, 0.0)) for p in poly]]
    kit.loft(sections)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_snout, _teeth, _fin],
                    surface_extra=_sculpt, holes_fn=_mouth_hole, uv_mode="front",
                    refine=[(0.0, -0.060, 0.090, 0.040, 0.0040)])
