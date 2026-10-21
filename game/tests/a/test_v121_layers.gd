## Lead rulings (b) and (c) on characters.md v1.18 / v1.19: (b) a hit-zone flinch on a moving body plays on the upper
## body (FlinchLayer, spine and up) so the legs keep their locomotion; standing still it is the full-body one-shot.
## (c) the third-person left hand sits on the held rifle's LeftHandIK (ThirdPersonLeftHandIK): HandL/Socket within 2 cm
## of the marker. Real cast rig (rook); a sub-case whose clip the rig lacks is skipped with a print.
extends TestCase

const HEISTER: StringName = &"rook"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


func _bot(primary: StringName = &"") -> CrewController:
	var l: Loadout = null
	if primary != &"" and ContentDB.weapon(primary) != null:
		l = CrewWeapons.build_loadout(null).duplicate() as Loadout
		l.primary = primary
		l.primary_mods = [] as Array[StringName]
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(0, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, l)
	crew.heister = HEISTER
	crew.net_id = 88300
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(3)
	crew.masked = true
	crew.set_physics_process(false)  # no floor: keep the body where the test puts it
	return crew


func _missing(d: AnimDriver, clips: Array[StringName], what: String) -> bool:
	if d == null or d.player == null:
		print("[v121 layers] skip %s: no animated rig" % what)
		return true
	for c: StringName in clips:
		if not d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, c]):
			print("[v121 layers] skip %s: the rig has no %s" % [what, c])
			return true
	return false


func _hit(crew: CrewController, d: AnimDriver, zone: int, pos: Vector3) -> void:
	d._last_hit_react_t = -100.0
	EventBus.damage_applied.emit(crew.net_id, 0, Damage.info(10.0, Enums.DamageType.BULLET, zone, &"", pos,
		Vector3(0, 0, 1)))


func test_moving_flinch_is_upper_body_only() -> void:
	var crew: CrewController = await _bot()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"hit_head", &"hit_chest"], "flinch layer"):
		return
	assert_true(d.flinch_layer != null, "every animated body has the flinch layer")
	assert_false(UpperBodyLayer.filtered("thigh.L") or UpperBodyLayer.filtered("shin.R"), "legs not in the layer")
	d.set_process(false)
	crew.velocity = Vector3(0, 0, -1.6)
	for _i: int in 25:
		d.tick(0.05)
	var loco: StringName = d.clip
	assert_true(String(loco).begins_with("walk"), "walking (%s)" % loco)
	_hit(crew, d, Enums.HitZone.HEAD, Vector3(0, 1.65, 0))
	d.tick(0.05)
	assert_eq(d.clip, loco, "moving: the legs keep %s (no full-body flinch)" % loco)
	assert_eq(d.flinch_layer.clip, &"hit_head", "the flinch plays on the upper body")
	assert_true(d.flinch_layer.active and d.flinch_layer.influence > 0.0, "layer on (%.2f)" % d.flinch_layer.influence)
	d.tick(0.05)
	assert_near(d.flinch_layer.influence, AnimTweak.data().hit_zone_layer_head_weight, 0.001, "head weight 0.9")
	_hit(crew, d, Enums.HitZone.BODY, Vector3(0, 1.2, 0))
	_hit(crew, d, Enums.HitZone.BODY, Vector3(0, 1.2, 0))
	for _i: int in 3:
		d.tick(0.05)
	assert_eq(d.flinch_layer.clip, &"hit_chest", "a new hit restarts the layer with its clip")
	assert_near(d.flinch_layer.influence, AnimTweak.data().hit_zone_layer_weight, 0.001, "body weight 0.7")
	for _i: int in 20:
		d.tick(0.05)
	assert_near(d.flinch_layer.influence, 0.0, 0.001, "faded out after the clip")
	assert_false(d.flinch_layer.active, "layer off")
	crew.velocity = Vector3.ZERO
	for _i: int in 25:
		d.tick(0.05)
	_hit(crew, d, Enums.HitZone.HEAD, Vector3(0, 1.65, 0))
	d.tick(0.016)
	assert_eq(d.clip, &"hit_head", "standing still: the full-body one-shot")
	assert_false(d.flinch_layer.active, "and no layer")


func test_left_hand_on_the_rifle_marker() -> void:
	var crew: CrewController = await _bot(&"weapon.corsair_ar")
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"idle_alert_rifle"], "left-hand IK"):
		return
	if crew.weapons.has_weapon(Enums.WeaponSlot.PRIMARY):
		crew.weapons.equip(Enums.WeaponSlot.PRIMARY)
		await wait_frames(2)
		d.refresh_weapon()
	var wv: WeaponVisual = d.weapon_visual as WeaponVisual
	var marker: Node3D = wv.get_marker(&"LeftHandIK") if wv != null else null
	if d.aim_family() != &"rifle" or marker == null:
		print("[v121 layers] skip left-hand IK: no rifle with a LeftHandIK (%s)" % d.weapon_kind)
		return
	assert_true(d.left_hand_ik != null, "the rig has the left-hand IK")
	await wait_seconds(1.0)  # the driver runs (idle_alert_<kind>, IK blended in)
	assert_true(String(d.clip).begins_with("idle_alert_"), "holding at the low ready (%s)" % d.clip)
	assert_near(d.left_hand_ik.influence, 1.0, 0.001, "IK fully in")
	d.set_process(false)
	d.player.speed_scale = 0.0  # a still pose: the attachments and the marker settle on the solved skeleton
	await wait_frames(4)
	var grip: Node3D = d.rig.get_node("Skeleton3D/HandL/Socket") as Node3D
	var err: float = grip.global_position.distance_to(marker.global_position)
	print("[v121 layers] %s: HandL/Socket %.4f m from LeftHandIK (solver %.4f)" % [d.weapon_kind, err,
		d.left_hand_ik.last_error_m])
	assert_true(err < 0.02, "left hand within 2 cm of the marker (%.4f m)" % err)
	d.left_hand_ik.influence = 0.0
	await wait_frames(4)
	var off: float = grip.global_position.distance_to(marker.global_position)
	print("[v121 layers] without the IK: %.4f m" % off)
	d.tick(0.05)
	d._aim_hold_left = 0.0
	d.player.speed_scale = 1.0
	d._on_reload_started(Enums.WeaponSlot.PRIMARY, 2.0)
	for _i: int in 6:
		d.tick(0.05)
	assert_true(String(d.clip).begins_with("reload_"), "reloading (%s)" % d.clip)
	assert_near(d.left_hand_ik.influence, 0.0, 0.001, "the reload frees the left hand (IK out)")


## LEAD (D's OF Cataclysm loud anim coverage: 21k errors at anim_layers.gd:75): the IK kept the previous weapon's
## LeftHandIK marker, which is freed when the WeaponVisual is replaced (drop / swap). No error, and the IK fades out.
func test_left_hand_ik_survives_a_freed_marker() -> void:
	var crew: CrewController = await _bot(&"weapon.corsair_ar")
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"idle_alert_rifle"], "left-hand IK"):
		return
	if crew.weapons.has_weapon(Enums.WeaponSlot.PRIMARY):
		crew.weapons.equip(Enums.WeaponSlot.PRIMARY)
		await wait_frames(2)
		d.refresh_weapon()
	var wv: WeaponVisual = d.weapon_visual as WeaponVisual
	var marker: Node3D = wv.get_marker(&"LeftHandIK") if wv != null else null
	if d.aim_family() != &"rifle" or marker == null:
		print("[v121 layers] skip freed marker: no rifle with a LeftHandIK (%s)" % d.weapon_kind)
		return
	await wait_seconds(1.0)
	assert_true(d.left_hand_ik.marker == marker, "the IK holds the rifle's marker")
	d.set_process(false)
	marker.free()  # the WeaponVisual replaced under the IK (drop / swap)
	for _i: int in 20:
		d.tick(0.05)
	assert_true(d.left_hand_ik.influence < 1.0, "the IK fades out without its marker (%.2f)" % d.left_hand_ik.influence)
	assert_false(d.left_hand_ik.active and not is_instance_valid(d.left_hand_ik.marker), "never active on a freed marker")
