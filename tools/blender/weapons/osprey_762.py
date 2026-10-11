"""Brannock Osprey Marksman: semi-automatic 7.62 sniper rifle, first-person model (B4-18).

About 79 cm from the muzzle brake to the receiver rear (plus a 27 cm precision stock). Machined receiver
with a long top rail, free-float handguard, fluted barrel with a two-port brake, ten-round magazine,
adjustable stock with a cheek riser, fixed 4x scope.

Origin = firing-hand pivot on the grip (see _osprey.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``TopRail``, ``ReceiverDetails``, ``TriggerGroup``, ``Grip``, ``Handguard``),
``Barrel`` (+ ``Brake``), ``Stock``. Stock parts: ``SightRail/StockSight`` (4x scope, ``AimPoint``),
``Magwell/StockMagazine`` (10 rounds).
"""

import math

import _common as c
import _osprey as o

ASSET_ID = "wpn_osprey_762"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.alu())
    mb.prism(c.chamfer_rect(o.REC_HW, o.REC_BOTTOM_Z, o.REC_TOP_Z, 0.004), axis="Y", start=o.REC_REAR_Y,
             end=o.REC_FRONT_Y, mat=st)
    mb.box((-0.0165, 0.060, o.REC_BOTTOM_Z - 0.012), (0.0165, 0.140, o.REC_BOTTOM_Z + 0.002), mat=st)    # magwell
    lower = [(-0.055, o.REC_BOTTOM_Z + 0.002), (0.058, o.REC_BOTTOM_Z + 0.002), (0.058, 0.018), (-0.024, 0.018),
             (-0.055, 0.026)]
    mb.prism(lower, axis="X", start=-0.0150, end=0.0150, mat=st)
    rec = c.finish(mb, "Receiver", bevel=0.0012, segments=2)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), o.RAIL_Y0, o.RAIL_Y1, o.REC_TOP_Z)
    rl.box((-0.0095, o.REC_FRONT_Y, o.REC_TOP_Z - 0.004), (0.0095, o.RAIL_Y1, o.REC_TOP_Z + 0.001),
           mat=rl.material(mats.alu()))
    c.finish(rl, "TopRail", bevel=0.0004, parent=rec)
    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    dt.box((o.REC_HW - 0.0005, 0.000, o.BORE_Z - 0.010), (o.REC_HW + 0.0005, 0.070, o.BORE_Z + 0.012), mat=dark)
    dt.box((o.REC_HW + 0.0002, 0.012, o.BORE_Z - 0.004), (o.REC_HW + 0.0030, 0.050, o.BORE_Z + 0.006), mat=s2)
    dt.box((-0.010, o.REC_REAR_Y - 0.010, o.BORE_Z + 0.008), (0.010, o.REC_REAR_Y + 0.002, o.BORE_Z + 0.016), mat=s2)
    for side in (-1.0, 1.0):
        for y in (-0.050, 0.140):
            dt.cylinder(0.0028, 0.0012, segments=10, centre=(side * (o.REC_HW + 0.0003), y, 0.040), axis="X", mat=s2)
    dt.cylinder(0.0060, 0.0030, segments=18, centre=(-0.0165, -0.032, 0.026), axis="X", mat=s2)
    c.finish(dt, "ReceiverDetails", parent=rec)
    c.build_trigger_group(ctx, mats, 0.006 + o.GRIP_TAN * 0.010, 0.060, 0.019, -0.012, 0.034, parent=rec)
    c.build_grip(ctx, mats, "polymer", o.GRIP_TOP_Z, o.GRIP_BOTTOM_Z, 0.0195, 0.0150, o.GRIP_ANGLE_DEG, parent=rec,
                 finger_bumps=3)
    hg = ctx.builder()
    hm = hg.material(mats.alu())
    outer = c.chamfer_rect(o.HG_HW, o.BORE_Z - 0.026, o.REC_TOP_Z - 0.001, 0.009)
    hole = list(reversed(c.circle(0.0150, 24, 0.0, o.BORE_Z)))
    hg.prism(outer, holes=[hole], axis="Y", start=o.HG_Y0, end=o.HG_Y1, mat=hm)
    dk = hg.material(mats.polymer())
    for i in range(8):
        y = o.HG_Y0 + 0.020 + i * 0.034
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * (o.HG_HW - 0.0004), side * (o.HG_HW + 0.0004)))
            hg.box((lo, y, o.BORE_Z - 0.010), (hi, y + 0.020, o.BORE_Z + 0.008), mat=dk)
    c.rail_side(hg, hg.material(mats.alu()), o.UNDER_Y - 0.030, o.UNDER_Y + 0.030, 0.0, o.BORE_Z - 0.0255, 0.0)
    c.rail_side(hg, hg.material(mats.alu()), o.SIDE_Y - 0.020, o.SIDE_Y + 0.020, o.HG_HW - 0.0005, o.BORE_Z, 1.0)
    c.finish(hg, "Handguard", bevel=0.0012, segments=1, parent=rec)
    return rec


def _barrel(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.prism(c.fluted(o.BARREL_R, o.BARREL_R - 0.0022, 6, 0.0, o.BORE_Z), axis="Y", start=o.HG_Y1 - 0.010,
             end=o.BARREL_END_Y, mat=st)
    mb.cylinder(0.0090, o.HG_Y1 - o.REC_FRONT_Y, segments=20, centre=(0.0, (o.HG_Y1 + o.REC_FRONT_Y) / 2, o.BORE_Z),
                axis="Y", mat=st)
    barrel = c.finish(mb, "Barrel", bevel=0.0004)
    br = ctx.builder()
    bm = br.material(mats.steel())
    dark = br.material(mats.polymer())
    y0 = o.BARREL_END_Y
    br.cylinder(0.0140, o.BRAKE_LEN, segments=24, centre=(0.0, y0 + o.BRAKE_LEN / 2, o.BORE_Z), axis="Y", mat=bm)
    for i in range(2):
        y = y0 + 0.010 + i * 0.016
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * 0.0125, side * 0.0146))
            br.box((lo, y, o.BORE_Z - 0.007), (hi, y + 0.010, o.BORE_Z + 0.007), mat=dark)
    c.finish(br, "Brake", bevel=0.0006, parent=barrel)
    return barrel


def _stock(ctx, mats):
    y0 = o.REC_REAR_Y
    yr = y0 - 0.270
    prof = [(y0 + 0.002, 0.078), (y0 - 0.020, 0.082), (yr + 0.010, 0.082), (yr, 0.074), (yr, -0.050),
            (yr + 0.030, -0.054), (y0 - 0.120, 0.004), (y0 - 0.020, 0.040), (y0 + 0.002, 0.046)]
    hole = [(y0 - 0.050, 0.066), (yr + 0.050, 0.066), (yr + 0.050, -0.022), (y0 - 0.120, 0.030)]
    mb = ctx.builder()
    m = mb.material(mats.polymer())
    mb.prism(prof, holes=[list(reversed(hole))], axis="X", start=-0.0170, end=0.0170, mat=m)
    stock = c.finish(mb, "Stock", bevel=0.0025, segments=2)
    dt = ctx.builder()
    dm = dt.material(mats.alu())
    dt.box((-0.0150, yr + 0.020, 0.084), (0.0150, y0 - 0.060, 0.098), mat=dm)                    # cheek riser
    for y in (yr + 0.040, y0 - 0.080):
        dt.cylinder(0.0035, 0.016, segments=12, centre=(0.0, y, 0.088), axis="Z", mat=dm)
    dt.box((-0.0170, yr - 0.016, -0.052), (0.0170, yr, 0.078), mat=dt.material(mats.rubber()))
    c.finish(dt, "StockDetails", bevel=0.0012, segments=1, parent=stock)
    return stock


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    _barrel(ctx, mats)
    _stock(ctx, mats)

    ctx.marker("Muzzle", (0.0, o.MUZZLE_Y, o.BORE_Z))
    ctx.marker("BarrelMount", (0.0, o.REC_FRONT_Y, o.BORE_Z))
    ctx.marker("Eject", (o.REC_HW, 0.035, o.BORE_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, o.SIGHT_RAIL_Y, o.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", o.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, o.UNDER_Y, o.BORE_Z - 0.0255 - 0.0057))
    ctx.marker("SideRail", (o.HG_HW + 0.0057, o.SIDE_Y, o.BORE_Z))
    ctx.marker("StockMount", o.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-0.028, 0.330, o.BORE_Z - 0.018))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    o.build_scope(ctx, mats, eight=False, parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    o.build_mag(ctx, mats, extended=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
