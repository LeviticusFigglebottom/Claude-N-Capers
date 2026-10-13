## In-heist HUD root (contracts/ui_hud.md, D-009). Owner: ENV B.
## Binds ONLY to the local HUD model and EventBus. The widgets bind DIRECTLY to the model, which
## speaks the ui_hud.md v1.3 binding shape (v1.2 adds `custody`, v1.3 `captain_present`/`captain_resistance`;
## v1.4 `stamina`/`exhausted` drive StaminaBar, bound by signal name ahead of ENV A)
## (ENV A's LocalHudModel; MockHudModel for the demo/tests).
## Model resolution, in order:
##   1. bind(model) called by the owner (tests, hud_demo);
##   2. exported `model_path`;
##   3. discovery through group G.LOCAL_HUD_MODEL (ui_hud.md v1.1, D-024: exactly one per peer,
##      joined in the model's _ready), polled every LOOKUP_INTERVAL_S while unbound, and again after
##      the bound model is freed. This is how the in-heist HUD finds HeistRuntime's model.
## Accessibility (B5-01): widget colours come from the active HudPalette (GameSettings
## `accessibility/palette`, HudPaletteSet.active_tweak) and the corner widgets scale with
## `accessibility/hud_scale`; both follow GameSettings.changed live (apply_accessibility()).
## B6-02: `scoreboard` (ScoreboardOverlay) shows the per-crew tally while the `scoreboard` action is held
## (or toggled, `controls/scoreboard_mode`), from the model's `crew_stats` (content/docs/scoreboard.md).
## No hard dependency on ENV A classes (duck-typed get() + signals by name). Layout is anchored for 1280x720 .. 3840x2160 (canvas_items
## stretch at the 1920x1080 base).
class_name Hud
extends Control

signal model_bound(model: Node)

const LOOKUP_INTERVAL_S: float = 0.25
const TOAST_S: float = 3.0
## PI-13: how long a casing_blocked hint stays up.
const CASING_HINT_S: float = 1.5
## casing_blocked action -> hint string key (unknown actions use ui.hud.casing_blocked.generic).
const CASING_HINT_KEYS: Dictionary = {
	&"sprint": &"ui.hud.casing_blocked.sprint", &"crouch": &"ui.hud.casing_blocked.crouch",
	&"jump": &"ui.hud.casing_blocked.jump"}

@export var model_path: NodePath
## Discover the model through group G.LOCAL_HUD_MODEL when nothing is bound.
@export var auto_find_model: bool = true
## Heist being played (MenuFlow sets it before adding the HUD): accents the objectives panel
## (UiAccent.for_heist, B4-07). Empty = no accent.
@export var heist_id: StringName = &""

## PO-4: slot -> heister id (MenuFlow at launch); teammate rows show the heister's name and colour.
var crew_heisters: Dictionary = {}
## Settings the HUD follows (null = GameSettings.current(); tests set their own before _ready).
var settings: GameSettings = null
## HudTweak recoloured by the active palette (what every widget reads).
var tweak: HudTweak = null
var model: Node = null
var chevrons: DetectionChevrons
var marks: MarkedTargets
## v1.8 objective world markers (edge-clamped, distance).
var objective_markers: ObjectiveMarkers
var interaction: InteractionPanel
## PP-A-1: guard-domination prompt (above the interaction prompt).
var dominate: DominatePrompt
var vitals: VitalsPanel
var ammo: AmmoPanel
var pager: PagerPanel
var objectives: ObjectivesPanel
var assault: AssaultBanner
## Lead round 64: hostage count + trade state, right of the assault banner.
var hostages: HostageStrip
var teammates: TeammatePanels
var status: StatusPanel
var custody: CustodyPanel
var captain: CaptainPanel
var stamina: StaminaBar
## The crosshair: hidden while casing / civilian, fades in once masked (lead ruling, PD2).
var crosshair: Label
## PO-1 mask-up progress ring around the crosshair while mask up is held.
var mask_ring: MaskProgress
## PO-4 contextual control hint (bottom centre): click to resume / mask up / throw the bag.
var hint: HintStrip
## Lead round 62 gameplay feedback: hit marker, damage direction arcs, low-health vignette + heartbeat.
var hit_feedback: HitFeedback
var damage_direction: DamageDirection
var low_health: LowHealthVignette
## Lead queue (a): the grey downed screen with the big bleedout timer and the revive line.
var downed: DownedOverlay
## PO-4 lane 11 first-time onboarding cards (right of centre).
var onboarding: OnboardingCard
## B6-02 Tab scoreboard (hold / toggle the `scoreboard` action).
var scoreboard: ScoreboardOverlay
var toast_label: Label
var secured_bags: int = 0
var _lookup_t: float = 0.0
var _toast_t: float = 0.0
var _watched_crew: Node = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if theme == null:
		theme = UiBuild.theme()
	if settings == null:
		settings = GameSettings.current()
	tweak = HudPaletteSet.active_tweak(settings)
	_build()
	_connect_events()
	settings.changed.connect(_on_settings_changed)
	apply_accessibility()
	if model == null and not model_path.is_empty() and has_node(model_path):
		bind(get_node(model_path))


func bind(m: Node) -> void:
	model = m
	for w: HudWidget in widgets():
		w.bind(m)
	if m != null:
		model_bound.emit(m)


func set_crew_heisters(map: Dictionary) -> void:
	crew_heisters = map.duplicate()
	if teammates != null:
		teammates.heisters = crew_heisters
		teammates.refresh()
	if downed != null:
		downed.heisters = crew_heisters
	if scoreboard != null:
		scoreboard.heisters = crew_heisters
		scoreboard.refresh()


func widgets() -> Array[HudWidget]:
	return [chevrons, marks, objective_markers, interaction, dominate, vitals, ammo, pager, objectives, assault,
			teammates, status, custody, captain, stamina, scoreboard, hint, mask_ring, onboarding, hit_feedback,
			damage_direction, low_health, downed, hostages]


func _build() -> void:
	low_health = _place(LowHealthVignette.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as LowHealthVignette
	downed = _place(DownedOverlay.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as DownedOverlay
	downed.heisters = crew_heisters
	marks = _place(MarkedTargets.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as MarkedTargets
	objective_markers = _place(ObjectiveMarkers.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as ObjectiveMarkers
	chevrons = _place(DetectionChevrons.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as DetectionChevrons
	crosshair = UiBuild.label(&"ui.hud.crosshair", UiBuild.HUD)
	crosshair.modulate.a = 0.0  # lead ruling: no crosshair until masked (PD2)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(crosshair, Control.PRESET_CENTER, Vector2(-20, -20), Vector2(40, 40))
	damage_direction = _place(DamageDirection.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as DamageDirection
	hit_feedback = _place(HitFeedback.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as HitFeedback
	interaction = _place(InteractionPanel.new(), Control.PRESET_CENTER, Vector2(-300, 60), Vector2(600, 110)) as InteractionPanel
	dominate = _place(DominatePrompt.new(), Control.PRESET_CENTER, Vector2(-360, -130), Vector2(720, 56)) as DominatePrompt
	stamina = _place(StaminaBar.new(), Control.PRESET_BOTTOM_LEFT, Vector2(48, -248), Vector2(340, 40)) as StaminaBar
	vitals = _place(VitalsPanel.new(), Control.PRESET_BOTTOM_LEFT, Vector2(48, -200), Vector2(340, 160)) as VitalsPanel
	ammo = _place(AmmoPanel.new(), Control.PRESET_BOTTOM_RIGHT, Vector2(-388, -200), Vector2(340, 160)) as AmmoPanel
	teammates = _place(TeammatePanels.new(), Control.PRESET_CENTER_LEFT, Vector2(48, -120), Vector2(260, 400)) as TeammatePanels
	teammates.heisters = crew_heisters  # MenuFlow may hand them over before the HUD is in the tree
	objectives = _place(ObjectivesPanel.new(), Control.PRESET_TOP_LEFT, Vector2(48, 48), Vector2(520, 200)) as ObjectivesPanel
	if heist_id != &"":
		objectives.set_accent(UiAccent.for_heist(heist_id))
	assault = _place(AssaultBanner.new(), Control.PRESET_CENTER_TOP, Vector2(-260, 40), Vector2(520, 56)) as AssaultBanner
	hostages = _place(HostageStrip.new(), Control.PRESET_CENTER_TOP, Vector2(280, 40), Vector2(220, 80)) as HostageStrip
	pager = _place(PagerPanel.new(), Control.PRESET_CENTER_TOP, Vector2(-200, 110), Vector2(400, 200)) as PagerPanel
	status = _place(StatusPanel.new(), Control.PRESET_TOP_RIGHT, Vector2(-448, 48), Vector2(400, 180)) as StatusPanel
	custody = _place(CustodyPanel.new(), Control.PRESET_CENTER, Vector2(-300, -200), Vector2(600, 130)) as CustodyPanel
	captain = _place(CaptainPanel.new(), Control.PRESET_CENTER_TOP, Vector2(-260, 104), Vector2(520, 84)) as CaptainPanel
	mask_ring = _place(MaskProgress.new(), Control.PRESET_CENTER, Vector2(-120, -40), Vector2(240, 110)) as MaskProgress
	# Below the interaction prompt, clear of the subtitles at the bottom (audit: they collided).
	hint = _place(HintStrip.new(), Control.PRESET_CENTER, Vector2(-450, 190), Vector2(900, 64)) as HintStrip
	onboarding = _place(OnboardingCard.new(), Control.PRESET_CENTER_RIGHT, Vector2(-OnboardingCard.WIDTH - 48, -300),
			Vector2(OnboardingCard.WIDTH, 0)) as OnboardingCard
	var board: ScoreboardOverlay = ScoreboardOverlay.new()
	board.settings = settings
	board.heisters = crew_heisters
	scoreboard = _place(board, Control.PRESET_CENTER, Vector2(-620, -260), Vector2(1240, 520)) as ScoreboardOverlay  # x1.5 fits 1920
	toast_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD_BIG))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(toast_label, Control.PRESET_CENTER, Vector2(-500, -260), Vector2(1000, 60))
	toast_label.visible = false


func _place(c: Control, preset: Control.LayoutPreset, offset: Vector2, min_size: Vector2) -> Control:
	if c is HudWidget:
		(c as HudWidget).tweak = tweak
	add_child(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(preset)
	if preset != Control.PRESET_FULL_RECT:
		c.offset_left = offset.x
		c.offset_top = offset.y
		c.offset_right = offset.x + min_size.x
		c.offset_bottom = offset.y + min_size.y
	else:
		c.set_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _exit_tree() -> void:
	if settings != null and settings.changed.is_connected(_on_settings_changed):
		settings.changed.disconnect(_on_settings_changed)


## Re-reads the palette and HUD scale from `settings` (palette change = widgets rebuilt).
func apply_accessibility() -> void:
	var t: HudTweak = HudPaletteSet.active_tweak(settings)
	if not _same_colors(t, tweak):
		tweak = t
		for w: HudWidget in widgets():
			w.set_tweak(tweak)
	var s: float = float(settings.get_value(GameSettings.ACCESSIBILITY, &"hud_scale"))
	for c: Node in get_children():
		var ctl: Control = c as Control
		if ctl == null or (ctl.anchor_left == 0.0 and ctl.anchor_right == 1.0 and ctl.anchor_top == 0.0 and ctl.anchor_bottom == 1.0):
			continue  # full-screen overlays (chevrons, marks) are not scaled
		ctl.pivot_offset = Vector2(ctl.anchor_left, ctl.anchor_top) * (ctl.custom_minimum_size.max(ctl.size))
		ctl.scale = Vector2(s, s)
	_stack_left_column(s)


## PQ-B-6: the left column (objectives / teammates / stamina / vitals) is a stack, so scaling each
## widget about its own anchor made them overlap at hud_scale 1.5 on a 1080-unit canvas. Stamina sits
## on top of the scaled vitals; teammates fit the band between objectives and stamina, shrinking
## below `s` only when that band is too short.
func _stack_left_column(s: float) -> void:
	if vitals == null or stamina == null or teammates == null or objectives == null:
		return
	var h: float = size.y if size.y > 0.0 else 1080.0
	var gap: float = 12.0
	var vitals_top: float = vitals.offset_bottom - (vitals.offset_bottom - vitals.offset_top) * s  # rel. bottom
	var stam_h: float = stamina.offset_bottom - stamina.offset_top
	stamina.offset_bottom = vitals_top - gap
	stamina.offset_top = stamina.offset_bottom - stam_h
	stamina.pivot_offset = Vector2(0.0, stam_h)
	var band_top: float = objectives.offset_top + (objectives.offset_bottom - objectives.offset_top) * s + gap
	var band_bottom: float = h + stamina.offset_bottom - stam_h * s - gap
	var tm_w: float = teammates.offset_right - teammates.offset_left
	var tm_h: float = teammates.offset_bottom - teammates.offset_top
	var ts: float = clampf((band_bottom - band_top) / tm_h, 0.1, s)
	var left: float = teammates.offset_left
	teammates.set_anchors_preset(Control.PRESET_TOP_LEFT)
	teammates.offset_left = left
	teammates.offset_right = left + tm_w
	teammates.offset_top = band_top + ((band_bottom - band_top) - tm_h * ts) * 0.5
	teammates.offset_bottom = teammates.offset_top + tm_h
	teammates.pivot_offset = Vector2.ZERO
	teammates.scale = Vector2(ts, ts)
	# The centred interaction prompt must clear the left column's width (stamina / vitals) too.
	if interaction != null:
		var w: float = size.x if size.x > 0.0 else 1920.0
		var col_right: float = vitals.offset_left + (vitals.offset_right - vitals.offset_left) * s + gap
		var iw: float = interaction.offset_right - interaction.offset_left
		var i_scale: float = clampf((w * 0.5 - col_right) * 2.0 / iw, 0.1, s)
		interaction.scale = Vector2(i_scale, i_scale)


func _on_settings_changed(section: StringName, _key: StringName) -> void:
	if section == GameSettings.ACCESSIBILITY:
		apply_accessibility()


static func _same_colors(a: HudTweak, b: HudTweak) -> bool:
	if a == null or b == null:
		return false
	for f: StringName in [&"detection_blue", &"detection_orange", &"detection_red", &"health_color", &"armor_color",
			&"low_health_color", &"ally_color", &"mark_color", &"objective_color", &"loot_color", &"interaction_color"]:
		if a.get(f) != b.get(f):
			return false
	return true


func _connect_events() -> void:
	EventBus.alarm_raised.connect(_on_alarm_raised)
	EventBus.loot_secured.connect(_on_loot_secured)
	EventBus.crew_downed.connect(_on_crew_downed)
	EventBus.crew_custody.connect(_on_crew_custody)


## Toast a strings key for `seconds` (default TOAST_S).
func toast(key: StringName, args: Dictionary = {}, seconds: float = TOAST_S) -> void:
	toast_label.text = UiText.t(key, args)
	toast_label.visible = true
	_toast_t = seconds


## PI-13 (ENV P): connect the local CrewController's `casing_blocked(action)` when it has one (no-op
## on builds without the signal). Returns whether a connection exists now.
func watch_crew(crew: Node) -> bool:
	if crew == null or not crew.has_signal(&"casing_blocked"):
		return false
	if _watched_crew != null and is_instance_valid(_watched_crew) and _watched_crew != crew \
			and _watched_crew.is_connected(&"casing_blocked", _on_casing_blocked):
		_watched_crew.disconnect(&"casing_blocked", _on_casing_blocked)
	if not crew.is_connected(&"casing_blocked", _on_casing_blocked):
		crew.connect(&"casing_blocked", _on_casing_blocked)
	_watched_crew = crew
	return true


## Brief "Mask up to sprint" style hint (CASING_HINT_S) for a move blocked while casing.
func _on_casing_blocked(action: StringName) -> void:
	var key: StringName = CASING_HINT_KEYS.get(action, &"ui.hud.casing_blocked.generic") as StringName
	toast(key, {"key": InteractionPanel.action_key_text(&"mask_up")}, CASING_HINT_S)


func _find_local_crew() -> void:
	if _watched_crew != null and is_instance_valid(_watched_crew):
		return
	for n: Node in get_tree().get_nodes_in_group(G.CREW):
		if int(n.get(&"slot") if n.get(&"slot") != null else -1) == Net.local_slot():
			watch_crew(n)
			return


## Prompts name the device the player is using (pad buttons vs keys); redraw on a switch.
func _input(event: InputEvent) -> void:
	if InteractionPanel.note_input(event):
		for w: HudWidget in widgets():
			if w != null and is_instance_valid(w):
				w.refresh()


func _process(delta: float) -> void:
	_update_crosshair(delta)
	if objective_markers != null and scoreboard != null:
		objective_markers.show_all = scoreboard.visible  # Tab shows every objective's marker
		objective_markers.z_index = 1 if scoreboard.visible else 0  # drawn over the sheet, not under it
	if onboarding != null and scoreboard != null:
		onboarding.visible = onboarding.shown != &"" and not scoreboard.visible  # Tab sheet wins (h02 capture)
	if hint != null and onboarding != null:
		hint.note.visible = hint.hint == &"mask_up" and onboarding.shown == &""  # the card already says it
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_label.visible = _toast_t > 0.0
	if model != null and not is_instance_valid(model):
		bind(null)
	if auto_find_model and (model == null or _watched_crew == null or not is_instance_valid(_watched_crew)):
		_lookup_t -= delta
		if _lookup_t <= 0.0:
			_lookup_t = LOOKUP_INTERVAL_S
			if model == null:
				discover_model()
			_find_local_crew()


## Crosshair alpha toward 1 when masked (or the mode is unknown, e.g. tests), toward 0 otherwise.
func _update_crosshair(delta: float) -> void:
	if crosshair == null:
		return
	var mode: StringName = StringName(model.get(&"player_mode")) if model != null and model.get(&"player_mode") != null else &""
	if mode == &"" and model != null and model.get(&"masked") != null:
		mode = &"masked" if bool(model.get(&"masked")) else &"casing"
	var target: float = 1.0 if mode == &"masked" or model == null else 0.0
	if not UiTokens.motion_ok():
		crosshair.modulate.a = target
	else:
		crosshair.modulate.a = move_toward(crosshair.modulate.a, target, delta / UiTokens.T_SLOW)


## Bind the local HUD model found through group G.LOCAL_HUD_MODEL. Returns it (or null).
func discover_model() -> Node:
	var found: Node = get_tree().get_first_node_in_group(G.LOCAL_HUD_MODEL)
	if found != null and found != model:
		bind(found)
	return found


func _on_alarm_raised(_reason: StringName, _source_net_id: int) -> void:
	toast(&"ui.hud.alarm")


func _on_loot_secured(_bag_net_id: int, _loot_id: StringName, _value: int) -> void:
	secured_bags += 1
	toast(&"ui.hud.secured", {"count": secured_bags})


func _on_crew_downed(crew_slot: int, _downs_used: int) -> void:
	if crew_slot != Net.local_slot():
		toast(&"ui.hud.teammate_downed", {"name": _crew_name(crew_slot)})


func _on_crew_custody(crew_slot: int) -> void:
	if crew_slot != Net.local_slot():
		toast(&"ui.hud.teammate_custody", {"name": _crew_name(crew_slot)})


func _crew_name(slot: int) -> String:
	if Net.crew.has(slot):
		return String(Net.crew[slot].get("display_name", ""))
	return UiText.t(&"ui.results.crew_slot", {"slot": slot + 1})
