"""Halvard Arms Sparrow MP: select-fire 9 mm machine pistol, first-person model (B4-12).

About 21 cm long. Black polymer frame with a long dust-cover rail and a front hand-stop, steel slide
with a ported muzzle shroud, left-side fire selector, 20-round magazine standing proud of the grip on
a flared base pad. Chunkier and more aggressive than the Kestrel P9.

Origin = firing-hand pivot (see _sparrow.py). Forward = Godot -Z.

Node tree: ``Frame`` (+ ``GripTexture``, ``Trigger``, ``Controls``, ``FrameRail``), ``Barrel``, ``Slide``
(+ ``SlideDetails``, ``Shroud``; slide-mounted ``SightRail`` and ``Eject``; ENV A cycles it along local
+Z). Stock parts: ``SightRail/StockSight`` (rear sight, ``AimPoint``), ``Magwell/StockMagazine``.
"""

import math

import _common as c
import _sparrow as s

ASSET_ID = "wpn_sparrow_mp"
TRI_BUDGET = 25000


def _slide(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    hw = s.SLIDE_HW
    cross = [(-hw, s.SLIDE_BOTTOM_Z), (hw, s.SLIDE_BOTTOM_Z), (hw, s.SLIDE_TOP_Z - 0.006), (hw - 0.004, s.SLIDE_TOP_Z),
             (-hw + 0.004, s.SLIDE_TOP_Z), (-hw, s.SLIDE_TOP_Z - 0.006)]
    mb.prism(cross, axis="Y", start=s.SLIDE_REAR_Y, end=s.SLIDE_FRONT_Y, mat=st)
    slide = c.finish(mb, "Slide", bevel=0.0010, segments=2)
    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.steel())
    for side in (-1.0, 1.0):                                         # front + rear serrations
        lo, hi = sorted((side * (hw - 0.0004), side * (hw + 0.0003)))
        for y0 in (s.SLIDE_REAR_Y + 0.006, s.SLIDE_FRONT_Y - 0.034):
            for i in range(6):
                y = y0 + i * 0.0040
                dt.box((lo, y, s.SLIDE_BOTTOM_Z + 0.006), (hi, y + 0.0018, s.SLIDE_TOP_Z - 0.006), mat=dark)
    dt.box((hw - 0.0005, 0.004, s.BORE_Z - 0.002), (hw + 0.0004, 0.042, s.SLIDE_TOP_Z - 0.004), mat=dark)  # port
    dt.box((-0.0016, s.FRONT_SIGHT_Y - 0.004, s.SLIDE_TOP_Z - 0.0005),
           (0.0016, s.FRONT_SIGHT_Y + 0.004, s.SLIDE_TOP_Z + s.SIGHT_DZ), mat=s2)                         # front post
    details = c.finish(dt, "SlideDetails", bevel=0.0003, parent=slide)
    dots = ctx.builder()
    dots.cylinder(0.0009, 0.0006, segments=12, centre=(0.0, s.FRONT_SIGHT_Y - 0.0042, s.SLIDE_TOP_Z + s.SIGHT_DZ - 0.0012),
                  axis="Y", mat=dots.material(mats.dot()))
    c.finish(dots, "FrontSightDot", parent=details)
    # ported muzzle shroud (moves with the slide)
    sh = ctx.builder()
    sm = sh.material(mats.steel())
    sd = sh.material(mats.polymer())
    prof = [(-hw + 0.001, s.SLIDE_BOTTOM_Z + 0.002), (hw - 0.001, s.SLIDE_BOTTOM_Z + 0.002), (hw - 0.001, s.SLIDE_TOP_Z - 0.008),
            (hw - 0.005, s.SLIDE_TOP_Z - 0.003), (-hw + 0.005, s.SLIDE_TOP_Z - 0.003), (-hw + 0.001, s.SLIDE_TOP_Z - 0.008)]
    sh.prism(prof, axis="Y", start=s.SLIDE_FRONT_Y - 0.001, end=s.SLIDE_FRONT_Y + s.SHROUD_LEN, mat=sm)
    for i in range(3):
        y = s.SLIDE_FRONT_Y + 0.005 + i * 0.008
        sh.box((-0.0045, y, s.SLIDE_TOP_Z - 0.0034), (0.0045, y + 0.005, s.SLIDE_TOP_Z - 0.0026), mat=sd)
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * (hw - 0.0014), side * (hw - 0.0006)))
            sh.box((lo, y, s.BORE_Z - 0.003), (hi, y + 0.005, s.BORE_Z + 0.006), mat=sd)
    sh.cylinder(0.0055, 0.001, segments=20, centre=(0.0, s.SLIDE_FRONT_Y + s.SHROUD_LEN + 0.0004, s.BORE_Z), axis="Y",
                mat=sd)
    c.finish(sh, "Shroud", bevel=0.0008, segments=1, parent=slide)
    return slide


def _barrel(ctx, mats):
    mb = ctx.builder()
    bare = mb.material(mats.bare())
    c.ring_y(mb, 0.0072, 0.0046, -0.020, s.MUZZLE_Y - 0.004, s.BORE_Z, bare, segments=20)
    mb.box((-0.0074, -0.020, s.BORE_Z), (0.0074, 0.042, s.BORE_Z + 0.0100), mat=bare)
    return c.finish(mb, "Barrel", bevel=0.0004)


def _frame(ctx, mats):
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    upper = [(-0.044, s.FRAME_TOP_Z), (s.FRAME_FRONT_Y, s.FRAME_TOP_Z), (s.FRAME_FRONT_Y, s.FRAME_BOTTOM_Z - 0.004),
             (s.FRAME_FRONT_Y - 0.010, s.FRAME_BOTTOM_Z - 0.012), (s.FRAME_FRONT_Y - 0.020, s.FRAME_BOTTOM_Z - 0.012),
             (s.FRAME_FRONT_Y - 0.024, s.FRAME_BOTTOM_Z), (-0.012, s.FRAME_BOTTOM_Z), (-0.036, 0.020),
             (-0.050, 0.024), (-0.052, 0.030)]                                               # beavertail + hand-stop
    mb.prism(upper, axis="X", start=-s.FRAME_HW, end=s.FRAME_HW, mat=poly)
    zt = s.GRIP_TOP_Z + 0.003
    grip = [(s.GRIP_HALF_DEPTH + s.GRIP_TAN * zt, zt),
            (s.GRIP_HALF_DEPTH + s.GRIP_TAN * s.GRIP_BOTTOM_Z, s.GRIP_BOTTOM_Z),
            (-s.GRIP_HALF_DEPTH + s.GRIP_TAN * s.GRIP_BOTTOM_Z - 0.001, s.GRIP_BOTTOM_Z),
            (-s.GRIP_HALF_DEPTH + s.GRIP_TAN * -0.030 - 0.0020, -0.030),
            (-s.GRIP_HALF_DEPTH + s.GRIP_TAN * zt, zt), (-0.036, 0.022)]
    mb.prism(grip, axis="X", start=-s.GRIP_HALF_WIDTH, end=s.GRIP_HALF_WIDTH, mat=poly)
    gy = s.GRIP_HALF_DEPTH + s.GRIP_TAN * -0.004
    outer = [(gy - 0.002, s.FRAME_BOTTOM_Z + 0.001), (0.078, s.FRAME_BOTTOM_Z + 0.001), (0.082, 0.006),
             (0.080, -0.006), (0.070, -0.012), (gy + 0.002, -0.012), (gy - 0.003, -0.006)]
    hole = [(s.GRIP_HALF_DEPTH + s.GRIP_TAN * 0.016 + 0.001, 0.016), (0.070, 0.016), (0.074, 0.006),
            (0.072, -0.002), (0.066, -0.006), (gy + 0.0035, -0.006)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0065, end=0.0065, mat=poly)
    frame = c.finish(mb, "Frame", bevel=0.0016, segments=2)

    gt = ctx.builder()
    gm = gt.material(mats.stipple())
    for side in (-1.0, 1.0):
        x = side * (s.GRIP_HALF_WIDTH - 0.0001)
        for r in range(11):
            z = -0.062 + r * 0.0058
            yb = -s.GRIP_HALF_DEPTH + s.GRIP_TAN * z + 0.006
            yf = s.GRIP_HALF_DEPTH + s.GRIP_TAN * z - 0.007
            yy = yb + (0.0029 if r % 2 else 0.0)
            while yy < yf:
                c.pyramid(gt.bm, c.Vector((x, yy, z)), c.Vector((0, 1, 0)), c.Vector((0, 0, 1)),
                          c.Vector((side, 0, 0)), 0.0013, 0.0005, gm)
                yy += 0.0058
    c.finish(gt, "GripTexture", parent=frame)
    rl = ctx.builder()
    ra = rl.material(mats.polymer())
    c.rail_side(rl, ra, s.RAIL_Y - 0.030, s.RAIL_Y + 0.020, 0.0, s.FRAME_BOTTOM_Z + 0.0005, 0.0)
    c.finish(rl, "FrameRail", bevel=0.0003, parent=frame)
    tr = ctx.builder()
    tm = tr.material(mats.steel())
    pf, pb = [], []
    for i in range(8):
        t = i / 7
        z = s.FRAME_BOTTOM_Z - t * 0.020
        yc = 0.046 + 0.006 * t * t
        pf.append((yc + 0.0020, z))
        pb.append((yc - 0.0020, z))
    tr.prism(pf + list(reversed(pb)), axis="X", start=-0.0030, end=0.0030, mat=tm)
    c.finish(tr, "Trigger", bevel=0.0005, parent=frame)
    ct = ctx.builder()
    cs = ct.material(mats.bare())
    ct.cylinder(0.0060, 0.0020, segments=18, centre=(-s.FRAME_HW - 0.0010, -0.028, 0.028), axis="X", mat=cs)  # selector
    ct.box((-s.FRAME_HW - 0.0022, -0.028, 0.026), (-s.FRAME_HW - 0.0006, -0.010, 0.030), mat=cs)
    ct.box((-s.FRAME_HW - 0.0014, 0.012, 0.030), (-s.FRAME_HW + 0.0003, 0.046, 0.035), mat=cs)              # slide stop
    ct.cylinder(0.0034, 0.0020, segments=16, centre=(-s.GRIP_HALF_WIDTH - 0.0008, 0.034, 0.010), axis="X", mat=cs)
    c.finish(ct, "Controls", bevel=0.0004, parent=frame)
    return frame


def build(ctx) -> None:
    mats = c.Mats(ctx)
    frame = _frame(ctx, mats)
    _barrel(ctx, mats)
    slide = _slide(ctx, mats)

    ctx.marker("Muzzle", (0.0, s.MUZZLE_Y, s.BORE_Z))
    ctx.marker("BarrelMount", (0.0, -0.020, s.BORE_Z))
    ctx.marker("Eject", (s.SLIDE_HW, 0.024, s.BORE_Z + 0.008), rotation_euler=(0.0, 0.0, -math.pi / 2), parent=slide)
    sight_rail = ctx.marker("SightRail", (0.0, s.SIGHT_RAIL_Y, s.SLIDE_TOP_Z), parent=slide)
    magwell = ctx.marker("Magwell", s.MAGWELL_POS, rotation_euler=s.MAGWELL_ROT)
    rail = (0.0, s.RAIL_Y, s.FRAME_BOTTOM_Z - 0.0057)
    ctx.marker("SideRail", rail, rotation_euler=c.DUST_COVER_SIDE_RAIL_ROT)  # D-118: gadgets hang under the rail
    ctx.marker("Underbarrel", rail)
    ctx.marker("StockMount", s.STOCK_MOUNT)
    grip_mount = ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-(s.GRIP_HALF_WIDTH + 0.012), s.GRIP_HALF_DEPTH + s.GRIP_TAN * -0.020 - 0.004, -0.020))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    s.build_rear_sight(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, 0.0, s.SIGHT_DZ), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    s.build_mag(ctx, mats, extended=False, parent=stock_mag)
    c.wrap_part(ctx, [c.child(frame, "GripTexture")], grip_mount, "StockGrip", (0.0, 0.0, 0.0))  # D-118: swappable grip texture

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
