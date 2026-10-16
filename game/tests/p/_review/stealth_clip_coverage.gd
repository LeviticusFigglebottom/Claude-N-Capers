## D-111 stealth clip coverage on the unit map (LEAD 2026-10-16): the intimidation / pager / body-bag clips that a full
## Night Deposit stealth run rarely reaches before a civilian call or a guard radio goes loud. Real input (Po5Pilot:
## mouse look, F, G, melee, hold-interact), windowed, with AnimCoverage (--anim-out=DIR) recording what played:
## A) 3 civilians, no guard: shout each down (F) and tie them (hold F) -> civilian down / cower / tied clips;
## B) 1 guard: knife him from behind (melee), answer his pager, bag the body, carry it a few metres and throw it (G)
##    -> guard death, pager_answer, bag_body, carry_bag_walk, throw_bag.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --resolution 960x540 --audio-driver Dummy \
##     res://tests/p/_review/stealth_clip_coverage.tscn -- --anim-out=/abs/dir [--out=/abs/shots]
## Prints "[SCC ...]" lines and "[SCC] RESULT tied=N knifed=N pager=N bagged=N thrown=N". Owner: ENV P.
extends Node

var rt: HeistRuntime = null
var pilot: Po5Pilot = null
var runner_out: String = ""
var _shot: int = 0
var _res: Dictionary = {"tied": 0, "knifed": 0, "pager": 0, "bagged": 0, "thrown": 0}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			runner_out = kv[1]
	if runner_out == "":
		runner_out = OS.get_user_data_dir() + "/stealth_clip_coverage"
	DirAccess.make_dir_recursive_absolute(runner_out)
	var n: Node = Node.new()
	n.name = "AnimCoverage"
	n.set_script(load("res://tests/p/_review/anim_coverage.gd"))
	get_tree().root.add_child.call_deferred(n)
	_run.call_deferred()


func note(msg: String) -> void:
	print("[SCC %.1fs t=%.1f] %s" % [Time.get_ticks_msec() / 1000.0, rt.heist_time_s if rt != null else -1.0, msg])


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_shot += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [runner_out, _shot, label])


func wait_s(s: float) -> void:
	for _i: int in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _run() -> void:
	await _civilians()
	await _guard()
	note("RESULT tied=%d knifed=%d pager=%d bagged=%d thrown=%d" % [_res["tied"], _res["knifed"], _res["pager"],
		_res["bagged"], _res["thrown"]])
	print("[SCC] RESULT tied=%d knifed=%d pager=%d bagged=%d thrown=%d" % [_res["tied"], _res["knifed"],
		_res["pager"], _res["bagged"], _res["thrown"]])
	get_tree().quit(0)


func _launch(guards: int, civilians: int) -> CrewController:
	rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(guards, civilians), "crew_ai": false})
	await ATestMaps.await_nav_synced(rt)
	var c: CrewController = rt.crew_controller(Net.local_slot()) as CrewController
	await wait_s(1.0)
	pilot = Po5Pilot.new(self, c)
	pilot.quiet = true
	pilot.shout_blockers = false
	await pilot.calibrate()
	await pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	return c


func _teardown() -> void:
	pilot.inp.release_all()
	rt.teardown()
	rt = null
	for _i: int in 3:
		await get_tree().process_frame


## A) shout each civilian down and tie them.
func _civilians() -> void:
	var c: CrewController = await _launch(0, 3)
	for n: Node in rt.npcs(&"civilian"):
		var civ: NpcBase = n as NpcBase
		var b: CivilianBrain = civ.get_node_or_null(^"Brain") as CivilianBrain
		if b == null:
			continue
		# The unit map has no baked nav: stand 3 m in front of the civilian instead of walking there.
		var front: Vector3 = civ.global_position + _flat(civ.global_position.direction_to(c.global_position)) * 3.0
		rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, Vector3(front.x, 0.05, front.z)))
		await wait_s(0.3)
		var head: Vector3 = civ.global_position + Vector3(0, 1.5, 0)
		for _k: int in 4:
			if b.mode == CivilianBrain.Mode.DOWN:
				break
			await pilot.face(head, 0.03, 1.5)
			await pilot.inp.tap(&"shout")
			await wait_s(1.2)
			note("shouted %s -> mode %d" % [civ.name, b.mode])
		await shot("civ_down_%s" % civ.name)
		for comp: Node in civ.find_children("*", "InteractableComponent", true, false):
			var ic: InteractableComponent = comp as InteractableComponent
			if ic.kind == &"cable_tie" and ic.enabled:
				var why: StringName = ic.availability(c)
				if why != &"":
					note("tie on %s unavailable: %s" % [civ.name, why])
					break
				var near: Vector3 = civ.global_position + _flat(civ.global_position.direction_to(c.global_position)) * 1.0
				rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, Vector3(near.x, 0.05, near.z)))
				await wait_s(0.3)
				if await pilot.use(ic, 15.0, func() -> bool: return b.mode == CivilianBrain.Mode.TIED, false):
					_res["tied"] += 1
				note("tie %s -> mode %d" % [civ.name, b.mode])
				break
		await wait_s(2.0)
	await shot("civs_tied")
	await _teardown()


## B) knife the guard from behind, answer the pager, bag, carry and throw the body.
func _guard() -> void:
	var c: CrewController = await _launch(1, 0)
	var g: NpcBase = rt.npcs(&"guard")[0] as NpcBase if not rt.npcs(&"guard").is_empty() else null
	if g == null:
		note("no guard")
		await _teardown()
		return
	var back: Vector3 = g.global_position + g.global_basis.z.normalized() * 0.8
	rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, Vector3(back.x, 0.05, back.z)))
	await wait_s(0.3)
	var hits: Array[int] = [0, 0]
	c.melee.hit_landed.connect(func(_t: Object) -> void: hits[0] += 1)
	c.melee.swung.connect(func(_ch: bool) -> void: hits[1] += 1)
	for _k: int in 4:
		if not g.is_alive():
			break
		await pilot.face(g.global_position + Vector3(0, 1.1, 0), 0.05, 1.0)
		await pilot.inp.hold(&"melee", 1.05)
		await wait_s(0.6)
		note("swing: dist %.2f, swings %d, hits %d, guard health %.2f alive %s, aim %s" % [pilot.flat_dist(
			g.global_position, c.global_position), hits[1], hits[0], g.health, g.is_alive(), c.aim_direction()])
	if g.is_alive():
		note("guard not knifed (alert %d)" % g.alert_state)
		await _teardown()
		return
	_res["knifed"] += 1
	await shot("knifed")
	var pager: InteractableComponent = null
	for _k: int in 40:  # the pager goes off a moment after the kill
		pager = _find_kind(&"answer_pager")
		if pager != null or rt.went_loud:
			break
		await wait_s(0.25)
	if pager != null:
		note("answering the pager")
		await shot("pager")
		if await pilot.use(pager, 20.0, func() -> bool: return not pager.enabled, false):
			_res["pager"] += 1
	else:
		note("no pager (loud %s)" % rt.went_loud)
	var bag: InteractableComponent = _find_kind(&"bag_body")
	if bag == null:
		note("no bag_body interaction")
	elif bag.availability(c) != &"":
		note("bag_body unavailable: %s" % bag.availability(c))
	elif await pilot.use(bag, 20.0, func() -> bool: return c.is_carrying_bag(), false):
		_res["bagged"] += 1
		pilot.inp.press(&"move_forward")
		await wait_s(2.5)
		pilot.inp.release(&"move_forward")
		await shot("carry")
		await pilot.inp.tap(&"drop_bag")
		await wait_s(1.5)
		if not c.is_carrying_bag():
			_res["thrown"] += 1
		await shot("thrown")
	await _teardown()


func _flat(v: Vector3) -> Vector3:
	var f: Vector3 = Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-6 else Vector3.BACK


func _find_kind(kind: StringName) -> InteractableComponent:
	for n: Node in get_tree().get_nodes_in_group(G.INTERACTABLE):
		var comp: InteractableComponent = n as InteractableComponent
		if comp != null and comp.enabled and comp.kind == kind and rt.is_ancestor_of(comp):
			return comp
	return null
