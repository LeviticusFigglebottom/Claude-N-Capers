"""Shared dimensions and part builders for the Marrow & Kell Warden .45 heavy pistol (B4-04).

Private helper: imported by ``warden_45.py`` and ``warden_45_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot (grip centre plane, mid depth, 20 mm below the grip top).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 17.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_HALF_DEPTH = 0.0215
GRIP_HALF_WIDTH = 0.0120          # steel frame; walnut panels add 3 mm per side
PANEL_T = 0.0030
GRIP_TOP_Z = 0.020
GRIP_BOTTOM_Z = -0.076

FRAME_HW = 0.0105
FRAME_TOP_Z = 0.035
FRAME_BOTTOM_Z = 0.018
FRAME_FRONT_Y = 0.150

SLIDE_HW = 0.0115
SLIDE_REAR_Y = -0.048
SLIDE_FRONT_Y = 0.168
SLIDE_BOTTOM_Z = 0.033
SLIDE_TOP_Z = 0.062
BORE_Z = 0.048
MUZZLE_Y = SLIDE_FRONT_Y + 0.003

SIGHT_RAIL_Y = -0.034
FRONT_SIGHT_Y = 0.156
SIGHT_DZ = 0.0040

MAG_HW = 0.0080
MAG_HD = 0.0165
MAG_INSIDE = 0.085
MAG_EXT_BELOW = 0.026

GRIP_COS = math.cos(math.radians(GRIP_ANGLE_DEG))
GRIP_SIN = math.sin(math.radians(GRIP_ANGLE_DEG))
MAGWELL_POS = (0.0, GRIP_TAN * GRIP_BOTTOM_Z, GRIP_BOTTOM_Z)
MAGWELL_ROT = (-math.radians(GRIP_ANGLE_DEG), 0.0, 0.0)


def build_rear_sight(ctx, mats, parent=None, name="RearSight"):
    """Low-profile rear sight with a square notch; origin = slide top centre."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    nh = 0.0017
    prof = [(-0.0080, 0.0), (0.0080, 0.0), (0.0080, 0.0068), (nh, 0.0068), (nh, SIGHT_DZ), (-nh, SIGHT_DZ),
            (-nh, 0.0068), (-0.0080, 0.0068)]
    mb.prism(prof, axis="Y", start=-0.0055, end=0.0050, mat=st)
    body = c.finish(mb, name, bevel=0.0004, parent=parent)
    dt = ctx.builder()
    d = dt.material(mats.dot())
    for x in (-0.0045, 0.0045):
        dt.cylinder(0.0009, 0.0006, segments=12, centre=(x, -0.0056, SIGHT_DZ - 0.0012), axis="Y", mat=d)
    c.finish(dt, name + "Dots", parent=body)
    return body


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    """Single-stack magazine in the Magwell frame; the standard one sits flush with a wood-tone pad."""
    below = MAG_EXT_BELOW if extended else 0.0
    body = c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.0, inside=MAG_INSIDE, mat_name="steel",
                           round_r=0.0055, parent=parent, name=name, base_drop=0.005)
    if extended:
        sl = ctx.builder()
        rub = sl.material(mats.rubber())
        hd = GRIP_HALF_DEPTH * GRIP_COS
        sl.prism([(-hd + 0.001, -below), (hd - 0.001, -below), (hd, 0.0), (-hd, 0.0)], axis="X",
                 start=-GRIP_HALF_WIDTH - PANEL_T + 0.0008, end=GRIP_HALF_WIDTH + PANEL_T - 0.0008, mat=rub)
        for i in range(3):
            z = -below + 0.006 + i * 0.007
            sl.box((-GRIP_HALF_WIDTH - PANEL_T + 0.0004, -hd + 0.006, z), (GRIP_HALF_WIDTH + PANEL_T - 0.0004, hd - 0.004,
                   z + 0.0025), mat=rub)
        c.finish(sl, name + "Sleeve", bevel=0.0012, segments=2, parent=body)
    return body


def build_compensator(ctx, mats, parent=None, name="Compensator"):
    """Slide-profile compensator on the barrel; origin = ``Muzzle``. Adds its own ``Muzzle``."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    dz0 = SLIDE_BOTTOM_Z - BORE_Z
    dz1 = SLIDE_TOP_Z - BORE_Z
    length = 0.036
    prof = [(-SLIDE_HW, dz0), (SLIDE_HW, dz0), (SLIDE_HW, dz1 - 0.005), (SLIDE_HW - 0.004, dz1),
            (-SLIDE_HW + 0.004, dz1), (-SLIDE_HW, dz1 - 0.005)]
    mb.prism(prof, axis="Y", start=-0.003, end=length, mat=st)
    body = c.finish(mb, name, bevel=0.0012, segments=2, parent=parent)
    pt = ctx.builder()
    dark = pt.material(mats.polymer())
    for i in range(3):                          # top ports
        y = 0.006 + i * 0.009
        pt.box((-0.0040, y, dz1 - 0.0004), (0.0040, y + 0.005, dz1 + 0.0003), mat=dark)
    pt.cylinder(0.0060, 0.001, segments=24, centre=(0.0, length + 0.0004, 0.0), axis="Y", mat=dark)
    c.finish(pt, name + "Ports", parent=body)
    ctx.marker("Muzzle", (0.0, length + 0.001, 0.0), parent=body)
    return body
