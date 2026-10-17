# PO-14 device-visual review (ENV D, 2026-10-17)

Scratch merge of env/d-art 6e3ee21b + env/a-core 59c4f282 (DeviceVisual, padlock) + env/c-worlds 115e2716 (gate locks);
nothing from it is pushed. For each lock the running device (A's `DeviceVisual.update(RUNNING, kind, mount)` on the
prefab's own mount) is rendered from 2 m (gameplay), up to 6 m (raycast to the open side) and a side close-up
(Compatibility renderer, llvmpipe, 640x360). `po14_overlap.log`: static colliders overlapping each device mesh, and
"visual" = device vertices inside a nearby level mesh's bounds (deepest mm). GN CuratorSafe's "Visual_RoomUCO" hits
are a whole-room mesh's bounds (false positive). Sheets: rows = lock/device, columns = 2 m, 6 m, side.
