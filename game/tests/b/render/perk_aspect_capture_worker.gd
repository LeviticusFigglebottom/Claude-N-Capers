## Worker for perk_aspect_capture.gd (autoloads are up by now).
extends Node

const SLOT: int = 7

var _out: String = ""
var _n: int = 0


func _ready() -> void:
	_run.call_deferred()


func _shot(name: String, frames: int = 10) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_n += 1
	img.save_png("%s/%02d_%s_%dx%d.png" % [_out, _n, name, img.get_width(), img.get_height()])


func _run() -> void:
	_out = OS.get_cmdline_user_args()[0]
	SaveService.root_dir = BTestUtil.profile_root()
	OnboardingTips.persist = false
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var p: PlayerProfile = PlayerProfile.new_default()
	p.loadout.perk_deck = &"perk.understudy"
	p.loadout.perk_deck_cards = 9
	p.loadout.perk_choices = {0: 1, 2: 0, 4: 0, 6: 3}
	p.loadout.perk_mimic_deck = &"perk.frenzy"
	SaveService.save_profile(p, SLOT)
	await _decks(p)
	await _loadout(p)
	await _hud()
	SaveService.delete_profile(SLOT)
	get_tree().quit(0)


func _decks(p: PlayerProfile) -> void:
	var s: PerkDeckScreen = (load("res://content/ui/progression/perk_deck_screen.tscn") as PackedScene).instantiate() as PerkDeckScreen
	s.profile_slot = SLOT
	s.setup(p)
	get_tree().root.add_child(s)
	await get_tree().process_frame
	for d: StringName in [&"perk.understudy", &"perk.lifeline", &"perk.veil"]:
		s.preview(d)
		s.card_panels[0].grab_focus()
		await _shot("deck_" + String(d).trim_prefix("perk."))
	s.preview(&"perk.understudy")
	s.card_panels[8].grab_focus()
	await _shot("deck_understudy_card9")
	s.queue_free()
	await get_tree().process_frame


func _loadout(_p: PlayerProfile) -> void:
	var flow: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	flow.profile_slot = SLOT
	get_tree().root.add_child(flow)
	for _i: int in range(4):
		await get_tree().process_frame
	flow.show_hub()
	flow.open_station(&"armory")
	await _shot("loadout_perk_line", 16)
	flow.queue_free()
	await get_tree().process_frame


func _hud() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.25, 0.27, 0.3)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(bg)
	var m: MockHudModel = MockHudModel.new()
	get_tree().root.add_child(m)
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	get_tree().root.add_child(hud)
	await get_tree().process_frame
	hud.bind(m)
	m.masked = true
	m.casing = false
	m.health = 60.0
	m.max_health = 100.0
	m.max_armor = 50.0
	var crew: Array[Dictionary] = []
	for slot: int in [1, 2, 3]:
		crew.append({"slot": slot, "name": "Crew %d" % slot, "health_frac": 0.8, "armor_frac": 0.5,
			"state": Enums.CrewState.NORMAL, "downs_left": 3})
	m.crew = crew
	var states: Array = [
		["hud_leech", &"throwable.leech_ampule", {"kind": &"leech_ampule", "charges": 0, "max": 1, "cooldown_left": 40.0,
			"active_left": 5.2, "partner_slot": -1, "mode": &"", "segments": {"count": 3, "size": 5}}],
		["hud_gas_paired", &"throwable.gas_dispenser", {"kind": &"gas_dispenser", "charges": 0, "max": 1,
			"cooldown_left": 55.0, "active_left": 8.0, "partner_slot": 2, "mode": &""}],
		["hud_pocket_ecm_jam", &"throwable.pocket_ecm", {"kind": &"pocket_ecm", "charges": 1, "max": 2,
			"cooldown_left": 90.0, "active_left": 4.3, "partner_slot": -1, "mode": &"jam"}]]
	for st: Array in states:
		m.throwable_id = st[1]
		m.perk_item = st[2]
		await _shot(st[0])
	hud.queue_free()
	m.queue_free()
	bg.queue_free()
