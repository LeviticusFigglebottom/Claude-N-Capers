## P-FP-STATES windowed review: one frame per first-person state on the dev_sandbox yard (lit, props in view):
## normal, downed (settled), tased (two frames), kicked (settled on the floor), a health hit at its peak.
## Writes <out>/<state>.png and <out>/fp_states_sheet.png.
##   xvfb-run -a -s "-screen 0 640x360x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 640x360 --path game res://tests/p/_review/fp_states_capture.tscn -- --out=/abs/dir
## Owner: ENV P.
extends Node

const SHOTS: PackedStringArray = ["normal", "downed", "tased_a", "tased_b", "kicked", "hit"]

var _out: String = "user://fp_states"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"dev_sandbox", 4401, Enums.Difficulty.ROUTINE, self,
		{"skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	rt.isolate_npc(null)
	var c: CrewController = rt.crew_controller(0) as CrewController
	c.set_masked(true)
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(6.0, 0.05, 11.0)))  # facing the building across the yard
	await _ticks(90)
	var imgs: Array[Image] = []
	imgs.append(await _shot("normal"))
	c.health.go_down()
	await _ticks(60)
	imgs.append(await _shot("downed"))
	c.health.revive(1)
	await _ticks(60)
	c.health.incapacitate(Enums.CrewState.TASED)
	await _ticks(30)
	imgs.append(await _shot("tased_a"))
	await _ticks(3)
	imgs.append(await _shot("tased_b"))
	c.health.revive(1)
	await _ticks(60)
	c.health.incapacitate(Enums.CrewState.CLOAKER_DOWNED)
	await _ticks(90)
	imgs.append(await _shot("kicked"))
	c.health.revive(1)
	await _ticks(90)
	EventBus.damage_applied.emit(c.net_id, 0, {"amount": 20.0, "health_damage": 20.0, "armor_damage": 0.0,
		"direction": c.global_transform.basis.x})
	await _ticks(2)  # ~ the punch peak (1 / fp_hit_punch_hz)
	imgs.append(await _shot("hit"))
	_sheet(imgs)
	print("[FPS] RESULT DONE %d frames %s/fp_states_sheet.png" % [imgs.size(), _out])
	rt.teardown()
	get_tree().quit(0)


func _shot(nm: String) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(PCaptureName.safe_path("%s/%s.png" % [_out, nm]))
	return img


func _sheet(imgs: Array[Image]) -> void:
	var w: int = 320
	var h: int = 180
	var cols: int = 3
	var sheet: Image = Image.create(w * cols, h * ceili(imgs.size() / float(cols)), false, Image.FORMAT_RGBA8)
	for k: int in imgs.size():
		var img: Image = imgs[k].duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((k % cols) * w, (k / cols) * h))
	sheet.save_png(PCaptureName.safe_path("%s/fp_states_sheet.png" % _out))


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame
