## Ammo box drops and walk-over pickups (QB-57, PD2). Owner: ENV A. Service SERVICE, child of
## HeistRuntime, server only. Numbers: AmmoPickupTweak (ammo_pickup_tweak.tres).
## * Drops: every killed NPC (EventBus.npc_killed) whose role is not in no_drop_roles drops one
##   AmmoPickup at its feet (chance drop_chance, rolled on GameRng &"ammo" only when below 1).
## * Pickup: a NORMAL / SWAN_SONG crew member within pickup_radius_m x weapon.ammo_pickup_range_mult
##   (horizontal) and pickup_height_m takes the box when at least one weapon is missing ammo. Each of
##   their weapons gets round(rand(WeaponStats.ammo_pickup_min, ammo_pickup_max) x
##   weapon.ammo_pickup_mult[weapon class] x shotgun ammo ammo_pickup_mult, D-118) rounds (GameRng &"ammo"), capped at
##   what it is missing (DeployablePrefab.max_ammo), per crew member's own weapons and modifiers. D-124: whole rounds
##   only, the fraction carries over per crew member and weapon (a Thumper's 0.2-0.4 gives a grenade every few boxes,
##   so the expected pickup matches the data); the carry resets when the weapon fills up or changes.
##   A box nobody can use stays on the floor.
## * weapon.kill_ammo_drop {every_n_kills} (Scrounger aced): every n-th kill by that crew member drops an
##   extra box (on top of the normal drop roll).
## * weapon.ammo_pickup_throwable {base_chance, step} (Pack Mule aced): a taken box holds a throwable
##   with base_chance + step x boxes taken without one (GameRng &"ammo"); +1 CrewWeapons.throwable_count
##   up to the equipped ThrowableDef.count, and the streak resets.
## * `ammo_picked(crew, amount)` (amount = rounds added over both weapons) is the hook for perk
##   mechanics such as perk.gambler.
##
## PUBLIC API: drop(position) -> AmmoPickup (server/test hook), boxes() -> Array[Node],
##   try_pickup(crew, box) -> int (rounds added; -1 = not taken, 0 = taken for a carried-over fraction),
##   static amount_for(crew, ws, rng) -> float, static rounds_for(crew, ws, rng) -> int, carry(crew, ws) -> float.
class_name AmmoPickupSystem
extends Node

signal ammo_picked(crew: CrewController, amount: int)

const SERVICE: StringName = &"ammo_pickups"
const RNG_STREAM: StringName = &"ammo"
const RANGE_KEY: StringName = &"weapon.ammo_pickup_range_mult"
const AMOUNT_KEY: StringName = &"weapon.ammo_pickup_mult"
const KILL_DROP_KEY: StringName = &"weapon.kill_ammo_drop"
const THROWABLE_KEY: StringName = &"weapon.ammo_pickup_throwable"

var _runtime: HeistRuntime = null
var _boxes: Array[AmmoPickup] = []
## crew slot -> kills (weapon.kill_ammo_drop) / boxes taken without a throwable (weapon.ammo_pickup_throwable).
var _kills: Dictionary[int, int] = {}
var _dry_boxes: Dictionary[int, int] = {}
## D-124: "<crew slot>|<weapon slot>" -> [weapon id, carried fraction of a round].
var _carry: Dictionary[String, Array] = {}


func _ready() -> void:
	if _runtime == null:
		_runtime = HeistRuntime.of(self)
	EventBus.npc_killed.connect(_on_npc_killed)


func _exit_tree() -> void:
	if EventBus.npc_killed.is_connected(_on_npc_killed):
		EventBus.npc_killed.disconnect(_on_npc_killed)


func _on_npc_killed(npc_net_id: int, killer_net_id: int, _info: Dictionary) -> void:
	if not Net.is_authority() or _runtime == null or _runtime.is_replica:
		return
	var npc: NpcBase = Ids.lookup(npc_net_id) as NpcBase
	if npc == null or not _runtime.is_ancestor_of(npc):
		return
	var tw: AmmoPickupTweak = AmmoPickupTweak.data()
	if tw.no_drop_roles.has(npc.role):
		return
	var pos: Vector3 = npc.global_position + Vector3(0.0, tw.drop_height_m, 0.0)
	var killer: CrewController = Ids.lookup(killer_net_id) as CrewController
	if killer != null:
		var every: int = int(Modifiers.params(killer.slot, KILL_DROP_KEY).get("every_n_kills", 0))
		_kills[killer.slot] = int(_kills.get(killer.slot, 0)) + 1
		if every > 0 and int(_kills[killer.slot]) % every == 0:
			drop(pos + Vector3(0.25, 0.0, 0.0))
	if tw.drop_chance < 1.0 and GameRng.stream(RNG_STREAM).randf() >= tw.drop_chance:
		return
	drop(pos)


## Server/test hook: drop an ammo box at `pos`. Returns it (null without a runtime).
func drop(pos: Vector3) -> AmmoPickup:
	if _runtime == null or _runtime.dynamic_root == null:
		return null
	_prune()
	var tw: AmmoPickupTweak = AmmoPickupTweak.data()
	while tw.max_boxes > 0 and _boxes.size() >= tw.max_boxes:
		_remove(_boxes[0])
	var box: AmmoPickup = AmmoPickup.new()
	box.name = "AmmoPickup_%d" % _runtime.dynamic_root.get_child_count()
	_runtime.dynamic_root.add_child(box, true)
	box.global_position = pos
	NetIds.claim(box)
	_boxes.append(box)
	return box


## Ammo boxes lying in this heist.
func boxes() -> Array[Node]:
	_prune()
	var out: Array[Node] = []
	out.assign(_boxes)
	return out


func _physics_process(_delta: float) -> void:
	if not Net.is_authority() or _runtime == null or _boxes.is_empty():
		return
	_prune()
	var tw: AmmoPickupTweak = AmmoPickupTweak.data()
	for crew: CrewController in _runtime.crew_members():
		if crew.crew_state != Enums.CrewState.NORMAL and crew.crew_state != Enums.CrewState.SWAN_SONG:
			continue
		var r: float = tw.pickup_radius_m * Modifiers.mult(crew.slot, RANGE_KEY)
		for box: AmmoPickup in _boxes.duplicate():
			var d: Vector3 = box.global_position - crew.global_position
			if Vector2(d.x, d.z).length() <= r and absf(d.y) <= tw.pickup_height_m:
				try_pickup(crew, box)


## Server: `crew` takes `box` if any weapon is missing ammo. Returns the rounds added over both weapons
## (-1 = not taken; 0 = taken, the fractions only carried over).
func try_pickup(crew: CrewController, box: AmmoPickup) -> int:
	if not Net.is_authority() or crew == null or crew.weapons == null or box == null or not _boxes.has(box):
		return -1
	var w: CrewWeapons = crew.weapons
	var rng: RandomNumberGenerator = GameRng.stream(RNG_STREAM)
	var total: int = 0
	var taken: bool = false
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if not w.has_weapon(ws):
			continue
		var missing: int = DeployablePrefab.max_ammo(crew, ws) - w.mag(ws) - w.reserve(ws)
		if missing <= 0:
			continue
		var amount: float = amount_for(crew, ws, rng)
		if amount <= 0.0:
			continue
		taken = true
		var n: float = amount + carry(crew, ws)
		var add: int = mini(floori(n + 0.000001), missing)
		_carry[_carry_key(crew, ws)] = [w.weapon_id(ws), 0.0 if add >= missing else maxf(n - add, 0.0)]
		if add <= 0:
			continue
		w.set_ammo(ws, w.mag(ws), w.reserve(ws) + add)
		total += add
	if not taken:
		return -1
	_roll_throwable(crew, rng)
	_remove(box)
	ammo_picked.emit(crew, total)
	return total


## D-124: the fraction of a round weapon slot `ws` of `crew` carries into its next box (0 after a weapon change).
func carry(crew: CrewController, ws: int) -> float:
	var c: Array = _carry.get(_carry_key(crew, ws), [])
	if c.size() < 2 or crew.weapons == null or StringName(c[0]) != crew.weapons.weapon_id(ws):
		return 0.0
	return float(c[1])


static func _carry_key(crew: CrewController, ws: int) -> String:
	return "%d|%d" % [crew.slot, ws]


## Rounds (fractional) one box gives weapon slot `ws` of `crew` (before the carry-over and the missing-ammo cap).
static func amount_for(crew: CrewController, ws: int, rng: RandomNumberGenerator) -> float:
	var w: CrewWeapons = crew.weapons
	var st: WeaponStats = w.stats(ws) if w != null else null
	if st == null or st.ammo_pickup_max <= 0.0:
		return 0.0
	var def: WeaponDef = ContentDB.weapon(w.weapon_id(ws))
	var q: StringName = Enums.weapon_class_qualifier(def.weapon_class) if def != null else &"pistol"
	var lo: float = minf(st.ammo_pickup_min, st.ammo_pickup_max)
	return rng.randf_range(lo, st.ammo_pickup_max) * Modifiers.mult(crew.slot, AMOUNT_KEY, q) \
		* w.ammo_pickup_mult(ws)  # D-118: shotgun ammo params.ammo_pickup_mult


## One box rounded to whole rounds, at least 1 (no carry-over; kept for callers that want a single box's size).
static func rounds_for(crew: CrewController, ws: int, rng: RandomNumberGenerator) -> int:
	var n: float = amount_for(crew, ws, rng)
	return maxi(int(round(n)), 1) if n > 0.0 else 0


func _roll_throwable(crew: CrewController, rng: RandomNumberGenerator) -> void:
	var p: Dictionary = Modifiers.params(crew.slot, THROWABLE_KEY)
	if p.is_empty() or crew.loadout == null or crew.loadout.throwable == &"":
		return
	var def: ThrowableDef = ContentDB.throwable(crew.loadout.throwable)
	var w: CrewWeapons = crew.weapons
	if def == null or w.throwable_count >= def.count:
		return
	var dry: int = int(_dry_boxes.get(crew.slot, 0))
	var chance: float = float(p.get("base_chance", 0.0)) + float(p.get("step", 0.0)) * float(dry)
	if rng.randf() < chance:
		CrewThrowables.set_count(crew, w.throwable_count + 1)
		_dry_boxes[crew.slot] = 0
	else:
		_dry_boxes[crew.slot] = dry + 1


func _remove(box: AmmoPickup) -> void:
	_boxes.erase(box)
	if is_instance_valid(box) and not box.is_queued_for_deletion():
		if box.get_parent() != null:
			box.get_parent().remove_child(box)
		box.queue_free()


func _prune() -> void:
	var keep: Array[AmmoPickup] = []
	for b: AmmoPickup in _boxes:
		if is_instance_valid(b) and b.is_inside_tree() and not b.is_queued_for_deletion():
			keep.append(b)
	_boxes = keep
