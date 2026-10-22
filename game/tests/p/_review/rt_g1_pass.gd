# gdlint:disable=max-returns,max-file-lines
## RT-P1 (next_heist_rolling_thunder.md §7 "G1 tests (ENV P)"): Rolling Thunder G1 greybox traversal by REAL INPUT.
## Built on of_g1_pass.gd (its Po5Pilot + PlayerInputDriver helpers: mouse look, WASD, crouch, jump, F holds, G throws;
## no teleports, no intent injection). One mode per §7 item that does NOT need the trucks (--test=):
##   stairs     stair A and stair B: ground -> Deck 2 -> roof and back down, every flight and half landing (§7.2), then
##              stair A up with a MEDIUM bag.
##   ramps      R1 + R2 ground -> roof and back by straight W walks (8.3 deg, 3.2 m headroom), then again with a HEAVY bag.
##   lift       the goods lift (lift_powered): walk in / out of the car at all 3 landings (sills <= 0.02 m), 2 bags in
##              on the ground, sent to the roof, both taken out there.
##   site       the man-gate padlock (lockpick), the FrameLadder up / down (empty-handed, S10.1b; a bag try logged), the
##              scaffold stair up / down with a MEDIUM bag (§7.6).
##   throws     every §7.5 throw, MEDIUM and HEAVY at 3 pitches: Orchard sidewalk -> west bays, the forecourt railing ->
##              trench, Deck 2 south barrier -> forecourt, F1 edge protection -> grade, pad edge -> the E3 hover zone.
##   underpass  the 32 m road ramp down, under the rail bridge, the east cut's end and back up, carriageway and both
##              sidewalk lanes (§7.1 / §7.9).
##   kerbs      straight W crossings of Orchard (the kerbed median) and Tannery, with a height profile of each line (§7.7:
##              kerbs <= 0.15 m).
##   escapes    E1 / E2 / E3 reached on foot from the plaza spawn; E3 <-> both head houses step-free (§7.14).
##   fences     the hoarding (2.4 m, nothing standable within 0.5 m: a ray probe of both faces + real jump tries) and the
##              rail palisades / lane fence (1.8 m, unclimbable: jump tries from the rail lane) (§7.6 / §7.9).
##   Truck phase (A's RT mission + C's trucks, trunk r275+):
##   ambush_clean / ambush_crash  north: rig hacked + no alarm -> clean stop and the +8 s ambush; 3 shots -> crash stop;
##              each truck's rear UsePoint reachable in that layout; the mixer / Tannery gate row.
##   breach     north clean, trucks_3, stores_both: T1 by the placed saw (jams fixed), T2 by the tool store's thermite
##              bag, T3 by C4 from the magazine (padlock + a box of 4), a T1 cargo bag on foot to E1.
##   c4         north clean, trucks_3, stores_c4: T3 by C4 alone (magazine padlock sawn once loud), its cargo -> E1.
##   east_e1 / east_e2  east clean: a HEAVY bag T1 -> E1, T3 -> E2 (trucks_3).
##   setup      from each spawn (plaza, car park, underpass), REAL detection: man-gate, rig hack; times vs the ETA and
##              every observer's peak D-128 fill.
##   trucks     the six truck-phase tests in turn.
##   clean_haz  as blown but a CLEAN stop: the crew hidden for the setup (shortcut), masked at Pier-40, real from the stop.
##   blown      Hazardous blown setup, REAL play: 3 AI teammates, mask + 3 shots at the plaza, the crash stop fought
##              from Pier-40's cover, T1 sawn and defended; rows: truck opened, downs, where the hits come from.
##   all        the nine traversal tests (stairs .. fences) in turn (a fresh launch each); continues past failures, one summary at the end.
## Command (windowed only, D-086; start it only when `pgrep -xc godot` <= 1):
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/rt_g1_pass.tscn -- --test=stairs|ramps|lift|site|throws|underpass|kerbs|escapes|fences|all \
##     --out=/abs/dir [--seed=N] [--render]
## Stated shortcuts (of_g1_pass.gd's): direct HeistLauncher.launch with a seed and pinned variants (PreplanResult
## force_variants); NPCs despawned (HeistRuntime.isolate_npc), the crew stealth_hidden and cameras disabled (geometry,
## not stealth); bags from LootManager.spawn_bag at the crew's feet, PICKED UP by F.
## Output: "[RTP ...]" notes; one "[RTP] ROW <test> | <item> | <PASS|STUCK|FAIL|NOTE> | <detail> | <owner>" per item
## (owner: C map = geometry / bake, A nav = path query / runtime); "[RTP] RESULT <PASS|FAIL> <test>" per test and a final
## "[RTP] RESULT ...". rows.md (the row table) and PNGs in --out.
## Owner: ENV P.
extends "res://tests/p/_review/of_g1_pass.gd"

const RT_HEIST: StringName = &"rolling_thunder"
const RT_SEED: int = 4101
const RT_FFL: Array[float] = [-5.0, 0.0, 3.5, 7.0]
const RT_SPAWN_CARPARK: StringName = &"preplan_spawn_carpark"
const RT_SPAWN_UNDERPASS: StringName = &"preplan_spawn_underpass"
const RT_FORCE: Dictionary = {&"goods_lift": [&"lift_powered"], &"player_perch": [&"perch_carpark_roof"],
	&"escape": [&"esc_van_carpark"]}
## Stair cores (rolling_thunder_layout FLIGHTS): per core, the stand inside each floor's landing and each half landing,
## bottom to top, and a deck point outside each floor's door.
const STAIR_A: Array[Vector3] = [Vector3(18.2, 0.0, -44.8), Vector3(17.5, 1.75, -49.0), Vector3(17.0, 3.5, -44.8),
	Vector3(18.2, 3.5, -44.8), Vector3(17.5, 5.25, -49.0), Vector3(17.0, 7.0, -44.8)]
const STAIR_A_OUT: Array[Vector3] = [Vector3(21.5, 0.0, -43.0), Vector3(21.5, 3.5, -43.0), Vector3(23.0, 7.0, -42.0)]
const STAIR_B: Array[Vector3] = [Vector3(51.2, 0.0, -19.1), Vector3(50.5, 1.75, -15.0), Vector3(49.8, 3.5, -19.1),
	Vector3(51.2, 3.5, -19.1), Vector3(50.5, 5.25, -15.0), Vector3(49.8, 7.0, -19.1)]
const STAIR_B_OUT: Array[Vector3] = [Vector3(47.0, 0.0, -17.5), Vector3(47.0, 3.5, -17.0), Vector3(47.0, 7.0, -17.0)]
## Ramps R1 (0 -> 3.5) and R2 (3.5 -> 7.0), x 43-49, rising north from z -20 to z -44.
const R1_FOOT: Vector3 = Vector3(46.0, 0.0, -17.5)
const R1_TOP: Vector3 = Vector3(46.0, 3.5, -45.5)
const R2_FOOT: Vector3 = Vector3(46.0, 3.5, -17.5)
const R2_TOP: Vector3 = Vector3(46.0, 7.0, -45.5)
## Goods lift (Gameplay/Lifts GoodsLift (20.5, 0, -48.5), landings 0 / 3.5 / 7.0, doors on z -47).
const LIFT_AT: Vector3 = Vector3(20.5, 0.0, -48.5)
const LIFT_STAND_Z: float = -46.2
const LIFT_IN_Z: float = -48.6
## Site: the man-gate (-14, 0, -16) from the Orchard sidewalk; FrameLadder (-49.3, 0, -50.08) 3.5 m; scaffold stair
## STW (-36..-32, -30..-24): foot entrance under CladNMid at z -30, flights x -34.7 (up south) / -33.3 (up north).
const MAN_GATE_OUT: Vector3 = Vector3(-12.3, 0.0, -16.3)
const MAN_GATE_IN: Vector3 = Vector3(-16.0, 0.0, -16.3)
const FRAME_LADDER_AT: Vector3 = Vector3(-49.3, 0.0, -50.08)
const SCAFFOLD: Array[Vector3] = [Vector3(-34.0, 0.0, -31.5), Vector3(-34.7, 0.0, -29.2), Vector3(-34.0, 1.75, -25.0),
	Vector3(-33.3, 3.5, -29.3), Vector3(-34.0, 3.5, -32.0)]
## §7.5 throw spots: [label, stand, aim, landing rule]. Rules: "cpg" CP-G deck inside the west barrier (x > 16.3, y < 0.6),
## "trench" in the underpass ramp (z > -10.8, y < -0.8), "forecourt" (z -14..-11, y < 0.6), "grade" outside the frame
## slab at grade (y < 0.6), "e3" secured in the hover zone.
const THROW_SPOTS: Array = [
	["orchard -> west bays", Vector3(15.6, 0.0, -30.0), Vector3(22.0, 0.0, -30.0), "cpg"],
	["forecourt railing -> trench", Vector3(45.0, 0.0, -11.6), Vector3(45.0, -2.0, -6.0), "trench"],
	["deck 2 south barrier -> forecourt", Vector3(30.0, 3.5, -14.6), Vector3(30.0, 0.0, -11.5), "forecourt"],
	["pad edge -> E3", Vector3.INF, Vector3(32.0, 7.0, -34.0), "e3"],
	["F1 edge protection -> grade", Vector3(-40.0, 3.5, -30.6), Vector3(-40.0, 0.0, -26.0), "grade"],
]
const THROW_BACKS: Array[float] = [0.0, 0.8, 1.6]
## Underpass legs (the ramp x 34..66, the bridge x 66..84, the east cut to x 104): carriageway, north and south lanes.
const UNDERPASS_LANES: Array[float] = [0.0, -9.5, 9.5]
const UNDERPASS_WEST_X: float = 30.0
const UNDERPASS_EAST_X: float = 101.0
## Kerb crossings: [label, from, to].
const KERB_LINES: Array = [
	["Orchard z -20 (W -> E)", Vector3(-12.5, 0.0, -20.0), Vector3(12.5, 0.0, -20.0)],
	["Orchard z 20 (E -> W)", Vector3(12.5, 0.0, 20.0), Vector3(-12.5, 0.0, 20.0)],
	["Tannery x -30 (N -> S)", Vector3(-30.0, 0.0, -10.5), Vector3(-30.0, 0.0, 10.5)],
	["Tannery x 24 (S -> N)", Vector3(24.0, 0.0, 10.5), Vector3(24.0, 0.0, -10.5)],
]
const KERB_MAX_M: float = 0.15
## Escapes (content PREPLAN escape points) and the head-house doors (roof).
const E1_AT: Vector3 = Vector3(23.0, 0.0, -30.0)
const E2_AT: Vector3 = Vector3(92.0, -5.0, -4.0)
const E3_AT: Vector3 = Vector3(32.0, 7.0, -34.0)
const HH_A_IN: Vector3 = Vector3(17.0, 7.0, -44.8)
const HH_B_IN: Vector3 = Vector3(49.8, 7.0, -19.1)
## Hoarding runs (Site/Hoarding, 2.4 m): [label, a, b] along the face; jump tries at fixed points [label, stand, dir].
const HOARDING_RUNS: Array = [
	["N", Vector3(-60.0, 0.0, -56.0), Vector3(-14.0, 0.0, -56.0)],
	["W", Vector3(-60.0, 0.0, -56.0), Vector3(-60.0, 0.0, -11.0)],
	["E", Vector3(-14.0, 0.0, -56.0), Vector3(-14.0, 0.0, -11.0)],
	["S", Vector3(-60.0, 0.0, -11.0), Vector3(-14.0, 0.0, -11.0)],
]
const STANDABLE_PROBE_M: float = 0.5
const STANDABLE_MIN_M: float = 0.3
const JUMP_TRIES: Array = [
	["hoarding E from the Orchard sidewalk", Vector3(-13.4, 0.0, -30.0), Vector3(-1.0, 0.0, 0.0)],
	["hoarding S from the Tannery sidewalk", Vector3(-45.0, 0.0, -10.4), Vector3(0.0, 0.0, -1.0)],
	["hoarding E from inside the site", Vector3(-14.6, 0.0, -25.0), Vector3(1.0, 0.0, 0.0)],
	["lane fence south from the rail lane", Vector3(58.0, 0.0, -14.7), Vector3(0.0, 0.0, 1.0)],
	["palisade x 64 from the rail lane", Vector3(63.3, 0.0, -40.0), Vector3(1.0, 0.0, 0.0)],
	["palisade x 64 from the rail lane (north)", Vector3(63.3, 0.0, -60.0), Vector3(1.0, 0.0, 0.0)],
]
const RAIL_LANE_IN: Vector3 = Vector3(55.0, 0.0, -35.0)
const FIRE_DOOR_IN: Vector3 = Vector3(50.8, 0.0, -35.0)

const DEVICE_SCALE: float = 3.0
const UNSEEN_GUARD_M: float = 30.0
const UNSEEN_CIV_M: float = 15.0
const UNSEEN_HOLD_S: float = 2.0
const SIGNAL_RIG_AT: Vector3 = Vector3(-16.25, 0.75, -13.45)
const MAGAZINE_DOOR_AT: Vector3 = Vector3(-23.0, 0.0, -49.0)
const MAGAZINE_BOXES_AT: Vector3 = Vector3(-23.0, 0.0, -51.0)
const C4_NEEDED: int = 4
const TOOL_STORE_DOOR_AT: Vector3 = Vector3(-48.0, 0.0, -17.0)
const THERMITE_BAG_AT: Vector3 = Vector3(-47.5, 0.0, -20.5)
## Where the crew waits for the convoy (north: the Orchard west sidewalk by the site; east: the forecourt).
const WAIT_NORTH: Vector3 = Vector3(-12.0, 0.0, -24.0)
const WAIT_EAST: Vector3 = Vector3(20.0, 0.0, -12.5)

const BLOWN_COVER: Vector3 = Vector3(0.0, 0.0, -37.6)
const BLOWN_FIGHT_S: float = 150.0
const BLOWN_MAX_S: float = 900.0
const BLOWN_PEEK_M: float = 45.0
const LULL_S: float = 2.0
const HAZ_PRIMARY: StringName = &"weapon.corsair_ar"
const HAZ_ARMOR: StringName = &"armor.heavy_vest"
const HAZ_DEPLOYABLE: StringName = &"deployable.doctor_bag"

var _rows: PackedStringArray = PackedStringArray()
var _straight_on: bool = false
var _hits: Dictionary = {}
var _downs: Dictionary = {}
var _crew_ids: Dictionary = {}
var _hp_min: float = INF
var _obj_states: Dictionary = {}


func note(msg: String) -> void:
	print("[RTP %.1fs t=%.1f] %s" % [(Time.get_ticks_msec() - _t0_ms) / 1000.0,
		rt.heist_time_s if rt != null and is_instance_valid(rt) else -1.0, msg])


func _run() -> void:
	_t0_ms = Time.get_ticks_msec()
	if runner_out.ends_with("/of_g1_pass"):
		runner_out = OS.get_user_data_dir() + "/rt_g1_pass"
		DirAccess.make_dir_recursive_absolute(runner_out)
	var tests: Array[String] = []
	if _test == "all":
		tests.assign(["stairs", "ramps", "lift", "site", "throws", "underpass", "kerbs", "escapes", "fences"])
	elif _test == "trucks":
		tests.assign(["ambush_clean", "ambush_crash", "breach", "east_e1", "east_e2", "setup"])
	else:
		tests.append(_test)
	var ok: bool = true
	for t: String in tests:
		_cur = t
		_alarm = &""
		var m: String = "_rt_" + t
		if not has_method(m):
			print("[RTP] RESULT FAIL %s (unknown test)" % t)
			ok = false
			continue
		note("=== %s ===" % t)
		var passed: bool = bool(await Callable(self, m).call())
		print("[RTP] RESULT %s %s" % ["PASS" if passed else "FAIL", t])
		_results.append("%s %s" % [t, "PASS" if passed else "FAIL"])
		ok = ok and passed
	_write_rows()
	Engine.time_scale = 1.0
	RenderingServer.render_loop_enabled = true
	print("[RTP] RESULT %s (%s)" % ["PASS" if ok else "FAIL", ", ".join(_results)])
	get_tree().quit(0 if ok else 1)


func _fail(step: String) -> bool:
	note("FAIL %s/%s (alarm %s)" % [_cur, step, _alarm])
	print("[RTP] FAIL %s/%s" % [_cur, step])
	if rt != null and is_instance_valid(rt):
		await shot("fail_%s_%s" % [_cur, step.replace(" ", "_").replace(">", "")])
	return false


func _row(item: String, verdict: String, detail: String, owner: String = "-") -> void:
	var line: String = "%s | %s | %s | %s | %s" % [_cur, item, verdict, detail, owner]
	_rows.append(line)
	print("[RTP] ROW " + line)


func _write_rows() -> void:
	var f: FileAccess = FileAccess.open(runner_out + "/rows.md", FileAccess.WRITE)
	if f == null:
		return
	f.store_line("| test | item | verdict | detail | owner |")
	f.store_line("|---|---|---|---|---|")
	for r: String in _rows:
		f.store_line("| " + r + " |")
	f.close()


func _rt_launch(force: Dictionary = {}, spawn_tag: StringName = &"") -> bool:
	var f: Dictionary = RT_FORCE.duplicate(true)
	for k: Variant in force:
		f[k] = force[k]
	var pre: Dictionary = {"force_variants": f}
	if spawn_tag != &"":
		pre["spawn_tag"] = spawn_tag
	var opts: Dictionary = {"preplan": pre, "skip_casing": true}
	if not await _launch(RT_HEIST, _seed if _seed >= 0 else RT_SEED, Enums.Difficulty.ROUTINE, opts, true):
		return false
	if not await _mask():
		return await _fail("mask")
	return true


## Who owns a failed walk to `to`: no nav path that ends there -> the bake / nav (C bake, A NavPath); a path but the
## crew did not get along it -> the map's colliders (C).
func _owner_for(to: Vector3) -> String:
	var path: PackedVector3Array = pilot.nav_path(to)
	if path.is_empty() or pilot.flat_dist(path[path.size() - 1], to) > 0.6 \
			or absf(path[path.size() - 1].y - to.y) > 0.8:
		return "nav: no path to %s (C bake / A NavPath)" % Po5Pilot._v(to)
	if not _path_clear(path):
		return "C map: the nav path runs through a collider"
	return "C map (collider) / P controller"


## Walk the waypoints in order (navmesh). One ROW for the leg: PASS, STUCK (reached, but Po5Pilot logged STUCK rows)
## or FAIL (a waypoint not reached).
func _leg(item: String, pts: Array, arrive: float = 0.5, timeout: float = 120.0) -> bool:
	var s0: int = pilot.stuck_spots.size()
	var t0: float = rt.heist_time_s
	for p: Vector3 in pts:
		if not await _go(p, arrive, timeout):
			_row(item, "FAIL", "waypoint %s not reached (at %s, %d STUCK)" % [Po5Pilot._v(p),
				Po5Pilot._v(pilot.crew.global_position), pilot.stuck_spots.size() - s0], _owner_for(p))
			await shot("leg_fail")
			return false
	var n: int = pilot.stuck_spots.size() - s0
	_row(item, "STUCK" if n > 0 else "PASS", "%.1f s, %d STUCK row(s)%s" % [rt.heist_time_s - t0, n,
		(": first at " + Po5Pilot._v(pilot.stuck_spots[s0]["pos"])) if n > 0 else ""],
		"C map (collider)" if n > 0 else "-")
	return true


## A straight W walk (no navmesh) from where the crew stands to `to`: ramps, sills, kerbs. Logs speed and min speed.
func _straight(item: String, to: Vector3, timeout: float = 40.0) -> bool:
	var vmin: Array[float] = [INF]
	var watch: Callable = func() -> void:
		var my_rt: HeistRuntime = rt
		await wait_s(0.6)
		while _straight_on and rt == my_rt:
			if pilot.crew.is_on_floor():
				vmin[0] = minf(vmin[0], _crew_v())
			await pilot.tick()
	_straight_on = true
	watch.call_deferred()
	var y0: float = pilot.crew.global_position.y
	var v: float = await _walk_straight(to, timeout, false, 0.3)
	_straight_on = false
	var dy: float = pilot.crew.global_position.y - y0
	if v < 0.0:
		_row(item, "FAIL", "not reached: stopped at %s (%.1f m short)" % [Po5Pilot._v(pilot.crew.global_position),
			pilot.flat_dist(pilot.crew.global_position, to)], "C map (collider)")
		await shot("straight_fail")
		return false
	var slow: bool = vmin[0] < 0.5 * v
	_row(item, "STUCK" if slow else "PASS", "mean %.2f m/s, min %.2f m/s on the floor, rise %+.2f m" % [v, vmin[0], dy],
		"C map (snag)" if slow else "-")
	return true



# --- stairs ---------------------------------------------------------------------------------------------------------

func _rt_stairs() -> bool:
	if not await _rt_launch({}, RT_SPAWN_CARPARK):
		return false
	var ok: bool = true
	for core: Array in [["stair A", STAIR_A, STAIR_A_OUT], ["stair B", STAIR_B, STAIR_B_OUT]]:
		var nm: String = core[0]
		var pts: Array[Vector3] = core[1]
		var outs: Array[Vector3] = core[2]
		if not await _leg("%s: to the ground door" % nm, [outs[0]], 0.6, 180.0):
			ok = false
			continue
		var up: Array[Vector3] = [pts[0], pts[1], pts[2]]
		ok = await _leg("%s: ground -> Deck 2 (in, 2 flights, out)" % nm, up + [outs[1]]) and ok
		var up2: Array[Vector3] = [pts[3], pts[4], pts[5]]
		ok = await _leg("%s: Deck 2 -> roof" % nm, up2 + [outs[2]]) and ok
		await shot("%s_roof" % nm.replace(" ", "_"))
		var dn: Array[Vector3] = [pts[5], pts[4], pts[3], pts[2], pts[1], pts[0]]
		ok = await _leg("%s: roof -> ground" % nm, dn + [outs[0]]) and ok
	# Stair A up with a MEDIUM bag.
	if not await _go(STAIR_A_OUT[0], 0.6, 120.0):
		return await _fail("stair A ground door")
	if await _get_bag(LOOT_MEDIUM) == null:
		return await _fail("bag")
	var all: Array[Vector3] = STAIR_A.duplicate()
	ok = await _leg("stair A: ground -> roof with a MEDIUM bag", all + [STAIR_A_OUT[2]]) and ok
	if not pilot.crew.is_carrying_bag():
		_row("stair A with a MEDIUM bag", "FAIL", "the bag was lost on the way", "P controller")
		ok = false
	await shot("stair_a_bag")
	return ok


# --- ramps ----------------------------------------------------------------------------------------------------------

func _rt_ramps() -> bool:
	if not await _rt_launch({}, RT_SPAWN_CARPARK):
		return false
	var ok: bool = true
	for heavy: bool in [false, true]:
		var tag: String = " with a HEAVY bag" if heavy else ""
		if not await _leg("R1 foot%s" % tag, [R1_FOOT], 0.4, 180.0):
			return false
		if heavy and await _get_bag(LOOT_HEAVY) == null:
			return await _fail("HEAVY bag")
		if heavy:
			await _go(R1_FOOT, 0.4, 20.0)
		ok = await _straight("R1 up%s (straight W)" % tag, R1_TOP, 60.0) and ok
		if not await _leg("Deck 2 north -> R2 foot%s" % tag, [R2_FOOT], 0.4, 180.0):
			return false
		ok = await _straight("R2 up%s (straight W)" % tag, R2_TOP, 60.0) and ok
		await shot("ramps_roof%s" % ("_heavy" if heavy else ""))
		if not await _leg("roof -> R2 top%s" % tag, [R2_TOP], 0.4, 60.0):
			return false
		ok = await _straight("R2 down%s" % tag, R2_FOOT, 60.0) and ok
		if not await _leg("Deck 2 south -> R1 top%s" % tag, [R1_TOP], 0.4, 180.0):
			return false
		ok = await _straight("R1 down%s" % tag, R1_FOOT, 60.0) and ok
		if heavy and not pilot.crew.is_carrying_bag():
			_row("ramps with a HEAVY bag", "FAIL", "the bag was lost on the way", "P controller")
			ok = false
	return ok


# --- lift -----------------------------------------------------------------------------------------------------------

func _lift_y(i: int) -> float:
	return RT_FFL[i + 1]


func _rt_lift() -> bool:
	if not await _rt_launch({}, RT_SPAWN_CARPARK):
		return false
	var lift: BagLift = _nearest("BagLift", LIFT_AT, 3.0) as BagLift
	if lift == null:
		return await _fail("no BagLift near %s" % Po5Pilot._v(LIFT_AT))
	note("lift %s: %d landings, travel %.1f s, at landing %d" % [lift.name, lift.landing_count(), lift.travel_s,
		lift.landing])
	var ok: bool = true
	# Walk in and out of the car at every landing (the sills, §7.2 <= 0.02 m).
	for i: int in [1, 2, 0]:
		var y: float = _lift_y(i)
		var stand: Vector3 = Vector3(LIFT_AT.x, y, LIFT_STAND_Z)
		var floor_pts: Array[Vector3] = [STAIR_A[0], STAIR_A[2], STAIR_A[5]]
		if not await _go(floor_pts[i], 0.5, 180.0) or not await _go(stand, 0.3, 60.0):
			_row("lift landing %d: reach the landing" % i, "FAIL", "at %s" % Po5Pilot._v(pilot.crew.global_position),
				_owner_for(stand))
			ok = false
			continue
		if not await _lift_to(lift, i, stand):
			_row("lift landing %d: call the car" % i, "FAIL", "car at landing %d" % lift.landing, "A lift / C panel")
			ok = false
			continue
		await wait_s(lift.door_travel() + 0.3)
		var ld: Door = _door_near(Vector3(LIFT_AT.x, y, -47.0), 1.0)
		if ld != null and not ld.is_open:
			await pilot.use(_comp(ld), 20.0, func() -> bool: return ld.is_open)
			await _go(stand, 0.3, 20.0)
		ok = await _straight("lift landing %d: walk into the car" % i, Vector3(LIFT_AT.x, y, LIFT_IN_Z), 10.0) and ok
		_row("lift landing %d: car floor" % i, "NOTE", "crew y %.3f vs landing %.3f (%+.3f m)" % [
			pilot.crew.global_position.y, y, pilot.crew.global_position.y - y], "-")
		ok = await _straight("lift landing %d: walk out" % i, stand + Vector3(0.0, 0.0, 0.8), 10.0) and ok
	# 2 bags in on the ground, up to the roof, both out there.
	var g_stand: Vector3 = Vector3(LIFT_AT.x, 0.0, LIFT_STAND_Z)
	if not await _lift_to(lift, 0, g_stand):
		return await _fail("lift to the ground")
	for k: int in 2:
		var lb: LootBag = await _get_bag(LOOT_HEAVY if k == 0 else LOOT_MEDIUM)
		if lb == null:
			return await _fail("bag %d" % k)
		if not await _bag_into_car(lift, g_stand):
			_row("lift: bag %d into the car" % k, "FAIL", "car has %d" % lift.bags_in_car().size(), "C car box / A lift")
			return await _fail("bag %d into the car" % k)
	_row("lift: 2 bags in the car (HEAVY + MEDIUM)", "PASS" if lift.bags_in_car().size() >= 2 else "FAIL",
		"%d bags" % lift.bags_in_car().size(), "-")
	var t0: float = rt.heist_time_s
	if not await _lift_to(lift, 2, g_stand):
		return await _fail("send to the roof")
	_row("lift: ground -> roof", "PASS" if lift.bags_in_car().size() >= 2 else "FAIL", "%.1f s, %d bags rode up" % [
		rt.heist_time_s - t0, lift.bags_in_car().size()], "-")
	var r_stand: Vector3 = Vector3(LIFT_AT.x, 7.0, LIFT_STAND_Z)
	if not await _leg("lift: ground -> roof by stair A to meet the car", STAIR_A.duplicate() + [r_stand]):
		return false
	var got: int = 0
	for k: int in 2:
		var bags: Array[LootBag] = lift.bags_in_car()
		if bags.is_empty():
			break
		if await pilot.use(_comp(bags[0]), 30.0, func() -> bool: return pilot.crew.is_carrying_bag()):
			got += 1
			await _go(Vector3(LIFT_AT.x + 2.5, 7.0, LIFT_STAND_Z + 2.0), 0.5, 20.0)
			await pilot.inp.tap(&"drop_bag")
			await wait_s(1.0)
	_row("lift: both bags out on the roof", "PASS" if got == 2 else "FAIL", "%d of 2 taken out by F" % got,
		"-" if got == 2 else "C car / A lift")
	await shot("lift_roof")
	return ok and got == 2


# --- site -----------------------------------------------------------------------------------------------------------

func _rt_site() -> bool:
	if not await _rt_launch():
		return false
	if not await _site_in():
		return false
	var ok: bool = true
	var lad: Ladder = _nearest("Ladder", FRAME_LADDER_AT, 3.0) as Ladder
	if lad == null:
		_row("FrameLadder", "FAIL", "no Ladder near %s" % Po5Pilot._v(FRAME_LADDER_AT), "C map")
		ok = false
	else:
		var up_ok: bool = await _climb(lad, true)
		_row("FrameLadder up (3.5 m)", "PASS" if up_ok else "FAIL", "at %s" % Po5Pilot._v(pilot.crew.global_position),
			"-" if up_ok else "C ladder landing / P climb")
		await shot("frame_ladder_top")
		var dn_ok: bool = up_ok and await _climb(lad, false)
		_row("FrameLadder down", "PASS" if dn_ok else "FAIL", "at %s" % Po5Pilot._v(pilot.crew.global_position),
			"-" if dn_ok else "C ladder landing / P climb")
		ok = ok and up_ok and dn_ok
		# S10.1b: a bag can't go up a ladder.
		if await _get_bag(LOOT_MEDIUM) != null:
			var refused: bool = not await _climb(lad, true)
			var still: bool = pilot.crew.is_carrying_bag()
			_row("FrameLadder with a bag (S10.1b: refused)", "PASS" if refused or not still else "FAIL",
				"climbed %s, still carrying %s, y %.1f" % [not refused, still, pilot.crew.global_position.y], "-")
			if not refused and pilot.crew.global_position.y > 2.0:
				await _climb(lad, false)
	# The scaffold stair with a MEDIUM bag, up and down.
	if not await _go(SCAFFOLD[0], 0.5, 120.0):
		return await _fail("scaffold foot")
	if await _get_bag(LOOT_MEDIUM) == null:
		return await _fail("bag")
	ok = await _leg("scaffold stair up with a MEDIUM bag", [SCAFFOLD[1], SCAFFOLD[2], SCAFFOLD[3], SCAFFOLD[4]]) and ok
	await shot("scaffold_top")
	ok = await _leg("scaffold stair down with a MEDIUM bag", [SCAFFOLD[3], SCAFFOLD[2], SCAFFOLD[1], SCAFFOLD[0]]) and ok
	if not pilot.crew.is_carrying_bag():
		_row("scaffold with a bag", "FAIL", "the bag was lost on the way", "P controller")
		ok = false
	return ok


## Plaza / street -> the man-gate: pick its padlock (F, lockpick 8 s), walk through it into the site.
func _site_in() -> bool:
	if not await _leg("street -> man-gate (Orchard sidewalk)", [MAN_GATE_OUT], 0.5, 180.0):
		return false
	var gate: Door = _door_near(Vector3(-14.0, 0.0, -16.0), 2.5)
	var lock: Node3D = _nearest("Padlock", Vector3(-14.0, 1.05, -16.0), 2.0)
	if gate != null and not gate.is_open and lock != null:
		if not pilot.crew.stealth_hidden:
			await _wait_unseen("man-gate")
		await _mask()  # interactions need the mask (InteractableComponent: casing_allowed only); mask at the gate
		var used: bool = await pilot.use(_comp(lock), 40.0, func() -> bool: return gate.is_open or not gate.locked)
		_row("man-gate padlock (lockpick)", "PASS" if used else "FAIL", "gate open %s" % gate.is_open,
			"-" if used else "A padlock / C placement")
		if not gate.is_open:
			await pilot.use(_comp(gate), 20.0, func() -> bool: return gate.is_open)
	else:
		_row("man-gate", "NOTE", "gate %s padlock %s" % [gate, lock], "-")
	return await _leg("through the man-gate into the site (>= 1.0 m)", [MAN_GATE_IN], 0.5, 60.0)


# --- throws ---------------------------------------------------------------------------------------------------------

func _rt_throws() -> bool:
	if not await _rt_launch({&"escape": [&"esc_heli_roof"]}):
		return false
	var e3: SecureZone = _secure_zone_near(E3_AT)
	var ok: bool = true
	for spot: Array in THROW_SPOTS:
		var label: String = spot[0]
		var rule: String = spot[3]
		var stand: Vector3 = spot[1]
		var aim: Vector3 = spot[2]
		if rule == "e3":
			if e3 == null or e3.global_position.distance_to(E3_AT) > 8.0:
				_row(label, "FAIL", "no secure zone near E3 %s" % Po5Pilot._v(E3_AT), "C map / A escape")
				ok = false
				continue
			aim = e3.global_position
		if rule == "grade" and not await _site_in():
			ok = false
			continue
		if not await _throw_route(rule):
			_row(label, "FAIL", "throw stand's floor not reached", _owner_for(stand if stand != Vector3.INF else aim))
			ok = false
			continue
		for loot: StringName in [LOOT_MEDIUM, LOOT_HEAVY]:
			var reach: float = Tweak.crew().bag_throw_distance_m[Enums.LootWeight.HEAVY if loot == LOOT_HEAVY
				else Enums.LootWeight.MEDIUM] if rule == "e3" else 0.0
			for pitch: float in THROW_PITCHES:
				var st: Vector3 = stand
				if rule == "e3":
					st = _open_stand(aim, reach * 0.6, e3)
					if st == Vector3.INF:
						_row("%s %s" % [label, loot], "FAIL", "no open stand %.1f m from the zone" % (reach * 0.6),
							"C map")
						ok = false
						break
				var verdict: String = await _throw_at(label, st, aim, loot, pitch, rule, e3)
				ok = ok and verdict.begins_with("OK")
		await shot("throws_%s" % rule)
	return ok


## Walk to the floor a throw spot is on.
func _throw_route(rule: String) -> bool:
	match rule:
		"cpg":
			return await _go(Vector3(13.0, 0.0, -30.0), 0.6, 180.0)
		"trench":
			return await _go(Vector3(45.0, 0.0, -12.8), 0.6, 180.0)
		"forecourt":
			return await _leg("to Deck 2 by stair A", [STAIR_A_OUT[0]] + STAIR_A.slice(0, 3) + [STAIR_A_OUT[1]], 0.5,
				180.0)
		"e3":
			return await _leg("to the roof by stair A", [STAIR_A[2], STAIR_A[3], STAIR_A[4], STAIR_A[5],
				STAIR_A_OUT[2]], 0.5, 180.0)
		"grade":
			return await _leg("to F1 by the scaffold stair", SCAFFOLD.duplicate(), 0.5, 180.0)
	return false


## One throw: from `stand` (and 0.8 / 1.6 m back of it while the bag bounces back off the barrier), toward `aim`.
func _throw_at(label: String, stand: Vector3, aim: Vector3, loot: StringName, pitch: float, rule: String,
		e3: SecureZone) -> String:
	var dir: Vector3 = Vector3(aim.x - stand.x, 0.0, aim.z - stand.z).normalized()
	var verdict: String = "?"
	var r: Dictionary = {}
	for back: float in THROW_BACKS:
		var st: Vector3 = pilot.stand_point(stand - dir * back)
		if not await _go(st, 0.3, 120.0):
			verdict = "FAIL stand %s not reached" % Po5Pilot._v(st)
			break
		if await _get_bag(loot) == null:
			verdict = "FAIL no bag"
			break
		await _go(st, 0.25, 10.0)
		r = await _throw(aim, pitch)
		verdict = _throw_verdict(rule, r, stand, e3)
		_throw_note("%s %s %+.0f deg from %.1f m back" % [label, loot, pitch, back], r, verdict)
		if not verdict.begins_with("FAIL bounced"):
			break
	var owner: String = "-" if verdict.begins_with("OK") else "C map (barrier / ledge)"
	_row("%s %s %+.0f deg" % [label, String(loot).get_slice(".", 1), pitch], "PASS" if verdict.begins_with("OK")
		else "FAIL", "%s; rests %s on %s (%.1f m)" % [verdict, Po5Pilot._v(r.get("rest", Vector3.ZERO)),
		r.get("under", "-"), float(r.get("dist", 0.0))], owner)
	if not verdict.begins_with("OK"):
		await shot("throw_bad")
	return verdict


func _throw_verdict(rule: String, r: Dictionary, stand: Vector3, _e3: SecureZone) -> String:
	if not bool(r.get("ok", false)):
		return "FAIL no throw"
	var p: Vector3 = r.get("rest", Vector3.ZERO)
	match rule:
		"cpg":
			if p.x > 16.3 and p.y < 0.6:
				return "OK in the west bays (%.1f m inside the barrier)" % (p.x - 16.2)
			if p.x < 16.0 and p.y < 0.6:
				return "FAIL bounced back off the barrier onto the sidewalk"
			return "FAIL caught at y %.2f (the barrier)" % p.y
		"trench":
			if p.z > -10.8 and p.y < -0.8:
				return "OK in the trench (y %.1f)" % p.y
			if p.z < -10.9 and p.y < 0.6:
				return "FAIL bounced back off the railing onto the forecourt"
			return "FAIL caught at y %.2f, z %.2f (railing / retaining wall top)" % [p.y, p.z]
		"forecourt":
			if p.z > -14.0 and p.y < 0.6:
				return "OK on the forecourt / street (z %.1f)" % p.z
			if absf(p.y - 3.5) < 0.6 and p.z < -14.2:
				return "FAIL bounced back off the barrier onto Deck 2"
			return "FAIL caught at y %.2f (barrier / ledge / awning)" % p.y
		"e3":
			if bool(r.get("secured", false)):
				return "OK secured in the E3 hover zone"
			return "FAIL not secured (rests %.1f m from the zone)" % _zone_dist(p, _e3) if _e3 != null else "FAIL"
		"grade":
			var outside: bool = p.z > -29.9 or p.z < -50.1 or p.x < -50.1 or p.x > -25.9
			if p.y < 0.6 and outside:
				return "OK at grade, %.1f m from the edge" % pilot.flat_dist(p, stand)
			if absf(p.y - 3.5) < 0.6:
				return "FAIL bounced back off the edge protection onto F1"
			return "FAIL caught at y %.2f (toe board / scaffold / ledge)" % p.y
	return "FAIL unknown rule"


# --- underpass ------------------------------------------------------------------------------------------------------

func _rt_underpass() -> bool:
	if not await _rt_launch():
		return false
	var ok: bool = true
	for z: float in UNDERPASS_LANES:
		var lane: String = "carriageway" if z == 0.0 else ("north sidewalk" if z < 0.0 else "south sidewalk")
		if not await _leg("junction -> west mouth (%s)" % lane, [Vector3(UNDERPASS_WEST_X, 0.0, z)], 0.6, 240.0):
			ok = false
			continue
		ok = await _straight("ramp down + under the bridge (%s)" % lane, Vector3(85.0, -5.0, z), 60.0) and ok
		ok = await _straight("east cut to its end (%s)" % lane, Vector3(UNDERPASS_EAST_X, -5.0, z), 30.0) and ok
		if z == 0.0:
			await shot("underpass_east_end")
		ok = await _straight("east end -> back up the ramp (%s)" % lane, Vector3(UNDERPASS_WEST_X, 0.0, z), 90.0) and ok
	ok = await _leg("underpass spawn row (71, -5, -9.3) on foot", [Vector3(73.0, -5.0, -9.3)], 0.6, 120.0) and ok
	return ok


# --- kerbs ----------------------------------------------------------------------------------------------------------

func _rt_kerbs() -> bool:
	if not await _rt_launch():
		return false
	var ok: bool = true
	for kl: Array in KERB_LINES:
		var label: String = kl[0]
		var a: Vector3 = kl[1]
		var b: Vector3 = kl[2]
		var steps: PackedStringArray = _height_steps(a, b)
		var worst: float = 0.0
		for s: String in steps:
			worst = maxf(worst, absf(s.get_slice("@", 0).to_float()))
		_row("%s: height profile" % label, "FAIL" if worst > KERB_MAX_M + 0.005 else "PASS",
			"steps > 0.02 m: %s" % (", ".join(steps) if not steps.is_empty() else "none"),
			"C map" if worst > KERB_MAX_M + 0.005 else "-")
		ok = ok and worst <= KERB_MAX_M + 0.005
		if not await _leg("%s: to the start" % label, [a], 0.4, 240.0):
			ok = false
			continue
		ok = await _straight("%s: straight W" % label, b, 40.0) and ok
	return ok


## Height changes along a -> b sampled every 0.05 m from above ("<dy>@<x,z>").
func _height_steps(a: Vector3, b: Vector3) -> PackedStringArray:
	var space: PhysicsDirectSpaceState3D = pilot.crew.get_world_3d().direct_space_state
	var out: PackedStringArray = PackedStringArray()
	var n: int = int(a.distance_to(b) / 0.05)
	var last: float = NAN
	for i: int in n + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0,
			p + Vector3.DOWN * 2.0, 1)
		q.exclude = [pilot.crew.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var y: float = (hit["position"] as Vector3).y
		if not is_nan(last) and absf(y - last) > 0.02:
			out.append("%+.3f@(%.2f, %.2f) %s" % [y - last, p.x, p.z, (hit["collider"] as Node).name])
		last = y
	return out


# --- escapes --------------------------------------------------------------------------------------------------------

func _rt_escapes() -> bool:
	if not await _rt_launch():
		return false
	var ok: bool = true
	ok = await _leg("plaza spawn -> E1 (west aisle)", [E1_AT], 1.0, 240.0) and ok
	ok = _clear_round("E1", E1_AT) and ok
	ok = await _leg("E1 -> E2 (east cut)", [E2_AT], 1.0, 300.0) and ok
	ok = _clear_round("E2", E2_AT) and ok
	await shot("e2")
	ok = await _leg("E2 -> E3 (roof pad, by stair A)", [STAIR_A_OUT[0]] + STAIR_A.duplicate() + [E3_AT], 1.0,
		300.0) and ok
	ok = _clear_round("E3", E3_AT) and ok
	await shot("e3")
	ok = await _leg("E3 -> head house B (step-free)", [HH_B_IN], 0.5, 120.0) and ok
	ok = await _leg("head house B -> E3", [E3_AT], 1.0, 120.0) and ok
	ok = await _leg("E3 -> head house A (step-free)", [HH_A_IN], 0.5, 120.0) and ok
	ok = await _leg("head house A -> E3", [E3_AT], 1.0, 120.0) and ok
	return ok


## §7.14: >= 1.0 m clear all round the escape point at knee and chest height (8 headings).
func _clear_round(label: String, at: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = pilot.crew.get_world_3d().direct_space_state
	var p: Vector3 = pilot.stand_point(at)
	var blocked: PackedStringArray = PackedStringArray()
	for k: int in 8:
		var a: float = TAU * float(k) / 8.0
		for h: float in [0.4, 1.2]:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * h,
				p + Vector3.UP * h + Vector3(sin(a), 0.0, cos(a)) * 1.0, 1)
			q.exclude = [pilot.crew.get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				blocked.append("%d deg h%.1f %s" % [roundi(rad_to_deg(a)), h, (hit["collider"] as Node).name])
	_row("%s: >= 1.0 m clear all round %s" % [label, Po5Pilot._v(p)], "PASS" if blocked.is_empty() else "NOTE",
		", ".join(blocked) if not blocked.is_empty() else "clear (8 headings, knee + chest)", "-" if blocked.is_empty()
		else "C map (the van itself may be one)")
	return true


# --- fences ---------------------------------------------------------------------------------------------------------

func _rt_fences() -> bool:
	if not await _rt_launch():
		return false
	var ok: bool = true
	for run: Array in HOARDING_RUNS:
		var hits: PackedStringArray = _standable_near(run[1], run[2])
		_row("hoarding %s: standable >= %.1f m within %.1f m of the face" % [run[0], STANDABLE_MIN_M, STANDABLE_PROBE_M],
			"FAIL" if not hits.is_empty() else "PASS", ", ".join(hits.slice(0, 8)) if not hits.is_empty() else "none",
			"C map" if not hits.is_empty() else "-")
		ok = ok and hits.is_empty()
	for jt: Array in JUMP_TRIES:
		var label: String = jt[0]
		var stand: Vector3 = jt[1]
		var dir: Vector3 = jt[2]
		if label.contains("inside the site") and not await _site_in():
			ok = false
			continue
		if label.contains("rail lane") and pilot.crew.global_position.x < 52.0:
			if not await _leg("car park -> rail lane by the fire door", [FIRE_DOOR_IN, RAIL_LANE_IN], 0.5, 300.0):
				ok = false
				continue
		ok = await _jump_try(label, stand, dir) and ok
	return ok


## Standable tops (a downward ray hit >= STANDABLE_MIN_M above grade and below the 2.4 m fence top) within
## STANDABLE_PROBE_M of either face of the run a -> b, every 0.25 m.
func _standable_near(a: Vector3, b: Vector3) -> PackedStringArray:
	var space: PhysicsDirectSpaceState3D = pilot.crew.get_world_3d().direct_space_state
	var out: PackedStringArray = PackedStringArray()
	var along: Vector3 = (b - a).normalized()
	var side: Vector3 = Vector3(-along.z, 0.0, along.x)
	var n: int = int(a.distance_to(b) / 0.25)
	for i: int in n + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		for s: float in [-1.0, 1.0]:
			for d: float in [0.25, STANDABLE_PROBE_M]:
				var c: Vector3 = p + side * s * d
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(c + Vector3.UP * 2.3,
					c + Vector3.DOWN * 0.5, 1)
				var hit: Dictionary = space.intersect_ray(q)
				if hit.is_empty():
					continue
				var y: float = (hit["position"] as Vector3).y
				if y >= STANDABLE_MIN_M and (hit["normal"] as Vector3).y > 0.7:
					out.append("%.2f m @(%.1f, %.1f) %s" % [y, c.x, c.z, (hit["collider"] as Node).name])
	return out


## Walk up to the fence at `stand`, face `dir`, hold W and jump 4 times: the crew must stay on its side.
func _jump_try(label: String, stand: Vector3, dir: Vector3) -> bool:
	if not await _go(stand, 0.4, 300.0):
		_row("jump: " + label, "FAIL", "stand %s not reached" % Po5Pilot._v(stand), _owner_for(stand))
		return false
	var side0: float = (pilot.crew.global_position - stand).dot(dir)
	await pilot.face(pilot.crew.eye_position() + dir * 5.0, 0.03, 1.5)
	var top: float = pilot.crew.global_position.y
	pilot.inp.press(&"move_forward")
	for _k: int in 4:
		await pilot.inp.tap(&"jump")
		for _f: int in 30:
			await pilot.tick()
			top = maxf(top, pilot.crew.global_position.y)
	pilot.inp.release(&"move_forward")
	await wait_s(0.5)
	var over: bool = (pilot.crew.global_position - stand).dot(dir) > side0 + 0.8
	_row("jump: " + label, "FAIL" if over else "PASS", "%s; feet peaked %.2f m above the stand, ended %s" % [
		"GOT OVER" if over else "stayed on its side", top - stand.y, Po5Pilot._v(pilot.crew.global_position)],
		"C map" if over else "-")
	if over:
		await shot("jump_over")
	return not over


# --- Truck phase (RT-P1 part 2: needs A's RT mission + C's trucks, trunk r275+) ---------------------------------------
# Stated shortcuts on top of the above: NPCs are KEPT up to the stop (the convoy, its escort, the ambush) with the crew
# stealth_hidden (timing / geometry, not stealth; the setup test alone runs with real detection). Once the stop is
# logged, NPCs are despawned (HeistRuntime.isolate_npc) every second so the breach rows test interaction and geometry,
# not combat. Device waits (saw, burn, convoy ETA) run at Engine.time_scale DEVICE_SCALE; walks run at 1.0.

## Plaza -> the man-gate -> the SignalRig hack -> wait for the stop: clean (rigged, no alarm) or crash (3 shots at once).
func _rt_ambush_clean() -> bool:
	return await _ambush_test(true, &"route_north")


func _rt_ambush_crash() -> bool:
	return await _ambush_test(false, &"route_north")


## T1 (cash) by the placed saw, T2 (bullion) by the thermite bag from the tool store, T3 by C4; north, clean stop.
func _rt_breach() -> bool:
	if not await _truck_launch(&"route_north", {&"site_stores": [&"stores_both"], &"truck_count": [&"trucks_3"]}):
		return false
	if not await _stop(true):
		return false
	_clear_npcs()
	var trucks: Array[ArmoredTruck] = _trucks()
	if trucks.size() < 2:
		return await _fail("%d trucks" % trucks.size())
	var ok: bool = await _saw_truck(trucks[0])
	ok = await _thermite_truck(trucks[1]) and ok
	if trucks.size() >= 3 and _nearest("ItemPickup", MAGAZINE_BOXES_AT, 3.0) != null:
		ok = await _c4_truck(trucks[2]) and ok
	else:
		_c4_row(trucks)
	_mixer_row()
	# The cargo: a T1 bag on foot to E1.
	ok = await _carry_to_escape("T1 cargo -> E1", trucks[0], E1_AT, LOOT_MEDIUM, true) and ok
	return ok


## T3 by C4 alone (north clean, trucks_3, stores_c4), then a bag of its cargo on foot to E1.
func _rt_c4() -> bool:
	if not await _truck_launch(&"route_north", {&"site_stores": [&"stores_c4"], &"truck_count": [&"trucks_3"]}):
		return false
	if not await _stop(true):
		return false
	_clear_npcs()
	var trucks: Array[ArmoredTruck] = _trucks()
	if trucks.size() < 3:
		return await _fail("%d trucks" % trucks.size())
	var ok: bool = await _c4_truck(trucks[2])
	return await _carry_to_escape("T3 cargo -> E1", trucks[2], E1_AT, LOOT_HEAVY, true) and ok


## East, clean: a HEAVY bag from T1 to E1, then (a second launch) from T3 to E2.
func _rt_east_e1() -> bool:
	if not await _truck_launch(&"route_east", {&"escape": [&"esc_van_carpark"]}):
		return false
	if not await _stop(true):
		return false
	_clear_npcs()
	var trucks: Array[ArmoredTruck] = _trucks()
	if trucks.is_empty():
		return await _fail("no trucks")
	return await _carry_to_escape("T1 -> E1 with a HEAVY bag (east, clean)", trucks[0], E1_AT, LOOT_HEAVY, false)


func _rt_east_e2() -> bool:
	if not await _truck_launch(&"route_east", {&"escape": [&"esc_van_underpass"], &"truck_count": [&"trucks_3"]}):
		return false
	if not await _stop(true):
		return false
	_clear_npcs()
	var trucks: Array[ArmoredTruck] = _trucks()
	if trucks.size() < 3:
		_row("T3 present (trucks_3 forced)", "FAIL", "%d trucks" % trucks.size(), "A mission / C convoy")
		return false
	return await _carry_to_escape("T3 -> E2 with a HEAVY bag (east, clean)", trucks[2], E2_AT, LOOT_HEAVY, false)


## Setup timing from each spawn: walk (unmasked, REAL detection, NPCs in) to the man-gate, pick it, hack the rig; logs
## the heist time of each step against the convoy ETA and every observer's peak D-128 fill.
func _rt_setup() -> bool:
	var ok: bool = true
	for sp: StringName in [&"", RT_SPAWN_CARPARK, RT_SPAWN_UNDERPASS]:
		var label: String = "plaza" if sp == &"" else String(sp).trim_prefix("preplan_spawn_")
		_peaks.clear()
		var f: Dictionary = RT_FORCE.duplicate(true)
		f[&"controller"] = [&"ctrl_open"]
		var pre: Dictionary = {"force_variants": f}
		if sp != &"":
			pre["spawn_tag"] = sp
		if not await _launch(RT_HEIST, _seed if _seed >= 0 else RT_SEED, Enums.Difficulty.ROUTINE,
				{"preplan": pre, "skip_casing": true}, false):
			return false
		var m: RollingThunderMission = rt.mission as RollingThunderMission
		var eta: float = m._eta_s if m != null else -1.0
		var t_gate: float = -1.0
		var t_rig: float = -1.0
		if await _site_in():
			t_gate = rt.heist_time_s
			if await _hack_rig():
				t_rig = rt.heist_time_s
		_peaks_table()
		var worst: float = 0.0
		for id: int in _peaks:
			worst = maxf(worst, float(_peaks[id]["max"]))
		var good: bool = t_rig > 0.0 and t_rig < eta and _alarm == &"" and worst < 1.0
		var fmt: String = "gate t=%.1f, rig hacked t=%.1f, ETA %.0f s (%.0f s spare), alarm '%s', %d observers, peak %.2f"
		_row("setup from %s spawn" % label, "PASS" if good else "FAIL", fmt % [
			t_gate, t_rig, eta, eta - t_rig, _alarm, _peaks.size(), worst], "-" if good else "C map / A mission")
		ok = ok and good
	return ok


# --- truck helpers ----------------------------------------------------------------------------------------------------

func _track_rover_hall() -> void:
	pass  # OF only


func _truck_launch(route: StringName, force: Dictionary) -> bool:
	var f: Dictionary = RT_FORCE.duplicate(true)
	f[&"convoy_route"] = [route]
	f[&"controller"] = [&"ctrl_open"]
	for k: Variant in force:
		f[k] = force[k]
	if not await _launch(RT_HEIST, _seed if _seed >= 0 else RT_SEED, Enums.Difficulty.ROUTINE,
			{"preplan": {"force_variants": f}, "skip_casing": true}, false):
		return false
	pilot.crew.stealth_hidden = true
	note("SHORTCUT truck phase: NPCs in, crew stealth_hidden until the stop")
	return true


func _mission() -> RollingThunderMission:
	return rt.mission as RollingThunderMission


## Clean: man-gate, rig hack, wait by the route, mask once stopped. Crash: mask and 3 shots at once, wait.
func _stop(clean: bool) -> bool:
	var m: RollingThunderMission = _mission()
	if m == null:
		return await _fail("no RollingThunderMission")
	var wait_at: Vector3 = WAIT_NORTH if m._route() == "north" else WAIT_EAST
	if clean:
		if not await _site_in() or not await _hack_rig():
			return await _fail("signals")
		if not await _go(MAN_GATE_OUT, 0.5, 60.0) or not await _go(wait_at, 0.8, 240.0):
			return await _fail("wait spot")
	else:
		await _mask()
		await pilot.face(pilot.crew.eye_position() + Vector3(0.0, 4.0, -6.0), 0.05, 1.5)
		for _k: int in 3:
			await pilot.inp.tap(&"fire")
			await wait_s(0.3)
		note("crash: 3 shots fired, alarm '%s', mission alerted %s" % [_alarm, m.alerted])
		await _go(wait_at, 0.8, 240.0)
	var t_wait: float = rt.heist_time_s
	Engine.time_scale = DEVICE_SCALE
	var stopped: bool = await wait_until(func() -> bool: return m._stop_done, 400.0 / DEVICE_SCALE + 60.0)
	Engine.time_scale = 1.0
	_row("%s stop (%s)" % ["clean" if clean else "crash", m._route()], "PASS" if stopped and m.clean_stop == clean
		else "FAIL", "stopped %s at t=%.1f (ETA %.0f, waited %.0f s), layout '%s', clean_stop %s, signals_rigged %s, alerted %s, alarm '%s'" % [
		stopped, rt.heist_time_s, m._eta_s, rt.heist_time_s - t_wait, m.layout_id, m.clean_stop, m.signals_rigged,
		m.alerted, _alarm], "-" if stopped and m.clean_stop == clean else "A mission")
	await shot("stop_%s" % ("clean" if clean else "crash"))
	if not stopped:
		return false
	if clean:
		await _mask()
		var sprung: bool = await wait_until(func() -> bool: return rt.went_loud, 20.0)
		_row("clean stop: the ambush springs (window +8 s)", "PASS" if sprung else "FAIL", "loud %s at t=%.1f" % [
			rt.went_loud, rt.heist_time_s], "-" if sprung else "A mission")
	# Every truck's lock reachable on foot (rear step, >= 1.0 m clear behind, §7.8).
	for t: ArmoredTruck in _trucks():
		var use: Vector3 = pilot.stand_point(_truck_use(t))
		var path: PackedVector3Array = pilot.nav_path(use)
		var reach: bool = not path.is_empty() and pilot.flat_dist(path[path.size() - 1], _truck_use(t)) < 0.6
		_row("%s rear UsePoint reachable (%s)" % [_truck_name(t), m.layout_id], "PASS" if reach else "FAIL",
			"use %s, nav end %s" % [Po5Pilot._v(_truck_use(t)), Po5Pilot._v(path[path.size() - 1]) if not path.is_empty()
			else "-"], "-" if reach else "C convoy layout / A nav")
	return true


func _ambush_test(clean: bool, route: StringName) -> bool:
	if not await _truck_launch(route, {}):
		return false
	var ok: bool = await _stop(clean)
	_clear_npcs()
	if ok:
		_mixer_row()
	return ok


## Real detection (the setup rows): like a human, hold unmasked on the sidewalk until no guard with a line of sight is
## within UNSEEN_GUARD_M or closing (two samples 0.5 s apart), and no civilian with a line of sight within
## UNSEEN_CIV_M, for UNSEEN_HOLD_S running. One ROW with the wait.
func _wait_unseen(label: String, max_s: float = 240.0) -> float:
	var t0: float = rt.heist_time_s
	var clear_s: float = 0.0
	var last: Dictionary = {}
	while rt.heist_time_s - t0 < max_s and clear_s < UNSEEN_HOLD_S:
		var why: String = ""
		for n: Node in rt.npcs():
			var npc: NpcBase = n as NpcBase
			var d: float = npc.global_position.distance_to(pilot.crew.global_position)
			var seen: bool = pilot.has_los(npc.head_position(), npc)
			if npc.role == &"civilian":
				if seen and d < UNSEEN_CIV_M:
					why = "civilian %.0f m" % d
			elif d < UNSEEN_GUARD_M and (seen or d < float(last.get(npc, INF)) - 0.2):
				why = "%s %.0f m%s" % [npc.role, d, "" if seen else " closing"]
			last[npc] = d
			if why != "":
				break
		clear_s = clear_s + 0.5 if why == "" else 0.0
		await wait_s(0.5)
	var waited: float = rt.heist_time_s - t0
	_row("%s: wait unseen before masking" % label, "PASS" if clear_s >= UNSEEN_HOLD_S else "FAIL", "%.0f s" % waited,
		"-" if clear_s >= UNSEEN_HOLD_S else "C patrol (no window)")
	return waited


func _hack_rig() -> bool:
	var rig: Node3D = _nearest("HackTerminal", SIGNAL_RIG_AT, 2.0)
	if rig == null:
		_row("SignalRig", "FAIL", "no HackTerminal near %s" % Po5Pilot._v(SIGNAL_RIG_AT), "C map")
		return false
	var m: RollingThunderMission = _mission()
	var t0: float = rt.heist_time_s
	var comp: InteractableComponent = _comp(rig)
	var ht: HackTerminal = rig as HackTerminal
	var restarts: int = 0
	await pilot.use(comp, 60.0, func() -> bool: return m.signals_rigged or (ht != null and ht.state != HackTerminal.State.IDLE))
	# Interruptions (HackTerminal: kind restart_hack, no auto-restart) need F again, as a player would.
	while not m.signals_rigged and rt.heist_time_s - t0 < 120.0:
		if comp.kind == &"restart_hack":
			restarts += 1
			await pilot.use(comp, 30.0, func() -> bool: return comp.kind != &"restart_hack")
		await wait_s(0.5)
	_row("SignalRig hack (15 s)", "PASS" if m.signals_rigged else "FAIL", "%.1f s from F, %d restart(s), signals_rigged %s%s" % [
		rt.heist_time_s - t0, restarts, m.signals_rigged, (", paused %s" % ht.pause_reasons()) if ht != null
		and ht.is_paused() else ""], "-" if m.signals_rigged else "A hack / C placement")
	return m.signals_rigged


func _clear_npcs() -> void:
	rt.isolate_npc(null)
	pilot.crew.stealth_hidden = true
	note("SHORTCUT NPCs despawned after the stop (breach rows test interaction, not combat)")
	_quiet_loud.call_deferred()


func _quiet_loud() -> void:
	var my_rt: HeistRuntime = rt
	while is_inside_tree() and rt == my_rt and is_instance_valid(rt):
		if not rt.npcs().is_empty():
			rt.isolate_npc(null)
		await wait_s(1.0)


func _trucks() -> Array[ArmoredTruck]:
	var out: Array[ArmoredTruck] = []
	var m: RollingThunderMission = _mission()
	if m != null and not m._trucks.is_empty():
		out.assign(m._trucks)
	else:
		for n: Node in get_tree().get_nodes_in_group(ArmoredTruck.GROUP):
			if (n as Node3D).is_visible_in_tree():
				out.append(n as ArmoredTruck)
	out.sort_custom(func(a: ArmoredTruck, b: ArmoredTruck) -> bool: return _truck_name(a) < _truck_name(b))
	return out


static func _truck_name(t: ArmoredTruck) -> String:
	return String(t.get_parent().name) if t.get_parent() != null else String(t.name)


## The rear UsePoint (truck local (-1.8, 0, rear - 0.5), rt_gameplay._convoy_truck) or the interactable's own.
func _truck_use(t: ArmoredTruck) -> Vector3:
	var c: InteractableComponent = _comp(t)
	if c != null and c.has_method(&"use_point_position"):
		return c.call(&"use_point_position")
	var up: Node3D = t.get_node_or_null("UsePoint") as Node3D
	return up.global_position if up != null else t.global_position


## The placed saw on `t`: F on the truck's lock (place_saw), then wait out the run, fixing jams (fix_drill).
func _saw_truck(t: ArmoredTruck) -> bool:
	# r278: the saw goes on the rear doors' SawPoint (a SAW drill_point child); before that, the truck's own lock.
	var sp: Node = t.get_node_or_null("SawPoint")
	var comp: InteractableComponent = _comp(sp) if sp != null else _comp(t)
	if comp == null:
		_row("%s saw" % _truck_name(t), "FAIL", "no interactable", "A truck")
		return false
	var k0: StringName = comp.kind
	note("saw: on %s, kind %s" % ["SawPoint" if sp != null else "the truck lock", k0])
	var t0: float = rt.heist_time_s
	var placed: bool = await pilot.use(comp, 60.0, func() -> bool: return t.opened or comp.kind != k0)
	note("saw: placed %s, kind now %s" % [placed, comp.kind])
	await shot("saw_placed")
	var jams: int = 0
	var t_end: float = rt.heist_time_s + 400.0
	Engine.time_scale = DEVICE_SCALE
	while not t.opened and rt.heist_time_s < t_end:
		if comp.kind == &"fix_drill":
			Engine.time_scale = 1.0
			jams += 1
			await pilot.use(comp, 30.0, func() -> bool: return comp.kind != &"fix_drill")
			Engine.time_scale = DEVICE_SCALE
		await wait_s(0.5)
	Engine.time_scale = 1.0
	_row("%s (%s) by the placed saw" % [_truck_name(t), "locked down" if t.locked_down else "no lockdown"],
		"PASS" if t.opened else "FAIL", "placed %s, opened %s after %.0f s heist time, %d jam(s) fixed" % [placed,
		t.opened, rt.heist_time_s - t0, jams], "-" if t.opened else "A truck / C rear step")
	await shot("saw_open")
	return t.opened


## Lockpick the tool store, carry the thermite bag to `t`'s BurnPoint (sibling `Thermite`), F, wait out the burn.
func _thermite_truck(t: ArmoredTruck) -> bool:
	var bp: Node3D = t.get_parent().get_node_or_null("Thermite") as Node3D
	if bp == null:
		_row("%s thermite" % _truck_name(t), "FAIL", "no Thermite BurnPoint beside the truck", "C convoy")
		return false
	var t0: float = rt.heist_time_s
	if not await _site_in():
		return false
	var door: Door = _door_near(TOOL_STORE_DOOR_AT, 1.5)
	if door != null and not door.is_open:
		await pilot.use(_comp(door), 60.0, func() -> bool: return door.is_open)
	var ls: Node3D = _nearest("LootSpawn", THERMITE_BAG_AT, 2.0)
	var got: bool = ls != null and await pilot.use(_comp(ls), 40.0, func() -> bool: return pilot.crew.is_carrying_bag())
	_row("thermite bag from the tool store (lockpick)", "PASS" if got else "FAIL", "door open %s, %.0f s" % [
		door != null and door.is_open, rt.heist_time_s - t0], "-" if got else "C map / A loot")
	if not got:
		return false
	var t1: float = rt.heist_time_s
	if not await _go(MAN_GATE_IN, 0.5, 120.0) or not await _go(MAN_GATE_OUT, 0.5, 60.0):
		_row("thermite bag out of the site", "FAIL", "at %s" % Po5Pilot._v(pilot.crew.global_position), "C map")
		return false
	var bcomp: InteractableComponent = _comp(bp)
	var placed: bool = bcomp != null and await pilot.use(bcomp, 90.0, func() -> bool: return (bcomp.kind != &"place_thermite"
		or not pilot.crew.is_carrying_bag()))
	_row("%s thermite carried and placed" % _truck_name(t), "PASS" if placed else "FAIL", "%.0f s carry from the tool store, placed %s" % [
		rt.heist_time_s - t1, placed], "-" if placed else "A burn_point / C placement")
	var t2: float = rt.heist_time_s
	Engine.time_scale = DEVICE_SCALE
	await wait_until(func() -> bool: return t.opened, 120.0 / DEVICE_SCALE + 20.0)
	Engine.time_scale = 1.0
	_row("%s by thermite" % _truck_name(t), "PASS" if t.opened else "FAIL", "opened %s %.0f s after placing" % [
		t.opened, rt.heist_time_s - t2], "-" if t.opened else "A burn_point")
	await shot("thermite_open")
	return t.opened


func _c4_row(trucks: Array[ArmoredTruck]) -> void:
	var boxes: int = 0
	for n: Node in rt.find_children("C4Box*", "", true, false):
		if n is Node3D and (n as Node3D).is_visible_in_tree() and _comp(n) != null:
			boxes += 1
	# LEAD r276: C's item_pickup C4 boxes (d6c8b99a) are held from trunk until r277.
	_row("C4 source on the map (magazine C4 boxes, stores_c4)", "PASS" if boxes > 0 else "BLOCKED: C r277",
		"%d C4 boxes with an interactable; trucks offer c4 once 4 x item.c4 are carried (%d trucks)" % [boxes,
		trucks.size()], "-" if boxes > 0 else "A5-03 (A) / C markers")


func _mixer_row() -> void:
	var gates: PackedStringArray = PackedStringArray()
	for nm: String in ["SiteTanneryGateW", "SiteTanneryGateE"]:
		var d: Door = rt.find_child(nm, true, false) as Door
		gates.append("%s %s" % [nm, "missing" if d == null else ("open" if d.is_open else ("locked" if d.locked
			else "closed"))])
	var mixer: Node3D = rt.find_child("MixerTruck", true, false) as Node3D
	var passable: bool = gates.size() > 0 and ", ".join(gates).contains("open")
	# LEAD r276: mixer phase 2 (C's Mixer / MixerStop / gates) is held from trunk until r277.
	_row("the mixer leaves / the Tannery gate passable (§7.6, QC-RT1)", "PASS" if passable else "BLOCKED: C r277",
		"%s; MixerTruck at %s; layout '%s'" % [", ".join(gates), Po5Pilot._v(mixer.global_position) if mixer != null
		else "-", _mission().layout_id], "-" if passable else "A mission (_mixer_move layouts) / C map")


## Carry a bag of `loot` from `t`'s rear step to the escape at `esc`: real cargo when the truck is open, else
## (SHORTCUT) LootManager.spawn_bag at the step. Drop it in the secure zone (G at the zone edge).
func _carry_to_escape(item: String, t: ArmoredTruck, esc: Vector3, loot: StringName, cargo: bool) -> bool:
	var use: Vector3 = pilot.stand_point(_truck_use(t))
	if not await _go(use, 0.5, 240.0):
		_row(item, "FAIL", "truck rear not reached", _owner_for(use))
		return false
	var lb: LootBag = _bag_near(use, 3.0) if cargo else null
	if lb != null:
		await pilot.use(_comp(lb), 20.0, func() -> bool: return pilot.crew.is_carrying_bag())
	if not pilot.crew.is_carrying_bag() and await _get_bag(loot) == null:
		_row(item, "FAIL", "no bag", "-")
		return false
	var zone: SecureZone = _secure_zone_near(esc)
	if zone == null or zone.global_position.distance_to(esc) > 10.0:
		_row(item, "FAIL", "no secure zone near %s" % Po5Pilot._v(esc), "A escape / C map")
		return false
	var t0: float = rt.heist_time_s
	var s0: int = pilot.stuck_spots.size()
	var path_m: float = 0.0
	var p: PackedVector3Array = pilot.nav_path(zone.global_position)
	for k: int in range(1, p.size()):
		path_m += p[k - 1].distance_to(p[k])
	var ok: bool = await _go(pilot.stand_point(zone.global_position), 1.5, 400.0)
	var id: int = (pilot.crew.carried_bag as LootBag).net_id if pilot.crew.is_carrying_bag() else -1
	if ok:
		await pilot.face(zone.global_position + Vector3.UP * 0.5, 0.05, 1.5)
		await pilot.inp.tap(&"drop_bag")
		await wait_until(func() -> bool: return _secured_ids.has(id), 3.0)
	var sec: bool = _secured_ids.has(id)
	var n: int = pilot.stuck_spots.size() - s0
	_row(item, "PASS" if sec and n == 0 else ("STUCK" if sec else "FAIL"), ("%.0f s heist time over a %.0f m path, secured %s, " +
		"%d STUCK row(s), weight %s") % [
		rt.heist_time_s - t0, path_m, sec, n, "HEAVY" if loot == LOOT_HEAVY else "MEDIUM"],
		"-" if sec and n == 0 else ("C map" if n > 0 else "A secure zone"))
	await shot("carry_%s" % ("e1" if esc == E1_AT else "e2"))
	return sec


## The magazine's padlock (pick), a C4 box (F: 4 x item.c4), out of the site, F on `t`'s lock (place_c4), the fuse.
func _c4_truck(t: ArmoredTruck) -> bool:
	var t0: float = rt.heist_time_s
	if not await _site_in():
		return false
	var door: Door = _door_near(MAGAZINE_DOOR_AT, 1.5)
	var lock: Node3D = _nearest("Padlock", MAGAZINE_DOOR_AT + Vector3.UP * 1.05, 2.0)
	if door != null and not door.is_open and lock != null:
		await pilot.use(_comp(lock), 40.0, func() -> bool: return (door.is_open or not door.locked
			or _comp(lock) == null or _comp(lock).kind != &"place_saw"))
		# Loud, the padlock takes a placed saw (place_saw) instead of a pick: wait out the cut before the door.
		Engine.time_scale = DEVICE_SCALE
		await wait_until(func() -> bool: return door.is_open or not door.locked, 240.0 / DEVICE_SCALE)
		Engine.time_scale = 1.0
		if not door.is_open:
			await pilot.use(_comp(door), 20.0, func() -> bool: return door.is_open)
	_row("magazine door open (padlock %s)" % ("sawn" if rt.went_loud else "picked"), "PASS" if door != null
		and door.is_open else "FAIL", "door %s" % ("open" if door != null and door.is_open else "closed"),
		"-" if door != null and door.is_open else "A padlock / C magazine")
	if door == null or not door.is_open:
		return false
	var have: int = pilot.crew.item_count(&"item.c4")
	for _k: int in 2:
		if have >= C4_NEEDED:
			break
		var box: Node3D = _nearest("ItemPickup", MAGAZINE_BOXES_AT, 3.0)
		if box == null:
			break
		await pilot.use(_comp(box), 30.0, func() -> bool: return pilot.crew.item_count(&"item.c4") > have)
		have = pilot.crew.item_count(&"item.c4")
	_row("C4 from the magazine (padlock pick + box)", "PASS" if have >= C4_NEEDED else "FAIL", "door open %s, %d x item.c4, %.0f s" % [
		door != null and door.is_open, have, rt.heist_time_s - t0], "-" if have >= C4_NEEDED else "C magazine / A item_pickup")
	if have < C4_NEEDED:
		return false
	if not await _go(MAN_GATE_IN, 0.5, 120.0) or not await _go(MAN_GATE_OUT, 0.5, 60.0):
		return false
	var comp: InteractableComponent = _comp(t)
	var t1: float = rt.heist_time_s
	var placed: bool = comp != null and await pilot.use(comp, 60.0,
		func() -> bool: return t.opened or pilot.crew.item_count(&"item.c4") < have)
	await wait_until(func() -> bool: return t.opened, 30.0)
	_row("%s by C4 (%d charges)" % [_truck_name(t), C4_NEEDED], "PASS" if t.opened else "FAIL",
		"placed %s (kind %s), opened %s %.0f s after F" % [placed, comp.kind if comp != null else "-", t.opened,
		rt.heist_time_s - t1], "-" if t.opened else "A truck / safe c4")
	await shot("c4_open")
	return t.opened


# --- Blown setup on Hazardous (LEAD 2026-10-22, the D-154 early-alarm balance) ----------------------------------------
# REAL play, no shortcuts after the launch: Hazardous, 3 AI teammates (crew_ai), NPCs in, real detection (no
# stealth_hidden), skip_casing. The pilot masks at the plaza and fires 3 shots (the early alarm), waits out the crash
# stop crouched behind Pier-40's south face peeking to shoot (Po5Pilot.engage on the nearest visible enemy), then once
# the escort is down (or BLOWN_FIGHT_S after the stop) saws T1 at its SawPoint (holds clear threats first, Po5Pilot
# combat) and defends it crouched at its rear step until it opens, custody, or BLOWN_MAX_S.


func _rt_blown() -> bool:
	return await _hazard_run(false)


## The clean-stop counterpart (LEAD: A's bots die to the escort 20-60 s after a Hazardous clean stop). SHORTCUT: the
## whole crew is stealth_hidden for the setup (the rig hack; not under test) and masks behind Pier-40; at the stop the
## hiding comes off and the fight is real from the ambush window on.
func _rt_clean_haz() -> bool:
	return await _hazard_run(true)


func _hazard_run(clean: bool) -> bool:
	var tag: String = "clean_haz" if clean else "blown"
	var f: Dictionary = RT_FORCE.duplicate(true)
	f[&"convoy_route"] = [&"route_north"]
	f[&"controller"] = [&"ctrl_open"]
	if rt != null and is_instance_valid(rt):
		rt.teardown()
		rt = null
		await wait_s(0.5)
	var opts: Dictionary = {"preplan": {"force_variants": f}, "skip_casing": true, "ai_teammates": 3, "crew_ai": true,
		"loadouts": {0: _hazard_loadout()}}
	rt = await HeistLauncher.launch(RT_HEIST, _seed if _seed >= 0 else RT_SEED, Enums.Difficulty.HAZARDOUS, self, opts)
	if rt == null:
		return await _fail("launch")
	note("launched rolling_thunder HAZARDOUS seed %d variants %s" % [_seed if _seed >= 0 else RT_SEED, rt.variants])
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await wait_s(2.0)
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.combat = not clean  # clean: no shooting through the setup (a downed site guard's pager blows it); on at the stop
	await pilot.calibrate()
	for s: int in 4:
		var cc: Node = rt.crew_controller(s)
		if cc != null:
			_crew_ids[NetIds.of(cc)] = s
	EventBus.damage_applied.connect(_on_blown_hit)
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void: _obj_states[id] = st)
	EventBus.crew_downed.connect(func(slot: int, used: int) -> void:
		_downs[slot] = int(_downs.get(slot, 0)) + 1
		note("DOWN slot %d (downs used %d) at %s" % [slot, used, Po5Pilot._v(pilot.crew.global_position)]))
	EventBus.crew_custody.connect(func(slot: int) -> void:
		_downs["custody_%d" % slot] = true
		note("CUSTODY slot %d" % slot))
	_watch_hp.call_deferred()
	await shot("%s_spawn" % tag)
	var m: RollingThunderMission = _mission()
	if clean:
		_crew_hidden(true)
		if not await _site_in() or not await _hack_rig():
			return await _fail("signals")
		await _go(MAN_GATE_OUT, 0.5, 60.0)
		await _mask()
	else:
		# The early alarm: mask in the plaza and fire 3 shots.
		await _mask()
		await pilot.face(pilot.crew.eye_position() + Vector3(0.0, 4.0, -6.0), 0.05, 1.5)
		for _k: int in 3:
			await pilot.inp.tap(&"fire")
			await wait_s(0.3)
		await wait_until(func() -> bool: return _alarm != &"" or m.alerted, 20.0)
		_row("blown: early alarm", "PASS" if m.alerted else "FAIL", "alarm '%s' at t=%.1f, mission alerted %s" % [_alarm,
			rt.heist_time_s, m.alerted], "-" if m.alerted else "A stealth / mission")
	# Cover by Pier-40 and fight the stop from there.
	await _go(BLOWN_COVER, 0.6, 180.0)
	if clean:
		pilot.inp.press(&"crouch")
		await wait_until(func() -> bool: return m._stop_done, 400.0)
		_crew_hidden(false)
		pilot.combat = true
		_peaks.clear()
		_watch_detection.call_deferred()  # DETECT lines: who sees the pilot at the hand-over, and when
		note("clean_haz: crew hiding off at the stop (t=%.1f, clean_stop %s)" % [rt.heist_time_s, m.clean_stop])
	await _hold_cover(func() -> bool: return m._stop_done, 400.0)
	var t_stop: float = rt.heist_time_s
	var stop_ok: bool = m._stop_done and m.clean_stop == clean
	_row("%s: %s stop" % [tag, "clean" if clean else "crash"], "PASS" if stop_ok else "FAIL",
		"layout '%s' at t=%.1f (ETA %.0f)" % [m.layout_id, t_stop, m._eta_s], "-" if stop_ok else "A mission")
	await shot("%s_stop" % tag)
	await _hold_cover(func() -> bool: return _objective_done(&"escort") or rt.heist_time_s - t_stop > BLOWN_FIGHT_S,
		BLOWN_FIGHT_S + 10.0)
	var esc_fmt: String = "escort done %s at t=%.1f (%.0f s after the stop), %s"
	_row("%s: escort down from cover" % tag, "PASS" if _objective_done(&"escort") else "NOTE", esc_fmt % [
		_objective_done(&"escort"), rt.heist_time_s, rt.heist_time_s - t_stop, _downs_text()], "-")
	# T1 by the saw, defended at the rear step.
	var trucks: Array[ArmoredTruck] = _trucks()
	var opened: bool = false
	var t_open: float = -1.0
	if not trucks.is_empty() and not _in_custody():
		var lull: float = await _wait_lull(120.0)
		note("%s: left cover for T1 after a %.0f s wait for a lull (t=%.1f)" % [tag, lull, rt.heist_time_s])
		var t: ArmoredTruck = trucks[0]
		var sp: Node = t.get_node_or_null("SawPoint")
		var comp: InteractableComponent = _comp(sp) if sp != null else _comp(t)
		var k0: StringName = comp.kind
		var placed: bool = await pilot.use(comp, 120.0, func() -> bool: return t.opened or comp.kind != k0)
		note("blown: saw placed %s at t=%.1f" % [placed, rt.heist_time_s])
		var t_end: float = rt.heist_time_s + BLOWN_MAX_S
		while not t.opened and rt.heist_time_s < t_end and not _in_custody():
			if comp.kind == &"fix_drill" and pilot.crew.crew_state == Enums.CrewState.NORMAL:
				await pilot.use(comp, 60.0, func() -> bool: return comp.kind != &"fix_drill")
			elif comp.kind == k0 and not t.opened and pilot.crew.crew_state == Enums.CrewState.NORMAL:
				await pilot.use(comp, 60.0, func() -> bool: return t.opened or comp.kind != k0)  # the saw was never placed
			await _hold_cover(func() -> bool: return t.opened or comp.kind == &"fix_drill", 6.0)
		opened = t.opened
		t_open = rt.heist_time_s
	var open_fmt: String = "opened %s at t=%.1f, %s, player health min %.0f; kit corsair_ar + kestrel_p9 + heavy_vest + doctor bag, no skills"
	_row("%s: a truck opened (T1 saw, Hazardous, AI crew)" % tag, "PASS" if opened else "FAIL", open_fmt % [
		opened, t_open, _downs_text(), _hp_min], "-" if opened else "balance (D-154)")
	_danger_rows(tag)
	if clean:
		_peaks_table()
	await shot("%s_end" % tag)
	return opened


## Crouched in cover; every 0.5 s peek (stand) at the nearest visible enemy within BLOWN_PEEK_M and engage 1.5 s.
func _hold_cover(done: Callable, max_s: float) -> void:
	var t0: float = rt.heist_time_s
	while not done.call() and rt.heist_time_s - t0 < max_s and not _in_custody():
		if pilot.crew.crew_state != Enums.CrewState.NORMAL:
			await wait_s(0.5)
			continue
		var foe: NpcBase = pilot.nearest_enemy(BLOWN_PEEK_M)
		if foe != null:
			pilot.inp.release(&"crouch")
			await pilot.engage(foe, 1.5)
		else:
			pilot.inp.press(&"crouch")
			await wait_s(0.5)
		if pilot.crew.carried_bag == null and _reload_due():
			await pilot.inp.tap(&"reload")
	pilot.inp.release(&"crouch")


## A competent Hazardous loud kit (the player default is a pistol and a suit): the bots' rifle, the pistol, a heavy
## vest, a doctor bag. No skills / perk deck (stated in the rows).
func _hazard_loadout() -> Loadout:
	var lo: Loadout = Loadout.new()
	lo.primary = HAZ_PRIMARY
	lo.secondary = CombatTweak.data().default_secondary
	lo.armor = HAZ_ARMOR
	lo.deployable = HAZ_DEPLOYABLE
	return CrewWeapons.build_loadout(lo)


## Leave cover only in a lull: no visible enemy within BLOWN_PEEK_M for LULL_S running (fighting meanwhile).
func _wait_lull(max_s: float) -> float:
	var t0: float = rt.heist_time_s
	var quiet: float = 0.0
	while quiet < LULL_S and rt.heist_time_s - t0 < max_s and not _in_custody():
		if pilot.nearest_enemy(BLOWN_PEEK_M) != null:
			quiet = 0.0
			await _hold_cover(func() -> bool: return pilot.nearest_enemy(BLOWN_PEEK_M) == null, 3.0)
		else:
			quiet += 0.5
			await wait_s(0.5)
	return rt.heist_time_s - t0


func _crew_hidden(on: bool) -> void:
	for s: int in 4:
		var cc: CrewController = rt.crew_controller(s) as CrewController
		if cc != null:
			cc.stealth_hidden = on


func _reload_due() -> bool:
	var w: Variant = pilot.crew.get(&"weapon")
	if w is Object and (w as Object).get(&"mag") != null:
		return int((w as Object).get(&"mag")) <= 3
	return false


func _on_blown_hit(victim: int, attacker: int, info: Dictionary) -> void:
	if not _crew_ids.has(victim):
		return
	var who: String = _observer_name(attacker).rstrip("0123456789_")
	var apos: Vector3 = Vector3.INF
	for n: Node in rt.npcs():
		if NetIds.of(n) == attacker:
			apos = (n as Node3D).global_position
	var key: String = "%s|slot %d" % [who, int(_crew_ids[victim])]
	var row: Dictionary = _hits.get(key, {"n": 0, "dmg": 0.0, "dist": 0.0, "at": PackedStringArray()})
	row["n"] = int(row["n"]) + 1
	row["dmg"] = float(row["dmg"]) + float(info.get("amount", info.get("damage", 0.0)))
	if apos != Vector3.INF and pilot != null:
		row["dist"] = float(row["dist"]) + apos.distance_to(pilot.crew.global_position)
		if (row["at"] as PackedStringArray).size() < 4:
			(row["at"] as PackedStringArray).append(Po5Pilot._v(apos))
	_hits[key] = row


func _watch_hp() -> void:
	var my_rt: HeistRuntime = rt
	while is_inside_tree() and rt == my_rt and is_instance_valid(rt) and pilot != null:
		var h: CrewHealth = pilot.crew.health
		if h != null and h.get(&"health") != null:
			_hp_min = minf(_hp_min, float(h.get(&"health")))
		await wait_s(0.5)


func _danger_rows(tag: String) -> void:
	var keys: Array = _hits.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(_hits[a]["dmg"]) > float(_hits[b]["dmg"]))
	for k: String in keys.slice(0, 10):
		var r: Dictionary = _hits[k]
		_row("%s: danger %s" % [tag, k], "NOTE", "%d hits, %.0f damage, mean range %.0f m, from %s" % [int(r["n"]),
			float(r["dmg"]), float(r["dist"]) / maxf(float(r["n"]), 1.0), ", ".join(r["at"] as PackedStringArray)], "-")


func _downs_text() -> String:
	return "downs %s" % str(_downs) if not _downs.is_empty() else "no downs"


func _in_custody() -> bool:
	return _downs.has("custody_%d" % pilot.crew.slot)


func _objective_done(id: StringName) -> bool:
	return int(_obj_states.get(id, -1)) == Enums.ObjectiveState.COMPLETED
