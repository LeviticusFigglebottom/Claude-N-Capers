"""Tillman Bastion BR mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_bastion_iron_sights``   SIGHT      -> ``SightRail``   (stock flip-up irons, ``AimPoint``)
* ``mod_bastion_standard_mag``  MAGAZINE   -> ``Magwell``     (stock straight 20-round magazine)
* ``mod_bastion_extended_mag``  MAGAZINE   -> ``Magwell``     (30 rounds)
* ``mod_bastion_suppressor``    SUPPRESSOR -> ``Muzzle``      (rifle can over the hider; own ``Muzzle``)
* ``mod_bastion_bipod``        FOREGRIP   -> ``Underbarrel`` (folding bipod on the handguard rail)

Optics are the shared ``mod_rail_reflex_sight`` / ``mod_rail_prism_scope``.
"""

import _common as c
import _bastion as t

TRI_BUDGET = 25000
VARIANTS = {
    "mod_bastion_iron_sights": {"part": "iron"},
    "mod_bastion_standard_mag": {"part": "mag"},
    "mod_bastion_extended_mag": {"part": "mag_ext"},
    "mod_bastion_suppressor": {"part": "suppressor"},
    "mod_bastion_bipod": {"part": "bipod"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = t.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, t.REAR_IRON_Y, aim))
    elif part == "mag":
        t.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        t.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        t.build_suppressor(ctx, mats)
    elif part == "bipod":
        c.build_bipod(ctx, mats, leg_len=0.150)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
