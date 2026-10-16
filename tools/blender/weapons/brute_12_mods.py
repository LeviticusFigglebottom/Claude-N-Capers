"""Tillman Brute 12 mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_brute_iron_sights`` SIGHT    -> ``SightRail`` (stock carry-handle aperture + front post, ``AimPoint``)
* ``mod_brute_drum_20``     MAGAZINE -> ``Magwell``   (stock 20-shell drum)
* ``mod_brute_box_8``       MAGAZINE -> ``Magwell``   (eight-shell box)
* ``mod_brute_drum_32``     MAGAZINE -> ``Magwell``   (32-shell drum)
* ``mod_brute_full_choke``  BARREL_EXT -> ``Muzzle``  (full choke in the compensator face; own ``Muzzle``)
* ``mod_brute_folding_stock`` STOCK -> ``StockMount`` (light folding-style stock from the receiver rear; hides
  ``StockStock``; D-118). ``StockMount`` sits on the base butt plate, so both stocks are shifted forward to start
  at the receiver rear.
* ``mod_brute_padded_stock`` STOCK -> ``StockMount`` (heavy padded stock from the receiver rear; hides ``StockStock``; D-118)

The reflex optic is the shared ``mod_rail_reflex_sight`` on the carry-handle rail.
"""

import _common as c
import _brute as u

TRI_BUDGET = 25000
VARIANTS = {
    "mod_brute_iron_sights": {"part": "iron"},
    "mod_brute_drum_20": {"part": "drum"},
    "mod_brute_box_8": {"part": "box"},
    "mod_brute_drum_32": {"part": "drum_big"},
    "mod_brute_full_choke": {"part": "choke"},
    "mod_brute_folding_stock": {"part": "stock_light"},
    "mod_brute_padded_stock": {"part": "stock_heavy"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        _body, aim = u.build_irons(ctx, mats)
        ctx.marker("AimPoint", (0.0, u.REAR_IRON_Y, aim))
    elif part == "drum":
        u.build_drum(ctx, mats, big=False)
    elif part == "drum_big":
        u.build_drum(ctx, mats, big=True)
    elif part == "box":
        u.build_box(ctx, mats)
    elif part == "choke":
        u.build_choke(ctx, mats)
    elif part == "stock_light":
        st = c.build_collapsed_stock(ctx, mats, 0.150, 0.036, -0.092, u.REC_HW - 0.004)
        st.location = (0.0, u.REC_REAR_Y - u.STOCK_MOUNT[1], 0.0)
    elif part == "stock_heavy":
        st = c.build_precision_stock(ctx, mats, 0.226, 0.036, -0.092, u.REC_HW - 0.003,
                                     front_z=u.REC_BOTTOM_Z + 0.004 - u.STOCK_MOUNT[2])
        st.location = (0.0, u.REC_REAR_Y - u.STOCK_MOUNT[1], 0.0)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
