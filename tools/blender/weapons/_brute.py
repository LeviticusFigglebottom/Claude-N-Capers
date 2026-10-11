"""Shared dimensions and part builders for the Tillman Brute 12 drum-fed automatic shotgun (B4-18).

Private helper: imported by ``brute_12.py`` and ``brute_12_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip.

Big slab-sided receiver in a straight line with an integral polymer buttstock (``StockMount`` at the
butt plate, no stock slot), carry handle with a top rail, vented barrel shroud, and a 20-shell drum
(``Magwell`` ahead of the trigger guard). Options: an eight-shell box or a 32-shell drum.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 15.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

REC_HW = 0.0240
REC_REAR_Y = -0.090
REC_FRONT_Y = 0.250
REC_BOTTOM_Z = 0.022
REC_TOP_Z = 0.098
BORE_Z = 0.062
BUTT_Y = -0.330
HANDLE_Y0, HANDLE_Y1 = -0.060, 0.170
HANDLE_TOP_Z = 0.128
RAIL_Y0, RAIL_Y1 = -0.050, 0.160
RAIL_TOP_Z = HANDLE_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.040

SHROUD_Y1 = 0.420
BARREL_END_Y = 0.455
MUZZLE_Y = BARREL_END_Y + 0.001

MAGWELL_POS = (0.0, 0.150, REC_BOTTOM_Z)
DRUM_W = 0.030                  # half width of the drum (along X)

STOCK_MOUNT = (0.0, BUTT_Y, 0.060)
UNDER_Y = 0.330
SIDE_Y = 0.330
REAR_IRON_Y = -0.040 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0140


def build_irons(ctx, mats, parent=None, name="IronSights"):
    """Carry-handle aperture + front post on the shroud; origin = SightRail."""
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, SHROUD_Y1 - 0.016 - SIGHT_RAIL_Y,
                                (BORE_Z + 0.024) - RAIL_TOP_Z, sight_h=IRON_AIM_DZ, parent=parent, name=name)


def build_drum(ctx, mats, big: bool, parent=None, name="Drum"):
    """Shell drum on a feed tower; origin = Magwell (receiver underside), +Z = insertion (up)."""
    r = 0.088 if big else 0.074
    hw = DRUM_W + (0.006 if big else 0.0)
    zc = -0.020 - r
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    st = mb.material(mats.matte())
    mb.box((-0.0170, -0.040, -0.026), (0.0170, 0.040, 0.020), mat=poly)                      # feed tower
    mb.cylinder(r, 2 * hw, segments=40, centre=(0.0, -0.004, zc), axis="X", mat=poly)
    for x in (-hw - 0.001, hw + 0.001):                                                         # side plates
        mb.cylinder(r * 0.82, 0.003, segments=32, centre=(x, -0.004, zc), axis="X", mat=st)
        mb.cylinder(0.014, 0.008, segments=20, centre=(x + (0.004 if x > 0 else -0.004), -0.004, zc), axis="X",
                    mat=st)                                                                     # winding key hub
    body = c.finish(mb, name, bevel=0.0015, segments=2, parent=parent)
    c.build_shell(ctx, mats, (0.0, 0.004, 0.014), name=name + "Shell", parent=body)
    return body


def build_box(ctx, mats, parent=None, name="BoxMagazine"):
    return c.build_box_mag(ctx, mats, 0.080, 0.0160, 0.0380, curve=0.0, inside=0.020, mat_name="polymer",
                           round_r=0.0100, ribs=1, parent=parent, name=name, base_drop=0.007)
