"""Tillman Ironworks Mule 12: compact 12-gauge pump shotgun (secondary), first-person model (B4-12).

About 52 cm long as issued (no stock). Blued steel receiver with a short optics rail, 275 mm barrel,
five-shell tube under it with a barrel band, black polymer ribbed pump and a raked polymer pistol grip.
The short, stockless sibling of the Plowman 12.

Origin = firing-hand pivot on the pistol grip (see _mule.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``ReceiverDetails``, ``TopRail``, ``TriggerGroup``, ``Grip``), ``Barrel``
(+ ``Bead``), ``Pump`` (separate: ENV A slides it along local +Z). Stock parts: ``SightRail/StockSight``
(ghost ring + front blade, ``AimPoint``), ``Magwell/StockMagazine`` (five-shell tube).
"""

import math

import _common as c
import _mule as p

ASSET_ID = "wpn_mule_12"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    hw = p.REC_HW
    cross = [(-hw, p.REC_BOTTOM_Z), (hw, p.REC_BOTTOM_Z), (hw, p.REC_TOP_Z - 0.010), (hw - 0.004, p.REC_TOP_Z - 0.003),
             (hw - 0.009, p.REC_TOP_Z), (-hw + 0.009, p.REC_TOP_Z), (-hw + 0.004, p.REC_TOP_Z - 0.003),
             (-hw, p.REC_TOP_Z - 0.010)]
    mb.prism(cross, axis="Y", start=p.REC_REAR_Y, end=p.REC_FRONT_Y, mat=st)
    rec = c.finish(mb, "Receiver", bevel=0.0012, segments=2)
    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.steel())
    dt.box((hw - 0.0005, 0.040, 0.034), (hw + 0.0004, 0.110, 0.074), mat=dark)          # ejection port
    dt.box((hw - 0.0002, 0.052, 0.040), (hw + 0.0010, 0.098, 0.068), mat=s2)            # bolt face
    dt.box((-0.0100, 0.060, p.REC_BOTTOM_Z - 0.0004), (0.0100, 0.150, p.REC_BOTTOM_Z + 0.0004), mat=dark)
    for side in (-1.0, 1.0):
        for y in (0.000, 0.070):
            dt.cylinder(0.0030, 0.001, segments=12, centre=(side * (hw + 0.0002), y, 0.024), axis="X", mat=s2)
    c.finish(dt, "ReceiverDetails", parent=rec)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), p.RAIL_Y0, p.RAIL_Y1, p.REC_TOP_Z - 0.001)
    c.finish(rl, "TopRail", bevel=0.0004, parent=rec)
    tg = ctx.builder()
    tm = tg.material(mats.steel())
    outer = [(0.008, p.REC_BOTTOM_Z + 0.002), (0.080, p.REC_BOTTOM_Z + 0.002), (0.078, -0.004), (0.066, -0.016),
             (0.018, -0.016), (0.008, -0.006)]
    hole = [(0.016, p.REC_BOTTOM_Z - 0.001), (0.070, p.REC_BOTTOM_Z - 0.001), (0.068, -0.004), (0.062, -0.010),
            (0.022, -0.010), (0.016, -0.004)]
    tg.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0065, end=0.0065, mat=tm)
    pf, pb = [], []
    for i in range(8):
        s = i / 7
        z = p.REC_BOTTOM_Z - s * 0.020
        yc = 0.040 + 0.006 * s * s
        pf.append((yc + 0.0020, z))
        pb.append((yc - 0.0020, z))
    tg.prism(pf + list(reversed(pb)), axis="X", start=-0.0032, end=0.0032, mat=tm)
    tg.cylinder(0.0045, 0.030, segments=16, centre=(0.0, 0.074, 0.004), axis="X", mat=tm)   # cross-bolt safety
    c.finish(tg, "TriggerGroup", bevel=0.0007, segments=1, parent=rec)
    gp = ctx.builder()
    poly = gp.material(mats.polymer())
    gp.prism(c.raked_grip_profile(p.GRIP_TOP_Z, p.GRIP_BOTTOM_Z, 0.0175, p.GRIP_ANGLE_DEG, palm_swell=0.0030,
                                  finger_bumps=3), axis="X", start=-0.0140, end=0.0140, mat=poly)
    gp.box((-0.0130, -0.036, 0.016), (0.0130, 0.010, p.REC_BOTTOM_Z + 0.004), mat=poly)
    gp.box((-0.0130, p.REC_REAR_Y - 0.004, 0.016), (0.0130, -0.020, 0.070), mat=poly)   # rear cap / tang
    grip = c.finish(gp, "Grip", bevel=0.0030, segments=3, parent=rec)
    gt = ctx.builder()
    gm = gt.material(mats.stipple())
    for side in (-1.0, 1.0):
        x = side * 0.0140
        for r in range(9):
            z = -0.062 + r * 0.008
            y = -0.0175 + p.GRIP_TAN * z + 0.006
            while y < 0.0175 + p.GRIP_TAN * z - 0.007:
                c.pyramid(gt.bm, c.Vector((x, y, z)), c.Vector((0, 1, 0)), c.Vector((0, 0, 1)), c.Vector((side, 0, 0)),
                          0.0016, 0.0006, gm)
                y += 0.0070
    c.finish(gt, "GripTexture", parent=grip)
    return rec


def _barrel(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    c.ring_y(mb, p.BARREL_R, 0.0092, p.REC_FRONT_Y, p.BARREL_END_Y, p.BORE_Z, st, segments=32)
    mb.cylinder(0.0145, 0.016, segments=32, centre=(0.0, p.REC_FRONT_Y + 0.008, p.BORE_Z), axis="Y", mat=st)
    mb.cylinder(p.BARREL_R + 0.0012, 0.014, segments=32, centre=(0.0, p.BARREL_END_Y - 0.007, p.BORE_Z), axis="Y",
                mat=st)                                                                  # muzzle band
    barrel = c.finish(mb, "Barrel", bevel=0.0005, segments=1)
    bd = ctx.builder()
    bd.cylinder(0.0017, 0.003, segments=12, centre=(0.0, p.BARREL_END_Y - 0.006, p.BORE_Z + p.BARREL_R + 0.0025),
                axis="Z", mat=bd.material(mats.brass()))
    c.finish(bd, "Bead", parent=barrel)
    return barrel


def _pump(ctx, mats):
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    zc = p.TUBE_Z - 0.002
    outer = c.rounded_rect(0.0230, 0.0210, 0.012, 0.0, zc, corner_segments=4)
    hole = list(reversed(c.circle(p.TUBE_R + 0.0005, 24, 0.0, p.TUBE_Z)))
    mb.prism(outer, holes=[hole], axis="Y", start=p.PUMP_Y0, end=p.PUMP_Y1, mat=poly)
    # front and rear lips (hand stops)
    for y0, y1 in ((p.PUMP_Y0, p.PUMP_Y0 + 0.010), (p.PUMP_Y1 - 0.010, p.PUMP_Y1)):
        mb.prism(c.rounded_rect(0.0245, 0.0240, 0.012, 0.0, zc - 0.003, corner_segments=4), holes=[hole], axis="Y",
                 start=y0, end=y1, mat=poly)
    pump = c.finish(mb, "Pump", bevel=0.0020, segments=2)
    rb = ctx.builder()
    rm = rb.material(mats.stipple())
    for i in range(7):
        y = p.PUMP_Y0 + 0.020 + i * 0.015
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * 0.0228, side * 0.0240))
            rb.box((lo, y, zc - 0.014), (hi, y + 0.007, zc + 0.012), mat=rm)
        rb.box((-0.016, y, zc - 0.0222), (0.016, y + 0.007, zc - 0.0205), mat=rm)
    c.finish(rb, "PumpRibs", parent=pump)
    ab = ctx.builder()
    am = ab.material(mats.steel())
    for side in (-1.0, 1.0):                                          # action bars back to the receiver
        x0, x1 = sorted((side * 0.0080, side * 0.0110))
        ab.box((x0, p.REC_FRONT_Y - 0.010, p.TUBE_Z + 0.004), (x1, p.PUMP_Y0 + 0.010, p.TUBE_Z + 0.009), mat=am)
    c.finish(ab, "ActionBars", bevel=0.0004, parent=pump)
    return pump


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    _barrel(ctx, mats)
    _pump(ctx, mats)

    ctx.marker("Muzzle", (0.0, p.MUZZLE_Y, p.BORE_Z))
    ctx.marker("BarrelMount", (0.0, p.REC_FRONT_Y, p.BORE_Z))
    ctx.marker("Eject", (p.REC_HW, 0.075, p.BORE_Z - 0.004), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, p.SIGHT_RAIL_Y, p.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", p.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, p.UNDER_Y, p.TUBE_Z - 0.022))
    ctx.marker("SideRail", (0.0230, p.UNDER_Y, p.TUBE_Z))
    ctx.marker("StockMount", p.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Pump (y 0.205-0.345, bottom z 0.009), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.252, -0.003))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _body, aim = p.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, p.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    p.build_tube(ctx, mats, extended=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
