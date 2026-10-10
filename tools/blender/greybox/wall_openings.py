"""Greybox walls with door / window / shopfront openings (C1-02).

Openings (x0, x1, z0, z1) in metres from the wall origin. Door openings are leaf + frame:
single 1.0 x 2.2 (0.9 x 2.1 leaf), double 2.0 x 2.2 (1.8 x 2.1), service 1.2 x 2.2 (1.1 x 2.1),
all centred in the module. Windows: sill 0.9, head 2.1. Shopfront: sill 0.3, head 2.7.
Fill them with the matching arch_door_* / arch_window_* asset placed at the opening's
bottom-centre: x = (x0 + x1) / 2, z = z0, on the wall centreline.
"""

import _kit

TRI_BUDGET = 500
HEIGHTS_CM = (300, 350, 400)
OPENINGS = {
    "door": (200, [(0.5, 1.5, 0.0, 2.2)]),
    "door_double": (400, [(1.0, 3.0, 0.0, 2.2)]),
    "door_service": (200, [(0.4, 1.6, 0.0, 2.2)]),
    "window": (200, [(0.5, 1.5, 0.9, 2.1)]),
    "window_wide": (400, [(0.5, 3.5, 0.9, 2.1)]),
    "shop": (400, [(0.5, 3.5, 0.3, 2.7)]),
}
VARIANTS = {
    f"arch_wall_{kind}_{name}_w{w}_h{h}": {
        "width": w / 100, "height": h / 100, "thickness": t, "exterior": kind == "ext", "openings": ops,
    }
    for kind, t in (("int", 0.2), ("ext", 0.4))
    for name, (w, ops) in OPENINGS.items()
    if not (name == "shop" and kind == "int")
    for h in HEIGHTS_CM
}


def build(ctx) -> None:
    p = ctx.params
    _kit.wall(ctx, p["width"], p["height"], p["thickness"], p["exterior"], [tuple(o) for o in p["openings"]])
