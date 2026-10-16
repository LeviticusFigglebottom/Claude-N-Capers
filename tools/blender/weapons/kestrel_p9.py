"""Halvard Arms Kestrel P9: compact 9 mm polymer-frame service pistol, first-person model (B1-03).

180 mm long, 30 mm wide at the grip, 141 mm tall with the standard magazine.

Origin = firing-hand pivot (grip centre plane, centred front-to-back, 20 mm below the top of the
grip; see _p9.py). Forward = Godot -Z (muzzle), up = Godot +Y.

Node tree (Godot names):
* ``Frame`` (polymer frame, grip, trigger guard, accessory rail),
  ``Trigger``, ``Controls`` (slide stop, takedown lever)
* ``Barrel``
* ``Slide`` (separate so ENV A can cycle it along local +Z) with ``SlideDetails`` (front sight,
  extractor), and the slide-mounted markers ``SightRail`` and ``Eject``
* markers per contracts/visual_slots.md: ``Muzzle``, ``Eject``, ``SightRail``, ``Magwell``,
  ``Underbarrel``, ``SideRail``, ``StockMount``, ``GripMount``, ``BarrelMount``, ``LeftHandIK``
* stock parts under their markers (hidden by WeaponVisual when a mod replaces them):
  ``SightRail/StockSight`` (rear sight, ``AimPoint`` in the notch), ``Magwell/StockMagazine``,
  ``GripMount/StockGrip`` (``FrameTexture``: grip stippling + front-strap grooves, D-118).

Marker orientation: -Z (Godot) = forward for all, except ``Eject`` (-Z points out of the ejection
port, to the right) and ``Magwell`` (rotated with the 18 deg grip rake, +Y = insertion axis).
"""

import math

import _common as c
import _p9 as p9

ASSET_ID = "wpn_kestrel_p9"
TRI_BUDGET = 25000


def _slide(ctx, mats):
    mb = ctx.builder()
    steel = mb.material(mats.steel())
    profile = [(p9.SLIDE_REAR_Y, p9.SLIDE_BOTTOM_Z), (p9.SLIDE_FRONT_Y, p9.SLIDE_BOTTOM_Z),
               (p9.SLIDE_FRONT_Y, p9.SLIDE_TOP_Z - 0.007), (p9.SLIDE_FRONT_Y - 0.007, p9.SLIDE_TOP_Z),
               (p9.SLIDE_REAR_Y + 0.002, p9.SLIDE_TOP_Z), (p9.SLIDE_REAR_Y, p9.SLIDE_TOP_Z - 0.003)]
    mb.prism(profile, axis="X", start=-p9.SLIDE_HALF_WIDTH, end=p9.SLIDE_HALF_WIDTH, mat=steel)
    # the top flat is narrower than the sides: chamfer the long top edges with a wedge-shaped bevel
    mb.bevel(0.0022, segments=3)
    slide = mb.to_object("Slide")

    cut = ctx.builder()
    # ejection port (right side + top)
    cut.box((0.0010, 0.004, p9.BORE_Z + 0.0005), (0.0200, 0.036, 0.0800))
    # rear and front cocking serrations, both sides
    for side in (-1.0, 1.0):
        x_in, x_out = side * (p9.SLIDE_HALF_WIDTH - 0.0010), side * 0.0200
        lo_x, hi_x = min(x_in, x_out), max(x_in, x_out)
        for i in range(8):
            y = p9.SLIDE_REAR_Y + 0.006 + i * 0.0030
            cut.box((lo_x, y, p9.SLIDE_BOTTOM_Z + 0.004), (hi_x, y + 0.0013, p9.SLIDE_TOP_Z - 0.003))
        for i in range(5):
            y = 0.104 + i * 0.0030
            cut.box((lo_x, y, p9.SLIDE_BOTTOM_Z + 0.007), (hi_x, y + 0.0013, p9.SLIDE_TOP_Z - 0.004))
    p9.geo.boolean(slide, cut.to_object("SlideCuts"))
    p9.finish_object_uv(slide)

    # front sight, extractor, guide-rod face
    dt = ctx.builder()
    st = dt.material(mats.steel())
    dt.box((-0.0018, p9.FRONT_SIGHT_Y - 0.0035, p9.SLIDE_TOP_Z - 0.0005),
           (0.0018, p9.FRONT_SIGHT_Y + 0.0035, p9.SLIDE_TOP_Z + p9.SIGHT_LINE_DZ), mat=st)
    dt.box((p9.SLIDE_HALF_WIDTH - 0.0004, 0.036, p9.BORE_Z + 0.003),
           (p9.SLIDE_HALF_WIDTH + 0.0005, 0.050, p9.BORE_Z + 0.0075), mat=st)
    dt.cylinder(0.0042, 0.0010, segments=20, centre=(0.0, p9.SLIDE_FRONT_Y + 0.0001, 0.0385), axis="Y",
                mat=dt.material(mats.matte()))
    details = p9.finish(dt, "SlideDetails", bevel=0.0004, parent=slide)
    dots = ctx.builder()
    dots.cylinder(0.0010, 0.0006, segments=12,
                  centre=(0.0, p9.FRONT_SIGHT_Y - 0.0037, p9.SLIDE_TOP_Z + p9.SIGHT_LINE_DZ - 0.0015), axis="Y",
                  mat=dots.material(mats.dot()))
    p9.finish(dots, "FrontSightDot", parent=details)
    return slide


def _barrel(ctx, mats):
    mb = ctx.builder()
    bare = mb.material(mats.bare())
    dark = mb.material(mats.polymer())
    mb.cylinder(p9.BARREL_RADIUS, 0.125 - p9.BARREL_REAR_Y, segments=24,
                centre=(0.0, (0.125 + p9.BARREL_REAR_Y) / 2, p9.BORE_Z), axis="Y", mat=bare)
    p9.ring_y(mb, p9.BARREL_RADIUS, p9.BORE_RADIUS, 0.125, p9.MUZZLE_Y, p9.BORE_Z, bare, segments=24)
    mb.cylinder(p9.BORE_RADIUS + 0.0001, 0.0008, segments=24, centre=(0.0, 0.128, p9.BORE_Z), axis="Y", mat=dark)
    # chamber hood, visible through the ejection port
    mb.box((-0.0074, p9.BARREL_REAR_Y, p9.BORE_Z), (0.0074, 0.034, p9.BORE_Z + 0.0090), mat=bare)
    return p9.finish(mb, "Barrel", bevel=0.0005, segments=1)


def _frame(ctx, mats):
    mb = ctx.builder()
    poly = mb.material(mats.polymer())
    # upper frame: rails under the slide, dust cover, beavertail tang
    upper = [(-0.032, p9.FRAME_TOP_Z), (p9.FRAME_FRONT_Y, p9.FRAME_TOP_Z), (p9.FRAME_FRONT_Y, 0.025),
             (p9.FRAME_FRONT_Y - 0.005, p9.FRAME_BOTTOM_Z), (-0.012, p9.FRAME_BOTTOM_Z),
             (-0.030, 0.0235), (-0.043, 0.0300), (-0.042, 0.0340)]
    mb.prism(upper, axis="X", start=-p9.FRAME_HALF_WIDTH, end=p9.FRAME_HALF_WIDTH, mat=poly)
    # grip: raked, palm swell on the back strap, flared magwell at the bottom
    zt = p9.GRIP_TOP_Z + 0.004
    fy, fz = p9.grip_bottom_point(p9.GRIP_PERP_HALF)
    by, bz = p9.grip_bottom_point(-p9.GRIP_PERP_HALF)
    grip = [(p9.grip_front_y(zt), zt),
            (p9.grip_front_y(-0.010) + 0.0015, -0.010),
            (p9.grip_front_y(-0.045) + 0.0010, -0.045),
            (p9.grip_front_y(fz + 0.006) + 0.0006, fz + 0.006),
            (fy + 0.0016, fz),
            (by - 0.0016, bz),
            (p9.grip_back_y(bz + 0.008) - 0.0004, bz + 0.008),
            (p9.grip_back_y(-0.035) - 0.0022, -0.035),
            (p9.grip_back_y(0.004) - 0.0004, 0.004),
            (-0.0300, 0.0235)]
    mb.prism(grip, axis="X", start=-p9.GRIP_HALF_WIDTH, end=p9.GRIP_HALF_WIDTH, mat=poly)
    # trigger guard (square front with a hook), joins the grip front strap
    gy = p9.grip_front_y(-0.004)
    outer = [(gy - 0.002, p9.FRAME_BOTTOM_Z + 0.001), (0.079, p9.FRAME_BOTTOM_Z + 0.001), (0.081, 0.010),
             (0.0790, -0.0040), (0.0730, -0.0095), (gy + 0.002, -0.0095), (gy - 0.003, -0.0050)]
    hole = [(p9.grip_front_y(0.017) + 0.001, 0.0170), (0.0700, 0.0170), (0.0720, 0.0080),
            (0.0700, -0.0010), (0.0660, -0.0040), (gy + 0.0035, -0.0040)]
    mb.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0058, end=0.0058, mat=poly)
    # accessory rail under the dust cover: spine + four cross-slot lugs
    mb.box((-0.0100, p9.RAIL_REAR_Y, p9.RAIL_BOTTOM_Z + 0.0025), (0.0100, p9.RAIL_FRONT_Y, p9.FRAME_BOTTOM_Z + 0.001),
           mat=poly)
    lug = (p9.RAIL_FRONT_Y - p9.RAIL_REAR_Y - 3 * 0.0035) / 4
    for i in range(4):
        y = p9.RAIL_REAR_Y + i * (lug + 0.0035)
        mb.box((-0.0105, y, p9.RAIL_BOTTOM_Z), (0.0105, y + lug, p9.RAIL_BOTTOM_Z + 0.0030), mat=poly)
    frame = p9.finish(mb, "Frame", bevel=0.0018, segments=3)

    # stippling panels on both grip sides
    st = ctx.builder()
    sm = st.material(mats.stipple())
    for side in (-1.0, 1.0):
        p9.stipple_patch(st, ctx.rng, sm, side, side * (p9.GRIP_HALF_WIDTH - 0.0001), -0.058, 0.008,
                         front_inset=0.0065, back_inset=0.0070)
    # front-strap grooves
    for i in range(6):
        z = -0.052 + i * 0.0085
        y = p9.grip_front_y(z) + 0.0012
        st.box((-0.0090, y - 0.0006, z - 0.0011), (0.0090, y + 0.0004, z + 0.0011), mat=sm)
    p9.finish(st, "FrameTexture", parent=frame)

    # trigger: curved blade with a safety tab
    tr = ctx.builder()
    tm = tr.material(mats.polymer())
    pts_front, pts_back = [], []
    for i in range(9):
        s = i / 8
        z = 0.0175 - s * 0.0185
        yc = 0.0430 + 0.0055 * s * s - 0.0015 * s
        pts_front.append((yc + 0.0018, z))
        pts_back.append((yc - 0.0018, z))
    tr.prism(pts_front + list(reversed(pts_back)), axis="X", start=-0.0032, end=0.0032, mat=tm)
    tr.box((-0.0010, 0.0450, 0.0020), (0.0010, 0.0472, 0.0110), mat=tr.material(mats.steel()))
    p9.finish(tr, "Trigger", bevel=0.0006, segments=2, parent=frame)

    # controls: slide stop (left), takedown lever (both sides), magazine release (left)
    ct = ctx.builder()
    cs = ct.material(mats.steel())
    ct.box((-p9.FRAME_HALF_WIDTH - 0.0012, 0.020, 0.0300), (-p9.FRAME_HALF_WIDTH + 0.0003, 0.040, 0.0345), mat=cs)
    ct.box((-p9.FRAME_HALF_WIDTH - 0.0010, 0.054, 0.0255), (p9.FRAME_HALF_WIDTH + 0.0010, 0.064, 0.0300), mat=cs)
    ct.box((-p9.GRIP_HALF_WIDTH - 0.0010, p9.grip_front_y(0.012) - 0.0060, 0.0080),
           (-p9.GRIP_HALF_WIDTH + 0.0005, p9.grip_front_y(0.012) - 0.0005, 0.0145), mat=ct.material(mats.polymer()))
    p9.finish(ct, "Controls", bevel=0.0004, segments=1, parent=frame)
    return frame


def build(ctx) -> None:
    mats = p9.Mats(ctx)
    frame = _frame(ctx, mats)
    _barrel(ctx, mats)
    slide = _slide(ctx, mats)

    # markers (contracts/visual_slots.md)
    ctx.marker("Muzzle", (0.0, p9.MUZZLE_Y, p9.BORE_Z))
    ctx.marker("BarrelMount", (0.0, p9.BARREL_REAR_Y, p9.BORE_Z))
    ctx.marker("Eject", (p9.SLIDE_HALF_WIDTH, 0.020, p9.BORE_Z + 0.009), rotation_euler=(0.0, 0.0, -math.pi / 2),
               parent=slide)
    sight_rail = ctx.marker("SightRail", (0.0, p9.SIGHT_RAIL_Y, p9.SLIDE_TOP_Z), parent=slide)
    magwell = ctx.marker("Magwell", p9.MAGWELL_POS, rotation_euler=p9.MAGWELL_ROT)
    rail = (0.0, (p9.RAIL_FRONT_Y + p9.RAIL_REAR_Y) / 2, p9.RAIL_BOTTOM_Z)
    ctx.marker("SideRail", rail, rotation_euler=c.DUST_COVER_SIDE_RAIL_ROT)  # D-118: gadgets hang under the rail
    ctx.marker("Underbarrel", rail)
    ctx.marker("StockMount", (0.0, -0.043, 0.030))
    grip_mount = ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-(p9.GRIP_HALF_WIDTH + 0.010), p9.grip_front_y(-0.020) - 0.004, -0.020))

    # stock parts (WeaponVisual hides them when a mod of that type replaces them)
    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    p9.build_rear_sight(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, 0.0, p9.SIGHT_LINE_DZ), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    p9.build_magazine(ctx, mats, extended=False, parent=stock_mag)
    c.wrap_part(ctx, [c.child(frame, "FrameTexture")], grip_mount, "StockGrip", (0.0, 0.0, 0.0))  # D-118: swappable grip texture

    ctx.source_extra["tris_lod0"] = p9.tris_of_scene()
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
