## Thermite burn point (QC-38, D-064 Dockside Burn; L3.4 fire). Owner: ENV A.
## A crew member carrying a `requires_loot` bag (loot.thermite) holds the interaction (InteractionTweak
## burn_place_s): the bag is consumed and the burn runs `duration_s` (burn_duration_s; no jams):
## device_started(net_id, &"thermite", duration). Then the telegraph: cue.burn_warning [R] and a
## burn_warning_s countdown (`stage` WARNING), then device_finished(net_id) (the mission drops the fire
## shutters on it) and the fire volume lights: crew inside take DamageType.FIRE (pierced_armor: ignores
## armour) burn_fire_dps every burn_fire_tick_s, and a NavigationObstacle3D keeps NPC / AI avoidance out.
## Works with only a visual and the volume: `FireVolume` (Node3D, box `fire_volume_size` centred on it;
## the prefab root when absent). Visual nodes (optional): `Fire` (shown while burning / lit).
class_name BurnPoint
extends GameplayPrefab

enum Stage { IDLE, BURNING, WARNING, LIT }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/burn_point/burn_point_placeholder.tscn")
const KIND: StringName = &"thermite"
const GROUP: StringName = &"fire_volume"

@export var requires_loot: StringName = &"loot.thermite"
## -1 = InteractionTweak.burn_duration_s.
@export var duration_s: float = -1.0
@export var fire_volume_size: Vector3 = Vector3(6.0, 3.0, 6.0)
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
	interactable.kind = &"place_thermite"
	interactable.allowed_with_bag = true
	interactable.extra_check = func(crew: Node) -> StringName:
		if stage != Stage.IDLE:
			return InteractableComponent.BLOCK_STATE
		var bag: LootBag = crew.get(&"carried_bag") as LootBag if crew != null else null
		return InteractableComponent.BLOCK_NONE if bag != null and bag.loot_id == requires_loot \
			else InteractableComponent.BLOCK_ITEM
	interactable.completed.connect(_on_completed)
	_show_fire(false)


func _on_completed(crew: Node) -> void:
	var c: CrewController = crew as CrewController
	if not Net.is_authority() or c == null or stage != Stage.IDLE:
		return
	var bag: LootBag = c.carried_bag as LootBag
	if bag == null or bag.loot_id != requires_loot:
		return
	c.set_carried_bag(null)
	if bag.get_parent() != null:
		bag.get_parent().remove_child(bag)
	bag.queue_free()
	start_burn()


## Server: start the burn now (also the mission's fallback without a bag).
func start_burn() -> void:
	if not Net.is_authority() or stage != Stage.IDLE:
		return
	stage = Stage.BURNING
	interactable.enabled = false
	timer_left = effective_duration()
	_show_fire(true)
	_emit_fact(&"device_started", [net_id, KIND, timer_left])


## True when `p` is inside the fire volume (AI avoidance; any stage).
func contains(p: Vector3) -> bool:
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
	add_to_group(GROUP)
	_obstacle = NavigationObstacle3D.new()
	_obstacle.name = "FireObstacle"
	_obstacle.radius = maxf(fire_volume_size.x, fire_volume_size.z) * 0.5
	_obstacle.avoidance_enabled = true
	var vol: Node3D = get_node_or_null(^"FireVolume") as Node3D
	(vol if vol != null else self).add_child(_obstacle)
	_emit_fact(&"device_finished", [net_id])


func _tick_fire(delta: float) -> void:
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


func _net_state() -> Dictionary:
	return {"stage": int(stage), "progress": progress, "timer_left": timer_left}


func _apply_net_state(d: Dictionary) -> void:
	if d.has("stage"):
		stage = int(d["stage"]) as Stage
		_show_fire(stage != Stage.IDLE)
	progress = float(d.get("progress", progress))
	timer_left = float(d.get("timer_left", timer_left))
