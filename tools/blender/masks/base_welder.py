"""Welder customisable base mask (``mask_base.welder``, D-111).

An original welding shield: a wide, flat-fronted, square-jawed shell (almost no face form: the crew
fit alone lifts it clear of the nose), a raised rectangular window frame round both eyes, the dark
filter lens flipped up on its hinge above the window and standing forward at an angle, a big
adjuster knob on each temple, a stepped chin guard and two short hose stubs under the cheeks. The
flat box with the lens sticking out of its top is the read at distance; the big flat front is an
easy canvas for decals and stripes.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import math

from mathutils import Vector

import _mask_base as mask

ASSET_ID = "mask_base_welder"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.108,
    "bottom": -0.126,
    "chin_point": 0.0,
    "side_arc": 0.112,
    "jaw_taper": 0.12,
    "wrap_radius": 0.120,
    "brow": 0.0,
    "cheek": 0.0,
    "nose": 0.0,
    "jaw": 0.2,
    "eye_shape": "round",
    "eye_width": 0.026,
    "eye_height": 0.0180,
    "eye_spacing": 0.066,
    "eye_tilt_deg": 0.0,
    "mouth": "none",
    "res": 0.0095,
    "res_back": 0.017,
    "edge_res": 0.0055,
}

WIN = (0.056, 0.020)          # window frame half width / half height (u, v), centred on the eye line
FRAME_W = 0.008               # frame border width
LENS_TILT = 16.0              # degrees the flipped-up lens leans forward of vertical


def _g(x: float, s: float) -> float:
    return math.exp(-(x / s) ** 2)


def _smooth(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _sculpt(u: float, v: float) -> float:
    # a flat front: the whole shield pushed out as a broad plateau, so the crew fit's lift over the nose
    # disappears into it, plus a shallow centre crease down the lower shield (two panels meeting at a ridge)
    plateau = 0.018 * math.exp(-(u / 0.078) ** 4) * _smooth(0.112, 0.080, v) * _smooth(-0.130, -0.100, v)
    return plateau + 0.006 * math.exp(-abs(u) / 0.030) * _smooth(-0.030, -0.070, v)


def _rr(cu: float, cv: float, hw: float, hh: float, r: float) -> mask.Loop2:
    pts: mask.Loop2 = []
    for cx, cy, a0 in ((hw - r, hh - r, 0.0), (-hw + r, hh - r, 90.0), (-hw + r, -hh + r, 180.0),
                       (hw - r, -hh + r, 270.0)):
        for k in range(5):
            a = math.radians(a0 + 90.0 * k / 4)
            pts.append((cu + cx + r * math.cos(a), cv + cy + r * math.sin(a)))
    return pts


def _window(kit: mask.MaskKit) -> None:
    """The raised window frame round both eyes."""
    hw, hh = WIN
    outer = mask.resample(_rr(0.0, 0.0, hw + FRAME_W, hh + FRAME_W, 0.006), 0.004)
    inner = mask.resample(_rr(0.0, 0.0, hw, hh, 0.003), 0.004)
    kit.plate(mask.oriented(outer, True), hi=0.0045, chamfer=0.0012, edge_res=0.004,
              holes=[mask.oriented(inner, False)])


def _lens(kit: mask.MaskKit) -> None:
    """The filter lens: a thin box hinged at the window's top edge, flipped up and forward."""
    surf = kit.surf
    hw, hh = WIN
    hinge_v = hh + FRAME_W
    h0 = surf.point(0.0, hinge_v, 0.0040)
    up = Vector((0.0, 0.0, 1.0))
    fwd = surf.normal(0.0, hinge_v)
    a = math.radians(LENS_TILT)
    d = (up * math.cos(a) + fwd * math.sin(a)).normalized()      # from the hinge out along the lens
    n = d.cross(Vector((1.0, 0.0, 0.0))).normalized()           # the lens's thickness direction
    length, half, th = 2 * hh + 0.010, hw + 0.004, 0.0040
    secs = []
    for x in (-half, half):
        base = h0 + Vector((x, 0.0, 0.0))
        secs.append([base, base + d * length, base + d * length + n * th, base + n * th])
    kit.loft(secs)
    # the hinge barrel
    mask.tube(kit.mb, [h0 + Vector((-half * 0.8, 0.0, 0.0)), h0 + Vector((half * 0.8, 0.0, 0.0))],
              lambda s: 0.0032, kit.mat("primary"), n=10, tip=False)


def _knobs(kit: mask.MaskKit) -> None:
    """A big ribbed adjuster knob on each temple."""
    surf = kit.surf
    for side in (1, -1):
        u = side * 0.100
        c = surf.point(u, 0.012, 0.0)
        nrm = surf.normal(u, 0.012)
        prof = [(0.0, 0.0), (0.014, 0.0), (0.0145, 0.004), (0.012, 0.009), (0.0, 0.010)]
        mask.lathe(kit.mb, c - nrm * 0.002, nrm, prof, kit.mat("primary"), n=14)


def _chin(kit: mask.MaskKit) -> None:
    """A stepped chin guard across the bottom of the shield."""
    guard = mask.resample(_rr(0.0, -0.106, 0.070, 0.012, 0.006), 0.004)
    kit.plate(mask.oriented(guard, True), hi=0.0040, chamfer=0.0012, edge_res=0.004)


def _hoses(kit: mask.MaskKit) -> None:
    """Two short hose stubs under the cheeks, pointing down and out."""
    surf = kit.surf
    for side in (1, -1):
        u, v = side * 0.070, -0.080
        p0 = surf.point(u, v, -0.002)
        nrm = surf.normal(u, v)
        path = [p0, p0 + nrm * 0.010, p0 + nrm * 0.016 + Vector((side * 0.006, 0.0, -0.012))]
        mask.tube(kit.mb, path, lambda s: 0.0075 - 0.0010 * s, kit.mat("primary"), n=12, tip=False)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_window, _lens, _knobs, _chin, _hoses],
                    surface_extra=_sculpt, uv_mode="front")
