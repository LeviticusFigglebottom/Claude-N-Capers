## Wrecker staged weak points (A3-01b, L4.6; damage.md WEAKPOINT). Owner: ENV A. Server-authoritative.
## Child `Weakpoints` of npc_wrecker.tscn. Builds two Hitbox areas (zone WEAKPOINT, layer 5) in front of
## the head: `Faceplate` (outermost) and `Visor` (behind it); the head sphere is behind both. Every
## WEAKPOINT hit is routed here (Hitbox.target = this node) and damages the CURRENT stage only, so the
## plates always break in order: Faceplate -> Visor -> head exposed, HP from EnemyDef.params.plate_health
## [faceplate, visor] = [150, 160] (D-052; legacy faceplate_hp / visor_hp still read). Same HP on every
## difficulty (PD2). Plate hits never hurt the Wrecker's health. damage.md v1.1: a plate takes the
## body amount x1 (no zone multiplier, no headshot bonus, no crit: `crit` is cleared); damage beyond the
## plate's remaining HP is lost (never carried to the next plate or the head); the reported `amount`
## is what the plate actually lost. Explosions do not hit plates.
## While a plate stands `is_head_armored()` is true and NpcHitRules turns HEAD hits into x1 hits;
## afterwards the EnemyDef headshot multiplier applies.
## Each break: cue.wrecker_plate_crack [R] at the head, the plate's hitbox is disabled, and the
## characters.md MeshInstance3D of the same name (`Faceplate` / `Visor`, plus `HeadArmored` with the
## visor) is hidden on every peer. Plate hits emit damage_applied (zone WEAKPOINT) for hit markers
## with `plate`, `plate_hp_left` and `plate_broken`.
class_name WreckerArmor
extends Node

signal plate_broken(plate: StringName, stage: int)

const STAGES: Array[StringName] = [&"Faceplate", &"Visor"]
const HP_DEFAULT: Array[float] = [150.0, 160.0]
## Extra mesh hidden with each stage (characters.md `HeadArmored` variants).
const EXTRA_HIDE: Dictionary = {&"Visor": [&"HeadArmored"]}

## 0 = faceplate up, 1 = visor up, 2 = head exposed.
var stage: int = 0
var plate_hp: Array[float] = []
var hitboxes: Array[Hitbox] = []

var _npc: NpcBase = null


func _ready() -> void:
	_npc = get_parent() as NpcBase
	if _npc == null:
		Log.error(&"ai", "WreckerArmor must be a child of an NpcBase")
		return
	_build.call_deferred()  # NpcBase builds `Hitboxes` in its own _ready (after ours)


func is_head_armored() -> bool:
	return stage < STAGES.size()


func current_plate() -> StringName:
	return STAGES[stage] if stage < STAGES.size() else &""


func hp_left() -> float:
	return plate_hp[stage] if stage < plate_hp.size() else 0.0


## Hit on a WEAKPOINT hitbox (docs/contracts/damage.md single hit path: this node is the target).
func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	var out: Dictionary = CombatSystem.ensure_info_v11(info.duplicate())
	out["amount"] = 0.0
	out["killed"] = false
	out["crit"] = false
	if not Net.is_authority() or _npc == null or not _npc.alive:
		return out
	if not is_head_armored():
		var head: Dictionary = info.duplicate()  # a stray weak-point hit after both plates: the head
		head["zone"] = Enums.HitZone.HEAD
		return _npc.take_hit(head, attacker_net_id)
	var amount: float = maxf(float(info.get("amount", 0.0)), 0.0)
	if int(info.get("type", Enums.DamageType.BULLET)) == Enums.DamageType.EXPLOSION:
		amount = 0.0  # blasts hit the body, not the plates
	var plate: StringName = current_plate()
	amount = minf(amount, maxf(plate_hp[stage], 0.0))  # excess is lost
	plate_hp[stage] -= amount
	out["amount"] = amount
	out["zone"] = Enums.HitZone.WEAKPOINT
	out["plate"] = plate
	out["plate_hp_left"] = maxf(plate_hp[stage], 0.0)
	out["plate_broken"] = plate_hp[stage] <= 0.0
	EventBus.damage_applied.emit(_npc.net_id, attacker_net_id, out)
	Net.replicate_event(&"damage_applied", [_npc.net_id, attacker_net_id, out])
	if plate_hp[stage] <= 0.0:
		_break_stage()
	return out


func _break_stage() -> void:
	var plate: StringName = STAGES[stage]
	var idx: int = stage
	stage += 1
	if idx < hitboxes.size() and hitboxes[idx] != null:
		hitboxes[idx].set_active(false)
	_hide_meshes(plate)
	if multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_rpc_hide.rpc(plate)
	PoliceSpecialKit.cue(_npc, &"cue.wrecker_plate_crack", _npc.head_position())
	plate_broken.emit(plate, stage)


@rpc("authority", "call_remote", "reliable")
func _rpc_hide(plate: StringName) -> void:
	_hide_meshes(plate)


func _hide_meshes(plate: StringName) -> void:
	var names: Array = [plate]
	names.append_array(EXTRA_HIDE.get(plate, []))
	var root: Node = _npc.get_node_or_null("Visual")
	if root == null:
		return
	for nm: Variant in names:
		var n: Node3D = root.find_child(String(nm), true, false) as Node3D
		if n != null:
			n.visible = false


func _build() -> void:
	if _npc == null or not is_instance_valid(_npc):
		return
	var hp: Array[float] = NpcHitRules.armor_of(_npc.enemy_def)["plate_health"]
	plate_hp.clear()
	for i: int in range(STAGES.size()):
		plate_hp.append(hp[i] if i < hp.size() else HP_DEFAULT[i])
	var root: Node3D = _npc.get_node_or_null("Hitboxes") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "Hitboxes"
		_npc.add_child(root)
	var tw: HeavySpecialTweak = HeavySpecialTweak.data()
	var head: Vector3 = Vector3(0.0, _npc.head_height, 0.0)
	hitboxes.clear()
	hitboxes.append(_add_box(root, "Faceplate", tw.wrecker_faceplate_size, head + tw.wrecker_faceplate_offset))
	hitboxes.append(_add_box(root, "Visor", tw.wrecker_visor_size, head + tw.wrecker_visor_offset))


func _add_box(root: Node3D, nm: String, size: Vector3, pos: Vector3) -> Hitbox:
	var a: Hitbox = Hitbox.new()
	a.name = nm
	a.hit_zone = Enums.HitZone.WEAKPOINT
	a.target = self
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	a.add_child(cs)
	root.add_child(a)
	return a
