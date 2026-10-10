"""Shared dimensions and part builders for the Graff-Lindqvist Rampart light machine gun (B4-04).

Private helper: imported by ``rampart_lmg.py`` and ``rampart_lmg_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip.

The quick-change barrel (with gas tube, front post, carry handle and flash hider) is the stock part
``BarrelMount/StockBarrel``; the short assault barrel mod replaces it and carries its own ``Muzzle``.
The belt box (with the belt feeding up into the left side of the receiver) hangs from ``Magwell``.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 20.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))

BORE_Z = 0.085
REC_REAR_Y = -0.080
REC_FRONT_Y = 0.230
REC_BOTTOM_Z = 0.020
REC_TOP_Z = 0.118
REC_HW = 0.0255
COVER_Y0, COVER_Y1 = -0.020, 0.160
COVER_TOP_Z = 0.132
RAIL_TOP_Z = COVER_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.050

HG_Y1 = 0.420
HG_HW = 0.0285
HG_ZC = 0.078
HG_HH = 0.031
UNDER_Y = 0.385

BARREL_R = 0.0125
LONG_END_Y = 0.665
SHORT_END_Y = 0.545
HIDER_LEN = 0.040

MAGWELL_POS = (0.0, 0.150, REC_BOTTOM_Z)
FEED_POS = (-REC_HW, 0.060, 0.100)          # belt entry on the receiver's left side (world)

IRON_AIM_DZ = 0.0160
REAR_IRON_Y = -0.055                       # in the SightRail frame


def build_rear_leaf(ctx, mats, parent=None, name="RearLeaf"):
    """Rear aperture leaf on the feed-cover rail; origin = SightRail. Front post lives on the barrel."""
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    y = REAR_IRON_Y
    aim = IRON_AIM_DZ
    mb.box((-0.0130, y - 0.014, 0.0), (0.0130, y + 0.014, 0.006), mat=alu)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * 0.0090, side * 0.0130))
        mb.box((lo, y - 0.008, 0.006), (hi, y + 0.004, aim + 0.007), mat=alu)
    mb.prism(c.circle(0.0065, 20, 0.0, aim), holes=[list(reversed(c.circle(0.0020, 12, 0.0, aim)))], axis="Y",
             start=y - 0.0015, end=y + 0.0015, mat=alu)
    mb.box((-0.0050, y - 0.0015, 0.006), (0.0050, y + 0.0015, aim - 0.0045), mat=alu)
    mb.cylinder(0.0040, 0.006, segments=16, centre=(0.0145, y, 0.004), axis="X", mat=alu)   # windage knob
    return c.finish(mb, name, bevel=0.0005, parent=parent)


def build_barrel(ctx, mats, short: bool, parent=None, name="Barrel"):
    """Quick-change barrel in the BarrelMount frame (origin = barrel root on the bore, +Y forward)."""
    end = (SHORT_END_Y if short else LONG_END_Y) - REC_FRONT_Y
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(BARREL_R, end, segments=28, centre=(0.0, end / 2, 0.0), axis="Y", mat=st)
    # flash hider: tapered cage
    for i in range(5):
        mb.cylinder(0.0145 - i * 0.0004, HIDER_LEN / 5 - 0.001, segments=24,
                    centre=(0.0, end + (i + 0.5) * HIDER_LEN / 5, 0.0), axis="Y", mat=st)
    # gas block + front post
    gy = end - 0.070
    mb.box((-0.0140, gy - 0.016, -0.034), (0.0140, gy + 0.016, 0.0120), mat=st)
    post_top = RAIL_TOP_Z + IRON_AIM_DZ - BORE_Z
    mb.box((-0.0060, gy - 0.008, 0.010), (0.0060, gy + 0.008, post_top - 0.014), mat=st)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * 0.0050, side * 0.0085))
        mb.box((lo, gy - 0.006, post_top - 0.016), (hi, gy + 0.006, post_top + 0.002), mat=st)
    mb.box((-0.0012, gy - 0.0015, post_top - 0.016), (0.0012, gy + 0.0015, post_top), mat=st)
    # gas tube back into the handguard
    mb.cylinder(0.0065, gy - 0.010, segments=16, centre=(0.0, (gy - 0.010) / 2, -0.024), axis="Y", mat=st)
    # carry handle (folded down along the barrel's right, on the handguard front)
    hy = 0.215 - (0.0 if not short else 0.050)
    mb.box((-0.0070, hy - 0.004, 0.010), (0.0070, hy + 0.012, 0.024), mat=st)
    body = c.finish(mb, name, bevel=0.0007, segments=1, parent=parent)
    hd = ctx.builder()
    poly = hd.material(mats.polymer())
    loop = [(hy - 0.050, 0.020), (hy + 0.062, 0.020), (hy + 0.056, 0.062), (hy - 0.044, 0.062)]
    inner = [(hy - 0.034, 0.030), (hy + 0.046, 0.030), (hy + 0.042, 0.050), (hy - 0.030, 0.050)]
    hd.prism(loop, holes=[list(reversed(inner))], axis="X", start=-0.0070, end=0.0070, mat=poly)
    c.finish(hd, name + "Handle", bevel=0.0025, segments=2, parent=body)
    return body


def build_box(ctx, mats, big: bool, parent=None, name="AmmoBox"):
    """Belt box in the Magwell frame: origin = box mount under the receiver, +Z up into it."""
    below = 0.150 if big else 0.105
    hw = 0.046 if big else 0.040
    hd = 0.052
    xo = -0.010
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    mb.prism(c.rounded_rect(hd, below / 2, 0.010, 0.0, -below / 2, corner_segments=3), axis="X", start=xo - hw,
             end=xo + hw, mat=poly)
    mb.box((xo - hw + 0.004, -0.030, 0.0), (xo + hw - 0.004, 0.030, 0.006), mat=poly)       # latch rail
    for i in range(3):                                                                       # ribs
        z = -below * (i + 1) / 4
        mb.box((xo - hw - 0.0012, -hd + 0.010, z - 0.003), (xo + hw + 0.0012, hd - 0.010, z + 0.003), mat=poly)
    mb.box((xo - hw - 0.002, -0.012, -0.030), (xo - hw + 0.001, 0.012, -0.012), mat=poly)    # side latch
    body = c.finish(mb, name, bevel=0.0030, segments=2, parent=parent)
    # belt: rounds from the box's top left corner up into the feed opening
    bt = ctx.builder()
    br = bt.material(mats.brass())
    lk = bt.material(mats.steel())
    fx, fy, fz = FEED_POS[0], FEED_POS[1] - MAGWELL_POS[1], FEED_POS[2] - MAGWELL_POS[2]
    sx, sy, sz = xo - hw + 0.010, fy, 0.004
    n = 9
    for i in range(n):
        t = i / (n - 1)
        x = sx + (fx - 0.006 - sx) * t - 0.012 * math.sin(math.pi * t)
        z = sz + (fz - sz) * t
        bt.cylinder(0.0050, 0.034, segments=12, centre=(x, sy, z), axis="Y", mat=br)
        bt.cylinder(0.0032, 0.014, segments=10, centre=(x, sy + 0.024, z), axis="Y", mat=br)
        bt.box((x - 0.0060, sy - 0.010, z - 0.0035), (x + 0.0060, sy - 0.004, z + 0.0035), mat=lk)
    c.finish(bt, name + "Belt", parent=body)
    return body
