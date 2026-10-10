"""Greybox stairs generated from the floor-to-floor height (C1-02, level_standards §2.6-7).

Riser count n = ceil(f2f / 0.19) so the riser is f2f / n exactly (0.15-0.19 m); tread 0.28 m;
width 1.2 m; at most 16 risers per flight. Layouts: straight (only if n <= 16), landing (two
straight flights with a 1.2 m mid landing) and u (two 1.2 m flights side by side, 0.1 m gap, half
landing). Origin: bottom of the first riser, centred on the (first) flight; climbs towards +Y
(Godot -Z). The last tread is flush with the upper floor. Collision is a smooth ramp.
"""

import _kit

TRI_BUDGET = 500
F2F_CM = (300, 350, 400, 450)
VARIANTS = {
    "arch_stair_straight_f300": {"floor_to_floor": 3.0, "layout": "straight"},
    **{f"arch_stair_landing_f{f}": {"floor_to_floor": f / 100, "layout": "landing"} for f in F2F_CM},
    **{f"arch_stair_u_f{f}": {"floor_to_floor": f / 100, "layout": "u"} for f in F2F_CM},
}


def build(ctx) -> None:
    facts = _kit.stair(ctx, ctx.params["floor_to_floor"], ctx.params["layout"])
    ctx.source_extra.update(facts)
