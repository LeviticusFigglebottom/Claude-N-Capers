"""Marrow & Kell Heron .308: bolt-action precision rifle, first-person model (B4-04).

About 1.22 m long. One-piece olive polymer thumbhole stock with an adjustable cheek riser, round
steel receiver with a scope rail, right-hand bolt, fluted heavy barrel with a muzzle brake,
detachable five-round magazine. Ships with a fixed 4x scope (the stock sight).

Origin = firing-hand pivot on the stock's grip (see _heron.py). Forward = Godot -Z.

Node tree: ``Stock`` (+ ``CheekRiser``, ``ButtPad``, ``TriggerGuard``, ``Trigger``, ``Rails``),
``Receiver`` (+ ``ScopeRail``), ``Bolt`` (separate: ENV A animates it), ``Barrel`` (+ ``Brake``).
Stock parts: ``SightRail/StockSight`` (4x scope, ``AimPoint`` at the eyepiece),
``Magwell/StockMagazine`` (five rounds).
"""

import math

import _common as c
import _heron as k

ASSET_ID = "wpn_heron_308"
TRI_BUDGET = 25000


def _stock(ctx, mats):
    mb = ctx.builder()
    ol = mb.material(mats.olive())
    gt = k.GRIP_TAN
    outer = [(0.520, 0.062), (0.245, 0.066), (0.010, 0.066), (-0.012, 0.074), (-0.060, 0.086), (-0.300, 0.088),
             (-0.355, 0.090), (-0.362, 0.080), (-0.368, -0.040), (-0.355, -0.050), (-0.200, -0.030),
             (-0.075, -0.018), (-0.046 + gt * -0.040, -0.040), (-0.034 + gt * -0.072, -0.072),
             (0.002 + gt * -0.074, -0.074), (0.017 + gt * -0.030, -0.030), (0.019, 0.000), (0.026, 0.012),
             (0.240, 0.020), (0.300, 0.028), (0.520, 0.038)]
    hole = [(-0.032, 0.040), (-0.075, 0.052), (-0.150, 0.044), (-0.150, 0.012), (-0.065, 0.004), (-0.034, 0.010)]
    mb.prism(outer, holes=[hole], axis="X", start=-k.STOCK_HW, end=k.STOCK_HW, mat=ol)

    def width(y, z):
        if y > 0.02:
            return 1.0 if y > 0.25 else 0.88
        if z < 0.02 and y > -0.06:
            return 0.60                      # grip
        return 0.86

    c.taper_x(mb, width)
    stock = c.finish(mb, "Stock", bevel=0.0040, segments=3)
    # barrel channel shadow (the barrel free-floats above the forend)
    ch = ctx.builder()
    dark = ch.material(mats.polymer())
    ch.box((-0.0135, 0.245, 0.0605), (0.0135, 0.515, 0.0625), mat=dark)
    for side in (-1.0, 1.0):                    # forend vent slots
        lo, hi = sorted((side * (k.STOCK_HW - 0.0004), side * (k.STOCK_HW + 0.0004)))
        for i in range(4):
            y = 0.300 + i * 0.045
            ch.box((lo, y, 0.040), (hi, y + 0.030, 0.052), mat=dark)
    c.finish(ch, "StockChannel", parent=stock)
    cr = ctx.builder()
    alu = cr.material(mats.alu())
    riser = cr.material(mats.olive())
    cr.prism([(-0.270, 0.086), (-0.090, 0.084), (-0.100, 0.102), (-0.260, 0.106)], axis="X", start=-0.0150,
             end=0.0150, mat=riser)
    for y in (-0.240, -0.120):
        cr.cylinder(0.0035, 0.020, segments=12, centre=(0.0, y, 0.080), axis="Z", mat=alu)
    c.finish(cr, "CheekRiser", bevel=0.0030, segments=2, parent=stock)
    pd = ctx.builder()
    rub = pd.material(mats.rubber())
    pd.prism([(-0.366, 0.090), (-0.372, -0.050), (-0.388, -0.048), (-0.382, 0.088)], axis="X", start=-0.0205,
             end=0.0205, mat=rub)
    c.finish(pd, "ButtPad", bevel=0.0030, segments=2, parent=stock)
    tg = ctx.builder()
    st = tg.material(mats.steel())
    outer_g = [(0.020, 0.016), (0.100, 0.022), (0.098, 0.010), (0.088, -0.004), (0.034, -0.004), (0.022, 0.004)]
    hole_g = [(0.030, 0.012), (0.090, 0.016), (0.088, 0.008), (0.082, 0.002), (0.036, 0.002), (0.030, 0.006)]
    tg.prism(outer_g, holes=[list(reversed(hole_g))], axis="X", start=-0.0070, end=0.0070, mat=st)
    tg.box((-0.0140, k.MAGWELL_Y0 - 0.006, 0.018), (0.0140, k.MAGWELL_Y1 + 0.008, 0.024), mat=st)   # bottom metal
    c.finish(tg, "TriggerGuard", bevel=0.0007, parent=stock)
    tr = ctx.builder()
    tm = tr.material(mats.steel())
    tr.box((-0.0030, 0.058, 0.002), (0.0030, 0.062, 0.020), mat=tm)
    c.finish(tr, "Trigger", bevel=0.0005, parent=stock)
    rl = ctx.builder()
    ra = rl.material(mats.alu())
    c.rail_side(rl, ra, k.UNDER_Y - 0.030, k.UNDER_Y + 0.035, 0.0, k.UNDER_Z + 0.0005, 0.0)
    c.rail_side(rl, ra, 0.420, 0.470, k.STOCK_HW - 0.0005, 0.050, 1.0)
    c.finish(rl, "Rails", bevel=0.0004, parent=stock)
    return stock


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(k.REC_R, k.REC_Y1 - k.REC_Y0, segments=32, centre=(0.0, (k.REC_Y0 + k.REC_Y1) / 2, k.BORE_Z),
                axis="Y", mat=st)
    mb.cylinder(k.REC_R + 0.002, 0.018, segments=32, centre=(0.0, k.REC_Y1 - 0.009, k.BORE_Z), axis="Y", mat=st)  # lug
    rec = c.finish(mb, "Receiver", bevel=0.0008, segments=1)
    pt = ctx.builder()
    dark = pt.material(mats.polymer())
    pt.box((k.REC_R - 0.006, 0.075, k.BORE_Z - 0.004), (k.REC_R + 0.0008, 0.135, k.BORE_Z + 0.010), mat=dark)  # port
    c.finish(pt, "EjectionPort", parent=rec)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), k.REC_Y0 + 0.004, k.REC_Y1 - 0.004, k.RAIL_BASE_Z)
    c.finish(rl, "ScopeRail", bevel=0.0004, parent=rec)
    return rec


def _bolt(ctx, mats):
    mb = ctx.builder()
    bare = mb.material(mats.bare())
    st = mb.material(mats.steel())
    mb.cylinder(0.0125, 0.026, segments=24, centre=(0.0, k.REC_Y0 - 0.010, k.BORE_Z), axis="Y", mat=st)   # shroud
    mb.cylinder(0.0090, 0.060, segments=24, centre=(0.0, 0.090, k.BORE_Z), axis="Y", mat=bare)          # body in port
    # handle: root, angled shaft, knob
    root_y = 0.030
    mb.box((0.0100, root_y - 0.006, k.BORE_Z - 0.004), (0.0230, root_y + 0.006, k.BORE_Z + 0.004), mat=bare)
    n = 5
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        x0, z0 = 0.023 + 0.020 * t0, k.BORE_Z - 0.030 * t0
        x1, z1 = 0.023 + 0.020 * t1, k.BORE_Z - 0.030 * t1
        mb.box((min(x0, x1) - 0.0025, root_y - 0.005 - 0.012 * t1, min(z0, z1) - 0.003),
               (max(x0, x1) + 0.0025, root_y + 0.004 - 0.012 * t0, max(z0, z1) + 0.003), mat=bare)
    mb.cylinder(0.0095, 0.020, segments=20, centre=(0.047, root_y - 0.014, k.BORE_Z - 0.034), axis="X", mat=st)
    # B4-12: origin ON the bore axis at the bolt rear, so ENV A can lift it about local Z and slide it +Z
    pivot = (0.0, k.REC_Y0 - 0.023, k.BORE_Z)
    mb.translate(tuple(-v for v in pivot))
    bolt = c.finish(mb, "Bolt", bevel=0.0007, segments=1)
    bolt.location = pivot
    return bolt


def _barrel(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    y0, y1 = k.REC_Y1, k.BARREL_END_Y
    mb.cylinder(k.BARREL_R + 0.0015, 0.060, segments=32, centre=(0.0, y0 + 0.030, k.BORE_Z), axis="Y", mat=st)
    mb.prism(c.fluted(k.BARREL_R, k.BARREL_R - 0.0025, 6, 0.0, k.BORE_Z), axis="Y", start=y0 + 0.060, end=y1 - 0.060,
             mat=st)
    mb.cylinder(k.BARREL_R - 0.0010, 0.062, segments=28, centre=(0.0, y1 - 0.031, k.BORE_Z), axis="Y", mat=st)
    barrel = c.finish(mb, "Barrel", bevel=0.0005, segments=1)
    br = ctx.builder()
    bm = br.material(mats.steel())
    dark = br.material(mats.polymer())
    prof = c.rounded_rect(0.0150, 0.0120, 0.005, 0.0, k.BORE_Z, corner_segments=2)
    br.prism(prof, axis="Y", start=y1 - 0.002, end=y1 + k.BRAKE_LEN, mat=bm)
    for i in range(4):                                       # side ports
        y = y1 + 0.008 + i * 0.010
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * 0.0146, side * 0.0154))
            br.box((lo, y, k.BORE_Z - 0.007), (hi, y + 0.006, k.BORE_Z + 0.007), mat=dark)
    br.cylinder(0.0055, 0.001, segments=20, centre=(0.0, y1 + k.BRAKE_LEN + 0.0004, k.BORE_Z), axis="Y", mat=dark)
    c.finish(br, "Brake", bevel=0.0010, segments=1, parent=barrel)
    return barrel


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _stock(ctx, mats)
    _receiver(ctx, mats)
    _bolt(ctx, mats)
    _barrel(ctx, mats)

    ctx.marker("Muzzle", (0.0, k.MUZZLE_Y, k.BORE_Z))
    ctx.marker("BarrelMount", (0.0, k.REC_Y1, k.BORE_Z))
    ctx.marker("Eject", (k.REC_R, 0.105, k.BORE_Z + 0.004), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, k.SIGHT_RAIL_Y, k.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", k.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, k.UNDER_Y, k.UNDER_Z - 0.0057))
    ctx.marker("SideRail", (k.STOCK_HW + 0.0057, 0.445, 0.050))
    ctx.marker("StockMount", (0.0, -0.012, 0.074))
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the stock fore-end (y 0.240-0.520, bottom z 0.036), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.333, 0.024))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    k.build_scope(ctx, mats, ten=False, parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    k.build_mag(ctx, mats, extended=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
