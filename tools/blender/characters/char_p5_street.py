"""Rolling Thunder street cast (RT-D1, QC-86): the diner staff, the car-park attendant and six street pedestrians
for ``rolling_thunder`` (docs/design/heists/rolling_thunder.md, "Civilian, guard and convoy roster").

The street pool (``street_civilian``: ``civ_street``, ``civ_bus``, ``civ_diner``) adds six daytime city looks to the
twelve Ostrander Federal customer faces (``bank_customer`` a-j, ``civilian_customer_a/b``), each with a face
(gender, skin, hair, hair colour, age bucket) none of those twelve has, three women and three men. Staff are in
their own colours; nobody wears police navy + ``char_hivis``, Halden steel-blue, TAC charcoal or the Vaultline
sand/brown/amber.

* ``char_diner_waitress`` (``staff_diner``): a woman in her 30s, dark hair in a bun: a 1950s-style pale rose short-
  sleeved uniform dress to the knee, a short cream bistro apron tied at the waist, a brass name badge, black flats.
* ``char_diner_cook`` (``staff_diner``): a heavy-set man in his 50s with stubble: cook's whites (a white band-collar
  jacket, double row of buttons, sleeves rolled), a long cream bib apron, black trousers and shoes, a white knit skull
  cap.
* G3 (RT character polish, the diner is a casing hub): the waitress gains a white Peter Pan collar and white sleeve
  cuffs, white buttons down the bodice, an order pad and a pencil in the apron pocket; the cook a folded white paper
  cook's cap (in place of the knit skull cap), a red neckerchief knotted at the throat and a striped side towel tucked
  in the apron string at the right hip.
* ``char_carpark_attendant`` (``staff_booth``): a man about 60, deep skin, short grey hair: a teal polo under a dark
  espresso fleece gilet (zipped), the staff lanyard and white card, grey slacks, black shoes, a watch.
* ``char_street_pedestrian`` (a): a commuter, a woman in her 30s, mid skin, dark bob: a belted double-breasted cherry
  mac above the knee over a grey roll-neck, black trousers, black flats.
* ``char_street_pedestrian_b``: a jogger, a young man, brown-deep skin, short dark hair: heather-grey hoodie (hood
  down), black joggers, white trainers, a sports watch.
* ``char_street_pedestrian_c``: a student, a young woman, deep skin, dark side-parted hair: a denim jacket over a
  white tee, black trousers, white trainers, a rust daypack on both shoulders.
* ``char_street_pedestrian_d``: a retiree, a man in his 70s, light skin, grey: a tweed flat cap, an oat cardigan over a
  pale blue shirt, brown trousers and shoes, silver glasses.
* ``char_street_pedestrian_e``: a delivery rider, a man in his 30s, mid-deep skin, dark side part: a green padded
  bomber over a graphite knit, charcoal work trousers, grey trainers, a big green insulated delivery backpack.
* ``char_street_pedestrian_f``: an office worker, a woman in her 50s, light skin, brown side part: a forest-green
  blazer over a white shirt, black trousers, low heels, a black leather shoulder bag, silver stud earrings.
* ``char_street_pedestrian_g`` / ``_h`` / ``_i`` (D-147 / D-149: zero twins at the top roll, 21 live on 21 looks):
  **finish-only** swaps of a / b / f. The same meshes (body params, hair style, age and every garment unchanged),
  with a new skin tone, hair colour and garment materials (``recolor``), so each is a new face for the pool:
  g = the commuter in a teal mac over a navy roll-neck (skin 5, brown hair); h = the jogger in a cream hoodie and
  navy joggers (skin 2, blond); i = the office worker in a grey blazer over an ivory silk shirt (skin 4, dark hair).

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (caps, bun, glasses, earrings).
No blend shapes (baked at the params below).
"""

import math

import _cartel_gear as cgr
import _contact_gear as cg
import _crew_heisters as crew
import _gear_kit as gk
import _npc as n
import _outfit_garments as g
import _outfit as o
import _p5 as p5
from _outfit import Gear, Hull, Mesh, Vector, smoothstep
from _outfit_build import Kit, build_character
from mathutils import Matrix

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

VARIANTS = {
    "char_diner_waitress": {"height": 1.68, "build": 0.4, "gender": 1.0, "age": 0.3, "skin": 4,
                            "hair": "side_part", "hair_color": "dark", "look": "waitress"},
    "char_diner_cook": {"height": 1.78, "build": 0.8, "gender": 0.0, "age": 0.55, "skin": 2, "beard_shadow": 0.75,
                        "hair": "buzz", "hair_color": "brown", "look": "cook"},
    "char_carpark_attendant": {"height": 1.76, "build": 0.6, "gender": 0.0, "age": 0.6, "skin": 6,
                               "beard_shadow": 0.3, "hair": "short", "hair_color": "grey", "look": "attendant"},
    # the six street pedestrians: faces none of the twelve OF street faces share (test_p5_cast _face)
    "char_street_pedestrian": {"height": 1.71, "build": 0.4, "gender": 1.0, "age": 0.32, "skin": 3,
                               "hair": "bob", "hair_color": "dark", "look": "commuter"},
    "char_street_pedestrian_b": {"height": 1.80, "build": 0.35, "gender": 0.0, "age": 0.12, "skin": 5,
                                 "beard_shadow": 0.2, "hair": "short", "hair_color": "dark", "look": "jogger"},
    "char_street_pedestrian_c": {"height": 1.68, "build": 0.35, "gender": 1.0, "age": 0.08, "skin": 6,
                                 "hair": "side_part", "hair_color": "dark", "look": "student"},
    "char_street_pedestrian_d": {"height": 1.72, "build": 0.55, "gender": 0.0, "age": 0.88, "skin": 1,
                                 "beard_shadow": 0.4, "hair": "buzz", "hair_color": "grey", "look": "retiree"},
    "char_street_pedestrian_e": {"height": 1.77, "build": 0.5, "gender": 0.0, "age": 0.33, "skin": 4,
                                 "beard_shadow": 0.6, "hair": "side_part", "hair_color": "dark", "look": "rider"},
    "char_street_pedestrian_f": {"height": 1.69, "build": 0.55, "gender": 1.0, "age": 0.55, "skin": 1,
                                 "hair": "side_part", "hair_color": "brown", "look": "office"},
    # finish-only swaps (D-147): a / b / f's params with only skin, hair colour and garment materials changed
    "char_street_pedestrian_g": {"height": 1.71, "build": 0.4, "gender": 1.0, "age": 0.32, "skin": 5,
                                 "hair": "bob", "hair_color": "brown", "look": "commuter",
                                 "recolor": {"char_mac_cherry": "char_knit_teal", "char_knit_grey": "char_knit_navy",
                                            "char_knit_teal": "char_silk_ivory"},
                                 "note": "Commuter g (finish swap of a): belted teal mac over a navy roll-neck, ivory "
                                         "scarf, black trousers, black flats, brown bob"},
    "char_street_pedestrian_h": {"height": 1.80, "build": 0.35, "gender": 0.0, "age": 0.12, "skin": 2,
                                 "beard_shadow": 0.2, "hair": "short", "hair_color": "blond", "look": "jogger",
                                 "recolor": {"char_hoodie_heather": "char_hoodie_cream",
                                             "char_trousers_black": "char_chino_navy"},
                                 "note": "Jogger h (finish swap of b): cream hoodie (hood down), navy joggers, white trainers, "
                                         "black sports watch, short blond hair"},
    "char_street_pedestrian_i": {"height": 1.69, "build": 0.55, "gender": 1.0, "age": 0.55, "skin": 4,
                                 "hair": "side_part", "hair_color": "dark", "look": "office",
                                 "recolor": {"char_blazer_forest": "char_blazer_grey", "char_shirt_white": "char_silk_ivory"},
                                 "note": "Office worker i (finish swap of f): grey blazer over an ivory silk shirt, black "
                                         "trousers, low heels, black leather shoulder bag, dark side part"},
}

ROSE = "char_diner_rose"
APRON = "char_apron_cream"


def _z(kit: Kit) -> tuple[float, float, float]:
    hips_z = kit.fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * kit.k
    return hips_z, belt_z, belt_z - 0.02 * kit.k


def _trainers(kit: Kit, mat: str = "char_sneaker_grey") -> Mesh:
    sh = g.shoes(kit.fit, mat, "char_button_pale", top_z=0.085, base=0.007, toe=0.016)
    kit.add_soft(sh)
    return sh


def _flats(kit: Kit) -> Mesh:
    sh = g.shoes(kit.fit, "char_shoe_black", "rubber_black", top_z=0.075, base=0.004, toe=0.018)
    kit.add_soft(sh)
    return sh


# ---------------------------------------------------------------------------------------------
# staff: the diner (staff_diner) and the car-park booth (staff_booth)
# ---------------------------------------------------------------------------------------------
def waitress(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _flats(kit)
    d = g.dress(fit, ROSE, 0.46 * k, sleeve=0.30, scoop=0.045, flare=0.12)
    kit.add_soft(d)
    waist = fit.ring_centre("waist").z
    n.waist_apron(kit, APRON, waist + 0.005 * k, 0.66 * k, width=0.44)
    kit.add_gear(gk.name_tag(kit.hull(), Vector((0.085 * k, 0.2, 1.33 * k)), k=k))
    kit.add_head(cg.chignon(fit, "char_hair_dark", size=0.9))
    kit.add_head(cg.earrings(fit, "chrome", drop=False))
    _waitress_g3(kit, waist)
    kit.notes["look"] = ("Diner waitress (RT-D1 staff_diner): 1950s-style pale rose short-sleeved uniform dress to the "
                         "knee, short cream bistro apron tied at the waist, brass name badge, black flats, dark bun; "
                         "G3: white "
                         "collar and cuffs, bodice buttons, order pad and pencil in the apron pocket")


def cook(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    jk = n.shirt(kit, "char_shirt_white", tuck, collar="band", sleeve=1.35, roll=0.006)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.062)
    # cook's whites: the double row of buttons of a chef jacket (above the bib)
    jh = Hull(fit, [jk])
    gear = Mesh()
    for sx in (-1.0, 1.0):
        for z in (1.40, 1.33):
            gear.extend(gk.button(jh, Vector((sx * 0.06 * k, 0.3, z * k)), "char_button_pale", r=0.009, k=k,
                                  thick=0.004))
    kit.add_gear(gear)
    kit.add_soft(g.apron(fit, kit.hull(), APRON, 1.30 * k, 0.50 * k, strap_mat=APRON))
    kit.add_head(_paper_cap(fit, "char_shirt_white"))
    _cook_g3(kit)
    kit.notes["look"] = ("Diner cook (RT-D1 staff_diner): cook's whites (white band-collar jacket, double row of "
                         "buttons, sleeves rolled), long cream bib apron, black trousers and shoes, white paper "
                         "cook's cap, "
                         "red neckerchief, side towel")


def _arm_ring(kit: Kit, side: str, t: float, out: float = 0.003, reach: float = 0.07) -> list[Vector]:
    """A closed ring of points on the outer surface round the arm at arm parameter ``t`` (0 shoulder, 1 elbow, 2 wrist);
    the rays start ``reach`` out from the bone (just outside the sleeve, so the bind-pose torso is never hit)."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    sh, el, wr = (Vector(fit.J[f"{j}.{side}"]) for j in ("shoulder", "elbow", "wrist"))
    a0, a1, tt = (sh, el, t) if t <= 1.0 else (el, wr, t - 1.0)
    axis = (a1 - a0).normalized()
    c = a0.lerp(a1, tt)
    ref = Vector((0.0, 1.0, 0.0))
    u = (ref - axis * ref.dot(axis)).normalized()
    v = axis.cross(u)
    ring = []
    for i in range(20):
        a = math.tau * i / 20
        d = u * math.cos(a) + v * math.sin(a)
        hit = hull.cast(c + d * reach * k, -d, reach * k)
        ring.append((hit[0] if hit[0] is not None else c + d * 0.6 * reach * k) + d * out * k)
    return ring


def _arm_band(kit: Kit, side: str, t: float, width: float, mat: str) -> None:
    """A closed band (tape, armband) round the arm at arm parameter ``t``."""
    k = kit.k
    m = Mesh()
    o.strip(m, kit.hull(), _arm_ring(kit, side, t, out=0.004), width * 0.5 * k, 0.003 * k, mat, segs_across=1,
            chamfer=0.001 * k, closed=True, cast_back=0.03 * k)
    kit.add_soft(m)


def _waitress_g3(kit: Kit, waist: float) -> None:
    """G3: the white Peter Pan collar, sleeve cuffs and bodice buttons; the order pad and pencil in the apron pocket."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    nk = g.Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y
    det = Mesh()
    for sx in (-1.0, 1.0):                                                     # collar: two rounded lobes
        path = []
        for i in range(8):
            x = sx * (0.006 + 0.095 * i / 7) * k
            edge = neck_z - 0.045 * k * smoothstep(0.09 * k, 0.0, abs(x))
            path.append(o.push_out(p5._front_hit(hull, x, edge - 0.014 * k, cy + 0.1 * k), hull, 0.002 * k))
        o.strip(det, hull, path, 0.016 * k, 0.0025 * k, "char_shirt_white", segs_across=2, chamfer=0.002 * k)
    for side in ("L", "R"):                                                    # cuffs at the sleeve hem
        o.strip(det, hull, _arm_ring(kit, side, 0.27, reach=0.12), 0.011 * k, 0.003 * k, "char_shirt_white",
                segs_across=1, chamfer=0.001 * k, closed=True)
    kit.add_soft(det)
    hull = kit.hull()
    gear = Mesh()
    for i in range(4):                                                         # bodice buttons
        z = neck_z - (0.075 + 0.045 * i) * k
        gear.extend(gk.button(hull, p5._front_hit(hull, 0.0, z, cy + 0.1 * k), "char_shirt_white", r=0.006, k=k))
    pocket = p5._front_hit(hull, -0.07 * k, waist - 0.09 * k, cy + 0.15 * k)     # apron pocket, wearer's left
    fwd = Vector((0.0, 1.0, 0.0))
    gear.extend(gk.bar(hull, pocket + Vector((0.0, 0.0, 0.030 * k)), fwd, 0.075, 0.050, 0.004, "char_prop_paper",
                       k=k))                                                   # the pad, standing out of it
    gear.extend(gk.bar(hull, pocket, fwd, 0.095, 0.070, 0.006, ROSE, k=k))       # the pocket (rose, as the dress)
    pen = Gear()
    pen.cyl(0.0035 * k, 0.12 * k, centre=(0.0, 0.0, 0.0), axis="Y", segs=6, mat="char_rubber_yellow")
    pen.cyl(0.0036 * k, 0.012 * k, centre=(0.0, 0.065 * k, 0.0), axis="Y", segs=6, mat="char_bank_red")
    mtx, loc = o.surface_frame(hull, pocket + Vector((0.035 * k, 0.0, 0.04 * k)), fwd, lift=0.008 * k)
    gear.extend(pen.to_mesh(mtx, anchor=loc))
    kit.add_gear(gear)


def _paper_cap(fit, mat: str) -> Mesh:
    """A folded white paper cook's cap: walls round the head from the brow line, pinched to a crest along the crown
    (front-back), the ends flat. Sized from the head and hair: the wall clears them by 6 mm, the crest the crown."""
    k = fit.k
    c = fit.head_centre()
    eye = fit.eye_centre()
    hh = gk.HeadHull(fit)
    z0 = eye.z + 0.040 * k
    top = fit.head_top() + 0.020 * k
    half_w = 0.0
    for dz in (0.0, 0.03, 0.06):
        for sx in (-1.0, 1.0):
            hit = hh.cast(Vector((c.x + sx * 0.3, c.y, z0 + dz * k)), Vector((-sx, 0.0, 0.0)), 0.6)
            if hit[0] is not None:
                half_w = max(half_w, abs(hit[0].x - c.x))
    half_w = (half_w or 0.075 * k) + 0.006 * k
    h = top - z0
    wall = 0.30 * h
    outline = [(-half_w, 0.0), (half_w, 0.0), (half_w, wall)]
    for i in range(1, 6):                                                      # the arch to the crest
        t = i / 6
        outline.append((half_w * (1.0 - t) ** 1.4, wall + (h - wall) * math.sin(t * math.pi / 2)))
    outline.append((0.0, h))
    for x, z in reversed(outline[3:-1]):
        outline.append((-x, z))
    outline.append((-half_w, wall))
    front = c.y + 0.095 * k
    back = c.y - 0.085 * k
    cap = Gear()
    cap.prism(outline, 0.0, front - back, mat)
    cap.bevel(0.002 * k, 1, 30.0)
    # local X = world X, local Y = up, local Z = backwards from the front edge (a rotation: a mirror flips the faces)
    mtx = Matrix(((1.0, 0.0, 0.0, c.x), (0.0, 0.0, -1.0, front), (0.0, 1.0, 0.0, z0), (0.0, 0.0, 0.0, 1.0)))
    return cap.to_mesh(mtx, anchor=c)


def _cook_g3(kit: Kit) -> None:
    """G3: the red neckerchief knotted at the throat and the striped side towel at the right hip."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    nk = g.Neck(fit)
    det = Mesh()
    ring = [nk.point(math.tau * i / 20, 0.25, 0.010 * k) for i in range(20)]
    o.strip(det, hull, ring, 0.013 * k, 0.004 * k, "char_bank_red", segs_across=2, chamfer=0.002 * k, closed=True)
    kit.add_soft(det)
    hull = kit.hull()
    gear = Mesh()
    knot = nk.point(0.0, 0.15, 0.022 * k)
    gear.extend(gk.bar(hull, knot, Vector((0.0, 1.0, 0.0)), 0.030, 0.026, 0.012, "char_bank_red", k=k, bevel=0.003))
    for sx, dz in ((-0.008, -0.04), (0.010, -0.035)):                          # the knot's ends
        gear.extend(gk.bar(hull, knot + Vector((sx * k, 0.006 * k, dz * k)), Vector((0.0, 1.0, 0.0)), 0.018, 0.045,
                           0.004, "char_bank_red", k=k))
    hips = fit.ring_centre("hips")
    fwd = Vector((0.0, 1.0, 0.0))
    towel_top = p5._front_hit(hull, 0.12 * k, hips.z + 0.06 * k, hips.y + 0.15 * k)    # wearer's right, on the apron
    mtx, loc = o.surface_frame(hull, towel_top, fwd, lift=0.004 * k)
    tw = Gear()
    tw.box((-0.07 * k, -0.24 * k, 0.0), (0.07 * k, 0.0, 0.006 * k), "char_shirt_white")
    for zz in (-0.20, -0.17):                                                  # woven stripes near the hem
        tw.box((-0.071 * k, (zz - 0.008) * k, 0.006 * k), (0.071 * k, (zz + 0.008) * k, 0.0075 * k), "char_knit_navy")
    tw.bevel(0.0015 * k, 1, 30.0)
    gear.extend(tw.to_mesh(mtx, anchor=loc))
    kit.add_gear(gear)


def _neck_scarf(kit: Kit, mat: str) -> None:
    """A light scarf wrapped once round the neck, knotted at the front with two short tails."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    m = Mesh()
    ring = [nk.point(math.tau * i / 20, 0.15, 0.016 * k) for i in range(20)]
    o.strip(m, kit.hull(), ring, 0.020 * k, 0.006 * k, mat, segs_across=2, chamfer=0.003 * k, closed=True)
    kit.add_soft(m)
    hull = kit.hull()
    knot = nk.point(0.0, 0.05, 0.030 * k)
    gear = Mesh()
    gear.extend(gk.bar(hull, knot, Vector((0.0, 1.0, 0.0)), 0.034, 0.028, 0.014, mat, k=k, bevel=0.004))
    for sx, dz in ((-0.012, -0.075), (0.014, -0.065)):
        gear.extend(gk.bar(hull, knot + Vector((sx * k, 0.004 * k, dz * k)), Vector((0.0, 1.0, 0.0)), 0.030, 0.10,
                           0.004, mat, k=k))
    kit.add_gear(gear)


def _elbow_patches(kit: Kit, mat: str) -> None:
    """Oval suede patches on the backs of the elbows."""
    fit, k = kit.fit, kit.k
    m = Mesh()
    for side in ("L", "R"):
        sh, el, wr = (Vector(fit.J[f"{j}.{side}"]) for j in ("shoulder", "elbow", "wrist"))
        axis = (wr - sh).normalized()
        back = Vector((0.0, -1.0, 0.0))
        back = (back - axis * back.dot(axis)).normalized()
        u = axis.cross(back).normalized()
        outline = [(0.030 * k * math.cos(a), 0.045 * k * math.sin(a)) for a in [math.tau * i / 16 for i in range(16)]]
        o.patch(m, kit.hull(), el + back * 0.12 * k, u, axis, outline, 0.0025 * k, mat, -back)
    kit.add_soft(m)


def attendant(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_polo_teal", tuck, sleeve=0.55, point_len=0.044, spread=0.30)
    tr = n.trousers(kit, "char_slacks_grey", sh, belt_z + 0.022 * k)
    n.belt(kit, tr, belt_z, mat="char_leather_black", buckle="chrome")
    soft, zipm = g.gilet(fit, kit.hull(), "char_fleece_espresso", hips_z - 0.03 * k, quilt=0.0)
    kit.add_soft(soft)
    kit.add_gear(zipm)
    n.lanyard(kit, "char_lanyard", "char_medic_white", card_z=1.16)
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    b = gk.Belt(fit, Hull(fit, [tr], body_regions=set()), belt_z, height=0.03, thick=0.005)   # G3: belt radio
    bg = Mesh()
    bg.extend(gk.radio(b, math.radians(100.0)))
    kit.add_gear(bg)
    kit.add_gear(gk.name_tag(kit.hull(), Vector((-0.085 * k, 0.2, 1.33 * k)), k=k, mat="chrome"))
    kit.add_head(cgr.beanie(fit, "char_knit_navy", front_el=12.0, back_el=-10.0, cuff=0.16, slouch=0.006))
    kit.notes["look"] = ("Car-park attendant (RT-D1 staff_booth): teal polo under a dark espresso fleece gilet, the "
                         "staff lanyard and white card, grey slacks, black belt and shoes, watch (no hi-vis)")


# ---------------------------------------------------------------------------------------------
# the street pedestrians (street_civilian: civ_street, civ_bus, civ_diner)
# ---------------------------------------------------------------------------------------------
def commuter(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _flats(kit)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.054)
    kit.add_soft(g.knit_top(fit, kit.hull(), "char_knit_grey", hips_z - 0.02 * k, neck="roll", base=0.006))
    n0 = len(kit.soft.f)
    coat, _info = n.jacket(kit, "char_mac_cherry", 0.56 * k, 1.03 * k, neck_w=0.09, lapel_w=0.07, flare=0.10,
                           base=0.013, open_below=0.05, sleeve=1.93, double=True)
    n.cull_under(kit, n0, coat, "faces_hidden_by_coat")
    waist = fit.ring_centre("waist").z
    cb = gk.Belt(fit, Hull(fit, [coat], body_regions=set()), waist, height=0.038, thick=0.004, drop=0.0)
    kit.add_soft(cb.mesh("char_mac_cherry"))
    _neck_scarf(kit, "char_knit_teal")                                          # G3
    n.messenger_bag(kit, "char_leather_black", "char_leather_black", a_deg=-115.0, z=1.00, w=0.17, h=0.13, d=0.06)
    kit.notes["look"] = ("Commuter (RT-D1): belted double-breasted cherry mac above the knee over a grey roll-neck, "
                         "black trousers, black flats, dark bob")


def jogger(kit: Kit) -> None:
    k = kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _trainers(kit, "char_sneaker_white")
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.050)
    n.hoodie(kit, "char_hoodie_heather", hips_z - 0.06 * k, string_mat="char_shirt_white")
    n.watch(kit, "L", strap="rubber_black", case="polymer_black")
    p5.headphones_on(kit, "polymer_black", "rubber_black", accent="char_hivis_orange")       # G3
    _arm_band(kit, "R", 0.45, 0.05, "rubber_black")                              # running armband
    kit.notes["look"] = ("Jogger (RT-D1): heather-grey hoodie (hood down), black joggers, white trainers, black sports "
                         "watch")


def student(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _trainers(kit, "char_sneaker_white")
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.054)
    kit.add_soft(g.knit_top(fit, kit.hull(), "char_shirt_white", hips_z - 0.03 * k, neck="crew", base=0.005, rib=0.02))
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_denim", 0.86 * k, 1.12 * k, button_mat="chrome", lapel_w=0.035, neck_w=0.09,
                         flare=0.05, chest_welt=False, base=0.012)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    p5.backpack(kit, "char_hoodie_rust", "char_nylon_black", trim="char_nylon_black")
    hull = kit.hull()                                                           # G3: enamel pins on the jacket
    pins = Mesh()
    cy = fit.ring_centre("chest").y
    for (x, z), mat in zip(((0.085, 1.33), (0.105, 1.30), (0.075, 1.29)), ("char_bank_red", "char_rubber_yellow",
                                                                            "char_knit_teal")):
        pins.extend(gk.button(hull, p5._front_hit(hull, x * k, z * k, cy + 0.12 * k), mat, r=0.008, k=k, thick=0.004))
    kit.add_gear(pins)
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.notes["look"] = ("Student (RT-D1): denim jacket over a white tee, black trousers, white trainers, rust daypack "
                         "on both shoulders")


def retiree(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, mat="char_shoe_brown")
    n.shirt(kit, "char_shirt_blue", tuck, point_len=0.054)
    tr = n.trousers(kit, "char_suit_brown", sh, belt_z + 0.022 * k, hem_r=0.060)
    n.belt(kit, tr, belt_z, mat="leather_dark", buckle="brass")
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_knit_oat", 0.82 * k, 1.04 * k, button_mat="char_button_dark", lapel_w=0.03,
                         neck_w=0.09, flare=0.08, chest_welt=False, base=0.013)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    cap, _info = cg.flat_cap(fit, "char_tweed_grey")
    kit.add_head(cap)
    kit.add_head(gk.glasses(fit, "char_metal_silver"))
    _elbow_patches(kit, "leather_dark")                                    # G3
    n.watch(kit, "L", strap="leather_dark", case="brass")
    kit.notes["look"] = ("Retiree (RT-D1): tweed flat cap, oat cardigan over a pale blue shirt, brown trousers, belt "
                         "and shoes, silver glasses")


def rider(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _trainers(kit)
    n.trousers(kit, "char_work_charcoal", sh, belt_z + 0.022 * k, hem_r=0.060)
    kit.add_soft(g.knit_top(fit, kit.hull(), "char_knit_graphite", hips_z - 0.02 * k, neck="crew", base=0.006))
    n0 = len(kit.soft.f)
    jk = crew.bomber(kit, "char_nylon_green", "char_knit_graphite", "char_nylon_green", hips_z - 0.01 * k, 1.36 * k,
                     neck_w=0.05)
    n.cull_under(kit, n0, jk, "faces_hidden_by_bomber")
    p5.backpack(kit, "char_nylon_green", "char_nylon_black", trim="char_hivis_orange", z=1.16, w=0.20, h=0.26,
                d=0.20)                                                         # G3: hi-vis orange trim
    for side in ("L", "R"):                                                      # G3: reflective forearm bands
        _arm_band(kit, side, 1.55, 0.030, "char_reflect_silver")
    kit.notes["look"] = ("Delivery rider (RT-D1): green padded bomber over a graphite knit, charcoal work trousers, grey "
                         "trainers, big green insulated delivery backpack")


def office(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, heel=True)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.05, spread=0.36)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.056)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_blazer_forest", 0.80 * k, 1.04 * k, button_mat="char_button_dark", lapel_w=0.05,
                         neck_w=0.09, flare=0.07)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    n.messenger_bag(kit, "char_leather_black", "char_leather_black", a_deg=-120.0, z=0.98, w=0.20, h=0.15, d=0.07)
    kit.add_head(cg.earrings(fit, "chrome", drop=False))
    n.lanyard(kit, "char_lanyard", "char_medic_white", card_z=1.18)               # G3
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.notes["look"] = ("Office worker (RT-D1): forest-green blazer over a white shirt, black trousers, low heels, black "
                         "leather shoulder bag, silver stud earrings")


_looks = {"waitress": waitress, "cook": cook, "attendant": attendant, "commuter": commuter, "jogger": jogger,
          "student": student, "retiree": retiree, "rider": rider, "office": office}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)
    table: dict[str, str] = kit.opts.get("recolor", {})
    if table:
        for m in (kit.soft, kit.gear, kit.head, kit.slung):
            m.m = [table.get(x, x) for x in m.m]
        kit.notes["look"] = kit.opts["note"] + " [" + ", ".join(f"{a} -> {b}" for a, b in sorted(table.items())) + "]"


def build(ctx) -> None:
    build_character(ctx, recipe)
