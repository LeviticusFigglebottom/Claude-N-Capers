"""Shared dimensions and part builders for the Brannock Wasp PDW (B4-12).

Private helper: imported by ``wasp_pdw.py`` and ``wasp_pdw_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the near-vertical pistol grip.

Compact 4.6 mm personal defence weapon: one-piece tan polymer body with a full-length top rail,
the magazine inserted through the pistol grip (``Magwell`` at the grip base, raked with the grip),
folding front grip moulded under the nose, short barrel with a three-prong flash hider, collapsed
telescopic stock (``StockMount/StockStock``).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 10.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_COS = math.cos(math.radians(GRIP_ANGLE_DEG))
GRIP_HALF_DEPTH = 0.0205
GRIP_HALF_WIDTH = 0.0150
GRIP_TOP_Z = 0.034
GRIP_BOTTOM_Z = -0.076

BODY_HW = 0.0200
BODY_REAR_Y = -0.085
BODY_FRONT_Y = 0.175
BODY_BOTTOM_Z = 0.034
BODY_TOP_Z = 0.096
BORE_Z = 0.072
RAIL_Y0, RAIL_Y1 = -0.075, 0.165
RAIL_TOP_Z = BODY_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.030

BARREL_END_Y = 0.225
HIDER_LEN = 0.030
MUZZLE_Y = BARREL_END_Y + HIDER_LEN + 0.001

MAG_HW = 0.0105
MAG_HD = 0.0150
MAG_INSIDE = 0.100
MAG_STD_BELOW = 0.020
MAG_EXT_BELOW = 0.058
MAGWELL_POS = (0.0, GRIP_TAN * GRIP_BOTTOM_Z, GRIP_BOTTOM_Z)
MAGWELL_ROT = (-math.radians(GRIP_ANGLE_DEG), 0.0, 0.0)

STOCK_MOUNT = (0.0, BODY_REAR_Y, BORE_Z - 0.006)
UNDER_Y = 0.125
SIDE_Y = 0.140
IRON_AIM_DZ = 0.0150
REAR_IRON_Y = -0.065 - SIGHT_RAIL_Y


def build_irons(ctx, mats, parent=None, name="IronSights"):
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, RAIL_Y1 - 0.012 - SIGHT_RAIL_Y, 0.0, sight_h=IRON_AIM_DZ,
                                parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    """Polymer magazine through the grip; origin = Magwell (grip base), +Z up the grip."""
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    body = c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.0, inside=MAG_INSIDE, mat_name="tan",
                           round_r=0.0036, ribs=2 if extended else 0, parent=parent, name=name, base_drop=0.004)
    bp = ctx.builder()
    poly = bp.material(mats.polymer())
    hd = GRIP_HALF_DEPTH * GRIP_COS
    bp.prism([(-hd + 0.002, -below - 0.008), (hd, -below - 0.008), (hd, -below - 0.002), (-hd + 0.002, -below - 0.002)],
             axis="X", start=-GRIP_HALF_WIDTH + 0.001, end=GRIP_HALF_WIDTH - 0.001, mat=poly)
    c.finish(bp, name + "Pad", bevel=0.0015, segments=2, parent=body)
    return body


def build_stock(ctx, mats, parent=None, name="Stock"):
    """Collapsed telescopic stock: two steel rods along the body sides and a polymer butt plate; origin =
    StockMount (body rear on the bore line), extends a little along -Y."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    poly = mb.material(mats.polymer())
    yr = -0.026
    for x in (-BODY_HW - 0.0040, BODY_HW + 0.0040):
        mb.cylinder(0.0042, 0.150, segments=12, centre=(x, yr + 0.075, 0.004), axis="Y", mat=st)
    mb.prism(c.rounded_rect(BODY_HW + 0.0085, 0.050, 0.010, 0.0, -0.022, corner_segments=3), axis="Y", start=yr - 0.018,
             end=yr, mat=poly)
    mb.box((-0.0150, yr - 0.024, -0.064), (0.0150, yr - 0.018, 0.020), mat=poly)
    return c.finish(mb, name, bevel=0.0015, segments=2, parent=parent)


def build_end_cap(ctx, mats, parent=None, name="EndCap"):
    """Stockless end cap closing the rod channels; origin = StockMount."""
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    mb.prism(c.rounded_rect(BODY_HW + 0.002, 0.026, 0.008, 0.0, 0.0, corner_segments=3), axis="Y", start=-0.010,
             end=0.0, mat=poly)
    mb.box((-0.0060, -0.014, -0.012), (0.0060, -0.010, 0.012), mat=mb.material(mats.steel()))   # sling loop
    return c.finish(mb, name, bevel=0.0015, segments=2, parent=parent)


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    """Slim can over the flash hider; origin = Muzzle."""
    return c.build_can(ctx, mats, length=0.160, r=0.0160, overlap=HIDER_LEN - 0.004, bore_r=0.0040, parent=parent,
                       name=name)
