"""Bruiser customisable base mask (``mask_base.bruiser``, QB-50b).

The tough one: a broad, squared full-face shell with a heavy scowling brow bar, a flattened,
kinked (broken) nose bridge, narrow hooded eyes in thick rims, hockey-mask breathing vents (a
stacked mouth grille and raked cheek slots) and a riveted jaw guard wrapping the chin. Wide at the
jaw and flat-topped, it reads blocky at any distance next to the pointed animal masks.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_bruiser"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.100,
    "bottom": -0.120,
    "side_arc": 0.118,
    "jaw_taper": 0.16,
    "brow": 1.6,
    "cheek": 1.6,
    "nose": 1.2,
    "jaw": 1.6,
    "eye_shape": "almond",
    "eye_width": 0.035,
    "eye_height": 0.0125,
    "eye_tilt_deg": 11.0,
    "mouth": "none",
    "face_half_width": 0.088,
    "wrap_radius": 0.096,
    "thickness": 0.006,
    "chamfer": 0.0018,
    "res": 0.0085,
    "res_back": 0.015,
}

RIVET_R = 0.0034


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # broken nose: the bridge kinks to the wearer's right, a knot on the break, a flattened tip
    f += 0.0060 * _g(u + 0.0070, 0.0065) * _g(v + 0.022, 0.0075)
    f -= 0.0050 * _g(u - 0.0060, 0.0055) * _g(v + 0.024, 0.0085)
    f += 0.0030 * _g(u - 0.0010, 0.0050) * _g(v + 0.009, 0.0040)  # knot on the bridge
    f -= 0.0035 * _g(au, 0.010) * _g(v + 0.046, 0.0060)  # tip flattened back
    f += 0.0030 * _g(au - 0.014, 0.008) * _g(v + 0.044, 0.0060)  # broad nostrils
    # heavy jaw and a jutting chin
    f += 0.0060 * _g(au, 0.045) * _g(v + 0.098, 0.022)
    # flat, sloping forehead
    f += 0.0040 * _g(au, 0.06) * max(0.0, min(1.0, (v - 0.04) / 0.05))
    return f


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    p = shape.p
    bot = -float(p["bottom"])
    loop = mask.superellipse(0.0, 0.0, float(p["side_arc"]), float(p["top"]), bot, 3.6, n=176, p_bottom=3.0)
    taper = float(p["jaw_taper"])
    return [(u * (1 - taper * (-v / bot) ** 2), v) if v < 0 else (u, v) for u, v in loop]


def _slot(cu: float, cv: float, half_l: float, half_h: float, deg: float) -> mask.Loop2:
    """Rounded vent slot (stadium) centred at (cu, cv), rotated ``deg``."""
    out: mask.Loop2 = []
    ca, sa = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    for side in (1, -1):
        for k in range(7):
            a = -math.pi / 2 + math.pi * k / 6
            x = side * (half_l - half_h + half_h * math.cos(a))
            y = side * half_h * math.sin(a)
            out.append((cu + x * ca - y * sa, cv + x * sa + y * ca))
    return out


def _vents(shape: mask.MaskShape) -> list[mask.Loop2]:
    out = [_slot(0.0, v, hl, 0.0026, 0.0) for v, hl in ((-0.060, 0.019), (-0.069, 0.017), (-0.078, 0.014))]
    for cu, cv in ((0.040, -0.034), (0.052, -0.043), (0.064, -0.052)):
        s = _slot(cu, cv, 0.0085, 0.0023, -38.0)
        out += [s, mask.mirror(s)]
    return out


def _brow_bar(kit: mask.MaskKit) -> None:
    """One heavy scowling brow bar across the forehead, low in the centre."""
    pts = [(-0.086, 0.035), (-0.064, 0.032), (-0.036, 0.026), (-0.014, 0.019), (0.0, 0.017),
           (0.014, 0.019), (0.036, 0.026), (0.064, 0.032), (0.086, 0.035)]
    bar = mask.strip(pts, 0.018, 0.018)
    kit.plate(mask.resample(bar, 0.004), hi=0.0055, chamfer=0.0014, edge_res=0.004)


def _eye_rims(kit: mask.MaskKit) -> None:
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0010)
    outer = mask.offset_loop(eye, -0.0060)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0030, chamfer=0.0008, edge_res=0.004)


def _jaw_points(kit: mask.MaskKit) -> tuple[mask.Loop2, mask.Loop2]:
    """Outer and inner edges of the jaw guard band (wearer's right to left, under the chin)."""
    outline = mask.resample(mask.oriented(_outline(kit.shape), True), 0.004)
    outer = mask.offset_loop(outline, 0.0035)
    inner = mask.offset_loop(outline, 0.0215)
    v_cut = -0.030
    idx = [i for i, (_u, v) in enumerate(outline) if v < v_cut]
    # idx is one contiguous run on a CCW loop starting at angle 0: order it from +u to -u
    idx.sort(key=lambda i: -math.atan2(outline[i][1], outline[i][0]) % (2 * math.pi))
    return [outer[i] for i in idx], [inner[i] for i in idx]


def _jaw_guard(kit: mask.MaskKit) -> None:
    """Riveted guard plate wrapping the jaw and chin."""
    outer, inner = _jaw_points(kit)
    band = outer + list(reversed(inner))
    kit.plate(band, hi=0.0045, chamfer=0.0012, edge_res=0.004)
    mid = [((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5) for a, b in zip(outer, inner)]
    lens = [0.0]
    for i in range(1, len(mid)):
        lens.append(lens[-1] + math.dist(mid[i - 1], mid[i]))
    for k in range(7):  # rivets spaced evenly along the band
        d = lens[-1] * (0.06 + 0.88 * k / 6)
        j = min(range(len(lens)), key=lambda i: abs(lens[i] - d))
        kit.plate(mask.disc(mid[j][0], mid[j][1], RIVET_R, 10), hi=0.0072, chamfer=0.0010, edge_res=0.003)


def _brow_rivets(kit: mask.MaskKit) -> None:
    for cu, cv in ((0.074, 0.034), (-0.074, 0.034)):
        kit.plate(mask.disc(cu, cv, RIVET_R, 10), hi=0.0082, chamfer=0.0010, edge_res=0.003)


def _forehead_ridge(kit: mask.MaskKit) -> None:
    """A low armour ridge up the forehead centre, from the brow bar to the hairline."""
    spine = [(0.0, 0.030 + 0.050 * i / 6) for i in range(7)]
    kit.plate(mask.strip(spine, 0.016, 0.009), hi=0.0028, chamfer=0.0010, edge_res=0.005)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_forehead_ridge, _brow_bar, _brow_rivets, _eye_rims, _jaw_guard],
                    surface_extra=_sculpt, outline_fn=_outline, holes_fn=_vents, uv_mode="front")
