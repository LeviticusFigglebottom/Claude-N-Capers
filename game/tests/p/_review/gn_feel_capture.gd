## GN-P1 windowed feel pass (next_heist.md §7.11, D-095): the first-person rifle at hip and in ADS at Gallery Night
## spots (Great Hall, BE balcony over the hall, the Treasury facing its laser grid, the reflecting pool, the loading
## dock, the Mews), real input for mask / ADS. Writes <out>/<spot>_<hip|ads>.png and <out>/gn_feel_sheet.png.
##   xvfb-run -a -s "-screen 0 640x360x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 640x360 --path game res://tests/p/_review/gn_feel_capture.tscn -- --out=/abs/dir
## Owner: ENV P.
extends Node

## [name, position, look-at]
const SPOTS: Array = [
	["hall", Vector3(22.0, 0.0, 24.0), Vector3(22.0, 1.6, 14.0)],
	["balcony", Vector3(29.6, 5.4, 21.0), Vector3(20.0, 2.0, 21.0)],
	["treasury", Vector3(40.0, 5.4, 25.0), Vector3(40.0, 6.6, 29.5)],
	["pool", Vector3(-9.5, 0.0, 12.5), Vector3(-9.5, 0.5, 20.0)],
	["dock", Vector3(36.5, 0.0, 2.0), Vector3(36.5, 1.5, 8.0)],
	["mews", Vector3(26.0, 0.0, -5.0), Vector3(36.0, 1.5, -2.0)],
]

var _out: String = "user://gn_feel"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = &"weapon.corsair_ar"
	l.primary_mods = [] as Array[StringName]
	l.resolved_primary = LoadoutResolver.resolve_weapon(l.primary, l.primary_mods)
	var rt: HeistRuntime = await HeistLauncher.launch(&"gallery_night", 1104, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "ai_teammates": 0, "loadouts": {0: l}})
	rt.isolate_npc(null)
	var tr: PTraversal = PTraversal.new(self, rt)
	tr.inp.capture_mouse()
	await tr.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await tr.inp.tap(&"slot_primary")
	await _ticks(90)
	var imgs: Array[Image] = []
	for s: Array in SPOTS:
		await tr.place(s[1], s[2])
		var c: CrewController = rt.crew_controller(0) as CrewController
		var d: Vector3 = (s[2] as Vector3) - c.eye_position()
		await tr.turn_to_pitch(atan2(d.y, Vector2(d.x, d.z).length()))
		await _ticks(40)
		imgs.append(await _shot("%s_hip" % s[0]))
		tr.inp.press(&"aim")
		await _ticks(50)
		imgs.append(await _shot("%s_ads" % s[0]))
		tr.inp.release(&"aim")
		await _ticks(30)
	_sheet(imgs)
	print("[GNF] RESULT DONE %d frames %s/gn_feel_sheet.png" % [imgs.size(), _out])
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
	var sheet: Image = Image.create(w * 2, h * ceili(imgs.size() / 2.0), false, Image.FORMAT_RGBA8)
	for k: int in imgs.size():
		var img: Image = imgs[k].duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((k % 2) * w, (k / 2) * h))
	sheet.save_png(PCaptureName.safe_path("%s/gn_feel_sheet.png" % _out))


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame
