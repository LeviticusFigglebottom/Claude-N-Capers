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
    # Night Deposit: low-pressure sodium (~2000 K) street and wall lights (docs/design/heists/night_deposit.md)
    "prop_street_lamp_sodium": {"fn": "street_lamp", "emit": "emit_sodium", "cat": {"kind": "street_lamp", "place": "row", "standoff": 3.4, "pin_only": True,
                                                                                    "fixture": True, "group": "exterior",
                                                                                    "light": {"type": "spot", "color": "#FF9A3C", "energy": 7.0,
                                                                                              "range": 15.0, "angle": 65,
                                                                                              "pos": [0.0, 5.75, -1.3]}}},
    "prop_wall_lamp_sodium": {"fn": "wall_lamp", "emit": "emit_sodium", "cat": {"kind": "wall_lamp", "place": "wall_mount", "z": 3.0, "pin_only": True,
                                                                                "fixture": True, "group": "exterior",
                                                                                "light": {"type": "spot", "color": "#FF9A3C", "energy": 3.0,
                                                                                          "range": 9.0, "angle": 75,
                                                                                          "pos": [0.0, 0.03, -0.31]}}},
    "prop_bin_street": {"fn": "bin_street", "cat": {"kind": "bin_street", "place": "row", "standoff": 2.9, "group": "exterior"}},
    "prop_bus_shelter": {"fn": "bus_shelter", "cat": {"kind": "bus_shelter", "place": "row", "standoff": 2.2, "fixture": True, "group": "exterior",
                                                      "light": {"type": "omni", "color": LED, "energy": 1.0, "range": 4.0, "pos": [0.0, 2.3, 0.0]}}},
    "prop_bollard_steel": {"fn": "bollard", "steel": True, "cat": {"kind": "bollard", "place": "row", "standoff": 3.7, "group": "exterior"}},
    "prop_bollard_concrete": {"fn": "bollard", "steel": False, "cat": {"kind": "bollard", "place": "row", "standoff": 3.7, "group": "exterior"}},
    "veh_car_sedan_wine": {"fn": "car", "paint": "car_wine", "cat": {"kind": "car", "place": "row", "standoff": 5.2, "group": "exterior"}},
    "veh_car_sedan_navy": {"fn": "car", "paint": "car_navy", "cat": {"kind": "car", "place": "row", "standoff": 5.2, "group": "exterior"}},
    "veh_car_sedan_silver": {"fn": "car", "paint": "car_silver", "cat": {"kind": "car", "place": "row", "standoff": 5.2, "group": "exterior"}},
    # RT-C2: the convoy's escort car (A5-02 convoy_vehicle visual): the sedan as `Body` (no collision: the mover fits
    # its own), a roof light bar, `Seat0..3` (front left / right, rear left / right) on the footwell floor (y 0.18,
    # sit_vehicle's root; D's convoy fit), rows 1.2 m apart. Front = +Y (Godot -Z): the map turns the mover's `Visual`
    # 180 deg so the bonnet leads (+Z); the seats face the art's front, so they face +Z in the mover.
    "veh_escort_car": {"fn": "car", "paint": "car_navy", "escort": True, "cat": {"prefab": "convoy_vehicle", "kind": "convoy_vehicle"}},
    "prop_hvac_condenser": {"fn": "hvac", "cat": {"kind": "hvac", "place": "wall", "group": "exterior"}},
    "prop_barrier_jersey": {"fn": "jersey", "cat": {"kind": "barrier", "place": "row", "standoff": 4.5, "group": "exterior"}},
    "prop_barrier_roadworks": {"fn": "roadworks", "cat": {"kind": "barrier", "place": "row", "standoff": 4.5, "group": "exterior"}},
    "prop_neon_vossberg": {"fn": "neon", "cat": {"kind": "neon_sign", "place": "wall_mount", "z": 3.6, "fixture": True, "group": "exterior",
                                                 "light": {"type": "omni", "color": "#FF3EA5", "energy": 2.5, "range": 7.0, "pos": [0.0, 0.0, -0.6]}}},
    "prop_awning": {"fn": "awning", "cat": {"kind": "awning", "place": "wall_mount", "z": 2.75, "group": "exterior"}},
    "prop_wall_lamp": {"fn": "wall_lamp", "cat": {"kind": "wall_lamp", "place": "wall_mount", "z": 2.4, "fixture": True, "group": "exterior",
                                                  "light": {"type": "spot", "color": "#FFC58F", "energy": 2.0, "range": 7.0, "angle": 60, "pos": [0.0, 0.03, -0.31]}}},
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
    e.bx((-0.13, 1.1, 5.815), (0.13, 1.55, 5.82), p.get("emit", "emit_neutral"))
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
    """Parked mid-size sedan: shaped side profile (bonnet, A/C pillars, boot), glasshouse with
    dark pillars, wheel arches, chrome beltline and grille, tail lights. Front = +Y."""
    w, ln = 1.8, 4.6
    paint = p["paint"]
    hl = ln / 2
    escort = bool(p.get("escort", False))
    o = k.obj("Body" if escort else "Car")
    body = o.part(bevel=0.04, segments=3)
    trim = o.part(bevel=0.004)
    glass = o.part(bevel=0.0)
    run = o.part(bevel=0.0)
    prof = [(-hl + 0.02, 0.36), (-hl, 0.55), (-hl + 0.04, 0.8), (-hl + 0.25, 0.92), (-hl + 0.95, 0.96),
            (hl - 1.25, 0.96), (hl - 0.55, 0.88), (hl - 0.08, 0.78), (hl, 0.6), (hl - 0.03, 0.36), (hl - 0.2, 0.3),
            (-hl + 0.2, 0.3)]
    body.profile_x(prof, -w / 2, w / 2, paint)
    cab = [(-hl + 0.9, 0.95), (-hl + 1.4, 1.38), (-hl + 1.55, 1.43), (hl - 2.0, 1.44), (hl - 1.8, 1.4), (hl - 1.2, 0.95)]
    gl = "glass_car" if escort else "glass_tinted"
    if escort:
        # an open cabin (LEAD r305: the seated escorts read through the glass): roof, A / C pillars, a dark interior
        # (floor plate at the beltline, dash, four seat backs) behind light glass
        body.profile_x([(-hl + 1.42, 1.37), (-hl + 1.55, 1.43), (hl - 2.0, 1.44), (hl - 1.82, 1.38)],
                       -w / 2 + 0.1, w / 2 - 0.1, paint)
        for sx in (-1, 1):
            px = sx * (w / 2 - 0.13)
            trim.rod((px, hl - 1.2, 0.96), (px, hl - 1.83, 1.39), 0.035, paint, segs=8)
            trim.rod((px, -hl + 0.92, 0.96), (px, -hl + 1.43, 1.38), 0.035, paint, segs=8)
        trim.bx((-w / 2 + 0.12, -hl + 0.95, 0.962), (w / 2 - 0.12, hl - 1.22, 0.968), "fabric_graphite")
        trim.bx((-0.78, hl - 1.34, 0.96), (0.78, hl - 1.22, 1.07), "plastic_black")
        for sx, sy in ((-1, 0.25), (1, 0.25), (-1, -0.95), (1, -0.95)):
            trim.bx((sx * 0.4 - 0.23, sy - 0.4, 0.96), (sx * 0.4 + 0.23, sy - 0.3, 1.3), "fabric_graphite")
        # the driver's wheel (Seat0, D's sit_vehicle_drive grip: _anim_rt.py WHEEL_C / WHEEL_R / WHEEL_TILT from the
        # seat root): rim face toward the driver and up, two spokes, the column forward-down into the dash
        ta = math.radians(30.0)
        wc = (-0.4, 0.25 + 0.40, 0.18 + 0.76)
        up = (0.0, math.sin(ta), math.cos(ta))
        rim = [(wc[0] + 0.18 * math.sin(math.tau * i / 16), wc[1] + 0.18 * math.cos(math.tau * i / 16) * up[1],
                wc[2] + 0.18 * math.cos(math.tau * i / 16) * up[2]) for i in range(16)]
        trim.tube(rim, 0.016, "rubber", segs=6, closed=True, joints=False)
        for s in (-1, 1):
            trim.rod(wc, (wc[0] + s * 0.17, wc[1] - 0.03 * up[1], wc[2] - 0.03 * up[2]), 0.012, "plastic_black", segs=6)
        trim.rod((wc[0], wc[1] - 0.01, wc[2] + 0.006), (wc[0], wc[1] + 0.36, wc[2] - 0.2), 0.03, "plastic_black", segs=8)
    else:
        body.profile_x(cab, -w / 2 + 0.1, w / 2 - 0.1, paint)
    # side glass + dark B pillar, beltline chrome, door seams and handles
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 - 0.1), sx * (w / 2 - 0.092)))
        glass.profile_x([(-hl + 1.0, 0.99), (-hl + 1.42, 1.36), (hl - 1.98, 1.37), (hl - 1.32, 0.99)], x0, x1, gl)
        trim.bx((min(x0, x1) - 0.004, -0.12, 0.98), (max(x0, x1) + 0.004, -0.04, 1.39), "plastic_black")
        xs0, xs1 = sorted((sx * (w / 2 - 0.004), sx * (w / 2 + 0.004)))
        trim.bx((xs0, -hl + 1.0, 0.955), (xs1, hl - 1.3, 0.97), "chrome")
        trim.bx((xs0, -0.08, 0.38), (xs1, -0.075, 0.95), "plastic_black")
        trim.bx((xs0, hl - 1.3, 0.38), (xs1, hl - 1.295, 0.95), "plastic_black")
        trim.bx((xs0, -hl + 1.05, 0.38), (xs1, -hl + 1.055, 0.95), "plastic_black")
        for yy in (-0.45, 0.55):
            trim.bx((sx * (w / 2 + 0.006) - 0.008, yy, 0.82), (sx * (w / 2 + 0.006) + 0.008, yy + 0.13, 0.845), "chrome")
        m0, m1 = sorted((sx * (w / 2 - 0.12), sx * (w / 2 + 0.12)))
        trim.bx((m0, hl - 1.28, 1.0), (m1, hl - 1.18, 1.09), paint)                       # door mirror on its arm
        # wheel arches (dark liners)
        for wy in (-hl + 0.85, hl - 0.95):
            trim.tube([(sx * (w / 2 - 0.01), wy - 0.37 * math.cos(math.pi * i / 10), 0.34 + 0.37 * math.sin(math.pi * i / 10))
                       for i in range(11)], 0.03, "plastic_black", segs=6)
    a = (hl - 1.2, 0.96)
    b = (hl - 1.82, 1.41)
    # screens sit proud of the cabin faces (no coplanar faces: levelcheck zfight)
    glass.profile_x([(a[0] + 0.03, a[1]), (b[0] + 0.03, b[1]), (b[0] + 0.018, b[1]), (a[0] + 0.018, a[1])], -w / 2 + 0.13, w / 2 - 0.13, gl)
    c = (-hl + 0.92, 0.96)
    d = (-hl + 1.42, 1.4)
    glass.profile_x([(c[0] - 0.03, c[1]), (d[0] - 0.03, d[1]), (d[0] - 0.018, d[1]), (c[0] - 0.018, c[1])], -w / 2 + 0.13, w / 2 - 0.13, gl)
    for sx in (-1, 1):
        trim.bx((sx * 0.62 - 0.18, hl - 0.06, 0.64), (sx * 0.62 + 0.18, hl + 0.004, 0.73), "glass_tinted")
        trim.bx((sx * 0.62 - 0.17, hl - 0.07, 0.65), (sx * 0.62 + 0.17, hl - 0.02, 0.72), "chrome")
        trim.bx((sx * 0.62 - 0.17, -hl - 0.004, 0.68), (sx * 0.62 + 0.17, -hl + 0.06, 0.78), "metal_red")
    trim.bx((-0.42, hl - 0.04, 0.46), (0.42, hl + 0.006, 0.6), "plastic_black")
    trim.bx((-0.42, hl + 0.004, 0.52), (0.42, hl + 0.01, 0.53), "chrome")
    trim.bx((-w / 2 + 0.06, hl - 0.14, 0.3), (w / 2 - 0.06, hl + 0.02, 0.43), "plastic_black")
    trim.bx((-w / 2 + 0.06, -hl - 0.02, 0.3), (w / 2 - 0.06, -hl + 0.14, 0.43), "plastic_black")
    trim.bx((-0.25, -hl - 0.026, 0.46), (-0.25 + 0.5, -hl - 0.02, 0.57), "plastic_white")
    for wy in (-hl + 0.85, hl - 0.95):
        for sx in (-1, 1):
            run.cyl(0.33, 0.22, (sx * (w / 2 - 0.12), wy, 0.33), "rubber", axis="X", segs=28)
            # painted steel wheel (LEAD r309: the untextured metallic steel mirrored the warm street as wood-brown)
            run.cyl(0.2, 0.225, (sx * (w / 2 - 0.12), wy, 0.33), "metal_grey", axis="X", segs=20)
            run.cyl(0.07, 0.23, (sx * (w / 2 - 0.12), wy, 0.33), "chrome", axis="X", segs=12)
    if escort:
        trim.bx((-0.55, -0.2, 1.44), (0.55, 0.05, 1.52), "plastic_black")  # light bar
        for sx, mat in ((-1, "emit_police_blue"), (1, "emit_led_red")):
            l0, l1 = sorted((sx * 0.08, sx * 0.52))
            trim.bx((l0, -0.18, 1.52), (l1, 0.03, 1.58), mat)
    o.build()
    if escort:
        _police_livery(k, w, hl)
        for i, (sx, sy) in enumerate(((-1, 0.25), (1, 0.25), (-1, -0.95), (1, -0.95))):
            k.empty("Seat%d" % i, (sx * 0.4, sy, 0.18))
        return
    k.collision([((-w / 2, -hl, 0.0), (w / 2, hl, 0.96)), ((-w / 2 + 0.1, -hl + 0.9, 0.96), (w / 2 - 0.1, hl - 1.2, 1.44))])


def _police_livery(k: Kit, w: float, hl: float) -> None:
    """RT-C2: the escort is the city's police escort (rolling_thunder.md: Vaultline pays for it): white door panels with
    POLICE on both flanks, proud of the body side (no coplanar faces), one mesh per flank on a turned pivot so the
    lettering reads from outside."""
    for name, sx in (("LiveryL", -1), ("LiveryR", 1)):
        piv = k.empty(name, (0.0, 0.0, 0.0), rotation=(0.0, 0.0, -sx * math.pi / 2))
        lv = k.obj(name + "Mesh", parent=piv)
        panel = lv.part(bevel=0.0)
        # pivot-local: x runs along the car (toward the front for the left flank, the rear for the right), +y outward
        y0, y1 = -hl + 1.26, hl - 1.34  # inside the wheel-arch liners (y -1.08 .. 0.98)
        a0, a1 = sorted((-sx * y0, -sx * y1))
        panel.bx((a0, w / 2 + 0.002, 0.42), (a1, w / 2 + 0.006, 0.93), "metal_white")
        lettering(panel, "POLICE", 0.17, -sx * (y0 + y1) / 2, w / 2 + 0.006, 0.585, "metal_dark", stroke=0.03,
                  depth=0.003, inlay=True)
        lv.build()


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
    # smooth arcs (res 3) and 8-sided swept tubes (<= 8000 tris, style guide §5): round letters at
    # grazing angles
    width = lettering(tube, "VOSSBERG", 0.5, 0.0, 0.1, -0.25, "emit_neon_magenta", stroke=0.026, depth=0.0,
                      round_tube=True, slant=0.22, spacing=0.18, res=3, tube_segs=8)
    # dark raceway behind the letters + standoffs; underline swash. The slant shifts the letter tops
    # towards -X (the viewer's right), so the raceway spans exactly the slanted text, no stub.
    lean = 0.22 * 0.5
    rc.bx((-width / 2 - lean - 0.06, 0.0, -0.08), (width / 2 + 0.06, 0.08, 0.06), "metal_dark")
    for i in range(9):
        x = -width / 2 + i * width / 8
        rc.rod((x, 0.08, -0.01), (x, 0.1, -0.01), 0.006, "steel", segs=6)
    swash = [(-width / 2 + 0.1 + i * (width - 0.2) / 16, 0.1, -0.33 + 0.03 * math.sin(i * math.pi / 8)) for i in range(17)]
    tube.tube(swash, 0.012, "emit_neon_magenta", segs=8)
    o.build()


def _awning(k: Kit, p: dict) -> None:
    """Striped walnut / ivory canvas awning on brass arms: sloped canopy, straight valance with a
    brass bead, triangular side cheeks. Back at y = 0, centred on the origin vertically."""
    w, proj, drop = 3.0, 1.0, 0.42
    n = 12
    o = k.obj("Awning")
    c = o.part(bevel=0.0)
    trim = o.part(bevel=0.003)
    top, low = 0.25, -0.15
    for i in range(n):
        x0 = -w / 2 + i * w / n
        key = "canvas_walnut" if i % 2 == 0 else "canvas_ivory"
        c.profile_x([(0.0, top), (proj, low), (proj, low - 0.012), (0.0, top - 0.012)], x0, x0 + w / n, key)
        c.profile_x([(proj - 0.012, low), (proj, low), (proj, low - drop + 0.25), (proj - 0.012, low - drop + 0.25)],
                    x0, x0 + w / n, key)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 - 0.008)))
        c.profile_x([(0.0, top), (proj, low), (proj, low - 0.17), (0.0, top - 0.06)], x0, x1, "canvas_walnut")
    trim.bx((-w / 2 - 0.02, 0.0, top - 0.04), (w / 2 + 0.02, 0.05, top + 0.03), "brass")
    trim.rod((-w / 2, proj + 0.004, low - 0.17), (w / 2, proj + 0.004, low - 0.17), 0.008, "brass", segs=8)
    for sx in (-1, 1):
        trim.rod((sx * (w / 2 - 0.15), 0.02, -0.25), (sx * (w / 2 - 0.15), proj - 0.04, low - 0.02), 0.012, "brass", segs=8)
        trim.cyl(0.03, 0.02, (sx * (w / 2 - 0.15), 0.01, -0.25), "brass", axis="Y", segs=14)
    o.build()


def _wall_lamp(k: Kit, p: dict) -> None:
    """Back-door gooseneck barn light: round wall plate, curved arm, enamel dish shade, lit bulb."""
    o = k.obj("Lamp")
    a = o.part(bevel=0.0)
    a.cyl(0.07, 0.016, (0.0, 0.008, 0.0), "metal_dark", axis="Y", segs=24)
    a.cyl(0.04, 0.02, (0.0, 0.025, 0.0), "metal_dark", axis="Y", segs=18)
    arm = [(0.0, 0.03 + 0.26 * math.sin(math.pi / 2 * i / 8), 0.0 + 0.16 * (1 - math.cos(math.pi / 2 * i / 8))) for i in range(9)]
    a.tube(arm, 0.011, "metal_dark", segs=10)
    tip = arm[-1]
    a.rod(tip, (0.0, tip[1] + 0.02, tip[2] - 0.03), 0.011, "metal_dark", segs=10)
    c = (0.0, tip[1] + 0.02, tip[2] - 0.03)
    a.lathe([(0.0, 0.0), (0.025, 0.0), (0.04, -0.03), (0.13, -0.09), (0.14, -0.1), (0.13, -0.095), (0.035, -0.035),
             (0.0, -0.035)], "metal_green", centre=c, segs=28)
    e = o.part(bevel=0.0)
    e.sphere(0.035, (c[0], c[1], c[2] - 0.06), p.get("emit", "emit_warm"), segs=12, rings=6)
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
