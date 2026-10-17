## Padlock on a grate, gate or door (QC-37; Night Deposit vent, Shadow Ledger cage, Dockside Burn). Owner: ENV A.
## Opened by lockpicking (kind &"lockpick", InteractionTweak.lockpick_door_s x interaction.lockpick_speed_mult,
## S9.2; `allow_lockpick`) or by cutting it with the handheld saw (G.SAW_TARGET, `saw_cut`, hand_saw_padlock_s).
## Opening unlocks/opens every `targets` node (DrillPoint.open_target: Safe.open_by_device, Door unlock + open).
## Placed methods (D-115 DB-8, D-138.2), all on the one Interactable:
##   saw   `place_saw`: once loud, or at any time with `place_saw_stealth` (its noise is the saw's own: DeviceRunner
##         kind &"saw", StealthTweak.saw_radius_m while stealth). Runs `saw_duration_s` (-1 =
##         InteractionTweak.padlock_saw_duration_s).
##   drill `place_drill`: at any time (a drill's noise, drill_radius_m). Runs `drill_duration_s` (-1 = the node's
##         `drill_duration_s` meta when set, else InteractionTweak.drill_duration_s, DrillPoint's drill default).
##   Both: kind &"place_saw" / &"place_drill" (drill_place_s), one DeviceRunner (`runner`, its kind set at
##   placement and replicated as `placed_kind`) x interaction.device_speed_mult with the PD2 jams (D-114 §2; fix:
##   kind &"fix_drill", drill_fix_s; auto-restart), device_started / jammed / restarted / finished [R] (the HUD
##   device row), the device art (DeviceVisual: DrillPoint.DEFAULT_SAW / DEFAULT_DEVICE) while placed, and the
##   lock opens forced (the fast breach swing) when done.
##   c4    `place_c4`: kind &"place_c4" (c4_place_s), pays one charge (Safe.consume_charges_for: item.c4, or trip
##         mines with interaction.shaped_charge); device_started(&"c4", c4_fuse_s); after the fuse it blows like a
##         Safe's C4 (cue.c4_explode, &"explosion" noise c4_noise_radius_m: loud, Explosion.apply at the lock
##         attributed to the placer), device_finished, and the lock opens forced.
## Choice when several are usable (Safe's METHOD_ORDER pattern, one prompt per crew member): in stealth the quiet
## lockpick first, then drill, saw, c4; loud the devices first (drill, saw, c4), the lockpick last.
## `requires_item` gates the lockpick only when a placed method exists (else the whole interaction, as before).
## Missions (D-138.4): `opened`, `beaten_by` (&"lockpick" / &"saw" / &"drill" / &"c4" / &"forced"), the server
## signal `lock_opened(method)`, and device_finished(net_id) for the saw / drill / c4.
class_name Padlock
extends GameplayPrefab

## Server: the padlock came off (`method` as `beaten_by`).
signal lock_opened(method: StringName)

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/padlock/padlock_placeholder.tscn")
const KIND_LOCKPICK: StringName = &"lockpick"
const KIND_PLACE_SAW: StringName = &"place_saw"
const KIND_PLACE_DRILL: StringName = &"place_drill"
const KIND_PLACE_C4: StringName = &"place_c4"
const KIND_FIX: StringName = &"fix_drill"
## method -> [interactable kind, prompt_key].
const METHOD_UI: Dictionary = {
	&"lockpick": [KIND_LOCKPICK, &"ui.prompt.pick_lock"],
	&"saw": [KIND_PLACE_SAW, &"ui.prompt.place_saw"],
	&"drill": [KIND_PLACE_DRILL, &"ui.prompt.place_drill"],
	&"c4": [KIND_PLACE_C4, &"ui.prompt.place_c4"],
	&"fix": [KIND_FIX, &"ui.prompt.fix_drill"],
}
const ORDER_STEALTH: Array[StringName] = [&"lockpick", &"drill", &"saw", &"c4"]
const ORDER_LOUD: Array[StringName] = [&"drill", &"saw", &"c4", &"lockpick"]
const DRILL_DURATION_META: StringName = &"drill_duration_s"
## PO-14 device review (D cb022207): the saw blade / drill bit stand off the door leaf by this much (m) out of the lock.
const SAW_OUT_M: float = 0.08
const DRILL_OUT_M: float = 0.04

@export var targets: Array[NodePath] = []
## D-138: false = no lockpick (nor its requires_item hold): only the placed methods / handheld saw open it.
@export var allow_lockpick: bool = true
@export_group("Placed saw")
## D-115 (DB-8): a placed saw cuts this padlock once the heist is loud.
@export var place_saw: bool = false
## D-138.2: the placed saw may also go on in stealth (its noise is the saw's own radius).
@export var place_saw_stealth: bool = false
## Placed-saw run time (s); -1 = InteractionTweak.padlock_saw_duration_s.
@export var saw_duration_s: float = -1.0
## The device shown while placed (null = DeviceVisual.scene_for(kind): the catalog saw / drill).
@export var device_scene: PackedScene
@export_group("Placed drill")
## D-138.2: a placed drill (any time) opens this padlock.
@export var place_drill: bool = false
## Placed-drill run time (s); -1 = the `drill_duration_s` meta, else InteractionTweak.drill_duration_s.
@export var drill_duration_s: float = -1.0
@export_group("C4")
## D-138.2: a C4 charge blows this padlock (loud).
@export var place_c4: bool = false
@export_group("Interaction")
## -1 = InteractionTweak.lockpick_door_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var opened: bool = false
## How the lock came off (&"" while on); see the header.
var beaten_by: StringName = &""
var saw_progress: float = 0.0
## The placed saw / drill (null without place_saw / place_drill). LocalHudModel / NetEntityCodec read it as `runner`.
var runner: DeviceRunner = null
## The device kind last placed (&"saw" / &"drill"; replicated so clients show the right art and HUD row).
var placed_kind: StringName = &"":
	set(v):
		placed_kind = v
		if runner != null and v != &"":
			runner.kind = v
## Seconds left on an armed C4 fuse (-1 = none; replicated, the HUD c4 row).
var timer_left: float = -1.0
## The placed device visual while RUNNING / JAMMED (null otherwise).
var device_node: Node3D:
	get:
		return _visual.node

var _visual: DeviceVisual = DeviceVisual.new()
var _session: StringName = &""
var _lock_item: StringName = &""
var _c4_by_net_id: int = 0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().lockpick_door_s


func _prefab_ready() -> void:
	add_to_group(G.SAW_TARGET)
	if place_saw or place_drill:
		runner = DeviceRunner.new(self, &"drill" if place_drill else &"saw")
		runner.state_changed.connect(_on_device_state)
		runner.finished.connect(func() -> void: open_lock(true, runner.kind))
	if _has_placed_method():
		_lock_item = interactable.requires_item  # the item gates the lockpick only
		interactable.requires_item = &""
	interactable.extra_check = _availability
	interactable.duration_override = _duration_for
	interactable.started.connect(func(crew: Node) -> void:
		_session = _pick(crew)[0]
		_apply_ui(_session))
	interactable.cancelled.connect(func(_c: Node) -> void: _session = &"")
	interactable.completed.connect(_on_completed)
	var first: Array = _pick(null)
	_apply_ui(first[0] if first[0] != &"" else (&"lockpick" if allow_lockpick else &"saw"))


## Placed-saw run time (s) before modifiers.
func effective_saw_duration() -> float:
	return saw_duration_s if saw_duration_s > 0.0 else Tweak.interaction().padlock_saw_duration_s


## Placed-drill run time (s) before modifiers.
func effective_drill_duration() -> float:
	if drill_duration_s > 0.0:
		return drill_duration_s
	if has_meta(DRILL_DURATION_META) and float(get_meta(DRILL_DURATION_META)) > 0.0:
		return float(get_meta(DRILL_DURATION_META))
	return Tweak.interaction().drill_duration_s


## True while a C4 charge is armed on the lock.
func c4_armed() -> bool:
	return timer_left >= 0.0 and not opened


func _physics_process(delta: float) -> void:
	if runner != null:
		runner.tick(delta)
	if timer_left < 0.0 or not Net.is_authority():
		return
	timer_left -= delta
	if timer_left <= 0.0:
		timer_left = -1.0
		_explode()


func _process(delta: float) -> void:
	if runner != null:
		_visual.tick(delta, runner.state == DeviceRunner.State.RUNNING)


func _exit_tree() -> void:
	if runner != null:
		runner.shutdown()


## Server (QC-37): the handheld saw cut the padlock for `seconds`.
func saw_cut(seconds: float, _attacker_net_id: int) -> void:
	if not Net.is_authority() or opened:
		return
	saw_progress = minf(saw_progress + seconds / maxf(Tweak.interaction().hand_saw_padlock_s, 0.01), 1.0)
	if saw_progress >= 1.0 - 0.0001:
		open_lock(true, &"saw")


## Server: the padlock is off (lockpicked, sawn, drilled, blown, or forced by the mission): open every target.
## PO-6: `forced` swings target doors with the fast breach swing. `how` is recorded as `beaten_by`.
func open_lock(forced: bool = false, how: StringName = &"forced") -> void:
	if not Net.is_authority() or opened:
		return
	opened = true
	beaten_by = how
	if runner != null:
		runner.abort()  # opened another way while a placed device runs: stop it (no-op when it finished)
	if timer_left >= 0.0:
		timer_left = -1.0  # opened another way while the C4 fuse burns: its HUD row stops
		_emit_fact(&"device_finished", [net_id])
	interactable.enabled = false
	var shackle: Node3D = visual_node("Shackle") as Node3D
	if shackle != null:
		shackle.visible = false
	for path: NodePath in targets:
		var t: Node = get_node_or_null(path)
		if t == null:
			Log.warn(&"prefab", "%s: padlock target %s not found" % [name, path])
		else:
			DrillPoint.open_target(t, forced)
	lock_opened.emit(how)


# --- Method selection (DB-8, D-138.2) ---------------------------------------------------------

func _has_placed_method() -> bool:
	return place_saw or place_drill or place_c4


## [method, block reason] `crew` would get now: lockpick / saw / drill / c4 / fix, or &"" with the reason.
func _pick(crew: Node) -> Array:
	var busy: Array = _pick_busy()
	if not busy.is_empty():
		return busy
	var first_block: StringName = &""
	for m: StringName in (ORDER_LOUD if _loud() else ORDER_STEALTH):
		var r: StringName = _method_block(m, crew)
		if r == InteractableComponent.BLOCK_NONE:
			return [m, r]
		if first_block == &"" and r != InteractableComponent.BLOCK_DISABLED:
			first_block = r
	return [&"", first_block if first_block != &"" else InteractableComponent.BLOCK_STATE]


## [] when the lock is free to take a method; else what a running / jammed / done device or armed C4 offers.
func _pick_busy() -> Array:
	if opened:
		return [&"", DrillPoint.BLOCK_DONE]
	if timer_left >= 0.0:
		return [&"", DrillPoint.BLOCK_RUNNING]
	if runner == null or runner.state == DeviceRunner.State.IDLE:
		return []
	match runner.state:
		DeviceRunner.State.JAMMED:
			return [&"fix", InteractableComponent.BLOCK_NONE]
		DeviceRunner.State.RUNNING:
			return [&"", DrillPoint.BLOCK_RUNNING]
	return [&"", DrillPoint.BLOCK_DONE]


func _method_block(m: StringName, crew: Node) -> StringName:
	var none: StringName = InteractableComponent.BLOCK_NONE
	var off: StringName = InteractableComponent.BLOCK_DISABLED
	match m:
		&"lockpick":
			return _lockpick_block(crew) if allow_lockpick else off
		&"saw":
			if not place_saw:
				return off
			return none if place_saw_stealth or _loud() else InteractableComponent.BLOCK_PHASE
		&"drill":
			return none if place_drill else off
		&"c4":
			return _c4_block(crew) if place_c4 else off
	return off


func _lockpick_block(crew: Node) -> StringName:
	if _lock_item != &"" and crew != null and crew.has_method(&"item_count") \
			and int(crew.call(&"item_count", _lock_item)) <= 0:
		return InteractableComponent.BLOCK_ITEM
	return InteractableComponent.BLOCK_NONE


func _c4_block(crew: Node) -> StringName:
	var c: CrewController = crew as CrewController
	if c != null and Safe.charge_source_for(c, 1, self) == &"":
		return InteractableComponent.BLOCK_ITEM
	return InteractableComponent.BLOCK_NONE


func _availability(crew: Node) -> StringName:
	var pick: Array = _pick(crew)
	if StringName(pick[0]) != &"" and _session == &"":
		_apply_ui(StringName(pick[0]))
	return StringName(pick[1])


func _duration_for(crew: Node, base: float) -> float:
	var m: StringName = _session if _session != &"" else StringName(_pick(crew)[0])
	match m:
		&"saw", &"drill":
			return Tweak.interaction().drill_place_s
		&"c4":
			return Tweak.interaction().c4_place_s
		&"fix":
			return Tweak.interaction().drill_fix_s
	return base


func _apply_ui(m: StringName) -> void:
	var ui: Array = METHOD_UI.get(m, [])
	if ui.size() != 2:
		return
	interactable.kind = ui[0]
	interactable.prompt_key = ui[1]
	interactable.speed_modifier_key = &"interaction.lockpick_speed_mult" if m == &"lockpick" else &""


func _on_completed(crew: Node) -> void:
	var m: StringName = _session if _session != &"" else StringName(_pick(crew)[0])
	_session = &""
	if not Net.is_authority() or opened:
		return
	var c: CrewController = crew as CrewController
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	match m:
		&"saw":
			placed_kind = &"saw"
			runner.place(slot, effective_saw_duration())
		&"drill":
			placed_kind = &"drill"
			runner.place(slot, effective_drill_duration())
		&"fix":
			runner.fix(slot)
		&"c4":
			if c != null and not Safe.consume_charges_for(c, 1, self):
				return
			_c4_by_net_id = NetIds.of(c) if c != null else 0
			timer_left = maxf(Tweak.interaction().c4_fuse_s, 0.01)
			interactable.enabled = false
			_emit_fact(&"device_started", [net_id, &"c4", timer_left])
			_cue(&"cue.c4_armed", global_position)
		&"lockpick":
			open_lock(false, &"lockpick")


## Server: the C4 fuse ran out: blow the lock (Safe._explode pattern).
func _explode() -> void:
	if opened:
		return
	var tw: InteractionTweak = Tweak.interaction()
	_emit_fact(&"device_finished", [net_id])
	_cue(&"cue.c4_explode", global_position)
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null:
		rt.make_noise(global_position, tw.c4_noise_radius_m, &"explosion", net_id)
	Explosion.apply(self, global_position, tw.c4_blast_radius_m, tw.c4_blast_damage, _c4_by_net_id, Safe.C4_ITEM)
	_c4_by_net_id = 0
	open_lock(true, &"c4")


func _loud() -> bool:
	var rt: HeistRuntime = HeistRuntime.of(self)
	return rt != null and (rt.phase == Enums.HeistPhase.LOUD or rt.went_loud)


# --- Placed device visual ---------------------------------------------------------------------

## While the device RUNS the padlock offers nothing (the HUD device row); jammed it offers "fix".
func _on_device_state(s: int) -> void:
	_visual.update(s, runner.kind, self, device_scene, SAW_OUT_M if runner.kind == &"saw" else DRILL_OUT_M)
	if opened:
		return
	match s:
		DeviceRunner.State.JAMMED:
			_apply_ui(&"fix")
			interactable.enabled = true
		DeviceRunner.State.RUNNING, DeviceRunner.State.DONE:
			interactable.enabled = false
		_:
			var p: Array = _pick(null)
			_apply_ui(StringName(p[0]))
