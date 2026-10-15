"""Shared dimensions and part builders for the Graff-Lindqvist Tern bullpup rifle (B4-18).

Private helper: imported by ``tern_556.py`` and ``tern_556_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip, which sits ahead of the magazine.

Olive polymer bullpup shell from the butt to a short handguard, the magazine BEHIND the grip
(``Magwell`` under the action), ejection port beside the cheek, full-length top rail, a short lower rail
under the handguard, 5.56 barrel with a 3-port brake. The stock is part of the shell, so there is no
stock slot; ``StockMount`` sits at the butt plate.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 14.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

BODY_HW = 0.0240
BODY_REAR_Y = -0.360
BODY_FRONT_Y = 0.140
BODY_TOP_Z = 0.090
BODY_BOTTOM_Z = 0.024
BORE_Z = 0.060
RAIL_Y0, RAIL_Y1 = -0.140, 0.130
RAIL_TOP_Z = BODY_TOP_Z + 0.0062
SIGHT_RAIL_Y = -0.020

BARREL_END_Y = 0.400
BRAKE_LEN = 0.042                # PO6-13 3-port side brake
MUZZLE_Y = BARREL_END_Y + BRAKE_LEN + 0.001

MAGWELL_Y = -0.118
MAGWELL_POS = (0.0, MAGWELL_Y, -0.004)
MAG_HW = 0.0120
MAG_HD = 0.0310
MAG_INSIDE = 0.040
MAG_STD_BELOW = 0.140
MAG_EXT_BELOW = 0.200

STOCK_MOUNT = (0.0, BODY_REAR_Y, 0.044)
UNDER_Y = 0.098
SIDE_Y = 0.100
REAR_IRON_Y = -0.125 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0160


def build_irons(ctx, mats, parent=None, name="IronSights"):
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, RAIL_Y1 - 0.014 - SIGHT_RAIL_Y, 0.0, sight_h=IRON_AIM_DZ,
                                parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    """Translucent-windowed polymer magazine behind the grip; origin = Magwell, +Z = insertion (up)."""
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD * 0.62, curve=0.022 if not extended else 0.034,
                           inside=MAG_INSIDE, mat_name="polymer", round_r=0.0045, ribs=0, parent=parent, name=name,
                           window=True)


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    return c.build_can(ctx, mats, length=0.170, r=0.0190, overlap=BRAKE_LEN - 0.004, bore_r=0.0045, parent=parent,
                       name=name)
