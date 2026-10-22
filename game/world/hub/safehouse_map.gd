## Root script of the safehouse hub (C4-02; docs/contracts/hub_map.md v1.2, docs/design/heists/safehouse.md "The
## Press"). A HeistMap for the map tooling only (validate_level `--profile=hub`, review cameras, floors): heist_def and
## variant_table stay null and the hub is never on the Board. Data only: SafehouseHost (ENV B) drives the walker and
## the station screens. Provides `station_requested` (relayed from every station), the `jukebox` cabinet, and
## `spawn_transform` for the return markers. Owner: ENV C.
@tool
class_name SafehouseMap
extends HeistMap

## Relayed from every station's own `station_requested` (SafehouseHost drops the second signal for one use).
signal station_requested(station_id: StringName)

## The cabinet's track before the player picks one (MusicDirector track id).
const DEFAULT_TRACK: StringName = &"glasshouse"
## The cabinet plays the quiet stem in the safehouse.
const CABINET_STEM: StringName = MusicTrack.STEM_STEALTH
const SPAWN_FALLBACK: StringName = &"Spawn"

## hub_map.md: the cabinet's MusicDirector (Audio/Jukebox, listen_to_event_bus off).
var jukebox: MusicDirector = null


func _ready() -> void:
	jukebox = get_node_or_null(^"Audio/Jukebox") as MusicDirector
	if Engine.is_editor_hint():
		return
	for st: Node in stations():
		if st.has_signal(&"station_requested"):
			st.connect(&"station_requested", _relay)


## Station nodes: children of Stations/ (each a HubStationPrefab with a UsePoint).
func stations() -> Array[Node]:
	var holder: Node = get_node_or_null(^"Stations")
	return holder.get_children() if holder != null else ([] as Array[Node])


## Plays `track_id` on the cabinet (&"" = the default track).
func set_jukebox_track(track_id: StringName) -> void:
	if jukebox == null:
		return
	if not jukebox.preview(track_id if track_id != &"" else DEFAULT_TRACK, CABINET_STEM):
		jukebox.preview(DEFAULT_TRACK, CABINET_STEM)


## The return marker `marker` under Spawns/ (ReturnHeist, ReturnRange, Spawn); unknown ids land on the `Spawn`
## marker in the loading bay so a missing return point never strands the player.
func spawn_transform(marker: StringName) -> Transform3D:
	for id: StringName in [marker, SPAWN_FALLBACK]:
		var n: Node3D = get_node_or_null(NodePath("Spawns/%s" % id)) as Node3D if id != &"" else null
		if n != null:
			return n.global_transform
	return global_transform


func _relay(id: StringName) -> void:
	station_requested.emit(id)
