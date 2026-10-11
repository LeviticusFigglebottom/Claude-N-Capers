"""Shared dimensions and part builders for the Graff-Lindqvist Ferret 9 open-bolt SMG (B4-18).

Private helper: imported by ``ferret_9.py`` and ``ferret_9_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the near-vertical pistol grip.

Boxy stamped-steel receiver with a ribbed top cover and a cocking knob, the 32-round stick magazine
inserted through the grip (``Magwell`` at the grip base), short barrel held by a knurled barrel nut,
polymer lower handguard, folding steel stock folded under the receiver (``StockMount/StockStock``), a
short optics rail on the top cover behind the rear sight.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 6.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_COS = math.cos(math.radians(GRIP_ANGLE_DEG))
GRIP_HALF_DEPTH = 0.0215
GRIP_HALF_WIDTH = 0.0160
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.078

REC_HW = 0.0200
REC_REAR_Y = -0.115
REC_FRONT_Y = 0.150
REC_BOTTOM_Z = 0.022
REC_TOP_Z = 0.080
BORE_Z = 0.058
RAIL_Y0, RAIL_Y1 = -0.100, -0.010
RAIL_TOP_Z = REC_TOP_Z + 0.0062
SIGHT_RAIL_Y = -0.060

BARREL_END_Y = 0.205
MUZZLE_Y = BARREL_END_Y + 0.001

MAG_HW = 0.0110
MAG_HD = 0.0155
MAG_INSIDE = 0.100
MAG_STD_BELOW = 0.060
MAG_EXT_BELOW = 0.105
MAGWELL_POS = (0.0, GRIP_TAN * GRIP_BOTTOM_Z, GRIP_BOTTOM_Z)
MAGWELL_ROT = (-math.radians(GRIP_ANGLE_DEG), 0.0, 0.0)

STOCK_MOUNT = (0.0, REC_REAR_Y, BORE_Z - 0.010)
UNDER_Y = 0.100
SIDE_Y = 0.110
REAR_IRON_Y = -0.010 - SIGHT_RAIL_Y       # rear sight just ahead of the rail, in the SightRail frame
FRONT_IRON_Y = 0.135 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0150


def build_irons(ctx, mats, parent=None, name="IronSights"):
    """Flip rear aperture on the cover + a protected front post on the receiver nose; origin = SightRail."""
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, FRONT_IRON_Y, REC_TOP_Z - RAIL_TOP_Z, sight_h=IRON_AIM_DZ,
                                parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    """Steel stick magazine through the grip; origin = Magwell (grip base), +Z up the grip."""
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.0, inside=MAG_INSIDE, mat_name="steel",
                           round_r=0.0040, ribs=3 if extended else 2, parent=parent, name=name, base_drop=0.005)


def build_folded_stock(ctx, mats, parent=None, name="FoldingStock"):
    """Folding steel stock folded forward under the receiver; origin = StockMount (receiver rear)."""
    mb = ctx.builder()
    st = mb.material(mats.matte())
    z = REC_BOTTOM_Z - BORE_Z + 0.010
    mb.box((-0.0120, -0.012, -0.022), (0.0120, 0.004, 0.012), mat=st)                     # hinge block
    mb.cylinder(0.0045, 0.030, segments=14, centre=(0.0, -0.006, -0.018), axis="X", mat=st)
    for x in (-REC_HW - 0.0035, REC_HW + 0.0035):
        mb.box((x - 0.0025, -0.006, z - 0.004), (x + 0.0025, 0.200, z + 0.004), mat=st)    # side arms
    mb.box((-REC_HW - 0.006, 0.192, z - 0.030), (REC_HW + 0.006, 0.204, z + 0.004), mat=st)  # butt plate
    return c.finish(mb, name, bevel=0.0008, segments=1, parent=parent)


def build_wood_stock(ctx, mats, parent=None, name="WoodStock"):
    """Fixed walnut stock; origin = StockMount, extends along -Y."""
    prof = [(0.004, 0.014), (0.004, -0.030), (-0.060, -0.040), (-0.230, -0.080), (-0.240, -0.078),
            (-0.240, 0.018), (-0.220, 0.024), (-0.020, 0.020)]
    return c.build_butt_stock(ctx, mats, "wood", prof, 0.0170, name=name, parent=parent, pad_y=-0.240,
                              pad_z=(-0.078, 0.018))


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    """Fat 9 mm can on the barrel nut; origin = Muzzle."""
    return c.build_can(ctx, mats, length=0.165, r=0.0190, overlap=0.0, bore_r=0.0050, rings=4, parent=parent,
                       name=name)
