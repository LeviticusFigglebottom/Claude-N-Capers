## PO's-eye PO6 regression checks on Golden Hour (`glasshouse`), windowed, real input (LEAD 2026-10-16): the items
## a full menu run shows poorly, each with a PASS / FAIL line and a screenshot. Complements A's flows
## (run_po5.sh gh_stealth / gh_loud: code route, drill, jams, timer, assault, escape) and A's po6_gh_capture
## (loot in the safe, one-press drill, pose-respecting deaths, corpse blood).
## Launch 1 (stealth, casing skipped):
##   PO6-06  every civilian stands at heist start (no DOWN / TIED / COWER / intimidated); manager office shot.
##   PO6-08  knife a guard: the pager window FREEZES while the answer is held; the answer completes.
##   PO6-20  the beeping body has the yellow outline (shot) and a pager row with a world position.
##   PO6-07  2 s after the answer no pager loop is active in the CuePlayer.
##   PO6-08  a second guard: hold the answer 0.6 s and let go -> alarm (no juggle); the pager loops stop.
## Launch 2 (loud, Brute 12 primary, AI crew):
##   PO6-19  a point-blank shotgun hit sends the cop's body flying (moves > 1 m) / ragdolls; two hits on the corpse.
##   PO6-14  carry a bag, face a bot, throw it (G) -> the bot carries it.
##   PO6-07  sirens / alarm loops: the active loop keys are printed at the end of the run (stopper audit).
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/po6_gh_check.tscn -- --out=/abs/dir [--seed=1792002290]
## Prints "[PO6] <item> PASS|FAIL <detail>" lines. Owner: ENV P.
extends Node

const MANAGER_AT: Vector3 = Vector3(9.2, 4.95, 8.75)

var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var runner_out: String = ""
var _seed: int = 1792002290
var _shot: int = 0
var _alarm: StringName = &""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": runner_out = v
			"seed": _seed = v.to_int()
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/po6_gh_check"
	DirAccess.make_dir_recursive_absolute(runner_out)
	_run.call_deferred()


func note(msg: String) -> void:
	print("[PO6 %.1fs t=%.1f] %s" % [Time.get_ticks_msec() / 1000.0, rt.heist_time_s if rt != null else -1.0, msg])


func verdict(item: String, ok: bool, detail: String) -> void:
	print("[PO6] %s %s %s" % [item, "PASS" if ok else "FAIL", detail])


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [runner_out, _shot, label])


func wait_s(s: float) -> void:
	for _i: int in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _run() -> void:
	await _stealth_checks()
	await _loud_checks()
	print("[PO6] DONE")
	get_tree().quit(0)


func _launch(opts: Dictionary) -> CrewController:
	rt = await HeistLauncher.launch(&"glasshouse", _seed, Enums.Difficulty.ROUTINE, self, opts)
	_alarm = &""
	EventBus.alarm_raised.connect(_on_alarm)
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await wait_s(1.5)
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.shout_blockers = false
	await pilot.calibrate()
	return c


func _on_alarm(reason: StringName, _src: int) -> void:
	if _alarm == &"":
		_alarm = reason
	note("alarm %s" % reason)


func _teardown() -> void:
	if EventBus.alarm_raised.is_connected(_on_alarm):
		EventBus.alarm_raised.disconnect(_on_alarm)
	pilot.inp.release_all()
	rt.teardown()
	rt = null
	for _i: int in 3:
		await get_tree().process_frame


func _place(c: CrewController, at: Vector3, look_at: Vector3) -> void:
	rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.05, 0)))
	await wait_s(0.3)
	await pilot.face(look_at, 0.03, 1.5)


func _flat_dir(from: Vector3, to: Vector3) -> Vector3:
	var d: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	return d.normalized() if d.length_squared() > 1e-6 else Vector3.BACK


# --- launch 1: stealth --------------------------------------------------------------------------

func _stealth_checks() -> void:
	var c: CrewController = await _launch({"skip_casing": true, "crew_ai": false})
	# PO6-06: civilians at the start.
	var bad: Array[String] = []
	var office: NpcBase = null
	for n: Node in rt.npcs(&"civilian"):
		var civ: NpcBase = n as NpcBase
		var b: CivilianBrain = civ.get_node_or_null(^"Brain") as CivilianBrain
		var mode: int = b.mode if b != null else -1
		if mode in [CivilianBrain.Mode.DOWN, CivilianBrain.Mode.TIED, CivilianBrain.Mode.COWER] \
				or civ.alert_state in [Enums.AlertState.INTIMIDATED, Enums.AlertState.TIED]:
			bad.append("%s mode %d alert %d at %s" % [civ.name, mode, civ.alert_state, Po5Pilot._v(civ.global_position)])
		if civ.global_position.y > 3.0 and (office == null
				or civ.global_position.distance_to(MANAGER_AT) < office.global_position.distance_to(MANAGER_AT)):
			office = civ
	if office != null:
		var stand: Vector3 = office.global_position - office.global_basis.z.normalized() * 2.5
		await _place(c, Vector3(stand.x, office.global_position.y, stand.z), office.global_position + Vector3(0, 1.2, 0))
		await shot("po6_06_manager_office_start")
	verdict("PO6-06", bad.is_empty(), "%d civilians at start, not standing: %s; office civilian %s" % [
		rt.npcs(&"civilian").size(), bad, office.name if office != null else "none"])
	var guards: Array[NpcBase] = []
	for n: Node in rt.npcs(&"guard"):
		guards.append(n as NpcBase)
	# Away from the civilians (a masked stranger next to a customer is a civilian_call).
	guards.sort_custom(func(a: NpcBase, b: NpcBase) -> bool: return _civ_dist(a) > _civ_dist(b))
	if guards.size() < 2:
		verdict("PO6-08", false, "needs 2 guards, found %d" % guards.size())
		await _teardown()
		return
	# PO6-08 / 20 / 07: a full answer.
	var pid: int = await _knife_and_wait_pager(c, guards[0])
	if pid <= 0:
		verdict("PO6-08", false, "NOT CHECKED: no pager on %s (alarm %s)" % [guards[0].name, _alarm])
	if pid > 0:
		await shot("po6_20_pager_outline")
		var comp: InteractableComponent = _pager_comp(guards[0])
		var row_pos: Vector3 = _pager_pos(pid)
		verdict("PO6-20", comp != null and row_pos != Vector3.INF, "pager row world pos %s (body %s), interactable %s (outline: see shot)" % [
			row_pos, guards[0].global_position, comp.get_path() if comp != null else "none"])
		var t0: float = _time_left(pid)
		await _place(c, guards[0].global_position + _flat_dir(guards[0].global_position, c.global_position) * 1.0,
			comp.global_position if comp != null else guards[0].global_position)
		var t_before: float = _time_left(pid)
		pilot.inp.press(&"interact")
		await wait_s(0.3)
		var t_held_a: float = _time_left(pid)
		await wait_s(1.0)
		var t_held_b: float = _time_left(pid)
		var answered: bool = await _wait_until(func() -> bool: return _time_left(pid) < 0.0, 15.0)
		pilot.inp.release(&"interact")
		verdict("PO6-08", absf(t_held_a - t_held_b) < 0.05 and answered,
			"freeze while held: %.2f -> %.2f over 1 s (window was %.2f at the beep, %.2f at the hold); answered %s" % [
			t_held_a, t_held_b, t0, t_before, answered])
		await wait_s(2.0)
		var loops: Array[StringName] = _active_loops()
		verdict("PO6-07", not _has_pager_loop(loops), "2 s after the answer, active loops %s" % [loops])
	# PO6-08: a released answer alarms.
	if _alarm == &"":
		var pid2: int = await _knife_and_wait_pager(c, guards[1])
		if pid2 <= 0:
			verdict("PO6-08b", false, "NOT CHECKED: no pager on %s (alarm %s)" % [guards[1].name, _alarm])
		if pid2 > 0:
			var comp2: InteractableComponent = _pager_comp(guards[1])
			await _place(c, guards[1].global_position + _flat_dir(guards[1].global_position, c.global_position) * 1.0,
				comp2.global_position if comp2 != null else guards[1].global_position)
			pilot.inp.press(&"interact")
			await wait_s(0.6)
			pilot.inp.release(&"interact")
			var alarmed: bool = await _wait_until(func() -> bool: return _alarm != &"",
				Tweak.stealth().pager_juggle_window_s + 2.0)
			verdict("PO6-08b", alarmed, "release after 0.6 s -> alarm %s" % _alarm)
			await wait_s(2.0)
			var loops2: Array[StringName] = _active_loops()
			verdict("PO6-07b", not _has_pager_loop(loops2), "2 s after the failed pager, active loops %s" % [loops2])
	else:
		verdict("PO6-08b", false, "skipped: already loud (%s) before the second pager" % _alarm)
	await _teardown()


func _knife_and_wait_pager(c: CrewController, g: NpcBase) -> int:
	var back: Vector3 = g.global_position + g.global_basis.z.normalized() * 0.8
	await _place(c, Vector3(back.x, g.global_position.y, back.z), g.global_position + Vector3(0, 1.2, 0))
	if not c.masked:
		await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	note("behind %s (nearest civilian %.1f m)" % [g.name, _civ_dist(g)])
	for _k: int in 3:
		if not g.is_alive():
			break
		await pilot.face(g.global_position + Vector3(0, 1.2, 0), 0.03, 1.0)
		await pilot.inp.hold(&"melee", 1.05)
		await wait_s(0.6)
	if g.is_alive():  # fallback: suppressed secondary to the head
		note("%s not knifed (alert %d): secondary to the head" % [g.name, g.alert_state])
		await pilot.inp.tap(&"slot_secondary")
		await wait_s(1.0)
		for _k: int in 4:
			if not g.is_alive():
				break
			await pilot.face(g.global_position + Vector3(0, 1.65, 0), 0.01, 1.0)
			await pilot.inp.tap(&"fire")
			await wait_s(0.4)
	if g.is_alive():
		note("%s still alive (alert %d)" % [g.name, g.alert_state])
		return -1
	var pagers: PagerSystem = rt.service(G.SVC_PAGERS) as PagerSystem
	for _k: int in 60:
		for e: Dictionary in pagers.pager_entries():
			if int(e["guard_net_id"]) == g.net_id:
				note("pager %d on %s, %.2f s" % [int(e["pager_id"]), g.name, float(e["time_left"])])
				return int(e["pager_id"])
		if _alarm != &"":
			break
		await wait_s(0.25)
	note("no pager on %s (alarm %s)" % [g.name, _alarm])
	return -1


func _time_left(pid: int) -> float:
	for e: Dictionary in (rt.service(G.SVC_PAGERS) as PagerSystem).pager_entries():
		if int(e["pager_id"]) == pid:
			return float(e["time_left"])
	return -1.0


func _pager_pos(pid: int) -> Vector3:
	for e: Dictionary in (rt.service(G.SVC_PAGERS) as PagerSystem).pager_entries():
		if int(e["pager_id"]) == pid:
			return e["world_pos"]
	return Vector3.INF


func _pager_comp(g: NpcBase) -> InteractableComponent:
	for comp: Node in g.find_children("*", "InteractableComponent", true, false):
		if (comp as InteractableComponent).kind == &"answer_pager":
			return comp as InteractableComponent
	return null


func _cue_player() -> CuePlayer:
	for n: Node in get_tree().root.find_children("*", "Node", true, false):
		if n is CuePlayer:
			return n as CuePlayer
	return null


func _active_loops() -> Array[StringName]:
	var cp: CuePlayer = _cue_player()
	return cp.active_loop_keys() if cp != null else [] as Array[StringName]


func _has_pager_loop(keys: Array[StringName]) -> bool:
	for k: StringName in keys:
		if String(k).contains("pager"):
			return true
	return false


func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while t < timeout_s:
		if cond.call():
			return true
		await wait_s(0.1)
		t += 0.1
	return bool(cond.call())


# --- launch 2: loud -----------------------------------------------------------------------------

func _loud_checks() -> void:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = &"weapon.brute_12"
	l.primary_mods = [] as Array[StringName]
	l.resolved_primary = LoadoutResolver.resolve_weapon(l.primary, l.primary_mods)
	var c: CrewController = await _launch({"skip_casing": true, "crew_ai": true, "loadouts": {0: l}})
	Modifiers.set_source(c.slot, &"test.po6", {&"defense.damage_taken_mult": 0.0})
	await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	await pilot.inp.tap(&"slot_primary")
	rt.stealth.raise_alarm(&"test", 0)
	await wait_s(2.0)
	# PO6-19: point-blank shotgun.
	var here: Vector3 = c.global_position
	var fwd: Vector3 = _open_direction(c, 7.0)
	var cop: NpcBase = rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, here + fwd * 2.0), {})
	await wait_s(0.3)
	var p0: Vector3 = cop.global_position
	await pilot.face(cop.global_position + Vector3(0, 1.2, 0), 0.03, 1.0)
	for _k: int in 3:
		if not cop.is_alive():
			break
		await pilot.inp.tap(&"fire")
		await wait_s(0.5)
	await shot("po6_19_shotgun_hit")
	await wait_s(1.5)
	var moved: float = _body_pos(cop).distance_to(p0)
	await shot("po6_19_shotgun_settled")
	verdict("PO6-19", not cop.is_alive() and moved > 1.0, "cop dead %s, body moved %.2f m (ragdoll %s)" % [
		not cop.is_alive(), moved, _ragdolling(cop)])
	if is_instance_valid(cop):
		var q: Vector3 = _body_pos(cop)
		var before: Vector3 = q
		await pilot.face(q + Vector3(0, 0.2, 0), 0.03, 1.0)
		for _k: int in 2:
			await pilot.inp.tap(&"fire")
			await wait_s(0.6)
		await shot("po6_19_corpse_hits")
		note("corpse nudge %.2f m" % _body_pos(cop).distance_to(before))
	# PO6-14: a bag thrown at a bot.
	var bot: CrewController = null
	for m: CrewController in rt.crew_members():
		if m != c and m.crew_state == Enums.CrewState.NORMAL and (bot == null
				or m.global_position.distance_to(c.global_position) < bot.global_position.distance_to(c.global_position)):
			bot = m
	var loot: LootManager = rt.service(G.SVC_LOOT) as LootManager
	if bot == null or loot == null:
		verdict("PO6-14", false, "no bot (%s) / loot service" % bot)
	else:
		var bag: LootBag = loot.spawn_bag(&"loot.jewelry", Transform3D(Basis.IDENTITY, c.global_position + Vector3.UP))
		loot.carry(bag, c)
		await wait_s(0.5)
		await pilot.face(bot.global_position + Vector3(0, 1.0, 0), 0.03, 1.5)
		note("throwing at %s %.1f m away" % [bot.name, bot.global_position.distance_to(c.global_position)])
		await pilot.inp.tap(&"drop_bag")
		var caught: bool = await _wait_until(func() -> bool: return bot.is_carrying_bag(), 8.0)
		await shot("po6_14_bot_bag")
		verdict("PO6-14", caught, "%s carrying after the throw: %s (player carrying %s)" % [bot.name, caught,
			c.is_carrying_bag()])
	note("PO6-07 audit: active loops at the end of the loud check %s" % [_active_loops()])
	Modifiers.clear_source(c.slot, &"test.po6")
	await _teardown()


func _civ_dist(g: NpcBase) -> float:
	var best: float = INF
	for n: Node in rt.npcs(&"civilian"):
		best = minf(best, (n as Node3D).global_position.distance_to(g.global_position))
	return best


## A flat direction with `clear_m` of free space from the crew (shotgun knock-back needs room).
func _open_direction(c: CrewController, clear_m: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = c.get_world_3d().direct_space_state
	var best: Vector3 = Vector3.FORWARD
	var best_d: float = -1.0
	for i: int in 16:
		var d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		var from: Vector3 = c.global_position + Vector3(0, 1.0, 0)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + d * 20.0)
		q.exclude = [c.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		var free_m: float = from.distance_to(hit["position"]) if not hit.is_empty() else 20.0
		if free_m > best_d:
			best_d = free_m
			best = d
	note("open direction %s, %.1f m clear (want %.1f)" % [best, best_d, clear_m])
	return best


func _body_pos(npc: NpcBase) -> Vector3:
	return npc.global_position if is_instance_valid(npc) else Vector3.INF  # NpcRagdoll moves the root under the hips


func _ragdolling(npc: NpcBase) -> String:
	var r: NpcRagdoll = npc.get_node_or_null(NpcRagdoll.NODE_NAME) as NpcRagdoll if is_instance_valid(npc) else null
	return NpcRagdoll.Phase.keys()[r.phase] if r != null and &"phase" in r else "none"
