"""Graff-Lindqvist Ferret 9: boxy open-bolt 9 mm SMG, first-person model (B4-18).

About 32 cm long with the stock folded. Stamped steel box receiver with a ribbed top cover and a
cocking knob, 32-round stick magazine through the near-vertical grip, polymer lower handguard, short
barrel under a knurled barrel nut, folding stock folded under the receiver, grip safety in the back
strap.

Origin = firing-hand pivot on the grip (see _ferret.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``TopCover``, ``ReceiverDetails``, ``Handguard``, ``TriggerGroup``, ``Grip``),
``Barrel`` (+ ``BarrelNut``). Stock parts: ``SightRail/StockSight`` (flip aperture + front post,
``AimPoint``), ``Magwell/StockMagazine`` (32 rounds), ``StockMount/StockStock`` (folded stock).
"""

import math

import _common as c
import _ferret as f

ASSET_ID = "wpn_ferret_9"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.prism(c.chamfer_rect(f.REC_HW, f.REC_BOTTOM_Z, f.REC_TOP_Z - 0.008, 0.003), axis="Y", start=f.REC_REAR_Y,
             end=f.REC_FRONT_Y, mat=st)
    mb.box((-0.012, f.REC_REAR_Y - 0.008, 0.034), (0.012, f.REC_REAR_Y, 0.070), mat=st)       # rear plate
    rec = c.finish(mb, "Receiver", bevel=0.0012, segments=2)

    tc = ctx.builder()
    tm = tc.material(mats.matte())
    top = [(-f.REC_HW - 0.001, f.REC_TOP_Z - 0.010), (f.REC_HW + 0.001, f.REC_TOP_Z - 0.010),
           (f.REC_HW + 0.001, f.REC_TOP_Z - 0.004), (f.REC_HW - 0.006, f.REC_TOP_Z),
           (-f.REC_HW + 0.006, f.REC_TOP_Z), (-f.REC_HW - 0.001, f.REC_TOP_Z - 0.004)]
    tc.prism(top, axis="Y", start=f.REC_REAR_Y + 0.004, end=f.REC_FRONT_Y - 0.004, mat=tm)
    for i in range(6):                                                                      # stamped grip ribs
        y = 0.010 + i * 0.016
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * (f.REC_HW - 0.003), side * (f.REC_HW + 0.0016)))
            tc.box((lo, y, f.REC_TOP_Z - 0.008), (hi, y + 0.007, f.REC_TOP_Z - 0.002), mat=tm)
    tc.box((-0.0040, 0.060, f.REC_TOP_Z - 0.001), (0.0040, 0.130, f.REC_TOP_Z + 0.0015), mat=tm)   # knob slot
    tc.cylinder(0.0075, 0.012, segments=18, centre=(0.0, 0.105, f.REC_TOP_Z + 0.006), axis="Z", mat=tm)  # knob
    cover = c.finish(tc, "TopCover", bevel=0.0008, segments=1, parent=rec)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), f.RAIL_Y0, f.RAIL_Y1, f.REC_TOP_Z)
    c.finish(rl, "TopRail", bevel=0.0004, parent=cover)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    dt.box((f.REC_HW - 0.0005, 0.010, f.BORE_Z - 0.010), (f.REC_HW + 0.0004, 0.075, f.BORE_Z + 0.012), mat=dark)
    for side in (-1.0, 1.0):
        for y in (-0.090, -0.030, 0.140):
            dt.cylinder(0.0026, 0.0012, segments=10, centre=(side * (f.REC_HW + 0.0002), y, 0.030), axis="X", mat=s2)
        lo, hi = sorted((side * (f.REC_HW - 0.0003), side * (f.REC_HW + 0.0009)))
        dt.box((lo, f.REC_REAR_Y + 0.010, 0.040), (hi, -0.025, 0.046), mat=s2)                 # side press
    dt.cylinder(0.0050, 0.0026, segments=16, centre=(-f.REC_HW - 0.0012, -0.040, 0.034), axis="X", mat=s2)  # selector
    c.finish(dt, "ReceiverDetails", parent=rec)

    hg = ctx.builder()
    poly = hg.material(mats.polymer())
    prof = [(0.080, f.REC_BOTTOM_Z + 0.002), (f.REC_FRONT_Y, f.REC_BOTTOM_Z + 0.002), (f.REC_FRONT_Y, 0.010),
            (f.REC_FRONT_Y - 0.010, 0.000), (0.092, 0.000), (0.080, 0.012)]
    hg.prism(prof, axis="X", start=-f.REC_HW - 0.002, end=f.REC_HW + 0.002, mat=poly)
    for i in range(5):
        y = 0.096 + i * 0.010
        hg.box((-f.REC_HW - 0.0028, y, 0.004), (f.REC_HW + 0.0028, y + 0.004, 0.018), mat=poly)
    c.finish(hg, "Handguard", bevel=0.0015, segments=2, parent=rec)

    c.build_trigger_group(ctx, mats, f.GRIP_HALF_DEPTH + 0.002, 0.078, f.REC_BOTTOM_Z, -0.008, 0.040,
                          parent=rec)
    gp = ctx.builder()
    poly2 = gp.material(mats.polymer())
    zt = f.GRIP_TOP_Z
    grip = [(f.GRIP_HALF_DEPTH + f.GRIP_TAN * zt, zt), (f.GRIP_HALF_DEPTH + f.GRIP_TAN * f.GRIP_BOTTOM_Z, f.GRIP_BOTTOM_Z),
            (-f.GRIP_HALF_DEPTH + f.GRIP_TAN * f.GRIP_BOTTOM_Z, f.GRIP_BOTTOM_Z),
            (-f.GRIP_HALF_DEPTH + f.GRIP_TAN * -0.030 - 0.003, -0.030), (-f.GRIP_HALF_DEPTH + f.GRIP_TAN * zt, zt)]
    gp.prism(grip, axis="X", start=-f.GRIP_HALF_WIDTH, end=f.GRIP_HALF_WIDTH, mat=poly2)
    g = c.finish(gp, "Grip", bevel=0.0030, segments=3, parent=rec)
    gs = ctx.builder()
    sm = gs.material(mats.bare())
    gs.box((-0.0080, -f.GRIP_HALF_DEPTH - 0.004, -0.040), (0.0080, -f.GRIP_HALF_DEPTH + 0.002, 0.010), mat=sm)
    c.finish(gs, "GripSafety", bevel=0.0010, parent=g)
    gt = ctx.builder()
    gm = gt.material(mats.stipple())
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * (f.GRIP_HALF_WIDTH - 0.0004), side * (f.GRIP_HALF_WIDTH + 0.0006)))
        for i in range(8):
            z = -0.068 + i * 0.010
            gt.box((lo, -0.014 + f.GRIP_TAN * z, z), (hi, 0.014 + f.GRIP_TAN * z, z + 0.005), mat=gm)
    c.finish(gt, "GripTexture", parent=g)
    return rec


def _barrel(ctx, mats):
    barrel = c.build_barrel(ctx, mats, 0.0080, f.REC_FRONT_Y - 0.010, f.BARREL_END_Y, f.BORE_Z, bore_r=0.0047,
                            segments=20)
    nut = ctx.builder()
    nm = nut.material(mats.matte())
    nut.cylinder(0.0160, 0.020, segments=24, centre=(0.0, f.REC_FRONT_Y + 0.009, f.BORE_Z), axis="Y", mat=nm)
    for i in range(12):
        a = 2 * math.pi * i / 12
        x, z = math.cos(a) * 0.0160, f.BORE_Z + math.sin(a) * 0.0160
        nut.box((x - 0.0012, f.REC_FRONT_Y + 0.001, z - 0.0012), (x + 0.0012, f.REC_FRONT_Y + 0.017, z + 0.0012), mat=nm)
    c.finish(nut, "BarrelNut", bevel=0.0005, parent=barrel)
    return barrel


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    _barrel(ctx, mats)

    ctx.marker("Muzzle", (0.0, f.MUZZLE_Y, f.BORE_Z))
    ctx.marker("BarrelMount", (0.0, f.REC_FRONT_Y, f.BORE_Z))
    ctx.marker("Eject", (f.REC_HW, 0.042, f.BORE_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, f.SIGHT_RAIL_Y, f.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", f.MAGWELL_POS, rotation_euler=f.MAGWELL_ROT)
    ctx.marker("Underbarrel", (0.0, f.UNDER_Y, 0.000))
    ctx.marker("SideRail", (f.REC_HW + 0.002, f.SIDE_Y, f.BORE_Z - 0.010))
    stock_mount = ctx.marker("StockMount", f.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Handguard (y 0.080-0.150, bottom z 0.000), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.103, -0.012))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = f.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, f.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    f.build_mag(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    f.build_folded_stock(ctx, mats, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
