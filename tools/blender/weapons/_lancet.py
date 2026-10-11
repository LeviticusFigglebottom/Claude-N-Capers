"""Shared dimensions and part builders for the Brannock Lancet .45 SMG (B4-18).

Private helper: imported by ``lancet_45.py`` and ``lancet_45_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the raked pistol grip.

Angular black polymer body with the bore low over the hand, a deep "chin" ahead of the trigger guard
that takes the .45 magazine (``Magwell`` under the chin, vertical), a full-length top rail, a short
lower rail under the nose for a foregrip, a three-prong flash hider and a skeleton stock on a rear
hinge block (``StockMount/StockStock``).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 12.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_HALF_DEPTH = 0.0200
GRIP_HALF_WIDTH = 0.0150
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.078

BODY_HW = 0.0220
BODY_REAR_Y = -0.090
BODY_FRONT_Y = 0.200
BODY_TOP_Z = 0.098
BODY_BOTTOM_Z = 0.022
CHIN_Y0, CHIN_Y1 = 0.080, 0.152
CHIN_BOTTOM_Z = -0.022
BORE_Z = 0.052
RAIL_Y0, RAIL_Y1 = -0.080, 0.188
RAIL_TOP_Z = BODY_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.040

BARREL_END_Y = 0.240
HIDER_LEN = 0.030
MUZZLE_Y = BARREL_END_Y + HIDER_LEN + 0.001

MAG_HW = 0.0120
MAG_HD = 0.0170
MAG_INSIDE = 0.060
MAG_STD_BELOW = 0.058
MAG_EXT_BELOW = 0.112
MAGWELL_POS = (0.0, 0.116, CHIN_BOTTOM_Z)

STOCK_MOUNT = (0.0, BODY_REAR_Y, 0.072)
UNDER_Y = 0.176
SIDE_Y = 0.170
REAR_IRON_Y = -0.068 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0150


def build_irons(ctx, mats, parent=None, name="IronSights"):
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, RAIL_Y1 - 0.014 - SIGHT_RAIL_Y, 0.0, sight_h=IRON_AIM_DZ,
                                parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    """Polymer .45 magazine under the chin; origin = Magwell, +Z = insertion (up)."""
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.0, inside=MAG_INSIDE, mat_name="polymer",
                           round_r=0.0055, ribs=3 if extended else 1, parent=parent, name=name, base_drop=0.006)


def build_stock(ctx, mats, parent=None, name="Stock"):
    """Skeleton stock on a hinge block; origin = StockMount (body rear), extends along -Y."""
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    st = mb.material(mats.matte())
    mb.box((-0.0150, -0.018, -0.026), (0.0150, 0.0, 0.020), mat=st)                     # hinge block
    mb.cylinder(0.0050, 0.034, segments=16, centre=(0.0, -0.009, -0.026), axis="X", mat=st)
    outer = [(-0.016, 0.016), (-0.235, 0.020), (-0.250, 0.010), (-0.250, -0.085), (-0.236, -0.090),
             (-0.205, -0.070), (-0.016, -0.024)]
    hole = [(-0.040, 0.004), (-0.222, 0.006), (-0.230, -0.002), (-0.230, -0.060), (-0.212, -0.058),
            (-0.040, -0.010)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0110, end=0.0110, mat=poly)
    mb.box((-0.0150, -0.262, -0.088), (0.0150, -0.250, 0.018), mat=mb.material(mats.rubber()))
    return c.finish(mb, name, bevel=0.0015, segments=2, parent=parent)


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    """Long .45 can over the flash hider; origin = Muzzle."""
    return c.build_can(ctx, mats, length=0.180, r=0.0185, overlap=HIDER_LEN - 0.004, bore_r=0.0060, parent=parent,
                       name=name)
