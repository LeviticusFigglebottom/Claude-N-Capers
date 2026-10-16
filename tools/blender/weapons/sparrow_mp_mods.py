"""Halvard Arms Sparrow MP mod parts (B4-12). Each pivot = its attach point (see _common.py):

* ``mod_sparrow_iron_sights``   SIGHT      -> ``SightRail``  (stock rear sight, ``AimPoint`` in the notch)
* ``mod_sparrow_reflex_sight``  SIGHT      -> ``SightRail``  (slide-cut reflex, the P9's optic)
* ``mod_sparrow_standard_mag``  MAGAZINE   -> ``Magwell``    (stock 20-round magazine)
* ``mod_sparrow_extended_mag``  MAGAZINE   -> ``Magwell``    (32 rounds)
* ``mod_sparrow_suppressor``    SUPPRESSOR -> ``Muzzle``     (slim 9 mm can; own ``Muzzle``)
* ``mod_sparrow_wire_stock``    STOCK      -> ``StockMount`` (clip-on wire stock, deployed)
* ``mod_sparrow_rubber_grip`` GRIP -> ``GripMount`` (slip-on rubber grip sleeve; hides ``StockGrip``; D-118)
* ``mod_sparrow_slim_grip`` GRIP -> ``GripMount`` (flush smooth polymer panels, no stippling; hides ``StockGrip``; D-118)
"""

import _common as c
import _p9 as p9
import _sparrow as s

TRI_BUDGET = 25000
VARIANTS = {
    "mod_sparrow_iron_sights": {"part": "iron"},
    "mod_sparrow_reflex_sight": {"part": "reflex"},
    "mod_sparrow_standard_mag": {"part": "mag"},
    "mod_sparrow_extended_mag": {"part": "mag_ext"},
    "mod_sparrow_suppressor": {"part": "suppressor"},
    "mod_sparrow_wire_stock": {"part": "stock"},
    "mod_sparrow_rubber_grip": {"part": "grip_rubber"},
    "mod_sparrow_slim_grip": {"part": "grip_slim"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        s.build_rear_sight(ctx, mats)
        ctx.marker("AimPoint", (0.0, 0.0, s.SIGHT_DZ))
    elif part == "reflex":
        p9.build_reflex(ctx, mats, name="ReflexSight")
    elif part == "mag":
        s.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        s.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        s.build_suppressor(ctx, mats)
    elif part == "stock":
        s.build_stock(ctx, mats)
    elif part == "grip_rubber":
        c.build_grip_sleeve(ctx, mats, s.GRIP_HALF_DEPTH, s.GRIP_TAN, 0.012, -0.066, s.GRIP_HALF_WIDTH)
    elif part == "grip_slim":
        c.build_slim_panels(ctx, mats, s.GRIP_HALF_DEPTH, s.GRIP_TAN, 0.010, -0.064, s.GRIP_HALF_WIDTH,
                            t=0.0006, inset=0.0055, mat_name="polymer")
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
