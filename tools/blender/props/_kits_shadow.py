"""Shadow Ledger dressing kits (SL-1, docs/design/heists/shadow_ledger.md room list), merged into _kits.py.

Kinds the map builds itself (shadow_ledger_layout.gd PROPS / CHAIRS: desks, tables, credenzas, shelving, the
racks, beds, wardrobes, the bar, the roof plant ...) are listed as required so the density check sees the room
complete; the generator (sl_dress.gd) enters them as virtual anchors, so KitPlacer counts them, puts its "on" items
on them and adds no second desk. Fixture grids follow the doc's zones: executive spaces 3000 K downlights (pools,
the coves are the map's linear LEDs), offices and corridors 4000 K panels (night level, sl_dressing LIGHT_TWEAKS),
back of house 5000 K panels, the server room 6500 K.
"""

from __future__ import annotations

DESK_CLUTTER = {"anchors": ["desk"], "items": {"papers": 3, "mug": 1.5, "pen_cup": 1, "binders": 1, "notebook": 1,
                                               "desk_phone": 0.5}, "count": (1, 3), "radius": 0.6}
EXEC_DESK = {"anchors": ["desk"], "items": {"papers": 2, "notebook": 1.5, "pen_cup": 1, "desk_lamp": 1.5},
             "count": (1, 2), "radius": 0.6}
TABLE_CLUTTER = {"anchors": ["table"], "items": {"papers": 2, "notebook": 1.5, "mug": 1, "glassware": 1},
                 "count": (1, 3), "radius": 0.5}
COUNTER = {"anchors": ["kitchen_counter"], "items": {"mug": 3, "bottles": 1.5, "kettle": 0.8, "glassware": 1},
           "count": (1, 3), "radius": 0.5}
FLOOR_OFFICE = {"anchors": ["wall", "door"], "items": {"bin": 2, "box": 1}, "count": (0, 1), "radius": 0.8}
# SL-1 polish: a four-seat bench pod carries a working day's clutter (the LEAD's G2 review: the pods read bare)
POD_CLUTTER = {"anchors": ["desk"], "items": {"papers": 3, "mug": 2, "pen_cup": 1, "binders": 1.5, "notebook": 1,
                                              "desk_phone": 1, "desk_lamp": 0.4, "plant_small": 0.6},
               "count": (4, 7), "radius": 1.1}
ART = ["prop_wall_art_a", "prop_wall_art_c", "prop_wall_art_b"]
OFFICE = {"picture": ART, "plant": ["prop_plant_tall"], "bin": ["prop_bin_office"], "light_fixture": ["prop_ceiling_panel_neutral"],
          "fire_extinguisher": ["prop_fire_extinguisher"], "rug": ["prop_rug_rect"]}
EXEC = {**OFFICE, "light_fixture": ["prop_downlight"]}
BOH = {"picture": ["prop_notice_frame"], "light_fixture": ["prop_ceiling_panel_cool"], "bin": ["prop_bin_office"]}

SHADOW_KITS: dict[str, dict] = {
    # ---- L40 service level
    "service_lobby": {
        "purpose": "lobby", "min_density": 0.15, "max_density": 1.2, "min_props": 10, "salt": 301,
        "required": ["cart", "lectern", "bulletin_board", "fire_extinguisher", "light_fixture", "mail_bins",
                     "cleaning_cart"],
        "optional": {"cart": 2, "picture": 1.5, "bin": 0.8, "switch": 0.6, "box": 1},
        "counts": {"picture": (2, 3), "box": (1, 2)},
        "assets": {**BOH, "cart": ["prop_mail_trolley"], "lectern": ["prop_lectern_signin"],
                   "mail_bins": ["prop_mail_bins"], "cleaning_cart": ["prop_cleaner_cart"], "box": ["prop_box_stack"]},
        "ceiling": {"prop_ceiling_panel_cool": 2.6},
        "lone_ok": ["cart", "lectern", "mail_bins", "cleaning_cart", "box"],
        "notes": "S1 service lift lobby (PUBLIC): the freight dolly and the contractor sign-in lectern are map-built; "
                 "the kit adds the post room's mail trolley and bin rack, a parked cleaner's cart, flattened boxes and "
                 "framed notices (SL-1 polish). The lift car opening, the sealed fire door and the service spawns stay "
                 "clear. 5000 K panels.",
    },
    "refuse_room": {
        "purpose": "storage", "min_density": 0.15, "max_density": 1.2, "min_props": 4, "salt": 302,
        "required": ["cage", "fire_extinguisher", "light_fixture"],
        "optional": {"box": 1.5, "bin": 1},
        "assets": {**BOH, "cage": ["prop_recycling_cage"], "box": ["prop_box_stack"], "bin": ["prop_bin_kitchen"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "lone_ok": ["cage", "box", "bin"],
        "notes": "S2 refuse: the two wheelie bins are body_container prefabs (keep-outs), the recycling cage is "
                 "map-built; flattened boxes by the door. Fluorescents.",
    },
    "corridor_spine_sl": {
        "purpose": "corridor", "min_density": 0.05, "max_density": 1.2, "min_props": 12, "salt": 311,
        "required": ["fire_extinguisher", "light_fixture", "picture", "door_sign"],
        "optional": {"picture": 2, "bulletin_board": 0.5, "switch": 1.0, "thermostat": 0.4, "outlet": 0.6},
        "counts": {"picture": (4, 6), "door_sign": (1, 13)},
        "assets": {"picture": ["prop_notice_frame", "prop_wall_art_a", "prop_notice_frame", "prop_wall_art_b"],
                   "door_sign": ["prop_door_sign"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 3.0},
        "lone_ok": ["bench", "cart"],
        "notes": "K16 south spine (C2, 36 m): room signs beside its doors (anchors from sl_dress), framed notices and "
                 "art; the floor stays clear but for a bench by K8 and a parked mail trolley by K13 (direct props, "
                 "against the wall, off the patrol line and the door clear zones). SL-1 polish.",
    },
    # ---- L41 offices
    "office_partner": {
        "purpose": "office", "min_density": 0.2, "max_density": 1.2, "min_props": 10, "salt": 303,
        "required": ["desk", "chair", "picture", "plant", "bookshelf", "light_fixture"],
        "optional": {"picture": 1, "floor_lamp": 0.8, "rug": 0.8, "side_table": 0.5, "credenza": 0.3},
        "counts": {"picture": (2, 3)},
        "assets": {**EXEC, "bookshelf": ["prop_bookcase_w160"], "credenza": ["prop_credenza_w200"]},
        "ceiling": {"prop_downlight": 2.4},
        "clutter": {"desk": EXEC_DESK},
        "lone_ok": ["plant", "floor_lamp", "sofa", "table"],
        "notes": "K1 Kessler / K5 Moor: the walnut desk, chair, credenza, sofa, shelves or meeting table are map-built "
                 "(the laptop, keycard and planner slots stay clear). Downlight pools, art, plants, a desk lamp.",
    },
    "conference_room": {
        "purpose": "office", "min_density": 0.3, "max_density": 1.2, "min_props": 10, "salt": 304,
        "required": ["table", "chair", "credenza", "picture", "light_fixture"],
        "optional": {"picture": 1, "plant": 1.5},
        "assets": {**EXEC},
        "ceiling": {"prop_downlight": 2.0},
        "clutter": {"table": TABLE_CLUTTER},
        "lone_ok": ["plant"],
        "notes": "K2: the 3.6 m conference table, six chairs and the credenza are map-built (frosted front).",
    },
    "reception_exec": {
        "purpose": "lobby", "min_density": 0.08, "max_density": 0.6, "min_props": 8, "salt": 305,
        "required": ["counter_transaction", "armchair", "side_table", "light_fixture"],
        "optional": {"plant": 2, "rug": 0.8, "floor_lamp": 0.5},
        "assets": {**EXEC, "side_table": ["prop_side_table"]},
        "ceiling": {"prop_downlight": 2.6},
        "lone_ok": ["plant", "armchair", "side_table", "floor_lamp", "counter_transaction"],
        "notes": "K3 (landmark): reception desk with the guard post, the club chairs, the K&M logo wall and the "
                 "feature stair are map-built; the lift doors, the stair foot and the glass doors stay clear.",
    },
    "office_small": {
        "purpose": "office", "min_density": 0.3, "max_density": 1.6, "min_props": 6, "salt": 306,
        "required": ["desk", "chair", "file_cabinet", "picture", "light_fixture"],
        "optional": {"plant": 1, "bookshelf": 0.8, "bin": 1},
        "assets": {**OFFICE},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"desk": DESK_CLUTTER, "floor": FLOOR_OFFICE},
        "lone_ok": ["plant", "file_cabinet", "bookshelf"],
        "notes": "K4 assistant, K20-K23 associates: the desks and chairs are map-built. 4000 K panels at night level.",
    },
    "office_open_law": {
        "purpose": "office", "min_density": 0.2, "max_density": 1.2, "min_props": 16, "salt": 307,
        "required": ["desk", "chair", "monitor", "keyboard", "printer", "file_cabinet", "water_cooler", "plant",
                     "whiteboard", "light_fixture"],
        "optional": {"plant": 1, "picture": 1, "bin": 1, "coat_rail": 0.6, "printer": 1.2, "file_cabinet": 1.5,
                     "bulletin_board": 0.6, "box": 0.5},
        "counts": {"monitor": (10, 12), "keyboard": (8, 12), "file_cabinet": (3, 4), "printer": (2, 2)},
        "assets": {**OFFICE, "printer": ["prop_printer_mfp"], "whiteboard": ["prop_whiteboard"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.6},
        "clutter": {"desk": POD_CLUTTER, "floor": FLOOR_OFFICE},
        "lone_ok": ["plant", "water_cooler", "printer", "coat_rail", "file_cabinet"],
        "notes": "K8 associates' open plan: three map-built four-seat bench pods (12 chairs, fabric spine screens) and "
                 "the printer; the kit puts screens, keyboards and a working day's clutter on the pods, a second "
                 "printer, cabinets, a whiteboard, a cooler, plants. C11 sightlines stay clear.",
    },
    "office_it": {
        "purpose": "office", "min_density": 0.3, "max_density": 1.6, "min_props": 8, "salt": 308,
        "required": ["desk", "chair", "monitor", "keyboard", "shelving", "light_fixture"],
        "optional": {"file_cabinet": 1, "box": 1, "bin": 1, "picture": 0.5},
        "counts": {"monitor": (2, 3)},
        "assets": {**OFFICE},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"desk": DESK_CLUTTER, "floor": {"anchors": ["wall"], "items": {"box": 2}, "count": (1, 2),
                                                    "radius": 0.8}},
        "lone_ok": ["shelving", "file_cabinet"],
        "notes": "K12 IT: two map-built desks and the spares shelving; screens, keyboards, boxes of spares. The "
                 "vision panel to K11 and the kc_it / whiteboard spots stay clear.",
    },
    "server_room_sl": {
        "purpose": "server_room", "min_density": 0.15, "max_density": 1.2, "min_props": 5, "salt": 309,
        "required": ["server_rack", "ups", "crac", "fire_extinguisher", "light_fixture"],
        "optional": {"box": 0.5},
        "assets": {"light_fixture": ["prop_ceiling_panel_cool"], "box": ["prop_box_stack"]},
        "ceiling": {"prop_ceiling_panel_cool": 2.2},
        "lone_ok": ["server_rack", "ups", "crac", "box"],
        "notes": "K11: the cage (ledger rack, hack terminal, drive sleds), the CRAC and the UPS are map-built; the "
                 "cage gate, the server door swing and the contractor spot stay clear. 6500 K, rack LEDs.",
    },
    "security_office_sl": {
        "purpose": "security_room", "min_density": 0.3, "max_density": 1.8, "min_props": 7, "salt": 310,
        "required": ["key_cabinet", "lockers", "counter_service", "bulletin_board", "fire_extinguisher", "light_fixture"],
        "optional": {"bin": 1, "file_cabinet": 0.5},
        "assets": {**BOH, "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.2},
        "clutter": {"counter": {"anchors": ["counter_service"], "items": {"mug": 2, "papers": 1}, "count": (1, 2),
                                "radius": 0.5}},
        "lone_ok": ["lockers", "key_cabinet", "counter_service"],
        "notes": "K13: the camera station (monitor wall on the east wall, the operator facing it) is a prefab; key "
                 "cabinet, counter and lockers are map-built. Dim panels (monitor glow carries the room).",
    },
    "copy_room": {
        "purpose": "storage", "min_density": 0.3, "max_density": 1.6, "min_props": 5, "salt": 311,
        "required": ["copier", "shelving", "box", "light_fixture"],
        "optional": {"file_cabinet": 1, "bin": 1},
        "assets": {**OFFICE, "shelving": ["prop_shelving_boxes"], "box": ["prop_box_stack"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "lone_ok": ["copier", "shelving", "box", "file_cabinet"],
        "notes": "K15 copy and mail: the copier is map-built; paper stock shelving, cartons, a cabinet.",
    },
    "archive_records": {
        "purpose": "storage", "min_density": 0.2, "max_density": 1.4, "min_props": 6, "salt": 312,
        "required": ["shelving", "archive_box", "step_ladder", "light_fixture"],
        "optional": {"archive_box": 1, "box": 1, "file_cabinet": 1},
        "assets": {"light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "lone_ok": ["shelving", "archive_box", "step_ladder", "file_cabinet", "box"],
        "notes": "K17 records archive: two map-built compact shelving runs, the document safe (prefab, keep-out); "
                 "archive boxes, a step ladder, a plan cabinet.",
    },
    "break_room_office": {
        "purpose": "break_room", "min_density": 0.3, "max_density": 1.8, "min_props": 12, "salt": 313,
        "required": ["fridge", "kitchen_counter", "microwave", "coffee_machine", "table", "chair", "bulletin_board",
                     "light_fixture"],
        "optional": {"wall_cabinet": 1.5, "water_cooler": 1, "bin": 1, "plant": 0.5},
        "assets": {"bin": ["prop_bin_kitchen"], "plant": ["prop_plant_tall"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.3},
        "clutter": {"counter": COUNTER},
        "lone_ok": ["plant", "water_cooler"],
        "notes": "K18 break room / M11 pantry: counter with sink, fridge, table and chairs are map-built; microwave, "
                 "coffee, kettle on the counter, wall cabinets, the bulletin board. 3500 K.",
    },
    "library_law": {
        "purpose": "office", "min_density": 0.2, "max_density": 1.2, "min_props": 6, "salt": 314,
        "required": ["bookshelf", "picture", "light_fixture"],
        "optional": {"table": 3, "chair": 2, "plant": 1, "picture": 0.5},
        "counts": {"chair": (2, 2)},
        "assets": {**EXEC, "table": ["prop_consult_table"], "chair": ["prop_chair_consult"]},
        "ceiling": {"prop_downlight": 2.2},
        "clutter": {"table": TABLE_CLUTTER},
        "lone_ok": ["bookshelf", "plant", "table"],
        "notes": "K19 law library: two map-built double-sided stacks; a reading table with chairs north of them.",
    },
    "meeting_small": {
        "purpose": "office", "min_density": 0.2, "max_density": 1.2, "min_props": 7, "salt": 315,
        "required": ["table", "chair", "picture", "light_fixture"],
        "optional": {"picture": 1, "credenza": 0.5, "plant": 1.5},
        "assets": {**OFFICE, "credenza": ["prop_credenza"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"table": TABLE_CLUTTER},
        "lone_ok": ["plant", "table"],
        "notes": "K24 interview room: the round table and three chairs are map-built.",
    },
    # ---- L41 / L42 back of house
    "electrical_sl": {
        "purpose": "electrical", "min_density": 0.3, "max_density": 2.5, "min_props": 3, "salt": 316,
        "required": ["switchboard", "breaker_panel", "it_rack", "light_fixture"],
        "optional": {"box": 0.5},
        "assets": {"light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.0},
        "lone_ok": ["switchboard", "it_rack"],
        "notes": "K14 / M12: the switchboard (sub-board) is map-built; breaker panel, telecom / AV rack.",
    },
    "janitor_sl": {
        "purpose": "storage", "min_density": 0.5, "max_density": 4.0, "min_props": 3, "salt": 317,
        "required": ["mop_sink", "light_fixture"],
        "optional": {"shelving": 1.5, "mop_bucket": 1},
        "assets": {"shelving": ["prop_shelving_cleaning"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.0},
        "notes": "J (L41): the janitor's sink is map-built; the riser panel and the body-hide corner stay clear.",
    },
    "linen_janitor": {
        "purpose": "storage", "min_density": 0.5, "max_density": 4.0, "min_props": 3, "salt": 318,
        "required": ["shelving", "cleaning_cart", "light_fixture"],
        "optional": {"mop_bucket": 1},
        "assets": {"light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.0},
        "notes": "J (L42) linen: the linen shelving and the cleaner's cart (kc_cleaner) are map-built.",
    },
    "plant_room_roof": {
        "purpose": "plant", "min_density": 0.06, "max_density": 0.8, "min_props": 8, "salt": 319,
        "required": ["ahu", "chiller", "tank", "lift_motor", "breaker_panel", "fire_extinguisher", "light_fixture"],
        "optional": {"gas_cylinders": 0.5},
        "assets": {"light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 3.0},
        "lone_ok": ["ahu", "chiller", "tank", "lift_motor", "gas_cylinders"],
        "notes": "R3: AHU (body hide behind it), chiller, water tank and the lift machines are map-built.",
    },
    "plant_riser": {
        "purpose": "plant", "min_density": 0.3, "max_density": 2.5, "min_props": 3, "salt": 320,
        "required": ["breaker_panel", "fire_extinguisher", "light_fixture"],
        "assets": {"light_fixture": ["prop_bulkhead_caged"]},
        "ceiling": {"prop_bulkhead_caged": 2.0},
        "notes": "R1 riser bay: the hatch and its caged ladder (prefab) stay clear.",
    },
    # ---- L42 partners' floor
    "lounge_exec": {
        "purpose": "lounge", "min_density": 0.08, "max_density": 0.6, "min_props": 12, "salt": 321,
        "required": ["counter_bar", "sofa", "coffee_table", "piano", "rug", "floor_lamp", "picture", "light_fixture"],
        "optional": {"plant": 2, "side_table": 0.8, "picture": 1},
        "assets": {**EXEC, "rug": ["prop_rug_rect"]},
        "ceiling": {"prop_downlight": 2.6},
        "lone_ok": ["plant", "floor_lamp", "piano", "armchair", "side_table", "sofa"],
        "notes": "M1 partners' lounge: the backlit teal bar (kc_lounge), two sofa groups, the coffee table and the "
                 "baby grand are map-built; a rug, lamps, plants, art. The glass wall over the void stays clear.",
    },
    "gallery_mezzanine": {
        "purpose": "lobby", "min_density": 0.06, "max_density": 0.5, "min_props": 6, "salt": 322,
        "required": ["sculpture", "picture", "light_fixture"],
        "optional": {"picture": 1.5, "bench": 1, "plant": 1},
        "assets": {**EXEC, "bench": ["prop_bench_corridor"]},
        "ceiling": {"prop_downlight": 2.6},
        "lone_ok": ["sculpture", "bench", "plant"],
        "notes": "M2 gallery / mezzanine: the sculpture plinths are map-built; the walkway along the void, the "
                 "feature-stair arrival, the lift doors and the art-hall doors stay clear.",
    },
    "art_hall": {
        "purpose": "gallery", "min_density": 0.08, "max_density": 0.8, "min_props": 4, "salt": 323,
        "required": ["sculpture", "picture", "light_fixture"],
        "optional": {"bench": 0.5},
        "assets": {**EXEC, "bench": ["prop_bench_gallery"]},
        "ceiling": {"prop_downlight": 2.4},
        "lone_ok": ["sculpture", "bench"],
        "notes": "M3 art hall: west part sculpture and art; the laser plane (x 26.5) and the east part (paintings, "
                 "study door) stay clear. The picture lights are map-built.",
    },
    "study_exec": {
        "purpose": "office", "min_density": 0.15, "max_density": 1.0, "min_props": 10, "salt": 324,
        "required": ["desk", "chair", "bookshelf", "armchair", "floor_lamp", "rug", "picture", "light_fixture"],
        "optional": {"side_table": 1, "picture": 1, "plant": 1.5},
        "assets": {**EXEC},
        "ceiling": {"prop_downlight": 2.4},
        "clutter": {"desk": EXEC_DESK},
        "lone_ok": ["plant", "floor_lamp", "armchair", "side_table"],
        "notes": "M4 Kessler's study: desk, chair, bookcase and the club chair are map-built; the time-locked safe "
                 "and its reader, the facade access door and the laptop spot stay clear.",
    },
    "bedroom_exec": {
        "purpose": "bedroom", "min_density": 0.15, "max_density": 1.2, "min_props": 8, "salt": 325,
        "required": ["bed", "nightstand", "wardrobe", "rug", "floor_lamp", "picture", "light_fixture"],
        "optional": {"plant": 0.8, "picture": 0.5},
        "assets": {**EXEC, "rug": ["prop_rug_rect"]},
        "ceiling": {"prop_downlight": 2.6},
        "lone_ok": ["plant", "floor_lamp"],
        "notes": "M5 guest suite: bed, nightstands (kc_guest) and wardrobe are map-built; Kessler's armchair is an "
                 "npc seat in its slot (keep-out).",
    },
    "bathroom_ensuite": {
        "purpose": "restroom", "min_density": 0.4, "max_density": 2.2, "min_props": 6, "salt": 326,
        "required": ["sink", "toilet", "mirror", "paper_dispenser", "light_fixture"],
        "optional": {"bin": 1, "grab_bar": 0.5},
        "assets": {"mirror": ["prop_mirror_restroom"], "bin": ["prop_bin_small"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 1.8},
        "notes": "M6 en-suite: the double vanity is map-built; the WC against a wall (plumbing), mirrors over the "
                 "vanity.",
    },
    "dressing_room": {
        "purpose": "dressing", "min_density": 0.4, "max_density": 2.5, "min_props": 4, "salt": 327,
        "required": ["wardrobe", "mirror", "light_fixture"],
        "optional": {"bench": 0.5},
        "assets": {"mirror": ["prop_mirror_wall"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 1.6},
        "notes": "M7 suite vestibule / dressing room: the wardrobes are map-built; a full-height mirror.",
    },
    "dining_exec": {
        "purpose": "dining_room", "min_density": 0.15, "max_density": 1.0, "min_props": 12, "salt": 328,
        "required": ["table", "chair", "credenza", "fridge", "picture", "light_fixture"],
        "optional": {"picture": 1, "plant": 1.5},
        "assets": {**EXEC},
        "ceiling": {"prop_downlight": 2.0},
        "lone_ok": ["plant"],
        "notes": "M8 private dining: the table for ten (six chairs map-built), the sideboard and the wine fridge "
                 "are map-built; the terrace slider stays clear.",
    },
    "wine_room": {
        "purpose": "storage", "min_density": 0.2, "max_density": 2.0, "min_props": 3, "salt": 329,
        "required": ["shelving", "cabinet", "light_fixture"],
        "assets": {"light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 1.8},
        "lone_ok": ["shelving", "cabinet"],
        "notes": "M13: the wine wall and the humidor (two small_loot) are map-built.",
    },
    "boardroom": {
        "purpose": "office", "min_density": 0.2, "max_density": 1.2, "min_props": 12, "salt": 330,
        "required": ["table", "chair", "credenza", "picture", "light_fixture"],
        "optional": {"picture": 1, "plant": 1.5},
        "assets": {**EXEC},
        "ceiling": {"prop_downlight": 2.2},
        "clutter": {"table": TABLE_CLUTTER},
        "lone_ok": ["plant"],
        "notes": "M14 boardroom: the 4.8 m table, nine chairs and the credenza (lap_boardroom) are map-built.",
    },
    "corridor_glazed": {
        "purpose": "corridor", "min_density": 0.05, "max_density": 1.2, "min_props": 3, "salt": 331,
        "required": ["fire_extinguisher", "picture", "light_fixture"],
        "optional": {"picture": 1, "switch": 0.5},
        "assets": {**EXEC},
        "ceiling": {"prop_downlight": 2.6},
        "notes": "M15 terrace corridor: glazed to the terrace (south); art on the north wall, the sliders clear.",
    },
    "restroom_exec": {
        "purpose": "restroom", "min_density": 0.3, "max_density": 2.0, "min_props": 7, "salt": 332,
        "required": ["toilet", "sink", "mirror", "soap_dispenser", "paper_dispenser", "light_fixture"],
        "optional": {"hand_dryer": 1, "bin": 1, "grab_bar": 0.5},
        "counts": {"toilet": (2, 3), "mirror": (2, 3)},
        "assets": {"mirror": ["prop_mirror_restroom"], "bin": ["prop_bin_small"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.0},
        "notes": "WCW / WCM (L41, L42): the stone vanity is map-built on the north wall; WCs against the walls.",
    },
    # ---- exterior
    "exterior_roof_tower": {
        "purpose": "exterior", "min_density": 0.008, "max_density": 0.3, "min_props": 6, "salt": 334,
        "required": ["ahu", "hvac", "bmu", "anchor_frame"],
        "assets": {},
        "lone_ok": ["ahu", "hvac", "bmu", "garage", "anchor_frame", "wall_lamp"],
        "notes": "X2 roof: the BMU and its cradle garage, the two line anchors and the roof plant (condensers, a "
                 "packaged AHU) are placed by the map (no kit pass); the helipad, the parapets and the BMU rail "
                 "stay clear.",
    },
    "exterior_terrace": {
        "purpose": "exterior", "min_density": 0.03, "max_density": 0.3, "min_props": 8, "salt": 333,
        "required": ["planter", "lounger", "heater", "counter_service"],
        "assets": {},
        "lone_ok": ["planter", "lounger", "heater", "counter_service", "bollard_light", "ladder"],
        "notes": "X1 terrace: planters, loungers, the outdoor kitchen and heaters are map-built (no kit pass); LED "
                 "bollards along the balustrade.",
    },
}
