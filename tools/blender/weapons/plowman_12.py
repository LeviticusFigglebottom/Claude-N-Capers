"""Tillman Ironworks Plowman 12: 12-gauge pump-action shotgun, first-person model (B4-04).

About 1.1 m long. Blued steel receiver with a short optics rail, 480 mm barrel, six-shell tube
magazine, walnut pump and buttstock with a rubber pad. Classic field-gun silhouette, distinct from
the rifles: no pistol grip, long tube under the barrel, ribbed wooden pump.

Origin = firing-hand pivot at the middle of the stock's wrist (see _plowman.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``ReceiverDetails``, ``TopRail``, ``TriggerGroup``), ``Barrel``,
``Pump`` (separate: ENV A slides it along local +Z on each pump). Stock parts:
``SightRail/StockSight`` (ghost ring + front blade, ``AimPoint``), ``Magwell/StockMagazine``
(standard tube), ``StockMount/StockStock`` (walnut buttstock incl. the wrist).
"""

import math

import _common as c
import _plowman as p

ASSET_ID = "wpn_plowman_12"
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
    dt.box((hw - 0.0005, 0.095, 0.034), (hw + 0.0004, 0.175, 0.072), mat=dark)       # ejection port
    dt.box((hw - 0.0002, 0.110, 0.040), (hw + 0.0010, 0.160, 0.066), mat=s2)         # bolt face in port
    dt.box((-0.0100, 0.118, p.REC_BOTTOM_Z - 0.0004), (0.0100, 0.226, p.REC_BOTTOM_Z + 0.0004), mat=dark)  # port
    for side in (-1.0, 1.0):                                                          # trigger-group pins
        for y in (0.060, 0.120):
            dt.cylinder(0.0030, 0.001, segments=12, centre=(side * (hw + 0.0002), y, 0.020), axis="X", mat=s2)
    c.finish(dt, "ReceiverDetails", parent=rec)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), p.RAIL_Y0, p.RAIL_Y1, p.REC_TOP_Z - 0.001)
    c.finish(rl, "TopRail", bevel=0.0004, parent=rec)
    tg = ctx.builder()
    tm = tg.material(mats.steel())
    outer = [(0.036, p.REC_BOTTOM_Z + 0.002), (0.122, p.REC_BOTTOM_Z + 0.002), (0.120, -0.006), (0.106, -0.022),
             (0.050, -0.022), (0.036, -0.010)]
    hole = [(0.046, p.REC_BOTTOM_Z - 0.001), (0.108, p.REC_BOTTOM_Z - 0.001), (0.106, -0.008), (0.098, -0.016),
            (0.054, -0.016), (0.046, -0.008)]
    tg.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0065, end=0.0065, mat=tm)
    pf, pb = [], []
    for i in range(8):
        s = i / 7
        z = p.REC_BOTTOM_Z - s * 0.020
        yc = 0.070 + 0.006 * s * s
        pf.append((yc + 0.0020, z))
        pb.append((yc - 0.0020, z))
    tg.prism(pf + list(reversed(pb)), axis="X", start=-0.0032, end=0.0032, mat=tm)
    tg.cylinder(0.0045, 0.030, segments=16, centre=(0.0, 0.115, 0.000), axis="X", mat=tm)  # cross-bolt safety
    c.finish(tg, "TriggerGroup", bevel=0.0007, segments=1, parent=rec)
    return rec


def _barrel(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    c.ring_y(mb, p.BARREL_R, 0.0092, p.REC_FRONT_Y, p.BARREL_END_Y, p.BORE_Z, st, segments=32)
    mb.cylinder(0.0145, 0.016, segments=32, centre=(0.0, p.REC_FRONT_Y + 0.008, p.BORE_Z), axis="Y", mat=st)  # collar
    # ventilated rib on top: posts + flat
    rib_z = p.BORE_Z + p.BARREL_R
    for i in range(12):
        y = p.REC_FRONT_Y + 0.030 + i * 0.038
        mb.box((-0.0028, y, rib_z - 0.001), (0.0028, y + 0.008, rib_z + 0.0045), mat=st)
    mb.box((-0.0040, p.REC_FRONT_Y + 0.020, rib_z + 0.0045), (0.0040, p.BARREL_END_Y - 0.004, rib_z + 0.0070), mat=st)
    barrel = c.finish(mb, "Barrel", bevel=0.0005, segments=1)
    bd = ctx.builder()
    bd.cylinder(0.0017, 0.003, segments=12, centre=(0.0, p.BARREL_END_Y - 0.006, rib_z + 0.0085), axis="Z",
                mat=bd.material(mats.brass()))
    c.finish(bd, "Bead", parent=barrel)
    return barrel


def _pump(ctx, mats):
    mb = ctx.builder()
    wood = mb.material(mats.wood())
    zc = p.TUBE_Z - 0.002
    outer = c.rounded_rect(0.0235, 0.0215, 0.013, 0.0, zc, corner_segments=4)
    hole = list(reversed(c.circle(p.TUBE_R + 0.0005, 24, 0.0, p.TUBE_Z)))
    mb.prism(outer, holes=[hole], axis="Y", start=p.PUMP_Y0, end=p.PUMP_Y1, mat=wood)
    pump = c.finish(mb, "Pump", bevel=0.0025, segments=2)
    rb = ctx.builder()
    rm = rb.material(mats.wood())
    for i in range(9):                                   # grip ribs around the pump
        y = p.PUMP_Y0 + 0.030 + i * 0.014
        rb.prism(c.rounded_rect(0.0242, 0.0222, 0.013, 0.0, zc, corner_segments=4), axis="Y", start=y,
                 end=y + 0.006, mat=rm)
    c.finish(rb, "PumpRibs", bevel=0.0008, parent=pump)
    ab = ctx.builder()
    am = ab.material(mats.steel())
    for side in (-1.0, 1.0):                              # action bars back to the receiver
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
    ctx.marker("Eject", (p.REC_HW, 0.135, p.BORE_Z - 0.004), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, p.SIGHT_RAIL_Y, p.RAIL_TOP_Z - 0.001))
    magwell = ctx.marker("Magwell", p.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, p.UNDER_Y, p.TUBE_Z - 0.022))
    ctx.marker("SideRail", (0.0225, p.UNDER_Y, p.TUBE_Z))
    stock_mount = ctx.marker("StockMount", p.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Pump (y 0.290-0.500, bottom z 0.010), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.360, -0.002))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _body, aim = p.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, -0.040, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    p.build_tube(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    p.build_stock(ctx, mats, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: middle of the stock wrist (grip centre plane)"
