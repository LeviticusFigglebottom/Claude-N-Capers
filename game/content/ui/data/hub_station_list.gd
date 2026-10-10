## Ordered safehouse station list (B4-07). Owner: ENV B. Data: res://content/data/ui/hub_stations.tres.
class_name HubStationList
extends Resource

const DEFAULT_PATH: String = "res://content/data/ui/hub_stations.tres"

## Display order of the 2D hub (and the documented station ids for ENV C's 3D hub).
@export var stations: Array[HubStation] = []


static func load_default() -> HubStationList:
	return load(DEFAULT_PATH) as HubStationList


## The station with `id`, or null.
func find(id: StringName) -> HubStation:
	for s: HubStation in stations:
		if s != null and s.id == id:
			return s
	return null


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: HubStation in stations:
		if s != null:
			out.append(s.id)
	return out
