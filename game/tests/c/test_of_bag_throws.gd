## Ostrander Federal bag throws on the built map (OF-C1 G1 fix for ENV P's OF-P1 windowed pass, §7.4 / §7.7): real
## LootBag bodies (ENV A's loot_bag.tscn) released the way LootManager.drop_bag throws them (0.7 m ahead of the crew's
## feet, 1.3 m up, the D-102 flat-ground speed for the weight's distance, the elevation = look pitch + 25 deg clamped to
## -20..70), in the committed map's Geometry + Props + the hoist rig (as it is after the burn: the lid gone), stepped by
## the physics server until they rest. ENV P's pitches: -20 / 0 / +25 deg.
## 1. The terrace east parapet (§7.4): a HEAVY throw clears the 1.1 m guard at every pitch from the face and from ENV P's
##    stand (0.6 m off it) and rests in the E2 secure zone; a MEDIUM one lands on Tannery Street within 4 m of it.
## 2. The hole (§7.7): a bag thrown across the hole from its W / E edge, looking down, hits the far guard screen and rests
##    on the vault floor; a bag thrown north at the hoist car from the vault floor stops on the backstop inside the car.
## Owner: ENV C.
extends TestCase

const SCENE: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
const BAG: String = "res://systems/loot/loot_bag.tscn"
const TANNERY_ZONE: String = "Variants/Group_escape/Slot_esc_van_tannery/SecureTannery"
const HOIST: String = "Gameplay/Lifts/Hoist"
const PITCHES: Array[float] = [-20.0, 0.0, 25.0]
## The terrace east parapet's face (x 47.8) and the throw line (z 19, ENV P's stand).
const FACE_X: float = 47.8
const TERRACE_Y: float = 8.6
const THROW_Z: float = 19.0
## Crew centre off the face: against it (capsule radius 0.35), ENV P's stand (47.2) and 1.2 m. (Measured on this map,
## OF-C1: HEAVY clears from up to 1.4 m off the face at -20 deg and 1.6 m at 0 / +25 deg; from 2.0 m a 2 m throw lands
## at the face, whatever the guard.)
const GAPS: Array[float] = [0.35, 0.6, 1.2]
const BESIDE_M: float = 4.0
## VT (vault floor) x 14-34, z 13-25 at FFL -4.
const VT: Rect2 = Rect2(14.0, 13.0, 20.0, 12.0)

var _holder: Node3D = null
var _zone_xf: Transform3D = Transform3D.IDENTITY
var _zone_half: Vector3 = Vector3.ZERO
var _car_xf: Transform3D = Transform3D.IDENTITY
var _car_half: Vector3 = Vector3.ZERO


func after_all() -> void:
	if _holder != null and is_instance_valid(_holder):
		_holder.queue_free()
	_holder = null


## §7.4: HEAVY in the E2 zone at every pitch from the face and P's stand; MEDIUM on the street beside it.
func test_terrace_parapet_throws_reach_e2() -> void:
	if not await _ensure():
		return
	var runs: Array[Dictionary] = []
	for w: int in [Enums.LootWeight.MEDIUM, Enums.LootWeight.HEAVY]:
		for gap: float in GAPS:
			for pitch: float in PITCHES:
				var crew: Vector3 = Vector3(FACE_X - gap, TERRACE_Y, THROW_Z)
				runs.append({"w": w, "gap": gap, "pitch": pitch, "bag": _throw(w, crew, Vector3.RIGHT, pitch)})
	await _settle(runs)
	for r: Dictionary in runs:
		var p: Vector3 = r["rest"]
		var heavy: bool = int(r["w"]) == Enums.LootWeight.HEAVY
		var d: float = _zone_dist(p)
		var label: String = "%s %+.0f deg from %.2f m off the face -> %s (%.1f m from E2)" % [
			"HEAVY" if heavy else "MEDIUM", float(r["pitch"]), float(r["gap"]), p, d]
		print("  terrace throw: " + label)
		assert_true(p.y < 0.6 and p.x > FACE_X + 0.4, "cleared the parapet onto Tannery Street: " + label)
		if heavy:
			assert_true(d <= 0.0, "HEAVY rests inside the E2 secure zone: " + label)
		else:
			assert_true(d <= BESIDE_M, "MEDIUM rests within %.0f m of the E2 secure zone: %s" % [BESIDE_M, label])


## §7.7 (a): thrown across the hole from the W / E edge looking down (-89 deg: the elevation clamps at -20), MEDIUM and
## HEAVY, the bag hits the far guard screen and drops onto the vault floor.
func test_hole_throw_down_lands_in_vt() -> void:
	if not await _ensure():
		return
	var runs: Array[Dictionary] = []
	for w: int in [Enums.LootWeight.MEDIUM, Enums.LootWeight.HEAVY]:
		for side: float in [-1.0, 1.0]:
			for z: float in [14.0, 14.6]:
				var crew: Vector3 = Vector3(24.0 + side * 1.0, 0.0, z)
				runs.append({"w": w, "side": side, "bag": _throw(w, crew, Vector3(-side, 0.0, 0.0), -89.0)})
	await _settle(runs)
	for r: Dictionary in runs:
		var p: Vector3 = r["rest"]
		var label: String = "weight %d from the %s edge -> %s" % [int(r["w"]), "W" if float(r["side"]) < 0.0 else "E", p]
		print("  hole throw: " + label)
		assert_true(p.y < -3.5 and VT.has_point(Vector2(p.x, p.z)), "a bag thrown down the hole rests in VT: " + label)


## §7.7 (b): thrown north at the open hoist car from the vault floor (against its sill, and ENV P's stand 1.2 m south of
## the car's centre), the bag stops on the backstop and rests inside the car (its origin in car_size_m).
func test_hoist_car_holds_a_thrown_bag() -> void:
	if not await _ensure():
		return
	var runs: Array[Dictionary] = []
	var c: Vector3 = _car_xf.origin
	for w: int in [Enums.LootWeight.MEDIUM, Enums.LootWeight.HEAVY]:
		for back: float in [0.0, 0.4]:
			for pitch: float in [-45.0, 0.0]:
				var crew: Vector3 = Vector3(c.x, -4.0, 16.15 + back)
				runs.append({"w": w, "back": back, "pitch": pitch, "bag": _throw(w, crew, Vector3.FORWARD, pitch)})
	await _settle(runs)
	for r: Dictionary in runs:
		var p: Vector3 = r["rest"]
		var l: Vector3 = _car_xf.affine_inverse() * p
		var label: String = "weight %d %+.0f deg from z %.2f -> %s (car-local %s)" % [int(r["w"]), float(r["pitch"]),
			16.15 + float(r["back"]), p, l]
		print("  car throw: " + label)
		assert_true(absf(l.x) <= _car_half.x and absf(l.z) <= _car_half.z and l.y >= -0.15 and l.y <= 2.0 * _car_half.y,
			"the hoist car holds a bag thrown from the vault floor: " + label)


# --- Helpers ----------------------------------------------------------------------------------------------------------

## Geometry + Props + the hoist rig at their map transforms in the test's world (built once).
func _ensure() -> bool:
	if _holder != null:
		return true
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps == null:
		fail("ostrander_federal.tscn missing")
		return false
	var map: Node3D = ps.instantiate() as Node3D
	var zone: Node3D = map.get_node_or_null(TANNERY_ZONE) as Node3D
	var hoist: Node3D = map.get_node_or_null(HOIST) as Node3D
	var rig: Node3D = map.get_node_or_null(HOIST + "/Rig") as Node3D
	if zone == null or hoist == null or rig == null:
		map.free()
		fail("SecureTannery / Hoist / Hoist/Rig missing")
		return false
	_zone_xf = _map_xform(map, zone)
	_zone_half = (zone.get(&"zone_size_m") as Vector3) * 0.5
	_car_xf = _map_xform(map, hoist)
	_car_half = (hoist.get(&"car_size_m") as Vector3) * 0.5
	var rig_xf: Transform3D = _map_xform(map, rig)
	_holder = Node3D.new()
	_holder.name = "OfBagThrowTest"
	for nm: String in ["Geometry", "Props"]:
		var n: Node = map.get_node(nm)
		_disown(n, map)
		map.remove_child(n)
		_holder.add_child(n)
	_disown(rig, map)
	rig.get_parent().remove_child(rig)
	rig.transform = rig_xf
	rig.visible = true
	_holder.add_child(rig)
	map.free()
	add_child(_holder)
	await wait_physics_frames(3)
	return true


## A real LootBag of `w` thrown by a crew member standing at `feet` facing `dir` (horizontal) at look pitch `pitch_deg`.
func _throw(w: int, feet: Vector3, dir: Vector3, pitch_deg: float) -> LootBag:
	var lt: LootTweak = LootTweak.get_default()
	var bag: LootBag = (load(BAG) as PackedScene).instantiate() as LootBag
	bag.loot_id = &"loot.of_throw_test"
	bag.weight = w as Enums.LootWeight
	_holder.add_child(bag)
	var fwd: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var dists: PackedFloat32Array = Tweak.crew().bag_throw_distance_m
	var dist: float = dists[clampi(w, 0, dists.size() - 1)]
	var theta: float = deg_to_rad(lt.throw_elevation_deg)
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var h: float = lt.throw_release_height_m
	var t: float = sqrt(maxf(2.0 * (h + dist * tan(theta)) / g, 0.0001))
	var v: float = dist / (cos(theta) * t)
	var elev: float = clampf(deg_to_rad(pitch_deg + lt.throw_pitch_bias_deg), deg_to_rad(lt.throw_min_elev_deg),
		deg_to_rad(lt.throw_max_elev_deg))
	bag.rotation.y = atan2(-fwd.x, -fwd.z)   # the carrier's look yaw (-Z forward)
	bag.release(feet + fwd * lt.drop_forward_m + Vector3.UP * h, fwd * v * cos(elev) + Vector3.UP * v * sin(elev), true)
	return bag


## Steps physics until every run's bag rests (< 0.05 m/s for 0.3 s) or 8 s pass; stores "rest" and frees the bags.
func _settle(runs: Array[Dictionary]) -> void:
	var still: Dictionary = {}
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	while t < 8.0:
		await wait_physics_frames(1)
		t += dt
		var done: bool = true
		for i: int in runs.size():
			var b: LootBag = runs[i]["bag"]
			var s: float = float(still.get(i, 0.0))
			s = s + dt if b.linear_velocity.length() < 0.05 and t > 0.2 else 0.0
			still[i] = s
			done = done and s >= 0.3
		if done:
			break
	for r: Dictionary in runs:
		var b2: LootBag = r["bag"]
		r["rest"] = b2.global_position
		b2.queue_free()
	await wait_physics_frames(2)


## Horizontal distance from `p` to the E2 secure zone's footprint (0 = inside).
func _zone_dist(p: Vector3) -> float:
	var l: Vector3 = _zone_xf.affine_inverse() * p
	return Vector2(maxf(absf(l.x) - _zone_half.x, 0.0), maxf(absf(l.z) - _zone_half.z, 0.0)).length()


static func _disown(n: Node, map: Node) -> void:
	if n.owner == map:
		n.owner = null
	for c: Node in n.get_children():
		_disown(c, map)


static func _map_xform(map: Node, n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != map:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
