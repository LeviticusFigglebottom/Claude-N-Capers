"""D2-03 crew review renders from the exported heister glbs (Cycles CPU; not an asset script).

    blender -b --factory-startup --python tools/blender/characters/_crew_review.py -- <mode> <out.png>

* ``lineup``: the heisters in A-pose, each bare-faced and then masked (the mask glb placed at the
  game's ``Head/Socket`` point: ``character_spec.gd`` SOCKET_POINTS["Head"] scaled by height, so the
  render shows the in-game fit), library materials (``_crew_review/crew_lineup.png``).
* ``silhouette``: flat black figures, masked, 30 m from a 60 deg / 1080 p camera (~56 px tall), front
  row and side row, cropped to the figure band and upscaled 2x nearest-neighbour
  (``crew_silhouette_30m.png``), as ``_outfit_review.py``.
* ``faces``: per heister a 3/4 head close-up bare, the same masked, and a masked profile (mask depth
  over nose and brow) (``crew_faces.png``).

Env ``SAMPLES`` overrides the sample count, ``SCALE`` the resolution percentage (drafts); env ``CHAR_ROOT`` reads the glbs from another root.
"""
import math
import os
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import _review_mats  # noqa: E402

ASSETS = __import__("pathlib").Path(HERE).resolve().parents[2] / "game" / "assets"
ROOT = os.environ.get("CHAR_ROOT") or str(ASSETS / "characters")
MASKS = str(ASSETS / "masks")
CREW = [("char_crew_rook", 1.84, "mask_gilded_heron"), ("char_crew_sable", 1.75, "mask_base_vulpine"),
        ("char_crew_dutch", 1.86, "mask_base_bruiser"), ("char_crew_wren", 1.68, "mask_base_owl"),
        ("char_crew_marten", 1.70, "mask_base_signal"), ("char_crew_jay", 1.83, "mask_base_lucha"),
        ("char_crew_juno", 1.73, "mask_base_moth"), ("char_crew_hale", 1.85, "mask_base_welder")]
HEAD_SOCKET = Vector((0.0, 0.0767, 1.666))   # Godot (0, 1.666, -0.0767) at 1.78 m, in Blender axes
mode, out = sys.argv[sys.argv.index("--") + 1:][:2]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def _import(path: str) -> list:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def figure(cid: str, height: float, mask: str | None, loc: Vector, rot_z: float = 0.0):
    """Character (+ mask at the Head socket) under one empty at ``loc``, turned by ``rot_z``."""
    pivot = bpy.data.objects.new(f"fig_{cid}_{'m' if mask else 'b'}", None)
    sc.collection.objects.link(pivot)
    new = _import(f"{ROOT}/{cid}/{cid}.glb")
    if mask:
        mnew = _import(f"{MASKS}/{mask}/{mask}.glb")
        for o in mnew:
            if o.parent is None:
                o.location = HEAD_SOCKET * (height / 1.78)
        new += mnew
    for o in new:
        if o.parent is None:
            o.parent = pivot
    pivot.location = loc
    pivot.rotation_euler.z = rot_z
    return pivot


sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = int(os.environ.get("SAMPLES", "48"))
sc.cycles.use_denoising = True
sc.render.resolution_percentage = int(os.environ.get("SCALE", "100"))
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


def light(name, loc, energy, size, color=(1, 1, 1), target=(0, 0, 1.2)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size, ld.color = energy, size, color
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(lo)


def aim(loc, tgt):
    cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def studio(e_key=2200, e_fill=700, e_rim=1600, spread=1.0):
    _review_mats.prepare()
    bg.inputs[0].default_value = (0.30, 0.27, 0.24, 1)
    bg.inputs[1].default_value = 0.35
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    fl = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.28, 0.24, 1)
    fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.5
    fl.data.materials.append(fm)
    light("key", (3.0 * spread, 5.0, 4.0), e_key, 4.0 * spread, (1.0, 0.90, 0.78))
    light("fill", (-5.0 * spread, 4.0, 2.0), e_fill, 5.0 * spread, (0.75, 0.82, 1.0))
    light("rim", (1.0, -5.0, 3.5), e_rim, 3.0 * spread, (1.0, 0.95, 0.9))


def render(path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def load_px(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(img)
    return a


def save_px(a, path):
    h, w = a.shape[:2]
    img = bpy.data.images.new("out", w, h, alpha=True)
    img.pixels.foreach_set(a.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


if mode == "lineup":
    spacing, gap = 1.3, 0.45
    xs = []
    x = 0.0
    for i in range(len(CREW)):
        xs += [x, x + spacing]
        x += 2 * spacing + gap
    mid = (xs[0] + xs[-1]) / 2
    for i, (cid, h, mask) in enumerate(CREW):
        figure(cid, h, None, Vector((-(xs[2 * i] - mid), 0, 0)), 0.0)
        figure(cid, h, mask, Vector((-(xs[2 * i + 1] - mid), 0, 0)), 0.0)
    studio(e_key=1500, e_fill=500, e_rim=1300, spread=2.0)
    # sized for six heisters at 3600 px / 21.5 m; both scale with the roster so the figures keep their pixel size
    grow = len(CREW) / 6
    sc.render.resolution_x, sc.render.resolution_y = round(3600 * grow), 1000
    cam_d.lens = 50 / grow ** 0.6
    aim((0.0, 21.5 * grow, 1.1), (0, 0, 0.92))
    render(out)
elif mode == "silhouette":
    bg.inputs[0].default_value = (0.8, 0.8, 0.8, 1)
    bg.inputs[1].default_value = 1.0
    black = bpy.data.materials.new("sil")
    black.use_nodes = True
    nt = black.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.02, 0.02, 0.02, 1)
    on = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], on.inputs[0])
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    cam_d.sensor_fit = "VERTICAL"
    cam_d.angle_y = math.radians(60.0)
    aim((0.0, 30.0, 1.0), (0, 0, 1.0))
    sc.cycles.samples = 8
    sc.render.filter_size = 1.5
    sc.render.use_border = True
    sc.render.use_crop_to_border = True
    sc.render.border_min_x, sc.render.border_max_x = (1920 - 500) / 2 / 1920, (1920 + 500) / 2 / 1920
    sc.render.border_min_y, sc.render.border_max_y = (540 - 41) / 1080, (540 + 59) / 1080
    tiles = []
    tmp = tempfile.mkdtemp()
    for row, rot in enumerate((0.0, math.pi / 2)):
        for o in list(bpy.data.objects):
            if o.type != "CAMERA":
                bpy.data.objects.remove(o, do_unlink=True)
        for i, (cid, h, mask) in enumerate(CREW):
            figure(cid, h, mask, Vector((-(i - 1.5) * 1.7, 0, 0)), rot)
        for o in bpy.data.objects:
            if o.type == "MESH":
                for s in range(len(o.material_slots)):
                    o.material_slots[s].material = black
        p = os.path.join(tmp, f"sil{row}.png")
        render(p)
        tiles.append(load_px(p))
    a = np.concatenate(tiles[::-1], axis=0)      # pixel rows run bottom-up: front row on top
    a = a.repeat(2, axis=0).repeat(2, axis=1)
    save_px(a, out)
elif mode == "faces":
    sets = {0.0: [], 6.0: []}
    for i, (cid, h, mask) in enumerate(CREW):
        sets[0.0].append(figure(cid, h, None, Vector((i * 3.0, 0, 0))))
        sets[6.0].append(figure(cid, h, mask, Vector((i * 3.0, 6.0, 0))))
    studio(e_key=260, e_fill=90, e_rim=200)
    sc.render.resolution_x, sc.render.resolution_y = 700, 700
    cam_d.lens = 85
    tmp = tempfile.mkdtemp()
    rows = []
    for row, (dy, ang) in enumerate(((0.0, 35.0), (6.0, 35.0), (6.0, 90.0))):
        tiles = []
        for key, pivots in sets.items():
            for pv in pivots:
                for o in pv.children_recursive:
                    o.hide_render = key != dy
        for i, (cid, h, mask) in enumerate(CREW):
            tgt = Vector((i * 3.0, dy + 0.02, 1.666 * h / 1.78 - 0.02))
            a = math.radians(ang)
            aim(tgt + Vector((math.sin(a) * 0.95, math.cos(a) * 0.95, 0.03)), tgt)
            p = os.path.join(tmp, f"f{row}_{i}.png")
            render(p)
            tiles.append(load_px(p))
        rows.append(np.concatenate(tiles, axis=1))
    save_px(np.concatenate(rows[::-1], axis=0), out)
elif mode == "detail":
    # env ID (asset id) and CAM = "target_z,distance,angle_deg": a close-up for checking garments
    cid = os.environ.get("ID", "char_crew_dutch")
    h = next(hh for c, hh, _m in CREW if c == cid)
    figure(cid, h, None, Vector((0, 0, 0)))
    studio(e_key=260, e_fill=90, e_rim=200)
    tz, dist, ang = map(float, os.environ.get("CAM", "1.35,1.4,30").split(","))
    sc.render.resolution_x, sc.render.resolution_y = 900, 900
    cam_d.lens = 70
    a = math.radians(ang)
    tgt = Vector((0.0, 0.0, tz))
    aim(tgt + Vector((math.sin(a) * dist, math.cos(a) * dist, 0.05)), tgt)
    render(out)
print("WROTE", out)
