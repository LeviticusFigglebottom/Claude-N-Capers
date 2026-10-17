"""Bust customisable base mask (``mask_base.bust``, achievement reward, Gallery Night).

The face of an original classical marble portrait bust, as in a museum gallery, cut off as a face
plate (no neck or shoulders): smooth, idealised features with a straight nose running on from the
brow, full sculpted lips, a rounded chin and soft cheeks; blank sculpted eyes with a crisp upper lid
and a soft lower lid round the eye holes the wearer looks through; and a fringe of tight snail
curls across the brow, three staggered rows on a raised hair cap whose curls scallop the top of the
outline, with a short curled lock in front of each temple. Calm and expressionless, the opposite of
the snarling and grinning bases.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

import _mask_base as mask

ASSET_ID = "mask_base_bust"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.094,
    "bottom": -0.116,
    "side_arc": 0.098,
    "jaw_taper": 0.22,
    "brow": 1.6,
    "cheek": 1.0,
    "nose": 1.8,
    "jaw": 1.8,
    "eye_shape": "almond",
    "eye_width": 0.031,
    "eye_height": 0.0120,
    "eye_spacing": 0.066,
    "eye_tilt_deg": 2.0,
    "mouth": "none",
    "mouth_width": 0.040,
    "mouth_v": -0.070,
    "res": 0.0100,
    "fit_clearance": 0.0045,
    "res_back": 0.016,
    "edge_res": 0.0055,
}

HAIRLINE = 0.050         # lowest point of the fringe on the centre line (v)
REFINE = [(0.0, -0.068, 0.026, 0.016, 0.0028), (0.0, -0.050, 0.020, 0.014, 0.0040),
          (0.0, -0.012, 0.011, 0.032, 0.0042)]  # lips, nose tip, nose ridge


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _hairline(u: float) -> float:
    """Lower edge of the hair cap: a shallow arch rising to the temples."""
    return HAIRLINE + 0.012 * (abs(u) / 0.080) ** 2


def _rows() -> list[list[tuple[float, float, float]]]:
    """Curl centres (u, v, radius) in three staggered rows, front (lowest) first."""
    rows = []
    specs = [(9, 0.0, 0.0098), (8, 0.017, 0.0094), (7, 0.033, 0.0090)]
    for n, dv, r in specs:
        row = []
        span = 0.064 - 0.006 * (dv / 0.017)
        for k in range(n):
            # a deterministic carver's irregularity: no two curls quite the same size or height
            j = math.sin(2.39 * k + 7.1 * n)
            u = -span + 2 * span * k / (n - 1) + 0.0010 * math.sin(1.7 * k + n)
            row.append((u, _hairline(u) + 0.0055 + dv + 0.0010 * j, r * (1 + 0.06 * j)))
        rows.append(row)
    return rows


def _outline_fn(shape: mask.MaskShape) -> mask.Loop2:
    base = shape.outline()
    caps = [mask.disc(u, v, r + 0.0018, 16) for row in _rows()[1:] for (u, v, r) in row]
    keep: list[mask.Point2] = []
    return mask.oriented(mask.radial_union([base] + caps, (0.0, -0.005), n=220, keep=keep), True)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # bring the lower face and the hair forward to where the crew fit would push them anyway, so the fit
    # does not flatten the lips and chin against the nose
    f += 0.015 * _smooth(-0.034, -0.064, v) * (1 - 0.3 * _smooth(-0.095, -0.120, v))
    f += 0.009 * _smooth(HAIRLINE - 0.004, HAIRLINE + 0.020, v)
    # sculpted lips: a bowed upper lip, a fuller lower lip, a crisp parting line turned up at the corners
    mv = float(PARAMS["mouth_v"])
    f += 0.0048 * _g(au, 0.016) * _g(v - mv - 0.0045 - 0.0012 * _g(au - 0.006, 0.004), 0.0030)
    f += 0.0058 * _g(au, 0.013) * _g(v - mv + 0.0058, 0.0042)
    f -= 0.0032 * _g(au, 0.019) * _g(v - mv - 0.0012 * (au / 0.02) ** 2, 0.0013)
    # Greek profile: fill the dip at the nose bridge so the nose runs straight on from the brow
    f += 0.0055 * _g(au, 0.011) * _g(v - 0.006, 0.014)
    # smooth, rounded forehead under the hair, soft temples
    f += 0.0020 * _g(au, 0.040) * _g(v - 0.040, 0.016)
    # full lower lip and the dimple under it, a rounded chin
    f += 0.0015 * _g(au, 0.014) * _g(v + 0.078, 0.004)
    f -= 0.0018 * _g(au, 0.012) * _g(v + 0.086, 0.004)
    f -= 0.0010 * _g(au, 0.020) * _g(v + 0.100, 0.012)
    # philtrum
    f -= 0.0008 * _g(au, 0.0025) * _smooth(-0.050, -0.056, v) * _smooth(-0.066, -0.062, v)
    # the hair cap sits on a slightly raised skull line
    f += 0.0020 * _smooth(-0.004, 0.004, v - _hairline(u))
    return f


def _cap(kit: mask.MaskKit) -> None:
    """Raised hair cap: the part of the outline above the hairline (the curls sit on it)."""
    outline = mask.oriented(_outline_fn(kit.shape), True)  # CCW: +u side, over the top, to -u
    n = len(outline)
    above = [p[1] > _hairline(p[0]) for p in outline]
    start = next(i for i in range(n) if not above[i - 1] and above[i])
    chain: mask.Loop2 = []
    i = start
    while above[i % n]:
        chain.append(outline[i % n])
        i += 1
    u0, u1 = chain[-1][0], chain[0][0]
    lower = [(u0 + (u1 - u0) * k / 24, _hairline(u0 + (u1 - u0) * k / 24)) for k in range(1, 24)]
    loop = mask.offset_loop(mask.oriented(chain + lower, True), 0.0015)
    kit.plate(mask.oriented(loop, True), hi=0.0024, lo=-0.0020, chamfer=0.0010, edge_res=0.006, res=0.03)


def _spiral_loop(cu: float, cv: float, r0: float, sense: int, start: float, turns: float = 1.35,
                 n: int = 24) -> mask.Loop2:
    pts = []
    for k in range(n + 1):
        t = k / n
        a = start + sense * 2 * math.pi * turns * t
        r = r0 * (1 - 0.74 * t)
        pts.append((cu + r * math.cos(a), cv + r * math.sin(a)))
    return mask.strip(pts, 0.42 * r0, 0.16 * r0)


def _curls(kit: mask.MaskKit) -> None:
    """Snail curls in three rows, alternating their turn; the front row stands highest."""
    for ri, row in enumerate(_rows()):
        hi = 0.0062 - 0.0010 * ri
        for k, (u, v, r) in enumerate(row):
            sense = 1 if (k + ri) % 2 else -1
            start = math.pi * (1.5 + 0.37 * k + 0.5 * ri)
            loop = _spiral_loop(u, v, r, sense, start)
            kit.plate(mask.oriented(loop, True), hi=hi, lo=0.0010, chamfer=0.0008,
                      edge_res=0.0034 if ri == 0 else 0.0040, res=0.03)
    # a curled lock in front of each temple
    for s in (1, -1):
        loop = _spiral_loop(s * 0.082, 0.032, 0.0110, s, math.pi * 0.5, turns=1.3)
        kit.plate(mask.oriented(loop, True), hi=0.0040, lo=-0.0020, chamfer=0.0008, edge_res=0.0036, res=0.03)


def _lids(kit: mask.MaskKit) -> None:
    """Blank sculpted eyes: a crisp upper lid and a thin lower lid round each opening."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    cu = sum(p[0] for p in eye) / len(eye)
    cv = sum(p[1] for p in eye) / len(eye)
    outer = mask.almond(cu, cv + 0.0016, 0.0200, 0.0100, point=1.6, tilt_deg=2.0, lower=0.70)
    inner = mask.offset_loop(eye, -0.0005)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(mask.oriented(o, True), holes=[mask.oriented(h, False)], hi=0.0018, chamfer=0.0008,
                  edge_res=0.0032)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_cap, _curls, _lids],
                    surface_extra=_sculpt, outline_fn=_outline_fn, uv_mode="front", refine=REFINE)
