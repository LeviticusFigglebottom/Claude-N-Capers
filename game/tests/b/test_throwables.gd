## D-073 (B6-08): the A3-12 throwables. The defs load with the contract fields ENV A reads (ThrowableDef `kind`,
## `count`, `damage`, `radius_m`, `fuse_s`, D-069 `anim_set`), their strings exist, and the loadout picker offers
## the four and never the perk-deck items.
extends TestCase

const FOUR: Array[StringName] = [&"throwable.frag", &"throwable.concussion", &"throwable.incendiary",
	&"throwable.throwing_knife"]
## Kinds named in the ThrowableDef contract comment (the A3-12 runtime switches on them).
const KINDS: Dictionary = {
	&"throwable.frag": &"frag", &"throwable.concussion": &"concussion", &"throwable.incendiary": &"incendiary",
	&"throwable.throwing_knife": &"throwing_knife",
}
const PERK_ITEMS: Array[StringName] = [&"throwable.boss_injector", &"throwable.gas_dispenser", &"throwable.leech_ampule",
	&"throwable.pocket_ecm", &"throwable.smoke_bomb", &"throwable.steady_flask"]


func after_all() -> void:
	SaveService.delete_profile(7)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_defs_load_with_the_fields_a_reads() -> void:
	for id: StringName in FOUR:
		var d: ThrowableDef = ContentDB.throwable(id)
		assert_true(d != null, "%s loads" % id)
		if d == null:
			continue
		assert_eq(d.id, id)
		assert_eq(d.kind, KINDS[id], "%s kind" % id)
		assert_eq(d.count, 3, "%s count (CrewWeapons.throwable_count)" % id)
		assert_eq(d.anim_set, &"throwable", "%s D-069 anim_set" % id)
		assert_true(d.damage >= 0.0 and d.radius_m >= 0.0 and d.fuse_s >= 0.0, "%s non-negative" % id)


func test_values() -> void:
	var frag: ThrowableDef = ContentDB.throwable(&"throwable.frag")
	assert_near(frag.damage, 1600.0, 0.01, "frag ~1,600 over the radius")
	assert_near(frag.radius_m, 5.0, 0.01)
	assert_near(frag.fuse_s, 2.5, 0.01)
	assert_eq(ContentDB.throwable(&"throwable.concussion").damage, 0.0, "concussion stuns only")
	assert_true(ContentDB.throwable(&"throwable.concussion").radius_m > frag.radius_m, "stun reaches further")
	var fire: ThrowableDef = ContentDB.throwable(&"throwable.incendiary")
	assert_true(fire.radius_m > 0.0, "fire pool radius")
	assert_true(fire.damage > 0.0 and fire.damage <= 60.0, "A3-12 reads damage as the pool's burn DPS, not a burst")
	var knife: ThrowableDef = ContentDB.throwable(&"throwable.throwing_knife")
	assert_eq(knife.radius_m, 0.0, "single target")
	assert_eq(knife.fuse_s, 0.0, "hits on impact")
	assert_true(knife.damage >= 1000.0, "high single-target damage")


func test_strings_exist() -> void:
	for id: StringName in FOUR:
		for suffix: String in ["name", "desc"]:
			var key: StringName = StringName("item.%s.%s" % [id, suffix])
			assert_ne(UiText.t(key), String(key), "%s exists" % key)
	assert_eq(UiText.item_key(&"throwable.frag"), &"item.throwable.frag.name")


func test_gate_excludes_perk_items() -> void:
	assert_eq(ThrowableGate.perk_item_ids(), PERK_ITEMS, "granted by perk cards")
	var ids: Array[StringName] = []
	for d: ThrowableDef in ThrowableGate.pickable():
		ids.append(d.id)
	for id: StringName in FOUR:
		assert_has(ids, id)
		assert_true(ThrowableGate.is_pickable(id))
	for id: StringName in PERK_ITEMS:
		assert_false(ids.has(id), "%s is perk-only" % id)
		assert_false(ThrowableGate.is_pickable(id))
	assert_false(ThrowableGate.is_pickable(&"throwable.nope"))


func test_picker_offers_the_four() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	var p: PlayerProfile = PlayerProfile.new_default()
	p.loadout.throwable = &"throwable.steady_flask"  # a stale perk item in the loadout is not offered
	var ls: LoadoutScreen = (load("res://content/ui/menus/loadout.tscn") as PackedScene).instantiate() as LoadoutScreen
	ls.profile_slot = 7
	ls.setup(p)
	add_child(ls)
	await wait_frames(1)
	var offered: Array[StringName] = ls.option_ids(ls.throwable_option)
	assert_eq(offered[0], &"", "none first")
	assert_eq(offered.size(), 5)
	for id: StringName in FOUR:
		assert_has(offered, id)
	for id: StringName in PERK_ITEMS:
		assert_false(offered.has(id), "%s not offered" % id)
	assert_eq(ls.current_loadout().throwable, &"", "the perk item falls back to none")
	assert_has(ls.focus_chain, ls.throwable_option as Control)
	ls.throwable_option.select(offered.find(&"throwable.frag"))
	assert_eq(ls.current_loadout().throwable, &"throwable.frag", "rides the launch loadout")
	assert_eq(ls.save(), OK)
	assert_eq(SaveService.load_profile(7).loadout.throwable, &"throwable.frag")
	ls.queue_free()
	await wait_frames(1)
