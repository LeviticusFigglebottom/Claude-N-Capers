## DB-P1 (D-115 item 4): the first windowed REAL-INPUT pass of Dockside Burn (`dockside_burn`, loud only) through the
## real menus, with A's PO-5 driver (clicks, Po5Pilot input only, render loop off between screenshots).
##  1. Snag leg: the pilot walks (real input, combat on) a fixed tour of the map's main areas, the fire stair, the
##     platform stair to the mezzanine, the pontoon ramp, the quay steps and the gangway, and logs every leg it cannot
##     finish (`SNAG` rows; the pilot's own STUCK rows carry the ray hits). Harness aid, logged: the local crew's
##     health is topped up (CrewHealth.reset_full) between snag legs so a cartel volley does not end the probe.
##  2. Loud: A's auto_loud flow (objective markers, devices, bags, escape), driven step by step from here with one
##     DB-specific step in front of it: the thermite bag (loot.thermite, at the crew spawn) is fetched and carried to
##     the run's burn point (A's flow would treat it as loot and throw it in the van).
## Logs an objective TIMELINE (heist time per objective state), the snag table, downs / custody and the result.
## Same --po5-out / --po5-seed / --po5-budget / --po5-difficulty arguments as gn_pass.tscn, plus --obs-out (observer),
## --snag=0 (skip the snag leg), --snag-only, --snag-from=<label> (start the tour there), --snag-leg-s=S (per-leg
## walk timeout, default 30). The observer's frames are slow on llvmpipe: pass --obs-every=60 or more. Run (windowed):
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/db_pass.tscn -- --po5-out=/abs/dir --po5-budget=3600 [--po5-seed=N] [--obs-out=/abs/dir]
## Owner: ENV P (A's driver, pilot and flows are used unchanged).
extends "res://tests/a/e2e/po5_flow.gd"

const AUTO_LOUD: String = "res://tests/a/e2e/po5_flow_auto_loud.gd"
const THERMITE: StringName = &"loot.thermite"
## Snag tour, map coordinates (dockside_burn_layout.gd: origin at the building's NW corner, +x east, +z south; MEZZ
## +3.6, the landing stage / pontoon -1.8): [label, point]. Each point is snapped to the navmesh.
const SNAG_TOUR: Array = [
	["yard_west_alley", Vector3(8.0, 0.0, -23.8)],
	["lane_north", Vector3(-4.0, 0.0, -24.0)],
	["fire_stair_foot", Vector3(-0.8, 0.0, -1.0)],
	["fire_stair_top", Vector3(-0.8, 3.6, 5.6)],
	["lane_mid", Vector3(-4.0, 0.0, 10.0)],
	["lane_south", Vector3(-4.0, 0.0, 34.0)],
	["quay_west", Vector3(1.0, 0.0, 40.0)],
	["quay_net_store", Vector3(21.2, 0.0, 37.0)],
	["pontoon_ramp_top", Vector3(24.0, 0.0, 42.6)],
	["pontoon", Vector3(24.0, -1.8, 51.5)],
	["quay_mid", Vector3(40.0, 0.0, 40.6)],
	["quay_steps_top", Vector3(57.0, 0.0, 39.4)],
	["landing_stage", Vector3(55.0, -1.8, 46.0)],
	["apron_south", Vector3(56.0, 0.0, 14.0)],
	["dock_door_out", Vector3(49.8, 0.0, 6.8)],
	["hall_centre", Vector3(34.6, 0.0, 6.0)],
	["hall_west", Vector3(24.6, 0.0, 4.0)],
	["platform_stair_landing", Vector3(25.1, 1.8, 7.4)],
	["platform_stair_top", Vector3(20.8, 3.6, 7.25)],
	["mezz_count_room", Vector3(13.4, 3.6, 4.4)],
	["spine_mid", Vector3(33.5, 0.0, 17.0)],
	["anteroom_spine", Vector3(33.5, 0.0, 25.3)],
	["anteroom_east", Vector3(46.4, 0.0, 28.0)],
	["apron_north", Vector3(60.0, 0.0, -6.5)],
	["gangway_west", Vector3(60.4, 0.0, -13.0)],
	["pier10_apron", Vector3(78.0, 0.0, -13.0)],
	["yard_east_alley", Vector3(52.0, 0.0, -23.8)],
	["gate", Vector3(33.75, 0.0, -36.0)],
]

var _do_snag: bool = true
var _snag_only: bool = false
var _leg_s: float = 30.0
var _snag_from: String = ""
var _timeline: PackedStringArray = PackedStringArray()
var _snags: PackedStringArray = PackedStringArray()
var _downs: int = 0
var _custody: int = 0
var _al: Object = null
var _ended: bool = false
var _thermite_fails: int = 0
var _thermite_given_up: bool = false


func _run() -> void:
	heist_name = "Dockside Burn"
	runner_flow = "db_pass"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--po5-difficulty="):
			difficulty_name = a.substr(17)
		elif a.begins_with("--po5-seed="):
			HeistLauncher.next_seed_override = a.substr(11).to_int()
		elif a.begins_with("--po5-budget="):
			_budget_s = a.substr(13).to_float()
		elif a == "--snag=0":
			_do_snag = false
		elif a == "--snag-only":
			_snag_only = true
		elif a.begins_with("--snag-from="):
			_snag_from = a.substr(12)
		elif a.begins_with("--snag-leg-s="):
			_leg_s = a.substr(13).to_float()
	if _budget_s > 0.0:
		_watchdog.call_deferred()
	if not await enter_heist():
		return
	var outcome: Array[int] = [-1]
	EventBus.heist_ended.connect(func(r: Dictionary) -> void:
		outcome[0] = 1 if bool(r.get("success", false)) else 0
		_ended = true
		_tl("heist_ended success=%s" % r.get("success", false)))
	EventBus.alarm_raised.connect(func(reason: StringName, src: int) -> void:
		_tl("alarm_raised %s by %d" % [reason, src]))
	EventBus.objective_updated.connect(func(id: StringName, st: int, _d: Dictionary) -> void:
		_tl("objective %s -> %s" % [id, ["HIDDEN", "ACTIVE", "COMPLETED", "FAILED"][clampi(st, 0, 3)]]))
	EventBus.loot_secured.connect(func(_b: int, l: StringName, v: int) -> void:
		_tl("loot_secured %s (%d)" % [l, v]))
	EventBus.device_started.connect(func(_id: int, kind: StringName, dur: float) -> void:
		_tl("device_started %s %.0f s" % [kind, dur]))
	crew.crew_state_changed.connect(func(_o: int, n: int) -> void:
		if n == Enums.CrewState.DOWNED:
			_downs += 1
		elif n == Enums.CrewState.CUSTODY:
			_custody += 1
		_tl("local crew state -> %d at %s" % [n, Po5Pilot._v(crew.global_position)]))
	note("DB variants: %s" % [rt.variants])
	note("DB map origin %s (snag tour uses layout coordinates)" % Po5Pilot._v(rt.map.global_position))
	var code: int = 0
	if _do_snag:
		await _snag_leg()
	if not _snag_only and not _ended:
		code = await _loud()
	if code == 0 and outcome[0] == 0:
		note("FAIL the heist ended in failure (success=false)")
		code = 1
	await shot("end")
	_report()
	_finish(code)


func _tl(what: String) -> void:
	var line: String = "t=%5.0f %s" % [rt.heist_time_s if rt != null and is_instance_valid(rt) else -1.0, what]
	_timeline.append(line)
	note("TL " + line)


# --- Snag leg ---------------------------------------------------------------------------------

func _snag_leg() -> void:
	pilot.combat = true
	var origin: Vector3 = rt.map.global_position
	var stuck0: int = pilot.stuck_spots.size()
	note("SNAG LEG start t=%.0f (%d points, %.0f s per leg)" % [rt.heist_time_s, SNAG_TOUR.size(), _leg_s])
	await shot("snag_start")
	var skipping: bool = _snag_from != ""
	for i: int in SNAG_TOUR.size():
		if skipping and SNAG_TOUR[i][0] != _snag_from:
			continue
		skipping = false
		if _ended:
			break
		if crew.crew_state != Enums.CrewState.NORMAL:
			note("SNAG LEG ends: local crew state %d at %s" % [crew.crew_state, Po5Pilot._v(crew.global_position)])
			break
		crew.health.reset_full()  # harness aid (see header)
		var label: String = SNAG_TOUR[i][0]
		var want: Vector3 = origin + (SNAG_TOUR[i][1] as Vector3)
		var stand: Vector3 = pilot.stand_point(want)
		var from: Vector3 = crew.global_position
		var path: PackedVector3Array = pilot.nav_path(stand)
		var path_ok: bool = not path.is_empty() and path[path.size() - 1].distance_to(stand) <= 1.0
		var t0: float = rt.heist_time_s
		var s0: int = pilot.stuck_spots.size()
		var ok: bool = await pilot.goto(stand, 1.0, _leg_s)
		var dt_s: float = rt.heist_time_s - t0
		var stucks: int = pilot.stuck_spots.size() - s0
		var row: String = "%-24s %s %5.1f s from %s to %s (snap %.1f m, nav path %s, stuck x%d%s)" % [label,
			"OK  " if ok else "FAIL", dt_s, Po5Pilot._v(from), Po5Pilot._v(stand), stand.distance_to(want),
			"yes" if path_ok else "NO", stucks,
			", blocked by door %s" % pilot.last_blocked_door.name if pilot.last_blocked_door != null else ""]
		if not ok:
			row += " ended at %s" % Po5Pilot._v(crew.global_position)
		for k: int in range(s0, pilot.stuck_spots.size()):
			var sr: Dictionary = pilot.stuck_spots[k]
			_snags.append("STUCK %s at %s toward %s: %s" % [label, Po5Pilot._v(sr["pos"]), Po5Pilot._v(sr["toward"]),
				"; ".join(sr["hits"])])
		_snags.append("LEG " + row)
		note("SNAG " + row)
		if not ok or stucks > 0:
			await shot("snag_%s" % label)
	note("SNAG LEG end t=%.0f: %d stuck rows" % [rt.heist_time_s, pilot.stuck_spots.size() - stuck0])
	await shot("snag_end")


# --- Loud -------------------------------------------------------------------------------------

## A's auto_loud.play() loop, step by step, with the DB thermite step first (see header).
func _loud() -> int:
	_al = (load(AUTO_LOUD) as GDScript).new()
	_al.set(&"f", self)
	_al.set(&"p", pilot)
	_al.set(&"rt", rt)
	EventBus.heist_ended.connect(func(_r: Dictionary) -> void: _al.set(&"_ended", true))
	note("LOUD start t=%.0f phase=%d went_loud=%s masked=%s" % [rt.heist_time_s, rt.phase, rt.went_loud, crew.masked])
	if not crew.masked:
		await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	pilot.combat = true
	pilot.hook_need = func() -> bool: return _al.call(&"_downed_mate") != null
	pilot.hook = Callable(_al, &"_revive_teammate")
	var t0: float = rt.heist_time_s
	var last_shot: float = -100.0
	while not _ended and rt.heist_time_s - t0 < float(_al.get(&"LOOP_LIMIT_S")):
		if crew.crew_state == Enums.CrewState.CUSTODY:
			note("FAIL player in custody at %.0f s" % rt.heist_time_s)
			return 1
		if crew.crew_state != Enums.CrewState.NORMAL:
			await _al.call(&"_act_while_down")
			continue
		if rt.heist_time_s - last_shot > 90.0:
			last_shot = rt.heist_time_s
			await shot("auto_%d" % int(rt.heist_time_s))
		if not await _thermite_step():
			await _al.call(&"step")
	if not _ended:
		note("FAIL no heist end within %.0f s; markers %s" % [float(_al.get(&"LOOP_LIMIT_S")), _al.call(&"_marker_summary")])
		return 1
	return await payday_to_hub()


## DB step: carry the thermite bag to the run's burn point. True when it acted this step.
func _thermite_step() -> bool:
	if _thermite_given_up or _burn_started():
		return false
	var bag: LootBag = crew.carried_bag as LootBag
	if bag != null and bag.loot_id == THERMITE:
		await _deliver_thermite()
		return true
	if crew.is_carrying_bag():
		return false  # another bag: A's flow secures it
	var src: InteractableComponent = _thermite_source()
	if src == null:
		return false
	note("THERMITE fetching from %s at %s (t=%.0f)" % [src.owner_node().name, Po5Pilot._v(src.global_position),
		rt.heist_time_s])
	await pilot.use(src, 30.0, func() -> bool: return crew.is_carrying_bag())
	if not crew.is_carrying_bag():
		_thermite_fails += 1
		note("THERMITE pick-up failed (%d)" % _thermite_fails)
		if _thermite_fails >= 3:
			await _give_up_thermite()
	return true


## Carry the thermite on our back to the burn point (clearing the way like A's carry) and place it.
func _deliver_thermite() -> void:
	var bp: BurnPoint = _burn_point()
	if bp == null:
		note("FINDING thermite carried but no idle burn point is enabled")
		await _give_up_thermite()
		return
	note("THERMITE carrying to %s at %s (t=%.0f)" % [bp.name, Po5Pilot._v(bp.global_position), rt.heist_time_s])
	var stand: Vector3 = pilot._use_stand(bp.interactable)
	var t_leg: float = rt.heist_time_s
	while crew.is_carrying_bag() and not pilot.near(crew.global_position, stand, 1.5) \
			and rt.heist_time_s - t_leg < 240.0 and crew.crew_state == Enums.CrewState.NORMAL and not _ended:
		if pilot.nearest_enemy(20.0) != null:
			await _al.call(&"_clear_then_pick_up")
			continue
		if not await pilot.goto(stand, 1.0, 6.0) and pilot.last_blocked_door != null:
			note("THERMITE route blocked by %s" % pilot.last_blocked_door.name)
			break
	if crew.crew_state != Enums.CrewState.NORMAL or _ended:
		return
	var ok: bool = await pilot.use(bp.interactable, 30.0, func() -> bool: return _burn_started())
	note("THERMITE burn point %s used: %s (t=%.0f)" % [bp.name, ok, rt.heist_time_s])
	if not ok and not _burn_started():
		_thermite_fails += 1
		if _thermite_fails >= 3:
			await _give_up_thermite()
	return


func _give_up_thermite() -> void:
	_thermite_given_up = true
	note("FINDING THERMITE given up after %d failures at %s (t=%.0f)" % [_thermite_fails,
		Po5Pilot._v(crew.global_position), rt.heist_time_s])
	var bag: LootBag = crew.carried_bag as LootBag
	if bag != null and bag.loot_id == THERMITE:
		await pilot.inp.tap(&"drop_bag")


func _burn_started() -> bool:
	for n: Node in rt.find_children("*", "BurnPoint", true, false):
		if (n as BurnPoint).stage != BurnPoint.Stage.IDLE:
			return true
	return false


## The idle burn point with an enabled interactable, nearest the burn / product marker (the run's product room).
func _burn_point() -> BurnPoint:
	var mark: Vector3 = Vector3.INF
	for m: Dictionary in rt.hud_model.objective_markers:
		if StringName(m["id"]) in [&"burn", &"product"]:
			mark = m["position"]
			break
	var best: BurnPoint = null
	var best_d: float = INF
	for n: Node in rt.find_children("*", "BurnPoint", true, false):
		var bp: BurnPoint = n as BurnPoint
		if bp.stage != BurnPoint.Stage.IDLE or not bp.interactable.enabled or not bp.is_visible_in_tree():
			continue
		var d: float = bp.global_position.distance_to(mark if mark != Vector3.INF else crew.global_position)
		if d < best_d:
			best = bp
			best_d = d
	return best


## A loose thermite bag, else an enabled thermite loot spawn (nearest).
func _thermite_source() -> InteractableComponent:
	var best: InteractableComponent = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		if c == null or not c.enabled or not rt.is_ancestor_of(c) or not (c.kind in [&"bag_loot", &"pick_bag"]):
			continue
		var o: Node = c.owner_node()
		var lid: Variant = o.get(&"loot_id") if o != null else null
		if lid == null or StringName(lid) != THERMITE or c.availability(crew) != &"":
			continue
		var d: float = c.global_position.distance_to(crew.global_position)
		if d < best_d:
			best = c
			best_d = d
	return best


# --- Report -----------------------------------------------------------------------------------

func _report() -> void:
	note("==== DB-P1 REPORT ====")
	note("seed %d variants %s" % [run_seed, rt.variants if rt != null and is_instance_valid(rt) else "-"])
	note("TIMELINE (%d rows):" % _timeline.size())
	for l: String in _timeline:
		note("  " + l)
	note("SNAG TABLE (%d rows):" % _snags.size())
	for s: String in _snags:
		note("  " + s)
	note("PILOT STUCK rows total %d (snag leg + loud)" % pilot.stuck_spots.size() if pilot != null else "no pilot")
	if pilot != null:
		for sr: Dictionary in pilot.stuck_spots:
			note("  STUCK at %s toward %s: %s" % [Po5Pilot._v(sr["pos"]), Po5Pilot._v(sr["toward"]), "; ".join(sr["hits"])])
	note("local downs %d custody %d" % [_downs, _custody])
