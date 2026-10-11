"""Marrow & Kell Reaper Double mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_reaper_bead_sight``     SIGHT    -> ``SightRail``   (stock tang notch, ``AimPoint``; the bead is on the rib)
* ``mod_reaper_fiber_sight``    SIGHT    -> ``SightRail``   (taller notch + glowing front bead clamp; ``AimPoint``)
* ``mod_reaper_shells``         MAGAZINE -> ``Magwell``     (stock: two shells in the chambers)
* ``mod_reaper_short_barrels``  BARREL   -> ``BarrelMount`` (sawn-off barrels on the Breech; own ``Muzzle``)
* ``mod_reaper_sawn_stock``     STOCK    -> ``StockMount``  (stock cut to a stub; hides ``StockStock``)
"""

import _common as c
import _reaper as r

TRI_BUDGET = 25000
VARIANTS = {
    "mod_reaper_bead_sight": {"part": "bead"},
    "mod_reaper_fiber_sight": {"part": "fiber"},
    "mod_reaper_shells": {"part": "shells"},
    "mod_reaper_short_barrels": {"part": "short"},
    "mod_reaper_sawn_stock": {"part": "sawn"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part in ("bead", "fiber"):
        _s, h = r.build_tang_sight(ctx, mats, fiber=part == "fiber")
        ctx.marker("AimPoint", (0.0, -0.006, h))
    elif part == "shells":
        r.build_shells(ctx, mats)
    elif part == "short":
        r.build_barrels(ctx, mats, r.SHORT_END_Y, muzzle=True)
    elif part == "sawn":
        r.build_stock(ctx, mats, sawn=True)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
