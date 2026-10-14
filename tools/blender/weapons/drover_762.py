"""Graff-Lindqvist Drover 762: long-stroke 7.62 mm battle rifle, first-person model (B4-12).

About 1.0 m long. Stamped steel receiver with a railed top cover, walnut handguard (upper and lower),
pistol grip and fixed stock, gas tube over the barrel, front sight block and a slant muzzle brake,
deeply curved steel 30-round magazine. Heavier and older-looking than the Brannock Corsair.

Origin = firing-hand pivot on the pistol grip (see _drover.py). Forward = Godot -Z, up = Godot +Y.

Node tree: ``Receiver`` (+ ``TopCover``, ``CoverRail``, ``ReceiverDetails``, ``Grip``, ``Trigger``,
``ChargingHandle``), ``Handguard`` (+ ``UpperGuard``, ``HandguardRails``), ``Barrel`` (+ ``GasBlock``,
``Brake``). Stock parts: ``SightRail/StockSight`` (flip-up rear + barrel post, ``AimPoint``),
``Magwell/StockMagazine`` (30 rounds), ``StockMount/StockStock`` (walnut stock).
"""

import math

import _common as c
import _drover as d

ASSET_ID = "wpn_drover_762"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    hw = d.REC_HW
    # lower receiver body (side profile) with the magwell and the trigger guard
    prof = [(d.REC_REAR_Y, 0.070), (d.REC_FRONT_Y, 0.070), (d.REC_FRONT_Y, 0.034), (d.REC_FRONT_Y - 0.012, d.REC_BOTTOM_Z),
            (d.MAGWELL_Y1 + 0.004, d.REC_BOTTOM_Z), (d.MAGWELL_Y1 + 0.004, d.REC_BOTTOM_Z - 0.006),
            (d.MAGWELL_Y0 - 0.004, d.REC_BOTTOM_Z - 0.006), (d.MAGWELL_Y0 - 0.004, d.REC_BOTTOM_Z),
            (0.030, d.REC_BOTTOM_Z), (0.010, d.GRIP_TOP_Z), (-0.032, d.GRIP_TOP_Z), (d.REC_REAR_Y, 0.034)]
    mb.prism(prof, axis="X", start=-hw, end=hw, mat=st)
    gy = 0.012
    outer = [(gy, d.REC_BOTTOM_Z + 0.002), (d.MAGWELL_Y0 - 0.004, d.REC_BOTTOM_Z + 0.002),
             (d.MAGWELL_Y0 - 0.006, -0.004), (gy + 0.010, -0.010), (gy, -0.004)]
    hole = [(gy + 0.008, d.REC_BOTTOM_Z - 0.002), (d.MAGWELL_Y0 - 0.010, d.REC_BOTTOM_Z - 0.002),
            (d.MAGWELL_Y0 - 0.011, -0.001), (gy + 0.012, -0.005), (gy + 0.006, -0.001)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0055, end=0.0055, mat=st)
    rec = c.finish(mb, "Receiver", bevel=0.0012, segments=2)

    # top cover: rounded stamped cover with a rear step
    tc = ctx.builder()
    tm = tc.material(mats.steel())
    cross = [(-hw, 0.069), (hw, 0.069), (hw, d.REC_TOP_Z - 0.010), (hw - 0.004, d.REC_TOP_Z - 0.003),
             (hw - 0.009, d.REC_TOP_Z), (-hw + 0.009, d.REC_TOP_Z), (-hw + 0.004, d.REC_TOP_Z - 0.003),
             (-hw, d.REC_TOP_Z - 0.010)]
    tc.prism(cross, axis="Y", start=d.REC_REAR_Y + 0.004, end=d.REC_FRONT_Y - 0.010, mat=tm)
    for y in (0.000, 0.060, 0.120):                              # stamped stiffening ribs
        tc.box((-hw - 0.0006, y, 0.074), (hw + 0.0006, y + 0.006, d.REC_TOP_Z - 0.012), mat=tm)
    cover = c.finish(tc, "TopCover", bevel=0.0010, segments=2, parent=rec)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), d.RAIL_Y0, d.RAIL_Y1, d.RAIL_BASE_Z)
    c.finish(rl, "CoverRail", bevel=0.0004, parent=cover)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    dt.box((hw - 0.0005, 0.030, 0.060), (hw + 0.0004, 0.115, 0.082), mat=dark)          # ejection port
    dt.box((hw - 0.0002, 0.050, 0.064), (hw + 0.0010, 0.100, 0.078), mat=s2)            # bolt carrier
    for side in (-1.0, 1.0):                                                              # rivets
        for y in (-0.050, -0.010, 0.170, 0.190):
            for z in (0.030, 0.058):
                dt.cylinder(0.0026, 0.0010, segments=10, centre=(side * (hw + 0.0003), y, z), axis="X", mat=s2)
        lo, hi = sorted((side * (hw - 0.0003), side * (hw + 0.0006)))
        dt.box((lo, d.MAGWELL_Y0 - 0.002, 0.024), (hi, d.MAGWELL_Y1 + 0.002, 0.050), mat=dark)   # mag-well dimple
    # big safety lever on the right
    dt.box((hw + 0.0004, 0.015, 0.062), (hw + 0.0024, 0.105, 0.070), mat=s2)
    dt.box((hw + 0.0004, 0.015, 0.046), (hw + 0.0024, 0.026, 0.066), mat=s2)
    # paddle mag release behind the magwell
    dt.box((-0.0060, d.MAGWELL_Y0 - 0.014, d.REC_BOTTOM_Z - 0.012), (0.0060, d.MAGWELL_Y0 - 0.006,
           d.REC_BOTTOM_Z + 0.001), mat=s2)
    c.finish(dt, "ReceiverDetails", bevel=0.0002, parent=rec)

    gp = ctx.builder()
    wood = gp.material(mats.wood())
    gp.prism(c.raked_grip_profile(d.GRIP_TOP_Z, d.GRIP_BOTTOM_Z, d.GRIP_HALF_DEPTH, d.GRIP_ANGLE_DEG,
                                  palm_swell=0.0030, finger_bumps=0),
             axis="X", start=-d.GRIP_HALF_WIDTH, end=d.GRIP_HALF_WIDTH, mat=wood)
    gp.box((-0.0120, -0.034, 0.016), (0.0120, 0.008, d.REC_BOTTOM_Z + 0.002), mat=wood)
    c.taper_x(gp, lambda y, z: 0.86 + 0.14 * min(1.0, max(0.0, (z + 0.076) / 0.05)))
    grip = c.finish(gp, "Grip", bevel=0.0030, segments=3)
    gs = ctx.builder()                                      # grip-screw escutcheon
    gs.cylinder(0.0032, 0.0012, segments=12, centre=(-(d.GRIP_HALF_WIDTH - 0.0015), d.GRIP_TAN * -0.020, -0.020),
                axis="X", mat=gs.material(mats.bare()))
    c.finish(gs, "GripScrew", parent=grip)

    tr = ctx.builder()
    ts = tr.material(mats.steel())
    pf, pb = [], []
    for i in range(8):
        s = i / 7
        z = d.REC_BOTTOM_Z - 0.002 - s * 0.020
        yc = 0.044 + 0.006 * s * s
        pf.append((yc + 0.0020, z))
        pb.append((yc - 0.0020, z))
    tr.prism(pf + list(reversed(pb)), axis="X", start=-0.0030, end=0.0030, mat=ts)
    c.finish(tr, "Trigger", bevel=0.0005, parent=rec)

    ch = ctx.builder()
    cm = ch.material(mats.bare())
    ch.box((hw, 0.105, 0.075), (hw + 0.004, 0.150, 0.081), mat=cm)                        # handle on the carrier
    ch.cylinder(0.0050, 0.016, segments=16, centre=(hw + 0.010, 0.140, 0.078), axis="X", mat=cm)
    c.finish(ch, "ChargingHandle", bevel=0.0006, parent=rec)
    return rec


def _handguard(ctx, mats):
    mb = ctx.builder()
    wood = mb.material(mats.wood())
    # lower handguard: U-shaped walnut around the barrel
    outer = c.rounded_rect(d.HG_HW, (d.BORE_Z + 0.012 - d.HG_BOTTOM_Z) / 2, 0.010, 0.0,
                           (d.BORE_Z + 0.012 + d.HG_BOTTOM_Z) / 2, corner_segments=3)
    hole = list(reversed(c.circle(0.0140, 24, 0.0, d.BORE_Z)))
    mb.prism(outer, holes=[hole], axis="Y", start=d.HG_Y0, end=d.HG_Y1, mat=wood)
    for i in range(3):                                       # finger grooves
        y = d.HG_Y0 + 0.050 + i * 0.030
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * (d.HG_HW - 0.0015), side * (d.HG_HW + 0.0004)))
            mb.box((lo, y, 0.050), (hi, y + 0.012, 0.064), mat=wood)
    c.taper_x(mb, lambda y, z: 0.92 + 0.08 * min(1.0, max(0.0, (z - d.HG_BOTTOM_Z) / 0.04)))
    hg = c.finish(mb, "Handguard", bevel=0.0030, segments=2)
    ug = ctx.builder()
    uw = ug.material(mats.wood())
    us = ug.material(mats.steel())
    ug.prism(c.rounded_rect(0.0150, 0.0105, 0.008, 0.0, d.GAS_Z, corner_segments=3), axis="Y", start=d.HG_Y0 + 0.010,
             end=d.HG_Y1 - 0.040, mat=uw)
    ug.cylinder(0.0075, d.GAS_BLOCK_Y - d.HG_Y1 + 0.040, segments=16,
                centre=(0.0, (d.GAS_BLOCK_Y + d.HG_Y1 - 0.040) / 2, d.GAS_Z), axis="Y", mat=us)   # gas tube
    ug.box((-0.0160, d.HG_Y1 - 0.006, d.HG_BOTTOM_Z), (0.0160, d.HG_Y1 + 0.004, d.GAS_Z + 0.004), mat=us)  # retainer
    c.finish(ug, "UpperGuard", bevel=0.0020, segments=2, parent=hg)
    rl = ctx.builder()
    ra = rl.material(mats.alu())
    c.rail_side(rl, ra, d.UNDER_Y - 0.035, d.UNDER_Y + 0.040, 0.0, d.HG_BOTTOM_Z + 0.0005, 0.0)
    c.rail_side(rl, ra, d.SIDE_Y - 0.025, d.SIDE_Y + 0.030, d.HG_HW - 0.0010, d.BORE_Z - 0.006, 1.0)
    c.finish(rl, "HandguardRails", bevel=0.0004, parent=hg)
    return hg


def _barrel(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(d.BARREL_R, d.BARREL_END_Y - d.REC_FRONT_Y, segments=24,
                centre=(0.0, (d.BARREL_END_Y + d.REC_FRONT_Y) / 2, d.BORE_Z), axis="Y", mat=st)
    mb.cylinder(0.0130, 0.020, segments=24, centre=(0.0, d.REC_FRONT_Y + 0.006, d.BORE_Z), axis="Y", mat=st)  # trunnion
    barrel = c.finish(mb, "Barrel", bevel=0.0005, segments=1)
    gb = ctx.builder()
    gm = gb.material(mats.steel())
    # gas block (barrel to gas tube) and the front sight block
    gb.box((-0.0130, d.GAS_BLOCK_Y - 0.014, d.BORE_Z - 0.012), (0.0130, d.GAS_BLOCK_Y + 0.014, d.GAS_Z + 0.006), mat=gm)
    gb.cylinder(0.0080, 0.020, segments=16, centre=(0.0, d.GAS_BLOCK_Y - 0.002, d.GAS_Z), axis="Y", mat=gm)
    fy = d.FRONT_SIGHT_Y
    gb.box((-0.0110, fy - 0.016, d.BORE_Z - 0.010), (0.0110, fy + 0.012, d.BORE_Z + 0.016), mat=gm)
    gb.box((-0.0080, fy - 0.004, d.BORE_Z - 0.032), (0.0080, fy + 0.006, d.BORE_Z - 0.010), mat=gm)   # bayonet lug
    c.finish(gb, "GasBlock", bevel=0.0010, segments=1, parent=barrel)
    br = ctx.builder()
    bm = br.material(mats.steel())
    dark = br.material(mats.polymer())
    y0, y1 = d.BARREL_END_Y - 0.002, d.BARREL_END_Y + d.BRAKE_LEN
    c.ring_y(br, 0.0120, 0.0058, y0, y1, d.BORE_Z, bm, segments=24)
    # slant cut (taller at the bottom) suggested by a dark wedge, plus two side ports
    zb = d.BORE_Z
    br.prism([(y1 - 0.010, zb - 0.0125), (y1 + 0.0004, zb - 0.0125), (y1 + 0.0004, zb - 0.0035)], axis="X",
             start=-0.012, end=0.012, mat=dark)
    for i in range(2):
        y = y0 + 0.012 + i * 0.012
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * 0.0116, side * 0.0126))
            br.box((lo, y, d.BORE_Z - 0.0045), (hi, y + 0.007, d.BORE_Z + 0.0045), mat=dark)
    c.finish(br, "Brake", bevel=0.0006, segments=1, parent=barrel)
    return barrel


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    _handguard(ctx, mats)
    _barrel(ctx, mats)

    ctx.marker("Muzzle", (0.0, d.MUZZLE_Y, d.BORE_Z))
    ctx.marker("BarrelMount", (0.0, d.REC_FRONT_Y, d.BORE_Z))
    ctx.marker("Eject", (d.REC_HW, 0.075, d.BORE_Z - 0.002), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, d.SIGHT_RAIL_Y, d.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", d.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, d.UNDER_Y, d.HG_BOTTOM_Z - 0.0057))
    ctx.marker("SideRail", (d.HG_HW + 0.0050, d.SIDE_Y, d.BORE_Z - 0.006))
    stock_mount = ctx.marker("StockMount", d.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Handguard (y 0.211-0.395, bottom z 0.034), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.272, 0.022))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _body, aim = d.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, d.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    d.build_mag(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    d.build_stock(ctx, mats, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
