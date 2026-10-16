"""Graff-Lindqvist Gale MG: high-rate belt-fed machine gun, first-person model (B4-18).

About 68 cm from the muzzle to the receiver rear (plus a 30 cm polymer stock). Stamped receiver with a
rear-hinged feed cover carrying the optics rail, long perforated barrel jacket with a 3-port muzzle brake and
a front post, belt box under the receiver.

Origin = firing-hand pivot on the grip (see _gale.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``FeedCover`` with ``TopRail`` and the ``SightRail`` marker; origin = the rear
hinge, D-044), ``ReceiverDetails``, ``TriggerGroup``, ``Grip``, ``ChargingHandle``), ``Jacket`` (+ ``MuzzleBrake``),
``Stock``. Stock parts: ``SightRail/StockSight`` (rear leaf, ``AimPoint``), ``Magwell/StockMagazine`` (belt box),
``StockMount/StockStock`` (polymer stock, D-118).
"""

import math

import _common as c
import _gale as g

ASSET_ID = "wpn_gale_mg"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    hw = g.REC_HW
    mb.prism(c.chamfer_rect(hw, g.REC_BOTTOM_Z, g.REC_TOP_Z, 0.004), axis="Y", start=g.REC_REAR_Y, end=g.REC_FRONT_Y,
             mat=st)
    mb.box((-0.020, 0.070, g.REC_BOTTOM_Z - 0.008), (0.020, 0.150, g.REC_BOTTOM_Z + 0.002), mat=st)    # box mount
    rec = c.finish(mb, "Receiver", bevel=0.0014, segments=2)

    cv = ctx.builder()
    cm = cv.material(mats.steel())
    cover = [(g.COVER_Y0, g.REC_TOP_Z - 0.002), (g.COVER_Y1, g.REC_TOP_Z - 0.002), (g.COVER_Y1 + 0.010, g.REC_TOP_Z + 0.004),
             (g.COVER_Y1, g.COVER_TOP_Z), (g.COVER_Y0 + 0.006, g.COVER_TOP_Z), (g.COVER_Y0, g.COVER_TOP_Z - 0.006)]
    cv.prism(cover, axis="X", start=-hw + 0.002, end=hw - 0.002, mat=cm)
    cv.cylinder(0.0058, 2 * hw + 0.004, segments=16, centre=g.COVER_HINGE, axis="X", mat=cm)
    for y in (0.030, 0.100):
        cv.box((-hw + 0.001, y, g.COVER_TOP_Z - 0.003), (hw - 0.001, y + 0.010, g.COVER_TOP_Z + 0.0006), mat=cm)
    cv.box((-0.014, g.COVER_Y1, g.COVER_TOP_Z - 0.012), (0.014, g.COVER_Y1 + 0.012, g.COVER_TOP_Z - 0.004), mat=cm)
    cv.translate(tuple(-v for v in g.COVER_HINGE))
    cover_obj = c.finish(cv, "FeedCover", bevel=0.0012, segments=2, parent=rec)
    cover_obj.location = g.COVER_HINGE
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), g.COVER_Y0 + 0.014, g.COVER_Y1 - 0.006, g.COVER_TOP_Z)
    rl.translate(tuple(-v for v in g.COVER_HINGE))
    c.finish(rl, "TopRail", bevel=0.0004, parent=cover_obj)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    dt.box((-hw - 0.0004, 0.025, 0.084), (-hw + 0.0005, 0.080, 0.106), mat=dark)            # feed opening (left)
    dt.box((hw - 0.0005, 0.020, 0.040), (hw + 0.0004, 0.100, 0.064), mat=dark)              # ejection port
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * (hw - 0.0003), side * (hw + 0.0008)))
        dt.box((lo, g.REC_REAR_Y + 0.008, 0.070), (hi, g.REC_FRONT_Y - 0.008, 0.076), mat=s2)
        for y in (-0.060, -0.020, 0.130):
            dt.cylinder(0.0030, 0.0012, segments=10, centre=(side * (hw + 0.0003), y, 0.034), axis="X", mat=s2)
    c.finish(dt, "ReceiverDetails", parent=rec)
    c.build_trigger_group(ctx, mats, 0.006 + g.GRIP_TAN * 0.010, 0.062, g.REC_BOTTOM_Z, -0.012, 0.034, parent=rec)
    c.build_grip(ctx, mats, "polymer", g.GRIP_TOP_Z, g.GRIP_BOTTOM_Z, 0.0195, 0.0150, g.GRIP_ANGLE_DEG, parent=rec,
                 finger_bumps=3)
    ch = ctx.builder()
    cm2 = ch.material(mats.bare())
    ch.box((hw, 0.110, 0.084), (hw + 0.004, 0.150, 0.090), mat=cm2)
    ch.box((hw, 0.140, 0.080), (hw + 0.026, 0.152, 0.094), mat=cm2)
    ch.cylinder(0.0060, 0.012, segments=16, centre=(hw + 0.026, 0.146, 0.087), axis="Z", mat=cm2)
    c.finish(ch, "ChargingHandle", bevel=0.0008, segments=1, parent=rec)
    return cover_obj


def _jacket(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.matte())
    dark = mb.material(mats.polymer())
    c.ring_y(mb, g.JACKET_R, g.JACKET_R - 0.0015, g.REC_FRONT_Y, g.JACKET_Y1, g.BORE_Z, st, segments=32)
    for i in range(9):                                                                      # cooling slots
        y = g.REC_FRONT_Y + 0.030 + i * 0.040
        for a in (0.0, math.pi / 2, math.pi):
            x, z = math.cos(a) * (g.JACKET_R + 0.0002), g.BORE_Z + math.sin(a) * (g.JACKET_R + 0.0002)
            if abs(math.cos(a)) > 0.5:
                lo, hi = sorted((x - 0.0010 * math.copysign(1, x), x + 0.0004 * math.copysign(1, x)))
                mb.box((lo, y, z - 0.006), (hi, y + 0.024, z + 0.006), mat=dark)
            else:
                mb.box((x - 0.006, y, z - 0.0010), (x + 0.006, y + 0.024, z + 0.0004), mat=dark)
    mb.cylinder(0.0070, g.JACKET_Y1 - g.REC_FRONT_Y, segments=16, centre=(0.0, (g.JACKET_Y1 + g.REC_FRONT_Y) / 2,
                g.BORE_Z), axis="Y", mat=st)                                                 # barrel inside
    fy = g.JACKET_Y1 - 0.030
    post_top = g.RAIL_TOP_Z + g.IRON_AIM_DZ
    mb.box((-0.0040, fy - 0.008, g.BORE_Z + g.JACKET_R - 0.002), (0.0040, fy + 0.008, post_top - 0.012), mat=st)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * 0.0045, side * 0.0075))
        mb.box((lo, fy - 0.005, post_top - 0.018), (hi, fy + 0.005, post_top + 0.002), mat=st)
    mb.box((-0.0012, fy - 0.0015, post_top - 0.014), (0.0012, fy + 0.0015, post_top), mat=st)
    rl = mb.material(mats.alu())
    c.rail_side(mb, rl, g.UNDER_Y - 0.030, g.UNDER_Y + 0.030, 0.0, g.BORE_Z - g.JACKET_R + 0.0005, 0.0)
    jacket = c.finish(mb, "Jacket", bevel=0.0006, segments=1)
    c.build_muzzle_brake(ctx, mats, 0.0150, g.JACKET_Y1, g.BRAKE_LEN, g.BORE_Z, parent=jacket)  # PO6-13
    return jacket


def _stock(ctx, mats):
    y0 = g.REC_REAR_Y
    yr = y0 - 0.290
    prof = [(y0 + 0.002, 0.106), (yr + 0.012, 0.100), (yr, 0.094), (yr, -0.030), (yr + 0.012, -0.040),
            (y0 - 0.130, 0.010), (y0 - 0.030, 0.030), (y0 + 0.002, 0.032)]
    stock = c.build_butt_stock(ctx, mats, "polymer", prof, 0.0190, name="Stock", pad_y=yr, pad_z=(-0.030, 0.094),
                               taper=lambda y, z: 0.82 + 0.18 * min(1.0, max(0.0, (y0 - y) / 0.3)))
    return stock


def build(ctx) -> None:
    mats = c.Mats(ctx)
    cover = _receiver(ctx, mats)
    _jacket(ctx, mats)
    stock = _stock(ctx, mats)

    ctx.marker("BarrelMount", (0.0, g.REC_FRONT_Y, g.BORE_Z))
    ctx.marker("Eject", (g.REC_HW, 0.060, g.BORE_Z - 0.026), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, g.SIGHT_RAIL_Y - g.COVER_HINGE[1], g.RAIL_TOP_Z - g.COVER_HINGE[2]),
                            parent=cover)
    magwell = ctx.marker("Magwell", g.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, g.UNDER_Y, g.BORE_Z - g.JACKET_R - 0.0057))
    ctx.marker("SideRail", (g.JACKET_R + 0.002, g.SIDE_Y, g.BORE_Z))
    stock_mount = ctx.marker("StockMount", g.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Jacket (y 0.160-0.555, bottom z 0.052), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.292, 0.040))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    g.build_rear_leaf(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, g.REAR_IRON_Y, g.IRON_AIM_DZ), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    g.build_box(ctx, mats, big=False, parent=stock_mag)
    c.wrap_part(ctx, [stock], stock_mount, "StockStock", g.STOCK_MOUNT)  # D-118: swappable stock

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
