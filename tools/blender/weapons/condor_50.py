"""Marrow & Kell Condor .50: bolt-action anti-materiel rifle, first-person model (B4-12).

About 1.40 m long. Black aluminium chassis with a long octagonal free-float handguard, skeleton stock
with an adjustable cheek riser and a thick rubber pad, round steel receiver with a full-length rail,
heavy barrel and a big two-chamber muzzle brake, five-round single-stack magazine. Ships with a 6x
scope (the stock sight). The biggest gun of the armory.

Origin = firing-hand pivot on the chassis grip (see _condor.py). Forward = Godot -Z.

Node tree: ``Chassis`` (+ ``ChassisDetails``, ``Grip``, ``Trigger``, ``Handguard`` with ``HandguardRails``),
``Stock`` (+ ``CheekRiser``, ``ButtPad``), ``Receiver`` (+ ``ScopeRail``), ``Bolt`` (origin on the bore axis;
ENV A animates it), ``Barrel`` (+ ``MuzzleBrake``). Stock parts: ``SightRail/StockSight`` (6x scope,
``AimPoint``), ``Magwell/StockMagazine`` (five rounds).
"""

import math

import _common as c
import _condor as k

ASSET_ID = "wpn_condor_50"
TRI_BUDGET = 25000


def _chassis(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    hw = k.CHASSIS_HW
    prof = [(-0.040, k.CHASSIS_TOP_Z), (k.HG_Y0 + 0.004, k.CHASSIS_TOP_Z), (k.HG_Y0 + 0.004, k.CHASSIS_BOTTOM_Z + 0.010),
            (k.MAGWELL_Y1 + 0.016, k.CHASSIS_BOTTOM_Z), (k.MAGWELL_Y0 - 0.010, k.CHASSIS_BOTTOM_Z),
            (0.034, k.CHASSIS_BOTTOM_Z), (0.010, 0.024), (-0.030, 0.024), (-0.040, 0.040)]
    mb.prism(prof, axis="X", start=-hw, end=hw, mat=alu)
    # trigger guard loop
    gy = 0.012
    outer = [(gy, 0.026), (0.088, 0.026), (0.088, -0.004), (gy + 0.008, -0.008), (gy, -0.002)]
    hole = [(gy + 0.008, 0.022), (0.082, 0.022), (0.082, 0.000), (gy + 0.010, -0.003), (gy + 0.006, 0.001)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0060, end=0.0060, mat=alu)
    chassis = c.finish(mb, "Chassis", bevel=0.0016, segments=2)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    st = dt.material(mats.bare())
    for side in (-1.0, 1.0):                                         # lightening pockets
        lo, hi = sorted((side * (hw - 0.0004), side * (hw + 0.0004)))
        for y0, y1 in ((0.215, 0.255), (-0.030, -0.005)):
            dt.box((lo, y0, k.CHASSIS_BOTTOM_Z + 0.012), (hi, y1, k.CHASSIS_TOP_Z - 0.010), mat=dark)
        for y in (0.020, 0.240):                                    # action screws
            dt.cylinder(0.0034, 0.0012, segments=12, centre=(side * (hw + 0.0003), y, 0.050), axis="X", mat=st)
    dt.box((-0.0180, k.MAGWELL_Y0 - 0.010, k.CHASSIS_BOTTOM_Z - 0.006), (0.0180, k.MAGWELL_Y0 - 0.002,
           k.CHASSIS_BOTTOM_Z + 0.001), mat=st)                                                  # mag release
    c.finish(dt, "ChassisDetails", parent=chassis)

    gp = ctx.builder()
    rub = gp.material(mats.rubber())
    gp.prism(c.raked_grip_profile(0.026, -0.078, 0.0175, k.GRIP_ANGLE_DEG, palm_swell=0.0035, finger_bumps=3),
             axis="X", start=-0.0145, end=0.0145, mat=rub)
    c.finish(gp, "Grip", bevel=0.0030, segments=3, parent=chassis)
    tr = ctx.builder()
    tm = tr.material(mats.steel())
    tr.box((-0.0030, 0.050, 0.002), (0.0030, 0.054, 0.022), mat=tm)
    tr.box((-0.0030, 0.050, 0.002), (0.0030, 0.058, 0.006), mat=tm)
    c.finish(tr, "Trigger", bevel=0.0005, parent=chassis)

    # octagonal free-float handguard
    hg = ctx.builder()
    ha = hg.material(mats.alu())
    oct_out = c.circle(k.HG_R, 8, 0.0, k.BORE_Z)
    oct_out = [(x * 1.0, z) for x, z in oct_out]
    hole = list(reversed(c.circle(k.BARREL_R + 0.004, 16, 0.0, k.BORE_Z)))
    hg.prism(oct_out, holes=[hole], axis="Y", start=k.HG_Y0, end=k.HG_Y1, mat=ha)
    hgo = c.finish(hg, "Handguard", bevel=0.0010, segments=1, parent=chassis)
    hs = ctx.builder()
    hd = hs.material(mats.polymer())
    for i in range(6):                                               # vent slots on the flats
        y = k.HG_Y0 + 0.030 + i * 0.050
        for a in (math.radians(22.5), math.radians(157.5)):
            x, z = math.cos(a) * (k.HG_R * 0.93), k.BORE_Z + math.sin(a) * (k.HG_R * 0.93)
            hs.box((x - 0.004, y, z - 0.004), (x + 0.004, y + 0.032, z + 0.004), mat=hd)
    ra = hs.material(mats.alu())
    c.rail_side(hs, ra, k.UNDER_Y - 0.040, k.UNDER_Y + 0.045, 0.0, k.UNDER_Z, 0.0)
    c.rail_side(hs, ra, k.SIDE_Y - 0.025, k.SIDE_Y + 0.030, k.HG_R * 0.92, k.BORE_Z, 1.0)
    c.finish(hs, "HandguardRails", bevel=0.0003, parent=hgo)
    return chassis


def _stock(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    y0 = -0.040
    yr = -0.420
    prof = [(y0, k.CHASSIS_TOP_Z), (yr + 0.020, 0.084), (yr, 0.080), (yr, -0.050), (yr + 0.030, -0.054),
            (-0.200, -0.020), (-0.070, 0.012), (y0, 0.030)]
    hole = [(-0.070, 0.064), (yr + 0.050, 0.068), (yr + 0.050, -0.026), (-0.200, 0.002), (-0.080, 0.030)]
    mb.prism(prof, holes=[hole], axis="X", start=-0.0150, end=0.0150, mat=alu)
    stock = c.finish(mb, "Stock", bevel=0.0020, segments=2)
    cr = ctx.builder()
    cm = cr.material(mats.alu())
    cr.prism([(-0.300, 0.086), (-0.110, 0.084), (-0.120, 0.104), (-0.290, 0.108)], axis="X", start=-0.0150,
             end=0.0150, mat=cm)
    for y in (-0.270, -0.140):
        cr.cylinder(0.0040, 0.022, segments=12, centre=(0.0, y, 0.082), axis="Z", mat=cr.material(mats.bare()))
    c.finish(cr, "CheekRiser", bevel=0.0020, segments=2, parent=stock)
    pd = ctx.builder()
    rub = pd.material(mats.rubber())
    pd.prism([(yr, 0.082), (yr, -0.052), (yr - 0.026, -0.050), (yr - 0.026, 0.080)], axis="X", start=-0.0215,
             end=0.0215, mat=rub)
    c.finish(pd, "ButtPad", bevel=0.0040, segments=2, parent=stock)
    return stock


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(k.REC_R, k.REC_Y1 - k.REC_Y0, segments=32, centre=(0.0, (k.REC_Y0 + k.REC_Y1) / 2, k.BORE_Z),
                axis="Y", mat=st)
    mb.cylinder(k.REC_R + 0.003, 0.022, segments=32, centre=(0.0, k.REC_Y1 - 0.011, k.BORE_Z), axis="Y", mat=st)
    rec = c.finish(mb, "Receiver", bevel=0.0008, segments=1)
    pt = ctx.builder()
    dark = pt.material(mats.polymer())
    pt.box((k.REC_R - 0.007, 0.090, k.BORE_Z - 0.006), (k.REC_R + 0.0008, 0.170, k.BORE_Z + 0.012), mat=dark)
    c.finish(pt, "EjectionPort", parent=rec)
    rl = ctx.builder()
    ra = rl.material(mats.alu())
    rl.box((-0.0080, k.RAIL_Y0, k.BORE_Z), (0.0080, k.RAIL_Y1, k.RAIL_BASE_Z + 0.001), mat=ra)
    c.picatinny(rl, ra, k.RAIL_Y0, k.RAIL_Y1, k.RAIL_BASE_Z)
    c.finish(rl, "ScopeRail", bevel=0.0004, parent=rec)
    return rec


def _bolt(ctx, mats):
    """Bolt with its origin on the bore axis at the bolt rear (BOLT_PIVOT)."""
    mb = ctx.builder()
    bare = mb.material(mats.bare())
    st = mb.material(mats.steel())
    by = k.BOLT_PIVOT[1]
    mb.cylinder(0.0170, 0.034, segments=24, centre=(0.0, by - 0.012, k.BORE_Z), axis="Y", mat=st)        # shroud
    mb.cylinder(0.0120, 0.090, segments=24, centre=(0.0, 0.130, k.BORE_Z), axis="Y", mat=bare)          # body
    root_y = by + 0.020
    mb.box((0.0130, root_y - 0.008, k.BORE_Z - 0.005), (0.0300, root_y + 0.008, k.BORE_Z + 0.005), mat=bare)
    n = 5
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        x0, z0 = 0.030 + 0.024 * t0, k.BORE_Z - 0.036 * t0
        x1, z1 = 0.030 + 0.024 * t1, k.BORE_Z - 0.036 * t1
        mb.box((min(x0, x1) - 0.0030, root_y - 0.006 - 0.014 * t1, min(z0, z1) - 0.0035),
               (max(x0, x1) + 0.0030, root_y + 0.005 - 0.014 * t0, max(z0, z1) + 0.0035), mat=bare)
    mb.cylinder(0.0120, 0.024, segments=20, centre=(0.056, root_y - 0.016, k.BORE_Z - 0.040), axis="X", mat=st)
    mb.translate(tuple(-v for v in k.BOLT_PIVOT))
    bolt = c.finish(mb, "Bolt", bevel=0.0008, segments=1)
    bolt.location = k.BOLT_PIVOT
    return bolt


def _barrel(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    y0, y1 = k.REC_Y1, k.BARREL_END_Y
    mb.cylinder(k.BARREL_R + 0.003, 0.050, segments=32, centre=(0.0, y0 + 0.025, k.BORE_Z), axis="Y", mat=st)
    mb.prism(c.fluted(k.BARREL_R, k.BARREL_R - 0.003, 8, 0.0, k.BORE_Z), axis="Y", start=y0 + 0.050,
             end=y1 - 0.050, mat=st)
    mb.cylinder(k.BARREL_R - 0.002, 0.052, segments=28, centre=(0.0, y1 - 0.026, k.BORE_Z), axis="Y", mat=st)
    barrel = c.finish(mb, "Barrel", bevel=0.0005, segments=1)
    c.build_muzzle_brake(ctx, mats, 0.0200, y1, k.BRAKE_LEN, k.BORE_Z, style="sniper", parent=barrel)  # PO6-13
    return barrel


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _chassis(ctx, mats)
    _stock(ctx, mats)
    _receiver(ctx, mats)
    _bolt(ctx, mats)
    _barrel(ctx, mats)

    ctx.marker("BarrelMount", (0.0, k.REC_Y1, k.BORE_Z))
    ctx.marker("Eject", (k.REC_R, 0.130, k.BORE_Z + 0.004), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, k.SIGHT_RAIL_Y, k.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", k.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, k.UNDER_Y, k.UNDER_Z - 0.0062))
    ctx.marker("SideRail", (k.HG_R * 0.92 + 0.0062, k.SIDE_Y, k.BORE_Z))
    ctx.marker("StockMount", k.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Handguard (y 0.270-0.620, bottom z 0.046), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.387, 0.034))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    k.build_scope(ctx, mats, high=False, parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    k.build_mag(ctx, mats, extended=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
    ctx.source_extra["bolt_pivot"] = "Bolt origin on the bore axis at the bolt rear (rotate about local Z, slide +Z)"
