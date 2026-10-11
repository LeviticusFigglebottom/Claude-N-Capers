"""Graff-Lindqvist Harrow 12 mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_harrow_iron_sights``  SIGHT      -> ``SightRail`` (stock rear aperture + front post, ``AimPoint``)
* ``mod_harrow_standard_mag`` MAGAZINE   -> ``Magwell``   (stock eight-shell box)
* ``mod_harrow_extended_mag`` MAGAZINE   -> ``Magwell``   (twelve-shell box)
* ``mod_harrow_muzzle_brake`` BARREL_EXT -> ``Muzzle``    (ported brake; own ``Muzzle``)

The reflex optic is the shared ``mod_rail_reflex_sight`` on the dust-cover rail.
"""

import _common as c
import _harrow as r

TRI_BUDGET = 25000
VARIANTS = {
    "mod_harrow_iron_sights": {"part": "iron"},
    "mod_harrow_standard_mag": {"part": "mag"},
    "mod_harrow_extended_mag": {"part": "mag_ext"},
    "mod_harrow_muzzle_brake": {"part": "brake"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = r.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, r.REAR_IRON_Y, aim))
    elif part == "mag":
        r.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        r.build_mag(ctx, mats, extended=True)
    elif part == "brake":
        r.build_brake(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
