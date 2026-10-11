"""Tillman Brute 12: drum-fed fully automatic 12-gauge, first-person model (B4-18).

About 79 cm from the muzzle to the butt plate. Slab-sided receiver in a straight line with the
polymer buttstock, carry handle with a top rail, vented barrel shroud, 20-shell drum ahead of the
trigger guard.

Origin = firing-hand pivot on the grip (see _brute.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``Butt``, ``CarryHandle``, ``ReceiverDetails``, ``ChargingHandle``, ``TriggerGroup``, ``Grip``,
``Shroud``), ``Barrel``. Stock parts: ``SightRail/StockSight`` (carry-handle aperture + front post,
``AimPoint``), ``Magwell/StockMagazine`` (20-shell drum). ``StockMount`` = butt plate (no stock slot).
"""

import math

import _common as c
import _brute as u

ASSET_ID = "wpn_brute_12"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.matte())
    mb.prism(c.chamfer_rect(u.REC_HW, u.REC_BOTTOM_Z, u.REC_TOP_Z, 0.006), axis="Y", start=u.REC_REAR_Y,
             end=u.REC_FRONT_Y, mat=st)
    rec = c.finish(mb, "Receiver", bevel=0.0015, segments=2)
    bt = ctx.builder()
    poly = bt.material(mats.polymer())
    prof = [(u.REC_REAR_Y + 0.004, u.REC_TOP_Z - 0.004), (u.BUTT_Y + 0.010, u.REC_TOP_Z - 0.002),
            (u.BUTT_Y, u.REC_TOP_Z - 0.010), (u.BUTT_Y, -0.030), (u.BUTT_Y + 0.040, -0.032),
            (-0.150, 0.020), (u.REC_REAR_Y + 0.004, u.REC_BOTTOM_Z + 0.004)]
    bt.prism(prof, axis="X", start=-u.REC_HW + 0.003, end=u.REC_HW - 0.003, mat=poly)
    butt = c.finish(bt, "Butt", bevel=0.0030, segments=2, parent=rec)
    pd = ctx.builder()
    pd.box((-u.REC_HW + 0.002, u.BUTT_Y - 0.014, -0.032), (u.REC_HW - 0.002, u.BUTT_Y + 0.001, u.REC_TOP_Z - 0.008),
           mat=pd.material(mats.rubber()))
    c.finish(pd, "ButtPad", bevel=0.0025, segments=2, parent=butt)

    ch = ctx.builder()
    cm = ch.material(mats.matte())
    ch.box((-0.0130, u.HANDLE_Y0, u.HANDLE_TOP_Z - 0.008), (0.0130, u.HANDLE_Y1, u.HANDLE_TOP_Z), mat=cm)
    for y in (u.HANDLE_Y0, u.HANDLE_Y1 - 0.020):
        ch.box((-0.0120, y, u.REC_TOP_Z - 0.002), (0.0120, y + 0.020, u.HANDLE_TOP_Z - 0.006), mat=cm)
    handle = c.finish(ch, "CarryHandle", bevel=0.0012, segments=2, parent=rec)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), u.RAIL_Y0, u.RAIL_Y1, u.HANDLE_TOP_Z)
    c.finish(rl, "TopRail", bevel=0.0004, parent=handle)

    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    dt.box((u.REC_HW - 0.0005, 0.010, u.BORE_Z - 0.014), (u.REC_HW + 0.0005, 0.100, u.BORE_Z + 0.016), mat=dark)
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * (u.REC_HW - 0.0003), side * (u.REC_HW + 0.0010)))
        for z in (0.034, 0.088):
            dt.box((lo, u.REC_REAR_Y + 0.010, z - 0.002), (hi, u.REC_FRONT_Y - 0.010, z + 0.002), mat=s2)
        for y in (-0.060, 0.050, 0.220):
            dt.cylinder(0.0034, 0.0012, segments=12, centre=(side * (u.REC_HW + 0.0004), y, 0.060), axis="X", mat=s2)
    c.finish(dt, "ReceiverDetails", parent=rec)
    ch = ctx.builder()  # D-058: own node so ENV A can pull it back on bolt_release
    ch.box((-u.REC_HW - 0.014, 0.180, u.BORE_Z + 0.010), (-u.REC_HW, 0.194, u.BORE_Z + 0.020),
           mat=ch.material(mats.bare()))
    c.finish(ch, "ChargingHandle", bevel=0.0006, parent=rec)
    c.build_trigger_group(ctx, mats, 0.006 + u.GRIP_TAN * 0.010, 0.068, u.REC_BOTTOM_Z, -0.010, 0.034, parent=rec)
    c.build_grip(ctx, mats, "polymer", u.GRIP_TOP_Z, u.GRIP_BOTTOM_Z, 0.0200, 0.0155, u.GRIP_ANGLE_DEG, parent=rec,
                 finger_bumps=3)

    sh = ctx.builder()
    sm = sh.material(mats.matte())
    outer = c.rounded_rect(0.0220, 0.0240, 0.010, 0.0, u.BORE_Z, corner_segments=3)
    hole = list(reversed(c.circle(0.0140, 24, 0.0, u.BORE_Z)))
    sh.prism(outer, holes=[hole], axis="Y", start=u.REC_FRONT_Y, end=u.SHROUD_Y1, mat=sm)
    dk = sh.material(mats.polymer())
    for i in range(6):
        y = u.REC_FRONT_Y + 0.020 + i * 0.026
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * 0.0216, side * 0.0226))
            sh.box((lo, y, u.BORE_Z - 0.010), (hi, y + 0.014, u.BORE_Z + 0.010), mat=dk)
    shroud = c.finish(sh, "Shroud", bevel=0.0012, segments=1, parent=rec)
    sr = ctx.builder()
    c.rail_side(sr, sr.material(mats.alu()), u.SIDE_Y - 0.025, u.SIDE_Y + 0.025, 0.0220, u.BORE_Z, 1.0)
    c.finish(sr, "ShroudRail", bevel=0.0003, parent=shroud)
    return rec


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    c.build_barrel(ctx, mats, 0.0130, u.SHROUD_Y1 - 0.020, u.BARREL_END_Y, u.BORE_Z, bore_r=0.0092, segments=28)

    ctx.marker("Muzzle", (0.0, u.MUZZLE_Y, u.BORE_Z))
    ctx.marker("BarrelMount", (0.0, u.REC_FRONT_Y, u.BORE_Z))
    ctx.marker("Eject", (u.REC_HW, 0.050, u.BORE_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, u.SIGHT_RAIL_Y, u.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", u.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, u.UNDER_Y, u.BORE_Z - 0.024))
    ctx.marker("SideRail", (0.0220 + 0.0057, u.SIDE_Y, u.BORE_Z))
    ctx.marker("StockMount", u.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-0.026, u.UNDER_Y, u.BORE_Z - 0.016))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = u.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, u.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    u.build_drum(ctx, mats, big=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
