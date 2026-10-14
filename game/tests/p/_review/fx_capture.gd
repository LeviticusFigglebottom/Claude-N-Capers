## D-105 first-person weapon FX capture sheet (impact_fx.md Tests, P): fires one shot per weapon with real input
## and saves the frames right after it (burst, tracer, kick, casing), then one sheet of all of them. Windowed:
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 960x540 --path game res://tests/p/_review/fx_capture.tscn -- --out=/abs/dir \
##     [--weapons=weapon.corsair_ar,weapon.kestrel_p9,weapon.mule_12] [--frames=0,1,3,8]
## Until ENV A emits EventBus.shot_fx (impact_fx.md §2) this tool stands in for it: each local `fired` claim is
## re-emitted as shot_fx (bit1 = first person) with `end` from a ray along the claim, so the FP tracer shows.
## Owner: ENV P.
extends Node

var _out: String = "user://fx_capture"
var _weapons: PackedStringArray = ["weapon.corsair_ar", "weapon.kestrel_p9", "weapon.mule_12"]
var _frames: PackedInt32Array = [0, 1, 3, 8]
var _real_shot_fx: bool = false
var _crew: CrewController = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--weapons="):
			_weapons = a.trim_prefix("--weapons=").split(",")
		elif a.begins_with("--frames="):
			_frames = PackedInt32Array(Array(a.trim_prefix("--frames=").split(",")).map(func(x: String) -> int:
				return int(x)))
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.shot_fx.connect(func(_o: Vector3, _e: Vector3, _n: Vector3, _s: StringName, _w: StringName, _id: int,
			_f: int) -> void: _real_shot_fx = true)
	var rows: Array[Array] = []
	for wid: String in _weapons:
		rows.append(await _capture(StringName(wid)))
	_sheet(rows)
	get_tree().quit(0)


func _capture(wid: StringName) -> Array:
	var def: WeaponDef = ContentDB.weapon(wid)
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	var secondary: bool = def != null and def.slot == Enums.WeaponSlot.SECONDARY
	if secondary:
		l.secondary = wid
		l.secondary_mods = {}
		l.resolved_secondary = LoadoutResolver.resolve_weapon(wid, {})
	else:
		l.primary = wid
		l.primary_mods = {}
		l.resolved_primary = LoadoutResolver.resolve_weapon(wid, {})
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	_crew = rt.crew_controller(0) as CrewController
	_crew.weapons.fired.connect(_stand_in)
	var inp: PInputDriver = PInputDriver.new(self)
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await inp.tap(&"slot_secondary" if secondary else &"slot_primary")
	for _i: int in 150:
		await get_tree().physics_frame
	var shots: Array[Image] = []
	inp.press(&"fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	inp.release(&"fire")
	var f: int = 0
	var want: int = 0
	while want < _frames.size():
		await get_tree().process_frame
		if f == _frames[want]:
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png("%s/%s_f%02d.png" % [_out, String(wid).trim_prefix("weapon."), f])
			shots.append(img)
			want += 1
		f += 1
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(_crew).camera())
	print("[FXCAP] %s set=%s flashes=%d shells=%d tracers=%d real_shot_fx=%s" % [wid,
		vm.anim_set if vm != null else &"", vm.fx.flashes if vm != null else -1,
		vm.fx.shells_ejected if vm != null else -1, vm.fx.tracers_drawn if vm != null else -1, _real_shot_fx])
	inp.release_all()
	rt.teardown()
	for _i: int in 3:
		await get_tree().process_frame
	return shots


## Stand-in for ENV A's emitter (only while no real shot_fx arrives): one FP shot_fx per fired claim.
func _stand_in(claim: Dictionary) -> void:
	if _real_shot_fx or _crew == null:
		return
	var o: Vector3 = claim.get("origin", _crew.eye_position())
	var d: Vector3 = (claim.get("direction", Vector3.FORWARD) as Vector3).normalized()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(o, o + d * 60.0)
	q.exclude = [_crew.get_rid()]
	var hit: Dictionary = _crew.get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = hit.get("position", o + d * 60.0)
	EventBus.shot_fx.emit(o, end, hit.get("normal", Vector3.ZERO), &"", &"", _crew.net_id, FpViewmodelFx.FLAG_FIRST_PERSON)
	_real_shot_fx = false


func _sheet(rows: Array[Array]) -> void:
	if rows.is_empty() or (rows[0] as Array).is_empty():
		return
	var cell: Image = (rows[0] as Array)[0]
	var w: int = cell.get_width() / 2
	var h: int = cell.get_height() / 2
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
	sheet.save_png("%s/fx_sheet.png" % _out)
	print("[FXCAP] sheet %s/fx_sheet.png (%d x %d)" % [_out, cols, rows.size()])
