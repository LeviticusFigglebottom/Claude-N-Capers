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
            "assets_add": {"desk": ["prop_desk_office"], "chair": ["prop_chair_office"]},
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
    out = {}
    for vid, (base, purpose, ch) in VARIANTS.items():
        k = copy.deepcopy(kits[base]) if base in kits else _tres_kit(base)
        k["purpose"] = purpose
        k["seed_id"] = base
        for key in ("required", "optional", "counts", "min_props"):
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
