"""Shared dimensions and part builders for the Tillman Furnace flamethrower (B4-18).

Private helper: imported by ``furnace_ft.py`` and ``furnace_ft_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip.

Steel valve housing with a pistol grip and a short stock, a long nozzle tube inside a perforated heat
shield, a front handle, a horizontal fuel tank under the shield (``Magwell``; the tank is the magazine),
and a ``PilotLight`` mesh node under the nozzle tip (B4-18: the igniter glow; ENV C/A hang the flame FX
on ``Muzzle``). Nozzle mods (BARREL_EXT) slip over the tip and carry their own ``Muzzle``.
"""

from __future__ import annotations

import math

import bmesh

import _common as c

GRIP_ANGLE_DEG = 18.0
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

BODY_HW = 0.0260
BODY_REAR_Y = -0.060
BODY_FRONT_Y = 0.150
BODY_BOTTOM_Z = 0.024
BODY_TOP_Z = 0.090
BORE_Z = 0.062
SHIELD_R = 0.0230
SHIELD_Y1 = 0.470
NOZZLE_R = 0.0120
NOZZLE_Y1 = 0.540
MUZZLE_Y = NOZZLE_Y1 + 0.001

MAGWELL_POS = (0.0, 0.200, BORE_Z - SHIELD_R - 0.006)
SIGHT_RAIL_Y = 0.030
RAIL_TOP_Z = BODY_TOP_Z + 0.002
STOCK_MOUNT = (0.0, BODY_REAR_Y, 0.060)
HANDLE_Y = 0.380
AIM_DZ = 0.0140


def build_post_sight(ctx, mats, parent=None, name="PostSight"):
    """Notch rear on the housing + post on the shield front; origin = SightRail. Returns the aim height."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    nh = 0.0018
    prof = [(-0.0090, 0.0), (0.0090, 0.0), (0.0090, AIM_DZ + 0.004), (nh, AIM_DZ + 0.004), (nh, AIM_DZ),
            (-nh, AIM_DZ), (-nh, AIM_DZ + 0.004), (-0.0090, AIM_DZ + 0.004)]
    mb.prism(prof, axis="Y", start=-0.004, end=0.004, mat=st)
    fy = SHIELD_Y1 - 0.020 - SIGHT_RAIL_Y
    fz = (BORE_Z + SHIELD_R) - RAIL_TOP_Z
    mb.box((-0.0050, fy - 0.008, fz - 0.001), (0.0050, fy + 0.008, fz + 0.004), mat=st)
    mb.box((-0.0015, fy - 0.002, fz + 0.004), (0.0015, fy + 0.002, AIM_DZ), mat=st)
    return c.finish(mb, name, bevel=0.0003, parent=parent), AIM_DZ


def build_tank(ctx, mats, big: bool, parent=None, name="FuelTank"):
    """Horizontal fuel tank on a saddle mount; origin = Magwell (+Z up into the mount)."""
    r = 0.046 if big else 0.038
    half = 0.130 if big else 0.105
    zc = -0.012 - r
    mb = ctx.builder()
    tk = mb.material(mats.ctx.material("brushed_steel", "#C3C5C8", roughness=0.35, metallic=1.0))
    st = mb.material(mats.matte())
    mb.cylinder(r, 2 * half - 0.020, segments=36, centre=(0.0, 0.0, zc), axis="Y", mat=tk)
    for sy in (-1.0, 1.0):
        mb.cylinder(r - 0.006, 0.010, segments=36, centre=(0.0, sy * (half - 0.005), zc), axis="Y", mat=tk)
        mb.box((-0.014, sy * 0.050 - 0.006, zc + r - 0.004), (0.014, sy * 0.050 + 0.006, 0.0), mat=st)   # saddle
        c.ring_y(mb, r + 0.002, r - 0.0002, sy * 0.050 - 0.005, sy * 0.050 + 0.005, zc, st, segments=36)
    mb.cylinder(0.0060, 0.020, segments=14, centre=(0.0, -half + 0.012, zc + r * 0.6), axis="Y", mat=st)  # valve
    body = c.finish(mb, name, bevel=0.0010, segments=1, parent=parent)
    gg = ctx.builder()
    gg.cylinder(0.0110, 0.006, segments=20, centre=(r + 0.002, 0.020, zc), axis="X", mat=gg.material(mats.matte()))
    gg.cylinder(0.0090, 0.001, segments=20, centre=(r + 0.0052, 0.020, zc), axis="X", mat=gg.material(mats.dot()))
    c.finish(gg, name + "Gauge", parent=body)
    return body


def build_nozzle(ctx, mats, wide: bool, parent=None, name="Nozzle"):
    """Nozzle extension over the tip; origin = Muzzle. Adds its own ``Muzzle``."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    if wide:
        length = 0.045
        c.ring_y(mb, NOZZLE_R + 0.004, NOZZLE_R + 0.0002, -0.020, 0.000, 0.0, st, segments=28)
        n = 28
        bm = mb.bm
        a = [bm.verts.new((math.cos(2 * math.pi * i / n) * (NOZZLE_R + 0.002), 0.0,
                           math.sin(2 * math.pi * i / n) * (NOZZLE_R + 0.002))) for i in range(n)]
        b = [bm.verts.new((math.cos(2 * math.pi * i / n) * 0.026, length, math.sin(2 * math.pi * i / n) * 0.020))
             for i in range(n)]
        faces = []
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.material_index = st
            faces.append(f)
        bmesh.ops.recalc_face_normals(bm, faces=faces)
    else:
        length = 0.110
        c.ring_y(mb, NOZZLE_R + 0.004, NOZZLE_R + 0.0002, -0.020, 0.000, 0.0, st, segments=28)
        c.ring_y(mb, 0.0090, 0.0060, 0.0, length, 0.0, st, segments=24)
        mb.cylinder(0.0105, 0.008, segments=24, centre=(0.0, length - 0.004, 0.0), axis="Y", mat=st)
    body = c.finish(mb, name, bevel=0.0004, parent=parent)
    ctx.marker("Muzzle", (0.0, length + 0.001, 0.0), parent=body)
    return body
