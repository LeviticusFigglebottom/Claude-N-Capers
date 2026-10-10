"""Shared dimensions and part builders for the Brannock Falchion DMR (B4-12).

Private helper: imported by ``falchion_dmr.py`` and ``falchion_dmr_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip.

Semi-automatic 7.62 marksman rifle: tall black receivers, long round free-float handguard with a
full-length top rail, heavy barrel with a three-port brake, olive precision stock with a cheek piece on
a buffer tube, straight 20-round magazine.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 18.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))

BORE_Z = 0.078
LOWER_TOP_Z = 0.064
UPPER_TOP_Z = 0.104
REC_HW = 0.0145
RECEIVER_REAR_Y = -0.085
UPPER_FRONT_Y = 0.190
RAIL_TOP_Z = UPPER_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.030

HG_FRONT_Y = 0.520
HG_R = 0.0245
UNDER_Y = 0.420
SIDE_Y = 0.440

BARREL_R = 0.0110
BARREL_END_Y = 0.700
BRAKE_LEN = 0.058
MUZZLE_Y = BARREL_END_Y + BRAKE_LEN + 0.001

MAGWELL_Y0, MAGWELL_Y1 = 0.092, 0.172
MAGWELL_BOTTOM_Z = -0.010
MAGWELL_POS = (0.0, (MAGWELL_Y0 + MAGWELL_Y1) / 2, MAGWELL_BOTTOM_Z)
MAG_HW = 0.0130
MAG_HD = 0.0340
MAG_INSIDE = 0.040
MAG_STD_BELOW = 0.098
MAG_EXT_BELOW = 0.122

STOCK_MOUNT = (0.0, RECEIVER_REAR_Y, BORE_Z)
IRON_AIM_DZ = 0.0170
REAR_IRON_Y = -0.070 - SIGHT_RAIL_Y


def build_irons(ctx, mats, parent=None, name="IronSights"):
    """Flip-up irons: rear on the receiver rail, front at the handguard tip (same rail height)."""
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, HG_FRONT_Y - 0.020 - SIGHT_RAIL_Y, 0.0,
                                sight_h=IRON_AIM_DZ, parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.006 if extended else 0.004, inside=MAG_INSIDE,
                           mat_name="polymer", round_r=0.0040, ribs=3 if extended else 2, parent=parent, name=name,
                           window=True)


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    return c.build_can(ctx, mats, length=0.190, r=0.0215, overlap=BRAKE_LEN - 0.004, bore_r=0.0058, parent=parent,
                       name=name, cap_style="teeth")
