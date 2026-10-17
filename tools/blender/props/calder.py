"""Shadow Ledger G2 dressing (SL-1; docs/design/heists/shadow_ledger.md room list and palette: graphite #2E3136 honed
stone, carpet and BOH paint; glass teal #5D8C8F; cold-white LED accents; walnut desks and leather).

Floor props: bottom-centre pivot, front = Blender +Y (Godot -Z); wall props: back at y 0; ceiling props: top at z 0.
The map-built pieces (shadow_ledger_layout.gd PROPS: desks, tables, credenzas, shelving, the server racks, beds,
wardrobes, the lounge bar, the roof plant ...) are modelled to their layout box (w = the box along the model's X,
d = along its Y, h) less a few millimetres, so the visual sits inside the unchanged gameplay collider; the generator
instances them over that collider with a yaw (shadow_ledger_dressing.gd PROP_ART).

* L41 offices: credenzas, bookcases, conference / boardroom / dining / meeting tables, the reception desk (1.05 m
  transaction ledge), bench workstations, an MFP printer, a copier, compact archive shelving, library stacks.
* Back of house: the ledger rack pair, a CRAC unit, a UPS tower, spares shelving, the security room's key cabinet,
  counter and lockers, switchboards, a janitor sink, kitchen / pantry counters, fridges, vanities, linen shelving,
  a cleaner's cart, the L40 freight dolly, sign-in lectern and recycling cage.
* Partners' floor: the lounge bar (backlit teal glass), leather sofas, a coffee table, a baby grand, sculpture
  plinths, club armchairs, a bed with nightstands, wardrobes, a sideboard, a wine fridge, wine racks, a humidor.
* Terrace and roof: planters, loungers, an outdoor kitchen, slim patio heaters; the roof AHU, chiller, water tank,
  lift motors, the BMU, its cradle garage and the two line anchor frames.
* Fixtures: a 6500 K linear LED (exec coves), a brass picture light (3000 K), a terrace LED bollard.
"""

import math

from _pb import Kit, bar_handle, knob, legs4, panel_door

TRI_BUDGET = 16000
COLD = "#E6EEFF"
WARM = "#FFC58F"
_G = "calder"
# Every SL prop is pin_only (KitPlacer picks it only where a kit pins it: other maps' kits keep their layouts).
BASE_VARIANTS = {
    # L40 service level
    "prop_freight_dolly": {"fn": "dolly", "w": 1.0, "d": 0.7, "h": 1.0, "cat": {"kind": "cart", "place": "wall", "group": _G}},
    "prop_lectern_signin": {"fn": "lectern", "w": 0.5, "d": 0.4, "h": 1.1,
                            "cat": {"kind": "lectern", "place": "wall", "support": True, "group": _G}},
    "prop_recycling_cage": {"fn": "recycling_cage", "w": 1.2, "d": 0.9, "h": 1.6, "cat": {"kind": "cage", "place": "wall",
                                                                                         "group": _G}},
    # offices
    "prop_credenza_w200": {"fn": "cabinet", "w": 2.0, "d": 0.5, "h": 0.8, "style": "walnut",
                           "cat": {"kind": "credenza", "place": "wall", "support": True, "group": _G}},
    "prop_credenza_w200_d40": {"fn": "cabinet", "w": 2.0, "d": 0.4, "h": 0.8, "style": "walnut",
                               "cat": {"kind": "credenza", "place": "wall", "support": True, "group": _G}},
    "prop_sideboard_w240": {"fn": "cabinet", "w": 2.4, "d": 0.45, "h": 0.9, "style": "stone",
                            "cat": {"kind": "credenza", "place": "wall", "support": True, "group": _G}},
    "prop_bookcase_w160": {"fn": "bookcase", "w": 1.6, "d": 0.4, "h": 2.0, "seed": 3,
                           "cat": {"kind": "bookshelf", "place": "wall", "group": _G}},
    "prop_bookcase_w240": {"fn": "bookcase", "w": 2.4, "d": 0.5, "h": 2.2, "seed": 7,
                           "cat": {"kind": "bookshelf", "place": "wall", "group": _G}},
    "prop_table_conference_l360": {"fn": "table", "w": 3.6, "d": 1.4, "h": 0.75, "style": "conference",
                                   "cat": {"kind": "table", "place": "center", "support": True, "group": _G}},
    "prop_table_boardroom_l480": {"fn": "table", "w": 4.8, "d": 1.4, "h": 0.75, "style": "boardroom",
                                  "cat": {"kind": "table", "place": "center", "support": True, "group": _G}},
    "prop_table_dining_l360": {"fn": "table", "w": 3.6, "d": 1.2, "h": 0.75, "style": "dining",
                               "cat": {"kind": "table", "place": "center", "support": True, "group": _G}},
    "prop_table_break_l160": {"fn": "table", "w": 1.6, "d": 1.0, "h": 0.75, "style": "break",
                              "cat": {"kind": "table", "place": "center", "support": True, "group": _G}},
    "prop_table_round_d120": {"fn": "table_round", "r": 0.6, "h": 0.75,
                              "cat": {"kind": "table", "place": "center", "support": True, "group": _G}},
    "prop_reception_desk_exec": {"fn": "reception", "cat": {"kind": "counter_transaction", "place": "wall", "support": True,
                                                            "top": 0.72, "group": _G}},
    "prop_printer_mfp": {"fn": "printer", "w": 0.6, "d": 0.5, "h": 1.0, "cat": {"kind": "printer", "place": "wall", "group": _G}},
    "prop_copier": {"fn": "printer", "w": 1.0, "d": 0.7, "h": 1.1, "big": True, "cat": {"kind": "copier", "place": "wall",
                                                                                      "group": _G}},
    "prop_workstation_pod": {"fn": "pod", "cat": {"kind": "desk", "place": "center", "support": True, "group": _G}},
    "prop_compact_shelving_w400": {"fn": "compact", "cat": {"kind": "shelving", "place": "none", "group": _G}},
    "prop_library_stack_w400": {"fn": "library_stack", "cat": {"kind": "bookshelf", "place": "none", "group": _G}},
    # back of house
    "prop_mop_sink_w90": {"fn": "mop_sink", "cat": {"kind": "mop_sink", "place": "wall", "group": _G}},
    "prop_server_rack_pair": {"fn": "rack_pair", "cat": {"kind": "server_rack", "place": "wall", "group": _G}},
    "prop_crac_unit": {"fn": "crac", "cat": {"kind": "crac", "place": "wall", "group": _G}},
    "prop_ups_tower": {"fn": "ups", "cat": {"kind": "ups", "place": "wall", "group": _G}},
    "prop_shelving_it_w160": {"fn": "shelving", "w": 1.6, "d": 0.5, "h": 2.0, "load": "it",
                              "cat": {"kind": "shelving", "place": "wall", "support": True, "group": _G}},
    "prop_shelving_linen": {"fn": "shelving", "w": 0.6, "d": 0.5, "h": 2.0, "load": "linen",
                            "cat": {"kind": "shelving", "place": "wall", "support": True, "group": _G}},
    "prop_wine_rack_w260": {"fn": "wine_rack", "cat": {"kind": "shelving", "place": "wall", "group": _G}},
    "prop_key_cabinet_floor": {"fn": "key_cabinet", "cat": {"kind": "key_cabinet", "place": "wall", "support": True,
                                                            "group": _G}},
    "prop_counter_security_w140": {"fn": "counter", "w": 1.4, "d": 0.5, "h": 0.9, "style": "security",
                                   "cat": {"kind": "counter_service", "place": "wall", "support": True, "top": 0.9,
                                           "group": _G}},
    # keepout: the sink / tap and the hob (x0, z0, x1, z1 on the work top): no "on" items there
    "prop_counter_kitchen_w300": {"fn": "counter", "w": 3.0, "d": 0.6, "h": 0.9, "style": "kitchen",
                                  "cat": {"kind": "kitchen_counter", "place": "wall", "support": True, "top": 0.9,
                                          "keepout": [[-1.02, -0.2, -0.47, 0.3]], "group": _G}},
    "prop_counter_pantry_w350": {"fn": "counter", "w": 3.5, "d": 0.55, "h": 0.9, "style": "pantry",
                                 "cat": {"kind": "kitchen_counter", "place": "wall", "support": True, "top": 0.9,
                                         "keepout": [[-1.27, -0.2, -0.72, 0.28], [0.72, -0.25, 1.37, 0.25]], "group": _G}},
    "prop_vanity_w240": {"fn": "vanity", "w": 2.4, "basins": 2, "cat": {"kind": "sink", "place": "wall", "group": _G}},
    "prop_vanity_w200": {"fn": "vanity", "w": 2.0, "basins": 2, "cat": {"kind": "sink", "place": "wall", "group": _G}},
    "prop_outdoor_kitchen": {"fn": "counter", "w": 3.0, "d": 0.6, "h": 0.9, "style": "outdoor",
                             "cat": {"kind": "counter_service", "place": "wall", "support": True, "top": 0.9, "group": _G}},
    "prop_lockers_w120": {"fn": "lockers", "cat": {"kind": "lockers", "place": "wall", "group": _G}},
    "prop_switchboard_w200": {"fn": "switchboard", "cat": {"kind": "switchboard", "place": "wall", "group": _G}},
    "prop_fridge_w70": {"fn": "fridge", "w": 0.7, "d": 0.7, "h": 1.8, "cat": {"kind": "fridge", "place": "wall", "group": _G}},
    "prop_wine_fridge": {"fn": "fridge", "w": 0.6, "d": 0.6, "h": 0.9, "wine": True,
                         "cat": {"kind": "fridge", "place": "wall", "support": True, "group": _G}},
    "prop_humidor_cabinet": {"fn": "cabinet", "w": 0.6, "d": 0.5, "h": 1.0, "style": "humidor",
                             "cat": {"kind": "cabinet", "place": "wall", "support": True, "group": _G}},
    "prop_it_trolley": {"fn": "it_trolley", "cat": {"kind": "cart", "place": "wall", "support": True, "top": 0.9,
                                                    "group": _G}},
    "prop_cleaner_cart": {"fn": "cleaner_cart", "cat": {"kind": "cleaning_cart", "place": "wall", "support": True,
                                                        "group": _G}},
    # partners' floor
    "prop_bar_lounge_w300": {"fn": "bar", "cat": {"kind": "counter_bar", "place": "wall", "support": True, "top": 1.1,
                                                  "group": _G}},
    "prop_sofa_w220": {"fn": "sofa", "w": 2.2, "d": 0.9, "cat": {"kind": "sofa", "place": "wall", "group": _G}},
    "prop_sofa_w200": {"fn": "sofa", "w": 2.0, "d": 0.9, "cat": {"kind": "sofa", "place": "wall", "group": _G}},
    "prop_armchair_club": {"fn": "armchair", "cat": {"kind": "armchair", "place": "seat", "hosts": ["coffee_table"],
                                                     "group": _G}},
    "prop_coffee_table_w100": {"fn": "coffee_table", "cat": {"kind": "coffee_table", "place": "center", "support": True,
                                                             "group": _G}},
    "prop_piano_grand": {"fn": "piano", "cat": {"kind": "piano", "place": "none", "group": _G}},
    "prop_plinth_sculpture_a": {"fn": "plinth", "form": "a", "cat": {"kind": "sculpture", "place": "floor", "group": _G}},
    "prop_plinth_sculpture_b": {"fn": "plinth", "form": "b", "cat": {"kind": "sculpture", "place": "floor", "group": _G}},
    "prop_bed_queen": {"fn": "bed", "cat": {"kind": "bed", "place": "wall", "support": True, "top": 0.6, "group": _G}},
    "prop_nightstand": {"fn": "nightstand", "cat": {"kind": "nightstand", "place": "wall", "support": True, "group": _G}},
    "prop_wardrobe_w160": {"fn": "wardrobe", "w": 1.6, "d": 0.6, "cat": {"kind": "wardrobe", "place": "wall", "group": _G}},
    "prop_wardrobe_w160_d50": {"fn": "wardrobe", "w": 1.6, "d": 0.5, "cat": {"kind": "wardrobe", "place": "wall",
                                                                             "group": _G}},
    # terrace and roof
    "prop_planter_terrace": {"fn": "planter", "cat": {"kind": "planter", "place": "wall", "group": _G}},
    "prop_lounger": {"fn": "lounger", "cat": {"kind": "lounger", "place": "none", "group": _G}},
    "prop_patio_heater_slim": {"fn": "heater", "cat": {"kind": "heater", "place": "floor", "group": _G}},
    "prop_ahu_roof": {"fn": "ahu", "cat": {"kind": "ahu", "place": "none", "group": _G}},
    "prop_chiller_roof": {"fn": "chiller", "cat": {"kind": "chiller", "place": "none", "group": _G}},
    "prop_water_tank_roof": {"fn": "tank", "cat": {"kind": "tank", "place": "none", "group": _G}},
    "prop_lift_motors": {"fn": "lift_motors", "cat": {"kind": "lift_motor", "place": "none", "group": _G}},
    "prop_bmu_machine": {"fn": "bmu", "cat": {"kind": "bmu", "place": "none", "group": _G}},
    "prop_cradle_garage": {"fn": "garage", "cat": {"kind": "garage", "place": "none", "group": _G}},
    "prop_anchor_frame_h140": {"fn": "anchor_frame", "h": 1.4, "cat": {"kind": "anchor_frame", "place": "none", "group": _G}},
    "prop_anchor_frame_h220": {"fn": "anchor_frame", "h": 2.2, "cat": {"kind": "anchor_frame", "place": "none", "group": _G}},
    # fixtures
    "prop_led_linear": {"fn": "led_linear", "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True, "group": _G,
                                                    "light": {"type": "spot", "color": COLD, "energy": 1.1, "range": 4.5,
                                                              "angle": 80, "pos": [0.0, -0.05, 0.0]}}},
    "prop_picture_light": {"fn": "picture_light", "cat": {"kind": "picture_light", "place": "wall_mount", "z": 2.25,
                                                          "fixture": True, "group": _G,
                                                          "light": {"type": "spot", "color": WARM, "energy": 1.6,
                                                                    "range": 2.6, "angle": 50, "pos": [0.0, -0.08, -0.26]}}},
    "prop_bollard_led": {"fn": "bollard", "cat": {"kind": "bollard_light", "place": "floor", "fixture": True, "group": _G,
                                                  "light": {"type": "omni", "color": COLD, "energy": 0.6, "range": 3.5,
                                                            "pos": [0.0, 0.75, 0.0]}}},
}
VARIANTS = {k: {**v, "cat": {**v["cat"], "pin_only": True}} for k, v in BASE_VARIANTS.items()}


def _rnd(i: int, j: int = 0, m: int = 97) -> int:
    """Deterministic small hash (book colours, gaps)."""
    return ((i * 7919 + j * 104729 + 31) * 2654435761 >> 7) % m


def _wheel(p, x: float, y: float, r: float) -> None:
    """Castor (axis X), bottom on z 0."""
    p.cyl(r, 0.03, (x, y, r), "rubber", axis="X", segs=10)


# ------------------------------------------------------------------------------------------ L40

def _dolly(k: Kit, p: dict) -> None:
    """Freight platform trolley: steel deck on castors, a tubular push handle at the back."""
    w, d, h = p["w"] - 0.01, p["d"] - 0.01, p["h"] - 0.01
    o = k.obj("Dolly")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -d / 2, 0.14), (w / 2, d / 2, 0.2), "metal_grey")
    a.bx((-w / 2 + 0.03, -d / 2 + 0.03, 0.2), (w / 2 - 0.03, d / 2 - 0.03, 0.205), "rubber")
    c = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            c.bx((sx * (w / 2 - 0.1) - 0.03, sy * (d / 2 - 0.1) - 0.03, 0.11), (sx * (w / 2 - 0.1) + 0.03,
                 sy * (d / 2 - 0.1) + 0.03, 0.14), "metal_dark")
            _wheel(c, sx * (w / 2 - 0.1), sy * (d / 2 - 0.1), 0.055)
        c.rod((sx * (w / 2 - 0.04), -d / 2 + 0.03, 0.2), (sx * (w / 2 - 0.04), -d / 2 + 0.03, h - 0.02), 0.016,
              "metal_dark", segs=8)
    c.rod((-w / 2 + 0.04, -d / 2 + 0.03, h - 0.02), (w / 2 - 0.04, -d / 2 + 0.03, h - 0.02), 0.016, "metal_dark", segs=8)
    c.rod((-w / 2 + 0.04, -d / 2 + 0.03, 0.6), (w / 2 - 0.04, -d / 2 + 0.03, 0.6), 0.012, "metal_dark", segs=8)
    # a strapped carton load
    b = o.part(bevel=0.006)
    b.bx((-0.4, -0.2, 0.205), (0.1, 0.25, 0.55), "cardboard")
    b.bx((0.12, -0.18, 0.205), (0.42, 0.22, 0.42), "cardboard")
    o.build()


def _lectern(k: Kit, p: dict) -> None:
    """Contractor sign-in lectern: graphite column, sloped top with a clipboard."""
    w, d, h = p["w"] - 0.01, p["d"] - 0.01, p["h"] - 0.01
    o = k.obj("Lectern")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.04), "metal_dark")
    a.bx((-0.15, -0.12, 0.04), (0.15, 0.12, h - 0.12), "metal_graphite")
    a.profile_x([(-d / 2, h - 0.14), (d / 2, h - 0.14), (d / 2, h - 0.08), (-d / 2, h)], -w / 2, w / 2, "metal_graphite")
    t = o.part(bevel=0.0)

    def ztop(y: float) -> float:  # the sloped top (high at the back, -Y)
        return h - 0.08 * (y + d / 2) / d

    # clipboard and its sheet lying on the slope (front +Y is low), a pen
    for i, (x0, x1, y0, y1, key) in enumerate(((-0.17, 0.17, -0.16, 0.15, "wood_oak"), (-0.15, 0.15, -0.12, 0.14, "paper"))):
        b0 = 0.002 + 0.006 * i
        t.profile_x([(y0, ztop(y0) + b0), (y1, ztop(y1) + b0), (y1, ztop(y1) + b0 + 0.005), (y0, ztop(y0) + b0 + 0.005)],
                    x0, x1, key)
    t.rod((0.05, -0.02, ztop(-0.02) + 0.018), (0.2, 0.08, ztop(0.08) + 0.018), 0.004, "plastic_black", segs=6)
    o.build()


def _recycling_cage(k: Kit, p: dict) -> None:
    """Wire recycling cage: steel frame, mesh sides (bars), flattened cardboard and bags inside."""
    w, d, h = p["w"] - 0.01, p["d"] - 0.01, p["h"] - 0.01
    o = k.obj("Cage")
    f = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            f.bx((sx * w / 2 - (0.035 if sx > 0 else 0.0), sy * d / 2 - (0.035 if sy > 0 else 0.0), 0.0),
                 (sx * w / 2 + (0.035 if sx < 0 else 0.0), sy * d / 2 + (0.035 if sy < 0 else 0.0), h), "steel_galv")
    for z in (0.08, h - 0.035):
        f.bx((-w / 2 + 0.035, -d / 2, z), (w / 2 - 0.035, -d / 2 + 0.035, z + 0.035), "steel_galv")
        f.bx((-w / 2 + 0.035, d / 2 - 0.035, z), (w / 2 - 0.035, d / 2, z + 0.035), "steel_galv")
        f.bx((-w / 2, -d / 2 + 0.035, z), (-w / 2 + 0.035, d / 2 - 0.035, z + 0.035), "steel_galv")
        f.bx((w / 2 - 0.035, -d / 2 + 0.035, z), (w / 2, d / 2 - 0.035, z + 0.035), "steel_galv")
    m = o.part(bevel=0.0)
    n = 9
    for i in range(1, n):
        x = -w / 2 + w * i / n
        for y in (-d / 2 + 0.017, d / 2 - 0.017):
            m.rod((x, y, 0.115), (x, y, h - 0.035), 0.004, "steel_galv", segs=4)
        y2 = -d / 2 + d * i / n
        for x2 in (-w / 2 + 0.017, w / 2 - 0.017):
            m.rod((x2, y2, 0.115), (x2, y2, h - 0.035), 0.004, "steel_galv", segs=4)
    for z in (0.5, 0.9, 1.3):
        m.rod((-w / 2 + 0.035, -d / 2 + 0.017, z), (w / 2 - 0.035, -d / 2 + 0.017, z), 0.004, "steel_galv", segs=4)
        m.rod((-w / 2 + 0.035, d / 2 - 0.017, z), (w / 2 - 0.035, d / 2 - 0.017, z), 0.004, "steel_galv", segs=4)
    b = o.part(bevel=0.008)
    b.bx((-w / 2 + 0.06, -d / 2 + 0.06, 0.115), (w / 2 - 0.06, d / 2 - 0.06, 0.135), "metal_grey")
    for i in range(6):
        y0 = -d / 2 + 0.08 + i * 0.12
        b.bx((-w / 2 + 0.08, y0, 0.135), (w / 2 - 0.08 - 0.04 * (i % 3), y0 + 0.03, 0.75 + 0.05 * (i % 2)), "cardboard")
    b.sphere(0.24, (0.25, 0.1, 0.95), "bag_black", segs=10, rings=6, scale=(1.0, 0.9, 0.8))
    o.build()


# ------------------------------------------------------------------------------------------ offices

def _cabinet(k: Kit, p: dict) -> None:
    """Low cabinet w x d x h: walnut credenza (four panel doors, plinth), stone-topped sideboard, or a humidor cabinet
    (glass door over cedar shelves)."""
    w, d, h = p["w"] - 0.01, p["d"] - 0.01, p["h"] - 0.005
    style = p["style"]
    o = k.obj("Cabinet")
    a = o.part(bevel=0.004, segments=2)
    body = {"walnut": "walnut", "stone": "walnut", "humidor": "wood_dark"}[style]
    top = {"walnut": "walnut", "stone": "stone_graphite", "humidor": "wood_dark"}[style]
    a.bx((-w / 2 + 0.02, -d / 2 + 0.01, 0.0), (w / 2 - 0.02, d / 2 - 0.06, 0.08), "metal_dark")
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2 - 0.035, h - 0.03), body)
    a.bx((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h), top)
    t = o.part(bevel=0.002)
    if style == "humidor":
        t.bx((-w / 2 + 0.04, d / 2 - 0.02, 0.12), (w / 2 - 0.04, d / 2 - 0.01, h - 0.07), "glass_tinted")
        for z in (0.3, 0.52, 0.74):
            t.bx((-w / 2 + 0.06, -d / 2 + 0.06, z), (w / 2 - 0.06, d / 2 - 0.06, z + 0.015), "wood_oak")
            t.bx((-0.18, -0.1, z + 0.015), (0.0, 0.08, z + 0.09), "wood_oak")
        t.bx((w / 2 - 0.09, d / 2 - 0.01, 0.45), (w / 2 - 0.07, d / 2 + 0.005, 0.6), "brass")
        o.build()
        return
    n = max(2, round(w / 0.5))
    for i in range(n):
        x0 = -w / 2 + 0.02 + i * (w - 0.04) / n
        x1 = x0 + (w - 0.04) / n - 0.006
        panel_door(t, x0, x1, 0.1, h - 0.05, d / 2 - 0.035, body, "brass" if style == "walnut" else None,
                   frame_w=0.04, depth=0.008)
        hx = x1 - 0.05 if i % 2 == 0 else x0 + 0.05
        t.bx((hx - 0.008, d / 2 - 0.015, h * 0.45), (hx + 0.008, d / 2 - 0.002, h * 0.7), "brass")
    o.build()


def _bookcase(k: Kit, p: dict) -> None:
    """Walnut bookcase w x d x h: carcass, five shelves, rows of bound books (deterministic colours / gaps), a few
    leaning sets and bookends."""
    w, d, h = p["w"] - 0.01, p["d"] - 0.01, p["h"] - 0.005
    seed = int(p.get("seed", 1))
    o = k.obj("Bookcase")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.0), (-w / 2 + 0.03, d / 2, h), "walnut")
    a.bx((w / 2 - 0.03, -d / 2, 0.0), (w / 2, d / 2, h), "walnut")
    a.bx((-w / 2 + 0.03, -d / 2, 0.0), (w / 2 - 0.03, -d / 2 + 0.02, h - 0.03), "walnut")
    a.bx((-w / 2 + 0.03, -d / 2, h - 0.03), (w / 2 - 0.03, d / 2, h), "walnut")
    a.bx((-w / 2 + 0.03, -d / 2 + 0.02, 0.0), (w / 2 - 0.03, d / 2, 0.08), "walnut")
    bays = max(1, round(w / 0.8))
    for i in range(1, bays):
        x = -w / 2 + w * i / bays
        a.bx((x - 0.012, -d / 2 + 0.02, 0.08), (x + 0.012, d / 2 - 0.005, h - 0.03), "walnut")
    ns = 5
    pitch = (h - 0.11) / ns
    b = o.part(bevel=0.0)
    keys = ("leather", "canvas_bank", "velvet_red", "fabric_graphite", "leather_cognac", "paint_slate", "canvas_walnut")
    for s in range(ns):
        z = 0.08 + s * pitch
        if s > 0:
            a.bx((-w / 2 + 0.03, -d / 2 + 0.02, z - 0.02), (w / 2 - 0.03, d / 2 - 0.005, z), "walnut")
        for bay in range(bays):
            bx0 = -w / 2 + w * bay / bays + (0.03 if bay == 0 else 0.012)
            bx1 = -w / 2 + w * (bay + 1) / bays - (0.03 if bay == bays - 1 else 0.012)
            x = bx0 + 0.01
            j = 0
            limit = bx1 - 0.01 - (0.12 if _rnd(seed, s * 11 + bay) % 3 == 0 else 0.0)
            while True:
                r = _rnd(seed * 31 + s, bay * 53 + j)
                bw = 0.025 + (r % 4) * 0.008
                bh = pitch * (0.62 + (r % 5) * 0.06) - 0.02
                if x + bw > limit:
                    break
                bd = d * (0.7 + (r % 3) * 0.06) - 0.03
                b.bx((x, d / 2 - 0.01 - bd, z + 0.001), (x + bw - 0.002, d / 2 - 0.01, z + 0.001 + bh), keys[r % len(keys)])
                x += bw
                j += 1
    o.build()


def _table(k: Kit, p: dict) -> None:
    """Rectangular table w (X) x d (Y) x h: conference / boardroom (walnut top with a stone inlay and cable ports, two
    graphite pedestal bases), dining (walnut, four tapered legs and aprons), break (laminate on a steel frame)."""
    w, d, h = p["w"] - 0.01, p["d"] - 0.01, p["h"]
    style = p["style"]
    o = k.obj("Table")
    a = o.part(bevel=0.005, segments=2)
    top = {"conference": "walnut", "boardroom": "walnut", "dining": "walnut", "break": "laminate_grey"}[style]
    a.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), top)
    t = o.part(bevel=0.0)
    if style in ("conference", "boardroom"):
        t.bx((-w / 2 + 0.25, -d / 2 + 0.3, h - 0.002), (w / 2 - 0.25, d / 2 - 0.3, h + 0.002), "stone_graphite")
        for i in range(3 if style == "boardroom" else 2):
            cx = -w / 2 + w * (i + 1) / (4 if style == "boardroom" else 3)
            t.bx((cx - 0.09, -0.04, h + 0.002), (cx + 0.09, 0.04, h + 0.006), "metal_dark")
        for sx in (-1, 1):
            cx = sx * w * 0.3
            a.bx((cx - 0.2, -d / 2 + 0.3, 0.0), (cx + 0.2, d / 2 - 0.3, 0.03), "metal_graphite")
            a.bx((cx - 0.12, -d / 2 + 0.38, 0.03), (cx + 0.12, d / 2 - 0.38, h - 0.04), "metal_graphite")
    elif style == "dining":
        legs4(a, w, d, h - 0.04, 0.06, 0.07, "walnut", taper=0.7, round_=True)
        a.bx((-w / 2 + 0.1, -d / 2 + 0.07, h - 0.13), (w / 2 - 0.1, -d / 2 + 0.09, h - 0.04), "walnut")
        a.bx((-w / 2 + 0.1, d / 2 - 0.09, h - 0.13), (w / 2 - 0.1, d / 2 - 0.07, h - 0.04), "walnut")
        # runner and two candle holders
        t.bx((-w / 2 + 0.5, -0.18, h + 0.001), (w / 2 - 0.5, 0.18, h + 0.004), "linen_white")
        for sx in (-0.5, 0.5):
            t.lathe([(0.04, 0.0), (0.03, 0.02), (0.012, 0.06), (0.02, 0.1), (0.0, 0.1)], "brass",
                    centre=(sx, 0.0, h + 0.004), segs=12)
    else:
        legs4(a, w, d, h - 0.04, 0.04, 0.04, "steel")
        a.bx((-w / 2 + 0.06, -d / 2 + 0.06, h - 0.1), (w / 2 - 0.06, -d / 2 + 0.08, h - 0.04), "steel")
        a.bx((-w / 2 + 0.06, d / 2 - 0.08, h - 0.1), (w / 2 - 0.06, d / 2 - 0.06, h - 0.04), "steel")
    o.build()


def _table_round(k: Kit, p: dict) -> None:
    """Round meeting / pantry table d 1.2: walnut top, graphite trumpet base."""
    r, h = p["r"] - 0.005, p["h"]
    o = k.obj("Table")
    a = o.part(bevel=0.0)
    a.lathe([(r - 0.01, h - 0.04), (r, h - 0.03), (r, h - 0.005), (r - 0.005, h), (0.0, h)], "walnut", segs=40)
    a.lathe([(r - 0.02, h - 0.04), (0.0, h - 0.04)], "walnut", segs=40)
    a.lathe([(0.3, 0.0), (0.3, 0.02), (0.1, 0.06), (0.06, 0.3), (0.07, h - 0.06), (0.15, h - 0.04)], "metal_graphite",
            segs=24)
    o.build()


def _reception(k: Kit, p: dict) -> None:
    """Executive reception desk 2.99 x 0.59 m: honed graphite stone front (visitor side, Blender -Y) up to the 1.05 m
    walnut transaction ledge, a 0.72 m walnut work top on the guard's side (+Y), a cold LED reveal under the ledge,
    a monitor and phone on the work top."""
    w, d = 2.99, 0.59
    o = k.obj("Desk")
    a = o.part(bevel=0.004, segments=2)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, -d / 2 + 0.06, 1.0), "stone_graphite")
    for sx in (-1, 1):
        a.bx((sx * w / 2 - (0.05 if sx > 0 else 0.0), -d / 2 + 0.06, 0.0), (sx * w / 2 + (0.05 if sx < 0 else 0.0),
             d / 2, 1.0), "stone_graphite")
    a.bx((-w / 2, -d / 2, 1.0), (w / 2, -d / 2 + 0.24, 1.05), "walnut")
    a.bx((-w / 2 + 0.05, -d / 2 + 0.06, 0.68), (w / 2 - 0.05, d / 2, 0.72), "walnut")
    a.bx((-w / 2 + 0.05, -d / 2 + 0.06, 0.0), (w / 2 - 0.05, -d / 2 + 0.24, 0.68), "walnut")
    # drawer pedestal on the guard side, east end
    a.bx((w / 2 - 0.5, -d / 2 + 0.24, 0.02), (w / 2 - 0.06, d / 2 - 0.02, 0.66), "walnut")
    t = o.part(bevel=0.0)
    t.bx((-w / 2 + 0.06, -d / 2 + 0.002, 0.93), (w / 2 - 0.06, -d / 2 + 0.006, 0.95), "emit_led_cold")
    for i in range(3):
        z0 = 0.05 + i * 0.2
        t.bx((w / 2 - 0.48, d / 2 - 0.02, z0), (w / 2 - 0.08, d / 2 - 0.008, z0 + 0.18), "walnut")
        t.bx((w / 2 - 0.33, d / 2 - 0.008, z0 + 0.13), (w / 2 - 0.23, d / 2, z0 + 0.145), "brass")
    # monitor (screen faces the guard, +Y) and the logbook
    t.bx((-0.3, -0.08, 0.72), (-0.1, 0.02, 0.73), "metal_dark")
    t.rod((-0.2, -0.05, 0.73), (-0.2, -0.05, 0.85), 0.015, "metal_dark", segs=8)
    t.bx((-0.47, -0.08, 0.83), (0.07, -0.05, 1.0), "plastic_black")
    t.bx((-0.45, -0.05, 0.845), (0.05, -0.045, 0.985), "emit_screen")
    t.bx((0.25, -0.02, 0.72), (0.55, 0.2, 0.735), "leather")
    o.build()


def _printer(k: Kit, p: dict) -> None:
    """Multifunction printer / copier w x d x h on a cabinet: scanner lid, control panel, paper trays."""
    w, d, h = p["w"] - 0.01, p["d"] - 0.01, p["h"] - 0.005
    big = bool(p.get("big", False))
    d -= 0.05  # trays and handles stand proud of the body: the whole stays inside the layout box
    o = k.obj("Printer")
    a = o.part(bevel=0.006, segments=2)
    a.bx((-w / 2, -d / 2, 0.06), (w / 2, d / 2, h - 0.08), "plastic_white")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.03, 0.06), "plastic_grey")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, h - 0.08), (w / 2 - 0.02, d / 2 - 0.02, h - 0.03), "plastic_grey")
    a.bx((-w / 2 + 0.03, -d / 2 + 0.03, h - 0.03), (w / 2 - 0.03, d / 2 - 0.03, h), "plastic_white")
    t = o.part(bevel=0.0)
    trays = 3 if big else 2
    for i in range(trays):
        z0 = 0.1 + i * (h - 0.35) / trays
        t.bx((-w / 2 + 0.04, d / 2, z0), (w / 2 - 0.04, d / 2 + 0.005, z0 + (h - 0.35) / trays - 0.02), "plastic_white")
        t.bx((-0.08, d / 2 + 0.005, z0 + 0.06), (0.08, d / 2 + 0.02, z0 + 0.08), "plastic_grey")
    t.bx((w / 2 - 0.3, d / 2 - 0.12, h - 0.002), (w / 2 - 0.05, d / 2 - 0.02, h + 0.02), "plastic_black")
    t.bx((w / 2 - 0.28, d / 2 - 0.1, h + 0.02), (w / 2 - 0.07, d / 2 - 0.04, h + 0.022), "emit_screen")
    t.bx((-w / 2 + 0.06, -0.1, h - 0.12), (w / 2 - 0.35, d / 2 + 0.002, h - 0.1), "paper")
    o.build()


def _pod(k: Kit, p: dict) -> None:
    """Bench workstation pod 2.39 x 1.59 m: four oak desks on a graphite spine frame, a cable tray down the middle,
    four drawer pedestals; monitors come from the kit."""
    w, d, h = 2.39, 1.59, 0.74
    o = k.obj("Pod")
    a = o.part(bevel=0.003)
    for sy in (-1, 1):
        for sx in (-1, 1):
            x0, x1 = sorted((sx * 0.003, sx * w / 2))
            y0, y1 = sorted((sy * 0.003, sy * d / 2))
            a.bx((x0, y0, h - 0.025), (x1, y1, h), "wood_oak")
    f = o.part(bevel=0.0)
    for sx in (-1, 0, 1):
        x = sx * (w / 2 - 0.04)
        f.bx((x - 0.03, -d / 2 + 0.06, 0.0), (x + 0.03, d / 2 - 0.06, 0.03), "metal_graphite")
        f.bx((x - 0.025, -0.03, 0.03), (x + 0.025, 0.03, h - 0.025), "metal_graphite")
    f.bx((-w / 2 + 0.06, -0.08, h - 0.16), (w / 2 - 0.06, 0.08, h - 0.13), "metal_graphite")
    for sy in (-1, 1):
        for sx in (-1, 1):
            cx = sx * 0.45
            y0, y1 = sorted((sy * 0.12, sy * (d / 2 - 0.12)))
            f.bx((cx - 0.2, y0, 0.03), (cx + 0.2, y1, 0.6), "metal_grey")
            for i in range(3):
                z0 = 0.06 + i * 0.18
                yf = sy * (d / 2 - 0.12)
                f.bx((cx - 0.19, min(yf, yf + sy * 0.01), z0), (cx + 0.19, max(yf, yf + sy * 0.01), z0 + 0.16), "metal_grey")
    o.build()


def _compact(k: Kit, p: dict) -> None:
    """Mobile compact archive shelving 3.99 x 0.79 x 2.19 m (double-sided, on floor rails): graphite end panels with
    hand wheels, steel shelves of archive boxes on both faces."""
    w, d, h = 3.99, 0.79, 2.19
    o = k.obj("Compact")
    a = o.part(bevel=0.004)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 - 0.035), sx * (w / 2 - 0.085)))
        a.bx((x0, -d / 2, 0.06), (x1, d / 2, h), "metal_graphite")
    a.bx((-w / 2 + 0.035, -d / 2 + 0.05, 0.0), (w / 2 - 0.035, d / 2 - 0.05, 0.06), "metal_dark")
    a.bx((-w / 2 + 0.085, -0.01, 0.06), (w / 2 - 0.085, 0.01, h - 0.02), "metal_grey")
    t = o.part(bevel=0.0)
    for sx in (-1, 1):
        t.torus(0.12, 0.012, (sx * (w / 2 - 0.016), 0.0, 1.1), "steel", segs=16, rsegs=6, axis="X")
        t.rod((sx * (w / 2 - 0.035), 0.0, 1.1), (sx * (w / 2 - 0.016), 0.0, 1.1), 0.02, "steel", segs=8)
    b = o.part(bevel=0.003)
    ns = 6
    pitch = (h - 0.12) / ns
    for s in range(ns):
        z = 0.08 + s * pitch
        a.bx((-w / 2 + 0.05, -d / 2 + 0.01, z), (w / 2 - 0.05, d / 2 - 0.01, z + 0.02), "steel")
        for side in (-1, 1):
            nb = 9
            for i in range(nb):
                r = _rnd(s * 17 + i, side + 5)
                if r % 7 == 0:
                    continue
                x0 = -w / 2 + 0.07 + i * (w - 0.14) / nb
                x1 = x0 + (w - 0.14) / nb - 0.02
                y0, y1 = sorted((side * 0.02, side * (d / 2 - 0.03)))
                b.bx((x0, y0, z + 0.02), (x1, y1, z + 0.02 + pitch * 0.62), "cardboard" if r % 3 else "paper")
    o.build()


def _library_stack(k: Kit, p: dict) -> None:
    """Double-sided law-library stack 3.99 x 0.59 x 2.19 m: walnut end panels, a centre spine, six shelves of bound
    law reports (uniform runs of maroon / green / tan spines) on both faces."""
    w, d, h = 3.99, 0.59, 2.19
    o = k.obj("Stack")
    a = o.part(bevel=0.003)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.04)))
        a.bx((x0, -d / 2, 0.0), (x1, d / 2, h), "walnut")
    a.bx((-w / 2 + 0.04, -0.01, 0.0), (w / 2 - 0.04, 0.01, h - 0.02), "walnut")
    a.bx((-w / 2 + 0.04, -d / 2 + 0.02, 0.0), (w / 2 - 0.04, d / 2 - 0.02, 0.08), "walnut")
    a.bx((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h), "walnut")
    b = o.part(bevel=0.002)
    runs = ("velvet_red", "felt_dark", "canvas_bank", "leather", "velvet_red", "canvas_walnut")
    ns = 6
    pitch = (h - 0.11) / ns
    for s in range(ns):
        z = 0.08 + s * pitch
        if s > 0:
            a.bx((-w / 2 + 0.04, -d / 2 + 0.01, z - 0.02), (w / 2 - 0.04, d / 2 - 0.01, z), "walnut")
        for side in (-1, 1):
            x = -w / 2 + 0.06
            j = 0
            while x < w / 2 - 0.12:
                r = _rnd(s * 13 + j, side + 3)
                seg = 0.25 + (r % 5) * 0.08
                x1 = min(x + seg, w / 2 - 0.06)
                y0, y1 = sorted((side * 0.02, side * (d / 2 - 0.03)))
                bh = pitch * (0.7 + (r % 3) * 0.05) - 0.02
                b.bx((x, y0, z + 0.001), (x1 - 0.004, y1, z + 0.001 + bh), runs[(s + j + (side > 0)) % len(runs)])
                x = x1 + (0.05 if r % 4 == 0 else 0.0)
                j += 1
    o.build()


# ------------------------------------------------------------------------------------------ back of house

def _mop_sink(k: Kit, p: dict) -> None:
    """Janitor's floor sink 0.89 x 0.49 m: a stainless tub on a plinth, a wall tap and a hose bracket."""
    w, d = 0.89, 0.49
    o = k.obj("Sink")
    a = o.part(bevel=0.006)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.08), "concrete_light")
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, -d / 2 + 0.04, 0.3), "steel")
    a.bx((-w / 2, d / 2 - 0.04, 0.08), (w / 2, d / 2, 0.3), "steel")
    a.bx((-w / 2, -d / 2 + 0.04, 0.08), (-w / 2 + 0.04, d / 2 - 0.04, 0.3), "steel")
    a.bx((w / 2 - 0.04, -d / 2 + 0.04, 0.08), (w / 2, d / 2 - 0.04, 0.3), "steel")
    a.bx((-w / 2 + 0.04, -d / 2 + 0.04, 0.08), (w / 2 - 0.04, d / 2 - 0.04, 0.1), "steel")
    t = o.part(bevel=0.0)
    t.bx((-0.25, -d / 2, 0.55), (0.25, -d / 2 + 0.03, 0.6), "chrome")
    for sx in (-0.15, 0.15):
        t.rod((sx, -d / 2 + 0.03, 0.575), (sx, -d / 2 + 0.12, 0.575), 0.012, "chrome", segs=8)
        t.rod((sx, -d / 2 + 0.12, 0.575), (sx, -d / 2 + 0.12, 0.5), 0.01, "chrome", segs=8)
    t.bx((0.25, -d / 2, 0.75), (0.4, -d / 2 + 0.06, 0.88), "plastic_grey")
    o.build()


def _rack_pair(k: Kit, p: dict) -> None:
    """The ledger rack: two 0.65 m server cabinets bayed together (1.29 x 0.59 x 1.99 m), perforated graphite doors
    with blue-white status LEDs (front +Y), cable management on top."""
    w, d, h = 1.29, 0.59, 1.99
    o = k.obj("Racks")
    a = o.part(bevel=0.004)
    for i in range(2):
        x0 = -w / 2 + i * w / 2 + (0.0 if i == 0 else 0.003)
        x1 = x0 + w / 2 - 0.003
        a.bx((x0, -d / 2, 0.05), (x1, d / 2 - 0.02, h - 0.03), "metal_graphite")
        a.bx((x0 + 0.02, -d / 2 + 0.02, 0.0), (x1 - 0.02, d / 2 - 0.04, 0.05), "metal_dark")
        a.bx((x0, -d / 2, h - 0.03), (x1, d / 2 - 0.02, h), "metal_dark")
    t = o.part(bevel=0.0)
    for i in range(2):
        x0 = -w / 2 + i * w / 2 + 0.03
        x1 = x0 + w / 2 - 0.06
        t.bx((x0, d / 2 - 0.02, 0.1), (x1, d / 2 - 0.006, h - 0.08), "metal_dark")
        for r in range(14):
            z = 0.16 + r * 0.12
            t.bx((x0 + 0.04, d / 2 - 0.006, z), (x1 - 0.12, d / 2 - 0.002, z + 0.06), "plastic_black")
            led = "emit_led_green" if (r + i) % 5 else "emit_amber"
            t.bx((x1 - 0.1, d / 2 - 0.006, z + 0.02), (x1 - 0.085, d / 2 - 0.001, z + 0.035), led)
            t.bx((x1 - 0.07, d / 2 - 0.006, z + 0.02), (x1 - 0.055, d / 2 - 0.001, z + 0.035), "emit_led_cold")
        t.bx((x1 - 0.03, d / 2 - 0.006, 0.9), (x1 - 0.015, d / 2 + 0.01, 1.2), "steel")
    o.build()


def _crac(k: Kit, p: dict) -> None:
    """Close-control air unit 0.99 x 0.79 x 1.89 m: white cabinet, front filter grille, a small display."""
    w, d, h = 0.99, 0.79, 1.89
    o = k.obj("Crac")
    a = o.part(bevel=0.006)
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2 - 0.015, h), "metal_white")
    a.bx((-w / 2 + 0.03, -d / 2 + 0.03, 0.0), (w / 2 - 0.03, d / 2 - 0.045, 0.08), "metal_dark")
    d -= 0.03
    t = o.part(bevel=0.0)
    for i in range(16):
        z = 0.2 + i * 0.06
        t.bx((-w / 2 + 0.06, d / 2, z), (w / 2 - 0.06, d / 2 + 0.006, z + 0.03), "metal_grey")
    t.bx((-0.15, d / 2, 1.5), (0.15, d / 2 + 0.01, 1.66), "plastic_black")
    t.bx((-0.12, d / 2 + 0.01, 1.53), (0.12, d / 2 + 0.012, 1.63), "emit_screen")
    t.bx((-w / 2 + 0.06, d / 2, 1.72), (w / 2 - 0.06, d / 2 + 0.004, 1.84), "metal_grey")
    o.build()


def _ups(k: Kit, p: dict) -> None:
    """UPS tower 0.79 x 0.59 x 1.59 m: graphite cabinet, battery-status panel, vents."""
    w, d, h = 0.79, 0.59, 1.59
    o = k.obj("Ups")
    a = o.part(bevel=0.005)
    a.bx((-w / 2, -d / 2, 0.05), (w / 2, d / 2, h), "metal_graphite")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.02, 0.05), "metal_dark")
    t = o.part(bevel=0.0)
    t.bx((-0.25, d / 2, 1.2), (0.25, d / 2 + 0.01, 1.42), "plastic_black")
    t.bx((-0.22, d / 2 + 0.01, 1.3), (0.05, d / 2 + 0.012, 1.4), "emit_screen")
    for i in range(4):
        t.bx((0.1 + i * 0.03, d / 2 + 0.01, 1.33), (0.115 + i * 0.03, d / 2 + 0.014, 1.345), "emit_led_green")
    for i in range(12):
        z = 0.15 + i * 0.07
        t.bx((-w / 2 + 0.08, d / 2, z), (w / 2 - 0.08, d / 2 + 0.005, z + 0.035), "metal_dark")
    o.build()


def _shelving(k: Kit, p: dict) -> None:
    """Steel shelving w x d x h: IT spares (drive boxes, cable reels, switches) or linen (folded towels, sheets)."""
    w, d, h = p["w"] - 0.01, p["d"] - 0.01, p["h"] - 0.005
    load = p["load"]
    o = k.obj("Shelving")
    a = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = sx * (w / 2 - 0.015)
            y = sy * (d / 2 - 0.015)
            a.bx((x - 0.015, y - 0.015, 0.0), (x + 0.015, y + 0.015, h), "steel")
    ns = 5
    b = o.part(bevel=0.004)
    for s in range(ns):
        z = 0.12 + s * (h - 0.2) / (ns - 1)
        a.bx((-w / 2 + 0.03, -d / 2, z - 0.025), (w / 2 - 0.03, d / 2, z), "metal_white" if load == "linen" else "steel")
        if s == ns - 1:
            break
        pitch = (h - 0.2) / (ns - 1)
        x = -w / 2 + 0.05
        i = 0
        while x < w / 2 - 0.1:
            r = _rnd(s * 7 + i, len(load))
            if load == "linen":
                cw = 0.26
                for f in range(3 + r % 3):
                    b.bx((x, -d / 2 + 0.04, z + f * 0.055), (x + cw - 0.02, d / 2 - 0.04, z + f * 0.055 + 0.05),
                         "linen_white" if (f + i) % 4 else "fabric_teal")
            else:
                cw = min(0.22 + (r % 3) * 0.08, w / 2 - 0.03 - x)
                if cw < 0.1:
                    break
                key = ("cardboard", "plastic_black", "plastic_grey", "cardboard")[r % 4]
                b.bx((x, -d / 2 + 0.05, z), (x + cw - 0.02, d / 2 - 0.04, z + pitch * (0.35 + (r % 4) * 0.1)), key)
            x += cw
            i += 1
    o.build()


def _wine_rack(k: Kit, p: dict) -> None:
    """Walnut wine wall 2.59 x 0.49 x 1.99 m: a lattice of cubbies with bottle ends (deterministic gaps)."""
    w, d, h = 2.59, 0.49, 1.99
    o = k.obj("Rack")
    a = o.part(bevel=0.002)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, -d / 2 + 0.02, h), "walnut")
    a.bx((-w / 2, -d / 2 + 0.02, 0.0), (w / 2, d / 2, 0.06), "walnut")
    a.bx((-w / 2, -d / 2 + 0.02, h - 0.03), (w / 2, d / 2, h), "walnut")
    nx, nz = 12, 9
    for i in range(nx + 1):
        x = -w / 2 + i * w / nx
        x0, x1 = max(-w / 2, x - 0.01), min(w / 2, x + 0.01)
        a.bx((x0, -d / 2 + 0.02, 0.06), (x1, d / 2, h - 0.03), "walnut")
    for j in range(1, nz):
        z = 0.06 + j * (h - 0.09) / nz
        a.bx((-w / 2, -d / 2 + 0.02, z - 0.008), (w / 2, d / 2, z + 0.008), "walnut")
    b = o.part(bevel=0.0)
    for i in range(nx):
        for j in range(nz):
            r = _rnd(i, j)
            if r % 6 == 0:
                continue
            cx = -w / 2 + (i + 0.5) * w / nx
            cz = 0.06 + (j + 0.5) * (h - 0.09) / nz
            key = "felt_dark" if r % 3 else "velvet_red"
            b.rod((cx, -d / 2 + 0.05, cz - 0.03), (cx, d / 2 - 0.08, cz - 0.03), 0.037, key, segs=8)
            b.rod((cx, d / 2 - 0.08, cz - 0.03), (cx, d / 2 - 0.01, cz - 0.03), 0.013, "metal_dark" if r % 2 else "brass",
                  segs=6)
    o.build()


def _key_cabinet(k: Kit, p: dict) -> None:
    """Security key cabinet 0.79 x 0.29 x 0.99 m: a steel cupboard with a key-safe door and a combination dial."""
    w, d, h = 0.79, 0.29, 0.99
    o = k.obj("Cabinet")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2 - 0.04, h), "metal_grey")
    t = o.part(bevel=0.002)
    panel_door(t, -w / 2 + 0.02, -0.005, 0.04, h - 0.04, d / 2 - 0.04, "metal_grey", None, frame_w=0.03, depth=0.006)
    panel_door(t, 0.005, w / 2 - 0.02, 0.04, h - 0.04, d / 2 - 0.04, "metal_grey", None, frame_w=0.03, depth=0.006)
    t.cyl(0.03, 0.016, (0.2, d / 2 - 0.012, 0.7), "metal_dark", axis="Y", segs=16)
    t.bx((-0.06, d / 2 - 0.025, 0.45), (-0.04, d / 2 - 0.004, 0.6), "chrome")
    t.bx((0.04, d / 2 - 0.025, 0.45), (0.06, d / 2 - 0.004, 0.6), "chrome")
    o.build()


def _counter(k: Kit, p: dict) -> None:
    """Counter w x d, work top at 0.9: security (graphite cabinets, laminate top), kitchen (graphite doors, stone top,
    a sink and a tap), pantry (the same with a hob), outdoor (stainless doors, stone top, a built-in grill)."""
    w, d, h = p["w"] - 0.01, p["d"] - 0.01, p["h"]
    style = p["style"]
    o = k.obj("Counter")
    a = o.part(bevel=0.003)
    top = {"security": "laminate_grey", "kitchen": "stone_graphite", "pantry": "stone_graphite",
           "outdoor": "stone_graphite"}[style]
    body = {"security": "metal_graphite", "kitchen": "paint_graphite", "pantry": "paint_graphite",
            "outdoor": "steel"}[style]
    a.bx((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h), top)
    a.bx((-w / 2 + 0.01, -d / 2 + 0.01, 0.1), (w / 2 - 0.01, d / 2 - 0.05, h - 0.03), body)
    a.bx((-w / 2 + 0.03, -d / 2 + 0.03, 0.0), (w / 2 - 0.03, d / 2 - 0.1, 0.1), "plastic_black")
    t = o.part(bevel=0.0)
    n = max(2, round(w / 0.6))
    for i in range(n):
        x0 = -w / 2 + 0.015 + i * (w - 0.03) / n
        x1 = x0 + (w - 0.03) / n - 0.006
        t.bx((x0, d / 2 - 0.05, 0.12), (x1, d / 2 - 0.035, h - 0.05), body)
        bar_handle(t, x0 + 0.06, x1 - 0.06, d / 2 - 0.035, h - 0.12, standoff=0.028)
    if style in ("kitchen", "pantry"):
        t.bx((-w / 2 + 0.5, -0.17, h - 0.002), (-w / 2 + 1.0, 0.13, h + 0.012), "steel")  # a raised drainer (keepout)
        t.rod((-w / 2 + 0.75, -d / 2 + 0.05, h), (-w / 2 + 0.75, -d / 2 + 0.05, h + 0.32), 0.012, "chrome", segs=8)
        t.rod((-w / 2 + 0.75, -d / 2 + 0.05, h + 0.32), (-w / 2 + 0.75, -d / 2 + 0.2, h + 0.3), 0.01, "chrome", segs=8)
    if style == "pantry":
        t.bx((w / 2 - 1.0, -0.2, h - 0.002), (w / 2 - 0.4, 0.2, h + 0.012), "plastic_black")
        for cx in (w / 2 - 0.85, w / 2 - 0.55):
            for cy in (-0.1, 0.1):
                t.cyl(0.07, 0.002, (cx, cy, h + 0.013), "metal_dark", segs=16)
    if style == "outdoor":
        t.bx((-0.5, -0.22, h - 0.012), (0.5, 0.2, h + 0.001), "metal_dark")  # the grill, flush with the work top
        for i in range(8):
            x = -0.45 + i * 0.13
            t.bx((x, -0.2, h - 0.006), (x + 0.015, 0.18, h + 0.001), "steel")
    o.build()


def _vanity(k: Kit, p: dict) -> None:
    """Washroom vanity w x 0.54 x 0.85: a floating honed-stone top on a graphite apron, under-mount basins, chrome
    taps on the back edge; the plumbing box against the wall."""
    w, d, h = float(p["w"]) - 0.01, 0.54, 0.85
    nb = int(p["basins"])
    o = k.obj("Vanity")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -d / 2, h - 0.05), (w / 2, d / 2, h), "stone_graphite")
    a.bx((-w / 2 + 0.02, -d / 2, h - 0.25), (w / 2 - 0.02, d / 2 - 0.02, h - 0.05), "paint_graphite")
    a.bx((-w / 2 + 0.1, -d / 2, 0.0), (w / 2 - 0.1, -d / 2 + 0.12, h - 0.25), "paint_graphite")
    t = o.part(bevel=0.0)
    for i in range(nb):
        cx = -w / 2 + (i + 0.5) * w / nb
        t.lathe([(0.2, 0.0), (0.18, -0.01), (0.12, -0.11), (0.0, -0.12)], "ceramic", centre=(cx, 0.02, h + 0.001), segs=24,
                scale_xy=(1.0, 0.7))
        t.rod((cx, -d / 2 + 0.07, h), (cx, -d / 2 + 0.07, h + 0.22), 0.012, "chrome", segs=8)
        t.rod((cx, -d / 2 + 0.07, h + 0.22), (cx, -d / 2 + 0.18, h + 0.2), 0.009, "chrome", segs=8)
    o.build()


def _lockers(k: Kit, p: dict) -> None:
    """Guard locker bank 1.19 x 0.49 x 1.79 m: four full-height graphite lockers, vents, handles, name cards."""
    w, d, h = 1.19, 0.49, 1.79
    o = k.obj("Lockers")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2 - 0.02, h), "metal_graphite")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.06, 0.08), "metal_dark")
    t = o.part(bevel=0.0)
    for i in range(4):
        x0 = -w / 2 + i * w / 4 + 0.005
        x1 = x0 + w / 4 - 0.01
        t.bx((x0, d / 2 - 0.02, 0.1), (x1, d / 2 - 0.008, h - 0.02), "metal_graphite")
        for v in range(4):
            z = h - 0.2 + v * 0.03
            t.bx((x0 + 0.05, d / 2 - 0.008, z), (x1 - 0.05, d / 2 - 0.004, z + 0.012), "metal_dark")
        t.bx((x1 - 0.05, d / 2 - 0.008, 0.95), (x1 - 0.035, d / 2 + 0.01, 1.1), "chrome")
        t.bx((x0 + 0.05, d / 2 - 0.008, 1.35), (x0 + 0.15, d / 2 - 0.004, 1.4), "paper")
    o.build()


def _switchboard(k: Kit, p: dict) -> None:
    """Low-voltage switchboard 1.99 x 0.49 x 1.99 m: three graphite sections, breaker windows, meters, a cable tray on
    top."""
    w, d, h = 1.99, 0.49, 1.99
    o = k.obj("Board")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.1), (w / 2, d / 2 - 0.02, h - 0.05), "metal_grey")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.06, 0.1), "metal_dark")
    a.bx((-w / 2 + 0.05, -d / 2 + 0.05, h - 0.05), (w / 2 - 0.05, d / 2 - 0.1, h), "steel_galv")
    t = o.part(bevel=0.0)
    for i in range(3):
        x0 = -w / 2 + i * w / 3 + 0.01
        x1 = x0 + w / 3 - 0.02
        t.bx((x0, d / 2 - 0.02, 0.15), (x1, d / 2 - 0.008, h - 0.1), "metal_grey")
        t.bx((x0 + 0.08, d / 2 - 0.008, 1.0), (x1 - 0.08, d / 2 - 0.004, 1.5), "glass_tinted")
        for r in range(4):
            t.bx((x0 + 0.1, d / 2 - 0.012, 1.06 + r * 0.11), (x1 - 0.1, d / 2 - 0.009, 1.12 + r * 0.11), "plastic_black")
        t.cyl(0.05, 0.02, ((x0 + x1) / 2, d / 2 - 0.0, 1.7), "plastic_white", axis="Y", segs=16)
        t.bx((x1 - 0.06, d / 2 - 0.008, 0.6), (x1 - 0.045, d / 2 + 0.01, 0.8), "chrome")
        t.bx(((x0 + x1) / 2 - 0.01, d / 2 - 0.008, 1.62), ((x0 + x1) / 2 + 0.01, d / 2 + 0.004, 1.63), "emit_led_green")
    o.build()


def _fridge(k: Kit, p: dict) -> None:
    """Integrated fridge (stainless door, graphite carcass) or a glass-door wine fridge with bottle ends."""
    w, d, h = p["w"] - 0.01, p["d"] - 0.01, p["h"] - 0.005
    wine = bool(p.get("wine", False))
    o = k.obj("Fridge")
    a = o.part(bevel=0.006)
    a.bx((-w / 2, -d / 2, 0.04), (w / 2, d / 2 - 0.04, h), "paint_graphite" if wine else "steel")
    a.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.0), (w / 2 - 0.02, d / 2 - 0.08, 0.04), "plastic_black")
    t = o.part(bevel=0.003)
    if wine:
        t.bx((-w / 2 + 0.03, d / 2 - 0.04, 0.08), (w / 2 - 0.03, d / 2 - 0.03, h - 0.04), "glass_tinted")
        for j in range(4):
            z = 0.15 + j * 0.17
            for i in range(4):
                x = -w / 2 + 0.1 + i * (w - 0.2) / 3
                t.rod((x, -d / 2 + 0.06, z), (x, d / 2 - 0.09, z), 0.035, "felt_dark", segs=8)
        t.bx((-w / 2 + 0.03, d / 2 - 0.03, h - 0.06), (w / 2 - 0.03, d / 2 - 0.02, h - 0.045), "emit_led_cold")
        bar_handle(t, -w / 2 + 0.08, w / 2 - 0.08, d / 2 - 0.03, h - 0.1)
    else:
        t.bx((-w / 2 + 0.01, d / 2 - 0.04, 0.06), (w / 2 - 0.01, d / 2 - 0.02, h * 0.62), "steel")
        t.bx((-w / 2 + 0.01, d / 2 - 0.04, h * 0.62 + 0.01), (w / 2 - 0.01, d / 2 - 0.02, h - 0.02), "steel")
        t.rod((w / 2 - 0.08, d / 2 - 0.02, h * 0.3), (w / 2 - 0.08, d / 2 - 0.02, h * 0.58), 0.012, "chrome", segs=8)
        t.rod((w / 2 - 0.08, d / 2 - 0.02, h * 0.66), (w / 2 - 0.08, d / 2 - 0.02, h * 0.9), 0.012, "chrome", segs=8)
    o.build()


def _cleaner_cart(k: Kit, p: dict) -> None:
    """Janitor's cart 0.89 x 0.49 x 0.99 m: a grey frame, two shelves of supplies, a yellow bag hoop, a mop bucket."""
    w, d, h = 0.89, 0.49, 0.99
    o = k.obj("Cart")
    a = o.part(bevel=0.004)
    for z in (0.12, 0.5, h - 0.03):
        a.bx((-w / 2, -d / 2, z), (w / 2 - 0.25, d / 2, z + 0.03), "plastic_grey")
    for sx in (-1, 1):
        x = -w / 2 + 0.02 if sx < 0 else w / 2 - 0.27
        for sy in (-1, 1):
            a.bx((x, sy * (d / 2 - 0.02) - 0.02, 0.06), (x + 0.04, sy * (d / 2 - 0.02) + 0.02, h), "plastic_grey")
    c = o.part(bevel=0.0)
    for x in (-w / 2 + 0.06, w / 2 - 0.08):
        for y in (-d / 2 + 0.06, d / 2 - 0.06):
            _wheel(c, x, y, 0.05)
    c.torus(0.14, 0.012, (w / 2 - 0.16, 0.0, 0.8), "plastic_grey", segs=16, rsegs=6)
    c.lathe([(0.12, 0.25), (0.135, 0.78), (0.0, 0.78)], "metal_yellow", centre=(w / 2 - 0.16, 0.0, 0.0), segs=14)
    b = o.part(bevel=0.003)
    for i in range(4):
        x = -w / 2 + 0.08 + i * 0.13
        b.lathe([(0.04, 0.0), (0.04, 0.2), (0.015, 0.26), (0.0, 0.26)], ("plastic_blue", "metal_white", "serum_green",
                "plastic_blue")[i], centre=(x, 0.0, 0.53), segs=10)
    b.bx((-w / 2 + 0.05, -0.15, 0.15), (0.05, 0.15, 0.4), "paper")
    o.build()


def _it_trolley(k: Kit, p: dict) -> None:
    """IT contractor's utility trolley 0.79 x 0.49 x 0.9 m: two grey plastic trays on steel posts and castors, a crate
    of cables and a toolbox on the lower tray; the work top (0.9) stays clear for the laptop / code note."""
    w, d, h = 0.79, 0.49, 0.9
    o = k.obj("Trolley")
    a = o.part(bevel=0.006)
    a.bx((-w / 2, -d / 2, h - 0.05), (w / 2, d / 2, h), "plastic_grey")
    a.bx((-w / 2, -d / 2, 0.2), (w / 2, d / 2, 0.25), "plastic_grey")
    c = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            c.rod((sx * (w / 2 - 0.04), sy * (d / 2 - 0.04), 0.1), (sx * (w / 2 - 0.04), sy * (d / 2 - 0.04), h - 0.05),
                  0.012, "steel", segs=8)
            _wheel(c, sx * (w / 2 - 0.06), sy * (d / 2 - 0.08), 0.05)
            c.bx((sx * (w / 2 - 0.06) - 0.02, sy * (d / 2 - 0.08) - 0.02, 0.1), (sx * (w / 2 - 0.06) + 0.02,
                 sy * (d / 2 - 0.08) + 0.02, 0.2), "metal_dark")
    b = o.part(bevel=0.004)
    b.bx((-0.34, -0.18, 0.25), (-0.02, 0.18, 0.45), "plastic_blue")
    b.bx((0.04, -0.12, 0.25), (0.34, 0.1, 0.4), "metal_red")
    b.bx((0.12, -0.05, 0.4), (0.26, 0.03, 0.43), "metal_dark")
    o.build()


# ------------------------------------------------------------------------------------------ partners' floor

def _bar(k: Kit, p: dict) -> None:
    """Lounge bar 2.99 x 0.59 x 1.1 m: a backlit glass-teal front (customer side, Blender -Y) between graphite stone
    ends, a walnut bar top over the full depth, a graphite back (the bartender's side, +Y) with a bottle shelf."""
    w, d, h = 2.99, 0.59, 1.1
    o = k.obj("Bar")
    a = o.part(bevel=0.004)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.08)))
        a.bx((x0, -d / 2, 0.0), (x1, d / 2, h - 0.04), "stone_graphite")
    a.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), "walnut")
    a.bx((-w / 2 + 0.08, -d / 2 + 0.06, 0.0), (w / 2 - 0.08, -d / 2 + 0.3, 0.06), "stone_graphite")
    a.bx((-w / 2 + 0.08, -d / 2 + 0.28, 0.0), (w / 2 - 0.08, d / 2 - 0.25, h - 0.04), "paint_graphite")
    a.bx((-w / 2 + 0.08, d / 2 - 0.25, 0.0), (w / 2 - 0.08, d / 2, 0.08), "paint_graphite")
    a.bx((-w / 2 + 0.08, d / 2 - 0.25, 0.5), (w / 2 - 0.08, d / 2 - 0.01, 0.53), "stone_graphite")
    g = o.part(bevel=0.0)
    g.bx((-w / 2 + 0.08, -d / 2 + 0.06, 0.06), (w / 2 - 0.08, -d / 2 + 0.07, h - 0.05), "emit_teal")
    g.bx((-w / 2 + 0.08, -d / 2 + 0.03, 0.06), (w / 2 - 0.08, -d / 2 + 0.04, h - 0.05), "glass_teal")
    t = o.part(bevel=0.0)
    for i in range(9):
        x = -w / 2 + 0.3 + i * 0.29
        hgt = 0.28 + (i % 3) * 0.04
        key = ("felt_dark", "glass_tinted", "brass_bronze")[i % 3]
        t.lathe([(0.04, 0.0), (0.04, hgt * 0.65), (0.014, hgt * 0.85), (0.012, hgt), (0.0, hgt)], key,
                centre=(x, d / 2 - 0.12, 0.53), segs=10)
    o.build()


def _sofa(k: Kit, p: dict) -> None:
    """Graphite leather sofa w x 0.89 x 0.79 m: low back, tight cushions, brushed steel sled legs."""
    w, d = float(p["w"]) - 0.01, 0.89
    o = k.obj("Sofa")
    soft = o.part(bevel=0.03, segments=3)
    soft.bx((-w / 2, -d / 2, 0.14), (w / 2, d / 2, 0.42), "leather_graphite")
    soft.bx((-w / 2, -d / 2, 0.42), (w / 2, -d / 2 + 0.2, 0.79), "leather_graphite")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.16)))
        soft.bx((x0, -d / 2 + 0.2, 0.42), (x1, d / 2, 0.6), "leather_graphite")
    nseat = 3 if w > 2.1 else 2
    for i in range(nseat):
        x0 = -w / 2 + 0.165 + i * (w - 0.33) / nseat
        x1 = x0 + (w - 0.33) / nseat - 0.006
        soft.bx((x0, -d / 2 + 0.21, 0.42), (x1, d / 2 - 0.02, 0.5), "leather_graphite")
    legs = o.part(bevel=0.0)
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.12)
        legs.rod((x, -d / 2 + 0.06, 0.012), (x, d / 2 - 0.06, 0.012), 0.012, "steel", segs=8)
        legs.rod((x, -d / 2 + 0.06, 0.012), (x, -d / 2 + 0.06, 0.14), 0.012, "steel", segs=8)
        legs.rod((x, d / 2 - 0.06, 0.012), (x, d / 2 - 0.06, 0.14), 0.012, "steel", segs=8)
    o.build()


def _armchair(k: Kit, p: dict) -> None:
    """Club armchair 0.79 x 0.79 x 0.79 m in cognac leather on walnut feet."""
    w, d = 0.79, 0.79
    o = k.obj("Armchair")
    soft = o.part(bevel=0.03, segments=3)
    soft.bx((-w / 2, -d / 2, 0.12), (w / 2, d / 2, 0.4), "leather_cognac")
    soft.bx((-w / 2, -d / 2, 0.4), (w / 2, -d / 2 + 0.18, 0.79), "leather_cognac")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.13)))
        soft.bx((x0, -d / 2 + 0.18, 0.4), (x1, d / 2, 0.62), "leather_cognac")
    soft.bx((-w / 2 + 0.135, -d / 2 + 0.185, 0.4), (w / 2 - 0.135, d / 2 - 0.02, 0.48), "leather_cognac")
    legs = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            legs.lathe([(0.02, 0.0), (0.026, 0.12)], "walnut", centre=(sx * (w / 2 - 0.07), sy * (d / 2 - 0.07), 0.0),
                       segs=10)
    o.build()


def _coffee_table(k: Kit, p: dict) -> None:
    """Coffee table 0.99 x 0.59 x 0.45 m: graphite stone top on a walnut frame, art books on top."""
    w, d, h = 0.99, 0.59, 0.45
    o = k.obj("Table")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h), "stone_graphite")
    legs4(a, w, d, h - 0.03, 0.03, 0.04, "walnut")
    a.bx((-w / 2 + 0.07, -d / 2 + 0.07, 0.12), (w / 2 - 0.07, d / 2 - 0.07, 0.14), "walnut")
    t = o.part(bevel=0.002)
    t.bx((-0.3, -0.15, h), (0.0, 0.08, h + 0.03), "canvas_bank")
    t.bx((-0.28, -0.13, h + 0.03), (-0.04, 0.06, h + 0.05), "paint_slate")
    t.lathe([(0.06, 0.0), (0.08, 0.04), (0.05, 0.08), (0.0, 0.08)], "ceramic", centre=(0.25, 0.05, h), segs=16)
    o.build()


def _piano(k: Kit, p: dict) -> None:
    """Baby grand piano in ebony lacquer (1.49 x 1.59 m footprint): curved case, raised lid on its stick, keyboard on
    the front (+Y), three legs, the lyre."""
    o = k.obj("Piano")
    a = o.part(bevel=0.006)
    # case outline (x, y): straight bass side (x -0.74), curved treble side, keyboard edge at y +0.5
    outline = [(-0.74, 0.5), (0.74, 0.5), (0.74, 0.2), (0.6, -0.15), (0.32, -0.45), (0.1, -0.7), (-0.2, -0.79),
               (-0.5, -0.79), (-0.74, -0.7)]
    a.slab(outline, 0.66, 0.98, "car_black")
    a.bx((-0.74, 0.5, 0.66), (0.74, 0.79, 0.74), "car_black")
    a.bx((-0.74, 0.5, 0.74), (-0.66, 0.79, 0.9), "car_black")
    a.bx((0.66, 0.5, 0.74), (0.74, 0.79, 0.9), "car_black")
    a.bx((-0.66, 0.5, 0.86), (0.66, 0.56, 0.98), "car_black")
    k_ = o.part(bevel=0.0)
    k_.bx((-0.64, 0.56, 0.74), (0.64, 0.76, 0.76), "ceramic")
    for i in range(36):
        if i % 7 in (2, 6):
            continue
        x = -0.62 + i * 0.035
        k_.bx((x, 0.62, 0.76), (x + 0.012, 0.76, 0.775), "car_black")
    legs = o.part(bevel=0.0)
    for (x, y) in ((-0.62, 0.62), (0.62, 0.62), (-0.3, -0.62)):
        legs.lathe([(0.04, 0.0), (0.05, 0.05), (0.06, 0.6), (0.07, 0.66)], "car_black", centre=(x, y, 0.0), segs=12)
        legs.cyl(0.03, 0.02, (x, y, 0.01), "brass", segs=10)
    legs.bx((-0.08, 0.2, 0.06), (0.08, 0.24, 0.66), "car_black")
    lid = o.part(bevel=0.004)
    lid.slab([(-0.72, 0.42), (0.72, 0.42), (0.72, 0.2), (0.58, -0.15), (0.3, -0.45), (0.08, -0.68), (-0.72, -0.68)],
             0.98, 0.995, "car_black")
    legs.rod((0.45, -0.1, 0.995), (0.45, -0.1, 0.995 + 0.003), 0.006, "brass", segs=6)
    o.build()


def _plinth(k: Kit, p: dict) -> None:
    """Gallery plinth 0.59 x 0.59 m: a graphite stone block (0.85 m) with a small bronze / ceramic abstract on top,
    within 1.09 m."""
    form = p["form"]
    o = k.obj("Plinth")
    a = o.part(bevel=0.004)
    a.bx((-0.295, -0.295, 0.0), (0.295, 0.295, 0.85), "stone_graphite")
    a.bx((-0.28, -0.28, 0.0), (0.28, 0.28, 0.02), "metal_dark")
    s = o.part(bevel=0.0)
    if form == "a":
        s.lathe([(0.08, 0.0), (0.1, 0.03), (0.06, 0.08), (0.11, 0.16), (0.04, 0.22), (0.0, 0.24)], "brass_bronze",
                centre=(0.0, 0.0, 0.85), segs=20)
    else:
        s.torus(0.09, 0.03, (0.0, 0.0, 0.97), "ceramic", segs=20, rsegs=8, axis="Y")
        s.bx((-0.06, -0.04, 0.85), (0.06, 0.04, 0.88), "metal_dark")
    o.build()


def _bed(k: Kit, p: dict) -> None:
    """Queen bed 1.79 wide x 2.09 long (Blender Y; headboard at -Y), mattress top 0.6: graphite upholstered frame,
    linen bedding with a teal throw, two pillows, an upholstered headboard to 1.0 m."""
    w, d = 1.79, 2.09
    o = k.obj("Bed")
    a = o.part(bevel=0.02, segments=2)
    a.bx((-w / 2, -d / 2 + 0.1, 0.08), (w / 2, d / 2, 0.36), "fabric_graphite")
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, -d / 2 + 0.1, 1.0), "fabric_graphite")
    soft = o.part(bevel=0.03, segments=3)
    soft.bx((-w / 2 + 0.03, -d / 2 + 0.11, 0.36), (w / 2 - 0.03, d / 2 - 0.02, 0.56), "linen_white")
    soft.bx((-w / 2 + 0.01, -d / 2 + 0.5, 0.5), (w / 2 - 0.01, d / 2, 0.6), "linen_white")
    soft.bx((-w / 2 + 0.02, d / 2 - 0.55, 0.6 - 0.002), (w / 2 - 0.02, d / 2 - 0.15, 0.6 + 0.0), "fabric_teal")
    for sx in (-1, 1):
        soft.bx((sx * 0.42 - 0.33, -d / 2 + 0.13, 0.5), (sx * 0.42 + 0.33, -d / 2 + 0.45, 0.6), "linen_white")
    legs = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            legs.bx((sx * (w / 2 - 0.08) - 0.03, sy * (d / 2 - 0.12) - 0.03, 0.0), (sx * (w / 2 - 0.08) + 0.03,
                    sy * (d / 2 - 0.12) + 0.03, 0.08), "walnut")
    o.build()


def _nightstand(k: Kit, p: dict) -> None:
    """Nightstand 0.44 x 0.49 x 0.59 m (front +Y): walnut, two drawers, a stone top."""
    w, d, h = 0.44, 0.49, 0.595
    o = k.obj("Nightstand")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -d / 2, 0.06), (w / 2, d / 2 - 0.015, h - 0.02), "walnut")
    a.bx((-w / 2, -d / 2, h - 0.02), (w / 2, d / 2, h), "stone_graphite")
    legs4(a, w, d - 0.015, 0.06, 0.02, 0.03, "metal_dark")
    t = o.part(bevel=0.002)
    for i in range(2):
        z0 = 0.09 + i * 0.24
        t.bx((-w / 2 + 0.02, d / 2 - 0.015, z0), (w / 2 - 0.02, d / 2 - 0.005, z0 + 0.22), "walnut")
        t.bx((-0.06, d / 2 - 0.005, z0 + 0.15), (0.06, d / 2 + 0.008, z0 + 0.165), "brass")
    o.build()


def _wardrobe(k: Kit, p: dict) -> None:
    """Fitted wardrobe w x d x 2.0 m: walnut doors with full-height brass pulls, a plinth and a cornice."""
    w, d, h = float(p["w"]) - 0.01, float(p["d"]) - 0.03, 1.995  # the pulls stay inside the layout box
    o = k.obj("Wardrobe")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, 0.08), (w / 2, d / 2 - 0.02, h - 0.04), "walnut")
    a.bx((-w / 2 + 0.02, -d / 2, 0.0), (w / 2 - 0.02, d / 2 - 0.05, 0.08), "metal_dark")
    a.bx((-w / 2, -d / 2, h - 0.04), (w / 2, d / 2, h), "walnut")
    t = o.part(bevel=0.002)
    n = 3 if w > 1.2 else 2
    for i in range(n):
        x0 = -w / 2 + 0.005 + i * (w - 0.01) / n
        x1 = x0 + (w - 0.01) / n - 0.006
        t.bx((x0, d / 2 - 0.02, 0.1), (x1, d / 2 - 0.004, h - 0.06), "walnut")
        hx = x1 - 0.04 if i % 2 == 0 else x0 + 0.04
        t.bx((hx - 0.007, d / 2 - 0.004, 0.7), (hx + 0.007, d / 2 + 0.012, 1.5), "brass")
    o.build()


# ------------------------------------------------------------------------------------------ terrace and roof

def _planter(k: Kit, p: dict) -> None:
    """Terrace planter 2.99 x 0.79 m: a graphite fibre-cement trough (0.6 m), soil, clipped box shrubs and ornamental
    grass within 0.9 m."""
    w, d = 2.99, 0.79
    o = k.obj("Planter")
    a = o.part(bevel=0.008)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, -d / 2 + 0.05, 0.6), "stone_graphite")
    a.bx((-w / 2, d / 2 - 0.05, 0.0), (w / 2, d / 2, 0.6), "stone_graphite")
    a.bx((-w / 2, -d / 2 + 0.05, 0.0), (-w / 2 + 0.05, d / 2 - 0.05, 0.6), "stone_graphite")
    a.bx((w / 2 - 0.05, -d / 2 + 0.05, 0.0), (w / 2, d / 2 - 0.05, 0.6), "stone_graphite")
    a.bx((-w / 2 + 0.05, -d / 2 + 0.05, 0.0), (w / 2 - 0.05, d / 2 - 0.05, 0.53), "soil")
    s = o.part(bevel=0.0)
    for i in range(4):
        cx = -w / 2 + 0.4 + i * 0.73
        s.sphere(0.24, (cx, 0.0, 0.66), "leaf_dark", segs=12, rings=6, scale=(1.0, 1.0, 0.85))
    for i in range(3):
        cx = -w / 2 + 0.77 + i * 0.73
        for j in range(7):
            ang = j * 0.9
            s.leaf((cx, 0.0, 0.53), (cx + math.cos(ang) * 0.12, math.sin(ang) * 0.12, 0.88), 0.03, "leaf")
    o.build()


def _lounger(k: Kit, p: dict) -> None:
    """Teak sun lounger 0.69 x 1.89 m (backrest at -Y raised, 0.4 m frame), a graphite cushion."""
    w, d = 0.69, 1.89
    o = k.obj("Lounger")
    a = o.part(bevel=0.004)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * w / 2, sx * (w / 2 - 0.04)))
        a.bx((x0, -d / 2, 0.2), (x1, d / 2, 0.26), "teak")
        for y in (-d / 2 + 0.08, d / 2 - 0.08):
            a.bx((x0, y - 0.03, 0.0), (x1, y + 0.03, 0.2), "teak")
    for i in range(12):
        y = -d / 2 + 0.62 + i * 0.105
        if y > d / 2 - 0.06:
            break
        a.bx((-w / 2 + 0.04, y, 0.24), (w / 2 - 0.04, y + 0.08, 0.27), "teak")
    soft = o.part(bevel=0.02, segments=2)
    soft.bx((-w / 2 + 0.05, -d / 2 + 0.62, 0.27), (w / 2 - 0.05, d / 2 - 0.05, 0.33), "fabric_graphite")
    soft.profile_x([(-d / 2 + 0.05, 0.27), (-d / 2 + 0.6, 0.27), (-d / 2 + 0.6, 0.33), (-d / 2 + 0.18, 0.395),
                    (-d / 2 + 0.05, 0.395)], -w / 2 + 0.05, w / 2 - 0.05, "fabric_graphite")
    o.build()


def _heater(k: Kit, p: dict) -> None:
    """Slim pyramid patio heater 0.49 x 0.49 x 2.19 m: a graphite square base and top cap, a glass flame tube (off),
    four corner posts."""
    o = k.obj("Heater")
    a = o.part(bevel=0.004)
    a.bx((-0.245, -0.245, 0.0), (0.245, 0.245, 0.45), "metal_graphite")
    a.bx((-0.2, -0.2, 1.95), (0.2, 0.2, 2.19), "metal_graphite")
    t = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            t.rod((sx * 0.17, sy * 0.17, 0.45), (sx * 0.17, sy * 0.17, 1.95), 0.012, "metal_dark", segs=6)
    t.cyl(0.07, 1.5, (0.0, 0.0, 1.2), "glass_tinted", segs=16)
    o.build()


def _ahu(k: Kit, p: dict) -> None:
    """Roof air-handling unit 2.39 x 1.59 x 2.19 m: graphite panelled casing, louvred intake, two fan hoods."""
    w, d, h = 2.37, 1.57, 2.19
    o = k.obj("Ahu")
    a = o.part(bevel=0.006)
    a.bx((-w / 2, -d / 2, 0.15), (w / 2, d / 2, h - 0.25), "metal_grey")
    a.bx((-w / 2 + 0.05, -d / 2 + 0.05, 0.0), (w / 2 - 0.05, d / 2 - 0.05, 0.15), "steel_galv")
    t = o.part(bevel=0.0)
    for i in range(4):
        x0 = -w / 2 + 0.05 + i * (w - 0.1) / 4
        t.bx((x0, d / 2, 0.25), (x0 + (w - 0.1) / 4 - 0.03, d / 2 + 0.006, h - 0.35), "metal_grey")
        t.bx((x0 + 0.05, d / 2 + 0.006, 1.0), (x0 + 0.07, d / 2 + 0.02, 1.2), "steel")
    for j in range(10):
        z = 0.3 + j * 0.12
        t.bx((-w / 2 - 0.006, -d / 2 + 0.15, z), (-w / 2, d / 2 - 0.15, z + 0.06), "steel_galv")
    for sx in (-0.55, 0.55):
        t.cyl(0.38, 0.25, (sx, 0.0, h - 0.125), "steel_galv", segs=24)
        t.cyl(0.33, 0.02, (sx, 0.0, h - 0.0), "metal_dark", segs=24)
    o.build()


def _chiller(k: Kit, p: dict) -> None:
    """Air-cooled chiller 2.19 x 1.39 x 1.99 m: V-coil louvres on both long sides, three fans on top."""
    w, d, h = 2.19, 1.39, 1.99
    o = k.obj("Chiller")
    a = o.part(bevel=0.005)
    a.bx((-w / 2, -d / 2, 0.1), (w / 2, d / 2, 0.7), "metal_white")
    a.bx((-w / 2, -d / 2, 0.7), (w / 2, d / 2, h - 0.12), "metal_white")
    a.bx((-w / 2 + 0.05, -d / 2 + 0.05, 0.0), (w / 2 - 0.05, d / 2 - 0.05, 0.1), "steel_galv")
    t = o.part(bevel=0.0)
    for sy in (-1, 1):
        for j in range(9):
            z = 0.78 + j * 0.11
            y0, y1 = sorted((sy * d / 2, sy * (d / 2 + 0.006)))
            t.bx((-w / 2 + 0.06, y0, z), (w / 2 - 0.06, y1, z + 0.05), "metal_grey")
    for i in range(3):
        cx = -w / 2 + (i + 0.5) * w / 3
        t.cyl(0.32, 0.12, (cx, 0.0, h - 0.06), "metal_dark", segs=24)
        for b in range(5):
            ang = b * 2 * math.pi / 5
            t.bx((cx + math.cos(ang) * 0.12 - 0.015, math.sin(ang) * 0.12 - 0.015, h - 0.03),
                 (cx + math.cos(ang) * 0.12 + 0.015, math.sin(ang) * 0.12 + 0.015, h), "steel_galv")
    o.build()


def _tank(k: Kit, p: dict) -> None:
    """Sectional water tank 1.59 x 1.59 x 2.19 m: galvanised flanged panels (a grid of ribs), a top hatch, a ladder
    bracket."""
    w, h = 1.55, 2.19
    o = k.obj("Tank")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -w / 2, 0.12), (w / 2, w / 2, h - 0.05), "steel_galv")
    a.bx((-w / 2 + 0.05, -w / 2 + 0.05, 0.0), (w / 2 - 0.05, w / 2 - 0.05, 0.12), "metal_dark")
    t = o.part(bevel=0.0)
    for i in range(1, 3):
        c = -w / 2 + i * w / 3
        for sy in (-1, 1):
            y0, y1 = sorted((sy * w / 2, sy * (w / 2 + 0.02)))
            t.bx((c - 0.015, y0, 0.12), (c + 0.015, y1, h - 0.05), "steel_galv")
            x0, x1 = sorted((sy * w / 2, sy * (w / 2 + 0.02)))
            t.bx((x0, c - 0.015, 0.12), (x1, c + 0.015, h - 0.05), "steel_galv")
    for z in (0.8, 1.45):
        for sy in (-1, 1):
            y0, y1 = sorted((sy * w / 2, sy * (w / 2 + 0.02)))
            t.bx((-w / 2, y0, z - 0.015), (w / 2, y1, z + 0.015), "steel_galv")
    t.bx((-0.3, -0.3, h - 0.05), (0.3, 0.3, h), "metal_grey")
    o.build()


def _lift_motors(k: Kit, p: dict) -> None:
    """Lift traction machines 1.99 x 1.19 x 1.19 m: two geared motors with sheaves on a bedplate, a controller box."""
    w, d = 1.99, 1.19
    o = k.obj("Motors")
    a = o.part(bevel=0.004)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.15), "metal_dark")
    for sx in (-1, 1):
        cx = sx * 0.5
        a.bx((cx - 0.35, -0.35, 0.15), (cx + 0.1, 0.35, 0.65), "metal_green")
        a.cyl(0.25, 0.4, (cx - 0.12, 0.0, 0.62), "metal_green", axis="X", segs=20)
    t = o.part(bevel=0.0)
    for sx in (-1, 1):
        t.cyl(0.3, 0.12, (sx * 0.5 + 0.22, 0.0, 0.5), "steel", axis="X", segs=24)
        for g in range(4):
            t.torus(0.3, 0.008, (sx * 0.5 + 0.18 + g * 0.025, 0.0, 0.5), "metal_dark", segs=24, rsegs=4, axis="X")
    t.bx((-0.25, d / 2 - 0.25, 0.15), (0.25, d / 2 - 0.02, 1.19), "metal_grey")
    t.bx((-0.15, d / 2 - 0.02, 0.85), (0.15, d / 2 - 0.01, 1.05), "plastic_black")
    t.bx((-0.08, d / 2 - 0.01, 0.95), (-0.06, d / 2 - 0.005, 0.97), "emit_led_green")
    o.build()


def _bmu(k: Kit, p: dict) -> None:
    """Building maintenance unit 2.99 x 1.59 x 2.49 m parked on its rail: a white trolley chassis on bogies, the
    counterweight, the slewing column and a folded jib, an amber beacon (off)."""
    w, d, h = 2.99, 1.59, 2.49
    o = k.obj("Bmu")
    a = o.part(bevel=0.006)
    a.bx((-w / 2, -d / 2, 0.2), (w / 2, d / 2, 0.75), "metal_white")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * (w / 2 - 0.1), sx * (w / 2 - 0.6)))
        a.bx((x0, -d / 2 + 0.1, 0.0), (x1, d / 2 - 0.1, 0.2), "metal_dark")
    a.bx((0.4, -d / 2 + 0.1, 0.75), (w / 2 - 0.1, d / 2 - 0.1, 1.3), "metal_grey")
    a.cyl(0.3, 1.2, (-0.6, 0.0, 1.35), "metal_white", segs=20)
    a.bx((-w / 2 + 0.05, -0.15, 1.95), (w / 2 - 0.05, 0.15, 2.25), "metal_white")
    t = o.part(bevel=0.0)
    t.bx((-0.85, -0.2, 2.25), (-0.35, 0.2, 2.35), "metal_dark")
    t.lathe([(0.07, 0.0), (0.06, 0.1), (0.0, 0.12)], "emit_amber", centre=(-0.6, 0.0, 2.35), segs=12)
    for i in range(6):
        x = -w / 2 + 0.2 + i * 0.5
        t.rod((x, -0.15, 1.95), (x + 0.25, 0.15, 2.25), 0.012, "metal_grey", segs=6)
    o.build()


def _garage(k: Kit, p: dict) -> None:
    """Cradle garage 2.99 x 2.39 x 2.19 m: a graphite steel enclosure with a roller front (+Y), a pent roof."""
    w, d, h = 2.99, 2.39, 2.19
    o = k.obj("Garage")
    a = o.part(bevel=0.005)
    a.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2 - 0.06, h - 0.1), "metal_graphite")
    a.profile_x([(-d / 2 - 0.0, h - 0.1), (d / 2, h - 0.1), (d / 2, h - 0.04), (-d / 2, h)], -w / 2, w / 2,
                "metal_graphite")
    t = o.part(bevel=0.0)
    for i in range(18):
        z = 0.05 + i * 0.1
        t.bx((-w / 2 + 0.1, d / 2 - 0.06, z), (w / 2 - 0.1, d / 2 - 0.02, z + 0.08), "steel_galv")
    t.bx((-w / 2 + 0.05, d / 2 - 0.06, 1.85), (w / 2 - 0.05, d / 2 - 0.01, h - 0.1), "metal_dark")
    for i in range(6):
        x = -w / 2 + 0.25 + i * 0.5
        for sy in (-1,):
            t.bx((x, sy * d / 2 - 0.0, 0.3), (x + 0.03, sy * d / 2 + 0.02, h - 0.2), "metal_dark")
    o.build()


def _anchor_frame(k: Kit, p: dict) -> None:
    """Line anchor frame 0.59 x 0.59 x h: a galvanised A-frame on a ballast plate with an eye and a shackle."""
    h = float(p["h"]) - 0.01
    o = k.obj("Anchor")
    a = o.part(bevel=0.004)
    a.bx((-0.295, -0.295, 0.0), (0.295, 0.295, 0.08), "metal_dark")
    t = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            t.rod((sx * 0.25, sy * 0.25, 0.08), (0.0, 0.0, h - 0.08), 0.025, "steel_galv", segs=8)
    t.cyl(0.05, 0.12, (0.0, 0.0, h - 0.07), "steel_galv", segs=12)
    t.torus(0.04, 0.01, (0.0, 0.0, h - 0.05), "steel", segs=12, rsegs=4, axis="Y")
    o.build()


# ------------------------------------------------------------------------------------------ fixtures

def _led_linear(k: Kit, p: dict) -> None:
    """Recessed-look linear LED 1.2 x 0.08 m (top at z 0): a graphite channel, a 6500 K opal diffuser."""
    o = k.obj("Linear")
    a = o.part(bevel=0.0)
    a.bx((-0.6, -0.04, -0.03), (0.6, 0.04, 0.0), "metal_graphite")
    a.bx((-0.58, -0.025, -0.036), (0.58, 0.025, -0.03), "emit_led_cold")
    o.build()


def _picture_light(k: Kit, p: dict) -> None:
    """Brass picture light (wall mount, back at y 0, centred on z 0): a round backplate, a swan arm and a 0.4 m hood
    over a warm LED strip."""
    o = k.obj("PictureLight")
    a = o.part(bevel=0.0)
    a.cyl(0.04, 0.012, (0.0, 0.006, 0.0), "brass", axis="Y", segs=16)
    a.tube([(0.0, 0.012, 0.0), (0.0, 0.12, 0.05), (0.0, 0.24, 0.02)], 0.008, "brass", segs=8)
    a.profile_x([(0.2, 0.05), (0.3, 0.0), (0.31, -0.02), (0.29, -0.02), (0.2, 0.025)], -0.2, 0.2, "brass")
    a.bx((-0.18, 0.27, -0.022), (0.18, 0.29, -0.018), "emit_warm")
    o.build()


def _bollard(k: Kit, p: dict) -> None:
    """Terrace LED bollard 0.15 x 0.15 x 0.8 m: a graphite square post with a frosted 6500 K head."""
    o = k.obj("Bollard")
    a = o.part(bevel=0.003)
    a.bx((-0.075, -0.075, 0.0), (0.075, 0.075, 0.62), "metal_graphite")
    a.bx((-0.075, -0.075, 0.78), (0.075, 0.075, 0.8), "metal_graphite")
    t = o.part(bevel=0.0)
    t.bx((-0.065, -0.065, 0.62), (0.065, 0.065, 0.78), "emit_led_cold")
    o.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
    cat = ctx.params["cat"]
    if cat.get("place") in ("ceiling", "wall_mount") or cat.get("fixture"):
        return
    # Floor props: a box collider over the model (support props up to their work top). The map's own colliders
    # replace it where the generator instances an SL prop over a layout box (sl_builder_base._art_visual).
    import bpy  # noqa: PLC0415  (Blender only)
    from lib import geo, naming  # noqa: PLC0415
    objs = sorted((o for o in bpy.data.objects if o.type == "MESH" and not naming.is_collision_name(o.name)),
                  key=lambda o: o.name)
    lo, hi = geo.bounds(objs)
    top = float(cat.get("top", 0.0)) or hi[2]
    k.collision([((lo[0], lo[1], lo[2]), (hi[0], hi[1], min(top, hi[2])))])
