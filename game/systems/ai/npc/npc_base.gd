## Base for every NPC (guards, civilians, police, specials). Owner: ENV A.
## Composition: behaviour lives in child components/brains (ai/<role>/); this node holds the
## shared state every system reads: role, alert state, health, net_id. Server-authoritative.
## The node stays in the tree after death as the corpse (group G.BODY) until bagged.
class_name NpcBase
extends CharacterBody3D

signal alert_state_changed(old_state: int, new_state: int)
signal died(info: Dictionary)

## &"guard", &"civilian", &"police", &"special" (test_hooks.md npcs(role)).
@export var role: StringName = &"guard"
@export var enemy_def: EnemyDef
@export var visual_scene: PackedScene

var net_id: int = 0
var alert_state: Enums.AlertState = Enums.AlertState.CALM
var health: float = 1.0
var max_health: float = 1.0
var alive: bool = true
## Spawn info (SpawnPoint tags, idle_activity, patrol graph) for the brain.
var spawn_info: Dictionary = {}
var difficulty: int = Enums.Difficulty.ROUTINE

@onready var visual_root: Node3D = get_node_or_null("Visual") as Node3D


func _ready() -> void:
	add_to_group(G.NPC)
	if role == &"civilian":
		add_to_group(G.CIVILIAN)
	else:
		add_to_group(G.ENEMY)
	collision_layer = 1 << 3
	collision_mask = (1 << 0) | (1 << 1)
	if visual_scene != null and visual_root != null:
		for c: Node in visual_root.get_children():
			c.queue_free()
		visual_root.add_child(visual_scene.instantiate())


## Server: set up stats from EnemyDef for the run difficulty.
func setup_npc(p_difficulty: int, info: Dictionary = {}) -> void:
	difficulty = p_difficulty
	spawn_info = info
	if enemy_def != null and enemy_def.health.size() > 0:
		max_health = enemy_def.health[clampi(p_difficulty, 0, enemy_def.health.size() - 1)]
	health = max_health


func is_alive() -> bool:
	return alive


func set_alert_state(s: Enums.AlertState) -> void:
	if s == alert_state:
		return
	var old: int = alert_state
	alert_state = s
	alert_state_changed.emit(old, s)
	if Net.is_authority():
		EventBus.npc_alert_state_changed.emit(net_id, old, s)
		Net.replicate_event(&"npc_alert_state_changed", [net_id, old, s])


## Head position for aiming/hitboxes (characters.md: 1.78 m rig, eye ~1.65).
func head_position() -> Vector3:
	return global_position + Vector3(0.0, 1.62, 0.0)
