## Stealth service (G.SVC_STEALTH): detection meters, stimuli, noise propagation, alarm.
## Owner: ENV A. Rows: S1.1, S1.5, S2.1-S2.8, S3.x, S4.1-S4.4, S11.2.
##
## PUBLIC API (other systems call only these; internals may change):
##   raise_alarm(reason, source_net_id)        -> emits alarm_raised [R] once (S3, S5, S11.2)
##   is_stealth() -> bool                      -> CASING/STEALTH and no alarm yet
##   detection_value(observer, slot) -> float  -> meter 0..1 (test_hooks.md)
##   register_stimulus(source, kind, data) -> int / unregister_stimulus(id) / stimulus(id)
##   zone_kinds_at(pos) -> Array[int] (MapZone.Kind) / in_zone(pos, kind) -> bool
##   has_los(from, to, exclude) -> bool        -> vision ray on world/vision-blocker layers
##   make_noise(...) is HeistRuntime.make_noise; this director listens to runtime.noise_made.
## Observer protocol (NpcBase, SecurityCamera): see game/systems/stealth/README.md.
class_name StealthDirector
extends Node

signal crew_detected(observer: Node, crew: Node)
signal stimulus_noticed(observer: Node, stimulus_id: int)

## Physics layers that block vision: world_static(1), world_dynamic(2), vision_blockers(8).
const VISION_MASK: int = (1 << 0) | (1 << 1) | (1 << 7)
## MapZone layer "triggers" (10).
const TRIGGER_MASK: int = 1 << 9

var alarm_reason: StringName = &""
var alarm_raised: bool = false

var _runtime: HeistRuntime = null
var _next_stimulus_id: int = 1
## id -> { "id", "kind", "source" (Node3D), "data" }
var _stimuli: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	_runtime = HeistRuntime.of(self)
	if _runtime != null:
		_runtime.noise_made.connect(_on_noise)


func is_stealth() -> bool:
	if alarm_raised or _runtime == null:
		return false
	return _runtime.phase == Enums.HeistPhase.CASING or _runtime.phase == Enums.HeistPhase.STEALTH


## Server: the alarm. Idempotent; HeistRuntime switches to LOUD on alarm_raised.
func raise_alarm(reason: StringName, source_net_id: int = 0) -> void:
	if not Net.is_authority() or alarm_raised:
		return
	alarm_raised = true
	alarm_reason = reason
	Log.info(&"stealth", "ALARM: %s (source %d)" % [reason, source_net_id])
	EventBus.alarm_raised.emit(reason, source_net_id)
	Net.replicate_event(&"alarm_raised", [reason, source_net_id])


func detection_value(_observer: Node, _slot: int) -> float:
	return 0.0  # A1-04


# --- Stimuli ------------------------------------------------------------------------

## Register something suspicious (S4.1). `data` may carry "position" for sources without a node.
func register_stimulus(source: Node3D, kind: StringName, data: Dictionary = {}) -> int:
	var id: int = _next_stimulus_id
	_next_stimulus_id += 1
	_stimuli[id] = {"id": id, "kind": kind, "source": source, "data": data}
	return id


func unregister_stimulus(id: int) -> void:
	_stimuli.erase(id)


func stimulus(id: int) -> Dictionary:
	return _stimuli.get(id, {})


func stimuli() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: int in _stimuli:
		out.append(_stimuli[id])
	return out


## World position of a stimulus (source node or data.position).
func stimulus_position(id: int) -> Vector3:
	var s: Dictionary = _stimuli.get(id, {})
	var src: Node3D = s.get("source") as Node3D
	if src != null and is_instance_valid(src):
		return src.global_position
	return (s.get("data", {}) as Dictionary).get("position", Vector3.INF)


# --- Spatial queries --------------------------------------------------------------------

func zone_kinds_at(pos: Vector3) -> Array[int]:
	var out: Array[int] = []
	if not is_inside_tree():
		return out
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	q.position = pos
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = TRIGGER_MASK
	for hit: Dictionary in space.intersect_point(q, 16):
		var z: MapZone = hit.get("collider") as MapZone
		if z != null and not out.has(z.kind):
			out.append(z.kind)
	return out


func in_zone(pos: Vector3, kind: int) -> bool:
	return zone_kinds_at(pos).has(kind)


func has_los(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> bool:
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, VISION_MASK)
	q.exclude = exclude
	return space.intersect_ray(q).is_empty()


# --- Noise (S4.3) -------------------------------------------------------------------------

func _on_noise(_position: Vector3, _radius: float, _kind: StringName, _source_net_id: int) -> void:
	pass  # A1-04: propagate to observers (radius x noise_no_los_mult without LOS)
