"""Greybox columns 0.4 m (square and round), heights 3.0/3.5/4.0 m. Origin: bottom-centre."""

import _kit

TRI_BUDGET = 500
VARIANTS = {
    f"arch_column_{tag}40_h{h}": {"shape": shape, "size": 0.4, "height": h / 100}
    for tag, shape in (("sq", "square"), ("rd", "round"))
    for h in (300, 350, 400)
}


def build(ctx) -> None:
    p = ctx.params
    _kit.column(ctx, p["shape"], p["size"], p["height"])
