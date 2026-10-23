## PO-5 driver node (lives on the root, survives scene changes). See po5_runner.gd.
extends Node

## A fast-mode (not rendered) frame longer than this prints a HITCH line with FrameProf's top systems (ms).
## HITCH `pipelines=` labels, in _pipelines_now() order.
const PIPELINE_KINDS: PackedStringArray = ["mesh", "surface", "draw", "spec", "canvas"]
const HITCH_MS: float = 1000.0
## _load_report: rendered heist frames measured after the loading screen goes.
const LOAD_FRAMES: int = 5

var runner_out: String = "user://po5"
var runner_flow: String = "smoke"
## The heist card to click: its menu display name. `--po5-heist=` may also give the heist id or its old code name
## ("Glasshouse", "glasshouse"): `menu_heist_name` maps it to the def's display_name ("Golden Hour", P's PO6 rerun).
var heist_name: String = "Golden Hour"
var difficulty_name: String = "Routine"
var rt: HeistRuntime = null
## The run seed, kept for the RESULT line after the runtime is freed (back in the hub).
var run_seed: int = -1
var crew: CrewController = null
var pilot: Po5Pilot = null
## D-145 evidence: downs / regen / loadouts / police composition (STATS lines at heist_ended and at the end).
var stats: Po5Stats = null
## llvmpipe renders at ~1 fps, which caps game time at 8 physics ticks per second. Between screenshots
## the harness turns the render loop off (window, DisplayServer and input stay real); shot() renders.
var fast: bool = false
var _heist_list: UiHeistList = null
var _shot: int = 0
var _log: PackedStringArray = PackedStringArray()
var _worst_frame_ms: float = 0.0
## --po5-direct: launch through MenuFlow.launch, not the Board (a staged heist).
var _direct: bool = false
## --po5-rt-stub-trucks: see _stub_rt_trucks.
var _stub_trucks: bool = false
## _telemetry passes (a CENSUS line every 6th).
var _tel_n: int = 0
## --po5-hitch-ms: log every heist frame (rendered or not) longer than this (ms; 0 = off), with the NPCs spawned in it.
var _render_hitch_ms: float = 0.0
var _render_hitches: int = 0
var _heist_worst_ms: float = 0.0
var _heist_worst_noshot_ms: float = 0.0
var _shot_frame: bool = false
var _pipelines_seen: PackedInt64Array = PackedInt64Array()
var _shot_hitches: int = 0
var _hitches_noted: bool = false
var _heist_frames: int = 0
var _spawned_this_frame: PackedStringArray = PackedStringArray()
var _last_frame_us: int = 0
var _was_rendering: bool = true
## Engine.get_frames_drawn() at the last _process: a HITCH line says how many frames were drawn in it (fast mode
## should draw none; a drawn frame means the stall is llvmpipe rendering, not game code).
var _last_drawn: int = 0
var _budget_s: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--po5-heist="):
			heist_name = menu_heist_name(a.substr(12))
		elif a.begins_with("--po5-difficulty="):
			difficulty_name = a.substr(17)
		elif a.begins_with("--po5-seed="):
			HeistLauncher.next_seed_override = a.substr(11).to_int()  # replay a run (menus still clicked)
		elif a.begins_with("--po5-budget="):
			_budget_s = a.substr(13).to_float()
		elif a.begins_with("--po5-crew-dmg="):  # D-133 harness-only dev option, named in the evidence
			HeistLauncher.dev_options["crew_damage_taken_mult"] = a.substr(15).to_float()
		elif a.begins_with("--po5-hitch-ms="):  # LEAD (OF loud GPU hitches): rendered frames too, from this many ms
			_render_hitch_ms = a.substr(15).to_float()
		elif a == "--po5-direct":  # LEAD (RT G1 pilot): a staged heist, launched through MenuFlow.launch, no Board
			_direct = true
		elif a == "--po5-rt-stub-trucks":  # RT G1 before C's convoy swap: armored_trucks on the placeholder boxes
			_stub_trucks = true
	if _budget_s > 0.0:
		_watchdog.call_deferred()
	if not await enter_heist():
		return
	var outcome: Array[int] = [-1]  # heist_ended success: -1 not ended, 0 failed, 1 succeeded
	EventBus.heist_ended.connect(func(r: Dictionary) -> void: outcome[0] = 1 if bool(r.get("success", false)) else 0)
	stats = Po5Stats.new()
	stats.start(self, rt)
	rt.npc_spawned.connect(func(n: NpcBase) -> void:
		_spawned_this_frame.append(String(n.enemy_def.id).trim_prefix("enemy.") if n.enemy_def != null else String(n.name)))
	EventBus.heist_ended.connect(func(_r: Dictionary) -> void: _note_hitches())
	EventBus.heist_ended.connect(func(_r: Dictionary) -> void: note(stats.summary()))
	match runner_flow:
		"dump":
			dump_map()
		"smoke":
			pass
		_:
			var script: GDScript = load("res://tests/a/e2e/po5_flow_%s.gd" % runner_flow) as GDScript
			if script == null:
				return _fail("unknown flow %s" % runner_flow)
			var sc: Object = script.new()
			var code: int = await sc.call(&"play", self)
			if code == 0 and outcome[0] == 0:  # ND attempt 11: a custody wipe ended the heist and still read PASS
				note("FAIL the heist ended in failure (success=false)")
				code = 1
			await shot("end")
			_finish(code)
			return
	_finish(0)


## The planning-table card label for `heist_name`: a heist id or code name ("Glasshouse", "night_deposit") -> that
## HeistDef's display_name; anything else (already a display name, or unknown) unchanged.
static func menu_heist_name(given: String) -> String:
	var id: String = given.strip_edges().to_snake_case()
	var path: String = "res://world/heists/%s/%s_def.tres" % [id, id]
	if id != "" and ResourceLoader.exists(path):
		var def: HeistDef = load(path) as HeistDef
		if def != null and def.display_name != "":
			return def.display_name
	return given


## Lethal / Cataclysm are locked in the build (heist_list unlocked_difficulties, PO-5.9) and behind progression: a
## harness run on them (LEAD: OF Cataclysm real-bot runs) opens that difficulty in memory first (never saved).
func _open_difficulty() -> void:
	var d: int = Enums.Difficulty.keys().find(difficulty_name.to_upper())
	var l: UiHeistList = HeistCatalog.heist_list()
	_heist_list = l  # held: an unreferenced Resource leaves the cache and the next load() rereads the file
	if d >= 0 and l != null and not l.unlocked_difficulties.has(d):
		l.unlocked_difficulties.append(d)
		note("harness: %s opened in memory (locked in the build)" % difficulty_name)


## main menu -> Safehouse -> Planning Table -> heist -> difficulty -> Briefing -> Continue -> Confirm plan
## -> Start Heist, by mouse clicks; then waits for the local crew to spawn.
## --po5-direct (LEAD, RT G1 pilot): a heist the Board does not offer yet (staged: hidden, WIP def) is launched
## through MenuFlow.launch (the Launch button's own path: solo session, bots, loadout, HUD) instead of the Board clicks;
## everything after the load is the same flow. Named in the evidence.
func _launch_direct() -> bool:
	var flows: Array[Node] = get_tree().root.find_children("*", "MenuFlow", true, false)
	if flows.is_empty():
		await _fail("direct: no MenuFlow")
		return false
	var id: StringName = StringName(heist_name.strip_edges().to_snake_case())
	for hid: StringName in HeistRegistry.ids():  # the display name -> the def id (Golden Hour is glasshouse)
		var def: HeistDef = HeistRegistry.get_def(hid)
		if def != null and def.display_name == heist_name.strip_edges():
			id = hid
	if HeistRegistry.get_def(id) == null:  # fail fast and name the choices, not 60 s later at "did not start"
		await _fail("direct: unknown heist '%s' (ids %s)" % [heist_name, HeistRegistry.ids()])
		return false
	var diff: int = Enums.Difficulty.keys().find(difficulty_name.to_upper())
	if diff < 0:  # was: silently Routine
		await _fail("direct: unknown difficulty '%s' (%s)" % [difficulty_name, Enums.Difficulty.keys()])
		return false
	var run_seed: int = HeistLauncher.next_seed_override if HeistLauncher.next_seed_override >= 0 else 1001
	note("DEV OPTION direct launch: %s diff %d seed %d through MenuFlow.launch (staged heist, no Board)" % [id, diff, run_seed])
	(flows[0] as MenuFlow).launch(id, diff, SaveService.load_profile().loadout, run_seed)
	return true


## --po5-rt-stub-trucks (harness only, named in the evidence): until C's RT convoy swap lands, an armored_truck on each
## G1 placeholder truck box of every convoy layout (rear doors toward the box's `<Veh>RearDoor` marker; bullion 180 / 90),
## then the layouts re-applied so only the stopped layout's trucks are in play.
func _stub_rt_trucks() -> void:
	var scene: PackedScene = load("res://systems/prefabs/armored_truck/armored_truck.tscn") as PackedScene
	var n: int = 0
	for layout: Node3D in ConvoyLayouts.layouts(rt.map):
		for body: Node in layout.get_children():
			var kind: String = String(body.get_meta(&"kind", ""))
			if not body is StaticBody3D or not kind in ["convoy_cash", "convoy_bullion"]:
				continue
			var rear: Node3D = layout.get_node_or_null(NodePath(String(body.name) + "RearDoor")) as Node3D
			var t: ArmoredTruck = scene.instantiate() as ArmoredTruck
			t.name = String(body.name) + "Truck"
			if kind == "convoy_bullion":
				t.saw_duration_s = 180.0
				t.hand_saw_duration_s = 90.0
				t.set_meta(&"truck_kind", "bullion")
			layout.add_child(t)
			var at: Vector3 = (body as Node3D).global_position
			var to_rear: Vector3 = (rear.global_position - at) if rear != null else -(body as Node3D).global_basis.z
			to_rear.y = 0.0
			t.global_transform = Transform3D(Basis.looking_at(to_rear.normalized(), Vector3.UP), at)  # -Z = rear doors
			n += 1
	rt.set_layout(String(rt.layouts.get(ConvoyLayouts.DEFAULT_GROUP, "")))
	note("DEV OPTION rt-stub-trucks: %d armored_trucks on the G1 placeholder boxes (until C's convoy swap)" % n)


func enter_heist() -> bool:
	_open_difficulty()
	var t0: int = Time.get_ticks_msec()
	while find_button("Safehouse") == null and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	await shot("main_menu")
	if _direct:
		if not await _launch_direct():
			return false
	else:
		for step: String in ["Safehouse", "Planning Table", heist_name, difficulty_name, "Briefing", "Continue",
				"Confirm plan", "Start Heist"]:
			if not await click_text(step):
				await _fail("menu: no '%s'" % step)
				return false
			await seconds(1.0)
			if step in ["Planning Table", "Briefing", "Continue", "Confirm plan"]:
				await shot(step.to_snake_case())
	# LEAD (GPU-18 heist-load frame 3.1 s): like a player, the render loop stays on through the loading screen and the
	# first heist frames (pipeline compiles land under the loading screen, as in play); fast mode after (_load_report).
	var pipes0: int = _pipelines_total()
	FrameProf.enabled = true  # per-system cost for HITCH lines (ND t=322 stall hunt)
	var t: float = 0.0
	while t < 60.0:
		rt = HeistRuntime.current()
		if rt != null and rt.crew_controller(0) != null and not _loading_up():
			break
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	if rt == null or rt.crew_controller(0) == null:
		await _fail("heist did not start within 60 s of Start Heist")
		return false
	await _load_report(pipes0)
	set_fast(true)
	crew = rt.crew_controller(0) as CrewController
	await wait_s(1.0)
	run_seed = rt.run_seed
	note("in heist %s seed %d diff %d phase %d crew at %s" % [rt.heist_id, rt.run_seed, rt.difficulty, rt.phase,
		Po5Pilot._v(crew.global_position)])
	var looks: PackedStringArray = PackedStringArray()  # LEAD r281: AI crew drawn as capsules
	for c: CrewController in rt.crew_members():
		var v: Node = c.get_node_or_null(^"Visual")
		var first: String = String(v.get_child(0).name) if v != null and v.get_child_count() > 0 else "-"
		looks.append("%d%s:%s:%s" % [c.slot, "(ai)" if c.is_ai else "", c.heister, "capsule" if first == "Placeholder" else first])
	note("crew looks: %s" % ", ".join(looks))
	if rt.mission is RollingThunderMission:
		Po5RtAb.new().start(self, rt, note)  # LEAD r287: RT lever A/B timeline (runs alongside the flow)
	if rt.options.has("crew_damage_taken_mult"):
		note("DEV OPTION crew_damage_taken_mult=%.2f (D-133 harness-only; assault events on)" % float(
			rt.options["crew_damage_taken_mult"]))
	await shot("heist_start")
	if _stub_trucks:
		_stub_rt_trucks()
	pilot = Po5Pilot.new(self, crew)
	await capture_like_player()
	await pilot.calibrate()
	for c: CrewController in rt.crew_members():
		var slot: int = c.slot
		c.crew_state_changed.connect(func(o: int, n: int) -> void:
			note("EVENT crew %d state %d -> %d at %s (t=%.0f)" % [slot, o, n, Po5Pilot._v(c.global_position), rt.heist_time_s]))
	_telemetry()
	return true


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var rendering: bool = RenderingServer.render_loop_enabled
	var drawn: int = Engine.get_frames_drawn()
	if _last_frame_us != 0:
		var frame_ms: float = (now - _last_frame_us) / 1000.0
		_worst_frame_ms = maxf(_worst_frame_ms, frame_ms)
		# Rendered frames (llvmpipe screenshots, menus) are slow by design: only fast-mode frames count.
		if frame_ms > HITCH_MS and not rendering and not _was_rendering and rt != null and is_instance_valid(rt):
			note("HITCH frame=%.0fms t=%.1f drawn=%d nodes=%d enemies=%d top: %s" % [frame_ms, rt.heist_time_s,
				drawn - _last_drawn, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), _alive_in(G.ENEMY),
				FrameProf.top(10)])
		if _render_hitch_ms > 0.0 and rt != null and is_instance_valid(rt):
			_heist_frames += 1
			_heist_worst_ms = maxf(_heist_worst_ms, frame_ms)
			if not _shot_frame:
				_heist_worst_noshot_ms = maxf(_heist_worst_noshot_ms, frame_ms)
			if frame_ms > _render_hitch_ms:
				_render_hitches += 1
				_shot_hitches += 1 if _shot_frame else 0
				_note_hitch(frame_ms)
	_spawned_this_frame.clear()
	_shot_frame = false
	if _render_hitch_ms > 0.0:
		_pipelines_seen = _pipelines_now()
	FrameProf.reset_frame()
	_was_rendering = rendering
	_last_frame_us = now
	_last_drawn = drawn


## Every 10 s of game time: frame cost, crew states/positions, enemy count.
func _telemetry() -> void:
	while rt != null and is_instance_valid(rt):
		await wait_s(10.0)
		if rt == null or not is_instance_valid(rt):
			return
		var cs: PackedStringArray = PackedStringArray()
		for c: CrewController in rt.crew_members():
			cs.append("%d:%d@%s" % [c.slot, c.crew_state, Po5Pilot._v(c.global_position)])
		var near_m: float = INF
		var en_close: int = 0
		for e: Node in get_tree().get_nodes_in_group(G.ENEMY):
			if not (e as NpcBase).is_alive():
				continue
			var ed: float = (e as Node3D).global_position.distance_to(crew.global_position)
			near_m = minf(near_m, ed)
			en_close += 1 if ed < 15.0 else 0
		cs.append("nearest_enemy=%.1fm within15=%d" % [near_m, en_close])
		var pin: Node = crew.get_node_or_null(^"PlayerInput") if crew != null else null
		cs.append("input_enabled=%s captured=%s paused_by=%s" % [pin.get(&"enabled") if pin != null else "-",
			MouseCapture.is_captured(), (load("res://content/ui/common/crew_input.gd") as GDScript).get(&"_holders")])
		var worst: float = _worst_frame_ms
		_worst_frame_ms = 0.0
		note("TEL worst_frame=%.0fms t=%.0f phase=%d phys=%.1fms proc=%.1fms nodes=%d enemies=%d civs=%d crew=[%s]" % [worst, rt.heist_time_s,
			rt.phase, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			_alive_in(G.ENEMY), _alive_in(G.CIVILIAN), " ".join(cs)])
		_tel_n += 1
		if _tel_n % 6 == 0:
			_census()


## Every 60 s of game time (LEAD GPU-20c, hitch build-up): physics server load, nodes by class and the parents with
## the most children, to find what accumulates over a long loud heist.
func _census() -> void:
	var by_class: Dictionary = {}
	var by_parent: Dictionary = {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var k: String = n.get_class()
		by_class[k] = int(by_class.get(k, 0)) + 1
		var cc: int = n.get_child_count()
		if cc >= 20:
			by_parent[String(n.get_path()).trim_prefix("/root/")] = cc
		for ch: Node in n.get_children():
			stack.append(ch)
	var cls: Array = by_class.keys()
	cls.sort_custom(func(a: String, b: String) -> bool: return by_class[a] > by_class[b])
	var par: Array = by_parent.keys()
	par.sort_custom(func(a: String, b: String) -> bool: return by_parent[a] > by_parent[b])
	note("CENSUS t=%.0f phys_active=%d pairs=%d islands=%d dead_npcs=%d classes={%s} parents={%s}" % [rt.heist_time_s,
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS),
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_COLLISION_PAIRS),
		PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ISLAND_COUNT),
		get_tree().get_nodes_in_group(G.ENEMY).size() - _alive_in(G.ENEMY),
		", ".join(cls.slice(0, 18).map(func(c: String) -> String: return "%s:%d" % [c, by_class[c]])),
		", ".join(par.slice(0, 10).map(func(c: String) -> String: return "%s:%d" % [c, by_parent[c]]))])


## After heist_ended: screenshot the payday, click through it like a player until the hub shows.
func payday_to_hub() -> int:
	set_fast(false)
	await seconds(3.0)
	await shot("payday")
	note("payday buttons: %s" % [visible_buttons()])
	for i: int in 12:
		if find_button("Planning Table") != null or _in_3d_hub():
			await shot("back_in_hub")
			note("back in the hub%s" % (" (3D safehouse, walker spawned)" if _in_3d_hub() else ""))
			return 0
		var clicked: bool = false
		for label: String in ["Continue", "Skip", "Next", "Collect", "Done", "Back to Safehouse", "Safehouse", "OK"]:
			var b: Button = find_button(label)
			if b != null and _button_label(b).contains(" · "):
				b = null  # the main menu's Quick Play "CONTINUE · <heist> · <difficulty>" starts a new heist (r278)
			if b != null:
				await click_control(b)
				clicked = true
				break
		if not clicked:
			clicked = await _pick_payday_card()
		if not clicked:
			note("payday: nothing to click; buttons %s" % [visible_buttons()])
		await seconds(2.0)
		await shot("payday_%d" % i)
	note("FAIL PO-5.payday: never got back to the hub; buttons %s" % [visible_buttons()])
	return 1


## Since C's 3D safehouse (B6-06) the hub is MenuFlow's SafehouseHost: back home = its scene is up with our walker.
func _in_3d_hub() -> bool:
	for n: Node in get_tree().root.find_children("*", "SafehouseHost", true, false):
		var h: SafehouseHost = n as SafehouseHost
		if h != null and h.is_active() and h.walker != null and is_instance_valid(h.walker):
			return true
	return false


## The Payday card pick: three unlabelled card buttons and a disabled Continue. Click the first card like
## a player would; the reveal then enables Continue.
func _pick_payday_card() -> bool:
	for n: Node in get_tree().root.find_children("*", "Button", true, false):
		var b: Button = n as Button
		if b.is_visible_in_tree() and not b.disabled and _button_label(b).strip_edges() == "":
			note("payday: picking a card")
			await click_control(b)
			return true
	return false


## PO-5.1: the game owns the mouse (MouseCapture, D-087). Like a player: wait for the capture, else click
## the game view once. Only if that fails too does the harness force it (logged as a FINDING for ENV P).
func capture_like_player() -> void:
	await wait_s(1.0)
	if not MouseCapture.is_captured():
		var vp: Viewport = get_viewport()
		var mid: Vector2 = vp.get_visible_rect().size * 0.5
		for pressed: bool in [true, false]:
			var mb: InputEventMouseButton = InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = pressed
			mb.position = vp.get_final_transform() * mid
			mb.global_position = mb.position
			Input.parse_input_event(mb)
			await get_tree().process_frame
		await wait_s(0.5)
	if MouseCapture.is_captured():
		note("mouse captured by the game (MouseCapture)")
	elif DisplayServer.get_name() == "headless":
		# GN-8 headless e2e: the headless DisplayServer cannot capture the mouse, so PlayerInput ignored every look
		# motion (the pilot stood in the vestibule). P's test hook lets the same relative motion events through.
		note("headless: no mouse capture; PlayerInput.test_assume_captured for the look motion")
		PlayerInput.test_assume_captured = true
	else:
		note("FINDING PO-5.1: mouse not captured after a click in the game view; harness forces it (mode %d)"
			% Input.mouse_mode)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Wall-clock budget (--po5-budget=<s>): screenshot + exit 2 when exceeded (release check never hangs).
func _watchdog() -> void:
	await get_tree().create_timer(_budget_s, true, false, true).timeout
	note("FAIL budget %.0f s exceeded" % _budget_s)
	await shot("budget_exceeded")
	_finish(2)


## Live NPCs in `group` (corpses stay in their groups).
func _alive_in(group: StringName) -> int:
	var n: int = 0
	for x: Node in get_tree().get_nodes_in_group(group):
		n += 1 if x is NpcBase and (x as NpcBase).is_alive() else 0
	return n


## Game-time wait (physics ticks).
func wait_s(s: float) -> void:
	for _i: int in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func dump_map() -> void:
	note("variants: %s" % [rt.variants])
	for n: Node in get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		var o: Node = c.owner_node()
		var tag: Variant = o.get(&"objective_tag") if o != null else null
		note("IA %s kind=%s en=%s vis=%s pos=%s tag=%s item=%s owner=%s" % [c.get_path(), c.kind, c.enabled,
			c.is_visible_in_tree(), Po5Pilot._v(c.global_position), tag, c.requires_item,
			o.get_class() if o != null else "-"])
	for n2: Node in get_tree().get_nodes_in_group(G.NPC):
		note("NPC %s at %s" % [n2.name, Po5Pilot._v((n2 as Node3D).global_position)])
	for o2: Dictionary in rt.mission.objectives():
		note("OBJ %s" % [o2])


## Finds a visible Button whose text contains `text` (case-insensitive) under the root.
func find_button(text: String, root: Node = null) -> Button:
	if root == null:
		root = get_tree().root
	for n: Node in root.find_children("*", "BaseButton", true, false):
		var b: BaseButton = n as BaseButton
		if b is Button and b.is_visible_in_tree() and not b.disabled \
				and _button_label(b as Button).to_lower().contains(text.to_lower()):
			return b as Button
	return null


## Clicks like a person: mouse motion to the control's centre, press, release (window coordinates).
func click_control(c: Control) -> void:
	var label: String = (c as Button).text if c is Button else String(c.name)  # c may be freed by the click
	var canvas_pos: Vector2 = c.get_global_rect().get_center()
	var win_pos: Vector2 = c.get_viewport().get_final_transform() * canvas_pos
	var mm: InputEventMouseMotion = InputEventMouseMotion.new()
	mm.position = win_pos
	mm.global_position = win_pos
	Input.parse_input_event(mm)
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var mb: InputEventMouseButton = InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = win_pos
		mb.global_position = win_pos
		Input.parse_input_event(mb)
		await get_tree().process_frame
	note("click '%s' at %s" % [label, win_pos])


func click_text(text: String, timeout_s: float = 20.0) -> bool:
	var b: Button = find_button(text)
	var t0: int = Time.get_ticks_msec()
	while b == null and Time.get_ticks_msec() - t0 < int(timeout_s * 1000.0):
		await get_tree().process_frame
		b = find_button(text)
	if b == null:
		note("NO BUTTON '%s'; visible: %s" % [text, visible_buttons()])
		return false
	await click_control(b)
	return true


## Button text, else its first descendant Label's text (card buttons draw their title in a Label).
static func _button_label(b: Button) -> String:
	if b.text != "":
		return b.text
	for l: Node in b.find_children("*", "Label", true, false):
		if (l as Label).text != "":
			return (l as Label).text
	return ""


func visible_buttons() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for n: Node in get_tree().root.find_children("*", "Button", true, false):
		if (n as Button).is_visible_in_tree():
			out.append(_button_label(n as Button))
	return out


func _scene_summary() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c: Node in get_tree().root.get_children():
		parts.append("%s(%s)" % [c.name, c.get_class()])
	return ", ".join(parts)


func _fail(msg: String) -> void:
	note("FAIL " + msg)
	await shot("fail")
	_finish(1)


func seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func set_fast(on: bool) -> void:
	fast = on
	RenderingServer.render_loop_enabled = not on
	_hud_redraw_widgets(not on)


## Harness workaround (PO-5 stealth finding): with the render loop off, the HUD still does its per-frame
## canvas work (markers, cards, prompts) and single process frames grow to 7-20 s under llvmpipe (game
## time up to ~85x slower than wall time once masked). The HUD canvas layers are hidden while the loop is
## off and shown again for every screenshot. Presentation only: gameplay is untouched.
func _hud_redraw_widgets(show: bool) -> void:
	for n: Node in get_tree().root.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = show


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		note("shot %s skipped (headless)" % label)  # GN-8: headless e2e runs (no viewport image to save)
		return
	var was_fast: bool = fast
	if was_fast:
		_hud_redraw_widgets(true)
		RenderingServer.render_loop_enabled = true
		await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_shot += 1
	var path: String = "%s/%02d_%s.png" % [runner_out, _shot, label]
	img.save_png(path)
	_shot_frame = true  # GPU-13: the readback + PNG is the long frame: HITCH lines mark it shot=1
	if was_fast:
		RenderingServer.render_loop_enabled = false
		_hud_redraw_widgets(false)
	note("shot %s" % path)


func note(msg: String) -> void:
	var line: String = "[PO5 %.1fs] %s" % [Time.get_ticks_msec() / 1000.0, msg]
	print(line)
	_log.append(line)


## One --po5-hitch-ms line: shot frame, pipeline compilations and VRAM (render side), process / physics, draws, spawns,
## FrameProf's top systems.
func _note_hitch(frame_ms: float) -> void:
	var head: String = "HITCH shot=%d pipelines=%s vram=%dMB frame=%.0fms t=%.1f" % [1 if _shot_frame else 0,
		_pipeline_delta(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576,
		frame_ms, rt.heist_time_s]
	note("%s process=%.1fms physics=%.1fms draws=%d objects=%d nodes=%d enemies=%d spawned=%s top: %s" % [head,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), _alive_in(G.ENEMY), _spawned_this_frame, FrameProf.top(8)])


## LEAD (GPU-12): pipeline compilations since the last frame, by kind (mesh / surface / draw / specialization / canvas):
## a render-side hitch with compilations in it is a first-use shader / pipeline compile (prewarm material + mesh).
func _pipeline_delta() -> String:
	var now: PackedInt64Array = _pipelines_now()
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(now.size()):
		var d: int = now[i] - (_pipelines_seen[i] if i < _pipelines_seen.size() else 0)
		if d > 0:
			parts.append("%s+%d" % [PIPELINE_KINDS[i], d])
	return "[%s]" % " ".join(parts)


## Sum of every pipeline-compilation counter (_pipelines_now).
func _pipelines_total() -> int:
	var n: int = 0
	for v: int in _pipelines_now():
		n += v
	return n


## True while MenuFlow's loading screen (a LoadingScreen under a root CanvasLayer) is up.
func _loading_up() -> bool:
	for n: Node in get_tree().root.get_children():
		if n is CanvasLayer:
			for c: Node in n.get_children():
				if c is LoadingScreen and (c as CanvasItem).is_visible_in_tree():
					return true
	return false


## LOAD line: the pipelines compiled under the loading screen and over the first LOAD_FRAMES rendered heist frames (with
## the longest of them): compiles after the loading screen are the ones a player sees as the first-frame hitch.
func _load_report(pipes0: int) -> void:
	var under: int = _pipelines_total() - pipes0
	var worst: float = 0.0
	for i: int in range(LOAD_FRAMES):
		var t0: int = Time.get_ticks_usec()
		if DisplayServer.get_name() == "headless":
			await get_tree().process_frame  # frame_post_draw never fires on the dummy renderer
		else:
			await RenderingServer.frame_post_draw
		worst = maxf(worst, (Time.get_ticks_usec() - t0) / 1000.0)
	note("LOAD pipelines compiled under the loading screen %d, over the first %d heist frames %d (worst frame %.0f ms) t=%.1f"
		% [under, LOAD_FRAMES, _pipelines_total() - pipes0 - under, worst, rt.heist_time_s])


func _pipelines_now() -> PackedInt64Array:
	return PackedInt64Array([
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS)])


## The --po5-hitch-ms summary, once (heist end or _finish: budget exit / FAIL). Screenshot frames are counted apart.
func _note_hitches() -> void:
	if _render_hitch_ms <= 0.0 or _hitches_noted:
		return
	_hitches_noted = true
	note("HITCHES %d of %d heist frames over %.0f ms (%d of them screenshot frames), worst %.0f ms, without a shot %.0f ms"
		% [_render_hitches, _heist_frames, _render_hitch_ms, _shot_hitches, _heist_worst_ms, _heist_worst_noshot_ms])


func _finish(code: int) -> void:
	_note_hitches()
	if stats != null:
		note(stats.summary())
	note("RESULT %s (code %d) flow=%s heist=%s seed=%d" % ["PASS" if code == 0 else "FAIL", code, runner_flow,
		heist_name, run_seed])
	RenderingServer.render_loop_enabled = true
	var f: FileAccess = FileAccess.open("%s/po5_log.txt" % runner_out, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log))
	get_tree().quit(code)
