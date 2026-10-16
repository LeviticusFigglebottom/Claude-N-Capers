## Worker for detection_live_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0

var _out: String = ""
var _heist: StringName = &"glasshouse"
var _scenario: StringName = &"ahead"
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_heist = StringName(args[1]) if args.size() > 1 else &"glasshouse"
	_scenario = StringName(args[2]) if args.size() > 2 else &"ahead"
	_out = (args[0] if args.size() > 0 else OS.get_user_data_dir() + "/detection_live").path_join(String(_heist))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	SaveService.root_dir = "user://detection_live_profiles"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	_flow.show_hub()
	_flow.call(&"_on_heist_chosen", _heist, Enums.Difficulty.ROUTINE)
	_flow.call(&"_on_briefing_continue", _heist, Enums.Difficulty.ROUTINE)
	_flow.call(&"_on_preplan_confirmed", {})
	await _frames(4)
	_flow.call(&"_on_launch_requested", _flow.loadout_screen.current_loadout())
	var t0: int = Time.get_ticks_msec()
	while (_hud() == null or _flow.runtime == null or _local_crew() == null) and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	await _frames(30)
	var me: CrewController = _local_crew()
	if me == null:
		print("LIVE RING FAIL no local crew")
		get_tree().quit(1)
		return
	me.set_masked(true)
	await _frames(10)
	var guards: Array[NpcBase] = _guards()
	print("LIVE RING guards=%d" % guards.size())
	# One scenario per run (a full meter raises the alarm, and LOUD hides every ring).
	match _scenario:
		&"side":  # the player looks ~75 degrees away: the crosshair arc, the ring at the edge or off screen
			if _place_in_view(me, guards, 6.0, deg_to_rad(75.0)) != null:
				await _fill_series("side", 4.0)
		&"camera":
			var cam: Node3D = _camera()
			if cam != null and _place_before_camera(me, cam):
				await _fill_series("camera", 4.0)
		_:  # straight ahead: stand in front of a guard, face it, let the real meter fill
			if _place_in_view(me, guards, 7.0, 0.0) != null:
				await _fill_series("ahead", 4.0)
	print("LIVE RING DONE %s" % _heist)
	get_tree().quit(0)


func _fill_series(tag: String, game_seconds: float) -> void:
	# Software rendering runs a heist at ~1 fps; a slow clock keeps each frame's step small enough to see the fill.
	Engine.time_scale = 0.2
	var t0: int = Time.get_ticks_msec()
	var game_t: float = 0.0
	var last_bucket: int = -1
	var shots: int = 0
	while game_t < game_seconds and shots < 6:
		await get_tree().process_frame
		game_t += get_process_delta_time()
		var v: float = _max_value()
		var bucket: int = int(v * 4.0)  # 0, 25, 50, 75, 100 %
		if v > 0.02 and bucket != last_bucket:
			last_bucket = bucket
			shots += 1
			await _shot("%s_%02d_v%03d" % [tag, shots, int(v * 100.0)])
			if v >= 1.0:
				break
	if shots == 0:
		await _shot("%s_none" % tag)
	print("LIVE RING %s: %d shots, peak %.2f after %.2f game s (%.0f s wall)" % [tag, shots, _max_value(), game_t,
			(Time.get_ticks_msec() - t0) / 1000.0])
	Engine.time_scale = 1.0


func _max_value() -> float:
	var hud: Hud = _hud()
	if hud == null:
		return 0.0
	var best: float = 0.0
	for row: Dictionary in hud.model.get(&"detection") as Array:
		best = maxf(best, float(row.get("value", 0.0)))
	return best


## Put `me` up to `dist` m from a guard, inside its view cone (or, failing that, anywhere open with the guard turned
## to face the player), looking at it turned by `turn` rad. Returns the guard.
func _place_in_view(me: CrewController, guards: Array[NpcBase], dist: float, turn: float) -> NpcBase:
	for face_guard: bool in [false, true]:
		for g: NpcBase in guards:
			var fwd: Vector3 = -g.global_transform.basis.z
			fwd.y = 0.0
			if fwd.length() < 0.1:
				continue
			fwd = fwd.normalized()
			var yaws: Array = [0.0, 25.0, -25.0, 45.0, -45.0] if not face_guard else range(0, 360, 30)
			for yaw: Variant in yaws:
				var dir: Vector3 = fwd.rotated(Vector3.UP, deg_to_rad(float(yaw)))
				for d: float in [dist, dist * 0.7, dist * 0.5, dist * 0.35]:
					var at: Vector3 = _open_spot(me, g, dir, d)
					if at == Vector3.INF:
						continue
					if face_guard:
						g.look_at(Vector3(at.x, g.global_position.y, at.z), Vector3.UP)
					var to_g: Vector3 = g.global_position - at
					to_g.y = 0.0
					var look: Vector3 = to_g.normalized().rotated(Vector3.UP, -turn)
					me.teleport(Transform3D(Basis.looking_at(look, Vector3.UP), at + Vector3.UP * 0.05))
					print("LIVE RING placed %.1f m from %s at %s deg (turn %.0f, guard turned %s)" % [d, g.name, yaw,
							rad_to_deg(turn), face_guard])
					return g
	print("LIVE RING no guard spot with line of sight")
	return null


## A floor point `d` m from guard `g` along `dir` that the guard's eye can see, or Vector3.INF.
func _open_spot(me: CrewController, g: NpcBase, dir: Vector3, d: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = me.get_world_3d().direct_space_state
	var spot: Vector3 = g.global_position + dir * d
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(g.eye_position(), spot + Vector3.UP * 1.5, 1)
	if not space.intersect_ray(q).is_empty():
		return Vector3.INF
	var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 1.0,
			spot + Vector3.DOWN * 1.0, 1)
	var hit: Dictionary = space.intersect_ray(down)
	if hit.is_empty():
		return Vector3.INF
	return hit["position"] as Vector3


func _place_before_camera(me: CrewController, cam: Node3D) -> bool:
	var fwd: Vector3 = -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return false
	fwd = fwd.normalized()
	var space: PhysicsDirectSpaceState3D = me.get_world_3d().direct_space_state
	for d: float in [6.0, 4.5, 3.0]:
		var spot: Vector3 = cam.global_position + fwd * d
		var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(spot, spot + Vector3.DOWN * 6.0, 1)
		var hit: Dictionary = space.intersect_ray(down)
		if hit.is_empty():
			continue
		var at: Vector3 = hit["position"] as Vector3
		var to_c: Vector3 = cam.global_position - at
		to_c.y = 0.0
		me.teleport(Transform3D(Basis.looking_at(to_c.normalized(), Vector3.UP), at + Vector3.UP * 0.05))
		print("LIVE RING placed %.1f m before camera %s" % [d, cam.name])
		return true
	return false


func _guards() -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	for n: Node in get_tree().get_nodes_in_group(G.OBSERVER):
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.alive and npc.role == &"guard":
			out.append(npc)
	return out


func _camera() -> Node3D:
	for n: Node in get_tree().root.find_children("*", "SecurityCamera", true, false):
		return n as Node3D
	return null


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("LIVE RING SHOT ", path)


func _hud() -> Hud:
	for n: Node in get_tree().root.find_children("*", "Hud", true, false):
		if n is Hud and (n as Hud).model != null:
			return n as Hud
	return null


func _local_crew() -> CrewController:
	for n: Node in get_tree().root.find_children("*", "CrewController", true, false):
		var c: CrewController = n as CrewController
		if c != null and c.slot == Net.local_slot() and not c.is_ai:
			return c
	return null
