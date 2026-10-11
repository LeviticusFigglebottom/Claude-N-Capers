"""Brannock Thorn: compound bow, first-person model (B4-18).

About 84 cm axle to axle. Machined black alloy riser with a leather-wrapped grip and a cut-out arrow
shelf, split olive limbs, two cams with cables, pin sight on the left, a 70 cm carbon arrow nocked on
the string (brace height about 15 cm).

Origin = hand pivot on the riser grip (see _thorn.py). Forward = Godot -Z.

Node tree: ``Riser`` (+ ``GripWrap``, ``Limbs``, ``Cams``, ``Cables``), ``StringUpper`` / ``StringLower``
(origins on the cam axles; ENV A swings them to the drawn nock). Stock parts: ``SightRail/StockSight``
(single-pin sight, ``AimPoint``), ``Magwell/StockMagazine`` (the nocked arrow). ``Muzzle`` = arrow tip.
"""

import math

import _common as c
import _thorn as t

ASSET_ID = "wpn_thorn_bow"
TRI_BUDGET = 25000


def _riser(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    front = [(0.022, -0.045), (0.024, 0.030), (0.040, 0.062), (0.060, 0.120), (0.066, 0.200), (0.052, 0.280),
             (0.032, 0.318)]
    back_top = [(0.010, 0.318), (0.030, 0.272), (0.042, 0.200), (0.040, 0.130), (0.024, 0.086), (-0.016, 0.064),
                (-0.024, 0.040)]
    back_bot = [(-0.024, -0.040), (-0.016, -0.060), (0.022, -0.092), (0.040, -0.140), (0.042, -0.200),
                (0.030, -0.262), (0.010, -0.308)]
    front_bot = [(0.028, -0.308), (0.048, -0.272), (0.062, -0.210), (0.058, -0.140), (0.040, -0.092),
                 (0.026, -0.060)]
    prof = front + back_top + back_bot + front_bot
    mb.prism(prof, axis="X", start=-t.RISER_HW, end=t.RISER_HW, mat=alu)
    riser = c.finish(mb, "Riser", bevel=0.0018, segments=2)
    gw = ctx.builder()
    lm = gw.material(t.leather(mats))
    gw.prism([(0.025, -0.048), (0.027, 0.034), (-0.026, 0.044), (-0.027, -0.044)], axis="X", start=-t.RISER_HW - 0.002,
             end=t.RISER_HW + 0.002, mat=lm)
    c.finish(gw, "GripWrap", bevel=0.0030, segments=2, parent=riser)

    lb = ctx.builder()
    ol = lb.material(mats.olive())
    for sz in (1.0, -1.0):
        for x in (-0.0085, 0.0085):
            p0 = (0.026, 0.300 * sz)
            p1 = (t.CAM_Y + 0.004, t.CAM_Z * sz)
            dy, dz = p1[0] - p0[0], p1[1] - p0[1]
            ln = math.hypot(dy, dz)
            ny, nz = -dz / ln * 0.0075, dy / ln * 0.0075
            quad = [(p0[0] + ny, p0[1] + nz), (p1[0] + ny * 0.6, p1[1] + nz * 0.6),
                    (p1[0] - ny * 0.6, p1[1] - nz * 0.6), (p0[0] - ny, p0[1] - nz)]
            lb.prism(quad, axis="X", start=x - 0.0045, end=x + 0.0045, mat=ol)
        lb.box((-0.016, 0.012, 0.296 * sz - 0.012), (0.016, 0.038, 0.296 * sz + 0.012), mat=lb.material(mats.alu()))
    c.finish(lb, "Limbs", bevel=0.0012, segments=1, parent=riser)

    cm = ctx.builder()
    ca = cm.material(mats.alu())
    st = cm.material(mats.steel())
    for sz in (1.0, -1.0):
        z = t.CAM_Z * sz
        outer = c.circle(t.CAM_R, 28, t.CAM_Y, z)
        hole = list(reversed(c.circle(t.CAM_R * 0.55, 20, t.CAM_Y + 0.004, z)))
        cm.prism(outer, holes=[hole], axis="X", start=-0.0045, end=0.0045, mat=ca)
        cm.cylinder(0.0045, 0.022, segments=12, centre=(0.0, t.CAM_Y, z), axis="X", mat=st)       # axle
    c.finish(cm, "Cams", bevel=0.0005, parent=riser)
    cb = ctx.builder()
    cbm = cb.material(mats.polymer())
    for sz in (1.0, -1.0):
        y0, z0 = t.CAM_Y + 0.010, t.CAM_Z * sz
        y1, z1 = t.CAM_Y + 0.012, -(t.CAM_Z - 0.020) * sz
        c.rod(cb, (0.0065 * sz, y0, z0), (0.0065 * sz, y1, z1), 0.0014, cbm)
    cb.box((0.004, 0.004, 0.090), (0.020, 0.010, 0.096), mat=cbm)                                    # cable guard
    c.finish(cb, "Cables", parent=riser)
    return riser


def _strings(ctx, mats):
    for sz, name in ((1.0, "StringUpper"), (-1.0, "StringLower")):
        mb = ctx.builder()
        sm = mb.material(mats.polymer())
        z_cam = t.CAM_Z * sz
        ln = abs(z_cam - t.NOCK[2])
        mb.cylinder(0.0016, ln, segments=8, centre=(0.0, -t.CAM_R, -sz * ln / 2), axis="Z", mat=sm)
        if sz > 0:
            mb.cylinder(0.0030, 0.012, segments=10, centre=(0.0, -t.CAM_R, -ln + 0.010), axis="Z",
                        mat=mb.material(mats.brass()))                                              # nock set
        obj = c.finish(mb, name)
        obj.location = (0.0, t.CAM_Y, z_cam)


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _riser(ctx, mats)
    _strings(ctx, mats)

    ctx.marker("Muzzle", (t.ARROW_X, t.MUZZLE_Y, t.ARROW_Z))
    ctx.marker("BarrelMount", (0.0, 0.040, t.ARROW_Z))
    ctx.marker("Eject", (t.RISER_HW, 0.020, t.ARROW_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", t.SIGHT_RAIL)
    magwell = ctx.marker("Magwell", t.MAGWELL_POS, rotation_euler=t.MAGWELL_ROT)
    ctx.marker("Underbarrel", t.UNDER)
    ctx.marker("SideRail", (t.RISER_HW, 0.050, 0.150))
    ctx.marker("StockMount", (0.0, -0.026, 0.0))
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", t.NOCK)

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    aim = t.build_pin_sight(ctx, mats, five=False, parent=stock_sight)
    ctx.marker("AimPoint", aim, parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    t.build_arrow(ctx, mats, broadhead=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "hand pivot: riser grip centre plane, mid grip depth"
