"""Serpent customisable base mask (``mask_base.serpent``, D3-03).

An original serpent: a broad, flat, wedge-shaped head narrowing to a rounded snout, narrow slanted
slit eyes under heavy brow scales, the crown tiled with large head scales (a long central shield,
paired brow and crown scales, small nose scales) and the cheeks with rows of small diamond scales,
a long lip line curling up from the snout toward the eyes, two nostril pits, and a broad hood
flaring out behind the head at both sides, cupped forward and ribbed, with a crest scale at the
top of the crown. The flared hood makes a wide shield silhouette with a narrow chin.

The hood is a flange off the shell's edge (``_mask_base.RimSurface``).

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_serpent"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.098,
    "bottom": -0.110,
    "chin_point": 0.006,
    "side_arc": 0.100,
    "jaw_taper": 0.56,
    "brow": 0.6,
    "cheek": 0.3,
    "nose": 0.0,
    "jaw": 0.4,
    "eye_shape": "almond",
    "eye_width": 0.036,
    "eye_height": 0.0100,
    "eye_spacing": 0.074,
    "eye_tilt_deg": 16.0,
    "mouth": "none",
    "res": 0.0090,
    "res_back": 0.016,
    "edge_res": 0.0050,
}

CENTRE = (0.0, -0.006)
HOOD_SPAN = (-72.0, 252.0)   # degrees covered by the hood (open under the chin)
TUCK = 0.0015


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _lip_v(au: float) -> float:
    """Height of the lip line at |u|: from the snout tip curling up toward the outer eye."""
    return -0.090 + 0.62 * au + 2.2 * au * au


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # rounded snout pushed forward
    f += 0.010 * _g(au, 0.030) * _g(v + 0.078, 0.024)
    # brow ridges over the eyes
    f += 0.0045 * _g(au - 0.040, 0.020) * _g(v - 0.018, 0.010)
    # lip line groove, fading out under the outer eye corner
    if au < 0.072:
        f -= 0.0030 * _g(v - _lip_v(au), 0.0026) * _smooth(0.072, 0.050, au)
    # nostril pits
    f -= 0.0040 * _g(math.hypot(au - 0.011, v + 0.072), 0.0035)
    # flat, broad crown
    f -= 0.0030 * _g(au, 0.06) * _g(v - 0.070, 0.030)
    return f


def _hood_rho(phi: float) -> float:
    """Hood width beyond the shell edge at angle phi: widest a little below eye level."""
    d = math.degrees(phi)
    side = min(abs(((d - (-12.0)) + 180) % 360 - 180), abs(((d - 192.0) + 180) % 360 - 180))
    top = abs(((d - 90.0) + 180) % 360 - 180)
    rho = 0.008 + 0.044 * math.exp(-(side / 50.0) ** 2) + 0.004 * math.exp(-(top / 25.0) ** 2)
    a0, a1 = HOOD_SPAN
    edge = min(d - a0 if d >= a0 else 999.0, a1 - d if d <= a1 else 999.0)
    if d < a0 - 1e-9 or d > a1 + 1e-9:
        return 0.0
    return rho * _smooth(0.0, 26.0, edge)


def _at(outline: mask.Loop2, phi: float, rho: float) -> mask.Point2:
    r = mask.ray_radius(CENTRE, phi, outline) + rho
    return (CENTRE[0] + r * math.cos(phi), CENTRE[1] + r * math.sin(phi))


def _hood(kit: mask.MaskKit) -> None:
    """The flared hood behind the head and three ribs on each side of it."""
    outline = kit.shape.outline()
    t = float(kit.params["thickness"])
    rim = mask.RimSurface(kit.surf, outline, centre=CENTRE, inset=0.0015, depth=-t + 0.0015, tilt=-0.28)
    m = kit.mat("primary")
    a0, a1 = math.radians(HOOD_SPAN[0]), math.radians(HOOD_SPAN[1])
    n = 96
    outer = [_at(outline, a0 + (a1 - a0) * k / n, _hood_rho(a0 + (a1 - a0) * k / n)) for k in range(n + 1)]
    inner = [_at(outline, a1 - (a1 - a0) * k / 48, -TUCK) for k in range(49)]
    mask.slab(kit.mb, rim, mask.oriented(outer[1:-1] + inner, True), [], -0.0028, 0.0, 0.0010, m, m, m,
              0.012, 0.03, 0.006, bottom=True)
    for d in (-40.0, -12.0, 16.0):
        for phi in (math.radians(d), math.radians(180.0 - d)):
            ln = _hood_rho(phi)
            pts = [_at(outline, phi + 0.08 * s * s * (1 if math.cos(phi) > 0 else -1), 0.004 + (ln - 0.010) * s)
                   for s in (k / 6 for k in range(7))]
            mask.slab(kit.mb, rim, mask.resample(mask.strip(pts, 0.0050, 0.0022), 0.005), [], -0.001, 0.0020,
                      0.0007, m, m, None, 0.03, 0.03, 0.005, bottom=False)


def _scale(kit: mask.MaskKit, loop: mask.Loop2, hi: float = 0.0022) -> None:
    kit.plate(loop, hi=hi, chamfer=0.0009, edge_res=0.006, res=0.03)


def _head_scales(kit: mask.MaskKit) -> None:
    """Large crown scales: a long central shield, brow, crown and nose scales, and a crest row."""
    _scale(kit, [(0.0, 0.056), (0.013, 0.048), (0.011, 0.020), (0.0, 0.010), (-0.011, 0.020), (-0.013, 0.048)])
    for loop in mask.mirrored([(0.022, 0.016), (0.050, 0.020), (0.064, 0.030), (0.040, 0.038), (0.020, 0.030)]):
        _scale(kit, loop, 0.0030)
    for loop in mask.mirrored([(0.004, 0.064), (0.020, 0.056), (0.046, 0.064), (0.040, 0.084), (0.006, 0.086)]):
        _scale(kit, loop)
    for loop in mask.mirrored([(0.003, -0.014), (0.016, -0.010), (0.020, -0.030), (0.004, -0.034)]):
        _scale(kit, loop)
    for loop in mask.mirrored([(0.003, -0.040), (0.016, -0.038), (0.014, -0.056), (0.003, -0.058)]):
        _scale(kit, loop)
    _scale(kit, mask.superellipse(0.0, 0.0905, 0.0068, 0.0050, 0.0050, 2.0, n=10), 0.0030)


def _cheek_scales(kit: mask.MaskKit) -> None:
    """Rows of small diamond scales on each cheek, between the lip line and the eye."""
    for row in range(3):
        for col in range(3):
            cu = 0.044 + 0.0125 * col + 0.006 * (row % 2)
            cv = -0.022 - 0.0105 * row - 0.004 * col
            if cv < _lip_v(cu) + 0.006:
                continue
            d = [(cu, cv + 0.0058), (cu + 0.0058, cv), (cu, cv - 0.0058), (cu - 0.0058, cv)]
            for loop in mask.mirrored(d):
                _scale(kit, loop, 0.0016)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_head_scales, _cheek_scales, _hood],
                    surface_extra=_sculpt, uv_mode="front")
