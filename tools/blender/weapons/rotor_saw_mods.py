"""Graff-Lindqvist Rotor Saw mod parts (B4-18). Each pivot = its attach point (see _common.py / _rotor.py):

* ``mod_saw_guide_notch``     SIGHT    -> ``SightRail``   (stock V-notch + guide line, ``AimPoint``)
* ``mod_saw_standard_blade``  MAGAZINE -> ``Magwell``     (stock abrasive blade; Magwell rides on ``Blade``)
* ``mod_saw_carbide_blade``   MAGAZINE -> ``Magwell``     (toothed carbide blade)
* ``mod_saw_durable_blade``   MAGAZINE -> ``Magwell``     (thick abrasive disc)
* ``mod_saw_front_handle``    FOREGRIP -> ``Underbarrel`` (wider loop handle; hides ``StockForegrip``)

PD2's portable saw only takes blades and handling parts: no optics, barrels or muzzle devices.
"""

import _common as c
import _rotor as r

TRI_BUDGET = 25000
VARIANTS = {
    "mod_saw_guide_notch": {"part": "notch"},
    "mod_saw_standard_blade": {"part": "standard"},
    "mod_saw_carbide_blade": {"part": "carbide"},
    "mod_saw_durable_blade": {"part": "durable"},
    "mod_saw_front_handle": {"part": "handle"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "notch":
        _n, aim = r.build_notch(ctx, mats)
        ctx.marker("AimPoint", (0.0, 0.0, aim))
    elif part in ("standard", "carbide", "durable"):
        r.build_blade(ctx, mats, part, name=part.capitalize() + "Blade")
    elif part == "handle":
        r.build_front_handle(ctx, mats, wide=True, name="WideFrontHandle")
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
