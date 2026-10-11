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
## No hard dependency on ENV A classes (duck-typed get() + signals by name). Layout is anchored for 1280x720 .. 3840x2160 (canvas_items
## stretch at the 1920x1080 base).
class_name Hud
extends Control

signal model_bound(model: Node)

const LOOKUP_INTERVAL_S: float = 0.25
const TOAST_S: float = 3.0

@export var model_path: NodePath
## Discover the model through group G.LOCAL_HUD_MODEL when nothing is bound.
@export var auto_find_model: bool = true
## Heist being played (MenuFlow sets it before adding the HUD): accents the objectives panel
## (UiAccent.for_heist, B4-07). Empty = no accent.
@export var heist_id: StringName = &""

var model: Node = null
var chevrons: DetectionChevrons
var marks: MarkedTargets
var interaction: InteractionPanel
var vitals: VitalsPanel
var ammo: AmmoPanel
var pager: PagerPanel
var objectives: ObjectivesPanel
var assault: AssaultBanner
var teammates: TeammatePanels
var status: StatusPanel
var custody: CustodyPanel
var captain: CaptainPanel
var stamina: StaminaBar
var toast_label: Label
var secured_bags: int = 0
var _lookup_t: float = 0.0
var _toast_t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if theme == null:
		theme = UiBuild.theme()
	_build()
	_connect_events()
	if model == null and not model_path.is_empty() and has_node(model_path):
		bind(get_node(model_path))


func bind(m: Node) -> void:
	model = m
	for w: HudWidget in widgets():
		w.bind(m)
	if m != null:
		model_bound.emit(m)


func widgets() -> Array[HudWidget]:
	return [chevrons, marks, interaction, vitals, ammo, pager, objectives, assault, teammates, status, custody, captain, stamina]


func _build() -> void:
	marks = _place(MarkedTargets.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as MarkedTargets
	chevrons = _place(DetectionChevrons.new(), Control.PRESET_FULL_RECT, Vector2.ZERO, Vector2.ZERO) as DetectionChevrons
	var crosshair: Label = UiBuild.label(&"ui.hud.crosshair", UiBuild.HUD)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(crosshair, Control.PRESET_CENTER, Vector2(-20, -20), Vector2(40, 40))
	interaction = _place(InteractionPanel.new(), Control.PRESET_CENTER, Vector2(-300, 60), Vector2(600, 110)) as InteractionPanel
	stamina = _place(StaminaBar.new(), Control.PRESET_BOTTOM_LEFT, Vector2(48, -248), Vector2(340, 40)) as StaminaBar
	vitals = _place(VitalsPanel.new(), Control.PRESET_BOTTOM_LEFT, Vector2(48, -200), Vector2(340, 160)) as VitalsPanel
	ammo = _place(AmmoPanel.new(), Control.PRESET_BOTTOM_RIGHT, Vector2(-388, -200), Vector2(340, 160)) as AmmoPanel
	teammates = _place(TeammatePanels.new(), Control.PRESET_CENTER_LEFT, Vector2(48, -120), Vector2(260, 400)) as TeammatePanels
	objectives = _place(ObjectivesPanel.new(), Control.PRESET_TOP_LEFT, Vector2(48, 48), Vector2(520, 200)) as ObjectivesPanel
	if heist_id != &"":
		objectives.set_accent(UiAccent.for_heist(heist_id))
	assault = _place(AssaultBanner.new(), Control.PRESET_CENTER_TOP, Vector2(-260, 40), Vector2(520, 56)) as AssaultBanner
	pager = _place(PagerPanel.new(), Control.PRESET_CENTER_TOP, Vector2(-200, 110), Vector2(400, 200)) as PagerPanel
	status = _place(StatusPanel.new(), Control.PRESET_TOP_RIGHT, Vector2(-448, 48), Vector2(400, 180)) as StatusPanel
	custody = _place(CustodyPanel.new(), Control.PRESET_CENTER, Vector2(-300, -200), Vector2(600, 130)) as CustodyPanel
	captain = _place(CaptainPanel.new(), Control.PRESET_CENTER_TOP, Vector2(-260, 104), Vector2(520, 84)) as CaptainPanel
	toast_label = UiBuild.label(&"", UiBuild.HUD_BIG)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(toast_label, Control.PRESET_CENTER, Vector2(-500, -260), Vector2(1000, 60))
	toast_label.visible = false


func _place(c: Control, preset: Control.LayoutPreset, offset: Vector2, min_size: Vector2) -> Control:
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


func _connect_events() -> void:
	EventBus.alarm_raised.connect(_on_alarm_raised)
	EventBus.loot_secured.connect(_on_loot_secured)
	EventBus.crew_downed.connect(_on_crew_downed)
	EventBus.crew_custody.connect(_on_crew_custody)


## Toast a strings key for TOAST_S seconds.
func toast(key: StringName, args: Dictionary = {}) -> void:
	toast_label.text = UiText.t(key, args)
	toast_label.visible = true
	_toast_t = TOAST_S


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_label.visible = _toast_t > 0.0
	if model != null and not is_instance_valid(model):
		bind(null)
	if model == null and auto_find_model:
		_lookup_t -= delta
		if _lookup_t <= 0.0:
			_lookup_t = LOOKUP_INTERVAL_S
			discover_model()


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
