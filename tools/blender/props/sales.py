"""Sales floor + private salon dressing (glasshouse kits sales_floor_jewelry, salon_private).

Walnut / brass / ivory / rose palette (style guide §3 glasshouse). Floor props: bottom-centre
pivot; wall-mounted: back-centre (back at Blender y = 0, the front +Y = Godot -Z); ceiling: top
centre. `cat` = catalog hints for KitPlacer (see _scenes.py).
"""

import math

import _jewelry as J
from _pb import Kit, chair_seat_marker, knob, legs4, lettering, panel_door

TRI_BUDGET = 16000
WARM = "#FFB46B"
VARIANTS = {
    "prop_counter_sales": {"fn": "counter", "cat": {"kind": "counter_service", "place": "wall", "support": True, "clear": 1.0, "group": "sales"}},
    "prop_cash_register": {"fn": "register", "cat": {"kind": "register", "place": "on", "hosts": ["counter_service"], "group": "sales"}},
    "prop_card_terminal": {"fn": "card_terminal", "cat": {"kind": "card_terminal", "place": "on", "hosts": ["counter_service", "table"], "group": "sales"}},
    "prop_consult_table": {"fn": "consult_table", "cat": {"kind": "table", "place": "center", "support": True, "clear": 0.7, "group": "sales"}},
    "prop_chair_consult": {"fn": "chair_consult", "cat": {"kind": "chair", "place": "seat", "hosts": ["table"], "group": "sales"}},
    "prop_bench_upholstered": {"fn": "bench", "cat": {"kind": "bench", "place": "wall", "clear": 0.6, "group": "sales"}},
    "prop_podium_bust": {"fn": "podium", "h": 0.95, "top": "bust", "cat": {"kind": "podium", "place": "floor", "clear": 0.5, "group": "sales"}},
    "prop_podium_tray": {"fn": "podium", "h": 0.8, "top": "tray", "cat": {"kind": "podium", "place": "floor", "clear": 0.5, "group": "sales"}},
    "prop_window_display_box": {"fn": "display_box", "cat": {"kind": "window_display", "place": "floor", "clear": 0.4, "group": "sales"}},
    "prop_mirror_counter": {"fn": "mirror_counter", "cat": {"kind": "mirror_table", "place": "on", "hosts": ["counter_service", "table"], "group": "sales"}},
    "prop_mirror_wall": {"fn": "mirror_wall", "cat": {"kind": "mirror", "place": "wall_mount", "z": 1.45, "group": "sales"}},
    "prop_ring_tray": {"fn": "ring_tray", "cat": {"kind": "ring_tray", "place": "on", "hosts": ["counter_service", "table", "coffee_table"], "group": "sales"}},
    "prop_bust_display": {"fn": "bust", "cat": {"kind": "bust", "place": "on", "hosts": ["counter_service", "table", "credenza"], "group": "sales"}},
    "prop_rug_round": {"fn": "rug_round", "cat": {"kind": "rug", "place": "rug", "support": True, "group": "sales"}},
    "prop_rug_rect": {"fn": "rug_rect", "cat": {"kind": "rug", "place": "rug", "support": True, "group": "sales"}},
    "prop_plant_tall": {"fn": "plant_tall", "cat": {"kind": "plant", "place": "corner", "group": "sales"}},
    "prop_plant_small": {"fn": "plant_small", "cat": {"kind": "plant_small", "place": "on", "hosts": ["desk", "credenza", "side_table", "table", "file_cabinet", "counter_service"], "group": "sales"}},
    "prop_sign_vossberg": {"fn": "sign", "cat": {"kind": "sign", "place": "wall_mount", "z": 2.3, "group": "sales"}},
    "prop_sofa": {"fn": "sofa", "cat": {"kind": "sofa", "place": "wall", "clear": 1.0, "group": "salon"}},
    "prop_armchair": {"fn": "armchair", "cat": {"kind": "armchair", "place": "seat", "hosts": ["coffee_table"], "group": "salon"}},
    "prop_coffee_table": {"fn": "coffee_table", "cat": {"kind": "coffee_table", "place": "center", "support": True, "clear": 0.5, "group": "salon"}},
    "prop_vitrine_decor": {"fn": "vitrine_decor", "cat": {"kind": "vitrine", "place": "wall", "clear": 0.7, "group": "salon"}},
    "prop_side_table": {"fn": "side_table", "cat": {"kind": "side_table", "place": "wall", "support": True, "group": "salon"}},
    "prop_floor_lamp": {"fn": "floor_lamp", "cat": {"kind": "floor_lamp", "place": "corner", "fixture": True, "group": "salon",
                                                   "light": {"type": "omni", "color": WARM, "energy": 0.8, "range": 3.5, "pos": [0.0, 1.45, 0.0]}}},
    "prop_table_lamp": {"fn": "table_lamp", "cat": {"kind": "table_lamp", "place": "on", "hosts": ["side_table", "credenza"], "fixture": True, "group": "salon",
                                                   "light": {"type": "omni", "color": WARM, "energy": 0.5, "range": 2.5, "pos": [0.0, 0.42, 0.0]}}},
    "prop_wall_art_a": {"fn": "art", "w": 0.8, "h": 0.6, "art": "a", "cat": {"kind": "picture", "place": "wall_mount", "z": 1.52, "group": "salon"}},
    "prop_wall_art_b": {"fn": "art", "w": 0.6, "h": 0.85, "art": "b", "cat": {"kind": "picture", "place": "wall_mount", "z": 1.52, "group": "salon"}},
    "prop_wall_art_c": {"fn": "art", "w": 1.2, "h": 0.7, "art": "c", "cat": {"kind": "picture", "place": "wall_mount", "z": 1.52, "group": "salon"}},
}


def _counter(k: Kit, p: dict) -> None:
    w, d, h = 2.2, 0.62, 0.9
    o = k.obj("Counter")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0015)
    hard.bx((-w / 2 + 0.04, -d / 2 + 0.04, 0.0), (w / 2 - 0.04, d / 2 - 0.06, 0.1), "wood_dark")
    trim.bx((-w / 2 + 0.039, -d / 2 + 0.039, 0.0), (w / 2 - 0.039, d / 2 - 0.059, 0.012), "brass")
    hard.bx((-w / 2, -d / 2, 0.1), (w / 2, d / 2, h - 0.04), "walnut")
    hard.bx((-w / 2 - 0.02, -d / 2 - 0.01, h - 0.04), (w / 2 + 0.02, d / 2 + 0.025, h), "marble")
    trim.bx((-w / 2 - 0.004, -d / 2 - 0.004, h - 0.06), (w / 2 + 0.004, d / 2 + 0.004, h - 0.05), "brass")
    n = 5
    pw = (w - 0.08) / n
    for i in range(n):
        x0 = -w / 2 + 0.04 + i * pw + 0.012
        panel_door(hard, x0, x0 + pw - 0.024, 0.15, h - 0.1, d / 2, "walnut", "brass")
    # staff side: open shelves
    hard.bx((-w / 2 + 0.05, -d / 2 - 0.0, 0.42), (w / 2 - 0.05, -d / 2 + 0.3, 0.44), "walnut")
    o.build()
    k.collision([((-w / 2 - 0.02, -d / 2 - 0.01, 0.0), (w / 2 + 0.02, d / 2 + 0.025, h))])


def _register(k: Kit, p: dict) -> None:
    o = k.obj("Register")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-0.17, -0.2, 0.0), (0.17, 0.2, 0.08), "plastic_black")
    a.bx((-0.15, -0.05, 0.08), (0.15, 0.15, 0.1), "plastic_grey")
    a.bx((-0.04, -0.12, 0.08), (0.04, -0.06, 0.2), "plastic_black")
    a.bx((-0.14, -0.13, 0.2), (0.14, -0.05, 0.38), "plastic_black")
    s = o.part(bevel=0.0)
    s.bx((-0.125, -0.051, 0.215), (0.125, -0.048, 0.365), "emit_screen")
    for r in range(3):
        for c in range(5):
            a.bx((-0.12 + c * 0.05, 0.0 + r * 0.045, 0.1), (-0.09 + c * 0.05, 0.03 + r * 0.045, 0.11), "plastic_white")
    o.build()
    k.collision([((-0.17, -0.2, 0.0), (0.17, 0.2, 0.38))])


def _card_terminal(k: Kit, p: dict) -> None:
    o = k.obj("Terminal")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-0.04, -0.05, 0.0), (0.04, 0.05, 0.015), "plastic_black")
    a.profile_x([(-0.04, 0.015), (0.04, 0.015), (0.03, 0.09), (-0.05, 0.06)], -0.035, 0.035, "plastic_black")
    s = o.part(bevel=0.0)
    s.cbox((0.0, -0.01, 0.068), (0.05, 0.004, 0.035), "emit_screen")
    o.build()


def _consult_table(k: Kit, p: dict) -> None:
    w, d, h = 1.1, 0.7, 0.74
    o = k.obj("Table")
    top = o.part(bevel=0.005, segments=2)
    legs = o.part(bevel=0.002)
    top.bx((-w / 2, -d / 2, h - 0.035), (w / 2, d / 2, h), "walnut")
    top.bx((-w / 2 + 0.05, -d / 2 + 0.05, h - 0.1), (w / 2 - 0.05, d / 2 - 0.05, h - 0.035), "walnut")
    inset = 0.09
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - inset), sy * (d / 2 - inset)
            legs.lathe([(0.018, 0.0), (0.024, 0.02), (0.016, 0.03), (0.02, h - 0.1)], "brass", centre=(x, y, 0.0), segs=12)
    legs.bx((-w / 2 + inset, -0.01, 0.12), (w / 2 - inset, 0.01, 0.14), "brass")
    o.build()
    k.collision([((-w / 2, -d / 2, h - 0.1), (w / 2, d / 2, h)), ((-w / 2 + 0.07, -d / 2 + 0.07, 0.0), (w / 2 - 0.07, d / 2 - 0.07, 0.02))])


def _chair_consult(k: Kit, p: dict) -> None:
    o = k.obj("Chair")
    frame = o.part(bevel=0.004, segments=2)
    soft = o.part(bevel=0.02, segments=3)
    w, d = 0.48, 0.5
    seat_z = 0.45
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.03), sy * (d / 2 - 0.03)
            frame.bx((x - 0.018, y - 0.018, 0.0), (x + 0.018, y + 0.018, seat_z - 0.06), "walnut")
    frame.bx((-w / 2, -d / 2, seat_z - 0.08), (w / 2, d / 2, seat_z - 0.04), "walnut")
    soft.bx((-w / 2 + 0.01, -d / 2 + 0.01, seat_z - 0.05), (w / 2 - 0.01, d / 2 - 0.01, seat_z + 0.0), "fabric_ivory")
    # back: walnut posts + upholstered panel at the back (Blender -Y; the sitter faces +Y)
    for sx in (-1, 1):
        frame.bx((sx * (w / 2 - 0.03) - 0.018, -d / 2 + 0.012, seat_z - 0.06), (sx * (w / 2 - 0.03) + 0.018, -d / 2 + 0.048, 0.92), "walnut")
    soft.bx((-w / 2 + 0.05, -d / 2 + 0.015, seat_z + 0.1), (w / 2 - 0.05, -d / 2 + 0.06, 0.9), "fabric_ivory")
    o.build()
    chair_seat_marker(k, seat_z)
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, seat_z)), ((-w / 2, -d / 2, seat_z), (w / 2, -d / 2 + 0.06, 0.92))])


def _bench(k: Kit, p: dict) -> None:
    w, d = 1.4, 0.45
    o = k.obj("Bench")
    soft = o.part(bevel=0.025, segments=3)
    frame = o.part(bevel=0.002)
    soft.bx((-w / 2, -d / 2, 0.3), (w / 2, d / 2, 0.46), "fabric_ivory")
    # tufting buttons
    for i in range(6):
        for j in range(2):
            soft.sphere(0.008, (-w / 2 + 0.12 + i * (w - 0.24) / 5, -d / 4 + j * d / 2, 0.462), "fabric_ivory", segs=6, rings=3)
    frame.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.27), (w / 2 - 0.02, d / 2 - 0.02, 0.3), "brass")
    for sx in (-1, 1):
        for sy in (-1, 1):
            frame.rod((sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0.0), (sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0.27), 0.014, "brass", segs=10)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.46))])


def _podium(k: Kit, p: dict) -> None:
    h = p["h"]
    s = 0.42
    o = k.obj("Podium")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0015)
    hard.bx((-s / 2, -s / 2, 0.0), (s / 2, s / 2, h - 0.03), "walnut")
    hard.bx((-s / 2 - 0.015, -s / 2 - 0.015, h - 0.03), (s / 2 + 0.015, s / 2 + 0.015, h), "felt_rose")
    trim.bx((-s / 2 - 0.004, -s / 2 - 0.004, 0.0), (s / 2 + 0.004, s / 2 + 0.004, 0.05), "brass")
    trim.bx((-s / 2 - 0.016, -s / 2 - 0.016, h - 0.034), (s / 2 + 0.016, s / 2 + 0.016, h - 0.028), "brass")
    disp = o.part(bevel=0.0)
    soft = o.part(bevel=0.003, segments=2)
    if p["top"] == "bust":
        J.bust(disp, soft, 0.0, 0.0, h, height=0.3, pearls=True)
    else:
        J.ring_tray(disp, soft, 0.0, 0.0, h, w=0.26, d=0.13)
        J.watch_pillow(disp, soft, 0.0, 0.1, h)
    o.build()
    k.collision([((-s / 2 - 0.015, -s / 2 - 0.015, 0.0), (s / 2 + 0.015, s / 2 + 0.015, h))])


def _display_box(k: Kit, p: dict) -> None:
    """Shop-window display box: walnut plinth, felt-lined lit cube, brass-edged glass front."""
    w, d, h = 0.8, 0.5, 1.15
    o = k.obj("Box")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0015)
    felt = o.part(bevel=0.002)
    glass = o.part(bevel=0.0)
    hard.bx((-w / 2 + 0.05, -d / 2 + 0.05, 0.0), (w / 2 - 0.05, d / 2 - 0.05, 0.55), "walnut")
    trim.bx((-w / 2 + 0.049, -d / 2 + 0.049, 0.0), (w / 2 - 0.049, d / 2 - 0.049, 0.03), "brass")
    hard.bx((-w / 2, -d / 2, 0.55), (w / 2, d / 2, 0.6), "walnut")
    hard.bx((-w / 2, -d / 2, 0.6), (-w / 2 + 0.03, d / 2, h), "walnut")
    hard.bx((w / 2 - 0.03, -d / 2, 0.6), (w / 2, d / 2, h), "walnut")
    hard.bx((-w / 2, -d / 2, 0.6), (w / 2, -d / 2 + 0.03, h), "walnut")
    hard.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), "walnut")
    felt.bx((-w / 2 + 0.03, -d / 2 + 0.03, 0.6), (w / 2 - 0.03, d / 2, 0.615), "felt_rose")
    felt.bx((-w / 2 + 0.03, -d / 2 + 0.03, 0.615), (w / 2 - 0.03, -d / 2 + 0.04, h - 0.04), "felt_rose")
    trim.bx((-w / 2 + 0.06, -d / 2 + 0.06, h - 0.046), (w / 2 - 0.06, d / 2 - 0.06, h - 0.04), "emit_warm")
    for (x0, x1) in ((-w / 2, w / 2),):
        trim.bx((x0, d / 2 - 0.012, 0.6), (x1, d / 2, 0.612), "brass")
        trim.bx((x0, d / 2 - 0.012, h - 0.052), (x1, d / 2, h - 0.04), "brass")
    glass.bx((-w / 2 + 0.03, d / 2 - 0.009, 0.612), (w / 2 - 0.03, d / 2 - 0.003, h - 0.052), "glass")
    disp = o.part(bevel=0.0)
    soft = o.part(bevel=0.003, segments=2)
    J.bust(disp, soft, -0.15, 0.0, 0.615, height=0.27, pearls=False)
    J.ring_tray(disp, soft, 0.14, 0.05, 0.615, w=0.22, d=0.11)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _mirror_counter(k: Kit, p: dict) -> None:
    o = k.obj("Mirror")
    a = o.part(bevel=0.002)
    a.cyl(0.07, 0.012, (0.0, 0.0, 0.006), "brass", segs=24)
    a.rod((0.0, 0.0, 0.012), (0.0, 0.0, 0.18), 0.006, "brass", segs=10)
    a.torus(0.1, 0.008, (0.0, 0.0, 0.29), "brass", segs=28, rsegs=6, axis="Y")
    m = o.part(bevel=0.0)
    m.cyl(0.098, 0.006, (0.0, 0.0, 0.29), "chrome", axis="Y", segs=28)
    o.build()


def _mirror_wall(k: Kit, p: dict) -> None:
    w, h = 0.65, 1.3
    o = k.obj("Mirror")
    fr = o.part(bevel=0.004, segments=2)
    fr.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.025, -h / 2 + 0.04), "brass")
    fr.bx((-w / 2, 0.0, h / 2 - 0.04), (w / 2, 0.025, h / 2), "brass")
    fr.bx((-w / 2, 0.0, -h / 2), (-w / 2 + 0.04, 0.025, h / 2), "brass")
    fr.bx((w / 2 - 0.04, 0.0, -h / 2), (w / 2, 0.025, h / 2), "brass")
    m = o.part(bevel=0.0)
    m.bx((-w / 2 + 0.035, 0.004, -h / 2 + 0.035), (w / 2 - 0.035, 0.014, h / 2 - 0.035), "chrome")
    o.build()


def _ring_tray(k: Kit, p: dict) -> None:
    o = k.obj("Tray")
    J.ring_tray(o.part(bevel=0.0), o.part(bevel=0.003, segments=2), 0.0, 0.0, 0.0, w=0.24, d=0.12)
    o.build()


def _bust(k: Kit, p: dict) -> None:
    o = k.obj("Bust")
    J.bust(o.part(bevel=0.0), o.part(bevel=0.0), 0.0, 0.0, 0.0, height=0.3, pearls=True)
    o.build()


def _rug_round(k: Kit, p: dict) -> None:
    o = k.obj("Rug")
    a = o.part(bevel=0.0)
    a.lathe([(1.2, 0.0), (1.2, 0.008), (1.19, 0.01), (0.0, 0.01)], "rug_burgundy", segs=48)
    a.torus(1.05, 0.004, (0.0, 0.0, 0.01), "rug_ivory", segs=48, rsegs=4)
    o.build()
    k.collision([], cylinders=[(1.2, 0.01, (0.0, 0.0, 0.005))])


def _rug_rect(k: Kit, p: dict) -> None:
    w, d = 2.4, 1.7
    o = k.obj("Rug")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.01), "rug_burgundy")
    b = o.part(bevel=0.0)
    for (x0, y0, x1, y1) in ((-w / 2 + 0.12, -d / 2 + 0.12, w / 2 - 0.12, -d / 2 + 0.16), (-w / 2 + 0.12, d / 2 - 0.16, w / 2 - 0.12, d / 2 - 0.12),
                             (-w / 2 + 0.12, -d / 2 + 0.12, -w / 2 + 0.16, d / 2 - 0.12), (w / 2 - 0.16, -d / 2 + 0.12, w / 2 - 0.12, d / 2 - 0.12)):
        b.bx((x0, y0, 0.01), (x1, y1, 0.0112), "rug_ivory")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.01))])


def _plant_tall(k: Kit, p: dict) -> None:
    """Fiddle-leaf fig in a ceramic planter: curved trunk, three branches, broad two-sided leaves."""
    rng = k.ctx.rng
    o = k.obj("Plant")
    pot = o.part(bevel=0.0)
    pot.lathe([(0.15, 0.0), (0.19, 0.04), (0.215, 0.4), (0.225, 0.44), (0.21, 0.46), (0.0, 0.46)], "ceramic", segs=28)
    pot.lathe([(0.2, 0.43), (0.2, 0.445), (0.0, 0.445)], "soil", segs=20)
    trunk = [(0.0, 0.0, 0.44), (0.02, 0.01, 0.75), (0.0, 0.03, 1.05), (-0.03, 0.02, 1.3)]
    pot.tube(trunk, 0.018, "wood_dark", segs=8)
    leaves = o.part(bevel=0.0)
    tips = [(-0.03, 0.02, 1.3), (0.14, 0.06, 1.18), (-0.16, -0.04, 1.1)]
    pot.tube([(0.0, 0.03, 1.0), (0.14, 0.06, 1.18)], 0.01, "wood_dark", segs=6)
    pot.tube([(0.02, 0.01, 0.85), (-0.16, -0.04, 1.1)], 0.01, "wood_dark", segs=6)
    for t, (tx, ty, tz) in enumerate(tips):
        n = 18 if t == 0 else 13
        for i in range(n):
            ang = 2.39996 * i + t
            up = 0.5 + 0.5 * i / n
            base = (tx + rng.uniform(-0.03, 0.03), ty + rng.uniform(-0.03, 0.03), tz - 0.28 * (1 - i / n) + 0.02)
            ln = rng.uniform(0.15, 0.23)
            d = (math.cos(ang) * ln * 0.9, math.sin(ang) * ln * 0.9, ln * (0.15 + 0.5 * up))
            tip = (base[0] + d[0], base[1] + d[1], base[2] + d[2])
            leaves.leaf(base, tip, ln * 0.62, "leaf" if i % 3 else "leaf_dark")
    o.build()
    k.collision([], cylinders=[(0.225, 0.46, (0.0, 0.0, 0.23))])


def _plant_small(k: Kit, p: dict) -> None:
    """Desk snake plant: upright blades in a small ceramic pot."""
    rng = k.ctx.rng
    o = k.obj("Plant")
    pot = o.part(bevel=0.0)
    pot.lathe([(0.05, 0.0), (0.065, 0.1), (0.068, 0.11), (0.0, 0.11)], "ceramic", segs=18)
    pot.lathe([(0.06, 0.1), (0.0, 0.1)], "soil", segs=12)
    leaves = o.part(bevel=0.0)
    for i in range(9):
        a = 2.39996 * i
        r = 0.015 + 0.03 * (i % 3) / 2
        base = (math.cos(a) * r, math.sin(a) * r, 0.1)
        hh = rng.uniform(0.16, 0.27)
        tip = (base[0] * 2.2 + rng.uniform(-0.02, 0.02), base[1] * 2.2 + rng.uniform(-0.02, 0.02), 0.1 + hh)
        leaves.leaf(base, tip, 0.035, "leaf" if i % 2 else "leaf_dark", up=(math.cos(a), math.sin(a), 0.0), fold=0.1)
    o.build()


def _sign(k: Kit, p: dict) -> None:
    w, h = 1.8, 0.34
    o = k.obj("Sign")
    hard = o.part(bevel=0.004, segments=2)
    hard.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.03, h / 2), "walnut")
    trim = o.part(bevel=0.0015)
    trim.bx((-w / 2 - 0.004, 0.0, -h / 2 - 0.004), (w / 2 + 0.004, 0.026, -h / 2 + 0.004), "brass")
    trim.bx((-w / 2 - 0.004, 0.0, h / 2 - 0.004), (w / 2 + 0.004, 0.026, h / 2 + 0.004), "brass")
    letters = o.part(bevel=0.0)
    lettering(letters, "VOSSBERG", 0.18, 0.0, 0.03, -0.09, "brass", stroke=0.022, depth=0.012, spacing=0.3)
    o.build()


def _sofa(k: Kit, p: dict) -> None:
    w, d = 2.0, 0.88
    o = k.obj("Sofa")
    soft = o.part(bevel=0.035, segments=3)
    legs = o.part(bevel=0.0)
    soft.bx((-w / 2, -d / 2, 0.12), (w / 2, d / 2, 0.42), "fabric_ivory")
    soft.bx((-w / 2, -d / 2, 0.42), (w / 2, -d / 2 + 0.22, 0.82), "fabric_ivory")
    for sx in (-1, 1):
        soft.bx((sx * w / 2 - 0.17 * (sx > 0), -d / 2, 0.42), (sx * w / 2 + 0.17 * (sx < 0), d / 2, 0.64), "fabric_ivory")
    for i in range(2):
        x0 = -w / 2 + 0.17 + i * (w - 0.34) / 2
        soft.bx((x0 + 0.005, -d / 2 + 0.22, 0.42), (x0 + (w - 0.34) / 2 - 0.005, d / 2 - 0.02, 0.52), "fabric_ivory")
        soft.bx((x0 + 0.02, -d / 2 + 0.2, 0.52), (x0 + (w - 0.34) / 2 - 0.02, -d / 2 + 0.32, 0.8), "fabric_ivory")
    for sx in (-1, 1):
        for sy in (-1, 1):
            legs.lathe([(0.02, 0.0), (0.026, 0.12)], "brass", centre=(sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), 0.0), segs=10)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.45)), ((-w / 2, -d / 2, 0.45), (w / 2, -d / 2 + 0.25, 0.82))])


def _armchair(k: Kit, p: dict) -> None:
    w, d = 0.82, 0.82
    o = k.obj("Armchair")
    soft = o.part(bevel=0.03, segments=3)
    legs = o.part(bevel=0.0)
    soft.bx((-w / 2, -d / 2, 0.14), (w / 2, d / 2, 0.42), "fabric_sage")
    soft.bx((-w / 2, -d / 2, 0.42), (w / 2, -d / 2 + 0.2, 0.88), "fabric_sage")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.14)))
        soft.bx((x0, -d / 2, 0.42), (x1, d / 2, 0.64), "fabric_sage")
    soft.bx((-w / 2 + 0.145, -d / 2 + 0.2, 0.42), (w / 2 - 0.145, d / 2 - 0.02, 0.5), "fabric_sage")
    for sx in (-1, 1):
        for sy in (-1, 1):
            legs.lathe([(0.016, 0.0), (0.022, 0.14)], "wood_dark", centre=(sx * (w / 2 - 0.07), sy * (d / 2 - 0.07), 0.0), segs=10)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.64)), ((-w / 2, -d / 2, 0.64), (w / 2, -d / 2 + 0.2, 0.88))])


def _coffee_table(k: Kit, p: dict) -> None:
    w, d, h = 1.1, 0.6, 0.42
    o = k.obj("Table")
    top = o.part(bevel=0.006, segments=2)
    base = o.part(bevel=0.002)
    top.bx((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h), "marble")
    for sx in (-1, 1):
        base.bx((sx * (w / 2 - 0.1) - 0.012, -d / 2 + 0.06, 0.0), (sx * (w / 2 - 0.1) + 0.012, d / 2 - 0.06, 0.02), "brass")
        base.bx((sx * (w / 2 - 0.1) - 0.012, -0.012, 0.0), (sx * (w / 2 - 0.1) + 0.012, 0.012, h - 0.03), "brass")
    base.bx((-w / 2 + 0.1, -0.012, h - 0.05), (w / 2 - 0.1, 0.012, h - 0.03), "brass")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _vitrine_decor(k: Kit, p: dict) -> None:
    w, d, h = 0.95, 0.42, 1.95
    o = k.obj("Vitrine")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0015)
    glass = o.part(bevel=0.0)
    hard.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.75), "walnut")
    for i in range(2):
        x0 = -w / 2 + 0.03 + i * (w - 0.06) / 2
        panel_door(hard, x0 + 0.01, x0 + (w - 0.06) / 2 - 0.01, 0.06, 0.7, d / 2, "walnut", "brass")
        knob(trim, x0 + (w - 0.06) / 2 - 0.05 if i == 0 else x0 + 0.05, d / 2 + 0.026, 0.45)
    hard.bx((-w / 2, -d / 2, 0.75), (-w / 2 + 0.03, d / 2, h - 0.06), "walnut")
    hard.bx((w / 2 - 0.03, -d / 2, 0.75), (w / 2, d / 2, h - 0.06), "walnut")
    hard.bx((-w / 2, -d / 2, 0.75), (w / 2, -d / 2 + 0.02, h - 0.06), "felt_rose")
    hard.bx((-w / 2 - 0.02, -d / 2, h - 0.06), (w / 2 + 0.02, d / 2 + 0.02, h), "walnut")
    trim.bx((-w / 2 - 0.022, d / 2 + 0.005, h - 0.04), (w / 2 + 0.022, d / 2 + 0.022, h - 0.032), "brass")
    glass.bx((-w / 2 + 0.03, d / 2 - 0.012, 0.75), (w / 2 - 0.03, d / 2 - 0.006, h - 0.06), "glass")
    for z in (1.15, 1.5):
        glass.bx((-w / 2 + 0.03, -d / 2 + 0.02, z), (w / 2 - 0.03, d / 2 - 0.02, z + 0.008), "glass")
    deco = o.part(bevel=0.0)
    rng = k.ctx.rng
    for z in (0.75, 1.158, 1.508):
        for j in range(3):
            x = -w / 2 + 0.17 + j * (w - 0.34) / 2
            hh = rng.uniform(0.14, 0.26)
            key = ("ceramic", "brass", "glass_tinted")[(j + int(z * 10)) % 3]
            deco.lathe([(0.03, 0.0), (0.055, hh * 0.35), (0.045, hh * 0.8), (0.022, hh), (0.0, hh)], key, centre=(x, 0.0, z), segs=16)
    o.build()
    k.collision([((-w / 2 - 0.02, -d / 2, 0.0), (w / 2 + 0.02, d / 2 + 0.02, h))])


def _side_table(k: Kit, p: dict) -> None:
    o = k.obj("Table")
    a = o.part(bevel=0.0)
    a.lathe([(0.25, 0.53), (0.25, 0.56), (0.0, 0.56)], "walnut", segs=28)
    a.lathe([(0.2, 0.0), (0.2, 0.02), (0.03, 0.03), (0.025, 0.53), (0.0, 0.53)], "brass", segs=20)
    o.build()
    k.collision([], cylinders=[(0.25, 0.56, (0.0, 0.0, 0.28))])


def _floor_lamp(k: Kit, p: dict) -> None:
    o = k.obj("Lamp")
    a = o.part(bevel=0.0)
    a.lathe([(0.15, 0.0), (0.15, 0.02), (0.02, 0.035), (0.0, 0.035)], "brass", segs=24)
    a.rod((0.0, 0.0, 0.03), (0.0, 0.0, 1.35), 0.011, "brass", segs=10)
    a.lathe([(0.2, 1.32), (0.13, 1.6), (0.0, 1.6)], "fabric_ivory", segs=24)
    a.lathe([(0.04, 1.36), (0.04, 1.5), (0.0, 1.5)], "emit_warm", segs=12)
    o.build()
    k.collision([], cylinders=[(0.15, 1.6, (0.0, 0.0, 0.8))])


def _table_lamp(k: Kit, p: dict) -> None:
    o = k.obj("Lamp")
    a = o.part(bevel=0.0)
    a.lathe([(0.07, 0.0), (0.075, 0.02), (0.09, 0.12), (0.06, 0.22), (0.015, 0.26), (0.0, 0.26)], "ceramic", segs=20)
    a.rod((0.0, 0.0, 0.26), (0.0, 0.0, 0.34), 0.006, "brass", segs=8)
    a.lathe([(0.15, 0.3), (0.11, 0.5), (0.0, 0.5)], "fabric_ivory", segs=24)
    a.lathe([(0.03, 0.33), (0.03, 0.44), (0.0, 0.44)], "emit_warm", segs=10)
    o.build()


def _art(k: Kit, p: dict) -> None:
    w, h = p["w"], p["h"]
    o = k.obj("Art")
    fr = o.part(bevel=0.003, segments=2)
    fw = 0.035
    fr.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.035, -h / 2 + fw), "wood_dark")
    fr.bx((-w / 2, 0.0, h / 2 - fw), (w / 2, 0.035, h / 2), "wood_dark")
    fr.bx((-w / 2, 0.0, -h / 2), (-w / 2 + fw, 0.035, h / 2), "wood_dark")
    fr.bx((w / 2 - fw, 0.0, -h / 2), (w / 2, 0.035, h / 2), "wood_dark")
    c = o.part(bevel=0.0)
    c.bx((-w / 2 + fw, 0.005, -h / 2 + fw), (w / 2 - fw, 0.02, h / 2 - fw), "canvas_ivory")
    rng = k.ctx.rng
    keys = {"a": ("art_ochre", "art_blue", "art_rust"), "b": ("art_rust", "art_ochre", "felt_rose"),
            "c": ("art_blue", "art_ochre", "wood_dark")}[p["art"]]
    iw, ih = w - 2 * fw - 0.06, h - 2 * fw - 0.06
    for i in range(5):
        bw, bh = rng.uniform(0.15, 0.55) * iw, rng.uniform(0.12, 0.5) * ih
        x = rng.uniform(-iw / 2 + bw / 2, iw / 2 - bw / 2)
        z = rng.uniform(-ih / 2 + bh / 2, ih / 2 - bh / 2)
        c.bx((x - bw / 2, 0.02 + 0.0005 * i, z - bh / 2), (x + bw / 2, 0.0205 + 0.0005 * (i + 1), z + bh / 2), keys[i % 3])
    if p["art"] == "c":
        c.torus(ih * 0.28, 0.006, (iw * 0.2, 0.025, 0.0), "brass", segs=32, rsegs=4, axis="Y")
    o.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
