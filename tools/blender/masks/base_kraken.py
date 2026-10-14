"""Kraken customisable base mask (``mask_base.kraken``, D-111).

An original octopus face: a tall, bulbous mantle that domes up over the forehead with a raised
seam down its centre, big round eyes ringed by thick lids with a heavy brow fold over each, a
smooth slope down to the siphon (a short tube on the centre line under the nose), and six
tentacles that grow out of the lower face, run down over the cheeks and jaw and leave the chin,
curling outward at the tips like a beard, a row of suckers on the underside of each. The mask is
heavy at the bottom and uneven at the edge; nothing else in the set has hanging parts.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_kraken"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.112,
    "top_peak": 0.010,
    "bottom": -0.100,
    "chin_point": 0.0,
    "side_arc": 0.094,
    "jaw_taper": 0.36,
    "brow": 0.6,
    "cheek": 0.6,
    "nose": 0.0,
    "jaw": 0.5,
    "eye_shape": "round",
    "eye_width": 0.030,
    "eye_height": 0.0200,
    "eye_spacing": 0.070,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "res": 0.0095,
    "res_back": 0.017,
    "edge_res": 0.0055,
}

#: Tentacle roots (u, v) on the lower face, from the centre outward (mirrored).
ROOTS = [(0.013, -0.050), (0.036, -0.058), (0.060, -0.054)]
#: How far below the chin each pair hangs (m) and how far its tip curls out (m).
DROP = [0.075, 0.062, 0.046]
CURL = [0.018, 0.026, 0.030]
ROOT_R = [0.0095, 0.0090, 0.0080]
SUCKERS = 6


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # the mantle: a broad dome over the forehead, highest above the brow
    f += 0.020 * _g(au, 0.060) * _smooth(0.010, 0.060, v) * (1.0 - 0.4 * _smooth(0.085, 0.115, v))
    # brow folds: a ridge arching over each eye
    f += 0.0045 * _g(math.hypot(au - 0.035, (v - 0.004) * 1.2) - 0.024, 0.0045) * _smooth(-0.004, 0.006, v)
    # the slope down to the siphon, then a soft hollow either side of it
    f += 0.006 * _g(au, 0.016) * _g(v + 0.032, 0.016)
    f -= 0.0030 * _g(au - 0.030, 0.012) * _g(v + 0.030, 0.014)
    return f


def _seam(kit: mask.MaskKit) -> None:
    """A raised seam down the centre of the mantle, from its crown to the brow."""
    seam = mask.strip([(0.0, 0.112), (0.0, 0.070), (0.0, 0.030)], 0.0030, 0.0055)
    kit.plate(mask.resample(seam, 0.004), hi=0.0022, chamfer=0.0009, edge_res=0.004)


def _lids(kit: mask.MaskKit) -> None:
    """A thick round lid ring round each eye."""
    for side in (1, -1):
        eye = mask.oriented(kit.shape.eye_hole(side), True)
        outer = mask.offset_loop(eye, -0.0060)
        inner = mask.offset_loop(eye, -0.0008)
        kit.plate(mask.resample(outer, 0.004), hi=0.0030, chamfer=0.0012, edge_res=0.004,
                  holes=[mask.oriented(mask.resample(inner, 0.004), False)])


def _siphon(kit: mask.MaskKit) -> None:
    """The siphon: a short, flared tube on the centre line under the nose, pointing down and out."""
    surf = kit.surf
    p0 = surf.point(0.0, -0.036, -0.002)
    nrm = surf.normal(0.0, -0.036)
    path = [p0, p0 + nrm * 0.008 + Vector((0.0, 0.0, -0.002)), p0 + nrm * 0.014 + Vector((0.0, 0.0, -0.006))]
    mask.tube(kit.mb, path, lambda s: 0.0065 + 0.0025 * s * s, kit.mat("primary"), n=12, tip=False)


def _tentacle_path(kit: mask.MaskKit, side: int, i: int) -> list[Vector]:
    surf = kit.surf
    u0, v0 = ROOTS[i]
    u0 *= side
    bottom = float(kit.params["bottom"])
    pts = []
    # on the face: from the root down to the shell's lower edge, riding just above the skin
    for k in range(9):
        t = k / 8
        v = v0 + (bottom - 0.004 - v0) * t
        u = u0 * (1.0 + 0.30 * t)
        pts.append(surf.point(u, v, 0.0030 + 0.0040 * t))
    # off the chin: hang down, then curl the tip outward and up
    last = pts[-1]
    nrm = surf.normal(u0 * 1.3, bottom)
    out = Vector((float(side), 0.0, 0.0))
    for k in range(1, 15):
        t = k / 14
        a = math.pi * 1.1 * _smooth(0.35, 1.0, t)
        down = DROP[i] * min(1.0, t / 0.75)
        q = last + nrm * (0.010 * t) + Vector((0.0, 0.0, -down))
        q += out * (CURL[i] * (1.0 - math.cos(a)) * 0.5) + Vector((0.0, 0.0, CURL[i] * math.sin(a) * 0.45))
        pts.append(q)
    return pts


def _tentacles(kit: mask.MaskKit) -> None:
    """Six tentacles: tubes from the lower face over the jaw and off the chin, suckers underneath."""
    m = kit.mat("primary")
    for i in range(len(ROOTS)):
        for side in (1, -1):
            path = _tentacle_path(kit, side, i)
            r0 = ROOT_R[i]
            mask.tube(kit.mb, path, lambda s, r0=r0: r0 * (1.0 - 0.80 * s ** 0.9) + 0.0012, m, n=10, tip=True)
            # suckers along the hanging part, on the side facing back toward the wearer's chest
            hang = path[9:]
            for k in range(SUCKERS):
                s = (k + 0.5) / SUCKERS
                j = min(len(hang) - 2, int(s * (len(hang) - 1)))
                c = hang[j]
                tan = (hang[j + 1] - hang[j]).normalized()
                back = Vector((0.0, -1.0, 0.0))
                back = (back - tan * back.dot(tan)).normalized()
                frac = (9 + j) / (len(path) - 1)
                r = r0 * (1.0 - 0.80 * frac ** 0.9) + 0.0012
                mask.sphere(kit.mb, c + back * (r * 0.85), max(0.0012, r * 0.42), m, n=6, rings=3, axis=back)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_seam, _lids, _siphon, _tentacles],
                    surface_extra=_sculpt, uv_mode="front")
