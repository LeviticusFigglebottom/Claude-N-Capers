"""Sunburst customisable base mask (``mask_base.sunburst``, D3-03).

An original radiant mask: a calm, symmetrical face (smooth brow, long straight nose, softly lowered
lids, small closed lips) framed by a crown of rays. The crown is a flange that leaves the shell's
edge all round the top and sides (``_mask_base.RimSurface``) and spreads flat instead of wrapping
round the head: a raised halo band hugging the face and fifteen pointed rays, long and short in
turn, each long ray with a raised spine. Open below the chin. The spiky disc is the read at
distance; the calm face is a large clean canvas for patterns.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_sunburst"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.100,
    "bottom": -0.114,
    "chin_point": 0.004,
    "side_arc": 0.098,
    "jaw_taper": 0.36,
    "brow": 0.7,
    "cheek": 0.9,
    "nose": 0.9,
    "jaw": 0.9,
    "eye_shape": "almond",
    "eye_width": 0.035,
    "eye_height": 0.0115,
    "eye_spacing": 0.068,
    "eye_tilt_deg": -4.0,
    "mouth": "closed",
    "mouth_width": 0.036,
    "mouth_v": -0.070,
    "res": 0.0085,
    "res_back": 0.015,
    "edge_res": 0.0050,
}

CENTRE = (0.0, -0.006)       # polar centre of the crown
SPAN = (-62.0, 242.0)        # degrees covered by the crown (open under the chin)
N_RAYS = 15
LONG, SHORT = 0.044, 0.028   # ray lengths beyond the shell edge (m)
BAND = 0.009                 # halo band width beyond the edge
TUCK = 0.0015               # how far the crown runs under the shell rim
TILT = 0.10                  # the crown sweeps slightly back
REFINE = [(0.0, -0.070, 0.024, 0.012, 0.0040)]  # lips


def _ray_angles() -> list[float]:
    step = (SPAN[1] - SPAN[0]) / N_RAYS
    return [math.radians(SPAN[0] + step * (k + 0.5)) for k in range(N_RAYS)]


def _r_o(outline: mask.Loop2, phi: float) -> float:
    return mask.ray_radius(CENTRE, phi, outline)


def _at(outline: mask.Loop2, phi: float, rho: float) -> mask.Point2:
    r = _r_o(outline, phi) + rho
    return (CENTRE[0] + r * math.cos(phi), CENTRE[1] + r * math.sin(phi))


def _crown_loop(outline: mask.Loop2) -> mask.Loop2:
    """The crown in (u, v): the inner arc tucked under the rim, then ray tips and valleys."""
    a0, a1 = math.radians(SPAN[0]), math.radians(SPAN[1])
    rays = _ray_angles()
    half = (a1 - a0) / N_RAYS * 0.5
    outer: mask.Loop2 = [_at(outline, a0, 0.0)]
    for k, phi in enumerate(rays):
        ln = LONG if k % 2 == 0 else SHORT
        outer.append(_at(outline, phi - half, BAND))
        outer.append(_at(outline, phi, BAND + ln))
    outer.append(_at(outline, a1 - 0.0, BAND))
    outer.append(_at(outline, a1, 0.0))
    inner = [_at(outline, a1 - (a1 - a0) * k / 60, -TUCK) for k in range(61)]
    return mask.oriented(outer + inner, True)


def _rim(kit: mask.MaskKit, outline: mask.Loop2) -> mask.RimSurface:
    t = float(kit.params["thickness"])
    return mask.RimSurface(kit.surf, outline, centre=CENTRE, inset=0.0015, depth=-t + 0.0015, tilt=TILT)


def _crown(kit: mask.MaskKit) -> None:
    """The ray crown, the halo band and a spine on every long ray."""
    outline = kit.shape.outline()
    rim = _rim(kit, outline)
    m = kit.mat("primary")
    mask.slab(kit.mb, rim, _crown_loop(outline), [], -0.0028, 0.0, 0.0010, m, m, m, 0.03, 0.03, 0.03,
              bottom=True)
    a0, a1 = math.radians(SPAN[0]), math.radians(SPAN[1])
    band_out = [_at(outline, a0 + (a1 - a0) * k / 72, BAND - 0.001) for k in range(73)]
    band_in = [_at(outline, a1 - (a1 - a0) * k / 72, 0.0015) for k in range(73)]
    mask.slab(kit.mb, rim, mask.oriented(band_out + band_in, True), [], -0.001, 0.0022, 0.0009, m, m, None,
              0.03, 0.03, 0.006, bottom=False)
    half = (a1 - a0) / N_RAYS * 0.5
    for k, phi in enumerate(_ray_angles()):
        if k % 2:
            continue
        spine = [_at(outline, phi - half * 0.16, BAND + 0.001), _at(outline, phi, BAND + LONG * 0.78),
                 _at(outline, phi + half * 0.16, BAND + 0.001)]
        mask.slab(kit.mb, rim, spine, [], -0.001, 0.0018, 0.0007, m, m, None, 0.03, 0.03, 0.03, bottom=False)


def _lids(kit: mask.MaskKit) -> None:
    """Softly lowered upper lids: a smooth band over the top of each eye."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    upper = sorted((p for p in mask.offset_loop(eye, -0.0010) if p[1] > -0.003), key=lambda p: p[0])
    lid = mask.strip([(x, y + 0.0030) for x, y in upper], 0.0070, 0.0070)
    for loop in mask.mirrored(mask.resample(lid, 0.004)):
        kit.plate(loop, hi=0.0020, chamfer=0.0009, edge_res=0.004)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_lids, _crown],
                    uv_mode="front", refine=REFINE)
