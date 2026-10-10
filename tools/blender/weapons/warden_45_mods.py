"""Marrow & Kell Warden .45 mod parts (B4-04). Each pivot = its attach point (see _common.py):

* ``mod_w45_iron_sights``   SIGHT      -> ``SightRail`` (stock rear sight, ``AimPoint`` in the notch)
* ``mod_w45_reflex_sight``  SIGHT      -> ``SightRail`` (slide-cut reflex, same optic as the P9's)
* ``mod_w45_standard_mag``  MAGAZINE   -> ``Magwell``   (stock flush 8-round magazine)
* ``mod_w45_extended_mag``  MAGAZINE   -> ``Magwell``   (12 rounds with a rubber sleeve)
* ``mod_w45_suppressor``    SUPPRESSOR -> ``Muzzle``    (.45 can; own ``Muzzle``)
* ``mod_w45_compensator``   BARREL_EXT -> ``Muzzle``    (slide-profile comp; own ``Muzzle``;
  data declares it conflicts with the suppressor)
"""

import _common as c
import _p9 as p9
import _warden as w

TRI_BUDGET = 25000
VARIANTS = {
    "mod_w45_iron_sights": {"part": "iron"},
    "mod_w45_reflex_sight": {"part": "reflex"},
    "mod_w45_standard_mag": {"part": "mag"},
    "mod_w45_extended_mag": {"part": "mag_ext"},
    "mod_w45_suppressor": {"part": "suppressor"},
    "mod_w45_compensator": {"part": "comp"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        w.build_rear_sight(ctx, mats)
        ctx.marker("AimPoint", (0.0, 0.0, w.SIGHT_DZ))
    elif part == "reflex":
        p9.build_reflex(ctx, mats, name="ReflexSight")
    elif part == "mag":
        w.build_mag(ctx, mats, extended=False)
    elif part == "mag_ext":
        w.build_mag(ctx, mats, extended=True)
    elif part == "suppressor":
        c.build_can(ctx, mats, length=0.160, r=0.0165, overlap=0.0)
    elif part == "comp":
        w.build_compensator(ctx, mats)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
