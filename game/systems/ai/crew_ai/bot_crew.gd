## L6.2 bot crew abilities and boosts (PD2 Crew Management; LEAD r285). Owner: ENV A. Each AI teammate carries one
## ABILITY and one BOOST (B: the defs, the crew-screen pickers, the strings; A: this runtime side).
## - Ability: a Modifiers grant on the bot's own slot (source "bot_ability"); bot_ability.inspire is a behaviour too:
##   the bot revives a downed teammate within `range` m it can see, at most once per `cooldown` s (PD2 Inspire).
## - Boost: a crew-wide grant (Modifiers.TEAM, source "bot_boost.<slot>") while that bot is in play (not in
##   custody), as PD2 boosts last while the bot is on the team.
## Ids come from the bot's Loadout (`bot_ability` / `bot_boost`, duck-typed until the contract field lands) or the
## launch option "bot_crew" {slot: {"ability": id, "boost": id}} (harness / tests). Defs: B's, when ContentDB has a
## "bot_crew" kind with the id (a Resource with `kind`, `grants`, `params`); else DEFAULTS below (PD2-shaped ◇).
class_name BotCrew
extends Node

const SERVICE: StringName = &"bot_crew"
const NODE_NAME: String = "BotCrew"
const CONTENT_KIND: StringName = &"bot_crew"
const INSPIRE: StringName = &"bot_ability.inspire"
const DEFAULTS: Dictionary = {
	&"bot_ability.inspire": {"kind": "ability", "grants": {}, "params": {"range": 9.0, "cooldown": 30.0}},
	&"bot_ability.quick": {"kind": "ability", "grants": {&"interaction.speed_mult": 0.7}, "params": {}},
	&"bot_ability.pied_piper": {"kind": "ability", "grants": {&"ability.shout_range_mult": 1.5}, "params": {}},
	&"bot_ability.resilient": {"kind": "ability", "grants": {&"defense.damage_taken_mult": 0.8}, "params": {}},
	&"bot_boost.ammo": {"kind": "boost", "grants": {&"weapon.ammo_total_mult.all": 1.25}, "params": {}},
	&"bot_boost.health": {"kind": "boost", "grants": {&"defense.health_mult": 1.1}, "params": {}},
	&"bot_boost.stamina": {"kind": "boost", "grants": {&"movement.stamina_mult": 1.25}, "params": {}},
	&"bot_boost.revive": {"kind": "boost", "grants": {&"interaction.revive_speed_mult": 0.8}, "params": {}},
	&"bot_boost.carry": {"kind": "boost", "grants": {&"loot.carry_speed_penalty_mult": 0.75}, "params": {}},
}

## slot -> {"ability": id, "boost": id}
var picks: Dictionary[int, Dictionary] = {}
## slot -> seconds until the bot may Inspire again
var inspire_cd: Dictionary[int, float] = {}
var _runtime: HeistRuntime = null
var _applied: Dictionary[int, bool] = {}


static func of(rt: HeistRuntime) -> BotCrew:
	if rt == null:
		return null
	var b: BotCrew = rt.service(SERVICE) as BotCrew
	if b == null:
		b = BotCrew.new()
		b.name = NODE_NAME
		b._runtime = rt
		rt.register_service(SERVICE, b)
	return b


## The def of `id`: {"kind", "grants", "params"} (B's resource, else DEFAULTS; {} when unknown).
static func def_for(id: StringName) -> Dictionary:
	if id == &"":
		return {}
	if ContentDB.KINDS.has(CONTENT_KIND) and ContentDB.has(CONTENT_KIND, id):
		var r: Resource = ContentDB.by_id(CONTENT_KIND, id)
		return {"kind": String(r.get(&"kind")), "grants": r.get(&"grants") as Dictionary, "params": r.get(&"params") as Dictionary}
	return DEFAULTS.get(id, {})


## The ability / boost ids of AI slot `crew` (launch option first, then its Loadout).
func _picks_for(crew: CrewController) -> Dictionary:
	var opt: Dictionary = (_runtime.options.get("bot_crew", {}) as Dictionary).get(crew.slot, {})
	var l: Loadout = crew.loadout
	var ability: StringName = StringName(opt.get("ability", l.get(&"bot_ability") if l != null and &"bot_ability" in l else &""))
	var boost: StringName = StringName(opt.get("boost", l.get(&"bot_boost") if l != null and &"bot_boost" in l else &""))
	return {"ability": ability, "boost": boost}


func _physics_process(delta: float) -> void:
	if not Net.is_authority() or _runtime == null:
		return
	for crew: CrewController in _runtime.crew_members():
		if not crew.is_ai:
			continue
		if not _applied.get(crew.slot, false):
			_apply_ability(crew)
		_tick_boost(crew)
		_tick_inspire(crew, delta)


func _apply_ability(crew: CrewController) -> void:
	_applied[crew.slot] = true
	picks[crew.slot] = _picks_for(crew)
	var d: Dictionary = def_for(StringName(picks[crew.slot]["ability"]))
	if not (d.get("grants", {}) as Dictionary).is_empty():
		Modifiers.set_source(crew.slot, &"bot_ability", d["grants"])


func _tick_boost(crew: CrewController) -> void:
	var source: StringName = StringName("bot_boost.%d" % crew.slot)
	var d: Dictionary = def_for(StringName((picks.get(crew.slot, {}) as Dictionary).get("boost", &"")))
	var grants: Dictionary = d.get("grants", {})
	if grants.is_empty() or crew.crew_state == Enums.CrewState.CUSTODY:
		Modifiers.clear_source(Modifiers.TEAM, source)
	else:
		Modifiers.set_source(Modifiers.TEAM, source, grants)


## Inspire: revive the nearest downed teammate in range and in sight, then wait out the cooldown.
func _tick_inspire(crew: CrewController, delta: float) -> void:
	inspire_cd[crew.slot] = maxf(inspire_cd.get(crew.slot, 0.0) - delta, 0.0)
	if StringName((picks.get(crew.slot, {}) as Dictionary).get("ability", &"")) != INSPIRE or inspire_cd[crew.slot] > 0.0 \
			or crew.crew_state != Enums.CrewState.NORMAL:
		return
	var p: Dictionary = def_for(INSPIRE).get("params", {})
	var best: CrewController = null
	var best_d: float = float(p.get("range", 0.0))
	for c: CrewController in _runtime.crew_members():
		if c == crew or c.crew_state != Enums.CrewState.DOWNED or c.health == null:
			continue
		var d: float = c.global_position.distance_to(crew.global_position)
		if d <= best_d and CombatSystem.has_los(crew, crew.eye_position(), c.global_position + Vector3.UP * 0.4, [crew, c]):
			best = c
			best_d = d
	if best != null:
		best.health.revive(crew.slot)
		inspire_cd[crew.slot] = float(p.get("cooldown", 0.0))
