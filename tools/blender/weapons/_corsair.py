"""Shared dimensions and part builders for the Brannock Corsair assault rifle (B4-04).

Private helper: imported by ``corsair_ar.py`` and ``corsair_ar_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip (grip centre plane, mid depth, 20 mm
below the grip top). Straight-line layout: bore, buffer tube and stock share one axis.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 22.0
GRIP_TOP_Z = 0.022
GRIP_BOTTOM_Z = -0.074
GRIP_HALF_DEPTH = 0.0170
GRIP_HALF_WIDTH = 0.0135

BORE_Z = 0.0800
LOWER_TOP_Z = 0.060
UPPER_TOP_Z = 0.098
RECEIVER_REAR_Y = -0.078
UPPER_FRONT_Y = 0.172
RAIL_TOP_Z = UPPER_TOP_Z + 0.0062

HG_FRONT_Y = 0.440
HG_HALF_WIDTH = 0.0235
HG_CENTRE_Z = 0.077
HG_HALF_HEIGHT = 0.021          # top = 0.098 (flush rail), bottom = 0.056
HG_BOTTOM_Z = HG_CENTRE_Z - HG_HALF_HEIGHT

BARREL_R = 0.0095
BARREL_END_Y = 0.560
HIDER_LEN = 0.050
MUZZLE_Y = BARREL_END_Y + HIDER_LEN + 0.002

MAGWELL_Y0 = 0.087
MAGWELL_Y1 = 0.160
MAGWELL_BOTTOM_Z = -0.012
MAGWELL_POS = (0.0, (MAGWELL_Y0 + MAGWELL_Y1) / 2, MAGWELL_BOTTOM_Z)

MAG_HW = 0.0115
MAG_HD = 0.0300
MAG_INSIDE = 0.038
MAG_STD_BELOW = 0.118
MAG_STD_CURVE = 0.030
MAG_EXT_BELOW = 0.156
MAG_EXT_CURVE = 0.044

SIGHT_RAIL_Y = 0.020                     # SightRail marker (receiver mid, on the rail top)
REAR_IRON_Y = -0.060 - SIGHT_RAIL_Y      # in the SightRail frame
FRONT_IRON_Y = 0.418 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0170

UNDER_Y = 0.380
SIDE_Y = 0.405


def build_irons(ctx, mats, parent=None, name="IronSights"):
    """Flip-up irons (rear on the receiver, front at the handguard tip). Origin = SightRail."""
    body, aim = c.build_flipup_irons(ctx, mats, REAR_IRON_Y, FRONT_IRON_Y, 0.0, sight_h=IRON_AIM_DZ,
                                     parent=parent, name=name)
    return body, aim


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    curve = MAG_EXT_CURVE if extended else MAG_STD_CURVE
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=curve, inside=MAG_INSIDE, mat_name="tan",
                           round_r=0.0028, ribs=3 if extended else 2, parent=parent, name=name,
                           window=extended)


def grip_profile():
    return c.raked_grip_profile(GRIP_TOP_Z, GRIP_BOTTOM_Z, GRIP_HALF_DEPTH, GRIP_ANGLE_DEG, palm_swell=0.0025,
                                finger_bumps=3)


GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
