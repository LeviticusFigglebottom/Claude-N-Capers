"""Marrow & Kell Shrike mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_shrike_iron_sights``     SIGHT    -> ``SightRail``   (stock buckhorn + front blade, ``AimPoint``)
* ``mod_shrike_peep_sight``      SIGHT    -> ``SightRail``   (tang aperture + front blade, ``AimPoint``)
* ``mod_shrike_scout_scope``     SIGHT    -> ``SightRail``   (long-eye-relief scope on a barrel base, ``AimPoint``)
* ``mod_shrike_tube``            MAGAZINE -> ``Magwell``     (stock eight-round tube at the loading port)
* ``mod_shrike_carbine_barrel``  BARREL   -> ``BarrelMount`` (shorter octagonal barrel; own ``Muzzle``)
"""

import _common as c
import _shrike as s

TRI_BUDGET = 25000
VARIANTS = {
    "mod_shrike_iron_sights": {"part": "iron"},
    "mod_shrike_peep_sight": {"part": "peep"},
    "mod_shrike_scout_scope": {"part": "scope"},
    "mod_shrike_tube": {"part": "tube"},
    "mod_shrike_carbine_barrel": {"part": "carbine"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _b, aim = s.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, s.REAR_IRON_Y, aim))
    elif part == "peep":
        _b, aim = s.build_peep(ctx, mats)
        ctx.marker("AimPoint", (0.0, s.REC_REAR_Y + 0.004 - s.SIGHT_RAIL_Y, aim))
    elif part == "scope":
        s.build_scope(ctx, mats)
    elif part == "tube":
        s.build_tube(ctx, mats)
    elif part == "carbine":
        s.build_barrel(ctx, mats, s.CARBINE_END_Y, muzzle=True)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
