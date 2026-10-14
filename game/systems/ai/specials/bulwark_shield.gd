## Bulwark ballistic shield (A3-01b L4.5, A3-06 L3.4). Owner: ENV A. Root `Shield` of bulwark_shield.tscn
## (characters.md: separate scene with a `Collision` child). A separate static body on physics layer 2
## `world_dynamic`, so it blocks bullets (CombatTweak.hitscan_mask), crew and NPC movement (doorways),
## and also LOS of crew shots behind it (the server LOS check). NPC LOS ignores shields
## (CombatSystem.has_npc_los). It is carried as a child of its Bulwark and is reparented in place to
## the heist's dynamic root when the Bulwark dies: a dropped shield still blocks (L4.5).
## Hits (docs/contracts/damage.md v1.1: the shield is a hit target): BULLET without `info.shield_pierce`,
## MELEE and anything else are BLOCKED: damage_applied [R] with amount 0 and `blocked = true` (victim =
## the carrier's net id, 0 for a dropped shield) so hit markers can show the block. A shield-piercing
## BULLET (attacker side: WeaponStats.shield_pierce / weapon.shield_pierce -> info.shield_pierce)
## continues along its direction and hits whatever is behind at x `pierce_mult` (the carrier's
## EnemyDef.params.shield_pierce_mult, D-052; fallback CombatTweak.shield_pierce_damage_mult 0.25);
## FIRE passes at CombatTweak.shield_fire_damage_mult. The forwarded hit is the single take_hit of that
## target (it emits damage_applied; the shield itself takes no damage).
## Explosions go around shields (Explosion ignores this group for LOS, PD2 behaviour).
## Geometry (characters.md v1.6): when the carrier wears an ENV D character, BulwarkBrain swaps in that
## character's own shield (`<char>/<char>_shield.tscn`: `Collision` + `Visual`, origin = the grip, -Z =
## shield face) via use_scene(), carried at HeavySpecialTweak.bulwark_grip_offset; the capsule placeholder
## keeps this scene's box at bulwark_shield_offset.
## Grip (characters.md v1.2/v1.4): the BODY (collision, blocking, dropping) always stays at the carrier-local
## carry offset, so gameplay never depends on animation. Only the `Visual` follows `HandL/Socket` each
## physics frame (socket -Z = shield face) while the guard is up and the socket is in a shield-holding pose
## (in front of the carrier, facing forward: shield_idle / shield_walk / shield_bang); otherwise (other
## clips, bind pose, capsule placeholder, guard down, dropped) the Visual rests on the body.
class_name BulwarkShield
extends AnimatableBody3D

signal blocked(info: Dictionary)
## Every hit on the shield (server, before blocking / piercing): BulwarkBrain stagger (L4.5).
signal struck(info: Dictionary)

const GROUP: StringName = &"bulwark_shield"
const LAYER_WORLD_DYNAMIC: int = 1 << 1
## BoneAttachment3D marker whose `Socket` is the shield grip.
const GRIP_MARKER: String = "HandL"
## Seconds between socket lookups while the carrier has no animated visual (placeholder).
const GRIP_LOOKUP_S: float = 0.5
## A socket pose is a shield hold when its -Z is within this angle of the carrier's forward...
const GRIP_MAX_TILT_DEG: float = 40.0
## ...and it is at least this far in front of the carrier (carrier-local -Z, m).
const GRIP_MIN_FRONT_M: float = 0.15
## Forwarded hit info key: instance ids of the shields a shield-piercing round already passed (A3-08 fix).
const PIERCED_KEY: String = "pierced_shields"
## Most shields one round may pass (no ping-pong between stacked Bulwarks).
const MAX_PIERCES: int = 3

## The carrying Bulwark (null once dropped).
var carrier: NpcBase = null
var dropped: bool = false
var blocked_hits: int = 0
var pierced_hits: int = 0
## L4.5 stagger: guard dropped (no collision, lowered); hits pass to the Bulwark behind.
var guard_down: bool = false
## Damage factor of a shield-piercing round (set from the carrier's EnemyDef in attach_to(), kept when
## dropped). < 0 = CombatTweak.shield_pierce_damage_mult.
var pierce_mult: float = -1.0
## The carrier visual's HandL/Socket the shield visual follows (null = none found).
var grip_socket: Node3D = null
## Carrier-local position of the carried, guard-up body (set by attach_to()).
var carry_offset: Vector3 = Vector3.ZERO
## True once use_scene() swapped in a character's shield geometry (origin = grip).
var character_geometry: bool = false

var _grip_lookup_left: float = 0.0
var _visual: Node3D = null
var _visual_rest: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	add_to_group(GROUP)
	_bind_visual()
	collision_layer = LAYER_WORLD_DYNAMIC
	collision_mask = 0
	sync_to_physics = false


func _physics_process(delta: float) -> void:
	follow_grip(delta)


## Align the `Visual` to the carrier's grip socket (guard up, carried, shield-holding pose). Returns true
## when aligned; false = the Visual rests on the body. The body itself never moves here.
func follow_grip(delta: float = 0.0) -> bool:
	if dropped or guard_down or carrier == null or not is_instance_valid(carrier) or get_parent() != carrier \
			or not is_inside_tree():
		_rest_visual()
		return false
	if grip_socket == null or not is_instance_valid(grip_socket) or not grip_socket.is_inside_tree():
		grip_socket = null
		_grip_lookup_left -= delta
		if _grip_lookup_left > 0.0:
			_rest_visual()
			return false
		_grip_lookup_left = GRIP_LOOKUP_S
		grip_socket = AnimDriver.socket_of(carrier, GRIP_MARKER)
		if grip_socket == null or not grip_socket.is_inside_tree():
			grip_socket = null
			_rest_visual()
			return false
	var xf: Transform3D = grip_socket.global_transform.orthonormalized()
	if _visual == null or not is_holding_pose(carrier.global_transform.affine_inverse() * xf):
		_rest_visual()
		return false
	_visual.global_transform = xf
	return true


## A carrier-local socket transform is a shield hold: in front of the carrier, its -Z facing forward.
static func is_holding_pose(local_xf: Transform3D) -> bool:
	var face: Vector3 = -local_xf.basis.z.normalized()
	return local_xf.origin.z <= -GRIP_MIN_FRONT_M and face.dot(Vector3.FORWARD) >= cos(deg_to_rad(GRIP_MAX_TILT_DEG))


## Swap in a character's shield scene geometry (characters.md v1.6 `bulwark_<v>_shield.tscn`: its
## `Collision` and `Visual` replace this scene's). Call before attach_to(). False = kept as is.
func use_scene(ps: PackedScene) -> bool:
	var src: Node = ps.instantiate() if ps != null else null
	if src == null:
		return false
	var col: CollisionShape3D = src.get_node_or_null(^"Collision") as CollisionShape3D
	var vis: Node3D = src.get_node_or_null(^"Visual") as Node3D
	if col == null or col.shape == null or vis == null:
		src.free()
		return false
	for nm: String in ["Collision", "Visual"]:
		var old: Node = get_node_or_null(NodePath(nm))
		if old != null:
			remove_child(old)
			old.free()
	for n: Node in [col, vis]:
		src.remove_child(n)
		n.owner = null
		add_child(n)
	src.free()
	character_geometry = true
	_visual = null
	_bind_visual()
	return true


func _bind_visual() -> void:
	if _visual == null or not is_instance_valid(_visual):
		_visual = get_node_or_null(^"Visual") as Node3D
		if _visual != null:
			_visual_rest = _visual.transform


func _rest_visual() -> void:
	_bind_visual()
	if _visual != null and not _visual.transform.is_equal_approx(_visual_rest):
		_visual.transform = _visual_rest


## Server: attach to `npc` at `local_pos` (the shield never collides with its carrier).
func attach_to(npc: NpcBase, local_pos: Vector3) -> void:
	carrier = npc
	var a: Dictionary = NpcHitRules.armor_of(npc.enemy_def)
	if bool(a["shield"]) or (npc.enemy_def != null and npc.enemy_def.params.has("shield_pierce_mult")):
		pierce_mult = float(a["shield_pierce_mult"])
	if get_parent() != npc:
		if get_parent() != null:
			get_parent().remove_child(self)
		npc.add_child(self)
	carry_offset = local_pos
	position = local_pos
	rotation = Vector3.ZERO
	npc.add_collision_exception_with(self)
	grip_socket = null
	_grip_lookup_left = 0.0
	follow_grip()


## Server: raise (`up`) or drop the guard. Down = no collision (bullets and bodies pass), the shield is
## held lowered at `local_pos`, tilted forward.
func set_guard(up: bool, local_pos: Vector3) -> void:
	guard_down = not up
	collision_layer = LAYER_WORLD_DYNAMIC if up else 0
	if carrier != null and get_parent() == carrier:
		position = local_pos
		rotation = Vector3.ZERO if up else Vector3(-PI * 0.3, 0.0, 0.0)
	follow_grip()


## The Bulwark died: the shield stays where it is (reparented under `new_parent`, transform kept).
func drop(new_parent: Node) -> void:
	if dropped:
		return
	dropped = true
	_rest_visual()  # the dropped shield looks where it blocks
	var xf: Transform3D = global_transform
	if carrier != null and is_instance_valid(carrier):
		carrier.remove_collision_exception_with(self)
	carrier = null
	if new_parent != null and get_parent() != new_parent:
		var was_in_tree: bool = is_inside_tree()
		if get_parent() != null:
			get_parent().remove_child(self)
		new_parent.add_child(self)
		if was_in_tree:
			global_transform = xf


func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	var out: Dictionary = CombatSystem.ensure_info_v11(info.duplicate())
	out["amount"] = 0.0
	out["killed"] = false
	out["blocked_by_shield"] = true
	if not Net.is_authority():
		return out
	struck.emit(info)
	var tw: CombatTweak = CombatTweak.data()
	var mult: float = pass_mult(info)
	if mult <= 0.0:
		blocked_hits += 1
		out["blocked"] = true
		out["crit"] = false
		blocked.emit(info)
		var victim: int = victim_net_id()
		EventBus.damage_applied.emit(victim, attacker_net_id, out)
		Net.replicate_event(&"damage_applied", [victim, attacker_net_id, out])
		return out
	# A round passes each shield once and at most MAX_PIERCES shields (stacked Bulwarks must not ping-pong it).
	var passed: Array = _pierced_ids(info)
	if passed.size() >= MAX_PIERCES or passed.has(get_instance_id()):
		return out
	var behind: Dictionary = _trace_behind(info, tw)
	if behind.is_empty():
		return out
	pierced_hits += 1
	var fwd: Dictionary = info.duplicate()
	fwd["amount"] = float(info.get("amount", 0.0)) * mult
	fwd["zone"] = int(behind["zone"])
	fwd["position"] = behind["position"]
	fwd["shield_pierced"] = true
	fwd[PIERCED_KEY] = _pierced_ids(info) + [get_instance_id()]
	return CombatSystem.deliver_hit(behind["target"] as Object, fwd, attacker_net_id)


## Instance ids of the shields this round already passed (forwarded hit info), oldest first.
static func _pierced_ids(info: Dictionary) -> Array:
	var v: Variant = info.get(PIERCED_KEY, [])
	return (v as Array).duplicate() if v is Array else []


## damage_applied victim of a blocked hit: the carrier's net id, 0 for a dropped shield.
func victim_net_id() -> int:
	return carrier.net_id if carrier != null and is_instance_valid(carrier) else 0


## Damage factor of `info` through this shield: shield_pierce BULLET -> pierce_mult (CombatTweak
## fallback), FIRE -> shield_fire_damage_mult, else 0 (blocked).
func pass_mult(info: Dictionary) -> float:
	var tw: CombatTweak = CombatTweak.data()
	var type: int = int(info.get("type", Enums.DamageType.BULLET))
	if type == Enums.DamageType.FIRE:
		return tw.shield_fire_damage_mult
	if type == Enums.DamageType.BULLET and bool(info.get("shield_pierce", false)):
		return pierce_mult if pierce_mult >= 0.0 else tw.shield_pierce_damage_mult
	return 0.0


## What the round hits after passing this shield: {target, zone, position} or {}.
func _trace_behind(info: Dictionary, tw: CombatTweak) -> Dictionary:
	var dir: Vector3 = info.get("direction", Vector3.ZERO)
	var pos: Variant = info.get("position")
	if dir.length() < 0.001 or not pos is Vector3 or not is_inside_tree():
		return {}
	dir = dir.normalized()
	var from: Vector3 = (pos as Vector3) - dir * 0.05
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + dir * tw.shield_pierce_reach_m, tw.hitscan_mask)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var ex: Array[RID] = [get_rid()]
	for id: Variant in _pierced_ids(info):
		var sh: CollisionObject3D = instance_from_id(int(id)) as CollisionObject3D
		if sh != null:
			ex.append(sh.get_rid())
	q.exclude = ex
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var col: Object = hit.get("collider")
	var target: Object = CombatSystem.resolve_collider(col)
	if target == null or target == self:
		return {}
	return {"target": target, "zone": Damage.zone_of(col), "position": hit.get("position", from)}
