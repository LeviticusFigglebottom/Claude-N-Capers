"""Safehouse ("The Press") hero props (ENV D, C4-03 G2 waits; C's spec in docs/levels/safehouse/README.md).
Original designs, library materials only. Blender +Y = Godot -Z = the prop's front (toward the user); floor pivots at
the footprint centre with the bottom at z = 0; wall pivots on the wall face (the back at y = 0), centred.

* ``prop_sh_old_press``: the notoriety station. A treadle platen press in black cast iron: two arched side frames,
  the bed and the rocking platen, the round ink disc on top, the 1.1 m flywheel on the -X side and the treadle, brass
  oil cups. The face around Godot (0, 1.2, -0.55) stays clear (the station's Interactable). Convex ``Collision``.
* ``prop_sh_jukebox``: the jukebox station. A round-topped walnut cabinet with an amber light bar on the arch and
  deep-red glowing side pillars (never cyan), the selection window, the speaker grille. Markers ``Speaker`` (Godot
  (0, 1.25, -0.2), MusicDirector.positional_parent) and ``GlowLight`` (Godot (0, 1.45, -0.35), C's OmniLight).
* ``prop_sh_board_map``: the Board's painted city map (wall, 4.0 x 2.2 m): 8 districts, a river, a bay, a street
  grid; pins in the contact colours (Vance pink, Reyes orange, the Accountant green) joined by red string; three
  contact cards on the left edge, the Accountant's veiled. All modelled, so it needs no texture.
* ``prop_sh_bunk_bed``: a two-berth steel bunk with the ladder on the +Y short end.
* ``prop_sh_gun_cabinet``: a locked two-door steel gun cabinet (hasp, padlock, keypad, vents).
* ``prop_sh_ppe_rack``: a wall rack of ear defenders and safety glasses (the range vestibule).
* ``prop_sh_drying_line``: a floor frame with two lines of pegged paint-masking stencils (the mask room).
* ``prop_sh_type_case``: an old compositor's type-case cabinet: drawers under a slanted top with an open case tray.
"""

from __future__ import annotations

import math

from _pb import Kit, lettering

TRI_BUDGET = 20000
_FLOOR = {"place": "floor", "group": "safehouse", "pin_only": True}
VARIANTS = {
    "prop_sh_old_press": {"fn": "old_press", "cat": dict(_FLOOR, kind="press", surface="metal")},
    "prop_sh_jukebox": {"fn": "jukebox", "cat": dict(_FLOOR, kind="jukebox", surface="wood")},
    "prop_sh_board_map": {
        "fn": "board_map",
        "cat": {"kind": "board", "mount": "wall", "place": "wall_mount", "group": "safehouse", "surface": "wood",
                "pin_only": True},
    },
    "prop_sh_bunk_bed": {"fn": "bunk_bed", "cat": dict(_FLOOR, kind="bed", surface="metal")},
    "prop_sh_gun_cabinet": {"fn": "gun_cabinet", "cat": dict(_FLOOR, kind="gun_cabinet", surface="metal")},
    "prop_sh_ppe_rack": {
        "fn": "ppe_rack",
        "cat": {"kind": "ppe_rack", "mount": "wall", "place": "wall_mount", "group": "safehouse", "surface": "wood",
                "pin_only": True},
    },
    "prop_sh_drying_line": {"fn": "drying_line", "cat": dict(_FLOOR, kind="drying_line", surface="wood")},
    "prop_sh_type_case": {"fn": "type_case", "cat": dict(_FLOOR, kind="type_case", surface="wood")},
}


# --------------------------------------------------------------------------------------------- the Old Press

def _old_press(k: Kit, p: dict) -> None:
    """1.4 (x) x 1.0 (y) x 1.9 m. Side frames at x = +-0.32, the flywheel (r 0.55) outboard at x = -0.62."""
    body = k.obj("Body")
    iron = body.part(bevel=0.008, segments=2)
    fine = body.part(bevel=0.002)
    fx = 0.32
    # two arched side frames (a cast A with a round boss at the main shaft), front +Y
    frame = [(-0.42, 0.0), (0.42, 0.0), (0.40, 0.08), (0.18, 0.35), (0.22, 1.05), (0.12, 1.30), (-0.05, 1.32),
             (-0.20, 1.10), (-0.24, 0.40), (-0.40, 0.08)]
    for sx in (-1, 1):
        x0, x1 = sorted((sx * fx, sx * (fx - 0.06)))
        iron.profile_x(frame, x0, x1, "metal_dark")
        iron.cyl(0.11, 0.08, (sx * (fx - 0.03), -0.02, 0.70), "metal_dark", axis="X", segs=20)    # shaft boss
        fine.cyl(0.03, 0.05, (sx * (fx - 0.03), 0.02, 1.33), "brass", axis="Z", segs=10)       # oil cup
        fine.cyl(0.018, 0.03, (sx * (fx - 0.03), 0.02, 1.37), "brass", axis="Z", segs=10)
    iron.bx((-fx, -0.40, 0.0), (fx, 0.40, 0.08), "metal_dark")                                   # floor plinth
    iron.bx((-fx + 0.06, -0.30, 0.30), (fx - 0.06, -0.22, 0.38), "metal_dark")                    # rear tie bar
    # the bed (vertical, at the back) and the platen (rocking forward), the chase and a forme in it
    iron.bx((-0.26, -0.10, 0.80), (0.26, -0.02, 1.28), "metal_dark")
    fine.bx((-0.22, -0.02, 0.84), (0.22, 0.0, 1.24), "steel_bare")                                # chase
    fine.bx((-0.15, 0.0, 0.92), (0.15, 0.012, 1.14), "metal_grey")                                # forme
    iron.bx((-0.25, 0.10, 0.80), (0.25, 0.17, 1.24), "metal_dark")                               # platen
    fine.bx((-0.22, 0.17, 0.84), (0.22, 0.176, 1.20), "paper")                                    # tympan sheet
    iron.rod((0.0, 0.17, 0.80), (0.0, 0.02, 0.70), 0.03, "metal_dark", segs=10)                   # platen link
    # the main shaft across the frames to the flywheel
    fine.cyl(0.03, 0.98, (-0.17, -0.02, 0.70), "steel_bare", axis="X", segs=12)
    # the ink disc on its column above the bed, two roller arms reaching down past the forme
    iron.cyl(0.05, 0.44, (0.0, -0.16, 1.52), "metal_dark", segs=12)
    iron.cyl(0.21, 0.04, (0.0, -0.16, 1.76), "metal_dark", segs=28)
    fine.cyl(0.19, 0.01, (0.0, -0.16, 1.785), "soot", segs=28)                                     # inked disc
    fine.cyl(0.03, 0.10, (0.0, -0.16, 1.84), "brass", segs=10)                                     # finial
    for sx in (-1, 1):
        iron.rod((sx * 0.27, -0.06, 1.70), (sx * 0.27, 0.0, 1.30), 0.02, "metal_dark")
        iron.rod((sx * 0.27, 0.0, 1.30), (sx * 0.27, 0.03, 0.96), 0.02, "metal_dark")
    fine.cyl(0.035, 0.52, (0.0, 0.03, 0.96), "rubber", axis="X", segs=12)                         # form roller
    # the feed board (left) and delivery board (right) flank the platen below the clear face
    fine.bx((0.26, 0.10, 0.90), (0.62, 0.36, 0.93), "wood_oak")
    fine.bx((-0.58, 0.10, 0.84), (-0.27, 0.32, 0.87), "wood_oak")
    fine.bx((0.30, 0.14, 0.93), (0.56, 0.32, 0.95), "paper")                                      # stacked sheets
    # the treadle under the front and its rod up to the crank
    iron.bx((-0.20, 0.10, 0.10), (0.20, 0.40, 0.14), "metal_dark")
    iron.rod((-0.18, 0.12, 0.12), (-0.30, -0.25, 0.10), 0.02, "metal_dark")
    iron.rod((-0.36, 0.28, 0.13), (-0.36, -0.02, 0.62), 0.018, "metal_dark")
    lettering(fine, "THE PRESS", 0.035, -0.29, 0.0, 0.18, "brass", stroke=0.007, depth=0.004)
    body.build()
    # the flywheel: a rim, six curved spokes and a hub, outboard on -X
    fly = k.obj("Flywheel", location=(-0.62, -0.02, 0.62))
    w = fly.part(bevel=0.004)
    w.torus(0.52, 0.035, (0.0, 0.0, 0.0), "metal_dark", segs=40, rsegs=8, axis="X")
    w.cyl(0.08, 0.10, (0.0, 0.0, 0.0), "metal_dark", axis="X", segs=16)
    for i in range(6):
        a0 = math.tau * i / 6
        pts = [(0.0, math.cos(a0 + d) * r, math.sin(a0 + d) * r) for r, d in ((0.07, 0.0), (0.30, 0.12),
                                                                               (0.50, 0.20))]
        w.tube(pts, 0.018, "metal_dark", segs=6)
    w.cyl(0.03, 0.03, (-0.06, 0.0, 0.0), "brass", axis="X", segs=10)                              # hub oil cup
    fly.build()
    k.collision([((-0.42, -0.42, 0.0), (0.42, 0.40, 1.89)), ((-0.68, -0.56, 0.08), (-0.56, 0.52, 1.16)),
                 ((0.26, 0.10, 0.84), (0.62, 0.36, 0.95))])


# ---------------------------------------------------------------------------------------------- the jukebox

def _arch(w: float, z0: float, zs: float, rise: float, n: int = 12) -> list[tuple[float, float]]:
    """A front elevation (x, z): straight sides to zs, then a half-ellipse of ``rise``."""
    hx = w / 2
    out = [(-hx, z0), (hx, z0), (hx, zs)]
    for i in range(1, n):
        a = math.pi * i / n
        out.append((hx * math.cos(a), zs + rise * math.sin(a)))
    out.append((-hx, zs))
    return out


def _jukebox(k: Kit, p: dict) -> None:
    """0.9 (x) x 0.65 (y) x 1.6 m, round top, the front at +Y."""
    hy = 0.325
    body = k.obj("Body")
    wood = body.part(bevel=0.01, segments=2)
    trim = body.part(bevel=0.003)
    wood.profile_y(_arch(0.9, 0.0, 1.22, 0.38), -hy, hy - 0.06, "walnut")                           # cabinet
    wood.bx((-0.47, -hy, 0.0), (0.47, hy, 0.07), "wood_dark")                                     # plinth
    trim.profile_y(_arch(0.76, 0.60, 1.22, 0.30), hy - 0.06, hy - 0.02, "wood_dark")                # front panel
    # the selection window (glass over the title strips) and the record well
    trim.bx((-0.28, hy - 0.025, 0.98), (0.28, hy - 0.005, 1.26), "glass_tinted")
    for row in range(6):
        for col in range(2):
            x0 = -0.25 + col * 0.26
            z = 1.0 + row * 0.042
            trim.bx((x0, hy - 0.03, z), (x0 + 0.23, hy - 0.026, z + 0.032), "paper")
    trim.bx((-0.30, hy - 0.02, 0.84), (0.30, hy, 0.94), "chrome")                                   # button bank
    for i in range(10):
        trim.bx((-0.27 + i * 0.056, hy, 0.87), (-0.23 + i * 0.056, hy + 0.015, 0.91), "plastic_white")
    lettering(trim, "SELECT", 0.025, 0.0, hy, 0.79, "chrome", stroke=0.005, depth=0.003)
    # the speaker grille: a chrome lattice on dark cloth, the coin slot beside it
    trim.bx((-0.30, hy - 0.02, 0.18), (0.30, hy - 0.01, 0.70), "fabric_charcoal")
    for i in range(7):
        x = -0.27 + i * 0.09
        trim.bx((x - 0.006, hy - 0.01, 0.20), (x + 0.006, hy, 0.68), "chrome")
    for i in range(5):
        z = 0.24 + i * 0.105
        trim.bx((-0.29, hy - 0.01, z - 0.006), (0.29, hy, z + 0.006), "chrome")
    trim.bx((0.33, hy - 0.02, 0.62), (0.40, hy, 0.70), "chrome")
    trim.bx((0.355, hy, 0.645), (0.375, hy + 0.004, 0.675), "metal_dark")
    body.build()
    # the glow: an amber light bar along the arch and deep-red side pillars
    glow = k.obj("Glow")
    g = glow.part(bevel=0.0)
    pts = []
    for i in range(13):
        a = math.pi * i / 12
        pts.append((0.41 * math.cos(a), hy - 0.03, 1.22 + 0.345 * math.sin(a)))
    g.tube(pts, 0.018, "emit_amber", segs=8)
    for sx in (-1, 1):
        g.bx((sx * 0.42 - 0.025, hy - 0.05, 0.12), (sx * 0.42 + 0.025, hy - 0.0, 1.20), "emit_led_red")
        for gy in (-0.20, 0.0, 0.20):                                                                # side slots
            g.bx((sx * 0.452 - 0.003, gy - 0.015, 0.30), (sx * 0.452 + 0.003, gy + 0.015, 1.05), "emit_led_red")
    glow.build()
    k.empty("Speaker", (0.0, 0.2, 1.25))
    k.empty("GlowLight", (0.0, 0.35, 1.45))
    k.collision([((-0.45, -hy, 0.0), (0.45, hy, 1.6))])


# --------------------------------------------------------------------------------------------- the Board map

_DISTRICTS = (   # (x0, z0, x1, z1, key): the city's eight districts on the 4.0 x 2.2 panel (x right-to-left mirrored)
    (-1.70, 0.25, -0.95, 0.95, "paint_greige"),
    (-0.85, 0.30, -0.10, 0.95, "art_ochre"),
    (0.05, 0.40, 0.75, 0.95, "paint_sage"),
    (-1.70, -0.45, -1.05, 0.15, "paint_ivory"),
    (-0.95, -0.40, -0.25, 0.18, "art_rust"),
    (-0.15, -0.30, 0.55, 0.28, "paint_greige"),
    (-1.70, -0.95, -0.80, -0.55, "paint_sage"),
    (-0.70, -0.95, 0.10, -0.50, "paint_ivory"),
)
_RIVER = ((-1.85, 0.20), (-1.0, 0.22), (-0.2, 0.33), (0.25, 0.35), (0.62, 0.30), (0.95, 0.05), (1.10, -0.30),
          (1.30, -0.60))
_PINS = ((-1.30, 0.62, "felt_rose"), (-0.45, 0.70, "felt_rose"), (-0.60, -0.10, "safety_orange"),
         (0.20, -0.02, "safety_orange"), (-1.25, -0.75, "metal_green"), (0.40, 0.70, "metal_green"))


def _board_map(k: Kit, p: dict) -> None:
    """A 4.0 x 2.2 x 0.06 m panel, the back on the wall (y = 0), centred on the pivot; the map on the front (+Y).
    The viewer's left is Blender +X: the contact cards sit there."""
    hx, hz, d = 2.0, 1.1, 0.06
    body = k.obj("Body")
    b = body.part(bevel=0.004)
    t = body.part(bevel=0.0)
    b.bx((-hx, 0.0, -hz), (hx, d - 0.012, hz), "wood_dark")                                        # backing board
    for x0, x1, z0, z1 in ((-hx, hx, hz - 0.05, hz), (-hx, hx, -hz, -hz + 0.05), (-hx, -hx + 0.05, -hz, hz),
                           (hx - 0.05, hx, -hz, hz)):
        b.bx((x0, d - 0.012, z0), (x1, d, z1), "wood_dark")                                        # frame
    sheet_y = d - 0.012
    t.bx((-1.95, sheet_y, -1.05), (1.25, sheet_y + 0.002, 1.05), "paper")                           # the map sheet
    # the bay (lower right of the sheet, viewer's right = -X) and the coastline
    bay = [(-1.95, -1.05), (-0.20, -1.05), (-0.45, -0.75), (-1.05, -0.62), (-1.35, -0.30), (-1.95, -0.18)]
    t.profile_y([(x, z) for x, z in bay], sheet_y + 0.002, sheet_y + 0.003, "art_blue")
    for x0, z0, x1, z1, key in _DISTRICTS:
        # mirror into the sheet: districts sit right of the cards (x < 1.25), above the bay
        t.bx((x0 + 0.45, sheet_y + 0.002, z0), (x1 + 0.45, sheet_y + 0.0035, z1), key)
    # the river, a ribbon of short bars across the districts into the bay
    for (x0, z0), (x1, z1) in zip(_RIVER, _RIVER[1:]):
        _strip(t, (-x0 * 0.85 - 0.30, z0), (-x1 * 0.85 - 0.30, z1), 0.05, sheet_y + 0.0035, "art_blue")
    # a street grid: thin dark lines
    for i in range(9):
        x = -1.75 + i * 0.36
        t.bx((x - 0.004, sheet_y + 0.0035, -0.95), (x + 0.004, sheet_y + 0.0045, 0.98), "metal_dark")
    for i in range(6):
        z = -0.85 + i * 0.35
        t.bx((-1.9, sheet_y + 0.0035, z - 0.004), (1.2, sheet_y + 0.0045, z + 0.004), "metal_dark")
    # pins and the red string between them (pin heads proud of the sheet)
    heads = []
    for x, z, key in _PINS:
        y0 = sheet_y + 0.004
        t.cyl(0.003, 0.03, (x, y0 + 0.015, z), "steel_bare", axis="Y", segs=6)
        t.sphere(0.018, (x, y0 + 0.035, z), key, segs=10, rings=5)
        heads.append((x, y0 + 0.03, z))
    for a, b_ in ((0, 1), (1, 3), (2, 3), (3, 5), (2, 4), (0, 2)):
        t.rod(heads[a], heads[b_], 0.0025, "metal_red", segs=4)
    # three contact cards on the left edge (viewer's left = +X): Vance, Reyes, the Accountant (veiled)
    for i, (key, veiled) in enumerate((("felt_rose", False), ("safety_orange", False), ("metal_green", True))):
        z = 0.62 - i * 0.62
        cx = 1.62
        t.bx((cx - 0.26, sheet_y, z - 0.26), (cx + 0.26, sheet_y + 0.004, z + 0.26), "paper")
        t.bx((cx - 0.26, sheet_y + 0.004, z + 0.20), (cx + 0.26, sheet_y + 0.006, z + 0.26), key)        # tab
        if veiled:
            t.bx((cx - 0.18, sheet_y + 0.004, z - 0.16), (cx + 0.18, sheet_y + 0.012, z + 0.16), "velvet_charcoal")
            t.bx((cx - 0.14, sheet_y + 0.012, z - 0.02), (cx + 0.14, sheet_y + 0.014, z + 0.02), "metal_green")
        else:
            t.bx((cx - 0.16, sheet_y + 0.004, z - 0.12), (cx + 0.16, sheet_y + 0.006, z + 0.17), "plastic_grey")
            t.sphere(0.07, (cx, sheet_y + 0.008, z + 0.05), "metal_dark", segs=10, rings=5, scale=(1, 0.1, 1.2))
        for j in range(3):
            t.bx((cx - 0.18, sheet_y + 0.004, z - 0.22 + j * 0.03), (cx + 0.18 - j * 0.05, sheet_y + 0.006,
                                                                      z - 0.21 + j * 0.03), "metal_dark")
        t.sphere(0.015, (cx, sheet_y + 0.02, z + 0.23), key, segs=8, rings=4)                    # card pin
    # the strings from the cards to their contacts' pins
    for i, pin in ((0, 0), (1, 2), (2, 4)):
        z = 0.62 - i * 0.62
        t.rod((1.62, sheet_y + 0.03, z + 0.23), heads[pin], 0.0025, "metal_red", segs=4)
    body.build()


def _strip(part, a: tuple[float, float], b: tuple[float, float], w: float, y: float, key: str) -> None:
    """A flat (x, z) ribbon segment of width ``w`` on the plane y (1 mm thick)."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dz) or 1.0
    nx, nz = -dz / ln * w / 2, dx / ln * w / 2
    outline = [(a[0] + nx, a[1] + nz), (b[0] + nx, b[1] + nz), (b[0] - nx, b[1] - nz), (a[0] - nx, a[1] - nz)]
    if (outline[1][0] - outline[0][0]) * (outline[2][1] - outline[0][1]) - (outline[1][1] - outline[0][1]) * (
            outline[2][0] - outline[0][0]) < 0:
        outline.reverse()
    part.profile_y(outline, y, y + 0.001, key)


# ------------------------------------------------------------------------------------------------- bunk bed

def _bunk_bed(k: Kit, p: dict) -> None:
    """0.95 (x) x 2.05 (y) x 1.75 m: a square-tube steel frame, two berths (0.35 / 1.25 m decks), the ladder on the
    +Y short end, a guard rail on the top berth."""
    hx, hy = 0.475, 1.025
    body = k.obj("Body")
    s = body.part(bevel=0.003)
    soft = body.part(bevel=0.03, segments=2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            s.bx((sx * hx - 0.02, sy * hy - 0.02, 0.0), (sx * hx + 0.02, sy * hy + 0.02, 1.75), "metal_green_worn")
    for z in (0.30, 1.20):
        for sx in (-1, 1):
            x0, x1 = sorted((sx * (hx - 0.02), sx * (hx - 0.05)))
            s.bx((x0, -hy, z), (x1, hy, z + 0.06), "metal_green_worn")                              # side rails
        for sy in (-1, 1):
            y0, y1 = sorted((sy * (hy - 0.02), sy * (hy - 0.05)))
            s.bx((-hx, y0, z), (hx, y1, z + 0.06), "metal_green_worn")                              # end rails
        for i in range(5):                                                                           # slats
            y = -hy + 0.2 + i * 0.41
            s.bx((-hx + 0.05, y - 0.03, z + 0.04), (hx - 0.05, y + 0.03, z + 0.05), "wood_pine")
        soft.bx((-hx + 0.05, -hy + 0.05, z + 0.05), (hx - 0.05, hy - 0.05, z + 0.17), "fabric_ivory")  # mattress
        soft.bx((-hx + 0.06, -hy + 0.45, z + 0.17), (hx - 0.06, hy - 0.06, z + 0.20), "fabric_sage"
                if z < 1 else "fabric_charcoal")                                                     # blanket
        soft.bx((-hx + 0.12, -hy + 0.08, z + 0.17), (hx - 0.12, -hy + 0.40, z + 0.27), "linen_white")  # pillow
    for sy in (-1, 1):                                                                               # head / foot
        y0, y1 = sorted((sy * (hy - 0.005), sy * (hy - 0.035)))
        for z in (0.62, 1.55, 1.70):
            s.bx((-hx, y0, z), (hx, y1, z + 0.04), "metal_green_worn")
    x0, x1 = sorted((-hx + 0.02, -hx + 0.05))                                                        # guard rail
    s.bx((x0, -hy, 1.50), (x1, 0.30, 1.54), "metal_green_worn")
    s.bx((x0, 0.26, 1.24), (x1, 0.30, 1.54), "metal_green_worn")
    # ladder on the +Y end, its rungs on the end frame
    for i in range(4):
        z = 0.50 + i * 0.27
        s.rod((0.10, hy + 0.0, z), (0.40, hy + 0.0, z), 0.012, "steel_bare", segs=8)
    for x in (0.10, 0.40):
        s.bx((x - 0.015, hy - 0.02, 0.0), (x + 0.015, hy + 0.012, 1.40), "metal_green_worn")
    body.build()
    k.collision([((-hx - 0.02, -hy - 0.02, 0.0), (hx + 0.02, hy + 0.02, 1.75))])


# ---------------------------------------------------------------------------------------------- gun cabinet

def _gun_cabinet(k: Kit, p: dict) -> None:
    """1.0 (x) x 0.5 (y) x 2.0 m: a welded steel cabinet, two doors with a centre hasp and padlock, a keypad, louvres,
    a stencilled locker number."""
    hx, hy, h = 0.5, 0.25, 2.0
    body = k.obj("Body")
    s = body.part(bevel=0.006)
    t = body.part(bevel=0.002)
    s.bx((-hx, -hy, 0.05), (hx, hy - 0.02, h), "powder_charcoal")
    s.bx((-hx + 0.03, -hy + 0.02, 0.0), (hx - 0.03, hy - 0.04, 0.05), "metal_dark")                   # plinth
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.004, sx * (hx - 0.02)))
        s.bx((x0, hy - 0.02, 0.08), (x1, hy, h - 0.03), "powder_charcoal")                             # door leaf
        for i in range(5):                                                                            # louvres
            z = 1.62 + i * 0.05
            t.bx((sx * 0.12 - 0.12, hy, z), (sx * 0.12 + 0.12, hy + 0.006, z + 0.012), "metal_dark")
        for z in (0.25, 1.0, 1.75):                                                                    # hinges
            t.cyl(0.012, 0.10, (sx * (hx - 0.005), hy - 0.005, z), "steel_bare", segs=8)
        t.bx((sx * 0.06 - 0.012, hy, 0.85), (sx * 0.06 + 0.012, hy + 0.03, 1.15), "steel_bare")       # handles
    t.bx((-0.035, hy, 1.05), (0.035, hy + 0.02, 1.13), "steel_bare")                                  # hasp
    t.bx((-0.025, hy + 0.01, 0.97), (0.025, hy + 0.035, 1.03), "brass")                               # padlock body
    t.torus(0.016, 0.004, (0.0, hy + 0.022, 1.045), "steel_bare", segs=12, rsegs=4, axis="Y", arc=math.pi)
    t.bx((0.14, hy, 1.25), (0.24, hy + 0.012, 1.38), "plastic_black")                                 # keypad
    for r in range(3):
        for c in range(3):
            t.bx((0.152 + c * 0.03, hy + 0.012, 1.27 + r * 0.03), (0.172 + c * 0.03, hy + 0.016, 1.285 + r * 0.03),
                 "metal_grey")
    t.bx((0.215, hy + 0.012, 1.355), (0.228, hy + 0.016, 1.368), "emit_led_red")
    lettering(t, "K4", 0.09, 0.27, hy, 0.35, "paint_hazard_orange", stroke=0.016, depth=0.002, inlay=True)
    body.build()
    k.collision([((-hx, -hy, 0.0), (hx, hy + 0.03, h))])


# ---------------------------------------------------------------------------------------------- PPE rack

def _ppe_rack(k: Kit, p: dict) -> None:
    """A 1.0 x 0.8 m pine board on the wall (the back at y = 0, centred), 0.2 m deep with its pegs: four ear
    defenders on the top rail, four pairs of safety glasses on hooks below, a painted label strip."""
    body = k.obj("Body")
    b = body.part(bevel=0.004)
    t = body.part(bevel=0.002)
    b.bx((-0.5, 0.0, -0.4), (0.5, 0.025, 0.4), "wood_pine")
    b.bx((-0.5, 0.025, 0.28), (0.5, 0.045, 0.34), "wood_oak")                                         # top rail
    b.bx((-0.5, 0.025, -0.08), (0.5, 0.045, -0.03), "wood_oak")                                       # hook rail
    t.bx((-0.42, 0.025, 0.36), (0.42, 0.028, 0.39), "paint_hazard_orange")                             # label strip
    lettering(t, "EARS EYES", 0.022, 0.0, 0.028, 0.365, "metal_dark", stroke=0.004, depth=0.002, inlay=True)
    for i in range(4):
        x = -0.36 + i * 0.24
        t.rod((x, 0.045, 0.30), (x, 0.13, 0.31), 0.008, "steel_bare", segs=8)                          # peg
        # ear defenders hung by the headband over the peg: the band arcs, the cups hang either side
        t.torus(0.075, 0.009, (x, 0.12, 0.25), "plastic_black", segs=16, rsegs=4, axis="Y", arc=math.pi)
        for sx in (-1, 1):
            t.cyl(0.042, 0.045, (x + sx * 0.075, 0.12, 0.20), "safety_orange", axis="X", segs=14)
            t.cyl(0.035, 0.012, (x + sx * 0.05, 0.12, 0.20), "rubber", axis="X", segs=12)
    for i in range(4):
        x = -0.36 + i * 0.24
        t.rod((x, 0.045, -0.05), (x, 0.09, -0.04), 0.005, "steel_bare", segs=6)                         # hook
        for sx in (-1, 1):                                                                             # lenses
            t.bx((x + sx * 0.035 - 0.03, 0.085, -0.13), (x + sx * 0.035 + 0.03, 0.092, -0.07), "glass_tinted")
        t.bx((x - 0.075, 0.082, -0.075), (x + 0.075, 0.095, -0.062), "plastic_black")                  # brow bar
        for sx in (-1, 1):                                                                             # folded arms
            t.bx((x + sx * 0.07 - 0.004, 0.06, -0.09), (x + sx * 0.07 + 0.004, 0.09, -0.07), "plastic_black")
    for i in range(2):                                                                                 # spare pack
        t.bx((-0.45 + i * 0.12, 0.025, -0.38), (-0.36 + i * 0.12, 0.08, -0.22), "cardboard")
    body.build()


# ---------------------------------------------------------------------------------------------- drying line

def _drying_line(k: Kit, p: dict) -> None:
    """1.5 (x) x 0.5 (y) x 1.8 m: two pine A-frame ends, a top bar, two lines (1.62 / 1.20 m) of pegged masking
    stencils (card and acetate with painted cut-outs) drying over a drip tray."""
    hx = 0.75
    body = k.obj("Body")
    w = body.part(bevel=0.004)
    t = body.part(bevel=0.0)
    for sx in (-1, 1):
        x = sx * (hx - 0.03)
        w.rod((x, -0.24, 0.0), (x, 0.0, 1.78), 0.022, "wood_pine", square=True)
        w.rod((x, 0.24, 0.0), (x, 0.0, 1.78), 0.022, "wood_pine", square=True)
        w.bx((x - 0.02, -0.20, 0.45), (x + 0.02, 0.20, 0.49), "wood_pine")
    w.bx((-hx, -0.03, 1.74), (hx, 0.03, 1.80), "wood_pine")
    w.bx((-hx + 0.05, -0.18, 0.04), (hx - 0.05, 0.18, 0.08), "metal_grey")                             # drip tray
    rng = [0.11, 0.07, 0.13, 0.09, 0.12, 0.08, 0.10]
    keys = ["cardboard", "paper", "frost", "cardboard", "paper", "frost", "cardboard"]
    paints = ["metal_red", "art_blue", "metal_yellow", "felt_rose", "metal_green", "safety_orange", "metal_white"]
    for li, z in enumerate((1.62, 1.20)):
        t.rod((-hx + 0.03, 0.0, z), (hx - 0.03, 0.0, z - 0.03), 0.004, "rope_tan", segs=6)
        n = 6 - li
        for i in range(n):
            x = -hx + 0.18 + i * (2 * hx - 0.36) / (n - 1)
            hgt = 0.26 + rng[(i + li) % 7]
            zt = z - 0.015 * (x + hx) / (2 * hx) - 0.01
            t.bx((x - 0.09, -0.002, zt - hgt), (x + 0.09, 0.002, zt), keys[(i + li) % 7])
            # a painted mask motif over the cut-out (eye holes left bare)
            pk = paints[(i * 3 + li) % 7]
            t.bx((x - 0.07, 0.002, zt - hgt + 0.04), (x + 0.07, 0.004, zt - 0.05), pk)
            for sx in (-1, 1):
                t.bx((x + sx * 0.035 - 0.018, 0.004, zt - 0.11), (x + sx * 0.035 + 0.018, 0.006, zt - 0.085),
                     "metal_dark")
            for dx in (-0.06, 0.06):                                                                  # pegs
                w.bx((x + dx - 0.007, -0.01, zt - 0.03), (x + dx + 0.007, 0.01, zt + 0.035), "wood_oak")
    body.build()
    k.collision([((-hx, -0.25, 0.0), (hx, 0.25, 1.8))])


# ------------------------------------------------------------------------------------------------ type case

def _type_case(k: Kit, p: dict) -> None:
    """1.3 (x) x 0.7 (y) x 1.0 m: a compositor's oak cabinet, two banks of shallow type drawers with brass label
    pulls, the slanted top (0.88 m at the front to 1.0 m at the back) carrying an open case of type."""
    hx, hy = 0.65, 0.35
    body = k.obj("Body")
    w = body.part(bevel=0.005)
    t = body.part(bevel=0.0015)
    w.bx((-hx, -hy, 0.0), (hx, hy - 0.02, 0.85), "wood_oak")
    w.bx((-hx + 0.03, -hy + 0.03, 0.0), (hx - 0.03, hy - 0.05, 0.06), "wood_dark")                     # kick
    w.profile_x([(-hy, 0.85), (hy, 0.85), (hy, 0.88), (-hy, 1.0)], -hx, hx, "wood_oak")                # slant
    for sx in (-1, 1):
        for i in range(12):
            z = 0.10 + i * 0.062
            x0, x1 = sorted((sx * 0.012, sx * (hx - 0.03)))
            w.bx((x0, hy - 0.02, z), (x1, hy - 0.004, z + 0.056), "wood_oak")                          # drawer front
            cx = sx * hx / 2
            t.bx((cx - 0.05, hy - 0.004, z + 0.02), (cx + 0.05, hy + 0.006, z + 0.038), "brass")        # pull
            t.bx((cx - 0.025, hy + 0.006, z + 0.04), (cx + 0.025, hy + 0.008, z + 0.052), "paper")      # label
    # the open case on the slant: a tray of compartments with type in some (the case tilts with the top)
    tilt = math.atan2(0.12, 2 * hy)
    ca, sa = math.cos(tilt), math.sin(tilt)

    def on_slant(x: float, v: float, up: float) -> tuple[float, float, float]:
        """(x, along the slant from the front edge, up off the slant) -> Blender."""
        return (x, hy - v * ca + up * sa, 0.88 + v * sa + up * ca)

    for i in range(7):
        for j in range(4):
            x0 = -0.52 + i * 0.15
            v0 = 0.06 + j * 0.13
            a = on_slant(x0 + 0.075, v0 + 0.06, 0.012)
            t.rod(on_slant(x0 + 0.075, v0, 0.012), on_slant(x0 + 0.075, v0 + 0.12, 0.012), 0.008,
                  "wood_dark", square=True)
            t.rod(on_slant(x0 + 0.005, v0 + 0.06, 0.012), on_slant(x0 + 0.145, v0 + 0.06, 0.012), 0.008,
                  "wood_dark", square=True)
            if (i * 5 + j * 3) % 4:
                t.sphere(0.03, a, "metal_grey", segs=8, rings=4, scale=(1.4, 1.4, 0.25))
    t.rod(on_slant(-0.56, 0.03, 0.01), on_slant(0.56, 0.03, 0.01), 0.012, "wood_dark", square=True)     # case rim
    t.rod(on_slant(-0.56, 0.60, 0.01), on_slant(0.56, 0.60, 0.01), 0.012, "wood_dark", square=True)
    t.rod(on_slant(0.40, 0.30, 0.03), on_slant(0.60, 0.30, 0.03), 0.02, "steel_bare", square=True)      # stick
    body.build()
    k.collision([((-hx, -hy, 0.0), (hx, hy, 1.0))])


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
