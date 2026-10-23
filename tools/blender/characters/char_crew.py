"""Crew bodies (the player heisters). The face is covered in game by the mask on the ``Head`` seat
(face centre, see ``_mask_base``), so heads stay visible and nothing is worn on the head.

* ``char_crew_body`` / ``char_crew_body_b`` (D1-02): the generic crew, a dark two-piece heist suit,
  shirt and tie, leather gloves, black shoes; two suit colourways.
* ``char_crew_rook`` / ``char_crew_sable`` / ``char_crew_dutch`` / ``char_crew_wren`` (D2-03): the four
  named heisters, each with a distinct heist outfit and 30 m silhouette (long coat, cropped blazer,
  bulky bomber, waistcoat and rolled sleeves). Design notes in ``_crew_heisters``.

Meshes: ``Body`` (covered skin removed), ``Hair`` (Dutch: + his beard and moustache, built as ``Headwear``
with strand UVs, ``_contact_gear.apply_strand_uvs``, then joined in), ``Outfit``, ``Gear`` (+ ``Headwear``
for Sable's earrings).
No blend shapes (baked).
"""
import json

import _contact_gear as cg
import _crew_heisters as crew
import _gear_kit as gk
import _outfit as o
import _outfit_garments as g
from _outfit import Hull, Mesh, Vector
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

VARIANTS = {
    "char_crew_body": {"height": 1.78, "build": 0.5, "gender": 0.0, "age": 0.3, "skin": 2, "hair": "short",
                       "hair_color": "dark", "suit": "char_suit_dark", "shirt": "char_shirt_white",
                       "tie": "char_tie_black"},
    "char_crew_body_b": {"height": 1.78, "build": 0.5, "gender": 0.0, "age": 0.3, "skin": 2, "hair": "short",
                         "hair_color": "dark", "suit": "char_suit_navy", "shirt": "char_shirt_black",
                         "tie": "char_tie_burgundy"},
    "char_crew_rook": {"height": 1.84, "build": 0.55, "gender": 0.0, "age": 0.5, "skin": 3, "hair": "side_part",
                       "hair_color": "dark", "beard_shadow": 0.5, "heister": "rook"},
    "char_crew_sable": {"height": 1.75, "build": 0.2, "gender": 1.0, "age": 0.38, "skin": 5, "hair": "bob",
                        "hair_color": "dark", "heister": "sable"},
    "char_crew_dutch": {"height": 1.86, "build": 0.95, "gender": 0.0, "age": 0.72, "skin": 1, "hair": "buzz",
                        "hair_color": "grey", "beard_shadow": 0.95, "heister": "dutch"},
    "char_crew_wren": {"height": 1.68, "build": 0.3, "gender": 1.0, "age": 0.08, "skin": 2, "hair": "short",
                       "hair_color": "brown", "heister": "wren"},
    "char_crew_marten": {"height": 1.70, "build": 0.70, "gender": 1.0, "age": 0.62, "skin": 3, "hair": "short",
                         "hair_color": "grey", "heister": "marten"},
    "char_crew_jay": {"height": 1.83, "build": 0.15, "gender": 0.0, "age": 0.15, "skin": 4, "hair": "buzz",
                      "hair_color": "dark", "beard_shadow": 0.3, "heister": "jay"},
    # D4-03: the roster's seventh and eighth heisters
    "char_crew_juno": {"height": 1.73, "build": 0.35, "gender": 1.0, "age": 0.3, "skin": 1, "hair": "side_part",
                       "hair_color": "blond", "heister": "juno"},
    "char_crew_hale": {"height": 1.85, "build": 0.75, "gender": 0.0, "age": 0.5, "skin": 6, "hair": "bald",
                       "hair_color": "dark", "beard_shadow": 0.5, "heister": "hale"},
}


def suit(kit: Kit, suit_mat: str, shirt_mat: str, tie_mat: str | None, shoe_mat: str = "char_shoe_black",
         trouser_mat: str | None = None, hem_z: float = 0.80, button_z: float = 1.06, gloves: str | None = None,
         collar: str = "fold") -> dict:
    """Shirt (+tie) + tailored jacket + trousers + shoes (+gloves). Shared by crew and manager."""
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * k
    shirt_bottom = belt_z - 0.02 * k
    shoes = g.shoes(fit, shoe_mat, "rubber_black")
    kit.add_soft(shoes)
    sh = g.upper_shell(fit, shirt_mat, bottom_z=shirt_bottom, sleeve=2.0)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], shirt_bottom)
    shirt_hull = Hull(fit, [m])
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=2)
        g.cuff_band(m, loops[key], shirt_hull, 0.05 * k, 0.002 * k, shirt_mat)
    g.shirt_collar(m, fit, sh.ring("neck"), kit.hull(), shirt_mat, point_len=0.058, spread=0.26)
    o.hem_all(m, thick=0.003 * k, depth=0.012 * k)
    kit.add_soft(m)
    tr = g.trousers(fit, trouser_mat or suit_mat, belt_z + 0.022 * k, hem_r=0.058, hull=kit.hull())
    tl = g.classify_loops(tr.mesh)
    o.straighten_loop(tr.mesh, tl["top"], iters=3)
    g.trouser_hems(tr, fit, Hull(fit, [shoes], body_regions=set()), trouser_mat or suit_mat)
    o.hem_all(tr.mesh, thick=0.004 * k, depth=0.012 * k)
    kit.add_soft(tr.mesh)
    belt = gk.Belt(fit, Hull(fit, [tr.mesh], body_regions=set()), belt_z, height=0.032, thick=0.004)
    kit.add_soft(belt.mesh("char_leather_black"))
    kit.add_gear(gk.buckle(belt, "chrome", w=0.040, h=0.032))
    hull = kit.hull()
    det = Mesh()
    nk = g.Neck(fit)
    if tie_mat:
        knot = g.tie(det, hull, fit, nk.point(0.0, 0.0, 0.0).z - 0.035 * k, belt_z + 0.03 * k, tie_mat, width=0.076)
        kit.add_soft(det)
        tk = o.Gear()
        tk.prism([(0.016 * k, 0.016 * k), (-0.016 * k, 0.016 * k), (-0.010 * k, -0.019 * k), (0.010 * k, -0.019 * k)],
                 0.0, 0.016 * k, tie_mat)
        tk.bevel(0.004 * k, 2, 30.0)
        kp = knot + Vector((0.0, 0.002 * k, 0.026 * k))
        kit.add_gear(tk.to_mesh(o.frame_from(kp, Vector((0.0, 1.0, 0.35))), anchor=kp))
    else:
        path = g.front_path(hull, 0.0, nk.point(0.0, 0.0).z - 0.02 * k, shirt_bottom + 0.03 * k, 0.02 * k)
        o.strip(det, hull, path, 0.015 * k, 0.0012 * k, shirt_mat, segs_across=1)
        kit.add_soft(det)
        hb = kit.hull()
        btn = Mesh()
        z = nk.point(0.0, 0.0).z - 0.075 * k
        while z > shirt_bottom + 0.05 * k:
            btn.extend(gk.button(hb, Vector((0.0, 0.2, z)), "char_button_pale", r=0.0045, k=k))
            z -= 0.09 * k
        kit.add_gear(btn)
    hull = kit.hull()
    jk, info = g.jacket(fit, hull, suit_mat, hem_z * k, button_z * k)
    kit.add_soft(jk)
    jh = Hull(fit, [jk])
    gear = Mesh()
    gear.extend(gk.button(jh, Vector((0.012 * k, 0.2, button_z * k - 0.012 * k)), "char_button_dark", r=0.009, k=k,
                          thick=0.004))
    kit.add_gear(gear)
    # pocket flaps on the hips + chest welt
    pk = Mesh()
    for sx in (-1.0, 1.0):
        o.patch(pk, jh, Vector((sx * 0.105 * k, 0.0, (hips_z - 0.045 * k))), Vector((1, 0, 0)), Vector((0, 0, 1)),
                o.rounded_rect(0.15 * k, 0.05 * k, 0.006 * k, 2), 0.0035 * k, suit_mat, cast_dir=Vector((0.25 * sx, -1, 0)),
                rings=2, chamfer=0.003 * k)
    o.patch(pk, jh, Vector((-0.095 * k, 0.0, 1.30 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.10 * k, 0.018 * k, 0.003 * k, 1), 0.0025 * k, suit_mat, cast_dir=Vector((-0.2, -1, 0)),
            rings=1, chamfer=0.002 * k)
    kit.add_soft(pk)
    if gloves:
        kit.add_soft(g.gloves(fit, gloves))
    return {"belt": belt, "jacket": info}


def recipe(kit: Kit) -> None:
    opts = kit.opts
    if "heister" in opts:
        who = opts["heister"]
        crew.LOOKS[who](kit)
        kit.notes["fp_sleeve"] = json.dumps(crew.FP_SLEEVES[who], sort_keys=True)
        kit.notes["head_note"] = "hat-free; the crew mask attaches at Head (face centre)"
        return
    suit(kit, opts["suit"], opts["shirt"], opts["tie"], gloves="char_leather_black")
    kit.notes["head_note"] = "head visible with short hair; the crew mask attaches at Head (face centre)"


def build(ctx) -> None:
    kits: list[Kit] = []

    def rec(kit: Kit) -> None:
        kits.append(kit)
        recipe(kit)

    build_character(ctx, rec)
    cg.apply_strand_uvs(kits[0])   # Dutch's beard: strand UVs instead of the box projection
    _headwear_into_hair(ctx)       # all-hair Headwear (Dutch's beard, Hale's moustache) joins Hair


def _headwear_into_hair(ctx) -> None:
    """Facial hair (Dutch's beard and moustache, Hale's moustache) is hair, so it joins the ``Hair`` mesh (the whole ``Headwear``
    is hair-material: masks seat over hair, garments may not poke into them, see test_crew.gd)."""
    import bpy

    hw = bpy.data.objects.get("Headwear")
    hair = bpy.data.objects.get("Hair")
    if hw is None or hair is None or not all(m.name.startswith("M_char_hair_") for m in hw.data.materials):
        return
    n_hw = len(hw.data.polygons)
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    hw.select_set(True)
    hair.select_set(True)
    bpy.context.view_layer.objects.active = hair
    bpy.ops.object.join()
    tris = json.loads(ctx.source_extra["tris_by_mesh"])
    tris["Hair"] = tris.get("Hair", 0) + tris.pop("Headwear")
    ctx.source_extra["tris_by_mesh"] = json.dumps(tris, sort_keys=True)
    ctx.source_extra["meshes"] = ",".join(sorted(tris))
    ctx.source_extra["hair_note"] = f"facial hair ({n_hw} tris) joined into Hair"
