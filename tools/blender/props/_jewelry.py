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
    """Velvet neck-bust (jewelry form) on a brass foot: shoulder yoke wide in X and shallow in Y,
    slender neck with a rounded top, and a pearl strand or a gold chain with a ruby pendant draped
    over the front (+Y)."""
    h = height
    p.lathe([(0.0, 0.0), (0.05, 0.0), (0.052, 0.008), (0.03, 0.014), (0.0, 0.016)], "brass", centre=(x, y, z), segs=16)
    p.cyl(0.007, h * 0.2, (x, y, z + 0.014 + h * 0.1), "brass", segs=10)
    # torso form: narrow at the stem, widening to square shoulders, wide in X and shallow in Y
    soft.lathe([(0.0, h * 0.2), (0.018, h * 0.21), (0.03, h * 0.3), (0.044, h * 0.45), (0.055, h * 0.58),
                (0.06, h * 0.63), (0.055, h * 0.665), (0.038, h * 0.685), (0.02, h * 0.695)], "velvet_charcoal",
               centre=(x, y, z), segs=20, scale_xy=(1.85, 0.6))
    # neck column with a softly domed top
    soft.lathe([(0.02, h * 0.68), (0.018, h * 0.8), (0.019, h * 0.9), (0.022, h * 0.95), (0.017, h * 0.985),
                (0.0, h)], "velvet_charcoal", centre=(x, y, z), segs=14, scale_xy=(1.0, 0.85))
    zc = z + h * 0.68
    # draped over the shoulders and down the chest; the chest surface depth is ~0.6 x radius
    def drape(t: float) -> tuple[float, float, float]:
        zz = zc - math.sin(t) * h * 0.24
        rad = 0.03 + 0.03 * math.sin(t)
        return (x - math.cos(t) * 0.05, y + rad * 0.6 + 0.004, zz)
    if pearls:
        n = 30
        for i in range(n):
            p.sphere(0.0068, drape(math.pi * i / (n - 1)), "ceramic", segs=6, rings=4)
    else:
        pts = [drape(math.pi * i / 16) for i in range(17)]
        p.tube(pts, 0.002, "brass", segs=5, joints=True)
        px, py, pz = drape(math.pi / 2)
        p.torus(0.005, 0.0015, (px, py + 0.002, pz - 0.006), "brass", segs=8, rsegs=4, axis="X")
        p.sphere(0.012, (px, py + 0.004, pz - 0.022), "car_wine", segs=10, rings=6, scale=(1.0, 0.6, 1.25))
        for sx in (-1, 1):
            p.sphere(0.005, drape(math.pi / 2 + sx * 0.6), "chrome", segs=6, rings=4)


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
