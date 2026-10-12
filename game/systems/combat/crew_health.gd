## Crew health / armor / downs component (A1-08): child `Health` of CrewController. Owner: ENV A.
## Server-authoritative. Fidelity rows:
## - L2.1 health: CrewTweak.base_health (230) x defense.health_mult; no regeneration.
## - L2.2 armor: ArmorDef.armor (CrewTweak.default_armor fallback) x defense.armor_mult. Armor absorbs
##   first; a normal hit is capped at the remaining armor (armor gating) unless the DamageInfo has
##   `bypass_armor_gate` (snipers): then the overflow reaches health. A gated hit (armor broken)
##   grants CrewTweak.armor_gate_invuln_s[difficulty] of invulnerability. Any damage restarts the
##   regen delay (armor_regen_delay_s x defense.armor_regen_delay_mult); armor then refills fully
##   over armor_regen_full_time_s (x 1/defense.armor_regen_rate_mult).
## - L2.5 bleedout: zero health -> DOWNED for bleedout_time_s (+defense.bleedout_time_add) with a
##   bleedout_health pool; can shoot, cannot move or interact. Expiry -> CUSTODY.
## - L2.6 downs: downs_before_custody (+defense.downs_extra); the next zero-health hit -> CUSTODY.
## - L2.7 revive: the sibling `ReviveInteractable` (InteractableComponent, kind &"revive") is enabled
##   while DOWNED; any other crew member (human, AI teammate via interact_target_net_id = net_id)
##   holds it for revive_time_s x interaction.revive_speed_mult (reviver). Completion -> NORMAL with
##   max_health x revived_health_frac[difficulty] x defense.revived_health_mult.
## - L2.4 dodge (A2-06): a BULLET hit is dodged with chance ArmorDef.dodge + defense.dodge_add (<= 0:
##   never) on GameRng &"dodge": no damage, `dodged` = true, the armor regen delay restarts.
## - L2.11 heal(amount, reset_downs) (A2-06): doctor bag / first aid kit.
## - L2.8 incapacitate(state, by_net_id) (A3-04): TASED / CLOAKER_DOWNED: helpless (no move, shoot or
##   interact), no bleedout, NOT a down; the ReviveInteractable frees them (health kept). Damage still
##   lands normally (zero health -> go_down). Emits crew_tased / crew_cloaker_downed [R].
## - L2.12 (A3-04): a downed crew member cuffed by police (CrewCuffs.cuff_downed) is CUFFED with the
##   bleedout paused; hits still drain the bleedout pool; freed -> DOWNED again.
## Events: crew_downed / crew_revived / crew_custody [R]; damage_applied [R]. A broken tase is
## end_tase() (no crew_revived; StingerBrain emits crew_tase_ended).
## HUD duck-typed interface (local_hud_model.gd): health, max_health, armor, max_armor, downs_left,
## bleedout_left.
class_name CrewHealth
extends Node

signal damaged(info: Dictionary, attacker_net_id: int)
signal downed(downs_used: int)
signal revived(by_slot: int)
signal custody()

var health: float = 230.0
var max_health: float = 230.0
var armor: float = 20.0
var max_armor: float = 20.0
## Downs used since the heist start (or the last reset).
var downs_used: int = 0
## Seconds of bleedout left (0 when not downed).
var bleedout_left: float = 0.0
## Bleedout health pool while downed (L2.5).
var bleedout_health: float = 0.0
## Seconds of post-gate invulnerability left.
var invuln_left: float = 0.0
## Seconds until armor starts regenerating.
var regen_delay_left: float = 0.0
## Downs left before the next zero-health hit means custody (HUD).
var downs_left: int:
	get:
		return maxi(max_downs() - downs_used, 0)

var _crew: CrewController = null
var _revive: InteractableComponent = null


func _ready() -> void:
	_crew = get_parent() as CrewController
	if _crew == null:
		Log.error(&"combat", "CrewHealth must be a child of a CrewController")
		return
	_revive = _crew.get_node_or_null("ReviveInteractable") as InteractableComponent
	if _revive != null:
		var tw: CrewTweak = Tweak.crew()
		_revive.kind = &"revive"
		_revive.interaction_time_s = tw.revive_time_s
		_revive.speed_modifier_key = &"interaction.revive_speed_mult"
		_revive.prompt_key = &"ui.prompt.revive"
		_revive.priority = 100
		_revive.enabled = false
		_revive.extra_check = _revive_check
		_revive.completed.connect(_on_revive_completed)
	reset_full()


## Max health / armor from tweak, armor def and modifiers (re-evaluated every server tick).
func compute_max_health() -> float:
	return PerkHooks.max_health(self, Tweak.crew().base_health
		* TeamModifiers.combined(_slot(), &"defense.health_mult", &"team.health_mult"))  # QB-60 team.health_mult; perk hook


func compute_max_armor() -> float:
	var base: float = Tweak.crew().default_armor
	var l: Loadout = _crew.loadout if _crew != null else null
	if l != null and l.armor != &"":
		var def: ArmorDef = ContentDB.armor(l.armor)
		if def != null:
			base = def.armor
	return PerkHooks.max_armor(self, base
		* TeamModifiers.combined(_slot(), &"defense.armor_mult", &"team.armor_mult"))  # QB-60: x team.armor_mult; perk hook


## Armor regen delay after a hit or dodge: personal x team key (QB-60).
func _regen_delay(tw: CrewTweak) -> float:
	return tw.armor_regen_delay_s * TeamModifiers.combined(_slot(), &"defense.armor_regen_delay_mult",
		&"team.armor_regen_delay_mult")


func max_downs() -> int:
	return Tweak.crew().downs_before_custody + int(Modifiers.add(_slot(), &"defense.downs_extra"))


## Full health and armor, downs reset (spawn, custody release, doctor bag P2).
func reset_full() -> void:
	max_health = compute_max_health()
	max_armor = compute_max_armor()
	health = max_health
	armor = max_armor
	downs_used = 0
	bleedout_left = 0.0
	invuln_left = 0.0
	regen_delay_left = 0.0


## A2-06 (L2.4): dodge chance = ArmorDef.dodge + defense.dodge_add (a negative total = 0).
func dodge_chance() -> float:
	var base: float = 0.0
	var l: Loadout = _crew.loadout if _crew != null else null
	if l != null and l.armor != &"":
		var def: ArmorDef = ContentDB.armor(l.armor)
		if def != null:
			base = def.dodge
	return clampf(base + Modifiers.add(_slot(), &"defense.dodge_add") + PerkHooks.dodge_add(self), 0.0, 1.0)  # perk hook


## A2-06 (L2.11): heal `amount` (clamped to max health); `reset_downs` (doctor bag) also restores
## every down. NORMAL crew only. Server.
func heal(amount: float, reset_downs: bool = false) -> void:
	if _crew == null or not Net.is_authority() or _crew.crew_state != Enums.CrewState.NORMAL:
		return
	health = minf(health + maxf(amount, 0.0), max_health)
	if reset_downs:
		downs_used = 0


func is_downed() -> bool:
	return _crew != null and _crew.crew_state == Enums.CrewState.DOWNED


# --- Damage -------------------------------------------------------------------------------------

## Server: the hit entry point (damage.md; CrewController.take_hit delegates here). `info` =
## Damage.info(); crew take x1 on the head (NPC fire), so `zone` / `headshot_bonus` are ignored.
## Emits damage_applied [R] itself. Returns the final DamageInfo (amount removed from armor +
## health, `armor_damage`, `health_damage`, `killed` = went down / to custody on this hit).
## damage.md v1.1: `info.pierced_armor` skips armor (straight to health, no armor gate); crew carry no
## shields, so `shield_pierce` is ignored and `blocked` stays false.
func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	var out: Dictionary = CombatSystem.ensure_info_v11(info.duplicate())
	out["armor_damage"] = 0.0
	out["health_damage"] = 0.0
	out["killed"] = false
	if not Net.is_authority() or _crew == null:
		out["amount"] = 0.0
		return out
	var st: int = _crew.crew_state
	if st == Enums.CrewState.CUSTODY:
		out["amount"] = 0.0
		return out
	var tw: CrewTweak = Tweak.crew()
	var dmg: float = maxf(float(info.get("amount", 0.0)), 0.0) * Modifiers.mult(_slot(), &"defense.damage_taken_mult")
	if int(info.get("type", Enums.DamageType.BULLET)) == Enums.DamageType.MELEE:
		dmg *= Modifiers.mult(_slot(), &"defense.melee_damage_taken_mult")  # A3-13: enemy melee
	dmg = TeamModifiers.hostage_reduced(_slot(), dmg, TeamModifiers.hostage_count(_crew))  # QB-60
	if st == Enums.CrewState.DOWNED or _is_cuffed_while_down():
		bleedout_health -= dmg
		out["amount"] = dmg
		out["health_damage"] = dmg
		_publish(out, attacker_net_id)
		if bleedout_health <= 0.0:
			out["killed"] = true
			go_to_custody()
		return out
	if invuln_left > 0.0:
		out["amount"] = 0.0
		return out
	# --- A2-06 dodge (L2.4): a ranged hit may do nothing; a dodge restarts the armor regen delay.
	if int(info.get("type", Enums.DamageType.BULLET)) == Enums.DamageType.BULLET and _roll_dodge():
		regen_delay_left = _regen_delay(tw)
		out["amount"] = 0.0
		out["dodged"] = true
		_publish(out, attacker_net_id)
		return out
	# --- end A2-06
	dmg = PerkHooks.incoming_damage(self, info, dmg)  # perk hook (QB-62: perk DR, perk.stoic DoT)
	var armor_dmg: float = 0.0
	var health_dmg: float = 0.0
	if bool(info.get("pierced_armor", false)) or armor <= 0.0:
		health_dmg = dmg
	elif dmg >= armor:
		armor_dmg = armor
		if bool(info.get("bypass_armor_gate", false)):
			health_dmg = dmg - armor
		else:
			invuln_left = _gate_invuln(tw)  # L2.2 armor gate: the overflow is discarded
	else:
		armor_dmg = dmg
	armor -= armor_dmg
	health = maxf(health - health_dmg, 0.0)
	regen_delay_left = _regen_delay(tw)
	out["amount"] = armor_dmg + health_dmg
	out["armor_damage"] = armor_dmg
	out["health_damage"] = health_dmg
	PerkHooks.after_hit(self, out)  # perk hook (QB-62)
	var rt: HeistRuntime = HeistRuntime.of(_crew)
	if rt != null and rt.interaction != null and armor_dmg + health_dmg > 0.0:
		rt.interaction.interrupt_on_damage(_crew.slot)  # S9.1
	if health <= 0.0:
		out["killed"] = true
	_publish(out, attacker_net_id)
	if health <= 0.0:
		go_down()
	return out


## Deprecated alias of take_hit.
func apply_damage(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	return take_hit(info, attacker_net_id)


func _publish(out: Dictionary, attacker_net_id: int) -> void:
	damaged.emit(out, attacker_net_id)
	EventBus.damage_applied.emit(_crew.net_id, attacker_net_id, out)
	Net.replicate_event(&"damage_applied", [_crew.net_id, attacker_net_id, out])


func _gate_invuln(tw: CrewTweak) -> float:
	var arr: PackedFloat32Array = tw.armor_gate_invuln_s
	if arr.is_empty():
		return 0.0
	return arr[clampi(_difficulty(), 0, arr.size() - 1)]


# --- State changes (server) ------------------------------------------------------------------------

## Zero health: DOWNED (L2.5) or, with no downs left, CUSTODY (L2.6).
func go_down() -> void:
	if _crew == null or not Net.is_authority():
		return
	if downs_used >= max_downs():
		go_to_custody()
		return
	var tw: CrewTweak = Tweak.crew()
	downs_used += 1
	health = 0.0
	armor = 0.0
	invuln_left = 0.0
	bleedout_left = tw.bleedout_time_s + Modifiers.add(_slot(), &"defense.bleedout_time_add")
	bleedout_health = tw.bleedout_health
	_crew.set_crew_state(Enums.CrewState.DOWNED)
	if _revive != null:
		_revive.enabled = true
	downed.emit(downs_used)
	EventBus.crew_downed.emit(_crew.slot, downs_used)
	Net.replicate_event(&"crew_downed", [_crew.slot, downs_used])
	Log.info(&"combat", "slot %d downed (%d/%d)" % [_crew.slot, downs_used, max_downs()])


func go_to_custody() -> void:
	if _crew == null or not Net.is_authority() or _crew.crew_state == Enums.CrewState.CUSTODY:
		return
	health = 0.0
	armor = 0.0
	bleedout_left = 0.0
	bleedout_health = 0.0
	_disable_revive()
	_crew.set_crew_state(Enums.CrewState.CUSTODY)
	custody.emit()
	EventBus.crew_custody.emit(_crew.slot)
	Net.replicate_event(&"crew_custody", [_crew.slot])
	Log.info(&"combat", "slot %d in custody" % _crew.slot)


## Server: revive a DOWNED crew member (ReviveInteractable completion, inspire P2...). A TASED /
## CLOAKER_DOWNED one (L2.8) gets up with the health and armor they had.
func revive(by_slot: int) -> void:
	if _crew == null or not Net.is_authority():
		return
	if is_incapacitated():
		_disable_revive()
		_crew.set_crew_state(Enums.CrewState.NORMAL)
		revived.emit(by_slot)
		EventBus.crew_revived.emit(_crew.slot, by_slot)
		Net.replicate_event(&"crew_revived", [_crew.slot, by_slot])
		return
	if _crew.crew_state != Enums.CrewState.DOWNED:
		return
	var tw: CrewTweak = Tweak.crew()
	var arr: PackedFloat32Array = tw.revived_health_frac
	var frac: float = arr[clampi(_difficulty(), 0, arr.size() - 1)] if not arr.is_empty() else 0.4
	max_health = compute_max_health()
	max_armor = compute_max_armor()
	health = max_health * frac * Modifiers.mult(_slot(), &"defense.revived_health_mult")
	health = clampf(health, 1.0, max_health)
	armor = max_armor * CombatTweak.data().revive_armor_frac
	bleedout_left = 0.0
	bleedout_health = 0.0
	invuln_left = 0.0
	regen_delay_left = 0.0
	_disable_revive()
	_crew.set_crew_state(Enums.CrewState.NORMAL)
	revived.emit(by_slot)
	EventBus.crew_revived.emit(_crew.slot, by_slot)
	Net.replicate_event(&"crew_revived", [_crew.slot, by_slot])


## A3-04 (L2.8): Taser / Phantom takedown. `state` is CrewState.TASED or CLOAKER_DOWNED; only a
## NORMAL (or SWAN_SONG) crew member can be taken down. Not a down, no bleedout; helpless until a
## teammate revives them (ReviveInteractable). Emits crew_tased / crew_cloaker_downed [R]. Server.
func incapacitate(state: Enums.CrewState, by_net_id: int = 0) -> bool:
	if _crew == null or not Net.is_authority():
		return false
	if state != Enums.CrewState.TASED and state != Enums.CrewState.CLOAKER_DOWNED:
		Log.warn(&"combat", "incapacitate: %s is not TASED / CLOAKER_DOWNED" % Enums.CrewState.keys()[state])
		return false
	var cur: int = _crew.crew_state
	if cur != Enums.CrewState.NORMAL and cur != Enums.CrewState.SWAN_SONG:
		return false
	_crew.set_crew_state(state)
	if _revive != null:
		_revive.enabled = true
	var sig: StringName = &"crew_tased" if state == Enums.CrewState.TASED else &"crew_cloaker_downed"
	EventBus.emit_signal(sig, _crew.slot, by_net_id)
	Net.replicate_event(sig, [_crew.slot, by_net_id])
	Log.info(&"combat", "slot %d %s by %d" % [_crew.slot, sig, by_net_id])
	return true


## L2.8: TASED or CLOAKER_DOWNED (helpless, revivable, not a down).
func is_incapacitated() -> bool:
	return _crew != null and (_crew.crew_state == Enums.CrewState.TASED
		or _crew.crew_state == Enums.CrewState.CLOAKER_DOWNED)


## L2.12: cuffed by police while downed (bleedout paused, pool still takes hits).
func _is_cuffed_while_down() -> bool:
	return _crew != null and _crew.crew_state == Enums.CrewState.CUFFED and bleedout_left > 0.0


## Server: a BROKEN tase (Stinger killed / stunned / LOS / range / counter, L4.4): a TASED crew member
## gets up with the health and armor they had. Not a revive: no crew_revived (D-049); the Stinger
## emits crew_tase_ended [R]. Returns false when not TASED.
func end_tase() -> bool:
	if _crew == null or not Net.is_authority() or _crew.crew_state != Enums.CrewState.TASED:
		return false
	_disable_revive()
	_crew.set_crew_state(Enums.CrewState.NORMAL)
	return true


## Server: custody release (P3 hostage trade): back to NORMAL at full health, downs reset.
func release_from_custody() -> void:
	if _crew == null or not Net.is_authority() or _crew.crew_state != Enums.CrewState.CUSTODY:
		return
	reset_full()
	_crew.set_crew_state(Enums.CrewState.NORMAL)


func _disable_revive() -> void:
	if _revive == null:
		return
	_revive.enabled = false
	var rt: HeistRuntime = HeistRuntime.of(_crew)
	if rt != null and rt.interaction != null:
		rt.interaction.cancel_all_on(_revive)


# --- Tick -----------------------------------------------------------------------------------------

## Authority: every physics tick (CrewController._tick_server_actions).
func server_tick(delta: float) -> void:
	if _crew == null:
		return
	_refresh_max()
	match _crew.crew_state:
		Enums.CrewState.DOWNED:
			bleedout_left -= delta
			if bleedout_left <= 0.0:
				bleedout_left = 0.0
				go_to_custody()
			return
		Enums.CrewState.CUSTODY, Enums.CrewState.TASED, Enums.CrewState.CLOAKER_DOWNED:
			return
		Enums.CrewState.CUFFED:
			if bleedout_left > 0.0:
				return  # L2.12: police-cuffed while downed, bleedout paused
	_tick_health_regen(delta)  # L2.1
	if invuln_left > 0.0:
		invuln_left = maxf(invuln_left - delta, 0.0)
	if PerkHooks.tick(self, delta):  # perk hook (QB-62); true = a perk replaces the armor regen
		return
	if regen_delay_left > 0.0:
		regen_delay_left -= delta
		return
	if armor < max_armor:
		var tw: CrewTweak = Tweak.crew()
		var rate: float = max_armor / maxf(tw.armor_regen_full_time_s, 0.001)
		armor = minf(armor + rate * TeamModifiers.armor_regen_rate_mult(_slot()) * delta, max_armor)


## L2.1: no base regen; defense.health_regen_per_sec (fraction of max health per second) heals while
## up (never while downed / custody / incapacitated: server_tick returns before this for those).
func _tick_health_regen(delta: float) -> void:
	var r: float = Modifiers.add(_slot(), &"defense.health_regen_per_sec")
	if r > 0.0 and health > 0.0 and health < max_health:
		health = minf(health + max_health * r * delta, max_health)


## Modifier changes mid-heist rescale the current values (keeps the fraction).
func _refresh_max() -> void:
	var mh: float = compute_max_health()
	if not is_equal_approx(mh, max_health):
		health = health * mh / maxf(max_health, 0.001)
		max_health = mh
	var ma: float = compute_max_armor()
	if not is_equal_approx(ma, max_armor):
		armor = armor * ma / maxf(max_armor, 0.001) if max_armor > 0.0 else ma
		max_armor = ma


func _revive_check(reviver: Node) -> StringName:
	if _crew == null or (_crew.crew_state != Enums.CrewState.DOWNED and not is_incapacitated()):
		return InteractableComponent.BLOCK_DISABLED
	if reviver == _crew:
		return InteractableComponent.BLOCK_STATE
	return InteractableComponent.BLOCK_NONE


func _on_revive_completed(reviver: Node) -> void:
	var by: int = int(reviver.get(&"slot")) if reviver != null else -1
	revive(by)


## Rolled on GameRng &"dodge" only when the chance is positive.
func _roll_dodge() -> bool:
	var chance: float = dodge_chance()
	return chance > 0.0 and GameRng.stream(&"dodge").randf() < chance


func _slot() -> int:
	return _crew.slot if _crew != null else -1


func _difficulty() -> int:
	var rt: HeistRuntime = HeistRuntime.of(_crew) if _crew != null else null
	return rt.difficulty if rt != null else Enums.Difficulty.ROUTINE
