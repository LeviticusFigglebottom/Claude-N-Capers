# The four convoy layouts (route x clean / crash) + checks for docs/design/heists/rolling_thunder.md ("Convoy", "Truck
# targets", "Loot path"). Owner: ENV C (RT-C1, paper stage: D-148.2 / D-149.10; `--check` only, nothing under game/).
# Run: python3 tools/levelcheck/plans/rolling_thunder_convoy.py            (the layouts as a table)
#      python3 tools/levelcheck/plans/rolling_thunder_convoy.py --check    (consistency report, exit 0 / 1)
#
# Site coordinates as rolling_thunder_site_ascii.py. Each vehicle is a box: centre (x, z), length along its heading,
# width, yaw (degrees off the arm's axis). Clean queues are straight; crash layouts are skewed (doc: within 1.1 m of
# the lane line, yawed 10-25 deg). D-149.1: each layout gets its own pre-baked nav region, so a layout only has to be
# self-consistent here; D-149.8: <= 8 movers drive in, then all are static.
#
# --check: queue spacing (3 m gaps) and lengths; the stop lines; the queue ends vs the doc; the north queue under the
# Skyway and clear of the piers; the east queue inside its lanes and the trench, its ramp heights; crash skews inside
# the carriageway with >= 1.0 m to the walls; a >= 1.0 m clear rear step behind every truck (the saw, the C4 and, on
# the bullion truck, the ground-level thermite point: D-149.2); the mover count; the loot-path distances are not shorter
# than the straight-line chain they describe.
import math
import os
import sys
from typing import Dict, List, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rolling_thunder_site_ascii as S  # noqa: E402
from rolling_thunder_checklib import Report, path_len  # noqa: E402

Pt = Tuple[float, float]
LEN = {"car": 5.0, "cash": 7.5, "bullion": 9.0}
WIDTH = {"car": 2.0, "cash": 2.5, "bullion": 2.5}      # ◇ not in the doc (typical vans / cars)
TRUCK_HEIGHT = 3.6                                      # ◇ (RT plan §7.9): must pass the 4.4 m height bar
GAP = 3.0
STOP_LINE = {"north": -14.0, "east": 14.0}
MAX_MOVERS = 8                                          # D-149.8
MOVERS = ["lead car", "T1", "T2", "T3", "rear car", "mixer", "marshal's scout car"]
LANE = {"north": -6.0, "east": -4.0}                    # x of the west lanes / z of the north lanes

# (name, kind, a0, a1 along the arm, lateral offset, yaw). Along = z for north, x for east.
Veh = Tuple[str, str, float, float, float, float]
LAYOUTS: Dict[str, List[Veh]] = {
    "north_clean": [("lead", "car", -16, -21, -6, 0), ("T1", "cash", -24, -31.5, -6, 0),
                    ("T2", "bullion", -34.5, -43.5, -6, 0), ("T3", "bullion", -46.5, -55.5, -6, 0),
                    ("rear", "car", -58.5, -63.5, -6, 0)],
    "east_clean": [("lead", "car", 16, 21, -4, 0), ("T1", "cash", 24, 31.5, -4, 0),
                   ("T2", "bullion", 34.5, 43.5, -4, 0), ("T3", "bullion", 46.5, 55.5, -4, 0),
                   ("rear", "car", 58.5, 63.5, -4, 0)],
    "north_crash": [("T1", "cash", -8, -16, -6, 15), ("T2", "bullion", -19, -28, -5, 20),
                    ("T3", "bullion", -31, -39, -5, 15), ("rear", "car", -42, -47, -6, 10)],
    "east_crash": [("T1", "cash", 9, 17, -4 + 1.1, 25), ("T2", "bullion", 20, 29, -4 - 1.1, 20),
                   ("T3", "bullion", 32, 40, -4 + 1.1, 25), ("rear", "car", 43, 48, -4 - 1.1, 10)],
}
CRASH_LEAD = {"north_crash": (-2.0, 2.0), "east_crash": (4.0, -2.0)}
DOC_QUEUE_END = {("north", 2): -52.0, ("north", 3): -63.0}
DOC_CASH_REAR = {"north": (-57.0, -62.0), "east": (57.0, 62.0)}   # Convoy composition (RT-C0 check)
DOC_THIRD_TRUCK_SHIFT = {"bullion": 12.0, "cash": 10.5}   # truck_count row (RT-C0 check): T3 length + the 3 m gap
# Doc rear-door points (Loot path).
DOC_REAR = {"north_clean": {"T1": (-6, -32), "T2": (-6, -44), "T3": (-6, -56)},
            "east_clean": {"T1": (33, -4), "T2": (45, -4), "T3": (56, -4)}}
DOC_REAR_Y = {"east_clean": {"T2": -1.7, "T3": -3.4}}

# Loot-path claims: (label, doc metres, the chain of points the doc describes).
CP = "car_park"
STAIR_A_DOOR: Pt = (16, -46)
ENTRANCE: Pt = (24, -14)
LIFT: Pt = (20.5, -48.5)                                 # LF local (3..6, 0..3) -> site
E1: Pt = (23, -30)
E2: Pt = (92, -4)
WEST_BARRIER: Pt = (16, -30)
JUNCTION: Pt = (0, 0)
PATHS: List[Tuple[str, float, List[Pt]]] = [
    ("north T2 -> stair A door -> E1", 42, [(-6, -44), STAIR_A_DOOR, E1]),
    ("north T1 -> entrance -> E1", 65, [(-6, -32), ENTRANCE, E1]),
    ("north T1 -> west barrier (throw spot)", 24, [(-6, -32), WEST_BARRIER]),
    ("north T1 -> junction -> E2", 125, [(-6, -32), JUNCTION, E2]),
    ("north T2 -> stair A door (E3 by the stairs, + 2 storeys)", 42, [(-6, -44), STAIR_A_DOOR]),
    ("east T1 -> entrance -> E1", 35, [(33, -4), ENTRANCE, E1]),
    ("east T3 -> entrance -> E1 (uphill)", 50, [(56, -4), ENTRANCE, E1]),
    ("east T1 -> E2", 60, [(33, -4), E2]),
    ("east T3 -> E2", 36, [(56, -4), E2]),
    ("east T1 -> entrance -> lift (E3)", 50, [(33, -4), ENTRANCE, LIFT]),
    ("crash -> entrance -> E1", 45, [JUNCTION, ENTRANCE, E1]),
    ("crash -> E2", 95, [JUNCTION, E2]),
    ("crash -> stair A door -> lift (E3)", 50, [JUNCTION, STAIR_A_DOOR, LIFT]),
]
PATH_TOL = 0.10                                          # a doc "≈" may be 10 % short of the straight-line chain


def corners(route: str, v: Veh) -> List[Pt]:
    """The vehicle box's four corners in site (x, z)."""
    _n, kind, a0, a1, lat, yaw = v
    c_along, ln, wd = (a0 + a1) / 2.0, LEN[kind], WIDTH[kind]
    t = math.radians(yaw)
    pts: List[Pt] = []
    for sa, sl in ((-1, -1), (-1, 1), (1, 1), (1, -1)):
        da, dl = sa * ln / 2.0, sl * wd / 2.0
        ra, rl = da * math.cos(t) - dl * math.sin(t), da * math.sin(t) + dl * math.cos(t)
        pts.append((lat + rl, c_along + ra) if route == "north" else (c_along + ra, lat + rl))
    return pts


def lateral_extent(route: str, v: Veh) -> Tuple[float, float]:
    vals = [p[0] if route == "north" else p[1] for p in corners(route, v)]
    return min(vals), max(vals)


def check_clean(rep: Report) -> None:
    rep.section("Clean queues (spacing, lengths, stop lines, ends)")
    for key in ("north_clean", "east_clean"):
        route = key.split("_")[0]
        vs = LAYOUTS[key]
        bad = []
        for v in vs:
            if abs(abs(v[3] - v[2]) - LEN[v[1]]) > 1e-6:
                bad.append("%s is %g m, a %s is %g m" % (v[0], abs(v[3] - v[2]), v[1], LEN[v[1]]))
        for a, b in zip(vs, vs[1:]):
            g = abs(b[2] - a[3])
            if abs(g - GAP) > 1e-6:
                bad.append("%s -> %s gap %g m" % (a[0], b[0], g))
        rep.expect(not bad, "%s: 5 vehicles, %g m gaps, lengths %s%s" % (key, GAP, [abs(v[3] - v[2]) for v in vs],
                                                                         "" if not bad else ": " + "; ".join(bad)))
        lead_gap = abs(vs[0][2] - STOP_LINE[route])
        rep.expect(lead_gap <= 2.0, "%s: lead car %.1f m behind the stop line %g" % (key, lead_gap, STOP_LINE[route]))
        if route == "north":
            two = vs[2][3] - GAP - LEN["car"]
            three = vs[4][3]
            for n, end in ((2, two), (3, three)):
                doc = DOC_QUEUE_END[("north", n)]
                rep.expect(abs(end - doc) <= 1.0, "north queue end with %d trucks z %.1f (doc %g)" % (n, end, doc))
            for t3, doc in DOC_THIRD_TRUCK_SHIFT.items():
                shift = LEN[t3] + GAP
                rep.expect(abs(shift - doc) < 1e-6 and (t3 != "bullion" or abs((two - three) - doc) < 1e-6),
                           "a %s T3 moves the rear car %.1f m back (doc %.1f)" % (t3, shift, doc))
            cash_rear = (vs[3][2] - LEN["cash"] - GAP, vs[3][2] - LEN["cash"] - GAP - LEN["car"])
            rep.expect(cash_rear == DOC_CASH_REAR["north"], "north rear car with t3_cash z %g..%g (doc %s)"
                       % (cash_rear + (DOC_CASH_REAR["north"],)))
        else:
            cash_rear = (vs[3][2] + LEN["cash"] + GAP, vs[3][2] + LEN["cash"] + GAP + LEN["car"])
            rep.expect(cash_rear == DOC_CASH_REAR["east"], "east rear car with t3_cash x %g..%g (doc %s)"
                       % (cash_rear + (DOC_CASH_REAR["east"],)))
        for t, pt in DOC_REAR.get(key, {}).items():
            v = next(x for x in vs if x[0] == t)
            rear = v[3]
            behind = (rear - pt[1]) if route == "north" else (pt[0] - rear)
            rep.expect(0.0 <= behind <= GAP, "%s %s rear-door point %s is %.1f m behind the doors (inside the %g m gap)"
                       % (key, t, pt, behind, GAP))
        for t, y in DOC_REAR_Y.get(key, {}).items():
            pt = DOC_REAR[key][t]
            rep.expect(abs(S.ramp_y(pt[0]) - y) <= 0.1, "%s %s rear point height %.2f (doc %.1f)"
                       % (key, t, S.ramp_y(pt[0]), y))


def check_fit(rep: Report) -> None:
    rep.section("Fit: under the Skyway, in the lanes, the trench, the height bar")
    for key, vs in LAYOUTS.items():
        route = key.split("_")[0]
        for v in vs:
            lo, hi = lateral_extent(route, v)
            if route == "north":
                ok = S.SKYWAY[0] <= lo and hi <= S.SKYWAY[2] and S.ORCHARD_CW[0] <= lo and hi <= S.MEDIAN[0]
                clear_pier = min(abs(S.MEDIAN[0] - hi), 99.0)
                if not ok:
                    rep.fail("%s %s x %.1f..%.1f leaves the west lanes (x -10..-1) or the deck" % (key, v[0], lo, hi))
                else:
                    rep.ok("%s %s x %.1f..%.1f under the deck, %.1f m clear of the median piers" % (key, v[0], lo, hi,
                                                                                                    clear_pier))
            else:
                walls = v[2] >= S.RAMP_X[0] or v[3] >= S.RAMP_X[0]
                to_wall = lo - S.RETAINING_Z[0]
                in_cw = S.TANNERY_CW[1] - 0.25 <= lo and hi <= S.TANNERY_CW[3]
                if "clean" in key:
                    in_cw = in_cw and hi <= 0.0
                if not in_cw:
                    rep.fail("%s %s z %.1f..%.1f outside its lanes" % (key, v[0], lo, hi))
                elif walls and to_wall < 1.0:
                    rep.fail("%s %s only %.1f m from the north retaining wall" % (key, v[0], to_wall))
                else:
                    rep.ok("%s %s z %.1f..%.1f%s" % (key, v[0], lo, hi,
                                                     ", %.1f m to the trench wall" % to_wall if walls else ""))
    rep.expect(TRUCK_HEIGHT <= S.HEIGHT_BAR[1], "trucks (%.1f m ◇) pass under the %.1f m height bar on route_east"
               % (TRUCK_HEIGHT, S.HEIGHT_BAR[1]))
    rear = LAYOUTS["east_clean"][-1]
    rep.expect(rear[3] < S.UNDERPASS_X[0], "east clean rear car ends at x %.1f, before the bridge (x %.0f)"
               % (rear[3], S.UNDERPASS_X[0]))


def check_crash(rep: Report) -> None:
    rep.section("Crash layouts (gaps, skew, the T-boned lead car)")
    for key in ("north_crash", "east_crash"):
        route = key.split("_")[0]
        vs = LAYOUTS[key]
        gaps = [abs(b[2] - a[3]) for a, b in zip(vs, vs[1:])]
        rep.expect(all(g >= GAP - 1e-6 for g in gaps), "%s: gaps %s m (>= %g)" % (key, gaps, GAP))
        yaws = [v[5] for v in vs if v[1] != "car"]
        offs = [abs(v[4] - LANE[route]) for v in vs]
        rep.expect(all(10 <= y <= 25 for y in yaws) and all(o <= 1.1 + 1e-6 for o in offs),
                   "%s: truck yaw %s deg (10-25), lane offsets <= 1.1 m" % (key, yaws))
        lead = CRASH_LEAD[key]
        first = vs[0][2]
        d = abs(first - (lead[1] if route == "north" else lead[0]))
        rep.expect(d >= 2.0, "%s: T1 front %.1f m from the T-boned lead car %s" % (key, d, lead))


# Vehicle seat / door requirements for the convoy prefabs and their seated units (ENV D's RT cast check against the
# clips, docs/status/env_d.md on env/d-art 9252b9ef item 7; RT plan §7.8). Requirements for A5-02 (convoy_vehicle,
# rt_vehicle_placement / test_rt_clips) and the G2 vehicle generators: nothing is built from them at G1. Metres, from
# the seated root (the driver's root is on the footwell floor under the seat centre, facing the vehicle's front).
SEAT_REQ = {
    "cushion_above_root": 0.36,
    "wheel_centre_ahead": 0.40, "wheel_centre_up": 0.76, "wheel_rim_r": 0.18, "wheel_tilt_deg": 30.0,
    "head_up": (1.0, 1.05), "roof_liner_min": 1.15,
    "door_open_behind": 0.30, "door_open_ahead": 0.65, "door_sill_max": 0.22, "door_beside_seat": 0.42,
    "clear_beside_seat": 1.10,
}
SEAT_INFO_KEYS = ("cushion_above_root", "wheel_centre_ahead", "wheel_centre_up", "wheel_rim_r", "wheel_tilt_deg",
                  "door_open_behind", "door_open_ahead", "door_sill_max", "door_beside_seat", "clear_beside_seat")
CAR_HEIGHT = 1.5            # the escort / scout cars: fine if their floor is at most 0.35 m (1.15 m liner)
CAR_FLOOR_MAX = 0.35
# vehicle_exit assumes a footwell level with the road: the 3.2-3.6 m armoured cabs need van_exit or a root drop (A).
CAB_NEEDS_DROP = ("cash", "bullion")


def check_seats(rep: Report) -> None:
    rep.section("Vehicle seats and doors (D's clip numbers; requirements for A5-02, nothing built at G1)")
    liner = CAR_HEIGHT - CAR_FLOOR_MAX
    rep.expect(liner >= SEAT_REQ["roof_liner_min"], "escort cars %.2f m tall, floor <= %.2f m: liner %.2f m >= %.2f"
               % (CAR_HEIGHT, CAR_FLOOR_MAX, liner, SEAT_REQ["roof_liner_min"]))
    rep.expect(SEAT_REQ["head_up"][1] < SEAT_REQ["roof_liner_min"], "head %.2f-%.2f m under the %.2f m liner"
               % (SEAT_REQ["head_up"] + (SEAT_REQ["roof_liner_min"],)))
    rep.info("driver: cushion %.2f m up; wheel centre %.2f ahead / %.2f up, rim r %.2f, tilted %.0f deg; door opening "
             "%.2f behind to %.2f ahead of the seat centre, sill <= %.2f, %.2f beside; %.2f m clear beside the seat"
             % tuple(SEAT_REQ[k] for k in SEAT_INFO_KEYS))
    rep.info("cab dismount: %s trucks need van_exit or a root drop (vehicle_exit assumes a road-level footwell; A)"
             % " / ".join(CAB_NEEDS_DROP))


def check_movers(rep: Report) -> None:
    rep.section("Movers (D-149.8)")
    rep.expect(len(MOVERS) <= MAX_MOVERS, "%d drive-in movers (%s) <= %d; the escape van pops in"
               % (len(MOVERS), ", ".join(MOVERS), MAX_MOVERS))


def check_paths(rep: Report) -> None:
    rep.section("Loot-path distances vs the straight-line chain (doc may be <= %d %% short)" % int(PATH_TOL * 100))
    for label, doc, pts in PATHS:
        lb = path_len(pts)
        if doc < lb * (1.0 - PATH_TOL):
            rep.fail("%s: doc ≈ %g m but the straight-line chain is already %.1f m" % (label, doc, lb))
        else:
            rep.ok("%s: doc ≈ %g m, chain %.1f m" % (label, doc, lb))


def check() -> Report:
    rep = Report("rolling_thunder_convoy --check")
    check_clean(rep)
    check_fit(rep)
    check_crash(rep)
    check_movers(rep)
    check_seats(rep)
    check_paths(rep)
    return rep


if __name__ == "__main__":
    if "--check" in sys.argv:
        r = check()
        print(r.render())
        sys.exit(0 if r.passed else 1)
    for k, vs in LAYOUTS.items():
        print(k)
        for v in vs:
            print("  %-5s %-8s %7.1f .. %7.1f  lateral %5.1f  yaw %3.0f" % v)
