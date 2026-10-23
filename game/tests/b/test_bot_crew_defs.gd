## L6.2 bot crew (PD2 Crew Management): BotCrewDef data under ContentDB kind `bot_crew` for ENV A's BotCrew. Four
## abilities and five boosts with A's ids, known modifier keys, Inspire's behaviour params, and text whose numbers match
## the grants. The crew-screen pickers come with the Loadout bot_ability / bot_boost contract.
extends TestCase

const ABILITIES: Array[StringName] = [&"bot_ability.inspire", &"bot_ability.quick", &"bot_ability.pied_piper",
	&"bot_ability.resilient"]
const BOOSTS: Array[StringName] = [&"bot_boost.ammo", &"bot_boost.health", &"bot_boost.stamina", &"bot_boost.revive",
	&"bot_boost.carry"]


func before_all() -> void:
	ContentDB.clear_cache()


func _ids(defs: Array[BotCrewDef]) -> Array[StringName]:
	var out: Array[StringName] = []
	for d: BotCrewDef in defs:
		out.append(d.id)
	return out


func test_ids_and_kinds() -> void:
	assert_true(ContentDB.KINDS.has(ContentDB.BOT_CREW), "a ContentDB kind (BotCrew.CONTENT_KIND)")
	assert_eq(_ids(ContentDB.bot_crew(BotCrewDef.ABILITY)), ABILITIES, "abilities in picker order")
	assert_eq(_ids(ContentDB.bot_crew(BotCrewDef.BOOST)), BOOSTS, "boosts in picker order")


func test_grants_and_params() -> void:
	for id: StringName in ABILITIES + BOOSTS:
		var d: BotCrewDef = ContentDB.by_id(ContentDB.BOT_CREW, id) as BotCrewDef
		for k: Variant in d.grants:
			assert_true(ModifierKeys.is_known(StringName(k)), "%s grants a known key %s" % [id, k])
			var v: float = float(d.grants[k])
			assert_true(v > 0.0 and v != 1.0, "%s: %s does something (%s)" % [id, k, v])
			var pct: String = "%d%%" % roundi(absf(1.0 - v) * 100.0)
			assert_true(UiText.t(StringName("item.%s.desc" % id)).contains(pct), "%s text says %s" % [id, pct])
		assert_true(UiText.has(UiText.item_key(id)), "%s has a name" % id)
	var inspire: BotCrewDef = ContentDB.by_id(ContentDB.BOT_CREW, &"bot_ability.inspire") as BotCrewDef
	assert_true(inspire.grants.is_empty(), "Inspire is a behaviour, not a stat")
	assert_near(float(inspire.params.get("range", 0.0)), 9.0, 0.001, "PD2 Inspire: 9 m")
	assert_true(float(inspire.params.get("cooldown", 0.0)) > 0.0, "a cooldown")
