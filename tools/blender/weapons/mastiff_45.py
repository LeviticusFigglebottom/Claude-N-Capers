"""Tillman Ironworks Mastiff .45: heavy open-bolt .45 submachine gun, first-person model (B4-12).

About 66 cm long. Round stamped-steel receiver tube with a welded optics rail and a cocking slot on the
left, perforated barrel shroud with a short bottom rail, steel trigger housing, straight 25-round stick
magazine, black polymer grip and a fixed steel wire stock. Old-school and blunt next to the polymer
Hornet 9.

Origin = firing-hand pivot on the pistol grip (see _mastiff.py). Forward = Godot -Z.

Node tree: ``Receiver`` (+ ``ReceiverRail``, ``ReceiverDetails``, ``Housing``, ``Grip``, ``Trigger``,
``CockingHandle``), ``Shroud`` (+ ``ShroudVents``, ``ShroudRails``, ``MuzzleNut``). Stock parts:
``SightRail/StockSight`` (flip-up irons, ``AimPoint``), ``Magwell/StockMagazine`` (25 rounds),
``StockMount/StockStock`` (wire stock).
"""

import math

import _common as c
import _mastiff as m

ASSET_ID = "wpn_mastiff_45"
TRI_BUDGET = 25000


def _receiver(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    mb.cylinder(m.TUBE_R, m.TUBE_FRONT_Y - m.TUBE_REAR_Y, segments=32,
                centre=(0.0, (m.TUBE_FRONT_Y + m.TUBE_REAR_Y) / 2, m.BORE_Z), axis="Y", mat=st)
    mb.cylinder(m.TUBE_R + 0.0015, 0.012, segments=32, centre=(0.0, m.TUBE_REAR_Y + 0.006, m.BORE_Z), axis="Y",
                mat=st)                                                                    # end cap
    mb.cylinder(m.TUBE_R + 0.0012, 0.010, segments=32, centre=(0.0, m.TUBE_FRONT_Y - 0.005, m.BORE_Z), axis="Y",
                mat=st)                                                                    # front collar
    rec = c.finish(mb, "Receiver", bevel=0.0008, segments=1)
    rl = ctx.builder()
    ra = rl.material(mats.alu())
    rl.box((-0.0080, m.RAIL_Y0, m.BORE_Z + m.TUBE_R - 0.006), (0.0080, m.RAIL_Y1, m.RAIL_BASE_Z + 0.001), mat=ra)
    c.picatinny(rl, ra, m.RAIL_Y0, m.RAIL_Y1, m.RAIL_BASE_Z)
    c.finish(rl, "ReceiverRail", bevel=0.0004, parent=rec)
    dt = ctx.builder()
    dark = dt.material(mats.polymer())
    s2 = dt.material(mats.bare())
    # cocking slot (left), ejection port (right), weld seam
    dt.box((-m.TUBE_R - 0.0004, -0.060, m.BORE_Z - 0.003), (-m.TUBE_R + 0.0012, 0.060, m.BORE_Z + 0.003), mat=dark)
    dt.box((m.TUBE_R - 0.0012, 0.030, m.BORE_Z - 0.006), (m.TUBE_R + 0.0004, 0.085, m.BORE_Z + 0.010), mat=dark)
    dt.box((m.TUBE_R - 0.0008, 0.040, m.BORE_Z - 0.003), (m.TUBE_R + 0.0008, 0.075, m.BORE_Z + 0.007), mat=s2)
    for y in (-0.080, 0.140):
        dt.cylinder(0.0024, 0.050, segments=10, centre=(0.0, y, m.BORE_Z - 0.010), axis="X", mat=s2)   # pins
    c.finish(dt, "ReceiverDetails", parent=rec)

    hs = ctx.builder()
    hm = hs.material(mats.steel())
    prof = [(m.HOUSING_Y0, m.BORE_Z - 0.010), (m.HOUSING_Y1, m.BORE_Z - 0.010), (m.HOUSING_Y1, m.MAGWELL_BOTTOM_Z + 0.010),
            (m.MAGWELL_Y1 + 0.003, m.MAGWELL_BOTTOM_Z), (m.MAGWELL_Y0 - 0.003, m.MAGWELL_BOTTOM_Z),
            (m.MAGWELL_Y0 - 0.006, m.HOUSING_BOTTOM_Z), (0.010, m.HOUSING_BOTTOM_Z), (0.002, m.GRIP_TOP_Z),
            (-0.030, m.GRIP_TOP_Z), (m.HOUSING_Y0, m.HOUSING_BOTTOM_Z + 0.012)]
    hs.prism(prof, axis="X", start=-0.0130, end=0.0130, mat=hm)
    gy = 0.012
    outer = [(gy, m.HOUSING_BOTTOM_Z + 0.002), (m.MAGWELL_Y0 - 0.006, m.HOUSING_BOTTOM_Z + 0.002),
             (m.MAGWELL_Y0 - 0.008, -0.006), (gy + 0.010, -0.010), (gy, -0.004)]
    hole = [(gy + 0.008, m.HOUSING_BOTTOM_Z - 0.002), (m.MAGWELL_Y0 - 0.012, m.HOUSING_BOTTOM_Z - 0.002),
            (m.MAGWELL_Y0 - 0.013, -0.002), (gy + 0.012, -0.005), (gy + 0.006, -0.001)]
    hs.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0050, end=0.0050, mat=hm)
    housing = c.finish(hs, "Housing", bevel=0.0012, segments=2, parent=rec)
    sel = ctx.builder()
    sm = sel.material(mats.bare())
    sel.cylinder(0.0055, 0.003, segments=18, centre=(-0.0145, 0.000, 0.044), axis="X", mat=sm)    # selector
    sel.box((-0.0165, -0.002, 0.042), (-0.0145, 0.016, 0.047), mat=sm)
    sel.box((0.0130, m.MAGWELL_Y0 - 0.010, 0.010), (0.0150, m.MAGWELL_Y0 - 0.002, 0.026), mat=sm)  # mag catch
    c.finish(sel, "Selector", bevel=0.0003, parent=housing)

    gp = ctx.builder()
    poly = gp.material(mats.polymer())
    gp.prism(c.raked_grip_profile(m.GRIP_TOP_Z, m.GRIP_BOTTOM_Z, m.GRIP_HALF_DEPTH, m.GRIP_ANGLE_DEG,
                                  palm_swell=0.0028, finger_bumps=3),
             axis="X", start=-m.GRIP_HALF_WIDTH, end=m.GRIP_HALF_WIDTH, mat=poly)
    grip = c.finish(gp, "Grip", bevel=0.0030, segments=3, parent=rec)
    gt = ctx.builder()
    gm = gt.material(mats.stipple())
    for side in (-1.0, 1.0):                                      # grip panel grooves
        x = side * (m.GRIP_HALF_WIDTH + 0.0002)
        lo, hi = sorted((x - side * 0.0006, x))
        for i in range(7):
            z = -0.060 + i * 0.010
            y0 = -m.GRIP_HALF_DEPTH + m.GRIP_TAN * z + 0.005
            gt.box((lo, y0, z), (hi, y0 + 2 * m.GRIP_HALF_DEPTH - 0.011, z + 0.004), mat=gm)
    c.finish(gt, "GripTexture", parent=grip)
    tr = ctx.builder()
    ts = tr.material(mats.steel())
    pf, pb = [], []
    for i in range(8):
        s = i / 7
        z = m.HOUSING_BOTTOM_Z - s * 0.020
        yc = 0.040 + 0.006 * s * s
        pf.append((yc + 0.0020, z))
        pb.append((yc - 0.0020, z))
    tr.prism(pf + list(reversed(pb)), axis="X", start=-0.0030, end=0.0030, mat=ts)
    c.finish(tr, "Trigger", bevel=0.0005, parent=rec)
    ck = ctx.builder()
    cm = ck.material(mats.bare())
    ck.box((-m.TUBE_R - 0.016, 0.044, m.BORE_Z - 0.004), (-m.TUBE_R + 0.002, 0.052, m.BORE_Z + 0.004), mat=cm)
    ck.cylinder(0.0060, 0.010, segments=16, centre=(-m.TUBE_R - 0.018, 0.048, m.BORE_Z), axis="X", mat=cm)
    c.finish(ck, "CockingHandle", bevel=0.0006, parent=rec)
    return rec


def _shroud(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    c.ring_y(mb, m.SHROUD_R, m.SHROUD_R - 0.0015, m.TUBE_FRONT_Y, m.SHROUD_Y1, m.BORE_Z, st, segments=28)
    mb.cylinder(m.SHROUD_R + 0.0010, 0.010, segments=28, centre=(0.0, m.SHROUD_Y1 - 0.005, m.BORE_Z), axis="Y", mat=st)
    mb.cylinder(0.0080, m.SHROUD_Y1 - m.TUBE_FRONT_Y, segments=20,
                centre=(0.0, (m.SHROUD_Y1 + m.TUBE_FRONT_Y) / 2, m.BORE_Z), axis="Y", mat=st)     # barrel inside
    shroud = c.finish(mb, "Shroud", bevel=0.0006, segments=1)
    vt = ctx.builder()
    dark = vt.material(mats.polymer())
    # three rows of round vents on each side and on top (dark discs just proud of the shroud)
    for k, a in enumerate((math.radians(25), math.radians(90), math.radians(155))):
        ca, sa = math.cos(a), math.sin(a)
        for i in range(6):
            y = m.TUBE_FRONT_Y + 0.020 + i * 0.020 + (0.010 if k == 1 else 0.0)
            vt.cylinder(0.0042, 0.0012, segments=12, centre=(ca * (m.SHROUD_R - 0.0002), y,
                                                              m.BORE_Z + sa * (m.SHROUD_R - 0.0002)),
                        axis="X" if k != 1 else "Z", mat=dark)
    c.finish(vt, "ShroudVents", parent=shroud)
    rl = ctx.builder()
    ra = rl.material(mats.alu())
    rl.box((-0.0080, m.UNDER_Y - 0.040, m.UNDER_Z - 0.0005), (0.0080, m.UNDER_Y + 0.040, m.BORE_Z - m.SHROUD_R + 0.004),
           mat=ra)
    c.rail_side(rl, ra, m.UNDER_Y - 0.040, m.UNDER_Y + 0.040, 0.0, m.UNDER_Z, 0.0)
    c.finish(rl, "ShroudRails", bevel=0.0004, parent=shroud)
    nt = ctx.builder()
    nm = nt.material(mats.steel())
    c.ring_y(nt, 0.0120, 0.0062, m.SHROUD_Y1, m.SHROUD_Y1 + m.MUZZLE_NUT_LEN, m.BORE_Z, nm, segments=8)
    c.finish(nt, "MuzzleNut", bevel=0.0006, parent=shroud)
    return shroud


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _receiver(ctx, mats)
    _shroud(ctx, mats)

    ctx.marker("Muzzle", (0.0, m.MUZZLE_Y, m.BORE_Z))
    ctx.marker("BarrelMount", (0.0, m.TUBE_FRONT_Y, m.BORE_Z))
    ctx.marker("Eject", (m.TUBE_R, 0.058, m.BORE_Z + 0.004), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, m.SIGHT_RAIL_Y, m.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", m.MAGWELL_POS)
    ctx.marker("Underbarrel", (0.0, m.UNDER_Y, m.UNDER_Z - 0.0057))
    ctx.marker("SideRail", (m.SHROUD_R + 0.0040, m.SIDE_Y, m.BORE_Z))
    stock_mount = ctx.marker("StockMount", m.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-(m.MAG_HW + 0.010), m.MAGWELL_POS[1], -0.030))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _body, aim = m.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, m.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    m.build_mag(ctx, mats, extended=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    m.build_wire_stock(ctx, mats, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
