"""Small jewelry display pieces (ring trays, necklace busts, watch pillows) shared by the display
case visuals and the sales-floor dressing. Blender only. Positions are the piece's bottom-centre;
the piece faces +Y (Godot -Z)."""

from __future__ import annotations

import math

from _pb import Part

GEMS = ("chrome", "car_wine", "car_navy", "chrome", "leaf")


def ring_tray(p: Part, soft: Part, x: float, y: float, z: float, w: float = 0.24, d: float = 0.12,
              rings: int = 5, rows: int = 2, rot: bool = False) -> None:
    """Ivory leather tray with slotted rows and rings seated in the slots."""
    h = 0.028
    if rot:
        w, d = d, w
    soft.bx((x - w / 2, y - d / 2, z), (x + w / 2, y + d / 2, z + h), "fabric_ivory")
    for r in range(rows):
        if rot:
            yy = 0.0
            xx = x + (r - (rows - 1) / 2) * (w / rows)
        else:
            yy = y + (r - (rows - 1) / 2) * (d / rows)
            xx = 0.0
        for i in range(rings):
            t = (i - (rings - 1) / 2) / max(1, rings - 1)
            if rot:
                px, py = xx, y + t * (d - 0.04)
            else:
                px, py = x + t * (w - 0.04), yy
            metal = "brass" if (i + r) % 3 else "chrome"
            p.torus(0.009, 0.0018, (px, py, z + h + 0.004), metal, segs=12, rsegs=4, axis="Y" if not rot else "X")
            p.sphere(0.0035, (px, py, z + h + 0.0135), GEMS[(i + 2 * r) % len(GEMS)], segs=6, rings=4)


def bust(p: Part, soft: Part, x: float, y: float, z: float, height: float = 0.26, pearls: bool = True) -> None:
    """Suede necklace bust (neck form) with a pearl strand or a gold chain and pendant."""
    hs = height
    soft.lathe([(0.085, 0.0), (0.085, 0.01), (0.072, 0.022), (0.062, hs * 0.3), (0.046, hs * 0.62),
                (0.034, hs * 0.85), (0.03, hs), (0.0, hs)], "suede",
               centre=(x, y, z), segs=20, scale_xy=(1.15, 0.85))
    zc = z + hs * 0.58
    if pearls:
        n = 22
        for i in range(n):
            a = math.pi * 0.15 + math.pi * 0.7 * i / (n - 1)
            px = x + math.cos(a) * 0.058
            py = y + math.sin(a) * 0.05
            pz = zc - math.sin(a) * 0.035
            p.sphere(0.0072, (px, py, pz), "ceramic", segs=8, rings=5)
    else:
        pts = []
        for i in range(9):
            a = math.pi * 0.12 + math.pi * 0.76 * i / 8
            pts.append((x + math.cos(a) * 0.072, y + math.sin(a) * 0.055, zc - math.sin(a) * 0.05))
        p.tube(pts, 0.0016, "brass", segs=4, joints=False)
        p.sphere(0.009, (x, y + 0.058, zc - 0.062), "car_wine", segs=8, rings=5)


def watch_pillow(p: Part, soft: Part, x: float, y: float, z: float, metal: str = "chrome",
                 strap: str = "leather_cognac") -> None:
    """Watch strapped around a small suede pillow, dial facing +Y and up."""
    soft.sphere(0.04, (x, y, z + 0.032), "suede", segs=12, rings=6, scale=(0.9, 0.7, 0.8))
    p.torus(0.036, 0.004, (x, y, z + 0.032), strap, segs=16, rsegs=4, axis="X")
    p.cyl(0.018, 0.008, (x, y + 0.03, z + 0.045), metal, axis="Y", segs=16)
    p.cyl(0.015, 0.002, (x, y + 0.0345, z + 0.045), "plastic_white", axis="Y", segs=16)


def display_set(p: Part, soft: Part, x0: float, x1: float, y: float, z: float, seed: int, depth: float = 0.3) -> None:
    """A curated mix along a deck from x0 to x1 (bust, tray, watches) on the deck plane z."""
    span = x1 - x0
    kinds = ("bust", "tray", "watch") if seed % 2 == 0 else ("tray", "bust", "watch")
    n = max(2, min(4, int(span / 0.32)))
    for i in range(n):
        cx = x0 + span * (i + 0.5) / n
        k = kinds[i % 3]
        if k == "bust" and depth >= 0.22:
            bust(p, soft, cx, y + 0.02, z, pearls=(i + seed) % 2 == 0)
        elif k == "tray" or depth < 0.22:
            ring_tray(p, soft, cx, y, z, w=min(0.26, span / n - 0.04), d=min(0.12, depth - 0.06))
        else:
            for j in (-1, 1):
                watch_pillow(p, soft, cx + j * 0.05, y, z, "brass" if j > 0 else "chrome")
