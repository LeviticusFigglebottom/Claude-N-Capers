## L6.2 bot crew (PD2 Crew Management): one ability and one boost per bot, picked on the crew screen, saved in the bot's
## crew_loadouts entry (ability / boost, missing = none) and written to the bot's launch Loadout (bot_ability /
## bot_boost) for ENV A's BotCrew.
extends TestCase

const SLOT: int = 0


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	OnboardingTips.persist = false


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_entry_validation_and_launch_loadout() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(CrewLoadouts.abilities().size(), 4)
	assert_eq(CrewLoadouts.boosts().size(), 5)
	var e: Dictionary = CrewLoadouts.empty_entry()
	e["ability"] = &"bot_ability.inspire"
	e["boost"] = &"bot_boost.ammo"
	CrewLoadouts.set_entry(p, 1, e)
	var l: Loadout = CrewLoadouts.bot_loadout(1, p, &"")
	assert_eq(l.bot_ability, &"bot_ability.inspire", "the ability reaches the launch Loadout")
	assert_eq(l.bot_boost, &"bot_boost.ammo")
	var bad: Dictionary = CrewLoadouts.empty_entry()
	bad["ability"] = &"bot_boost.ammo"  # a boost in the ability field
	bad["boost"] = &"bot_boost.nope"
	var v: Dictionary = CrewLoadouts.validate(p, bad)
	assert_eq(v["ability"], &"", "wrong kind -> none")
	assert_eq(v["boost"], &"", "unknown id -> none")
	assert_eq(CrewLoadouts.bot_loadout(0, p, &"").bot_ability, &"", "an empty bot carries none")
	var s: Array = CrewLoadouts.summary(p)
	assert_eq(String((s[1] as Dictionary)["ability"]), "bot_ability.inspire", "the lobby summary carries it")


func test_save_round_trip_and_old_entries() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var e: Dictionary = CrewLoadouts.empty_entry()
	e["boost"] = &"bot_boost.health"
	CrewLoadouts.set_entry(p, 2, e)
	SaveService.save_profile(p, SLOT)
	var back: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(CrewLoadouts.entry(back, 2)["boost"], &"bot_boost.health", "saved and loaded")
	var d: Dictionary = p.to_dict()
	for entry: Variant in d["crew_loadouts"] as Array:
		(entry as Dictionary).erase("ability")
		(entry as Dictionary).erase("boost")
	var old: PlayerProfile = PlayerProfile.from_dict(ProfileSchema.sanitize(d))
	assert_eq(CrewLoadouts.entry(old, 2)["boost"], &"", "a v10 entry without the fields reads none")


func test_crew_screen_rows() -> void:
	SaveService.delete_profile(SLOT)
	var p: PlayerProfile = PlayerProfile.new_default()
	SaveService.save_profile(p, SLOT)
	var cs: CrewScreen = (load("res://content/ui/crew/crew_screen.tscn") as PackedScene).instantiate() as CrewScreen
	cs.setup(p, SLOT)
	add_child(cs)
	await wait_frames(2)
	assert_true(cs.rows.has("ability") and cs.rows.has("boost"), "ability and boost rows")
	assert_eq((cs.rows["ability"] as ItemSlot).item_count, 5, "None + 4 abilities")
	assert_eq((cs.rows["boost"] as ItemSlot).item_count, 6, "None + 5 boosts")
	cs.select_bot(1)
	assert_true(cs.pick("ability", &"bot_ability.quick") and cs.pick("boost", &"bot_boost.carry"))
	var saved: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(CrewLoadouts.entry(saved, 1)["ability"], &"bot_ability.quick", "saved at once")
	assert_eq(CrewLoadouts.entry(saved, 1)["boost"], &"bot_boost.carry")
	assert_true(cs.summary_labels[1].text.contains(UiText.t(&"item.bot_ability.quick.name")), "the bot's card shows it")
	cs.queue_free()
	await wait_frames(2)
