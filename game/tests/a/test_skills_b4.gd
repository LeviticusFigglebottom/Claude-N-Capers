## B's unhooked skill keys, batch 4 (game/content/docs/unhooked_skill_keys.md): gun handling stats (4a, the A-side
## ones; the ADS / sprint keys live in ENV P's files) and combat triggers (4b). Every number comes from B's skill data.
extends TestCase

const HIP_DISCIPLINE: StringName = &"skill.gunnery.hip_discipline"
const STEADY_AIM: StringName = &"skill.marksman.steady_aim"
const HIP_FIRE: StringName = &"skill.scattergun.hip_fire"
const LONG_BARREL: StringName = &"skill.scattergun.long_barrel"
const RUN_AND_GUN: StringName = &"skill.gunnery.run_and_gun"
const WIND_UP: StringName = &"skill.scrapper.wind_up"
const RELOAD_RHYTHM: StringName = &"skill.marksman.reload_rhythm"
const HOT_STREAK: StringName = &"skill.two_gun.hot_streak"
const RHYTHM: StringName = &"skill.two_gun.rhythm"
const ECONOMY: StringName = &"skill.marksman.economy"
const GRAZING: StringName = &"skill.marksman.grazing_fire"
const ANATOMY: StringName = &"skill.gunnery.anatomy"
const KNOCKDOWN: StringName = &"skill.gunnery.knockdown"
const OUTNUMBERED: StringName = &"skill.scattergun.outnumbered"
const THICK_SKIN: StringName = &"skill.juggernaut.thick_skin"

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1204, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "loadouts": {0: _ar_loadout()}})
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)


## The default loadout with an automatic assault rifle as the primary (Economy / Anatomy classes).
func _ar_loadout() -> Loadout:
	var l: Loadout = Loadout.new()
	var tw: CombatTweak = CombatTweak.data()
	l.primary = _weapon_of("assault_rifle", true)
	l.secondary = tw.default_secondary
	l.secondary_mods = tw.default_secondary_mods.duplicate()
	return CrewWeapons.build_loadout(l)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _skill(id: StringName) -> SkillDef:
	return ContentDB.by_id(ContentDB.SKILLS, id) as SkillDef


func _grant(slot: int, id: StringName, aced: bool = false) -> void:
	var g: Dictionary = (_skill(id).grants_basic as Dictionary).duplicate()
	if aced:
		g.merge(_skill(id).grants_aced, true)
	Modifiers.set_source(slot, StringName("test.%s" % id), g)


func _val(id: StringName, key: StringName, aced: bool = false) -> Variant:
	var g: Dictionary = (_skill(id).grants_basic as Dictionary).duplicate()
	if aced:
		g.merge(_skill(id).grants_aced, true)
	return g.get(key)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _intent(aim: bool) -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.aim = aim
	return i


## weapon.hip_spread_mult / still_spread_mult / moving_spread_mult: spread x value when hip-firing / still / moving.
func test_spread_skills() -> void:
	var w: CrewWeapons = _crew(0).weapons
	var s: CrewWeapons.WeaponState = w._states[w.equipped_slot]
	_crew(0).velocity = Vector3.ZERO
	var hip0: float = w._spread_deg(s, _intent(false))
	var ads0: float = w._spread_deg(s, _intent(true))
	_grant(0, HIP_DISCIPLINE)
	assert_near(w._spread_deg(s, _intent(false)), hip0 * float(_val(HIP_DISCIPLINE, &"weapon.hip_spread_mult.all")), 0.0001,
		"Hip Discipline: hip spread")
	assert_near(w._spread_deg(s, _intent(true)), ads0, 0.0001, "aimed: unchanged")
	Modifiers.clear_source(0, StringName("test.%s" % HIP_DISCIPLINE))
	_grant(0, STEADY_AIM, true)
	assert_near(w._spread_deg(s, _intent(true)), ads0 * float(_val(STEADY_AIM, &"weapon.still_spread_mult.all", true)),
		0.0001, "Steady Aim Aced: still")
	_crew(0).velocity = Vector3(CombatTweak.data().moving_speed_threshold + 2.0, 0.0, 0.0)
	var mov0: float = w._spread_deg(s, _intent(true))
	_grant(0, HIP_DISCIPLINE, true)
	assert_near(w._spread_deg(s, _intent(true)), mov0 * float(_val(HIP_DISCIPLINE, &"weapon.moving_spread_mult.all", true)),
		0.0001, "Hip Discipline Aced: moving (not the still mult)")


## weapon.hip_fire_rate_mult (Hip Fire Aced, shotguns): fire rate x value while not aiming.
func test_hip_fire_rate() -> void:
	var w: CrewWeapons = _crew(0).weapons
	var s: CrewWeapons.WeaponState = w._states[w.equipped_slot]
	var v: float = float(_val(HIP_FIRE, &"weapon.hip_fire_rate_mult.shotgun", true))
	w.aiming = false
	var base: float = w._shot_interval(s)
	_grant(0, HIP_FIRE, true)
	var want: float = base / v if s.qualifier == &"shotgun" else base
	assert_near(w._shot_interval(s), want, 0.0001, "only shotguns (this one: %s)" % s.qualifier)
	Modifiers.set_source(0, &"test.class", {StringName("weapon.hip_fire_rate_mult.%s" % s.qualifier): v})
	assert_near(w._shot_interval(s), base / v, 0.0001, "hip fire: faster")
	w.aiming = true
	assert_near(w._shot_interval(s), base, 0.0001, "aiming: unchanged")


## weapon.falloff_range_mult (Long Barrel Aced, shotguns): falloff distances x value.
func test_falloff_range() -> void:
	var w: CrewWeapons = _crew(0).weapons
	var s: CrewWeapons.WeaponState = w._states[w.equipped_slot]
	var v: float = float(_val(LONG_BARREL, &"weapon.falloff_range_mult.shotgun", true))
	var d: float = (s.stats.falloff_start_m + s.stats.falloff_end_m) * 0.5
	var near_far: float = w.damage_at(w.equipped_slot, d * v)
	var at_d: float = w.damage_at(w.equipped_slot, d)
	_grant(0, LONG_BARREL, true)
	if s.qualifier != &"shotgun":
		assert_near(w.damage_at(w.equipped_slot, d * v), near_far, 0.0001, "not a shotgun: unchanged")
	Modifiers.set_source(0, &"test.class", {StringName("weapon.falloff_range_mult.%s" % s.qualifier): v})
	assert_near(w.damage_at(w.equipped_slot, d * v), at_d, 0.0001, "x%.2f the distance hits as hard as before" % v)


## A weapon id of class `cls` (with a full-auto mode when `auto`), &"" if none.
func _weapon_of(cls: String, auto: bool = false) -> StringName:
	for w: WeaponDef in ContentDB.all_weapons():
		if String(Enums.weapon_class_qualifier(w.weapon_class)) == cls and (not auto or w.fire_modes.has(&"auto")):
			return w.id
	return &""


func _enemy(pos: Vector3) -> NpcBase:
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	return dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"), Transform3D(Basis.IDENTITY, pos), null)


func _hit(npc: NpcBase, weapon_id: StringName, head: bool, amount: float = 10.0) -> void:
	EventBus.damage_applied.emit(npc.net_id, _crew(0).net_id, {"amount": amount, "weapon_id": weapon_id,
		"zone": Enums.HitZone.HEAD if head else Enums.HitZone.BODY})


## weapon.kill_reload_buff: Reload Rhythm (headshot kill), Wind Up (melee kill), Run and Gun (auto kills, next reload).
func test_kill_reload_buffs() -> void:
	var ar: StringName = _weapon_of("assault_rifle", true)
	_grant(0, RELOAD_RHYTHM, true)
	var rr: Dictionary = _val(RELOAD_RHYTHM, &"weapon.kill_reload_buff", true)
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {"weapon_id": ar, "zone": Enums.HitZone.BODY})
	assert_eq(Modifiers.mult(0, &"weapon.reload_speed_mult"), 1.0, "a body kill: nothing")
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {"weapon_id": ar, "zone": Enums.HitZone.HEAD})
	assert_near(Modifiers.mult(0, &"weapon.reload_speed_mult"), float(rr["reload_mult"]), 0.0001, "a headshot kill: faster")
	assert_near(CrewBuffs.of(_rt).left(0, StringName("kill_reload.test.%s" % RELOAD_RHYTHM)), float(rr["duration"]), 0.1,
		"for duration s")
	Modifiers.clear_source(0, StringName("test.%s" % RELOAD_RHYTHM))
	CrewBuffs.of(_rt).end(0, StringName("kill_reload.test.%s" % RELOAD_RHYTHM))
	_grant(0, WIND_UP, true)
	var wu: Dictionary = _val(WIND_UP, &"weapon.kill_reload_buff", true)
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {"weapon_id": &"melee.bash", "type": Enums.DamageType.MELEE})
	assert_near(Modifiers.mult(0, &"weapon.reload_speed_mult"), float(wu["reload_mult"]), 0.0001, "Wind Up: a melee kill")
	Modifiers.clear_source(0, StringName("test.%s" % WIND_UP))
	CrewBuffs.of(_rt).end(0, StringName("kill_reload.test.%s" % WIND_UP))
	_grant(0, RUN_AND_GUN, true)
	var rg: Dictionary = _val(RUN_AND_GUN, &"weapon.kill_reload_buff", true)
	for i: int in int(rg["kills"]) - 1:
		EventBus.npc_killed.emit(9999, _crew(0).net_id, {"weapon_id": ar})
	assert_eq(Modifiers.mult(0, &"weapon.reload_speed_mult"), 1.0, "Run and Gun: not before `kills` kills")
	EventBus.npc_killed.emit(9999, _crew(0).net_id, {"weapon_id": ar})
	var w: CrewWeapons = _crew(0).weapons
	var past: float = maxf(float(w.mag_size(w.equipped_slot) - int(rg["mag_falloff_from"])), 0.0)
	assert_near(Modifiers.mult(0, &"weapon.reload_speed_mult"), maxf(float(rg["reload_mult"]) - float(rg["mag_falloff"]) * past,
		float(rg["min_mult"])), 0.0001, "the next reload, by magazine size")
	SkillTriggers.reload_done(_crew(0))
	assert_eq(Modifiers.mult(0, &"weapon.reload_speed_mult"), 1.0, "spent by the reload")


## weapon.hit_stack_buff: Hot Streak (pistol damage) and Rhythm (pistol accuracy) stack per hit up to max_stacks.
func test_hit_stacks() -> void:
	var pistol: StringName = _weapon_of("pistol")
	var npc: NpcBase = _enemy(Vector3(0, 0, -20))
	_grant(0, HOT_STREAK)
	var hs: Dictionary = _val(HOT_STREAK, &"weapon.hit_stack_buff")
	_hit(npc, pistol, false)
	_hit(npc, pistol, false)
	assert_near(Modifiers.mult(0, &"weapon.damage_mult", &"pistol"),
		1.0 + float(hs["per_hit"]) * float(hs["max_stacks"]), 0.0001, "Hot Streak: capped at max_stacks")
	Modifiers.clear_source(0, StringName("test.%s" % HOT_STREAK))
	_grant(0, RHYTHM)
	var rh: Dictionary = _val(RHYTHM, &"weapon.hit_stack_buff")
	for i: int in 2:
		_hit(npc, pistol, false)
	assert_near(Modifiers.mult(0, &"weapon.spread_mult", &"pistol"), 1.0 - 2.0 * float(rh["per_hit"]), 0.0001,
		"Rhythm: two stacks of accuracy")
	_hit(npc, _weapon_of("assault_rifle"), false)
	assert_near(Modifiers.mult(0, &"weapon.spread_mult", &"pistol"), 1.0 - 2.0 * float(rh["per_hit"]), 0.0001,
		"another class adds none")


## weapon.headshot_refund (Economy): `headshots` headshots within the window return `refund` rounds.
func test_headshot_refund() -> void:
	var w: CrewWeapons = _crew(0).weapons
	var ws: int = w.equipped_slot
	var p: Dictionary = _val(ECONOMY, &"weapon.headshot_refund", true)
	var cls: String = String(Enums.weapon_class_qualifier(ContentDB.weapon(w.weapon_id(ws)).weapon_class))
	assert_true((p["classes"] as Array).has(cls), "the default primary (%s) is an Economy class" % cls)
	_grant(0, ECONOMY, true)
	var npc: NpcBase = _enemy(Vector3(0, 0, -20))
	w.set_ammo(ws, w.mag(ws) - 5, w.reserve(ws))
	var mag: int = w.mag(ws)
	for i: int in int(p["headshots"]) - 1:
		_hit(npc, w.weapon_id(ws), true)
	assert_eq(w.mag(ws), mag, "not before `headshots` headshots")
	_hit(npc, w.weapon_id(ws), true)
	assert_eq(w.mag(ws), mag + int(p["refund"]), "a round back in the magazine")


## weapon.graze (Grazing Fire): a sniper hit deals frac of its damage around the target (Aced: all of it on a
## headshot kill).
func test_graze() -> void:
	var sniper: StringName = _weapon_of("sniper")
	var a: NpcBase = _enemy(Vector3(0, 0, -20))
	var b: NpcBase = _enemy(Vector3(0.6, 0, -20))
	await wait_physics_frames(2)
	_grant(0, GRAZING, true)
	var got: Array[float] = []
	var trigger: Array[float] = []
	var on_hit: Callable = func(victim: int, _att: int, info: Dictionary) -> void:
		if victim == b.net_id and bool(info.get("graze", false)):
			got.append(float(info.get("amount", 0.0)))
		elif victim == a.net_id:
			trigger.append(float(info.get("amount", 0.0)))
	EventBus.damage_applied.connect(on_hit)
	_hit(a, _weapon_of("assault_rifle"), false, 50.0)
	assert_true(got.is_empty(), "another class: no graze")
	_hit(a, sniper, false, 50.0)
	assert_eq(got.size(), 1, "a sniper hit grazes the neighbour")
	a.health = 1.0
	CombatSystem.deliver_hit(a, Damage.info(50.0, Enums.DamageType.BULLET, Enums.HitZone.HEAD, sniper, a.global_position,
		Vector3.FORWARD, _crew(0).net_id), _crew(0).net_id)
	EventBus.damage_applied.disconnect(on_hit)
	assert_eq(got.size(), 2, "the headshot kill grazes too")
	var p: Dictionary = _val(GRAZING, &"weapon.graze", true)
	if got.size() == 2 and not trigger.is_empty():
		assert_near(got[0], 50.0 * float(p["frac"]), 0.01, "frac of the hit")
		assert_near(got[1], trigger[trigger.size() - 1] * float(p["headshot_kill_frac"]), 0.01,
			"Aced: headshot_kill_frac of the killing hit")


## weapon.body_expertise (Anatomy): an auto weapon's body shot gets `frac` of the headshot multiplier (NpcBase).
func test_body_expertise() -> void:
	var p: Dictionary = _val(ANATOMY, &"weapon.body_expertise", true)
	var ar: StringName = _weapon_of("assault_rifle", true)
	assert_eq(CombatSystem.body_expertise_frac(0, ar, Enums.HitZone.BODY), 0.0, "no skill: nothing")
	_grant(0, ANATOMY, true)
	assert_near(CombatSystem.body_expertise_frac(0, ar, Enums.HitZone.BODY), float(p["frac"]), 0.0001, "an auto AR body shot")
	assert_eq(CombatSystem.body_expertise_frac(0, ar, Enums.HitZone.HEAD), 0.0, "a headshot already has it")
	assert_eq(CombatSystem.body_expertise_frac(0, _weapon_of("pistol"), Enums.HitZone.BODY), 0.0, "not a listed class")
	var npc: NpcBase = _enemy(Vector3(0, 0, -20))
	npc.max_health = 100000.0
	npc.health = 100000.0
	var base: Dictionary = npc.take_hit(Damage.info(10.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, ar,
		Vector3.ZERO, Vector3.FORWARD, _crew(0).net_id), _crew(0).net_id)
	var info: Dictionary = Damage.info(10.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, ar, Vector3.ZERO, Vector3.FORWARD,
		_crew(0).net_id)
	info["body_expertise"] = float(p["frac"])
	var out: Dictionary = npc.take_hit(info, _crew(0).net_id)
	var hm: float = npc.enemy_def.headshot_mult[clampi(npc.difficulty, 0, npc.enemy_def.headshot_mult.size() - 1)]
	assert_near(float(out["amount"]), float(base["amount"]) * lerpf(1.0, hm, float(p["frac"])), 0.01,
		"frac of the head multiplier on the body")


## weapon.stagger_chance_add (Knockdown): the chance a hit stuns a non-special enemy.
func test_knockdown_stagger() -> void:
	_grant(0, KNOCKDOWN, true)
	assert_near(Modifiers.add(0, &"weapon.stagger_chance_add", &"assault_rifle"),
		float(_val(KNOCKDOWN, &"weapon.stagger_chance_add.all", true)), 0.0001, "the chance")
	Modifiers.set_source(0, &"test.sure", {&"weapon.stagger_chance_add.all": 1.0})
	var npc: NpcBase = _enemy(Vector3(0, 0, -20))
	_hit(npc, _weapon_of("assault_rifle"), false)
	assert_true(npc.is_stunned(), "a sure stagger stuns")


## defense.outnumbered: with `enemies` within radius, damage x damage_mult (Aced: damage taken x value) for duration.
func test_outnumbered() -> void:
	var p: Dictionary = _val(OUTNUMBERED, &"defense.outnumbered", true)
	_grant(0, OUTNUMBERED, true)
	var at: Vector3 = _crew(0).global_position
	for i: int in int(p["enemies"]) - 1:
		_enemy(at + Vector3(3.0 + i, 0, 0))
	await wait_physics_frames(3)
	assert_eq(Modifiers.mult(0, &"weapon.damage_mult", &"assault_rifle"), 1.0, "one short: nothing")
	_enemy(at + Vector3(0, 0, 4))
	await wait_physics_frames(3)
	assert_near(Modifiers.mult(0, &"weapon.damage_mult", &"assault_rifle"), float(p["damage_mult"]), 0.0001, "outnumbered")
	assert_near(Modifiers.mult(0, &"defense.damage_taken_mult"), float(p["damage_taken_mult"]), 0.0001, "Aced: tougher")


## defense.flashbang_duration_mult (Thick Skin): flash blind time x value.
func test_thick_skin_flash() -> void:
	var h: CrewHealth = _crew(0).health
	h.flash(4.0)
	var base: float = h.flashed_left
	h.flashed_left = 0.0
	_grant(0, THICK_SKIN, true)
	h.flash(4.0)
	assert_near(h.flashed_left, base * float(_val(THICK_SKIN, &"defense.flashbang_duration_mult", true)), 0.0001, "shorter")
