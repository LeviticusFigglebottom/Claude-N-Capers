"""Knight customisable base mask (``mask_base.knight``, D3-03).

An original visor faceplate (no historical helmet replica): a smooth, hard plate whose lower half
is drawn forward into a pointed prow along a sharp centre keel, two narrow vision slits divided by
the keel under a raised brow band studded with rivets, a raised rim round each slit, a strip down
the keel, pierced cross-shaped breathing holes on both sides of the prow, and a low comb running
up the forehead to the top edge. The prow and comb make an angular side silhouette, the slits and
crosses a severe front.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_knight"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.104,
    "bottom": -0.120,
    "chin_point": 0.016,
    "side_arc": 0.106,
    "jaw_taper": 0.30,
    "brow": 0.0,
    "cheek": 0.0,
    "nose": 0.0,
    "jaw": 0.3,
    "eye_shape": "slit",
    "eye_width": 0.046,
    "eye_height": 0.0190,
    "eye_spacing": 0.064,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "face_half_width": 0.084,
    "wrap_radius": 0.092,
    "res": 0.0085,
    "res_back": 0.015,
    "edge_res": 0.0050,
}

BAND = (0.012, 0.024)        # brow band, lower and upper edge (v)
# breathing crosses on the right side of the prow (mirrored): centre (u, v)
CROSSES = [(0.026, -0.040), (0.042, -0.050), (0.030, -0.062), (0.046, -0.074), (0.034, -0.086)]
REFINE = [(0.0, -0.060, 0.010, 0.060, 0.0040)]  # keel crease


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # the prow: the lower plate drawn forward to a sharp keel on the centre line
    k = _smooth(0.004, -0.030, v) * (1 - 0.35 * _smooth(-0.080, -0.125, v))
    f += 0.034 * k * max(0.0, 1 - au / 0.080) ** 1.25
    # a flat, smooth brow (no sockets): fill the eye area back up
    f += 0.0045 * _g(au - 0.032, 0.026) * _g(v, 0.016)
    return f


def _cross(cu: float, cv: float, arm: float = 0.0042, w: float = 0.0016) -> mask.Loop2:
    """Plus-shaped hole (CCW), 12 corners."""
    pts = [(w, w), (w, arm), (-w, arm), (-w, w), (-arm, w), (-arm, -w), (-w, -w), (-w, -arm), (w, -arm),
           (w, -w), (arm, -w), (arm, w)]
    return [(cu + x, cv + y) for x, y in pts]


def _holes(shape: mask.MaskShape) -> list[mask.Loop2]:
    out: list[mask.Loop2] = []
    for cu, cv in CROSSES:
        out += mask.mirrored(_cross(cu, cv))
    return out


def _band(kit: mask.MaskKit) -> None:
    """Raised brow band across the plate, with a row of rivets."""
    a = float(kit.params["side_arc"]) - 0.004
    pts = [(-a + 2 * a * k / 24, BAND[0] + 0.0015 * (1 - (k / 12 - 1) ** 2)) for k in range(25)]
    top = [(x, y + (BAND[1] - BAND[0])) for x, y in reversed(pts)]
    kit.plate(pts + top, hi=0.0032, chamfer=0.0012, edge_res=0.006)
    for k in range(-4, 5):
        if k == 0:
            continue
        u = 0.020 * k
        kit.plate(mask.disc(u, (BAND[0] + BAND[1]) * 0.5 + 0.0007, 0.0024, 8), hi=0.0058, chamfer=0.0010,
                  edge_res=0.005, res=0.03)


def _slit_rims(kit: mask.MaskKit) -> None:
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0008)
    outer = mask.offset_loop(eye, -0.0040, max_miter=1.5)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0022, chamfer=0.0008, edge_res=0.004)


def _keel(kit: mask.MaskKit) -> None:
    """A narrow raised strip down the keel, from between the slits to the chin."""
    pts = [(0.0, -0.002 - 0.118 * k / 12) for k in range(13)]
    kit.plate(mask.resample(mask.strip(pts, 0.0070, 0.0040), 0.005), hi=0.0026, chamfer=0.0010, edge_res=0.005)


def _comb(kit: mask.MaskKit) -> None:
    """A low comb up the centre of the forehead to the top edge (a thin plate standing on the shell)."""
    surf = kit.surf
    t = float(kit.params["thickness"])
    v0, v1 = 0.034, float(kit.params["top"]) - 0.003
    n = 14
    base, top = [], []
    for k in range(n + 1):
        s = k / n
        v = v0 + (v1 - v0) * s
        b = surf.point(0.0, v, -0.5 * t)
        nrm = surf.normal(0.0, v)
        h = 0.0015 + 0.024 * math.sin(0.5 * math.pi * s) ** 1.4
        base.append((b.y, b.z))
        top.append((b.y + nrm.y * h, b.z + nrm.z * h))
    profile = base + list(reversed(top))
    kit.mb.prism(profile, axis="X", start=-0.0026, end=0.0026, mat=kit.mat("primary"))
    # a rounded cap on the comb's leading edge
    p = Vector((0.0, top[0][0], top[0][1]))
    mask.sphere(kit.mb, p, 0.0030, kit.mat("primary"), n=8, rings=4)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_band, _slit_rims, _keel, _comb],
                    surface_extra=_sculpt, holes_fn=_holes, uv_mode="front", refine=REFINE)
