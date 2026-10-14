"""Tillman Hush 9: integrally suppressed 9 mm SMG, first-person model (B4-18).

About 50 cm from the muzzle to the receiver end cap. Round-topped stamped receiver with a clamp-on rail,
polymer trigger housing and grip, curved magazine ahead of the guard, slim polymer handguard over the
rear of a fat integral suppressor, cocking tube on the upper left, retractable two-rail stock.
Suppressed out of the box (data: ``suppressed``), so it has no ``SUPPRESSOR`` slot.

Origin = firing-hand pivot on the grip (see _hush.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``ClawRail``, ``ReceiverDetails``, ``TriggerHousing``, ``Grip``,
``Handguard``, ``CockingTube``), ``Can`` (integral suppressor). Stock parts: ``SightRail/StockSight``
(rear aperture + hooded front post, ``AimPoint``), ``Magwell/StockMagazine``, ``StockMount/StockStock``.
"""

import math

import _common as c
import _hush as h

ASSET_ID = "wpn_hush_9"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    cross = c.rounded_rect(h.REC_HW, (h.REC_TOP_Z - h.REC_BOTTOM_Z) / 2, 0.012, 0.0,
                           (h.REC_TOP_Z + h.REC_BOTTOM_Z) / 2, corner_segments=4)
    mb.prism(cross, axis="Y", start=h.REC_REAR_Y, end=h.REC_FRONT_Y, mat=st)
    rec = c.finish(mb, "Receiver", bevel=0.0010, segments=1)

    rl = ctx.builder()
    ra = rl.material(mats.alu())
    for y in (h.RAIL_Y0 + 0.010, h.RAIL_Y1 - 0.010):                                    # claw clamps
        rl.box((-h.REC_HW - 0.002, y - 0.008, h.REC_TOP_Z - 0.014), (h.REC_HW + 0.002, y + 0.008, h.REC_TOP_Z), mat=ra)
    c.picatinny(rl, ra, h.RAIL_Y0, h.RAIL_Y1, h.REC_TOP_Z)
    c.finish(rl, "ClawRail", bevel=0.0004, parent=rec)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    dt.box((h.REC_HW - 0.0005, 0.010, h.BORE_Z - 0.008), (h.REC_HW + 0.0006, 0.060, h.BORE_Z + 0.012), mat=dark)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * (h.REC_HW - 0.0003), side * (h.REC_HW + 0.0009)))
        dt.box((lo, h.REC_REAR_Y + 0.010, h.BORE_Z - 0.002), (hi, h.REC_FRONT_Y - 0.010, h.BORE_Z + 0.004), mat=s2)
        for y in (-0.070, 0.100):
            dt.cylinder(0.0028, 0.0012, segments=10, centre=(side * (h.REC_HW + 0.0004), y, 0.050), axis="X", mat=s2)
    c.finish(dt, "ReceiverDetails", parent=rec)

    th = ctx.builder()
    poly = th.material(mats.polymer())
    prof = [(-0.050, h.REC_BOTTOM_Z + 0.002), (0.070, h.REC_BOTTOM_Z + 0.002), (0.070, 0.030), (0.060, 0.022),
            (-0.030, 0.022), (-0.050, 0.030)]
    th.prism(prof, axis="X", start=-0.0165, end=0.0165, mat=poly)
    th.cylinder(0.0060, 0.0030, segments=18, centre=(-0.0180, -0.030, 0.032), axis="X", mat=poly)     # selector
    c.finish(th, "TriggerHousing", bevel=0.0015, segments=2, parent=rec)
    c.build_trigger_group(ctx, mats, 0.010 + h.GRIP_TAN * 0.010, 0.068, 0.023, -0.010, 0.036, mat_name="polymer",
                          parent=rec)
    c.build_grip(ctx, mats, "polymer", h.GRIP_TOP_Z, h.GRIP_BOTTOM_Z, 0.0200, 0.0150, h.GRIP_ANGLE_DEG, parent=rec,
                 finger_bumps=3)

    hg = ctx.builder()
    hm = hg.material(mats.polymer())
    outer = c.rounded_rect(h.CAN_R + 0.0050, h.CAN_R + 0.0040, 0.012, 0.0, h.BORE_Z - 0.002, corner_segments=4)
    hole = list(reversed(c.circle(h.CAN_R + 0.0004, 32, 0.0, h.BORE_Z)))
    hg.prism(outer, holes=[hole], axis="Y", start=h.REC_FRONT_Y - 0.004, end=h.HG_Y1, mat=hm)
    for i in range(4):                                                                      # finger grooves
        y = h.REC_FRONT_Y + 0.030 + i * 0.020
        hg.box((-h.CAN_R - 0.0060, y, h.BORE_Z - 0.016), (h.CAN_R + 0.0060, y + 0.006, h.BORE_Z - 0.004), mat=hm)
    c.finish(hg, "Handguard", bevel=0.0015, segments=2, parent=rec)
    ct = ctx.builder()
    cm = ct.material(mats.steel())
    ct.cylinder(0.0070, 0.200, segments=16, centre=(-0.012, h.REC_FRONT_Y + 0.060, h.REC_TOP_Z - 0.006), axis="Y",
                mat=cm)
    ct.box((-0.032, h.REC_FRONT_Y - 0.020, h.REC_TOP_Z - 0.010), (-0.016, h.REC_FRONT_Y - 0.010, h.REC_TOP_Z - 0.002),
           mat=cm)                                                                          # cocking handle
    c.finish(ct, "CockingTube", bevel=0.0006, parent=rec)
    return rec


def _can(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.matte())
    mb.cylinder(h.CAN_R, h.CAN_Y1 - h.CAN_Y0, segments=40, centre=(0.0, (h.CAN_Y0 + h.CAN_Y1) / 2, h.BORE_Z), axis="Y",
                mat=st)
    for y in (h.HG_Y1 + 0.012, h.CAN_Y1 - 0.014):
        mb.cylinder(h.CAN_R + 0.0008, 0.006, segments=40, centre=(0.0, y, h.BORE_Z), axis="Y", mat=st)
    can = c.finish(mb, "Can", bevel=0.0010, segments=2)
    cp = ctx.builder()
    cm = cp.material(mats.steel())
    c.ring_y(cp, h.CAN_R - 0.0010, 0.0050, h.CAN_Y1, h.CAN_Y1 + 0.004, h.BORE_Z, cm, segments=40)
    cp.cylinder(0.0051, 0.001, segments=20, centre=(0.0, h.CAN_Y1 + 0.0015, h.BORE_Z), axis="Y",
                mat=cp.material(mats.polymer()))
    c.finish(cp, "CanCap", bevel=0.0006, parent=can)
    return can


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    _can(ctx, mats)

    ctx.marker("Muzzle", (0.0, h.MUZZLE_Y, h.BORE_Z))
    ctx.marker("BarrelMount", (0.0, h.REC_FRONT_Y, h.BORE_Z))
    ctx.marker("Eject", (h.REC_HW, 0.035, h.BORE_Z + 0.002), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, h.SIGHT_RAIL_Y, h.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", h.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, h.UNDER_Y, h.BORE_Z - h.CAN_R - 0.008))
    ctx.marker("SideRail", (h.CAN_R + 0.006, h.SIDE_Y, h.BORE_Z))
    stock_mount = ctx.marker("StockMount", h.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Handguard (y 0.146-0.270, bottom z 0.039), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.187, 0.027))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = h.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, h.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    h.build_mag(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    h.build_stock(ctx, mats, collapsed=False, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
