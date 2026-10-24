"""Special enemies + TAC Heavy (P3, pd2_fidelity L4.2-L4.9, game_overview §5, style_guide §3).

Every special is a full ``rig_humanoid`` character built with the outfit/gear APIs (``_outfit``,
``_outfit_garments``, ``_gear_kit``; TAC-based ones reuse ``char_police``'s TAC Light recipe), plus
the special gear of ``_special_gear``. Silhouette at 30 m is the design driver
(``_review/specials_silhouette_30m.png``):

* ``char_tac_heavy`` (Heavy SWAT): bulkier TAC; thick frontal armour plate over the carrier,
  two-layer pauldrons + upper-arm plates, gorget, groin flap and thigh plates; big helmet with a
  smoked visor flipped UP (head stays vulnerable, PD2). Wider shoulders and a taller, front-heavy
  head than TAC Light.
* ``char_phantom`` (Cloaker): tall and slim, near-black suit, tight balaclava, no helmet; quad-tube
  night-vision goggles whose long outer tubes splay out (the iconic snout/"ears" at eye level) on a
  mount arm that stands up over the forehead (both read in the 30 m silhouette). The
  four lenses are the separate mesh ``Goggles`` (material ``char_goggle_glow``: ORM + emission
  #3BFF6A; the assembly sets it as ``material_override`` so ENV A's PhantomBrain ramps it).
* ``char_stinger`` (Taser): TAC Light kit + a battery backpack with twin capacitor cylinders that
  stand above the shoulders, electric-blue (#59A8FF) cells/stripes/shoulder patches/helmet band,
  blue cables from the pack coiled round both forearms.
* ``char_bulwark`` (Shield): heavy TAC armour + riot helmet with a full smoked visor DOWN and a neck
  guard. Its shield is the separate asset ``char_bulwark_shield`` (``_special_shield``).
* ``char_bulwark_aegis``: the Aegis squad recolour (steel-blue armour #5D6E80, #7FC8FF accents),
  shield ``char_bulwark_aegis_shield``.
* ``char_wrecker`` (Bulldozer): the biggest figure (1.88 m body, ~1.97 m with the helmet, widest
  shoulders): black bomb suit (thick draped shells), high collar, massive pauldrons, chest plate
  with hazard-yellow stripes, armoured hood. Three head states: ``Faceplate`` (black plate with a
  hazard-yellow #E6B43A rim and an eye slit) over ``Visor`` (smoked glass) + ``HeadArmored`` (visor
  frame, brow band, chin guard and cheek plates, hidden by ENV A together with the Visor) over the
  hood's face opening (face exposed). All three are separate meshes, 100 % ``head``.
* ``char_longshot`` (Sniper): urban, no ghillie: wide-brimmed boonie hat, shemagh, light chest rig
  with a rangefinder pouch, rifle drag bag diagonally on the back (sticks up over the right
  shoulder). ``LaserOrigin`` = Marker3D child of ``Skeleton3D/HandR/Socket`` at (0, 0.06, -0.50) in
  socket (weapon) axes: the laser module's spot ahead of the grip, so the beam follows the aimed
  weapon.
* ``char_corpsman`` (Medic): TAC Light kit with a white helmet, white armbands and a big white medic
  pack (its top shows above the shoulders); the mark is an ORIGINAL design (``_special_gear.emblem``:
  a red disc carrying a white plus with round-capped arms in a thin white ring), deliberately not
  the protected Red Cross emblem (red cross on white) nor the Star of Life.
* Duty looks (D-145.3, PO-18): ``char_stinger_duty`` / ``char_bulwark_duty`` (+ ``char_bulwark_duty_shield``) carry no
  body armour for Routine and Tense (see DUTY_VARIANTS).
* ``char_brandt`` (Captain Winters analogue): heavy steel-blue armour under a knee-length command
  coat (open front), pauldrons over the coat, a crested helmet (blue crest fin front-to-back).

Faction variants (D2-01): ``char_<id>_<v>`` for every special above except Brandt / Aegis (faction-free
boss squad) and ``v`` in frd, sentinel, zero, via ``_faction.dress`` (recolour + original insignia, zero:
bone face mask, bone "skull" Wrecker faceplate); the special nodes are built by the same recipes, so
every variant keeps them. Bulwark shields per variant: ``char_bulwark_<v>_shield`` (``FACTION_SHIELDS``).

Meshes: ``Body``, ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (+ ``Faceplate``, ``Visor``,
``HeadArmored`` on the Wrecker, ``Goggles`` on the Phantom). No blend shapes (baked).
"""

import math

import _faction as faction
import _gear_kit as gk
import _outfit as o
import _outfit_garments as g
import _p5 as p5
import _special_gear as sg
import char_police as police
from _outfit import Hull, Mesh, Vector, lerp, smoothstep

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

BASE_VARIANTS = {
    "char_tac_heavy": {"height": 1.83, "build": 1.0, "gender": 0.0, "age": 0.4, "skin": 1, "beard_shadow": 0.7, "hair": "buzz",
                       "hair_color": "dark", "unit": "tac_heavy"},
    "char_phantom": {"height": 1.86, "build": 0.15, "gender": 0.0, "age": 0.3, "skin": 2, "hair": "none",
                     "hair_color": "dark", "unit": "phantom"},
    "char_stinger": {"height": 1.80, "build": 0.6, "gender": 0.0, "age": 0.35, "skin": 4, "beard_shadow": 0.5, "hair": "buzz",
                     "hair_color": "dark", "unit": "stinger"},
    "char_bulwark": {"height": 1.84, "build": 0.95, "gender": 0.0, "age": 0.4, "skin": 3, "hair": "buzz",
                     "hair_color": "brown", "unit": "bulwark"},
    "char_bulwark_aegis": {"height": 1.84, "build": 0.95, "gender": 0.0, "age": 0.35, "skin": 2, "hair": "buzz",
                           "hair_color": "dark", "unit": "bulwark", "armor": "char_aegis_steel",
                           "accent": "char_aegis_blue", "carrier": "char_aegis_steel"},
    "char_wrecker": {"height": 1.88, "build": 1.0, "gender": 0.0, "age": 0.45, "skin": 2, "hair": "buzz",
                     "hair_color": "dark", "unit": "wrecker"},
    "char_longshot": {"height": 1.80, "build": 0.45, "gender": 0.0, "age": 0.45, "skin": 5, "beard_shadow": 0.65, "hair": "short",
                      "hair_color": "dark", "unit": "longshot"},
    "char_corpsman": {"height": 1.79, "build": 0.55, "gender": 0.0, "age": 0.3, "skin": 2, "hair": "short",
                      "hair_color": "brown", "unit": "corpsman"},
    "char_brandt": {"height": 1.86, "build": 0.85, "gender": 0.0, "age": 0.75, "skin": 1, "beard_shadow": 0.45, "hair": "short",
                    "hair_color": "grey", "unit": "brandt", "armor": "char_aegis_steel", "accent": "char_aegis_blue",
                    "carrier": "char_tac_gear"},
    "char_bulwark_shield": {"unit": "shield", "face": "char_tac_helmet", "edge": "rubber_black",
                            "letters": "char_medic_white", "glass": "char_lens", "metal": "polymer_black"},
    "char_bulwark_aegis_shield": {"unit": "shield", "face": "char_aegis_steel", "edge": "rubber_black",
                                  "letters": "char_aegis_blue", "glass": "char_lens", "metal": "polymer_black"},
}
#: D2-01 faction reskins (``_faction``) of the law-enforcement specials: ``char_<id>_<variant>``, plus a
#: recoloured shield per Bulwark variant (``char_bulwark_<variant>_shield``, word = the faction's name)
FACTIONS = ("frd", "sentinel", "zero")
FACTION_ROLES = ("char_tac_heavy", "char_phantom", "char_stinger", "char_bulwark", "char_wrecker", "char_longshot",
                 "char_corpsman")
FACTION_SHIELDS = {
    "char_bulwark_frd_shield": {"unit": "shield", "faction": "frd", "face": "char_frd_helmet", "edge": "rubber_black",
                                "letters": "char_frd_yellow", "glass": "char_lens", "metal": "polymer_black",
                                "word": "FRD"},
    "char_bulwark_sentinel_shield": {"unit": "shield", "faction": "sentinel", "face": "char_sen_white",
                                     "edge": "rubber_black", "letters": "char_sen_red", "glass": "char_lens",
                                     "metal": "polymer_black", "word": "SENTINEL"},
    "char_bulwark_zero_shield": {"unit": "shield", "faction": "zero", "face": "char_zero_armor", "edge": "rubber_black",
                                 "letters": "char_zero_bone", "glass": "char_lens", "metal": "polymer_black",
                                 "word": "ZERO"},
}
#: D-145.3 (PO-18): the specials that spawn on Routine/Tense without body armour (ENV A: EnemyDef visual_variant
#: ``duty`` there): Stinger on the TAC duty base (no carrier, soft cap) with its capacitor pack, cables and blue
#: patches; Bulwark without the heavy carrier / plates / pauldrons, keeping its riot helmet (visor down) and its
#: shield (``char_bulwark_duty_shield`` = the base shield, found beside the duty scene as ``<cid>_shield``)
DUTY_VARIANTS = {
    "char_stinger_duty": {**BASE_VARIANTS["char_stinger"], "armored": False, "back_mark": False},
    "char_bulwark_duty": {**BASE_VARIANTS["char_bulwark"], "armored": False},
    "char_bulwark_duty_shield": dict(BASE_VARIANTS["char_bulwark_shield"]),
}
VARIANTS = {**BASE_VARIANTS, **FACTION_SHIELDS, **DUTY_VARIANTS,
            **{f"{aid}_{fac}": {**BASE_VARIANTS[aid], "faction": fac} for aid in FACTION_ROLES for fac in FACTIONS}}

TAC = "char_tac_charcoal"
TAC_GEAR = "char_tac_gear"
ARMOR = "char_tac_helmet"
LENS = "char_lens"
SUIT = "char_wrecker_suit"
BLACK = "char_armor_black"
HAZARD = "char_hazard_yellow"
BLUE = "char_stinger_blue"
WHITE = "char_medic_white"
DRAB = "char_sniper_drab"
PH = "char_phantom_suit"


# =============================================================================================
# shared pieces
# =============================================================================================
def _shoulder(kit, sx: float) -> Vector:
    return Vector(kit.fit.J["shoulder.R" if sx > 0 else "shoulder.L"])


def pauldrons(kit, mat: str, trim: str | None, size: float = 1.0, lift: float = 1.0, upper_arm: bool = True,
              trim_scale: float = 0.78, arm_mat: str | None = None) -> None:
    """Two-layer shoulder plates plus an upper-arm plate per side (squares and widens the shoulders)."""
    k = kit.k
    m = Mesh()
    for sx in (-1.0, 1.0):
        sh = _shoulder(kit, sx)
        # centred out on the shoulder cap (the deltoid), facing up-and-out: the plate's inner edge
        # stops short of the neck instead of riding up the trapezius
        anchor = sh + Vector((sx * 0.04 * k, 0.0, 0.0))
        tgt = sh + Vector((sx * 0.055 * k, 0.0, 0.0))
        m.extend(sg.plate(kit, tgt, Vector((sx * 0.86, 0.0, 0.51)), 0.16 * size, 0.15 * size,
                          [(1.0, 0.022 * lift, mat)] + ([(trim_scale, 0.018 * lift, trim)] if trim else []),
                          up=Vector((0, 1, 0)), r=0.035,
                          anchor=anchor))
        if not upper_arm:
            continue
        el = Vector(kit.fit.J["elbow.R" if sx > 0 else "elbow.L"])
        mid = sh.lerp(el, 0.42)
        m.extend(sg.plate(kit, mid, Vector((sx, 0.0, 0.35)), 0.09 * size, 0.12 * size, [(1.0, 0.016 * lift, arm_mat or mat)],
                          up=(sh - el).normalized(), r=0.02, anchor=mid))
    kit.add_gear(m)


def heavy(kit, armor: str, accent: str, carrier: str, shoulder_plates: bool = True) -> dict:
    """Heavy TAC body: TAC uniform, thick carrier with a frontal armour plate, gorget, groin flap,
    thigh plates, knee pads, gloves, belt kit. Returns the uniform info."""
    fit, k = kit.fit, kit.k
    base = police._base_uniform(kit, TAC, TAC, "band", boots=True)
    belt = base["belt"]
    kit.add_gear(gk.knee_pads(fit, kit.hull()))
    kit.add_soft(g.gloves(fit, "char_tac_glove", base=0.0035, cuff_len=0.07, cuff_off=0.007))
    hull = kit.hull()
    pc = Mesh()
    o.patch(pc, hull, Vector((0.0, 0.0, 1.25 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.34 * k, 0.36 * k, 0.03 * k, 3), 0.050 * k, carrier, cast_dir=Vector((0, -1, 0)),
            rings=4, chamfer=0.009 * k)
    o.patch(pc, hull, Vector((0.0, 0.0, 1.27 * k)), Vector((-1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.34 * k, 0.37 * k, 0.03 * k, 3), 0.045 * k, carrier, cast_dir=Vector((0, 1, 0)),
            rings=4, chamfer=0.009 * k)
    cb = gk.Belt(fit, Hull(fit, [base["shirt"]], body_regions=set()), 1.14 * k, height=0.17, thick=0.034, drop=0.0,
                 gap=0.006)
    pc.extend(cb.mesh(carrier))
    ph = Hull(fit, [pc, base["shirt"]])
    nk = g.Neck(fit)
    for sx in (-1.0, 1.0):
        pts = []
        for t in [i / 10 for i in range(11)]:
            a = sx * (0.35 + (math.pi - 0.7) * t)
            q = nk.point(a, 0.0, 0.035 * k)
            q.z = 1.40 * k + 0.07 * k * math.sin(math.pi * t)
            q.x = sx * (0.085 * k + 0.035 * k * math.sin(math.pi * t))
            pts.append(q)
        pts = [o.push_out(q, ph, 0.004 * k) for q in pts]
        o.strip(pc, ph, pts, 0.03 * k, 0.009 * k, carrier, segs_across=2, chamfer=0.003 * k)
    kit.add_soft(pc)
    # frontal armour plate (PD2 heavy: frontal plate) and a gorget round the front of the neck
    chest_anchor = Vector((0.0, fit.ring_centre("chest").y, 1.30 * k))
    kit.add_gear(sg.plate(kit, Vector((0.0, 0.0, 1.29 * k)), Vector((0, 1, 0)), 0.30, 0.30,
                          [(1.0, 0.024, armor), (0.84, 0.010, armor)], r=0.04, anchor=chest_anchor))
    gor = Mesh()
    path = [nk.point(a, 0.15, 0.03 * k) for a in [math.radians(x) for x in range(-100, 101, 20)]]
    o.strip(gor, kit.hull(), path, 0.032 * k, 0.018 * k, armor, side_hint=o.UP, segs_across=2, chamfer=0.004 * k,
            cast_back=0.08)
    kit.add_gear(gor)
    # groin flap and thigh plates
    hips = fit.ring_centre("hips")
    kit.add_gear(sg.plate(kit, Vector((0.0, hips.y, hips.z - 0.05 * k)), Vector((0, 1, -0.05)), 0.20, 0.17,
                          [(1.0, 0.02, armor)], r=0.04, anchor=Vector((0.0, hips.y, hips.z))))
    for sx in (-1.0, 1.0):
        th = fit.ring_centre("thigh.R" if sx > 0 else "thigh.L")
        tgt = Vector((th.x, th.y, 0.72 * k))
        kit.add_gear(sg.plate(kit, tgt, Vector((sx * 0.35, 1.0, 0.0)), 0.12, 0.17, [(1.0, 0.016, armor)], r=0.03,
                              anchor=tgt))
    # belt kit
    gear = Mesh()
    gear.extend(gk.buckle(belt, "polymer_black", w=0.055, h=0.045))
    gear.extend(gk.pouch(belt, math.radians(-140.0), 0.08, 0.07, 0.035, carrier, snap="polymer_black"))
    gear.extend(gk.pouch(belt, math.radians(140.0), 0.08, 0.07, 0.035, carrier, snap="polymer_black"))
    gear.extend(gk.holster(belt, math.radians(100.0)))
    for a in (-60.0, 60.0):
        mtx = cb.frame(math.radians(a), dz=-0.02 * k)
        gp = o.Gear()
        gp.box((-0.035 * k, -0.06 * k, 0.0), (0.035 * k, 0.05 * k, 0.04 * k), carrier)
        gp.box((-0.038 * k, 0.03 * k, 0.036 * k), (0.038 * k, 0.055 * k, 0.046 * k), accent)
        gp.bevel(0.004 * k, 1, 30.0)
        gear.extend(gp.to_mesh(mtx, anchor=cb.point(math.radians(a))))
    kit.add_gear(gear)
    if shoulder_plates:
        pauldrons(kit, armor, accent)
    kit.seats["Hip"] = belt.point(math.radians(140.0), dz=0.0, out=0.05 * k)
    return base


def shell_radius(hull: Hull, c: Vector, az: float, z: float) -> float:
    d = Vector((math.sin(az), math.cos(az), 0.0))
    hit = hull.cast(Vector((c.x, c.y, z)) + d * 0.5, -d, 0.5)
    return (0.5 - hit[3]) if hit[0] is not None else 0.12


def big_helmet(kit, mat: str, gap: float = 0.040, cup_r: float = 0.045) -> tuple[Mesh, Hull]:
    helm, _info = gk.helmet(kit.fit, mat, gap=gap, cup_r=cup_r)
    kit.add_head(helm)
    return helm, Hull(kit.fit, [helm], body_regions=set())


def visor(kit, helm_hull: Hull, down: bool, frame: str, glass: str = LENS) -> None:
    """Smoked riot visor on the helmet: ``down`` covers the face (Bulwark), else flipped up onto the
    helmet front (TAC Heavy). Pivot hubs at the sides."""
    fit, k = kit.fit, kit.k
    c = fit.head_centre()
    eye = fit.eye_centre()
    if down:
        z0, z1 = eye.z - 0.135 * k, eye.z + 0.06 * k
        a0 = math.radians(72.0)
        rt = {az: shell_radius(helm_hull, c, az, z1) for az in [lerp(-a0, a0, i / 14) for i in range(15)]}

        def r_fn(az: float, z: float) -> float:
            base = min(rt.values(), key=lambda v: v)
            rr = rt[min(rt, key=lambda q: abs(q - az))]
            return max(rr, base) + 0.008 * k + 0.20 * (z1 - z)
    else:
        z0, z1 = eye.z + 0.075 * k, eye.z + 0.13 * k
        a0 = math.radians(64.0)

        def r_fn(az: float, z: float) -> float:
            return shell_radius(helm_hull, c, az, z) + 0.009 * k

    def mt(u: float, v: float) -> str:
        if u < 0.05 or u > 0.95 or v < 0.1 or v > 0.88:
            return frame
        return glass

    m = sg.curved_panel(c, -a0, a0, z0, z1, r_fn, 0.006 * k, mt, nu=14, nv=6 if down else 3, side_mat=frame)
    zh = z1 - 0.01 * k if down else lerp(z0, z1, 0.4)
    for sx in (-1.0, 1.0):
        az = sx * (a0 + math.radians(4.0))
        rr = shell_radius(helm_hull, c, az, zh)
        p = Vector((c.x + rr * math.sin(az), c.y + rr * math.cos(az), zh))
        gp = o.Gear()
        gp.cyl(0.018 * k, 0.012 * k, centre=(0, 0, 0.006 * k), axis="Z", segs=12, mat=frame)
        gp.bevel(0.002 * k, 1, 30.0)
        m.extend(gp.to_mesh(o.frame_from(p, Vector((math.sin(az), math.cos(az), 0.0))), weights=sg.HEAD_W))
    kit.add_head(m)


# =============================================================================================
# recipes
# =============================================================================================
def tac_heavy(kit) -> None:
    heavy(kit, ARMOR, TAC_GEAR, TAC_GEAR, shoulder_plates=False)
    # PP-D-1: matte white pauldron trim (metallic steel read too dark at 40 m) so the near-black heavy keeps a readable shoulder line at 30-40 m
    accent = kit.opts.get("shoulder_accent", "char_glove_white")
    pauldrons(kit, ARMOR, accent, size=1.3, lift=1.7, trim_scale=0.92, arm_mat=accent)
    _helm, hh = big_helmet(kit, ARMOR, gap=0.05, cup_r=0.048)
    visor(kit, hh, down=False, frame="polymer_black")
    _silhouette_accent(kit, hh, accent)
    kit.notes["hat"] = "heavy helmet, visor up (Headwear)"


def _silhouette_accent(kit, helm_hull: Hull, accent: str) -> None:
    """D-165 dark-map read: the near-black heavy vanished from behind past ~30 m (the white pauldrons only carry the
    front and sides). A light band round the sides and back of the helmet, below the flipped-up visor, and two
    reflective stripes across the upper back of the armour, in the pauldron accent (faction-neutral: no lettering)."""
    fit, k = kit.fit, kit.k
    c = fit.head_centre()
    z = fit.eye_centre().z + 0.035 * k
    path = []
    for i in range(25):                                   # 70 degrees either side of straight back
        az = math.radians(70.0 + 220.0 * i / 24)
        d = Vector((math.sin(az), math.cos(az), 0.0))
        hit = helm_hull.cast(Vector((c.x, c.y, z)) + d * 0.3, -d, 0.3)
        path.append(hit[0] if hit[0] is not None else Vector((c.x, c.y, z)) + d * 0.12 * k)
    band = Mesh()
    o.strip(band, helm_hull, path, 0.016 * k, 0.003 * k, accent, closed=False, segs_across=1, chamfer=0.002 * k,
            side_hint=o.UP, cast_back=0.05, weights=sg.HEAD_W)
    kit.add_head(band)
    cy = fit.ring_centre("chest").y
    hull = kit.hull()
    anchor = p5._back_hit(hull, 0.0, 1.26 * k, cy - 0.14 * k)       # rigid to the chest, like a stamp
    m = Mesh()
    for dz in (0.020, -0.020):                            # two stripes across the carrier back, each cast per cm
        z0 = (1.26 + dz) * k
        path = [p5._back_hit(hull, -0.13 * k + 0.26 * k * i / 26, z0, cy - 0.14 * k) for i in range(27)]
        o.strip(m, hull, path, 0.011 * k, 0.0025 * k, accent, side_hint=o.UP, segs_across=1, chamfer=0.001 * k,
                cast_back=0.05, anchor=anchor)
    kit.add_gear(m)


def duty_body(kit) -> None:
    """D-145.3 Bulwark duty body: the TAC uniform with knee pads, gloves and belt kit (magazine pouches, radio,
    holster), POLICE across the back; no carrier, plates or pauldrons."""
    fit, k = kit.fit, kit.k
    base = police._base_uniform(kit, TAC, TAC, "band", boots=True)
    belt = base["belt"]
    kit.add_gear(gk.knee_pads(fit, kit.hull()))
    kit.add_soft(g.gloves(fit, "char_tac_glove", base=0.0035, cuff_len=0.07, cuff_off=0.007))
    gear = Mesh()
    gear.extend(gk.buckle(belt, "polymer_black", w=0.055, h=0.045))
    for a_deg in (-28.0, -48.0, -68.0):
        gear.extend(gk.pouch(belt, math.radians(a_deg), 0.05, 0.085, 0.032, TAC_GEAR, snap="polymer_black"))
    gear.extend(gk.radio(belt, math.radians(-100.0)))
    gear.extend(gk.pouch(belt, math.radians(-140.0), 0.08, 0.07, 0.035, TAC_GEAR, snap="polymer_black"))
    gear.extend(gk.holster(belt, math.radians(100.0)))
    kit.add_gear(gear)
    p5.stamp_back(kit, "POLICE", 1.27, 0.075, "char_hivis")
    kit.seats["Hip"] = belt.point(math.radians(-140.0), dz=0.0, out=0.05 * k)


def bulwark(kit) -> None:
    armor = kit.opts.get("armor", ARMOR)
    accent = kit.opts.get("accent", "polymer_black")
    if kit.opts.get("armored", True):
        heavy(kit, armor, accent, kit.opts.get("carrier", TAC_GEAR))
    else:
        duty_body(kit)
    helm, hh = big_helmet(kit, armor, gap=0.044, cup_r=0.046)
    del helm
    visor(kit, hh, down=True, frame=accent)
    # neck guard (ballistic curtain) hanging from the helmet back
    fit, k = kit.fit, kit.k
    c = fit.head_centre()
    eye = fit.eye_centre()
    a0 = math.radians(115.0)

    def r_fn(az: float, z: float) -> float:
        top = eye.z - 0.01 * k
        return shell_radius(hh, c, az, top) + 0.004 * k + 0.12 * (top - z)

    curtain = sg.curved_panel(c, a0, 2 * math.pi - a0, eye.z - 0.10 * k, eye.z - 0.01 * k, r_fn, 0.012 * k,
                              armor, nu=10, nv=2)
    kit.add_head(curtain)
    kit.notes["hat"] = "riot helmet, visor down, neck guard (Headwear)"


def phantom(kit) -> None:
    fit, k = kit.fit, kit.k
    base = police._base_uniform(kit, PH, PH, "band", boots=True)
    belt = base["belt"]
    kit.add_soft(g.gloves(fit, "char_tac_glove", base=0.003, cuff_len=0.06, cuff_off=0.006))
    # slim harness: two straps crossing the chest and back, small pouches
    hull = kit.hull()
    hm = Mesh()
    nk = g.Neck(fit)
    for sx in (-1.0, 1.0):
        sh = _shoulder(kit, sx)
        top = nk.point(sx * math.pi / 2, 0.0, 0.02 * k)
        pts = []
        for t in [i / 8 for i in range(9)]:
            pts.append(Vector((lerp(top.x * 1.3, -sx * 0.10 * k, t), 0.3, lerp(sh.z + 0.02 * k, belt.z + 0.05 * k, t))))
        path = []
        for q in pts:
            hit = hull.cast(q, Vector((0, -1, 0)), 0.6)
            path.append(hit[0] if hit[0] is not None else q)
        o.strip(hm, hull, path, 0.016 * k, 0.005 * k, "polymer_black", segs_across=1, chamfer=0.002 * k)
    kit.add_soft(hm)
    gear = Mesh()
    gear.extend(gk.buckle(belt, "polymer_black", w=0.05, h=0.04))
    for a in (-120.0, 120.0, -150.0):
        gear.extend(gk.pouch(belt, math.radians(a), 0.06, 0.06, 0.03, PH, snap="polymer_black"))
    gear.extend(gk.holster(belt, math.radians(100.0)))
    kit.add_gear(gear)
    # tight balaclava (no eye holes: the goggles sit over it)
    bala, _rings = sg.head_dome(fit, PH, lambda az, el: 0.011 + 0.012 * smoothstep(-0.1, -0.7, el) * smoothstep(-0.2, 0.6, math.cos(az)), el_min=-62.0, n_az=28, n_el=10, smooth=0, neck=0.016, neck_mat=PH)
    kit.add_head(bala)
    bh = Hull(fit, [bala], body_regions=set())
    eye = fit.eye_centre()
    hit = bh.cast(Vector((0.0, 0.5, eye.z)), Vector((0, -1, 0)), 1.0)
    yf = max(hit[0].y if hit[0] is not None else eye.y + 0.02 * k, eye.y + 0.012 * k)
    # quad-tube night vision: inner pair straight, outer pair splayed 14 deg; housing bridge; straps
    head = Mesh()
    lens = Mesh()
    # long tubes and a wide splay so the snout reads in the 30 m silhouette
    tube_len = 0.130 * k
    rad = 0.0180 * k
    zt = eye.z + 0.004 * k
    tubes = [(-0.025, 0.0), (0.025, 0.0), (-0.072, -34.0), (0.072, 34.0)]
    for x, ang in tubes:
        a = math.radians(ang)
        d = Vector((math.sin(a), math.cos(a), 0.0))
        start = Vector((x * k, yf + 0.012 * k, zt))
        gp = o.Gear()
        gp.cyl(rad, tube_len, centre=(0, 0, tube_len / 2), axis="Z", segs=14, mat="polymer_black")
        gp.cyl(rad * 1.12, 0.012 * k, centre=(0, 0, tube_len - 0.006 * k), axis="Z", segs=14, mat="rubber_black")
        gp.bevel(0.002 * k, 1, 30.0)
        mtx = o.frame_from(start, d)
        head.extend(gp.to_mesh(mtx, weights=sg.HEAD_W))
        gl = o.Gear()
        gl.cyl(rad * 0.86, 0.004 * k, centre=(0, 0, tube_len + 0.0015 * k), axis="Z", segs=14, mat="char_goggle_glow")
        lens.extend(gl.to_mesh(mtx, weights=sg.HEAD_W))
    gp = o.Gear()
    gp.box((-0.08 * k, -0.022 * k, 0.0), (0.08 * k, 0.026 * k, 0.03 * k), "polymer_black")
    gp.box((-0.016 * k, 0.02 * k, 0.004 * k), (0.016 * k, 0.07 * k, 0.026 * k), "polymer_black")   # mount
    gp.bevel(0.004 * k, 1, 30.0)
    head.extend(gp.to_mesh(o.frame_from(Vector((0.0, yf - 0.002 * k, zt)), Vector((0, 1, 0))), weights=sg.HEAD_W))
    # mount arm: rises from the housing over the forehead to a shroud block on the crown strap, standing
    # proud of the head (the raised NVG arm is the second silhouette cue)
    bh_top = bh.cast(Vector((0.0, yf - 0.035 * k, eye.z + 0.5)), Vector((0, 0, -1)), 1.0)
    z_fore = bh_top[0].z if bh_top[0] is not None else eye.z + 0.06 * k
    arm_pts = [Vector((0.0, yf + 0.010 * k, zt + 0.026 * k)), Vector((0.0, yf + 0.016 * k, zt + 0.060 * k)),
               Vector((0.0, yf + 0.006 * k, max(zt + 0.105 * k, z_fore + 0.042 * k))),
               Vector((0.0, yf - 0.030 * k, max(zt + 0.116 * k, z_fore + 0.050 * k)))]
    o.tube(head, arm_pts, 0.0085 * k, "polymer_black", sides=6, weights=lambda p, t: sg.HEAD_W)
    gp = o.Gear()
    gp.box((-0.022 * k, -0.018 * k, 0.0), (0.022 * k, 0.018 * k, 0.026 * k), "polymer_black")
    gp.bevel(0.004 * k, 1, 30.0)
    top_blk = arm_pts[-1] - Vector((0.0, 0.0, 0.020 * k))
    head.extend(gp.to_mesh(o.frame_from(top_blk, Vector((0, 0.35, 1.0)).normalized()), weights=sg.HEAD_W))
    # head strap ring round the balaclava and a crown strap
    c = fit.head_centre()
    ring = []
    for i in range(29):
        az = 2 * math.pi * i / 28
        zz = zt + 0.02 * k * (1 - math.cos(az)) * 0.5
        r = shell_radius(bh, c, az, zz) + 0.003 * k
        ring.append(Vector((c.x + r * math.sin(az), c.y + r * math.cos(az), zz)))
    o.tube(head, ring, 0.0065 * k, "polymer_black", sides=4, weights=lambda p, t: sg.HEAD_W, caps=False)
    crown = []
    for i in range(9):
        el = math.radians(lerp(20.0, 160.0, i / 8))
        d = Vector((0.0, math.cos(el), math.sin(el)))
        r = (sg.head_radius(fit, 0.0 if el < math.pi / 2 else math.pi, math.atan2(d.z, abs(d.y)), c) or 0.1 * k)
        crown.append(c + d * (r + 0.009 * k))
    o.tube(head, crown, 0.0065 * k, "polymer_black", sides=4, weights=lambda p, t: sg.HEAD_W)
    kit.add_head(head)
    kit.extra["Goggles"] = lens
    kit.overrides["Goggles"] = "res://world/materials/char_goggle_glow.tres"
    kit.seats["Hip"] = belt.point(math.radians(120.0), dz=0.0, out=0.045 * k)
    kit.notes["hat"] = "balaclava + quad-tube NVG (Headwear); lenses = Goggles (emissive)"


def stinger(kit) -> None:
    police.tac(kit)
    fit, k = kit.fit, kit.k
    pack, mtx, anchor = sg.backpack(kit, 0.30, 0.34, 0.12, 1.26, "polymer_black", trim=TAC_GEAR)
    gp = o.Gear()
    w, h, d = 0.30 * k, 0.34 * k, 0.12 * k
    for sx in (-1.0, 1.0):
        x = sx * 0.16 * k
        gp.cyl(0.038 * k, 0.40 * k, centre=(x, h / 2 + 0.14 * k, d * 0.55), axis="Y", segs=14, mat="polymer_black")
        for yy in (0.08, 0.18, 0.28):
            gp.cyl(0.041 * k, 0.02 * k, centre=(x, h / 2 + yy * k, d * 0.55), axis="Y", segs=14, mat=BLUE)
        gp.cyl(0.028 * k, 0.03 * k, centre=(x, h / 2 + 0.35 * k, d * 0.55), axis="Y", segs=12, mat=BLUE)
    for yy in (0.06, -0.06):
        gp.box((-w / 2 + 0.02 * k, yy * k - 0.012 * k, d - 0.004 * k), (w / 2 - 0.02 * k, yy * k + 0.012 * k,
               d + 0.008 * k), BLUE)
    gp.bevel(0.003 * k, 1, 30.0)
    pack.extend(gp.to_mesh(mtx, anchor=anchor))
    kit.add_gear(pack)
    hull = kit.hull()
    cables = Mesh()
    for sx in (-1.0, 1.0):
        sh = _shoulder(kit, sx)
        el = Vector(fit.J["elbow.R" if sx > 0 else "elbow.L"])
        wr = Vector(fit.J["wrist.R" if sx > 0 else "wrist.L"])
        # pack mtx: local +X is the character's left seen from behind -> use world positions
        start = mtx @ Vector((-sx * w / 2, -h / 2 + 0.06 * k, d * 0.5))
        p1 = sh + Vector((sx * 0.03 * k, -0.07 * k, -0.08 * k))
        rr = sg.limb_radius(hull, sh.lerp(el, 0.6), el - sh)
        out = Vector((0, -1, 0.0)).cross(el - sh).normalized() * -sx
        p2 = sh.lerp(el, 0.6) + Vector((0, -0.6, 0)).normalized() * (rr + 0.012 * k)
        p3 = el + Vector((0, -1, 0)) * (sg.limb_radius(hull, el, wr - el) + 0.012 * k)
        del out
        pts = [start, start.lerp(p1, 0.5) + Vector((0, -0.03 * k, 0)), p1, p2, p3]
        o.tube(cables, pts, 0.0065 * k, BLUE, sides=6)
        a = el.lerp(wr, 0.08)
        b = el.lerp(wr, 0.86)
        r = sg.limb_radius(hull, el.lerp(wr, 0.5), wr - el) + 0.010 * k
        sg.helix(cables, a, b, r, 6.0, 0.0045 * k, BLUE, steps=96)
    kit.add_soft(cables)
    # blue shoulder patches and (armoured: on the helmet) band
    for sx in (-1.0, 1.0):
        sh = _shoulder(kit, sx)
        el = Vector(fit.J["elbow.R" if sx > 0 else "elbow.L"])
        p = sh.lerp(el, 0.32)
        kit.add_gear(sg.plate(kit, p, Vector((sx, 0.0, 0.2)), 0.07, 0.07, [(1.0, 0.004, BLUE)], up=(sh - el), r=0.012,
                              anchor=p))
    if not kit.opts.get("armored", True):
        kit.notes["hat"] = "soft charcoal duty cap (Headwear), no helmet (D-145.3); pack, cables and patches keep the blue"
        return
    hh = Hull(fit, [kit.head], body_regions=set())
    c = fit.head_centre()
    eye = fit.eye_centre()
    band = []
    for i in range(29):
        az = 2 * math.pi * i / 28
        zz = eye.z + 0.062 * k + 0.012 * k * math.cos(az)
        r = shell_radius(hh, c, az, zz) + 0.002 * k
        band.append(Vector((c.x + r * math.sin(az), c.y + r * math.cos(az), zz)))
    bm = Mesh()
    o.tube(bm, band, 0.006 * k, BLUE, sides=4, weights=lambda p, t: sg.HEAD_W, caps=False)
    kit.add_head(bm)
    kit.notes["hat"] = "TAC helmet with an electric-blue band (Headwear)"


def corpsman(kit) -> None:
    police.tac(kit)
    # PP-D-1: small white shoulder caps (lighter shoulder line on the dark TAC kit)
    pauldrons(kit, WHITE, None, size=0.75, lift=0.6, upper_arm=False)
    fit, k = kit.fit, kit.k
    kit.head.m = [WHITE if x == "char_tac_helmet" else x for x in kit.head.m]
    hh = Hull(fit, [kit.head], body_regions=set())
    c = fit.head_centre()
    eye = fit.eye_centre()
    em = Mesh()
    for az in (0.0, math.radians(-90.0), math.radians(90.0), math.pi):
        zz = eye.z + (0.075 if az == 0.0 else 0.07) * k
        d = Vector((math.sin(az), math.cos(az), 0.25))
        mtx, _loc = o.surface_frame(hh, Vector((c.x, c.y, zz)), d, up=o.UP, reach=0.4)
        em.extend(sg.emblem(mtx, k, 0.024, weights=sg.HEAD_W))
    # D-165: every medic mark in its own `Marks` mesh, which the assembler keeps at full detail (lod_bias): merged
    # into the helmet / armband / pack surfaces, the renderer's automatic LODs ate the white plus from 20 m on
    marks = Mesh()
    marks.extend(em)
    # white armbands with the mark on both upper arms
    hull = kit.hull()
    arms = Mesh()
    for sx in (-1.0, 1.0):
        sh = _shoulder(kit, sx)
        el = Vector(fit.J["elbow.R" if sx > 0 else "elbow.L"])
        ctr = sh.lerp(el, 0.45)
        ax = (el - sh).normalized()
        s1 = ax.cross(o.UP).normalized()
        s2 = ax.cross(s1).normalized()
        path = []
        for i in range(17):
            a = 2 * math.pi * i / 16
            dd = s1 * math.cos(a) + s2 * math.sin(a)
            hit = hull.cast(ctr + dd * 0.3, -dd, 0.3)
            path.append(hit[0] if hit[0] is not None else ctr + dd * 0.05)
        o.strip(arms, hull, path[:-1], 0.035 * k, 0.003 * k, WHITE, closed=True, segs_across=1, chamfer=0.002 * k,
                side_hint=ax, cast_back=0.05)
        ah = kit.hull(arms)
        mtx, loc = o.surface_frame(ah, ctr, Vector((sx, 0.0, 0.25)), up=-ax)
        marks.extend(sg.emblem(mtx, k, 0.022, anchor=loc))
    kit.add_gear(arms)
    # medic pack (white, mark on the back, red lid stripe); its top shows above the shoulders
    pack, mtx, anchor = sg.backpack(kit, 0.46, 0.50, 0.16, 1.42, WHITE, trim="char_medic_red")
    marks.extend(sg.emblem(mtx @ o.Matrix.Translation((0.0, -0.02 * k, 0.166 * k)), k, 0.07, anchor=anchor))
    kit.extra["Marks"] = marks
    gp = o.Gear()
    for sx in (-1.0, 1.0):
        gp.box((sx * 0.23 * k - 0.025 * k, -0.17 * k, 0.02 * k), (sx * 0.23 * k + 0.025 * k, 0.08 * k, 0.13 * k), TAC_GEAR)
    gp.bevel(0.006 * k, 1, 30.0)
    pack.extend(gp.to_mesh(mtx, anchor=anchor))
    kit.add_gear(pack)
    kit.notes["hat"] = "white TAC helmet with the Corpsman mark (Headwear)"
    kit.notes["medic_mark"] = "original: red disc, white round-capped plus, thin white ring (not the Red Cross emblem)"


def longshot(kit) -> None:
    fit, k = kit.fit, kit.k
    base = police._base_uniform(kit, TAC, TAC, "fold", boots=True)
    belt = base["belt"]
    kit.add_soft(g.gloves(fit, "char_tac_glove", base=0.003, cuff_len=0.05, cuff_off=0.006))
    # light chest rig
    hull = kit.hull()
    rig = Mesh()
    o.patch(rig, hull, Vector((0.0, 0.0, 1.20 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.30 * k, 0.17 * k, 0.025 * k, 3), 0.014 * k, DRAB, cast_dir=Vector((0, -1, 0)), rings=3,
            chamfer=0.005 * k)
    rh = Hull(fit, [rig, base["shirt"]])
    nk = g.Neck(fit)
    for sx in (-1.0, 1.0):
        pts = []
        for t in [i / 10 for i in range(11)]:
            a = sx * (0.45 + (math.pi - 0.9) * t)
            q = nk.point(a, 0.0, 0.03 * k)
            q.z = lerp(1.27 * k, 1.27 * k, t) + 0.15 * k * math.sin(math.pi * t)
            q.x = sx * (0.08 * k + 0.03 * k * math.sin(math.pi * t))
            pts.append(q)
        pts = [o.push_out(q, rh, 0.003 * k) for q in pts]
        o.strip(rig, rh, pts, 0.018 * k, 0.005 * k, DRAB, segs_across=1, chamfer=0.002 * k)
    kit.add_soft(rig)
    hull = kit.hull()
    gear = Mesh()
    for x in (-0.09, -0.03, 0.03):
        mtx, loc = o.surface_frame(hull, Vector((x * k, 0.3, 1.20 * k)), Vector((0, 1, 0)))
        gp = o.Gear()
        gp.box((-0.026 * k, -0.055 * k, 0.0), (0.026 * k, 0.05 * k, 0.03 * k), DRAB)
        gp.box((-0.028 * k, 0.025 * k, 0.026 * k), (0.028 * k, 0.05 * k, 0.034 * k), DRAB)
        gp.bevel(0.004 * k, 1, 30.0)
        gear.extend(gp.to_mesh(mtx, anchor=loc))
    # rangefinder pouch (right of centre) with the rangefinder's lens showing
    mtx, loc = o.surface_frame(hull, Vector((0.095 * k, 0.3, 1.21 * k)), Vector((0.1, 1, 0)))
    gp = o.Gear()
    gp.box((-0.04 * k, -0.05 * k, 0.0), (0.04 * k, 0.04 * k, 0.05 * k), DRAB)
    gp.box((-0.032 * k, 0.03 * k, 0.008 * k), (0.032 * k, 0.07 * k, 0.044 * k), "polymer_black")
    gp.cyl(0.012 * k, 0.012 * k, centre=(0.013 * k, 0.074 * k, 0.026 * k), axis="Y", segs=12, mat=LENS)
    gp.cyl(0.012 * k, 0.012 * k, centre=(-0.013 * k, 0.074 * k, 0.026 * k), axis="Y", segs=12, mat=LENS)
    gp.bevel(0.003 * k, 1, 30.0)
    gear.extend(gp.to_mesh(mtx, anchor=loc))
    gear.extend(gk.buckle(belt, "polymer_black", w=0.05, h=0.04))
    gear.extend(gk.pouch(belt, math.radians(-130.0), 0.07, 0.06, 0.03, DRAB, snap="polymer_black"))
    gear.extend(gk.holster(belt, math.radians(100.0)))
    kit.add_gear(gear)
    # rifle drag bag diagonally on the back (top over the right shoulder)
    hull = kit.hull()
    mtx, loc = o.surface_frame(hull, Vector((0.02 * k, -0.3, 1.16 * k)), Vector((0, -1, 0)), up=o.UP)
    gp = o.Gear()
    L, W, D = 1.12 * k, 0.15 * k, 0.085 * k
    gp.box((-W / 2, -L / 2, 0.006 * k), (W / 2, L / 2, D), DRAB)
    gp.box((-W / 2 - 0.004 * k, L / 2 - 0.06 * k, 0.0), (W / 2 + 0.004 * k, L / 2 + 0.004 * k, D + 0.006 * k), TAC_GEAR)
    gp.box((-W / 2 - 0.004 * k, -L / 2 - 0.004 * k, 0.0), (W / 2 + 0.004 * k, -L / 2 + 0.05 * k, D + 0.006 * k),
           TAC_GEAR)
    gp.box((-W / 2 + 0.02 * k, -0.12 * k, D - 0.002 * k), (W / 2 - 0.02 * k, 0.12 * k, D + 0.022 * k), DRAB)
    gp.bevel(0.01 * k, 2, 30.0)
    # local +X is the character's left seen from behind; tilt the top towards the right shoulder
    tilt = o.Matrix.Rotation(math.radians(-24.0), 4, "Z")
    kit.add_gear(gp.to_mesh(mtx @ o.Matrix.Translation((0.0, 0.0, 0.018 * k)) @ tilt, anchor=loc))
    # shemagh rolled round the neck
    c_ring = []
    for t, rad, dz in ((0.05, 0.022, 0.0), (0.3, 0.036, 0.0), (0.6, 0.026, 0.0)):
        c_ring.append([nk.point(2 * math.pi * i / 24, t, rad * k) + Vector((0, 0, dz)) for i in range(24)])
    sm = Mesh()
    sg.loft(sm, c_ring, DRAB, nk.cb, w=None)
    kit.add_soft(sm)
    # boonie hat: crown + wide floppy brim + band
    eye = fit.eye_centre()
    top = fit.head_top()
    c = fit.head_centre()
    zb = eye.z + 0.035 * k
    rings = sg.crown_rings(fit, [zb, zb + 0.04 * k, top - 0.025 * k], 0.014 * k, n=28)
    hat = Mesh()
    hm = Mesh()
    sg.loft(hm, rings, DRAB, c, w=sg.HEAD_W, cap_top=False)
    topr = rings[-1]
    cc = sum(topr, Vector()) / len(topr)
    cap_ring = [cc + (p - cc) * 0.72 + Vector((0, 0, 0.022 * k)) for p in topr]
    ids_top = len(hm.v) - len(topr)
    ids_cap = hm.ring(cap_ring, sg.HEAD_W)
    n = len(topr)
    for j in range(n):
        jj = (j + 1) % n
        q = (ids_top + j, ids_top + jj, ids_cap[jj], ids_cap[j])
        sg.put(hm, q, DRAB, (hm.v[q[0]] - cc) + Vector((0, 0, 0.05)))
    pole = hm.add(cc + Vector((0, 0, 0.03 * k)), sg.HEAD_W)
    for j in range(n):
        sg.put(hm, (ids_cap[j], ids_cap[(j + 1) % n], pole), DRAB, o.UP)
    hat.extend(hm)
    base_r = rings[0]
    brim_out = []
    brim_lo = []
    for p in base_r:
        dd = Vector((p.x - c.x, p.y - c.y, 0.0))
        dn = dd.normalized()
        q = p + dn * 0.085 * k + Vector((0, 0, -0.022 * k))
        brim_out.append(q)
        brim_lo.append(q + Vector((0, 0, -0.006 * k)))
    base_lo = [p + Vector((0, 0, -0.006 * k)) for p in base_r]
    b = Mesh()
    ids = [b.ring(r_, sg.HEAD_W) for r_ in (base_r, brim_out, brim_lo, base_lo)]
    for a_, b_, ref in ((ids[0], ids[1], Vector((0, 0, 1))), (ids[1], ids[2], None), (ids[2], ids[3], Vector((0, 0, -1)))):
        for j in range(n):
            jj = (j + 1) % n
            q = (a_[j], a_[jj], b_[jj], b_[j])
            cq = sum((b.v[i] for i in q), Vector()) / 4
            sg.put(b, q, DRAB, ref if ref is not None else Vector((cq.x - c.x, cq.y - c.y, 0.0)))
    hat.extend(b)
    band = [Vector((p.x, p.y, p.z + 0.012 * k)) + Vector((p.x - c.x, p.y - c.y, 0)).normalized() * 0.003 * k
            for p in base_r]
    band.append(band[0])
    o.tube(hat, band, 0.009 * k, TAC_GEAR, sides=4, weights=lambda p, t: sg.HEAD_W, caps=False)
    kit.add_head(hat)
    kit.markers.append({"name": "LaserOrigin", "parent": "HandR/Socket", "origin": [0.0, 0.06, -0.5]})
    kit.seats["Hip"] = belt.point(math.radians(100.0), dz=0.0, out=0.05 * k)
    kit.notes["hat"] = "boonie hat (Headwear); LaserOrigin under HandR/Socket at (0, 0.06, -0.5)"


def brandt(kit) -> None:
    fit, k = kit.fit, kit.k
    armor = kit.opts["armor"]
    accent = kit.opts["accent"]
    heavy(kit, armor, accent, kit.opts.get("carrier", TAC_GEAR), shoulder_plates=False)
    coat, _info = g.jacket(fit, kit.hull(), "char_coat_command", 0.52 * k, 1.02 * k, neck_w=0.11, base=0.022,
                           sleeve=1.85, flare=0.13, open_below=0.06, lapel_w=0.06, collar_mat=armor,
                           lapel_mat="char_coat_command", shoulder_pad=0.01)
    # shirt / carrier faces fully hidden under the coat are dropped (tri budget)
    n0 = len(kit.soft.f)
    kit.add_soft(coat)
    kit.notes["faces_hidden_by_coat"] = str(sg.cull_hidden(kit.soft, n0, Hull(fit, [coat], body_regions=set())))
    pauldrons(kit, armor, accent, size=1.12, lift=1.15)
    helm, hh = big_helmet(kit, armor, gap=0.04, cup_r=0.044)
    del helm
    # crest: a fin from the brow over the crown to the nape
    c = fit.head_centre()
    path = []
    for i in range(13):
        el = math.radians(lerp(25.0, 160.0, i / 12))
        d = Vector((0.0, math.cos(el), math.sin(el)))
        hit = hh.cast(c + d * 0.5, -d, 0.5)
        path.append(hit[0] if hit[0] is not None else c + d * 0.14)
    crest = Mesh()
    o.strip(crest, hh, path, 0.011 * k, 0.036 * k, accent, side_hint=Vector((1, 0, 0)), segs_across=1,
            chamfer=0.004 * k, weights=sg.HEAD_W, profile=lambda o_: 1.0)
    kit.add_head(crest)
    visor(kit, hh, down=False, frame=accent)
    kit.notes["hat"] = "crested command helmet, visor up (Headwear); long command coat (Outfit)"


def wrecker(kit) -> None:
    fit, k = kit.fit, kit.k
    hips = fit.ring_centre("hips")
    chest = fit.ring_centre("chest")
    boots = g.shoes(fit, "char_shoe_black", "rubber_black", top_z=0.26, base=0.016, toe=0.02, sole_h=0.03, boot=True)
    kit.add_soft(boots)

    def sh_bulk(p: Vector) -> float:
        d = 0.0
        for sx in (-1.0, 1.0):
            dd = (p - _shoulder(kit, sx) - Vector((0, 0, 0.03 * k))).length
            d += 0.05 * k * smoothstep(0.16 * k, 0.04 * k, dd)
        return d

    def up_keep(r: str, c: Vector) -> bool:
        if r in ("torso", "pelvis"):
            return c.z > hips.z - 0.02 * k
        if r in ("upper_arms", "forearms"):
            return g._arm_param(fit, c, g._side(c)) < 1.86
        return False

    def up_off(p: Vector, r: str) -> float:
        if r in ("upper_arms", "forearms"):
            a = g._arm_param(fit, p, g._side(p))
            return (0.042 - 0.012 * smoothstep(1.0, 1.9, a)) * k + sh_bulk(p) * smoothstep(0.6, 0.0, a)
        front = smoothstep(chest.y - 0.02, chest.y + 0.08, p.y)
        return (0.045 + 0.02 * front) * k + sh_bulk(p)

    up = sg.puffy_shell(fit, SUIT, up_keep, up_off, hull=Hull(fit), max_off=0.16)
    m = up.mesh
    for loop in o.boundary_loops(m.f):
        o.straighten_loop(m, loop, iters=2)
    o.hem_all(m, thick=0.01 * k, depth=0.02 * k)
    kit.add_soft(m)

    def lo_keep(r: str, c: Vector) -> bool:
        if r in ("pelvis", "torso"):
            return c.z <= hips.z + 0.04 * k
        if r == "thighs":
            return True
        if r == "shins":
            return c.z > 0.215 * k
        return False

    def lo_off(p: Vector, r: str) -> float:
        d = 0.038 * k
        for sfx in ("L", "R"):
            kc = fit.ring_centre(f"knee.{sfx}")
            d += 0.02 * k * smoothstep(0.12 * k, 0.02 * k, (p - kc).length)
        return d

    lo = sg.puffy_shell(fit, SUIT, lo_keep, lo_off, hull=Hull(fit, [boots]), max_off=0.12)
    lm = lo.mesh
    for loop in o.boundary_loops(lm.f):
        o.straighten_loop(lm, loop, iters=5)
    o.hem_all(lm, thick=0.01 * k, depth=0.02 * k)
    kit.add_soft(lm)
    kit.add_soft(g.gloves(fit, "char_tac_glove", base=0.008, cuff_len=0.09, cuff_off=0.03))
    belt = gk.Belt(fit, Hull(fit, [lm, m], body_regions=set()), hips.z + 0.03 * k, height=0.07, thick=0.012)
    kit.add_soft(belt.mesh(BLACK))
    # armour: big chest plate with hazard stripes, groin plate, shin guards, massive pauldrons
    ca = Vector((0.0, chest.y, 1.30 * k))
    cp = sg.plate(kit, Vector((0.0, 0.0, 1.27 * k)), Vector((0, 1, 0)), 0.40, 0.40,
                  [(1.0, 0.03, BLACK), (0.86, 0.012, BLACK)], r=0.05, anchor=ca)
    kit.add_gear(cp)
    hull = kit.hull()
    stripes = Mesh()
    for zz in (1.40, 1.17):
        path = []
        for i in range(9):
            x = lerp(-0.15, 0.15, i / 8) * k
            hit = hull.cast(Vector((x, 0.6, zz * k)), Vector((0, -1, 0)), 1.0)
            path.append(hit[0] if hit[0] is not None else Vector((x, 0.2, zz * k)))
        o.strip(stripes, hull, path, 0.016 * k, 0.003 * k, HAZARD, segs_across=1, chamfer=0.002 * k,
                anchor=ca)
    kit.add_gear(stripes)
    kit.add_gear(sg.plate(kit, Vector((0.0, hips.y, hips.z - 0.08 * k)), Vector((0, 1, -0.05)), 0.24, 0.22,
                          [(1.0, 0.025, BLACK)], r=0.05, anchor=Vector((0.0, hips.y, hips.z))))
    for sx in (-1.0, 1.0):
        kc = fit.ring_centre("knee.R" if sx > 0 else "knee.L")
        tgt = kc + Vector((0, 0, -0.17 * k))
        kit.add_gear(sg.plate(kit, tgt, Vector((0, 1, 0.05)), 0.13, 0.30, [(1.0, 0.02, BLACK)], r=0.04, anchor=tgt))
    pauldrons(kit, BLACK, BLACK, size=1.35, lift=1.6)
    # high bomb-suit collar standing up round the neck (lower at the front so the face stays visible)
    nk = g.Neck(fit)
    eye = fit.eye_centre()
    col = Mesh()
    rings = []
    for t, rad, zf in ((-0.2, 0.10, 0.0), (0.4, 0.105, 0.03), (1.0, 0.10, 0.05)):
        pts = []
        for i in range(28):
            az = 2 * math.pi * i / 28
            p = nk.point(az, max(t, 0.0), rad * k)
            if t < 0:
                p = p + Vector((0, 0, t * 0.1 * k))
            front = 0.5 * (1 + math.cos(az))
            p.z += zf * k * (1.0 - 0.8 * front)
            pts.append(p)
        rings.append(pts)
    ids = sg.loft(col, rings, SUIT, nk.cb, w=None)
    inner = [col.ring([nk.point(2 * math.pi * i / 28, 1.0, 0.03 * k) + Vector((0, 0, rings[-1][i].z - nk.point(
        2 * math.pi * i / 28, 1.0).z)) for i in range(28)], None)]
    for j in range(28):
        jj = (j + 1) % 28
        sg.put(col, (ids[-1][j], ids[-1][jj], inner[0][jj], inner[0][j]), SUIT, o.UP)
    kit.add_soft(col)
    # armoured hood with a face opening (state 3 shows the face through it)
    brow = eye.z + 0.035 * k
    chin = eye.z - 0.125 * k
    c = fit.head_centre()

    def hood_gap(az: float, el: float) -> float:
        return 0.040 + 0.03 * smoothstep(0.2, 1.4, el)

    hood, _r = sg.head_dome(fit, BLACK, hood_gap, el_min=-58.0, n_az=32, n_el=10, smooth=3)
    open_a = math.radians(50.0)

    def opening(cc: Vector) -> bool:
        az = math.atan2(cc.x - c.x, cc.y - c.y)
        return abs(az) < open_a and chin - 0.02 * k < cc.z < brow
    g.delete_faces(hood, opening)
    o.hem_all(hood, thick=0.008 * k, depth=0.02 * k)
    kit.add_head(hood)
    # staged face armour (each a separate mesh, 100 % head)
    fr = max(sg.face_radius(fit, a, z, c) for a in [math.radians(x) for x in range(-50, 51, 10)]
             for z in [lerp(chin, brow, t / 6) for t in range(7)])
    r_vis = fr + 0.026 * k

    def r_const(rv: float):
        return lambda az, z: rv

    vis = sg.curved_panel(c, -math.radians(54.0), math.radians(54.0), chin - 0.03 * k, brow + 0.012 * k,
                          r_const(r_vis), 0.006 * k, LENS, nu=12, nv=4)
    kit.extra["Visor"] = vis
    arm = Mesh()
    arm.extend(sg.curved_panel(c, -math.radians(64.0), math.radians(64.0), brow + 0.004 * k, brow + 0.045 * k,
                               r_const(r_vis + 0.012 * k), 0.016 * k, BLACK, nu=12, nv=1))
    arm.extend(sg.curved_panel(c, -math.radians(60.0), math.radians(60.0), chin - 0.075 * k, chin - 0.022 * k,
                               lambda az, z: r_vis + 0.008 * k + 0.25 * (chin - 0.022 * k - z), 0.016 * k, BLACK,
                               nu=12, nv=2))
    for sx in (-1.0, 1.0):
        a0, a1 = sorted((sx * math.radians(52.0), sx * math.radians(66.0)))
        arm.extend(sg.curved_panel(c, a0, a1, chin - 0.04 * k, brow + 0.02 * k, r_const(r_vis + 0.006 * k), 0.02 * k,
                                   BLACK, nu=2, nv=4))
    kit.extra["HeadArmored"] = arm
    r_fp = r_vis + 0.034 * k

    def fp_mat(u: float, v: float) -> str:
        if u < 0.09 or u > 0.91 or v < 0.1 or v > 0.9:
            return HAZARD
        if 0.58 < v < 0.72 and 0.2 < u < 0.8:
            return "char_visor_gloss"
        return BLACK

    kit.extra["Faceplate"] = sg.curved_panel(c, -math.radians(58.0), math.radians(58.0), chin - 0.045 * k,
                                             brow + 0.03 * k, lambda az, z: r_fp + 0.06 * (brow - z) * 0.3,
                                             0.016 * k, fp_mat, nu=12, nv=10, side_mat=HAZARD)
    kit.seats["Hip"] = belt.point(math.radians(120.0), dz=0.0, out=0.05 * k)
    kit.notes["hat"] = "bomb-suit hood (Headwear); Faceplate / Visor / HeadArmored = the 3 head states"


def recipe(kit) -> None:
    {"tac_heavy": tac_heavy, "phantom": phantom, "stinger": stinger, "bulwark": bulwark, "wrecker": wrecker,
     "longshot": longshot, "corpsman": corpsman, "brandt": brandt}[kit.opts["unit"]](kit)
    faction.dress(kit)


def build(ctx) -> None:
    if ctx.params.get("unit") == "shield":
        import _special_shield as shield

        shield.build_shield(ctx, {k: ctx.params[k] for k in ("face", "edge", "letters", "glass", "metal", "word")
                                  if k in ctx.params})
        if ctx.params.get("faction"):
            faction.tag(ctx, ctx.params["faction"])
        return
    sg.build_special(ctx, recipe)
