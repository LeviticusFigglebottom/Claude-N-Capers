## Rolling Thunder safe contents (ENV A's RT mission runs: "PayStation / DinerOfficeSafe: content sits outside the safe
## body; moved to LootAnchor", Safe PO6-05). On the generated map, every loot prefab a Safe holds is authored (read
## before the map enters the tree) inside the safe's interior_aabb(), so the stow never has to move it. Owner: ENV C.
extends TestCase

const MAP: String = "res://world/heists/rolling_thunder/rolling_thunder.tscn"

var _map: Node = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
	_map = null
	await wait_frames(2)


func test_safe_contents_start_inside_the_body() -> void:
	_map = (load(MAP) as PackedScene).instantiate()
	# the authored positions (safe-local), read before _ready's stow can move them
	var authored: Dictionary = {}
	for s: Node in _map.find_children("*", "Safe", true, false):
		for p: Node in s.find_children("*", "GameplayPrefab", true, false):
			var t: Transform3D = (p as Node3D).transform
			var c: Node = p.get_parent()
			while c != s:
				t = (c as Node3D).transform * t
				c = c.get_parent()
			authored[s.get_path_to(p)] = t.origin
	add_child(_map)
	await wait_frames(1)
	var n: int = 0
	for s2: Node in _map.find_children("*", "Safe", true, false):
		var sf: Safe = s2 as Safe
		var interior: AABB = sf.interior_aabb()
		assert_true(interior.has_volume(), "%s has a Body interior" % sf.name)
		for p2: GameplayPrefab in sf.call(&"_inner_loot"):
			var at: Vector3 = authored.get(sf.get_path_to(p2), Vector3.INF)
			assert_true(interior.has_point(at), "%s: %s authored at %s, outside %s" % [sf.name, p2.name, at, interior])
			n += 1
	assert_true(n >= 4, "safe contents found (%d)" % n)
