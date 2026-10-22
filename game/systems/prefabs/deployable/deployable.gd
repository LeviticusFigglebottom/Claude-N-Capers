## A placed crew deployable (A2-06 L2.11, S6.2; A2-03 S8.4-S8.6). Owner: ENV A.
## Spawned at runtime by DeployableSystem (never map-placed). One prefab for every kind; `kind`
## (DeployableDef.kind) picks the behaviour of `Interactable`:
##   doctor_bag     kind &"use_doctor_bag": full heal + downs reset; `uses_left` (2) uses.
##   fak            kind &"use_fak": heals DeployableTweak.fak_heal (params.heal); 1 use, no down reset.
##   ammo_bag       kind &"use_ammo_bag": refills both weapons from a shared pool (`ammo_left`, in
##                  "full loadouts": 4 uses = 400 %); each crew member takes only what is missing.
##   body_bag_case  kind &"take_body_bag": +1 body bag up to the crew member's cap; `uses_left` (3).
##   ecm            kind &"ecm_feedback" (S8.6, every ECM, D-038): EcmSystem stuns.
##   armor_bag      kind &"use_armor_bag" (QB-58, Walk-in Closet): its owner puts on `bag_armor` (the
##                  loadout's armor; DeployableSystem starts them in DeployableTweak.armor_bag_start_armor)
##                  with full armor; 1 use.
## Doctor bag use time x interaction.doctor_bag_speed_mult of the user (QB-59).
## Floor object: origin at the floor, front -Z faces the crew member who placed it. Group
## G.DEPLOYABLE. Visual: DeployableDef.model when set, else a box placeholder (`Body`).
class_name DeployablePrefab
extends GameplayPrefab

## ECM lifecycle (EcmSystem).
enum EcmState { NONE, QUEUED, JAMMING, SPENT, DOOR }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/deployable/deployable_placeholder.tscn")
const KIND_INTERACTION: Dictionary = {
	&"doctor_bag": [&"use_doctor_bag", &"ui.prompt.use_doctor_bag"],
	&"fak": [&"use_fak", &"ui.prompt.use_first_aid_kit"],
	&"ammo_bag": [&"use_ammo_bag", &"ui.prompt.use_ammo_bag"],
	&"body_bag_case": [&"take_body_bag", &"ui.prompt.take_body_bag"],
	&"ecm": [&"ecm_feedback", &"ui.prompt.ecm_feedback"],
	&"armor_bag": [&"use_armor_bag", &"ui.prompt.use_armor_bag"],
	&"sentry": [&"use_sentry", &"ui.prompt.interact"],  # D-157: the owner cycles modes / picks it up (SentryGun)
}
const AMMO_EPSILON: float = 0.0005

## DeployableDef.kind.
@export var kind: StringName = &"doctor_bag"
## DeployableDef id (&"deployable.doctor_bag").
@export var deployable_id: StringName = &""
@export_group("Interaction")
## -1 = DeployableTweak.use_time_s[kind].
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

## Crew slot that placed it (modifiers of the owner apply: ECM duration, feedback...).
var owner_slot: int = -1
## Charges left (doctor bag / FAK / body bag case).
var uses_left: int = 1
## Ammo bag pool left, in full loadouts (1.0 = 100 %).
var ammo_left: float = 0.0
## FAK / doctor bag heal parameters (from the def).
var heal_amount: float = 0.0
var heal_frac: float = 1.0
var resets_downs: bool = false
## QB-58 armor bag: ArmorDef id the owner changes into.
var bag_armor: StringName = &""
## ECM state (EcmSystem): jam timer, flashing (S8.4 last 8 s), feedback (S8.6).
var ecm_state: EcmState = EcmState.NONE
var jam_duration: float = 0.0
var jam_left: float = 0.0
var flashing: bool = false
var feedback_used: bool = false
var feedback_recharge_left: float = 0.0
## Trip mine (S9.5 deployable): seconds before it arms; true once detonated.
var _trip_arm_left: float = 0.0
var _trip_fired: bool = false


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return float(DeployableTweak.data().use_time_s.get(kind, 1.0))


## Server, before add_child: configure from the def and the owner's modifiers.
func setup(def: DeployableDef, p_owner_slot: int, uses: int) -> void:
	deployable_id = def.id
	kind = def.kind
	owner_slot = p_owner_slot
	uses_left = maxi(uses, 1)
	if def.model != null:
		visual_scene = def.model
	match kind:
		&"ammo_bag":
			ammo_left = float(uses) * float(def.params.get("refill_frac_per_use", 1.0))
		&"fak":
			heal_amount = float(def.params.get("heal", DeployableTweak.data().fak_heal))
			resets_downs = false
		&"doctor_bag":
			heal_frac = float(def.params.get("heal_frac", 1.0))
			resets_downs = bool(def.params.get("resets_downs", true))
		&"body_bag_case":
			uses_left = maxi(uses, 1)
		&"sentry":  # D-157: the turret behaviour (SentryGun.NODE_NAME child)
			var sg: SentryGun = SentryGun.new()
			sg.name = SentryGun.NODE_NAME
			sg.setup(owner_slot, def.params)
			add_child(sg)


func _prefab_ready() -> void:
	add_to_group(G.DEPLOYABLE)
	var spec: Array = KIND_INTERACTION.get(kind, [&"use", &"ui.prompt.interact"])
	interactable.kind = spec[0]
	interactable.prompt_key = spec[1]
	interactable.extra_check = _use_check
	interactable.speed_modifier_key = &"deploy.deploy_speed_mult" if kind != &"ecm" else &""
	interactable.completed.connect(_on_completed)
	if kind == &"doctor_bag":
		interactable.duration_override = _doctor_bag_duration
	if kind == &"trip_mine":
		interactable.enabled = false  # S9.5 trip mine: no use interaction, it arms and waits for an enemy
		_trip_arm_left = DeployableTweak.data().trip_mine_arm_s


## QB-59: the user's interaction.doctor_bag_speed_mult (lower = faster).
func _doctor_bag_duration(crew: Node, base: float) -> float:
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	return base * Modifiers.mult(slot, &"interaction.doctor_bag_speed_mult") if slot >= 0 else base


## Charges left for the HUD / visuals (ammo bag: percent of one loadout, rounded).
func charges_left() -> int:
	if kind == &"ammo_bag":
		return int(round(ammo_left * 100.0))
	return uses_left


# --- Use ----------------------------------------------------------------------------------------

func _use_check(crew: Node) -> StringName:
	var c: CrewController = crew as CrewController
	if c == null:
		return InteractableComponent.BLOCK_NONE
	if kind == &"ecm":
		var ecm: EcmSystem = HeistRuntime.get_service(EcmSystem.SERVICE) as EcmSystem
		return ecm.feedback_block(self, c) if ecm != null else InteractableComponent.BLOCK_DISABLED
	var usable: bool = true
	match kind:
		&"doctor_bag", &"fak":
			usable = c.health != null and (c.health.health < c.health.max_health - 0.01
				or (resets_downs and c.health.downs_used > 0))
		&"ammo_bag":
			usable = ammo_left > AMMO_EPSILON and _ammo_missing_frac(c) > 0.0
		&"body_bag_case":
			usable = uses_left > 0 and c.body_bags < body_bag_cap(c.slot)
		&"armor_bag":
			usable = c.slot == owner_slot and bag_armor != &"" and c.loadout != null and c.loadout.armor != bag_armor
	return InteractableComponent.BLOCK_NONE if usable else InteractableComponent.BLOCK_STATE


## S6.2: body bag inventory cap (CrewTweak.body_bags_cap + stealth.body_bags_extra).
static func body_bag_cap(slot: int) -> int:
	return Tweak.crew().body_bags_cap + int(Modifiers.add(slot, &"stealth.body_bags_extra"))


func _on_completed(crew: Node) -> void:
	var c: CrewController = crew as CrewController
	if not Net.is_authority() or c == null or _use_check(c) != InteractableComponent.BLOCK_NONE:
		return
	match kind:
		&"doctor_bag":
			c.health.heal(c.health.max_health * heal_frac, resets_downs)  # L2.11
			SkillTriggers.doctor_bag_used(self, c)  # B1 Messiah Aced
			SkillTriggers.medical_used(self, c)  # B3 Bedside Manner
			_consume_use()
		&"fak":
			c.health.heal(heal_amount, false)  # L2.11: no down reset
			SkillTriggers.medical_used(self, c)  # B3 Bedside Manner
			_consume_use()
		&"ammo_bag":
			_give_ammo(c)
		&"body_bag_case":
			c.body_bags += 1  # S6.2
			c.inventory_changed.emit()
			_consume_use()
		&"ecm":
			var ecm: EcmSystem = HeistRuntime.get_service(EcmSystem.SERVICE) as EcmSystem
			if ecm != null:
				ecm.trigger_feedback(self, c.slot)
		&"armor_bag":
			DeployableSystem.wear_armor(c, bag_armor)  # QB-58
			_consume_use()
		&"sentry":
			var sg: SentryGun = SentryGun.of(self)
			if sg != null and sg.interact(c):  # D-157: picked up: the ammo refunded, the sentry back in the inventory
				var ds: DeployableSystem = HeistRuntime.get_service(DeployableSystem.SERVICE) as DeployableSystem
				if ds != null:
					ds.restock(c.slot, deployable_id)
				_spent()


## Server: one use gone (B3 Field Kit: the first-aid kit that auto-revived someone).
func consume_use() -> void:
	_consume_use()


func _consume_use() -> void:
	uses_left -= 1
	if uses_left <= 0:
		_spent()


func _spent() -> void:
	interactable.enabled = false
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null and rt.interaction != null:
		rt.interaction.cancel_all_on(interactable)
	queue_free()


# --- Trip mine (S9.5 deployable) ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if kind != &"trip_mine" or _trip_fired or not Net.is_authority() or not is_inside_tree():
		return
	if _trip_arm_left > 0.0:
		_trip_arm_left -= delta
		return
	var tw: DeployableTweak = DeployableTweak.data()
	var eye: Vector3 = global_position + Vector3.UP * 0.2
	for n: Node in get_tree().get_nodes_in_group(G.ENEMY):
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.alive or HeistRuntime.of(npc) != HeistRuntime.of(self):
			continue
		if npc.global_position.distance_to(global_position) <= tw.trip_mine_trigger_m \
				and CombatSystem.has_los(self, eye, npc.global_position + Vector3.UP * 0.9, [npc]):
			trip_detonate()
			return


## Server: blow the trip mine (noise, cue, L3.6 blast x the owner's deploy.trip_mine_radius_mult), then free.
func trip_detonate() -> void:
	if _trip_fired:
		return
	_trip_fired = true
	var tw: DeployableTweak = DeployableTweak.data()
	var pos: Vector3 = global_position + Vector3.UP * 0.2
	var radius: float = tw.trip_mine_radius_m * (Modifiers.mult(owner_slot, &"deploy.trip_mine_radius_mult")
		if owner_slot >= 0 else 1.0)
	var rt: HeistRuntime = HeistRuntime.of(self)
	var by: int = 0
	if rt != null:
		var c: Node = rt.crew_controller(owner_slot) if owner_slot >= 0 else null
		by = NetIds.of(c) if c != null else 0
		rt.make_noise(pos, tw.trip_mine_noise_radius_m, &"explosion", net_id)
	EventBus.audio_cue_requested.emit(&"cue.trip_mine_explode", pos, by)
	Net.replicate_event(&"audio_cue_requested", [&"cue.trip_mine_explode", pos, by])
	Explosion.apply(self, pos, radius, tw.trip_mine_damage, by, &"deployable.trip_mine")
	var fire: Dictionary = Modifiers.params(owner_slot, &"deploy.trip_mine_fire") if owner_slot >= 0 else {}
	if not fire.is_empty():  # B5 Hot Floor: the blast leaves a fire pool
		ThrownItem.spawn_fire_pool(self, global_position, float(fire.get("radius", 0.0)), float(fire.get("duration", 0.0)),
			by, owner_slot)
	_spent()


# --- Ammo bag (L2.11) -----------------------------------------------------------------------------

## Fraction of one full loadout of ammo `crew` is missing (0 = full).
func _ammo_missing_frac(c: CrewController) -> float:
	var w: CrewWeapons = c.weapons
	if w == null:
		return 0.0
	var total: int = 0
	var missing: int = 0
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if not w.has_weapon(ws):
			continue
		var mx: int = max_ammo(c, ws)
		total += mx
		missing += maxi(mx - w.mag(ws) - w.reserve(ws), 0)
	return float(missing) / float(total) if total > 0 else 0.0


## Full mag + reserve of weapon slot `ws` (same rule as CrewWeapons arming: total_ammo x
## weapon.ammo_total_mult, at least one magazine).
static func max_ammo(c: CrewController, ws: int) -> int:
	var w: CrewWeapons = c.weapons
	var st: WeaponStats = w.stats(ws) if w != null else null
	if st == null:
		return 0
	var def: WeaponDef = ContentDB.weapon(w.weapon_id(ws))
	var q: StringName = Enums.weapon_class_qualifier(def.weapon_class) if def != null else &"pistol"
	var total: int = int(round(float(st.total_ammo) * Modifiers.mult(c.slot, &"weapon.ammo_total_mult", q)))
	return maxi(total, w.mag_size(ws))


func _give_ammo(c: CrewController) -> void:
	var w: CrewWeapons = c.weapons
	var need: float = _ammo_missing_frac(c)
	if w == null or need <= 0.0:
		return
	var take: float = minf(need, ammo_left)
	var scale: float = take / need
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if not w.has_weapon(ws):
			continue
		var mx: int = max_ammo(c, ws)
		var have: int = w.mag(ws) + w.reserve(ws)
		var add: int = int(round(float(maxi(mx - have, 0)) * scale))
		w.set_ammo(ws, w.mag(ws), mini(w.reserve(ws) + add, mx - w.mag(ws)))  # shared pool (400 %)
	ammo_left = maxf(ammo_left - take, 0.0)
	SkillTriggers.ammo_bag_used(self, c, owner_slot, take)  # B1 Bulletstorm (the bag owner's skill)
	if ammo_left <= AMMO_EPSILON:
		_spent()
