## D-126 (PO playtest): the secondary slot holds pistols, SMGs and shotguns. Every shotgun is a secondary; the loadout's
## secondary list shows the whole slot from a fresh profile (owned ones pickable, the rest disabled with their level or
## "buy in the Workshop"); a save with a secondary-slot weapon equipped as its primary moves it over.
extends TestCase

const SHOTGUNS: Array[StringName] = [&"weapon.plowman_12", &"weapon.brute_12", &"weapon.harrow_12", &"weapon.reaper_db",
		&"weapon.mule_12"]


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_every_smg_and_shotgun_is_a_secondary() -> void:
	var n: int = 0
	for w: WeaponDef in ContentDB.all_weapons():
		var c: int = int(w.weapon_class)
		if w.anim_set == &"akimbo":
			continue  # PD2 akimbo pairs stay primaries
		if c == Enums.WeaponClass.SMG or c == Enums.WeaponClass.SHOTGUN or c == Enums.WeaponClass.PISTOL:
			assert_eq(int(w.slot), int(Enums.WeaponSlot.SECONDARY), "%s is a secondary" % w.id)
			n += 1
	assert_true(n >= 16, "pistols + SMGs + shotguns checked: %d" % n)
	for id: StringName in SHOTGUNS:
		assert_eq(int(ContentDB.weapon(id).slot), int(Enums.WeaponSlot.SECONDARY), "%s" % id)


func test_fresh_profile_loadout_lists_the_whole_secondary_slot() -> void:
	SaveService.delete_profile(0)
	var s: LoadoutScreen = (load("res://content/ui/menus/loadout.tscn") as PackedScene).instantiate() as LoadoutScreen
	var p: PlayerProfile = PlayerProfile.new_default()
	s.setup(p)
	add_child(s)
	await wait_frames(1)
	var o: ItemSlot = s.weapon_option
	var classes: Array[int] = []
	var enabled: Array[StringName] = []
	for i: int in range(o.item_count):
		var id: StringName = StringName(o.get_item_metadata(i))
		var w: WeaponDef = ContentDB.weapon(id)
		assert_eq(int(w.slot), int(Enums.WeaponSlot.SECONDARY), "%s listed as a secondary" % id)
		if not classes.has(int(w.weapon_class)):
			classes.append(int(w.weapon_class))
		if not o.is_item_disabled(i):
			enabled.append(id)
			assert_true(p.owned_weapons.has(id), "%s pickable only when owned" % id)
		else:
			assert_true(o.get_item_text(i).contains(str(w.unlock_level)) or o.get_item_text(i).contains("Workshop"),
					"%s says what it takes: %s" % [id, o.get_item_text(i)])
	assert_eq(classes.slice(0, 3), [Enums.WeaponClass.PISTOL, Enums.WeaponClass.SMG, Enums.WeaponClass.SHOTGUN]
			as Array[int], "pistols, then SMGs, then shotguns")
	assert_true(enabled.has(p.loadout.secondary), "the equipped secondary is pickable")
	for i: int in range(o.item_count):
		var w: WeaponDef = ContentDB.weapon(StringName(o.get_item_metadata(i)))
		assert_eq(o.get_item_glyph(i), LoadoutScreen.class_glyph(int(w.weapon_class)), "%s class icon" % w.id)
	assert_eq(LoadoutScreen.class_glyph(Enums.WeaponClass.SMG), &"smg")
	assert_eq(LoadoutScreen.class_glyph(Enums.WeaponClass.SHOTGUN), &"shotgun")
	var picker: ItemPicker = o.open_picker()
	await wait_frames(2)
	var locks: Array[Node] = picker.find_children("Lock", "Label", true, false)
	assert_true(locks.size() >= o.item_count - enabled.size(), "every locked tile puts its lock on a second line")
	picker.queue_free()
	assert_eq(s._selected_id(o), p.loadout.secondary, "and selected")
	s.queue_free()
	await wait_frames(1)


func test_weapons_move_to_their_slot_on_load() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.owned_weapons = [&"weapon.kestrel_p9", &"weapon.plowman_12", &"weapon.corsair_ar"] as Array[StringName]
	p.loadout.primary = &"weapon.plowman_12"
	p.loadout.secondary = &"weapon.kestrel_p9"
	var notes: Array[String] = ProfileValidator.validate(p)
	assert_eq(p.loadout.primary, &"weapon.corsair_ar", "the starter AR takes the primary slot")
	assert_eq(p.loadout.secondary, &"weapon.plowman_12", "the shotgun is the secondary now")
	assert_true(" ".join(notes).contains("D-126"), "noted: %s" % [notes])
	var q: PlayerProfile = PlayerProfile.new_default()
	q.owned_weapons = [&"weapon.plowman_12"] as Array[StringName]
	q.loadout.primary = &"weapon.plowman_12"
	ProfileValidator.validate(q)
	assert_eq(q.loadout.primary, &"", "no primary owned: the slot is empty (buy one in the Workshop)")
	var r: PlayerProfile = PlayerProfile.new_default()
	r.loadout.secondary = &"weapon.corsair_ar"
	ProfileValidator.validate(r)
	assert_eq(int(ContentDB.weapon(r.loadout.secondary).slot), int(Enums.WeaponSlot.SECONDARY), "a primary leaves")
