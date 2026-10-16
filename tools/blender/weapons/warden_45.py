"""Marrow & Kell Warden .45: all-steel single-stack heavy pistol, first-person model (B4-04).

216 mm long. Blued steel frame and slide, exposed hammer, beavertail, walnut grip panels, eight-round
magazine. The silhouette is deliberately different from the polymer Kestrel P9: rounded slide top,
hammer spur, wood panels, longer and slimmer.

Origin = firing-hand pivot (see _warden.py). Forward = Godot -Z, up = Godot +Y.

Node tree: ``Frame`` (+ ``GripPanels``, ``Trigger``, ``Controls``, ``Hammer``), ``Barrel``,
``Slide`` (+ ``SlideDetails``; slide-mounted ``SightRail`` and ``Eject``; ENV A cycles it along
local +Z). Stock parts: ``SightRail/StockSight`` (rear sight, ``AimPoint``), ``Magwell/StockMagazine``.
"""

import math

import _common as c
import _warden as w

ASSET_ID = "wpn_warden_45"
TRI_BUDGET = 25000


def _slide(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    hw = w.SLIDE_HW
    cross = [(-hw, w.SLIDE_BOTTOM_Z), (hw, w.SLIDE_BOTTOM_Z), (hw, w.SLIDE_TOP_Z - 0.009),
             (hw - 0.0025, w.SLIDE_TOP_Z - 0.0025), (hw - 0.0060, w.SLIDE_TOP_Z), (-hw + 0.0060, w.SLIDE_TOP_Z),
             (-hw + 0.0025, w.SLIDE_TOP_Z - 0.0025), (-hw, w.SLIDE_TOP_Z - 0.009)]
    mb.prism(cross, axis="Y", start=w.SLIDE_REAR_Y, end=w.SLIDE_FRONT_Y, mat=st)
    slide = c.finish(mb, "Slide", bevel=0.0010, segments=2)
    dt = ctx.builder()
    s2 = dt.material(mats.steel())
    dark = dt.material(mats.polymer())
    # rear serrations (dark inlays), ejection port, barrel bushing, extractor, front sight
    for side in (-1.0, 1.0):
        lo, hi = sorted((side * (hw - 0.0004), side * (hw + 0.0003)))
        for i in range(9):
            y = w.SLIDE_REAR_Y + 0.006 + i * 0.0032
            dt.box((lo, y, w.SLIDE_BOTTOM_Z + 0.004), (hi, y + 0.0014, w.SLIDE_TOP_Z - 0.007), mat=dark)
    dt.box((hw - 0.0005, 0.004, w.BORE_Z - 0.002), (hw + 0.0004, 0.040, w.SLIDE_TOP_Z - 0.004), mat=dark)
    dt.box((-0.0040, 0.006, w.SLIDE_TOP_Z - 0.0006), (0.0040, 0.038, w.SLIDE_TOP_Z + 0.0003), mat=dark)
    dt.box((hw - 0.0002, 0.040, w.BORE_Z + 0.004), (hw + 0.0006, 0.058, w.BORE_Z + 0.008), mat=s2)
    dt.cylinder(0.0098, 0.004, segments=28, centre=(0.0, w.SLIDE_FRONT_Y + 0.0015, w.BORE_Z), axis="Y", mat=s2)
    dt.box((-0.0016, w.FRONT_SIGHT_Y - 0.004, w.SLIDE_TOP_Z - 0.0005),
           (0.0016, w.FRONT_SIGHT_Y + 0.004, w.SLIDE_TOP_Z + w.SIGHT_DZ), mat=s2)
    details = c.finish(dt, "SlideDetails", bevel=0.0003, parent=slide)
    dots = ctx.builder()
    dots.cylinder(0.0009, 0.0006, segments=12, centre=(0.0, w.FRONT_SIGHT_Y - 0.0042, w.SLIDE_TOP_Z + w.SIGHT_DZ - 0.0012),
                  axis="Y", mat=dots.material(mats.dot()))
    c.finish(dots, "FrontSightDot", parent=details)
    return slide


def _barrel(ctx, mats):
    mb = ctx.builder()
    bare = mb.material(mats.bare())
    c.ring_y(mb, 0.0076, 0.0058, -0.020, w.MUZZLE_Y, w.BORE_Z, bare, segments=24)
    mb.box((-0.0078, -0.020, w.BORE_Z), (0.0078, 0.040, w.BORE_Z + 0.0105), mat=bare)   # hood under the port
    return c.finish(mb, "Barrel", bevel=0.0004)


def _frame(ctx, mats):
    mb = ctx.builder()
    st = mb.material(mats.steel())
    upper = [(-0.040, w.FRAME_TOP_Z), (w.FRAME_FRONT_Y, w.FRAME_TOP_Z), (w.FRAME_FRONT_Y, w.FRAME_BOTTOM_Z + 0.004),
             (w.FRAME_FRONT_Y - 0.006, w.FRAME_BOTTOM_Z), (-0.012, w.FRAME_BOTTOM_Z), (-0.034, 0.022),
             (-0.058, 0.026), (-0.060, 0.031), (-0.050, w.FRAME_TOP_Z)]                       # beavertail
    mb.prism(upper, axis="X", start=-w.FRAME_HW, end=w.FRAME_HW, mat=st)
    zt = w.GRIP_TOP_Z + 0.003
    grip = [(w.GRIP_HALF_DEPTH + w.GRIP_TAN * zt, zt),
            (w.GRIP_HALF_DEPTH + w.GRIP_TAN * w.GRIP_BOTTOM_Z, w.GRIP_BOTTOM_Z),
            (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * w.GRIP_BOTTOM_Z - 0.001, w.GRIP_BOTTOM_Z),
            (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * -0.030 - 0.0015, -0.030),
            (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * zt, zt), (-0.036, 0.022)]
    mb.prism(grip, axis="X", start=-w.GRIP_HALF_WIDTH, end=w.GRIP_HALF_WIDTH, mat=st)
    # rounded trigger guard
    gy = w.GRIP_HALF_DEPTH + w.GRIP_TAN * -0.004
    outer = [(gy - 0.002, w.FRAME_BOTTOM_Z + 0.001), (0.080, w.FRAME_BOTTOM_Z + 0.001), (0.084, 0.008),
             (0.082, -0.003), (0.074, -0.010), (gy + 0.002, -0.010), (gy - 0.003, -0.005)]
    hole = [(w.GRIP_HALF_DEPTH + w.GRIP_TAN * 0.016 + 0.001, 0.016), (0.072, 0.016), (0.076, 0.008),
            (0.074, 0.000), (0.068, -0.004), (gy + 0.0035, -0.004)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0055, end=0.0055, mat=st)
    frame = c.finish(mb, "Frame", bevel=0.0014, segments=2)

    # walnut panels with diamond checkering bumps
    pn = ctx.builder()
    wood = pn.material(mats.wood())
    for side in (-1.0, 1.0):
        x0, x1 = sorted((side * (w.GRIP_HALF_WIDTH - 0.0005), side * (w.GRIP_HALF_WIDTH + w.PANEL_T)))
        panel = [(w.GRIP_HALF_DEPTH + w.GRIP_TAN * 0.012 - 0.0045, 0.012),
                 (w.GRIP_HALF_DEPTH + w.GRIP_TAN * -0.068 - 0.0035, -0.068),
                 (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * -0.068 + 0.0040, -0.068),
                 (-w.GRIP_HALF_DEPTH + w.GRIP_TAN * 0.012 + 0.0040, 0.012)]
        pn.prism(panel, axis="X", start=x0, end=x1, mat=wood)
    panels = c.finish(pn, "GripPanels", bevel=0.0012, segments=2, parent=frame)
    ck = ctx.builder()
    km = ck.material(mats.wood())
    for side in (-1.0, 1.0):
        x = side * (w.GRIP_HALF_WIDTH + w.PANEL_T - 0.0001)
        for r in range(10):
            z = -0.058 + r * 0.0055
            yb = -w.GRIP_HALF_DEPTH + w.GRIP_TAN * z + 0.008
            yf = w.GRIP_HALF_DEPTH + w.GRIP_TAN * z - 0.008
            yy = yb + (0.00275 if r % 2 else 0.0)
            while yy < yf:
                c.pyramid(ck.bm, c.Vector((x, yy, z)), c.Vector((0, 1, 0)), c.Vector((0, 0, 1)),
                          c.Vector((side, 0, 0)), 0.0016, 0.0006, km)
                yy += 0.0055
        ck.cylinder(0.0028, 0.0008, segments=12, centre=(x, w.GRIP_TAN * -0.030, -0.030), axis="X",
                    mat=ck.material(mats.bare()))                                   # panel screw
    c.finish(ck, "GripChecker", parent=panels)

    tr = ctx.builder()
    tm = tr.material(mats.bare())
    tr.box((-0.0030, 0.046, -0.001), (0.0030, 0.050, 0.019), mat=tm)                # flat trigger
    tr.box((-0.0030, 0.046, 0.015), (0.0030, 0.066, 0.019), mat=tm)                 # bow
    c.finish(tr, "Trigger", bevel=0.0006, parent=frame)
    ct = ctx.builder()
    cs = ct.material(mats.steel())
    ct.box((-w.FRAME_HW - 0.0014, 0.012, 0.030), (-w.FRAME_HW + 0.0003, 0.048, 0.035), mat=cs)    # slide stop
    ct.cylinder(0.0035, 0.0016, segments=16, centre=(-w.FRAME_HW - 0.0008, 0.050, 0.032), axis="X", mat=cs)
    ct.box((-w.FRAME_HW - 0.0016, -0.040, 0.030), (-w.FRAME_HW + 0.0003, -0.022, 0.036), mat=cs)  # thumb safety
    ct.cylinder(0.0034, 0.0020, segments=16, centre=(-w.GRIP_HALF_WIDTH - 0.0008, 0.034, 0.010), axis="X", mat=cs)  # mag release
    c.finish(ct, "Controls", bevel=0.0004, parent=frame)
    hm = ctx.builder()
    hs = hm.material(mats.steel())
    hammer = [(-0.047, 0.036), (-0.047, 0.050), (-0.054, 0.062), (-0.062, 0.065), (-0.065, 0.061),
              (-0.058, 0.052), (-0.056, 0.036)]
    hm.prism(hammer, axis="X", start=-0.0032, end=0.0032, mat=hs)
    c.finish(hm, "Hammer", bevel=0.0006, segments=1, parent=frame)
    return frame


def build(ctx) -> None:
    mats = c.Mats(ctx)
    frame = _frame(ctx, mats)
    _barrel(ctx, mats)
    slide = _slide(ctx, mats)

    ctx.marker("Muzzle", (0.0, w.MUZZLE_Y, w.BORE_Z))
    ctx.marker("BarrelMount", (0.0, -0.020, w.BORE_Z))
    ctx.marker("Eject", (w.SLIDE_HW, 0.022, w.BORE_Z + 0.008), rotation_euler=(0.0, 0.0, -math.pi / 2), parent=slide)
    sight_rail = ctx.marker("SightRail", (0.0, w.SIGHT_RAIL_Y, w.SLIDE_TOP_Z), parent=slide)
    magwell = ctx.marker("Magwell", w.MAGWELL_POS, rotation_euler=w.MAGWELL_ROT)
    rail = (0.0, 0.120, w.FRAME_BOTTOM_Z)
    ctx.marker("SideRail", rail, rotation_euler=c.DUST_COVER_SIDE_RAIL_ROT)  # D-118: gadgets hang under the rail
    ctx.marker("Underbarrel", rail)
    ctx.marker("StockMount", (0.0, -0.058, 0.030))
    grip_mount = ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-(w.GRIP_HALF_WIDTH + 0.012), w.GRIP_HALF_DEPTH + w.GRIP_TAN * -0.020 - 0.004, -0.020))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    w.build_rear_sight(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, 0.0, w.SIGHT_DZ), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    w.build_mag(ctx, mats, extended=False, parent=stock_mag)
    c.wrap_part(ctx, [c.child(frame, "GripPanels")], grip_mount, "StockGrip", (0.0, 0.0, 0.0))  # D-118: swappable grip panels

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
