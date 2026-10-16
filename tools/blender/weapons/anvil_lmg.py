"""Tillman Ironworks Anvil: belt-fed 7.62 mm general-purpose machine gun, first-person model (B4-12).

About 1.15 m long. Tall riveted steel receiver with a rear-hinged feed cover (optics rail on top), walnut
skeleton stock and pistol grip, gas cylinder under a long fluted quick-change barrel with a wooden
carry handle folded to the right, olive steel ammo box under the receiver. Heavier and older than the
polymer Rampart.

Origin = firing-hand pivot on the pistol grip (see _anvil.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``FeedCover`` with ``TopRail`` and the ``SightRail`` marker; origin = the rear
hinge axis, opens 78 deg about local X (D-044), ``ReceiverDetails``, ``Grip``, ``Trigger``,
``ChargingHandle``), ``GasCylinder`` (+ ``GasRail``), ``Stock``. Stock parts: ``SightRail/StockSight``
(tangent rear leaf, ``AimPoint``), ``Magwell/StockMagazine`` (100-round box + belt),
``BarrelMount/StockBarrel`` (long barrel), ``StockMount/StockStock`` (wooden stock, D-118).
"""

import math

import _common as c
import _anvil as a

ASSET_ID = "wpn_anvil_lmg"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    """Receiver with its children; returns the FeedCover (the SightRail marker rides on it)."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    hw = a.REC_HW
    cross = [(-hw, a.REC_BOTTOM_Z), (hw, a.REC_BOTTOM_Z), (hw, a.REC_TOP_Z - 0.004), (hw - 0.004, a.REC_TOP_Z),
             (-hw + 0.004, a.REC_TOP_Z), (-hw, a.REC_TOP_Z - 0.004)]
    mb.prism(cross, axis="Y", start=a.REC_REAR_Y, end=a.REC_FRONT_Y, mat=st)
    mb.box((-0.020, 0.090, a.REC_BOTTOM_Z - 0.008), (0.020, 0.190, a.REC_BOTTOM_Z + 0.002), mat=st)   # box mount
    gy = 0.008
    outer = [(gy, a.REC_BOTTOM_Z + 0.002), (0.088, a.REC_BOTTOM_Z + 0.002), (0.088, -0.006), (gy + 0.006, -0.006),
             (gy, -0.001)]
    hole = [(gy + 0.008, a.REC_BOTTOM_Z - 0.002), (0.084, a.REC_BOTTOM_Z - 0.002), (0.084, -0.002),
            (gy + 0.010, -0.002)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0065, end=0.0065, mat=st)
    rec = c.finish(mb, "Receiver", bevel=0.0016, segments=2)

    # feed cover (D-044): origin on the REAR hinge axis; ENV A opens it 78 deg about local X
    cv = ctx.builder()
    cm = cv.material(mats.steel())
    cover = [(a.COVER_Y0, a.REC_TOP_Z - 0.002), (a.COVER_Y1, a.REC_TOP_Z - 0.002),
             (a.COVER_Y1 + 0.012, a.REC_TOP_Z + 0.004), (a.COVER_Y1, a.COVER_TOP_Z),
             (a.COVER_Y0 + 0.006, a.COVER_TOP_Z), (a.COVER_Y0, a.COVER_TOP_Z - 0.006)]
    cv.prism(cover, axis="X", start=-hw + 0.002, end=hw - 0.002, mat=cm)
    cv.cylinder(0.0060, 2 * hw + 0.004, segments=16, centre=a.COVER_HINGE, axis="X", mat=cm)
    for y in (0.030, 0.090):                                                # stamped stiffeners
        cv.box((-hw + 0.001, y, a.COVER_TOP_Z - 0.003), (hw - 0.001, y + 0.010, a.COVER_TOP_Z + 0.0006), mat=cm)
    cv.box((-0.014, a.COVER_Y1, a.COVER_TOP_Z - 0.012), (0.014, a.COVER_Y1 + 0.012, a.COVER_TOP_Z - 0.004),
           mat=cm)                                                           # front latch
    cv.translate(tuple(-v for v in a.COVER_HINGE))
    cover_obj = c.finish(cv, "FeedCover", bevel=0.0012, segments=2, parent=rec)
    cover_obj.location = a.COVER_HINGE
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), a.COVER_Y0 + 0.014, a.COVER_Y1 - 0.006, a.COVER_TOP_Z)
    rl.translate(tuple(-v for v in a.COVER_HINGE))
    c.finish(rl, "TopRail", bevel=0.0004, parent=cover_obj)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    dt.box((-hw - 0.0004, 0.040, 0.092), (-hw + 0.0005, 0.100, 0.116), mat=dark)          # feed opening (left)
    dt.box((hw - 0.0005, 0.030, 0.050), (hw + 0.0004, 0.120, 0.072), mat=dark)            # ejection port (right)
    for side in (-1.0, 1.0):
        for y in (-0.070, -0.035, 0.150, 0.195):
            for z in (0.036, 0.100):
                dt.cylinder(0.0030, 0.0012, segments=10, centre=(side * (hw + 0.0003), y, z), axis="X", mat=s2)
        lo, hi = sorted((side * (hw - 0.0003), side * (hw + 0.0008)))
        dt.box((lo, a.REC_REAR_Y + 0.008, 0.074), (hi, a.REC_FRONT_Y - 0.008, 0.080), mat=s2)   # side rib
    c.finish(dt, "ReceiverDetails", parent=rec)

    gp = ctx.builder()
    wood = gp.material(mats.wood())
    gp.prism(c.raked_grip_profile(0.026, -0.076, 0.0180, a.GRIP_ANGLE_DEG, palm_swell=0.0030, finger_bumps=0),
             axis="X", start=-0.0145, end=0.0145, mat=wood)
    gp.box((-0.012, -0.036, 0.018), (0.012, 0.008, a.REC_BOTTOM_Z + 0.002), mat=wood)
    c.finish(gp, "Grip", bevel=0.0030, segments=3, parent=rec)
    tr = ctx.builder()
    ts = tr.material(mats.steel())
    pf, pb = [], []
    for i in range(8):
        s = i / 7
        z = a.REC_BOTTOM_Z - s * 0.020
        yc = 0.040 + 0.006 * s * s
        pf.append((yc + 0.0020, z))
        pb.append((yc - 0.0020, z))
    tr.prism(pf + list(reversed(pb)), axis="X", start=-0.0032, end=0.0032, mat=ts)
    tr.box((-0.0185, -0.004, 0.010), (-0.0145, 0.020, 0.016), mat=ts)                       # safety
    c.finish(tr, "Trigger", bevel=0.0005, parent=rec)
    ch = ctx.builder()
    cm2 = ch.material(mats.bare())
    ch.box((hw, 0.130, 0.040), (hw + 0.004, 0.205, 0.046), mat=cm2)                          # handle track
    ch.box((hw, 0.195, 0.036), (hw + 0.030, 0.207, 0.050), mat=cm2)                          # charging handle
    ch.cylinder(0.0060, 0.012, segments=16, centre=(hw + 0.030, 0.201, 0.043), axis="Z", mat=cm2)
    c.finish(ch, "ChargingHandle", bevel=0.0008, segments=1, parent=rec)
    return cover_obj


def _gas(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(a.GAS_R, a.GAS_Y1 - a.REC_FRONT_Y, segments=20,
                centre=(0.0, (a.GAS_Y1 + a.REC_FRONT_Y) / 2, a.GAS_Z), axis="Y", mat=st)
    mb.box((-0.0150, a.REC_FRONT_Y, a.GAS_Z - 0.014), (0.0150, a.REC_FRONT_Y + 0.030, a.BORE_Z + 0.004),
           mat=st)                                                                         # front trunnion block
    mb.box((-0.0110, a.GAS_Y1 - 0.016, a.GAS_Z - 0.010), (0.0110, a.GAS_Y1 + 0.004, a.BORE_Z - 0.006), mat=st)
    for i in range(5):                                                                     # heat collars
        y = a.REC_FRONT_Y + 0.050 + i * 0.034
        mb.cylinder(a.GAS_R + 0.0015, 0.008, segments=20, centre=(0.0, y, a.GAS_Z), axis="Y", mat=st)
    gas = c.finish(mb, "GasCylinder", bevel=0.0008, segments=1)
    rl = ctx.builder()
    ra = rl.material(mats.alu())
    under_z = a.GAS_Z - a.GAS_R
    rl.box((-0.0080, a.UNDER_Y - 0.040, under_z - 0.0010), (0.0080, a.UNDER_Y + 0.040, a.GAS_Z), mat=ra)
    c.rail_side(rl, ra, a.UNDER_Y - 0.040, a.UNDER_Y + 0.040, 0.0, under_z - 0.0005, 0.0)
    rl.box((0.0080, a.SIDE_Y - 0.020, a.GAS_Z - 0.008), (a.GAS_R + 0.002, a.SIDE_Y + 0.025, a.GAS_Z + 0.008), mat=ra)
    c.rail_side(rl, ra, a.SIDE_Y - 0.020, a.SIDE_Y + 0.025, a.GAS_R + 0.0010, a.GAS_Z, 1.0)
    c.finish(rl, "GasRail", bevel=0.0004, parent=gas)
    return gas


def _stock(ctx, mats):
    mb = ctx.builder()
    wood = mb.material(mats.wood())
    y0 = a.REC_REAR_Y
    yr = y0 - 0.300
    prof = [(y0 + 0.002, 0.116), (y0 - 0.050, 0.112), (yr + 0.012, 0.104), (yr, 0.098), (yr - 0.002, -0.034),
            (yr + 0.012, -0.044), (y0 - 0.140, 0.006), (y0 - 0.030, 0.030), (y0 + 0.002, 0.032)]
    hole = [(y0 - 0.040, 0.094), (yr + 0.036, 0.088), (yr + 0.036, -0.010), (y0 - 0.150, 0.036),
            (y0 - 0.050, 0.050)]
    mb.prism(prof, holes=[hole], axis="X", start=-0.0190, end=0.0190, mat=wood)
    c.taper_x(mb, lambda y, z: 0.80 + 0.20 * min(1.0, max(0.0, (y0 - y) / 0.3)))
    stock = c.finish(mb, "Stock", bevel=0.0035, segments=2)
    pd = ctx.builder()
    st = pd.material(mats.steel())
    pd.prism([(yr - 0.002, 0.100), (yr - 0.002, -0.040), (yr - 0.010, -0.038), (yr - 0.010, 0.098)], axis="X",
             start=-0.0188, end=0.0188, mat=st)
    pd.box((-0.0130, y0 - 0.010, 0.040), (0.0130, y0 + 0.004, 0.110), mat=st)               # receiver tang
    c.finish(pd, "ButtPlate", bevel=0.0015, segments=1, parent=stock)
    return stock


def build(ctx) -> None:
    mats = c.Mats(ctx)
    cover = _receiver(ctx, mats)
    _gas(ctx, mats)
    stock = _stock(ctx, mats)

    barrel_mount = ctx.marker("BarrelMount", (0.0, a.REC_FRONT_Y, a.BORE_Z))
    ctx.marker("Eject", (a.REC_HW, 0.075, a.BORE_Z - 0.026), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, a.SIGHT_RAIL_Y - a.COVER_HINGE[1], a.RAIL_TOP_Z - a.COVER_HINGE[2]),
                            parent=cover)
    magwell = ctx.marker("Magwell", a.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, a.UNDER_Y, a.GAS_Z - a.GAS_R - 0.0062))
    ctx.marker("SideRail", (a.GAS_R + 0.0072, a.SIDE_Y, a.GAS_Z))
    stock_mount = ctx.marker("StockMount", a.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the GasCylinder (y 0.215-0.459, bottom z 0.044), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.296, 0.032))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    a.build_rear_leaf(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, a.REAR_IRON_Y, a.IRON_AIM_DZ), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    a.build_box(ctx, mats, big=False, parent=stock_mag)
    stock_barrel = ctx.marker("StockBarrel", (0.0, 0.0, 0.0), parent=barrel_mount)
    a.build_barrel(ctx, mats, short=False, parent=stock_barrel)
    c.wrap_part(ctx, [stock], stock_mount, "StockStock", a.STOCK_MOUNT)  # D-118: swappable stock

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
