"""Shared dimensions and part builders for the Tillman Ironworks Plowman 12 pump shotgun (B4-04).

Private helper: imported by ``plowman_12.py`` and ``plowman_12_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot at the middle of the stock's wrist.

Tube magazine convention: ``Magwell`` sits at the loading port under the receiver (shells go in along
local +Z); the stock tube (``StockMagazine``) and the extended tube mod are built in that frame and
run forward under the barrel.
"""

from __future__ import annotations

import math

import _common as c

BORE_Z = 0.060
REC_REAR_Y = 0.032
REC_FRONT_Y = 0.250
REC_BOTTOM_Z = 0.008
REC_TOP_Z = 0.085
REC_HW = 0.0145
RAIL_Y0, RAIL_Y1 = 0.080, 0.205
RAIL_TOP_Z = REC_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.140

BARREL_R = 0.0105
BARREL_END_Y = 0.735
MUZZLE_Y = BARREL_END_Y + 0.001

TUBE_Z = BORE_Z - 0.0255
TUBE_R = 0.0115
TUBE_STD_END = 0.600
TUBE_EXT_END = 0.700
MAGWELL_POS = (0.0, 0.172, REC_BOTTOM_Z)

PUMP_Y0, PUMP_Y1 = 0.290, 0.500
STOCK_MOUNT = (0.0, REC_REAR_Y, 0.050)
UNDER_Y = 0.390

# stock outline in WORLD (y, z); converted into the StockMount frame by the builders
STOCK_PROFILE = [
    (REC_REAR_Y + 0.004, REC_TOP_Z - 0.002), (-0.015, 0.050), (-0.110, 0.062), (-0.326, 0.062),
    (-0.334, 0.058), (-0.346, -0.082), (-0.336, -0.088), (-0.200, -0.060), (-0.060, -0.040),
    (0.004, -0.028), (REC_REAR_Y, REC_BOTTOM_Z), (REC_REAR_Y + 0.004, REC_BOTTOM_Z)]
GRIP_ONLY_PROFILE = [
    (REC_REAR_Y + 0.004, REC_TOP_Z - 0.006), (0.012, 0.074), (-0.010, 0.058), (-0.026, 0.030),
    (-0.044, -0.010), (-0.058, -0.050), (-0.062, -0.068), (-0.050, -0.076), (-0.026, -0.076),
    (-0.024, -0.062), (-0.016, -0.054), (-0.018, -0.044), (-0.008, -0.034), (-0.010, -0.024),
    (0.000, -0.014), (0.002, -0.004), (0.014, 0.004), (REC_REAR_Y, REC_BOTTOM_Z),
    (REC_REAR_Y + 0.004, REC_BOTTOM_Z)]


def _to_mount(pts):
    return [(y - STOCK_MOUNT[1], z - STOCK_MOUNT[2]) for y, z in pts]


def build_stock(ctx, mats, parent=None, name="Stock"):
    """Walnut buttstock with the wrist; origin = StockMount."""
    mb = ctx.builder()
    wood = mb.material(mats.wood())
    mb.prism(_to_mount(STOCK_PROFILE), axis="X", start=-0.021, end=0.021, mat=wood)
    yb = -0.346 - STOCK_MOUNT[1]

    def width(y, z):
        t = min(1.0, max(0.0, y / yb))                # 0 at the receiver, 1 at the butt
        return 0.68 + 0.32 * t

    c.taper_x(mb, width)
    body = c.finish(mb, name, bevel=0.0045, segments=3, parent=parent)
    pad = ctx.builder()
    rub = pad.material(mats.rubber())
    pp = _to_mount([(-0.346, 0.060), (-0.358, -0.084), (-0.370, -0.083), (-0.358, 0.061)])
    pad.prism(pp, axis="X", start=-0.0205, end=0.0205, mat=rub)
    c.finish(pad, name + "Pad", bevel=0.0030, segments=2, parent=body)
    return body


def build_pistol_grip(ctx, mats, parent=None, name="PistolGrip"):
    """Stockless raked pistol grip (Hedge Grip mod); origin = StockMount."""
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    mb.prism(_to_mount(GRIP_ONLY_PROFILE), axis="X", start=-0.0145, end=0.0145, mat=poly)
    c.taper_x(mb, lambda y, z: 0.85 if z > 0.03 else 1.0)
    body = c.finish(mb, name, bevel=0.0030, segments=3, parent=parent)
    st = ctx.builder()
    sm = st.material(mats.stipple())
    for side in (-1.0, 1.0):
        x = side * 0.0144
        for r in range(9):
            z = -0.062 + r * 0.008
            y = -0.040 + 0.45 * (z + 0.062) * 0.9 - 0.004
            for k in range(3):
                c.pyramid(st.bm, c.Vector((x, y + k * 0.008 - STOCK_MOUNT[1] + 0.0, z - STOCK_MOUNT[2])),
                          c.Vector((0, 1, 0)), c.Vector((0, 0, 1)), c.Vector((side, 0, 0)), 0.0018, 0.0007, sm)
    c.finish(st, name + "Texture", parent=body)
    cap = ctx.builder()
    cap.prism(_to_mount([(-0.064, -0.070), (-0.024, -0.078), (-0.024, -0.082), (-0.064, -0.074)]), axis="X",
              start=-0.0140, end=0.0140, mat=cap.material(mats.steel()))
    c.finish(cap, name + "Cap", bevel=0.0010, parent=body)
    return body


def build_tube(ctx, mats, extended: bool, parent=None, name="MagTube"):
    """Tube magazine in the Magwell frame (+Z = up into the loading port)."""
    end = TUBE_EXT_END if extended else TUBE_STD_END
    oy, oz = MAGWELL_POS[1], MAGWELL_POS[2]
    z = TUBE_Z - oz
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(TUBE_R, end - REC_FRONT_Y, segments=28, centre=(0.0, (end + REC_FRONT_Y) / 2 - oy, z), axis="Y",
                mat=st)
    mb.cylinder(TUBE_R + 0.0012, 0.024, segments=28, centre=(0.0, end + 0.012 - oy, z), axis="Y", mat=st)   # cap
    mb.cylinder(0.0050, 0.004, segments=16, centre=(0.0, end + 0.026 - oy, z), axis="Y", mat=st)
    # follower/shell visible in the loading port
    mb.box((-0.0095, -0.030, 0.004), (0.0095, 0.034, 0.010), mat=st)
    if extended:
        # barrel clamp tying the tube to the barrel
        clamp_y = end - 0.010 - oy
        mb.box((-0.0125, clamp_y - 0.008, z), (0.0125, clamp_y + 0.008, BORE_Z - oz), mat=st)
        c.ring_y(mb, BARREL_R + 0.003, BARREL_R - 0.0004, clamp_y - 0.008, clamp_y + 0.008, BORE_Z - oz, st,
                 segments=28)
    body = c.finish(mb, name, bevel=0.0008, segments=1, parent=parent)
    sh = ctx.builder()
    br = sh.material(mats.brass())
    sh.cylinder(0.0105, 0.004, segments=20, centre=(0.0, 0.022, 0.012), axis="Y", mat=br)
    hull = sh.material(mats.polymer())
    sh.cylinder(0.0100, 0.052, segments=20, centre=(0.0, -0.006, 0.012), axis="Y", mat=hull)
    c.finish(sh, name + "Shell", parent=body)
    return body


def build_irons(ctx, mats, parent=None, name="GhostRing"):
    """Ghost-ring rear on the receiver rail + front blade on the barrel; origin = SightRail."""
    front_y = BARREL_END_Y - 0.030 - SIGHT_RAIL_Y
    front_base = (BORE_Z + BARREL_R) - RAIL_TOP_Z
    return c.build_flipup_irons(ctx, mats, -0.040, front_y, front_base, sight_h=0.0130, parent=parent, name=name)


def build_choke(ctx, mats, parent=None, name="Choke"):
    """Extended breaching choke with castellated teeth; origin = Muzzle. Adds its own ``Muzzle``."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    length = 0.048
    c.ring_y(mb, 0.0132, 0.0090, -0.004, length, 0.0, st, segments=32)
    for i in range(6):
        a = 2 * math.pi * i / 6
        x, z = math.cos(a) * 0.0112, math.sin(a) * 0.0112
        mb.box((x - 0.003, length, z - 0.003), (x + 0.003, length + 0.006, z + 0.003), mat=st)
    body = c.finish(mb, name, bevel=0.0007, segments=1, parent=parent)
    pt = ctx.builder()
    dark = pt.material(mats.polymer())
    for i in range(3):
        y = 0.012 + i * 0.010
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * 0.0128, side * 0.0136))
            pt.box((lo, y, -0.003), (hi, y + 0.006, 0.003), mat=dark)
    c.finish(pt, name + "Ports", parent=body)
    ctx.marker("Muzzle", (0.0, length + 0.006, 0.0), parent=body)
    return body
