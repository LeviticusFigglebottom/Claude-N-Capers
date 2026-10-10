"""P3 special-enemy review renders from the exported glbs (Cycles CPU; not an asset script).

    blender -b --factory-startup --python tools/blender/characters/_special_review.py -- <mode> <out.png>

* ``lineup``: every special + TAC Light + Patrol in A-pose, front, colour (``_review/specials_lineup.png``).
* ``silhouette``: flat black figures on white seen from 30 m with a 60 deg / 1080 p camera (~56 px tall),
  two rows: front and three-quarter (45 deg); each row cropped to the figure band and the sheet upscaled
  2x nearest-neighbour (``_review/specials_silhouette_30m.png``).
* ``closeups``: the Wrecker's three head states (Faceplate on / Faceplate off / Visor + HeadArmored off)
  and the Phantom's goggles glowing (``_review/specials_closeups.png``).
* ``views``: env IDS, each figure front / 3/4 / side / back (iteration aid).

The Bulwarks carry their shield at ENV A's ``HeavySpecialTweak.bulwark_shield_offset`` (0, 0.95, -0.6).
Env CHAR_ROOT reads the glbs from another output root, SAMPLES overrides the sample count.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.environ.get("CHAR_ROOT") or str(
    __import__("pathlib").Path(__file__).resolve().parents[3] / "game" / "assets" / "characters")
SPECIALS = ["char_patrol_officer", "char_tac_light", "char_tac_heavy", "char_stinger", "char_corpsman",
            "char_bulwark", "char_bulwark_aegis", "char_phantom", "char_wrecker", "char_longshot", "char_brandt"]
SHIELDS = {"char_bulwark": "char_bulwark_shield", "char_bulwark_aegis": "char_bulwark_aegis_shield"}
SHIELD_OFFSET = Vector((0.0, 0.6, 0.95))     # Godot (0, 0.95, -0.6) in Blender axes
GLOW = (0.231, 1.0, 0.416, 1.0)
mode, out = sys.argv[sys.argv.index("--") + 1:][:2]
IDS = os.environ["IDS"].split(",") if os.environ.get("IDS") else SPECIALS

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def imp(cid, loc, rot=0.0, shield=True):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f"{ROOT}/{cid}/{cid}.glb")
    new = [o for o in bpy.data.objects if o not in before]
    if shield and cid in SHIELDS:
        b2 = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=f"{ROOT}/{SHIELDS[cid]}/{SHIELDS[cid]}.glb")
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


def glow_goggles():
    for m in bpy.data.materials:
        if "goggle_glow" in m.name and m.use_nodes:
            bsdf = m.node_tree.nodes.get("Principled BSDF")
            if bsdf is not None:
                bsdf.inputs["Emission Color"].default_value = GLOW
                bsdf.inputs["Emission Strength"].default_value = 6.0


def light(name, loc, energy, size, color=(1, 1, 1), target=(0, 0, 1.2)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size, ld.color = energy, size, color
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(lo)


def setup_render(samples=48):
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = int(os.environ.get("SAMPLES", str(samples)))
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"


def studio(scale=1.0):
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.30, 0.27, 0.24, 1)
    bg.inputs[1].default_value = 0.35
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    fl = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.28, 0.24, 1)
    fl.data.materials.append(fm)
    light("key", (3.0, 5.0, 4.0), 2200 * scale, 4.0, (1.0, 0.90, 0.78))
    light("fill", (-5.0, 4.0, 2.0), 700 * scale, 5.0, (0.75, 0.82, 1.0))
    light("rim", (1.0, -5.0, 3.5), 1600 * scale, 3.0, (1.0, 0.95, 0.9))


cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam


def aim(loc, tgt):
    cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def row_x(i, n, spacing):
    return -(i - (n - 1) / 2) * spacing


def upscale(img_pixels, w, h, f=2):
    big = [0.0] * (w * f * h * f * 4)
    for y in range(h * f):
        for x in range(w * f):
            s_i = ((y // f) * w + x // f) * 4
            d_i = (y * w * f + x) * 4
            big[d_i:d_i + 4] = img_pixels[s_i:s_i + 4]
    return big


def save(pixels, w, h, path):
    img = bpy.data.images.new("out", w, h, alpha=True)
    img.pixels.foreach_set(pixels)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


if mode == "lineup":
    setup_render()
    studio()
    for i, cid in enumerate(IDS):
        imp(cid, (row_x(i, len(IDS), 1.35), 0, 0))
    glow_goggles()
    sc.render.resolution_x, sc.render.resolution_y = 3600, 1000
    cam_d.lens = 50
    aim((0.0, 23.0, 1.1), (0, 0, 0.95))
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)

elif mode == "silhouette":
    setup_render(8)
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.8, 0.8, 0.8, 1)
    bg.inputs[1].default_value = 1.0
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    cam_d.sensor_fit = "VERTICAL"
    cam_d.angle_y = math.radians(60.0)
    aim((0.0, 30.0, 1.0), (0, 0, 1.0))
    sc.render.filter_size = 1.5
    band_w = 1000
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
    for rot in (0.0, math.radians(45.0)):
        for o in list(bpy.data.objects):
            if o.type in ("MESH", "ARMATURE", "EMPTY"):
                bpy.data.objects.remove(o, do_unlink=True)
        for i, cid in enumerate(IDS):
            imp(cid, (row_x(i, len(IDS), 1.25), 0, 0), rot)
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
    h = sum(r[2] for r in rows) + 6
    sheet = [1.0] * (w * h * 4)
    y0 = 0
    for px, rw, rh in reversed(rows):     # image rows go bottom-up: 3/4 row at the bottom
        for y in range(rh):
            sheet[((y0 + y) * w) * 4:((y0 + y) * w + rw) * 4] = px[(y * rw) * 4:((y + 1) * rw) * 4]
        y0 += rh
        for y in range(y0, min(y0 + 6, h)):
            for x in range(w):
                sheet[(y * w + x) * 4:(y * w + x) * 4 + 4] = [0.55, 0.55, 0.55, 1.0]
        y0 += 6
    save(upscale(sheet, w, h), w * 2, h * 2, out)

elif mode == "closeups":
    setup_render(64)
    studio(0.25)
    states = [set(), {"Faceplate"}, {"Faceplate", "Visor", "HeadArmored"}]
    for i, hide in enumerate(states):
        objs = imp("char_wrecker", (row_x(i, 4, 1.0), 0, 0), math.radians(15.0))
        for o in objs:
            if o.type == "MESH" and o.name.split(".")[0] in hide:
                o.hide_render = True
    imp("char_phantom", (row_x(3, 4, 1.0), 0, 0.0), math.radians(25.0))
    glow_goggles()
    sc.render.resolution_x, sc.render.resolution_y = 3000, 800
    cam_d.lens = 85
    aim((0.0, 9.6, 1.78), (0.0, 0.0, 1.62))
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)

elif mode == "views":
    setup_render(32)
    studio(0.6)
    n = len(IDS) * 4
    i = 0
    for cid in IDS:
        for rot in (0.0, 45.0, 90.0, 180.0):
            imp(cid, (row_x(i, n, 1.2), 0, 0), math.radians(rot))
            i += 1
    glow_goggles()
    sc.render.resolution_x, sc.render.resolution_y = 400 * n, 900
    cam_d.lens = 50
    aim((0.0, 1.55 * n + 1.5, 1.05), (0, 0, 1.0))
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
print("WROTE", out)
