"""Graff-Lindqvist Rampart: 5.56 mm belt-fed light machine gun, first-person model (B4-04).

About 1.07 m long. Wide steel receiver with a hinged feed cover (optics rail on top), belt box under
the receiver feeding from the left, ribbed polymer handguard, quick-change barrel with carry handle
and tall front post, fixed polymer stock. The heaviest, bulkiest silhouette of the armory.

Origin = firing-hand pivot on the pistol grip (see _rampart.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``FeedCover`` with ``TopRail`` and the ``SightRail`` marker; its origin is the
rear hinge axis and it opens 78 deg about local X, D-044, ``ReceiverDetails``, ``Grip``,
``Trigger``, ``ChargingHandle``), ``Handguard`` (+ rails), ``Stock``. Stock parts:
``SightRail/StockSight`` (rear leaf, ``AimPoint``), ``Magwell/StockMagazine`` (100-round box + belt),
``BarrelMount/StockBarrel`` (long barrel).
"""

import math

import _common as c
import _rampart as r

ASSET_ID = "wpn_rampart_lmg"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    """Receiver with its children; returns the FeedCover (the SightRail marker rides on it)."""
    mb = ctx.builder()
    st = mb.material(mats.steel())
    hw = r.REC_HW
    cross = [(-hw, r.REC_BOTTOM_Z), (hw, r.REC_BOTTOM_Z), (hw, r.REC_TOP_Z - 0.006), (hw - 0.006, r.REC_TOP_Z),
             (-hw + 0.006, r.REC_TOP_Z), (-hw, r.REC_TOP_Z - 0.006)]
    mb.prism(cross, axis="Y", start=r.REC_REAR_Y, end=r.REC_FRONT_Y, mat=st)
    # box mount + trigger housing under the receiver
    mb.box((-0.024, 0.098, r.REC_BOTTOM_Z - 0.010), (0.024, 0.202, r.REC_BOTTOM_Z + 0.002), mat=st)
    gy = 0.008
    outer = [(gy, r.REC_BOTTOM_Z + 0.002), (0.094, r.REC_BOTTOM_Z + 0.002), (0.094, -0.006), (gy + 0.006, -0.006),
             (gy, -0.001)]
    hole = [(gy + 0.008, r.REC_BOTTOM_Z - 0.002), (0.090, r.REC_BOTTOM_Z - 0.002), (0.090, -0.002),
            (gy + 0.010, -0.002)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0065, end=0.0065, mat=st)
    rec = c.finish(mb, "Receiver", bevel=0.0018, segments=2)

    # Feed cover (D-044, visual_slots.md): hinged at the REAR; the object's origin is the hinge axis, so
    # ENV A opens it by rotating about local X (open = 78 deg, front edge up; closed = rotation 0).
    cv = ctx.builder()
    cm = cv.material(mats.steel())
    cover = [(r.COVER_Y0, r.REC_TOP_Z - 0.002), (r.COVER_Y1, r.REC_TOP_Z - 0.002), (r.COVER_Y1 + 0.010, r.REC_TOP_Z + 0.004),
             (r.COVER_Y1, r.COVER_TOP_Z), (r.COVER_Y0 + 0.006, r.COVER_TOP_Z), (r.COVER_Y0, r.COVER_TOP_Z - 0.006)]
    cv.prism(cover, axis="X", start=-hw + 0.002, end=hw - 0.002, mat=cm)
    cv.cylinder(r.COVER_HINGE_R, 2 * hw + 0.004, segments=16, centre=r.COVER_HINGE, axis="X", mat=cm)   # hinge
    cv.box((-0.012, r.COVER_Y1 - 0.002, r.COVER_TOP_Z - 0.012), (0.012, r.COVER_Y1 + 0.010, r.COVER_TOP_Z - 0.004),
           mat=cm)                                                                    # front latch
    cv.translate(tuple(-v for v in r.COVER_HINGE))
    cover_obj = c.finish(cv, "FeedCover", bevel=0.0012, segments=2, parent=rec)
    cover_obj.location = r.COVER_HINGE
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), r.COVER_Y0 + 0.006, r.COVER_Y1 - 0.004, r.COVER_TOP_Z)
    rl.translate(tuple(-v for v in r.COVER_HINGE))
    c.finish(rl, "TopRail", bevel=0.0004, parent=cover_obj)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.steel())
    # feed opening on the left, ejection port on the right, side plates rivets
    dt.box((-hw - 0.0004, 0.030, 0.088), (-hw + 0.0005, 0.090, 0.112), mat=dark)
    dt.box((hw - 0.0005, 0.020, 0.062), (hw + 0.0004, 0.110, 0.084), mat=dark)
    for side in (-1.0, 1.0):
        for y in (-0.060, -0.020, 0.120, 0.200):
            for z in (0.032, 0.106):
                dt.cylinder(0.0028, 0.0012, segments=10, centre=(side * (hw + 0.0003), y, z), axis="X", mat=s2)
        lo, hi = sorted((side * (hw - 0.0003), side * (hw + 0.0006)))
        dt.box((lo, r.REC_REAR_Y + 0.010, 0.050), (hi, r.REC_FRONT_Y - 0.010, 0.053), mat=s2)   # side seam
    c.finish(dt, "ReceiverDetails", parent=rec)

    gp = ctx.builder()
    poly = gp.material(mats.polymer())
    gp.prism(c.raked_grip_profile(0.024, -0.074, 0.0175, r.GRIP_ANGLE_DEG, palm_swell=0.003, finger_bumps=3),
             axis="X", start=-0.0140, end=0.0140, mat=poly)
    gp.box((-0.012, -0.034, 0.018), (0.012, 0.006, r.REC_BOTTOM_Z + 0.002), mat=poly)
    c.finish(gp, "Grip", bevel=0.0030, segments=3, parent=rec)
    tr = ctx.builder()
    ts = tr.material(mats.steel())
    pf, pb = [], []
    for i in range(8):
        s = i / 7
        z = r.REC_BOTTOM_Z - s * 0.020
        yc = 0.040 + 0.006 * s * s
        pf.append((yc + 0.0020, z))
        pb.append((yc - 0.0020, z))
    tr.prism(pf + list(reversed(pb)), axis="X", start=-0.0032, end=0.0032, mat=ts)
    tr.cylinder(0.0055, 0.004, segments=16, centre=(-0.0160, 0.004, 0.012), axis="X", mat=ts)    # safety
    c.finish(tr, "Trigger", bevel=0.0005, parent=rec)
    ch = ctx.builder()
    cm2 = ch.material(mats.steel())
    ch.box((hw, 0.150, 0.088), (hw + 0.004, 0.220, 0.094), mat=cm2)                  # handle track
    ch.box((hw, 0.200, 0.084), (hw + 0.026, 0.212, 0.098), mat=cm2)                  # folding handle
    c.finish(ch, "ChargingHandle", bevel=0.0008, segments=1, parent=rec)
    return cover_obj


def _handguard(ctx, mats):
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    outer = c.rounded_rect(r.HG_HW, r.HG_HH, 0.012, 0.0, r.HG_ZC, corner_segments=3)
    hole = list(reversed(c.circle(0.0170, 24, 0.0, r.BORE_Z)))
    mb.prism(outer, holes=[hole], axis="Y", start=r.REC_FRONT_Y, end=r.HG_Y1, mat=poly)
    hg = c.finish(mb, "Handguard", bevel=0.0030, segments=2)
    rb = ctx.builder()
    rm = rb.material(mats.polymer())
    for i in range(8):                                  # heat ribs
        y = r.REC_FRONT_Y + 0.018 + i * 0.020
        rb.prism(c.rounded_rect(r.HG_HW + 0.0012, r.HG_HH + 0.0012, 0.012, 0.0, r.HG_ZC, corner_segments=3),
                 axis="Y", start=y, end=y + 0.008, mat=rm)
    c.finish(rb, "HandguardRibs", bevel=0.0010, parent=hg)
    rl = ctx.builder()
    ra = rl.material(mats.alu())
    c.rail_side(rl, ra, r.UNDER_Y - 0.030, r.UNDER_Y + 0.035, 0.0, r.HG_ZC - r.HG_HH + 0.0005, 0.0)
    c.rail_side(rl, ra, r.UNDER_Y - 0.020, r.UNDER_Y + 0.025, r.HG_HW + 0.0007, r.HG_ZC, 1.0)
    c.finish(rl, "HandguardRails", bevel=0.0004, parent=hg)
    return hg


def _stock(ctx, mats):
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    y0 = r.REC_REAR_Y
    yr = y0 - 0.300
    prof = [(y0 + 0.002, 0.112), (y0 - 0.060, 0.110), (yr + 0.010, 0.112), (yr, 0.108), (yr - 0.002, -0.020),
            (yr + 0.012, -0.030), (y0 - 0.150, 0.010), (y0 - 0.040, 0.030), (y0 + 0.002, 0.028)]
    hole = [(y0 - 0.050, 0.092), (yr + 0.030, 0.092), (yr + 0.030, 0.000), (y0 - 0.150, 0.030),
            (y0 - 0.060, 0.046)]
    mb.prism(prof, holes=[hole], axis="X", start=-0.0200, end=0.0200, mat=poly)
    c.taper_x(mb, lambda y, z: 0.85 + 0.15 * min(1.0, max(0.0, (y0 - y) / 0.3)))
    stock = c.finish(mb, "Stock", bevel=0.0035, segments=2)
    pd = ctx.builder()
    rub = pd.material(mats.rubber())
    pd.prism([(yr - 0.002, 0.108), (yr - 0.002, -0.028), (yr - 0.016, -0.026), (yr - 0.016, 0.104)], axis="X",
             start=-0.0195, end=0.0195, mat=rub)
    c.finish(pd, "ButtPad", bevel=0.0025, segments=2, parent=stock)
    return stock


def build(ctx) -> None:
    mats = c.Mats(ctx)
    cover = _receiver(ctx, mats)
    _handguard(ctx, mats)
    _stock(ctx, mats)

    ctx.marker("Muzzle", (0.0, r.LONG_END_Y + r.HIDER_LEN + 0.001, r.BORE_Z))
    barrel_mount = ctx.marker("BarrelMount", (0.0, r.REC_FRONT_Y, r.BORE_Z))
    ctx.marker("Eject", (r.REC_HW, 0.065, r.BORE_Z - 0.012), rotation_euler=(0.0, 0.0, -math.pi / 2))
    # the optics rail rides on the feed cover, so sights open with it
    sight_rail = ctx.marker("SightRail", (0.0, r.SIGHT_RAIL_Y - r.COVER_HINGE[1], r.RAIL_TOP_Z - r.COVER_HINGE[2]),
                            parent=cover)
    magwell = ctx.marker("Magwell", r.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, r.UNDER_Y, r.HG_ZC - r.HG_HH - 0.0057))
    ctx.marker("SideRail", (r.HG_HW + 0.0065, r.UNDER_Y, r.HG_ZC))
    ctx.marker("StockMount", (0.0, r.REC_REAR_Y, r.BORE_Z))
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Handguard (y 0.230-0.420, bottom z 0.041), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.293, 0.029))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    r.build_rear_leaf(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, r.REAR_IRON_Y, r.IRON_AIM_DZ), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    r.build_box(ctx, mats, big=False, parent=stock_mag)
    stock_barrel = ctx.marker("StockBarrel", (0.0, 0.0, 0.0), parent=barrel_mount)
    r.build_barrel(ctx, mats, short=False, parent=stock_barrel)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
