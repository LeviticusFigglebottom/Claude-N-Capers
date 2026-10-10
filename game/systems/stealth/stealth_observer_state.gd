## Per-observer bookkeeping for StealthDirector (server only). Owner: ENV A.
## One instance per node in G.OBSERVER; holds that observer's detection meters per crew slot
## (S2.1), its stimulus meters (S4.1) and the last values replicated to each crew peer.
class_name StealthObserverState
extends RefCounted

var node: Node3D = null
## Enums.ObserverKind
var kind: int = Enums.ObserverKind.GUARD
## Preset values resolved from StealthTweak.observer_presets (S2.2).
var near: float = 2.0
var far: float = 30.0
var half_fov_rad: float = deg_to_rad(60.0)
var base_rate: float = 1.0
## Physics time of the last staggered update (dt is integrated from it).
var last_time: float = 0.0
## Refresh stamp used to drop observers that left the group.
var seen_stamp: int = 0
## crew slot -> meter 0..1 (absent = 0).
var meters: Dictionary[int, float] = {}
## crew slot -> true once the meter reached 1.0 (stays full, S2.1).
var spotted: Dictionary[int, bool] = {}
## crew slot -> last value sent as detection_progress.
var sent: Dictionary[int, float] = {}
## stimulus id -> meter 0..1.
var stimulus_meters: Dictionary[int, float] = {}
## stimulus id -> true once notify_stimulus was called.
var noticed: Dictionary[int, bool] = {}


func setup(p_node: Node3D, p_kind: int, preset: Dictionary) -> void:
	node = p_node
	kind = p_kind
	near = float(preset.get("near", 2.0))
	far = float(preset.get("far", 30.0))
	half_fov_rad = deg_to_rad(float(preset.get("fov_deg", 120.0)) * 0.5)
	base_rate = 1.0 / maxf(float(preset.get("min_time", 1.0)), 0.001)


func is_camera() -> bool:
	return kind == Enums.ObserverKind.CAMERA
