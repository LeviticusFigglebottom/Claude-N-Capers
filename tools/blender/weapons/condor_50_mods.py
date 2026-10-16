"""Marrow & Kell Condor .50 mod parts (B4-12). Each pivot = its attach point (see _common.py):

* ``mod_condor_scope_6x``       SIGHT      -> ``SightRail``   (stock 6x scope, ``AimPoint`` at the eyepiece)
* ``mod_condor_scope_12x``      SIGHT      -> ``SightRail``   (34 mm 12x scope with parallax turret)
* ``mod_condor_standard_mag``   MAGAZINE   -> ``Magwell``     (stock five-round magazine)
* ``mod_condor_extended_mag``   MAGAZINE   -> ``Magwell``     (eight rounds)
* ``mod_condor_suppressor``     SUPPRESSOR -> ``Muzzle``      (massive can over the brake; own ``Muzzle``)
* ``mod_condor_bipod``          FOREGRIP   -> ``Underbarrel`` (folded bipod)
* ``mod_condor_skeleton_stock`` STOCK -> ``StockMount`` (light open-frame skeleton stock; hides ``StockStock``; D-118)
* ``mod_condor_precision_stock`` STOCK -> ``StockMount`` (heavy precision stock, cheek riser + thick pad; hides ``StockStock``; D-118)
"""

import _common as c
import _condor as k

TRI_BUDGET = 25000
VARIANTS = {
    "mod_condor_scope_6x": {"part": "scope6"},
    "mod_condor_scope_12x": {"part": "scope12"},
    "mod_condor_standard_mag": {"part": "mag"},
    "mod_condor_extended_mag": {"part": "mag_ext"},
    "mod_condor_suppressor": {"part": "suppressor"},
    "mod_condor_bipod": {"part": "bipod"},
    "mod_condor_skeleton_stock": {"part": "stock_light"},
    "mod_condor_precision_stock": {"part": "stock_heavy"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "scope6":
        k.build_scope(ctx, mats, high=False)
    elif part == "scope12":
        k.build_scope(ctx, mats, high=True)
    elif part == "mag":
        k.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        k.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        k.build_suppressor(ctx, mats)
    elif part == "bipod":
        c.build_bipod(ctx, mats, leg_len=0.220)
    elif part == "stock_light":
        c.build_skeleton_stock(ctx, mats, 0.300, 0.010, -0.128, 0.0150, front_z=-0.044, mat_name="alu")
    elif part == "stock_heavy":
        c.build_precision_stock(ctx, mats, 0.380, 0.010, -0.128, 0.0165, front_z=-0.044)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
