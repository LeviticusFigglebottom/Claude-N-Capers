"""QC-36 cartel gunmen review renders from the exported glbs (Cycles CPU; not an asset script).

    blender -b --factory-startup --python tools/blender/characters/_cartel_review.py -- <mode> <out.png>

* ``lineup``: the three Co-op gunmen next to the comparison cast (Patrol, TAC Light, a civilian and
  the crew body), front three-quarter (top row) and back three-quarter (bottom row, the slung gun),
  colour (``_review/cartel_lineup.png``).
* ``silhouette``: the same figures as flat black shapes seen from 30 m with a 60 deg / 1080 p
  camera, cropped to the figure band and upscaled 3x nearest-neighbour
  (``_review/cartel_silhouette_30m.png``).

Env SAMPLES overrides the sample count.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "..", "game", "assets", "characters")
ROOT = os.path.normpath(ROOT)
CAST = ["char_cartel_gunman", "char_cartel_gunman_b", "char_cartel_gunman_c", "char_patrol_officer",
        "char_tac_light", "char_civilian_customer_b", "char_crew_body"]
mode, out = sys.argv[sys.argv.index("--") + 1:][:2]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam


def imp(asset, loc, rot=0.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f"{ROOT}/{asset}/{asset}.glb")
    new = [o for o in bpy.data.objects if o not in before]
    bpy.context.view_layer.update()
    for o in new:
        if o.parent is None:
            o.matrix_world = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rot, 4, "Z") @ o.matrix_world
    return new


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


def col_x(c, spacing):
    return -(c - (len(CAST) - 1) / 2) * spacing


if mode == "lineup":
    setup_render(32)
    world((0.30, 0.29, 0.28, 1), 0.25)
    for c, a in enumerate(CAST):
        imp(a, (col_x(c, 1.3), 0.0, 2.3), math.radians(20.0))
        imp(a, (col_x(c, 1.3), 0.0, 0.0), math.radians(200.0))
    sys.path.insert(0, HERE)
    import _review_mats

    _review_mats.prepare()
    light("key", (4.0, 9.0, 9.0), 3000, 8.0, (1.0, 0.92, 0.82), (0, 0, 2.2))
    light("fill", (-7.0, 8.0, 4.0), 1100, 9.0, (0.78, 0.84, 1.0), (0, 0, 2.2))
    light("rim", (0.0, -8.0, 7.0), 1800, 9.0, (1.0, 0.95, 0.9), (0, 0, 2.2))
    sc.render.resolution_x, sc.render.resolution_y = 2400, 1560
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = 9.6
    aim((0.0, 30.0, 2.05), (0.0, 0.0, 2.05))
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)

elif mode == "silhouette":
    setup_render(8)
    world((0.8, 0.8, 0.8, 1), 1.0)
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    cam_d.sensor_fit = "VERTICAL"
    cam_d.angle_y = math.radians(60.0)
    aim((0.0, 30.0, 1.0), (0, 0, 1.0))
    sc.render.filter_size = 1.5
    band_w = 820
    sc.render.use_border = True
    sc.render.use_crop_to_border = True
    sc.render.border_min_x, sc.render.border_max_x = (1920 - band_w) / 2 / 1920, (1920 + band_w) / 2 / 1920
    sc.render.border_min_y, sc.render.border_max_y = (540 - 41) / 1080, (540 + 59) / 1080
    black = bpy.data.materials.new("sil")
    black.use_nodes = True
    nt = black.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.02, 0.02, 0.02, 1)
    outn = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], outn.inputs[0])
    rows = []
    for rot in (0.0, 180.0):
        for o in list(bpy.data.objects):
            if o.type in ("MESH", "ARMATURE", "EMPTY"):
                bpy.data.objects.remove(o, do_unlink=True)
        for c, a in enumerate(CAST):
            imp(a, (col_x(c, 1.25), 0.0, 0.0), math.radians(rot))
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
    for px, rw, rh in reversed(rows):     # image rows go bottom-up: the back view at the bottom
        for y in range(rh):
            sheet[((y0 + y) * w) * 4:((y0 + y) * w + rw) * 4] = px[(y * rw) * 4:((y + 1) * rw) * 4]
        y0 += rh
        for y in range(y0, min(y0 + 6, h)):
            sheet[(y * w) * 4:(y * w + w) * 4] = [0.55, 0.55, 0.55, 1.0] * w
        y0 += 6
    f = 3
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
print("WROTE", out)
