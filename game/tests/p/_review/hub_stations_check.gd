## PO (2026-10-23) "press F in the safehouse does nothing": windowed real-input check of C's 3D safehouse through the
## real MenuFlow (main menu -> safehouse) with the real walker (spawn_for_hub + PlayerInput). Per station (Stations/*):
## stand at its UsePoint (stated shortcut: a teleport; Po5Pilot's navmesh walk needs a HeistRuntime), then
##   natural   look level (pitch 0) at the station: is the prompt up (hub_interaction.aimed_component)?
##   aimed     look straight at its InteractableComponent: prompt up?
##   F         a real F tap (PInputDriver): does the station's screen open (safehouse.station_id)? one shot, then back.
## Rows: "[HUB] ROW <station> | natural <y/n> | aimed <y/n> | F <y/n> | <detail>"; "[HUB] RESULT".
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --resolution 960x540 --path game \
##     res://tests/p/_review/hub_stations_check.tscn -- --out=/abs/dir
## Owner: ENV P.
extends Node

const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")

var _out: String = "user://hub_stations"
var _inp: PInputDriver = null
var _ok: bool = true


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _shot(nm: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(PCaptureName.safe_path("%s/%s.png" % [_out, nm]))


func _run() -> void:
	GameSettings.current().set_value(GameSettings.CONTROLS, &"safehouse_hub", "walk")
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await _frames(5)
	f.main_menu.safehouse_button.pressed.emit()
	await _frames(60)
	var sh: SafehouseHost = f.safehouse
	var c: CrewController = sh.walker as CrewController
	if not sh.is_active() or c == null:
		print("[HUB] RESULT FAIL (no 3D safehouse / no real walker: active %s walker %s)" % [sh.is_active(), sh.walker])
		get_tree().quit(1)
		return
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var pin: PlayerInput = c.get_node(^"PlayerInput") as PlayerInput
	await _shot("00_safehouse")
	var stations: Array[Node] = sh.map.get_node(^"Stations").get_children()
	# The range station leaves the safehouse for the range: check it last.
	stations.sort_custom(func(a: Node, b: Node) -> bool: return a.name != "range" and b.name == "range")
	for st: Node in stations:
		var hs: HubStationPrefab = st as HubStationPrefab
		if hs == null:
			continue
		var comp: InteractableComponent = hs.interactable
		var up: Node3D = hs.get_node_or_null(^"UsePoint") as Node3D
		var stand: Vector3 = up.global_position if up != null else hs.global_position + hs.global_basis.z * 1.0
		# Face the station from the UsePoint (yaw toward the component), level.
		var flat: Vector3 = comp.global_position - stand
		var yaw: float = atan2(-flat.x, -flat.z)
		c.teleport(Transform3D(Basis(Vector3.UP, yaw), stand))
		await _frames(10)
		pin.add_look(wrapf(yaw - c.look_yaw, -PI, PI), -c.look_pitch)
		await _frames(8)
		var natural: bool = c.hub_interaction.aimed_component(c) == comp
		var to: Vector3 = comp.global_position - c.eye_position()
		pin.add_look(0.0, atan2(to.y, Vector2(to.x, to.z).length()) - c.look_pitch)
		await _frames(8)
		var aimed: bool = c.hub_interaction.aimed_component(c) == comp
		var sid: StringName = hs.station_id  # the range station frees the safehouse (leave(range_marker))
		var comp_y: float = comp.global_position.y
		var dist: float = c.eye_position().distance_to(comp.global_position)
		await _inp.tap(&"interact")
		await _frames(40)
		var left: bool = not sh.is_active()  # the range: the safehouse left for it
		var opened: bool = sh.station_id == sid or left
		await _shot("%s_after_f" % sid)
		_ok = _ok and aimed and opened
		print("[HUB] ROW %s | natural %s | aimed %s | F %s | comp y %.2f, dist %.2f, screen '%s'%s" % [sid,
			"y" if natural else "n", "y" if aimed else "n", "y" if opened else "n", comp_y, dist, sh.station_id,
			" (left for the range)" if left else ""])
		if left:
			break  # the safehouse (and its stations) is gone; the remaining stations need a fresh enter
		if sh.station_id != &"" and f.current is UiScreen:
			(f.current as UiScreen).back_requested.emit()
			await _frames(40)
	print("[HUB] RESULT %s" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)
	await get_tree().create_timer(10.0, true, false, true).timeout
	OS.kill(OS.get_process_id())
