"""Marrow & Kell Reaper Double: side-by-side break-action 12-gauge, first-person model (B4-18).

About 72 cm from the muzzles to the wrist (plus a 29 cm walnut buttstock). Blued action block with a top
tang, 61 cm side-by-side barrels with a rib and brass bead, walnut splinter forend and pistol-grip wrist.

Origin = firing-hand pivot on the wrist (see _reaper.py). Forward = Godot -Z.

Node tree: ``Action`` (+ ``ActionDetails``, ``TriggerGroup``, ``Grip``), ``Breech`` (the forend mesh;
origin = hinge pin; carries ``BarrelMount/StockBarrel``, ``Muzzle``, ``Magwell/StockMagazine`` with two
shells, ``Underbarrel``, ``SideRail``, ``LeftHandIK`` and ``Eject``). Stock parts:
``SightRail/StockSight`` (tang notch, ``AimPoint``), ``StockMount/StockStock`` (walnut buttstock).
"""

import math

import _common as c
import _reaper as r

ASSET_ID = "wpn_reaper_db"
TRI_BUDGET = 25000


def _action(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    prof = [(r.ACT_REAR_Y, r.ACT_TOP_Z - 0.012), (r.ACT_REAR_Y + 0.012, r.ACT_TOP_Z), (r.ACT_FRONT_Y, r.ACT_TOP_Z),
            (r.ACT_FRONT_Y, r.ACT_BOTTOM_Z + 0.010), (r.ACT_FRONT_Y - 0.012, r.ACT_BOTTOM_Z),
            (r.ACT_REAR_Y + 0.004, r.ACT_BOTTOM_Z)]
    mb.prism(prof, axis="X", start=-r.ACT_HW, end=r.ACT_HW, mat=st)
    mb.box((-0.0070, -0.060, r.ACT_TOP_Z - 0.006), (0.0070, r.ACT_REAR_Y + 0.004, r.ACT_TOP_Z), mat=st)   # top tang
    mb.box((-0.0100, 0.020, r.ACT_TOP_Z - 0.001), (0.0100, 0.044, r.ACT_TOP_Z + 0.004), mat=st)          # top lever
    act = c.finish(mb, "Action", bevel=0.0012, segments=2)
    dt = ctx.builder()
    br = dt.material(mats.bare())
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * (r.ACT_HW - 0.0003), side * (r.ACT_HW + 0.0006)))
        dt.box((lo, r.ACT_REAR_Y + 0.010, r.ACT_BOTTOM_Z + 0.008), (hi, r.ACT_FRONT_Y - 0.010, r.ACT_TOP_Z - 0.008),
               mat=br)                                                                           # side plates
        dt.cylinder(0.0040, 0.0012, segments=14, centre=(side * (r.ACT_HW + 0.0008), 0.040, 0.040), axis="X", mat=br)
    dt.box((-0.0090, -0.004, r.ACT_TOP_Z - 0.0005), (0.0090, 0.016, r.ACT_TOP_Z + 0.0025), mat=br)       # safety
    c.finish(dt, "ActionDetails", bevel=0.0003, parent=act)
    c.build_trigger_group(ctx, mats, 0.004 + r.GRIP_TAN * 0.012, 0.064, r.ACT_BOTTOM_Z, -0.012, 0.026, parent=act)
    tr = ctx.builder()
    tm = tr.material(mats.steel())
    tr.box((-0.0028, 0.040, -0.002), (0.0028, 0.045, r.ACT_BOTTOM_Z), mat=tm)                          # 2nd trigger
    c.finish(tr, "RearTrigger", bevel=0.0005, parent=act)
    g = c.build_grip(ctx, mats, "wood", r.GRIP_TOP_Z, r.GRIP_BOTTOM_Z, 0.0190, 0.0160, r.GRIP_ANGLE_DEG, parent=act,
                     finger_bumps=0, palm_swell=0.004)
    cap = ctx.builder()
    zb = r.GRIP_BOTTOM_Z
    cap.box((-0.0150, -0.019 + r.GRIP_TAN * zb - 0.003, zb - 0.004), (0.0150, 0.019 + r.GRIP_TAN * zb - 0.002, zb + 0.001),
            mat=cap.material(mats.steel()))
    c.finish(cap, "GripCap", bevel=0.0012, segments=2, parent=g)
    return act


def _breech(ctx, mats):
    mb = ctx.builder()
    wood = mb.material(mats.wood())
    zc = r.BORE_Z - 0.022
    prof = c.rounded_rect(0.0215, 0.0150, 0.010, 0.0, zc, corner_segments=3)
    mb.prism(prof, axis="Y", start=r.FOREND_Y0, end=r.FOREND_Y1, mat=wood)
    c.taper_x(mb, lambda y, z: 1.0 - 0.25 * max(0.0, (y - r.FOREND_Y1 + 0.060) / 0.060))
    mb.box((-0.0160, r.ACT_FRONT_Y + 0.002, r.ACT_BOTTOM_Z), (0.0160, r.FOREND_Y0 + 0.002, r.ACT_BOTTOM_Z + 0.018),
           mat=mb.material(mats.steel()))                                                        # forend iron
    mb.translate(tuple(-v for v in r.HINGE))
    breech = c.finish(mb, "Breech", bevel=0.0015, segments=2)
    breech.location = r.HINGE
    bmount = ctx.marker("BarrelMount", r.hinge_local((0.0, r.ACT_FRONT_Y + 0.001, r.BORE_Z)), parent=breech)
    sb = ctx.marker("StockBarrel", (0.0, 0.0, 0.0), parent=bmount)
    r.build_barrels(ctx, mats, r.BARREL_END_Y, parent=sb)
    ctx.marker("Muzzle", r.hinge_local((0.0, r.MUZZLE_Y, r.BORE_Z)), parent=breech)
    magwell = ctx.marker("Magwell", r.hinge_local((0.0, r.ACT_FRONT_Y + 0.001, r.BORE_Z)),
                         rotation_euler=(-math.pi / 2, 0.0, 0.0), parent=breech)
    sm = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    r.build_shells(ctx, mats, parent=sm)
    under = r.hinge_local((0.0, 0.200, r.BORE_Z - 0.022 - 0.0155))
    ctx.marker("Underbarrel", under, parent=breech)
    ctx.marker("SideRail", r.hinge_local((0.0220, 0.200, r.BORE_Z - 0.022)), parent=breech)
    # Lead (ENV D, FP left-hand cup): under the Breech fore-end (y 0.072-0.300, bottom z 0.017), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", r.hinge_local((0.0, 0.148, 0.005)), parent=breech)
    ctx.marker("Eject", r.hinge_local((r.BARREL_X + r.BARREL_R, r.ACT_FRONT_Y + 0.004, r.BORE_Z)),
               rotation_euler=(0.0, 0.0, -math.pi / 2), parent=breech)
    return breech


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _action(ctx, mats)
    _breech(ctx, mats)

    sight_rail = ctx.marker("SightRail", (0.0, r.SIGHT_RAIL_Y, r.RAIL_TOP_Z))
    stock_mount = ctx.marker("StockMount", r.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _s, h = r.build_tang_sight(ctx, mats, fiber=False, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, -0.006, h), parent=stock_sight)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    r.build_stock(ctx, mats, sawn=False, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: wrist centre plane, mid grip depth, 20 mm below the wrist top"
