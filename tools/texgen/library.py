"""The material library table: which lib ids exist and how they are sized.

UV / texel convention (see README.md): a library texture covers ``tile_m`` x ``tile_m`` metres
(default ``TILE_M`` = 2.0 m), so **1 UV unit = tile_m metres**. Environment materials all use 2.0 m:
1024 px -> 512 px/m (within reach), 512 px -> 256 px/m (ceilings, featureless/distant).
First-person weapon materials (D-026) use ``tile_m = 1.0``: 1024 px -> 1024 px/m, matching
``tools/blender/lib/uv.box_project(density=1024)`` (uv = metres * density / 1024 = metres).
The tile size is also stored on each material as ``metadata/uv_tile_m``.
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
    # First-person weapon materials (D-026): 1 UV unit = 1 m, 1024 px/m.
    "polymer_black": {"size": 1024, "tile_m": 1.0},
    "polymer_stipple": {"size": 1024, "tile_m": 1.0},
    "steel_blued": {"size": 1024, "tile_m": 1.0},
    "steel_bare": {"size": 1024, "tile_m": 1.0},
    "metal_matte": {"size": 1024, "tile_m": 1.0},
    "paint_white": {"size": 1024, "tile_m": 1.0},
    "brass_cartridge": {"size": 1024, "tile_m": 1.0},
    "glass_lens_tint": {"size": 512, "tile_m": 1.0, "kind": "glass"},
    # No textures: a flat emissive StandardMaterial3D (a reticle is a tiny emissive mesh/decal).
    "emissive_reticle_red": {"kind": "emissive"},
    # Trim sheet (trim.py). Strip UV ranges: game/assets/textures/trim_interior/trim_table.json
    "trim_interior": {"size": 1024, "trim": True},
}


def tile_m(lib_id: str) -> float:
    return float(LIBRARY[lib_id].get("tile_m", TILE_M))


def texel_density(lib_id: str) -> float:
    entry = LIBRARY[lib_id]
    return entry["size"] / tile_m(lib_id) if "size" in entry else 0.0
