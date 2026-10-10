"""Visuals for the remaining gameplay prefabs (visual_slots.md / systems/prefabs/README.md).

Exact node names per prefab; no collision (prefabs own it). Blender +Y = Godot -Z (the front).

* safe (large workshop safe): `Body` (hollow carcass + shelf), `Door` (hinge pivot, -X edge),
  `DrillPoint` (-Z into the lock), `LootAnchor`.
* security_camera wall / ceiling: `Mount`, `Head` (pivot), `Lens` (-Z = view), `Led`.
* keycard_reader, keypad: `Panel`, `Led` (wall, back-centre pivot, mounted at 1.2 m).
* alarm_button, phone: no required nodes (`Panel`/`Button`, `Base`/`Handset`).
* camera_station: `Desk`, `Screens` (screen faces only), `Monitors`, `Seat` (operator faces the
  screens, Godot +Z).
* body_container (dumpster): `Body`, `Lid` (pivot on the back top edge), `Inside`.
* ladder (fire-escape drop ladder): `Top`, `Bottom` markers, climb side -Z.
* secure_zone van: `Body`, `DoorL`, `DoorR` (rear door hinges), `DropAnchor`; rear faces -Z.
* loot bag: `Bag` (pivot bottom-centre), light / medium / heavy.
* drill device: `Bit` (spins about Godot Z); origin at the bit tip, the bit points -Z.
"""

import math

from _pb import Kit, panel_door

TRI_BUDGET = 12000
VARIANTS = {
    "prop_safe_large": {"fn": "safe", "cat": {"prefab": "safe", "kind": "safe"}},
    "prop_security_camera_wall": {"fn": "camera_wall", "cat": {"prefab": "security_camera", "kind": "security_camera", "mount": "wall"}},
    "prop_security_camera_ceiling": {"fn": "camera_ceiling", "cat": {"prefab": "security_camera", "kind": "security_camera", "mount": "ceiling"}},
    "prop_keycard_reader": {"fn": "keycard_reader", "cat": {"prefab": "keycard_reader", "kind": "keycard_reader", "mount": "wall"}},
    "prop_keypad": {"fn": "keypad", "cat": {"prefab": "keypad", "kind": "keypad", "mount": "wall"}},
    "prop_alarm_button": {"fn": "alarm_button", "cat": {"prefab": "alarm_button", "kind": "alarm_button", "mount": "wall"}},
    "prop_phone_wall": {"fn": "phone_wall", "cat": {"prefab": "phone", "kind": "phone", "mount": "wall"}},
    "prop_camera_station": {"fn": "camera_station", "cat": {"prefab": "camera_station", "kind": "camera_station"}},
    "prop_dumpster": {"fn": "dumpster", "cat": {"prefab": "body_container", "kind": "dumpster"}},
    "prop_ladder_fire_escape_h300": {"fn": "ladder", "h": 3.0, "cat": {"prefab": "ladder", "kind": "ladder"}},
    "prop_ladder_fire_escape_h420": {"fn": "ladder", "h": 4.2, "cat": {"prefab": "ladder", "kind": "ladder"}},
    "veh_van_secure": {"fn": "van", "cat": {"prefab": "secure_zone", "kind": "van"}},
    "prop_loot_bag_light": {"fn": "bag", "size": (0.5, 0.28, 0.26), "cat": {"prefab": "loot_bag", "kind": "loot_bag"}},
    "prop_loot_bag_medium": {"fn": "bag", "size": (0.62, 0.34, 0.31), "cat": {"prefab": "loot_bag", "kind": "loot_bag"}},
    "prop_loot_bag_heavy": {"fn": "bag", "size": (0.74, 0.4, 0.36), "cat": {"prefab": "loot_bag", "kind": "loot_bag"}},
    "prop_drill_device": {"fn": "drill", "cat": {"prefab": "drill", "kind": "drill"}},
}


# ------------------------------------------------------------------------------------- safe

def _safe(k: Kit, p: dict) -> None:
    w, d, h, foot = 0.8, 0.7, 1.32, 0.07
    wall = 0.07
    body = k.obj("Body")
    hard = body.part(bevel=0.006, segments=2)
    trim = body.part(bevel=0.002)
    inner = body.part(bevel=0.0)
    y0, y1 = -d / 2, d / 2
    z0, z1 = foot, foot + h
    # plinth feet
    for sx in (-1, 1):
        fx0, fx1 = sorted((sx * (w / 2 - 0.12), sx * (w / 2 - 0.02)))
        hard.bx((fx0, y0 + 0.03, 0.0), (fx1, y1 - 0.03, foot), "metal_dark")
    hard.bx((-w / 2 + 0.03, y0 + 0.03, 0.0), (w / 2 - 0.03, y1 - 0.03, 0.03), "metal_dark")
    # hollow carcass: back, sides, top, bottom, with a front face frame
    hard.bx((-w / 2, y0, z0), (w / 2, y0 + wall, z1), "metal_green")
    hard.bx((-w / 2, y0, z0), (-w / 2 + wall, y1, z1), "metal_green")
    hard.bx((w / 2 - wall, y0, z0), (w / 2, y1, z1), "metal_green")
    hard.bx((-w / 2, y0, z1 - wall), (w / 2, y1, z1), "metal_green")
    hard.bx((-w / 2, y0, z0), (w / 2, y1, z0 + wall), "metal_green")
    # brass trim: frame round the door opening, corner beads, top band
    trim.bx((-w / 2 - 0.004, y1 - 0.004, z0 + wall - 0.012), (w / 2 + 0.004, y1 + 0.004, z0 + wall), "brass")
    trim.bx((-w / 2 - 0.004, y1 - 0.004, z1 - wall), (w / 2 + 0.004, y1 + 0.004, z1 - wall + 0.012), "brass")
    for sx in (-1, 1):
        trim.bx((sx * w / 2 - 0.006, y0 - 0.006, z1 - 0.06), (sx * w / 2 + 0.006, y1 + 0.006, z1 - 0.045), "brass")
        trim.bx((sx * w / 2 - 0.006, y0 - 0.006, z0 + 0.03), (sx * w / 2 + 0.006, y1 + 0.006, z0 + 0.045), "brass")
    # interior: shelf and steel lining
    inner.bx((-w / 2 + wall, y0 + wall, z0 + wall), (w / 2 - wall, y0 + wall + 0.004, z1 - wall), "steel")
    inner.bx((-w / 2 + wall, y0 + wall, z0 + 0.55), (w / 2 - wall, y1 - 0.12, z0 + 0.565), "steel")
    body.build()
    # door: hinge on the -X edge of the opening, flush with the front face
    ow = w - 2 * wall
    oz0, oz1 = z0 + wall, z1 - wall
    hinge = (-ow / 2, y1, oz0)
    door = k.empty("Door", hinge)
    dm = k.obj("DoorMesh", parent=door)
    dh = dm.part(bevel=0.005, segments=2)
    dt = dm.part(bevel=0.0015)
    dw, dz = ow - 0.006, oz1 - oz0 - 0.006
    dh.bx((0.003, -0.11, 0.003), (dw, 0.0, dz), "metal_green")
    dh.bx((0.05, 0.0, 0.05), (dw - 0.05, 0.014, dz - 0.05), "metal_green")
    for (a0, a1, b0, b1) in ((0.035, dw - 0.035, 0.035, 0.045), (0.035, dw - 0.035, dz - 0.045, dz - 0.035),
                             (0.035, 0.045, 0.035, dz - 0.035), (dw - 0.045, dw - 0.035, 0.035, dz - 0.035)):
        dt.bx((a0, 0.0, b0), (a1, 0.004, b1), "brass")
    cx, cz = dw * 0.62, dz * 0.62
    dt.cyl(0.075, 0.012, (cx, 0.02, cz), "brass", axis="Y", segs=32)
    dt.cyl(0.058, 0.03, (cx, 0.036, cz), "metal_dark", axis="Y", segs=32)
    dt.cyl(0.02, 0.01, (cx, 0.055, cz), "brass", axis="Y", segs=16)
    for i in range(24):
        a = 2 * math.pi * i / 24
        dt.cbox((cx + math.cos(a) * 0.066, 0.027, cz + math.sin(a) * 0.066), (0.004, 0.006, 0.004), "plastic_white")
    hx, hz = dw * 0.62, dz * 0.33
    dt.cyl(0.03, 0.03, (hx, 0.025, hz), "brass", axis="Y", segs=20)
    for i in range(3):
        a = math.pi / 2 + 2 * math.pi * i / 3
        tip = (hx + math.cos(a) * 0.13, 0.05, hz + math.sin(a) * 0.13)
        dt.rod((hx, 0.04, hz), tip, 0.008, "brass", segs=8)
        dt.sphere(0.016, tip, "brass", segs=10, rings=6)
    # nameplate
    dt.bx((dw * 0.5 - 0.11, 0.0, dz - 0.16), (dw * 0.5 + 0.11, 0.004, dz - 0.11), "brass")
    for z in (0.2, dz - 0.2):
        dt.cyl(0.014, 0.12, (-0.008, -0.05, z), "brass", segs=12)
    dm.build()
    k.empty("DrillPoint", (-ow / 2 + cx, y1 + 0.06, oz0 + cz), rotation=(0.0, 0.0, math.pi))
    k.empty("LootAnchor", (0.0, 0.0, z0 + wall + 0.002))


# ----------------------------------------------------------------------------------- cameras

def _camera_head(k: Kit, head) -> None:
    hm = k.obj("Housing", parent=head)
    hp = hm.part(bevel=0.006, segments=2)
    hp.bx((-0.055, -0.02, -0.05), (0.055, 0.2, 0.05), "plastic_white")
    hp.bx((-0.07, -0.02, 0.05), (0.07, 0.24, 0.062), "plastic_white")
    lp = hm.part(bevel=0.0)
    lp.cyl(0.032, 0.02, (0.0, 0.205, 0.0), "plastic_black", axis="Y", segs=20)
    lp.cyl(0.022, 0.006, (0.0, 0.217, 0.0), "glass_tinted", axis="Y", segs=20)
    hm.build()
    led = k.obj("Led", parent=head)
    led.part(bevel=0.0).cyl(0.005, 0.006, (0.04, 0.2, -0.032), "emit_led_red", axis="Y", segs=8)
    led.build()
    k.empty("Lens", (0.0, 0.222, 0.0), parent=head)


def _camera_wall(k: Kit, p: dict) -> None:
    mount = k.obj("Mount")
    mp = mount.part(bevel=0.004, segments=2)
    mp.bx((-0.05, 0.0, -0.07), (0.05, 0.015, 0.07), "plastic_white")
    mp.rod((0.0, 0.01, 0.0), (0.0, 0.14, -0.05), 0.016, "plastic_white", segs=12)
    mp.sphere(0.022, (0.0, 0.15, -0.06), "plastic_white", segs=12, rings=6)
    mount.build()
    head = k.empty("Head", (0.0, 0.15, -0.06))
    _camera_head(k, head)


def _camera_ceiling(k: Kit, p: dict) -> None:
    mount = k.obj("Mount")
    mp = mount.part(bevel=0.004, segments=2)
    mp.cyl(0.06, 0.015, (0.0, 0.0, -0.0075), "plastic_white", segs=24)
    mp.rod((0.0, 0.0, -0.01), (0.0, 0.0, -0.14), 0.016, "plastic_white", segs=12)
    mp.sphere(0.022, (0.0, 0.0, -0.15), "plastic_white", segs=12, rings=6)
    mount.build()
    head = k.empty("Head", (0.0, 0.0, -0.21))
    _camera_head(k, head)


# ----------------------------------------------------------------------------- wall devices

def _keycard_reader(k: Kit, p: dict) -> None:
    pan = k.obj("Panel")
    pp = pan.part(bevel=0.004, segments=2)
    pp.bx((-0.045, 0.0, -0.075), (0.045, 0.024, 0.075), "plastic_black")
    pp.bx((-0.035, 0.024, -0.02), (0.035, 0.028, 0.05), "glass_tinted")
    pp.bx((-0.03, 0.024, -0.06), (0.03, 0.03, -0.04), "plastic_grey")
    pp.bx((-0.032, 0.0, -0.08), (0.032, 0.03, -0.075), "steel")
    pan.build()
    led = k.obj("Led")
    led.part(bevel=0.0).cbox((0.0, 0.029, 0.062), (0.03, 0.006, 0.006), "emit_led_red")
    led.build()


def _keypad(k: Kit, p: dict) -> None:
    pan = k.obj("Panel")
    pp = pan.part(bevel=0.004, segments=2)
    kp = pan.part(bevel=0.0015)
    pp.bx((-0.05, 0.0, -0.08), (0.05, 0.022, 0.08), "steel")
    pp.bx((-0.038, 0.022, 0.035), (0.038, 0.025, 0.065), "glass_tinted")
    for r in range(4):
        for c in range(3):
            x = (c - 1) * 0.026
            z = 0.012 - r * 0.024
            kp.bx((x - 0.01, 0.022, z - 0.009), (x + 0.01, 0.03, z + 0.009), "chrome")
    pan.build()
    led = k.obj("Led")
    led.part(bevel=0.0).cyl(0.004, 0.005, (0.04, 0.025, 0.072), "emit_led_red", axis="Y", segs=8)
    led.build()


def _alarm_button(k: Kit, p: dict) -> None:
    pan = k.obj("Panel")
    pp = pan.part(bevel=0.004, segments=2)
    pp.bx((-0.05, 0.0, -0.05), (0.05, 0.03, 0.05), "metal_red")
    pp.bx((-0.04, 0.03, -0.042), (0.04, 0.032, -0.03), "plastic_white")
    pan.build()
    btn = k.obj("Button")
    bp = btn.part(bevel=0.0)
    bp.cyl(0.022, 0.012, (0.0, 0.036, 0.008), "plastic_black", axis="Y", segs=20)
    cap = btn.part(bevel=0.0)
    cap.lathe([(0.0, 0.0), (0.02, 0.0), (0.021, 0.008), (0.012, 0.016), (0.0, 0.017)], "metal_yellow",
              centre=(0.0, 0.0, 0.0), segs=20)
    for v in cap.bm.verts:
        x, y, z = v.co
        v.co = (x, 0.042 + z, 0.008 + y)
    btn.build()


def _phone_wall(k: Kit, p: dict) -> None:
    base = k.obj("Base")
    bp = base.part(bevel=0.006, segments=2)
    bp.bx((-0.06, 0.0, -0.1), (0.06, 0.045, 0.1), "plastic_grey")
    for r in range(4):
        for c in range(3):
            bp.bx(((c - 1) * 0.022 - 0.008, 0.045, -0.07 + r * 0.02 - 0.007), ((c - 1) * 0.022 + 0.008, 0.05, -0.07 + r * 0.02 + 0.007), "plastic_white")
    base.build()
    hs = k.obj("Handset")
    hp = hs.part(bevel=0.008, segments=2)
    hp.bx((-0.085, 0.045, 0.015), (-0.04, 0.085, 0.2), "plastic_black")
    hp.bx((-0.09, 0.05, 0.17), (-0.035, 0.09, 0.22), "plastic_black")
    hp.bx((-0.09, 0.05, 0.0), (-0.035, 0.09, 0.05), "plastic_black")
    hs.build()


# ---------------------------------------------------------------------------- camera station

def _camera_station(k: Kit, p: dict) -> None:
    w, d, h = 1.6, 0.8, 0.75
    desk = k.obj("Desk")
    top = desk.part(bevel=0.004, segments=2)
    top.bx((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h), "stone_dark")
    for sx in (-1, 1):
        px0, px1 = sorted((sx * w / 2, sx * (w / 2 - 0.05)))
        top.bx((px0, -d / 2 + 0.03, 0.0), (px1, d / 2 - 0.03, h - 0.03), "metal_dark")
    top.bx((-w / 2 + 0.05, -d / 2 + 0.05, 0.25), (w / 2 - 0.05, -d / 2 + 0.07, h - 0.03), "metal_dark")
    # pedestal with drawers on the right
    top.bx((0.3, -d / 2 + 0.06, 0.0), (w / 2 - 0.05, d / 2 - 0.04, h - 0.03), "metal_grey")
    for i in range(3):
        z0 = 0.04 + i * 0.22
        top.bx((0.32, d / 2 - 0.04, z0), (w / 2 - 0.07, d / 2 - 0.02, z0 + 0.2), "metal_grey")
        top.bx((0.5, d / 2 - 0.02, z0 + 0.15), (0.62, d / 2 - 0.005, z0 + 0.165), "steel")
    # keyboard, mouse, phone, mug, notebook on the desk (operator side = +Y)
    kb = desk.part(bevel=0.002)
    kb.bx((-0.22, 0.12, h), (0.22, 0.27, h + 0.022), "plastic_black")
    kb.bx((0.3, 0.16, h), (0.36, 0.25, h + 0.03), "plastic_black")
    kb.bx((-0.62, 0.05, h), (-0.4, 0.33, h + 0.012), "paper")
    kb.cyl(0.04, 0.1, (0.55, 0.2, h + 0.05), "ceramic", segs=16)
    kb.bx((-0.7, -0.15, h), (-0.5, 0.02, h + 0.06), "plastic_grey")
    desk.build()
    # monitor wall: 3 x 2 screens on a frame behind the desk (-Y = Godot +Z)
    mon = k.obj("Monitors")
    mp = mon.part(bevel=0.004)
    sc = k.obj("Screens")
    sp = sc.part(bevel=0.0)
    mw, mh = 0.5, 0.31
    yb = -d / 2 + 0.06
    for sx in (-1, 1):
        mp.bx((sx * 0.72 - 0.025, yb - 0.05, h), (sx * 0.72 + 0.025, yb, 1.75), "metal_dark")
    mp.bx((-0.75, yb - 0.05, 1.7), (0.75, yb, 1.75), "metal_dark")
    for r in range(2):
        for c in range(3):
            x = (c - 1) * (mw + 0.02)
            z = 1.06 + r * (mh + 0.02)
            mp.bx((x - mw / 2, yb, z - mh / 2), (x + mw / 2, yb + 0.04, z + mh / 2), "plastic_black")
            sp.bx((x - mw / 2 + 0.012, yb + 0.04, z - mh / 2 + 0.012), (x + mw / 2 - 0.012, yb + 0.043, z + mh / 2 - 0.012), "emit_screen")
    # a desk monitor (for the operator) on a stand
    mp.bx((-0.08, -0.05, h), (0.08, 0.05, h + 0.012), "plastic_black")
    mp.bx((-0.02, -0.03, h), (0.02, -0.01, h + 0.2), "plastic_black")
    mp.bx((-0.28, -0.03, h + 0.12), (0.28, 0.0, h + 0.44), "plastic_black")
    sp.bx((-0.27, 0.0, h + 0.13), (0.27, 0.003, h + 0.43), "emit_screen")
    mon.build()
    sc.build()
    k.empty("Seat", (0.0, 0.75, 0.45), rotation=(0.0, 0.0, math.pi))


# ---------------------------------------------------------------------------------- dumpster

def _dumpster(k: Kit, p: dict) -> None:
    w, d, h = 1.8, 1.0, 1.1
    body = k.obj("Body")
    hard = body.part(bevel=0.008, segments=1)
    run = body.part(bevel=0.0)
    # tapered tub: wider at the top, front (+Y) slopes
    outline = [(-d / 2 + 0.12, 0.18), (d / 2 - 0.02, 0.18), (d / 2, h - 0.06), (-d / 2, h - 0.06)]
    hard.profile_x(outline, -w / 2 + 0.02, w / 2 - 0.02, "metal_green_worn")
    hard.bx((-w / 2, -d / 2 - 0.02, h - 0.1), (w / 2, d / 2 + 0.02, h - 0.04), "metal_green_worn")
    for sx in (-1, 1):
        hard.bx((sx * (w / 2 - 0.01) - 0.015, -d / 2 + 0.1, 0.2), (sx * (w / 2 - 0.01) + 0.015, d / 2 - 0.04, h - 0.1), "metal_green_worn")
        hard.bx((sx * (w / 2 + 0.02) - 0.03, -0.05, 0.55), (sx * (w / 2 + 0.02) + 0.03, 0.05, 0.62), "metal_dark")
    # vertical ribs on the front
    for i in range(4):
        x = -w / 2 + 0.3 + i * (w - 0.6) / 3
        hard.bx((x - 0.025, d / 2 - 0.02, 0.22), (x + 0.025, d / 2 + 0.015, h - 0.1), "metal_green_worn")
    # casters
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.15), sy * (d / 2 - 0.15)
            run.bx((x - 0.05, y - 0.05, 0.13), (x + 0.05, y + 0.05, 0.18), "metal_dark")
            run.cyl(0.065, 0.045, (x, y, 0.065), "rubber", axis="X", segs=14)
    run.bx((-w / 2 + 0.3, -0.12, 0.6), (w / 2 - 0.3, 0.12, 0.62), "metal_dark")
    body.build()
    lid = k.empty("Lid", (0.0, -d / 2 - 0.02, h - 0.04))
    lm = k.obj("LidMesh", parent=lid)
    lp = lm.part(bevel=0.01, segments=2)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.005, sx * (w / 2)))
        lp.bx((x0, 0.0, 0.0), (x1, d + 0.06, 0.05), "plastic_black")
        lp.bx((x0 + 0.05, d + 0.01, 0.0), (x1 - 0.05, d + 0.07, 0.04), "plastic_black")
    for x in (-w / 2 + 0.1, -0.1, 0.1, w / 2 - 0.1):
        lp.cyl(0.02, 0.06, (x, 0.0, 0.0), "metal_dark", axis="X", segs=10)
    lm.build()
    k.empty("Inside", (0.0, 0.0, 0.5))


# ------------------------------------------------------------------------------------ ladder

def _ladder(k: Kit, p: dict) -> None:
    h = p["h"]
    rail_x = 0.23
    lad = k.obj("Rails")
    lp = lad.part(bevel=0.002)
    top = h + 0.9
    for sx in (-1, 1):
        x = sx * rail_x
        lp.bx((x - 0.03, -0.01, 0.0), (x + 0.03, 0.01, top - 0.25), "metal_dark")
        # gooseneck return to the landing at the top
        lp.rod((x, 0.0, top - 0.25), (x, -0.12, top), 0.017, "metal_dark", segs=10)
        lp.rod((x, -0.12, top), (x, -0.35, top - 0.15), 0.017, "metal_dark", segs=10)
        # wall standoffs every 1.2 m (the wall is behind, Blender -Y)
        z = 0.6
        while z < h - 0.3:
            lp.bx((x - 0.012, -0.16, z - 0.02), (x + 0.012, -0.01, z + 0.02), "metal_dark")
            lp.bx((x - 0.04, -0.17, z - 0.05), (x + 0.04, -0.16, z + 0.05), "metal_dark")
            z += 1.2
    n = int(h / 0.3)
    for i in range(n + 1):
        z = 0.15 + i * 0.3
        if z > top - 0.3:
            break
        lp.rod((-rail_x, 0.0, z), (rail_x, 0.0, z), 0.0125, "metal_dark", segs=8)
    lad.build()
    k.empty("Top", (0.0, -0.4, h))
    k.empty("Bottom", (0.0, 0.4, 0.0))


# --------------------------------------------------------------------------------------- van

def _van(k: Kit, p: dict) -> None:
    w, l, h = 2.0, 5.0, 2.2
    yr = l / 2           # rear (Blender +Y = Godot -Z)
    body = k.obj("Body")
    shell = body.part(bevel=0.04, segments=2)
    trim = body.part(bevel=0.006)
    glass = body.part(bevel=0.0)
    clear = 0.35
    # cargo box + cab with a sloped bonnet/windscreen (side profile y, z), extruded along X
    prof = [(-yr, clear + 0.1), (-yr, 0.95), (-yr + 0.55, 1.15), (-yr + 1.25, h - 0.05), (yr, h - 0.05), (yr, clear + 0.1)]
    shell.profile_x(prof, -w / 2 + 0.04, w / 2 - 0.04, "metal_white")
    # windscreen and side windows
    a = (-yr + 0.6, 1.17)
    b = (-yr + 1.2, h - 0.12)
    nx, nz = (b[1] - a[1]), -(b[0] - a[0])
    ln = math.hypot(nx, nz)
    nx, nz = nx / ln * 0.006, nz / ln * 0.006
    glass.profile_x([(a[0] - nx, a[1] - nz), (b[0] - nx, b[1] - nz), (b[0] + nx, b[1] + nz), (a[0] + nx, a[1] + nz)],
                    -w / 2 + 0.12, w / 2 - 0.12, "glass_tinted")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 - 0.045), sx * (w / 2 - 0.03)))
        glass.profile_x([(-yr + 1.0, 1.3), (-yr + 1.75, 1.3), (-yr + 1.75, h - 0.25), (-yr + 1.28, h - 0.25)], x0, x1, "glass_tinted")
        trim.bx((x0, -yr + 1.8, 1.05), (x1 + 0.005 * sx, -yr + 1.84, 1.95), "plastic_black")
        # side mirrors and door handles
        trim.bx((sx * (w / 2 + 0.12) - 0.06, -yr + 0.95, 1.3), (sx * (w / 2 + 0.12) + 0.06, -yr + 1.0, 1.5), "plastic_black")
        trim.bx((sx * (w / 2) - 0.02, -yr + 1.55, 1.15), (sx * (w / 2) + 0.02, -yr + 1.7, 1.18), "plastic_black")
        trim.bx((sx * (w / 2) - 0.02, -0.4, 1.0), (sx * (w / 2) + 0.02, -0.25, 1.03), "plastic_black")
        # sliding-door seam and rubbing strip
        trim.bx((x0 - 0.002 * sx, -0.6, clear + 0.25), (x1 + 0.004 * sx, 1.2, clear + 0.33), "plastic_black")
    # bumpers, grille, lights
    trim.bx((-w / 2, -yr - 0.08, clear), (w / 2, -yr + 0.15, clear + 0.25), "plastic_black")
    trim.bx((-w / 2, yr - 0.15, clear), (w / 2, yr + 0.08, clear + 0.22), "plastic_black")
    trim.bx((-0.55, -yr - 0.01, 0.65), (0.55, -yr + 0.02, 0.9), "plastic_black")
    for sx in (-1, 1):
        trim.bx((sx * 0.75 - 0.16, -yr - 0.005, 0.82), (sx * 0.75 + 0.16, -yr + 0.03, 0.95), "chrome")
        trim.bx((sx * 0.9 - 0.06, yr - 0.02, 1.0), (sx * 0.9 + 0.06, yr + 0.015, 1.5), "metal_red")
    # wheels and arches
    run = body.part(bevel=0.0)
    for sy in (-yr + 0.95, yr - 1.0):
        for sx in (-1, 1):
            run.cyl(0.36, 0.24, (sx * (w / 2 - 0.15), sy, 0.36), "rubber", axis="X", segs=24)
            run.cyl(0.22, 0.245, (sx * (w / 2 - 0.15), sy, 0.36), "steel", axis="X", segs=16)
    body.build()
    # rear doors (hinged at the outer edges, closed = flush with the rear)
    for name, sx in (("DoorL", -1), ("DoorR", 1)):
        piv = k.empty(name, (sx * (w / 2 - 0.04), yr, clear + 0.1))
        dm = k.obj(name + "Mesh", parent=piv)
        dp = dm.part(bevel=0.02, segments=2)
        x0, x1 = sorted((0.0, -sx * (w / 2 - 0.045)))
        dp.bx((x0, -0.04, 0.0), (x1, 0.02, h - 0.15 - clear - 0.1), "metal_white")
        g = dm.part(bevel=0.0)
        g.bx((x0 + 0.1, 0.02, 1.05), (x1 - 0.1, 0.026, 1.5), "glass_tinted")
        g.bx((x0 + 0.05 if sx > 0 else x1 - 0.12, 0.02, 0.6), (x0 + 0.12 if sx > 0 else x1 - 0.05, 0.05, 0.64), "plastic_black")
        dm.build()
    k.empty("DropAnchor", (0.0, yr + 0.7, 0.1))


# --------------------------------------------------------------------------------- loot bag

def _bag(k: Kit, p: dict) -> None:
    lx, ly, lz = p["size"]
    bag = k.obj("Bag")
    soft = bag.part(bevel=min(lz, ly) * 0.3, segments=3)
    soft.bx((-lx / 2, -ly / 2, 0.0), (lx / 2, ly / 2, lz), "bag_black")
    straps = bag.part(bevel=0.0)
    for sx in (-1, 1):
        x = sx * lx * 0.22
        r = ly * 0.33
        straps.tube([(x, -r * math.cos(math.pi * i / 8), lz - 0.01 + r * math.sin(math.pi * i / 8)) for i in range(9)],
                    0.012, "rubber", segs=6)
        straps.bx((x - 0.02, -ly / 2 - 0.003, 0.03), (x + 0.02, ly / 2 + 0.003, lz * 0.5), "rubber")
    straps.bx((-lx * 0.4, -0.006, lz - 0.002), (lx * 0.4, 0.006, lz + 0.006), "steel")
    bag.build()


# ------------------------------------------------------------------------------------ drill

def _drill(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    hard = body.part(bevel=0.006, segments=2)
    trim = body.part(bevel=0.0)
    # the bit tip is at the origin, pointing +Y (Godot -Z) into the lock; the drill sits behind it
    hard.bx((-0.09, -0.62, -0.1), (0.09, -0.3, 0.1), "metal_orange")
    hard.cyl(0.085, 0.22, (0.0, -0.22, 0.0), "metal_dark", axis="Y", segs=20)
    hard.bx((-0.06, -0.58, 0.1), (0.06, -0.34, 0.16), "metal_dark")
    trim.rod((0.0, -0.55, 0.16), (0.0, -0.37, 0.16), 0.018, "rubber", segs=10)
    for sx in (-1, 1):
        trim.rod((sx * 0.08, -0.5, -0.1), (sx * 0.25, -0.35, -0.42), 0.012, "steel", segs=8)
        trim.rod((sx * 0.08, -0.5, 0.1), (sx * 0.22, -0.4, 0.38), 0.012, "steel", segs=8)
    trim.bx((-0.05, -0.65, -0.03), (0.05, -0.62, 0.05), "emit_led_green")
    body.build()
    bit = k.obj("Bit", location=(0.0, -0.1, 0.0))
    bp = bit.part(bevel=0.0)
    bp.cyl(0.03, 0.04, (0.0, -0.01, 0.0), "steel", axis="Y", segs=14)
    bp.cyl(0.009, 0.09, (0.0, 0.055, 0.0), "chrome", axis="Y", segs=10)
    bit.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
