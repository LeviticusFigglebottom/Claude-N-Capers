## B4-18: animated parts of the batch-3 weapon models (visual_slots.md round 6, D-055): Slide, FeedCover,
## Breech, Lever, bow/crossbow strings, saw Blade, rotary Rotor and the flamethrower PilotLight. The marker,
## stock-part, length and budget checks for these models live in test_weapon_models.gd with the others.
extends TestCase


func before_all() -> void:
	ContentDB.clear_cache()


func _model_of(weapon_id: StringName) -> WeaponVisual:
	var v: WeaponVisual = WeaponVisual.new()
	add_child(v)
	v.setup_ids(weapon_id, [] as Array[StringName])
	return v


func _local(v: WeaponVisual, n: Node3D) -> Vector3:
	return v.model.global_transform.affine_inverse() * n.global_position


## B4-18 Wren slide and Gale feed cover follow the batch-2 rules (Slide carries SightRail; D-044 cover).
func test_batch3_slide_and_feed_cover() -> void:
	var w: WeaponVisual = _model_of(&"weapon.wren_380")
	var slide: Node3D = w.model.find_child("Slide", true, false) as Node3D
	assert_true(slide != null and slide.is_ancestor_of(w.get_base_marker(&"SightRail")), "Wren Slide carries the sight")
	w.queue_free()
	var v: WeaponVisual = _model_of(&"weapon.gale_mg")
	var cover: Node3D = v.model.find_child("FeedCover", true, false) as Node3D
	assert_true(cover != null and cover.rotation.is_zero_approx(), "Gale FeedCover closed at rotation 0")
	if cover != null:
		var sight: Node3D = v.get_marker(&"SightRail")
		assert_true(cover.is_ancestor_of(sight), "SightRail rides on the feed cover")
		var before: Vector3 = sight.global_position
		cover.rotation.x = deg_to_rad(78.0)
		assert_true(sight.global_position.y > before.y + 0.03, "opening lifts the rail")
	v.queue_free()


## B4-18 break actions: `Breech` (hinge pivot below the bore) carries the barrels, Muzzle, BarrelMount and the
## chamber Magwell (insertion axis = forward, -Z); a NEGATIVE rotation about local X drops the muzzle.
func test_breech_break_actions() -> void:
	for id: StringName in [&"weapon.reaper_db", &"weapon.thumper_40"]:
		var v: WeaponVisual = _model_of(id)
		var breech: Node3D = v.model.find_child("Breech", true, false) as Node3D
		assert_true(breech != null, "%s Breech" % id)
		if breech == null:
			v.queue_free()
			continue
		assert_true(breech.rotation.is_zero_approx(), "%s closed = rotation 0" % id)
		var muzzle: Node3D = v.get_base_marker(&"Muzzle")
		var magwell: Node3D = v.get_base_marker(&"Magwell")
		for m: StringName in [&"Muzzle", &"BarrelMount", &"Magwell"]:
			assert_true(breech.is_ancestor_of(v.get_base_marker(m)), "%s %s rides on the Breech" % [id, m])
		assert_true(magwell.global_basis.y.normalized().dot(Vector3.FORWARD) > 0.99, "%s rounds go in forward" % id)
		var hinge: Vector3 = _local(v, breech)
		assert_true(hinge.y < _local(v, muzzle).y - 0.02, "%s hinge below the bore" % id)
		var stock: Node3D = v.get_base_marker(&"StockMount")
		var s0: Vector3 = stock.global_position
		var m0: Vector3 = muzzle.global_position
		breech.rotation.x = deg_to_rad(-40.0)
		assert_true(muzzle.global_position.y < m0.y - 0.1, "%s opening drops the muzzle" % id)
		assert_true(stock.global_position.is_equal_approx(s0), "%s the stock stays put" % id)
		v.queue_free()


## B4-18 lever action: `Lever` pivots ahead of the grip; a positive rotation about local X swings the loop down.
func test_shrike_lever() -> void:
	var v: WeaponVisual = _model_of(&"weapon.shrike_44")
	var lever: MeshInstance3D = v.model.find_child("Lever", true, false) as MeshInstance3D
	assert_true(lever != null, "Lever mesh")
	if lever == null:
		v.queue_free()
		return
	assert_true(lever.rotation.is_zero_approx(), "closed = rotation 0")
	var p: Vector3 = _local(v, lever)
	assert_true(p.z < -0.05 and p.y > 0.0, "pivot at the receiver's front-bottom (%s)" % p)
	var box: AABB = lever.get_aabb()
	assert_true(box.end.z > 0.08, "the loop reaches back under the wrist: %s" % box)
	var loop: Vector3 = lever.global_transform * box.get_center()
	lever.rotation.x = deg_to_rad(50.0)
	assert_true((lever.global_transform * box.get_center()).y < loop.y - 0.02, "opening swings the loop down")
	assert_true(v.get_base_marker(&"Magwell").global_basis.y.normalized().dot(Vector3.UP) > 0.99, "tube port")
	v.queue_free()


## B4-18 bow and crossbow strings. Bow: StringUpper/StringLower start on the cam axles above and below the nock.
## Crossbow: the same pair rolled flat (Upper = left, Lower = right; local X = up), origins on the limb-tip axles,
## RELAXED at rest (the halves meet ahead of the latch). On both, a NEGATIVE turn of StringUpper and a POSITIVE turn
## of StringLower about local X pull the meeting point back; the crossbow's halves reach the latch (the bolt's
## nock, Magwell) with that swing plus a stretch along local Y. The nocked projectile points -Z.
func test_bow_and_crossbow_strings() -> void:
	var b: WeaponVisual = _model_of(&"weapon.thorn_bow")
	var up: Node3D = b.model.find_child("StringUpper", true, false) as Node3D
	var low: Node3D = b.model.find_child("StringLower", true, false) as Node3D
	assert_true(up != null and low != null, "bow strings")
	var nock: Vector3 = _local(b, b.get_base_marker(&"Magwell"))
	if up != null and low != null:
		assert_true(_local(b, up).y > nock.y + 0.3 and _local(b, low).y < nock.y - 0.3, "cams above and below")
		assert_near(_local(b, up).z, nock.z, 0.04, "cam axle near the string line")
		_assert_draw_pulls_back(b, up, low, "bow")
	assert_true(b.get_base_marker(&"Magwell").global_basis.y.normalized().dot(Vector3.FORWARD) > 0.99, "arrow forward")
	assert_true(_local(b, b.get_base_marker(&"LeftHandIK")).distance_to(Vector3(0.0, nock.y, nock.z)) < 0.02,
		"draw hand on the nock")
	b.queue_free()
	var x: WeaponVisual = _model_of(&"weapon.vise_crossbow")
	assert_true(x.model.find_child("String", true, false) == null, "crossbow: no single sliding String")
	var xu: Node3D = x.model.find_child("StringUpper", true, false) as Node3D
	var xl: Node3D = x.model.find_child("StringLower", true, false) as Node3D
	assert_true(xu != null and xl != null, "crossbow string halves")
	if xu != null and xl != null:
		_assert_crossbow_halves(x, xu, xl)
	x.queue_free()


## The end of a string half away from its pivot, in model space (Upper runs along local -Y, Lower along +Y). The
## half is the cord mesh itself (bow) or a Node3D carrying it (crossbow, `<half>Cord`).
func _half_end(v: WeaponVisual, half: Node3D, upper: bool) -> Vector3:
	var cord: MeshInstance3D = half as MeshInstance3D
	if cord == null:
		cord = half.get_node_or_null(NodePath(String(half.name) + "Cord")) as MeshInstance3D
	if cord == null:
		return half.global_position
	var box: AABB = cord.get_aabb()
	var tip: Vector3 = cord.global_transform * Vector3(0.0, box.position.y if upper else box.end.y, 0.0)
	return v.model.global_transform.affine_inverse() * tip


func _assert_draw_pulls_back(v: WeaponVisual, up: Node3D, low: Node3D, what: String) -> void:
	for pair: Array in [[up, true, -1.0], [low, false, 1.0]]:
		var half: Node3D = pair[0]
		var rest: Transform3D = half.transform
		var e0: Vector3 = _half_end(v, half, pair[1])
		half.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, float(pair[2]) * deg_to_rad(10.0)), rest.origin)
		assert_true(_half_end(v, half, pair[1]).z > e0.z + 0.01, "%s %s: the draw turn pulls the string back" % [what, half.name])
		half.transform = rest


func _assert_crossbow_halves(x: WeaponVisual, xu: Node3D, xl: Node3D) -> void:
	var latch: Vector3 = _local(x, x.get_base_marker(&"Magwell"))
	var pu: Vector3 = _local(x, xu)
	var pl: Vector3 = _local(x, xl)
	assert_true(pu.x < -0.25 and pl.x > 0.25, "pivots on the left / right limb tips (%s, %s)" % [pu, pl])
	assert_true(pu.z < latch.z - 0.25 and absf(pu.z - pl.z) < 0.001, "tips level, well ahead of the latch")
	for h: Node3D in [xu, xl]:
		assert_near(_local(x, h).y, latch.y, 0.002, "%s level with the nock" % h.name)
		assert_true(h.global_basis.x.normalized().dot(Vector3.UP) > 0.999, "%s local X = up" % h.name)
	var eu: Vector3 = _half_end(x, xu, true)
	assert_true(eu.distance_to(_half_end(x, xl, false)) < 0.002, "the halves meet")
	assert_near(eu.x, 0.0, 0.002, "relaxed meeting point on the centre plane")
	assert_near(latch.z - eu.z, 0.16, 0.002, "relaxed: the string sits 0.16 m ahead of the nock")
	_assert_draw_pulls_back(x, xu, xl, "crossbow")
	# latched: swing about local X and stretch along local Y until each half ends on the nock
	var flat: Vector3 = Vector3(1.0, 0.0, 1.0)
	var a: float = ((eu - pu) * flat).angle_to((latch - pu) * flat)
	var s: float = (latch - pu).length() / (eu - pu).length()
	assert_true(a > deg_to_rad(10.0) and a < deg_to_rad(30.0) and s > 1.1 and s < 1.5, "latch swing %f rad, stretch %f" % [a, s])
	for pair: Array in [[xu, true, -a], [xl, false, a]]:
		var half: Node3D = pair[0]
		var rest: Transform3D = half.transform
		half.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, pair[2]) * Basis.from_scale(Vector3(1.0, s, 1.0)),
			rest.origin)
		assert_true(_half_end(x, half, pair[1]).distance_to(latch) < 0.002, "%s latched on the nock" % half.name)
		half.transform = rest


## B4-18 saw, rotary gun and flamethrower parts.
func test_saw_rotor_and_pilot_light() -> void:
	var s: WeaponVisual = _model_of(&"weapon.rotor_saw")
	var blade: Node3D = s.model.find_child("Blade", true, false) as Node3D
	assert_true(blade != null and blade.is_ancestor_of(s.get_base_marker(&"Magwell")), "the fitted blade spins with Blade")
	if blade != null:
		var r: float = _local(s, blade).distance_to(_local(s, s.get_base_marker(&"Muzzle")))
		assert_true(r > 0.14 and r < 0.16, "Muzzle on the blade's front edge (%f)" % r)
		var m0: Vector3 = s.get_base_marker(&"Magwell").global_position
		blade.rotation.x = deg_to_rad(90.0)
		assert_true(s.get_base_marker(&"Magwell").global_position.is_equal_approx(m0), "spins about its axle")
	s.queue_free()
	var c: WeaponVisual = _model_of(&"weapon.cyclone_rotary")
	var rotor: Node3D = c.model.find_child("Rotor", true, false) as Node3D
	assert_true(rotor != null and rotor.is_ancestor_of(c.get_base_marker(&"BarrelMount")), "Rotor carries the cluster")
	if rotor != null:
		var muzzle: Vector3 = _local(c, c.get_base_marker(&"Muzzle"))
		var axis: Vector3 = _local(c, rotor)
		assert_true(absf(axis.x) < 0.0005 and absf(axis.y - muzzle.y) < 0.0005, "Rotor on the bore axis")
	c.queue_free()
	var f: WeaponVisual = _model_of(&"weapon.furnace_ft")
	var pilot: Node3D = f.model.find_child("PilotLight", true, false) as Node3D
	assert_true(pilot != null, "PilotLight")
	if pilot != null:
		var mesh: MeshInstance3D = pilot as MeshInstance3D
		var at: Vector3 = mesh.global_transform * mesh.get_aabb().get_center() if mesh != null else pilot.global_position
		assert_true(at.distance_to(f.get_base_marker(&"Muzzle").global_position) < 0.06, "pilot light at the nozzle")
	f.queue_free()


## D-058: the box/drum shotguns carry a separate `ChargingHandle` mesh on the receiver side (ENV A pulls it
## back on bolt_release).
func test_box_shotgun_charging_handles() -> void:
	for id: StringName in [&"weapon.harrow_12", &"weapon.brute_12"]:
		var v: WeaponVisual = _model_of(id)
		var ch: Node3D = v.model.find_child("ChargingHandle", true, false) as Node3D
		assert_true(ch != null, "%s ChargingHandle" % id)
		if ch != null:
			assert_true(ch is MeshInstance3D or ch.get_child_count() > 0, "%s handle has geometry" % id)
		v.queue_free()
