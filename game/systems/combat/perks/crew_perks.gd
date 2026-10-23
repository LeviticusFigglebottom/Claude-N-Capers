## Per-crew perk dispatcher (QB-62, P4). Owner: ENV A. Lives as metadata META on its CrewController
## (PerkHooks.of creates it on first use, so it exists from CrewHealth._ready on). refresh() keeps one
## PerkComponent per `perk.*` PARAMS key that Modifiers.params(slot, key) grants (non-empty dict) and
## routes the CrewHealth hooks and the holder's gameplay events (EventBus.damage_applied /
## npc_killed with the holder as attacker; authority only) to them.
## Also owns the perk "panic" runtime: panicked enemies are NpcBase.stun()ed and ticked here.
class_name CrewPerks
extends RefCounted

const META: StringName = &"crew_perks"
## AmmoPickupSystem service name and its `ammo_picked(crew, amount)` signal (duck-typed, QB-57).
const AMMO_SERVICE: StringName = &"ammo_pickups"
const AMMO_SIGNAL: StringName = &"ammo_picked"

var crew: CrewController = null
## perk key -> component (insertion order = SCRIPTS order).
var components: Dictionary[StringName, PerkComponent] = {}

var _connected: bool = false
var _ammo_source: Node = null
## Enemies panicked by this crew member's perks (stun ticked by tick_panics).
var _panicked: Array[NpcBase] = []


func _init(p_crew: CrewController) -> void:
	crew = p_crew


## perk key -> component script. Order = hook order.
static func scripts() -> Dictionary[StringName, GDScript]:
	return {
		PerkCrewChief.KEY: PerkCrewChief, PerkMuscle.KEY: PerkMuscle, PerkArmorer.KEY: PerkArmorer,
		PerkRogue.KEY: PerkRogue, PerkCrook.KEY: PerkCrook, PerkSociopath.KEY: PerkSociopath,
		PerkBurglar.KEY: PerkBurglar, PerkInfiltrator.KEY: PerkInfiltrator, PerkGrinder.KEY: PerkGrinder,
		PerkStoic.KEY: PerkStoic, PerkAnarchist.KEY: PerkAnarchist, PerkExPresident.KEY: PerkExPresident,
		PerkGambler.KEY: PerkGambler, PerkKingpin.KEY: PerkKingpin, PerkThrowable.KEY: PerkThrowable,
		PerkPocketEcm.KEY: PerkPocketEcm, PerkYakuza.KEY: PerkYakuza, PerkBiker.KEY: PerkBiker,
		PerkManiac.KEY: PerkManiac, PerkSicario.KEY: PerkSicario, PerkTagTeam.KEY: PerkTagTeam,
		PerkLeech.KEY: PerkLeech, PerkCopycat.KEY: PerkCopycat,
	}


## Sync the components with the crew member's current modifiers (a changed dict keeps the state).
func refresh() -> void:
	if crew == null or not is_instance_valid(crew):
		return
	var all: Dictionary[StringName, GDScript] = scripts()
	for k: StringName in all:
		var p: Dictionary = Modifiers.params(crew.slot, k)
		if p.is_empty():
			if components.erase(k) and Net.is_authority():
				PerkItems.clear_key(HeistRuntime.of(crew), crew.slot, k)  # D-163: its HUD item goes with it
			continue
		if components.has(k):
			components[k].params = p
			continue
		var comp: PerkComponent = all[k].new() as PerkComponent
		comp.setup(crew, k, p)
		components[k] = comp
	if not _connected and Net.is_authority() and not components.is_empty():
		_connected = true
		EventBus.damage_applied.connect(_on_damage_applied)
		EventBus.npc_killed.connect(_on_npc_killed)
	if _connected and (_ammo_source == null or not is_instance_valid(_ammo_source)):
		_connect_ammo()


func _connect_ammo() -> void:
	var rt: HeistRuntime = HeistRuntime.of(crew)
	var svc: Node = rt.service(AMMO_SERVICE) if rt != null else null
	if svc == null or not svc.has_signal(AMMO_SIGNAL):
		return
	_ammo_source = svc
	var cb: Callable = _on_ammo_picked
	if not svc.is_connected(AMMO_SIGNAL, cb):
		svc.connect(AMMO_SIGNAL, cb)


func component(k: StringName) -> PerkComponent:
	return components.get(k)


# --- Aggregated hooks ---------------------------------------------------------------------------

func adjust_max_health(value: float, raw_armor: float) -> float:
	for c: PerkComponent in components.values():
		value = c.adjust_max_health(value, raw_armor)
	return value


func adjust_max_armor(value: float, raw_health: float) -> float:
	for c: PerkComponent in components.values():
		value = c.adjust_max_armor(value, raw_health)
	return value


func damage_reduction(info: Dictionary) -> float:
	var dr: float = 0.0
	for c: PerkComponent in components.values():
		dr += c.damage_reduction(info)
	return dr


func incoming(info: Dictionary, dmg: float) -> float:
	for c: PerkComponent in components.values():
		dmg = c.incoming(info, dmg)
	return dmg


func after_hit(out: Dictionary) -> void:
	for c: PerkComponent in components.values():
		c.after_hit(out)


## Authority tick (the holder is NORMAL / SWAN_SONG). True when a perk replaces the armor regen.
func server_tick(delta: float) -> bool:
	refresh()
	tick_panics(delta)
	var handled: bool = false
	for c: PerkComponent in components.values():
		c.tick(delta)
		handled = handled or c.handles_armor_regen()
	return handled


func dodge_add() -> float:
	var total: float = 0.0
	for c: PerkComponent in components.values():
		total += c.dodge_add()
	return total


func aggro_mult(from: Node3D) -> float:
	var m: float = 1.0
	for c: PerkComponent in components.values():
		m *= c.aggro_mult(from)
	return m


func melee_damage_mult() -> float:
	var m: float = 1.0
	for c: PerkComponent in components.values():
		m *= c.melee_damage_mult()
	return m


func on_ammo_picked(amount: int) -> void:
	for c: PerkComponent in components.values():
		c.on_ammo_picked(amount)


## D-164 (LEAD): deck-item cooldowns keep running while the holder is down (CrewHealth, through
## PerkHooks.tick_downed): only components with tick_item_cooldown(delta), only that timer.
func tick_item_cooldowns(delta: float) -> void:
	for c: PerkComponent in components.values():
		if c.has_method(&"tick_item_cooldown"):
			c.call(&"tick_item_cooldown", delta)


func use_throwable(kind: StringName) -> bool:
	var up: bool = crew == null or crew.crew_state in [Enums.CrewState.NORMAL, Enums.CrewState.SWAN_SONG]
	for c: PerkComponent in components.values():
		if not up and not (c.has_method(&"usable_while_down") and bool(c.call(&"usable_while_down"))):
			continue  # D-164: while down only a perk that allows it (Leech)
		if c.use_throwable(kind):
			return true
	return false


# --- Panic --------------------------------------------------------------------------------------

## Server: panic the enemies within `radius` m of `pos` (NpcBase.stun for PerkTweak.panic_stun_s).
static func panic(holder: CrewController, pos: Vector3, radius: float) -> int:
	var perks: CrewPerks = PerkHooks.of(holder)
	if perks == null or not Net.is_authority():
		return 0
	var n: int = 0
	for npc: NpcBase in PerkUtil.enemies_near(holder, pos, radius):
		npc.stun(PerkTweak.data().panic_stun_s)
		if npc.is_stunned():
			n += 1
			if not perks._panicked.has(npc):
				perks._panicked.append(npc)
	return n


func tick_panics(delta: float) -> void:
	for i: int in range(_panicked.size() - 1, -1, -1):
		var npc: NpcBase = _panicked[i]
		if npc == null or not is_instance_valid(npc):
			_panicked.remove_at(i)
			continue
		npc.tick_stun(delta)
		if not npc.is_stunned():
			_panicked.remove_at(i)


# --- Events (authority) -------------------------------------------------------------------------

func _is_mine(attacker_net_id: int) -> bool:
	return crew != null and is_instance_valid(crew) and Net.is_authority() and crew.net_id != 0 \
		and attacker_net_id == crew.net_id


func _on_damage_applied(victim_net_id: int, attacker_net_id: int, info: Dictionary) -> void:
	if not _is_mine(attacker_net_id) or float(info.get("amount", 0.0)) <= 0.0:
		return
	var victim: Node = Ids.lookup(victim_net_id)
	if victim == null or victim is CrewController:
		return
	for c: PerkComponent in components.values():
		c.on_damage_dealt(victim, info)


func _on_ammo_picked(who: Node, amount: int) -> void:
	if who == crew and Net.is_authority():
		on_ammo_picked(amount)


func _on_npc_killed(npc_net_id: int, killer_net_id: int, info: Dictionary) -> void:
	if not _is_mine(killer_net_id):
		return
	var victim: Node = Ids.lookup(npc_net_id)
	for c: PerkComponent in components.values():
		c.on_kill(victim, info)
