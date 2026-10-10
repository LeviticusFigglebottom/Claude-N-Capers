## Table of firing-range dummy presets (B1-05). Owner: ENV B.
## Data: res://content/data/range/range_dummies.tres. See RangeDummyDef for the EnemyDef stopgap.
class_name RangeDummyTable
extends Resource

@export var dummies: Array[RangeDummyDef] = []


## Preset by id, or null (Log.error) when unknown.
func dummy(id: StringName) -> RangeDummyDef:
	for d: RangeDummyDef in dummies:
		if d.id == id:
			return d
	Log.error(&"range", "unknown range dummy '%s'" % id)
	return null
