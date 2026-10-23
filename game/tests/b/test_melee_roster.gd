## P5 armory melee (LEAD r280 queue (2)): the launch roster of 12 MeleeDefs (pd2_fidelity P5), PD2-shaped trade-offs
## (L3.9: charge, knockdown, silent; concealment counts, S2.4), strings, and the loadout picker lists them all.
extends TestCase

const SETS: Array[StringName] = [&"melee_knife", &"melee_blunt", &"melee_blade"]
## ENV D's arms rigs pick each set's charge_start length from the first def whose id holds one of these fragments
## (tools/blender/characters/_arms_sets.py MELEE_MATCH); every def must be found under its own set.
const MELEE_MATCH: Dictionary = {
	&"melee_knife": ["knife", "dagger", "shank"],
	&"melee_blunt": ["baton", "bat", "club", "hammer", "pipe", "crowbar", "wrench"],
	&"melee_blade": ["machete", "sword", "katana", "axe", "cleaver"],
}


func before_all() -> void:
	ContentDB.clear_cache()


func _all() -> Array[MeleeDef]:
	var out: Array[MeleeDef] = []
	for r: Variant in ContentDB.all_melees():
		out.append(r as MeleeDef)
	return out


func test_twelve_melees_cover_every_set() -> void:
	var defs: Array[MeleeDef] = _all()
	assert_eq(defs.size(), 12, "pd2_fidelity P5: 12 melee at launch")
	var per_set: Dictionary = {}
	for d: MeleeDef in defs:
		assert_true(SETS.has(d.anim_set), "%s: anim_set %s is a D-069 melee set" % [d.id, d.anim_set])
		per_set[d.anim_set] = int(per_set.get(d.anim_set, 0)) + 1
		var hit: bool = false
		for frag: Variant in MELEE_MATCH.get(d.anim_set, []) as Array:
			hit = hit or String(d.id).contains(String(frag))
		assert_true(hit, "%s: the id names its set (the arms rigs match by id fragment)" % d.id)
	for s: StringName in SETS:
		assert_true(int(per_set.get(s, 0)) >= 3, "%s has at least 3 melees (%d)" % [s, int(per_set.get(s, 0))])


func test_values_are_pd2_shaped() -> void:
	for d: MeleeDef in _all():
		assert_eq(String(d.id), "melee." + d.resource_path.get_file().get_basename(), "%s: id matches the file" % d.id)
		assert_true(d.damage > 0.0 and d.charged_damage > d.damage, "%s: a charged hit beats a quick one" % d.id)
		assert_near(d.charge_time_s, 1.0, 0.001, "%s: charge 1 s (the arms rigs' charge_start clip)" % d.id)
		assert_true(d.knockdown >= 0.0 and d.knockdown <= 1.0, "%s: knockdown is a chance" % d.id)
		assert_true(d.concealment >= 15 and d.concealment <= 30, "%s: concealment within PD2's 30 cap" % d.id)
		assert_true(d.range_m >= 1.5 and d.range_m <= 2.3, "%s: reach %.2f m" % [d.id, d.range_m])
		assert_true(d.silent, "%s: PD2 melee kills are silent" % d.id)
		assert_true(d.unlock_level >= 0 and d.unlock_level <= 100, "%s: unlock level %d (D-155)" % [d.id, d.unlock_level])
	# The trade-off: blunt knocks down more than blades and knives, knives keep the best concealment.
	var avg: Dictionary = {}
	for s: StringName in SETS:
		var kd: float = 0.0
		var conc: float = 0.0
		var n: int = 0
		for d: MeleeDef in _all():
			if d.anim_set == s:
				kd += d.knockdown
				conc += d.concealment
				n += 1
		avg[s] = Vector2(kd / n, conc / n)
	assert_true((avg[&"melee_blunt"] as Vector2).x > (avg[&"melee_blade"] as Vector2).x, "blunt knocks down more")
	assert_true((avg[&"melee_blade"] as Vector2).x > (avg[&"melee_knife"] as Vector2).x, "blades knock down more than knives")
	assert_near((avg[&"melee_knife"] as Vector2).y, 30.0, 0.001, "knives are fully concealable")


func test_every_melee_has_strings() -> void:
	for d: MeleeDef in _all():
		for suffix: String in ["name", "desc"]:
			var key: String = "item.%s.%s" % [String(d.id), suffix]
			var text: String = UiText.t(StringName(key))
			assert_true(text != key and text != "", "%s has text" % key)
		assert_eq(UiText.t(UiText.item_key(d.id)), d.display_name, "%s: display_name matches strings.csv" % d.id)


func test_loadout_picker_lists_them() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	SaveService.delete_profile(0)
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(flow)
	await wait_frames(4)
	flow.show_hub()
	flow.open_station(&"armory")
	await wait_frames(4)
	var slot: ItemSlot = flow.loadout_screen.melee_option
	assert_eq(slot.item_count, 12, "the melee slot offers all 12")
	var names: PackedStringArray = PackedStringArray()
	for i: int in range(slot.item_count):
		names.append(slot.get_item_text(i))
	for d: MeleeDef in _all():
		var listed: bool = false
		for n: String in names:
			listed = listed or n.begins_with(d.display_name)
		assert_true(listed, "%s listed (locked ones carry their level)" % d.display_name)
	var ls: LoadoutScreen = flow.loadout_screen
	assert_false(ls.melee_info.visible, "no melee card until the melee picker previews")
	var picker: ItemPicker = slot.open_picker()
	await wait_frames(2)
	for i: int in range(slot.item_count):
		if slot.get_item_metadata(i) == &"melee.sledgehammer":  # locked at level 1: previews all the same
			picker.tiles[i].grab_focus()
	await wait_frames(2)
	assert_true(ls.melee_info.visible, "the melee card shows the focused melee")
	assert_true(ls.melee_info_title.text.contains("Sledgehammer") and ls.melee_info_stats.text.contains("350")
			and ls.melee_info_stats.text.contains("90%") and ls.melee_info_desc.text != "",
			"card: %s / %s" % [ls.melee_info_title.text, ls.melee_info_stats.text])
	picker.close()
	await wait_frames(2)
	assert_false(ls.melee_info.visible, "the card hides when the picker closes")
	flow.queue_free()
	await wait_frames(2)
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR
