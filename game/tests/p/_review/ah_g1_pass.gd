# gdlint:disable=max-returns
## AH-P1 (D-165): Afterhours (the Velvet) real-input pass, ready for ENV C's greybox. Built on rt_g1_pass.gd / of_g1_pass.gd
## (Po5Pilot + PlayerInputDriver: mouse look, WASD, F holds, G throws; no teleports, no intent injection). Route plan:
## docs/design/heists/afterhours.md (Modes, Floor plans, Stealth routes, Loud, Escape; D-075 rulings). One mode per
## --test=:
##   casing   the civilian start (D-065 start_mode civilian, NPCs in, real detection): the crew spawns civilian in G1;
##            walks the whole front of house (foyer, hall, dance floor, stage front, east bar, main bar, under-circle,
##            the G3b WC, the west fire exit -> the smokers' passage -> Marlin Ave -> back in the main doors, the grand
##            stair -> the VIP rope gate -> U2 -> U1 balcony and back); every observer's peak fill stays 0 and the mode
##            stays civilian. The D-075 civilian-allowed set: every guest door on the way opens; each staff door (east
##            bar service door, backstage, the box-office flap, the VIP staff door) answers ui.blocked.civilian.
##   stealth  Stealth route 1 (east bar service door): the nearest gear_drop -> casing; behind the east bar into G20; a
##            keycard (nearest KeycardPickup) and the safe's code note (CodeNote of the safe's code_group) as casing;
##            mask in G23 when unseen; the staff stair -> U6 -> the office keycard door -> the safe keypad -> 3 cash bags
##            out to the active van's secure zone; into the escape. No alarm allowed (a row per step, peaks table).
##   loud     The loud line: gear + keycard as casing, mask, a burst in the hall (the alarm: music cut, stampede),
##            the office by keycard, the safe drilled (jams fixed), the van's return (2nd FADE or 300 s), 3 bags
##            carried down the staff stair to it, into the escape. --build=loud for the PD2 loud kit (RT's).
##     --out=/abs/dir [--seed=N] [--npcs]
## Positions are the design doc's grid (origin the Velvet's NW corner, +x east, +z south, FFL 0.0 / 4.2): if C's
## greybox moves a room, the rows name the waypoint that missed. Props are found by type at runtime (GearPickup,
## KeycardPickup, CodeNote, KeycardReader, Safe, EscapeZone, SecureZone), never by coordinates alone.
## Output: "[AHP ...]" notes; "[AHP] ROW <test> | <item> | <PASS|STUCK|FAIL|NOTE> | <detail> | <owner>"; "[AHP] RESULT".
## Owner: ENV P.
extends "res://tests/p/_review/rt_g1_pass.gd"

const AH_HEIST: StringName = &"afterhours"
const AH_SEED: int = 6501
const UP: float = 4.2
## Front of house, civilian walk (D-075: civilians stay front-of-house), in order.
const FOH_WALK: Array = [
	["foyer (G1)", Vector3(18.0, 0.0, 25.0)], ["hall doors -> under-circle (G7)", Vector3(19.5, 0.0, 19.0)],
	["dance floor (G6)", Vector3(13.0, 0.0, 13.0)], ["stage front", Vector3(13.0, 0.0, 11.5)],
	["east bar (guest side)", Vector3(22.0, 0.0, 11.0)], ["main bar (guest side)", Vector3(4.5, 0.0, 14.0)],
	["G7 booths (east)", Vector3(23.0, 0.0, 19.5)], ["patrons' WC G3b", Vector3(4.5, 0.0, 24.0)],
	["west fire exit (0, 19) -> smokers' passage", Vector3(-2.0, 0.0, 19.0)],
	["smokers' passage -> Marlin Ave", Vector3(-2.0, 0.0, 29.5)], ["Marlin Ave sidewalk", Vector3(10.0, 0.0, 30.0)],
	["main doors -> foyer", Vector3(15.5, 0.0, 25.5)], ["grand stair foot (G8)", Vector3(10.5, 0.0, 26.5)],
	["grand stair top (U8)", Vector3(8.0, UP, 26.0)], ["VIP rope gate -> U2", Vector3(15.0, UP, 24.0)],
	["U1 balcony (rail)", Vector3(13.0, UP, 16.5)], ["back down to the foyer", Vector3(18.0, 0.0, 25.0)],
]
## Staff doors (D-075: never civilian_allowed): the door's grid point and the guest-side stand.
const STAFF_DOORS: Array = [
	["east bar service door", Vector3(26.0, 0.0, 11.0), Vector3(23.0, 0.0, 11.0)],
	["backstage door", Vector3(13.0, 0.3, 7.0), Vector3(13.0, 0.3, 8.2)],
	["box-office staff flap", Vector3(22.0, 0.0, 27.0), Vector3(20.8, 0.0, 26.0)],
	["VIP staff door", Vector3(26.0, UP, 18.0), Vector3(24.8, UP, 18.0)],
]
const EAST_BAR_BEHIND: Vector3 = Vector3(25.2, 0.0, 12.0)
const G20_IN: Vector3 = Vector3(27.0, 0.0, 12.0)
const G23_MASK: Vector3 = Vector3(31.0, 0.0, 10.0)
const STAFF_STAIR_GROUND: Vector3 = Vector3(34.0, 0.0, 15.0)
const U6_AT: Vector3 = Vector3(33.0, UP, 15.0)
const OFFICE_DOOR_AT: Vector3 = Vector3(28.0, UP, 18.0)
const OFFICE_IN: Vector3 = Vector3(31.0, UP, 18.5)
const HALL_SHOT_AT: Vector3 = Vector3(13.0, 0.0, 16.0)
const SAFE_BAGS: int = 3
const DRILL_MAX_S: float = 600.0
const VAN_MAX_S: float = 900.0

var _civ_peak: float = 0.0


func note(msg: String) -> void:
	print("[AHP %.1fs t=%.1f] %s" % [(Time.get_ticks_msec() - _t0_ms) / 1000.0,
		rt.heist_time_s if rt != null and is_instance_valid(rt) else -1.0, msg])


func _run() -> void:
	_t0_ms = Time.get_ticks_msec()
	if runner_out.ends_with("/of_g1_pass"):
		runner_out = OS.get_user_data_dir() + "/ah_g1_pass"
		DirAccess.make_dir_recursive_absolute(runner_out)
	var tests: Array[String] = []
	if _test == "all":
		tests.assign(["casing", "stealth", "loud"])
	else:
		tests.append(_test)
	var ok: bool = true
	for t: String in tests:
		_cur = t
		_alarm = &""
		var m: String = "_ah_" + t
		if not has_method(m):
			print("[AHP] RESULT FAIL %s (unknown test)" % t)
			ok = false
			continue
		note("=== %s ===" % t)
		var passed: bool = bool(await Callable(self, m).call())
		print("[AHP] RESULT %s %s" % ["PASS" if passed else "FAIL", t])
		_results.append("%s %s" % [t, "PASS" if passed else "FAIL"])
		ok = ok and passed
	_write_rows()
	Engine.time_scale = 1.0
	RenderingServer.render_loop_enabled = true
	print("[AHP] RESULT %s (%s)" % ["PASS" if ok else "FAIL", ", ".join(_results)])
	get_tree().quit(0 if ok else 1)


func _row(item: String, verdict: String, detail: String, owner: String = "-") -> void:
	var line: String = "%s | %s | %s | %s | %s" % [_cur, item, verdict, detail, owner]
	_rows.append(line)
	print("[AHP] ROW " + line)


## Launch the Velvet with real detection (NPCs, cameras), the civilian start (no skip_casing).
func _ah_launch(loud_kit: bool = false) -> bool:
	# gear_cloak (the foyer, across the counter): reachable with no door, so the gear never decides the result.
	var opts: Dictionary = {"preplan": {"force_variants": {&"gear_drop": [&"gear_cloak"]}}}
	if loud_kit:
		opts["loadouts"] = {Net.local_slot(): _hazard_loadout()}
	if not await _launch(AH_HEIST, _seed if _seed >= 0 else AH_SEED, Enums.Difficulty.ROUTINE, opts, false):
		return false
	var mode: StringName = pilot.crew.player_mode
	_row("civilian start (D-065)", "PASS" if mode == &"civilian" else "FAIL", "mode %s at %s" % [mode,
		Po5Pilot._v(pilot.crew.global_position)], "-" if mode == &"civilian" else "A start_mode / C HeistDef")
	return mode == &"civilian"


func _worst_peak() -> float:
	var worst: float = 0.0
	for id: int in _peaks:
		worst = maxf(worst, float(_peaks[id]["max"]))
	return worst


# --- casing (civilian walk) -----------------------------------------------------------------------------------------

func _ah_casing() -> bool:
	_peaks.clear()
	if not await _ah_launch():
		return false
	var ok: bool = true
	for step: Array in FOH_WALK:
		var at: Vector3 = step[1]
		await _open_guest_doors_toward(at)
		var reached: bool = await _leg(String(step[0]), [at], 0.8, 120.0)
		ok = ok and reached
		_civ_peak = maxf(_civ_peak, _worst_peak())
		if pilot.crew.player_mode != &"civilian":
			_row("still civilian after %s" % step[0], "FAIL", "mode %s" % pilot.crew.player_mode, "A civilian rule")
			return false
	await shot("casing_foh")
	for d: Array in STAFF_DOORS:
		ok = await _staff_door_blocked(String(d[0]), d[1], d[2]) and ok
	_peaks_table()
	var worst: float = _worst_peak()
	_row("undetectable as a civilian (D-065: detection x 0)", "PASS" if worst <= 0.0 else "FAIL",
		"%d observers, peak %.2f" % [_peaks.size(), worst], "-" if worst <= 0.0 else "A detection (civilian x 0)")
	return ok and worst <= 0.0


## Any closed door within 6 m on the way to `at` that a civilian may use: F it open (guest doors, D-075).
func _open_guest_doors_toward(at: Vector3) -> void:
	var here: Vector3 = pilot.crew.global_position
	for n: Node in rt.find_children("*", "Door", true, false):
		var door: Door = n as Door
		if door.is_open or door.global_position.distance_to(here) > 6.0 \
				or door.global_position.distance_to(at) > here.distance_to(at) + 1.0:
			continue
		var comp: InteractableComponent = _comp(door)
		if comp == null or comp.availability(pilot.crew) != InteractableComponent.BLOCK_NONE:
			continue
		var opened: bool = await pilot.use(comp, 15.0, func() -> bool: return door.is_open)
		_row("guest door %s (civilian)" % door.name, "PASS" if opened else "FAIL", "opened %s" % opened,
			"-" if opened else "C civilian_allowed / A door")


## A staff door near `at` answers ui.blocked.civilian to a civilian (D-075), checked from the guest-side stand.
func _staff_door_blocked(label: String, at: Vector3, stand: Vector3) -> bool:
	var door: Door = _door_near(at, 1.5)
	if door == null:
		_row("staff door: %s" % label, "FAIL", "no Door within 1.5 m of %s" % Po5Pilot._v(at), "C map")
		return false
	if not await _go(stand, 0.6, 120.0):
		_row("staff door: %s" % label, "FAIL", "stand %s not reached" % Po5Pilot._v(stand), _owner_for(stand))
		return false
	var comp: InteractableComponent = _comp(door)
	var why: StringName = comp.availability(pilot.crew) if comp != null else &"none"
	var good: bool = why == InteractableComponent.BLOCK_CIVILIAN and not door.is_open
	_row("staff door: %s blocks a civilian" % label, "PASS" if good else "FAIL", "availability '%s', open %s" % [why,
		door.is_open], "-" if good else "C civilian_allowed (D-075)")
	return good


# --- stealth (route 1) ----------------------------------------------------------------------------------------------

func _ah_stealth() -> bool:
	_peaks.clear()
	if not await _ah_launch():
		return false
	if not await _gear():
		return false
	var safe: Safe = _safe()
	if safe == null:
		_row("office safe", "FAIL", "no Safe prefab", "C map")
		return false
	if not await _behind_east_bar():
		return false
	var have_card: bool = await _keycard()
	var have_code: bool = await _code_note(safe)
	if not have_card:
		return false
	# Upstairs (kc_vip_bar / U-side slots): the nav's shortest line runs through the masked-only VIP staff door, so a
	# casing player goes back the guest way: grand stair -> foyer -> behind the east bar -> G20.
	if pilot.crew.global_position.y > 2.0 and not await _leg("back down the guest way to G20 (casing)",
			[Vector3(8.0, UP, 26.0), Vector3(18.0, 0.0, 25.0), EAST_BAR_BEHIND, G20_IN], 0.8, 180.0):
		return false
	if not await _go(G23_MASK, 0.6, 90.0):
		_row("G23 (mask spot)", "FAIL", "not reached", _owner_for(G23_MASK))
		return false
	await _wait_unseen("G23")
	if not await _mask():
		return await _fail("mask")
	if not await _office():
		return false
	if not have_code:
		have_code = await _code_note(safe, "masked, in the office")
	var opened: bool = await _open_safe(safe, have_code)
	if not opened:
		return false
	var esc: EscapeZone = await _active_escape(60.0)
	var bags: int = await _safe_bags_to(safe, esc)
	var escaped: bool = bags >= SAFE_BAGS and await _escape(esc)
	_peaks_table()
	_row("stealth: no alarm", "PASS" if not rt.went_loud else "FAIL", "alarm '%s', peak %.2f over %d observers" % [
		_alarm, _worst_peak(), _peaks.size()], "-" if not rt.went_loud else "C patrols / P route")
	return escaped and not rt.went_loud


## The nearest gear_drop (all 4 are reachable without a staff door, D-075): F -> casing.
func _gear() -> bool:
	var gp: GearPickup = _nearest("GearPickup", pilot.crew.global_position) as GearPickup
	if gp == null:
		_row("gear (gear_drop)", "FAIL", "no GearPickup", "C map")
		return false
	var t0: float = rt.heist_time_s
	# gear_cloak is taken ACROSS the counter from the foyer (D-075): stand where a path from the crew actually ends,
	# within reach of the gear, then press F from there (pilot.use would walk to the navmesh point behind the counter).
	var stand: Vector3 = _reach_stand(gp.global_position)
	if stand == Vector3.INF or not await _go(stand, 0.4, 240.0):
		_row("gear (%s)" % gp.name, "FAIL", "no reachable stand within reach of %s" % Po5Pilot._v(gp.global_position),
			_owner_for(gp.global_position))
		return false
	var got: bool = await pilot.use(_comp(gp), 20.0, func() -> bool: return pilot.crew.player_mode == &"casing", false)
	_row("gear (%s) -> casing" % gp.name, "PASS" if got else "FAIL", "%.0f s from the spawn, mode %s, at %s" % [
		rt.heist_time_s - t0, pilot.crew.player_mode, Po5Pilot._v(gp.global_position)], "-" if got else "A gear / C slot")
	return got


## A floor point within reach (<= 1.6 m flat) of `target` that the nav path from the crew really ends at: rings of
## 0.6 / 1.0 / 1.4 m, 16 bearings, the shortest walk wins. Vector3.INF when none.
func _reach_stand(target: Vector3) -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_m: float = INF
	for r: float in [0.6, 1.0, 1.4]:
		for k: int in 16:
			var a: float = TAU * float(k) / 16.0
			var cand: Vector3 = pilot.stand_point(target + Vector3(cos(a), 0.0, sin(a)) * r)
			if Po5Pilot.flat_dist(cand, target) > 1.6:
				continue
			var p: PackedVector3Array = pilot.nav_path(cand)
			if p.is_empty() or Po5Pilot.flat_dist(p[p.size() - 1], cand) > 0.3 or absf(p[p.size() - 1].y - cand.y) > 0.5:
				continue
			var m: float = 0.0
			for i: int in range(1, p.size()):
				m += p[i - 1].distance_to(p[i])
			if m < best_m:
				best = cand
				best_m = m
	return best


## Walk within reach of `target` (_reach_stand; the plain nearest navmesh point when no ring candidate is reachable).
func _go_reach(target: Vector3, arrive: float = 0.6, timeout: float = 240.0) -> bool:
	var stand: Vector3 = _reach_stand(target)
	return await _go(stand if stand != Vector3.INF else pilot.stand_point(target), arrive, timeout)


## Route 1: behind the east bar while the floor bouncer is away, through the service door into G20 (casing).
func _behind_east_bar() -> bool:
	if not await _leg("behind the east bar", [EAST_BAR_BEHIND], 0.5, 120.0):
		return false
	var door: Door = _door_near(Vector3(26.0, 0.0, 11.0), 1.5)
	if door != null and not door.is_open:
		var why: StringName = _comp(door).availability(pilot.crew) if _comp(door) != null else &"none"
		var opened: bool = await pilot.use(_comp(door), 20.0, func() -> bool: return door.is_open)
		_row("east bar service door (casing)", "PASS" if opened else "FAIL", "availability '%s', open %s" % [why,
			door.is_open], "-" if opened else "C door lock / A casing rule")
		if not opened:
			return false
	return await _leg("into G20", [G20_IN], 0.5, 60.0)


## The nearest office keycard (any KeycardPickup slot the variant rolled), as casing.
func _keycard() -> bool:
	var best: KeycardPickup = null
	var best_m: float = INF
	for n: Node in rt.find_children("*", "KeycardPickup", true, false):
		var k: KeycardPickup = n as KeycardPickup
		var p: PackedVector3Array = pilot.nav_path(k.global_position)
		var m: float = 0.0
		for i: int in range(1, p.size()):
			m += p[i - 1].distance_to(p[i])
		if not k.taken and not p.is_empty() and m < best_m:
			best = k
			best_m = m
	if best == null:
		_row("keycard", "FAIL", "no reachable KeycardPickup", "C map / bake")
		return false
	var t0: float = rt.heist_time_s
	var kc_name: String = String(best.name)  # the pickup frees itself when taken
	var ok: bool = await _go_reach(best.global_position, 0.6, 180.0) \
		and await pilot.use(_comp(best), 20.0, func() -> bool: return pilot.crew.item_count(&"item.keycard") > 0)
	_row("keycard (%s, %.0f m walk)" % [kc_name, best_m], "PASS" if ok else "FAIL", "%.0f s, peak %.2f" % [
		rt.heist_time_s - t0, _worst_peak()], "-" if ok else "C map / A keycard")
	return ok


## The safe's code note (CodeNote with the safe's code_group). `phase` labels the row. A note out of reach now (the
## office blotter behind the masked-only VIP staff door while casing) is a NOTE, read later; false = not read.
func _code_note(safe: Safe, phase: String = "casing") -> bool:
	if safe.code_group == &"":
		_row("safe code note", "NOTE", "the safe has no code_group: drill only", "-")
		return false
	for n: Node in rt.find_children("*", "CodeNote", true, false):
		var cn: CodeNote = n as CodeNote
		if cn.code_group != safe.code_group or pilot.nav_path(cn.global_position).is_empty():
			continue
		var reached: bool = await _go_reach(cn.global_position, 0.6, 180.0)
		if not reached and pilot.last_blocked_door != null:
			_row("safe code (%s, %s)" % [cn.name, phase], "NOTE", "not reachable now: %s (%s); read later" % [
				pilot.last_blocked_door.name, _comp(pilot.last_blocked_door).availability(pilot.crew)
				if _comp(pilot.last_blocked_door) != null else "-"], "-")
			return false
		var ok: bool = reached and await pilot.use(_comp(cn), 15.0)
		_row("safe code (%s, %s)" % [cn.name, phase], "PASS" if ok else "FAIL", "read %s, code '%s'" % [ok,
			cn.code_text()], "-" if ok else "C map / A code note")
		return ok
	_row("safe code note", "NOTE", "none reachable for group %s: drill" % safe.code_group, "-")
	return false


## The staff stair -> U6 -> the office keycard door (swipe) -> in.
func _office() -> bool:
	if not await _leg("staff stair (G22) -> U6", [STAFF_STAIR_GROUND, U6_AT], 0.6, 120.0):
		return false
	var reader: KeycardReader = _nearest("KeycardReader", OFFICE_DOOR_AT, 3.0) as KeycardReader
	var door: Door = _door_near(OFFICE_DOOR_AT, 1.5)
	if door != null and not door.is_open:
		var ok: bool = reader != null and await pilot.use(_comp(reader), 20.0, func() -> bool: return door.is_open)
		_row("office keycard door", "PASS" if ok else "FAIL", "reader %s, open %s" % [reader != null, door.is_open],
			"-" if ok else "C reader binding / A keycard")
		if not ok:
			return false
	return await _leg("into the office (U9)", [OFFICE_IN], 0.6, 60.0)


func _safe() -> Safe:
	var best: Safe = null
	for n: Node in rt.find_children("*", "Safe", true, false):
		var s: Safe = n as Safe
		if best == null or s.size > best.size:  # the LARGE office safe, not G26's SMALL drop safe
			best = s
	return best


## Keypad (the code read) or the drill (placed, jams fixed); true once open.
func _open_safe(safe: Safe, have_code: bool) -> bool:
	var comp: InteractableComponent = _comp(safe)
	if comp == null:
		_row("safe", "FAIL", "no interactable", "A safe / C map")
		return false
	if not await _go_reach(safe.global_position, 0.6, 60.0):
		_row("safe", "FAIL", "not reached", _owner_for(safe.global_position))
		return false
	var t0: float = rt.heist_time_s
	var k0: StringName = comp.kind
	var method: StringName = safe.method_for(pilot.crew)
	await pilot.use(comp, 30.0, func() -> bool: return safe.opened or comp.kind != k0)
	var jams: int = 0
	if not safe.opened:
		Engine.time_scale = DEVICE_SCALE
		var t_end: float = rt.heist_time_s + DRILL_MAX_S
		while not safe.opened and rt.heist_time_s < t_end:
			if comp.kind == &"fix_drill":
				Engine.time_scale = 1.0
				jams += 1
				await pilot.use(comp, 30.0, func() -> bool: return comp.kind != &"fix_drill")
				Engine.time_scale = DEVICE_SCALE
			await wait_s(0.5)
		Engine.time_scale = 1.0
	_row("safe by %s%s" % [method, " (code read)" if have_code else ""], "PASS" if safe.opened else "FAIL",
		"opened %s after %.0f s heist time, %d jam(s) fixed" % [safe.opened, rt.heist_time_s - t0, jams],
		"-" if safe.opened else "A safe")
	await shot("%s_safe" % _cur)
	return safe.opened


## The active van's EscapeZone (stealth: present; loud: once it returns), waiting up to `max_s`.
func _active_escape(max_s: float) -> EscapeZone:
	var t_end: float = rt.heist_time_s + max_s
	while true:
		for n: Node in rt.find_children("*", "EscapeZone", true, false):
			if (n as EscapeZone).active:
				return n as EscapeZone
		if rt.heist_time_s >= t_end:
			return null
		await wait_s(1.0)
	return null


## Bag the safe's cash (its contents' LootSpawns) and carry each to the secure zone at `esc` (G at the zone).
func _safe_bags_to(safe: Safe, esc: EscapeZone) -> int:
	var zone: SecureZone = _secure_zone_near(esc.global_position) if esc != null else null
	if zone == null:
		_row("van secure zone", "FAIL", "escape %s, no SecureZone near it" % esc, "A escape / C map")
		return 0
	var n: int = 0
	for prefab: GameplayPrefab in safe.contents():
		if n >= SAFE_BAGS:
			break
		var t0: float = rt.heist_time_s
		if not await _go_reach(prefab.global_position, 0.6, 300.0):
			break
		if not await pilot.use(_comp(prefab), 20.0, func() -> bool: return pilot.crew.is_carrying_bag()):
			continue
		var id: int = (pilot.crew.carried_bag as LootBag).net_id
		var t1: float = rt.heist_time_s
		var s0: int = pilot.stuck_spots.size()
		var ok: bool = await _go_reach(zone.global_position, 1.5, 400.0)
		if ok:
			await pilot.face(zone.global_position + Vector3.UP * 0.5, 0.05, 1.5)
			await pilot.inp.tap(&"drop_bag")
			await wait_until(func() -> bool: return _secured_ids.has(id), 3.0)
		var sec: bool = _secured_ids.has(id)
		var stuck: int = pilot.stuck_spots.size() - s0
		n += 1 if sec else 0
		_row("bag %d: safe -> van (%s)" % [n, esc.name], "PASS" if sec and stuck == 0 else ("STUCK" if sec else "FAIL"),
			"bagged in %.0f s, carried in %.0f s, %d STUCK row(s), secured %s" % [t1 - t0, rt.heist_time_s - t1, stuck,
			sec], "-" if sec and stuck == 0 else ("C map" if stuck > 0 else "A secure zone"))
	return n


func _escape(esc: EscapeZone) -> bool:
	var ok: bool = await _go(esc.global_position, 1.0, 240.0)
	await wait_until(func() -> bool: return rt.phase == Enums.HeistPhase.ENDED or esc.escaping_slots(rt).has(pilot.crew.slot),
		20.0)
	var out: bool = rt.phase == Enums.HeistPhase.ENDED or esc.escaping_slots(rt).has(pilot.crew.slot)
	_row("escape (%s)" % esc.name, "PASS" if out else "FAIL", "reached %s, escaping %s" % [ok, out],
		"-" if out else "A escape")
	return out


# --- loud -----------------------------------------------------------------------------------------------------------

func _ah_loud() -> bool:
	if not await _ah_launch(_build() == "loud"):
		return false
	# Masked straight after the gear (the alarm comes next anyway): a masked crew is not door-gated as casing is.
	if not await _gear():
		return false
	if not await _mask():
		return await _fail("mask")
	if not await _behind_east_bar() or not await _keycard():
		return false
	pilot.combat = true
	if not await _go(HALL_SHOT_AT, 0.8, 120.0):
		_row("hall (the alarm shot)", "FAIL", "not reached", _owner_for(HALL_SHOT_AT))
		return false
	var t_alarm: float = rt.heist_time_s
	pilot.inp.press(&"fire")
	await wait_until(func() -> bool: return rt.went_loud, 6.0)
	pilot.inp.release(&"fire")
	_row("the alarm (a burst in the hall)", "PASS" if rt.went_loud else "FAIL", "loud %s after %.1f s, alarm '%s'" % [
		rt.went_loud, rt.heist_time_s - t_alarm, _alarm], "-" if rt.went_loud else "A alarm (noise)")
	if not rt.went_loud:
		return false
	await wait_s(3.0)
	await shot("loud_house_lights")
	var safe: Safe = _safe()
	if safe == null or not await _office() or not await _open_safe(safe, false):
		_danger_rows("loud")
		return false
	var esc: EscapeZone = await _active_escape(VAN_MAX_S)
	_row("van back (2nd FADE or 300 s)", "PASS" if esc != null else "FAIL", "escape %s at t=%.0f" % [esc,
		rt.heist_time_s], "-" if esc != null else "A mission (escape_wait)")
	var bags: int = await _safe_bags_to(safe, esc) if esc != null else 0
	var out: bool = bags >= SAFE_BAGS and await _escape(esc)
	_danger_rows("loud")
	return out
