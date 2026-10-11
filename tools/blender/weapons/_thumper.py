"""Shared dimensions and part builders for the Brannock Thumper 40 single-shot grenade launcher (B4-18).

Private helper: imported by ``thumper_40.py`` and ``thumper_40_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the walnut pistol grip.

Break-open 40 mm launcher: steel receiver block, a ``Breech`` node (origin = hinge pin at the receiver's
front-bottom; opening = a negative rotation about local X, about 45 degrees, so the muzzle drops) that
carries the fat barrel, the walnut forend, a short top rail with the folding leaf sight (``SightRail``),
``Muzzle``, ``Magwell`` at the chamber mouth (insertion axis = the bore) with the loaded grenade
(``StockMagazine``), ``Underbarrel``, ``SideRail``, ``LeftHandIK`` and ``Eject``. Walnut buttstock =
``StockMount/StockStock``.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 22.0
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.074

REC_HW = 0.0250
REC_REAR_Y = -0.022
REC_FRONT_Y = 0.060
REC_BOTTOM_Z = 0.020
REC_TOP_Z = 0.080
BORE_Z = 0.058
BARREL_R = 0.0255
BORE_R = 0.0205
HINGE = (0.0, REC_FRONT_Y - 0.004, REC_BOTTOM_Z + 0.006)
BARREL_END_Y = 0.330
MUZZLE_Y = BARREL_END_Y + 0.001
FOREND_Y0, FOREND_Y1 = 0.080, 0.250
RAIL_Y0, RAIL_Y1 = 0.090, 0.210
RAIL_BASE_Z = BORE_Z + BARREL_R - 0.002
RAIL_TOP_Z = RAIL_BASE_Z + 0.0062
SIGHT_RAIL_Y = 0.150
STOCK_MOUNT = (0.0, -0.024, 0.050)
UNDER_Y = 0.170
LEAF_H = 0.022


def hinge_local(p):
    return (p[0] - HINGE[0], p[1] - HINGE[1], p[2] - HINGE[2])


def build_leaf(ctx, mats, parent=None, name="LeafSight"):
    """Folding ladder leaf on the barrel rail plus a front post at the muzzle; origin = SightRail.
    Returns the aim height."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    y = -0.040
    mb.box((-0.0110, y - 0.012, 0.0), (0.0110, y + 0.012, 0.005), mat=st)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * 0.0070, side * 0.0100))
        mb.box((lo, y - 0.002, 0.004), (hi, y + 0.002, LEAF_H + 0.006), mat=st)
    for z in (0.010, 0.016, LEAF_H + 0.004):
        mb.box((-0.0070, y - 0.0015, z), (-0.0015, y + 0.0015, z + 0.002), mat=st)
        mb.box((0.0015, y - 0.0015, z), (0.0070, y + 0.0015, z + 0.002), mat=st)
    fy = BARREL_END_Y - 0.020 - SIGHT_RAIL_Y
    fz = (BORE_Z + BARREL_R) - RAIL_TOP_Z
    mb.box((-0.0050, fy - 0.006, fz - 0.001), (0.0050, fy + 0.006, fz + 0.004), mat=st)
    mb.box((-0.0012, fy - 0.0015, fz + 0.004), (0.0012, fy + 0.0015, LEAF_H), mat=st)
    return c.finish(mb, name, bevel=0.0003, parent=parent), LEAF_H


def build_grenade(ctx, mats, parent=None, name="GrenadeRound"):
    """40 mm round in the Magwell frame (+Z = into the chamber)."""
    mb = ctx.builder()
    br = mb.material(mats.alu())
    head = mb.material(mats.olive())
    mb.cylinder(BORE_R - 0.0006, 0.050, segments=28, centre=(0.0, 0.0, 0.026), axis="Z", mat=br)
    mb.cylinder(BORE_R + 0.0012, 0.003, segments=28, centre=(0.0, 0.0, 0.0005), axis="Z", mat=br)       # rim
    mb.cylinder(BORE_R - 0.0006, 0.030, segments=28, centre=(0.0, 0.0, 0.066), axis="Z", mat=head)
    c.cone_z(mb, BORE_R - 0.0006, 0.081, 0.100, head, segments=28)
    return c.finish(mb, name, bevel=0.0004, parent=parent)


def build_stock(ctx, mats, stockless: bool, parent=None, name="Stock"):
    if stockless:
        mb = ctx.builder()
        st = mb.material(mats.steel())
        mb.prism(c.rounded_rect(0.0170, 0.026, 0.008, 0.0, -0.004, corner_segments=3), axis="Y", start=-0.010,
                 end=0.002, mat=st)
        mb.box((-0.0050, -0.016, -0.010), (0.0050, -0.010, 0.010), mat=st)
        return c.finish(mb, name, bevel=0.0012, segments=1, parent=parent)
    prof = [(0.004, 0.028), (0.004, -0.030), (-0.010, -0.080), (-0.030, -0.096), (-0.060, -0.080),
            (-0.250, -0.110), (-0.262, -0.110), (-0.262, 0.024), (-0.240, 0.030), (-0.030, 0.030)]
    return c.build_butt_stock(ctx, mats, "wood", prof, 0.0200, name=name, parent=parent, pad_y=-0.262,
                              pad_z=(-0.110, 0.024), taper=lambda y, z: 0.82 if y > -0.05 else 1.0)
