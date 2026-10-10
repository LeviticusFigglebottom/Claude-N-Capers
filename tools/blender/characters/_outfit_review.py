"""D1-02 review renders from the exported character glbs (Cycles CPU; not an asset script).

    blender -b --factory-startup --python tools/blender/characters/_outfit_review.py -- <mode> <out.png>

lineup: all outfit characters in A-pose (_review/outfits_lineup.png); officer: 3/4
close-up of the security officer (_review/security_officer.png); face: 3/4 head close-up of one
civilian (env FACE_ID, default the jeweler; _review/civilian_face.png); silhouette: flat black
figures 30 m from a 60 deg / 1080 p camera (~56 px tall) for the readability check, cropped to the
figure band (840 x 100 px of the 1080 p frame) and upscaled 2x nearest-neighbour
(_review/outfits_silhouette_30m.png). Env SAMPLES overrides the sample count; env CHAR_ROOT reads
the glbs from another output root (scratch builds) and env IDS (comma separated) picks the figures.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

REPO = os.environ.get("CHAR_ROOT") or str(
    __import__("pathlib").Path(__file__).resolve().parents[3] / "game" / "assets" / "characters")
IDS = ["char_security_officer", "char_security_officer_b", "char_patrol_officer", "char_tac_light",
       "char_civilian_customer_a", "char_civilian_customer_b", "char_civilian_sales", "char_civilian_jeweler",
       "char_civilian_manager", "char_crew_body", "char_crew_body_b"]
if os.environ.get("IDS"):
    IDS = os.environ["IDS"].split(",")
mode, out = sys.argv[sys.argv.index("--") + 1:][:2]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def imp(cid, x, rot=0.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f"{REPO}/{cid}/{cid}.glb")
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.parent is None:
            o.location.x += x
            o.rotation_euler.z += rot
    return new


FACE_ID = os.environ.get("FACE_ID", "char_civilian_jeweler")
ids = {"officer": [os.environ.get("OFFICER_ID", "char_security_officer")], "face": [FACE_ID]}.get(mode, IDS)
spacing = 1.3
for i, cid in enumerate(ids):
    imp(cid, -(i - (len(ids) - 1) / 2) * spacing)

sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = int(os.environ.get("SAMPLES", "48"))
sc.cycles.use_denoising = True
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"
world = bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]


def light(name, loc, energy, size, color=(1, 1, 1), target=(0, 0, 1.2)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size, ld.color = energy, size, color
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(lo)


cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam

if mode in ("lineup", "officer", "face"):
    bg.inputs[0].default_value = (0.30, 0.27, 0.24, 1)
    bg.inputs[1].default_value = 0.35
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    fl = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.28, 0.24, 1)
    fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.5
    fl.data.materials.append(fm)
    # warm interior key, cool dusk fill, rim
    e_key, e_fill, e_rim = (2200, 700, 1600) if mode == "lineup" else (260, 90, 200)
    light("key", (3.0, 5.0, 4.0), e_key, 4.0, (1.0, 0.90, 0.78))
    light("fill", (-5.0, 4.0, 2.0), e_fill, 5.0, (0.75, 0.82, 1.0))
    light("rim", (1.0, -5.0, 3.5), e_rim, 3.0, (1.0, 0.95, 0.9))

if mode == "lineup":
    sc.render.resolution_x, sc.render.resolution_y = 3600, 1000
    cam_d.lens = 50
    cam.location = (0.0, 21.5, 1.1)
    cam.rotation_euler = (Vector((0, 0, 0.92)) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
elif mode == "officer":
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1600
    cam_d.lens = 70
    # env CAM = "target_z,distance,angle_deg[,height_offset]" re-aims this close-up (detail checks)
    tz, dist, ang, dz = (list(map(float, os.environ["CAM"].split(","))) + [0.06])[:4] if os.environ.get("CAM") \
        else (1.45, 1.55, 32.0, 0.06)
    tgt = Vector((0.0, 0.0, tz))
    a = math.radians(ang)
    cam.location = tgt + Vector((math.sin(a) * dist, math.cos(a) * dist, dz))
    cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    cam_d.dof.use_dof = False
elif mode == "face":
    sc.render.resolution_x, sc.render.resolution_y = 1200, 1200
    cam_d.lens = 85
    top = max((o.matrix_world @ Vector(c)).z for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Body")
              for c in o.bound_box)
    tgt = Vector((0.0, 0.0, top - 0.115))
    a = math.radians(35)
    cam.location = tgt + Vector((math.sin(a) * 0.95, math.cos(a) * 0.95, 0.02))
    cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
elif mode == "silhouette":
    # flat silhouettes against a light background, camera 30 m away, 1080p-equivalent pixel size
    bg.inputs[0].default_value = (0.8, 0.8, 0.8, 1)
    bg.inputs[1].default_value = 1.0
    black = bpy.data.materials.new("sil")
    black.use_nodes = True
    nt = black.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.02, 0.02, 0.02, 1)
    outn = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], outn.inputs[0])
    for o in bpy.data.objects:
        if o.type == "MESH":
            for i in range(len(o.material_slots)):
                o.material_slots[i].material = black
    sc.view_settings.view_transform = "Standard"
    # 60 deg vertical FOV at 1080 rows => figure ~ 56 px tall at 30 m
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    cam_d.sensor_fit = "VERTICAL"
    cam_d.angle_y = math.radians(60.0)
    cam.location = (0.0, 30.0, 1.0)
    cam.rotation_euler = (Vector((0, 0, 1.0)) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    sc.cycles.samples = 8
    sc.render.filter_size = 1.5
    # crop to the figure band (840 x 100 px around the frame centre line), upscaled 2x below
    sc.render.use_border = True
    sc.render.use_crop_to_border = True
    sc.render.border_min_x, sc.render.border_max_x = (1920 - 840) / 2 / 1920, (1920 + 840) / 2 / 1920
    sc.render.border_min_y, sc.render.border_max_y = (540 - 41) / 1080, (540 + 59) / 1080

sc.render.filepath = out
bpy.ops.render.render(write_still=True)
if mode == "silhouette":
    img = bpy.data.images.load(out)
    w, h = img.size
    px = list(img.pixels)
    big = [0.0] * (w * 2 * h * 2 * 4)
    for y in range(h * 2):
        for x in range(w * 2):
            s_i = ((y // 2) * w + x // 2) * 4
            d_i = (y * w * 2 + x) * 4
            big[d_i:d_i + 4] = px[s_i:s_i + 4]
    img2 = bpy.data.images.new("sil2x", w * 2, h * 2, alpha=True)
    img2.pixels.foreach_set(big)
    img2.filepath_raw = out
    img2.file_format = "PNG"
    img2.save()
print("WROTE", out)
