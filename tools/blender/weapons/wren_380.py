"""Halvard Arms Wren .380: compact single-stack carry pistol, first-person model (B4-18).

About 15 cm long. Slim black polymer frame with a short stippled grip and an integral beavertail, bare
steel slide with rear serrations and low sights, seven-round magazine with a finger-rest pad. The
smallest gun in the armory (PD2 compact-pistol analog).

Origin = firing-hand pivot (see _wren.py). Forward = Godot -Z.

Node tree: ``Frame`` (+ ``GripTexture``, ``Trigger``, ``Controls``), ``Barrel``, ``Slide`` (+
``SlideDetails``; slide-mounted ``SightRail`` and ``Eject``; ENV A cycles it along local +Z). Stock parts:
``SightRail/StockSight`` (notch rear sight, ``AimPoint``), ``Magwell/StockMagazine``.
"""

import math

import _common as c
import _wren as w

ASSET_ID = "wpn_wren_380"
TRI_BUDGET = 25000


def _slide(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.bare())
    hw = w.SLIDE_HW
    cross = [(-hw, w.SLIDE_BOTTOM_Z), (hw, w.SLIDE_BOTTOM_Z), (hw, w.SLIDE_TOP_Z - 0.007), (hw - 0.005, w.SLIDE_TOP_Z),
             (-hw + 0.005, w.SLIDE_TOP_Z), (-hw, w.SLIDE_TOP_Z - 0.007)]
    mb.prism(cross, axis="Y", start=w.SLIDE_REAR_Y, end=w.SLIDE_FRONT_Y, mat=st)
    slide = c.finish(mb, "Slide", bevel=0.0012, segments=2)
    dt = ctx.builder()
    dark = dt.material(mats.steel())
    for side in (-1.0, 1.0):                                         # rear serrations
        lo, hi = sorted((side * (hw - 0.0004), side * (hw + 0.0003)))
        for i in range(7):
            y = w.SLIDE_REAR_Y + 0.004 + i * 0.0036
            dt.box((lo, y, w.SLIDE_BOTTOM_Z + 0.004), (hi, y + 0.0016, w.SLIDE_TOP_Z - 0.007), mat=dark)
    dt.box((hw - 0.0005, 0.002, w.BORE_Z - 0.002), (hw + 0.0004, 0.030, w.SLIDE_TOP_Z - 0.004), mat=dark)   # port
    dt.box((-0.0014, w.FRONT_SIGHT_Y - 0.004, w.SLIDE_TOP_Z - 0.0005),
           (0.0014, w.FRONT_SIGHT_Y + 0.003, w.SLIDE_TOP_Z + w.SIGHT_DZ), mat=dark)                         # front
    dt.cylinder(0.0050, 0.0012, segments=20, centre=(0.0, w.SLIDE_FRONT_Y + 0.0002, w.BORE_Z), axis="Y", mat=dark)
    c.finish(dt, "SlideDetails", bevel=0.0002, parent=slide)
    return slide


def _frame(ctx, mats):
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    upper = [(-0.040, w.FRAME_TOP_Z), (w.FRAME_FRONT_Y, w.FRAME_TOP_Z), (w.FRAME_FRONT_Y, w.FRAME_BOTTOM_Z),
             (w.FRAME_FRONT_Y - 0.006, w.FRAME_BOTTOM_Z - 0.004), (0.062, w.FRAME_BOTTOM_Z - 0.004),
             (0.060, w.FRAME_BOTTOM_Z), (-0.010, w.FRAME_BOTTOM_Z), (-0.032, 0.020), (-0.044, 0.024), (-0.045, 0.029)]
    mb.prism(upper, axis="X", start=-w.FRAME_HW, end=w.FRAME_HW, mat=poly)
    zt = w.GRIP_TOP_Z + 0.003
    grip = [(w.GRIP_HALF_DEPTH + w.GRIP_TAN * zt, zt),
            (w.GRIP_HALF_DEPTH + w.GRIP_TAN * w.GRIP_BOTTOM_Z, w.GRIP_BOTTOM_Z),
            (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * w.GRIP_BOTTOM_Z, w.GRIP_BOTTOM_Z),
            (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * -0.026 - 0.0020, -0.026),
            (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * zt - 0.004, zt)]
    mb.prism(grip, axis="X", start=-w.GRIP_HALF_WIDTH, end=w.GRIP_HALF_WIDTH, mat=poly)
    gy = w.GRIP_HALF_DEPTH + w.GRIP_TAN * -0.004
    outer = [(gy - 0.002, w.FRAME_BOTTOM_Z + 0.001), (0.066, w.FRAME_BOTTOM_Z + 0.001), (0.068, 0.006),
             (0.064, -0.006), (0.056, -0.010), (gy + 0.002, -0.010), (gy - 0.003, -0.005)]
    hole = [(w.GRIP_HALF_DEPTH + w.GRIP_TAN * 0.014 + 0.001, 0.014), (0.059, 0.014), (0.061, 0.006),
            (0.058, -0.001), (0.053, -0.004), (gy + 0.0035, -0.004)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0060, end=0.0060, mat=poly)
    frame = c.finish(mb, "Frame", bevel=0.0016, segments=2)

    gt = ctx.builder()
    gm = gt.material(mats.stipple())
    for side in (-1.0, 1.0):
        x = side * (w.GRIP_HALF_WIDTH - 0.0001)
        for r in range(9):
            z = -0.048 + r * 0.0058
            yb = -w.GRIP_HALF_DEPTH + w.GRIP_TAN * z + 0.006
            yf = w.GRIP_HALF_DEPTH + w.GRIP_TAN * z - 0.006
            yy = yb + (0.0029 if r % 2 else 0.0)
            while yy < yf:
                c.pyramid(gt.bm, c.Vector((x, yy, z)), c.Vector((0, 1, 0)), c.Vector((0, 0, 1)),
                          c.Vector((side, 0, 0)), 0.0013, 0.0005, gm)
                yy += 0.0058
    c.finish(gt, "GripTexture", parent=frame)
    tr = ctx.builder()
    tm = tr.material(mats.polymer())
    pf, pb = [], []
    for i in range(8):
        t = i / 7
        z = w.FRAME_BOTTOM_Z - t * 0.018
        yc = 0.040 + 0.006 * t * t
        pf.append((yc + 0.0020, z))
        pb.append((yc - 0.0020, z))
    tr.prism(pf + list(reversed(pb)), axis="X", start=-0.0028, end=0.0028, mat=tm)
    c.finish(tr, "Trigger", bevel=0.0005, parent=frame)
    ct = ctx.builder()
    cs = ct.material(mats.steel())
    ct.box((-w.FRAME_HW - 0.0012, 0.010, 0.028), (-w.FRAME_HW + 0.0003, 0.040, 0.0325), mat=cs)            # slide stop
    ct.cylinder(0.0030, 0.0018, segments=16, centre=(-w.GRIP_HALF_WIDTH - 0.0007, 0.030, 0.010), axis="X", mat=cs)
    ct.cylinder(0.0022, 0.0010, segments=12, centre=(w.FRAME_HW + 0.0004, 0.074, 0.025), axis="X", mat=cs)  # pin
    c.finish(ct, "Controls", bevel=0.0003, parent=frame)
    return frame


def _barrel(ctx, mats):
    mb = ctx.builder()
    bare = mb.material(mats.bare())
    c.ring_y(mb, 0.0062, 0.0040, -0.018, w.MUZZLE_Y - 0.002, w.BORE_Z, bare, segments=20)
    mb.box((-0.0064, -0.018, w.BORE_Z), (0.0064, 0.030, w.BORE_Z + 0.0090), mat=bare)
    return c.finish(mb, "Barrel", bevel=0.0004)


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _frame(ctx, mats)
    _barrel(ctx, mats)
    slide = _slide(ctx, mats)

    ctx.marker("Muzzle", (0.0, w.MUZZLE_Y, w.BORE_Z))
    ctx.marker("BarrelMount", (0.0, -0.018, w.BORE_Z))
    ctx.marker("Eject", (w.SLIDE_HW, 0.016, w.BORE_Z + 0.007), rotation_euler=(0.0, 0.0, -math.pi / 2), parent=slide)
    sight_rail = ctx.marker("SightRail", (0.0, w.SIGHT_RAIL_Y, w.SLIDE_TOP_Z), parent=slide)
    magwell = ctx.marker("Magwell", w.MAGWELL_POS, rotation_euler=w.MAGWELL_ROT)
    rail = (0.0, w.RAIL_Y, w.FRAME_BOTTOM_Z - 0.0040)
    ctx.marker("SideRail", rail, rotation_euler=c.DUST_COVER_SIDE_RAIL_ROT)  # D-118: gadgets hang under the rail
    ctx.marker("Underbarrel", rail)
    ctx.marker("StockMount", w.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-(w.GRIP_HALF_WIDTH + 0.012), w.GRIP_HALF_DEPTH + w.GRIP_TAN * -0.020 - 0.004, -0.020))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    w.build_rear_sight(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, 0.0, w.SIGHT_DZ), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    w.build_mag(ctx, mats, extended=False, parent=stock_mag)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
