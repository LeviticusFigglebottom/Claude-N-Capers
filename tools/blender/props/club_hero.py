"""Afterhours ("the Velvet") hero props (ENV D, D-165 / D-159 style; footprints from ENV C's G1 greybox,
afterhours_layout_content.gd FURNITURE). Original designs in the picture house's deco language (lacquer, brass, velvet),
library materials only; the VELVET mark is the club's own invented lettering. C keeps the colliders (greybox boxes, RT's
PROP_ART pattern), the LED floor, the bar counters, the stage riser, the loose bottles / glasses (MultiMesh) and the
ClubLights fixtures: these are the visual bodies.

Blender +Y = Godot -Z = the prop's front. Floor props pivot bottom-centre; the hanging pieces (ball, truss) pivot at
their ceiling / hanging point with everything below z = 0.

* ``prop_ah_dj_booth`` (DJBooth, 3.0 x 1.0 x 1.0): a black lacquer console with brass deco fins and the VELVET mark in
  magenta neon on the crowd-side fascia (+Y), a raised front parapet, two decks and a mixer on the deck (z 1.0), a
  laptop on a stand. The -X end of the deck stays flat and clear (C's kc_dj_booth pickup lies there once the booth
  is turned to face the crowd). Marker ``DJStand``: behind the console (Blender -Y), facing it.
* ``prop_ah_back_bar`` (MainBarBack, 7.0 x 0.6, cabinet 1.0): a walnut cabinet with a dark stone top; above it, on the
  wall, a brass-framed smoked mirror, three glass shelves with warm LED lips and the bottle wall (ONE ``Bottles``
  mesh, per the perf table), and a small neon VELVET sign over the mirror.
* ``prop_ah_booth`` / ``prop_ah_booth_vip`` (BoothW1/W2/E1, VIPBooth1-3: 2.4 x 0.6, back 1.1): a straight channel-tufted
  velvet banquette on a plinth with a brass kick and cap rail (lounge: charcoal velvet; VIP: red velvet with a fuller
  brass rail). Markers ``Seat0..2`` at the seat front, bottom (z 0), facing out (+Y).
* ``prop_ah_booth_corner`` (BoothReserved, 1.6 x 1.6): an L banquette (backs on -Y and +X) round a pedestal table.
  Markers ``Seat0..3``.
* ``prop_ah_mirror_ball``: a 0.48 m faceted mirror ball (40 self-lit glint tiles) on a motor and drop rod under a brass ceiling rose. Marker
  ``Mount`` = the ceiling point (origin); the ball centre hangs 0.55 m below it.
* ``prop_ah_truss_2m``: a 2 m black box truss (0.29 m square) with two moving-head fixture bodies hung under it.
  Markers ``LightSocket0..1`` at the heads' lenses, pointing down (C's SpotLights parent there); the origin is the
  truss top centre (hanging point).

G2 batch 1 (LEAD 2026-10-23, C's FURNITURE boxes):

* ``prop_ah_speaker_stack`` (SpeakerStackW/E, 1.2 x 1.0, 2.2 high): a black lacquer sub cabinet (two 18" cones) under a
  mid / high top box (two 10" cones and a horn), brass corner caps, a magenta LED status pip; the grilles face +Y.
* ``prop_ah_vip_sofa`` (VIPSofa, 3.0 x 0.9, back 0.9): a deco sofa in red velvet, a tufted back, rolled arms, a
  brass plinth band on brass feet. Markers ``Seat0..2`` at the seat front, facing out (+Y).
* ``prop_ah_vip_coffee_table`` (VIPCoffeeTable, 1.2 x 0.6, top 0.40): a dark stone top on a brass edge band, four slim
  brass legs (the floor shows under it), a brass tray with two coupes.
* ``prop_ah_bottle_table`` (VIPTable2, 0.8 x 0.6, 0.75 high): the bottle-service table: a stone top on brass legs, an
  ice bucket with two bottles in it, a sparkler stick on the hottest one, two coupes.
* ``prop_ah_high_table`` (HighTable1/2, 0.7 round, 1.05 high): a poseur table, dark stone top on a brass column and a
  weighted brass base, a candle cup.
* ``prop_ah_private_shelving`` (PrivateShelving, 3.0 x 0.6, 2.0 high; C turns it 90 deg to the wall): dark steel
  shelving, four shelves of locked cash boxes and document boxes, padlocks in brass.

G2 batch 2 (back of house dressing, C's FURNITURE boxes):

* ``prop_ah_keg_trolley`` (KegTrolley, 0.6 x 0.6, 1.0 high): a red steel hand truck with a 50 l keg strapped on its
  toe plate.
* ``prop_ah_keg_rack`` (KegRack, 2.4 x 0.8, 1.6 high; C turns it 90 deg): a galvanised two-tier rack of standing kegs,
  the couplers on top.
* ``prop_ah_bottle_bank`` (BottleBank, 1.2 x 0.9, 1.2 high): a green 1100 l wheelie bin for empties, lid shut, GLASS
  stencilled on the front.
* ``prop_ah_crates`` (CratesG13W/E, 1.2 x 0.7, 1.4 high): columns of plastic bottle crates (each column one colour,
  red with one yellow), the top crates of the shorter columns loaded with empties.
* ``prop_ah_flight_cases`` (FlightCases, 1.6 x 0.8, 1.0 high): two black road cases with aluminium edges, ball
  corners and butterfly latches, a smaller one stacked on the big one, a VELVET stencil.

G2 batch 3 (C's club list):

* ``prop_ah_bar_counter_2m`` (MainBarCounter / EastBarCounter / VIPBarCounter, modular: 2.0 x 0.6, top 1.05): the
  customer side (+Y) a black lacquer front with brass deco fins, a warm LED strip under the stone top's lip, a brass
  footrail on brackets, a recessed brass kick; the bartender side (-Y) open with an under-counter shelf. Tiles end to
  end along X (C turns it to its bar).
* ``prop_ah_bar_counter_end`` (0.6 x 0.6, top 1.05): the end cap in the same profile, the footrail returning round it.
* ``prop_ah_box_office_counter`` (BoxOfficeCounter, 4.4 x 0.6, top 1.05): a walnut front with brass bands and a stone
  top, a recessed cash tray at the window end (-X), a call bell, a ticket roll, a card reader; the cloakroom hatch end
  (+X) has a brass coat-check ticket rail.
* ``prop_ah_marquee`` (the entrance marquee, 12.0 x 2.8): a black canopy with a lit fascia, VELVET in magenta neon on
  the street side (+Y), rows of lamp bulbs along the fascia, a grid of bulbs on the soffit. Pivot = the wall-side
  soffit centre (the canopy rises 0.9 above it and reaches 2.8 out along +Y): place it at the soffit height (~4.0).
* ``prop_ah_ice_bucket`` (small loot BottleServiceU1/U2): an ice bucket with a bottle in it, pivot at its base.
* ``prop_ah_tip_jar`` (TipJarCloak): a glass jar with folded notes and a plain ivory label.
* ``prop_ah_till`` (TillMainBar / TillEastBar / TillVIPBar / TillBoxOffice): a POS till: cash drawer, a tilted touch
  screen on a stalk, a receipt printer; the operator side is -Y.

G2 batch 4 (back of house, C's list). Wall pieces: pivot ``Mount`` at the back centre, the back flush with the wall
(y = 0), everything in +Y; the catalog ``z`` is the centre height.

* ``prop_ah_bulb_mirror`` (G11 green room, 1.2 x 0.9, centre 1.5): a dressing-room mirror in a black frame ringed with
  lamp bulbs, a narrow shelf under it with a make-up case and a water bottle.
* ``prop_ah_cigarette_machine`` (G7 alcove, 0.75 x 0.5, 1.8 high, floor): a vintage cabinet machine in oxblood and
  chrome-grey, a lit display window of packet faces, a row of pull knobs, a coin plate and a tray.
* ``prop_ah_projector`` (U5, 0.5 x 0.9, 1.4 high, floor): an old 35 mm projector on its pedestal: twin reel arms with
  reels, the lamp house, the lens facing +Y (Godot -Z).
* ``prop_ah_radio_charger`` (G24, 0.6 x 0.15 x 0.25, centre 1.2): a wall gang charger, six handsets in their cups,
  green charge LEDs.
* ``prop_ah_clock_in`` (G25, 0.75 x 0.12 x 0.6, centre 1.4): the clock-in terminal (keypad, display, card slot) with a
  card rack of staff cards beside it (+X), one prop.
* ``prop_ah_key_hooks`` (G12, 0.4 x 0.08 x 0.5, centre 1.5): a small steel key cabinet, its door open to the left,
  three rows of hooks with keys and tags.
"""

from __future__ import annotations

import math

from _pb import Kit, lettering

TRI_BUDGET = 20000
_FLOOR = {"place": "floor", "group": "afterhours", "pin_only": True}
_HUNG = {"place": "ceiling", "group": "afterhours", "pin_only": True}
_ON = {"place": "on", "group": "afterhours", "pin_only": True}

#: wall pieces (build.py reads the table from plain assignments, no functions): the catalog z is the centre height
_WALL = {"place": "wall_mount", "group": "afterhours", "pin_only": True}
VARIANTS = {
    "prop_ah_dj_booth": {"fn": "dj_booth", "cat": dict(_FLOOR, kind="dj_booth", surface="wood")},
    "prop_ah_back_bar": {"fn": "back_bar", "cat": dict(_FLOOR, kind="back_bar", surface="wood")},
    "prop_ah_booth": {"fn": "booth", "vip": False, "cat": dict(_FLOOR, kind="booth", surface="fabric")},
    "prop_ah_booth_vip": {"fn": "booth", "vip": True, "cat": dict(_FLOOR, kind="booth", surface="fabric")},
    "prop_ah_booth_corner": {"fn": "booth_corner", "cat": dict(_FLOOR, kind="booth", surface="fabric")},
    "prop_ah_mirror_ball": {"fn": "mirror_ball", "cat": dict(_HUNG, kind="mirror_ball", surface="metal")},
    "prop_ah_truss_2m": {"fn": "truss", "cat": dict(_HUNG, kind="truss", surface="metal")},
    # G2 batch 1
    "prop_ah_speaker_stack": {"fn": "speaker_stack", "cat": dict(_FLOOR, kind="speaker", surface="wood")},
    "prop_ah_vip_sofa": {"fn": "vip_sofa", "cat": dict(_FLOOR, kind="sofa", surface="fabric")},
    "prop_ah_vip_coffee_table": {"fn": "vip_coffee_table", "cat": dict(_FLOOR, kind="table", surface="wood")},
    "prop_ah_bottle_table": {"fn": "bottle_table", "cat": dict(_FLOOR, kind="table", surface="stone")},
    "prop_ah_high_table": {"fn": "high_table", "cat": dict(_FLOOR, kind="table", surface="stone")},
    "prop_ah_private_shelving": {"fn": "private_shelving", "cat": dict(_FLOOR, kind="shelving", surface="metal")},
    # G2 batch 2
    "prop_ah_keg_trolley": {"fn": "keg_trolley", "cat": dict(_FLOOR, kind="trolley", surface="metal")},
    "prop_ah_keg_rack": {"fn": "keg_rack", "cat": dict(_FLOOR, kind="shelving", surface="metal")},
    "prop_ah_bottle_bank": {"fn": "bottle_bank", "cat": dict(_FLOOR, kind="bin", surface="plastic")},
    "prop_ah_crates": {"fn": "crates", "cat": dict(_FLOOR, kind="crate", surface="plastic")},
    "prop_ah_flight_cases": {"fn": "flight_cases", "cat": dict(_FLOOR, kind="crate", surface="wood")},
    # G2 batch 3
    "prop_ah_bar_counter_2m": {"fn": "bar_counter", "end": False, "cat": dict(_FLOOR, kind="counter", surface="wood")},
    "prop_ah_bar_counter_end": {"fn": "bar_counter", "end": True, "cat": dict(_FLOOR, kind="counter", surface="wood")},
    "prop_ah_box_office_counter": {"fn": "box_office_counter", "cat": dict(_FLOOR, kind="counter", surface="wood")},
    "prop_ah_marquee": {"fn": "marquee", "cat": dict(_WALL, z=4.0, kind="sign", surface="metal")},
    "prop_ah_ice_bucket": {"fn": "ice_bucket", "cat": dict(_ON, kind="loot_visual", surface="metal")},
    "prop_ah_tip_jar": {"fn": "tip_jar", "cat": dict(_ON, kind="loot_visual", surface="glass")},
    "prop_ah_till": {"fn": "till", "cat": dict(_ON, kind="loot_visual", surface="plastic")},
    # G2 batch 4
    "prop_ah_bulb_mirror": {"fn": "bulb_mirror", "cat": dict(_WALL, z=1.5, kind="mirror", surface="glass")},
    "prop_ah_cigarette_machine": {"fn": "cigarette_machine", "cat": dict(_FLOOR, kind="vending", surface="metal")},
    "prop_ah_projector": {"fn": "projector", "cat": dict(_FLOOR, kind="projector", surface="metal")},
    "prop_ah_radio_charger": {"fn": "radio_charger", "cat": dict(_WALL, z=1.2, kind="charger", surface="plastic")},
    "prop_ah_clock_in": {"fn": "clock_in", "cat": dict(_WALL, z=1.4, kind="terminal", surface="plastic")},
    "prop_ah_key_hooks": {"fn": "key_hooks", "cat": dict(_WALL, z=1.5, kind="key_cabinet", surface="metal")},
}

LACQUER = "plastic_black"
MAGENTA = "emit_neon_magenta_sign"  # C e476b33b: 1.8, the hue holds (the shared 6.0 key clips to white)


def _hash(i: int) -> float:
    """A deterministic 0..1 value per index (no RNG in asset scripts)."""
    return ((i * 2654435761) % 1000) / 1000.0


# ------------------------------------------------------------------------------------------------- DJ booth

def _dj_booth(k: Kit, p: dict) -> None:
    hx, hy, top = 1.5, 0.5, 1.0
    body = k.obj("Body")
    c = body.part(bevel=0.006)
    t = body.part(bevel=0.0015)
    c.bx((-hx, -hy, 0.0), (hx, hy - 0.06, top - 0.04), LACQUER)                          # the console
    c.bx((-hx - 0.01, -hy - 0.01, top - 0.04), (hx + 0.01, hy - 0.05, top), "walnut")     # deck slab
    c.bx((-hx, hy - 0.06, 0.0), (hx, hy, top + 0.12), LACQUER)                            # crowd-side parapet
    t.bx((-hx - 0.004, hy - 0.004, top + 0.10), (hx + 0.004, hy + 0.006, top + 0.13), "brass")  # its brass cap
    t.bx((-hx - 0.004, hy - 0.004, 0.0), (hx + 0.004, hy + 0.008, 0.05), "brass")         # kick
    # the fascia: brass deco fins either side of the mark, a brass band over them
    for i in range(6):
        for sx in (-1, 1):
            x = sx * (0.95 + i * 0.09)
            t.bx((x - 0.012, hy, 0.12), (x + 0.012, hy + 0.018, 0.82 - i * 0.05), "brass")
    t.bx((-hx + 0.05, hy, 0.88), (hx - 0.05, hy + 0.012, 0.91), "brass")
    t.bx((-0.78, hy, 0.30), (0.78, hy + 0.006, 0.70), "metal_dark")                       # the mark's panel
    lettering(t, "VELVET", 0.22, 0.0, hy + 0.006, 0.39, MAGENTA, stroke=0.016, depth=0.012, round_tube=True)
    # the gear on the deck, on the DJ's (-Y) half; the -X end stays flat for the keycard
    z = top
    for x in (-0.62, 0.58):                                                               # two decks
        t.bx((x - 0.17, -0.40, z), (x + 0.17, 0.02, z + 0.06), "plastic_black")
        t.cyl(0.11, 0.008, (x, -0.21, z + 0.064), "metal_grey", segs=20)                  # platter
        t.cyl(0.03, 0.006, (x, -0.21, z + 0.071), MAGENTA, segs=12)                       # centre ring
        t.bx((x + 0.10, -0.38, z + 0.06), (x + 0.15, -0.30, z + 0.066), "emit_screen")
    t.bx((-0.17, -0.40, z), (0.17, 0.02, z + 0.08), "metal_dark")                          # the mixer
    for i in range(4):
        t.bx((-0.13 + i * 0.075, -0.30, z + 0.08), (-0.10 + i * 0.075, -0.06, z + 0.085), "plastic_grey")
        t.cyl(0.012, 0.02, (-0.115 + i * 0.075, -0.34, z + 0.09), "rubber", segs=8)
    # laptop on a stand at the +X end
    t.bx((1.02, -0.36, z), (1.06, -0.10, z + 0.12), "steel_bare")                          # stand
    t.bx((0.90, -0.40, z + 0.12), (1.26, -0.12, z + 0.135), "metal_grey")                   # base
    t.bx((0.90, -0.42, z + 0.135), (1.26, -0.40, z + 0.36), "metal_grey")                   # lid
    t.bx((0.92, -0.40, z + 0.15), (1.24, -0.398, z + 0.345), "emit_screen")                 # screen (DJ side)
    body.build()
    k.empty("DJStand", (0.0, -hy - 0.30, 0.0))


# ------------------------------------------------------------------------------------------------- back bar

#: liquors read through coloured glass: mostly opaque keys so the wall reads under the club light, a few clear ones
_BOTTLE_KEYS = ("art_ochre", "serum_green", "metal_green", "paint_ivory", "plastic_black", "art_rust", "glass_teal",
                "art_ochre", "glass_tinted")


def _back_bar(k: Kit, p: dict) -> None:
    hx, hy, cab = 3.5, 0.3, 1.0
    body = k.obj("Body")
    c = body.part(bevel=0.005)
    t = body.part(bevel=0.0015)
    c.bx((-hx, -hy, 0.0), (hx, hy - 0.02, cab - 0.04), "walnut")                          # cabinet
    c.bx((-hx - 0.01, -hy, cab - 0.04), (hx + 0.01, hy + 0.01, cab), "stone_dark")       # top
    t.bx((-hx, hy - 0.02, 0.0), (hx, hy + 0.004, 0.08), "brass")                           # kick
    for i in range(10):                                                                     # door panels
        x0 = -hx + 0.05 + i * 0.69
        t.bx((x0, hy - 0.02, 0.14), (x0 + 0.64, hy - 0.012, cab - 0.10), "wood_dark")
        t.bx((x0 + 0.30, hy - 0.012, 0.52), (x0 + 0.34, hy, 0.62), "brass")                # pulls
    # the wall above: a smoked mirror in a brass frame, three glass shelves with warm LED lips
    wy = -hy + 0.02
    t.bx((-hx + 0.08, wy, 1.05), (hx - 0.08, wy + 0.01, 2.62), "chrome")                   # smoked mirror
    for x0, x1, z0, z1 in ((-hx + 0.04, hx - 0.04, 2.62, 2.68), (-hx + 0.04, hx - 0.04, 1.0, 1.05),
                           (-hx + 0.04, -hx + 0.08, 1.0, 2.68), (hx - 0.08, hx - 0.04, 1.0, 2.68)):
        t.bx((x0, wy, z0), (x1, wy + 0.03, z1), "brass")
    shelves = (1.38, 1.78, 2.18)
    for z in shelves:
        t.bx((-hx + 0.10, wy + 0.01, z - 0.012), (hx - 0.10, wy + 0.26, z), "glass")
        t.bx((-hx + 0.10, wy + 0.25, z - 0.03), (hx - 0.10, wy + 0.27, z - 0.012), "emit_warm")
    for x in (-2.35, -1.17, 0.0, 1.17, 2.35):                                               # brass brackets
        for z in shelves:
            t.bx((x - 0.01, wy + 0.01, z - 0.10), (x + 0.01, wy + 0.24, z - 0.012), "brass")
    lettering(t, "VELVET", 0.16, 0.0, wy + 0.03, 2.72, MAGENTA, stroke=0.012, depth=0.010, round_tube=True)
    body.build()
    # the bottle wall: one mesh (the counter top row and the three shelves)
    bot = k.obj("Bottles")
    b = bot.part(bevel=0.0)
    i = 0
    for row, (z, y) in enumerate(((cab, -0.16), (shelves[0], wy + 0.12), (shelves[1], wy + 0.12),
                                  (shelves[2], wy + 0.12))):
        x = -hx + 0.20
        while x < hx - 0.20:
            h = 0.22 + 0.10 * _hash(i + row * 97)
            r = 0.032 + 0.008 * _hash(i * 7 + 3)
            key = _BOTTLE_KEYS[(i * 5 + row) % len(_BOTTLE_KEYS)]
            b.cyl(r, h * 0.66, (x, y, z + h * 0.33), key, segs=6)
            b.cyl(r * 0.40, h * 0.34, (x, y, z + h * 0.83), key, segs=6)
            x += 0.085 + 0.025 * _hash(i * 13 + row)
            i += 1
    bot.build()


# ---------------------------------------------------------------------------------------------------- booths

def _banquette(t, c, x0: float, x1: float, y_back: float, y_front: float, velvet: str, rail: str,
               fuller: bool) -> None:
    """A straight channel-tufted banquette along X, back at ``y_back``, seat front at ``y_front`` (> y_back)."""
    c.bx((x0, y_back, 0.0), (x1, y_front, 0.38), velvet)                                    # plinth
    t.bx((x0, y_front - 0.002, 0.0), (x1, y_front + 0.006, 0.06), rail)                     # brass kick
    c.bx((x0, y_back + 0.15, 0.38), (x1, y_front, 0.48), velvet)                            # seat cushion
    c.bx((x0, y_back, 0.38), (x1, y_back + 0.15, 1.06), velvet)                             # back
    for z in (0.58, 0.74, 0.90):                                                            # channel tufts
        t.rod((x0 + 0.02, y_back + 0.16, z), (x1 - 0.02, y_back + 0.16, z), 0.045, velvet, segs=8)
    t.rod((x0, y_back + 0.07, 1.08), (x1, y_back + 0.07, 1.08), 0.03 if fuller else 0.02, rail, segs=8)


def _booth(k: Kit, p: dict) -> None:
    vip = bool(p.get("vip", False))
    hx, hy = 1.2, 0.3
    velvet = "velvet_red" if vip else "velvet_charcoal"
    body = k.obj("Body")
    c = body.part(bevel=0.02, segments=2)
    t = body.part(bevel=0.002)
    _banquette(t, c, -hx, hx, -hy, hy, velvet, "brass", vip)
    for sx in (-1, 1):                                                                      # end caps
        c.bx((sx * hx - (0.05 if sx > 0 else 0.0), -hy, 0.0), (sx * hx + (0.0 if sx > 0 else 0.05), hy, 0.70),
             "walnut")
        t.bx((sx * hx - (0.05 if sx > 0 else 0.0), hy - 0.01, 0.66), (sx * hx + (0.0 if sx > 0 else 0.05), hy + 0.004,
                                                                           0.70), "brass")
    body.build()
    for i, x in enumerate((-0.80, 0.0, 0.80)):
        k.empty(f"Seat{i}", (x, hy, 0.0))


def _booth_corner(k: Kit, p: dict) -> None:
    h = 0.8
    body = k.obj("Body")
    c = body.part(bevel=0.02, segments=2)
    t = body.part(bevel=0.002)
    _banquette(t, c, -h, h, -h, -h + 0.6, "velvet_red", "brass", True)                     # the back row (-Y)
    # the side arm along +X (seats face -X): built as a rotated banquette by hand
    x0 = h - 0.6
    c.bx((x0, -h + 0.6, 0.0), (h, h, 0.38), "velvet_red")
    t.bx((x0 - 0.006, -h + 0.6, 0.0), (x0 + 0.002, h, 0.06), "brass")
    c.bx((x0, -h + 0.6, 0.38), (h - 0.15, h, 0.48), "velvet_red")
    c.bx((h - 0.15, -h + 0.6, 0.38), (h, h, 1.06), "velvet_red")
    for z in (0.58, 0.74, 0.90):
        t.rod((h - 0.16, -h + 0.62, z), (h - 0.16, h - 0.02, z), 0.045, "velvet_red", segs=8)
    t.rod((h - 0.07, -h, 1.08), (h - 0.07, h, 1.08), 0.03, "brass", segs=8)
    # the pedestal table in the L
    t.cyl(0.04, 0.68, (-0.15, 0.25, 0.34), "brass", segs=10)
    t.cyl(0.18, 0.03, (-0.15, 0.25, 0.015), "brass", segs=16)
    c.cyl(0.32, 0.04, (-0.15, 0.25, 0.70), "stone_dark", segs=24)
    body.build()
    for i, (x, y) in enumerate(((-0.55, -h + 0.6), (-0.05, -h + 0.6))):
        k.empty(f"Seat{i}", (x, y, 0.0))
    for i, y in enumerate((-0.05, 0.50)):                                                   # the side arm faces -X
        k.empty(f"Seat{i + 2}", (x0, y, 0.0), rotation=(0.0, 0.0, math.pi / 2))


# --------------------------------------------------------------------------------------- mirror ball, truss

def _mirror_ball(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    t = body.part(bevel=0.002)
    t.cyl(0.10, 0.02, (0.0, 0.0, -0.01), "brass", segs=20)                                 # ceiling rose
    t.rod((0.0, 0.0, -0.02), (0.0, 0.0, -0.12), 0.006, "steel_bare", segs=6)               # chain / drop
    t.bx((-0.05, -0.05, -0.20), (0.05, 0.05, -0.12), "alu_black")                           # the motor
    t.rod((0.0, 0.0, -0.20), (0.0, 0.0, -0.31), 0.008, "steel_bare", segs=6)
    body.build()
    ball = k.obj("Ball")
    b = ball.part(bevel=0.0)
    b.sphere(0.24, (0.0, 0.0, -0.55), "metal_grey", segs=24, rings=14)                   # silver tiles
    # D-165 dress review: a rough grey sphere 8 m up read as a dull disc under the club light, so a golden-spiral
    # scatter of self-lit glint tiles (octahedra, inside the old 0.25 m bounds) sparkles under any light state
    n = 40
    for i in range(n):
        zf = 1.0 - 2.0 * (i + 0.5) / n
        rf, th = math.sqrt(1.0 - zf * zf), i * math.pi * (3.0 - math.sqrt(5.0))
        c = 0.236
        b.sphere(0.012, (c * rf * math.cos(th), c * rf * math.sin(th), -0.55 + c * zf), "emit_led_cold", segs=4,
                 rings=2)
    ball.build(smooth_angle=5.0)                                                            # flat facets = tiles
    k.empty("Mount", (0.0, 0.0, 0.0))


def _truss(k: Kit, p: dict) -> None:
    hl, s = 1.0, 0.145
    zt, zb = -0.025, -0.315
    body = k.obj("Body")
    t = body.part(bevel=0.0)
    for y in (-s, s):                                                                       # four chords
        for z in (zt, zb):
            t.rod((-hl, y, z), (hl, y, z), 0.024, "alu_black", segs=8)
    n = 4
    for i in range(n):                                                                      # zig-zag lacing
        x0, x1 = -hl + i * (2 * hl / n), -hl + (i + 1) * (2 * hl / n)
        for y in (-s, s):
            t.rod((x0, y, zt), (x1, y, zb), 0.009, "alu_black", segs=6)
        for z in (zt, zb):
            t.rod((x0, -s, z), (x1, s, z), 0.009, "alu_black", segs=6)
    for x in (-hl, hl):                                                                     # end plates
        t.bx((x - 0.006, -s - 0.03, zb - 0.03), (x + 0.006, s + 0.03, 0.0), "metal_dark")       # top = the hanging point
    sockets = []
    for i, x in enumerate((-0.5, 0.5)):                                                     # two moving heads
        t.bx((x - 0.05, -0.04, zb - 0.05), (x + 0.05, 0.04, zb - 0.025), "metal_dark")         # clamp
        t.bx((x - 0.12, -0.10, zb - 0.16), (x + 0.12, 0.10, zb - 0.06), "alu_black")           # base
        for sx in (-1, 1):                                                                  # yoke arms
            t.bx((x + sx * 0.13 - 0.015, -0.03, zb - 0.38), (x + sx * 0.13 + 0.015, 0.03, zb - 0.16), "alu_black")
        t.sphere(0.11, (x, 0.0, zb - 0.32), "alu_black", segs=14, rings=8)                    # head
        t.cyl(0.07, 0.02, (x, 0.0, zb - 0.43), "glass", segs=14)                              # lens (down)
        sockets.append((x, 0.0, zb - 0.445))
    body.build()
    for i, loc in enumerate(sockets):
        k.empty(f"LightSocket{i}", loc, rotation=(-math.pi / 2, 0.0, 0.0))                  # Godot -Z points down


# ------------------------------------------------------------------------------------------- G2 batch 1

def _cone(t, x: float, z: float, r: float, y: float) -> None:
    """A speaker cone on a +Y baffle at ``y``: a grey surround ring and dust cap round the dark cone (an all-black
    driver vanishes into the black cabinet under the club light)."""
    t.cyl(r, 0.012, (x, y + 0.006, z), "plastic_grey", segs=20, axis="Y")
    t.cyl(r * 0.86, 0.016, (x, y + 0.008, z), "metal_dark", segs=20, axis="Y")
    t.cyl(r * 0.24, 0.03, (x, y + 0.016, z), "metal_grey", segs=12, axis="Y")


def _speaker_stack(k: Kit, p: dict) -> None:
    hx, hy = 0.6, 0.5
    body = k.obj("Body")
    c = body.part(bevel=0.008)
    t = body.part(bevel=0.0015)
    zs = 1.25                                                                               # sub / top split
    c.bx((-hx, -hy, 0.0), (hx, hy - 0.03, zs - 0.01), LACQUER)                             # sub cabinet
    c.bx((-hx + 0.02, -hy + 0.02, zs), (hx - 0.02, hy - 0.05, 2.2), LACQUER)               # top box
    # the baffles stand 1 mm proud of the cabinet fronts (coplanar faces z-fight)
    t.bx((-hx + 0.01, hy - 0.029, 0.04), (hx - 0.01, hy - 0.02, zs - 0.05), "metal_dark")   # sub baffle
    t.bx((-hx + 0.03, hy - 0.049, zs + 0.04), (hx - 0.03, hy - 0.04, 2.16), "metal_dark")   # top baffle
    for x in (-0.27, 0.27):
        _cone(t, x, 0.62, 0.22, hy - 0.02)                                                  # 18" subs
    for x in (-0.28, 0.28):
        _cone(t, x, 1.52, 0.12, hy - 0.04)                                                  # 10" mids
    t.bx((-0.17, hy - 0.04, 1.77), (0.17, hy - 0.025, 2.07), "plastic_grey")               # the horn flare
    t.bx((-0.16, hy - 0.035, 1.78), (0.16, hy - 0.02, 2.06), "plastic_black")              # the horn mouth
    t.bx((-0.10, hy - 0.05, 1.86), (0.10, hy - 0.03, 1.98), "metal_dark")
    for x0, x1 in ((-hx, -hx + 0.05), (hx - 0.05, hx)):                                     # brass corner caps
        for z0, z1 in ((0.0, 0.06), (zs - 0.07, zs - 0.01), (2.14, 2.2)):
            t.bx((x0, hy - 0.05, z0), (x1, hy - 0.01, z1), "brass")
    t.bx((hx - 0.10, hy - 0.04, 1.30), (hx - 0.07, hy - 0.025, 1.33), MAGENTA)              # status pip
    body.build()


def _vip_sofa(k: Kit, p: dict) -> None:
    hx, hy = 1.5, 0.45
    v = "velvet_red"
    body = k.obj("Body")
    c = body.part(bevel=0.03, segments=2)
    t = body.part(bevel=0.002)
    for x in (-hx + 0.08, hx - 0.08):                                                       # brass feet
        for y in (-hy + 0.08, hy - 0.08):
            t.cyl(0.025, 0.08, (x, y, 0.04), "brass", segs=10)
    t.bx((-hx, -hy, 0.08), (hx, hy, 0.12), "brass")                                         # plinth band
    c.bx((-hx + 0.16, -hy + 0.20, 0.12), (hx - 0.16, hy, 0.46), v)                           # seat
    c.bx((-hx + 0.04, -hy, 0.12), (hx - 0.04, -hy + 0.22, 0.90), v)                         # back
    for z in (0.56, 0.72):                                                                  # channel tufts
        t.rod((-hx + 0.20, -hy + 0.23, z), (hx - 0.20, -hy + 0.23, z), 0.04, v, segs=8)
    for sx in (-1, 1):                                                                      # rolled arms
        x = sx * (hx - 0.10)
        c.bx((x - 0.10, -hy, 0.12), (x + 0.10, hy, 0.56), v)
        t.rod((x, -hy, 0.60), (x, hy, 0.60), 0.10, v, segs=12)
    body.build()
    for i, x in enumerate((-0.85, 0.0, 0.85)):
        k.empty(f"Seat{i}", (x, hy, 0.0))


def _coupe(t, x: float, y: float, z: float) -> None:
    t.cyl(0.03, 0.004, (x, y, z + 0.002), "glass", segs=10)
    t.rod((x, y, z), (x, y, z + 0.10), 0.004, "glass", segs=6)
    t.cyl(0.045, 0.03, (x, y, z + 0.115), "glass", segs=12)


def _vip_coffee_table(k: Kit, p: dict) -> None:
    """LEAD r-AH-G2: a low table, not a block: a stone top at 0.40 on a brass edge band, four slim brass legs and a
    recessed brass stretcher, the floor showing under it."""
    hx, hy, top = 0.6, 0.3, 0.40
    body = k.obj("Body")
    c = body.part(bevel=0.004)
    t = body.part(bevel=0.0015)
    for x in (-hx + 0.06, hx - 0.06):                                                       # brass legs
        for y in (-hy + 0.05, hy - 0.05):
            t.rod((x, y, 0.0), (x, y, top - 0.05), 0.014, "brass", segs=8)
    for y in (-hy + 0.05, hy - 0.05):                                                       # recessed stretchers
        t.rod((-hx + 0.06, y, 0.10), (hx - 0.06, y, 0.10), 0.008, "brass", segs=6)
    t.bx((-hx, -hy, top - 0.05), (hx, hy, top - 0.03), "brass")                             # brass edge band
    c.bx((-hx + 0.01, -hy + 0.01, top - 0.03), (hx - 0.01, hy - 0.01, top), "stone_dark")  # top
    t.cyl(0.17, 0.012, (0.18, 0.02, top + 0.006), "brass", segs=20)                         # tray
    for x in (0.12, 0.25):
        _coupe(t, x, 0.02, top + 0.012)
    body.build()


def _bottle_table(k: Kit, p: dict) -> None:
    hx, hy, top = 0.4, 0.3, 0.75
    body = k.obj("Body")
    c = body.part(bevel=0.006)
    t = body.part(bevel=0.0015)
    for x in (-hx + 0.05, hx - 0.05):                                                       # brass legs
        for y in (-hy + 0.05, hy - 0.05):
            t.rod((x, y, 0.0), (x, y, top - 0.04), 0.016, "brass", segs=8)
    t.bx((-hx + 0.03, -hy + 0.03, 0.20), (hx - 0.03, hy - 0.03, 0.22), "brass")             # stretcher shelf
    c.bx((-hx, -hy, top - 0.04), (hx, hy, top), "stone_dark")                               # top
    # the ice bucket (diffuse grey: chrome reads black here), two bottles in it, a sparkler on one
    t.cyl(0.11, 0.22, (-0.10, 0.0, top + 0.11), "metal_grey", segs=20)
    t.cyl(0.10, 0.012, (-0.10, 0.0, top + 0.20), "paint_ivory", segs=16)                    # the ice
    for i, (dx, key) in enumerate(((-0.04, "metal_green"), (0.04, "plastic_black"))):
        x = -0.10 + dx
        t.cyl(0.036, 0.26, (x, 0.0, top + 0.21), key, segs=10)
        t.cyl(0.014, 0.10, (x, 0.0, top + 0.39), key, segs=8)
        t.cyl(0.016, 0.03, (x, 0.0, top + 0.43), "brass", segs=8)                           # foil
        if i == 0:
            t.rod((x, 0.0, top + 0.45), (x, 0.0, top + 0.58), 0.003, "steel_bare", segs=4)
            t.sphere(0.022, (x, 0.0, top + 0.60), "emit_warm", segs=8, rings=5)             # the sparkler
    for x in (0.15, 0.27):
        _coupe(t, x, 0.06, top)
    body.build()


def _high_table(k: Kit, p: dict) -> None:
    top = 1.05
    body = k.obj("Body")
    c = body.part(bevel=0.004)
    t = body.part(bevel=0.0015)
    t.cyl(0.26, 0.03, (0.0, 0.0, 0.015), "brass", segs=24)                                  # weighted base
    t.cyl(0.035, top - 0.07, (0.0, 0.0, (top - 0.04) / 2.0 + 0.015), "brass", segs=12)      # column
    t.cyl(0.09, 0.02, (0.0, 0.0, top - 0.05), "brass", segs=16)                             # top spider
    c.cyl(0.35, 0.04, (0.0, 0.0, top - 0.02), "stone_dark", segs=32)                        # top
    t.cyl(0.035, 0.05, (0.10, 0.06, top + 0.025), "glass_tinted", segs=10)                  # candle cup
    t.cyl(0.02, 0.012, (0.10, 0.06, top + 0.035), "emit_warm", segs=8)
    body.build()


def _private_shelving(k: Kit, p: dict) -> None:
    hx, hy, h = 1.5, 0.3, 2.0
    body = k.obj("Body")
    c = body.part(bevel=0.004)
    t = body.part(bevel=0.0012)
    for x in (-hx + 0.02, 0.0, hx - 0.02):                                                  # uprights
        for y in (-hy + 0.02, hy - 0.02):
            c.bx((x - 0.02, y - 0.02, 0.0), (x + 0.02, y + 0.02, h), "metal_dark")
    shelves = (0.12, 0.60, 1.08, 1.56, 1.96)
    for z in shelves:
        c.bx((-hx, -hy, z - 0.025), (hx, hy, z), "metal_dark")
    # the load: steel cash boxes with brass padlocks and grey document boxes, per bay and shelf (deterministic)
    i = 0
    for zi, z in enumerate(shelves[:-1]):
        x = -hx + 0.08
        while x < hx - 0.20:
            if abs(x) < 0.06:
                x += 0.06
                continue
            cash = _hash(i * 3 + zi) < 0.55
            w = 0.30 if cash else 0.36
            hh = 0.16 if cash else 0.30
            t.bx((x, -hy + 0.06, z), (x + w, hy - 0.06, z + hh), "metal_grey" if cash else "cardboard")
            if cash:
                t.bx((x + w / 2 - 0.02, hy - 0.06, z + hh - 0.07), (x + w / 2 + 0.02, hy - 0.04, z + hh - 0.03),
                     "brass")                                                               # padlock
            x += w + 0.05 + 0.05 * _hash(i * 11 + 5)
            i += 1
    body.build()


# ------------------------------------------------------------------------------------------- G2 batch 2

def _keg(t, x: float, y: float, z: float, lying: bool = False) -> None:
    """A 50 l steel keg (0.41 dia x 0.53) standing on ``z`` (lying: along X, its base at ``z``)."""
    r, h = 0.205, 0.53
    if lying:
        t.cyl(r, h, (x, y, z + r), "steel_galv", segs=18, axis="X")
        for dx in (-0.16, 0.16):
            t.cyl(r + 0.008, 0.03, (x + dx, y, z + r), "steel_bare", segs=18, axis="X")    # rolling rings
        return
    t.cyl(r, h, (x, y, z + h / 2), "steel_galv", segs=18)
    for dz in (0.15, 0.38):
        t.cyl(r + 0.008, 0.03, (x, y, z + dz), "steel_bare", segs=18)
    t.cyl(0.035, 0.03, (x, y, z + h + 0.015), "metal_dark", segs=10)                         # spear / coupler


def _keg_trolley(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    t = body.part(bevel=0.002)
    t.bx((-0.24, -0.22, 0.0), (0.24, 0.05, 0.02), "steel_bare")                              # toe plate
    for x in (-0.24, 0.24):                                                                  # frame rails
        t.rod((x, -0.26, 0.02), (x, -0.30, 1.0), 0.014, "metal_red", segs=8)
        t.cyl(0.10, 0.06, (x + (0.04 if x > 0 else -0.04), -0.30, 0.10), "rubber", segs=16, axis="X")  # wheels
    t.rod((-0.24, -0.30, 1.0), (0.24, -0.30, 1.0), 0.016, "metal_red", segs=8)              # handle
    for z in (0.35, 0.70):
        t.rod((-0.24, -0.27, z), (0.24, -0.27, z), 0.010, "metal_red", segs=6)
    _keg(t, 0.0, -0.06, 0.02)
    t.bx((-0.21, -0.27, 0.40), (0.21, 0.16, 0.43), "plastic_black")                         # strap
    body.build()


def _keg_rack(k: Kit, p: dict) -> None:
    hx, hy = 1.2, 0.4
    body = k.obj("Body")
    c = body.part(bevel=0.002)
    t = body.part(bevel=0.002)
    for x in (-hx + 0.02, hx - 0.02):
        for y in (-hy + 0.02, hy - 0.02):
            c.bx((x - 0.02, y - 0.02, 0.0), (x + 0.02, y + 0.02, 1.6), "steel_galv")       # posts
    for z in (0.08, 0.86):
        c.bx((-hx, -hy, z - 0.03), (hx, hy, z), "steel_galv")                               # decks
    for zi, z in enumerate((0.08, 0.86)):
        for i in range(5):
            if (i + zi) % 4 != 3:                                                           # a gap per tier
                _keg(t, -hx + 0.24 + i * 0.48, 0.0, z)
    body.build()


def _bottle_bank(k: Kit, p: dict) -> None:
    hx, hy, h = 0.6, 0.45, 1.12
    body = k.obj("Body")
    c = body.part(bevel=0.02, segments=2)
    t = body.part(bevel=0.002)
    c.bx((-hx + 0.04, -hy + 0.04, 0.10), (hx - 0.04, hy - 0.02, h), "metal_green")        # the bin (tapered look:
    c.bx((-hx, -hy, h - 0.12), (hx, hy, h), "metal_green")                                  #  a wider rim band)
    for x in (-hx + 0.12, hx - 0.12):                                                        # castors
        for y in (-hy + 0.12, hy - 0.12):
            t.cyl(0.05, 0.04, (x, y, 0.05), "rubber", segs=12, axis="X")
    # the lid (hinged at the back, -Y)
    t.bx((-hx - 0.01, -hy - 0.02, h), (hx + 0.01, hy + 0.02, h + 0.04), "metal_green")
    t.bx((-hx + 0.06, -hy, h + 0.04), (hx - 0.06, -hy + 0.04, h + 0.08), "plastic_black")  # hinge strip
    for x in (-0.3, 0.3):                                                                    # front handles
        t.bx((x - 0.10, hy, 0.86), (x + 0.10, hy + 0.04, 0.90), "plastic_black")
    lettering(t, "GLASS", 0.10, 0.0, hy + 0.002, 0.55, "paint_ivory", stroke=0.016, depth=0.004)
    body.build()


def _crate(t, x: float, y: float, z: float, key: str, full: bool, i: int) -> None:
    """A 0.40 x 0.30 x 0.28 plastic bottle crate (open lattice read: a solid body with darker hand-hole bands)."""
    t.bx((x - 0.20, y - 0.15, z), (x + 0.20, y + 0.15, z + 0.27), key)
    t.bx((x - 0.12, y + 0.15, z + 0.18), (x + 0.12, y + 0.152, z + 0.23), "metal_dark")     # hand hole (front)
    if full:
        for bx in range(4):
            for by in range(3):
                kx, ky = x - 0.15 + bx * 0.10, y - 0.10 + by * 0.10
                bk = ("metal_green", "art_ochre", "plastic_black")[(i + bx + by) % 3]
                t.cyl(0.012, 0.09, (kx, ky, z + 0.315), bk, segs=6)                          # necks


def _crates(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    t = body.part(bevel=0.004)
    i = 0
    for cx, n in ((-0.40, 5), (0.0, 4), (0.40, 3)):
        for cy in (-0.17, 0.17):
            m = n - (1 if cy > 0 and cx > 0.2 else 0)
            key = "metal_yellow" if i == 3 else "metal_red"                                # one colour per column
            for lvl in range(m):
                # the top crate holds empties, except on the 5-high column (it stays inside C's 1.4 m box)
                _crate(t, cx, cy, lvl * 0.275, key, lvl == m - 1 and m < 5, i)
            i += 1
    body.build()


def _flight_case(c, t, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> None:
    c.bx((x0, y0, z0), (x1, y1, z1), "plastic_black")
    for x in (x0, x1):                                                                       # aluminium edges
        for y in (y0, y1):
            t.bx((x - 0.012, y - 0.012, z0), (x + 0.012, y + 0.012, z1), "steel_bare")
            for z in (z0, z1):
                t.sphere(0.022, (x, y, z), "steel_bare", segs=8, rings=4)                    # ball corners
    for z in (z0, z1):
        for y in (y0, y1):
            t.bx((x0, y - 0.012, z - 0.012), (x1, y + 0.012, z + 0.012), "steel_bare")
    zl = z0 + (z1 - z0) * 0.62                                                               # the lid line, latches
    t.bx((x0, y1, zl - 0.006), (x1, y1 + 0.004, zl + 0.006), "steel_bare")
    for f in (0.2, 0.8):
        x = x0 + (x1 - x0) * f
        t.bx((x - 0.04, y1, zl - 0.04), (x + 0.04, y1 + 0.012, zl + 0.04), "steel_bare")


def _flight_cases(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    c = body.part(bevel=0.004)
    t = body.part(bevel=0.0015)
    _flight_case(c, t, -0.78, 0.78, -0.38, 0.38, 0.06, 0.62)                                # the big case
    for x in (-0.6, 0.6):                                                                    # castors
        for y in (-0.25, 0.25):
            t.cyl(0.04, 0.03, (x, y, 0.04), "rubber", segs=10, axis="X")
    _flight_case(c, t, -0.62, 0.30, -0.28, 0.28, 0.64, 1.0)                                 # the small one on top
    lettering(t, "VELVET", 0.08, -0.30, 0.392, 0.30, "paint_ivory", stroke=0.012, depth=0.003)
    body.build()


# ------------------------------------------------------------------------------------------- G2 batch 3

def _bar_counter(k: Kit, p: dict) -> None:
    end = bool(p.get("end", False))
    hx, hy, top = (0.3 if end else 1.0), 0.3, 1.05
    fy = hy - 0.06                                                                           # the front panel face
    body = k.obj("Body")
    c = body.part(bevel=0.004)
    t = body.part(bevel=0.0015)
    c.bx((-hx, -hy + 0.05, 0.12), (hx, fy, top - 0.05), LACQUER)                            # the front body
    c.bx((-hx, -hy + 0.05, 0.0), (hx, fy - 0.05, 0.12), LACQUER)                            # recessed plinth
    t.bx((-hx, fy - 0.052, 0.0), (hx, fy - 0.048, 0.06), "brass")                           # kick strip
    c.bx((-hx, -hy, top - 0.05), (hx, hy - 0.02, top), "stone_dark")                       # top, lip over the front
    t.bx((-hx, hy - 0.05, top - 0.065), (hx, hy - 0.035, top - 0.05), "emit_warm")         # LED strip under the lip
    n = 2 if end else 7                                                                      # brass deco fins
    for i in range(n):
        x = -hx + (i + 0.5) * (2 * hx / n)
        t.bx((x - 0.012, fy, 0.18), (x + 0.012, fy + 0.015, top - 0.12), "brass")
    t.bx((-hx, fy, top - 0.10), (hx, fy + 0.012, top - 0.075), "brass")                    # top band
    # the footrail on brackets, 0.25 up, inside the footprint
    ry = hy - 0.025
    t.rod((-hx, ry, 0.25), (hx, ry, 0.25), 0.022, "brass", segs=10)
    for x in ((0.0,) if end else (-0.75, 0.0, 0.75)):
        t.rod((x, fy, 0.25), (x, ry, 0.25), 0.010, "brass", segs=6)
    # the bartender side: an under-counter shelf with glass racks
    c.bx((-hx, -hy + 0.05, 0.55), (hx, -hy + 0.30, 0.58), "metal_dark")
    if not end:
        for x in (-0.6, 0.0, 0.6):
            t.bx((x - 0.22, -hy + 0.06, 0.58), (x + 0.22, -hy + 0.28, 0.62), "plastic_black")
            for gx in range(4):
                t.cyl(0.03, 0.09, (x - 0.15 + gx * 0.10, -hy + 0.17, 0.665), "glass", segs=8)
    body.build()


def _box_office_counter(k: Kit, p: dict) -> None:
    hx, hy, top = 2.2, 0.3, 1.05
    body = k.obj("Body")
    c = body.part(bevel=0.004)
    t = body.part(bevel=0.0015)
    c.bx((-hx, -hy, 0.0), (hx, hy - 0.04, top - 0.05), "walnut")                            # the counter body
    c.bx((-hx - 0.01, -hy, top - 0.05), (hx + 0.01, hy, top), "stone_dark")                # top
    for z0, z1 in ((0.0, 0.06), (0.46, 0.49), (top - 0.12, top - 0.09)):                     # brass bands
        t.bx((-hx, hy - 0.04, z0), (hx, hy - 0.025, z1), "brass")
    for i in range(8):                                                                       # raised panels
        x0 = -hx + 0.06 + i * 0.545
        t.bx((x0, hy - 0.04, 0.10), (x0 + 0.48, hy - 0.03, 0.42), "wood_dark")
        t.bx((x0, hy - 0.04, 0.53), (x0 + 0.48, hy - 0.03, 0.88), "wood_dark")
    # the window end (-X): a recessed cash tray, a call bell, a ticket roll, a card reader
    t.bx((-1.90, -0.10, top - 0.02), (-1.50, 0.18, top + 0.002), "metal_grey")
    t.cyl(0.04, 0.03, (-1.25, 0.12, top + 0.015), "brass", segs=14)
    t.sphere(0.03, (-1.25, 0.12, top + 0.035), "brass", segs=10, rings=5)
    t.cyl(0.045, 0.10, (-1.0, 0.0, top + 0.045), "paint_ivory", segs=12, axis="X")         # ticket roll
    t.bx((-0.75, -0.04, top), (-0.67, 0.04, top + 0.03), "plastic_black")                   # card reader
    t.bx((-0.74, -0.03, top + 0.03), (-0.68, 0.0, top + 0.032), "emit_screen")
    # the hatch end (+X): a brass coat-check ticket rail with hanging tags
    t.rod((1.3, 0.10, top + 0.14), (2.05, 0.10, top + 0.14), 0.006, "brass", segs=6)
    for x in (1.3, 2.05):
        t.rod((x, 0.10, top), (x, 0.10, top + 0.14), 0.006, "brass", segs=6)
    for i in range(9):
        x = 1.38 + i * 0.08
        t.bx((x - 0.02, 0.098, top + 0.06), (x + 0.02, 0.102, top + 0.135), "paint_ivory")
    body.build()


def _marquee(k: Kit, p: dict) -> None:
    hx, d = 6.0, 2.8
    z0, z1 = 0.0, 0.9                                                                         # soffit, canopy top
    body = k.obj("Body")
    c = body.part(bevel=0.01)
    t = body.part(bevel=0.0)
    w0 = 0.005                                                   # bevelled boxes start off the wall (the bevel bulges)
    c.bx((-hx, w0, z0 + 0.15), (hx, d - 0.05, z1 - 0.05), LACQUER)                          # the canopy box
    c.bx((-hx - 0.03, d - 0.08, z0), (hx + 0.03, d, z1), "metal_dark")                      # the street fascia
    for sx in (-1, 1):                                                                       # side fascias
        c.bx((sx * hx - 0.04, w0, z0), (sx * hx + 0.04, d, z1), "metal_dark")
    c.bx((-hx, w0, z0), (hx, d, z0 + 0.15), "metal_dark")                                   # soffit frame
    t.bx((-hx + 0.05, 0.05, z0 - 0.002), (hx - 0.05, d - 0.10, z0), "plastic_grey")         # soffit panel
    t.bx((-hx, d - 0.10, z1), (hx, d, z1 + 0.04), "brass")                                  # top band
    lettering(t, "VELVET", 0.46, 0.0, d, z0 + 0.22, MAGENTA, stroke=0.05, depth=0.04, round_tube=True)
    # the lamp bulbs: two rows along the street fascia and the sides, a grid on the soffit
    for z in (z0 + 0.08, z1 - 0.06):
        x = -hx + 0.15
        while x < hx - 0.1:
            t.cyl(0.025, 0.03, (x, d + 0.015, z), "emit_warm", segs=6, axis="Y")
            x += 0.30
        for sx in (-1, 1):
            y = 0.2
            while y < d - 0.1:
                t.cyl(0.025, 0.03, (sx * (hx + 0.055), y, z), "emit_warm", segs=6, axis="X")
                y += 0.30
    for xi in range(16):
        for yi in range(4):
            t.cyl(0.035, 0.02, (-hx + 0.4 + xi * 0.75, 0.40 + yi * 0.62, z0 - 0.01), "emit_warm", segs=8)
    body.build()
    k.empty("Mount", (0.0, 0.0, 0.0))


def _ice_bucket(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    t = body.part(bevel=0.0015)
    t.cyl(0.11, 0.22, (0.0, 0.0, 0.11), "metal_grey", segs=20)
    t.cyl(0.10, 0.012, (0.0, 0.0, 0.21), "paint_ivory", segs=16)                             # ice
    t.cyl(0.036, 0.26, (0.02, 0.0, 0.20), "metal_green", segs=10)
    t.cyl(0.014, 0.10, (0.02, 0.0, 0.38), "metal_green", segs=8)
    t.cyl(0.016, 0.03, (0.02, 0.0, 0.42), "brass", segs=8)                                    # foil
    for sx in (-1, 1):                                                                        # ring handles
        t.rod((sx * 0.11, -0.03, 0.17), (sx * 0.125, 0.03, 0.17), 0.006, "metal_grey", segs=6)
    body.build()


def _tip_jar(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    t = body.part(bevel=0.001)
    t.cyl(0.06, 0.16, (0.0, 0.0, 0.08), "glass", segs=14)
    t.cyl(0.05, 0.02, (0.0, 0.0, 0.17), "glass", segs=14)                                     # the neck
    for i in range(5):                                                                        # folded notes
        a = i * 1.26
        t.bx((0.025 * math.cos(a) - 0.02, 0.025 * math.sin(a) - 0.006, 0.01 + i * 0.022),
             (0.025 * math.cos(a) + 0.02, 0.025 * math.sin(a) + 0.006, 0.04 + i * 0.022), "paint_sage")
    t.bx((-0.04, 0.058, 0.06), (0.04, 0.062, 0.10), "paint_ivory")                           # label (no lettering:
    #                                                                                          2 cm text cost 2k tris)
    body.build()


def _till(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    c = body.part(bevel=0.004)
    t = body.part(bevel=0.0015)
    c.bx((-0.20, -0.20, 0.0), (0.20, 0.20, 0.10), "plastic_black")                           # cash drawer
    t.bx((-0.16, -0.205, 0.03), (0.16, -0.20, 0.07), "metal_dark")                           # drawer front (-Y)
    t.rod((0.0, 0.0, 0.10), (0.0, 0.0, 0.24), 0.02, "metal_dark", segs=8)                   # screen stalk
    scr = (-0.15, -0.02, 0.22), (0.15, 0.01, 0.42)
    t.bx(scr[0], scr[1], "plastic_black")                                                     # screen (tilted read)
    t.bx((-0.13, -0.022, 0.24), (0.13, -0.02, 0.40), "emit_screen")
    t.bx((0.10, 0.04, 0.10), (0.20, 0.18, 0.18), "plastic_grey")                              # receipt printer
    t.bx((0.12, 0.06, 0.18), (0.18, 0.062, 0.24), "paint_ivory")                              # receipt
    body.build()


# ------------------------------------------------------------------------------------------- G2 batch 4

def _bulb_mirror(k: Kit, p: dict) -> None:
    hw, hh = 0.6, 0.45
    body = k.obj("Body")
    c = body.part(bevel=0.004)
    t = body.part(bevel=0.0)
    c.bx((-hw, 0.0, -hh), (hw, 0.04, hh), LACQUER)                                           # frame
    t.bx((-hw + 0.10, 0.04, -hh + 0.10), (hw - 0.10, 0.044, hh - 0.08), "metal_grey")       # the mirror (chrome reads
    #                                                                                          black here)
    # the bulbs: along the top and both sides of the frame
    n = 7
    for i in range(n):
        x = -hw + 0.10 + i * (2 * hw - 0.20) / (n - 1)
        t.sphere(0.028, (x, 0.07, hh - 0.04), "emit_warm", segs=8, rings=5)
    for sx in (-1, 1):
        for j in range(5):
            z = -hh + 0.12 + j * (2 * hh - 0.24) / 4
            t.sphere(0.028, (sx * (hw - 0.05), 0.07, z), "emit_warm", segs=8, rings=5)
    c.bx((-hw, 0.0, -hh - 0.03), (hw, 0.16, -hh), "walnut")                                  # the shelf
    t.bx((-0.42, 0.04, -hh), (-0.18, 0.13, -hh + 0.09), "plastic_black")                    # make-up case
    t.cyl(0.03, 0.20, (0.35, 0.10, -hh + 0.10), "glass_teal", segs=10)                       # water bottle
    body.build()
    k.empty("Mount", (0.0, 0.0, 0.0))


def _cigarette_machine(k: Kit, p: dict) -> None:
    hx, hy, h = 0.375, 0.25, 1.8
    body = k.obj("Body")
    c = body.part(bevel=0.01, segments=2)
    t = body.part(bevel=0.0015)
    c.bx((-hx, -hy, 0.06), (hx, hy - 0.02, h), "metal_red")                                  # the cabinet
    t.bx((-hx + 0.02, -hy + 0.02, 0.0), (hx - 0.02, hy - 0.06, 0.06), "metal_dark")         # plinth
    t.bx((-hx, hy - 0.02, h - 0.10), (hx, hy, h - 0.06), "metal_grey")                      # top trim
    # the display window: packet faces behind glass, lit
    t.bx((-hx + 0.05, hy - 0.02, 0.95), (hx - 0.05, hy - 0.012, 1.62), "emit_neutral")
    faces = ("paint_ivory", "metal_red", "metal_blue", "art_ochre", "metal_green", "paint_ivory")
    for row in range(2):
        for col in range(6):
            x = -hx + 0.08 + col * 0.105
            z = 1.02 + row * 0.30
            t.bx((x, hy - 0.012, z), (x + 0.08, hy - 0.006, z + 0.22), faces[(col + row * 2) % len(faces)])
    t.bx((-hx + 0.04, hy - 0.02, 0.94), (hx - 0.04, hy - 0.004, 0.95), "metal_grey")       # window frame
    t.bx((-hx + 0.04, hy - 0.02, 1.62), (hx - 0.04, hy - 0.004, 1.63), "metal_grey")
    for col in range(6):                                                                     # pull knobs
        x = -hx + 0.12 + col * 0.105
        t.bx((x - 0.03, hy - 0.02, 0.80), (x + 0.03, hy - 0.004, 0.86), "metal_grey")
        t.cyl(0.012, 0.04, (x, hy + 0.01, 0.83), "metal_grey", segs=8, axis="Y")
    t.bx((0.12, hy - 0.02, 0.56), (0.30, hy - 0.006, 0.72), "metal_grey")                  # coin plate
    t.bx((0.17, hy - 0.006, 0.66), (0.25, hy - 0.004, 0.67), "plastic_black")               # slot
    t.bx((-0.25, hy - 0.06, 0.25), (0.05, hy, 0.36), "metal_grey")                          # delivery tray
    body.build()


def _projector(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    c = body.part(bevel=0.006)
    t = body.part(bevel=0.0015)
    c.bx((-0.20, -0.40, 0.0), (0.20, 0.40, 0.08), "metal_dark")                              # base plate
    c.bx((-0.10, -0.15, 0.08), (0.10, 0.15, 0.75), "metal_graphite")                         # the pedestal
    c.bx((-0.18, -0.30, 0.75), (0.18, 0.38, 1.02), "metal_graphite")                         # the head
    c.bx((-0.16, -0.42, 0.80), (0.16, -0.12, 1.12), "metal_dark")                            # lamp house (back)
    t.rod((-0.08, -0.42, 1.12), (-0.08, -0.42, 1.20), 0.03, "metal_dark", segs=8)            # chimney
    t.cyl(0.055, 0.16, (0.0, 0.44, 0.90), "metal_dark", segs=16, axis="Y")                   # the lens barrel (+Y)
    t.cyl(0.040, 0.01, (0.0, 0.525, 0.90), "glass", segs=14, axis="Y")
    for y, z in ((0.25, 1.30), (-0.20, 1.22)):                                               # reel arms and reels
        t.rod((0.0, y * 0.5, 1.02), (0.0, y, z), 0.012, "metal_grey", segs=6)
        t.cyl(0.17, 0.035, (0.0, y, z), "metal_grey", segs=24, axis="X")
        t.cyl(0.05, 0.04, (0.0, y, z), "metal_dark", segs=12, axis="X")
    body.build()


def _radio_charger(k: Kit, p: dict) -> None:
    hw, hh, d = 0.30, 0.125, 0.15
    body = k.obj("Body")
    c = body.part(bevel=0.004)
    t = body.part(bevel=0.0015)
    c.bx((-hw, 0.0, -hh), (hw, 0.03, hh), "metal_dark")                                       # backplate
    c.bx((-hw + 0.01, 0.03, -hh), (hw - 0.01, d, -hh + 0.07), "plastic_black")                # the charger bar
    for i in range(6):
        x = -hw + 0.06 + i * 0.096
        t.bx((x - 0.032, 0.06, -hh + 0.07), (x + 0.032, 0.115, hh - 0.04), "plastic_black")  # handset
        t.rod((x + 0.018, 0.09, hh - 0.04), (x + 0.018, 0.09, hh + 0.0), 0.006, "rubber", segs=6)  # antenna
        t.bx((x - 0.02, 0.115, 0.0), (x + 0.02, 0.117, 0.04), "metal_grey")                 # speaker grille
        t.bx((x - 0.006, d, -hh + 0.03), (x + 0.006, d + 0.003, -hh + 0.042), "emit_led_green")
    body.build()
    k.empty("Mount", (0.0, 0.0, 0.0))


def _clock_in(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    c = body.part(bevel=0.004)
    t = body.part(bevel=0.0015)
    # the terminal (-X part): 0.3 wide, 0.4 high, 0.12 deep, centred on z 0
    x0 = -0.225
    c.bx((x0 - 0.15, 0.0, -0.20), (x0 + 0.15, 0.12, 0.20), "plastic_grey")
    t.bx((x0 - 0.11, 0.12, 0.04), (x0 + 0.11, 0.122, 0.15), "emit_screen")                  # display
    for r in range(4):                                                                        # keypad
        for q in range(3):
            t.bx((x0 - 0.06 + q * 0.045, 0.12, -0.04 - r * 0.035), (x0 - 0.03 + q * 0.045, 0.126, -0.015 - r * 0.035),
                 "plastic_black")
    t.bx((x0 + 0.06, 0.12, -0.16), (x0 + 0.12, 0.124, -0.15), "plastic_black")              # card slot
    # the card rack (+X part): 0.35 wide, 0.6 high, 0.05 deep, with staff cards in its pockets
    x1 = 0.20
    c.bx((x1 - 0.175, 0.0, -0.30), (x1 + 0.175, 0.05, 0.30), "metal_grey")
    for r in range(5):
        for q in range(3):
            x = x1 - 0.13 + q * 0.105
            z = -0.25 + r * 0.11
            t.bx((x - 0.04, 0.05, z), (x + 0.04, 0.054, z + 0.04), "metal_dark")             # pocket
            if (r * 3 + q) % 4 != 1:
                t.bx((x - 0.035, 0.052, z + 0.02), (x + 0.035, 0.056, z + 0.085), "paint_ivory")  # a card
    body.build()
    k.empty("Mount", (0.0, 0.0, 0.0))


def _key_hooks(k: Kit, p: dict) -> None:
    hw, hh, d = 0.2, 0.25, 0.08
    body = k.obj("Body")
    c = body.part(bevel=0.0)
    t = body.part(bevel=0.001)
    # the back alone is on the wall plane (y = 0); the frame sits on it (coplanar overlapping faces at y = 0 would be
    # pushed 4 mm through the wall by dezfight, test_props' wall-back check)
    c.bx((-hw, 0.0, -hh), (hw, 0.008, hh), "paint_greige")                                    # back (light: keys read)
    c.bx((-hw, 0.008, -hh), (hw, d, -hh + 0.012), "metal_grey")                               # the box: bottom,
    c.bx((-hw, 0.008, hh - 0.012), (hw, d, hh), "metal_grey")                                 #  top,
    for sx in (-1, 1):                                                                         #  sides
        c.bx((sx * hw - (0.012 if sx > 0 else 0.0), 0.008, -hh), (sx * hw + (0.0 if sx > 0 else 0.012), d, hh),
             "metal_grey")
    # the door, open to the left (hinged on the -X edge, swung ~110 deg out)
    c.bx((-hw - 0.15, d, -hh), (-hw - 0.14, d + 0.36, hh), "metal_grey")
    for r in range(3):                                                                         # hooks, keys, tags
        z = hh - 0.10 - r * 0.15
        for q in range(5):
            x = -hw + 0.05 + q * 0.075
            t.rod((x, 0.008, z), (x, 0.04, z), 0.003, "steel_bare", segs=4)
            if (r + q) % 3 != 2:
                t.bx((x - 0.006, 0.035, z - 0.06), (x + 0.006, 0.040, z - 0.01), "brass")      # key
                t.bx((x - 0.014, 0.036, z - 0.095), (x + 0.014, 0.039, z - 0.06),
                     ("metal_red", "metal_yellow", "metal_blue")[(r + q) % 3])                 # tag
    body.build()
    k.empty("Mount", (0.0, 0.0, 0.0))


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
