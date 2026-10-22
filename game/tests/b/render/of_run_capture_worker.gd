## Worker for of_run_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const HEIST: StringName = &"ostrander_federal"
const SLOT: int = 0
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
## Objectives whose ACTIVE turn gets a HUD shot (the chain at its longest, the device timers, the endgame).
const SHOOT_AT: Dictionary = {
	&"stealth": [&"vault_gate", &"time_lock_wait", &"secure", &"escape"],
	&"loud": [&"drill_delivery", &"vault_drill", &"hoist", &"escape_wait"],
}

var _out: String = ""
var _modes: Array[StringName] = [&"pager", &"stealth", &"loud"]
var _issues: int = 0
var _hud: Hud = null
var _pd: PaydayScreen = null
var _layer: CanvasLayer = null
var _mode: StringName = &""
var _shots: Array[String] = []
var _busy: bool = false
var _pager_shot: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/of_run"
	if args.size() > 1:
		_modes = [StringName(args[1])]
	DirAccess.make_dir_recursive_absolute(_out)
	SaveService.root_dir = "user://of_run_profiles_%d" % OS.get_process_id()  # LEAD r252: not into the out dir (repo tree)
	_run.call_deferred()


func _run() -> void:
	for m: StringName in _modes:
		await _play(m)
	print("OFRUN DONE %d" % _issues)
	get_tree().quit(0)


## "pager": the pager row on OF without a full run. Stated shortcut: one real pager is started on a live guard through
## the run's PagerSystem (as if he had just been killed); the HUD is shot while it rings, then the run is torn down.
func _pager() -> void:
	_mode = &"pager"
	_spawn_ui()
	var flow: X4StealthFlow = X4StealthFlow.new(self)
	if await flow.launch(HEIST, 18):
		var pagers: PagerSystem = flow.rt.find_child("PagerSystem", true, false) as PagerSystem
		var guard: NpcBase = null
		for n: Node in flow.rt.npcs():
			if (n as NpcBase).role == &"guard" and not n.is_in_group(&"camera_operator"):
				guard = n as NpcBase
				break
		if pagers == null or guard == null:
			_issue("pager", "no PagerSystem or guard")
		else:
			pagers.start_pager(guard)
			for _i: int in range(90):
				await get_tree().physics_frame
			await _hud_shot("pager")
	await flow.teardown()
	_layer.queue_free()
	await _frames(4)


func _play(mode: StringName) -> void:
	if mode == &"pager":
		await _pager()
		return
	_mode = mode
	_shots.clear()
	_pager_shot = false
	SaveService.delete_profile(SLOT)
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_spawn_ui()
	var flow: X4StealthFlow = X4StealthFlow.new(self)
	RenderingServer.render_loop_enabled = false
	var ok: bool = false
	var loud: X4OfLoud = null
	if mode == &"stealth":
		ok = await flow.launch(HEIST, 18)
	else:
		loud = X4OfLoud.new(flow)
		ok = await X4OfLoud.launch(flow, HEIST, 5)
	if ok:
		EventBus.objective_updated.connect(_on_objective)
		EventBus.pager_started.connect(_on_pager)
		EventBus.device_started.connect(_on_device)
		if mode == &"stealth":
			ok = await X4StealthRoutes.play(flow)
		else:
			ok = await loud.play()
		EventBus.objective_updated.disconnect(_on_objective)
		EventBus.pager_started.disconnect(_on_pager)
		EventBus.device_started.disconnect(_on_device)
	while _busy:
		await get_tree().process_frame
	RenderingServer.render_loop_enabled = true
	var r: Dictionary = flow.ended[0] if not flow.ended.is_empty() else {}
	print("OFRUN %s route ok=%s alarms=%s pagers=%d completed=%s secured=%s failures=%s" % [mode, ok, flow.alarms,
		flow.pagers, flow.completed, flow.secured_loot, flow.failures])
	await _payday(r)
	await flow.teardown()
	_layer.queue_free()
	await _frames(4)


## HUD + payday on their own layer above the map, as MenuFlow._spawn_in_heist_ui does (before the launch).
func _spawn_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	_hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	_hud.heist_id = HEIST
	_layer.add_child(_hud)
	ContactRadio.spawn(_layer, HEIST)
	_pd = (load("res://content/ui/results/payday.tscn") as PackedScene).instantiate() as PaydayScreen
	_pd.listen_heist_ended = true
	_pd.start_fact_log()
	_pd.profile_slot = SLOT
	_pd.cards_enabled = false
	_pd.visible = false
	_layer.add_child(_pd)


func _on_objective(id: StringName, state: int, _d: Dictionary) -> void:
	if state == Enums.ObjectiveState.ACTIVE and (SHOOT_AT[_mode] as Array).has(id) and not _shots.has(String(id)):
		_shots.append(String(id))
		_hud_shot.call_deferred(String(id))


## The first device of each kind (the rack / PC hack, the thermal drill) gets a shot a few seconds in.
func _on_device(_id: int, kind: StringName, _duration: float) -> void:
	var tag: String = "device_" + String(kind)
	if not _shots.has(tag):
		_shots.append(tag)
		_hud_shot.call_deferred(tag)


func _on_pager(_p: int, _g: int) -> void:
	if not _pager_shot:
		_pager_shot = true
		_hud_shot.call_deferred("pager")


func _hud_shot(tag: String) -> void:
	while _busy:
		await get_tree().process_frame
	_busy = true
	RenderingServer.render_loop_enabled = true
	for s: Vector2i in SIZES:
		get_window().size = s
		await _frames(8)
		await RenderingServer.frame_post_draw
		_save("%s_hud_%s" % [_mode, tag])
		_scan("%s/hud_%s@%d" % [_mode, tag, s.y], _hud)
	_dump_hud(tag)
	get_window().size = SIZES[0]
	RenderingServer.render_loop_enabled = false
	_busy = false


func _dump_hud(tag: String) -> void:
	for w: HudWidget in _hud.widgets():
		var cls: String = String((w.get_script() as Script).resource_path.get_file().get_basename())
		if not cls in ["objectives_panel", "pager_panel", "device_timers"] or not w.is_visible_in_tree():
			continue
		var texts: PackedStringArray = PackedStringArray()
		for n: Node in w.find_children("*", "Label", true, false):
			var l: Label = n as Label
			if l.is_visible_in_tree() and l.text.strip_edges() != "":
				texts.append(l.text.replace("\n", " / "))
		print("OFRUN HUD %s %s %s: %s" % [_mode, tag, cls, " | ".join(texts)])


func _payday(r: Dictionary) -> void:
	if r.is_empty():
		_issue(String(_mode), "no heist_ended result")
		return
	await _frames(6)
	if not _pd.visible:
		_issue(String(_mode), "payday did not open on heist_ended")
		return
	_pd.skip_count()
	print("OFRUN PAYDAY %s result success=%s stealth=%s difficulty=%s time=%.0f bags=%s small=%s kills=%s pagers=%s" % [
		_mode, r.get("success"), r.get("stealth"), r.get("difficulty"), float(r.get("time_s", r.get("heist_time_s", -1.0))),
		r.get("secured_loot", r.get("bags", "?")), r.get("small_loot", "?"), r.get("kills", "?"), r.get("pagers", "?")])
	print("OFRUN PAYDAY %s payout=%s" % [_mode, _pd.payout])
	print("OFRUN PAYDAY %s freshness=%s achievements=%s" % [_mode, _pd.freshness_eval, _pd.achievements_unlocked])
	for s: Vector2i in SIZES:
		get_window().size = s
		await _frames(10)
		await RenderingServer.frame_post_draw
		_save("%s_payday" % _mode)
		_scan("%s/payday@%d" % [_mode, s.y], _pd)
	var texts: PackedStringArray = PackedStringArray()
	for n: Node in _pd.find_children("*", "Label", true, false):
		var l: Label = n as Label
		if l.is_visible_in_tree() and l.text.strip_edges() != "":
			texts.append(l.text.replace("\n", " / "))
	print("OFRUN PAYDAY %s labels: %s" % [_mode, " | ".join(texts)])
	get_window().size = SIZES[0]


func _save(stem: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, stem, img.get_width(), img.get_height()]
	img.save_png(path)
	print("OFRUN SHOT ", path)


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


## Flags visible labels whose text does not fit (trimmed / spilling, or off the viewport) and overlapping labels
## (ui_qa_walk_worker's scan).
func _scan(tag: String, root: Control) -> void:
	var view: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var labels: Array[Label] = []
	for n: Node in root.find_children("*", "Label", true, false):
		var l: Label = n as Label
		if l == null or not l.is_visible_in_tree() or l.text.strip_edges() == "" or not _on_screen(l) or _faded(l):
			continue
		labels.append(l)
		var r: Rect2 = l.get_global_rect()
		var need: float = l.get_theme_font(&"font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				l.get_theme_font_size(&"font_size")).x
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING \
				and need > r.size.x + 2.0:
			_issue(tag, "clipped '%s' needs %.0f px, has %.0f" % [l.text.left(48), need, r.size.x])
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING \
				and need > r.size.x + 2.0:
			_issue(tag, "trimmed '%s' needs %.0f px, has %.0f" % [l.text.left(48), need, r.size.x])
		if r.end.x > view.end.x + 1.0 or r.end.y > view.end.y + 1.0 or r.position.x < -1.0 or r.position.y < -1.0:
			_issue(tag, "off-screen '%s' %s" % [l.text.left(48), r])
	for a: int in range(labels.size()):
		for b: int in range(a + 1, labels.size()):
			var ra: Rect2 = labels[a].get_global_rect().grow(-1.0)
			var rb: Rect2 = labels[b].get_global_rect().grow(-1.0)
			if ra.intersects(rb):
				_issue(tag, "overlap '%s' x '%s'" % [labels[a].text.left(32), labels[b].text.left(32)])


func _faded(l: CanvasItem) -> bool:
	var n: Node = l
	while n is CanvasItem:
		if (n as CanvasItem).modulate.a < 0.05 or (n == l and l.self_modulate.a < 0.05):
			return true
		n = n.get_parent()
	return false


func _on_screen(l: Control) -> bool:
	var p: Node = l.get_parent()
	while p != null:
		if p is ScrollContainer:
			return (p as Control).get_global_rect().grow(1.0).encloses(l.get_global_rect())
		p = p.get_parent()
	return true


func _issue(tag: String, what: String) -> void:
	_issues += 1
	print("QA ISSUE %s %s" % [tag, what])
