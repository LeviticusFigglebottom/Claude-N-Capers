## D-116 motion clip (windowed): real input on the unit map, every rendered frame saved, for the "organic" review:
## idle (breathing), a fast turn and stop (sway lag + overshoot), walk (footstep bob), sprint, jump + landing dip,
## three shots (recoil spring), ADS in, aimed hold, ADS out, a tactical reload (one-handed sets: the left hand comes
## in for it, D-116). --reload-only records just the shots + reload (reload framing review). Writes
## <out>/<weapon>/f_NNNN.png per weapon and prints
## `[MOTION] <weapon> <segment> frame=N`; make a video with
##   ffmpeg -framerate 30 -i <out>/<weapon>/f_%04d.png -pix_fmt yuv420p <weapon>.mp4
##   xvfb-run -a -s "-screen 0 640x360x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 30 --resolution 640x360 --path game res://tests/p/_review/motion_clip.tscn -- --out=/abs/dir \
##     [--weapons=weapon.kestrel_p9,weapon.corsair_ar] [--reload-only]
## Owner: ENV P.
extends Node

var _out: String = "user://motion_clip"
var _weapons: PackedStringArray = ["weapon.kestrel_p9", "weapon.corsair_ar"]
var _dir: String = ""
var _frame: int = 0
var _reload_only: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"weapons": _weapons = v.split(",")
			"reload-only": _reload_only = true
	for wid: String in _weapons:
		await _weapon(StringName(wid))
	print("[MOTION] RESULT DONE weapons=%d out=%s" % [_weapons.size(), _out])
	get_tree().quit(0)


func _weapon(wid: StringName) -> void:
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
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 10)))
	var inp: PInputDriver = PInputDriver.new(self)
	inp.capture_mouse()
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await inp.tap(&"slot_secondary" if secondary else &"slot_primary")
	await _ticks(60)
	_dir = "%s/%s" % [_out, String(wid).trim_prefix("weapon.")]
	DirAccess.make_dir_recursive_absolute(_dir)
	_frame = 0
	if _reload_only:
		await _reload(wid, inp)
		inp.release_all()
		rt.teardown()
		for _i: int in 3:
			await get_tree().process_frame
		return
	await _seg(wid, "idle", 30)
	for _k: int in 10:  # fast turn right, then stop: sway lag + spring overshoot
		inp.look(45.0, 0.0)
		await _rec()
	await _seg(wid, "turn_stop", 30)
	inp.press(&"move_forward")
	await _seg(wid, "walk", 60)
	inp.press(&"sprint")
	await _seg(wid, "sprint", 45)
	inp.release(&"sprint")
	inp.release(&"move_forward")
	await _seg(wid, "stop", 20)
	await inp.tap(&"jump")
	await _seg(wid, "jump_land", 45)
	for _k: int in 3:
		await inp.tap(&"fire")
		await _seg(wid, "fire", 8)
	await _seg(wid, "recover", 15)
	inp.press(&"aim")
	await _seg(wid, "ads_in", 30)
	inp.release(&"aim")
	await _seg(wid, "ads_out", 30)
	await _reload(wid, inp)
	inp.release_all()
	rt.teardown()
	for _i: int in 3:
		await get_tree().process_frame


func _reload(wid: StringName, inp: PInputDriver) -> void:
	for _k: int in 2:  # a full magazine does not reload
		await inp.tap(&"fire")
		await _seg(wid, "fire", 8)
	await inp.tap(&"reload")
	await _seg(wid, "reload", 90)


func _seg(wid: StringName, label: String, frames: int) -> void:
	print("[MOTION] %s %s frame=%d" % [wid, label, _frame])
	for _i: int in frames:
		await _rec()


func _rec() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(PCaptureName.safe_path("%s/f_%04d.png" % [_dir, _frame]))
	_frame += 1


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame
