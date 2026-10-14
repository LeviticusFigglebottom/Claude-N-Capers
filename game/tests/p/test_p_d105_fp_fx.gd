## D-105 / impact_fx.md §4 (ENV P): first-person weapon FX. Real input (PInputDriver) fires; the tracer path takes
## EventBus.shot_fx the way ENV A emits it (flags bit1 = this peer's first-person shooter).
## Windowed: xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game \
##   res://tests/framework/runner.tscn -- --dir=p --filter=d105
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(primary: StringName = &"") -> CrewController:
	var opts: Dictionary = {"map_packed": ATestMaps.basic(0, 0), "crew_ai": false}
	if primary != &"":
		var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
		l.primary = primary
		l.resolved_primary = LoadoutResolver.resolve_weapon(l.primary, l.primary_mods)
		opts["loadouts"] = {0: l}
	_rt = await HeistLauncher.launch(&"unit_map", 105, Enums.Difficulty.ROUTINE, self, opts)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	if primary != &"":
		await _inp.tap(&"slot_primary")
	await wait_seconds(2.0)
	return c


func _vm(c: CrewController) -> FpViewmodel:
	return FpViewmodel.of(CrewView.of(c).camera())


func test_shot_flashes_ejects_and_kicks() -> void:
	var c: CrewController = await _launch(&"weapon.bastion_br")
	var vm: FpViewmodel = _vm(c)
	assert_false(c.weapons.stats(c.weapons.equipped_slot).suppressed, "an unsuppressed rifle (suppressed: no burst)")
	assert_true(vm != null and vm.fx != null and vm.anim_set != &"", "animated viewmodel with FX")
	if vm == null or vm.fx == null:
		return
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var amp: float = float(tw.kick_back_m.get(vm.anim_set, 0.0))
	var shots0: int = c.weapons.shots_fired
	_inp.press(&"fire")
	var peak: float = 0.0
	var saw_flash: bool = false
	for _k: int in 12:
		await wait_physics_frames(1)
		peak = maxf(peak, vm.kick().x)
		var f: Node3D = vm.fx.get_node_or_null(^"MuzzleFlash") as Node3D
		saw_flash = saw_flash or (f != null and f.visible)
	_inp.release(&"fire")
	var shots: int = c.weapons.shots_fired - shots0
	assert_true(shots >= 1, "fired (%d)" % shots)
	assert_eq(vm.fx.flashes, shots, "a flash per shot")
	assert_true(saw_flash, "the burst showed")
	assert_eq(vm.fx.shells_ejected, shots, "a casing per shot")
	# Peaks at amp after 18 ms; a slow (llvmpipe) frame samples it later on the curve (>= 0.78 amp at 1/30 s).
	assert_true(peak > amp * 0.6 and peak < amp * 1.05 * shots, "kick back %.4f m (set %s %.4f, %d shots stack)" % [
		peak, vm.anim_set, amp, shots])
	assert_true(await wait_until(func() -> bool: return vm.kick() == Vector2.ZERO, 3.0), "kick settles (%s)" % vm.kick())
	var f2: Node3D = vm.fx.get_node_or_null(^"MuzzleFlash") as Node3D
	assert_true(f2 == null or not f2.visible, "burst gone")


func test_pump_shotgun_ejects_on_the_cycle() -> void:
	var c: CrewController = await _launch(&"weapon.mule_12")
	var vm: FpViewmodel = _vm(c)
	if vm == null or vm.fx == null:
		assert_true(false, "viewmodel")
		return
	assert_eq(vm.anim_set, &"shotgun", "pump set")
	await _inp.tap(&"fire")
	assert_eq(vm.fx.flashes, 1, "flash on the shot")
	assert_eq(vm.fx.shells_ejected, 0, "the shell waits for the pump")
	var ok: bool = await wait_until(func() -> bool: return vm.fx.shells_ejected == 1, 2.0)
	assert_true(ok, "the pump ejects the shell")


func test_tracer_cadence_and_filters() -> void:
	var c: CrewController = await _launch(&"weapon.bastion_br")
	var vm: FpViewmodel = _vm(c)
	if vm == null or vm.fx == null:
		assert_true(false, "viewmodel")
		return
	var every: int = int(FpViewmodelTweak.data().tracer_every.get(vm.weapon_class_key(), 2))
	var o: Vector3 = c.eye_position()
	var end: Vector3 = o + Vector3(0, 0, -30)
	var fp: int = FpViewmodelFx.FLAG_FIRST_PERSON
	EventBus.shot_fx.emit(o, end, Vector3.ZERO, &"", &"assault_rifle", c.net_id, 0)
	EventBus.shot_fx.emit(o, end, Vector3.ZERO, &"", &"assault_rifle", c.net_id + 999, fp)
	EventBus.shot_fx.emit(o, end, Vector3.ZERO, &"", &"assault_rifle", c.net_id, fp | FpViewmodelFx.FLAG_SUPPRESSED)
	assert_eq(vm.fx.tracers_drawn, 0, "third-person, other shooters and suppressed shots draw no FP tracer")
	for _k: int in every * 2:
		EventBus.shot_fx.emit(o, end, Vector3.ZERO, &"", &"assault_rifle", c.net_id, fp)
	assert_eq(vm.fx.tracers_drawn, 2, "1 in %d (%s)" % [every, vm.weapon_class_key()])
	var tracer: MeshInstance3D = null
	for n: Node in c.get_parent().get_children():
		if n.name.begins_with("FpTracer"):
			tracer = n as MeshInstance3D
	assert_true(tracer != null and tracer.layers == 1, "the streak lives in the world on layer 1")
	var from: Vector3 = vm.muzzle_world_apparent()
	assert_true(from != Vector3.INF, "apparent muzzle")
	var cam: Camera3D = CrewView.of(c).camera()
	var local: Vector3 = cam.global_transform.affine_inverse() * from
	assert_true(local.z < -0.05 and local.x > 0.0 and local.y < 0.0, "apparent muzzle ahead, right, low: %s" % local)
	await wait_seconds(0.3)
	assert_false(tracer.visible, "the streak is gone after %.0f m at %.0f m/s" % [30.0,
		FpViewmodelTweak.data().tracer_speed_mps])
