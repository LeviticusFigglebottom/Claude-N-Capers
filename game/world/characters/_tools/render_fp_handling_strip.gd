## D-116 follow-up (organic FP handling): a windowed frame strip of the first-person reload and draw per weapon, in
## a lit heist (Glasshouse by default), with real input. Every STEP_TICKS physics ticks one frame is saved. Writes
## <out>/<weapon>/<phase>_NN.png and <out>/<weapon>_strip.png (rows = reload, draw; frames left to right).
##   xvfb-run -a -s "-screen 0 640x360x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 640x360 --path game res://world/characters/_tools/render_fp_handling_strip.tscn \
##     -- --out=/abs/dir [--weapons=weapon.kestrel_p9,...] [--heist=glasshouse] [--step=6] [--reload_s=2.6]
##     [--actions=idle,melee,melee_charge,throw]: idle = 0.5 s of the hip hold; a quick melee (tap), a charged melee
##     (held 1 s, released) and a throw (held 0.4 s, released) with --melee (melee.folding_knife) and --throwable
##     (throwable.frag) in the loadout
##     heavy_idle / heavy_charge (characters v1.38 melee_heavy review, before B's sledgehammer model lands): the loadout
##     melee is melee.sledgehammer, its MeleeDef switched IN MEMORY to anim_set melee_heavy with a stand-in two-handed
##     prop (0.9 m handle from -0.33 to +0.55 on Godot +Y, a head at +0.55; identity on the weapon bone);
##     heavy_idle force-plays melee_heavy/idle with the prop, heavy_charge holds melee 1.3 s (frames over the last 0.3 s)
##     and releases (the strike every tick)
## Owner: ENV D.
extends Node

var _out: String = "user://fp_handling_strip"
var _weapons: PackedStringArray = ["weapon.kestrel_p9", "weapon.corsair_ar", "weapon.hornet_9", "weapon.mule_12"]
var _heist: StringName = &"glasshouse"
var _step: int = 6
var _reload_s: float = 2.6
var _draw_s: float = 1.0
## --actions: the rows to capture instead of reload / draw (empty = reload, draw)
var _actions: PackedStringArray = []
var _melee: StringName = &"melee.folding_knife"
var _throwable: StringName = &"throwable.frag"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"weapons": _weapons = v.split(",")
			"heist": _heist = StringName(v)
			"step": _step = int(v)
			"reload_s": _reload_s = float(v)
			"actions": _actions = v.split(",")
			"melee": _melee = StringName(v)
			"throwable": _throwable = StringName(v)
	DirAccess.make_dir_recursive_absolute(_out)
	RenderingServer.render_loop_enabled = false   # llvmpipe: render only the saved frames
	for wid: String in _weapons:
		await _weapon(StringName(wid))
	RenderingServer.render_loop_enabled = true
	print("[STRIP] RESULT DONE %s" % _out)
	get_tree().quit(0)


func _weapon(wid: StringName) -> void:
	var def: WeaponDef = ContentDB.weapon(wid)
	var secondary: bool = def != null and def.slot == Enums.WeaponSlot.SECONDARY
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	if secondary:
		l.secondary = wid
		l.secondary_mods = [] as Array[StringName]
		l.resolved_secondary = LoadoutResolver.resolve_weapon(wid, l.secondary_mods)
		if l.primary == &"":   # the default loadout carries no primary: something to swap to for the draw
			l.primary = &"weapon.corsair_ar"
			l.primary_mods = [] as Array[StringName]
			l.resolved_primary = LoadoutResolver.resolve_weapon(l.primary, l.primary_mods)
	else:
		l.primary = wid
		l.primary_mods = [] as Array[StringName]
		l.resolved_primary = LoadoutResolver.resolve_weapon(wid, l.primary_mods)
	if not _actions.is_empty():
		l.melee = _melee
		l.throwable = _throwable
	var heavy: bool = false
	for act: String in _actions:
		heavy = heavy or act.begins_with("heavy_")
	if heavy:
		l.melee = &"melee.sledgehammer"
		var md: MeleeDef = ContentDB.melee(l.melee)
		if md != null:   # in memory only, this run: the v1.38 two-handed set with the stand-in prop
			md.anim_set = &"melee_heavy"
			md.model = _heavy_prop()
	var rt: HeistRuntime = await HeistLauncher.launch(_heist, 1002, Enums.Difficulty.ROUTINE, self,
			{"ai_teammates": 0, "crew_ai": false, "loadouts": {0: l}})
	rt.isolate_npc(null)
	var wname: String = String(wid).trim_prefix("weapon.")
	DirAccess.make_dir_recursive_absolute("%s/%s" % [_out, wname])
	var inp: PInputDriver = PInputDriver.new(self)
	inp.capture_mouse()
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	var own: StringName = &"slot_secondary" if secondary else &"slot_primary"
	var other: StringName = &"slot_primary" if secondary else &"slot_secondary"
	await inp.tap(own)
	await _ticks(90)
	if not _actions.is_empty():
		await _action_rows(inp, wname)
		inp.release_all()
		rt.teardown()
		for _i: int in 3:
			await get_tree().process_frame
		return
	for _i: int in 3:   # a partly spent magazine: the tactical reload
		await inp.tap(&"fire")
		await _ticks(20)
	await _ticks(40)
	var rows: Array[Array] = []
	await inp.tap(&"reload")
	rows.append(await _frames(wname, "reload", _reload_s))
	await _ticks(30)
	await inp.tap(other)
	await _ticks(150)
	await inp.tap(own)
	rows.append(await _frames(wname, "draw", _draw_s))
	_sheet(rows, "%s/%s_strip.png" % [_out, wname])
	inp.release_all()
	rt.teardown()
	for _i: int in 3:
		await get_tree().process_frame


## The --actions rows: real input, frames every --step ticks.
func _action_rows(inp: PInputDriver, wname: String) -> void:
	var rows: Array[Array] = []
	for act: String in _actions:
		match act:
			"idle":   # the hip hold as drawn (thumb / grip review)
				rows.append(await _frames(wname, act, 0.5))
			"melee":
				await inp.tap(&"melee")
				rows.append(await _frames(wname, act, 1.0))
			"melee_charge":
				inp.press(&"melee")
				var held: Array[Image] = await _frames(wname, act + "_hold", 1.0)
				inp.release(&"melee")
				held.append_array(await _frames(wname, act + "_swing", 0.8))
				rows.append(held)
			"heavy_idle":
				var fp: Node = get_tree().root.find_child("FpViewmodel", true, false)
				var md: MeleeDef = ContentDB.melee(&"melee.sledgehammer")
				if fp != null and md != null and fp.call(&"supports", &"melee_heavy"):
					var segs: Array[Dictionary] = []
					fp.call(&"_add_seg", segs, &"melee_heavy", &"idle", 3.0, 1.0)
					fp.call(&"_start_item", FpViewmodel.Action.MELEE, segs, md.model)
				await _ticks(20)
				rows.append(await _frames(wname, act, 0.3))
			"heavy_charge":
				inp.press(&"melee")
				await _ticks(60)
				var hv: Array[Image] = await _frames(wname, act + "_hold", 0.3)
				inp.release(&"melee")
				var keep: int = _step
				_step = 1   # the strike at every tick (the hit lands within ~0.3 s of the release)
				hv.append_array(await _frames(wname, act + "_strike", 0.4))
				_step = keep
				hv.append_array(await _frames(wname, act + "_swing", 0.6))
				rows.append(hv)
			"throw":
				inp.press(&"throw_item")
				var aim: Array[Image] = await _frames(wname, act + "_hold", 0.4)
				inp.release(&"throw_item")
				aim.append_array(await _frames(wname, act + "_release", 1.2))
				rows.append(aim)
		await _ticks(120)
	_sheet(rows, "%s/%s_actions.png" % [_out, wname])


## The stand-in two-handed prop (Godot item axes): a 0.85 m handle on +Y from -0.33 to +0.52 and an 8 x 8 x 22 cm
## head from +0.52 to +0.60, long along the striking direction (Z).
func _heavy_prop() -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "HeavyProp"
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.45, 0.32)
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.62, 0.64, 0.67)
	steel.metallic = 0.6
	steel.roughness = 0.35
	var handle: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.017
	cyl.bottom_radius = 0.017
	cyl.height = 0.85
	cyl.material = wood
	handle.mesh = cyl
	handle.position = Vector3(0.0, 0.095, 0.0)
	handle.name = "Handle"
	var head: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.22)
	box.material = steel
	head.mesh = box
	head.position = Vector3(0.0, 0.56, 0.0)
	head.name = "Head"
	root.add_child(handle)
	root.add_child(head)
	handle.owner = root
	head.owner = root
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func _frames(wname: String, phase: String, seconds: float) -> Array[Image]:
	var out: Array[Image] = []
	var n: int = int(ceil(seconds * Engine.physics_ticks_per_second / float(_step)))
	for i: int in n:
		var img: Image = await _shot()
		img.save_png("%s/%s/%s_%02d.png" % [_out, wname, phase, i])
		out.append(img)
		await _ticks(_step)
	return out


func _shot() -> Image:
	RenderingServer.render_loop_enabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	return img


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


## Rows of frames cropped to the viewmodel (the right / lower part of the screen) at full size, wrapped every
## COLS frames.
func _sheet(rows: Array[Array], path: String) -> void:
	const COLS: int = 8
	var fw: int = (rows[0][0] as Image).get_width()
	var fh: int = (rows[0][0] as Image).get_height()
	var crop: Rect2i = Rect2i(int(fw * 0.3), int(fh * 0.25), fw - int(fw * 0.3), fh - int(fh * 0.25))
	var w: int = crop.size.x * 3 / 4
	var h: int = crop.size.y * 3 / 4
	var lines: int = 0
	for r: Array in rows:
		lines += ceili(r.size() / float(COLS))
	var sheet: Image = Image.create(w * COLS, h * lines, false, Image.FORMAT_RGB8)
	var y: int = 0
	for r: Array in rows:
		for i: int in r.size():
			var img: Image = (r[i] as Image).get_region(crop)
			img.convert(Image.FORMAT_RGB8)
			img.resize(w, h)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((i % COLS) * w, (y + i / COLS) * h))
		y += ceili(r.size() / float(COLS))
	sheet.save_png(path)
