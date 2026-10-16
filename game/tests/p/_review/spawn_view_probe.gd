## Spawn-view probe (headless is fine): per heist, every PLAYER SpawnPoint (and the crew as spawned): position,
## facing yaw, and what an eye-height ray along the facing hits first (distance, collider path). A camera that starts
## inside geometry or a few cm from a wall shows a flat void at heist start. Prints `[SPAWN] ...`.
##   /opt/godot/godot --headless --path game res://tests/p/_review/spawn_view_probe.tscn -- [--heists=night_deposit,...]
## Owner: ENV P.
extends Node

var _heists: PackedStringArray = ["night_deposit", "glasshouse", "gallery_night", "dockside_burn", "shadow_ledger"]


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--heists="):
			_heists = a.substr(9).split(",")
	for h: String in _heists:
		await _heist(StringName(h))
	print("[SPAWN] RESULT DONE")
	get_tree().quit(0)


func _heist(h: StringName) -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(h, 1002, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false})
	if rt == null:
		print("[SPAWN] %s launch failed" % h)
		return
	for _i: int in 10:
		await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = rt.get_viewport().world_3d.direct_space_state
	for n: Node in rt.map.get_slots(G.PLAYER_SPAWN):
		var sp: Node3D = n as Node3D
		_probe(h, "spawn %s tags=%s" % [rt.get_path_to(sp), (n as SpawnPoint).tags], sp.global_transform, space, null)
	var c: CrewController = rt.crew_controller(0) as CrewController
	var cam: Camera3D = CrewView.of(c).camera() if c != null else null
	if cam != null:
		_probe(h, "crew0 camera", cam.global_transform, space, c, true)
	rt.teardown()
	for _i: int in 3:
		await get_tree().process_frame


func _probe(h: StringName, label: String, xf: Transform3D, space: PhysicsDirectSpaceState3D, crew: Node,
		is_cam: bool = false) -> void:
	var eye: Vector3 = xf.origin if is_cam else xf.origin + Vector3(0, Tweak.crew().eye_standing, 0)
	var fwd: Vector3 = -xf.basis.z
	fwd.y = 0.0 if not is_cam else fwd.y
	fwd = fwd.normalized()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + fwd * 30.0)
	if crew != null:
		q.exclude = [(crew as CollisionObject3D).get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	var pq: PhysicsPointQueryParameters3D = _pt(eye)
	var me: CrewController = (get_tree().root.find_children("*", "CrewController", true, false).front()
		as CrewController) if crew == null else crew as CrewController
	if me != null:
		pq.exclude = [me.get_rid()]  # the spawned crew stands on spawn 1: its own capsule is not "inside geometry"
	var inside: bool = not space.intersect_point(pq).is_empty()
	print("[SPAWN] %s %s at %s yaw=%.0f eye_inside_collider=%s first_hit=%s" % [h, label, xf.origin,
		rad_to_deg(atan2(-fwd.x, -fwd.z)), inside,
		("%.2f m %s" % [eye.distance_to(hit["position"]), (hit["collider"] as Node).get_path()]) if not hit.is_empty() else "none"])


func _pt(p: Vector3) -> PhysicsPointQueryParameters3D:
	var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	q.position = p
	return q
