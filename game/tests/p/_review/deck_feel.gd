# gdlint:disable=max-returns
## LEAD gap job (2026-10-23): windowed feel pass of the new perk decks in a LIVE LOUD heist (Glasshouse, Routine, real
## input, 3 AI bots on). Built on rt_g1_pass.gd (Po5Pilot combat: _hold_cover peeks and engages, reloads in lulls).
## One mode per deck (--test=, or all):
##   hacker    perk.hacker 9/9, G pocket ECM with >= 2 enemies within 12 m: feedback mode, the stun count, kill heals.
##   lifeline  perk.lifeline 9/9, fight to < 60% health, G the ampule: the heal, the segments, kills restoring them.
##   veil      perk.veil 9/9, G the smoke bomb at the feet, hold in the cloud: damage per second before vs inside.
##   buddy     perk.buddy_system 9/9, G tags the nearest bot, fight: heals on paired kills, Synergy absorb.
##   copycat   perk.understudy 9/9 (picks armor / dodge / dodge / crouch, mimic Ironclad): headshot heals, the
##             tactical reload, grace.
## Each: the alarm by a burst (real input), the deck's moment with ONE shot (HUD + FP pose), FIGHT_S of fighting, rows
## with numbers and a PD2 judgement line. Stated shortcuts: direct HeistLauncher.launch (seed, Routine), the
## hazard kit (corsair_ar + kestrel + heavy vest + doctor bag), the alarm by gunfire.
##     --out=/abs/dir [--seed=N] [--open (advance on the nearest enemy)] [--diff=hazardous]
## Output: "[DKF ...]" notes and "[DKF] ROW <deck> | <item> | PASS|FAIL|NOTE | <detail> | <owner>"; "[DKF] RESULT".
## Owner: ENV P.
extends "res://tests/p/_review/rt_g1_pass.gd"

const GH_HEIST: StringName = &"glasshouse"
const DECK_SEED: int = 7101
const FIGHT_S: float = 60.0
const NEAR_M: float = 12.0
const LOW_HEALTH: float = 0.6
const DECKS: Dictionary = {&"hacker": &"perk.hacker", &"lifeline": &"perk.lifeline", &"veil": &"perk.veil",
	&"buddy": &"perk.buddy_system", &"copycat": &"perk.understudy"}
const COPYCAT_CHOICES: Dictionary = {0: 1, 2: 2, 4: 2, 6: 3}

## --open: the pilot advances on the nearest enemy instead of fighting from where it stands.
const OPEN_STOP_M: float = 7.0

var _kills: int = 0
var _open: bool = OS.get_cmdline_user_args().has("--open")
var _open_moves: int = 0
var _heal_events: Array[String] = []


func note(msg: String) -> void:
	print("[DKF %.1fs t=%.1f] %s" % [(Time.get_ticks_msec() - _t0_ms) / 1000.0,
		rt.heist_time_s if rt != null and is_instance_valid(rt) else -1.0, msg])


func _run() -> void:
	_t0_ms = Time.get_ticks_msec()
	if runner_out.ends_with("/of_g1_pass"):
		runner_out = OS.get_user_data_dir() + "/deck_feel"
		DirAccess.make_dir_recursive_absolute(runner_out)
	var tests: Array[String] = []
	if _test == "all":
		tests.assign(["hacker", "lifeline", "veil", "buddy", "copycat"])
	else:
		tests.append(_test)
	var ok: bool = true
	for t: String in tests:
		_cur = t
		var m: String = "_dk_" + t
		if not has_method(m):
			print("[DKF] RESULT FAIL %s (unknown test)" % t)
			ok = false
			continue
		note("=== %s ===" % t)
		var passed: bool = bool(await Callable(self, m).call())
		print("[DKF] RESULT %s %s" % ["PASS" if passed else "FAIL", t])
		_results.append("%s %s" % [t, "PASS" if passed else "FAIL"])
		ok = ok and passed
	_write_rows()
	Engine.time_scale = 1.0
	RenderingServer.render_loop_enabled = true
	print("[DKF] RESULT %s (%s)" % ["PASS" if ok else "FAIL", ", ".join(_results)])
	get_tree().quit(0 if ok else 1)
	await get_tree().create_timer(10.0, true, false, true).timeout
	OS.kill(OS.get_process_id())  # finished runs can hang in shutdown under llvmpipe


func _row(item: String, verdict: String, detail: String, owner: String = "-") -> void:
	var line: String = "%s | %s | %s | %s | %s" % [_cur, item, verdict, detail, owner]
	_rows.append(line)
	print("[DKF] ROW " + line)


## The hazard kit with `deck` 9/9 (Copycat: the picks + the Ironclad mimic).
func _deck_loadout(deck: StringName) -> Loadout:
	var lo: Loadout = Loadout.new()
	lo.primary = HAZ_PRIMARY
	lo.secondary = CombatTweak.data().default_secondary
	lo.armor = HAZ_ARMOR
	lo.deployable = HAZ_DEPLOYABLE
	lo.perk_deck = deck
	lo.perk_deck_cards = 9
	if deck == &"perk.understudy":
		lo.perk_choices = COPYCAT_CHOICES.duplicate()
		lo.perk_mimic_deck = &"perk.ironclad"
	return CrewWeapons.build_loadout(lo)


## --diff=hazardous etc. (default Routine): Routine armor regen out-heals the incoming fire, so the defensive decks
## need a harder difficulty to be exercised.
func _dk_diff() -> Enums.Difficulty:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--diff="):
			return Enums.Difficulty.get(a.trim_prefix("--diff=").to_upper(), Enums.Difficulty.ROUTINE) as Enums.Difficulty
	return Enums.Difficulty.ROUTINE


## Glasshouse with the deck, 3 AI bots ON, masked, then the alarm by a burst (real input). True once loud.
func _deck_launch(deck: StringName) -> bool:
	if rt != null and is_instance_valid(rt):
		rt.teardown()
		rt = null
		await wait_s(0.5)
	_kills = 0
	_heal_events.clear()
	if Net.crew.is_empty():
		Net.start_solo("Player", 3)  # before keying the loadout: Net.local_slot() is -1 with no crew (offline is already authority)
	rt = await HeistLauncher.launch(GH_HEIST, _seed if _seed >= 0 else DECK_SEED, _dk_diff(), self,
		{"skip_casing": true, "ai_teammates": 3, "crew_ai": true, "loadouts": {Net.local_slot(): _deck_loadout(deck)}})
	if rt == null:
		return await _fail("launch")
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await wait_s(2.0)
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.shout_blockers = false
	await pilot.calibrate()
	pilot.combat = true
	if not EventBus.npc_killed.is_connected(_on_kill):
		EventBus.npc_killed.connect(_on_kill)
	_hits.clear()
	_crew_ids.clear()
	for s: int in 4:
		var cc: Node = rt.crew_controller(s)
		if cc != null:
			_crew_ids[NetIds.of(cc)] = s
	if not EventBus.damage_applied.is_connected(_on_blown_hit):
		EventBus.damage_applied.connect(_on_blown_hit)
	note("launched %s (%s) deck %s, spawn %s" % [GH_HEIST, Enums.Difficulty.keys()[_dk_diff()], deck,
		Po5Pilot._v(c.global_position)])
	var eff: Loadout = rt.crew_loadouts.get(c.slot) as Loadout
	note("deck check: local_slot %d, crew.slot %d, effective deck %s, perks %s, perk.throwable %s" % [Net.local_slot(),
		c.slot, eff.perk_deck if eff != null else &"-", PerkHooks.of(c).components.keys(),
		Modifiers.params(c.slot, &"perk.throwable")])
	if not await _mask():
		return await _fail("mask")
	if _fast:
		_set_fast(true)
	pilot.inp.press(&"fire")
	await wait_until(func() -> bool: return rt.went_loud, 8.0)
	pilot.inp.release(&"fire")
	_row("loud by a burst", "PASS" if rt.went_loud else "FAIL", "loud %s" % rt.went_loud, "-" if rt.went_loud else "A alarm")
	return rt.went_loud


func _on_kill(_victim_id: int, killer_id: int, _info: Dictionary) -> void:
	if pilot != null and killer_id == pilot.crew.net_id:
		_kills += 1


func _health() -> float:
	return pilot.crew.health.health if pilot.crew.health != null else 0.0


func _max_health() -> float:
	return maxf(pilot.crew.health.max_health, 1.0) if pilot.crew.health != null else 1.0


## Fight from where the crew stands until `done` or `max_s`; logs every heal (a health rise not from a revive).
func _fight(max_s: float, done: Callable = Callable()) -> void:
	var t_end: float = rt.heist_time_s + max_s
	var t_start: float = rt.heist_time_s
	var last: float = _health()
	while rt.heist_time_s < t_end and not _in_custody() and not (done.is_valid() and bool(done.call())):
		await _hold_cover(func() -> bool: return true, 1.0)
		var foe: NpcBase = pilot.nearest_enemy(BLOWN_PEEK_M)
		if _open and pilot.crew.crew_state == Enums.CrewState.NORMAL:
			# --open (LEAD): fight in the open, no holding at the spawn behind the bots: close to OPEN_STOP_M of the
			# nearest enemy (seen or not) before every engagement.
			var near: NpcBase = pilot.nearest_enemy(60.0)
			if near != null and near.global_position.distance_to(pilot.crew.global_position) > OPEN_STOP_M + 0.5:
				await pilot.goto(near.global_position, OPEN_STOP_M, 4.0)
				_open_moves += 1
			foe = pilot.nearest_enemy(BLOWN_PEEK_M)
		if foe != null and pilot.crew.crew_state == Enums.CrewState.NORMAL:
			await pilot.engage(foe, 1.5)
		else:
			await wait_s(0.5)
		var h: float = _health()
		if h > last + 0.5 and pilot.crew.crew_state == Enums.CrewState.NORMAL:
			_heal_events.append("+%.0f at t=%.0f (kills %d)" % [h - last, rt.heist_time_s, _kills])
		last = h
	note("fight %.0f s (t=%.0f..%.0f), custody %s, kills %d, health %.0f/%.0f armor %.0f, at %s%s" % [
		rt.heist_time_s - t_start, t_start, rt.heist_time_s, _in_custody(), _kills, _health(), _max_health(),
		pilot.crew.health.armor if pilot.crew.health != null else 0.0, Po5Pilot._v(pilot.crew.global_position),
		", open moves %d" % _open_moves if _open else ""])


## Enemies (alive) within `r` of the crew.
func _enemies_within(r: float) -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	for n: Node in rt.npcs():
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.is_in_group(G.ENEMY) and npc.global_position.distance_to(pilot.crew.global_position) <= r:
			out.append(npc)
	return out


func _items_state() -> Dictionary:
	var pi: PerkItems = rt.service(PerkItems.SERVICE) as PerkItems
	return pi.state(pilot.crew.slot) if pi != null else {}


func _use_deck_item() -> void:
	var c: CrewController = pilot.crew
	var used: Array[StringName] = []
	var on_used: Callable = func(id: StringName, _k: StringName) -> void: used.append(id)
	c.throwables.deck_item_used.connect(on_used)
	var perks: CrewPerks = PerkHooks.of(c)
	var pt: PerkThrowable = perks.component(PerkThrowable.KEY) as PerkThrowable if perks != null else null
	note("G: masked %s, state %d, bag %s, perks %s, item %s" % [c.masked, c.crew_state, c.is_carrying_bag(),
		perks.components.keys() if perks != null else [], pt.item_id() if pt != null else &"-"])
	var edges: int = 0
	pilot.inp.press(&"throw_item")
	for _k: int in 3:
		await get_tree().physics_frame
		edges += 1 if c.intent != null and c.intent.throw_item else 0
	pilot.inp.release(&"throw_item")
	await wait_s(0.4)  # the FP use pose is up (FpViewmodelDeck)
	note("G: intent.throw_item on %d of 3 ticks, deck_item_used %s" % [edges, used])
	if used.is_empty():
		_row("G uses the deck item (real input)", "FAIL", "intent edges %d, no deck_item_used; direct PerkHooks.use_throwable %s"
			% [edges, PerkHooks.use_throwable(c)], "P input / A perk.throwable")
		await wait_s(0.4)
	c.throwables.deck_item_used.disconnect(on_used)


# --- decks ----------------------------------------------------------------------------------------------------------

func _dk_hacker() -> bool:
	if not await _deck_launch(DECKS[&"hacker"]):
		return false
	await _fight(120.0, func() -> bool: return _enemies_within(NEAR_M).size() >= 2)
	var near: Array[NpcBase] = _enemies_within(NEAR_M)
	await _use_deck_item()
	await shot("hacker_feedback")
	var ecm: Node = rt.service(&"ecm")
	var e: Dictionary = ((ecm.get(&"pocket") as Dictionary).get(pilot.crew.slot, {}) as Dictionary).duplicate() \
		if ecm != null else {}  # a copy: EcmSystem resets the live entry's mode when the feedback ends
	await wait_s(1.5)
	var stunned: int = 0
	for npc: NpcBase in near:
		if is_instance_valid(npc) and npc.is_stunned():
			stunned += 1
	_row("pocket ECM: feedback in loud", "PASS" if String(e.get("mode", "")) != "" else "FAIL",
		"mode %s, active %.1f s, charges %s, %d of %d near enemies stunned 1.5 s after G" % [e.get("mode", "-"),
		float(e.get("active_left", 0.0)), e.get("charges", "-"), stunned, near.size()], "A EcmSystem")
	await _fight(FIGHT_S)
	_row("kills / heals (Bit Decay, Botnet)", "NOTE", "%d kills, heals: %s" % [_kills, ", ".join(_heal_events)])
	_danger_rows("hacker")
	return String(e.get("mode", "")) != ""


func _dk_lifeline() -> bool:
	if not await _deck_launch(DECKS[&"lifeline"]):
		return false
	await _fight(240.0, func() -> bool: return _health() < _max_health() * LOW_HEALTH)
	var before: float = _health()
	await _use_deck_item()
	await wait_s(0.3)
	var after: float = _health()
	var leech: PerkLeech = PerkHooks.of(pilot.crew).component(PerkLeech.KEY) as PerkLeech
	await shot("lifeline_ampule")
	var seg: String = "%d/%d" % [leech.segments_left(), leech.segment_total()] if leech != null else "-"
	var unhurt: bool = before >= _max_health() - 0.5  # never below LOW_HEALTH in the fight: nothing to heal
	var good: bool = leech != null and leech.is_active() and (after > before or unhurt)
	var detail: String = "health %.0f -> %.0f of %.0f, window %.1f s, segments %s, HUD %s" % [before, after, _max_health(),
		leech.active_left if leech != null else 0.0, seg, _items_state().keys()]
	if unhurt:
		detail += " (the crew was never hurt: no heal to measure)"
	_row("ampule: activate heal + segments", ("NOTE" if unhurt else "PASS") if good else "FAIL", detail,
		"-" if good else "A PerkLeech")
	var s0: int = leech.segments_left() if leech != null else 0
	await _fight(minf(FIGHT_S, leech.active_left if leech != null else 0.0))
	_row("segments over the window", "NOTE", "segments %d -> %d, kills %d, heals %s" % [s0,
		leech.segments_left() if leech != null else 0, _kills, ", ".join(_heal_events)])
	_danger_rows("lifeline")
	return good


func _dk_veil() -> bool:
	if not await _deck_launch(DECKS[&"veil"]):
		return false
	await _fight(120.0, func() -> bool: return _enemies_within(25.0).size() >= 2)
	var h0: float = _health() + pilot.crew.health.armor
	var t0: float = rt.heist_time_s
	await _fight(15.0)
	var out_dps: float = maxf(h0 - (_health() + pilot.crew.health.armor), 0.0) / maxf(rt.heist_time_s - t0, 0.1)
	await pilot.face(pilot.crew.global_position + pilot.crew.global_transform.basis.z * -1.5 + Vector3.DOWN * 1.2, 0.05, 1.5)
	await _use_deck_item()
	await wait_s(1.5)
	var in_cloud: bool = SmokeZones.in_smoke(pilot.crew)
	await shot("veil_in_cloud")
	var h1: float = _health() + pilot.crew.health.armor
	var t1: float = rt.heist_time_s
	await _fight(8.0)
	var in_dps: float = maxf(h1 - (_health() + pilot.crew.health.armor), 0.0) / maxf(rt.heist_time_s - t1, 0.1)
	_row("smoke at the feet: in the cloud", "PASS" if in_cloud else "FAIL", "in smoke %s, damage/s before %.1f, inside %.1f" % [
		in_cloud, out_dps, in_dps], "A PerkSicario / SmokeZones")
	_danger_rows("veil")
	return in_cloud


func _dk_buddy() -> bool:
	if not await _deck_launch(DECKS[&"buddy"]):
		return false
	var mate: CrewController = null
	for s: int in range(1, 4):
		var m: CrewController = rt.crew_controller(s) as CrewController
		if m != null and (mate == null or m.global_position.distance_to(pilot.crew.global_position)
				< mate.global_position.distance_to(pilot.crew.global_position)):
			mate = m
	if mate == null:
		_row("tag a bot", "FAIL", "no bot", "A bots")
		return false
	pilot.combat = false
	await pilot.face(mate.global_position + Vector3.UP * 1.2, 0.02, 2.0)
	await _use_deck_item()
	pilot.combat = true
	var tp: TagPairs = TagPairs.of(rt)
	var tagged: int = tp.tagged_of(pilot.crew.slot) if tp != null else -1
	await shot("buddy_tagged")
	_row("G tags the aimed bot", "PASS" if tagged == mate.slot else "FAIL", "tagged slot %d (aimed %d, %.0f m)" % [tagged,
		mate.slot, mate.global_position.distance_to(pilot.crew.global_position)], "A TagPairs")
	await _fight(FIGHT_S)
	var tt: PerkTagTeam = PerkHooks.of(pilot.crew).component(PerkTagTeam.KEY) as PerkTagTeam
	_row("paired kills: heals + Synergy absorb", "NOTE", "kills %d, heals %s, absorb %s" % [_kills,
		", ".join(_heal_events), tt.get(&"absorb") if tt != null else "-"])
	_danger_rows("buddy")
	return tagged == mate.slot


func _dk_copycat() -> bool:
	if not await _deck_launch(DECKS[&"copycat"]):
		return false
	await _fight(30.0)
	await shot("copycat_fight")
	await _fight(FIGHT_S)
	var cc: PerkCopycat = PerkHooks.of(pilot.crew).component(PerkCopycat.KEY) as PerkCopycat
	_row("Copycat live in a fight", "PASS" if cc != null else "FAIL", "kills %d, heals %s, reload kills %s, grace cd %.1f" % [
		_kills, ", ".join(_heal_events), cc.reload_kills if cc != null else {}, cc.grace_cd if cc != null else 0.0],
		"A PerkCopycat")
	_danger_rows("copycat")
	return cc != null
