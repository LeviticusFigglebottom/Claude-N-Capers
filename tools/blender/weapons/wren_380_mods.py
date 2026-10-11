"""Halvard Arms Wren .380 mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_wren_iron_sights``   SIGHT      -> ``SightRail``  (stock notch rear sight, ``AimPoint``)
* ``mod_wren_standard_mag``  MAGAZINE   -> ``Magwell``    (stock 7-round magazine, finger-rest pad)
* ``mod_wren_extended_mag``  MAGAZINE   -> ``Magwell``    (10 rounds, sleeved grip extension)
* ``mod_wren_suppressor``    SUPPRESSOR -> ``Muzzle``     (short can; own ``Muzzle``)
* ``mod_wren_reflex_sight``  SIGHT      -> ``SightRail``  (micro red dot in the rear-sight cut; ``AimPoint``)
"""

import _common as c
import _wren as w

TRI_BUDGET = 25000
VARIANTS = {
    "mod_wren_iron_sights": {"part": "iron"},
    "mod_wren_standard_mag": {"part": "mag"},
    "mod_wren_extended_mag": {"part": "mag_ext"},
    "mod_wren_suppressor": {"part": "suppressor"},
    "mod_wren_reflex_sight": {"part": "reflex"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        w.build_rear_sight(ctx, mats)
        ctx.marker("AimPoint", (0.0, 0.0, w.SIGHT_DZ))
    elif part == "mag":
        w.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        w.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        w.build_suppressor(ctx, mats)
    elif part == "reflex":
        w.build_reflex(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
