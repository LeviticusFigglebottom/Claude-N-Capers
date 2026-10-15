"""Shared dimensions and part builders for the Graff-Lindqvist Gale MG high-rate belt-fed gun (B4-18).

Private helper: imported by ``gale_mg.py`` and ``gale_mg_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip.

Stamped steel receiver with a rear-hinged ``FeedCover`` (D-044: origin on the rear hinge, opens 78
degrees about local X, optics rail and ``SightRail`` on top), a long perforated barrel jacket with a
3-port muzzle brake and front post, black polymer stock, belt box under the receiver feeding from the left
(``Magwell``). The bipod is a mod on ``Underbarrel``.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 16.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

BORE_Z = 0.078
REC_REAR_Y = -0.080
REC_FRONT_Y = 0.160
REC_BOTTOM_Z = 0.022
REC_TOP_Z = 0.110
REC_HW = 0.0220
COVER_Y0, COVER_Y1 = 0.000, 0.150
COVER_TOP_Z = 0.122
COVER_HINGE = (0.0, COVER_Y0 - 0.004, REC_TOP_Z + 0.002)
RAIL_TOP_Z = COVER_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.070

JACKET_R = 0.0200
JACKET_Y1 = 0.555
BRAKE_LEN = 0.052                # PO6-13 3-port side brake (was a booster)
MUZZLE_Y = JACKET_Y1 + BRAKE_LEN + 0.001

MAGWELL_POS = (0.0, 0.110, REC_BOTTOM_Z)
FEED_POS = (-REC_HW, 0.050, 0.094)

UNDER_Y = 0.470
SIDE_Y = 0.400
IRON_AIM_DZ = 0.0170
REAR_IRON_Y = -0.050
STOCK_MOUNT = (0.0, REC_REAR_Y, BORE_Z - 0.010)


def build_rear_leaf(ctx, mats, parent=None, name="RearLeaf"):
    """U-notch rear leaf on the cover rail; origin = SightRail."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    y = REAR_IRON_Y
    aim = IRON_AIM_DZ
    mb.box((-0.0120, y - 0.018, 0.0), (0.0120, y + 0.014, 0.005), mat=st)
    nh = 0.0018
    prof = [(-0.0110, 0.004), (0.0110, 0.004), (0.0110, aim + 0.004), (nh, aim + 0.004), (nh, aim),
            (-nh, aim), (-nh, aim + 0.004), (-0.0110, aim + 0.004)]
    mb.prism(prof, axis="Y", start=y - 0.0020, end=y + 0.0020, mat=st)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * 0.0110, side * 0.0140))
        mb.box((lo, y - 0.010, 0.004), (hi, y + 0.006, aim + 0.006), mat=st)
    return c.finish(mb, name, bevel=0.0004, parent=parent)


def build_box(ctx, mats, big: bool, parent=None, name="AmmoBox"):
    """Black steel belt box in the Magwell frame (+Z up into the receiver) with the belt feeding left."""
    below = 0.130 if big else 0.095
    hw = 0.050 if big else 0.042
    hd = 0.052
    xo = -0.012
    mb = ctx.builder()
    bx = mb.material(mats.matte())
    st = mb.material(mats.steel())
    mb.box((xo - hw, -hd, -below), (xo + hw, hd, -0.004), mat=bx)
    mb.box((xo - hw - 0.0015, -hd - 0.0015, -0.016), (xo + hw + 0.0015, hd + 0.0015, -0.004), mat=bx)
    for i in range(3):
        y = -hd + 0.020 + i * 0.032
        mb.box((xo - hw - 0.0010, y - 0.004, -below + 0.010), (xo + hw + 0.0010, y + 0.004, -0.020), mat=bx)
    mb.box((xo - 0.020, -0.034, -0.004), (xo + 0.020, 0.034, 0.004), mat=st)
    mb.box((xo - 0.026, -0.004, -below - 0.006), (xo + 0.026, 0.004, -below), mat=st)
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
