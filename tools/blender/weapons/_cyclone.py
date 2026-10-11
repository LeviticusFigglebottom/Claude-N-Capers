"""Shared dimensions and part builders for the Brannock Cyclone Rotary six-barrel gun (B4-18).

Private helper: imported by ``cyclone_rotary.py`` and ``cyclone_rotary_mods.py``. Axes and pivot rules:
see ``_common.py``. Origin = firing-hand pivot on the pistol grip under the housing.

Motor housing with a carry handle and top rail, a ``Rotor`` (B4-18 animated part: empty on the cluster
axis; ENV A spins it about local Z in Godot = the bore axis) carrying ``BarrelMount`` and the six-barrel
cluster (``StockBarrel``), a fixed front handle under the housing nose and a belt box hanging on the left
(``Magwell``) with a feed chute. ``Muzzle`` = the cluster axis at the barrel ends.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 14.0
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

HOUSE_HW = 0.0480
HOUSE_Y0, HOUSE_Y1 = -0.130, 0.120
HOUSE_Z0, HOUSE_Z1 = 0.026, 0.134
AXIS_Z = 0.080
ROTOR = (0.0, HOUSE_Y1 + 0.004, AXIS_Z)
CLUSTER_R = 0.0220
BARREL_R = 0.0080
LONG_LEN = 0.420
SHORT_LEN = 0.270
MUZZLE_Y = ROTOR[1] + LONG_LEN + 0.001

HANDLE_Y0, HANDLE_Y1 = -0.080, 0.090
HANDLE_TOP_Z = HOUSE_Z1 + 0.034
RAIL_Y0, RAIL_Y1 = -0.070, 0.080
RAIL_TOP_Z = HANDLE_TOP_Z + 0.0062
SIGHT_RAIL_Y = 0.000
REAR_IRON_Y = -0.060 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0150

MAGWELL_POS = (-HOUSE_HW, 0.000, HOUSE_Z0 + 0.010)
STOCK_MOUNT = (0.0, HOUSE_Y0, AXIS_Z)
UNDER = (0.0, 0.090, HOUSE_Z0)


def build_irons(ctx, mats, parent=None, name="IronSights"):
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, RAIL_Y1 - 0.012 - SIGHT_RAIL_Y, 0.0, sight_h=IRON_AIM_DZ,
                                parent=parent, name=name)


def build_cluster(ctx, mats, length: float, muzzle: bool = False, parent=None, name="BarrelCluster"):
    """Six barrels around the axis in the BarrelMount frame (origin on the axis, +Y forward)."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    for i in range(6):
        a = 2 * math.pi * i / 6 + math.pi / 6
        x, z = math.cos(a) * CLUSTER_R, math.sin(a) * CLUSTER_R
        mb.prism(c.circle(BARREL_R, 16, x, z), holes=[list(reversed(c.circle(0.0040, 12, x, z)))], axis="Y", start=0.0,
                 end=length, mat=st)
    for y in (0.010, length * 0.55, length - 0.020):                                         # clamps
        mb.prism(c.circle(CLUSTER_R + BARREL_R + 0.003, 32), holes=[list(reversed(c.circle(0.012, 16)))], axis="Y",
                 start=y, end=y + 0.012, mat=st)
    body = c.finish(mb, name, bevel=0.0004, parent=parent)
    if muzzle:
        ctx.marker("Muzzle", (0.0, length + 0.001, 0.0), parent=body)
    return body


def build_box(ctx, mats, big: bool, parent=None, name="AmmoBox"):
    """Belt box hanging on the housing's left side; origin = Magwell, +Z = up into the feed."""
    below = 0.150 if big else 0.115
    w = 0.060 if big else 0.050
    hd = 0.070
    xo = -0.012 - w
    mb = ctx.builder()
    ol = mb.material(mats.olive())
    st = mb.material(mats.steel())
    mb.box((xo - w, -hd, -below), (xo + w, hd, -0.030), mat=ol)
    mb.box((xo - w - 0.0015, -hd - 0.0015, -0.044), (xo + w + 0.0015, hd + 0.0015, -0.030), mat=ol)
    mb.box((-0.016, -0.020, -0.034), (0.004, 0.020, 0.004), mat=st)                          # mount shoe
    for i in range(2):
        z = -below * (i + 1) / 3
        mb.box((xo - w - 0.001, -hd + 0.014, z - 0.004), (xo + w + 0.001, hd - 0.014, z + 0.004), mat=ol)
    body = c.finish(mb, name, bevel=0.0018, segments=1, parent=parent)
    ch = ctx.builder()
    cm = ch.material(mats.polymer())
    ch.box((xo - 0.016, -0.018, -0.032), (-0.010, 0.018, -0.020), mat=cm)                       # chute
    br = ch.material(mats.brass())
    n = 7
    for i in range(n):
        x = xo + (-0.012 - xo) * i / (n - 1)
        ch.cylinder(0.0050, 0.034, segments=10, centre=(x, 0.0, -0.016), axis="Y", mat=br)
    c.finish(ch, name + "Belt", parent=body)
    return body
