"""Night Deposit (Harbor Savings & Loan, docs/design/heists/night_deposit.md): banking hall, teller
line, ATM vestibule, vault and count-room dressing, plus the round vault door and the loot-pile
visuals of the bank's gameplay prefabs.

Floor props: bottom-centre pivot, front +Y (Godot -Z); wall-mounted: back at y = 0, centred
vertically on the origin (the catalog `z` is the centre height); ceiling: top at z = 0. No
lettering anywhere (style: unreadable text reads as garbled at review distance).
"""

import math

from _pb import Kit, chair_seat_marker, knob, legs4, panel_door

TRI_BUDGET = 24000
WARM = "#FFC58F"
_WORK_TOPS = ["counter_transaction", "desk", "table", "counter_service", "packing_bench", "credenza"]
VARIANTS = {
    # banking hall + teller line
    "prop_counter_teller": {"fn": "counter_teller", "cat": {"kind": "counter_transaction", "place": "wall", "support": True, "clear": 0.9,
                                                           "group": "bank", "top": 1.05}},
    "prop_check_table": {"fn": "check_table", "cat": {"kind": "check_table", "place": "center", "support": True, "clear": 0.8,
                                                     "group": "bank", "top": 1.05}},
    "prop_queue_post": {"fn": "queue_post", "cat": {"kind": "stanchion", "place": "floor", "group": "bank"}},
    "prop_note_counter": {"fn": "note_counter", "cat": {"kind": "note_counter", "place": "on", "hosts": _WORK_TOPS, "group": "bank"}},
    "prop_deposit_slips": {"fn": "deposit_slips", "cat": {"kind": "slip_tray", "place": "on", "hosts": ["check_table", "counter_transaction"],
                                                         "group": "bank"}},
    "prop_pendant_brass": {"fn": "pendant", "lit": True, "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True, "group": "bank", "pin_only": True,
                                                                 "light": {"type": "omni", "color": WARM, "energy": 2.2, "range": 7.5,
                                                                           "pos": [0.0, -1.62, 0.0]}}},
    "prop_pendant_brass_off": {"fn": "pendant", "lit": False, "cat": {"kind": "light_fixture", "place": "ceiling", "group": "bank", "pin_only": True}},
    "prop_clock_harbor": {"fn": "clock", "cat": {"kind": "clock", "place": "wall_mount", "z": 3.4, "fixture": True, "group": "bank",
                                                 "light": {"type": "omni", "color": "#FFE6C0", "energy": 0.9, "range": 4.0,
                                                           "pos": [0.0, 0.0, -0.7]}}},
    # ATM vestibule
    "prop_atm": {"fn": "atm", "cat": {"kind": "atm", "place": "wall", "clear": 0.9, "group": "bank"}},
    "prop_night_drop": {"fn": "night_drop", "cat": {"kind": "night_drop", "place": "wall", "clear": 0.8, "group": "bank"}},
    "prop_leaflet_rack": {"fn": "leaflet_rack", "cat": {"kind": "leaflet_rack", "place": "wall_mount", "z": 1.3, "group": "bank"}},
    # vault, count room, cash handling
    "prop_deposit_boxes": {"fn": "deposit_boxes", "cat": {"kind": "deposit_boxes", "place": "wall", "group": "bank"}},
    "prop_cash_trolley": {"fn": "cash_trolley", "cat": {"kind": "cash_cage", "place": "wall", "clear": 0.6, "group": "bank"}},
    "prop_microfiche": {"fn": "microfiche", "cat": {"kind": "microfiche", "place": "on", "hosts": ["desk", "table"], "group": "bank"}},
    "prop_convex_mirror": {"fn": "convex_mirror", "cat": {"kind": "convex_mirror", "place": "wall_mount", "z": 2.4, "group": "bank"}},
    "prop_vault_bench": {"fn": "vault_bench", "cat": {"kind": "bench", "place": "wall", "clear": 0.6, "group": "bank", "pin_only": True}},
    "prop_vault_table": {"fn": "vault_table", "cat": {"kind": "table", "place": "center", "support": True, "clear": 0.7, "group": "bank",
                                                     "pin_only": True}},
    # gameplay prefab visuals
    "prop_vault_door_round": {"fn": "vault_door", "cat": {"prefab": "door", "kind": "vault_door"}},
    "prop_cash_bags": {"fn": "cash_bags", "cat": {"prefab": "loot_spawn", "kind": "loot_spawn"}},
    "prop_cash_pallet": {"fn": "cash_pallet", "cat": {"prefab": "loot_spawn", "kind": "loot_spawn"}},
    "prop_night_drop_bags": {"fn": "night_drop_bags", "cat": {"prefab": "loot_spawn", "kind": "loot_spawn"}},
    "prop_cash_stack": {"fn": "cash_stack", "cat": {"prefab": "small_loot", "kind": "small_loot"}},
    "prop_keycard_bank": {"fn": "keycard", "cat": {"prefab": "keycard_pickup", "kind": "keycard"}},
}


# ---------------------------------------------------------------------------------- hall

def _counter_teller(k: Kit, p: dict) -> None:
    """Teller counter segment (17 m / 6 stations): walnut-panelled customer face (-Y) on a dark stone
    plinth, marble transaction top at 1.05 m, cash drawers on the staff side (+Y)."""
    w, d, h = 17.0 / 6.0, 0.8, 1.05
    o = k.obj("Counter")
    hard = o.part(bevel=0.004, segments=2)
    trim = o.part(bevel=0.0015)
    top = o.part(bevel=0.006, segments=2)
    y0, y1 = -d / 2, d / 2
    # carcass
    hard.bx((-w / 2, y0 + 0.08, 0.1), (w / 2, y1 - 0.03, h - 0.05), "walnut")
    # plinths (customer side stone, staff side recessed kick)
    hard.bx((-w / 2, y0 + 0.06, 0.0), (w / 2, y1 - 0.08, 0.1), "stone_dark")
    # customer face (-Y): three raised walnut panels per segment framed by brass beads
    pw = (w - 0.12) / 3
    for i in range(3):
        x0 = -w / 2 + 0.06 + i * pw + 0.03
        x1 = -w / 2 + 0.06 + (i + 1) * pw - 0.03
        hard.bx((x0, y0 + 0.06, 0.18), (x1, y0 + 0.08, h - 0.14), "walnut")
        hard.bx((x0 + 0.06, y0 + 0.045, 0.24), (x1 - 0.06, y0 + 0.06, h - 0.2), "walnut")
    trim.bx((-w / 2, y0 + 0.055, 0.1), (w / 2, y0 + 0.08, 0.13), "brass")
    trim.bx((-w / 2, y0 + 0.055, h - 0.09), (w / 2, y0 + 0.08, h - 0.07), "brass")
    for i in range(4):
        x = -w / 2 + 0.06 + i * pw
        trim.bx((x - 0.012, y0 + 0.06, 0.13), (x + 0.012, y0 + 0.08, h - 0.09), "brass")
    # marble top
    top.bx((-w / 2, y0, h - 0.05), (w / 2, y1, h), "marble")
    # staff side: cash drawers under the top, cupboard doors below
    for i in range(4):
        x0 = -w / 2 + 0.08 + i * (w - 0.16) / 4
        x1 = x0 + (w - 0.16) / 4 - 0.02
        hard.bx((x0, y1 - 0.03, h - 0.2), (x1, y1 - 0.01, h - 0.07), "walnut")
        knob(trim, (x0 + x1) / 2, y1 - 0.01, h - 0.135)
        hard.bx((x0, y1 - 0.03, 0.14), (x1, y1 - 0.01, h - 0.24), "walnut")
        trim.bx(((x0 + x1) / 2 - 0.05, y1 - 0.01, h - 0.34), ((x0 + x1) / 2 + 0.05, y1 + 0.004, h - 0.33), "brass")
    o.build()
    k.collision([((-w / 2, y0, 0.0), (w / 2, y1, h))])


def _check_table(k: Kit, p: dict) -> None:
    """Standing check-writing desk: marble top at 1.05 m on two cast-iron lyre legs, a brass
    gallery rail and a stretcher."""
    w, d, h = 1.4, 0.6, 1.05
    o = k.obj("Table")
    top = o.part(bevel=0.008, segments=2)
    iron = o.part(bevel=0.0)
    trim = o.part(bevel=0.002)
    top.bx((-w / 2, -d / 2, h - 0.05), (w / 2, d / 2, h), "marble")
    top.bx((-w / 2 + 0.06, -d / 2 + 0.05, h - 0.12), (w / 2 - 0.06, d / 2 - 0.05, h - 0.05), "walnut")
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.22)
        iron.lathe([(0.0, 0.0), (0.16, 0.0), (0.16, 0.04), (0.06, 0.1), (0.045, 0.2), (0.035, 0.5), (0.05, 0.75),
                    (0.04, h - 0.16), (0.06, h - 0.12), (0.0, h - 0.12)], "metal_dark", centre=(x, 0.0, 0.0), segs=16)
        iron.bx((x - 0.03, -d / 2 + 0.08, h - 0.14), (x + 0.03, d / 2 - 0.08, h - 0.12), "metal_dark")
    iron.rod((-w / 2 + 0.22, 0.0, 0.35), (w / 2 - 0.22, 0.0, 0.35), 0.022, "metal_dark", segs=10)
    # pen chains and a centre divider on the top
    for sx in (-0.3, 0.3):
        trim.cyl(0.018, 0.05, (sx, 0.0, h + 0.025), "brass", segs=12)
    trim.bx((-w / 2 + 0.1, -0.008, h), (w / 2 - 0.1, 0.008, h + 0.06), "brass")
    o.build()
    k.collision([((-w / 2, -d / 2, h - 0.12), (w / 2, d / 2, h)), ((-w / 2 + 0.06, -0.16, 0.0), (-w / 2 + 0.38, 0.16, h - 0.12)),
                 ((w / 2 - 0.38, -0.16, 0.0), (w / 2 - 0.06, 0.16, h - 0.12))])


def _queue_post(k: Kit, p: dict) -> None:
    """Two brass queue stanchions 1.6 m apart with a red velvet rope."""
    gap = 1.6
    o = k.obj("Stanchions")
    a = o.part(bevel=0.0)
    for sx in (-1, 1):
        x = sx * gap / 2
        a.lathe([(0.0, 0.0), (0.16, 0.0), (0.16, 0.02), (0.12, 0.045), (0.03, 0.06), (0.025, 0.9), (0.035, 0.92),
                 (0.04, 0.95), (0.0, 0.97)], "brass", centre=(x, 0.0, 0.0), segs=20)
    rope = o.part(bevel=0.0)
    pts = []
    n = 10
    for i in range(n + 1):
        t = i / n
        x = -gap / 2 + 0.05 + (gap - 0.1) * t
        z = 0.88 - 0.16 * 4 * t * (1 - t)
        pts.append((x, 0.0, z))
    rope.tube(pts, 0.018, "velvet_red", segs=8)
    o.build()
    k.collision([((-gap / 2 - 0.16, -0.16, 0.0), (gap / 2 + 0.16, 0.16, 0.97))])


def _note_counter(k: Kit, p: dict) -> None:
    o = k.obj("Counter")
    a = o.part(bevel=0.01, segments=2)
    a.profile_x([(-0.14, 0.0), (0.16, 0.0), (0.16, 0.12), (0.05, 0.25), (-0.14, 0.25)], -0.13, 0.13, "plastic_grey")
    t = o.part(bevel=0.002)
    t.bx((-0.1, -0.12, 0.25), (0.1, 0.0, 0.27), "plastic_black")
    t.bx((-0.09, 0.1, 0.02), (0.09, 0.17, 0.08), "plastic_black")
    t.bx((-0.06, 0.06, 0.16), (0.06, 0.12, 0.19), "plastic_black")
    s = o.part(bevel=0.0)
    s.bx((-0.05, 0.12, 0.165), (0.05, 0.123, 0.185), "emit_led_green")
    # a strapped bundle of notes in the stacker
    s.bx((-0.075, 0.105, 0.081), (0.075, 0.16, 0.1), "cash_green")
    o.build()


def _deposit_slips(k: Kit, p: dict) -> None:
    o = k.obj("Tray")
    a = o.part(bevel=0.002)
    a.bx((-0.16, -0.11, 0.0), (0.16, 0.11, 0.012), "brass")
    for sx in (-1, 1):
        a.bx((sx * 0.16 - 0.006, -0.11, 0.0), (sx * 0.16 + 0.006, 0.11, 0.03), "brass")
    a.bx((-0.16, -0.11, 0.0), (0.16, -0.098, 0.03), "brass")
    s = o.part(bevel=0.0)
    s.bx((-0.07, -0.09, 0.012), (0.07, 0.09, 0.022), "paper")
    s.bx((0.0, -0.09, 0.012), (0.14, 0.09, 0.018), "canvas_ivory")
    o.build()


def _pendant(k: Kit, p: dict) -> None:
    """Brass hall pendant: ceiling canopy, 1.45 m rod, gallery and an opal globe (lit or off)."""
    drop = 1.45
    o = k.obj("Pendant")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, -0.06), (0.09, -0.06), (0.1, -0.03), (0.1, 0.0), (0.0, 0.0)], "brass", segs=20)
    a.rod((0.0, 0.0, -0.06), (0.0, 0.0, -drop), 0.012, "brass", segs=8)
    a.lathe([(0.0, -drop - 0.02), (0.05, -drop - 0.02), (0.11, -drop - 0.06), (0.12, -drop - 0.09), (0.1, -drop - 0.1),
             (0.0, -drop - 0.06)], "brass", segs=20)
    a.torus(0.16, 0.012, (0.0, 0.0, -drop - 0.2), "brass", segs=24, rsegs=6)
    for i in range(3):
        ang = 2 * math.pi * i / 3
        a.rod((math.cos(ang) * 0.1, math.sin(ang) * 0.1, -drop - 0.09), (math.cos(ang) * 0.16, math.sin(ang) * 0.16, -drop - 0.2),
              0.006, "brass", segs=5)
    g = o.part(bevel=0.0)
    # unlit globes are milk glass (opaque white), so they still read as globes at night
    g.sphere(0.2, (0.0, 0.0, -drop - 0.3), "emit_warm" if p.get("lit") else "plastic_white", segs=20, rings=10)
    o.build()


def _clock(k: Kit, p: dict) -> None:
    """Brass harbour clock: drum case, lit ivory dial with brass batons (no numerals) and hands."""
    r = 0.5
    o = k.obj("Clock")
    case = o.part(bevel=0.0)
    case.lathe([(0.0, 0.0), (r + 0.05, 0.0), (r + 0.07, 0.04), (r + 0.07, 0.14), (r + 0.04, 0.18), (r, 0.18), (r, 0.16), (0.0, 0.16)],
               "brass", segs=40)
    face = o.part(bevel=0.0)
    face.cyl(r - 0.005, 0.004, (0.0, 0.0, 0.162), "emit_clock", segs=40)
    marks = o.part(bevel=0.0)
    for i in range(12):
        ang = 2 * math.pi * i / 12
        ln = 0.1 if i % 3 == 0 else 0.06
        wd = 0.03 if i % 3 == 0 else 0.016
        c = (math.sin(ang) * (r - 0.06 - ln / 2), math.cos(ang) * (r - 0.06 - ln / 2))
        rot_pts = []
        for dx, dy in ((-wd / 2, -ln / 2), (wd / 2, -ln / 2), (wd / 2, ln / 2), (-wd / 2, ln / 2)):
            rot_pts.append((c[0] + dx * math.cos(ang) + dy * math.sin(ang), c[1] - dx * math.sin(ang) + dy * math.cos(ang)))
        marks.slab(rot_pts, 0.164, 0.172, "metal_dark")
    # hands at 2:30 (the heist's hour)
    for ang, ln, wd in ((math.radians(75.0), 0.28, 0.035), (math.radians(180.0), 0.4, 0.022)):
        pts = [(-wd / 2, -0.05), (wd / 2, -0.05), (wd / 4, ln), (-wd / 4, ln)]
        rp = [(x * math.cos(ang) + y * math.sin(ang), -x * math.sin(ang) + y * math.cos(ang)) for x, y in pts]
        marks.slab(rp, 0.172, 0.18, "metal_dark")
    marks.cyl(0.025, 0.02, (0.0, 0.0, 0.18), "brass", segs=12)
    _turn_to_front(o)
    o.build()


def _turn_to_front(o, offset: tuple = (0.0, 0.0, 0.0)) -> None:
    """Parts modelled along +Z (back at z = 0, dial up = +Y) turned to face +Y (back at y = 0, dial up
    = +Z): (x, y, z) -> (-x, z, y), so the dial reads correctly from the front."""
    from mathutils import Matrix  # noqa: PLC0415 - Blender only

    mtx = Matrix.Translation(offset) @ Matrix.Rotation(math.pi, 4, "Y") @ Matrix.Rotation(-math.pi / 2, 4, "X")
    for part in o.parts:
        part.transform(mtx)


# ---------------------------------------------------------------------------------- ATM vestibule

def _atm(k: Kit, p: dict) -> None:
    """Free-standing lobby ATM backed to the wall: slate-green cabinet, lit header panel, recessed
    screen, keypad, card reader, cash slot and privacy hood."""
    w, d, h = 0.7, 0.72, 1.7
    o = k.obj("ATM")
    a = o.part(bevel=0.008, segments=2)
    t = o.part(bevel=0.002)
    s = o.part(bevel=0.0)
    y0, y1 = -d / 2, d / 2
    a.bx((-w / 2, y0, 0.0), (w / 2, y1 - 0.18, h), "metal_green")
    a.bx((-w / 2, y0, 0.0), (w / 2, y1, 0.85), "metal_green")
    # fascia shelf + keypad deck (sloped)
    a.profile_x([(y1 - 0.18, 0.85), (y1, 0.85), (y1, 0.95), (y1 - 0.18, 1.02)], -w / 2 + 0.02, w / 2 - 0.02, "metal_dark")
    # screen surround (tilted back) + screen
    a.profile_x([(y1 - 0.18, 1.02), (y1 - 0.14, 1.02), (y1 - 0.2, 1.42), (y1 - 0.18, 1.42)], -w / 2 + 0.03, w / 2 - 0.03, "metal_dark")
    s.profile_x([(y1 - 0.141, 1.06), (y1 - 0.135, 1.06), (y1 - 0.19, 1.38), (y1 - 0.196, 1.38)], -0.2, 0.2, "emit_screen")
    # privacy hood
    a.bx((-w / 2, y1 - 0.18, 1.42), (w / 2, y1 - 0.02, 1.47), "metal_dark")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.02)))
        a.bx((x0, y1 - 0.18, 0.95), (x1, y1 - 0.03, 1.47), "metal_dark")
    # lit header (no text: a mint light band)
    s.bx((-w / 2 + 0.04, y1 - 0.18 + 0.001, 1.52), (w / 2 - 0.04, y1 - 0.175, 1.64), "emit_mint")
    # keypad 4 x 3 on the deck
    for r in range(4):
        for c in range(3):
            x = -0.07 + c * 0.045
            yy = y1 - 0.05 - r * 0.03
            zz = 0.95 + (0.07 * (y1 - yy) / 0.18)
            t.bx((x - 0.017, yy - 0.012, zz), (x + 0.017, yy + 0.012, zz + 0.012), "steel")
    # card reader (green bezel) + receipt + cash slots on the fascia
    t.bx((0.13, y1 - 0.006, 0.86), (0.25, y1 + 0.02, 0.92), "plastic_black")
    s.bx((0.15, y1 + 0.02, 0.88), (0.23, y1 + 0.022, 0.9), "emit_led_green")
    t.bx((-0.22, y1 - 0.006, 0.7), (0.22, y1 + 0.015, 0.78), "steel")
    s.bx((-0.18, y1 + 0.015, 0.735), (0.18, y1 + 0.017, 0.745), "plastic_black")
    t.bx((0.15, y1 - 0.006, 0.6), (0.25, y1 + 0.012, 0.64), "steel")
    # plinth
    t.bx((-w / 2 + 0.02, y0 + 0.02, 0.0), (w / 2 - 0.02, y1 + 0.005, 0.06), "stone_dark")
    o.build()
    k.collision([((-w / 2, y0, 0.0), (w / 2, y1, 0.95)), ((-w / 2, y0, 0.95), (w / 2, y1 - 0.02, h))])


def _night_drop(k: Kit, p: dict) -> None:
    """Night depository head unit: steel cabinet with a brass pull-down hopper; the chute runs
    down into the basement depository safe. Dark parts are clean powder coat (no grime at arm's length)."""
    w, d, h = 0.8, 0.45, 1.3
    o = k.obj("NightDrop")
    a = o.part(bevel=0.006, segments=2)
    t = o.part(bevel=0.002)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h), "steel")
    a.bx((-w / 2 - 0.01, -d / 2, h - 0.06), (w / 2 + 0.01, d / 2 + 0.02, h), "powder_charcoal")
    a.bx((-w / 2 + 0.01, -d / 2 + 0.01, 0.0), (w / 2 - 0.01, d / 2 + 0.005, 0.08), "powder_charcoal")
    # hopper: a brass panel tilted out, with a handle
    t.profile_x([(d / 2, 0.86), (d / 2 + 0.06, 0.88), (d / 2 + 0.03, 1.12), (d / 2, 1.12)], -0.28, 0.28, "brass")
    t.rod((-0.15, d / 2 + 0.075, 0.9), (0.15, d / 2 + 0.075, 0.9), 0.012, "brass", segs=10)
    for sx in (-0.15, 0.15):
        t.rod((sx, d / 2 + 0.05, 0.9), (sx, d / 2 + 0.075, 0.9), 0.009, "brass", segs=8)
    # keyed panel and an envelope shelf below
    t.bx((-0.3, d / 2, 0.25), (0.3, d / 2 + 0.008, 0.75), "powder_charcoal")
    knob(t, 0.22, d / 2 + 0.008, 0.5, "steel", r=0.016)
    t.bx((-0.25, d / 2, 0.8), (0.25, d / 2 + 0.1, 0.82), "steel")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _leaflet_rack(k: Kit, p: dict) -> None:
    o = k.obj("Rack")
    a = o.part(bevel=0.002)
    w, h = 0.5, 0.6
    a.bx((-w / 2, 0.0, -h / 2), (w / 2, 0.012, h / 2), "metal_dark")
    s = o.part(bevel=0.0)
    for i in range(3):
        z = -h / 2 + 0.04 + i * 0.19
        for c in range(2):
            x0 = -w / 2 + 0.03 + c * 0.23
            a.bx((x0, 0.012, z), (x0 + 0.21, 0.06, z + 0.012), "glass_tinted")
            a.bx((x0, 0.048, z), (x0 + 0.21, 0.06, z + 0.08), "glass_tinted")
            key = ("paper", "paint_slate", "metal_red", "canvas_ivory")[(i + c) % 4]
            s.bx((x0 + 0.03, 0.02, z + 0.012), (x0 + 0.18, 0.04, z + 0.17), key)
    o.build()


# ---------------------------------------------------------------------------------- vault + cash

def _deposit_boxes(k: Kit, p: dict) -> None:
    """Safe-deposit box wall unit: steel carcass, 6 columns of brass-faced doors (small boxes on top,
    larger ones lower), two keyholes per door, a stone plinth and a cornice."""
    w, h, d = 1.8, 2.2, 0.45
    o = k.obj("Boxes")
    a = o.part(bevel=0.004, segments=1)
    doors = o.part(bevel=0.0025)
    keys = o.part(bevel=0.0)
    y0, y1 = -d / 2, d / 2
    a.bx((-w / 2, y0, 0.12), (w / 2, y1 - 0.01, h - 0.08), "steel")
    a.bx((-w / 2, y0, 0.0), (w / 2, y1, 0.12), "stone_dark")
    a.bx((-w / 2 - 0.01, y0, h - 0.08), (w / 2 + 0.01, y1 + 0.02, h), "metal_dark")
    cols = 6
    cw = (w - 0.06) / cols
    rows = [0.14] * 8 + [0.2] * 2 + [0.28]  # top to bottom heights (sum 1.88)
    z = h - 0.1
    for rh in rows:
        for c in range(cols):
            x0 = -w / 2 + 0.03 + c * cw
            doors.bx((x0 + 0.006, y1 - 0.01, z - rh + 0.006), (x0 + cw - 0.006, y1 + 0.006, z - 0.006), "brass")
            for kx in (0.32, 0.68):
                keys.cyl(0.008, 0.004, (x0 + cw * kx, y1 + 0.0075, z - rh * 0.5), "metal_dark", axis="Y", segs=8)
        z -= rh
    o.build()
    k.collision([((-w / 2, y0, 0.0), (w / 2, y1, h))])


def _cash_trolley(k: Kit, p: dict) -> None:
    """Wheeled cash cage: steel tube frame, mesh sides, two shelves with canvas cash bags."""
    w, d, h = 1.0, 0.7, 1.7
    o = k.obj("Trolley")
    f = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            f.rod((sx * (w / 2 - 0.02), sy * (d / 2 - 0.02), 0.12), (sx * (w / 2 - 0.02), sy * (d / 2 - 0.02), h), 0.018,
                  "steel", segs=8)
            f.cyl(0.05, 0.035, (sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), 0.05), "rubber", axis="X", segs=12)
            f.bx((sx * (w / 2 - 0.08) - 0.025, sy * (d / 2 - 0.08) - 0.025, 0.08), (sx * (w / 2 - 0.08) + 0.025,
                 sy * (d / 2 - 0.08) + 0.025, 0.12), "metal_dark")
    for z in (0.12, 0.85, h - 0.01):
        f.bx((-w / 2, -d / 2, z - 0.02), (w / 2, d / 2, z + 0.01), "steel")
    mesh = o.part(bevel=0.0)
    for x in [(-w / 2 + 0.05 + i * (w - 0.1) / 9) for i in range(10)]:
        for sy in (-1, 1):
            mesh.rod((x, sy * (d / 2 - 0.02), 0.13), (x, sy * (d / 2 - 0.02), h - 0.02), 0.004, "steel", segs=4)
    for y in [(-d / 2 + 0.05 + i * (d - 0.1) / 6) for i in range(7)]:
        mesh.rod((-(w / 2 - 0.02), y, 0.13), (-(w / 2 - 0.02), y, h - 0.02), 0.004, "steel", segs=4)
    bags = o.part(bevel=0.02, segments=2)
    for zb, n in ((0.13, 3), (0.86, 2)):
        for i in range(n):
            x = -w / 2 + 0.2 + i * (w - 0.4) / max(1, n - 1) if n > 1 else 0.0
            bags.bx((x - 0.14, -0.2, zb), (x + 0.14, 0.2, zb + 0.32), "canvas_bank")
            bags.cyl(0.03, 0.06, (x, 0.0, zb + 0.35), "canvas_bank", segs=8)
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _microfiche(k: Kit, p: dict) -> None:
    o = k.obj("Reader")
    a = o.part(bevel=0.01, segments=2)
    a.bx((-0.2, -0.22, 0.0), (0.2, 0.18, 0.1), "plastic_white")
    a.profile_x([(-0.22, 0.1), (-0.06, 0.1), (-0.12, 0.48), (-0.22, 0.48)], -0.2, 0.2, "plastic_white")
    s = o.part(bevel=0.0)
    s.profile_x([(-0.06, 0.13), (-0.058, 0.13), (-0.118, 0.45), (-0.12, 0.45)], -0.17, 0.17, "emit_screen")
    t = o.part(bevel=0.002)
    t.bx((-0.15, 0.0, 0.1), (0.15, 0.17, 0.12), "glass_tinted")
    knob(t, 0.16, 0.18, 0.05, "plastic_black", r=0.014)
    o.build()


def _convex_mirror(k: Kit, p: dict) -> None:
    """Inspection-passage convex mirror: wall plate, arm, chrome dome tilted down into the passage."""
    from mathutils import Matrix  # noqa: PLC0415 - Blender only

    o = k.obj("Mirror")
    a = o.part(bevel=0.0)
    a.bx((-0.04, 0.0, -0.04), (0.04, 0.012, 0.04), "metal_dark")
    a.rod((0.0, 0.006, 0.0), (0.0, 0.16, -0.02), 0.012, "metal_dark", segs=8)
    m = o.part(bevel=0.0)
    r = 0.25
    m.lathe([(r, 0.0), (r * 0.95, 0.03), (r * 0.8, 0.06), (r * 0.55, 0.085), (0.0, 0.1)], "chrome", segs=24)
    m.torus(r, 0.012, (0.0, 0.0, 0.0), "plastic_black", segs=24, rsegs=6)
    m.cyl(r, 0.01, (0.0, 0.0, -0.005), "plastic_black", segs=24)
    m.transform(Matrix.Translation((0.0, 0.2, -0.04)) @ Matrix.Rotation(-math.radians(110.0), 4, "X"))
    o.build()


def _vault_bench(k: Kit, p: dict) -> None:
    """Viewing bench: walnut slab on steel legs (antechamber, coupon booths)."""
    w, d, h = 1.6, 0.42, 0.45
    o = k.obj("Bench")
    a = o.part(bevel=0.006, segments=2)
    a.bx((-w / 2, -d / 2, h - 0.05), (w / 2, d / 2, h), "walnut")
    legs4(a, w, d, h - 0.05, 0.06, 0.05, "steel")
    a.bx((-w / 2 + 0.11, -0.02, 0.12), (w / 2 - 0.11, 0.02, 0.15), "steel")
    o.build()
    k.collision([((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h))])


def _vault_table(k: Kit, p: dict) -> None:
    """Steel vault inspection table with a leather-lined top."""
    w, d, h = 1.2, 0.7, 0.74
    o = k.obj("Table")
    a = o.part(bevel=0.004, segments=1)
    a.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), "steel")
    legs4(a, w, d, h - 0.04, 0.03, 0.04, "steel")
    a.bx((-w / 2 + 0.05, -d / 2 + 0.05, 0.12), (w / 2 - 0.05, d / 2 - 0.05, 0.14), "steel")
    s = o.part(bevel=0.0)
    s.bx((-w / 2 + 0.06, -d / 2 + 0.06, h), (w / 2 - 0.06, d / 2 - 0.06, h + 0.004), "leather")
    o.build()
    k.collision([((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h + 0.004)),
                 ((-w / 2 + 0.03, -d / 2 + 0.03, 0.0), (w / 2 - 0.03, d / 2 - 0.03, h - 0.04))])


def _vault_door(k: Kit, p: dict) -> None:
    """Round vault door (door prefab, VAULT lock) for a 2.4 x 2.3 m opening in a 0.6 m wall:
    `Frame` = steel collar plate filling the opening around a 1.12 m round bore (collision: the
    corners), `Leaf` = 2.2 m stepped door plug hinged on its left edge (-X, extends +X), with
    locking bolts, a hinge arm, a spoked hand wheel and the time-lock box on the front (+Y)."""
    wall_t = 0.6
    ow, oh = 2.4, 2.3
    r_bore = 1.12
    cz = oh / 2
    fr = k.obj("Frame")
    plate = fr.part(bevel=0.004, segments=1)
    n = 48
    hole = [(math.cos(2 * math.pi * i / n) * r_bore, cz + math.sin(2 * math.pi * i / n) * r_bore) for i in range(n)]
    outer = [(-ow / 2, 0.0), (ow / 2, 0.0), (ow / 2, oh), (-ow / 2, oh)]
    plate.prism(outer, holes=[hole], axis="Y", start=-wall_t / 2 - 0.002, end=wall_t / 2 + 0.002, mat=plate.m("steel"))
    ring = fr.part(bevel=0.0)
    # lip ring hugs the bore so nothing dips below the floor line (bottom 0.01 m above z 0)
    ring.torus(r_bore + 0.005, 0.015, (0.0, wall_t / 2 + 0.015, cz), "metal_dark", segs=48, rsegs=8, axis="Y")
    for i in range(16):
        ang = 2 * math.pi * (i + 0.5) / 16
        if cz + math.sin(ang) * (r_bore + 0.12) < 0.06:
            continue
        ring.cyl(0.022, 0.02, (math.cos(ang) * (r_bore + 0.12), wall_t / 2 + 0.012, cz + math.sin(ang) * (r_bore + 0.12)), "steel",
                 axis="Y", segs=10)
    obj = fr.build()
    cols = []
    c = 0.36
    for sx in (-1, 1):
        x0, x1 = sorted((sx * ow / 2, sx * (ow / 2 - c)))
        cols.append(((x0, -wall_t / 2, 0.0), (x1, wall_t / 2, c * 0.6)))
        cols.append(((x0, -wall_t / 2, oh - c * 0.6), (x1, wall_t / 2, oh)))
    k.collision(cols, kind="trimesh", parent=obj)
    # leaf: hinge on the -X edge of the bore, front face at the antechamber side (+Y)
    # PO-7: the plug fits the bore with 8 mm clearance (2 cm left a see-through crescent at the sill).
    rr = r_bore - 0.008
    hinge_x = -rr  # leaf spans hinge_x .. hinge_x + 2 * rr: width 2.22 m (door width_m 2.2)
    pivot = k.empty("Leaf", (hinge_x, 0.0, 0.0))
    lf = k.obj("LeafMesh", parent=pivot)
    body = lf.part(bevel=0.0)
    ox = -hinge_x  # leaf-local x of the bore centre
    body.cyl(rr, 0.22, (ox, wall_t / 2 - 0.11 + 0.03, cz), "steel", axis="Y", segs=48)
    body.cyl(rr - 0.12, wall_t - 0.16, (ox, -0.05, cz), "steel", axis="Y", segs=40)
    face = lf.part(bevel=0.0)
    face.torus(rr - 0.06, 0.03, (ox, wall_t / 2 + 0.04, cz), "metal_dark", segs=48, rsegs=6, axis="Y")
    face.cyl(0.42, 0.02, (ox, wall_t / 2 + 0.05, cz), "metal_dark", axis="Y", segs=32)
    # spoked hand wheel
    face.torus(0.34, 0.025, (ox, wall_t / 2 + 0.2, cz), "chrome", segs=32, rsegs=8, axis="Y")
    face.cyl(0.08, 0.16, (ox, wall_t / 2 + 0.13, cz), "chrome", axis="Y", segs=16)
    for i in range(4):
        ang = math.pi / 4 + i * math.pi / 2
        face.rod((ox, wall_t / 2 + 0.2, cz), (ox + math.cos(ang) * 0.34, wall_t / 2 + 0.2, cz + math.sin(ang) * 0.34), 0.018,
                 "chrome", segs=8)
    # locking bolt heads round the rim and the time-lock box above the wheel
    for i in range(12):
        ang = 2 * math.pi * i / 12
        face.cyl(0.035, 0.03, (ox + math.cos(ang) * (rr - 0.18), wall_t / 2 + 0.04, cz + math.sin(ang) * (rr - 0.18)), "steel",
                 axis="Y", segs=12)
    face.bx((ox - 0.16, wall_t / 2 + 0.03, cz + 0.52), (ox + 0.16, wall_t / 2 + 0.1, cz + 0.72), "metal_dark")
    face.bx((ox - 0.12, wall_t / 2 + 0.1, cz + 0.56), (ox + 0.12, wall_t / 2 + 0.104, cz + 0.68), "glass_tinted")
    # hinge arm on the -X side (pivot axis) and the hinge pin
    face.bx((0.0, wall_t / 2 + 0.03, cz - 0.35), (0.35, wall_t / 2 + 0.16, cz + 0.35), "metal_dark")
    face.cyl(0.07, 0.9, (0.07, wall_t / 2 + 0.1, cz), "steel", segs=16)
    lf.build()
    k.empty("Handle", (ox, wall_t / 2 + 0.2, cz), parent=pivot)


def _cash_bags(k: Kit, p: dict) -> None:
    """Pile of canvas cash bags (tied necks) on the floor: the vault cage / night-drop loot."""
    o = k.obj("Bags")
    a = o.part(bevel=0.03, segments=2)
    t = o.part(bevel=0.0)
    spots = [(-0.3, -0.1, 0.0, 0.0), (0.05, -0.15, 0.0, 0.2), (0.35, 0.05, 0.0, -0.3), (-0.12, 0.18, 0.0, 0.5),
             (0.0, 0.0, 0.3, 0.1), (0.2, 0.2, 0.0, 0.9)]
    for x, y, z, rot in spots:
        cs, sn = math.cos(rot), math.sin(rot)
        pts = [(x + dx * cs - dy * sn, y + dx * sn + dy * cs) for dx, dy in ((-0.15, -0.11), (0.15, -0.11), (0.15, 0.11), (-0.15, 0.11))]
        a.slab(pts, z, z + 0.26, "canvas_bank")
        t.cyl(0.04, 0.05, (x, y, z + 0.285), "canvas_bank", segs=8)
        t.cyl(0.045, 0.012, (x, y, z + 0.265), "metal_red", segs=8)
    o.build()


def _night_drop_bags(k: Kit, p: dict) -> None:
    """Night-depository pouches inside the depository safe (PO6-05): flat zipped bank bags, two stacks of three
    (about 0.72 x 0.5 m, fits the MEDIUM safe's compartment), a lock tab and a paper tag on each."""
    o = k.obj("Pouches")
    a = o.part(bevel=0.02, segments=2)
    t = o.part(bevel=0.0)
    lw, ld, lh = 0.32, 0.22, 0.075
    for sx, base_rot in ((-0.19, 0.08), (0.19, -0.12)):
        for layer in range(3):
            rot = base_rot + 0.09 * (layer - 1) * (1 if sx < 0 else -1)
            cs, sn = math.cos(rot), math.sin(rot)
            x, y, z = sx, 0.02 * (layer - 1), layer * lh
            pts = [(x + dx * cs - dy * sn, y + dx * sn + dy * cs)
                   for dx, dy in ((-lw / 2, -ld / 2), (lw / 2, -ld / 2), (lw / 2, ld / 2), (-lw / 2, ld / 2))]
            a.slab(pts, z, z + lh - 0.006, "canvas_bank")
            zx, zy = x + (lw / 2 - 0.03) * cs, y + (lw / 2 - 0.03) * sn
            t.bx((zx - 0.02, zy - 0.03, z + lh - 0.008), (zx + 0.02, zy + 0.03, z + lh - 0.002), "metal_red")
            tx, ty = x - (lw / 2 - 0.05) * cs, y - (lw / 2 - 0.05) * sn
            t.bx((tx - 0.03, ty - 0.02, z + lh - 0.006), (tx + 0.03, ty + 0.02, z + lh - 0.003), "paper")
    o.build()


def _cash_pallet(k: Kit, p: dict) -> None:
    """The Co-op's pallet of shrink-wrapped cash bricks."""
    w, d = 1.2, 0.8
    o = k.obj("Pallet")
    a = o.part(bevel=0.004)
    for y in (-d / 2 + 0.05, 0.0, d / 2 - 0.05):
        a.bx((-w / 2, y - 0.05, 0.0), (w / 2, y + 0.05, 0.1), "wood_pine")
    for i in range(7):
        x = -w / 2 + 0.07 + i * (w - 0.14) / 6
        a.bx((x - 0.06, -d / 2, 0.1), (x + 0.06, d / 2, 0.122), "wood_pine")
    b = o.part(bevel=0.006)
    lw, ld, lh = 0.36, 0.24, 0.14
    for layer in range(4):
        z = 0.122 + layer * lh
        for ix in range(3):
            for iy in range(3):
                x = -w / 2 + 0.06 + ix * (lw + 0.02) + lw / 2
                y = -d / 2 + 0.04 + iy * (ld + 0.02) + ld / 2
                if layer == 3 and (ix + iy) % 2 == 1:
                    continue
                b.bx((x - lw / 2, y - ld / 2, z), (x + lw / 2, y + ld / 2, z + lh - 0.004), "cash_green")
                b.bx((x - 0.02, y - ld / 2 - 0.002, z), (x + 0.02, y + ld / 2 + 0.002, z + lh - 0.004), "paper")
    o.build()


def _cash_stack(k: Kit, p: dict) -> None:
    """Small loot: two strapped stacks of notes."""
    o = k.obj("Cash")
    a = o.part(bevel=0.003)
    for i, (x, rot) in enumerate(((-0.05, 0.1), (0.07, -0.15))):
        cs, sn = math.cos(rot), math.sin(rot)
        pts = [(x + dx * cs - dy * sn, dx * sn + dy * cs) for dx, dy in ((-0.08, -0.037), (0.08, -0.037), (0.08, 0.037), (-0.08, 0.037))]
        a.slab(pts, 0.0, 0.05 + 0.01 * i, "cash_green")
        band = [(x + dx * cs - dy * sn, dx * sn + dy * cs) for dx, dy in ((-0.015, -0.039), (0.015, -0.039), (0.015, 0.039),
                                                                          (-0.015, 0.039))]
        a.slab(band, 0.0, 0.052 + 0.01 * i, "paper")
    o.build()


def _keycard(k: Kit, p: dict) -> None:
    o = k.obj("Card")
    a = o.part(bevel=0.0)
    a.bx((-0.043, -0.027, 0.0), (0.043, 0.027, 0.003), "plastic_white")
    a.bx((-0.039, 0.008, 0.003), (0.039, 0.02, 0.0045), "paint_slate")
    a.bx((-0.03, -0.018, 0.003), (-0.012, -0.004, 0.0042), "brass")
    o.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
