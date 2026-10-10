## Static firing-range target (B1-05): a silhouette board on a stand with BODY and HEAD hit zones,
## HP from RangeDummyTable for the selected difficulty, and an automatic reset after death.
## Owner: ENV B. Range-only: it is not an NPC and runs no AI.
##
## HIT API: docs/contracts/damage.md v1.0, the single hit path. On the server the attacker calls
##   `take_hit(info: Dictionary, attacker_net_id: int) -> Dictionary`
## exactly once per hit, with `info = Damage.info(...)`. `info.amount` is BODY damage (after falloff
## and attacker-side modifiers, before zone). The target applies its zone multiplier: for HEAD,
## `headshot_mult()` (the RangeDummyDef row for the difficulty, copying the EnemyDef it imitates)
## x `info.headshot_bonus` (weapon headshot bonus, default 1.0). Other zones take x1 (a range dummy
## has no weak points). It then emits `EventBus.damage_applied(net_id, attacker_net_id, final_info)`
## itself and returns final_info with the final `amount`, `killed` and `health_after`. A downed
## target ignores hits and returns {}. It never listens to damage_applied (that would apply hits
## twice) and never emits npc_killed (range dummies are not NPCs).
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

# Silhouette model (meters, origin = ground below the board centre, facing +Z = the shooting line).
const STAND_TOP: float = 0.85
const TORSO_SIZE: Vector3 = Vector3(0.46, 0.55, 0.03)
const SHOULDER_SIZE: Vector3 = Vector3(0.6, 0.16, 0.03)
const NECK_SIZE: Vector3 = Vector3(0.12, 0.08, 0.03)
const HEAD_RADIUS: float = 0.13
const BODY_BOX: Vector3 = Vector3(0.6, 0.67, 0.12)
const HEAD_BOX: Vector3 = Vector3(0.27, 0.28, 0.12)

var net_id: int = 0
var lane: int = 0
var distance_m: float = 0.0
var dummy: RangeDummyDef = null
var difficulty: int = 0
var max_health: float = 1.0
var health: float = 1.0
var alive: bool = true
var tweak: RangeTweak = null

var _respawn_left: float = -1.0
var _board: Node3D
var _hp_label: Label3D
var _hitboxes: Array[RangeHitbox] = []
var _fall_tween: Tween


## Call before adding to the tree.
func setup(def: RangeDummyDef, diff: int, range_tweak: RangeTweak, lane_index: int, dist_m: float) -> void:
	dummy = def
	tweak = range_tweak
	lane = lane_index
	distance_m = dist_m
	difficulty = diff
	max_health = dummy.health_for(diff) if dummy != null else 1.0
	health = max_health


func _ready() -> void:
	add_to_group(G.RANGE_TARGET)
	_build_visual()
	if Net.is_authority():
		net_id = Ids.next()
		Ids.register(net_id, self)
	_refresh_label()


func _process(delta: float) -> void:
	if _respawn_left < 0.0:
		return
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		reset_target()


## The dummy's headshot multiplier at the current difficulty (EnemyDef.headshot_mult analog).
func headshot_mult() -> float:
	return dummy.headshot_mult_for(difficulty) if dummy != null else 1.0


## Multiplier the target applies to a hit's body damage (damage.md): HEAD takes the dummy's
## headshot multiplier x the attacker's `headshot_bonus`; every other zone takes x1.
func zone_mult(zone: int, headshot_bonus: float = 1.0) -> float:
	return RangeMath.zone_mult(zone, headshot_mult(), headshot_bonus)


## The single hit path (see header). Body damage in, final info out; emits damage_applied.
func take_hit(info: Dictionary, attacker_net_id: int) -> Dictionary:
	if not alive:
		return {}
	var out: Dictionary = info.duplicate()
	var zone: int = int(info.get("zone", Enums.HitZone.BODY))
	var bonus: float = float(info.get("headshot_bonus", 1.0))
	var amount: float = maxf(float(info.get("amount", 0.0)), 0.0) * zone_mult(zone, bonus)
	if bool(info.get("crit", false)):
		amount *= headshot_mult()  # damage.md D-027: crit adds the HEAD mult on any zone (stacks on head)
	health = maxf(health - amount, 0.0)
	var killed: bool = health <= RangeMath.EPS
	out["amount"] = amount
	out["killed"] = killed
	out["health_after"] = health
	out["attacker_net_id"] = attacker_net_id
	_refresh_label()
	EventBus.damage_applied.emit(net_id, attacker_net_id, out)
	damaged.emit(self, out, attacker_net_id)
	if killed:
		_die()
	return out


## Full health, standing, at the current difficulty.
func set_difficulty(diff: int) -> void:
	difficulty = diff
	max_health = dummy.health_for(diff) if dummy != null else 1.0
	reset_target()


func reset_target() -> void:
	_respawn_left = -1.0
	health = max_health
	alive = true
	for hb: RangeHitbox in _hitboxes:
		hb.set_active(true)
	_animate_fall(false)
	_refresh_label()
	reset_done.emit(self)


func hitboxes() -> Array[RangeHitbox]:
	return _hitboxes


## World position of the centre of a zone (tests, readout, aim helpers).
func zone_position(zone: Enums.HitZone) -> Vector3:
	for hb: RangeHitbox in _hitboxes:
		if hb.zone == zone:
			return hb.global_position
	return global_position


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


func _refresh_label() -> void:
	if _hp_label == null:
		return
	_hp_label.text = UiText.t(&"ui.range.target_hp", {"hp": ceili(health), "max": ceili(max_health)})


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
	_hp_label = Label3D.new()
	_hp_label.name = "HpLabel"
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hp_label.font_size = tweak.hp_font_size
	_hp_label.pixel_size = tweak.label_pixel_size
	_hp_label.outline_size = 10
	_hp_label.position = Vector3(0.0, head_c.y + STAND_TOP + 0.3, 0.0)
	_hp_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_hp_label)


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
