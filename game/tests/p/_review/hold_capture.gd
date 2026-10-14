## PO-13 weapon hold / ADS capture (windowed): per weapon class, real input on the unit map, one frame per pose:
## hip (idle), hip while turning (mouse moving right), walk (mid-stride), sprint, ADS mid-transition, ADS settled.
## Writes <out>/<weapon>_<pose>.png and <out>/hold_sheet.png (rows = weapons, cols = poses).
##   xvfb-run -a -s "-screen 0 640x360x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 640x360 --path game res://tests/p/_review/hold_capture.tscn -- --out=/abs/dir \
##     [--weapons=weapon.kestrel_p9,...] [--heist=glasshouse]   (a lit map behind the silhouette; default unit map)
## Owner: ENV P.
extends Node

const POSES: PackedStringArray = ["hip", "turn", "walk", "sprint", "ads_mid", "ads"]

var _out: String = "user://hold_capture"
var _heist: StringName = &""
var _weapons: PackedStringArray = ["weapon.kestrel_p9", "weapon.hornet_9", "weapon.corsair_ar", "weapon.mule_12",
	"weapon.anvil_lmg", "weapon.heron_308"]


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"weapons": _weapons = v.split(",")
			"heist": _heist = StringName(v)
	DirAccess.make_dir_recursive_absolute(_out)
	var rows: Array[Array] = []
	for wid: String in _weapons:
		rows.append(await _weapon(StringName(wid)))
	_sheet(rows)
	print("[HOLD] RESULT DONE weapons=%d sheet=%s/hold_sheet.png" % [rows.size(), _out])
	get_tree().quit(0)


func _weapon(wid: StringName) -> Array:
	var def: WeaponDef = ContentDB.weapon(wid)
	var secondary: bool = def != null and def.slot == Enums.WeaponSlot.SECONDARY
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	if secondary:
		l.secondary = wid
		l.secondary_mods = [] as Array[StringName]
		l.resolved_secondary = LoadoutResolver.resolve_weapon(wid, l.secondary_mods)
	else:
		l.primary = wid
		l.primary_mods = [] as Array[StringName]
		l.resolved_primary = LoadoutResolver.resolve_weapon(wid, l.primary_mods)
	var rt: HeistRuntime = null
	if _heist == &"":
		rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
			{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	else:  # a lit street behind the silhouette (the crew's own spawn)
		rt = await HeistLauncher.launch(_heist, 1002, Enums.Difficulty.ROUTINE, self,
			{"ai_teammates": 0, "crew_ai": false, "loadouts": {0: l}})
		rt.isolate_npc(null)
	var c: CrewController = rt.crew_controller(0) as CrewController
	if _heist == &"":
		rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 10)))
	var inp: PInputDriver = PInputDriver.new(self)
	inp.capture_mouse()
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await inp.tap(&"slot_secondary" if secondary else &"slot_primary")
	await _ticks(120)
	var imgs: Array[Image] = []
	imgs.append(await _shot(wid, "hip"))
	for _k: int in 12:  # steady turn right (~40 px per frame)
		inp.look(40.0, 0.0)
		await _ticks(1)
	imgs.append(await _shot(wid, "turn"))
	await _ticks(60)
	inp.press(&"move_forward")
	await _ticks(50)
	imgs.append(await _shot(wid, "walk"))
	inp.press(&"sprint")
	await _ticks(50)
	imgs.append(await _shot(wid, "sprint"))
	inp.release(&"sprint")
	inp.release(&"move_forward")
	await _ticks(60)
	inp.press(&"aim")
	await _ticks(6)
	imgs.append(await _shot(wid, "ads_mid"))
	await _ticks(60)
	imgs.append(await _shot(wid, "ads"))
	inp.release_all()
	rt.teardown()
	for _i: int in 3:
		await get_tree().process_frame
	return imgs


func _shot(wid: StringName, pose: String) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [_out, String(wid).trim_prefix("weapon."), pose])
	return img


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _sheet(rows: Array[Array]) -> void:
	if rows.is_empty() or (rows[0] as Array).is_empty():
		return
	var cell: Image = (rows[0] as Array)[0]
	var half: bool = cell.get_width() > 400  # full-size cells from a small window (--resolution 320x180)
	var w: int = cell.get_width() / 2 if half else cell.get_width()
	var h: int = cell.get_height() / 2 if half else cell.get_height()
	var sheet: Image = Image.create(w * POSES.size(), h * rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in (rows[y] as Array).size():
			var img: Image = ((rows[y] as Array)[x] as Image).duplicate() as Image
			img.convert(Image.FORMAT_RGBA8)
			img.resize(w, h, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(x * w, y * h))
	sheet.save_png("%s/hold_sheet.png" % _out)
