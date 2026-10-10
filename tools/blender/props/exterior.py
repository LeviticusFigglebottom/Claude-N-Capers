"""Exterior dressing (exterior_street, exterior_alley): street lamp, bins, bus shelter, bollards,
parked cars, HVAC condenser, barriers, the magenta neon "VOSSBERG" sign, awning, wall lamp,
planter. Floor props: bottom-centre pivot, front +Y (Godot -Z); wall-mounted: back at y = 0,
centred vertically on the origin.
"""

import math

from _pb import Kit, lettering

TRI_BUDGET = 14000
LED = "#FFD9B0"
VARIANTS = {
    "prop_street_lamp": {"fn": "street_lamp", "cat": {"kind": "street_lamp", "place": "row", "standoff": 3.4, "fixture": True, "group": "exterior",
                                                      "light": {"type": "spot", "color": LED, "energy": 6.0, "range": 14.0, "angle": 60, "pos": [0.0, 5.75, -1.3]}}},
    "prop_bin_street": {"fn": "bin_street", "cat": {"kind": "bin_street", "place": "row", "standoff": 2.9, "group": "exterior"}},
    "prop_bus_shelter": {"fn": "bus_shelter", "cat": {"kind": "bus_shelter", "place": "row", "standoff": 2.2, "fixture": True, "group": "exterior",
                                                      "light": {"type": "omni", "color": LED, "energy": 1.0, "range": 4.0, "pos": [0.0, 2.3, 0.0]}}},
    "prop_bollard_steel": {"fn": "bollard", "steel": True, "cat": {"kind": "bollard", "place": "row", "standoff": 3.7, "group": "exterior"}},
    "prop_bollard_concrete": {"fn": "bollard", "steel": False, "cat": {"kind": "bollard", "place": "row", "standoff": 3.7, "group": "exterior"}},
    "veh_car_sedan_wine": {"fn": "car", "paint": "car_wine", "cat": {"kind": "car", "place": "row", "standoff": 5.2, "group": "exterior"}},
    "veh_car_sedan_navy": {"fn": "car", "paint": "car_navy", "cat": {"kind": "car", "place": "row", "standoff": 5.2, "group": "exterior"}},
    "veh_car_sedan_silver": {"fn": "car", "paint": "car_silver", "cat": {"kind": "car", "place": "row", "standoff": 5.2, "group": "exterior"}},
    "prop_hvac_condenser": {"fn": "hvac", "cat": {"kind": "hvac", "place": "wall", "group": "exterior"}},
    "prop_barrier_jersey": {"fn": "jersey", "cat": {"kind": "barrier", "place": "row", "standoff": 4.5, "group": "exterior"}},
    "prop_barrier_roadworks": {"fn": "roadworks", "cat": {"kind": "barrier", "place": "row", "standoff": 4.5, "group": "exterior"}},
    "prop_neon_vossberg": {"fn": "neon", "cat": {"kind": "neon_sign", "place": "wall_mount", "z": 3.6, "fixture": True, "group": "exterior",
                                                 "light": {"type": "omni", "color": "#FF3EA5", "energy": 2.5, "range": 7.0, "pos": [0.0, 0.0, -0.6]}}},
    "prop_awning": {"fn": "awning", "cat": {"kind": "awning", "place": "wall_mount", "z": 2.75, "group": "exterior"}},
    "prop_wall_lamp": {"fn": "wall_lamp", "cat": {"kind": "wall_lamp", "place": "wall_mount", "z": 2.4, "fixture": True, "group": "exterior",
                                                  "light": {"type": "omni", "color": "#FFC58F", "energy": 1.2, "range": 6.0, "pos": [0.0, -0.1, -0.2]}}},
    "prop_planter_street": {"fn": "planter", "cat": {"kind": "planter", "place": "row", "standoff": 0.9, "group": "exterior"}},
}


def _street_lamp(k: Kit, p: dict) -> None:
    o = k.obj("Lamp")
    a = o.part(bevel=0.0)
    a.lathe([(0.16, 0.0), (0.16, 0.05), (0.12, 0.08), (0.1, 0.6), (0.075, 0.65), (0.06, 5.9), (0.0, 5.9)], "metal_dark", segs=16)
    a.rod((0.0, 0.0, 5.6), (0.0, 1.0, 5.95), 0.04, "metal_dark", segs=10)
    a.rod((0.0, 1.0, 5.95), (0.0, 1.3, 5.92), 0.035, "metal_dark", segs=10)
    h = o.part(bevel=0.01, segments=2)
    h.bx((-0.16, 1.05, 5.82), (0.16, 1.6, 5.94), "metal_dark")
    e = o.part(bevel=0.0)
    e.bx((-0.13, 1.1, 5.815), (0.13, 1.55, 5.82), "emit_neutral")
    a.bx((-0.08, -0.1, 2.4), (0.08, -0.06, 2.6), "metal_grey")
    o.build()
    k.collision([], cylinders=[(0.12, 5.9, (0.0, 0.0, 2.95))])


def _bin_street(k: Kit, p: dict) -> None:
    o = k.obj("Bin")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, 0.0), (0.26, 0.0), (0.26, 0.9), (0.28, 0.92), (0.28, 0.98), (0.0, 1.0)], "metal_dark", segs=20)
    for i in range(16):
        ang = 2 * math.pi * i / 16
        a.rod((math.cos(ang) * 0.262, math.sin(ang) * 0.262, 0.08), (math.cos(ang) * 0.262, math.sin(ang) * 0.262, 0.86),
              0.008, "metal_dark", segs=4)
    a.bx((-0.12, 0.27, 0.75), (0.12, 0.29, 0.86), "plastic_black")
    o.build()
    k.collision([], cylinders=[(0.28, 1.0, (0.0, 0.0, 0.5))])


def _bus_shelter(k: Kit, p: dict) -> None:
    w, d, h = 3.6, 1.5, 2.5
    o = k.obj("Shelter")
    fr = o.part(bevel=0.004)
    gl = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            fr.bx((sx * w / 2 - 0.04, sy * d / 2 - 0.04, 0.0), (sx * w / 2 + 0.04, sy * d / 2 + 0.04, h), "metal_dark")
    fr.bx((-w / 2 - 0.1, -d / 2 - 0.1, h), (w / 2 + 0.1, d / 2 + 0.25, h + 0.12), "metal_dark")
    gl.bx((-w / 2 - 0.08, -d / 2 - 0.08, h + 0.12), (w / 2 + 0.08, d / 2 + 0.23, h + 0.13), "glass")
    # glass back (Blender -Y) and sides with a mid rail
    gl.bx((-w / 2 + 0.04, -d / 2 - 0.006, 0.15), (w / 2 - 0.04, -d / 2 + 0.006, h - 0.1), "glass")
    for sx in (-1, 1):
        gl.bx((sx * w / 2 - 0.006, -d / 2 + 0.04, 0.15), (sx * w / 2 + 0.006, d / 2 - 0.4, h - 0.1), "glass")
        fr.bx((sx * w / 2 - 0.02, -d / 2, 1.0), (sx * w / 2 + 0.02, d / 2 - 0.4, 1.04), "metal_dark")
    fr.bx((-w / 2, -d / 2 - 0.02, 1.0), (w / 2, -d / 2 + 0.02, 1.04), "metal_dark")
    # bench and the lit advertising panel at one end
    fr.bx((-1.2, -d / 2 + 0.05, 0.45), (0.6, -d / 2 + 0.4, 0.5), "wood_oak")
    for x in (-1.0, 0.4):
        fr.bx((x - 0.03, -d / 2 + 0.1, 0.0), (x + 0.03, -d / 2 + 0.35, 0.45), "metal_dark")
    fr.bx((w / 2 - 0.9, -d / 2 + 0.03, 0.1), (w / 2 - 0.1, -d / 2 + 0.18, 2.0), "metal_dark")
    e = o.part(bevel=0.0)
    e.bx((w / 2 - 0.85, -d / 2 + 0.18, 0.18), (w / 2 - 0.15, -d / 2 + 0.185, 1.92), "emit_neutral")
    art = o.part(bevel=0.0)
    art.bx((w / 2 - 0.8, -d / 2 + 0.186, 0.6), (w / 2 - 0.2, -d / 2 + 0.188, 1.5), "art_blue")
    art.bx((w / 2 - 0.7, -d / 2 + 0.189, 1.0), (w / 2 - 0.3, -d / 2 + 0.19, 1.4), "felt_rose")
    o.build()
    k.collision([((-w / 2 - 0.04, -d / 2 - 0.04, 0.0), (w / 2 + 0.04, -d / 2 + 0.04, h)),
                 ((-w / 2 - 0.1, -d / 2 - 0.1, h), (w / 2 + 0.1, d / 2 + 0.25, h + 0.13))])


def _bollard(k: Kit, p: dict) -> None:
    o = k.obj("Bollard")
    a = o.part(bevel=0.0)
    if p["steel"]:
        a.lathe([(0.0, 0.0), (0.075, 0.0), (0.075, 0.95), (0.06, 1.0), (0.0, 1.01)], "metal_dark", segs=20)
        a.lathe([(0.077, 0.82), (0.077, 0.88), (0.0, 0.88)], "metal_yellow", segs=20)
        k.collision([], cylinders=[(0.075, 1.0, (0.0, 0.0, 0.5))])
    else:
        a.lathe([(0.0, 0.0), (0.22, 0.0), (0.2, 0.75), (0.17, 0.8), (0.0, 0.81)], "concrete_light", segs=24)
        k.collision([], cylinders=[(0.22, 0.8, (0.0, 0.0, 0.4))])
    o.build()


def _car(k: Kit, p: dict) -> None:
    w, ln = 1.8, 4.6
    paint = p["paint"]
    o = k.obj("Car")
    body = o.part(bevel=0.05, segments=3)
    trim = o.part(bevel=0.006)
    glass = o.part(bevel=0.0)
    run = o.part(bevel=0.0)
    hl = ln / 2
    # lower body (side profile y, z), front = +Y
    prof = [(-hl, 0.32), (-hl + 0.05, 0.85), (-hl + 0.9, 0.95), (hl - 1.1, 0.95), (hl - 0.05, 0.75), (hl, 0.42), (hl - 0.1, 0.3)]
    body.profile_x(prof, -w / 2, w / 2, paint)
    # greenhouse: pillars as a tapered cabin with glass faces
    cab = [(-hl + 0.95, 0.94), (-hl + 1.45, 1.42), (hl - 1.9, 1.44), (hl - 1.25, 0.94)]
    body.profile_x(cab, -w / 2 + 0.12, w / 2 - 0.12, paint)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 - 0.115), sx * (w / 2 - 0.105)))
        glass.profile_x([(-hl + 1.05, 0.98), (-hl + 1.48, 1.38), (hl - 1.95, 1.39), (hl - 1.35, 0.98)], x0, x1, "glass_tinted")
        trim.bx((x0 - 0.002 * sx, -0.12, 0.97), (x1 + 0.004 * sx, -0.06, 1.4), paint)
        trim.bx((sx * (w / 2 + 0.06) - 0.05, hl - 1.3, 1.0), (sx * (w / 2 + 0.06) + 0.05, hl - 1.2, 1.1), paint)
        trim.bx((sx * w / 2 - 0.01, -0.5, 0.82), (sx * w / 2 + 0.01, -0.36, 0.84), "chrome")
        trim.bx((sx * w / 2 - 0.01, 0.4, 0.82), (sx * w / 2 + 0.01, 0.54, 0.84), "chrome")
    a = (hl - 1.25, 0.95)
    b = (hl - 1.88, 1.42)
    glass.profile_x([(a[0] + 0.006, a[1]), (b[0] + 0.006, b[1]), (b[0] - 0.006, b[1]), (a[0] - 0.006, a[1])], -w / 2 + 0.15, w / 2 - 0.15, "glass_tinted")
    c = (-hl + 0.97, 0.95)
    d = (-hl + 1.44, 1.41)
    glass.profile_x([(c[0] - 0.006, c[1]), (d[0] - 0.006, d[1]), (d[0] + 0.006, d[1]), (c[0] + 0.006, c[1])], -w / 2 + 0.15, w / 2 - 0.15, "glass_tinted")
    # lights, grille, bumpers, plates
    for sx in (-1, 1):
        trim.bx((sx * 0.62 - 0.17, hl - 0.04, 0.62), (sx * 0.62 + 0.17, hl + 0.005, 0.72), "chrome")
        trim.bx((sx * 0.65 - 0.15, -hl - 0.005, 0.7), (sx * 0.65 + 0.15, -hl + 0.06, 0.8), "metal_red")
    trim.bx((-0.4, hl - 0.03, 0.45), (0.4, hl + 0.01, 0.6), "plastic_black")
    trim.bx((-w / 2 + 0.05, hl - 0.12, 0.28), (w / 2 - 0.05, hl + 0.03, 0.42), "plastic_black")
    trim.bx((-w / 2 + 0.05, -hl - 0.03, 0.28), (w / 2 - 0.05, -hl + 0.12, 0.42), "plastic_black")
    trim.bx((-0.25, -hl - 0.035, 0.45), (0.25, -hl - 0.03, 0.56), "plastic_white")
    for sy in (-hl + 0.85, hl - 0.95):
        for sx in (-1, 1):
            run.cyl(0.33, 0.22, (sx * (w / 2 - 0.12), sy, 0.33), "rubber", axis="X", segs=24)
            run.cyl(0.21, 0.225, (sx * (w / 2 - 0.12), sy, 0.33), "steel", axis="X", segs=16)
    o.build()
    k.collision([((-w / 2, -hl, 0.0), (w / 2, hl, 0.95)), ((-w / 2 + 0.12, -hl + 0.95, 0.95), (w / 2 - 0.12, hl - 1.25, 1.44))])


def _hvac(k: Kit, p: dict) -> None:
    w, d, h = 1.0, 0.42, 0.9
    o = k.obj("Condenser")
    a = o.part(bevel=0.006, segments=2)
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2, h), "metal_white")
    for sx in (-1, 1):
        a.bx((sx * (w / 2 - 0.08) - 0.03, -d / 2, 0.0), (sx * (w / 2 - 0.08) + 0.03, d / 2, 0.08), "metal_dark")
    g = o.part(bevel=0.0)
    g.cyl(0.3, 0.01, (-0.15, d / 2 + 0.002, 0.5), "metal_dark", axis="Y", segs=28)
    for i in range(5):
        g.torus(0.06 * (i + 1), 0.004, (-0.15, d / 2 + 0.012, 0.5), "metal_dark", segs=24, rsegs=4, axis="Y")
    g.rod((-0.45, d / 2 + 0.012, 0.5), (0.15, d / 2 + 0.012, 0.5), 0.004, "metal_dark", segs=4)
    g.bx((0.25, d / 2, 0.15), (0.45, d / 2 + 0.005, 0.8), "metal_grey")
    g.rod((0.3, -d / 2, 0.3), (0.3, -d / 2 - 0.0, 0.0), 0.012, "steel", segs=6)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _jersey(k: Kit, p: dict) -> None:
    o = k.obj("Barrier")
    a = o.part(bevel=0.01, segments=2)
    a.profile_x([(-0.3, 0.0), (0.3, 0.0), (0.3, 0.08), (0.2, 0.25), (0.08, 0.8), (-0.08, 0.8), (-0.2, 0.25), (-0.3, 0.08)],
                -1.0, 1.0, "concrete_light")
    a.bx((-1.0, -0.17, 0.5), (1.0, -0.15, 0.6), "metal_red")
    o.build()
    k.collision([((-1.0, -0.3, 0.0), (1.0, 0.3, 0.8))])


def _roadworks(k: Kit, p: dict) -> None:
    o = k.obj("Barrier")
    a = o.part(bevel=0.004)
    for z in (0.75, 0.95):
        for i in range(8):
            x0 = -1.0 + i * 0.25
            a.bx((x0, -0.02, z), (x0 + 0.25, 0.02, z + 0.15), "metal_red" if i % 2 == 0 else "metal_white")
    for sx in (-1, 1):
        a.bx((sx * 0.85 - 0.03, -0.03, 0.0), (sx * 0.85 + 0.03, 0.03, 1.12), "metal_white")
        a.bx((sx * 0.85 - 0.12, -0.3, 0.0), (sx * 0.85 + 0.12, 0.3, 0.12), "plastic_black")
    o.build()
    k.collision([((-1.0, -0.3, 0.0), (1.0, 0.3, 1.12))])


def _neon(k: Kit, p: dict) -> None:
    o = k.obj("Neon")
    rc = o.part(bevel=0.006, segments=2)
    tube = o.part(bevel=0.0)
    width = lettering(tube, "VOSSBERG", 0.5, 0.0, 0.1, -0.25, "emit_neon_magenta", stroke=0.026, depth=0.0,
                      round_tube=True, slant=0.22, spacing=0.18)
    # dark raceway behind the letters + standoffs; underline swash
    rc.bx((-width / 2 - 0.08, 0.0, -0.08), (width / 2 + 0.18, 0.08, 0.06), "metal_dark")
    for i in range(9):
        x = -width / 2 + i * width / 8
        rc.rod((x, 0.08, -0.01), (x, 0.1, -0.01), 0.006, "steel", segs=6)
    swash = [(-width / 2 + 0.1 + i * (width - 0.2) / 16, 0.1, -0.33 + 0.03 * math.sin(i * math.pi / 8)) for i in range(17)]
    tube.tube(swash, 0.012, "emit_neon_magenta", segs=8)
    o.build()


def _awning(k: Kit, p: dict) -> None:
    w, proj = 3.0, 1.0
    o = k.obj("Awning")
    c = o.part(bevel=0.0)
    trim = o.part(bevel=0.003)
    c.profile_x([(0.0, 0.25), (proj, -0.15), (proj, -0.4), (proj - 0.02, -0.4), (proj - 0.02, -0.17), (0.0, 0.23)],
                -w / 2, w / 2, "canvas_ivory")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.02)))
        c.profile_x([(0.0, 0.25), (proj, -0.15), (proj, -0.17), (0.0, 0.23)], x0, x1, "canvas_ivory")
    trim.bx((-w / 2 - 0.02, 0.0, 0.22), (w / 2 + 0.02, 0.05, 0.3), "brass")
    for sx in (-1, 1):
        trim.rod((sx * (w / 2 - 0.1), 0.02, 0.1), (sx * (w / 2 - 0.1), proj - 0.05, -0.12), 0.012, "brass", segs=8)
    o.build()


def _wall_lamp(k: Kit, p: dict) -> None:
    o = k.obj("Lamp")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-0.08, 0.0, -0.12), (0.08, 0.02, 0.12), "metal_dark")
    a.bx((-0.07, 0.02, 0.05), (0.07, 0.22, 0.09), "metal_dark")
    e = o.part(bevel=0.0)
    e.bx((-0.06, 0.04, 0.045), (0.06, 0.2, 0.05), "emit_warm")
    a.rod((0.0, 0.02, -0.08), (0.0, 0.18, 0.05), 0.01, "metal_dark", segs=8)
    o.build()


def _planter(k: Kit, p: dict) -> None:
    o = k.obj("Planter")
    a = o.part(bevel=0.01, segments=2)
    a.bx((-0.6, -0.4, 0.0), (0.6, 0.4, 0.55), "concrete_light")
    s = o.part(bevel=0.0)
    s.bx((-0.55, -0.35, 0.5), (0.55, 0.35, 0.52), "soil")
    rng = k.ctx.rng
    for i in range(14):
        x, y = rng.uniform(-0.45, 0.45), rng.uniform(-0.28, 0.28)
        s.sphere(rng.uniform(0.12, 0.2), (x, y, 0.62 + rng.uniform(0, 0.15)), "leaf", segs=8, rings=5, scale=(1.0, 1.0, 0.8))
    o.build()
    k.collision([((-0.6, -0.4, 0.0), (0.6, 0.4, 0.55))])


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
