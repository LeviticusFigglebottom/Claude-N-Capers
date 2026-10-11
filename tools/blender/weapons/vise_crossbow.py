"""Tillman Vise: recurve crossbow, first-person model (B4-18).

About 46 cm from the bolt tip to the stock hinge, prod 58 cm wide. Olive polymer stock with a flight
deck and an integral foregrip, recurve prod with a riser block and foot stirrup, short optics bridge
over the latch, skeleton stock, 43 cm bolt in the groove.

Origin = firing-hand pivot on the grip (see _vise.py). Forward = Godot -Z.

Node tree: ``Body`` (+ ``Deck``, ``Prod``, ``Stirrup``, ``Bridge``, ``TriggerGroup``, ``Grip``,
``Foregrip``), ``StringUpper`` / ``StringLower`` (the left / right string halves, origins on the limb-tip
axles, relaxed at rest; see _vise.py for the latch swing). Stock parts:
``SightRail/StockSight`` (flip-up irons, ``AimPoint``), ``Magwell/StockMagazine`` (the bolt),
``StockMount/StockStock`` (skeleton stock).
"""

import math

import _common as c
import _vise as v

ASSET_ID = "wpn_vise_crossbow"
TRI_BUDGET = 25000


def _body(ctx, mats):
    mb = ctx.builder()
    ol = mb.material(mats.olive())
    prof = [(v.BODY_REAR_Y, v.DECK_Z - 0.004), (v.DECK_Y1, v.DECK_Z - 0.004), (v.DECK_Y1 + 0.010, v.DECK_Z - 0.014),
            (v.DECK_Y1 + 0.010, v.BODY_BOTTOM_Z + 0.006), (0.180, v.BODY_BOTTOM_Z + 0.006), (0.150, v.BODY_BOTTOM_Z),
            (-0.020, v.BODY_BOTTOM_Z), (-0.045, 0.032), (v.BODY_REAR_Y, 0.034)]
    mb.prism(prof, axis="X", start=-v.BODY_HW, end=v.BODY_HW, mat=ol)
    body = c.finish(mb, "Body", bevel=0.0025, segments=2)
    dk = ctx.builder()
    al = dk.material(mats.alu())
    dark = dk.material(mats.polymer())
    dk.box((-0.0120, -0.010, v.DECK_Z - 0.006), (0.0120, v.DECK_Y1, v.DECK_Z), mat=al)
    dk.box((-0.0030, -0.008, v.DECK_Z - 0.0004), (0.0030, v.DECK_Y1 - 0.004, v.DECK_Z + 0.0004), mat=dark)  # groove
    dk.box((-0.0100, -0.004, v.DECK_Z), (0.0100, 0.022, v.DECK_Z + 0.010), mat=dark)                     # latch box
    c.finish(dk, "Deck", bevel=0.0006, parent=body)

    pr = ctx.builder()
    pm = pr.material(mats.matte())
    lm = pr.material(mats.polymer())
    pr.box((-0.030, v.PROD_Y - 0.020, v.DECK_Z - 0.026), (0.030, v.PROD_Y + 0.020, v.DECK_Z + 0.008), mat=pm)  # riser
    for sx in (-1.0, 1.0):
        pts = []
        n = 8
        for i in range(n + 1):
            s = i / n
            x = sx * (0.026 + (v.TIP_X - 0.026) * s)
            y = v.PROD_Y - 0.004 - (v.PROD_Y - v.TIP_Y) * s * s + 0.018 * math.sin(math.pi * s) * (1 - s)
            pts.append((x, y))
        w = [(x, y + 0.012 * (1 - 0.6 * i / n)) for i, (x, y) in enumerate(pts)]
        loop = pts + list(reversed(w))
        if sx < 0:
            loop = list(reversed(loop))
        pr.prism(loop, axis="Z", start=v.DECK_Z - 0.010, end=v.DECK_Z + 0.004, mat=lm)
        pr.cylinder(0.0060, 0.016, segments=12, centre=(sx * v.TIP_X, v.TIP_Y + 0.004, v.DECK_Z - 0.003), axis="Z",
                    mat=pm)
    c.finish(pr, "Prod", bevel=0.0010, segments=1, parent=body)
    sp = ctx.builder()
    sm = sp.material(mats.matte())
    outer = [(-0.040, 0.0), (0.040, 0.0), (0.040, 0.090), (-0.040, 0.090)]
    hole = [(-0.032, 0.008), (-0.032, 0.082), (0.032, 0.082), (0.032, 0.008)]
    sp.prism(outer, holes=[hole], axis="Z", start=v.DECK_Z - 0.014, end=v.DECK_Z - 0.008, mat=sm)
    sp.translate((0.0, v.PROD_Y + 0.018, 0.0))
    c.finish(sp, "Stirrup", bevel=0.0008, parent=body)

    br = ctx.builder()
    ba = br.material(mats.alu())
    # one deep post behind the latch carries the bridge (a front post would stand in the string's path)
    br.box((-0.0120, v.BRIDGE_Y0, v.DECK_Z), (0.0120, v.BRIDGE_POST_Y1, v.BRIDGE_Z), mat=ba)
    br.box((-0.0120, v.BRIDGE_POST_Y1, v.BRIDGE_Z - 0.010), (0.0120, v.BRIDGE_POST_Y1 + 0.030, v.BRIDGE_Z), mat=ba)
    br.box((-0.0095, v.BRIDGE_Y0, v.BRIDGE_Z - 0.004), (0.0095, v.BRIDGE_Y1, v.BRIDGE_Z), mat=ba)
    c.picatinny(br, ba, v.BRIDGE_Y0, v.BRIDGE_Y1, v.BRIDGE_Z)
    c.finish(br, "Bridge", bevel=0.0004, parent=body)

    c.build_trigger_group(ctx, mats, 0.012, 0.064, v.BODY_BOTTOM_Z, -0.012, 0.034, mat_name="polymer", parent=body)
    c.build_grip(ctx, mats, "olive", v.GRIP_TOP_Z, v.GRIP_BOTTOM_Z, 0.0195, 0.0150, v.GRIP_ANGLE_DEG, parent=body,
                 finger_bumps=3)
    fg = ctx.builder()
    fm = fg.material(mats.olive())
    fg.prism(c.rounded_rect(0.0140, 0.0160, 0.008, 0.0, v.UNDER_Y, corner_segments=3), axis="Z",
             start=v.BODY_BOTTOM_Z - 0.070, end=v.BODY_BOTTOM_Z + 0.008, mat=fm)
    c.finish(fg, "Foregrip", bevel=0.0018, segments=2, parent=body)
    return body


def _strings(ctx, mats):
    """Two string halves, relaxed (brace): Node3D ``StringUpper`` / ``StringLower`` on the limb-tip axles with the
    cord mesh (``...Cord``) as a child. Each half runs to ``BRACE`` along local -Y (Upper, left) / +Y (Lower, right)
    in Godot axes, local X = up: Blender local x = up, local z = -/+ the string direction (Godot Y = Blender z)."""
    ln = v.brace_len()
    for (tx, ty, tz), sz, name in ((v.STRING_TIPS[0], 1.0, "StringUpper"), (v.STRING_TIPS[1], -1.0, "StringLower")):
        mb = ctx.builder()
        sm = mb.material(mats.polymer())
        mb.cylinder(0.0016, ln, segments=8, centre=(0.0, 0.0, -sz * ln / 2), axis="Z", mat=sm)
        if sz > 0:                                                                    # centre serving
            mb.cylinder(0.0024, 0.024, segments=8, centre=(0.0, 0.0, -ln + 0.012), axis="Z", mat=mb.material(mats.matte()))
        else:
            mb.cylinder(0.0024, 0.024, segments=8, centre=(0.0, 0.0, ln - 0.012), axis="Z", mat=mb.material(mats.matte()))
        d = c.Vector((v.BRACE[0] - tx, v.BRACE[1] - ty, 0.0)).normalized()
        z = d * -sz
        x = c.Vector((0.0, 0.0, 1.0))
        rot = c.Matrix((x, z.cross(x), z)).transposed()
        # the export applies mesh rotations, so the turned frame is an empty with the cord mesh under it
        half = ctx.marker(name, (tx, ty, tz), rotation_euler=tuple(rot.to_euler("XYZ")))
        c.finish(mb, name + "Cord", parent=half)


def build(ctx) -> None:
    mats = c.Mats(ctx)
    _body(ctx, mats)
    _strings(ctx, mats)

    ctx.marker("Muzzle", (0.0, v.MUZZLE_Y, v.MAGWELL_POS[2]))
    ctx.marker("BarrelMount", (0.0, v.PROD_Y, v.DECK_Z))
    ctx.marker("Eject", (v.BODY_HW, 0.010, v.DECK_Z - 0.010), rotation_euler=(0.0, 0.0, -math.pi / 2))
    sight_rail = ctx.marker("SightRail", (0.0, v.SIGHT_RAIL_Y, v.RAIL_TOP_Z))
    magwell = ctx.marker("Magwell", v.MAGWELL_POS, rotation_euler=v.MAGWELL_ROT)
    ctx.marker("Underbarrel", (0.0, v.UNDER_Y, v.BODY_BOTTOM_Z - 0.070))
    ctx.marker("SideRail", (v.BODY_HW, v.SIDE_Y, 0.044))
    stock_mount = ctx.marker("StockMount", v.STOCK_MOUNT)
    ctx.marker("GripMount", (0.0, 0.0, 0.0))
    ctx.marker("LeftHandIK", (-0.016, v.UNDER_Y, v.BODY_BOTTOM_Z - 0.030))

    stock_sight = ctx.marker("StockSight", (0.0, 0.0, 0.0), parent=sight_rail)
    _irons, aim = v.build_irons(ctx, mats, parent=stock_sight)
    ctx.marker("AimPoint", (0.0, v.REAR_IRON_Y, aim), parent=stock_sight)
    stock_mag = ctx.marker("StockMagazine", (0.0, 0.0, 0.0), parent=magwell)
    v.build_bolt(ctx, mats, heavy=False, parent=stock_mag)
    stock_stock = ctx.marker("StockStock", (0.0, 0.0, 0.0), parent=stock_mount)
    v.build_stock(ctx, mats, folded=False, parent=stock_stock)

    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["string"] = ("StringUpper (left) / StringLower (right): origins on the limb-tip axles at Godot "
                                  f"x = -/+{v.TIP_X:.3f}; rest = relaxed, halves meet {v.STRING_TRAVEL:.3f} m ahead of the "
                                  f"nock (Magwell); latched = StringUpper -{math.degrees(v.latch_angle()):.2f} deg / StringLower "
                                  f"+{math.degrees(v.latch_angle()):.2f} deg about local X, local Y scaled "
                                  f"x{v.latch_stretch():.4f}")
    ctx.source_extra["origin"] = "firing-hand pivot: grip centre plane, mid grip depth, 20 mm below grip top"
