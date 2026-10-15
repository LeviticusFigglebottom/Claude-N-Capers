"""Shared dimensions and part builders for the Graff-Lindqvist Drover 762 battle rifle (B4-12).

Private helper: imported by ``drover_762.py`` and ``drover_762_mods.py``. Axes and pivot rules: see
``_common.py``. Origin = firing-hand pivot on the walnut pistol grip (grip centre plane, mid depth,
20 mm below the grip top).

Long-stroke 7.62 rifle: stamped steel receiver with a railed top cover, walnut furniture, deeply
curved steel magazine, 3-port muzzle brake. The fixed walnut stock is the stock part
``StockMount/StockStock``; the side-folding steel stock mod replaces it (shown folded along the
left side of the receiver).
"""

from __future__ import annotations

import math

import _common as c

GRIP_ANGLE_DEG = 20.0
GRIP_TAN = math.tan(math.radians(GRIP_ANGLE_DEG))
GRIP_TOP_Z = 0.022
GRIP_BOTTOM_Z = -0.076
GRIP_HALF_DEPTH = 0.0175
GRIP_HALF_WIDTH = 0.0140

BORE_Z = 0.074
REC_HW = 0.0150
REC_REAR_Y = -0.072
REC_FRONT_Y = 0.205
REC_BOTTOM_Z = 0.020
REC_TOP_Z = 0.090                 # top cover crown
RAIL_BASE_Z = REC_TOP_Z + 0.0005
RAIL_TOP_Z = RAIL_BASE_Z + 0.0062
RAIL_Y0, RAIL_Y1 = -0.055, 0.170
SIGHT_RAIL_Y = 0.040

GAS_Z = BORE_Z + 0.019
HG_Y0, HG_Y1 = REC_FRONT_Y + 0.006, 0.395
HG_HW = 0.0230
HG_BOTTOM_Z = 0.040
UNDER_Y = 0.330
SIDE_Y = 0.340

BARREL_R = 0.0090
BARREL_END_Y = 0.600
GAS_BLOCK_Y = 0.420
FRONT_SIGHT_Y = 0.565
BRAKE_LEN = 0.050
MUZZLE_Y = BARREL_END_Y + BRAKE_LEN + 0.001

MAGWELL_Y0, MAGWELL_Y1 = 0.088, 0.150
MAGWELL_POS = (0.0, (MAGWELL_Y0 + MAGWELL_Y1) / 2, REC_BOTTOM_Z - 0.004)
MAG_HW = 0.0125
MAG_HD = 0.0300
MAG_INSIDE = 0.034
MAG_STD_BELOW = 0.150
MAG_STD_CURVE = 0.062
MAG_EXT_BELOW = 0.192
MAG_EXT_CURVE = 0.092

STOCK_MOUNT = (0.0, REC_REAR_Y, 0.058)
IRON_AIM_DZ = 0.0170
REAR_IRON_Y = -0.045 - SIGHT_RAIL_Y        # in the SightRail frame


def build_irons(ctx, mats, parent=None, name="IronSights"):
    """Flip-up rear aperture on the cover rail + front post on the barrel's sight block.
    Origin = SightRail. Returns (body, aim_z)."""
    front_base = (BORE_Z + 0.016) - RAIL_TOP_Z
    return c.build_flipup_irons(ctx, mats, REAR_IRON_Y, FRONT_SIGHT_Y - SIGHT_RAIL_Y, front_base,
                                sight_h=IRON_AIM_DZ, parent=parent, name=name)


def build_mag(ctx, mats, extended: bool, parent=None, name="Magazine"):
    """Ribbed steel magazine with a deep forward curve; origin = Magwell."""
    below = MAG_EXT_BELOW if extended else MAG_STD_BELOW
    curve = MAG_EXT_CURVE if extended else MAG_STD_CURVE
    return c.build_box_mag(ctx, mats, below, MAG_HW, MAG_HD, curve=curve, inside=MAG_INSIDE, mat_name="steel",
                           round_r=0.0040, ribs=4 if extended else 3, parent=parent, name=name, base_drop=0.007)


def _to_mount(pts):
    return [(y - STOCK_MOUNT[1], z - STOCK_MOUNT[2]) for y, z in pts]


STOCK_PROFILE = [
    (REC_REAR_Y + 0.004, REC_TOP_Z - 0.006), (REC_REAR_Y - 0.010, 0.082), (-0.200, 0.072), (-0.338, 0.066),
    (-0.346, 0.060), (-0.352, -0.054), (-0.340, -0.060), (-0.230, -0.030), (-0.120, 0.004),
    (REC_REAR_Y - 0.004, 0.026), (REC_REAR_Y + 0.004, REC_BOTTOM_Z + 0.002)]


def build_stock(ctx, mats, parent=None, name="Stock"):
    """Fixed walnut stock with a steel butt plate; origin = StockMount, extends along -Y."""
    mb = ctx.builder()
    wood = mb.material(mats.wood())
    mb.prism(_to_mount(STOCK_PROFILE), axis="X", start=-0.0200, end=0.0200, mat=wood)
    yb = -0.352 - STOCK_MOUNT[1]
    c.taper_x(mb, lambda y, z: 0.70 + 0.30 * min(1.0, max(0.0, y / yb)))
    body = c.finish(mb, name, bevel=0.0040, segments=3, parent=parent)
    bp = ctx.builder()
    st = bp.material(mats.steel())
    bp.prism(_to_mount([(-0.352, 0.064), (-0.358, -0.058), (-0.364, -0.057), (-0.358, 0.065)]), axis="X",
             start=-0.0198, end=0.0198, mat=st)
    for z in (0.030, -0.030):                                   # butt-plate screws
        bp.cylinder(0.0030, 0.0012, segments=12, centre=(0.0, -0.3646 - STOCK_MOUNT[1], z - STOCK_MOUNT[2] + 0.004),
                    axis="Y", mat=bp.material(mats.bare()))
    c.finish(bp, name + "Plate", bevel=0.0012, segments=1, parent=body)
    sw = ctx.builder()                                          # sling swivel
    sw.prism(c.circle(0.0070, 16, 0.0, 0.0), holes=[list(reversed(c.circle(0.0045, 12, 0.0, 0.0)))], axis="X",
             start=-0.0015, end=0.0015, mat=sw.material(mats.steel()))
    sw.translate((0.0, -0.300 - STOCK_MOUNT[1], -0.052 - STOCK_MOUNT[2]))
    c.finish(sw, name + "Swivel", parent=body)
    return body


def build_folding_stock(ctx, mats, parent=None, name="FoldingStock"):
    """Side-folding steel stock, FOLDED forward along the receiver's left side; origin = StockMount."""
    mb = ctx.builder()
    st = mb.material(mats.matte())
    rub = mb.material(mats.rubber())
    # hinge block on the receiver rear
    mb.box((-0.0150, -0.016, -0.026), (0.0150, 0.0, 0.026), mat=st)
    mb.cylinder(0.0055, 0.060, segments=16, centre=(-0.0190, -0.008, 0.0), axis="Z", mat=st)
    # two flat struts lying along the left side (folded), pointing forward
    x0, x1 = -0.0250, -0.0195
    for z0 in (0.012, -0.030):
        mb.box((x0, -0.010, z0), (x1, 0.215, z0 + 0.012), mat=st)
    # butt plate at the front end of the folded stock, flat against the receiver side
    mb.box((x0 - 0.002, 0.205, -0.036), (x1, 0.222, 0.030), mat=st)
    mb.box((x0 - 0.004, 0.208, -0.034), (x0 - 0.002, 0.219, 0.028), mat=rub)
    return c.finish(mb, name, bevel=0.0010, segments=1, parent=parent)


def build_brake_suppressor(ctx, mats, parent=None, name="Suppressor"):
    """7.62 can that slips over the muzzle brake; origin = Muzzle (front of the brake)."""
    return c.build_can(ctx, mats, length=0.185, r=0.0205, overlap=BRAKE_LEN - 0.004, bore_r=0.0058,
                       parent=parent, name=name, cap_style="teeth")
