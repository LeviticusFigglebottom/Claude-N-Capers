## D-073 (B6-07): heister choice. The roster + uniqueness rule (Heisters), the profile round trip, the loadout
## picker, lobby uniqueness (first claim keeps, later conflict falls back, AI fills the rest) and distinct
## heisters in every launch loadout, solo and co-op.
extends TestCase

const LOADOUT_SCENE_PATH: String = "res://content/ui/menus/loadout.tscn"
const SLOT: int = 7


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR
	Log.capture = false
	Log.captured.clear()


## Host in slot 0, a client in slot 1, AI in 2 and 3.
func _state() -> LobbyState:
	var s: LobbyState = LobbyState.new(true)
	s.set_crew({
		0: {"peer_id": 1, "is_ai": false, "display_name": "Host"},
		1: {"peer_id": 7, "is_ai": false, "display_name": "Player 7"},
		2: {"peer_id": 0, "is_ai": true, "display_name": "AI 2"},
		3: {"peer_id": 0, "is_ai": true, "display_name": "AI 3"},
	}, 0, 0)
	return s


func _summary(heister: StringName) -> Dictionary:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 10
	var l: Loadout = p.loadout.duplicate(true) as Loadout
	l.heister = heister
	return LobbyState.summary_from(l, p)


func _distinct(heisters: Array) -> bool:
	var seen: Array[StringName] = []
	for h: Variant in heisters:
		var id: StringName = StringName(h)
		if not Heisters.is_known(id) or seen.has(id):
			return false
		seen.append(id)
	return true


func test_roster_data_and_names() -> void:
	assert_eq(Heisters.ids(), [&"rook", &"sable", &"dutch", &"wren", &"marten", &"jay", &"juno", &"hale"] as Array[StringName],
			"roster order (D4-03: juno, hale)")
	for id: StringName in Heisters.ids():
		assert_eq(Heisters.name_key(id), StringName("crew.%s" % id))
		assert_ne(Heisters.display_name(id), String(Heisters.name_key(id)), "%s has a name string" % id)
		assert_ne(Heisters.accent(id), Heisters.roster().generic_accent, "%s has its own accent" % id)
	assert_false(Heisters.is_known(&""))
	assert_false(Heisters.is_known(&"crew.rook"), "ids are bare names")
	assert_ne(UiText.t(&"ui.heister.any"), "ui.heister.any")


func test_assign_rule() -> void:
	# uncontested picks kept; AI takes the rest in roster order
	var a: Dictionary = Heisters.assign([0, 1] as Array[int], {0: &"dutch", 1: &"rook"}, [2, 3] as Array[int])
	assert_eq(a, {0: &"dutch", 1: &"rook", 2: &"sable", 3: &"wren"})
	# conflict: first claim keeps it, the later one falls back to the next free after its pick
	var c: Dictionary = Heisters.assign([1, 0] as Array[int], {0: &"sable", 1: &"sable"}, [2, 3] as Array[int])
	assert_eq(c[1], &"sable", "first claim keeps")
	assert_eq(c[0], &"dutch", "next after sable in roster order")
	assert_true(_distinct(c.values()))
	# next after wren is marten, then jay (D-111), juno, hale (D4-03); wrap-around: hale taken -> rook
	var w: Dictionary = Heisters.assign([0, 1] as Array[int], {0: &"wren", 1: &"wren"}, [] as Array[int])
	assert_eq(w[1], &"marten")
	var m: Dictionary = Heisters.assign([0, 1] as Array[int], {0: &"marten", 1: &"marten"}, [] as Array[int])
	assert_eq(m[1], &"jay")
	var j: Dictionary = Heisters.assign([0, 1] as Array[int], {0: &"jay", 1: &"jay"}, [] as Array[int])
	assert_eq(j[1], &"juno")
	var h: Dictionary = Heisters.assign([0, 1] as Array[int], {0: &"hale", 1: &"hale"}, [] as Array[int])
	assert_eq(h[1], &"rook", "wraps to the start")
	# no preference = first free; conflicts are served after every uncontested pick
	var g: Dictionary = Heisters.assign([0, 1, 2] as Array[int], {0: &"", 1: &"rook", 2: &"rook"}, [3] as Array[int])
	assert_eq(g[1], &"rook")
	assert_eq(g[0], &"sable", "no preference after the uncontested picks")
	assert_eq(g[2], &"dutch")
	assert_eq(g[3], &"wren", "AI last")
	assert_eq(Heisters.next_free(&"rook", [&"rook", &"sable", &"dutch", &"wren"] as Array[StringName]), &"marten")
	assert_eq(Heisters.next_free(&"rook", Heisters.ids()), &"")


func test_profile_round_trip_and_repair() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.loadout.heister = &"wren"
	assert_eq(String((p.to_dict()["loadout"] as Dictionary)["heister"]), "wren", "saved in the loadout")
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	assert_eq(SaveService.load_profile(SLOT).loadout.heister, &"wren", "loaded back")
	Log.capture = true
	Log.captured.clear()
	var d: Dictionary = p.to_dict()
	(d["loadout"] as Dictionary)["heister"] = "the_drifter"
	assert_eq(SaveService.profile_from_save(d).loadout.heister, &"", "unknown heister cleared")
	var warned: bool = false
	for line: String in Log.captured:
		warned = warned or line.contains("loadout.heister: unknown heister 'the_drifter'")
	assert_true(warned, "repair logged")
	(d["loadout"] as Dictionary)["heister"] = 4
	assert_eq(SaveService.profile_from_save(d).loadout.heister, &"", "wrong type -> default")
	(d["loadout"] as Dictionary).erase("heister")
	assert_eq(SaveService.profile_from_save(d).loadout.heister, &"", "missing key (older v6 file) reads as no preference")
	Log.capture = false


func test_picker_lists_roster_and_saves() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.loadout.heister = &"dutch"
	var ls: LoadoutScreen = (load(LOADOUT_SCENE_PATH) as PackedScene).instantiate() as LoadoutScreen
	ls.profile_slot = SLOT
	ls.setup(p)
	add_child(ls)
	await wait_frames(1)
	assert_eq(ls.option_ids(ls.heister_option), [&"", &"rook", &"sable", &"dutch", &"wren", &"marten", &"jay", &"juno",
		&"hale"] as Array[StringName])
	assert_false(ls.select_heister(&"marten"), "D-111: Marten is earned (The Planner)")
	assert_eq(ls.heister_option.get_item_text(5), UiText.t(&"ui.loadout.heister_locked", {"name": Heisters.display_name(&"marten")}))
	assert_eq(ls.current_loadout().heister, &"dutch", "starts on the profile's pick")
	assert_eq(ls.heister_swatch.color, Heisters.accent(&"dutch"))
	assert_eq(ls.heister_portrait.visible, Heisters.portrait(&"dutch") != null, "portrait only when ENV D ships one")
	assert_has(ls.focus_chain, ls.heister_option as Control)
	assert_true(ls.select_heister(&"sable"))
	assert_eq(ls.current_loadout().heister, &"sable")
	ls.set_taken_heisters([&"rook"] as Array[StringName])
	assert_false(ls.select_heister(&"rook"), "taken by another crew member")
	assert_eq(ls.current_loadout().heister, &"sable", "selection kept across the re-list")
	assert_true(ls.heister_option.get_item_text(1).contains(Heisters.display_name(&"rook")))
	assert_ne(ls.heister_option.get_item_text(1), Heisters.display_name(&"rook"), "marked taken")
	assert_eq(ls.save(), OK)
	assert_eq(SaveService.load_profile(SLOT).loadout.heister, &"sable", "saved with the loadout")
	ls.queue_free()
	await wait_frames(1)


func test_summary_carries_and_validates_heister() -> void:
	var s: Dictionary = _summary(&"wren")
	assert_eq(String((s["loadout"] as Dictionary)["heister"]), "wren")
	var clean: Dictionary = LobbyState.sanitize_summary(s)
	assert_eq(String((clean["loadout"] as Dictionary)["heister"]), "wren")
	assert_eq(LobbyState.validate_summary(clean), [] as Array[String])
	var bad: Dictionary = clean.duplicate(true)
	(bad["loadout"] as Dictionary)["heister"] = "crew.ghost"
	assert_has(LobbyState.validate_summary(bad), "heister: unknown id crew.ghost")
	var wrong: Dictionary = s.duplicate(true)
	(wrong["loadout"] as Dictionary)["heister"] = 3
	assert_eq(LobbyState.sanitize_summary(wrong), {}, "not a String: malformed")
	var old: Dictionary = s.duplicate(true)
	(old["loadout"] as Dictionary).erase("heister")
	assert_eq(String((LobbyState.sanitize_summary(old)["loadout"] as Dictionary)["heister"]), "", "missing = no preference")


func test_lobby_conflict_first_claim_keeps() -> void:
	var st: LobbyState = _state()
	assert_eq(st.receive(1, LobbyState.MSG_PROFILE, _summary(&"sable")), LobbyState.OK)
	assert_eq(st.receive(0, LobbyState.MSG_PROFILE, _summary(&"sable")), LobbyState.OK)
	assert_eq(st.heister_of(1), &"sable", "client claimed first")
	assert_eq(st.heister_of(0), &"dutch", "host falls back to the next free heister")
	assert_true(st.is_legal(0), "a conflict never blocks Start")
	var v0: Dictionary = st.slot_view(0)
	assert_eq(v0["heister"], &"dutch")
	assert_eq(v0["heister_pick"], &"sable")
	# re-sending the same pick (every lobby show) keeps the claim's place
	st.receive(1, LobbyState.MSG_PROFILE, _summary(&"sable"))
	assert_eq(st.heister_of(1), &"sable")
	assert_eq(st.heisters_taken_by_others(0), [&"sable"] as Array[StringName], "the host's picker marks sable taken")
	# the client changes its pick: the host's claim is now the earlier one for sable
	st.receive(1, LobbyState.MSG_PROFILE, _summary(&"rook"))
	assert_eq(st.heister_of(0), &"sable")
	assert_eq(st.heister_of(1), &"rook")
	# a slot that leaves frees its heister
	st.set_crew({0: {"peer_id": 1, "is_ai": false, "display_name": "Host"}}, 0, 0)
	assert_eq(st.heister_of(0), &"sable")
	assert_eq(st.ai_heisters(), {1: &"rook", 2: &"dutch", 3: &"wren"}, "empty seats fill in roster order")


func test_lobby_ai_fill_and_distinct_launch_loadouts() -> void:
	var st: LobbyState = _state()
	st.receive(0, LobbyState.MSG_PROFILE, _summary(&"wren"))
	st.receive(1, LobbyState.MSG_PROFILE, _summary(&""))
	var lo: Dictionary = st.launch_loadouts()
	assert_eq((lo[0] as Loadout).heister, &"wren")
	assert_eq((lo[1] as Loadout).heister, &"rook", "no preference = first free")
	var ai: Dictionary = st.ai_heisters()
	assert_eq(ai, {2: &"sable", 3: &"dutch"}, "AI takes the unused heisters")
	var opts: Dictionary = MenuFlow.build_coop_launch_options(lo, {}, false, &"", Heisters.ai_loadouts(ai))
	assert_eq(int(opts["ai_teammates"]), 2)
	var all: Dictionary = opts["loadouts"] as Dictionary
	assert_eq(all.size(), 4)
	var hs: Array = []
	for slot: int in range(4):
		hs.append((all[slot] as Loadout).heister)
	assert_true(_distinct(hs), "every launched slot has a distinct heister: %s" % [hs])
	assert_true((all[2] as Loadout).resolved_primary != null or (all[2] as Loadout).resolved_secondary != null,
			"AI loadout = ENV A's default AI loadout")


func test_solo_launch_loadouts_distinct() -> void:
	var l: Loadout = Loadout.new()
	l.heister = &"dutch"
	var opts: Dictionary = MenuFlow.build_launch_options(3, 0, l)
	var all: Dictionary = opts["loadouts"] as Dictionary
	assert_eq(all[0], l, "the player's resolved loadout")
	assert_eq(l.heister, &"dutch")
	assert_eq(all.keys().size(), 4)
	var hs: Array = []
	for slot: int in range(4):
		hs.append((all[slot] as Loadout).heister)
	assert_true(_distinct(hs), "solo crew distinct: %s" % [hs])
	var any: Loadout = Loadout.new()
	var two: Dictionary = MenuFlow.build_launch_options(2, 1, any)["loadouts"] as Dictionary
	assert_eq(any.heister, &"rook", "no preference = first heister")
	assert_eq(two.keys().size(), 3, "AI only in the seats Net.start_solo fills")
	assert_true(two.has(0) and two.has(2) and not two.has(3))
	var none: Dictionary = MenuFlow.build_launch_options(0, 0, Loadout.new())["loadouts"] as Dictionary
	assert_eq(none.size(), 1, "no AI, no AI loadouts")


## D-111: Marten is earned (achievement The Planner grants unlock.achievement.the_planner); the others are free.
func test_marten_unlock() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(Heisters.unlock_of(&"marten"), &"unlock.achievement.the_planner")
	assert_false(Heisters.is_unlocked(p, &"marten"))
	for id: StringName in [&"rook", &"sable", &"dutch", &"wren", &""]:
		assert_true(Heisters.is_unlocked(p, id), "%s free" % id)
	assert_eq(Heisters.unlock_of(&"jay"), &"unlock.achievement.wheelman", "Jay: Wheelman (5 loud wins)")
	assert_false(Heisters.is_unlocked(p, &"jay"))
	MaskLocker.grant_unlock(p, &"unlock.achievement.the_planner")
	assert_true(Heisters.is_unlocked(p, &"marten"))
	var a: AchievementDef = ContentDB.by_id(ContentDB.ACHIEVEMENTS, &"achievement.the_planner") as AchievementDef
	assert_true(a != null and a.unlock == &"unlock.achievement.the_planner")
