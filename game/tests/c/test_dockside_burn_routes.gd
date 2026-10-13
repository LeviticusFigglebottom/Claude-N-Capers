## Dockside Burn holdout approaches (D-070: every holdout has >= 2 non-`breach_only` police approaches;
## the P3 port found the holdouts hollow). Owner: ENV C. Design: docs/design/heists/dockside_burn.md
## §Holdouts. An approach is one of the holdout's designed entrances (chokepoints) that is NOT a
## `breach_only` ENTRY point and that police reach on the baked navmesh from a legal spawn (a POLICE
## SpawnPoint or a non-`breach_only` ENTRY point, QC-42) and that leads on to the holdout. The play-space
## police gates (tag `police_gate`, BARRED, opened by the mission when the police arrive) have their
## door NavLinks enabled, as in the loud phase; every other door keeps its baked state.
extends TestCase

const SCENE: String = "res://world/heists/dockside_burn/dockside_burn.tscn"
## Holdout -> [centroid, {entrance name: floor point on the approach side}] (dockside_burn.md §Holdouts).
const HOLDOUTS: Dictionary = {
	"H1": [Vector3(16.0, 3.6, 3.0), {
		"platform_stair_foot": Vector3(26.0, 0.0, 9.0), "st_stair_door": Vector3(1.5, 0.0, 6.8),
		"mc_west_fire_stair": Vector3(-0.8, 3.6, 7.0)}],
	"H2": [Vector3(30.0, 0.0, 28.0), {
		"sp_mouth": Vector3(33.5, 0.0, 22.0), "c2_south_door": Vector3(41.2, 0.0, 23.0),
		"an_quay_door": Vector3(46.0, 0.0, 33.4), "an_east_door": Vector3(49.4, 0.0, 28.0)}],
	"H3": [Vector3(18.0, 0.0, 37.0), {
		"quay_west": Vector3(4.0, 0.0, 37.0), "quay_east": Vector3(32.0, 0.0, 37.0),
		"pk_quay_door": Vector3(12.0, 0.0, 33.4)}],
	"H4": [Vector3(30.0, 0.0, -28.0), {
		"gate": Vector3(34.0, 0.0, -33.0), "yard_west": Vector3(8.0, 0.0, -23.8),
		"yard_east": Vector3(52.0, 0.0, -23.8)}],
}
const SNAP_M: float = 1.5
const BREACH_M: float = 2.0

var _map: Node3D = null
var _rid: RID = RID()


func before_all() -> void:
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps == null:
		return
	_map = ps.instantiate() as Node3D
	add_child(_map)
	for d: Node in _map.get_node("Gameplay/Doors").get_children():
		if d is Door and String(d.name).ends_with("Gate") and (d as Door).lock == Door.Lock.BARRED:
			for l: Node in d.find_children("*", "NavigationLink3D", true, false):
				(l as NavigationLink3D).enabled = true
	_rid = (_map.get_node("Navigation") as NavigationRegion3D).get_navigation_map()
	var probe: Vector3 = HOLDOUTS["H4"][0]
	for i: int in range(120):
		await wait_physics_frames(1)
		if NavigationServer3D.map_get_iteration_id(_rid) > 0 \
				and NavigationServer3D.map_get_closest_point(_rid, probe).distance_to(probe) <= SNAP_M:
			break


func after_all() -> void:
	if _map != null:
		_map.queue_free()


func _snap(p: Vector3) -> Vector3:
	var c: Vector3 = NavigationServer3D.map_get_closest_point(_rid, p)
	return c if c.distance_to(p) <= SNAP_M else Vector3.INF


func _reaches(a: Vector3, b: Vector3) -> bool:
	if a == Vector3.INF or b == Vector3.INF:
		return false
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_rid, a, b, true)
	return path.size() >= 2 and path[path.size() - 1].distance_to(b) < 0.75


func test_every_holdout_has_two_non_breach_approaches() -> void:
	if _map == null:
		fail("map missing")
		return
	var starts: Array[Vector3] = []
	var breach: Array[Vector3] = []
	for n: Node in _map.find_children("*", "SpawnPoint", true, false):
		if (n as SpawnPoint).kind == SpawnPoint.Kind.POLICE:
			starts.append(_snap((n as Node3D).global_position))
	for n2: Node in _map.get_node("Tactical").get_children():
		var tp: TacticalPoint = n2 as TacticalPoint
		if tp == null or tp.kind != TacticalPoint.Kind.ENTRY:
			continue
		if tp.tags.has(&"breach_only"):
			breach.append(tp.global_position)
		else:
			starts.append(_snap(tp.global_position))
	assert_true(starts.size() >= 6, "legal police starts (got %d)" % starts.size())
	for h: String in HOLDOUTS:
		var centre: Vector3 = _snap(HOLDOUTS[h][0])
		assert_true(centre != Vector3.INF, "%s centroid on the navmesh" % h)
		var ok: PackedStringArray = PackedStringArray()
		var ents: Dictionary = HOLDOUTS[h][1]
		for e: String in ents:
			var ep: Vector3 = ents[e]
			var is_breach: bool = false
			for bp: Vector3 in breach:
				if Vector2(bp.x - ep.x, bp.z - ep.z).length() < BREACH_M and absf(bp.y - ep.y) < 2.0:
					is_breach = true
			var sp: Vector3 = _snap(ep)
			if is_breach or not _reaches(sp, centre):
				continue
			for s: Vector3 in starts:
				if _reaches(s, sp):
					ok.append(e)
					break
		print("[C3] %s non-breach approaches: %s" % [h, ", ".join(ok)])
		assert_true(ok.size() >= 2, "D-070: %s has >= 2 non-breach_only police approaches (got %s)" % [h, ok])
