"""Skull customisable base mask (``mask_base.skull``, "Grin Skull", B4-15).

A stylised full-face skull plate: a broad rounded cranium over a narrower mandible (the notch
under the cheekbones is the read at distance), deep round eye sockets with a raised orbital rim
and the eye holes sunk in their floor, an inverted-heart nasal notch cut through the shell,
flaring cheekbones over hollow cheeks, and two rows of teeth in relief on a jutting maxilla,
parted by a bite line (relief only: no gap under the jaw). Forms are broad and simple so colour
pairs and patterns stay readable.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_skull"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.108,
    "bottom": -0.122,
    "side_arc": 0.110,
    "jaw_taper": 0.40,
    "brow": 1.5,
    "cheek": 0.0,
    "nose": 0.0,
    "jaw": 0.9,
    "eye_shape": "round",
    "eye_width": 0.027,
    "eye_height": 0.025,
    "eye_spacing": 0.070,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "face_half_width": 0.092,
    "wrap_radius": 0.098,
    "res": 0.0085,
    "res_back": 0.015,
    "edge_res": 0.0045,
}

EYE_U = 0.035
BITE_V = -0.0855  # the line between the upper and lower teeth
# teeth from the centre outward: (half width, upper height, lower height)
TEETH = [(0.0056, 0.0140, 0.0125), (0.0052, 0.0130, 0.0118), (0.0047, 0.0116, 0.0106), (0.0042, 0.0100, 0.0094)]
REFINE = [
    (EYE_U, 0.002, 0.036, 0.034, 0.0036),    # right orbit
    (-EYE_U, 0.002, 0.036, 0.034, 0.0036),   # left orbit
    (0.0, -0.034, 0.016, 0.024, 0.0040),     # nasal cavity
]


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # deep orbit: a bowl around each eye, the hole in its floor, a raised orbital rim around it
    d = math.hypot((au - EYE_U) * 0.88, (v - 0.002) * 0.95)
    f -= 0.0140 * _g(d, 0.020)
    f += 0.0032 * _g(d - 0.026, 0.0060)
    # nasal bone between the orbits, and the shallow pit around the nasal cavity
    f += 0.0040 * _g(au, 0.009) * _smooth(-0.022, -0.008, v) * _smooth(0.024, 0.010, v)
    f -= 0.0035 * _g(au, 0.016) * _g(v + 0.036, 0.014)
    # cheekbones (zygomatic arch) flaring sideways, hollow cheeks under them
    f += 0.0095 * _g(au - 0.062, 0.024) * _g(v + 0.030, 0.011)
    f -= 0.0090 * _g(au - 0.052, 0.015) * _g(v + 0.062, 0.016)
    # jutting maxilla / mandible carrying the teeth
    f += 0.0080 * _g(au, 0.036) * _g(v - BITE_V, 0.022)
    # temples sink back
    f -= 0.0045 * _g(au - 0.090, 0.016) * _g(v - 0.030, 0.030)
    # bite line between the two rows
    f -= 0.0016 * _g(au, 0.042) * _g(v - BITE_V, 0.0018)
    return f


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    cranium = mask.superellipse(0.0, 0.0, 0.112, 0.108, 0.046, 2.3, n=180, p_bottom=2.2)
    cheek = mask.superellipse(0.088, -0.028, 0.026, 0.012, 0.014, 2.2, n=40)
    jaw = mask.superellipse(0.0, -0.064, 0.060, 0.044, 0.058, 3.2, n=140, p_bottom=2.6)
    return mask.radial_union([cranium, cheek, mask.mirror(cheek), jaw], centre=(0.0, -0.012), n=360)


def _nasal(shape: mask.MaskShape) -> list[mask.Loop2]:
    """Inverted-heart nasal cavity: pointed at the top, two lobes at the bottom."""
    pts = [(0.0, -0.016), (0.0070, -0.028), (0.0118, -0.041), (0.0086, -0.0505),
           (0.0, -0.0465), (-0.0086, -0.0505), (-0.0118, -0.041), (-0.0070, -0.028)]
    return [mask.spline_loop(pts, samples=5, sharp=(0, 4))]


def _rrect(cu: float, cv: float, hw: float, hh: float) -> mask.Loop2:
    return mask.superellipse(cu, cv, hw, hh, hh, 3.6, n=28)


def _teeth(kit: mask.MaskKit) -> None:
    """Two rows of teeth in relief, parted at the bite line, sized down toward the corners."""
    gap = 0.0011
    u = 0.0
    for k, (hw, up_h, lo_h) in enumerate(TEETH):
        cu = u + hw + (gap * 0.5 if k == 0 else gap)
        u = cu + hw
        lift = 0.008 * (cu / 0.040) ** 2  # the row curves up toward the corners
        top = _rrect(cu, BITE_V + gap + up_h * 0.5 + lift, hw, up_h * 0.5)
        bot = _rrect(cu, BITE_V - gap - lo_h * 0.5 + lift, hw, lo_h * 0.5)
        for t in (top, bot):
            for loop in mask.mirrored(t):
                kit.plate(loop, hi=0.0024, chamfer=0.0009, edge_res=0.0022)


def _socket_floor(kit: mask.MaskKit) -> None:
    """A thin lip on each eye hole, so the hole reads as sunk inside the orbit."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0008)
    outer = mask.offset_loop(eye, -0.0040)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0012, chamfer=0.0005, edge_res=0.0035)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_socket_floor, _teeth],
                    surface_extra=_sculpt, outline_fn=_outline, holes_fn=_nasal, uv_mode="front",
                    refine=REFINE)
