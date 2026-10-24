"""Afterhours kits (AH-C2, D-147 reuse-first). Imported by _kits.py, which writes every kit .tres.

The room list (docs/design/heists/afterhours.md; tools/levelcheck/plans/afterhours_emit_layout.py ROOM_KIT) names 13
kits. Rooms whose shared kit already fits keep it (G23 storage_supplies); the rest are AH kits:
purpose variants of shared kits (the OF / RT way: validate_level density wants the kit's purpose to be its room's,
`seed_id` = the base id) and new club kits for the front of house. The club's set pieces (bars, booths, the stage, the
DJ booth, the VIP sofa) are map-built G1 boxes with ENV D's prop_ah_* art (ah_dress_data.gd PROP_ART); these kits add
the dressing round them: velvet ropes and brass pendants in the foyer, the cigarette machine in the G7 alcove, the
door team's key cabinet and radio charger, the staff entrance's clock-in, the green room's bulb mirror.
"""

from __future__ import annotations

import copy

# variant id -> (base kit, room purpose, changes)
VARIANTS = {
    "green_room": (
        "dressing_room",
        "staff_room",
        {
            "required": ["mirror", "coat_rail", "light_fixture"],
            "optional": {"bench": 0.5, "side_table": 0.5, "plant": 0.3},
            "min_props": 4,
            "assets_add": {"mirror": ["prop_ah_bulb_mirror"], "coat_rail": ["prop_coat_rail"]},
            "lone_ok_add": ["mirror", "coat_rail"],
            "notes": "AH G11 green room: the DJs' bulb mirror and coat rail; the sofa and the flight cases are the map's "
            "(GreenRoomSofa, FlightCases).",
        },
    ),
    "storage_bar_stock": (
        "storage_supplies",
        "storage",
        {
            "required": ["shelving", "crate", "box", "light_fixture"],
            "optional": {"pallet": 0.6, "box": 1.5, "crate": 1.0},
            "assets_add": {"crate": ["prop_ah_crates"], "shelving": ["prop_shelving_boxes"]},
            "min_props": 6,
            "notes": "AH G10 bar stock room: bottle crates, boxed stock on shelving; the stock cage is the map's.",
        },
    ),
    "loading_bar": (
        "loading_bay",
        "loading",
        {
            "required": ["pallet", "crate", "shelving", "dolly", "light_fixture"],
            "optional": {"box": 1.2, "pallet": 0.8, "fire_extinguisher": 1},
            "assets_add": {"light_fixture": ["prop_fluorescent"], "crate": ["prop_ah_crates"]},
            "ceiling": {"prop_fluorescent": 3.0},
            "notes": "AH G21 loading bay: BOH fluorescents on a 3 m grid (doc zones: 5000 K), bottle crates, pallets, "
            "a dolly; the keg rack and the bottle bank are the map's. (The shared loading_bay has no fixture: the "
            "G2 review's loading shot was black.)",
        },
    ),
    "staff_entrance": (
        "service_lobby",
        "lobby",
        {
            "required": ["terminal", "bulletin_board", "fire_extinguisher", "light_fixture"],
            "optional": {"bin": 0.8, "picture": 1.0, "box": 0.6},
            "assets_add": {"terminal": ["prop_ah_clock_in"]},
            "lone_ok_add": ["terminal"],
            "min_props": 4,
            "notes": "AH G25 staff entrance: the clock-in terminal and card rack, the rota board, an extinguisher.",
        },
    ),
    "door_team_room": (
        "security_office",
        "staff_room",
        {
            "required": ["desk", "chair", "key_cabinet", "charger", "lockers", "light_fixture"],
            "optional": {"coffee_machine": 0.8, "bin": 1, "picture": 1},
            "assets_add": {"key_cabinet": ["prop_ah_key_hooks"], "charger": ["prop_ah_radio_charger"]},
            "lone_ok_add": ["key_cabinet", "charger"],
            "min_props": 8,
            "notes": "AH G24 door team room: the key board (prop_ah_key_hooks), the radio charger, lockers, the "
            "head of security's desk; the door log desk is the map's (DoorLogDesk).",
        },
    ),
    "private_lounge": (
        "lounge_exec",
        "living_room",
        {
            "required": ["sofa", "coffee_table", "rug", "floor_lamp", "light_fixture"],
            "optional": {"plant": 1, "picture": 1, "side_table": 0.8},
            "min_props": 6,
            "notes": "AH U12 Crale's private room: a sofa, a rug, lamps; the product shelving and the laser grid are "
            "the map's.",
        },
    ),
}

# The club's new kits (front of house), assembled from the library and ENV D's prop_ah_*.
NEW_KITS = {
    "club_hall": {
        "purpose": "hall",
        "min_density": 0.0,
        "max_density": 0.4,
        "min_props": 2,
        "salt": 4801,
        "required": ["fire_extinguisher"],
        "optional": {"bin": 1},
        "counts": {"fire_extinguisher": (2, 3)},
        "assets": {"fire_extinguisher": ["prop_fire_extinguisher"]},
        "ceiling": {},
        "lone_ok": ["fire_extinguisher", "bin"],
        "notes": "AH G6 the hall: the floor stays clear (the dancers, the stampede lanes); the stage, the DJ booth, "
        "the stacks, the bars and the truss rig are the map's; the kit adds extinguishers on the walls (an exit sign "
        "on the north wall lands behind the stage riser, 2.06 m over the floor: none). No ceiling grid (the club rig).",
    },
    "club_lounge": {
        "purpose": "bar",
        "min_density": 0.0,
        "max_density": 1.0,
        "min_props": 2,
        "salt": 4802,
        "required": ["vending", "fire_extinguisher"],
        "optional": {"plant": 0.6, "bin": 1},
        "assets": {"vending": ["prop_ah_cigarette_machine"], "plant": ["prop_plant_tall"]},
        "ceiling": {"prop_downlight": 3.0},
        "lone_ok": ["vending", "fire_extinguisher", "plant", "bin"],
        "notes": "AH G7 under the circle: the booths and high tables are the map's; the kit adds the cigarette "
        "machine (the alcove), an extinguisher and downlights in the circle's soffit.",
    },
    "club_foyer": {
        "purpose": "lobby",
        "min_density": 0.04,
        "max_density": 0.6,
        "min_props": 6,
        "salt": 4803,
        "required": ["stanchion", "plant", "picture", "light_fixture"],
        "optional": {"bench": 0.6, "plant": 1, "picture": 1},
        "counts": {"stanchion": (1, 2)},
        "assets": {
            "stanchion": ["prop_stanchion_velvet"],
            "plant": ["prop_plant_tall"],
            "picture": ["prop_wall_art_a", "prop_wall_art_b", "prop_wall_art_c"],
            "light_fixture": ["prop_pendant_brass"],
        },
        "ceiling": {"prop_pendant_brass": 3.0},
        "lone_ok": ["stanchion", "plant", "picture", "bench"],
        "notes": "AH G1 the foyer: velvet ropes to the hall doors, palms, framed posters, brass pendants (2700 K); "
        "the box office counter and the grand stair are the map's.",
    },
    "club_box_office": {
        "purpose": "reception",
        "min_density": 0.05,
        "max_density": 1.2,
        "min_props": 3,
        "salt": 4804,
        "required": ["chair", "coat_rail", "light_fixture"],
        "optional": {"bin": 1, "file_cabinet": 0.6},
        "assets": {"chair": ["prop_stool_teller"], "coat_rail": ["prop_coat_rail"], "light_fixture": ["prop_downlight"]},
        "ceiling": {"prop_downlight": 2.5},
        "lone_ok": ["chair", "coat_rail", "bin", "file_cabinet"],
        "notes": "AH G2 box office and cloakroom: the cashier's stool behind the counter (the map's, D's "
        "prop_ah_box_office_counter), the coat rail behind the hatch.",
    },
    "vip_balcony": {
        "purpose": "bar",
        "min_density": 0.0,
        "max_density": 0.8,
        "min_props": 2,
        "salt": 4805,
        "required": ["fire_extinguisher", "plant"],
        "optional": {"bin": 1, "plant": 1},
        "assets": {"plant": ["prop_plant_tall"]},
        "ceiling": {"prop_downlight": 3.0},
        "lone_ok": ["fire_extinguisher", "plant", "bin"],
        "notes": "AH U1 the balcony: the VIP booths along the brass rail are the map's; the kit adds palms, an "
        "extinguisher, downlights (the rail uplights are the lighting lane's).",
    },
    "vip_lounge": {
        "purpose": "bar",
        "min_density": 0.04,
        "max_density": 1.0,
        "min_props": 4,
        "salt": 4806,
        "required": ["armchair", "side_table", "floor_lamp", "plant"],
        "optional": {"armchair": 1, "plant": 1, "picture": 1},
        "assets": {
            "armchair": ["prop_armchair_club"],
            "plant": ["prop_plant_tall"],
            "picture": ["prop_wall_art_a", "prop_wall_art_b", "prop_wall_art_c"],
        },
        "ceiling": {"prop_downlight": 2.5},
        "lone_ok": ["armchair", "side_table", "floor_lamp", "plant", "picture"],
        "notes": "AH U2 the VIP lounge: club armchairs, side tables, lamps, palms; the VIP bar, the sofa and its "
        "coffee table are the map's (D's prop_ah_vip_sofa / prop_ah_vip_coffee_table).",
    },
}


def afterhours_kits(kits: dict) -> dict:
    out = {kid: copy.deepcopy(k) for kid, k in NEW_KITS.items()}
    for vid, (base, purpose, ch) in VARIANTS.items():
        k = copy.deepcopy(kits[base])
        k["purpose"] = purpose
        k["seed_id"] = base
        for key in ("required", "optional", "counts", "min_props", "min_density", "ceiling"):
            if key in ch:
                k[key] = copy.deepcopy(ch[key])
        assets = k.setdefault("assets", {})
        for kind, ids in ch.get("assets_add", {}).items():
            assets[kind] = list(ids)
        if "lone_ok_add" in ch:
            k["lone_ok"] = sorted(set(k.get("lone_ok", [])) | set(ch["lone_ok_add"]))
        k["notes"] = f"Afterhours ({purpose}), from {base}: " + ch["notes"]
        out[vid] = k
    return out
