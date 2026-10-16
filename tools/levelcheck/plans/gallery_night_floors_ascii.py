# ASCII floor plans + checks for docs/design/heists/gallery_night.md ("Floor plans", "Room list").
# Run: python3 tools/levelcheck/plans/gallery_night_floors_ascii.py            (the four plans)
#      python3 tools/levelcheck/plans/gallery_night_floors_ascii.py --check    (consistency report, exit 0/1)
#
# 1 char = 1 m; each char is a grid POINT (x = col, z = row). Rooms are rectangles (x0, z0, x1, z1) in
# metres between wall centre lines (exterior 0.5 m limestone, interior 0.2 m, art-store vault 0.4 m `%`).
# Origin = the building's NW corner, +x east, +z south (the Mews at the top, Aldous Parade at the bottom).
# Floors: B Basement (FFL -4.2, x 0-32 z 0-20), G Ground (0.0, x 0-44 z 0-30), U Upper (5.4, x 0-44
# z 0-30), R Roof deck (+9.0, north strip x 0-32 z 0-8). This file is the data source for the greybox.
#
# --check: the rooms (+ declared voids) tile each floor footprint exactly; every opening lies on a wall
# (or the facade) with exactly one room on each side; every room has a door or opening; every room is
# reachable from outside; room sizes match the Room list; the shafts line up; the stair arithmetic of the
# vertical data table (risers x height = storey, runs, landings <= 16 risers, Stair SS core fit).
import sys
from typing import Dict, List, Optional, Set, Tuple

Rect = Tuple[float, float, float, float]

FLOORS = ("B", "G", "U", "R")
FLOOR_HEIGHTS = {"B": -4.2, "G": 0.0, "U": 5.4, "R": 9.0}   # HeistMap.floor_heights (D-054, D-040)
FLOOR_TITLES = {"B": "BASEMENT (FFL -4.2)", "G": "GROUND (FFL 0.0)", "U": "UPPER (FFL 5.4)", "R": "ROOF DECK (+9.0)"}
FOOT: Dict[str, Rect] = {"B": (0, 0, 32, 20), "G": (0, 0, 44, 30), "U": (0, 0, 44, 30), "R": (0, 0, 32, 8)}
RULER = {"B": 32, "G": 44, "U": 44, "R": 44}   # ruler width (the doc's roof ruler runs to 44 like G/U)

# The vertical shafts, at the same plan position on every floor they serve.
SS: Rect = (0, 0, 3, 8)      # Stair SS (service U-stair): 3.0 x 8.0 centre lines, 0.3 m walls
LF: Rect = (28, 0, 32, 6)    # art lift (bag_lift `art_lift`, 2.6 x 5.6 car), landings B/G/U

# ROOMS[floor] = [(id, RoomVolume.purpose, rect)]. Ids and purposes are the Room list's. An id may appear
# more than once (an L-shaped room); its rects are one room (no wall between them).
ROOMS: Dict[str, List[Tuple[str, str, Rect]]] = {
    "B": [
        ("SS", "stair", SS),
        ("LK", "locker_room", (3, 0, 10, 6)),        # staff + attendant lockers, 2 WC cubicles
        ("FR", "storage", (10, 0, 20, 6)),           # frame store / packing
        ("QR", "storage", (20, 0, 28, 6)),           # quarantine (orchard_quarantine slot)
        ("LF", "elevator", LF),
        ("BB", "corridor", (3, 6, 32, 8)),           # basement spine
        ("PL", "plant", (0, 8, 12, 20)),             # climate plant; areaway ladder to the court grate
        ("AS", "vault", (12, 8, 32, 20)),            # art store (the vault), 0.4 m reinforced walls
    ],
    "G": [
        ("SS", "stair", SS),
        ("BR", "break_room", (3, 0, 9, 6)),
        ("WC", "restroom", (9, 0, 12, 6)),           # staff
        ("SC", "security_room", (12, 0, 18, 6)),
        ("RG", "office", (18, 0, 24, 6)),            # registrar
        ("J", "janitor", (24, 0, 26, 6)),
        ("E1", "electrical", (26, 0, 28, 6)),
        ("LF", "elevator", LF),
        ("LD", "loading", (32, 0, 44, 12)),
        ("BC", "corridor", (3, 6, 32, 8)),           # back corridor (BOH spine)
        ("WG", "gallery", (0, 8, 12, 20)),           # Founders' Gallery
        ("GH", "atrium", (12, 8, 32, 26)),           # Great Hall (void above it on U: 252 of 360 m2)
        ("EG", "gallery", (32, 12, 44, 24)),         # Harbour Gallery
        ("DC", "gallery", (0, 20, 7, 30)),           # Drawings Cabinet
        ("PWW", "restroom", (7, 20, 12, 25)),        # public, women (drawn "WCW")
        ("PWM", "restroom", (7, 25, 12, 30)),        # public, men (drawn "WCM")
        ("CK", "reception", (12, 26, 18, 30)),       # cloakroom
        ("VE", "lobby", (18, 26, 26, 30)),           # vestibule
        ("GS", "retail", (26, 26, 32, 30)),          # gift shop
        ("EB", "gallery", (32, 24, 44, 30)),         # Benefactors' Room
    ],
    "U": [
        ("SS", "stair", SS),
        ("CO", "office", (3, 0, 10, 6)),             # curator (wall safe, S K)
        ("AO", "office", (10, 0, 17, 6)),            # development / admin
        ("UW", "restroom", (17, 0, 20, 6)),          # staff
        ("FS", "storage", (20, 0, 22, 6)),           # frame and plinth store (drawn "F")
        ("SV", "server_room", (22, 0, 28, 6)),       # Argus head-end, hack_terminal
        ("LF", "elevator", LF),
        ("CS", "workshop", (32, 0, 44, 12)),         # Conservation Studio
        ("UC", "corridor", (3, 6, 32, 8)),           # upper corridor
        ("UG1", "gallery", (0, 8, 12, 20)),          # Calloway Room (top-lit)
        ("BW", "atrium", (12, 8, 15, 26)),           # west balcony over the Great Hall
        ("BE", "atrium", (29, 8, 32, 26)),           # east balcony
        ("UG3", "gallery", (32, 12, 44, 24)),        # Maritime Room
        ("UG2", "gallery", (0, 20, 12, 30)),         # Sallow Room
        ("SL", "atrium", (12, 26, 32, 30)),          # south loggia
        ("AT", "staff_room", (32, 24, 36, 30)),      # attendants' station
        ("TR", "vault", (36, 24, 44, 30)),           # Treasury
    ],
    "R": [
        ("HH", "stair", SS),                         # Stair SS head house ("SS-roof / HH")
        ("X4", "exterior", (3, 0, 28, 8)),           # roof deck
        ("X4", "exterior", (28, 6, 32, 8)),          # roof deck, the strip south of the motor room
        ("LM", "elevator_machine", LF),              # lift motor room (locked; not in the Room list)
    ],
}
# Voids (no floor on this level) that take part in the tiling.
VOID: Dict[str, List[Tuple[str, Rect]]] = {"U": [("GH_VOID", (15, 8, 29, 26))]}   # the Great Hall volume
# Room edges that are a 1.1 m balustrade (r) instead of a wall.
RAIL: Dict[str, List[Rect]] = {"U": [(15, 8, 15, 26), (29, 8, 29, 26), (15, 26, 29, 26)]}
# Art-store vault walls (0.4 m reinforced) drawn `%`; the east wall is the exterior wall.
VAULT: Dict[str, List[Rect]] = {"B": [(12, 8, 31, 8), (12, 8, 12, 20), (12, 20, 31, 20)]}
# Rooms allowed to have no door (with the reason).
NO_DOOR_OK = {("R", "LM"): "lift motor room: locked, no interaction (Roof notes)"}

# Openings: (floor, kind, x0, z0, x1, z1, note). One of x0 == x1 (a wall along z) or z0 == z1 (a wall
# along x); the span is the clear opening in metres along that wall, and the plan draws `kind` at every
# grid point p with start <= p < end. Kinds: D door (0.9-1.2; 1.8 = double DD), A arch / wide opening
# (no leaf), S arch with a lockdown shutter, R roller door, V vault door, W window, h ladder top.
OPEN: List[Tuple[str, str, float, float, float, float, str]] = [
    # --- Basement ---
    ("B", "D", 3, 6.5, 3, 7.5, "SS stair door (E wall, south floor landing; vision panel; push bar)"),
    ("B", "D", 5.5, 6, 6.5, 6, "LK"),
    ("B", "D", 14.5, 6, 15.5, 6, "FR"),
    ("B", "D", 23.5, 6, 24.5, 6, "QR"),
    ("B", "D", 28.6, 6, 30.4, 6, "LF art-lift landing door (S), 1.8 m"),
    ("B", "D", 4.5, 8, 5.5, 8, "PL"),
    ("B", "V", 20.5, 8, 22.5, 8, "AS vault door: lock VAULT, width_m 2.0, keycard_reader beside it (stealth); "
                                 "thermal-drill point T (22, 7), loud, 240 s"),
    # --- Ground ---
    ("G", "D", 3, 6.5, 3, 7.5, "SS stair door"),
    ("G", "D", 4.5, 6, 5.5, 6, "BR"),
    ("G", "D", 9.5, 6, 10.5, 6, "WC"),
    ("G", "D", 15.5, 6, 16.5, 6, "SC (plan draws x 16; the Room list says door S (15, 6), 121 deg off the "
                                 "operator's facing)"),
    ("G", "D", 19.5, 6, 20.5, 6, "RG"),
    ("G", "D", 24.5, 6, 25.5, 6, "J"),
    ("G", "D", 26.5, 6, 27.5, 6, "E1"),
    ("G", "D", 28.6, 6, 30.4, 6, "LF art-lift landing door (S), 1.8 m"),
    ("G", "D", 32, 1.5, 32, 4.5, "LF art-lift landing door (E) to LD (through car)"),
    ("G", "D", 32, 6.1, 32, 7.9, "BC -> LD double door, 1.8 m"),
    ("G", "D", 4.6, 8, 6.4, 8, "BC -> WG art-handling door DD, 1.8 m, LOCKPICK"),
    ("G", "D", 18.5, 8, 19.5, 8, "staff door under the stair (BC -> GH), LOCKPICK, NPC-authorised; "
                                 "2.4 m under the half-landing soffit"),
    ("G", "R", 34.7, 0, 38.3, 0, "LD roller door N (Mews), 3.6 x 4.5"),
    ("G", "D", 40.5, 0, 41.5, 0, "LD personnel door N (Mews), LOCKPICK; fire exit"),
    ("G", "D", 37, 12, 39, 12, "LD -> EG art door DD: 2.0 m sliding fire door, KEYCARD reader on the LD "
                               "side, industrial_door shutter in loud"),
    ("G", "D", 0, 11.6, 0, 13.4, "WG Sculpture Court French doors (court_doors variable); fire exit"),
    ("G", "A", 12, 12, 12, 16, "WG <-> GH arch, 4.0 m"),
    ("G", "D", 2.5, 20, 3.5, 20, "WG -> DC"),
    ("G", "D", 12, 21.5, 12, 22.5, "GH -> PWW"),
    ("G", "D", 12, 25, 12, 26, "GH -> PWM (drawn on the PWW/PWM partition line; kept inside PWM's wall)"),
    ("G", "A", 32, 16, 32, 20, "GH <-> EG arch, 4.0 m"),
    ("G", "A", 36, 24, 40, 24, "EG <-> EB opening, 4.0 m"),
    ("G", "D", 14.5, 26, 15.5, 26, "GH -> CK"),
    ("G", "A", 20.5, 26, 23.5, 26, "VE <-> GH (glass inner screen opening), 3 m"),
    ("G", "D", 27.5, 26, 28.5, 26, "GS (plan: GH side; the Room list says door from VE, LOCKPICK)"),
    ("G", "D", 18.5, 30, 22.5, 30, "VE bronze outer doors, 4 leaves (open until last call, then locked)"),
    ("G", "W", 4.5, 0, 5.5, 0, "BR window N"),
    ("G", "W", 14.5, 0, 15.5, 0, "SC window N (frosted)"),
    ("G", "W", 20.5, 0, 21.5, 0, "RG window N"),
    ("G", "W", 12.5, 30, 13.5, 30, "CK shop-front glazing"),
    ("G", "W", 15.5, 30, 16.5, 30, "CK shop-front glazing"),
    ("G", "W", 27.5, 30, 28.5, 30, "GS shop-front glazing"),
    ("G", "W", 30.5, 30, 31.5, 30, "GS shop-front glazing"),
    ("G", "W", 33.5, 30, 34.5, 30, "EB tall window S (sill 0.9, blinds)"),
    ("G", "W", 37.5, 30, 38.5, 30, "EB tall window S"),
    ("G", "W", 41.5, 30, 42.5, 30, "EB tall window S"),
    ("G", "W", 44, 25.5, 44, 26.5, "EB tall window E (Wexley St)"),
    ("G", "W", 44, 27.5, 44, 28.5, "EB tall window E"),
    # --- Upper ---
    ("U", "D", 3, 6.5, 3, 7.5, "SS stair door"),
    ("U", "D", 5.5, 6, 6.5, 6, "CO"),
    ("U", "D", 13.5, 6, 14.5, 6, "AO"),
    ("U", "D", 17.5, 6, 18.5, 6, "UW"),
    ("U", "D", 20.5, 6, 21.5, 6, "FS"),
    ("U", "D", 24.5, 6, 25.5, 6, "SV: CODE door (code_group argus, keypad on the UC side)"),
    ("U", "D", 28.6, 6, 30.4, 6, "LF art-lift landing door (S), 1.8 m"),
    ("U", "D", 32, 1.5, 32, 4.5, "LF art-lift landing door (E) to CS"),
    ("U", "D", 32, 6.5, 32, 7.5, "UC -> CS"),
    ("U", "D", 12.5, 8, 13.5, 8, "UC -> BW"),
    ("U", "D", 29.5, 8, 30.5, 8, "UC -> BE"),
    ("U", "S", 12, 11.5, 12, 14.5, "Calloway arch UG1 <-> BW, 3 m: industrial_door shutter, starts_open, "
                                   "lock BARRED on lockdown"),
    ("U", "A", 3.5, 20, 6.5, 20, "UG1 <-> UG2 arch, 3 m"),
    ("U", "D", 35.5, 12, 36.5, 12, "UG3 -> CS, LOCKPICK"),
    ("U", "A", 32, 15.5, 32, 18.5, "BE <-> UG3 arch, 3 m"),
    ("U", "D", 32.5, 24, 33.5, 24, "UG3 -> AT"),
    ("U", "D", 38.5, 24, 39.5, 24, "UG3 -> TR: KEYCARD + shutter; laser grid inside at z 26.5"),
    ("U", "A", 12, 26.6, 12, 29.0, "UG2 <-> SL arch, 2.4 m"),
    ("U", "D", 32, 27.5, 32, 28.5, "SL -> AT"),
    ("U", "W", 4.5, 0, 5.5, 0, "CO window N"),
    ("U", "W", 13.5, 0, 14.5, 0, "AO window N"),
    # The doc draws this window on the UW/FS partition point (x 20); a centred span would straddle the
    # partition, so the data puts it in FS's facade bay (x 20-21). Lead to confirm (or move it into UW).
    ("U", "W", 20.5, 0, 21.5, 0, "FS window N"),
    ("U", "W", 44, 1.5, 44, 2.5, "CS window E"),
    ("U", "W", 44, 3.5, 44, 4.5, "CS window E"),
    ("U", "W", 44, 5.5, 44, 6.5, "CS window E"),
    ("U", "W", 44, 7.5, 44, 8.5, "CS window E"),
    ("U", "W", 44, 9.5, 44, 10.5, "CS window E"),
    ("U", "W", 15.5, 30, 16.5, 30, "SL tall window S (sill 0.9)"),
    ("U", "W", 19.5, 30, 20.5, 30, "SL tall window S"),
    ("U", "W", 23.5, 30, 24.5, 30, "SL tall window S"),
    ("U", "W", 27.5, 30, 28.5, 30, "SL tall window S"),
    # --- Roof deck ---
    ("R", "D", 3, 6.5, 3, 7.5, "HH roof door: LOCKPICK 8 s from the deck, push bar inside"),
    ("R", "h", 9.5, 0, 10.5, 0, "fire-escape ladder top (caged, 9.0 m from the Mews; masked only, no bags)"),
]

# Vertical links other than Stair SS and the art lift (for the reachability check).
LINKS = [("B", "PL", "G", "OUT", "areaway ladder (PL floor -> court grate), masked only, no bags"),
         ("G", "GH", "U", "BW", "grand stair, west return flight"),
         ("G", "GH", "U", "BE", "grand stair, east return flight"),
         ("R", "X4", "G", "OUT", "fire-escape ladder (Mews)")]


def _stair_arrows() -> List[Tuple[float, float, str]]:
    return [(1, z, "^v") for z in range(1, 6)]


# Labels and symbols: (x, z, text), written last (labels may overwrite a wall char, as in the doc).
MARK: Dict[str, List[Tuple[float, float, str]]] = {
    "B": _stair_arrows() + [
        (4, 1, "LK"), (4, 3, "WC"), (11, 1, "FR FRAMES"), (21, 1, "QR"), (22, 3, "L"), (29, 1, "LF"),
        (8, 7, "BB"), (22, 7, "T"),
        (1, 9, "PL PLANT"), (2, 14, "H^"), (8, 17, "G"),
        (13, 9, "AS ART STORE"),
        (14, 11, "[==]  [==]  [==]"), (14, 13, "[==]  [==]  [==]"), (14, 15, "[==]  [==]  [==]"),
        (14, 17, "[==]  [==]  [==]"), (14, 12, "L"), (26, 16, "L"), (20, 18, "L"),
        (30, 10, "bb"), (30, 12, "bb"), (30, 14, "bb"), (30, 16, "bb"),
    ],
    "G": _stair_arrows() + [
        (4, 1, "BR"), (10, 1, "WC"), (13, 1, "SC"), (13, 3, "mon"), (14, 4, "o"), (19, 1, "RG"),
        (25, 1, "J"), (27, 1, "E"), (29, 1, "LF"),
        (34, 2, "LD LOADING"), (34, 6, "crates"), (38, 9, "L"),
        (8, 7, "BC BACK CORRIDOR"),
        (1, 9, "WG FOUNDERS"), (1, 10, "GALLERY"), (1, 16, "L"), (7, 16, "L"), (10, 16, "L"), (5, 18, "G"),
        # Great Hall: half landing l (+2.7) with cp_landing L, central flight ^, return flights v
        (15, 9, "llllllLlllllll")] + [(15, z, "v") for z in range(10, 14)] + [(28, z, "v") for z in range(10, 14)]
    + [(21, z, "^^^") for z in range(10, 15)] + [
        (21, 15, "rope"), (22, 17, "G"), (13, 18, "====="), (13, 19, "bar"),
        (19, 19, "c"), (22, 19, "c"), (26, 19, "c"), (24, 22, "c"), (27, 22, "c"), (14, 23, "GH GREAT HALL"),
        (33, 13, "EG HARBOUR"), (33, 16, "L"), (43, 18, "L"), (37, 20, "G"), (38, 22, "L"),
        (33, 25, "EB"), (34, 28, "L"), (41, 28, "L"),
        (1, 21, "DC"), (1, 22, "DRAWINGS"), (2, 26, "L"), (4, 26, "L"),
        (8, 21, "WCW"), (8, 26, "WCM"), (13, 27, "CK"), (19, 27, "VE"), (27, 27, "GS"),
    ],
    "U": _stair_arrows() + [
        (4, 1, "CO"), (4, 3, "S K"), (11, 1, "AO"), (12, 4, "K"), (15, 4, "c"), (18, 1, "UW"), (21, 1, "F"),
        (23, 1, "SV"), (26, 3, "H"), (29, 1, "LF"),
        (34, 2, "CS"), (34, 4, "(N-light)"), (36, 8, "L  L"), (40, 10, "K"),
        (8, 7, "UC UPPER CORRIDOR"),
        (1, 9, "UG1"), (1, 10, "CALLOWAY"), (6, 11, "L"), (1, 14, "L"), (6, 15, "G"), (10, 17, "L"),
        (13, 10, "BW"), (30, 10, "BE"), (17, 12, "(void over GH)"),
        (15, 14, "l"), (15, 15, "l"), (15, 16, "l"), (29, 14, "l"), (29, 15, "l"), (29, 16, "l"),
        (33, 13, "UG3"), (33, 14, "MARITIME"), (42, 15, "L"), (34, 18, "L"), (38, 19, "G"), (40, 22, "L"),
        (1, 21, "UG2 SALLOW"), (1, 25, "L"), (6, 25, "L"), (6, 27, "G"), (10, 28, "L"),
        (22, 27, "G"), (16, 28, "SL SOUTH LOGGIA"),
        (33, 25, "AT"), (37, 25, "TR"), (37, 26, ":::::::"), (40, 28, "L"),
    ],
    "R": _stair_arrows() + [
        (1, 0, "HH"), (29, 1, "LM"), (5, 2, "ROOF DECK +9.0"), (6, 4, "AHU  AHU    cond."),
        (12, 6, "P  P  P  P"),
    ],
}

# Room list sizes (x by z, between wall centre lines) for the size check.
SIZES = {"SS": (3, 8), "HH": (3, 8), "LF": (4, 6), "LK": (7, 6), "FR": (10, 6), "QR": (8, 6), "BB": (29, 2),
         "PL": (12, 12), "AS": (20, 12), "BR": (6, 6), "WC": (3, 6), "SC": (6, 6), "RG": (6, 6), "J": (2, 6),
         "E1": (2, 6), "BC": (29, 2), "LD": (12, 12), "GH": (20, 18), "VE": (8, 4), "CK": (6, 4), "GS": (6, 4),
         "WG": (12, 12), "DC": (7, 10), "PWW": (5, 5), "PWM": (5, 5), "EG": (12, 12), "EB": (12, 6),
         "UC": (29, 2), "CO": (7, 6), "AO": (7, 6), "SV": (6, 6), "UW": (3, 6), "FS": (2, 6), "CS": (12, 12),
         "BW": (3, 18), "BE": (3, 18), "SL": (20, 4), "UG1": (12, 12), "UG2": (12, 10), "UG3": (12, 12),
         "AT": (4, 6), "TR": (8, 6), "X4": (25, 8)}

# Stair data (vertical data table): (name, from FFL, to FFL, flights, risers per flight, riser, tread).
STAIRS = [("SS", -4.2, 0.0, 2, 12, 0.175, 0.28), ("SS", 0.0, 5.4, 2, 15, 0.180, 0.28),
          ("SS", 5.4, 9.0, 2, 10, 0.180, 0.28), ("grand", 0.0, 5.4, 2, 15, 0.180, 0.30)]
DOC_RUNS = {(-4.2, 0.0): 3.08, (0.0, 5.4): 3.92, (5.4, 9.0): 2.52}   # runs quoted in the table


# ---------------------------------------------------------------------------------------------- model
def cells(fl: str) -> Dict[Tuple[int, int], str]:
    """Unit cell (i, j) = [i, i+1] x [j, j+1] -> room id (or the void id)."""
    out: Dict[Tuple[int, int], str] = {}
    for rid, rect in [(r[0], r[2]) for r in ROOMS[fl]] + VOID.get(fl, []):
        x0, z0, x1, z1 = (int(v) for v in rect)
        for i in range(x0, x1):
            for j in range(z0, z1):
                out[(i, j)] = rid if (i, j) not in out else out[(i, j)] + "&" + rid
    return out


def rail_edges(fl: str) -> Set[Tuple[int, int, int, int]]:
    out = set()
    for (x0, z0, x1, z1) in RAIL.get(fl, []):
        for (a, b, c, d) in unit_edges(x0, z0, x1, z1):
            out.add((a, b, c, d))
    return out


def unit_edges(x0: float, z0: float, x1: float, z1: float) -> List[Tuple[int, int, int, int]]:
    if x0 == x1:
        return [(int(x0), k, int(x0), k + 1) for k in range(int(min(z0, z1)), int(max(z0, z1)))]
    return [(k, int(z0), k + 1, int(z0)) for k in range(int(min(x0, x1)), int(max(x0, x1)))]


def sides(c: Dict[Tuple[int, int], str], e: Tuple[int, int, int, int]) -> Tuple[Optional[str], Optional[str]]:
    a, b, cc, d = e
    if a == cc:   # wall along z at x = a: cells west / east
        return c.get((a - 1, b)), c.get((a, b))
    return c.get((a, b - 1)), c.get((a, b))   # wall along x at z = b: cells north / south


def walls(fl: str) -> Set[Tuple[int, int, int, int]]:
    """Unit edges with different rooms on the two sides (incl. the facade), minus balustrades."""
    c = cells(fl)
    x0, z0, x1, z1 = (int(v) for v in FOOT[fl])
    out = set()
    rails = rail_edges(fl)
    for i in range(x0, x1 + 1):
        for j in range(z0, z1 + 1):
            for e in ((i, j, i, j + 1), (i, j, i + 1, j)):
                if (e[2] > x1) or (e[3] > z1):
                    continue
                s = sides(c, e)
                if s[0] != s[1] and e not in rails:
                    out.add(e)
    return out


# --------------------------------------------------------------------------------------------- render
def plan(fl: str) -> str:
    w = RULER[fl]
    _, _, fx, fz = (int(v) for v in FOOT[fl])
    g = [[" "] * (w + 1) for _ in range(fz + 1)]
    ws = walls(fl)

    def deg(i: int, j: int) -> Tuple[bool, bool, bool, bool]:
        return ((i - 1, j, i, j) in ws, (i, j, i + 1, j) in ws, (i, j - 1, i, j) in ws, (i, j, i, j + 1) in ws)

    for j in range(fz + 1):
        for i in range(fx + 1):
            le, ri, up, dn = deg(i, j)
            if (le or ri) and (up or dn):
                g[j][i] = "+"
            elif le or ri:
                g[j][i] = "-"
            elif up or dn:
                g[j][i] = "|"
            if i in (0, fx) or j in (0, fz):
                g[j][i] = "#"
    for (x0, z0, x1, z1) in VAULT.get(fl, []):
        for k in range(int(max(x1 - x0, z1 - z0)) + 1):
            g[int(z0) + (k if x0 == x1 else 0)][int(x0) + (k if z0 == z1 else 0)] = "%"
    for (x0, z0, x1, z1) in RAIL.get(fl, []):
        for k in range(int(max(x1 - x0, z1 - z0)) + 1):
            i, j = int(x0) + (k if z0 == z1 else 0), int(z0) + (k if x0 == x1 else 0)
            le, ri, up, dn = deg(i, j)
            if not ((le and ri) or (up and dn)):   # a rail ends against a through wall, not over it
                g[j][i] = "r"
    for (f2, k, x0, z0, x1, z1, _) in OPEN:
        if f2 != fl:
            continue
        for (i, j) in span_points(x0, z0, x1, z1):
            g[j][i] = k
    for (x, z, s) in MARK.get(fl, []):
        for n, ch in enumerate(s):
            g[int(z)][int(x) + n] = ch
    out = ["      " + "".join(str(i % 10) for i in range(w + 1))]
    for j in range(fz + 1):
        out.append(("%5d " % j if j % 2 == 0 else "      ") + "".join(g[j]).rstrip())
    return "\n".join(out)


def span_points(x0: float, z0: float, x1: float, z1: float) -> List[Tuple[int, int]]:
    """Grid points p of an opening with start <= p < end (along its wall)."""
    eps = 1e-9
    if x0 == x1:
        return [(int(x0), p) for p in range(int(-(-z0 // 1)), int(z1 + 1)) if z0 - eps <= p < z1 - eps]
    return [(p, int(z0)) for p in range(int(-(-x0 // 1)), int(x1 + 1)) if x0 - eps <= p < x1 - eps]


# ---------------------------------------------------------------------------------------------- check
def opening_sides(fl: str, x0: float, z0: float, x1: float, z1: float) -> Tuple[Set[str], Set[str], bool]:
    """Rooms west/north and east/south of an opening; and whether the whole span is on a wall."""
    c = cells(fl)
    ws = walls(fl)
    if x0 == x1:
        es = [(int(x0), k, int(x0), k + 1) for k in range(int(z0 // 1), int(-(-z1 // 1)))]
    else:
        es = [(k, int(z0), k + 1, int(z0)) for k in range(int(x0 // 1), int(-(-x1 // 1)))]
    a: Set[str] = set()
    b: Set[str] = set()
    for e in es:
        s = sides(c, e)
        a.add(s[0] or "OUT")
        b.add(s[1] or "OUT")
    return a, b, all(e in ws for e in es)


def area(r: Rect) -> float:
    return (r[2] - r[0]) * (r[3] - r[1])


def check() -> bool:
    ok = True

    def fail(msg: str) -> None:
        nonlocal ok
        ok = False
        print("FAIL " + msg)

    # 1. tiling
    print("Tiling (rooms + voids vs footprint, per 1 m cell):")
    for fl in FLOORS:
        c = cells(fl)
        x0, z0, x1, z1 = (int(v) for v in FOOT[fl])
        over = sorted({v for v in c.values() if "&" in v})
        outside = sorted({v for (i, j), v in c.items() if not (x0 <= i < x1 and z0 <= j < z1)})
        gaps = [(i, j) for i in range(x0, x1) for j in range(z0, z1) if (i, j) not in c]
        for v in over:
            fail("%s overlap %s" % (fl, v))
        for v in outside:
            fail("%s room outside the footprint %s" % (fl, v))
        if gaps:
            fail("%s %d m2 not covered, e.g. cell %s" % (fl, len(gaps), gaps[0]))
        tot = sum(area(r) for _, _, r in ROOMS[fl]) + sum(area(r) for _, r in VOID.get(fl, []))
        print("  %s: rooms %.0f + voids %.0f = %.0f m2 vs footprint %.0f m2 -> %s"
              % (fl, tot - sum(area(r) for _, r in VOID.get(fl, [])), sum(area(r) for _, r in VOID.get(fl, [])),
                 tot, area(FOOT[fl]), "OK" if not (over or outside or gaps) and tot == area(FOOT[fl]) else "MISMATCH"))
    gh = [r for rid, _, r in ROOMS["G"] if rid == "GH"][0]
    void = VOID["U"][0][1]
    print("  Great Hall void %.0f of %.0f m2 (doc: 252 of 360) -> %s"
          % (area(void), area(gh), "OK" if (area(void), area(gh)) == (252, 360) else "MISMATCH"))
    if (area(void), area(gh)) != (252, 360):
        fail("Great Hall void area")

    # 2. openings on walls, one room each side
    print("Openings (on a wall, one room on each side):")
    graph: Dict[Tuple[str, str], Set[Tuple[str, str]]] = {}
    n_open = 0
    for (fl, k, x0, z0, x1, z1, note) in OPEN:
        n_open += 1
        if not (x0 == x1 or z0 == z1) or (x0 == x1 and z0 == z1):
            fail("%s %s (%s,%s,%s,%s) is not a span along one wall line" % (fl, k, x0, z0, x1, z1))
            continue
        a, b, on_wall = opening_sides(fl, x0, z0, x1, z1)
        tag = "%s %s (%g,%g)-(%g,%g) %s" % (fl, k, x0, z0, x1, z1, note.split(":")[0].split(" (")[0])
        if not on_wall:
            fail("%s: not on a wall (sides %s / %s)" % (tag, sorted(a), sorted(b)))
            continue
        if len(a) != 1 or len(b) != 1:
            fail("%s: straddles a partition (sides %s / %s)" % (tag, sorted(a), sorted(b)))
            continue
        ra, rb = a.pop(), b.pop()
        if any(v.endswith("_VOID") for v in (ra, rb)):
            fail("%s: opens onto a void" % tag)
        if k == "W" and "OUT" not in (ra, rb):
            fail("%s: window not on the facade" % tag)
        if k != "W":
            graph.setdefault((fl, ra), set()).add((fl, rb))
            graph.setdefault((fl, rb), set()).add((fl, ra))
    print("  %d openings checked" % n_open)

    # 3. every room has a door; reachability from outside
    print("Doors and reachability:")
    for (fa, ra, fb, rb, _) in LINKS:
        na, nb = (fa, ra), ((fb, rb) if rb != "OUT" else ("G", "OUT"))
        graph.setdefault(na, set()).add(nb)
        graph.setdefault(nb, set()).add(na)
    for shaft, fls in (("SS", ("B", "G", "U")), ("LF", ("B", "G", "U"))):
        for f1, f2 in zip(fls, fls[1:]):
            graph.setdefault((f1, shaft), set()).add((f2, shaft))
            graph.setdefault((f2, shaft), set()).add((f1, shaft))
    graph.setdefault(("U", "SS"), set()).add(("R", "HH"))
    graph.setdefault(("R", "HH"), set()).add(("U", "SS"))
    for fl in FLOORS:   # all floors' OUT are the same outside
        if (fl, "OUT") in graph and fl != "G":
            for n in graph.pop((fl, "OUT")):
                graph.setdefault(("G", "OUT"), set()).add(n)
                graph[n] = {("G", "OUT") if m == (fl, "OUT") else m for m in graph[n]}
    seen = {("G", "OUT")}
    todo = [("G", "OUT")]
    while todo:
        for m in graph.get(todo.pop(), set()):
            if m not in seen:
                seen.add(m)
                todo.append(m)
    for fl in FLOORS:
        for rid in dict.fromkeys(r[0] for r in ROOMS[fl]):
            doors = [m for m in graph.get((fl, rid), set()) if m[0] == fl]
            if (fl, rid) in NO_DOOR_OK:
                print("  %s %s: no door, allowed (%s)" % (fl, rid, NO_DOOR_OK[(fl, rid)]))
                continue
            if not doors:
                fail("%s %s has no door or opening" % (fl, rid))
            elif (fl, rid) not in seen:
                fail("%s %s is not reachable from outside" % (fl, rid))
    print("  %d rooms reachable from outside (via doors, Stair SS, the art lift, the grand stair, ladders)"
          % len([n for n in seen if n[1] != "OUT"]))

    # 4. sizes vs the Room list, shafts aligned
    print("Room sizes vs the Room list:")
    nsz = 0
    for fl in FLOORS:
        for rid, _, (x0, z0, x1, z1) in ROOMS[fl]:
            if rid in SIZES and [r[0] for r in ROOMS[fl]].count(rid) == 1:
                nsz += 1
                if (x1 - x0, z1 - z0) != SIZES[rid]:
                    fail("%s %s is %g x %g, Room list says %g x %g" % ((fl, rid, x1 - x0, z1 - z0) + SIZES[rid]))
            elif rid not in SIZES and (fl, rid) not in NO_DOOR_OK:
                fail("%s %s missing from the Room list sizes" % (fl, rid))
    x4 = [r for rid, _, r in ROOMS["R"] if rid == "X4"]
    print("  %d rooms match; X4 (roof deck) is %g x %g + a %g x %g strip south of LM (Room list: 25 x 8)"
          % (nsz, x4[0][2] - x4[0][0], x4[0][3] - x4[0][1], x4[1][2] - x4[1][0], x4[1][3] - x4[1][1]))
    for rid, rect, fls in (("SS", SS, "BGU"), ("HH", SS, "R"), ("LF", LF, "BGU"), ("LM", LF, "R")):
        for fl in fls:
            if (rid, rect) not in [(r[0], r[2]) for r in ROOMS[fl]]:
                fail("%s %s is not at the shaft position %s" % (fl, rid, rect))
    print("  Stair SS / head house at %s and art lift / motor room at %s on every floor -> OK" % (SS, LF))

    # 5. stairs
    print("Stairs (vertical data table):")
    fh = [FLOOR_HEIGHTS[f] for f in FLOORS]
    if fh != sorted(fh) or 0.0 not in fh:
        fail("floor_heights must ascend and contain 0.0")
    runs = []
    for (name, h0, h1, fn, rn, rh, tr) in STAIRS:
        h = round(h1 - h0, 3)
        tot = round(fn * rn * rh, 3)
        run = round((rn - 1) * tr, 3)
        good = abs(tot - h) < 1e-6 and rn <= 16 and 0.15 <= rh <= 0.19 and tr >= 0.28
        print("  %-5s %5.1f -> %4.1f: %d x %d risers x %.3f = %.2f (storey %.2f), landing every %d <= 16, "
              "%d treads x %.2f = run %.2f -> %s" % (name, h0, h1, fn, rn, rh, tot, h, rn, rn - 1, tr, run,
                                                     "OK" if good else "BAD"))
        if not good:
            fail("stair %s %.1f -> %.1f" % (name, h0, h1))
        if name == "SS":
            runs.append(run)
            if abs(DOC_RUNS[(h0, h1)] - run) > 1e-6:
                fail("SS %.1f -> %.1f run %.2f, table says %.2f" % (h0, h1, run, DOC_RUNS[(h0, h1)]))
    for (h0, h1) in zip(fh, fh[1:]):
        if not any(s[0] == "SS" and s[1] == h0 and s[2] == h1 for s in STAIRS):
            fail("no Stair SS flight pair for %.1f -> %.1f" % (h0, h1))
    # Stair SS core fit: 3.0 x 8.0 centre lines, 0.3 m walls -> 2.7 x 7.7 clear.
    cw, cl = SS[2] - SS[0] - 0.3, SS[3] - SS[1] - 0.3
    across = 1.2 + 0.2 + 1.2
    door_z0 = [o[3] for o in OPEN if o[0] == "B" and o[6].startswith("SS")][0]
    landing = max(1.30, round(SS[3] - 0.15 - door_z0, 3))   # floor landing must take the whole door
    along = landing + max(runs) + 1.30
    print("  SS core fit: flights 1.2 + 0.2 well + 1.2 = %.2f <= %.2f clear -> %s"
          % (across, cw, "OK" if across <= cw + 1e-9 else "BAD"))
    print("  SS core fit along z: floor landing %.2f (doc min 1.30; deepened to take the door z %.1f-%.1f) + "
          "run %.2f + half landing 1.30 = %.2f <= %.2f clear -> %s (doc: 1.30 + 3.92 + 1.30 = 6.52)"
          % (landing, door_z0, door_z0 + 1.0, max(runs), along, cl, "OK" if along <= cl + 1e-9 else "BAD"))
    if across > cw + 1e-9 or along > cl + 1e-9:
        fail("Stair SS core fit")
    # Grand (imperial) stair geometry: central flight rises N from z 14.4 to the half landing (z 8.2-10.2,
    # +2.7), the return flights rise S back to z 14.4 and onto the balcony landings (z 14.4-16.4, +5.4).
    run_g = (15 - 1) * 0.30
    hl_soffit = 2.7 - 0.3   # 0.3 m landing slab
    gx0, gz0, gx1, gz1 = gh
    vx0, vz0, vx1, vz1 = void
    g_ok = (abs((14.4 - 10.2) - run_g) < 1e-6 and gx0 <= 15.0 and 29.0 <= gx1 and gz0 <= 8.2 and 16.4 <= gz1
            and vx0 <= 15.0 and 29.0 <= vx1 and vz0 <= 8.2 and 16.4 <= vz1 and hl_soffit >= 2.1)
    print("  grand stair: run 14 x 0.30 = %.2f = z 14.4 -> 10.2; landings x 15.0-29.0 inside GH %s and the U "
          "void %s; headroom under the half landing %.1f >= 2.1 (staff door) -> %s"
          % (run_g, gh, void, hl_soffit, "OK" if g_ok else "BAD"))
    if not g_ok:
        fail("grand stair geometry")
    print("  ladders: areaway -4.2 -> 0.0 = %.1f m; fire escape 0.0 -> 9.0 = %.1f m (table: 4.2, 9.0) -> OK"
          % (FLOOR_HEIGHTS["G"] - FLOOR_HEIGHTS["B"], FLOOR_HEIGHTS["R"] - FLOOR_HEIGHTS["G"]))
    print("RESULT:", "PASS" if ok else "FAIL")
    return ok


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    for f in FLOORS:
        print(FLOOR_TITLES[f])
        print(plan(f))
        print()
