"""Shadow Ledger dressing kits (Kessler & Moor tower floor: service level, penthouse offices, the
partners' suite and the roof). Imported by _kits.py, which writes every kit .tres.

Same conventions as _kits.py: kinds are the catalog `kind` metas, `assets` pins the style (and, for
required kinds, the instance order), `ceiling` lays fixtures on a grid. Layout-relevant furniture
(reception desk, bar counter, grand piano, the partners' bed, NPC desks) is anchored by the map; the
kits fill around it. Gameplay prefabs (wheelie bins, safes, terminals) are keep-outs.

Seat rules worth knowing: armchairs only seat at coffee tables, desk lamps only stand on desks /
credenzas, monitors only on desks; kits that ask for those include the host kind.
"""

from __future__ import annotations

DESK_CLUTTER = {"anchors": ["desk"], "items": {"papers": 3, "mug": 1.5, "pen_cup": 1.2, "binders": 0.8, "notebook": 1.5,
                                              "laptop": 1.2, "plant_small": 0.5}, "count": (2, 3), "radius": 0.6}
TABLE_CLUTTER = {"anchors": ["table"], "items": {"laptop": 1.5, "notebook": 1.5, "papers": 1.5, "mug": 1}, "count": (1, 3),
                 "radius": 0.6}
CREDENZA_CLUTTER = {"anchors": ["credenza"], "items": {"bust": 1, "table_lamp": 1, "binders": 0.6, "plant_small": 1},
                    "count": (1, 2), "radius": 0.4}
SIDE_CLUTTER = {"anchors": ["side_table"], "items": {"table_lamp": 1.2, "plant_small": 1}, "count": (1, 1), "radius": 0.3}
FLOOR_BOH = {"anchors": ["wall", "corner"], "items": {"box": 3, "archive_box": 1}, "count": (1, 2), "radius": 1.0}
ART = ["prop_wall_art_a", "prop_wall_art_b", "prop_wall_art_c"]

TOWER_KITS: dict[str, dict] = {
    # ---------------------------------------------------------------- service level
    "service_lobby": {
        "purpose": "lobby", "min_density": 0.15, "max_density": 1.5, "min_props": 7, "salt": 201,
        "required": ["bench", "bulletin_board", "fire_extinguisher", "bin", "light_fixture"],
        "optional": {"picture": 1, "switch": 0.8, "exit_sign": 0.6, "plant": 0.4},
        "assets": {"bench": ["prop_bench_corridor"], "bin": ["prop_bin_kitchen"], "picture": ["prop_notice_frame"],
                   "plant": ["prop_plant_tall"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "lone_ok": ["bench", "bin", "plant"],
        "notes": "S1 service lobby by the freight lift: waiting bench, notice board, extinguisher, bin, fluorescent "
                 "strips. The freight-lift doors and their landing stay clear (keep-out).",
    },
    "refuse_room": {
        "purpose": "storage", "min_density": 0.25, "max_density": 2.0, "min_props": 6, "salt": 202,
        "required": ["shelving", "mop_bucket", "box", "light_fixture"],
        "optional": {"box": 1.5, "shelving": 0.5, "fire_extinguisher": 0.6},
        "assets": {"shelving": ["prop_shelving_cleaning", "prop_shelving_boxes"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.2},
        "clutter": {"floor": FLOOR_BOH},
        "notes": "S2 refuse room: the two wheelie bins are gameplay prefabs (keep-outs); cleaning shelf, mop bucket, "
                 "flattened boxes. Fluorescent.",
    },
    "restroom_multi": {
        "purpose": "restroom", "min_density": 0.35, "max_density": 2.5, "min_props": 8, "salt": 203,
        "required": ["toilet", "sink", "mirror", "paper_dispenser", "soap_dispenser", "hand_dryer", "light_fixture"],
        "optional": {"bin": 1, "grab_bar": 0.4},
        "counts": {"toilet": (2, 3), "sink": (1, 2)},
        "assets": {"mirror": ["prop_mirror_restroom"], "bin": ["prop_bin_small"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.2},
        "notes": "Tower restrooms (4 rooms, 3 x 6.5 m): 2-3 WCs (cubicle partitions, if any, are map anchors), vanity "
                 "sinks with mirrors and soap, paper by the WCs, a hand dryer.",
    },
    # ---------------------------------------------------------------- penthouse offices
    "office_partner": {
        "purpose": "office", "min_density": 0.3, "max_density": 1.8, "min_props": 14, "salt": 204,
        "required": ["rug", "desk", "chair", "credenza", "bookshelf", "sofa", "coffee_table", "armchair", "picture", "plant",
                     "desk_lamp", "monitor", "light_fixture"],
        "optional": {"picture": 1, "side_table": 0.6, "floor_lamp": 0.6, "plant": 0.5, "bookshelf": 0.5, "file_cabinet": 0.3},
        "counts": {"chair": (3, 3), "armchair": (1, 2)},
        "assets": {"desk": ["prop_desk_exec"], "chair": ["prop_chair_task", "prop_chair_visitor", "prop_chair_visitor"],
                   "picture": ART, "plant": ["prop_plant_tall"], "rug": ["prop_rug_rect"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.4},
        "clutter": {"credenza": CREDENZA_CLUTTER, "desk": DESK_CLUTTER, "side": SIDE_CLUTTER},
        "notes": "K1 / K5 partner offices: free-standing executive desk (task chair 0.47 m + two visitor chairs), "
                 "credenza, bookshelf, a sofa + coffee table + armchair seating group on a rug, art, 2700 K downlights.",
    },
    "conference_room": {
        "purpose": "office", "min_density": 0.3, "max_density": 2.0, "min_props": 10, "salt": 205,
        "required": ["table", "chair", "credenza", "picture", "plant", "light_fixture"],
        "optional": {"tv": 0.8, "picture": 0.8, "plant": 0.4, "bin": 0.3},
        "counts": {"chair": (4, 6), "tv": (1, 1)},
        "assets": {"table": ["prop_table_conference"], "chair": ["prop_chair_office"], "picture": ART, "plant": ["prop_plant_tall"],
                   "bin": ["prop_bin_office"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.2},
        "clutter": {"credenza": CREDENZA_CLUTTER, "table": TABLE_CLUTTER},
        "lone_ok": ["table"],
        "notes": "K2 conference room: 3.0 m racetrack table with up to six swivel chairs, credenza, wall display, art.",
    },
    "reception_exec": {
        "purpose": "lobby", "min_density": 0.12, "max_density": 1.2, "min_props": 16, "salt": 206,
        "required": ["rug", "sofa", "coffee_table", "armchair", "plant", "picture", "light_fixture"],
        "optional": {"sofa": 0.5, "side_table": 0.8, "floor_lamp": 0.8, "plant": 1, "picture": 1, "bench": 0.5, "vitrine": 0.3},
        "counts": {"armchair": (2, 2), "plant": (2, 3), "picture": (2, 3)},
        "assets": {"picture": ART, "plant": ["prop_plant_tall"], "rug": ["prop_rug_rect"], "bench": ["prop_bench_upholstered"],
                   "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_chandelier_ring": 14.0, "prop_downlight": 3.0},
        "clutter": {"side": SIDE_CLUTTER},
        "lone_ok": ["plant", "bench", "vitrine", "counter_transaction"],
        "notes": "K3 executive reception: the reception desk (prop_reception_desk, 1.05 m ledge) is a map anchor and the "
                 "feature stair a keep-out. Waiting group (sofa, two armchairs, coffee table on a rug), plants, art, "
                 "the ring chandelier over the middle and 2700 K downlights.",
    },
    "office_small": {
        "purpose": "office", "min_density": 0.25, "max_density": 2.2, "min_props": 7, "salt": 207,
        "required": ["desk", "chair", "monitor", "file_cabinet", "picture", "plant", "light_fixture"],
        "optional": {"keyboard": 1, "bin": 0.8, "desk_lamp": 0.6, "picture": 0.6, "bookshelf": 0.5},
        "assets": {"desk": ["prop_desk_office"], "chair": ["prop_chair_task"], "picture": ["prop_wall_art_a", "prop_wall_art_b"],
                   "plant": ["prop_plant_tall"], "bin": ["prop_bin_office"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"desk": DESK_CLUTTER},
        "notes": "K4, K20-K23 associate offices (3-5 m x 6 m): wall desk with a task chair (0.47 m), monitor, file "
                 "cabinet, plant, art. 4000 K panels.",
    },
    "office_open_tower": {
        "purpose": "office", "min_density": 0.2, "max_density": 1.5, "min_props": 22, "salt": 208,
        "required": ["desk", "chair", "monitor", "keyboard", "file_cabinet", "printer", "water_cooler", "plant", "light_fixture"],
        "optional": {"plant": 1, "picture": 1, "bin": 1, "bookshelf": 0.6, "desk_lamp": 0.6, "credenza": 0.5},
        "counts": {"desk": (4, 6), "chair": (4, 6), "monitor": (3, 6), "keyboard": (3, 6), "file_cabinet": (2, 3),
                   "plant": (2, 3)},
        "assets": {"desk": ["prop_desk_office"], "chair": ["prop_chair_office"], "bin": ["prop_bin_office"], "plant": ["prop_plant_tall"],
                   "picture": ["prop_wall_art_a", "prop_wall_art_b", "prop_notice_frame"],
                   "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"desk": DESK_CLUTTER},
        "lone_ok": ["plant", "water_cooler", "printer"],
        "notes": "K8 paralegal open office: wall desks with swivel chairs and monitors, file cabinets, printer, water "
                 "cooler, plants. 4000 K panels.",
    },
    "office_it": {
        "purpose": "office", "min_density": 0.3, "max_density": 2.0, "min_props": 10, "salt": 209,
        "required": ["desk", "chair", "monitor", "keyboard", "it_rack", "shelving", "box", "light_fixture"],
        "optional": {"box": 1.5, "file_cabinet": 0.5, "bin": 0.6, "fire_extinguisher": 0.5},
        "counts": {"it_rack": (1, 2), "monitor": (1, 2)},
        "assets": {"desk": ["prop_desk_office"], "chair": ["prop_chair_office"], "shelving": ["prop_shelving_parts", "prop_shelving_boxes"],
                   "bin": ["prop_bin_office"], "light_fixture": ["prop_ceiling_panel_cool"]},
        "ceiling": {"prop_ceiling_panel_cool": 2.4},
        "clutter": {"desk": {"anchors": ["desk"], "items": {"keyboard": 0.5, "papers": 1, "mug": 1, "laptop": 1.2}, "count": (1, 2),
                             "radius": 0.5}},
        "notes": "K12 IT office: support desk, network racks (LEDs), parts shelving, boxed kit. 5000 K panels.",
    },
    "copy_room": {
        "purpose": "storage", "min_density": 0.4, "max_density": 2.5, "min_props": 7, "salt": 210,
        "required": ["printer", "shelving", "archive_box", "box", "bin", "light_fixture"],
        "optional": {"box": 1, "archive_box": 1, "file_cabinet": 0.5, "shelving": 0.4},
        "assets": {"shelving": ["prop_shelving_archive", "prop_shelving_boxes"], "bin": ["prop_bin_office"],
                   "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.2},
        "notes": "K15 copy / supplies room: printer, paper and archive boxes on shelving, bin.",
    },
    "library_law": {
        "purpose": "office", "min_density": 0.3, "max_density": 2.0, "min_props": 12, "salt": 211,
        "required": ["rug", "bookshelf", "table", "chair", "credenza", "desk_lamp", "coffee_table", "armchair", "light_fixture"],
        "optional": {"bookshelf": 1, "floor_lamp": 0.8, "picture": 0.6, "side_table": 0.5, "armchair": 0.4},
        "counts": {"bookshelf": (4, 6), "chair": (2, 4)},
        "assets": {"table": ["prop_table_dining"], "chair": ["prop_chair_dining"], "rug": ["prop_rug_rect"],
                   "picture": ["prop_wall_art_a", "prop_wall_art_b"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.4},
        "clutter": {"table": {"anchors": ["table"], "items": {"notebook": 2, "papers": 1.5, "binders": 1}, "count": (1, 2),
                              "radius": 0.5},
                    "side": SIDE_CLUTTER},
        "lone_ok": ["table"],
        "notes": "K19 law library: walnut bookshelves round the walls, a reading table with upholstered chairs, a "
                 "credenza with the desk lamp, an armchair at a low table on the rug. Warm downlights.",
    },
    "meeting_small": {
        "purpose": "office", "min_density": 0.3, "max_density": 2.0, "min_props": 10, "salt": 212,
        "required": ["table", "chair", "credenza", "picture", "plant", "light_fixture"],
        "optional": {"picture": 1, "plant": 0.5, "tv": 0.4, "bin": 0.3},
        "counts": {"chair": (4, 4), "tv": (1, 1)},
        "assets": {"table": ["prop_table_dining"], "chair": ["prop_chair_visitor"], "picture": ART, "plant": ["prop_plant_tall"],
                   "bin": ["prop_bin_office"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.4},
        "clutter": {"credenza": CREDENZA_CLUTTER, "table": TABLE_CLUTTER},
        "lone_ok": ["table"],
        "notes": "K24 client meeting room: walnut table with four cognac visitor chairs, credenza, art, plant.",
    },
    # ---------------------------------------------------------------- partners' suite
    "lounge_exec": {
        "purpose": "lounge", "min_density": 0.12, "max_density": 1.2, "min_props": 16, "salt": 213,
        "required": ["rug", "sofa", "coffee_table", "armchair", "floor_lamp", "plant", "picture", "light_fixture"],
        "optional": {"side_table": 1, "floor_lamp": 0.6, "plant": 0.8, "picture": 1, "vitrine": 0.4, "bench": 0.3},
        "counts": {"sofa": (1, 2), "armchair": (2, 3), "plant": (2, 3), "picture": (2, 3)},
        "assets": {"picture": ART, "plant": ["prop_plant_tall"], "rug": ["prop_rug_rect", "prop_rug_round"],
                   "bench": ["prop_bench_upholstered"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_chandelier_ring": 14.0, "prop_downlight": 3.0},
        "clutter": {"side": SIDE_CLUTTER},
        "lone_ok": ["piano", "counter_bar", "plant", "vitrine", "floor_lamp", "bench"],
        "notes": "M1 partners' lounge: the bar counter (prop_bar_counter) and the grand piano (prop_piano_grand) are map "
                 "anchors. Seating group(s) on rugs, floor lamps, plants, art, ring chandelier + downlights.",
    },
    "gallery_mezzanine": {
        "purpose": "lobby", "min_density": 0.12, "max_density": 1.5, "min_props": 8, "salt": 214,
        "required": ["plinth", "picture", "bench", "plant", "light_fixture"],
        "optional": {"plinth": 1, "picture": 1, "vitrine": 0.6, "plant": 0.5},
        "counts": {"plinth": (2, 3), "picture": (2, 4)},
        "assets": {"bench": ["prop_bench_upholstered"], "picture": ART, "plant": ["prop_plant_tall"],
                   "light_fixture": ["prop_track_light"]},
        "ceiling": {"prop_track_light": 3.0},
        "lone_ok": ["plinth", "bench", "plant", "vitrine"],
        "notes": "M2 gallery mezzanine (L-shape: pass the bounding box + a keep-out for the missing corner, and the "
                 "railing edge): plinths, art on the walls, an upholstered bench, track lights. Busts do not stand on "
                 "plinths (bust hosts: counter_service / table / credenza).",
    },
    "art_hall": {
        "purpose": "gallery", "min_density": 0.15, "max_density": 1.5, "min_props": 8, "salt": 215,
        "required": ["picture", "bench", "plinth", "light_fixture"],
        "optional": {"picture": 1, "plinth": 0.6, "bench": 0.3},
        "counts": {"picture": (3, 5), "plinth": (1, 2)},
        "assets": {"picture": ART, "bench": ["prop_bench_upholstered"], "light_fixture": ["prop_track_light"]},
        "ceiling": {"prop_track_light": 2.6},
        "lone_ok": ["plinth", "bench"],
        "notes": "M3 art hall (top-lit gallery): the hang on the long walls, plinths, a bench, track lights.",
    },
    "study_exec": {
        "purpose": "office", "min_density": 0.25, "max_density": 1.8, "min_props": 15, "salt": 216,
        "required": ["rug", "desk", "chair", "bookshelf", "credenza", "coffee_table", "armchair", "floor_lamp", "picture",
                     "desk_lamp", "light_fixture"],
        "optional": {"side_table": 0.6, "plant": 0.8, "picture": 1, "bookshelf": 0.5, "wall_safe": 0.2},
        "counts": {"chair": (3, 3), "bookshelf": (2, 4)},
        "assets": {"desk": ["prop_desk_exec"], "chair": ["prop_chair_task", "prop_chair_visitor", "prop_chair_visitor"],
                   "picture": ART, "plant": ["prop_plant_tall"], "rug": ["prop_rug_rect"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.4},
        "clutter": {"credenza": CREDENZA_CLUTTER, "desk": DESK_CLUTTER, "side": SIDE_CLUTTER},
        "notes": "M4 senior partner's study: executive desk (task chair 0.47 m + two visitor chairs), bookshelves, "
                 "credenza, a reading armchair at a low table on the rug, floor lamp, art. Warm downlights.",
    },
    "bedroom_exec": {
        "purpose": "bedroom", "min_density": 0.2, "max_density": 2.0, "min_props": 9, "salt": 217,
        "required": ["bed", "wardrobe", "rug", "picture", "light_fixture"],
        "optional": {"armchair": 0.6, "coffee_table": 0.6, "floor_lamp": 0.6, "side_table": 0.4, "plant": 0.6, "picture": 0.6,
                     "mirror": 0.4},
        "assets": {"bed": ["prop_bed_double"], "table_lamp": ["prop_lamp_bedside"], "mirror": ["prop_mirror_wall"],
                   "picture": ART, "plant": ["prop_plant_tall"], "rug": ["prop_rug_rect"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.4},
        "clutter": {"bedside": {"anchors": ["bed"], "items": {"nightstand": 1}, "count": (2, 2), "radius": 0.25},
                    "lamps": {"anchors": ["nightstand"], "items": {"table_lamp": 1}, "count": (1, 1), "radius": 0.3}},
        "notes": "M5 partner's bedroom: the bed (prop_bed_double, `Pelvis` marker for the sleeping NPC) is a map anchor; "
                 "two nightstands beside it with bedside lamps (clutter groups, so they hug the bed), wardrobe, rug, "
                 "art. Armchair only with a coffee table (seat host).",
    },
    "bathroom_ensuite": {
        "purpose": "restroom", "min_density": 0.4, "max_density": 3.0, "min_props": 6, "salt": 218,
        "required": ["toilet", "sink", "mirror", "soap_dispenser", "paper_dispenser", "light_fixture"],
        "optional": {"bin": 0.6, "grab_bar": 0.3},
        "assets": {"mirror": ["prop_mirror_restroom"], "bin": ["prop_bin_small"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 1.8},
        "notes": "M6 en-suite: WC with paper, vanity with mirror and soap. Warm downlights.",
    },
    "dressing_room": {
        "purpose": "dressing", "min_density": 0.5, "max_density": 3.0, "min_props": 5, "salt": 219,
        "required": ["wardrobe", "mirror", "bench", "light_fixture"],
        "counts": {"wardrobe": (2, 2)},
        "assets": {"mirror": ["prop_mirror_wall"], "bench": ["prop_bench_upholstered"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 1.6},
        "notes": "M7 dressing room (4 x 2 m): two wardrobes, a full-length mirror, an upholstered bench.",
    },
    "dining_exec": {
        "purpose": "dining_room", "min_density": 0.2, "max_density": 1.6, "min_props": 16, "salt": 220,
        "required": ["rug", "table", "chair", "credenza", "picture", "plant", "light_fixture"],
        "optional": {"picture": 1, "plant": 0.6, "vitrine": 0.3, "floor_lamp": 0.4},
        "counts": {"chair": (6, 8), "picture": (2, 3), "plant": (1, 2)},
        "assets": {"rug": ["prop_rug_dining"], "table": ["prop_table_dining"], "chair": ["prop_chair_dining"], "picture": ART,
                   "plant": ["prop_plant_tall"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_chandelier_ring": 12.0, "prop_downlight": 2.6},
        "clutter": {"credenza": CREDENZA_CLUTTER, "table": {"anchors": ["table"], "items": {"bottles": 1}, "count": (0, 1),
                                                            "radius": 0.5}},
        "lone_ok": ["table"],
        "notes": "M8 partners' dining room: 2.4 m walnut table on a 4 x 3 m rug with up to eight upholstered chairs, "
                 "a credenza as sideboard, art, the ring chandelier centred over the room + downlights. If the map "
                 "anchors the table, anchor the rug under it too.",
    },
    "wine_room": {
        "purpose": "storage", "min_density": 0.3, "max_density": 2.5, "min_props": 4, "salt": 221,
        "required": ["wine_rack", "light_fixture"],
        "optional": {"wine_rack": 1, "crate": 0.5},
        "counts": {"wine_rack": (2, 3)},
        "assets": {"light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.2},
        "notes": "M13 wine room: walnut wine walls, a wooden case or two. Dim warm downlights.",
    },
    "boardroom": {
        "purpose": "office", "min_density": 0.25, "max_density": 2.0, "min_props": 16, "salt": 222,
        "required": ["table", "chair", "credenza", "tv", "picture", "plant", "light_fixture"],
        "optional": {"picture": 1, "plant": 0.5, "bin": 0.2},
        "counts": {"chair": (8, 10)},
        "assets": {"table": ["prop_table_boardroom"], "chair": ["prop_chair_office"], "picture": ART, "plant": ["prop_plant_tall"],
                   "bin": ["prop_bin_office"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.4},
        "clutter": {"credenza": CREDENZA_CLUTTER, "table": {"anchors": ["table"], "items": {"laptop": 1.5, "notebook": 1.5,
                                                                                             "papers": 1.5, "mug": 1},
                                                            "count": (2, 4), "radius": 0.6}},
        "lone_ok": ["table"],
        "notes": "M14 boardroom: 4.2 m walnut table, 8-10 swivel chairs, credenza, wall display (prop_tv_wall; the "
                 "brief's 'monitor' kind only stands on desks), art, plants.",
    },
    "corridor_glazed": {
        "purpose": "corridor", "min_density": 0.08, "max_density": 1.2, "min_props": 8, "salt": 223,
        "required": ["fire_extinguisher", "light_fixture"],
        "optional": {"plant": 0.6, "picture": 0.8, "switch": 0.5, "exit_sign": 0.4},
        "counts": {"plant": (1, 2)},
        "assets": {"picture": ["prop_wall_art_a", "prop_wall_art_b"], "plant": ["prop_plant_tall"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.6},
        "lone_ok": ["plant"],
        "notes": "M15 glazed corridor (1.5 m): wall-mounted dressing, a plant or two (0.53 m deep, the walkway stays "
                 ">= 0.9 m). No benches: a bench + its clearance would block the 1.5 m corridor.",
    },
    "plant_riser": {
        "purpose": "plant", "min_density": 0.4, "max_density": 3.0, "min_props": 4, "salt": 224,
        "required": ["breaker_panel", "it_rack", "light_fixture"],
        "optional": {"box": 0.6, "fire_extinguisher": 0.6, "shelving": 0.3},
        "assets": {"shelving": ["prop_shelving_parts"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "notes": "R1 riser cupboard: breaker panel, comms rack, fluorescent strip.",
    },
    # ---------------------------------------------------------------- roof
    "exterior_terrace": {
        "purpose": "exterior", "min_density": 0.03, "max_density": 0.3, "min_props": 9, "salt": 225,
        "required": ["planter", "lounger", "heater"],
        "optional": {"planter": 1, "lounger": 0.5, "heater": 0.5},
        "counts": {"planter": (3, 5), "lounger": (4, 6), "heater": (2, 4)},
        "assets": {"planter": ["prop_planter_terrace"]},
        "lone_ok": ["planter", "lounger", "heater"],
        "notes": "X1 roof terrace: stone planters along the building wall / parapet (wall-backed: pass the walls), "
                 "sun loungers, patio heaters (warm omni).",
    },
    "exterior_roof": {
        "purpose": "exterior", "min_density": 0.003, "max_density": 0.3, "min_props": 3, "salt": 226,
        "required": ["hvac"],
        "optional": {"hvac": 1},
        "counts": {"hvac": (3, 5)},
        "lone_ok": ["hvac"],
        "notes": "X2 plant roof: condensers backed to the plant-room walls / parapet. Roof hatch, lift overrun and "
                 "the window-cleaning rail are map pieces (keep-outs).",
    },
}
