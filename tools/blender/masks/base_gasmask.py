"""Gas mask customisable base mask (``mask_base.gasmask``, "Filter Face", B4-15).

A full-face respirator: a rounded rubber face piece edged by a thick, soft face seal, a moulded
nose cup bulging forward under a seam, two large round eyepieces (a stepped bezel ring standing
proud of the face around a slightly domed lens), a ribbed filter canister screwed onto the front
of the nose cup and angled down (the single filter), a pair of exhalation valves on the cheeks
and four strap stubs standing out of the sides, each with a harness buckle. The only mask in the
set that pushes far forward of the face; the pivot stays at the face centre (the canister is the
front-most point, on the centreline).

Everything (lenses included) is the one ``M_char_mask_base`` slot (masks.md: one surface,
material_override). UV0: front planar projection normalised to the mask bounds
(``_mask_base.front_project``). Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot
-Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_gasmask"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.100,
    "bottom": -0.118,
    "side_arc": 0.112,
    "jaw_taper": 0.30,
    "brow": 0.2,
    "cheek": 0.3,
    "nose": 0.0,
    "jaw": 0.6,
    "eye_shape": "round",
    "eye_width": 0.040,
    "eye_height": 0.040,
    "eye_spacing": 0.076,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "face_half_width": 0.088,
    "wrap_radius": 0.100,
    "thickness": 0.006,
    "chamfer": 0.0020,
    "res": 0.0100,
    "res_back": 0.016,
    "edge_res": 0.0065,
}

EYE_U = 0.038
CUP_V = -0.056       # centre of the nose cup / canister mount
CANISTER_TILT = 22.0  # degrees, nose of the canister pointing down
VALVE = (0.054, -0.074)
# strap stubs standing out of the sides: (centre u, centre v, half length, half width, rotation deg)
STUBS = [(0.112, 0.042, 0.025, 0.0100, -14.0), (0.102, -0.046, 0.025, 0.0095, 24.0)]


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # nose cup: the lower face pushed well forward
    f += 0.026 * _g(au, 0.042) * _g(v - CUP_V, 0.032)
    # flat seats for the eyepieces (no sockets on a respirator)
    f += 0.0055 * _g(math.hypot(au - EYE_U, v), 0.026)
    # the strap stubs stand out flat instead of following the head round
    f += 0.55 * max(0.0, au - 0.094) ** 1.15
    # cheeks fill out toward the valves
    f += 0.0040 * _g(au - 0.054, 0.020) * _g(v + 0.070, 0.020)
    return f


def _rot(loop: mask.Loop2, cu: float, cv: float, deg: float) -> mask.Loop2:
    ca, sa = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [(cu + x * ca - y * sa, cv + x * sa + y * ca) for x, y in loop]


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    parts = [shape.outline()]
    for cu, cv, hl, hw, deg in STUBS:
        t = _rot(mask.superellipse(0.0, 0.0, hl, hw, hw, 3.4, n=40), cu, cv, deg)
        parts += [t, mask.mirror(t)]
    return mask.radial_union(parts, centre=(0.0, -0.006), n=400)


def _seal(kit: mask.MaskKit) -> None:
    """Thick rubber face seal all round the edge."""
    outline = mask.resample(mask.oriented(kit.shape.outline(), True), 0.0055)
    outer = mask.offset_loop(outline, 0.0018)
    inner = mask.offset_loop(outline, 0.0125)
    kit.plate(outer, holes=[inner], hi=0.0055, chamfer=0.0022, edge_res=0.0055)


def _cup_seam(kit: mask.MaskKit) -> None:
    """Moulded seam framing the nose cup: a U from under one eyepiece round to the other."""
    pts = []
    for k in range(17):
        a = math.pi * (1.10 + 0.80 * k / 16)
        pts.append((0.058 * math.cos(a), CUP_V + 0.012 + 0.052 * math.sin(a)))
    kit.plate(mask.resample(mask.strip(pts, 0.0050, 0.0050), 0.0045), hi=0.0022, chamfer=0.0008,
              edge_res=0.0045)


def _axis_at(kit: mask.MaskKit, u: float, v: float, forward: float) -> Vector:
    """Skin normal at (u, v) pulled toward +Y by ``forward`` (0 = pure normal)."""
    n = kit.surf.normal(u, v)
    return (n + Vector((0.0, forward, 0.0))).normalized()


def _eyepieces(kit: mask.MaskKit) -> None:
    """Stepped bezel ring with a recessed, slightly domed lens over each eye hole."""
    prof = [(0.0, -0.0035), (0.0300, -0.0040), (0.0300, 0.0030), (0.0285, 0.0042), (0.0262, 0.0046),
            (0.0262, 0.0108), (0.0250, 0.0122), (0.0212, 0.0122), (0.0212, 0.0072), (0.0140, 0.0084),
            (0.0, 0.0090)]
    for side in (1, -1):
        c = kit.surf.point(side * EYE_U, 0.0, 0.0)
        mask.lathe(kit.mb, c, _axis_at(kit, side * EYE_U, 0.0, 0.6), prof, kit.mat("primary"), n=30)


def _canister(kit: mask.MaskKit) -> None:
    """Ribbed filter canister on a threaded port, angled down from the nose cup."""
    t = math.radians(CANISTER_TILT)
    axis = Vector((0.0, math.cos(t), -math.sin(t)))
    c = kit.surf.point(0.0, CUP_V, -0.004)
    prof = [(0.0, -0.002), (0.0215, -0.002), (0.0215, 0.010), (0.0245, 0.0115), (0.0245, 0.016),
            (0.0215, 0.0175), (0.0215, 0.020), (0.0300, 0.0215), (0.0325, 0.0240)]
    a = 0.0240
    for _k in range(3):  # ribs: a groove then a land
        prof += [(0.0325, a + 0.0045), (0.0308, a + 0.0055), (0.0308, a + 0.0075), (0.0325, a + 0.0085)]
        a += 0.0085
    prof += [(0.0325, a + 0.0040), (0.0300, a + 0.0068), (0.0245, a + 0.0068), (0.0225, a + 0.0040),
             (0.0100, a + 0.0040), (0.0100, a + 0.0072), (0.0080, a + 0.0085), (0.0, a + 0.0088)]
    mask.lathe(kit.mb, c, axis, prof, kit.mat("primary"), n=28)


def _valves(kit: mask.MaskKit) -> None:
    """Exhalation valve on each cheek: a short housing with a stepped cap."""
    prof = [(0.0, -0.003), (0.0150, -0.003), (0.0150, 0.0070), (0.0138, 0.0082), (0.0118, 0.0082),
            (0.0118, 0.0110), (0.0106, 0.0124), (0.0060, 0.0124), (0.0060, 0.0110), (0.0, 0.0110)]
    for side in (1, -1):
        u, v = side * VALVE[0], VALVE[1]
        c = kit.surf.point(u, v, 0.0)
        mask.lathe(kit.mb, c, _axis_at(kit, u, v, 0.25), prof, kit.mat("primary"), n=18)


def _buckles(kit: mask.MaskKit) -> None:
    """Four harness buckles where the strap stubs leave the seal: rounded tabs with a strap slot."""
    for cu, cv, _hl, _hw, deg in STUBS:
        bu, bv = cu - 0.010 * math.cos(math.radians(deg)), cv - 0.010 * math.sin(math.radians(deg))
        tab = _rot(mask.superellipse(0.0, 0.0, 0.0085, 0.0135, 0.0135, 3.0, n=32), bu, bv, deg)
        slot = _rot(mask.superellipse(0.0025, 0.0, 0.0018, 0.0085, 0.0085, 3.0, n=20), bu, bv, deg)
        for o, h in ((tab, slot), (mask.mirror(tab), mask.mirror(slot))):
            kit.plate(o, holes=[h], hi=0.0085, chamfer=0.0012, edge_res=0.0045)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_seal, _cup_seam, _buckles, _eyepieces, _valves, _canister],
                    surface_extra=_sculpt, outline_fn=_outline, uv_mode="front")
