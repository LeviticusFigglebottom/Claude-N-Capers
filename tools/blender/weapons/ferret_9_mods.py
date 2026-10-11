"""Graff-Lindqvist Ferret 9 mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_ferret_iron_sights``   SIGHT      -> ``SightRail``  (stock flip aperture + front post, ``AimPoint``)
* ``mod_ferret_standard_mag``  MAGAZINE   -> ``Magwell``    (stock 32-round stick through the grip)
* ``mod_ferret_extended_mag``  MAGAZINE   -> ``Magwell``    (40 rounds)
* ``mod_ferret_suppressor``    SUPPRESSOR -> ``Muzzle``     (fat can; own ``Muzzle``)
* ``mod_ferret_wood_stock``    STOCK      -> ``StockMount`` (fixed walnut stock; hides ``StockStock``)

The reflex optic is the shared ``mod_rail_reflex_sight`` on the top-cover rail.
"""

import _common as c
import _ferret as f

TRI_BUDGET = 25000
VARIANTS = {
    "mod_ferret_iron_sights": {"part": "iron"},
    "mod_ferret_standard_mag": {"part": "mag"},
    "mod_ferret_extended_mag": {"part": "mag_ext"},
    "mod_ferret_suppressor": {"part": "suppressor"},
    "mod_ferret_wood_stock": {"part": "wood_stock"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = f.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, f.REAR_IRON_Y, aim))
    elif part == "mag":
        f.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        f.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        f.build_suppressor(ctx, mats)
    elif part == "wood_stock":
        f.build_wood_stock(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
