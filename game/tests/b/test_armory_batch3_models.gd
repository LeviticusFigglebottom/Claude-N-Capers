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


## B4-18 bow and crossbow strings: StringUpper/StringLower start on the cam axles above and below the nock;
## the crossbow `String` starts at the latch, at the bolt's nock (Magwell). The nocked projectile points -Z.
func test_bow_and_crossbow_strings() -> void:
	var b: WeaponVisual = _model_of(&"weapon.thorn_bow")
	var up: Node3D = b.model.find_child("StringUpper", true, false) as Node3D
	var low: Node3D = b.model.find_child("StringLower", true, false) as Node3D
	assert_true(up != null and low != null, "bow strings")
	var nock: Vector3 = _local(b, b.get_base_marker(&"Magwell"))
	if up != null and low != null:
		assert_true(_local(b, up).y > nock.y + 0.3 and _local(b, low).y < nock.y - 0.3, "cams above and below")
		assert_near(_local(b, up).z, nock.z, 0.04, "cam axle near the string line")
	assert_true(b.get_base_marker(&"Magwell").global_basis.y.normalized().dot(Vector3.FORWARD) > 0.99, "arrow forward")
	assert_true(_local(b, b.get_base_marker(&"LeftHandIK")).distance_to(Vector3(0.0, nock.y, nock.z)) < 0.02,
		"draw hand on the nock")
	b.queue_free()
	var x: WeaponVisual = _model_of(&"weapon.vise_crossbow")
	var s: Node3D = x.model.find_child("String", true, false) as Node3D
	assert_true(s != null, "crossbow String")
	if s != null:
		assert_true(_local(x, s).distance_to(_local(x, x.get_base_marker(&"Magwell"))) < 0.01, "latch at the nock")
	x.queue_free()


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
