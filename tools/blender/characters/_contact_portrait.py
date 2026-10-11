"""Contact portrait busts for the briefing screen (QB-50a). Not an asset script.

One table (``CONTACTS``) describes each bust: the character glb, a pose (model-space rotations
about bone heads, applied in order), the camera and the art-directed light rig. It drives both

* the **stills** (Blender Cycles CPU, AgX):

      blender -b --factory-startup --python tools/blender/characters/_contact_portrait.py -- \
          render <name> <out.png>            # one portrait, 1024 x 1024
      python3 tools/blender/characters/_contact_portrait.py sheet <out.png> <png>...   # review sheet

  written to ``game/assets/characters/portraits/<name>.png`` (``ContactDef.portrait_texture``),
* the **live bust scenes** (``python3 tools/blender/characters/_contact_portrait.py scenes``):
  ``game/world/characters/portraits/<name>/<name>_portrait.tscn`` (``ContactDef.portrait_scene``,
  a Node3D root that ``ContactPortrait`` renders in a SubViewport): the assembled character, the
  same pose (``portrait_pose.gd``), a Camera3D, the light rig, a backdrop and a WorldEnvironment.

Axes in the table are Blender's (+Z up, the character faces +Y); the scene writer converts them to
Godot (x, z, -y). Env SAMPLES overrides the Cycles sample count, env CHAR_ROOT reads the glbs from
another output root (scratch builds).
"""

from __future__ import annotations

import math
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
PORTRAIT_SIZE = 1024
SCENE_DIR = REPO / "game" / "world" / "characters" / "portraits"
PNG_DIR = REPO / "game" / "assets" / "characters" / "portraits"

# Pose: (bone, axis (Blender model space), degrees), applied in order about each bone's head.
# Arms come down from the A-pose (45 deg) to hang at the sides; head/neck carry the attitude.
_ARMS_DOWN = [
    ("upper_arm.L", (0, 1, 0), -36.0), ("upper_arm.R", (0, 1, 0), 36.0),
    ("upper_arm.L", (1, 0, 0), 6.0), ("upper_arm.R", (1, 0, 0), 6.0),
]

# Lights: (name, kind, location, target, colour, blender_watts, size_m, godot_energy)
CONTACTS: dict[str, dict] = {
    "odile": {
        "asset": "char_contact_odile",
        "pose": _ARMS_DOWN + [
            ("chest", (0, 0, 1), -6.0),
            ("neck", (1, 0, 0), 3.0),             # a slight chin lift: poised, a touch impatient
            ("head", (1, 0, 0), 4.0),
            ("head", (0, 0, 1), 20.0),            # turned toward the camera (the chignon still shows)
            ("head", (0, 1, 0), -5.0),            # slight tilt
        ],
        # camera: target (z rel. to the eyes), distance, yaw (deg, + = character's left), dz, lens
        "camera": {"target_dz": -0.09, "dist": 1.22, "yaw": -36.0, "cam_dz": 0.13, "lens": 85.0},
        "bg": {"top": (0.018, 0.022, 0.030), "glow": (0.085, 0.040, 0.070), "glow_xy": (0.62, 0.58), "glow_r": 0.55},
        "lights": [
            # soft loop lighting: a large warm-neutral key high and just camera-side of the nose, a
            # broad fill from the camera side (no hollow under the cheekbone), warm rims behind
            ("key", "AREA", (-0.10, 1.50, 1.90), (0.0, 0.0, 1.58), (1.00, 0.93, 0.86), 65.0, 1.4, 0.9),
            ("fill", "AREA", (-1.25, 1.05, 1.50), (0.0, 0.0, 1.52), (0.88, 0.86, 0.95), 14.0, 1.6, 0.3),
            ("rim", "AREA", (-0.95, -1.05, 1.62), (0.0, 0.0, 1.52), (1.00, 0.70, 0.45), 90.0, 0.5, 1.8),
            ("rim_far", "AREA", (0.55, -1.25, 1.66), (0.0, 0.0, 1.52), (1.00, 0.74, 0.50), 70.0, 0.5, 1.8),
            ("hair", "AREA", (-0.3, -0.9, 2.3), (0.0, 0.0, 1.62), (0.90, 0.92, 1.00), 12.0, 0.4, 0.5),
        ],
        "ambient": (0.020, 0.022, 0.028),
    },
    "hollis": {
        "asset": "char_contact_hollis",
        "pose": _ARMS_DOWN + [
            ("chest", (0, 0, 1), 8.0),
            ("neck", (1, 0, 0), -4.0),            # head forward and down: sizing you up
            ("head", (1, 0, 0), -3.0),
            ("head", (0, 0, 1), -12.0),
            ("head", (0, 1, 0), 3.0),
        ],
        "camera": {"target_dz": -0.13, "dist": 1.40, "yaw": 26.0, "cam_dz": -0.02, "lens": 85.0},
        "bg": {"top": (0.022, 0.016, 0.012), "glow": (0.15, 0.08, 0.03), "glow_xy": (0.30, 0.45), "glow_r": 0.6},
        "lights": [
            ("bulb", "POINT", (0.55, 0.75, 2.25), (0.0, 0.0, 1.6), (1.00, 0.68, 0.38), 70.0, 0.05, 2.0),
            ("bounce", "AREA", (-0.2, 1.6, 0.9), (0.0, 0.0, 1.45), (0.95, 0.62, 0.36), 10.0, 1.2, 0.35),
            ("window", "AREA", (-1.3, 0.6, 1.8), (0.0, 0.0, 1.55), (0.60, 0.72, 0.95), 22.0, 0.8, 0.6),
            ("rim", "AREA", (-0.6, -1.0, 2.0), (0.0, 0.0, 1.55), (1.00, 0.75, 0.45), 55.0, 0.4, 1.6),
        ],
        "ambient": (0.022, 0.016, 0.012),
    },
    "accountant": {
        "asset": "char_contact_accountant",
        "pose": _ARMS_DOWN + [
            ("neck", (1, 0, 0), -2.0),
            ("head", (0, 0, 1), 6.0),
        ],
        "camera": {"target_dz": -0.10, "dist": 1.50, "yaw": -12.0, "cam_dz": -0.04, "lens": 85.0},
        # a bright frosted window behind (blind slats), the figure dark against it
        "bg": {"top": (0.10, 0.16, 0.15), "glow": (1.6, 2.2, 2.0), "glow_xy": (0.5, 0.58), "glow_r": 0.48,
               "blinds": True},
        "lights": [
            ("rim_l", "AREA", (-0.6, -1.3, 1.95), (0.0, 0.0, 1.6), (0.80, 1.00, 0.92), 260.0, 0.5, 6.0),
            ("rim_r", "AREA", (0.6, -1.3, 1.85), (0.0, 0.0, 1.6), (0.80, 1.00, 0.92), 260.0, 0.5, 6.0),
            ("top", "AREA", (0.0, -0.9, 2.5), (0.0, 0.0, 1.7), (0.80, 1.00, 0.92), 25.0, 0.4, 0.6),
            # glint: tiny, bright source that the lenses mirror; too weak to light the face
            ("glint", "AREA", (0.40, 1.55, 1.74), (0.0, 0.0, 1.62), (1.00, 1.00, 1.00), 2.0, 0.03, 0.05),
        ],
        "ambient": (0.0004, 0.0005, 0.0005),
        "glint": True,
    },
}


def godot_vec(v) -> tuple[float, float, float]:
    return (float(v[0]), float(v[2]), -float(v[1]))


# =============================================================================================
# Blender still
# =============================================================================================
def _render(name: str, out: str) -> None:
    import bpy
    from mathutils import Matrix, Vector

    spec = CONTACTS[name]
    root = os.environ.get("CHAR_ROOT") or str(REPO / "game" / "assets" / "characters")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    cid = spec["asset"]
    bpy.ops.import_scene.gltf(filepath=f"{root}/{cid}/{cid}.glb")
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    mw = arm.matrix_world.copy()
    mwi = mw.inverted()
    for bone, axis, deg in spec["pose"]:
        bpy.context.view_layer.update()
        pb = arm.pose.bones[bone]
        head_w = mw @ pb.head
        rot = (Matrix.Translation(head_w) @ Matrix.Rotation(math.radians(deg), 4, Vector(axis))
               @ Matrix.Translation(-head_w))
        pb.matrix = mwi @ rot @ mw @ pb.matrix
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    # the eye line (posed): from the Body mesh's evaluated bounds
    dg = bpy.context.evaluated_depsgraph_get()
    body = next(o for o in meshes if o.name.startswith("Body"))
    ev = body.evaluated_get(dg)
    top = max((ev.matrix_world @ v.co).z for v in ev.data.vertices)
    eye_z = top - 0.115
    # the game's library textures (skin tint included), light SSS on skin/lips, no terminator
    # strokes; then the art-directed tweaks: matte hair, glossy lenses, silk sheen
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import _review_mats  # noqa: PLC0415
    from _outfit_palette import SKIN_SPECULAR  # noqa: PLC0415

    _review_mats.prepare(skip_orm=("char_hair", "char_lens", "char_silk"))
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        if "char_skin" in m.name:              # the game material's metallic_specular (skin F0 ~2.8 %)
            bsdf.inputs["Specular IOR Level"].default_value = SKIN_SPECULAR
        if "char_hair" in m.name:              # low spec, so dark hair stays dark under rims
            bsdf.inputs["Specular IOR Level"].default_value = 0.3
            bsdf.inputs["Roughness"].default_value = 0.5
        if "char_lens" in m.name:
            bsdf.inputs["Roughness"].default_value = 0.03
            bsdf.inputs["Coat Weight"].default_value = 1.0
        if "char_silk" in m.name:
            bsdf.inputs["Sheen Weight"].default_value = 0.15
            bsdf.inputs["Specular IOR Level"].default_value = 0.6

    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = int(os.environ.get("SAMPLES", "160"))
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.render.resolution_x = sc.render.resolution_y = PORTRAIT_SIZE
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bgn = world.node_tree.nodes["Background"]
    bgn.inputs[0].default_value = (*spec["ambient"], 1.0)
    bgn.inputs[1].default_value = 1.0

    # camera
    cam_s = spec["camera"]
    tgt = Vector((0.0, 0.0, eye_z + cam_s["target_dz"]))
    a = math.radians(cam_s["yaw"])
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam_d.lens = cam_s["lens"]
    cam.location = tgt + Vector((math.sin(a) * cam_s["dist"], math.cos(a) * cam_s["dist"], cam_s["cam_dz"]))
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_d.dof.use_dof = True
    cam_d.dof.focus_distance = (Vector((0.0, 0.08, eye_z)) - cam.location).length
    cam_d.dof.aperture_fstop = 2.8

    # backdrop: a large plane behind the figure, facing the camera, with an emissive gradient
    back_dir = (tgt - cam.location).normalized()
    plane_c = tgt + back_dir * 1.6
    bpy.ops.mesh.primitive_plane_add(size=3.2, location=plane_c)
    bd = bpy.context.active_object
    bd.rotation_euler = (-back_dir).to_track_quat("Z", "Y").to_euler()
    bm = bpy.data.materials.new("backdrop")
    bm.use_nodes = True
    nt = bm.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    # radial glow around glow_xy (generated coords 0..1 over the plane)
    gx, gy = spec["bg"]["glow_xy"]
    mx = nt.nodes.new("ShaderNodeMath")
    mx.operation = "SUBTRACT"
    mx.inputs[1].default_value = gx
    nt.links.new(sep.outputs[0], mx.inputs[0])
    my = nt.nodes.new("ShaderNodeMath")
    my.operation = "SUBTRACT"
    my.inputs[1].default_value = gy
    nt.links.new(sep.outputs[1], my.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(mx.outputs[0], comb.inputs[0])
    nt.links.new(my.outputs[0], comb.inputs[1])
    ln = nt.nodes.new("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    nt.links.new(comb.outputs[0], ln.inputs[0])
    dv = nt.nodes.new("ShaderNodeMath")
    dv.operation = "DIVIDE"
    dv.inputs[1].default_value = spec["bg"]["glow_r"]
    nt.links.new(ln.outputs["Value"], dv.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "EASE"
    ramp.color_ramp.elements[0].color = (*spec["bg"]["glow"], 1.0)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (*spec["bg"]["top"], 1.0)
    nt.links.new(dv.outputs[0], ramp.inputs[0])
    col = ramp.outputs[0]
    if spec["bg"].get("blinds"):
        # venetian blind slats: dark bars across the glow
        wv = nt.nodes.new("ShaderNodeTexWave")
        wv.wave_type = "BANDS"
        wv.bands_direction = "Y"
        wv.inputs["Scale"].default_value = 9.0
        wv.inputs["Distortion"].default_value = 0.0
        wv.inputs["Detail"].default_value = 0.0
        nt.links.new(tc.outputs["Generated"], wv.inputs["Vector"])
        st = nt.nodes.new("ShaderNodeMath")
        st.operation = "GREATER_THAN"
        st.inputs[1].default_value = 0.78
        nt.links.new(wv.outputs["Fac"], st.inputs[0])
        mixs = nt.nodes.new("ShaderNodeMix")
        mixs.data_type = "RGBA"
        nt.links.new(st.outputs[0], mixs.inputs["Factor"])
        nt.links.new(col, mixs.inputs["A"])
        mixs.inputs["B"].default_value = (0.03, 0.045, 0.045, 1.0)
        col = mixs.outputs["Result"]
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(col, em.inputs["Color"])
    outn = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], outn.inputs[0])
    bd.data.materials.append(bm)
    bd.visible_shadow = False
    bd.visible_glossy = name == "accountant"
    bd.visible_diffuse = False

    glint_at = None
    if spec.get("glint"):
        # mirror the camera in the (posed) lenses: the glint light sits where the lenses reflect to
        acc, nrm, cnt = Vector(), Vector(), 0
        for o in meshes:
            if not o.name.startswith("Headwear"):
                continue
            eo = o.evaluated_get(dg)
            me = eo.data
            for poly in me.polygons:
                mt = eo.material_slots[poly.material_index].material
                if mt is None or "char_lens" not in mt.name:
                    continue
                acc += eo.matrix_world @ poly.center
                nrm += (eo.matrix_world.to_3x3() @ poly.normal)
                cnt += 1
        if cnt:
            lc = acc / cnt
            nrm.normalize()
            d = (cam.location - lc).normalized()
            r = 2.0 * d.dot(nrm) * nrm - d
            glint_at = (lc + r * 1.5, lc)
    skip = set(filter(None, os.environ.get("NO_LIGHTS", "").split(",")))   # debugging: drop lights by name
    for lname, kind, loc, target, colr, watts, size, _ge in spec["lights"]:
        if lname in skip:
            continue
        ld = bpy.data.lights.new(lname, kind)
        ld.energy = watts
        ld.color = colr
        if kind == "AREA":
            ld.size = size
        else:
            ld.shadow_soft_size = size
        lo = bpy.data.objects.new(lname, ld)
        lo.location = Vector(loc) + Vector((0, 0, eye_z - 1.60))
        lo.rotation_euler = (Vector(target) + Vector((0, 0, eye_z - 1.60)) - lo.location).to_track_quat("-Z", "Y").to_euler()
        if lname == "glint" and glint_at is not None:
            lo.location = glint_at[0]
            lo.rotation_euler = (glint_at[1] - glint_at[0]).to_track_quat("-Z", "Y").to_euler()
        if lname == "glint":
            lo.visible_diffuse = False          # seen only in glossy reflections (the lenses)
            lo.visible_transmission = False
            lo.visible_volume_scatter = False
        sc.collection.objects.link(lo)

    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("WROTE", out)


# =============================================================================================
# review sheet (system python + Pillow)
# =============================================================================================
def _sheet(out: str, pngs: list[str]) -> None:
    from PIL import Image, ImageDraw

    tiles = [Image.open(p).convert("RGB") for p in pngs]
    t = 640
    pad = 24
    label_h = 40
    w = len(tiles) * t + (len(tiles) + 1) * pad
    h = t + 2 * pad + label_h + 128 + pad
    sheet = Image.new("RGB", (w, h), (22, 24, 28))
    dr = ImageDraw.Draw(sheet)
    for i, (img, p) in enumerate(zip(tiles, pngs)):
        x = pad + i * (t + pad)
        sheet.paste(img.resize((t, t), Image.LANCZOS), (x, pad))
        dr.text((x, pad + t + 8), f"{Path(p).stem}  ({img.size[0]}x{img.size[1]}; slot 360x360, board 128x128)",
                fill=(200, 200, 200))
        # in-game sizes: the briefing slot and the board thumbnail
        sheet.paste(img.resize((128, 128), Image.LANCZOS), (x, pad + t + label_h))
        sheet.paste(img.resize((64, 64), Image.LANCZOS), (x + 140, pad + t + label_h))
    sheet.save(out)
    print("WROTE", out)


# =============================================================================================
# Godot bust scenes (system python)
# =============================================================================================
def _scene_text(name: str) -> str:
    spec = CONTACTS[name]
    cid = spec["asset"]
    char_id = cid.removeprefix("char_")
    pose_items = []
    for bone, axis, deg in spec["pose"]:
        gx, gy, gz = godot_vec(axis)
        pose_items.append(f'["{bone}", Vector3({gx + 0.0:g}, {gy + 0.0:g}, {gz + 0.0:g}), {deg:g}]')
    cam = spec["camera"]
    lines = [
        '[gd_scene load_steps=8 format=3]',
        '',
        f'[ext_resource type="PackedScene" path="res://world/characters/{char_id}/{char_id}.tscn" id="1_char"]',
        '[ext_resource type="Script" path="res://world/characters/portraits/portrait_bust.gd" id="2_bust"]',
        '',
        '[sub_resource type="Environment" id="Environment_bust"]',
        'background_mode = 1',
        f'background_color = Color({spec["bg"]["top"][0]:.3f}, {spec["bg"]["top"][1]:.3f}, {spec["bg"]["top"][2]:.3f}, 1)',
        'ambient_light_source = 2',
        f'ambient_light_color = Color({spec["ambient"][0]:.3f}, {spec["ambient"][1]:.3f}, {spec["ambient"][2]:.3f}, 1)',
        'ambient_light_energy = 4.0',
        'tonemap_mode = 4',
        'glow_enabled = true',
        'glow_intensity = 0.25',
        'ssao_enabled = true',
        '',
        '[sub_resource type="Gradient" id="Gradient_bg"]',
        'interpolation_mode = 2',
        'offsets = PackedFloat32Array(0, 1)',
        'colors = PackedColorArray({}, 1, {}, 1)'.format(
            ", ".join(f"{min(c, 1.0):.3f}" for c in spec["bg"]["glow"]),
            ", ".join(f"{c:.3f}" for c in spec["bg"]["top"])),
        '',
        '[sub_resource type="GradientTexture2D" id="GradientTexture2D_bg"]',
        'gradient = SubResource("Gradient_bg")',
        'width = 256',
        'height = 256',
        'fill = 1',
        'fill_from = Vector2({:.2f}, {:.2f})'.format(spec["bg"]["glow_xy"][0], 1.0 - spec["bg"]["glow_xy"][1]),
        'fill_to = Vector2({:.2f}, {:.2f})'.format(spec["bg"]["glow_xy"][0] + spec["bg"]["glow_r"],
                                                     1.0 - spec["bg"]["glow_xy"][1]),
        '',
        '[sub_resource type="StandardMaterial3D" id="Material_bg"]',
        'shading_mode = 0',
        'albedo_texture = SubResource("GradientTexture2D_bg")',
        '',
        '[sub_resource type="QuadMesh" id="QuadMesh_bg"]',
        'material = SubResource("Material_bg")',
        'size = Vector2(3.2, 3.2)',
        '',
        f'[node name="{name.capitalize()}Portrait" type="Node3D"]',
        'script = ExtResource("2_bust")',
        f'pose = [{", ".join(pose_items)}]',
        f'camera_target_dz = {cam["target_dz"]:g}',
        f'camera_distance = {cam["dist"]:g}',
        f'camera_yaw_deg = {cam["yaw"]:g}',
        f'camera_dz = {cam["cam_dz"]:g}',
        f'camera_lens_mm = {cam["lens"]:g}',
        f'blinds = {"true" if spec["bg"].get("blinds") else "false"}',
        '',
        '[node name="Character" parent="." instance=ExtResource("1_char")]',
        '',
        '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]',
        'environment = SubResource("Environment_bust")',
        '',
        '[node name="Camera3D" type="Camera3D" parent="."]',
        'current = true',
        '',
        '[node name="Backdrop" type="MeshInstance3D" parent="."]',
        'cast_shadow = 0',
        'mesh = SubResource("QuadMesh_bg")',
        '',
        '[node name="Lights" type="Node3D" parent="."]',
    ]
    for lname, kind, loc, target, colr, _w, size, genergy in spec["lights"]:
        if lname == "glint":        # Cycles-only (glossy-only light); Godot lights cannot skip diffuse
            continue
        gl = godot_vec(loc)
        gt = godot_vec(target)
        node = "OmniLight3D" if kind == "POINT" else "SpotLight3D"
        lines += [
            '',
            f'[node name="{lname.capitalize()}" type="{node}" parent="Lights"]',
            f'position = Vector3({gl[0] + 0.0:g}, {gl[1] + 0.0:g}, {gl[2] + 0.0:g})',
            f'metadata/target = Vector3({gt[0] + 0.0:g}, {gt[1] + 0.0:g}, {gt[2] + 0.0:g})',
            f'light_color = Color({colr[0]:g}, {colr[1]:g}, {colr[2]:g}, 1)',
            f'light_energy = {genergy:g}',
            f'light_size = {min(size, 0.5):g}',
            'light_specular = 0.35',        # Godot's spec on cloth reads hotter than Cycles
            'shadow_enabled = true',
        ]
        if node == "SpotLight3D":
            lines += ['spot_range = 6.0', 'spot_angle = 40.0', 'spot_attenuation = 0.5']
        else:
            lines += ['omni_range = 6.0']
    return "\n".join(lines) + "\n"


def _scenes() -> None:
    for name in CONTACTS:
        d = SCENE_DIR / name
        d.mkdir(parents=True, exist_ok=True)
        p = d / f"{name}_portrait.tscn"
        p.write_text(_scene_text(name))
        print("WROTE", p)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    cmd = argv[0]
    if cmd == "render":
        _render(argv[1], argv[2])
    elif cmd == "sheet":
        _sheet(argv[1], argv[2:])
    elif cmd == "scenes":
        _scenes()
    else:
        raise SystemExit(f"unknown command {cmd}")
