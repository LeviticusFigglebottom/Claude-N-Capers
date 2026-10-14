"""Graff-Lindqvist Harrow 12: box-fed semi-automatic 12-gauge, first-person model (B4-18).

About 57 cm from the muzzle to the receiver rear (plus a 26 cm fixed stock). Stamped steel receiver with
a railed dust cover, polymer handguard under a gas tube, heavy plain barrel, wide eight-shell box
magazine, fixed polymer stock.

Origin = firing-hand pivot on the grip (see _harrow.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``DustCover``, ``TopRail``, ``ReceiverDetails``, ``ChargingHandle``, ``TriggerGroup``, ``Grip``,
``Handguard``, ``GasTube``), ``Barrel``. Stock parts: ``SightRail/StockSight`` (rear aperture + front
post, ``AimPoint``), ``Magwell/StockMagazine`` (8 shells), ``StockMount/StockStock``.
"""

import math

import _common as c
import _harrow as r

ASSET_ID = "wpn_harrow_12"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.prism(c.chamfer_rect(r.REC_HW, r.REC_BOTTOM_Z, r.REC_TOP_Z - 0.010, 0.003), axis="Y", start=r.REC_REAR_Y,
             end=r.REC_FRONT_Y, mat=st)
    mb.box((-0.0210, 0.040, r.REC_BOTTOM_Z - 0.008), (0.0210, 0.142, r.REC_BOTTOM_Z + 0.002), mat=st)   # magwell
    rec = c.finish(mb, "Receiver", bevel=0.0010, segments=2)
    dc = ctx.builder()
    dm = dc.material(mats.matte())
    top = c.rounded_rect(r.REC_HW + 0.0005, 0.0080, 0.007, 0.0, r.REC_TOP_Z - 0.008, corner_segments=4)
    dc.prism(top, axis="Y", start=r.REC_REAR_Y - 0.004, end=r.REC_FRONT_Y - 0.020, mat=dm)
    cover = c.finish(dc, "DustCover", bevel=0.0006, parent=rec)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), r.RAIL_Y0, r.RAIL_Y1, r.REC_TOP_Z)
    c.finish(rl, "TopRail", bevel=0.0004, parent=cover)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    dt.box((r.REC_HW - 0.0005, -0.010, r.BORE_Z - 0.012), (r.REC_HW + 0.0005, 0.090, r.BORE_Z + 0.014), mat=dark)
    dt.box((r.REC_HW - 0.0002, -0.080, 0.030), (r.REC_HW + 0.0040, 0.010, 0.042), mat=s2)         # safety lever
    for side in (-1.0, 1.0):
        for y in (-0.080, -0.030, 0.120):
            dt.cylinder(0.0030, 0.0012, segments=10, centre=(side * (r.REC_HW + 0.0003), y, 0.036), axis="X", mat=s2)
    c.finish(dt, "ReceiverDetails", parent=rec)
    ch = ctx.builder()  # D-058: own node so ENV A can pull it back on bolt_release
    ch.box((r.REC_HW + 0.0003, 0.070, r.BORE_Z + 0.004), (r.REC_HW + 0.014, 0.082, r.BORE_Z + 0.012),
           mat=ch.material(mats.bare()))
    c.finish(ch, "ChargingHandle", bevel=0.0006, parent=rec)
    c.build_trigger_group(ctx, mats, 0.006 + r.GRIP_TAN * 0.010, 0.040, r.REC_BOTTOM_Z, -0.010, 0.030, parent=rec)
    c.build_grip(ctx, mats, "polymer", r.GRIP_TOP_Z, r.GRIP_BOTTOM_Z, 0.0195, 0.0150, r.GRIP_ANGLE_DEG, parent=rec,
                 finger_bumps=0)

    hg = ctx.builder()
    hm = hg.material(mats.polymer())
    outer = c.rounded_rect(0.0240, 0.0230, 0.010, 0.0, r.BORE_Z - 0.006, corner_segments=3)
    hole = list(reversed(c.circle(r.BARREL_R + 0.001, 24, 0.0, r.BORE_Z)))
    hg.prism(outer, holes=[hole], axis="Y", start=r.HG_Y0, end=r.HG_Y1, mat=hm)
    for i in range(5):
        y = r.HG_Y0 + 0.020 + i * 0.022
        hg.box((-0.0250, y, r.BORE_Z - 0.024), (0.0250, y + 0.008, r.BORE_Z - 0.012), mat=hm)
    hd = c.finish(hg, "Handguard", bevel=0.0015, segments=2, parent=rec)
    hr = ctx.builder()
    c.rail_side(hr, hr.material(mats.alu()), r.UNDER_Y - 0.025, r.UNDER_Y + 0.025, 0.0, r.BORE_Z - 0.0285, 0.0)
    c.finish(hr, "HandguardRail", bevel=0.0003, parent=hd)
    gt = ctx.builder()
    gs = gt.material(mats.steel())
    gt.cylinder(0.0075, r.HG_Y1 - r.REC_FRONT_Y + 0.030, segments=16,
                centre=(0.0, (r.HG_Y1 + r.REC_FRONT_Y + 0.010) / 2, r.BORE_Z + 0.020), axis="Y", mat=gs)
    gt.box((-0.0110, r.HG_Y1 + 0.004, r.BORE_Z - 0.012), (0.0110, r.HG_Y1 + 0.028, r.BORE_Z + 0.028), mat=gs)
    c.finish(gt, "GasTube", bevel=0.0006, parent=rec)
    return rec


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    c.build_barrel(ctx, mats, r.BARREL_R, r.REC_FRONT_Y - 0.010, r.BARREL_END_Y, r.BORE_Z, bore_r=0.0092,
                   segments=28)

    ctx.marker("Muzzle", (0.0, r.MUZZLE_Y, r.BORE_Z))
    ctx.marker("BarrelMount", (0.0, r.REC_FRONT_Y, r.BORE_Z))
    ctx.marker("Eject", (r.REC_HW, 0.040, r.BORE_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, r.SIGHT_RAIL_Y, r.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", r.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, r.UNDER_Y, r.BORE_Z - 0.0285 - 0.0057))
    ctx.marker("SideRail", (0.0250, r.SIDE_Y, r.BORE_Z - 0.006))
    stock_mount = ctx.marker("StockMount", r.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Handguard (y 0.152-0.300, bottom z 0.031), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.201, 0.019))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = r.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, r.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    r.build_mag(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    r.build_stock(ctx, mats, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
