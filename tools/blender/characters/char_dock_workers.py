"""Night-shift workers for ``dockside_burn`` (D-115, heist cast audit 2026-10-15 D-DB-1): the Pier 9
cold store's forklift drivers and a packer (``civ_worker``, the heist's hostages). Plain civilian
work wear that reads at 30 m as *workers*, never as the Co-op gunmen (``char_cartel.py``: no sling,
no slung gun, no bandana, no rust waxed jacket or cartel material ids) or the police (no navy
uniform, no police hi-vis vest cut): a loose hi-vis vest with silver reflective tape (two hoops
round the torso, braces over the shoulders), a hard hat or a beanie, work trousers, safety boots.

* ``char_dock_worker``: forklift driver, a heavy-set man in his 40s, stubble: orange hi-vis vest
  over a navy canvas work jacket (zip, collar, flap pockets), charcoal cargo work trousers, brown
  leather safety boots, a white hard hat (peak, short brim, centre ridge).
* ``char_dock_worker_b``: forklift driver (crowd variant), a younger woman, deep skin, dark bob:
  yellow hi-vis vest over a charcoal canvas work jacket, black cargo trousers, black safety boots,
  a blue hard hat.
* ``char_dock_worker_c``: dock hand (D-115, third ``civ_worker`` face), a sturdy woman in her 50s, light skin,
  grey bob under a navy knit beanie (no hard hat): orange hi-vis vest over a maroon zip fleece, blue denim work
  jeans, brown leather safety boots.
* ``char_dock_packer``: packer, an older lean man, light skin, grey stubble, in the packing wing's
  processing whites (D-116): a white smock, a yellow rubber bib apron and long yellow rubber gloves, charcoal
  work trousers, white boots and a white hygiene cap (no hi-vis: he works indoors at the packing table).

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (hard hat,
beanie). No blend shapes (baked at the params below).
"""

import math

import _cartel_gear as cgear
import _npc as n
import _outfit as o
import _outfit_garments as g
import _special_gear as sg
from _outfit import Hull, Mesh, Vector, clamp, lerp
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

VARIANTS = {
    "char_dock_worker": {"height": 1.80, "build": 0.75, "gender": 0.0, "age": 0.5, "skin": 3, "beard_shadow": 0.8,
                         "hair": "short", "hair_color": "dark", "look": "worker"},
    "char_dock_worker_b": {"height": 1.68, "build": 0.5, "gender": 1.0, "age": 0.25, "skin": 6, "hair": "bob",
                           "hair_color": "dark", "look": "worker_b"},
    "char_dock_worker_c": {"height": 1.69, "build": 0.7, "gender": 1.0, "age": 0.62, "skin": 2, "hair": "bob",
                           "hair_color": "grey", "look": "worker_c"},
    "char_dock_packer": {"height": 1.74, "build": 0.3, "gender": 0.0, "age": 0.75, "skin": 1, "beard_shadow": 0.7,
                         "hair": "short", "hair_color": "grey", "look": "packer"},
}

TAU = 6.283185307179586
ORANGE = "char_hivis_orange"
YELLOW = "char_hivis"
TAPE = "char_reflect_silver"
CHARCOAL = "char_work_charcoal"


def _z(kit: Kit) -> tuple[float, float]:
    hips_z = kit.fit.ring_centre("hips").z
    return hips_z, hips_z + 0.035 * kit.k


# =============================================================================================
# gear
# =============================================================================================
def hard_hat(fit, mat: str, gap: float = 0.024) -> Mesh:
    """Safety helmet: a smooth stiff shell standing ``gap`` off head + hair (above the brows at the
    front, over the tops of the ears, down to the occiput at the back), a short brim all round that
    grows into a peak at the front, and a raised centre ridge from the peak over the crown."""
    k = fit.k
    c = fit.head_centre()

    def el_lo(az: float) -> float:
        return lerp(22.0, -4.0, cgear._back_blend(az) ** 0.8)

    def el_hi(_az: float) -> float:
        return 86.0

    rows = [(0.0, 0.006), (0.0, gap), (0.10, gap + 0.004), (0.32, gap + 0.006), (0.56, gap + 0.006),
            (0.78, gap + 0.004), (0.94, gap + 0.002)]
    m, rings = cgear.head_wrap(fit, mat, el_lo, el_hi, rows, n_az=36, pole=True, smooth=5,
                               bottom_out=Vector((0, 0, -1)))
    inner, base = rings[0], rings[1]
    nr = len(base)
    to, bo, bi = [], [], []
    for i in range(nr):
        az = TAU * i / nr
        front = max(0.0, math.cos(az))
        p = m.v[base[i]]
        d = Vector((p.x - c.x, p.y - c.y, 0.0)).normalized()
        w = (0.011 + 0.042 * front ** 2.2) * k
        drop = (0.003 + 0.010 * front ** 2) * k
        q = p + d * w - cgear.UP * drop
        to.append(m.add(q + cgear.UP * 0.0022 * k, sg.HEAD_W))
        bo.append(m.add(q - cgear.UP * 0.0022 * k, sg.HEAD_W))
        bi.append(m.add(p - cgear.UP * 0.0045 * k, sg.HEAD_W))
    zb = sum(m.v[i].z for i in base) / nr
    m.band(base, to, mat, inside=Vector((c.x, c.y, zb - 0.5)))
    m.band(to, bo, mat, inside=Vector((c.x, c.y, zb)))
    m.band(bo, bi, mat, inside=Vector((c.x, c.y, zb + 0.5)))
    m.band(bi, inner, mat, inside=Vector((c.x, c.y, zb + 0.5)))
    # centre ridge: front (above the peak) over the crown to the back
    path = []
    for j in range(15):
        t = j / 14
        a = 0.0 if t <= 0.5 else math.pi
        el = math.radians(lerp(34.0, 90.0, t * 2.0) if t <= 0.5 else lerp(90.0, 18.0, (t - 0.5) * 2.0))
        el = min(el, math.radians(89.0))
        r = sg.head_radius(fit, a, el, c) or 0.10 * k
        d = Vector((math.cos(el) * math.sin(a), math.cos(el) * math.cos(a), math.sin(el)))
        path.append(c + d * (r + (gap + 0.0045) * k))
    o.tube(m, path, lambda t: (0.0035 + 0.0035 * math.sin(math.pi * t) ** 0.5) * k, mat, sides=6,
           weights=lambda p, t: sg.HEAD_W)
    return m


def hivis_vest(kit: Kit, mat: str, tape: str = TAPE, stand: float = 0.008) -> Mesh:
    """Loose hi-vis safety vest over the current layers: sleeveless, a V neck (clean snapped edge),
    hem at the hip, two reflective hoops round the torso and reflective braces up the front and back."""
    fit, k = kit.fit, kit.k
    hips_z, _belt_z = _z(kit)
    nk = g.Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y
    chest_z = fit.ring_centre("chest").z
    v_z = chest_z + 0.015 * k

    def v_half(z: float) -> float:
        t = clamp((z - v_z) / max(neck_z - v_z, 1e-3), 0.0, 1.0)
        return lerp(0.010 * k, 0.074 * k, t ** 0.85)

    def cut(cc: Vector) -> bool:
        if cc.y > cy - 0.01 * k:
            return cc.z > neck_z + 0.004 * k
        return cc.z > neck_z + 0.012 * k

    hull = kit.hull()
    vest = g.upper_shell(fit, mat, bottom_z=hips_z - 0.03 * k, base=0.010 + stand - 0.008, sleeveless=True,
                         hull=hull, top_cut=cut, iters=6, waist_blouse=0.0, min_off=stand * k)
    vm = vest.mesh
    # V neck: drop the faces inside the V, then snap the opening's edges onto the V line (clean edge)
    g.delete_faces(vm, lambda cc: cc.y > cy and cc.z >= v_z and abs(cc.x) < v_half(cc.z))
    g.snap_opening(vm, v_half, cy, v_z, neck_z + 0.03 * k, hull, stand * k)
    for loop in o.boundary_loops(vm.f):
        o.straighten_loop(vm, loop, iters=3)
    o.hem_all(vm, thick=0.005 * k, depth=0.014 * k)
    _torso_weights(fit, vm)
    kit.add_soft(vm)
    vh = Hull(fit, [vm], body_regions=set())
    tp = Mesh()
    ctr = fit.ring_centre("waist")
    # two hoops of tape round the torso (closed strips cast onto the vest)
    for z in (fit.ring_centre("waist").z - 0.02 * k, chest_z - 0.075 * k):
        loop = []
        for i in range(40):
            a = TAU * i / 40
            d = Vector((math.sin(a), math.cos(a), 0.0))
            hit = vh.cast(Vector((ctr.x, ctr.y, z)) + d * 0.6, -d, 0.7)
            if hit[0] is not None:
                loop.append(hit[0])
        o.strip(tp, vh, loop, 0.021 * k, 0.0025 * k, tape, side_hint=cgear.UP, segs_across=1, chamfer=0.002 * k,
                closed=True, cast_back=0.04)
    # braces: up the front and up the back from the upper hoop to the shoulder line
    z0 = chest_z - 0.075 * k + 0.021 * k
    z_top = neck_z - 0.035 * k
    for sx in (-1.0, 1.0):
        x = sx * 0.100 * k
        for y0, dy in ((0.6, -1.0), (-0.6, 1.0)):
            pts = []
            for i in range(15):
                z = lerp(z0, z_top, i / 14)
                hit = vh.cast(Vector((x, y0, z)), Vector((0, dy, 0)), 1.2)
                if hit[0] is not None:
                    pts.append(hit[0])
            o.strip(tp, vh, pts, 0.020 * k, 0.0032 * k, tape, side_hint=Vector((sx, 0, 0)), segs_across=1,
                    chamfer=0.002 * k, cast_back=0.04)
    _torso_weights(fit, tp)
    kit.add_soft(tp)
    return vm


def _torso_weights(fit, m: Mesh, arm_keep: float = 0.2) -> None:
    """D-115 clip audit: a sleeveless vest stands well off the body, so the armhole's nearest skin is the upper arm
    and those vertices were dragged up the raised arms (hands_up, surrender), tearing the vest. Keep at most
    ``arm_keep`` of an upper_arm weight; the rest goes to that side's clavicle (the vest rides the shoulder)."""
    for i, p in enumerate(m.v):
        w = dict(m.w[i]) if m.w[i] is not None else fit.weights_at(m.a[i] if m.a[i] is not None else p)
        for sfx in ("L", "R"):
            arm = w.pop(f"upper_arm.{sfx}", 0.0) + w.pop(f"forearm.{sfx}", 0.0)
            if arm > 0.0:
                w[f"upper_arm.{sfx}"] = arm * arm_keep
                w[f"clavicle.{sfx}"] = w.get(f"clavicle.{sfx}", 0.0) + arm * (1.0 - arm_keep)
        top = sorted(w.items(), key=lambda kv: (-kv[1], kv[0]))[:4]
        top = [(b, x) for b, x in top if x >= 0.01 * sum(y for _c, y in top)]
        tot = sum(x for _b, x in top)
        m.w[i] = {b: x / tot for b, x in sorted(top)}


def _boots(kit: Kit, mat: str) -> Mesh:
    s = g.shoes(kit.fit, mat, "rubber_black", top_z=0.15, base=0.0075, toe=0.013, sole_h=0.022, boot=True)
    kit.add_soft(s)
    return s


def _cargos(kit: Kit, mat: str, boots: Mesh) -> Mesh:
    k = kit.k
    _hips_z, belt_z = _z(kit)
    tr = n.trousers(kit, mat, boots, belt_z + 0.022 * k, hem_r=0.064)
    cgear.cargo_pockets(kit, tr, mat, z=0.57)
    return tr


# =============================================================================================
# looks
# =============================================================================================
def worker(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    boots = _boots(kit, "char_shoe_brown")
    tr = _cargos(kit, CHARCOAL, boots)
    n.belt(kit, tr, belt_z, mat="char_leather_black", buckle="chrome", height=0.036)
    cgear.work_jacket(kit, "char_work_navy", "char_work_navy", hips_z - 0.06 * k, 1.43 * k)
    hivis_vest(kit, ORANGE, stand=0.016)
    kit.add_head(hard_hat(fit, "char_hardhat_white"))
    kit.notes["hat"] = "white hard hat (Headwear)"
    kit.notes["headwear_class"] = "hard_hat"   # Headwear meta for A's HardHatHandLift (assemble_characters)
    n.front_item(kit, -0.090, 1.250, (0.070, 0.095, 0.010), "char_medic_white", lift=0.003)  # DB-G3: a notepad
    n.front_item(kit, -0.060, 1.270, (0.008, 0.080, 0.007), "polymer_black", lift=0.006)  # and a pen
    kit.notes["look"] = ("forklift driver: orange hi-vis vest (silver tape hoops + braces) over a navy canvas work "
                         "jacket, charcoal cargo work trousers, brown safety boots, white hard hat")


def worker_b(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, _belt_z = _z(kit)
    boots = _boots(kit, "char_shoe_black")
    _cargos(kit, "char_trousers_black", boots)
    cgear.work_jacket(kit, CHARCOAL, CHARCOAL, hips_z - 0.06 * k, 1.43 * k)
    hivis_vest(kit, YELLOW, stand=0.016)
    kit.add_head(hard_hat(fit, "char_hardhat_blue"))
    kit.notes["hat"] = "blue hard hat (Headwear)"
    kit.notes["headwear_class"] = "hard_hat"   # Headwear meta for A's HardHatHandLift (assemble_characters)
    n.lanyard(kit, "char_lanyard", "char_medic_white", card_z=1.17)                  # DB-G3: a port pass
    kit.notes["look"] = ("forklift driver B: yellow hi-vis vest (silver tape) over a charcoal canvas work jacket, "
                         "black cargo trousers, black safety boots, blue hard hat")


def worker_c(kit: Kit) -> None:
    """D-115: the third yard hand (civ_worker pool of three): beanie instead of a hard hat, maroon fleece sleeves."""
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    boots = _boots(kit, "char_shoe_brown")
    tr = n.trousers(kit, "char_denim", boots, belt_z + 0.022 * k, hem_r=0.062)
    n.belt(kit, tr, belt_z, mat="char_leather_black", buckle="chrome", height=0.034)
    fleece = g.knit_top(fit, kit.hull(), "char_fleece_maroon", hips_z - 0.05 * k, neck="roll", base=0.012, rib=0.04)
    kit.add_soft(fleece)
    hivis_vest(kit, ORANGE, stand=0.016)
    kit.add_head(cgear.beanie(fit, "char_knit_navy"))
    kit.notes["hat"] = "navy knit beanie (Headwear)"
    n.front_item(kit, 0.125, 0.975, (0.055, 0.100, 0.012), "char_apron_leather", lift=0.003,
                 up=Vector((0.2, 0.0, 1.0)))                                         # DB-G3: gloves at the waist
    kit.notes["look"] = ("dock hand C: orange hi-vis vest (silver tape hoops + braces) over a maroon fleece, blue "
                         "denim work jeans, brown safety boots, navy beanie")


def packer(kit: Kit) -> None:
    """D-116 cast polish: the packing wing's fish packer in processing whites, not a third yard hand."""
    fit, k = kit.fit, kit.k
    hips_z, _belt_z = _z(kit)
    boots = g.shoes(fit, "char_sneaker_white", "rubber_black", top_z=0.30, base=0.0075, toe=0.013, sole_h=0.022,
                    boot=True)
    kit.add_soft(boots)
    _cargos(kit, CHARCOAL, boots)
    smock = g.knit_top(fit, kit.hull(), "char_shirt_white", hips_z - 0.09 * k, neck="roll", base=0.011, rib=0.03)
    kit.add_soft(smock)
    kit.add_soft(g.gloves(fit, "char_rubber_yellow", cuff_len=0.10, base=0.003, cuff_off=0.007))
    kit.add_soft(g.apron(fit, kit.hull(), "char_rubber_yellow", 1.33 * k, 0.50 * k, strap_mat="char_rubber_yellow"))
    kit.add_head(cgear.beanie(fit, "char_shirt_white", front_el=14.0, back_el=-10.0, cuff=0.05))
    kit.notes["hat"] = "white hygiene cap over the hair (Headwear)"
    n.front_item(kit, -0.085, 1.300, (0.007, 0.120, 0.007), "char_metal_silver", lift=0.003)  # DB-G3: a probe
    n.front_item(kit, -0.085, 1.345, (0.016, 0.030, 0.012), "char_rubber_yellow", lift=0.004)  # thermometer
    kit.notes["look"] = ("packer (D-116): processing whites: white smock, yellow rubber bib apron and long gloves, "
                         "charcoal work trousers, white boots, white hygiene cap (packing wing, no hi-vis)")


_looks = {"worker": worker, "worker_b": worker_b, "worker_c": worker_c, "packer": packer}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)
    kit.notes["insignia"] = "none (civilian work wear; no police/cartel material ids)"


def build(ctx) -> None:
    build_character(ctx, recipe)
