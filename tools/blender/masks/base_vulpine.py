"""Vulpine customisable base mask (``mask_base.vulpine``, QB-50b).

A fox: tall pointed ears rising well above the brow line (hollowed inside, with a fur tuft), a
long tapering snout lofted from the brow stop to a rounded nose pad, sly upswept eyes under a
soft brow, and a spiked cheek ruff that widens the lower silhouette. Fur is suggested by a few
broad sculpted locks, never by fine noise, so patterns stay readable.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_vulpine"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.088,
    "bottom": -0.098,
    "chin_point": 0.014,
    "side_arc": 0.104,
    "jaw_taper": 0.52,
    "brow": 1.15,
    "cheek": 1.3,
    "nose": 0.3,
    "jaw": 0.7,
    "eye_shape": "almond",
    "eye_width": 0.037,
    "eye_height": 0.0135,
    "eye_tilt_deg": 17.0,
    "mouth": "none",
    "res": 0.0085,
    "res_back": 0.015,
    # ornaments
    "snout_tip": (0.0, 0.098, -0.052),
}

# ear: (inner base, tip, outer base) in (u, v); the right ear, mirrored for the left
EAR = [(0.010, 0.084), (0.034, 0.128), (0.062, 0.172), (0.088, 0.122), (0.106, 0.040)]
EAR_TIP = (0.062, 0.172)
# cheek ruff spikes: (root top, tip, root bottom)
RUFF = [((0.098, -0.004), (0.128, -0.030), (0.094, -0.034)),
        ((0.090, -0.030), (0.116, -0.064), (0.080, -0.060)),
        ((0.072, -0.056), (0.092, -0.094), (0.056, -0.082))]


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _ear_axis(u: float, v: float) -> tuple[float, float]:
    """(along, across) coordinates of (|u|, v) relative to the ear's centre axis."""
    bx, by = 0.058, 0.066
    tx, ty = EAR_TIP
    dx, dy = tx - bx, ty - by
    ln = math.hypot(dx, dy)
    ax, ay = dx / ln, dy / ln
    px, py = abs(u) - bx, v - by
    return (px * ax + py * ay) / ln, -px * ay + py * ax


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # stand the ears up: cancel most of the head's backward curve above the brow
    lift = _smooth(0.075, 0.180, v)
    f += lift * (0.62 * 3.2 * max(0.0, v - 0.02) ** 2 + 0.010 * _g(au - 0.06, 0.04))
    # hollow of each ear, deepest toward the base
    along, across = _ear_axis(u, v)
    if -0.2 < along < 1.1:
        f -= 0.0065 * _g(across, 0.012 * (1.15 - 0.8 * max(0.0, along))) * _smooth(-0.1, 0.25, along) * _smooth(1.05, 0.6, along)
    # fox stop: a dip between the eyes where the snout leaves the brow
    f -= 0.0025 * _g(au, 0.012) * _g(v - 0.012, 0.010)
    # cheeks swell out toward the ruff
    f += 0.0045 * _g(au - 0.075, 0.020) * _g(v + 0.035, 0.022)
    return f


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    face = shape.outline()
    ear = mask.spline_loop(EAR, samples=5, sharp=(0, 2, 4))
    parts = [face, ear, mask.mirror(ear)]
    tips = [EAR_TIP, (-EAR_TIP[0], EAR_TIP[1])]
    for a, tip, b in RUFF:
        tri = [a, tip, b, ((a[0] + b[0]) * 0.5 - 0.03, (a[1] + b[1]) * 0.5)]
        parts += [tri, mask.mirror(tri)]
        tips += [tip, (-tip[0], tip[1])]
    return mask.radial_union(parts, centre=(0.0, -0.010), n=400, keep=tips)


def _inner_ear(kit: mask.MaskKit) -> None:
    """A fur tuft in each ear hollow: two locks rising from the base toward the tip."""
    for root, tip, w in (((0.048, 0.076), (0.058, 0.146), 0.017), ((0.066, 0.072), (0.068, 0.126), 0.013)):
        lock = mask.leaf(root, tip, w, bend=0.08, n=8, fullness=0.6)
        for loop in mask.mirrored(lock):
            kit.plate(loop, hi=0.0022, chamfer=0.0006, edge_res=0.004)


def _brow(kit: mask.MaskKit) -> None:
    """Soft swept brow lock above each eye, rising toward the ear."""
    lock = mask.leaf((0.012, 0.020), (0.074, 0.050), 0.013, bend=0.10, n=9, fullness=0.5)
    for loop in mask.mirrored(lock):
        kit.plate(loop, hi=0.0026, chamfer=0.0008)


def _ruff_locks(kit: mask.MaskKit) -> None:
    """Broad fur locks over the cheeks, sweeping out into the ruff spikes."""
    for root, tip, w, hi in (((0.030, -0.022), (0.104, -0.026), 0.018, 0.0034),
                             ((0.030, -0.042), (0.092, -0.058), 0.017, 0.0028),
                             ((0.028, -0.062), (0.068, -0.080), 0.014, 0.0022)):
        lock = mask.leaf(root, tip, w, bend=-0.10, n=9, fullness=0.55)
        for loop in mask.mirrored(lock):
            kit.plate(loop, hi=hi, chamfer=0.0007)


def _snout(kit: mask.MaskKit) -> None:
    """Long tapering muzzle lofted from inside the shell, a narrow bridge over a fuller jaw line,
    capped by a rounded nose pad."""
    surf = kit.surf
    t = float(kit.params["thickness"])
    tip = Vector(kit.params["snout_tip"])
    top0, bot0, w0 = 0.010, -0.074, 0.026

    def profile(s: float) -> list[tuple[float, float]]:
        zt = top0 + (tip.z + 0.012 - top0) * s ** 0.9
        zb = bot0 + (tip.z - 0.010 - bot0) * s ** 0.7
        zc, hh = (zt + zb) * 0.5, (zt - zb) * 0.5
        w = w0 * (1 - 0.62 * s ** 0.8)
        out = []
        for j in range(16):  # rounded section: narrow bridge on top, fuller flat-ish jaw below
            b = math.pi * 0.5 + 2 * math.pi * j / 16
            c, sn = math.cos(b), math.sin(b)
            x = w * c * (1 - (0.55 - 0.15 * s) * max(sn, 0.0) ** 1.5)
            z = zc + hh * (sn if sn > 0 else -abs(sn) ** 0.75)
            out.append((x, z))
        return out

    root = profile(0.0)
    y_root = [surf.depth_at(x, z) - 0.5 * t for x, z in root]
    n = 16
    sections = []
    for k in range(n + 1):
        s = k / n
        sy = tip.y - 0.006
        ys = [yr + (sy - yr) * (s ** 0.85) for yr in y_root]
        sections.append([Vector((x, ys[i], z)) for i, (x, z) in enumerate(profile(s))])
    kit.loft(sections, cap_start=False)
    # nose pad: a rounded, slightly heart-shaped button over the muzzle end
    pad = []
    for k in range(8):
        a = math.pi * k / 7 - math.pi / 2  # -90..90 deg along +Y
        r = math.cos(a)
        y = tip.y - 0.010 + 0.016 * (math.sin(a) + 1) * 0.5
        sec = []
        for j in range(12):
            b = 2 * math.pi * j / 12
            sx = 0.0150 * r * math.cos(b) * (1.0 + 0.10 * math.cos(2 * b))
            sz = 0.0105 * r * math.sin(b) * (1.0 - 0.15 * math.sin(b))
            sec.append(Vector((sx, y, tip.z + 0.004 + sz)))
        pad.append(sec)
    kit.loft(pad[1:-1], tip=Vector((0.0, tip.y + 0.006, tip.z + 0.004)), cap_start=True)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_inner_ear, _brow, _ruff_locks, _snout],
                    surface_extra=_sculpt, outline_fn=_outline, uv_mode="front")
