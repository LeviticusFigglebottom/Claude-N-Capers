"""Goalie customisable base mask (``mask_base.goalie``, "Crease Guard", B4-15).

A rigid, moulded sports face guard: a smooth, tall domed shell with a moulded nose and a slight
brow ridge, wide eye holes edged by a thin raised rim, clusters of small round vent holes over the
mouth, the cheeks and the forehead, raised stiffening ribs (one up the centre of the dome, two
sweeping up from the outer brows, two running down between the cheek and mouth vents) and four
strap tabs with slots standing out from the sides. Unlike the bruiser (squared, armoured, slotted
vents) it is round everywhere; the dot clusters, the ribs and the side tabs are its read.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_goalie"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.116,
    "bottom": -0.124,
    "chin_point": 0.0,
    "side_arc": 0.106,
    "jaw_taper": 0.27,
    "brow": 0.5,
    "cheek": 0.9,
    "nose": 0.85,
    "jaw": 1.0,
    "eye_shape": "almond",
    "eye_width": 0.037,
    "eye_height": 0.0175,
    "eye_tilt_deg": 5.0,
    "mouth": "none",
    "face_half_width": 0.090,
    "wrap_radius": 0.100,
    "res": 0.0095,
    "res_back": 0.015,
}

HOLE_R = 0.0029
# (centre u, centre v, half width, half height, rotation deg) of the right-hand strap tabs
TABS = [(0.102, 0.046, 0.018, 0.0110, -12.0), (0.090, -0.058, 0.018, 0.0105, 30.0)]


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # a slight moulded brow ridge running across above the eyes
    f += 0.0024 * _g(v - 0.028, 0.012) * _g(au, 0.052)
    # rounded dome: the forehead held forward so the shell reads as one smooth helmet-like curve
    f += 0.0050 * _g(au, 0.070) * _g(v - 0.080, 0.040)
    # the strap tabs flare out flat instead of following the head round
    f += 0.55 * max(0.0, au - 0.092) ** 1.15
    # a gently pushed-out mouth guard under the nose
    f += 0.0050 * _g(au, 0.034) * _g(v + 0.078, 0.024)
    return f


def _rot(loop: mask.Loop2, cu: float, cv: float, deg: float) -> mask.Loop2:
    ca, sa = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [(cu + x * ca - y * sa, cv + x * sa + y * ca) for x, y in loop]


def _tab(cu: float, cv: float, hw: float, hh: float, deg: float) -> mask.Loop2:
    return _rot(mask.superellipse(0.0, 0.0, hw, hh, hh, 3.2, n=40), cu, cv, deg)


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    parts = [shape.outline()]
    for cu, cv, hw, hh, deg in TABS:
        t = _tab(cu, cv, hw, hh, deg)
        parts += [t, mask.mirror(t)]
    return mask.radial_union(parts, centre=(0.0, -0.004), n=400)


def _hole_centres() -> list[tuple[float, float]]:
    out: list[tuple[float, float]] = []
    # mouth: a rounded triangle of staggered rows
    for v, us in ((-0.061, (0.006, 0.018)), (-0.072, (0.0, 0.012, 0.024)), (-0.083, (0.006, 0.018)),
                  (-0.094, (0.0, 0.012)), (-0.105, (0.006,))):
        for u in us:
            out += [(u, v)] if u == 0.0 else [(u, v), (-u, v)]
    # cheeks: a hexagonal cluster of seven under each eye
    s = 0.0098
    for du, dv in ((0.0, 0.0), (s, 0.0), (-s, 0.0), (s / 2, s * 0.866), (-s / 2, s * 0.866),
                   (s / 2, -s * 0.866), (-s / 2, -s * 0.866)):
        out += [(0.054 + du, -0.046 + dv), (-0.054 - du, -0.046 + dv)]
    # forehead: two short staggered rows either side of the centre rib
    for u, v in ((0.015, 0.084), (0.027, 0.081), (0.021, 0.072), (0.033, 0.069)):
        out += [(u, v), (-u, v)]
    return out


def _holes(shape: mask.MaskShape) -> list[mask.Loop2]:
    out = [mask.disc(u, v, HOLE_R, 10) for u, v in _hole_centres()]
    for cu, cv, _hw, _hh, deg in TABS:  # strap slots, tall and narrow, near the tab's outer end
        slot = _rot(mask.superellipse(0.0080, 0.0, 0.0022, 0.0062, 0.0062, 3.0, n=16), cu, cv, deg)
        out += [slot, mask.mirror(slot)]
    return out


def _eye_rims(kit: mask.MaskKit) -> None:
    """Thin raised rim around each eye hole."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0009)
    outer = mask.offset_loop(eye, -0.0042, max_miter=1.5)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0020, chamfer=0.0007, edge_res=0.0035)


def _ribs(kit: mask.MaskKit) -> None:
    """Raised stiffening ribs: up the centre of the dome, up from the outer brows, and down
    between the cheek and mouth vents."""
    centre = [(0.0, 0.046 + 0.064 * k / 8) for k in range(9)]
    kit.plate(mask.resample(mask.strip(centre, 0.0110, 0.0070), 0.004), hi=0.0034, chamfer=0.0012,
              edge_res=0.004)
    brow = [(0.064 - 0.024 * t * t, 0.040 + 0.068 * t) for t in (k / 8 for k in range(9))]
    lower = [(0.034 + 0.004 * math.sin(math.pi * t), -0.030 - 0.068 * t) for t in (k / 8 for k in range(9))]
    for pts, w0, w1 in ((brow, 0.0080, 0.0050), (lower, 0.0062, 0.0048)):
        for loop in mask.mirrored(mask.resample(mask.strip(pts, w0, w1), 0.004)):
            kit.plate(loop, hi=0.0028, chamfer=0.0010, edge_res=0.004)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_eye_rims, _ribs],
                    surface_extra=_sculpt, outline_fn=_outline, holes_fn=_holes, uv_mode="front")
