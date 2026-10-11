"""Plant, server and cleaning dressing (Night Deposit basement B3 plant, B4 server room, cleaner):
boiler, air handling unit, hot-water tank, UPS cabinet, server rack (+ the hack-terminal rack: `Screen` + `Panel` for the hack_terminal prefab), janitor cart.

Floor props: bottom-centre pivot, front +Y (Godot -Z). Everything stays inside its footprint (the
props stand 12 mm off the wall: pipes and ducts never reach into the shell).
"""

import math

from _pb import Kit, bar_handle, knob

TRI_BUDGET = 8000
VARIANTS = {
    "prop_boiler": {"fn": "boiler", "cat": {"kind": "boiler", "place": "wall", "clear": 0.9, "group": "plant"}},
    "prop_air_handler": {"fn": "air_handler", "cat": {"kind": "ahu", "place": "wall", "clear": 0.9, "group": "plant"}},
    "prop_water_tank": {"fn": "water_tank", "cat": {"kind": "tank", "place": "corner", "group": "plant"}},
    "prop_ups_cabinet": {"fn": "ups", "cat": {"kind": "ups", "place": "wall", "clear": 0.8, "group": "plant"}},
    "prop_server_rack": {"fn": "server_rack", "cat": {"kind": "server_rack", "place": "wall", "clear": 0.9, "group": "plant"}},
    # hack_terminal prefab visual (Night Deposit srv_ground / srv_basement): open rack with a KVM console
    "prop_server_rack_terminal": {"fn": "server_rack", "terminal": True,
                                  "cat": {"prefab": "hack_terminal", "kind": "hack_terminal", "group": "plant"}},
    "prop_cleaning_cart": {"fn": "cleaning_cart", "cat": {"kind": "cleaning_cart", "place": "wall", "group": "plant"}},
}


def _gauge(p, x: float, y: float, z: float, r: float = 0.05) -> None:
    p.cyl(r, 0.03, (x, y + 0.015, z), "chrome", axis="Y", segs=16)
    p.cyl(r - 0.008, 0.004, (x, y + 0.031, z), "plastic_white", axis="Y", segs=16)
    p.bx((x - 0.003, y + 0.033, z - 0.002), (x + r * 0.7, y + 0.036, z + 0.002), "metal_dark")


def _boiler(k: Kit, p: dict) -> None:
    w, d, h = 1.2, 0.85, 1.8
    o = k.obj("Boiler")
    a = o.part(bevel=0.01, segments=2)
    t = o.part(bevel=0.002)
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2, h), "metal_red")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.02, 0.08), "metal_dark")
    # front access panels, burner window, control fascia with gauges
    for x0, x1 in ((-w / 2 + 0.04, -0.02), (0.02, w / 2 - 0.04)):
        t.bx((x0, d / 2, 0.12), (x1, d / 2 + 0.01, 1.2), "metal_red")
        bar_handle(t, (x0 + x1) / 2 - 0.1, (x0 + x1) / 2 + 0.1, d / 2 + 0.01, 1.05, "steel")
    t.bx((-w / 2 + 0.04, d / 2, 1.28), (w / 2 - 0.04, d / 2 + 0.02, h - 0.06), "metal_dark")
    s = o.part(bevel=0.0)
    s.bx((-0.08, d / 2 + 0.02, 1.45), (0.08, d / 2 + 0.022, 1.55), "emit_amber")
    for x in (-0.38, -0.22, 0.24, 0.4):
        _gauge(t, x, d / 2 + 0.02, 1.5)
    # flue + flow / return pipes rising off the top, within the footprint
    a.cyl(0.13, 0.25, (0.0, -d / 2 + 0.2, h + 0.125), "steel", segs=20)
    for x in (-0.4, 0.4):
        t.rod((x, -d / 2 + 0.12, h - 0.02), (x, -d / 2 + 0.12, h + 0.3), 0.045, "metal_grey", segs=12)
        t.cyl(0.065, 0.03, (x, -d / 2 + 0.12, h + 0.15), "steel", segs=12)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _air_handler(k: Kit, p: dict) -> None:
    w, d, h = 2.0, 1.0, 1.9
    o = k.obj("AHU")
    a = o.part(bevel=0.008, segments=1)
    t = o.part(bevel=0.002)
    a.bx((-w / 2, -d / 2, 0.15), (w / 2, d / 2, h), "metal_grey")
    for x in (-w / 2 + 0.1, w / 2 - 0.1):
        a.bx((x - 0.06, -d / 2 + 0.05, 0.0), (x + 0.06, d / 2 - 0.05, 0.15), "metal_dark")
    # three access doors with lever latches; a fan grille on the left section
    sec = (w - 0.08) / 3
    for i in range(3):
        x0 = -w / 2 + 0.04 + i * sec
        t.bx((x0 + 0.02, d / 2, 0.22), (x0 + sec - 0.02, d / 2 + 0.012, h - 0.08), "metal_grey")
        for z in (0.6, 1.5):
            t.bx((x0 + sec - 0.1, d / 2 + 0.012, z - 0.03), (x0 + sec - 0.06, d / 2 + 0.04, z + 0.03), "metal_dark")
    g = o.part(bevel=0.0)
    cx, cz = -w / 2 + 0.04 + sec / 2, 1.05
    g.cyl(0.24, 0.01, (cx, d / 2 + 0.017, cz), "metal_dark", axis="Y", segs=24)
    for i in range(5):
        g.torus(0.05 + i * 0.045, 0.006, (cx, d / 2 + 0.024, cz), "steel", segs=24, rsegs=4, axis="Y")
    # duct collar on top
    a.bx((-0.45, -0.3, h), (0.45, 0.3, h + 0.2), "steel")
    t.bx((-0.5, -0.35, h + 0.2), (0.5, 0.35, h + 0.24), "steel")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h + 0.24))])


def _water_tank(k: Kit, p: dict) -> None:
    r, h = 0.45, 1.75
    o = k.obj("Tank")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, 0.25), (r * 0.7, 0.25), (r, 0.35), (r, h - 0.12), (r * 0.7, h), (0.0, h + 0.02)], "metal_white", segs=28)
    for i in range(4):
        ang = math.pi / 4 + i * math.pi / 2
        x, y = math.cos(ang) * (r - 0.08), math.sin(ang) * (r - 0.08)
        a.rod((x, y, 0.0), (x, y, 0.32), 0.03, "metal_dark", segs=8)
        a.cyl(0.05, 0.015, (x, y, 0.0075), "metal_dark", segs=10)
    t = o.part(bevel=0.0)
    for z in (0.5, 1.3):
        t.torus(r + 0.005, 0.012, (0.0, 0.0, z), "steel", segs=28, rsegs=4)
    t.rod((0.0, r - 0.02, 0.7), (0.0, r + 0.12, 0.7), 0.025, "brass", segs=10)
    t.cyl(0.04, 0.06, (0.0, r + 0.09, 0.7), "brass", segs=12)
    t.rod((0.0, 0.0, h), (0.0, 0.0, h + 0.25), 0.03, "metal_grey", segs=10)
    _gauge(t, -0.2, r - 0.06, 1.45, 0.045)
    o.build()
    k.collision([], cylinders=[(r, h + 0.25, (0.0, 0.0, (h + 0.25) / 2))])


def _ups(k: Kit, p: dict) -> None:
    w, d, h = 0.6, 0.8, 1.9
    o = k.obj("UPS")
    a = o.part(bevel=0.006, segments=2)
    t = o.part(bevel=0.002)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h), "plastic_black")
    t.bx((-w / 2 + 0.03, d / 2, 0.08), (w / 2 - 0.03, d / 2 + 0.01, h - 0.4), "metal_dark")
    for i in range(14):
        z = 0.15 + i * 0.08
        t.bx((-w / 2 + 0.08, d / 2 + 0.01, z), (w / 2 - 0.08, d / 2 + 0.014, z + 0.02), "plastic_grey")
    t.bx((-w / 2 + 0.06, d / 2, h - 0.35), (w / 2 - 0.06, d / 2 + 0.012, h - 0.06), "plastic_grey")
    s = o.part(bevel=0.0)
    s.bx((-0.12, d / 2 + 0.012, h - 0.25), (0.12, d / 2 + 0.014, h - 0.15), "emit_screen")
    for i, key in enumerate(("emit_led_green", "emit_led_green", "emit_amber")):
        s.bx((-0.1 + i * 0.08, d / 2 + 0.012, h - 0.11), (-0.08 + i * 0.08, d / 2 + 0.015, h - 0.09), key)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _server_rack(k: Kit, p: dict) -> None:
    w, d, h = 0.6, 1.0, 2.0
    term = p.get("terminal", False)
    # the terminal rack keeps its console zone (1U KVM tray + flip-up LCD) clear of equipment
    cz0, cz1 = 0.98, 1.42
    o = k.obj("Rack")
    a = o.part(bevel=0.004, segments=1)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2 - 0.03, h), "plastic_black")
    # equipment: 1U..4U slabs behind a tinted glass door, LED dots on each
    t = o.part(bevel=0.0015)
    s = o.part(bevel=0.0)
    z = 0.12
    rng = k.ctx.rng
    i = 0
    while z < h - 0.2:
        u = (1, 2, 1, 4, 2, 1, 3)[i % 7]
        hh = 0.0445 * u - 0.004
        if term and z + hh > cz0 and z < cz1:
            z = cz1 + 0.006
            continue
        key = ("metal_dark", "plastic_grey", "metal_grey")[i % 3]
        t.bx((-w / 2 + 0.06, d / 2 - 0.05, z), (w / 2 - 0.06, d / 2 - 0.035, z + hh), key)
        for j in range(rng.randint(2, 5)):
            x = -w / 2 + 0.1 + j * 0.05
            led = ("emit_led_green", "emit_led_green", "emit_amber")[(i + j) % 3]
            s.bx((x, d / 2 - 0.035, z + hh * 0.5 - 0.004), (x + 0.012, d / 2 - 0.032, z + hh * 0.5 + 0.004), led)
        z += hh + 0.006
        i += 1
    if not term:
        g = o.part(bevel=0.0)
        g.bx((-w / 2 + 0.03, d / 2 - 0.03, 0.06), (w / 2 - 0.03, d / 2 - 0.022, h - 0.06), "glass")
        a.bx((w / 2 - 0.05, d / 2 - 0.03, 0.9), (w / 2 - 0.03, d / 2, 1.2), "steel")
    else:
        # front rails either side of the open bay
        for sx in (-1, 1):
            a.bx((sx * (w / 2 - 0.045) - 0.015, d / 2 - 0.05, 0.06), (sx * (w / 2 - 0.045) + 0.015, d / 2 - 0.03, h - 0.06),
                 "metal_grey")
    o.build()
    if not term:
        k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])
        return
    # Panel: the pulled-out KVM tray (keyboard, touchpad) and the LCD lid's bezel and hinge
    pn = k.obj("Panel")
    b = pn.part(bevel=0.003)
    tw = w / 2 - 0.07
    b.bx((-tw, d / 2 - 0.36, cz0), (tw, d / 2 + 0.1, cz0 + 0.035), "metal_dark")
    b.bx((-tw + 0.03, d / 2 - 0.12, cz0 + 0.035), (tw - 0.03, d / 2 + 0.06, cz0 + 0.045), "plastic_black")
    b.bx((-0.05, d / 2 - 0.17, cz0 + 0.035), (0.05, d / 2 - 0.13, cz0 + 0.04), "plastic_grey")
    b.bx((-tw, d / 2 - 0.37, cz0 + 0.035), (tw, d / 2 - 0.34, cz1), "metal_dark")
    pn.build()
    # Screen: the LCD face only (the prefab swaps its material for the hack progress)
    sc = k.obj("Screen")
    c = sc.part(bevel=0.0)
    c.bx((-tw + 0.025, d / 2 - 0.34, cz0 + 0.06), (tw - 0.025, d / 2 - 0.336, cz1 - 0.02), "emit_screen")
    sc.build()


def _cleaning_cart(k: Kit, p: dict) -> None:
    w, d, h = 1.0, 0.5, 1.0
    o = k.obj("Cart")
    a = o.part(bevel=0.01, segments=2)
    a.bx((-w / 2, -d / 2, 0.1), (w / 2, d / 2, 0.14), "metal_yellow")
    a.bx((-w / 2, -d / 2, 0.55), (-0.05, d / 2, 0.59), "metal_yellow")
    a.bx((-w / 2, -d / 2, 0.14), (-w / 2 + 0.03, d / 2, h), "metal_yellow")
    a.bx((-0.08, -d / 2, 0.14), (-0.05, d / 2, 0.85), "metal_yellow")
    t = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            t.cyl(0.04, 0.03, (sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0.04), "rubber", axis="X", segs=10)
            t.bx((sx * (w / 2 - 0.06) - 0.015, sy * (d / 2 - 0.06) - 0.015, 0.07), (sx * (w / 2 - 0.06) + 0.015,
                 sy * (d / 2 - 0.06) + 0.015, 0.1), "metal_dark")
    # bucket with wringer, mop, a bin bag on the hoop, bottles on the shelf
    t.lathe([(0.0, 0.14), (0.16, 0.14), (0.19, 0.44), (0.0, 0.44)], "metal_yellow", centre=(0.25, 0.0, 0.0), segs=16)
    t.bx((0.12, -0.12, 0.44), (0.38, 0.12, 0.52), "plastic_grey")
    t.rod((0.3, 0.05, 0.3), (0.38, 0.1, 1.25), 0.012, "wood_pine", segs=8)
    s = o.part(bevel=0.03, segments=2)
    s.bx((-0.46, -0.2, 0.15), (-0.11, 0.2, 0.54), "bag_black")
    for i, key in enumerate(("metal_red", "plastic_white", "metal_green")):
        x = -0.4 + i * 0.1
        t.lathe([(0.0, 0.59), (0.03, 0.59), (0.03, 0.75), (0.012, 0.79), (0.0, 0.8)], key, centre=(x, 0.0, 0.0), segs=10)
    knob(t, -w / 2 + 0.015, d / 2, 0.9, "plastic_black", r=0.012)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
