"""Brannock Corsair: 5.56 mm gas-operated carbine, first-person model (B4-04).

About 89 cm long with the stock. Black anodised receivers and free-float handguard with flush top
rail, tan polymer grip, stock and magazine. Straight-line layout (bore = buffer tube axis).

Origin = firing-hand pivot on the pistol grip (see _corsair.py). Forward = Godot -Z, up = Godot +Y.

Node tree (Godot names): ``Lower`` (+ ``Grip``, ``Trigger``, ``Controls``), ``Upper`` (+ ``TopRail``,
``ChargingHandle``), ``Handguard`` (+ rails, slot inlays), ``Barrel`` (+ ``MuzzleBrake``), ``Stock``
(buffer tube + tan stock). Markers per contracts/visual_slots.md: ``Muzzle``, ``Eject``,
``SightRail``, ``Magwell``, ``Underbarrel``, ``SideRail``, ``StockMount``, ``GripMount``,
``BarrelMount``, ``LeftHandIK``. Stock parts: ``SightRail/StockSight`` (flip-up irons, ``AimPoint``),
``Magwell/StockMagazine`` (30-round magazine).
"""

import math

import _common as c
import _corsair as k

ASSET_ID = "wpn_corsair_ar"
TRI_BUDGET = 25000


def _lower(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    y0 = k.RECEIVER_REAR_Y
    prof = [(y0, k.LOWER_TOP_Z), (k.UPPER_FRONT_Y - 0.004, k.LOWER_TOP_Z), (k.MAGWELL_Y1 + 0.010, 0.050),
            (k.MAGWELL_Y1 + 0.002, 0.038), (k.MAGWELL_Y1 - 0.002, 0.030), (k.MAGWELL_Y0, 0.024),
            (0.030, 0.024), (0.006, k.GRIP_TOP_Z), (-0.030, k.GRIP_TOP_Z), (-0.048, 0.034), (y0, 0.046)]
    mb.prism(prof, axis="X", start=-0.0115, end=0.0115, mat=alu)
    # magwell with a flared mouth
    well = [(k.MAGWELL_Y0 - 0.002, 0.032), (k.MAGWELL_Y1 + 0.001, 0.032), (k.MAGWELL_Y1 + 0.001, -0.004),
            (k.MAGWELL_Y1 + 0.004, k.MAGWELL_BOTTOM_Z), (k.MAGWELL_Y0 - 0.005, k.MAGWELL_BOTTOM_Z),
            (k.MAGWELL_Y0 - 0.002, -0.004)]
    mb.prism(well, axis="X", start=-0.0150, end=0.0150, mat=alu)
    # trigger guard: loop from the grip front to the magwell
    gy = 0.010
    outer = [(gy, 0.026), (k.MAGWELL_Y0, 0.026), (k.MAGWELL_Y0, -0.006), (gy + 0.006, -0.006), (gy, -0.001)]
    hole = [(gy + 0.008, 0.022), (k.MAGWELL_Y0 - 0.004, 0.022), (k.MAGWELL_Y0 - 0.004, -0.002),
            (gy + 0.010, -0.002)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0060, end=0.0060, mat=alu)
    lower = c.finish(mb, "Lower", bevel=0.0015, segments=2)

    # pistol grip (tan) with stippled panels
    gp = ctx.builder()
    tan = gp.material(mats.tan())
    gp.prism(k.grip_profile(), axis="X", start=-k.GRIP_HALF_WIDTH, end=k.GRIP_HALF_WIDTH, mat=tan)
    gp.box((-0.0115, -0.032, 0.016), (0.0115, 0.006, 0.026), mat=tan)          # grip-to-lower shoulder
    grip = c.finish(gp, "Grip", bevel=0.0030, segments=3)
    st = ctx.builder()
    sm = st.material(mats.stipple())
    for side in (-1.0, 1.0):
        x = side * (k.GRIP_HALF_WIDTH - 0.0001)
        for r in range(14):
            z = -0.058 + r * 0.0045
            yb = -k.GRIP_HALF_DEPTH + k.GRIP_TAN * z + 0.006
            yf = k.GRIP_HALF_DEPTH + k.GRIP_TAN * z - 0.007
            yy = yb + (0.00225 if r % 2 else 0.0)
            while yy < yf:
                c.pyramid(st.bm, c.Vector((x, yy, z)), c.Vector((0, 1, 0)), c.Vector((0, 0, 1)),
                          c.Vector((side, 0, 0)), 0.0011, 0.0005, sm)
                yy += 0.0045
    c.finish(st, "GripTexture", parent=grip)

    # trigger + controls
    tr = ctx.builder()
    ts = tr.material(mats.steel())
    pts_f, pts_b = [], []
    for i in range(8):
        s = i / 7
        z = 0.024 - s * 0.020
        yc = 0.040 + 0.006 * s * s
        pts_f.append((yc + 0.0018, z))
        pts_b.append((yc - 0.0018, z))
    tr.prism(pts_f + list(reversed(pts_b)), axis="X", start=-0.0030, end=0.0030, mat=ts)
    c.finish(tr, "Trigger", bevel=0.0005, parent=lower)
    ct = ctx.builder()
    cs = ct.material(mats.steel())
    ct.cylinder(0.0060, 0.003, segments=20, centre=(-0.0130, -0.004, 0.044), axis="X", mat=cs)    # selector
    ct.box((-0.0145, -0.002, 0.042), (-0.0125, 0.012, 0.046), mat=cs)                              # selector lever
    ct.cylinder(0.0045, 0.004, segments=16, centre=(0.0135, k.MAGWELL_Y0 - 0.006, 0.040), axis="X", mat=cs)  # mag release
    ct.box((-0.0145, 0.064, 0.036), (-0.0115, 0.080, 0.050), mat=cs)                               # bolt catch
    for y in (k.RECEIVER_REAR_Y + 0.012, k.UPPER_FRONT_Y - 0.010):                                 # takedown pins
        ct.cylinder(0.0032, 0.0250, segments=12, centre=(0.0, y, 0.053), axis="X", mat=cs)
    c.finish(ct, "Controls", bevel=0.0003, parent=lower)
    return lower


def _upper(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    y0, y1 = k.RECEIVER_REAR_Y, k.UPPER_FRONT_Y
    prof = [(-0.0130, k.LOWER_TOP_Z), (0.0130, k.LOWER_TOP_Z), (0.0130, 0.088), (0.0105, k.UPPER_TOP_Z),
            (-0.0105, k.UPPER_TOP_Z), (-0.0130, 0.088)]
    mb.prism(prof, axis="Y", start=y0, end=y1, mat=alu)
    # forward assist housing (right rear) and brass deflector
    mb.cylinder(0.0075, 0.040, segments=20, centre=(0.0160, y0 + 0.030, 0.083), axis="Y", mat=alu)
    mb.box((0.0120, 0.010, 0.072), (0.0175, 0.030, 0.094), mat=alu)
    upper = c.finish(mb, "Upper", bevel=0.0012, segments=2)
    dt = ctx.builder()
    poly = dt.material(mats.polymer())
    steel = dt.material(mats.steel())
    dt.box((0.0128, 0.034, 0.066), (0.0136, 0.098, 0.086), mat=poly)              # dust cover / port
    dt.cylinder(0.0045, 0.010, segments=16, centre=(0.0160, y0 + 0.008, 0.083), axis="Y", mat=steel)  # FA button
    c.finish(dt, "UpperDetails", bevel=0.0003, parent=upper)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), y0 + 0.004, y1 - 0.002, k.UPPER_TOP_Z)
    c.finish(rl, "TopRail", bevel=0.0004, parent=upper)
    ch = ctx.builder()
    chm = ch.material(mats.alu())
    ch.box((-0.0040, y0 - 0.014, 0.088), (0.0040, y0 + 0.002, 0.096), mat=chm)
    ch.prism([(-0.020, y0 - 0.016), (0.020, y0 - 0.016), (0.016, y0 - 0.008), (-0.016, y0 - 0.008)], axis="Z",
             start=0.087, end=0.097, mat=chm)
    c.finish(ch, "ChargingHandle", bevel=0.0010, segments=1, parent=upper)
    return upper


def _handguard(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    outer = c.rounded_rect(k.HG_HALF_WIDTH, k.HG_HALF_HEIGHT, 0.009, 0.0, k.HG_CENTRE_Z)
    hole = list(reversed(c.circle(0.0150, 24, 0.0, k.BORE_Z)))
    mb.prism(outer, holes=[hole], axis="Y", start=k.UPPER_FRONT_Y, end=k.HG_FRONT_Y, mat=alu)
    # barrel nut collar
    mb.cylinder(0.0175, 0.012, segments=28, centre=(0.0, k.UPPER_FRONT_Y + 0.004, k.BORE_Z), axis="Y", mat=alu)
    hg = c.finish(mb, "Handguard", bevel=0.0012, segments=2)
    rl = ctx.builder()
    ra = rl.material(mats.alu())
    c.picatinny(rl, ra, k.UPPER_FRONT_Y + 0.002, k.HG_FRONT_Y - 0.004, k.UPPER_TOP_Z)
    c.rail_side(rl, ra, k.UNDER_Y - 0.045, k.UNDER_Y + 0.050, 0.0, k.HG_BOTTOM_Z + 0.0005, 0.0)
    c.rail_side(rl, ra, k.SIDE_Y - 0.025, k.SIDE_Y + 0.030, k.HG_HALF_WIDTH - 0.0005, k.HG_CENTRE_Z, 1.0)
    c.finish(rl, "HandguardRails", bevel=0.0004, parent=hg)
    # M-LOK style slots: dark inlays on both sides and the bottom rear
    sl = ctx.builder()
    sm = sl.material(mats.polymer())
    for side in (-1.0, 1.0):
        x0, x1 = sorted((side * (k.HG_HALF_WIDTH - 0.0004), side * (k.HG_HALF_WIDTH + 0.0003)))
        for i in range(5):
            y = 0.195 + i * 0.034
            if side > 0 and y > k.SIDE_Y - 0.040:
                continue
            sl.box((x0, y, k.HG_CENTRE_Z - 0.0035), (x1, y + 0.024, k.HG_CENTRE_Z + 0.0035), mat=sm)
    for i in range(4):
        y = 0.192 + i * 0.034
        sl.box((-0.0035, y, k.HG_BOTTOM_Z - 0.0003), (0.0035, y + 0.024, k.HG_BOTTOM_Z + 0.0004), mat=sm)
    c.finish(sl, "HandguardSlots", parent=hg)
    return hg


def _barrel(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(k.BARREL_R, k.BARREL_END_Y - k.UPPER_FRONT_Y, segments=24,
                centre=(0.0, (k.BARREL_END_Y + k.UPPER_FRONT_Y) / 2, k.BORE_Z), axis="Y", mat=st)
    barrel = c.finish(mb, "Barrel", bevel=0.0005, segments=1)
    # PO6-13: 3-port side brake carrying Muzzle + MuzzlePortL/R
    c.build_muzzle_brake(ctx, mats, 0.0112, k.BARREL_END_Y, k.BRAKE_LEN, k.BORE_Z, parent=barrel)
    return barrel


def _stock(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    y0 = k.RECEIVER_REAR_Y
    mb.cylinder(0.0150, 0.180, segments=24, centre=(0.0, y0 - 0.090, k.HG_CENTRE_Z), axis="Y", mat=alu)  # buffer tube
    mb.cylinder(0.0185, 0.008, segments=8, centre=(0.0, y0 - 0.006, k.HG_CENTRE_Z), axis="Y", mat=alu)    # castle nut
    mb.box((-0.011, y0 - 0.012, 0.050), (0.011, y0 - 0.002, 0.068), mat=alu)                              # end plate
    tube = c.finish(mb, "BufferTube", bevel=0.0006, segments=1)
    sb = ctx.builder()
    tan = sb.material(mats.tan())
    yf, yr = y0 - 0.088, y0 - 0.212
    prof = [(yf, 0.098), (yr + 0.010, 0.102), (yr, 0.100), (yr - 0.004, 0.060), (yr - 0.002, -0.032),
            (yr + 0.016, -0.036), (yr + 0.050, 0.010), (yf + 0.020, 0.052), (yf, 0.056)]
    hole = [(yr + 0.014, 0.048), (yr + 0.014, -0.018), (yr + 0.024, -0.020), (yr + 0.060, 0.030),
            (yr + 0.060, 0.048)]
    sb.prism(prof, holes=[hole], axis="X", start=-0.0200, end=0.0200, mat=tan)
    c.taper_x(sb, lambda y, z: 0.82 + 0.18 * min(1.0, max(0.0, (yf - y) / (yf - yr))))
    stock = c.finish(sb, "Stock", bevel=0.0035, segments=3, parent=tube)
    pd = ctx.builder()
    rub = pd.material(mats.rubber())
    pd.prism([(yr - 0.004, 0.099), (yr - 0.004, -0.034), (yr - 0.016, -0.031), (yr - 0.016, 0.096)], axis="X",
             start=-0.0195, end=0.0195, mat=rub)
    for i in range(6):
        z = -0.022 + i * 0.020
        pd.box((-0.0200, yr - 0.0172, z), (0.0200, yr - 0.0150, z + 0.006), mat=rub)
    c.finish(pd, "ButtPad", bevel=0.0025, segments=2, parent=stock)
    return tube


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _lower(ctx, mats)
    _upper(ctx, mats)
    _handguard(ctx, mats)
    _barrel(ctx, mats)
    _stock(ctx, mats)

    ctx.marker("BarrelMount", (0.0, k.UPPER_FRONT_Y, k.BORE_Z))
    ctx.marker("Eject", (0.0135, 0.066, k.BORE_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, k.SIGHT_RAIL_Y, k.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", k.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, k.UNDER_Y, k.HG_BOTTOM_Z - 0.0057))
    ctx.marker("SideRail", (k.HG_HALF_WIDTH + 0.0057, k.SIDE_Y, k.HG_CENTRE_Z))
    ctx.marker("StockMount", (0.0, k.RECEIVER_REAR_Y, k.HG_CENTRE_Z))
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Handguard (y 0.170-0.440, bottom z 0.050), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.260, 0.038))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _body, aim = k.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, k.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    k.build_mag(ctx, mats, extended=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
