"""Tillman Furnace: flamethrower, first-person model (B4-18).

About 60 cm from the nozzle to the housing rear (plus a short 20 cm stock). Steel valve housing with a
pistol grip, perforated heat shield over a long nozzle tube, front handle, brushed-steel fuel tank under
the shield, pilot light under the nozzle tip.

Origin = firing-hand pivot on the grip (see _furnace.py). Forward = Godot -Z.

Node tree: ``Housing`` (+ ``HousingDetails``, ``TriggerGroup``, ``Grip``, ``Stock``, ``Shield``,
``FrontHandle``), ``PilotLight`` (emissive igniter, B4-18). Stock parts: ``SightRail/StockSight`` (notch +
post, ``AimPoint``), ``Magwell/StockMagazine`` (fuel tank).
"""

import math

import _common as c
import _furnace as f

ASSET_ID = "wpn_furnace_ft"
TRI_BUDGET = 25000


def _housing(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.matte())
    mb.prism(c.chamfer_rect(f.BODY_HW, f.BODY_BOTTOM_Z, f.BODY_TOP_Z, 0.008), axis="Y", start=f.BODY_REAR_Y,
             end=f.BODY_FRONT_Y, mat=st)
    house = c.finish(mb, "Housing", bevel=0.0015, segments=2)
    dt = ctx.builder()
    s2 = dt.material(mats.bare())
    dk = dt.material(mats.polymer())
    dt.cylinder(0.0140, 0.012, segments=24, centre=(f.BODY_HW + 0.006, 0.060, f.BORE_Z), axis="X", mat=s2)   # valve knob
    for i in range(6):
        a = 2 * math.pi * i / 6
        dt.box((f.BODY_HW + 0.010, 0.060 + math.cos(a) * 0.012 - 0.002, f.BORE_Z + math.sin(a) * 0.012 - 0.002),
               (f.BODY_HW + 0.014, 0.060 + math.cos(a) * 0.012 + 0.002, f.BORE_Z + math.sin(a) * 0.012 + 0.002), mat=s2)
    dt.box((-f.BODY_HW - 0.004, 0.020, f.BORE_Z - 0.010), (-f.BODY_HW, 0.110, f.BORE_Z + 0.010), mat=dk)    # igniter box
    dt.box((-0.008, f.BODY_FRONT_Y - 0.006, f.BODY_BOTTOM_Z - 0.010), (0.008, f.MAGWELL_POS[1] + 0.010,
                                                                    f.BODY_BOTTOM_Z), mat=s2)        # fuel line
    for side in (-1.0, 1.0):
        for y in (-0.040, 0.120):
            dt.cylinder(0.0034, 0.0012, segments=12, centre=(side * (f.BODY_HW + 0.0003), y, 0.040), axis="X", mat=s2)
    dt.box((-0.0095, -0.020, f.BODY_TOP_Z - 0.002), (0.0095, 0.080, f.RAIL_TOP_Z), mat=s2)            # sight base
    c.finish(dt, "HousingDetails", bevel=0.0003, parent=house)
    c.build_trigger_group(ctx, mats, 0.006 + 0.010 * math.tan(math.radians(f.GRIP_ANGLE_DEG)), 0.064,
                          f.BODY_BOTTOM_Z, -0.012, 0.034, parent=house)
    c.build_grip(ctx, mats, "polymer", f.GRIP_TOP_Z, f.GRIP_BOTTOM_Z, 0.0200, 0.0155, f.GRIP_ANGLE_DEG, parent=house,
                 finger_bumps=3)
    prof = [(0.004, 0.024), (0.004, -0.030), (-0.040, -0.040), (-0.190, -0.080), (-0.200, -0.078), (-0.200, 0.024),
            (-0.180, 0.030)]
    sk = c.build_butt_stock(ctx, mats, "polymer", prof, 0.0180, name="Stock", pad_y=-0.200, pad_z=(-0.078, 0.024))
    sk.location = f.STOCK_MOUNT
    sk.parent = house

    sh = ctx.builder()
    sm = sh.material(mats.steel())
    dk2 = sh.material(mats.polymer())
    c.ring_y(sh, f.SHIELD_R, f.SHIELD_R - 0.0015, f.BODY_FRONT_Y, f.SHIELD_Y1, f.BORE_Z, sm, segments=36)
    for i in range(7):
        y = f.BODY_FRONT_Y + 0.030 + i * 0.042
        for k in range(6):
            a = 2 * math.pi * (k + 0.5) / 6
            x, z = math.cos(a) * (f.SHIELD_R + 0.0002), f.BORE_Z + math.sin(a) * (f.SHIELD_R + 0.0002)
            sh.cylinder(0.0050, 0.0012, segments=10, centre=(x, y, z), axis="X" if abs(math.cos(a)) > 0.7 else "Z",
                        mat=dk2)
    sh.cylinder(f.NOZZLE_R, f.NOZZLE_Y1 - f.BODY_FRONT_Y, segments=24,
                centre=(0.0, (f.NOZZLE_Y1 + f.BODY_FRONT_Y) / 2, f.BORE_Z), axis="Y", mat=sm)
    c.ring_y(sh, f.NOZZLE_R + 0.0025, 0.0060, f.NOZZLE_Y1 - 0.012, f.NOZZLE_Y1, f.BORE_Z, sm, segments=24)
    c.finish(sh, "Shield", bevel=0.0005, parent=house)
    fh = ctx.builder()
    fm = fh.material(mats.polymer())
    fh.box((-0.0130, f.HANDLE_Y - 0.018, f.BORE_Z - f.SHIELD_R - 0.010), (0.0130, f.HANDLE_Y + 0.018,
                                                                        f.BORE_Z - f.SHIELD_R + 0.004), mat=fm)
    fh.prism(c.rounded_rect(0.0130, 0.0150, 0.008, 0.0, f.HANDLE_Y, corner_segments=3), axis="Z",
             start=f.BORE_Z - f.SHIELD_R - 0.085, end=f.BORE_Z - f.SHIELD_R - 0.008, mat=fm)
    c.finish(fh, "FrontHandle", bevel=0.0018, segments=2, parent=house)
    return house


def _pilot(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(0.0040, 0.050, segments=12, centre=(0.0, f.NOZZLE_Y1 - 0.030, f.BORE_Z - f.NOZZLE_R - 0.006),
                axis="Y", mat=st)
    mb.box((-0.003, f.NOZZLE_Y1 - 0.040, f.BORE_Z - f.NOZZLE_R - 0.006), (0.003, f.NOZZLE_Y1 - 0.034, f.BORE_Z),
           mat=st)
    glow = mb.material(mats.reticle())
    mb.cylinder(0.0030, 0.004, segments=12, centre=(0.0, f.NOZZLE_Y1 - 0.003, f.BORE_Z - f.NOZZLE_R - 0.006),
                axis="Y", mat=glow)
    return c.finish(mb, "PilotLight", bevel=0.0003)


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _housing(ctx, mats)
    _pilot(ctx, mats)

    ctx.marker("Muzzle", (0.0, f.MUZZLE_Y, f.BORE_Z))
    ctx.marker("BarrelMount", (0.0, f.BODY_FRONT_Y, f.BORE_Z))
    ctx.marker("Eject", (f.BODY_HW, 0.040, f.BORE_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, f.SIGHT_RAIL_Y, f.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", f.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, f.HANDLE_Y, f.BORE_Z - f.SHIELD_R - 0.085))
    ctx.marker("SideRail", (f.SHIELD_R + 0.002, 0.420, f.BORE_Z))
    ctx.marker("StockMount", f.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-0.016, f.HANDLE_Y, f.BORE_Z - f.SHIELD_R - 0.040))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _s, aim = f.build_post_sight(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, 0.0, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    f.build_tank(ctx, mats, big=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
