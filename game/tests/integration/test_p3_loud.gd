## P3 GATE: loud complete (docs/roadmap.md P3 gate: "bot crew survives scripted waves; specials'
## counterplay verified"). Owner: LEAD. Rows: pd2_fidelity.md L1 (director), L2.8-L2.10 (takedowns,
## custody, trade), L4.3-L4.11 (specials, Brandt, caps), L6.1 (AI orders).
## Every test runs the real P3 map (HEIST) through contracts/test_hooks.md (HeistLauncher, HeistRuntime
## hooks, CrewIntent bots) and ENV A's public systems; facts are observed on EventBus. ENV A classes
## are referenced statically: a missing mechanic is a LOAD FAIL or an assertion failure, never a skip.
##   test_01_scripted_waves_escalation_and_caps   L1.1-L1.5, L4.11: 3 compressed waves, bot crew fights
##   test_02_phantom_kick_and_teammate_rescue     L4.3, L2.8
##   test_03_stinger_tase_broken_by_kill          L4.4, L2.8 (crew_tased / crew_tase_ended, D-049)
##   test_04_bulwark_shield_pierce_flank_stagger  L4.5, L3.4
##   test_05_wrecker_plates_then_head             L4.6
##   test_06_longshot_perch_laser_cover_then_shot L4.7
##   test_07_corpsman_revives_until_killed        L4.8
##   test_08_brandt_aegis_lock_resist_retreat     L4.9
##   test_09_custody_and_hostage_trades           L2.9, L2.10, L6.3 (+ S7 shout and tie)
##   test_10_ai_orders_during_assault             L6.1 (A3-05 hold / follow / revive)
## Setup shortcuts (outside the mechanic under test, each named where used): the director's timings are
## compressed with the launch option `director_tweak` (test_01, test_08, test_10) or emptied (special
## tests: no other police, so a counterplay is not decided by stray units); NPCs not under test are
## despawned with isolate_npc() (special tests) or, for the Co-op's cartel gunmen (GUARD spawns, awake in
## COMBAT from the load; not the subject of test_01, test_09 or test_10), with _despawn_cartel(); crew
## damage immunity (`defense.damage_taken_mult` 0) and no dodge (`defense.dodge_add` -1) are modifier
## sources where crew damage is not the subject; specials are placed with SpecialSpawner /
## HeistRuntime.spawn_npc (the director's own spawn path), and so is the night-shift hostage test_09
## needs beyond the rolled `night_shift`; custody comes from a lethal hit with no downs left (L2.6)
## instead of three full down/revive cycles.
## The bots fight with real CrewIntent fire (hitscan claims validated by the server, CombatSystem).
extends TestCase

## P3 map: Dockside Burn, the loud-only P3 heist (docs/design/heists/dockside_burn.md, D-064; D-070).
const HEIST: StringName = &"dockside_burn"
## Seed 3007 resolves guard_post = hall / platform / yard_e / yard_w (8 cartel gunmen), east_gangway =
## gangway_up (no Pier 10 police spawn), escape = esc_van_gate, night_shift = shift_1 (one worker).
const SEED: int = 3007
## Loud-gate difficulty: FRD faction, every special in the roster, Brandt eligible (captain_min_difficulty).
const DIFF: Enums.Difficulty = Enums.Difficulty.HAZARDOUS
const DIRECTOR_TWEAK: String = "res://systems/director/director_tweak.tres"
const TIME_SCALE: float = 2.0
const WAVE_TIME_SCALE: float = 3.0
const RISE_FRAMES: int = 3
const ARENA_DIST_M: float = 12.0
## test_01's hold: Ferro Street in front of the yard gate (dockside_burn.md Site: the gate is x 30-38 on
## the z -34 fence, the street z -52..-40), the open street the crew arrives on; police come down it
## from the closures at its ends.
const WAVE_HOLD: Vector3 = Vector3(31.5, 0.0, -45.0)

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []
var _t0: int = 0
## Most open navmesh point of the map (deterministic for HEIST + SEED), computed once per file.
var _arena: Vector3 = Vector3.INF
var _arena_dirs: Array[Vector3] = []
## test_04: the most open navmesh point with no SHIELD_ANCHOR in a Bulwark's reach, computed once.
var _standoff: Vector3 = Vector3.INF
var _standoff_dirs: Array[Vector3] = []


func before_each() -> void:
	Engine.time_scale = 1.0
	_events.clear()
	_t0 = Time.get_ticks_msec()


func after_each() -> void:
	Engine.time_scale = 1.0
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
		print("[P3] %s: %.1f s" % [_current, float(Time.get_ticks_msec() - _t0) / 1000.0])
	_rt = null
	await wait_frames(2)


# --- 01 Director --------------------------------------------------------------------------------------

## L1.1-L1.5, L4.11: three compressed waves on DIFF with the full default spawn groups. The crew holds
## the open street (WAVE_HOLD, Ferro Street; the cartel gunmen despawned); the bot (slot 0, sniper
## rifle) fights next to its AI crew, a lasing Longshot first.
## Checks: stage curve 50/75/100% drives each wave's SUSTAIN length, drama rises under fire, specials
## spawn in assaults AND between waves (CONTROL, wave >= 2), no unit spawns at a `breach_only` ENTRY
## point (L1.4, D-064 QC-42: building entries are breach targets, never spawns), alive specials never
## exceed DifficultyDef.special_limits (per limit key) nor alive police the enemy cap, the faction
## matches the difficulty, and the crew survives: the heist still runs, the human bot never reaches
## custody and at least one crew member is on its feet at every tick (AI teammates may be down / in
## custody).
func test_01_scripted_waves_escalation_and_caps() -> void:
	var tw: DirectorTweak = _wave_tweak()
	if not await _launch(DIFF, {"director_tweak": tw, "captain": false, "loadouts": {0: _sniper_loadout()}}):
		return
	var d: AssaultDirector = _director()
	var limits: Dictionary = _rt.difficulty_def.special_limits
	assert_false(limits.is_empty(), "DifficultyDef.special_limits set for difficulty %d" % DIFF)
	var crew_n: int = _rt.crew_members().size()
	var sustains: Dictionary = {}
	var spawned: Array[Array] = []
	var on_phase: Callable = func(p: int, w: int) -> void:
		if p == Enums.AssaultPhase.SUSTAIN:
			sustains[w] = d.phase_time_left
	var on_unit: Callable = func(npc: NpcBase, point: Node3D) -> void:
		var def: EnemyDef = npc.enemy_def
		var breach: bool = point != null and point.get(&"tags") is Array and (point.get(&"tags") as Array).has(&"breach_only")
		spawned.append([def.id if def != null else &"", int(d.assault_phase), d.wave_index,
			def != null and def.is_special, def.resource_path if def != null else "", point.name if breach else &""])
	d.phase_changed.connect(on_phase)
	d.unit_spawned.connect(on_unit)
	_conns.append([d.phase_changed, on_phase])
	_conns.append([d.unit_spawned, on_unit])
	# The crew holds the open street (WAVE_HOLD), facing along it.
	_despawn_cartel()
	var a: Vector3 = _near(WAVE_HOLD, WAVE_HOLD)
	var dirs: Array[Vector3] = _clear_dirs(a, ARENA_DIST_M)
	assert_false(dirs.is_empty(), "WAVE_HOLD %s is open along the street" % WAVE_HOLD)
	var fwd: Vector3 = dirs[0] if not dirs.is_empty() else Vector3.RIGHT
	_place(0, a, a + fwd)
	for s: int in [1, 2, 3]:
		_rt.teleport_crew(s, BotUtil.facing(_near(a - fwd * 1.5 + _side(fwd) * float(s - 2) * 1.5, a), a + fwd))
	await _go_loud()
	Engine.time_scale = WAVE_TIME_SCALE
	var stats: Dictionary = {"over": [], "peak": {}, "drama": 0.0, "cap_over": 0, "alive_max": 0, "min_standing": 4}
	var watch: Callable = func() -> bool:
		_combat_tick(0)
		for key: Variant in limits:
			var n: int = d.roster.special_alive(StringName(key))
			(stats["peak"] as Dictionary)[key] = maxi(int((stats["peak"] as Dictionary).get(key, 0)), n)
			if n > int(limits[key]):
				(stats["over"] as Array).append("%s: %d > %d" % [key, n, limits[key]])
		stats["alive_max"] = maxi(int(stats["alive_max"]), d.alive_count())
		stats["cap_over"] = int(stats["cap_over"]) + (1 if d.alive_count() > d.enemy_cap() else 0)
		stats["drama"] = maxf(float(stats["drama"]), d.drama)
		var standing: int = 0
		for c: CrewController in _rt.crew_members():
			standing += 1 if c.crew_state == Enums.CrewState.NORMAL else 0
		stats["min_standing"] = mini(int(stats["min_standing"]), standing)
		return d.wave_index >= 3 and d.assault_phase == Enums.AssaultPhase.SUSTAIN and d.phase_time >= 4.0
	var ok: bool = await wait_until(watch, 240.0)
	Engine.time_scale = 1.0
	_rt.set_bot_intent(0, _still(0))
	assert_true(ok, "director reached wave 3 SUSTAIN (wave %d, phase %d)" % [d.wave_index, d.assault_phase])
	# L1.3: stage curve and sustain length per wave.
	for w: int in [1, 2, 3]:
		assert_eq(d.stage_for_wave(w), w - 1, "wave %d stage" % w)
		assert_near(float(sustains.get(w, -1.0)), d.sustain_duration(w, crew_n), 0.1, "wave %d SUSTAIN length" % w)
	assert_true(float(sustains.get(3, 0.0)) > float(sustains.get(1, 0.0)), "later waves sustain longer")
	# L1.2 drama.
	assert_true(float(stats["drama"]) > 0.0, "drama rose under fire (max %.2f)" % stats["drama"])
	# L1.3 / L4.11 specials.
	var in_assault: int = 0
	var between: int = 0
	var faction_units: int = 0
	var at_breach: Array[StringName] = []
	for s: Array in spawned:
		if StringName(s[5]) != &"" and not at_breach.has(StringName(s[5])):
			at_breach.append(StringName(s[5]))
		if bool(s[3]):
			var p: int = int(s[1])
			in_assault += 1 if p == Enums.AssaultPhase.BUILD or p == Enums.AssaultPhase.SUSTAIN else 0
			between += 1 if p == Enums.AssaultPhase.CONTROL and int(s[2]) >= 2 else 0
			assert_true(limits.has(d.roster.special_limit_key(s[0])), "special %s has a DifficultyDef limit" % s[0])
		elif String(s[4]).contains("/frd/") or s[0] == &"enemy.frd_agent":
			faction_units += 1
	assert_true(in_assault > 0, "specials spawned during assaults (%d)" % in_assault)
	assert_true(between > 0, "specials spawned between waves (CONTROL, wave >= 2: %d)" % between)
	assert_eq(at_breach, [] as Array[StringName], "L1.4: no unit spawned at a breach_only ENTRY point (QC-42)")
	assert_eq(stats["over"], [], "alive specials within DifficultyDef.special_limits")
	assert_eq(int(stats["cap_over"]), 0, "alive police never above the enemy cap (%d)" % d.enemy_cap())
	# L1.5 faction.
	assert_eq(d.faction(), tw.faction_by_difficulty[DIFF], "faction by difficulty")
	assert_true(faction_units > 0, "FRD-faction units spawned (%d)" % faction_units)
	# Survival: the heist goes on, the human bot is not in custody and the crew was never wiped.
	assert_true(_of(&"heist_ended").is_empty(), "the heist is still running")
	assert_ne(_crew(0).crew_state, Enums.CrewState.CUSTODY, "the human bot is not in custody")
	assert_true(int(stats["min_standing"]) >= 1, "at least one crew member always on its feet")
	print("[P3] waves: %d units (%d specials in assaults, %d between waves), peak specials %s, max alive %d, " % [
		spawned.size(), in_assault, between, stats["peak"], stats["alive_max"]]
		+ "max drama %.2f, downs %d, custody %d, tased %d, kicked %d, kills %d, min standing %d, sustain %s" % [
		stats["drama"], _of(&"crew_downed").size(), _of(&"crew_custody").size(), _of(&"crew_tased").size(),
		_of(&"crew_cloaker_downed").size(), _kills(), stats["min_standing"], sustains])


# --- 02 Phantom ----------------------------------------------------------------------------------------

## L4.3 + L2.8: the Phantom telegraphs (hum, charge cue, glowing goggles), charges and kicks one of two
## crew members down (CLOAKER_DOWNED: no down counted, no bleedout). Counterplay: the teammate kills it
## with real fire, then frees the victim with the revive interaction (crew_revived).
func test_02_phantom_kick_and_teammate_rescue() -> void:
	if not await _launch(DIFF, _special_opts()):
		return
	await _loud_cleared()
	var a: Vector3 = _arena_point()
	var fwd: Vector3 = _arena_dirs[0]
	_place(0, a, a + fwd)
	_place(1, _near(a + _side(fwd) * 2.0, a), a + fwd)
	await wait_physics_frames(3)
	var units: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"phantom", _facing_xf(a + fwd * 8.0, a))
	assert_eq(units.size(), 1, "one Phantom")
	if units.is_empty():
		return
	var ph: NpcBase = units[0]
	var b: PhantomBrain = ph.get_node("Brain") as PhantomBrain
	Engine.time_scale = TIME_SCALE
	var winding: bool = await wait_until(func() -> bool: return b.mode == &"windup", 20.0)
	assert_true(winding, "Phantom winds up a charge (mode %s)" % b.mode)
	if not winding:
		return
	assert_true(b.goggles_glowing, "telegraph: goggles glow during the charge")
	assert_true(_has_cue(&"cue.phantom_hum"), "telegraph: cue.phantom_hum")
	assert_true(_has_cue(&"cue.phantom_charge"), "telegraph: cue.phantom_charge")
	var kicked: bool = await wait_until(func() -> bool: return _slot_in_state(Enums.CrewState.CLOAKER_DOWNED) >= 0, 5.0)
	assert_true(kicked, "the kick lands (result %s)" % b.last_kick_result)
	if not kicked:
		return
	var victim: CrewController = _crew(_slot_in_state(Enums.CrewState.CLOAKER_DOWNED))
	var rescuer: CrewController = _crew(1 - victim.slot)
	assert_eq(b.last_kick_result, &"hit", "kick result")
	assert_eq(victim.health.downs_used, 0, "L2.8: no down counted")
	assert_eq(victim.health.bleedout_left, 0.0, "L2.8: no bleedout")
	assert_true(_has(&"crew_cloaker_downed", victim.slot, ph.net_id), "crew_cloaker_downed(victim, phantom)")
	assert_eq(rescuer.crew_state, Enums.CrewState.NORMAL, "never kicks the last player standing")
	var dead: bool = await _shoot_until(rescuer.slot, ph, func() -> bool: return not ph.alive, 20.0)
	assert_true(dead, "the teammate kills the Phantom")
	var freed: bool = await _revive(rescuer.slot, victim, 15.0)
	assert_true(freed, "the teammate frees the victim (revive interaction)")
	assert_true(_has(&"crew_revived", victim.slot, rescuer.slot), "crew_revived(victim, rescuer)")
	assert_eq(victim.crew_state, Enums.CrewState.NORMAL, "victim back on its feet")
	assert_eq(victim.health.downs_used, 0, "still no down counted")


# --- 03 Stinger ----------------------------------------------------------------------------------------

## L4.4 + L2.8: a Stinger winds up (~1 s, cue) and tases the nearest crew member: crew_tased, no down,
## no movement, involuntary fire. Counterplay: the teammate kills the Stinger -> the tase breaks
## (crew_tase_ended, victim NORMAL), which is not a revive (D-049).
func test_03_stinger_tase_broken_by_kill() -> void:
	if not await _launch(DIFF, _special_opts({1: _sniper_loadout()})):
		return
	await _loud_cleared()
	var a: Vector3 = _arena_point()
	var fwd: Vector3 = _arena_dirs[0]
	_place(0, a, a + fwd)
	_place(1, _near(a - fwd * 3.0 + _side(fwd) * 2.0, a), a + fwd)
	await wait_physics_frames(3)
	var st: NpcBase = _rt.spawn_npc(&"police", _facing_xf(a + fwd * 10.0, a), {"enemy_def": SpecialSpawner.enemy_def(&"stinger")})
	assert_true(st != null and st.get_node_or_null("Brain") is StingerBrain, "Stinger spawned (director path)")
	if st == null:
		return
	var b: StingerBrain = st.get_node("Brain") as StingerBrain
	Engine.time_scale = TIME_SCALE
	var winding: bool = await wait_until(func() -> bool: return b.mode == &"windup", 10.0)
	assert_true(winding, "windup (mode %s)" % b.mode)
	assert_true(_has_cue(&"cue.stinger_windup"), "telegraph: cue.stinger_windup")
	var tased: bool = await wait_until(func() -> bool: return _slot_in_state(Enums.CrewState.TASED) >= 0, 3.0)
	assert_true(tased, "tased after the windup")
	if not tased:
		return
	var victim: CrewController = _crew(_slot_in_state(Enums.CrewState.TASED))
	var killer: CrewController = _crew(1 - victim.slot)
	assert_true(_has(&"crew_tased", victim.slot, st.net_id), "crew_tased(victim, stinger)")
	assert_eq(victim.health.downs_used, 0, "L2.8: no down counted")
	assert_true(victim.weapons.involuntary_fire, "involuntary fire while tased")
	var p0: Vector3 = victim.global_position
	var walk: CrewIntent = _still(victim.slot)
	walk.move = Vector2(0.0, 1.0)
	_rt.set_bot_intent(victim.slot, walk)
	await wait_seconds(0.6)
	_rt.set_bot_intent(victim.slot, _still(victim.slot))
	assert_true(victim.global_position.distance_to(p0) < 0.05, "the tased victim cannot move")
	var dead: bool = await _shoot_until(killer.slot, st, func() -> bool: return not st.alive, 6.0)
	assert_true(dead, "the teammate kills the Stinger")
	await wait_physics_frames(2)
	assert_eq(victim.crew_state, Enums.CrewState.NORMAL, "killing the Stinger frees the victim")
	assert_false(victim.weapons.involuntary_fire, "involuntary fire off")
	assert_eq(b.last_break_reason, &"killed", "break reason")
	assert_eq(_count(&"crew_tase_ended", victim.slot), 1, "crew_tase_ended(victim) once")
	assert_eq(_count(&"crew_revived", victim.slot), 0, "a broken tase is not a revive (D-049)")


# --- 04 Bulwark ----------------------------------------------------------------------------------------

## L4.5 + L3.4: the Bulwark fixates on the nearest crew member and faces it. Frontal non-piercing fire
## (pistol) is blocked (amount 0, blocked); a flank shot from the teammate hits for full damage; a
## shield-piercing sniper round passes at x0.25 and its weight staggers the Bulwark (guard down).
## The crew stands where no SHIELD_ANCHOR is in the Bulwark's reach (_standoff_point), so it holds its
## standoff band in the open instead of claiming a doorway anchor (BulwarkBrain._find_cover).
func test_04_bulwark_shield_pierce_flank_stagger() -> void:
	if not await _launch(DIFF, _special_opts({0: _sniper_loadout()})):
		return
	await _loud_cleared()
	_immune([0, 1])
	var a: Vector3 = _standoff_point()
	var fwd: Vector3 = _standoff_dirs[0]
	_place(0, a, a + fwd)
	_place(1, _near(a - fwd * 4.0, a), a + fwd)
	await _equip(0, Enums.WeaponSlot.SECONDARY)
	var units: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"bulwark", _facing_xf(a + fwd * 10.0, a))
	assert_eq(units.size(), 1, "one Bulwark")
	if units.is_empty():
		return
	var bw: NpcBase = units[0]
	var b: BulwarkBrain = bw.get_node("Brain") as BulwarkBrain
	await wait_physics_frames(3)
	var shield: BulwarkShield = b.shield
	assert_true(shield != null, "carries its shield")
	if shield == null:
		return
	Engine.time_scale = TIME_SCALE
	var set_up: bool = await wait_until(func() -> bool:
		return b.fixated == _crew(0) and bw.velocity.length() < 0.2 and _flat(bw.global_position - a) < 9.0, 15.0)
	Engine.time_scale = 1.0
	assert_true(set_up, "fixates on slot 0 and holds its standoff near %s (mode %s, %.1f m)" % [
		a, b.mode, _flat(bw.global_position - a)])
	print("[P3] bulwark standoff: crew at %s, Bulwark holds %.1f m out (mode %s)" % [a, _flat(bw.global_position - a), b.mode])
	# 1. Frontal pistol fire: blocked.
	var hp0: float = bw.health
	var n0: int = _hits_on(bw).size()
	assert_true(await _fire_once(0, func() -> Vector3: return CombatSystem.target_center(bw)), "slot 0 fires")
	await wait_physics_frames(2)
	var hits: Array[Dictionary] = _hits_on(bw)
	assert_eq(hits.size(), n0 + 1, "the frontal round is reported against the Bulwark")
	if hits.size() == n0 + 1:
		assert_true(bool(hits[n0]["blocked"]) and float(hits[n0]["amount"]) == 0.0, "frontal pistol round blocked")
	assert_true(shield.blocked_hits >= 1, "the shield took it")
	assert_near(bw.health, hp0, 0.001, "Bulwark unhurt from the front")
	# 2. Flank: the teammate steps to the Bulwark's side and fires the same pistol.
	var flank: Variant = _los_spot(bw, _side(-bw.look_forward()) * 5.0, 2.0)
	assert_true(flank != null, "a flank spot with line of sight")
	if flank != null:
		_place(1, flank as Vector3, bw.global_position)
		await wait_physics_frames(2)
		var dist: float = _crew(1).eye_position().distance_to(CombatSystem.target_center(bw))
		var want: float = _crew(1).weapons.damage_at(_crew(1).weapons.equipped_slot, dist)
		var n1: int = _hits_on(bw).size()
		assert_true(await _fire_once(1, func() -> Vector3: return CombatSystem.target_center(bw)), "slot 1 fires")
		await wait_physics_frames(2)
		hits = _hits_on(bw)
		assert_eq(hits.size(), n1 + 1, "the flank round hits the Bulwark")
		if hits.size() == n1 + 1:
			assert_false(bool(hits[n1]["blocked"]), "flank round not blocked")
			assert_near(float(hits[n1]["amount"]), want, want * 0.1, "full damage from the flank")
	# 3. Shield-piercing sniper round from the front: x0.25 through the shield + stagger.
	await _equip(0, Enums.WeaponSlot.PRIMARY)
	var d0: float = _crew(0).eye_position().distance_to(CombatSystem.target_center(bw))
	var full: float = _crew(0).weapons.damage_at(Enums.WeaponSlot.PRIMARY, d0)
	var n2: int = _hits_on(bw).size()
	var staggers0: int = b.staggers
	assert_true(await _fire_once(0, func() -> Vector3: return CombatSystem.target_center(bw)), "slot 0 fires the sniper")
	await wait_physics_frames(2)
	hits = _hits_on(bw)
	assert_true(hits.size() > n2, "the piercing round reaches the Bulwark")
	if hits.size() > n2:
		assert_true(bool(hits[n2].get("shield_pierced", false)), "shield_pierced")
		assert_near(float(hits[n2]["amount"]), full * float(bw.enemy_def.params.get("shield_pierce_mult", 0.25)),
			full * 0.05, "x0.25 through the shield")
	assert_eq(b.staggers, staggers0 + 1, "the heavy round staggers the Bulwark")
	assert_true(b.is_staggered() and shield.guard_down, "guard down while staggered")


# --- 05 Wrecker ----------------------------------------------------------------------------------------

## L4.6: sniper rounds at a Wrecker's head hit the Faceplate (150), then the Visor (160) - the plates
## absorb them (the Wrecker is unhurt), each break cracks (cue) - and only then the head, with the
## headshot multiplier.
func test_05_wrecker_plates_then_head() -> void:
	if not await _launch(DIFF, _special_opts({0: _sniper_loadout()})):
		return
	await _loud_cleared()
	_immune([0, 1])
	var a: Vector3 = _arena_point()
	var fwd: Vector3 = _arena_dirs[0]
	_place(0, a, a + fwd)
	_place(1, _near(a - fwd * 4.0, a), a + fwd)
	var units: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"wrecker_g", _facing_xf(a + fwd * 9.0, a))
	assert_eq(units.size(), 1, "one Wrecker")
	if units.is_empty():
		return
	var w: NpcBase = units[0]
	var armor: WreckerArmor = w.get_node("Weakpoints") as WreckerArmor
	assert_eq(armor.current_plate(), &"Faceplate", "faceplate first")
	await wait_physics_frames(3)
	var hp0: float = w.health
	var zones: Array[int] = []
	for k: int in range(3):
		var n0: int = _hits_on(w).size()
		assert_true(await _fire_once(0, func() -> Vector3: return w.head_position()), "shot %d fired" % (k + 1))
		await wait_physics_frames(2)
		var hits: Array[Dictionary] = _hits_on(w)
		zones.append(int(hits[n0]["zone"]) if hits.size() > n0 else -1)
		if k == 1:
			assert_near(w.health, hp0, 0.001, "plates absorb: the Wrecker is unhurt after two plate hits")
		if k == 2 and hits.size() > n0:
			var dist: float = _crew(0).eye_position().distance_to(w.head_position())
			var body: float = _crew(0).weapons.damage_at(Enums.WeaponSlot.PRIMARY, dist)
			assert_true(float(hits[n0]["amount"]) > body * 1.5, "headshot multiplier on the exposed head (%.0f vs %.0f)" % [
				hits[n0]["amount"], body])
	assert_eq(zones, [Enums.HitZone.WEAKPOINT, Enums.HitZone.WEAKPOINT, Enums.HitZone.HEAD] as Array[int],
		"faceplate, visor, then the head")
	assert_eq(armor.stage, 2, "both plates broken")
	assert_false(armor.is_head_armored(), "head exposed")
	assert_eq(_cue_count(&"cue.wrecker_plate_crack"), 2, "a crack cue per plate")
	assert_true(w.health < hp0, "the head shot hurt the Wrecker")


# --- 06 Longshot ---------------------------------------------------------------------------------------

## L4.7: the Longshot spawns only on a SNIPER_PERCH, lases its target (visible tracking laser) and fires
## only after the 1.2 s aim lock. Counterplay: breaking line of sight during the lock cancels the shot;
## back in view, the shot lands (cue.longshot_report) and bypasses armor gating; one sniper round kills it.
func test_06_longshot_perch_laser_cover_then_shot() -> void:
	if not await _launch(DIFF, _special_opts({0: _sniper_loadout()})):
		return
	await _loud_cleared()
	for s: int in [0, 1]:
		Modifiers.set_source(s, &"p3_gate.nododge", {&"defense.dodge_add": -1.0})
	var perches: Array[Node] = _rt.map.get_slots(G.SNIPER_PERCH)
	assert_true(not perches.is_empty(), "%s has SNIPER_PERCH points" % HEIST)
	if perches.is_empty():
		return
	var units: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"longshot")
	assert_eq(units.size(), 1, "one Longshot")
	if units.is_empty():
		return
	var ls: NpcBase = units[0]
	var b: LongshotBrain = ls.get_node("Brain") as LongshotBrain
	assert_true(b.is_perched() or b.perch != null or _on_perch(ls, perches), "spawned on a SNIPER_PERCH")
	var eye: Vector3 = ls.eye_position()
	var seen: Variant = _spot_seeing(eye, true, 34.0)
	var hidden: Variant = _spot_seeing(eye, false, 34.0, seen)
	assert_true(seen != null and hidden != null, "a spot in view of the perch and one in cover nearby")
	if seen == null or hidden == null:
		return
	_place(0, seen as Vector3, eye)
	_place(1, hidden as Vector3, eye)
	var lasing: bool = await wait_until(func() -> bool: return b.laser_active, 8.0)
	assert_true(lasing, "telegraph: the laser locks on")
	if not lasing:
		return
	assert_true((ls.get_node("LaserBeam") as Node3D).visible, "laser beam visible")
	assert_eq(b.shots_fired, 0, "no shot at laser-on")
	# Counterplay: step into cover during the aim lock.
	_place(0, _near((hidden as Vector3) + Vector3(0.8, 0.0, 0.0), hidden as Vector3), eye)
	await wait_seconds(b.tweak.longshot_aim_lock_s + 1.0)
	assert_eq(b.shots_fired, 0, "breaking line of sight during the lock cancels the shot")
	# Back in view: the laser returns and the shot lands after the full lock.
	var c: CrewController = _crew(0)
	var hp: float = c.health.health
	var armor: float = c.health.armor
	_place(0, seen as Vector3, eye)
	var relased: bool = await wait_until(func() -> bool: return b.laser_active, 4.0)
	assert_true(relased, "laser back on")
	var t_on: int = Time.get_ticks_msec()
	var shot: bool = await wait_until(func() -> bool: return b.shots_fired >= 1, 4.0)
	var lock_s: float = float(Time.get_ticks_msec() - t_on) / 1000.0
	assert_true(shot, "fires once the lock completes")
	if not shot:
		return
	await wait_physics_frames(1)
	assert_true(lock_s >= b.tweak.longshot_aim_lock_s - 0.15, "aim lock %.2f s" % lock_s)
	assert_true(_has_cue(&"cue.longshot_report"), "cue.longshot_report")
	var dmg: float = b.shot_damage(ls.global_position.distance_to(c.global_position))
	assert_true(dmg > armor, "the round exceeds the armor (%.0f > %.0f)" % [dmg, armor])
	assert_near(c.health.health, hp - (dmg - armor), 1.0, "no armor gating: overflow reaches health")
	var dead: bool = await _shoot_until(0, ls, func() -> bool: return not ls.alive, 8.0)
	assert_true(dead, "a sniper round kills the Longshot")


# --- 07 Corpsman ---------------------------------------------------------------------------------------

## L4.8: a lethal shot on a cop next to a Corpsman is turned into a revive (healed by the medic, chime +
## outline). Counterplay: kill the Corpsman; after its cooldown the same lethal shot now kills the cop.
func test_07_corpsman_revives_until_killed() -> void:
	if not await _launch(DIFF, _special_opts({0: _sniper_loadout()})):
		return
	await _loud_cleared()
	_immune([0, 1])
	var a: Vector3 = _arena_point()
	var fwd: Vector3 = _arena_dirs[0]
	_place(0, a, a + fwd)
	_place(1, _near(a - fwd * 4.0, a), a + fwd)
	var med: NpcBase = _rt.spawn_npc(&"police", _facing_xf(_near(a + fwd * 12.0, a), a),
		{"enemy_def": SpecialSpawner.enemy_def(&"corpsman")})
	var cop: NpcBase = _rt.spawn_npc(&"police", _facing_xf(_near(a + fwd * 12.0 + _side(fwd) * 2.0, a), a),
		{"enemy_def": _director().enemy_def_for(&"enemy.tac_light")})
	assert_true(med != null and cop != null, "Corpsman and a TAC unit spawned")
	if med == null or cop == null:
		return
	var mb: CorpsmanBrain = med.get_node("Brain") as CorpsmanBrain
	await wait_physics_frames(3)
	assert_true(med.global_position.distance_to(cop.global_position) <= mb.special_tweak.corpsman_radius_m, "within 7 m")
	assert_true(await _fire_once(0, func() -> Vector3: return CombatSystem.target_center(cop)), "lethal shot on the cop")
	await wait_physics_frames(2)
	assert_true(cop.alive, "the Corpsman revives the cop instead of letting it die")
	assert_eq(mb.revives, 1, "one revive")
	assert_true(_has_cue(&"cue.corpsman_heal"), "cue.corpsman_heal")
	assert_true(CorpsmanBrain.is_outlined(cop), "green outline on the healed unit")
	var killed: bool = await _shoot_until(0, med, func() -> bool: return not med.alive, 8.0)
	assert_true(killed, "the crew kills the Corpsman")
	await wait_seconds(mb.special_tweak.corpsman_cooldown_s + 0.5)
	var dead: bool = await _shoot_until(0, cop, func() -> bool: return not cop.alive, 8.0)
	assert_true(dead, "without its Corpsman the cop dies")
	assert_eq(mb.revives, 1, "no further revives")


# --- 08 Brandt -----------------------------------------------------------------------------------------

## L4.9: Commander Brandt arrives during an assault with his Aegis shields (cue), locks the assault (no
## FADE while present), stacks resistance for every enemy from 10% to 50% once in position (real fire
## on a TAC unit does half damage at 50%), takes at most 10% max HP per hit, cannot be killed and
## retreats at 20% HP (captain_retreated): resistance gone, the assault fades again.
func test_08_brandt_aegis_lock_resist_retreat() -> void:
	var tw: DirectorTweak = _quiet_tweak()
	tw.first_control_s = 1.0
	tw.anticipation_s = 1.0
	tw.build_s = 2.0
	tw.sustain_by_stage_s = PackedFloat32Array([1.0, 1.0, 1.0])
	tw.fade_wait_cap_s = 0.5
	tw.captain_min_wave = 1
	tw.captain_chance = 1.0
	tw.captain_delay_s = 0.5
	tw.captain_position_timeout_s = 2.0
	tw.aegis_resist_step_s = 0.5
	tw.captain_despawn_s = 0.0
	if not await _launch(DIFF, {"ai_teammates": 1, "crew_ai": false, "director_tweak": tw}):
		return
	await _loud_cleared()
	_immune([0, 1])
	var d: AssaultDirector = _director()
	var c: AegisCaptain = d.captain
	assert_true(c.eligible(), "Brandt eligible on difficulty %d" % DIFF)
	var arrived: bool = await wait_until(func() -> bool: return not _of(&"captain_arrived").is_empty(), 15.0)
	assert_true(arrived, "captain_arrived")
	if not arrived:
		return
	assert_true(d.is_assault_active(), "arrives during an assault (phase %d)" % d.assault_phase)
	assert_eq(c.alive_shields(), tw.aegis_shields, "%d Aegis shields" % tw.aegis_shields)
	assert_true(_has_cue(AegisCaptain.CUE_ARRIVAL), "cue.brandt_arrival")
	assert_true(d.captain_active(), "assault locked")
	var stacked: bool = await wait_until(func() -> bool: return d.aegis_resistance() >= tw.aegis_resist_max - 0.001, 12.0)
	assert_true(stacked, "resistance stacks to %.0f%% (now %.2f)" % [tw.aegis_resist_max * 100.0, d.aegis_resistance()])
	assert_true(_cue_count(AegisCaptain.CUE_PULSE) >= 5, "cue.aegis_pulse per step")
	assert_eq(d.assault_phase, Enums.AssaultPhase.SUSTAIN, "no FADE while Brandt is on the map")
	assert_true(d.phase_time_left <= 0.0, "the sustain timer is long over")
	# Resistance on real fire: a TAC unit in front of slot 0 takes (1 - 0.5) of the pistol's damage.
	var a: Vector3 = _arena_point()
	var fwd: Vector3 = _arena_dirs[0]
	_place(0, a, a + fwd)
	var cop: NpcBase = _rt.spawn_npc(&"police", _facing_xf(a + fwd * 6.0, a), {"enemy_def": d.enemy_def_for(&"enemy.tac_light")})
	await wait_physics_frames(2)
	var dist: float = _crew(0).eye_position().distance_to(CombatSystem.target_center(cop))
	var want: float = _crew(0).weapons.damage_at(_crew(0).weapons.equipped_slot, dist) * (1.0 - d.aegis_resistance())
	var n0: int = _hits_on(cop).size()
	assert_true(await _fire_once(0, func() -> Vector3: return CombatSystem.target_center(cop)), "slot 0 fires")
	await wait_physics_frames(2)
	var hits: Array[Dictionary] = _hits_on(cop)
	assert_eq(hits.size(), n0 + 1, "hit on the TAC unit")
	if hits.size() == n0 + 1:
		assert_near(float(hits[n0]["amount"]), want, want * 0.1, "50%% resistance on every enemy")
	# Per-hit cap, cannot be killed, retreat at 20% HP.
	var brandt: NpcBase = c.brandt
	var cap: float = tw.captain_hit_cap_frac * brandt.max_health
	var hits_taken: int = 0
	while c.active and hits_taken < 20:
		var r: Dictionary = CombatSystem.deliver_hit(brandt, Damage.info(100000.0, Enums.DamageType.BULLET,
			Enums.HitZone.BODY, &"test.p3_gate", brandt.global_position, Vector3.FORWARD), _crew(0).net_id)
		assert_true(float(r.get("amount", 0.0)) <= cap + 0.01, "per-hit cap %.0f (got %.0f)" % [cap, r.get("amount", 0.0)])
		hits_taken += 1
	assert_false(c.active, "Brandt retreats")
	assert_eq(c.retreat_reason, AegisCaptain.RETREAT_HP, "at 20%% HP (after %d capped hits)" % hits_taken)
	assert_true(brandt.health > 0.0, "he was never killed")
	assert_eq(_of(&"captain_retreated").size(), 1, "captain_retreated once")
	assert_near(d.aegis_resistance(), 0.0, 0.0001, "resistance gone")
	var faded: bool = await wait_until(func() -> bool: return d.assault_phase == Enums.AssaultPhase.FADE, 5.0)
	assert_true(faded, "the assault resumes and fades after the retreat")


# --- 09 Custody / trade --------------------------------------------------------------------------------

## L2.9 / L2.10 / L6.3 on a trade-only difficulty: the bot shouts down and cable-ties two civilians
## (hostages: the night shift). SEED rolls one worker (night_shift 1-3 is a variant), so a second is
## spawned next to it with HeistRuntime.spawn_npc and the first one's spawn info. An AI teammate goes
## into custody; after the negotiation the first hostage is highlighted and the human trades it by
## interaction (crew_traded). Then the human itself goes into custody: with no free human and a free AI,
## the trade happens automatically (solo with AI) and the human is back.
func test_09_custody_and_hostage_trades() -> void:
	if not await _launch(DIFF, {"director_tweak": _quiet_tweak(), "captain": false}):
		return
	_despawn_cartel()
	var civs: Array[Node] = _rt.npcs(&"civilian")
	assert_false(civs.is_empty(), "%s has a night shift" % HEIST)
	if not civs.is_empty():
		var w0: NpcBase = civs[0] as NpcBase
		for k: int in range(civs.size(), 2):
			var at: Vector3 = _near(w0.global_position + w0.global_basis.x * 1.5 * float(k), w0.global_position)
			_rt.spawn_npc(&"civilian", Transform3D(w0.global_basis, at), w0.spawn_info.duplicate())
	await wait_physics_frames(2)
	await _go_loud()
	Engine.time_scale = TIME_SCALE
	var cs: CustodySystem = CustodySystem.of(_rt)
	assert_true(cs != null, "custody service")
	civs = _rt.npcs(&"civilian")
	assert_true(civs.size() >= 2, "two civilians to take hostage (%d)" % civs.size())
	if cs == null or civs.size() < 2:
		return
	for k: int in range(2):
		if not await _take_hostage(civs[k] as NpcBase):
			return
	assert_eq(cs.hostage_candidates().size(), 2, "two hostages")
	# AI teammate -> custody -> traded by the human's interaction.
	var ai: CrewController = _crew(1)
	_custody_hit(ai)
	assert_eq(ai.crew_state, Enums.CrewState.CUSTODY, "AI teammate in custody (no downs left)")
	assert_true(cs.auto_release_left(1) < 0.0, "trade only on difficulty %d" % DIFF)
	var ready: bool = await wait_until(func() -> bool: return cs.highlighted_hostage() != null, cs.trade_time_for(1) + 2.0)
	assert_true(ready, "negotiation over: a hostage is highlighted")
	if not ready:
		return
	assert_eq(ai.crew_state, Enums.CrewState.CUSTODY, "a human is free: no automatic trade")
	var h: NpcBase = cs.highlighted_hostage()
	var hid: int = h.net_id
	if not await _go_next_to(0, h):
		return
	var traded: bool = await _hold_interact(0, hid, h.global_position,
		func() -> bool: return not _of(&"crew_traded").is_empty(), CustodyTweak.data().trade_interaction_s + 3.0)
	assert_true(traded, "the human trades the hostage")
	assert_true(_has(&"crew_traded", 1, hid), "crew_traded(1, hostage)")
	assert_eq(ai.crew_state, Enums.CrewState.NORMAL, "AI teammate back (L6.3)")
	assert_near(ai.health.health, ai.health.max_health, 0.001, "released at full health")
	# The human -> custody -> traded automatically (solo with AI, L2.9).
	var human: CrewController = _crew(0)
	_custody_hit(human)
	assert_eq(human.crew_state, Enums.CrewState.CUSTODY, "the human is in custody")
	var auto: bool = await wait_until(func() -> bool: return _count(&"crew_traded", 0) > 0, cs.trade_time_for(0) + 3.0)
	assert_true(auto, "AI-only crew: the trade happens automatically")
	assert_eq(human.crew_state, Enums.CrewState.NORMAL, "the human is back")
	assert_eq(human.health.downs_used, 0, "downs reset by the release")
	var near: float = INF
	for c: CrewController in _rt.crew_members():
		if c != human:
			near = minf(near, c.global_position.distance_to(human.global_position))
	assert_true(near < 4.0, "released next to the crew (%.1f m)" % near)
	assert_true(_of(&"heist_ended").is_empty(), "the heist goes on")


# --- 10 AI orders --------------------------------------------------------------------------------------

## L6.1 (A3-05) during an assault, in the open (the crew is moved to the arena): hold keeps an AI at its
## point while the human walks 12 m away, follow brings it back; with the other two AIs holding, a
## downed teammate beyond their hold_revive_radius_m is ignored until the human orders the revive.
func test_10_ai_orders_during_assault() -> void:
	var tw: DirectorTweak = _quiet_tweak()
	tw.first_control_s = 1.0
	tw.anticipation_s = 1.0
	tw.build_s = 200.0
	tw.assault_groups = (load(DIRECTOR_TWEAK) as DirectorTweak).assault_groups
	if not await _launch(DIFF, {"director_tweak": tw, "captain": false}):
		return
	_despawn_cartel()
	await _go_loud()
	_immune([0, 1, 3])
	var d: AssaultDirector = _director()
	var a: Vector3 = _arena_point()
	var fwd: Vector3 = _arena_dirs[0]
	var back: Vector3 = _arena_dirs[_arena_dirs.size() / 2]
	_place(0, a, a + fwd)
	for s: int in [1, 2, 3]:
		_rt.teleport_crew(s, BotUtil.facing(_near(a - fwd * 1.5 + _side(fwd) * float(s - 2) * 1.5, a), a + fwd))
	var assault: bool = await wait_until(func() -> bool: return d.is_assault_active(), 10.0)
	assert_true(assault, "assault under way (phase %d)" % d.assault_phase)
	Engine.time_scale = TIME_SCALE
	var ai: CrewController = _crew(1)
	var tw_ai: CrewAiTweak = CrewAiBrain.of(ai).tweak
	var hold_at: Vector3 = ai.global_position
	await _order(&"hold", ai.net_id)
	assert_eq(CrewAiBrain.of(ai).stance, &"hold", "slot 1 holds")
	assert_eq(CrewAiBrain.of(_crew(2)).stance, &"follow", "only the named AI received the order")
	assert_has(_lines(), &"vo.crew.ack_hold", "hold acknowledged")
	_place(0, _near(a + fwd * ARENA_DIST_M, a), a)
	await wait_seconds(4.0)
	assert_true(_flat(ai.global_position - hold_at) < 1.0, "holding AI stayed put (%.1f m)" % _flat(ai.global_position - hold_at))
	assert_true(_flat(_crew(2).global_position - _crew(0).global_position) <= tw_ai.follow_max_m + 0.5,
		"a non-holding AI followed the human")
	await _order(&"follow", ai.net_id)
	assert_has(_lines(), &"vo.crew.ack_follow", "follow acknowledged")
	var caught: bool = await wait_until(func() -> bool:
		return _flat(ai.global_position - _crew(0).global_position) <= tw_ai.follow_max_m + 0.5, 15.0)
	assert_true(caught, "follow: the AI caught up with the human")
	# Revive order: slots 1 and 3 hold next to the human; slot 2 goes down 12 m away, in the open.
	_place(0, a, a + fwd)
	await _order(&"hold", _crew(1).net_id, _near(a + _side(fwd) * 1.5, a))
	await _order(&"hold", _crew(3).net_id, _near(a - _side(fwd) * 1.5, a))
	var far: Vector3 = _near(a + back * ARENA_DIST_M, a)
	assert_true(_flat(far - a) > tw_ai.hold_revive_radius_m + 3.0, "downed spot beyond the hold revive radius")
	var downed: CrewController = _crew(2)
	_rt.teleport_crew(2, Transform3D(Basis.IDENTITY, far))
	await wait_physics_frames(3)
	_lethal_hit(downed)
	assert_eq(downed.crew_state, Enums.CrewState.DOWNED, "slot 2 downed")
	await wait_seconds(2.0)
	for s: int in [1, 3]:
		assert_true(CrewAiBrain.of(_crew(s)).revive_target != downed, "holding slot %d ignores the far downed AI" % s)
	assert_eq(_count(&"crew_revived", 2), 0, "nobody revived slot 2 unordered")
	await _order(&"revive", downed.net_id)
	assert_has(_lines(), &"vo.crew.ack_revive", "revive acknowledged")
	var revived: bool = await wait_until(func() -> bool: return _count(&"crew_revived", 2) > 0, downed.health.bleedout_left + 2.0)
	assert_true(revived, "the ordered AI revives slot 2 within the bleedout")
	if revived:
		var by: int = int(_of(&"crew_revived").filter(func(e: Array) -> bool: return int(e[1]) == 2)[0][2])
		assert_true(by == 1 or by == 3, "revived by an ordered holding AI (slot %d)" % by)
	assert_true(d.is_assault_active(), "orders worked during the assault (phase %d)" % d.assault_phase)


# --- Harness -------------------------------------------------------------------------------------------

func _launch(difficulty: Enums.Difficulty, options: Dictionary) -> bool:
	var opts: Dictionary = {"ai_teammates": 3, "skip_casing": true}
	opts.merge(options, true)
	_rt = await HeistLauncher.launch(HEIST, SEED, difficulty, self, opts)
	if _rt == null:
		fail("HeistLauncher.launch(%s, %d) returned null" % [HEIST, SEED])
		return false
	var crew: Node3D = _rt.crew_controller(0) as Node3D
	var nav_ok: bool = await wait_until(func() -> bool: return BotUtil.nav_ready(crew), 10.0)
	assert_true(nav_ok, "navigation map ready")
	await wait_physics_frames(2)
	_listen_all([&"heist_ended", &"crew_downed", &"crew_custody", &"crew_revived", &"crew_traded", &"crew_tased",
		&"crew_tase_ended", &"crew_cloaker_downed", &"captain_arrived", &"captain_retreated", &"damage_applied",
		&"audio_cue_requested", &"voice_line_requested", &"civilian_tied", &"npc_killed"])
	return nav_ok


## Two crew members (slot 1 bot-driven, the AI brain off), no director spawns, no Brandt.
func _special_opts(loadouts: Dictionary = {}) -> Dictionary:
	var o: Dictionary = {"ai_teammates": 1, "crew_ai": false, "director_tweak": _quiet_tweak(), "captain": false}
	if not loadouts.is_empty():
		o["loadouts"] = loadouts
	return o


## Heron .308 (sniper: armor + shield pierce) primary, Kestrel P9 secondary (ENV B weapons).
func _sniper_loadout() -> Loadout:
	var l: Loadout = Loadout.new()
	l.primary = &"weapon.heron_308"
	l.secondary = &"weapon.kestrel_p9"
	return l


func _quiet_tweak() -> DirectorTweak:
	var tw: DirectorTweak = (load(DIRECTOR_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 10000.0
	tw.first_responder_groups = 0
	tw.assault_groups = []
	tw.control_special_groups = []
	return tw


## Default spawn groups and caps, timings compressed (~1/6) so three waves run in about a minute.
func _wave_tweak() -> DirectorTweak:
	var tw: DirectorTweak = (load(DIRECTOR_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 4.0
	tw.control_between_waves_s = 6.0
	tw.anticipation_s = 2.0
	tw.build_s = 5.0
	tw.sustain_by_stage_s = PackedFloat32Array([5.0, 7.0, 9.0])
	tw.fade_wait_cap_s = 3.0
	tw.fade_s = 2.0
	tw.drama_fade_window_s = 3.0
	tw.first_responder_interval_s = 2.0
	tw.assault_group_interval_s = 1.5
	tw.control_group_interval_s = 3.0
	tw.control_special_interval_s = 1.5
	tw.control_special_chance = 1.0
	return tw


func _director() -> AssaultDirector:
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _go_loud() -> void:
	_rt.stealth.raise_alarm(&"p3_gate", 0)
	var loud: bool = await wait_until(func() -> bool: return _rt.phase == Enums.HeistPhase.LOUD, 3.0)
	assert_true(loud, "alarm -> LOUD")


## LOUD, then every map NPC despawned (QA-9): the special under test meets only the crew.
func _loud_cleared() -> void:
	await _go_loud()
	_rt.isolate_npc(null)
	await wait_physics_frames(2)


## The Co-op's cartel gunmen (GUARD spawns tagged `cartel`; role &"guard" while they are ordinary guards,
## QC-36; matched by role, spawn tag or an enemy.cartel* EnemyDef) leave the map: queue_free while still
## in the tree (isolate_npc's remove_child leaves the crew AI aiming at an out-of-tree node until the
## free: crew_ai_brain.gd _aim_point errors).
func _despawn_cartel() -> void:
	for n: Node in _rt.npcs():
		var npc: NpcBase = n as NpcBase
		var tags: Variant = npc.spawn_info.get("tags", [])
		if npc.role == &"guard" or npc.role == &"cartel" or (tags is Array and (tags as Array).has(&"cartel")) \
				or (npc.enemy_def != null and String(npc.enemy_def.id).begins_with("enemy.cartel")):
			npc.queue_free()


func _immune(slots: Array[int]) -> void:
	for s: int in slots:
		Modifiers.set_source(s, &"p3_gate.immune", {&"defense.damage_taken_mult": 0.0})


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
		_events.append([tag, a, b, c])
	sig.connect(cb)
	_conns.append([sig, cb])


func _listen_all(tags: Array[StringName]) -> void:
	for tag: StringName in tags:
		_listen(Signal(EventBus, tag), tag)


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _count(tag: StringName, a: Variant) -> int:
	var n: int = 0
	for e: Array in _of(tag):
		n += 1 if e[1] == a else 0
	return n


func _has(tag: StringName, a: Variant, b: Variant) -> bool:
	for e: Array in _of(tag):
		if e[1] == a and e[2] == b:
			return true
	return false


func _has_cue(id: StringName) -> bool:
	return _cue_count(id) > 0


func _cue_count(id: StringName) -> int:
	return _count(&"audio_cue_requested", id)


func _lines() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Array in _of(&"voice_line_requested"):
		if e[1] == &"crew_ai":
			out.append(StringName(e[2]))
	return out


## damage_applied infos reported against `npc` (blocked shield hits included, damage.md v1.1).
func _hits_on(npc: NpcBase) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Array in _of(&"damage_applied"):
		if int(e[1]) == npc.net_id:
			out.append(e[3] as Dictionary)
	return out


## Police killed by the crew (npc_killed with a crew member as the killer).
func _kills() -> int:
	var crew_ids: Array[int] = []
	for c: CrewController in _rt.crew_members():
		crew_ids.append(c.net_id)
	var n: int = 0
	for e: Array in _of(&"npc_killed"):
		n += 1 if crew_ids.has(int(e[2])) else 0
	return n


func _slot_in_state(state: Enums.CrewState) -> int:
	for c: CrewController in _rt.crew_members():
		if c.crew_state == state:
			return c.slot
	return -1


## Idle intent that keeps `slot`'s current view.
func _still(slot: int) -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = _crew(slot).look_yaw
	i.look_pitch = _crew(slot).look_pitch
	return i


## Teleport `slot` to `at` facing `look` and hold an idle intent looking there.
func _place(slot: int, at: Vector3, look: Vector3) -> void:
	_rt.teleport_crew(slot, BotUtil.facing(at, look))
	var c: CrewController = _crew(slot)
	_rt.set_bot_intent(slot, BotUtil.look_at_intent(at + Vector3.UP * (c.eye_position().y - c.global_position.y), look))


static func _facing_xf(at: Vector3, look: Vector3) -> Transform3D:
	return BotUtil.facing(at, look)


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


static func _side(fwd: Vector3) -> Vector3:
	return fwd.cross(Vector3.UP).normalized()


## Navmesh point near `want` (falls back to `fallback` when there is none within 1.5 m).
func _near(want: Vector3, fallback: Vector3) -> Vector3:
	for r: float in [0.5, 1.0, 1.5]:
		var p: Variant = BotUtil.nav_point_near(_crew(0), want, r)
		if p != null:
			return p as Vector3
	return fallback


## True when a ray between `a` and `b` meets neither architecture nor props.
func _clear(a: Vector3, b: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, b, 1 | 2)
	return _crew(0).get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Directions (12, every 30 deg) from `p` with clear knee- and eye-height lines and navmesh `dist` m out.
func _clear_dirs(p: Vector3, dist: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for deg: int in range(0, 360, 30):
		var d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(deg)))
		var far: Vector3 = p + d * dist
		if _clear(p + Vector3.UP * 1.5, far + Vector3.UP * 1.5) and _clear(p + Vector3.UP * 0.4, far + Vector3.UP * 0.4) \
				and BotUtil.nav_point_near(_crew(0), far, 0.5) != null \
				and BotUtil.nav_point_near(_crew(0), p + d * dist * 0.5, 0.5) != null:
			out.append(d)
	return out


## The most open navmesh point within 48 m of the crew spawn (its clear directions in _arena_dirs).
func _arena_point() -> Vector3:
	if _arena == Vector3.INF:
		var r: Array = _most_open(func(_p: Vector3) -> bool: return true)
		_arena = r[0]
		_arena_dirs.assign(r[1])
		assert_true(_arena_dirs.size() >= 4, "an open arena on %s (%d clear directions)" % [HEIST, _arena_dirs.size()])
		print("[P3] arena %s (%d clear directions)" % [_arena, _arena_dirs.size()])
	return _arena


## test_04: the most open navmesh point (as _arena_point) farther than the Bulwark's anchor reach
## (HeavySpecialTweak.bulwark_anchor_max_from_target_m, + 2 m) from every SHIELD_ANCHOR point; only
## directions whose opposite is clear too (Bulwark ahead, teammate behind). Directions in _standoff_dirs.
func _standoff_point() -> Vector3:
	if _standoff == Vector3.INF:
		var reach: float = HeavySpecialTweak.data().bulwark_anchor_max_from_target_m + 2.0
		var anchors: Array[Node] = _rt.map.get_slots(BulwarkBrain.ANCHOR_GROUP)
		var r: Array = _most_open(func(p: Vector3) -> bool:
			for n: Node in anchors:
				if _flat((n as Node3D).global_position - p) < reach:
					return false
			return true, true)
		_standoff = r[0]
		_standoff_dirs.assign(r[1])
		assert_false(_standoff_dirs.is_empty(), "a standoff spot on %s beyond %.0f m of every shield anchor" % [HEIST, reach])
		if _standoff_dirs.is_empty():
			_standoff_dirs.append(Vector3.FORWARD)
	return _standoff


## [point, clear directions] of the navmesh point within 48 m of the crew spawn (4 m grid) that passes
## `accept`, is in the crew's space (_crew_reachable) and has the most _clear_dirs (with `both_ways`,
## only those whose opposite is clear too).
func _most_open(accept: Callable, both_ways: bool = false) -> Array:
	var origin: Vector3 = (_rt.map.get_slots(G.PLAYER_SPAWN)[0] as Node3D).global_position
	var locked: Array[Door] = []
	for n: Node in get_tree().get_nodes_in_group(Door.GROUP):
		if n is Door and _rt.is_ancestor_of(n) and (n as Door).locked and not (n as Door).is_open:
			locked.append(n as Door)
	var best_p: Vector3 = origin
	var best: Array[Vector3] = []
	for x: int in range(-48, 49, 4):
		for z: int in range(-48, 49, 4):
			var p: Variant = BotUtil.nav_point_near(_crew(0), origin + Vector3(x, 0.0, z), 0.8)
			if p == null or not accept.call(p as Vector3):
				continue
			var dirs: Array[Vector3] = _clear_dirs(p as Vector3, ARENA_DIST_M)
			if both_ways:
				var kept: Array[Vector3] = []
				for d: Vector3 in dirs:
					if dirs.any(func(e: Vector3) -> bool: return e.dot(d) < -0.99):
						kept.append(d)
				dirs = kept
			if dirs.size() > best.size() and _crew_reachable(origin, p as Vector3, locked):
				best = dirs
				best_p = p as Vector3
	return [best_p, best]


## True when the navmesh path from `from` to `to` passes none of the `locked` doors. The navmesh runs
## through doorways, so a closure's barred police gate does not cut it: this keeps the search out of
## the police spawn pockets beyond the closures (dockside_burn.md Play-space closure).
func _crew_reachable(from: Vector3, to: Vector3, locked: Array[Door]) -> bool:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_crew(0).get_world_3d().navigation_map, from, to, true)
	if path.is_empty() or _flat(path[path.size() - 1] - to) > 0.5:
		return false
	for door: Door in locked:
		var at: Vector3 = door.global_position
		for k: int in range(1, path.size()):
			var q: Vector3 = Geometry3D.get_closest_point_to_segment(at, path[k - 1], path[k])
			if _flat(q - at) < door.effective_width() * 0.5 + 0.5 and absf(q.y - at.y) < 2.0:
				return false
	return true


## A navmesh point `offset` away from `npc` (+/- 60 deg, distance +- `slack`) with a clear line to it.
func _los_spot(npc: NpcBase, offset: Vector3, slack: float) -> Variant:
	var center: Vector3 = CombatSystem.target_center(npc)
	for deg: int in [0, 15, -15, 30, -30, 45, -45, 60, -60]:
		for k: float in [0.0, slack, -slack]:
			var off: Vector3 = offset.rotated(Vector3.UP, deg_to_rad(float(deg)))
			off = off.normalized() * maxf(off.length() + k, 1.5)
			var p: Variant = BotUtil.nav_point_near(_crew(0), npc.global_position + off, 0.5)
			if p != null and _clear((p as Vector3) + Vector3.UP * 1.6, center):
				return p
	return null


## A navmesh point within `radius` m of the arena that does (`visible`) or does not see `eye`; with
## `near_to`, the closest such point to it.
func _spot_seeing(eye: Vector3, visible: bool, radius: float, near_to: Variant = null) -> Variant:
	var origin: Vector3 = _arena_point() if near_to == null else near_to as Vector3
	var best: Variant = null
	var best_d: float = INF
	for r: float in [0.0, 2.0, 4.0, 6.0, 9.0, 12.0, 16.0, 20.0, 25.0, 30.0]:
		if r > radius:
			break
		for deg: int in range(0, 360, 20):
			var want: Vector3 = origin + Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(deg))) * r
			var p: Variant = BotUtil.nav_point_near(_crew(0), want, 0.6)
			if p == null or _clear((p as Vector3) + Vector3.UP * 1.0, eye) != visible:
				continue
			if visible and not _clear((p as Vector3) + Vector3.UP * 1.6, eye):
				continue
			var dd: float = (p as Vector3).distance_to(origin)
			if dd < best_d:
				best_d = dd
				best = p
		if best != null:
			return best
	return best


func _on_perch(npc: NpcBase, perches: Array[Node]) -> bool:
	for n: Node in perches:
		if (n as Node3D).global_position.distance_to(npc.global_position) < 1.6:
			return true
	return false


## Switch `slot` to weapon slot `ws` and wait for the draw.
func _equip(slot: int, ws: int) -> void:
	var i: CrewIntent = _still(slot)
	i.weapon_slot = ws
	_rt.set_bot_intent(slot, i)
	await wait_physics_frames(RISE_FRAMES)
	_rt.set_bot_intent(slot, _still(slot))
	await wait_seconds(_crew(slot).weapons.stats(ws).equip_time_s + 0.2)


## Pull the trigger of `slot` (aiming down sights), re-aimed at `aim.call()` every tick, until one round
## leaves the barrel (semi-auto / bolt: press and release; a dry trigger starts the reload).
func _fire_once(slot: int, aim: Callable, timeout_s: float = 6.0) -> bool:
	var c: CrewController = _crew(slot)
	var n0: int = c.weapons.shots_fired
	var t: float = 0.0
	while c.weapons.shots_fired == n0 and t < timeout_s:
		var i: CrewIntent = BotUtil.look_at_intent(c.eye_position(), aim.call())
		i.aim = true
		i.fire = true
		_rt.set_bot_intent(slot, i)
		await get_tree().physics_frame
		var r: CrewIntent = BotUtil.look_at_intent(c.eye_position(), aim.call())
		r.aim = true
		_rt.set_bot_intent(slot, r)
		await get_tree().physics_frame
		t += 2.0 * get_physics_process_delta_time()
	return c.weapons.shots_fired > n0


## Shoot at `npc` (its centre, else its head, whichever `slot` sees) until `done` or `timeout_s`. When it
## has moved out of sight, `slot` steps to a navmesh spot ~6 m from it with a clear line (the bot chases).
func _shoot_until(slot: int, npc: NpcBase, done: Callable, timeout_s: float) -> bool:
	var t0: float = _rt.heist_time_s
	while not done.call() and _rt.heist_time_s - t0 < timeout_s:
		if not is_instance_valid(npc) or not npc.is_inside_tree():
			break
		if _aim_point(slot, npc) == Vector3.INF:
			var away: Vector3 = _crew(slot).global_position - npc.global_position
			var spot: Variant = _los_spot(npc, Vector3(away.x, 0.0, away.z).normalized() * 6.0, 2.0)
			if spot != null:
				_place(slot, spot as Vector3, npc.global_position)
				await wait_physics_frames(2)
		await _fire_once(slot, func() -> Vector3:
			var p: Vector3 = _aim_point(slot, npc)
			return p if p != Vector3.INF else CombatSystem.target_center(npc), 3.0)
	_rt.set_bot_intent(slot, _still(slot))
	return done.call()


## The point of `npc` that `slot`'s eye sees: its centre, else its head, else Vector3.INF.
func _aim_point(slot: int, npc: NpcBase) -> Vector3:
	var eye: Vector3 = _crew(slot).eye_position()
	for p: Vector3 in [CombatSystem.target_center(npc), npc.head_position()]:
		if _clear(eye, p):
			return p
	return Vector3.INF


## L2.6: a crew member with no downs left goes straight to custody on zero health.
func _custody_hit(c: CrewController) -> void:
	c.health.downs_used = c.health.max_downs()
	_lethal_hit(c)


func _lethal_hit(c: CrewController) -> void:
	var hit: Dictionary = Damage.info(c.health.health + 1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY,
		&"test.p3_gate", c.global_position, Vector3.FORWARD)
	hit["pierced_armor"] = true
	c.take_hit(hit, 0)


## Teleport `slot` onto the navmesh next to `target` (within 1.2 m), facing it.
func _go_next_to(slot: int, target: Node3D) -> bool:
	for r: float in [0.8, 1.0, 1.2]:
		for deg: int in range(0, 360, 45):
			var want: Vector3 = target.global_position + Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(deg))) * r
			var p: Variant = BotUtil.nav_point_near(target, want, 0.3)
			if p != null and _clear((p as Vector3) + Vector3.UP * 1.0, target.global_position + Vector3.UP * 0.5):
				_place(slot, p as Vector3, target.global_position)
				await wait_physics_frames(2)
				return true
	fail("no navmesh point next to %s" % target.name)
	return false


## Hold interact on `target_net_id` until `done` or `timeout_s`, then release.
func _hold_interact(slot: int, target_net_id: int, look_to: Vector3, done: Callable, timeout_s: float) -> bool:
	var i: CrewIntent = BotUtil.look_at_intent(_crew(slot).eye_position(), look_to)
	i.interact = true
	i.interact_target_net_id = target_net_id
	_rt.set_bot_intent(slot, i)
	var ok: bool = await wait_until(done, timeout_s)
	_rt.set_bot_intent(slot, _still(slot))
	await wait_physics_frames(RISE_FRAMES)
	return ok


## `slot` walks up to `victim` (teleport) and holds the revive interaction (CrewTweak.revive_time_s).
func _revive(slot: int, victim: CrewController, timeout_s: float) -> bool:
	if not await _go_next_to(slot, victim):
		return false
	return await _hold_interact(slot, victim.net_id, victim.global_position,
		func() -> bool: return victim.crew_state == Enums.CrewState.NORMAL, timeout_s)


## S7.1 + S7.2: shout `civ` down from next to it, then cable-tie it (hostage). A fleeing civilian only
## drops with Tweak.stealth().fleeing_shout_chance per shout (D-016), so the bot keeps shouting (one
## shout per shout_cooldown_s), up to 10 tries.
func _take_hostage(civ: NpcBase) -> bool:
	var down: bool = false
	var tries: int = 0
	while not down and tries < 10:
		tries += 1
		if not await _go_next_to(0, civ):
			return false
		var sh: CrewIntent = BotUtil.look_at_intent(_crew(0).eye_position(), civ.global_position + Vector3.UP * 0.8)
		sh.shout = true
		_rt.set_bot_intent(0, sh)
		await wait_physics_frames(RISE_FRAMES)
		_rt.set_bot_intent(0, _still(0))
		down = await wait_until(func() -> bool: return civ.alert_state == Enums.AlertState.INTIMIDATED,
			Tweak.stealth().shout_cooldown_s + 0.2)
	assert_true(down, "%s intimidated by shouting (%d shouts, state %d)" % [civ.name, tries, civ.alert_state])
	if not down:
		return false
	var tied: bool = false
	for attempt: int in 4:  # LEAD (ENV A patch): a hit cancels the hold (S9.1); a civilian back up needs a re-shout
		if civ.alert_state != Enums.AlertState.INTIMIDATED and civ.alert_state != Enums.AlertState.TIED:
			var sh2: CrewIntent = BotUtil.look_at_intent(_crew(0).eye_position(), civ.global_position + Vector3.UP * 0.8)
			sh2.shout = true
			_rt.set_bot_intent(0, sh2)
			await wait_physics_frames(RISE_FRAMES)
			_rt.set_bot_intent(0, _still(0))
			await wait_until(func() -> bool: return civ.alert_state == Enums.AlertState.INTIMIDATED,
				Tweak.stealth().shout_cooldown_s + 0.2)
		tied = await _hold_interact(0, civ.net_id, civ.global_position,
			func() -> bool: return civ.alert_state == Enums.AlertState.TIED, Tweak.interaction().cable_tie_s + 2.0)
		if tied:
			break
	assert_true(tied, "%s cable-tied" % civ.name)
	return tied


## The human (slot 0) issues order `o` (crew_intent.md) for a few ticks, then stands still.
func _order(o: StringName, target: int = 0, position: Vector3 = Vector3.ZERO) -> void:
	var i: CrewIntent = _still(0)
	i.order = o
	i.order_target_net_id = target
	i.order_position = position
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(RISE_FRAMES)
	_rt.set_bot_intent(0, _still(0))
	await wait_physics_frames(2)


## Bot fire control for test_01: aim down sights at a lasing Longshot, else the nearest police unit in
## line of sight within 40 m, and fire (press / release every other tick; a dry trigger reloads).
func _combat_tick(slot: int) -> void:
	var c: CrewController = _crew(slot)
	if c == null or (c.crew_state != Enums.CrewState.NORMAL and c.crew_state != Enums.CrewState.DOWNED):
		return
	var eye: Vector3 = c.eye_position()
	var best: NpcBase = null
	var best_d: float = INF
	var best_at: Vector3 = Vector3.ZERO
	for n: NpcBase in _director().alive_units():
		# Like a player: a lasing Longshot first (L4.7 counterplay), else the nearest unit within 40 m.
		var lasing: bool = n.get_node_or_null("Brain") is LongshotBrain and (n.get_node("Brain") as LongshotBrain).laser_active
		for at: Vector3 in [CombatSystem.target_center(n), n.head_position()]:
			var dd: float = eye.distance_to(at) - (1000.0 if lasing else 0.0)
			if dd < best_d and (lasing or dd < 40.0) and CombatSystem.has_los(c, eye, at, [c, n]):
				best = n
				best_d = dd
				best_at = at
				break
	if best == null:
		_rt.set_bot_intent(slot, _still(slot))
		return
	var i: CrewIntent = BotUtil.look_at_intent(eye, best_at)
	i.aim = true
	i.fire = Engine.get_physics_frames() % 2 == 0
	_rt.set_bot_intent(slot, i)
