## LEAD round 305: windowed confirm of PO-21 and PO-22 on trunk, through the real MenuFlow.
##   PO-21  main menu -> the 3D safehouse -> MenuFlow.launch (the Launch button's single path; stated shortcut: the
##          planning-table clicks) -> in the heist: no MouseCapture release held, wants_capture true, the OS mode, and
##          (when the OS captured) real mouse motion turns the camera. NO PlayerInput.test_assume_captured here (that
##          bypass would hide the bug).
##   PO-22  masked, hip vs aiming down sights: the HUD crosshair alpha and one shot each (before / after).
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --resolution 960x540 --path game \
##     res://tests/p/_review/po_confirm.tscn -- --out=/abs/dir [--heist=ostrander_federal]
## Rows: "[POC] ROW <item> | PASS|FAIL|NOTE | <detail>"; "[POC] RESULT".
## Owner: ENV P.
extends Node

const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")

var _out: String = "user://po_confirm"
var _heist: StringName = &"ostrander_federal"
var _ok: bool = true
var _inp: PInputDriver = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			_out = kv[1]
		elif kv[0] == "heist" and kv.size() > 1:
			_heist = StringName(kv[1])
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _shot(nm: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(PCaptureName.safe_path("%s/%s.png" % [_out, nm]))


func _row(item: String, good: bool, detail: String, note: bool = false) -> void:
	_ok = _ok and (good or note)
	print("[POC] ROW %s | %s | %s" % [item, "NOTE" if note else ("PASS" if good else "FAIL"), detail])


func _run() -> void:
	MouseCapture.reset()
	GameSettings.current().set_value(GameSettings.CONTROLS, &"safehouse_hub", "walk")
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await _frames(5)
	f.main_menu.safehouse_button.pressed.emit()
	await _frames(60)
	_row("in the 3D safehouse", f.safehouse.is_active(), "active %s" % f.safehouse.is_active())
	f.launch(_heist, Enums.Difficulty.ROUTINE, CrewWeapons.build_loadout(null), 2105)
	var t0: int = Time.get_ticks_msec()
	while (f.runtime == null or not is_instance_valid(f.runtime)) and Time.get_ticks_msec() - t0 < 900000:
		await _frames(10)
	var rt: HeistRuntime = f.runtime
	if rt == null:
		_row("heist launched from the safehouse", false, "no runtime after 900 s")
		_finish()
		return
	await _frames(120)
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	var held: Array[String] = []
	for k: StringName in [&"station", &"pause", &"options", &"payday", &"menu", &"chat", &"dropin"]:
		if MouseCapture.is_released(k):
			held.append(String(k))
	_row("PO-21: no MouseCapture release held in the heist", held.is_empty(), "held %s" % [held])
	_row("PO-21: wants_capture (gameplay owner, no release)", MouseCapture.wants_capture(), "wants %s, OS mode %d" % [
		MouseCapture.wants_capture(), Input.mouse_mode])
	_inp = PInputDriver.new(self)
	if MouseCapture.is_captured():
		var y0: float = c.look_yaw
		for _k: int in 10:
			_inp.look(20.0, 0.0)
			await _frames(1)
		await _frames(5)
		_row("PO-21: real mouse motion turns the camera", absf(c.look_yaw - y0) > 0.01, "yaw %.3f -> %.3f" % [y0, c.look_yaw])
	else:
		_row("PO-21: OS capture", false, "xvfb did not grant the capture (no WM focus): motion check skipped", true)
	await _shot("po21_in_heist")
	# PO-22: masked, hip vs ADS crosshair.
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await _frames(90)
	var hud: Hud = f.get("_hud") as Hud
	var hip_a: float = hud.crosshair.modulate.a if hud != null and hud.crosshair != null else -1.0
	await _shot("po22_hip")
	_inp.press(&"aim")
	await _frames(60)
	var ads_a: float = hud.crosshair.modulate.a if hud != null and hud.crosshair != null else -1.0
	var model: Object = rt.hud_model
	var blend: Variant = model.get(&"ads_blend") if model != null and &"ads_blend" in model else null
	await _shot("po22_ads")
	_inp.release(&"aim")
	_row("PO-22: crosshair shown at the hip (masked)", hip_a > 0.9, "alpha %.2f" % hip_a)
	_row("PO-22: crosshair hidden while aiming down sights", ads_a < 0.1, "alpha %.2f, model ads_blend %s" % [ads_a, blend])
	_finish()


func _finish() -> void:
	print("[POC] RESULT %s" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)
	await get_tree().create_timer(10.0, true, false, true).timeout
	OS.kill(OS.get_process_id())
