"""Brannock Osprey Marksman mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_osprey_scope_4x``       SIGHT      -> ``SightRail``   (stock fixed 4x scope, ``AimPoint``)
* ``mod_osprey_scope_8x``       SIGHT      -> ``SightRail``   (8x precision scope with parallax knob, ``AimPoint``)
* ``mod_osprey_standard_mag``   MAGAZINE   -> ``Magwell``     (stock 10-round magazine)
* ``mod_osprey_extended_mag``   MAGAZINE   -> ``Magwell``     (20 rounds)
* ``mod_osprey_suppressor``     SUPPRESSOR -> ``Muzzle``      (large can over the brake; own ``Muzzle``)
* ``mod_osprey_bipod``          FOREGRIP   -> ``Underbarrel`` (folding bipod on the handguard rail)
* ``mod_osprey_skeleton_stock`` STOCK -> ``StockMount`` (light open-frame skeleton stock; hides ``StockStock``; D-118)
* ``mod_osprey_precision_stock`` STOCK -> ``StockMount`` (heavy precision stock, cheek riser + thick pad; hides ``StockStock``; D-118)
"""

import _common as c
import _osprey as o

TRI_BUDGET = 25000
VARIANTS = {
    "mod_osprey_scope_4x": {"part": "scope4"},
    "mod_osprey_scope_8x": {"part": "scope8"},
    "mod_osprey_standard_mag": {"part": "mag"},
    "mod_osprey_extended_mag": {"part": "mag_ext"},
    "mod_osprey_suppressor": {"part": "suppressor"},
    "mod_osprey_bipod": {"part": "bipod"},
    "mod_osprey_skeleton_stock": {"part": "stock_light"},
    "mod_osprey_precision_stock": {"part": "stock_heavy"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part in ("scope4", "scope8"):
        o.build_scope(ctx, mats, eight=part == "scope8")
    elif part == "mag":
        o.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        o.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        o.build_suppressor(ctx, mats)
    elif part == "bipod":
        c.build_bipod(ctx, mats, leg_len=0.170)
    elif part == "stock_light":
        c.build_skeleton_stock(ctx, mats, 0.230, 0.020, -0.116, 0.0170, front_z=-0.016)
    elif part == "stock_heavy":
        c.build_precision_stock(ctx, mats, 0.268, 0.020, -0.116, 0.0175, front_z=-0.016)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
