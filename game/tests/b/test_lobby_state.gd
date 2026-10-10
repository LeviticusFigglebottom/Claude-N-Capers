## B4-11: the co-op lobby model (LobbyState, pure), field validation (LobbyAddress) and the co-op
## launch options. Networking is in test_lobby_loopback.gd.
extends TestCase

const TRIAGE: StringName = &"skill.field_medic.triage"
const MASK_COMP: Dictionary = {"base": "mask_base.visage", "material": "mask_material.matte",
	"colors": "mask_colors.bone_ink", "pattern": "mask_pattern.solid"}


func after_all() -> void:
	Log.capture = false
	Log.captured.clear()


## Host in slot 0 (peer 1), a client in slot 1 (peer 7), AI in 2 and 3.
func _crew() -> Dictionary:
	return {
		0: {"peer_id": 1, "is_ai": false, "display_name": "Host"},
		1: {"peer_id": 7, "is_ai": false, "display_name": "Player 7"},
		2: {"peer_id": 0, "is_ai": true, "display_name": "AI 2"},
		3: {"peer_id": 0, "is_ai": true, "display_name": "AI 3"},
	}


func _state(host: bool = true, local: int = 0) -> LobbyState:
	var s: LobbyState = LobbyState.new(host)
	s.set_crew(_crew(), local, 0)
	return s


func _summary(level: int = 10, skills: Dictionary = {}) -> Dictionary:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = "Wren"
	p.level = level
	var l: Loadout = p.loadout.duplicate(true) as Loadout
	l.skills = skills
	return LobbyState.summary_from(l, p)


func _contract() -> Dictionary:
	return LobbyState.contract_data(&"glasshouse", Enums.Difficulty.HAZARDOUS, true)


func test_slots_and_ai_fill() -> void:
	var s: LobbyState = _state(true, 0)
	assert_eq(s.human_slots(), [0, 1] as Array[int])
	var v0: Dictionary = s.slot_view(0)
	assert_true(bool(v0["is_host"]) and bool(v0["is_local"]) and not bool(v0["is_ai"]))
	assert_eq(String(v0["name"]), "Host", "crew display name until a summary arrives")
	assert_false(bool(v0["has_summary"]))
	var v2: Dictionary = s.slot_view(2)
	assert_true(bool(v2["occupied"]) and bool(v2["is_ai"]), "AI fill slot")
	var small: Dictionary = _crew()
	small.erase(3)
	s.set_crew(small, 0, 0)
	assert_false(bool(s.slot_view(3)["occupied"]), "open seat")
	assert_eq(s.slot_view(3)["slot"], 3)


func test_message_validation() -> void:
	var s: LobbyState = _state(true, 0)
	assert_eq(s.receive(1, &"lobby.nope", {}), LobbyState.R_UNKNOWN_KIND)
	assert_eq(s.receive(2, LobbyState.MSG_READY, {"ready": true}), LobbyState.R_BAD_SENDER, "AI slot")
	assert_eq(s.receive(-1, LobbyState.MSG_READY, {"ready": true}), LobbyState.R_BAD_SENDER, "no slot")
	assert_eq(s.receive(1, LobbyState.MSG_CONTRACT, _contract()), LobbyState.R_NOT_HOST)
	assert_eq(s.receive(1, LobbyState.MSG_START, LobbyState.start_data(_contract(), 5)), LobbyState.R_NOT_HOST)
	assert_eq(s.receive(1, LobbyState.MSG_READY, {"ready": "yes"}), LobbyState.R_BAD_PAYLOAD)
	assert_eq(s.receive(1, LobbyState.MSG_READY, {"ready": true, "x": &"sn"}), LobbyState.R_BAD_PAYLOAD, "StringName is not JSON-safe")
	assert_eq(s.receive(1, LobbyState.MSG_PROFILE, {"name": "x"}), LobbyState.R_BAD_PAYLOAD)
	assert_eq(s.receive(0, LobbyState.MSG_CONTRACT, {"heist": "glasshouse", "difficulty": 99}), LobbyState.R_BAD_PAYLOAD)
	assert_eq(s.receive(0, LobbyState.MSG_START, _contract()), LobbyState.R_BAD_PAYLOAD, "start needs a seed")
	assert_eq(s.receive(1, PlanVote.MSG_CAST, {"option": 3}), LobbyState.R_BAD_PAYLOAD)
	assert_true(s.ready.is_empty() and s.contract.is_empty() and s.summaries.is_empty(), "rejections change nothing")
	assert_eq(s.receive(1, LobbyState.MSG_READY, {"ready": true}), LobbyState.OK)
	assert_true(s.is_ready(1))


func test_json_safety() -> void:
	assert_true(LobbyState.is_json_safe({"a": [1, 2.5, "x", true, null, {"b": {}}]}))
	assert_false(LobbyState.is_json_safe({1: "int key"}))
	assert_false(LobbyState.is_json_safe({"v": Vector2.ONE}))
	assert_false(LobbyState.is_json_safe({"o": Node}))
	var sum: Dictionary = _summary()
	assert_true(LobbyState.is_json_safe(sum), "profile summary is JSON-safe")
	# Through real JSON (ints arrive as floats) the summary still parses to the same thing.
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(sum)) as Dictionary
	assert_eq(LobbyState.sanitize_summary(round_trip), LobbyState.sanitize_summary(sum))


func test_host_only_start_needs_contract_ready_and_legal_summaries() -> void:
	var client: LobbyState = _state(false, 1)
	assert_eq(client.start_block(), LobbyState.BLOCK_NOT_HOST)
	var s: LobbyState = _state(true, 0)
	assert_eq(s.start_block(), LobbyState.BLOCK_NO_CONTRACT)
	assert_eq(s.receive(0, LobbyState.MSG_CONTRACT, _contract()), LobbyState.OK)
	assert_eq(s.contract["heist"], &"glasshouse")
	assert_true(bool(s.contract["is_pro"]))
	assert_eq(s.start_block(), LobbyState.BLOCK_MISSING_SUMMARY)
	assert_eq(s.receive(0, LobbyState.MSG_PROFILE, _summary()), LobbyState.OK)
	assert_eq(s.receive(1, LobbyState.MSG_PROFILE, _summary(0, {TRIAGE: 2})), LobbyState.OK)
	assert_false(s.is_legal(1), "aced skill at level 0 is illegal")
	assert_eq(s.start_block(), LobbyState.BLOCK_ILLEGAL)
	assert_false(s.launch_loadouts().has(1), "an illegal loadout is never launched")
	assert_eq(s.receive(1, LobbyState.MSG_PROFILE, _summary(10, {TRIAGE: 2})), LobbyState.OK)
	assert_true(s.is_legal(1), "legal at level 10: %s" % [s.errors.get(1)])
	assert_eq(s.start_block(), LobbyState.BLOCK_NOT_READY)
	s.receive(0, LobbyState.MSG_READY, {"ready": true})
	assert_eq(s.start_block(), LobbyState.BLOCK_NOT_READY, "the client is not ready yet")
	s.receive(1, LobbyState.MSG_READY, {"ready": true})
	assert_eq(s.start_block(), LobbyState.OK, "AI slots never block")
	assert_true(s.can_start())
	assert_eq(s.receive(0, LobbyState.MSG_START, LobbyState.start_data(s.contract, 4242)), LobbyState.OK)
	assert_eq(int(s.started["seed"]), 4242)
	assert_eq(s.start_block(), LobbyState.BLOCK_STARTED)


func test_contract_change_clears_ready_and_votes() -> void:
	var s: LobbyState = _state(true, 0)
	s.receive(0, LobbyState.MSG_CONTRACT, _contract())
	s.receive(1, LobbyState.MSG_READY, {"ready": true})
	s.receive(1, PlanVote.MSG_CAST, {"option": "asset.escape_van@pp_a"})
	s.receive(0, PlanVote.MSG_CAST, {"option": "asset.escape_van@pp_b"})
	s.receive(1, PlanVote.MSG_RETRACT, {"group": "escape"})
	assert_eq(s.vote_log.size(), 3)
	assert_eq(s.vote_log[2]["kind"], PlanVote.MSG_RETRACT, "order kept")
	assert_eq(int(s.vote_log[0]["slot"]), 1)
	s.receive(0, LobbyState.MSG_CONTRACT, _contract())
	assert_true(s.is_ready(1), "same contract re-sent: nothing reset")
	assert_eq(s.vote_log.size(), 3)
	s.receive(0, LobbyState.MSG_CONTRACT, LobbyState.contract_data(&"glasshouse", Enums.Difficulty.ROUTINE, false))
	assert_false(s.is_ready(1), "new difficulty: ready cleared")
	assert_true(s.vote_log.is_empty(), "new contract: votes cleared")


func test_crew_change_forgets_the_old_occupant() -> void:
	var s: LobbyState = _state(true, 0)
	s.receive(1, LobbyState.MSG_PROFILE, _summary())
	s.receive(1, LobbyState.MSG_READY, {"ready": true})
	s.receive(1, PlanVote.MSG_CAST, {"option": "asset.x@pp"})
	var c: Dictionary = _crew()
	c[1] = {"peer_id": 0, "is_ai": true, "display_name": "AI 1"}  # the client left: AI takes the seat
	s.set_crew(c, 0, 0)
	assert_false(s.is_ready(1))
	assert_false(s.summaries.has(1))
	assert_true(s.vote_log.is_empty())
	assert_eq(s.receive(1, LobbyState.MSG_READY, {"ready": true}), LobbyState.R_BAD_SENDER)
	s.receive(0, LobbyState.MSG_PROFILE, _summary())
	c = _crew()
	s.set_crew(c, 0, 0)
	assert_true(s.summaries.has(0), "same occupant keeps its summary")


func test_summary_round_trip_and_names() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = "A very long crew name that goes past the limit"
	p.level = 12
	p.custom_masks = [MASK_COMP.duplicate()]
	var l: Loadout = p.loadout.duplicate(true) as Loadout
	l.secondary_mods = [&"mod.p9_suppressor"] as Array[StringName]
	l.mask = &"mask.custom.0"
	l.skills = {TRIAGE: 1}
	var sum: Dictionary = LobbyState.summary_from(l, p)
	var clean: Dictionary = LobbyState.sanitize_summary(sum)
	assert_eq(String(clean["name"]).length(), LobbyTweak.load_default().max_name_length, "name cut")
	assert_eq(LobbyState.validate_summary(clean), [] as Array[String])
	var back: Loadout = LobbyState.loadout_from_dict(clean["loadout"] as Dictionary)
	assert_eq(back.secondary, &"weapon.kestrel_p9")
	assert_eq(back.secondary_mods, [&"mod.p9_suppressor"] as Array[StringName])
	assert_eq(back.armor, &"armor.tailored_suit")
	assert_eq(back.skills, {TRIAGE: 1})
	assert_eq(String(back.mask_descriptor.get("id", "")), "mask.custom.0", "custom mask descriptor travels")
	var names: Dictionary = LobbyState.item_names(clean["loadout"] as Dictionary)
	assert_eq(names["secondary"], UiText.t(&"item.weapon.kestrel_p9.name"))
	assert_eq(names["armor"], UiText.t(&"item.armor.tailored_suit.name"))
	assert_eq(names["deployable"], UiText.t(&"item.deployable.doctor_bag.name"))
	assert_eq(names["primary"], "", "empty slot")
	assert_eq(names["mask"], UiText.t(&"ui.lobby.custom_mask"))
	var md: MaskDef = LobbyState.mask_def(clean["loadout"] as Dictionary)
	assert_true(md != null, "other peers can compose the custom mask")
	var preset: Dictionary = LobbyState.sanitize_summary(_summary())
	assert_eq(LobbyState.mask_name(preset["loadout"] as Dictionary), UiText.t(&"item.mask.gilded_heron.name"))
	assert_true(LobbyState.mask_def(preset["loadout"] as Dictionary) != null)


func test_illegal_summaries_are_flagged() -> void:
	Log.capture = true
	var base: Dictionary = LobbyState.sanitize_summary(_summary())
	var bad_weapon: Dictionary = base.duplicate(true)
	(bad_weapon["loadout"] as Dictionary)["secondary"] = "weapon.does_not_exist"
	assert_false(LobbyState.validate_summary(bad_weapon).is_empty(), "unknown weapon")
	var bad_mod: Dictionary = base.duplicate(true)
	(bad_mod["loadout"] as Dictionary)["secondary_mods"] = ["mod.p9_suppressor", "mod.p9_suppressor"]
	assert_false(LobbyState.validate_summary(bad_mod).is_empty(), "two mods in one slot")
	var bad_mask: Dictionary = base.duplicate(true)
	(bad_mask["loadout"] as Dictionary)["mask"] = "mask.custom.1"
	assert_false(LobbyState.validate_summary(bad_mask).is_empty(), "custom mask without a descriptor")
	var bad_level: Dictionary = base.duplicate(true)
	bad_level["level"] = 999
	assert_false(LobbyState.validate_summary(bad_level).is_empty())
	var bad_cards: Dictionary = base.duplicate(true)
	(bad_cards["loadout"] as Dictionary)["perk_deck_cards"] = 12
	assert_false(LobbyState.validate_summary(bad_cards).is_empty())
	var bad_skill: Dictionary = base.duplicate(true)
	(bad_skill["loadout"] as Dictionary)["skills"] = {"skill.nope.nope": 1}
	assert_false(LobbyState.validate_summary(bad_skill).is_empty())
	Log.capture = false


func test_launch_options_carry_every_human_loadout() -> void:
	var s: LobbyState = _state(true, 0)
	s.receive(0, LobbyState.MSG_PROFILE, _summary())
	var sum: Dictionary = _summary(5)
	((sum["loadout"] as Dictionary))["armor"] = "armor.patrol_vest"
	s.receive(1, LobbyState.MSG_PROFILE, sum)
	var lo: Dictionary = s.launch_loadouts()
	assert_eq(lo.keys().size(), 2)
	assert_eq((lo[1] as Loadout).armor, &"armor.patrol_vest")
	assert_true((lo[0] as Loadout).resolved_secondary != null, "resolved")
	assert_true((lo[1] as Loadout).detection_risk > 0)
	var opts: Dictionary = MenuFlow.build_coop_launch_options(lo, {"version": 1}, true)
	assert_eq(int(opts["ai_teammates"]), 2)
	assert_eq(opts["loadouts"], lo)
	assert_true(opts.has("preplan"))
	assert_true(bool(opts["is_pro"]))
	var plain: Dictionary = MenuFlow.build_coop_launch_options(lo)
	assert_false(plain.has("preplan") or plain.has("is_pro"))


func test_address_and_port_validation() -> void:
	var tw: LobbyTweak = LobbyTweak.load_default()
	assert_eq(tw.default_port, Net.DEFAULT_PORT, "data default matches Net")
	assert_eq(LobbyAddress.parse_port("27655", tw), 27655)
	assert_eq(LobbyAddress.parse_port(" 4000 ", tw), 4000)
	assert_eq(LobbyAddress.parse_port("80", tw), -1, "below min_port")
	assert_eq(LobbyAddress.parse_port("70000", tw), -1)
	assert_eq(LobbyAddress.parse_port("12ab", tw), -1)
	assert_eq(LobbyAddress.parse_port("", tw), -1)
	assert_eq(LobbyAddress.parse_address(" 127.0.0.1 "), "127.0.0.1")
	assert_eq(LobbyAddress.parse_address("192.168.0.10"), "192.168.0.10")
	assert_eq(LobbyAddress.parse_address("::1"), "::1")
	assert_eq(LobbyAddress.parse_address("Crew-Box.local"), "crew-box.local")
	assert_eq(LobbyAddress.parse_address("300.1.1.1"), "")
	assert_eq(LobbyAddress.parse_address("bad host"), "")
	assert_eq(LobbyAddress.parse_address("-x.com"), "")
	assert_eq(LobbyAddress.parse_address(""), "")
	assert_eq(LobbyAddress.parse_address(tw.loopback_address), "127.0.0.1")
