"""Greybox material palette (C1-02). Pure Python, shared by make_materials.py (Godot .tres) and the
greybox asset scripts (Blender placeholder colours), so both always agree.

Rules (style guide §3): sRGB 8-bit channels inside 30..240, saturation <= 0.75, never the
interactable cyan #4FD1E8. Hues are deliberately distinct per surface class so greybox screenshots
read: warm walls, sandy exterior, blue-grey floors, orange doors, ochre stairs, green counters.
"""

# library_id: (hex sRGB, roughness, alpha)
GREYBOX: dict[str, tuple[str, float, float]] = {
    "grey_wall": ("#B9B3A7", 0.8, 1.0),
    "grey_wall_ext": ("#A3876B", 0.85, 1.0),
    "grey_floor": ("#6F7A86", 0.75, 1.0),
    "grey_ceiling": ("#D3D0C8", 0.85, 1.0),
    "grey_door": ("#B8763C", 0.7, 1.0),
    "grey_frame": ("#4C4642", 0.6, 1.0),
    "grey_glass": ("#9CC2B8", 0.1, 0.35),
    "grey_stair": ("#B59E52", 0.8, 1.0),
    "grey_trim": ("#5C5C62", 0.6, 1.0),
    "grey_counter": ("#5F8C6C", 0.7, 1.0),
    "grey_prop": ("#9C5C52", 0.8, 1.0),
}

FORBIDDEN = ("#4FD1E8",)


def srgb_bytes(hex_color: str) -> tuple[int, int, int]:
    h = hex_color.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def check() -> None:
    for lib_id, (hex_color, rough, alpha) in GREYBOX.items():
        rgb = srgb_bytes(hex_color)
        if hex_color.upper() in FORBIDDEN:
            raise ValueError(f"{lib_id}: uses the reserved interactable accent")
        if min(rgb) < 30 or max(rgb) > 240:
            raise ValueError(f"{lib_id}: channel outside 30..240")
        if max(rgb) and (max(rgb) - min(rgb)) / max(rgb) > 0.75:
            raise ValueError(f"{lib_id}: saturation above 0.75")
        if not 0.0 <= rough <= 1.0 or not 0.0 < alpha <= 1.0:
            raise ValueError(f"{lib_id}: roughness/alpha out of range")
