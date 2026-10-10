"""Tillman Ironworks Mule 12 mod parts (B4-12). Each pivot = its attach point (see _common.py):

* ``mod_mule_ghost_ring``       SIGHT    -> ``SightRail``  (stock ghost ring + front blade, ``AimPoint``)
* ``mod_mule_standard_tube``    MAGAZINE -> ``Magwell``    (stock five-shell tube)
* ``mod_mule_extended_tube``    MAGAZINE -> ``Magwell``    (seven shells, barrel clamp)
* ``mod_mule_folding_stock``    STOCK    -> ``StockMount`` (deployed skeleton stock; the Mule ships stockless)

The reflex optic is the shared ``mod_rail_reflex_sight``.
"""

import _common as c
import _mule as p

TRI_BUDGET = 25000
VARIANTS = {
    "mod_mule_ghost_ring": {"part": "iron"},
    "mod_mule_standard_tube": {"part": "tube"},
    "mod_mule_extended_tube": {"part": "tube_ext"},
    "mod_mule_folding_stock": {"part": "stock"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = p.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, p.REAR_IRON_Y, aim))
    elif part == "tube":
        p.build_tube(ctx, mats, extended=False)
    elif part == "tube_ext":
        p.build_tube(ctx, mats, extended=True)
    elif part == "stock":
        p.build_folding_stock(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
