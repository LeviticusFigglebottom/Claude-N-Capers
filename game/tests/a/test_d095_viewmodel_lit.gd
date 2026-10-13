## D-094 / D-095 (visual_slots v1.2): heist-map key lights near play spaces carry render layer 21
## (CrewView.VIEWMODEL_LIT_LAYER, 1 << 20) in addition to their world layer, so they light the first-person
## viewmodel. Layer 20 (1 << 19, the hidden FP body / levelcheck PROXY_LAYER) is never used on a light.
extends TestCase

## heist id -> minimum tagged lights (builder fixtures `Lighting/Fixtures/*/Light`, room fills
## `Lighting/Fill/*`, Dockside's yard masts `Props/Exterior/Mast*/Light`).
const MAPS: Dictionary = {
	&"glasshouse": 28,
	&"night_deposit": 37,
	&"shadow_ledger": 58,
	&"dockside_burn": 40,
}


func test_d095_layer_constants() -> void:
	assert_eq(CrewView.VIEWMODEL_LIT_LAYER, 1 << 20, "viewmodel_lit is layer 21")
	assert_eq(CrewView.VIEWMODEL_LIT_LAYER & CrewView.FIRST_PERSON_HIDDEN_LAYER, 0, "not the hidden-body layer")


func test_d095_map_lights_tagged() -> void:
	for id: StringName in MAPS:
		var ps: PackedScene = load("res://world/heists/%s/%s.tscn" % [id, id]) as PackedScene
		assert_true(ps != null, "%s loads" % id)
		if ps == null:
			continue
		var root: Node = ps.instantiate()
		var lights: Array[Light3D] = []
		_collect(root, lights)
		var tagged: int = 0
		var untagged_key: Array[String] = []
		var hidden_layer: Array[String] = []
		for l: Light3D in lights:
			var path: String = String(root.get_path_to(l))
			if (l.layers & (1 << 19)) != 0:
				hidden_layer.append(path)
			if not _is_key_light(path):
				continue
			if (l.layers & CrewView.VIEWMODEL_LIT_LAYER) != 0 and (l.layers & 1) != 0:
				tagged += 1
			else:
				untagged_key.append(path)
		assert_true(tagged >= int(MAPS[id]), "%s: %d key lights tagged (>= %d)" % [id, tagged, MAPS[id]])
		assert_true(untagged_key.is_empty(), "%s: key lights missing world+viewmodel_lit: %s" % [id, untagged_key])
		assert_true(hidden_layer.is_empty(), "%s: lights on layer 20 (1 << 19): %s" % [id, hidden_layer])
		root.free()


func _is_key_light(path: String) -> bool:
	if path.begins_with("Lighting/Fill/"):
		return true
	if not path.ends_with("/Light"):
		return false
	return path.begins_with("Lighting/Fixtures/") or path.begins_with("Props/Exterior/Mast")


func _collect(n: Node, out: Array[Light3D]) -> void:
	if n is Light3D:
		out.append(n as Light3D)
	for c: Node in n.get_children():
		_collect(c, out)
