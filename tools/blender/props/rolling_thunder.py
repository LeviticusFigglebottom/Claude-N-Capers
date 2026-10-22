"""Rolling Thunder new generators (RT-C2 batch 3, docs/process/next_heist_rolling_thunder.md §3c "genuinely new"),
library materials only. Blender +Y = Godot -Z; floor pivots (x / y centred, bottom at z = 0).

Vehicles (one parametric truck family; the length runs along Y, the front at Blender -Y = Godot +Z, the rear at
Blender +Y = Godot -Z, as the van and the limo; static visual scenes that A5-01 / A5-02's movers can wrap):

* ``veh_armored_truck_cash`` (7.5 m) / ``veh_armored_truck_bullion`` (9 m, the rear-door thermite plate, D-149.2):
  the Vaultline cash-in-transit truck, split in two prefab visuals on one frame (the full truck's pivot, bottom-centre;
  RT-C2 convoy: one collider per part, no stacked bodies):
  * the hold (``veh_armored_truck_*``, A5-01 ``armored_truck``'s visual, Safe slots): `Body` (the armoured box, open at
    the rear, with the cargo floor and two racks inside: the truck's collision is fitted to it), `Door` (one rear door
    on its hinge pivot at +X, the leaf toward -X, so Safe's ``rotation.y = -open`` swings it out; the lock plate and,
    on the bullion truck, the thermite plate ride on it), `DrillPoint` (the one saw point on the lock, -Z into it,
    D-138), `LootAnchor` (the hold floor), `ThermitePoint` (bullion), `Rear` (the rear step and tail lights, outside
    `Body`) and the rear axles;
  * the cab (``veh_armored_cab_*``, A5-02 ``convoy_vehicle``'s visual): `Body` (the cab and the front chassis: the
    mover's collision is fitted to it), `Seat0` (driver) / `Seat1` (passenger) on the cab floor 1.2 m up (sit_vehicle's
    root, the cushion 0.36 m over it; facing the front, +Z; the cab dismount needs van_exit or a root drop), `WheelCentre` 0.40 m ahead / 0.76 m up, cab doors
    `CabDoorL` / `CabDoorR` from 0.30 m behind to 0.65 m ahead of the seat centre with the sill <= 0.22 m over the cab
    floor (D's clip numbers, rolling_thunder_convoy.py SEAT_REQ), and the front axle.
* ``veh_mixer_truck``: Reyes's concrete mixer (8 m): cab, chassis, the drum on `Drum` (its pivot on the drum axis, so a
  mover can turn it), the chute and ladder at the rear.
* ``veh_lorry``: an articulated lorry, tractor unit + box trailer (``ln`` overall, ``w`` wide; the closures' sizes).
* ``veh_lorry_tm``: the rigid traffic-management truck with the raised amber arrow board.
"""

from __future__ import annotations

import math

from _pb import Kit, lettering

TRI_BUDGET = 20000
_VEH = {"kind": "vehicle", "group": "exterior", "place": "none", "surface": "metal"}
VARIANTS = {
    "veh_armored_truck_cash": {
        "fn": "truck",
        "style": "armored",
        "part": "hold",
        "ln": 7.5,
        "w": 2.5,
        "h": 3.2,
        "cat": {"prefab": "armored_truck", "kind": "armored_truck", "surface": "metal"},
    },
    "veh_armored_truck_bullion": {
        "fn": "truck",
        "style": "armored",
        "part": "hold",
        "ln": 9.0,
        "w": 2.5,
        "h": 3.6,
        "bullion": True,
        "cat": {"prefab": "armored_truck", "kind": "armored_truck", "surface": "metal"},
    },
    "veh_armored_cab_cash": {
        "fn": "truck",
        "style": "armored",
        "part": "cab",
        "ln": 7.5,
        "w": 2.5,
        "h": 3.2,
        "cat": {"prefab": "convoy_vehicle", "kind": "convoy_vehicle", "surface": "metal"},
    },
    "veh_armored_cab_bullion": {
        "fn": "truck",
        "style": "armored",
        "part": "cab",
        "ln": 9.0,
        "w": 2.5,
        "h": 3.6,
        "cat": {"prefab": "convoy_vehicle", "kind": "convoy_vehicle", "surface": "metal"},
    },
    # QC-81: the bullion truck's rear-door thermite (A's burn_point visual): only `Fire`, the molten patch on the
    # thermite plate (BurnPoint shows it while burning); the plate itself rides on the truck's `Door`
    "prop_thermite_lock": {"fn": "thermite_lock", "cat": {"prefab": "burn_point", "kind": "burn_point"}},
    "veh_mixer_truck": {"fn": "truck", "style": "mixer", "ln": 8.0, "w": 2.5, "h": 3.5, "cat": dict(_VEH)},
    # phase 2 (D-149.8, the LEAD's ruling): Reyes's mixer as A5-02's convoy_vehicle visual (the mover fits its collision
    # to `Body`; Seat0 driver +X / Seat1 on the cab floor, facing +Z, from _cab_markers)
    "veh_mixer_truck_mover": {"fn": "truck", "style": "mixer", "ln": 8.0, "w": 2.5, "h": 3.5,
                              "cat": {"prefab": "convoy_vehicle", "kind": "convoy_vehicle"}},
    "veh_lorry": {"fn": "truck", "style": "lorry", "ln": 14.0, "w": 2.0, "h": 3.9, "cat": dict(_VEH)},
    "veh_lorry_tm": {"fn": "truck", "style": "tm", "ln": 9.0, "w": 2.5, "h": 3.4, "cat": dict(_VEH)},
    # the diner's cookline (D: the top at 0.90 m, its front edge 0.30 m ahead of the cook); griddle / fryer / range
    # modules on a 5 m run, the extraction hood over its back half
    "prop_cookline": {
        "fn": "cookline",
        "ln": 5.0,
        "d": 0.8,
        "cat": {"kind": "cookline", "place": "wall", "group": "kitchen", "surface": "metal", "top": 0.9},
    },
    # the diner booth: two high-backed benches facing across a fixed table (sit_eat / cower_seated in pairs)
    "prop_diner_booth": {
        "fn": "booth",
        "cat": {"kind": "booth", "place": "wall", "group": "sales", "surface": "fabric"},
    },
    # A5-03's charge box (the item_pickup visual): a ribbed olive case, the lid up, two charges in the tray
    "prop_c4_box": {
        "fn": "c4_box",
        "cat": {"kind": "pickup_box", "place": "on", "group": "exterior", "surface": "metal"},
    },
    # the car-park entry barrier (post + 3.6 m arm, raised: the entrance is a walk route) and the height bars (2.1 m car
    # park, 4.4 m underpass; unplaced: the map's G1 EntranceHeightBar lintel and trench HeightBar are the bars)
    "prop_car_park_barrier": {
        "fn": "barrier_arm",
        "arm": 3.6,
        "cat": {"kind": "barrier", "place": "none", "group": "exterior", "surface": "metal"},
    },
    "prop_car_park_height_bar_w600": {
        "fn": "height_bar",
        "span": 6.0,
        "clear": 2.1,
        "cat": {"kind": "height_bar", "place": "none", "group": "exterior", "surface": "metal"},
    },
    "prop_car_park_height_bar_w2200_h440": {
        "fn": "height_bar",
        "span": 22.0,
        "clear": 4.4,
        "cat": {"kind": "height_bar", "place": "none", "group": "exterior", "surface": "metal"},
    },  # landmarks 1-3 and the street / site set (§3c)
    "prop_rt_tower_crane": {
        "fn": "tower_crane",
        "cat": {"kind": "landmark", "place": "none", "group": "exterior", "surface": "metal"},
    },
    "prop_rt_skyway_girder_l2600": {
        "fn": "girder",
        "ln": 26.0,
        "text": "ORCHARD SKYWAY",
        "cat": {"kind": "landmark", "mount": "wall", "place": "wall_mount", "group": "exterior", "surface": "metal"},
    },
    "prop_rt_clock_pillar": {
        "fn": "clock_pillar",
        "cat": {"kind": "landmark", "place": "none", "group": "exterior", "surface": "metal"},
    },
    "prop_traffic_signal": {
        "fn": "signal",
        "cat": {"kind": "traffic_signal", "place": "none", "group": "exterior", "surface": "metal"},
    },
    "prop_scaffold_bay_w200_h460": {
        "fn": "scaffold",
        "w": 2.0,
        "h": 4.6,
        "net": True,
        "cat": {"kind": "scaffold", "place": "none", "group": "exterior", "surface": "metal"},
    },
    "prop_scaffold_bay_w100_h460": {
        "fn": "scaffold",
        "w": 1.0,
        "h": 4.6,
        "net": True,
        "cat": {"kind": "scaffold", "place": "none", "group": "exterior", "surface": "metal"},
    },
    "prop_scaffold_edge_w200_h110": {
        "fn": "scaffold",
        "w": 2.0,
        "h": 1.1,
        "cat": {"kind": "scaffold", "place": "none", "group": "exterior", "surface": "metal"},
    },
    "prop_site_formwork_stack": {
        "fn": "clutter",
        "style": "formwork",
        "cat": {"kind": "formwork", "place": "floor", "group": "exterior", "surface": "wood"},
    },
    "prop_site_rebar_bundle": {
        "fn": "clutter",
        "style": "rebar",
        "cat": {"kind": "rebar", "place": "floor", "group": "exterior", "surface": "metal"},
    },
    "prop_site_mortar_mixer": {
        "fn": "clutter",
        "style": "mixer",
        "cat": {"kind": "mixer", "place": "floor", "group": "exterior", "surface": "metal"},
    },
    "prop_rail_track_l3000": {
        "fn": "rail_track",
        "ln": 30.0,
        "cat": {"kind": "rail_track", "place": "none", "group": "exterior", "surface": "metal"},
    },
    "prop_heli_pad_marking": {
        "fn": "heli_pad",
        "r": 5.0,
        "cat": {"kind": "marking", "place": "none", "group": "exterior", "surface": "concrete"},
    },
    # the car-park bay lines (§3c "bay lines", painted as 4 mm meshes): 3 bays on a 2.4 m pitch, 4.4 m deep (clear of
    # the guards and columns behind the bays), the parked car in the middle one
    "prop_bay_lines_x3": {
        "fn": "bay_lines",
        "n": 3,
        "pitch": 2.4,
        "depth": 4.4,
        "cat": {"kind": "marking", "place": "none", "group": "exterior", "surface": "concrete"},
    },
    # the site hoarding's graphic panel (§3c "hoarding graphic"): a painted 6 x 1.4 m board, TANNERS REACH
    "prop_hoarding_graphic_w600": {
        "fn": "hoarding_graphic",
        "w": 6.0,
        "text": "TANNERS REACH",
        "cat": {"kind": "signage", "mount": "wall", "place": "wall_mount", "group": "exterior", "surface": "wood"},
    },
    "prop_neon_halfway": {
        "fn": "neon_sign",
        "text": "HALFWAY",
        "line2": "OPEN 24 HRS",
        "key2": "emit_mint",
        "cat": {"kind": "neon_sign", "mount": "wall", "place": "wall_mount", "group": "exterior", "surface": "metal"},
    },
    # GPU-21 (the LEAD's render review: DR read as an office): the diner's own furniture, each a shared kit's form with
    # the diner finish (D-147 §3c "a new prop with a reason"; docs/design/heists/rolling_thunder.md, GPU-21 props).
    # pin_only: no other kit's pick of these kinds changes.
    "prop_diner_stool": {
        "fn": "diner_stool",
        "seat": 0.72,
        "cat": {"kind": "stool", "place": "floor", "group": "sales", "surface": "metal", "pin_only": True},
    },
    "prop_diner_chair": {
        "fn": "diner_chair",
        "seat": 0.47,
        "cat": {"kind": "chair", "place": "seat", "hosts": ["table"], "group": "sales", "surface": "fabric",
                "seat_fwd": 0.12, "pin_only": True},
    },
    "prop_diner_counter_w250": {
        "fn": "diner_counter",
        "ln": 2.5,
        "d": 0.8,
        "cat": {"kind": "counter_service", "place": "wall", "support": True, "clear": 1.0, "top": 0.9, "group": "sales",
                "surface": "wood", "pin_only": True},
    },
    "prop_diner_table_w80": {
        "fn": "diner_table",
        "w": 0.8,
        "d": 0.8,
        "h": 0.74,
        "cat": {"kind": "table", "place": "center", "support": True, "clear": 0.7, "group": "sales", "pin_only": True},
    },
    "prop_diner_table_l120": {
        "fn": "diner_table",
        "w": 1.2,
        "d": 0.8,
        "h": 0.74,
        "cat": {"kind": "table", "place": "center", "support": True, "clear": 0.7, "group": "sales", "pin_only": True},
    },
    "prop_diner_table_l180": {
        "fn": "diner_table",
        "w": 1.8,
        "d": 0.8,
        "h": 0.74,
        "cat": {"kind": "table", "place": "center", "support": True, "clear": 0.7, "group": "sales", "pin_only": True},
    },
    "prop_pendant_diner": {
        "fn": "diner_pendant",
        "drop": 0.5,
        "cat": {"kind": "light_fixture", "place": "ceiling", "fixture": True, "group": "lighting", "pin_only": True,
                "light": {"type": "omni", "color": "#FFC890", "energy": 1.5, "range": 5.0, "pos": [0.0, -0.72, 0.0]}},
    },
    "prop_diner_menu_board": {
        "fn": "menu_board",
        "w": 2.4,
        "h": 0.9,
        "cat": {"kind": "menu_board", "mount": "wall", "place": "wall_mount", "group": "sales", "surface": "wood",
                "pin_only": True},
    },
    # GPU-22 (the LEAD: rc_diner_neon showed a sliver of pink; the wall neon is edge-on from the street): a two-sided
    # pole sign at the diner's NE corner, readable along Tannery and from the junction, the convoy stop's landmark
    # (D-147 §3c "a new prop with a reason": no street pole sign in the catalog).
    "prop_pole_sign_halfway": {
        "fn": "pole_sign",
        "text": "HALFWAY",
        "line2": "DINER  OPEN 24 HRS",
        "key2": "emit_mint",
        "cat": {"kind": "pole_sign", "place": "none", "group": "exterior", "surface": "metal", "pin_only": True},
    },
    "prop_neon_eat": {
        "fn": "neon_sign",
        "text": "EAT",
        "key": "emit_led_red",
        "line2": "COFFEE  PIE",
        "key2": "emit_mint",
        "cat": {"kind": "neon_sign", "mount": "wall", "place": "wall_mount", "group": "sales", "surface": "metal",
                "pin_only": True},
    },
}

WHEEL_R = 0.5
# prop_traffic_signal: the pole stands this far -X of the pivot (the footprint centre).
SIGNAL_POLE = 1.4
CAB_FLOOR = 1.2
# the armoured truck: its cab length (the cab visual ends there, the hold starts 0.06 m behind it), and the rear
# door's lock edge (x): the leaf hangs from the +X hinge, the lock near its free (-X) edge
ARMORED_CAB = 2.1
LOCK_X = -0.85


def _wheels(run, w: float, ys: list[float], dual: list[bool]) -> None:
    for wy, twin in zip(ys, dual):
        for sx in (-1, 1):
            xs = [sx * (w / 2 - 0.2)] + ([sx * (w / 2 - 0.5)] if twin else [])
            for wx in xs:
                run.cyl(WHEEL_R, 0.28, (wx, wy, WHEEL_R), "rubber", axis="X", segs=20)
                run.cyl(0.3, 0.29, (wx, wy, WHEEL_R), "steel", axis="X", segs=14)
            run.cyl(0.09, 0.3, (sx * (w / 2 - 0.2), wy, WHEEL_R), "chrome", axis="X", segs=8)


def _cab(k: Kit, body, w: float, yf: float, cab: float, ch: float, paint: str,
         glass_key: str = "glass_tinted") -> None:
    """A forward-control cab from yf to yf + cab, roof at ch: shell, raked screen, side windows, grille, lamps."""
    shell = body.part(bevel=0.04, segments=2)
    trim = body.part(bevel=0.004)
    glass = body.part(bevel=0.0)
    yb = yf + cab
    prof = [(yf + 0.02, 0.7), (yf, 1.5), (yf + 0.15, ch - 0.12), (yf + 0.35, ch), (yb, ch), (yb, 0.7)]
    shell.profile_x(prof, -w / 2, w / 2, paint)
    # windscreen (proud of the raked front) and side windows
    a, b = (yf + 0.03, 1.75), (yf + 0.17, ch - 0.2)
    ln = math.hypot(b[0] - a[0], b[1] - a[1])
    nx, nz = -(b[1] - a[1]) / ln, (b[0] - a[0]) / ln
    glass.profile_x(
        [
            (a[0] + nx * 0.004, a[1] + nz * 0.004),
            (b[0] + nx * 0.004, b[1] + nz * 0.004),
            (b[0] + nx * 0.014, b[1] + nz * 0.014),
            (a[0] + nx * 0.014, a[1] + nz * 0.014),
        ],
        -w / 2 + 0.1,
        w / 2 - 0.1,
        glass_key,
    )
    for sx in (-1, 1):
        g0, g1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.012)))
        glass.profile_x(
            [(yf + 0.35, 1.8), (yf + 1.2, 1.8), (yf + 1.2, ch - 0.25), (yf + 0.45, ch - 0.25)], g0, g1, glass_key
        )
        m0, m1 = sorted((sx * (w / 2 + 0.03), sx * (w / 2 + 0.25)))
        trim.bx((m0, yf + 0.3, 1.9), (m1, yf + 0.36, 2.35), "plastic_black")  # mirror
        l0, l1 = sorted((sx * (w / 2 - 0.45), sx * (w / 2 - 0.08)))
        trim.bx((l0, yf - 0.03, 0.85), (l1, yf + 0.01, 1.0), "emit_cool")  # headlamp
        s0, s1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.012)))
        trim.bx((s0, yf + 0.3, 0.75), (s1, yf + 0.32, ch - 0.1), "plastic_black")  # door seams
        trim.bx((s0, yf + 1.3, 0.75), (s1, yf + 1.32, ch - 0.1), "plastic_black")
        st0, st1 = sorted((sx * (w / 2 - 0.05), sx * (w / 2 + 0.06)))
        trim.bx((st0, yf + 0.45, 0.45), (st1, yf + 1.15, 0.5), "steel")  # cab steps
        trim.bx((st0, yf + 0.45, 0.85), (st1, yf + 1.15, 0.9), "steel")
    trim.bx((-0.7, yf - 0.025, 1.05), (0.7, yf + 0.01, 1.45), "plastic_black")  # grille
    trim.bx((-w / 2 + 0.03, yf - 0.12, 0.45), (w / 2 - 0.03, yf + 0.1, 0.72), "plastic_black")  # bumper


def _cab_markers(k: Kit, w: float, yf: float) -> None:
    """D's driver / passenger clip numbers (SEAT_REQ): seats on the cab floor, the wheel, the cab doors (closed)."""
    seat_y = yf + 1.0
    # driver, passenger (ConvoyVehicle.seats()); the driver at +X (Godot +X: the left when facing +Z), as the escort cars
    # (the LEAD, round 275: one hand of drive across the convoy)
    for name, sx in (("Seat0", 1), ("Seat1", -1)):
        k.empty(name, (sx * (w / 2 - 0.6), seat_y, CAB_FLOOR), rotation=(0.0, 0.0, math.pi))  # root on the floor, facing the front
    wc = (w / 2 - 0.6, seat_y - 0.40, CAB_FLOOR + 0.76)
    k.empty("WheelCentre", wc)
    # the steering wheel (D's sit_vehicle_drive fit, r280: rim 0.18 m round WheelCentre, its face tilted 30 deg toward
    # the driver, the hands at 10 and 2) on its column down to the dash
    sw = k.obj("SteeringWheel")
    sp = sw.part(bevel=0.0)
    t = math.radians(30.0)
    v = (0.0, -math.sin(t), math.cos(t))   # the wheel's "up" in its plane, leaning toward the front
    rim = [(wc[0] + 0.18 * math.cos(a), wc[1] + 0.18 * math.sin(a) * v[1], wc[2] + 0.18 * math.sin(a) * v[2])
           for a in (2.0 * math.pi * i / 16 for i in range(17))]
    sp.tube(rim, 0.016, "plastic_black", segs=6)
    sp.rod(wc, (wc[0], wc[1] - 0.32, wc[2] - 0.2), 0.03, "plastic_black", segs=8)   # the column
    sw.build()
    for name, sx in (("CabDoorL", -1), ("CabDoorR", 1)):
        piv = k.empty(name, (sx * (w / 2 + 0.014), seat_y - 0.65, CAB_FLOOR + 0.2))
        dm = k.obj(name + "Mesh", parent=piv)
        dp = dm.part(bevel=0.004)
        x0, x1 = sorted((0.0, sx * 0.01))
        dp.bx((x0, 0.0, 0.0), (x1, 0.95, 0.38), "plastic_black")  # door kick plate
        dm.build()


def _armored(k: Kit, p: dict, body, w: float, ln: float, h: float, yf: float, yr: float) -> None:
    """The armoured truck as two prefab visuals on one frame (``part``): the cab (the mover) or the hold (the Safe)."""
    y0 = yf + ARMORED_CAB + 0.06
    if p["part"] == "cab":
        _cab(k, body, w, yf, ARMORED_CAB, h - 0.3, "rt_vaultline")
        skirt = body.part(bevel=0.03, segments=2)
        skirt.bx((-w / 2 + 0.05, yf + 0.5, 0.55), (w / 2 - 0.05, yf + ARMORED_CAB, 0.95), "metal_dark")  # chassis
        body.build()
        _cab_markers(k, w, yf)
        run = k.obj("Wheels")
        _wheels(run.part(bevel=0.0), w, [yf + 1.1], [False])
        run.build()
        return
    shell = body.part(bevel=0.03, segments=2)
    trim = body.part(bevel=0.004)
    inner = body.part(bevel=0.0)
    t = 0.06  # the armour: five walls, open at the rear behind the door
    shell.bx((-w / 2, y0, h - t), (w / 2, yr, h), "rt_vaultline")  # roof
    shell.bx((-w / 2, y0, 0.95), (w / 2, yr, 0.95 + t), "rt_vaultline")  # floor plate
    shell.bx((-w / 2, y0, 0.95), (w / 2, y0 + t, h), "rt_vaultline")  # bulkhead
    for sx in (-1, 1):
        s0, s1 = sorted((sx * w / 2, sx * (w / 2 - t)))
        shell.bx((s0, y0, 0.95), (s1, yr, h), "rt_vaultline")  # side walls
    shell.bx((-w / 2 + 0.05, y0, 0.55), (w / 2 - 0.05, yr - 0.2, 0.95), "metal_dark")  # chassis skirt
    for sx in (-1, 1):
        b0, b1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.012)))
        trim.bx((b0, y0 + 0.1, 1.55), (b1, yr - 0.1, 1.75), "rt_vaultline_band")  # brass band
        for gy in (y0 + 1.0, y0 + 2.2):  # gun ports
            trim.bx((b0, gy, 2.1), (b1, gy + 0.18, 2.28), "metal_dark")
    trim.bx((-0.5, y0 + 1.0, h), (0.5, y0 + 1.8, h + 0.08), "metal_dark")  # roof hatch (shut)
    trim.bx((-0.6, y0, h), (0.6, y0 + 0.25, h + 0.25), "plastic_black")  # roof beacon box
    # the cargo hold: the floor, two racks of shelves
    inner.bx((-w / 2 + t, y0 + t, 0.95 + t), (w / 2 - t, yr - 0.1, 1.0 + t), "steel_galv")
    for sx in (-1, 1):
        for z in (1.4, 1.9, 2.4):
            r0, r1 = sorted((sx * (w / 2 - t), sx * (w / 2 - 0.55)))
            inner.bx((r0, y0 + 0.4, z), (r1, yr - 0.3, z + 0.03), "steel_galv")
    body.build()
    # outside `Body` (the fitted collision stops at the doors): the rear step and the tail lights
    rear = k.obj("Rear")
    rp = rear.part(bevel=0.004)
    rp.bx((-w / 2 + 0.05, yr - 0.05, 0.4), (w / 2 - 0.05, yr + 0.35, 0.52), "steel")  # rear step
    for sx in (-1, 1):
        l0, l1 = sorted((sx * (w / 2 - 0.3), sx * (w / 2 - 0.06)))
        rp.bx((l0, yr + 0.004, 0.62), (l1, yr + 0.03, 0.9), "metal_red")  # tail lights
    rear.build()
    # the rear door: Safe's one `Door` pivot (hinge at +X, the leaf toward -X, closed); the lock plate on its free edge
    dh = h - 1.05
    hx = w / 2 - 0.03
    door = k.empty("Door", (hx, yr + 0.01, 1.0))
    dm = k.obj("DoorMesh", parent=door)
    dp = dm.part(bevel=0.006)
    dp.bx((-(w - 0.06), 0.0, 0.0), (0.0, 0.06, dh), "rt_vaultline")  # leaf
    dp.bx((-(w - 0.06) / 2 - 0.01, 0.06, 0.05), (-(w - 0.06) / 2 + 0.01, 0.065, dh - 0.05), "metal_dark")  # seam
    lx = LOCK_X - hx
    dp.bx((lx - 0.16, 0.06, 0.45), (lx + 0.16, 0.09, 0.95), "steel")  # lock plate
    dp.bx((lx + 0.2, 0.06, 0.62), (lx + 0.45, 0.09, 0.68), "steel")  # handle
    if p.get("bullion"):
        # D-149.2: the thermite plate under the lock (the ground-level burn point, its UsePoint on the road)
        dp.bx((lx - 0.22, 0.06, 0.0), (lx + 0.22, 0.075, 0.38), "metal_orange")
    dm.build()
    if p.get("bullion"):
        k.empty("ThermitePoint", (LOCK_X, yr + 0.08, 1.19))
    k.empty("DrillPoint", (LOCK_X, yr + 0.1, 1.7), rotation=(0.0, 0.0, math.pi))
    k.empty("LootAnchor", (0.0, (y0 + yr) / 2, 1.0 + t))
    axles = [yr - 1.6] + ([yr - 2.9] if ln > 8.0 else [])
    run = k.obj("Wheels")
    _wheels(run.part(bevel=0.0), w, axles, [True] * len(axles))
    run.build()


def _mixer(k: Kit, body, w: float, ln: float, h: float, yf: float, yr: float) -> None:
    cab = 2.2
    # D's mixer cab fit (r280): Reyes at the wheel must read from outside, so lighter glass than the armoured cabs
    _cab(k, body, w, yf, cab, 2.95, "metal_white", glass_key="glass_teal")
    trim = body.part(bevel=0.004)
    trim.bx((-0.5, yf + cab, 0.55), (0.5, yr - 0.2, 0.95), "metal_dark")  # chassis
    trim.bx((-w / 2 + 0.1, yf + cab, 0.95), (w / 2 - 0.1, yr - 0.5, 1.05), "metal_dark")  # subframe
    trim.bx((-0.25, yr - 1.6, 1.05), (0.25, yr - 1.2, 2.2), "metal_dark")  # rear pedestal
    trim.bx((-0.25, yf + cab + 0.3, 1.05), (0.25, yf + cab + 0.7, 2.6), "metal_dark")  # front pedestal
    # the chute and the ladder at the rear
    trim.profile_x(
        [(yr - 0.9, 2.3), (yr - 0.2, 1.9), (yr - 0.2, 1.75), (yr - 0.9, 2.15)], -0.25, 0.25, "safety_orange"
    )
    for sx in (-1, 1):
        trim.rod((sx * 0.45, yr - 0.15, 0.6), (sx * 0.45, yr - 0.4, 3.0), 0.02, "steel", segs=6)
    for i in range(7):
        z = 0.8 + i * 0.32
        trim.rod((-0.45, yr - 0.15 - 0.025 * i, z), (0.45, yr - 0.15 - 0.025 * i, z), 0.015, "steel", segs=6)
    body.build()
    _cab_markers(k, w, yf)
    # the drum on its own pivot (the drum axis, tilted 14 deg up toward the rear)
    tilt = math.radians(14)
    cy, cz = (yf + cab + 0.2 + yr - 0.6) / 2, 2.1
    drum_len = (yr - 0.6) - (yf + cab + 0.2)
    piv = k.empty("Drum", (0.0, cy, cz), rotation=(-math.pi / 2 + tilt, 0.0, 0.0))
    dm = k.obj("DrumMesh", parent=piv)
    dp = dm.part(bevel=0.0)
    half = drum_len / 2
    prof = [(0.0, -half), (0.7, -half + 0.05), (1.05, -half + 0.9), (1.05, half - 1.4), (0.5, half), (0.0, half)]
    dp.lathe(prof, "safety_orange", segs=24)
    for t in range(6):  # blade ribs
        a = t * math.pi / 3
        dp.rod(
            (1.06 * math.cos(a), 1.06 * math.sin(a), -half + 1.0),
            (1.06 * math.cos(a + 0.6), 1.06 * math.sin(a + 0.6), half - 1.5),
            0.03,
            "metal_dark",
            segs=4,
            square=True,
        )
    dm.build()
    run = k.obj("Wheels")
    rp = run.part(bevel=0.0)
    _wheels(rp, w, [yf + 1.1, yr - 2.2, yr - 0.9], [False, True, True])
    run.build()


def _lorry(k: Kit, body, w: float, ln: float, h: float, yf: float, yr: float) -> None:
    cab = 2.3
    _cab(k, body, w, yf, cab, 3.0, "rt_lorry_red")
    trim = body.part(bevel=0.004)
    shell = body.part(bevel=0.03, segments=2)
    t0 = yf + cab + 0.9  # trailer nose
    trim.bx((-0.45, yf + cab, 0.55), (0.45, t0 + 0.6, 0.95), "metal_dark")  # tractor chassis
    trim.bx((-0.6, yf + cab + 0.3, 0.95), (0.6, yf + cab + 1.1, 1.05), "steel")  # fifth wheel
    shell.bx((-w / 2, t0, 1.15), (w / 2, yr, h), "trailer_white")  # box trailer
    trim.bx((-w / 2 + 0.05, t0, 0.9), (w / 2 - 0.05, yr, 1.15), "metal_dark")  # trailer frame
    for sx in (-1, 1):
        b0, b1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.012)))
        trim.bx((b0, t0 + 0.2, 1.3), (b1, yr - 0.2, 1.42), "metal_red")  # side stripe
        trim.bx((b0, t0 + 2.0, 0.6), (b1, yr - 2.5, 0.75), "steel")  # side guard
    trim.bx((-w / 2 + 0.05, yr, 1.15), (w / 2 - 0.05, yr + 0.03, h - 0.05), "trailer_white")  # rear doors
    trim.bx((-0.012, yr + 0.03, 1.2), (0.012, yr + 0.04, h - 0.1), "plastic_black")
    body.build()
    _cab_markers(k, w, yf)
    run = k.obj("Wheels")
    rp = run.part(bevel=0.0)
    _wheels(rp, w, [yf + 1.0, yf + cab + 0.7, yr - 2.6, yr - 1.4], [False, True, True, True])
    run.build()


def _tm(k: Kit, body, w: float, ln: float, h: float, yf: float, yr: float) -> None:
    cab = 2.2
    _cab(k, body, w, yf, cab, 2.9, "hivis")
    trim = body.part(bevel=0.004)
    trim.bx((-0.45, yf + cab, 0.55), (0.45, yr - 0.2, 0.95), "metal_dark")  # chassis
    trim.bx((-w / 2, yf + cab + 0.05, 0.95), (w / 2, yr, 1.15), "metal_dark")  # flatbed
    for sx in (-1, 1):
        b0, b1 = sorted((sx * w / 2, sx * (w / 2 - 0.06)))
        trim.bx((b0, yf + cab + 0.05, 1.15), (b1, yr, 1.5), "hivis")  # dropsides
    # the arrow board, raised on its mast over the bed's rear, facing the traffic behind (+Y)
    trim.bx((-0.08, yr - 0.6, 1.15), (0.08, yr - 0.45, h - 1.3), "steel")
    trim.bx((-1.1, yr - 0.45, h - 1.35), (1.1, yr - 0.38, h - 0.05), "plastic_black")
    for i in range(3):  # chevrons
        x = -0.6 + i * 0.6
        trim.profile_y(
            [
                (x - 0.15, h - 1.0),
                (x + 0.15, h - 0.7),
                (x - 0.15, h - 0.4),
                (x - 0.05, h - 0.4),
                (x + 0.25, h - 0.7),
                (x - 0.05, h - 1.0),
            ],
            yr - 0.38,
            yr - 0.36,
            "emit_amber",
        )
    for sx in (-1, 1):
        l0, l1 = sorted((sx * (w / 2 - 0.3), sx * (w / 2 - 0.06)))
        trim.bx((l0, yr, 0.95), (l1, yr + 0.03, 1.12), "metal_red")
    body.build()
    _cab_markers(k, w, yf)
    run = k.obj("Wheels")
    rp = run.part(bevel=0.0)
    _wheels(rp, w, [yf + 1.1, yr - 1.8], [False, True])
    run.build()


def _truck(k: Kit, p: dict) -> None:
    ln, w, h = float(p["ln"]), float(p["w"]), float(p["h"])
    yf, yr = -ln / 2, ln / 2
    body = k.obj("Body")
    style = p["style"]
    if style == "armored":
        _armored(k, p, body, w, ln, h, yf, yr)
    elif style == "mixer":
        _mixer(k, body, w, ln, h, yf, yr)
    elif style == "lorry":
        _lorry(k, body, w, ln, h, yf, yr)
    else:
        _tm(k, body, w, ln, h, yf, yr)


# ------------------------------------------------------------------------------------------- the diner


def _cookline(k: Kit, p: dict) -> None:
    """A stainless cookline along X (``ln``), ``d`` deep, the front (the cook's side) at +Y: base cabinets, a griddle,
    two fryer wells, a four-burner range and a prep top at 0.90 m; the backsplash and the extraction hood
    (2.0-2.5 m) over the back half, so the cook's head stays clear."""
    ln, d = float(p["ln"]), float(p["d"])
    hx, hy = ln / 2, d / 2
    body = k.obj("Body")
    cab = body.part(bevel=0.006)
    trim = body.part(bevel=0.002)
    cab.bx((-hx, -hy, 0.1), (hx, hy - 0.04, 0.86), "steel")  # cabinets
    cab.bx((-hx + 0.03, -hy + 0.03, 0.0), (hx - 0.03, hy - 0.08, 0.1), "plastic_black")  # plinth
    cab.bx((-hx, -hy, 0.86), (hx, hy, 0.9), "steel")  # worktop
    x = -hx
    for kind, wd in (("griddle", 1.4), ("fryer", 1.0), ("range", 1.6), ("prep", ln - 4.0)):
        x0, x1 = x + 0.04, x + wd - 0.04
        if kind == "griddle":
            trim.bx((x0, -hy + 0.1, 0.9), (x1, hy - 0.08, 0.905), "metal_dark")
        elif kind == "fryer":
            half = (x1 - x0) / 2
            for fx in (x0 + 0.03, x0 + half + 0.03):
                trim.bx((fx, -hy + 0.15, 0.9), (fx + half - 0.06, hy - 0.12, 0.905), "metal_dark")
        elif kind == "range":
            for i in range(4):
                trim.cyl(
                    0.11, 0.01, (x0 + 0.4 + (i % 2) * 0.7, -hy + 0.22 + (i // 2) * 0.32, 0.905), "metal_dark", segs=12
                )
        for kx in (x0 + 0.1, x1 - 0.1):  # control knobs
            trim.cyl(0.02, 0.03, (kx, hy + 0.01, 0.78), "plastic_black", axis="Y", segs=8)
        trim.bx((x1, -hy, 0.1), (x1 + 0.006, hy - 0.035, 0.86), "metal_dark")  # module seam
        x += wd
    cab.bx((-hx, -hy, 0.9), (hx, -hy + 0.04, 2.0), "steel")  # backsplash / back
    cab.bx((-hx, -hy, 2.0), (hx, 0.05, 2.5), "steel")  # hood
    trim.bx((-hx + 0.1, -hy + 0.06, 1.995), (hx - 0.1, 0.0, 2.0), "metal_dark")  # filters
    for lx in (-hx / 2, hx / 2):
        trim.bx((lx - 0.2, 0.0, 1.99), (lx + 0.2, 0.04, 2.0), "emit_warm")
    body.build()
    k.collision([((-hx, -hy, 0.0), (hx, hy, 0.9))])


def _booth(k: Kit, p: dict) -> None:
    """A fixed diner booth (2.4 m deep, 1.2 m wide): two high-backed benches face each other across a 0.75 m table;
    `Seat0` / `Seat1` (the -Y bench, facing +Y) and `Seat2` / `Seat3` (the +Y bench, facing -Y) at the cushion."""
    w, dpth = 1.2, 2.4
    hx, hy = w / 2, dpth / 2
    body = k.obj("Body")
    up = body.part(bevel=0.03, segments=2)
    wood = body.part(bevel=0.004)
    for sy in (-1, 1):
        b0, b1 = sorted((sy * hy, sy * (hy - 0.55)))
        wood.bx((-hx, b0, 0.0), (hx, b1, 0.38), "wood_dark")  # bench box
        up.bx((-hx + 0.02, b0, 0.38), (hx - 0.02, b1, 0.47), "rug_burgundy")  # cushion
        k0, k1 = sorted((sy * hy, sy * (hy - 0.12)))
        up.bx((-hx + 0.02, k0, 0.47), (hx - 0.02, k1, 1.25), "rug_burgundy")  # high back
        wood.bx((-hx, k0, 1.25), (hx, k1, 1.3), "wood_dark")
    wood.bx((-hx + 0.05, -0.375, 0.71), (hx - 0.05, 0.375, 0.75), "laminate_grey")  # table top
    wood.cyl(0.05, 0.7, (0.0, 0.0, 0.36), "chrome", segs=10)
    wood.cyl(0.25, 0.02, (0.0, 0.0, 0.01), "chrome", segs=16)
    body.build()
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        k.empty("Seat%d" % i, (sx * 0.28, sy * (hy - 0.33), 0.47))
    k.collision(
        [
            ((-hx, -hy, 0.0), (hx, -hy + 0.55, 0.47)),
            ((-hx, hy - 0.55, 0.0), (hx, hy, 0.47)),
            ((-hx, -hy, 0.47), (hx, -hy + 0.12, 1.3)),
            ((-hx, hy - 0.12, 0.47), (hx, hy, 1.3)),
            ((-hx + 0.05, -0.375, 0.0), (hx - 0.05, 0.375, 0.75)),
        ]
    )


def _diner_stool(k: Kit, p: dict) -> None:
    """A fixed counter stool (GPU-21): a chrome pedestal bolted to the floor on a flange, a foot ring, and a round red
    vinyl seat (``seat`` m, the cushion top) with a chrome band."""
    sz = float(p["seat"])
    o = k.obj("Stool")
    a = o.part(bevel=0.0)
    a.cyl(0.16, 0.02, (0.0, 0.0, 0.01), "chrome", segs=20)  # floor flange
    for i in range(4):
        ang = math.pi / 4 + i * math.pi / 2
        a.cyl(0.012, 0.006, (math.cos(ang) * 0.12, math.sin(ang) * 0.12, 0.023), "chrome", segs=6)  # bolts
    a.rod((0.0, 0.0, 0.02), (0.0, 0.0, sz - 0.09), 0.035, "chrome", segs=12)
    a.torus(0.19, 0.01, (0.0, 0.0, 0.26), "chrome", segs=20, rsegs=6)  # foot ring
    for i in range(3):
        ang = 2 * math.pi * i / 3
        a.rod((0.0, 0.0, 0.26), (math.cos(ang) * 0.19, math.sin(ang) * 0.19, 0.26), 0.008, "chrome", segs=5)
    a.cyl(0.18, 0.02, (0.0, 0.0, sz - 0.08), "chrome", segs=20)  # seat pan
    soft = o.part(bevel=0.02, segments=2)
    soft.cyl(0.19, 0.07, (0.0, 0.0, sz - 0.035), "rt_vinyl_red", segs=24)
    a.torus(0.19, 0.008, (0.0, 0.0, sz - 0.05), "chrome", segs=24, rsegs=4)  # band
    o.build()
    k.collision([], cylinders=[(0.19, sz, (0.0, 0.0, sz / 2))])


def _diner_chair(k: Kit, p: dict) -> None:
    """A chrome-tube diner chair with a red vinyl seat and back (GPU-21). The `Seat` marker at the cushion (``seat``,
    D's 0.47 m, as prop_chair_task, so the customers' roots and NpcSeatSpawns snaps do not move); no collision (the
    seated NPC owns the space, as prop_chair_task)."""
    seat = float(p["seat"])
    o = k.obj("Chair")
    a = o.part(bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.rod((sx * 0.2, sy * 0.2, 0.0), (sx * 0.19, sy * 0.19, seat - 0.06), 0.012, "chrome", segs=8)
            a.sphere(0.014, (sx * 0.2, sy * 0.2, 0.014), "chrome", segs=6, rings=3)
        a.rod((sx * 0.19, -0.19, seat - 0.06), (sx * 0.19, 0.19, seat - 0.06), 0.01, "chrome", segs=6)  # side rails
        a.rod((sx * 0.19, -0.2, seat - 0.06), (sx * 0.19, -0.23, 0.9), 0.011, "chrome", segs=8)  # back uprights
    a.rod((-0.19, -0.23, 0.9), (0.19, -0.23, 0.9), 0.011, "chrome", segs=8)
    soft = o.part(bevel=0.02, segments=2)
    soft.bx((-0.22, -0.22, seat - 0.07), (0.22, 0.22, seat), "rt_vinyl_red")
    soft.bx((-0.2, -0.25, 0.62), (0.2, -0.2, 0.86), "rt_vinyl_red")
    o.build()
    k.empty("Seat", (0.0, 0.0, seat))


def _diner_counter(k: Kit, p: dict) -> None:
    """A diner counter module (GPU-21) ``ln`` m along X, ``d`` m deep, the customers' front at +Y (Godot -Z): a grey
    laminate top at 0.90 m with a stainless nosing overhanging the front 0.22 m (knee room at the stools), the cream
    laminate front with a red band between stainless strips, a stainless kick; the staff side (-Y) a stainless back with
    an open shelf."""
    ln, d = float(p["ln"]), float(p["d"])
    hx, hy = ln / 2, d / 2
    fy = hy - 0.22  # the front panel under the overhang
    body = k.obj("Counter")
    cab = body.part(bevel=0.004)
    trim = body.part(bevel=0.0)
    cab.bx((-hx, -hy + 0.04, 0.0), (hx, fy - 0.06, 0.12), "steel")  # kick, recessed
    cab.bx((-hx, -hy, 0.12), (hx, fy - 0.012, 0.86), "rt_laminate_cream")
    cab.bx((-hx, fy - 0.012, 0.46), (hx, fy, 0.6), "rt_laminate_red")
    for z0 in (0.44, 0.6):
        trim.bx((-hx, fy - 0.012, z0), (hx, fy + 0.004, z0 + 0.02), "steel")
    for x in (-hx + 0.004, hx - 0.004):  # module joints
        trim.bx((x - 0.004, fy - 0.012, 0.12), (x + 0.004, fy + 0.004, 0.86), "steel")
    cab.bx((-hx, -hy, 0.86), (hx, hy - 0.02, 0.9), "laminate_grey")  # top
    trim.bx((-hx, hy - 0.02, 0.855), (hx, hy, 0.9), "steel")  # front nosing
    trim.bx((-hx, -hy, 0.12), (hx, -hy + 0.01, 0.86), "steel")  # staff-side back
    trim.bx((-hx + 0.05, -hy - 0.001, 0.4), (hx - 0.05, -hy + 0.3, 0.42), "steel")  # open shelf
    body.build()
    k.collision([((-hx, -hy, 0.0), (hx, hy, 0.9))])


def _diner_pendant(k: Kit, p: dict) -> None:
    """A diner pendant (GPU-21): a chrome canopy, a ``drop`` m stem and a red enamel dome shade over a warm lamp; the
    shade's rim ``drop`` + 0.2 m under the ceiling (2.28 m clear under DR's 3.0 m, where prop_pendant_brass reaches
    1.95 m)."""
    drop = float(p["drop"])
    o = k.obj("Pendant")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, -0.05), (0.07, -0.05), (0.08, -0.03), (0.08, 0.0), (0.0, 0.0)], "chrome", segs=16)
    a.rod((0.0, 0.0, -0.05), (0.0, 0.0, -drop), 0.008, "chrome", segs=6)
    z = -drop
    a.lathe([(0.0, z - 0.2), (0.19, z - 0.2), (0.185, z - 0.17), (0.15, z - 0.09), (0.08, z - 0.03),
             (0.035, z), (0.0, z)], "rt_enamel_red", segs=24)
    g = o.part(bevel=0.0)
    g.sphere(0.055, (0.0, 0.0, z - 0.21), "emit_warm", segs=12, rings=6)
    o.build()


def _menu_board(k: Kit, p: dict) -> None:
    """The diner's menu board (GPU-21): a black letter board ``w`` x ``h`` in a chrome frame, three columns, each a
    white header (BREAKFAST, BURGERS, PIE / COFFEE) over menu lines and price tabs. Wall mount: the back at y = 0,
    centred on the pivot, the front +Y."""
    w, h = float(p["w"]), float(p["h"])
    hw, hh = w / 2, h / 2
    o = k.obj("Board")
    b = o.part(bevel=0.0)
    b.bx((-hw, 0.0, -hh), (hw, 0.03, hh), "felt_dark")
    fr = o.part(bevel=0.004)
    for lo, hi in (((-hw - 0.03, 0.0, hh), (hw + 0.03, 0.045, hh + 0.03)),
                   ((-hw - 0.03, 0.0, -hh - 0.03), (hw + 0.03, 0.045, -hh)),
                   ((-hw - 0.03, 0.0, -hh), (-hw, 0.045, hh)), ((hw, 0.0, -hh), (hw + 0.03, 0.045, hh))):
        fr.bx(lo, hi, "chrome")
    t = o.part(bevel=0.0)
    cw = w / 3
    heads = (("BREAKFAST",), ("BURGERS",), ("PIE", "COFFEE"))
    lines = (0.62, 0.5, 0.7, 0.44, 0.58, 0.66, 0.4, 0.54)
    for c, words in enumerate(heads):
        # read from the front (+Y): the viewer's left is Blender +X, so the first column sits at +X
        cx = hw - cw * (c + 0.5)
        zt = hh - 0.14
        for i, word in enumerate(words):
            lettering(t, word, 0.07, cx, 0.03, zt - i * 0.29, "metal_white", stroke=0.011, depth=0.003, inlay=True,
                      spacing=0.2)
        row = 0
        z = zt - 0.08
        while z > -hh + 0.06:
            if len(words) > 1 and abs(z - (zt - 0.29 + 0.035)) < 0.06:
                z -= 0.075
                continue
            ln = lines[(row + c * 3) % len(lines)] * (cw - 0.2)
            x0 = cx + (cw - 0.2) / 2  # flush left as read: the line starts at the column's +X side
            t.bx((x0 - ln, 0.03, z), (x0, 0.033, z + 0.014), "metal_white")
            t.bx((cx - (cw - 0.2) / 2, 0.03, z), (cx - (cw - 0.2) / 2 + 0.07, 0.033, z + 0.014), "metal_white")
            z -= 0.075
            row += 1
    o.build()


def _diner_table(k: Kit, p: dict) -> None:
    """A diner table (GPU-21) ``w`` x ``d``, top at ``h`` (D's 0.74 m): cream laminate with a ribbed chrome band, on a
    chrome pedestal and cross foot (one under a square top, two under a long one)."""
    w, d, h = float(p["w"]), float(p["d"]), float(p["h"])
    o = k.obj("Table")
    a = o.part(bevel=0.003)
    a.bx((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h), "rt_laminate_cream")
    m = o.part(bevel=0.0)
    m.bx((-w / 2 - 0.004, -d / 2 - 0.004, h - 0.034), (w / 2 + 0.004, d / 2 + 0.004, h - 0.004), "chrome")
    xs = [0.0] if w < 1.1 else [-w / 2 + 0.35, w / 2 - 0.35]
    for x in xs:
        m.rod((x, 0.0, 0.03), (x, 0.0, h - 0.034), 0.035, "chrome", segs=12)
        m.cyl(0.1, 0.02, (x, 0.0, h - 0.044), "chrome", segs=16)
        for ang in (0.0, math.pi / 2):
            ex, ey = math.cos(ang) * min(0.3, d / 2 - 0.05), math.sin(ang) * min(0.3, d / 2 - 0.05)
            m.rod((x - ex, -ey, 0.02), (x + ex, ey, 0.02), 0.02, "chrome", segs=6, square=True)
    o.build()
    k.collision([((-w / 2, -d / 2, h - 0.03), (w / 2, d / 2, h)),
                 ((xs[0] - 0.04, -0.04, 0.0), (xs[-1] + 0.04, 0.04, h))])


def _c4_box(k: Kit, p: dict) -> None:
    """A 0.45 x 0.3 x 0.2 m ribbed olive charge case: the lid stood up at the back (-Y), two wrapped charges in the
    foam tray, latches at the front."""
    body = k.obj("Body")
    c = body.part(bevel=0.01, segments=2)
    t = body.part(bevel=0.002)
    c.bx((-0.225, -0.15, 0.0), (0.225, 0.15, 0.2), "polymer_olive")
    for rx in (-0.15, 0.0, 0.15):
        t.bx((rx - 0.01, -0.153, 0.03), (rx + 0.01, 0.153, 0.17), "polymer_olive")  # ribs
    t.bx((-0.2, -0.12, 0.19), (0.2, 0.12, 0.2), "fabric_charcoal")  # foam tray
    for cx in (-0.09, 0.09):
        t.bx((cx - 0.075, -0.1, 0.2), (cx + 0.075, 0.1, 0.245), "paper")  # charges
        t.bx((cx - 0.076, -0.02, 0.2), (cx + 0.076, 0.02, 0.247), "plastic_black")  # tape band
    c.bx((-0.225, -0.17, 0.2), (0.225, -0.15, 0.48), "polymer_olive")  # lid (up)
    t.bx((-0.06, -0.175, 0.42), (0.06, -0.17, 0.46), "metal_yellow")  # hazard label
    for lx in (-0.1, 0.1):
        t.bx((lx - 0.03, 0.15, 0.08), (lx + 0.03, 0.17, 0.14), "steel")  # latches
    body.build()


def _thermite_lock(k: Kit, p: dict) -> None:
    """The burning thermite on a 0.44 x 0.38 m door plate: a molten patch (the pivot at its bottom centre, on the
    plate's face) with slag runs below and a bright core; Blender +Y is the outside (Godot -Z, off the door)."""
    fire = k.obj("Fire")
    f = fire.part(bevel=0.003)
    f.bx((-0.2, 0.0, 0.03), (0.2, 0.012, 0.36), "emit_ember")  # the burning face
    f.bx((-0.12, 0.012, 0.1), (0.12, 0.024, 0.3), "emit_fire")  # the core
    for i, (x, ln) in enumerate(((-0.14, 0.03), (-0.05, 0.0), (0.06, 0.02), (0.15, 0.01))):
        f.bx((x - 0.012, 0.0, ln), (x + 0.012, 0.016, 0.06 + 0.01 * i), "emit_fire")  # slag runs
    fire.build()


def _barrier_arm(k: Kit, p: dict) -> None:
    """A car-park entry barrier, open: the motor post (0.35 x 0.3 x 1.1 m) at the pivot and the arm raised straight up
    from its hinge at 0.95 m in red / white bands (the entrance stays a walk route: an arm down across it would need a
    collider and close the marshal's and the police's way in), so it stands in the open, not under a soffit."""
    arm = float(p["arm"])
    body = k.obj("Body")
    b = body.part(bevel=0.01)
    t = body.part(bevel=0.002)
    b.bx((-0.175, -0.15, 0.0), (0.175, 0.15, 1.1), "metal_yellow")
    t.bx((-0.18, -0.155, 0.95), (0.18, 0.155, 1.0), "metal_dark")
    b.bx((0.175, -0.07, 0.88), (0.29, 0.07, 1.02), "metal_dark")  # the hinge boss on the lane side
    n = int(arm / 0.4)
    for i in range(n):
        z0 = 0.95 + i * arm / n
        b.bx((0.19, -0.04, z0), (0.27, 0.04, z0 + arm / n), "metal_red" if i % 2 == 0 else "metal_white")
    t.bx((-0.06, 0.15, 0.6), (0.06, 0.16, 0.75), "metal_red")  # lamp
    body.build()
    k.collision([((-0.175, -0.15, 0.0), (0.175, 0.15, 1.1))])


def _height_bar(k: Kit, p: dict) -> None:
    """A height-restriction portal: two posts ``span`` apart (X), the bar's underside at ``clear`` m, hazard bands
    and the clearance plate at the middle."""
    span, clear = float(p["span"]), float(p["clear"])
    hx = span / 2
    body = k.obj("Body")
    b = body.part(bevel=0.01)
    t = body.part(bevel=0.002)
    for sx in (-1, 1):
        b.bx((sx * hx - 0.1, -0.1, 0.0), (sx * hx + 0.1, 0.1, clear + 0.3), "metal_dark")
    n = max(4, int(span / 0.6))
    for i in range(n):
        x0 = -hx + 0.1 + i * (span - 0.2) / n
        x1 = -hx + 0.1 + (i + 1) * (span - 0.2) / n
        b.bx((x0, -0.08, clear), (x1, 0.08, clear + 0.25), "metal_yellow" if i % 2 == 0 else "metal_dark")
    t.bx((-0.4, 0.08, clear + 0.02), (0.4, 0.09, clear + 0.23), "metal_white")  # plate
    body.build()
    k.collision(
        [
            ((-hx - 0.1, -0.1, 0.0), (-hx + 0.1, 0.1, clear + 0.3)),
            ((hx - 0.1, -0.1, 0.0), (hx + 0.1, 0.1, clear + 0.3)),
            ((-hx, -0.08, clear), (hx, 0.08, clear + 0.25)),
        ]
    )


# ------------------------------------------------------------------------------------------- landmarks


def _lattice(p, lo: tuple, hi: tuple, axis: str, panel: float, r: float, key: str) -> None:
    """A square-section lattice box from lo to hi, its long side along ``axis`` ("X" or "Z"): four chords and a
    zig-zag brace on each face, one bay per ``panel`` m (square 4-sided bars, light on triangles)."""
    ax = 0 if axis == "X" else 2
    a0, a1 = lo[ax], hi[ax]
    n = max(1, int(round((a1 - a0) / panel)))
    others = [i for i in range(3) if i != ax]
    corners = [
        (lo[others[0]], lo[others[1]]),
        (hi[others[0]], lo[others[1]]),
        (hi[others[0]], hi[others[1]]),
        (lo[others[0]], hi[others[1]]),
    ]

    def pt(a: float, c: tuple) -> tuple:
        v = [0.0, 0.0, 0.0]
        v[ax] = a
        v[others[0]], v[others[1]] = c
        return tuple(v)

    for c in corners:
        p.rod(pt(a0, c), pt(a1, c), r, key, segs=4, square=True)
    for f in range(4):
        c0, c1 = corners[f], corners[(f + 1) % 4]
        for i in range(n):
            s0 = a0 + (a1 - a0) * i / n
            s1 = a0 + (a1 - a0) * (i + 1) / n
            p.rod(
                pt(s0, c0 if i % 2 == 0 else c1), pt(s1, c1 if i % 2 == 0 else c0), r * 0.6, key, segs=4, square=True
            )


def _tower_crane(k: Kit, p: dict) -> None:
    """Tanner's Reach tower crane (landmark 3; the G1 Crane boxes' geometry): ballast on the 4 x 4 m base pad, a
    1.6 m lattice mast to 29.6 m, the slewing cab, the 40 m jib along +X with its trolley and hook, the counter-jib
    with its ballast and the A-frame tie bars. The pivot at the mast's foot on the pad's top (y 1.4)."""
    body = k.obj("Body", location=(0.0, 0.0, -1.4))  # modelled on the 1.4 m pad: the pivot at its top
    lat = body.part(bevel=0.0)
    solid = body.part(bevel=0.01)
    trim = body.part(bevel=0.002)
    for bx in (-1.3, 1.3):  # base ballast
        solid.bx((bx - 0.6, -1.7, 1.4), (bx + 0.6, 1.7, 2.2), "concrete")
    solid.bx((-0.65, -1.0, 1.4), (0.65, 1.0, 1.5), "metal_yellow")  # foot plate (between the ballast)
    _lattice(lat, (-0.8, -0.8, 1.55), (0.8, 0.8, 29.6), "Z", 1.6, 0.06, "metal_yellow")
    solid.bx((-1.1, -1.1, 29.6), (1.1, 1.1, 30.4), "metal_yellow")  # slewing ring
    solid.bx((-4.0, -1.9, 30.4), (-1.2, 1.9, 31.2), "metal_yellow")  # machinery deck
    solid.bx((-1.1, 0.9, 29.0), (0.9, 2.6, 31.2), "metal_white")  # cab
    trim.bx((-1.12, 2.4, 29.6), (0.92, 2.62, 30.9), "glass_tinted")
    _lattice(lat, (0.8, -0.4, 31.0), (40.0, 0.4, 31.8), "X", 2.0, 0.05, "metal_yellow")  # jib
    _lattice(lat, (-14.0, -0.6, 31.0), (-0.8, 0.6, 31.8), "X", 2.0, 0.05, "metal_yellow")  # counter-jib
    for cx in (-13.0, -11.6):  # counterweights
        solid.bx((cx - 0.6, -0.9, 28.8), (cx + 0.6, 0.9, 31.0), "concrete")
    lat.rod((0.0, 0.0, 30.4), (0.0, 0.0, 36.0), 0.08, "metal_yellow", segs=4, square=True)  # A-frame
    lat.rod((0.0, 0.0, 36.0), (28.0, 0.0, 31.8), 0.025, "steel", segs=4)  # tie bars
    lat.rod((0.0, 0.0, 36.0), (-13.5, 0.0, 31.8), 0.025, "steel", segs=4)
    solid.bx((21.0, -0.5, 30.6), (22.4, 0.5, 31.0), "metal_dark")  # trolley
    lat.rod((21.7, 0.0, 30.6), (21.7, 0.0, 24.0), 0.012, "steel", segs=4)  # hoist rope
    solid.bx((21.45, -0.2, 23.4), (21.95, 0.2, 24.0), "safety_orange")  # hook block
    trim.bx((39.4, -0.15, 31.8), (39.8, 0.15, 32.1), "emit_led_red")  # tip light
    body.build()


def _girder(k: Kit, p: dict) -> None:
    """The Skyway's junction fascia (landmark 1): a 1.4 m steel plate girder face ``ln`` long on the deck's edge,
    flanges, stiffeners every 2 m, the name band with the cut-metal lettering. Wall mount: the back at y = 0, the
    front +Y (Godot -Z), the bottom at the pivot."""
    ln = float(p["ln"])
    hx = ln / 2
    body = k.obj("Body")
    pl = body.part(bevel=0.004)
    tr = body.part(bevel=0.002)
    pl.bx((-hx, 0.0, 0.0), (hx, 0.06, 1.4), "rt_skyway_green")  # web plate
    pl.bx((-hx, 0.0, 0.0), (hx, 0.25, 0.06), "rt_skyway_green")  # bottom flange
    pl.bx((-hx, 0.0, 1.34), (hx, 0.25, 1.4), "rt_skyway_green")  # top flange
    for i in range(int(ln / 2.0) + 1):
        x = -hx + i * ln / int(ln / 2.0)
        tr.bx((x - 0.012, 0.06, 0.06), (x + 0.012, 0.22, 1.34), "rt_skyway_green")  # stiffeners
    tr.bx((-3.6, 0.06, 0.5), (3.6, 0.075, 1.0), "metal_white")  # name band
    lettering(tr, p.get("text", "SKYWAY"), 0.34, 0.0, 0.075, 0.58, "metal_dark", stroke=0.05, depth=0.012, inlay=True)
    body.build()


def _clock_pillar(k: Kit, p: dict) -> None:
    """The plaza's clock pillar (landmark 2): a moulded plinth, a fluted cast-iron column, the four-faced clock head
    with lit dials at 5.0-5.8 m and a finial (6.0 m); the 0.8 m footprint of the G1 box."""
    body = k.obj("Body")
    c = body.part(bevel=0.006)
    t = body.part(bevel=0.002)
    c.bx((-0.4, -0.4, 0.0), (0.4, 0.4, 0.45), "metal_green")
    c.bx((-0.33, -0.33, 0.45), (0.33, 0.33, 0.6), "metal_green")
    c.lathe([(0.24, 0.6), (0.17, 0.85), (0.15, 4.6), (0.22, 4.8), (0.3, 5.0)], "metal_green", segs=16)
    for i in range(8):  # flutes
        a = i * math.pi / 4
        t.rod(
            (0.155 * math.cos(a), 0.155 * math.sin(a), 0.9),
            (0.155 * math.cos(a), 0.155 * math.sin(a), 4.5),
            0.012,
            "metal_green",
            segs=4,
        )
    c.bx((-0.4, -0.4, 5.0), (0.4, 0.4, 5.8), "metal_green")  # clock head
    for ax, sx in (("Y", 1), ("Y", -1), ("X", 1), ("X", -1)):
        if ax == "Y":
            t.cyl(0.3, 0.02, (0.0, sx * 0.41, 5.4), "emit_clock", axis="Y", segs=20)
            t.bx((-0.012, sx * 0.425 - 0.004, 5.4), (0.012, sx * 0.425 + 0.004, 5.62), "metal_dark")
        else:
            t.cyl(0.3, 0.02, (sx * 0.41, 0.0, 5.4), "emit_clock", axis="X", segs=20)
            t.bx((sx * 0.425 - 0.004, -0.012, 5.4), (sx * 0.425 + 0.004, 0.012, 5.6), "metal_dark")
    c.lathe([(0.45, 5.8), (0.3, 5.9), (0.08, 5.95), (0.0, 6.0)], "metal_green", segs=12)  # cap + finial
    body.build()


def _signal(k: Kit, p: dict) -> None:
    """A junction traffic signal: a 4 m pole, the 3-aspect head on the pole and one on a 3 m mast arm over the road
    (+X); dark lenses with `Red` / `Amber` / `Green` lit lens nodes (the [signals] read: the mission shows one per
    head). Front (+Y, Godot -Z) toward the traffic; the pivot at the footprint centre, the pole at
    x = -SIGNAL_POLE."""
    o = -SIGNAL_POLE
    body = k.obj("Body")
    b = body.part(bevel=0.006)
    t = body.part(bevel=0.002)
    b.cyl(0.08, 4.0, (o, 0.0, 2.0), "metal_dark", segs=12)
    b.cyl(0.14, 0.12, (o, 0.0, 0.06), "metal_dark", segs=12)
    b.rod((o, 0.0, 5.2), (o + 3.0, 0.0, 5.2), 0.05, "metal_dark", segs=8)
    b.rod((o, 0.0, 4.0), (o, 0.0, 5.3), 0.07, "metal_dark", segs=10)
    heads = [(o, 0.16, 2.3), (o + 2.8, 0.16, 4.3)]
    for hx, hy, hz in heads:
        b.bx((hx - 0.17, hy - 0.12, hz), (hx + 0.17, hy + 0.12, hz + 0.9), "metal_dark")
        for i in range(3):
            z = hz + 0.75 - i * 0.3
            t.cyl(0.1, 0.02, (hx, hy + 0.125, z), "plastic_black", axis="Y", segs=12)
            t.bx((hx - 0.13, hy + 0.12, z + 0.1), (hx + 0.13, hy + 0.2, z + 0.12), "metal_dark")  # visor
    body.build()
    for name, i, key in (("Red", 0, "emit_led_red"), ("Amber", 1, "emit_amber"), ("Green", 2, "emit_led_green")):
        o = k.obj(name)
        lp = o.part(bevel=0.0)
        for hx, hy, hz in heads:
            lp.cyl(0.095, 0.01, (hx, hy + 0.14, hz + 0.75 - i * 0.3), key, axis="Y", segs=12)
        o.build()


def _scaffold(k: Kit, p: dict) -> None:
    """A scaffold bay ``w`` wide, ``h`` tall and 0.06 m deep (the G1 cladding / edge-protection boxes): standards at
    the ends, ledgers every 2 m (or the guard rail at 1.0 m and the mid rail at 0.5 m for edge protection), a toe board
    and the debris netting. Floor pivot, the face along X."""
    w, h = float(p["w"]), float(p["h"])
    hx = w / 2
    body = k.obj("Body")
    tb = body.part(bevel=0.0)
    for sx in (-1, 1):
        tb.rod((sx * (hx - 0.03), 0.0, 0.0), (sx * (hx - 0.03), 0.0, h), 0.024, "steel_galv", segs=6)
    rails = [h - 0.05, h * 0.5] if h < 2.0 else [z for z in (2.0, 4.0) if z < h] + [h - 0.05]
    for z in rails:
        tb.rod((-hx, 0.0, z), (hx, 0.0, z), 0.024, "steel_galv", segs=6)
    tb.bx((-hx + 0.03, -0.02, 0.0), (hx - 0.03, 0.02, 0.15), "wood_pine")  # toe board
    if p.get("net"):
        tb.bx((-hx + 0.05, -0.008, 0.16), (hx - 0.05, 0.008, h - 0.1), "net_green")
    body.build()


def _clutter(k: Kit, p: dict) -> None:
    """Site clutter (one generator): ``style`` formwork (a 2.4 x 1.2 x 1.2 m stack of ply panels on bearers),
    rebar (a 6 m bundle on two timbers) or mixer (a mortar mixer on its stand)."""
    body = k.obj("Body")
    b = body.part(bevel=0.006)
    t = body.part(bevel=0.002)
    st = p["style"]
    if st == "formwork":
        for by in (-0.45, 0.45):
            b.bx((-1.2, by - 0.06, 0.0), (1.2, by + 0.06, 0.1), "wood_pine")
        for i in range(10):
            z = 0.1 + i * 0.105
            b.bx((-1.18 + (i % 2) * 0.02, -0.6, z), (1.18 + (i % 2) * 0.02, 0.6, z + 0.1), "wood_oak")
        t.bx((-0.03, -0.62, 0.1), (0.03, 0.62, 1.2), "metal_dark")  # strap
    elif st == "rebar":
        for by in (-2.0, 2.0):
            b.bx((-0.3, by - 0.06, 0.0), (0.3, by + 0.06, 0.1), "wood_pine")
        for i in range(12):
            x = -0.2 + (i % 6) * 0.08
            z = 0.12 + (i // 6) * 0.07
            t.rod((x, -3.0, z), (x, 3.0, z), 0.016, "metal_rust", segs=6)
        t.bx((-0.25, -1.0, 0.1), (0.25, -0.96, 0.27), "metal_dark")
        t.bx((-0.25, 0.96, 0.1), (0.25, 1.0, 0.27), "metal_dark")
    else:
        b.bx((-0.4, -0.5, 0.0), (0.4, 0.5, 0.08), "metal_red")
        for sx in (-1, 1):
            t.rod((sx * 0.35, 0.0, 0.08), (sx * 0.3, 0.0, 0.75), 0.03, "metal_red", segs=6)
            t.cyl(0.18, 0.08, (sx * 0.42, 0.35, 0.18), "rubber", axis="X", segs=12)
        b.lathe([(0.0, 0.55), (0.32, 0.6), (0.4, 0.95), (0.28, 1.25), (0.2, 1.3)], "metal_orange", segs=16)
        b.bx((0.3, -0.15, 0.6), (0.5, 0.15, 0.85), "metal_dark")  # motor
    body.build()


def _rail_track(k: Kit, p: dict) -> None:
    """A ``ln`` m panel of standard-gauge track along Y on its ballast shoulder: sleepers every 0.65 m, two rails
    (1.435 m gauge), the ballast bed. Dressing on the rail bank (no collision; nobody walks there)."""
    ln = float(p["ln"])
    hy = ln / 2
    body = k.obj("Body")
    b = body.part(bevel=0.0)
    r = body.part(bevel=0.002)
    b.profile_y([(-1.6, 0.0), (1.6, 0.0), (1.2, 0.25), (-1.2, 0.25)], -hy, hy, "concrete")  # ballast
    n = int(ln / 0.65)
    for i in range(n):
        y = -hy + 0.325 + i * (ln - 0.65) / max(1, n - 1)
        b.bx((-1.25, y - 0.12, 0.25), (1.25, y + 0.12, 0.4), "concrete_light")
    for sx in (-1, 1):
        x = sx * 0.7175
        r.bx((x - 0.035, -hy, 0.4), (x + 0.035, hy, 0.43), "steel")
        r.bx((x - 0.008, -hy, 0.43), (x + 0.008, hy, 0.53), "steel")
        r.bx((x - 0.035, -hy, 0.53), (x + 0.035, hy, 0.56), "steel_bare")
    body.build()


def _neon_sign(k: Kit, p: dict) -> None:
    """The diner's neon (the prop_neon_vossberg family, text and colour as params): ``text`` on a dark raceway and
    ``line2`` under it, smaller. Wall mount: the back at y = 0, centred on the pivot."""
    o = k.obj("Neon")
    rc = o.part(bevel=0.006, segments=2)
    tube = o.part(bevel=0.0)
    key = p.get("key", "emit_neon_magenta")
    width = lettering(
        tube,
        p["text"],
        0.5,
        0.0,
        0.1,
        -0.05,
        key,
        stroke=0.026,
        depth=0.0,
        round_tube=True,
        spacing=0.18,
        res=3,
        tube_segs=8,
    )
    w2 = (
        lettering(
            tube,
            p.get("line2", ""),
            0.24,
            0.0,
            0.1,
            -0.4,
            p.get("key2", key),
            stroke=0.018,
            depth=0.0,
            round_tube=True,
            spacing=0.2,
            res=2,
            tube_segs=6,
        )
        if p.get("line2")
        else 0.0
    )
    rw = max(width, w2) / 2 + 0.08
    rc.bx((-rw, 0.0, -0.46), (rw, 0.08, 0.5), "metal_dark")
    for i in range(7):
        x = -rw + 0.06 + i * (2 * rw - 0.12) / 6
        rc.rod((x, 0.08, 0.0), (x, 0.1, 0.0), 0.006, "steel", segs=6)
    o.build()


POLE_SIGN_H = 6.4      # the cabinet top (m); the cabinet is 1.8 m tall, its underside 4.6 m (over a 3.6 m truck)
POLE_SIGN_D = 0.36     # cabinet depth (Y)


def _pole_sign(k: Kit, p: dict) -> None:
    """A street pole sign (two-sided): a round pole on a base plate, a dark cabinet on it, ``text`` and ``line2`` in
    neon on both faces, each read from its own side (the -Y face is drawn in a frame turned 180 deg about Z). Pivot at
    the pole's foot; the faces are +Y / -Y (Godot -Z / +Z), so a yaw of 90 reads along a street running along X."""
    top, bot = POLE_SIGN_H, POLE_SIGN_H - 1.8
    width = 0.0
    faces = [k.obj("Body"), k.obj("Back", parent=k.empty("BackFrame", rotation=(0.0, 0.0, math.pi)))]
    for o in faces:
        tube = o.part(bevel=0.0)
        w1 = lettering(tube, p["text"], 0.62, 0.0, POLE_SIGN_D / 2, bot + 0.85, p.get("key", "emit_neon_magenta"),
                       stroke=0.03, depth=0.0, round_tube=True, spacing=0.18, res=3, tube_segs=8)
        w2 = 0.0
        if p.get("line2"):
            w2 = lettering(tube, p["line2"], 0.26, 0.0, POLE_SIGN_D / 2, bot + 0.25, p.get("key2", "emit_mint"),
                           stroke=0.02, depth=0.0, round_tube=True, spacing=0.2, res=2, tube_segs=6)
        width = max(width, w1, w2)
    hw = width / 2 + 0.2
    b = faces[0].part(bevel=0.006)
    b.cyl(0.11, bot + 0.1, (0.0, 0.0, (bot + 0.1) / 2), "metal_dark", segs=14)
    b.cyl(0.24, 0.03, (0.0, 0.0, 0.015), "metal_dark", segs=14)
    b.bx((-hw, -POLE_SIGN_D / 2, bot), (hw, POLE_SIGN_D / 2, top), "metal_dark")
    b.bx((-hw - 0.04, -POLE_SIGN_D / 2 - 0.02, top - 0.06), (hw + 0.04, POLE_SIGN_D / 2 + 0.02, top), "metal_yellow")
    for o in faces:
        o.build()


def _heli_pad(k: Kit, p: dict) -> None:
    """The car-park roof's heli-pad marking (§3c "heli pad", a painted decal as a 4 mm mesh, so it lies 4 mm over the
    deck's finish, outside the z-fight plane tolerance): the touchdown ring (``r`` m) in yellow and the white H."""
    r = float(p["r"])
    body = k.obj("Body")
    m = body.part(bevel=0.0)
    n = 40
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 1) / n
        ri, ro = r - 0.2, r + 0.2
        m.slab(
            [
                (ri * math.cos(a0), ri * math.sin(a0)),
                (ro * math.cos(a0), ro * math.sin(a0)),
                (ro * math.cos(a1), ro * math.sin(a1)),
                (ri * math.cos(a1), ri * math.sin(a1)),
            ],
            0.0,
            0.004,
            "metal_yellow",
        )
    for sx in (-1, 1):
        m.bx((sx * 1.0 - 0.25, -1.5, 0.0), (sx * 1.0 + 0.25, 1.5, 0.004), "metal_white")
    m.bx((-0.75, -0.25, 0.0), (0.75, 0.25, 0.004), "metal_white")
    body.build()


def _bay_lines(k: Kit, p: dict) -> None:
    """Parking bay lines (a painted 4 mm mesh): ``n`` + 1 white lines ``depth`` m long along Y on a ``pitch`` m pitch
    along X, joined by the line across their back (-Y); the bays centred on the pivot."""
    n, pitch, depth = int(p["n"]), float(p["pitch"]), float(p["depth"])
    hx, hy = n * pitch / 2, depth / 2
    body = k.obj("Body")
    m = body.part(bevel=0.0)
    for i in range(n + 1):
        x = -hx + i * pitch
        m.bx((x - 0.05, -hy, 0.0), (x + 0.05, hy, 0.004), "metal_white")
    m.bx((-hx + 0.05, -hy, 0.0), (hx - 0.05, -hy + 0.1, 0.004), "metal_white")
    body.build()


def _hoarding_graphic(k: Kit, p: dict) -> None:
    """The site hoarding's graphic board (``w`` x 1.4 m, 12 mm ply on the hoarding face): a dark green field, a white
    band with the developer's name in cut lettering, a safety-yellow strip at the foot. Wall mount: the back at y = 0,
    centred on the pivot."""
    w = float(p["w"])
    hx = w / 2
    body = k.obj("Body")
    b = body.part(bevel=0.004)
    t = body.part(bevel=0.0)
    b.bx((-hx, 0.0, -0.7), (hx, 0.012, 0.7), "metal_green")
    t.bx((-hx + 0.15, 0.012, -0.05), (hx - 0.15, 0.016, 0.45), "metal_white")
    t.bx((-hx + 0.15, 0.012, -0.6), (hx - 0.15, 0.016, -0.45), "metal_yellow")
    lettering(t, p["text"], 0.32, 0.0, 0.016, 0.04, "metal_dark", stroke=0.045, depth=0.006, inlay=True)
    body.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
