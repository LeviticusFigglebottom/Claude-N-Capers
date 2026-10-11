"""D2-02 heist NPC review renders from the exported glbs (Cycles CPU; not an asset script).

    blender -b --factory-startup --python tools/blender/characters/_npc_review.py -- <mode> <out.png>

lineup: every heist NPC in A-pose, the two heists side by side (_review/npcs_lineup.png; Shadow Ledger
with the D-063 cast: Kessler robe + coat, Helena Moor, Northgate guards, IT contractor, cleaner), lit by
a sodium-warm key for night_deposit and a cold-white key for shadow_ledger; faces: 3/4 head
close-ups in a grid (_review/npcs_faces.png); silhouette: the shadow_ledger party (guests, staff,
Kessler) and the bank staff seen from 30 m with a 60 deg / 1080 p camera (~56 px tall): the top band
flat black, the bottom band in colour under dim night light, cropped and upscaled 2x
nearest-neighbour (_review/npcs_silhouette_30m.png). Env CHAR_ROOT reads the glbs from another
output root (scratch builds), IDS (comma separated) picks the figures, SAMPLES the sample count.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.environ.get("CHAR_ROOT") or os.path.join(HERE, "..", "..", "..", "game", "assets", "characters")
BANK = ["char_npc_bank_teller", "char_npc_bank_teller_b", "char_npc_bank_night_manager", "char_npc_bank_cleaner",
        "char_npc_bank_guard"]
PENT = ["char_npc_penthouse_guest_a", "char_npc_penthouse_guest_b", "char_npc_penthouse_staff", "char_npc_kessler",
        "char_npc_kessler_coat", "char_npc_helena_moor", "char_npc_northgate_guard", "char_npc_northgate_guard_b",
        "char_npc_it_contractor", "char_npc_cleaner_sl"]
IDS = os.environ["IDS"].split(",") if os.environ.get("IDS") else BANK + PENT
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
cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam


def floor(rgb):
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
    fl = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1)
    fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.5
    fl.data.materials.append(fm)


def lib_mats():
    import _review_mats

    _review_mats.prepare()


if mode == "lineup":
    bank = [i for i in IDS if i in BANK]
    pent = [i for i in IDS if i not in BANK]
    spacing, gap = 1.7, 2.2
    xs = [i * spacing for i in range(len(bank))] + [(len(bank) - 1) * spacing + gap + i * spacing for i in range(len(pent))]
    mid = (xs[0] + xs[-1]) / 2
    for cid, x in zip(bank + pent, xs):
        imp(cid, (-(x - mid), 0, 0))
    lib_mats()
    bg.inputs[0].default_value = (0.20, 0.20, 0.22, 1)
    bg.inputs[1].default_value = 0.25
    floor((0.12, 0.12, 0.13))
    # left half (bank, seen from +y so +x is screen-left): warm sodium key; right: cold white key
    light("key_bank", (6.0, 6.0, 4.5), 900, 5.0, (1.0, 0.86, 0.70), target=(4.5, 0, 1.0))
    light("key_pent", (-6.0, 6.0, 4.5), 900, 5.0, (0.86, 0.93, 1.0), target=(-4.5, 0, 1.0))
    light("fill", (0.0, 8.0, 1.6), 300, 10.0, (0.92, 0.94, 1.0))
    light("rim", (0.0, -6.0, 3.5), 900, 8.0, (1.0, 1.0, 1.0))
    # frame the whole row: 50 mm on a 36 mm sensor sees 0.72 x the distance horizontally
    span = xs[-1] - xs[0] + 1.6
    sc.render.resolution_x, sc.render.resolution_y = max(3600, int(span * 200)), 900
    cam_d.lens = 50
    aim(cam, (0.0, max(23.0, span / 0.72 * 1.04), 1.0), (0, 0, 1.0))
elif mode == "faces":
    cols = 5
    rows = math.ceil(len(IDS) / cols)
    # each head in its own cell: figures 3 m apart; one orthographic camera per tile is overkill, so
    # the grid is built in Blender by placing the figures and rendering tiles, then stitched
    lib_mats()
    import _review_mats

    if hasattr(_review_mats, "terminator"):
        _review_mats.terminator()
    bg.inputs[0].default_value = (0.30, 0.30, 0.31, 1)
    bg.inputs[1].default_value = 0.4
    tile = 640
    sc.render.resolution_x, sc.render.resolution_y = tile, tile
    cam_d.lens = 85
    tops = {}
    for i, cid in enumerate(IDS):
        objs = imp(cid, (i * 4.0, 0, 0))
        top = max((ob.matrix_world @ Vector(c)).z for ob in objs if ob.type == "MESH" and ob.name.startswith("Body")
                  for c in ob.bound_box)
        tops[cid] = (i * 4.0, top)
    light("key", (2.0, 3.0, 3.0), 300, 2.0, (1.0, 0.95, 0.88))
    light("fill", (-3.0, 2.0, 1.8), 90, 3.0, (0.82, 0.88, 1.0))
    light("rim", (0.5, -3.0, 2.5), 160, 2.0)
    for lo in [ob for ob in bpy.data.objects if ob.type == "LIGHT"]:
        lo["base"] = tuple(lo.location)
    tiles = []
    for cid in IDS:
        x0, top = tops[cid]
        for lo in [ob for ob in bpy.data.objects if ob.type == "LIGHT"]:
            b = lo["base"]
            lo.location = (b[0] + x0, b[1], b[2] + top - 1.75)
            lo.rotation_euler = (Vector((x0, 0, top - 0.1)) - lo.location).to_track_quat("-Z", "Y").to_euler()
        tgt = Vector((x0, 0.0, top - 0.115))
        a = math.radians(35)
        aim(cam, tgt + Vector((-math.sin(a) * 0.95, math.cos(a) * 0.95, 0.03)), tgt)
        path = out + f".{cid}.png"
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        tiles.append(path)
    # stitch
    W, H = cols * tile, rows * tile
    big = [0.3, 0.3, 0.31, 1.0] * (W * H)
    for i, path in enumerate(tiles):
        img = bpy.data.images.load(path)
        px = list(img.pixels)
        cx, cy = i % cols, rows - 1 - i // cols
        for y in range(tile):
            d0 = ((cy * tile + y) * W + cx * tile) * 4
            big[d0:d0 + tile * 4] = px[y * tile * 4:(y + 1) * tile * 4]
        bpy.data.images.remove(img)
        os.remove(path)
    im = bpy.data.images.new("faces", W, H, alpha=True)
    im.pixels.foreach_set(big)
    im.filepath_raw = out
    im.file_format = "PNG"
    im.save()
    print("WROTE", out)
    sys.exit(0)
elif mode == "silhouette":
    # two bands 2.2 m apart in z: silhouettes on top (flat black), colour below (night light).
    spacing = 1.45
    n_ids = len(IDS)
    sil = bpy.data.materials.new("sil")
    sil.use_nodes = True
    nt = sil.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.02, 0.02, 0.02, 1)
    on = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], on.inputs[0])
    for i, cid in enumerate(IDS):
        x = -(i - (n_ids - 1) / 2) * spacing
        for ob in imp(cid, (x, 0, 2.3)):
            if ob.type == "MESH":
                for s in range(len(ob.material_slots)):
                    ob.material_slots[s].material = sil
        imp(cid, (x, 0, 0))
    lib_mats()
    # backdrop: light grey card behind the silhouettes, dark night floor/wall behind the colour row
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -1.5, 3.4))
    card = bpy.context.active_object
    card.scale = (40, 2.4, 1)
    card.rotation_euler = (math.radians(90), 0, 0)
    cm = bpy.data.materials.new("card")
    cm.use_nodes = True
    cnt = cm.node_tree
    for nd in list(cnt.nodes):
        cnt.nodes.remove(nd)
    e2 = cnt.nodes.new("ShaderNodeEmission")
    e2.inputs["Color"].default_value = (0.8, 0.8, 0.8, 1)
    o2 = cnt.nodes.new("ShaderNodeOutputMaterial")
    cnt.links.new(e2.outputs[0], o2.inputs[0])
    card.data.materials.append(cm)
    floor((0.10, 0.10, 0.11))
    bg.inputs[0].default_value = (0.05, 0.055, 0.065, 1)
    bg.inputs[1].default_value = 1.0
    light("key", (3.0, 8.0, 5.0), 900, 6.0, (0.95, 0.97, 1.0), target=(0, 0, 0.9))
    light("fill", (-6.0, 6.0, 2.0), 300, 6.0, (1.0, 0.85, 0.7), target=(0, 0, 0.9))
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
    # frame rows: z 0..1.9 and 2.3..4.2 at 30 m: 1080 rows span 2*30*tan(30) = 34.6 m (31.2 px/m)
    ppm = 1080 / (2 * 30 * math.tan(math.radians(30)))
    half_w = (n_ids * spacing / 2 + 0.6) * ppm
    lo_px, hi_px = 540 + (-0.15 - 2.15) * ppm, 540 + (4.3 - 2.15) * ppm
    sc.render.border_min_x, sc.render.border_max_x = (960 - half_w) / 1920, (960 + half_w) / 1920
    sc.render.border_min_y, sc.render.border_max_y = lo_px / 1080, hi_px / 1080

if mode != "faces":
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
if mode == "silhouette":
    img = bpy.data.images.load(out)
    w, h = img.size
    px = list(img.pixels)
    f = 3
    big = [0.0] * (w * f * h * f * 4)
    for y in range(h * f):
        for x in range(w * f):
            s_i = ((y // f) * w + x // f) * 4
            d_i = (y * w * f + x) * 4
            big[d_i:d_i + 4] = px[s_i:s_i + 4]
    img2 = bpy.data.images.new("sil3x", w * f, h * f, alpha=True)
    img2.pixels.foreach_set(big)
    img2.filepath_raw = out
    img2.file_format = "PNG"
    img2.save()
print("WROTE", out)
