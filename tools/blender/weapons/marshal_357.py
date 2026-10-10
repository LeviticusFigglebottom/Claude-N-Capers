"""Marrow & Kell Marshal .357: six-shot double-action revolver, first-person model (B4-12).

About 26 cm long with the 4 in barrel. Bare stainless frame, full-underlug barrel with a ramp front
sight, fluted six-shot cylinder on a swing-out crane, exposed hammer, walnut grip with checkering.

Origin = firing-hand pivot (see _marshal.py). Forward = Godot -Z.

Node tree: ``Frame`` (+ ``FrameDetails``, ``Hammer``, ``Trigger``, ``TriggerGuard``), ``Crane`` (pivot on the
crane hinge; swings the cylinder out left: positive rotation about local Z, 80 deg) with ``Cylinder``
(pivot on the cylinder axis at its rear face; 60 deg about local Z per shot) carrying ``Magwell``.
Stock parts: ``SightRail/StockSight`` (rear sight, ``AimPoint``), ``Magwell/StockMagazine`` (six
cartridges), ``BarrelMount/StockBarrel`` (4 in barrel), ``GripMount/StockGrip`` (walnut grip).
"""

import math

import _common as c
import _marshal as m

ASSET_ID = "wpn_marshal_357"
TRI_BUDGET = 25000

FRAME_HALF = 0.0150


def _frame(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.bare())
    y0, y1 = m.FRAME_REAR_Y, m.FRAME_FRONT_Y
    prof = [(y0 + 0.004, m.TOP_STRAP_Z1 - 0.010), (y0 + 0.020, m.TOP_STRAP_Z1), (y1, m.TOP_STRAP_Z1),
            (y1, m.BORE_Z - 0.020), (m.CYL_Y1 + 0.004, m.FRAME_BOTTOM_Z + 0.006), (m.CYL_Y1 - 0.004, m.FRAME_BOTTOM_Z),
            (0.012, m.FRAME_BOTTOM_Z), (-0.004, m.GRIP_TOP_Z), (y0 + 0.004, m.GRIP_TOP_Z + 0.006),
            (y0, 0.040)]
    window = [(m.CYL_Y0 - 0.0005, m.CYL_Z - m.CYL_R - 0.0010), (m.CYL_Y1 + 0.0005, m.CYL_Z - m.CYL_R - 0.0010),
              (m.CYL_Y1 + 0.0005, m.TOP_STRAP_Z0), (m.CYL_Y0 - 0.0005, m.TOP_STRAP_Z0)]
    mb.prism(prof, holes=[list(reversed(window))], axis="X", start=-FRAME_HALF, end=FRAME_HALF, mat=st)
    # grip frame (covered by the grip panels)
    t = m.GRIP_TAN
    gf = [(m.GRIP_HALF_DEPTH - 0.004 + t * 0.022, 0.022), (m.GRIP_HALF_DEPTH - 0.004 + t * -0.060, -0.060),
          (-m.GRIP_HALF_DEPTH + 0.004 + t * -0.060, -0.060), (-m.GRIP_HALF_DEPTH + 0.004 + t * 0.022, 0.022)]
    mb.prism(gf, axis="X", start=-0.0080, end=0.0080, mat=st)
    c.taper_x(mb, lambda y, z: 0.72 if z < 0.022 else (0.78 if z > m.TOP_STRAP_Z0 + 0.002 else 1.0))
    frame = c.finish(mb, "Frame", bevel=0.0014, segments=2)

    dt = ctx.builder()
    s2 = dt.material(mats.steel())
    dark = dt.material(mats.polymer())
    for side in (-1.0, 1.0):                                                          # side-plate screws
        for y, z in ((-0.012, 0.040), (0.004, 0.028), (m.CYL_Y1 + 0.004, 0.036)):
            dt.cylinder(0.0022, 0.0008, segments=10, centre=(side * (FRAME_HALF * 0.98), y, z), axis="X", mat=s2)
    dt.box((-0.0024, m.FRAME_REAR_Y + 0.016, m.TOP_STRAP_Z1 - 0.0008), (0.0024, m.FRAME_FRONT_Y - 0.004,
           m.TOP_STRAP_Z1 + 0.0004), mat=dark)                                         # sight groove
    dt.box((-FRAME_HALF - 0.0008, m.CYL_Y0 - 0.020, 0.044), (-FRAME_HALF + 0.0004, m.CYL_Y0 - 0.006, 0.050), mat=s2)  # latch
    c.finish(dt, "FrameDetails", bevel=0.0002, parent=frame)

    hm = ctx.builder()
    hs = hm.material(mats.steel())
    hammer = [(m.FRAME_REAR_Y + 0.006, 0.040), (m.FRAME_REAR_Y + 0.010, 0.066), (m.FRAME_REAR_Y - 0.004, 0.084),
              (m.FRAME_REAR_Y - 0.016, 0.086), (m.FRAME_REAR_Y - 0.018, 0.080), (m.FRAME_REAR_Y - 0.004, 0.072),
              (m.FRAME_REAR_Y - 0.002, 0.040)]
    hm.prism(hammer, axis="X", start=-0.0035, end=0.0035, mat=hs)
    for i in range(4):                                                                 # spur checkering
        y = m.FRAME_REAR_Y - 0.014 + i * 0.003
        hm.box((-0.0037, y, 0.083 - i * 0.002), (0.0037, y + 0.0012, 0.0868 - i * 0.002), mat=hs)
    c.finish(hm, "Hammer", bevel=0.0005, parent=frame)
    tr = ctx.builder()
    tm = tr.material(mats.bare())
    pf, pb = [], []
    for i in range(8):
        s = i / 7
        z = m.FRAME_BOTTOM_Z - s * 0.022
        yc = 0.030 - 0.004 * s + 0.007 * s * s
        pf.append((yc + 0.0030, z))
        pb.append((yc - 0.0030, z))
    tr.prism(pf + list(reversed(pb)), axis="X", start=-0.0040, end=0.0040, mat=tm)
    c.finish(tr, "Trigger", bevel=0.0006, parent=frame)
    tg = ctx.builder()
    gm = tg.material(mats.bare())
    outer = [(0.008, m.FRAME_BOTTOM_Z + 0.002), (m.CYL_Y1 + 0.004, m.FRAME_BOTTOM_Z + 0.002), (0.060, 0.006),
             (0.054, -0.006), (0.040, -0.012), (0.018, -0.010), (0.010, -0.002)]
    hole = [(0.016, m.FRAME_BOTTOM_Z - 0.002), (0.050, m.FRAME_BOTTOM_Z - 0.002), (0.052, 0.006), (0.048, -0.002),
            (0.038, -0.006), (0.022, -0.005), (0.017, 0.002)]
    tg.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0050, end=0.0050, mat=gm)
    c.finish(tg, "TriggerGuard", bevel=0.0010, segments=1, parent=frame)
    return frame


def _crane(ctx, mats):
    """Crane (pivot on its hinge) with the cylinder (pivot on its axis at the rear face). Returns cylinder."""
    piv = m.CRANE_PIVOT
    cyl_origin = (0.0, m.CYL_Y0, m.CYL_Z)
    mb = ctx.builder()
    st = mb.material(mats.bare())
    # yoke arm at the cylinder front, from the hinge up to the cylinder axis, and the hinge tube
    mb.cylinder(0.0035, m.CYL_Y1 - m.CYL_Y0 + 0.006, segments=14,
                centre=(piv[0], (m.CYL_Y0 + m.CYL_Y1) / 2 + 0.003, piv[2]), axis="Y", mat=st)
    mb.box((piv[0] - 0.003, m.CYL_Y1 + 0.0005, piv[2] - 0.003), (0.004, m.CYL_Y1 + 0.006, m.CYL_Z + 0.004), mat=st)
    mb.cylinder(0.0030, 0.032, segments=14, centre=(0.0, m.CYL_Y1 + 0.016, m.CYL_Z), axis="Y", mat=st)   # ejector rod
    mb.translate(tuple(-v for v in piv))
    crane = c.finish(mb, "Crane", bevel=0.0005, segments=1)
    crane.location = piv

    cb = ctx.builder()
    cm = cb.material(mats.bare())
    length = m.CYL_Y1 - m.CYL_Y0
    cb.prism(c.fluted(m.CYL_R, m.CYL_R - 0.0030, 6), axis="Y", start=0.002, end=length - 0.004, mat=cm)
    cb.cylinder(m.CYL_R - 0.0006, 0.002, segments=24, centre=(0.0, 0.001, 0.0), axis="Y", mat=cm)
    cb.cylinder(m.CYL_R - 0.0015, 0.004, segments=24, centre=(0.0, length - 0.002, 0.0), axis="Y", mat=cm)  # chamfered front
    cb.translate((0.0, 0.0, 0.0))
    cylinder = c.finish(cb, "Cylinder", bevel=0.0006, segments=1, parent=crane)
    cylinder.location = tuple(a - b for a, b in zip(cyl_origin, piv))
    ch = ctx.builder()
    dark = ch.material(mats.polymer())
    for i in range(6):                                                                 # chamber mouths (front)
        a = math.pi / 2 + i * math.pi / 3
        ch.cylinder(0.0046, 0.0008, segments=14, centre=(math.cos(a) * m.CYL_CHAMBER_R, length + 0.0002,
                                                          math.sin(a) * m.CYL_CHAMBER_R), axis="Y", mat=dark)
        b = a + math.pi / 6                                                            # cylinder stop notches
        ch.box((math.cos(b) * (m.CYL_R - 0.0004) - 0.0014, 0.010, math.sin(b) * (m.CYL_R - 0.0004) - 0.0014),
               (math.cos(b) * (m.CYL_R - 0.0004) + 0.0014, 0.016, math.sin(b) * (m.CYL_R - 0.0004) + 0.0014), mat=dark)
    c.finish(ch, "CylinderDetails", parent=cylinder)
    return cylinder


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _frame(ctx, mats)
    cylinder = _crane(ctx, mats)

    ctx.marker("Muzzle", (0.0, m.BARREL_STD_END + 0.001, m.BORE_Z))
    barrel_mount = ctx.marker("BarrelMount", (0.0, m.FRAME_FRONT_Y, m.BORE_Z))
    ctx.marker("Eject", (m.CYL_R, (m.CYL_Y0 + m.CYL_Y1) / 2, m.CYL_Z), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, m.SIGHT_RAIL_Y, m.TOP_STRAP_Z1))
    # speedloader point: the cylinder's rear face, local +Z = forward into the chambers
    magwell = ctx.marker("Magwell", (0.0, 0.0, 0.0), rotation_euler=(-math.pi / 2, 0.0, 0.0), parent=cylinder)
    rail = (0.0, 0.135, m.BORE_Z - m.LUG_DZ - 0.002)
    ctx.marker("SideRail", rail)
    ctx.marker("Underbarrel", rail)
    ctx.marker("StockMount", m.STOCK_MOUNT)
    grip_mount = ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-(m.GRIP_HALF_WIDTH + 0.012), m.GRIP_HALF_DEPTH + m.GRIP_TAN * -0.020 - 0.004, -0.020))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    m.build_rear_sight(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, 0.0, m.SIGHT_DZ), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    m.build_cartridges(ctx, mats, parent=stock_mag)
    stock_barrel = ctx.marker("StockBarrel", (0.0, 0.0, 0.0), parent=barrel_mount)
    m.build_barrel(ctx, mats, "std", parent=stock_barrel, muzzle=False)
    stock_grip = ctx.marker("StockGrip", (0.0, 0.0, 0.0), parent=grip_mount)
    m.build_grip(ctx, mats, rubber=False, parent=stock_grip)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
    ctx.source_extra["crane"] = "Crane pivot on the hinge axis; +80 deg about local Z (Godot) swings the cylinder out left"
