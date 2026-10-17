## Worker for hud_scope_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const HUD_SCENE: String = "res://content/ui/hud/hud.tscn"
## P's ring on the 1920x1080 canvas (r228 capture).
const RING: Rect2 = Rect2(465, 43, 994, 994)

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/hud_scope"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	OnboardingTips.persist = false
	await _shot(false, 3.5)
	await _shot(true, 1.6)
	await _shot(true, 3.5)
	InteractionPanel.pad_active = true  # LEAD r229 reach pass: the docked prompt names the pad button
	await _shot(true, 1.6, "_pad")
	InteractionPanel.pad_active = false
	get_tree().quit()


func _shot(scoped: bool, dist: float, tag: String = "") -> void:
	var w: Node3D = Node3D.new()
	add_child(w)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.52, 0.47)
	w.add_child(env)
	var cam: Camera3D = Camera3D.new()
	w.add_child(cam)
	cam.current = true
	cam.fov = 18.0 if scoped else 75.0
	var drill: Node3D = Node3D.new()
	w.add_child(drill)
	drill.position = Vector3(0.0, -0.15 if scoped else 0.8, -dist)  # hip: its panel on the toast line (P's shot)
	var box: MeshInstance3D = MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	(box.mesh as BoxMesh).size = Vector3(0.5, 0.6, 0.4)
	drill.add_child(box)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	w.add_child(light)
	var id: int = Ids.next()
	Ids.register(id, drill)
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = (load(HUD_SCENE) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	hud.heist_id = &"glasshouse"
	add_child(hud)
	await get_tree().process_frame
	hud.onboarding.show_delay_s = 0.0
	hud.bind(model)
	var drv: MockHudDriver = MockHudDriver.new()
	drv.model = model
	drv.setup_initial()
	drv.free()
	model.casing = false
	model.masked = true
	model.player_mode = &"masked"
	model.heist_phase = Enums.HeistPhase.LOUD
	model.assault_phase = Enums.AssaultPhase.ANTICIPATION
	model.assault_wave = 1
	model.devices = [{"net_id": id, "kind": &"drill", "world_pos": drill.position, "progress": 0.4,
			"time_left_s": 71.0, "state": &"jammed", "fix_prompt_key": &"ui.prompt.fix_drill"}]
	if dist < 2.0:
		model.interaction = {"text_key": &"ui.prompt.fix_drill", "args": {}, "progress": 0.0,
				"blocked_reason": &""}
	var mask: Control = null
	if scoped:
		hud.onboarding._show(&"loud")
		model.scope_ring = RING
		model.scoped_ads = true
		mask = _mask()
	else:
		hud.toast(&"ui.hud.alarm", {}, 30.0)
	for _i: int in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/scope_%s_%s%s_%dx%d.png" % [_out, "scoped" if scoped else "hip", ("%.1fm" % dist).replace(".",
			"m").trim_suffix("m"), tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("SCOPE SHOT ", path, " docked=", hud._docked.size(), " plated=", hud.interaction.plated)
	hud.queue_free()
	model.queue_free()
	w.queue_free()
	if mask != null:
		mask.get_parent().queue_free()
	await get_tree().process_frame


## Stand-in for P's scope overlay: black outside the ring (drawn under the HUD, over the world).
func _mask() -> Control:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var c: Control = Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(func() -> void:
		var r: float = RING.size.x * 0.5
		c.draw_arc(RING.get_center(), r + 700.0, 0.0, TAU, 160, Color.BLACK, 1400.0))
	layer.add_child(c)
	return c
