"""Tillman Bastion BR: 7.62 battle rifle, first-person model (B4-18).

About 69 cm from the muzzle to the receiver rear (plus a 26 cm fixed stock). Stamped steel receiver,
cocking tube over the barrel with the handle on the left, slim vented polymer handguard, clamp-on top
rail, straight 20-round magazine, 3-port side brake, fixed polymer stock.

Origin = firing-hand pivot on the grip (see _bastion.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``CockingTube``, ``TopRail``, ``ReceiverDetails``, ``TriggerHousing``,
``TriggerGroup``, ``Grip``, ``Handguard``), ``Barrel`` (+ ``MuzzleBrake``). Stock parts:
``SightRail/StockSight`` (rear aperture + front post on the tube nose, ``AimPoint``),
``Magwell/StockMagazine`` (20 rounds), ``StockMount/StockStock`` (fixed stock).
"""

import math

import _common as c
import _bastion as b

ASSET_ID = "wpn_bastion_br"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.prism(c.chamfer_rect(b.REC_HW, b.REC_BOTTOM_Z, b.REC_TOP_Z, 0.005), axis="Y", start=b.REC_REAR_Y,
             end=b.REC_FRONT_Y, mat=st)
    mb.box((-0.0170, 0.060, b.REC_BOTTOM_Z - 0.010), (0.0170, 0.136, b.REC_BOTTOM_Z + 0.002), mat=st)   # magwell
    rec = c.finish(mb, "Receiver", bevel=0.0012, segments=2)

    tb = ctx.builder()
    tm = tb.material(mats.steel())
    tb.cylinder(b.TUBE_R, b.TUBE_END_Y - b.REC_FRONT_Y + 0.040, segments=24,
                centre=(0.0, (b.TUBE_END_Y + b.REC_FRONT_Y - 0.040) / 2, b.TUBE_Z), axis="Y", mat=tm)
    tb.box((-b.TUBE_R - 0.022, 0.300, b.TUBE_Z - 0.004), (-b.TUBE_R + 0.002, 0.310, b.TUBE_Z + 0.004), mat=tm)  # handle
    tb.cylinder(0.0050, 0.010, segments=14, centre=(-b.TUBE_R - 0.024, 0.305, b.TUBE_Z), axis="X", mat=tm)
    hood = c.circle(0.0140, 24, 0.0, b.TUBE_Z + b.TUBE_R + 0.009)                                  # front hood
    hole = list(reversed(c.circle(0.0110, 24, 0.0, b.TUBE_Z + b.TUBE_R + 0.009)))
    tb.prism(hood, holes=[hole], axis="Y", start=b.TUBE_END_Y - 0.020, end=b.TUBE_END_Y - 0.006, mat=tm)
    tb.cylinder(b.TUBE_R + 0.004, 0.020, segments=24, centre=(0.0, b.TUBE_END_Y - 0.010, b.TUBE_Z), axis="Y", mat=tm)
    tb.box((-0.006, b.TUBE_END_Y - 0.020, b.BORE_Z), (0.006, b.TUBE_END_Y, b.TUBE_Z), mat=tm)       # barrel clamp
    c.finish(tb, "CockingTube", bevel=0.0006, parent=rec)

    rl = ctx.builder()
    ra = rl.material(mats.alu())
    for y in (b.RAIL_Y0 + 0.012, b.RAIL_Y1 - 0.012):
        rl.box((-b.REC_HW - 0.003, y - 0.009, b.REC_TOP_Z - 0.012), (b.REC_HW + 0.003, y + 0.009, b.REC_TOP_Z + 0.004),
               mat=ra)
    rl.box((-0.0095, b.RAIL_Y0, b.REC_TOP_Z), (0.0095, b.RAIL_Y1, b.REC_TOP_Z + 0.004), mat=ra)
    c.picatinny(rl, ra, b.RAIL_Y0, b.RAIL_Y1, b.REC_TOP_Z + 0.004)
    c.finish(rl, "TopRail", bevel=0.0004, parent=rec)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    dt.box((b.REC_HW - 0.0005, 0.010, b.BORE_Z - 0.010), (b.REC_HW + 0.0005, 0.075, b.BORE_Z + 0.012), mat=dark)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * (b.REC_HW - 0.0003), side * (b.REC_HW + 0.0010)))
        dt.box((lo, b.REC_REAR_Y + 0.008, 0.074), (hi, b.REC_FRONT_Y - 0.008, 0.080), mat=s2)        # pressed rib
        for y in (-0.070, -0.020, 0.160):
            dt.cylinder(0.0030, 0.0012, segments=10, centre=(side * (b.REC_HW + 0.0004), y, 0.040), axis="X", mat=s2)
    dt.box((-0.0060, 0.136, b.REC_BOTTOM_Z - 0.012), (0.0060, 0.146, b.REC_BOTTOM_Z), mat=s2)        # mag catch
    c.finish(dt, "ReceiverDetails", parent=rec)

    th = ctx.builder()
    poly = th.material(mats.polymer())
    prof = [(-0.060, b.REC_BOTTOM_Z + 0.002), (0.058, b.REC_BOTTOM_Z + 0.002), (0.058, 0.018), (-0.026, 0.018),
            (-0.060, 0.022)]
    th.prism(prof, axis="X", start=-0.0160, end=0.0160, mat=poly)
    th.cylinder(0.0060, 0.0030, segments=18, centre=(-0.0175, -0.032, 0.024), axis="X", mat=poly)
    c.finish(th, "TriggerHousing", bevel=0.0015, segments=2, parent=rec)
    c.build_trigger_group(ctx, mats, 0.008 + b.GRIP_TAN * 0.010, 0.064, 0.019, -0.012, 0.036, mat_name="polymer",
                          parent=rec)
    c.build_grip(ctx, mats, "polymer", b.GRIP_TOP_Z, b.GRIP_BOTTOM_Z, 0.0195, 0.0150, b.GRIP_ANGLE_DEG, parent=rec,
                 finger_bumps=3)

    hg = ctx.builder()
    hm = hg.material(mats.polymer())
    outer = c.rounded_rect(0.0240, 0.0280, 0.012, 0.0, b.BORE_Z - 0.004, corner_segments=4)
    hole = list(reversed(c.circle(0.0130, 24, 0.0, b.BORE_Z)))
    hg.prism(outer, holes=[hole], axis="Y", start=b.HG_Y0, end=b.HG_Y1, mat=hm)
    for i in range(7):
        y = b.HG_Y0 + 0.025 + i * 0.024
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * 0.0236, side * 0.0246))
            hg.box((lo, y, b.BORE_Z - 0.010), (hi, y + 0.012, b.BORE_Z + 0.012), mat=hm)
    hd = c.finish(hg, "Handguard", bevel=0.0015, segments=2, parent=rec)
    hr = ctx.builder()
    c.rail_side(hr, hr.material(mats.alu()), b.UNDER_Y - 0.030, b.UNDER_Y + 0.030, 0.0, b.BORE_Z - 0.0315, 0.0)
    c.finish(hr, "HandguardRail", bevel=0.0003, parent=hd)
    return rec


def _barrel(ctx, mats):
    barrel = c.build_barrel(ctx, mats, 0.0100, b.REC_FRONT_Y - 0.010, b.BARREL_END_Y, b.BORE_Z, bore_r=0.0040,
                            segments=24)
    c.build_muzzle_brake(ctx, mats, 0.0125, b.BARREL_END_Y, b.BRAKE_LEN, b.BORE_Z, parent=barrel)  # PO6-13
    return barrel


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    _barrel(ctx, mats)

    ctx.marker("BarrelMount", (0.0, b.REC_FRONT_Y, b.BORE_Z))
    ctx.marker("Eject", (b.REC_HW, 0.040, b.BORE_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, b.SIGHT_RAIL_Y, b.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", b.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, b.UNDER_Y, b.BORE_Z - 0.0315 - 0.0057))
    ctx.marker("SideRail", (0.0250, b.SIDE_Y, b.BORE_Z))
    stock_mount = ctx.marker("StockMount", b.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Handguard (y 0.205-0.415, bottom z 0.034), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.275, 0.022))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = b.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, b.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    b.build_mag(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    b.build_stock(ctx, mats, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
