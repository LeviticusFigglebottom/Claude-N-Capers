"""Shared dimensions and part builders for the Tillman Ironworks Anvil 7.62 general-purpose MG (B4-12).

Private helper: imported by ``anvil_lmg.py`` and ``anvil_lmg_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip.

Belt-fed 7.62: tall riveted steel receiver with a rear-hinged ``FeedCover`` (D-044, optics rail on top),
walnut skeleton stock, gas cylinder under a long fluted quick-change barrel
(``BarrelMount/StockBarrel``: barrel + wooden carry handle + front post + 3-port muzzle brake), olive steel
ammo box under the receiver feeding from the left (``Magwell``).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 18.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))

BORE_Z = 0.088
REC_REAR_Y = -0.085
REC_FRONT_Y = 0.215
REC_BOTTOM_Z = 0.022
REC_TOP_Z = 0.122
REC_HW = 0.0235
COVER_Y0, COVER_Y1 = -0.005, 0.165
COVER_TOP_Z = 0.134
COVER_HINGE = (0.0, COVER_Y0 - 0.004, REC_TOP_Z + 0.002)   # rear hinge axis = FeedCover origin (Blender)
COVER_OPEN_DEG = 78.0
RAIL_TOP_Z = COVER_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.060

GAS_Z = BORE_Z - 0.030
GAS_Y1 = 0.455
GAS_R = 0.0110
UNDER_Y = 0.330
SIDE_Y = 0.330

BARREL_R = 0.0130
LONG_END_Y = 0.700
SHORT_END_Y = 0.560
BRAKE_LEN = 0.060                # PO6-13 3-port side brake

MAGWELL_POS = (0.0, 0.140, REC_BOTTOM_Z)
FEED_POS = (-REC_HW, 0.070, 0.104)          # belt entry on the receiver's left side (world)

IRON_AIM_DZ = 0.0170
REAR_IRON_Y = -0.050                        # in the SightRail frame
STOCK_MOUNT = (0.0, REC_REAR_Y, BORE_Z - 0.010)


def build_rear_leaf(ctx, mats, parent=None, name="RearLeaf"):
    """Tangent rear leaf with a U notch on the feed-cover rail; origin = SightRail."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    y = REAR_IRON_Y
    aim = IRON_AIM_DZ
    mb.box((-0.0120, y - 0.020, 0.0), (0.0120, y + 0.016, 0.005), mat=st)                     # base
    nh = 0.0018
    prof = [(-0.0110, 0.004), (0.0110, 0.004), (0.0110, aim + 0.004), (nh, aim + 0.004), (nh, aim),
            (-nh, aim), (-nh, aim + 0.004), (-0.0110, aim + 0.004)]
    mb.prism(prof, axis="Y", start=y - 0.0020, end=y + 0.0020, mat=st)                         # leaf
    for side in (-1.0, 1.0):                                                                     # guards
        lo, hi = sorted((side * 0.0110, side * 0.0140))
        mb.box((lo, y - 0.010, 0.004), (hi, y + 0.006, aim + 0.006), mat=st)
    mb.cylinder(0.0035, 0.006, segments=14, centre=(0.0150, y - 0.012, 0.004), axis="X", mat=st)
    return c.finish(mb, name, bevel=0.0004, parent=parent)


def build_barrel(ctx, mats, short: bool, parent=None, name="Barrel"):
    """Quick-change fluted barrel in the BarrelMount frame (origin = barrel root on the bore, +Y fwd).
    Carries the carry handle, the front post and the 3-port ``MuzzleBrake`` (with ``Muzzle``,
    ``MuzzlePortL/R``)."""
    end = (SHORT_END_Y if short else LONG_END_Y) - REC_FRONT_Y
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(BARREL_R + 0.003, 0.040, segments=28, centre=(0.0, 0.020, 0.0), axis="Y", mat=st)   # barrel nut
    mb.prism(c.fluted(BARREL_R, BARREL_R - 0.0025, 8), axis="Y", start=0.040, end=end - 0.030, mat=st)
    mb.cylinder(BARREL_R - 0.0015, 0.032, segments=24, centre=(0.0, end - 0.016, 0.0), axis="Y", mat=st)
    # front post on a ring
    fy = end - 0.020
    post_top = RAIL_TOP_Z + IRON_AIM_DZ - BORE_Z
    c.ring_y(mb, BARREL_R + 0.003, BARREL_R - 0.0005, fy - 0.008, fy + 0.008, 0.0, st, segments=24)
    mb.box((-0.0040, fy - 0.006, BARREL_R), (0.0040, fy + 0.006, post_top - 0.012), mat=st)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * 0.0045, side * 0.0075))
        mb.box((lo, fy - 0.005, post_top - 0.016), (hi, fy + 0.005, post_top + 0.002), mat=st)
    mb.box((-0.0012, fy - 0.0015, post_top - 0.014), (0.0012, fy + 0.0015, post_top), mat=st)
    # carry-handle clamp on the barrel (handle folded to the right, clear of the sight line)
    hy = 0.075
    mb.box((-0.0060, hy - 0.010, -0.004), (0.0200, hy + 0.010, BARREL_R + 0.006), mat=st)
    body = c.finish(mb, name, bevel=0.0007, segments=1, parent=parent)
    hd = ctx.builder()
    wood = hd.material(mats.wood())
    # folding carry handle lying along the barrel's right side: two legs and a round grip bar
    for dy in (-0.008, 0.008):
        hd.box((0.0180, hy + dy - 0.005, BARREL_R - 0.002), (0.0300, hy + dy + 0.005, BARREL_R + 0.012), mat=wood)
    hd.prism(c.rounded_rect(0.0075, 0.0085, 0.006, 0.0300, BARREL_R + 0.014, corner_segments=3), axis="Y",
             start=hy - 0.070, end=hy + 0.070, mat=wood)
    c.finish(hd, name + "Handle", bevel=0.0025, segments=2, parent=body)
    c.build_muzzle_brake(ctx, mats, 0.0145, end, BRAKE_LEN, 0.0, parent=body)   # PO6-13, carries the Muzzle
    return body


def build_box(ctx, mats, big: bool, parent=None, name="AmmoBox"):
    """Olive steel belt box in the Magwell frame (+Z up into the receiver) with the belt feeding left."""
    below = 0.140 if big else 0.100
    hw = 0.052 if big else 0.044
    hd = 0.056
    xo = -0.012
    mb = ctx.builder()
    ol = mb.material(mats.olive())
    st = mb.material(mats.steel())
    mb.box((xo - hw, -hd, -below), (xo + hw, hd, -0.004), mat=ol)
    mb.box((xo - hw - 0.0015, -hd - 0.0015, -0.016), (xo + hw + 0.0015, hd + 0.0015, -0.004), mat=ol)   # lid lip
    for i in range(2):                                                                     # pressed ribs
        z = -below * (i + 1) / 3
        mb.box((xo - hw - 0.0010, -hd + 0.012, z - 0.004), (xo + hw + 0.0010, hd - 0.012, z + 0.004), mat=ol)
    mb.box((xo - 0.020, -0.034, -0.004), (xo + 0.020, 0.034, 0.004), mat=st)               # mount shoe
    mb.box((xo + hw, -0.012, -0.040), (xo + hw + 0.004, 0.012, -0.020), mat=st)            # latch
    mb.box((xo - 0.030, -0.004, -below - 0.006), (xo + 0.030, 0.004, -below), mat=st)      # carry strap bar
    body = c.finish(mb, name, bevel=0.0018, segments=1, parent=parent)
    bt = ctx.builder()
    br = bt.material(mats.brass())
    lk = bt.material(mats.steel())
    fx, fy, fz = FEED_POS[0], FEED_POS[1] - MAGWELL_POS[1], FEED_POS[2] - MAGWELL_POS[2]
    sx, sz = xo - hw + 0.012, 0.000
    n = 9
    for i in range(n):
        t = i / (n - 1)
        x = sx + (fx - 0.006 - sx) * t - 0.014 * math.sin(math.pi * t)
        z = sz + (fz - sz) * t
        bt.cylinder(0.0058, 0.040, segments=12, centre=(x, fy, z), axis="Y", mat=br)
        bt.cylinder(0.0036, 0.016, segments=10, centre=(x, fy + 0.028, z), axis="Y", mat=br)
        bt.box((x - 0.0068, fy - 0.012, z - 0.0040), (x + 0.0068, fy - 0.005, z + 0.0040), mat=lk)
    c.finish(bt, name + "Belt", parent=body)
    return body
