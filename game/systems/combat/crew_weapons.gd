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
signal equipped_changed(weapon_slot: int)
signal ammo_changed(weapon_slot: int)

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
var involuntary_pitch_up_deg: float = 0.0

var _crew: CrewController = null
var _states: Dictionary[int, WeaponState] = {}
var _cooldown: float = 0.0
var _equip_left: float = 0.0
var _prev_fire: bool = false
var _prev_reload: bool = false
var _seq: int = 0
var _server_clock: float = 0.0
var _last_server_shot_clock: float = -INF
var _last_server_seq: int = 0


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
	if l != null:
		deployable_id = l.deployable  # A2-06: HUD fallback until DeployableSystem syncs
		_add_state(Enums.WeaponSlot.PRIMARY, l.primary, l.resolved_primary)
		_add_state(Enums.WeaponSlot.SECONDARY, l.secondary, l.resolved_secondary)
	equipped_slot = Enums.WeaponSlot.PRIMARY if _states.has(Enums.WeaponSlot.PRIMARY) else Enums.WeaponSlot.SECONDARY
	reloading = false
	_equip_left = 0.0
	_cooldown = 0.0


func _add_state(ws: int, id: StringName, st: WeaponStats) -> void:
	if id == &"" or st == null:
		return
	var s: WeaponState = WeaponState.new()
	s.id = id
	s.def = ContentDB.weapon(id)
	s.stats = st
	s.qualifier = Enums.weapon_class_qualifier(s.def.weapon_class) if s.def != null else &"pistol"
	var slot: int = _crew.slot if _crew != null else -1
	s.mag_size = maxi(st.mag_size + int(Modifiers.add(slot, &"weapon.mag_extra", s.qualifier)), 1)
	var total: int = int(round(float(st.total_ammo) * Modifiers.mult(slot, &"weapon.ammo_total_mult", s.qualifier)))
	s.mag = s.mag_size
	s.reserve = maxi(total - s.mag_size, 0)
	_states[ws] = s


# --- Queries (HUD + other systems) ----------------------------------------------------------

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
	return s.stats.damage * CombatSystem.falloff_mult(s.stats, distance) \
		* Modifiers.mult(slot, &"weapon.damage_mult", s.qualifier)


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
	_tick_timers(delta)
	_handle_controls(intent)
	if involuntary_fire:
		_involuntary_tick(intent)  # A3-01a: the server pulls the trigger for every slot (L4.4)
	elif not _remote_owned():
		_try_fire(intent)
	_prev_fire = intent.fire
	_prev_reload = intent.reload


## Owning client of a remote human: predicted firing; claims go to the server.
func client_tick(intent: CrewIntent, delta: float) -> void:
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


## Switch to `ws` if that slot holds a weapon (cancels a reload; equip_time_s before firing).
func equip(ws: int) -> bool:
	if not _states.has(ws) or ws == equipped_slot:
		return false
	var mobile: bool = _crew.crew_state == Enums.CrewState.NORMAL or _crew.crew_state == Enums.CrewState.SWAN_SONG
	if not mobile and _crew.crew_state != Enums.CrewState.DOWNED:
		return false
	equipped_slot = ws
	reloading = false
	reload_left = 0.0
	var s: WeaponState = _states[ws]
	_equip_left = s.stats.equip_time_s / maxf(Modifiers.mult(_crew.slot, &"weapon.swap_speed_mult", s.qualifier), 0.01)
	equipped_changed.emit(ws)
	return true


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


func _try_fire(intent: CrewIntent) -> void:
	if not intent.fire:
		return
	var s: WeaponState = _states.get(equipped_slot)
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
	var claim: Dictionary = _build_claim(s, intent)
	var interval: float = 60.0 / maxf(s.stats.fire_rate_rpm, 1.0)
	_cooldown = maxf(_cooldown, -get_physics_process_delta_time()) + interval
	_apply_recoil(s)
	fired.emit(claim)
	if Net.is_authority():
		CombatSystem.validate_and_apply(claim, _crew)
	else:
		s.mag -= 1
		shots_fired += 1
		last_shot_age = 0.0
		ammo_changed.emit(equipped_slot)
		_rpc_hit_claim.rpc_id(1, _strip_objects(claim))


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
	_cooldown = maxf(_cooldown, -get_physics_process_delta_time()) + 60.0 / maxf(s.stats.fire_rate_rpm, 1.0)
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
	for p: int in range(maxi(s.stats.pellets, 1)):
		var dir: Vector3 = _spread_dir(fwd, _spread_deg(s, intent) * (involuntary_spread_mult if involuntary_fire else 1.0))
		var h: Dictionary = _hitscan(origin, dir, tw, s.stats.wall_pierce)
		if not h.is_empty():
			hits.append(h)
	return {
		"seq": _seq, "weapon_slot": equipped_slot, "weapon_id": s.id, "origin": origin, "direction": fwd,
		"muzzle": _muzzle_position(), "hits": hits,
	}


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
	var base: float = s.stats.spread_deg_ads if intent.aim else s.stats.spread_deg_hip
	var hv: float = Vector2(_crew.velocity.x, _crew.velocity.z).length()
	var mult: float = tw.spread_mult_still
	if hv > tw.moving_speed_threshold:
		mult = tw.spread_mult_moving
	elif _crew.crouched:
		mult = tw.spread_mult_crouched
	return maxf(base * mult * Modifiers.mult(_crew.slot, &"weapon.spread_mult", s.qualifier), 0.0)


## Uniform direction inside a cone of half-angle `deg` around `fwd` (GameRng &"spread").
func _spread_dir(fwd: Vector3, deg: float) -> Vector3:
	if deg <= 0.0001:
		return fwd
	var rng: RandomNumberGenerator = GameRng.stream(&"spread")
	var r: float = tan(deg_to_rad(deg)) * sqrt(rng.randf())
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
			return {}
		ex.append(hit.get("rid") as RID)
		q.exclude = ex
		hit = _crew.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var col: Object = hit.get("collider")
	var target: Object = CombatSystem.resolve_collider(col)
	if target == null or target == _crew:
		return {}
	var pos: Vector3 = hit.get("position", origin)
	return {
		"target_id": NetIds.of(target as Node), "target": target, "zone": Damage.zone_of(col),
		"distance": origin.distance_to(pos), "position": pos,
	}


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
	var side: float = deg_to_rad(GameRng.stream(&"recoil").randf_range(-h, h))
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


func _check_timing_and_origin(s: WeaponState, claim: Dictionary) -> StringName:
	var tw: CombatTweak = CombatTweak.data()
	var remote: bool = _remote_owned()
	var interval: float = 60.0 / maxf(s.stats.fire_rate_rpm, 1.0)
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
		rt.make_noise(origin, radius, &"gunshot", _crew.net_id)
	ammo_changed.emit(ws)
	_sync_ammo(ws)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hit_claim(claim: Dictionary) -> void:
	if not Net.is_authority() or _crew == null:
		return
	if multiplayer.get_remote_sender_id() != _crew.peer_id:
		Log.warn(&"net", "hit claim for slot %d from wrong peer %d" % [_crew.slot, multiplayer.get_remote_sender_id()])
		return
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
