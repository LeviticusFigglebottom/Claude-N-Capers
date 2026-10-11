"""Brannock Thorn compound bow mod parts (B4-18). Each pivot = its attach point (see _common.py / _thorn.py):

* ``mod_thorn_pin_sight``        SIGHT    -> ``SightRail``   (stock single-pin sight, ``AimPoint`` on the pin)
* ``mod_thorn_five_pin_sight``   SIGHT    -> ``SightRail``   (five pins + bubble level, ``AimPoint`` on the top pin)
* ``mod_thorn_arrow``            MAGAZINE -> ``Magwell``     (stock carbon arrow, nock at the origin, along +Z)
* ``mod_thorn_broadhead_arrow``  MAGAZINE -> ``Magwell``     (arrow with a three-blade broadhead)
* ``mod_thorn_stabilizer``       FOREGRIP -> ``Underbarrel`` (weighted rod off the riser front)

A bow has no barrel, suppressor or stock: PD2's bows take only sights, stabiliser-like parts and arrows.
"""

import _common as c
import _thorn as t

TRI_BUDGET = 25000
VARIANTS = {
    "mod_thorn_pin_sight": {"part": "pin1"},
    "mod_thorn_five_pin_sight": {"part": "pin5"},
    "mod_thorn_arrow": {"part": "arrow"},
    "mod_thorn_broadhead_arrow": {"part": "broadhead"},
    "mod_thorn_stabilizer": {"part": "stabilizer"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part in ("pin1", "pin5"):
        aim = t.build_pin_sight(ctx, mats, five=part == "pin5")
        ctx.marker("AimPoint", aim)
    elif part == "arrow":
        t.build_arrow(ctx, mats, broadhead=False)
    elif part == "broadhead":
        t.build_arrow(ctx, mats, broadhead=True, name="BroadheadArrow")
    elif part == "stabilizer":
        t.build_stabilizer(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
