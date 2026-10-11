## 3D safehouse hub data (B6-06, QC-45..49). Owner: ENV B. Data: res://content/data/ui/safehouse_hub.tres.
## Names every piece of ENV C's safehouse scene and ENV A's hub hooks that SafehouseHost looks up, so
## B code holds no path into another env (the scene path lives here, like MusicCatalogTweak.table_path).
## Contract: docs/contracts/hub_map.md v1.0. Stations are found in group G.HUB_STATION (contracts/ids.gd).
class_name SafehouseHubTweak
extends Resource

const DEFAULT_PATH: String = "res://content/data/ui/safehouse_hub.tres"

## ENV C's safehouse scene (docs/design/heists/safehouse.md "Contract deviations"). Missing = 2D hub.
@export var scene_path: String = ""
## Global class the scene root must be (looked up by name, UiNav.global_class); &"" = any root.
@export var map_class: StringName = &""
## Child of the scene root that holds the stations, each named by its station id.
@export var stations_node: String = "Stations"
## Signals (on the root and on each station) that request a station; the first argument is the id.
@export var station_signals: Array[StringName] = [&"station_requested", &"station_used"]
## Station child the player returns to when its screen closes.
@export var use_point_name: String = "UsePoint"
## Optional station child (a Marker3D, -Z = view direction; hub_map.md v1.0) the walker's own camera blends
## to before the screen opens, and its meta holding the field of view in degrees (default station_cam_fov).
@export var station_cam_name: String = "StationCam"
@export var station_cam_fov_meta: StringName = &"fov"
@export var station_cam_fov: float = 60.0
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
## Marker3D any unknown / missing return id falls back to (the loading bay spawn, hub_map.md v1.0).
@export var spawn_marker: StringName = &"Spawn"
## Root property holding the jukebox preview target (preview(id, stem) / stop_preview()), and the
## node name searched for when the property is missing.
@export var jukebox_property: StringName = &"jukebox"
@export var jukebox_node: String = "Jukebox"
## Root method that plays the picked track on the cabinet (MusicCatalog.resolve_choice(profile)).
@export var jukebox_track_method: StringName = &"set_jukebox_track"
## MusicDirector.set_ducked(bool) (-6 dB): called on the cabinet while a station screen other than
## `jukebox_station` is open (only when the method exists).
@export var duck_method: StringName = &"set_ducked"
@export var jukebox_station: StringName = &"jukebox"
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
