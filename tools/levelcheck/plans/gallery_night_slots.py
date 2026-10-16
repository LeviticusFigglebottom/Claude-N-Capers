# Gallery Night: the map's variant groups / VariantSlot ids and contract nodes, with rooms and plan positions,
# cross-checked against the design doc and ENV B's draft data (GN-C1). Owner: ENV C.
# Run: python3 tools/levelcheck/plans/gallery_night_slots.py              (the slot list)
#      python3 tools/levelcheck/plans/gallery_night_slots.py --check      (consistency report, exit 0/1)
#      python3 tools/levelcheck/plans/gallery_night_slots.py --check --b-live[=<git ref>] [--root=<checkout>]
#          (re-read ENV B's draft from git, default origin/env/b-gallery-night, instead of the snapshot below,
#           and report where the snapshot is stale)
#
# Sources: docs/design/heists/gallery_night.md (Variable table, Rare events, Pre-planning, Sightlines, Police
# spawns, Escape, Review shots; parsed live from the doc), ENV B's draft (game/content/_drafts/gallery_night/
# README.md "Map slot names" + gallery_night_variants.tres, game/content/data/preplanning/blueprints/
# gallery_night.tres, assets/intel_*.tres; a snapshot of commit f2063f84 is embedded) and the floor plans
# (gallery_night_floors_ascii.py: room rectangles). This file is the slot / contract-node data source for the
# greybox generator (game/world/heists/gallery_night/greybox/).
#
# Coordinates: metres, the plans' origin (the gallery's NW corner), +x east, +z south; `floor` is a plan floor
# (B G U R); `y` (optional) is metres above that floor's FFL where the anchor is not on the floor.
#
# --check FAILs (exit 1) when: a group or slot that the doc or ENV B references is missing from SLOTS (or SLOTS
# has one neither references); a slot, camera, spawn, zone, preplan point or review camera names an unknown room
# or sits outside its room's rectangle; a preplan point's params name an unknown group/slot or disagree with the
# doc; the contract-node needs are not covered (player spawns >= 4 per spawn option incl. pp_spawn_mews /
# pp_spawn_roof, police P1-P5 in >= 3 directions and >= 15 m from every holdout, an ESCAPE and a SECURE_LOOT zone
# per escape slot, >= 12 review cameras >= 0.5 m inside their rooms, the 11 preplan points, camera_spine /
# camera_screen layout rules). Differences between ENV B's draft and the doc, and inconsistencies inside the
# doc, are printed as NOTE lines (for the lead / ENV B); they do not fail the check.
import math
import os
import re
import subprocess
import sys
from typing import Dict, List, Optional, Tuple

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
for _a in sys.argv:  # --root=<repo checkout> when the script runs from a copy (ENV B)
    if _a.startswith("--root="):
        ROOT = os.path.abspath(_a.split("=", 1)[1])
sys.path.insert(0, os.path.join(ROOT, "tools", "levelcheck", "plans"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gallery_night_floors_ascii as P  # noqa: E402
DOC = os.path.join(ROOT, "docs", "design", "heists", "gallery_night.md")
B_REF = "origin/env/b-gallery-night"
B_FILES = {
    "readme": "game/content/_drafts/gallery_night/README.md",
    "variants": "game/content/_drafts/gallery_night/gallery_night_variants.tres",
    "blueprint": "game/content/data/preplanning/blueprints/gallery_night.tres",
    "intel_list": "game/content/data/preplanning/assets/intel_list.tres",
    "intel_sensors": "game/content/data/preplanning/assets/intel_sensors.tres",
}
Rect = Tuple[float, float, float, float]

# Exterior rooms (Room list X1-X3; X4 is the roof deck in the floor plans). Rectangles from the Site section.
# X3: the Room list says 14 x 30 (x -16...-2), but the French doors (x 0), C8 (-0.4, 4) and pp_court_doors
# (-1, 12.5) need the court to reach the gallery's west facade; ENV B's blueprint draws it x -16...0 too.
EXTERIOR: Dict[str, List[Rect]] = {
    "X1": [(-40, 30, 58, 50)],                          # Aldous Parade + portico (to the park railings)
    "X2": [(-40, -8, 44, 0), (44, -22, 58, 30)],        # Pelham Mews (8 m) + Wexley Street (14 m)
    "X3": [(-16, 0, 0, 30)],                            # Sculpture Court, to the facade (see above)
}
EXTERIOR_PURPOSE = {"X1": "exterior", "X2": "exterior", "X3": "exterior"}
EXTERIOR_KIT = {"X1": "exterior_boulevard", "X2": "exterior_mews", "X3": "exterior_court"}

# Resolver order (= ENV B's rule order; `conservator` before `keycard`, since kc_conservator requires cons_late).
GROUP_ORDER = ["centrepiece", "canvas_orchard", "canvas_widow", "canvas_saint", "sensor_net", "conservator", "keycard",
               "code_note", "guard_post", "security_room_staffed", "camera", "laser_pattern", "curator_route",
               "court_doors", "areaway", "escape", "xl_crate", "admin_pa"]

# SLOTS: (group, slot_id, base weight, floor, room, x, z, y, yaw, note). The VariantSlot sits at (x, FFL + y, z),
# turned by `yaw` (degrees about +y; the content's front, -Z, faces 0 north (-z), 90 west (-x), 180 south (+z),
# -90 east (+x)); its content (prefabs, spawns, cameras) is placed by the generator as children, and an interactive
# slot's UsePoint stands USE_POINT_M in front of the anchor (rehearsal F2/F3). Wall-hung slots (WALL_HUNG) face away
# from the wall they hang on. Base weights go on VariantSlot.weight (per-difficulty rows live in the variant table).
SLOTS: List[Tuple[str, str, float, str, str, float, float, float, float, str]] = [
    ("centrepiece", "cp_landing", 0.4, "G", "GH", 21.0, 8.25, 2.7, 180.0, "landing wall easel-frame (centre +2.7 +1.55); laser curtain after last call"),
    ("centrepiece", "cp_treasury", 0.35, "U", "TR", 40.0, 29.6, 0.0, 0.0, "centred on the TR south wall, behind the laser grid"),
    ("centrepiece", "cp_store", 0.25, "B", "AS", 20.0, 18.0, 0.0, 0.0, "AS rack screen (plan L (20, 18))"),
    ("canvas_orchard", "orchard_calloway", 1.0, "U", "UG1", 0.3, 14.0, 0.0, -90.0, "UG1 W wall behind the partition screen (6, 12-16)"),
    ("canvas_orchard", "orchard_benefactors", 1.0, "G", "EB", 32.25, 28.0, 0.0, -90.0, "EB W (donor) wall by plan L (34, 28)"),
    ("canvas_orchard", "orchard_quarantine", 0.7, "B", "QR", 22.0, 3.0, 0.0, 180.0, "opened travel crate in QR"),
    ("canvas_widow", "widow_sallow", 1.0, "U", "UG2", 0.3, 25.0, 0.0, -90.0, "UG2 W wall (plan L (1, 25))"),
    ("canvas_widow", "widow_founders", 1.0, "G", "WG", 0.3, 16.0, 0.0, -90.0, "WG W wall (plan L (1, 16))"),
    ("canvas_widow", "widow_conservation", 0.7, "U", "CS", 36.0, 8.0, 0.0, -90.0, "CS main easel, frame off"),
    ("canvas_saint", "saint_maritime", 1.0, "U", "UG3", 43.7, 16.0, 0.0, 90.0, "UG3 E wall, z 16 so the partition screen hides it from C10 (lead r127)"),
    ("canvas_saint", "saint_harbour", 1.0, "G", "EG", 43.7, 18.0, 0.0, 90.0, "EG E wall (plan L (43, 18))"),
    ("canvas_saint", "saint_store", 0.7, "B", "AS", 26.0, 16.0, 0.0, 0.0, "AS rack screen (plan L (26, 16))"),
    ("sensor_net", "sensors_treasury", 0.5, "U", "SV", 25.0, 2.0, 0.0, 0.0, "logic slot: Argus alarm group = the TR frame"),
    ("sensor_net", "sensors_upper", 0.35, "U", "SV", 25.0, 2.0, 0.0, 0.0, "logic slot: upper frames + TR + the landing"),
    ("sensor_net", "sensors_all", 0.15, "U", "SV", 25.0, 2.0, 0.0, 0.0, "logic slot: every hung frame"),
    ("conservator", "cons_late", 1.0, "U", "CS", 37.5, 9.0, 0.0, 90.0, "civ_conservator spawn at the main easel"),
    ("conservator", "cons_gone", 1.0, "U", "CS", 37.5, 9.0, 0.0, 90.0, "empty"),
    ("keycard", "kc_curator", 1.0, "G", "GH", 15.0, 18.6, 1.1, -90.0, "carried by civ_curator (QC-52); curator_tipsy: on the GH bar here"),
    ("keycard", "kc_security", 0.75, "G", "SC", 17.6, 3.0, 1.2, 90.0, "SC key cabinet, E wall"),
    ("keycard", "kc_registrar", 1.0, "G", "RG", 21.0, 3.0, 0.75, 180.0, "RG desk drawer (pp_insider_registrar)"),
    ("keycard", "kc_conservator", 1.0, "U", "CS", 40.0, 10.0, 0.9, 0.0, "CS bench drawer (plan K (40, 10)); requires cons_late"),
    ("code_note", "code_security_log", 1.0, "G", "SC", 17.4, 0.6, 1.0, 180.0, "guard log, SC NE counter"),
    ("code_note", "code_curator_planner", 1.0, "U", "CO", 6.0, 2.0, 0.75, 180.0, "planner on the curator's desk"),
    ("code_note", "code_admin_postit", 1.0, "U", "AO", 14.0, 4.0, 1.0, 180.0, "post-it on an AO monitor"),
    ("guard_post", "rover_ground", 1.0, "G", "BC", 10.0, 7.0, 0.0, -90.0, "guard_rover_ground spawn (BC)"),
    ("guard_post", "rover_upper", 1.0, "U", "UC", 10.0, 7.0, 0.0, -90.0, "guard_rover_upper spawn (UC)"),
    ("guard_post", "rover_basement", 1.0, "B", "BB", 10.0, 7.0, 0.0, -90.0, "guard_rover_basement spawn (BB)"),
    ("guard_post", "dock_smoker", 1.0, "G", "X2", 40.0, -2.0, 0.0, 0.0, "guard_mews spawn, Mews by the LD personnel door"),
    ("guard_post", "rover_none", 1.0, "G", "GH", 22.0, 17.0, 0.0, 180.0, "empty slot (encodes counts; weight 0 from Hazardous)"),
    ("security_room_staffed", "sec_staffed", 0.6, "G", "SC", 13.5, 3.5, 0.0, 90.0, "CAMERA_OPERATOR at the console, facing W"),
    ("security_room_staffed", "sec_empty", 0.4, "G", "SC", 13.5, 3.5, 0.0, 90.0, "empty"),
    ("camera", "cam_a", 1.0, "G", "SC", 12.6, 3.0, 0.0, 0.0, "layout cameras C1 C3 C6 C7 C9 C13 (children)"),
    ("camera", "cam_b", 1.0, "G", "SC", 12.6, 3.0, 0.0, 0.0, "layout cameras C2 C4 C6 C8 C10 C12 (children)"),
    ("camera", "cam_c", 1.0, "G", "SC", 12.6, 3.0, 0.0, 0.0, "layout cameras C1 C4 C5 C8 C10 C12 (children)"),
    ("laser_pattern", "lz_static", 0.5, "U", "TR", 40.0, 26.5, 0.0, 0.0, "TR grid z 26.5: 3 beams 1.30/1.8/2.33"),
    ("laser_pattern", "lz_sweep", 0.2, "U", "TR", 40.0, 26.5, 0.0, 0.0, "TR grid: 3 vertical, 6 s sweep"),
    ("laser_pattern", "lz_timed", 0.3, "U", "TR", 40.0, 26.5, 0.0, 0.0, "TR grid: 4 beams, off 4 s of 16 s"),
    ("curator_route", "curator_hall", 1.0, "G", "GH", 17.0, 16.0, 0.0, -90.0, "civ_curator spawn + staff_curator points in GH"),
    ("curator_route", "curator_office", 1.0, "U", "CO", 6.0, 4.0, 0.0, 0.0, "civ_curator spawn + staff_curator points CO/UG1/CS"),
    ("court_doors", "court_doors_open", 1.0, "G", "WG", 0.6, 12.5, 0.0, 90.0, "French doors NONE until last call"),
    ("court_doors", "court_doors_locked", 1.0, "G", "WG", 0.6, 12.5, 0.0, 90.0, "French doors LOCKPICK"),
    ("areaway", "grate_loose", 1.0, "G", "X3", -4.0, 14.0, 0.0, 90.0, "court grate: lift 3 s"),
    ("areaway", "grate_padlocked", 1.0, "G", "X3", -4.0, 14.0, 0.0, 90.0, "court grate: padlock (lockpick 8 s or saw)"),
    ("escape", "esc_mews", 0.55, "G", "X2", 37.0, -4.0, 0.0, 90.0, "E1 van at the LD roller door"),
    ("escape", "esc_parade", 0.45, "G", "X1", 22.0, 34.0, 0.0, 90.0, "E2 limo at the portico kerb"),
    ("xl_crate", "xl_none", 1.0, "G", "LD", 38.0, 9.0, 0.0, 0.0, "empty sibling (QC-62): no crate unless late_loan"),
    ("xl_crate", "xl_loan", 1.0, "G", "LD", 38.0, 9.0, 0.0, 0.0, "late_loan crate (2 studies); pick 0, only the rare event"),
    ("admin_pa", "pa_none", 1.0, "U", "AO", 15.0, 4.0, 0.0, 0.0, "empty sibling (QC-62): no PA unless late_paperwork"),
    ("admin_pa", "pa_late", 1.0, "U", "AO", 15.0, 4.0, 0.0, 0.0, "civ_admin at an AO desk; pick 0, only late_paperwork"),
]
# Slots hung on (or fixed to) a wall: --check wants the anchor <= WALL_HUNG_MAX_M from that wall's room face and the
# yaw facing away from it (into the room), so the prefab clears the wall and its UsePoint lands on the floor.
WALL_HUNG = ("cp_landing", "cp_treasury", "orchard_calloway", "orchard_benefactors", "widow_sallow", "widow_founders",
             "saint_maritime", "saint_harbour", "kc_security")
WALL_HUNG_MAX_M = 0.3
USE_POINT_M = 0.9          # the gameplay prefabs' default UsePoint distance in front of the object
# Groups whose content the crew walks up to and uses (a UsePoint in front of the anchor).
USE_POINT_GROUPS = ("centrepiece", "canvas_orchard", "canvas_widow", "canvas_saint", "keycard", "code_note", "areaway")
EXT_T, INT_T = 0.4, 0.2    # facade / interior wall thickness (gallery_night_emit_layout.py)
SCALARS = {"last_call_s": [480, 600, 720], "patrons": [3, 5, 7, 9], "stragglers": [0, 1, 2],
           "store_paintings": [4, 6, 8], "consignment_lockers": [4, 6, 8], "escape_eta_s": [90, 120, 150]}
RARE = {"curator_tipsy": ("keycard", "kc_curator"), "late_loan": ("xl_crate", "xl_loan"), "insurance_inspection": None,
        "vaultline_early": None, "argus_upgrade": ("sensor_net", "sensors_all"), "late_paperwork": ("admin_pa", "pa_late")}

# Security cameras (Sightlines): id -> (floor, room, x, z, mount height above FFL, layouts). Layout cameras sit
# under their cam_* slot; "always" = outside any slot (C11, C14; B6).
CAMERAS: Dict[str, Tuple[str, str, float, float, float, Tuple[str, ...]]] = {
    "C1": ("G", "VE", 22.0, 26.2, 3.2, ("cam_a", "cam_c")),
    "C2": ("G", "GH", 31.0, 22.0, 5.1, ("cam_b",)),
    "C3": ("G", "WG", 11.6, 8.4, 3.2, ("cam_a",)),
    "C4": ("G", "EG", 43.6, 23.6, 3.2, ("cam_b", "cam_c")),
    "C5": ("G", "BC", 3.4, 7.0, 2.8, ("cam_c",)),
    "C6": ("G", "LD", 32.4, 0.4, 3.2, ("cam_a", "cam_b")),
    "C7": ("G", "X2", 36.0, -1.0, 3.2, ("cam_a",)),
    "C8": ("G", "X3", -0.4, 4.0, 3.0, ("cam_b", "cam_c")),
    "C9": ("U", "UG1", 11.6, 19.6, 3.2, ("cam_a",)),
    "C10": ("U", "UG3", 32.4, 12.4, 3.2, ("cam_b", "cam_c")),
    "C11": ("U", "TR", 43.6, 24.4, 2.6, ("always",)),
    "C12": ("B", "BB", 31.6, 7.0, 2.8, ("cam_b", "cam_c")),
    "C13": ("U", "UC", 3.4, 7.0, 2.8, ("cam_a",)),
    "C14": ("B", "AS", 31.6, 8.4, 3.2, ("always",)),
}
# The doc's layout table (Sightlines "Camera layouts") for the cross-check.
DOC_LAYOUTS = {"cam_a": {"C1", "C3", "C6", "C7", "C9", "C13"}, "cam_b": {"C2", "C4", "C6", "C8", "C10", "C12"},
               "cam_c": {"C1", "C4", "C5", "C8", "C10", "C12"}}
CAMERA_SPINE_ROOMS = ("BC", "UC")
CAMERA_SCREEN_SLOTS = ("orchard_calloway", "widow_sallow", "saint_maritime")
# Partition screens (meta kind = partition_screen): (room, x0, z0, x1, z1) on the plan; UG3's is a G1 choice.
SCREENS = [("UG1", 6.0, 12.0, 6.0, 16.0), ("UG3", 38.0, 14.0, 38.0, 17.0)]

# Player spawns: (name, spawn_tag, floor, room, x, z, yaw). "" = default (pp_spawn_portico).
PLAYER_SPAWNS = [
    ("PlayerPortico1", "", "G", "X1", 20.5, 35.0, 0.0), ("PlayerPortico2", "", "G", "X1", 21.5, 35.0, 0.0),
    ("PlayerPortico3", "", "G", "X1", 22.5, 35.0, 0.0), ("PlayerPortico4", "", "G", "X1", 23.5, 35.0, 0.0),
    ("PlayerMews1", "preplan_spawn_mews", "G", "X2", 24.5, -5.0, 90.0),
    ("PlayerMews2", "preplan_spawn_mews", "G", "X2", 25.5, -5.0, 90.0),
    ("PlayerMews3", "preplan_spawn_mews", "G", "X2", 26.5, -5.0, 90.0),
    ("PlayerMews4", "preplan_spawn_mews", "G", "X2", 27.5, -5.0, 90.0),
    ("PlayerRoof1", "preplan_spawn_roof", "R", "X4", 12.0, 6.0, 0.0),
    ("PlayerRoof2", "preplan_spawn_roof", "R", "X4", 15.0, 6.0, 0.0),
    ("PlayerRoof3", "preplan_spawn_roof", "R", "X4", 18.0, 6.0, 0.0),
    ("PlayerRoof4", "preplan_spawn_roof", "R", "X4", 21.0, 6.0, 0.0),
]
# Police spawns (Loud): (name, tag, x, z, y absolute). Outside the play space (behind occluders) except P5.
POLICE_SPAWNS = [("P1", "police_w", -46.0, 44.0, 0.0), ("P2", "police_e", 76.0, 44.0, 0.0),
                 ("P3", "police_n", 52.0, -28.0, 0.0), ("P4", "police_mews", -46.0, -4.0, 0.0),
                 ("P5", "police_roof", 22.0, 29.0, 11.0)]
HOLDOUTS = {"H1": (22.0, 10.0), "H2": (20.0, 5.0), "H3": (20.0, 12.0), "H4": (38.0, 6.0)}
MIN_CREW_DISTANCE_M = 15.0   # DirectorTweak min_crew_distance_m
# Escape / secure zones: (escape slot, kind, floor, room, x, z) (Escape: van rear doors, limo boot).
ESCAPE_ZONES = [("esc_mews", "ESCAPE", "G", "X2", 37.0, -4.0), ("esc_mews", "SECURE_LOOT", "G", "X2", 34.5, -4.0),
                ("esc_parade", "ESCAPE", "G", "X1", 22.0, 34.0), ("esc_parade", "SECURE_LOOT", "G", "X1", 25.0, 34.0)]
# Preplan points (Pre-planning; positions = ENV B's blueprint): (id, category, floor index, plan floor, room, x, z,
# params).
PREPLAN = [
    ("pp_spawn_portico", "spawn", 1, "G", "X1", 22.0, 36.0, {}),
    ("pp_spawn_mews", "spawn", 1, "G", "X2", 26.0, -5.0, {"spawn_tag": "preplan_spawn_mews"}),
    ("pp_spawn_roof", "spawn", 3, "R", "X4", 17.0, 6.0, {"spawn_tag": "preplan_spawn_roof"}),
    ("pp_drop_court", "drop_zone", 1, "G", "X3", -12.0, 24.0, {}),
    ("pp_drop_mews", "drop_zone", 1, "G", "X2", 16.0, -2.0, {}),
    ("pp_drop_roof", "drop_zone", 3, "R", "X4", 8.0, 3.0, {}),
    ("pp_escape_mews", "escape", 1, "G", "X2", 37.0, -4.0, {"variant_group": "escape", "variant_slot": "esc_mews"}),
    ("pp_escape_parade", "escape", 1, "G", "X1", 22.0, 34.0, {"variant_group": "escape", "variant_slot": "esc_parade"}),
    ("pp_insider_registrar", "insider", 1, "G", "RG", 21.0, 3.0, {"variant_group": "keycard", "variant_slot": "kc_registrar"}),
    ("pp_grate", "insider", 1, "G", "X3", -4.0, 14.0, {"variant_group": "areaway", "variant_slot": "grate_loose"}),
    ("pp_court_doors", "insider", 1, "G", "X3", -1.0, 12.5, {"variant_group": "court_doors", "variant_slot": "court_doors_open"}),
]
# Review cameras (Review shots): (id, floor, room, x, z, eye height above FFL, look-at x, z, y above FFL).
# TopDownPlan (the doc's rc_top_down; validate_level needs a TopDown* name at final) has no room (orthographic).
REVIEW_CAMERAS = [
    ("TopDownPlan", "G", "", 9.0, 20.0, 120.0, 9.0, 20.0, 0.0),
    ("rc_ext_parade", "G", "X1", 22.0, 41.0, 1.7, 22.0, 30.0, 6.0),
    ("rc_ext_wexley", "G", "X2", 56.0, 10.0, 1.7, 44.0, 6.0, 4.0),
    ("rc_ext_mews", "G", "X2", -30.0, -4.0, 1.7, 40.0, -2.0, 3.0),
    ("rc_ext_court", "G", "X3", -8.0, 29.0, 1.7, -6.0, 8.0, 2.0),
    ("rc_hall_entry", "G", "VE", 22.0, 29.0, 1.7, 22.0, 9.0, 4.0),
    ("rc_hall_landing", "G", "GH", 22.0, 9.4, 4.3, 22.0, 24.0, 1.0),
    ("rc_balcony", "U", "BW", 13.5, 17.0, 1.7, 30.5, 17.0, 1.0),
    ("rc_founders", "G", "WG", 11.0, 19.0, 1.7, 1.0, 9.0, 1.5),
    ("rc_drawings", "G", "DC", 6.0, 29.0, 1.7, 1.0, 21.0, 1.5),
    ("rc_harbour", "G", "EG", 43.0, 23.0, 1.7, 37.0, 12.5, 1.5),
    ("rc_benefactors", "G", "EB", 43.0, 29.0, 1.7, 33.0, 25.0, 1.5),
    ("rc_cloakroom", "G", "CK", 17.0, 29.0, 1.7, 12.5, 26.5, 1.2),
    ("rc_back_corridor", "G", "BC", 3.6, 7.0, 1.7, 31.0, 7.0, 1.5),
    ("rc_security", "G", "SC", 16.5, 3.5, 1.7, 12.5, 3.5, 1.3),
    ("rc_loading", "G", "LD", 43.0, 11.0, 1.7, 33.0, 2.0, 2.0),
    ("rc_break", "G", "BR", 8.0, 5.0, 1.7, 4.0, 1.0, 1.0),
    ("rc_calloway", "U", "UG1", 11.0, 19.0, 1.7, 1.0, 9.0, 2.5),
    ("rc_sallow", "U", "UG2", 11.0, 29.0, 1.7, 1.0, 21.0, 2.5),
    ("rc_maritime", "U", "UG3", 43.0, 13.0, 1.7, 39.0, 24.0, 1.5),
    ("rc_treasury", "U", "TR", 39.0, 25.0, 1.7, 40.0, 29.6, 1.5),
    ("rc_upper_corridor", "U", "UC", 31.0, 7.0, 1.7, 4.0, 7.0, 1.5),
    ("rc_curator", "U", "CO", 9.0, 5.0, 1.7, 4.0, 1.0, 1.0),
    ("rc_conservation", "U", "CS", 43.0, 11.0, 1.7, 34.0, 2.0, 1.5),
    ("rc_art_store", "B", "AS", 31.0, 19.0, 1.7, 21.5, 8.5, 1.2),
    ("rc_plant", "B", "PL", 11.0, 19.0, 1.7, 2.0, 14.0, 1.5),
    ("rc_roof_deck", "R", "X4", 10.0, 1.0, 1.7, 22.0, 6.0, 0.5),
]


# ------------------------------------------------------------------------------------------------- rooms
def room_rects(floor: str, rid: str) -> List[Rect]:
    if rid in EXTERIOR:
        return EXTERIOR[rid] if floor == "G" else []
    return [r[2] for r in P.ROOMS[floor] if r[0] == rid]


def inside(floor: str, rid: str, x: float, z: float, margin: float = 0.0) -> bool:
    return any(r[0] + margin <= x <= r[2] - margin and r[1] + margin <= z <= r[3] - margin
               for r in room_rects(floor, rid))


def room_exists(floor: str, rid: str) -> bool:
    return bool(room_rects(floor, rid))


def use_point(x: float, z: float, yaw: float) -> Tuple[float, float]:
    """The point USE_POINT_M in front of an anchor turned by `yaw` (front = -Z turned about +y)."""
    a = math.radians(yaw)
    return x - math.sin(a) * USE_POINT_M, z - math.cos(a) * USE_POINT_M


def hung_wall(floor: str, rid: str, x: float, z: float) -> Optional[Tuple[float, float, str]]:
    """The nearest wall of the room rectangle holding (x, z): (distance from its room face, the yaw facing away from
    it, its side), or None when that edge has no wall there (an open edge, a balustrade)."""
    rect = [r for r in room_rects(floor, rid) if r[0] <= x <= r[2] and r[1] <= z <= r[3]][0]
    foot = P.FOOT[floor]
    sides = [("W", rect[0], x - rect[0], -90.0, "x"), ("E", rect[2], rect[2] - x, 90.0, "x"),
             ("N", rect[1], z - rect[1], 180.0, "z"), ("S", rect[3], rect[3] - z, 0.0, "z")]
    best = None
    for side, edge, d, away, axis in sides:
        ext = edge in ((foot[0], foot[2]) if axis == "x" else (foot[1], foot[3]))
        face = d - (EXT_T if ext else INT_T) / 2.0
        if best is None or face < best[0]:
            best = (face, away, side, edge, axis)
    face, away, side, edge, axis = best
    k = int(math.floor(z if axis == "x" else x))
    unit = (int(edge), k, int(edge), k + 1) if axis == "x" else (k, int(edge), k + 1, int(edge))
    return (face, away, side) if unit in P.walls(floor) else None


def slot_index() -> Dict[str, List[str]]:
    out: Dict[str, List[str]] = {}
    for g, s, *_ in SLOTS:
        out.setdefault(g, []).append(s)
    return out


# --------------------------------------------------------------------------------------------- the doc
def _section(text: str, title: str) -> str:
    m = re.search(r"^## " + re.escape(title) + r".*?$(.*?)(?=^## )", text, re.M | re.S)
    return m.group(1) if m else ""


def _strip_parens(s: str) -> str:
    out, depth = "", 0
    for ch in s:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth = max(0, depth - 1)
        elif depth == 0:
            out += ch
    return out


def _cells(line: str) -> List[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def parse_doc(text: str) -> Dict:
    groups: Dict[str, Dict] = {}
    order: List[str] = []
    for line in _section(text, "Variable table").splitlines():
        if not line.startswith("| `"):
            continue
        c = _cells(line)
        gid = re.findall(r"`([a-z0-9_]+)`", c[0])[0]
        if "scalar" in c[0]:
            groups[gid] = {"scalar": True, "options": re.findall(r"\d+", _strip_parens(c[1]))}
        else:
            groups[gid] = {"scalar": False, "options": re.findall(r"`([a-z0-9_]+)`", _strip_parens(c[1])),
                           "weights": c[2], "std": re.findall(r"`([a-z0-9_]+)`", c[0])[1:],
                           "mentions": re.findall(r"`([a-z0-9_]+)`", c[1])}
        order.append(gid)
    rare: Dict[str, Dict] = {}
    for line in _section(text, "Rare events").splitlines():
        if not line.startswith("| `"):
            continue
        c = _cells(line)
        rid = re.findall(r"`([a-z0-9_]+)`", c[0])[0]
        md = re.search(r"min_difficulty` (\w+)", c[2])
        rare[rid] = {"chance": float(re.search(r"([\d.]+)%", c[2]).group(1)) / 100.0,
                     "min_difficulty": md.group(1) if md else None,
                     "tokens": re.findall(r"`([a-z0-9_]+)`", c[2] + " " + c[3])}
    points: Dict[str, Dict] = {}
    for line in _section(text, "Pre-planning").splitlines():
        if not line.startswith("| `pp_"):
            continue
        c = _cells(line)
        pid = re.findall(r"`(pp_[a-z0-9_]+)`", c[0])[0]
        params: Dict[str, str] = {}
        vg = re.search(r"variant_group `(\w+)`", c[2])
        vs = re.search(r"slot `(\w+)`", c[2])
        st = re.search(r"spawn_tag `(\w*)`", c[2])
        if vs:
            params["variant_slot"] = vs.group(1)
            if vg:   # rows after the first of a group write only "slot `x`"
                params["variant_group"] = vg.group(1)
        if st and st.group(1):
            params["spawn_tag"] = st.group(1)
        flr = re.search(r"floor (\d)", c[2])
        points[pid] = {"category": c[1], "params": params, "floor": int(flr.group(1)) if flr else None}
    return {"groups": groups, "order": order, "rare": rare, "points": points}


# ------------------------------------------------------------------------------------------- ENV B draft
# Snapshot of ENV B's draft at origin/env/b-gallery-night f2063f84 + 2302f353 (QC-62 siblings) (parse_b() of the five files), so --check
# runs without git. `--b-live` re-reads the branch and reports drift.
B_SNAPSHOT = {
    "ref": "2302f353",
    "rules": [
        ["centrepiece", [1, 1], None, {}, {}],
        ["canvas_orchard", [1, 1], None, {}, {}],
        ["canvas_widow", [1, 1], None, {}, {}],
        ["canvas_saint", [1, 1], None, {}, {}],
        ["sensor_net", [1, 1], None, {"2": {"sensors_all": 0.4, "sensors_treasury": 0.2, "sensors_upper": 0.4},
                                      "3": {"sensors_all": 0.4, "sensors_treasury": 0.2, "sensors_upper": 0.4},
                                      "4": {"sensors_all": 0.4, "sensors_treasury": 0.2, "sensors_upper": 0.4},
                                      "5": {"sensors_all": 0.4, "sensors_treasury": 0.2, "sensors_upper": 0.4}}, {}],
        ["conservator", [1, 1], None, {}, {}],
        ["keycard", [2, 2], None, {}, {"kc_conservator": {"conservator": ["cons_late"]}}],
        ["code_note", [1, 1], None, {}, {}],
        ["guard_post", [1, 1], [0, 0, 1, 2, 3, 3], {"2": {"rover_none": 0.0}, "3": {"rover_none": 0.0},
                                                   "4": {"rover_none": 0.0}, "5": {"rover_none": 0.0}}, {}],
        ["security_room_staffed", [1, 1], None, {"2": {"sec_empty": 0.35, "sec_staffed": 0.65},
                                                "3": {"sec_empty": 0.25, "sec_staffed": 0.75},
                                                "4": {"sec_empty": 0.25, "sec_staffed": 0.75},
                                                "5": {"sec_empty": 0.25, "sec_staffed": 0.75}}, {}],
        ["camera", [1, 1], None, {}, {}],
        ["laser_pattern", [1, 1], None, {"2": {"lz_static": 0.2, "lz_sweep": 0.4, "lz_timed": 0.4},
                                         "3": {"lz_static": 0.2, "lz_sweep": 0.4, "lz_timed": 0.4},
                                         "4": {"lz_static": 0.2, "lz_sweep": 0.4, "lz_timed": 0.4},
                                         "5": {"lz_static": 0.2, "lz_sweep": 0.4, "lz_timed": 0.4}}, {}],
        ["curator_route", [1, 1], None, {}, {}],
        ["court_doors", [1, 1], None, {}, {}],
        ["areaway", [1, 1], None, {}, {}],
        ["escape", [1, 1], None, {}, {}],
        ["xl_crate", [0, 0], None, {}, {}],
        ["admin_pa", [0, 0], None, {}, {}],
    ],
    "slots": {
        "centrepiece": [["cp_landing", 0.4], ["cp_treasury", 0.35], ["cp_store", 0.25]],
        "canvas_orchard": [["orchard_calloway", 1.0], ["orchard_benefactors", 1.0], ["orchard_quarantine", 0.7]],
        "canvas_widow": [["widow_sallow", 1.0], ["widow_founders", 1.0], ["widow_conservation", 0.7]],
        "canvas_saint": [["saint_maritime", 1.0], ["saint_harbour", 1.0], ["saint_store", 0.7]],
        "sensor_net": [["sensors_treasury", 0.5], ["sensors_upper", 0.35], ["sensors_all", 0.15]],
        "conservator": [["cons_late", 1.0], ["cons_gone", 1.0]],
        "keycard": [["kc_curator", 1.0], ["kc_security", 0.75], ["kc_registrar", 1.0], ["kc_conservator", 1.0]],
        "code_note": [["code_security_log", 1.0], ["code_curator_planner", 1.0], ["code_admin_postit", 1.0]],
        "guard_post": [["rover_ground", 1.0], ["rover_upper", 1.0], ["rover_basement", 1.0], ["dock_smoker", 1.0],
                       ["rover_none", 1.0]],
        "security_room_staffed": [["sec_staffed", 0.6], ["sec_empty", 0.4]],
        "camera": [["cam_a", 1.0], ["cam_b", 1.0], ["cam_c", 1.0]],
        "laser_pattern": [["lz_static", 0.5], ["lz_sweep", 0.2], ["lz_timed", 0.3]],
        "curator_route": [["curator_hall", 1.0], ["curator_office", 1.0]],
        "court_doors": [["court_doors_open", 1.0], ["court_doors_locked", 1.0]],
        "areaway": [["grate_loose", 1.0], ["grate_padlocked", 1.0]],
        "escape": [["esc_mews", 0.55], ["esc_parade", 0.45]],
        "xl_crate": [["xl_loan", 1.0], ["xl_none", 1.0]],
        "admin_pa": [["pa_late", 1.0], ["pa_none", 1.0]],
    },
    "scalars": {"last_call_s": [480, 600, 720], "patrons": [3, 5, 7, 9], "stragglers": [0, 1, 2],
                "store_paintings": [4, 6, 8], "consignment_lockers": [4, 6, 8], "escape_eta_s": [90, 120, 150]},
    "rare": {
        "curator_tipsy": {"chance": 0.05, "min_difficulty": None, "force": ["keycard", "kc_curator"], "requires": {}},
        "late_loan": {"chance": 0.05, "min_difficulty": None, "force": ["xl_crate", "xl_loan"], "requires": {}},
        "insurance_inspection": {"chance": 0.08, "min_difficulty": 2, "force": None, "requires": {}},
        "vaultline_early": {"chance": 0.06, "min_difficulty": 2, "force": None,
                            "requires": {"centrepiece": ["cp_landing", "cp_treasury"]}},
        "argus_upgrade": {"chance": 0.06, "min_difficulty": 4, "force": ["sensor_net", "sensors_all"], "requires": {}},
        "late_paperwork": {"chance": 0.05, "min_difficulty": None, "force": ["admin_pa", "pa_late"], "requires": {}},
    },
    "points": {
        "pp_spawn_portico": ["spawn", 1, [22.0, 36.0], {}],
        "pp_spawn_mews": ["spawn", 1, [26.0, -5.0], {"spawn_tag": "preplan_spawn_mews"}],
        "pp_spawn_roof": ["spawn", 3, [17.0, 6.0], {"spawn_tag": "preplan_spawn_roof"}],
        "pp_drop_court": ["drop_zone", 1, [-12.0, 24.0], {}],
        "pp_drop_mews": ["drop_zone", 1, [16.0, -2.0], {}],
        "pp_drop_roof": ["drop_zone", 3, [8.0, 3.0], {}],
        "pp_escape_mews": ["escape", 1, [37.0, -4.0], {"variant_group": "escape", "variant_slot": "esc_mews"}],
        "pp_escape_parade": ["escape", 1, [22.0, 34.0], {"variant_group": "escape", "variant_slot": "esc_parade"}],
        "pp_insider_registrar": ["insider", 1, [21.0, 3.0], {"variant_group": "keycard", "variant_slot": "kc_registrar"}],
        "pp_grate": ["insider", 1, [-4.0, 14.0], {"variant_group": "areaway", "variant_slot": "grate_loose"}],
        "pp_court_doors": ["insider", 1, [-1.0, 12.5], {"variant_group": "court_doors",
                                                        "variant_slot": "court_doors_open"}],
    },
    "reveals": {"intel_list": ["centrepiece", "canvas_orchard", "canvas_widow", "canvas_saint"],
                "intel_sensors": ["sensor_net"]},
}


def _top_dicts(s: str) -> List[str]:
    """Top-level {...} blocks of a Godot array literal."""
    out, depth, start = [], 0, -1
    for i, ch in enumerate(s):
        if ch == "{":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                out.append(s[start:i + 1])
    return out


def _array_block(text: str, name: str) -> str:
    m = re.search(r"^" + name + r" = Array\[Dictionary\]\(\[(.*?)\]\)\s*$", text, re.M | re.S)
    return m.group(1) if m else ""


def _num(v: str) -> object:
    return int(v) if re.fullmatch(r"-?\d+", v) else float(v)


def parse_b(files: Dict[str, str]) -> Dict:
    out: Dict = {"ref": "", "rules": [], "slots": {}, "scalars": {}, "rare": {}, "points": {}, "reveals": {}}
    v = files["variants"]
    for blk in _top_dicts(_array_block(v, "rules")):
        g = re.search(r'"group": &"(\w+)"', blk).group(1)
        pk = re.search(r'"pick": Vector2i\((\d+), (\d+)\)', blk)
        da = re.search(r'"difficulty_add": Array\[int\]\(\[([^\]]*)\]\)', blk)
        wbd: Dict[str, Dict[str, float]] = {}
        m = re.search(r'"weights_by_difficulty": \{(.*)', blk, re.S)
        if m:
            for d, body in re.findall(r"(\d+): \{([^}]*)\}", m.group(1)):
                wbd[d] = {k: float(w) for k, w in re.findall(r'&"(\w+)": ([\d.]+)', body)}
        sreq: Dict[str, Dict[str, List[str]]] = {}
        m2 = re.search(r'"slot_requires": \{\s*&"(\w+)": \{\s*&"(\w+)": \[([^\]]*)\]', blk)
        if m2:
            sreq[m2.group(1)] = {m2.group(2): re.findall(r'&"(\w+)"', m2.group(3))}
        out["rules"].append([g, [int(pk.group(1)), int(pk.group(2))],
                             [int(x) for x in da.group(1).split(",")] if da else None, wbd, sreq])
    for blk in _top_dicts(_array_block(v, "rare_events")):
        rid = re.search(r'"id": &"(\w+)"', blk).group(1)
        md = re.search(r'"min_difficulty": (\d+)', blk)
        fa = re.search(r'"force_active": \{\s*"group": &"(\w+)",\s*"slot": &"(\w+)"', blk)
        rq = re.search(r'"requires": \{\s*&"(\w+)": \[([^\]]*)\]', blk)
        out["rare"][rid] = {"chance": float(re.search(r'"chance": ([\d.]+)', blk).group(1)),
                            "min_difficulty": int(md.group(1)) if md else None,
                            "force": [fa.group(1), fa.group(2)] if fa else None,
                            "requires": {rq.group(1): re.findall(r'&"(\w+)"', rq.group(2))} if rq else {}}
    for blk in _top_dicts(_array_block(v, "scalars")):
        sid = re.search(r'"id": &"(\w+)"', blk).group(1)
        vals = re.search(r'"values": \[([^\]]*)\]', blk).group(1)
        out["scalars"][sid] = [int(float(x)) for x in vals.split(",")]
    sec = re.search(r"## Map slot names.*?\n(.*?)\n\*\*Scalars", files["readme"], re.S)
    for line in (sec.group(1) if sec else "").splitlines():
        c = _cells(line) if line.startswith("|") else []
        if len(c) < 4 or not re.fullmatch(r"\d+", c[0]):
            continue
        g = re.findall(r"`(\w+)`", c[1])[0]
        body = _strip_parens(c[2])
        out["slots"][g] = [[s, float(w) if w else None] for s, w in re.findall(r"`(\w+)`(?: ([\d.]+))?", body)]
    for blk in _top_dicts(_array_block(files["blueprint"], "points")):
        pid = re.search(r'"id": &"(\w+)"', blk).group(1)
        pos = re.search(r'"pos": Vector2\(([-\d.]+), ([-\d.]+)\)', blk)
        params = {k: val for k, val in re.findall(r'"(spawn_tag|variant_group|variant_slot)": &"(\w+)"', blk)}
        out["points"][pid] = [re.search(r'"category": &"(\w+)"', blk).group(1),
                              int(re.search(r'"floor": (\d+)', blk).group(1)),
                              [float(pos.group(1)), float(pos.group(2))], params]
    for key in ("intel_list", "intel_sensors"):
        m3 = re.search(r"reveals = Array\[StringName\]\(\[([^\]]*)\]\)", files[key])
        out["reveals"][key] = re.findall(r'&"(\w+)"', m3.group(1)) if m3 else []
    return out


def read_b_live(ref: str) -> Optional[Dict]:
    files: Dict[str, str] = {}
    for key, path in B_FILES.items():
        try:
            files[key] = subprocess.run(["git", "-C", ROOT, "show", "%s:%s" % (ref, path)], check=True,
                                        capture_output=True, text=True).stdout
        except (OSError, subprocess.CalledProcessError):
            return None
    sha = subprocess.run(["git", "-C", ROOT, "rev-parse", "--short=8", ref], capture_output=True, text=True).stdout
    b = parse_b(files)
    b["ref"] = sha.strip()
    return b


# ---------------------------------------------------------------------------------------------- check
def _weights_from_doc(text: str, n: int) -> Dict[str, List[float]]:
    """Base (and per-difficulty) weights from a Variable-table weights cell; {} when it is prose."""
    out: Dict[str, List[float]] = {}
    for label, key in (("Routine", "base"), ("Hazardous", "2"), ("Brutal\\+", "3+")):
        m = re.search(label + r"(?:/Tense)? ([\d.]+(?:/[\d.]+)+)", text)
        if m:
            out[key] = [float(x) for x in m.group(1).split("/")]
    if "base" not in out:
        m = re.match(r"\s*([\d.]+(?:, [\d.]+)+)", text)
        if m and len(m.group(1).split(",")) == n:
            out["base"] = [float(x) for x in m.group(1).split(",")]
    return out


def _norm(w: List[float]) -> List[float]:
    t = sum(w)
    return [round(x / t, 3) if t else 0.0 for x in w]


def check(b: Dict, b_snapshot_diff: List[str]) -> bool:
    ok = True
    notes: List[str] = []

    def fail(msg: str) -> None:
        nonlocal ok
        ok = False
        print("FAIL " + msg)

    doc = parse_doc(open(DOC, encoding="utf-8").read())
    ours = slot_index()

    print("Groups and slots (map list vs the doc's Variable table / Rare events vs ENV B's draft %s):" % b["ref"])
    doc_groups = {g: d for g, d in doc["groups"].items() if not d["scalar"]}
    for g, d in doc_groups.items():
        if g not in ours:
            fail("doc group `%s` has no slots in the map list" % g)
            continue
        for s in d["options"]:
            if s not in ours[g]:
                fail("doc slot %s/%s missing from the map list" % (g, s))
    b_slots = {g: [s for s, _ in v] for g, v in b["slots"].items()}
    b_rule_groups = [r[0] for r in b["rules"]]
    for g in b_rule_groups:
        if g not in ours:
            fail("ENV B rule group `%s` missing from the map list" % g)
    for g, sl in b_slots.items():
        for s in sl:
            if s not in ours.get(g, []):
                fail("ENV B slot %s/%s missing from the map list" % (g, s))
    for rid, r in b["rare"].items():
        for grp, sl in ([r["force"]] if r["force"] else []) + [[k, x] for k, v in r["requires"].items() for x in v]:
            if sl not in ours.get(grp, []):
                fail("ENV B rare event %s references %s/%s, missing from the map list" % (rid, grp, sl))
    for rule in b["rules"]:
        for slot, req in rule[4].items():
            for grp, sl in req.items():
                for s in [slot] + sl:
                    if not any(s in v for v in ours.values()):
                        fail("ENV B slot_requires %s -> %s/%s: unknown slot" % (rule[0], grp, s))
    doc_rare_slots = {t for r in doc["rare"].values() for t in r["tokens"]}
    for g, sl in ours.items():
        known_b = g in b_slots or g in b_rule_groups
        if g not in doc_groups and not known_b:
            fail("map group `%s` is referenced by neither the doc nor ENV B" % g)
        for s in sl:
            if s not in doc_groups.get(g, {}).get("options", []) and s not in b_slots.get(g, []):
                fail("map slot %s/%s is referenced by neither the doc nor ENV B" % (g, s))
    if [g for g in GROUP_ORDER] != list(ours.keys()) or GROUP_ORDER != b_rule_groups:
        fail("group order: map list %s / GROUP_ORDER %s / ENV B rules %s differ" % (list(ours), GROUP_ORDER,
                                                                                    b_rule_groups))
    for sid, vals in SCALARS.items():
        dv = [int(x) for x in doc["groups"].get(sid, {}).get("options", [])]
        if dv != vals:
            fail("scalar %s: map list %s, doc %s" % (sid, vals, dv))
    print("  %d groups, %d slots, %d scalars, %d rare events in the map list" % (len(ours), len(SLOTS), len(SCALARS),
                                                                                  len(RARE)))
    for rid, fs in RARE.items():
        if rid not in doc["rare"]:
            fail("rare event %s not in the doc" % rid)
        if fs and fs[1] not in ours.get(fs[0], []):
            fail("rare event %s forces %s/%s: not in the map list" % (rid, fs[0], fs[1]))

    # --- ENV B vs the doc (notes only) ---
    for g in doc_groups:
        if g not in b_slots:
            notes.append("B vs doc: doc group `%s` is not in ENV B's slot list" % g)
        elif doc_groups[g]["options"] != b_slots[g]:
            notes.append("B vs doc: %s options doc %s, B %s" % (g, doc_groups[g]["options"], b_slots[g]))
    for g in b_slots:
        if g not in doc_groups:
            notes.append("B vs doc: ENV B group `%s` (slots %s) is not in the doc's Variable table%s" % (
                g, b_slots[g], "; the doc only names `%s` in Rare events/Room list" % g if g in doc_rare_slots
                else "; the doc names no slot for it"))
    doc_order = [g for g in doc["order"] if g in doc_groups]
    b_order = [g for g in b_rule_groups if g in doc_groups]
    if doc_order != b_order:
        moved = [g for i, g in enumerate(b_order) if i >= len(doc_order) or doc_order[i] != g]
        notes.append("B vs doc: rule order differs (B moves %s); doc order %s puts `keycard` (slot_requires "
                     "conservator/cons_late) before `conservator`, which heist_map.md §5 forbids, so B's order is "
                     "the valid one" % (moved[:2], doc_order[5:9]))
    diffnames = {0: "Routine", 1: "Tense", 2: "Hazardous", 3: "Brutal", 4: "Lethal", 5: "Cataclysm"}
    for g in doc_groups:
        if g not in b_slots:
            continue
        w = _weights_from_doc(doc_groups[g]["weights"], len(doc_groups[g]["options"]))
        bw = [x for _, x in b["slots"][g]]
        if "base" in w and _norm(w["base"]) != _norm([x or 0.0 for x in bw]):
            notes.append("B vs doc: %s base weights doc %s, B %s" % (g, w["base"], bw))
        rule = [r for r in b["rules"] if r[0] == g][0]
        if "3+" in w and "2" not in w:
            b2 = rule[3].get("2")
            if b2:
                notes.append("B vs doc: %s: the doc gives Routine and Brutal+ rows only; B also applies the Brutal+ "
                             "row at Hazardous (the lead's GN-B1 ruling 1); the doc's Variable table is not updated" % g)
        for key, diffs in (("2", ["2"]), ("3+", ["3", "4", "5"])):
            if key not in w:
                continue
            for d in diffs:
                row = rule[3].get(d)
                if row is None:
                    notes.append("B vs doc: %s has no %s row in B (doc %s)" % (g, diffnames[int(d)], w[key]))
                    continue
                opts = doc_groups[g]["options"]
                got = [round(row.get(s, dict(b["slots"][g]).get(s) or 0.0), 3) for s in opts]
                if _norm(got) != _norm(w[key]):
                    notes.append("B vs doc: %s %s weights doc %s, B %s" % (g, diffnames[int(d)], w[key], got))
    md_map = {"Hazardous": 2, "Brutal": 3, "Lethal": 4}
    for rid, dr in doc["rare"].items():
        br = b["rare"].get(rid)
        if br is None:
            notes.append("B vs doc: rare event %s missing in B" % rid)
            continue
        if abs(br["chance"] - dr["chance"]) > 1e-9:
            notes.append("B vs doc: %s chance doc %.2f, B %.2f" % (rid, dr["chance"], br["chance"]))
        if md_map.get(dr["min_difficulty"] or "", None) != br["min_difficulty"]:
            notes.append("B vs doc: %s min_difficulty doc %s, B %s" % (rid, dr["min_difficulty"], br["min_difficulty"]))
        if br["force"] and br["force"][1] not in dr["tokens"] and br["force"][0] not in dr["tokens"]:
            notes.append("B vs doc: %s forces %s/%s; the doc's row names no slot (tokens %s)"
                         % (rid, br["force"][0], br["force"][1], dr["tokens"]))
        elif br["force"] and br["force"][1] not in dr["tokens"]:
            notes.append("B vs doc: %s forces group `%s` slot `%s`; the doc calls `%s` the slot (Rare events, Room "
                         "list LD)" % (rid, br["force"][0], br["force"][1], br["force"][0]))
        if br["requires"]:
            notes.append("B vs doc: %s carries `requires` %s inside `effects` (VariantResolver ignores it on rare "
                         "events; the mission script must gate the event, B README)" % (rid, br["requires"]))
    for rid in b["rare"]:
        if rid not in doc["rare"]:
            notes.append("B vs doc: B rare event %s not in the doc" % rid)
    for sid, vals in b["scalars"].items():
        if SCALARS.get(sid) != vals:
            notes.append("B vs doc: scalar %s B %s, doc/map %s" % (sid, vals, SCALARS.get(sid)))

    # --- rooms and positions ---
    print("Rooms and positions (every anchor inside its room's rectangle):")
    n = 0
    hung = 0
    for g, s, _, fl, rid, x, z, _, yaw, _ in SLOTS:
        n += 1
        if not room_exists(fl, rid):
            fail("slot %s/%s: room %s %s does not exist" % (g, s, fl, rid))
            continue
        if not inside(fl, rid, x, z):
            fail("slot %s/%s at (%g, %g) is outside room %s %s %s" % (g, s, x, z, fl, rid, room_rects(fl, rid)))
            continue
        if not -180.0 < yaw <= 180.0:
            fail("slot %s/%s: yaw %g is not in (-180, 180]" % (g, s, yaw))
        if g in USE_POINT_GROUPS:
            ux, uz = use_point(x, z, yaw)
            if not inside(fl, rid, ux, uz, 0.3):
                fail("slot %s/%s: its UsePoint (%.2f, %.2f) (yaw %g, %g m in front) is not >= 0.3 m inside room %s %s"
                     % (g, s, ux, uz, yaw, USE_POINT_M, fl, rid))
        if s in WALL_HUNG:
            hung += 1
            w = hung_wall(fl, rid, x, z)
            if w is None:
                fail("wall-hung slot %s/%s at (%g, %g): no wall of room %s %s on its nearest edge" % (g, s, x, z, fl, rid))
            elif w[0] > WALL_HUNG_MAX_M + 1e-6 or w[0] < 0.0:
                fail("wall-hung slot %s/%s is %.2f m from the %s wall's face (wants 0..%g m)" % (g, s, w[0], w[2],
                                                                                              WALL_HUNG_MAX_M))
            elif abs(((yaw - w[1]) + 180.0) % 360.0 - 180.0) > 1.0:
                fail("wall-hung slot %s/%s on the %s wall faces yaw %g; away from the wall is yaw %g" % (g, s, w[2], yaw,
                                                                                                      w[1]))
    print("  %d wall-hung slots on their wall (<= %g m, facing away); interactive slots' UsePoints inside their rooms"
          % (hung, WALL_HUNG_MAX_M))
    for cid, (fl, rid, x, z, _, lay) in CAMERAS.items():
        n += 1
        if not inside(fl, rid, x, z):
            fail("camera %s at (%g, %g) is outside room %s %s" % (cid, x, z, fl, rid))
    for nm, _, fl, rid, x, z, _ in PLAYER_SPAWNS:
        n += 1
        if not inside(fl, rid, x, z):
            fail("player spawn %s at (%g, %g) is outside room %s %s" % (nm, x, z, fl, rid))
    for slot, kind, fl, rid, x, z in ESCAPE_ZONES:
        n += 1
        if not inside(fl, rid, x, z):
            fail("%s zone (%s) at (%g, %g) is outside room %s %s" % (kind, slot, x, z, fl, rid))
    for pid, _, _, fl, rid, x, z, _ in PREPLAN:
        n += 1
        if not inside(fl, rid, x, z):
            fail("preplan point %s at (%g, %g) is outside room %s %s" % (pid, x, z, fl, rid))
    for rc in REVIEW_CAMERAS:
        n += 1
        if rc[2] and not inside(rc[1], rc[2], rc[3], rc[4], 0.5):
            fail("review camera %s at (%g, %g) is not >= 0.5 m inside room %s %s" % (rc[0], rc[3], rc[4], rc[1], rc[2]))
    for rid, x0, z0, x1, z1 in SCREENS:
        n += 1
        if not (inside("U", rid, x0, z0, 0.5) and inside("U", rid, x1, z1, 0.5)):
            fail("partition screen in %s (%g, %g)-(%g, %g) is not inside the room" % (rid, x0, z0, x1, z1))
    print("  %d anchors checked" % n)

    # --- contract-node needs ---
    print("Contract-node needs:")
    opts: Dict[str, int] = {}
    for _, tag, *_ in PLAYER_SPAWNS:
        opts[tag] = opts.get(tag, 0) + 1
    for pid, cat, _, _, _, _, _, params in PREPLAN:
        if cat == "spawn":
            tag = params.get("spawn_tag", "")
            if opts.get(tag, 0) < 4:
                fail("spawn option %s (spawn_tag `%s`) has %d PLAYER spawns (< 4)" % (pid, tag, opts.get(tag, 0)))
    print("  PLAYER spawns: %s" % ", ".join("`%s` x%d" % (k or "default", v) for k, v in opts.items()))
    names = [p[0] for p in POLICE_SPAWNS]
    if names != ["P1", "P2", "P3", "P4", "P5"]:
        fail("police spawns %s, expected P1..P5" % names)
    sectors = set()
    for nm, tag, x, z, y in POLICE_SPAWNS:
        if y > 0.0:
            sectors.add("roof")
        else:
            sectors.add(int(((math.degrees(math.atan2(x - 22.0, -(z - 15.0))) + 360.0 + 22.5) % 360.0) // 45.0))
        for h, (hx, hz) in HOLDOUTS.items():
            d = ((x - hx) ** 2 + (z - hz) ** 2) ** 0.5
            if d < MIN_CREW_DISTANCE_M:
                fail("police spawn %s is %.1f m from holdout %s (< %g)" % (nm, d, h, MIN_CREW_DISTANCE_M))
            elif d < 19.0:
                notes.append("doc: Police spawns says every spawn is >= 19 m from every holdout centroid; %s -> %s is "
                             "%.1f m (the doc's own table says %d); >= %g m (DirectorTweak) holds"
                             % (nm, h, d, round(d), MIN_CREW_DISTANCE_M))
        if -40 <= x <= 58 and -10 <= z <= 50 and y == 0.0:
            fail("police spawn %s at (%g, %g) is inside the play space" % (nm, x, z))
    if len(sectors) < 3:
        fail("police spawns cover %d directions (< 3)" % len(sectors))
    print("  POLICE spawns P1..P5: %d directions, all >= %g m from H1..H4" % (len(sectors), MIN_CREW_DISTANCE_M))
    esc = ours.get("escape", [])
    for s in esc:
        kinds = {k for sl, k, *_ in ESCAPE_ZONES if sl == s}
        if kinds != {"ESCAPE", "SECURE_LOOT"}:
            fail("escape slot %s has zones %s (needs ESCAPE + SECURE_LOOT)" % (s, sorted(kinds)))
        anchor = [a for a in SLOTS if a[1] == s][0]
        for sl, k, fl, rid, x, z in ESCAPE_ZONES:
            if sl == s and (anchor[4] != rid or ((anchor[5] - x) ** 2 + (anchor[6] - z) ** 2) ** 0.5 > 6.0):
                fail("%s zone of %s is not next to its slot anchor" % (k, s))
    print("  ESCAPE + SECURE_LOOT zones for %s" % ", ".join(esc))
    rc_ids = [r[0] for r in REVIEW_CAMERAS]
    doc_rc = re.findall(r"^\| `((?:rc_|TopDown)\w+)`", _section(open(DOC, encoding="utf-8").read(), "Review shots"), re.M)
    if rc_ids != doc_rc:
        fail("review cameras: map %s vs doc %s" % (sorted(set(rc_ids) ^ set(doc_rc)), "(sets differ)"))
    if len(rc_ids) < 12:
        fail("review cameras: %d (< 12)" % len(rc_ids))
    print("  review cameras: %d (doc: %d), each >= 0.5 m inside its room" % (len(rc_ids), len(doc_rc)))
    pp_ids = [p[0] for p in PREPLAN]
    if set(pp_ids) != set(doc["points"]):
        fail("preplan points: map vs doc differ: %s" % sorted(set(pp_ids) ^ set(doc["points"])))
    for pid, cat, fidx, fl, _, x, z, params in PREPLAN:
        dp = doc["points"].get(pid, {})
        if dp and dp["category"] != cat:
            fail("preplan %s category %s, doc %s" % (pid, cat, dp["category"]))
        if dp and any(params.get(k) != v for k, v in dp["params"].items()):
            fail("preplan %s params %s, doc %s" % (pid, params, dp["params"]))
        if dp and dp["floor"] is not None and dp["floor"] != fidx:
            fail("preplan %s floor %d, doc %d" % (pid, fidx, dp["floor"]))
        if P.FLOORS.index(fl) != fidx:
            fail("preplan %s floor index %d but plan floor %s" % (pid, fidx, fl))
        if "variant_slot" in params and params["variant_slot"] not in ours.get(params["variant_group"], []):
            fail("preplan %s names %s/%s: not in the map list" % (pid, params["variant_group"], params["variant_slot"]))
        bp = b["points"].get(pid)
        if bp is None:
            notes.append("B vs doc: preplan point %s is not in ENV B's blueprint" % pid)
            continue
        if bp[0] != cat or bp[1] != fidx or bp[3] != params:
            notes.append("B vs doc: preplan %s B %s/%s/%s, doc %s/%s/%s" % (pid, bp[0], bp[1], bp[3], cat, fidx, params))
        if (bp[2][0], bp[2][1]) != (x, z):
            fail("preplan %s at (%g, %g), ENV B's blueprint (%g, %g)" % (pid, x, z, bp[2][0], bp[2][1]))
    for pid in b["points"]:
        if pid not in pp_ids:
            notes.append("B vs doc: B blueprint point %s is not in the doc" % pid)
    print("  preplan points: %d (doc %d, ENV B blueprint %d)" % (len(pp_ids), len(doc["points"]), len(b["points"])))
    for key, groups in b["reveals"].items():
        for g in groups:
            if g not in ours:
                fail("ENV B asset.%s reveals unknown group `%s`" % (key, g))
    doc_text = open(DOC, encoding="utf-8").read()
    for key in ("intel_list", "intel_sensors"):
        m = re.search(r"asset\.%s\": \{\"reveals\": \[([^\]]*)\]" % key, doc_text)
        dg = re.findall(r'&"(\w+)"', m.group(1)) if m else []
        if dg != b["reveals"].get(key, []):
            notes.append("B vs doc: asset.%s reveals doc %s, B %s" % (key, dg, b["reveals"].get(key)))

    # --- camera layouts (B6) ---
    print("Camera layouts (camera_spine / camera_screen, B6):")
    lay: Dict[str, set] = {"cam_a": set(), "cam_b": set(), "cam_c": set()}
    for cid, row in CAMERAS.items():
        for lid in row[5]:
            if lid != "always":
                lay[lid].add(cid)
    if lay != DOC_LAYOUTS:
        fail("camera layouts %s differ from the doc's table %s" % (lay, DOC_LAYOUTS))
    for lid, cams in lay.items():
        spine = sorted({CAMERAS[c][1] for c in cams} & set(CAMERA_SPINE_ROOMS))
        if len(spine) > 1:
            fail("camera_spine: layout %s watches both %s" % (lid, spine))
    for s in CAMERA_SCREEN_SLOTS:
        a = [x for x in SLOTS if x[1] == s][0]
        cams = [c for c, row in CAMERAS.items() if row[1] == a[4]]
        if not cams:
            notes.append("doc: camera_screen slot %s is in %s, which has no camera in any layout (vacuous)" % (s, a[4]))
        elif not any(r[0] == a[4] for r in SCREENS):
            fail("camera_screen: %s (%s, camera %s) has no partition screen" % (s, a[4], cams))
    print("  cam_a %s | cam_b %s | cam_c %s | always C11 C14" % tuple(" ".join(sorted(lay[k], key=lambda c: int(c[1:])))
                                                                   for k in ("cam_a", "cam_b", "cam_c")))

    # --- the doc against itself (geometry notes found while building the list) ---
    corner = {(0, 0): "NW", (1, 0): "NE", (0, 1): "SW", (1, 1): "SE"}
    cam_doc = re.findall(r"^\| (C\d+) \| [A-Za-z]+, ([NS][EW]) corner \(([\d.]+), ([\d.]+)\)",
                         _section(doc_text, "Sightlines"), re.M)
    for cid, label, xs, zs in cam_doc:
        fl, rid = CAMERAS[cid][0], CAMERAS[cid][1]
        r = room_rects(fl, rid)[0]
        got = corner[(int(float(xs) > (r[0] + r[2]) / 2), int(float(zs) > (r[1] + r[3]) / 2))]
        if got != label:
            notes.append("doc: %s is called the %s %s corner but (%s, %s) is its %s corner" % (cid, rid, label, xs, zs,
                                                                                               got))
    wg = room_rects("G", "WG")[0]
    if not wg[1] <= CAMERAS["C8"][3] <= wg[3]:
        notes.append("doc: C8 is 'on the WG west wall (-0.4, 4)' but WG spans z %g-%g; z 4 is the SS/BR facade"
                     % (wg[1], wg[3]))
    notes.append("doc: X3 Sculpture Court is x -16...-2 (14 x 30) in Site/Room list, but the French doors (x 0), C8 "
                 "(-0.4, 4) and pp_court_doors (-1, 12.5) sit in x -2...0; ENV B's blueprint draws x -16...0 (used here)")
    notes.append("doc: the areaway ladder H^ is in PL at (2, 14) (under WG, inside the building) but the grate `a` is "
                 "at (-4, 14) in the court (site plan, ENV B blueprint); the basement ends at x 0, so the areaway "
                 "needs a well x ~-5...0 or the ladder moves (G1 layout decision)")
    notes.append("doc: the upper plan draws `S K` in CO and a `K` in AO (12, 4), but the Room list says the curator's "
                 "card is on her lanyard (kc_curator) and the Variable table has no AO keycard slot")
    notes.append("doc: Variable table names the standard kinds in brackets (`loot_spot`, `civilian_cluster`, "
                 "`locked_door`, `vent_open`); ENV B (and this list) use the variable names as group ids (four "
                 "loot_spot groups cannot share one id)")

    if b_snapshot_diff:
        for d in b_snapshot_diff:
            notes.append("B snapshot stale: " + d)
    print("Notes (for the lead / ENV B; not failures):")
    for nt in notes:
        print("  NOTE " + nt)
    print("RESULT:", "PASS" if ok else "FAIL")
    return ok


def _diff(a: object, b: object, path: str = "") -> List[str]:
    if isinstance(a, dict) and isinstance(b, dict):
        out: List[str] = []
        for k in sorted(set(a) | set(b), key=str):
            if k == "ref":
                continue
            out += _diff(a.get(k), b.get(k), "%s/%s" % (path, k))
        return out
    return [] if a == b else ["%s: snapshot %s, live %s" % (path, a, b)]


def main() -> int:
    live = [a for a in sys.argv if a.startswith("--b-live")]
    b = B_SNAPSHOT
    drift: List[str] = []
    if live:
        ref = live[0].split("=", 1)[1] if "=" in live[0] else B_REF
        lb = read_b_live(ref)
        if lb is None:
            print("FAIL cannot read ENV B's draft from %s (git fetch origin env/b-gallery-night)" % ref)
            return 1
        drift = _diff(B_SNAPSHOT, lb)
        b = lb
    if "--check" in sys.argv:
        print("ENV B draft: %s (%s)" % (b["ref"], "live" if live else "embedded snapshot"))
        return 0 if check(b, drift) else 1
    for g in GROUP_ORDER:
        for row in [r for r in SLOTS if r[0] == g]:
            print("%-22s %-22s w %-5g %s %-4s (%6.1f, %5.1f) yaw %4g  %s" % (row[0], row[1], row[2], row[3], row[4],
                                                                              row[5], row[6], row[8], row[9]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
