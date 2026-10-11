"""Tillman Vise crossbow mod parts (B4-18). Each pivot = its attach point (see _common.py / _vise.py):

* ``mod_vise_iron_sights``  SIGHT    -> ``SightRail``  (stock flip-up irons on the bridge, ``AimPoint``)
* ``mod_vise_bolt``         MAGAZINE -> ``Magwell``    (stock carbon bolt, nock at the origin, along +Z)
* ``mod_vise_heavy_bolt``   MAGAZINE -> ``Magwell``    (heavier bolt with a steel head)
* ``mod_vise_folded_stock`` STOCK    -> ``StockMount`` (skeleton stock folded along the right side)

Optics are the shared ``mod_rail_reflex_sight`` / ``mod_rail_prism_scope`` on the bridge rail.
"""

import _common as c
import _vise as v

TRI_BUDGET = 25000
VARIANTS = {
    "mod_vise_iron_sights": {"part": "iron"},
    "mod_vise_bolt": {"part": "bolt"},
    "mod_vise_heavy_bolt": {"part": "heavy"},
    "mod_vise_folded_stock": {"part": "folded"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = v.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, v.REAR_IRON_Y, aim))
    elif part == "bolt":
        v.build_bolt(ctx, mats, heavy=False)
    elif part == "heavy":
        v.build_bolt(ctx, mats, heavy=True, name="HeavyBoltArrow")
    elif part == "folded":
        v.build_stock(ctx, mats, folded=True)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
