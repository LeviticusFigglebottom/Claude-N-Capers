## Worker for heist_tips_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const HUD_SCENE: String = "res://content/ui/hud/hud.tscn"

var _out: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/heist_tips"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	UiScreen.motion_enabled = false
	OnboardingTips.persist = false
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.16, 0.17, 0.19)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = -1
	layer.add_child(bg)
	add_child(layer)
	for h: StringName in OnboardingTips.HEISTS:
		OnboardingTips.reset()
		for id: StringName in OnboardingTips.ALL:
			OnboardingTips.mark_seen(id)  # a returning player: the heist card is the only one left
		var model: MockHudModel = MockHudModel.new()
		model.casing = false
		add_child(model)
		var hud: Hud = (load(HUD_SCENE) as PackedScene).instantiate() as Hud
		hud.auto_find_model = false
		hud.heist_id = h
		add_child(hud)
		await get_tree().process_frame
		hud.onboarding.show_delay_s = 0.0
		hud.bind(model)
		model.player_mode = &"casing"
		for _i: int in range(20):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/tip_%s_%dx%d.png" % [_out, h, img.get_width(), img.get_height()]
		img.save_png(path)
		print("TIP SHOT ", path, " shown=", hud.onboarding.shown)
		hud.queue_free()
		model.queue_free()
		await get_tree().process_frame
	get_tree().quit()
