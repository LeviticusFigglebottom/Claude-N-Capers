"""Kestrel P9 mod parts (B1-03). Each pivot = its attach point, so the glb snaps onto the marker
named for its ModType (contracts/data_schemas.md §Weapons):

* ``mod_p9_suppressor``   SUPPRESSOR -> ``Muzzle``    (adds its own ``Muzzle`` marker at the front cap)
* ``mod_p9_reflex_sight`` SIGHT      -> ``SightRail`` (adds ``AimPoint`` at the reticle dot)
* ``mod_p9_iron_sights``  SIGHT      -> ``SightRail`` (stock rear sight; ``AimPoint`` in the notch)
* ``mod_p9_standard_mag`` MAGAZINE   -> ``Magwell``   (stock 17-round magazine)
* ``mod_p9_extended_mag`` MAGAZINE   -> ``Magwell``   (25 rounds, grip-matching sleeve)
* ``mod_p9_rubber_grip`` GRIP -> ``GripMount`` (slip-on rubber grip sleeve; hides ``StockGrip``; D-118)

The stock parts are identical to the ``StockSight`` / ``StockMagazine`` nodes in ``wpn_kestrel_p9``
(same helper code in _p9.py); their own glbs serve workshop previews and reload animations.
"""

import _common as c
import _p9 as p9

TRI_BUDGET = 25000
VARIANTS = {
    "mod_p9_suppressor": {"part": "suppressor"},
    "mod_p9_reflex_sight": {"part": "reflex"},
    "mod_p9_iron_sights": {"part": "iron"},
    "mod_p9_standard_mag": {"part": "mag"},
    "mod_p9_extended_mag": {"part": "mag_ext"},
    "mod_p9_rubber_grip": {"part": "grip_rubber"},
}


def build(ctx) -> None:
    mats = p9.Mats(ctx)
    part = ctx.param("part")
    if part == "suppressor":
        p9.build_suppressor(ctx, mats, name="Suppressor")
    elif part == "reflex":
        p9.build_reflex(ctx, mats, name="ReflexSight")
    elif part == "iron":
        p9.build_rear_sight(ctx, mats, name="RearSight")
        ctx.marker("AimPoint", (0.0, 0.0, p9.SIGHT_LINE_DZ))
    elif part == "mag":
        p9.build_magazine(ctx, mats, extended=False, name="Magazine")
    elif part == "mag_ext":
        p9.build_magazine(ctx, mats, extended=True, name="Magazine")
    elif part == "grip_rubber":
        c.build_grip_sleeve(ctx, mats, p9.GRIP_HALF_DEPTH, p9.GRIP_TAN, 0.006, -0.060, p9.GRIP_HALF_WIDTH, grow=0.0028)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = p9.tris_of_scene()
