"""Marrow & Kell Shrike: tube-fed lever-action rifle, first-person model (B4-18).

About 59 cm from the muzzle to the wrist (plus a 30 cm walnut stock). Blued receiver with a loading gate
on the right, 41 cm octagonal barrel, full-length tube magazine with a barrel band, walnut forend and
straight stock with a steel crescent butt plate, big-loop lever.

Origin = firing-hand pivot on the wrist (see _shrike.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``ReceiverDetails``, ``Trigger``, ``Wrist``, ``Forend``), ``Lever`` (origin =
lever pivot; ENV A swings it about local X), ``Stock``. Stock parts: ``SightRail/StockSight`` (buckhorn +
front blade, ``AimPoint``), ``Magwell/StockMagazine`` (tube), ``BarrelMount/StockBarrel`` (octagonal barrel).
"""

import math

import _common as c
import _shrike as s

ASSET_ID = "wpn_shrike_44"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    prof = [(s.REC_REAR_Y, s.REC_TOP_Z - 0.016), (s.REC_REAR_Y + 0.020, s.REC_TOP_Z), (s.REC_FRONT_Y, s.REC_TOP_Z),
            (s.REC_FRONT_Y, s.REC_BOTTOM_Z), (s.REC_REAR_Y + 0.010, s.REC_BOTTOM_Z)]
    mb.prism(prof, axis="X", start=-s.REC_HW, end=s.REC_HW, mat=st)
    mb.box((-0.0060, s.REC_REAR_Y - 0.040, s.REC_TOP_Z - 0.022), (0.0060, s.REC_REAR_Y + 0.004, s.REC_TOP_Z - 0.014),
           mat=st)                                                                                   # top tang
    rec = c.finish(mb, "Receiver", bevel=0.0012, segments=2)
    dt = ctx.builder()
    br = dt.material(mats.bare())
    dk = dt.material(mats.polymer())
    dt.box((s.REC_HW - 0.0004, 0.070, 0.022), (s.REC_HW + 0.0008, 0.110, 0.036), mat=br)               # loading gate
    dt.box((-0.0070, 0.010, s.REC_TOP_Z - 0.0004), (0.0070, 0.080, s.REC_TOP_Z + 0.0004), mat=dk)       # top port
    dt.box((-0.0040, s.REC_REAR_Y + 0.004, s.REC_TOP_Z - 0.010), (0.0040, s.REC_REAR_Y + 0.022, s.REC_TOP_Z + 0.004),
           mat=br)                                                                                   # hammer
    for side in (-1.0, 1.0):
        for y, z in ((0.020, 0.030), (0.120, 0.050), (0.120, 0.024)):
            dt.cylinder(0.0030, 0.0012, segments=12, centre=(side * (s.REC_HW + 0.0003), y, z), axis="X", mat=br)
    c.finish(dt, "ReceiverDetails", bevel=0.0003, parent=rec)
    tr = ctx.builder()
    tm = tr.material(mats.bare())
    pf, pb = [], []
    for i in range(8):
        t = i / 7
        z = s.REC_BOTTOM_Z - t * 0.020
        yc = 0.040 + 0.006 * t * t
        pf.append((yc + 0.0020, z))
        pb.append((yc - 0.0020, z))
    tr.prism(pf + list(reversed(pb)), axis="X", start=-0.0030, end=0.0030, mat=tm)
    c.finish(tr, "Trigger", bevel=0.0005, parent=rec)
    c.build_grip(ctx, mats, "wood", s.GRIP_TOP_Z, s.GRIP_BOTTOM_Z, 0.0160, 0.0150, s.GRIP_ANGLE_DEG, name="Wrist",
                 parent=rec, finger_bumps=0, palm_swell=0.002)
    fe = ctx.builder()
    wd = fe.material(mats.wood())
    zc = (s.TUBE_Z + s.BORE_Z) / 2 - 0.004
    fe.prism(c.rounded_rect(0.0175, 0.0230, 0.010, 0.0, zc, corner_segments=3), axis="Y", start=s.REC_FRONT_Y,
             end=s.FOREND_Y1, mat=wd)
    fe.box((-0.0185, s.FOREND_Y1 - 0.012, zc - 0.022), (0.0185, s.FOREND_Y1, zc + 0.020), mat=fe.material(mats.steel()))
    c.finish(fe, "Forend", bevel=0.0020, segments=2, parent=rec)
    return rec


def _lever(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    outer, hole = s.lever_profile()
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0045, end=0.0045, mat=st)
    lever = c.finish(mb, "Lever", bevel=0.0008, segments=1)
    lever.location = s.LEVER_PIVOT
    return lever


def _stock(ctx, mats):
    y0 = s.REC_REAR_Y
    yr = y0 - 0.300
    prof = [(y0 + 0.002, s.REC_TOP_Z - 0.016), (y0 - 0.030, s.REC_TOP_Z - 0.022), (yr + 0.010, 0.050), (yr, 0.046),
            (yr - 0.004, -0.010), (yr, -0.072), (yr + 0.014, -0.074), (y0 - 0.060, -0.048), (y0 - 0.034, -0.050),
            (y0 - 0.010, -0.020)]
    stock = c.build_butt_stock(ctx, mats, "wood", prof, 0.0185, name="Stock",
                               taper=lambda y, z: 0.80 + 0.20 * min(1.0, max(0.0, (y0 - y) / 0.10)))
    bp = ctx.builder()
    bp.prism([(yr - 0.004, 0.048), (yr - 0.008, -0.010), (yr - 0.004, -0.076), (yr + 0.002, -0.074),
              (yr - 0.002, -0.010), (yr + 0.002, 0.046)], axis="X", start=-0.0180, end=0.0180,
             mat=bp.material(mats.steel()))
    c.finish(bp, "ButtPlate", bevel=0.0010, parent=stock)
    return stock


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    _lever(ctx, mats)
    _stock(ctx, mats)

    ctx.marker("Muzzle", (0.0, s.MUZZLE_Y, s.BORE_Z))
    bmount = ctx.marker("BarrelMount", (0.0, s.REC_FRONT_Y, s.BORE_Z))
    ctx.marker("Eject", (s.REC_HW, 0.045, s.REC_TOP_Z - 0.008), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, s.SIGHT_RAIL_Y, s.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", s.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, 0.250, s.TUBE_Z - s.TUBE_R - 0.012))
    ctx.marker("SideRail", (0.0180, 0.250, s.BORE_Z - 0.010))
    ctx.marker("StockMount", s.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-0.022, 0.250, s.TUBE_Z - 0.006))

    sb = ctx.marker("StockBarrel", (0.0, 0.0, 0.0), parent=bmount)
    s.build_barrel(ctx, mats, s.BARREL_END_Y, parent=sb)
    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _b, aim = s.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, s.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    s.build_tube(ctx, mats, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: wrist centre plane, mid grip depth, 20 mm below the wrist top"
