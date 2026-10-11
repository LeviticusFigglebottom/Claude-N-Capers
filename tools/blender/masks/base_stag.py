"""Stag customisable base mask (``mask_base.stag``, D3-03).

An original young stag: a long, gentle deer face with a soft brow, large dark-rimmed almond eyes
set wide, a tapering bridge running down to a broad muzzle under a rounded nose pad with a split
lip, a forelock tuft between the antlers, two broad leaf-shaped ears held out flat to the sides
and two short antlers (a burr ring, a beam sweeping up and out, a brow tine pointing forward and
a small fork at the top). Ears out sideways plus antlers up make a wide "T" read at distance,
unlike the upright ears of the vulpine and the cat.

The ears are built on a shallow dish behind the shell edge (``_mask_base.DishSurface``) so they
can reach past the side of the head without wrapping round it.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_stag"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.096,
    "top_peak": 0.010,
    "bottom": -0.120,
    "chin_point": 0.006,
    "side_arc": 0.098,
    "jaw_taper": 0.46,
    "brow": 0.9,
    "cheek": 0.8,
    "nose": 0.0,
    "jaw": 0.7,
    "eye_shape": "almond",
    "eye_width": 0.036,
    "eye_height": 0.0160,
    "eye_spacing": 0.074,
    "eye_tilt_deg": -8.0,
    "mouth": "none",
    "res": 0.0090,
    "res_back": 0.016,
    "edge_res": 0.0050,
}

ANTLER_ROOT = (0.034, 0.080)
# ear on the dish: root (hidden behind the shell edge), tip, half width, tilt of the tip up (m)
EAR_ROOT = (0.084, 0.044)
EAR_TIP = (0.142, 0.072)
EAR_W = 0.034
EAR_EDGE = (0.106, 0.046)  # (u, v) on the shell edge where the ear emerges
REFINE = [(0.0, -0.088, 0.030, 0.026, 0.0045)]


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    au = abs(u)
    f = 0.0
    # a narrow bridge running from between the eyes down to the muzzle
    t = _smooth(0.012, -0.030, v) * _smooth(-0.120, -0.090, v)
    f += 0.012 * t * _g(au, 0.016 + 0.010 * _smooth(-0.03, -0.09, v))
    # broad soft muzzle and the split upper lip under the nose pad
    f += 0.008 * _g(au, 0.032) * _g(v + 0.092, 0.020)
    f -= 0.0025 * _g(au, 0.0020) * _g(v + 0.100, 0.006)
    # the tear-duct groove under the inner corner of each eye
    f -= 0.0035 * _g(au - 0.026 + 0.25 * (v + 0.010), 0.0035) * _smooth(0.0, -0.010, v) * _smooth(-0.045, -0.025, v)
    # the ear tabs stand out flat instead of following the head round
    f += 0.50 * max(0.0, au - 0.090) ** 1.15 * _g(v - 0.046, 0.030)
    # the forelock bunched up between the antlers
    f += 0.0045 * _g(au, 0.022) * _g(v - 0.068, 0.018)
    return f


def _outline(shape: mask.MaskShape) -> mask.Loop2:
    """The face outline with a short tab at each side under the ear root."""
    tab = mask.superellipse(0.096, 0.046, 0.016, 0.017, 0.017, 2.6, n=32)
    return mask.radial_union([shape.outline(), tab, mask.mirror(tab)], centre=(0.0, -0.004), n=400)


def _lids(kit: mask.MaskKit) -> None:
    """A dark-rim band round each large eye, drawn out to a point at the outer corner."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0010)
    outer = mask.offset_loop(eye, -0.0050, max_miter=1.6)
    outer = [(x + 0.004 * _smooth(0.040, 0.054, x), y - 0.003 * _smooth(0.040, 0.054, x)) for x, y in outer]
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0018, chamfer=0.0006, edge_res=0.004)


def _nose(kit: mask.MaskKit) -> None:
    """Rounded nose pad, wider than tall, with two nostril commas cut into its lower edge."""
    pad = []
    for k in range(36):
        a = 2 * math.pi * k / 36
        c, sn = math.cos(a), math.sin(a)
        r = 1.0 - 0.18 * max(0.0, -sn) ** 3 * (1 - abs(c))  # flattened, notched underside
        pad.append((0.021 * c * r, -0.078 + 0.012 * sn * r))
    kit.plate(pad, hi=0.0045, chamfer=0.0018, edge_res=0.0035)
    for side in (1, -1):
        nos = mask.leaf((side * 0.006, -0.078), (side * 0.015, -0.084), 0.0050, n=6)
        kit.plate(nos, hi=0.0050, chamfer=0.0008, edge_res=0.003)


def _forelock(kit: mask.MaskKit) -> None:
    """Three soft locks of the forelock between the antler roots."""
    for root, tip, w in (((0.0, 0.052), (0.0, 0.096), 0.016), ((0.010, 0.050), (0.026, 0.086), 0.012)):
        lock = mask.leaf(root, tip, w, bend=0.06 if root[0] else 0.0, n=8, fullness=0.6)
        for loop in ([lock] if root[0] == 0.0 else mask.mirrored(lock)):
            kit.plate(loop, hi=0.0024, chamfer=0.0008, edge_res=0.004)


def _ear_loop() -> mask.Loop2:
    return mask.leaf(EAR_ROOT, EAR_TIP, EAR_W, bend=0.05, n=14, fullness=0.55, root_round=0.7)


def _ears(kit: mask.MaskKit) -> None:
    """Broad leaf ears held out flat to the sides, each with a hollow ridge down the middle."""
    # the dish starts just behind the shell's inner skin at its side edge, so the ear leaves the edge
    t = float(kit.params["thickness"])
    edge = kit.surf.point(EAR_EDGE[0], EAR_EDGE[1], -t)
    dish = mask.DishSurface(edge.y - 0.0015, centre=(edge.x, edge.z), slope=-0.10)
    m = kit.mat("primary")
    ear = _ear_loop()
    rib = mask.leaf((EAR_ROOT[0] + 0.014, EAR_ROOT[1] + 0.008), (EAR_TIP[0] - 0.012, EAR_TIP[1] - 0.003),
                    EAR_W * 0.42, bend=0.05, n=10, fullness=0.6)
    for o, r in ((ear, rib), (mask.mirror(ear), mask.mirror(rib))):
        mask.slab(kit.mb, dish, o, [], -0.004, 0.0, 0.0012, m, m, m, 0.02, 0.02, 0.005, bottom=True)
        mask.slab(kit.mb, dish, r, [], -0.001, 0.0016, 0.0007, m, m, None, 0.02, 0.02, 0.005, bottom=False)


def _antlers(kit: mask.MaskKit) -> None:
    """Short antlers: a burr ring, a beam up and out, a forward brow tine and a small top fork."""
    m = kit.mat("primary")
    for side in (1, -1):
        u0, v0 = side * ANTLER_ROOT[0], ANTLER_ROOT[1]
        base = kit.surf.point(u0, v0, -0.004)
        nrm = kit.surf.normal(u0, v0)
        burr = [(0.0, -0.002), (0.0105, -0.002), (0.0125, 0.0025), (0.0120, 0.0050), (0.0090, 0.0060),
                (0.0, 0.0062)]
        axis = (nrm * 0.5 + Vector((side * 0.25, -0.05, 1.0))).normalized()
        mask.lathe(kit.mb, base + axis * 0.004, axis, burr, m, n=14)
        p0 = base + axis * 0.006
        top = p0 + Vector((side * 0.036, -0.006, 0.066))
        beam = mask.bezier3(p0, p0 + axis * 0.030, top + Vector((-side * 0.006, 0.010, -0.020)), top, 9)
        mask.tube(kit.mb, beam, lambda s: 0.0078 * (1 - 0.55 * s) + 0.0012, m, n=10)
        # brow tine: from a third of the way up, forward and up
        b0 = beam[3]
        brow_tip = b0 + Vector((-side * 0.006, 0.030, 0.022))
        mask.tube(kit.mb, mask.bezier3(b0, b0 + Vector((0.0, 0.012, 0.0)), brow_tip - Vector((0.0, 0.006, 0.006)),
                                       brow_tip, 5), lambda s: 0.0060 * (1 - 0.7 * s) + 0.0008, m, n=8)
        # top fork: a short back tine near the top
        f0 = beam[7]
        fork_tip = f0 + Vector((side * 0.004, -0.012, 0.022))
        mask.tube(kit.mb, mask.bezier3(f0, f0 + Vector((0.0, -0.006, 0.006)), fork_tip - Vector((0.0, -0.004, 0.006)),
                                       fork_tip, 4), lambda s: 0.0046 * (1 - 0.7 * s) + 0.0008, m, n=8)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_lids, _nose, _forelock, _ears, _antlers],
                    surface_extra=_sculpt, outline_fn=_outline, uv_mode="front", refine=REFINE)
