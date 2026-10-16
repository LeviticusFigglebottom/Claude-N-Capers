"""Graff-Lindqvist Gale MG mod parts (B4-18). Each pivot = its attach point (see _common.py):

* ``mod_gale_iron_sights`` SIGHT    -> ``SightRail``   (stock rear leaf on the feed cover, ``AimPoint``)
* ``mod_gale_box_100``     MAGAZINE -> ``Magwell``     (stock 100-round belt box)
* ``mod_gale_box_200``     MAGAZINE -> ``Magwell``     (200-round belt box)
* ``mod_gale_bipod``       FOREGRIP -> ``Underbarrel`` (folding bipod under the jacket)
* ``mod_gale_barrage_brake`` BARREL_EXT -> ``Muzzle``    (heavy brake over the stock brake; own ``Muzzle`` + ``MuzzlePortL``/``R``)
* ``mod_gale_collapsed_stock`` STOCK -> ``StockMount`` (light telescoping stock pushed in; hides ``StockStock``; D-118)
* ``mod_gale_heavy_stock`` STOCK -> ``StockMount`` (heavy stock, cheek riser + recoil pad; hides ``StockStock``; D-118)

Optics are the shared ``mod_rail_reflex_sight`` / ``mod_rail_prism_scope`` on the feed-cover rail.
"""

import _common as c
import _gale as g

TRI_BUDGET = 25000
VARIANTS = {
    "mod_gale_iron_sights": {"part": "iron"},
    "mod_gale_box_100": {"part": "box"},
    "mod_gale_box_200": {"part": "box_big"},
    "mod_gale_bipod": {"part": "bipod"},
    "mod_gale_barrage_brake": {"part": "brake"},
    "mod_gale_collapsed_stock": {"part": "stock_light"},
    "mod_gale_heavy_stock": {"part": "stock_heavy"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        g.build_rear_leaf(ctx, mats)
        ctx.marker("AimPoint", (0.0, g.REAR_IRON_Y, g.IRON_AIM_DZ))
    elif part == "box":
        g.build_box(ctx, mats, big=False)
    elif part == "box_big":
        g.build_box(ctx, mats, big=True)
    elif part == "bipod":
        c.build_bipod(ctx, mats, leg_len=0.170)
    elif part == "brake":
        g.build_barrage_brake(ctx, mats)
    elif part == "stock_light":
        c.build_collapsed_stock(ctx, mats, 0.150, 0.038, -0.108, 0.0190)
    elif part == "stock_heavy":
        c.build_precision_stock(ctx, mats, 0.280, 0.038, -0.108, 0.0195, front_z=-0.036)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
