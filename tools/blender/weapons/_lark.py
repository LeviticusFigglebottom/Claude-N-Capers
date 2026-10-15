"""Shared dimensions and part builders for the Halvard Arms Lark Carbine (B4-18).

Private helper: imported by ``lark_carbine.py`` and ``lark_carbine_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip.

Short 5.56 carbine: machined steel receiver with an integral full-length top rail, short tan polymer
handguard with a gas tube above the barrel, curved tan magazine, 3-port brake, side-folding tan
skeleton stock on a hinge block (``StockMount/StockStock``; the folded variant lies along the right
side of the receiver).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 18.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

REC_HW = 0.0165
REC_REAR_Y = -0.075
REC_FRONT_Y = 0.160
REC_BOTTOM_Z = 0.028
REC_TOP_Z = 0.086
BORE_Z = 0.062
RAIL_Y0, RAIL_Y1 = -0.068, 0.150
RAIL_TOP_Z = REC_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.020

HG_Y0, HG_Y1 = 0.162, 0.292
BARREL_END_Y = 0.330
BRAKE_LEN = 0.040                # PO6-13 3-port side brake
MUZZLE_Y = BARREL_END_Y + BRAKE_LEN + 0.001

MAG_HW = 0.0120
MAG_HD = 0.0300
MAG_INSIDE = 0.030
MAG_STD_BELOW = 0.140
MAG_EXT_BELOW = 0.190
MAGWELL_POS = (0.0, 0.094, REC_BOTTOM_Z - 0.006)

STOCK_MOUNT = (0.0, REC_REAR_Y, 0.058)
UNDER_Y = 0.235
SIDE_Y = 0.235
REAR_IRON_Y = -0.058 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0150


def build_irons(ctx, mats, parent=None, name="IronSights"):
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, RAIL_Y1 - 0.014 - SIGHT_RAIL_Y, 0.0, sight_h=IRON_AIM_DZ,
                                parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD * 0.62, curve=0.026 if not extended else 0.040,
                           inside=MAG_INSIDE, mat_name="tan", round_r=0.0045, ribs=3, parent=parent, name=name)


def build_stock(ctx, mats, folded: bool, parent=None, name="Stock"):
    """Skeleton stock on a hinge block; origin = StockMount, extends along -Y (or folded along +X side)."""
    mb = ctx.builder()
    st = mb.material(mats.matte())
    mb.box((-0.0150, -0.018, -0.026), (0.0150, 0.0, 0.020), mat=st)
    mb.cylinder(0.0050, 0.050, segments=16, centre=(0.0175, -0.009, -0.003), axis="Z", mat=st)   # hinge pin (right)
    arm = ctx.builder()
    tm = arm.material(mats.tan())
    outer = [(-0.016, 0.018), (-0.225, 0.022), (-0.240, 0.012), (-0.240, -0.080), (-0.226, -0.086),
             (-0.200, -0.066), (-0.016, -0.022)]
    hole = [(-0.040, 0.006), (-0.212, 0.008), (-0.222, 0.000), (-0.222, -0.056), (-0.206, -0.054),
            (-0.040, -0.008)]
    arm.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0110, end=0.0110, mat=tm)
    arm.box((-0.0150, -0.252, -0.084), (0.0150, -0.240, 0.020), mat=arm.material(mats.rubber()))
    if folded:
        # swing 180 deg about the right-hand hinge pin: the arm lies forward along the receiver's right side
        arm.translate((-0.0175, 0.009, 0.0))
        arm.transform(c.rot_matrix(math.pi, "Z"))
        arm.translate((0.0175, -0.009, 0.0))
    body = c.finish(mb, name, bevel=0.0010, segments=1, parent=parent)
    c.finish(arm, name + "Arm", bevel=0.0015, segments=2, parent=body)
    return body


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    return c.build_can(ctx, mats, length=0.150, r=0.0180, overlap=BRAKE_LEN - 0.004, bore_r=0.0045, parent=parent,
                       name=name)
