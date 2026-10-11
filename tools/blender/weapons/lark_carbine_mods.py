"""Halvard Arms Lark Carbine mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_lark_iron_sights``   SIGHT      -> ``SightRail``   (stock flip-up irons, ``AimPoint``)
* ``mod_lark_standard_mag``  MAGAZINE   -> ``Magwell``     (stock curved 30-round magazine)
* ``mod_lark_extended_mag``  MAGAZINE   -> ``Magwell``     (40 rounds)
* ``mod_lark_suppressor``    SUPPRESSOR -> ``Muzzle``      (rifle can over the hider; own ``Muzzle``)
* ``mod_lark_folded_stock``  STOCK      -> ``StockMount``  (the stock folded along the right side; hides ``StockStock``)

Optics are the shared ``mod_rail_reflex_sight`` / ``mod_rail_prism_scope``.
"""

import _common as c
import _lark as t

TRI_BUDGET = 25000
VARIANTS = {
    "mod_lark_iron_sights": {"part": "iron"},
    "mod_lark_standard_mag": {"part": "mag"},
    "mod_lark_extended_mag": {"part": "mag_ext"},
    "mod_lark_suppressor": {"part": "suppressor"},
    "mod_lark_folded_stock": {"part": "folded"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = t.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, t.REAR_IRON_Y, aim))
    elif part == "mag":
        t.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        t.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        t.build_suppressor(ctx, mats)
    elif part == "folded":
        t.build_stock(ctx, mats, folded=True)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
