"""Brannock Falchion DMR: semi-automatic 7.62 mm marksman rifle, first-person model (B4-12).

About 1.08 m long. Tall black aluminium receivers, long round free-float handguard with a full-length
top rail and short accessory rails, heavy barrel with a three-port brake, olive precision stock with a
raised cheek piece and rubber pad, straight 20-round magazine with a witness window. Longer, heavier
and more precise-looking than the Corsair.

Origin = firing-hand pivot on the pistol grip (see _falchion.py). Forward = Godot -Z.

Node tree: ``Lower`` (+ ``Grip``, ``Trigger``, ``Controls``), ``Upper`` (+ ``TopRail``,
``ChargingHandle``), ``Handguard`` (+ ``HandguardRails``, ``HandguardSlots``), ``Barrel`` (+ ``Brake``),
``BufferTube`` (+ ``Stock``, ``CheekPiece``, ``ButtPad``). Stock parts: ``SightRail/StockSight``
(flip-up irons, ``AimPoint``), ``Magwell/StockMagazine`` (20 rounds).
"""

import math

import _common as c
import _falchion as f

ASSET_ID = "wpn_falchion_dmr"
TRI_BUDGET = 25000


def _lower(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    y0 = f.RECEIVER_REAR_Y
    prof = [(y0, f.LOWER_TOP_Z), (f.UPPER_FRONT_Y - 0.004, f.LOWER_TOP_Z), (f.MAGWELL_Y1 + 0.012, 0.052),
            (f.MAGWELL_Y1 + 0.002, 0.036), (f.MAGWELL_Y1 - 0.002, 0.028), (f.MAGWELL_Y0, 0.024),
            (0.030, 0.024), (0.006, 0.022), (-0.030, 0.022), (-0.050, 0.036), (y0, 0.048)]
    mb.prism(prof, axis="X", start=-0.0120, end=0.0120, mat=alu)
    well = [(f.MAGWELL_Y0 - 0.002, 0.032), (f.MAGWELL_Y1 + 0.001, 0.032), (f.MAGWELL_Y1 + 0.001, -0.002),
            (f.MAGWELL_Y1 + 0.004, f.MAGWELL_BOTTOM_Z), (f.MAGWELL_Y0 - 0.005, f.MAGWELL_BOTTOM_Z),
            (f.MAGWELL_Y0 - 0.002, -0.002)]
    mb.prism(well, axis="X", start=-0.0165, end=0.0165, mat=alu)
    gy = 0.010
    outer = [(gy, 0.026), (f.MAGWELL_Y0, 0.026), (f.MAGWELL_Y0, -0.006), (gy + 0.006, -0.006), (gy, -0.001)]
    hole = [(gy + 0.008, 0.022), (f.MAGWELL_Y0 - 0.004, 0.022), (f.MAGWELL_Y0 - 0.004, -0.002), (gy + 0.010, -0.002)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0060, end=0.0060, mat=alu)
    lower = c.finish(mb, "Lower", bevel=0.0015, segments=2)
    gp = ctx.builder()
    ol = gp.material(mats.olive())
    gp.prism(c.raked_grip_profile(0.022, -0.076, 0.0175, f.GRIP_ANGLE_DEG, palm_swell=0.0030, finger_bumps=0),
             axis="X", start=-0.0140, end=0.0140, mat=ol)
    gp.box((-0.0120, -0.034, 0.016), (0.0120, 0.006, 0.026), mat=ol)
    gp.box((-0.0145, -0.026 + f.GRIP_TAN * -0.076, -0.084), (0.0145, 0.020 + f.GRIP_TAN * -0.076, -0.074), mat=ol)  # shelf
    grip = c.finish(gp, "Grip", bevel=0.0030, segments=3, parent=lower)
    st = ctx.builder()
    sm = st.material(mats.stipple())
    for side in (-1.0, 1.0):
        x = side * 0.0139
        for r in range(12):
            z = -0.060 + r * 0.0050
            yy = -0.0175 + f.GRIP_TAN * z + 0.006 + (0.0025 if r % 2 else 0.0)
            while yy < 0.0175 + f.GRIP_TAN * z - 0.006:
                c.pyramid(st.bm, c.Vector((x, yy, z)), c.Vector((0, 1, 0)), c.Vector((0, 0, 1)), c.Vector((side, 0, 0)),
                          0.0012, 0.0005, sm)
                yy += 0.0050
    c.finish(st, "GripTexture", parent=grip)
    tr = ctx.builder()
    ts = tr.material(mats.steel())
    tr.box((-0.0030, 0.040, 0.002), (0.0030, 0.044, 0.024), mat=ts)                    # flat match trigger
    c.finish(tr, "Trigger", bevel=0.0005, parent=lower)
    ct = ctx.builder()
    cs = ct.material(mats.steel())
    ct.cylinder(0.0060, 0.003, segments=20, centre=(-0.0135, -0.004, 0.046), axis="X", mat=cs)
    ct.box((-0.0150, -0.002, 0.044), (-0.0130, 0.014, 0.048), mat=cs)
    ct.cylinder(0.0045, 0.004, segments=16, centre=(0.0140, f.MAGWELL_Y0 - 0.006, 0.042), axis="X", mat=cs)
    for y in (f.RECEIVER_REAR_Y + 0.012, f.UPPER_FRONT_Y - 0.010):
        ct.cylinder(0.0032, 0.0260, segments=12, centre=(0.0, y, 0.055), axis="X", mat=cs)
    c.finish(ct, "Controls", bevel=0.0003, parent=lower)
    return lower


def _upper(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    y0, y1 = f.RECEIVER_REAR_Y, f.UPPER_FRONT_Y
    hw = f.REC_HW
    prof = [(-hw, f.LOWER_TOP_Z), (hw, f.LOWER_TOP_Z), (hw, 0.092), (hw - 0.0025, f.UPPER_TOP_Z),
            (-hw + 0.0025, f.UPPER_TOP_Z), (-hw, 0.092)]
    mb.prism(prof, axis="Y", start=y0, end=y1, mat=alu)
    mb.box((hw - 0.002, 0.010, 0.074), (hw + 0.005, 0.034, 0.098), mat=alu)                 # brass deflector
    upper = c.finish(mb, "Upper", bevel=0.0012, segments=2)
    dt = ctx.builder()
    poly = dt.material(mats.polymer())
    dt.box((hw - 0.0002, 0.040, 0.070), (hw + 0.0006, 0.110, 0.092), mat=poly)              # dust cover
    c.finish(dt, "UpperDetails", parent=upper)
    rl = ctx.builder()
    c.picatinny(rl, rl.material(mats.alu()), y0 + 0.004, y1 - 0.002, f.UPPER_TOP_Z)
    c.finish(rl, "TopRail", bevel=0.0004, parent=upper)
    ch = ctx.builder()
    chm = ch.material(mats.alu())
    ch.box((-0.0040, y0 - 0.014, 0.092), (0.0040, y0 + 0.002, 0.100), mat=chm)
    ch.prism([(-0.024, y0 - 0.016), (0.024, y0 - 0.016), (0.020, y0 - 0.008), (-0.020, y0 - 0.008)], axis="Z",
             start=0.091, end=0.101, mat=chm)
    c.finish(ch, "ChargingHandle", bevel=0.0010, segments=1, parent=upper)
    return upper


def _handguard(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    hole = list(reversed(c.circle(0.0170, 24, 0.0, f.BORE_Z)))
    mb.prism(c.circle(f.HG_R, 32, 0.0, f.BORE_Z), holes=[hole], axis="Y", start=f.UPPER_FRONT_Y, end=f.HG_FRONT_Y,
             mat=alu)
    mb.box((-0.0105, f.UPPER_FRONT_Y, f.BORE_Z + f.HG_R - 0.006), (0.0105, f.HG_FRONT_Y, f.UPPER_TOP_Z), mat=alu)
    mb.cylinder(0.0195, 0.014, segments=28, centre=(0.0, f.UPPER_FRONT_Y + 0.004, f.BORE_Z), axis="Y", mat=alu)
    hg = c.finish(mb, "Handguard", bevel=0.0010, segments=1)
    rl = ctx.builder()
    ra = rl.material(mats.alu())
    c.picatinny(rl, ra, f.UPPER_FRONT_Y + 0.002, f.HG_FRONT_Y - 0.004, f.UPPER_TOP_Z)
    under_z = f.BORE_Z - f.HG_R + 0.0005
    c.rail_side(rl, ra, f.UNDER_Y - 0.040, f.UNDER_Y + 0.045, 0.0, under_z, 0.0)
    c.rail_side(rl, ra, f.SIDE_Y - 0.025, f.SIDE_Y + 0.030, f.HG_R - 0.0010, f.BORE_Z, 1.0)
    c.finish(rl, "HandguardRails", bevel=0.0004, parent=hg)
    sl = ctx.builder()
    sm = sl.material(mats.polymer())
    for k, a in enumerate((math.radians(-35), math.radians(215))):
        x, z = math.cos(a) * (f.HG_R - 0.0006), f.BORE_Z + math.sin(a) * (f.HG_R - 0.0006)
        for i in range(7):
            y = f.UPPER_FRONT_Y + 0.020 + i * 0.044
            sl.box((x - 0.0030, y, z - 0.0030), (x + 0.0030, y + 0.030, z + 0.0030), mat=sm)
    c.finish(sl, "HandguardSlots", parent=hg)
    return hg


def _barrel(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(f.BARREL_R, f.BARREL_END_Y - f.UPPER_FRONT_Y, segments=24,
                centre=(0.0, (f.BARREL_END_Y + f.UPPER_FRONT_Y) / 2, f.BORE_Z), axis="Y", mat=st)
    barrel = c.finish(mb, "Barrel", bevel=0.0005, segments=1)
    br = ctx.builder()
    bm = br.material(mats.steel())
    dark = br.material(mats.polymer())
    y0, y1 = f.BARREL_END_Y - 0.002, f.BARREL_END_Y + f.BRAKE_LEN
    c.ring_y(br, 0.0140, 0.0062, y0, y1, f.BORE_Z, bm, segments=28)
    for i in range(3):
        y = y0 + 0.012 + i * 0.014
        for side in (-1.0, 1.0):
            lo, hi = sorted((side * 0.0136, side * 0.0146))
            br.box((lo, y, f.BORE_Z - 0.006), (hi, y + 0.008, f.BORE_Z + 0.006), mat=dark)
    c.finish(br, "Brake", bevel=0.0006, segments=1, parent=barrel)
    return barrel


def _stock(ctx, mats):
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    y0 = f.RECEIVER_REAR_Y
    mb.cylinder(0.0155, 0.200, segments=24, centre=(0.0, y0 - 0.100, f.BORE_Z), axis="Y", mat=alu)
    mb.cylinder(0.0190, 0.008, segments=8, centre=(0.0, y0 - 0.006, f.BORE_Z), axis="Y", mat=alu)
    tube = c.finish(mb, "BufferTube", bevel=0.0006, segments=1)
    sb = ctx.builder()
    ol = sb.material(mats.olive())
    yf, yr = y0 - 0.070, y0 - 0.250
    prof = [(yf, 0.104), (yr + 0.006, 0.104), (yr, 0.100), (yr - 0.002, -0.030), (yr + 0.016, -0.036),
            (yr + 0.080, 0.000), (yf - 0.010, 0.050), (yf, 0.062)]
    hole = [(yr + 0.022, 0.056), (yr + 0.022, -0.012), (yr + 0.036, -0.016), (yr + 0.090, 0.022), (yr + 0.090, 0.056)]
    sb.prism(prof, holes=[hole], axis="X", start=-0.0200, end=0.0200, mat=ol)
    c.taper_x(sb, lambda y, z: 0.80 + 0.20 * min(1.0, max(0.0, (yf - y) / (yf - yr))))
    stock = c.finish(sb, "Stock", bevel=0.0030, segments=2, parent=tube)
    ck = ctx.builder()
    cm = ck.material(mats.olive())
    ck.prism([(yf - 0.010, 0.104), (yr + 0.020, 0.104), (yr + 0.024, 0.126), (yf - 0.030, 0.124)], axis="X",
             start=-0.0160, end=0.0160, mat=cm)
    c.finish(ck, "CheekPiece", bevel=0.0035, segments=2, parent=stock)
    pd = ctx.builder()
    rub = pd.material(mats.rubber())
    pd.prism([(yr - 0.002, 0.102), (yr - 0.002, -0.034), (yr - 0.018, -0.032), (yr - 0.018, 0.100)], axis="X",
             start=-0.0198, end=0.0198, mat=rub)
    c.finish(pd, "ButtPad", bevel=0.0028, segments=2, parent=stock)
    return tube


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _lower(ctx, mats)
    _upper(ctx, mats)
    _handguard(ctx, mats)
    _barrel(ctx, mats)
    _stock(ctx, mats)

    ctx.marker("Muzzle", (0.0, f.MUZZLE_Y, f.BORE_Z))
    ctx.marker("BarrelMount", (0.0, f.UPPER_FRONT_Y, f.BORE_Z))
    ctx.marker("Eject", (f.REC_HW, 0.075, f.BORE_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, f.SIGHT_RAIL_Y, f.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", f.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, f.UNDER_Y, f.BORE_Z - f.HG_R - 0.0057))
    ctx.marker("SideRail", (f.HG_R + 0.0052, f.SIDE_Y, f.BORE_Z))
    ctx.marker("StockMount", f.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    # Lead (ENV D, FP left-hand cup): under the Handguard (y 0.187-0.520, bottom z 0.048), x 0, 12 mm low, a third of the way forward.
    ctx.marker("LeftHandIK", (0.0, 0.298, 0.036))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = f.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, f.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    f.build_mag(ctx, mats, extended=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
