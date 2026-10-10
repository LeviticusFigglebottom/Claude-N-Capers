"""Heron customisable base mask (``mask_base.heron``, QB-50b).

The plain member of the heron family (see ``gilded_heron.py``): the same full-face shell, faceted
dagger beak, stepped feather plates over the brows and cheeks and the crest keel, but without the
gilded ornament (no lacquer eye bands, no chin chevrons, no two-tone keel). One colour-neutral
surface, tinted at runtime by the mask shader (color_a/color_b + pattern over UV0).

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import _mask_base as mask
import gilded_heron as heron

ASSET_ID = "mask_base_heron"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.098,
    "top_peak": 0.024,
    "bottom": -0.114,
    "chin_point": 0.012,
    "side_arc": 0.108,
    "jaw_taper": 0.34,
    "brow": 1.3,
    "cheek": 0.8,
    "nose": 0.4,
    "jaw": 1.0,
    "eye_shape": "almond",
    "eye_width": 0.036,
    "eye_height": 0.017,
    "eye_tilt_deg": 9.0,
    "mouth": "none",
    "res": 0.010,
    "res_back": 0.016,
    # ornaments (shared with gilded_heron)
    "beak_tip": (0.0, 0.135, -0.070),
    "beak_root_top": 0.010,
    "beak_root_bottom": -0.056,
    "beak_half_width": 0.0155,
}


def _eye_rims(kit: mask.MaskKit) -> None:
    """A thin sculpted lid rim around each eye in place of the gilded lacquer band."""
    eye = mask.oriented(kit.shape.eye_hole(1), True)
    inner = mask.offset_loop(eye, -0.0012)
    outer = mask.offset_loop(eye, -0.0055)
    for o, h in ((outer, inner), (mask.mirror(outer), mask.mirror(inner))):
        kit.plate(o, holes=[h], hi=0.0014, chamfer=0.0005, edge_res=0.004)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx),
                    ornaments=[_eye_rims, heron._brow_feathers, heron._cheek_feathers, heron._crest, heron._beak],
                    uv_mode="front")
