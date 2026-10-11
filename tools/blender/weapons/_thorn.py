"""Shared dimensions and part builders for the Brannock Thorn compound bow (B4-18).

Private helper: imported by ``thorn_bow.py`` and ``thorn_bow_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = the hand pivot on the riser grip (the bow hand; ENV D decides which hand of the
``bow`` viewmodel set holds it).

Machined alloy riser with a leather-wrapped grip, split limbs, two cams, cables, a pin sight on the
left of the riser (``SightRail``), the arrow on the rest at the left of the riser (``Magwell`` at the
nock point, insertion axis = forward along the arrow; ``StockMagazine`` = the nocked arrow). Animated
parts (B4-18): ``StringUpper`` / ``StringLower``, each with its origin on its cam axle and running to the
nock point; ENV A swings them about local X (and stretches them) to meet the drawn nock, and moves the
arrow back with the draw. ``Muzzle`` = the arrow tip at brace.
"""

from __future__ import annotations

import math

import _common as c

RISER_HW = 0.0120
CAM_Y = -0.125
CAM_Z = 0.405
CAM_R = 0.030
STRING_Y = CAM_Y - CAM_R
NOCK = (0.0, STRING_Y, 0.050)
ARROW_X = -0.014
ARROW_Z = 0.050
ARROW_LEN = 0.700
MAGWELL_POS = (ARROW_X, STRING_Y, ARROW_Z)
MAGWELL_ROT = (-math.pi / 2, 0.0, 0.0)          # local +Z (insertion) = forward along the arrow
MUZZLE_Y = STRING_Y + ARROW_LEN + 0.010
SIGHT_RAIL = (0.0, 0.060, 0.096)
PIN = (-0.026, 0.075, 0.006)                    # pin tip in the SightRail frame
UNDER = (0.0, 0.040, -0.062)


def leather(mats):
    return mats.ctx.material("leather_dark", "#493730", roughness=0.8)


def build_arrow(ctx, mats, broadhead: bool, parent=None, name="CarbonArrow"):
    """Arrow in the Magwell frame: nock at the origin, shaft along local +Z, three vanes, steel head."""
    mb = ctx.builder()
    shaft = mb.material(mats.polymer())
    vane = mb.material(mats.tan())
    mb.cylinder(0.0038, ARROW_LEN - 0.040, segments=12, centre=(0.0, 0.0, 0.010 + (ARROW_LEN - 0.040) / 2), axis="Z",
                mat=shaft)
    mb.cylinder(0.0042, 0.012, segments=12, centre=(0.0, 0.0, 0.006), axis="Z", mat=vane)
    for i in range(3):
        a = 2 * math.pi * i / 3 + math.pi / 2
        pts = c.radial([(0.0036, 0.024), (0.0036, 0.090), (0.0120, 0.084), (0.0130, 0.040)], a)
        c.plate(mb, pts, (-math.sin(a), math.cos(a), 0.0), 0.0008, vane)
    body = c.finish(mb, name, bevel=0.0, parent=parent)
    hd = ctx.builder()
    st = hd.material(mats.bare())
    tip = ARROW_LEN - 0.030
    if broadhead:
        hd.cylinder(0.0045, 0.020, segments=12, centre=(0.0, 0.0, tip + 0.010), axis="Z", mat=st)
        for i in range(3):
            a = 2 * math.pi * i / 3
            prof = [(0.0030, tip + 0.004), (0.0140, tip + 0.012), (0.0010, tip + 0.044), (0.0030, tip + 0.040)]
            pts = c.radial(prof, a)
            c.plate(hd, pts, (-math.sin(a), math.cos(a), 0.0), 0.0007, st)
        c.cone_z(hd, 0.0045, tip + 0.020, tip + 0.046, st)
    else:
        hd.cylinder(0.0040, 0.016, segments=12, centre=(0.0, 0.0, tip + 0.008), axis="Z", mat=st)
        c.cone_z(hd, 0.0040, tip + 0.016, tip + 0.036, st)
    c.finish(hd, name + "Head", parent=body)
    return body


def build_pin_sight(ctx, mats, five: bool, parent=None, name="PinSight"):
    """Pin sight on a bar off the riser's left face; origin = SightRail. Returns the AimPoint position."""
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    hx, hy, hz = PIN[0], PIN[1], PIN[2]
    mb.box((-0.020, -0.012, -0.010), (-RISER_HW + 0.001, 0.012, 0.010), mat=alu)                   # mount block
    mb.box((-0.024, 0.0, -0.004), (-0.018, hy - 0.020, 0.004), mat=alu)                           # bar
    r = 0.024 if five else 0.020
    outer = c.circle(r, 32, hx, hz)
    hole = list(reversed(c.circle(r - 0.004, 32, hx, hz)))
    mb.prism(outer, holes=[hole], axis="Y", start=hy - 0.006, end=hy + 0.006, mat=alu)
    body = c.finish(mb, name, bevel=0.0005, parent=parent)
    pn = ctx.builder()
    pm = pn.material(mats.reticle())
    pins = (0.0, -0.006, -0.012, -0.018, 0.006) if five else (0.0,)
    for dz in pins:
        pn.cylinder(0.0006, r - 0.006, segments=8, centre=(hx + (r - 0.006) / 2, hy, hz + dz), axis="X", mat=pm)
        pn.cylinder(0.0012, 0.002, segments=10, centre=(hx + 0.0005, hy, hz + dz), axis="X", mat=pm)
    c.finish(pn, name + "Pins", parent=body)
    if five:
        lv = ctx.builder()
        lv.cylinder(0.0030, 0.010, segments=12, centre=(hx, hy, hz - r + 0.003), axis="Y", mat=lv.material(mats.lens()))
        c.finish(lv, name + "Level", parent=body)
    return (hx, hy, hz)


def build_stabilizer(ctx, mats, parent=None, name="Stabilizer"):
    """Weighted rod screwed into the riser front; origin = Underbarrel, extends along +Y."""
    mb = ctx.builder()
    alu = mb.material(mats.alu())
    rub = mb.material(mats.rubber())
    mb.cylinder(0.0090, 0.012, segments=20, centre=(0.0, 0.006, 0.0), axis="Y", mat=rub)
    mb.cylinder(0.0075, 0.230, segments=20, centre=(0.0, 0.127, 0.0), axis="Y", mat=alu)
    for i in range(3):
        mb.cylinder(0.0120, 0.012, segments=24, centre=(0.0, 0.250 + i * 0.014, 0.0), axis="Y", mat=alu)
    return c.finish(mb, name, bevel=0.0006, parent=parent)
