"""Tillman Hush 9 mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_hush_iron_sights``     SIGHT    -> ``SightRail``  (stock rear aperture + hooded front post, ``AimPoint``)
* ``mod_hush_standard_mag``    MAGAZINE -> ``Magwell``    (stock curved 30-round magazine)
* ``mod_hush_extended_mag``    MAGAZINE -> ``Magwell``    (40 rounds, longer curve)
* ``mod_hush_collapsed_stock`` STOCK    -> ``StockMount`` (the stock pushed in; hides ``StockStock``)

No suppressor slot: the can is integral. The reflex optic is the shared ``mod_rail_reflex_sight``.
"""

import _common as c
import _hush as h

TRI_BUDGET = 25000
VARIANTS = {
    "mod_hush_iron_sights": {"part": "iron"},
    "mod_hush_standard_mag": {"part": "mag"},
    "mod_hush_extended_mag": {"part": "mag_ext"},
    "mod_hush_collapsed_stock": {"part": "stock_in"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = h.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, h.REAR_IRON_Y, aim))
    elif part == "mag":
        h.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        h.build_mag(ctx, mats, extended=True)
    elif part == "stock_in":
        h.build_stock(ctx, mats, collapsed=True)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
