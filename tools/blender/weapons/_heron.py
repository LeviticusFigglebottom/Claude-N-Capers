"""Shared dimensions and part builders for the Marrow & Kell Heron .308 bolt-action rifle (B4-04).

Private helper: imported by ``heron_308.py`` and ``heron_308_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the thumbhole stock's near-vertical grip.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 12.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))

BORE_Z = 0.078
REC_R = 0.0175
REC_Y0, REC_Y1 = 0.012, 0.240
RAIL_BASE_Z = BORE_Z + REC_R - 0.0015
RAIL_TOP_Z = RAIL_BASE_Z + 0.0062
SIGHT_RAIL_Y = 0.125

BARREL_R = 0.0120
BARREL_END_Y = 0.800
BRAKE_LEN = 0.055
MUZZLE_Y = BARREL_END_Y + BRAKE_LEN + 0.001

MAGWELL_Y0, MAGWELL_Y1 = 0.105, 0.165
MAGWELL_POS = (0.0, (MAGWELL_Y0 + MAGWELL_Y1) / 2, 0.022)
MAG_HW = 0.0125
MAG_HD = 0.0280

UNDER_Y = 0.465
UNDER_Z = 0.0360
STOCK_HW = 0.0240
STOCK_MOUNT = (0.0, -0.012, 0.074)
BUTT_CUT_Y = -0.160              # D-118: the swappable butt starts 1 cm behind the thumbhole

SCOPE_4X = dict(length=0.300, tube_r=0.0127, obj_r=0.0215, eye_r=0.0190, ring_h=0.042)
SCOPE_10X = dict(length=0.370, tube_r=0.0150, obj_r=0.0275, eye_r=0.0200, ring_h=0.048, parallax=True,
                 obj_len=0.085)


def build_scope(ctx, mats, ten: bool, parent=None, name="Scope"):
    spec = SCOPE_10X if ten else SCOPE_4X
    return c.build_scope(ctx, mats, parent=parent, name=name, ring_ys=(-0.050, 0.050), **spec)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    return c.build_box_mag(ctx, mats, 0.045 if extended else 0.010, MAG_HW, MAG_HD, curve=0.0, inside=0.032,
                           mat_name="polymer", round_r=0.0058, ribs=2 if extended else 0, parent=parent,
                           name=name)


def build_brake_suppressor(ctx, mats, parent=None, name="Suppressor"):
    """Large can that slips over the muzzle brake; origin = Muzzle (front of the brake)."""
    return c.build_can(ctx, mats, length=0.200, r=0.0225, overlap=BRAKE_LEN - 0.004, bore_r=0.0065,
                       parent=parent, name=name)
