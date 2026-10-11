"""Shared dimensions and part builders for the Tillman Bastion BR 7.62 battle rifle (B4-18).

Private helper: imported by ``bastion_br.py`` and ``bastion_br_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the polymer pistol grip.

Stamped steel receiver with a cocking tube running forward over the barrel (cocking handle on the left),
slim vented polymer handguard, clamp-on top rail, a straight 20-round box magazine in a flared magwell,
prong flash hider, fixed polymer stock (``StockMount/StockStock``, not modular).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 18.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

REC_HW = 0.0175
REC_REAR_Y = -0.090
REC_FRONT_Y = 0.200
REC_BOTTOM_Z = 0.028
REC_TOP_Z = 0.090
BORE_Z = 0.066
TUBE_Z = REC_TOP_Z - 0.002
TUBE_R = 0.0100
TUBE_END_Y = 0.440
RAIL_Y0, RAIL_Y1 = -0.075, 0.120
RAIL_TOP_Z = REC_TOP_Z + 0.004 + 0.0062
SIGHT_RAIL_Y = 0.020

HG_Y0, HG_Y1 = 0.205, 0.415
BARREL_END_Y = 0.560
HIDER_LEN = 0.040
MUZZLE_Y = BARREL_END_Y + HIDER_LEN + 0.001

MAG_HW = 0.0135
MAG_HD = 0.0300
MAG_INSIDE = 0.030
MAG_STD_BELOW = 0.095
MAG_EXT_BELOW = 0.140
MAGWELL_POS = (0.0, 0.098, REC_BOTTOM_Z - 0.006)

STOCK_MOUNT = (0.0, REC_REAR_Y, 0.058)
UNDER_Y = 0.330
SIDE_Y = 0.330
REAR_IRON_Y = -0.060 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0150


def build_irons(ctx, mats, parent=None, name="IronSights"):
    """Rear aperture on the rail + hooded front post on the cocking-tube nose; origin = SightRail."""
    front_base = (TUBE_Z + TUBE_R) - RAIL_TOP_Z
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, TUBE_END_Y - 0.012 - SIGHT_RAIL_Y, front_base,
                                sight_h=IRON_AIM_DZ, parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD * 0.62, curve=0.008 if not extended else 0.016,
                           inside=MAG_INSIDE, mat_name="matte", round_r=0.0055, ribs=4, parent=parent, name=name)


def build_stock(ctx, mats, parent=None, name="Stock"):
    """Fixed polymer stock; origin = StockMount (receiver rear), extends along -Y."""
    prof = [(0.004, 0.030), (0.004, -0.030), (-0.050, -0.040), (-0.250, -0.098), (-0.262, -0.098),
            (-0.262, 0.032), (-0.240, 0.036), (-0.030, 0.034)]
    return c.build_butt_stock(ctx, mats, "polymer", prof, 0.0190, name=name, parent=parent, pad_y=-0.262,
                              pad_z=(-0.098, 0.032), taper=lambda y, z: 0.85 if y > -0.040 else 1.0)


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    return c.build_can(ctx, mats, length=0.200, r=0.0215, overlap=HIDER_LEN - 0.004, bore_r=0.0055, parent=parent,
                       name=name)
