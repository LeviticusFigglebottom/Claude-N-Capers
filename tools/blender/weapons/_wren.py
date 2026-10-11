"""Shared dimensions and part builders for the Halvard Arms Wren .380 pocket pistol (B4-18).

Private helper: imported by ``wren_380.py`` and ``wren_380_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot (grip centre plane, mid depth, 20 mm below the grip top).

Compact single-stack .380 carry pistol: slim black polymer frame with a short grip (two-finger plus a
magazine extension), a bare-steel slide with rear cocking serrations, low snag-free sights, seven-round
flush magazine. ``Slide`` cycles along local +Z (ENV A); ``SightRail`` and ``Eject`` ride on it.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 16.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_COS = math.cos(math.radians(GRIP_ANGLE_DEG))
GRIP_HALF_DEPTH = 0.0185
GRIP_HALF_WIDTH = 0.0118
GRIP_TOP_Z = 0.020
GRIP_BOTTOM_Z = -0.056

FRAME_HW = 0.0105
FRAME_TOP_Z = 0.032
FRAME_BOTTOM_Z = 0.017
FRAME_FRONT_Y = 0.104

SLIDE_HW = 0.0110
SLIDE_REAR_Y = -0.038
SLIDE_FRONT_Y = 0.112
SLIDE_BOTTOM_Z = 0.030
SLIDE_TOP_Z = 0.054
BORE_Z = 0.043
MUZZLE_Y = SLIDE_FRONT_Y + 0.001

SIGHT_RAIL_Y = -0.026
FRONT_SIGHT_Y = 0.104
SIGHT_DZ = 0.0032

MAG_HW = 0.0085
MAG_HD = 0.0150
MAG_INSIDE = 0.070
MAG_STD_BELOW = 0.006
MAG_EXT_BELOW = 0.024

MAGWELL_POS = (0.0, GRIP_TAN * GRIP_BOTTOM_Z, GRIP_BOTTOM_Z)
MAGWELL_ROT = (-math.radians(GRIP_ANGLE_DEG), 0.0, 0.0)
STOCK_MOUNT = (0.0, -GRIP_HALF_DEPTH + GRIP_TAN * -0.010 - 0.002, -0.010)
RAIL_Y = 0.080


def build_rear_sight(ctx, mats, parent=None, name="RearSight"):
    """Low snag-free notch rear sight; origin = slide top centre."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    nh = 0.0015
    prof = [(-0.0075, 0.0), (0.0075, 0.0), (0.0065, 0.0055), (nh, 0.0055), (nh, SIGHT_DZ), (-nh, SIGHT_DZ),
            (-nh, 0.0055), (-0.0065, 0.0055)]
    mb.prism(prof, axis="Y", start=-0.0050, end=0.0045, mat=st)
    return c.finish(mb, name, bevel=0.0004, parent=parent)


def build_reflex(ctx, mats, parent=None, name="ReflexSight"):
    """Micro slide-cut red dot; origin = slide top centre (rear sight dovetail). Adds ``AimPoint``."""
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    mb.box((-0.0105, -0.012, 0.0), (0.0105, 0.016, 0.0055), mat=alu)
    outer = [(-0.0110, 0.0050), (0.0110, 0.0050), (0.0110, 0.0190), (0.0075, 0.0240), (-0.0075, 0.0240),
             (-0.0110, 0.0190)]
    hole = [(-0.0085, 0.0075), (-0.0085, 0.0180), (-0.0060, 0.0215), (0.0060, 0.0215), (0.0085, 0.0180),
            (0.0085, 0.0075)]
    mb.prism(outer, holes=[hole], axis="Y", start=0.002, end=0.014, mat=alu)
    body = c.finish(mb, name, bevel=0.0007, segments=1, parent=parent)
    ln = ctx.builder()
    ln.prism(hole, axis="Y", start=0.0075, end=0.0085, mat=ln.material(mats.lens()))
    c.finish(ln, name + "Lens", parent=body)
    rt = ctx.builder()
    rt.cylinder(0.0006, 0.0002, segments=12, centre=(0.0, 0.0072, 0.0140), axis="Y", mat=rt.material(mats.reticle()))
    c.finish(rt, name + "Reticle", parent=body)
    ctx.marker("AimPoint", (0.0, 0.0072, 0.0140), parent=body)
    return body


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    """Single-stack magazine in the Magwell frame with a finger-rest base pad (longer when extended)."""
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    body = c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.0, inside=MAG_INSIDE, mat_name="steel",
                           round_r=0.0040, ribs=0, parent=parent, name=name, base_drop=0.003)
    bp = ctx.builder()
    poly = bp.material(mats.polymer())
    hd = GRIP_HALF_DEPTH * GRIP_COS
    sleeve = below - 0.004 if extended else 0.0
    bp.prism([(-hd + 0.001, -below - 0.009), (hd + 0.004, -below - 0.009), (hd + 0.006, -below - 0.003),
              (hd + 0.001, -below + sleeve), (-hd + 0.001, -below + sleeve)], axis="X", start=-GRIP_HALF_WIDTH + 0.0005,
             end=GRIP_HALF_WIDTH - 0.0005, mat=poly)
    c.finish(bp, name + "Pad", bevel=0.0015, segments=2, parent=body)
    return body


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    """Short .380 can on a threaded barrel; origin = Muzzle."""
    return c.build_can(ctx, mats, length=0.115, r=0.0130, overlap=0.0, bore_r=0.0042, rings=3, parent=parent,
                       name=name)
