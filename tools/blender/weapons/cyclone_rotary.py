"""Brannock Cyclone Rotary: six-barrel rotary gun (PD2 minigun analog), first-person model (B4-18).

About 68 cm from the barrel ends to the housing rear. Motor housing with cooling fins, a carry handle
with a top rail, a spinning six-barrel cluster with three clamps, front handle under the nose, olive belt
box on the left side.

Origin = firing-hand pivot on the grip (see _cyclone.py). Forward = Godot -Z.

Node tree: ``Housing`` (+ ``HousingDetails``, ``CarryHandle``, ``TriggerGroup``, ``Grip``,
``FrontHandle``), ``Rotor`` (empty on the cluster axis; ENV A spins it) with ``BarrelMount/StockBarrel``
(the cluster). Stock parts: ``SightRail/StockSight`` (flip-up irons, ``AimPoint``),
``Magwell/StockMagazine`` (belt box).
"""

import math

import _common as c
import _cyclone as y

ASSET_ID = "wpn_cyclone_rotary"
TRI_BUDGET = 25000


def _housing(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.matte())
    cross = c.rounded_rect(y.HOUSE_HW, (y.HOUSE_Z1 - y.HOUSE_Z0) / 2, 0.022, 0.0, (y.HOUSE_Z1 + y.HOUSE_Z0) / 2,
                           corner_segments=4)
    mb.prism(cross, axis="Y", start=y.HOUSE_Y0, end=y.HOUSE_Y1, mat=st)
    house = c.finish(mb, "Housing", bevel=0.0020, segments=2)
    dt = ctx.builder()
    dk = dt.material(mats.polymer())
    s2 = dt.material(mats.steel())
    for i in range(8):                                                                       # cooling fins
        yy = y.HOUSE_Y0 + 0.020 + i * 0.016
        dt.prism(c.rounded_rect(y.HOUSE_HW + 0.004, (y.HOUSE_Z1 - y.HOUSE_Z0) / 2 + 0.004, 0.024, 0.0,
                                (y.HOUSE_Z1 + y.HOUSE_Z0) / 2, corner_segments=4), axis="Y", start=yy, end=yy + 0.006,
                 mat=s2)
    dt.cylinder(0.034, 0.010, segments=32, centre=(0.0, y.HOUSE_Y1 + 0.002, y.AXIS_Z), axis="Y", mat=s2)  # nose ring
    dt.box((y.HOUSE_HW - 0.002, 0.030, 0.060), (y.HOUSE_HW + 0.008, 0.090, 0.100), mat=dk)          # ejection chute
    dt.box((-0.0120, y.HOUSE_Y0 - 0.010, 0.050), (0.0120, y.HOUSE_Y0, 0.110), mat=s2)               # battery cap
    c.finish(dt, "HousingDetails", bevel=0.0005, parent=house)
    ch = ctx.builder()
    cm = ch.material(mats.matte())
    ch.box((-0.0130, y.HANDLE_Y0, y.HANDLE_TOP_Z - 0.010), (0.0130, y.HANDLE_Y1, y.HANDLE_TOP_Z), mat=cm)
    for yy in (y.HANDLE_Y0, y.HANDLE_Y1 - 0.020):
        ch.box((-0.0120, yy, y.HOUSE_Z1 - 0.004), (0.0120, yy + 0.020, y.HANDLE_TOP_Z - 0.008), mat=cm)
    handle = c.finish(ch, "CarryHandle", bevel=0.0012, segments=2, parent=house)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), y.RAIL_Y0, y.RAIL_Y1, y.HANDLE_TOP_Z)
    c.finish(rl, "TopRail", bevel=0.0004, parent=handle)
    c.build_trigger_group(ctx, mats, 0.006 + 0.010 * math.tan(math.radians(y.GRIP_ANGLE_DEG)), 0.062, y.HOUSE_Z0 + 0.002,
                          -0.010, 0.034, parent=house)
    c.build_grip(ctx, mats, "polymer", y.GRIP_TOP_Z, y.GRIP_BOTTOM_Z, 0.0200, 0.0155, y.GRIP_ANGLE_DEG, parent=house,
                 finger_bumps=3)
    gp = ctx.builder()
    gp.box((-0.0140, -0.010, -0.004), (0.0140, 0.024, 0.006), mat=gp.material(mats.polymer()))
    fh = c.finish(gp, "FrontHandleMount", bevel=0.0010, parent=house)
    fh.location = y.UNDER
    c.build_vertical_grip(ctx, mats, length=0.085, parent=fh, name="FrontHandle")
    return house


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _housing(ctx, mats)
    rotor = ctx.marker("Rotor", y.ROTOR)
    bmount = ctx.marker("BarrelMount", (0.0, 0.0, 0.0), parent=rotor)

    ctx.marker("Muzzle", (0.0, y.MUZZLE_Y, y.AXIS_Z))
    ctx.marker("Eject", (y.HOUSE_HW + 0.008, 0.060, 0.070), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, y.SIGHT_RAIL_Y, y.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", y.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, y.UNDER[1], y.UNDER[2] - 0.004))
    ctx.marker("SideRail", (y.HOUSE_HW + 0.004, -0.060, y.AXIS_Z))
    ctx.marker("StockMount", y.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-0.016, y.UNDER[1], y.UNDER[2] - 0.040))

    sb = ctx.marker("StockBarrel", (0.0, 0.0, 0.0), parent=bmount)
    y.build_cluster(ctx, mats, y.LONG_LEN, parent=sb)
    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = y.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, y.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    y.build_box(ctx, mats, big=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
