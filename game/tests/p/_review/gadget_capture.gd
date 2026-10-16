## D-118 gadget capture (windowed): a lit heist, the given weapons with WeaponStats.gadgets forced to laser +
## flashlight (until ENV B's gadget mods land), real input toggles them; frames: off, on at hip, on aimed.
## Writes <out>/<weapon>_<off|hip|ads>.png and <out>/gadget_sheet.png.
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 960x540 --path game res://tests/p/_review/gadget_capture.tscn -- --out=/abs/dir \
##     [--heist=glasshouse] [--weapons=weapon.corsair_ar,weapon.kestrel_p9]
##     [--mods=weapon.kestrel_p9:mod.rail_combo,...]   real gadget mods (then WeaponStats.gadgets is not forced)
##     [--at=x,y,z,yaw_deg]   stand there (teleport) facing yaw (0 = -Z), e.g. ND basement spine B5:
##                            --heist=night_deposit --at=3.5,-4.0,6.75,-90
## Owner: ENV P.
extends Node

var _out: String = "user://gadget_capture"
var _heist: StringName = &"glasshouse"
var _weapons: PackedStringArray = ["weapon.corsair_ar", "weapon.kestrel_p9"]
var _mods: PackedStringArray = []
## Optional stand point (x, y, z, yaw degrees); empty = the spawn.
var _at: PackedFloat64Array = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"heist": _heist = StringName(v)
			"weapons": _weapons = v.split(",")
			"mods": _mods = v.split(",", false)
			"at": _at = v.split_floats(",")
	DirAccess.make_dir_recursive_absolute(_out)
	RenderingServer.render_loop_enabled = false
	var rows: Array[Array] = []
	for wid: String in _weapons:
		rows.append(await _weapon(StringName(wid)))
	var w: int = 480
	var h: int = 270
	var sheet: Image = Image.create(w * 3, h * rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		for x: int in (rows[y] as Array).size():
			var img: Image = ((rows[y] as Array)[x] as Image).duplicate() as Image
			img.convert(Image.FORMAT_RGBA8)
			img.resize(w, h, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(x * w, y * h))
	sheet.save_png("%s/gadget_sheet.png" % _out)
	RenderingServer.render_loop_enabled = true
	print("[GADGET] RESULT DONE weapons=%d sheet=%s/gadget_sheet.png" % [rows.size(), _out])
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
	var rt: HeistRuntime = await HeistLauncher.launch(_heist, 1002, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "loadouts": {0: l}})
	rt.isolate_npc(null)
	var c: CrewController = rt.crew_controller(0) as CrewController
	var inp: PInputDriver = PInputDriver.new(self)
	inp.capture_mouse()
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await inp.tap(&"slot_secondary" if secondary else &"slot_primary")
	if _at.size() >= 3:
		rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(_at[0], _at[1] + 0.05, _at[2])))
		await _ticks(10)
		if _at.size() >= 4:
			await inp.turn_to_yaw(c, deg_to_rad(_at[3]))
	await _ticks(90)
	var st: WeaponStats = c.weapons.stats(c.weapons.equipped_slot)
	if mods.is_empty():
		st.gadgets = [&"laser", &"flashlight"] as Array[StringName]  # no gadget mod given: force both (Muzzle origin)
	print("[GADGET] %s mods=%s gadgets=%s laser_origin=%s" % [wid, mods, st.gadgets,
		(c.weapon_visual as WeaponVisual).get_marker(&"LaserOrigin") != null])
	for _k: int in 6:
		inp.look(0.0, 30.0)
		await _ticks(1)
	await _ticks(20)
	var name: String = String(wid).trim_prefix("weapon.")
	var imgs: Array[Image] = [await _shot(name, "off")]
	await inp.tap(&"gadget_toggle")
	await _ticks(10)
	imgs.append(await _shot(name, "hip"))
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
	if vm != null and vm.gadgets != null:
		print("[GADGET] %s hip laser=%s light=%s end=%s in_tree=%s cam=%s" % [name, vm.gadgets.laser_visible,
			vm.gadgets.light_visible, vm.gadgets.laser_end, vm.gadgets.is_inside_tree(),
			CrewView.of(c).camera().global_position])
	inp.press(&"aim")
	await _ticks(50)
	imgs.append(await _shot(name, "ads"))
	inp.release_all()
	rt.teardown()
	for _i: int in 3:
		await get_tree().process_frame
	return imgs


func _shot(name: String, label: String) -> Image:
	RenderingServer.render_loop_enabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	img.save_png("%s/%s_%s.png" % [_out, name, label])
	return img


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame
