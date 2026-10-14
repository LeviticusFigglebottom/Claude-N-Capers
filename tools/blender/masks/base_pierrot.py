"""Pierrot customisable base mask (``mask_base.pierrot``, D-111).

An original sad clown: a smooth, pale oval face with high, thin brows arched in surprise, softly
lowered lids, a small straight nose, small closed lips turned down at the corners, a single
teardrop raised under the left eye (the mask's one asymmetric detail, a plate, so the outline stays
symmetric) and a deep pleated ruff that leaves the shell's lower edge from ear to ear
(``_mask_base.RimSurface``). The clean face over the frilled collar is the read at distance; the
large smooth face is a canvas for patterns.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_pierrot"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.102,
    "bottom": -0.112,
    "chin_point": 0.002,
    "side_arc": 0.094,
    "jaw_taper": 0.40,
    "brow": 0.6,
    "cheek": 0.8,
    "nose": 0.8,
    "jaw": 0.8,
    "eye_shape": "almond",
    "eye_width": 0.033,
    "eye_height": 0.0105,
    "eye_spacing": 0.066,
    "eye_tilt_deg": -10.0,
    "mouth": "closed",
    "mouth_width": 0.030,
    "mouth_v": -0.070,
    "res": 0.0085,
    "res_back": 0.015,
    "edge_res": 0.0050,
}

CENTRE = (0.0, -0.010)       # polar centre of the ruff
SPAN = (198.0, 342.0)        # degrees covered by the ruff (under the face, ear to ear)
N_PLEATS = 22
DEPTH = 0.034                # ruff depth beyond the shell edge (m)
TUCK = 0.0015
TILT = -0.05                 # the ruff tips slightly forward, like a starched collar
REFINE = [(0.0, -0.070, 0.022, 0.010, 0.0040)]  # lips


def _r_o(outline: mask.Loop2, phi: float) -> float:
    return mask.ray_radius(CENTRE, phi, outline)


def _at(outline: mask.Loop2, phi: float, rho: float) -> mask.Point2:
    r = _r_o(outline, phi) + rho
    return (CENTRE[0] + r * math.cos(phi), CENTRE[1] + r * math.sin(phi))


def _ruff(kit: mask.MaskKit) -> None:
    """The ruff: a scalloped flange (a round lobe per pleat) and a raised fold line on every pleat."""
    outline = kit.shape.outline()
    t = float(kit.params["thickness"])
    rim = mask.RimSurface(kit.surf, outline, centre=CENTRE, inset=0.0015, depth=-t + 0.0015, tilt=TILT)
    m = kit.mat("primary")
    a0, a1 = math.radians(SPAN[0]), math.radians(SPAN[1])
    step = (a1 - a0) / N_PLEATS
    outer: mask.Loop2 = [_at(outline, a0, 0.0)]
    for k in range(N_PLEATS):
        for j in range(1, 7) if k else range(7):
            s = j / 6
            rho = DEPTH * (0.80 + 0.20 * math.sin(math.pi * s))
            outer.append(_at(outline, a0 + step * (k + s), rho))
    outer[-1] = _at(outline, a1, 0.0)
    inner = [_at(outline, a1 - (a1 - a0) * k / 60, -TUCK) for k in range(61)]
    mask.slab(kit.mb, rim, mask.oriented(outer + inner, True), [], -0.0026, 0.0, 0.0009, m, m, m,
              0.03, 0.03, 0.03, bottom=True)
    for k in range(1, N_PLEATS):
        phi = a0 + step * k
        fold = [_at(outline, phi - 0.06 * step, 0.002), _at(outline, phi, DEPTH * 0.82),
                _at(outline, phi + 0.06 * step, 0.002)]
        mask.slab(kit.mb, rim, fold, [], -0.001, 0.0022, 0.0006, m, m, None, 0.03, 0.03, 0.03, bottom=False)


def _brows(kit: mask.MaskKit) -> None:
    """High, thin brows arched in surprise."""
    for loop in mask.mirrored(mask.strip([(0.014, 0.034), (0.030, 0.046), (0.048, 0.044), (0.060, 0.034)],
                                         0.0024, 0.0016)):
        kit.plate(mask.resample(loop, 0.003), hi=0.0016, chamfer=0.0006, edge_res=0.003)


def _lids(kit: mask.MaskKit) -> None:
    """Softly lowered upper lids."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    upper = sorted((p for p in mask.offset_loop(eye, -0.0010) if p[1] > -0.003), key=lambda p: p[0])
    lid = mask.strip([(x, y + 0.0028) for x, y in upper], 0.0060, 0.0060)
    for loop in mask.mirrored(mask.resample(lid, 0.004)):
        kit.plate(loop, hi=0.0018, chamfer=0.0008, edge_res=0.004)


def _tear(kit: mask.MaskKit) -> None:
    """A single teardrop under the left eye (Blender +X = the wearer's left)."""
    drop = mask.spline_loop([(0.034, -0.016), (0.039, -0.030), (0.034, -0.036), (0.029, -0.030)], samples=5,
                            sharp=[0])
    kit.plate(mask.resample(drop, 0.0025), hi=0.0022, chamfer=0.0008, edge_res=0.0025)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_brows, _lids, _tear, _ruff],
                    uv_mode="front", refine=REFINE)
