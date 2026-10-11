"""Shared dimensions and part builders for the Marrow & Kell Shrike lever-action rifle (B4-18).

Private helper: imported by ``shrike_44.py`` and ``shrike_44_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the walnut wrist.

Tube-fed lever action in a heavy pistol calibre: blued receiver with a side loading gate, octagonal
barrel (``BarrelMount/StockBarrel``), full-length tube magazine under it (``Magwell`` at the receiver's
loading port, D-045 shell-by-shell), walnut forend and straight stock. Animated part (B4-18): ``Lever``,
origin = the lever pivot at the receiver's front-bottom; ENV A swings it about local X (a positive ~50 degrees)
so the finger loop drops away from the wrist, then back.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 34.0
GRIP_TOP_Z = 0.022
GRIP_BOTTOM_Z = -0.034

REC_HW = 0.0165
REC_REAR_Y = -0.012
REC_FRONT_Y = 0.150
REC_BOTTOM_Z = 0.012
REC_TOP_Z = 0.072
BORE_Z = 0.052
BARREL_R = 0.0110
BARREL_END_Y = 0.560
CARBINE_END_Y = 0.485
MUZZLE_Y = BARREL_END_Y + 0.001
TUBE_R = 0.0085
TUBE_Z = BORE_Z - BARREL_R - TUBE_R + 0.001
TUBE_END_Y = 0.445
FOREND_Y1 = 0.330

LEVER_PIVOT = (0.0, 0.124, REC_BOTTOM_Z - 0.002)
LOOP_C = (0.032, -0.030)
MAGWELL_POS = (0.0, 0.140, REC_BOTTOM_Z)

SIGHT_RAIL_Y = 0.200
RAIL_TOP_Z = BORE_Z + BARREL_R             # barrel flat top
REAR_IRON_Y = 0.270 - SIGHT_RAIL_Y
FRONT_IRON_Y = 0.465 - SIGHT_RAIL_Y
AIM_DZ = 0.0110
STOCK_MOUNT = (0.0, -0.034, 0.030)


def _blade(mb, mat, y, h):
    mb.box((-0.0040, y - 0.008, -0.001), (0.0040, y + 0.008, 0.003), mat=mat)
    mb.prism([(y - 0.006, 0.002), (y + 0.006, 0.002), (y + 0.003, h), (y - 0.001, h)], axis="X", start=-0.0010,
             end=0.0010, mat=mat)


def build_irons(ctx, mats, parent=None, name="Buckhorn"):
    """Buckhorn rear on the barrel + front blade; origin = SightRail (barrel top). Returns (body, aim_z)."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    y = REAR_IRON_Y
    nh = 0.0018
    prof = [(-0.0100, 0.0), (0.0100, 0.0), (0.0110, AIM_DZ + 0.006), (0.0060, AIM_DZ + 0.002), (nh, AIM_DZ + 0.002),
            (nh, AIM_DZ), (-nh, AIM_DZ), (-nh, AIM_DZ + 0.002), (-0.0060, AIM_DZ + 0.002), (-0.0110, AIM_DZ + 0.006)]
    mb.prism(prof, axis="Y", start=y - 0.0020, end=y + 0.0020, mat=st)
    mb.box((-0.0050, y - 0.008, -0.001), (0.0050, y + 0.008, 0.002), mat=st)
    _blade(mb, st, FRONT_IRON_Y, AIM_DZ)
    return c.finish(mb, name, bevel=0.0003, parent=parent), AIM_DZ


def build_peep(ctx, mats, parent=None, name="TangPeep"):
    """Folding aperture on the receiver tang + front blade; origin = SightRail. Returns (body, aim_z)."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    y = REC_REAR_Y + 0.004 - SIGHT_RAIL_Y
    z0 = REC_TOP_Z - RAIL_TOP_Z
    aim = AIM_DZ + 0.004
    mb.box((-0.0050, y - 0.020, z0), (0.0050, y + 0.006, z0 + 0.003), mat=st)
    mb.box((-0.0018, y - 0.002, z0), (0.0018, y + 0.002, aim - 0.004), mat=st)
    outer = c.circle(0.0055, 20, 0.0, aim)
    hole = list(reversed(c.circle(0.0016, 12, 0.0, aim)))
    mb.prism(outer, holes=[hole], axis="Y", start=y - 0.0015, end=y + 0.0015, mat=st)
    _blade(mb, st, FRONT_IRON_Y, aim)
    return c.finish(mb, name, bevel=0.0003, parent=parent), aim


def build_scope(ctx, mats, parent=None, name="ScoutScope"):
    """Long-eye-relief scope on a barrel base; origin = SightRail."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.box((-0.0080, -0.050, -0.001), (0.0080, 0.070, 0.004), mat=st)                          # scout base
    base = c.finish(mb, name + "Base", bevel=0.0004, parent=parent)
    return c.build_scope(ctx, mats, length=0.230, tube_r=0.0115, obj_r=0.0150, eye_r=0.0170, ring_h=0.028,
                         parent=base, name=name, ring_ys=(-0.035, 0.045), obj_len=0.040, eye_len=0.060)


def build_barrel(ctx, mats, end_y: float, muzzle: bool = False, parent=None, name="Barrel"):
    """Octagonal barrel in the BarrelMount frame (origin = barrel root on the bore, +Y forward)."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    length = end_y - REC_FRONT_Y
    octa = [(BARREL_R * math.cos(math.pi / 8 + i * math.pi / 4), BARREL_R * math.sin(math.pi / 8 + i * math.pi / 4))
            for i in range(8)]
    hole = list(reversed(c.circle(0.0055, 16)))
    mb.prism(octa, holes=[hole], axis="Y", start=0.0, end=length, mat=st)
    body = c.finish(mb, name, bevel=0.0004, parent=parent)
    if muzzle:
        ctx.marker("Muzzle", (0.0, length + 0.001, 0.0), parent=body)
    return body


def build_tube(ctx, mats, parent=None, name="MagTube"):
    """Tube magazine + barrel band in the Magwell frame (+Z = up into the loading port)."""
    oy, oz = MAGWELL_POS[1], MAGWELL_POS[2]
    z = TUBE_Z - oz
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(TUBE_R, TUBE_END_Y - REC_FRONT_Y, segments=24, centre=(0.0, (TUBE_END_Y + REC_FRONT_Y) / 2 - oy, z),
                axis="Y", mat=st)
    by = TUBE_END_Y - 0.008 - oy
    mb.box((-0.0095, by - 0.006, z - TUBE_R - 0.001), (0.0095, by + 0.006, BORE_Z + BARREL_R + 0.001 - oz), mat=st)
    mb.box((-0.0070, -0.020, 0.002), (0.0070, 0.010, 0.008), mat=st)                              # follower
    body = c.finish(mb, name, bevel=0.0006, segments=1, parent=parent)
    rd = ctx.builder()
    br = rd.material(mats.brass())
    rd.cylinder(0.0060, 0.040, segments=16, centre=(0.0, 0.000, 0.012), axis="Y", mat=br)
    c.finish(rd, name + "Round", parent=body)
    return body


def lever_profile():
    """Side profile (y, z) of the lever relative to the pivot, plus the finger-loop hole."""
    px, pz = LEVER_PIVOT[1], LEVER_PIVOT[2]
    cy, cz = LOOP_C
    outer = [(0.008, 0.004), (0.008, -0.006)]
    ring = [(cy + 0.027 * math.cos(a), cz + 0.024 * math.sin(a)) for a in
            [math.radians(d) for d in range(60, -240, -20)]]
    outer += [(y - px, z - pz) for y, z in ring]
    outer += [(0.040 - px, REC_BOTTOM_Z - 0.006 - pz), (0.110 - px, REC_BOTTOM_Z - 0.004 - pz)]
    hole = [(cy + 0.018 * math.cos(math.radians(d)) - px, cz + 0.015 * math.sin(math.radians(d)) - pz)
            for d in range(0, 360, 30)]
    return outer, hole
