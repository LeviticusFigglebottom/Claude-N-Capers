"""Brannock Corsair mod parts (B4-04). Each pivot = its attach point (see _common.py):

* ``mod_corsair_iron_sights``     SIGHT      -> ``SightRail``   (stock flip-up irons, ``AimPoint``)
* ``mod_corsair_standard_mag``    MAGAZINE   -> ``Magwell``     (stock 30-round magazine)
* ``mod_corsair_extended_mag``    MAGAZINE   -> ``Magwell``     (40 rounds, longer, witness window)
* ``mod_corsair_suppressor``      SUPPRESSOR -> ``Muzzle``      (slips over the flash hider; own ``Muzzle``)
* ``mod_corsair_vertical_grip``   FOREGRIP   -> ``Underbarrel`` (vertical foregrip)

Rail optics shared with other rifles are in ``rail_optics_mods.py``.
"""

import _common as c
import _corsair as k

TRI_BUDGET = 25000
VARIANTS = {
    "mod_corsair_iron_sights": {"part": "iron"},
    "mod_corsair_standard_mag": {"part": "mag"},
    "mod_corsair_extended_mag": {"part": "mag_ext"},
    "mod_corsair_suppressor": {"part": "suppressor"},
    "mod_corsair_vertical_grip": {"part": "grip"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = k.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, k.REAR_IRON_Y, aim))
    elif part == "mag":
        k.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        k.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        c.build_can(ctx, mats, length=0.175, r=0.0190, overlap=k.HIDER_LEN - 0.004)
    elif part == "grip":
        c.build_vertical_grip(ctx, mats, length=0.080)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
