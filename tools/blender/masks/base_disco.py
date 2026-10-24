"""Disco customisable base mask (``mask_base.disco``, D-165 Afterhours reward: "Closing Time").

An original club mask after the Velvet's mirror ball: a rounded face tiled all over with small square
mirror tiles on a grid, each a raised plate with a chamfered edge, the grout lines between them sunk to
the shell. The tiles stop short of the shell edge and of the round eye holes and the small round mouth,
leaving a clean border round each opening. With a chrome or gold material the tile grid catches the light
like the ball; the regular grid is the read at distance.

Materials: a single ``M_char_mask_base`` slot (masks.md: one surface, material_override).
UV0: front planar projection normalised to the mask bounds (``_mask_base.front_project``).
Pivot: the face centre (see ``_mask_base``); Blender +Y (= Godot -Z) forward.
"""

import _mask_base as mask

ASSET_ID = "mask_base_disco"
TRI_BUDGET = 8000
PARAMS = {
    "coverage": "full",
    "top": 0.102,
    "bottom": -0.112,
    "side_arc": 0.102,
    "jaw_taper": 0.18,
    "brow": 0.6,
    "cheek": 0.8,
    "nose": 0.6,
    "jaw": 0.8,
    "eye_shape": "round",
    "eye_width": 0.030,
    "eye_height": 0.021,
    "eye_spacing": 0.068,
    "eye_tilt_deg": 0.0,
    "mouth": "open",
    "mouth_width": 0.022,
    "mouth_height": 0.012,
    "mouth_v": -0.070,
    "res": 0.0085,
    "res_back": 0.015,
    "edge_res": 0.0050,
}

PITCH = 0.016          # tile grid pitch (m, in face u/v)
TILE = 0.0135          # tile side; the rest is the grout line
ORIGIN = (0.0, -0.004)  # a grid line runs down the face centre
EDGE_CLEAR = 0.005     # tiles stop this far inside the outline
HOLE_CLEAR = 0.004     # and this far from the eye / mouth holes


def _tiles(kit: mask.MaskKit) -> None:
    """Every grid tile whose four corners clear the outline border and the holes."""
    inside = mask.offset_loop(mask.oriented(kit.shape.outline(), True), EDGE_CLEAR)
    holes = [mask.offset_loop(mask.oriented(h, True), -HOLE_CLEAR) for h in kit.shape.holes()]
    h = TILE / 2
    n = int(0.13 / PITCH) + 1
    for j in range(-n, n + 1):
        for i in range(-n, n + 1):
            # the grid is centred on a grout line: tile centres at half-pitch offsets
            cu, cv = ORIGIN[0] + (i + 0.5) * PITCH, ORIGIN[1] + (j + 0.5) * PITCH
            corners = [(cu - h, cv - h), (cu + h, cv - h), (cu + h, cv + h), (cu - h, cv + h)]
            if not all(mask.point_in_loop(c, inside) for c in corners):
                continue
            if any(mask.point_in_loop(c, ho) for c in corners + [(cu, cv)] for ho in holes):
                continue
            kit.plate(corners, hi=0.0016, chamfer=0.0005, edge_res=TILE)


def build(ctx) -> None:
    mask.build_mask(ctx, ctx.params, mask.base_materials(ctx), ornaments=[_tiles], uv_mode="front")
