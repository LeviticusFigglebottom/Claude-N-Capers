"""Graff-Lindqvist Drover 762 mod parts (B4-12). Each pivot = its attach point (see _common.py):

* ``mod_drover_iron_sights``     SIGHT      -> ``SightRail``  (stock flip-up rear + barrel post, ``AimPoint``)
* ``mod_drover_standard_mag``    MAGAZINE   -> ``Magwell``    (stock 30-round steel magazine)
* ``mod_drover_extended_mag``    MAGAZINE   -> ``Magwell``    (40 rounds, deeper curve)
* ``mod_drover_suppressor``      SUPPRESSOR -> ``Muzzle``     (slips over the slant brake; own ``Muzzle``)
* ``mod_drover_folding_stock``   STOCK      -> ``StockMount`` (side-folder, shown folded; hides ``StockStock``)

Rail optics shared with other rifles are in ``rail_optics_mods.py``.
"""

import _common as c
import _drover as d

TRI_BUDGET = 25000
VARIANTS = {
    "mod_drover_iron_sights": {"part": "iron"},
    "mod_drover_standard_mag": {"part": "mag"},
    "mod_drover_extended_mag": {"part": "mag_ext"},
    "mod_drover_suppressor": {"part": "suppressor"},
    "mod_drover_folding_stock": {"part": "stock_fold"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = d.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, d.REAR_IRON_Y, aim))
    elif part == "mag":
        d.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        d.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        d.build_brake_suppressor(ctx, mats)
    elif part == "stock_fold":
        d.build_folding_stock(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
