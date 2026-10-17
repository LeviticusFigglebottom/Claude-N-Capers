## PO-16 / D-145 windowed check: PD2 free ladder climbing by real input (Po5Pilot mouse look + WASD + jump) on the unit
## map with a 3 m Ladder prefab and a box landing under its Top marker. Walk in (attach), climb up looking up, stop
## mid-ladder and look around (no camera lock), climb on and step off onto the landing, look down + W to climb back
## down, re-attach and jump off. Screenshots per stage plus every FRAME_EVERY-th rendered frame of the whole run
## (frames/NNNN.png, for a clip). Stated shortcut: direct launch on the unit map, crew teleported to the ladder.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/ladder_check.tscn -- --out=/abs/dir
## Prints "[LADDER] ROW ..." per stage and "[LADDER] RESULT PASS/FAIL". Owner: ENV P.
extends Node

const FRAME_EVERY: int = 3

var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var runner_out: String = ""
var _lad: Ladder = null
var _shot: int = 0
var _frame: int = 0
var _rec: bool = false
var _ok: bool = true


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			runner_out = kv[1]
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/ladder_check"
	DirAccess.make_dir_recursive_absolute(runner_out + "/frames")
	_run.call_deferred()


func _process(_delta: float) -> void:
	if not _rec:
		return
	_frame += 1
	if _frame % FRAME_EVERY == 0:
		get_viewport().get_texture().get_image().save_png("%s/frames/%04d.png" % [runner_out, _frame / FRAME_EVERY])


func note(msg: String) -> void:
	print("[LADDER t=%.1f] %s" % [rt.heist_time_s if rt != null else -1.0, msg])


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [runner_out, _shot, label])


func _row(stage: String, ok: bool, detail: String) -> void:
	_ok = _ok and ok
	print("[LADDER] ROW %s|%s|%s" % [stage, "PASS" if ok else "FAIL", detail])


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_s: float) -> bool:
	for _i: int in int(max_s * Engine.physics_ticks_per_second):
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func _hold_w(cond: Callable, max_s: float) -> bool:
	pilot.inp.press(&"move_forward")
	var ok: bool = await _until(cond, max_s)
	pilot.inp.release(&"move_forward")
	return ok


func _run() -> void:
	rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_lad = ATestMaps.add_prefab(rt, "ladder", Vector3(0, 0, -6)) as Ladder
	await _ticks(3)
	var top: Vector3 = _lad.top_position()
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	var depth: float = absf(top.z - _lad.global_position.z) + 2.0
	box.size = Vector3(4.0, top.y, depth)
	shape.shape = box
	body.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()  # placeholder look for the landing
	var bm: BoxMesh = BoxMesh.new()
	bm.size = box.size
	mesh.mesh = bm
	body.add_child(mesh)
	rt.map.add_child(body)
	body.global_position = Vector3(_lad.global_position.x, top.y * 0.5, _lad.global_position.z + 0.15 + depth * 0.5)
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await _ticks(20)
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.inp.capture_mouse()
	await pilot.calibrate()
	await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	var off: Vector3 = -_lad.global_basis.z
	off.y = 0.0
	rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, _lad.bottom_position() + off.normalized() * 1.6 +
		Vector3(0, 0.05, 0)))
	await _ticks(10)
	await pilot.face(_lad.global_position + Vector3(0, 2.2, 0), 0.03, 1.5)
	await shot("at_the_ladder")
	_rec = true
	# 1. walk in + climb to mid-ladder
	pilot.inp.press(&"move_forward")
	var mid: bool = await _until(func() -> bool: return c.ladder.is_climbing() and c.global_position.y > 1.2, 4.0)
	pilot.inp.release(&"move_forward")
	_row("walk_in_attach", mid and not _lad.is_climbing(c.slot), "y %.2f free %s prefab_climb %s" % [
		c.global_position.y, c.ladder.is_climbing(), _lad.is_climbing(c.slot)])
	await shot("mid_ladder")
	# 2. look around while attached
	var y0: float = c.global_position.y
	await pilot.face(c.global_position + Vector3(3.0, 0.5, 0.0), 0.05, 1.5)
	await _ticks(20)
	await shot("look_right_on_ladder")
	await pilot.face(c.global_position + Vector3(0.0, -1.0, -3.0), 0.05, 1.5)
	await _ticks(20)
	await shot("look_back_on_ladder")
	_row("full_look", c.ladder.is_climbing() and absf(c.global_position.y - y0) < 0.1, "y %.2f -> %.2f" % [y0,
		c.global_position.y])
	# 3. climb on and step off at the top
	await pilot.face(_lad.global_position + Vector3(0, 4.0, 0), 0.05, 1.5)
	var on_top: Callable = func() -> bool: return c.global_position.y > top.y - 0.15 and not c.ladder.is_climbing()
	var up: bool = await _hold_w(on_top, 4.0)
	await _ticks(10)
	_row("step_off_top", up, "at %s top %s" % [c.global_position, top])
	await shot("on_the_landing")
	# 4. look down over the edge + W climbs down
	await pilot.face(_lad.bottom_position() + Vector3(0, 0.2, -0.3), 0.03, 1.5)
	await shot("look_down_from_landing")
	var floor_y: float = _lad.bottom_position().y + 0.1
	var on_floor: Callable = func() -> bool: return c.global_position.y < floor_y and not c.ladder.is_climbing()
	var down: bool = await _hold_w(on_floor, 5.0)
	_row("climb_down", down, "at %s" % c.global_position)
	await shot("back_on_the_floor")
	# 5. re-attach and jump off
	rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, _lad.bottom_position() + off.normalized() * 0.9 +
		Vector3(0, 0.05, 0)))
	await _ticks(10)
	await pilot.face(_lad.global_position + Vector3(0, 2.2, 0), 0.03, 1.5)
	pilot.inp.press(&"move_forward")
	await _until(func() -> bool: return c.ladder.is_climbing() and c.global_position.y > 1.4, 4.0)
	pilot.inp.release(&"move_forward")
	await pilot.inp.tap(&"jump")
	await _ticks(5)
	var let_go: bool = not c.ladder.is_climbing()
	await _until(func() -> bool: return c.grounded, 3.0)
	_row("jump_off", let_go and c.global_position.y < 0.3, "y %.2f" % c.global_position.y)
	await shot("jumped_off")
	_rec = false
	print("[LADDER] RESULT %s" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)
