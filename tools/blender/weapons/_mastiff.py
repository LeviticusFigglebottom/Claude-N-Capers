"""Shared dimensions and part builders for the Tillman Ironworks Mastiff .45 submachine gun (B4-12).

Private helper: imported by ``mastiff_45.py`` and ``mastiff_45_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip.

Heavy, slow-firing .45 SMG: round stamped-steel receiver tube with a welded optics rail, perforated
barrel shroud, straight stick magazine, fixed wire stock (``StockMount/StockStock``).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 18.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.074
GRIP_HALF_DEPTH = 0.0170
GRIP_HALF_WIDTH = 0.0140

BORE_Z = 0.070
TUBE_R = 0.0215
TUBE_REAR_Y = -0.095
TUBE_FRONT_Y = 0.150
RAIL_BASE_Z = BORE_Z + TUBE_R - 0.0020
RAIL_TOP_Z = RAIL_BASE_Z + 0.0062
RAIL_Y0, RAIL_Y1 = -0.070, 0.135
SIGHT_RAIL_Y = 0.030

HOUSING_Y0, HOUSING_Y1 = -0.040, 0.135
HOUSING_BOTTOM_Z = 0.024
SHROUD_R = 0.0175
SHROUD_Y1 = 0.300
MUZZLE_NUT_LEN = 0.012
MUZZLE_Y = SHROUD_Y1 + MUZZLE_NUT_LEN + 0.001

MAGWELL_Y0, MAGWELL_Y1 = 0.084, 0.124
MAGWELL_BOTTOM_Z = 0.004
MAGWELL_POS = (0.0, (MAGWELL_Y0 + MAGWELL_Y1) / 2, MAGWELL_BOTTOM_Z)
MAG_HW = 0.0120
MAG_HD = 0.0170
MAG_INSIDE = 0.030
MAG_STD_BELOW = 0.135
MAG_EXT_BELOW = 0.180

STOCK_MOUNT = (0.0, TUBE_REAR_Y, BORE_Z - 0.004)
UNDER_Y = 0.235
UNDER_Z = BORE_Z - SHROUD_R - 0.0025
SIDE_Y = 0.235
IRON_AIM_DZ = 0.0150
REAR_IRON_Y = -0.060 - SIGHT_RAIL_Y


def build_irons(ctx, mats, parent=None, name="IronSights"):
    """Flip-up rear aperture on the rail, front post at the rail's front end; origin = SightRail."""
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, RAIL_Y1 - 0.012 - SIGHT_RAIL_Y, 0.0, sight_h=IRON_AIM_DZ,
                                parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    """Straight double-stack .45 stick magazine; origin = Magwell."""
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.004 if extended else 0.0, inside=MAG_INSIDE,
                           mat_name="steel", round_r=0.0055, ribs=4 if extended else 3, parent=parent, name=name,
                           window=extended, base_drop=0.007)


def build_wire_stock(ctx, mats, parent=None, name="Stock"):
    """Fixed steel wire stock; origin = StockMount, extends along -Y."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    rub = mb.material(mats.rubber())
    mb.box((-0.0180, -0.014, -0.022), (0.0180, 0.0, 0.020), mat=st)                     # mount block
    yr = -0.235
    for x in (-0.0130, 0.0130):
        mb.cylinder(0.0042, -yr - 0.010, segments=12, centre=(x, (yr - 0.004) / 2, 0.010), axis="Y", mat=st)
        # lower strut, angled down to the toe
        ya, yb, za, zb = -0.012, yr + 0.004, -0.016, -0.086
        band = [(ya, za - 0.004), (yb, zb - 0.004), (yb, zb + 0.004), (ya, za + 0.004)]
        mb.prism(band, axis="X", start=x - 0.0040, end=x + 0.0040, mat=st)
    # butt plate + rubber pad
    mb.box((-0.0200, yr - 0.006, -0.096), (0.0200, yr + 0.004, 0.022), mat=st)
    mb.box((-0.0195, yr - 0.016, -0.094), (0.0195, yr - 0.006, 0.020), mat=rub)
    return c.finish(mb, name, bevel=0.0010, segments=1, parent=parent)


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    """Fat .45 can on the muzzle nut; origin = Muzzle."""
    return c.build_can(ctx, mats, length=0.190, r=0.0200, overlap=MUZZLE_NUT_LEN - 0.002, bore_r=0.0068,
                       parent=parent, name=name)
