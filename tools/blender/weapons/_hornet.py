"""Shared dimensions and part builders for the Brannock Hornet 9 submachine gun (B4-04).

Private helper: imported by ``hornet_9.py`` and ``hornet_9_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the integral pistol grip.
"""

from __future__ import annotations

import math

from mathutils import Matrix

import _common as c

GRIP_ANGLE_DEG = 16.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.072
GRIP_HALF_DEPTH = 0.0165
GRIP_HALF_WIDTH = 0.0145

BODY_HW = 0.0210
BODY_REAR_Y = -0.078
BODY_FRONT_Y = 0.205
BODY_TOP_Z = 0.096
BORE_Z = 0.070
RAIL_TOP_Z = BODY_TOP_Z + 0.0062
BARREL_END_Y = 0.252
MUZZLE_Y = BARREL_END_Y + 0.001

MAGWELL_Y0 = 0.080
MAGWELL_Y1 = 0.122
MAGWELL_BOTTOM_Z = -0.002
MAGWELL_POS = (0.0, (MAGWELL_Y0 + MAGWELL_Y1) / 2, MAGWELL_BOTTOM_Z)
MAG_HW = 0.0115
MAG_HD = 0.0160
MAG_INSIDE = 0.034
MAG_STD_BELOW = 0.128
MAG_EXT_BELOW = 0.180

STOCK_MOUNT = (0.0, BODY_REAR_Y, BORE_Z)
SIGHT_RAIL_Y = 0.030
UNDER_Y = 0.175
UNDER_Z = 0.034
SIDE_Y = 0.178


def build_irons(ctx, mats, parent=None, name="IronSights"):
    return c.build_flipup_irons(ctx, mats, -0.060 - SIGHT_RAIL_Y, 0.185 - SIGHT_RAIL_Y, 0.0, sight_h=0.0150,
                                parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.020 if extended else 0.012,
                           inside=MAG_INSIDE, mat_name="polymer", round_r=0.0045, ribs=3 if extended else 2,
                           parent=parent, name=name)


def _stock_geometry(mb, mats):
    """Skeleton side-folding stock in the StockMount frame (extends along -Y)."""
    poly = mb.material(mats.polymer())
    steel = mb.material(mats.steel())
    mb.box((-0.016, -0.022, -0.020), (0.016, 0.0, 0.020), mat=poly)                 # hinge block
    mb.cylinder(0.0055, 0.042, segments=16, centre=(0.0, -0.011, 0.0), axis="Z", mat=steel)   # hinge pin
    # two struts converging to the butt plate
    for z0, z1 in ((0.012, 0.018), (-0.016, -0.050)):
        ya, yb = -0.018, -0.238
        band = [(ya, z0 - 0.0055), (yb, z1 - 0.0055), (yb, z1 + 0.0055), (ya, z0 + 0.0055)]
        mb.prism(band, axis="X", start=-0.0075, end=0.0075, mat=poly)
    # butt plate with a rubber-less polymer pad, slightly curved
    prof = [(-0.235, 0.032), (-0.248, 0.030), (-0.252, -0.010), (-0.250, -0.068), (-0.236, -0.070),
            (-0.232, -0.010)]
    mb.prism(prof, axis="X", start=-0.0175, end=0.0175, mat=poly)
    # cheek strip on the top strut
    mb.box((-0.0095, -0.200, 0.016), (0.0095, -0.060, 0.025), mat=poly)


def build_stock(ctx, mats, folded: bool, parent=None, name="Stock"):
    mb = ctx.builder()
    _stock_geometry(mb, mats)
    if folded:
        # swung forward 180 deg around the hinge pin onto the right side of the receiver
        mb.transform(Matrix.Translation((0.016 + BODY_HW + 0.002, -0.022, 0.0)) @ Matrix.Rotation(math.pi, 4, "Z")
                     @ Matrix.Translation((0.0, 0.011, 0.0)))
    return c.finish(mb, name, bevel=0.0015, segments=2, parent=parent)
