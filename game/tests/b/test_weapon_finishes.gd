## B7-04: weapon finishes. Data (12 finishes, strings, recipes, unlock ids), FinishApplier overrides on the
## right surfaces (model, akimbo offhand, mods when covered) with the stock look restored, no shared material
## mutated, ownership (locked finishes cannot be equipped), persistence through PlayerProfile.weapon_finishes
## when the field exists, the workshop picker (preview + equip), and the loadout / lobby summary carry.
extends TestCase

const CORSAIR: StringName = &"weapon.corsair_ar"
const PAIR: StringName = &"weapon.akimbo_warden_45"
const SUPPRESSOR: StringName = &"mod.corsair_suppressor"
const GUNMETAL: StringName = &"finish.gunmetal_blue"
const ARCTIC: StringName = &"finish.arctic"
const CASE: StringName = &"finish.case_hardened"
const CARBON: StringName = &"finish.carbon"
const GILDED: StringName = &"finish.gilded_ledger"
const WORKSHOP: String = "res://content/ui/workshop/workshop_screen.tscn"
const EXPECTED: Array[String] = [
	"gunmetal_blue", "desert_tan", "olive_drab", "arctic", "cherry_polymer", "carbon", "urban_camo",
	"midnight_chrome", "copper_patina", "case_hardened", "brass_engraved", "gilded_ledger",
]

var _nodes: Array[Node] = []


## A profile type that has the save-v7 field (B7-01), for trees where PlayerProfile does not yet.
class FieldProfile:
	extends PlayerProfile
	var weapon_finishes: Dictionary = {}


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(1)


func _visual(weapon_id: StringName, mods: Array[StringName] = []) -> WeaponVisual:
	var v: WeaponVisual = WeaponVisual.new()
	add_child(v)
	_nodes.append(v)
	v.setup_ids(weapon_id, mods)
	return v


func _profile() -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	if not p.owned_weapons.has(CORSAIR):
		p.owned_weapons.append(CORSAIR)
	p.loadout.primary = CORSAIR
	p.loadout.primary_mods = []
	return p


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh != null:
			out.append(n as MeshInstance3D)
	if root is MeshInstance3D:
		out.append(root as MeshInstance3D)
	return out


## Every surface under `root` wears `def` exactly where its stock slot is covered, and nothing elsewhere.
func _assert_worn(root: Node, def: FinishDef, label: String) -> int:
	var worn: int = 0
	for mi: MeshInstance3D in _meshes(root):
		for i: int in range(mi.mesh.get_surface_count()):
			var slot: StringName = FinishApplier.slot_of(mi.mesh.surface_get_material(i))
			var want: bool = def != null and slot != &"" and def.layer_for(slot) != null
			var o: Material = mi.get_surface_override_material(i)
			if want:
				worn += 1
				assert_true(o != null and StringName(o.get_meta(FinishMaterials.META_FINISH, &"")) == def.id,
						"%s: %s/%d (%s) wears %s" % [label, mi.name, i, slot, def.id])
			else:
				assert_true(o == null, "%s: %s/%d (%s) keeps its stock material" % [label, mi.name, i, slot])
	return worn


func test_every_finish_has_strings_and_a_valid_recipe() -> void:
	var table: Dictionary = StringTable.parse_csv(StringTable.CSV_PATH, [] as Array[String])
	var all: Array[FinishDef] = WeaponFinishes.all()
	assert_eq(all.size(), EXPECTED.size(), "12 finishes")
	var defaults: int = 0
	for fname: String in EXPECTED:
		var d: FinishDef = WeaponFinishes.def(StringName("finish." + fname))
		assert_true(d != null, "finish.%s exists" % fname)
		if d == null:
			continue
		assert_eq(d.unlock, StringName("unlock.finish." + fname), "%s unlock id" % d.id)
		defaults += 1 if d.default_owned else 0
		for suffix: String in [".name", ".desc"]:
			assert_has(table, "item.%s%s" % [d.id, suffix], "%s has text" % d.id)
		assert_false(d.layers.is_empty(), "%s has a recipe" % d.id)
		for i: int in range(d.layers.size()):
			var l: FinishLayer = d.layers[i]
			assert_false(l.slots.is_empty(), "%s layer %d names slots" % [d.id, i])
			for s: StringName in l.slots:
				assert_true(FinishApplier.SLOT_MATERIALS.has(s), "%s: slot %s is finishable" % [d.id, s])
			assert_true(FinishMaterials.is_pattern(l.pattern), "%s: pattern %s" % [d.id, l.pattern])
			assert_true(l.pattern_scale > 0.0 and l.roughness >= 0.0 and l.roughness <= 1.0, "%s numbers" % d.id)
			var m: Material = FinishMaterials.material_for(d, i)
			assert_true(m is BaseMaterial3D and m.resource_path == "", "%s layer %d builds a runtime material" % [d.id, i])
	assert_true(defaults >= 2 and defaults <= 4, "a few finishes are owned by default (%d)" % defaults)
	for k: String in table.keys():
		if k.begins_with("ui.workshop.finish."):
			assert_true(String(table[k]).strip_edges() != "", k)


func test_finish_applies_to_the_right_surfaces_and_stock_comes_back() -> void:
	var v: WeaponVisual = _visual(CORSAIR)
	var d: FinishDef = WeaponFinishes.def(GUNMETAL)
	assert_true(v.apply_finish(GUNMETAL))
	assert_eq(v.finish_id, GUNMETAL)
	assert_true(_assert_worn(v.model, d, "gunmetal") > 0, "the Corsair has metal surfaces to finish")
	# A two-layer finish replaces metal and polymer with different materials.
	var g: FinishDef = WeaponFinishes.def(GILDED)
	v.apply_finish(GILDED)
	assert_true(_assert_worn(v.model, g, "gilded") > 0)
	assert_ne(FinishMaterials.material_for(g, 0), FinishMaterials.material_for(g, 1), "one material per layer")
	assert_true(v.apply_finish(&""), "stock")
	assert_eq(v.finish_id, &"")
	_assert_worn(v.model, null, "stock")
	assert_false(v.apply_finish(&"finish.nope"), "unknown id -> stock, false")
	_assert_worn(v.model, null, "unknown")


func test_finish_survives_setup_and_follows_the_loadout() -> void:
	var v: WeaponVisual = _visual(CORSAIR)
	v.apply_finish(GUNMETAL)
	v.setup_ids(CORSAIR, [SUPPRESSOR] as Array[StringName])
	_assert_worn(v.model, WeaponFinishes.def(GUNMETAL), "after a mod change")
	var l: Loadout = Loadout.new()
	l.primary = CORSAIR
	assert_eq(v.apply_loadout_finish(l), &"", "no weapon_finishes on the loadout -> stock")
	assert_eq(v.apply_loadout_finish(null), &"")
	if &"weapon_finishes" in l:
		l.set(&"weapon_finishes", {CORSAIR: CASE})
		assert_eq(v.apply_loadout_finish(l), CASE, "Loadout.weapon_finishes drives the visual")


func test_offhand_and_mods_follow_the_finish() -> void:
	var pair: WeaponVisual = _visual(PAIR)
	assert_true(pair.is_akimbo())
	pair.apply_finish(GUNMETAL)
	var d: FinishDef = WeaponFinishes.def(GUNMETAL)
	assert_eq(_assert_worn(pair.offhand, d, "offhand"), _assert_worn(pair.model, d, "main gun"), "both guns match")
	var v: WeaponVisual = _visual(CORSAIR, [SUPPRESSOR] as Array[StringName])
	var can: Node3D = v.attached.get(Enums.ModType.SUPPRESSOR) as Node3D
	assert_true(can != null, "suppressor attached")
	v.apply_finish(GUNMETAL)
	assert_true(_assert_worn(can, d, "covered mod") > 0, "covers_mods: the suppressor is finished")
	var case_def: FinishDef = WeaponFinishes.def(CASE)
	assert_false(case_def.covers_mods)
	v.apply_finish(CASE)
	_assert_worn(can, null, "uncovered mod")
	var base_worn: int = 0
	for mi: MeshInstance3D in _meshes(v.model):
		if not can.is_ancestor_of(mi):
			for i: int in range(mi.mesh.get_surface_count()):
				base_worn += 1 if FinishApplier.worn(mi, i) == CASE else 0
	assert_true(base_worn > 0, "the gun itself still wears case-hardened")


func test_no_shared_material_is_mutated() -> void:
	var v: WeaponVisual = _visual(CORSAIR, [SUPPRESSOR] as Array[StringName])
	var before: Array[Array] = []
	for mi: MeshInstance3D in _meshes(v):
		for i: int in range(mi.mesh.get_surface_count()):
			var m: Material = mi.mesh.surface_get_material(i)
			var bm: BaseMaterial3D = m as BaseMaterial3D
			before.append([mi.mesh, i, m, bm.albedo_color if bm != null else Color.BLACK,
					bm.roughness if bm != null else 0.0, bm.albedo_texture if bm != null else null])
	var carbon_layer: FinishLayer = WeaponFinishes.def(CARBON).layers[0]
	var lib: BaseMaterial3D = carbon_layer.base_material as BaseMaterial3D
	assert_true(lib != null, "carbon borrows C's library material")
	var lib_state: Array = [lib.albedo_color, lib.metallic, lib.roughness, lib.clearcoat]
	for id: StringName in [GUNMETAL, CARBON, GILDED, CASE, &""]:
		v.apply_finish(id)
	v.apply_finish(CARBON)
	for e: Array in before:
		var mesh: Mesh = e[0]
		var m: Material = mesh.surface_get_material(int(e[1]))
		assert_true(m == e[2], "mesh surface material unchanged")
		var bm: BaseMaterial3D = m as BaseMaterial3D
		if bm != null:
			assert_eq(bm.albedo_color, e[3])
			assert_eq(bm.roughness, e[4])
			assert_true(bm.albedo_texture == e[5])
	assert_eq([lib.albedo_color, lib.metallic, lib.roughness, lib.clearcoat], lib_state, "library material untouched")
	assert_true(FinishMaterials.material_for(WeaponFinishes.def(CARBON), 0) != lib, "a duplicate, not the library")
	var other: WeaponVisual = _visual(CORSAIR)
	_assert_worn(other.model, null, "a second Corsair stays stock")


func test_locked_finishes_cannot_be_equipped() -> void:
	var p: PlayerProfile = _profile()
	assert_true(WeaponFinishes.is_owned(p, GUNMETAL), "default owned")
	assert_false(WeaponFinishes.is_owned(p, ARCTIC), "locked")
	assert_false(WeaponFinishes.equip(p, CORSAIR, ARCTIC), "locked finish refused")
	assert_eq(WeaponFinishes.equipped(p, CORSAIR), &"")
	assert_false(WeaponFinishes.equip(p, CORSAIR, &"finish.nope"), "unknown finish refused")
	assert_false(WeaponFinishes.equip(p, &"weapon.nope", GUNMETAL), "unknown weapon refused")
	assert_true(WeaponFinishes.equip(p, CORSAIR, GUNMETAL))
	assert_eq(WeaponFinishes.equipped(p, CORSAIR), GUNMETAL)
	MaskLocker.grant_unlock(p, &"unlock.finish.arctic")
	assert_true(WeaponFinishes.equip(p, CORSAIR, ARCTIC), "unlocked by its unlock id")
	assert_eq(WeaponFinishes.equipped(p, CORSAIR), ARCTIC)
	p.unlocks.erase(&"unlock.finish.arctic")
	assert_eq(WeaponFinishes.equipped(p, CORSAIR), &"", "a finish no longer owned reads as stock")
	assert_true(WeaponFinishes.equip(p, CORSAIR, &""), "stock is always allowed")


func test_notoriety_and_sources() -> void:
	assert_eq(WeaponFinishes.source_of(GUNMETAL)["kind"], WeaponFinishes.SOURCE_DEFAULT)
	var src: Dictionary = WeaponFinishes.source_of(CASE)
	assert_eq(src["kind"], WeaponFinishes.SOURCE_NOTORIETY)
	assert_eq(int(src["rank"]), 10)
	assert_true(WorkshopFinishPanel.source_text(CASE).contains(Notoriety.roman(10)), "locked text names the rank")
	var p: PlayerProfile = _profile()
	p.notoriety = 10
	Notoriety.apply_rewards(p)
	assert_true(WeaponFinishes.is_owned(p, CASE), "Notoriety X grants case-hardened")
	assert_false(WeaponFinishes.is_owned(p, GILDED), "rank XXV not reached")
	for d: FinishDef in WeaponFinishes.all():
		var kind: StringName = WeaponFinishes.source_of(d.id)["kind"]
		assert_true(kind != WeaponFinishes.SOURCE_DEFAULT or d.default_owned, d.id)
		assert_true(WorkshopFinishPanel.source_text(d.id) != "", "%s has a source text" % d.id)


func test_finish_persists_when_the_field_exists() -> void:
	var p: PlayerProfile = _profile()
	if &"weapon_finishes" in p:
		assert_true(WeaponFinishes.persists(p))
		assert_true(WeaponFinishes.equip(p, CORSAIR, GUNMETAL))
		assert_eq(SaveService.save_profile(p, 0), OK)
		var back: PlayerProfile = SaveService.load_profile(0)
		assert_eq(WeaponFinishes.equipped(back, CORSAIR), GUNMETAL, "saved and loaded (save v7)")
	else:
		assert_false(WeaponFinishes.persists(p), "no save field yet (B7-01 adds it)")
		assert_true(WeaponFinishes.equip(p, CORSAIR, GUNMETAL), "kept in memory")
		assert_eq(WeaponFinishes.equipped(p, CORSAIR), GUNMETAL)
	var fp: FieldProfile = FieldProfile.new()
	fp.owned_weapons.append(CORSAIR)
	assert_true(WeaponFinishes.persists(fp))
	assert_true(WeaponFinishes.equip(fp, CORSAIR, GUNMETAL))
	assert_eq(StringName(fp.weapon_finishes.get(CORSAIR, &"")), GUNMETAL, "written to profile.weapon_finishes")
	assert_false(fp.has_meta(WeaponFinishes.PROFILE_FIELD), "no fallback when the field exists")


func test_picker_previews_and_equips() -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = _profile()
	var screen: WorkshopScreen = (load(WORKSHOP) as PackedScene).instantiate() as WorkshopScreen
	screen.setup(p)
	add_child(screen)
	_nodes.append(screen)
	await wait_frames(1)
	assert_eq(screen.model.weapon_id, CORSAIR)
	var panel: WorkshopFinishPanel = screen.finish_panel
	assert_eq(panel.list.item_count, WeaponFinishes.all().size() + 1, "stock + every finish")
	assert_true(screen.focus_chain.has(panel.list))
	assert_true(screen.select_finish(GUNMETAL))
	assert_eq(screen.stage.visual.finish_id, GUNMETAL, "live preview on the turntable")
	_assert_worn(screen.stage.visual.model, WeaponFinishes.def(GUNMETAL), "preview")
	assert_false(panel.equip_button.disabled)
	assert_true(screen.equip_finish())
	assert_eq(WeaponFinishes.equipped(p, CORSAIR), GUNMETAL, "equipped on the profile")
	assert_true(panel.equip_button.disabled, "already applied")
	# Locked finish: previews, but cannot be equipped.
	assert_true(screen.select_finish(ARCTIC))
	assert_eq(screen.stage.visual.finish_id, ARCTIC)
	assert_true(panel.equip_button.disabled)
	assert_false(screen.equip_finish())
	assert_eq(WeaponFinishes.equipped(p, CORSAIR), GUNMETAL)
	assert_true(panel.status_label.text != "")
	# Another weapon starts on its own (stock) finish; coming back shows the applied one.
	screen.select_weapon(PAIR)
	assert_eq(panel.preview_id, &"")
	assert_eq(screen.stage.visual.finish_id, &"")
	screen.select_weapon(CORSAIR)
	assert_eq(screen.stage.visual.finish_id, GUNMETAL)


func test_loadout_and_lobby_summary_carry_the_finish() -> void:
	var p: PlayerProfile = _profile()
	WeaponFinishes.equip(p, CORSAIR, GUNMETAL)
	assert_eq(WeaponFinishes.for_loadout(p, p.loadout), {CORSAIR: GUNMETAL})
	var s: Dictionary = LobbyState.summary_from(p.loadout, p)
	assert_eq((s["loadout"] as Dictionary)["weapon_finishes"], {String(CORSAIR): String(GUNMETAL)})
	var clean: Dictionary = LobbyState.sanitize_summary(JSON.parse_string(JSON.stringify(s)) as Dictionary)
	assert_eq((clean["loadout"] as Dictionary)["weapon_finishes"], {String(CORSAIR): String(GUNMETAL)}, "survives JSON")
	assert_eq(LobbyState.validate_summary(clean).size(), LobbyState.validate_summary(LobbyState.sanitize_summary(s)).size())
	var bad: Dictionary = WeaponFinishes.sanitize_map({"weapon.corsair_ar": "finish.nope", "weapon.nope": "finish.arctic", "x": 3})
	assert_true(bad.is_empty(), "unknown ids dropped")
	var l: Loadout = LobbyState.loadout_from_dict(clean["loadout"] as Dictionary)
	var resolved: Loadout = LoadoutResolver.resolve(p.loadout)
	if &"weapon_finishes" in l:
		assert_eq(WeaponFinishes.from_loadout(l, CORSAIR), GUNMETAL, "co-op launch loadout carries it")
		assert_true(WeaponFinishes.stamp(resolved, p))
		assert_eq(WeaponFinishes.from_loadout(resolved, CORSAIR), GUNMETAL, "solo launch loadout carries it")
	else:
		assert_false(WeaponFinishes.stamp(resolved, p), "no Loadout.weapon_finishes yet (contracts round 28)")
		assert_eq(WeaponFinishes.from_loadout(resolved, CORSAIR), &"")
