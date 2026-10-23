## D-164 perk.leech (Lifeline) on B's names: the ampule window (activate heal, armor off, segmented health, kills
## restore a segment, team heal on damage), the cooldown from the window's end with kill cuts, no_bleedout with the
## zero-health slow, the temporary revive while down (back down at the end unless kept), and the PerkItems segments
## (ui_hud v1.22).
extends TestCase

const ITEM: StringName = &"throwable.test_leech_ampule"
const LEECH: Dictionary = {"duration_s": 6.0, "cooldown_s": 40.0, "kill_cooldown_reduction_s": 1.0,
	"activate_heal_fraction": 0.4, "armor_off": true, "segment_fraction": 0.2, "kills_per_segment": 2,
	"team_heal_on_damage_fraction": 0.05}

var _rt: HeistRuntime = null
var _victim_id: int = 8500


func before_each() -> void:
	var d: ThrowableDef = ThrowableDef.new()
	d.id = ITEM
	d.kind = PerkLeech.KIND
	d.count = 1
	ContentDB.inject(ContentDB.THROWABLES, ITEM, d)
	_rt = await HeistLauncher.launch(&"unit_map", 1640, Enums.Difficulty.ROUTINE, self,
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


func _grant(extra: Dictionary = {}) -> PerkLeech:
	var p: Dictionary = LEECH.duplicate()
	p.merge(extra, true)
	Modifiers.set_source(0, &"deck", {PerkLeech.KEY: p, &"perk.throwable": {"item_id": ITEM},
		&"defense.dodge_add": -1.0})
	var perks: CrewPerks = PerkHooks.of(_crew())
	perks.refresh()
	return perks.component(PerkLeech.KEY) as PerkLeech


func _hit(amount: float) -> void:
	var h: CrewHealth = _crew().health
	h.grace_left = 0.0
	h.invuln_left = 0.0
	_crew().take_hit(Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", _crew().global_position,
		Vector3.FORWARD), 0)


func _kill() -> void:
	_victim_id += 1
	EventBus.npc_killed.emit(_victim_id, _crew().net_id, {"type": Enums.DamageType.BULLET})


func test_window_heal_armor_segments_kills_team_heal() -> void:
	var l: PerkLeech = _grant()
	var h: CrewHealth = _crew().health
	var mate: CrewHealth = _crew(1).health
	h.health = h.max_health * 0.5
	mate.health = mate.max_health * 0.5
	assert_true(PerkHooks.use_throwable(_crew()), "the ampule")
	assert_near(h.health, h.max_health * 0.9, 0.01, "+40 % on use")
	await wait_physics_frames(2)
	assert_near(h.armor, 0.0, 0.001, "armor off")
	assert_near(h.max_armor, 0.0, 0.001, "max armor 0 in the window")
	assert_eq(l.segment_total(), 5, "segments of 20 %")
	assert_eq(l.segments_left(), 5, "90 %: 5 segments (the top one partly filled)")
	_hit(1.0)
	assert_near(h.health, h.max_health * 0.8, 0.01, "a small hit takes the whole top segment")
	_hit(9999.0)
	assert_near(h.health, h.max_health * 0.6, 0.01, "a huge hit: one segment only")
	assert_near(mate.health, mate.max_health * 0.6, 0.01, "each hit heals the teammate 5 %")
	_kill()
	assert_near(h.health, h.max_health * 0.6, 0.01, "1 kill: not yet")
	_kill()
	assert_near(h.health, h.max_health * 0.8, 0.01, "2 kills: a segment back")
	await wait_physics_frames(2)
	var st: Dictionary = (_rt.service(PerkItems.SERVICE) as PerkItems).state(0)
	assert_eq(st.get("segments", {}), {"count": 4, "size": 5}, "segments on the HUD state")
	assert_false(PerkHooks.use_throwable(_crew()), "not again while active")


func test_end_cooldown_and_kill_cuts() -> void:
	var l: PerkLeech = _grant()
	var h: CrewHealth = _crew().health
	PerkHooks.use_throwable(_crew())
	_kill()
	l.active_left = 0.05
	await wait_physics_frames(4)
	assert_false(l.is_active(), "the window ended")
	assert_true(h.max_armor > 0.0, "armor back on")
	assert_near(h.armor, 0.0, 0.5, "through its regen, not refilled")
	assert_near(l.cooldown_left, 40.0, 0.2, "the cooldown starts at the end")
	_kill()
	assert_near(l.cooldown_left, 39.0, 0.2, "-1 s per kill")
	await wait_physics_frames(2)
	assert_false((_rt.service(PerkItems.SERVICE) as PerkItems).state(0).has("segments"), "no segments outside")


func test_no_bleedout_slow_then_down_at_the_end() -> void:
	var l: PerkLeech = _grant({"no_bleedout": true, "zero_health_speed_mult": 0.2})
	var h: CrewHealth = _crew().health
	h.health = h.max_health * 0.1
	PerkHooks.use_throwable(_crew())
	for _i: int in 4:
		_hit(9999.0)
	assert_near(h.health, 0.0, 0.001, "at 0 health")
	assert_eq(_crew().crew_state, Enums.CrewState.NORMAL, "no down in the window")
	await wait_physics_frames(2)
	assert_near(Modifiers.mult(0, &"movement.speed_mult"), 0.2, 0.0001, "x0.2 speed at 0 health")
	l.active_left = 0.05
	await wait_physics_frames(4)
	assert_eq(_crew().crew_state, Enums.CrewState.DOWNED, "the window ends at 0 health: down")
	assert_near(Modifiers.mult(0, &"movement.speed_mult"), 1.0, 0.0001, "the slow ends")


func test_temporary_revive_while_down() -> void:
	var l: PerkLeech = _grant({"usable_while_downed": true})
	var h: CrewHealth = _crew().health
	h.go_down()
	var downs: int = h.downs_used
	h.bleedout_left = 20.0
	assert_true(PerkHooks.use_throwable(_crew()), "usable while down")
	assert_eq(_crew().crew_state, Enums.CrewState.NORMAL, "up again")
	assert_near(h.health, h.max_health * 0.4, 0.01, "at the activate heal")
	l.active_left = 0.05
	await wait_physics_frames(4)
	assert_eq(_crew().crew_state, Enums.CrewState.DOWNED, "back down at the end")
	assert_eq(h.downs_used, downs, "the same down, not a new one")
	assert_near(h.bleedout_left, 20.0, 0.5, "with the bleed-out it had")
	l.cooldown_left = 0.0
	assert_true(PerkHooks.use_throwable(_crew()), "again")
	EventBus.crew_revived.emit(1, 0)  # the holder revives a teammate
	l.active_left = 0.05
	await wait_physics_frames(4)
	assert_eq(_crew().crew_state, Enums.CrewState.NORMAL, "kept up: a revive given")


func test_not_usable_while_down_by_default() -> void:
	_grant()
	_crew().health.go_down()
	assert_false(PerkHooks.use_throwable(_crew()), "card 9 not held: no use while down")


func test_item_cooldowns_run_while_down() -> void:
	var l: PerkLeech = _grant()
	Modifiers.set_source(0, &"deck2", {PerkKingpin.KEY: {"cooldown_s": 30.0, "duration_s": 4.0}})
	var perks: CrewPerks = PerkHooks.of(_crew())
	perks.refresh()
	var k: PerkKingpin = perks.component(PerkKingpin.KEY) as PerkKingpin
	l.cooldown_left = 10.0
	k.cooldown_left = 10.0
	k.active_left = 3.0
	_crew().health.go_down()
	assert_eq(_crew().crew_state, Enums.CrewState.DOWNED)
	await wait_physics_frames(30)
	assert_true(l.cooldown_left < 9.7, "Leech's cooldown runs while down (%.2f)" % l.cooldown_left)
	assert_true(k.cooldown_left < 9.7, "and Kingpin's injector cooldown (%.2f)" % k.cooldown_left)
	assert_near(k.active_left, 3.0, 0.0001, "only the cooldown: the rest of the component stays paused")


func test_d164_weapons_refill_mag_and_headshot_info() -> void:
	var w: CrewWeapons = _crew().weapons
	var ws: int = w.equipped_slot
	w.set_ammo(ws, 0, 1000)
	var size: int = w.mag_size(ws)
	assert_eq(w.refill_mag(ws), size, "from the reserve")
	assert_eq(w.mag(ws), size)
	assert_eq(w.reserve(ws), 1000 - size)
	w.set_ammo(ws, 0, 0)
	assert_eq(w.refill_mag(ws), 0, "an empty reserve gives nothing")
	assert_eq(w.refill_mag(ws, true), size, "free fills anyway")
	assert_true(PerkHooks.is_headshot({"zone": Enums.HitZone.HEAD}), "headshot")
	assert_false(PerkHooks.is_headshot({"zone": Enums.HitZone.BODY}))
	assert_false(PerkHooks.is_headshot({}))


## LEAD (B's finding): a deck item fires CrewThrowables.deck_item_used(item_id, kind) for the FP / 3P use pose, and
## deck_item_def() resolves its ThrowableDef though the deck (not the loadout) supplies it; a refused use emits nothing.
func test_deck_item_used_signal_and_def() -> void:
	_grant()
	var t: CrewThrowables = _crew().get_node(CrewThrowables.NODE_NAME) as CrewThrowables
	var got: Array = []
	t.deck_item_used.connect(func(id: StringName, kind: StringName) -> void: got.append([id, kind]))
	assert_true(t.deck_item_def() != null and t.deck_item_def().id == ITEM, "the deck item's def")
	assert_true(t.throwable_def() == null, "not a grenade-type throwable")
	assert_true(PerkHooks.use_throwable(_crew()), "used")
	assert_eq(got, [[ITEM, PerkLeech.KIND]], "deck_item_used(item_id, kind) once")
	assert_false(PerkHooks.use_throwable(_crew()), "refused while active")
	assert_eq(got.size(), 1, "a refused use emits nothing")
