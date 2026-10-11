"""Brannock Thumper 40: break-open single-shot 40 mm grenade launcher, first-person model (B4-18).

About 35 cm from the muzzle to the wrist (plus a 26 cm walnut stock). Steel receiver block, fat
27 cm barrel with a short top rail and a folding ladder sight, walnut forend and pistol-grip stock.

Origin = firing-hand pivot on the grip (see _thumper.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``ReceiverDetails``, ``TriggerGroup``, ``Grip``), ``Breech`` (barrel + forend +
rail; origin = hinge pin; carries ``SightRail``, ``Muzzle``, ``BarrelMount``, ``Magwell/StockMagazine``,
``Underbarrel``, ``SideRail``, ``LeftHandIK``, ``Eject``). Stock parts: ``SightRail/StockSight`` (leaf +
front post, ``AimPoint``), ``StockMount/StockStock`` (walnut stock).
"""

import math

import _common as c
import _thumper as h

ASSET_ID = "wpn_thumper_40"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    prof = [(h.REC_REAR_Y, h.REC_TOP_Z - 0.014), (h.REC_REAR_Y + 0.016, h.REC_TOP_Z), (h.REC_FRONT_Y, h.REC_TOP_Z),
            (h.REC_FRONT_Y, h.REC_BOTTOM_Z), (h.REC_REAR_Y + 0.006, h.REC_BOTTOM_Z)]
    mb.prism(prof, axis="X", start=-h.REC_HW, end=h.REC_HW, mat=st)
    rec = c.finish(mb, "Receiver", bevel=0.0015, segments=2)
    dt = ctx.builder()
    br = dt.material(mats.bare())
    dt.box((-0.0090, 0.000, h.REC_TOP_Z - 0.001), (0.0090, 0.040, h.REC_TOP_Z + 0.006), mat=br)          # latch lever
    dt.box((-0.0040, h.REC_REAR_Y + 0.002, h.REC_TOP_Z - 0.004), (0.0040, 0.000, h.REC_TOP_Z + 0.004), mat=br)
    for side in (-1.0, 1.0):
        dt.cylinder(0.0045, 0.0012, segments=14, centre=(side * (h.REC_HW + 0.0004), 0.044, h.HINGE[2]), axis="X",
                    mat=br)
    c.finish(dt, "ReceiverDetails", bevel=0.0003, parent=rec)
    c.build_trigger_group(ctx, mats, 0.006 + 0.010 * math.tan(math.radians(h.GRIP_ANGLE_DEG)), 0.060,
                          h.REC_BOTTOM_Z, -0.012, 0.030, parent=rec)
    c.build_grip(ctx, mats, "wood", h.GRIP_TOP_Z, h.GRIP_BOTTOM_Z, 0.0200, 0.0160, h.GRIP_ANGLE_DEG, parent=rec,
                 finger_bumps=0, palm_swell=0.004)
    return rec


def _breech(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    c.ring_y(mb, h.BARREL_R, h.BORE_R, h.REC_FRONT_Y + 0.002, h.BARREL_END_Y, h.BORE_Z, st, segments=36)
    mb.cylinder(h.BARREL_R + 0.0015, 0.012, segments=36, centre=(0.0, h.BARREL_END_Y - 0.006, h.BORE_Z), axis="Y",
                mat=st)
    mb.box((-0.0140, h.REC_FRONT_Y, h.REC_BOTTOM_Z), (0.0140, h.FOREND_Y0 + 0.004, h.BORE_Z - h.BARREL_R + 0.004),
           mat=st)                                                                                  # hinge lug
    rl = mb.material(mats.alu())
    mb.box((-0.0095, h.RAIL_Y0, h.RAIL_BASE_Z - 0.004), (0.0095, h.RAIL_Y1, h.RAIL_BASE_Z), mat=rl)
    c.picatinny(mb, rl, h.RAIL_Y0, h.RAIL_Y1, h.RAIL_BASE_Z)
    mb.translate(tuple(-v for v in h.HINGE))
    breech = c.finish(mb, "Breech", bevel=0.0006, segments=1)
    breech.location = h.HINGE
    fe = ctx.builder()
    wd = fe.material(mats.wood())
    zc = h.BORE_Z - h.BARREL_R - 0.006
    fe.prism(c.rounded_rect(0.0230, 0.0150, 0.010, 0.0, zc, corner_segments=3), axis="Y", start=h.FOREND_Y0,
             end=h.FOREND_Y1, mat=wd)
    fe.translate(tuple(-v for v in h.HINGE))
    c.finish(fe, "Forend", bevel=0.0020, segments=2, parent=breech)

    ctx.marker("Muzzle", h.hinge_local((0.0, h.MUZZLE_Y, h.BORE_Z)), parent=breech)
    ctx.marker("BarrelMount", h.hinge_local((0.0, h.REC_FRONT_Y + 0.002, h.BORE_Z)), parent=breech)
    sight_rail = ctx.marker("SightRail", h.hinge_local((0.0, h.SIGHT_RAIL_Y, h.RAIL_TOP_Z)), parent=breech)
    magwell = ctx.marker("Magwell", h.hinge_local((0.0, h.REC_FRONT_Y + 0.003, h.BORE_Z)),
                         rotation_euler=(-math.pi / 2, 0.0, 0.0), parent=breech)
    ctx.marker("Underbarrel", h.hinge_local((0.0, h.UNDER_Y, zc - 0.015)), parent=breech)
    ctx.marker("SideRail", h.hinge_local((h.BARREL_R + 0.002, 0.280, h.BORE_Z)), parent=breech)
    ctx.marker("LeftHandIK", h.hinge_local((-0.024, h.UNDER_Y, zc)), parent=breech)
    ctx.marker("Eject", h.hinge_local((h.BARREL_R, h.REC_FRONT_Y + 0.010, h.BORE_Z)),
               rotation_euler=(0.0, 0.0, -math.pi / 2), parent=breech)
    return sight_rail, magwell


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    sight_rail, magwell = _breech(ctx, mats)
    stock_mount = ctx.marker("StockMount", h.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _leaf, aim = h.build_leaf(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, -0.040, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    h.build_grenade(ctx, mats, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    h.build_stock(ctx, mats, stockless=False, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
