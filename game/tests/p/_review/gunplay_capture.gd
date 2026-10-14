## D-105 product-owner check ("gunplay feels impactful"): a real heist (Glasshouse, alarm raised), each weapon class
## fired with real input at several distinct surfaces; captures the shot frame (FP muzzle burst, FP tracer, casing)
## and a later frame (ENV C's impact debris / decal), checks bit1 is not doubled (no third-person muzzle / tracer
## from VfxDirector for our own shots), and logs the frame time while firing. Windowed:
##   xvfb-run -a -s "-screen 0 640x360x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 640x360 --path game res://tests/p/_review/gunplay_capture.tscn -- --out=/abs/dir \
##     [--heist=glasshouse] [--weapons=weapon.kestrel_p9,...] [--targets=4] [--frames=0,10]
## Prints "[GUNPLAY] ..." lines and writes <out>/gunplay_sheet.png (rows = weapons, cols = surface x frame).
## Owner: ENV P.
extends Node

var _out: String = "user://gunplay"
var _heist: StringName = &"glasshouse"
var _weapons: PackedStringArray = ["weapon.kestrel_p9", "weapon.hornet_9", "weapon.corsair_ar", "weapon.mule_12",
	"weapon.anvil_lmg", "weapon.heron_308"]
var _n_targets: int = 4
var _frames: PackedInt32Array = [0, 10]
var _crew: CrewController = null
var _rt: HeistRuntime = null
var _inp: PInputDriver = null
var _doubled: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"heist": _heist = StringName(v)
			"weapons": _weapons = v.split(",")
			"targets": _n_targets = int(v)
			"frames": _frames = PackedInt32Array(Array(v.split(",")).map(func(x: String) -> int: return int(x)))
	DirAccess.make_dir_recursive_absolute(_out)
	var rows: Array[Array] = []
	for wid: String in _weapons:
		rows.append(await _weapon(StringName(wid)))
	_sheet(rows)
	print("[GUNPLAY] RESULT DONE weapons=%d doubled=%d sheet=%s/gunplay_sheet.png" % [rows.size(), _doubled, _out])
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
	_rt = await HeistLauncher.launch(_heist, 1002, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "loadouts": {0: l}})
	_rt.isolate_npc(null)
	_crew = _rt.crew_controller(0) as CrewController
	_crew.stealth_hidden = true
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	var st: Node = _rt.service(G.SVC_STEALTH)
	if st != null and st.has_method(&"raise_alarm"):
		st.call(&"raise_alarm", &"scripted")  # loud, as the PO plays it
	var dir: Node = _rt.service(G.SVC_DIRECTOR)
	if dir != null:
		dir.process_mode = Node.PROCESS_MODE_DISABLED  # no assault waves: the capture is about our own shots
	await _inp.tap(&"slot_secondary" if secondary else &"slot_primary")
	await _ticks(70)
	_rt.isolate_npc(null)
	var targets: Array[Dictionary] = _pick_targets()
	var imgs: Array[Image] = []
	for t: Dictionary in targets:
		imgs.append_array(await _fire_at(wid, t))
	_inp.release_all()
	_rt.teardown()
	for _i: int in 3:
		await get_tree().process_frame
	return imgs


## Distinct surfaces around the spawn: rays every 30 deg of yaw at a few pitches, 3..25 m, one per surface id.
func _pick_targets() -> Array[Dictionary]:
	var space: PhysicsDirectSpaceState3D = _crew.get_world_3d().direct_space_state
	var eye: Vector3 = _crew.eye_position()
	var by_surface: Dictionary[StringName, Dictionary] = {}
	for pitch_deg: float in [-8.0, -35.0, 10.0]:
		for k: int in 12:
			var yaw: float = _crew.look_yaw + deg_to_rad(30.0 * k)
			var pitch: float = deg_to_rad(pitch_deg)
			var d: Vector3 = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + d * 25.0)
			q.exclude = [_crew.get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				continue
			var dist: float = eye.distance_to(hit["position"])
			if dist < 3.0:
				continue
			var s: StringName = ImpactFx.surface_of(hit.get("collider"))
			if not by_surface.has(s):
				by_surface[s] = {"yaw": yaw, "pitch": pitch, "surface": s, "dist": dist}
	var out: Array[Dictionary] = []
	for s: StringName in by_surface:
		out.append(by_surface[s])
		if out.size() >= _n_targets:
			break
	print("[GUNPLAY] targets %s" % [out.map(func(t: Dictionary) -> String: return "%s@%.0fm" % [t["surface"], t["dist"]])])
	return out


func _fire_at(wid: StringName, t: Dictionary) -> Array[Image]:
	await _inp.turn_to_yaw(_crew, float(t["yaw"]))
	await _turn_to_pitch(float(t["pitch"]))
	await _ticks(6)
	var vfx: VfxDirector = _rt.vfx
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(_crew).camera())
	var c_muzzles0: int = vfx.muzzles.set_count() if vfx != null else 0
	var fp_tracers0: int = vm.fx.tracers_drawn if vm != null and vm.fx != null else 0
	var shots0: int = _crew.weapons.shots_fired
	_inp.press(&"fire")
	await _crew.weapons.fired
	var out: Array[Image] = []
	var f: int = 0
	var want: int = 0
	var t0: int = Time.get_ticks_usec()
	var released: bool = false
	var c_tracers_max: int = 0
	while want < _frames.size():
		await get_tree().process_frame
		if vfx != null:
			c_tracers_max = maxi(c_tracers_max, vfx.tracers.live)
		if not released and f >= 4:
			_inp.release(&"fire")
			released = true
		if f == _frames[want]:
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png("%s/%s_%s_f%02d.png" % [_out, String(wid).trim_prefix("weapon."), t["surface"], f])
			out.append(img)
			want += 1
		f += 1
	if not released:
		_inp.release(&"fire")
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / maxf(float(f), 1.0)
	var shots: int = _crew.weapons.shots_fired - shots0
	var c_muzzles: int = (vfx.muzzles.set_count() if vfx != null else 0) - c_muzzles0
	var doubled: bool = c_muzzles > 0 or c_tracers_max > 0
	if doubled:
		_doubled += 1
	print("[GUNPLAY] %s -> %s @%.0fm shots=%d fp_tracers=%d c_tracers=%d c_muzzle_sets+%d decals=%d frame=%.1fms %s" % [
		wid, t["surface"], float(t["dist"]), shots, (vm.fx.tracers_drawn if vm != null and vm.fx != null else 0)
		- fp_tracers0, c_tracers_max, c_muzzles, vfx.decals.live if vfx != null else -1, ms,
		"DOUBLED" if doubled else "ok"])
	await _ticks(10)
	return out


func _turn_to_pitch(pitch: float) -> void:
	for _k: int in 30:
		var err: float = pitch - _crew.look_pitch
		if absf(err) < 0.01:
			return
		_inp.look(0.0, -err / PInputDriver.mouse_radians_per_px())
		await _ticks(10)


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


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
	sheet.save_png("%s/gunplay_sheet.png" % _out)
