"""SOURCE.txt writer (style guide §6). Pure Python. Output must be deterministic: no timestamps,
no absolute paths, sorted keys."""

from __future__ import annotations

import json
import pathlib
from typing import Any


def render(asset_id: str, script_rel: str, params: dict[str, Any], seed: int, blender_version: str,
           lib_version: str, extra: dict[str, Any] | None = None) -> str:
    folder = pathlib.PurePosixPath(script_rel).parent.name or "<folder>"
    lines = [
        f"asset: {asset_id}",
        f"script: {script_rel}",
        f"params: {json.dumps(params, sort_keys=True)}",
        f"seed: {seed}  (zlib.crc32(asset_id))",
        f"generator: Blender {blender_version}, tools/blender/lib {lib_version}",
        f"rebuild: python3 tools/blender/build.py --category {folder} --asset {asset_id}",
        "edit policy: generated file, never edit by hand; change the script and rebuild",
    ]
    for key, value in sorted((extra or {}).items()):
        lines.append(f"{key}: {value}")
    return "\n".join(lines) + "\n"


def write(path: pathlib.Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="\n")
