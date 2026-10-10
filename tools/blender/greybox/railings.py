"""Greybox railing 1.05 m (level_standards §2.6): posts <= 1 m apart, top rail, mid rail.

Origin: bottom of the start end, centred on the rail line; runs along +X.
"""

import _kit

TRI_BUDGET = 500
VARIANTS = {f"arch_railing_w{w}": {"length": w / 100} for w in (100, 200)}


def build(ctx) -> None:
    _kit.railing(ctx, ctx.params["length"])
