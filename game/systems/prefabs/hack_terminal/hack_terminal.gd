## Timed silent hack (server rack, time-lock override; QC-12, D-040). Owner: ENV A.
## Interaction (kind &"start_hack", InteractionTweak.hack_start_s) starts a run of `duration_s`
## (-1 = InteractionTweak.hack_duration_s). Interruptions work like drill jams: the count is rolled
## at the start on GameRng &"devices" in [`interruptions`.x, `interruptions`.y] (-1 = the tweak's
## hack_interruptions), and interruption k of n sits at progress (k + 1) / (n + 1) ± a jitter
## (hack_interruption_jitter of one segment). While interrupted the same Interactable is kind
## &"restart_hack" (hack_restart_s); there is no auto-restart. Silent: no noise, no stimulus.
## Events (the device_* facts, kind &"hack"): device_started(net_id, &"hack", duration) /
## device_jammed / device_restarted(net_id, slot) / device_finished [R]; cues cue.hack_start,
## cue.hack_interrupt, cue.hack_done. On finish every `targets` node is opened like a finished drill
## (DrillPoint.open_target: `open_by_device()`, else `unlock()` + open).
## Visual: `Screen` (MeshInstance3D; its material_override follows the state) and `Panel`.
class_name HackTerminal
extends GameplayPrefab

enum State { IDLE, RUNNING, INTERRUPTED, DONE }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/hack_terminal/hack_terminal_placeholder.tscn")
const KIND: StringName = &"hack"
## Screen colour per State (placeholder feedback; art may ignore it).
const SCREEN_COLORS: Array[Color] = [
	Color(0.15, 0.2, 0.25), Color(0.2, 0.75, 0.35), Color(0.85, 0.2, 0.15), Color(0.6, 1.0, 0.7),
]

## Run time in s. -1 = InteractionTweak.hack_duration_s.
@export var duration_s: float = -1.0
## Rolled interruption count [min, max]. Negative = InteractionTweak.hack_interruptions.
@export var interruptions: Vector2i = Vector2i(-1, -1)
## What the hack opens (Door, Safe, ...).
@export var targets: Array[NodePath] = []
@export_group("Interaction")
## -1 = InteractionTweak.hack_start_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var state: State = State.IDLE
## 0..1.
var progress: float = 0.0
## Effective run time (s).
var duration: float = 0.0
## Remaining interruption points (progress fractions, ascending).
var pending_interruptions: Array[float] = []
## Interruptions rolled at the start (tests / HUD).
var rolled_interruptions: int = 0

var _start_time: float = 0.0
var _screen_mats: Array[StandardMaterial3D] = []


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Screen", "Panel"])


func _default_interaction_time() -> float:
	return Tweak.interaction().hack_start_s


func _prefab_ready() -> void:
	_start_time = interactable.interaction_time_s
	interactable.kind = &"start_hack"
	interactable.prompt_key = &"ui.prompt.start_hack"
	interactable.extra_check = _availability
	interactable.completed.connect(_on_completed)
	for c: Color in SCREEN_COLORS:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		_screen_mats.append(m)
	_update_screen()


## Effective run time (s) before the start.
func effective_duration() -> float:
	return duration_s if duration_s >= 0.0 else Tweak.interaction().hack_duration_s


## Rolled interruption range [min, max].
func interruption_range() -> Vector2i:
	var r: Vector2i = interruptions if interruptions.x >= 0 and interruptions.y >= 0 else Tweak.interaction().hack_interruptions
	return Vector2i(mini(r.x, r.y), maxi(r.x, r.y))


## Seconds of running left (excluding interruptions).
func time_left() -> float:
	if state == State.IDLE:
		return effective_duration()
	return maxf(1.0 - progress, 0.0) * duration


## Server: start the hack (interaction completion; tests may call it directly).
func start_hack(crew_slot: int) -> void:
	if not Net.is_authority() or state != State.IDLE:
		return
	duration = maxf(effective_duration(), 0.01)
	progress = 0.0
	_roll_interruptions()
	_emit_fact(&"device_started", [net_id, KIND, duration])
	_cue(&"cue.hack_start", global_position)
	Log.info(LOG_CHANNEL, "%s: hack started by slot %d (%.1f s, %d interruptions)" % [name, crew_slot, duration, rolled_interruptions])
	_set_state(State.RUNNING)


## Server: resume after an interruption.
func restart_hack(crew_slot: int) -> void:
	if not Net.is_authority() or state != State.INTERRUPTED:
		return
	_emit_fact(&"device_restarted", [net_id, crew_slot])
	_cue(&"cue.hack_start", global_position)
	_set_state(State.RUNNING)


func _physics_process(delta: float) -> void:
	if state != State.RUNNING or not Net.is_authority():
		return
	progress = minf(progress + delta / duration, 1.0)
	if not pending_interruptions.is_empty() and progress >= pending_interruptions[0] and progress < 1.0:
		pending_interruptions.pop_front()
		_emit_fact(&"device_jammed", [net_id])
		_cue(&"cue.hack_interrupt", global_position)
		_set_state(State.INTERRUPTED)
	elif progress >= 1.0:
		_emit_fact(&"device_finished", [net_id])
		_cue(&"cue.hack_done", global_position)
		_set_state(State.DONE)
		for p: NodePath in targets:
			DrillPoint.open_target(get_node_or_null(p) if not p.is_empty() else null)


func _roll_interruptions() -> void:
	var rng: RandomNumberGenerator = GameRng.stream(&"devices")
	var r: Vector2i = interruption_range()
	var n: int = rng.randi_range(maxi(r.x, 0), maxi(r.y, 0))
	rolled_interruptions = n
	pending_interruptions.clear()
	var seg: float = 1.0 / float(n + 1)
	var jitter: float = clampf(Tweak.interaction().hack_interruption_jitter, 0.0, 0.49) * seg
	for k: int in range(n):
		var at: float = seg * float(k + 1) + rng.randf_range(-jitter, jitter)
		pending_interruptions.append(clampf(at, 0.01, 0.99))
	pending_interruptions.sort()


func _availability(_crew: Node) -> StringName:
	if state == State.IDLE or state == State.INTERRUPTED:
		return InteractableComponent.BLOCK_NONE
	return InteractableComponent.BLOCK_STATE


func _on_completed(crew: Node) -> void:
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	match state:
		State.IDLE:
			start_hack(slot)
		State.INTERRUPTED:
			restart_hack(slot)


func _set_state(s: State) -> void:
	state = s
	match s:
		State.INTERRUPTED:
			interactable.kind = &"restart_hack"
			interactable.interaction_time_s = Tweak.interaction().hack_restart_s
			interactable.prompt_key = &"ui.prompt.restart_hack"
		State.DONE:
			interactable.enabled = false
		_:
			interactable.kind = &"start_hack"
			interactable.interaction_time_s = _start_time
			interactable.prompt_key = &"ui.prompt.start_hack"
	_update_screen()


func _update_screen() -> void:
	var screen: MeshInstance3D = visual_node("Screen") as MeshInstance3D
	if screen != null and int(state) < _screen_mats.size():
		screen.material_override = _screen_mats[int(state)]
