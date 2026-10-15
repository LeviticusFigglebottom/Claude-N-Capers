"""Shared dimensions and part builders for the Graff-Lindqvist Harrow 12 box-fed shotgun (B4-18).

Private helper: imported by ``harrow_12.py`` and ``harrow_12_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the polymer pistol grip.

Semi-automatic 12-gauge on a long-stroke rifle action: stamped steel receiver with a railed dust
cover, polymer handguard and gas tube, heavy plain barrel (muzzle devices go on ``Muzzle``), a wide
eight-shell box magazine (``Magwell`` under the receiver), fixed polymer stock (``StockStock``).
Reloads like a rifle (ENV D ``rifle`` set), sounds like a shotgun.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 18.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

REC_HW = 0.0180
REC_REAR_Y = -0.100
REC_FRONT_Y = 0.150
REC_BOTTOM_Z = 0.026
REC_TOP_Z = 0.084
BORE_Z = 0.060
RAIL_Y0, RAIL_Y1 = -0.085, 0.110
RAIL_TOP_Z = REC_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.000

HG_Y0, HG_Y1 = 0.152, 0.300
BARREL_R = 0.0120
BARREL_END_Y = 0.470
COMP_LEN = 0.035                 # PO6-13 top-ported compensator
COMP_SLEEVE = 0.022              # ... slipped this far back over the barrel end
MUZZLE_Y = BARREL_END_Y + COMP_LEN - COMP_SLEEVE + 0.001

MAG_HW = 0.0165
MAG_HD = 0.0380
MAG_INSIDE = 0.026
MAG_STD_BELOW = 0.090
MAG_EXT_BELOW = 0.140
MAGWELL_POS = (0.0, 0.090, REC_BOTTOM_Z)

STOCK_MOUNT = (0.0, REC_REAR_Y, 0.056)
UNDER_Y = 0.240
SIDE_Y = 0.240
REAR_IRON_Y = -0.070 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0150


def build_irons(ctx, mats, parent=None, name="IronSights"):
    """Rear aperture on the cover rail + front post on the gas block; origin = SightRail."""
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, HG_Y1 + 0.016 - SIGHT_RAIL_Y, (BORE_Z + 0.028) - RAIL_TOP_Z,
                                sight_h=IRON_AIM_DZ, parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.004 if not extended else 0.010,
                           inside=MAG_INSIDE, mat_name="polymer", round_r=0.0100, ribs=2 if extended else 1,
                           parent=parent, name=name, base_drop=0.007)


def build_stock(ctx, mats, parent=None, name="Stock"):
    prof = [(0.004, 0.028), (0.004, -0.030), (-0.050, -0.042), (-0.250, -0.096), (-0.262, -0.096),
            (-0.262, 0.030), (-0.240, 0.034), (-0.030, 0.032)]
    return c.build_butt_stock(ctx, mats, "polymer", prof, 0.0185, name=name, parent=parent, pad_y=-0.262,
                              pad_z=(-0.096, 0.030))


def build_brake(ctx, mats, parent=None, name="MuzzleBrake"):
    """Ported brake threaded on the barrel; origin = Muzzle. Adds its own ``Muzzle``."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    dark = mb.material(mats.polymer())
    length = 0.060
    c.ring_y(mb, 0.0165, 0.0095, -0.004, length, 0.0, st, segments=28)
    for i in range(4):
        y = 0.010 + i * 0.012
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * 0.0150, side * 0.0172))
            mb.box((lo, y, -0.006), (hi, y + 0.007, 0.006), mat=dark)
        mb.box((-0.006, y, 0.0150), (0.006, y + 0.007, 0.0172), mat=dark)
    body = c.finish(mb, name, bevel=0.0006, parent=parent)
    ctx.marker("Muzzle", (0.0, length + 0.001, 0.0), parent=body)
    return body
