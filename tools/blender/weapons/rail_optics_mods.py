"""Picatinny optics shared by the rail-equipped weapons (B4-04): Hornet 9, Corsair, Plowman 12,
Rampart. Origin = rail top centre (``SightRail``), +Y forward; each carries its own ``AimPoint``.

* ``mod_rail_reflex_sight``  SIGHT -> ``SightRail`` (open reflex, red dot)
* ``mod_rail_prism_scope``   SIGHT -> ``SightRail`` (compact fixed 3x prism)
"""

import _common as c

TRI_BUDGET = 25000
VARIANTS = {
    "mod_rail_reflex_sight": {"part": "reflex"},
    "mod_rail_prism_scope": {"part": "prism"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "reflex":
        c.build_rail_reflex(ctx, mats)
    elif part == "prism":
        c.build_prism_scope(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
