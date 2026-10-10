"""Marrow & Kell Heron .308 mod parts (B4-04). Each pivot = its attach point (see _common.py):

* ``mod_heron_scope_4x``       SIGHT      -> ``SightRail``   (stock fixed 4x scope, ``AimPoint``)
* ``mod_heron_scope_10x``      SIGHT      -> ``SightRail``   (30 mm 10x scope with parallax turret)
* ``mod_heron_standard_mag``   MAGAZINE   -> ``Magwell``     (stock five-round magazine)
* ``mod_heron_extended_mag``   MAGAZINE   -> ``Magwell``     (ten rounds)
* ``mod_heron_suppressor``     SUPPRESSOR -> ``Muzzle``      (slips over the brake; own ``Muzzle``)
* ``mod_heron_bipod``          FOREGRIP   -> ``Underbarrel`` (folded bipod)
"""

import _common as c
import _heron as k

TRI_BUDGET = 25000
VARIANTS = {
    "mod_heron_scope_4x": {"part": "scope4"},
    "mod_heron_scope_10x": {"part": "scope10"},
    "mod_heron_standard_mag": {"part": "mag"},
    "mod_heron_extended_mag": {"part": "mag_ext"},
    "mod_heron_suppressor": {"part": "suppressor"},
    "mod_heron_bipod": {"part": "bipod"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "scope4":
        k.build_scope(ctx, mats, ten=False)
    elif part == "scope10":
        k.build_scope(ctx, mats, ten=True)
    elif part == "mag":
        k.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        k.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        k.build_brake_suppressor(ctx, mats)
    elif part == "bipod":
        c.build_bipod(ctx, mats, leg_len=0.170)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
