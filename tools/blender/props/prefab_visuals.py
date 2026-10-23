"""Visuals for the remaining gameplay prefabs (visual_slots.md / systems/prefabs/README.md).

Exact node names per prefab; no collision (prefabs own it). Blender +Y = Godot -Z (the front).

* safe (large workshop safe): `Body` (hollow carcass + shelf), `Door` (hinge pivot, -X edge),
  `DrillPoint` (-Z into the lock), `LootAnchor`.
* security_camera wall / ceiling: `Mount`, `Head` (pivot), `Lens` (-Z = view), `Led`.
* keycard_reader, keypad: `Panel`, `Led` (wall, back-centre pivot, mounted at 1.2 m).
* alarm_button, phone: no required nodes (`Panel`/`Button`, `Base`/`Handset`).
* camera_station: `Desk`, `Screens` (screen faces only), `Monitors`, `Seat` (operator faces the
  screens, Godot +Z).
* body_container (dumpster, GN crate / cart): `Body`, `Lid` (pivot on the back top edge), `Inside`.
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
    # D-063: the operator's sit_chair_watch / desk_work anims use a 0.74 m desk and a 0.47 m seat
    "prop_camera_station_bank": {"fn": "camera_station", "h": 0.74, "seat": 0.47, "cat": {"prefab": "camera_station", "kind": "camera_station"}},
    "prop_dumpster": {"fn": "dumpster", "cat": {"prefab": "body_container", "kind": "dumpster"}},
    # GN-C2 (Gallery Night BODY_HIDE indoors): an empty lidded packing crate (FR, FS, PL) and a janitor's lidded
    # linen / waste cart (J); same nodes as the dumpster.
    "prop_crate_hide": {"fn": "hide_box", "style": "crate", "size": (1.3, 0.8, 0.85),
                        "cat": {"prefab": "body_container", "kind": "crate"}},
    "prop_cart_hide": {"fn": "hide_box", "style": "cart", "size": (1.0, 0.65, 0.95),
                       "cat": {"prefab": "body_container", "kind": "cart"}},
    # D-111 SL refuse room: 0.94 m deep (lid inside the 1.0 m placeholder box against the back wall)
    "prop_dumpster_d094": {"fn": "dumpster", "d": 0.94, "cat": {"prefab": "body_container", "kind": "dumpster"}},
    "prop_ladder_fire_escape_h300": {"fn": "ladder", "h": 3.0, "cat": {"prefab": "ladder", "kind": "ladder"}},
    "prop_ladder_fire_escape_h420": {"fn": "ladder", "h": 4.2, "cat": {"prefab": "ladder", "kind": "ladder"}},
    "prop_ladder_wall_h400": {"fn": "ladder_wall", "h": 4.0, "cat": {"prefab": "ladder", "kind": "ladder"}},
    # D-111 (SL / DB): the fire-escape ladder at the map's climb height with straight stiles (1.0 m grab rails over
    # the landing, no gooseneck over a slab edge), stand-offs reaching the wall `gap` m behind the stiles (0 =
    # free-standing, the SL services riser hole). Top / Bottom match the ladder placeholder.
    **{f"prop_ladder_steel_h{h}_g{g:02d}": {"fn": "ladder", "h": h / 100.0, "gap": g / 100.0, "goose": False,
                                            "cat": {"prefab": "ladder", "kind": "ladder"}}
       for h, g in ((360, 0), (440, 0), (360, 25), (360, 40), (800, 40), (520, 22))},
    # OF-C2 (Ostrander Federal): the roof -> terrace caged ladder (3.6 m, stiles 0.35 m off the facade, a safety cage
    # from 2.2 m up past the parapet) and the lane fire-escape drop ladder (3.0 m, gooseneck onto the landing, no
    # stand-offs: it hangs in front of the landing edge, nothing behind it).
    "prop_ladder_steel_h360_g35_cage": {"fn": "ladder", "h": 3.6, "gap": 0.35, "goose": False, "cage": True,
                                        "cat": {"prefab": "ladder", "kind": "ladder"}},
    "prop_ladder_fire_escape_h300_g00": {"fn": "ladder", "h": 3.0, "gap": 0.0, "goose_back": 0.32,
                                         "cat": {"prefab": "ladder", "kind": "ladder"}},
    # OF-C2: the crew's rope ladder down the burn hole (4.0 m: its burn_height_m; hidden until the burn), its ropes
    # shackled to two anchor plates bolted into the cut slab face 0.04 m behind them (nothing over the edge: the
    # lid drill and the hall floor stay clear).
    "prop_ladder_rope_h400": {"fn": "ladder_rope", "h": 4.0, "edge": 0.04,
                              "cat": {"prefab": "ladder", "kind": "ladder"}},
    # OF-C2: the burn-hole bag hoist (bag_lift visual): a 1.1 x 0.7 m cradle for the 1.0 x 0.75 car_size_m in the
    # 1.19 x 0.78 m rig shaft (Ostrander Federal HOIST_RIG).
    "prop_hoist_cradle_w110": {"fn": "hoist_cradle", "w": 1.1, "d": 0.7, "h": 1.0,
                               "cat": {"prefab": "bag_lift", "kind": "lift_car", "surface": "metal"}},
    "prop_padlock_brass": {"fn": "padlock", "cat": {"prefab": "padlock", "kind": "padlock"}},
    "prop_customs_seal": {"fn": "customs_seal", "cat": {"prefab": "padlock", "kind": "padlock"}},
    # hack_terminal prefab visual (Dockside Burn E1 `lift_dead`): the goods-lift breaker cabinet, wall-hung
    "prop_lift_breaker": {"fn": "lift_breaker", "cat": {"prefab": "hack_terminal", "kind": "breaker_panel", "mount": "wall"}},
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
    w, d, h = 1.6, 0.8, p.get("h", 0.75)
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
    k.empty("Seat", (0.0, 0.75, p.get("seat", 0.45)), rotation=(0.0, 0.0, math.pi))


# ---------------------------------------------------------------------------------- dumpster

def _dumpster(k: Kit, p: dict) -> None:
    w, d, h = 1.8, p.get("d", 1.0), 1.1
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


# ------------------------------------------------------------------------- hide box (crate / cart)

def _hide_box(k: Kit, p: dict) -> None:
    """Lidded body container: `Body`, `Lid` (pivot on the back top edge), `LidMesh`, `Inside`.

    crate: pine boards on a batten frame, a stencilled label on the front; cart: a grey plastic tub on casters
    with a push handle at the back.
    """
    w, d, h = p["size"]
    crate = p["style"] == "crate"
    shell = "wood_pine" if crate else "plastic_grey"
    lid_key = "wood_pine" if crate else "plastic_black"
    t = 0.022 if crate else 0.03
    z0 = 0.0 if crate else 0.16
    body = k.obj("Body")
    hard = body.part(bevel=0.003 if crate else 0.01, segments=1)
    run = body.part(bevel=0.0)
    hard.bx((-w / 2 + t, -d / 2 + t, z0), (w / 2 - t, d / 2 - t, z0 + t), shell)
    for sy in (-1, 1):
        y0, y1 = sorted((sy * d / 2, sy * (d / 2 - t)))
        hard.bx((-w / 2, y0, z0), (w / 2, y1, h - 0.03), shell)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - t)))
        hard.bx((x0, -d / 2 + t, z0), (x1, d / 2 - t, h - 0.03), shell)
    if crate:
        # battens: a band round the foot and the rim, corner posts
        for zb in (0.0, h - 0.11):
            for sy in (-1, 1):
                y0, y1 = sorted((sy * (d / 2 + 0.018), sy * d / 2))
                run.bx((-w / 2, y0, zb), (w / 2, y1, zb + 0.08), "wood_pine")
            for sx in (-1, 1):
                x0, x1 = sorted((sx * (w / 2 + 0.018), sx * w / 2))
                run.bx((x0, -d / 2, zb), (x1, d / 2, zb + 0.08), "wood_pine")
        for sx in (-1, 1):
            for sy in (-1, 1):
                x0, x1 = sorted((sx * (w / 2 + 0.018), sx * (w / 2 - 0.06)))
                y0, y1 = sorted((sy * (d / 2 + 0.018), sy * (d / 2 - 0.06)))
                run.bx((x0, y0, 0.0), (x1, y1, h - 0.03), "wood_pine")
        run.bx((-0.2, d / 2 + 0.018, h * 0.45), (0.2, d / 2 + 0.02, h * 0.45 + 0.14), "paper")
    else:
        for sx in (-1, 1):
            for sy in (-1, 1):
                x, y = sx * (w / 2 - 0.1), sy * (d / 2 - 0.1)
                run.bx((x - 0.04, y - 0.04, 0.1), (x + 0.04, y + 0.04, z0), "metal_dark")
                run.cyl(0.05, 0.035, (x, y, 0.05), "rubber", axis="X", segs=14)
        for sx in (-1, 1):
            hx = sx * (w / 2 - 0.08)
            run.rod((hx, -d / 2 - 0.01, h - 0.2), (hx, -d / 2 - 0.1, h + 0.05), 0.012, "steel", segs=8)
        run.rod((-(w / 2 - 0.08), -d / 2 - 0.1, h + 0.05), (w / 2 - 0.08, -d / 2 - 0.1, h + 0.05), 0.014, "steel",
                segs=8)
    body.build()
    lid = k.empty("Lid", (0.0, -d / 2, h - 0.03))
    lm = k.obj("LidMesh", parent=lid)
    lp = lm.part(bevel=0.003 if crate else 0.008, segments=1)
    lp.bx((-w / 2, 0.0, 0.0), (w / 2, d, 0.03), lid_key)
    if crate:
        for x in (-w / 2 + 0.08, 0.0, w / 2 - 0.08):
            lp.bx((x - 0.04, 0.02, 0.03), (x + 0.04, d - 0.02, 0.05), "wood_pine")
    else:
        lp.bx((-0.15, d - 0.02, -0.04), (0.15, d + 0.02, 0.03), "plastic_black")
    lm.build()
    k.empty("Inside", (0.0, 0.0, z0 + 0.3))


# ------------------------------------------------------------------------------------ ladder

def _ladder(k: Kit, p: dict) -> None:
    h = p["h"]
    gap = p.get("gap", 0.17)  # wall distance behind the stiles (Blender -Y); 0 = no stand-offs
    rail_x = 0.23
    lad = k.obj("Rails")
    lp = lad.part(bevel=0.002)
    top = h + 0.9
    for sx in (-1, 1):
        x = sx * rail_x
        if not p.get("goose", True):
            lp.bx((x - 0.03, -0.01, 0.0), (x + 0.03, 0.01, h + 1.0), "metal_dark")
        else:
            lp.bx((x - 0.03, -0.01, 0.0), (x + 0.03, 0.01, top - 0.25), "metal_dark")
            # gooseneck return to the landing at the top
            lp.rod((x, 0.0, top - 0.25), (x, -0.12, top), 0.017, "metal_dark", segs=10)
            lp.rod((x, -0.12, top), (x, -p.get("goose_back", 0.35), top - 0.15), 0.017, "metal_dark", segs=10)
        # wall standoffs every 1.2 m (the wall is behind, Blender -Y)
        z = 0.6
        while gap > 0.0 and z < h - 0.3:
            lp.bx((x - 0.012, -(gap - 0.01), z - 0.02), (x + 0.012, -0.01, z + 0.02), "metal_dark")
            lp.bx((x - 0.04, -gap, z - 0.05), (x + 0.04, -(gap - 0.01), z + 0.05), "metal_dark")
            z += 1.2
    n = int(h / 0.3)
    for i in range(n + 1):
        z = 0.15 + i * 0.3
        if z > top - 0.3:
            break
        lp.rod((-rail_x, 0.0, z), (rail_x, 0.0, z), 0.0125, "metal_dark", segs=8)
    if p.get("cage", False):
        _ladder_cage(lad.part(bevel=0.0), rail_x, h + 0.95)
    lad.build()
    k.empty("Top", (0.0, -0.4, h))
    k.empty("Bottom", (0.0, 0.4, 0.0))


def _ladder_rope(k: Kit, p: dict) -> None:
    """Rescue rope ladder hung down a floor opening: two braided rope sides from the floor of the lower level to
    eye shackles on two steel anchor plates bolted into the opening's cut face (``edge`` m behind the ropes, Blender
    -Y, 0.06-0.2 m below the upper floor), aluminium rungs every 0.3 m held off the face by spacer blocks. Nothing
    rises over the upper floor (the climber steps off onto it at Top). Top / Bottom as the steel ladders."""
    h, edge = p["h"], p["edge"]
    rope_x = 0.2
    lad = k.obj("Rails")
    rp = lad.part(bevel=0.0)
    for sx in (-1, 1):
        x = sx * rope_x
        rp.rod((x, 0.0, 0.012), (x, 0.0, h - 0.13), 0.011, "rope_tan", segs=8)
        rp.cyl(0.016, 0.03, (x, 0.0, 0.015), "rope_tan", segs=8)                       # whipped rope end
    z = 0.25
    while z < h - 0.3:
        rp.rod((-rope_x - 0.02, 0.0, z), (rope_x + 0.02, 0.0, z), 0.014, "steel", segs=10)
        for sx in (-1, 1):
            rp.cbox((sx * rope_x, 0.025, z), (0.03, 0.03, 0.05), "metal_dark")
        z += 0.3
    an = lad.part(bevel=0.002)
    for sx in (-1, 1):
        x = sx * rope_x
        an.bx((x - 0.05, -edge, h - 0.2), (x + 0.05, -edge + 0.012, h - 0.06), "metal_dark")   # anchor plate
        for bz in (h - 0.18, h - 0.08):
            an.cyl(0.009, 0.008, (x, -edge + 0.016, bz), "steel", axis="Y", segs=8)              # anchor bolts
        an.torus(0.02, 0.005, (x, -0.014, h - 0.115), "steel", segs=12, rsegs=4, axis="X")      # eye shackle
    lad.build()
    k.empty("Top", (0.0, -0.4, h))
    k.empty("Bottom", (0.0, 0.4, 0.0))


def _ladder_cage(cp, rail_x: float, z_top: float) -> None:
    """Safety cage on the climb side (Blender +Y): flat-bar hoops from 2.2 m every 0.75 m up to ``z_top``, each
    springing off both stiles round a 0.36 m radius (0.71 m deep, EN ISO 14122-4 proportions), tied by five
    vertical straps."""
    r, cy = 0.36, 0.35
    arc = [math.radians(180.0 - 15.0 * i) for i in range(13)]

    def hoop(z: float) -> list:
        pts = [(-rail_x, 0.0, z), (-r, 0.16, z)]
        pts += [(r * math.cos(a), cy + r * math.sin(a), z) for a in arc]
        return pts + [(r, 0.16, z), (rail_x, 0.0, z)]

    zs = []
    z = 2.2
    while z <= z_top + 1e-6:
        zs.append(z)
        z += 0.75
    for z in zs:
        cp.tube(hoop(z), 0.008, "metal_dark", segs=6)
    for a in (150.0, 120.0, 90.0, 60.0, 30.0):
        x, y = r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))
        cp.rod((x, y, zs[0] - 0.03), (x, y, zs[-1] + 0.03), 0.007, "metal_dark", segs=6)


def _ladder_wall(k: Kit, p: dict) -> None:
    """Fixed steel pit ladder bolted to a wall (wall behind, Blender -Y at y 0): straight stiles that
    run 1.0 m past the landing as grab rails (no gooseneck over the landing, so nothing overhangs a
    ledge or a gate's swing), rungs every 0.3 m and wall brackets every 1.2 m."""
    h = p["h"]
    rail_x = 0.2
    off = 0.16  # stile centre in front of the wall
    lad = k.obj("Rails")
    lp = lad.part(bevel=0.002)
    top = h + 1.0
    for sx in (-1, 1):
        x = sx * rail_x
        lp.bx((x - 0.03, off - 0.01, 0.0), (x + 0.03, off + 0.01, top), "metal_dark")
        z = 0.6
        while z < top - 0.2:
            lp.bx((x - 0.012, 0.012, z - 0.02), (x + 0.012, off - 0.01, z + 0.02), "metal_dark")
            lp.bx((x - 0.04, 0.0, z - 0.05), (x + 0.04, 0.012, z + 0.05), "metal_dark")
            z += 1.2
    z = 0.3
    while z < h + 0.01:
        lp.rod((-rail_x, off, z), (rail_x, off, z), 0.0125, "metal_dark", segs=8)
        z += 0.3
    lad.build()
    k.empty("Top", (0.0, -0.4, h))
    k.empty("Bottom", (0.0, 0.5, 0.0))


def _padlock(k: Kit, p: dict) -> None:
    """Brass padlock (padlock prefab, QC-37): `Body` = brass case, bottom at the pivot, a keyway on both
    faces; `Shackle` = the steel hoop above it (the prefab hides it once the lock is cut or picked)."""
    w, h, d = 0.05, 0.055, 0.022
    b = k.obj("Body")
    a = b.part(bevel=0.004, segments=2)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h), "brass")
    kp = b.part(bevel=0.0)
    kp.cyl(0.004, 0.002, (0.0, d / 2 + 0.001, h * 0.35), "metal_dark", axis="Y", segs=10)
    kp.cyl(0.004, 0.002, (0.0, -d / 2 - 0.001, h * 0.35), "metal_dark", axis="Y", segs=10)
    b.build()
    sh = k.obj("Shackle")
    s2 = sh.part(bevel=0.0)
    r = 0.016
    for sx in (-1, 1):
        s2.rod((sx * r, 0.0, h), (sx * r, 0.0, h + 0.014), 0.004, "chrome", segs=8)
    n = 10
    pts = [(math.cos(math.pi * i / n) * r, 0.0, h + 0.014 + math.sin(math.pi * i / n) * r) for i in range(n + 1)]
    s2.tube(pts, 0.004, "chrome", segs=8)
    sh.build()


def _customs_seal(k: Kit, p: dict) -> None:
    """Customs bolt seal on a container hasp (padlock prefab visual, D-115 DB-9: the non-weapons containers carry
    only this; the Co-op's brass padlock marks the weapons ones). Bottom at the pivot (padlock contract): `Body` =
    the yellow numbered tag (0-4.5 cm) under the moulded red seal head, `Shackle` = the steel bolt through the hasp
    above it (hidden once cut)."""
    b = k.obj("Body")
    tag = b.part(bevel=0.0)
    tag.bx((-0.009, -0.0015, 0.0), (0.009, 0.0015, 0.045), "metal_yellow")
    tag.bx((-0.007, -0.0018, 0.01), (0.007, 0.0018, 0.017), "metal_dark")   # printed number strip
    a = b.part(bevel=0.003, segments=2)
    a.cyl(0.012, 0.032, (0.0, 0.0, 0.061), "metal_red", segs=14)
    a.cyl(0.015, 0.006, (0.0, 0.0, 0.078), "metal_red", segs=14)
    b.build()
    sh = k.obj("Shackle")
    s2 = sh.part(bevel=0.0)
    s2.rod((0.0, 0.0, 0.081), (0.0, 0.0, 0.155), 0.004, "steel", segs=8)
    s2.cyl(0.007, 0.006, (0.0, 0.0, 0.157), "steel", segs=10)
    sh.build()


# --------------------------------------------------------------------------------------- van

def _van(k: Kit, p: dict) -> None:
    """Panel van (secure_zone): shaped cab (sloped bonnet, raked screen), boxy cargo body with
    rounded edges, wheel arches, side rubbing strip and sliding-door seams, grille, lamps and
    bumpers; two rear doors with windows and handles on hinge pivots. The rear faces Blender +Y."""
    w, l, h = 2.0, 5.0, 2.2
    yr = l / 2           # rear (Blender +Y = Godot -Z)
    clear = 0.35
    body = k.obj("Body")
    shell = body.part(bevel=0.05, segments=3)
    trim = body.part(bevel=0.004)
    glass = body.part(bevel=0.0)
    run = body.part(bevel=0.0)
    prof = [(-yr + 0.02, clear + 0.1), (-yr, 0.62), (-yr + 0.05, 0.98), (-yr + 0.6, 1.12), (-yr + 1.3, h - 0.08),
            (-yr + 1.45, h - 0.04), (yr - 0.03, h - 0.04), (yr, h - 0.1), (yr, clear + 0.12), (yr - 0.2, clear + 0.08)]
    shell.profile_x(prof, -w / 2, w / 2, "metal_white")
    # windscreen and cab side windows, proud of the shell (no coplanar faces)
    a, b = (-yr + 0.62, 1.15), (-yr + 1.26, h - 0.14)
    ln = math.hypot(b[0] - a[0], b[1] - a[1])
    nx, nz = -(b[1] - a[1]) / ln, (b[0] - a[0]) / ln
    glass.profile_x([(a[0] + nx * 0.004, a[1] + nz * 0.004), (b[0] + nx * 0.004, b[1] + nz * 0.004),
                     (b[0] + nx * 0.014, b[1] + nz * 0.014), (a[0] + nx * 0.014, a[1] + nz * 0.014)],
                    -w / 2 + 0.12, w / 2 - 0.12, "glass_tinted")
    for sx in (-1, 1):
        g0, g1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.012)))
        glass.profile_x([(-yr + 1.0, 1.3), (-yr + 1.7, 1.3), (-yr + 1.7, h - 0.3), (-yr + 1.3, h - 0.3)], g0, g1, "glass_tinted")
        t0, t1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.03)))
        trim.bx((t0, -yr + 0.4, clear + 0.38), (t1, yr - 0.25, clear + 0.48), "plastic_black")      # rubbing strip
        s0, s1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.009)))
        for yy in (-yr + 1.75, -0.35, 1.05):                                                        # door seams
            trim.bx((s0, yy, clear + 0.15), (s1, yy + 0.012, h - 0.12), "plastic_black")
        trim.bx((s0, -yr + 1.75, h - 0.33), (s1, 1.06, h - 0.32), "plastic_black")                  # slide rail
        h0, h1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.02)))
        trim.bx((h0, -yr + 1.5, 1.12), (h1, -yr + 1.64, 1.15), "plastic_black")                     # handles
        trim.bx((h0, -0.55, 1.05), (h1, -0.41, 1.08), "plastic_black")
        m0, m1 = sorted((sx * (w / 2 + 0.03), sx * (w / 2 + 0.2)))
        trim.bx((m0, -yr + 1.0, 1.3), (m1, -yr + 1.06, 1.52), "plastic_black")                      # mirror
        for wy in (-yr + 0.95, yr - 1.0):
            trim.tube([(sx * (w / 2 + 0.006), wy - 0.43 * math.cos(math.pi * i / 10), 0.38 + 0.43 * math.sin(math.pi * i / 10))
                       for i in range(11)], 0.035, "plastic_black", segs=6)
            run.cyl(0.36, 0.24, (sx * (w / 2 - 0.15), wy, 0.36), "rubber", axis="X", segs=28)
            run.cyl(0.22, 0.245, (sx * (w / 2 - 0.15), wy, 0.36), "steel", axis="X", segs=20)
            run.cyl(0.08, 0.25, (sx * (w / 2 - 0.15), wy, 0.36), "chrome", axis="X", segs=12)
        # tail lights wrap the rear corners on the sides (clear of the rear doors)
        l0, l1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.014)))
        trim.bx((l0, yr - 0.14, 0.95), (l1, yr - 0.02, 1.55), "metal_red")
    # front: grille, headlamps, bumper; rear bumper with step; plates
    trim.bx((-0.6, -yr - 0.012, 0.66), (0.6, -yr + 0.03, 0.9), "plastic_black")
    for gz in (0.71, 0.77, 0.83):
        trim.bx((-0.56, -yr - 0.02, gz), (0.56, -yr - 0.012, gz + 0.025), "chrome")
    for sx in (-1, 1):
        trim.bx((sx * 0.78 - 0.17, -yr + 0.02, 0.86), (sx * 0.78 + 0.17, -yr + 0.08, 0.98), "glass_tinted")
        trim.bx((sx * 0.78 - 0.15, -yr + 0.012, 0.88), (sx * 0.78 + 0.15, -yr + 0.03, 0.96), "chrome")
    trim.bx((-w / 2 + 0.02, -yr - 0.1, clear), (w / 2 - 0.02, -yr + 0.15, clear + 0.24), "plastic_black")
    trim.bx((-w / 2 + 0.02, yr - 0.15, clear), (w / 2 - 0.02, yr + 0.1, clear + 0.2), "plastic_black")
    trim.bx((-0.35, yr + 0.1, clear + 0.06), (0.35, yr + 0.22, clear + 0.09), "steel")
    trim.bx((-0.25, -yr - 0.12, clear + 0.06), (0.25, -yr - 0.1, clear + 0.17), "plastic_white")
    body.build()
    # rear doors (hinged at the outer edges, closed = flush with the rear)
    # `doors_open_deg` (the safehouse's crew van, rear doors open): each leaf turned out about its hinge
    open_r = math.radians(float(p.get("doors_open_deg", 0.0)))
    for name, sx in (("DoorL", -1), ("DoorR", 1)):
        piv = k.empty(name, (sx * (w / 2 - 0.04), yr, clear + 0.1), (0.0, 0.0, -sx * open_r))
        dm = k.obj(name + "Mesh", parent=piv)
        dp = dm.part(bevel=0.02, segments=2)
        dt = dm.part(bevel=0.003)
        x0, x1 = sorted((0.0, -sx * (w / 2 - 0.045)))
        dh = h - 0.15 - clear - 0.1
        dp.bx((x0, -0.035, 0.0), (x1, 0.025, dh), "metal_white")
        g = dm.part(bevel=0.0)
        g.bx((x0 + 0.1, 0.03, dh - 0.62), (x1 - 0.1, 0.036, dh - 0.16), "glass_tinted")
        dt.bx((x0 + 0.08, 0.025, dh - 0.66), (x1 - 0.08, 0.03, dh - 0.12), "plastic_black")
        hx0, hx1 = (x1 - 0.14, x1 - 0.05) if sx < 0 else (x0 + 0.05, x0 + 0.14)
        dt.bx((hx0, 0.025, 0.6), (hx1, 0.06, 0.64), "plastic_black")
        hinge_x = -0.012 if sx < 0 else 0.012
        for hz in (0.25, dh - 0.3):
            dt.cyl(0.018, 0.12, (hinge_x, 0.03, hz), "steel", segs=10)
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
    """Magnetic-base safe drill rig: the bit tip is the origin and points +Y (Godot -Z) into the
    lock; behind it the chuck, an orange gearbox, a long motor with cooling rings, a carry handle,
    a status panel and two clamp legs with rubber pads resting on the door face (y = 0)."""
    body = k.obj("Body")
    hard = body.part(bevel=0.006, segments=2)
    trim = body.part(bevel=0.0)
    hard.bx((-0.1, -0.36, -0.12), (0.1, -0.16, 0.13), "metal_orange")
    hard.bx((-0.085, -0.36, 0.13), (0.085, -0.2, 0.17), "metal_dark")
    trim.cyl(0.08, 0.3, (0.0, -0.51, 0.0), "metal_dark", axis="Y", segs=24)
    for i in range(6):
        trim.torus(0.08, 0.006, (0.0, -0.4 - i * 0.045, 0.0), "steel", segs=24, rsegs=4, axis="Y")
    trim.cyl(0.06, 0.03, (0.0, -0.675, 0.0), "metal_orange", axis="Y", segs=20)
    trim.tube([(0.0, -0.33, 0.17), (0.0, -0.33, 0.26), (0.0, -0.55, 0.26), (0.0, -0.6, 0.09)], 0.014, "rubber", segs=8)
    trim.bx((0.1, -0.33, -0.05), (0.104, -0.2, 0.08), "plastic_black")
    trim.bx((0.104, -0.31, 0.03), (0.106, -0.22, 0.06), "emit_led_green")
    trim.cyl(0.035, 0.05, (0.0, -0.135, 0.0), "steel", axis="Y", segs=18)
    for sx in (-1, 1):
        trim.rod((sx * 0.1, -0.26, -0.08), (sx * 0.24, -0.06, -0.24), 0.014, "steel", segs=8)
        trim.rod((sx * 0.1, -0.26, 0.08), (sx * 0.24, -0.06, 0.24), 0.014, "steel", segs=8)
        for sz in (-1, 1):
            trim.cyl(0.045, 0.03, (sx * 0.24, -0.035, sz * 0.24), "rubber", axis="Y", segs=16)
    trim.tube([(0.0, -0.66, -0.05), (0.05, -0.7, -0.2), (0.15, -0.68, -0.32)], 0.008, "rubber", segs=6)
    body.build()
    bit = k.obj("Bit", location=(0.0, -0.1, 0.0))
    bp = bit.part(bevel=0.0)
    bp.cyl(0.022, 0.03, (0.0, -0.005, 0.0), "steel", axis="Y", segs=14)
    bp.cyl(0.009, 0.09, (0.0, 0.055, 0.0), "chrome", axis="Y", segs=10)
    bit.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)


def _hoist_cradle(k: Kit, p: dict) -> None:
    """Crew-rigged bag hoist cradle (bag_lift visual, OF-C2 burn-hole hoist): a ``w`` x ``d`` chequer-plate tray (top
    12 mm over the car origin) in an angle frame, 0.12 m kick rails on three sides, the -Y side (Godot +Z) lipped
    only (bags come in over the shaft sill), four corner posts to ``h`` and four chain slings to a master ring
    and hook block over the centre. `Car` carries it; `DoorL` / `DoorR` are markers (no gates: the prefab's door slide
    moves nothing visible)."""
    w, d, h = p["w"], p["d"], p["h"]
    hw, hd = w / 2, d / 2
    car = k.obj("Car")
    tray = car.part(bevel=0.002)
    tray.bx((-hw, -hd, 0.0), (hw, hd, 0.012), "metal_grey")
    tread = car.part(bevel=0.0)
    for i in range(6):
        for j in range(4):
            cx = -hw + (i + 0.5) * w / 6
            cy = -hd + (j + 0.5) * d / 4
            ang = 0.25 if (i + j) % 2 == 0 else -0.25
            dx, dy = 0.06 * math.cos(ang * math.pi), 0.06 * math.sin(ang * math.pi)
            tread.rod((cx - dx, cy - dy, 0.014), (cx + dx, cy + dy, 0.014), 0.004, "metal_grey", segs=4, square=True)
    fr = car.part(bevel=0.002)
    # perimeter angle (the -Y edge a low lip), kick rails W / E / +Y
    fr.bx((-hw, -hd, 0.012), (hw, -hd + 0.03, 0.05), "metal_yellow")
    fr.bx((-hw, hd - 0.03, 0.012), (hw, hd, 0.12), "metal_yellow")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw - 0.03)))
        fr.bx((x0, -hd + 0.03, 0.012), (x1, hd - 0.03, 0.12), "metal_yellow")
        for sy in (-1, 1):
            y0, y1 = sorted((sy * hd, sy * (hd - 0.04)))
            fr.bx((x0 if sx < 0 else x1 - 0.04, y0, 0.012), (x0 + 0.04 if sx < 0 else x1, y1, h), "metal_dark")
        # top rail along each long side
        fr.bx((x0 if sx < 0 else x1 - 0.04, -hd, h - 0.04), (x0 + 0.04 if sx < 0 else x1, hd, h), "metal_dark")
    trim = car.part(bevel=0.0)
    ring = (0.0, 0.0, h + 0.45)
    for sx in (-1, 1):
        for sy in (-1, 1):
            corner = (sx * (hw - 0.02), sy * (hd - 0.02), h)
            trim.cyl(0.012, 0.03, (corner[0], corner[1], h + 0.015), "steel", segs=8)
            trim.rod(corner, (ring[0] + sx * 0.03, ring[1] + sy * 0.03, ring[2] - 0.04), 0.006, "steel_galv", segs=6)
    trim.torus(0.05, 0.009, ring, "steel", segs=16, rsegs=4, axis="Y")
    trim.bx((-0.04, -0.03, ring[2] + 0.04), (0.04, 0.03, ring[2] + 0.16), "metal_yellow")      # hook block
    trim.cyl(0.008, 0.25, (0.0, 0.0, ring[2] + 0.29), "steel_galv", segs=6)                  # hoist wire
    car_obj = car.build()
    k.empty("DoorL", (-hw / 2, hd, 0.0), parent=car_obj)
    k.empty("DoorR", (hw / 2, hd, 0.0), parent=car_obj)


def _lift_breaker(k: Kit, p: dict) -> None:
    """Goods-lift breaker cabinet: pivot back-centre of the cabinet (hung at 1.45 m, like prop_breaker_panel).
    `Panel` = cabinet, reset lever, labels; `Screen` = the status window the prefab tints with progress."""
    w, d, z0, z1 = 0.6, 0.16, -0.45, 0.45
    pn = k.obj("Panel")
    a = pn.part(bevel=0.005, segments=2)
    a.bx((-w / 2, 0.0, z0), (w / 2, d, z1), "metal_grey")
    a.bx((-w / 2 + 0.02, d, z0 + 0.02), (w / 2 - 0.02, d + 0.008, z1 - 0.02), "metal_grey")
    a.bx((-0.07, 0.0, z1), (0.07, 0.08, z1 + 0.6), "metal_dark")  # conduit up to the ceiling run
    t = pn.part(bevel=0.0)
    t.bx((-0.12, d + 0.008, z1 - 0.12), (0.12, d + 0.01, z1 - 0.06), "metal_yellow")  # "LIFT" warning plate
    t.bx((-0.24, d + 0.008, z0 + 0.06), (-0.12, d + 0.01, z0 + 0.14), "paper")
    lv = pn.part(bevel=0.004, segments=2)
    lv.bx((w / 2 - 0.13, d + 0.008, z0 + 0.32), (w / 2 - 0.05, d + 0.05, z0 + 0.58), "plastic_black")  # lever boss
    lv.rod((w / 2 - 0.09, d + 0.05, z0 + 0.45), (w / 2 - 0.09, d + 0.2, z0 + 0.62), 0.014, "steel", segs=8)
    lv.cyl(0.024, 0.07, (w / 2 - 0.09, d + 0.2, z0 + 0.62), "metal_red", axis="Y", segs=12)
    pn.build()
    sc = k.obj("Screen")
    c = sc.part(bevel=0.0)
    c.bx((-0.22, d + 0.008, z0 + 0.38), (0.08, d + 0.012, z0 + 0.56), "emit_screen")
    sc.build()

