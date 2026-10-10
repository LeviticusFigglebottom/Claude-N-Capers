"""Greybox door visuals for the `door` prefab (contracts/visual_slots.md) and bare door frames.

Nodes: Frame (static mesh, depth = wall + 0.02), Leaf (Node3D at the hinge axis, rotate around Y),
LeafMesh, HandleMesh, Handle marker; double doors add Leaf2/LeafMesh2/HandleMesh2/Handle2.
Collision: Collision (StaticBody3D, trimesh) for the frame only. Origin: bottom-centre of the
opening on the wall centreline. Leaf closed = rotation 0.
"""

import _kit

TRI_BUDGET = 500
VARIANTS = {
    f"arch_door_{prefix}{kind}_t{t}": {"kind": kind, "wall_t": t / 100, "leaf": prefix == ""}
    for prefix in ("", "frame_")
    for kind in ("single", "double", "service")
    for t in (20, 40)
}


def build(ctx) -> None:
    p = ctx.params
    _kit.door(ctx, p["kind"], p["wall_t"], p["leaf"])
