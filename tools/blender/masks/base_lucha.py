"""Lucha customisable base mask (``mask_base.lucha``, D-111).

An original wrestling hood: a smooth, full face with large teardrop eye openings, each wrapped in a
raised flame appliqué whose tongues lick up and out toward the temples, a raised oval mouth surround,
a centre stripe panel from the crown down the nose, and the hood itself, a deep flange that leaves the
top and sides of the face (``_mask_base.RimSurface``) and rounds off over the head, with a laced seam
up the back of the crown suggested by a row of eyelets at its top. The rounded full-hood outline with
flame-wrapped eyes is the read at distance; the big panels are made for loud two-colour patterns.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_lucha"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.104,
    "bottom": -0.112,
    "chin_point": 0.0,
    "side_arc": 0.098,
    "jaw_taper": 0.34,
    "brow": 0.9,
    "cheek": 0.9,
    "nose": 0.9,
    "jaw": 0.9,
    "eye_shape": "almond",
    "eye_width": 0.040,
    "eye_height": 0.0200,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 14.0,
    "mouth": "open",
    "mouth_width": 0.036,
    "mouth_height": 0.016,
    "mouth_v": -0.070,
    "res": 0.0085,
    "res_back": 0.015,
    "edge_res": 0.0050,
}

CENTRE = (0.0, -0.004)
SPAN = (-38.0, 218.0)      # the hood: over the top and down both sides to the jaw
HOOD = 0.036               # hood depth beyond the shell edge (m)
TILT = 0.08                # the hood rounds back over the head
TUCK = 0.0015


def _r_o(outline: mask.Loop2, phi: float) -> float:
    return mask.ray_radius(CENTRE, phi, outline)


def _at(outline: mask.Loop2, phi: float, rho: float) -> mask.Point2:
    r = _r_o(outline, phi) + rho
    return (CENTRE[0] + r * math.cos(phi), CENTRE[1] + r * math.sin(phi))


def _hood(kit: mask.MaskKit) -> None:
    """The hood flange (its edge eased round at the ends) and a row of lace eyelets at the crown."""
    outline = kit.shape.outline()
    t = float(kit.params["thickness"])
    rim = mask.RimSurface(kit.surf, outline, centre=CENTRE, inset=0.0015, depth=-t + 0.0015, tilt=TILT)
    m = kit.mat("primary")
    a0, a1 = math.radians(SPAN[0]), math.radians(SPAN[1])
    outer = []
    for k in range(73):
        s = k / 72
        ease = math.sin(math.pi * s) ** 0.35
        outer.append(_at(outline, a0 + (a1 - a0) * s, HOOD * ease + 0.0005))
    inner = [_at(outline, a1 - (a1 - a0) * k / 72, -TUCK) for k in range(73)]
    mask.slab(kit.mb, rim, mask.oriented(outer + inner, True), [], -0.0030, 0.0, 0.0012, m, m, m,
              0.03, 0.03, 0.006, bottom=True)
    # a raised piping band where the hood meets the face
    band_o = [_at(outline, a0 + (a1 - a0) * k / 72, 0.0055) for k in range(73)]
    band_i = [_at(outline, a1 - (a1 - a0) * k / 72, 0.0010) for k in range(73)]
    mask.slab(kit.mb, rim, mask.oriented(band_o + band_i, True), [], -0.001, 0.0024, 0.0008, m, m, None,
              0.03, 0.03, 0.007, bottom=False)
    # eyelets up the crown
    for k in range(5):
        phi = math.radians(90.0)
        c = _at(outline, phi + (k - 2) * 0.10, HOOD * 0.62)
        mask.slab(kit.mb, rim, mask.oriented(mask.disc(c[0], c[1], 0.0030, 10), True), [], -0.001, 0.0022, 0.0006,
                  m, m, None, 0.03, 0.03, 0.003, bottom=False)


def _flames(kit: mask.MaskKit) -> None:
    """A flame appliqué round each eye: a band hugging the opening with three tongues licking up and out."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0012)
    band = mask.offset_loop(eye, -0.0080)
    pts: mask.Loop2 = []
    cu = sum(p[0] for p in eye) / len(eye)
    cv = sum(p[1] for p in eye) / len(eye)
    tongues = [(70.0, 0.030), (35.0, 0.042), (0.0, 0.030)]   # angle (deg from +u), length beyond the band
    for p in mask.resample(band, 0.0028):
        ang = math.degrees(math.atan2(p[1] - cv, p[0] - cu))
        ext = 0.0
        for a, ln in tongues:
            d = (ang - a + 180.0) % 360.0 - 180.0
            ext = max(ext, ln * max(0.0, 1.0 - abs(d) / 15.0) ** 1.3)
        r = math.hypot(p[0] - cu, p[1] - cv)
        k = (r + ext) / r
        # tongues curl upward
        pts.append((cu + (p[0] - cu) * k, cv + (p[1] - cv) * k + 0.25 * ext))
    for outer_l, hole in ((pts, inner), (mask.mirror(pts), mask.mirror(inner))):
        kit.plate(mask.oriented(outer_l, True), hi=0.0034, chamfer=0.0009, edge_res=0.003,
                  holes=[mask.oriented(hole, False)])


def _mouth(kit: mask.MaskKit) -> None:
    """A raised oval surround round the mouth."""
    m = kit.shape.mouth_hole()
    if m is None:
        return
    lip_o = mask.offset_loop(mask.oriented(m, True), -0.0055)
    lip_i = mask.offset_loop(mask.oriented(m, True), -0.0010)
    kit.plate(mask.oriented(mask.resample(lip_o, 0.003), True), hi=0.0024, chamfer=0.0008, edge_res=0.003,
              holes=[mask.oriented(mask.resample(lip_i, 0.003), False)])


def _stripe(kit: mask.MaskKit) -> None:
    """A centre stripe panel from the crown down between the eyes to the tip of the nose."""
    stripe = mask.strip([(0.0, 0.104), (0.0, 0.050), (0.0, 0.010), (0.0, -0.034)], 0.020, 0.008)
    kit.plate(mask.resample(stripe, 0.004), hi=0.0016, chamfer=0.0007, edge_res=0.004)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_stripe, _flames, _mouth, _hood],
                    uv_mode="front")
