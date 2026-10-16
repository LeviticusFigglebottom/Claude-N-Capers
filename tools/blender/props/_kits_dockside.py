"""Dockside Burn dressing kits (DB-C2, docs/design/heists/dockside_burn.md room list), merged into _kits.py.

Kinds the map builds itself (dockside_burn_layout.gd PROPS: counters, compressors, racking, crates, containers...) are
listed as required so the density check sees the room complete; the generator (db_dress.gd) drops a required kind
the room already holds before it runs KitPlacer, and registers the map-built supports as hosts. Every asset is pinned
(the DB props are pin_only). Fixture grids: offices 4000 K panels, the hall's 5000 K high bays, the chambers' 6000 K
battens, the strongroom's caged bulkhead (doc §Audio/lighting).
"""

from __future__ import annotations

FLOOR_DOCK = {"anchors": ["wall", "corner"], "items": {"fish_boxes": 2, "pallet": 1.5, "tote": 0.6}, "count": (1, 2),
              "radius": 1.2}
FLOOR_OFFICE = {"anchors": ["wall", "door"], "items": {"bin": 2, "box": 1}, "count": (0, 1), "radius": 0.8}
DESK_CLUTTER = {"anchors": ["desk", "counter_service"], "items": {"papers": 3, "mug": 2, "binders": 1, "notebook": 1},
                "count": (1, 3), "radius": 0.6}
OFFICE_ASSETS = {"bin": ["prop_bin_office"], "picture": ["prop_notice_frame"], "box": ["prop_box_small"],
                 "light_fixture": ["prop_ceiling_panel_neutral"], "fire_extinguisher": ["prop_fire_extinguisher"],
                 "papers": ["prop_papers"], "mug": ["prop_mug"], "binders": ["prop_binders"], "notebook": ["prop_notebook"]}
DOCK_ASSETS = {"fish_boxes": ["prop_fish_box_stack"], "pallet": ["prop_pallet_stack", "prop_pallet"], "tote": ["prop_ibc_tote"],
               "fire_extinguisher": ["prop_fire_extinguisher"], "hose_reel": ["prop_hose_reel"],
               "pallet_wrapped": ["prop_pallet_wrapped"], "fish_crates": ["prop_fish_crates"],
               "pallet_jack": ["prop_pallet_jack"], "dolly": ["prop_hand_truck"], "cone": ["prop_traffic_cone"]}

DOCKSIDE_KITS: dict[str, dict] = {
    "office_front_desk": {
        "purpose": "reception", "min_density": 0.2, "max_density": 1.4, "min_props": 8, "salt": 201,
        "required": ["counter_service", "bench", "chair", "bulletin_board", "water_cooler", "plant", "light_fixture"],
        "optional": {"picture": 1.5, "bin": 1, "fire_extinguisher": 1, "clock": 1},
        "assets": {**OFFICE_ASSETS, "bulletin_board": ["prop_bulletin_board"], "water_cooler": ["prop_water_cooler"],
                   "clock": ["prop_clock_harbor"], "plant": ["prop_plant_tall"]},
        "ceiling": {"prop_ceiling_panel_neutral": 3.0},
        "clutter": {"desk": DESK_CLUTTER},
        "lone_ok": ["plant", "water_cooler", "bench"],
        "notes": "O1 Co-op front office: the reception counter, waiting bench and the receptionist's seat are map-built "
                 "(the DeskCashO1 pickup sits on the counter). Tide / shift boards, the harbour clock, a cooler.",
    },
    "plant_refrigeration": {
        "purpose": "plant", "min_density": 0.08, "max_density": 1.0, "min_props": 9, "salt": 202,
        "required": ["compressor", "tank", "control_panel", "breaker_panel", "gas_cylinders", "fire_extinguisher",
                     "light_fixture"],
        "optional": {"tote": 1, "shelving": 0.8, "hose_reel": 0.6},
        "assets": {**DOCK_ASSETS, "breaker_panel": ["prop_breaker_panel"], "gas_cylinders": ["prop_gas_cylinders"],
                   "shelving": ["prop_shelving_parts"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 4.5},
        "lone_ok": ["compressor", "tank", "control_panel", "tote", "gas_cylinders"],
        "notes": "PL ammonia plant: the three screw compressors, the receiver and the control panel are map-built. "
                 "The culvert grate (vent exit) and its link stay clear. 4000 K fluorescents, green panel LEDs.",
    },
    "workshop_forklift": {
        "purpose": "workshop", "min_density": 0.08, "max_density": 1.0, "min_props": 8, "salt": 203,
        "required": ["forklift", "rack", "counter_service", "tool_wall", "fire_extinguisher", "light_fixture"],
        "optional": {"shelving": 1, "crate": 0.8, "pallet": 0.6},
        "assets": {**DOCK_ASSETS, "tool_wall": ["prop_tool_wall"], "shelving": ["prop_shelving_parts"],
                   "crate": ["prop_crate_wood"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 4.5},
        "lone_ok": ["forklift", "rack", "shelving", "crate"],
        "notes": "WS forklift charging: the two forklifts on charge, the battery rack and the tool bench are map-built.",
    },
    "janitor_dockside": {
        "purpose": "janitor", "min_density": 0.4, "max_density": 4.0, "min_props": 3, "salt": 204,
        "required": ["mop_sink", "shelving", "light_fixture"],
        "optional": {"mop_bucket": 1, "cleaning_cart": 0.5},
        "assets": {"mop_bucket": ["prop_mop_bucket"], "cleaning_cart": ["prop_cleaning_cart"],
                   "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.0},
        "notes": "J: mop sink and the chemical shelf are map-built.",
    },
    "packing_hall": {
        "purpose": "warehouse", "min_density": 0.04, "max_density": 0.4, "min_props": 12, "salt": 205,
        "required": ["conveyor", "counter_service", "ice_machine", "fish_crates", "hose_reel", "fire_extinguisher",
                     "light_fixture"],
        "optional": {"fish_boxes": 2, "pallet": 1, "pallet_wrapped": 0.8, "pallet_jack": 0.5, "tote": 0.5},
        "assets": {**DOCK_ASSETS, "light_fixture": ["prop_led_batten_cold"]},
        "ceiling": {"prop_led_batten_cold": 4.5},
        "clutter": {"floor": FLOOR_DOCK},
        "lone_ok": ["conveyor", "ice_machine", "fish_crates", "pallet_wrapped", "pallet", "tote", "pallet_jack", "fish_boxes"],
        "notes": "PK chilled packing hall: the roller conveyor, the two stainless tables, the ice machine and the crate "
                 "stacks are map-built; the product / burn point (prod_packing) and the quay doors stay clear.",
    },
    "marshalling_hall": {
        "purpose": "warehouse", "min_density": 0.04, "max_density": 0.12, "min_props": 12, "salt": 206,
        "required": ["crate", "pallet_jack", "pallet_wrapped", "fire_extinguisher", "light_fixture"],
        "optional": {"pallet": 1, "tote": 0.5, "cone": 0.5},
        "assets": {**DOCK_ASSETS, "crate": ["prop_shipping_crate_h120"], "light_fixture": ["prop_highbay_led"]},
        "ceiling": {"prop_highbay_led": 6.0},
        "lone_ok": ["crate", "pallet_jack", "pallet_wrapped", "pallet", "tote", "cone", "desk", "chair"],
        "notes": "H dispatch staging (lead G2 review): the open floor x 28.6-42.4 stays empty between the map-built "
                 "crate banks; wrapped pallets by the roller doors. 5000 K high bays (half on).",
    },
    "cold_store_racked": {
        "purpose": "warehouse", "min_density": 0.03, "max_density": 0.2, "min_props": 8, "salt": 207,
        "required": ["rack", "pallet_wrapped", "fire_extinguisher", "light_fixture"],
        "optional": {"pallet": 1, "fish_crates": 0.6},
        "assets": {**DOCK_ASSETS, "light_fixture": ["prop_led_batten_cold"]},
        "ceiling": {"prop_led_batten_cold": 4.7},
        "lone_ok": ["rack", "pallet_wrapped", "pallet", "fish_crates"],
        "notes": "C1 / C2 freezer chambers: the double-sided racking rows are map-built (3 m aisles kept clear). Wrapped "
                 "pallets against the walls, 6000 K battens over the aisles.",
    },
    "cold_store_racked_b": {
        "purpose": "warehouse", "min_density": 0.02, "max_density": 0.1, "min_props": 5, "salt": 217,
        "required": ["rack", "fish_boxes", "fire_extinguisher", "light_fixture"],
        "optional": {"pallet": 1, "pallet_jack": 0.5},
        "assets": {**DOCK_ASSETS, "light_fixture": ["prop_led_batten_cold"]},
        "ceiling": {"prop_led_batten_cold": 4.7},
        "lone_ok": ["rack", "fish_boxes", "pallet", "pallet_jack"],
        "notes": "C2 (lead DB G2 review: tell the chambers apart): half-empty, stacked fish boxes instead of C1's "
                 "wrapped pallets and crates, bare steel panels, colder light. Racking rows map-built as in C1.",
    },
    "cold_store_aisle": {
        "purpose": "warehouse", "min_density": 0.05, "max_density": 0.4, "min_props": 4, "salt": 208,
        "required": ["fire_extinguisher", "light_fixture"],
        "optional": {"fish_boxes": 1},
        "assets": {**DOCK_ASSETS, "light_fixture": ["prop_led_batten_cold"]},
        "ceiling": {"prop_led_batten_cold": 3.5},
        "lone_ok": ["fish_boxes"],
        "notes": "SP spine aisle: strip curtains both ends, the chamber doors; only wall-hung kit and battens.",
    },
    "strongroom_freezer": {
        "purpose": "vault", "min_density": 0.04, "max_density": 0.8, "min_props": 3, "salt": 209,
        "required": ["shelving", "light_fixture"],
        "optional": {"fish_crates": 1},
        "assets": {**DOCK_ASSETS, "light_fixture": ["prop_bulkhead_caged"]},
        "ceiling": {"prop_bulkhead_caged": 8.0},
        "lone_ok": ["shelving", "fish_crates"],
        "notes": "SR blast-freezer strongroom: freezer shelving (map-built), one caged bulkhead; the cash pallets / fish "
                 "blocks are the cash_location variant.",
    },
    "quay_dock": {
        "purpose": "warehouse", "min_density": 0.04, "max_density": 0.3, "min_props": 10, "salt": 210,
        "required": ["pallet_wrapped", "wrapping_machine", "forklift", "hose_reel", "fire_extinguisher", "light_fixture"],
        "optional": {"pallet": 1.2, "fish_crates": 0.8, "pallet_jack": 0.5, "tote": 0.4},
        "assets": {**DOCK_ASSETS, "light_fixture": ["prop_highbay_led"]},
        "ceiling": {"prop_highbay_led": 5.5},
        "clutter": {"floor": FLOOR_DOCK},
        "lone_ok": ["pallet_wrapped", "wrapping_machine", "forklift", "pallet", "fish_crates", "pallet_jack", "tote",
                    "fish_boxes"],
        "notes": "AN quay dock: the wrapped pallets, the wrapper and the forklift are map-built; the vault door, the "
                 "quay roller doors and the strip curtain stay clear.",
    },
    "count_room_cash": {
        "purpose": "cash_office", "min_density": 0.3, "max_density": 1.8, "min_props": 9, "salt": 211,
        "required": ["counter_service", "chair", "note_counter", "shelving", "file_cabinet", "light_fixture"],
        "optional": {"bin": 1, "box": 1, "picture": 0.5},
        "assets": {**OFFICE_ASSETS, "note_counter": ["prop_note_counter"], "shelving": ["prop_shelving_boxes"],
                   "file_cabinet": ["prop_file_cabinet"]},
        "ceiling": {"prop_ceiling_panel_neutral": 3.0},
        "lone_ok": ["shelving", "file_cabinet"],
        "notes": "M1 count room (doc kit count_room; the shared count_room kit is an office kit): the counting table "
                 "and its chair are map-built; money counters on the table; the cash cage variant and the lift door clear.",
    },
    "gatehouse": {
        "purpose": "office", "min_density": 0.3, "max_density": 1.8, "min_props": 6, "salt": 212,
        "required": ["counter_service", "chair", "heater", "light_fixture"],
        "optional": {"bin": 1, "picture": 0.8, "fire_extinguisher": 0.8, "clock": 0.6},
        "assets": {**OFFICE_ASSETS, "heater": ["prop_radiator_heater"], "clock": ["prop_clock_harbor"]},
        "ceiling": {"prop_ceiling_panel_neutral": 3.0},
        "clutter": {"desk": DESK_CLUTTER},
        "notes": "GH: the weighbridge console (gate controls, desk clutter), the gate man's seat and the heater are map-built.",
    },
    "net_store": {
        "purpose": "storage", "min_density": 0.15, "max_density": 1.2, "min_props": 7, "salt": 213,
        "required": ["nets", "rope_reel", "fish_boxes", "life_ring", "light_fixture"],
        "optional": {"fish_boxes": 1, "tote": 0.5, "pallet": 0.6},
        "assets": {**DOCK_ASSETS, "nets": ["prop_net_pile"], "rope_reel": ["prop_rope_reels"],
                   "life_ring": ["prop_life_ring"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 4.0},
        "lone_ok": ["nets", "rope_reel", "fish_boxes", "tote", "pallet"],
        "notes": "QS quay net store (holdout H3): net piles and rope reels are map-built; the pontoon window and both "
                 "doors stay clear.",
    },
    "exterior_yard": {
        "purpose": "exterior", "min_density": 0.004, "max_density": 0.3, "min_props": 12, "salt": 214,
        "required": ["container", "vehicle", "ice_bins", "lamp_post"],
        "lone_ok": ["container", "vehicle", "ice_bins", "lamp_post", "kerb", "cone", "pallet", "tote", "barrier", "bollard",
                    "skip", "railing", "gangway", "loot_spawn"],
        "notes": "X1 yard: containers K1-K6 + D1, the reach stacker, the reefer trailer, ice-bin pallets and the sodium "
                 "masts are map-built; cones, pallet stacks and totes in clusters at the container ends (direct props).",
    },
    "exterior_lane": {
        "purpose": "exterior", "min_density": 0.004, "max_density": 0.3, "min_props": 3, "salt": 215,
        "required": ["vehicle", "skip"],
        "lone_ok": ["vehicle", "skip", "lamp_post", "pallet", "tote", "cone", "bin_street", "loot_spawn"],
        "notes": "X2 west lane: the flatbed and the skips are map-built.",
    },
    "exterior_apron": {
        "purpose": "exterior", "min_density": 0.004, "max_density": 0.3, "min_props": 5, "salt": 216,
        "required": ["forklift", "bollard"],
        "lone_ok": ["forklift", "bollard", "lamp_post", "pallet", "tote", "cone", "life_ring", "ice_bins"],
        "notes": "X3 east apron: the forklift and the quay bollards are map-built; life rings on the dock wall.",
    },
    "exterior_quay": {
        "purpose": "exterior", "min_density": 0.004, "max_density": 0.3, "min_props": 8, "salt": 217,
        "required": ["bollard", "nets", "ice_bins"],
        "lone_ok": ["bollard", "nets", "ice_bins", "lamp_post", "pallet", "tote", "fish_crates", "rope_reel", "life_ring",
                    "boat", "loot_spawn"],
        "notes": "X4 quay, pontoon and landing stage: bollards, net stacks and ice-bin pallets are map-built.",
    },
}
