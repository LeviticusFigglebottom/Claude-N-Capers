## Thermite burn point (QC-38, D-064 Dockside Burn; L3.4 fire). Owner: ENV A.
## A crew member carrying a `requires_loot` bag (loot.thermite), or with one lying within burn_bag_radius_m
## (D-068), holds the interaction (InteractionTweak burn_place_s): the bag is consumed and the burn runs
## `duration_s` (burn_duration_s; no jams):
## device_started(net_id, &"thermite", duration). Then the telegraph: cue.burn_warning [R] and a
## burn_warning_s countdown (`stage` WARNING), then device_finished(net_id) (the mission drops the fire
## shutters on it) and the fire volume lights: crew inside take DamageType.FIRE (pierced_armor: ignores
## armour) burn_fire_dps every burn_fire_tick_s, and a NavigationObstacle3D keeps NPC / AI avoidance out.
## Works with only a visual and the volume: `FireVolume` (Node3D, box `fire_volume_size` centred on it;
## the prefab root when absent). Visual nodes (optional): `Fire` (shown while burning / lit).
## QC-81 (Rolling Thunder bullion truck, D-149.2): `target` (a Safe / ArmoredTruck, Door, ... as DrillPoint.target) is
## opened when the burn finishes (DrillPoint.open_target); `fire_volume_size` ZERO = no fire volume (no damage, no
## obstacle, not in the fire_volume group): the thermite only burns through the lock.
class_name BurnPoint
extends GameplayPrefab

enum Stage { IDLE, BURNING, WARNING, LIT }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/burn_point/burn_point_placeholder.tscn")
const KIND: StringName = &"thermite"
const GROUP: StringName = &"fire_volume"
## Fire light while burning (visual only).
const FIRE_LIGHT_ENERGY: float = 1.6
const FIRE_LIGHT_RANGE_M: float = 4.0
const FIRE_LIGHT_HEIGHT_M: float = 0.9

@export var requires_loot: StringName = &"loot.thermite"
## -1 = InteractionTweak.burn_duration_s.
@export var duration_s: float = -1.0
## ZERO = no fire volume (QC-81).
@export var fire_volume_size: Vector3 = Vector3(6.0, 3.0, 6.0)
## QC-81: opened when the burn finishes (empty = none; the mission reacts to device_finished).
@export var target: NodePath
@export_group("Interaction")
## -1 = InteractionTweak.burn_place_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var stage: Stage = Stage.IDLE
var progress: float = 0.0
var timer_left: float = -1.0

var _tick_left: float = 0.0
var _obstacle: NavigationObstacle3D = null


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().burn_place_s


func effective_duration() -> float:
	return duration_s if duration_s >= 0.0 else Tweak.interaction().burn_duration_s


func _prefab_ready() -> void:
	set_process(false)  # the fire light flickers only while burning
	interactable.kind = &"place_thermite"
	interactable.allowed_with_bag = true
	interactable.extra_check = func(crew: Node) -> StringName:
		if stage != Stage.IDLE:
			return InteractableComponent.BLOCK_STATE
		return InteractableComponent.BLOCK_NONE if thermite_for(crew) != null else InteractableComponent.BLOCK_ITEM
	interactable.completed.connect(_on_completed)
	_show_fire(false)


func _on_completed(crew: Node) -> void:
	var c: CrewController = crew as CrewController
	if not Net.is_authority() or c == null or stage != Stage.IDLE:
		return
	var bag: LootBag = thermite_for(c)
	if bag == null:
		return
	LootManager.consume_bag(bag)
	start_burn()


## The thermite bag `crew` would use: the one it carries, else the nearest loose one within burn_bag_radius_m.
func thermite_for(crew: Node) -> LootBag:
	return LootManager.tool_bag_for(crew, requires_loot, global_position, Tweak.interaction().burn_bag_radius_m)


## Server: start the burn now (also the mission's fallback without a bag).
func start_burn() -> void:
	if not Net.is_authority() or stage != Stage.IDLE:
		return
	stage = Stage.BURNING
	interactable.enabled = false
	timer_left = effective_duration()
	_show_fire(true)
	_emit_fact(&"device_started", [net_id, KIND, timer_left])


## QC-81: this burn point lights a fire volume when it finishes.
func has_fire() -> bool:
	return fire_volume_size != Vector3.ZERO


## True when `p` is inside the fire volume (AI avoidance; any stage). Never without a volume (QC-81).
func contains(p: Vector3) -> bool:
	if not has_fire():
		return false
	var vol: Node3D = get_node_or_null(^"FireVolume") as Node3D
	var center: Node3D = vol if vol != null else self
	var local: Vector3 = center.global_transform.affine_inverse() * p
	var h: Vector3 = fire_volume_size * 0.5
	return absf(local.x) <= h.x and absf(local.z) <= h.z and local.y >= -0.2 and local.y <= fire_volume_size.y


func is_lit() -> bool:
	return stage == Stage.LIT


func _physics_process(delta: float) -> void:
	if not Net.is_authority():
		return
	match stage:
		Stage.BURNING:
			timer_left -= delta
			progress = clampf(1.0 - timer_left / maxf(effective_duration(), 0.01), 0.0, 1.0)
			if timer_left <= 0.0:
				stage = Stage.WARNING
				timer_left = Tweak.interaction().burn_warning_s
				var p: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)
				EventBus.audio_cue_requested.emit(&"cue.burn_warning", p, net_id)
				Net.replicate_event(&"audio_cue_requested", [&"cue.burn_warning", p, net_id])
		Stage.WARNING:
			timer_left -= delta
			if timer_left <= 0.0:
				_light()
		Stage.LIT:
			_tick_fire(delta)


func _light() -> void:
	stage = Stage.LIT
	timer_left = -1.0
	progress = 1.0
	if has_fire():
		add_to_group(GROUP)
		_obstacle = NavigationObstacle3D.new()
		_obstacle.name = "FireObstacle"
		_obstacle.radius = maxf(fire_volume_size.x, fire_volume_size.z) * 0.5
		_obstacle.avoidance_enabled = true
		var vol: Node3D = get_node_or_null(^"FireVolume") as Node3D
		(vol if vol != null else self).add_child(_obstacle)
	else:
		_show_fire(false)  # QC-81: burnt through, nothing keeps burning
	_emit_fact(&"device_finished", [net_id])
	if not target.is_empty():
		DrillPoint.open_target(get_node_or_null(target), true)


func _tick_fire(delta: float) -> void:
	if not has_fire():
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	var tw: InteractionTweak = Tweak.interaction()
	_tick_left = tw.burn_fire_tick_s
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt == null:
		return
	for c: CrewController in rt.crew_members():
		if not contains(c.global_position + Vector3(0.0, 0.3, 0.0)):
			continue
		var info: Dictionary = Damage.info(tw.burn_fire_dps * tw.burn_fire_tick_s, Enums.DamageType.FIRE,
			Enums.HitZone.BODY, &"burn_point", c.global_position, Vector3.UP, net_id)
		info["pierced_armor"] = true  # L3.4 / D-064: fire ignores armour
		CombatSystem.deliver_hit(c, info, net_id)


func _show_fire(on: bool) -> void:
	var f: Node3D = visual_node("Fire") as Node3D
	if f != null:
		f.visible = on
	_fire_light(on)


## A warm flickering OmniLight while burning (ENV C's ask; visual only, deterministic flicker, no RNG).
func _fire_light(on: bool) -> void:
	var l: OmniLight3D = get_node_or_null(^"FireLight") as OmniLight3D
	if l == null and on:
		l = OmniLight3D.new()
		l.name = "FireLight"
		l.light_color = Color(1.0, 0.55, 0.2)
		l.omni_range = FIRE_LIGHT_RANGE_M
		l.shadow_enabled = false
		add_child(l)
		l.position = Vector3(0.0, FIRE_LIGHT_HEIGHT_M, 0.0)
	if l != null:
		l.visible = on
	set_process(on)


func _process(_delta: float) -> void:
	var l: OmniLight3D = get_node_or_null(^"FireLight") as OmniLight3D
	if l == null or not l.visible:
		set_process(false)
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	l.light_energy = FIRE_LIGHT_ENERGY * (1.0 + 0.18 * sin(t * 17.0) + 0.11 * sin(t * 31.0 + 1.3))


func _net_state() -> Dictionary:
	return {"stage": int(stage), "progress": progress, "timer_left": timer_left}


func _apply_net_state(d: Dictionary) -> void:
	if d.has("stage"):
		stage = int(d["stage"]) as Stage
		_show_fire(stage != Stage.IDLE and (stage != Stage.LIT or has_fire()))
	progress = float(d.get("progress", progress))
	timer_left = float(d.get("timer_left", timer_left))
