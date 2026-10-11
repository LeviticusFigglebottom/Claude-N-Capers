## Safehouse station (QC-44, A3-11; docs/design/heists/safehouse.md "Stations"). Owner: ENV A.
## An instant press (interaction_time_s 0, casing + civilian allowed, silent) with prompt
## `ui.prompt.station.<station_id>`, aimed at the standard reach (InteractionTweak.reach_m). On use it emits
## `station_used(station_id, crew)` and `station_requested(station_id)`; ENV C's SafehouseMap relays it and
## B's MenuFlow opens the screen (QC-45). No heist facts are emitted: the hub has no HeistRuntime.
class_name HubStationPrefab
extends GameplayPrefab

signal station_used(station_id: StringName, crew: Node)
signal station_requested(station_id: StringName)

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/hub_station/hub_station_placeholder.tscn")
const KIND: StringName = &"hub_station"
const PROMPT_PREFIX: String = "ui.prompt.station."

## B's id from hub_stations.tres (board, planning, armory, masks, jukebox, notoriety, range, crew).
@export var station_id: StringName = &""

@export_group("Interaction")
@export var interaction_time_s: float = 0.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = true
@export var civilian_allowed: bool = true
@export var noise: StringName = &"silent"

var uses: int = 0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return 0.0


func _prefab_ready() -> void:
	interactable.kind = KIND
	interactable.prompt_key = prompt_key()
	interactable.completed.connect(_on_completed)


func prompt_key() -> StringName:
	return StringName(PROMPT_PREFIX + String(station_id)) if station_id != &"" else &""


func _on_completed(crew: Node) -> void:
	uses += 1
	station_used.emit(station_id, crew)
	station_requested.emit(station_id)
