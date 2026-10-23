## D-163 perk decks on B's names: perk.sicario (Veil: the smoke bomb cloud with its params, the cooldown from the cloud's
## end with kill cuts, Twitch, dodge_restores_armor, in_smoke_effect_mult, ally_in_smoke_dodge_add) and perk.tag_team
## (Buddy System: the aim-line tag, kill heals for both, kill_extend_s, Synergy absorb until off cooldown, the
## tagged-kill cooldown cut), each publishing its PerkItems state (ui_hud v1.21) and clearing it when the deck goes.
extends TestCase

const SMOKE_ITEM: StringName = &"throwable.test_smoke_bomb"
const GAS_ITEM: StringName = &"throwable.test_gas_dispenser"
const SICARIO: Dictionary = {"smoke_duration_s": 10.0, "smoke_radius_m": 4.0, "cooldown_s": 60.0,
	"kill_cooldown_reduction_s": 1.0, "in_smoke_dodge_add": 0.5, "enemy_accuracy_mult": 0.5}
const TAG: Dictionary = {"tag_range_m": 18.0, "duration_s": 11.0, "cooldown_s": 60.0, "kill_extend_s": 1.3,
	"holder_kill_heal": 15.0, "tagged_kill_heal": 7.5}

var _rt: HeistRuntime = null
var _victim_id: int = 8000


func before_each() -> void:
	for pair: Array in [[SMOKE_ITEM, ThrownItem.KIND_SMOKE], [GAS_ITEM, PerkTagTeam.KIND]]:
		var d: ThrowableDef = ThrowableDef.new()
		d.id = pair[0]
		d.kind = pair[1]
		d.count = 1
		ContentDB.inject(ContentDB.THROWABLES, d.id, d)
	_rt = await HeistLauncher.launch(&"unit_map", 1631, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "skip_casing": true})
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	ContentDB.clear_cache()
	await wait_frames(1)


func _crew(slot: int = 0) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _grant(key: StringName, base: Dictionary, extra: Dictionary, item: StringName, dodge: float = -1.0) -> PerkComponent:
	var p: Dictionary = base.duplicate()
	p.merge(extra, true)
	Modifiers.set_source(0, &"deck", {key: p, &"perk.throwable": {"item_id": item}, &"defense.dodge_add": dodge})
	var perks: CrewPerks = PerkHooks.of(_crew())
	perks.refresh()
	return perks.component(key)


func _kill_by(c: CrewController) -> void:
	_victim_id += 1
	EventBus.npc_killed.emit(_victim_id, c.net_id, {"type": Enums.DamageType.BULLET})


func _hit(c: CrewController, amount: float = 5.0) -> void:
	c.health.grace_left = 0.0
	c.take_hit(Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", c.global_position,
		Vector3.FORWARD), 0)


func _items() -> PerkItems:
	return _rt.service(PerkItems.SERVICE) as PerkItems


# --- Sicario -----------------------------------------------------------------------------------

func test_sicario_smoke_bomb_cloud_and_cooldown() -> void:
	var s: PerkSicario = _grant(PerkSicario.KEY, SICARIO, {}, SMOKE_ITEM) as PerkSicario
	assert_true(PerkHooks.use_throwable(_crew()), "the throwable key throws the smoke bomb")
	var cloud: ThrownItem = s.cloud
	assert_true(cloud != null and cloud.kind() == ThrownItem.KIND_SMOKE, "a smoke item")
	assert_near(cloud.smoke_radius(), 4.0, 0.0001, "smoke_radius_m")
	assert_near(float(cloud.params["crew_bullet_avoid"]), 0.5, 0.0001, "in_smoke_dodge_add")
	assert_near(float(cloud.params["npc_accuracy_mult"]), 0.5, 0.0001, "enemy_accuracy_mult")
	assert_false(PerkHooks.use_throwable(_crew()), "one at a time")
	assert_true(await wait_until(func() -> bool: return cloud.landed, 4.0), "it lands and smokes")
	assert_near(cloud.pool_left, 10.0, 0.5, "smoke_duration_s")
	_kill_by(_crew())
	assert_near(s.cooldown_left, 60.0, 0.01, "the cooldown waits for the cloud (kills do not cut it yet)")
	await wait_physics_frames(1)
	assert_eq(int(_items().state(0)["charges"]), 0)
	assert_true(float(_items().state(0)["active_left"]) > 9.0, "active_left on the HUD state")
	cloud.pool_left = 0.05
	assert_true(await wait_until(func() -> bool: return s.cloud == null, 2.0), "the cloud ends")
	_kill_by(_crew())
	assert_near(s.cooldown_left, 59.0, 0.2, "then it recharges, -1 s per kill")
	assert_false(PerkHooks.use_throwable(_crew()), "still recharging")
	s.cooldown_left = 0.0
	await wait_physics_frames(2)
	assert_eq(int(_items().state(0)["charges"]), 1, "ready on the HUD state")
	Modifiers.clear_source(0, &"deck")
	PerkHooks.of(_crew()).refresh()
	assert_eq(_items().state(0), {}, "the deck gone: no HUD item")


func test_sicario_twitch_and_armor_on_dodge() -> void:
	var s: PerkSicario = _grant(PerkSicario.KEY, SICARIO, {"twitch_dodge_add": 0.2, "twitch_lockout_s": 4.0,
		"dodge_restores_armor": true}, SMOKE_ITEM) as PerkSicario
	var h: CrewHealth = _crew().health
	_hit(_crew())
	_hit(_crew())
	assert_eq(s.twitch_stacks, 2, "+1 per hit taken")
	assert_near(s.dodge_add(), 0.4, 0.0001, "+0.2 each")
	h.armor = 0.0
	PerkHooks.on_dodge(h)
	assert_eq(s.twitch_stacks, 0, "a dodge resets Twitch")
	assert_near(h.armor, h.max_armor, 0.01, "card 7: the armor refills")
	_hit(_crew())
	assert_eq(s.twitch_stacks, 0, "locked out for twitch_lockout_s")
	s.tick(4.1)
	_hit(_crew())
	assert_eq(s.twitch_stacks, 1, "stacking again")


func test_sicario_card9_in_smoke_doubles_and_allies() -> void:
	var s: PerkSicario = _grant(PerkSicario.KEY, SICARIO, {"twitch_dodge_add": 0.2, "in_smoke_effect_mult": 2.0,
		"ally_in_smoke_dodge_add": 0.1}, SMOKE_ITEM, 0.15) as PerkSicario
	s.twitch_stacks = 1
	assert_near(s.dodge_add(), 0.2, 0.0001, "outside the smoke: x1")
	PerkHooks.use_throwable(_crew())
	var cloud: ThrownItem = s.cloud
	assert_true(await wait_until(func() -> bool: return cloud.landed, 4.0), "landed")
	_crew().global_position = cloud.global_position
	_crew(1).global_position = cloud.global_position + Vector3(1, 0, 0)
	await wait_physics_frames(1)
	assert_near(s.dodge_add(), 0.4 + 0.15, 0.0001, "in the smoke: Twitch x2 and the deck's dodge x2 (+0.15)")
	var mate: CrewHealth = _crew(1).health
	assert_near(PerkHooks.dodge_add(mate), 0.1, 0.0001, "an ally in the holder's cloud: +0.1")
	_crew(1).global_position = cloud.global_position + Vector3(20, 0, 0)
	assert_near(PerkHooks.dodge_add(mate), 0.0, 0.0001, "outside it: nothing")


# --- Tag Team ----------------------------------------------------------------------------------

func test_tag_team_tag_heals_absorb_extend_and_cut() -> void:
	var t: PerkTagTeam = _grant(PerkTagTeam.KEY, TAG, {"kill_absorb": 2.0, "max_absorb": 3.0,
		"tagged_kill_cooldown_cut_s": 2.0}, GAS_ITEM) as PerkTagTeam
	var holder: CrewController = _crew()
	var mate: CrewController = _crew(1)
	mate.global_position = holder.global_position + holder.aim_direction().normalized() * 6.0
	await wait_physics_frames(2)
	assert_true(PerkHooks.use_throwable(holder), "the gas dispenser tags the teammate on the aim line")
	var tp: TagPairs = TagPairs.of(_rt)
	assert_eq(tp.tagged_of(0), 1)
	holder.health.health = holder.health.max_health - 100.0
	mate.health.health = mate.health.max_health - 100.0
	_kill_by(mate)
	assert_near(holder.health.health, holder.health.max_health - 85.0, 0.01, "the tagged ally's kill heals the holder 15")
	assert_near(mate.health.health, mate.health.max_health - 92.5, 0.01, "and the ally 7.5")
	assert_near(tp.cooldown_left(0), 58.0, 0.1, "card 9: -2 s cooldown")
	assert_near(PerkHooks.absorb(holder), 2.0, 0.0001, "card 5: +2 absorb")
	var left: float = float(tp.pairs[0]["left"])
	_kill_by(holder)
	assert_near(float(tp.pairs[0]["left"]), left + 1.3, 0.05, "a holder kill extends the pair 1.3 s")
	assert_near(PerkHooks.absorb(holder), 3.0, 0.0001, "capped at max_absorb")
	assert_near(PerkHooks.absorb(mate), 0.0, 0.0001, "the holder's absorb only")
	await wait_physics_frames(2)
	var st: Dictionary = _items().state(0)
	assert_eq(StringName(st["kind"]), PerkTagTeam.KIND, "HUD state kind")
	assert_eq(int(st["partner_slot"]), 1, "partner_slot")
	assert_true(float(st["active_left"]) > 10.0, "active_left")
	tp.pairs[0]["left"] = 0.0
	tp.pairs[0]["tagged"] = -1
	_kill_by(holder)
	assert_near(holder.health.health, holder.health.max_health - 70.0, 0.01, "unpaired: no heal")
	assert_near(PerkHooks.absorb(holder), 3.0, 0.0001, "the absorb stays while the item recharges")
	tp.pairs[0]["cooldown"] = 0.0
	await wait_physics_frames(2)
	assert_near(PerkHooks.absorb(holder), 0.0, 0.0001, "off cooldown: Synergy ends")
	assert_eq(int(_items().state(0)["partner_slot"]), -1, "no partner")


func test_tag_team_miss_costs_nothing() -> void:
	_grant(PerkTagTeam.KEY, TAG, {}, GAS_ITEM)
	var holder: CrewController = _crew()
	_crew(1).global_position = holder.global_position + holder.aim_direction().normalized() * 30.0
	await wait_physics_frames(2)
	assert_false(PerkHooks.use_throwable(holder), "nobody within tag_range_m")
	assert_eq(TagPairs.of(_rt).cooldown_left(0), 0.0, "no cooldown")
