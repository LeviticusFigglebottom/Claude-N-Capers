## PO-7 windowed check (LEAD 2026-10-17): NPC muzzle flashes must not freeze in the air (C e22dfbd8). Dockside Burn,
## direct launch (stated shortcut: no menus), Po5Pilot real input only: mask up, walk into the cartel yard and let the
## gunmen fire (the pilot fights back). Rendering stays ON the whole time (the fix holds a flash until a drawn frame,
## so po5 fast mode would hold every flash). Every physics tick: each MuzzleFlash under a MuzzleFx that stays flashing
## (or its sparks visible) for more than STUCK_S of game time is a "[FLASH] STUCK" row. Screenshots every SHOT_S.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/flash_check.tscn -- --out=/abs/dir [--seed=1792194538] [--secs=25]
## Owner: ENV P.
extends Node

const STUCK_S: float = 1.0
const SHOT_S: float = 5.0
const YARD: Array[Vector3] = [Vector3(33.8, 0.0, -36.0), Vector3(52.0, 0.0, -23.8), Vector3(46.4, 0.0, 28.0)]

var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var runner_out: String = ""
var _seed: int = 1792194538
var _secs: float = 25.0
var _shown: Dictionary = {}  # MuzzleFlash -> game seconds shown
var _stuck: Dictionary = {}
var _flashes: int = 0
var _shot: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": runner_out = v
			"seed": _seed = v.to_int()
			"secs": _secs = v.to_float()
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/flash_check"
	DirAccess.make_dir_recursive_absolute(runner_out)
	_run.call_deferred()


func note(msg: String) -> void:
	print("[FLASH t=%.1f] %s" % [rt.heist_time_s if rt != null else -1.0, msg])


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [runner_out, _shot, label])


func _physics_process(delta: float) -> void:
	if rt == null:
		return
	for fx: Node in rt.get_tree().root.find_children("*", "MuzzleFx", true, false):
		for c: Node in fx.get_children():
			var mf: MuzzleFlash = c as MuzzleFlash
			if mf == null:
				continue
			var sparks: Node3D = mf.get_node_or_null(^"Sparks") as Node3D
			var on: bool = mf.is_flashing() or (sparks != null and sparks.visible)
			if not on:
				_shown.erase(mf)
				continue
			if not _shown.has(mf):
				_flashes += 1
			_shown[mf] = float(_shown.get(mf, 0.0)) + delta
			if float(_shown[mf]) > STUCK_S and not _stuck.has(mf):
				_stuck[mf] = true
				note("STUCK %s at %s shown %.2f s (frames drawn %d)" % [mf.get_path(), mf.global_position, _shown[mf],
					Engine.get_frames_drawn()])


func _run() -> void:
	rt = await HeistLauncher.launch(&"dockside_burn", _seed, Enums.Difficulty.ROUTINE, self, {"crew_ai": true})
	if rt == null:
		print("[FLASH] RESULT FAIL no runtime")
		get_tree().quit(1)
		return
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.combat = true
	await pilot.calibrate()
	await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	note("masked %s at %s" % [c.masked, c.global_position])
	var t0: float = rt.heist_time_s
	var next_shot: float = t0
	var i: int = 0
	while rt.heist_time_s - t0 < _secs:
		if rt.heist_time_s >= next_shot:
			next_shot = rt.heist_time_s + SHOT_S
			await shot("t%03d" % int(rt.heist_time_s))
		var foe: NpcBase = pilot.nearest_enemy(40.0)
		if foe != null:
			await pilot.engage(foe, 2.0)
		else:
			await pilot.goto(YARD[i % YARD.size()], 1.0, 4.0)
			if pilot.flat_dist(c.global_position, YARD[i % YARD.size()]) < 1.5:
				i += 1
	note("RESULT %s: %d flashes seen, %d stuck > %.1f s, frames drawn %d" % ["PASS" if _stuck.is_empty() else "FAIL",
		_flashes, _stuck.size(), STUCK_S, Engine.get_frames_drawn()])
	await shot("end")
	print("[FLASH] RESULT %s" % ("PASS" if _stuck.is_empty() else "FAIL"))
	get_tree().quit(0 if _stuck.is_empty() else 1)
