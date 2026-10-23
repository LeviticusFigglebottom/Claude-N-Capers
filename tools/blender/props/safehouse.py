"""Safehouse "The Press" (docs/design/heists/safehouse.md, C4-03): the catalogue fixtures and vehicle the G2 pass stood
in for. ENV D builds the hero props (the Old Press, the jukebox, the Board's map, ...: prop_sh_*). Library materials only.
Blender +Y = Godot -Z; floor pivots (bottom-centre), ceiling fixtures with their top at z = 0.

* ``prop_sh_pendant_enamel``: the print-works green-enamel pendant (#2F4A3E shade, 2700 K), a 2.3 m drop for the hall's
  5 m ceiling (the lamp hangs at ~2.6 m over the planning table and the press).
* ``prop_sh_work_light``: the loading bay's LED work light on a tripod stand (5000 K, the head 1.8 m up, aimed down).
* ``veh_sh_crew_van``: the crew van, backed in under the roller door with both rear doors open (the secure van's
  generator, prefab_visuals._van, with ``doors_open_deg``).
"""

from __future__ import annotations

import math

from _pb import Kit
from prefab_visuals import _van

TRI_BUDGET = 12000
K2700 = "#FFA95E"
K5000 = "#FFF0E3"
VARIANTS = {
    "prop_sh_pendant_enamel": {"fn": "pendant_enamel", "cat": {
        "kind": "light_fixture", "place": "ceiling", "fixture": True, "group": "safehouse", "pin_only": True,
        "light": {"type": "omni", "color": K2700, "energy": 2.0, "range": 6.0, "pos": [0.0, -2.43, 0.0]}}},
    "prop_sh_work_light": {"fn": "work_light", "cat": {
        "kind": "light_fixture", "place": "floor", "fixture": True, "group": "safehouse", "pin_only": True,
        "light": {"type": "spot", "color": K5000, "energy": 1.6, "range": 7.0, "angle": 55, "pos": [0.0, 1.7, 0.06]}}},
    "veh_sh_crew_van": {"fn": "crew_van", "doors_open_deg": 100.0, "cat": {
        "kind": "vehicle", "group": "safehouse", "place": "none", "surface": "metal", "pin_only": True}},
}


def _pendant_enamel(k: Kit, p: dict) -> None:
    """Green-enamel factory pendant: ceiling rose, a 2.3 m chain-like rod, a shallow enamel cone with a white inside and
    a warm lamp under it."""
    drop = 2.3
    o = k.obj("Pendant")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, -0.05), (0.07, -0.05), (0.08, -0.02), (0.08, 0.0), (0.0, 0.0)], "metal_dark", segs=16)
    a.rod((0.0, 0.0, -0.05), (0.0, 0.0, -drop), 0.008, "metal_dark", segs=6)
    a.cyl(0.035, 0.08, (0.0, 0.0, -drop - 0.03), "metal_dark", segs=12)
    # the shade: green enamel outside, white enamel inside (two shells 4 mm apart, no coplanar faces)
    a.lathe([(0.03, -drop - 0.06), (0.12, -drop - 0.1), (0.24, -drop - 0.2), (0.27, -drop - 0.24),
             (0.266, -drop - 0.244), (0.0, -drop - 0.244)], "sh_enamel_green", segs=28)
    w = o.part(bevel=0.0)
    w.lathe([(0.0, -drop - 0.07), (0.115, -drop - 0.105), (0.235, -drop - 0.205), (0.26, -drop - 0.236),
             (0.0, -drop - 0.236)], "metal_white", segs=28)
    e = o.part(bevel=0.0)
    e.sphere(0.055, (0.0, 0.0, -drop - 0.13), "emit_warm", segs=12, rings=6)
    o.build()


def _work_light(k: Kit, p: dict) -> None:
    """LED work light on a tripod: three splayed legs, a telescopic pole, a yoke and a finned rectangular head with an
    emissive lens."""
    o = k.obj("Stand")
    a = o.part(bevel=0.0)
    hub = (0.0, 0.0, 0.55)
    for i in range(3):
        ang = 2 * math.pi * i / 3 + math.pi / 2
        a.rod(hub, (math.cos(ang) * 0.42, math.sin(ang) * 0.42, 0.0075), 0.012, "safety_orange", segs=6)  # feet on the floor
    a.rod((0.0, 0.0, 0.4), (0.0, 0.0, 1.2), 0.018, "metal_dark", segs=8)
    a.rod((0.0, 0.0, 1.2), (0.0, 0.0, 1.68), 0.013, "steel", segs=8)
    a.bx((-0.13, -0.015, 1.66), (0.13, 0.015, 1.7), "metal_dark")
    for sx in (-1, 1):
        a.bx((sx * 0.13 - 0.01, -0.015, 1.66), (sx * 0.13 + 0.01, 0.015, 1.82), "metal_dark")
    h = o.part(bevel=0.004)
    # head: 0.24 x 0.1 x 0.14 over the pole at 1.79 m, its lens on Blender -Y (Godot +Z); the light aims down
    h.bx((-0.12, -0.05, 1.72), (0.12, 0.05, 1.86), "metal_dark")
    for i in range(5):
        x = -0.1 + 0.05 * i
        h.bx((x - 0.004, 0.05, 1.74), (x + 0.004, 0.08, 1.84), "metal_dark")
    e = o.part(bevel=0.0)
    e.bx((-0.105, -0.056, 1.735), (0.105, -0.05, 1.845), "emit_cool")
    o.build()


def _crew_van(k: Kit, p: dict) -> None:
    _van(k, p)


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
