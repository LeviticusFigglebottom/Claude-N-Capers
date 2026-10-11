"""Shared dimensions and part builders for the Tillman Vise crossbow (B4-18).

Private helper: imported by ``vise_crossbow.py`` and ``vise_crossbow_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the pistol grip.

Polymer stock with a flight deck, a recurve prod across the front, a foot stirrup, a short optics bridge
over the latch (``SightRail``), a skeleton stock (``StockMount/StockStock``). The bolt lies in the flight
groove (``Magwell`` at the latch, insertion axis = forward along the bolt; ``StockMagazine`` = the bolt).
Animated parts (B4-18): the string is two halves, ``StringUpper`` (left) and ``StringLower`` (right), modelled
like the bow's (the bow's pair rolled 90 deg to the left about the bore): each half's origin is on its
limb-tip axle (``STRING_TIPS``) and the half runs to the centre along its local -Y (Upper) / +Y (Lower), local
X = up (Godot), so a rotation about local X swings it in the horizontal deck plane. Rest pose (rotation 0) =
RELAXED (brace): the halves meet on the centre plane at ``BRACE``, ``STRING_TRAVEL`` ahead of the nock.
Latched (on the bolt's nock = ``Magwell``, in the latch jaws): StringUpper turns by -``latch_angle()`` and StringLower by
+``latch_angle()`` about local X, each stretched by ``latch_stretch()`` along local Y (the prod limbs stay
fixed).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 18.0
GRIP_TOP_Z = 0.024
GRIP_BOTTOM_Z = -0.076

BODY_HW = 0.0200
BODY_REAR_Y = -0.060
DECK_Y1 = 0.420
DECK_Z = 0.062
BODY_BOTTOM_Z = 0.024
LATCH = (0.0, 0.012, DECK_Z + 0.004)
PROD_Y = 0.400
TIP_X = 0.290
TIP_Y = 0.335
BOLT_LEN = 0.430
MAGWELL_POS = (0.0, LATCH[1] + 0.004, DECK_Z + 0.004)
MAGWELL_ROT = (-math.pi / 2, 0.0, 0.0)
MUZZLE_Y = MAGWELL_POS[1] + BOLT_LEN + 0.010
STRING_TRAVEL = 0.160                             # latched -> brace (ENV D's crossbow STRING_TRAVEL)
STRING_NOCK = MAGWELL_POS                         # latched: the halves meet on the bolt's nock (in the latch jaws)
STRING_Z = STRING_NOCK[2]                         # the string runs level at the nock height
BRACE = (0.0, STRING_NOCK[1] + STRING_TRAVEL, STRING_Z)
STRING_TIPS = ((-TIP_X, TIP_Y + 0.004, STRING_Z), (TIP_X, TIP_Y + 0.004, STRING_Z))   # Upper (left), Lower (right)

BRIDGE_Y0, BRIDGE_Y1 = -0.050, 0.110
BRIDGE_POST_Y1 = 0.002                            # the single post stops short of the latched string
BRIDGE_Z = 0.092
RAIL_TOP_Z = BRIDGE_Z + 0.0062
SIGHT_RAIL_Y = 0.030
REAR_IRON_Y = -0.040 - SIGHT_RAIL_Y
IRON_AIM_DZ = 0.0140

STOCK_MOUNT = (0.0, BODY_REAR_Y, 0.050)
UNDER_Y = 0.250
SIDE_Y = 0.200


def _plan_len(a, b) -> float:
    return math.hypot(b[0] - a[0], b[1] - a[1])


def brace_len() -> float:
    """Length of one string half at rest (tip axle -> brace point)."""
    return _plan_len(STRING_TIPS[0], BRACE)


def latch_stretch() -> float:
    """Length factor of a half from brace to latched (tip axle -> latch / brace length)."""
    return _plan_len(STRING_TIPS[0], STRING_NOCK) / brace_len()


def latch_angle() -> float:
    """Swing (radians, > 0) of each half about its tip axle from brace to latched."""
    tx, ty = STRING_TIPS[1][0], STRING_TIPS[1][1]
    a0 = math.atan2(BRACE[1] - ty, BRACE[0] - tx)
    a1 = math.atan2(STRING_NOCK[1] - ty, STRING_NOCK[0] - tx)
    return abs(a1 - a0)


def build_irons(ctx, mats, parent=None, name="IronSights"):
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, BRIDGE_Y1 - 0.012 - SIGHT_RAIL_Y, 0.0, sight_h=IRON_AIM_DZ,
                                parent=parent, name=name)


def build_bolt(ctx, mats, heavy: bool, parent=None, name="BoltArrow"):
    """Crossbow bolt in the Magwell frame: nock at the origin, shaft along local +Z."""
    mb = ctx.builder()
    shaft = mb.material(mats.polymer())
    vane = mb.material(mats.olive())
    mb.cylinder(0.0042, BOLT_LEN - 0.030, segments=12, centre=(0.0, 0.0, (BOLT_LEN - 0.030) / 2), axis="Z", mat=shaft)
    for i in range(3):
        a = 2 * math.pi * i / 3 + math.pi / 2
        pts = c.radial([(0.0040, 0.008), (0.0040, 0.060), (0.0110, 0.056), (0.0120, 0.022)], a)
        c.plate(mb, pts, (-math.sin(a), math.cos(a), 0.0), 0.0008, vane)
    body = c.finish(mb, name, parent=parent)
    hd = ctx.builder()
    st = hd.material(mats.bare() if not heavy else mats.steel())
    tip = BOLT_LEN - 0.030
    r = 0.0055 if heavy else 0.0045
    hd.cylinder(r, 0.014, segments=12, centre=(0.0, 0.0, tip + 0.007), axis="Z", mat=st)
    c.cone_z(hd, r, tip + 0.014, tip + (0.040 if heavy else 0.030), st)
    c.finish(hd, name + "Head", parent=body)
    return body


def build_stock(ctx, mats, folded: bool, parent=None, name="Stock"):
    """Skeleton stock (as the Lark's, olive); origin = StockMount."""
    mb = ctx.builder()
    st = mb.material(mats.matte())
    mb.box((-0.0150, -0.016, -0.024), (0.0150, 0.0, 0.020), mat=st)
    mb.cylinder(0.0050, 0.048, segments=16, centre=(0.0175, -0.008, -0.002), axis="Z", mat=st)
    arm = ctx.builder()
    tm = arm.material(mats.olive())
    outer = [(-0.014, 0.018), (-0.230, 0.024), (-0.244, 0.014), (-0.244, -0.080), (-0.230, -0.086),
             (-0.200, -0.066), (-0.014, -0.022)]
    hole = [(-0.040, 0.006), (-0.214, 0.010), (-0.226, 0.002), (-0.226, -0.056), (-0.210, -0.054),
            (-0.040, -0.008)]
    arm.prism(outer, holes=[list(reversed(hole))], axis="X", start=-0.0110, end=0.0110, mat=tm)
    arm.box((-0.0150, -0.256, -0.084), (0.0150, -0.244, 0.022), mat=arm.material(mats.rubber()))
    if folded:
        arm.translate((-0.0175, 0.008, 0.0))
        arm.transform(c.rot_matrix(math.pi, "Z"))
        arm.translate((0.0175, -0.008, 0.0))
    body = c.finish(mb, name, bevel=0.0010, segments=1, parent=parent)
    c.finish(arm, name + "Arm", bevel=0.0015, segments=2, parent=body)
    return body
