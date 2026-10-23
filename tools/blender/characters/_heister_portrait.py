"""Crew heister portraits for the heister picker (D-073). Not an asset script.

The playable heisters (``char_crew_<id>``, see ``_crew_heisters.py``) get the same 3/4 bust stills
as the contact portraits: this module adds a ``HEISTERS`` table in the ``_contact_portrait`` format
(pose, camera, backdrop, light rig) and renders it with that module's Cycles renderer, so the crew
and the contacts read as one family. Unmasked, so the face reads (``Heisters.portrait`` loads
``<portrait_dir>/<id>.png``; the loadout picker shows it at 72 px):

    blender -b --factory-startup --python tools/blender/characters/_heister_portrait.py -- \
        render <id> <out.png>            # one portrait, 1024 x 1024 (env SIZE for quick previews)
    python3 tools/blender/characters/_heister_portrait.py sheet <out.png> <png>...   # review sheet

written to ``game/assets/characters/portraits/<id>.png``. Each heister has a dark gradient
backdrop with a glow in their signature colour (Rook oxblood, Sable aubergine, Dutch warm tan,
Wren mustard against teal, Marten burnt orange against olive, Jay cobalt with a cognac rim, Juno emerald with a
cool rim, Hale warm sand with a work-glove yellow rim), and a pose that carries the personality.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _contact_portrait as cp  # noqa: E402

_ARMS_DOWN = cp._ARMS_DOWN

# Lights: (name, kind, location, target, colour, blender_watts, size_m, godot_energy); positions are
# relative to an eye line at z = 1.60 (the renderer shifts them to the character's real eye line).
HEISTERS: dict[str, dict] = {
    # Rook: composed and level, square to the camera; cool neutral key, oxblood rim + glow
    "rook": {
        "asset": "char_crew_rook",
        "pose": _ARMS_DOWN + [
            ("chest", (0, 0, 1), -4.0),
            ("neck", (1, 0, 0), -1.0),
            ("head", (0, 0, 1), 10.0),            # a small turn back toward the camera: level, steady
        ],
        "camera": {"target_dz": -0.12, "dist": 1.52, "yaw": -24.0, "cam_dz": 0.02, "lens": 85.0},
        "bg": {"top": (0.016, 0.016, 0.020), "glow": (0.078, 0.019, 0.021), "glow_xy": (0.66, 0.60), "glow_r": 0.58},
        "lights": [
            ("key", "AREA", (-0.25, 1.45, 1.95), (0.0, 0.0, 1.58), (0.96, 0.95, 0.95), 58.0, 1.3, 0.9),
            ("fill", "AREA", (-1.25, 1.00, 1.50), (0.0, 0.0, 1.52), (0.82, 0.86, 0.96), 13.0, 1.6, 0.3),
            ("rim", "AREA", (0.85, -1.10, 1.70), (0.0, 0.0, 1.52), (1.00, 0.36, 0.30), 120.0, 0.5, 2.0),
            ("rim_far", "AREA", (-0.80, -1.15, 1.62), (0.0, 0.0, 1.52), (1.00, 0.55, 0.45), 55.0, 0.5, 1.4),
            ("hair", "AREA", (-0.2, -0.9, 2.3), (0.0, 0.0, 1.62), (0.90, 0.92, 1.00), 14.0, 0.4, 0.5),
        ],
        "ambient": (0.018, 0.018, 0.022),
    },
    # Sable: cool, a slight chin-up and a look down the nose; soft high key, aubergine glow, cool rims
    "sable": {
        "asset": "char_crew_sable",
        "pose": _ARMS_DOWN + [
            ("chest", (0, 0, 1), 8.0),
            ("neck", (1, 0, 0), 4.0),             # chin up
            ("head", (1, 0, 0), 4.0),
            ("head", (0, 0, 1), -16.0),
            ("head", (0, 1, 0), 4.0),             # a slight, unbothered tilt
        ],
        "camera": {"target_dz": -0.10, "dist": 1.30, "yaw": 30.0, "cam_dz": 0.06, "lens": 85.0},
        "bg": {"top": (0.018, 0.014, 0.024), "glow": (0.058, 0.024, 0.078), "glow_xy": (0.34, 0.60), "glow_r": 0.58},
        "lights": [
            # deep skin wants more key than the others (a near-neutral one: a warm key and bounce
            # pushed her skin orange) and a soft bounce under the chin
            ("key", "AREA", (0.20, 1.50, 1.95), (0.0, 0.0, 1.58), (1.00, 0.98, 0.96), 72.0, 1.6, 1.0),
            ("fill", "AREA", (1.25, 1.00, 1.50), (0.0, 0.0, 1.52), (0.90, 0.88, 0.98), 22.0, 1.6, 0.4),
            ("bounce", "AREA", (0.0, 1.30, 0.95), (0.0, 0.0, 1.50), (1.00, 0.93, 0.86), 8.0, 1.0, 0.2),
            ("rim", "AREA", (-0.90, -1.05, 1.66), (0.0, 0.0, 1.52), (0.86, 0.80, 1.00), 60.0, 0.5, 1.6),
            ("rim_far", "AREA", (0.70, -1.20, 1.66), (0.0, 0.0, 1.52), (0.90, 0.84, 1.00), 45.0, 0.5, 1.3),
            ("hair", "AREA", (0.3, -0.9, 2.3), (0.0, 0.0, 1.62), (0.90, 0.92, 1.00), 5.0, 0.4, 0.5),
        ],
        "ambient": (0.020, 0.018, 0.026),
    },
    # Dutch: big and leaning in, chest square, head forward; warm tungsten key, tan glow
    "dutch": {
        "asset": "char_crew_dutch",
        "pose": _ARMS_DOWN + [
            ("chest", (1, 0, 0), -5.0),           # leaning in at the camera
            ("chest", (0, 0, 1), -5.0),
            ("neck", (1, 0, 0), -3.0),
            ("head", (1, 0, 0), 2.0),
            ("head", (0, 0, 1), 8.0),
            ("head", (0, 1, 0), 3.0),
        ],
        "camera": {"target_dz": -0.14, "dist": 1.62, "yaw": -20.0, "cam_dz": -0.08, "lens": 85.0},
        "bg": {"top": (0.022, 0.017, 0.013), "glow": (0.096, 0.058, 0.030), "glow_xy": (0.64, 0.56), "glow_r": 0.62},
        "lights": [
            ("key", "AREA", (-0.45, 1.40, 2.00), (0.0, 0.0, 1.58), (1.00, 0.86, 0.70), 48.0, 1.0, 0.9),
            ("fill", "AREA", (1.20, 1.10, 1.45), (0.0, 0.0, 1.52), (0.80, 0.84, 0.95), 12.0, 1.6, 0.3),
            ("rim", "AREA", (0.85, -1.05, 1.70), (0.0, 0.0, 1.52), (1.00, 0.72, 0.42), 110.0, 0.5, 1.9),
            ("rim_far", "AREA", (-0.75, -1.20, 1.66), (0.0, 0.0, 1.52), (1.00, 0.76, 0.48), 60.0, 0.5, 1.5),
            ("hair", "AREA", (0.2, -0.9, 2.4), (0.0, 0.0, 1.66), (1.00, 0.92, 0.82), 12.0, 0.4, 0.5),
        ],
        "ambient": (0.022, 0.018, 0.014),
    },
    # Wren: turned away, eyes back to camera, alert; mustard key-side glow, a teal rim (her tie)
    "wren": {
        "asset": "char_crew_wren",
        "pose": _ARMS_DOWN + [
            ("chest", (0, 0, 1), -14.0),          # body turned off the camera
            ("neck", (1, 0, 0), 2.0),
            ("head", (0, 0, 1), 26.0),            # snapped back toward it
            ("head", (0, 1, 0), 6.0),             # an inquisitive tilt
        ],
        "camera": {"target_dz": -0.09, "dist": 1.26, "yaw": -30.0, "cam_dz": 0.04, "lens": 85.0},
        "bg": {"top": (0.008, 0.020, 0.022), "glow": (0.086, 0.062, 0.016), "glow_xy": (0.68, 0.58), "glow_r": 0.56},
        "lights": [
            ("key", "AREA", (-0.20, 1.50, 1.90), (0.0, 0.0, 1.58), (1.00, 0.95, 0.84), 52.0, 1.4, 0.9),
            ("fill", "AREA", (-1.25, 1.05, 1.50), (0.0, 0.0, 1.52), (0.82, 0.90, 0.95), 14.0, 1.6, 0.3),
            ("rim", "AREA", (0.70, -1.20, 1.66), (0.0, 0.0, 1.52), (0.40, 0.90, 0.88), 150.0, 0.5, 2.2),
            ("rim_far", "AREA", (-0.95, -1.05, 1.62), (0.0, 0.0, 1.52), (1.00, 0.80, 0.40), 75.0, 0.5, 1.8),
            ("hair", "AREA", (-0.3, -0.9, 2.3), (0.0, 0.0, 1.62), (0.90, 0.95, 1.00), 12.0, 0.4, 0.5),
        ],
        "ambient": (0.016, 0.022, 0.024),
    },
    # Marten (D-111): the planner, square-on and appraising, a small chin-down look; olive backdrop,
    # burnt-orange glow and rims
    "marten": {
        "asset": "char_crew_marten",
        "pose": _ARMS_DOWN + [
            ("chest", (0, 0, 1), 6.0),
            ("neck", (1, 0, 0), -3.0),            # chin down: weighing you up
            ("head", (0, 0, 1), -8.0),
        ],
        "camera": {"target_dz": -0.11, "dist": 1.40, "yaw": 20.0, "cam_dz": 0.02, "lens": 85.0},
        "bg": {"top": (0.014, 0.017, 0.010), "glow": (0.090, 0.040, 0.012), "glow_xy": (0.34, 0.60), "glow_r": 0.58},
        "lights": [
            ("key", "AREA", (0.25, 1.45, 1.95), (0.0, 0.0, 1.58), (0.98, 0.95, 0.88), 56.0, 1.3, 0.9),
            ("fill", "AREA", (1.25, 1.00, 1.50), (0.0, 0.0, 1.52), (0.85, 0.90, 0.82), 13.0, 1.6, 0.3),
            ("rim", "AREA", (-0.85, -1.10, 1.70), (0.0, 0.0, 1.52), (1.00, 0.52, 0.22), 130.0, 0.5, 2.0),
            ("rim_far", "AREA", (0.80, -1.15, 1.62), (0.0, 0.0, 1.52), (0.70, 0.80, 0.45), 55.0, 0.5, 1.4),
            ("hair", "AREA", (0.2, -0.9, 2.3), (0.0, 0.0, 1.62), (0.92, 0.94, 0.90), 12.0, 0.4, 0.5),
        ],
        "ambient": (0.018, 0.020, 0.014),
    },
    # Jay (D-111): the driver, loose and easy, a lean and a half-turn back to the camera; cobalt backdrop, cognac rim
    "jay": {
        "asset": "char_crew_jay",
        "pose": _ARMS_DOWN + [
            ("chest", (0, 0, 1), -18.0),          # body turned away, the driver's slouch
            ("chest", (0, 1, 0), -3.0),
            ("neck", (1, 0, 0), 1.0),
            ("head", (0, 0, 1), 22.0),            # looking back over the shoulder
            ("head", (0, 1, 0), -4.0),
        ],
        "camera": {"target_dz": -0.12, "dist": 1.50, "yaw": -26.0, "cam_dz": 0.03, "lens": 85.0},
        "bg": {"top": (0.008, 0.012, 0.026), "glow": (0.024, 0.050, 0.110), "glow_xy": (0.66, 0.58), "glow_r": 0.58},
        "lights": [
            ("key", "AREA", (-0.25, 1.45, 1.95), (0.0, 0.0, 1.58), (0.94, 0.95, 1.00), 56.0, 1.3, 0.9),
            ("fill", "AREA", (-1.25, 1.00, 1.50), (0.0, 0.0, 1.52), (0.80, 0.86, 0.98), 13.0, 1.6, 0.3),
            ("rim", "AREA", (0.85, -1.10, 1.70), (0.0, 0.0, 1.52), (1.00, 0.66, 0.40), 125.0, 0.5, 2.0),
            ("rim_far", "AREA", (-0.80, -1.15, 1.62), (0.0, 0.0, 1.52), (0.45, 0.62, 1.00), 60.0, 0.5, 1.4),
            ("hair", "AREA", (-0.2, -0.9, 2.3), (0.0, 0.0, 1.62), (0.90, 0.92, 1.00), 12.0, 0.4, 0.5),
        ],
        "ambient": (0.014, 0.016, 0.026),
    },
    # Juno (D4-03): the point woman, chin up and sure of it, a half-turn to camera; emerald backdrop, a cool
    # chrome-white rim off the zip side
    "juno": {
        "asset": "char_crew_juno",
        "pose": _ARMS_DOWN + [
            ("chest", (0, 0, 1), 16.0),           # shoulder toward the camera
            ("neck", (1, 0, 0), 4.0),             # chin up
            ("head", (0, 0, 1), -20.0),           # back to the lens
            ("head", (0, 1, 0), 3.0),
        ],
        "camera": {"target_dz": -0.10, "dist": 1.34, "yaw": 24.0, "cam_dz": 0.02, "lens": 85.0},
        "bg": {"top": (0.006, 0.016, 0.012), "glow": (0.020, 0.075, 0.050), "glow_xy": (0.34, 0.58), "glow_r": 0.58},
        "lights": [
            ("key", "AREA", (0.25, 1.45, 1.95), (0.0, 0.0, 1.58), (1.00, 0.96, 0.90), 52.0, 1.3, 0.9),
            ("fill", "AREA", (1.25, 1.00, 1.50), (0.0, 0.0, 1.52), (0.84, 0.92, 0.90), 12.0, 1.6, 0.3),
            ("rim", "AREA", (-0.85, -1.10, 1.70), (0.0, 0.0, 1.52), (0.85, 0.95, 1.00), 120.0, 0.5, 2.0),
            ("rim_far", "AREA", (0.80, -1.15, 1.62), (0.0, 0.0, 1.52), (0.35, 0.85, 0.60), 60.0, 0.5, 1.4),
            ("hair", "AREA", (0.2, -0.9, 2.3), (0.0, 0.0, 1.62), (0.95, 0.94, 0.90), 12.0, 0.4, 0.5),
        ],
        "ambient": (0.012, 0.020, 0.016),
    },
    # Hale (D4-03): the big steady one, square-on from a little below, unhurried; warm sand backdrop, a
    # work-glove yellow rim
    "hale": {
        "asset": "char_crew_hale",
        "pose": _ARMS_DOWN + [
            ("chest", (0, 0, 1), -6.0),
            ("neck", (1, 0, 0), -2.0),
            ("head", (0, 0, 1), 4.0),
        ],
        "camera": {"target_dz": -0.12, "dist": 1.46, "yaw": -14.0, "cam_dz": -0.04, "lens": 85.0},
        "bg": {"top": (0.020, 0.016, 0.010), "glow": (0.100, 0.075, 0.030), "glow_xy": (0.66, 0.58), "glow_r": 0.60},
        "lights": [
            ("key", "AREA", (-0.25, 1.45, 1.95), (0.0, 0.0, 1.58), (1.00, 0.95, 0.86), 64.0, 1.4, 1.0),
            ("fill", "AREA", (-1.25, 1.00, 1.50), (0.0, 0.0, 1.52), (0.90, 0.88, 0.82), 18.0, 1.6, 0.35),
            ("rim", "AREA", (0.85, -1.10, 1.70), (0.0, 0.0, 1.52), (1.00, 0.80, 0.35), 130.0, 0.5, 2.0),
            ("rim_far", "AREA", (-0.80, -1.15, 1.62), (0.0, 0.0, 1.52), (0.85, 0.75, 0.55), 60.0, 0.5, 1.4),
            ("hair", "AREA", (-0.2, -0.9, 2.3), (0.0, 0.0, 1.62), (0.95, 0.92, 0.85), 14.0, 0.4, 0.5),
        ],
        "ambient": (0.022, 0.019, 0.014),
    },
}


# Stills-only grading on top of the contact renderer: a film exposure (EV; the crew's dark cloth
# washes out to grey at the contacts' exposure) and a hair albedo multiplier (dark hair otherwise
# reads silver under the rims).
GRADE: dict[str, dict] = {
    "rook": {"exposure": -0.3, "hair_mul": 0.6, "look": "AgX - High Contrast"},
    "sable": {"exposure": -0.5, "hair_mul": 0.45, "eye_mul": 0.7, "look": "AgX - High Contrast"},
    "dutch": {"exposure": -0.6, "hair_mul": 1.0, "look": "AgX - High Contrast"},
    "wren": {"exposure": -0.5, "hair_mul": 0.85, "look": "AgX - High Contrast"},
    "marten": {"exposure": -0.5, "hair_mul": 0.9, "look": "AgX - High Contrast"},
    "jay": {"exposure": -0.5, "hair_mul": 0.55, "look": "AgX - High Contrast"},
    "juno": {"exposure": -0.5, "hair_mul": 0.8, "look": "AgX - High Contrast"},
    "hale": {"exposure": -0.2, "hair_mul": 0.6, "look": "AgX - High Contrast"},
}


def _graded_prepare(name: str):
    import _review_mats  # noqa: PLC0415

    orig = _review_mats.prepare

    def prepare(skip_orm: tuple[str, ...] = ()) -> None:
        import bpy

        orig(skip_orm)
        g = GRADE[name]

        def grade(scene, *_args) -> None:     # after the renderer has set AgX up
            scene.view_settings.exposure = g["exposure"]
            scene.view_settings.look = g.get("look", scene.view_settings.look)

        bpy.app.handlers.render_pre.append(grade)
        for m in bpy.data.materials:
            if not m.use_nodes:
                continue
            if "char_hair" in m.name:
                k = g["hair_mul"]
            elif m.name.startswith("M_char_eye") and "iris" not in m.name:
                k = g.get("eye_mul", 0.85)          # eye whites glow under a close key
            else:
                continue
            if k == 1.0:
                continue
            nt = m.node_tree
            alb = nt.nodes.get("lib_albedo")
            bsdf = nt.nodes.get("Principled BSDF")
            if alb is None or bsdf is None:
                continue
            mul = nt.nodes.new("ShaderNodeMix")
            mul.data_type = "RGBA"
            mul.blend_type = "MULTIPLY"
            mul.inputs["Factor"].default_value = 1.0
            mul.inputs["B"].default_value = (k,) * 3 + (1.0,)
            nt.links.new(alb.outputs["Color"], mul.inputs["A"])
            nt.links.new(mul.outputs["Result"], bsdf.inputs["Base Color"])

    _review_mats.prepare = prepare


def _render(name: str, out: str) -> None:
    cp.CONTACTS[name] = HEISTERS[name]       # the contact table is never written back
    _graded_prepare(name)
    cp.PORTRAIT_SIZE = int(os.environ.get("SIZE", str(cp.PORTRAIT_SIZE)))
    cp._render(name, out)


def _sheet(out: str, pngs: list[str]) -> None:
    """The four at full size (scaled to 512) with the picker's sizes below: 128, 72 (loadout), 64."""
    from PIL import Image, ImageDraw

    tiles = [Image.open(p).convert("RGB") for p in pngs]
    t = 512
    pad = 24
    label_h = 32
    w = len(tiles) * t + (len(tiles) + 1) * pad
    h = pad + t + label_h + 128 + 2 * pad
    sheet = Image.new("RGB", (w, h), (22, 24, 28))
    dr = ImageDraw.Draw(sheet)
    for i, (img, p) in enumerate(zip(tiles, pngs)):
        x = pad + i * (t + pad)
        sheet.paste(img.resize((t, t), Image.LANCZOS), (x, pad))
        dr.text((x, pad + t + 8), f"{Path(p).stem}  ({img.size[0]}x{img.size[1]}; 128 / 72 loadout / 64)",
                fill=(200, 200, 200))
        y = pad + t + label_h
        sheet.paste(img.resize((128, 128), Image.LANCZOS), (x, y))
        sheet.paste(img.resize((72, 72), Image.LANCZOS), (x + 140, y))
        sheet.paste(img.resize((64, 64), Image.LANCZOS), (x + 224, y))
    sheet.save(out)
    print("WROTE", out)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if argv[0] == "render":
        _render(argv[1], argv[2])
    elif argv[0] == "sheet":
        _sheet(argv[1], argv[2:])
    else:
        raise SystemExit(f"unknown command {argv[0]}")
