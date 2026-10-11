"""D2-01 faction review renders from the exported glbs (Cycles CPU; not an asset script).

    blender -b --factory-startup --python tools/blender/characters/_faction_review.py -- <mode> <out.png>

* ``lineup``: a grid, rows = factions (tac, frd, sentinel, zero), columns = Patrol, TAC Light, TAC Heavy
  and the specials (Bulwark with its faction shield), then the FRD field agent (FRD row: ``frd_agent`` and
  ``frd_agent_b``; Sentinel row: its reskin; no TAC / Zero agent), front three-quarter, colour
  (``_review/factions_lineup.png``).
* ``silhouette``: the same grid as flat black figures seen from 30 m with a 60 deg / 1080 p camera,
  each row cropped to the figure band and upscaled 2x nearest-neighbour
  (``_review/factions_silhouette_30m.png``).
* ``views``: env IDS, each figure front / 3/4 / side / back (iteration aid).

Env SAMPLES overrides the sample count.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))), "game", "assets", "characters")
ROLES = ["patrol_officer", "tac_light", "tac_heavy", "phantom", "stinger", "bulwark", "wrecker", "longshot", "corpsman",
         "frd_agent", "frd_agent_b"]
#: the FRD field agent is FRD-only (base = FRD look): no TAC / Zero cell, ``_b`` only in the FRD row
AGENT_CELLS = {("frd_agent", "frd"): "char_frd_agent", ("frd_agent", "sentinel"): "char_frd_agent_sentinel",
               ("frd_agent_b", "frd"): "char_frd_agent_b"}
FACTIONS = ["tac", "frd", "sentinel", "zero"]
SHIELD_OFFSET = Vector((0.0, 0.6, 0.95))     # Godot (0, 0.95, -0.6) in Blender axes
GLOW = (0.231, 1.0, 0.416, 1.0)
mode, out = sys.argv[sys.argv.index("--") + 1:][:2]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam


def cid(role, fac):
    if role.startswith("frd_agent"):
        return AGENT_CELLS.get((role, fac))
    return f"char_{role}" if fac == "tac" else f"char_{role}_{fac}"


def shield_id(fac):
    return "char_bulwark_shield" if fac == "tac" else f"char_bulwark_{fac}_shield"


def imp(asset, loc, rot=0.0, shield=None):
    if asset is None:
        return []
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f"{ROOT}/{asset}/{asset}.glb")
    new = [o for o in bpy.data.objects if o not in before]
    if shield:
        b2 = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=f"{ROOT}/{shield}/{shield}.glb")
        sh = [o for o in bpy.data.objects if o not in b2]
        for o in sh:
            if o.name.startswith("Collision"):
                o.hide_render = True
            if o.parent is None:
                o.location += SHIELD_OFFSET
        new += sh
    bpy.context.view_layer.update()
    for o in new:
        if o.parent is None:
            o.matrix_world = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rot, 4, "Z") @ o.matrix_world
    return new


def grid(rot, spacing_x=1.3, spacing_z=2.4):
    for r, fac in enumerate(FACTIONS):
        for c, role in enumerate(ROLES):
            x = -(c - (len(ROLES) - 1) / 2) * spacing_x
            z = (len(FACTIONS) - 1 - r) * spacing_z
            imp(cid(role, fac), (x, 0.0, z), rot, shield_id(fac) if role == "bulwark" else None)


def light(name, loc, energy, size, color=(1, 1, 1), target=(0, 0, 1.2)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size, ld.color = energy, size, color
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(lo)


def setup_render(samples):
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = int(os.environ.get("SAMPLES", str(samples)))
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"


def world(color, strength):
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = color
    bg.inputs[1].default_value = strength


def aim(loc, tgt):
    cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def prep_colour():
    sys.path.insert(0, HERE)
    import _review_mats

    _review_mats.prepare()
    for m in bpy.data.materials:
        if "goggle_glow" in m.name and m.use_nodes:
            bsdf = m.node_tree.nodes.get("Principled BSDF")
            if bsdf is not None:
                bsdf.inputs["Emission Color"].default_value = GLOW
                bsdf.inputs["Emission Strength"].default_value = 6.0


if mode == "lineup":
    setup_render(32)
    world((0.30, 0.27, 0.24, 1), 0.25)
    grid(math.radians(20.0))
    prep_colour()
    light("key", (4.0, 9.0, 9.0), 3800, 8.0, (1.0, 0.92, 0.82), (0, 0, 4.5))
    light("fill", (-7.0, 8.0, 4.0), 1300, 9.0, (0.78, 0.84, 1.0), (0, 0, 4.5))
    light("rim", (0.0, -8.0, 7.0), 2200, 9.0, (1.0, 0.95, 0.9), (0, 0, 4.5))
    sc.render.resolution_x, sc.render.resolution_y = 3300, 2300
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = 15.0
    aim((0.0, 30.0, 4.55), (0.0, 0.0, 4.55))
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)

elif mode == "silhouette":
    # one camera at 30 m per row (each faction rendered separately, then stacked)
    setup_render(8)
    world((0.8, 0.8, 0.8, 1), 1.0)
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    cam_d.sensor_fit = "VERTICAL"
    cam_d.angle_y = math.radians(60.0)
    aim((0.0, 30.0, 1.0), (0, 0, 1.0))
    sc.render.filter_size = 1.5
    band_w = 900
    sc.render.use_border = True
    sc.render.use_crop_to_border = True
    sc.render.border_min_x, sc.render.border_max_x = (1920 - band_w) / 2 / 1920, (1920 + band_w) / 2 / 1920
    sc.render.border_min_y, sc.render.border_max_y = (540 - 41) / 1080, (540 + 59) / 1080
    black = bpy.data.materials.new("sil")
    black.use_nodes = True
    nt = black.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.02, 0.02, 0.02, 1)
    outn = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], outn.inputs[0])
    rows = []
    for fac in FACTIONS:
        for o in list(bpy.data.objects):
            if o.type in ("MESH", "ARMATURE", "EMPTY"):
                bpy.data.objects.remove(o, do_unlink=True)
        for c, role in enumerate(ROLES):
            x = -(c - (len(ROLES) - 1) / 2) * 1.25
            imp(cid(role, fac), (x, 0.0, 0.0), 0.0, shield_id(fac) if role == "bulwark" else None)
        for o in bpy.data.objects:
            if o.type == "MESH":
                for j in range(len(o.material_slots)):
                    o.material_slots[j].material = black
        tmp = out + f".row{len(rows)}.png"
        sc.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(tmp)
        rows.append((list(img.pixels), img.size[0], img.size[1]))
        os.remove(tmp)
    w = rows[0][1]
    h = sum(r[2] for r in rows) + 6 * len(rows)
    sheet = [1.0] * (w * h * 4)
    y0 = 0
    for px, rw, rh in reversed(rows):     # image rows go bottom-up: zero at the bottom
        for y in range(rh):
            sheet[((y0 + y) * w) * 4:((y0 + y) * w + rw) * 4] = px[(y * rw) * 4:((y + 1) * rw) * 4]
        y0 += rh
        for y in range(y0, min(y0 + 6, h)):
            sheet[(y * w) * 4:(y * w + w) * 4] = [0.55, 0.55, 0.55, 1.0] * w
        y0 += 6
    f = 2
    big = [0.0] * (w * f * h * f * 4)
    for y in range(h * f):
        src = (y // f) * w * 4
        row = []
        for x in range(w):
            row += sheet[src + x * 4:src + x * 4 + 4] * f
        big[y * w * f * 4:(y + 1) * w * f * 4] = row
    img = bpy.data.images.new("out", w * f, h * f, alpha=True)
    img.pixels.foreach_set(big)
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()

elif mode == "views":
    setup_render(24)
    world((0.30, 0.27, 0.24, 1), 0.6)
    ids = os.environ["IDS"].split(",")
    n = len(ids) * 4
    i = 0
    for a in ids:
        for rot in (0.0, 45.0, 90.0, 180.0):
            imp(a, (-(i - (n - 1) / 2) * 1.2, 0, 0), math.radians(rot))
            i += 1
    prep_colour()
    light("key", (3.0, 5.0, 4.0), 1300, 4.0, (1.0, 0.90, 0.78))
    light("fill", (-5.0, 4.0, 2.0), 420, 5.0, (0.75, 0.82, 1.0))
    light("rim", (1.0, -5.0, 3.5), 960, 3.0, (1.0, 0.95, 0.9))
    sc.render.resolution_x, sc.render.resolution_y = 400 * n, 900
    cam_d.lens = 50
    aim((0.0, 1.55 * n + 1.5, 1.05), (0, 0, 1.0))
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
print("WROTE", out)
