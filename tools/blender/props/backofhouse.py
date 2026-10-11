"""Back-of-house dressing: workshop (workshop_jeweler), receiving/storage (storage_receiving,
storage_archive, janitor_closet), electrical closet, restrooms (restroom_single).

Floor props: bottom-centre pivot, front +Y (Godot -Z); wall-mounted: back at y = 0, centred on
the origin vertically (the catalog `z` is the centre height); `cat` = KitPlacer hints.
"""

import math

from _pb import Kit, bar_handle, legs4

TRI_BUDGET = 14000
COOL = "#FFE4CE"
VARIANTS = {
    # workshop
    "prop_jeweler_bench": {"fn": "jeweler_bench", "cat": {"kind": "jeweler_bench", "place": "wall", "support": True, "clear": 0.9, "group": "workshop", "top": 0.92,
                                                         "keepout": [[-0.22, -0.4, 0.22, -0.12]]}},
    "prop_workbench": {"fn": "workbench", "cat": {"kind": "workbench", "place": "wall", "support": True, "clear": 0.9, "group": "workshop", "top": 0.9,
                                                 "keepout": [[-0.75, 0.3, 0.75, 0.36]]}},
    "prop_bench_lamp": {"fn": "bench_lamp", "cat": {"kind": "task_lamp", "place": "on", "hosts": ["jeweler_bench"], "fixture": True, "group": "workshop",
                                                     "light": {"type": "spot", "color": COOL, "energy": 1.5, "range": 2.0, "angle": 40, "pos": [0.0, 0.44, -0.26]}}},
    "prop_magnifier_lamp": {"fn": "magnifier", "cat": {"kind": "magnifier", "place": "on", "hosts": ["jeweler_bench", "desk"], "fixture": True, "group": "workshop",
                                                       "light": {"type": "spot", "color": COOL, "energy": 0.8, "range": 1.5, "angle": 45, "pos": [0.0, 0.47, -0.17]}}},
    "prop_polishing_machine": {"fn": "polisher", "cat": {"kind": "polishing_machine", "place": "on", "hosts": ["workbench"], "group": "workshop"}},
    "prop_ultrasonic_cleaner": {"fn": "ultrasonic", "cat": {"kind": "ultrasonic_cleaner", "place": "on", "hosts": ["workbench", "jeweler_bench"], "group": "workshop"}},
    "prop_tool_wall": {"fn": "tool_wall", "cat": {"kind": "tool_wall", "place": "wall_mount", "z": 1.45, "group": "workshop"}},
    "prop_stool_shop": {"fn": "stool", "cat": {"kind": "stool", "place": "seat", "hosts": ["jeweler_bench", "workbench"], "group": "workshop"}},
    "prop_stool_teller": {"fn": "stool", "seat": 0.72, "cat": {"kind": "stool", "place": "seat", "hosts": ["counter_transaction"], "group": "bank",
                                                               "pin_only": True}},
    "prop_shelving_parts": {"fn": "shelving", "load": "parts", "cat": {"kind": "shelving", "place": "wall", "clear": 0.8, "group": "storage"}},
    "prop_shelving_boxes": {"fn": "shelving", "load": "boxes", "cat": {"kind": "shelving", "place": "wall", "clear": 0.8, "group": "storage"}},
    "prop_shelving_archive": {"fn": "shelving", "load": "archive", "cat": {"kind": "shelving", "place": "wall", "clear": 0.8, "group": "storage"}},
    "prop_shelving_cleaning": {"fn": "shelving", "load": "cleaning", "w": 0.9, "cat": {"kind": "shelving", "place": "wall", "clear": 0.6, "group": "storage"}},
    # storage / receiving
    "prop_crate_wood": {"fn": "crate", "cat": {"kind": "crate", "place": "wall", "support": True, "group": "storage"}},
    "prop_box_small": {"fn": "box", "size": (0.4, 0.3, 0.25), "cat": {"kind": "box", "place": "wall", "group": "storage"}},
    "prop_box_stack": {"fn": "box_stack", "cat": {"kind": "box", "place": "wall", "group": "storage"}},
    "prop_archive_boxes": {"fn": "archive_boxes", "cat": {"kind": "archive_box", "place": "wall", "group": "storage"}},
    "prop_gift_boxes": {"fn": "gift_boxes", "cat": {"kind": "gift_boxes", "place": "on", "hosts": ["packing_bench", "table", "workbench"], "group": "storage"}},
    "prop_packing_bench": {"fn": "packing_bench", "cat": {"kind": "packing_bench", "place": "wall", "support": True, "clear": 0.9, "group": "storage", "top": 0.9,
                                                         "keepout": [[-0.6, 0.2, 0.6, 0.38], [0.48, -0.1, 0.7, 0.02]]}},
    "prop_hand_truck": {"fn": "hand_truck", "cat": {"kind": "dolly", "place": "wall", "group": "storage"}},
    "prop_pallet": {"fn": "pallet", "load": False, "cat": {"kind": "pallet", "place": "wall", "support": True, "group": "storage"}},
    "prop_pallet_loaded": {"fn": "pallet", "load": True, "cat": {"kind": "pallet", "place": "wall", "group": "storage"}},
    "prop_step_ladder": {"fn": "step_ladder", "cat": {"kind": "step_ladder", "place": "wall", "group": "storage"}},
    "prop_mop_sink": {"fn": "mop_sink", "cat": {"kind": "mop_sink", "place": "corner", "group": "storage"}},
    "prop_mop_bucket": {"fn": "mop_bucket", "cat": {"kind": "mop_bucket", "place": "wall", "group": "storage"}},
    "prop_breaker_panel": {"fn": "breaker", "cat": {"kind": "breaker_panel", "place": "wall_mount", "z": 1.45, "group": "storage"}},
    "prop_it_rack": {"fn": "it_rack", "cat": {"kind": "it_rack", "place": "wall", "clear": 0.8, "group": "storage"}},
    # restroom
    "prop_toilet": {"fn": "toilet", "cat": {"kind": "toilet", "place": "wall", "clear": 0.6, "group": "restroom"}},
    "prop_sink_vanity": {"fn": "vanity", "cat": {"kind": "sink", "place": "wall", "clear": 0.6, "group": "restroom"}},
    "prop_mirror_restroom": {"fn": "mirror", "cat": {"kind": "mirror", "place": "wall_mount", "z": 1.55, "hosts": ["sink"], "group": "restroom"}},
    "prop_grab_bar": {"fn": "grab_bar", "cat": {"kind": "grab_bar", "place": "wall_mount", "z": 0.85, "hosts": ["toilet"], "group": "restroom"}},
    "prop_paper_dispenser": {"fn": "paper_dispenser", "cat": {"kind": "paper_dispenser", "place": "wall_mount", "z": 0.7, "hosts": ["toilet"], "group": "restroom"}},
    "prop_hand_dryer": {"fn": "hand_dryer", "cat": {"kind": "hand_dryer", "place": "wall_mount", "z": 1.2, "group": "restroom"}},
    "prop_soap_dispenser": {"fn": "soap", "cat": {"kind": "soap_dispenser", "place": "wall_mount", "z": 1.15, "hosts": ["sink"], "group": "restroom"}},
    "prop_bin_small": {"fn": "bin_small", "cat": {"kind": "bin", "place": "corner", "group": "restroom"}},
}


# ---------------------------------------------------------------------------------- workshop

def _jeweler_bench(k: Kit, p: dict) -> None:
    w, d, h = 1.2, 0.6, 0.92
    o = k.obj("Bench")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0015)
    # top with the half-moon cut-out at the front (+Y)
    cut = [(math.cos(math.pi * i / 12) * 0.2, d / 2 - math.sin(math.pi * i / 12) * 0.16) for i in range(13)]
    outline = [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2)] + cut + [(-w / 2, d / 2)]
    hard.slab(outline, h - 0.04, h, "wood_oak")
    # drawer pedestals left/right, back panel, shelf
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.36)))
        hard.bx((x0, -d / 2, 0.0), (x1, d / 2 - 0.02, h - 0.04), "wood_oak")
        for i in range(6):
            z0 = 0.05 + i * 0.135
            hard.bx((x0 + 0.015, d / 2 - 0.02, z0), (x1 - 0.015, d / 2, z0 + 0.12), "wood_oak")
            trim.cbox(((x0 + x1) / 2, d / 2 + 0.006, z0 + 0.09), (0.08, 0.012, 0.012), "steel")
    hard.bx((-w / 2 + 0.36, -d / 2, 0.0), (w / 2 - 0.36, -d / 2 + 0.02, h - 0.04), "wood_oak")
    # leather catch skin and its frame under the cut-out
    trim.bx((-0.22, d / 2 - 0.3, h - 0.2), (0.22, d / 2, h - 0.19), "leather")
    # bench pin, tools, ring mandrel
    trim.bx((-0.04, d / 2 - 0.02, h - 0.03), (0.04, d / 2 + 0.06, h - 0.01), "wood_pine")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _workbench(k: Kit, p: dict) -> None:
    w, d, h = 1.5, 0.7, 0.9
    o = k.obj("Bench")
    hard = o.part(bevel=0.003)
    hard.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), "steel")
    hard.bx((-w / 2, -d / 2, h - 0.05), (w / 2, d / 2, h - 0.04), "wood_pine")
    legs4(hard, w, d, h - 0.05, 0.03, 0.045, "metal_grey")
    hard.bx((-w / 2 + 0.05, -d / 2 + 0.05, 0.15), (w / 2 - 0.05, d / 2 - 0.05, 0.18), "metal_grey")
    hard.bx((-w / 2, -d / 2 - 0.0, h), (w / 2, -d / 2 + 0.02, h + 0.12), "steel")
    hard.bx((0.15, -d / 2 + 0.1, 0.18), (0.5, d / 2 - 0.12, 0.42), "plastic_grey")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _bench_lamp(k: Kit, p: dict) -> None:
    o = k.obj("Lamp")
    a = o.part(bevel=0.0)
    a.cyl(0.06, 0.025, (0.0, -0.12, 0.0125), "metal_dark", segs=20)
    a.rod((0.0, -0.12, 0.02), (0.0, -0.05, 0.4), 0.008, "metal_dark", segs=8)
    a.sphere(0.012, (0.0, -0.05, 0.4), "metal_dark", segs=8, rings=4)
    a.rod((0.0, -0.05, 0.4), (0.0, 0.22, 0.47), 0.008, "metal_dark", segs=8)
    a.lathe([(0.0, 0.0), (0.02, 0.0), (0.07, -0.08), (0.075, -0.09), (0.0, -0.09)], "metal_dark", centre=(0.0, 0.26, 0.5), segs=16)
    a.lathe([(0.065, -0.085), (0.0, -0.085)], "emit_cool", centre=(0.0, 0.26, 0.5), segs=16)
    o.build()


def _magnifier(k: Kit, p: dict) -> None:
    o = k.obj("Lamp")
    a = o.part(bevel=0.0)
    a.bx((-0.07, -0.18, 0.0), (0.07, -0.08, 0.03), "plastic_white")
    a.rod((0.0, -0.13, 0.03), (0.0, -0.06, 0.42), 0.01, "plastic_white", segs=8)
    a.rod((0.0, -0.06, 0.42), (0.0, 0.08, 0.5), 0.01, "plastic_white", segs=8)
    a.torus(0.09, 0.02, (0.0, 0.17, 0.5), "plastic_white", segs=24, rsegs=6)
    a.torus(0.09, 0.007, (0.0, 0.17, 0.48), "emit_cool", segs=24, rsegs=4)
    a.cyl(0.075, 0.01, (0.0, 0.17, 0.5), "glass", segs=24)
    o.build()


def _polisher(k: Kit, p: dict) -> None:
    o = k.obj("Polisher")
    a = o.part(bevel=0.003)
    a.bx((-0.1, -0.1, 0.0), (0.1, 0.1, 0.03), "metal_dark")
    a.cyl(0.08, 0.26, (0.0, 0.0, 0.16), "metal_green", axis="X", segs=20)
    a.rod((-0.13, 0.0, 0.16), (-0.24, 0.0, 0.16), 0.008, "steel", segs=8)
    a.rod((0.13, 0.0, 0.16), (0.24, 0.0, 0.16), 0.008, "steel", segs=8)
    a.cyl(0.07, 0.03, (-0.24, 0.0, 0.16), "fabric_ivory", axis="X", segs=18)
    a.cyl(0.07, 0.03, (0.24, 0.0, 0.16), "felt_rose", axis="X", segs=18)
    o.build()


def _ultrasonic(k: Kit, p: dict) -> None:
    o = k.obj("Cleaner")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-0.15, -0.1, 0.0), (0.15, 0.1, 0.15), "steel")
    a.bx((-0.13, -0.08, 0.15), (0.13, 0.08, 0.152), "glass_tinted")
    a.bx((-0.12, 0.1, 0.03), (0.12, 0.104, 0.1), "plastic_black")
    s = o.part(bevel=0.0)
    s.bx((-0.06, 0.104, 0.06), (0.0, 0.106, 0.085), "emit_amber")
    o.build()


def _tool_wall(k: Kit, p: dict) -> None:
    w, h = 1.2, 0.8
    o = k.obj("ToolWall")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.018, h / 2), "wood_pine")
    t = o.part(bevel=0.0)
    rng = k.ctx.rng
    for i in range(14):
        x = -w / 2 + 0.08 + (i % 7) * (w - 0.16) / 6
        z = 0.15 if i < 7 else -0.15
        t.rod((x, 0.018, z + 0.12), (x, 0.05, z + 0.12), 0.003, "steel", segs=5)
        ln = rng.uniform(0.12, 0.2)
        key = ("plastic_black", "metal_red", "wood_oak", "metal_yellow")[i % 4]
        t.bx((x - 0.012, 0.03, z - ln / 2 + 0.05), (x + 0.012, 0.045, z + 0.1), key)
        t.rod((x, 0.037, z - ln / 2 + 0.05), (x, 0.037, z - ln / 2 - 0.05), 0.003, "steel", segs=5)
    t.bx((-w / 2 + 0.05, 0.018, -h / 2 + 0.04), (w / 2 - 0.05, 0.09, -h / 2 + 0.06), "steel")
    o.build()


def _stool(k: Kit, p: dict) -> None:
    o = k.obj("Stool")
    a = o.part(bevel=0.0)
    sz = p.get("seat", 0.62)
    a.cyl(0.18, 0.06, (0.0, 0.0, sz), "leather", segs=20)
    a.rod((0.0, 0.0, 0.08), (0.0, 0.0, 0.59 if "seat" not in p else sz - 0.03), 0.025, "steel", segs=10)
    for i in range(5):
        ang = 2 * math.pi * i / 5
        tip = (math.cos(ang) * 0.26, math.sin(ang) * 0.26, 0.04)
        a.rod((0.0, 0.0, 0.08), tip, 0.014, "metal_dark", segs=6)
        a.sphere(0.025, (tip[0], tip[1], 0.025), "plastic_black", segs=8, rings=4)
    a.torus(0.17, 0.008, (0.0, 0.0, 0.3), "steel", segs=20, rsegs=4)
    for i in range(3):
        ang = 2 * math.pi * i / 3
        a.rod((0.0, 0.0, 0.3), (math.cos(ang) * 0.17, math.sin(ang) * 0.17, 0.3), 0.006, "steel", segs=5)
    o.build()
    top = 0.65 if "seat" not in p else sz + 0.03
    k.collision([], cylinders=[(0.26, top, (0.0, 0.0, top / 2))])


def _shelf_load(t, load: str, x0: float, x1: float, y0: float, y1: float, z: float, rng) -> None:
    x = x0 + 0.02
    while x < x1 - 0.12:
        if load == "boxes":
            bw = rng.uniform(0.25, 0.42)
            bh = rng.uniform(0.18, 0.3)
            bd = rng.uniform(0.25, y1 - y0 - 0.04)
            if x + bw > x1 - 0.02:
                break
            t.bx((x, y0 + 0.02, z), (x + bw, y0 + 0.02 + bd, z + bh), "cardboard")
            t.bx((x + bw * 0.45, y0 + 0.02, z + bh - 0.001), (x + bw * 0.55, y0 + 0.02 + bd, z + bh + 0.001), "paper")
            x += bw + rng.uniform(0.02, 0.08)
        elif load == "archive":
            bw = 0.11
            if x + bw > x1 - 0.02:
                break
            key = ("paper", "cardboard", "paper")[int(rng.uniform(0, 2.99))]
            t.bx((x, y0 + 0.03, z), (x + bw - 0.005, y1 - 0.04, z + 0.27), key)
            t.bx((x + 0.02, y1 - 0.042, z + 0.08), (x + bw - 0.025, y1 - 0.039, z + 0.14), "plastic_white")
            x += bw + (0.06 if rng.random() < 0.15 else 0.0)
        elif load == "cleaning":
            r = rng.uniform(0.035, 0.05)
            hh = rng.uniform(0.2, 0.3)
            key = ("plastic_white", "metal_yellow", "canvas_teal", "metal_red")[int(rng.uniform(0, 3.99))]
            t.lathe([(r, 0.0), (r, hh * 0.8), (r * 0.4, hh * 0.9), (r * 0.35, hh), (0.0, hh)], key, centre=(x + r, (y0 + y1) / 2, z), segs=10)
            x += 2 * r + 0.03
        else:
            bw = rng.uniform(0.18, 0.3)
            bh = rng.uniform(0.08, 0.16)
            key = ("plastic_grey", "plastic_black", "metal_dark", "plastic_white")[int(rng.uniform(0, 3.99))]
            if x + bw > x1 - 0.02:
                break
            t.bx((x, y0 + 0.04, z), (x + bw, y1 - 0.05, z + bh), key)
            x += bw + rng.uniform(0.02, 0.1)


def _shelving(k: Kit, p: dict) -> None:
    w = p.get("w", 1.2)
    d, h = 0.45, 1.95
    o = k.obj("Shelving")
    a = o.part(bevel=0.002)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.02), sy * (d / 2 - 0.02)
            a.bx((x - 0.02, y - 0.02, 0.0), (x + 0.02, y + 0.02, h), "metal_grey")
    levels = (0.08, 0.5, 0.92, 1.34, 1.76)
    for z in levels:
        a.bx((-w / 2, -d / 2, z), (w / 2, d / 2, z + 0.025), "metal_grey")
    for sy in (-1, 1):
        a.rod((-w / 2 + 0.03, sy * (d / 2 - 0.02), 0.3), (w / 2 - 0.03, sy * (d / 2 - 0.02), 1.6), 0.004, "metal_grey", segs=4)
    t = o.part(bevel=0.002)
    rng = k.ctx.rng
    for z in levels:
        if rng.random() < 0.85:
            _shelf_load(t, p["load"], -w / 2 + 0.02, w / 2 - 0.02, -d / 2, d / 2, z + 0.025, rng)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


# ------------------------------------------------------------------------------------ storage

def _crate(k: Kit, p: dict) -> None:
    w, d, h = 0.8, 0.6, 0.6
    o = k.obj("Crate")
    a = o.part(bevel=0.003)
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.02, h - 0.02), "wood_pine")
    for z0 in (0.0, h - 0.08):
        for sy in (-1, 1):
            y0, y1 = sorted((sy * d / 2, sy * (d / 2 - 0.022)))
            a.bx((-w / 2, y0, z0), (w / 2, y1, z0 + 0.08), "wood_pine")
        for sx in (-1, 1):
            x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.022)))
            a.bx((x0, -d / 2, z0), (x1, d / 2, z0 + 0.08), "wood_pine")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.06)))
            y0, y1 = sorted((sy * d / 2, sy * (d / 2 - 0.022)))
            a.bx((x0, y0, 0.0), (x1, y1, h), "wood_pine")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, h - 0.02), (w / 2 - 0.02, d / 2 - 0.02, h), "wood_pine")
    a.bx((-0.15, d / 2, 0.25), (0.15, d / 2 + 0.002, 0.35), "paper")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _cardboard(t, lo, hi) -> None:
    t.bx(lo, hi, "cardboard")
    cx = (lo[0] + hi[0]) / 2
    t.bx((cx - 0.025, lo[1] - 0.001, hi[2] - 0.0005), (cx + 0.025, hi[1] + 0.001, hi[2] + 0.001), "paper")
    t.bx((cx - 0.025, hi[1] - 0.0005, lo[2] + (hi[2] - lo[2]) * 0.6), (cx + 0.025, hi[1] + 0.001, hi[2]), "paper")


def _box(k: Kit, p: dict) -> None:
    sx, sy, sz = p["size"]
    o = k.obj("Box")
    _cardboard(o.part(bevel=0.003), (-sx / 2, -sy / 2, 0.0), (sx / 2, sy / 2, sz))
    o.build()
    k.collision([((-sx / 2, -sy / 2, 0.0), (sx / 2, sy / 2, sz))])


def _box_stack(k: Kit, p: dict) -> None:
    o = k.obj("Boxes")
    t = o.part(bevel=0.003)
    _cardboard(t, (-0.3, -0.22, 0.0), (0.3, 0.22, 0.4))
    _cardboard(t, (-0.26, -0.2, 0.4), (0.2, 0.18, 0.7))
    _cardboard(t, (-0.18, -0.12, 0.7), (0.14, 0.14, 0.88))
    o.build()
    k.collision([((-0.3, -0.22, 0.0), (0.3, 0.22, 0.4)), ((-0.26, -0.2, 0.4), (0.2, 0.18, 0.88))])


def _archive_boxes(k: Kit, p: dict) -> None:
    o = k.obj("Boxes")
    t = o.part(bevel=0.003)
    for i, (x, z) in enumerate(((-0.17, 0.0), (0.17, 0.0), (0.0, 0.27))):
        t.bx((x - 0.16, -0.2, z), (x + 0.16, 0.2, z + 0.27), "paper" if i % 2 == 0 else "cardboard")
        t.bx((x - 0.05, 0.2, z + 0.1), (x + 0.05, 0.202, z + 0.16), "plastic_white")
    o.build()
    k.collision([((-0.33, -0.2, 0.0), (0.33, 0.2, 0.27)), ((-0.16, -0.2, 0.27), (0.16, 0.2, 0.54))])


def _gift_boxes(k: Kit, p: dict) -> None:
    o = k.obj("Gifts")
    t = o.part(bevel=0.002)
    for i in range(4):
        x = -0.15 + (i % 2) * 0.16
        y = -0.05 + (i // 2) * 0.12
        t.bx((x - 0.06, y - 0.05, 0.0), (x + 0.06, y + 0.05, 0.06), "paint_ivory")
        t.bx((x - 0.06, y - 0.005, 0.0), (x + 0.06, y + 0.005, 0.061), "felt_rose")
    t.bx((0.08, -0.08, 0.0), (0.22, 0.1, 0.1), "wood_dark")
    o.build()


def _packing_bench(k: Kit, p: dict) -> None:
    w, d, h = 1.8, 0.75, 0.9
    o = k.obj("Bench")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, h - 0.035), (w / 2, d / 2, h), "wood_pine")
    legs4(a, w, d, h - 0.035, 0.03, 0.05, "metal_grey")
    a.bx((-w / 2 + 0.05, -d / 2 + 0.05, 0.15), (w / 2 - 0.05, d / 2 - 0.05, 0.17), "wood_pine")
    # paper roll on brackets at the back, tape dispenser, folded boxes on the shelf
    for sx in (-1, 1):
        a.bx((sx * 0.55 - 0.01, -d / 2, h), (sx * 0.55 + 0.01, -d / 2 + 0.1, h + 0.25), "metal_grey")
    a.cyl(0.08, 1.05, (0.0, -d / 2 + 0.07, h + 0.2), "paper", axis="X", segs=18)
    a.bx((0.5, 0.0, h), (0.68, 0.08, h + 0.08), "metal_red")
    a.cyl(0.04, 0.05, (0.59, 0.04, h + 0.1), "plastic_grey", axis="X", segs=12)
    a.bx((-w / 2 + 0.1, -d / 2 + 0.1, 0.17), (-0.1, d / 2 - 0.1, 0.27), "cardboard")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _hand_truck(k: Kit, p: dict) -> None:
    o = k.obj("Truck")
    a = o.part(bevel=0.0)
    for sx in (-1, 1):
        a.rod((sx * 0.18, -0.08, 0.04), (sx * 0.18, -0.12, 1.2), 0.013, "metal_red", segs=8)
        a.cyl(0.1, 0.06, (sx * 0.22, -0.12, 0.1), "rubber", axis="X", segs=16)
    a.rod((-0.18, -0.12, 1.2), (0.18, -0.12, 1.2), 0.013, "metal_red", segs=8)
    for z in (0.4, 0.75):
        a.rod((-0.18, -0.1, z), (0.18, -0.1, z), 0.01, "metal_red", segs=6)
    a.bx((-0.2, -0.08, 0.0), (0.2, 0.15, 0.015), "steel")
    a.rod((-0.22, -0.12, 0.1), (0.22, -0.12, 0.1), 0.01, "steel", segs=6)
    o.build()
    k.collision([((-0.28, -0.22, 0.0), (0.28, 0.15, 1.21))])


def _pallet(k: Kit, p: dict) -> None:
    w, d = 1.2, 0.8
    o = k.obj("Pallet")
    a = o.part(bevel=0.002)
    for i in range(3):
        y = -d / 2 + 0.05 + i * (d - 0.1) / 2
        a.bx((-w / 2, y - 0.05, 0.0), (w / 2, y + 0.05, 0.022), "wood_pine")
        for x in (-w / 2 + 0.05, 0.0, w / 2 - 0.05):
            a.bx((x - 0.05, y - 0.05, 0.022), (x + 0.05, y + 0.05, 0.1), "wood_pine")
    for x in (-w / 2 + 0.05, 0.0, w / 2 - 0.05):
        a.bx((x - 0.05, -d / 2, 0.1), (x + 0.05, d / 2, 0.122), "wood_pine")
    for i in range(7):
        x = -w / 2 + 0.05 + i * (w - 0.1) / 6
        a.bx((x - 0.05, -d / 2, 0.122), (x + 0.05, d / 2, 0.144), "wood_pine")
    top = 0.144
    if p["load"]:
        t = o.part(bevel=0.003)
        for i in range(2):
            for j in range(2):
                for lz in range(2):
                    x0 = -w / 2 + 0.02 + i * (w / 2)
                    y0 = -d / 2 + 0.02 + j * (d / 2)
                    _cardboard(t, (x0, y0, top + lz * 0.35), (x0 + w / 2 - 0.04, y0 + d / 2 - 0.04, top + lz * 0.35 + 0.34))
        wrap = o.part(bevel=0.0)
        wrap.bx((-w / 2 + 0.01, -d / 2 + 0.01, top + 0.3), (w / 2 - 0.01, d / 2 - 0.01, top + 0.55), "glass_frosted")
    o.build()
    h = top + (0.71 if p["load"] else 0.0)
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _step_ladder(k: Kit, p: dict) -> None:
    o = k.obj("Ladder")
    a = o.part(bevel=0.002)
    hgt = 1.5
    for sx in (-1, 1):
        a.rod((sx * 0.22, 0.25, 0.0), (sx * 0.18, -0.02, hgt), 0.015, "steel", segs=6, square=True)
        a.rod((sx * 0.22, -0.32, 0.0), (sx * 0.18, -0.06, hgt), 0.012, "steel", segs=6, square=True)
    for i in range(4):
        f = (i + 1) / 5
        y = 0.25 + (-0.02 - 0.25) * f
        a.bx((-0.2, y - 0.05, hgt * f - 0.015), (0.2, y + 0.05, hgt * f), "metal_grey")
    a.bx((-0.2, -0.1, hgt), (0.2, 0.02, hgt + 0.04), "metal_orange")
    o.build()
    k.collision([((-0.24, -0.33, 0.0), (0.24, 0.27, hgt + 0.04))])


def _mop_sink(k: Kit, p: dict) -> None:
    o = k.obj("Sink")
    a = o.part(bevel=0.01, segments=2)
    s = 0.6
    a.bx((-s / 2, -s / 2, 0.0), (s / 2, -s / 2 + 0.05, 0.3), "ceramic")
    a.bx((-s / 2, s / 2 - 0.05, 0.0), (s / 2, s / 2, 0.3), "ceramic")
    a.bx((-s / 2, -s / 2, 0.0), (-s / 2 + 0.05, s / 2, 0.3), "ceramic")
    a.bx((s / 2 - 0.05, -s / 2, 0.0), (s / 2, s / 2, 0.3), "ceramic")
    a.bx((-s / 2, -s / 2, 0.0), (s / 2, s / 2, 0.06), "ceramic")
    f = o.part(bevel=0.0)
    f.rod((0.0, -s / 2, 0.75), (0.0, -s / 2 + 0.2, 0.75), 0.015, "chrome", segs=8)
    f.rod((0.0, -s / 2 + 0.2, 0.75), (0.0, -s / 2 + 0.22, 0.62), 0.013, "chrome", segs=8)
    for sx in (-1, 1):
        f.cyl(0.025, 0.05, (sx * 0.12, -s / 2 + 0.025, 0.8), "chrome", axis="Y", segs=10)
        f.bx((sx * 0.12 - 0.04, -s / 2 + 0.045, 0.79), (sx * 0.12 + 0.04, -s / 2 + 0.06, 0.81), "chrome")
    f.bx((-0.06, -s / 2, 0.68), (0.06, -s / 2 + 0.01, 0.9), "steel")
    o.build()
    k.collision([((-s / 2, -s / 2, 0.0), (s / 2, s / 2, 0.3))])


def _mop_bucket(k: Kit, p: dict) -> None:
    o = k.obj("Bucket")
    a = o.part(bevel=0.008, segments=2)
    a.bx((-0.22, -0.17, 0.06), (0.22, 0.17, 0.4), "metal_yellow")
    a.bx((-0.12, -0.18, 0.4), (0.04, 0.18, 0.55), "metal_yellow")
    b = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.sphere(0.03, (sx * 0.18, sy * 0.13, 0.03), "plastic_black", segs=8, rings=4)
    b.rod((-0.04, 0.0, 0.3), (-0.12, 0.05, 1.3), 0.012, "wood_pine", segs=8)
    b.cyl(0.08, 0.06, (-0.04, 0.0, 0.33), "fabric_ivory", segs=10)
    o.build()
    k.collision([((-0.23, -0.18, 0.0), (0.23, 0.18, 0.55))])


def _breaker(k: Kit, p: dict) -> None:
    w, h = 0.5, 0.8
    o = k.obj("Panel")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.11, h / 2), "metal_grey")
    a.bx((-w / 2 + 0.02, 0.11, -h / 2 + 0.02), (w / 2 - 0.02, 0.118, h / 2 - 0.02), "metal_grey")
    a.bx((w / 2 - 0.06, 0.118, -0.04), (w / 2 - 0.045, 0.13, 0.04), "plastic_black")
    a.bx((-0.08, 0.118, h / 2 - 0.12), (0.08, 0.12, h / 2 - 0.06), "paper")
    a.rod((0.0, 0.05, h / 2), (0.0, 0.05, h / 2 + 0.5), 0.02, "steel", segs=8)
    o.build()


def _it_rack(k: Kit, p: dict) -> None:
    w, d, h = 0.6, 0.8, 1.8
    o = k.obj("Rack")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.0), (-w / 2 + 0.03, d / 2, h), "metal_dark")
    a.bx((w / 2 - 0.03, -d / 2, 0.0), (w / 2, d / 2, h), "metal_dark")
    a.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), "metal_dark")
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.06), "metal_dark")
    a.bx((-w / 2, -d / 2, 0.06), (w / 2, -d / 2 + 0.02, h - 0.04), "metal_dark")
    e = o.part(bevel=0.002)
    led = o.part(bevel=0.0)
    z = 0.15
    rng = k.ctx.rng
    while z < h - 0.25:
        u = (1, 1, 2, 2, 4)[int(rng.uniform(0, 4.99))]
        hh = u * 0.0445
        e.bx((-w / 2 + 0.03, -d / 2 + 0.1, z), (w / 2 - 0.03, d / 2 - 0.02, z + hh - 0.004), "plastic_black" if u < 4 else "metal_grey")
        for i in range(4 if u < 2 else 2):
            key = "emit_led_green" if rng.random() < 0.8 else "emit_amber"
            led.cbox((-w / 2 + 0.08 + i * 0.03, d / 2 - 0.018, z + 0.012), (0.006, 0.004, 0.006), key)
        if u == 1:
            for i in range(12):
                e.bx((-0.2 + i * 0.03, d / 2 - 0.02, z + 0.012), (-0.185 + i * 0.03, d / 2 - 0.016, z + 0.03), "metal_dark")
        z += hh + (0.0445 if rng.random() < 0.3 else 0.0)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


# ------------------------------------------------------------------------------------ restroom

def _toilet(k: Kit, p: dict) -> None:
    o = k.obj("Toilet")
    a = o.part(bevel=0.0)
    # pedestal + bowl (lathe, squashed), cistern against the wall (back = Blender -Y)
    a.lathe([(0.11, 0.0), (0.12, 0.02), (0.1, 0.2), (0.17, 0.36), (0.18, 0.4), (0.0, 0.4)], "ceramic",
            centre=(0.0, 0.05, 0.0), segs=24, scale_xy=(1.0, 1.35))
    a.lathe([(0.185, 0.4), (0.19, 0.42), (0.0, 0.42)], "plastic_white", centre=(0.0, 0.05, 0.0), segs=24, scale_xy=(1.0, 1.35))
    b = o.part(bevel=0.012, segments=2)
    b.bx((-0.2, -0.32, 0.38), (0.2, -0.14, 0.8), "ceramic")
    b.bx((-0.21, -0.33, 0.8), (0.21, -0.13, 0.83), "ceramic")
    b.bx((0.12, -0.15, 0.7), (0.17, -0.12, 0.72), "chrome")
    b.bx((-0.08, -0.25, 0.3), (0.08, -0.14, 0.4), "ceramic")
    o.build()
    k.collision([((-0.21, -0.33, 0.0), (0.21, 0.32, 0.83))])


def _vanity(k: Kit, p: dict) -> None:
    w, d, h = 0.8, 0.5, 0.85
    o = k.obj("Vanity")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-w / 2 + 0.03, -d / 2, 0.1), (w / 2 - 0.03, d / 2 - 0.04, h - 0.04), "walnut")
    a.bx((-w / 2 + 0.06, -d / 2, 0.0), (w / 2 - 0.06, d / 2 - 0.08, 0.1), "wood_dark")
    for i in range(2):
        x0 = -w / 2 + 0.04 + i * (w - 0.08) / 2
        a.bx((x0 + 0.005, d / 2 - 0.04, 0.13), (x0 + (w - 0.08) / 2 - 0.005, d / 2 - 0.02, h - 0.07), "walnut")
        a.cbox((x0 + (w - 0.08) / 2 - 0.05 if i == 0 else x0 + 0.05, d / 2 - 0.01, h - 0.2), (0.012, 0.02, 0.08), "brass")
    a.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), "marble")
    b = o.part(bevel=0.0)
    b.lathe([(0.0, 0.0), (0.12, 0.0), (0.2, 0.1), (0.21, 0.13), (0.19, 0.13), (0.11, 0.025), (0.0, 0.025)], "ceramic",
            centre=(0.0, 0.03, h), segs=28, scale_xy=(1.0, 0.75))
    b.rod((0.0, -d / 2 + 0.06, h), (0.0, -d / 2 + 0.06, h + 0.22), 0.014, "brass", segs=10)
    b.rod((0.0, -d / 2 + 0.06, h + 0.22), (0.0, -d / 2 + 0.2, h + 0.2), 0.011, "brass", segs=10)
    b.rod((0.0, -d / 2 + 0.06, h + 0.12), (0.05, -d / 2 + 0.1, h + 0.17), 0.006, "brass", segs=6)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h + 0.13))])


def _mirror(k: Kit, p: dict) -> None:
    w, h = 0.6, 0.8
    o = k.obj("Mirror")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.02, h / 2), "steel")
    m = o.part(bevel=0.0)
    m.bx((-w / 2 + 0.015, 0.02, -h / 2 + 0.015), (w / 2 - 0.015, 0.024, h / 2 - 0.015), "chrome")
    o.build()


def _grab_bar(k: Kit, p: dict) -> None:
    o = k.obj("Bar")
    a = o.part(bevel=0.0)
    ln = 0.6
    a.rod((-ln / 2, 0.07, 0.0), (ln / 2, 0.07, 0.0), 0.016, "steel", segs=12)
    for sx in (-1, 1):
        a.rod((sx * ln / 2, 0.0, 0.0), (sx * ln / 2, 0.07, 0.0), 0.016, "steel", segs=12)
        a.cyl(0.035, 0.008, (sx * ln / 2, 0.004, 0.0), "steel", axis="Y", segs=14)
    o.build()


def _paper_dispenser(k: Kit, p: dict) -> None:
    o = k.obj("Dispenser")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-0.13, 0.0, -0.13), (0.13, 0.12, 0.13), "steel")
    a.bx((-0.05, 0.12, -0.04), (0.05, 0.123, 0.04), "glass_tinted")
    o.build()


def _hand_dryer(k: Kit, p: dict) -> None:
    o = k.obj("Dryer")
    a = o.part(bevel=0.02, segments=3)
    a.bx((-0.14, 0.0, -0.15), (0.14, 0.17, 0.15), "plastic_white")
    b = o.part(bevel=0.0)
    b.cyl(0.03, 0.06, (0.0, 0.12, -0.17), "steel", segs=14)
    b.bx((-0.05, 0.17, 0.05), (0.05, 0.172, 0.08), "steel")
    o.build()


def _soap(k: Kit, p: dict) -> None:
    o = k.obj("Soap")
    a = o.part(bevel=0.006, segments=2)
    a.bx((-0.06, 0.0, -0.1), (0.06, 0.09, 0.1), "plastic_white")
    a.bx((-0.04, 0.09, -0.02), (0.04, 0.095, 0.06), "glass_tinted")
    a.bx((-0.03, 0.05, -0.12), (0.03, 0.09, -0.1), "chrome")
    o.build()


def _bin_small(k: Kit, p: dict) -> None:
    o = k.obj("Bin")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, 0.0), (0.12, 0.0), (0.13, 0.3), (0.135, 0.31), (0.0, 0.31)], "steel", segs=20)
    a.bx((-0.04, -0.15, 0.0), (0.04, -0.11, 0.02), "plastic_black")
    o.build()
    k.collision([], cylinders=[(0.135, 0.31, (0.0, 0.0, 0.155))])


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
