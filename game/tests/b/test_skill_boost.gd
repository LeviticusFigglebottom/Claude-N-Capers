## D-106: armory / loadout stats with the player's skills and perk deck applied (SkillBoost), read like
## ENV A's CrewWeapons reads Modifiers (class qualifier: ".all" + ".<class>"), with a base toggle and
## boosted values marked.
extends TestCase

const CORSAIR: StringName = &"weapon.corsair_ar"
const HORNET: StringName = &"weapon.hornet_9"
const HARDBALL: StringName = &"skill.gunnery.hardball"  ## basic: +15 mag for SMG / LMG / AR
const LOADOUT_SCENE: PackedScene = preload("res://content/ui/menus/loadout.tscn")

var _screen: LoadoutScreen


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func after_each() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null
	await wait_frames(1)


func test_apply_reads_modifiers_like_the_runtime() -> void:
	var base: WeaponStats = LoadoutResolver.resolve_weapon(CORSAIR, [] as Array[StringName])
	var mods: Dictionary = {&"weapon.mag_extra.assault_rifle": 15, &"weapon.damage_mult.all": 1.1,
		&"weapon.reload_speed_mult.shotgun": 2.0, &"weapon.damage_mult": 3.0, &"weapon.reload_speed_mult.all": 1.25}
	var b: WeaponStats = SkillBoost.apply(base, ContentDB.weapon(CORSAIR), mods)
	assert_eq(b.mag_size, base.mag_size + 15, "class-qualified ADD")
	assert_near(b.damage, base.damage * 1.1, 0.0001, ".all MULT; the bare key is not read with a qualifier (Modifiers._collect)")
	assert_near(b.reload_time_s, base.reload_time_s / 1.25, 0.0001, "only the .all reload grant applies to an AR")
	assert_ne(b, base, "a copy")
	assert_eq(base.mag_size, LoadoutResolver.resolve_weapon(CORSAIR, [] as Array[StringName]).mag_size, "input untouched")
	assert_eq(SkillBoost.apply(base, ContentDB.weapon(CORSAIR), {}), base, "no grants: same stats")


func test_workshop_rows_boosted_by_default_with_a_base_toggle() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.loadout.skills = {HARDBALL: 1}
	var m: WorkshopModel = WorkshopModel.new(p)
	m.select_weapon(CORSAIR)
	assert_true(m.with_skills, "skills on by default")
	m.with_skills = false
	var base_mag: int = int((m.stat_rows()["shown"] as Dictionary)["mag"])
	m.with_skills = true
	var rows: Dictionary = m.stat_rows()
	assert_eq(int((rows["shown"] as Dictionary)["mag"]), base_mag + 15, "with skills by default")
	assert_has(rows["boosted"], "mag", "marked")
	assert_false(bool(((rows["delta"] as Dictionary)["mag"] as Dictionary)["changed"]), "deltas compare like with like")
	m.with_skills = false
	rows = m.stat_rows()
	assert_eq(base_mag, LoadoutResolver.resolve_weapon(CORSAIR, m.profile.loadout.primary_mods).mag_size, "base = resolved")
	assert_true((rows["boosted"] as Array).is_empty())


func test_loadout_screen_marks_boosted_and_toggles() -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.owned_weapons.append(HORNET)
	p.loadout.secondary = HORNET
	p.loadout.secondary_mods = [] as Array[StringName]
	p.loadout.skills = {HARDBALL: 1}
	_screen = LOADOUT_SCENE.instantiate() as LoadoutScreen
	_screen.setup(p)
	add_child(_screen)
	await wait_frames(1)
	_screen.refresh()
	var mag: Label = _screen.get(&"_stat_value_labels")["mag"] as Label
	var base_mag: int = LoadoutResolver.resolve_weapon(HORNET, [] as Array[StringName]).mag_size
	assert_eq(mag.text, UiText.t(&"ui.stats.boosted_value", {"value": str(base_mag + 15)}), "SMG +15, marked")
	assert_true(_screen.boosted_legend.visible, "legend explains the mark")
	assert_has(_screen.focus_chain, _screen.stats_mode_button as Control, "the toggle is reachable by pad")
	_screen.stats_mode_button.pressed.emit()
	assert_eq(mag.text, str(base_mag), "base values")
	assert_false(_screen.boosted_legend.visible)
	assert_eq(_screen.stats_mode_button.text, UiText.t(&"ui.stats.base"))
