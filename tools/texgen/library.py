"""The material library table: which lib ids exist and how they are sized.

UV / texel convention (see README.md): every library texture covers ``TILE_M`` x ``TILE_M``
metres of surface, so **1 UV unit = 2.0 m** for every material. ``size`` (pixels) therefore sets
the effective texel density: 1024 px -> 512 px/m (within reach), 512 px -> 256 px/m (ceilings,
featureless or distant materials).
"""

from __future__ import annotations

TILE_M = 2.0
TEX_ROOT = "game/assets/textures"
MAT_ROOT = "game/world/materials"

# kind: "opaque" (ORMMaterial3D) or "glass" (ORMMaterial3D with alpha transparency).
LIBRARY: dict[str, dict] = {
    "plaster_painted": {"size": 1024},
    "drywall_painted": {"size": 1024},
    "concrete": {"size": 1024},
    "terrazzo": {"size": 1024},
    "marble_cream": {"size": 1024},
    "carpet_commercial": {"size": 1024},
    "ceiling_tile": {"size": 512},
    "wood_veneer_walnut": {"size": 1024},
    "brushed_steel": {"size": 1024},
    "chrome": {"size": 512},
    "brass": {"size": 1024},
    "glass_clear": {"size": 512, "kind": "glass"},
    "rubber_black": {"size": 512},
    "fabric_upholstery": {"size": 1024},
    "leather_dark": {"size": 1024},
    "plastic_matte": {"size": 512},
    "brick_red": {"size": 1024},
    "asphalt": {"size": 1024},
    "tile_ceramic_white": {"size": 1024},
    "vinyl_floor": {"size": 1024},
    "metal_painted": {"size": 1024},
    # Trim sheet (trim.py). Strip UV ranges: game/assets/textures/trim_interior/trim_table.json
    "trim_interior": {"size": 1024, "trim": True},
}


def texel_density(lib_id: str) -> float:
    return LIBRARY[lib_id]["size"] / TILE_M
