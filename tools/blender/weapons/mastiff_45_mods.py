"""Tillman Ironworks Mastiff .45 mod parts (B4-12). Each pivot = its attach point (see _common.py):

* ``mod_mastiff_iron_sights``    SIGHT      -> ``SightRail``   (stock flip-up irons, ``AimPoint``)
* ``mod_mastiff_standard_mag``   MAGAZINE   -> ``Magwell``     (stock 25-round stick)
* ``mod_mastiff_extended_mag``   MAGAZINE   -> ``Magwell``     (35 rounds, witness window)
* ``mod_mastiff_suppressor``     SUPPRESSOR -> ``Muzzle``      (fat .45 can; own ``Muzzle``)
* ``mod_mastiff_vertical_grip``  FOREGRIP   -> ``Underbarrel`` (vertical foregrip on the shroud rail)

The reflex optic is the shared ``mod_rail_reflex_sight``.
"""

import _common as c
import _mastiff as m

TRI_BUDGET = 25000
VARIANTS = {
    "mod_mastiff_iron_sights": {"part": "iron"},
    "mod_mastiff_standard_mag": {"part": "mag"},
    "mod_mastiff_extended_mag": {"part": "mag_ext"},
    "mod_mastiff_suppressor": {"part": "suppressor"},
    "mod_mastiff_vertical_grip": {"part": "grip"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = m.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, m.REAR_IRON_Y, aim))
    elif part == "mag":
        m.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        m.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        m.build_suppressor(ctx, mats)
    elif part == "grip":
        c.build_vertical_grip(ctx, mats, length=0.070)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
