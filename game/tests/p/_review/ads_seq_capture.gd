## PO6-11 hip -> ADS -> hip sequence capture (windowed): per weapon, real input on the unit map: hip idle, hip walk,
## then frames through the ADS transition and its settle, then back out to the hip.
## Writes <out>/<weapon>_<nn>_<label>.png and <out>/ads_seq_sheet.png (rows = weapons, cols = frames), and prints
## `[ADSSEQ] <weapon> <label> grip=<weapon bone, camera space> aim=<AimPoint, camera space>` per frame.
##   xvfb-run -a -s "-screen 0 640x360x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 640x360 --path game res://tests/p/_review/ads_seq_capture.tscn -- --out=/abs/dir \
##     [--weapons=weapon.kestrel_p9,...]
##     [--ads-z=0.05,0,-0.05] [--vm-fov=52,60]   PO6-11 framing sweep at settled ADS: per (set_ads_offset_z, viewmodel
##                                             FOV) prints `[ADSCOV] ... arms=<frame share> gun=<frame share>` (pixels
##                                             that change when the Arms mesh / the gun is hidden) and saves a frame
## Owner: ENV P.
extends Node

## Physics ticks after pressing aim (in), and after releasing it (out), at which a frame is saved.
const IN_TICKS: Array[int] = [2, 4, 6, 8, 11, 15, 22, 40]
const OUT_TICKS: Array[int] = [4, 8, 30]

var _out: String = "user://ads_seq"
var _ads_z: PackedFloat64Array = []
var _vm_fov: PackedFloat64Array = []
var _weapons: PackedStringArray = ["weapon.kestrel_p9", "weapon.warden_45", "weapon.wren_380", "weapon.sparrow_mp",
	"weapon.marshal_357", "weapon.corsair_ar"]


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"weapons": _weapons = v.split(",")
			"ads-z":
				for e: String in v.split(",", false):
					_ads_z.append(float(e))
			"vm-fov":
				for e: String in v.split(",", false):
					_vm_fov.append(float(e))
	DirAccess.make_dir_recursive_absolute(_out)
	RenderingServer.render_loop_enabled = false
	var rows: Array[Array] = []
	for wid: String in _weapons:
		rows.append(await _weapon(StringName(wid)))
	_sheet(rows)
	RenderingServer.render_loop_enabled = true
	print("[ADSSEQ] RESULT DONE weapons=%d sheet=%s/ads_seq_sheet.png" % [rows.size(), _out])
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
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	var c: CrewController = rt.crew_controller(0) as CrewController
	rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 10)))
	var inp: PInputDriver = PInputDriver.new(self)
	inp.capture_mouse()
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await inp.tap(&"slot_secondary" if secondary else &"slot_primary")
	await _ticks(120)
	var name: String = String(wid).trim_prefix("weapon.")
	var imgs: Array[Image] = []
	imgs.append(await _shot(c, name, imgs.size(), "hip"))
	inp.press(&"move_forward")
	await _ticks(40)
	imgs.append(await _shot(c, name, imgs.size(), "walk"))
	inp.release(&"move_forward")
	await _ticks(60)
	var vm0: FpViewmodel = FpViewmodel.of(get_viewport().get_camera_3d())
	if vm0 != null:
		vm0.skeleton.skeleton_updated.connect(_dump_bones.bind(vm0, name), CONNECT_ONE_SHOT)
		await _ticks(2)
	inp.press(&"aim")
	var t: int = 0
	for k: int in IN_TICKS:
		await _ticks(k - t)
		t = k
		imgs.append(await _shot(c, name, imgs.size(), "in%d" % k))
	if not _ads_z.is_empty() or not _vm_fov.is_empty():
		await _sweep(name)
	inp.release(&"aim")
	t = 0
	for k: int in OUT_TICKS:
		await _ticks(k - t)
		t = k
		imgs.append(await _shot(c, name, imgs.size(), "out%d" % k))
	inp.release_all()
	rt.teardown()
	for _i: int in 3:
		await get_tree().process_frame
	return imgs


func _shot(c: CrewController, name: String, idx: int, label: String) -> Image:
	RenderingServer.render_loop_enabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	img.save_png("%s/%s_%02d_%s.png" % [_out, name, idx, label])
	var cam: Camera3D = get_viewport().get_camera_3d()
	var vm: FpViewmodel = FpViewmodel.of(cam) if cam != null else null
	if vm != null and vm.weapon_attach != null and cam != null:
		var inv: Transform3D = cam.global_transform.affine_inverse()
		var aim: Node3D = vm.weapon_visual.get_marker(WeaponVisual.AIM_POINT) if vm.weapon_visual != null else null
		var muz: Node3D = vm.weapon_visual.get_marker(&"Muzzle") if vm.weapon_visual != null else null
		var bore: Vector3 = (inv.basis * (muz.global_position - aim.global_position)).normalized() \
			if muz != null and aim != null else Vector3.ZERO
		var up: Vector3 = inv.basis * vm.weapon_attach.global_basis.y.normalized()
		if muz != null:
			var vc: Camera3D = CrewView.of(c).viewmodel_camera() if c != null else null
			var pc: Camera3D = vc if vc != null else cam
			var sz: Vector2 = get_viewport().get_visible_rect().size
			print("[ADSSEQ] %s %s screen grip=%s muzzle=%s" % [name, label,
				pc.unproject_position(vm.weapon_attach.global_position) / sz,
				pc.unproject_position(muz.global_position) / sz])
		print("[ADSSEQ] %s %s ads=%.2f grip=%s aim=%s yaw=%.1f pitch=%.1f roll=%.1f" % [name, label, vm.ads_weight,
			inv * vm.weapon_attach.global_position, inv * aim.global_position if aim != null else Vector3.INF,
			rad_to_deg(atan2(-bore.x, -bore.z)), rad_to_deg(asin(clampf(bore.y, -1.0, 1.0))),
			rad_to_deg(atan2(-up.x, up.y))])
		var mk: Node3D = vm.weapon_visual.get_marker(&"LeftHandIK") if vm.weapon_visual != null else null
		var hb: int = vm.skeleton.find_bone("hand.L")
		if mk != null and hb >= 0:
			var hand: Transform3D = vm.skeleton.global_transform * vm.skeleton.get_bone_global_pose(hb)
			var rel: Transform3D = mk.global_transform.orthonormalized().affine_inverse() * hand.orthonormalized()
			print("[ADSSEQ] %s %s wrist_in_marker=%s hand_rel_euler=%s ik=%.2f" % [name, label, rel.origin,
				rel.basis.get_euler() * (180.0 / PI), vm.left_hand_ik.ik.influence if vm.left_hand_ik != null else -1.0])
	elif c == null:
		print("[ADSSEQ] %s %s no crew" % [name, label])
	return img


## PO6-11: settled-ADS framing per (eye relief offset, viewmodel FOV): frame share of the sleeves and of the gun.
func _sweep(name: String) -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var vm: FpViewmodel = FpViewmodel.of(get_viewport().get_camera_3d())
	if vm == null:
		return
	var set_id: StringName = vm.anim_set
	var z0: Variant = tw.set_ads_offset_z.get(set_id, 0.0)
	var fov0: float = tw.viewmodel_fov_deg
	var zs: PackedFloat64Array = _ads_z if not _ads_z.is_empty() else PackedFloat64Array([float(z0)])
	var fovs: PackedFloat64Array = _vm_fov if not _vm_fov.is_empty() else PackedFloat64Array([fov0])
	var arms_meshes: Array[MeshInstance3D] = []
	for n: Node in vm.arms.find_children("*", "MeshInstance3D", true, false):
		if vm.weapon_visual == null or not vm.weapon_visual.is_ancestor_of(n):
			arms_meshes.append(n as MeshInstance3D)
	for z: float in zs:
		for f: float in fovs:
			tw.set_ads_offset_z[set_id] = z
			tw.viewmodel_fov_deg = f
			await _ticks(40)
			var a: Image = await _shot(null, name, 90, "cov_z%s_fov%s" % [z, f])
			for m: MeshInstance3D in arms_meshes:
				m.visible = false
			var b: Image = await _grab()
			for m: MeshInstance3D in arms_meshes:
				m.visible = true
			vm.weapon_visual.visible = false
			var c: Image = await _grab()
			vm.weapon_visual.visible = true
			print("[ADSCOV] %s set=%s ads_z=%.3f vm_fov=%.0f arms=%.3f gun=%.3f" % [name, set_id, z, f, _diff(a, b),
				_diff(a, c)])
	tw.set_ads_offset_z[set_id] = z0
	tw.viewmodel_fov_deg = fov0
	await _ticks(20)


func _grab() -> Image:
	RenderingServer.render_loop_enabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	return img


## Share of pixels that differ (any channel by more than 6/255).
static func _diff(a: Image, b: Image) -> float:
	var n: int = 0
	var w: int = mini(a.get_width(), b.get_width())
	var h: int = mini(a.get_height(), b.get_height())
	for y: int in range(0, h, 2):
		for x: int in range(0, w, 2):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 6.0 / 255.0:
				n += 1
	return float(n) / float(maxi((w / 2) * (h / 2), 1))


## Post-modifier positions of the hand bones (camera space), at the hip (D-116 one-handed check).
func _dump_bones(vm: FpViewmodel, name: String) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var inv: Transform3D = cam.global_transform.affine_inverse()
	for b: String in ["upper_arm.L", "hand.L", "thumb_03.L", "index_03.L", "hand.R", "thumb_03.R", "index_03.R"]:
		var i: int = vm.skeleton.find_bone(b)
		if i >= 0:
			print("[ADSSEQ] %s bone %s %s left_drop=%.2f" % [name, b,
				inv * (vm.skeleton.global_transform * vm.skeleton.get_bone_global_pose(i).origin), vm.left_arm_drop()])


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
	sheet.save_png("%s/ads_seq_sheet.png" % _out)
