## Worker for hud_crowd_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const HUD_SCENE: String = "res://content/ui/hud/hud.tscn"
## LEAD r229 crowding pass: every heist loud (hip and scoped), plus GN stealth (pagers).
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn",
		&"gallery_night"]
const RING: Rect2 = Rect2(465, 43, 994, 994)

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/hud_crowd"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	OnboardingTips.persist = false
	for h: StringName in HEISTS:
		await _loud(h, false)
		await _loud(h, true)
	await _loud(&"glasshouse", false, false)  # the tip card shows when no toast is up (Hud hides it under one)
	await _loud(&"glasshouse", true, false)
	await _moment(&"gn_stealth")
	get_tree().quit()


## One loud moment on heist `h`: the heist's first two objectives, a jammed drill + a hack, an assault banner with
## an event, a captain, two detection rings (one red), a toast, the "loud" tip card, three subtitles; `scoped` adds
## P's ring (stand-in black mask) and an interaction prompt.
func _loud(h: StringName, scoped: bool, toast: bool = true) -> void:
	var w: Dictionary = _world()
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = (load(HUD_SCENE) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	hud.heist_id = h
	add_child(hud)
	await get_tree().process_frame
	hud.onboarding.show_delay_s = 0.0
	hud.bind(model)
	var drv: MockHudDriver = MockHudDriver.new()
	drv.model = model
	drv.setup_initial()
	drv.free()
	var sub: SubtitleOverlay = SubtitleOverlay.new()
	add_child(sub)
	model.casing = false
	model.masked = true
	model.player_mode = &"masked"
	model.heist_phase = Enums.HeistPhase.LOUD
	model.assault_phase = Enums.AssaultPhase.SUSTAIN
	model.assault_wave = 3
	model.captain_present = true
	model.captain_resistance = 0.4
	model.hostages = 1
	var def: HeistDef = HeistRegistry.get_def(h)
	var objs: Array[Dictionary] = []
	for i: int in range(mini(2, def.objectives.size())):
		var id: StringName = def.objectives[i]
		objs.append({"id": id, "text_key": StringName("objective.%s.%s" % [h, id]), "args": {"count": 1, "total": 4,
				"found": 1, "drives_secured": 1, "drives": 2}, "state": Enums.ObjectiveState.ACTIVE,
				"device_net_id": int(w["drill_id"]) if i == 0 else -1})
	model.objectives = objs
	model.devices = [
		{"net_id": int(w["drill_id"]), "kind": &"drill", "world_pos": (w["drill"] as Node3D).position, "progress": 0.4,
				"time_left_s": 71.0, "state": &"jammed", "fix_prompt_key": &"ui.prompt.fix_drill"},
		{"net_id": int(w["hack_id"]), "kind": &"hack", "world_pos": (w["hack"] as Node3D).position, "progress": 0.7,
				"time_left_s": 22.0, "state": &"running"}]
	model.detection = [
		{"observer_net_id": int(w["guard_id"]), "world_pos": (w["guard"] as Node3D).position, "value": 1.0,
				"kind": Enums.ObserverKind.POLICE},
		{"observer_net_id": 99, "world_pos": Vector3(-6.0, -1.0, -3.0), "value": 0.6, "kind": Enums.ObserverKind.GUARD}]
	if scoped:
		model.interaction = {"text_key": &"ui.prompt.fix_drill", "args": {"key": "F"}, "progress": 0.3,
				"blocked_reason": &""}
		model.scope_ring = RING
		model.scoped_ads = true
		_mask()
	else:
		model.interaction = {}
	EventBus.assault_event_started.emit(&"turret_van", int(w["event_id"]), (w["event"] as Node3D).position)
	hud.onboarding._show(&"loud")
	if toast:
		hud.toast(&"ui.hud.assault_event.turret_van", {}, 30.0)
	sub.show_line(&"mercer", &"vo.mercer.abort", {"source": ContactRadio.SOURCE})
	sub.show_line(&"rook", &"vo.rook.cops_incoming_1", {})
	for _i: int in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/loud_%s_%s%s_%dx%d.png" % [_out, h, "scoped" if scoped else "hip", "" if toast else "_card",
			img.get_width(), img.get_height()]
	img.save_png(path)
	print("CROWD SHOT ", path, " docked=", hud._docked.size(), " toast=", hud.toast_label.visible, " card=",
			hud.onboarding.visible)
	EventBus.assault_event_ended.emit(&"turret_van", int(w["event_id"]))
	hud.queue_free()
	sub.queue_free()
	model.queue_free()
	(w["world"] as Node).queue_free()
	for c: Node in get_children():
		if c is CanvasLayer:
			c.queue_free()
	await get_tree().process_frame


## Stand-in for P's scope overlay: black outside the ring (under the HUD, over the world).
func _mask() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var c: Control = Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(func() -> void:
		c.draw_arc(RING.get_center(), RING.size.x * 0.5 + 700.0, 0.0, TAU, 160, Color.BLACK, 1400.0))
	layer.add_child(c)


## A tiny world in front of the camera: device panels, a paged guard and an assault event need world positions.
func _world() -> Dictionary:
	var w: Node3D = Node3D.new()
	add_child(w)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.30, 0.27)
	w.add_child(env)
	var cam: Camera3D = Camera3D.new()
	w.add_child(cam)
	cam.current = true
	var out: Dictionary = {"world": w}
	for n: String in ["drill", "hack", "guard", "event"]:
		var node: Node3D = Node3D.new()
		w.add_child(node)
		out[n] = node
		var id: int = Ids.next()
		Ids.register(id, node)
		out[n + "_id"] = id
	(out["drill"] as Node3D).position = Vector3(-1.6, -0.6, -5.0)
	(out["hack"] as Node3D).position = Vector3(1.2, -0.3, -6.5)
	(out["guard"] as Node3D).position = Vector3(2.4, -1.4, -7.0)
	(out["event"] as Node3D).position = Vector3(-3.0, 0.5, -14.0)
	return out


func _moment(m: StringName) -> void:
	var w: Dictionary = _world()
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = (load(HUD_SCENE) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	hud.heist_id = &"glasshouse" if m == &"gh_loud" else &"gallery_night"
	add_child(hud)
	await get_tree().process_frame
	hud.onboarding.show_delay_s = 0.0
	hud.bind(model)
	var drv: MockHudDriver = MockHudDriver.new()
	drv.model = model
	drv.setup_initial()
	drv.free()
	var sub: SubtitleOverlay = SubtitleOverlay.new()
	add_child(sub)
	model.crew = [
		MockHudDriver._mate(1, "crew.sable", 0.6, 0.3, Enums.CrewState.NORMAL),
		MockHudDriver._mate(2, "crew.dutch", 0.2, 0.0, Enums.CrewState.DOWNED),
		MockHudDriver._mate(3, "crew.wren", 1.0, 0.8, Enums.CrewState.NORMAL),
	]
	if m == &"gh_loud":
		model.casing = false
		model.masked = true
		model.player_mode = &"masked"
		model.heist_phase = Enums.HeistPhase.LOUD
		model.assault_phase = Enums.AssaultPhase.SUSTAIN
		model.assault_wave = 2
		model.captain_present = true
		model.captain_resistance = 0.25
		model.warnings = [&"phantom", &"captain"]
		model.hostages = 2
		model.carried_bag = {"loot_id": &"loot.jewelry", "weight": Enums.LootWeight.LIGHT}
		model.objectives = [
			{"id": &"safe", "text_key": &"objective.glasshouse.safe", "args": {}, "state": Enums.ObjectiveState.ACTIVE,
					"device_net_id": int(w["drill_id"])},
			{"id": &"secure", "text_key": &"objective.glasshouse.secure", "args": {"count": 1, "total": 4},
					"state": Enums.ObjectiveState.ACTIVE},
		]
		model.devices = [{"net_id": int(w["drill_id"]), "kind": &"drill", "world_pos": (w["drill"] as Node3D).position,
				"progress": 0.4, "time_left_s": 71.0, "state": &"jammed", "fix_prompt_key": &"ui.prompt.fix_drill"}]
		model.interaction = {"text_key": &"ui.prompt.fix_drill", "args": {"key": "F"}, "progress": 0.3, "blocked_reason": &""}
		EventBus.assault_event_started.emit(&"turret_van", int(w["event_id"]), (w["event"] as Node3D).position)
		hud.toast(&"ui.hud.assault_event.turret_van")
		sub.show_line(&"mercer", &"vo.mercer.abort", {"source": ContactRadio.SOURCE})
		sub.show_line(&"rook", &"vo.rook.cops_incoming_1", {})
		sub.show_line(&"guard", &"vo.guard.cuff_warning", {})
	else:
		model.casing = false
		model.masked = true
		model.player_mode = &"masked"
		model.heist_phase = Enums.HeistPhase.STEALTH
		model.pagers_answered = 1
		EventBus.pager_started.emit(7, int(w["guard_id"]))
		model.pagers = [{"pager_id": 7, "time_left_s": 8.2, "answering": true, "progress": 0.45}]
		model.detection = [{"observer_net_id": int(w["guard_id"]), "value": 0.6, "world_pos": Vector3(5.0, 0.0, -2.0)}]
		model.objectives = [
			{"id": &"hack", "text_key": &"objective.gallery_night.hack", "args": {}, "state": Enums.ObjectiveState.ACTIVE,
					"device_net_id": int(w["hack_id"])},
			{"id": &"find_canvases", "text_key": &"objective.gallery_night.find_canvases",
					"args": {"found": 2, "total": 4}, "state": Enums.ObjectiveState.ACTIVE},
		]
		model.devices = [{"net_id": int(w["hack_id"]), "kind": &"hack", "world_pos": (w["hack"] as Node3D).position,
				"progress": 0.6, "time_left_s": 38.0, "state": &"paused"}]
		model.interaction = {"text_key": &"ui.prompt.answer_pager", "args": {"key": "F"}, "progress": 0.45,
				"blocked_reason": &""}
		sub.show_line(&"vance", &"vo.vance.gallery_night_radio_canvases_done", {"source": ContactRadio.SOURCE})
		sub.show_line(&"sable", &"vo.sable.pager_started_1", {})
		sub.show_line(&"mercer", &"vo.mercer.gallery_night_last_call", {"source": ContactRadio.SOURCE})
	for _i: int in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/crowd_%s_%dx%d.png" % [_out, m, img.get_width(), img.get_height()]
	img.save_png(path)
	print("CROWD SHOT ", path, " onboarding=", hud.onboarding.shown, " subs=", sub.rows.size())
	EventBus.assault_event_ended.emit(&"turret_van", int(w["event_id"]))
	hud.queue_free()
	sub.queue_free()
	model.queue_free()
	(w["world"] as Node).queue_free()
	await get_tree().process_frame
