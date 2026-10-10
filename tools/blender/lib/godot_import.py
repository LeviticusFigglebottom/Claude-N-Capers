"""Create or update the Godot ``<file>.glb.import`` sidecar so the post-import script runs. Pure Python.

Godot owns the .import format. We only guarantee a handful of ``[params]`` keys:

* ``import_script/path`` -> ``res://world/tools/import/glb_post_import.gd`` (material library mapping)
* the LOD/tangent keys from ``lod.GODOT_IMPORT_PARAMS``

If the sidecar does not exist we write a minimal one (``[remap] importer="scene"`` + those params);
the next ``godot --import`` completes it (uid, dest_files, all other defaults) and keeps our params.
If it exists we rewrite only our keys in place, so Godot's uid and other settings survive rebuilds.
"""

from __future__ import annotations

import pathlib

from . import lod

POST_IMPORT_SCRIPT = "res://world/tools/import/glb_post_import.gd"


def required_params() -> dict[str, str]:
    params = {"import_script/path": f'"{POST_IMPORT_SCRIPT}"'}
    params.update(lod.GODOT_IMPORT_PARAMS)
    return params


def minimal_text() -> str:
    lines = ["[remap]", "", 'importer="scene"', 'type="PackedScene"', "", "[params]", ""]
    lines += [f"{k}={v}" for k, v in sorted(required_params().items())]
    return "\n".join(lines) + "\n"


def ensure(glb_path: pathlib.Path) -> bool:
    """Write or patch ``<glb>.import``. Returns True if the file changed."""
    imp = glb_path.with_name(glb_path.name + ".import")
    if not imp.exists():
        imp.write_text(minimal_text(), encoding="utf-8", newline="\n")
        return True
    old = imp.read_text(encoding="utf-8")
    lines = old.split("\n")
    wanted = required_params()
    seen: set[str] = set()
    section = ""
    params_end = -1
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped
            continue
        if section != "[params]":
            continue
        params_end = i
        key = stripped.split("=", 1)[0]
        if key in wanted:
            lines[i] = f"{key}={wanted[key]}"
            seen.add(key)
    missing = [f"{k}={v}" for k, v in sorted(wanted.items()) if k not in seen]
    if missing:
        if params_end < 0:
            lines += ["", "[params]", ""]
            params_end = len(lines) - 1
        lines[params_end + 1:params_end + 1] = missing
    new = "\n".join(lines)
    if new != old:
        imp.write_text(new, encoding="utf-8", newline="\n")
        return True
    return False
