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

import _cartel_gear as cgr
import _contact_gear as cg
import _crew_heisters as crew
import _gear_kit as gk
import _npc as n
import _outfit_garments as g
import _p5 as p5
from _outfit import Hull, Mesh, Vector
from _outfit_build import Kit, build_character

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
                                 "recolor": {"char_mac_cherry": "char_knit_teal", "char_knit_grey": "char_knit_navy"},
                                 "note": "Commuter g (finish swap of a): belted teal mac over a navy roll-neck, black "
                                         "trousers, black flats, brown bob"},
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
    kit.notes["look"] = ("Diner waitress (RT-D1 staff_diner): 1950s-style pale rose short-sleeved uniform dress to the "
                         "knee, short cream bistro apron tied at the waist, brass name badge, black flats, dark bun")


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
    kit.add_head(cgr.beanie(fit, "char_shirt_white", front_el=16.0, back_el=-6.0, cuff=0.10, slouch=0.004))
    kit.notes["look"] = ("Diner cook (RT-D1 staff_diner): cook's whites (white band-collar jacket, double row of "
                         "buttons, sleeves rolled), long cream bib apron, black trousers and shoes, white skull cap")


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
    kit.notes["look"] = ("Commuter (RT-D1): belted double-breasted cherry mac above the knee over a grey roll-neck, "
                         "black trousers, black flats, dark bob")


def jogger(kit: Kit) -> None:
    k = kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _trainers(kit, "char_sneaker_white")
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.050)
    n.hoodie(kit, "char_hoodie_heather", hips_z - 0.06 * k, string_mat="char_shirt_white")
    n.watch(kit, "L", strap="rubber_black", case="polymer_black")
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
    p5.backpack(kit, "char_nylon_green", "char_nylon_black", trim="char_nylon_black", z=1.16, w=0.20, h=0.26, d=0.20)
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
