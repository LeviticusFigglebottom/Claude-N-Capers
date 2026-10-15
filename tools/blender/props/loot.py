"""Loot stack and small-loot visuals for Shadow Ledger and Dockside Burn (D-111 prop art pass; the `loot_spawn` /
`small_loot` prefabs, visual_slots.md: no required nodes, no collision, the prefab owns the interaction).

Floor items, pivot bottom-centre, front +Y (Godot -Z). Sizes stay near the 0.6 x 0.4 m loot placeholder so the stacks
keep clear of the furniture and walls the placeholders were placed against.

* `prop_loot_weapon_crate`: two stencilled olive arms crates (pine battens, steel corners, rope handles).
* `prop_loot_contraband_bales`: three shrink-wrapped cardboard bales with strapping (the cartel product).
* `prop_loot_thermite_drum`: a red steel thermite drum with a clamp lid and a hazard band.
* `prop_loot_ledger_books`: an archive box of leather-bound ledgers, one lying on top.
* `prop_loot_ledger_drives`: an open hard case of drive sleds in foam, status LEDs lit.
* `prop_loot_laptop`: a closed laptop on its padded sleeve with the charger.
* small_loot: `prop_valuables_jewelry_case` (open leather case, ring tray, bracelet), `prop_valuables_watch_box`
  (watch on a pillow in its box), `prop_valuables_cigar_box` (cedar cigar box, lid ajar).
"""

import math

import _jewelry as jw
from _pb import Kit

TRI_BUDGET = 8000
_LOOT = {"prefab": "loot_spawn"}
_SMALL = {"prefab": "small_loot"}
VARIANTS = {
    "prop_loot_weapon_crate": {"fn": "weapon_crate", "cat": {**_LOOT, "kind": "weapon_crate", "surface": "wood"}},
    "prop_loot_contraband_bales": {"fn": "bales", "cat": {**_LOOT, "kind": "contraband"}},
    "prop_loot_thermite_drum": {"fn": "thermite_drum", "cat": {**_LOOT, "kind": "thermite", "surface": "metal"}},
    "prop_loot_ledger_books": {"fn": "ledger_books", "cat": {**_LOOT, "kind": "ledger_books"}},
    "prop_loot_ledger_drives": {"fn": "ledger_drives", "cat": {**_LOOT, "kind": "ledger_drives"}},
    "prop_loot_laptop": {"fn": "laptop", "cat": {**_LOOT, "kind": "laptop"}},
    "prop_valuables_jewelry_case": {"fn": "jewelry_case", "cat": {**_SMALL, "kind": "small_valuables"}},
    "prop_valuables_watch_box": {"fn": "watch_box", "cat": {**_SMALL, "kind": "small_valuables"}},
    "prop_valuables_cigar_box": {"fn": "cigar_box", "cat": {**_SMALL, "kind": "small_valuables"}},
}


def _crate(body, trim, soft, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> None:
    body.bx((x0 + 0.015, y0 + 0.015, z0), (x1 - 0.015, y1 - 0.015, z1 - 0.012), "metal_green_worn")
    # pine battens round each face and a lid rim
    for zb in (z0, z1 - 0.05):
        trim.bx((x0, y0, zb), (x1, y1, zb + 0.05), "wood_pine")
    for x in (x0, x1 - 0.05):
        for y in (y0, y1 - 0.04):
            trim.bx((x, y, z0 + 0.05), (x + 0.05, y + 0.04, z1 - 0.05), "wood_pine")
    trim.bx((x0 + 0.02, y0 + 0.02, z1 - 0.012), (x1 - 0.02, y1 - 0.02, z1), "metal_green_worn")
    # steel corner caps
    for x in (x0, x1):
        for y in (y0, y1):
            for z in (z0, z1):
                cx = x + (0.02 if x == x0 else -0.02)
                cy = y + (0.02 if y == y0 else -0.02)
                cz = z + (0.02 if z == z0 else -0.02)
                trim.cbox((cx, cy, cz), (0.05, 0.05, 0.045), "metal_dark")
    # stencil plate on the front, rope handles on the ends
    trim.bx(((x0 + x1) / 2 - 0.22, y1, (z0 + z1) / 2 - 0.05), ((x0 + x1) / 2 + 0.22, y1 + 0.003, (z0 + z1) / 2 + 0.05),
            "paint_ivory")
    trim.bx(((x0 + x1) / 2 - 0.2, y1 + 0.003, (z0 + z1) / 2 - 0.02), ((x0 + x1) / 2 + 0.05, y1 + 0.005,
                                                                       (z0 + z1) / 2 + 0.02), "metal_dark")
    for x, s in ((x0, -1), (x1, 1)):
        soft.tube([(x + s * 0.004, -0.08, (z0 + z1) / 2 + 0.03), (x + s * 0.04, -0.05, (z0 + z1) / 2 - 0.02),
                   (x + s * 0.04, 0.05, (z0 + z1) / 2 - 0.02), (x + s * 0.004, 0.08, (z0 + z1) / 2 + 0.03)],
                  0.008, "fabric", segs=6)


def _weapon_crate(k: Kit, p: dict) -> None:
    o = k.obj("Crates")
    body = o.part(bevel=0.004)
    trim = o.part(bevel=0.002)
    soft = o.part(bevel=0.0)
    _crate(body, trim, soft, -0.45, 0.45, -0.22, 0.22, 0.0, 0.32)
    _crate(body, trim, soft, -0.42, 0.42, -0.2, 0.2, 0.32, 0.6)
    o.build()


def _bales(k: Kit, p: dict) -> None:
    o = k.obj("Bales")
    core = o.part(bevel=0.02, segments=2)
    wrap = o.part(bevel=0.0)
    for (cx, cy, cz, w, d, h) in ((-0.24, 0.0, 0.0, 0.44, 0.42, 0.34), (0.24, 0.0, 0.0, 0.44, 0.42, 0.34),
                                  (0.02, 0.0, 0.34, 0.46, 0.4, 0.3)):
        core.bx((cx - w / 2, cy - d / 2, cz), (cx + w / 2, cy + d / 2, cz + h), "cardboard")
        # shrink-wrap film over the top and the long faces
        wrap.bx((cx - w / 2 + 0.01, cy - d / 2 - 0.003, cz + 0.02), (cx + w / 2 - 0.01, cy - d / 2, cz + h - 0.02),
                "glass_frosted")
        wrap.bx((cx - w / 2 + 0.01, cy + d / 2, cz + 0.02), (cx + w / 2 - 0.01, cy + d / 2 + 0.003, cz + h - 0.02),
                "glass_frosted")
        # two black straps round the bale and a paper label
        for sx in (-0.12, 0.12):
            x = cx + sx
            wrap.bx((x - 0.012, cy - d / 2 - 0.006, cz + 0.004), (x + 0.012, cy + d / 2 + 0.006, cz + 0.008),
                    "plastic_black")
            wrap.bx((x - 0.012, cy - d / 2 - 0.006, cz + h - 0.002), (x + 0.012, cy + d / 2 + 0.006, cz + h + 0.002),
                    "plastic_black")
            for y in (cy - d / 2 - 0.006, cy + d / 2 + 0.002):
                wrap.bx((x - 0.012, y, cz + 0.004), (x + 0.012, y + 0.004, cz + h + 0.002), "plastic_black")
        wrap.bx((cx - 0.06, cy - d / 2 - 0.007, cz + h * 0.45), (cx + 0.05, cy - d / 2 - 0.004, cz + h * 0.75), "paper")
    o.build()


def _thermite_drum(k: Kit, p: dict) -> None:
    r, h = 0.2, 0.6
    o = k.obj("Drum")
    a = o.part(bevel=0.0)
    a.lathe([(0.0, 0.0), (r - 0.01, 0.0), (r, 0.012), (r, h - 0.03), (r + 0.006, h - 0.02), (r + 0.006, h),
             (0.0, h)], "metal_red", segs=28)
    for z in (h * 0.3, h * 0.62):
        a.torus(r + 0.002, 0.008, (0.0, 0.0, z), "metal_red", segs=28, rsegs=4)
    b = o.part(bevel=0.002)
    b.torus(r + 0.006, 0.012, (0.0, 0.0, h - 0.01), "metal_dark", segs=28, rsegs=5)   # clamp ring
    b.bx((-0.03, r - 0.01, h - 0.04), (0.03, r + 0.04, h + 0.01), "metal_dark")      # clamp lever
    b.cyl(0.03, 0.02, (0.08, 0.06, h + 0.01), "metal_dark", segs=12)                  # bung
    lab = o.part(bevel=0.0)
    # hazard band: an orange label wrapped on the front half
    n = 10
    for i in range(n):
        a0 = math.pi * (0.15 + 0.7 * i / n)
        a1 = math.pi * (0.15 + 0.7 * (i + 1) / n)
        p0 = (math.cos(a0) * (r + 0.002), math.sin(a0) * (r + 0.002))
        p1 = (math.cos(a1) * (r + 0.002), math.sin(a1) * (r + 0.002))
        cx, cy = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        seg = math.dist(p0, p1)
        ang = math.atan2(cy, cx)
        lab.slab([(cx + math.cos(ang + math.pi / 2) * seg / 2, cy + math.sin(ang + math.pi / 2) * seg / 2),
                  (cx - math.cos(ang + math.pi / 2) * seg / 2, cy - math.sin(ang + math.pi / 2) * seg / 2),
                  (cx - math.cos(ang + math.pi / 2) * seg / 2 + math.cos(ang) * 0.003,
                   cy - math.sin(ang + math.pi / 2) * seg / 2 + math.sin(ang) * 0.003),
                  (cx + math.cos(ang + math.pi / 2) * seg / 2 + math.cos(ang) * 0.003,
                   cy + math.sin(ang + math.pi / 2) * seg / 2 + math.sin(ang) * 0.003)],
                 h * 0.4, h * 0.58, "safety_orange")
    o.build()


def _ledger_books(k: Kit, p: dict) -> None:
    w, d, h = 0.42, 0.32, 0.26
    o = k.obj("Archive")
    box = o.part(bevel=0.003)
    t = 0.006
    box.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, t), "cardboard")
    box.bx((-w / 2, -d / 2, 0.0), (-w / 2 + t, d / 2, h), "cardboard")
    box.bx((w / 2 - t, -d / 2, 0.0), (w / 2, d / 2, h), "cardboard")
    box.bx((-w / 2, -d / 2, 0.0), (w / 2, -d / 2 + t, h), "cardboard")
    box.bx((-w / 2, d / 2 - t, 0.0), (w / 2, d / 2, h * 0.8), "cardboard")
    box.bx((-0.08, d / 2, h * 0.35), (0.08, d / 2 + 0.002, h * 0.6), "paper")   # box label
    books = o.part(bevel=0.003)
    pages = o.part(bevel=0.0)
    # five ledgers standing spine-up inside, the last one lying on top
    x = -w / 2 + t + 0.004
    for i, bw in enumerate((0.07, 0.06, 0.075, 0.065, 0.07)):
        bh = 0.3 if i % 2 == 0 else 0.29
        cover = "leather" if i != 2 else "leather_cognac"
        books.bx((x, -0.14, t), (x + bw, 0.14, t + bh), cover)
        pages.bx((x + 0.006, -0.135, t + 0.004), (x + bw - 0.006, 0.142, t + bh - 0.004), "paper")
        books.bx((x, -0.142, t + bh * 0.7), (x + bw, -0.14, t + bh * 0.78), "brass")
        x += bw + 0.002
    books.bx((-0.17, -0.13, h + 0.06), (0.17, 0.11, h + 0.1), "leather")
    pages.bx((-0.165, -0.125, h + 0.064), (0.172, 0.105, h + 0.096), "paper")
    o.build()


def _ledger_drives(k: Kit, p: dict) -> None:
    w, d = 0.5, 0.36
    o = k.obj("Case")
    shell = o.part(bevel=0.012, segments=2)
    shell.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.14), "plastic_black")
    # open lid standing behind (hinged on the back edge), foam inside it
    shell.bx((-w / 2, -d / 2 - 0.06, 0.12), (w / 2, -d / 2, 0.12 + d), "plastic_black")
    det = o.part(bevel=0.002)
    det.bx((-w / 2 + 0.02, -d / 2 + 0.02, 0.1), (w / 2 - 0.02, d / 2 - 0.02, 0.141), "fabric_charcoal")
    det.bx((-w / 2 + 0.02, -d / 2 + 0.001, 0.14), (w / 2 - 0.02, -d / 2 + 0.002, 0.12 + d - 0.02), "fabric_charcoal")
    for sx in (-1, 1):
        det.bx((sx * 0.15 - 0.03, d / 2, 0.06), (sx * 0.15 + 0.03, d / 2 + 0.02, 0.1), "metal_dark")   # latches
    det.bx((-0.08, d / 2, 0.11), (0.08, d / 2 + 0.03, 0.125), "metal_dark")                         # handle
    led = o.part(bevel=0.0)
    for i in range(6):
        x = -0.19 + 0.076 * i
        det.bx((x - 0.03, -0.12, 0.1), (x + 0.03, 0.12, 0.17), "alu_black")
        det.bx((x - 0.026, 0.12, 0.16), (x + 0.026, 0.13, 0.172), "plastic_grey")
        led.bx((x - 0.006, 0.13, 0.163), (x + 0.006, 0.132, 0.168), "emit_led_green" if i % 3 else "emit_amber")
    o.build()


def _laptop(k: Kit, p: dict) -> None:
    o = k.obj("LaptopShell")  # not "Laptop": the SL loot prefab is named that (test_shadow_ledger_launch)
    sl = o.part(bevel=0.012, segments=2)
    sl.bx((-0.2, -0.15, 0.0), (0.2, 0.15, 0.035), "bag_black")
    lp = o.part(bevel=0.004)
    lp.bx((-0.17, -0.12, 0.035), (0.17, 0.12, 0.053), "alu_black")
    lp.bx((-0.168, -0.118, 0.053), (0.168, 0.118, 0.056), "metal_grey")
    lp.cyl(0.012, 0.002, (0.0, 0.0, 0.0565), "emit_cool", segs=12)
    ch = o.part(bevel=0.004)
    ch.bx((0.22, -0.05, 0.0), (0.3, 0.0, 0.03), "plastic_black")
    ch.tube([(0.26, 0.0, 0.015), (0.26, 0.06, 0.008), (0.2, 0.09, 0.006), (0.12, 0.13, 0.04)], 0.004, "plastic_black",
            segs=6)
    o.build()


def _jewelry_case(k: Kit, p: dict) -> None:
    w, d = 0.18, 0.12
    o = k.obj("Case")
    sh = o.part(bevel=0.004)
    sh.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.045), "leather")
    sh.bx((-w / 2, -d / 2 - 0.012, 0.04), (w / 2, -d / 2, 0.04 + d), "leather")   # open lid
    soft = o.part(bevel=0.0)
    soft.bx((-w / 2 + 0.006, -d / 2 + 0.001, 0.05), (w / 2 - 0.006, -d / 2 + 0.002, 0.03 + d), "velvet_charcoal")
    jp = o.part(bevel=0.0)
    jw.ring_tray(jp, soft, -0.03, 0.0, 0.03, w=0.1, d=0.09, rings=4, rows=2)
    jp.torus(0.03, 0.004, (0.055, 0.0, 0.05), "brass", segs=16, rsegs=4)
    for i in range(6):
        a = 2 * math.pi * i / 6
        jp.sphere(0.005, (0.055 + 0.03 * math.cos(a), 0.03 * math.sin(a), 0.054), "chrome", segs=6, rings=4)
    o.build()


def _watch_box(k: Kit, p: dict) -> None:
    o = k.obj("Box")
    sh = o.part(bevel=0.004)
    sh.bx((-0.06, -0.05, 0.0), (0.06, 0.05, 0.04), "walnut")
    sh.bx((-0.06, -0.062, 0.035), (0.06, -0.05, 0.035 + 0.1), "walnut")
    soft = o.part(bevel=0.0)
    soft.bx((-0.055, -0.045, 0.036), (0.055, 0.045, 0.041), "suede")
    jp = o.part(bevel=0.0)
    jw.watch_pillow(jp, soft, 0.0, 0.0, 0.035, metal="brass")
    o.build()


def _cigar_box(k: Kit, p: dict) -> None:
    w, d = 0.22, 0.14
    o = k.obj("Box")
    sh = o.part(bevel=0.003)
    t = 0.006
    sh.bx((-w / 2, -d / 2, 0.0), (w / 2, d / 2, t), "wood_oak")
    for x0, x1, y0, y1 in ((-w / 2, -w / 2 + t, -d / 2, d / 2), (w / 2 - t, w / 2, -d / 2, d / 2),
                           (-w / 2, w / 2, -d / 2, -d / 2 + t), (-w / 2, w / 2, d / 2 - t, d / 2)):
        sh.bx((x0, y0, 0.0), (x1, y1, 0.05), "wood_oak")
    # lid ajar, hinged at the back, propped 25 degrees
    lid = o.part(bevel=0.002)
    a = math.radians(25)
    lid.profile_x([(-d / 2, 0.05), (-d / 2 + d * math.cos(a), 0.05 + d * math.sin(a)),
                   (-d / 2 + d * math.cos(a) - t * math.sin(a), 0.05 + d * math.sin(a) + t * math.cos(a)),
                   (-d / 2 - t * math.sin(a), 0.05 + t * math.cos(a))], -w / 2, w / 2, "wood_oak")
    sh.bx((-0.05, d / 2, 0.015), (0.05, d / 2 + 0.002, 0.04), "paper")   # band label
    cg = o.part(bevel=0.0)
    for i in range(8):
        x = -w / 2 + t + 0.012 + i * 0.025
        cg.rod((x, -d / 2 + t + 0.004, 0.024), (x, d / 2 - t - 0.004, 0.024), 0.011, "leather_cognac", segs=8)
        cg.rod((x, d / 2 - t - 0.03, 0.024), (x, d / 2 - t - 0.018, 0.024), 0.0115, "brass", segs=8)
    o.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
