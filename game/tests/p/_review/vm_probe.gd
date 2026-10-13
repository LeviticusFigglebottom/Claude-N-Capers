## Viewmodel render probe on the small unit map (fast windowed): hip + ADS shots and the viewmodel meshes'
## layers / materials. Run under xvfb (not --headless): ... --path game res://tests/p/_review/vm_probe.tscn -- --out=DIR
## Owner: ENV P.
extends Node

var _out: String = "/tmp"
var _slot: String = ""
var _heist: StringName = &""
var _moves: bool = false
var _fire: bool = false
var _primary: StringName = &"weapon.corsair_ar"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--primary="):
			_primary = StringName(a.trim_prefix("--primary="))
		elif a.begins_with("--heist="):
			_heist = StringName(a.trim_prefix("--heist="))
		elif a == "--fire":
			_fire = true
		elif a == "--moves":
			_moves = true
		elif a == "--no_ik":
			FpViewmodelTweak.data().left_hand_ik_skip_sets.append(&"rifle")
			FpViewmodelTweak.data().left_hand_ik_skip_sets.append(&"pistol")
		elif a.begins_with("--slot="):
			_slot = a.trim_prefix("--slot=")
	DirAccess.make_dir_recursive_absolute(_out)
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = _primary
	l.resolved_primary = LoadoutResolver.resolve_weapon(l.primary, l.primary_mods)
	var rt: HeistRuntime = null
	if _heist == &"":
		rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
			{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	else:
		rt = await HeistLauncher.launch(_heist, 1002, Enums.Difficulty.ROUTINE, self,
			{"ai_teammates": 0, "loadouts": {0: l}})
		rt.isolate_npc(null)
	var inp: PInputDriver = PInputDriver.new(self)
	var c: CrewController = rt.crew_controller(0) as CrewController
	for _i: int in 30:
		await get_tree().physics_frame
	await _shot("vm_casing")
	_dump(c)
	await inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	for _i: int in 90:
		await get_tree().physics_frame
	if _slot != "":
		await inp.tap(&"slot_primary" if _slot == "primary" else &"slot_secondary")
		for _i: int in 120:
			await get_tree().physics_frame
	print("[VM] equipped slot=%d primary=%s secondary=%s" % [c.weapons.equipped_slot, c.loadout.primary,
		c.loadout.secondary])
	await _shot("vm_hip")
	_dump(c)
	if _fire:
		inp.press(&"fire")
		for k: int in 4:
			await get_tree().physics_frame
			var ml: OmniLight3D = c.find_child("MuzzleLight", true, false) as OmniLight3D
			print("[VM] fire t%d light=%s" % [k, "none" if ml == null else "vis=%s e=%.2f at=%s" % [ml.visible,
				ml.light_energy, ml.global_position]])
			if ml != null and ml.visible:
				await _shot("vm_fire_flash")
				break
		inp.release(&"fire")
		for _i: int in 30:
			await get_tree().physics_frame
	if _moves:
		inp.press(&"move_forward")
		inp.press(&"sprint")
		for _i: int in 60:
			await get_tree().physics_frame
		await _shot("vm_sprint")
		inp.release(&"sprint")
		inp.release(&"move_forward")
		inp.press(&"crouch")
		for _i: int in 40:
			await get_tree().physics_frame
		await _shot("vm_crouch")
		inp.release(&"crouch")
		for _i: int in 30:
			await get_tree().physics_frame
		inp.press(&"jump")
		for _i: int in 12:
			await get_tree().physics_frame
		await _shot("vm_jump_air")
		inp.release(&"jump")
		for _i: int in 60:
			await get_tree().physics_frame
	inp.press(&"aim")
	for k: int in 7:
		for _i: int in 2:
			await get_tree().physics_frame
		await _shot("vm_ads_t%02d" % (k * 2 + 2))
		var vmn: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
		if vmn != null:
			print("[VM] t%02d ads_weight=%.2f anim=%s pos=%s" % [k * 2 + 2, vmn.ads_weight,
				vmn.player.current_animation if vmn.player != null else "", vmn.position])
	for _i: int in 46:
		await get_tree().physics_frame
	await _shot("vm_ads")
	_dump(c)
	var vp: SubViewport = CrewView.of(c).find_child("Viewmodel", true, false) as SubViewport
	if vp != null:
		var img: Image = vp.get_texture().get_image()
		img.save_png("%s/vm_ads_subviewport.png" % _out)
		var mid: Color = img.get_pixel(img.get_width() / 2 + 60, img.get_height() * 3 / 4)
		print("[VM] subviewport size=%s format=%d px=%s corner=%s" % [vp.size, img.get_format(), mid,
			img.get_pixel(10, 10)])
	inp.release_all()
	get_tree().quit()


func _dump(c: CrewController) -> void:
	var cam: Camera3D = CrewView.of(c).camera()
	var inv: Transform3D = cam.global_transform.affine_inverse()
	var vm: FpViewmodel = FpViewmodel.of(cam)
	if vm != null and vm.weapon_visual != null:
		var wv: Node3D = vm.weapon_visual
		var wx: Transform3D = inv * wv.global_transform
		print("[VM] set=%s weapon origin cam=%s fwd(-Z)=%s up=%s scale=%s" % [vm.anim_set, wx.origin,
			-wx.basis.z.normalized(), wx.basis.y.normalized(), wx.basis.get_scale()])
		for mk: StringName in [&"GripMount", &"LeftHandIK", &"Muzzle", &"AimPoint", &"Magwell"]:
			var m: Node3D = wv.call(&"get_marker", mk) as Node3D if wv.has_method(&"get_marker") else null
			if m != null:
				print("[VM]   %s cam=%s" % [mk, (inv * m.global_transform).origin])
		var ab: AABB = AABB()
		var first: bool = true
		for n: Node in wv.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
			ab = b if first else ab.merge(b)
			first = false
		print("[VM]   weapon AABB cam pos=%s size=%s" % [ab.position, ab.size])
	for n: Node in c.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = n as MeshInstance3D
		if (m.layers & CrewView.VIEWMODEL_LAYER) == 0 or not m.is_visible_in_tree():
			continue
		var mat: Material = m.get_active_material(0)
		var info: String = "none"
		if mat is StandardMaterial3D:
			var sm: StandardMaterial3D = mat as StandardMaterial3D
			info = "std albedo=%s shading=%d cull=%d tex=%s" % [sm.albedo_color, sm.shading_mode, sm.cull_mode,
				sm.albedo_texture != null]
		elif mat != null:
			info = mat.get_class()
		print("[VM] %s layers=%x surfaces=%d mat0=%s pos=%s" % [m.get_path(), m.layers,
			m.mesh.get_surface_count() if m.mesh != null else 0, info, m.global_position])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[VM] shot ", name)
