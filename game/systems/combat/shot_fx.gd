## PO-8 (D-105, docs/contracts/impact_fx.md 1.0 §1-§2): local presentation of shots, melee hits and
## explosions. Owner: ENV A. Presentation only: nothing here feeds gameplay.
## Every peer emits `EventBus.shot_fx` once per hitscan ray / pellet / melee hit and `EventBus.explosion_fx`
## once per blast, locally, from the shot replication below (never per pellet on the wire):
## - crew guns: CrewWeapons emits on the peer that simulates the shot (its real pellets), the server
##   relays one compact fact per accepted shot (HeistNetSync._rpc_crew_shot: eye origin, aim direction,
##   spread, pellet seed, weapon slot) and every other peer re-runs the same seeded spread and raycasts
##   its own world (CrewWeapons._fx_replay);
## - NPC guns and crew melee: the server emits and relays one fact per shot / strike
##   (HeistNetSync._rpc_impact_fx: shooter, from, to, target, mode); peers raycast misses locally;
## - explosions: Explosion.apply (C4, breach charges, frags, launchers, trip mines) and concussion
##   grenades call `explosion()` (server), relayed with HeistNetSync._rpc_explosion_fx.
## There is no dedicated (render-less) server mode today, so every peer emits (listen-server hosts too).
class_name ShotFx
extends RefCounted

## shot_fx flags. Mirror EventBus.SHOT_FX_SUPPRESSED / _FIRST_PERSON / _HEADSHOT / _PENETRATED (events 1.2).
const FLAG_SUPPRESSED: int = EventBus.SHOT_FX_SUPPRESSED
const FLAG_FIRST_PERSON: int = EventBus.SHOT_FX_FIRST_PERSON
const FLAG_HEADSHOT: int = EventBus.SHOT_FX_HEADSHOT
const FLAG_PENETRATED: int = EventBus.SHOT_FX_PENETRATED
## D-113 (ENV C's VfxDirector): a heavy flesh hit (shotgun / sniper / LMG class, or a round of at least
## CombatTweak.fx_strong_damage).
const FLAG_STRONG: int = EventBus.SHOT_FX_STRONG
## D-113: weapon classes whose flesh hits are STRONG, and those whose rounds exit the body (PENETRATED).
const STRONG_CLASSES: Array[StringName] = [&"shotgun", &"sniper", &"lmg"]
const EXIT_CLASSES: Array[StringName] = [&"sniper"]

const CLASS_MELEE: StringName = &"melee"
const SURFACE_FLESH: StringName = &"flesh"
const SURFACE_ARMOR: StringName = &"armor"
const SURFACE_META: StringName = &"surface"

## _rpc_impact_fx modes.
const MODE_SHOT_MISS: int = 0
const MODE_SHOT_HIT: int = 1
const MODE_MELEE: int = 2

const RNG_STREAM: StringName = &"shot_fx"

const ANIM_DRIVER_NODE: NodePath = ^"AnimDriver"
const MUZZLE_MARKER: StringName = &"Muzzle"


## True when this process presents effects (no dedicated server mode exists yet: always true).
static func enabled() -> bool:
	return true


## impact_fx.md §1 surface of a hit collider: ENV C's ImpactFx.surface_of (metadata / shield / hitbox /
## character / concrete), plus Wrecker armour plates -> armor. Null (a miss) -> &"".
static func surface_of(collider: Object) -> StringName:
	if collider == null or not is_instance_valid(collider):
		return &""
	var hb: Hitbox = collider as Hitbox
	if hb != null and hb.get_damage_target() is WreckerArmor:
		return SURFACE_ARMOR  # Wrecker armour plates that are not WEAKPOINT zones
	return ImpactFx.surface_of(collider)  # ENV C's impact_fx.md §1 lookup (metadata, shield, hitbox, character)


## shot_fx weapon class of a crew weapon (Enums.WeaponClass -> &"pistol", &"smg", &"ar", &"shotgun",
## &"lmg", &"sniper", &"special", &"melee").
static func weapon_class_id(def: WeaponDef) -> StringName:
	if def == null:
		return &"pistol"
	match def.weapon_class:
		Enums.WeaponClass.PISTOL:
			return &"pistol"
		Enums.WeaponClass.SMG:
			return &"smg"
		Enums.WeaponClass.ASSAULT_RIFLE:
			return &"ar"
		Enums.WeaponClass.SHOTGUN:
			return &"shotgun"
		Enums.WeaponClass.LMG:
			return &"lmg"
		Enums.WeaponClass.SNIPER:
			return &"sniper"
		Enums.WeaponClass.MELEE:
			return CLASS_MELEE
	return &"special"


## shot_fx weapon class of an NPC weapon id (EnemyDef.weapon, e.g. &"weapon.npc_rifle"): nearest crew class.
static func npc_weapon_class(weapon_id: StringName) -> StringName:
	if weapon_id != &"" and ContentDB.has(ContentDB.WEAPONS, weapon_id):
		return weapon_class_id(ContentDB.weapon(weapon_id))
	var s: String = String(weapon_id)
	if s.contains("melee"):
		return CLASS_MELEE
	if s.contains("shotgun"):
		return &"shotgun"
	if s.contains("sniper"):
		return &"sniper"
	if s.contains("lmg") or s.contains("minigun"):
		return &"lmg"
	if s.contains("smg"):
		return &"smg"
	if s.contains("pistol"):
		return &"pistol"
	return &"ar"


## Third-person muzzle of `body` (crew or NPC): the `Muzzle` marker of the AnimDriver's WeaponVisual
## (visual_slots.md; mods override it, e.g. a suppressor), else `fallback` (the eye).
static func tp_muzzle(body: Node, fallback: Vector3) -> Vector3:
	if body == null or not is_instance_valid(body):
		return fallback
	var ad: AnimDriver = body.get_node_or_null(ANIM_DRIVER_NODE) as AnimDriver
	if ad == null or ad.weapon_visual == null or not is_instance_valid(ad.weapon_visual):
		return fallback
	if not ad.weapon_visual.has_method(&"get_marker"):
		return fallback
	var m: Node3D = ad.weapon_visual.call(&"get_marker", MUZZLE_MARKER) as Node3D
	if m != null and m.is_inside_tree():
		return m.global_position
	return fallback


## Emit one shot_fx for a ray result (`hit` = an intersect_ray dictionary, {} = miss at `max_end`).
static func emit_ray(origin: Vector3, hit: Dictionary, max_end: Vector3, weapon_class: StringName,
		shooter_net_id: int, flags: int) -> void:
	if hit.is_empty():
		EventBus.shot_fx.emit(origin, max_end, Vector3.ZERO, &"", weapon_class, shooter_net_id, flags)
		return
	var col: Object = hit.get("collider") as Object
	if col != null and Damage.zone_of(col) == Enums.HitZone.HEAD:
		flags |= FLAG_HEADSHOT
	var surface: StringName = surface_of(col)
	EventBus.shot_fx.emit(origin, hit.get("position", max_end) as Vector3, hit.get("normal", Vector3.ZERO) as Vector3,
		surface, weapon_class, shooter_net_id, flesh_flags(flags, surface, weapon_class))


## D-113: STRONG / PENETRATED only mean something on flesh (cleared elsewhere); the class rules add them.
static func flesh_flags(flags: int, surface: StringName, weapon_class: StringName) -> int:
	if surface != SURFACE_FLESH:
		return flags & ~(FLAG_STRONG | FLAG_PENETRATED)
	if STRONG_CLASSES.has(weapon_class):
		flags |= FLAG_STRONG
	if EXIT_CLASSES.has(weapon_class):
		flags |= FLAG_PENETRATED
	return flags


# --- NPC shots and melee (server emits + relays; peers replay) ------------------------------------

## Server: an NPC fired at `aim` (`hit` = the rolled outcome). Picks where a miss lands, then emits and
## relays one fact.
static func npc_shot(npc: NpcBase, from: Vector3, aim: Vector3, hit: bool, target: Node = null) -> void:
	if npc == null or not enabled():
		return
	var to: Vector3 = aim
	if not hit:
		var dir: Vector3 = (aim - from).normalized()
		var side: Vector3 = dir.cross(Vector3.UP)
		if side.length() < 0.001:
			side = Vector3.RIGHT
		var tw: CombatTweak = CombatTweak.data()
		var rng: RandomNumberGenerator = GameRng.stream(RNG_STREAM)
		var off: float = rng.randf_range(tw.fx_npc_miss_offset_min_m, tw.fx_npc_miss_offset_max_m)
		var ang: float = rng.randf() * TAU
		var up: Vector3 = side.normalized().cross(dir).normalized()
		to = aim + (side.normalized() * cos(ang) + up * sin(ang)) * off
	var tid: int = NetIds.of(target) if hit and target != null else 0
	var mode: int = MODE_SHOT_HIT if hit else MODE_SHOT_MISS
	play_impact(npc, from, to, tid, mode)
	_relay_impact(npc, NetIds.of(npc), from, to, tid, mode)


## Server: a melee strike by `attacker` (crew member or NPC) landed on `target` at `point`.
static func melee_hit(attacker: Node, from: Vector3, point: Vector3, target: Object) -> void:
	if attacker == null or not enabled():
		return
	var tid: int = NetIds.of(target as Node) if target is Node else 0
	play_impact(attacker, from, point, tid, MODE_MELEE)
	_relay_impact(attacker, NetIds.of(attacker), from, point, tid, MODE_MELEE)


## Every peer: emit the shot_fx of an NPC shot / melee fact. A miss raycasts this peer's world.
static func play_impact(shooter: Node, from: Vector3, to: Vector3, target_id: int, mode: int) -> void:
	if shooter == null or not is_instance_valid(shooter) or not shooter.is_inside_tree():
		return
	var sid: int = NetIds.of(shooter)
	var crew: CrewController = shooter as CrewController
	var flags: int = FLAG_FIRST_PERSON if crew != null and crew.is_local() else 0
	var cls: StringName = CLASS_MELEE
	if mode != MODE_MELEE:
		var npc: NpcBase = shooter as NpcBase
		cls = npc_weapon_class(npc.enemy_def.weapon if npc != null and npc.enemy_def != null else &"")
	var origin: Vector3 = from if mode == MODE_MELEE or (flags & FLAG_FIRST_PERSON) != 0 else tp_muzzle(shooter, from)
	var dir: Vector3 = to - from
	if dir.length() < 0.0001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	if mode != MODE_SHOT_MISS:
		var target: Object = Ids.lookup(target_id) if target_id != 0 else null
		var surface: StringName = surface_of(target) if target != null else SURFACE_FLESH
		var fp: int = FrameProf.begin()
		EventBus.shot_fx.emit(origin, to, -dir, surface, cls, sid, flesh_flags(flags, surface, cls))
		FrameProf.end(&"shot_fx.hit_emit", fp)  # A4-02: VfxDirector (C) + listeners
		return
	var tw: CombatTweak = CombatTweak.data()
	var max_end: Vector3 = from + dir * tw.hitscan_max_range_m
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, max_end, tw.hitscan_mask)
	q.collide_with_areas = false  # hitboxes: a miss must not land on the shooter's own head
	var co: CollisionObject3D = shooter as CollisionObject3D
	if co != null:
		q.exclude = [co.get_rid()]
	var space: PhysicsDirectSpaceState3D = (shooter as Node3D).get_world_3d().direct_space_state
	var fp2: int = FrameProf.begin()
	var hit: Dictionary = space.intersect_ray(q)
	FrameProf.end(&"shot_fx.miss_ray", fp2)
	fp2 = FrameProf.begin()
	emit_ray(origin, hit, max_end, cls, sid, flags)
	FrameProf.end(&"shot_fx.miss_emit", fp2)  # A4-02: VfxDirector (C) + listeners


static func _relay_impact(ctx: Node, shooter_id: int, from: Vector3, to: Vector3, target_id: int, mode: int) -> void:
	var sync: HeistNetSync = _sync_of(ctx)
	if sync != null:
		sync.relay_impact_fx(shooter_id, from, to, target_id, mode)


# --- Explosions ---------------------------------------------------------------------------------

## Server: a blast at `pos`. Emits explosion_fx here and relays it to every client.
static func explosion(ctx: Node, pos: Vector3, radius: float, kind: StringName) -> void:
	if not enabled():
		return
	EventBus.explosion_fx.emit(pos, radius, kind)
	var sync: HeistNetSync = _sync_of(ctx)
	if sync != null:
		sync.relay_explosion_fx(pos, radius, kind)


## explosion_fx kind from the Explosion.apply weapon id: &"c4" (safes, breach charges), &"trip_mine",
## &"launcher" (a WeaponDef: launcher / bow explosive), &"frag" (throwables), &"explosion" otherwise.
static func explosion_kind(weapon_id: StringName) -> StringName:
	var s: String = String(weapon_id)
	if s == "":
		return &"explosion"
	if s.contains("c4"):
		return &"c4"
	if s.begins_with("deployable."):
		return StringName(s.trim_prefix("deployable."))
	if ContentDB.has(ContentDB.WEAPONS, weapon_id):
		return &"launcher"
	return &"frag"


static func _sync_of(ctx: Node) -> HeistNetSync:
	if ctx == null or not is_instance_valid(ctx) or not Net.is_authority():
		return null
	var rt: HeistRuntime = HeistRuntime.of(ctx)
	return rt.net_sync if rt != null else null
