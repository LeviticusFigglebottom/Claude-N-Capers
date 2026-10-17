"""Laser security (D-111 item 10, Shadow Ledger SL-2): the emitter column and the beam sets of a laser grid.
Original models; no third-party assets. Blender +Y = Godot -Z, +Z up.

* ``prop_laser_emitter_column``: a 2.7 m floor-to-near-ceiling emitter column, 0.15 (X) x 0.12 m, the shape of
  Shadow Ledger's art-hall `LaserEmitters` collision (the map's StaticBody owns the collider; this visual has
  none). Black anodised extrusion on a brushed-steel plinth, a smoked-glass lens window down its +X face with
  the red emitter heads behind it, a top cap with a status LED and a key switch on the -Y side. Pivot on the
  floor at the footprint centre; the lens face looks along +X (turn the far column 180 degrees).
* ``prop_laser_beams_*`` (`laser_grid` visual, visual_slots.md v1.1): `Beam0..n-1` red emissive rods that the
  LaserGrid moves and shows / hides. Horizontal sets (static / timed_off) are rods along X of `len`, authored
  stacked on the floor (A places each at its beam height on ready); vertical sets (sweeping) are `len` tall
  rods centred `len / 2` up (A places each at (x, size_m.y / 2, 0)). No posts: the map's emitter columns carry
  them. The ids name the length in cm and the beam count.
"""

from _pb import Kit

TRI_BUDGET = 8000
_BEAMS = {"prefab": "laser_grid", "kind": "laser_beams", "surface": "glass"}
VARIANTS = {
    "prop_laser_emitter_column": {"fn": "column", "h": 2.7, "w": 0.15, "d": 0.12,
                                  "cat": {"kind": "laser_emitter", "place": "none", "surface": "metal", "group": "security"}},
    "prop_laser_beams_h688x3": {"fn": "beams", "len": 6.88, "n": 3, "vertical": False, "cat": _BEAMS},
    "prop_laser_beams_h688x4": {"fn": "beams", "len": 6.88, "n": 4, "vertical": False, "cat": _BEAMS},
    "prop_laser_beams_v260x3": {"fn": "beams", "len": 2.6, "n": 3, "vertical": True, "cat": _BEAMS},
}
BEAM_R = 0.007


def _column(k: Kit, p: dict) -> None:
    h, hw, hd = p["h"], p["w"] / 2, p["d"] / 2
    o = k.obj("Column")
    body = o.part(bevel=0.01, segments=2)
    body.bx((-hw + 0.004, -hd + 0.004, 0.07), (hw - 0.004, hd - 0.004, h - 0.06), "alu_black")
    base = o.part(bevel=0.006, segments=1)
    base.bx((-hw, -hd, 0.0), (hw, hd, 0.07), "steel")
    base.bx((-hw, -hd, h - 0.06), (hw, hd, h), "steel")
    trim = o.part(bevel=0.0)
    # recessed lens window on the +X face (0.25 .. h - 0.2), smoked glass over red emitter heads
    x0 = hw - 0.004
    trim.bx((x0 - 0.002, -0.032, 0.25), (x0 + 0.002, 0.032, h - 0.2), "metal_dark")
    trim.bx((x0 + 0.002, -0.026, 0.27), (x0 + 0.005, 0.026, h - 0.22), "glass_tinted")
    z = 0.32
    while z < h - 0.24:
        trim.cyl(0.011, 0.004, (x0 + 0.004, 0.0, z), "emit_led_red", axis="X", segs=10)
        z += 0.1
    # plinth bolts, top status LED, key switch and a service label on the -Y side
    for sx in (-1, 1):
        for sy in (-1, 1):
            trim.cyl(0.008, 0.006, (sx * (hw - 0.02), sy * (hd - 0.02), 0.073), "steel_bare", segs=6)
    trim.cyl(0.009, 0.004, (0.0, 0.0, h + 0.002), "emit_led_green", segs=10)
    ky = -hd + 0.004
    trim.bx((-0.035, ky - 0.004, 1.05), (0.035, ky, 1.17), "steel")
    trim.cyl(0.012, 0.008, (0.0, ky - 0.008, 1.11), "brass", axis="Y", segs=10)
    trim.bx((-0.04, ky - 0.002, 1.3), (0.04, ky, 1.36), "plastic_white")
    o.build()


def _beams(k: Kit, p: dict) -> None:
    ln, n = p["len"], p["n"]
    for i in range(n):
        if p["vertical"]:
            beam = k.obj("Beam%d" % i, location=(0.0, 0.0, ln / 2))
            beam.part(bevel=0.0).rod((0.0, 0.0, -ln / 2), (0.0, 0.0, ln / 2), BEAM_R, "emit_led_red", segs=6)
        else:
            beam = k.obj("Beam%d" % i, location=(0.0, 0.0, BEAM_R))
            beam.part(bevel=0.0).rod((-ln / 2, 0.0, 0.0), (ln / 2, 0.0, 0.0), BEAM_R, "emit_led_red", segs=6)
        beam.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
