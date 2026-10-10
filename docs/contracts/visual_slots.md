# Contract: visual slots (v1.0)

How art scenes (ENV C props/characters, ENV B weapons) plug into ENV A gameplay prefabs.

## General rules for any visual scene

* Root: `Node3D`. Pivot = **bottom-centre contact point** for floor objects, **back-centre** for
  wall-mounted objects, **top-centre** for ceiling-mounted objects.
* Forward = **−Z** (the side facing the room / the user). +Y up. Meters. Scale 1.0 at root.
* No scripts that affect gameplay. Visual-only scripts (animated FX) allowed under `world/`.
* No collision in the visual scene **unless** a child named `Collision` (StaticBody3D) is provided for
  prefabs that declare "visual supplies collision" below; otherwise the prefab owns collision.
* Materials: from the shared material library (`world/materials/`) or generated per asset;
  **never** default material.
* LODs: `GeometryInstance3D.visibility_range_*` or importer LODs as the style guide specifies.

## Named nodes required per prefab

| Prefab | Required named nodes in visual scene |
|---|---|
| `door` | `Frame` (static), `Leaf` (Node3D pivot at hinge axis; A rotates it around Y), optional `Leaf2` (double), `Handle` marker. Leaf closed = rotation 0. Default size 0.9 × 2.1 m (single), 1.8 × 2.1 m (double). Visual supplies collision for `Frame` only. |
| `security_camera` | `Mount` (static, wall/ceiling), `Head` (Node3D; A yaws/pitches it), `Lens` (Marker3D at lens, −Z = view dir), `Led` (MeshInstance3D; A toggles emission) |
| `camera_station` | `Screens` (MeshInstance3D(s), A swaps material to off/static), `Seat` marker |
| `display_case` | `Body`, `Glass` (MeshInstance3D(s); A hides + spawns shatter), `LootAnchor` markers |
| `safe` / vault | `Body`, `Door` (pivot at hinge), `DrillPoint` marker (−Z into the lock), `LootAnchor` |
| `drill_point` | n/a (drill/saw art is a separate device visual with `Bit` node A spins) |
| `keycard_reader`, `keypad` | `Panel`, `Led` |
| `window` | `Frame`, `Glass`, optional `Sash` (pivot for openable) |
| `secure_zone` (van) | `Body`, `DoorL`, `DoorR` (pivots), `DropAnchor` |
| `ladder` | `Top` and `Bottom` markers |
| `body_container` | `Lid` (pivot), `Inside` marker |
| loot bag | `Bag` mesh; pivot bottom; size by weight class (style guide) |
| weapons (ENV B) | `Muzzle`, `Eject`, `SightRail`, `Magwell`, `Underbarrel`, `SideRail`, `StockMount`, `GripMount`, `BarrelMount`, `LeftHandIK` markers; mods attach at the marker named for their `ModType` (see data_schemas.md §Weapons) |
| weapons, extra (QB-22) | origin = firing-hand pivot (grip centre plane, mid-grip, 20 mm below the grip top); `Slide` cycles along local +Z; optional `AimPoint` (ADS eye alignment, −Z down the bore). A mod may carry its own `Muzzle` (e.g. a suppressor tip): `WeaponVisual.get_marker(&"Muzzle")` returns the outermost one, and ENV A must use it for tracers, flash and the noise origin. On pistols `SideRail` and `Underbarrel` may share the dust-cover rail. |
| weapons, animated parts (QB-42/44) | `Pump` (shotgun fore-end, slides along local +Z then back), `Bolt` (bolt handle: rotates then slides +Z), `Slide` (pistols). ENV A animates them per fire/reload. On tube-fed weapons `Magwell` sits at the loading port. Bipods are a flat stability bonus in data until a deploy mechanic exists. |
| characters | see characters.md |

ENV A must ship placeholder visuals with the **same named nodes** so swapping art changes nothing.
