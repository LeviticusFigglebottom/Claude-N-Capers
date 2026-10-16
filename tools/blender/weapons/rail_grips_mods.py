"""Picatinny foregrip shared by the under-railed weapons without their own grip (D-115): Drover 762,
Lark Carbine, Ferret 9, Hornet 9, Hush 9, Wasp PDW. Origin = underside rail surface (``Underbarrel``),
hanging along -Z (see _common.py).

* ``mod_rail_vertical_grip``  FOREGRIP -> ``Underbarrel`` (short vertical foregrip)

Like every vertical grip it carries a ``LeftHandIK`` at the palm contact (c.build_vertical_grip, lead vgrip plan):
with the grip equipped the support hand holds the grip instead of the base model's fore-end marker.
"""

import _common as c

TRI_BUDGET = 25000
VARIANTS = {
    "mod_rail_vertical_grip": {"part": "grip"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "grip":
        # short enough to read on the SMGs without hanging past their magazines
        c.build_vertical_grip(ctx, mats, length=0.070)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
