"""Tillman Furnace flamethrower mod parts (B4-18). Each pivot = its attach point (see _common.py / _furnace.py):

* ``mod_furnace_post_sight``   SIGHT      -> ``SightRail`` (stock notch + post, ``AimPoint``)
* ``mod_furnace_tank``         MAGAZINE   -> ``Magwell``   (stock fuel tank under the shield)
* ``mod_furnace_large_tank``   MAGAZINE   -> ``Magwell``   (larger tank)
* ``mod_furnace_wide_nozzle``  BARREL_EXT -> ``Muzzle``    (flared nozzle; own ``Muzzle``)
* ``mod_furnace_long_nozzle``  BARREL_EXT -> ``Muzzle``    (long narrow nozzle; own ``Muzzle``)

PD2's flamethrower takes only nozzle and tank parts, so there are no optics, grips or stocks.
"""

import _common as c
import _furnace as f

TRI_BUDGET = 25000
VARIANTS = {
    "mod_furnace_post_sight": {"part": "post"},
    "mod_furnace_tank": {"part": "tank"},
    "mod_furnace_large_tank": {"part": "tank_big"},
    "mod_furnace_wide_nozzle": {"part": "wide"},
    "mod_furnace_long_nozzle": {"part": "long"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "post":
        _s, aim = f.build_post_sight(ctx, mats)
        ctx.marker("AimPoint", (0.0, 0.0, aim))
    elif part == "tank":
        f.build_tank(ctx, mats, big=False)
    elif part == "tank_big":
        f.build_tank(ctx, mats, big=True)
    elif part in ("wide", "long"):
        f.build_nozzle(ctx, mats, wide=part == "wide")
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
