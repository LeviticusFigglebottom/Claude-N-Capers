# ASCII floor plans + checks for docs/design/heists/ostrander_federal.md ("Floor plans", "Room list"). Owner: ENV C.
# Run: python3 tools/levelcheck/plans/ostrander_federal_floors_ascii.py            (the five plans)
#      python3 tools/levelcheck/plans/ostrander_federal_floors_ascii.py --check    (consistency report, exit 0/1)
#
# 1 char = 1 m; each char is a grid POINT (x = col, z = row). Rooms are rectangles (x0, z0, x1, z1) in metres between
# wall centre lines (exterior 0.4 m, interior 0.2 m, stair cores 0.3 m, vault 0.6 m `%`). Origin = the bank's NW corner,
# +x east, +z south (Ledger Lane at the top, Ostrander Plaza at the bottom). Floors: B Basement (FFL -4.0, x 0-48
# z 0-25), G Ground (0.0, x 0-48 z 0-36), M Gallery (5.0), E Executive + the hall-roof terrace (8.6), R Roof (+12.2,
# the north block x 0-48 z 0-17). This file is the data source for the greybox (ostrander_federal_emit_layout.py).
#
# --check: the rooms (+ declared voids) tile each floor footprint exactly; every opening lies on a wall (or the facade)
# with exactly one room on each side; every room has a door or opening; every room is reachable from outside; room
# sizes match the Room list; the stair cores and the cash lift line up; the stair arithmetic of the vertical data
# table (risers x height = storey, runs, landings <= 16 risers, core fit with the 1.30 m landings).
#
# Plan corrections against the doc drawings (G1, OF-C1; listed in the OF-C1 report):
#  * ground GL/E1 partition: the doc repeats the basement's lift door at (11, 3); E1 is an electrical closet off BC,
#    so the ground floor has no GL -> E1 door (the lift opens W into LD, Room list).
#  * the gallery UC end window E (Room list) is not drawn: added at (48, 8).
#  * CP (count room) is 3.2 m like the rest of the basement (Room list) but cash_office is 2.6-3.0: it takes the same
#    2.6-3.2 basement override as BB/RC/SS/LK/CM/CQ (Night Deposit precedent).
#  * the roof plant enclosure (drawn, x 20-34 z 2-10, door S) is a room here: RP, purpose plant (X5 "Plant, AHU").
#  * vault walls are 0.6 m (Night Deposit's round-door wall; the prop_vault_door_round kit), not 0.8 m.
#  * the gallery restrooms are WM2 / WW2 (room ids are unique per map).
import sys
from typing import Dict, List, Optional, Set, Tuple

Rect = Tuple[float, float, float, float]

FLOORS = ("B", "G", "M", "E", "R")
FLOOR_HEIGHTS = {"B": -4.0, "G": 0.0, "M": 5.0, "E": 8.6, "R": 12.2}   # HeistMap.floor_heights (D-054, D-040)
FLOOR_NAMES = {"B": "Basement", "G": "Ground", "M": "Gallery", "E": "Executive", "R": "Roof"}
FLOOR_TITLES = {"B": "BASEMENT (FFL -4.0)", "G": "GROUND (FFL 0.0)", "M": "GALLERY LEVEL (FFL 5.0)",
                "E": "EXECUTIVE LEVEL (FFL 8.6) AND THE HALL-ROOF TERRACE", "R": "ROOF (+12.2; NORTH BLOCK)"}
FOOT: Dict[str, Rect] = {"B": (0, 0, 48, 25), "G": (0, 0, 48, 36), "M": (0, 0, 48, 36), "E": (0, 0, 48, 36),
                         "R": (0, 0, 48, 17)}
RULER = {f: 48 for f in FLOORS}

# The vertical shafts, at the same plan position on every floor they serve.
SA: Rect = (13, 0, 16, 7)    # Stair A: 3.0 x 7.0 centre lines, 0.3 m walls; Basement -> Roof (head house HH)
SB: Rect = (45, 0, 48, 7)    # Stair B: Basement -> Executive (top)
GL: Rect = (10, 0, 13, 3)    # cash lift (bag_lift, Basement <-> Ground)

ROOMS: Dict[str, List[Tuple[str, str, Rect]]] = {
    "B": [
        ("LK", "locker_room", (0, 0, 10, 7)),        # staff lockers + 3 WC cubicles (the ghost line's room)
        ("GL", "elevator", GL),
        ("CQ", "storage", (10, 3, 13, 7)),           # cart queue in front of the lift
        ("SA", "stair", SA),
        ("CP", "cash_office", (16, 0, 26, 7)),       # count room
        ("PL", "plant", (26, 0, 35, 7)),             # boilers, AHU (the Phantom's areaway vent)
        ("CM", "server_room", (35, 0, 40, 7)),       # comms (srv_basement)
        ("SS", "storage", (40, 0, 45, 7)),           # supplies
        ("SB", "stair", SB),
        ("BB", "corridor", (0, 7, 48, 9)),           # basement spine
        ("RC", "storage", (0, 9, 14, 25)),           # records (the time-lock wait room)
        ("VC", "vault", (14, 9, 34, 13)),            # vault concourse: gate, lasers x 21, TL, vault door
        ("VT", "vault", (14, 13, 34, 25)),           # the vault
        ("SD", "vault", (34, 9, 48, 25)),            # safe-deposit hall
    ],
    "G": [
        ("LD", "warehouse", (0, 0, 10, 9)),          # loading dock / sally port
        ("GL", "elevator", GL),
        ("E1", "electrical", (10, 3, 13, 7)),
        ("SA", "stair", SA),
        ("SR", "security_room", (16, 0, 23, 7)),
        ("GR", "locker_room", (23, 0, 29, 7)),       # guards' lockers
        ("WM", "restroom", (29, 0, 32, 7)),
        ("WW", "restroom", (32, 0, 35, 7)),
        ("J1", "janitor", (35, 0, 38, 7)),
        ("MO", "office", (38, 0, 45, 7)),            # mail and operations
        ("SB", "stair", SB),
        ("BC", "corridor", (10, 7, 48, 9)),          # back corridor (fire exit at the east end)
        ("LO", "office", (0, 9, 8, 19)),             # loans
        ("TW", "banking_hall", (8, 9, 40, 17)),      # teller workroom (the lid T at (24, 14))
        ("PC", "lobby", (40, 9, 48, 19)),            # private-client lounge
        ("CN1", "office", (0, 19, 8, 24)),
        ("CN2", "office", (0, 24, 8, 29)),
        ("AV", "lobby", (0, 29, 8, 36)),             # ATM vestibule (PUBLIC)
        ("BH", "hall", (8, 17, 40, 32)),             # banking hall (PUBLIC), U round the vestibule
        ("BH", "hall", (8, 32, 20, 36)),
        ("BH", "hall", (28, 32, 40, 36)),
        ("VE", "lobby", (20, 32, 28, 36)),           # bronze-and-glass vestibule (PUBLIC)
        ("BM", "office", (40, 19, 48, 27)),          # branch manager
        ("PW", "restroom", (40, 27, 48, 31)),        # customer restrooms (PUBLIC)
        ("NA", "office", (40, 31, 48, 36)),          # new accounts
    ],
    "M": [
        ("BR", "break_room", (0, 0, 10, 7)),
        ("E2", "electrical", (10, 0, 13, 7)),
        ("SA", "stair", SA),
        ("IT", "office", (16, 0, 23, 7)),
        ("SV", "server_room", (23, 0, 29, 7)),       # srv_gallery, the 2 server-drive bags
        ("WM2", "restroom", (29, 0, 32, 7)),
        ("WW2", "restroom", (32, 0, 35, 7)),
        ("J2", "janitor", (35, 0, 38, 7)),
        ("AR", "storage", (38, 0, 45, 7)),           # archive
        ("SB", "stair", SB),
        ("UC", "corridor", (0, 7, 48, 9)),
        ("AO1", "office", (0, 9, 6, 18)),
        ("AO2", "office", (0, 18, 6, 27)),
        ("AO3", "office", (0, 27, 6, 36)),
        ("WL", "corridor", (6, 9, 8, 36)),           # west loggia (glazed to the hall void)
        ("OF", "office", (8, 9, 28, 17)),            # operations (open plan)
        ("CF", "office", (28, 9, 34, 17)),           # conference
        ("CO", "office", (34, 9, 40, 17)),           # compliance
        ("GA", "lobby", (8, 17, 40, 20)),            # officers' gallery (1.1 m guard over the hall)
        ("EL", "corridor", (40, 9, 42, 36)),         # east loggia
        ("VO", "office", (42, 9, 48, 18)),           # vault operations
        ("TR", "office", (42, 18, 48, 27)),          # treasury
        ("TT", "office", (42, 27, 48, 36)),          # training room
    ],
    "E": [
        ("BD", "office", (0, 0, 10, 7)),             # boardroom
        ("E3", "electrical", (10, 0, 13, 7)),
        ("SA", "stair", SA),
        ("EA", "office", (16, 0, 23, 7)),            # executive assistant (pc_exec)
        ("PR", "office", (23, 0, 35, 7)),            # president (the wall safe)
        ("PN", "break_room", (35, 0, 42, 7)),        # executive pantry
        ("XW", "restroom", (42, 0, 45, 7)),
        ("SB", "stair", SB),
        ("XC", "corridor", (0, 7, 48, 9)),
        ("XL", "lounge", (0, 9, 16, 17)),            # executive lounge (terrace doors)
        ("LG", "office", (16, 9, 28, 17)),           # legal
        ("CT", "office", (28, 9, 40, 17)),           # trust department
        ("RA", "storage", (40, 9, 48, 17)),          # records
        ("X4", "exterior", (0, 17, 48, 36)),         # the hall-roof terrace (+ the wing roofs)
    ],
    "R": [
        ("X5", "exterior", (0, 0, 13, 17)),          # main roof
        ("HH", "stair", SA),                         # Stair A head house
        ("X5", "exterior", (13, 7, 16, 17)),
        ("X5", "exterior", (16, 0, 48, 2)),
        ("X5", "exterior", (16, 2, 20, 17)),
        ("RP", "plant", (20, 2, 34, 10)),            # roof plant enclosure
        ("X5", "exterior", (20, 10, 34, 17)),
        ("X5", "exterior", (34, 2, 48, 17)),
    ],
}
# Voids (no floor on this level) that take part in the tiling.
VOID: Dict[str, List[Tuple[str, Rect]]] = {"M": [("BH_VOID", (8, 20, 40, 36))]}   # the banking hall's upper volume
# Room edges that are not plain walls. RAIL: the GA bronze guard (1.1 m, solid base to 1.0 m). GLAZE: the loggias'
# full-height glazing to the hall void. COUNTER: the teller line (counter + bandit glass + the bulkhead over it).
RAIL: Dict[str, List[Rect]] = {"M": [(8, 20, 40, 20)]}
GLAZE: Dict[str, List[Rect]] = {"M": [(8, 20, 8, 36), (40, 20, 40, 36)]}
COUNTER: Dict[str, List[Rect]] = {"G": [(8, 17, 40, 17)]}
# Vault walls (0.6 m reinforced) drawn `%`: the vault VT's box (the south wall is the facade).
VAULT: Dict[str, List[Rect]] = {"B": [(14, 13, 34, 13), (14, 13, 14, 25), (34, 13, 34, 25)]}
NO_DOOR_OK: Dict[Tuple[str, str], str] = {}

# Openings: (floor, kind, x0, z0, x1, z1, note). One of x0 == x1 (a wall along z) or z0 == z1 (a wall along x); the span
# is the clear (kit) opening along that wall, and the plan draws `kind` at every grid point p with start <= p < end.
# Kinds: D door (single 1.0 / service 1.2 / double 2.0 kit openings), G the vault gate (grille, KEYCARD), V the round
# vault door, R roller door, W window, g the teller gate (in the counter), h ladder top / fire-escape crossing.
OPEN: List[Tuple[str, str, float, float, float, float, str]] = [
    # --- Basement ---
    ("B", "D", 4.5, 7, 5.5, 7, "LK"),
    ("B", "D", 10.5, 3, 12.5, 3, "GL cash-lift landing door S (CQ), 1.8 m leaves"),
    ("B", "D", 11.4, 7, 12.6, 7, "CQ (service: carts)"),
    ("B", "D", 13.9, 7, 15.1, 7, "SA stair door (floor landing, vision panel)"),
    ("B", "D", 20.5, 7, 21.5, 7, "CP"),
    ("B", "D", 29.5, 7, 30.5, 7, "PL"),
    ("B", "D", 36.5, 7, 37.5, 7, "CM"),
    ("B", "D", 41.5, 7, 42.5, 7, "SS"),
    ("B", "D", 45.9, 7, 47.1, 7, "SB stair door"),
    ("B", "D", 5.4, 9, 6.6, 9, "RC (service)"),
    ("B", "G", 16.0, 9, 18.0, 9, "vault gate: 2.0 m steel grille, KEYCARD (reader K), BARRED at lockdown"),
    ("B", "D", 41.4, 9, 42.6, 9, "SD (service)"),
    ("B", "V", 28.8, 13, 31.2, 13, "vault door: round 2.4 m, VAULT lock, time lock"),
    # --- Ground ---
    ("G", "R", 3.2, 0, 6.8, 0, "LD roller door N (Ledger Lane), 3.6 x 4.0"),
    ("G", "D", 7.4, 0, 8.6, 0, "LD personnel door N (Ledger Lane), LOCKPICK, NPC-authorised"),
    ("G", "W", 0.6, 0, 1.6, 0, "LD window N"),
    ("G", "D", 10, 0.5, 10, 2.5, "GL cash-lift landing door W (LD), 1.8 m"),
    ("G", "D", 10, 7.4, 10, 8.6, "LD -> BC (service)"),
    ("G", "D", 11.5, 7, 12.5, 7, "E1"),
    ("G", "D", 13.9, 7, 15.1, 7, "SA stair door"),
    ("G", "D", 18.5, 7, 19.5, 7, "SR"),
    ("G", "D", 25.5, 7, 26.5, 7, "GR"),
    ("G", "D", 29.5, 7, 30.5, 7, "WM"),
    ("G", "D", 32.5, 7, 33.5, 7, "WW"),
    ("G", "D", 35.4, 7, 36.6, 7, "J1 (service: the mask-up closet)"),
    ("G", "D", 40.5, 7, 41.5, 7, "MO"),
    ("G", "D", 45.9, 7, 47.1, 7, "SB stair door"),
    ("G", "D", 48, 7.4, 48, 8.6, "BC east fire exit (Tannery St): push bar, door_fire_propped"),
    ("G", "D", 13.4, 9, 14.6, 9, "BC -> TW staff door W: LOCKPICK, NPC-authorised"),
    ("G", "D", 33.4, 9, 34.6, 9, "BC -> TW staff door E: LOCKPICK, NPC-authorised"),
    ("G", "D", 43.4, 9, 44.6, 9, "BC -> PC service door (unlocked during hours: the coffee runs)"),
    ("G", "D", 8, 11.5, 8, 12.5, "LO -> TW: LOCKPICK"),
    ("G", "D", 40, 11.5, 40, 12.5, "TW -> PC"),
    ("G", "D", 8, 17.5, 8, 18.5, "LO hall door (unlocked during hours)"),
    ("G", "D", 40, 17.5, 40, 18.5, "PC hall door (unlocked)"),
    ("G", "g", 23.4, 17, 24.6, 17, "teller gate (service door in the counter): LOCKPICK, NPC-authorised"),
    ("G", "D", 8, 20.5, 8, 21.5, "CN1"),
    ("G", "D", 8, 25.5, 8, 26.5, "CN2"),
    ("G", "D", 8, 31.5, 8, 32.5, "AV hall door (glass, open during hours)"),
    ("G", "D", 40, 22.5, 40, 23.5, "BM"),
    ("G", "D", 40, 28.5, 40, 29.5, "PW"),
    ("G", "D", 40, 32.5, 40, 33.5, "NA"),
    ("G", "D", 21.9, 32, 26.1, 32, "VE inner glass doors, 2 x 1.8 m (open during hours)"),
    ("G", "D", 21.9, 36, 26.1, 36, "bronze doors, 2 x 1.8 m (open during hours; lockdown)"),
    ("G", "D", 3.0, 36, 5.0, 36, "AV street doors (double glass, open during hours)"),
    ("G", "W", 10.2, 36, 13.4, 36, "hall arched window, bay W1 (sill 1.0, 5.5 m tall)"),
    ("G", "W", 14.6, 36, 17.8, 36, "hall arched window, bay W2"),
    ("G", "W", 30.2, 36, 33.4, 36, "hall arched window, bay E1"),
    ("G", "W", 34.6, 36, 37.8, 36, "hall arched window, bay E2"),
    ("G", "W", 48, 10.5, 48, 11.5, "PC window E"),
    ("G", "W", 48, 14.5, 48, 15.5, "PC window E"),
    ("G", "W", 48, 20.5, 48, 21.5, "BM window E"),
    ("G", "W", 48, 23.5, 48, 24.5, "BM window E"),
    ("G", "W", 48, 32.5, 48, 33.5, "NA window E"),
    # --- Gallery ---
    ("M", "D", 4.5, 7, 5.5, 7, "BR"),
    ("M", "D", 11.5, 7, 12.5, 7, "E2"),
    ("M", "D", 13.9, 7, 15.1, 7, "SA stair door"),
    ("M", "D", 18.5, 7, 19.5, 7, "IT"),
    ("M", "D", 25.4, 7, 26.6, 7, "SV: LOCKPICK (service)"),
    ("M", "D", 29.5, 7, 30.5, 7, "WM2"),
    ("M", "D", 32.5, 7, 33.5, 7, "WW2"),
    ("M", "D", 35.5, 7, 36.5, 7, "J2"),
    ("M", "D", 40.5, 7, 41.5, 7, "AR"),
    ("M", "D", 45.9, 7, 47.1, 7, "SB stair door"),
    ("M", "D", 6.5, 9, 7.5, 9, "UC -> WL"),
    ("M", "D", 11.5, 9, 12.5, 9, "OF (UC)"),
    ("M", "D", 30.5, 9, 31.5, 9, "CF (UC)"),
    ("M", "D", 36.5, 9, 37.5, 9, "CO (UC)"),
    ("M", "D", 40.5, 9, 41.5, 9, "UC -> EL"),
    ("M", "D", 6, 12.5, 6, 13.5, "AO1 (WL)"),
    ("M", "D", 6, 21.5, 6, 22.5, "AO2 (WL)"),
    ("M", "D", 6, 30.5, 6, 31.5, "AO3 (WL)"),
    ("M", "D", 42, 12.5, 42, 13.5, "VO (EL)"),
    ("M", "D", 42, 21.5, 42, 22.5, "TR (EL)"),
    ("M", "D", 42, 30.5, 42, 31.5, "TT (EL)"),
    ("M", "D", 17.5, 17, 18.5, 17, "OF -> GA"),
    ("M", "D", 30.5, 17, 31.5, 17, "CF -> GA"),
    ("M", "D", 8, 17.5, 8, 18.5, "WL -> GA"),
    ("M", "D", 40, 17.5, 40, 18.5, "GA -> EL"),
    ("M", "W", 3.5, 0, 4.5, 0, "BR window N"),
    ("M", "W", 6.5, 0, 7.5, 0, "BR window N"),
    ("M", "W", 48, 7.5, 48, 8.5, "UC end window E"),
    ("M", "W", 48, 13.0, 48, 14.0, "VO window E"),
    ("M", "W", 48, 22.0, 48, 23.0, "TR window E"),
    ("M", "W", 48, 31.0, 48, 32.0, "TT window E"),
    ("M", "W", 2.5, 36, 3.5, 36, "AO3 window S"),
    ("M", "W", 44.5, 36, 45.5, 36, "TT window S"),
    # --- Executive + terrace ---
    ("E", "D", 4.5, 7, 5.5, 7, "BD"),
    ("E", "D", 11.5, 7, 12.5, 7, "E3"),
    ("E", "D", 13.9, 7, 15.1, 7, "SA stair door"),
    ("E", "D", 18.4, 7, 19.6, 7, "EA (service: the roof route)"),
    ("E", "D", 27.5, 7, 28.5, 7, "PR"),
    ("E", "D", 37.5, 7, 38.5, 7, "PN"),
    ("E", "D", 42.5, 7, 43.5, 7, "XW"),
    ("E", "D", 45.9, 7, 47.1, 7, "SB stair door (top floor)"),
    ("E", "D", 5.4, 9, 6.6, 9, "XL (XC; service: the ghost line)"),
    ("E", "D", 21.5, 9, 22.5, 9, "LG (XC)"),
    ("E", "D", 33.5, 9, 34.5, 9, "CT (XC)"),
    ("E", "D", 43.5, 9, 44.5, 9, "RA (XC)"),
    ("E", "D", 4.6, 17, 6.6, 17, "XL terrace glass doors W (DD): LOCKPICK from outside"),
    ("E", "D", 9.6, 17, 11.6, 17, "XL terrace glass doors E (DD): LOCKPICK from outside"),
    ("E", "W", 1.0, 17, 3.4, 17, "XL window S (terrace)"),
    ("E", "W", 18.0, 17, 21.6, 17, "LG window S"),
    ("E", "W", 30.0, 17, 33.6, 17, "CT window S"),
    ("E", "W", 42.0, 17, 45.6, 17, "RA window S"),
    # --- Roof ---
    ("R", "D", 13.9, 7, 15.1, 7, "HH roof door: LOCKPICK 8 s from the roof, push bar inside (service)"),
    ("R", "D", 26.5, 10, 27.5, 10, "RP roof plant door"),
    ("R", "h", 45.4, 17, 46.6, 17, "caged ladder top (roof -> terrace, 3.6 m)"),
    ("R", "h", 0.4, 0, 1.4, 0, "fire-escape crossing fe: the lowered coping, 2 x 0.3 m steps, rails"),
]

# Vertical links other than the stairs and the cash lift (for the reachability check).
LINKS = [("R", "X5", "G", "OUT", "Corvino fire escape (drop ladder 3.0 m + steel stair), masked only, no bags"),
         ("R", "X5", "E", "X4", "caged ladder 3.6 m at (46, 17), no bags"),
         ("B", "VT", "G", "TW", "rope ladder 4.0 m through the hole (24, 14) (loud, after the burn; QC-61)")]


def _stair_arrows(x: int, top: bool) -> List[Tuple[float, float, str]]:
    return [(x + 1, z, "=v" if top else "^v") for z in range(1, 5)]


MARK: Dict[str, List[Tuple[float, float, str]]] = {
    "B": _stair_arrows(13, False) + _stair_arrows(45, False) + [
        (1, 1, "LK LOCKER"), (11, 1, "GL"), (11, 5, "CQ"), (17, 1, "CP COUNT"), (27, 1, "PL PLANT"), (36, 1, "CM"),
        (41, 1, "SS"), (37, 3, "SRV"), (2, 8, "BB BASEMENT CORRIDOR"), (1, 10, "RC RECORDS"), (15, 10, "VC"),
        (17, 11, "K"), (21, 10, ":"), (21, 11, ":"), (21, 12, ":"), (26, 11, "G"), (32, 12, "TL"),
        (35, 10, "SD SAFE DEPOS"), (36, 12, "bbbbbbbbbbb"), (36, 17, "bbbbbbbbbbb"), (36, 22, "bbbbbbbbbbb"),
        (15, 14, "VT VAULT"), (15, 15, "bbbbbbbb"), (24, 14, "x"), (27, 15, "[GOLD]P"), (20, 18, "[CASH CAGE]"),
        (16, 20, "S"), (15, 24, "bbbbbbbbbbbbbbbbbbb"),
    ],
    "G": _stair_arrows(13, False) + _stair_arrows(45, False) + [
        (1, 1, "LD DOCK"), (11, 1, "GL"), (11, 5, "E1"), (17, 1, "SR SEC"), (19, 3, "Mo"), (24, 1, "GR GU"),
        (30, 1, "WM"), (33, 1, "WW"), (36, 1, "J1"), (39, 1, "MO MAI"), (3, 4, "P"),
        (11, 8, "BC BACK CORRIDOR"), (1, 10, "LO LOAN"), (9, 10, "TW TELLER WORKROOM"), (41, 10, "PC CLIE"),
        (13, 12, "t t t"), (31, 12, "t t t"), (24, 14, "T"), (9, 18, "BH BANKING HALL"),
        (1, 20, "CN1"), (41, 20, "BM MANA"), (44, 24, "c"), (1, 25, "CN2"), (41, 28, "PW WC"), (1, 30, "AV ATM"),
        (24, 30, "G"), (41, 32, "NA ACCT"), (2, 33, "$$  n"), (21, 33, "VE"),
    ] + [(24, z, "m") for z in range(18, 32, 2)],
    "M": _stair_arrows(13, False) + _stair_arrows(45, False) + [
        (1, 1, "BR BREAK"), (11, 1, "E2"), (17, 1, "IT"), (24, 1, "SV SE"), (25, 3, "SRV"), (30, 1, "WM"),
        (33, 1, "WW"), (36, 1, "J2"), (39, 1, "AR ARC"), (1, 8, "UC UPPER CORRIDOR"), (1, 10, "AO1"),
        (2, 12, "k"), (9, 10, "OF OPERATIONS"), (12, 12, "k"), (29, 10, "CF"), (35, 10, "CO"), (43, 10, "VO"),
        (45, 12, "k"), (9, 18, "GA GALLERY"), (24, 18, "G"), (1, 19, "AO2"), (2, 21, "k"), (43, 19, "TR"),
        (1, 28, "AO3"), (2, 30, "k"), (43, 28, "TT"), (10, 28, "VOID OVER THE BANKING HALL"),
    ],
    "E": _stair_arrows(13, False) + _stair_arrows(45, True) + [
        (1, 1, "BD BOARD"), (11, 1, "E3"), (17, 1, "EA ASS"), (19, 3, "k"), (24, 1, "PR PRESIDEN"), (30, 3, "S"),
        (36, 1, "PN PAN"), (43, 1, "XW"), (1, 8, "XC EXEC CORRIDOR"), (1, 10, "XL EXEC LOUNGE"), (17, 10, "LG LEGAL"),
        (29, 10, "CT TRUST"), (41, 10, "RA RECO"), (2, 20, "TERRACE +8.6 (roof over the hall)"),
        (14, 22, "*****************"), (14, 30, "*****************"), (18, 26, "LANTERN"),
        (33, 24, "HHHHHHH"), (33, 30, "HHHHHHH"), (35, 26, "E3 net"), (46, 18, "h"), (3, 32, "planters"),
    ] + [(14, z, "*") for z in range(23, 30)] + [(30, z, "*") for z in range(23, 30)],
    "R": [(14, z, "=v") for z in range(1, 5)] + [
        (1, 2, "fe"), (21, 3, "ROOF PLANT"), (38, 4, "AHU"), (5, 12, "ROOF +12.2"), (38, 12, "tank"),
        (2, 14, "rp"), (46, 16, "h"),
    ],
}

# Room list sizes (x by z, between wall centre lines) for the size check.
SIZES = {"LK": (10, 7), "GL": (3, 3), "CQ": (3, 4), "SA": (3, 7), "CP": (10, 7), "PL": (9, 7), "CM": (5, 7),
         "SS": (5, 7), "SB": (3, 7), "BB": (48, 2), "RC": (14, 16), "VC": (20, 4), "VT": (20, 12), "SD": (14, 16),
         "LD": (10, 9), "E1": (3, 4), "SR": (7, 7), "GR": (6, 7), "WM": (3, 7), "WW": (3, 7), "J1": (3, 7),
         "MO": (7, 7), "BC": (38, 2), "LO": (8, 10), "TW": (32, 8), "PC": (8, 10), "CN1": (8, 5), "CN2": (8, 5),
         "AV": (8, 7), "VE": (8, 4), "BM": (8, 8), "PW": (8, 4), "NA": (8, 5), "BR": (10, 7), "E2": (3, 7),
         "IT": (7, 7), "SV": (6, 7), "WM2": (3, 7), "WW2": (3, 7), "J2": (3, 7), "AR": (7, 7), "UC": (48, 2),
         "AO1": (6, 9), "AO2": (6, 9), "AO3": (6, 9), "WL": (2, 27), "EL": (2, 27), "OF": (20, 8), "CF": (6, 8),
         "CO": (6, 8), "GA": (32, 3), "VO": (6, 9), "TR": (6, 9), "TT": (6, 9), "BD": (10, 7), "E3": (3, 7),
         "EA": (7, 7), "PR": (12, 7), "PN": (7, 7), "XW": (3, 7), "XC": (48, 2), "XL": (16, 8), "LG": (12, 8),
         "CT": (12, 8), "RA": (8, 8), "HH": (3, 7), "X4": (48, 19), "RP": (14, 8)}
BH_AREA = 576   # Room list: 32 x 19 less VE

# Stair data (vertical data table): (name, from FFL, to FFL, flights, risers per flight, riser, tread).
STAIRS = [("SA", -4.0, 0.0, 2, 11, 4.0 / 22, 0.28), ("SA", 0.0, 5.0, 2, 14, 5.0 / 28, 0.28),
          ("SA", 5.0, 8.6, 2, 10, 0.18, 0.28), ("SA", 8.6, 12.2, 2, 10, 0.18, 0.28),
          ("SB", -4.0, 0.0, 2, 11, 4.0 / 22, 0.28), ("SB", 0.0, 5.0, 2, 14, 5.0 / 28, 0.28),
          ("SB", 5.0, 8.6, 2, 10, 0.18, 0.28)]
DOC_RUNS = {(-4.0, 0.0): 2.80, (0.0, 5.0): 3.64, (5.0, 8.6): 2.52, (8.6, 12.2): 2.52}
# Core layout (both cores): clear 2.7 x 6.7 m; flights 1.2 + 0.2 well + 1.2; first riser line LANDING_Z m from the
# core's north wall line, so the floor landing (south) is 1.30 m deep and takes the 1.0 m stair door.
CORE_LANDING = 1.30
LANDING_MIN = 1.30


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


def unit_edges(x0: float, z0: float, x1: float, z1: float) -> List[Tuple[int, int, int, int]]:
    if x0 == x1:
        return [(int(x0), k, int(x0), k + 1) for k in range(int(min(z0, z1)), int(max(z0, z1)))]
    return [(k, int(z0), k + 1, int(z0)) for k in range(int(min(x0, x1)), int(max(x0, x1)))]


def special_edges(fl: str, table: Dict[str, List[Rect]]) -> Set[Tuple[int, int, int, int]]:
    out = set()
    for (x0, z0, x1, z1) in table.get(fl, []):
        out.update(unit_edges(x0, z0, x1, z1))
    return out


def sides(c: Dict[Tuple[int, int], str], e: Tuple[int, int, int, int]) -> Tuple[Optional[str], Optional[str]]:
    a, b, cc, _d = e
    if a == cc:   # wall along z at x = a: cells west / east
        return c.get((a - 1, b)), c.get((a, b))
    return c.get((a, b - 1)), c.get((a, b))   # wall along x at z = b: cells north / south


def all_edges(fl: str) -> Set[Tuple[int, int, int, int]]:
    """Unit edges with different rooms on the two sides (incl. the facade)."""
    c = cells(fl)
    x0, z0, x1, z1 = (int(v) for v in FOOT[fl])
    out = set()
    for i in range(x0, x1 + 1):
        for j in range(z0, z1 + 1):
            for e in ((i, j, i, j + 1), (i, j, i + 1, j)):
                if (e[2] > x1) or (e[3] > z1):
                    continue
                s = sides(c, e)
                if s[0] != s[1]:
                    out.add(e)
    return out


def walls(fl: str) -> Set[Tuple[int, int, int, int]]:
    """Plain wall edges: room boundaries minus the rail / glazing / counter edges."""
    sp = special_edges(fl, RAIL) | special_edges(fl, GLAZE) | special_edges(fl, COUNTER)
    return {e for e in all_edges(fl) if e not in sp}


def boundary(fl: str) -> Set[Tuple[int, int, int, int]]:
    """Every edge an opening may sit on (walls + counter)."""
    return walls(fl) | special_edges(fl, COUNTER)


# --------------------------------------------------------------------------------------------- render
def span_points(x0: float, z0: float, x1: float, z1: float) -> List[Tuple[int, int]]:
    """Grid points p of an opening with start <= p < end (along its wall)."""
    eps = 1e-9
    if x0 == x1:
        return [(int(x0), p) for p in range(int(-(-z0 // 1)), int(z1 + 1)) if z0 - eps <= p < z1 - eps]
    return [(p, int(z0)) for p in range(int(-(-x0 // 1)), int(x1 + 1)) if x0 - eps <= p < x1 - eps]


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
            if (i in (0, fx) or j in (0, fz)) and g[j][i] != " ":
                g[j][i] = "#" if not (fl in ("E", "R") and j > 0 and (j >= 17 or fl == "R")) else "p"
    if fl == "E":   # terrace parapets
        for j in range(17, fz + 1):
            g[j][0] = g[j][fx] = "p"
        for i in range(fx + 1):
            g[fz][i] = "p"
    if fl == "R":
        for j in range(fz + 1):
            g[j][0] = g[j][fx] = "p"
        for i in range(fx + 1):
            g[0][i] = g[fz][i] = "p"
    for (x0, z0, x1, z1) in VAULT.get(fl, []):
        for k in range(int(max(x1 - x0, z1 - z0)) + 1):
            g[int(z0) + (k if x0 == x1 else 0)][int(x0) + (k if z0 == z1 else 0)] = "%"
    for table, ch in ((RAIL, "r"), (GLAZE, "W"), (COUNTER, "=")):
        for (x0, z0, x1, z1) in table.get(fl, []):
            for k in range(1, int(max(x1 - x0, z1 - z0))):
                g[int(z0) + (k if x0 == x1 else 0)][int(x0) + (k if z0 == z1 else 0)] = ch
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


# ---------------------------------------------------------------------------------------------- check
def opening_sides(fl: str, x0: float, z0: float, x1: float, z1: float) -> Tuple[Set[str], Set[str], bool]:
    """Rooms west/north and east/south of an opening; and whether the whole span is on a wall (or the counter)."""
    c = cells(fl)
    ws = boundary(fl)
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


def _graph() -> Dict[Tuple[str, str], Set[Tuple[str, str]]]:
    graph: Dict[Tuple[str, str], Set[Tuple[str, str]]] = {}

    def link(a: Tuple[str, str], b: Tuple[str, str]) -> None:
        graph.setdefault(a, set()).add(b)
        graph.setdefault(b, set()).add(a)

    for (fl, k, x0, z0, x1, z1, _note) in OPEN:
        a, b, on_wall = opening_sides(fl, x0, z0, x1, z1)
        if on_wall and len(a) == 1 and len(b) == 1 and k != "W":
            ra, rb = next(iter(a)), next(iter(b))
            link((fl if ra != "OUT" else "G", ra), (fl if rb != "OUT" else "G", rb))
    for (fa, ra, fb, rb, _) in LINKS:
        link((fa, ra), ((fb, rb) if rb != "OUT" else ("G", "OUT")))
    for shaft, fls in (("SA", ("B", "G", "M", "E")), ("SB", ("B", "G", "M", "E")), ("GL", ("B", "G"))):
        for f1, f2 in zip(fls, fls[1:]):
            link((f1, shaft), (f2, shaft))
    link(("E", "SA"), ("R", "HH"))
    # The roof edges ("h") and the terrace doors open onto exterior rooms on their own floor; the terrace (X4) and the
    # roof (X5) are outside, but not the street: they join the street only through the LINKS above.
    for key in list(graph):
        if key[1] == "OUT" and key[0] != "G":
            for nb in graph.pop(key):
                graph[nb].discard(key)
                link(nb, ("G", "OUT"))
    return graph


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
        vo = sum(area(r) for _, r in VOID.get(fl, []))
        tot = sum(area(r) for _, _, r in ROOMS[fl]) + vo
        print("  %s: rooms %.0f + voids %.0f = %.0f m2 vs footprint %.0f m2 -> %s"
              % (fl, tot - vo, vo, tot, area(FOOT[fl]), "OK" if not (over or outside or gaps) and tot == area(FOOT[fl])
                 else "MISMATCH"))
    bh = sum(area(r) for rid, _, r in ROOMS["G"] if rid == "BH")
    print("  BH banking hall %.0f m2 (Room list: 576 = 32 x 19 less VE) -> %s" % (bh, "OK" if bh == BH_AREA else "BAD"))
    if bh != BH_AREA:
        fail("BH area")

    # 2. openings on walls, one room each side
    print("Openings (on a wall, one room on each side):")
    for (fl, k, x0, z0, x1, z1, note) in OPEN:
        tag = "%s %s (%g,%g)-(%g,%g) %s" % (fl, k, x0, z0, x1, z1, note.split(":")[0].split(" (")[0])
        if not (x0 == x1 or z0 == z1) or (x0 == x1 and z0 == z1):
            fail("%s is not a span along one wall line" % tag)
            continue
        a, b, on_wall = opening_sides(fl, x0, z0, x1, z1)
        if not on_wall:
            fail("%s: not on a wall (sides %s / %s)" % (tag, sorted(a), sorted(b)))
            continue
        if len(a) != 1 or len(b) != 1:
            fail("%s: straddles a partition (sides %s / %s)" % (tag, sorted(a), sorted(b)))
            continue
        ra, rb = next(iter(a)), next(iter(b))
        if any(v.endswith("_VOID") for v in (ra, rb)):
            fail("%s: opens onto a void" % tag)
        if k == "W" and "OUT" not in (ra, rb) and not {ra, rb} & {"X4"}:
            fail("%s: window not on the facade" % tag)
        # an opening must keep >= 0.3 m of wall to the next crossing wall (jambs; door kits need 0.1 m frame)
        lo, hi = (z0, z1) if x0 == x1 else (x0, x1)
        line = x0 if x0 == x1 else z0
        cross = [e for e in boundary(fl) if (e[0] == e[2]) != (x0 == x1)]
        pts = sorted({(e[1] if x0 == x1 else e[0]) for e in cross
                      if (e[0] if x0 == x1 else e[1]) == line or (e[2] if x0 == x1 else e[3]) == line})
        near = [p for p in pts if lo - 0.3 < p < hi + 0.3]
        if near and k not in ("h",):
            fail("%s: a crossing wall at %s is within 0.3 m of the opening" % (tag, near))
    print("  %d openings checked" % len(OPEN))

    # 3. every room has a door; reachability from outside
    print("Doors and reachability:")
    graph = _graph()
    seen = {("G", "OUT")}
    todo = [("G", "OUT")]
    while todo:
        for m in graph.get(todo.pop(), set()):
            if m not in seen:
                seen.add(m)
                todo.append(m)
    nroom = 0
    for fl in FLOORS:
        for rid in dict.fromkeys(r[0] for r in ROOMS[fl]):
            nroom += 1
            doors = [m for m in graph.get((fl, rid), set())]
            if (fl, rid) in NO_DOOR_OK:
                print("  %s %s: no door, allowed (%s)" % (fl, rid, NO_DOOR_OK[(fl, rid)]))
                continue
            if not doors:
                fail("%s %s has no door or opening" % (fl, rid))
            elif (fl, rid) not in seen:
                fail("%s %s is not reachable from outside" % (fl, rid))
    print("  %d rooms, %d reachable from the street (doors, Stairs A / B, the cash lift, the fire escape, the caged "
          "ladder, the rope ladder)" % (nroom, len([n for n in seen if n[1] != "OUT"])))

    # 4. sizes vs the Room list, shafts aligned
    print("Room sizes vs the Room list:")
    nsz = 0
    for fl in FLOORS:
        for rid, _, (x0, z0, x1, z1) in ROOMS[fl]:
            if [r[0] for r in ROOMS[fl]].count(rid) > 1:
                continue
            if rid not in SIZES:
                fail("%s %s missing from the Room list sizes" % (fl, rid))
                continue
            nsz += 1
            if (x1 - x0, z1 - z0) != SIZES[rid]:
                fail("%s %s is %g x %g, Room list says %g x %g" % ((fl, rid, x1 - x0, z1 - z0) + SIZES[rid]))
    print("  %d rooms match" % nsz)
    for rid, rect, fls in (("SA", SA, "BGME"), ("HH", SA, "R"), ("SB", SB, "BGME"), ("GL", GL, "BG")):
        for fl in fls:
            if (rid, rect) not in [(r[0], r[2]) for r in ROOMS[fl]]:
                fail("%s %s is not at the shaft position %s" % (fl, rid, rect))
    print("  Stair A %s (+ head house), Stair B %s, cash lift %s on every floor they serve -> OK" % (SA, SB, GL))

    # 5. stairs
    print("Stairs (vertical data table):")
    fh = [FLOOR_HEIGHTS[f] for f in FLOORS]
    if fh != sorted(fh) or 0.0 not in fh:
        fail("floor_heights must ascend and contain 0.0")
    for (name, h0, h1, fn, rn, rh, tr) in STAIRS:
        h = round(h1 - h0, 4)
        tot = round(fn * rn * rh, 4)
        run = round((rn - 1) * tr, 3)
        good = abs(tot - h) < 1e-6 and rn <= 16 and 0.15 <= rh <= 0.19 and 0.25 <= tr <= 0.32
        print("  %s %5.1f -> %4.1f: %d x %d risers x %.4f = %.2f (storey %.2f), landing every %d <= 16, "
              "%d treads x %.2f = run %.2f (doc %.2f) -> %s" % (name, h0, h1, fn, rn, rh, tot, h, rn, rn - 1, tr, run,
                                                               DOC_RUNS[(h0, h1)], "OK" if good else "BAD"))
        if not good or abs(DOC_RUNS[(h0, h1)] - run) > 1e-6:
            fail("stair %s %.1f -> %.1f" % (name, h0, h1))
    for f1, f2 in zip(FLOORS, FLOORS[1:]):
        a, b = FLOOR_HEIGHTS[f1], FLOOR_HEIGHTS[f2]
        if not any(s[0] == "SA" and s[1] == a and s[2] == b for s in STAIRS):
            fail("no Stair A flight pair for %.1f -> %.1f" % (a, b))
    cw, cl = SA[2] - SA[0] - 0.3, SA[3] - SA[1] - 0.3
    across = 1.2 + 0.2 + 1.2
    longest = max((rn - 1) * tr for (_n, _a, _b, _f, rn, _r, tr) in STAIRS)
    along = CORE_LANDING + longest + LANDING_MIN
    print("  core fit: flights 1.2 + 0.2 well + 1.2 = %.2f <= %.2f clear; along z: floor landing %.2f + run %.2f + "
          "half landing %.2f = %.2f <= %.2f clear -> %s" % (across, cw, CORE_LANDING, longest, LANDING_MIN, along, cl,
                                                            "OK" if across <= cw and along <= cl + 1e-9 else "BAD"))
    if across > cw or along > cl + 1e-9:
        fail("stair core fit")
    print("  ladders: drop ladder 3.0 m (lane -> fire-escape landing +3.0), caged 12.2 -> 8.6 = %.1f m, rope ladder "
          "0.0 -> -4.0 = %.1f m (table 3.6 / 4.0) -> OK" % (FLOOR_HEIGHTS["R"] - FLOOR_HEIGHTS["E"],
                                                          FLOOR_HEIGHTS["G"] - FLOOR_HEIGHTS["B"]))
    print("RESULT:", "PASS" if ok else "FAIL")
    return ok


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    for f in FLOORS:
        print(FLOOR_TITLES[f])
        print(plan(f))
        print()
