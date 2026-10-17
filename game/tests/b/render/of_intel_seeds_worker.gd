## Worker for of_intel_seeds.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const HEIST: StringName = &"ostrander_federal"
const SEEDS: int = 10
## Lines whose items the walk counts (the rest are flags, scalars or rare events).
const COUNTED: Array[StringName] = [&"guards", &"operator", &"cameras", &"alarm_buttons", &"keycards", &"keypads", &"lasers",
	&"vault_doors", &"safes", &"padlocks", &"hack_terminals"]

var _issues: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var def: HeistDef = HeistRegistry.get_def(HEIST)
	var data: BriefingIntelData = BriefingIntel.data_for(HEIST)
	var rooms: Array[Dictionary] = BriefingIntel.map_rooms(def.map_scene)
	for s: int in range(1, SEEDS + 1):
		var diff: int = (s - 1) % 6
		var lines: Dictionary = {}
		for l: Dictionary in BriefingIntel.lines(HEIST, diff, def.mode, data):
			lines[l["id"]] = l
		var rt: HeistRuntime = await HeistLauncher.launch(HEIST, s, diff, self, {"ai_teammates": 0})
		if rt == null:
			_issue("seed %d" % s, "launch failed")
			continue
		for _i: int in range(30):
			await get_tree().physics_frame
		var live: Dictionary = _live(rt, rooms)
		var parts: PackedStringArray = PackedStringArray()
		for id: StringName in COUNTED:
			if not lines.has(id):
				if int((live["count"] as Dictionary).get(id, 0)) > 0:
					_issue("seed %d d%d" % [s, diff], "%s: %d on the map, no briefing line" % [id, live["count"][id]])
				continue
			var l: Dictionary = lines[id]
			var n: int = int((live["count"] as Dictionary).get(id, 0))
			parts.append("%s %d [%d-%d]" % [id, n, int(l["min"]), int(l["max"])])
			if n < int(l["min"]) or n > int(l["max"]):
				_issue("seed %d d%d" % [s, diff], "%s: %d on the map, briefing says %d-%d (%s)" % [id, n, int(l["min"]),
					int(l["max"]), l["text"]])
			var named: Dictionary = l.get("rooms", {}) as Dictionary
			if l.get("base_key") != null:
				for rid: StringName in (live["rooms"] as Dictionary).get(id, []) as Array:
					if not named.has(rid):
						_issue("seed %d d%d" % [s, diff], "%s in room '%s', briefing names %s" % [id, rid, named.keys()])
		print("OFINTEL seed %d d%d %s | rolled %s" % [s, diff, ", ".join(parts), _rolled(rt.variants)])
		rt.teardown()
		await get_tree().process_frame
		await get_tree().process_frame
	print("OFINTEL DONE %d" % _issues)
	get_tree().quit(0)


## {"count": {line_id: n}, "rooms": {line_id: [room_id, ...]}} of the live map (guards: spawned at load).
func _live(rt: HeistRuntime, rooms: Array[Dictionary]) -> Dictionary:
	var by_cat: Dictionary = {}
	var cat_rooms: Dictionary = {}
	var cats_of: Dictionary = {}
	for n: Node in find_children("*", "Node3D", true, false):
		cats_of[n] = _categories(n as Node3D)
	for n: Node in cats_of:
		var n3: Node3D = n as Node3D
		var cats: Array[StringName] = cats_of[n]
		# As the scan: a reader / keypad that opens a keycard / code door is that door's lock (counted once).
		for pair: Array in [[&"keycard_reader", &"keycard_door"], [&"keypad", &"code_door"]]:
			if cats.has(pair[0]) and _targets_have(n3, cats_of, pair[1]):
				cats.erase(pair[0])
		for c: StringName in cats:
			by_cat[c] = int(by_cat.get(c, 0)) + 1
			if not cat_rooms.has(c):
				cat_rooms[c] = []
			(cat_rooms[c] as Array).append(BriefingIntel.room_at(rooms, n3.global_position))
	var guards: int = 0
	var operators: int = 0
	for npc: Node in rt.npcs():
		# The camera operator is a guard NPC on a staffed station (CameraStation's group); the briefing gives it its
		# own line.
		if npc.is_in_group(&"camera_operator"):
			operators += 1
		elif (npc as NpcBase).role == &"guard":
			guards += 1
	by_cat[&"guard"] = guards
	by_cat[&"operator"] = operators
	cat_rooms.erase(&"guard")
	cat_rooms.erase(&"operator")
	var count: Dictionary = {}
	var where: Dictionary = {}
	for id: StringName in COUNTED:
		for c: Variant in BriefingIntel.LINE_CATEGORIES.get(id, []) as Array:
			count[id] = int(count.get(id, 0)) + int(by_cat.get(c, 0))
			where[id] = (where.get(id, []) as Array) + (cat_rooms.get(c, []) as Array)
	return {"count": count, "rooms": where}


## BriefingIntel.categories_of on a live node: the prefab (scene file, else script) name, door locks, code safes.
func _categories(n: Node3D) -> Array[StringName]:
	var out: Array[StringName] = []
	var base: String = n.scene_file_path.get_file().get_basename()
	if base == "" and n.get_script() != null:
		base = (n.get_script() as Script).resource_path.get_file().get_basename()
	if BriefingIntel.PREFAB_CATEGORY.has(base):
		out.append(BriefingIntel.PREFAB_CATEGORY[base])
	if base == "door":
		match int(n.get(&"lock")):
			BriefingIntel.DOOR_KEYCARD:
				out.append(&"keycard_door")
			BriefingIntel.DOOR_CODE:
				out.append(&"code_door")
			BriefingIntel.DOOR_VAULT:
				out.append(&"vault_door")
	elif base == "safe" and (n.get(&"methods") as Array).has(&"code"):
		out.append(&"code_safe")
	return out


func _targets_have(n: Node3D, cats_of: Dictionary, category: StringName) -> bool:
	var targets: Variant = n.get(&"targets")
	if not targets is Array:
		return false
	for p: Variant in targets as Array:
		var t: Node = n.get_node_or_null(p as NodePath)
		if t != null and cats_of.has(t) and (cats_of[t] as Array).has(category):
			return true
	return false


func _rolled(v: Dictionary) -> String:
	var keep: PackedStringArray = PackedStringArray()
	for g: String in ["keycard", "code_pc", "server_room", "camera", "laser_pattern", "security_room_staffed",
			"guard_post", "guard_extra"]:
		keep.append("%s=%s" % [g, v.get(StringName(g), [])])
	return " ".join(keep)


func _issue(tag: String, what: String) -> void:
	_issues += 1
	print("QA ISSUE %s %s" % [tag, what])
