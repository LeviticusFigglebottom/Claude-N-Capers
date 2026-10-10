"""Shared dimensions and part builders for the Halvard Arms Sparrow MP machine pistol (B4-12).

Private helper: imported by ``sparrow_mp.py`` and ``sparrow_mp_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot (grip centre plane, mid depth, 20 mm below the grip top).

Select-fire 9 mm machine pistol: polymer frame with a long dust-cover rail and an integral front
hand-stop, steel slide with a ported muzzle shroud, 20-round magazine that stands proud of the grip,
fire selector on the left. ``Slide`` cycles along local +Z (ENV A); ``SightRail`` and ``Eject`` ride
on it. The clip-on wire stock mod attaches at ``StockMount`` on the grip's back strap.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 18.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_COS = math.cos(math.radians(GRIP_ANGLE_DEG))
GRIP_HALF_DEPTH = 0.0210
GRIP_HALF_WIDTH = 0.0148
GRIP_TOP_Z = 0.020
GRIP_BOTTOM_Z = -0.072

FRAME_HW = 0.0120
FRAME_TOP_Z = 0.035
FRAME_BOTTOM_Z = 0.018
FRAME_FRONT_Y = 0.160

SLIDE_HW = 0.0128
SLIDE_REAR_Y = -0.042
SLIDE_FRONT_Y = 0.140
SLIDE_BOTTOM_Z = 0.033
SLIDE_TOP_Z = 0.062
BORE_Z = 0.048
SHROUD_LEN = 0.030
MUZZLE_Y = SLIDE_FRONT_Y + SHROUD_LEN + 0.002

SIGHT_RAIL_Y = -0.028
FRONT_SIGHT_Y = 0.128
SIGHT_DZ = 0.0040

MAG_HW = 0.0108
MAG_HD = 0.0160
MAG_INSIDE = 0.086
MAG_STD_BELOW = 0.026
MAG_EXT_BELOW = 0.082

MAGWELL_POS = (0.0, GRIP_TAN * GRIP_BOTTOM_Z, GRIP_BOTTOM_Z)
MAGWELL_ROT = (-math.radians(GRIP_ANGLE_DEG), 0.0, 0.0)
STOCK_MOUNT = (0.0, -GRIP_HALF_DEPTH + GRIP_TAN * -0.010 - 0.002, -0.010)
RAIL_Y = 0.120


def build_rear_sight(ctx, mats, parent=None, name="RearSight"):
    """Square-notch rear sight; origin = slide top centre."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    nh = 0.0017
    prof = [(-0.0085, 0.0), (0.0085, 0.0), (0.0085, 0.0070), (nh, 0.0070), (nh, SIGHT_DZ), (-nh, SIGHT_DZ),
            (-nh, 0.0070), (-0.0085, 0.0070)]
    mb.prism(prof, axis="Y", start=-0.0060, end=0.0050, mat=st)
    body = c.finish(mb, name, bevel=0.0004, parent=parent)
    dt = ctx.builder()
    d = dt.material(mats.dot())
    for x in (-0.0048, 0.0048):
        dt.cylinder(0.0009, 0.0006, segments=12, centre=(x, -0.0061, SIGHT_DZ - 0.0012), axis="Y", mat=d)
    c.finish(dt, name + "Dots", parent=body)
    return body


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    """Double-stack magazine in the Magwell frame with a flared polymer base pad."""
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    body = c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=0.0, inside=MAG_INSIDE, mat_name="steel",
                           round_r=0.0045, ribs=3 if extended else 0, parent=parent, name=name, base_drop=0.004)
    bp = ctx.builder()
    poly = bp.material(mats.polymer())
    hd = GRIP_HALF_DEPTH * GRIP_COS
    bp.prism([(-hd + 0.001, -below - 0.010), (hd + 0.002, -below - 0.010), (hd + 0.001, -below - 0.003),
              (-hd, -below - 0.003)], axis="X", start=-GRIP_HALF_WIDTH + 0.001, end=GRIP_HALF_WIDTH - 0.001, mat=poly)
    c.finish(bp, name + "Pad", bevel=0.0015, segments=2, parent=body)
    return body


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    """Slim 9 mm can on the shroud's thread; origin = Muzzle."""
    return c.build_can(ctx, mats, length=0.150, r=0.0145, overlap=0.0, bore_r=0.0050, parent=parent, name=name)


def build_stock(ctx, mats, parent=None, name="WireStock"):
    """Clip-on folding wire stock (deployed); origin = StockMount on the grip back strap, extends -Y."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    rub = mb.material(mats.rubber())
    mb.box((-0.0120, -0.010, -0.030), (0.0120, 0.002, 0.034), mat=st)                   # clamp shoe
    yr = -0.230
    for x in (-0.0105, 0.0105):
        top = [(-0.008, 0.026), (yr + 0.004, 0.050), (yr + 0.004, 0.058), (-0.008, 0.034)]
        mb.prism(top, axis="X", start=x - 0.0030, end=x + 0.0030, mat=st)
        low = [(-0.008, -0.026), (yr + 0.004, -0.060), (yr + 0.004, -0.052), (-0.008, -0.018)]
        mb.prism(low, axis="X", start=x - 0.0030, end=x + 0.0030, mat=st)
    mb.box((-0.0160, yr - 0.004, -0.066), (0.0160, yr + 0.006, 0.064), mat=st)
    mb.box((-0.0155, yr - 0.014, -0.064), (0.0155, yr - 0.004, 0.062), mat=rub)
    return c.finish(mb, name, bevel=0.0008, segments=1, parent=parent)
