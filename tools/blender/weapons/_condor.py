"""Shared dimensions and part builders for the Marrow & Kell Condor .50 anti-materiel rifle (B4-12).

Private helper: imported by ``condor_50.py`` and ``condor_50_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the chassis pistol grip.

Bolt-action .50: black aluminium chassis with a long octagonal handguard, skeleton stock with a cheek
riser, round steel receiver, heavy barrel with a two-chamber muzzle brake, single-stack five-round box
magazine. The ``Bolt`` object's origin sits ON the bore axis at the bolt's rear (ENV A lifts it 62 deg
about local Z, then slides it 0.075 m along +Z; visual_slots.md, characters.md v1.4).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 16.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))

BORE_Z = 0.080
REC_R = 0.0225
REC_Y0, REC_Y1 = 0.005, 0.270
RAIL_BASE_Z = BORE_Z + REC_R - 0.0015
RAIL_TOP_Z = RAIL_BASE_Z + 0.0062
RAIL_Y0, RAIL_Y1 = -0.010, 0.330
SIGHT_RAIL_Y = 0.150

CHASSIS_HW = 0.0260
CHASSIS_TOP_Z = BORE_Z - 0.004
CHASSIS_BOTTOM_Z = 0.026
HG_Y0, HG_Y1 = REC_Y1, 0.620
HG_R = 0.0300

BARREL_R = 0.0165
BARREL_END_Y = 0.930
BRAKE_LEN = 0.085
MUZZLE_Y = BARREL_END_Y + BRAKE_LEN + 0.001

BOLT_PIVOT = (0.0, REC_Y0 + 0.020, BORE_Z)

MAGWELL_Y0, MAGWELL_Y1 = 0.110, 0.200
MAGWELL_POS = (0.0, (MAGWELL_Y0 + MAGWELL_Y1) / 2, CHASSIS_BOTTOM_Z - 0.002)
MAG_HW = 0.0160
MAG_HD = 0.0440
STOCK_MOUNT = (0.0, -0.040, BORE_Z - 0.006)

UNDER_Y = 0.560
UNDER_Z = BORE_Z - HG_R * 0.92
SIDE_Y = 0.560

SCOPE_6X = dict(length=0.330, tube_r=0.0150, obj_r=0.0270, eye_r=0.0205, ring_h=0.050, obj_len=0.080)
SCOPE_12X = dict(length=0.410, tube_r=0.0170, obj_r=0.0320, eye_r=0.0215, ring_h=0.058, parallax=True,
                 obj_len=0.095)


def build_scope(ctx, mats, high: bool, parent=None, name="Scope"):
    spec = SCOPE_12X if high else SCOPE_6X
    return c.build_scope(ctx, mats, parent=parent, name=name, ring_ys=(-0.060, 0.060), **spec)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    return c.build_box_mag(ctx, mats, 0.075 if extended else 0.030, MAG_HW, MAG_HD, curve=0.0, inside=0.030,
                           mat_name="steel", round_r=0.0075, ribs=2 if extended else 1, parent=parent, name=name,
                           base_drop=0.008)


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    """Massive .50 can over the brake; origin = Muzzle (front of the brake)."""
    return c.build_can(ctx, mats, length=0.200, r=0.0300, overlap=BRAKE_LEN - 0.006, bore_r=0.0085,
                       parent=parent, name=name, rings=6)
