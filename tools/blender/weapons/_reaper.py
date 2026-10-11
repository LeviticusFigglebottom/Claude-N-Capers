"""Shared dimensions and part builders for the Marrow & Kell Reaper Double shotgun (B4-18).

Private helper: imported by ``reaper_db.py`` and ``reaper_db_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the walnut wrist (pistol-grip stock).

Side-by-side 12-gauge break action: a steel action block with a top tang, and a ``Breech`` node whose
origin is the hinge pin at the front-bottom of the action (B4-18 animated part: opening = a negative
rotation about local X, about 40 degrees, so the muzzles drop). The barrels (``BarrelMount/StockBarrel``),
the walnut forend, ``Muzzle``, ``Magwell`` (at the chamber mouths, insertion axis = the bores) and the two
loaded shells (``StockMagazine``) ride on the Breech. Buttstock = ``StockMount/StockStock``.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 24.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.026
GRIP_BOTTOM_Z = -0.062

ACT_HW = 0.0235
ACT_REAR_Y = -0.022
ACT_FRONT_Y = 0.070
ACT_BOTTOM_Z = 0.020
ACT_TOP_Z = 0.074
BORE_Z = 0.054
BARREL_R = 0.0118
BARREL_X = 0.0119
HINGE = (0.0, ACT_FRONT_Y - 0.004, ACT_BOTTOM_Z + 0.008)      # Breech origin (Blender)
BARREL_END_Y = 0.680
SHORT_END_Y = 0.330
MUZZLE_Y = BARREL_END_Y + 0.001
FOREND_Y0, FOREND_Y1 = 0.090, 0.300
SIGHT_RAIL_Y = -0.010
RAIL_TOP_Z = ACT_TOP_Z + 0.002
STOCK_MOUNT = (0.0, -0.042, 0.040)
BEAD_DZ = 0.0100                                        # aim line above the rail (tang notch / bead)


def hinge_local(p):
    """World (Blender) point -> Breech-local."""
    return (p[0] - HINGE[0], p[1] - HINGE[1], p[2] - HINGE[2])


def build_barrels(ctx, mats, end_y: float, muzzle: bool = False, parent=None, name="Barrels"):
    """Side-by-side barrels + top rib + bead in the BarrelMount frame (origin = barrel root on the axis between
    the bores, +Y forward). ``muzzle`` adds an own ``Muzzle`` at the end (the sawn-off mod; the base model keeps
    its Muzzle on the Breech)."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    length = end_y - ACT_FRONT_Y
    for x in (-BARREL_X, BARREL_X):
        outer = c.circle(BARREL_R, 28, x, 0.0)
        hole = list(reversed(c.circle(0.0092, 24, x, 0.0)))
        mb.prism(outer, holes=[hole], axis="Y", start=0.0, end=length, mat=st)
    mb.box((-0.0045, 0.0, 0.0090), (0.0045, length - 0.002, BARREL_R + 0.0030), mat=st)          # top rib
    mb.box((-0.0040, 0.0, -BARREL_R - 0.0010), (0.0040, length - 0.010, -0.0080), mat=st)       # bottom rib
    mb.box((-BARREL_X - BARREL_R + 0.002, 0.0, -0.012), (BARREL_X + BARREL_R - 0.002, 0.040, 0.010), mat=st)  # lumps
    body = c.finish(mb, name, bevel=0.0006, segments=1, parent=parent)
    bd = ctx.builder()
    bd.cylinder(0.0020, 0.004, segments=12, centre=(0.0, length - 0.008, BARREL_R + 0.0045), axis="Z",
                mat=bd.material(mats.brass()))
    c.finish(bd, name + "Bead", parent=body)
    if muzzle:
        ctx.marker("Muzzle", (0.0, length + 0.001, 0.0), parent=body)
    return body


def build_shells(ctx, mats, parent=None, name="Shells"):
    """Two shells in the chambers; Magwell frame (+Z = into the chambers along the bores)."""
    holder = ctx.marker(name, (0.0, 0.0, 0.0), parent=parent)
    for i, x in enumerate((-BARREL_X, BARREL_X)):
        c.build_shell(ctx, mats, (x, 0.0, 0.030), axis_y=False, name=f"{name}{'LR'[i]}Shell", parent=holder)
    return holder


def build_tang_sight(ctx, mats, fiber: bool, parent=None, name="TangSight"):
    """Notched rear on the top tang; origin = SightRail. The fibre variant adds a taller notch and a glowing
    front bead clamped on the rib far forward."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    h = BEAD_DZ + (0.004 if fiber else 0.0)
    nh = 0.0016
    prof = [(-0.0070, 0.0), (0.0070, 0.0), (0.0060, h + 0.003), (nh, h + 0.003), (nh, h), (-nh, h), (-nh, h + 0.003),
            (-0.0060, h + 0.003)]
    mb.prism(prof, axis="Y", start=-0.006, end=0.006, mat=st)
    body = c.finish(mb, name, bevel=0.0004, parent=parent)
    if fiber:
        fb = ctx.builder()
        y = BARREL_END_Y - 0.030 - SIGHT_RAIL_Y
        zr = (BORE_Z + BARREL_R + 0.003) - RAIL_TOP_Z
        fb.box((-0.0040, y - 0.010, zr), (0.0040, y + 0.010, zr + 0.004), mat=fb.material(mats.steel()))
        fb.cylinder(0.0015, 0.012, segments=12, centre=(0.0, y, zr + 0.0055), axis="Y", mat=fb.material(mats.reticle()))
        c.finish(fb, name + "Front", bevel=0.0003, parent=body)
    return body, h


def build_stock(ctx, mats, sawn: bool, parent=None, name="Stock"):
    """Walnut buttstock from the wrist; origin = StockMount, extends along -Y. Sawn = a short rounded stub."""
    if sawn:
        prof = [(0.004, 0.026), (0.004, -0.040), (-0.020, -0.050), (-0.050, -0.040), (-0.060, -0.010),
                (-0.050, 0.020), (-0.020, 0.028)]
        return c.build_butt_stock(ctx, mats, "wood", prof, 0.0170, name=name, parent=parent)
    prof = [(0.004, 0.026), (0.004, -0.040), (-0.004, -0.090), (-0.024, -0.104), (-0.050, -0.080),
            (-0.280, -0.108), (-0.292, -0.108),
            (-0.292, 0.020), (-0.270, 0.024), (-0.040, 0.026)]
    return c.build_butt_stock(ctx, mats, "wood", prof, 0.0200, name=name, parent=parent, pad_y=-0.292,
                              pad_z=(-0.108, 0.020), taper=lambda y, z: 0.82 if y > -0.06 else 1.0)
