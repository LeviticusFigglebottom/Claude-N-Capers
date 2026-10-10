"""Greybox window visuals for the `window` prefab: Frame + Glass (contracts/visual_slots.md).

Origin: bottom-centre of the opening (the sill) on the wall centreline; frame depth 0.1 m centred.
No collision (the window prefab owns it). Mullions every <= 1.5 m.
"""

import _kit

TRI_BUDGET = 500
VARIANTS = {
    "arch_window_w100_h120": {"width": 1.0, "height": 1.2},
    "arch_window_w300_h120": {"width": 3.0, "height": 1.2},
    "arch_window_shop_w300_h240": {"width": 3.0, "height": 2.4},
}


def build(ctx) -> None:
    _kit.window(ctx, ctx.params["width"], ctx.params["height"])
