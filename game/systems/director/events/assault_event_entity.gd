## PO6-17: base of the replicated assault-event entities (turret van, helicopter, breach). Owner: ENV A.
## A dynamic entity (HeistRuntime.dynamic_root child with a `net_id`): HeistNetSync spawns it on clients from
## its script path + `kind` / `params` (NetEntityCodec), mirrors `_net_state()` diffs and its transform
## (`_net_xform()`). Visuals are built in _ready on every peer from ENV C's prop scene under G.PROPS_DIR when it
## exists (docs/levels/_art/po6_17/README.md), else a code-built placeholder with the same node names.
## The server simulates; clients only render the replicated stage / pose.
class_name AssaultEventEntity
extends Node3D

## Server: the event is over (entity left / destroyed / blown); the runner stops counting it as active.
signal ended(entity: AssaultEventEntity)

var net_id: int = 0
var kind: StringName = &""
var params: Dictionary = {}
## Replicated stage (subclass enum).
var stage: int = 0
## Seconds in the current stage (server; clients count locally from the stage change).
var stage_time: float = 0.0
var is_ended: bool = false


func is_server() -> bool:
	return Net.is_authority()


func _ready() -> void:
	_build()
	_apply_stage(stage)


## Subclasses: build the visuals (every peer).
func _build() -> void:
	pass


## Subclasses: show `s` (every peer; also called on the server by set_stage).
func _apply_stage(_s: int) -> void:
	pass


func set_stage(s: int) -> void:
	if s == stage:
		return
	stage = s
	stage_time = 0.0
	_apply_stage(s)


## Server: mark the event over (idempotent).
func end_event() -> void:
	if is_ended:
		return
	is_ended = true
	ended.emit(self)


func _net_state() -> Dictionary:
	return {"stage": stage}


func _apply_net_state(d: Dictionary) -> void:
	if d.has("stage") and int(d["stage"]) != stage:
		stage = int(d["stage"])
		stage_time = 0.0
		_apply_stage(stage)


func _net_xform() -> Variant:
	return global_transform


func p_float(key: String, default: float, difficulty: int = -1) -> float:
	var v: Variant = params.get(key, default)
	if v is Array or v is PackedFloat32Array:
		var a: Array = Array(v)
		if a.is_empty():
			return default
		return float(a[clampi(difficulty, 0, a.size() - 1)])
	return float(v)


## Server: an audio cue at `pos` from this entity, relayed to clients ([R]).
func cue(cue_id: StringName, pos: Vector3) -> void:
	EventBus.audio_cue_requested.emit(cue_id, pos, net_id)
	Net.replicate_event(&"audio_cue_requested", [cue_id, pos, net_id])


## ENV C's prop scene `rel` under G.PROPS_DIR (instanced), or null when it is not there yet.
static func prop(rel: String) -> Node3D:
	if rel == "":
		return null
	var path: String = G.PROPS_DIR + rel
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null


## Placeholder box mesh (unshaded tint so it reads in any light).
static func box(node_name: String, size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = pos
	return mi


static func cylinder(node_name: String, radius: float, height: float, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	return mi


static func marker(node_name: String, pos: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = node_name
	n.position = pos
	return n


## First descendant named `node_name` (C's props keep markers under `Model/`).
static func find_named(root: Node, node_name: String) -> Node3D:
	if root == null:
		return null
	var direct: Node3D = root.get_node_or_null(NodePath("Model/" + node_name)) as Node3D
	if direct != null:
		return direct
	return root.find_child(node_name, true, false) as Node3D
