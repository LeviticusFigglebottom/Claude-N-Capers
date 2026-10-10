## One safehouse station (pd2_fidelity C9, B4-07). Owner: ENV B. Data: res://content/data/ui/hub_stations.tres.
## The 2D hub (HubMenu) lists these; ENV C's 3D safehouse interactables open the same stations
## through MenuFlow.open_station(id). Text is strings.csv `title_key` / `desc_key`.
class_name HubStation
extends Resource

## Station id passed to MenuFlow.open_station (e.g. &"board").
@export var id: StringName = &""
@export var title_key: StringName = &""
@export var desc_key: StringName = &""
## Glyph HubStationIcon draws: &"board", &"planning", &"armory", &"masks", &"range", &"crew" (unknown = a plain dot).
@export var icon_kind: StringName = &""
## What MenuFlow opens (MenuFlow.TARGETS): &"board", &"heist_select", &"loadout", &"masks", &"firing_range", &"lobby".
@export var target: StringName = &""
