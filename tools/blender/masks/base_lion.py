"""Lion customisable base mask (``mask_base.lion``, D-111).

An original lion: a broad, flat-browed face with a deep furrow between heavy brows, almond eyes set
under them, a wide muzzle with two rounded whisker pads, a broad triangular nose leather and a split
upper lip. Round the whole face, top, sides and under the chin, runs a mane: a flange leaving the
shell's edge (``_mask_base.RimSurface``) cut into flame-shaped locks in two staggered rows, the back
row longer, every front lock with a raised ridge. The ring of locks is the widest round outline in
the set; nothing else reads as a full circle at distance.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_lion"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.094,
    "bottom": -0.112,
    "chin_point": 0.0,
    "side_arc": 0.096,
    "jaw_taper": 0.30,
    "brow": 1.3,
    "cheek": 0.8,
    "nose": 0.0,
    "jaw": 0.7,
    "eye_shape": "almond",
    "eye_width": 0.033,
    "eye_height": 0.0125,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 8.0,
    "mouth": "none",
    "res": 0.0090,
    "res_back": 0.016,
    "edge_res": 0.0050,
}

CENTRE = (0.0, -0.008)      # polar centre of the mane
N_BACK, N_FRONT = 16, 16    # locks per row (full circle)
BACK_LEN = 0.040            # back-row lock length beyond the shell edge (m)
FRONT_LEN = 0.026           # front-row lock length
TUCK = 0.0015               # how far the mane runs under the shell rim
TILT = 0.16                 # the mane sweeps back
REFINE = [(0.0, -0.068, 0.040, 0.030, 0.0042)]  # muzzle: nose leather, pads, lip


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # broad nose bridge running from the brow furrow down to the nose leather
    f += 0.012 * _g(au, 0.020) * _smooth(0.010, -0.020, v) * _smooth(-0.075, -0.050, v)
    # the muzzle: two rounded whisker pads either side of the centre line
    f += 0.012 * _g(au - 0.020, 0.018) * _g(v + 0.078, 0.016)
    # the chin under the pads
    f += 0.006 * _g(au, 0.022) * _g(v + 0.102, 0.012)
    # deep vertical furrow between the brows
    f -= 0.0035 * _g(au, 0.0035) * _g(v - 0.030, 0.016)
    # split upper lip: a groove down the centre of the pads
    f -= 0.0028 * _g(au, 0.0022) * _smooth(-0.064, -0.072, v) * _smooth(-0.096, -0.086, v)
    # hollow under the cheekbones
    f -= 0.0025 * _g(au - 0.058, 0.014) * _g(v + 0.040, 0.016)
    return f


def _r_o(outline: mask.Loop2, phi: float) -> float:
    return mask.ray_radius(CENTRE, phi, outline)


def _at(outline: mask.Loop2, phi: float, rho: float) -> mask.Point2:
    r = _r_o(outline, phi) + rho
    return (CENTRE[0] + r * math.cos(phi), CENTRE[1] + r * math.sin(phi))


def _lock_ring(outline: mask.Loop2, n: int, length: float, phase: float, base: float) -> mask.Loop2:
    """A ring of flame-shaped locks: each lock swells, then narrows to a tip curving clockwise."""
    pts: mask.Loop2 = []
    step = 2 * math.pi / n
    for k in range(n):
        a = phase + k * step
        for j in range(8):
            t = j / 8.0
            # lock profile: valley at t = 0, a swelling flank, the tip at t = 0.62, a steep return
            if t < 0.62:
                rho = base + length * (math.sin(t / 0.62 * math.pi / 2) ** 1.6)
            else:
                rho = base + length * (1.0 - _smooth(0.62, 1.0, t))
            pts.append(_at(outline, a + t * step + 0.18 * step * math.sin(t * math.pi), rho))
    return pts


def _rim(kit: mask.MaskKit, outline: mask.Loop2) -> mask.RimSurface:
    t = float(kit.params["thickness"])
    return mask.RimSurface(kit.surf, outline, centre=CENTRE, inset=0.0015, depth=-t + 0.0015, tilt=TILT)


def _mane(kit: mask.MaskKit) -> None:
    """Back row (long locks, flat) and front row (short locks, raised, a ridge on each)."""
    outline = kit.shape.outline()
    rim = _rim(kit, outline)
    m = kit.mat("primary")
    inner = [_at(outline, -2 * math.pi * k / 96, -TUCK) for k in range(96)]
    back = _lock_ring(outline, N_BACK, BACK_LEN, 0.0, 0.006)
    mask.slab(kit.mb, rim, mask.oriented(back, True), [mask.oriented(inner, False)], -0.0030, 0.0, 0.0010,
              m, m, m, 0.03, 0.03, 0.03, bottom=True)
    front = _lock_ring(outline, N_FRONT, FRONT_LEN, math.pi / N_FRONT, 0.004)
    inner_f = [_at(outline, -2 * math.pi * k / 96, 0.0010) for k in range(96)]
    mask.slab(kit.mb, rim, mask.oriented(front, True), [mask.oriented(inner_f, False)], -0.001, 0.0030, 0.0010,
              m, m, None, 0.03, 0.03, 0.006, bottom=False)
    step = 2 * math.pi / N_FRONT
    for k in range(N_FRONT):
        a = math.pi / N_FRONT + k * step
        ridge = [_at(outline, a + 0.20 * step, 0.004), _at(outline, a + 0.70 * step, FRONT_LEN * 0.85),
                 _at(outline, a + 0.42 * step, 0.004)]
        mask.slab(kit.mb, rim, ridge, [], -0.001, 0.0048, 0.0007, m, m, None, 0.03, 0.03, 0.03, bottom=False)


def _nose(kit: mask.MaskKit) -> None:
    """Broad triangular nose leather at the top of the muzzle, flat-topped."""
    tri = mask.spline_loop([(0.0, -0.066), (-0.017, -0.052), (-0.012, -0.046), (0.012, -0.046), (0.017, -0.052)],
                           samples=4, sharp=[0])
    kit.plate(mask.resample(tri, 0.004), hi=0.0038, chamfer=0.0012, edge_res=0.004)


def _brows(kit: mask.MaskKit) -> None:
    """Heavy brows over each eye, thick at the furrow and thinning out to the temple."""
    for loop in mask.mirrored(mask.leaf((0.010, 0.022), (0.060, 0.016), 0.010, bend=0.004)):
        kit.plate(mask.resample(loop, 0.004), hi=0.0030, chamfer=0.0011, edge_res=0.004)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_brows, _nose, _mane],
                    surface_extra=_sculpt, uv_mode="front", refine=REFINE)
