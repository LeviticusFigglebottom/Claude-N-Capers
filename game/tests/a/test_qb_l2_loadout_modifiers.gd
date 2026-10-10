## QB-L2: HeistRuntime pushes every crew slot's Loadout modifiers (skills + perk deck, per slot
## source LoadoutModifiers.SOURCE; team grants as TEAM sources) before the crew spawns, without any
## manual Modifiers.set_source (LoadoutModifiers, heist_runtime.gd).
extends TestCase

const ZIP_AND_TIE: StringName = &"skill.persuader.zip_and_tie"
const FOREMAN: StringName = &"perk.foreman"

var _rt: HeistRuntime = null


func before_each() -> void:
	Modifiers.clear_all()


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _skilled_loadout(cards: int) -> Loadout:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.skills = {ZIP_AND_TIE: 1}  # basic: stealth.cable_ties_extra 4
	l.perk_deck = FOREMAN
	l.perk_deck_cards = cards  # card 5: team.health_mult 1.1 + defense.health_mult 1.0909091
	l.modifiers = {}  # unresolved on purpose: the push resolves it
	return l


func _launch(loadouts: Dictionary, ai: int = 1) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4402, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": ai, "skip_casing": true, "loadouts": loadouts})


func test_qb_l2_launched_loadout_skills_and_perk_change_behaviour() -> void:
	await _launch({0: _skilled_loadout(5)})
	var c0: CrewController = _rt.crew_controller(0) as CrewController
	var c1: CrewController = _rt.crew_controller(1) as CrewController
	var tw: CrewTweak = Tweak.crew()
	assert_eq(c0.cable_ties, tw.cable_ties_base + 4, "Zip & Tie basic: +4 cable ties from the loadout alone")
	assert_eq(c1.cable_ties, tw.cable_ties_base, "the AI teammate's default loadout has no skills")
	assert_near(c0.health.max_health, tw.base_health * 1.0909091 * 1.1, 0.05, "Foreman: personal x team health")
	assert_near(c1.health.max_health, tw.base_health * 1.1, 0.05, "team.health_mult (TEAM source) reaches every slot")
	assert_true(Modifiers.dump(0).get(0, {}).has(LoadoutModifiers.SOURCE), "slot 0 source pushed")
	assert_true(Modifiers.dump(1).get(1, {}).has(LoadoutModifiers.SOURCE), "default-loadout slot pushed too")
	var team: Dictionary = Modifiers.dump(0).get(Modifiers.TEAM, {})
	assert_true(team.has(LoadoutResolver.team_perk_source(FOREMAN)), "team grants on TEAM as team_perk.foreman")


func test_qb_l2_same_team_deck_on_two_slots_counts_once() -> void:
	await _launch({0: _skilled_loadout(5), 1: _skilled_loadout(5)})
	var c1: CrewController = _rt.crew_controller(1) as CrewController
	assert_near(Modifiers.mult(1, &"team.health_mult"), 1.1, 0.0001, "one team_perk.foreman source")
	assert_near(c1.health.max_health, Tweak.crew().base_health * 1.0909091 * 1.1, 0.05, "slot 1 own deck + team once")


func test_qb_l2_resolved_modifiers_are_used_as_given() -> void:
	var l: Loadout = _skilled_loadout(0)
	l.modifiers = {&"stealth.cable_ties_extra": 1}
	await _launch({0: l}, 0)
	var c0: CrewController = _rt.crew_controller(0) as CrewController
	assert_eq(c0.cable_ties, Tweak.crew().cable_ties_base + 1, "Loadout.modifiers wins when already resolved")
	assert_eq(LoadoutModifiers.modifiers_of(l), l.modifiers)
