## B4-15: masks batch (pd2_fidelity P8 / P9). New colour pairs, patterns and materials load; colours
## respect the albedo floor; the six new presets resolve; locked presets drop from payday cards or
## unlock ids; ENV D base request slots stay hidden until their glb exists; every new pattern id
## builds a mask without errors.
extends TestCase

const NEW_COLORS: Array[StringName] = [&"mask_colors.tide_coral", &"mask_colors.saffron_plum",
	&"mask_colors.frost_slate", &"mask_colors.oxblood_brass", &"mask_colors.mint_graphite", &"mask_colors.sulfur_ash"]
const NEW_PATTERNS: Array[StringName] = [&"mask_pattern.scales", &"mask_pattern.circuit", &"mask_pattern.prowl",
	&"mask_pattern.halftone", &"mask_pattern.crackle", &"mask_pattern.starburst"]
const NEW_MATERIALS: Array[StringName] = [&"mask_material.porcelain", &"mask_material.ink_lacquer",
	&"mask_material.stipple"]
const NEW_PRESETS: Array[StringName] = [&"mask.porcelain_vigil", &"mask.tide_runner", &"mask.night_circuit",
	&"mask.sulfur_brute", &"mask.oxblood_herald", &"mask.paper_saint"]
const REQUESTED_BASES: Array[StringName] = [&"mask_base.skull", &"mask_base.theatre", &"mask_base.gasmask",
	&"mask_base.demon", &"mask_base.goalie"]
const SHIPPED_BASES: Array[StringName] = [&"mask_base.heron", &"mask_base.visage", &"mask_base.vulpine",
	&"mask_base.bruiser", &"mask_base.owl"]
const FLOOR: float = 0.119

var _screen: MaskScreen


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_each() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
		await wait_frames(1)
	_screen = null
	Log.capture = false
	Log.captured.clear()


func after_all() -> void:
	SaveService.delete_profile(7)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_new_parts_load() -> void:
	for id: StringName in NEW_COLORS:
		assert_true(MaskCatalog.part(id) is MaskColorDef, "colour pair %s" % id)
	for id: StringName in NEW_PATTERNS:
		assert_true(MaskCatalog.part(id) is MaskPatternDef, "pattern %s" % id)
	for id: StringName in NEW_MATERIALS:
		var m: MaskMaterialDef = MaskCatalog.part(id) as MaskMaterialDef
		assert_true(m != null, "material %s" % id)
		assert_true(ResourceLoader.exists("res://world/materials/%s.tres" % m.material_id),
			"%s wraps an existing library material (%s)" % [id, m.material_id])
		assert_eq(m.library_material.resource_path, "res://world/materials/%s.tres" % m.material_id)
	assert_true(MaskCatalog.parts(MaskCatalog.COLORS).size() >= 16)
	assert_true(MaskCatalog.parts(MaskCatalog.PATTERN).size() >= 14)
	assert_true(MaskCatalog.parts(MaskCatalog.MATERIAL).size() >= 12)


func test_new_colours_meet_albedo_floor() -> void:
	for p: MaskPartDef in MaskCatalog.all_parts(MaskCatalog.COLORS):
		var c: MaskColorDef = p as MaskColorDef
		for col: Color in [c.color_a, c.color_b]:
			assert_true(col.r >= FLOOR and col.g >= FLOOR and col.b >= FLOOR, "%s: %s under the floor" % [c.id, col])
	for md: MaskDef in MaskCatalog.presets():
		for col: Color in [md.color_a, md.color_b]:
			assert_true(col.r >= FLOOR and col.g >= FLOOR and col.b >= FLOOR, "%s: %s under the floor" % [md.id, col])


func test_procedural_ids_are_unique_and_in_shader() -> void:
	var seen: Dictionary = {}
	for p: MaskPartDef in MaskCatalog.all_parts(MaskCatalog.PATTERN):
		var proc: int = int((p as MaskPatternDef).procedural)
		assert_false(seen.has(proc), "%s reuses procedural %d" % [p.id, proc])
		seen[proc] = true
	assert_eq(MaskPatternDef.Procedural.size(), 23)  # round 244: +6, RT-B1: +2, AH-B1: +1 achievement-part fallbacks
	var code: String = (load(MaskComposer.SHADER_PATH) as Shader).code
	for i: int in range(1, MaskPatternDef.Procedural.size()):
		assert_true(code.contains("pattern == %d)" % i), "shader draws procedural %d" % i)


func test_presets_resolve_via_catalog() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	for id: StringName in NEW_PRESETS:
		var md: MaskDef = MaskCatalog.resolve(id, p)
		assert_true(md != null, "%s resolves" % id)
		if md == null:
			continue
		assert_true(md.model != null, "%s uses its base's ENV D mesh" % id)
		var comp: Dictionary = MaskComposer.composition_of(md)
		for k: String in MaskCatalog.KINDS:
			assert_true(MaskCatalog.has_part(StringName(String(comp[k]))), "%s: %s part '%s' resolves" % [id, k, comp[k]])
		assert_true(MaskComposer.compose(comp, id) != null, "%s re-composes" % id)
		assert_eq(MaskCatalog.from_descriptor(MaskCatalog.descriptor(id, p)), md, "%s descriptor round trip" % id)
		assert_ne(MaskCatalog.display_name(id), String(UiText.item_key(id)), "%s has a name string" % id)


func test_locked_presets() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var circuit: MaskDef = ContentDB.mask(&"mask.night_circuit") as MaskDef
	var herald: MaskDef = ContentDB.mask(&"mask.oxblood_herald") as MaskDef
	assert_eq(circuit.unlock, MaskCatalog.UNLOCK_PAYDAY)
	assert_true(String(herald.unlock).begins_with(MaskCatalog.UNLOCK_ACHIEVEMENT_PREFIX))
	for id: StringName in [circuit.id, herald.id]:
		assert_false(MaskLocker.is_equippable(p, id), "%s starts locked" % id)
		assert_false(MaskLocker.available_ids(p).has(id))
		assert_false(MaskLocker.equip(p, id))
	var pool: Array[StringName] = PaydayCards.pool(PaydayCards.MASK_PART, p)
	assert_has(pool, circuit.id, "payday preset drops from mask cards")
	assert_false(pool.has(herald.id), "achievement presets never drop")
	assert_eq(PaydayCards.table().item_tier(circuit.id), 2, "rare drop")
	assert_true(PaydayCards.grant(p, {"type": PaydayCards.MASK_PART, "item_id": circuit.id}))
	assert_true(MaskLocker.equip(p, circuit.id))
	assert_false(PaydayCards.pool(PaydayCards.MASK_PART, p).has(circuit.id), "owned preset leaves the pool")
	assert_false(MaskLocker.grant_preset(p, circuit.id), "already owned")
	assert_false(MaskLocker.grant_preset(p, &"mask.gilded_heron"), "no unlock = nothing to grant")
	assert_eq(MaskLocker.grant_unlock(p, herald.unlock), [herald.id] as Array[StringName])
	assert_true(MaskLocker.is_equippable(p, herald.id))
	assert_eq(SaveService.save_profile(p, 7), OK)
	var q: PlayerProfile = SaveService.load_profile(7)
	assert_has(q.owned_masks, circuit.id)
	assert_has(q.owned_masks, herald.id)
	assert_eq(PaydayCardView.detail_text({"type": PaydayCards.MASK_PART, "item_id": circuit.id}),
		UiText.t(&"ui.payday_cards.mask_kind.preset"))


func test_requested_bases_hidden_until_glb_exists() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var visible: Array[MaskPartDef] = MaskCatalog.parts(MaskCatalog.BASE)
	for id: StringName in REQUESTED_BASES:
		assert_true(MaskCatalog.is_known(id), "%s slot is in the data" % id)
		var b: MaskBaseDef = MaskCatalog.part(id) as MaskBaseDef
		assert_true(b.requires_model, "%s waits for ENV D" % id)
		var short: String = String(id).trim_prefix("mask_base.")
		assert_eq(b.model_path, "res://assets/masks/mask_base_%s/mask_base_%s.glb" % [short, short])
		var shipped: bool = ResourceLoader.exists(b.model_path)
		assert_eq(MaskCatalog.is_available(id), shipped, "%s available exactly when its glb exists" % id)
		assert_eq(visible.has(b), shipped, "%s in pickers only when shipped" % id)
		if shipped:
			continue
		assert_false(MaskCatalog.has_part(id))
		assert_false(PaydayCards.pool(PaydayCards.MASK_PART, null).has(id), "%s never drops" % id)
		assert_false(MaskLocker.grant_part(p, id), "%s cannot be granted" % id)
		var comp: Dictionary = MaskComposer.normalized(MaskCatalog.tweak().default_composition)
		comp[MaskCatalog.BASE] = String(id)
		assert_false(MaskComposer.validate(comp).is_empty(), "%s cannot be composed" % id)
	for id: StringName in SHIPPED_BASES:
		assert_true(MaskCatalog.is_available(id), "%s visible" % id)
	# The rule lights a slot up as soon as the file exists (a shipped glb stands in for ENV D's).
	var probe: MaskBaseDef = MaskBaseDef.new()
	probe.requires_model = true
	probe.model_path = "res://assets/masks/mask_base_owl/mask_base_owl.glb"
	assert_true(MaskCatalog.part_available(probe))
	probe.model_path = "res://assets/masks/mask_base_nope/mask_base_nope.glb"
	assert_false(MaskCatalog.part_available(probe))
	probe.requires_model = false
	assert_true(MaskCatalog.part_available(probe), "placeholder bases stay available")


func test_mask_screen_pickers_hide_requested_bases() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	_screen = (load("res://content/ui/masks/mask_screen.tscn") as PackedScene).instantiate() as MaskScreen
	_screen.profile_slot = 7
	_screen.setup(p)
	add_child(_screen)
	await wait_frames(1)
	var listed: Array[String] = []
	var o: OptionButton = _screen.part_options[MaskCatalog.BASE] as OptionButton
	for i: int in range(o.item_count):
		listed.append(String(o.get_item_metadata(i)))
	for id: StringName in SHIPPED_BASES:
		assert_has(listed, String(id))
	for id: StringName in REQUESTED_BASES:
		if not MaskCatalog.is_available(id):
			assert_false(listed.has(String(id)), "%s hidden in the picker" % id)
			assert_false(_screen.set_part(MaskCatalog.BASE, id))
	var pats: OptionButton = _screen.part_options[MaskCatalog.PATTERN] as OptionButton
	assert_eq(pats.item_count, MaskCatalog.parts(MaskCatalog.PATTERN).size(), "every pattern listed")
	assert_true(_screen.list_buttons.has(&"mask.porcelain_vigil"), "unlocked new preset listed")
	assert_false(_screen.list_buttons.has(&"mask.night_circuit"), "locked preset not listed")
	assert_true(_screen.select_mask(&"mask.tide_runner"))
	assert_eq(String(_screen.draft[MaskCatalog.PATTERN]), "mask_pattern.scales")


func test_card_pool_includes_new_parts() -> void:
	var pool: Array[StringName] = PaydayCards.pool(PaydayCards.MASK_PART, PlayerProfile.new_default())
	var earned: Dictionary = Achievements.all_reward_ids()
	for id: StringName in NEW_COLORS + NEW_PATTERNS + NEW_MATERIALS:
		if MaskCatalog.part(id).default_owned:
			assert_false(pool.has(id), "%s is default-owned" % id)
		elif earned.has(id):
			assert_false(pool.has(id), "%s is an achievement reward" % id)
		else:
			assert_has(pool, id, "%s drops from payday cards" % id)
	var t: PaydayCardsTable = PaydayCards.table()
	assert_eq(t.item_tier(&"mask_pattern.starburst"), 2)
	assert_eq(t.item_tier(&"mask_material.porcelain"), 2)
	assert_eq(t.item_tier(&"mask_base.skull"), 2, "request slots carry their tier ahead of the mesh")


func test_strings_for_every_part_and_preset() -> void:
	var table: Dictionary = StringTable.parse_csv()
	for k: String in MaskCatalog.KINDS:
		for p: MaskPartDef in MaskCatalog.all_parts(k):
			assert_has(table, String(UiText.item_key(p.id)))
	for id: StringName in NEW_PRESETS:
		assert_has(table, "item.%s.name" % id)
		assert_has(table, "item.%s.desc" % id)
	assert_has(table, "ui.payday_cards.mask_kind.preset")


func test_every_pattern_builds_a_mask_without_errors() -> void:
	Log.capture = true
	Log.captured.clear()
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0, 0, -0.5)
	vp.add_child(cam)
	cam.look_at(Vector3.ZERO)
	for p: MaskPartDef in MaskCatalog.parts(MaskCatalog.PATTERN):
		var pat: MaskPatternDef = p as MaskPatternDef
		var comp: Dictionary = MaskComposer.normalized(MaskCatalog.tweak().default_composition)
		comp[MaskCatalog.PATTERN] = String(pat.id)
		var node: Node3D = MaskComposer.instantiate(MaskComposer.compose(comp))
		vp.add_child(node)
		var found: Array[Node] = node.find_children("*", "GeometryInstance3D", true, false)
		assert_false(found.is_empty(), "%s has a mesh" % pat.id)
		for g: Node in found:
			var sm: ShaderMaterial = (g as GeometryInstance3D).material_override as ShaderMaterial
			assert_true(sm != null and sm.shader != null, "%s: mask material" % pat.id)
			if sm != null:
				assert_eq(int(sm.get_shader_parameter(&"pattern")), int(pat.procedural), "%s: pattern id" % pat.id)
		await wait_frames(1)
		node.queue_free()
	await wait_frames(1)
	vp.queue_free()
	var errors: Array[String] = []
	for line: String in Log.captured:
		if line.begins_with("[ERROR]"):
			errors.append(line)
	assert_eq(errors, [] as Array[String], "no mask errors")
