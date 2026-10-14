"""Wicker customisable base mask (``mask_base.wicker``, D-111).

An original harvest effigy: a rounded face woven like a basket (horizontal weavers passing over and
under vertical stakes, sculpted into the skin), round eyes and a small round mouth each bound with
a twisted rope ring, a fringe of braided straw tassels hanging from the jaw (``_mask_base.RimSurface``
flange cut into strands) and two forked twigs growing up and out of the brow like antlers. Folk and
handmade where the rest of the set is cast or carved; the forked twigs over the tasselled fringe are
the read at distance.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_wicker"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.100,
    "bottom": -0.106,
    "chin_point": 0.0,
    "side_arc": 0.100,
    "jaw_taper": 0.26,
    "brow": 0.6,
    "cheek": 0.7,
    "nose": 0.3,
    "jaw": 0.6,
    "eye_shape": "round",
    "eye_width": 0.026,
    "eye_height": 0.0230,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 0.0,
    "mouth": "open",
    "mouth_width": 0.020,
    "mouth_height": 0.016,
    "mouth_v": -0.064,
    "res": 0.0058,
    "res_back": 0.016,
    "edge_res": 0.0045,
}

ROW = 0.0105          # weaver height (m)
STAKE = 0.0120        # stake spacing (m)
CENTRE = (0.0, -0.010)
SPAN = (205.0, 335.0)  # the fringe hangs from the jaw, ear to ear
N_TASSELS = 15
TASSEL = 0.040


def _weave(u: float, v: float) -> float:
    """Over/under basket weave: each weaver bulges where it passes over a stake, dips where under."""
    row = math.floor(v / ROW)
    fv = (v / ROW) - row                       # 0..1 across the weaver
    across = math.sin(math.pi * fv) ** 0.6     # rounded weaver profile, grooves between rows
    phase = 0.0 if row % 2 == 0 else math.pi   # alternate rows are offset by one stake
    over = 0.5 + 0.5 * math.cos(2 * math.pi * u / (2 * STAKE) + phase)
    return 0.0012 * across + 0.0010 * across * over - 0.0008


def _ring(kit: mask.MaskKit, hole: mask.Loop2) -> None:
    """A twisted rope ring round a hole: a band of short slanted plates."""
    loop = mask.oriented(hole, True)
    outer = mask.resample(mask.offset_loop(loop, -0.0060), 0.0045)
    n = len(outer)
    c = (sum(p[0] for p in loop) / len(loop), sum(p[1] for p in loop) / len(loop))
    for k in range(0, n, 1):
        a, b = outer[k], outer[(k + 1) % n]
        ia = (c[0] + (a[0] - c[0]) * 0.78, c[1] + (a[1] - c[1]) * 0.78)
        ib = (c[0] + (b[0] - c[0]) * 0.70, c[1] + (b[1] - c[1]) * 0.70)
        kit.plate([ia, a, b, ib], hi=0.0026, lo=-0.0010, chamfer=0.0005, edge_res=0.003, res=0.02)


def _rings(kit: mask.MaskKit) -> None:
    for side in (1, -1):
        _ring(kit, kit.shape.eye_hole(side))
    m = kit.shape.mouth_hole()
    if m is not None:
        _ring(kit, m)


def _r_o(outline: mask.Loop2, phi: float) -> float:
    return mask.ray_radius(CENTRE, phi, outline)


def _at(outline: mask.Loop2, phi: float, rho: float) -> mask.Point2:
    r = _r_o(outline, phi) + rho
    return (CENTRE[0] + r * math.cos(phi), CENTRE[1] + r * math.sin(phi))


def _fringe(kit: mask.MaskKit) -> None:
    """Braided straw tassels: a narrow band under the jaw, then a strand per tassel, knotted mid-way."""
    outline = kit.shape.outline()
    t = float(kit.params["thickness"])
    rim = mask.RimSurface(kit.surf, outline, centre=CENTRE, inset=0.0015, depth=-t + 0.0015, tilt=0.04)
    m = kit.mat("primary")
    a0, a1 = math.radians(SPAN[0]), math.radians(SPAN[1])
    band_out = [_at(outline, a0 + (a1 - a0) * k / 40, 0.006) for k in range(41)]
    band_in = [_at(outline, a1 - (a1 - a0) * k / 40, -0.0015) for k in range(41)]
    mask.slab(kit.mb, rim, mask.oriented(band_out + band_in, True), [], -0.0026, 0.0, 0.0008, m, m, m,
              0.03, 0.03, 0.004, bottom=True)
    step = (a1 - a0) / N_TASSELS
    for k in range(N_TASSELS):
        phi = a0 + step * (k + 0.5)
        ln = TASSEL * (0.85 + 0.15 * math.cos(3.0 * k))
        w = step * 0.30
        strand = [_at(outline, phi - w, 0.004), _at(outline, phi - w * 0.6, ln * 0.45),
                  _at(outline, phi - w * 1.1, ln * 0.52), _at(outline, phi - w * 0.5, ln),
                  _at(outline, phi + w * 0.5, ln), _at(outline, phi + w * 1.1, ln * 0.52),
                  _at(outline, phi + w * 0.6, ln * 0.45), _at(outline, phi + w, 0.004)]
        mask.slab(kit.mb, rim, mask.oriented(strand, True), [], -0.0022, 0.0, 0.0006, m, m, m,
                  0.03, 0.03, 0.03, bottom=True)


def _twigs(kit: mask.MaskKit) -> None:
    """Two forked twigs growing up and out of the brow, each with a side shoot."""
    surf = kit.surf
    m = kit.mat("primary")
    for side in (1, -1):
        u, v = side * 0.046, 0.078
        p0 = surf.point(u, v, -0.003)
        out = Vector((float(side), 0.0, 0.0))
        main = mask.bezier3(p0, p0 + Vector((0.0, 0.004, 0.030)), p0 + out * 0.030 + Vector((0.0, -0.006, 0.060)),
                            p0 + out * 0.058 + Vector((0.0, -0.012, 0.074)), 10)
        mask.tube(kit.mb, main, lambda s: 0.0042 * (1 - s) + 0.0012, m, n=8, tip=True)
        fork = main[5]
        shoot = mask.bezier3(fork, fork + out * 0.010 + Vector((0.0, 0.002, 0.004)),
                             fork + out * 0.024 + Vector((0.0, 0.000, 0.004)),
                             fork + out * 0.032 + Vector((0.0, -0.002, -0.004)), 6)
        mask.tube(kit.mb, shoot, lambda s: 0.0026 * (1 - s) + 0.0010, m, n=7, tip=True)
        inner = main[7]
        sprig = mask.bezier3(inner, inner + Vector((0.0, 0.0, 0.010)), inner - out * 0.004 + Vector((0.0, 0.0, 0.018)),
                             inner - out * 0.006 + Vector((0.0, -0.002, 0.024)), 5)
        mask.tube(kit.mb, sprig, lambda s: 0.0020 * (1 - s) + 0.0009, m, n=6, tip=True)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_rings, _fringe, _twigs],
                    surface_extra=_weave, uv_mode="front")
