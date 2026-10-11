"""Ram customisable base mask (``mask_base.ram``, D3-03).

An original ram: a long face with a high, convex Roman nose running from the brow down to a broad,
blunt muzzle with slanted nostrils and a cleft lip, heavy-lidded eyes under a low brow, a cap of
round wool curls over the forehead and two massive ridged horns that leave the top of the head,
sweep back and out, and curl down and forward round the cheeks. The horn spirals widen the
silhouette at eye level; nothing else in the set has that shape.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_ram"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.098,
    "top_peak": 0.006,
    "bottom": -0.124,
    "chin_point": 0.004,
    "side_arc": 0.098,
    "jaw_taper": 0.40,
    "brow": 1.1,
    "cheek": 0.5,
    "nose": 0.0,
    "jaw": 0.6,
    "eye_shape": "almond",
    "eye_width": 0.034,
    "eye_height": 0.0135,
    "eye_spacing": 0.070,
    "eye_tilt_deg": -3.0,
    "mouth": "none",
    "res": 0.0090,
    "res_back": 0.016,
    "edge_res": 0.0050,
}

HORN_ROOT = (0.058, 0.078)   # (u, v) where each horn leaves the forehead
ROOT_R = 0.0200              # horn radius at the root
CURL_C = (0.015, 0.012)      # spiral centre (Blender y, z)
CURL_SWEEP = 350.0           # degrees of curl from the root to the tip
CURL_TURN = 38.0             # the curl plane turned out of the sagittal plane (front of the curl inward)
REFINE = [(0.0, -0.088, 0.034, 0.022, 0.0045)]  # muzzle: nostrils and the cleft


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # Roman nose: a broad convex ridge from the brow to the muzzle, highest mid-way
    t = _smooth(0.018, -0.030, v) * _smooth(-0.122, -0.080, v)
    f += 0.017 * t * _g(au, 0.020 + 0.008 * _smooth(-0.04, -0.09, v))
    # blunt muzzle pad
    f += 0.010 * _g(au, 0.030) * _g(v + 0.094, 0.020)
    # slanted nostrils: pits rising toward the centre
    d = math.hypot((au - 0.016) * 0.8 + (v + 0.084) * 0.5, (v + 0.084) - (au - 0.016) * 0.5)
    f -= 0.0045 * _g(d, 0.0045)
    # cleft lip: a groove down from between the nostrils, then out to each side
    f -= 0.0022 * _g(au, 0.0018) * _smooth(-0.090, -0.098, v) * _smooth(-0.122, -0.110, v)
    f -= 0.0020 * _g(v + 0.104 + 0.25 * au, 0.0020) * _smooth(0.026, 0.008, au) * _smooth(0.0, 0.004, au)
    # sunken temples under the horn roots, hollow cheeks under the eyes
    f -= 0.0030 * _g(au - 0.070, 0.016) * _g(v - 0.030, 0.020)
    f -= 0.0025 * _g(au - 0.045, 0.014) * _g(v + 0.045, 0.018)
    return f


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    """The face outline with a broad, blunt muzzle in place of a pointed chin."""
    muzzle = mask.superellipse(0.0, -0.096, 0.036, 0.020, 0.028, 3.2, n=80)
    return mask.radial_union([shape.outline(), muzzle], centre=(0.0, -0.010), n=360)


def _curls(kit: mask.MaskKit) -> None:
    """A cap of round wool curls over the forehead, staggered rows narrowing toward the top."""
    rows = [(0.040, (0.0, 0.019, 0.038, 0.057)), (0.057, (0.0095, 0.0285, 0.0475)),
            (0.074, (0.0, 0.019, 0.038)), (0.090, (0.0095, 0.0285))]
    for v, us in rows:
        for u in us:
            r = 0.0098 - 0.0007 * (v - 0.040) / 0.05
            for cu in ((u,) if u == 0.0 else (u, -u)):
                kit.plate(mask.disc(cu, v, r, 12), hi=0.0026, chamfer=0.0013, edge_res=0.006, res=0.02)
                kit.plate(mask.disc(cu + 0.0015, v + 0.0012, r * 0.48, 8), hi=0.0044, chamfer=0.0010,
                          edge_res=0.006, res=0.02)


def _lids(kit: mask.MaskKit) -> None:
    """Heavy upper lid over each eye."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    upper = [p for p in mask.offset_loop(eye, -0.0010) if p[1] > -0.002]
    upper.sort(key=lambda p: p[0])
    lid = mask.strip([(x, y + 0.0028) for x, y in upper], 0.0062, 0.0062)
    for loop in mask.mirrored(mask.resample(lid, 0.0045)):
        kit.plate(loop, hi=0.0024, chamfer=0.0009, edge_res=0.0045)


def _horns(kit: mask.MaskKit) -> None:
    """Two ridged horns: up and back from the forehead, then down and forward round the cheek."""
    surf = kit.surf
    n_sec, n_ring = 52, 12
    for side in (1, -1):
        # the root is buried in the forehead; its underside is clamped to the shell wall (below)
        p0 = surf.point(side * HORN_ROOT[0], HORN_ROOT[1], -0.004)
        skin = surf.point(side * HORN_ROOT[0], HORN_ROOT[1], 0.0)
        nrm = surf.normal(side * HORN_ROOT[0], HORN_ROOT[1])
        dy, dz = p0.y - CURL_C[0], p0.z - CURL_C[1]
        th0 = math.atan2(dz, dy / 0.9)
        r0 = math.hypot(dy / 0.9, dz)

        ct, st = math.cos(math.radians(CURL_TURN)), math.sin(math.radians(CURL_TURN))

        def curl(s: float, p0: Vector = p0, th0: float = th0, r0: float = r0, side: int = side) -> Vector:
            th = th0 + math.radians(CURL_SWEEP) * s
            r = r0 * (1 - 0.72 * s ** 0.85)
            yy = 0.9 * r * math.cos(th)
            x = abs(p0.x) + 0.046 * _smooth(0.0, 0.30, s) + 0.010 * s - st * yy
            return Vector((side * x, CURL_C[0] + ct * yy, CURL_C[1] + r * math.sin(th)))

        fix = p0 - curl(0.0)

        def centre(s: float, curl=curl, fix: Vector = fix) -> Vector:
            return curl(s) + fix * (1 - _smooth(0.0, 0.25, s))

        sections = []
        for k in range(n_sec + 1):
            s = k / n_sec
            c = centre(s)
            tan = (centre(min(1.0, s + 0.005)) - centre(max(0.0, s - 0.005))).normalized()
            sx = Vector((float(side), 0.0, 0.0))
            a = (sx - tan * sx.dot(tan)).normalized()
            b = tan.cross(a).normalized()
            rad = (ROOT_R - 0.0035) * (1 - s) ** 0.8 + 0.0035
            rad *= 1.0 + 0.07 * math.cos(2 * math.pi * 11.0 * s) * (1 - 0.6 * s)  # growth ridges
            sec = []
            for j in range(n_ring):
                ang = 2 * math.pi * j / n_ring
                # a flattened, slightly keeled section (the outer face of a ram horn is broad)
                ca, sa = math.cos(ang), math.sin(ang)
                q = c + a * (rad * 0.90 * ca) + b * (rad * sa * (1.0 + 0.12 * max(ca, 0.0)))
                d = (q - skin).dot(nrm)
                if d < -0.0035:  # never deeper than the shell wall: keep clear of the face
                    q = q + nrm * (-0.0035 - d)
                sec.append(q)
            sections.append(sec)
        kit.loft(sections, cap_start=True)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_curls, _lids, _horns],
                    surface_extra=_sculpt, outline_fn=_outline, uv_mode="front", refine=REFINE)
