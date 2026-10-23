# Contract: safehouse hub map (v1.2)

Owner: LEAD. Producer ENV C (scene, art), ENV A (`hub_station` prefab, hub crew spawn: A3-11), consumer ENV B
(MenuFlow / SafehouseHost, B6-06). Design: docs/design/heists/safehouse.md ("The Press"). Decision: D-072.

## Scene
* `res://world/hub/safehouse/safehouse.tscn`, root class `SafehouseMap extends HeistMap` (v1.2: a data-only HeistMap subclass with
  `heist_def = null` and `variant_table = null`; no `<id>_def.tres`, so never on the Board; levelcheck reuses its pipeline). Children follow heist_map.md where they apply (Geometry, Props, Lighting, Navigation, Rooms, Spawns,
  ReviewCameras); gameplay nodes live under `Stations/`. validate_level runs with `--profile=hub`.
* The root provides:
  * `signal station_requested(id: StringName)` (optional when every station emits it itself);
  * `jukebox`: ENV C's `MusicDirector` with `listen_to_event_bus = false`: `preview(track_id, stem := &"assault") -> bool`,
    `stop_preview()`, `set_ducked(bool)` (−6 dB, 0.25 s tween; on MusicDirector itself, so the 2D JukeboxScreen
    director has it too; SafehouseHost ducks while a station screen is open). Fallback: a descendant named `Jukebox`;
  * `set_jukebox_track(track_id)`;
  * `spawn_transform(marker: StringName) -> Transform3D` for `&"ReturnHeist"` / `&"ReturnRange"` (fallback: Marker3Ds
    with those names); any unknown id falls back to the `Spawn` Marker3D (loading bay), so a missing return point
    never strands the player.

## Stations
* Nodes in group `G.HUB_STATION` (`&"hub_station"`) and/or children of `Stations/`. Station id = `station_id`
  export, else the node name. Each has a `UsePoint` (Marker3D where the player stands, +Y up, −Z facing the station;
  the walker returns there after the screen closes) and an optional `StationCam` (a **Marker3D**, −Z = view
  direction, optional `fov` meta in degrees, default 60; never a live Camera3D; B blends the walker camera to it
  over 0.35 s). Interaction reach is measured from the station's origin, not the UsePoint.
* Signal: `station_requested(id)` (or ENV A's prefab `station_used(id, crew)`). Interaction reach 2.0 m, prompt key
  `ui.prompt.station.<id>`, same prompt format as in-heist interactions.
* The 9 ids: `board`, `planning`, `armory`, `masks`, `jukebox`, `notoriety`, `range`, `crew`, `profile` (career screen, B7-01; added in v1.1).

## Session
* Solo / local (PD2). The walker is spawned by `CrewController.spawn_for_hub(parent, xform, loadout) -> Node`
  (ENV A, QC-43): unmasked civilian mode, `set_input_paused(bool)`, `teleport(xform)`, a Camera3D; its prompt comes
  through `LocalHudModel.track(crew)` `interaction`. The 2D hub stays as the fallback (Options → Controls
  `safehouse_hub` walk/menu).

## v1.2 (2026-10-22, LEAD; C proposal for C4-02)
* `SafehouseMap` extends `HeistMap` (data only, no HeistDef / variant table) instead of being an unrelated root, so validate_level's
  HeistMap-typed pipeline is reused. `--profile=hub` skips the heist-only checks (contract heist nodes, variants, police/assault,
  loot, cameras, stealth) and keeps geometry, floating, clipping, materials, lights, scale, doors, navmesh, rooms, bounds and the
  walkthrough (spawn → every station UsePoint). B's SafehouseHost still checks for `SafehouseMap`. Anything that iterates heists must
  go through HeistRegistry (def files), never through `is HeistMap`.
