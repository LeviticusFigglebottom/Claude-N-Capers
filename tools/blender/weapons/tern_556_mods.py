"""Graff-Lindqvist Tern mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_tern_iron_sights``   SIGHT      -> ``SightRail``   (stock flip-up irons, ``AimPoint``)
* ``mod_tern_standard_mag``  MAGAZINE   -> ``Magwell``     (stock 30-round windowed magazine behind the grip)
* ``mod_tern_extended_mag``  MAGAZINE   -> ``Magwell``     (42 rounds)
* ``mod_tern_suppressor``    SUPPRESSOR -> ``Muzzle``      (rifle can over the hider; own ``Muzzle``)
* ``mod_tern_vertical_grip`` FOREGRIP   -> ``Underbarrel`` (vertical grip on the lower rail)

Optics are the shared ``mod_rail_reflex_sight`` / ``mod_rail_prism_scope``.
"""

import _common as c
import _tern as t

TRI_BUDGET = 25000
VARIANTS = {
    "mod_tern_iron_sights": {"part": "iron"},
    "mod_tern_standard_mag": {"part": "mag"},
    "mod_tern_extended_mag": {"part": "mag_ext"},
    "mod_tern_suppressor": {"part": "suppressor"},
    "mod_tern_vertical_grip": {"part": "grip"},
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
    elif part == "grip":
        c.build_vertical_grip(ctx, mats, length=0.075)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
