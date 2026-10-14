"""Signal customisable base mask (``mask_base.signal``, D-111).

An original piece of salvaged tech: a smooth, rounded faceplate cut by panel seams, a speaker-grille
mouth (a recessed panel crossed by horizontal bars), a plain round left eye and, on the right eye, a
raised lens ring with a short barrel (a camera eye) that is the face's focal point; a small dish
antenna on a stalk rises from the right temple, and a stubby whip aerial from the left side of the
brow. Deliberately lopsided: the only asymmetric outline in the set (``test_masks`` allows it a wider
centring tolerance), a robot that was patched together rather than designed.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward. "Left"/"right" are
the wearer's: Blender +X = left, -X = right.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_signal"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.100,
    "bottom": -0.110,
    "chin_point": 0.0,
    "side_arc": 0.100,
    "jaw_taper": 0.30,
    "brow": 0.5,
    "cheek": 0.5,
    "nose": 0.3,
    "jaw": 0.5,
    "eye_shape": "round",
    "eye_width": 0.024,
    "eye_height": 0.0240,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "res": 0.0085,
    "res_back": 0.016,
    "edge_res": 0.0050,
}

GRILLE = (0.0, -0.070, 0.034, 0.016)   # (u, v) centre and half extents of the speaker panel


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _sculpt(u: float, v: float) -> float:
    f = 0.0
    # panel seams: a horizontal seam across the brow, a vertical one down the centre of the lower face
    f -= 0.0016 * _g(v - 0.040, 0.0016)
    f -= 0.0016 * _g(u, 0.0016) * (1.0 if v < -0.030 else 0.0)
    # the speaker panel is recessed
    cu, cv, hu, hv = GRILLE
    inside = _g(max(0.0, abs(u - cu) - hu), 0.002) * _g(max(0.0, abs(v - cv) - hv), 0.002)
    f -= 0.0035 * inside
    return f


def _grille(kit: mask.MaskKit) -> None:
    """Horizontal bars across the recessed speaker panel."""
    cu, cv, hu, hv = GRILLE
    for k in range(5):
        v = cv - hv + (k + 0.5) * (2 * hv / 5)
        bar = [(cu - hu + 0.002, v - 0.0016), (cu + hu - 0.002, v - 0.0016), (cu + hu - 0.002, v + 0.0016),
               (cu - hu + 0.002, v + 0.0016)]
        kit.plate(mask.resample(bar, 0.004), hi=0.0006, lo=-0.0040, chamfer=0.0005, edge_res=0.004, res=0.02)


def _camera_eye(kit: mask.MaskKit) -> None:
    """The right eye (Blender -X): a raised lens ring and a short barrel round the opening."""
    surf = kit.surf
    eye = mask.oriented(kit.shape.eye_hole(-1), True)
    cu = sum(p[0] for p in eye) / len(eye)
    cv = sum(p[1] for p in eye) / len(eye)
    ring = mask.disc(cu, cv, 0.0215, 28)
    kit.plate(mask.oriented(ring, True), hi=0.0040, chamfer=0.0012, edge_res=0.003,
              holes=[mask.oriented(mask.disc(cu, cv, 0.0135, 24), False)])
    c = surf.point(cu, cv, 0.0030)
    nrm = surf.normal(cu, cv)
    prof = [(0.0140, 0.0), (0.0175, 0.0), (0.0175, 0.008), (0.0160, 0.011), (0.0140, 0.011)]
    mask.lathe(kit.mb, c, nrm, prof, kit.mat("primary"), n=24)


def _plain_eye(kit: mask.MaskKit) -> None:
    """The left eye (Blender +X): a thin bevelled rim."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    kit.plate(mask.offset_loop(eye, -0.0040), hi=0.0014, chamfer=0.0006, edge_res=0.003,
              holes=[mask.oriented(mask.offset_loop(eye, -0.0008), False)])


def _dish(kit: mask.MaskKit) -> None:
    """A small dish antenna on a stalk from the right temple, facing forward and out."""
    surf = kit.surf
    u, v = -0.090, 0.040
    p0 = surf.point(u, v, -0.003)
    out = Vector((-1.0, 0.0, 0.0))
    stalk = [p0, p0 + out * 0.014 + Vector((0.0, 0.0, 0.012)), p0 + out * 0.024 + Vector((0.0, 0.004, 0.032))]
    m = kit.mat("primary")
    mask.tube(kit.mb, stalk, lambda s: 0.0038, m, n=8, tip=False)
    c = stalk[-1]
    axis = Vector((-0.45, 0.85, 0.30)).normalized()
    prof = [(0.0, 0.0), (0.009, 0.0008), (0.018, 0.0034), (0.026, 0.0076), (0.031, 0.0108),
            (0.031, 0.0130), (0.026, 0.0100), (0.018, 0.0060), (0.009, 0.0034), (0.0, 0.0026)]
    mask.lathe(kit.mb, c, axis, prof, m, n=20)
    # the feed horn on three thin struts
    tip = c + axis * 0.028
    mask.sphere(kit.mb, tip, 0.0028, m, n=8, rings=4, axis=axis)
    side = axis.cross(Vector((0.0, 0.0, 1.0))).normalized()
    upv = side.cross(axis).normalized()
    for k in range(3):
        a = 2 * math.pi * k / 3
        foot = c + axis * 0.006 + (side * math.cos(a) + upv * math.sin(a)) * 0.024
        mask.tube(kit.mb, [foot, tip], lambda s: 0.0011, m, n=5, tip=False)


def _aerial(kit: mask.MaskKit) -> None:
    """A stubby whip aerial from the left side of the brow, with a ball tip."""
    surf = kit.surf
    u, v = 0.060, 0.074
    p0 = surf.point(u, v, -0.003)
    path = [p0, p0 + Vector((0.006, -0.002, 0.020)), p0 + Vector((0.012, -0.006, 0.044))]
    m = kit.mat("primary")
    base = mask.disc(u, v, 0.0070, 12)
    kit.plate(mask.oriented(base, True), hi=0.0030, chamfer=0.0008, edge_res=0.003)
    mask.tube(kit.mb, path, lambda s: 0.0030 - 0.0010 * s, m, n=8, tip=False)
    mask.sphere(kit.mb, path[-1], 0.0034, m, n=10, rings=5)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_grille, _camera_eye, _plain_eye, _dish, _aerial],
                    surface_extra=_sculpt, uv_mode="front")
