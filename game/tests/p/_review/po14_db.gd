## PO-14 / D-138 windowed check, Dockside Burn: the count-cage gate opens by a VISIBLE placed drill on its padlock
## (no stand-in safe, no invisible device). Needs a seed whose cash rolled into the count room (cash_countroom: the
## mission disables the padlock otherwise): --scan=A-B (headless OK) prints each seed's cash_location. Play (windowed,
## Po5Pilot real input, crew AI on so the cartel / police are fought): mask, walk to CountCagePadlock, place the drill
## (loud: devices first), fix jams, screenshots of the drill on the lock and of the open gate; checks `beaten_by`, the
## gate's is_open and that no Safe node sits within SAFE_NEAR_M of the gate. Stated shortcut: direct launch, no menus.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/po14_db.tscn -- --seed=N --out=/abs/dir      (or -- --scan=1-20)
## Owner: ENV P.
extends Node

const SAFE_NEAR_M: float = 4.0
const MAX_S: float = 360.0

var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var runner_out: String = ""
var _seed: int = 1
var _scan: Vector2i = Vector2i.ZERO
var _shot: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": runner_out = v
			"seed": _seed = v.to_int()
			"scan":
				var ab: PackedStringArray = v.split("-")
				_scan = Vector2i(ab[0].to_int(), ab[1].to_int() if ab.size() > 1 else ab[0].to_int())
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/po14_db"
	DirAccess.make_dir_recursive_absolute(runner_out)
	if _scan != Vector2i.ZERO:
		_run_scan.call_deferred()
	else:
		_run.call_deferred()


func note(msg: String) -> void:
	print("[PO14 t=%.1f] %s" % [rt.heist_time_s if rt != null else -1.0, msg])


func shot(label: String) -> void:
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png(PCaptureName.safe_path("%s/%02d_%s.png" % [runner_out, _shot, label]))
	RenderingServer.render_loop_enabled = false


func _run_scan() -> void:
	for s: int in range(_scan.x, _scan.y + 1):
		var r: HeistRuntime = await HeistLauncher.launch(&"dockside_burn", s, Enums.Difficulty.ROUTINE, self,
			{"crew_ai": false})
		if r == null:
			print("[PO14SCAN] seed %d: no runtime" % s)
			continue
		print("[PO14SCAN] seed %d cash_location=%s" % [s, r.mission.variant(&"cash_location")])
		r.teardown()
		for _i: int in 3:
			await get_tree().process_frame
	get_tree().quit(0)


func _comp(node: Node) -> InteractableComponent:
	for c: Node in node.find_children("*", "InteractableComponent", true, false):
		return c as InteractableComponent
	return node as InteractableComponent


func _run() -> void:
	rt = await HeistLauncher.launch(&"dockside_burn", _seed, Enums.Difficulty.ROUTINE, self, {"crew_ai": true})
	if rt == null:
		print("[PO14] RESULT FAIL no runtime")
		get_tree().quit(1)
		return
	note("cash_location %s" % rt.mission.variant(&"cash_location"))
	var lock: Node3D = rt.find_child("CountCagePadlock", true, false) as Node3D
	var gate: Door = rt.find_child("CountCageGate", true, false) as Door
	if lock == null or gate == null:
		print("[PO14] RESULT FAIL padlock %s gate %s" % [lock, gate])
		get_tree().quit(1)
		return
	for s: Node in rt.find_children("*", "Safe", true, false):
		if (s as Node3D).global_position.distance_to(gate.global_position) < SAFE_NEAR_M:
			note("SAFE NEAR THE GATE: %s at %s" % [s.get_path(), (s as Node3D).global_position])
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.combat = true
	await pilot.calibrate()
	await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	RenderingServer.render_loop_enabled = false
	var ic: InteractableComponent = _comp(lock)
	note("padlock at %s kind %s enabled %s; gate at %s open %s" % [lock.global_position, ic.kind if ic else &"-",
		ic.enabled if ic else false, gate.global_position, gate.is_open])
	var placed: Callable = func() -> bool: return StringName(lock.get(&"placed_kind")) != &"" or gate.is_open
	var t0: float = rt.heist_time_s
	while not placed.call() and rt.heist_time_s - t0 < 240.0:
		await pilot.use(ic, 40.0, placed)
	note("placed %s (kind %s, interactable now %s)" % [placed.call(), lock.get(&"placed_kind"), ic.kind])
	await shot("device_on_lock")
	var next_shot: float = rt.heist_time_s + 30.0
	while not gate.is_open and rt.heist_time_s - t0 < MAX_S:
		if ic.enabled and ic.kind == &"fix_drill":
			note("jammed: fixing")
			await pilot.use(ic, 20.0, func() -> bool: return ic.kind != &"fix_drill")
		await pilot.hold_position(2.0)
		if rt.heist_time_s >= next_shot:
			next_shot = rt.heist_time_s + 30.0
			await shot("running_t%03d" % int(rt.heist_time_s))
	await shot("gate")
	var ok: bool = gate.is_open and StringName(lock.get(&"beaten_by")) == &"drill"
	print("[PO14] ROW dockside_burn|seed %d|placed %s|beaten_by %s|gate open %s|%s" % [_seed, lock.get(&"placed_kind"),
		lock.get(&"beaten_by"), gate.is_open, "PASS" if ok else "FAIL"])
	RenderingServer.render_loop_enabled = true
	get_tree().quit(0 if ok else 1)
