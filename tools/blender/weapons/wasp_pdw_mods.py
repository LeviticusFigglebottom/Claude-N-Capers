"""Brannock Wasp PDW mod parts (B4-12). Each pivot = its attach point (see _common.py):

* ``mod_wasp_iron_sights``   SIGHT      -> ``SightRail``  (stock flip-up irons, ``AimPoint``)
* ``mod_wasp_standard_mag``  MAGAZINE   -> ``Magwell``    (stock 30-round magazine through the grip)
* ``mod_wasp_extended_mag``  MAGAZINE   -> ``Magwell``    (40 rounds)
* ``mod_wasp_suppressor``    SUPPRESSOR -> ``Muzzle``     (slim can over the flash hider; own ``Muzzle``)
* ``mod_wasp_end_cap``       STOCK      -> ``StockMount`` (stock removed: end cap; hides ``StockStock``)

The reflex optic is the shared ``mod_rail_reflex_sight``.
"""

import _common as c
import _wasp as w

TRI_BUDGET = 25000
VARIANTS = {
    "mod_wasp_iron_sights": {"part": "iron"},
    "mod_wasp_standard_mag": {"part": "mag"},
    "mod_wasp_extended_mag": {"part": "mag_ext"},
    "mod_wasp_suppressor": {"part": "suppressor"},
    "mod_wasp_end_cap": {"part": "cap"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = w.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, w.REAR_IRON_Y, aim))
    elif part == "mag":
        w.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        w.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        w.build_suppressor(ctx, mats)
    elif part == "cap":
        w.build_end_cap(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
