"""Interior trim sheet ``trim_interior``: horizontal strips, each tiling along U.

Each strip borrows the surface of a library material (rows of that material's maps, so colours
and wear stay consistent with the library) and adds a 1D moulding profile across V that becomes
the strip's normal map and AO. Strip heights are in pixels at 512 px/m, so a strip's V extent equals
its real-world height and the U direction repeats every 2 m like every other library texture.

The UV table is exported to ``game/assets/textures/trim_interior/trim_table.json`` for
``tools/blender/lib`` (``v`` values given both in glTF/Godot convention, top = 0, and in Blender
convention, bottom = 0).
"""

from __future__ import annotations

import importlib

import numpy as np

from texgen import ops
from texgen.materials.base import Ctx, Maps, weather

PAD_PX = 4  # rows replicated above/below every strip (mip bleed guard)

# name, source lib id, height px (content, without padding), profile, paint override?, source row
STRIPS: list[dict] = [
    {"name": "baseboard", "source": "drywall_painted", "px": 64, "profile": "baseboard", "paint": True},
    {"name": "crown_cornice", "source": "drywall_painted", "px": 128, "profile": "crown", "paint": True},
    {"name": "door_casing", "source": "drywall_painted", "px": 48, "profile": "casing", "paint": True},
    {"name": "chair_rail", "source": "drywall_painted", "px": 32, "profile": "bullnose", "paint": True},
    {"name": "wood_trim", "source": "wood_veneer_walnut", "px": 48, "profile": "eased", "row": 24},
    {"name": "wood_trim_wide", "source": "wood_veneer_walnut", "px": 96, "profile": "chamfer", "row": 144},
    {"name": "metal_edge", "source": "brushed_steel", "px": 32, "profile": "chamfer"},
    {"name": "chrome_band", "source": "chrome", "px": 24, "profile": "half_round"},
    {"name": "brass_inlay", "source": "brass", "px": 16, "profile": "chamfer_small"},
    {"name": "rubber_strip", "source": "rubber_black", "px": 32, "profile": "ribs"},
    {"name": "rubber_bumper", "source": "rubber_black", "px": 64, "profile": "dome"},
    {"name": "metal_kickplate", "source": "metal_painted", "px": 64, "profile": "chamfer"},
    {"name": "plastic_edge", "source": "plastic_matte", "px": 24, "profile": "eased"},
    {"name": "picture_rail", "source": "drywall_painted", "px": 24, "profile": "bullnose", "paint": True},
]


def _profile(kind: str, t: np.ndarray, h_m: float) -> np.ndarray:
    """Height (metres) across the strip; t = 0 at the strip's top row, 1 at the bottom."""
    if kind == "baseboard":
        top = ops.smoothstep(0.0, 0.2, t)
        ogee = 0.006 * (top - 1.0) + 0.0015 * np.sin(np.pi * np.clip(t / 0.2, 0, 1))
        return np.where(t < 0.2, ogee, 0.0) - 0.002 * ops.smoothstep(0.94, 1.0, t)
    if kind == "crown":
        cove = -0.03 * np.sin(np.pi * np.clip((t - 0.15) / 0.7, 0.0, 1.0))
        fillet = np.where(t < 0.08, 0.004, 0.0) + np.where(t > 0.92, 0.004, 0.0)
        return cove + fillet
    if kind == "casing":
        bead = 0.004 * np.sqrt(np.clip(1.0 - ((t - 0.07) / 0.07) ** 2, 0.0, 1.0))
        step = np.where(t < 0.18, 0.0, -0.003)
        return np.where(t < 0.14, bead, step) - 0.003 * ops.smoothstep(0.9, 1.0, t)
    if kind == "bullnose":
        return 0.6 * h_m * np.sqrt(np.clip(np.sin(np.pi * t), 0.0, 1.0)) * 0.5
    if kind == "eased":
        e = np.minimum(t, 1.0 - t)
        return 0.003 * np.sqrt(np.clip(e / 0.15, 0.0, 1.0)).clip(0, 1)
    if kind == "chamfer":
        e = np.minimum(t, 1.0 - t) * h_m
        return np.minimum(e, 0.003)
    if kind == "chamfer_small":
        e = np.minimum(t, 1.0 - t) * h_m
        return np.minimum(e, 0.001)
    if kind == "half_round":
        return 0.5 * h_m * np.sqrt(np.clip(1.0 - (2.0 * t - 1.0) ** 2, 0.0, 1.0))
    if kind == "ribs":
        return 0.0015 * (0.5 + 0.5 * np.cos(2.0 * np.pi * t * 4.0))
    if kind == "dome":
        return 0.4 * h_m * np.sqrt(np.clip(1.0 - (2.0 * t - 1.0) ** 2, 0.0, 1.0))
    raise ValueError(kind)


def layout(size: int) -> list[dict]:
    """Pixel/UV placement of every strip (content rows only, padding excluded)."""
    y = 0
    out = []
    for s in STRIPS:
        top = y + PAD_PX
        bottom = top + s["px"]
        out.append({**s, "px_top": top, "px_bottom": bottom})
        y = bottom + PAD_PX
    if y > size:
        raise ValueError(f"trim sheet overflow: {y} > {size}")
    return out


def generate(ctx: Ctx, make_ctx) -> tuple[Maps, list[dict]]:
    """``make_ctx(lib_id) -> Ctx`` builds a context for a source library material."""
    size = ctx.size
    rows = layout(size)
    albedo = np.zeros((size, size, 3))
    rough = np.ones((size, size)) * 0.8
    metal = np.zeros((size, size))
    height = np.zeros((size, size))
    cache: dict[str, tuple[Maps, Ctx]] = {}
    paint = ctx.col("paint")
    for s in rows:
        src_id = s["source"]
        if src_id not in cache:
            sctx = make_ctx(src_id)
            mod = importlib.import_module(f"texgen.materials.{src_id}")
            cache[src_id] = (mod.generate(sctx), sctx)
        src, sctx = cache[src_id]
        scale = size / sctx.size
        h_px = s["px"]
        y0 = s.get("row", 0)
        src_rows = np.arange(-PAD_PX, h_px + PAD_PX).clip(0, h_px - 1) + y0
        src_rows = (src_rows / scale).astype(np.int64) % sctx.size
        src_cols = (np.arange(size) / scale).astype(np.int64) % sctx.size
        a = src.albedo[np.ix_(src_rows, src_cols)]
        r = src.roughness[np.ix_(src_rows, src_cols)]
        m = src.metallic[np.ix_(src_rows, src_cols)]
        hh = src.height[np.ix_(src_rows, src_cols)]
        if s.get("paint"):
            base = ops.hex_to_linear(sctx.p("base"))
            a = a * (paint / base)[None, None, :]
            r = float(ctx.p("paint_rough")) + (r - r.mean()) * 0.5
        h_m = h_px / (size / ctx.tile_m)
        t = (np.arange(-PAD_PX, h_px + PAD_PX).clip(0, h_px - 1) + 0.5) / h_px
        prof = _profile(s["profile"], t, h_m)[:, None]
        y_top = s["px_top"] - PAD_PX
        sl = slice(y_top, y_top + h_px + 2 * PAD_PX)
        albedo[sl] = a
        rough[sl] = r
        metal[sl] = m
        height[sl] = hh * 0.5 + prof
    # Unused rows at the bottom: neutral paint, flat.
    used = rows[-1]["px_bottom"] + PAD_PX
    albedo[used:] = paint
    rough[used:] = float(ctx.p("paint_rough"))
    height[used:] = 0.0
    maps = Maps(albedo, rough, metal, height, normal_strength=1.0, ao_radii_m=(0.003, 0.01),
                ao_depth_m=0.003, ao_strength=0.7)
    weather(ctx, maps, edge_radius_m=0.003, cavity_radius_m=0.006)
    return maps, rows


def table(rows: list[dict], size: int, tile_m: float) -> dict:
    px_per_m = size / tile_m
    strips = []
    for s in rows:
        strips.append({
            "name": s["name"],
            "source_material": s["source"],
            "profile": s["profile"],
            "height_m": round(s["px"] / px_per_m, 6),
            "px_top": s["px_top"],
            "px_bottom": s["px_bottom"],
            "v_top_gltf": round(s["px_top"] / size, 6),
            "v_bottom_gltf": round(s["px_bottom"] / size, 6),
            "v_min_blender": round(1.0 - s["px_bottom"] / size, 6),
            "v_max_blender": round(1.0 - s["px_top"] / size, 6),
        })
    return {
        "_doc": "Generated by tools/texgen/build.py (trim.py). Do not edit. "
                "U repeats every u_repeat_m metres (1 UV unit = 2 m). V ranges exclude the "
                f"{PAD_PX}px padding. gltf/Godot V: 0 = top of image; Blender V: 0 = bottom.",
        "material": "trim_interior",
        "texture_size_px": size,
        "u_repeat_m": tile_m,
        "texel_density_px_per_m": px_per_m,
        "padding_px": PAD_PX,
        "strips": strips,
    }
