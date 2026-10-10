"""Shared dimensions and part builders for the Tillman Ironworks Mule 12 compact pump shotgun (B4-12).

Private helper: imported by ``mule_12.py`` and ``mule_12_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the raked polymer pistol grip.

Secondary-slot pump gun: short barrel, five-shell tube, no stock as issued (the grip is part of the
receiver). The stock mod is a skeleton steel stock that attaches at ``StockMount`` (nothing to hide).
Tube convention as the Plowman 12: ``Magwell`` sits at the loading port, the tube is built in that frame.
``Pump`` is a separate object; ENV A slides it along local +Z.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 22.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.074

BORE_Z = 0.064
REC_REAR_Y = -0.040
REC_FRONT_Y = 0.165
REC_BOTTOM_Z = 0.014
REC_TOP_Z = 0.088
REC_HW = 0.0145
RAIL_Y0, RAIL_Y1 = 0.010, 0.140
RAIL_TOP_Z = REC_TOP_Z + 0.0062 - 0.001
SIGHT_RAIL_Y = 0.080

BARREL_R = 0.0105
BARREL_END_Y = 0.440
MUZZLE_Y = BARREL_END_Y + 0.001

TUBE_Z = BORE_Z - 0.0255
TUBE_R = 0.0115
TUBE_STD_END = 0.405
TUBE_EXT_END = 0.485
MAGWELL_POS = (0.0, 0.098, REC_BOTTOM_Z)

PUMP_Y0, PUMP_Y1 = 0.205, 0.345
STOCK_MOUNT = (0.0, REC_REAR_Y, 0.056)
UNDER_Y = 0.290
REAR_IRON_Y = -0.050                       # in the SightRail frame
IRON_AIM_DZ = 0.0120


def build_irons(ctx, mats, parent=None, name="GhostRing"):
    """Ghost-ring rear on the receiver rail + front blade on the barrel; origin = SightRail."""
    front_y = BARREL_END_Y - 0.020 - SIGHT_RAIL_Y
    front_base = (BORE_Z + BARREL_R) - RAIL_TOP_Z
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, front_y, front_base, sight_h=IRON_AIM_DZ, parent=parent,
                                name=name)


def build_tube(ctx, mats, extended: bool, parent=None, name="MagTube"):
    """Tube magazine in the Magwell frame (+Z = up into the loading port)."""
    end = TUBE_EXT_END if extended else TUBE_STD_END
    oy, oz = MAGWELL_POS[1], MAGWELL_POS[2]
    z = TUBE_Z - oz
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(TUBE_R, end - REC_FRONT_Y, segments=28, centre=(0.0, (end + REC_FRONT_Y) / 2 - oy, z), axis="Y",
                mat=st)
    mb.cylinder(TUBE_R + 0.0012, 0.020, segments=28, centre=(0.0, end + 0.010 - oy, z), axis="Y", mat=st)
    mb.box((-0.0095, -0.028, 0.004), (0.0095, 0.030, 0.010), mat=st)                     # follower in the port
    if extended:
        clamp_y = end - 0.010 - oy
        mb.box((-0.0125, clamp_y - 0.008, z), (0.0125, clamp_y + 0.008, BORE_Z - oz), mat=st)
        c.ring_y(mb, BARREL_R + 0.003, BARREL_R - 0.0004, clamp_y - 0.008, clamp_y + 0.008, BORE_Z - oz, st,
                 segments=28)
    else:
        clamp_y = end - 0.006 - oy                                                       # barrel band
        mb.box((-0.0100, clamp_y - 0.006, z), (0.0100, clamp_y + 0.006, BORE_Z - oz), mat=st)
    body = c.finish(mb, name, bevel=0.0008, segments=1, parent=parent)
    sh = ctx.builder()
    br = sh.material(mats.brass())
    sh.cylinder(0.0105, 0.004, segments=20, centre=(0.0, 0.020, 0.012), axis="Y", mat=br)
    hull = sh.material(mats.polymer())
    sh.cylinder(0.0100, 0.050, segments=20, centre=(0.0, -0.007, 0.012), axis="Y", mat=hull)
    c.finish(sh, name + "Shell", parent=body)
    return body


def build_folding_stock(ctx, mats, parent=None, name="FoldingStock"):
    """Deployed skeleton steel stock with a rubber pad; origin = StockMount, extends along -Y."""
    mb = ctx.builder()
    st = mb.material(mats.matte())
    rub = mb.material(mats.rubber())
    mb.box((-0.0150, -0.016, -0.024), (0.0150, 0.0, 0.022), mat=st)                     # hinge block
    mb.cylinder(0.0050, 0.034, segments=16, centre=(0.0, -0.010, 0.026), axis="X", mat=st)  # hinge pin
    yr = -0.240
    for x in (-0.0110, 0.0110):
        mb.box((x - 0.0035, yr + 0.004, 0.006), (x + 0.0035, -0.012, 0.018), mat=st)    # top struts
        band = [(-0.012, -0.024), (yr + 0.004, -0.104), (yr + 0.004, -0.090), (-0.012, -0.010)]
        mb.prism(band, axis="X", start=x - 0.0035, end=x + 0.0035, mat=st)              # lower struts
    mb.box((-0.0180, yr - 0.004, -0.112), (0.0180, yr + 0.006, 0.024), mat=st)
    mb.box((-0.0175, yr - 0.018, -0.110), (0.0175, yr - 0.004, 0.022), mat=rub)
    return c.finish(mb, name, bevel=0.0010, segments=1, parent=parent)
