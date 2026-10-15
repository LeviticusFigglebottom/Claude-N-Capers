"""Shared dimensions and part builders for the Brannock Osprey Marksman semi-automatic sniper (B4-18).

Private helper: imported by ``osprey_762.py`` and ``osprey_762_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip.

Semi-automatic 7.62 marksman rifle: machined receiver with a full-length top rail, long free-float
handguard (lower rail section for the bipod), fluted barrel with a two-port brake, ten-round box
magazine, adjustable precision stock with a cheek riser (part of the model; no stock slot). The stock
sight is a fixed 4x scope (``SightRail/StockSight``).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 16.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

REC_HW = 0.0170
REC_REAR_Y = -0.085
REC_FRONT_Y = 0.175
REC_BOTTOM_Z = 0.030
REC_TOP_Z = 0.090
BORE_Z = 0.064
RAIL_Y0, RAIL_Y1 = -0.080, 0.300
RAIL_TOP_Z = REC_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.060

HG_Y0, HG_Y1 = 0.175, 0.480
HG_HW = 0.0250
BARREL_R = 0.0105
BARREL_END_Y = 0.660
BRAKE_LEN = 0.048
MUZZLE_Y = BARREL_END_Y + BRAKE_LEN + 0.001

MAG_HW = 0.0130
MAG_HD = 0.0300
MAGWELL_POS = (0.0, 0.098, REC_BOTTOM_Z - 0.008)

STOCK_MOUNT = (0.0, REC_REAR_Y, 0.062)
UNDER_Y = 0.400
SIDE_Y = 0.400

SCOPE_4X = dict(length=0.300, tube_r=0.0127, obj_r=0.0215, eye_r=0.0190, ring_h=0.040)
SCOPE_8X = dict(length=0.360, tube_r=0.0150, obj_r=0.0280, eye_r=0.0200, ring_h=0.048, parallax=True, obj_len=0.085)


def build_scope(ctx, mats, eight: bool, parent=None, name="Scope"):
    return c.build_scope(ctx, mats, parent=parent, name=name, ring_ys=(-0.050, 0.050),
                         **(SCOPE_8X if eight else SCOPE_4X))


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    below = 0.105 if extended else 0.052
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD * 0.62, curve=0.004 if not extended else 0.010,
                           inside=0.030, mat_name="polymer", round_r=0.0055, ribs=2 if extended else 1,
                           parent=parent, name=name)


def build_suppressor(ctx, mats, parent=None, name="Suppressor"):
    return c.build_can(ctx, mats, length=0.190, r=0.0215, overlap=BRAKE_LEN - 0.004, bore_r=0.0060, parent=parent,
                       name=name)
