"""Material table for the props library (C1-07). Pure Python (no bpy): read by the Blender prop
scripts (slot colours) and by ``_make_materials.py`` (Godot materials + detail textures).

Two kinds of ids:

* **Library** ids (``game/world/materials/<id>.tres``, tools/texgen): used as-is. ``glb_post_import``
  maps ``M_<id>`` onto them.
* **Prop** ids (``game/world/props/materials/<id>.tres``): tinted variants of library surfaces (the
  library's ORM + normal maps, plus a neutral luminance "detail" albedo derived from the library
  albedo, multiplied by ``color``) and untextured emissives. ``_make_materials.py`` writes them and
  points each prop ``.glb.import`` at them (``_subresources`` -> ``use_external``).

Colours are sRGB hex. Albedo rules (style guide §3) are respected by the tints: no pure black/white,
saturation <= 0.75 except emissives/signage, and nothing near the interactable accent ``#4FD1E8``.
"""

from __future__ import annotations

# Library materials: key -> (library id, placeholder colour, roughness, metallic, alpha).
LIBRARY: dict[str, tuple[str, str, float, float, float]] = {
    "walnut": ("wood_veneer_walnut", "#5A3B28", 0.45, 0.0, 1.0),
    "brass": ("brass", "#C9A227", 0.3, 1.0, 1.0),
    "glass": ("glass_clear", "#8FA0A0", 0.05, 0.0, 0.25),
    "chrome": ("chrome", "#B8BCC0", 0.1, 1.0, 1.0),
    "steel": ("brushed_steel", "#8E9296", 0.35, 1.0, 1.0),
    "marble": ("marble_cream", "#D9D2C2", 0.25, 0.0, 1.0),
    "leather": ("leather_dark", "#4A3226", 0.55, 0.0, 1.0),
    "fabric": ("fabric_upholstery", "#4C5666", 0.85, 0.0, 1.0),
    "plastic": ("plastic_matte", "#7A7C7E", 0.6, 0.0, 1.0),
    "rubber": ("rubber_black", "#2A2A2A", 0.85, 0.0, 1.0),
    "metal_blue": ("metal_painted", "#5A6670", 0.5, 0.0, 1.0),
    "concrete": ("concrete", "#9A968E", 0.85, 0.0, 1.0),
    "carpet": ("carpet_commercial", "#5A5A58", 0.95, 0.0, 1.0),
    "plaster": ("plaster_painted", "#E8DCC8", 0.85, 0.0, 1.0),
    "drywall": ("drywall_painted", "#D8D6CE", 0.85, 0.0, 1.0),
    "terrazzo": ("terrazzo", "#CFC8BC", 0.4, 0.0, 1.0),
    "tile": ("tile_ceramic_white", "#E4E2DC", 0.3, 0.0, 1.0),
    "asphalt": ("asphalt", "#4A4A48", 0.9, 0.0, 1.0),
    "brick": ("brick_red", "#8A4A3A", 0.85, 0.0, 1.0),
    # weapon/gear library ids (tools/texgen, 1 m tiles: TILE_1M), used by the equipment props (D-111)
    "polymer": ("polymer_black", "#2A2B2D", 0.7, 0.0, 1.0),
    "polymer_olive": ("polymer_olive", "#4E5338", 0.7, 0.0, 1.0),
    "steel_bare": ("steel_bare", "#8A8D90", 0.4, 1.0, 1.0),
    "brass_case": ("brass_cartridge", "#B8913A", 0.3, 1.0, 1.0),
    "alu_black": ("alu_anodized_black", "#2C2D30", 0.4, 1.0, 1.0),
    "safety_orange": ("paint_safety_orange", "#D2611E", 0.6, 0.0, 1.0),
}

# Detail sources: neutral luminance textures derived from these library albedos.
DETAIL_SOURCES: tuple[str, ...] = (
    "fabric_upholstery", "leather_dark", "drywall_painted", "metal_painted", "plastic_matte",
    "wood_veneer_walnut", "plaster_painted", "carpet_commercial", "marble_cream", "asphalt", "concrete",
)

# Prop materials: key -> dict(id, source (library id for detail/ORM/normal), color, roughness
# multiplier, metallic multiplier, normal_scale). ``roughness``/``metallic`` scale the library ORM.
TINTED: dict[str, dict] = {
    "felt_rose": {"source": "fabric_upholstery", "color": "#A8695A", "roughness": 1.0},
    "suede": {"source": "leather_dark", "color": "#8C6D56", "roughness": 1.1},
    "fabric_ivory": {"source": "fabric_upholstery", "color": "#CBBDA6", "roughness": 1.0},
    "fabric_charcoal": {"source": "fabric_upholstery", "color": "#46494D", "roughness": 1.0},
    "fabric_sage": {"source": "fabric_upholstery", "color": "#7D8A72", "roughness": 1.0},
    "leather_cognac": {"source": "leather_dark", "color": "#7C4C31", "roughness": 0.9},
    "paint_ivory": {"source": "drywall_painted", "color": "#D4C7AF", "roughness": 0.7},
    "paint_greige": {"source": "drywall_painted", "color": "#9D978C", "roughness": 0.75},
    "paint_sage": {"source": "drywall_painted", "color": "#8A9483", "roughness": 0.75},
    "metal_grey": {"source": "drywall_painted", "color": "#A4A8A8", "roughness": 0.9},
    "metal_dark": {"source": "metal_painted", "color": "#3B3E41", "roughness": 0.9},
    # metal_dark without the chipped-paint pattern (its bare-metal chips read as black keyhole-like
    # blots on large flat office panels); powder-coated steel furniture uses this
    "powder_charcoal": {"source": "drywall_painted", "color": "#3B3E41", "roughness": 0.9},
    "metal_green": {"source": "drywall_painted", "color": "#3D5645", "roughness": 1.0},
    "metal_red": {"source": "drywall_painted", "color": "#9B2E28", "roughness": 0.8},
    "metal_yellow": {"source": "drywall_painted", "color": "#C99E38", "roughness": 0.9},
    "metal_white": {"source": "plastic_matte", "color": "#D2D0CA", "roughness": 0.8},
    "metal_green_worn": {"source": "metal_painted", "color": "#3D5645", "roughness": 1.0},
    "metal_orange": {"source": "metal_painted", "color": "#C86A34", "roughness": 0.9},
    "car_wine": {"source": "plastic_matte", "color": "#5D232A", "roughness": 0.45},
    "car_navy": {"source": "plastic_matte", "color": "#26334A", "roughness": 0.45},
    "car_silver": {"source": "plastic_matte", "color": "#8F9395", "roughness": 0.45, "metallic": 1.0},
    "ceramic": {"source": "plastic_matte", "color": "#E3E1DB", "roughness": 0.35},
    "plastic_black": {"source": "plastic_matte", "color": "#2C2D2F", "roughness": 0.9},
    "plastic_white": {"source": "plastic_matte", "color": "#D6D4CE", "roughness": 0.8},
    "plastic_grey": {"source": "plastic_matte", "color": "#6E7174", "roughness": 0.85},
    "cardboard": {"source": "plaster_painted", "color": "#A57F57", "roughness": 1.1},
    "paper": {"source": "plaster_painted", "color": "#E2DED4", "roughness": 1.1},
    "wood_oak": {"source": "wood_veneer_walnut", "color": "#A27C55", "roughness": 1.0},
    "wood_pine": {"source": "wood_veneer_walnut", "color": "#B8946A", "roughness": 1.2},
    "wood_dark": {"source": "wood_veneer_walnut", "color": "#3E2A1F", "roughness": 0.9},
    "leaf": {"source": "leather_dark", "color": "#3F5C35", "roughness": 0.8},
    "soil": {"source": "asphalt", "color": "#3A2F28", "roughness": 1.0},
    "rug_burgundy": {"source": "carpet_commercial", "color": "#6C3337", "roughness": 1.0},
    "rug_ivory": {"source": "carpet_commercial", "color": "#C9BCA5", "roughness": 1.0},
    "stone_dark": {"source": "marble_cream", "color": "#45423F", "roughness": 0.8},
    "cork": {"source": "concrete", "color": "#A57C52", "roughness": 1.1},
    "concrete_light": {"source": "concrete", "color": "#B4AFA6", "roughness": 1.0},
    "canvas_teal": {"source": "fabric_upholstery", "color": "#2F5A5C", "roughness": 1.0},
    "canvas_ivory": {"source": "fabric_upholstery", "color": "#D2C6B0", "roughness": 1.0},
    "bag_black": {"source": "fabric_upholstery", "color": "#2B2C2E", "roughness": 1.0},
    "velvet_charcoal": {"source": "fabric_upholstery", "color": "#3B3437", "roughness": 1.0},
    "canvas_walnut": {"source": "fabric_upholstery", "color": "#5A3B28", "roughness": 1.0},
    "leaf_dark": {"source": "leather_dark", "color": "#2F4A2A", "roughness": 0.8},
    "art_ochre": {"source": "plaster_painted", "color": "#B98B4A", "roughness": 1.0},
    "art_blue": {"source": "plaster_painted", "color": "#3F5873", "roughness": 1.0},
    "art_rust": {"source": "plaster_painted", "color": "#94513A", "roughness": 1.0},
    # Night Deposit (Harbor Savings & Loan, docs/design/heists/night_deposit.md palette)
    "paint_slate": {"source": "drywall_painted", "color": "#3F5A52", "roughness": 0.8},
    "canvas_bank": {"source": "fabric_upholstery", "color": "#B9A98A", "roughness": 1.0},
    "velvet_red": {"source": "fabric_upholstery", "color": "#7E2924", "roughness": 1.0},
    "cash_green": {"source": "plaster_painted", "color": "#7F9373", "roughness": 1.0},
    "hull_navy": {"source": "metal_painted", "color": "#2C3A4A", "roughness": 0.9},
    "hull_white": {"source": "metal_painted", "color": "#C9C6BC", "roughness": 0.9},
    "container_rust": {"source": "metal_painted", "color": "#8A4630", "roughness": 1.0},
    "container_blue": {"source": "metal_painted", "color": "#3A5470", "roughness": 1.0},
    "container_green": {"source": "metal_painted", "color": "#4E6B4A", "roughness": 1.0},
    # Gallery Night (docs/design/heists/gallery_night.md palette: bone, halberd green, gilt; GN-C2)
    "car_black": {"source": "plastic_matte", "color": "#1F2023", "roughness": 0.4},
    "paint_halberd": {"source": "drywall_painted", "color": "#24463A", "roughness": 0.8},
    "steel_galv": {"source": "drywall_painted", "color": "#8E9497", "roughness": 0.7},
    # equipment (D-111 deployables: ammo bag olive drab, medic patch red, armor-bag coyote carrier)
    "bag_olive": {"source": "fabric_upholstery", "color": "#4B5136", "roughness": 1.0},
    "bag_red": {"source": "fabric_upholstery", "color": "#8A2C27", "roughness": 1.0},
    "bag_coyote": {"source": "fabric_upholstery", "color": "#7A6A4E", "roughness": 1.0},
    "metal_rust": {"source": "metal_painted", "color": "#5E3A2A", "roughness": 1.0},
}

# Painted canvases (GN-C2): key -> albedo PNG from tools/texgen/paintings.py. The prop material is a plain
# albedo-textured StandardMaterial3D (meta untextured_ok: no ORM/normal, the image is the detail); the Blender
# scripts map the painted face 0..1 onto the image (cover fit), not world-scaled.
PAINTINGS: dict[str, str] = {
    f"painting_{pid}": f"res://assets/textures/paintings/tex_painting_{pid}_albedo.png"
    for pid in ("lantern", "orchard", "widow", "saint", "study1", "study2", "study3", "study4", "study5", "study6",
                "study7", "study8")
}

# Untextured materials (validator meta untextured_ok): emissives and LEDs. color/emission sRGB.
EMISSIVE: dict[str, dict] = {
    "emit_neon_magenta": {"color": "#5A1636", "emission": "#FF3EA5", "energy": 6.0},
    "emit_warm": {"color": "#8A6A48", "emission": "#FFB46B", "energy": 3.0},
    "emit_neutral": {"color": "#8A7C6A", "emission": "#FFD9B0", "energy": 2.5},
    "emit_cool": {"color": "#8A8784", "emission": "#F4EEE4", "energy": 2.5},
    "emit_screen": {"color": "#1C2228", "emission": "#7890A6", "energy": 0.9},
    "emit_led_red": {"color": "#3A0C0A", "emission": "#FF2A1A", "energy": 3.0},
    "emit_led_green": {"color": "#0C2A12", "emission": "#3AD15A", "energy": 3.0},
    "emit_exit_green": {"color": "#123A20", "emission": "#36B25A", "energy": 2.0},
    "emit_amber": {"color": "#3A2A0A", "emission": "#FFA020", "energy": 3.0},
    "emit_sodium": {"color": "#5A3414", "emission": "#FF9A3C", "energy": 4.0},
    "emit_mint": {"color": "#40564A", "emission": "#D8FFE8", "energy": 3.0},
    "emit_clock": {"color": "#8A8068", "emission": "#FFF1D2", "energy": 1.6},
    # burn barrel (D-111): flame tongues and the ember bed / vent glow
    "emit_fire": {"color": "#6A2A0A", "emission": "#FF7A22", "energy": 5.0},
    "emit_ember": {"color": "#3A1206", "emission": "#FF3A0C", "energy": 3.0},
}

# Transparent variants of glass_clear (library albedo with alpha x colour).
GLASS: dict[str, dict] = {
    "glass_frosted": {"source": "glass_clear", "color": "#E4E8E6", "alpha": 0.82},
    "glass_tinted": {"source": "glass_clear", "color": "#3A4044", "alpha": 0.9},
}

# Prop ids (Godot) are prefixed so they can never collide with a library id.
PROP_PREFIX = "pr_"


def prop_id(key: str) -> str:
    return PROP_PREFIX + key


def slot(key: str) -> tuple[str, str, float, float, float]:
    """(material id, placeholder sRGB hex, roughness, metallic, alpha) for a material key."""
    if key in LIBRARY:
        return LIBRARY[key]
    if key in TINTED:
        t = TINTED[key]
        return (prop_id(key), t["color"], min(1.0, 0.6 * t.get("roughness", 1.0)), t.get("metallic", 0.0), 1.0)
    if key in GLASS:
        g = GLASS[key]
        return (prop_id(key), g["color"], 0.1, 0.0, g["alpha"])
    if key in EMISSIVE:
        e = EMISSIVE[key]
        return (prop_id(key), e["emission"], 0.5, 0.0, 1.0)
    if key in PAINTINGS:
        return (prop_id(key), "#8A7A62", 0.75, 0.0, 1.0)
    raise KeyError(f"unknown prop material key {key!r}")


def all_keys() -> list[str]:
    return sorted(set(LIBRARY) | set(TINTED) | set(EMISSIVE) | set(GLASS) | set(PAINTINGS))


# Texture width (px) of every library id whose tile is 512 px over 2 m (style: low-detail surfaces).
LIB_512 = {"chrome", "rubber_black", "plastic_matte", "glass_clear", "ceiling_tile"}
# Weapon/gear library ids whose 1024 px texture tiles every 1 m (metadata/uv_tile_m = 1.0): at the prop
# density (512 px/m) they need the same one-repeat-per-metre UVs as the 512 px tiles.
TILE_1M = {"polymer_black", "polymer_olive", "steel_bare", "brass_cartridge", "alu_anodized_black",
           "paint_safety_orange"}


def texture_px(mat_id: str) -> float:
    """Albedo texture size behind a material id (library or prop) -> UV density choice."""
    if mat_id in LIB_512 or mat_id in TILE_1M:
        return 512.0
    if mat_id.startswith(PROP_PREFIX):
        key = mat_id[len(PROP_PREFIX):]
        src = (TINTED.get(key) or GLASS.get(key) or {}).get("source")
        if src in LIB_512:
            return 512.0
    return 1024.0
