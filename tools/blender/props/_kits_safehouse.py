"""Safehouse ("The Press") dressing kits (C4-03; docs/design/heists/safehouse.md room list, D-147 reuse-first). Imported
by _kits.py, which writes every kit .tres.

The G0's new kits, built from catalog assets that exist today; each kit's purpose is its room's levelcheck purpose
(docs/levels/safehouse/README.md: LB loading, H1 workshop, MK office, BK bedroom, RV corridor). No kit places light
fixtures: the safehouse's fixtures are explicit (sh_lighting.gd, the G0's per-room list), so no `ceiling` grid and no
required `light_fixture`. The stations (the Board, the planning table, the armory bench, the mask bench, the jukebox,
the Old Press, the range door, the crew phone, the bulletin board) are the map's own and are kept clear (keep-outs).
The CO / WC / ST rooms use the shared corridor_service, restroom_single and electrical_closet kits unchanged.
Waits (new assets, D): the bunk bed (two queen beds stand in), the gun cabinet (lockers stand in), the ear-defender
rack (a coat rail stands in), the van (the G1 box), the old type cases (plan chests stand in), the press itself.
"""

from __future__ import annotations

SAFEHOUSE_KITS = {
    "loading_bay": {
        "purpose": "loading",
        "min_density": 0.12,
        "max_density": 0.6,
        "min_props": 8,
        "salt": 4801,
        "required": ["pallet", "crate", "shelving", "dolly", "coat_rail", "bag"],
        "optional": {"box": 1.2, "pallet": 0.8, "fire_extinguisher": 1, "gas_cylinders": 0.5},
        "counts": {"pallet": (2, 2), "bag": (2, 3)},
        "assets": {
            "pallet": ["prop_pallet_loaded"],
            "shelving": ["prop_shelving_parts"],
            "bag": ["prop_bag_floor"],
        },
        "ceiling": {},
        "lone_ok": ["pallet", "crate", "shelving", "dolly", "coat_rail", "vehicle", "fire_extinguisher"],
        "notes": "Safehouse LB (8 x 8 m, the spawn room): two pallets of old paper reels (print-works legacy), a "
        "rolling tool chest (parts shelving), an empty duffel pile, the hand truck, a coat rack; the crew van is the "
        "map's (Props/CrewVan). The work light on its stand is an explicit fixture.",
    },
    "safehouse_hall": {
        "purpose": "workshop",
        "min_density": 0.05,
        "max_density": 0.4,
        "min_props": 9,
        "salt": 4802,
        "required": ["plan_chest", "file_cabinet", "shelving", "fire_extinguisher", "picture", "bin"],
        "optional": {"crate": 0.6, "box": 0.6, "plant": 0.3, "coat_rail": 0.4},
        "counts": {"plan_chest": (2, 3), "picture": (2, 2)},
        "assets": {
            "shelving": ["prop_shelving_archive"],
            "picture": ["prop_notice_frame"],
            "bin": ["prop_bin_office"],
        },
        "ceiling": {},
        "lone_ok": ["plan_chest", "file_cabinet", "shelving", "fire_extinguisher", "picture", "plant"],
        "notes": "Safehouse H1 print hall (14 x 12 m): old type cases along the walls (plan chests stand in), a "
        "filing cabinet, shelving, the pinned fire plans by the openings (notice frames). The Board, the planning "
        "table, the Old Press and the crew phone are stations; the hall's middle stays open.",
    },
    "safehouse_lounge": {
        "purpose": "break_room",
        "min_density": 0.2,
        "max_density": 1.0,
        "min_props": 16,
        "salt": 4803,
        "required": ["sofa", "coffee_table", "rug", "fridge", "kitchen_counter", "microwave", "coffee_machine",
                     "table", "chair", "wall_cabinet", "bin"],
        "optional": {"armchair": 1, "side_table": 1, "plant": 0.5, "picture": 1, "bookshelf": 0.6, "kettle": 0.6},
        "counts": {"chair": (4, 4)},
        "assets": {
            "chair": ["prop_chair_break"],
            "table": ["prop_table_break"],
            "rug": ["prop_rug_rect"],
            "bin": ["prop_bin_kitchen"],
            "picture": ["prop_wall_art_a", "prop_wall_art_b"],
            "plant": ["prop_plant_tall"],
        },
        "clutter": {
            "counter": {
                "anchors": ["kitchen_counter", "table", "coffee_table"],
                "count": (1, 3),
                "items": {"mug": 3, "bottles": 1, "papers": 1, "kettle": 0.6},
                "radius": 0.5,
            },
        },
        "ceiling": {},
        "lone_ok": ["fridge", "bookshelf", "plant"],
        "notes": "Safehouse LG lounge (8 x 10 m, extends break_room): an L-sofa (sofa + armchair) round a coffee "
        "table on a rug, a kitchenette (counter, fridge, microwave, coffee machine, wall cabinets), a dining table "
        "with 4 chairs. The jukebox and the bulletin board (profile) are stations; the floor lamp and the pendant are "
        "explicit fixtures.",
    },
    "armory_workshop": {
        "purpose": "workshop",
        "min_density": 0.1,
        "max_density": 0.8,
        "min_props": 6,
        "salt": 4804,
        "required": ["lockers", "shelving", "crate", "box"],
        "optional": {"stool": 1, "bin": 1, "tool_wall": 0.6, "fire_extinguisher": 1},
        "counts": {"lockers": (2, 2)},
        "assets": {"shelving": ["prop_shelving_parts"], "stool": ["prop_stool_shop"]},
        "ceiling": {},
        "lone_ok": ["lockers", "shelving", "crate", "fire_extinguisher"],
        "notes": "Safehouse WS workshop (6 x 7 m): two locked gun cabinets on the north wall (lockers stand in), "
        "parts shelving on wall z 7, ammo crates, a stool where it fits. The armory bench and its pegboard are the "
        "station (its approach is kept clear).",
    },
    "mask_room": {
        "purpose": "office",
        "min_density": 0.15,
        "max_density": 0.9,
        "min_props": 5,
        "salt": 4805,
        "required": ["shelving", "coat_rail", "box", "bin"],
        "optional": {"chair": 1, "plant_small": 0.4, "picture": 0.6},
        "assets": {"shelving": ["prop_shelving_cleaning"], "chair": ["prop_chair_task"]},
        "ceiling": {},
        "lone_ok": ["shelving", "coat_rail"],
        "notes": "Safehouse MK mask room (6 x 5 m, a former darkroom): the paint / finish shelf, a drying line with "
        "stencils (a coat rail stands in), a chair where it fits (the G0's bench chair would stand on the station's "
        "UsePoint). The mask bench and the mask wall are the station.",
    },
    "safehouse_plant": {
        "purpose": "electrical",
        "min_density": 0.3,
        "max_density": 1.2,
        "min_props": 5,
        "salt": 4809,
        "required": ["breaker_panel", "it_rack", "shelving", "archive_box"],
        "optional": {"box": 1, "tank": 0.6, "fire_extinguisher": 1},
        "assets": {"shelving": ["prop_shelving_archive"]},
        "ceiling": {},
        "lone_ok": ["breaker_panel", "it_rack", "shelving", "tank"],
        "notes": "Safehouse ST store (3.5 x 4.5 m; the G0's electrical_closet + storage_archive): the breaker panel, "
        "Mercer's router / NAS rack, shelving with print-works archive boxes, the water heater (tank) where it fits.",
    },
    "bunk_room": {
        "purpose": "bedroom",
        "min_density": 0.2,
        "max_density": 1.0,
        "min_props": 6,
        "salt": 4806,
        "required": ["bed", "lockers", "side_table", "bag"],
        "optional": {"table_lamp": 1, "rug": 0.6, "box": 0.5},
        "counts": {"bed": (2, 2), "lockers": (2, 2), "bag": (2, 4)},
        "assets": {"bed": ["prop_bed_queen"], "bag": ["prop_bag_floor"], "rug": ["prop_rug_rect"]},
        "ceiling": {},
        "lone_ok": ["bed", "lockers"],
        "notes": "Safehouse BK bunk room (5 x 4.5 m): two beds (the G0's bunk beds wait for their asset), four "
        "personal lockers (two banks), duffels, a bedside table and lamp.",
    },
    "range_vestibule": {
        "purpose": "corridor",
        "min_density": 0.1,
        "max_density": 0.8,
        "min_props": 4,
        "salt": 4807,
        "required": ["bench", "crate", "coat_rail", "fire_extinguisher"],
        "optional": {"box": 0.8},
        "counts": {"crate": (2, 3)},
        "assets": {"bench": ["prop_bench_locker"]},
        "ceiling": {},
        "lone_ok": ["bench", "crate", "coat_rail", "fire_extinguisher"],
        "notes": "Safehouse RV range vestibule (3.5 x 4.5 m): the ear-defender and eye-protection rack (a coat rail "
        "stands in), ammo crates, a bench. The range door (station 7) and its LIVE FIRE lamp are the map's.",
    },
    "kit_store": {
        "purpose": "storage",
        "min_density": 0.2,
        "max_density": 0.8,
        "min_props": 8,
        "salt": 4808,
        "required": ["shelving", "crate", "box", "bag", "pallet"],
        "optional": {"gas_cylinders": 0.6, "box": 1.2, "crate": 1.0},
        "counts": {"shelving": (2, 3), "bag": (2, 3)},
        "assets": {
            "shelving": ["prop_shelving_boxes", "prop_shelving_parts"],
            "bag": ["prop_bag_floor"],
            "pallet": ["prop_pallet"],
        },
        "ceiling": {},
        "lone_ok": ["shelving", "pallet", "crate"],
        "notes": "Safehouse KS kit store (5.5 x 6 m): the equipment cage's shelving, drill and ECM cases (boxes), "
        "thermite crates (inert dressing), spare duffels, a pallet. The fire exit is on the south wall.",
    },
}
