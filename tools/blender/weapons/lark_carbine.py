"""Halvard Arms Lark Carbine: short 5.56 carbine with a three-round burst, first-person model (B4-18).

About 44 cm from the muzzle to the stock hinge (plus a 25 cm side-folding stock). Machined steel
receiver with an integral top rail, short tan handguard with the gas tube above the barrel, curved tan
magazine, birdcage hider, tan skeleton stock.

Origin = firing-hand pivot on the grip (see _lark.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``TopRail``, ``ReceiverDetails``, ``TriggerGroup``, ``Grip``, ``Handguard``,
``GasTube``), ``Barrel`` (+ ``FlashHider``). Stock parts: ``SightRail/StockSight`` (flip-up irons,
``AimPoint``), ``Magwell/StockMagazine`` (30 rounds), ``StockMount/StockStock`` (extended stock).
"""

import math

import _common as c
import _lark as k

ASSET_ID = "wpn_lark_carbine"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.prism(c.chamfer_rect(k.REC_HW, k.REC_BOTTOM_Z, k.REC_TOP_Z, 0.004), axis="Y", start=k.REC_REAR_Y,
             end=k.REC_FRONT_Y, mat=st)
    mb.box((-0.0160, 0.060, k.REC_BOTTOM_Z - 0.010), (0.0160, 0.128, k.REC_BOTTOM_Z + 0.002), mat=st)    # magwell
    lower = [(-0.050, k.REC_BOTTOM_Z + 0.002), (0.058, k.REC_BOTTOM_Z + 0.002), (0.058, 0.018), (-0.024, 0.018),
             (-0.050, 0.024)]
    mb.prism(lower, axis="X", start=-0.0150, end=0.0150, mat=st)
    rec = c.finish(mb, "Receiver", bevel=0.0012, segments=2)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), k.RAIL_Y0, k.RAIL_Y1, k.REC_TOP_Z)
    c.finish(rl, "TopRail", bevel=0.0004, parent=rec)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    dt.box((k.REC_HW - 0.0005, 0.000, k.BORE_Z - 0.010), (k.REC_HW + 0.0005, 0.060, k.BORE_Z + 0.012), mat=dark)
    dt.box((k.REC_HW + 0.0002, 0.010, k.BORE_Z + 0.004), (k.REC_HW + 0.012, 0.022, k.BORE_Z + 0.012), mat=s2)  # handle
    for side in (-1.0, 1.0):
        for y in (-0.055, 0.130):
            dt.cylinder(0.0028, 0.0012, segments=10, centre=(side * (k.REC_HW + 0.0003), y, 0.040), axis="X", mat=s2)
    dt.cylinder(0.0060, 0.0030, segments=18, centre=(-0.0165, -0.030, 0.026), axis="X", mat=s2)       # selector
    dt.box((-0.0180, -0.030, 0.024), (-0.0168, -0.010, 0.028), mat=s2)
    c.finish(dt, "ReceiverDetails", parent=rec)
    c.build_trigger_group(ctx, mats, 0.008 + k.GRIP_TAN * 0.010, 0.062, 0.019, -0.012, 0.036, parent=rec)
    c.build_grip(ctx, mats, "tan", k.GRIP_TOP_Z, k.GRIP_BOTTOM_Z, 0.0190, 0.0145, k.GRIP_ANGLE_DEG, parent=rec,
                 finger_bumps=3)

    hg = ctx.builder()
    hm = hg.material(mats.tan())
    outer = c.rounded_rect(0.0230, 0.0270, 0.010, 0.0, k.BORE_Z + 0.002, corner_segments=3)
    hole = list(reversed(c.circle(0.0110, 24, 0.0, k.BORE_Z)))
    hg.prism(outer, holes=[hole], axis="Y", start=k.HG_Y0, end=k.HG_Y1, mat=hm)
    for i in range(5):
        y = k.HG_Y0 + 0.018 + i * 0.020
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * 0.0226, side * 0.0238))
            hg.box((lo, y, k.BORE_Z - 0.012), (hi, y + 0.010, k.BORE_Z + 0.016), mat=hm)
    hd = c.finish(hg, "Handguard", bevel=0.0015, segments=2, parent=rec)
    hr = ctx.builder()
    c.rail_side(hr, hr.material(mats.alu()), k.UNDER_Y - 0.030, k.UNDER_Y + 0.030, 0.0, k.BORE_Z - 0.0245, 0.0)
    c.rail_side(hr, hr.material(mats.alu()), k.SIDE_Y - 0.020, k.SIDE_Y + 0.020, 0.0225, k.BORE_Z, 1.0)
    c.finish(hr, "HandguardRail", bevel=0.0003, parent=hd)
    gt = ctx.builder()
    gs = gt.material(mats.steel())
    gt.cylinder(0.0060, k.HG_Y1 - k.REC_FRONT_Y + 0.020, segments=16,
                centre=(0.0, (k.HG_Y1 + k.REC_FRONT_Y + 0.020) / 2, k.BORE_Z + 0.019), axis="Y", mat=gs)
    gt.box((-0.0090, k.HG_Y1 + 0.002, k.BORE_Z - 0.006), (0.0090, k.HG_Y1 + 0.022, k.BORE_Z + 0.025), mat=gs)  # block
    c.finish(gt, "GasTube", bevel=0.0006, parent=rec)
    return rec


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    barrel = c.build_barrel(ctx, mats, 0.0085, k.REC_FRONT_Y - 0.010, k.BARREL_END_Y, k.BORE_Z, bore_r=0.0030)
    c.build_flash_hider(ctx, mats, 0.0105, k.BARREL_END_Y, k.HIDER_LEN, k.BORE_Z, parent=barrel)

    ctx.marker("Muzzle", (0.0, k.MUZZLE_Y, k.BORE_Z))
    ctx.marker("BarrelMount", (0.0, k.REC_FRONT_Y, k.BORE_Z))
    ctx.marker("Eject", (k.REC_HW, 0.030, k.BORE_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, k.SIGHT_RAIL_Y, k.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", k.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, k.UNDER_Y, k.BORE_Z - 0.0245 - 0.0057))
    ctx.marker("SideRail", (0.0225 + 0.0057, k.SIDE_Y, k.BORE_Z))
    stock_mount = ctx.marker("StockMount", k.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Handguard (y 0.162-0.292, bottom z 0.037), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.205, 0.025))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = k.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, k.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    k.build_mag(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    k.build_stock(ctx, mats, folded=False, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
