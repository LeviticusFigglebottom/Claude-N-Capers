"""Shared dimensions and part builders for the Graff-Lindqvist Rotor Saw portable cut-off saw (B4-18).

Private helper: imported by ``rotor_saw.py`` and ``rotor_saw_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the rear (pistol) handle.

Tan motor housing with an air-filter cover and an exhaust on the right, rear pistol handle with a
throttle trigger, a loop front handle over the housing (``Underbarrel/StockForegrip``), an arm forward to
a 30 cm abrasive blade under a half guard. Animated part (B4-18): ``Blade``, an empty on the spindle axis
(local X); ENV A spins it. ``Magwell`` sits on the Blade (insertion axis = the spindle), so whatever blade
is fitted (``StockMagazine`` or a blade mod) spins with it. ``Muzzle`` = the cutting edge at the front.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 10.0
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

HOUSE_HW = 0.0500
HOUSE_Y0, HOUSE_Y1 = 0.050, 0.240
HOUSE_Z0, HOUSE_Z1 = -0.070, 0.082
SPINDLE = (0.0, 0.420, -0.010)
BLADE_R = 0.150
GUARD_R = 0.162
MUZZLE_Y = SPINDLE[1] + BLADE_R + 0.002
SIGHT_RAIL_Y = 0.110
RAIL_TOP_Z = HOUSE_Z1 + 0.002
UNDER = (0.0, 0.205, HOUSE_Z1)
STOCK_MOUNT = (0.0, -0.034, 0.030)
AIM_DZ = 0.0120


def build_notch(ctx, mats, parent=None, name="GuideNotch"):
    """V-notch on the housing top + a painted guide line on the guard; origin = SightRail."""
    mb = ctx.builder()
    st = mb.material(mats.matte())
    nh = 0.0020
    prof = [(-0.0120, 0.0), (0.0120, 0.0), (0.0120, AIM_DZ + 0.004), (nh, AIM_DZ + 0.004), (0.0, AIM_DZ),
            (-nh, AIM_DZ + 0.004), (-0.0120, AIM_DZ + 0.004)]
    mb.prism(prof, axis="Y", start=-0.004, end=0.004, mat=st)
    body = c.finish(mb, name, bevel=0.0003, parent=parent)
    ln = ctx.builder()
    gy = SPINDLE[1] - SIGHT_RAIL_Y
    gz = SPINDLE[2] - RAIL_TOP_Z
    ln.box((-0.0015, gy - 0.060, gz + GUARD_R - 0.004), (0.0015, gy + 0.020, gz + GUARD_R + 0.0015),
           mat=ln.material(mats.dot()))
    c.finish(ln, name + "Line", parent=body)
    return body, AIM_DZ


def build_blade(ctx, mats, kind: str, parent=None, name="StandardBlade"):
    """Blade disc in the Magwell frame (spindle = local Z; the disc lies in local XY)."""
    mb = ctx.builder()
    r = BLADE_R - (0.004 if kind == "carbide" else 0.0)
    disc = mb.material(mats.polymer() if kind == "durable" else mats.ctx.material(
        "brushed_steel", "#C3C5C8", roughness=0.35, metallic=1.0))
    th = 0.0045 if kind == "durable" else 0.0025
    outer = c.circle(r, 64)
    hole = list(reversed(c.circle(0.0125, 16)))
    mb.prism(outer, holes=[hole], axis="Z", start=-th / 2, end=th / 2, mat=disc)
    st = mb.material(mats.steel())
    if kind == "carbide":
        for i in range(36):
            a = 2 * math.pi * i / 36
            ca, sa = math.cos(a), math.sin(a)
            p = [(ca * (r - 0.004) - sa * 0.003, sa * (r - 0.004) + ca * 0.003),
                 (ca * (r + 0.006) - sa * 0.001, sa * (r + 0.006) + ca * 0.001),
                 (ca * (r + 0.004) + sa * 0.004, sa * (r + 0.004) - ca * 0.004),
                 (ca * (r - 0.004) + sa * 0.003, sa * (r - 0.004) - ca * 0.003)]
            mb.prism(p, axis="Z", start=-0.0022, end=0.0022, mat=st)
    else:
        for i in range(24):                                                              # segment slots
            a = 2 * math.pi * i / 24
            mb.box((math.cos(a) * (r - 0.010) - 0.0012, math.sin(a) * (r - 0.010) - 0.0012, th / 2 - 0.0002),
                   (math.cos(a) * (r - 0.010) + 0.0012, math.sin(a) * (r - 0.010) + 0.0012, th / 2 + 0.0004),
                   mat=st)
    mb.cylinder(0.030, th + 0.004, segments=24, centre=(0.0, 0.0, 0.0), axis="Z", mat=st)          # flange
    mb.cylinder(0.010, th + 0.010, segments=6, centre=(0.0, 0.0, 0.0), axis="Z", mat=st)           # nut
    return c.finish(mb, name, bevel=0.0, parent=parent)


def build_front_handle(ctx, mats, wide: bool, parent=None, name="FrontHandle"):
    """Loop handle over the housing front; origin = Underbarrel (housing top front), loop in the XZ plane."""
    mb = ctx.builder()
    m = mb.material(mats.polymer())
    hw = HOUSE_HW + (0.022 if wide else 0.010)
    top = 0.050 if wide else 0.040
    low = -0.090
    pts = [(-hw, low), (-hw, top - 0.012), (-hw + 0.012, top), (hw - 0.012, top), (hw, top - 0.012), (hw, low)]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        c.rod(mb, (x0, 0.0, z0), (x1, 0.0, z1), 0.0110 if not wide else 0.0125, m, segments=12)
    rub = mb.material(mats.rubber())
    mb.cylinder(0.0135 if not wide else 0.0150, 2 * hw - 0.040, segments=16, centre=(0.0, 0.0, top), axis="X", mat=rub)
    for x in (-hw, hw):
        mb.box((x - 0.008, -0.010, low - 0.006), (x + 0.008, 0.010, low + 0.006), mat=m)              # mounts
    return c.finish(mb, name, bevel=0.0, parent=parent)
