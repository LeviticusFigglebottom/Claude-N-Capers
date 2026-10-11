"""Brannock Thumper 40 mod parts (B4-18). Each pivot = its attach point (see _common.py / _thumper.py):

* ``mod_thumper_leaf_sight``     SIGHT    -> ``SightRail``   (stock folding ladder + front post, ``AimPoint``)
* ``mod_thumper_grenade``        MAGAZINE -> ``Magwell``     (stock: the 40 mm round in the chamber)
* ``mod_thumper_vertical_grip``  FOREGRIP -> ``Underbarrel`` (vertical grip under the forend)
* ``mod_thumper_stockless``      STOCK    -> ``StockMount``  (steel end cap; hides ``StockStock``)

The reflex optic is the shared ``mod_rail_reflex_sight`` on the barrel rail (it rides on the Breech).
"""

import _common as c
import _thumper as h

TRI_BUDGET = 25000
VARIANTS = {
    "mod_thumper_leaf_sight": {"part": "leaf"},
    "mod_thumper_grenade": {"part": "grenade"},
    "mod_thumper_vertical_grip": {"part": "grip"},
    "mod_thumper_stockless": {"part": "stockless"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "leaf":
        _leaf, aim = h.build_leaf(ctx, mats)
        ctx.marker("AimPoint", (0.0, -0.040, aim))
    elif part == "grenade":
        h.build_grenade(ctx, mats)
    elif part == "grip":
        c.build_vertical_grip(ctx, mats, length=0.070)
    elif part == "stockless":
        h.build_stock(ctx, mats, stockless=True)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
