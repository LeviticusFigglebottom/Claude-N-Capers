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
        # D-038 (weapon blacks lifted to ~60-85 sRGB, lead r188): black polymers, rubber and black paint/anodize
        # may set a per-material "lum_min"
        # down to this value; every other material keeps lum_min.
        "lum_min_black": 0.02,
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
        "glass_frosted": {
            # D-142: one shared frosted look (the maps' privacy panes; the props' pr_glass_frosted points at it)
            "tint": "#E4E8E6", "shade": "#C9D0CF", "alpha": (0.78, 0.88), "wipe_clear": 0.06,
            "rough": (0.55, 0.7), "wear": 0.0, "grime": 0.0,
        },
        "rubber_black": {
            "base": "#3C3C3C", "rough": (0.84, 0.92), "wear": 0.25, "grime": 0.2, "relief_ref_mm": 0.2,
            "specular": 0.35, "lum_min": 0.02,
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
        # ---- OF-C2: Ostrander Federal G2 surfaces (bank: pristine) ----
        "limestone_ashlar": {
            # palette limestone #CBC3B0 (ostrander_federal.md Audio/lighting), neutral enough for the hall and VC
            "stone": "#C6BEAB", "stone_light": "#D3CCBB", "stone_dark": "#B3AA96", "joint": "#8A8272",
            "blocks_per_row": 2, "courses": 4, "joint_mm": 5, "chamfer_mm": 6, "bedding": 0.6,
            "rough": (0.72, 0.84), "joint_rough": 0.92, "wear": 0.08, "grime": 0.15,
        },
        "wood_panel_oak": {
            "base": "#7A5A3F", "late": "#5A412D", "light": "#8E6B4C", "bays": 4, "rows": 2, "stile_mm": 70,
            "bevel_mm": 35, "rings": 34, "rough": (0.36, 0.46), "pore_rough": 0.56, "wear": 0.08, "grime": 0.12,
        },
        "steel_plate_riveted": {
            # vault paint: a grey ultramarine (secondary #2F3F6B lifted to read under the 4000 K strips)
            "paint": "#59627A", "seam": "#3E4352", "plates": 2, "seam_mm": 4, "rivet_inset_mm": 40,
            "rivet_pitch_mm": 100, "rivet_mm": 16, "rough": (0.38, 0.5), "wear": 0.1, "grime": 0.15,
        },
        # ---- RT-C2: Rolling Thunder (the site hoarding: weathered exterior paint on ply) ----
        "plywood_painted": {
            "paint": "#3E5646", "gap": "#262A27", "sheets": 2, "gap_mm": 3, "rough": (0.72, 0.86),
            "wear": 0.35, "grime": 0.5,
        },
        # RT-C2 GPU-21: the diner's checkerboard vinyl (vinyl_floor's model; 0.25 m squares, cream / charcoal)
        "vinyl_checker": {
            "tile_a": "#D9D1BF", "tile_b": "#3A3A3D", "chip_dark": "#6E6A62", "chip_light": "#C9C3B6",
            "tile_m": 0.25, "rough": (0.3, 0.46), "wear": 0.3, "grime": 0.4,
        },
        # ---- First-person weapon materials (D-026; 1 m tiles at 1024 px/m) ----
        "polymer_black": {
            "base": "#45464A", "rough": (0.64, 0.76), "grain_cells_per_m": 300, "wear": 0.25,
            "grime": 0.2, "relief_ref_mm": 0.1, "specular": 0.4, "lum_min": 0.02,
        },
        "polymer_stipple": {
            "base": "#3F4042", "rough": (0.66, 0.8), "stipple_cells_per_m": 220, "stipple_mm": 0.35,
            "wear": 0.35, "grime": 0.3, "relief_ref_mm": 0.1, "specular": 0.4, "lum_min": 0.02,
        },
        "steel_blued": {
            "base": "#6A717C", "worn": "#ACAFB3", "rough": (0.3, 0.4), "worn_rough": 0.28,
            "holster_wear": 0.35, "wear": 0.3, "grime": 0.1,
        },
        "steel_bare": {"base": "#B7B9BC", "rough": (0.22, 0.32), "streak": 0.05, "wear": 0.0, "grime": 0.05},
        "metal_matte": {"base": "#76797D", "rough": (0.5, 0.6), "wear": 0.2, "grime": 0.2},
        # Armory batch 3.
        "paint_safety_orange": {
            # #E8641E pulled to the 0.75 saturation cap and a little darker so it stays rich under AgX.
            "paint": "#CC6633", "steel": "#B4B7BA", "rough": (0.36, 0.46), "steel_rough": 0.32,
            "chip": 0.5, "wear": 0.45, "grime": 0.35,
        },
        "carbon_fibre": {
            "base": "#2A2B2D", "sheen": "#414347", "tows_per_m": 256, "rough": (0.3, 0.42),
            "lum_min": 0.02, "specular": 0.5, "clearcoat": {"amount": 1.0, "roughness": 0.08},
            "wear": 0.0, "grime": 0.05,
        },
        "emissive_pilot_flame": {
            "albedo": "#0E0F14", "emission": "#FFFFFF", "emission_energy": 1.0, "roughness": 1.0,
            # Blue core at the burner (mesh V = 1, bottom) to orange tip (V = 0, top).
            "gradient": [(0.0, "#1F4DFF"), (0.35, "#3D63F0"), (0.55, "#FF7A1F"), (1.0, "#E84A0C")],
            "gradient_from": (0.5, 1.0), "gradient_to": (0.5, 0.0),
        },
        # D-034 additions.
        "alu_anodized_black": {
            "base": "#53565B", "worn": "#BEC1C5", "rough": (0.34, 0.44), "worn_rough": 0.3,
            "edge_wear": 0.3, "wear": 0.3, "grime": 0.1, "lum_min": 0.02,
        },
        "polymer_tan": {
            "base": "#8A7A5C", "rough": (0.58, 0.7), "grain_cells_per_m": 300, "wear": 0.25,
            "grime": 0.3, "relief_ref_mm": 0.1, "specular": 0.4, "grime_color": "#4A4034",
        },
        "polymer_olive": {
            "base": "#5A5C45", "rough": (0.58, 0.7), "grain_cells_per_m": 300, "wear": 0.25,
            "grime": 0.25, "relief_ref_mm": 0.1, "specular": 0.4,
        },
        "glass_lens_coated": {
            "tint_a": "#8E89A2", "tint_b": "#89998D", "dirt": "#8A877E", "alpha": 0.25,
            "dirt_alpha": 0.4, "rough": (0.02, 0.04), "dirt_rough": 0.35, "wear": 0.0, "grime": 0.1,
        },
        "paint_white": {"base": "#DAD8D2", "rough": (0.4, 0.5), "wear": 0.1, "grime": 0.25},
        "brass_cartridge": {
            "base": "#E5C17C", "tarnish": "#8E6A3A", "rough": (0.17, 0.26), "tarnish_rough": 0.45,
            "wear": 0.0, "grime": 0.15,
        },
        "glass_lens_tint": {
            "tint": "#7E9A86", "dirt": "#8A877E", "alpha": 0.3, "dirt_alpha": 0.45,
            "rough": (0.02, 0.05), "dirt_rough": 0.35, "wear": 0.0, "grime": 0.15,
        },
        # Emissive, untextured (signage/emissive colours are exempt from the saturation cap).
        "emissive_reticle_red": {
            "albedo": "#2A0605", "emission": "#FF1A10", "emission_energy": 1.0, "roughness": 0.5,
        },
        # Night harbour water (kind "water", PO-13). Texture: ripple field sizes (cells per metre over the
        # 8 m tile), heights and the slick mask. Shader: deep body colour (dark green-grey, below the
        # albedo floor on purpose: water absorbs, its look is the reflection), Fresnel sheen toward the
        # fog/horizon, two ripple layers drifting against each other and a large slow slick layer.
        "water_harbour_night": {
            "ripple_cells_per_m": 0.75, "ripple_mm": 80.0, "chop_cells_per_m": 2.5, "chop_mm": 14.0,
            "warp": 0.035, "warp_cells_per_m": 0.25, "slope_range": 0.4, "slick_cells_per_m": 0.25,
            "shader": {
                "deep_color": "#1A2421", "sheen_color": "#46504F", "sheen": 0.35,
                "ripple_scale_b": 2.7, "slick_scale": 0.09,
                "flow_a": (0.012, 0.007), "flow_b": (-0.009, 0.013), "flow_slick": (0.002, -0.001),
                "ripple_strength": 0.45, "slick_calm": 0.25, "far_fade_m": 70.0,
                "roughness_calm": 0.04, "roughness_rippled": 0.12, "specular": 0.5,
                "glint_strength": 2.0, "glint_sharpness": 4000.0, "glint_spread": 0.25,
                "glint_fog": 0.004,
            },
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
        # Gallery Night (gallery_night.md §Audio/lighting): warm ivory mids, green-teal shadows, lifted lilac
        # highlights (the gala uplights outside).
        "gallery_night": {
            "slope": (1.02, 1.0, 0.97),
            "offset": (0.0, 0.004, 0.006),
            "power": (1.0, 1.0, 1.0),
            "shadow_tint": (-0.014, 0.008, 0.012),
            "highlight_tint": (0.012, 0.0, 0.016),
            "contrast": 1.05,
            "pivot": 0.45,
            "saturation": 1.02,
        },
        # Dockside Burn (dockside_burn.md §Audio/lighting): cold blue-grey shadows, sodium-orange highlights, slightly
        # crushed blacks in the fog.
        "dockside_burn": {
            "slope": (1.025, 1.0, 0.975),
            "offset": (-0.006, -0.004, 0.0),
            "power": (1.0, 1.0, 1.0),
            "shadow_tint": (-0.014, -0.002, 0.02),
            "highlight_tint": (0.022, 0.008, -0.02),
            "contrast": 1.08,
            "pivot": 0.42,
            "saturation": 0.95,
        },
        # Shadow Ledger (shadow_ledger.md §Audio/lighting): cool, desaturated, teal mids, neutral whites (the
        # highlights pulled back to neutral so the 6500 K coves and the crown fins stay white).
        "shadow_ledger": {
            "slope": (0.985, 1.0, 1.015),
            "offset": (-0.004, 0.0, 0.002),
            "power": (1.02, 1.0, 1.0),
            "shadow_tint": (-0.016, 0.006, 0.012),
            "highlight_tint": (0.004, 0.0, -0.004),
            "contrast": 1.06,
            "pivot": 0.44,
            "saturation": 0.88,
        },
        # Ostrander Federal (ostrander_federal.md §Audio/lighting, OF-C2): Friday afternoon daylight, the brightest heist:
        # warm, slightly golden highlights (the SW sun on the limestone and the bronze), neutral-cool shadows, clean
        # neutral mids, soft contrast and a small lift so no black is crushed.
        "ostrander_federal": {
            "slope": (1.015, 1.0, 0.98),
            "offset": (0.008, 0.008, 0.01),
            "power": (1.0, 1.0, 1.0),
            "shadow_tint": (-0.004, 0.0, 0.008),
            "highlight_tint": (0.02, 0.012, -0.014),
            "contrast": 0.97,
            "pivot": 0.45,
            "saturation": 1.02,
        },
        # Rolling Thunder (rolling_thunder.md §Audio/lighting, RT-C2): 16:50, the low autumn sun down Tannery: warm amber
        # highlights, teal-green shadows under the Skyway, the blacks held.
        # (the LEAD's r277 review: no lifted blacks, so no offset lift and contrast 1.0 round the pivot)
        "rolling_thunder": {
            "slope": (1.03, 1.0, 0.955),
            "offset": (0.0, 0.002, 0.002),
            "power": (1.0, 1.0, 1.0),
            "shadow_tint": (-0.01, 0.006, 0.006),
            "highlight_tint": (0.03, 0.014, -0.022),
            "contrast": 1.0,
            "pivot": 0.45,
            "saturation": 1.03,
        },
        # Safehouse "The Press" (safehouse.md §Lighting and mood, C4-03): night, warm 2700-3000 K pools in a dark
        # industrial shell: warm mids, print-works green in the shadows, the blacks held.
        "safehouse": {
            "slope": (1.03, 1.0, 0.96),
            "offset": (0.0, 0.002, 0.0),
            "power": (1.0, 1.0, 1.0),
            "shadow_tint": (-0.008, 0.008, 0.0),
            "highlight_tint": (0.02, 0.01, -0.015),
            "contrast": 1.02,
            "pivot": 0.45,
            "saturation": 1.0,
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
