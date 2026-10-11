"""Night Deposit dressing kits (C2 G2): one entry per kit id of docs/design/heists/night_deposit.md's
room list (Harbor Savings & Loan). Imported by _kits.py, which writes every kit .tres.

Same conventions as _kits.py: kinds are the catalog `kind` metas, `assets` pins the style (and, for
required kinds, the instance order), `ceiling` lays fixtures on a grid. Layout-relevant furniture
(teller counter, ATMs, deposit-box walls, the desks NPCs sit at, keycard / code-note surfaces) is
anchored by the map (night_deposit_dressing.gd ANCHORS); the kits fill around it. Gameplay prefabs
(camera station, safes, hack terminal, laser grids) are keep-outs.
"""

from __future__ import annotations

DESK_CLUTTER = {"anchors": ["desk"], "items": {"papers": 3, "mug": 1.5, "pen_cup": 1.5, "binders": 1, "notebook": 1.5},
                "count": (2, 3), "radius": 0.6}
FLOOR_BOH = {"anchors": ["wall", "corner"], "items": {"box": 3, "archive_box": 1, "bin": 1}, "count": (1, 2), "radius": 1.0}

BANK_KITS: dict[str, dict] = {
    "sally_port": {
        "purpose": "storage", "min_density": 0.25, "max_density": 1.6, "min_props": 8, "salt": 41,
        "required": ["cash_cage", "shelving", "dolly", "fire_extinguisher", "pallet", "light_fixture"],
        "optional": {"box": 1.5, "crate": 0.6, "bin": 0.5, "switch": 0.6},
        "counts": {"cash_cage": (2, 2)},
        "assets": {"shelving": ["prop_shelving_boxes"], "light_fixture": ["prop_fluorescent"], "bin": ["prop_bin_kitchen"],
                   "pallet": ["prop_pallet"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "clutter": {"floor": FLOOR_BOH},
        "notes": "G1 armoured-car transfer room: cash trolleys, shelving, hand truck, the roller door bay kept clear "
                 "(keep-out), the cash lift shaft in the NE corner (keep-out). 4000 K fluorescent.",
    },
    "security_office_bank": {
        "purpose": "security_room", "min_density": 0.4, "max_density": 1.8, "min_props": 9, "salt": 42,
        "required": ["lockers", "credenza", "key_cabinet", "coffee_machine", "bulletin_board", "light_fixture"],
        "optional": {"file_cabinet": 1, "bin": 1, "picture": 0.6, "water_cooler": 0.6},
        "assets": {"bin": ["prop_bin_office"], "picture": ["prop_notice_frame"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"credenza": {"anchors": ["credenza"], "items": {"binders": 1, "mug": 1.5, "papers": 1}, "count": (1, 2),
                                 "radius": 0.4}},
        "notes": "G3 (Halden Security): the camera station prefab on the west wall and the operator's NPC seat (task "
                 "chair, 0.47 m, D-063) come from the map. Key cabinet over the credenza (kc_security), guard lockers, "
                 "coffee. Dim panels; monitor glow from the station.",
    },
    "storage_supplies": {
        "purpose": "storage", "min_density": 0.3, "max_density": 1.6, "min_props": 8, "salt": 43,
        "required": ["shelving", "archive_box", "box", "step_ladder", "light_fixture"],
        "optional": {"pallet": 0.8, "file_cabinet": 0.8, "box": 1.5, "bin": 0.4},
        "counts": {"shelving": (3, 4)},
        "assets": {"shelving": ["prop_shelving_boxes", "prop_shelving_archive"], "light_fixture": ["prop_fluorescent"],
                   "pallet": ["prop_pallet_loaded"], "bin": ["prop_bin_office"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "clutter": {"floor": FLOOR_BOH},
        "notes": "G6 bank supplies + archive overflow. The srv_ground variant rack + hack terminal (NE) is a keep-out.",
    },
    "teller_line": {
        "purpose": "office", "min_density": 0.3, "max_density": 1.5, "min_props": 16, "salt": 44,
        "required": ["counter_transaction", "stool", "note_counter", "credenza", "file_cabinet", "printer", "light_fixture"],
        "optional": {"file_cabinet": 1, "bin": 1, "picture": 0.6, "credenza": 1},
        "counts": {"note_counter": (2, 3), "credenza": (2, 3)},
        "assets": {"stool": ["prop_stool_teller"], "bin": ["prop_bin_office"], "picture": ["prop_notice_frame"],
                   "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"back": {"anchors": ["credenza"], "items": {"note_counter": 1.5, "binders": 1, "papers": 1.5, "mug": 1},
                             "count": (1, 2), "radius": 0.5},
                    "counter": {"anchors": ["counter_transaction"], "items": {"papers": 2, "note_counter": 1, "pen_cup": 1},
                                "count": (0, 1), "radius": 0.5}},
        "lone_ok": ["stool"],
        "notes": "G8 teller workroom: the 1.05 m transaction counter (6 stations) is anchored along the hall; stools, note "
                 "counters, the back counters (credenzas) along the corridor wall, files and a printer. No tellers at "
                 "night (D-063): the stools are anchored pushed back against the wall; the map keeps the staff walkway "
                 "along the counter clear (keep-out).",
    },
    "banking_hall": {
        "purpose": "banking_hall", "min_density": 0.06, "max_density": 0.6, "min_props": 18, "salt": 45,
        "required": ["check_table", "stanchion", "bench", "plant", "picture", "slip_tray", "light_fixture"],
        "optional": {"plant": 1, "picture": 1, "bin": 0.6},
        "counts": {"plant": (2, 3), "picture": (2, 3)},
        "assets": {"plant": ["prop_plant_tall"], "picture": ["prop_wall_art_a", "prop_wall_art_c", "prop_wall_art_b"],
                   "bin": ["prop_bin_office"], "light_fixture": ["prop_pendant_brass", "prop_pendant_brass_off"]},
        "clutter": {"tables": {"anchors": ["check_table"], "items": {"slip_tray": 2, "pen_cup": 0.5}, "count": (1, 1), "radius": 0.4}},
        "lone_ok": ["check_table", "stanchion", "bench", "plant", "bin"],
        "notes": "G9 banking hall (night mode): check-writing tables, queue stanchions, waiting benches, the compass rose "
                 "(keep-out) and the brass pendants (night mode: a quarter lit) are anchored. Clocks are anchors too.",
    },
    "office_loan": {
        "purpose": "office", "min_density": 0.4, "max_density": 1.8, "min_props": 12, "salt": 46,
        "required": ["desk", "chair", "file_cabinet", "bookshelf", "picture", "desk_lamp", "plant", "monitor", "light_fixture"],
        "optional": {"picture": 1, "bin": 1, "credenza": 0.5},
        "counts": {"chair": (3, 3)},
        "assets": {"desk": ["prop_desk_bank"], "chair": ["prop_chair_task", "prop_chair_visitor", "prop_chair_visitor"],
                   "picture": ["prop_wall_art_a", "prop_wall_art_b"], "plant": ["prop_plant_tall"], "bin": ["prop_bin_office"],
                   "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"desk": DESK_CLUTTER},
        "notes": "G11 loan officer: free-standing desk (0.74 m) with the officer's task chair (0.47 m seat, D-063) and two "
                 "visitor chairs, files, bookshelf, art. Glass front to the hall, window to Wharf Lane.",
    },
    "office_manager_bank": {
        "purpose": "office", "min_density": 0.4, "max_density": 1.8, "min_props": 12, "salt": 47,
        "required": ["desk", "chair", "credenza", "bookshelf", "picture", "desk_lamp", "plant", "monitor", "light_fixture"],
        "optional": {"picture": 1, "file_cabinet": 0.6},
        "counts": {"chair": (3, 3)},
        "assets": {"desk": ["prop_desk_bank"], "chair": ["prop_chair_task", "prop_chair_visitor", "prop_chair_visitor"],
                   "picture": ["prop_wall_art_c", "prop_wall_art_a", "prop_wall_art_b"], "plant": ["prop_plant_tall"],
                   "rug": ["prop_rug_rect"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"desk": DESK_CLUTTER, "credenza": {"anchors": ["credenza"], "items": {"binders": 1, "table_lamp": 1,
                                                                                           "plant_small": 1}, "count": (1, 2),
                                                       "radius": 0.4}},
        "notes": "G12 branch manager: desk at 0.74 m with the manager's NPC seat (task chair 0.47 m, D-063: desk_work / "
                 "phone_seated), credenza, bookshelf, art. The small safe (xl_manager_safe) is a gameplay prefab.",
    },
    "atm_vestibule": {
        "purpose": "lobby", "min_density": 0.4, "max_density": 2.0, "min_props": 8, "salt": 48,
        "required": ["atm", "night_drop", "bin", "leaflet_rack", "light_fixture"],
        "optional": {"leaflet_rack": 0.6, "picture": 0.5},
        "assets": {"bin": ["prop_bin_office"], "picture": ["prop_notice_frame"], "light_fixture": ["prop_ceiling_panel_cool"]},
        "ceiling": {"prop_ceiling_panel_cool": 1.8},
        "notes": "G13 24 h ATM vestibule (PUBLIC): the two ATMs and the night depository head are anchored (saw targets "
                 "on the ATMs, D-057). Cool LED, the green-white jewel on the corner.",
    },
    "cash_transfer": {
        "purpose": "storage", "min_density": 0.3, "max_density": 1.6, "min_props": 8, "salt": 49,
        "required": ["cash_cage", "shelving", "packing_bench", "pallet", "light_fixture"],
        "optional": {"box": 1, "bin": 0.5, "fire_extinguisher": 0.6},
        "counts": {"cash_cage": (2, 3), "shelving": (2, 2)},
        "assets": {"shelving": ["prop_shelving_boxes"], "pallet": ["prop_pallet"], "light_fixture": ["prop_fluorescent"],
                   "bin": ["prop_bin_kitchen"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "clutter": {"bench": {"anchors": ["packing_bench"], "items": {"papers": 1, "note_counter": 1, "binders": 0.5},
                              "count": (1, 2), "radius": 0.5}},
        "notes": "B1 cash transfer: the cash lift landing (shaft keep-out, NE), cash cages on wheels, sealed-bag shelving "
                 "and a sorting bench. 5000 K.",
    },
    "locker_room": {
        "purpose": "locker_room", "min_density": 0.3, "max_density": 1.8, "min_props": 9, "salt": 50,
        "required": ["lockers", "bench", "sink", "mirror", "bin", "light_fixture"],
        "optional": {"hand_dryer": 1, "soap_dispenser": 1, "bag": 0.6},
        "counts": {"lockers": (3, 4), "sink": (2, 2)},
        "assets": {"bench": ["prop_bench_corridor"], "mirror": ["prop_mirror_restroom"], "bin": ["prop_bin_small"],
                   "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "lone_ok": ["bench"],
        "notes": "B2 staff locker room (the branch's only restrooms are the B13 WCs): lockers, bench, sink row with "
                 "mirrors, dryer.",
    },
    "restroom_wc": {
        "purpose": "restroom", "min_density": 0.4, "max_density": 3.0, "min_props": 4, "salt": 51,
        "required": ["toilet", "paper_dispenser", "light_fixture"],
        "optional": {"bin": 1, "grab_bar": 0.5},
        "assets": {"bin": ["prop_bin_small"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.0},
        "notes": "B13: two WC cubicles (toilets + partition anchored by the map against the north wall).",
    },
    "plant_room": {
        "purpose": "plant", "min_density": 0.3, "max_density": 1.6, "min_props": 8, "salt": 52,
        "required": ["boiler", "ahu", "tank", "breaker_panel", "light_fixture"],
        "optional": {"ups": 1, "shelving": 0.5, "fire_extinguisher": 1, "box": 0.6},
        "assets": {"shelving": ["prop_shelving_parts"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "lone_ok": ["tank", "boiler", "ahu"],
        "notes": "B3 plant: boiler, air handler, hot-water tank (anchored), breaker panel. The areaway door (north) and "
                 "its swing stay clear.",
    },
    "server_room": {
        "purpose": "server_room", "min_density": 0.3, "max_density": 1.8, "min_props": 9, "salt": 53,
        "required": ["server_rack", "ups", "desk", "chair", "monitor", "light_fixture"],
        "optional": {"it_rack": 1, "box": 0.6, "fire_extinguisher": 0.8, "bin": 0.5},
        "counts": {"server_rack": (3, 4)},
        "assets": {"desk": ["prop_desk_office"], "chair": ["prop_chair_office"], "bin": ["prop_bin_office"],
                   "light_fixture": ["prop_ceiling_panel_cool"]},
        "ceiling": {"prop_ceiling_panel_cool": 2.4},
        "clutter": {"desk": {"anchors": ["desk"], "items": {"keyboard": 1, "papers": 1, "mug": 1}, "count": (1, 2), "radius": 0.5}},
        "notes": "B4: rack rows, UPS, a console desk. The srv_basement hack terminal (north wall) is a keep-out.",
    },
    "corridor_inspection": {
        "purpose": "corridor", "min_density": 0.05, "max_density": 1.2, "min_props": 4, "salt": 54,
        "required": ["convex_mirror", "fire_extinguisher", "light_fixture"],
        "optional": {"switch": 0.6, "outlet": 0.6},
        "counts": {"convex_mirror": (2, 2)},
        "assets": {"light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 3.0},
        "notes": "B7 / B10 vault inspection passages (dead ends with a reason): convex mirrors, wall-mounted only.",
    },
    "vault_antechamber": {
        "purpose": "vault", "min_density": 0.1, "max_density": 1.5, "min_props": 4, "salt": 55,
        "required": ["bench", "fire_extinguisher", "light_fixture"],
        "optional": {"picture": 0.4},
        "assets": {"bench": ["prop_vault_bench"], "picture": ["prop_notice_frame"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.6},
        "lone_ok": ["bench"],
        "notes": "B8: the viewing bench behind the laser plane is anchored; the laser grid, the time-lock panel and the "
                 "round vault door are gameplay prefabs (keep-outs).",
    },
    "vault_main": {
        "purpose": "vault", "min_density": 0.1, "max_density": 1.2, "min_props": 10, "salt": 56,
        "required": ["deposit_boxes", "table", "cash_cage", "light_fixture"],
        "optional": {"cash_cage": 0.5},
        "assets": {"table": ["prop_vault_table"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.2},
        "lone_ok": ["table", "cash_cage", "loot_spawn"],
        "notes": "B9: deposit-box walls east and west (anchored; their saw points are drill_point prefabs), the cash cage "
                 "(map) with the cage loot, the Co-op pallet. Bright 4000 K strips.",
    },
    "count_room": {
        "purpose": "office", "min_density": 0.4, "max_density": 1.8, "min_props": 12, "salt": 57,
        "required": ["desk", "chair", "note_counter", "packing_bench", "cash_cage", "shelving", "light_fixture"],
        "optional": {"file_cabinet": 0.8, "bin": 0.6},
        "counts": {"desk": (2, 2), "chair": (2, 2), "note_counter": (2, 3)},
        "assets": {"desk": ["prop_desk_office"], "chair": ["prop_chair_office"], "shelving": ["prop_shelving_boxes"],
                   "bin": ["prop_bin_office"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"desk": {"anchors": ["desk", "packing_bench"], "items": {"note_counter": 2, "papers": 1, "binders": 0.6},
                             "count": (1, 2), "radius": 0.5}},
        "notes": "B11 cash counting room: counting desks with note counters, the sealing bench, a cash trolley, shelving.",
    },
    "depository": {
        "purpose": "vault", "min_density": 0.15, "max_density": 1.5, "min_props": 5, "salt": 58,
        "required": ["cash_cage", "shelving", "light_fixture"],
        "optional": {"box": 1.5, "shelving": 0.6},
        "assets": {"shelving": ["prop_shelving_boxes"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "notes": "B12 night depository: the safe under the chute (prefab) and the night-drop bags (loot) are keep-outs. "
                 "No pallets: low pallets read as walkable floor but are navmesh obstructions.",
    },
    "exterior_lot": {
        "purpose": "exterior", "min_density": 0.005, "max_density": 0.3, "min_props": 6, "salt": 59,
        "required": ["street_lamp", "hvac", "pallet", "bin_street"],
        "optional": {"hvac": 1, "pallet": 1, "crate": 0.6, "box": 0.6},
        "counts": {"hvac": (2, 2)},
        "assets": {"street_lamp": ["prop_street_lamp_sodium"], "pallet": ["prop_pallet", "prop_pallet_loaded"]},
        "lone_ok": ["street_lamp", "bin_street", "car", "bollard", "hvac", "pallet", "crate", "box", "wall_lamp"],
        "notes": "X1 staff lot + alley: parked staff cars, sodium poles and the dumpster (prefab) are anchored; the van "
                 "slot E1, the escape zone and the areaway cage are keep-outs. Condensers and pallets on the facade.",
    },
    "exterior_harbor": {
        "purpose": "exterior", "min_density": 0.005, "max_density": 0.3, "min_props": 8, "salt": 60,
        "required": ["street_lamp", "bin_street", "bollard", "planter"],
        "optional": {"bollard": 1.5, "planter": 0.8},
        "counts": {"bollard": (2, 4)},
        "assets": {"street_lamp": ["prop_street_lamp_sodium"], "bollard": ["prop_bollard_steel"]},
        "lone_ok": ["street_lamp", "bin_street", "bollard", "planter", "car", "barrier", "bench"],
        "notes": "X2 Harbor Street, the quay and Wharf Lane: sodium lamps, parked cars, quay mooring bollards and benches "
                 "are anchored; the placer fills bins, bollards and planters along the facades.",
    },
}
