"""Brannock Hornet 9: 9 mm blowback submachine gun, first-person model (B4-04).

Boxy one-piece polymer receiver with an integral grip and trigger guard, short threaded barrel,
straight 30-round magazine, skeleton stock that folds to the right side. About 53 cm long with the
stock extended, 28 cm folded.

Origin = firing-hand pivot on the grip (see _hornet.py). Forward = Godot -Z, up = Godot +Y.

Node tree: ``Receiver`` (+ ``ReceiverTexture``, ``TopRail``, ``Rails``, ``Trigger``, ``Controls``),
``Barrel``. Markers per contracts/visual_slots.md. Stock parts: ``SightRail/StockSight`` (irons,
``AimPoint``), ``Magwell/StockMagazine``, ``StockMount/StockStock`` (extended skeleton stock).
"""

import math

import _common as c
import _hornet as h

ASSET_ID = "wpn_hornet_9"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    y0, y1 = h.BODY_REAR_Y, h.BODY_FRONT_Y
    top = h.BODY_TOP_Z
    prof = [(y0, top - 0.004), (y0 + 0.004, top), (y1 - 0.006, top), (y1, top - 0.006), (y1, 0.040),
            (y1 - 0.010, 0.032), (h.MAGWELL_Y1 + 0.006, 0.032), (h.MAGWELL_Y1 + 0.004, h.MAGWELL_BOTTOM_Z),
            (h.MAGWELL_Y0 - 0.004, h.MAGWELL_BOTTOM_Z), (h.MAGWELL_Y0 - 0.006, 0.026), (0.024, 0.026),
            (-0.030, 0.026), (-0.050, 0.036), (y0, 0.046)]
    mb.prism(prof, axis="X", start=-h.BODY_HW, end=h.BODY_HW, mat=poly)
    # integral grip
    mb.prism(c.raked_grip_profile(h.GRIP_TOP_Z + 0.004, h.GRIP_BOTTOM_Z, h.GRIP_HALF_DEPTH, h.GRIP_ANGLE_DEG,
                                  palm_swell=0.003, finger_bumps=3),
             axis="X", start=-h.GRIP_HALF_WIDTH, end=h.GRIP_HALF_WIDTH, mat=poly)
    # trigger guard (integral, square)
    gy = h.GRIP_HALF_DEPTH + h.GRIP_TAN * 0.0 - 0.002
    outer = [(gy, 0.028), (h.MAGWELL_Y0 - 0.002, 0.028), (h.MAGWELL_Y0 - 0.002, -0.008), (gy + 0.004, -0.008),
             (gy - 0.002, -0.002)]
    hole = [(gy + 0.008, 0.026), (h.MAGWELL_Y0 - 0.008, 0.026), (h.MAGWELL_Y0 - 0.008, -0.003),
            (gy + 0.008, -0.003)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0065, end=0.0065, mat=poly)
    rec = c.finish(mb, "Receiver", bevel=0.0028, segments=3)

    # texture: grip panels, front grip grooves, receiver seam, ejection port
    tx = ctx.builder()
    sm = tx.material(mats.stipple())
    st = tx.material(mats.steel())
    for side in (-1.0, 1.0):
        x = side * (h.GRIP_HALF_WIDTH - 0.0002)
        for r in range(12):
            z = -0.058 + r * 0.0050
            yb = -h.GRIP_HALF_DEPTH + h.GRIP_TAN * z + 0.006
            yf = h.GRIP_HALF_DEPTH + h.GRIP_TAN * z - 0.006
            yy = yb + (0.0025 if r % 2 else 0.0)
            while yy < yf:
                c.pyramid(tx.bm, c.Vector((x, yy, z)), c.Vector((0, 1, 0)), c.Vector((0, 0, 1)),
                          c.Vector((side, 0, 0)), 0.0012, 0.0005, sm)
                yy += 0.005
        xo = side * (h.BODY_HW + 0.0002)
        lo, hi = sorted((xo, side * (h.BODY_HW - 0.0006)))
        for i in range(7):                                      # front grip grooves
            y = 0.136 + i * 0.009
            tx.box((lo, y, 0.036), (hi, y + 0.004, 0.060), mat=sm)
        tx.box((lo, h.BODY_REAR_Y + 0.010, 0.062), (hi, h.BODY_FRONT_Y - 0.012, 0.064), mat=sm)  # seam line
    tx.box((h.BODY_HW - 0.0005, 0.030, 0.068), (h.BODY_HW + 0.0004, 0.074, 0.086), mat=st)       # ejection port
    c.finish(tx, "ReceiverTexture", parent=rec)

    rl = ctx.builder()
    ra = rl.material(mats.alu())
    c.picatinny(rl, ra, h.BODY_REAR_Y + 0.010, h.BODY_FRONT_Y - 0.008, h.BODY_TOP_Z)
    c.finish(rl, "TopRail", bevel=0.0004, parent=rec)
    sr = ctx.builder()
    sa = sr.material(mats.alu())
    c.rail_side(sr, sa, h.UNDER_Y - 0.025, h.UNDER_Y + 0.030, 0.0, h.UNDER_Z + 0.0005, 0.0)
    c.rail_side(sr, sa, h.SIDE_Y - 0.020, h.SIDE_Y + 0.025, h.BODY_HW - 0.0005, h.BORE_Z - 0.006, 1.0)
    c.finish(sr, "Rails", bevel=0.0004, parent=rec)

    tr = ctx.builder()
    ts = tr.material(mats.steel())
    pf, pb = [], []
    for i in range(8):
        s = i / 7
        z = 0.026 - s * 0.020
        yc = 0.038 + 0.006 * s * s
        pf.append((yc + 0.0018, z))
        pb.append((yc - 0.0018, z))
    tr.prism(pf + list(reversed(pb)), axis="X", start=-0.0030, end=0.0030, mat=ts)
    c.finish(tr, "Trigger", bevel=0.0005, parent=rec)
    ct = ctx.builder()
    cs = ct.material(mats.steel())
    ct.cylinder(0.0060, 0.003, segments=20, centre=(-h.BODY_HW - 0.0010, 0.002, 0.044), axis="X", mat=cs)   # selector
    ct.box((-h.BODY_HW - 0.0026, 0.000, 0.042), (-h.BODY_HW - 0.0006, 0.018, 0.047), mat=cs)
    ct.box((-0.0060, h.MAGWELL_Y1 + 0.004, -0.004), (0.0060, h.MAGWELL_Y1 + 0.012, 0.010), mat=cs)        # paddle release
    # cocking handle on the left front, in its channel
    ct.box((-h.BODY_HW - 0.0004, 0.120, 0.082), (-h.BODY_HW + 0.0004, 0.195, 0.088), mat=cs)
    ct.box((-h.BODY_HW - 0.016, 0.166, 0.080), (-h.BODY_HW, 0.176, 0.090), mat=cs)
    ct.cylinder(0.0055, 0.008, segments=16, centre=(-h.BODY_HW - 0.019, 0.171, 0.085), axis="X", mat=cs)
    c.finish(ct, "Controls", bevel=0.0004, parent=rec)
    return rec


def _barrel(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(0.0140, 0.010, segments=8, centre=(0.0, h.BODY_FRONT_Y + 0.004, h.BORE_Z), axis="Y", mat=st)  # nut
    c.ring_y(mb, 0.0085, 0.0048, h.BODY_FRONT_Y, h.BARREL_END_Y - 0.012, h.BORE_Z, st, segments=24)
    c.ring_y(mb, 0.0075, 0.0048, h.BARREL_END_Y - 0.012, h.BARREL_END_Y, h.BORE_Z, st, segments=24)     # thread
    for i in range(4):
        mb.cylinder(0.0079, 0.0012, segments=24, centre=(0.0, h.BARREL_END_Y - 0.010 + i * 0.0026, h.BORE_Z),
                    axis="Y", mat=st)
    return c.finish(mb, "Barrel", bevel=0.0004, segments=1)


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    _barrel(ctx, mats)

    ctx.marker("Muzzle", (0.0, h.MUZZLE_Y, h.BORE_Z))
    ctx.marker("BarrelMount", (0.0, h.BODY_FRONT_Y, h.BORE_Z))
    ctx.marker("Eject", (h.BODY_HW, 0.052, h.BORE_Z + 0.006), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, h.SIGHT_RAIL_Y, h.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", h.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, h.UNDER_Y, h.UNDER_Z - 0.0057))
    ctx.marker("SideRail", (h.BODY_HW + 0.0057, h.SIDE_Y, h.BORE_Z - 0.006))
    stock_mount = ctx.marker("StockMount", h.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-(h.BODY_HW + 0.010), 0.160, 0.040))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _body, aim = h.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, -0.060 - h.SIGHT_RAIL_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    h.build_mag(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    h.build_stock(ctx, mats, folded=False, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
