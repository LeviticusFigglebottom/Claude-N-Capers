"""Writers for Godot text resources (.tres/.tscn) and ``.import`` sidecars.

``.import`` handling: we write a minimal file with the parameters that matter. When Godot imports
it adds ``uid``, ``path`` and default params; on later builds we only patch our keys in
``[params]`` and keep everything else, so re-running the build never churns Godot's uids.
"""

from __future__ import annotations

import math
from pathlib import Path

from texgen import io as tio

TEXTURE_PARAMS_COMMON = {
    "compress/mode": "2",              # VRAM compressed (BPTC/S3TC desktop)
    "compress/high_quality": "false",
    "mipmaps/generate": "true",
    "process/fix_alpha_border": "true",
    "process/normal_map_invert_y": "false",   # our normals are already OpenGL (Y+)
}

IMPORT_PARAMS = {
    # BPTC (BC7) for albedo: plain S3TC (BC1 5:6:5) visibly tints dark neutrals green.
    "albedo": {**TEXTURE_PARAMS_COMMON, "compress/normal_map": "2", "compress/high_quality": "true"},
    "orm": {**TEXTURE_PARAMS_COMMON, "compress/normal_map": "2"},
    "normal": {**TEXTURE_PARAMS_COMMON, "compress/normal_map": "1"},
}

LUT_IMPORT_PARAMS = {
    "compress/mode": "0",   # lossless: a LUT must not be block-compressed
    "mipmaps/generate": "false",
}


def _hex_color(hx: str, alpha: float = 1.0) -> str:
    h = hx.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return f"Color({r:.4f}, {g:.4f}, {b:.4f}, {alpha:g})"


def ensure_import(png: Path, importer: str, rtype: str, params: dict) -> None:
    imp = png.with_name(png.name + ".import")
    text = imp.read_text(encoding="utf-8").splitlines() if imp.exists() else []
    if f'importer="{importer}"' not in text:
        # Missing, or Godot auto-imported it with the wrong importer before we wrote ours:
        # start fresh (keeping the uid so references stay valid).
        uid = [ln for ln in text if ln.startswith("uid=")]
        lines = ["[remap]", "", f'importer="{importer}"', f'type="{rtype}"', *uid, "", "[params]", ""]
        lines += [f"{k}={v}" for k, v in params.items()]
        tio.write_text(imp, "\n".join(lines) + "\n")
        return
    out: list[str] = []
    in_params = False
    seen: set[str] = set()
    for line in text:
        if line.startswith("["):
            if in_params:
                out += [f"{k}={v}" for k, v in params.items() if k not in seen]
            in_params = line.strip() == "[params]"
        elif in_params and "=" in line:
            key = line.split("=", 1)[0]
            if key in params:
                line = f"{key}={params[key]}"
                seen.add(key)
        out.append(line)
    if in_params:
        out += [f"{k}={v}" for k, v in params.items() if k not in seen]
    tio.write_text(imp, "\n".join(out) + "\n")


def write_material(path: Path, lib_id: str, tex_res: str, kind: str, tile_m: float,
                   specular: float | None = None, clearcoat: dict | None = None) -> None:
    """ORMMaterial3D referencing tex_<id>_{albedo,orm,normal}.png under ``tex_res``."""
    alb = f"{tex_res}/tex_{lib_id}_albedo.png"
    orm = f"{tex_res}/tex_{lib_id}_orm.png"
    nrm = f"{tex_res}/tex_{lib_id}_normal.png"
    lines = [
        '[gd_resource type="ORMMaterial3D" load_steps=4 format=3]',
        "",
        f'[ext_resource type="Texture2D" path="{alb}" id="1_albedo"]',
        f'[ext_resource type="Texture2D" path="{orm}" id="2_orm"]',
        f'[ext_resource type="Texture2D" path="{nrm}" id="3_normal"]',
        "",
        "[resource]",
        f'resource_name = "M_{lib_id}"',
    ]
    if kind == "glass":
        lines += ["transparency = 1", "depth_draw_mode = 1"]
    lines += [
        "texture_filter = 5",
        'albedo_texture = ExtResource("1_albedo")',
        "metallic = 1.0",
        *([f"metallic_specular = {float(specular)}"] if specular is not None else []),
        "roughness = 1.0",
        'orm_texture = ExtResource("2_orm")',
        "normal_enabled = true",
        "normal_scale = 1.0",
        'normal_texture = ExtResource("3_normal")',
        "ao_enabled = true",
        *([
            "clearcoat_enabled = true",
            f"clearcoat = {float(clearcoat.get('amount', 1.0))}",
            f"clearcoat_roughness = {float(clearcoat.get('roughness', 0.1))}",
        ] if clearcoat else []),
        f"metadata/uv_tile_m = {float(tile_m)}",
    ]
    tio.write_text(path, "\n".join(lines) + "\n")


def write_emissive_material(path: Path, lib_id: str, p: dict) -> None:
    """Emissive StandardMaterial3D (reticles, indicator LEDs, pilot flames). Emission (not
    unshaded) so the HDR value can exceed 1 and catch the glow pass.

    Optional ``gradient`` (list of (offset, sRGB hex)) adds an embedded ``GradientTexture2D`` as
    the emission texture, running along mesh V from ``gradient_from`` to ``gradient_to`` (UV
    points; default bottom -> top). No PNG is involved, so it stays deterministic text.
    """
    grad = p.get("gradient")
    lines = ['[gd_resource type="StandardMaterial3D" format=3]', ""]
    if grad:
        offs = ", ".join(f"{float(o):g}" for o, _c in grad)
        cols = ", ".join(_hex_color(c)[6:-1] for _o, c in grad)
        fx, fy = p.get("gradient_from", (0.5, 1.0))
        tx, ty = p.get("gradient_to", (0.5, 0.0))
        lines += [
            '[sub_resource type="Gradient" id="Gradient_emit"]',
            f"offsets = PackedFloat32Array({offs})",
            f"colors = PackedColorArray({cols})",
            "",
            '[sub_resource type="GradientTexture2D" id="GradientTexture2D_emit"]',
            'gradient = SubResource("Gradient_emit")',
            "width = 16",
            "height = 64",
            f"fill_from = Vector2({fx:g}, {fy:g})",
            f"fill_to = Vector2({tx:g}, {ty:g})",
            "",
        ]
    lines += [
        "[resource]",
        f'resource_name = "M_{lib_id}"',
        f"albedo_color = {_hex_color(p['albedo'])}",
        f"roughness = {p.get('roughness', 0.6)}",
        "emission_enabled = true",
        f"emission = {_hex_color(p['emission'])}",
        f"emission_energy_multiplier = {p['emission_energy']}",
        "disable_receive_shadows = true",
        # Multiply (operator 1): emission colour x gradient. The default (add) would sum the
        # gradient with the emission colour and wash it out to white.
        *(['emission_operator = 1', 'emission_texture = SubResource("GradientTexture2D_emit")'] if grad else []),
        "metadata/uv_tile_m = 1.0",
    ]
    tio.write_text(path, "\n".join(lines) + "\n")


def write_environment(path: Path, e: dict, lut_res: str) -> None:
    lines = [
        '[gd_resource type="Environment" load_steps=4 format=3]',
        "",
        f'[ext_resource type="Texture3D" path="{lut_res}" id="1_lut"]',
        "",
        '[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_sky"]',
        f"sky_top_color = {_hex_color(e['sky_top'])}",
        f"sky_horizon_color = {_hex_color(e['sky_horizon'])}",
        f"sky_curve = {e['sky_curve']}",
        f"sky_energy_multiplier = {e['sky_energy']}",
        f"ground_bottom_color = {_hex_color(e['ground_bottom'])}",
        f"ground_horizon_color = {_hex_color(e['ground_horizon'])}",
        f"ground_curve = {e['ground_curve']}",
        f"sun_angle_max = {e['sun_angle_max']}",
        f"sun_curve = {e['sun_curve']}",
        "",
        '[sub_resource type="Sky" id="Sky_main"]',
        'sky_material = SubResource("ProceduralSkyMaterial_sky")',
        "",
        "[resource]",
        "background_mode = 2",
        'sky = SubResource("Sky_main")',
        "ambient_light_source = 3",
        f"ambient_light_energy = {e['ambient_energy']}",
        "reflected_light_source = 2",
        "tonemap_mode = 4",
        f"tonemap_exposure = {e['exposure']}",
        f"tonemap_agx_white = {e['agx_white']}",
        f"tonemap_agx_contrast = {e['agx_contrast']}",
        "ssao_enabled = true",
        f"ssao_radius = {e['ssao_radius']}",
        f"ssao_intensity = {e['ssao_intensity']}",
        "ssil_enabled = true",
        f"ssil_radius = {e['ssil_radius']}",
        f"ssil_intensity = {e['ssil_intensity']}",
        "glow_enabled = true",
        f"glow_intensity = {e['glow_intensity']}",
        f"glow_bloom = {e['glow_bloom']}",
        "glow_blend_mode = 1",
        f"glow_hdr_threshold = {e['glow_hdr_threshold']}",
        "fog_enabled = true",
        f"fog_light_color = {_hex_color(e['fog_color'])}",
        f"fog_density = {e['fog_density']}",
        "fog_sky_affect = 0.0",
        "adjustment_enabled = true",
        'adjustment_color_correction = ExtResource("1_lut")',
    ]
    tio.write_text(path, "\n".join(lines) + "\n")


def _sun_basis(elevation_deg: float, azimuth_deg: float) -> list[list[float]]:
    """Rows of a basis whose -Z points from the sun toward the ground.

    Azimuth is measured clockwise from -Z (north/forward) toward +X (east).
    """
    el = math.radians(elevation_deg)
    az = math.radians(azimuth_deg)
    to_sun = (math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el))
    z = to_sun
    up = (0.0, 1.0, 0.0)
    x = (up[1] * z[2] - up[2] * z[1], up[2] * z[0] - up[0] * z[2], up[0] * z[1] - up[1] * z[0])
    xl = math.sqrt(sum(c * c for c in x))
    x = tuple(c / xl for c in x)
    y = (z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0])
    cols = (x, y, z)
    return [[cols[j][i] for j in range(3)] for i in range(3)]


def write_sun_scene(path: Path, name: str, e: dict) -> None:
    rows = _sun_basis(e["sun_elevation"], e["sun_azimuth"])
    vals = ", ".join(f"{rows[i][j]:.6f}" for i in range(3) for j in range(3))
    lines = [
        "[gd_scene format=3]",
        "",
        f'[node name="{name}" type="DirectionalLight3D"]',
        f"transform = Transform3D({vals}, 0, 10, 0)",
        f"light_color = {_hex_color(e['sun_color'])}",
        f"light_energy = {e['sun_energy']}",
        "shadow_enabled = true",
        "directional_shadow_max_distance = 120.0",
    ]
    tio.write_text(path, "\n".join(lines) + "\n")
