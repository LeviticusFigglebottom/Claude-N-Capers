"""Shared dimensions and part builders for the Marrow & Kell Marshal .357 revolver (B4-12).

Private helper: imported by ``marshal_357.py`` and ``marshal_357_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot (grip centre plane, mid depth, 20 mm below the grip top).

Six-shot double-action revolver in bare stainless steel with walnut grips.

Animated parts (proposed visual_slots addition, B4-12):
* ``Crane``: pivot ON the crane hinge axis (parallel to the bore, below-left of the cylinder). The
  cylinder swings out to the LEFT by a positive rotation about local Z (Godot), open = 80 deg.
* ``Crane/Cylinder``: pivot on the cylinder axis at the rear face; rotates about local Z, 60 deg per shot.
* ``Crane/Cylinder/Magwell``: the speedloader point at the cylinder's rear face, local +Z = insertion
  axis (forward, into the chambers); ``StockMagazine`` = the six cartridges.
The barrel (with its underlug and front sight) is the stock part ``BarrelMount/StockBarrel``; the walnut
grip is ``GripMount/StockGrip``.
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 22.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.020
GRIP_BOTTOM_Z = -0.068
GRIP_HALF_DEPTH = 0.0175
GRIP_HALF_WIDTH = 0.0160

FRAME_HW = 0.0095
FRAME_REAR_Y = -0.036
FRAME_FRONT_Y = 0.062
FRAME_BOTTOM_Z = 0.018
TOP_STRAP_Z0, TOP_STRAP_Z1 = 0.069, 0.078
BORE_Z = 0.060

CYL_R = 0.0205
CYL_CHAMBER_R = 0.0122
CYL_Z = BORE_Z - CYL_CHAMBER_R
CYL_Y0, CYL_Y1 = 0.010, 0.054
CRANE_PIVOT = (-0.0060, CYL_Y0, CYL_Z - 0.0190)      # Blender coords (x, y, z)
CRANE_OPEN_DEG = 80.0

BARREL_STD_END = 0.165                              # 4 in
BARREL_LONG_END = 0.215                             # 6 in
BARREL_SNUB_END = 0.110                             # 2.5 in
BARREL_R = 0.0085
LUG_DZ = 0.016                                      # underlug depth below the bore

SIGHT_RAIL_Y = -0.008                               # rear sight on the top strap
SIGHT_DZ = 0.0040
STOCK_MOUNT = (0.0, -0.040, 0.010)


def barrel_end(kind: str) -> float:
    return {"std": BARREL_STD_END, "long": BARREL_LONG_END, "snub": BARREL_SNUB_END}[kind]


def build_rear_sight(ctx, mats, parent=None, name="RearSight"):
    """Adjustable square-notch rear sight; origin = top-strap top centre."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    nh = 0.0016
    prof = [(-0.0075, 0.0), (0.0075, 0.0), (0.0075, 0.0068), (nh, 0.0068), (nh, SIGHT_DZ), (-nh, SIGHT_DZ),
            (-nh, 0.0068), (-0.0075, 0.0068)]
    mb.prism(prof, axis="Y", start=-0.0080, end=0.0040, mat=st)
    mb.cylinder(0.0018, 0.003, segments=10, centre=(0.0080, -0.002, 0.004), axis="X", mat=st)   # windage screw
    return c.finish(mb, name, bevel=0.0004, parent=parent)


def build_barrel(ctx, mats, kind: str, parent=None, name="Barrel", muzzle: bool = True):
    """Barrel with a full underlug and a ramp front sight, in the BarrelMount frame (origin = barrel root
    at the frame front on the bore, +Y forward). Barrel mods add their own ``Muzzle`` marker (``muzzle``);
    the stock barrel does not (the base model's ``Muzzle`` sits at its crown)."""
    end = barrel_end(kind) - FRAME_FRONT_Y
    mb = ctx.builder()
    st = mb.material(mats.bare())
    c.ring_y(mb, BARREL_R, 0.0046, -0.006, end, 0.0, st, segments=24)
    mb.box((-0.0062, -0.006, -LUG_DZ), (0.0062, end - 0.004, -0.002), mat=st)          # underlug
    mb.box((-0.0040, -0.006, 0.004), (0.0040, end - 0.002, BARREL_R + 0.0020), mat=st)  # top rib
    top = BARREL_R + 0.0020
    fy = end - 0.010
    ramp = [(fy - 0.012, top), (fy + 0.004, top), (fy + 0.004, top + SIGHT_DZ + (TOP_STRAP_Z1 - BORE_Z) - top),
            (fy, top + SIGHT_DZ + (TOP_STRAP_Z1 - BORE_Z) - top)]
    mb.prism(ramp, axis="X", start=-0.0014, end=0.0014, mat=st)
    body = c.finish(mb, name, bevel=0.0006, segments=1, parent=parent)
    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    dt.cylinder(0.0047, 0.0008, segments=16, centre=(0.0, end + 0.0003, 0.0), axis="Y", mat=dark)
    if kind != "snub":
        for side in (-1.0, 1.0):                                       # ported vents on the long barrels
            lo, hi = sorted((side * 0.0058, side * 0.0066))
            dt.box((lo, end - 0.040, -LUG_DZ + 0.003), (hi, end - 0.012, -0.005), mat=dark)
    c.finish(dt, name + "Details", parent=body)
    if muzzle:
        ctx.marker("Muzzle", (0.0, end + 0.001, 0.0), parent=body)
    return body


def build_cartridges(ctx, mats, parent=None, name="Rounds"):
    """Six .357 cartridges in the Magwell frame (cylinder rear face, +Z forward into the chambers)."""
    mb = ctx.builder()
    br = mb.material(mats.brass())
    for i in range(6):
        a = math.pi / 2 + i * math.pi / 3
        x, y = math.cos(a) * CYL_CHAMBER_R, math.sin(a) * CYL_CHAMBER_R
        mb.cylinder(0.0048, 0.0012, segments=14, centre=(x, y, -0.0004), axis="Z", mat=br)     # rim
        mb.cylinder(0.0040, 0.030, segments=12, centre=(x, y, 0.015), axis="Z", mat=br)         # case
    body = c.finish(mb, name, bevel=0.0, parent=parent)
    pr = ctx.builder()
    pm = pr.material(mats.bare())
    for i in range(6):
        a = math.pi / 2 + i * math.pi / 3
        x, y = math.cos(a) * CYL_CHAMBER_R, math.sin(a) * CYL_CHAMBER_R
        pr.cylinder(0.0016, 0.0006, segments=10, centre=(x, y, -0.0012), axis="Z", mat=pm)     # primers
    c.finish(pr, name + "Round", parent=body)
    return body


def grip_profile():
    """Side profile of the walnut grip (round butt)."""
    t = GRIP_TAN
    front = [(GRIP_HALF_DEPTH + t * z, z) for z in (GRIP_TOP_Z, 0.000, -0.025, -0.050)]
    bottom = [(GRIP_HALF_DEPTH + t * -0.064 - 0.002, -0.066), (t * GRIP_BOTTOM_Z + 0.006, GRIP_BOTTOM_Z),
              (t * GRIP_BOTTOM_Z - 0.010, GRIP_BOTTOM_Z + 0.001), (-GRIP_HALF_DEPTH + t * -0.066 - 0.001, -0.064)]
    back = [(-GRIP_HALF_DEPTH + t * z - 0.002 * math.sin(math.pi * (z - GRIP_TOP_Z) / (GRIP_BOTTOM_Z - GRIP_TOP_Z)), z)
            for z in (-0.050, -0.025, 0.000)]
    # back strap humps up to the frame rear under the hammer
    hump = [(-GRIP_HALF_DEPTH + t * 0.012 - 0.006, 0.012), (FRAME_REAR_Y + 0.002, GRIP_TOP_Z + 0.010),
            (FRAME_REAR_Y + 0.010, GRIP_TOP_Z + 0.014)]
    return front + bottom + back + hump


def build_grip(ctx, mats, rubber: bool, parent=None, name="GripPanels"):
    """Walnut (stock) or finger-grooved rubber grip around the grip frame; origin = GripMount (= origin)."""
    mb = ctx.builder()
    m = mb.material(mats.rubber() if rubber else mats.wood())
    prof = grip_profile()
    if rubber:                                                       # finger grooves + longer, fuller butt
        prof = [(y + (0.0018 * abs(math.sin(z / 0.024 * math.pi)) if y > 0 and z < 0.0 else 0.0), z - (0.004 if z < -0.06 else 0.0))
                for y, z in prof]
    hw = GRIP_HALF_WIDTH + (0.0012 if rubber else 0.0)
    mb.prism(prof, axis="X", start=-hw, end=hw, mat=m)
    c.taper_x(mb, lambda y, z: 0.86 + 0.14 * math.sin(math.pi * min(1.0, max(0.0, (GRIP_TOP_Z - z) / 0.094))))
    body = c.finish(mb, name, bevel=0.0035, segments=3, parent=parent)
    if not rubber:
        ck = ctx.builder()
        km = ck.material(mats.wood())
        for side in (-1.0, 1.0):
            x = side * (hw * 0.95)
            for r in range(7):
                z = -0.052 + r * 0.0060
                yb = -GRIP_HALF_DEPTH + GRIP_TAN * z + 0.006
                yf = GRIP_HALF_DEPTH + GRIP_TAN * z - 0.007
                yy = yb + (0.0030 if r % 2 else 0.0)
                while yy < yf:
                    c.pyramid(ck.bm, c.Vector((x, yy, z)), c.Vector((0, 1, 0)), c.Vector((0, 0, 1)),
                              c.Vector((side, 0, 0)), 0.0016, 0.0006, km)
                    yy += 0.0060
        ck.cylinder(0.0030, 0.0008, segments=12, centre=(-(hw * 0.95) - 0.0003, GRIP_TAN * -0.030, -0.030), axis="X",
                    mat=ck.material(mats.bare()))
        c.finish(ck, name + "Checker", parent=body)
    else:
        rb = ctx.builder()
        rm = rb.material(mats.rubber())
        for i in range(8):
            z = -0.066 + i * 0.008
            rb.box((-hw - 0.0004, -GRIP_HALF_DEPTH + GRIP_TAN * z + 0.004, z),
                   (hw + 0.0004, GRIP_HALF_DEPTH + GRIP_TAN * z - 0.004, z + 0.0025), mat=rm)
        c.finish(rb, name + "Ribs", parent=body)
    return body
