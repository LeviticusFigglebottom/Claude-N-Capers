"""Brannock Lancet .45 mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_lancet_iron_sights``   SIGHT      -> ``SightRail``   (stock flip-up irons, ``AimPoint``)
* ``mod_lancet_standard_mag``  MAGAZINE   -> ``Magwell``     (stock 25-round magazine under the chin)
* ``mod_lancet_extended_mag``  MAGAZINE   -> ``Magwell``     (40 rounds)
* ``mod_lancet_suppressor``    SUPPRESSOR -> ``Muzzle``      (long can over the flash hider; own ``Muzzle``)
* ``mod_lancet_vertical_grip`` FOREGRIP   -> ``Underbarrel`` (vertical grip on the lower rail)

Optics are the shared ``mod_rail_reflex_sight`` / ``mod_rail_prism_scope``.
"""

import _common as c
import _lancet as v

TRI_BUDGET = 25000
VARIANTS = {
    "mod_lancet_iron_sights": {"part": "iron"},
    "mod_lancet_standard_mag": {"part": "mag"},
    "mod_lancet_extended_mag": {"part": "mag_ext"},
    "mod_lancet_suppressor": {"part": "suppressor"},
    "mod_lancet_vertical_grip": {"part": "grip"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = v.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, v.REAR_IRON_Y, aim))
    elif part == "mag":
        v.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        v.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        v.build_suppressor(ctx, mats)
    elif part == "grip":
        c.build_vertical_grip(ctx, mats, length=0.070)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
