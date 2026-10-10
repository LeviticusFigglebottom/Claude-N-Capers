## Discovers heists by convention: res://world/heists/<id>/<id>_def.tres (contracts/heist_map.md §1).
## Owner: LEAD. Lets UI (ENV B) list heists without hard-coding paths into ENV C's folder (D-024).
class_name HeistRegistry
extends RefCounted

const ROOT: String = "res://world/heists"


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var d: DirAccess = DirAccess.open(ROOT)
	if d == null:
		return out
	for sub: String in d.get_directories():
		if ResourceLoader.exists(def_path(StringName(sub))):
			out.append(StringName(sub))
	out.sort()
	return out


static func def_path(heist_id: StringName) -> String:
	return "%s/%s/%s_def.tres" % [ROOT, heist_id, heist_id]


## Map scene: HeistDef.map_scene if set, else the convention res://world/heists/<id>/<id>.tscn (answers QA-1).
static func map_scene_path(heist_id: StringName) -> String:
	var d: HeistDef = get_def(heist_id)
	if d != null and d.map_scene != "":
		return d.map_scene
	return "%s/%s/%s.tscn" % [ROOT, heist_id, heist_id]


static func get_def(heist_id: StringName) -> HeistDef:
	var p: String = def_path(heist_id)
	if not ResourceLoader.exists(p):
		return null
	return load(p) as HeistDef


static func all() -> Array[HeistDef]:
	var out: Array[HeistDef] = []
	for id: StringName in ids():
		var h: HeistDef = get_def(id)
		if h != null:
			out.append(h)
	return out
