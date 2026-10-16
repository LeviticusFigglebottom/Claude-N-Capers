## D-115 hand props (characters.md v1.16): ENV D's `_props/hand_props.json` (prop -> scene, socket, clips) read once;
## AnimDriver calls sync() on every clip change so a clip's props sit at `<socket>/Socket` (identity child) while
## it plays and are freed on the next clip (death clips list no props). Owner: ENV A.
class_name HandProps
extends RefCounted

const INDEX_PATH: String = G.CHARACTERS_DIR + "_props/hand_props.json"
## Child name prefix of an attached prop under its Socket.
const NODE_PREFIX: String = "HandProp_"

## clip -> Array of {"prop": String, "scene": String, "socket": String}.
static var _by_clip: Dictionary = {}
static var _loaded: bool = false


## The props `clip` holds (empty for none). Reads the index on first use.
static func props_for(clip: StringName) -> Array:
	_load()
	return _by_clip.get(String(clip), [])


## Attach `clip`'s props under `rig`'s sockets and free any other attached prop. Returns the attached prop names.
static func sync(rig: Node3D, clip: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if rig == null:
		return out
	var want: Dictionary = {}
	for p: Dictionary in props_for(clip):
		want[NODE_PREFIX + String(p["prop"])] = p
	for socket_name: String in ["HandR", "HandL"]:
		var socket: Node3D = rig.get_node_or_null(NodePath("Skeleton3D/%s/Socket" % socket_name)) as Node3D
		if socket == null:
			continue
		for c: Node in socket.get_children():
			if c.name.begins_with(NODE_PREFIX) and not (want.has(String(c.name)) \
					and String(want[String(c.name)]["socket"]) == socket_name):
				socket.remove_child(c)
				c.queue_free()
	for node_name: String in want:
		var p: Dictionary = want[node_name]
		var socket: Node3D = rig.get_node_or_null(NodePath("Skeleton3D/%s/Socket" % p["socket"])) as Node3D
		if socket == null:
			continue
		if socket.get_node_or_null(NodePath(node_name)) == null:
			var ps: PackedScene = load(String(p["scene"])) as PackedScene \
				if ResourceLoader.exists(String(p["scene"])) else null
			if ps == null:
				continue
			var n: Node = ps.instantiate()
			n.name = node_name
			socket.add_child(n)
		out.append(String(p["prop"]))
	return out


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(INDEX_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not (data is Dictionary):
		Log.error(&"anim", "hand_props.json: not a dictionary")
		return
	for prop: String in data as Dictionary:
		var e: Variant = (data as Dictionary)[prop]
		if not (e is Dictionary):
			continue
		var d: Dictionary = e as Dictionary
		for clip: Variant in d.get("clips", []):
			var list: Array = _by_clip.get(String(clip), [])
			list.append({"prop": prop, "scene": String(d.get("scene", "")), "socket": String(d.get("socket", "HandR"))})
			_by_clip[String(clip)] = list
