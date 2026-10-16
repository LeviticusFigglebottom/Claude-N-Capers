## PO6-17 turret van (PD2 SWAT van turret event). Owner: ENV A. Replicated dynamic entity; the runner spawns it
## at a `TurretVan_<n>` marker (nose +Z, ENV C prop_turret_van) or a fallback police spawn.
## Stages: DRIVE (drives drive_in_m forward into the spot over drive_in_s, cue.assault_van_arrive) -> DOORS
## (rear doors swing open over door_open_s, cue.assault_van_park = engine stop fact; the `squad` dismounts at
## ExitPoint) -> DEPLOY (the roof turret rises out of TurretMount over deploy_s, cue.assault_turret_deploy) ->
## ACTIVE (AssaultTurret fires) -> DESTROYED (turret killed: cue.assault_turret_destroyed, a small blast fx,
## the van stays as a wreck; the event ends). Body collision: an AnimatableBody3D box on world_dynamic.
class_name AssaultTurretVan
extends AssaultEventEntity

enum Stage { DRIVE, DOORS, DEPLOY, ACTIVE, DESTROYED }

const DOOR_OPEN_DEG: float = 100.0
const TURRET_SINK_M: float = 0.95

## Server: called once in DOORS with (unit ids, ExitPoint transform); the runner spawns them.
var on_dismount: Callable = Callable()

var model: Node3D = null
var body: AnimatableBody3D = null
var turret: AssaultTurret = null
var door_l: Node3D = null
var door_r: Node3D = null
var exit_point: Node3D = null
var mount: Node3D = null
## Server: parked transform and drive start.
var park: Transform3D = Transform3D.IDENTITY
var drive_from: Transform3D = Transform3D.IDENTITY

var _client_t: float = 0.0


func _build() -> void:
	var tw: AssaultEventsTweak = AssaultEventsTweak.data()
	model = AssaultEventEntity.prop(String(params.get("van_scene", tw.van_scene)))
	if model == null:
		model = _placeholder()
	model.name = "Prop"
	add_child(model)
	door_l = AssaultEventEntity.find_named(model, "DoorL")
	door_r = AssaultEventEntity.find_named(model, "DoorR")
	exit_point = AssaultEventEntity.find_named(model, "ExitPoint")
	mount = AssaultEventEntity.find_named(model, "TurretMount")
	body = AnimatableBody3D.new()
	body.name = "Body"
	body.sync_to_physics = false
	body.collision_layer = 1 << 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(2.4, 2.6, 6.0)
	cs.shape = bs
	cs.position = Vector3(0, 1.3, -0.1)
	body.add_child(cs)
	add_child(body)
	turret = AssaultTurret.new()
	turret.name = "Turret"
	(mount if mount != null else self).add_child(turret)
	turret.setup(self, String(params.get("turret_scene", tw.turret_scene)))
	turret.position = Vector3(0, -TURRET_SINK_M, 0)


## Same node names / frame as C's prop_turret_van (nose +Z, rear doors -Z).
static func _placeholder() -> Node3D:
	var root: Node3D = Node3D.new()
	var model_n: Node3D = Node3D.new()
	model_n.name = "Model"
	root.add_child(model_n)
	var b: Node3D = AssaultEventEntity.marker("Body", Vector3.ZERO)
	model_n.add_child(b)
	var navy: Color = Color(0.12, 0.16, 0.27)
	b.add_child(AssaultEventEntity.box("Shell", Vector3(2.2, 2.0, 5.8), navy, Vector3(0, 1.45, 0)))
	b.add_child(AssaultEventEntity.box("Stripe", Vector3(2.22, 0.18, 5.82), Color(0.84, 0.89, 0.29), Vector3(0, 1.2, 0)))
	b.add_child(AssaultEventEntity.box("Windscreen", Vector3(1.9, 0.6, 0.05), Color(0.1, 0.12, 0.14), Vector3(0, 1.95, 2.91)))
	b.add_child(AssaultEventEntity.box("LightBarBlue", Vector3(0.6, 0.12, 0.25), Color(0.1, 0.3, 1.0), Vector3(0.4, 2.52, 2.2)))
	b.add_child(AssaultEventEntity.box("LightBarRed", Vector3(0.6, 0.12, 0.25), Color(1.0, 0.1, 0.1), Vector3(-0.4, 2.52, 2.2)))
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.9, 1.9]:
			var w: MeshInstance3D = AssaultEventEntity.cylinder("Wheel", 0.42, 0.3, Color(0.05, 0.05, 0.05), Vector3(x, 0.42, z))
			w.rotation.z = PI * 0.5
			b.add_child(w)
	for side: float in [1.0, -1.0]:
		var d: Node3D = AssaultEventEntity.marker("DoorL" if side > 0.0 else "DoorR", Vector3(1.06 * side, 0.5, -2.9))
		model_n.add_child(d)
		d.add_child(AssaultEventEntity.box("DoorLMesh" if side > 0.0 else "DoorRMesh", Vector3(1.04, 1.8, 0.06), navy,
			Vector3(-0.52 * side, 0.9, -0.03)))
	var m: Node3D = AssaultEventEntity.marker("TurretMount", Vector3(0, 2.66, -1.0))
	model_n.add_child(m)
	m.add_child(AssaultEventEntity.cylinder("Ring", 0.5, 0.12, Color(0.17, 0.18, 0.2), Vector3(0, -0.06, 0)))
	model_n.add_child(AssaultEventEntity.marker("ExitPoint", Vector3(0, 0, -4.2)))
	return root


func exit_transform() -> Transform3D:
	if exit_point != null and exit_point.is_inside_tree():
		return exit_point.global_transform
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -4.2))


func _apply_stage(s: int) -> void:
	_client_t = 0.0
	if turret == null:
		return
	if s >= Stage.ACTIVE and turret.position.y < 0.0:
		turret.position = Vector3.ZERO
	if s >= Stage.DOORS:
		_set_doors(1.0 if s > Stage.DOORS else 0.0)
	turret.set_destroyed(s == Stage.DESTROYED)


func _set_doors(f: float) -> void:
	var a: float = deg_to_rad(DOOR_OPEN_DEG) * clampf(f, 0.0, 1.0)
	if door_l != null:
		door_l.rotation.y = -a
	if door_r != null:
		door_r.rotation.y = a


func _process(delta: float) -> void:
	if is_server():
		return
	_client_t += delta  # clients animate doors / turret rise locally from the replicated stage
	_animate(stage, _client_t)


func _animate(s: int, t: float) -> void:
	if s == Stage.DOORS:
		_set_doors(t / maxf(p_float("door_open_s", 0.8), 0.01))
	elif s == Stage.DEPLOY and turret != null:
		turret.position.y = -TURRET_SINK_M * (1.0 - clampf(t / maxf(p_float("deploy_s", 2.0), 0.01), 0.0, 1.0))


# --- Server -------------------------------------------------------------------------------------

func start(p_park: Transform3D) -> void:
	park = p_park
	var fwd: Vector3 = park.basis.z.normalized()
	drive_from = Transform3D(park.basis, park.origin - fwd * p_float("drive_in_m", 20.0))
	global_transform = drive_from  # engine loop / cue.assault_van_arrive: C's CuePlayer on assault_event_started


func _physics_process(delta: float) -> void:
	if not is_server() or not is_inside_tree():
		return
	stage_time += delta
	match stage:
		Stage.DRIVE:
			var dur: float = maxf(p_float("drive_in_s", 4.0), 0.01)
			var f: float = clampf(stage_time / dur, 0.0, 1.0)
			var e: float = 1.0 - pow(1.0 - f, 2.0)  # ease out: brakes into the spot
			global_transform = Transform3D(park.basis, drive_from.origin.lerp(park.origin, e))
			if f >= 1.0:
				cue(&"cue.assault_van_park", global_position)
				set_stage(Stage.DOORS)
		Stage.DOORS:
			var dur2: float = maxf(p_float("door_open_s", 0.8), 0.01)
			_set_doors(stage_time / dur2)
			if stage_time >= dur2:
				var ids: Array = params.get("squad", []) as Array
				if on_dismount.is_valid() and not ids.is_empty():
					on_dismount.call(ids, exit_transform())
				cue(&"cue.assault_turret_deploy", turret.global_position if turret != null else global_position)
				set_stage(Stage.DEPLOY)
		Stage.DEPLOY:
			_animate(Stage.DEPLOY, stage_time)
			if stage_time >= p_float("deploy_s", 2.0):
				set_stage(Stage.ACTIVE)
				turret.armed = true
		Stage.ACTIVE:
			turret.tick(delta)


## Server (AssaultTurret.take_hit): the turret is dead.
func turret_destroyed(_by_net_id: int) -> void:
	if stage == Stage.DESTROYED:
		return
	turret.armed = false
	var at: Vector3 = turret.global_position + Vector3(0, 0.9, 0)
	set_stage(Stage.DESTROYED)
	ShotFx.explosion(self, at, 1.6, &"explosion")
	cue(&"cue.assault_turret_destroyed", at)
	end_event()


func _net_state() -> Dictionary:
	var d: Dictionary = {"stage": stage}
	if turret != null:
		d["ty"] = snappedf(turret.yaw, 0.01)
		d["tp"] = snappedf(turret.pitch, 0.01)
		d["thp"] = roundf(turret.health)
		d["tar"] = roundf(turret.armor_hp)
	return d


func _apply_net_state(d: Dictionary) -> void:
	super._apply_net_state(d)
	if turret == null:
		return
	if d.has("ty") or d.has("tp"):
		turret.set_pose(float(d.get("ty", turret.yaw)), float(d.get("tp", turret.pitch)))
	if d.has("thp"):
		turret.health = float(d["thp"])
	if d.has("tar"):
		turret.armor_hp = float(d["tar"])
