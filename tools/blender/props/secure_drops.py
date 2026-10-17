"""Bag-secure drop points that are not vehicles (D-111 item 7, Shadow Ledger SL-2; gameplay_prefabs.md
`secure_zone`, visual_slots.md: `Body`, `DoorL`, `DoorR` (pivots), `DropAnchor`).

The secure_zone prefab is a SECURE_LOOT box centred on its pivot (the centre of the floor footprint); these
visuals mark where bags go and are low lying, so the map keeps `vehicle_collision = false` (no collider, no
navmesh change; walk over them). Blender +Y = Godot -Z. `DoorL` / `DoorR` are plain pivots at the two ends
(nothing opens); `DropAnchor` sits 0.1 m over the middle.

* ``prop_secure_cargo_net``: E1 heli pad, a 3.6 m square helicopter cargo net laid out flat (tan rope mesh,
  0.3 m squares, knotted crossings, a heavy perimeter rope) with its four orange lifting legs gathered to the
  master ring and swivel hook, ready to be hooked under the escape heli. The perimeter rope rests on the slab
  (pivot height) and sinks 2 cm into a painted pad deck (SL HelipadDeck 0 .. 0.02) so the net reads on top of it.
* ``prop_secure_line_tarp``: E2 bag line, the crew's rigging tarp at the anchor: an olive canvas groundsheet
  (1.6 x 1.2 m, hemmed, brass grommets) with three orange bag strops and their carabiners laid out, a spare line
  trolley and a coil of rope: bags dropped here are clipped onto the line to Vantage House.
* ``prop_secure_lift_blanket``: E3 service lift, quilted freight blankets spread on the car floor (teal, as the
  escape fit-out's wall pads) with a folded stack at the back and a ratchet strap: the drop inside the car. It is
  26 mm thick, so it covers the fit-out's chequer plate (0 .. 0.013) when that appears.
"""

import math

from _pb import Kit

TRI_BUDGET = 8000
_SZ = {"prefab": "secure_zone", "surface": "fabric"}
VARIANTS = {
    "prop_secure_cargo_net": {"fn": "cargo_net", "half": 1.8, "cell": 0.3, "cat": {**_SZ, "kind": "cargo_net"}},
    "prop_secure_line_tarp": {"fn": "line_tarp", "cat": {**_SZ, "kind": "drop_tarp"}},
    "prop_secure_lift_blanket": {"fn": "lift_blanket", "cat": {**_SZ, "kind": "drop_blanket"}},
}


def _markers(k: Kit, half_x: float, z: float) -> None:
    k.empty("DoorL", (-half_x, 0.0, z))
    k.empty("DoorR", (half_x, 0.0, z))
    k.empty("DropAnchor", (0.0, 0.0, 0.1))


# ------------------------------------------------------------------------------------ E1 cargo net

def _cargo_net(k: Kit, p: dict) -> None:
    h, cell = p["half"], p["cell"]
    n = int(round(2 * h / cell))
    zr = 0.026        # mesh rope centre: 6 mm proud of a 2 cm pad deck
    rr = 0.009
    o = k.obj("Body")
    rope = o.part(bevel=0.0)
    knots = o.part(bevel=0.0)
    for i in range(1, n):
        c = -h + i * cell
        rope.rod((-h, c, zr), (h, c, zr), rr, "rope_tan", segs=5)
        rope.rod((c, -h, zr + 0.004), (c, h, zr + 0.004), rr, "rope_tan", segs=5)
        for j in range(1, n):
            knots.cbox((-h + j * cell, c, zr + 0.002), (0.034, 0.034, 0.026), "rope_tan")
    # perimeter rope, resting on the slab
    rim = o.part(bevel=0.0)
    pr = 0.024
    corners = [(-h, -h, pr), (h, -h, pr), (h, h, pr), (-h, h, pr)]
    rim.tube(corners, pr, "rope_tan", segs=8, closed=True)
    # lifting legs: corner thimbles, orange webbing legs gathered toward the master ring off-centre
    ring = (0.55, -0.35, 0.05)
    legs = o.part(bevel=0.0)
    hard = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (h - 0.02), sy * (h - 0.02)
            hard.torus(0.045, 0.011, (cx, cy, 0.05), "steel", segs=12, rsegs=4, axis="Z")
            # the leg lies over the net in two straight runs with a slight sag point
            mx, my = cx * 0.45 + ring[0] * 0.55, cy * 0.45 + ring[1] * 0.55
            legs.rod((cx - sx * 0.04, cy - sy * 0.04, 0.052), (mx, my, 0.05), 0.022, "paint_hazard_orange", segs=4, square=True)
            legs.rod((mx, my, 0.05), (ring[0] + sx * 0.05, ring[1] + sy * 0.05, 0.058), 0.022, "paint_hazard_orange",
                     segs=4, square=True)
    # master ring and a swivel hook lying beside it
    hard.torus(0.1, 0.018, ring, "steel", segs=20, rsegs=6, axis="Z")
    hard.cbox((ring[0] + 0.19, ring[1], 0.055), (0.12, 0.05, 0.03), "metal_yellow")
    hard.torus(0.05, 0.013, (ring[0] + 0.3, ring[1], 0.05), "steel", segs=14, rsegs=5, axis="Z", arc=1.6 * math.pi)
    # two coiled ratchet straps at the edge of the net
    strap = o.part(bevel=0.0)
    for x, y in ((-1.2, h - 0.3), (-0.6, h - 0.3)):
        for t in range(4):
            strap.torus(0.12 - t * 0.02, 0.012, (x, y, 0.048 + t * 0.002), "metal_yellow", segs=16, rsegs=4, axis="Z")
        strap.cbox((x + 0.13, y, 0.06), (0.1, 0.06, 0.04), "steel")
    o.build()
    _markers(k, h, 0.05)


# ------------------------------------------------------------------------------------ E2 line tarp

def _line_tarp(k: Kit, p: dict) -> None:
    hx, hy, t = 0.8, 0.6, 0.012
    o = k.obj("Body")
    sheet = o.part(bevel=0.004)
    sheet.bx((-hx, -hy, 0.0), (hx, hy, t), "bag_olive")
    hem = o.part(bevel=0.0)
    for sy in (-1, 1):
        y0, y1 = sorted((sy * hy, sy * (hy - 0.05)))
        hem.bx((-hx, y0, t), (hx, y1, t + 0.003), "bag_olive")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hx, sx * (hx - 0.05)))
        hem.bx((x0, -hy + 0.05, t), (x1, hy - 0.05, t + 0.003), "bag_olive")
    grom = o.part(bevel=0.0)
    for gx in (-hx + 0.03, -0.27, 0.27, hx - 0.03):
        for gy in (-hy + 0.03, hy - 0.03):
            grom.torus(0.012, 0.004, (gx, gy, t + 0.004), "brass", segs=10, rsegs=4, axis="Z")
    # three bag strops (orange webbing loops) laid out side by side, each with a carabiner
    gear = o.part(bevel=0.0)
    for i, x in enumerate((-0.45, 0.0, 0.45)):
        y0 = -0.32
        loop = [(x - 0.08, y0, t + 0.012), (x - 0.06, y0 + 0.5, t + 0.012), (x + 0.06, y0 + 0.5, t + 0.012),
                (x + 0.08, y0, t + 0.012)]
        gear.tube(loop, 0.012, "paint_hazard_orange", segs=4, closed=True)
        gear.torus(0.035, 0.007, (x, y0 - 0.05, t + 0.008), "steel", segs=12, rsegs=4, axis="Z",
                   arc=1.75 * math.pi)
        gear.cbox((x, y0 - 0.088, t + 0.008), (0.018, 0.02, 0.012), "metal_dark")
    # spare line trolley (yellow side plates, twin sheaves) lying flat
    tx, ty = 0.55, 0.38
    for sx in (-0.03, 0.03):
        gear.bx((tx - 0.07, ty + sx - 0.006, t), (tx + 0.07, ty + sx + 0.006, t + 0.11), "metal_yellow")
    for wx in (-0.04, 0.04):
        gear.cyl(0.03, 0.05, (tx + wx, ty, t + 0.055), "metal_dark", axis="Y", segs=10)
    # rope coil (a few stacked turns)
    rope = o.part(bevel=0.0)
    for j in range(5):
        rope.torus(0.17 - (j % 2) * 0.015, 0.011, (-0.5, 0.33, t + 0.011 + j * 0.02), "rope_tan", segs=20,
                   rsegs=5, axis="Z")
    o.build()
    _markers(k, hx, 0.05)


# ------------------------------------------------------------------------------- E3 lift blanket

def _lift_blanket(k: Kit, p: dict) -> None:
    z0 = 0.0
    hx, hy, t = 0.85, 0.65, 0.026
    o = k.obj("Body")
    pad = o.part(bevel=0.008, segments=2)
    pad.bx((-hx, -hy, z0), (hx, hy, z0 + t), "canvas_teal")
    seams = o.part(bevel=0.0)
    for i in range(1, 6):
        x = -hx + i * (2 * hx / 6)
        seams.bx((x - 0.006, -hy + 0.04, z0 + t), (x + 0.006, hy - 0.04, z0 + t + 0.002), "fabric_charcoal")
    for y in (-hy + 0.03, hy - 0.03):
        seams.bx((-hx + 0.03, y - 0.008, z0 + t), (hx - 0.03, y + 0.008, z0 + t + 0.002), "fabric_charcoal")
    # folded stack toward the car's back wall (-X; the opening is on +X, as the escape fit-out)
    stack = o.part(bevel=0.012, segments=2)
    sx0 = -hx + 0.05
    for j in range(3):
        zz = z0 + t + j * 0.045
        stack.bx((sx0, -0.45 + j * 0.01, zz), (sx0 + 0.42, 0.4 - j * 0.01, zz + 0.045), "canvas_teal")
    # ratchet strap coil on the front corner
    strap = o.part(bevel=0.0)
    for j in range(3):
        strap.torus(0.1 - j * 0.02, 0.011, (0.55, -0.38, z0 + t + 0.011 + j * 0.002), "metal_yellow", segs=16, rsegs=4,
                    axis="Z")
    strap.cbox((0.68, -0.38, z0 + t + 0.016), (0.09, 0.05, 0.03), "steel")
    o.build()
    _markers(k, hx, z0 + 0.05)


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
