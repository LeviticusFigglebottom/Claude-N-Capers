"""Graff-Lindqvist Rampart mod parts (B4-04). Each pivot = its attach point (see _common.py):

* ``mod_rampart_iron_sights``  SIGHT    -> ``SightRail``   (stock rear leaf, ``AimPoint``)
* ``mod_rampart_box_100``      MAGAZINE -> ``Magwell``     (stock 100-round belt box)
* ``mod_rampart_box_200``      MAGAZINE -> ``Magwell``     (200-round box)
* ``mod_rampart_short_barrel`` BARREL   -> ``BarrelMount`` (assault barrel; hides ``StockBarrel``,
  carries its own ``Muzzle``)
* ``mod_rampart_bipod``        FOREGRIP -> ``Underbarrel`` (folded bipod)
"""

import _common as c
import _rampart as r

TRI_BUDGET = 25000
VARIANTS = {
    "mod_rampart_iron_sights": {"part": "iron"},
    "mod_rampart_box_100": {"part": "box"},
    "mod_rampart_box_200": {"part": "box_big"},
    "mod_rampart_short_barrel": {"part": "short_barrel"},
    "mod_rampart_bipod": {"part": "bipod"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        r.build_rear_leaf(ctx, mats)
        ctx.marker("AimPoint", (0.0, r.REAR_IRON_Y, r.IRON_AIM_DZ))
    elif part == "box":
        r.build_box(ctx, mats, big=False)
    elif part == "box_big":
        r.build_box(ctx, mats, big=True)
    elif part == "short_barrel":
        body = r.build_barrel(ctx, mats, short=True)
        ctx.marker("Muzzle", (0.0, r.SHORT_END_Y - r.REC_FRONT_Y + r.HIDER_LEN + 0.001, 0.0), parent=body)
    elif part == "bipod":
        c.build_bipod(ctx, mats, leg_len=0.130)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
