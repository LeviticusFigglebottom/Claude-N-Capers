"""Marrow & Kell Marshal .357 mod parts (B4-12). Each pivot = its attach point (see _common.py):

* ``mod_marshal_iron_sights``   SIGHT    -> ``SightRail``   (stock top-strap rear sight, ``AimPoint``)
* ``mod_marshal_reflex_sight``  SIGHT    -> ``SightRail``   (small reflex on a top-strap plate; the P9 optic)
* ``mod_marshal_cylinder``      MAGAZINE -> ``Magwell``     (stock six cartridges in the cylinder)
* ``mod_marshal_long_barrel``   BARREL   -> ``BarrelMount`` (6 in barrel; own ``Muzzle``)
* ``mod_marshal_snub_barrel``   BARREL   -> ``BarrelMount`` (2.5 in barrel; own ``Muzzle``)
* ``mod_marshal_rubber_grip``   GRIP     -> ``GripMount``   (finger-groove rubber grip; hides ``StockGrip``)
"""

import _common as c
import _marshal as m
import _p9 as p9

TRI_BUDGET = 25000
VARIANTS = {
    "mod_marshal_iron_sights": {"part": "iron"},
    "mod_marshal_reflex_sight": {"part": "reflex"},
    "mod_marshal_cylinder": {"part": "rounds"},
    "mod_marshal_long_barrel": {"part": "barrel_long"},
    "mod_marshal_snub_barrel": {"part": "barrel_snub"},
    "mod_marshal_rubber_grip": {"part": "grip_rubber"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        m.build_rear_sight(ctx, mats)
        ctx.marker("AimPoint", (0.0, 0.0, m.SIGHT_DZ))
    elif part == "reflex":
        p9.build_reflex(ctx, mats, name="ReflexSight")
    elif part == "rounds":
        m.build_cartridges(ctx, mats)
    elif part == "barrel_long":
        m.build_barrel(ctx, mats, "long")
    elif part == "barrel_snub":
        m.build_barrel(ctx, mats, "snub")
    elif part == "grip_rubber":
        m.build_grip(ctx, mats, rubber=True)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
