"""Dockside Burn G2 dressing (DB-C2; docs/design/heists/dockside_burn.md room list and palette: rust #7A4A2E,
concrete #7D7F7C, flare orange #FF6B1A; frosted cold-store panels; heavy dock wear).

Floor props: bottom-centre pivot, front = Blender +Y (Godot -Z); wall props: back at y 0; ceiling props: top at z 0.
The map-built pieces (dockside_burn_layout.gd PROPS: the forklifts, compressors, racking, packing line, crates, nets,
yard vehicles...) are modelled to their layout box (x = Godot x, y = Godot z, z = height) less a few millimetres, so
the visual sits inside the unchanged gameplay collider; the generator instances them over that collider.

* Plant / workshop: screw compressor skids, the ammonia receiver vessel, the plant control panel, the main
  switchboard, a forklift (also the yard / apron / anteroom ones), the traction-battery charging rack.
* Packing / cold store: the roller conveyor, stainless packing tables, a flake-ice machine, fish-crate stacks, the
  double-sided cold-store racking (3 levels of frosted cartons), shrink-wrapped pallets, the pallet wrapper, pallet
  jack, shipping crates, freezer shelving, the janitor's shelf.
* Quay / yard: net piles with floats, rope reels, insulated ice-bin pallets, a lane skip, the reach stacker, the
  reefer trailer, the flatbed trailer, IBC totes, traffic cones, pallet stacks.
* Offices: the dispatch desk, counters (reception / break / count / tool bench / gate console), the canteen table,
  the staff locker bank and bench, the gun locker, a radiator heater, a pedestal basin.
* Fixtures: the hall's high-bay LED, the cold-store LED batten (6000 K), the strongroom's caged bulkhead; wall-hung
  hose reel and life ring.
"""

import math

from _pb import Kit, bar_handle

TRI_BUDGET = 16000
COLD = "#DCE8FF"
HALL = "#F2F0EA"
BULKHEAD = "#FFE2B8"
_G = "dockside"
# Every DB prop is pin_only (KitPlacer picks it only where a kit pins it: other maps' kits keep their layouts).
BASE_VARIANTS = {
    # plant / workshop
    "prop_forklift": {"fn": "forklift", "cat": {"kind": "forklift", "place": "floor", "clear": 1.0, "group": _G}},
    "prop_screw_compressor": {"fn": "compressor", "cat": {"kind": "compressor", "place": "wall", "clear": 0.9, "group": _G}},
    "prop_receiver_vessel": {"fn": "receiver", "cat": {"kind": "tank", "place": "wall", "clear": 0.6, "group": _G}},
    "prop_plant_panel": {"fn": "plant_panel", "cat": {"kind": "control_panel", "place": "wall", "clear": 0.9, "group": _G}},
    "prop_switchboard": {"fn": "switchboard", "cat": {"kind": "switchboard", "place": "wall", "clear": 0.9, "group": _G}},
    "prop_battery_rack": {"fn": "battery_rack", "cat": {"kind": "rack", "place": "wall", "support": True, "top": 1.2,
                                                        "group": _G}},
    # packing / cold store
    "prop_conveyor_roller": {"fn": "conveyor", "cat": {"kind": "conveyor", "place": "center", "support": True, "top": 0.9,
                                                       "group": _G}},
    "prop_packing_table_steel": {"fn": "packing_table", "cat": {"kind": "counter_service", "place": "wall", "support": True,
                                                                "top": 0.9, "group": _G}},
    "prop_ice_machine": {"fn": "ice_machine", "cat": {"kind": "ice_machine", "place": "wall", "clear": 0.8, "group": _G}},
    "prop_fish_crates": {"fn": "fish_crates", "layers": 5, "cat": {"kind": "fish_crates", "place": "wall", "group": _G}},
    "prop_fish_box_stack": {"fn": "fish_box_stack", "cat": {"kind": "fish_boxes", "place": "wall", "group": _G}},
    "prop_racking_coldstore": {"fn": "racking", "cat": {"kind": "rack", "place": "none", "group": _G}},
    "prop_pallet_wrapped": {"fn": "pallet_wrapped", "cat": {"kind": "pallet_wrapped", "place": "wall", "group": _G}},
    "prop_pallet_wrapper": {"fn": "wrapper", "cat": {"kind": "wrapping_machine", "place": "wall", "clear": 0.8, "group": _G}},
    "prop_pallet_jack": {"fn": "pallet_jack", "cat": {"kind": "pallet_jack", "place": "wall", "group": _G}},
    "prop_shipping_crate_h120": {"fn": "shipping_crate", "h": 1.2, "cat": {"kind": "crate", "place": "wall", "support": True,
                                                                          "group": _G}},
    "prop_shipping_crate_h180": {"fn": "shipping_crate", "h": 1.8, "cat": {"kind": "crate", "place": "wall", "group": _G}},
    "prop_shelving_freezer": {"fn": "shelving", "w": 2.4, "d": 0.6, "h": 2.0, "load": "fish",
                              "cat": {"kind": "shelving", "place": "wall", "support": True, "group": _G}},
    "prop_shelving_janitor": {"fn": "shelving", "w": 1.2, "d": 0.5, "h": 1.8, "load": "cleaning",
                              "cat": {"kind": "shelving", "place": "wall", "support": True, "group": _G}},
    # quay / yard
    "prop_net_pile": {"fn": "net_pile", "w": 1.8, "d": 1.2, "h": 1.2, "cat": {"kind": "nets", "place": "wall", "group": _G}},
    "prop_net_pile_low": {"fn": "net_pile", "w": 2.0, "d": 1.5, "h": 1.0, "cat": {"kind": "nets", "place": "wall", "group": _G}},
    "prop_rope_reels": {"fn": "rope_reels", "cat": {"kind": "rope_reel", "place": "wall", "group": _G}},
    "prop_ice_bins": {"fn": "ice_bins", "cat": {"kind": "ice_bins", "place": "wall", "group": _G}},
    "prop_skip": {"fn": "skip", "cat": {"kind": "skip", "place": "wall", "group": _G}},
    "veh_reach_stacker": {"fn": "reach_stacker", "cat": {"kind": "vehicle", "place": "none", "group": _G}},
    "veh_reefer_trailer": {"fn": "reefer_trailer", "cat": {"kind": "vehicle", "place": "none", "group": _G}},
    "veh_flatbed_trailer": {"fn": "flatbed", "cat": {"kind": "vehicle", "place": "none", "group": _G}},
    "prop_ibc_tote": {"fn": "ibc", "cat": {"kind": "tote", "place": "wall", "group": _G}},
    "prop_traffic_cone": {"fn": "cone", "cat": {"kind": "cone", "place": "floor", "group": _G}},
    "prop_pallet_stack": {"fn": "pallet_stack", "cat": {"kind": "pallet", "place": "wall", "group": _G}},
    # offices
    "prop_desk_dispatch": {"fn": "desk", "w": 2.4, "d": 0.8, "h": 0.75, "cat": {"kind": "desk", "place": "wall",
                                                                              "support": True, "clear": 1.0, "group": _G}},
    "prop_table_canteen": {"fn": "canteen_table", "cat": {"kind": "table", "place": "center", "support": True, "clear": 0.7,
                                                          "group": _G}},
    "prop_counter_reception_w300": {"fn": "counter", "w": 3.0, "d": 0.6, "style": "reception",
                                    "cat": {"kind": "counter_service", "place": "wall", "support": True, "top": 0.9,
                                            "group": _G}},
    "prop_counter_break_w220": {"fn": "counter", "w": 2.2, "d": 0.6, "style": "kitchen",
                                "cat": {"kind": "kitchen_counter", "place": "wall", "support": True, "top": 0.9, "group": _G}},
    "prop_counter_count_w240": {"fn": "counter", "w": 2.4, "d": 1.0, "style": "count",
                                "cat": {"kind": "counter_service", "place": "center", "support": True, "top": 0.9,
                                        "group": _G}},
    "prop_counter_tool_w200": {"fn": "counter", "w": 2.0, "d": 0.7, "style": "tool",
                               "cat": {"kind": "counter_service", "place": "wall", "support": True, "top": 0.9, "group": _G}},
    "prop_counter_console_w160": {"fn": "counter", "w": 1.6, "d": 0.7, "style": "console",
                                  "cat": {"kind": "counter_service", "place": "wall", "support": True, "top": 0.9,
                                          "group": _G}},
    "prop_lockers_bank_w300": {"fn": "locker_bank", "cat": {"kind": "lockers", "place": "wall", "clear": 0.8, "group": _G}},
    "prop_bench_locker": {"fn": "bench_locker", "cat": {"kind": "bench", "place": "wall", "clear": 0.6, "group": _G}},
    "prop_gun_locker": {"fn": "gun_locker", "cat": {"kind": "gun_locker", "place": "wall", "clear": 0.8, "group": _G}},
    "prop_radiator_heater": {"fn": "radiator", "cat": {"kind": "heater", "place": "wall", "group": _G}},
    "prop_basin_pedestal": {"fn": "basin", "cat": {"kind": "sink", "place": "wall", "clear": 0.6, "group": _G}},
    "prop_hose_reel": {"fn": "hose_reel", "cat": {"kind": "hose_reel", "place": "wall_mount", "z": 1.3, "group": _G}},
    "prop_life_ring": {"fn": "life_ring", "cat": {"kind": "life_ring", "place": "wall_mount", "z": 1.5, "group": _G}},
    # fixtures
    "prop_highbay_led": {"fn": "highbay", "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True, "group": _G,
                                                  "light": {"type": "spot", "color": HALL, "energy": 3.0, "range": 9.0,
                                                            "angle": 70, "pos": [0.0, -0.32, 0.0]}}},
    "prop_led_batten_cold": {"fn": "batten", "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True,
                                                     "group": _G,
                                                     "light": {"type": "spot", "color": COLD, "energy": 2.6, "range": 9.5,
                                                               "angle": 75, "pos": [0.0, -0.09, 0.0]}}},
    "prop_mast_sodium": {"fn": "mast", "cat": {"kind": "lamp_post", "place": "none", "group": _G}},
    "prop_fish_blocks": {"fn": "fish_blocks", "cat": {"kind": "fish_blocks", "place": "wall", "group": _G}},
    "prop_product_pallet": {"fn": "product_pallet", "cat": {"kind": "pallet_product", "place": "wall", "support": True,
                                                            "group": _G}},
    "prop_bulkhead_caged": {"fn": "bulkhead", "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True,
                                                      "group": _G,
                                                      "light": {"type": "omni", "color": BULKHEAD, "energy": 1.4, "range": 6.0,
                                                                "pos": [0.0, -0.26, 0.0]}}},
}
VARIANTS = {k: {**v, "cat": {**v["cat"], "pin_only": True}} for k, v in BASE_VARIANTS.items()}


def _wheel(p, x: float, y: float, r: float, w: float) -> None:
    """Tyre (axis X) with a hub, bottom on z 0."""
    p.cyl(r, w, (x, y, r), "rubber", axis="X", segs=16)
    p.cyl(r * 0.55, w + 0.01, (x, y, r), "metal_dark", axis="X", segs=12)


# ------------------------------------------------------------------------------------- plant / workshop

def _forklift(k: Kit, p: dict) -> None:
    """Counterbalance forklift 1.19 x 2.59 x 2.09 m: orange body, rear counterweight, overhead guard, mast and forks
    to the front (+Y)."""
    o = k.obj("Forklift")
    b = o.part(bevel=0.015, segments=2)
    b.bx((-0.55, -1.0, 0.18), (0.55, 0.45, 0.95), "metal_orange")
    b.bx((-0.56, -1.29, 0.12), (0.56, -0.9, 1.15), "metal_dark")
    b.bx((-0.25, -0.45, 0.95), (0.25, 0.05, 1.05), "metal_dark")
    b.bx((-0.22, -0.55, 1.05), (0.22, -0.4, 1.45), "plastic_black")
    b.bx((-0.22, -0.42, 1.05), (0.22, -0.05, 1.12), "plastic_black")
    g = o.part(bevel=0.0)
    for sx in (-0.5, 0.5):
        g.rod((sx, -0.7, 0.95), (sx, -0.7, 2.05), 0.035, "metal_dark", segs=8)
        g.rod((sx, 0.35, 0.95), (sx, 0.3, 2.05), 0.035, "metal_dark", segs=8)
    g.bx((-0.54, -0.74, 2.02), (0.54, 0.34, 2.08), "metal_dark")
    for i in range(5):
        y = -0.6 + i * 0.22
        g.bx((-0.5, y, 2.0), (0.5, y + 0.03, 2.02), "metal_dark")
    g.rod((0.0, 0.1, 1.1), (0.0, -0.1, 1.35), 0.012, "metal_dark", segs=6)
    g.torus(0.13, 0.015, (0.0, -0.08, 1.38), "plastic_black", segs=16, rsegs=5, axis="X")
    m = o.part(bevel=0.0)
    for sx in (-0.35, 0.35):
        m.bx((sx - 0.05, 0.5, 0.12), (sx + 0.05, 0.62, 2.07), "metal_dark")
    m.bx((-0.4, 0.62, 0.1), (0.4, 0.68, 0.7), "metal_dark")
    for sx in (-0.28, 0.28):
        m.bx((sx - 0.06, 0.62, 0.02), (sx + 0.06, 1.29, 0.07), "metal_dark")
        m.bx((sx - 0.06, 0.62, 0.02), (sx + 0.06, 0.68, 0.7), "metal_dark")
    m.rod((0.0, 0.56, 0.2), (0.0, 0.56, 1.9), 0.04, "steel", segs=10)
    w = o.part(bevel=0.0)
    for sx in (-0.47, 0.47):
        _wheel(w, sx, 0.3, 0.28, 0.2)
        _wheel(w, sx, -0.95, 0.22, 0.18)
    e = o.part(bevel=0.0)
    e.sphere(0.06, (0.0, -0.2, 2.13 - 0.06), "emit_amber", segs=10, rings=5)
    e.bx((-0.45, 0.32, 1.9), (-0.35, 0.36, 1.98), "emit_cool")
    e.bx((0.35, 0.32, 1.9), (0.45, 0.36, 1.98), "emit_cool")
    o.build()


def _compressor(k: Kit, p: dict) -> None:
    """Ammonia screw-compressor skid 1.59 x 2.59 x 1.79 m: steel skid, motor, screw block, oil separator vessel on top,
    suction / discharge pipework and a local control box on the front."""
    o = k.obj("Compressor")
    s = o.part(bevel=0.006)
    s.bx((-0.79, -1.29, 0.0), (0.79, 1.29, 0.16), "metal_dark")
    s.bx((-0.3, -1.15, 0.16), (0.3, -0.2, 0.3), "metal_dark")
    s.bx((-0.4, 0.0, 0.16), (0.4, 1.0, 0.75), "metal_green")
    s.bx((0.42, 0.9, 0.3), (0.75, 1.28, 1.2), "metal_grey")
    c = o.part(bevel=0.0)
    c.cyl(0.36, 0.95, (0.0, -0.7, 0.68), "metal_green", axis="Y", segs=20)
    for i in range(10):
        y = -1.12 + i * 0.09
        c.cyl(0.38, 0.02, (0.0, y, 0.68), "metal_green", axis="Y", segs=20)
    c.cyl(0.1, 0.25, (0.0, -0.15, 0.68), "steel", axis="Y", segs=12)
    c.cyl(0.3, 2.2, (-0.25, 0.0, 1.45), "metal_green", axis="Y", segs=20)
    c.sphere(0.3, (-0.25, 1.1, 1.45), "metal_green", segs=20, rings=8, scale=(1.0, 0.45, 1.0))
    c.sphere(0.3, (-0.25, -1.1, 1.45), "metal_green", segs=20, rings=8, scale=(1.0, 0.45, 1.0))
    for y in (-0.8, 0.8):
        c.bx((-0.5, y - 0.05, 0.75), (0.0, y + 0.05, 1.2), "metal_dark")
    pi = o.part(bevel=0.0)
    pi.tube([(0.2, 0.5, 0.75), (0.2, 0.5, 1.3), (0.55, 0.5, 1.3), (0.55, -0.6, 1.3), (0.55, -0.6, 1.75)], 0.06, "steel",
            segs=10)
    pi.tube([(-0.25, -1.2, 1.45), (-0.6, -1.2, 1.45), (-0.6, -1.2, 0.3)], 0.045, "steel", segs=10)
    pi.cyl(0.09, 0.03, (0.55, -0.6, 1.0), "metal_red", axis="Z", segs=12)
    pi.cyl(0.05, 0.02, (0.4, 1.285, 1.0), "metal_white", axis="Y", segs=12)
    e = o.part(bevel=0.0)
    for i, key in enumerate(("emit_led_green", "emit_led_green", "emit_amber")):
        e.bx((0.48 + i * 0.07, 1.284, 1.08), (0.52 + i * 0.07, 1.287, 1.11), key)
    e.bx((0.48, 1.284, 0.82), (0.69, 1.287, 0.95), "emit_screen")
    o.build()


def _receiver(k: Kit, p: dict) -> None:
    """Horizontal ammonia receiver 2.99 x 1.19 x 1.59 m on two saddles: dished ends, sight glass, relief valves."""
    o = k.obj("Receiver")
    v = o.part(bevel=0.0)
    r, ln = 0.52, 2.3
    v.cyl(r, ln, (0.0, 0.0, 0.92), "metal_white", axis="X", segs=24)
    for sx in (-1, 1):
        v.sphere(r, (sx * ln / 2, 0.0, 0.92), "metal_white", segs=24, rings=10, scale=(0.6, 1.0, 1.0))
    for x in (-0.7, 0.7):
        v.bx((x - 0.12, -0.45, 0.0), (x + 0.12, 0.45, 0.62), "metal_dark")
    v.bx((-1.0, -0.5, 0.0), (1.0, 0.5, 0.04), "metal_dark")
    pi = o.part(bevel=0.0)
    for x in (-0.4, 0.3):
        pi.rod((x, 0.0, 1.4), (x, 0.0, 1.58), 0.04, "steel", segs=10)
        pi.cyl(0.07, 0.04, (x, 0.0, 1.5), "metal_red", segs=12)
    pi.rod((0.95, -0.2, 0.5), (0.95, -0.2, 1.35), 0.025, "glass", segs=8)
    pi.cyl(0.05, 0.3, (-1.35, 0.0, 0.92), "steel", axis="X", segs=10)
    o.build()


def _plant_panel(k: Kit, p: dict) -> None:
    """Refrigeration control panel 1.99 x 0.39 x 1.99 m: three cabinet doors, a touch screen, indicator LEDs."""
    w, d, h = 1.99, 0.39, 1.99
    o = k.obj("Panel")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -d / 2, 0.1), (w / 2, d / 2 - 0.01, h), "metal_grey")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.04, 0.1), "metal_dark")
    t = o.part(bevel=0.0)
    for i in range(3):
        x0 = -w / 2 + 0.02 + i * (w - 0.04) / 3
        x1 = x0 + (w - 0.04) / 3 - 0.01
        t.bx((x0, d / 2 - 0.01, 0.14), (x1, d / 2, h - 0.04), "metal_grey")
        t.bx((x1 - 0.06, d / 2, 0.95), (x1 - 0.03, d / 2 + 0.03, 1.15), "metal_dark")
    e = o.part(bevel=0.0)
    e.bx((-0.28, d / 2, 1.3), (0.28, d / 2 + 0.003, 1.65), "emit_screen")
    for i in range(8):
        key = "emit_led_green" if i % 3 else "emit_led_red"
        x = -0.85 + i * 0.07
        e.cyl(0.015, 0.006, (x, d / 2 + 0.003, 1.75), key, axis="Y", segs=8)
        e.cyl(0.015, 0.006, (0.4 + i * 0.06, d / 2 + 0.003, 1.75), "emit_led_green", axis="Y", segs=8)
    o.build()


def _switchboard(k: Kit, p: dict) -> None:
    """Main LV switchboard 1.59 x 0.39 x 1.99 m: four cubicle doors with meters and handles."""
    w, d, h = 1.59, 0.39, 1.99
    o = k.obj("Board")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2 - 0.01, h), "metal_grey")
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2 - 0.04, 0.08), "metal_dark")
    t = o.part(bevel=0.0)
    for i in range(4):
        x0 = -w / 2 + 0.01 + i * (w - 0.02) / 4
        x1 = x0 + (w - 0.02) / 4 - 0.008
        t.bx((x0, d / 2 - 0.01, 0.1), (x1, d / 2, h - 0.02), "metal_grey")
        t.cyl(0.04, 0.01, ((x0 + x1) / 2, d / 2 + 0.005, 1.6), "metal_white", axis="Y", segs=12)
        t.bx((x1 - 0.05, d / 2, 0.9), (x1 - 0.03, d / 2 + 0.03, 1.1), "metal_dark")
        t.bx((x0 + 0.05, d / 2, 1.85), (x0 + 0.2, d / 2 + 0.003, 1.9), "metal_yellow")
    o.build()


def _battery_rack(k: Kit, p: dict) -> None:
    """Traction-battery charging rack 0.79 x 2.39 x 1.2 m: steel frame, four battery boxes, chargers on the top shelf."""
    w, d, h = 0.79, 2.39, 1.2
    o = k.obj("Rack")
    f = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 0, 1):
            x = sx * (w / 2 - 0.03)
            y = sy * (d / 2 - 0.03)
            f.bx((x - 0.03, y - 0.03, 0.0), (x + 0.03, y + 0.03, h - 0.04), "metal_yellow")
    for z in (0.08, 0.62):
        f.bx((-w / 2, -d / 2, z), (w / 2, d / 2, z + 0.04), "metal_dark")
    f.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), "metal_dark")
    b = o.part(bevel=0.006)
    for i in range(4):
        y0 = -d / 2 + 0.06 + i * 0.58
        b.bx((-0.33, y0, 0.12), (0.33, y0 + 0.5, 0.58), "metal_blue")
        b.bx((-0.25, y0 + 0.1, 0.58), (-0.1, y0 + 0.2, 0.61), "metal_red")
    for i in range(2):
        y0 = -0.95 + i * 1.1
        b.bx((-0.3, y0, 0.66), (0.3, y0 + 0.8, 1.1), "metal_grey")
    e = o.part(bevel=0.0)
    for i in range(2):
        y0 = -0.95 + i * 1.1
        e.bx((0.3, y0 + 0.1, 0.95), (0.303, y0 + 0.25, 1.02), "emit_led_green")
    o.build()


# ------------------------------------------------------------------------------------- packing / cold store

def _conveyor(k: Kit, p: dict) -> None:
    """Gravity roller conveyor 7.99 x 0.99 x 0.9 m: side rails, galvanised rollers (top at 0.9), legs, a motor box."""
    w, d, h = 7.99, 0.99, 0.9
    o = k.obj("Conveyor")
    f = o.part(bevel=0.0)
    for sy in (-1, 1):
        y = sy * (d / 2 - 0.04)
        f.bx((-w / 2, y - 0.04, h - 0.16), (w / 2, y + 0.04, h - 0.02), "steel")
    n = 5
    for i in range(n):
        x = -w / 2 + 0.2 + i * (w - 0.4) / (n - 1)
        for sy in (-1, 1):
            y = sy * (d / 2 - 0.06)
            f.bx((x - 0.03, y - 0.03, 0.0), (x + 0.03, y + 0.03, h - 0.16), "steel")
        f.bx((x - 0.025, -d / 2 + 0.06, 0.25), (x + 0.025, d / 2 - 0.06, 0.29), "steel")
    r = o.part(bevel=0.0)
    pitch = 0.16
    m = int((w - 0.1) / pitch)
    for i in range(m):
        x = -w / 2 + 0.05 + pitch * (i + 0.5)
        r.cyl(0.03, d - 0.16, (x, 0.0, h - 0.03), "steel", axis="Y", segs=8)
    b = o.part(bevel=0.005)
    b.bx((w / 2 - 0.9, d / 2 - 0.08, 0.35), (w / 2 - 0.5, d / 2 + 0.0, 0.6), "metal_blue")
    o.build()


def _packing_table(k: Kit, p: dict) -> None:
    """Stainless fish-packing table 1.99 x 0.79 x 0.9 m: dished top with an upstand, undershelf, round legs."""
    w, d, h = 1.99, 0.79, 0.9
    o = k.obj("Table")
    t = o.part(bevel=0.003)
    t.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), "steel")
    t.bx((-w / 2 + 0.06, -d / 2 + 0.06, 0.18), (w / 2 - 0.06, d / 2 - 0.06, 0.2), "steel")
    lg = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            lg.rod((sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0.0), (sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), h - 0.04),
                   0.022, "steel", segs=10)
    c = o.part(bevel=0.004)
    c.bx((-0.7, -0.3, 0.2), (-0.1, 0.1, 0.48), "plastic_blue")
    c.bx((0.2, -0.3, 0.2), (0.8, 0.1, 0.48), "plastic_blue")
    o.build()


def _ice_machine(k: Kit, p: dict) -> None:
    """Flake-ice machine on its storage bin 1.39 x 1.19 x 1.79 m: stainless bin with a lift-up door, the ice-maker
    head above, vent louvres."""
    w, d, h = 1.39, 1.19, 1.79
    o = k.obj("IceMachine")
    a = o.part(bevel=0.01, segments=2)
    a.bx((-w / 2, -d / 2, 0.12), (w / 2, d / 2, 1.1), "steel")
    a.bx((-w / 2 + 0.1, -d / 2 + 0.1, 1.1), (w / 2 - 0.1, d / 2 - 0.1, h), "steel")
    lg = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            lg.cyl(0.035, 0.12, (sx * (w / 2 - 0.1), sy * (d / 2 - 0.1), 0.06), "metal_dark", segs=10)
    t = o.part(bevel=0.0)
    t.bx((-0.5, d / 2, 0.55), (0.5, d / 2 + 0.01, 1.0), "steel")
    bar_handle(t, -0.3, 0.3, d / 2 + 0.01, 0.95, "metal_dark", r=0.012, standoff=0.03)
    for i in range(6):
        z = 1.25 + i * 0.07
        t.bx((-0.45, d / 2 - 0.1, z), (0.45, d / 2 - 0.095, z + 0.03), "metal_dark")
    e = o.part(bevel=0.0)
    e.bx((0.35, d / 2 - 0.095, 1.62), (0.45, d / 2 - 0.092, 1.68), "emit_led_green")
    o.build()


def _fish_box(p, x: float, y: float, z: float, w: float, d: float, h: float, key: str) -> None:
    p.bx((x - w / 2 + 0.01, y - d / 2 + 0.01, z), (x + w / 2 - 0.01, y + d / 2 - 0.01, z + h - 0.02), key)
    p.bx((x - w / 2, y - d / 2, z + h - 0.03), (x + w / 2, y + d / 2, z + h), key)


def _pallet(p, w: float, d: float, key: str = "wood_pine", z: float = 0.0, dx: float = 0.0) -> None:
    """Euro-style pallet w x d x 0.14 m (deck boards, blocks, bottom boards), bottom at z."""
    for sy in (-1, 0, 1):
        y = sy * (d / 2 - 0.05)
        p.bx((dx - w / 2, y - 0.05, z), (dx + w / 2, y + 0.05, z + 0.022), key)
        for sx in (-1, 0, 1):
            x = dx + sx * (w / 2 - 0.05)
            p.bx((x - 0.05, y - 0.05, z + 0.022), (x + 0.05, y + 0.05, z + 0.118), key)
    n = 7
    for i in range(n):
        x = dx - w / 2 + 0.05 + i * (w - 0.1) / (n - 1)
        p.bx((x - 0.05, -d / 2, z + 0.118), (x + 0.05, d / 2, z + 0.14), key)


def _fish_crates(k: Kit, p: dict) -> None:
    """Stacked fish boxes on a pallet 1.19 x 1.19 x 1.49 m: five layers of blue / grey 0.59 x 0.39 m boxes."""
    o = k.obj("Crates")
    pl = o.part(bevel=0.0)
    _pallet(pl, 1.18, 1.18)
    bx = o.part(bevel=0.0)
    layers = int(p.get("layers", 5))
    lh = (1.49 - 0.14) / layers
    for li in range(layers):
        z = 0.14 + li * lh
        rot = li % 2
        for i in range(2):
            for j in range(3):
                if rot:
                    x, y, bw, bd = -0.295 + i * 0.59, -0.39 + j * 0.39, 0.59, 0.39
                else:
                    x, y, bw, bd = -0.39 + j * 0.39, -0.295 + i * 0.59, 0.39, 0.59
                key = "plastic_blue" if (li + i + j) % 4 else "plastic_grey"
                _fish_box(bx, x, y, z, bw, bd, lh, key)
    o.build()


def _fish_box_stack(k: Kit, p: dict) -> None:
    """Three empty fish boxes, nested and slightly offset, 0.62 x 0.42 x 0.5 m (kit clutter)."""
    o = k.obj("Boxes")
    b = o.part(bevel=0.0)
    for i in range(3):
        key = ("plastic_blue", "plastic_blue", "plastic_white")[i]
        dx = (-0.005, 0.004, -0.002)[i]
        _fish_box(b, dx, 0.0, i * 0.16, 0.6, 0.4, 0.17, key)
    o.build()


def _carton_block(p, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, key: str) -> None:
    """A pallet load of cartons: the block with carton seams (thin proud bands)."""
    p.bx((x0, y0, z0), (x1, y1, z1), key)


def _racking(k: Kit, p: dict) -> None:
    """Double-sided cold-store pallet racking 2.69 x 9.19 x 6.59 m: 5 upright frames along the run, orange beams at
    0 / 2.2 / 4.4 / 6.5 m, frosted carton loads on pallets (some bays empty), a frosted back-to-back mesh spine."""
    w, d, h = 2.69, 9.19, 6.59
    o = k.obj("Racking")
    f = o.part(bevel=0.0)
    bays = 4
    pitch = d / bays
    for i in range(bays + 1):
        y = -d / 2 + 0.05 + i * (d - 0.1) / bays
        for x in (-w / 2 + 0.05, -0.08, 0.08, w / 2 - 0.05):
            f.bx((x - 0.045, y - 0.045, 0.0), (x + 0.045, y + 0.045, h), "metal_blue")
        for x0, x1 in ((-w / 2 + 0.05, -0.08), (0.08, w / 2 - 0.05)):
            for z in (0.6, 2.8, 5.0):
                f.bx((x0, y - 0.02, z), (x1, y + 0.02, z + 0.05), "metal_blue")
    bm = o.part(bevel=0.0)
    for i in range(bays):
        y0 = -d / 2 + 0.1 + i * pitch
        y1 = y0 + pitch - 0.1
        for z in (2.1, 4.3, 6.45):
            for x in (-w / 2 + 0.01, -0.13, 0.04, w / 2 - 0.1):
                bm.bx((x, y0, z), (x + 0.09, y1, z + 0.12), "metal_orange")
    ld = o.part(bevel=0.0)
    rng = k.ctx.rng
    for i in range(bays):
        y0 = -d / 2 + 0.2 + i * pitch
        for side, (x0, x1) in enumerate(((-w / 2 + 0.12, -0.15), (0.15, w / 2 - 0.12))):
            for lvl, z in enumerate((0.0, 2.22, 4.42)):
                for j in range(2):
                    if rng.random() < 0.18:
                        continue
                    ya = y0 + j * (pitch - 0.3) / 2
                    yb = ya + (pitch - 0.3) / 2 - 0.08
                    ld.bx((x0, ya, z), (x1, yb, z + 0.14), "wood_pine")
                    top = z + 0.14 + rng.uniform(1.0, 1.7)
                    _carton_block(ld, x0 + 0.03, x1 - 0.03, ya + 0.03, yb - 0.03, z + 0.14, top,
                                  "frost" if (i + side + lvl + j) % 3 else "cardboard_frost")
    o.build()


def _pallet_wrapped(k: Kit, p: dict) -> None:
    """Shrink-wrapped pallet 1.19 x 1.19 x 1.59 m: the wrapped load (frosted film over cartons) on a pallet."""
    o = k.obj("Pallet")
    pl = o.part(bevel=0.0)
    _pallet(pl, 1.18, 1.18)
    a = o.part(bevel=0.03, segments=2)
    a.bx((-0.58, -0.58, 0.14), (0.58, 0.58, 1.58), "shrink_wrap")
    t = o.part(bevel=0.0)
    t.bx((-0.25, 0.58, 0.9), (0.25, 0.583, 1.15), "paper")
    o.build()


def _wrapper(k: Kit, p: dict) -> None:
    """Pallet stretch wrapper 1.99 x 1.99 x 2.19 m: low turntable, mast at the back corner, film carriage, control
    pod."""
    o = k.obj("Wrapper")
    t = o.part(bevel=0.0)
    t.cyl(0.95, 0.09, (0.0, 0.1, 0.045), "metal_dark", segs=32)
    t.cyl(0.9, 0.02, (0.0, 0.1, 0.1), "steel", segs=32)
    m = o.part(bevel=0.006)
    m.bx((0.62, -0.99, 0.0), (0.99, -0.62, 2.19), "metal_blue")
    m.bx((0.5, -0.75, 0.6), (0.7, -0.45, 1.0), "metal_grey")
    m.cyl(0.06, 0.5, (0.6, -0.55, 0.8), "plastic_white", segs=12)
    m.bx((0.62, -0.62, 1.4), (0.92, -0.45, 1.75), "metal_grey")
    m.bx((-0.95, -0.99, 0.0), (0.62, -0.75, 0.09), "metal_dark")
    e = o.part(bevel=0.0)
    e.bx((0.66, -0.449, 1.55), (0.8, -0.446, 1.68), "emit_screen")
    e.cyl(0.025, 0.006, (0.86, -0.447, 1.5), "emit_led_red", axis="Y", segs=8)
    o.build()


def _pallet_jack(k: Kit, p: dict) -> None:
    """Hand pallet truck 0.59 x 1.59 x 1.19 m: forks to the front (+Y), pump unit and tow handle at the back."""
    o = k.obj("Jack")
    f = o.part(bevel=0.004)
    for sx in (-0.2, 0.2):
        f.bx((sx - 0.08, -0.35, 0.03), (sx + 0.08, 0.79, 0.085), "metal_red")
    f.bx((-0.29, -0.5, 0.03), (0.29, -0.3, 0.3), "metal_red")
    f.cyl(0.06, 0.3, (0.0, -0.42, 0.45), "metal_red", segs=12)
    w = o.part(bevel=0.0)
    for sx in (-0.2, 0.2):
        w.cyl(0.04, 0.06, (sx, 0.7, 0.04), "rubber", axis="X", segs=10)
    w.cyl(0.09, 0.06, (-0.12, -0.42, 0.09), "rubber", axis="X", segs=12)
    w.cyl(0.09, 0.06, (0.12, -0.42, 0.09), "rubber", axis="X", segs=12)
    h = o.part(bevel=0.0)
    h.rod((0.0, -0.45, 0.55), (0.0, -0.75, 1.1), 0.02, "metal_red", segs=8)
    h.torus(0.12, 0.018, (0.0, -0.78, 1.06), "plastic_black", segs=16, rsegs=6, axis="X")
    o.build()


def _shipping_crate(k: Kit, p: dict) -> None:
    """Battened timber shipping crate 1.19 x 1.19 x h m with stencilled side boards."""
    h = float(p["h"]) - 0.005
    w = 1.19
    o = k.obj("Crate")
    a = o.part(bevel=0.003)
    a.bx((-w / 2 + 0.02, -w / 2 + 0.02, 0.0), (w / 2 - 0.02, w / 2 - 0.02, h - 0.02), "wood_pine")
    a.bx((-w / 2, -w / 2, h - 0.02), (w / 2, w / 2, h), "wood_pine")
    b = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.bx((sx * w / 2 - 0.08 * (sx > 0), sy * w / 2 - 0.08 * (sy > 0), 0.0),
                 (sx * w / 2 + 0.08 * (sx < 0), sy * w / 2 + 0.08 * (sy < 0), h - 0.02), "wood_oak")
    for z in (0.05, h * 0.5 - 0.04, h - 0.11):
        for sy in (-1, 1):
            y0, y1 = sorted((sy * (w / 2 - 0.02), sy * w / 2))
            b.bx((-w / 2 + 0.08, y0, z), (w / 2 - 0.08, y1, z + 0.08), "wood_oak")
        for sx in (-1, 1):
            x0, x1 = sorted((sx * (w / 2 - 0.02), sx * w / 2))
            b.bx((x0, -w / 2 + 0.08, z), (x1, w / 2 - 0.08, z + 0.08), "wood_oak")
    s = o.part(bevel=0.0)
    s.bx((-0.3, w / 2, h * 0.62), (0.3, w / 2 + 0.002, h * 0.62 + 0.12), "plastic_black")
    o.build()


def _shelving(k: Kit, p: dict) -> None:
    """Steel shelving w x d x h, four shelves; `fish`: frozen fish blocks and cartons, `cleaning`: chemicals, mop
    buckets, rolls."""
    w, d, h = float(p["w"]) - 0.01, float(p["d"]) - 0.01, float(p["h"]) - 0.005
    load = p["load"]
    o = k.obj("Shelving")
    f = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.02), sy * (d / 2 - 0.02)
            f.bx((x - 0.02, y - 0.02, 0.0), (x + 0.02, y + 0.02, h), "metal_grey")
    levels = [0.1, 0.6, 1.1, h - 0.03] if h > 1.85 else [0.1, 0.6, 1.1, h - 0.03]
    for z in levels:
        f.bx((-w / 2, -d / 2, z), (w / 2, d / 2, z + 0.03), "metal_grey")
    s = o.part(bevel=0.0)
    rng = k.ctx.rng
    for z in levels[:-1]:
        x = -w / 2 + 0.06
        while x < w / 2 - 0.3:
            bw = rng.uniform(0.18, 0.4)
            bh = rng.uniform(0.12, 0.36)
            if load == "fish":
                key = ("frost", "cardboard_frost", "frost")[int(rng.random() * 3) % 3]
                s.bx((x, -d / 2 + 0.05, z + 0.03), (x + bw, d / 2 - 0.05, z + 0.03 + bh), key)
            else:
                key = ("plastic_blue", "plastic_white", "metal_red", "plastic_grey")[int(rng.random() * 4) % 4]
                r = min(bw, d - 0.1) * 0.35
                s.cyl(r, bh, (x + bw / 2, 0.0, z + 0.03 + bh / 2), key, segs=12)
            x += bw + 0.04
    o.build()


# ------------------------------------------------------------------------------------- quay / yard

def _net_pile(k: Kit, p: dict) -> None:
    """A heap of green trawl net with orange floats and a coil of rope, w x d x h."""
    w, d, h = float(p["w"]) - 0.02, float(p["d"]) - 0.02, float(p["h"]) - 0.01
    o = k.obj("Nets")
    n = o.part(bevel=0.0)
    rng = k.ctx.rng
    lumps = [(0.0, 0.0, 0.0, w / 2, d / 2, h * 0.55)]
    for _ in range(6):
        sx, sy = rng.uniform(0.35, 0.55), rng.uniform(0.35, 0.55)
        rx, ry = w / 2 * sx, d / 2 * sy
        cx = rng.uniform(-w / 2 + rx, w / 2 - rx)
        cy = rng.uniform(-d / 2 + ry, d / 2 - ry)
        lumps.append((cx, cy, h * 0.25, rx, ry, h * rng.uniform(0.5, 0.75)))
    for cx, cy, cz, rx, ry, rz in lumps:
        top = min(h, cz + rz)
        n.lathe([(rx, 0.0), (rx * 0.98, (top - cz) * 0.3), (rx * 0.8, (top - cz) * 0.7), (rx * 0.35, (top - cz) * 0.95),
                 (0.0, top - cz)], "net_green", centre=(cx, cy, cz if cz > 0 else 0.0), segs=12, scale_xy=(1.0, ry / rx))
    fl = o.part(bevel=0.0)
    for i in range(7):
        a = 2 * math.pi * i / 7 + rng.uniform(-0.3, 0.3)
        x, y = math.cos(a) * w * 0.38, math.sin(a) * d * 0.38
        fl.sphere(0.08, (x, y, rng.uniform(0.25, 0.5) * h), "metal_orange", segs=10, rings=6)
    fl.torus(min(w, d) * 0.18, 0.025, (w * 0.2, -d * 0.15, h * 0.93), "rope_tan", segs=20, rsegs=5)
    o.build()


def _rope_reels(k: Kit, p: dict) -> None:
    """Two cable-drum reels of mooring rope 1.59 x 0.99 x 0.89 m (axis X) on chocks."""
    o = k.obj("Reels")
    a = o.part(bevel=0.0)
    r = 0.44
    for cx in (-0.39, 0.39):
        for sx in (-0.33, 0.33):
            a.cyl(r, 0.04, (cx + sx, 0.0, r), "wood_pine", axis="X", segs=24)
        a.cyl(r * 0.82, 0.62, (cx, 0.0, r), "rope_tan", axis="X", segs=24)
        a.cyl(0.06, 0.74, (cx, 0.0, r), "metal_dark", axis="X", segs=10)
        for sy in (-1, 1):
            a.bx((cx - 0.36, sy * 0.36 - 0.06, 0.0), (cx + 0.36, sy * 0.36 + 0.06, 0.08), "wood_oak")
    o.build()


def _ice_bins(k: Kit, p: dict) -> None:
    """Two insulated fish tubs (1.1 m square, lidded) stacked on a pallet, 1.19 x 1.19 x 1.19 m."""
    o = k.obj("Bins")
    pl = o.part(bevel=0.0)
    _pallet(pl, 1.18, 1.18)
    b = o.part(bevel=0.02, segments=2)
    for i in range(2):
        z = 0.14 + i * 0.52
        b.bx((-0.55, -0.55, z), (0.55, 0.55, z + 0.47), "ice_blue")
        b.bx((-0.57, -0.57, z + 0.47), (0.57, 0.57, z + 0.52), "ice_blue")
    t = o.part(bevel=0.0)
    for i in range(2):
        z = 0.14 + i * 0.52
        t.bx((-0.4, 0.55, z + 0.15), (0.4, 0.552, z + 0.3), "plastic_white")
    o.build()


def _skip(k: Kit, p: dict) -> None:
    """Builder's skip 1.59 x 3.19 x 1.39 m (long axis Y): sloped ends, lifting lugs, rust paint, scrap inside."""
    w, d, h = 1.59, 3.19, 1.39
    o = k.obj("Skip")
    a = o.part(bevel=0.0)
    a.profile_x([(-1.0, 0.0), (1.0, 0.0), (d / 2, h - 0.04), (-d / 2, h - 0.04)], -w / 2 + 0.06, w / 2 - 0.06, "metal_yellow")
    a.profile_x([(-d / 2, h - 0.06), (d / 2, h - 0.06), (d / 2, h), (-d / 2, h)], -w / 2, w / 2, "metal_dark")
    l = o.part(bevel=0.0)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 - 0.06), sx * (w / 2 - 0.001)))
        for y in (-0.7, 0.7):
            l.bx((x0, y - 0.08, 0.6), (x1, y + 0.08, 0.95), "metal_dark")
    s = o.part(bevel=0.0)
    s.bx((-0.5, -1.0, h - 0.05), (0.3, 0.2, h - 0.03), "rubber")
    s.bx((-0.2, 0.3, h - 0.05), (0.6, 1.1, h - 0.035), "wood_pine")
    o.build()


def _reach_stacker(k: Kit, p: dict) -> None:
    """Container reach stacker 2.99 x 6.99 x 3.49 m: chassis on four big tyres, cab on the left, the boom raised over
    the front (+Y) with a parked spreader."""
    o = k.obj("Stacker")
    c = o.part(bevel=0.02, segments=2)
    c.bx((-1.25, -3.4, 0.6), (1.25, 1.8, 1.4), "metal_yellow")
    c.bx((-1.3, -3.49, 0.5), (1.3, -2.7, 1.9), "metal_dark")
    c.bx((-1.3, -0.4, 1.4), (-0.3, 0.9, 3.0), "metal_yellow")
    g = o.part(bevel=0.0)
    for x0, x1 in ((-1.27, -1.26), (-0.32, -0.31)):
        g.bx((x0, -0.3, 2.0), (x1, 0.8, 2.85), "glass_tinted")
    g.bx((-1.2, 0.9, 2.0), (-0.4, 0.91, 2.85), "glass_tinted")
    b = o.part(bevel=0.0)
    b.profile_x([(-2.6, 1.4), (-2.0, 1.4), (3.0, 3.1), (3.0, 3.45), (2.6, 3.45), (-2.6, 1.9)], -0.1, 0.9, "metal_yellow")
    b.rod((0.4, -0.5, 1.4), (0.4, 1.2, 2.6), 0.14, "steel", segs=10)
    b.bx((-1.45, 2.8, 2.9), (1.45, 3.45, 3.45), "metal_yellow")
    for sx in (-1.4, 1.4):
        b.bx((sx - 0.05, 2.9, 2.6), (sx + 0.05, 3.4, 2.9), "metal_dark")
    w = o.part(bevel=0.0)
    for sx in (-1.15, 1.15):
        for y in (0.9, -2.4):
            w.cyl(0.62, 0.55, (sx, y, 0.62), "rubber", axis="X", segs=20)
            w.cyl(0.32, 0.56, (sx, y, 0.62), "metal_dark", axis="X", segs=14)
    e = o.part(bevel=0.0)
    e.sphere(0.09, (-0.8, 0.2, 3.1), "emit_amber", segs=10, rings=5)
    for sx in (-0.9, 0.9):
        e.bx((sx - 0.12, 1.801, 1.0), (sx + 0.12, 1.804, 1.15), "emit_cool")
    o.build()


def _reefer_trailer(k: Kit, p: dict) -> None:
    """Refrigerated semi-trailer 2.49 x 12.99 x 3.99 m: white insulated box, the reefer unit on the front (+Y) end,
    landing legs, a triple-axle rear bogie, rear doors with locking bars."""
    w, d, h = 2.49, 12.99, 3.99
    o = k.obj("Trailer")
    b = o.part(bevel=0.02, segments=2)
    b.bx((-w / 2, -d / 2, 1.2), (w / 2, d / 2 - 0.4, h - 0.02), "trailer_white")
    b.bx((-1.0, d / 2 - 0.4, 1.8), (1.0, d / 2 - 0.01, 3.6), "metal_grey")
    r = o.part(bevel=0.0)
    for i in range(14):
        y = -d / 2 + 0.4 + i * (d - 0.8) / 13
        for sx in (-1, 1):
            x0, x1 = sorted((sx * (w / 2 - 0.01), sx * (w / 2 + 0.004)))
            r.bx((x0, y - 0.03, 1.25), (x1, y + 0.03, h - 0.08), "metal_grey")
    ch = o.part(bevel=0.0)
    for sx in (-0.5, 0.5):
        ch.bx((sx - 0.08, -d / 2 + 0.2, 0.95), (sx + 0.08, d / 2 - 0.6, 1.2), "metal_dark")
    for sx in (-0.6, 0.6):
        ch.bx((sx - 0.06, 2.6, 0.0), (sx + 0.06, 2.75, 1.0), "metal_dark")
        ch.bx((sx - 0.15, 2.55, 0.0), (sx + 0.15, 2.8, 0.03), "metal_dark")
    ch.bx((-w / 2, -d / 2, 0.85), (w / 2, -d / 2 + 0.15, 1.0), "metal_red")
    wh = o.part(bevel=0.0)
    for i in range(3):
        y = -d / 2 + 1.2 + i * 1.3
        for sx in (-1.0, 1.0):
            wh.cyl(0.5, 0.45, (sx * 0.95, y, 0.5), "rubber", axis="X", segs=18)
            wh.cyl(0.28, 0.46, (sx * 0.95, y, 0.5), "steel", axis="X", segs=12)
    dr = o.part(bevel=0.0)
    dr.bx((-0.01, -d / 2 - 0.004, 1.25), (0.01, -d / 2, h - 0.08), "metal_dark")
    for x in (-0.8, -0.3, 0.3, 0.8):
        dr.rod((x, -d / 2 - 0.03, 1.3), (x, -d / 2 - 0.03, h - 0.12), 0.018, "steel", segs=8)
    o.build()


def _flatbed(k: Kit, p: dict) -> None:
    """Flatbed trailer 2.39 x 6.99 x 1.39 m: timber deck on steel side rails, tandem axle, a strapped crate load."""
    w, d = 2.39, 6.99
    o = k.obj("Flatbed")
    a = o.part(bevel=0.0)
    a.bx((-w / 2, -d / 2, 1.0), (w / 2, d / 2, 1.05), "metal_dark")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 1.05), (w / 2 - 0.02, d / 2 - 0.02, 1.1), "wood_oak")
    for sx in (-0.45, 0.45):
        a.bx((sx - 0.08, -d / 2 + 0.1, 0.75), (sx + 0.08, d / 2 - 0.1, 1.0), "metal_dark")
    for sx in (-0.5, 0.5):
        a.bx((sx - 0.06, d / 2 - 1.6, 0.0), (sx + 0.06, d / 2 - 1.45, 0.75), "metal_dark")
        a.bx((sx - 0.15, d / 2 - 1.65, 0.0), (sx + 0.15, d / 2 - 1.4, 0.03), "metal_dark")
    wh = o.part(bevel=0.0)
    for y in (-d / 2 + 1.2, -d / 2 + 2.3):
        for sx in (-1.0, 1.0):
            wh.cyl(0.42, 0.4, (sx * 0.92, y, 0.42), "rubber", axis="X", segs=18)
            wh.cyl(0.24, 0.41, (sx * 0.92, y, 0.42), "steel", axis="X", segs=12)
    c = o.part(bevel=0.004)
    c.bx((-0.9, -2.5, 1.1), (0.9, -0.9, 1.38), "wood_pine")
    c.bx((-0.6, 0.2, 1.1), (0.6, 1.4, 1.38), "metal_blue")
    s = o.part(bevel=0.0)
    for y in (-2.0, -1.4):
        s.bx((-0.905, y - 0.025, 1.1), (0.905, y + 0.025, 1.385), "metal_orange")
    o.build()


def _ibc(k: Kit, p: dict) -> None:
    """IBC tote 0.99 x 1.19 x 1.14 m: white bottle in a galvanised cage on a pallet base, tap on the front."""
    o = k.obj("Tote")
    a = o.part(bevel=0.04, segments=2)
    a.bx((-0.46, -0.56, 0.15), (0.46, 0.56, 1.06), "plastic_white")
    c = o.part(bevel=0.0)
    c.bx((-0.495, -0.595, 0.0), (0.495, 0.595, 0.15), "metal_grey")
    for x in (-0.48, -0.16, 0.16, 0.48):
        for sy in (-1, 1):
            c.rod((x, sy * 0.58, 0.15), (x, sy * 0.58, 1.12), 0.012, "metal_grey", segs=6)
    for y in (-0.58, -0.2, 0.2, 0.58):
        for sx in (-1, 1):
            c.rod((sx * 0.48, y, 0.15), (sx * 0.48, y, 1.12), 0.012, "metal_grey", segs=6)
    for z in (0.5, 0.85, 1.12):
        c.tube([(-0.48, -0.58, z), (0.48, -0.58, z), (0.48, 0.58, z), (-0.48, 0.58, z)], 0.012, "metal_grey", segs=6,
               closed=True, joints=False)
    c.cyl(0.08, 0.04, (0.0, 0.0, 1.12), "plastic_black", segs=12)
    c.cyl(0.04, 0.08, (0.0, 0.6, 0.25), "plastic_black", axis="Y", segs=10)
    o.build()


def _cone(k: Kit, p: dict) -> None:
    """Traffic cone 0.36 x 0.36 x 0.7 m: orange with a reflective band, square black base."""
    o = k.obj("Cone")
    a = o.part(bevel=0.0)
    a.bx((-0.18, -0.18, 0.0), (0.18, 0.18, 0.03), "plastic_black")
    a.lathe([(0.15, 0.03), (0.11, 0.25), (0.082, 0.4), (0.03, 0.7), (0.0, 0.7)], "metal_orange", segs=16)
    a.lathe([(0.083, 0.38), (0.068, 0.48), (0.0681, 0.48)], "plastic_white", segs=16)
    o.build()


def _pallet_stack(k: Kit, p: dict) -> None:
    """Seven empty pallets stacked, 1.18 x 0.78 x 0.98 m, slightly askew."""
    o = k.obj("Stack")
    for i in range(7):
        a = o.part(bevel=0.0)
        _pallet(a, 1.16, 0.78, z=i * 0.14, dx=((i * 37) % 5 - 2) * 0.004)
    o.build()


# ------------------------------------------------------------------------------------- offices

def _desk(k: Kit, p: dict) -> None:
    """Steel dispatch desk w x d, top at h: grey laminate top, modesty panel, a drawer pedestal (user side +Y)."""
    w, d, h = float(p["w"]) - 0.01, float(p["d"]) - 0.01, float(p["h"])
    o = k.obj("Desk")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h), "laminate_grey")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 - 0.02), sx * (w / 2 - 0.06)))
        a.bx((x0, -d / 2 + 0.03, 0.0), (x1, d / 2 - 0.03, h - 0.03), "powder_charcoal")
    a.bx((-w / 2 + 0.06, -d / 2 + 0.03, 0.25), (w / 2 - 0.06, -d / 2 + 0.05, h - 0.03), "powder_charcoal")
    a.bx((w / 2 - 0.5, -d / 2 + 0.06, 0.0), (w / 2 - 0.08, d / 2 - 0.06, h - 0.04), "metal_grey")
    t = o.part(bevel=0.0)
    for i in range(3):
        z = 0.08 + i * 0.22
        bar_handle(t, w / 2 - 0.36, w / 2 - 0.22, d / 2 - 0.06, z + 0.15, "steel", r=0.006, standoff=0.02)
    o.build()


def _canteen_table(k: Kit, p: dict) -> None:
    """Canteen table 1.59 x 0.89 m, top at 0.75: laminate top on two steel T-legs."""
    w, d, h = 1.59, 0.89, 0.75
    o = k.obj("Table")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h), "laminate_grey")
    lg = o.part(bevel=0.0)
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.25)
        lg.bx((x - 0.04, -0.04, 0.03), (x + 0.04, 0.04, h - 0.03), "powder_charcoal")
        lg.bx((x - 0.04, -d / 2 + 0.08, 0.0), (x + 0.04, d / 2 - 0.08, 0.03), "powder_charcoal")
    lg.bx((-w / 2 + 0.25, -0.03, h - 0.1), (w / 2 - 0.25, 0.03, h - 0.03), "powder_charcoal")
    o.build()


def _counter(k: Kit, p: dict) -> None:
    """Counter w x d, work top at 0.9 m. Styles: reception (laminate top, raised front transaction shelf would exceed
    the 0.9 service rule, so a flush front panel), kitchen (sink, cupboard doors), count (open table with a cash tray
    rack below), tool (steel workbench, drawers), console (gatehouse desk: two monitors' shelf below)."""
    w, d, h = float(p["w"]) - 0.01, float(p["d"]) - 0.01, 0.9
    style = p["style"]
    o = k.obj("Counter")
    a = o.part(bevel=0.003)
    top_key = {"reception": "laminate_grey", "kitchen": "laminate_grey", "count": "laminate_grey", "tool": "steel",
               "console": "laminate_grey"}[style]
    body_key = {"reception": "wood_oak", "kitchen": "metal_white", "count": "powder_charcoal", "tool": "metal_blue",
                "console": "powder_charcoal"}[style]
    a.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), top_key)
    if style in ("reception", "kitchen", "console"):
        a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.1), (w / 2 - 0.02, d / 2 - 0.04, h - 0.04), body_key)
        a.bx((-w / 2 + 0.04, -d / 2 + 0.04, 0.0), (w / 2 - 0.04, d / 2 - 0.08, 0.1), "plastic_black")
    else:
        for sx in (-1, 1):
            for sy in (-1, 1):
                a.bx((sx * (w / 2 - 0.04) - 0.03, sy * (d / 2 - 0.04) - 0.03, 0.0),
                     (sx * (w / 2 - 0.04) + 0.03, sy * (d / 2 - 0.04) + 0.03, h - 0.04), body_key)
        a.bx((-w / 2 + 0.04, -d / 2 + 0.04, 0.15), (w / 2 - 0.04, d / 2 - 0.04, 0.18), body_key)
    t = o.part(bevel=0.0)
    if style == "kitchen":
        t.bx((-0.75, -0.2, h - 0.002), (-0.25, 0.15, h + 0.003), "steel")
        t.rod((-0.5, -0.24, h), (-0.5, -0.24, h + 0.3), 0.012, "chrome", segs=8)
        t.rod((-0.5, -0.24, h + 0.3), (-0.5, -0.08, h + 0.3), 0.012, "chrome", segs=8)
        n = max(2, int(w / 0.6))
        for i in range(n):
            x0 = -w / 2 + 0.03 + i * (w - 0.06) / n
            x1 = x0 + (w - 0.06) / n - 0.008
            t.bx((x0, d / 2 - 0.04, 0.12), (x1, d / 2 - 0.02, h - 0.06), "metal_white")
            t.bx((x1 - 0.06, d / 2 - 0.02, h - 0.2), (x1 - 0.04, d / 2, h - 0.1), "steel")
    elif style == "reception":
        t.bx((-w / 2 + 0.02, -d / 2 + 0.019, 0.1), (w / 2 - 0.02, -d / 2 + 0.02, h - 0.06), "metal_blue")
        t.bx((-w / 2 + 0.2, -d / 2 + 0.017, 0.55), (-w / 2 + 1.0, -d / 2 + 0.0195, 0.7), "paper")
    elif style == "tool":
        for i in range(3):
            z = 0.55 + i * 0.09
            t.bx((-w / 2 + 0.1, d / 2 - 0.05, z), (-w / 2 + 0.6, d / 2 - 0.03, z + 0.08), "metal_red")
        t.bx((-w / 2 + 0.06, -d / 2 + 0.06, 0.18), (-w / 2 + 0.9, d / 2 - 0.06, 0.4), "metal_red")
    elif style == "count":
        for i in range(3):
            x = -0.6 + i * 0.6
            t.bx((x - 0.2, -0.3, 0.18), (x + 0.2, 0.3, 0.32), "plastic_grey")
    else:  # console
        t.bx((-w / 2 + 0.04, d / 2 - 0.045, 0.3), (w / 2 - 0.04, d / 2 - 0.04, 0.6), "metal_grey")
    o.build()


def _locker_bank(k: Kit, p: dict) -> None:
    """Staff locker bank 2.99 x 0.49 x 1.79 m: ten two-tier steel lockers with vents, handles and name cards."""
    w, d, h = 2.99, 0.49, 1.79
    o = k.obj("Lockers")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2 - 0.02, h), "metal_grey")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.06, 0.08), "metal_dark")
    t = o.part(bevel=0.0)
    n = 10
    for i in range(n):
        x0 = -w / 2 + i * w / n + 0.005
        x1 = x0 + w / n - 0.01
        key = "metal_green" if i % 4 else "metal_grey"
        for z0, z1 in ((0.1, 0.92), (0.96, h - 0.02)):
            t.bx((x0, d / 2 - 0.02, z0), (x1, d / 2, z1), key)
            for j in range(3):
                zz = z1 - 0.07 - j * 0.025
                t.bx((x0 + 0.05, d / 2, zz), (x1 - 0.05, d / 2 + 0.002, zz + 0.01), "metal_dark")
            t.bx((x1 - 0.05, d / 2, (z0 + z1) / 2 - 0.04), (x1 - 0.03, d / 2 + 0.02, (z0 + z1) / 2 + 0.04), "steel")
            t.bx((x0 + 0.03, d / 2, z1 - 0.16), (x0 + 0.11, d / 2 + 0.002, z1 - 0.12), "paper")
    o.build()


def _bench_locker(k: Kit, p: dict) -> None:
    """Changing-room bench 1.99 x 0.39 x 0.45 m: slatted timber seat on steel legs, a boot rail."""
    w, d, h = 1.99, 0.39, 0.45
    o = k.obj("Bench")
    a = o.part(bevel=0.003)
    for i in range(3):
        y0 = -d / 2 + i * d / 3 + 0.005
        a.bx((-w / 2, y0, h - 0.04), (w / 2, y0 + d / 3 - 0.01, h), "wood_oak")
    lg = o.part(bevel=0.0)
    for x in (-w / 2 + 0.15, 0.0, w / 2 - 0.15):
        lg.bx((x - 0.025, -d / 2 + 0.03, 0.0), (x + 0.025, d / 2 - 0.03, h - 0.04), "powder_charcoal")
    lg.rod((-w / 2 + 0.15, 0.0, 0.12), (w / 2 - 0.15, 0.0, 0.12), 0.015, "powder_charcoal", segs=8)
    o.build()


def _gun_locker(k: Kit, p: dict) -> None:
    """Steel gun locker 1.19 x 0.49 x 1.89 m: two doors with a keypad lock, louvred top vent."""
    w, d, h = 1.19, 0.49, 1.89
    o = k.obj("Locker")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -d / 2, 0.06), (w / 2, d / 2 - 0.015, h), "metal_dark")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.05, 0.06), "plastic_black")
    t = o.part(bevel=0.0)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.004, sx * (w / 2 - 0.02)))
        t.bx((x0, d / 2 - 0.015, 0.08), (x1, d / 2, h - 0.03), "metal_dark")
        t.bx((sx * 0.04 - 0.012, d / 2, 0.9), (sx * 0.04 + 0.012, d / 2 + 0.03, 1.15), "steel")
    for i in range(5):
        z = h - 0.2 + i * 0.03
        t.bx((-0.4, d / 2, z), (0.4, d / 2 + 0.002, z + 0.012), "plastic_black")
    t.bx((0.12, d / 2, 1.2), (0.24, d / 2 + 0.02, 1.36), "plastic_black")
    e = o.part(bevel=0.0)
    e.bx((0.15, d / 2 + 0.02, 1.32), (0.21, d / 2 + 0.022, 1.345), "emit_led_red")
    o.build()


def _radiator(k: Kit, p: dict) -> None:
    """Oil-filled radiator heater 0.39 x 0.79 x 0.59 m (long axis Y): twelve fins on castors, control box at one end."""
    o = k.obj("Heater")
    a = o.part(bevel=0.0)
    for i in range(12):
        y = -0.33 + i * 0.06
        a.bx((-0.16, y - 0.022, 0.08), (0.16, y + 0.022, 0.58), "metal_white")
    a.bx((-0.06, -0.36, 0.1), (0.06, 0.36, 0.14), "metal_white")
    a.bx((-0.12, 0.36, 0.25), (0.12, 0.39, 0.5), "plastic_grey")
    w = o.part(bevel=0.0)
    for sx in (-0.15, 0.15):
        for y in (-0.3, 0.3):
            w.bx((sx - 0.02, y - 0.12, 0.0), (sx + 0.02, y + 0.12, 0.08), "plastic_black")
    e = o.part(bevel=0.0)
    e.bx((-0.03, 0.389, 0.42), (0.03, 0.392, 0.45), "emit_amber")
    o.build()


def _basin(k: Kit, p: dict) -> None:
    """Pedestal wash basin 0.49 x 0.49 x 0.85 m (back to the wall at -Y): ceramic bowl, pedestal, chrome mixer."""
    o = k.obj("Basin")
    a = o.part(bevel=0.01, segments=2)
    a.bx((-0.24, -0.24, 0.74), (0.24, 0.2, 0.85), "ceramic")
    a.lathe([(0.0, 0.0), (0.12, 0.0), (0.1, 0.05), (0.08, 0.5), (0.11, 0.74), (0.0, 0.74)], "ceramic",
            centre=(0.0, -0.1, 0.0), segs=16)
    t = o.part(bevel=0.0)
    t.bx((-0.17, -0.12, 0.849), (0.17, 0.13, 0.851), "steel")
    t.rod((0.0, -0.2, 0.85), (0.0, -0.2, 1.0), 0.015, "chrome", segs=8)
    t.rod((0.0, -0.2, 1.0), (0.0, -0.08, 0.98), 0.012, "chrome", segs=8)
    o.build()


def _hose_reel(k: Kit, p: dict) -> None:
    """Wall-hung wash-down hose reel 0.5 x 0.3 x 0.5 m (back at y 0): bracket, red reel, coiled hose, nozzle."""
    o = k.obj("Reel")
    a = o.part(bevel=0.0)
    a.bx((-0.18, 0.0, -0.22), (0.18, 0.02, 0.22), "metal_dark")
    a.rod((0.0, 0.02, 0.0), (0.0, 0.26, 0.0), 0.03, "metal_dark", segs=10)
    for y in (0.06, 0.26):
        a.cyl(0.24, 0.015, (0.0, y, 0.0), "metal_red", axis="Y", segs=24)
    a.cyl(0.19, 0.18, (0.0, 0.16, 0.0), "rubber", axis="Y", segs=24)
    a.rod((0.18, 0.2, -0.05), (0.2, 0.22, -0.3), 0.018, "rubber", segs=8)
    a.cyl(0.025, 0.12, (0.2, 0.22, -0.36), "metal_yellow", segs=10)
    o.build()


def _life_ring(k: Kit, p: dict) -> None:
    """Quayside life ring on its post-board 0.62 x 0.12 x 0.75 m (back at y 0): orange ring, white bands, rope."""
    o = k.obj("Ring")
    a = o.part(bevel=0.0)
    a.bx((-0.31, 0.0, -0.37), (0.31, 0.02, 0.37), "wood_oak")
    a.rod((0.0, 0.02, 0.28), (0.0, 0.08, 0.28), 0.015, "metal_dark", segs=8)
    a.torus(0.24, 0.05, (0.0, 0.07, 0.0), "metal_orange", segs=28, rsegs=8, axis="Y")
    for ang in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):
        x, z = math.cos(ang) * 0.24, math.sin(ang) * 0.24
        a.cyl(0.056, 0.05, (x, 0.07, z), "plastic_white", axis="X" if abs(z) > 0.1 else "Z", segs=10)
    a.torus(0.245, 0.008, (0.0, 0.12, 0.0), "rope_tan", segs=28, rsegs=4, axis="Y")
    o.build()


# ------------------------------------------------------------------------------------- fixtures

def _highbay(k: Kit, p: dict) -> None:
    """High-bay LED (top at z 0): hanger rod, finned round driver housing, a 0.45 m diffuser."""
    o = k.obj("Fixture")
    a = o.part(bevel=0.0)
    a.rod((0.0, 0.0, 0.0), (0.0, 0.0, -0.12), 0.012, "metal_dark", segs=8)
    a.cyl(0.12, 0.08, (0.0, 0.0, -0.16), "metal_dark", segs=20)
    for i in range(12):
        ang = 2 * math.pi * i / 12
        a.rod((math.cos(ang) * 0.11, math.sin(ang) * 0.11, -0.16), (math.cos(ang) * 0.18, math.sin(ang) * 0.18, -0.16), 0.035,
              "metal_dark", segs=4, square=True)
    a.lathe([(0.0, -0.3), (0.225, -0.3), (0.2, -0.24), (0.06, -0.2), (0.0, -0.2)], "metal_grey", segs=24)
    e = o.part(bevel=0.0)
    e.cyl(0.2, 0.01, (0.0, 0.0, -0.305), "emit_cool", segs=24)
    o.build()


def _batten(k: Kit, p: dict) -> None:
    """Cold-store IP65 LED batten (top at z 0) 1.5 x 0.12 m on two drop brackets, opal diffuser."""
    o = k.obj("Fixture")
    a = o.part(bevel=0.004)
    a.bx((-0.75, -0.06, -0.08), (0.75, 0.06, -0.03), "metal_white")
    for x in (-0.55, 0.55):
        a.bx((x - 0.02, -0.02, -0.03), (x + 0.02, 0.02, 0.0), "metal_dark")
    e = o.part(bevel=0.0)
    e.bx((-0.72, -0.045, -0.09), (0.72, 0.045, -0.08), "emit_cool")
    o.build()


def _mast(k: Kit, p: dict) -> None:
    """Sodium yard mast 8 m (the generator adds the light): tapered galvanised pole on a bolted base plate, an arm to
    the front (+Y) and the flood head (y 0.4-1.1, z 7.76-7.9) with its glowing lens underneath. Visual only (the map
    keeps its 0.2 m pole collider)."""
    o = k.obj("Mast")
    a = o.part(bevel=0.0)
    a.bx((-0.2, -0.2, 0.0), (0.2, 0.2, 0.03), "steel_galv")
    for sx in (-0.15, 0.15):
        for sy in (-0.15, 0.15):
            a.cyl(0.018, 0.05, (sx, sy, 0.055), "metal_dark", segs=6)
    a.lathe([(0.1, 0.03), (0.095, 2.0), (0.075, 7.5), (0.07, 8.0), (0.0, 8.0)], "steel_galv", segs=12)
    a.bx((-0.05, 0.0, 7.9), (0.05, 1.0, 8.0), "steel_galv")
    a.rod((0.0, 0.05, 7.6), (0.0, 0.6, 7.92), 0.025, "steel_galv", segs=6)
    h = o.part(bevel=0.01)
    h.bx((-0.18, 0.4, 7.79), (0.18, 1.1, 7.9), "metal_dark")
    e = o.part(bevel=0.0)
    e.bx((-0.15, 0.43, 7.77), (0.15, 1.07, 7.79), "emit_sodium")
    o.build()


def _fish_blocks(k: Kit, p: dict) -> None:
    """Frozen fish blocks 1.99 x 1.99 x 1.2 m: four pallets of frosted blocks (the empty strongroom variant)."""
    o = k.obj("Blocks")
    for sx in (-0.5, 0.5):
        for sy in (-0.5, 0.5):
            pl = o.part(bevel=0.0)
            _pallet(pl, 0.97, 0.97, dx=sx)
            pl.translate((0.0, sy, 0.0))
    b = o.part(bevel=0.0)
    rng = k.ctx.rng
    for sx in (-0.5, 0.5):
        for sy in (-0.5, 0.5):
            for li in range(3):
                z = 0.14 + li * 0.35
                hgt = 0.34 if li < 2 else rng.uniform(0.18, 0.34)
                for j in range(2):
                    x0 = sx - 0.46 + j * 0.47
                    b.bx((x0, sy - 0.46, z), (x0 + 0.45, sy + 0.46, z + hgt), "frost" if (li + j) % 2 else "cardboard_frost")
    o.build()


def _product_pallet(k: Kit, p: dict) -> None:
    """The product pallet the burn point sits on, 1.19 x 0.99 x 1.2 m: boxed 'frozen fish' cartons on a pallet, a
    flat top (the burn barrel stands on it)."""
    o = k.obj("Pallet")
    pl = o.part(bevel=0.0)
    _pallet(pl, 1.18, 0.98)
    b = o.part(bevel=0.0)
    for li in range(3):
        z = 0.14 + li * 0.3533
        for i in range(3):
            for j in range(2):
                x0 = -0.585 + i * 0.39
                y0 = -0.485 + j * 0.485
                b.bx((x0 + 0.005, y0 + 0.005, z), (x0 + 0.385, y0 + 0.48, z + 0.3533 - 0.004),
                     "cardboard_frost" if (li + i + j) % 3 else "frost")
    b.bx((-0.59, -0.49, 1.19), (0.59, 0.49, 1.2), "shrink_wrap")
    o.build()


def _bulkhead(k: Kit, p: dict) -> None:
    """Caged bulkhead light (top at z 0): a 0.26 m round base, frosted dome, steel cage."""
    o = k.obj("Fixture")
    a = o.part(bevel=0.0)
    a.cyl(0.13, 0.04, (0.0, 0.0, -0.02), "metal_dark", segs=20)
    e = o.part(bevel=0.0)
    e.sphere(0.1, (0.0, 0.0, -0.12), "emit_neutral", segs=16, rings=6, scale=(1.0, 1.0, 0.8))
    c = o.part(bevel=0.0)
    for i in range(6):
        ang = 2 * math.pi * i / 6
        x, y = math.cos(ang) * 0.115, math.sin(ang) * 0.115
        c.tube([(x, y, -0.04), (x * 0.95, y * 0.95, -0.15), (x * 0.3, y * 0.3, -0.215)], 0.005, "metal_dark", segs=5,
               joints=False)
    c.torus(0.112, 0.005, (0.0, 0.0, -0.12), "metal_dark", segs=20, rsegs=4)
    o.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
    cat = ctx.params["cat"]
    if cat.get("place") in ("ceiling", "wall_mount") or cat.get("fixture"):
        return
    # Floor props: a box collider over the model (support props up to their work top). The map's own colliders
    # replace it where the generator instances a DB prop over a layout box (db_builder_base._art_visual).
    import bpy  # noqa: PLC0415  (Blender only)
    from lib import geo, naming  # noqa: PLC0415
    objs = sorted((o for o in bpy.data.objects if o.type == "MESH" and not naming.is_collision_name(o.name)),
                  key=lambda o: o.name)
    lo, hi = geo.bounds(objs)
    top = float(cat.get("top", 0.0)) or hi[2]
    k.collision([((lo[0], lo[1], lo[2]), (hi[0], hi[1], min(top, hi[2])))])
