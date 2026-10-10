"""Style presets for the C1-00 art-direction samples (D-012).

Pure Python (no bpy) so both the Blender scene scripts and the Pillow post-process (post.py)
import the same dict. Every asset script builds ONE shared geometry and reads only these presets
for what differs between styles: proportions, bevels, surface treatment, lighting rig, render
settings and colour grade. Nothing here is hand-tuned per asset.

Styles (docs/art/style_guide.md §1):
  a_gsr   Grounded Stylized Realism: real proportions (head/hands x1.03), confident bevels,
          mid-frequency detail, soft key + warm practicals, gentle grade.
  b_noir  Neo-noir graphic: exaggerated shapes, painterly posterised albedo, ink outlines,
          hard rim light, deep shadow, magenta/teal neon, crushed contrast.
  c_photo Gritty photoreal: plausible softboxes/bounce, high-frequency micro detail, wear,
          grime, fingerprints, skin SSS, lens artefacts and grain.
"""

from __future__ import annotations

STYLE_IDS = ("a_gsr", "b_noir", "c_photo")

STYLES: dict[str, dict] = {
    "a_gsr": {
        "label": "A  Grounded Stylized Realism",
        # Geometry / proportions
        "head_scale": 1.03,          # style_guide §1: head and hands x1.03
        "exaggeration": 1.0,         # facial landmark exaggeration (1 = anatomical)
        "asymmetry": 0.0,            # real faces are asymmetric; stylised ones are not
        "bevel": 0.004,              # m, chamfer that catches light (2-8 mm band)
        "bevel_segments": 3,
        "smooth_iters": 6,           # SDF mesh smoothing passes (clean confident forms)
        # Surfaces
        "surface": "clean",          # clean | painterly | micro
        "variation": 0.05,           # low-frequency albedo variation amplitude
        "wear": 0.25,                # edge wear / cavity grime strength
        "micro": 0.0,                # high-frequency bump / roughness breakup
        "fingerprints": 0.0,
        "glass_smudge": 0.0,         # roughness amplitude of smudges/wipes/dust on glass
        "dust": 0.0,                 # dust on up-facing surfaces
        "brushed_metal": 0.0,        # anisotropic brushed finish on metals
        "velvet_fuzz": 0.0,          # velvet sheen + fibre micro-normal
        "micro_normal": 0.0,         # strength of high-frequency micro bump (also skin pores)
        "fabric_weave_scale": 1.0, "fabric_weave_strength": 1.0,
        "caustics": False,
        "posterize": 0,              # albedo steps (0 = off)
        "saturation": 1.0,           # albedo saturation multiplier
        "skin_sss": 0.35, "skin_sss_scale": 0.004, "skin_rough": 0.5,
        "outline": 0.0,              # Freestyle line thickness px (0 = off)
        # Lighting / render
        "rig": "soft_practical",
        "world_strength": 0.25,
        "world_color": (0.55, 0.62, 0.78),
        "exposure": -0.3,
        "look": "AgX - Base Contrast",
        "samples": 64,
        "dof_fstop": 4.0,
        "bloom": 0.35,
        # Post (post.py, display-referred)
        "grade": {"contrast": 1.06, "saturation": 1.05, "lift": (0.010, 0.012, 0.018),
                  "gain": (1.03, 1.0, 0.96), "vignette": 0.18, "grain": 0.0,
                  "chroma_ab": 0.0, "curve_toe": 0.0},
    },
    "b_noir": {
        "label": "B  Neo-noir Graphic",
        "head_scale": 1.07,
        "exaggeration": 1.35,        # squarer jaw, heavier brow, longer nose
        "asymmetry": 0.0,
        "bevel": 0.007,
        "bevel_segments": 1,         # flat graphic chamfers
        "smooth_iters": 3,           # keep it a little planar / chiselled
        "surface": "painterly",
        "variation": 0.16,
        "wear": 0.1,
        "micro": 0.0,
        "fingerprints": 0.0,
        "glass_smudge": 0.0, "dust": 0.0, "brushed_metal": 0.0, "velvet_fuzz": 0.0, "micro_normal": 0.0,
        "fabric_weave_scale": 0.5, "fabric_weave_strength": 0.3,
        "caustics": False,
        "posterize": 5,
        "saturation": 0.85,
        "skin_sss": 0.12, "skin_sss_scale": 0.003, "skin_rough": 0.55,
        "outline": 1.6,
        "rig": "noir_neon",
        "world_strength": 0.05,
        "world_color": (0.20, 0.30, 0.50),
        "exposure": 0.0,
        "look": "AgX - High Contrast",
        "samples": 64,
        "dof_fstop": 5.6,
        "bloom": 0.7,
        "grade": {"contrast": 1.22, "saturation": 1.18, "lift": (0.0, 0.012, 0.022),
                  "gain": (1.04, 0.98, 1.02), "vignette": 0.42, "grain": 0.018,
                  "chroma_ab": 0.0, "curve_toe": 0.06},
    },
    "c_photo": {
        "label": "C  Gritty Photoreal",
        "head_scale": 1.0,
        "exaggeration": 1.0,
        "asymmetry": 1.0,
        "bevel": 0.0015,             # real manufacturing radii
        "bevel_segments": 3,
        "smooth_iters": 4,
        "surface": "micro",
        "variation": 0.08,
        "wear": 0.6,
        "micro": 1.0,
        "fingerprints": 1.0,
        "glass_smudge": 0.14,
        "dust": 1.0,
        "brushed_metal": 1.0,
        "velvet_fuzz": 1.0,
        "micro_normal": 1.5,
        "fabric_weave_scale": 1.6, "fabric_weave_strength": 1.5,
        "caustics": True,
        "posterize": 0,
        "saturation": 0.92,
        "skin_sss": 1.0, "skin_sss_scale": 0.006, "skin_rough": 0.42,
        "outline": 0.0,
        "rig": "softbox_bounce",
        "world_strength": 0.15,
        "world_color": (0.62, 0.66, 0.72),
        "exposure": 0.0,
        "look": "AgX - Base Contrast",
        "samples": 96,
        "dof_fstop": 2.8,
        "bloom": 0.05,
        "grade": {"contrast": 1.12, "saturation": 0.98, "lift": (0.004, 0.004, 0.005),
                  "gain": (1.0, 1.0, 0.99), "vignette": 0.22, "grain": 0.022,
                  "chroma_ab": 1.2, "curve_toe": 0.0},
    },
}

# Glasshouse heist palette (style_guide §3), sRGB hex.
PALETTE = {
    "ivory": "#E8DCC8",
    "walnut": "#5A3B28",
    "brass": "#C9A227",
    "neon_magenta": "#FF3EA5",
}


def get(style_id: str) -> dict:
    if style_id not in STYLES:
        raise SystemExit(f"unknown style {style_id!r}; expected one of {STYLE_IDS}")
    return STYLES[style_id]
