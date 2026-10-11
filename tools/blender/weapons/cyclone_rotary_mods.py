"""Brannock Cyclone Rotary mod parts (B4-18). Each pivot = its attach point (see _common.py / _cyclone.py):

* ``mod_cyclone_iron_sights``    SIGHT    -> ``SightRail``   (stock flip-up irons on the handle rail, ``AimPoint``)
* ``mod_cyclone_box_500``        MAGAZINE -> ``Magwell``     (stock belt box on the left)
* ``mod_cyclone_box_750``        MAGAZINE -> ``Magwell``     (bigger belt box)
* ``mod_cyclone_short_barrels``  BARREL   -> ``BarrelMount`` (short cluster on the Rotor; own ``Muzzle``)

The reflex optic is the shared ``mod_rail_reflex_sight``.
"""

import _common as c
import _cyclone as y

TRI_BUDGET = 25000
VARIANTS = {
    "mod_cyclone_iron_sights": {"part": "iron"},
    "mod_cyclone_box_500": {"part": "box"},
    "mod_cyclone_box_750": {"part": "box_big"},
    "mod_cyclone_short_barrels": {"part": "short"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = y.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, y.REAR_IRON_Y, aim))
    elif part == "box":
        y.build_box(ctx, mats, big=False)
    elif part == "box_big":
        y.build_box(ctx, mats, big=True)
    elif part == "short":
        y.build_cluster(ctx, mats, y.SHORT_LEN, muzzle=True)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
