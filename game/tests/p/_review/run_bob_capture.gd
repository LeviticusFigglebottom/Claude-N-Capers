## PO-20 / D-145 windowed run-bob capture: the local crew (masked, hip, default loadout) on the unit map walks 2 s, sprints
## 4 s, stops 1 s, by real input (PInputDriver W / sprint). Run under Godot's movie maker for an exact 60 fps clip:
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     --fixed-fps 60 --write-movie /abs/dir/frames/f.png res://tests/p/_review/run_bob_capture.tscn -- --out=/abs/dir
## Prints per-phase "[RUNBOB] ROW phase|frames|head p2p x/y mm roll deg|vm p2p x/y mm pitch/roll deg|vm max step mm/deg"
## (p2p = peak to peak over the phase; max step = the largest frame-to-frame change: a snap). Frame numbers of each
## phase start go to phases.txt so the clip can be cut. Stated shortcut: direct launch on the unit map. Owner: ENV P.
extends Node

var rt: HeistRuntime = null
var runner_out: String = ""
var _c: CrewController = null
var _vm: FpViewmodel = null
var _phase: String = ""
var _samples: Dictionary = {}  # phase -> Array[PackedFloat32Array]
var _frame: int = 0
var _marks: PackedStringArray = PackedStringArray()


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			runner_out = kv[1]
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/run_bob"
	DirAccess.make_dir_recursive_absolute(runner_out)
	_run.call_deferred()


func _process(_delta: float) -> void:
	_frame += 1
	if _phase == "" or _c == null or _vm == null:
		return
	var head: Node3D = _c.get_node(^"Head") as Node3D
	var s: PackedFloat32Array = PackedFloat32Array([head.position.x * 1000.0, head.position.y * 1000.0,
		rad_to_deg(head.rotation.z), _vm.position.x * 1000.0, _vm.position.y * 1000.0, _vm.rotation_degrees.x,
		_vm.rotation_degrees.z])
	if not _samples.has(_phase):
		_samples[_phase] = []
	(_samples[_phase] as Array).append(s)


func _mark(p: String) -> void:
	_phase = p
	_marks.append("%s %d" % [p, _frame])


func _secs(s: float) -> void:
	for _i: int in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _run() -> void:
	rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_c = rt.crew_controller(Net.local_slot()) as CrewController
	var inp: PInputDriver = PInputDriver.new(self)
	inp.capture_mouse()
	await _secs(0.5)
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	rt.teleport_crew(_c.slot, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 12)))
	await _secs(1.0)
	for n: Node in _c.find_children("*", "FpViewmodel", true, false):
		_vm = n as FpViewmodel
	_mark("stand")
	await _secs(1.0)
	inp.press(&"move_forward")
	_mark("walk")
	await _secs(2.0)
	inp.press(&"sprint")
	_mark("sprint_in")
	await _secs(0.6)
	_mark("sprint")
	await _secs(3.4)
	inp.release(&"sprint")
	inp.release(&"move_forward")
	_mark("stop")
	await _secs(1.0)
	_phase = ""
	for p: String in ["stand", "walk", "sprint_in", "sprint", "stop"]:
		_report(p)
	var f: FileAccess = FileAccess.open(runner_out + "/phases.txt", FileAccess.WRITE)
	f.store_string("\n".join(_marks) + "\n")
	f.close()
	get_tree().quit(0)


func _report(p: String) -> void:
	var rows: Array = _samples.get(p, [])
	if rows.is_empty():
		print("[RUNBOB] ROW %s|0" % p)
		return
	var lo: PackedFloat32Array = (rows[0] as PackedFloat32Array).duplicate()
	var hi: PackedFloat32Array = lo.duplicate()
	var step: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0, 0])
	for k: int in rows.size():
		var s: PackedFloat32Array = rows[k]
		for j: int in s.size():
			lo[j] = minf(lo[j], s[j])
			hi[j] = maxf(hi[j], s[j])
			if k > 0:
				step[j] = maxf(step[j], absf(s[j] - (rows[k - 1] as PackedFloat32Array)[j]))
	var p2p: PackedFloat32Array = PackedFloat32Array()
	for j: int in lo.size():
		p2p.append(hi[j] - lo[j])
	print("[RUNBOB] ROW %s|%d|head x %.1f y %.1f mm roll %.2f deg|vm x %.1f y %.1f mm pitch %.2f roll %.2f deg|" % [p,
		rows.size(), p2p[0], p2p[1], p2p[2], p2p[3], p2p[4], p2p[5], p2p[6]]
		+ "step head %.2f/%.2f mm %.3f deg vm %.2f/%.2f mm %.3f/%.3f deg" % [step[0], step[1], step[2], step[3], step[4],
		step[5], step[6]])
