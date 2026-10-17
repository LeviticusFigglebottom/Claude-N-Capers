#!/usr/bin/env python3
"""Write the hand-prop scenes (D-115) from char_anim_humanoid/SOURCE.txt.

    python3 tools/blender/characters/make_hand_prop_scenes.py [--check]

For every prop of ``HAND_PROPS`` this writes ``game/world/characters/_props/hand_<prop>.tscn``: a ``Node3D``
root ``Hand<Prop>`` that IS the hand socket frame (put it under ``HandR/Socket`` or ``HandL/Socket`` with an
identity transform), and under it ``Model`` = the prop glb (``char_hand_<prop>``, built by ``char_hand_props.py``)
at the SOURCE.txt ``<prop>_grip`` transform. Root metadata: ``prop``, ``socket`` (``HandR`` / ``HandL``),
``clips`` (the ambient clips that hold it). ``hand_props.json`` next to them indexes the same. ``--check``
compares instead of writing (exit 1 when stale). Not an asset script (no ASSET_ID/VARIANTS): build.py skips it.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
SOURCE = REPO / "game/assets/characters/char_anim_humanoid/SOURCE.txt"
OUT = REPO / "game/world/characters/_props"

#: prop -> the ambient clips (characters.md / SOURCE.txt) that hold it; the socket comes from the grip line.
HAND_PROPS = {
    "phone": ["phone_call", "phone_seated", "walk_text", "queue_idle_b"],
    "cigarette": ["smoke"],
    "mug": ["mug_idle", "mug_carry_walk"],
    "mop": ["mop"],
    "book": ["sit_bed_read", "sit_chair_read"],
    "rag": ["bartender_wipe"],
    "bottle": ["bartender_pour"],
    "glass": ["bartender_pour"],
    "cash": ["teller_count"],
}

_XFORM = re.compile(r"basis x=\(([^)]*)\) y=\(([^)]*)\) z=\(([^)]*)\) origin=\(([^)]*)\) relative to (Hand[LR])/Socket")


def grips() -> dict[str, tuple[list[list[float]], list[float], str]]:
    """prop -> (basis columns x, y, z; origin; socket) from SOURCE.txt `<prop>_grip` lines."""
    out = {}
    for line in SOURCE.read_text().splitlines():
        key, _, rest = line.partition(": ")
        if not key.endswith("_grip"):
            continue
        m = _XFORM.match(rest)
        if m:
            vec = [[float(x) for x in m.group(i).split(",")] for i in range(1, 5)]
            out[key[:-5]] = (vec[:3], vec[3], m.group(5))
    return out


def scene_text(prop: str, cols: list[list[float]], origin: list[float], socket: str) -> str:
    rows = [cols[c][r] for r in range(3) for c in range(3)]
    nums = ", ".join(f"{v + 0.0:g}" for v in rows + origin)
    clips = ", ".join(f'"{c}"' for c in HAND_PROPS[prop])
    name = "Hand" + prop.capitalize()
    return (f'[gd_scene load_steps=2 format=3]\n\n'
            f'[ext_resource type="PackedScene" path="res://assets/characters/char_hand_{prop}/char_hand_{prop}.glb" '
            f'id="1_glb"]\n\n'
            f'[node name="{name}" type="Node3D"]\n'
            f'metadata/prop = "{prop}"\n'
            f'metadata/socket = "{socket}"\n'
            f'metadata/clips = PackedStringArray({clips})\n\n'
            f'[node name="Model" parent="." instance=ExtResource("1_glb")]\n'
            f'transform = Transform3D({nums})\n')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="only report stale files")
    args = ap.parse_args()
    table = grips()
    files: dict[pathlib.Path, str] = {}
    index = {}
    for prop, clips in HAND_PROPS.items():
        if prop not in table:
            print(f"make_hand_prop_scenes: SOURCE.txt has no {prop}_grip", file=sys.stderr)
            return 1
        cols, origin, socket = table[prop]
        path = OUT / f"hand_{prop}.tscn"
        files[path] = scene_text(prop, cols, origin, socket)
        index[prop] = {"scene": f"res://world/characters/_props/hand_{prop}.tscn", "socket": socket,
                       "clips": clips, "asset": f"char_hand_{prop}"}
    files[OUT / "hand_props.json"] = json.dumps(index, indent=2, sort_keys=True) + "\n"
    stale = [p for p, text in files.items() if not p.exists() or p.read_text() != text]
    if args.check:
        for p in stale:
            print(f"stale: {p.relative_to(REPO)}")
        return 1 if stale else 0
    OUT.mkdir(parents=True, exist_ok=True)
    for p in stale:
        p.write_text(files[p])
    print(f"make_hand_prop_scenes: {len(stale)} of {len(files)} file(s) written to {OUT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
