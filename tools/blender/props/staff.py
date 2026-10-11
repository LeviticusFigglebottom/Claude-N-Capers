"""Staff areas: break room (break_room), security office (security_office), offices
(office_open, office_manager), corridors (corridor_service, corridor_office), ceiling lights,
wall details (switch, outlet, thermostat) and desk / counter clutter.

Floor props: bottom-centre pivot, front +Y (Godot -Z); wall-mounted: back at y = 0, centred
vertically on the origin (catalog `z` = centre height); ceiling: top at z = 0.
"""

import math

from _pb import Kit, bar_handle, chair_seat_marker, knob, legs4, lettering, panel_door

TRI_BUDGET = 12000
WARM = "#FFC58F"
NEUTRAL = "#FFD9B0"
COOL = "#FFE4CE"
_ON_DESK = ["desk", "table", "credenza", "counter_service", "kitchen_counter", "jeweler_bench", "workbench", "packing_bench"]
VARIANTS = {
    # break room
    "prop_fridge": {"fn": "fridge", "cat": {"kind": "fridge", "place": "wall", "clear": 0.9, "group": "kitchen"}},
    "prop_kitchen_counter": {"fn": "kitchen_counter", "cat": {"kind": "kitchen_counter", "place": "wall", "support": True, "clear": 1.0, "group": "kitchen",
                                                             "top": 0.9, "keepout": [[-0.68, -0.22, -0.12, 0.33]]}},
    "prop_wall_cabinet": {"fn": "wall_cabinet", "cat": {"kind": "wall_cabinet", "place": "wall_mount", "z": 1.85, "hosts": ["kitchen_counter"], "group": "kitchen"}},
    "prop_microwave": {"fn": "microwave", "cat": {"kind": "microwave", "place": "on", "hosts": ["kitchen_counter"], "group": "kitchen"}},
    "prop_coffee_machine": {"fn": "coffee_machine", "cat": {"kind": "coffee_machine", "place": "on", "hosts": ["kitchen_counter", "credenza"], "group": "kitchen"}},
    "prop_kettle": {"fn": "kettle", "cat": {"kind": "kettle", "place": "on", "hosts": ["kitchen_counter"], "group": "kitchen"}},
    "prop_table_break": {"fn": "table_break", "cat": {"kind": "table", "place": "center", "support": True, "clear": 0.7, "group": "kitchen"}},
    "prop_chair_break": {"fn": "chair_break", "cat": {"kind": "chair", "place": "seat", "hosts": ["table"], "group": "kitchen"}},
    "prop_lockers": {"fn": "lockers", "cat": {"kind": "lockers", "place": "wall", "clear": 0.8, "group": "kitchen"}},
    "prop_bulletin_board": {"fn": "bulletin", "cat": {"kind": "bulletin_board", "place": "wall_mount", "z": 1.5, "group": "kitchen"}},
    "prop_water_cooler": {"fn": "water_cooler", "cat": {"kind": "water_cooler", "place": "corner", "group": "kitchen"}},
    "prop_bin_kitchen": {"fn": "bin_kitchen", "cat": {"kind": "bin", "place": "wall", "group": "kitchen"}},
    # offices + security
    "prop_desk_office": {"fn": "desk_office", "cat": {"kind": "desk", "place": "wall", "support": True, "clear": 1.0, "group": "office"}},
    "prop_desk_exec": {"fn": "desk_exec", "cat": {"kind": "desk", "place": "floor", "support": True, "clear": 1.0, "group": "office"}},
    "prop_chair_office": {"fn": "chair_office", "cat": {"kind": "chair", "place": "seat", "hosts": ["desk"], "group": "office"}},
    "prop_chair_visitor": {"fn": "chair_visitor", "cat": {"kind": "chair", "place": "seat", "hosts": ["desk", "table"], "seat_side": "back", "group": "office"}},
    "prop_monitor": {"fn": "monitor", "cat": {"kind": "monitor", "place": "on", "hosts": ["desk"], "group": "office"}},
    "prop_keyboard_mouse": {"fn": "keyboard", "cat": {"kind": "keyboard", "place": "on", "hosts": ["desk"], "group": "office"}},
    "prop_desk_lamp": {"fn": "desk_lamp", "cat": {"kind": "desk_lamp", "place": "on", "hosts": ["desk", "credenza"], "fixture": True, "group": "office",
                                                  "light": {"type": "spot", "color": WARM, "energy": 0.8, "range": 1.8, "angle": 45, "pos": [0.0, 0.38, -0.12]}}},
    "prop_file_cabinet": {"fn": "file_cabinet", "cat": {"kind": "file_cabinet", "place": "wall", "support": True, "clear": 0.8, "group": "office"}},
    "prop_printer": {"fn": "printer", "cat": {"kind": "printer", "place": "wall", "clear": 0.8, "group": "office"}},
    "prop_bookshelf": {"fn": "bookshelf", "cat": {"kind": "bookshelf", "place": "wall", "clear": 0.7, "group": "office"}},
    "prop_credenza": {"fn": "credenza", "cat": {"kind": "credenza", "place": "wall", "support": True, "clear": 0.7, "group": "office"}},
    "prop_key_cabinet": {"fn": "key_cabinet", "cat": {"kind": "key_cabinet", "place": "wall_mount", "z": 1.5, "group": "office"}},
    "prop_safe_wall": {"fn": "safe_wall", "cat": {"kind": "wall_safe", "place": "wall_mount", "z": 1.2, "group": "office"}},
    "prop_gem_scope": {"fn": "gem_scope", "cat": {"kind": "gem_scope", "place": "on", "hosts": ["desk", "jeweler_bench"], "group": "office"}},
    # clutter
    "prop_papers": {"fn": "papers", "cat": {"kind": "papers", "place": "on", "hosts": _ON_DESK, "group": "clutter"}},
    "prop_mug": {"fn": "mug", "cat": {"kind": "mug", "place": "on", "hosts": _ON_DESK, "group": "clutter"}},
    "prop_pen_cup": {"fn": "pen_cup", "cat": {"kind": "pen_cup", "place": "on", "hosts": _ON_DESK, "group": "clutter"}},
    "prop_binders": {"fn": "binders", "cat": {"kind": "binders", "place": "on", "hosts": _ON_DESK + ["file_cabinet"], "group": "clutter"}},
    "prop_phone_desk": {"fn": "phone_desk", "cat": {"kind": "desk_phone", "place": "on", "hosts": ["desk", "counter_service", "credenza"], "group": "clutter"}},
    "prop_notebook": {"fn": "notebook", "cat": {"kind": "notebook", "place": "on", "hosts": _ON_DESK, "group": "clutter"}},
    "prop_tray_tools": {"fn": "tray_tools", "cat": {"kind": "tool_tray", "place": "on", "hosts": ["jeweler_bench", "workbench"], "group": "clutter"}},
    "prop_bottles": {"fn": "bottles", "cat": {"kind": "bottles", "place": "on", "hosts": ["kitchen_counter", "table", "workbench"], "group": "clutter"}},
    "prop_bin_office": {"fn": "bin_office", "cat": {"kind": "bin", "place": "wall", "group": "clutter"}},
    "prop_bag_floor": {"fn": "bag_floor", "cat": {"kind": "bag", "place": "wall", "group": "clutter"}},
    # corridor + wall details
    "prop_fire_extinguisher": {"fn": "extinguisher", "cat": {"kind": "fire_extinguisher", "place": "wall_mount", "z": 1.05, "group": "corridor"}},
    "prop_exit_sign": {"fn": "exit_sign", "cat": {"kind": "exit_sign", "place": "above_door", "z": 2.35, "fixture": True, "group": "corridor"}},
    "prop_bench_corridor": {"fn": "bench_corridor", "cat": {"kind": "bench", "place": "wall", "clear": 0.6, "group": "corridor"}},
    "prop_light_switch": {"fn": "switch", "cat": {"kind": "switch", "place": "wall_mount", "z": 1.2, "group": "corridor"}},
    "prop_outlet": {"fn": "outlet", "cat": {"kind": "outlet", "place": "wall_mount", "z": 0.3, "group": "corridor"}},
    "prop_thermostat": {"fn": "thermostat", "cat": {"kind": "thermostat", "place": "wall_mount", "z": 1.5, "group": "corridor"}},
    "prop_notice_frame": {"fn": "notice", "cat": {"kind": "picture", "place": "wall_mount", "z": 1.5, "group": "corridor"}},
    # ceiling lights
    "prop_ceiling_panel_neutral": {"fn": "panel_light", "emit": "emit_neutral", "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True, "group": "lighting",
                                                                                      "light": {"type": "spot", "color": NEUTRAL, "energy": 1.6, "range": 4.5, "angle": 70, "pos": [0.0, -0.05, 0.0]}}},
    "prop_ceiling_panel_cool": {"fn": "panel_light", "emit": "emit_cool", "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True, "group": "lighting",
                                                                                "light": {"type": "spot", "color": COOL, "energy": 1.4, "range": 4.5, "angle": 70, "pos": [0.0, -0.05, 0.0]}}},
    "prop_downlight": {"fn": "downlight", "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True, "group": "lighting",
                                                  "light": {"type": "spot", "color": "#FFB46B", "energy": 1.8, "range": 4.5, "angle": 40, "pos": [0.0, -0.04, 0.0]}}},
    "prop_track_light": {"fn": "track_light", "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True, "group": "lighting",
                                                      "light": {"type": "spot", "color": "#FFB46B", "energy": 2.2, "range": 5.0, "angle": 50, "pos": [0.0, -0.2, 0.0]}}},
    "prop_chandelier_ring": {"fn": "chandelier", "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True, "group": "lighting",
                                                         "light": {"type": "omni", "color": "#FFB46B", "energy": 2.5, "range": 6.0, "pos": [0.0, -0.95, 0.0]}}},
    "prop_fluorescent": {"fn": "fluorescent", "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True, "group": "lighting",
                                                      "light": {"type": "spot", "color": COOL, "energy": 1.2, "range": 4.0, "angle": 75, "pos": [0.0, -0.08, 0.0]}}},
}


# ------------------------------------------------------------------------------------- kitchen

def _fridge(k: Kit, p: dict) -> None:
    w, d, h = 0.7, 0.7, 1.85
    o = k.obj("Fridge")
    a = o.part(bevel=0.012, segments=2)
    a.bx((-w / 2, -d / 2, 0.04), (w / 2, d / 2 - 0.05, h), "steel")
    a.bx((-w / 2 + 0.005, d / 2 - 0.05, 0.05), (w / 2 - 0.005, d / 2, 0.68), "steel")
    a.bx((-w / 2 + 0.005, d / 2 - 0.05, 0.69), (w / 2 - 0.005, d / 2, h - 0.01), "steel")
    a.bx((-w / 2 + 0.03, -d / 2 + 0.03, 0.0), (w / 2 - 0.03, d / 2 - 0.08, 0.04), "plastic_black")
    t = o.part(bevel=0.0)
    for z0, z1 in ((0.45, 0.65), (0.75, 1.2)):
        bar_handle(t, w / 2 - 0.06, z1, d / 2, z0, "steel", r=0.01, standoff=0.035, vertical=True)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _kitchen_counter(k: Kit, p: dict) -> None:
    w, d, h = 2.4, 0.62, 0.9
    o = k.obj("Counter")
    a = o.part(bevel=0.003, segments=1)
    a.bx((-w / 2, -d / 2, 0.1), (w / 2, d / 2 - 0.02, h - 0.035), "paint_sage")
    a.bx((-w / 2 + 0.02, -d / 2, 0.0), (w / 2 - 0.02, d / 2 - 0.07, 0.1), "plastic_black")
    n = 4
    for i in range(n):
        x0 = -w / 2 + i * w / n + 0.004
        x1 = x0 + w / n - 0.008
        a.bx((x0, d / 2 - 0.02, 0.105), (x1, d / 2, h - 0.04), "paint_sage")
        bar_handle(a, x0 + 0.08, x1 - 0.08, d / 2, h - 0.1, "steel", r=0.006, standoff=0.025)
    a.bx((-w / 2, -d / 2, h - 0.035), (w / 2, d / 2 + 0.02, h), "stone_dark")
    # sink basin (dark recess) + tap at the back
    s = o.part(bevel=0.0)
    sx = -0.4
    s.bx((sx - 0.25, -0.18, h - 0.002), (sx + 0.25, 0.2, h + 0.002), "steel")
    s.bx((sx - 0.22, -0.15, h + 0.002), (sx + 0.22, 0.17, h + 0.003), "metal_dark")
    s.cyl(0.025, 0.04, (sx, -0.24, h + 0.02), "chrome", segs=12)
    s.rod((sx, -0.24, h + 0.04), (sx, -0.24, h + 0.27), 0.012, "chrome", segs=10)
    s.rod((sx, -0.24, h + 0.27), (sx, -0.06, h + 0.22), 0.01, "chrome", segs=10)
    s.rod((sx + 0.05, -0.24, h + 0.08), (sx + 0.1, -0.2, h + 0.1), 0.006, "chrome", segs=6)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2 + 0.02, h))])


def _wall_cabinet(k: Kit, p: dict) -> None:
    w, d, h = 1.2, 0.34, 0.7
    o = k.obj("Cabinet")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, d - 0.02, h / 2), "paint_sage")
    for i in range(2):
        x0 = -w / 2 + i * w / 2 + 0.004
        a.bx((x0, d - 0.02, -h / 2 + 0.004), (x0 + w / 2 - 0.008, d, h / 2 - 0.004), "paint_sage")
        hx = x0 + w / 2 - 0.06 if i == 0 else x0 + 0.06
        bar_handle(a, hx, -h / 2 + 0.2, d, -h / 2 + 0.05, "steel", r=0.006, standoff=0.025, vertical=True)
    o.build()


def _microwave(k: Kit, p: dict) -> None:
    o = k.obj("Microwave")
    a = o.part(bevel=0.006, segments=2)
    a.bx((-0.25, -0.18, 0.0), (0.25, 0.18, 0.29), "metal_white")
    a.bx((-0.24, 0.18, 0.02), (0.1, 0.19, 0.27), "glass_tinted")
    a.bx((0.11, 0.18, 0.02), (0.24, 0.19, 0.27), "plastic_black")
    s = o.part(bevel=0.0)
    s.bx((0.14, 0.19, 0.22), (0.21, 0.192, 0.25), "emit_led_green")
    o.build()


def _coffee_machine(k: Kit, p: dict) -> None:
    o = k.obj("Coffee")
    a = o.part(bevel=0.008, segments=2)
    a.bx((-0.13, -0.18, 0.0), (0.13, 0.15, 0.04), "plastic_black")
    a.bx((-0.13, -0.18, 0.04), (0.13, -0.02, 0.38), "plastic_black")
    a.bx((-0.13, -0.18, 0.3), (0.13, 0.15, 0.38), "steel")
    a.bx((-0.04, 0.05, 0.25), (0.04, 0.12, 0.3), "steel")
    b = o.part(bevel=0.0)
    b.lathe([(0.03, 0.0), (0.04, 0.09), (0.0, 0.09)], "ceramic", centre=(0.0, 0.07, 0.04), segs=14)
    o.build()


def _kettle(k: Kit, p: dict) -> None:
    o = k.obj("Kettle")
    a = o.part(bevel=0.0)
    a.cyl(0.09, 0.02, (0.0, 0.0, 0.01), "plastic_black", segs=18)
    a.lathe([(0.08, 0.02), (0.085, 0.12), (0.06, 0.22), (0.0, 0.23)], "steel", segs=18)
    a.torus(0.06, 0.012, (-0.08, 0.0, 0.14), "plastic_black", segs=12, rsegs=5, axis="Y", arc=math.pi)
    a.rod((0.07, 0.0, 0.15), (0.12, 0.0, 0.2), 0.012, "steel", segs=8)
    o.build()


def _table_break(k: Kit, p: dict) -> None:
    w, d, h = 1.2, 0.8, 0.74
    o = k.obj("Table")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h), "plastic_white")
    a.bx((-w / 2 - 0.002, -d / 2 - 0.002, h - 0.032), (w / 2 + 0.002, d / 2 + 0.002, h - 0.026), "wood_oak")
    legs4(a, w, d, h - 0.03, 0.05, 0.035, "metal_dark", round_=True)
    o.build()
    k.collision([((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h)), ((-w / 2 + 0.04, -d / 2 + 0.04, 0.0), (w / 2 - 0.04, d / 2 - 0.04, 0.02))])


def _chair_break(k: Kit, p: dict) -> None:
    o = k.obj("Chair")
    a = o.part(bevel=0.0)
    seat = 0.45
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.rod((sx * 0.2, sy * 0.2, 0.0), (sx * 0.18, sy * 0.18, seat - 0.03), 0.011, "metal_dark", segs=8)
    b = o.part(bevel=0.015, segments=2)
    b.bx((-0.22, -0.22, seat - 0.035), (0.22, 0.22, seat), "paint_sage")
    b.profile_x([(-0.24, seat + 0.08), (-0.2, seat + 0.08), (-0.18, 0.86), (-0.22, 0.86)], -0.21, 0.21, "paint_sage")
    a.rod((-0.18, -0.21, seat - 0.03), (-0.18, -0.21, seat + 0.1), 0.009, "metal_dark", segs=6)
    a.rod((0.18, -0.21, seat - 0.03), (0.18, -0.21, seat + 0.1), 0.009, "metal_dark", segs=6)
    o.build()
    chair_seat_marker(k, seat)
    k.collision([((-0.22, -0.24, 0.0), (0.22, 0.22, seat)), ((-0.22, -0.24, seat), (0.22, -0.17, 0.86))])


def _lockers(k: Kit, p: dict) -> None:
    w, d, h = 0.9, 0.5, 1.8
    o = k.obj("Lockers")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2 - 0.02, h), "metal_grey")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.06, 0.08), "metal_dark")
    n = 3
    for i in range(n):
        x0 = -w / 2 + i * w / n + 0.006
        x1 = x0 + w / n - 0.012
        for z0, z1 in ((0.1, 0.92), (0.96, h - 0.02)):
            a.bx((x0, d / 2 - 0.02, z0), (x1, d / 2, z1), "metal_grey")
            for j in range(4):
                zz = z1 - 0.06 - j * 0.02
                a.bx((x0 + 0.05, d / 2, zz), (x1 - 0.05, d / 2 + 0.002, zz + 0.008), "metal_dark")
            a.bx((x1 - 0.05, d / 2, (z0 + z1) / 2 - 0.04), (x1 - 0.03, d / 2 + 0.02, (z0 + z1) / 2 + 0.04), "steel")
            a.bx((x0 + 0.03, d / 2, z1 - 0.13), (x0 + 0.1, d / 2 + 0.002, z1 - 0.1), "paper")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _bulletin(k: Kit, p: dict) -> None:
    w, h = 0.9, 0.6
    o = k.obj("Board")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.02, h / 2), "wood_oak")
    a.bx((-w / 2 + 0.025, 0.02, -h / 2 + 0.025), (w / 2 - 0.025, 0.024, h / 2 - 0.025), "cork")
    rng = k.ctx.rng
    for i in range(7):
        pw, ph = rng.uniform(0.1, 0.21), rng.uniform(0.1, 0.28)
        x = rng.uniform(-w / 2 + 0.03 + pw / 2, w / 2 - 0.03 - pw / 2)
        z = rng.uniform(-h / 2 + 0.03 + ph / 2, h / 2 - 0.03 - ph / 2)
        key = ("paper", "paper", "metal_yellow", "felt_rose")[i % 4]
        a.bx((x - pw / 2, 0.024 + i * 0.0006, z - ph / 2), (x + pw / 2, 0.0246 + i * 0.0006, z + ph / 2), key)
        a.cbox((x, 0.03, z + ph / 2 - 0.015), (0.01, 0.01, 0.01), "metal_red")
    o.build()


def _water_cooler(k: Kit, p: dict) -> None:
    o = k.obj("Cooler")
    a = o.part(bevel=0.01, segments=2)
    a.bx((-0.16, -0.16, 0.0), (0.16, 0.16, 1.0), "plastic_white")
    a.bx((-0.1, 0.16, 0.7), (0.1, 0.2, 0.75), "plastic_grey")
    b = o.part(bevel=0.0)
    b.lathe([(0.0, 1.0), (0.13, 1.02), (0.135, 1.35), (0.06, 1.42), (0.03, 1.45), (0.0, 1.45)], "glass_frosted", segs=20)
    b.cyl(0.012, 0.03, (-0.05, 0.19, 0.78), "metal_red", segs=8)
    b.cyl(0.012, 0.03, (0.05, 0.19, 0.78), "plastic_grey", segs=8)
    o.build()
    k.collision([((-0.16, -0.16, 0.0), (0.16, 0.2, 1.45))])


def _bin_kitchen(k: Kit, p: dict) -> None:
    o = k.obj("Bin")
    a = o.part(bevel=0.01, segments=2)
    a.bx((-0.18, -0.15, 0.0), (0.18, 0.15, 0.62), "steel")
    a.bx((-0.185, -0.155, 0.62), (0.185, 0.155, 0.66), "plastic_black")
    o.build()
    k.collision([((-0.185, -0.155, 0.0), (0.185, 0.155, 0.66))])


# ------------------------------------------------------------------------------------- office

def _desk_office(k: Kit, p: dict) -> None:
    w, d, h = 1.4, 0.7, 0.74
    o = k.obj("Desk")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-w / 2, -d / 2, h - 0.025), (w / 2, d / 2, h), "wood_oak")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 - 0.02), sx * (w / 2 - 0.06)))
        a.bx((x0, -d / 2 + 0.03, 0.0), (x1, d / 2 - 0.03, h - 0.025), "powder_charcoal")
    a.bx((-w / 2 + 0.06, -d / 2 + 0.03, 0.3), (w / 2 - 0.06, -d / 2 + 0.05, h - 0.025), "powder_charcoal")
    # drawer pedestal on the right
    a.bx((0.22, -d / 2 + 0.06, 0.04), (w / 2 - 0.07, d / 2 - 0.05, h - 0.03), "metal_grey")
    for i in range(3):
        z0 = 0.06 + i * 0.21
        a.bx((0.23, d / 2 - 0.05, z0), (w / 2 - 0.08, d / 2 - 0.035, z0 + 0.19), "metal_grey")
        a.bx((0.33, d / 2 - 0.035, z0 + 0.15), (0.45, d / 2 - 0.02, z0 + 0.165), "steel")
    o.build()
    k.collision([((-w / 2, -d / 2, h - 0.025), (w / 2, d / 2, h)), ((0.22, -d / 2 + 0.06, 0.0), (w / 2 - 0.02, d / 2 - 0.035, h - 0.025)),
                 ((-w / 2 + 0.02, -d / 2 + 0.03, 0.0), (-w / 2 + 0.06, d / 2 - 0.03, h - 0.025))])


def _desk_exec(k: Kit, p: dict) -> None:
    w, d, h = 1.8, 0.85, 0.75
    o = k.obj("Desk")
    a = o.part(bevel=0.005, segments=2)
    t = o.part(bevel=0.0015)
    # walnut top as a frame round a flush leather writing surface (one plane at 0.75, no overlaps)
    ix0, ix1, iy0, iy1 = -w / 2 + 0.15, w / 2 - 0.15, -d / 2 + 0.12, d / 2 - 0.12
    a.bx((-w / 2, -d / 2, h - 0.04), (w / 2, iy0, h), "walnut")
    a.bx((-w / 2, iy1, h - 0.04), (w / 2, d / 2, h), "walnut")
    a.bx((-w / 2, iy0, h - 0.04), (ix0, iy1, h), "walnut")
    a.bx((ix1, iy0, h - 0.04), (w / 2, iy1, h), "walnut")
    lt = o.part(bevel=0.0)
    lt.bx((ix0, iy0, h - 0.04), (ix1, iy1, h), "leather")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 - 0.02), sx * (w / 2 - 0.45)))
        a.bx((x0, -d / 2 + 0.03, 0.0), (x1, d / 2 - 0.03, h - 0.04), "walnut")
        for i in range(3):
            z0 = 0.05 + i * 0.215
            panel_door(a, x0 + 0.015, x1 - 0.015, z0, z0 + 0.2, d / 2 - 0.03, "walnut", "brass", frame_w=0.035, depth=0.012)
            knob(t, (x0 + x1) / 2, d / 2 - 0.006, z0 + 0.1)
    # modesty panel on the visitor side (Blender -Y)
    a.bx((-w / 2 + 0.45, -d / 2 + 0.03, 0.2), (w / 2 - 0.45, -d / 2 + 0.06, h - 0.04), "walnut")
    t.bx((-w / 2 - 0.003, -d / 2 - 0.003, h - 0.025), (w / 2 + 0.003, d / 2 + 0.003, h - 0.018), "brass")
    o.build()
    k.collision([((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h)), ((-w / 2 + 0.02, -d / 2 + 0.03, 0.0), (-w / 2 + 0.45, d / 2 - 0.03, h - 0.04)),
                 ((w / 2 - 0.45, -d / 2 + 0.03, 0.0), (w / 2 - 0.02, d / 2 - 0.03, h - 0.04))])


def _chair_office(k: Kit, p: dict) -> None:
    o = k.obj("Chair")
    a = o.part(bevel=0.0)
    seat = 0.45
    for i in range(5):
        ang = 2 * math.pi * i / 5 + math.pi / 2
        tip = (math.cos(ang) * 0.3, math.sin(ang) * 0.3, 0.06)
        a.rod((0.0, 0.0, 0.08), tip, 0.016, "plastic_black", segs=6)
        a.sphere(0.028, (tip[0], tip[1], 0.028), "plastic_black", segs=8, rings=4)
    a.rod((0.0, 0.0, 0.08), (0.0, 0.0, seat - 0.06), 0.025, "chrome", segs=12)
    a.rod((0.0, -0.22, seat - 0.05), (0.0, -0.27, seat + 0.18), 0.015, "plastic_black", segs=8)
    soft = o.part(bevel=0.025, segments=3)
    soft.bx((-0.25, -0.24, seat - 0.07), (0.25, 0.24, seat), "fabric_charcoal")
    soft.bx((-0.23, -0.3, seat + 0.12), (0.23, -0.24, 1.0), "fabric_charcoal")
    for sx in (-1, 1):
        a.rod((sx * 0.25, -0.12, seat - 0.03), (sx * 0.26, -0.12, seat + 0.2), 0.012, "plastic_black", segs=6)
        a.bx((sx * 0.26 - 0.03, -0.18, seat + 0.2), (sx * 0.26 + 0.03, 0.08, seat + 0.23), "plastic_black")
    o.build()
    chair_seat_marker(k, seat)
    k.collision([((-0.3, -0.3, 0.0), (0.3, 0.3, seat)), ((-0.23, -0.3, seat), (0.23, -0.24, 1.0))])


def _chair_visitor(k: Kit, p: dict) -> None:
    o = k.obj("Chair")
    seat = 0.45
    frame = o.part(bevel=0.003)
    soft = o.part(bevel=0.02, segments=3)
    for sx in (-1, 1):
        frame.rod((sx * 0.24, 0.22, 0.011), (sx * 0.24, 0.22, seat - 0.04), 0.011, "chrome", segs=8)
        frame.rod((sx * 0.24, -0.22, 0.011), (sx * 0.24, -0.24, 0.85), 0.011, "chrome", segs=8)
        frame.rod((sx * 0.24, 0.22, 0.011), (sx * 0.24, -0.22, 0.011), 0.011, "chrome", segs=8)
        frame.rod((sx * 0.24, 0.22, 0.63), (sx * 0.24, -0.23, 0.63), 0.011, "chrome", segs=8)
        frame.rod((sx * 0.24, 0.22, 0.63), (sx * 0.24, 0.22, seat - 0.04), 0.011, "chrome", segs=8)
    soft.bx((-0.23, -0.22, seat - 0.06), (0.23, 0.24, seat), "leather_cognac")
    soft.bx((-0.22, -0.26, seat + 0.12), (0.22, -0.21, 0.84), "leather_cognac")
    o.build()
    chair_seat_marker(k, seat)
    k.collision([((-0.26, -0.26, 0.0), (0.26, 0.25, seat)), ((-0.26, -0.26, seat), (0.26, -0.2, 0.86))])


def _monitor(k: Kit, p: dict) -> None:
    o = k.obj("Monitor")
    a = o.part(bevel=0.003)
    a.bx((-0.11, -0.12, 0.0), (0.11, 0.04, 0.012), "plastic_black")
    a.bx((-0.025, -0.1, 0.012), (0.025, -0.07, 0.24), "plastic_black")
    a.bx((-0.3, -0.07, 0.12), (0.3, -0.04, 0.47), "plastic_black")
    s = o.part(bevel=0.0)
    s.bx((-0.29, -0.04, 0.13), (0.29, -0.037, 0.46), "emit_screen")
    o.build()


def _keyboard(k: Kit, p: dict) -> None:
    o = k.obj("Keyboard")
    a = o.part(bevel=0.003)
    a.bx((-0.22, -0.07, 0.0), (0.22, 0.07, 0.02), "plastic_black")
    for r in range(4):
        a.bx((-0.2, -0.055 + r * 0.03, 0.02), (0.2, -0.035 + r * 0.03, 0.026), "plastic_grey")
    a.bx((0.29, -0.05, 0.0), (0.35, 0.05, 0.03), "plastic_black")
    a.bx((0.26, -0.11, 0.0), (0.38, 0.11, 0.003), "rubber")
    o.build()


def _desk_lamp(k: Kit, p: dict) -> None:
    o = k.obj("Lamp")
    a = o.part(bevel=0.0)
    a.cyl(0.07, 0.02, (0.0, -0.06, 0.01), "brass", segs=20)
    a.rod((0.0, -0.06, 0.02), (0.0, -0.06, 0.32), 0.007, "brass", segs=8)
    a.rod((0.0, -0.06, 0.32), (0.0, 0.1, 0.38), 0.007, "brass", segs=8)
    a.lathe([(0.0, 0.0), (0.03, 0.0), (0.06, -0.05), (0.065, -0.055), (0.0, -0.055)], "paint_greige", centre=(0.0, 0.12, 0.39), segs=16)
    a.lathe([(0.055, -0.05), (0.0, -0.05)], "emit_warm", centre=(0.0, 0.12, 0.39), segs=16)
    o.build()


def _file_cabinet(k: Kit, p: dict) -> None:
    w, d, h = 0.47, 0.62, 1.32
    o = k.obj("Cabinet")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2 - 0.02, h), "metal_grey")
    for i in range(4):
        z0 = 0.03 + i * 0.32
        a.bx((-w / 2 + 0.01, d / 2 - 0.02, z0), (w / 2 - 0.01, d / 2, z0 + 0.3), "metal_grey")
        bar_handle(a, -0.08, 0.08, d / 2, z0 + 0.22, "steel", r=0.006, standoff=0.025)
        a.bx((-0.05, d / 2, z0 + 0.25), (0.05, d / 2 + 0.002, z0 + 0.28), "paper")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _printer(k: Kit, p: dict) -> None:
    o = k.obj("Printer")
    a = o.part(bevel=0.01, segments=2)
    a.bx((-0.3, -0.3, 0.05), (0.3, 0.3, 0.75), "plastic_white")
    a.bx((-0.3, -0.3, 0.75), (0.3, 0.3, 1.0), "plastic_grey")
    a.bx((-0.28, -0.25, 1.0), (0.28, 0.25, 1.06), "plastic_white")
    a.bx((-0.27, -0.27, 0.0), (0.27, 0.27, 0.05), "plastic_black")
    for i in range(3):
        a.bx((-0.28, 0.3, 0.12 + i * 0.2), (0.28, 0.31, 0.29 + i * 0.2), "plastic_white")
    a.bx((-0.2, 0.0, 0.76), (0.2, 0.31, 0.78), "plastic_grey")
    s = o.part(bevel=0.0)
    s.bx((0.1, 0.3, 0.9), (0.26, 0.31, 0.97), "emit_screen")
    o.build()
    k.collision([((-0.3, -0.3, 0.0), (0.3, 0.31, 1.06))])


def _bookshelf(k: Kit, p: dict) -> None:
    w, d, h = 0.9, 0.35, 2.0
    o = k.obj("Shelf")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.0), (-w / 2 + 0.025, d / 2, h), "walnut")
    a.bx((w / 2 - 0.025, -d / 2, 0.0), (w / 2, d / 2, h), "walnut")
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, -d / 2 + 0.012, h), "walnut")
    levels = (0.0, 0.4, 0.78, 1.16, 1.54, h - 0.025)
    for z in levels:
        a.bx((-w / 2, -d / 2, z), (w / 2, d / 2, z + 0.025), "walnut")
    b = o.part(bevel=0.002)
    rng = k.ctx.rng
    keys = ("art_rust", "art_blue", "wood_dark", "paint_ivory", "art_ochre", "leather")
    for z in levels[:-1]:
        x = -w / 2 + 0.03
        zb = z + 0.025
        while x < w / 2 - 0.06:
            bw = rng.uniform(0.022, 0.05)
            bh = rng.uniform(0.2, 0.31)
            if rng.random() < 0.08:
                x += 0.08
                continue
            b.bx((x, -d / 2 + 0.02, zb), (x + bw - 0.002, -d / 2 + 0.02 + rng.uniform(0.15, 0.22), zb + bh), keys[int(rng.uniform(0, 5.99))])
            x += bw
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _credenza(k: Kit, p: dict) -> None:
    w, d, h = 1.6, 0.45, 0.75
    o = k.obj("Credenza")
    a = o.part(bevel=0.004, segments=2)
    t = o.part(bevel=0.0015)
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2 - 0.02, h - 0.03), "walnut")
    a.bx((-w / 2 - 0.01, -d / 2, h - 0.03), (w / 2 + 0.01, d / 2 + 0.01, h), "walnut")
    for i in range(4):
        x0 = -w / 2 + i * w / 4 + 0.008
        panel_door(a, x0, x0 + w / 4 - 0.016, 0.1, h - 0.05, d / 2 - 0.02, "walnut", "brass", frame_w=0.045, depth=0.012)
        knob(t, x0 + w / 4 - 0.05 if i % 2 == 0 else x0 + 0.034, d / 2 - 0.008, h - 0.18)
    for sx in (-1, 1):
        for sy in (-1, 1):
            t.lathe([(0.015, 0.0), (0.022, 0.08)], "brass", centre=(sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0.0), segs=10)
    o.build()
    k.collision([((-w / 2 - 0.01, -d / 2, 0.0), (w / 2 + 0.01, d / 2 + 0.01, h))])


def _key_cabinet(k: Kit, p: dict) -> None:
    w, h = 0.4, 0.5
    o = k.obj("KeyCabinet")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.09, h / 2), "metal_grey")
    a.bx((-w / 2 + 0.01, 0.09, -h / 2 + 0.01), (w / 2 - 0.01, 0.1, h / 2 - 0.01), "metal_grey")
    a.cyl(0.012, 0.02, (w / 2 - 0.04, 0.105, 0.0), "chrome", axis="Y", segs=12)
    a.bx((-0.08, 0.1, h / 2 - 0.08), (0.08, 0.102, h / 2 - 0.04), "paper")
    o.build()


def _safe_wall(k: Kit, p: dict) -> None:
    o = k.obj("WallSafe")
    a = o.part(bevel=0.003)
    s = 0.38
    a.bx((-s / 2, 0.0, -s / 2), (s / 2, 0.025, s / 2), "metal_dark")
    a.bx((-s / 2 + 0.03, 0.025, -s / 2 + 0.03), (s / 2 - 0.03, 0.04, s / 2 - 0.03), "metal_dark")
    a.cyl(0.04, 0.02, (0.05, 0.05, 0.05), "brass", axis="Y", segs=20)
    a.cyl(0.015, 0.03, (0.05, 0.06, -0.07), "brass", axis="Y", segs=12)
    a.rod((0.05, 0.075, -0.07), (0.12, 0.075, -0.07), 0.008, "brass", segs=8)
    o.build()


def _gem_scope(k: Kit, p: dict) -> None:
    o = k.obj("Scope")
    a = o.part(bevel=0.0)
    a.bx((-0.1, -0.12, 0.0), (0.1, 0.12, 0.03), "plastic_black")
    a.rod((0.0, -0.08, 0.03), (0.0, -0.08, 0.33), 0.018, "metal_dark", segs=10)
    a.cyl(0.035, 0.03, (0.0, 0.0, 0.08), "emit_cool", segs=16)
    a.rod((0.0, -0.08, 0.28), (0.0, 0.0, 0.25), 0.02, "metal_dark", segs=10)
    a.rod((0.0, 0.0, 0.12), (0.0, 0.0, 0.3), 0.025, "plastic_white", segs=14)
    a.rod((-0.03, 0.0, 0.3), (-0.04, -0.05, 0.4), 0.012, "metal_dark", segs=10)
    a.rod((0.03, 0.0, 0.3), (0.04, -0.05, 0.4), 0.012, "metal_dark", segs=10)
    o.build()


# ------------------------------------------------------------------------------------- clutter

def _papers(k: Kit, p: dict) -> None:
    o = k.obj("Papers")
    a = o.part(bevel=0.0)
    rng = k.ctx.rng
    z = 0.0
    for i in range(5):
        r = rng.uniform(-0.15, 0.15)
        c, s = math.cos(r), math.sin(r)
        pts = [(-0.105, -0.148), (0.105, -0.148), (0.105, 0.148), (-0.105, 0.148)]
        pts = [(x * c - y * s + rng.uniform(-0.01, 0.01), x * s + y * c) for x, y in pts]
        a.slab(pts, z, z + 0.003, "paper")
        z += 0.003
    o.build()


def _mug(k: Kit, p: dict) -> None:
    o = k.obj("Mug")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, 0.0), (0.038, 0.0), (0.04, 0.095), (0.034, 0.095), (0.032, 0.012), (0.0, 0.012)],
            ("ceramic", "art_blue", "felt_rose")[k.ctx.seed % 3], segs=18)
    a.torus(0.025, 0.006, (0.05, 0.0, 0.05), "ceramic", segs=10, rsegs=4, axis="Y")
    o.build()


def _pen_cup(k: Kit, p: dict) -> None:
    o = k.obj("Cup")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, 0.0), (0.038, 0.0), (0.038, 0.1), (0.0, 0.1)], "metal_dark", segs=16)
    for i, (dx, dy, key) in enumerate(((0.01, 0.0, "plastic_black"), (-0.012, 0.01, "metal_red"), (0.0, -0.014, "art_blue"))):
        a.rod((dx, dy, 0.05), (dx * 3, dy * 3, 0.17), 0.004, key, segs=6)
    o.build()


def _binders(k: Kit, p: dict) -> None:
    o = k.obj("Binders")
    a = o.part(bevel=0.002)
    keys = ("art_blue", "plastic_black", "art_rust", "paint_greige")
    for i in range(4):
        x = -0.12 + i * 0.065
        a.bx((x, -0.14, 0.0), (x + 0.06, 0.14, 0.31), keys[i])
        a.cyl(0.012, 0.003, (x + 0.03, 0.14, 0.05), "steel", axis="Y", segs=10)
    a.bx((0.15, -0.12, 0.0), (0.17, 0.12, 0.2), "metal_dark")
    o.build()


def _phone_desk(k: Kit, p: dict) -> None:
    o = k.obj("Phone")
    a = o.part(bevel=0.006, segments=2)
    a.profile_x([(-0.1, 0.0), (0.1, 0.0), (0.1, 0.03), (-0.1, 0.07)], -0.11, 0.11, "plastic_black")
    a.bx((-0.1, -0.08, 0.06), (0.04, -0.03, 0.09), "plastic_black")
    for r in range(4):
        for c in range(3):
            a.bx((0.05 + c * 0.018, -0.04 + r * 0.025, 0.04 - r * 0.006), (0.063 + c * 0.018, -0.028 + r * 0.025, 0.047 - r * 0.006), "plastic_grey")
    s = o.part(bevel=0.0)
    s.bx((-0.06, 0.0, 0.045), (0.02, 0.05, 0.049), "emit_screen")
    o.build()


def _notebook(k: Kit, p: dict) -> None:
    o = k.obj("Notebook")
    a = o.part(bevel=0.002)
    a.bx((-0.08, -0.11, 0.0), (0.08, 0.11, 0.018), "leather")
    a.bx((-0.077, -0.107, 0.002), (0.082, 0.107, 0.016), "paper")
    a.rod((0.1, -0.08, 0.004), (0.13, 0.06, 0.004), 0.004, "brass", segs=6)
    o.build()


def _tray_tools(k: Kit, p: dict) -> None:
    o = k.obj("Tray")
    a = o.part(bevel=0.002)
    a.bx((-0.12, -0.08, 0.0), (0.12, 0.08, 0.02), "wood_oak")
    for i in range(5):
        x = -0.09 + i * 0.045
        a.rod((x, -0.06, 0.025), (x + 0.01, 0.06, 0.025), 0.004, ("steel", "wood_dark", "steel", "plastic_black", "brass")[i], segs=6)
    a.cyl(0.02, 0.01, (0.08, -0.04, 0.025), "brass", segs=12)
    o.build()


def _bottles(k: Kit, p: dict) -> None:
    o = k.obj("Bottles")
    a = o.part(bevel=0.0)
    for i, (x, y, key, hh) in enumerate(((-0.06, 0.0, "glass_tinted", 0.26), (0.0, 0.03, "plastic_white", 0.2), (0.06, -0.02, "metal_red", 0.14))):
        r = 0.03 if i < 2 else 0.035
        a.lathe([(r, 0.0), (r, hh * 0.7), (r * 0.35, hh * 0.85), (r * 0.33, hh), (0.0, hh)], key, centre=(x, y, 0.0), segs=12)
    o.build()


def _bin_office(k: Kit, p: dict) -> None:
    o = k.obj("Bin")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, 0.0), (0.11, 0.0), (0.135, 0.32), (0.13, 0.32), (0.105, 0.008), (0.0, 0.008)], "metal_dark", segs=20)
    a.lathe([(0.1, 0.08), (0.12, 0.2), (0.0, 0.2)], "paper", segs=10)
    o.build()
    k.collision([], cylinders=[(0.135, 0.32, (0.0, 0.0, 0.16))])


def _bag_floor(k: Kit, p: dict) -> None:
    o = k.obj("Bag")
    a = o.part(bevel=0.03, segments=3)
    a.bx((-0.2, -0.08, 0.0), (0.2, 0.08, 0.3), "leather_cognac")
    b = o.part(bevel=0.0)
    b.torus(0.12, 0.008, (0.0, 0.0, 0.3), "leather_cognac", segs=16, rsegs=4, axis="Y", arc=math.pi)
    b.bx((-0.04, 0.08, 0.2), (0.04, 0.083, 0.25), "brass")
    o.build()
    k.collision([((-0.2, -0.08, 0.0), (0.2, 0.08, 0.3))])


# ----------------------------------------------------------------------- corridor / wall bits

def _extinguisher(k: Kit, p: dict) -> None:
    o = k.obj("Extinguisher")
    a = o.part(bevel=0.0)
    a.bx((-0.06, 0.0, -0.05), (0.06, 0.015, 0.25), "metal_dark")
    a.bx((-0.07, 0.015, -0.03), (0.07, 0.03, 0.0), "metal_dark")
    a.lathe([(0.0, 0.0), (0.075, 0.0), (0.08, 0.02), (0.08, 0.42), (0.05, 0.48), (0.02, 0.5), (0.0, 0.5)], "metal_red",
            centre=(0.0, 0.1, -0.3), segs=20)
    a.rod((0.0, 0.1, 0.2), (0.0, 0.1, 0.26), 0.014, "metal_dark", segs=8)
    a.rod((0.0, 0.1, 0.26), (0.08, 0.1, 0.27), 0.008, "metal_dark", segs=6)
    a.rod((0.02, 0.1, 0.25), (0.07, 0.17, 0.0), 0.008, "rubber", segs=6)
    a.rod((0.07, 0.17, 0.0), (0.06, 0.17, -0.2), 0.008, "rubber", segs=6)
    a.bx((-0.05, 0.178, -0.12), (0.05, 0.181, 0.05), "paper")
    o.build()


def _exit_sign(k: Kit, p: dict) -> None:
    w, h = 0.36, 0.15
    o = k.obj("Sign")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.05, h / 2), "plastic_white")
    e = o.part(bevel=0.0)
    e.bx((-w / 2 + 0.015, 0.05, -h / 2 + 0.015), (w / 2 - 0.015, 0.052, h / 2 - 0.015), "emit_exit_green")
    lt = o.part(bevel=0.0)
    lettering(lt, "EXIT", 0.07, -0.02, 0.052, -0.035, "plastic_white", stroke=0.011, depth=0.003)
    lt.profile_y([(0.1, 0.0), (0.13, 0.025), (0.1, 0.05), (0.1, 0.035), (0.075, 0.035), (0.075, 0.015), (0.1, 0.015)],
                 0.052, 0.055, "plastic_white")
    o.build()


def _bench_corridor(k: Kit, p: dict) -> None:
    w, d = 1.4, 0.42
    o = k.obj("Bench")
    a = o.part(bevel=0.004, segments=2)
    for i in range(5):
        y = -d / 2 + 0.02 + i * (d - 0.04) / 4
        a.bx((-w / 2, y - 0.035, 0.42), (w / 2, y + 0.035, 0.45), "wood_oak")
    for sx in (-1, 1):
        a.bx((sx * (w / 2 - 0.12) - 0.02, -d / 2 + 0.02, 0.0), (sx * (w / 2 - 0.12) + 0.02, d / 2 - 0.02, 0.42), "metal_dark")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.45))])


def _switch(k: Kit, p: dict) -> None:
    o = k.obj("Switch")
    a = o.part(bevel=0.002)
    a.bx((-0.04, 0.0, -0.04), (0.04, 0.008, 0.04), "plastic_white")
    a.bx((-0.012, 0.008, -0.02), (0.012, 0.014, 0.02), "plastic_white")
    o.build()


def _outlet(k: Kit, p: dict) -> None:
    o = k.obj("Outlet")
    a = o.part(bevel=0.002)
    a.bx((-0.04, 0.0, -0.04), (0.04, 0.008, 0.04), "plastic_white")
    a.cyl(0.02, 0.004, (0.0, 0.01, 0.0), "plastic_grey", axis="Y", segs=14)
    o.build()


def _thermostat(k: Kit, p: dict) -> None:
    o = k.obj("Thermostat")
    a = o.part(bevel=0.003)
    a.bx((-0.05, 0.0, -0.06), (0.05, 0.022, 0.06), "plastic_white")
    s = o.part(bevel=0.0)
    s.bx((-0.03, 0.022, 0.0), (0.03, 0.024, 0.035), "emit_screen")
    o.build()


def _notice(k: Kit, p: dict) -> None:
    w, h = 0.32, 0.45
    o = k.obj("Notice")
    a = o.part(bevel=0.002)
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.015, h / 2), "steel")
    a.bx((-w / 2 + 0.015, 0.015, -h / 2 + 0.015), (w / 2 - 0.015, 0.017, h / 2 - 0.015), "paper")
    a.bx((-w / 2 + 0.04, 0.017, h / 2 - 0.09), (w / 2 - 0.04, 0.0175, h / 2 - 0.05), "metal_red")
    for i in range(6):
        a.bx((-w / 2 + 0.04, 0.017, h / 2 - 0.14 - i * 0.04), (w / 2 - 0.04 - (i % 3) * 0.04, 0.0175, h / 2 - 0.13 - i * 0.04), "plastic_grey")
    o.build()


# ----------------------------------------------------------------------------- ceiling lights

def _panel_light(k: Kit, p: dict) -> None:
    s = 0.6
    o = k.obj("Panel")
    a = o.part(bevel=0.003)
    a.bx((-s / 2, -s / 2, -0.035), (s / 2, s / 2, 0.0), "metal_white")
    e = o.part(bevel=0.0)
    e.bx((-s / 2 + 0.02, -s / 2 + 0.02, -0.037), (s / 2 - 0.02, s / 2 - 0.02, -0.035), p["emit"])
    o.build()


def _downlight(k: Kit, p: dict) -> None:
    o = k.obj("Downlight")
    a = o.part(bevel=0.0)
    a.lathe([(0.09, 0.0), (0.09, -0.008), (0.06, -0.012), (0.05, -0.03), (0.0, -0.03)], "brass", segs=24)
    a.lathe([(0.045, -0.026), (0.0, -0.026)], "emit_warm", segs=16)
    o.build()


def _track_light(k: Kit, p: dict) -> None:
    ln = 2.0
    o = k.obj("Track")
    a = o.part(bevel=0.002)
    a.bx((-ln / 2, -0.02, -0.035), (ln / 2, 0.02, 0.0), "metal_dark")
    b = o.part(bevel=0.0)
    for i in range(4):
        x = -ln / 2 + 0.25 + i * (ln - 0.5) / 3
        b.cbox((x, 0.0, -0.05), (0.04, 0.03, 0.03), "metal_dark")
        b.rod((x, 0.0, -0.06), (x, 0.0, -0.1), 0.008, "metal_dark", segs=8)
        tilt = 0.06 * (1 if i % 2 == 0 else -1)
        b.lathe([(0.0, 0.0), (0.035, 0.0), (0.04, -0.12), (0.0, -0.12)], "metal_dark", centre=(x, tilt, -0.1), segs=14)
        b.lathe([(0.032, -0.118), (0.0, -0.118)], "emit_warm", centre=(x, tilt, -0.1), segs=14)
        b.torus(0.04, 0.003, (x, tilt, -0.22), "brass", segs=14, rsegs=4)
    o.build()


def _chandelier(k: Kit, p: dict) -> None:
    """Landmark: brass-and-crystal ring chandelier (2.4 m) hung on four rods, 0.9 m drop."""
    r = 1.2
    drop = 0.9
    o = k.obj("Chandelier")
    a = o.part(bevel=0.0)
    a.cyl(0.12, 0.02, (0.0, 0.0, -0.01), "brass", segs=24)
    for i in range(4):
        ang = 2 * math.pi * i / 4 + math.pi / 4
        top = (math.cos(ang) * 0.1, math.sin(ang) * 0.1, -0.02)
        end = (math.cos(ang) * (r - 0.02), math.sin(ang) * (r - 0.02), -drop)
        a.rod(top, end, 0.005, "brass", segs=6)
    a.torus(r, 0.03, (0.0, 0.0, -drop), "brass", segs=64, rsegs=8)
    a.torus(r, 0.012, (0.0, 0.0, -drop - 0.04), "brass", segs=64, rsegs=6)
    e = o.part(bevel=0.0)
    e.torus(r, 0.016, (0.0, 0.0, -drop - 0.025), "emit_warm", segs=64, rsegs=6)
    c = o.part(bevel=0.0)
    n = 72
    for i in range(n):
        ang = 2 * math.pi * (i + 0.5) / n
        x, y = math.cos(ang) * r, math.sin(ang) * r
        ln = 0.12 + 0.1 * ((i * 7) % 5) / 4
        c.rod((x, y, -drop - 0.045), (x, y, -drop - 0.045 - ln), 0.002, "chrome", segs=4)
        c.sphere(0.014, (x, y, -drop - 0.055 - ln), "glass", segs=6, rings=4, scale=(1.0, 1.0, 1.5))
    o.build()


def _fluorescent(k: Kit, p: dict) -> None:
    w, d = 1.2, 0.3
    o = k.obj("Fixture")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, -0.08), (w / 2, d / 2, 0.0), "metal_white")
    e = o.part(bevel=0.0)
    for sy in (-0.07, 0.07):
        e.rod((-w / 2 + 0.04, sy, -0.075), (w / 2 - 0.04, sy, -0.075), 0.013, "emit_cool", segs=10)
    o.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
