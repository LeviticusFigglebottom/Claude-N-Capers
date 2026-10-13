## PO-4 UI sound cues (D-090, contracts/audio_cues.md v1.5). Owner: ENV B.
## The one place UI code plays a sound: menus, HUD widgets and the payday screen call
## `UiSfx.play(&"cue.ui_...")`, and UiBuild wires every button it makes through `UiSfx.wire()`
## (focus cue on keyboard / pad navigation, a press cue picked by the button's kind).
## UI sounds are local presentation: they are played here directly on the UI bus (2D) and are never
## sent through EventBus.audio_cue_requested (so the heist CuePlayer does not double them and nothing
## replicates). Cue definitions come from ENV C's registry (world/audio/cues.tres, looked up by class
## name, no hard path); a cue missing from the registry is silent. Headless: requests are recorded in
## `played` (tests) but no player node is created.
class_name UiSfx
extends Node

const FOCUS: StringName = &"cue.ui_focus"
const CONFIRM: StringName = &"cue.ui_confirm"
const BACK: StringName = &"cue.ui_back"
const PRIMARY: StringName = &"cue.ui_primary"
const ERROR: StringName = &"cue.ui_error"
const TAB: StringName = &"cue.ui_tab"
const OBJECTIVE_DONE: StringName = &"cue.hud_objective_done"
const HINT: StringName = &"cue.hud_hint"
const PAYDAY_TOTAL: StringName = &"cue.payday_total"
const PAYDAY_TICK: StringName = &"cue.payday_tick"
const CARD_FLIP: StringName = &"cue.card_flip"
## Every UI cue id (tests check each one is in the registry).
const ALL: Array[StringName] = [FOCUS, CONFIRM, BACK, PRIMARY, ERROR, TAB, OBJECTIVE_DONE, HINT,
		PAYDAY_TOTAL, PAYDAY_TICK, CARD_FLIP]

## Button kinds (UiBuild): which cue a press plays. &"none" = focus cue only.
const KIND_CONFIRM: StringName = &"confirm"
const KIND_PRIMARY: StringName = &"primary"
const KIND_BACK: StringName = &"back"
const KIND_TAB: StringName = &"tab"
const KIND_NONE: StringName = &"none"
const KIND_CUES: Dictionary[StringName, StringName] = {
	KIND_CONFIRM: CONFIRM, KIND_PRIMARY: PRIMARY, KIND_BACK: BACK, KIND_TAB: TAB, KIND_NONE: &"",
}
## Meta on a wired button: its kind (StringName).
const KIND_META: StringName = &"ui_sfx_kind"

## The focus cue plays only when focus moved within this long after a keyboard / pad navigation
## input, so screens grabbing focus on open (and mouse clicks) stay quiet.
const NAV_WINDOW_MS: int = 350
const NAV_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next",
		&"ui_focus_prev", &"ui_page_up", &"ui_page_down", &"ui_payday_prev", &"ui_payday_next"]
## Floor for the per-cue repeat guard (the registry's cooldown_s wins when longer).
const MIN_REPEAT_S: float = 0.03
const POOL: int = 6
const PLAYED_CAP: int = 64

## Global UI sound switch (tests, captures).
static var enabled: bool = true
## Cue ids actually requested (after the repeat guard), oldest first; capped at PLAYED_CAP (tests).
static var played: Array[StringName] = []

static var _instance: UiSfx = null
static var _nav_ms: int = -1000000
static var _last_ms: Dictionary[StringName, int] = {}
static var _lib: Script = null
static var _lib_checked: bool = false

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending: Array[Resource] = []


## Wire `b` for UI sounds: focus cue (navigation only) + the press cue of `kind`. Calling it again
## only changes the kind. Returns `b`.
static func wire(b: BaseButton, kind: StringName = KIND_CONFIRM) -> BaseButton:
	var first: bool = not b.has_meta(KIND_META)
	b.set_meta(KIND_META, kind)
	if first:
		b.focus_entered.connect(_on_focus_entered)
		b.pressed.connect(_on_pressed.bind(b))
		b.gui_input.connect(_on_gui_input.bind(b))
		if DisplayServer.get_name() != "headless":
			_ensure()  # the player node also watches navigation input for the focus cue
	return b


## Lane 6: a click / accept on a disabled button (can't afford, locked, nothing selected) buzzes.
static func _on_gui_input(event: InputEvent, b: BaseButton) -> void:
	if not b.disabled:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed(&"ui_accept"):
		play(ERROR)


## Lane 6: plays the error cue when an action reports failure; returns `ok` (wrap action results).
static func check(ok: bool) -> bool:
	if not ok:
		play(ERROR)
	return ok


## The kind `b` was wired with (&"" = not wired).
static func kind_of(b: BaseButton) -> StringName:
	return StringName(b.get_meta(KIND_META, &""))


## The cue a press of `b` plays (&"" = none).
static func press_cue(b: BaseButton) -> StringName:
	return KIND_CUES.get(kind_of(b), &"")


## Play UI cue `cue_id` once. Returns whether it was requested (false: disabled, unknown cue, or the
## same cue repeated within its cooldown).
static func play(cue_id: StringName) -> bool:
	if not enabled or cue_id == &"":
		return false
	var def: Resource = cue_def(cue_id)
	if def == null:
		return false
	var now: int = Time.get_ticks_msec()
	var guard_ms: int = int(maxf(float(def.get(&"cooldown_s")), MIN_REPEAT_S) * 1000.0)
	if _last_ms.has(cue_id) and now - _last_ms[cue_id] < guard_ms:
		return false
	_last_ms[cue_id] = now
	played.append(cue_id)
	if played.size() > PLAYED_CAP:
		played.pop_front()
	if DisplayServer.get_name() == "headless":
		return true
	var inst: UiSfx = _ensure()
	if inst != null:
		inst._start(def)
	return true


## Record a keyboard / pad navigation input now (the next focus change within NAV_WINDOW_MS plays
## the focus cue). Called from the player node's _input; tests call it directly.
static func note_navigation() -> void:
	_nav_ms = Time.get_ticks_msec()


static func navigated_recently() -> bool:
	return Time.get_ticks_msec() - _nav_ms <= NAV_WINDOW_MS


## Tests: forget repeat guards, navigation and the played log.
static func reset() -> void:
	_last_ms.clear()
	played.clear()
	_nav_ms = -1000000


## ENV C's AudioCueDef for `cue_id` from the default registry (null when absent).
static func cue_def(cue_id: StringName) -> Resource:
	var lib: Script = _cue_lib()
	if lib == null:
		return null
	var reg: Object = lib.call(&"registry") as Object
	if reg == null:
		return null
	var def: Resource = reg.call(&"get_cue", cue_id) as Resource
	if def == null or (def.get(&"streams") as Array).is_empty():
		return null
	return def


static func _cue_lib() -> Script:
	if not _lib_checked:
		_lib_checked = true
		_lib = UiNav.global_class(&"AudioCueLib")
	return _lib


static func _on_focus_entered() -> void:
	if navigated_recently():
		play(FOCUS)


static func _on_pressed(b: BaseButton) -> void:
	play(press_cue(b))


static func _ensure() -> UiSfx:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_instance = UiSfx.new()
	_instance.name = "UiSfx"
	tree.root.add_child.call_deferred(_instance)  # the root may be busy setting up children
	return _instance


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # pause menu sounds play while the tree is paused
	_rng.seed = 0x5F_0D90  # presentation-only pitch jitter; deterministic, not gameplay


func _ready() -> void:
	var lib: Script = _cue_lib()
	if lib != null:
		lib.call(&"ensure_buses")
	for i: int in range(POOL):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "P%d" % i
		add_child(p)
		_players.append(p)
	for def: Resource in _pending:
		_start(def)
	_pending.clear()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _input(event: InputEvent) -> void:
	if event is InputEventMouse or not event.is_pressed():
		return
	for a: StringName in NAV_ACTIONS:
		if InputMap.has_action(a) and event.is_action_pressed(a, true):
			note_navigation()
			return


func _start(def: Resource) -> void:
	if _players.is_empty():
		if _pending.size() < POOL:
			_pending.append(def)
		return
	var streams: Array = def.get(&"streams") as Array
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stop()
	p.stream = streams[0] if streams.size() == 1 else streams[_rng.randi_range(0, streams.size() - 1)]
	p.volume_db = float(def.get(&"volume_db"))
	var jitter: float = float(def.get(&"pitch_jitter"))
	p.pitch_scale = 1.0 + (_rng.randf_range(-jitter, jitter) if jitter > 0.0 else 0.0)
	var bus: StringName = StringName(def.get(&"bus"))
	p.bus = bus if AudioServer.get_bus_index(bus) != -1 else &"Master"
	p.play()
