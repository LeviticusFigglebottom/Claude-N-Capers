"""Brannock Lancet .45: low-recoil .45 SMG, first-person model (B4-18).

About 36 cm from the muzzle to the stock hinge. Angular black polymer body with the bore low over the
hand, a deep chin ahead of the trigger guard that takes the magazine, full-length top rail, short lower
rail under the nose, three-prong flash hider, skeleton stock on a rear hinge block.

Origin = firing-hand pivot on the grip (see _lancet.py). Forward = Godot -Z.

Node tree: ``Body`` (+ ``BodyRail``, ``BodyDetails``, ``Grip``, ``TriggerGroup``), ``Barrel`` (+
``FlashHider``). Stock parts: ``SightRail/StockSight`` (flip-up irons, ``AimPoint``),
``Magwell/StockMagazine`` (25 rounds), ``StockMount/StockStock`` (skeleton stock).
"""

import math

import _common as c
import _lancet as v

ASSET_ID = "wpn_lancet_45"
TRI_BUDGET = 25000


def _body(ctx, mats):
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    prof = [(v.BODY_REAR_Y, v.BODY_TOP_Z), (v.BODY_FRONT_Y - 0.012, v.BODY_TOP_Z), (v.BODY_FRONT_Y, v.BODY_TOP_Z - 0.012),
            (v.BODY_FRONT_Y, v.BORE_Z - 0.016), (v.BODY_FRONT_Y - 0.020, v.BODY_BOTTOM_Z),
            (v.CHIN_Y1 + 0.006, v.BODY_BOTTOM_Z), (v.CHIN_Y1, v.CHIN_BOTTOM_Z),
            (v.CHIN_Y0 + 0.012, v.CHIN_BOTTOM_Z), (v.CHIN_Y0, v.BODY_BOTTOM_Z - 0.010),
            (v.CHIN_Y0 - 0.004, v.BODY_BOTTOM_Z), (-0.022, v.BODY_BOTTOM_Z), (-0.050, 0.036),
            (v.BODY_REAR_Y, 0.046)]
    mb.prism(prof, axis="X", start=-v.BODY_HW, end=v.BODY_HW, mat=poly)
    c.taper_x(mb, lambda y, z: 0.82 if z > v.BODY_TOP_Z - 0.008 else (0.86 if z < v.BODY_BOTTOM_Z - 0.004 else 1.0))
    body = c.finish(mb, "Body", bevel=0.0025, segments=2)

    rl = ctx.builder()
    ra = rl.material(mats.alu())
    rl.box((-0.0095, v.RAIL_Y0, v.BODY_TOP_Z - 0.003), (0.0095, v.RAIL_Y1, v.BODY_TOP_Z + 0.001), mat=ra)
    c.picatinny(rl, ra, v.RAIL_Y0, v.RAIL_Y1, v.BODY_TOP_Z)
    c.rail_side(rl, ra, v.UNDER_Y - 0.022, v.UNDER_Y + 0.022, 0.0, v.BODY_BOTTOM_Z + 0.0005, 0.0)
    c.rail_side(rl, ra, v.SIDE_Y - 0.020, v.SIDE_Y + 0.020, v.BODY_HW - 0.0005, v.BORE_Z + 0.012, 1.0)
    c.finish(rl, "BodyRail", bevel=0.0004, parent=body)

    dt = ctx.builder()
    dark = dt.material(mats.stipple())
    s2 = dt.material(mats.steel())
    dt.box((v.BODY_HW - 0.0005, -0.010, v.BORE_Z), (v.BODY_HW + 0.0004, 0.050, v.BORE_Z + 0.020), mat=dark)  # port
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * (v.BODY_HW - 0.0004), side * (v.BODY_HW + 0.0005)))
        dt.box((lo, v.CHIN_Y0 + 0.010, v.CHIN_BOTTOM_Z + 0.006), (hi, v.CHIN_Y1 - 0.008, v.BODY_BOTTOM_Z + 0.010),
               mat=dark)                                                                        # chin panel
        for y in (-0.060, 0.120):
            dt.cylinder(0.0028, 0.0012, segments=12, centre=(side * (v.BODY_HW + 0.0002), y, v.BORE_Z + 0.030),
                        axis="X", mat=s2)
    dt.box((-v.BODY_HW - 0.010, 0.060, v.BORE_Z + 0.016), (-v.BODY_HW, 0.072, v.BORE_Z + 0.026), mat=s2)  # charger
    dt.cylinder(0.0055, 0.0028, segments=18, centre=(-v.BODY_HW - 0.0012, -0.012, 0.040), axis="X", mat=s2)
    dt.box((-v.BODY_HW - 0.0026, -0.012, 0.038), (-v.BODY_HW - 0.0010, 0.006, 0.042), mat=s2)        # selector
    c.finish(dt, "BodyDetails", bevel=0.0002, parent=body)

    c.build_trigger_group(ctx, mats, v.GRIP_HALF_DEPTH + v.GRIP_TAN * 0.010, v.CHIN_Y0, v.BODY_BOTTOM_Z, -0.010,
                          0.042, mat_name="polymer", parent=body)
    g = c.build_grip(ctx, mats, "polymer", v.GRIP_TOP_Z, v.GRIP_BOTTOM_Z, v.GRIP_HALF_DEPTH, v.GRIP_HALF_WIDTH,
                     v.GRIP_ANGLE_DEG, parent=body, finger_bumps=3)
    gt = ctx.builder()
    gm = gt.material(mats.stipple())
    for side in (-1.0, 1.0):
        x = side * (v.GRIP_HALF_WIDTH - 0.0001)
        for r in range(9):
            z = -0.064 + r * 0.008
            yy = -v.GRIP_HALF_DEPTH + v.GRIP_TAN * z + 0.006 + (0.004 if r % 2 else 0.0)
            while yy < v.GRIP_HALF_DEPTH + v.GRIP_TAN * z - 0.006:
                c.pyramid(gt.bm, c.Vector((x, yy, z)), c.Vector((0, 1, 0)), c.Vector((0, 0, 1)), c.Vector((side, 0, 0)),
                          0.0016, 0.0006, gm)
                yy += 0.008
    c.finish(gt, "GripTexture", parent=g)
    return body


def _barrel(ctx, mats):
    barrel = c.build_barrel(ctx, mats, 0.0090, v.BODY_FRONT_Y - 0.010, v.BARREL_END_Y, v.BORE_Z, bore_r=0.0058,
                            segments=24)
    fh = ctx.builder()
    fm = fh.material(mats.steel())
    y0, y1 = v.BARREL_END_Y, v.BARREL_END_Y + v.HIDER_LEN
    fh.cylinder(0.0110, 0.008, segments=20, centre=(0.0, y0 + 0.004, v.BORE_Z), axis="Y", mat=fm)
    for i in range(3):
        a = math.pi / 2 + i * 2 * math.pi / 3
        x, z = math.cos(a) * 0.0080, v.BORE_Z + math.sin(a) * 0.0080
        fh.box((x - 0.0028, y0 + 0.008, z - 0.0028), (x + 0.0028, y1, z + 0.0028), mat=fm)
    c.finish(fh, "FlashHider", bevel=0.0005, parent=barrel)
    return barrel


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _body(ctx, mats)
    _barrel(ctx, mats)

    ctx.marker("Muzzle", (0.0, v.MUZZLE_Y, v.BORE_Z))
    ctx.marker("BarrelMount", (0.0, v.BODY_FRONT_Y, v.BORE_Z))
    ctx.marker("Eject", (v.BODY_HW, 0.020, v.BORE_Z + 0.010), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, v.SIGHT_RAIL_Y, v.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", v.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, v.UNDER_Y, v.BODY_BOTTOM_Z - 0.0057))
    ctx.marker("SideRail", (v.BODY_HW + 0.0057, v.SIDE_Y, v.BORE_Z + 0.012))
    stock_mount = ctx.marker("StockMount", v.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup for the smg set): under the forward body (magwell front y 0.133 to body front 0.200, bottom z 0.022), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.155, 0.010))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = v.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, v.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    v.build_mag(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    v.build_stock(ctx, mats, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
