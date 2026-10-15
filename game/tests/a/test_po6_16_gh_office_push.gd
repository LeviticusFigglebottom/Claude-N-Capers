## PO6-16 (D-114 §5, L1.1 / L1.4): Golden Hour (glasshouse) loud with the crew held in the U6 manager office (the
## PO playtest: cops idled outside / on its threshold). Logs the director's spawn count over time and every cop's
## mode / position relative to ManagerDoor (headless diagnostic), and asserts the assault force ends up INSIDE
## the office during SUSTAIN with nobody stalled on the way.
extends TestCase

const OFFICE_MIN: Vector3 = Vector3(7.0, 3.6, 6.0)
const OFFICE_MAX: Vector3 = Vector3(12.0, 7.0, 12.0)
const DOOR: Vector3 = Vector3(10.5, 4.2, 6.0)

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


static func _in_office(p: Vector3) -> bool:
	return p.x > OFFICE_MIN.x and p.x < OFFICE_MAX.x and p.z > OFFICE_MIN.z and p.z < OFFICE_MAX.z and p.y > OFFICE_MIN.y


func test_po6_16_gh_police_enter_manager_office() -> void:
	var tw: DirectorTweak = (load("res://systems/director/director_tweak.tres") as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 3.0
	tw.anticipation_s = 2.0
	tw.build_s = 15.0
	tw.sustain_by_stage_s = PackedFloat32Array([120.0, 120.0, 120.0])
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.HAZARDOUS, self,
		{"crew_ai": false, "director_tweak": tw, "captain": false})
	assert_true(_rt != null, "launched")
	await wait_physics_frames(5)
	var spots: Array[Vector3] = [Vector3(9.0, 4.25, 10.8), Vector3(10.0, 4.25, 10.8), Vector3(11.2, 4.25, 10.5), Vector3(8.0, 4.25, 10.5)]
	for s: int in _rt.crew_members().size():
		_rt.teleport_crew(s, Transform3D(Basis.IDENTITY, spots[s]))
		Modifiers.set_source(s, &"diag.immune", {&"defense.damage_taken_mult": 0.0})
	for c: CrewController in _rt.crew_members():
		c.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	Engine.time_scale = 4.0
	var t0: int = Engine.get_physics_frames()
	var first_in: float = -1.0
	var last_inside: int = 0
	var last_alive: int = 0
	for step: int in 16:
		await wait_physics_frames(int(5.0 * Engine.physics_ticks_per_second / Engine.time_scale))
		var t: float = float(Engine.get_physics_frames() - t0) * Engine.time_scale / float(Engine.physics_ticks_per_second)
		var units: Array[NpcBase] = dir.alive_units()
		var inside: int = 0
		var deep: int = 0
		for u: NpcBase in units:
			if _in_office(u.global_position):
				inside += 1
				if u.global_position.z > DOOR.z + 1.5:
					deep += 1
		last_inside = inside
		last_alive = units.size()
		if inside > 0 and first_in < 0.0:
			first_in = t
		print("[DIAG] t=%5.1f phase=%s alive=%d cap=%d spawned=%d assault_spawned=%d pool=%d inside=%d deep=%d" % [t,
			Enums.AssaultPhase.keys()[dir.assault_phase], units.size(), dir.police_budget(), dir.spawned_total,
			dir.assault_spawned, dir._force_pool(), inside, deep])
		if step % 4 == 3:
			for u: NpcBase in units:
				var b: PoliceBrain = u.get_node_or_null(^"Brain") as PoliceBrain
				var m: NpcMotor = u.get_node_or_null(^"Motor") as NpcMotor
				var p: Vector3 = u.global_position
				print("[DIAG]   %s pos=(%.1f,%.1f,%.1f) dDoor=%.1f mode=%s vis=%s cover=%s wait=%s blocked=%s tgt=%s mtr=%s arrived=%s" % [
					u.name, p.x, p.y, p.z, p.distance_to(DOOR), b.mode if b else &"-", b._target_visible if b else false,
					b.cover_point.name if b and b.cover_point else "-", m.waiting_door != null if m else false,
					m.blocked_door != null if m else false, (b.combat_target as Node).name if b and b.combat_target else "-",
					m.target if m else Vector3.ZERO, m.arrived if m else false])
				var ag: NavigationAgent3D = u.get_node_or_null(^"NavAgent") as NavigationAgent3D
				if ag != null and m != null and not m.arrived:
					var path: PackedVector3Array = ag.get_current_navigation_path()
					print("[DIAG]     nav finished=%s reachable=%s path=%d idx=%d next=%s final=%s vel=%s" % [
						ag.is_navigation_finished(), ag.is_target_reachable(), path.size(),
						ag.get_current_navigation_path_index(), ag.get_next_path_position(), ag.get_final_position(), u.velocity])
					var cols: Array[String] = []
					for ci: int in u.get_slide_collision_count():
						var col: KinematicCollision3D = u.get_slide_collision(ci)
						var o: Node = col.get_collider() as Node
						cols.append("%s n=%s" % [o.get_path() if o else "?", col.get_normal()])
					var near: Array[String] = []
					for n: Node in _rt.npcs():
						var o3: Node3D = n as Node3D
						if o3 != u and o3.global_position.distance_to(p) < 1.5:
							near.append("%s(%s)" % [o3.name, (n as NpcBase).alert_state])
					print("[DIAG]     wall=%s floor=%s stun=%s cols=%s near=%s yield=%s" % [u.is_on_wall(), u.is_on_floor(),
						u.is_stunned(), cols, near, m.yielding()])
	print("[DIAG] first cop inside office at t=%.1f" % first_in)
	await _shot("po6_16_gh_office_crew_view")
	assert_true(first_in >= 0.0 and first_in <= 30.0, "police inside the office within 30 s of the alarm (%.1f)" % first_in)
	assert_eq(dir.assault_phase, Enums.AssaultPhase.SUSTAIN, "still sustaining")
	assert_true(last_alive >= dir.police_budget() - 1, "force at its cap (%d / %d)" % [last_alive, dir.police_budget()])
	assert_true(last_inside >= last_alive - 1, "the force is inside the office, not outside it (%d of %d)" % [last_inside, last_alive])


## Windowed evidence only (headless: no-op): PO6_16_SHOTS=<dir> saves the crew 0 view (facing ManagerDoor).
func _shot(nm: String) -> void:
	var out: String = OS.get_environment("PO6_16_SHOTS")
	if out == "" or DisplayServer.get_name() == "headless":
		return
	Engine.time_scale = 1.0
	await wait_frames(10)
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = out.path_join(nm + ".png")
	print("[DIAG] screenshot %s: %s" % [path, error_string(img.save_png(path))])
