# gdlint:disable=max-public-methods
## Crew weapons component (A1-08): child `Weapons` of CrewController. Owner: ENV A.
## Fidelity: L3.1 (stats from resolved WeaponStats), L3.2 (falloff), L3.7 (suppressors), L3.8 (hit
## claims), S1.1 (no firing while casing), S4.3 (unsuppressed shots are noise), L2.5 (shoot while
## downed). Numbers: ENV B's resolved WeaponStats + CombatTweak (combat_tweak.tres).
##
## Per tick (CrewController): `server_tick` on the authority for every slot, `client_tick` on a remote
## human's own peer. Fire decisions (trigger edge for semi, RPM cooldown, ammo, reload, equip) run
## where the shooter is simulated: the server for solo/host/AI/bots, the owning client for remote
## humans. Each shot builds a hit claim (see CombatSystem) from a hitscan with spread; the server
## validates it (CombatSystem.validate_and_apply) and applies damage. Remote claims arrive through
## `_rpc_hit_claim`, checked against multiplayer.get_remote_sender_id().
##
## HUD duck-typed interface (local_hud_model.gd): mag(slot), reserve(slot), equipped_slot,
## deployable_count, throwable_count. Slots are Enums.WeaponSlot (PRIMARY / SECONDARY).
## Modifiers: weapon.damage_mult / spread_mult / recoil_mult / reload_speed_mult / swap_speed_mult /
## mag_extra / ammo_total_mult, qualified by Enums.weapon_class_qualifier(WeaponDef.weapon_class).
class_name CrewWeapons
extends Node

## Local presentation: a shot left the muzzle (viewmodel, local audio). `claim` = hit claim.
signal fired(claim: Dictionary)
signal reload_started(weapon_slot: int, duration: float)
signal reload_finished(weapon_slot: int)
## A running reload was cancelled (cancel_reload: P's sprint start, PD2) before it finished.
signal reload_cancelled(weapon_slot: int)
signal equipped_changed(weapon_slot: int)
signal ammo_changed(weapon_slot: int)
## D-118: a slot's laser / flashlight was switched (server toggle; clients on the replicated state).
signal gadget_changed(weapon_slot: int, on: bool)

## D-118: gadgets CrewIntent.gadget toggles (WeaponStats.gadgets); angled sights are not switched here.
const TOGGLE_GADGETS: Array[StringName] = [&"laser", &"flashlight"]
## PO-8: server-side marker on a claim that arrived from its owning client (_rpc_hit_claim).
const REMOTE_CLAIM_KEY: String = "_remote"

## Per-slot runtime state.
class WeaponState:
	extends RefCounted
	var id: StringName = &""
	var def: WeaponDef = null
	var stats: WeaponStats = null
	var qualifier: StringName = &""
	var mag: int = 0
	var reserve: int = 0
	var mag_size: int = 0
	## B4-18: merged WeaponDef/WeaponModDef params (SpecialWeapons) and the resulting kind.
	var special: Dictionary = {}
	var kind: StringName = &""
	## D-118: resolved shotgun ammo profile (ShotgunAmmo.profile), pellets per shot and wall piercing.
	var ammo: Dictionary = {}
	var pellets: int = 1
	var wall_pierce: bool = false

## Equipped Enums.WeaponSlot (HUD).
var equipped_slot: int = Enums.WeaponSlot.SECONDARY
var deployable_count: int = 0
## A2-06: current deployable id (DeployableSystem keeps it and deployable_count up to date).
var deployable_id: StringName = &""
var throwable_count: int = 0
## Effective (resolved) loadout these weapons came from.
var loadout: Loadout = null
var reloading: bool = false
var reload_left: float = 0.0
## Seconds since this crew member last fired (INF = never). L2.5 "downed player who is shooting".
var last_shot_age: float = INF
## Accepted shots (server) / fired shots (client).
var shots_fired: int = 0
## A3-01a (L4.4): set by a Stinger while tasing (server). The equipped weapon fires on its own at max
## RPM (any fire mode), spread x involuntary_spread_mult, pulled involuntary_pitch_up_deg up, and
## auto-reloads; cleared when the crew state leaves TASED. Setting it false resets the two below.
var involuntary_fire: bool = false:
	set(v):
		involuntary_fire = v
		if not v:
			involuntary_spread_mult = 1.0
			involuntary_pitch_up_deg = 0.0
var involuntary_spread_mult: float = 1.0
## B4a: aiming down sights this tick (the intent's aim; weapon.hip_fire_rate_mult applies while false).
var aiming: bool = false
var involuntary_pitch_up_deg: float = 0.0
## B4-18 (presentation + HUD): bow draw 0..1 while the trigger is held, minigun spin 0..1.
var charge: float = 0.0
var spin: float = 0.0
## B4-18: CrewController multiplies its move speed by this (minigun spinning: params.spin.move_speed_mult).
var move_speed_mult: float = 1.0

var _crew: CrewController = null
var _states: Dictionary[int, WeaponState] = {}
var _cooldown: float = 0.0
var _equip_left: float = 0.0
var _prev_fire: bool = false
var _prev_reload: bool = false
var _prev_gadget: bool = false
## D-118: Enums.WeaponSlot -> gadget switched on (absent = off).
var _gadget_on: Dictionary[int, bool] = {}
var _seq: int = 0
var _server_clock: float = 0.0
var _last_server_shot_clock: float = -INF
var _last_server_seq: int = 0
var _drawing: bool = false
## Minigun spinning up / flamethrower burning (cue edges).
var _spinning_up: bool = false
## PO-8 (impact_fx.md): per-shot pellet RNG (seeded from the claim's `fx_seed`, so every peer replays the
## same pellets) and the last `_hitscan` ray: the hit dictionary ({} = miss) and thin walls passed.
var _pellet_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ray_hit: Dictionary = {}
var _ray_walls: int = 0


func _ready() -> void:
	_crew = get_parent() as CrewController
	if _crew == null:
		Log.error(&"combat", "CrewWeapons must be a child of a CrewController")
		return
	_crew.crew_state_changed.connect(_on_crew_state_changed)
	if _crew.loadout == null or (_crew.loadout.secondary != &"" and _crew.loadout.resolved_secondary == null) \
			or (_crew.loadout.primary != &"" and _crew.loadout.resolved_primary == null):
		_crew.loadout = build_loadout(_crew.loadout)
	set_loadout(_crew.loadout)


## Build an effective, resolved loadout: `base` if given (resolved by ENV B's LoadoutResolver when
## its stats are missing), else CombatTweak's default (kestrel_p9 + suppressor, D-025 QA-2).
static func build_loadout(base: Loadout) -> Loadout:
	var l: Loadout = base
	if l == null:
		var tw: CombatTweak = CombatTweak.data()
		l = Loadout.new()
		l.primary = tw.default_primary
		l.primary_mods = tw.default_primary_mods.duplicate()
		l.secondary = tw.default_secondary
		l.secondary_mods = tw.default_secondary_mods.duplicate()
		l.armor = tw.default_armor if ContentDB.armor(tw.default_armor) != null else &""
	var needs_resolve: bool = (l.primary != &"" and l.resolved_primary == null) \
		or (l.secondary != &"" and l.resolved_secondary == null)
	if needs_resolve:
		l = LoadoutResolver.resolve(l)
	return l


## (Re)arm from a resolved loadout: full magazines and reserves.
func set_loadout(l: Loadout) -> void:
	loadout = l
	_states.clear()
	_clear_gadgets()
	if l != null:
		deployable_id = l.deployable  # A2-06: HUD fallback until DeployableSystem syncs
		var th: ThrowableDef = ContentDB.throwable(l.throwable) if l.throwable != &"" else null
		throwable_count = th.count if th != null else 0
		_add_state(Enums.WeaponSlot.PRIMARY, l.primary, l.resolved_primary, l.primary_mods)
		_add_state(Enums.WeaponSlot.SECONDARY, l.secondary, l.resolved_secondary, l.secondary_mods)
	equipped_slot = Enums.WeaponSlot.PRIMARY if _states.has(Enums.WeaponSlot.PRIMARY) else Enums.WeaponSlot.SECONDARY
	reloading = false
	_equip_left = 0.0
	_cooldown = 0.0
	_reset_special()


func _add_state(ws: int, id: StringName, st: WeaponStats, mods: Array[StringName] = []) -> void:
	if id == &"" or st == null:
		return
	var s: WeaponState = WeaponState.new()
	s.id = id
	s.def = ContentDB.weapon(id)
	s.stats = st
	s.qualifier = Enums.weapon_class_qualifier(s.def.weapon_class) if s.def != null else &"pistol"
	s.special = SpecialWeapons.params_of(s.def, mods)
	s.kind = SpecialWeapons.kind_of(s.special)
	s.ammo = ShotgunAmmo.profile(s.special)
	s.pellets = ShotgunAmmo.pellets(st.pellets, s.ammo)
	s.wall_pierce = ShotgunAmmo.wall_pierce(st.wall_pierce, s.ammo)
	var slot: int = _crew.slot if _crew != null else -1
	s.mag_size = maxi(st.mag_size + int(Modifiers.add(slot, &"weapon.mag_extra", s.qualifier)), 1)
	var total: int = int(round(float(st.total_ammo) * Modifiers.mult(slot, &"weapon.ammo_total_mult", s.qualifier)))
	s.mag = s.mag_size
	s.reserve = maxi(total - s.mag_size, 0)
	_states[ws] = s


# --- Queries (HUD + other systems) ----------------------------------------------------------

## D-118: the slot's laser / flashlight is on (replicated; third-person views and stealth read it).
func gadget_on(ws: int) -> bool:
	return _gadget_on.get(ws, false)


## D-118: the toggleable gadgets of slot `ws` (subset of TOGGLE_GADGETS in its resolved stats).
func toggle_gadgets(ws: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var st: WeaponStats = stats(ws)
	if st != null:
		for g: StringName in st.gadgets:
			if TOGGLE_GADGETS.has(g) and not out.has(g):
				out.append(g)
	return out


## D-118 (authority): flip the equipped weapon's gadget if it has a laser or flashlight. Returns the new state.
func toggle_gadget() -> bool:
	if not Net.is_authority() or toggle_gadgets(equipped_slot).is_empty():
		return gadget_on(equipped_slot)
	_set_gadget(equipped_slot, not gadget_on(equipped_slot))
	return gadget_on(equipped_slot)


func _set_gadget(ws: int, on: bool) -> void:
	if gadget_on(ws) == on:
		return
	if on:
		_gadget_on[ws] = true
	else:
		_gadget_on.erase(ws)
	gadget_changed.emit(ws, on)


func _clear_gadgets() -> void:
	for ws: int in _gadget_on.keys():
		_set_gadget(ws, false)


## D-118 net state: bit (1 << ws) per slot whose gadget is on.
func gadget_bits() -> int:
	var b: int = 0
	for ws: int in _gadget_on.keys():
		b |= 1 << ws
	return b


## D-118 (client): apply the server's gadget_bits(); emits gadget_changed per slot that changed.
func apply_gadget_bits(b: int) -> void:
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		_set_gadget(ws, (b & (1 << ws)) != 0)


func has_weapon(ws: int) -> bool:
	return _states.has(ws)


func mag(ws: int) -> int:
	var s: WeaponState = _states.get(ws)
	return s.mag if s != null else 0


func reserve(ws: int) -> int:
	var s: WeaponState = _states.get(ws)
	return s.reserve if s != null else 0


func stats(ws: int) -> WeaponStats:
	var s: WeaponState = _states.get(ws)
	return s.stats if s != null else null


func weapon_id(ws: int) -> StringName:
	var s: WeaponState = _states.get(ws)
	return s.id if s != null else &""


## D-118: pellets per shot (WeaponStats.pellets under the shotgun ammo); client claims and server agree on it.
func pellet_count(ws: int) -> int:
	var s: WeaponState = _states.get(ws)
	return s.pellets if s != null else 1


## D-118: resolved shotgun ammo profile of slot `ws` (ShotgunAmmo.profile; {} without a weapon).
func ammo_profile(ws: int) -> Dictionary:
	var s: WeaponState = _states.get(ws)
	return s.ammo if s != null else {}


## L3.4 + D-118: rounds of slot `ws` pass thin walls (WeaponStats.wall_pierce, overridden by ammo penetration).
func wall_pierce(ws: int) -> bool:
	var s: WeaponState = _states.get(ws)
	return s.wall_pierce if s != null else false


## D-118: ammo box rounds multiplier of slot `ws` (shotgun ammo `ammo_pickup_mult`, 1 otherwise).
func ammo_pickup_mult(ws: int) -> float:
	var s: WeaponState = _states.get(ws)
	return float(s.ammo.get("ammo_pickup_mult", 1.0)) if s != null else 1.0


func is_suppressed(ws: int = -1) -> bool:
	var st: WeaponStats = stats(equipped_slot if ws < 0 else ws)
	return st != null and st.suppressed


## L2.5: a downed crew member "is shooting" if they fired within CombatTweak.downed_shooting_grace_s.
func is_shooting() -> bool:
	return last_shot_age <= CombatTweak.data().downed_shooting_grace_s


## S1.1 + crew state: may this crew member pull the trigger at all?
func can_fire() -> bool:
	if _crew == null or _crew.is_casing():
		return false
	if (_crew.melee != null and _crew.melee.state != &"") or (_crew.throwables != null and _crew.throwables.busy()):
		return false  # L3.9 / A3-12: no shooting mid-swing, while charging a melee or throwing
	var s: int = _crew.crew_state
	if s == Enums.CrewState.TASED:
		return involuntary_fire  # L4.4: only the involuntary trigger while tased
	return s == Enums.CrewState.NORMAL or s == Enums.CrewState.DOWNED or s == Enums.CrewState.SWAN_SONG



## Body damage of one bullet/pellet from weapon slot `ws` at `distance` (falloff x weapon.damage_mult
## qualified by the weapon class). Head multipliers are applied by the target (NpcBase, L3.3).
func damage_at(ws: int, distance: float) -> float:
	var s: WeaponState = _states.get(ws)
	if s == null:
		return 0.0
	var slot: int = _crew.slot if _crew != null else -1
	var ai: float = Tweak.crew().ai_damage_mult if _crew != null and _crew.is_ai else 1.0  # PO6-15: PD2 bots hit soft
	var rm: float = maxf(float(s.ammo.get("range_mult", 1.0)), 0.01)  # D-118: ammo range scales the falloff
	var per_pellet: float = float(maxi(s.stats.pellets, 1)) / float(maxi(s.pellets, 1))  # D-118: per-shot total kept
	rm *= Modifiers.mult(slot, &"weapon.falloff_range_mult", s.qualifier)  # B4a Long Barrel: falloff distances x value
	return s.stats.damage * per_pellet * CombatSystem.falloff_mult(s.stats, distance / rm) \
		* Modifiers.mult(slot, &"weapon.damage_mult", s.qualifier) * ai * SkillTriggers.berserk_mult(_crew, true)  # B1


## info.headshot_bonus (damage.md QB-26): WeaponStats.headshot_mult (bonus, default 1.0) x the
## weapon.headshot_mult modifier for this weapon class.
func headshot_bonus(ws: int) -> float:
	var s: WeaponState = _states.get(ws)
	if s == null:
		return 1.0
	var slot: int = _crew.slot if _crew != null else -1
	return s.stats.headshot_mult * Modifiers.mult(slot, &"weapon.headshot_mult", s.qualifier)


## A2-06 (DeployableSystem, server): the HUD's deployable id / count; synced to a remote owner.
func set_deployable(id: StringName, count: int) -> void:
	deployable_id = id
	deployable_count = count
	if Net.is_authority() and _crew != null and _remote_owned() and HeistNetSync.can_rpc(_crew):
		_rpc_deployable.rpc_id(_crew.peer_id, id, count)


@rpc("authority", "call_remote", "reliable")
func _rpc_deployable(id: StringName, count: int) -> void:
	deployable_id = id
	deployable_count = count


## Server/test hook: set a slot's magazine and reserve directly (clamped to >= 0, mag <= mag size).
func set_ammo(ws: int, p_mag: int, p_reserve: int) -> void:
	var s: WeaponState = _states.get(ws)
	if s == null:
		return
	s.mag = clampi(p_mag, 0, s.mag_size)
	s.reserve = maxi(p_reserve, 0)
	ammo_changed.emit(ws)
	_sync_ammo(ws)


func mag_size(ws: int) -> int:
	var s: WeaponState = _states.get(ws)
	return s.mag_size if s != null else 0


# --- Ticks ---------------------------------------------------------------------------------

## Authority: every physics tick for every crew member (CrewController._tick_server_actions).
func server_tick(intent: CrewIntent, delta: float) -> void:
	_server_clock += delta
	aiming = intent.aim
	_tick_timers(delta)
	_handle_controls(intent)
	if intent.gadget and not _prev_gadget:
		toggle_gadget()
	_prev_gadget = intent.gadget
	if involuntary_fire:
		_involuntary_tick(intent)  # A3-01a: the server pulls the trigger for every slot (L4.4)
	elif not _remote_owned():
		_try_fire(intent)
	_prev_fire = intent.fire
	_prev_reload = intent.reload


## Owning client of a remote human: predicted firing; claims go to the server.
func client_tick(intent: CrewIntent, delta: float) -> void:
	aiming = intent.aim
	_tick_timers(delta)
	_handle_controls(intent)
	_try_fire(intent)
	_prev_fire = intent.fire
	_prev_reload = intent.reload


func _tick_timers(delta: float) -> void:
	last_shot_age += delta
	if _cooldown > 0.0:
		_cooldown -= delta
	if _equip_left > 0.0:
		_equip_left -= delta
	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			_finish_reload()


func _handle_controls(intent: CrewIntent) -> void:
	if intent.weapon_slot >= 0 and intent.weapon_slot != equipped_slot:
		equip(intent.weapon_slot)
	if intent.reload and not _prev_reload:
		start_reload()


## Switch to `ws` if that slot holds a weapon (cancels a reload; equip_time_s before firing). `redraw` with
## ws == equipped_slot re-draws the same weapon without a slot change or equipped_changed: PD2
## PlayerCarry:_enter -> _start_action_equip on a bag pickup (the viewmodel draws on carried_bag_changed).
func equip(ws: int, redraw: bool = false) -> bool:
	if not _states.has(ws) or (ws == equipped_slot and not redraw):
		return false
	var mobile: bool = _crew.crew_state == Enums.CrewState.NORMAL or _crew.crew_state == Enums.CrewState.SWAN_SONG
	if not mobile and _crew.crew_state != Enums.CrewState.DOWNED:
		return false
	var changed: bool = ws != equipped_slot
	equipped_slot = ws
	reloading = false
	reload_left = 0.0
	_reset_special()
	_equip_left = _equip_time(_states[ws])
	if changed:
		equipped_changed.emit(ws)
	return true


func _equip_time(s: WeaponState) -> float:
	return s.stats.equip_time_s / maxf(Modifiers.mult(_crew.slot, &"weapon.swap_speed_mult", s.qualifier), 0.01)


## Start reloading the equipped weapon (tactical or empty time). Returns false if not possible.
func start_reload() -> bool:
	var s: WeaponState = _states.get(equipped_slot)
	if s == null or reloading or s.mag >= s.mag_size or s.reserve <= 0:
		return false
	var st: int = _crew.crew_state
	if st != Enums.CrewState.NORMAL and st != Enums.CrewState.DOWNED and st != Enums.CrewState.SWAN_SONG \
			and not (st == Enums.CrewState.TASED and involuntary_fire):
		return false
	var base: float = s.stats.reload_time_s if s.mag > 0 else s.stats.reload_empty_time_s
	reload_left = maxf(base, 0.0) / maxf(Modifiers.mult(_crew.slot, &"weapon.reload_speed_mult", s.qualifier), 0.01)
	reloading = true
	reload_started.emit(equipped_slot, reload_left)
	if reload_left <= 0.0:
		_finish_reload()
	return true


## Cancel the running reload of weapon slot `ws` (-1 = the equipped one), as a sprint start does in PD2 (P's
## CrewController). The rounds stay where they were (the magazine fills only when a reload finishes). It runs in the
## shared crew simulation, so the server and the owner's prediction cancel on the same tick, as the reload started
## (intent-driven, no RPC). Returns true when a reload was cancelled.
func cancel_reload(ws: int = -1) -> bool:
	if not reloading or (ws >= 0 and ws != equipped_slot):
		return false
	reloading = false
	reload_left = 0.0
	reload_cancelled.emit(equipped_slot)
	return true


func _finish_reload() -> void:
	reloading = false
	reload_left = 0.0
	var s: WeaponState = _states.get(equipped_slot)
	if s == null:
		return
	var take: int = mini(s.mag_size - s.mag, s.reserve)
	s.mag += take
	s.reserve -= take
	reload_finished.emit(equipped_slot)
	ammo_changed.emit(equipped_slot)
	_sync_ammo(equipped_slot)
	SkillTriggers.reload_done(_crew)  # B4b: "next reload" kill buffs are spent


func _try_fire(intent: CrewIntent) -> void:
	var s: WeaponState = _states.get(equipped_slot)
	if s != null and not s.special.is_empty() and not _special_gate(s, intent):
		return
	if not intent.fire:
		return
	if s == null or not can_fire() or _equip_left > 0.0:
		return
	var auto: bool = s.def != null and s.def.fire_modes.has(&"auto")
	var pressed: bool = not _prev_fire
	if not auto and not pressed:
		return  # semi / burst / pump / bolt: one shot per trigger press
	if reloading or _cooldown > 0.0:
		return
	if s.mag <= 0:
		if pressed:
			start_reload()  # PD2: dry trigger starts a reload
		return
	_fire_shot(s, intent)


func _fire_shot(s: WeaponState, intent: CrewIntent) -> void:
	var claim: Dictionary = _build_claim(s, intent)
	var interval: float = _shot_interval(s)
	_cooldown = maxf(_cooldown, -get_physics_process_delta_time()) + interval
	_apply_recoil(s)
	fired.emit(claim)
	if Net.is_authority():
		CombatSystem.validate_and_apply(claim, _crew)
	else:
		if not CrewBuffs.free_ammo(_crew):  # B1: Swan Song Aced / Bulletstorm (mirrored CrewBuffs tag)
			s.mag -= 1
		shots_fired += 1
		last_shot_age = 0.0
		ammo_changed.emit(equipped_slot)
		_rpc_hit_claim.rpc_id(1, _strip_objects(claim))


## B4-18 (SpecialWeapons): bow draw / minigun spin / saw contact before the normal trigger logic.
## Returns true when the normal fire path should run this tick.
func _special_gate(s: WeaponState, intent: CrewIntent) -> bool:
	var dt: float = get_physics_process_delta_time()
	var ready: bool = can_fire() and _equip_left <= 0.0 and not reloading
	var sp: Dictionary = SpecialWeapons.block(s.special, "spin")
	if not sp.is_empty():
		var up: bool = intent.fire and ready and s.mag > 0
		var rate: float = 1.0 / maxf(float(sp.get("spin_up_s" if up else "spin_down_s", 0.5)), 0.01)
		if up != _spinning_up and (up or spin > 0.0):
			_cue(s, "spin_up" if up else "spin_down")
		_spinning_up = up
		spin = clampf(spin + (rate if up else -rate) * dt, 0.0, 1.0)
		move_speed_mult = float(sp.get("move_speed_mult", 1.0)) if spin > 0.0 else 1.0
		if spin < 1.0 and s.mag > 0:
			return false
	if s.def != null and s.def.fire_modes.has(&"charge"):
		return _charge_gate(s, intent, ready, dt)
	if s.kind == SpecialWeapons.KIND_SAW and intent.fire and not _prev_fire:
		_cue(s, "rev")
	if s.kind == SpecialWeapons.KIND_FLAME:
		var on: bool = intent.fire and ready and s.mag > 0
		if on != _spinning_up:
			_cue(s, "ignite" if on else "stop")
		_spinning_up = on  # flamethrowers have no spin: the flag tracks the flame instead
	if s.kind == SpecialWeapons.KIND_SAW and intent.fire and s.mag > 0:
		return SpecialWeapons.saw_has_contact(_crew, _crew.eye_position(), _crew.aim_direction(), s.special)
	return true


func _cue(s: WeaponState, suffix: String) -> void:
	SpecialWeapons.cue(s.def, suffix, _crew.global_position + Vector3(0.0, 1.4, 0.0), _crew.net_id)


## Bow: hold to draw (charge 0..1 over draw_time_s), release to loose at the reached draw.
func _charge_gate(s: WeaponState, intent: CrewIntent, ready: bool, dt: float) -> bool:
	if s.mag <= 0:
		charge = 0.0
		return true  # dry trigger -> reload via the normal path
	if intent.fire and ready:
		if not _drawing:
			_cue(s, "draw")
		var draw: float = SpecialWeapons.draw_time(s.special)
		charge = 1.0 if draw <= 0.0 else minf(charge + dt / draw, 1.0)
		_drawing = true
		return false
	if _drawing and not intent.fire and ready and _cooldown <= 0.0:
		_fire_shot(s, intent)
	if not intent.fire:
		_drawing = false
		charge = 0.0
	return false


func _reset_special() -> void:
	charge = 0.0
	spin = 0.0
	move_speed_mult = 1.0
	_drawing = false
	_spinning_up = false


## A3-01a (L4.4): tased auto-fire (server): max RPM regardless of fire mode, auto-reload when empty.
func _involuntary_tick(intent: CrewIntent) -> void:
	var s: WeaponState = _states.get(equipped_slot)
	if s == null or not can_fire() or _equip_left > 0.0 or reloading:
		return
	if s.mag <= 0:
		start_reload()
		return
	if _cooldown > 0.0:
		return
	var keep_seq: int = _last_server_seq
	_seq = maxi(_seq, _last_server_seq)
	var claim: Dictionary = _build_claim(s, intent)
	_cooldown = maxf(_cooldown, -get_physics_process_delta_time()) + _shot_interval(s)
	fired.emit(claim)
	CombatSystem.validate_and_apply(claim, _crew)
	if _remote_owned():
		_last_server_seq = keep_seq  # the owning client's claim sequence continues untouched


# --- Hitscan ---------------------------------------------------------------------------------

func _build_claim(s: WeaponState, intent: CrewIntent) -> Dictionary:
	_seq += 1
	var tw: CombatTweak = CombatTweak.data()
	var origin: Vector3 = _crew.eye_position()
	var fwd: Vector3 = _crew.aim_direction()
	if involuntary_fire and involuntary_pitch_up_deg != 0.0:
		var right: Vector3 = fwd.cross(Vector3.UP)
		if right.length() > 0.001:
			fwd = fwd.rotated(right.normalized(), deg_to_rad(involuntary_pitch_up_deg)).normalized()
	var hits: Array[Dictionary] = []
	var spread: float = _spread_deg(s, intent) * (involuntary_spread_mult if involuntary_fire else 1.0)
	# PO-8: one seed per shot drives every pellet (no RNG draw without spread, as before).
	var pellet_seed: int = GameRng.stream(&"spread").randi() if spread > 0.0001 else 0
	_pellet_rng.seed = pellet_seed
	var fx: bool = ShotFx.enabled()
	var fx_origin: Vector3 = _fx_origin() if fx else origin
	var fx_flags: int = _fx_flags(s)
	var cls: StringName = ShotFx.weapon_class_id(s.def)
	var max_range: float = tw.hitscan_max_range_m
	# B4-18: flame / saw / projectile shots carry no hits (the server derives them).
	for p: int in range(s.pellets if s.kind == SpecialWeapons.KIND_HITSCAN else 0):  # D-118: ammo pellets
		var dir: Vector3 = _spread_dir(fwd, spread, _pellet_rng)
		var h: Dictionary = _hitscan(origin, dir, tw, s.wall_pierce)
		if not h.is_empty():
			hits.append(h)
		if fx:
			ShotFx.emit_ray(fx_origin, _ray_hit, origin + dir * max_range, cls, _crew.net_id,
				fx_flags | (ShotFx.FLAG_PENETRATED if _ray_walls > 0 else 0))
	return {
		"seq": _seq, "weapon_slot": equipped_slot, "weapon_id": s.id, "origin": origin, "direction": fwd,
		"muzzle": _muzzle_position(), "hits": hits, "charge": charge if _drawing else 1.0,
		"spread": spread, "fx_seed": pellet_seed,
	}


## PO-8: shot_fx origin on this peer: the first-person muzzle for the local human (ENV P draws its own
## flash/tracer from the viewmodel), else the third-person weapon's `Muzzle`, else the eye.
func _fx_origin() -> Vector3:
	if _crew.is_local():
		var fx_muzzle: Node3D = _fp_fx_muzzle()
		return fx_muzzle.global_position if fx_muzzle != null else _muzzle_position()
	return ShotFx.tp_muzzle(_crew, _crew.eye_position())


## ENV P: FpViewmodel.fx_muzzle() is the Muzzle of the gun that fires the NEXT shot (akimbo alternates right then
## left; valid before `fired`), null without one. Duck-typed: the viewmodel is a child of the crew camera.
func _fp_fx_muzzle() -> Node3D:
	var view: CrewView = CrewView.of(_crew)
	var cam: Camera3D = view.camera() if view != null else null
	var vm: Node = cam.get_node_or_null(^"FpViewmodel") if cam != null else null
	if vm == null or not vm.has_method(&"fx_muzzle"):
		return null
	var m: Node3D = vm.call(&"fx_muzzle") as Node3D
	return m if m != null and m.is_inside_tree() else null


func _fx_flags(s: WeaponState) -> int:
	var f: int = ShotFx.FLAG_SUPPRESSED if s.stats != null and s.stats.suppressed else 0
	if _crew.is_local():
		f |= ShotFx.FLAG_FIRST_PERSON
	if s.stats != null and s.stats.damage >= CombatTweak.data().fx_strong_damage:
		f |= ShotFx.FLAG_STRONG  # D-113 (kept only on flesh hits by ShotFx.flesh_flags)
	if s.stats != null and s.wall_pierce:
		f |= ShotFx.FLAG_PENETRATED  # AP rounds exit the body (flesh only, as above)
	return f


## PO-8, every peer that did not simulate the shot: replay a relayed crew shot (net hook called by
## HeistNetSync._rpc_crew_shot on clients; server_commit_shot for a remote client's claim on the host):
## the same seeded pellets, raycast against this peer's world, one shot_fx each. No gameplay effect.
func _fx_replay(origin: Vector3, dir: Vector3, spread_deg: float, pellet_seed: int, ws: int) -> void:
	var s: WeaponState = _states.get(ws)
	if s == null or s.stats == null or s.kind != SpecialWeapons.KIND_HITSCAN or _crew == null \
			or not _crew.is_inside_tree() or not ShotFx.enabled():
		return
	var tw: CombatTweak = CombatTweak.data()
	var fwd: Vector3 = dir.normalized() if dir.length() > 0.0001 else _crew.aim_direction()
	_pellet_rng.seed = pellet_seed
	var fx_origin: Vector3 = _fx_origin()
	var fx_flags: int = _fx_flags(s)
	var cls: StringName = ShotFx.weapon_class_id(s.def)
	for p: int in range(s.pellets):
		var d: Vector3 = _spread_dir(fwd, clampf(spread_deg, 0.0, tw.fx_max_replay_spread_deg), _pellet_rng)
		_hitscan(origin, d, tw, s.wall_pierce)
		ShotFx.emit_ray(fx_origin, _ray_hit, origin + d * tw.hitscan_max_range_m, cls, _crew.net_id,
			fx_flags | (ShotFx.FLAG_PENETRATED if _ray_walls > 0 else 0))


## Tracer / flash / noise origin: the outermost `Muzzle` marker of the crew's weapon visual
## (visual_slots.md: WeaponVisual.get_marker(&"Muzzle")) when one is attached, else the eye.
func _muzzle_position() -> Vector3:
	var wv: Variant = _crew.get(&"weapon_visual")
	var vis: Object = wv as Object if wv is Object else null
	if vis != null and is_instance_valid(vis) and vis.has_method(&"get_marker"):
		var m: Node3D = vis.call(&"get_marker", &"Muzzle") as Node3D
		if m != null and m.is_inside_tree():
			return m.global_position
	return _crew.eye_position()


## A claim without object references (RPC-safe); the server resolves targets by id or re-raycast.
static func _strip_objects(claim: Dictionary) -> Dictionary:
	var c: Dictionary = claim.duplicate(true)
	var hits: Array = []
	for h: Variant in claim.get("hits", []):
		var d: Dictionary = (h as Dictionary).duplicate()
		d.erase("target")
		hits.append(d)
	c["hits"] = hits
	return c


func _spread_deg(s: WeaponState, intent: CrewIntent) -> float:
	var tw: CombatTweak = CombatTweak.data()
	var base: float = s.stats.spread_deg_ads * tw.ads_spread_mult if intent.aim else s.stats.spread_deg_hip  # D-131
	var hv: float = Vector2(_crew.velocity.x, _crew.velocity.z).length()
	var mult: float = tw.spread_mult_still
	var moving: bool = hv > tw.moving_speed_threshold
	if _crew.crouched:
		mult = tw.spread_mult_crouched  # D-097: PD2 crouching row (moving or not)
	elif moving:
		mult = tw.spread_mult_moving
	var q: StringName = s.qualifier
	var skill: float = Modifiers.mult(_crew.slot, &"weapon.moving_spread_mult" if moving else &"weapon.still_spread_mult", q)
	if not intent.aim:
		skill *= Modifiers.mult(_crew.slot, &"weapon.hip_spread_mult", q)  # B4a Hip Discipline / Steady Aim / Snap Shot
	return maxf(base * mult * skill * Modifiers.mult(_crew.slot, &"weapon.spread_mult", q), 0.0)


## Direction inside a cone of half-angle `deg` around `fwd` (`rng`, default GameRng &"spread"; shots use the
## per-shot seeded pellet RNG, PO-8). D-097 (PD2): the radius is uniform in [0, max] (not area-uniform), so
## shots cluster toward the centre as in PD2.
func _spread_dir(fwd: Vector3, deg: float, rng: RandomNumberGenerator = null) -> Vector3:
	if deg <= 0.0001:
		return fwd
	if rng == null:
		rng = GameRng.stream(&"spread")
	var r: float = tan(deg_to_rad(deg)) * rng.randf()
	var phi: float = rng.randf() * TAU
	var right: Vector3 = fwd.cross(Vector3.UP)
	if right.length() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up: Vector3 = right.cross(fwd).normalized()
	return (fwd + right * (r * cos(phi)) + up * (r * sin(phi))).normalized()


## First thing the ray hits (world or hitbox). Returns a claim hit entry, or {} for a miss/world hit.
## A3-06 (L3.4): thin walls (CombatTweak.penetrable_mask) stop the ray unless `wall_pierce`, then up to
## wall_pierce_max of them are passed (the server applies wall_pierce_damage_mult).
func _hitscan(origin: Vector3, dir: Vector3, tw: CombatTweak, wall_pierce: bool = false) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + dir * tw.hitscan_max_range_m, tw.hitscan_mask | tw.penetrable_mask)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var ex: Array[RID] = [_crew.get_rid()]
	q.exclude = ex
	var hit: Dictionary = _crew.get_world_3d().direct_space_state.intersect_ray(q)
	var walls: int = 0
	while not hit.is_empty() and _is_penetrable(hit.get("collider")):
		walls += 1
		if not wall_pierce or walls > tw.wall_pierce_max:
			_ray_hit = hit  # PO-8: the ray stops at this wall
			_ray_walls = walls - 1
			return {}
		ex.append(hit.get("rid") as RID)
		q.exclude = ex
		hit = _crew.get_world_3d().direct_space_state.intersect_ray(q)
	_ray_hit = hit
	_ray_walls = walls
	if hit.is_empty():
		return {}
	var col: Object = hit.get("collider")
	var target: Object = CombatSystem.resolve_collider(col)
	if target == null or target == _crew:
		return {}
	var pos: Vector3 = hit.get("position", origin)
	var rec: Dictionary = {
		"target_id": NetIds.of(target as Node), "target": target, "zone": Damage.zone_of(col),
		"distance": origin.distance_to(pos), "position": pos,
	}
	var limb: StringName = NpcLimbHitboxes.limb_at(col, pos, dir, _crew.get_world_3d().direct_space_state)
	if limb != &"":
		rec["limb"] = limb  # D-123: flinch sub-zone only (the zone stays BODY)
	return rec


static func _is_penetrable(collider: Variant) -> bool:
	var co: CollisionObject3D = collider as CollisionObject3D if collider is CollisionObject3D else null
	return co != null and (co.collision_layer & CombatTweak.data().penetrable_mask) != 0 \
		and (co.collision_layer & CombatTweak.data().hitscan_mask) == 0


func _apply_recoil(s: WeaponState) -> void:
	# Humans only: the kick goes into the local PlayerInput's look accumulators (AI/bots ignore it).
	if _crew.is_ai or not _crew.is_local():
		return
	var pin: Node = _crew.get_node_or_null("PlayerInput")
	if pin == null:
		return
	var rm: float = Modifiers.mult(_crew.slot, &"weapon.recoil_mult", s.qualifier)
	var kick: float = deg_to_rad(s.stats.recoil_kick_deg * rm)
	var h: float = s.stats.recoil_horizontal_deg * rm
	# D-099: + bias = mean drift to the right; look yaw grows to the LEFT, hence the minus.
	var bias: float = s.stats.recoil_horizontal_bias_deg * rm
	var side: float = deg_to_rad(GameRng.stream(&"recoil").randf_range(-h, h) - bias)
	if pin.has_method(&"add_recoil"):
		pin.call(&"add_recoil", kick, side)
		return
	var p: Variant = pin.get(&"_pitch")
	var y: Variant = pin.get(&"_yaw")
	if p is float and y is float:
		pin.set(&"_pitch", clampf(float(p) + kick, -deg_to_rad(89.0), deg_to_rad(89.0)))
		pin.set(&"_yaw", float(y) + side)


# --- Server validation (called by CombatSystem) -------------------------------------------------

## Server: why `claim` cannot be a real shot now (&"" = fine). Does not mutate state.
func server_check_shot(claim: Dictionary) -> StringName:
	var ws: int = int(claim.get("weapon_slot", -1))
	var s: WeaponState = _states.get(ws)
	if not can_fire():
		return &"cannot_fire"
	if int(claim.get("seq", 0)) <= _last_server_seq:
		return &"stale_seq"
	if s == null or ws != equipped_slot or StringName(claim.get("weapon_id", &"")) != s.id:
		return &"weapon"
	return _check_timing_and_origin(s, claim)


## Seconds between shots: 60 / rpm / weapon.fire_rate_mult (A4-04; higher mult = faster).
func _shot_interval(s: WeaponState) -> float:
	var m: float = Modifiers.mult(_crew.slot, &"weapon.fire_rate_mult", s.qualifier) if _crew != null else 1.0
	if _crew != null and not aiming:
		m *= Modifiers.mult(_crew.slot, &"weapon.hip_fire_rate_mult", s.qualifier)  # B4a Hip Fire
	return 60.0 / maxf(s.stats.fire_rate_rpm * maxf(m, 0.01), 1.0)


func _check_timing_and_origin(s: WeaponState, claim: Dictionary) -> StringName:
	var tw: CombatTweak = CombatTweak.data()
	var remote: bool = _remote_owned()
	var interval: float = _shot_interval(s)
	var origin: Variant = claim.get("origin")
	var reason: StringName = &""
	if reloading and not remote:
		reason = &"reloading"
	elif _server_clock - _last_server_shot_clock < interval * tw.claim_rof_tolerance:
		reason = &"rate"
	elif s.mag <= 0 and not (remote and reloading and s.reserve > 0):
		reason = &"ammo"
	elif not origin is Vector3 or (origin as Vector3).distance_to(_crew.eye_position()) > tw.claim_origin_tolerance_m:
		reason = &"origin"
	return reason


## Server: consume the round and publish the shot (weapon_fired, S4.3 noise). After server_check_shot.
func server_commit_shot(claim: Dictionary) -> void:
	if reloading and _remote_owned():
		_finish_reload()  # the owning client finished its reload before our mirrored timer did
	var ws: int = int(claim.get("weapon_slot", equipped_slot))
	var s: WeaponState = _states[ws]
	if s.def != null and s.def.fire_modes.has(&"charge"):  # B4-18: no fuller draw than the time since the last shot
		var draw: float = SpecialWeapons.draw_time(s.special)
		var cap: float = 1.0 if draw <= 0.0 else (_server_clock - _last_server_shot_clock) / (draw * CombatTweak.data().claim_rof_tolerance)
		claim["charge"] = clampf(float(claim.get("charge", 1.0)), 0.0, minf(cap, 1.0))
	if not CrewBuffs.free_ammo(_crew):  # B1: Swan Song Aced / Bulletstorm
		s.mag -= 1
	_last_server_seq = int(claim.get("seq", 0))
	_last_server_shot_clock = _server_clock
	last_shot_age = 0.0
	shots_fired += 1
	var origin: Vector3 = claim.get("muzzle", claim.get("origin", _crew.eye_position()))
	EventBus.weapon_fired.emit(_crew.net_id, s.id, s.stats.suppressed, origin)
	var radius: float = s.stats.noise_radius_m if s.stats.suppressed else Tweak.stealth().gunshot_player_radius_m
	var rt: HeistRuntime = HeistRuntime.of(_crew)
	if rt != null and radius > 0.0:
		# D-121: the server's gunshot noise starts at the shooter's eye (deterministic), not the claim's animated muzzle.
		rt.make_noise(_crew.eye_position(), radius, &"gunshot", _crew.net_id)
	ammo_changed.emit(ws)
	_sync_ammo(ws)
	_commit_shot_fx(claim, s, ws)


## PO-8: presentation of an accepted gun shot on the peers that did not simulate it. A remote client's
## claim (`_remote`) is replayed here on the host and relayed to every other client; a shot simulated on
## the host (host human, AI bots, tased auto-fire) was presented in _build_claim and goes to all clients.
func _commit_shot_fx(claim: Dictionary, s: WeaponState, ws: int) -> void:
	var seed_v: Variant = claim.get("fx_seed")
	var spread_v: Variant = claim.get("spread", 0.0)
	if s.kind != SpecialWeapons.KIND_HITSCAN or not seed_v is int or not (spread_v is float or spread_v is int):
		return  # also drops a malformed client claim (presentation only)
	var o_v: Variant = claim.get("origin")
	var d_v: Variant = claim.get("direction")
	var origin: Vector3 = o_v as Vector3 if o_v is Vector3 else _crew.eye_position()
	var dir: Vector3 = d_v as Vector3 if d_v is Vector3 else _crew.aim_direction()
	var spread: float = float(spread_v)
	var pellet_seed: int = int(seed_v)
	var remote: bool = bool(claim.get(REMOTE_CLAIM_KEY, false))
	if remote:
		_fx_replay(origin, dir, spread, pellet_seed, ws)
	var rt: HeistRuntime = HeistRuntime.of(_crew)
	if rt != null and rt.net_sync != null:
		rt.net_sync.relay_crew_shot(_crew.net_id, origin, dir, spread, pellet_seed, ws, _crew.peer_id if remote else 0)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hit_claim(claim: Dictionary) -> void:
	if not Net.is_authority() or _crew == null:
		return
	if multiplayer.get_remote_sender_id() != _crew.peer_id:
		Log.warn(&"net", "hit claim for slot %d from wrong peer %d" % [_crew.slot, multiplayer.get_remote_sender_id()])
		return
	claim[REMOTE_CLAIM_KEY] = true  # PO-8: presented on the owning client already (set here, never trusted)
	var res: Dictionary = CombatSystem.validate_and_apply(claim, _crew)
	if not bool(res["accepted"]):
		_sync_ammo(int(claim.get("weapon_slot", equipped_slot)))


func _sync_ammo(ws: int) -> void:
	if not Net.is_authority() or _crew == null or not _remote_owned() or not HeistNetSync.can_rpc(_crew):
		return
	_rpc_ammo.rpc_id(_crew.peer_id, ws, mag(ws), reserve(ws))


@rpc("authority", "call_remote", "reliable")
func _rpc_ammo(ws: int, p_mag: int, p_reserve: int) -> void:
	var s: WeaponState = _states.get(ws)
	if s == null:
		return
	s.mag = p_mag
	s.reserve = p_reserve
	ammo_changed.emit(ws)


## A human on another peer drives this slot: the server only validates its hit claims.
func _remote_owned() -> bool:
	return not _crew.is_ai and _crew.peer_id != 0 and _crew.peer_id != Net.local_peer_id()


func _on_crew_state_changed(_old: int, new_state: int) -> void:
	if new_state != Enums.CrewState.TASED:
		involuntary_fire = false
	# PD2: a downed crew member fights with the secondary weapon (L2.5).
	if new_state == Enums.CrewState.DOWNED and _states.has(Enums.WeaponSlot.SECONDARY):
		equip(Enums.WeaponSlot.SECONDARY)
	if new_state != Enums.CrewState.NORMAL and new_state != Enums.CrewState.DOWNED \
			and new_state != Enums.CrewState.SWAN_SONG:
		reloading = false
		reload_left = 0.0
