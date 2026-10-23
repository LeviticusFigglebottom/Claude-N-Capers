## D-115 queue 1: the six heister FP sleeve / glove variants under the one-handed pistol framing (D-116), hip and ADS,
## in the real viewmodel (FpViewmodel.apply_sleeves per heister; real input on the unit map). Look for a visible cuff
## edge or a texture seam at the wrist. Writes <out>/<heister>_<pose>.png and <out>/sleeve_pistol_sheet.png
## (rows = heisters, cols = hip, ADS).
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 960x540 --path game res://world/characters/_tools/render_sleeve_pistol_review.tscn \
##     -- --out=/abs/dir [--weapon=weapon.kestrel_p9]
## Owner: ENV D.
extends Node

const HEISTERS: Array[StringName] = [&"rook", &"sable", &"dutch", &"wren", &"marten", &"jay", &"juno", &"hale"]

var _out: String = "user://sleeve_pistol_review"
var _weapon: StringName = &"weapon.kestrel_p9"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"weapon": _weapon = StringName(v)
	DirAccess.make_dir_recursive_absolute(_out)
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.secondary = _weapon
	l.secondary_mods = [] as Array[StringName]
	l.resolved_secondary = LoadoutResolver.resolve_weapon(_weapon, l.secondary_mods)
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
			{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 10)))
	var inp: PInputDriver = PInputDriver.new(self)
	inp.capture_mouse()
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await inp.tap(&"slot_secondary")
	await _ticks(120)
	var vm: FpViewmodel = get_tree().root.find_children("*", "FpViewmodel", true, false)[0] as FpViewmodel
	var rows: Array[Array] = []
	for h: StringName in HEISTERS:
		var ok: bool = vm.apply_sleeves(h)
		print("[SLEEVE] %s variant=%s" % [h, ok])
		var row: Array[Image] = []
		await _ticks(10)
		row.append(await _shot(h, "hip"))
		inp.press(&"aim")
		await _ticks(60)
		row.append(await _shot(h, "ads"))
		inp.release(&"aim")
		await _ticks(60)
		rows.append(row)
	_sheet(rows)
	inp.release_all()
	rt.teardown()
	print("[SLEEVE] RESULT DONE %s/sleeve_pistol_sheet.png" % _out)
	get_tree().quit(0)


func _shot(h: StringName, pose: String) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [_out, h, pose])
	return img


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _sheet(rows: Array[Array]) -> void:
	if rows.is_empty():
		return
	var w: int = (rows[0][0] as Image).get_width() / 2
	var hh: int = (rows[0][0] as Image).get_height() / 2
	var sheet: Image = Image.create(w * rows[0].size(), hh * rows.size(), false, Image.FORMAT_RGB8)
	for r: int in rows.size():
		for c: int in rows[r].size():
			var img: Image = (rows[r][c] as Image).duplicate() as Image
			img.convert(Image.FORMAT_RGB8)
			img.resize(w, hh)
			sheet.blit_rect(img, Rect2i(0, 0, w, hh), Vector2i(c * w, r * hh))
	sheet.save_png("%s/sleeve_pistol_sheet.png" % _out)
