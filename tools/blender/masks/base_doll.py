"""Doll customisable base mask (``mask_base.doll``, D3-03).

An original porcelain doll face: a round, smooth, baby-cheeked face with a high forehead, a
scalloped fringe of sculpted curls across the top, a ringlet hanging at each temple, large round
eyes with painted-on upper lashes and short lower lashes in relief, a small button nose, softly
raised round "rouge" discs on the cheeks, and a tiny closed rosebud mouth. ``crack`` (on by
default) cuts a fine jagged crack from the fringe down across the right brow and cheek, the
porcelain's tell. Round face and ringlets make a soft, wide silhouette.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_doll"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.108,
    "bottom": -0.108,
    "side_arc": 0.106,
    "jaw_taper": 0.30,
    "brow": 0.4,
    "cheek": 1.7,
    "nose": 0.30,
    "jaw": 0.7,
    "eye_shape": "round",
    "eye_width": 0.031,
    "eye_height": 0.027,
    "eye_spacing": 0.072,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "mouth_v": -0.066,
    "face_half_width": 0.086,
    "res": 0.0085,
    "res_back": 0.015,
    "edge_res": 0.0050,
    # the crack: a fine jagged groove (u, v) polyline; set "crack": False for an unbroken face
    "crack": True,
}

CRACK = [(0.030, 0.100), (0.036, 0.080), (0.030, 0.066), (0.042, 0.046), (0.038, 0.032), (0.052, 0.022),
         (0.060, -0.024), (0.054, -0.040), (0.066, -0.058), (0.062, -0.074)]
CRACK_BRANCH = [(0.042, 0.046), (0.058, 0.054), (0.066, 0.050)]
RINGLET = (0.100, -0.012)
REFINE = [(0.0, -0.064, 0.020, 0.012, 0.0035), (0.038, 0.064, 0.016, 0.040, 0.0026),
          (0.057, -0.026, 0.014, 0.054, 0.0026)]


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _seg(u: float, v: float, a: tuple[float, float], b: tuple[float, float]) -> float:
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((u - a[0]) * dx + (v - a[1]) * dy) / (dx * dx + dy * dy)))
    return math.hypot(u - a[0] - t * dx, v - a[1] - t * dy)


def _crack_dist(u: float, v: float) -> float:
    d = 1.0
    for line in (CRACK, CRACK_BRANCH):
        for a, b in zip(line, line[1:]):
            d = min(d, _seg(u, v, a, b))
    return d


def _sculpt_fn(crack: bool):
    def sculpt(u: float, v: float) -> float:
        au = abs(u)
        f = 0.0
        # a high, round forehead
        f += 0.0045 * _g(au, 0.06) * _g(v - 0.060, 0.035)
        # plump baby cheeks low on the face
        f += 0.0060 * _g(au - 0.046, 0.022) * _g(v + 0.046, 0.020)
        # a tiny chin pad under the mouth
        f += 0.0030 * _g(au, 0.014) * _g(v + 0.088, 0.010)
        if crack and u > 0.0:
            f -= 0.0024 * _g(_crack_dist(u, v), 0.0017)
        return f
    return sculpt


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    parts = [shape.outline()]
    for side in (1, -1):
        cu, cv = side * RINGLET[0], RINGLET[1]
        parts.append(mask.superellipse(cu, cv, 0.014, 0.030, 0.034, 2.0, n=40))
    return mask.radial_union(parts, centre=(0.0, -0.004), n=400)


def _fringe(kit: mask.MaskKit) -> None:
    """Scalloped fringe of curls across the top, each curl with a raised swirl."""
    top = float(kit.params["top"])
    n = 7
    w = 0.150 / n
    for k in range(n):
        cu = -0.075 + w * (k + 0.5)
        cv = top - 0.024 - 0.020 * (cu / 0.075) ** 2
        curl = mask.superellipse(cu, cv, w * 0.62, 0.017, 0.012, 2.2, n=20)
        kit.plate(curl, hi=0.0040, chamfer=0.0016, edge_res=0.005, res=0.02)
        swirl = mask.leaf((cu - w * 0.30, cv + 0.004), (cu + w * 0.25, cv - 0.004), 0.0050, bend=0.25, n=6)
        kit.plate(swirl, hi=0.0058, chamfer=0.0008, edge_res=0.004, res=0.02)


def _ringlets(kit: mask.MaskKit) -> None:
    """A ringlet at each temple: three stacked rolls."""
    for k in range(3):
        cv = RINGLET[1] + 0.020 - 0.019 * k
        roll = mask.superellipse(RINGLET[0] - 0.002, cv, 0.0120 - 0.001 * k, 0.0085, 0.0085, 2.0, n=16)
        for loop in mask.mirrored(roll):
            kit.plate(loop, hi=0.0040, chamfer=0.0016, edge_res=0.005, res=0.02)


def _lashes(kit: mask.MaskKit) -> None:
    """Painted lashes in relief: a lid line with five upper lashes, three short lower lashes."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    cu, cv = kit.surf.eye_u, kit.surf.eye_v
    rw, rh = float(kit.params["eye_width"]) * 0.5, float(kit.params["eye_height"]) * 0.5
    inner = mask.offset_loop(eye, -0.0008)
    outer = mask.offset_loop(eye, -0.0034)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0016, chamfer=0.0006, edge_res=0.004)
    for k in range(5):
        a = math.radians(150 - 25 * k)
        r0 = (cu + (rw + 0.002) * math.cos(a), cv + (rh + 0.002) * math.sin(a))
        r1 = (cu + (rw + 0.0105) * math.cos(a - 0.12), cv + (rh + 0.0095) * math.sin(a - 0.12))
        for loop in mask.mirrored(mask.leaf(r0, r1, 0.0030, bend=0.10, n=5, fullness=0.4, root_round=0.8)):
            kit.plate(loop, hi=0.0016, chamfer=0.0005, edge_res=0.003, res=0.02)
    for k in range(3):
        a = math.radians(-120 + 30 * k)
        r0 = (cu + (rw + 0.002) * math.cos(a), cv + (rh + 0.002) * math.sin(a))
        r1 = (cu + (rw + 0.0065) * math.cos(a), cv + (rh + 0.0060) * math.sin(a))
        for loop in mask.mirrored(mask.leaf(r0, r1, 0.0022, n=4, fullness=0.4, root_round=0.8)):
            kit.plate(loop, hi=0.0012, chamfer=0.0004, edge_res=0.003, res=0.02)


def _rouge(kit: mask.MaskKit) -> None:
    """Round painted cheek discs, barely raised, and a button nose tip."""
    for loop in mask.mirrored(mask.disc(0.050, -0.042, 0.016, 28)):
        kit.plate(loop, hi=0.0007, chamfer=0.0005, edge_res=0.004)
    kit.plate(mask.superellipse(0.0, -0.040, 0.0075, 0.0055, 0.0050, 2.0, n=16), hi=0.0030, chamfer=0.0014,
              edge_res=0.003)


def _lips(kit: mask.MaskKit) -> None:
    """Rosebud lips: a bow-shaped upper lip and a rounder lower lip."""
    mv = float(kit.params["mouth_v"])
    up = mask.spline_loop([(-0.011, mv + 0.0005), (-0.0055, mv + 0.0058), (0.0, mv + 0.0032), (0.0055, mv + 0.0058),
                           (0.011, mv + 0.0005), (0.0, mv + 0.0012)], samples=5, sharp=(0, 2, 4))
    lo = mask.superellipse(0.0, mv - 0.0032, 0.0090, 0.0028, 0.0032, 2.0, n=20)
    for loop in (up, lo):
        kit.plate(loop, hi=0.0022, chamfer=0.0009, edge_res=0.0025, res=0.02)


def build(ctx) -> None:
    crack = bool(ctx.params.get("crack", True))
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_fringe, _ringlets, _lashes, _rouge, _lips],
                    surface_extra=_sculpt_fn(crack), outline_fn=_outline, uv_mode="front",
                    refine=REFINE if crack else REFINE[:1])
