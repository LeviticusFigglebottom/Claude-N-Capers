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
## Captain panel top (HUD units) under a one-line assault banner, and its gap below a taller one (_stack_captain).
const CAPTAIN_TOP: float = 104.0
const CAPTAIN_GAP: float = 8.0
## Gap (HUD units) between the scope ring, the screen edge and the text panels docked in the margin (_avoid_scope).
const SCOPE_GAP: float = 12.0
## A margin narrower than this (HUD units) takes no panels: they stay where they are.
const SCOPE_MIN_MARGIN: float = 220.0

@export var model_path: NodePath
## Discover the model through group G.LOCAL_HUD_MODEL when nothing is bound.
@export var auto_find_model: bool = true
## Heist being played (MenuFlow sets it before adding the HUD): accents the objectives panel
## (UiAccent.for_heist, B4-07). Empty = no accent.
@export var heist_id: StringName = &""
## L1.7: the running heist's Enums.Difficulty (assault-banner skulls; -1 = none) and C4 Last Breath (MenuFlow sets both).
@export var difficulty: int = -1
@export var last_breath: bool = false

## PO-4: slot -> heister id (MenuFlow at launch); teammate rows show the heister's name and colour.
var crew_heisters: Dictionary = {}
## Settings the HUD follows (null = GameSettings.current(); tests set their own before _ready).
var settings: GameSettings = null
## HudTweak recoloured by the active palette (what every widget reads).
var tweak: HudTweak = null
var model: Node = null
## D-128: PD2 detection rings over observers + crosshair arcs (was the S2.1 chevrons).
var chevrons: DetectionRings
var marks: MarkedTargets
## v1.8 objective world markers (edge-clamped, distance).
var objective_markers: ObjectiveMarkers
## PO6-03: PD2 device timer panels (drill / saw / hack ...) at the devices.
var device_timers: DeviceTimers
## PO6-20: a waypoint over every guard with a live pager.
var pager_waypoints: PagerWaypoints
## PO6-17: RNG assault event markers (turret van, helicopter, breach); their names go on the assault banner.
var assault_events: AssaultEventMarkers
## PO6-17b: breach-blast white-out over everything (LocalHudModel.flashed_s).
var breach_flash: BreachFlash
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
## The crosshair: hidden while casing / civilian, fades in once masked (lead ruling, PD2), and out while aiming down
## sights (PO-22, ui_hud v1.23: alpha x (1 - LocalHudModel.ads_blend)).
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
## The crosshair's masked / casing fade before the ADS factor (PO-22).
var _crosshair_base: float = 0.0
var _subtitles: WeakRef = null
var _subtitle_seek: int = 0
var _lookup_t: float = 0.0
var _toast_t: float = 0.0
var _watched_crew: Node = null
## Other humans in the crew (slot -> display name), to tell the crew when one leaves or joins (PD2).
var _human_names: Dictionary = {}
## Control -> [offset_left, offset_top, offset_right, offset_bottom, scale, pivot_offset] as placed; _avoid_scope
## docks the control in the scope margin and puts these back when the scope is lowered.
var _docked: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if theme == null:
		theme = UiBuild.theme()
	if settings == null:
		settings = GameSettings.current()
	UiSfx.warm()  # not on the first objective flash mid-heist (perf item, see UiSfx.warm)
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
	return [chevrons, marks, objective_markers, device_timers, pager_waypoints, assault_events, breach_flash, interaction,
			dominate, vitals, ammo, pager, objectives, assault, teammates, status, custody, captain, stamina, scoreboard, hint,
			mask_ring, onboarding, hit_feedback, damage_direction, low_health, downed, hostages]


func _build() -> void:
	low_health = _place(LowHealthVignette.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as LowHealthVignette
	downed = _place(DownedOverlay.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as DownedOverlay
	downed.heisters = crew_heisters
	marks = _place(MarkedTargets.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as MarkedTargets
	objective_markers = _place(ObjectiveMarkers.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as ObjectiveMarkers
	device_timers = _place(DeviceTimers.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as DeviceTimers
	pager_waypoints = _place(PagerWaypoints.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as PagerWaypoints
	assault_events = _place(AssaultEventMarkers.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) \
			as AssaultEventMarkers
	chevrons = _place(DetectionRings.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as DetectionRings
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
	device_timers.objective_suffix_changed.connect(objectives.set_device_suffix)
	assault = _place(AssaultBanner.new(), Control.PRESET_CENTER_TOP, Vector2(-260, 40), Vector2(520, 56)) as AssaultBanner
	assault.difficulty = difficulty
	assault.last_breath = last_breath
	hostages = _place(HostageStrip.new(), Control.PRESET_CENTER_TOP, Vector2(280, 40), Vector2(220, 80)) as HostageStrip
	pager = _place(PagerPanel.new(), Control.PRESET_CENTER_TOP, Vector2(-200, 110), Vector2(400, 200)) as PagerPanel
	status = _place(StatusPanel.new(), Control.PRESET_TOP_RIGHT, Vector2(-448, 48), Vector2(400, 180)) as StatusPanel
	custody = _place(CustodyPanel.new(), Control.PRESET_CENTER, Vector2(-300, -200), Vector2(600, 130)) as CustodyPanel
	captain = _place(CaptainPanel.new(), Control.PRESET_CENTER_TOP, Vector2(-260, CAPTAIN_TOP), Vector2(520, 84)) as CaptainPanel
	mask_ring = _place(MaskProgress.new(), Control.PRESET_CENTER, Vector2(-120, -40), Vector2(240, 110)) as MaskProgress
	# Below the interaction prompt, clear of the subtitles at the bottom (audit: they collided).
	hint = _place(HintStrip.new(), Control.PRESET_CENTER, Vector2(-450, 190), Vector2(900, 64)) as HintStrip
	onboarding = _place(OnboardingCard.new(), Control.PRESET_CENTER_RIGHT, Vector2(-OnboardingCard.WIDTH - 48, -300),
			Vector2(OnboardingCard.WIDTH, 0)) as OnboardingCard
	onboarding.heist_id = heist_id  # D-115 heist card
	var board: ScoreboardOverlay = ScoreboardOverlay.new()
	board.settings = settings
	board.heisters = crew_heisters
	# r246: top at -350 so the sheet (rows grow it to ~710) ends above the vitals block (it clipped ARMOR / HEALTH values).
	# r261 ultrawide pass: the sheet needed ~1,326 wide, so the 1,240 box grew it to the right only (43 px off centre at
	# every aspect). Tighter sheet gaps + a 1,260 box: centred, and clear of the teammate panels on the left.
	scoreboard = _place(board, Control.PRESET_CENTER, Vector2(-630, -350), Vector2(1260, 520)) as ScoreboardOverlay
	toast_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD_BIG))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(toast_label, Control.PRESET_CENTER, Vector2(-500, -260), Vector2(1000, 60))
	toast_label.visible = false
	assault_events.events_changed.connect(assault.set_events)
	breach_flash = _place(BreachFlash.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as BreachFlash  # on top


## ui_hud v1.16 (LEAD r227/r228): while the model says `scoped_ads`, no TEXT panel sits over the ring `scope_ring`
## (canvas units at the 1920x1080 stretch base, written by P's scope overlay). Device timer panels inside it are not
## drawn. The assault banner, captain, toast, tip card, interaction prompt and hint strip that the ring would cover dock in
## the black margin right of it, stacked from the top. The prompt sits at least at the vertical centre, on a dark plate,
## and when the margin runs short the card gives way to it. Markers, chevrons, hit markers and subtitles stay (PD2).
func _avoid_scope() -> void:
	var ring: Rect2 = Rect2()
	if model != null and model.get(&"scoped_ads") == true and model.get(&"scope_ring") is Rect2:
		ring = model.get(&"scope_ring") as Rect2
	var local: Rect2 = get_global_transform_with_canvas().affine_inverse() * ring if ring.has_area() else Rect2()
	if device_timers != null:
		device_timers.avoid = local
		device_timers.yield_rect = _toast_rect() if local == Rect2() else Rect2()
	var keep: Array[Control] = []
	if local.has_area():
		keep = _dock_in_margin(local)
	for c: Variant in _docked.keys():
		if not keep.has(c as Control):
			_undock(c as Control)


## r228 windowed check: the toast's text (not its 1000-unit box), for device panels to step below.
## GPU-19: the global rect of the top-centre banner stack (the assault banner and the captain / boss panel, those
## showing); empty when neither shows. World markers and device timers step below it.
func _banner_stack_rect() -> Rect2:
	var out: Rect2 = Rect2()
	for c: Control in [assault.panel if assault != null else null, captain]:
		if c != null and c.is_visible_in_tree() and c.size.x > 0.0:
			out = c.get_global_rect() if not out.has_area() else out.merge(c.get_global_rect())
	return out


func _toast_rect() -> Rect2:
	if toast_label == null or not toast_label.visible or toast_label.text == "":
		return Rect2()
	var f: Font = toast_label.get_theme_font(&"font")
	var fs: int = toast_label.get_theme_font_size(&"font_size")
	var w: float = f.get_string_size(toast_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * toast_label.scale.x
	var r: Rect2 = Rect2(toast_label.position, toast_label.size * toast_label.scale)
	return Rect2(r.get_center().x - w * 0.5 - SCOPE_GAP, r.position.y, w + 2.0 * SCOPE_GAP, r.size.y)


## Docks the text panels the ring covers; returns the docked controls.
func _dock_in_margin(ring: Rect2) -> Array[Control]:
	var x0: float = ring.end.x + SCOPE_GAP
	var w: float = size.x - SCOPE_GAP * 2.0 - x0
	var out: Array[Control] = []
	if w < SCOPE_MIN_MARGIN:
		return out
	for c: Control in [assault, captain, toast_label, onboarding, interaction, hint]:
		if c != null and c.visible and _over_ring(c, ring):
			out.append(c)
	var top: float = SCOPE_GAP * 3.0
	if status != null and status.visible and status.get_child_count() > 0:
		var st: Rect2 = _visual_rect(status)
		top = maxf(top, st.position.y + (status.get_child(0) as Control).get_combined_minimum_size().y * status.scale.y
				+ SCOPE_GAP)
	var bottom: float = (_visual_rect(ammo).position.y if ammo != null else size.y) - SCOPE_GAP
	if _stack(out, x0, w, top, bottom, ring, true) and out.has(onboarding):
		_stack(out, x0, w, top, bottom, ring, false)  # the prompt did not fit under the card: the card gives way
	return out


## Lays `list` out top-down in the margin; returns true when the interaction prompt ran past `bottom`.
func _stack(list: Array[Control], x0: float, w: float, top: float, bottom: float, ring: Rect2, with_card: bool) -> bool:
	var y: float = top
	var prompt_short: bool = false
	for c: Control in list:
		_dock(c)
		var saved: Array = _docked[c] as Array
		var base: float = (saved[4] as Vector2).x
		if c == onboarding:
			onboarding.settle()
			onboarding.fit_width(w / base)
		var content: Vector2 = _dock_content(c)
		var own_h: float = float(saved[3]) - float(saved[1]) if c == interaction else content.y
		var sc: float = minf(base, w / maxf(content.x, 1.0))
		var h: float = own_h * sc
		var at: float = maxf(y, ring.get_center().y - h * 0.5) if c == interaction else y
		var fits: bool = at + h <= bottom and (with_card or c != onboarding)
		if c == interaction and not fits:
			prompt_short = true
		c.pivot_offset = Vector2.ZERO
		c.scale = Vector2(sc, sc)
		var origin: Vector2 = Vector2(size.x * c.anchor_left, size.y * c.anchor_top)
		var x: float = x0 if fits else size.x + 100.0  # no room: off screen until the scope is lowered
		c.offset_left = x - origin.x
		c.offset_top = at - origin.y
		c.offset_right = c.offset_left + w / sc
		c.offset_bottom = c.offset_top + own_h
		if fits:
			y = at + h + SCOPE_GAP
	if interaction != null:
		interaction.plated = list.has(interaction)
	return prompt_short


## Remembers how `c` was placed (once per scoped stretch).
func _dock(c: Control) -> void:
	if not _docked.has(c):
		_docked[c] = [c.offset_left, c.offset_top, c.offset_right, c.offset_bottom, c.scale, c.pivot_offset]


func _undock(c: Control) -> void:
	var saved: Array = _docked[c] as Array
	_docked.erase(c)
	c.offset_left = float(saved[0])
	c.offset_top = float(saved[1])
	c.offset_right = float(saved[2])
	c.offset_bottom = float(saved[3])
	c.scale = saved[4] as Vector2
	c.pivot_offset = saved[5] as Vector2
	if c == onboarding:
		onboarding.fit_width(OnboardingCard.WIDTH)
	if c == interaction:
		interaction.plated = false


## Unscaled size of what `c` shows (its first child's minimum; the toast's text).
func _dock_content(c: Control) -> Vector2:
	if c == toast_label:
		var r: Rect2 = _toast_rect()
		return Vector2(r.size.x / maxf(toast_label.scale.x, 0.01), toast_label.size.y)
	var inner: Control = c.get_child(0) as Control if c.get_child_count() > 0 else null
	return inner.get_combined_minimum_size().max(Vector2(1, 1)) if inner != null else c.size


## Where `c` is drawn (its rect scaled about its pivot), in HUD units.
static func _visual_rect(c: Control) -> Rect2:
	return Rect2(c.position + c.pivot_offset * (Vector2.ONE - c.scale), c.size * c.scale)


## True when `c` as placed (not as docked) touches the circle inscribed in `ring`.
func _over_ring(c: Control, ring: Rect2) -> bool:
	var r: Rect2 = _visual_rect(c)
	if _docked.has(c):
		var saved: Array = _docked[c] as Array
		var origin: Vector2 = Vector2(size.x * c.anchor_left, size.y * c.anchor_top)
		var sc: Vector2 = saved[4] as Vector2
		var piv: Vector2 = saved[5] as Vector2
		var sz: Vector2 = Vector2(float(saved[2]) - float(saved[0]), float(saved[3]) - float(saved[1]))
		r = Rect2(origin + Vector2(float(saved[0]), float(saved[1])) + piv * (Vector2.ONE - sc), sz * sc)
	if c == toast_label:
		var t: Rect2 = _toast_rect()
		r = Rect2(Vector2(r.get_center().x - t.size.x * 0.5, r.position.y), Vector2(t.size.x, r.size.y))
	var centre: Vector2 = ring.get_center()
	var radius: float = minf(ring.size.x, ring.size.y) * 0.5
	var near: Vector2 = centre.clamp(r.position, r.end)
	return near.distance_to(centre) < radius


## r227 crowding audit: the captain panel sits under the assault banner's real bottom; the banner grows when it lists
## the active assault events, and the fixed spot covered that line ("TURRET VAN" under Commander Brandt).
func _stack_captain() -> void:
	if captain == null or assault == null or assault.panel == null:
		return
	var top: float = CAPTAIN_TOP
	if assault.visible and assault.panel.is_visible_in_tree():
		top = maxf(top, assault.offset_top + assault.panel.position.y + assault.panel.size.y + CAPTAIN_GAP)
	if not is_equal_approx(captain.offset_top, top):
		var h: float = captain.offset_bottom - captain.offset_top
		captain.offset_top = top
		captain.offset_bottom = top + h


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
	elif section == GameSettings.BINDINGS:
		# D-115: a rebind (pause menu Options) redraws every key cap. Options applies the InputMap right after
		# `changed` (copy_from, then apply), so read it a frame later.
		refresh_keys.call_deferred()


## Redraws every widget, so key caps and prompts follow the current InputMap (rebinding, device switch).
func refresh_keys() -> void:
	for w: HudWidget in widgets():
		if w != null and is_instance_valid(w):
			w.refresh()


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
	Net.crew_changed.connect(_on_net_crew_changed)
	_human_names = _other_humans()


## Co-op windowed pass: a human who drops is replaced by an AI without a word (the host just saw the
## heister turn AI). Toast who left / joined, PD2 style.
func _on_net_crew_changed() -> void:
	var now: Dictionary = _other_humans()
	for slot: int in _human_names:
		if not now.has(slot):
			toast(&"ui.hud.player_left", {"name": _human_names[slot], "heister": _crew_name(slot)})
	for slot: int in now:
		if not _human_names.has(slot):
			toast(&"ui.hud.player_joined", {"name": now[slot], "heister": _crew_name(slot)})
	_human_names = now


func _other_humans() -> Dictionary:
	var out: Dictionary = {}
	var me: int = Net.local_slot()
	for slot: int in Net.crew:
		var c: Dictionary = Net.crew[slot] as Dictionary
		if slot != me and not bool(c.get("is_ai", true)):
			out[slot] = String(c.get("display_name", ""))
	return out


## Toast a strings key for `seconds` (default TOAST_S).
func toast(key: StringName, args: Dictionary = {}, seconds: float = TOAST_S) -> void:
	# LEAD r229: an assault event the banner already lists is not toasted as well (its world marker stays).
	if AssaultEventMarkers.KIND_KEYS.values().has(key) and assault != null and assault.events_label != null \
			and assault.events_label.visible and assault.events_label.text.split(" · ").has(UiText.t(key, args)):
		return
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
		refresh_keys()


## Global rect of the in-heist subtitle box while it shows rows (ContactRadio's SubtitleOverlay, a sibling layer), or
## an empty rect. The overlay is found once and held weakly.
func _subtitle_rect() -> Rect2:
	var sub: SubtitleOverlay = _subtitles.get_ref() as SubtitleOverlay if _subtitles != null else null
	if sub == null:
		_subtitle_seek -= 1
		if _subtitle_seek > 0:
			return Rect2()
		_subtitle_seek = 30  # look again twice a second, not every frame
		for n: Node in get_tree().get_nodes_in_group(SubtitleOverlay.GROUP):
			sub = n as SubtitleOverlay
			_subtitles = weakref(sub)
			break
	if sub == null or sub.box == null or sub.rows.is_empty() or not sub.box.is_visible_in_tree():
		return Rect2()
	return sub.box.get_global_rect()


func _process(delta: float) -> void:
	_update_crosshair(delta)
	_stack_captain()
	_avoid_scope()
	if objective_markers != null and scoreboard != null:
		objective_markers.show_all = scoreboard.visible  # Tab shows every objective's marker
		objective_markers.z_index = 1 if scoreboard.visible else 0  # drawn over the sheet, not under it
		var sheet: Control = scoreboard.sheet if scoreboard.visible else null
		objective_markers.avoid = sheet.get_global_rect() if sheet != null else Rect2()  # badges only on it
	if objective_markers != null:
		objective_markers.subtitle_band = _subtitle_rect()
		objective_markers.top_band = _banner_stack_rect()
	if device_timers != null:
		device_timers.top_band = _banner_stack_rect()
	if onboarding != null and scoreboard != null:
		# The Tab sheet and the pause menu's job card sit on the card's spot and win (h02 / fail captures).
		onboarding.visible = onboarding.shown != &"" and not scoreboard.visible and not MouseCapture.is_released(&"pause") \
				and not (toast_label != null and toast_label.visible) \
				and not (downed != null and downed.active)  # lane 2 audit: the card sat over the downed screen
	if hint != null and onboarding != null:
		hint.yield_to_card = onboarding.visible and onboarding.shown == &"casing"  # the card shows the mask row
		hint.note.visible = hint.hint == &"mask_up" and onboarding.shown == &""  # any card already says it
	if _toast_t > 0.0:
		_toast_t -= delta
		# Not over the Tab sheet, nor over the downed screen (its block sits where toasts do).
		toast_label.visible = _toast_t > 0.0 and not (scoreboard != null and scoreboard.visible) \
				and not (downed != null and downed.active)
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
		_crosshair_base = target
	else:
		_crosshair_base = move_toward(_crosshair_base, target, delta / UiTokens.T_SLOW)
	# PO-22 (PD2 hides it in ADS): P writes ads_blend (0 hip .. 1 ADS, already smoothed); hip bloom is untouched.
	var ads: Variant = model.get(&"ads_blend") if model != null else null
	crosshair.modulate.a = _crosshair_base * (1.0 - clampf(float(ads), 0.0, 1.0) if ads != null else 1.0)


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
	toast(&"ui.hud.secured_one" if secured_bags == 1 else &"ui.hud.secured", {"count": secured_bags})  # P #11


func _on_crew_downed(crew_slot: int, _downs_used: int) -> void:
	if crew_slot != Net.local_slot():
		toast(&"ui.hud.teammate_downed", {"name": _crew_name(crew_slot)})


func _on_crew_custody(crew_slot: int) -> void:
	if crew_slot != Net.local_slot():
		toast(&"ui.hud.teammate_custody", {"name": _crew_name(crew_slot)})


func _crew_name(slot: int) -> String:
	if crew_heisters.has(slot):  # the heister the slot plays, like the crew rows (windowed: "AI 1 is down")
		return Heisters.display_name(StringName(crew_heisters[slot]))
	if Net.crew.has(slot):
		return String(Net.crew[slot].get("display_name", ""))
	return UiText.t(&"ui.results.crew_slot", {"slot": slot + 1})
