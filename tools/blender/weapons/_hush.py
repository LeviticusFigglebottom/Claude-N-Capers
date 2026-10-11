"""Shared dimensions and part builders for the Tillman Hush 9 integrally suppressed SMG (B4-18).

Private helper: imported by ``hush_9.py`` and ``hush_9_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the polymer pistol grip.

Round-topped stamped receiver with a clamp-on optics rail, polymer trigger housing, curved 30-round
magazine ahead of the trigger guard (``Magwell`` under the receiver), a fat integral suppressor that
starts inside a slim polymer handguard and runs to the muzzle (no ``SUPPRESSOR`` slot), a cocking tube
on the upper left and a retractable two-rail stock (``StockMount/StockStock``).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 15.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.022
GRIP_BOTTOM_Z = -0.076

REC_HW = 0.0190
REC_REAR_Y = -0.105
REC_FRONT_Y = 0.150
REC_BOTTOM_Z = 0.040
REC_TOP_Z = 0.090
BORE_Z = 0.066
RAIL_Y0, RAIL_Y1 = -0.095, 0.020
RAIL_TOP_Z = REC_TOP_Z + 0.0062
SIGHT_RAIL_Y = -0.040

CAN_R = 0.0205
CAN_Y0, CAN_Y1 = 0.150, 0.400
HG_Y1 = 0.270
MUZZLE_Y = CAN_Y1 + 0.004

MAG_HW = 0.0110
MAG_HD = 0.0150
MAG_INSIDE = 0.026
MAG_STD_BELOW = 0.120
MAG_EXT_BELOW = 0.160
MAGWELL_POS = (0.0, 0.088, REC_BOTTOM_Z)

STOCK_MOUNT = (0.0, REC_REAR_Y, 0.070)
UNDER_Y = 0.215
SIDE_Y = 0.220
REAR_IRON_Y = -0.088 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0170


def build_irons(ctx, mats, parent=None, name="IronSights"):
    """Rear aperture on the receiver + hooded front post on the can; origin = SightRail."""
    front_base = (BORE_Z + CAN_R) - RAIL_TOP_Z
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, CAN_Y1 - 0.025 - SIGHT_RAIL_Y, front_base,
                                sight_h=IRON_AIM_DZ, parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    """Curved steel magazine; origin = Magwell (receiver bottom), +Z = insertion (up)."""
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.026 if not extended else 0.036,
                           inside=MAG_INSIDE, mat_name="steel", round_r=0.0040, ribs=3, parent=parent, name=name)


def build_stock(ctx, mats, collapsed: bool, parent=None, name="Stock"):
    """Retractable two-rail stock; origin = StockMount (receiver rear), extends along -Y."""
    mb = ctx.builder()
    st = mb.material(mats.matte())
    rub = mb.material(mats.rubber())
    yr = -0.070 if collapsed else -0.210
    mb.box((-0.0150, -0.010, -0.024), (0.0150, 0.0, 0.022), mat=st)                      # end cap
    for x in (-0.0135, 0.0135):
        mb.box((x - 0.0030, yr, 0.004), (x + 0.0030, 0.0 if not collapsed else 0.0, 0.012), mat=st)
    mb.prism(c.rounded_rect(0.0170, 0.048, 0.010, 0.0, -0.024, corner_segments=3), axis="Y", start=yr - 0.010,
             end=yr, mat=st)
    mb.box((-0.0160, yr - 0.022, -0.070), (0.0160, yr - 0.010, 0.022), mat=rub)
    return c.finish(mb, name, bevel=0.0010, segments=1, parent=parent)
