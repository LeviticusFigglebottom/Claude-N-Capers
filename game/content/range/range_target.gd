## Firing-range target (B1-05, B4-13): a silhouette board on a stand with BODY and HEAD hit zones,
## HP from its RangeDummyDef (ENV A's EnemyDef when shipped) for the selected difficulty, optional
## armor (B4-13: frontal plate, Bulwark-style shield, Wrecker-style staged face plates) and an
## automatic reset after death. Owner: ENV B. Range-only: it is not an NPC and runs no AI.
##
## HIT API: docs/contracts/damage.md v1.0, the single hit path. On the server the attacker calls
##   `take_hit(info: Dictionary, attacker_net_id: int) -> Dictionary`
## exactly once per hit, with `info = Damage.info(...)`. `info.amount` is BODY damage (after falloff
## and attacker-side modifiers, before zone). The target applies its own rules through
## RangeDamageModel.apply() (zone mult x headshot_bonus, crit, frontal armor unless
## `info.pierced_armor`, plates on WEAKPOINT). Hits on the shield hitbox resolve to the RangeShield
## node (its get_damage_target), whose take_hit routes them here as shield hits (x shield_pierce_mult
## with `info.shield_pierce`, else blocked). Either way THIS node then emits
## `EventBus.damage_applied(net_id, attacker_net_id, final_info)` once (blocked hits too, amount 0,
## `blocked` true) and returns final_info with the final `amount`, `killed`, `health_after` and the
## model's extra keys. A downed target ignores hits and returns {}. It never listens to
## damage_applied and never emits npc_killed (range dummies are not NPCs).
## Pierce flags: `info.shield_pierce` / `info.pierced_armor` are attacker-side (A3-06). An info
## without a `shield_pierce` key comes from a runtime that does not send them yet; the target then
## uses `pierce_fallback` (the range shooter's resolved WeaponStats, set by FiringRange): its
## shield_pierce, and an armor_pierce roll on GameRng.stream(&"range.armor_pierce").
## Hitboxes (RangeHitbox, physics layer 5) implement get_damage_target() / get_hit_zone(), so
## `Damage.find_target(collider)` and `Damage.zone_of(collider)` resolve them.
##
## Group: G.RANGE_TARGET. Net id: allocated from Ids on the authority and registered with
## Ids.register(), so Ids.lookup(net_id) returns the target.
class_name RangeTarget
extends Node3D

signal damaged(target: RangeTarget, info: Dictionary, attacker_net_id: int)
signal died(target: RangeTarget)
signal reset_done(target: RangeTarget)

const PIERCE_STREAM: StringName = &"range.armor_pierce"
# Silhouette model (meters, origin = ground below the board centre, facing +Z = the shooting line).
const STAND_TOP: float = 0.85
const TORSO_SIZE: Vector3 = Vector3(0.46, 0.55, 0.03)
const SHOULDER_SIZE: Vector3 = Vector3(0.6, 0.16, 0.03)
const NECK_SIZE: Vector3 = Vector3(0.12, 0.08, 0.03)
const HEAD_RADIUS: float = 0.13
const BODY_BOX: Vector3 = Vector3(0.6, 0.67, 0.12)
const HEAD_BOX: Vector3 = Vector3(0.27, 0.28, 0.12)
# Armor pieces (board space). The face plate sits in front of the head box, the shield in front of
# everything (ground to above the head), the chest plate on the torso (visual; BODY zone is armored).
const FACEPLATE_BOX: Vector3 = Vector3(0.3, 0.3, 0.06)
const FACEPLATE_Z: float = 0.1
const SHIELD_BOX: Vector3 = Vector3(0.78, 1.8, 0.05)
const SHIELD_Z: float = 0.32
const CHEST_PLATE_SIZE: Vector3 = Vector3(0.42, 0.46, 0.03)

var net_id: int = 0
var lane: int = 0
var distance_m: float = 0.0
var dummy: RangeDummyDef = null
var difficulty: int = 0
var max_health: float = 1.0
var health: float = 1.0
var alive: bool = true
var tweak: RangeTweak = null
## The damage rules for `dummy` at `difficulty` (shared with the readout).
var model: RangeDamageModel = RangeDamageModel.new()
## Health + plate pools (RangeDamageModel state).
var state: Dictionary = {}
## Shooter's resolved stats for infos without attacker-side pierce flags (see header).
var pierce_fallback: WeaponStats = null
## The shield hit receiver (null without a shield).
var shield_node: RangeShield = null

var _respawn_left: float = -1.0
var _board: Node3D
var _hp_label: Label3D
var _hitboxes: Array[RangeHitbox] = []
var _faceplate_hb: RangeHitbox = null
var _faceplate_mesh: MeshInstance3D = null
var _fall_tween: Tween


## Call before adding to the tree.
func setup(def: RangeDummyDef, diff: int, range_tweak: RangeTweak, lane_index: int, dist_m: float) -> void:
	dummy = def
	tweak = range_tweak
	lane = lane_index
	distance_m = dist_m
	_set_model(diff)


func _ready() -> void:
	add_to_group(G.RANGE_TARGET)
	if state.is_empty():
		_set_model(difficulty)
	_build_visual()
	if Net.is_authority():
		net_id = Ids.next()
		Ids.register(net_id, self)
	_refresh_plates()
	_refresh_label()


func _process(delta: float) -> void:
	if _respawn_left < 0.0:
		return
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		reset_target()


## The dummy's headshot multiplier at the current difficulty (EnemyDef.headshot_mult).
func headshot_mult() -> float:
	return model.headshot_mult


## Multiplier a plain (unarmored, plate-free) hit zone receives (damage.md): HEAD takes the dummy's
## headshot multiplier x the attacker's `headshot_bonus`; every other zone takes x1.
func zone_mult(zone: int, headshot_bonus: float = 1.0) -> float:
	return RangeMath.zone_mult(zone, headshot_mult(), headshot_bonus)


## Plates still on (Wrecker-style dummies).
func plates_left() -> int:
	return model.plates_left(state)


## The single hit path (see header). Body damage in, final info out; emits damage_applied.
func take_hit(info: Dictionary, attacker_net_id: int) -> Dictionary:
	return _hit(info, attacker_net_id, false)


## RangeShield's entry: the same hit path for a hit that struck the shield first.
func take_shield_hit(info: Dictionary, attacker_net_id: int) -> Dictionary:
	return _hit(info, attacker_net_id, true)


func _hit(info: Dictionary, attacker_net_id: int, via_shield: bool) -> Dictionary:
	if not alive:
		return {}
	var hit: Dictionary = _with_pierce(info)
	var res: Dictionary = model.apply(state, hit, via_shield, is_frontal(hit))
	health = float(state["health"])
	var out: Dictionary = hit.duplicate()
	out.merge(res, true)
	out["via_shield"] = via_shield
	out["attacker_net_id"] = attacker_net_id
	if int(res["plate_stage"]) >= 0:
		_refresh_plates()
	_refresh_label()
	EventBus.damage_applied.emit(net_id, attacker_net_id, out)
	damaged.emit(self, out, attacker_net_id)
	if bool(out["killed"]):
		_die()
	return out


## A hit travelling against the dummy's facing (+Z) is frontal; no direction counts as frontal.
func is_frontal(info: Dictionary) -> bool:
	var dir: Vector3 = info.get("direction", Vector3.ZERO)
	if dir.length_squared() < RangeMath.EPS:
		return true
	var facing: Vector3 = global_transform.basis.z if is_inside_tree() else basis.z
	return dir.dot(facing) < 0.0


func _with_pierce(info: Dictionary) -> Dictionary:
	if info.has("shield_pierce") or pierce_fallback == null:
		return info
	var out: Dictionary = info.duplicate()
	out["shield_pierce"] = pierce_fallback.shield_pierce
	if not bool(out.get("pierced_armor", false)) and pierce_fallback.armor_pierce > 0.0:
		out["pierced_armor"] = GameRng.stream(PIERCE_STREAM).randf() < pierce_fallback.armor_pierce
	return out


## Full health, standing, at the current difficulty.
func set_difficulty(diff: int) -> void:
	_set_model(diff)
	reset_target()


func reset_target() -> void:
	_respawn_left = -1.0
	state = model.new_state()
	health = max_health
	alive = true
	for hb: RangeHitbox in _hitboxes:
		hb.set_active(true)
	_refresh_plates()
	_animate_fall(false)
	_refresh_label()
	reset_done.emit(self)


func hitboxes() -> Array[RangeHitbox]:
	return _hitboxes


## World position of the centre of a zone (tests, readout, aim helpers). WEAKPOINT = the face plate.
## The shield hitbox is never returned (it is in front of everything).
func zone_position(zone: Enums.HitZone) -> Vector3:
	for hb: RangeHitbox in _hitboxes:
		if hb.zone == zone and hb.part != RangeHitbox.PART_SHIELD:
			return hb.global_position
	return global_position


func _set_model(diff: int) -> void:
	difficulty = diff
	model = RangeDamageModel.from_def(dummy, diff)
	state = model.new_state()
	max_health = model.health
	health = max_health


func _die() -> void:
	alive = false
	for hb: RangeHitbox in _hitboxes:
		hb.set_active(false)
	_animate_fall(true)
	_respawn_left = dummy.respawn_delay_s if dummy != null else 1.0
	died.emit(self)


func _animate_fall(down: bool) -> void:
	if _board == null:
		return
	if _fall_tween != null and _fall_tween.is_valid():
		_fall_tween.kill()
	var angle: float = -deg_to_rad(tweak.target_fall_deg) if down else 0.0
	if not is_inside_tree():
		_board.rotation.x = angle
		return
	_fall_tween = create_tween()
	_fall_tween.tween_property(_board, ^"rotation:x", angle, tweak.target_fall_time_s)


## Face plate: shown and hittable while a plate remains (colour per stage), else the head is exposed.
func _refresh_plates() -> void:
	if _faceplate_hb == null:
		return
	var left: int = plates_left()
	_faceplate_hb.set_active(left > 0 and alive)
	_faceplate_mesh.visible = left > 0
	if left > 0 and not tweak.plate_colors.is_empty():
		var stage: int = int(state["stage"])
		var mat: StandardMaterial3D = _faceplate_mesh.material_override as StandardMaterial3D
		mat.albedo_color = tweak.plate_colors[clampi(stage, 0, tweak.plate_colors.size() - 1)]


func _refresh_label() -> void:
	if _hp_label == null:
		return
	var hp: Dictionary = {"hp": ceili(health), "max": ceili(max_health)}
	if plates_left() > 0:
		var plates: PackedFloat32Array = state["plates"]
		hp["plate"] = ceili(plates[int(state["stage"])])
		_hp_label.text = UiText.t(&"ui.range.target_hp_plate", hp)
	else:
		_hp_label.text = UiText.t(&"ui.range.target_hp", hp)


func _build_visual() -> void:
	var stand_mat: StandardMaterial3D = _mat(tweak.stand_color)
	var board_mat: StandardMaterial3D = _mat(tweak.board_color)
	var head_mat: StandardMaterial3D = _mat(tweak.head_color)
	add_child(_box(Vector3(0.5, 0.04, 0.3), Vector3(0.0, 0.02, 0.0), stand_mat))
	add_child(_box(Vector3(0.05, STAND_TOP, 0.05), Vector3(0.0, STAND_TOP * 0.5, -0.04), stand_mat))
	# The board hinges at the top of the stand and falls backwards (-Z) when killed.
	_board = Node3D.new()
	_board.name = "Board"
	_board.position = Vector3(0.0, STAND_TOP, 0.0)
	add_child(_board)
	var torso_c: Vector3 = Vector3(0.0, TORSO_SIZE.y * 0.5, 0.0)
	_board.add_child(_box(TORSO_SIZE, torso_c, board_mat))
	var shoulder_c: Vector3 = Vector3(0.0, TORSO_SIZE.y + SHOULDER_SIZE.y * 0.5 - 0.04, 0.0)
	_board.add_child(_box(SHOULDER_SIZE, shoulder_c, board_mat))
	var neck_c: Vector3 = Vector3(0.0, shoulder_c.y + SHOULDER_SIZE.y * 0.5 + NECK_SIZE.y * 0.5 - 0.02, 0.0)
	_board.add_child(_box(NECK_SIZE, neck_c, board_mat))
	var head_c: Vector3 = Vector3(0.0, neck_c.y + NECK_SIZE.y * 0.5 + HEAD_RADIUS - 0.02, 0.0)
	var head: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = HEAD_RADIUS
	disc.bottom_radius = HEAD_RADIUS
	disc.height = TORSO_SIZE.z
	disc.radial_segments = 20
	disc.material = head_mat
	head.mesh = disc
	head.position = head_c
	head.rotation.x = PI * 0.5
	_board.add_child(head)
	var body_hb: RangeHitbox = RangeHitbox.new()
	body_hb.name = "BodyHitbox"
	body_hb.setup(self, Enums.HitZone.BODY, BODY_BOX)
	body_hb.position = Vector3(0.0, BODY_BOX.y * 0.5, 0.0)
	_board.add_child(body_hb)
	var head_hb: RangeHitbox = RangeHitbox.new()
	head_hb.name = "HeadHitbox"
	head_hb.setup(self, Enums.HitZone.HEAD, HEAD_BOX)
	head_hb.position = head_c
	_board.add_child(head_hb)
	_hitboxes = [body_hb, head_hb]
	_build_armor(head_c)
	_hp_label = Label3D.new()
	_hp_label.name = "HpLabel"
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hp_label.font_size = tweak.hp_font_size
	_hp_label.pixel_size = tweak.label_pixel_size
	_hp_label.outline_size = 10
	_hp_label.position = Vector3(0.0, head_c.y + STAND_TOP + 0.3, 0.0)
	_hp_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_hp_label)


## Chest plate (visual), face plate (WEAKPOINT hitbox + mesh) and shield (RangeShield + hitbox).
func _build_armor(head_c: Vector3) -> void:
	if model.frontal_armor:
		var chest: MeshInstance3D = _box(CHEST_PLATE_SIZE,
				Vector3(0.0, TORSO_SIZE.y * 0.5 + 0.02, TORSO_SIZE.z * 0.5 + CHEST_PLATE_SIZE.z * 0.5), _mat(tweak.armor_color))
		chest.name = "ChestPlate"
		_board.add_child(chest)
	if not model.plate_health.is_empty():
		_faceplate_mesh = _box(FACEPLATE_BOX, Vector3(head_c.x, head_c.y, FACEPLATE_Z), null)
		_faceplate_mesh.name = "FacePlate"
		_faceplate_mesh.material_override = _mat(tweak.armor_color)
		_board.add_child(_faceplate_mesh)
		_faceplate_hb = RangeHitbox.new()
		_faceplate_hb.name = "FacePlateHitbox"
		_faceplate_hb.setup(self, Enums.HitZone.WEAKPOINT, FACEPLATE_BOX)
		_faceplate_hb.part = RangeHitbox.PART_PLATE
		_faceplate_hb.position = _faceplate_mesh.position
		_board.add_child(_faceplate_hb)
		_hitboxes.append(_faceplate_hb)
	if model.shield:
		shield_node = RangeShield.new()
		shield_node.name = "Shield"
		shield_node.owner_target = self
		# Bottom edge 0.1 m above the ground (board space starts at STAND_TOP).
		shield_node.position = Vector3(0.0, SHIELD_BOX.y * 0.5 - STAND_TOP + 0.1, SHIELD_Z)
		_board.add_child(shield_node)
		var mat: StandardMaterial3D = _mat(tweak.shield_color)
		if tweak.shield_color.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shield_node.add_child(_box(SHIELD_BOX, Vector3.ZERO, mat))
		var shb: RangeHitbox = RangeHitbox.new()
		shb.name = "ShieldHitbox"
		shb.setup(self, Enums.HitZone.BODY, SHIELD_BOX)
		shb.part = RangeHitbox.PART_SHIELD
		shb.receiver = shield_node
		shield_node.add_child(shb)
		_hitboxes.append(shb)


static func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


static func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	b.material = mat
	mi.mesh = b
	mi.position = pos
	return mi
