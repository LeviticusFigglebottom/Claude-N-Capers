"""Brannock Wasp PDW: compact 4.6 mm personal defence weapon, first-person model (B4-12).

About 42 cm long with the stock collapsed. One-piece tan polymer body with a full-length optics rail,
magazine through the near-vertical pistol grip, moulded front grip under the nose, short barrel with a
three-prong flash hider, collapsed telescopic stock with steel rods. Smaller and lighter than the
Hornet 9.

Origin = firing-hand pivot on the grip (see _wasp.py). Forward = Godot -Z.

Node tree: ``Body`` (+ ``BodyRail``, ``BodyDetails``, ``Grip``, ``FrontGrip``, ``Trigger``,
``ChargingHandle``), ``Barrel`` (+ ``FlashHider``). Stock parts: ``SightRail/StockSight`` (flip-up irons,
``AimPoint``), ``Magwell/StockMagazine`` (30 rounds), ``StockMount/StockStock`` (collapsed stock).
"""

import math

import _common as c
import _wasp as w

ASSET_ID = "wpn_wasp_pdw"
TRI_BUDGET = 25000


def _body(ctx, mats):
    mb = ctx.builder()
    tan = mb.material(mats.tan())
    hw = w.BODY_HW
    prof = [(w.BODY_REAR_Y, w.BODY_TOP_Z), (w.BODY_FRONT_Y - 0.010, w.BODY_TOP_Z), (w.BODY_FRONT_Y, w.BODY_TOP_Z - 0.012),
            (w.BODY_FRONT_Y, w.BORE_Z - 0.020), (w.BODY_FRONT_Y - 0.012, w.BODY_BOTTOM_Z),
            (0.074, w.BODY_BOTTOM_Z), (0.070, w.BODY_BOTTOM_Z + 0.004), (w.GRIP_HALF_DEPTH + 0.004, w.BODY_BOTTOM_Z + 0.004),
            (-w.GRIP_HALF_DEPTH - 0.004, w.BODY_BOTTOM_Z + 0.004), (w.BODY_REAR_Y + 0.010, w.BODY_BOTTOM_Z + 0.010),
            (w.BODY_REAR_Y, w.BODY_BOTTOM_Z + 0.022)]
    mb.prism(prof, axis="X", start=-hw, end=hw, mat=tan)
    # trigger guard ring moulded into the body
    gy = w.GRIP_HALF_DEPTH + w.GRIP_TAN * 0.010
    outer = [(gy - 0.002, w.BODY_BOTTOM_Z + 0.002), (0.074, w.BODY_BOTTOM_Z + 0.002), (0.072, 0.004), (0.060, -0.008),
             (gy + 0.004, -0.008), (gy - 0.002, -0.002)]
    hole = [(gy + 0.004, w.BODY_BOTTOM_Z - 0.002), (0.066, w.BODY_BOTTOM_Z - 0.002), (0.064, 0.004), (0.056, -0.002),
            (gy + 0.006, -0.002), (gy + 0.003, 0.004)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0065, end=0.0065, mat=tan)
    c.taper_x(mb, lambda y, z: 0.86 if z > w.BODY_TOP_Z - 0.010 else 1.0)
    body = c.finish(mb, "Body", bevel=0.0025, segments=2)

    rl = ctx.builder()
    ra = rl.material(mats.alu())
    rl.box((-0.0095, w.RAIL_Y0, w.BODY_TOP_Z - 0.003), (0.0095, w.RAIL_Y1, w.BODY_TOP_Z + 0.001), mat=ra)
    c.picatinny(rl, ra, w.RAIL_Y0, w.RAIL_Y1, w.BODY_TOP_Z)
    c.rail_side(rl, ra, w.SIDE_Y - 0.020, w.SIDE_Y + 0.020, w.BODY_HW - 0.0005, w.BORE_Z - 0.008, 1.0)
    c.finish(rl, "BodyRail", bevel=0.0004, parent=body)
    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.steel())
    dt.box((hw - 0.0005, 0.000, w.BORE_Z - 0.006), (hw + 0.0004, 0.050, w.BORE_Z + 0.010), mat=dark)   # port
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * (hw - 0.0004), side * (hw + 0.0004)))
        for i in range(4):                                                                     # grip panels
            y = w.BODY_REAR_Y + 0.020 + i * 0.012
            dt.box((lo, y, w.BODY_BOTTOM_Z + 0.016), (hi, y + 0.006, w.BODY_TOP_Z - 0.020), mat=dark)
        for y in (-0.050, 0.110):
            dt.cylinder(0.0028, 0.001, segments=12, centre=(side * (hw + 0.0002), y, w.BORE_Z - 0.016), axis="X",
                        mat=s2)
    dt.cylinder(0.0055, 0.003, segments=18, centre=(-hw - 0.0012, -0.006, w.BODY_BOTTOM_Z + 0.012), axis="X",
                mat=s2)                                                                         # selector
    dt.box((-hw - 0.0026, -0.006, w.BODY_BOTTOM_Z + 0.010), (-hw - 0.0010, 0.012, w.BODY_BOTTOM_Z + 0.014), mat=s2)
    c.finish(dt, "BodyDetails", bevel=0.0002, parent=body)

    gp = ctx.builder()
    poly = gp.material(mats.tan())
    zt = w.GRIP_TOP_Z + 0.004
    grip = [(w.GRIP_HALF_DEPTH + w.GRIP_TAN * zt, zt), (w.GRIP_HALF_DEPTH + w.GRIP_TAN * w.GRIP_BOTTOM_Z, w.GRIP_BOTTOM_Z),
            (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * w.GRIP_BOTTOM_Z, w.GRIP_BOTTOM_Z),
            (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * -0.030 - 0.0025, -0.030), (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * zt, zt)]
    gp.prism(grip, axis="X", start=-w.GRIP_HALF_WIDTH, end=w.GRIP_HALF_WIDTH, mat=poly)
    g = c.finish(gp, "Grip", bevel=0.0030, segments=3, parent=body)
    gt = ctx.builder()
    gm = gt.material(mats.stipple())
    for side in (-1.0, 1.0):
        x = side * (w.GRIP_HALF_WIDTH - 0.0001)
        for r in range(10):
            z = -0.062 + r * 0.0080
            yb = -w.GRIP_HALF_DEPTH + w.GRIP_TAN * z + 0.006
            yf = w.GRIP_HALF_DEPTH + w.GRIP_TAN * z - 0.006
            yy = yb + (0.0040 if r % 2 else 0.0)
            while yy < yf:
                c.pyramid(gt.bm, c.Vector((x, yy, z)), c.Vector((0, 1, 0)), c.Vector((0, 0, 1)), c.Vector((side, 0, 0)),
                          0.0016, 0.0006, gm)
                yy += 0.0080
    c.finish(gt, "GripTexture", parent=g)

    fg = ctx.builder()
    fm = fg.material(mats.polymer())
    fy = w.UNDER_Y + 0.020
    fg.box((-0.0110, fy - 0.014, w.BODY_BOTTOM_Z - 0.006), (0.0110, fy + 0.014, w.BODY_BOTTOM_Z + 0.002), mat=fm)
    fg.prism(c.rounded_rect(0.0105, 0.0130, 0.007, 0.0, fy, corner_segments=3), axis="Z", start=w.BODY_BOTTOM_Z - 0.066,
             end=w.BODY_BOTTOM_Z - 0.004, mat=fm)
    c.finish(fg, "FrontGrip", bevel=0.0018, segments=2, parent=body)

    tr = ctx.builder()
    ts = tr.material(mats.steel())
    pf, pb = [], []
    for i in range(8):
        t = i / 7
        z = w.BODY_BOTTOM_Z - t * 0.020
        yc = 0.044 + 0.006 * t * t
        pf.append((yc + 0.0020, z))
        pb.append((yc - 0.0020, z))
    tr.prism(pf + list(reversed(pb)), axis="X", start=-0.0030, end=0.0030, mat=ts)
    c.finish(tr, "Trigger", bevel=0.0005, parent=body)
    ch = ctx.builder()
    cm = ch.material(mats.polymer())
    ch.prism([(-0.024, w.BODY_REAR_Y - 0.010), (0.024, w.BODY_REAR_Y - 0.010), (0.020, w.BODY_REAR_Y + 0.002),
              (-0.020, w.BODY_REAR_Y + 0.002)], axis="Z", start=w.BODY_TOP_Z - 0.012, end=w.BODY_TOP_Z - 0.003, mat=cm)
    c.finish(ch, "ChargingHandle", bevel=0.0012, parent=body)
    return body


def _barrel(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(0.0075, w.BARREL_END_Y - w.BODY_FRONT_Y + 0.010, segments=20,
                centre=(0.0, (w.BARREL_END_Y + w.BODY_FRONT_Y - 0.010) / 2, w.BORE_Z), axis="Y", mat=st)
    barrel = c.finish(mb, "Barrel", bevel=0.0004)
    fh = ctx.builder()
    fm = fh.material(mats.steel())
    y0, y1 = w.BARREL_END_Y, w.BARREL_END_Y + w.HIDER_LEN
    fh.cylinder(0.0095, 0.008, segments=20, centre=(0.0, y0 + 0.004, w.BORE_Z), axis="Y", mat=fm)
    for i in range(3):                                                                         # three prongs
        a = math.pi / 2 + i * 2 * math.pi / 3
        x, z = math.cos(a) * 0.0068, w.BORE_Z + math.sin(a) * 0.0068
        fh.box((x - 0.0025, y0 + 0.008, z - 0.0025), (x + 0.0025, y1, z + 0.0025), mat=fm)
    c.finish(fh, "FlashHider", bevel=0.0005, parent=barrel)
    return barrel


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _body(ctx, mats)
    _barrel(ctx, mats)

    ctx.marker("Muzzle", (0.0, w.MUZZLE_Y, w.BORE_Z))
    ctx.marker("BarrelMount", (0.0, w.BODY_FRONT_Y, w.BORE_Z))
    ctx.marker("Eject", (w.BODY_HW, 0.025, w.BORE_Z + 0.002), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, w.SIGHT_RAIL_Y, w.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", w.MAGWELL_POS, rotation_euler=w.MAGWELL_ROT)
    ctx.marker("Underbarrel", (0.0, w.UNDER_Y, w.BODY_BOTTOM_Z - 0.0057))
    ctx.marker("SideRail", (w.BODY_HW + 0.0057, w.SIDE_Y, w.BORE_Z - 0.008))
    stock_mount = ctx.marker("StockMount", w.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead ruling (round 211): the smg cup grip like hornet/lancet/tern (vgrip set = backlog): x 0, 12 mm under the body,
    # in the fore-end gap between the trigger guard (~y 0.075) and the moulded FrontGrip (y 0.131), clear of both.
    ctx.marker("LeftHandIK", (0.0, 0.100, w.BODY_BOTTOM_Z - 0.012))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = w.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, w.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    w.build_mag(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    w.build_stock(ctx, mats, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
