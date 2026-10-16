## PO-13 weapon hold / ADS capture (windowed): per weapon class, real input on the unit map, one frame per pose:
## hip (idle), hip while turning (mouse moving right), walk (mid-stride), sprint, ADS mid-transition, ADS settled.
## Writes <out>/<weapon>_<pose>.png and <out>/hold_sheet.png (rows = weapons, cols = poses).
##   xvfb-run -a -s "-screen 0 640x360x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 640x360 --path game res://tests/p/_review/hold_capture.tscn -- --out=/abs/dir \
##     [--weapons=weapon.kestrel_p9,...] [--heist=glasshouse]   (a lit map behind the silhouette; default unit map)
##     [--mods=weapon.corsair_ar:mod.corsair_vertical_grip,...]   mods per weapon (weapon:mod pairs)
##     [--closeup]   also <out>/closeup_sheet.png: hip and ADS seen from below / left / right of the support hand
##                   (a review camera on the weapon's LeftHandIK marker that sees the viewmodel layers; finger clipping)
## Owner: ENV P.
extends Node

const POSES: PackedStringArray = ["hip", "turn", "walk", "sprint", "ads_mid", "ads"]
## Close-up review cameras, in LeftHandIK marker (= weapon) space: name -> [eye offset, up axis index (1 y, 2 z)].
const CLOSE_VIEWS: Dictionary = {"below": [Vector3(0.04, -0.24, 0.06), 2], "left": [Vector3(-0.26, 0.03, 0.02), 1],
	"right": [Vector3(0.26, 0.03, 0.02), 1]}

var _out: String = "user://hold_capture"
var _heist: StringName = &""
var _closeup: bool = false
var _mods: PackedStringArray = []
var _close_rows: Array[Array] = []
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
			"closeup": _closeup = true
			"mods": _mods = v.split(",", false)
	DirAccess.make_dir_recursive_absolute(_out)
	# Like A's PO-5 fast mode: llvmpipe renders a lit heist at minutes per frame, so the render loop is off between
	# shots (physics, animation and input stay real; _shot() renders the frame it saves).
	RenderingServer.render_loop_enabled = false
	var rows: Array[Array] = []
	for wid: String in _weapons:
		rows.append(await _weapon(StringName(wid)))
	_sheet(rows)
	if _closeup:
		_sheet(_close_rows, "closeup_sheet.png")
	RenderingServer.render_loop_enabled = true
	print("[HOLD] RESULT DONE weapons=%d sheet=%s/hold_sheet.png" % [rows.size(), _out])
	get_tree().quit(0)


func _weapon(wid: StringName) -> Array:
	var def: WeaponDef = ContentDB.weapon(wid)
	var secondary: bool = def != null and def.slot == Enums.WeaponSlot.SECONDARY
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	var mods: Array[StringName] = []
	for pair: String in _mods:
		var wm: PackedStringArray = pair.split(":")
		if wm.size() == 2 and StringName(wm[0]) == wid:
			mods.append(StringName(wm[1]))
	if secondary:
		l.secondary = wid
		l.secondary_mods = mods
		l.resolved_secondary = LoadoutResolver.resolve_weapon(wid, l.secondary_mods)
	else:
		l.primary = wid
		l.primary_mods = mods
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
	var close: Array[Image] = []
	imgs.append(await _shot(wid, "hip"))
	if _closeup:
		close.append_array(await _close_shots(wid, c, "hip"))
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
	if _closeup:
		close.append_array(await _close_shots(wid, c, "ads"))
		_close_rows.append(close)
	inp.release_all()
	rt.teardown()
	for _i: int in 3:
		await get_tree().process_frame
	return imgs


func _shot(wid: StringName, pose: String) -> Image:
	RenderingServer.render_loop_enabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	img.save_png("%s/%s_%s.png" % [_out, String(wid).trim_prefix("weapon."), pose])
	return img


## The support hand from below / left / right: a main-viewport camera that sees the viewmodel layers, on the
## weapon's LeftHandIK marker; the overlay canvases (HUD, viewmodel SubViewport) are hidden for these frames.
func _close_shots(wid: StringName, c: CrewController, pose: String) -> Array[Image]:
	var out: Array[Image] = []
	var wv: WeaponVisual = c.weapon_visual as WeaponVisual
	var marker: Node3D = wv.get_marker(&"LeftHandIK") if wv != null else null
	if marker == null:
		print("[HOLD] %s: no LeftHandIK marker, no close-ups" % wid)
		return out
	var cam: Camera3D = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.01
	cam.far = 10.0
	cam.cull_mask = 1 | CrewView.VIEWMODEL_LAYER | CrewView.VIEWMODEL_LIT_LAYER
	get_tree().root.add_child(cam)
	var prev: Camera3D = get_viewport().get_camera_3d()
	var hidden: Array[CanvasLayer] = []
	for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if (n as CanvasLayer).visible:
			(n as CanvasLayer).visible = false
			hidden.append(n as CanvasLayer)
	cam.current = true
	for view: String in CLOSE_VIEWS:
		var m: Transform3D = marker.global_transform.orthonormalized()
		var spec: Array = CLOSE_VIEWS[view]
		var up: Vector3 = m.basis.y if int(spec[1]) == 1 else -m.basis.z
		cam.global_position = m.origin + m.basis * (spec[0] as Vector3)
		cam.look_at(m.origin, up)
		out.append(await _shot(wid, "%s_%s" % [pose, view]))
	for cl: CanvasLayer in hidden:
		if is_instance_valid(cl):
			cl.visible = true
	if prev != null and is_instance_valid(prev):
		prev.current = true
	cam.queue_free()
	return out


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _sheet(rows: Array[Array], file: String = "hold_sheet.png") -> void:
	if rows.is_empty() or (rows[0] as Array).is_empty():
		return
	var cell: Image = (rows[0] as Array)[0]
	var half: bool = cell.get_width() > 400  # full-size cells from a small window (--resolution 320x180)
	var w: int = cell.get_width() / 2 if half else cell.get_width()
	var h: int = cell.get_height() / 2 if half else cell.get_height()
	var cols: int = 0
	for r: Array in rows:
		cols = maxi(cols, r.size())
	var sheet: Image = Image.create(w * cols, h * rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in (rows[y] as Array).size():
			var img: Image = ((rows[y] as Array)[x] as Image).duplicate() as Image
			img.convert(Image.FORMAT_RGBA8)
			img.resize(w, h, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(x * w, y * h))
	sheet.save_png("%s/%s" % [_out, file])
