"""Preset "gsr": Grounded Stylized Realism (docs/art/style_guide.md, provisional, D-012).

EVERYTHING art-directable lives here: colours (sRGB hex), roughness ranges, wear/grime, pattern
sizes, LUT grades and environment settings. Changing art direction = copy this file, edit values,
run ``build.py --preset <name>``. Generators must not hard-code colours.
"""

PRESET = {
    "name": "gsr",
    # Global multipliers (per-heist variants can scale these: bank 0.3, docks 1.8).
    "scales": {"wear": 1.0, "grime": 1.0},
    # style_guide.md §3. Luminance is linear; saturation is HSV S of the sRGB-encoded value.
    "rules": {
        "lum_min": 0.04,
        "lum_max": 0.85,
        "sat_max": 0.75,
        "metal_rough_min": 0.15,
        "forbidden": ["#4FD1E8"],
        "forbidden_dist": 40.0,
    },
    "materials": {
        "plaster_painted": {
            "base": "#E3D8C6", "rough": (0.74, 0.84), "undulation_mm": 0.6, "trowel_mm": 0.25,
            "mottle": 0.035, "wear": 0.15, "grime": 0.25,
        },
        "drywall_painted": {
            "base": "#D6D2C9", "rough": (0.62, 0.70), "peel_mm": 0.06, "peel_cells_per_m": 70,
            "mottle": 0.02, "wear": 0.1, "grime": 0.2,
        },
        "concrete": {
            "base": "#7E7C77", "dark": "#62615D", "light": "#8F8D87", "rough": (0.72, 0.9),
            "pore_cells_per_m": 45, "pore_density": 0.35, "crack": 0.6, "wear": 0.4, "grime": 0.6,
        },
        "terrazzo": {
            "matrix": "#CEC6B7",
            "chips": ["#EDE8DF", "#9A958C", "#3F3C39", "#A86A44", "#6F7B6B", "#D8C9AC", "#B9B2A6"],
            "chip_weights": [0.24, 0.18, 0.12, 0.1, 0.08, 0.16, 0.12],
            "big_cells_per_m": 18, "small_cells_per_m": 55, "rough": (0.16, 0.26),
            "wear": 0.1, "grime": 0.3,
        },
        "marble_cream": {
            "base": "#DCD4C3", "base2": "#CFC4AE", "vein": "#8F8576", "vein_gold": "#B79F78",
            "slab_m": 1.0, "rough": (0.1, 0.16), "etch_rough": 0.26, "seam": 0.5,
            "wear": 0.05, "grime": 0.2,
        },
        "carpet_commercial": {
            "base": "#585C63", "heather_a": "#4D535D", "heather_b": "#6C665D", "seam": "#3C3E42",
            "tile_m": 0.5, "rows_per_tile": 32, "rough": (0.9, 0.98), "wear": 0.2, "grime": 0.35,
        },
        "ceiling_tile": {
            "tile": "#E3E1DB", "grid": "#D6D5D1", "tile_m": 0.5, "grid_mm": 24,
            "rough": (0.9, 0.97), "grid_rough": 0.42, "wear": 0.0, "grime": 0.25,
        },
        "wood_veneer_walnut": {
            "base": "#5B4332", "late": "#3F2E22", "light": "#76573F", "leaf_m": 0.25,
            "rings_per_leaf": 9, "rough": (0.34, 0.44), "pore_rough": 0.55, "wear": 0.15,
            "grime": 0.15,
        },
        "brushed_steel": {
            "base": "#C3C5C8", "rough": (0.28, 0.4), "streak": 0.05, "wear": 0.0, "grime": 0.15,
        },
        "chrome": {"base": "#C8C9CA", "rough": (0.15, 0.2), "smudge": 0.05, "wear": 0.0, "grime": 0.1},
        "brass": {
            "base": "#E3C886", "tarnish": "#8C6E3E", "rough": (0.26, 0.32), "tarnish_rough": 0.55,
            "wear": 0.2, "grime": 0.2,
        },
        "glass_clear": {
            "tint": "#E6EEEA", "dirt": "#8A877E", "alpha": 0.1, "dirt_alpha": 0.25,
            "rough": (0.03, 0.08), "dirt_rough": 0.5, "wear": 0.0, "grime": 0.5,
        },
        "rubber_black": {
            "base": "#3B3B3A", "rough": (0.84, 0.92), "wear": 0.25, "grime": 0.2, "relief_ref_mm": 0.2,
        },
        "fabric_upholstery": {
            "base": "#4A5262", "heather": "#5E6573", "weave_cells_per_m": 64, "rough": (0.88, 0.96),
            "relief_ref_mm": 0.4,
            "wear": 0.2, "grime": 0.2,
        },
        "leather_dark": {
            "base": "#4A372D", "crease": "#33271F", "scuff": "#675043", "grain_cells_per_m": 55,
            "rough": (0.42, 0.58), "wear": 0.35, "grime": 0.3,
            "grime_color": "#2E241E", "relief_ref_mm": 0.2,
        },
        "plastic_matte": {"base": "#6C6E71", "rough": (0.52, 0.6), "wear": 0.15, "grime": 0.2},
        "brick_red": {
            "brick": "#8A4835", "brick_dark": "#6C3A2C", "brick_orange": "#A2593B",
            "mortar": "#A8A396", "bricks_per_row": 9, "courses": 26, "mortar_mm": 10,
            "rough": (0.82, 0.92), "mortar_rough": 0.95, "wear": 0.5, "grime": 0.5,
        },
        "asphalt": {
            "base": "#3C3C3A", "stone": "#5F5D59", "stain": "#2E2E2D", "rough": (0.84, 0.95),
            "stone_cells_per_m": 90, "crack": 0.5, "wear": 0.3, "grime": 0.4,
        },
        "tile_ceramic_white": {
            "tile": "#E4E2DD", "grout": "#A9A59D", "tile_m": 0.2, "grout_mm": 4,
            "rough": (0.07, 0.12), "grout_rough": 0.9, "wear": 0.05, "grime": 0.55,
        },
        "vinyl_floor": {
            "tile_a": "#C7BFAF", "tile_b": "#BAB2A2", "chip_dark": "#8E8679", "chip_light": "#DCD6CA",
            "tile_m": 0.5, "rough": (0.42, 0.58), "wear": 0.3, "grime": 0.45,
        },
        "metal_painted": {
            "paint": "#4B5157", "steel": "#B4B7BA", "rough": (0.4, 0.5), "steel_rough": 0.32,
            "chip": 0.5, "wear": 0.5, "grime": 0.35,
        },
        # Trim sheet colour overrides (sources are library materials; see trim.py).
        "trim_interior": {"paint": "#E2DCD0", "paint_rough": 0.38, "wear": 0.15, "grime": 0.2},
    },
    # 3D LUT grades (lut.py). Ops run in display (sRGB-encoded, post-tonemap) space.
    "luts": {
        "neutral": {},
        "glasshouse": {
            # ASC-CDL-ish: slope (gain), offset (lift), power (gamma) per channel.
            "slope": (1.035, 1.0, 0.955),
            "offset": (0.0, 0.0, 0.0),
            "power": (1.0, 1.0, 1.0),
            # Split toning: shadows pulled cool, highlights warm, weighted by luma.
            "shadow_tint": (-0.012, 0.0, 0.022),
            "highlight_tint": (0.018, 0.006, -0.016),
            "contrast": 1.06,
            "pivot": 0.45,
            "saturation": 1.04,
        },
    },
    # Godot Environment resources (godot.py).
    "environments": {
        "glasshouse": {
            "lut": "glasshouse",
            "sky_top": "#1E3557",
            "sky_horizon": "#B98A86",
            "ground_horizon": "#4A3F42",
            "ground_bottom": "#141518",
            "sky_curve": 0.12,
            "ground_curve": 0.05,
            "sun_angle_max": 12.0,
            "sun_curve": 0.08,
            "sky_energy": 0.7,
            "ambient_energy": 0.6,
            "exposure": 1.0,
            "agx_white": 12.0,
            "agx_contrast": 1.15,
            "glow_intensity": 0.35,
            "glow_bloom": 0.04,
            "glow_hdr_threshold": 1.1,
            "ssao_radius": 1.2,
            "ssao_intensity": 1.6,
            "ssil_radius": 4.0,
            "ssil_intensity": 0.8,
            "fog_density": 0.0015,
            "fog_color": "#6A6E86",
            # Sun scene (sun_glasshouse.tscn): elevation/azimuth in degrees, colour, energy.
            "sun_elevation": 4.0,
            "sun_azimuth": 250.0,
            "sun_color": "#FF9E66",
            "sun_energy": 0.35,
        },
    },
}
