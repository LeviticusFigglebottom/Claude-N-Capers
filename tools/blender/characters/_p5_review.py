"""D3-01 P5 cast review renders from the exported glbs (Cycles CPU; not an asset script).

    blender -b --factory-startup --python tools/blender/characters/_p5_review.py -- <mode> <out.png>

Env ``IDS`` (comma separated asset ids) picks the figures, ``CAST_GROUPS`` (``|``-separated groups of
comma-separated ids) groups them with gaps, ``SAMPLES`` the sample count, ``CHAR_ROOT`` another glb
root. Modes:

* ``lineup``: one heist row in A-pose (``IDS``), neutral key + rim (``BACK=1`` views them from behind). ``_p5_stitch.py`` stacks the rows
  with heist labels into ``_review/p5_lineup.png``.
* ``faces``: one 3/4 head close-up per id, written as ``<out>.<id>.png`` tiles (stitched by
  ``_p5_stitch.py`` into ``_review/p5_faces.png``).
* ``silhouette``: every id seen from 30 m with a 60 deg / 1080 p camera (~56 px tall), groups separated
  by gaps: flat black on a light card on top, colour under dim night light below; cropped (the
  stitch script upscales 3x nearest-neighbour into ``_review/p5_silhouette_30m.png``).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.environ.get("CHAR_ROOT") or os.path.join(HERE, "..", "..", "..", "game", "assets", "characters")
GROUPS = [g.split(",") for g in os.environ["CAST_GROUPS"].split("|")] if os.environ.get("CAST_GROUPS") else None
IDS = os.environ["IDS"].split(",") if os.environ.get("IDS") else [i for g in (GROUPS or []) for i in g]
mode, out = sys.argv[sys.argv.index("--") + 1:][:2]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sys.path.insert(0, HERE)


def imp(cid, loc, rot=0.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f"{REPO}/{cid}/{cid}.glb")
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.parent is None:
            o.location = Vector(loc) + o.location
            o.rotation_euler.z += rot
    return new


def light(name, loc, energy, size, color=(1, 1, 1), target=(0, 0, 1.2)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size, ld.color = energy, size, color
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(lo)


def aim(cam, loc, tgt):
    cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def flat(rgb, name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*rgb, 1)
    on = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], on.inputs[0])
    return m


sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = int(os.environ.get("SAMPLES", "40"))
sc.cycles.use_denoising = True
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"
world = bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam


def floor(rgb):
    bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, 0))
    fl = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1)
    fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.5
    fl.data.materials.append(fm)


def lib_mats():
    import _review_mats

    _review_mats.library_textures()
    if hasattr(_review_mats, "terminator"):
        _review_mats.terminator()


if mode == "lineup":
    spacing = 1.45
    xs = [i * spacing for i in range(len(IDS))]
    mid = (xs[0] + xs[-1]) / 2
    back = os.environ.get("BACK") == "1"
    for cid, x in zip(IDS, xs):
        imp(cid, (-(x - mid), 0, 0))
    lib_mats()
    bg.inputs[0].default_value = (0.22, 0.22, 0.24, 1)
    bg.inputs[1].default_value = 0.30
    floor((0.13, 0.13, 0.14))
    light("key", (5.0, 8.0, 5.0), 1400, 8.0, (1.0, 0.95, 0.88), target=(0, 0, 1.0))
    light("fill", (-6.0, 8.0, 1.8), 500, 10.0, (0.86, 0.92, 1.0), target=(0, 0, 1.0))
    light("rim", (0.0, -6.0, 3.5), 900, 10.0, (1.0, 1.0, 1.0))
    span = xs[-1] - xs[0] + 1.2
    sc.render.resolution_x, sc.render.resolution_y = int(span * 170), 560
    cam_d.lens = 50
    cam_d.sensor_fit = "HORIZONTAL"
    aim(cam, (0.0, (-1.0 if back else 1.0) * span / 0.72 * 1.02, 1.0), (0, 0, 0.98))
    if back:
        for lo in [ob for ob in bpy.data.objects if ob.type == "LIGHT"]:
            lo.location.y = -lo.location.y
            lo.rotation_euler = (Vector((0, 0, 1.0)) - lo.location).to_track_quat("-Z", "Y").to_euler()
elif mode == "faces":
    lib_mats()
    bg.inputs[0].default_value = (0.30, 0.30, 0.31, 1)
    bg.inputs[1].default_value = 0.4
    tile = int(os.environ.get("TILE", "420"))
    sc.render.resolution_x, sc.render.resolution_y = tile, tile
    cam_d.lens = 85
    tops = {}
    for i, cid in enumerate(IDS):
        objs = imp(cid, (i * 4.0, 0, 0))
        top = max((ob.matrix_world @ Vector(c)).z for ob in objs if ob.type == "MESH" and ob.name.startswith("Body")
                  for c in ob.bound_box)
        tops[cid] = (i * 4.0, top)
    lib_mats()
    light("key", (2.0, 3.0, 3.0), 300, 2.0, (1.0, 0.95, 0.88))
    light("fill", (-3.0, 2.0, 1.8), 90, 3.0, (0.82, 0.88, 1.0))
    light("rim", (0.5, -3.0, 2.5), 160, 2.0)
    for lo in [ob for ob in bpy.data.objects if ob.type == "LIGHT"]:
        lo["base"] = tuple(lo.location)
    for cid in IDS:
        x0, top = tops[cid]
        for lo in [ob for ob in bpy.data.objects if ob.type == "LIGHT"]:
            b = lo["base"]
            lo.location = (b[0] + x0, b[1], b[2] + top - 1.75)
            lo.rotation_euler = (Vector((x0, 0, top - 0.1)) - lo.location).to_track_quat("-Z", "Y").to_euler()
        tgt = Vector((x0, 0.0, top - 0.10))
        a = math.radians(35)
        aim(cam, tgt + Vector((-math.sin(a) * 1.05, math.cos(a) * 1.05, 0.04)), tgt)
        sc.render.filepath = out + f".{cid}.png"
        bpy.ops.render.render(write_still=True)
    print("WROTE tiles", out)
    sys.exit(0)
elif mode == "silhouette":
    spacing, gap = 1.3, 2.6
    groups = GROUPS or [IDS]
    xs, ids = [], []
    x = 0.0
    for gi, grp in enumerate(groups):
        if gi:
            x += gap - spacing
        for cid in grp:
            xs.append(x)
            ids.append(cid)
            x += spacing
    mid = (xs[0] + xs[-1]) / 2
    sil = flat((0.02, 0.02, 0.02), "sil")
    for cid, xx in zip(ids, xs):
        for ob in imp(cid, (-(xx - mid), 0, 2.3)):
            if ob.type == "MESH":
                for s in range(len(ob.material_slots)):
                    ob.material_slots[s].material = sil
        imp(cid, (-(xx - mid), 0, 0))
    lib_mats()
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -1.5, 3.4))
    card = bpy.context.active_object
    card.scale = (80, 2.4, 1)
    card.rotation_euler = (math.radians(90), 0, 0)
    card.data.materials.append(flat((0.8, 0.8, 0.8), "card"))
    floor((0.10, 0.10, 0.11))
    bg.inputs[0].default_value = (0.05, 0.055, 0.065, 1)
    bg.inputs[1].default_value = 1.0
    light("key", (3.0, 8.0, 5.0), 1400, 8.0, (0.95, 0.97, 1.0), target=(0, 0, 0.9))
    light("fill", (-6.0, 6.0, 2.0), 500, 8.0, (1.0, 0.85, 0.7), target=(0, 0, 0.9))
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    cam_d.sensor_fit = "VERTICAL"
    cam_d.angle_y = math.radians(60.0)
    aim(cam, (0.0, 30.0, 2.15), (0, 0, 2.15))
    sc.cycles.samples = 32
    sc.render.filter_size = 1.5
    sc.render.use_border = True
    sc.render.use_crop_to_border = True
    ppm = 1080 / (2 * 30 * math.tan(math.radians(30)))
    half_w = min(960.0, ((xs[-1] - xs[0]) / 2 + 0.8) * ppm)
    lo_px, hi_px = 540 + (-0.15 - 2.15) * ppm, 540 + (4.3 - 2.15) * ppm
    sc.render.border_min_x, sc.render.border_max_x = (960 - half_w) / 1920, (960 + half_w) / 1920
    sc.render.border_min_y, sc.render.border_max_y = lo_px / 1080, hi_px / 1080

sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("WROTE", out)
