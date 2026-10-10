"""Greybox plain walls (C1-02): interior 0.2 m / exterior 0.4 m, widths 0.5/1/2/4 m, heights 3.0/3.5/4.0 m.

Origin: bottom of the start end on the wall centreline; the wall runs along +X (see _kit.py).
"""

import _kit

TRI_BUDGET = 500
WIDTHS_CM = (50, 100, 200, 400)
HEIGHTS_CM = (300, 350, 400)
VARIANTS = {
    f"arch_wall_{kind}_w{w}_h{h}": {"width": w / 100, "height": h / 100, "thickness": t, "exterior": kind == "ext"}
    for kind, t in (("int", 0.2), ("ext", 0.4))
    for w in WIDTHS_CM
    for h in HEIGHTS_CM
}


def build(ctx) -> None:
    p = ctx.params
    _kit.wall(ctx, p["width"], p["height"], p["thickness"], p["exterior"])
