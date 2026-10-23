## Crew throwables (A3-12): frag / concussion / incendiary grenades and throwing knives. Owner: ENV A.
## Child `Throwables` of CrewController, ticked with the weapons (server and the owning client). The item is
## Loadout.throwable (ThrowableDef, count in CrewWeapons.throwable_count); a perk-deck throwable (flask,
## injector: PerkHooks.throwable_id) replaces it and stays with PerkThrowable.
## - a rising edge of intent.throw_item (masked, NORMAL, one left, not mid-melee) starts the throw: `pin_pull`
##   now, the release throw_windup_s later. At the release the authority takes one from the count and spawns a
##   ThrownItem along the aim (lofted throw_loft_deg, throw_speed_mps + the thrower's velocity); then
##   throw_recover_s before the next throw. No shooting while throwing (CrewWeapons.can_fire reads `busy()`).
## Signals (presentation; FpViewmodel plays the `throwable` set): pin_pulled, released.
class_name CrewThrowables
extends Node

signal pin_pulled()
signal released()

const NODE_NAME: String = "Throwables"
const CUE_PIN: StringName = &"cue.throwable_pin"

## &"" idle, &"winding" (pin pulled), &"recovering".
var state: StringName = &""
var state_left: float = 0.0
var throws: int = 0

var _crew: CrewController = null
var _prev: bool = false


## Server: set `crew`'s throwables left (ammo pickups, tests); synced to a remote owner.
static func set_count(crew: CrewController, count: int) -> void:
	if crew == null or crew.weapons == null:
		return
	crew.weapons.throwable_count = maxi(count, 0)
	var t: CrewThrowables = crew.get_node_or_null(NODE_NAME) as CrewThrowables
	if t != null and Net.is_authority() and not crew.is_ai and crew.peer_id != Net.local_peer_id() \
			and HeistNetSync.can_rpc(crew):
		t._rpc_count.rpc_id(crew.peer_id, crew.weapons.throwable_count)


func _ready() -> void:
	_crew = get_parent() as CrewController


## The equipped grenade-type throwable (null when none, or a perk-deck item replaces it).
func throwable_def() -> ThrowableDef:
	if _crew == null or _crew.loadout == null or _crew.loadout.throwable == &"":
		return null
	if PerkHooks.throwable_id(_crew) != &"":
		return null  # the deck's flask / injector (PerkThrowable)
	var def: ThrowableDef = ContentDB.throwable(_crew.loadout.throwable)
	return def if def != null and ThrownItem.KINDS.has(def.kind) else null


func can_throw() -> bool:
	return _crew != null and _crew.masked and _crew.crew_state == Enums.CrewState.NORMAL and state == &"" \
		and _crew.weapons != null and _crew.weapons.throwable_count > 0 and throwable_def() != null \
		and (_crew.melee == null or _crew.melee.state == &"")


## Throwing (no shots meanwhile).
func busy() -> bool:
	return state != &""


func tick(intent: CrewIntent, delta: float) -> void:
	var held: bool = intent != null and intent.throw_item
	var pressed: bool = held and not _prev
	_prev = held
	if state == &"":
		if pressed and can_throw():
			state = &"winding"
			state_left = CombatTweak.data().throw_windup_s
			pin_pulled.emit()
			if Net.is_authority():  # audio_cues v1.3
				EventBus.audio_cue_requested.emit(CUE_PIN, _crew.eye_position(), _crew.net_id)
				Net.replicate_event(&"audio_cue_requested", [CUE_PIN, _crew.eye_position(), _crew.net_id])
		return
	state_left -= delta
	if state_left > 0.0:
		return
	if state == &"winding":
		if _crew.crew_state != Enums.CrewState.NORMAL:
			state = &""  # downed / tased mid-throw: the grenade is not thrown
			return
		_release()
		state = &"recovering"
		state_left = CombatTweak.data().throw_recover_s
	else:
		state = &""


func _release() -> void:
	throws += 1
	released.emit()
	if not Net.is_authority():
		return
	var def: ThrowableDef = throwable_def()
	if def == null or _crew.weapons.throwable_count <= 0:
		return
	set_count(_crew, _crew.weapons.throwable_count - 1)
	spawn(_crew, def, throws)


## Server: spawn `def` thrown by `crew` along its aim (tests call it directly). `extra` adds item params (a deck
## throwable's mechanic numbers, D-163) before the item enters the tree, so they replicate with its spawn.
static func spawn(crew: CrewController, def: ThrowableDef, seq: int = 0, extra: Dictionary = {}) -> ThrownItem:
	var rt: HeistRuntime = HeistRuntime.of(crew)
	var parent: Node = rt.dynamic_root if rt != null and rt.dynamic_root != null else crew.get_parent()
	if parent == null:
		return null
	var tw: CombatTweak = CombatTweak.data()
	var aim: Vector3 = crew.aim_direction().normalized()
	var side: Vector3 = aim.cross(Vector3.UP)
	var dir: Vector3 = aim.rotated(side.normalized(), deg_to_rad(tw.throw_loft_deg)) if side.length() > 0.01 else aim
	var item: ThrownItem = ThrownItem.new()
	item.name = "Thrown_%d_%d" % [crew.slot, seq]
	item.params = {
		"velocity": dir * tw.throw_speed_mps + crew.velocity, "kind": def.kind, "damage": def.damage,
		"radius_m": def.radius_m, "fuse_s": def.fuse_s, "attacker": crew.net_id, "owner_slot": crew.slot,
		"throwable_id": def.id,
	}
	item.params.merge(extra, true)
	parent.add_child(item, true)
	item.global_position = crew.eye_position() + aim * 0.4
	NetIds.claim(item)
	return item


@rpc("authority", "call_remote", "reliable")
func _rpc_count(count: int) -> void:
	if _crew != null and _crew.weapons != null:
		_crew.weapons.throwable_count = count
