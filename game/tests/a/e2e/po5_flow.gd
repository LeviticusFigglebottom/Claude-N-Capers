## PO-5 driver node (lives on the root, survives scene changes). See po5_runner.gd.
extends Node

## A fast-mode (not rendered) frame longer than this prints a HITCH line with FrameProf's top systems (ms).
const HITCH_MS: float = 1000.0

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
## llvmpipe renders at ~1 fps, which caps game time at 8 physics ticks per second. Between screenshots
## the harness turns the render loop off (window, DisplayServer and input stay real); shot() renders.
var fast: bool = false
var _shot: int = 0
var _log: PackedStringArray = PackedStringArray()
var _worst_frame_ms: float = 0.0
var _last_frame_us: int = 0
var _was_rendering: bool = true
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
	if _budget_s > 0.0:
		_watchdog.call_deferred()
	if not await enter_heist():
		return
	var outcome: Array[int] = [-1]  # heist_ended success: -1 not ended, 0 failed, 1 succeeded
	EventBus.heist_ended.connect(func(r: Dictionary) -> void: outcome[0] = 1 if bool(r.get("success", false)) else 0)
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


## main menu -> Safehouse -> Planning Table -> heist -> difficulty -> Briefing -> Continue -> Confirm plan
## -> Start Heist, by mouse clicks; then waits for the local crew to spawn.
func enter_heist() -> bool:
	var t0: int = Time.get_ticks_msec()
	while find_button("Safehouse") == null and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	await shot("main_menu")
	for step: String in ["Safehouse", "Planning Table", heist_name, difficulty_name, "Briefing", "Continue",
			"Confirm plan", "Start Heist"]:
		if not await click_text(step):
			await _fail("menu: no '%s'" % step)
			return false
		await seconds(1.0)
		if step in ["Planning Table", "Briefing", "Continue", "Confirm plan"]:
			await shot(step.to_snake_case())
	set_fast(true)
	FrameProf.enabled = true  # per-system cost for HITCH lines (ND t=322 stall hunt)
	var t: float = 0.0
	while t < 60.0:
		rt = HeistRuntime.current()
		if rt != null and rt.crew_controller(0) != null:
			break
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	if rt == null or rt.crew_controller(0) == null:
		await _fail("heist did not start within 60 s of Start Heist")
		return false
	crew = rt.crew_controller(0) as CrewController
	await wait_s(1.0)
	run_seed = rt.run_seed
	note("in heist %s seed %d diff %d phase %d crew at %s" % [rt.heist_id, rt.run_seed, rt.difficulty, rt.phase,
		Po5Pilot._v(crew.global_position)])
	if rt.options.has("crew_damage_taken_mult"):
		note("DEV OPTION crew_damage_taken_mult=%.2f (D-133 harness-only; assault events on)" % float(
			rt.options["crew_damage_taken_mult"]))
	await shot("heist_start")
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
	if _last_frame_us != 0:
		var frame_ms: float = (now - _last_frame_us) / 1000.0
		_worst_frame_ms = maxf(_worst_frame_ms, frame_ms)
		# Rendered frames (llvmpipe screenshots, menus) are slow by design: only fast-mode frames count.
		if frame_ms > HITCH_MS and not rendering and not _was_rendering and rt != null and is_instance_valid(rt):
			note("HITCH frame=%.0fms t=%.1f nodes=%d enemies=%d top: %s" % [frame_ms, rt.heist_time_s,
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT), _alive_in(G.ENEMY), FrameProf.top(10)])
	FrameProf.reset_frame()
	_was_rendering = rendering
	_last_frame_us = now


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


## After heist_ended: screenshot the payday, click through it like a player until the hub shows.
func payday_to_hub() -> int:
	set_fast(false)
	await seconds(3.0)
	await shot("payday")
	note("payday buttons: %s" % [visible_buttons()])
	for i: int in 12:
		if find_button("Planning Table") != null:
			await shot("back_in_hub")
			note("back in the hub")
			return 0
		var clicked: bool = false
		for label: String in ["Continue", "Skip", "Next", "Collect", "Done", "Back to Safehouse", "Safehouse", "OK"]:
			var b: Button = find_button(label)
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
	if was_fast:
		RenderingServer.render_loop_enabled = false
		_hud_redraw_widgets(false)
	note("shot %s" % path)


func note(msg: String) -> void:
	var line: String = "[PO5 %.1fs] %s" % [Time.get_ticks_msec() / 1000.0, msg]
	print(line)
	_log.append(line)


func _finish(code: int) -> void:
	note("RESULT %s (code %d) flow=%s heist=%s seed=%d" % ["PASS" if code == 0 else "FAIL", code, runner_flow,
		heist_name, run_seed])
	RenderingServer.render_loop_enabled = true
	var f: FileAccess = FileAccess.open("%s/po5_log.txt" % runner_out, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log))
	get_tree().quit(code)
