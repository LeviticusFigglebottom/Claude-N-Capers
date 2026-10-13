## PO-4 ADS picture sweep (windowed, run with --fixed-fps 60): for every WeaponDef, ADS on the unit map and measure
## how much of the screen the viewmodel covers (alpha of the viewmodel SubViewport): total, lower half, and the
## centre box around the sights. Saves a thumbnail per weapon and prints "[ADS] id set total lower centre".
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --fixed-fps 60 --audio-driver Dummy \
##     --resolution 640x360 --path game res://tests/p/_review/ads_sweep.tscn -- --out=DIR [--only=id,id]
## Owner: ENV P.
extends Node

const WEAPON_DIR: String = "res://content/data/weapons/"
const SKIP_SETS: Array[StringName] = [&"akimbo", &"bow"]

var _out: String = "/tmp/ads_sweep"
var _only: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--ads_z="):
			for kv: String in a.trim_prefix("--ads_z=").split(","):
				var parts: PackedStringArray = kv.split(":")
				FpViewmodelTweak.data().set_ads_offset_z[StringName(parts[0])] = float(parts[1])
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	for f: String in DirAccess.get_files_at(WEAPON_DIR):
		if not f.ends_with(".tres"):
			continue
		var d: WeaponDef = load(WEAPON_DIR + f) as WeaponDef
		if d == null or d.id == &"" or SKIP_SETS.has(d.anim_set):
			continue
		if not _only.is_empty() and not _only.has(String(d.id).trim_prefix("weapon.")):
			continue
		await _one(d)
	print("[ADS] done")
	get_tree().quit()


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _one(def: WeaponDef) -> void:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	var primary: bool = def.slot == Enums.WeaponSlot.PRIMARY
	if primary:
		l.primary = def.id
		l.resolved_primary = LoadoutResolver.resolve_weapon(def.id, l.primary_mods)
	else:
		l.secondary = def.id
		l.resolved_secondary = LoadoutResolver.resolve_weapon(def.id, l.secondary_mods)
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	var inp: PInputDriver = PInputDriver.new(self)
	var c: CrewController = rt.crew_controller(0) as CrewController
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await inp.tap(&"slot_primary" if primary else &"slot_secondary")
	await _ticks(150)
	inp.press(&"aim")
	await _ticks(60)
	await RenderingServer.frame_post_draw
	var vp: SubViewport = CrewView.of(c).find_child("Viewmodel", true, false) as SubViewport
	var vm: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
	if vp != null:
		var img: Image = vp.get_texture().get_image()
		var cov: Vector3 = _coverage(img)
		print("[ADS] %-22s %-12s total=%.3f lower=%.3f centre=%.3f" % [String(def.id).trim_prefix("weapon."),
			vm.anim_set if vm != null else &"?", cov.x, cov.y, cov.z])
		img.resize(320, 180)
		img.save_png("%s/%s.png" % [_out, String(def.id).trim_prefix("weapon.")])
	inp.release_all()
	rt.teardown()
	await get_tree().process_frame
	await get_tree().process_frame


## (all pixels, lower half, centre box 30% x 30%) shares with alpha > 0.5.
static func _coverage(img: Image) -> Vector3:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var tot: int = 0
	var low: int = 0
	var cen: int = 0
	var n_low: int = 0
	var n_cen: int = 0
	for y: int in range(0, h, 4):
		for x: int in range(0, w, 4):
			var on: bool = img.get_pixel(x, y).a > 0.5
			tot += 1 if on else 0
			if y >= h / 2:
				n_low += 1
				low += 1 if on else 0
			if absi(x - w / 2) < w * 0.15 and absi(y - h / 2) < h * 0.15:
				n_cen += 1
				cen += 1 if on else 0
	var n: int = ((h + 3) / 4) * ((w + 3) / 4)
	return Vector3(float(tot) / n, float(low) / maxi(n_low, 1), float(cen) / maxi(n_cen, 1))
