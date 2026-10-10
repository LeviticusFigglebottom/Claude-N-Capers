#!/usr/bin/env python3
"""Write the greybox StandardMaterial3D library to game/world/materials/grey_*.tres (C1-02).

    python3 tools/blender/greybox/make_materials.py

Pure Python, deterministic (no uid line: Godot tolerates a missing uid in a text resource and
references these by path). Not an asset script: it has no ASSET_ID/VARIANTS, so build.py skips it.
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from _palette import GREYBOX, check, srgb_bytes  # noqa: E402

OUT_DIR = pathlib.Path(__file__).resolve().parents[3] / "game" / "world" / "materials"


def fmt(x: float) -> str:
    s = f"{x:.6f}".rstrip("0").rstrip(".")
    return s if s else "0"


def render(lib_id: str, hex_color: str, roughness: float, alpha: float) -> str:
    r, g, b = (c / 255.0 for c in srgb_bytes(hex_color))
    lines = [
        '[gd_resource type="StandardMaterial3D" format=3]',
        "",
        "[resource]",
        f'resource_name = "{lib_id}"',
    ]
    if alpha < 1.0:
        lines.append("transparency = 1")
        lines.append("cull_mode = 2")
    lines.append(f"albedo_color = Color({fmt(r)}, {fmt(g)}, {fmt(b)}, {fmt(alpha)})")
    lines.append("metallic_specular = 0.5")
    lines.append(f"roughness = {fmt(roughness)}")
    return "\n".join(lines) + "\n"


def main() -> int:
    check()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for lib_id, (hex_color, rough, alpha) in sorted(GREYBOX.items()):
        path = OUT_DIR / f"{lib_id}.tres"
        path.write_text(render(lib_id, hex_color, rough, alpha), encoding="utf-8", newline="\n")
        print(f"wrote {path.relative_to(OUT_DIR.parents[2])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
