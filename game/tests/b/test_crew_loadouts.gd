## D-145.4 / PO-19: crew bot loadouts (CrewLoadouts). What a bot slot may equip (owned primaries + their owned mods,
## unlocked armors, wearable masks, unlocked heisters + heist suits), validation back to the defaults, A's for_slot
## API, the bot's launch Loadout, outfit preferences in the heister assignment, the solo launch options and the
## co-op lobby (host summary -> bot outfits and the AI cards' entries).
extends TestCase

const AR: StringName = &"weapon.corsair_ar"
const P9: StringName = &"weapon.kestrel_p9"
const CAN: StringName = &"mod.corsair_suppressor"
const SCOPE: StringName = &"mod.rail_prism_scope"
const REFLEX: StringName = &"mod.rail_reflex_sight"
const FIXTURES: String = "res://tests/b/fixtures/save"
const SLOT: int = 5


func _profile() -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.owned_weapons = [AR, P9] as Array[StringName]
	p.owned_mods = [CAN, SCOPE, REFLEX] as Array[StringName]
	p.level = 12
	return p


func test_default_profile_has_empty_slots_and_defaults() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(p.crew_loadouts.size(), CrewLoadouts.SLOTS)
	var d: Dictionary = CrewLoadouts.for_slot(0, p)
	assert_eq(d["weapon"], null, "default weapon")
	assert_eq(d["armor"], null, "default armor")
	assert_eq(d["mask"], &"")
	assert_eq(d["outfit"], &"")
	assert_eq((d["mods"] as Array).size(), 0)


func test_options_follow_the_armory() -> void:
	var p: PlayerProfile = _profile()
	assert_eq(CrewLoadouts.weapons(p), [AR] as Array[StringName], "owned primaries only (the P9 is a secondary)")
	var m: Dictionary = CrewLoadouts.mods(p, AR)
	assert_eq(m.get(Enums.ModType.SUPPRESSOR), [CAN] as Array[StringName])
	assert_eq(m.get(Enums.ModType.SIGHT), [&"mod.rail_reflex_sight", SCOPE] as Array[StringName], "owned, slot order")
	assert_false(m.has(Enums.ModType.STOCK), "no owned stock mod")
	var armors: Array[StringName] = CrewLoadouts.armors(p)
	assert_has(armors, &"armor.heavy_vest", "unlock_level 12 at level 12")
	assert_false(armors.has(&"armor.flak_rig"), "unlock_level 21 is still locked")
	assert_false(armors.has(&"armor.breacher_plate"), "a skill armor needs its skill")
	p.loadout.skills[&"skill.juggernaut.plated"] = 1
	assert_has(CrewLoadouts.armors(p), &"armor.breacher_plate")
	var outfits: Array[StringName] = CrewLoadouts.outfits(p)
	for id: StringName in Heisters.ids():
		assert_eq(outfits.has(id), Heisters.is_unlocked(p, id), "%s offered iff unlocked" % id)


func test_validate_falls_back_to_defaults() -> void:
	var p: PlayerProfile = _profile()
	var e: Dictionary = CrewLoadouts.validate(p, {"weapon": AR, "mods": [CAN, REFLEX, SCOPE, &"mod.p9_suppressor", &"mod.nope"],
		"armor": &"armor.flak_rig", "mask": &"mask.nope", "outfit": &"nobody"})
	assert_eq(e["weapon"], AR)
	assert_has(e["mods"], CAN)
	assert_has(e["mods"], SCOPE, "one sight: the last wins")
	assert_false((e["mods"] as Array).has(REFLEX))
	assert_eq((e["mods"] as Array).size(), 2, "a mod for another gun and an unknown id are dropped")
	assert_eq(e["armor"], &"", "a locked armor is the default")
	assert_eq(e["mask"], &"")
	assert_eq(e["outfit"], &"")
	assert_eq(CrewLoadouts.validate(p, {"weapon": P9})["weapon"], &"", "a secondary is not a bot primary")
	p.owned_weapons.erase(AR)
	assert_eq(CrewLoadouts.validate(p, e)["weapon"], &"", "a gun no longer owned falls back")
	assert_eq((CrewLoadouts.validate(p, e)["mods"] as Array).size(), 0, "and loses its mods")


func test_set_entry_for_slot_and_bot_loadout() -> void:
	var p: PlayerProfile = _profile()
	assert_true(CrewLoadouts.set_entry(p, 1, {"weapon": AR, "mods": [CAN], "armor": &"armor.heavy_vest"}))
	assert_false(CrewLoadouts.set_entry(p, CrewLoadouts.SLOTS, {}), "out of range")
	var d: Dictionary = CrewLoadouts.for_slot(1, p)
	assert_eq((d["weapon"] as WeaponDef).id, AR)
	assert_eq(((d["mods"] as Array)[0] as WeaponModDef).id, CAN)
	assert_eq((d["armor"] as ArmorDef).id, &"armor.heavy_vest")
	assert_eq(CrewLoadouts.for_slot(0, p)["weapon"], null, "slot 0 untouched")
	CrewLoadouts.source = p
	assert_eq((CrewLoadouts.for_slot(1)["weapon"] as WeaponDef).id, AR, "no profile: the launch source")
	CrewLoadouts.source = null
	var l: Loadout = CrewLoadouts.bot_loadout(1, p, &"rook")
	assert_eq(l.primary, AR)
	assert_eq(l.primary_mods, [CAN] as Array[StringName])
	assert_true(l.resolved_primary != null, "resolved with the mod")
	assert_eq(l.armor, &"armor.heavy_vest")
	assert_eq(l.heister, &"rook")
	var dflt: Loadout = CrewLoadouts.bot_loadout(0, p, &"sable")
	var a_default: Loadout = CrewWeapons.build_loadout(null)
	assert_eq(dflt.primary, a_default.primary, "an empty slot is A's default bot")
	assert_eq(dflt.armor, a_default.armor)


func test_outfit_picks_in_the_heister_assignment() -> void:
	var suit: StringName = &"suit_test_charcoal"
	var bodies: Dictionary = Tweak.crew().body_scenes
	bodies[suit] = null  # a heist suit as CrewTweak.body_scenes would list it (test only)
	var p: PlayerProfile = _profile()
	CrewLoadouts.set_entry(p, 0, {"outfit": &"rook"})
	CrewLoadouts.set_entry(p, 1, {"outfit": suit})
	CrewLoadouts.set_entry(p, 2, {"outfit": &"rook"})
	assert_eq(CrewLoadouts.entry(p, 1)["outfit"], suit, "a suit is a valid outfit")
	var picks: Dictionary = CrewLoadouts.outfit_picks(p, [1, 2, 3] as Array[int])
	var a: Dictionary = Heisters.assign([0] as Array[int], {0: &"sable"}, [1, 2, 3] as Array[int], picks)
	assert_eq(a[0], &"sable", "the human keeps the pick")
	assert_eq(a[1], &"rook", "bot 0 wears its heister")
	assert_eq(a[2], suit, "bot 1 wears the suit")
	assert_true(a[3] != &"rook" and a[3] != &"sable" and Heisters.is_known(a[3]), "bot 2's rook is taken: next free")
	var human_rook: Dictionary = Heisters.assign([0] as Array[int], {0: &"rook"}, [1, 2, 3] as Array[int], picks)
	assert_true(human_rook[1] != &"rook", "a human's heister wins over a bot's pick")
	bodies.erase(suit)
	assert_eq(CrewLoadouts.entry(p, 1)["outfit"], suit, "saved as is")
	assert_eq(CrewLoadouts.validate(p, CrewLoadouts.entry(p, 1))["outfit"], &"", "a suit no longer listed falls back")


func test_solo_launch_options_carry_the_crew() -> void:
	var p: PlayerProfile = _profile()
	CrewLoadouts.set_entry(p, 0, {"weapon": AR, "mods": [SCOPE], "armor": &"armor.light_vest", "outfit": &"dutch"})
	var l: Loadout = LoadoutResolver.resolve(p.loadout)
	l.heister = &"sable"
	var opts: Dictionary = MenuFlow.build_launch_options(3, 0, l, {}, false, &"", p)
	var bots: Dictionary = opts["loadouts"] as Dictionary
	assert_eq(bots.size(), 4)
	var first: Loadout = bots[1] as Loadout
	assert_eq(first.primary, AR, "the first AI slot is bot slot 0")
	assert_eq(first.primary_mods, [SCOPE] as Array[StringName])
	assert_eq(first.armor, &"armor.light_vest")
	assert_eq(first.heister, &"dutch")
	assert_eq((bots[2] as Loadout).primary, CrewWeapons.build_loadout(null).primary, "bot slot 1 is still the default")
	var plain: Dictionary = MenuFlow.build_launch_options(3, 0, LoadoutResolver.resolve(p.loadout))["loadouts"]
	assert_eq((plain[1] as Loadout).primary, CrewWeapons.build_loadout(null).primary, "no crew profile: A's default bots")


func test_lobby_host_summary_drives_bot_outfits_and_cards() -> void:
	var p: PlayerProfile = _profile()
	CrewLoadouts.set_entry(p, 0, {"weapon": AR, "outfit": &"wren", "armor": &"armor.heavy_vest"})
	var st: LobbyState = LobbyState.new(true)
	st.set_crew({0: {"peer_id": 1, "is_ai": false, "display_name": "Host"}, 1: {"peer_id": 0, "is_ai": true, "display_name": "AI"},
			2: {"peer_id": 0, "is_ai": true, "display_name": "AI"}}, 0, 0)
	var summary: Dictionary = LobbyState.summary_from(p.loadout, p)
	assert_eq((summary["crew"] as Array).size(), CrewLoadouts.SLOTS, "the summary carries the bots")
	assert_eq(st.receive(0, LobbyState.MSG_PROFILE, summary), LobbyState.OK)
	assert_eq(st.ai_heisters()[1], &"wren", "the first AI seat wears bot slot 0's outfit")
	var v: Dictionary = st.slot_view(1)
	assert_eq(String((v["bot"] as Dictionary)["weapon"]), String(AR), "the AI card's entry")
	assert_eq(String((st.slot_view(2)["bot"] as Dictionary)["weapon"]), "", "bot slot 1: default")
	assert_true((st.slot_view(0)["bot"] as Dictionary).is_empty(), "a human seat has no bot entry")
	var junk: Dictionary = summary.duplicate(true)
	junk["crew"] = [{"weapon": 5, "mods": "x", "outfit": "wren"}, "nope", {}, {}, {}]
	assert_eq(st.receive(0, LobbyState.MSG_PROFILE, junk), LobbyState.OK, "a bad crew list never refuses a summary")
	assert_eq(String((st.slot_view(1)["bot"] as Dictionary)["weapon"]), "", "non-string weapon dropped")
	assert_eq(st.ai_heisters()[1], &"wren")
	assert_true((st.slot_view(2)["bot"] as Dictionary).is_empty(), "a malformed entry ends the list")


## D-145.4 / PO-19 (v10): crew_loadouts is always ProfileSchema.CREW_SLOTS typed entries; 9 -> 10 adds them empty.
func test_v10_crew_loadouts_migrate_repair_and_round_trip() -> void:
	var m: Dictionary = SaveService.migrate(_fixture("v9"))
	assert_eq(int(m["version"]), 10)
	assert_eq((m["crew_loadouts"] as Array).size(), ProfileSchema.CREW_SLOTS, "9 -> 10: one empty entry per bot slot")
	assert_eq((m["crew_loadouts"] as Array)[0], {"weapon": "", "mods": [], "armor": "", "mask": "", "outfit": "", "ability": "",
			"boost": ""}, "L6.2: ability / boost default to none")
	Log.capture = true
	var q: PlayerProfile = SaveService.profile_from_save(_fixture("v10_crew_damaged"))
	assert_eq(q.crew_loadouts.size(), ProfileSchema.CREW_SLOTS, "the 4th entry is dropped")
	assert_eq(q.crew_loadouts[0]["weapon"], &"weapon.corsair_ar")
	assert_eq(q.crew_loadouts[0]["mods"], [&"mod.corsair_suppressor"] as Array[StringName], "a number in mods is dropped")
	assert_eq(q.crew_loadouts[1]["weapon"], &"", "a non-dict entry is emptied")
	assert_eq(q.crew_loadouts[2]["weapon"], &"", "a non-string weapon is the default")
	assert_eq(q.crew_loadouts[2]["outfit"], &"suit_navy")
	assert_true(_warned("crew_loadouts: 4 entries"))
	assert_true(_warned("crew_loadouts[1]: expected a crew loadout"))
	assert_true(_warned("crew_loadouts[2]/weapon: expected short_id"))
	var bad: Dictionary = _fixture("v10_crew_damaged")
	bad.erase("crew_loadouts")
	assert_eq(SaveService.profile_from_save(bad).crew_loadouts.size(), ProfileSchema.CREW_SLOTS, "missing -> empty entries")
	bad["crew_loadouts"] = "lots"
	assert_eq(SaveService.profile_from_save(bad).crew_loadouts[0]["armor"], &"", "a non-list -> empty entries")
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(p.crew_loadouts.size(), ProfileSchema.CREW_SLOTS)
	p.crew_loadouts[1]["weapon"] = &"weapon.corsair_ar"
	p.crew_loadouts[1]["mods"] = [&"mod.corsair_suppressor"] as Array[StringName]
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var r: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(r.crew_loadouts, p.crew_loadouts, "saved exactly")


func _fixture(fx: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [FIXTURES, fx]))
	var d: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
	d.erase("_doc")
	return d


func _warned(fragment: String) -> bool:
	for line: String in Log.captured:
		if line.contains(fragment):
			return true
	return false


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_each() -> void:
	Log.capture = false
	Log.captured.clear()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


## r246 (A 09a2a165): an unequipped bot carries CombatTweak.bot_default_primary and default_armor, and the Bot Crew
## screen / lobby AI cards name them ("Standard: <item>") instead of a generic label.
func test_default_labels_name_the_standard_gear() -> void:
	var tw: CombatTweak = CombatTweak.data()
	var n: Dictionary = CrewLoadouts.names(CrewLoadouts.empty_entry())
	assert_eq(n["weapon"], UiText.t(&"ui.crew.default_named", {"name": UiText.t(UiText.item_key(tw.bot_default_primary))}))
	assert_eq(n["armor"], UiText.t(&"ui.crew.default_named", {"name": UiText.t(UiText.item_key(tw.default_armor))}))
	assert_false(String(n["weapon"]).contains("weapon."), "a name, not an id: %s" % n["weapon"])
	assert_false(String(n["armor"]).contains("armor."), "a name, not an id: %s" % n["armor"])
	print("default labels: ", n["weapon"], " / ", n["armor"])
