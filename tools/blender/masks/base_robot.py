"""Robot customisable base mask (``mask_base.robot``, D3-03).

An original robot face plate: a boxy, flat-fronted shell with squared corners, split into raised
panels (a forehead plate, two cheek plates and a chin plate) held by rivets, two lens eyes (a
stepped barrel standing out of the face round each eye hole, with an inner iris ring), a grille
mouth of six vertical slots in a raised frame, a cylindrical "ear" housing with a ribbed cap on
each side of the head, and a short antenna with a ball tip on top. Square outline, side housings
and antenna make a mechanical silhouette quite unlike the organic bases.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_robot"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "side_arc": 0.100,
    "brow": 0.0,
    "cheek": 0.0,
    "nose": 0.0,
    "jaw": 0.2,
    "eye_shape": "round",
    "eye_width": 0.025,
    "eye_height": 0.025,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "face_half_width": 0.086,
    "wrap_radius": 0.094,
    "res": 0.0090,
    "res_back": 0.016,
    "edge_res": 0.0055,
}

TOP, BOTTOM, HALF_W = 0.098, -0.116, 0.098
GRILLE_V = -0.074
SLOTS = [(-0.0175 + 0.007 * k) for k in range(6)]
EAR = (0.099, 0.004)


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # flatten the front: cancel most of the head's horizontal curve inside the front panel
    a = au / 0.094
    f += 0.80 * 0.094 * (1 - math.cos(min(a, 0.80))) * (1 - _smooth(0.060, 0.096, au) * 0.6)
    # square forehead: cancel the backward fall of the brow
    f += 0.75 * 3.2 * max(0.0, v - 0.02) ** 2
    # a flat seat round each lens
    f += 0.0040 * _g(math.hypot(au - 0.034, v), 0.022)
    return f


def _rrect(cu: float, cv: float, hw: float, hh: float, p: float = 5.0, n: int = 48) -> mask.Loop2:
    return mask.superellipse(cu, cv, hw, hh, hh, p, n=n)


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    box = mask.superellipse(0.0, (TOP + BOTTOM) * 0.5, HALF_W, (TOP - BOTTOM) * 0.5, (TOP - BOTTOM) * 0.5, 4.5,
                            n=200)
    # the lower corners chamfered in toward the chin
    return [(u * (1 - 0.18 * max(0.0, (-0.04 - v) / 0.076) ** 2), v) for u, v in box]


def _holes(shape: mask.MaskShape) -> list[mask.Loop2]:
    return [_rrect(u, GRILLE_V, 0.0022, 0.0125, 3.0, n=16) for u in SLOTS]


def _rivet(kit: mask.MaskKit, u: float, v: float) -> None:
    kit.plate(mask.disc(u, v, 0.0024, 8), hi=0.0052, chamfer=0.0011, res=0.03, edge_res=0.005)


def _panels(kit: mask.MaskKit) -> None:
    """Forehead, cheek and chin plates with a rivet in each corner."""
    kit.plate(_rrect(0.0, 0.058, 0.074, 0.026), hi=0.0026, chamfer=0.0010, edge_res=0.006)
    for su in (-0.064, 0.064):
        for sv in (0.040, 0.076):
            _rivet(kit, su, sv)
    cheek = _rrect(0.070, -0.040, 0.020, 0.030, 4.0)
    for loop in mask.mirrored(cheek):
        kit.plate(loop, hi=0.0026, chamfer=0.0010, edge_res=0.006)
    for sv in (-0.018, -0.062):
        for loop in mask.mirrored(mask.disc(0.070, sv, 0.0024, 8)):
            kit.plate(loop, hi=0.0052, chamfer=0.0011, res=0.03, edge_res=0.005)
    kit.plate(_rrect(0.0, -0.104, 0.034, 0.008, 4.0), hi=0.0024, chamfer=0.0009, edge_res=0.006)


def _grille(kit: mask.MaskKit) -> None:
    """A raised frame round the grille slots, and a bar between each pair of slots."""
    frame = _rrect(0.0, GRILLE_V, 0.030, 0.019, 4.0)
    inner = _rrect(0.0, GRILLE_V, 0.024, 0.0145, 4.0)
    kit.plate(frame, holes=[inner], hi=0.0040, chamfer=0.0012, edge_res=0.005)


def _lenses(kit: mask.MaskKit) -> None:
    """A stepped lens barrel round each eye hole (open bore) with an iris ring inside."""
    r = float(kit.params["eye_width"]) * 0.5
    prof = [(r + 0.0015, -0.004), (r + 0.0085, -0.004), (r + 0.0085, 0.004), (r + 0.0070, 0.0055),
            (r + 0.0050, 0.0055), (r + 0.0050, 0.0120), (r + 0.0040, 0.0135), (r + 0.0012, 0.0135),
            (r + 0.0012, 0.0085), (r - 0.0030, 0.0085), (r - 0.0030, 0.0065), (r + 0.0012, 0.0065),
            (r + 0.0012, -0.004)]
    for side in (1, -1):
        u = side * kit.surf.eye_u
        c = kit.surf.point(u, 0.0, 0.0)
        axis = (kit.surf.normal(u, 0.0) + Vector((0.0, 1.5, 0.0))).normalized()
        mask.lathe(kit.mb, c, axis, prof, kit.mat("primary"), n=24)


def _ears(kit: mask.MaskKit) -> None:
    """A cylindrical housing on each side with a ribbed cap."""
    prof = [(0.0, -0.004), (0.0170, -0.004), (0.0170, 0.0060), (0.0150, 0.0070), (0.0150, 0.0085),
            (0.0165, 0.0095), (0.0150, 0.0105), (0.0150, 0.0120), (0.0165, 0.0130), (0.0150, 0.0140),
            (0.0120, 0.0160), (0.0050, 0.0160), (0.0050, 0.0200), (0.0035, 0.0215), (0.0, 0.0215)]
    for side in (1, -1):
        u, v = side * EAR[0], EAR[1]
        c = kit.surf.point(u, v, -0.002)
        axis = (Vector((float(side), 0.0, 0.0)) * 1.0 + kit.surf.normal(u, v) * 0.4).normalized()
        mask.lathe(kit.mb, c, axis, prof, kit.mat("primary"), n=20)


def _antenna(kit: mask.MaskKit) -> None:
    """A short antenna on a round base, with a ball tip."""
    v = TOP - 0.010
    c = kit.surf.point(0.0, v, -0.002)
    up = Vector((0.0, -0.15, 1.0)).normalized()
    m = kit.mat("primary")
    mask.lathe(kit.mb, c, up, [(0.0, -0.002), (0.0110, -0.002), (0.0110, 0.0040), (0.0085, 0.0060),
                               (0.0026, 0.0060), (0.0022, 0.0300), (0.0, 0.0300)], m, n=14)
    mask.sphere(kit.mb, c + up * 0.0330, 0.0058, m, n=12, rings=6, axis=up)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_panels, _grille, _lenses, _ears, _antenna],
                    surface_extra=_sculpt, outline_fn=_outline, holes_fn=_holes, uv_mode="front")
