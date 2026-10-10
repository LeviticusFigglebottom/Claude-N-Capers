"""Tillman Ironworks Plowman 12 mod parts (B4-04). Each pivot = its attach point (see _common.py):

* ``mod_plowman_ghost_ring``       SIGHT      -> ``SightRail``  (stock ghost ring + front blade)
* ``mod_plowman_standard_tube``    MAGAZINE   -> ``Magwell``    (stock six-shell tube)
* ``mod_plowman_extended_tube``    MAGAZINE   -> ``Magwell``    (eight shells, barrel clamp)
* ``mod_plowman_choke``            BARREL_EXT -> ``Muzzle``     (breaching choke; own ``Muzzle``)
* ``mod_plowman_pistol_grip``      STOCK      -> ``StockMount`` (stockless grip; hides ``StockStock``)
"""

import _common as c
import _plowman as p

TRI_BUDGET = 25000
VARIANTS = {
    "mod_plowman_ghost_ring": {"part": "iron"},
    "mod_plowman_standard_tube": {"part": "tube"},
    "mod_plowman_extended_tube": {"part": "tube_ext"},
    "mod_plowman_choke": {"part": "choke"},
    "mod_plowman_pistol_grip": {"part": "grip"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = p.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, -0.040, aim))
    elif part == "tube":
        p.build_tube(ctx, mats, extended=False)
    elif part == "tube_ext":
        p.build_tube(ctx, mats, extended=True)
    elif part == "choke":
        p.build_choke(ctx, mats)
    elif part == "grip":
        p.build_pistol_grip(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
