## B2-03: mask customisation (pd2_fidelity P8). Part catalog, MaskComposer.compose, MaskCatalog.resolve
## for preset and custom ids, descriptors for other peers, MaskLocker ownership/slots/equip, strings,
## placeholder visual, and the mask screen flow (edit -> save into a slot -> equip).
extends TestCase

const SLOT: int = 7
const COMP: Dictionary = {
	"base": "mask_base.vulpine", "material": "mask_material.gilt",
	"colors": "mask_colors.ember_soot", "pattern": "mask_pattern.split",
}

var _screen: MaskScreen


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_each() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
		await wait_frames(1)
	_screen = null
	SaveService.delete_profile(SLOT)


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_part_catalog() -> void:
	for k: String in MaskCatalog.KINDS:
		var parts: Array[MaskPartDef] = MaskCatalog.parts(k)
		assert_true(parts.size() >= 4, "%s has parts" % k)
		var owned: int = 0
		for p: MaskPartDef in parts:
			assert_eq(MaskCatalog.kind_of(p.id), k, String(p.id))
			owned += 1 if p.default_owned else 0
		assert_true(owned >= 1 and owned < parts.size(), "%s: some default-owned, some to unlock" % k)
	for p: MaskPartDef in MaskCatalog.parts(MaskCatalog.MATERIAL):
		var m: MaskMaterialDef = p as MaskMaterialDef
		assert_true(m.library_material != null, "%s references a library material" % m.id)
		assert_eq(MaskCatalog.material_for(m.material_id), m, "library ids are unique")
	for r: Resource in ContentDB.all_of(ContentDB.MASKS):
		assert_true(r is MaskDef, "ContentDB masks index holds only MaskDef presets")


func test_compose_fields() -> void:
	var d: MaskDef = MaskComposer.compose(COMP, &"mask.custom.2")
	assert_true(d != null)
	assert_eq(d.id, &"mask.custom.2")
	assert_eq(d.material_id, &"brass")
	var c: MaskColorDef = MaskCatalog.part(&"mask_colors.ember_soot") as MaskColorDef
	assert_eq(d.color_a, c.color_a)
	assert_eq(d.color_b, c.color_b)
	assert_eq(d.pattern_id, &"mask_pattern.split")
	assert_eq(d.unlock, &"")
	assert_eq(MaskComposer.composition_of(d), COMP)


func test_compose_invalid_is_null() -> void:
	var bad: Dictionary = COMP.duplicate()
	bad["pattern"] = "mask_colors.bone_ink"
	assert_eq(MaskComposer.validate(bad).size(), 1)
	assert_true(MaskComposer.compose(bad) == null)
	bad.erase("base")
	assert_eq(MaskComposer.validate(bad).size(), 2)


func test_preset_composition() -> void:
	var gh: MaskDef = ContentDB.mask(&"mask.gilded_heron") as MaskDef
	var comp: Dictionary = MaskComposer.composition_of(gh)
	assert_eq(comp["base"], "mask_base.heron")
	assert_eq(comp["material"], "mask_material.gilt")
	assert_eq(comp["colors"], "mask_colors.gilt_night")
	assert_eq(comp["pattern"], "mask_pattern.brow_band")


func test_resolve_preset_and_custom() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(MaskCatalog.resolve(&"mask.gilded_heron", p).id, &"mask.gilded_heron")
	assert_true(MaskCatalog.resolve(&"", p) == null, "no mask")
	assert_true(MaskCatalog.resolve(&"mask.custom.0", p) == null, "empty slot")
	assert_eq(MaskLocker.save_custom(p, 0, {"base": "mask_base.visage", "material": "mask_material.matte",
		"colors": "mask_colors.bone_ink", "pattern": "mask_pattern.solid"}), &"mask.custom.0")
	var d: MaskDef = MaskCatalog.resolve(&"mask.custom.0", p)
	assert_eq(d.id, &"mask.custom.0")
	assert_eq(d.material_id, &"plastic_matte")
	assert_eq(MaskCatalog.custom_index(&"mask.custom.12"), 12)
	assert_eq(MaskCatalog.custom_index(&"mask.custom.x"), -1)
	assert_eq(MaskCatalog.custom_index(&"mask.gilded_heron"), -1)


func test_descriptor_for_other_peers() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	MaskLocker.grant_part(p, &"mask_pattern.dots")
	var comp: Dictionary = COMP.duplicate()
	comp["pattern"] = "mask_pattern.dots"
	MaskLocker.save_custom(p, 3, comp)
	var desc: Dictionary = MaskCatalog.descriptor(&"mask.custom.3", p)
	var json: Variant = JSON.parse_string(JSON.stringify(desc))
	var d: MaskDef = MaskCatalog.from_descriptor(json as Dictionary)
	assert_eq(d.id, &"mask.custom.3")
	assert_eq(d.pattern_id, &"mask_pattern.dots")
	assert_eq(MaskCatalog.descriptor(&"mask.gilded_heron", p), {"preset": "mask.gilded_heron"})
	assert_eq(MaskCatalog.from_descriptor({"preset": "mask.gilded_heron"}).id, &"mask.gilded_heron")
	assert_eq(MaskCatalog.descriptor(&"", p), {})
	assert_true(MaskCatalog.from_descriptor({}) == null)


func test_locked_parts_and_grant() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var comp: Dictionary = COMP.duplicate()
	comp["base"] = "mask_base.owl"
	assert_false(MaskLocker.is_part_owned(p, &"mask_base.owl"))
	assert_eq(MaskLocker.save_custom(p, 0, comp), &"", "locked part refused")
	assert_true(MaskLocker.grant_part(p, &"mask_base.owl"))
	assert_false(MaskLocker.grant_part(p, &"mask_base.owl"), "already owned")
	assert_false(MaskLocker.grant_part(p, &"mask_base.nope"))
	assert_eq(MaskLocker.save_custom(p, 0, comp), &"mask.custom.0")
	assert_eq(MaskLocker.save_custom(p, MaskCatalog.tweak().custom_slot_count, comp), &"", "slot out of range")
	assert_eq(MaskLocker.owned_parts(p, MaskCatalog.BASE).size(), _default_owned(MaskCatalog.BASE) + 1)


func test_equip_and_save_round_trip() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_false(MaskLocker.equip(p, &"mask.custom.1"), "empty slot")
	assert_eq(p.loadout.mask, &"mask.gilded_heron")
	MaskLocker.save_custom(p, 1, COMP)
	assert_true(MaskLocker.equip(p, &"mask.custom.1"))
	assert_eq(p.loadout.mask, &"mask.custom.1")
	assert_eq(MaskLocker.available_ids(p), [&"mask.gilded_heron", &"mask.custom.1"] as Array[StringName])
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.loadout.mask, &"mask.custom.1")
	assert_eq(MaskComposer.composition_of(MaskCatalog.resolve(q.loadout.mask, q)), COMP)
	var r: Loadout = LoadoutResolver.resolve(q.loadout)
	assert_eq(r.mask, &"mask.custom.1", "LoadoutResolver keeps the mask id")
	MaskLocker.clear_custom(q, 1)
	assert_eq(q.loadout.mask, &"", "clearing the worn slot unequips it")


func test_strings_exist() -> void:
	var table: Dictionary = StringTable.parse_csv()
	for k: String in MaskCatalog.KINDS:
		for p: MaskPartDef in MaskCatalog.parts(k):
			assert_has(table, String(UiText.item_key(p.id)))
	for md: MaskDef in MaskCatalog.presets():
		assert_has(table, String(UiText.item_key(md.id)))
	assert_has(table, "ui.masks.custom_slot")


func test_placeholder_visual() -> void:
	for p: MaskPartDef in MaskCatalog.parts(MaskCatalog.BASE):
		var mesh: ArrayMesh = MaskComposer.placeholder_mesh(p as MaskBaseDef, 16)
		assert_true(mesh.get_surface_count() == 1, "%s mesh" % p.id)
		var aabb: AABB = mesh.get_aabb()
		assert_true(aabb.size.x > 0.1 and aabb.size.y > 0.1, "%s face-sized" % p.id)
		assert_true(aabb.position.z < 0.0, "%s bulges toward -Z" % p.id)
	var node: Node3D = MaskComposer.instantiate(MaskComposer.compose(COMP))
	# LEAD: with ENV D's base meshes on trunk the composition may use the model instead of "Placeholder".
	var found: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	assert_false(found.is_empty(), "mask has a mesh")
	if found.is_empty():
		node.free()
		return
	var mi: MeshInstance3D = found[0] as MeshInstance3D
	assert_true(mi.material_override is ShaderMaterial)
	assert_eq((mi.material_override as ShaderMaterial).get_shader_parameter(&"pattern"), int(MaskPatternDef.Procedural.SPLIT))
	node.free()


func test_screen_flow() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	_screen = (load("res://content/ui/masks/mask_screen.tscn") as PackedScene).instantiate() as MaskScreen
	_screen.profile_slot = SLOT
	_screen.setup(p)
	add_child(_screen)
	await wait_frames(1)
	assert_eq(_screen.selected_id, &"mask.gilded_heron", "opens on the worn mask")
	assert_true(_screen.list_buttons.has(&"mask.custom.0"))
	assert_true(_screen.equip_button.disabled, "already worn")
	assert_true(_screen.preview.mask_node != null, "preview shows a mask")
	assert_true(_screen.select_mask(&"mask.custom.2"))
	assert_true(_screen.dirty, "empty slot = draft")
	assert_true(_screen.set_part("base", &"mask_base.vulpine"))
	assert_false(_screen.set_part("base", &"mask_colors.bone_ink"))
	assert_true(_screen.set_part("pattern", &"mask_pattern.stripes"))
	assert_true(_screen.save_button.disabled, "locked pattern")
	assert_eq(_screen.save_to_slot(), &"")
	assert_true(_screen.set_part("pattern", &"mask_pattern.split"))
	assert_false(_screen.save_button.disabled)
	assert_eq(_screen.save_to_slot(), &"mask.custom.2")
	assert_false(_screen.dirty)
	var got: Array[StringName] = []
	_screen.mask_changed.connect(func(id: StringName) -> void: got.append(id))
	assert_true(_screen.equip_selected())
	assert_eq(got, [&"mask.custom.2"] as Array[StringName])
	assert_eq(p.loadout.mask, &"mask.custom.2")
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.loadout.mask, &"mask.custom.2", "saved to disk")
	assert_eq(MaskLocker.custom_composition(q, 2)["base"], "mask_base.vulpine")
	var backs: Array[int] = []
	_screen.back_requested.connect(func() -> void: backs.append(1))
	_screen.back_button.pressed.emit()
	assert_eq(backs.size(), 1)


func _default_owned(kind: String) -> int:
	var n: int = 0
	for p: MaskPartDef in MaskCatalog.parts(kind):
		n += 1 if p.default_owned else 0
	return n


func test_mask_colours_respect_albedo_floor() -> void:
	# style guide albedo floor (D-035; lead note on ENV D's mask): no channel below ~0.12.
	var colors: Array[Color] = []
	var preset: MaskDef = ContentDB.mask(&"mask.gilded_heron")
	colors.append(preset.color_a)
	colors.append(preset.color_b)
	var text: String = FileAccess.get_file_as_string("res://content/data/masks/parts/colors.tres")
	var rx: RegEx = RegEx.create_from_string("Color\\(([^)]*)\\)")
	for m: RegExMatch in rx.search_all(text):
		var p: PackedStringArray = m.get_string(1).split(",")
		colors.append(Color(float(p[0]), float(p[1]), float(p[2])))
	for c: Color in colors:
		assert_true(c.r >= 0.119 and c.g >= 0.119 and c.b >= 0.119, "colour %s under the albedo floor" % c)


func test_gilded_heron_uses_env_d_mesh() -> void:
	var preset: MaskDef = ContentDB.mask(&"mask.gilded_heron")
	assert_true(preset.model != null, "ENV D mesh wired")
	var n: Node = preset.model.instantiate()
	assert_true(n is Node3D)
	n.free()


func test_base_mesh_paths_exist() -> void:
	# ENV D's base meshes (QB-50b): pipeline layout assets/masks/mask_base_<name>/mask_base_<name>.glb.
	var text: String = FileAccess.get_file_as_string("res://content/data/masks/parts/bases.tres")
	var rx: RegEx = RegEx.create_from_string("model_path = \"([^\"]+)\"")
	var found: int = 0
	for m: RegExMatch in rx.search_all(text):
		found += 1
		assert_true(ResourceLoader.exists(m.get_string(1)), "missing base mesh %s" % m.get_string(1))
	assert_eq(found, 5, "five base shapes")


func test_placeholder_uv_origin_is_viewer_left() -> void:
	# masks.md: u = 0 at +X (the viewer's left looking at the mask front), v = 0 at the top.
	var mesh: Mesh = MaskComposer.placeholder_mesh(MaskCatalog.part(&"mask_base.visage") as MaskBaseDef)
	assert_true(mesh != null)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var right_most: int = 0
	for i: int in range(verts.size()):
		if verts[i].x > verts[right_most].x:
			right_most = i
	assert_true(uvs[right_most].x < 0.1, "+X edge maps to u ~ 0")


## D-043 QA-25: Loadout.mask_descriptor carries the worn CUSTOM mask to every peer; {} for presets/none.
func test_loadout_mask_descriptor() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var r: Loadout = LoadoutResolver.resolve(p.loadout, p)
	assert_eq(p.loadout.mask, &"mask.gilded_heron")
	assert_eq(r.mask_descriptor, {}, "preset: {}")
	MaskLocker.save_custom(p, 2, COMP)
	assert_true(MaskLocker.equip(p, &"mask.custom.2"))
	var want: Dictionary = MaskCatalog.descriptor(&"mask.custom.2", p)
	assert_eq(p.loadout.mask_descriptor, want, "equip fills the profile loadout")
	r = LoadoutResolver.resolve(p.loadout, p)
	assert_eq(r.mask_descriptor, want, "resolve(loadout, profile)")
	assert_eq(LoadoutResolver.resolve(p.loadout).mask_descriptor, want, "kept without a profile")
	assert_eq(LoadoutResolver.resolve(r).mask_descriptor, want, "re-resolving keeps it (ENV A)")
	assert_eq(MaskCatalog.from_descriptor(r.mask_descriptor).id, &"mask.custom.2")
	var other: Loadout = p.loadout.duplicate(true) as Loadout
	other.mask = &"mask.custom.5"
	assert_eq(LoadoutResolver.resolve(other).mask_descriptor, {}, "a stale descriptor for another mask is dropped")
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.loadout.mask_descriptor, want, "derived again on load (never saved)")
	assert_false(JSON.stringify(q.to_dict()).contains("mask_descriptor"), "not persisted")
	MaskLocker.clear_custom(q, 2)
	assert_eq(q.loadout.mask_descriptor, {}, "clearing the worn slot clears it")
	var ls: LoadoutScreen = (load("res://content/ui/menus/loadout.tscn") as PackedScene).instantiate() as LoadoutScreen
	ls.setup(p)
	add_child(ls)
	await wait_frames(1)
	assert_eq(ls.current_loadout().mask_descriptor, want, "the launch loadout carries it")
	ls.queue_free()
	await wait_frames(1)
