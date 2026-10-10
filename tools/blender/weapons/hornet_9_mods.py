"""Brannock Hornet 9 mod parts (B4-04). Each pivot = its attach point (see _common.py):

* ``mod_hornet_iron_sights``   SIGHT      -> ``SightRail``  (stock irons, ``AimPoint``)
* ``mod_hornet_standard_mag``  MAGAZINE   -> ``Magwell``    (stock 30-round magazine)
* ``mod_hornet_extended_mag``  MAGAZINE   -> ``Magwell``    (45 rounds)
* ``mod_hornet_suppressor``    SUPPRESSOR -> ``Muzzle``     (fat 9 mm can; own ``Muzzle``)
* ``mod_hornet_stock_folded``  STOCK      -> ``StockMount`` (the stock swung onto the right side;
  hides ``StockStock``)
"""

import _common as c
import _hornet as h

TRI_BUDGET = 25000
VARIANTS = {
    "mod_hornet_iron_sights": {"part": "iron"},
    "mod_hornet_standard_mag": {"part": "mag"},
    "mod_hornet_extended_mag": {"part": "mag_ext"},
    "mod_hornet_suppressor": {"part": "suppressor"},
    "mod_hornet_stock_folded": {"part": "stock_folded"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = h.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, -0.060 - h.SIGHT_RAIL_Y, aim))
    elif part == "mag":
        h.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        h.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        c.build_can(ctx, mats, length=0.190, r=0.0200, overlap=0.012)
    elif part == "stock_folded":
        h.build_stock(ctx, mats, folded=True)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
