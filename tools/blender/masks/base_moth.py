"""Moth customisable base mask (``mask_base.moth``, D3-03).

An original moth: a soft, round face with two large domed eye rings, a furry crest of tufts on the
brow, two feathery antennae (a curved spine with a comb of barbs on both
sides) rising from the forehead, and four wings spreading out behind the face, broad upper wings
and smaller lower wings, in relief: an eyespot ring on each upper wing, a smaller ring on each
lower wing, and veins fanning out from the face. The wings and antennae give the widest, most
lobed silhouette in the set.

Wings and antennae are flanges off the shell's edge (``_mask_base.RimSurface``).

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_moth"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.094,
    "bottom": -0.104,
    "side_arc": 0.098,
    "jaw_taper": 0.40,
    "brow": 0.6,
    "cheek": 0.8,
    "nose": 0.2,
    "jaw": 0.6,
    "eye_shape": "round",
    "eye_width": 0.034,
    "eye_height": 0.030,
    "eye_spacing": 0.074,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "res": 0.0090,
    "res_back": 0.016,
    "edge_res": 0.0050,
}

CENTRE = (0.0, -0.004)
TUCK = 0.0015
TILT = 0.14
# right wings, upper then lower: (leading-edge start, apex, trailing-edge end angle in degrees,
# apex length beyond the shell edge m)
WINGS = [(74.0, 18.0, -8.0, 0.068), (-14.0, -42.0, -70.0, 0.042)]
# antenna: root and tip in (u, v), right side
ANT_ROOT = (0.012, 0.091)
ANT_TIP = (0.062, 0.168)


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _lobe(d: float, a_in: float, apex: float, a_out: float, ln: float) -> float:
    """A wing in polar form: a straight leading edge from ``a_in`` out to the ``apex`` angle (full
    length ``ln``), then a rounded trailing edge back to ``a_out`` (degrees, either order)."""
    if (d - a_in) * (d - apex) <= 0:
        t = (d - a_in) / (apex - a_in)
        return ln * (0.10 + 0.90 * t ** 0.85)
    if (d - apex) * (d - a_out) <= 0:
        t = (d - apex) / (a_out - apex)
        return ln * (1 - t) ** 0.6
    return 0.0


def _wing_rho(phi: float) -> float:
    d = math.degrees(phi)
    rho = 0.0
    for a_in, apex, a_out, ln in WINGS:
        rho = max(rho, _lobe(d, a_in, apex, a_out, ln), _lobe(180.0 - d, a_in, apex, a_out, ln))
    return rho


def _at(outline: mask.Loop2, phi: float, rho: float) -> mask.Point2:
    r = mask.ray_radius(CENTRE, phi, outline) + rho
    return (CENTRE[0] + r * math.cos(phi), CENTRE[1] + r * math.sin(phi))


def _rim(kit: mask.MaskKit, outline: mask.Loop2) -> mask.RimSurface:
    t = float(kit.params["thickness"])
    return mask.RimSurface(kit.surf, outline, centre=CENTRE, inset=0.0015, depth=-t + 0.0015, tilt=TILT)


def _flat(kit: mask.MaskKit, rim: mask.RimSurface, loop: mask.Loop2, hi: float = 0.0018) -> None:
    m = kit.mat("primary")
    mask.slab(kit.mb, rim, loop, [], -0.001, hi, 0.0007, m, m, None, 0.03, 0.03, 0.005, bottom=False)


def _wings(kit: mask.MaskKit) -> None:
    """Four wings behind the face with eyespot rings and veins."""
    outline = kit.shape.outline()
    rim = _rim(kit, outline)
    m = kit.mat("primary")
    for upper, (a_in, apex, a_out, ln) in zip((True, False), WINGS):
        for flip in (False, True):
            def ang(d: float, flip: bool = flip) -> float:
                return math.radians(180.0 - d if flip else d)

            lo, hi_ = sorted((ang(a_in), ang(a_out)))
            n = 40
            outer = [_at(outline, lo + (hi_ - lo) * k / n, _wing_rho(lo + (hi_ - lo) * k / n)) for k in range(n + 1)]
            inner = [_at(outline, hi_ - (hi_ - lo) * k / 12, -TUCK) for k in range(13)]
            mask.slab(kit.mb, rim, mask.oriented(outer + inner, True), [], -0.0028, 0.0, 0.0010, m, m, m,
                      0.012, 0.03, 0.005, bottom=True)
            # eyespot: a ring with a dot, in the broad part of the wing
            spot = ang(apex + 0.30 * (a_in - apex))
            ring_c = _at(outline, spot, _wing_rho(spot) * 0.50)
            r_out = 0.0125 if upper else 0.0080
            ring = mask.disc(ring_c[0], ring_c[1], r_out, 18)
            hole = mask.disc(ring_c[0], ring_c[1], r_out * 0.62, 14)
            mask.slab(kit.mb, rim, ring, [hole], -0.001, 0.0020, 0.0007, m, m, None, 0.03, 0.03, 0.004, bottom=False)
            _flat(kit, rim, mask.disc(ring_c[0], ring_c[1], r_out * 0.30, 10), 0.0026)
            # veins fanning out on either side of the eyespot
            for f in (0.12, 0.72):
                phi = ang(a_in + (a_out - a_in) * f)
                vl = _wing_rho(phi)
                pts = [_at(outline, phi, 0.002 + (vl - 0.009) * q) for q in (k / 5 for k in range(6))]
                _flat(kit, rim, mask.resample(mask.strip(pts, 0.0030, 0.0016), 0.005), 0.0016)


def _antenna_loop(side: int) -> mask.Loop2:
    """A curved spine with a comb of thin barbs on both sides (bipectinate), tapering to the tip."""
    n = 10
    root, tip = ANT_ROOT, ANT_TIP
    mid = (root[0] + (tip[0] - root[0]) * 0.35, root[1] + (tip[1] - root[1]) * 0.6)

    def frame(t: float) -> tuple[mask.Point2, float, float, float, float]:
        p = mask.quad_bezier(root, mid, tip, t)
        a = mask.quad_bezier(root, mid, tip, max(0.0, t - 1e-3))
        b = mask.quad_bezier(root, mid, tip, min(1.0, t + 1e-3))
        tx, ty = b[0] - a[0], b[1] - a[1]
        tl = math.hypot(tx, ty) or 1.0
        return p, tx / tl, ty / tl, -ty / tl, tx / tl

    left: mask.Loop2 = []
    right: mask.Loop2 = []
    for i in range(n + 2):
        t = i / (n + 1)
        p, tx, ty, px, py = frame(t)
        spine = 0.0024 * (1 - 0.55 * t)
        if 0 < i <= n:
            barb = 0.0120 * math.sin(math.pi * (0.12 + 0.80 * t))
            w = 0.0016
            for sgn, out in ((1, left), (-1, right)):
                out += [(p[0] + sgn * px * spine - tx * w, p[1] + sgn * py * spine - ty * w),
                        (p[0] + sgn * px * (spine + barb) + tx * 0.008, p[1] + sgn * py * (spine + barb) + ty * 0.008),
                        (p[0] + sgn * px * spine + tx * w, p[1] + sgn * py * spine + ty * w)]
        else:
            left.append((p[0] + px * spine, p[1] + py * spine))
            right.append((p[0] - px * spine, p[1] - py * spine))
    loop = left + list(reversed(right))
    return loop if side > 0 else mask.mirror(loop)


def _antennae(kit: mask.MaskKit) -> None:
    outline = kit.shape.outline()
    rim = _rim(kit, outline)
    m = kit.mat("primary")
    for side in (1, -1):
        mask.slab(kit.mb, rim, _antenna_loop(side), [], -0.0026, 0.0, 0.0008, m, m, m, 0.03, 0.03, 0.03,
                  bottom=True)


def _eyes(kit: mask.MaskKit) -> None:
    """Large domed compound-eye rings in two steps."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    for o_off, i_off, hi in ((-0.0080, -0.0040, 0.0022), (-0.0042, -0.0008, 0.0040)):
        outer = mask.offset_loop(eye, o_off)
        inner = mask.offset_loop(eye, i_off)
        for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
            kit.plate(o, holes=[h], hi=hi, chamfer=0.0010, edge_res=0.006)


def _fur(kit: mask.MaskKit) -> None:
    """A furry crest of tufts on the brow over the nose."""
    for root, tip, w in (((0.0, 0.010), (0.0, 0.060), 0.020), ((0.012, 0.016), (0.030, 0.054), 0.014)):
        lock = mask.leaf(root, tip, w, n=8, fullness=0.6)
        for loop in ([lock] if root[0] == 0.0 else mask.mirrored(lock)):
            kit.plate(loop, hi=0.0026, chamfer=0.0009, edge_res=0.005)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_eyes, _fur, _wings, _antennae],
                    uv_mode="front")
