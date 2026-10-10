"""Brannock Falchion DMR mod parts (B4-12). Each pivot = its attach point (see _common.py):

* ``mod_falchion_iron_sights``    SIGHT      -> ``SightRail``   (stock flip-up irons, ``AimPoint``)
* ``mod_falchion_standard_mag``   MAGAZINE   -> ``Magwell``     (stock 20-round magazine)
* ``mod_falchion_extended_mag``   MAGAZINE   -> ``Magwell``     (25 rounds)
* ``mod_falchion_suppressor``     SUPPRESSOR -> ``Muzzle``      (7.62 can over the brake; own ``Muzzle``)
* ``mod_falchion_bipod``          FOREGRIP   -> ``Underbarrel`` (folded bipod)

Rail optics are the shared ``rail_optics_mods.py``.
"""

import _common as c
import _falchion as f

TRI_BUDGET = 25000
VARIANTS = {
    "mod_falchion_iron_sights": {"part": "iron"},
    "mod_falchion_standard_mag": {"part": "mag"},
    "mod_falchion_extended_mag": {"part": "mag_ext"},
    "mod_falchion_suppressor": {"part": "suppressor"},
    "mod_falchion_bipod": {"part": "bipod"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = f.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, f.REAR_IRON_Y, aim))
    elif part == "mag":
        f.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        f.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        f.build_suppressor(ctx, mats)
    elif part == "bipod":
        c.build_bipod(ctx, mats, leg_len=0.175)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
