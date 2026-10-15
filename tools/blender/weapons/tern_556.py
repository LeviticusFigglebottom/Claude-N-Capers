"""Graff-Lindqvist Tern: 5.56 bullpup assault rifle, first-person model (B4-18).

About 79 cm from the muzzle to the butt plate with a 26 cm barrel run inside the shell. Olive polymer
bullpup shell, magazine behind the pistol grip, ejection port beside the cheek, full-length top rail,
lower rail under the handguard, 3-port side brake.

Origin = firing-hand pivot on the grip (see _tern.py). Forward = Godot -Z.

Node tree: ``Shell`` (+ ``ShellRail``, ``ShellDetails``, ``ButtPad``, ``TriggerGroup``, ``Grip``),
``Barrel`` (+ ``MuzzleBrake``). Stock parts: ``SightRail/StockSight`` (flip-up irons, ``AimPoint``),
``Magwell/StockMagazine`` (30 rounds). ``StockMount`` is the butt plate (no stock slot).
"""

import math

import _common as c
import _tern as t

ASSET_ID = "wpn_tern_556"
TRI_BUDGET = 25000


def _shell(ctx, mats):
    mb = ctx.builder()
    ol = mb.material(mats.olive())
    prof = [(t.BODY_REAR_Y, t.BODY_TOP_Z + 0.002), (t.BODY_FRONT_Y - 0.012, t.BODY_TOP_Z),
            (t.BODY_FRONT_Y, t.BODY_TOP_Z - 0.014), (t.BODY_FRONT_Y, t.BORE_Z - 0.020),
            (t.BODY_FRONT_Y - 0.016, t.BODY_BOTTOM_Z), (0.050, t.BODY_BOTTOM_Z), (0.044, t.BODY_BOTTOM_Z + 0.004),
            (-0.022, t.BODY_BOTTOM_Z + 0.004), (-0.072, 0.010), (t.MAGWELL_Y + 0.026, -0.004),
            (t.MAGWELL_Y - 0.028, -0.004), (t.MAGWELL_Y - 0.038, 0.012), (-0.215, 0.022),
            (t.BODY_REAR_Y + 0.020, -0.006), (t.BODY_REAR_Y, -0.008)]
    mb.prism(prof, axis="X", start=-t.BODY_HW, end=t.BODY_HW, mat=ol)
    c.taper_x(mb, lambda y, z: 0.84 if z > t.BODY_TOP_Z - 0.006 else (0.80 if y < -0.20 and z < 0.03 else 1.0))
    shell = c.finish(mb, "Shell", bevel=0.0030, segments=2)

    rl = ctx.builder()
    ra = rl.material(mats.alu())
    rl.box((-0.0095, t.RAIL_Y0, t.BODY_TOP_Z - 0.003), (0.0095, t.RAIL_Y1, t.BODY_TOP_Z + 0.001), mat=ra)
    c.picatinny(rl, ra, t.RAIL_Y0, t.RAIL_Y1, t.BODY_TOP_Z)
    c.rail_side(rl, ra, t.UNDER_Y - 0.030, t.UNDER_Y + 0.030, 0.0, t.BODY_BOTTOM_Z + 0.0005, 0.0)
    c.rail_side(rl, ra, t.SIDE_Y - 0.022, t.SIDE_Y + 0.022, t.BODY_HW - 0.0005, t.BORE_Z, 1.0)
    c.finish(rl, "ShellRail", bevel=0.0004, parent=shell)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    st = dt.material(mats.steel())
    dt.box((t.BODY_HW - 0.0005, -0.170, t.BORE_Z - 0.008), (t.BODY_HW + 0.0005, -0.100, t.BORE_Z + 0.014), mat=dark)
    dt.box((t.BODY_HW + 0.0002, -0.160, t.BORE_Z - 0.004), (t.BODY_HW + 0.0012, -0.112, t.BORE_Z + 0.010), mat=st)
    dt.box((-t.BODY_HW - 0.012, 0.070, t.BORE_Z + 0.008), (-t.BODY_HW + 0.001, 0.082, t.BORE_Z + 0.018), mat=st)  # charger
    dt.box((-t.BODY_HW - 0.0006, -0.020, t.BORE_Z + 0.012), (-t.BODY_HW + 0.0005, 0.120, t.BORE_Z + 0.016), mat=dark)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * (t.BODY_HW - 0.0004), side * (t.BODY_HW + 0.0004)))
        for i in range(5):                                                                     # handguard vents
            y = 0.060 + i * 0.012
            dt.box((lo, y, t.BODY_BOTTOM_Z + 0.008), (hi, y + 0.005, t.BORE_Z - 0.004), mat=dark)
        dt.cylinder(0.0030, 0.0012, segments=12, centre=(side * (t.BODY_HW + 0.0002), -0.240, 0.050), axis="X", mat=st)
    dt.box((-0.0220, -0.010, 0.026), (-0.0180, 0.016, 0.032), mat=st)                             # selector
    c.finish(dt, "ShellDetails", bevel=0.0002, parent=shell)
    bp = ctx.builder()
    bp.box((-t.BODY_HW + 0.002, t.BODY_REAR_Y - 0.014, -0.006), (t.BODY_HW - 0.002, t.BODY_REAR_Y + 0.001,
                                                                t.BODY_TOP_Z), mat=bp.material(mats.rubber()))
    c.finish(bp, "ButtPad", bevel=0.0025, segments=2, parent=shell)

    c.build_trigger_group(ctx, mats, 0.020 + t.GRIP_TAN * 0.010, 0.082, t.BODY_BOTTOM_Z + 0.004, -0.008, 0.042,
                          mat_name="olive", parent=shell)
    c.build_grip(ctx, mats, "olive", t.GRIP_TOP_Z, t.GRIP_BOTTOM_Z, 0.0195, 0.0145, t.GRIP_ANGLE_DEG, parent=shell,
                 finger_bumps=3)
    return shell


def _barrel(ctx, mats):
    barrel = c.build_barrel(ctx, mats, 0.0085, t.BODY_FRONT_Y - 0.010, t.BARREL_END_Y, t.BORE_Z, bore_r=0.0030,
                            segments=24)
    mb = ctx.builder()
    gm = mb.material(mats.steel())
    mb.cylinder(0.0120, 0.016, segments=24, centre=(0.0, t.BODY_FRONT_Y + 0.040, t.BORE_Z), axis="Y", mat=gm)  # gas block
    c.finish(mb, "GasBlock", bevel=0.0006, parent=barrel)
    c.build_muzzle_brake(ctx, mats, 0.0110, t.BARREL_END_Y, t.BRAKE_LEN, t.BORE_Z, parent=barrel)  # PO6-13
    return barrel


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _shell(ctx, mats)
    _barrel(ctx, mats)

    ctx.marker("BarrelMount", (0.0, t.BODY_FRONT_Y, t.BORE_Z))
    ctx.marker("Eject", (t.BODY_HW, -0.136, t.BORE_Z + 0.004), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, t.SIGHT_RAIL_Y, t.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", t.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, t.UNDER_Y, t.BODY_BOTTOM_Z - 0.0057))
    ctx.marker("SideRail", (t.BODY_HW + 0.0057, t.SIDE_Y, t.BORE_Z))
    ctx.marker("StockMount", t.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup for the smg set): under the bullpup fore-end (grip front y 0.04 to body front 0.140, bottom z 0.024), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.073, 0.012))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = t.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, t.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    t.build_mag(ctx, mats, extended=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
