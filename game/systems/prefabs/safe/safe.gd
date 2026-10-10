## Lockable safe / vault (S9.8). Owner: ENV A. Opened by any of `methods`:
## &"drill", &"saw" (S9.4), &"c4", &"lockpick" (SMALL only, needs interaction.can_lockpick_safes),
## &"code" (S9.7, `code_group` known to the crew).
## Visual: `Body`, `Door` (pivot at hinge), `DrillPoint` marker (-Z into the lock), `LootAnchor`.
## Floor object: pivot bottom-centre, door on the front (-Z).
## One `Interactable` serves every method. For each crew member it offers the first usable method
## in METHOD_ORDER (code, lockpick, drill, saw, c4) and sets `kind` / `prompt_key` / hold time:
##   code      kind &"enter_code"   keypad_s; blocked `ui.blocked.code_unknown` until a note is read
##   lockpick  kind &"lockpick"     safe_lockpick_s × interaction.lockpick_speed_mult
##   drill/saw kind &"place_drill" / &"place_saw": DeviceRunner (time by `size` from
##             safe_drill_duration_s / safe_saw_duration_s; jams -> kind &"fix_drill", drill_fix_s)
##   c4        kind &"place_c4"     c4_place_s, consumes `item.c4`; after c4_fuse_s it blows the lock:
##             noise &"explosion" (c4_noise_radius_m), cue.c4_explode, device_started/finished(&"c4"),
##             and an L3.6 blast (`Explosion.apply`, c4_blast_radius_m / c4_blast_damage) at the lock
##             attributed to the crew member who placed it (so it never hurts the crew)
## A drill_point whose `target` is this safe also works (`open_by_device()`).
## A2-08 KEYCARD: with &"keycard" in `methods` the safe is opened by a keycard_reader (the safe's
## own Interactable never offers it). Wire it either way (both may be set, it opens once):
##   * the reader's `targets` lists the safe, or
##   * the safe's `reader` export points at the reader (the safe binds itself at ready).
## A completed reader (keycard, or ECM on the reader) calls `open_by_keycard()`: the lock is beaten
## (beaten_by = &"keycard"), then the time lock applies as for any method. Without &"keycard" in
## `methods` the call is ignored with a warning.
## Time lock (`time_lock_s` > 0, vaults): beating the lock does not open the door. The same
## Interactable becomes kind &"start_time_lock" (hold time_lock_start_s, a normal hold: interrupted =
## start again); then the timer runs time_lock_s (device_started(net_id, &"time_lock", s) ...
## device_finished) and the door swings. P2 simplification of the "hackable panel": the timer, once
## started, cannot be paused or interrupted.
## Opening swings `Door` and enables the loot inside: any SmallLoot / LootSpawn / GameplayPrefab
## child with an Interactable is disabled until then.
class_name Safe
extends GameplayPrefab

enum Size { SMALL, MEDIUM, LARGE }
## LOCKED -> (C4_ARMED) -> [TIME_LOCK -> TIME_LOCK_RUNNING] -> OPEN.
enum Stage { LOCKED, C4_ARMED, TIME_LOCK, TIME_LOCK_RUNNING, OPEN }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/safe/safe_placeholder.tscn")
const C4_ITEM: StringName = &"item.c4"
## Preference when several methods are usable by the same crew member.
const METHOD_ORDER: Array[StringName] = [&"code", &"lockpick", &"drill", &"saw", &"c4"]
## method -> [kind, prompt_key].
const METHOD_UI: Dictionary = {
	&"code": [&"enter_code", &"ui.prompt.enter_code"],
	&"lockpick": [&"lockpick", &"ui.prompt.pick_lock"],
	&"drill": [&"place_drill", &"ui.prompt.place_drill"],
	&"saw": [&"place_saw", &"ui.prompt.place_saw"],
	&"c4": [&"place_c4", &"ui.prompt.place_c4"],
	&"fix": [&"fix_drill", &"ui.prompt.fix_drill"],
	&"time_lock": [&"start_time_lock", &"ui.prompt.start_time_lock"],
}

@export var size: Size = Size.MEDIUM
@export var methods: Array[StringName] = [&"drill"]
## S9.7: code group for the &"code" method.
@export var code_group: StringName = &""
## S9.8: vault time lock in s (0 = none), see the header.
@export var time_lock_s: float = 0.0
## A2-08: keycard_reader that opens this safe (`methods` must contain &"keycard"). Optional: the
## reader's own `targets` listing this safe works the same.
@export var reader: NodePath = NodePath("")
## Collision box size (m), placed on the pivot; ZERO = fit to the visual (or use the visual's own
## `Collision`), see GameplayPrefab "Collision fitting".
@export var collision_size_override: Vector3 = Vector3.ZERO
@export_group("Interaction")
## -1 = InteractionTweak.drill_place_s (placing the drill on `DrillPoint`).
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var opened: bool = false
var stage: Stage = Stage.LOCKED
var runner: DeviceRunner = null
## Seconds left on the armed C4 fuse or the running time lock (-1 = none).
var timer_left: float = -1.0
## Method that beat the lock (&"code", &"lockpick", &"c4", &"device"), &"" while locked.
var beaten_by: StringName = &""

var _place_time: float = 0.0
## net_id of the crew member who armed the C4 (blast attacker), 0 = none.
var _c4_by_net_id: int = 0
## Method chosen when the current hold started.
var _session_method: StringName = &""


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Body", "Door", "DrillPoint", "LootAnchor"])


func _default_interaction_time() -> float:
	return Tweak.interaction().drill_place_s


## The fitted collision follows `Body` (the swinging `Door` is not part of the box).
func _collision_source_node() -> String:
	return "Body"


func _prefab_ready() -> void:
	_place_time = interactable.interaction_time_s
	if methods.has(&"drill") or methods.has(&"saw"):
		runner = DeviceRunner.new(self, &"drill" if methods.has(&"drill") else &"saw")
		runner.finished.connect(open_by_device)
	var first: StringName = &""
	for m: StringName in METHOD_ORDER:
		if methods.has(m):
			first = m
			break
	if first == &"":
		interactable.enabled = false  # opened by a drill_point / mission only
	else:
		_apply_ui(first)
	interactable.extra_check = _availability
	interactable.duration_override = _duration_for
	interactable.started.connect(_on_started)
	interactable.cancelled.connect(func(_c: Node) -> void: _session_method = &"")
	interactable.completed.connect(_on_completed)
	for p: GameplayPrefab in _inner_loot():
		p.interactable.enabled = false
	_bind_reader()
	# A1-03 behaviour (P3): hackable time-lock panel.


## Server: a device finished, the C4 blew, or the mission forces it: the lock is beaten. Opens the
## door now, or arms the time lock first (`time_lock_s` > 0).
func open_by_device() -> void:
	_lock_beaten(&"device")


## Server: a bound keycard_reader was used (A2-08 KEYCARD method).
func open_by_keycard() -> void:
	if not Net.is_authority():
		return
	if not methods.has(&"keycard"):
		Log.warn(LOG_CHANNEL, "%s: keycard reader used but `methods` has no &\"keycard\"" % name)
		return
	_lock_beaten(&"keycard")


## Server: swing the door open now (also skips a time lock; missions).
func swing_open() -> void:
	if opened:
		return
	opened = true
	stage = Stage.OPEN
	timer_left = -1.0
	var door: Node3D = visual_node("Door") as Node3D
	if door != null:
		door.rotation.y = -deg_to_rad(Tweak.interaction().safe_door_open_deg)
	if interactable != null:
		interactable.enabled = false
	for p: GameplayPrefab in _inner_loot():
		p.interactable.enabled = true


## Drill time by `size` (s).
func drill_duration() -> float:
	return _by_size(Tweak.interaction().safe_drill_duration_s, Tweak.interaction().drill_duration_s)


## Saw time by `size` (s).
func saw_duration() -> float:
	return _by_size(Tweak.interaction().safe_saw_duration_s, Tweak.interaction().saw_duration_s)


## Method `crew` would use now (&"" = none; see `availability` for why).
func method_for(crew: Node) -> StringName:
	return StringName(_pick(crew)[0])


func _by_size(t: PackedFloat32Array, fallback: float) -> float:
	if t.is_empty():
		return fallback
	return t[clampi(int(size), 0, t.size() - 1)]


func _physics_process(delta: float) -> void:
	if runner != null:
		runner.tick(delta)
	if timer_left < 0.0 or not Net.is_authority():
		return
	timer_left -= delta
	if timer_left > 0.0:
		return
	timer_left = -1.0
	_emit_fact(&"device_finished", [net_id])
	if stage == Stage.C4_ARMED:
		_explode()
	elif stage == Stage.TIME_LOCK_RUNNING:
		_cue(&"cue.time_lock_done", global_position)
		swing_open()


func _exit_tree() -> void:
	if runner != null:
		runner.shutdown()


# --- Method selection --------------------------------------------------------------

## [method, reason]: what `crew` can do now.
func _pick(crew: Node) -> Array:
	if stage != Stage.LOCKED:
		return _pick_staged()
	if runner != null and runner.state != DeviceRunner.State.IDLE:
		if runner.state == DeviceRunner.State.JAMMED:
			return [&"fix", InteractableComponent.BLOCK_NONE]
		return [&"", InteractableComponent.BLOCK_STATE]
	var first_block: StringName = &""
	for m: StringName in METHOD_ORDER:
		if not methods.has(m):
			continue
		var r: StringName = _method_block(m, crew)
		if r == InteractableComponent.BLOCK_NONE:
			return [m, r]
		if first_block == &"":
			first_block = r
	return [&"", first_block if first_block != &"" else InteractableComponent.BLOCK_DISABLED]


func _pick_staged() -> Array:
	match stage:
		Stage.TIME_LOCK:
			return [&"time_lock", InteractableComponent.BLOCK_NONE]
		Stage.OPEN:
			return [&"", InteractableComponent.BLOCK_DISABLED]
	return [&"", InteractableComponent.BLOCK_STATE]


func _method_block(m: StringName, crew: Node) -> StringName:
	var c: CrewController = crew as CrewController
	var ok: bool = false
	match m:
		&"code":
			var reg: CodeRegistry = CodeRegistry.of(self)
			if code_group != &"" and reg != null and not reg.is_known(code_group):
				return CodeRegistry.BLOCK_CODE_UNKNOWN
			ok = code_group != &"" and reg != null
		&"lockpick":
			ok = size == Size.SMALL and c != null and Modifiers.flag(c.slot, &"interaction.can_lockpick_safes")
		&"drill", &"saw":
			ok = runner != null and runner.kind == m
		&"c4":
			if c != null and c.item_count(C4_ITEM) <= 0:
				return InteractableComponent.BLOCK_ITEM
			ok = c != null
	return InteractableComponent.BLOCK_NONE if ok else InteractableComponent.BLOCK_STATE


func _availability(crew: Node) -> StringName:
	var pick: Array = _pick(crew)
	if StringName(pick[0]) != &"" and _session_method == &"":
		_apply_ui(StringName(pick[0]))
	return StringName(pick[1])


func _duration_for(crew: Node, base: float) -> float:
	var tw: InteractionTweak = Tweak.interaction()
	var m: StringName = _session_method if _session_method != &"" else method_for(crew)
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	match m:
		&"code":
			return tw.keypad_s
		&"lockpick":
			return tw.safe_lockpick_s * (Modifiers.mult(slot, &"interaction.lockpick_speed_mult") if slot >= 0 else 1.0)
		&"c4":
			return tw.c4_place_s
		&"fix":
			return tw.drill_fix_s
		&"time_lock":
			return tw.time_lock_start_s
	return _place_time if m == &"drill" or m == &"saw" else base


func _apply_ui(m: StringName) -> void:
	var ui: Array = METHOD_UI.get(m, [])
	if ui.size() == 2:
		interactable.kind = ui[0]
		interactable.prompt_key = ui[1]


# --- Actions -----------------------------------------------------------------------

func _on_started(crew: Node) -> void:
	_session_method = method_for(crew)
	_apply_ui(_session_method)


func _on_completed(crew: Node) -> void:
	var m: StringName = _session_method
	_session_method = &""
	if not Net.is_authority() or opened:
		return
	var c: CrewController = crew as CrewController
	var slot: int = c.slot if c != null else -1
	match m:
		&"fix":
			runner.fix(slot)
		&"drill":
			runner.place(slot, drill_duration())
		&"saw":
			runner.place(slot, saw_duration())
		&"code", &"lockpick":
			_lock_beaten(m)
		&"c4":
			if c != null and c.remove_item(C4_ITEM, 1):
				stage = Stage.C4_ARMED
				_c4_by_net_id = NetIds.of(c)
				timer_left = Tweak.interaction().c4_fuse_s
				_emit_fact(&"device_started", [net_id, &"c4", timer_left])
				_cue(&"cue.c4_armed", global_position)
		&"time_lock":
			stage = Stage.TIME_LOCK_RUNNING
			timer_left = maxf(time_lock_s, 0.01)
			_emit_fact(&"device_started", [net_id, &"time_lock", timer_left])
			_cue(&"cue.time_lock_start", global_position)


func _explode() -> void:
	var pos: Vector3 = global_position + Vector3.UP * 0.6
	_cue(&"cue.c4_explode", pos)
	var tw: InteractionTweak = Tweak.interaction()
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null:
		rt.make_noise(pos, tw.c4_noise_radius_m, &"explosion", net_id)
	var drill: Node3D = visual_node("DrillPoint") as Node3D
	var blast: Vector3 = drill.global_position if drill != null else pos
	Explosion.apply(self, blast, tw.c4_blast_radius_m, tw.c4_blast_damage, _c4_by_net_id, C4_ITEM)
	_c4_by_net_id = 0
	_lock_beaten(&"c4")


func _lock_beaten(how: StringName) -> void:
	if opened or not (stage == Stage.LOCKED or stage == Stage.C4_ARMED):
		return
	beaten_by = how
	if time_lock_s > 0.0:
		stage = Stage.TIME_LOCK
		interactable.enabled = true
		_apply_ui(&"time_lock")
	else:
		swing_open()


func _bind_reader() -> void:
	if reader.is_empty():
		return
	var r: KeycardReader = get_node_or_null(reader) as KeycardReader
	if r == null:
		Log.error(LOG_CHANNEL, "%s: `reader` %s is not a KeycardReader" % [name, reader])
		return
	if not methods.has(&"keycard"):
		Log.warn(LOG_CHANNEL, "%s: `reader` set but `methods` has no &\"keycard\"" % name)
	r.bind_target(self)


## Loot prefabs inside this safe (descendants outside `Visual`).
func _inner_loot() -> Array[GameplayPrefab]:
	var out: Array[GameplayPrefab] = []
	var stack: Array[Node] = []
	for c: Node in get_children():
		if c != visual_root:
			stack.append(c)
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var p: GameplayPrefab = n as GameplayPrefab
		if p != null and p.interactable != null:
			out.append(p)
		for c: Node in n.get_children():
			stack.append(c)
	return out
