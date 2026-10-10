"""Greybox floor tiles (0.2 m slab, top at z=0) and ceiling tiles (0.05 m, underside at z=0) (C1-02).

Origin at a corner; tiles extend over +X and +Y (Blender) = +X and -Z (Godot).
"""

import _kit

TRI_BUDGET = 500
SIZES_CM = (100, 200, 400)
VARIANTS = {
    **{f"arch_floor_w{s}": {"kind": "floor", "size": s / 100} for s in SIZES_CM},
    **{f"arch_ceiling_w{s}": {"kind": "ceiling", "size": s / 100} for s in SIZES_CM},
}


def build(ctx) -> None:
    if ctx.params["kind"] == "floor":
        _kit.floor_tile(ctx, ctx.params["size"])
    else:
        _kit.ceiling_tile(ctx, ctx.params["size"])
