## LEAD r244 (b): NPC third-person weapons baked to one surface (NpcWeaponBake). Every NPC-carried gun has a bake
## with one MeshInstance3D / one surface on the shared material; the bake keeps the source's markers (same
## transforms) and geometry (same triangle count and bounds), so a weapon model change without a rebake fails here;
## WeaponVisual.setup_npc() uses the bake and keeps the marker API.
extends TestCase


func _carried() -> Array[WeaponDef]:
	var out: Array[WeaponDef] = []
	for npc_id: StringName in NpcWeaponModels.data().models:
		var def: WeaponDef = NpcWeaponModels.weapon_def(npc_id)
		if def != null and not out.has(def):
			out.append(def)
	return out


func test_every_carried_weapon_has_a_one_surface_bake() -> void:
	var defs: Array[WeaponDef] = _carried()
	assert_true(defs.size() >= 8, "NPC guns mapped: %d" % defs.size())
	var shared: Material = load(NpcWeaponBake.MATERIAL_PATH) as Material
	for def: WeaponDef in defs:
		var ps: PackedScene = NpcWeaponBake.scene(def)
		assert_true(ps != null, "%s has a bake (run npc_weapon_bake_cli.gd)" % def.id)
		if ps == null:
			continue
		var n: Node3D = ps.instantiate() as Node3D
		var mis: Array[Node] = n.find_children("*", "MeshInstance3D", true, false)
		assert_eq(mis.size(), 1, "%s: one MeshInstance3D" % def.id)
		var mesh: Mesh = (mis[0] as MeshInstance3D).mesh
		assert_eq(mesh.get_surface_count(), 1, "%s: one surface" % def.id)
		assert_eq(mesh.surface_get_material(0), shared, "%s: the shared merged material" % def.id)
		n.free()


func test_bake_matches_the_source_model() -> void:
	for def: WeaponDef in _carried():
		var ps: PackedScene = NpcWeaponBake.scene(def)
		if ps == null:
			continue
		var baked: Node3D = ps.instantiate() as Node3D
		var src: Node3D = def.model.instantiate() as Node3D
		for m: Node3D in NpcWeaponBake.markers(src):
			var b: Node3D = baked.get_node_or_null(NodePath(String(m.name))) as Node3D
			assert_true(b != null, "%s keeps marker %s" % [def.id, m.name])
			if b != null:
				var want: Transform3D = WeaponVisual._transform_to(src, m)
				assert_true(b.transform.is_equal_approx(want), "%s %s at the source transform" % [def.id, m.name])
		var tris: int = 0
		var box: AABB = AABB()
		var first: bool = true
		for node: Node in src.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node as MeshInstance3D
			if not NpcWeaponBake._shown(src, mi):
				continue
			var xf: Transform3D = WeaponVisual._transform_to(src, mi)
			for s: int in mi.mesh.get_surface_count():
				var a: Array = mi.mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				tris += idx.size() / 3 if not idx.is_empty() else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var part: AABB = xf * mi.mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		var mesh: Mesh = (baked.get_node(NodePath(String(NpcWeaponBake.MERGED_NODE))) as MeshInstance3D).mesh
		var got: int = (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_eq(got, tris, "%s: same triangles as the stock model (stale bake?)" % def.id)
		var mb: AABB = mesh.get_aabb()
		assert_true(mb.position.distance_to(box.position) < 0.002 and mb.end.distance_to(box.end) < 0.002,
				"%s: bounds %s vs source %s (stale bake?)" % [def.id, mb, box])
		baked.free()
		src.free()


func test_looks_come_from_the_library_materials() -> void:
	var blued: Array = NpcWeaponBake.look(load("res://world/materials/steel_blued.tres") as Material)
	var walnut: Array = NpcWeaponBake.look(load("res://world/materials/wood_veneer_walnut.tres") as Material)
	var brass: Array = NpcWeaponBake.look(load("res://world/materials/brass_cartridge.tres") as Material)
	assert_true(float(blued[1]) > 0.5, "blued steel stays metal: %s" % [blued])
	assert_true(float(walnut[1]) < 0.5, "walnut is not metal: %s" % [walnut])
	var wc: Color = walnut[0]
	assert_true(wc.r > wc.b, "walnut reads warm: %s" % wc)
	var bc: Color = brass[0]
	assert_true(bc.r > bc.b and bc.g > bc.b, "brass reads yellow: %s" % bc)


func test_setup_npc_uses_the_bake_and_keeps_markers() -> void:
	var def: WeaponDef = NpcWeaponModels.weapon_def(&"weapon.npc_rifle")
	var wv: WeaponVisual = WeaponVisual.new()
	add_child(wv)
	wv.setup_npc(def)
	assert_eq(wv.weapon, def)
	assert_eq(wv.model.find_children("*", "MeshInstance3D", true, false).size(), 1, "the merged model")
	for m: StringName in [&"Muzzle", &"LeftHandIK", &"AimPoint", &"Eject"]:
		assert_true(wv.get_marker(m) != null, "marker %s" % m)
	var full: WeaponVisual = WeaponVisual.new()
	add_child(full)
	full.setup(def, [] as Array[WeaponModDef])
	assert_true(wv.get_marker(&"Muzzle").global_position.is_equal_approx(full.get_marker(&"Muzzle").global_position),
			"the muzzle is where the full model's is")
	# A weapon without a bake falls back to the full stock model.
	var other: WeaponDef = ContentDB.weapon(&"weapon.akimbo_warden_45")
	wv.setup_npc(other)
	assert_true(wv.model.find_children("*", "MeshInstance3D", true, false).size() > 1, "no bake: the full model")
	wv.queue_free()
	full.queue_free()
	await wait_frames(1)
