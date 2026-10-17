## Per-observer bookkeeping for StealthDirector (server only). Owner: ENV A.
## One instance per node in G.OBSERVER; holds that observer's detection meters per crew slot
## (S2.1), its stimulus meters (S4.1) and the last values replicated to each crew peer.
class_name StealthObserverState
extends RefCounted

var node: Node3D = null
## Enums.ObserverKind
var kind: int = Enums.ObserverKind.GUARD
## Preset values resolved from StealthTweak.observer_presets (S2.2).
## D-128 PD2: far = dis_max / camera range (m); half_fov_rad = angle_max (NPC) or half the cone (camera).
var far: float = 40.0
var half_fov_rad: float = deg_to_rad(60.0)
## D-128 PD2 `delay` pair (s) and the attention class (&"combatant" / &"non_combatant").
var delay_min: float = 0.2
var delay_max: float = 2.0
var attention: StringName = &"combatant"
## D-118 ◇ gadget base rate (1 / preset gadget_time).
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
	far = float(preset.get("far", 40.0))
	half_fov_rad = deg_to_rad(float(preset.get("fov_deg", 120.0)) * 0.5)
	delay_min = float(preset.get("delay_min", 0.2))
	delay_max = float(preset.get("delay_max", 2.0))
	attention = StringName(preset.get("attention", &"combatant"))
	base_rate = 1.0 / maxf(float(preset.get("gadget_time", 1.0)), 0.001)


func is_camera() -> bool:
	return kind == Enums.ObserverKind.CAMERA
