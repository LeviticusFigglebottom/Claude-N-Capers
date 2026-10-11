"""Graff-Lindqvist Rotor Saw: portable cut-off saw (PD2 OVE9000 analog), first-person model (B4-18).

About 61 cm from the blade's front edge to the rear handle. Tan motor housing with an air-filter cover,
exhaust on the right and a pull-start, rear pistol handle with a throttle trigger, loop front handle,
an arm forward to a 30 cm blade under a half guard.

Origin = firing-hand pivot on the rear handle (see _rotor.py). Forward = Godot -Z.

Node tree: ``Housing`` (+ ``HousingDetails``, ``Handle``, ``TriggerGroup``, ``Grip``, ``Arm``, ``Guard``),
``Blade`` (empty on the spindle; ENV A spins it about local X) with ``Magwell/StockMagazine`` (the blade).
Stock parts: ``SightRail/StockSight`` (guide notch, ``AimPoint``), ``Underbarrel/StockForegrip`` (loop handle).
"""

import math

import _common as c
import _rotor as r

ASSET_ID = "wpn_rotor_saw"
TRI_BUDGET = 25000


def _housing(ctx, mats):
    mb = ctx.builder()
    tan = mb.material(mats.tan())
    prof = [(r.HOUSE_Y0, r.HOUSE_Z1 - 0.020), (r.HOUSE_Y0 + 0.030, r.HOUSE_Z1), (r.HOUSE_Y1 - 0.020, r.HOUSE_Z1),
            (r.HOUSE_Y1, r.HOUSE_Z1 - 0.030), (r.HOUSE_Y1, r.HOUSE_Z0 + 0.020), (r.HOUSE_Y1 - 0.020, r.HOUSE_Z0),
            (r.HOUSE_Y0 + 0.020, r.HOUSE_Z0), (r.HOUSE_Y0, r.HOUSE_Z0 + 0.030)]
    mb.prism(prof, axis="X", start=-r.HOUSE_HW, end=r.HOUSE_HW, mat=tan)
    c.taper_x(mb, lambda y, z: 0.86 if z > r.HOUSE_Z1 - 0.010 or z < r.HOUSE_Z0 + 0.010 else 1.0)
    house = c.finish(mb, "Housing", bevel=0.0040, segments=2)
    dt = ctx.builder()
    dk = dt.material(mats.polymer())
    st = dt.material(mats.matte())
    dt.box((-0.036, r.HOUSE_Y0 + 0.040, r.HOUSE_Z1 - 0.004), (0.036, r.HOUSE_Y1 - 0.040, r.HOUSE_Z1 + 0.012), mat=dk)
    for i in range(6):                                                                       # filter cover vents
        y = r.HOUSE_Y0 + 0.052 + i * 0.018
        dt.box((-0.030, y, r.HOUSE_Z1 + 0.011), (0.030, y + 0.006, r.HOUSE_Z1 + 0.014), mat=st)
    dt.box((r.HOUSE_HW - 0.002, 0.120, -0.040), (r.HOUSE_HW + 0.016, 0.200, 0.010), mat=st)           # muffler
    for i in range(4):
        dt.box((r.HOUSE_HW + 0.0155, 0.128 + i * 0.018, -0.032), (r.HOUSE_HW + 0.0170, 0.138 + i * 0.018, 0.002),
               mat=dk)
    dt.cylinder(0.018, 0.012, segments=24, centre=(-r.HOUSE_HW - 0.004, 0.150, 0.000), axis="X", mat=dk)  # starter
    dt.box((-r.HOUSE_HW - 0.014, 0.142, -0.004), (-r.HOUSE_HW - 0.008, 0.170, 0.004), mat=st)
    c.finish(dt, "HousingDetails", bevel=0.0005, parent=house)

    hd = ctx.builder()
    hm = hd.material(mats.polymer())
    hd.box((-0.0140, -0.034, r.GRIP_TOP_Z - 0.002), (0.0140, r.HOUSE_Y0 + 0.020, r.GRIP_TOP_Z + 0.020), mat=hm)
    hd.box((-0.0140, -0.040, -0.080), (0.0140, -0.026, r.GRIP_TOP_Z + 0.010), mat=hm)            # rear loop leg
    hd.box((-0.0140, -0.040, -0.092), (0.0140, r.HOUSE_Y0 + 0.020, -0.078), mat=hm)              # bottom bar
    c.finish(hd, "Handle", bevel=0.0030, segments=2, parent=house)
    c.build_trigger_group(ctx, mats, 0.012, 0.050, r.GRIP_TOP_Z - 0.002, -0.010, 0.030, mat_name="polymer",
                          parent=house)
    c.build_grip(ctx, mats, "rubber", r.GRIP_TOP_Z, r.GRIP_BOTTOM_Z + 0.004, 0.0180, 0.0145, r.GRIP_ANGLE_DEG,
                 parent=house, finger_bumps=3)

    am = ctx.builder()
    al = am.material(mats.alu())
    sy, sz = r.SPINDLE[1], r.SPINDLE[2]
    am.prism([(r.HOUSE_Y1 - 0.030, 0.030), (sy, sz + 0.024), (sy + 0.020, sz), (sy, sz - 0.024),
              (r.HOUSE_Y1 - 0.030, -0.040)], axis="X", start=0.012, end=0.032, mat=al)
    am.cylinder(0.020, 0.030, segments=24, centre=(0.020, sy, sz), axis="X", mat=al)                # bearing
    c.finish(am, "Arm", bevel=0.0012, segments=1, parent=house)

    gd = ctx.builder()
    gm = gd.material(mats.matte())
    a0, a1 = math.radians(45.0), math.radians(225.0)
    n = 20
    arc_o = [(sy + r.GUARD_R * math.cos(a0 + (a1 - a0) * i / n), sz + r.GUARD_R * math.sin(a0 + (a1 - a0) * i / n))
             for i in range(n + 1)]
    arc_i = [(sy + (r.GUARD_R - 0.006) * math.cos(a0 + (a1 - a0) * i / n),
              sz + (r.GUARD_R - 0.006) * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    gd.prism(arc_o + list(reversed(arc_i)), axis="X", start=-0.012, end=0.012, mat=gm)
    sector = [(sy, sz)] + arc_o
    for x0 in (-0.012, 0.010):
        gd.prism(sector, axis="X", start=x0, end=x0 + 0.002, mat=gm)
    c.finish(gd, "Guard", bevel=0.0006, parent=house)
    return house


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _housing(ctx, mats)
    blade = ctx.marker("Blade", r.SPINDLE)

    ctx.marker("Muzzle", (0.0, r.MUZZLE_Y, r.SPINDLE[2]))
    ctx.marker("BarrelMount", (0.0, r.HOUSE_Y1, 0.000))
    ctx.marker("Eject", (r.HOUSE_HW + 0.016, 0.160, -0.015), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, r.SIGHT_RAIL_Y, r.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", (0.0, 0.0, 0.0), rotation_euler=(0.0, math.pi / 2, 0.0), parent=blade)
    under = ctx.marker("Underbarrel", r.UNDER)
    ctx.marker("SideRail", (r.HOUSE_HW, 0.090, 0.040))
    ctx.marker("StockMount", r.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-0.030, r.UNDER[1], r.UNDER[2] + 0.040))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _n, aim = r.build_notch(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, 0.0, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    r.build_blade(ctx, mats, "standard", parent=stock_mag)
    stock_fg = ctx.marker("StockForegrip", (0.0, 0.0, 0.0), parent=under)
    r.build_front_handle(ctx, mats, wide=False, parent=stock_fg)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: rear handle centre plane, mid grip depth, 20 mm below its top"
