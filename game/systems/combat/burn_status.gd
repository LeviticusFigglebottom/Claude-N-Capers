## Burning (B4-18 flamethrower, L3.4): fire damage over time on an NPC, server only. Owner: ENV A.
## Child `Burn` of the NpcBase. Each tick delivers DamageType.FIRE (ignores armor; shields pass at
## CombatTweak.shield_fire_damage_mult) through CombatSystem.deliver_hit. Igniting again refreshes the
## duration. On ignition a panic roll (GameRng &"burn_panic") stuns the NPC for `panic_s` (PD2: burning
## enemies flail instead of shooting; stun-immune enemies such as the Wrecker ignore it, L4.6).
## D-118: the same status ticks other DoT types under another node name (flechette bleed: POISON, `Bleed`).
class_name BurnStatus
extends Node

const NODE_NAME: String = "Burn"
const TICK_S: float = 0.5

var dps: float = 0.0
var left: float = 0.0
var attacker: int = 0
var weapon_id: StringName = &""
## Enums.DamageType of each tick (FIRE unless a D-118 bleed).
var damage_type: int = Enums.DamageType.FIRE
var _tick: float = 0.0
## This burn stunned the NPC (stuns are ticked by whoever applied them).
var _panicking: bool = false


## Server: set `npc` on fire with flame params {dot_damage_per_s, dot_duration_s, panic_chance, panic_s}.
## `type` / `node_name`: another DoT kind on its own child node (D-118 bleed).
static func ignite(npc: NpcBase, attacker_net_id: int, wid: StringName, flame: Dictionary,
		type: int = Enums.DamageType.FIRE, node_name: String = NODE_NAME) -> BurnStatus:
	if npc == null or not npc.alive or not Net.is_authority():
		return null
	var per_s: float = float(flame.get("dot_damage_per_s", 0.0))
	var dur: float = float(flame.get("dot_duration_s", 0.0))
	if per_s <= 0.0 or dur <= 0.0:
		return null
	var b: BurnStatus = npc.get_node_or_null(node_name) as BurnStatus
	var fresh: bool = b == null
	if fresh:
		b = BurnStatus.new()
		b.name = node_name
		b.damage_type = type
		npc.add_child(b)
	b.dps = maxf(b.dps, per_s)
	b.left = maxf(b.left, dur)
	b.attacker = attacker_net_id
	b.weapon_id = wid
	if fresh and GameRng.stream(&"burn_panic").randf() < float(flame.get("panic_chance", 0.0)):
		npc.stun(float(flame.get("panic_s", 0.0)))
		b._panicking = npc.is_stunned()
	return b


func _physics_process(delta: float) -> void:
	var npc: NpcBase = get_parent() as NpcBase
	if npc == null or not npc.alive or (left <= 0.0 and not _panicking) or not Net.is_authority():
		_stop()
		return
	if _panicking:
		npc.tick_stun(delta)
		_panicking = npc.is_stunned()
	left -= delta
	_tick += delta
	if _tick < TICK_S - 0.0001 or left < -0.001:
		return
	_tick -= TICK_S
	var c: Vector3 = CombatSystem.target_center(npc)
	var info: Dictionary = Damage.info(dps * TICK_S, damage_type, Enums.HitZone.BODY, weapon_id, c,
		Vector3.DOWN, attacker)
	info["pierced_armor"] = true
	CombatSystem.deliver_hit(npc, info, attacker)


func _stop() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
