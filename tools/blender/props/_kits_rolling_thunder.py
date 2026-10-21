"""Rolling Thunder variants of shared dressing kits (RT-C2, D-147 reuse-first). Imported by _kits.py, which writes every
kit .tres.

docs/process/next_heist_rolling_thunder.md §3c names 8 kit variants (the OF way, _kits_ostrander.py): each is its base
kit with the RT room's purpose (validate_level density: a kit's purpose must be its room's), `seed_id` = the base id,
and the §3c props pinned for the room (the booth's heater, the plant room's switchboard, the site office's plan chest
and whiteboard, the cabin WC's pedestal basin, the tool store's tool wall and gas cylinders, the yard's tote and
ashtray, the underpass's caged bulkheads). The shared kits stay unchanged. `car_park_roof` (from the new kit
`car_park_deck`) waits for that kit (RT-C2 new-kit batch); the roof's purpose is kit-exempt until then.
Bases that are hand-written .tres (restroom_multi, GN-C2) are read from game/world/kits/.
"""

from __future__ import annotations

import copy
import pathlib
import re

KITS_DIR = pathlib.Path(__file__).resolve().parents[3] / "game" / "world" / "kits"

# variant id -> (base kit, room purpose, changes)
VARIANTS = {
    "attendant_booth": (
        "security_office",
        "office",
        {
            "required": ["desk", "chair", "monitor", "heater", "key_cabinet", "light_fixture"],
            "optional": {"file_cabinet": 1, "bin": 1, "picture": 1},
            "assets_add": {"heater": ["prop_radiator_heater"], "key_cabinet": ["prop_key_cabinet"]},
            "clutter_items_add": {"desk": {"kettle": 1}},
            "min_props": 8,
            "notes": "RT AB car-park attendant booth (5 x 6 m, windows N and W): the attendant's desk and chair are "
            "map-built (BoothDesk, a seated spawn); the kit adds the heater, key cabinet, monitor and kettle.",
        },
    ),
    "plant_carpark": (
        "plant_room",
        "plant",
        {
            "required": ["boiler", "tank", "switchboard", "light_fixture"],
            "optional": {"ahu": 0.5, "ups": 1, "shelving": 0.5, "fire_extinguisher": 1, "box": 0.6},
            "assets_add": {"switchboard": ["prop_switchboard"]},
            "lone_ok_add": ["switchboard"],
            "notes": "RT CPL car-park plant room: boiler, water tank, switchboard; the goods-lift breaker "
            "(LiftBreaker, a gameplay wall mount) is the map's.",
        },
    ),
    "site_office": (
        "office_small",
        "office",
        {
            "required": ["desk", "chair", "plan_chest", "whiteboard", "coat_rail", "light_fixture"],
            "optional": {"file_cabinet": 1, "bin": 1},
            "assets_add": {
                "desk": ["prop_desk_office"],
                "chair": ["prop_chair_office"],
                "whiteboard": ["prop_whiteboard"],
            },
            "clutter_items_add": {"desk": {"kettle": 0.8}},
            "lone_ok_add": ["plan_chest", "coat_rail"],
            "notes": "RT C1 site office cabin (3 x 9 m): desk, plan chest, whiteboard, coat rail, kettle.",
        },
    ),
    "site_wc": (
        "restroom_multi",
        "restroom",
        {
            "assets_add": {"toilet": ["prop_toilet"], "sink": ["prop_basin_pedestal"]},
            "notes": "RT C3 site WC cabin: two WCs, pedestal basin, mirror.",
        },
    ),
    "site_tool_store": (
        "storage_supplies",
        "storage",
        {
            "required": ["shelving", "tool_wall", "gas_cylinders", "box", "light_fixture"],
            "optional": {"pallet": 0.8, "box": 1.5, "crate": 0.8},
            "counts": {"shelving": [2, 3]},
            "assets_set": {
                "shelving": ["prop_shelving_parts"],
                "box": ["prop_box_small", "prop_box_stack"],
                "crate": ["prop_crate_wood"],
            },
            "notes": "RT C4 site tool store cabin: parts shelving, the tool wall, gas cylinders, boxes.",
        },
    ),
    "exterior_yard_small": (
        "exterior_alley",
        "exterior",
        {
            "required": ["pallet", "crate", "tote", "wall_lamp", "ashtray"],
            "optional": {"pallet": 1, "crate": 1, "box": 1, "hvac": 1},
            "counts": {},
            "assets_set": {
                "pallet": ["prop_pallet", "prop_pallet_loaded"],
                "crate": ["prop_crate_wood"],
                "box": ["prop_box_small", "prop_box_stack"],
                "tote": ["prop_ibc_tote"],
            },
            "lone_ok_add": ["pallet", "crate", "tote", "ashtray", "hvac", "dumpster"],
            "notes": "RT YD diner yard (20 x 8 m): the bins (body_container) and the gates are the map's; the kit adds "
            "pallets, crates, the waste-oil tote, the back-door lamp and an ashtray stand.",
        },
    ),
    "exterior_underpass": (
        "exterior_lane",
        "exterior",
        {
            "required": ["light_fixture", "barrier"],
            "lone_ok_add": ["light_fixture", "barrier", "bollard"],
            "notes": "RT X2 Tannery underpass and the east cut: caged bulkheads and cold battens under "
            "the rail bridge, barriers at the sidewalk ramps (placed from fixed tables, rt_dress_data.gd).",
        },
    ),
}

# The 7 new RT kits of §3c (RT-C2 batch 2), assembled from existing catalog props only. A §3c "new generator" a kit
# cannot place yet is named in its notes (car_park_deck: prop_car_park_barrier, bay lines; diner_dining:
# prop_diner_booth; kitchen_commercial: prop_cookline; site_frame_*: prop_scaffold, prop_site_clutter; exterior_site:
# prop_rt_tower_crane, plywood_painted). Open-air rooms (the frame, the site yard) are dressed from fixed tables
# (rt_dress_data.gd, the OF way); the kit sets their required kinds and densities.
NEW_KITS = {
    "car_park_deck": {
        "purpose": "car_park",
        "min_density": 0.015,
        "max_density": 0.3,
        "min_props": 10,
        "salt": 4711,
        "required": ["light_fixture", "fire_extinguisher"],
        "optional": {"exit_sign": 1},
        "counts": {"fire_extinguisher": (3, 4)},
        "assets": {"light_fixture": ["prop_led_batten_cold"], "exit_sign": ["prop_exit_sign"]},
        "ceiling": {"prop_led_batten_cold": 6.0},
        "lone_ok": ["car", "fire_extinguisher", "exit_sign", "light_fixture", "safe", "bag_lift"],
        "notes": "RT CP-G / CP-2 car-park decks: cold LED battens on a 6 m grid under the deck above, extinguishers "
        "on the walls, exit signs over the doors; the parked cars (veh_car_sedan_*) are the map's (catalog art on "
        "the G1 boxes). No floor props: the aisles and ramps stay a drive. Waits: prop_car_park_barrier, bay lines.",
    },
    "diner_dining": {
        "purpose": "restaurant",
        "min_density": 0.12,
        "max_density": 1.0,
        "min_props": 12,
        "salt": 4712,
        "required": ["register", "table", "chair", "light_fixture"],
        "optional": {"plant": 0.5, "bin": 0.5},
        "counts": {"table": (1, 2)},
        "assets": {
            "light_fixture": ["prop_downlight"],
            "table": ["prop_table_round_d120"],
            "chair": ["prop_chair_break"],
            "bin": ["prop_bin_small"],
            "plant": ["prop_plant_tall"],
        },
        "ceiling": {"prop_downlight": 2.6},
        "lone_ok": ["display_case", "plant"],
        "notes": "RT DR Halloran's dining room: the counter (prop_counter_sales art) with the till on it, round "
        "tables and chairs beside the map's three customer tables, downlights (prop_pendant_brass hangs to 1.05 m "
        "under the 3.0 m ceiling, so not here), the pie case and the counter stools from fixed tables. Waits: "
        "prop_diner_booth (no pair seat exists), the HALFWAY neon (prop_neon_vossberg variant).",
    },
    "kitchen_commercial": {
        "purpose": "kitchen",
        "min_density": 0.25,
        "max_density": 1.8,
        "min_props": 10,
        "salt": 4713,
        "required": ["fridge", "kitchen_counter", "wall_cabinet", "microwave", "bin", "shelving", "light_fixture"],
        "optional": {"fire_extinguisher": 1, "box": 0.6},
        "assets": {
            "bin": ["prop_bin_kitchen"],
            "shelving": ["prop_shelving_parts"],
            "light_fixture": ["prop_ceiling_panel_neutral"],
            "box": ["prop_box_small"],
        },
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "notes": "RT K diner kitchen: fridge, prep counter with the microwave and wall cabinets, dry-goods shelving, "
        "kitchen bin; the prep table (prop_packing_table_steel art) is the map's. Waits: prop_cookline (the G1 "
        "Cookline box stays greybox), prop_door_slide_coldstore (dressing).",
    },
    "function_room": {
        "purpose": "restaurant",
        "min_density": 0.12,
        "max_density": 1.0,
        "min_props": 12,
        "salt": 4714,
        "required": ["table", "chair", "counter_bar", "light_fixture"],
        "optional": {"plant": 0.8},
        "counts": {"table": (2, 3), "chair": (6, 8)},
        "assets": {
            "table": ["prop_table_break"],
            "chair": ["prop_chair_break"],
            "counter_bar": ["prop_bar_lounge_w300"],
            "light_fixture": ["prop_ceiling_panel_neutral"],
            "plant": ["prop_plant_tall"],
        },
        "ceiling": {"prop_ceiling_panel_neutral": 2.6},
        "notes": "RT U1 upstairs function room: break tables with chairs beside the map's two long tables, the "
        "lounge bar on a wall, ceiling panels.",
    },
    "site_frame_ground": {
        "purpose": "exterior",
        "min_density": 0.01,
        "max_density": 0.3,
        "min_props": 6,
        "salt": 4715,
        "required": ["pallet", "forklift", "cone"],
        "lone_ok": ["pallet", "forklift", "cone", "formwork", "skip", "gas_cylinders"],
        "notes": "RT FG the frame's ground floor: loaded pallets in pairs, the forklift (for the dumper, D-149.6), "
        "cones; the formwork stacks are the map's (G1 boxes). Fixed tables (rt_dress_data.gd). Waits: "
        "prop_site_clutter (formwork / rebar / mixer), prop_scaffold.",
    },
    "site_frame_slab": {
        "purpose": "exterior",
        "min_density": 0.008,
        "max_density": 0.3,
        "min_props": 4,
        "salt": 4716,
        "required": ["pallet", "cone"],
        "lone_ok": ["pallet", "cone", "gas_cylinders"],
        "notes": "RT F1 the frame's first slab: block pallets (the map's G1 boxes, prop_pallet_loaded art) with a "
        "second pallet each, cones by the slab edge. Fixed tables. Waits: prop_scaffold (edge protection), "
        "prop_site_clutter.",
    },
    "exterior_site": {
        "purpose": "exterior",
        "min_density": 0.005,
        "max_density": 0.3,
        "min_props": 8,
        "salt": 4717,
        "required": ["lamp_post", "cone", "barrier", "light_fixture"],
        "lone_ok": [
            "lamp_post",
            "cone",
            "barrier",
            "light_fixture",
            "skip",
            "dumpster",
            "formwork",
            "pallet",
            "gas_cylinders",
            "landmark",
            "pole",
            "ladder",
            "vehicle",
        ],
        "notes": "RT X4 Tanner's Reach site yard: sodium masts, roadworks barriers with a hazard beacon, cones, gas "
        "cylinders by the cabins. Fixed tables. Waits: prop_rt_tower_crane (the G1 crane boxes), plywood_painted "
        "+ the hoarding graphic, prop_c4_box.",
    },
}

# the 8th variant (RT-C2 batch 2): the roof deck from the new car_park_deck
NEW_VARIANTS = {
    "car_park_roof": (
        "car_park_deck",
        "roof",
        {
            "required": ["street_lamp"],
            "optional": {},
            "counts": {"street_lamp": [4, 6]},
            "min_props": 6,
            "min_density": 0.004,
            "assets_set": {"street_lamp": ["prop_street_lamp"]},
            "ceiling": {},
            "lone_ok_add": ["street_lamp"],
            "notes": "RT CP-R the open roof deck: street lamps off the parapets (prop_street_lamp as the §3c lamp "
            "columns), the map's parked cars; no ceiling. Waits: the heli-pad marking (texgen decal).",
        },
    ),
}


def _tres_kit(kit_id: str) -> dict:
    """A hand-written DressingKit .tres as a _kits.py dict (flat fields only; refuses clutter groups)."""
    text = (KITS_DIR / f"{kit_id}.tres").read_text(encoding="utf-8")

    def field(name: str) -> str:
        m = re.search(rf"^{name} = (.*?)(?=^\w+ = |\Z)", text, re.M | re.S)
        if m is None:
            raise ValueError(f"{kit_id}.tres: no {name}")
        return m.group(1).strip()

    def names(s: str) -> list:
        return re.findall(r'&"([^"]+)"', s)

    if field("clutter_groups") != "{}":
        raise ValueError(f"{kit_id}.tres: clutter groups not supported")
    k = {
        "purpose": names(field("purpose"))[0],
        "min_density": float(field("min_density")),
        "max_density": float(field("max_density")),
        "min_props": int(field("min_props")),
        "salt": int(field("seed_salt")),
        "required": names(field("required_items")),
        "optional": {a: float(b) for a, b in re.findall(r'&"([^"]+)": ([\d.]+)', field("optional_items"))},
        "counts": {
            a: [int(x), int(y)] for a, x, y in re.findall(r'&"([^"]+)": Vector2i\((\d+), (\d+)\)', field("counts"))
        },
        "assets": {
            a: re.findall(r'"([^"]+)"', b)
            for a, b in re.findall(r'&"([^"]+)": PackedStringArray\(([^)]*)\)', field("assets"))
        },
        "ceiling": {a: float(b) for a, b in re.findall(r'"([^"]+)": ([\d.]+)', field("ceiling"))},
        "lone_ok": names(field("lone_ok_kinds")),
        "notes": field("notes").strip('"'),
    }
    return k


def rolling_thunder_kits(kits: dict) -> dict:
    out = {kid: copy.deepcopy(k) for kid, k in NEW_KITS.items()}
    for vid, (base, purpose, ch) in {**VARIANTS, **NEW_VARIANTS}.items():
        src = out if base in out else kits
        k = copy.deepcopy(src[base]) if base in src else _tres_kit(base)
        k["purpose"] = purpose
        k["seed_id"] = base
        for key in ("required", "optional", "counts", "min_props", "min_density", "ceiling"):
            if key in ch:
                k[key] = copy.deepcopy(ch[key])
        assets = k.setdefault("assets", {})
        for kind, ids in ch.get("assets_add", {}).items():
            assets[kind] = list(ids)
        for kind, ids in ch.get("assets_set", {}).items():
            assets[kind] = list(ids)
        for group, items in ch.get("clutter_items_add", {}).items():
            k["clutter"][group]["items"].update(items)
        if "lone_ok_add" in ch:
            k["lone_ok"] = sorted(set(k.get("lone_ok", [])) | set(ch["lone_ok_add"]))
        k["notes"] = f"Rolling Thunder ({purpose}), from {base}: " + ch["notes"]
        out[vid] = k
    return out
