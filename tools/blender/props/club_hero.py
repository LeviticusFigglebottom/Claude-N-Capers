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
* ``prop_ah_mirror_ball``: a 0.5 m faceted mirror ball on a motor and drop rod under a brass ceiling rose. Marker
  ``Mount`` = the ceiling point (origin); the ball centre hangs 0.55 m below it.
* ``prop_ah_truss_2m``: a 2 m black box truss (0.29 m square) with two moving-head fixture bodies hung under it.
  Markers ``LightSocket0..1`` at the heads' lenses, pointing down (C's SpotLights parent there); the origin is the
  truss top centre (hanging point).
"""

from __future__ import annotations

import math

from _pb import Kit, lettering

TRI_BUDGET = 20000
_FLOOR = {"place": "floor", "group": "afterhours", "pin_only": True}
_HUNG = {"place": "ceiling", "group": "afterhours", "pin_only": True}
VARIANTS = {
    "prop_ah_dj_booth": {"fn": "dj_booth", "cat": dict(_FLOOR, kind="dj_booth", surface="wood")},
    "prop_ah_back_bar": {"fn": "back_bar", "cat": dict(_FLOOR, kind="back_bar", surface="wood")},
    "prop_ah_booth": {"fn": "booth", "vip": False, "cat": dict(_FLOOR, kind="booth", surface="fabric")},
    "prop_ah_booth_vip": {"fn": "booth", "vip": True, "cat": dict(_FLOOR, kind="booth", surface="fabric")},
    "prop_ah_booth_corner": {"fn": "booth_corner", "cat": dict(_FLOOR, kind="booth", surface="fabric")},
    "prop_ah_mirror_ball": {"fn": "mirror_ball", "cat": dict(_HUNG, kind="mirror_ball", surface="metal")},
    "prop_ah_truss_2m": {"fn": "truss", "cat": dict(_HUNG, kind="truss", surface="metal")},
}

LACQUER = "plastic_black"
MAGENTA = "emit_neon_magenta"


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
    b.sphere(0.25, (0.0, 0.0, -0.55), "metal_grey", segs=24, rings=14)                   # silver tiles
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
        t.bx((x - 0.006, -s - 0.03, zb - 0.03), (x + 0.006, s + 0.03, zt + 0.03), "metal_dark")
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


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
