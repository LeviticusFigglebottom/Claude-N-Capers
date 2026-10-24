#!/usr/bin/env python3
"""Glasshouse dressing kits (C1-07) -> game/world/kits/<id>.tres (DressingKit). System python:

    python3 tools/blender/props/_kits.py

One entry per kit id used in docs/design/heists/glasshouse.md (room list). Kinds are the `kind`
metas of the props catalog (game/world/props/prop_catalog.json); `assets` pins a kit's style
(and, for required kinds, the order of the instances); `ceiling` lays fixtures on a grid.
Densities count every prop the placer adds (incl. wall-mounted, ceiling fixtures and clutter);
rooms with gameplay prefabs (cases, safe, camera station) get those on top.
"""

from __future__ import annotations

import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
OUT = REPO / "game" / "world" / "kits"

DESK_CLUTTER = {"anchors": ["desk"], "items": {"papers": 3, "mug": 2, "pen_cup": 1.5, "binders": 1, "notebook": 1.5,
                                              "plant_small": 0.6}, "count": (2, 4), "radius": 0.6}
FLOOR_CLUTTER_OFFICE = {"anchors": ["wall", "door"], "items": {"bin": 2, "bag": 1, "box": 1}, "count": (0, 1), "radius": 0.8}
FLOOR_CLUTTER_STORE = {"anchors": ["wall", "door", "corner"], "items": {"box": 3, "crate": 1, "archive_box": 1}, "count": (1, 2), "radius": 1.0}

KITS: dict[str, dict] = {
    "storage_receiving": {
        "purpose": "storage", "min_density": 0.35, "max_density": 1.6, "min_props": 8, "salt": 11,
        "required": ["shelving", "packing_bench", "dolly", "mop_sink", "crate", "light_fixture"],
        "optional": {"box": 3, "pallet": 1.5, "shelving": 1.5, "bin": 0.5, "step_ladder": 0.5},
        "counts": {"shelving": (2, 2), "crate": (1, 2)},
        "assets": {"shelving": ["prop_shelving_boxes", "prop_shelving_parts"], "light_fixture": ["prop_fluorescent"],
                   "bin": ["prop_bin_kitchen"], "pallet": ["prop_pallet_loaded", "prop_pallet"]},
        "ceiling": {"prop_fluorescent": 2.2},
        "clutter": {"floor": FLOOR_CLUTTER_STORE, "bench": {"anchors": ["packing_bench"], "items": {"gift_boxes": 2, "papers": 1, "mug": 1},
                                                            "count": (1, 2), "radius": 0.5}},
        "notes": "G1 receiving: shelving, packing bench, dolly, mop sink, delivery crates. L-shaped room: pass the main "
                 "rectangle and a keep-out for the electrical closet corner. Alarm keypad by the back door is a prefab.",
    },
    "electrical_closet": {
        "purpose": "electrical", "min_density": 0.5, "max_density": 2.5, "min_props": 3, "salt": 12,
        "required": ["breaker_panel", "it_rack", "light_fixture"],
        "optional": {"box": 1, "shelving": 0.5},
        "assets": {"shelving": ["prop_shelving_parts"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.0},
        "notes": "G7: breaker panel, IT rack with router/switches (LEDs).",
    },
    "workshop_jeweler": {
        "purpose": "workshop", "min_density": 0.5, "max_density": 2.0, "min_props": 12, "salt": 13,
        "required": ["jeweler_bench", "task_lamp", "magnifier", "stool", "workbench", "polishing_machine",
                     "ultrasonic_cleaner", "tool_wall", "light_fixture"],
        "optional": {"shelving": 1.5, "bin": 0.7, "file_cabinet": 0.6, "picture": 0.4},
        "counts": {"jeweler_bench": (2, 2), "task_lamp": (2, 2), "stool": (2, 3)},
        "assets": {"shelving": ["prop_shelving_parts"], "light_fixture": ["prop_ceiling_panel_cool"], "bin": ["prop_bin_office"],
                   "picture": ["prop_notice_frame"]},
        "ceiling": {"prop_ceiling_panel_cool": 2.4},
        "clutter": {"bench": {"anchors": ["jeweler_bench", "workbench"], "items": {"tool_tray": 3, "papers": 1, "mug": 1, "notebook": 1},
                              "count": (1, 2), "radius": 0.5}},
        "lone_ok": ["safe"],
        "notes": "G2: the safe is a gameplay prefab on the north wall (pass it as a keep-out). Two jeweler benches with "
                 "task lamps + magnifiers, polishing machine and ultrasonic cleaner on the workbench, tool wall. 5000 K.",
    },
    "restroom_single": {
        "purpose": "restroom", "min_density": 0.4, "max_density": 2.2, "min_props": 7, "salt": 14,
        "required": ["toilet", "sink", "mirror", "grab_bar", "paper_dispenser", "soap_dispenser", "light_fixture"],
        "optional": {"hand_dryer": 2, "bin": 1},
        "counts": {"grab_bar": (1, 2)},
        "assets": {"mirror": ["prop_mirror_restroom"], "bin": ["prop_bin_small"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "notes": "G3/U3 accessible WC: toilet and vanity against walls (plumbing), grab bars + paper by the toilet, mirror "
                 "and soap over the vanity.",
    },
    "corridor_service": {
        "purpose": "corridor", "min_density": 0.05, "max_density": 1.2, "min_props": 3, "salt": 15,
        "required": ["fire_extinguisher", "exit_sign", "light_fixture"],
        "optional": {"switch": 1.5, "picture": 1.0, "thermostat": 0.5, "outlet": 1.0},
        "assets": {"picture": ["prop_notice_frame"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 3.0},
        "notes": "Back-of-house corridors and lobbies (G4, G10, U8): wall-mounted only, the floor stays clear "
                 "(>= 0.9 m service width). 4000 K panels. Exit signs centre at 2.32 m over doors.",
    },
    "janitor_closet": {
        "purpose": "storage", "min_density": 0.5, "max_density": 4.0, "min_props": 3, "salt": 16,
        "required": ["mop_sink", "light_fixture"],
        "optional": {"shelving": 3, "mop_bucket": 2},
        "assets": {"shelving": ["prop_shelving_cleaning"], "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.0},
        "notes": "G9 under the stair: mop sink, cleaning shelf, mop bucket. BODY_HIDE zone: keep 1 m² of floor free "
                 "(pass it as a keep-out).",
    },
    "sales_floor_jewelry": {
        "purpose": "sales_floor", "min_density": 0.25, "max_density": 0.8, "min_props": 20, "salt": 17,
        "required": ["counter_service", "register", "card_terminal", "table", "chair", "bench", "podium", "window_display",
                     "mirror", "plant", "sign", "light_fixture"],
        "optional": {"podium": 0.5, "window_display": 0.3, "plant": 1, "mirror": 1, "rug": 0.6, "picture": 1.2, "bench": 0.4},
        "counts": {"chair": (2, 2), "podium": (2, 2), "window_display": (2, 2), "plant": (2, 2)},
        "assets": {"chair": ["prop_chair_consult"], "table": ["prop_consult_table"], "bench": ["prop_bench_upholstered"],
                   "mirror": ["prop_mirror_wall"], "plant": ["prop_plant_tall"], "light_fixture": ["prop_downlight"],
                   "rug": ["prop_rug_rect"], "picture": ["prop_wall_art_a", "prop_wall_art_c"]},
        "ceiling": {"prop_downlight": 2.2},
        "clutter": {"counter": {"anchors": ["counter_service", "table"], "items": {"ring_tray": 2, "bust": 1, "mirror_table": 1.2,
                                                                                 "notebook": 0.5}, "count": (1, 2), "radius": 0.5}},
        "lone_ok": ["podium", "window_display", "display_case"],
        "notes": "G5: display cases, the round chandelier display and the chandelier ring are gameplay/landmark pieces "
                 "placed by the map (anchors / keep-outs). The kit adds the sales counter (+ register, terminal), "
                 "consultation table + 2 chairs, bench, podiums, window display boxes, mirrors, plants, the brass sign "
                 "and 2700 K downlights (track lights: prop_track_light as anchors over the wall cases).",
    },
    "salon_private": {
        "purpose": "sales_floor", "min_density": 0.3, "max_density": 1.5, "min_props": 10, "salt": 18,
        "required": ["sofa", "coffee_table", "armchair", "vitrine", "mirror", "floor_lamp", "rug", "light_fixture"],
        "optional": {"side_table": 1.5, "table_lamp": 1, "picture": 1.5, "plant": 1},
        "counts": {"armchair": (2, 2)},
        "assets": {"mirror": ["prop_mirror_wall"], "picture": ["prop_wall_art_a", "prop_wall_art_b", "prop_wall_art_c"],
                   "plant": ["prop_plant_tall"], "light_fixture": ["prop_downlight"], "rug": ["prop_rug_rect"]},
        "ceiling": {"prop_downlight": 2.4},
        "clutter": {"table": {"anchors": ["coffee_table", "side_table"], "items": {"ring_tray": 1, "bust": 0.6, "notebook": 0.5,
                                                                                  "table_lamp": 1, "plant_small": 0.6},
                              "count": (1, 2), "radius": 0.4}},
        "notes": "G6 private salon: two high-value cases are prefabs (keep-outs). Sofa, coffee table on a rug, two "
                 "armchairs, vitrine, mirror, lamps, wall art. 2700 K, dimmer.",
    },
    "break_room": {
        "purpose": "break_room", "min_density": 0.5, "max_density": 1.8, "min_props": 14, "salt": 19,
        "required": ["fridge", "kitchen_counter", "microwave", "coffee_machine", "table", "chair", "lockers",
                     "bulletin_board", "light_fixture"],
        "optional": {"wall_cabinet": 2, "water_cooler": 1, "bin": 1.2, "kettle": 1, "picture": 0.5, "plant": 0.4},
        "counts": {"chair": (4, 4)},
        "assets": {"chair": ["prop_chair_break"], "table": ["prop_table_break"], "bin": ["prop_bin_kitchen"],
                   "picture": ["prop_notice_frame"], "plant": ["prop_plant_tall"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.3},
        "clutter": {"counter": {"anchors": ["kitchen_counter", "table"], "items": {"mug": 3, "bottles": 1.5, "papers": 1, "kettle": 0.6},
                                "count": (1, 3), "radius": 0.5}},
        "notes": "U1: fridge, counter with sink, microwave + coffee, table with 4 chairs, lockers, bulletin board. 3500 K.",
    },
    "security_office": {
        "purpose": "security_room", "min_density": 0.4, "max_density": 1.8, "min_props": 10, "salt": 20,
        "required": ["desk", "chair", "monitor", "key_cabinet", "lockers", "credenza", "coffee_machine", "light_fixture"],
        "optional": {"file_cabinet": 1.5, "bin": 1, "picture": 1},
        "assets": {"desk": ["prop_desk_office"], "chair": ["prop_chair_office"], "bin": ["prop_bin_office"],
                   "picture": ["prop_notice_frame"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"desk": DESK_CLUTTER, "floor": FLOOR_CLUTTER_OFFICE},
        "notes": "U2: the camera_station prefab (monitor wall, west wall) is placed by the map (keep-out). Desk, key "
                 "cabinet (east wall), guard lockers, coffee on the credenza. Dim; monitor glow.",
    },
    "corridor_office": {
        "purpose": "corridor", "min_density": 0.05, "max_density": 1.2, "min_props": 3, "salt": 21,
        "required": ["fire_extinguisher", "light_fixture", "picture"],
        "optional": {"picture": 1.5, "switch": 1.0, "thermostat": 0.5, "outlet": 0.8},
        "assets": {"picture": ["prop_wall_art_a", "prop_wall_art_b", "prop_notice_frame"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 3.0},
        "notes": "U4 upper spine: wall-mounted only (art, extinguisher, switches); railing and stair void are keep-outs.",
    },
    "office_open": {
        "purpose": "office", "min_density": 0.4, "max_density": 1.8, "min_props": 16, "salt": 22,
        "required": ["desk", "chair", "monitor", "keyboard", "file_cabinet", "printer", "water_cooler", "gem_scope", "light_fixture"],
        "optional": {"bookshelf": 1, "plant": 1, "picture": 1, "bin": 1, "desk_lamp": 1, "credenza": 0.5},
        "counts": {"desk": (3, 3), "chair": (3, 3), "monitor": (2, 3), "keyboard": (2, 3), "file_cabinet": (2, 3)},
        "assets": {"desk": ["prop_desk_office"], "chair": ["prop_chair_office"], "bin": ["prop_bin_office"],
                   "plant": ["prop_plant_tall"], "picture": ["prop_wall_art_a", "prop_wall_art_b", "prop_notice_frame"],
                   "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"desk": DESK_CLUTTER, "floor": FLOOR_CLUTTER_OFFICE},
        "notes": "U5 admin + appraisal: 3 desks (one with the gem scope), file cabinets, printer, water cooler. 4000 K.",
    },
    "office_manager": {
        "purpose": "office", "min_density": 0.4, "max_density": 1.8, "min_props": 12, "salt": 23,
        "required": ["desk", "chair", "credenza", "bookshelf", "picture", "wall_safe", "desk_lamp", "plant", "light_fixture"],
        "optional": {"picture": 1, "rug": 0.6, "file_cabinet": 0.5, "side_table": 0.5, "floor_lamp": 0.5},
        "counts": {"chair": (3, 3)},
        "assets": {"desk": ["prop_desk_exec"], "chair": ["prop_chair_office", "prop_chair_visitor", "prop_chair_visitor"],
                   "picture": ["prop_wall_art_a", "prop_wall_art_b", "prop_wall_art_c"], "plant": ["prop_plant_tall"],
                   "rug": ["prop_rug_rect"], "light_fixture": ["prop_ceiling_panel_neutral"]},
        "ceiling": {"prop_ceiling_panel_neutral": 2.4},
        "clutter": {"desk": DESK_CLUTTER, "credenza": {"anchors": ["credenza"], "items": {"bust": 1, "table_lamp": 1, "binders": 1,
                                                                                          "plant_small": 1}, "count": (1, 2), "radius": 0.4}},
        "notes": "U6 Greta Vossberg: executive desk (free-standing, visitors on the far side), credenza, bookshelf, art, "
                 "small wall safe (dressing).",
    },
    "storage_archive": {
        "purpose": "storage", "min_density": 0.3, "max_density": 1.6, "min_props": 8, "salt": 24,
        "required": ["shelving", "archive_box", "step_ladder", "packing_bench", "light_fixture"],
        "optional": {"shelving": 2, "box": 2, "archive_box": 1.5, "file_cabinet": 0.6},
        "counts": {"shelving": (3, 4)},
        "assets": {"shelving": ["prop_shelving_archive", "prop_shelving_boxes", "prop_shelving_archive"],
                   "light_fixture": ["prop_fluorescent"]},
        "ceiling": {"prop_fluorescent": 2.4},
        "clutter": {"floor": FLOOR_CLUTTER_STORE, "bench": {"anchors": ["packing_bench"], "items": {"gift_boxes": 3, "papers": 1},
                                                            "count": (1, 2), "radius": 0.5}},
        "notes": "U7 stock + archive: archive boxes on shelving, packaging and gift-box stock, step ladder.",
    },
    "exterior_alley": {
        "purpose": "exterior", "min_density": 0.02, "max_density": 0.3, "min_props": 6, "salt": 25,
        "required": ["hvac", "pallet", "wall_lamp", "crate"],
        "optional": {"hvac": 1.5, "pallet": 1.5, "box": 1, "crate": 1},
        "counts": {"hvac": (2, 3)},
        "assets": {"pallet": ["prop_pallet", "prop_pallet_loaded"]},
        "notes": "X1 service alley: dumpsters (body_container prefabs), fire-escape ladder and the alley gate are placed "
                 "by the map. The kit adds condensers against the building, pallets, crates, the back-door lamp.",
    },
    "exterior_street": {
        "purpose": "exterior", "min_density": 0.005, "max_density": 0.3, "min_props": 6, "salt": 26,
        "required": ["street_lamp", "bin_street", "bollard"],
        "optional": {"bollard": 2, "planter": 1, "car": 1.5, "barrier": 0.5, "bus_shelter": 0.3},
        "counts": {"street_lamp": (2, 3), "bollard": (3, 5)},
        "lone_ok": ["street_lamp", "bin_street", "bollard", "planter", "car", "barrier", "bus_shelter"],
        "notes": "X2 streets: the neon sign, awnings, bus shelter and parked cars are usually anchored by the map "
                 "(sidewalk/curb lines); the placer fills lamps, bins, bollards, planters along the facade.",
    },
}


sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _kits_bank import BANK_KITS  # noqa: E402  (Night Deposit kits)

KITS.update(BANK_KITS)
from _kits_dockside import DOCKSIDE_KITS  # noqa: E402  (Dockside Burn kits, DB-C2)

KITS.update(DOCKSIDE_KITS)
from _kits_shadow import SHADOW_KITS  # noqa: E402  (Shadow Ledger kits, SL-1)

KITS.update(SHADOW_KITS)
from _kits_ostrander import ostrander_kits  # noqa: E402  (Ostrander Federal purpose variants, OF-C2)

KITS.update(ostrander_kits(KITS))
from _kits_rolling_thunder import rolling_thunder_kits  # noqa: E402  (Rolling Thunder variants, RT-C2)

KITS.update(rolling_thunder_kits(KITS))
from _kits_safehouse import SAFEHOUSE_KITS  # noqa: E402  (Safehouse kits, C4-03)

KITS.update(SAFEHOUSE_KITS)
from _kits_afterhours import afterhours_kits  # noqa: E402  (Afterhours variants + club kits, AH-C2; after the safehouse kits: loading_bay)

KITS.update(afterhours_kits(KITS))


def _sn(s: str) -> str:
    return f'&"{s}"'


def _dict_sn(d: dict, fmt) -> str:
    if not d:
        return "{}"
    return "{\n" + ",\n".join(f"{_sn(k)}: {fmt(v)}" for k, v in sorted(d.items())) + "\n}"


def _clutter(groups: dict) -> str:
    if not groups:
        return "{}"
    rows = []
    for g, spec in sorted(groups.items()):
        anchors = ", ".join(_sn(a) for a in spec["anchors"])
        items = ", ".join(f"{_sn(k)}: {float(v):g}" for k, v in sorted(spec["items"].items()))
        cx, cy = spec["count"]
        rows.append(f'{_sn(g)}: {{\n"anchors": Array[StringName]([{anchors}]),\n"count": Vector2i({cx}, {cy}),\n'
                    f'"items": {{{items}}},\n"radius": {float(spec["radius"]):g}\n}}')
    return "{\n" + ",\n".join(rows) + "\n}"


def render(kit_id: str, k: dict) -> str:
    req = ", ".join(_sn(x) for x in k["required"])
    lone = ", ".join(_sn(x) for x in k.get("lone_ok", []))
    notes = k.get("notes", "").replace('"', '\\"')
    lines = [
        '[gd_resource type="Resource" script_class="DressingKit" load_steps=2 format=3]',
        "",
        '[ext_resource type="Script" path="res://world/kits/dressing_kit.gd" id="1_kit"]',
        "",
        "[resource]",
        'script = ExtResource("1_kit")',
        f"id = {_sn(kit_id)}",
        f"purpose = {_sn(k['purpose'])}",
        f"required_items = Array[StringName]([{req}])",
        f"optional_items = {_dict_sn(k.get('optional', {}), lambda v: f'{float(v):g}')}",
        f"clutter_groups = {_clutter(k.get('clutter', {}))}",
        f"min_density = {k['min_density']:g}",
        f"max_density = {k['max_density']:g}",
        f"min_props = {k['min_props']}",
        f"lone_ok_kinds = Array[StringName]([{lone}])",
        f"seed_salt = {k['salt']}",
        *([f"seed_id = {_sn(k['seed_id'])}"] if k.get("seed_id") else []),
        f"counts = {_dict_sn(k.get('counts', {}), lambda v: f'Vector2i({v[0]}, {v[1]})')}",
        f"assets = {_dict_sn(k.get('assets', {}), lambda v: 'PackedStringArray(' + ', '.join(f'\"{a}\"' for a in v) + ')')}",
        "ceiling = {" + ", ".join(f'"{a}": {float(s):g}' for a, s in sorted(k.get("ceiling", {}).items())) + "}",
        f'notes = "{notes}"',
    ]
    return "\n".join(lines) + "\n"


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    n = 0
    for kit_id, k in sorted(KITS.items()):
        path = OUT / f"{kit_id}.tres"
        text = render(kit_id, k)
        if not path.exists() or path.read_text(encoding="utf-8") != text:
            path.write_text(text, encoding="utf-8", newline="\n")
            n += 1
    print(f"kits: {len(KITS)} kits, {n} file(s) written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
