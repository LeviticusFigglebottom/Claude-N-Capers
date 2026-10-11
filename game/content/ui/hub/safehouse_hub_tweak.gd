## 3D safehouse hub data (B6-06, QC-45..49). Owner: ENV B. Data: res://content/data/ui/safehouse_hub.tres.
## Names every piece of ENV C's safehouse scene and ENV A's hub hooks that SafehouseHost looks up, so
## B code holds no path into another env (the scene path lives here, like MusicCatalogTweak.table_path).
class_name SafehouseHubTweak
extends Resource

const DEFAULT_PATH: String = "res://content/data/ui/safehouse_hub.tres"

## ENV C's safehouse scene (docs/design/heists/safehouse.md "Contract deviations"). Missing = 2D hub.
@export var scene_path: String = ""
## Global class the scene root must be (looked up by name, UiNav.global_class); &"" = any root.
@export var map_class: StringName = &""
## Group of the station nodes (ENV A's `hub_station` prefab, or C's SafehouseStation).
@export var station_group: StringName = &"hub_station"
## Child of the scene root that holds the stations, each named by its station id.
@export var stations_node: String = "Stations"
## Signals (on the root and on each station) that request a station; the first argument is the id.
@export var station_signals: Array[StringName] = [&"station_requested", &"station_used"]
## Station child the player returns to when its screen closes.
@export var use_point_name: String = "UsePoint"
## Optional station child the camera blends to before the screen opens.
@export var station_cam_name: String = "StationCam"
## Camera blend time (s) to a StationCam; 0 opens the screen at once.
@export var station_cam_blend_s: float = 0.35
## ENV A's crew class and its hub spawn hook `spawn_for_hub(parent, xform, loadout) -> Node` (QC-43).
@export var crew_class: StringName = &"CrewController"
@export var spawn_method: StringName = &"spawn_for_hub"
## Group of a walker stand-in placed in the scene (mocks / greybox) used while A's hook is missing.
@export var walker_group: StringName = &"hub_walker"
## Return markers (`spawn_transform(id)` on the root, else a descendant Marker3D with that name).
@export var entry_marker: StringName = &"ReturnHeist"
@export var range_marker: StringName = &"ReturnRange"
@export var heist_marker: StringName = &"ReturnHeist"
## Root property holding the jukebox preview target (preview(id, stem) / stop_preview()), and the
## node name searched for when the property is missing.
@export var jukebox_property: StringName = &"jukebox"
@export var jukebox_node: String = "Jukebox"
## Root method that plays the picked track on the cabinet (MusicCatalog.resolve_choice(profile)).
@export var jukebox_track_method: StringName = &"set_jukebox_track"
## Backdrop alpha over the 3D view while a station screen or the pause menu is open.
@export var dim_alpha: float = 0.72


static func load_default() -> SafehouseHubTweak:
	var t: SafehouseHubTweak = null
	if ResourceLoader.exists(DEFAULT_PATH):
		t = load(DEFAULT_PATH) as SafehouseHubTweak
	if t == null:
		Log.error(&"ui", "missing %s" % DEFAULT_PATH)
		t = SafehouseHubTweak.new()
	return t
