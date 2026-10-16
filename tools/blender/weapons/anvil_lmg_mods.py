"""Tillman Ironworks Anvil mod parts (B4-12). Each pivot = its attach point (see _common.py):

* ``mod_anvil_iron_sights``   SIGHT    -> ``SightRail``   (stock tangent rear leaf, ``AimPoint``; the front
  post rides on the barrel)
* ``mod_anvil_box_100``       MAGAZINE -> ``Magwell``     (stock 100-round box + belt)
* ``mod_anvil_box_150``       MAGAZINE -> ``Magwell``     (150-round box)
* ``mod_anvil_short_barrel``  BARREL   -> ``BarrelMount`` (short quick-change barrel; own ``Muzzle``)
* ``mod_anvil_bipod``         FOREGRIP -> ``Underbarrel`` (folded bipod on the gas-cylinder rail)
* ``mod_anvil_collapsed_stock`` STOCK -> ``StockMount`` (light telescoping stock pushed in; hides ``StockStock``; D-118)
* ``mod_anvil_heavy_stock`` STOCK -> ``StockMount`` (heavy stock, cheek riser + recoil pad; hides ``StockStock``; D-118)

Optics are the shared rail optics (``rail_optics_mods.py``).
"""

import _common as c
import _anvil as a

TRI_BUDGET = 25000
VARIANTS = {
    "mod_anvil_iron_sights": {"part": "iron"},
    "mod_anvil_box_100": {"part": "box"},
    "mod_anvil_box_150": {"part": "box_big"},
    "mod_anvil_short_barrel": {"part": "barrel_short"},
    "mod_anvil_bipod": {"part": "bipod"},
    "mod_anvil_collapsed_stock": {"part": "stock_light"},
    "mod_anvil_heavy_stock": {"part": "stock_heavy"},
}


def build(ctx) -> None:
    mats = c.Mats(ctx)
    part = ctx.param("part")
    if part == "iron":
        a.build_rear_leaf(ctx, mats)
        ctx.marker("AimPoint", (0.0, a.REAR_IRON_Y, a.IRON_AIM_DZ))
    elif part == "box":
        a.build_box(ctx, mats, big=False)
    elif part == "box_big":
        a.build_box(ctx, mats, big=True)
    elif part == "barrel_short":
        a.build_barrel(ctx, mats, short=True)   # its MuzzleBrake carries the own Muzzle
    elif part == "bipod":
        c.build_bipod(ctx, mats, leg_len=0.180)
    elif part == "stock_light":
        c.build_collapsed_stock(ctx, mats, 0.160, 0.038, -0.122, 0.0190)
    elif part == "stock_heavy":
        c.build_precision_stock(ctx, mats, 0.290, 0.038, -0.122, 0.0195, front_z=-0.048)
    else:
        raise ValueError(f"unknown part {part!r}")
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
