## D-164 perk.leech (Lifeline; PD2 Leech). Owner: ENV A. Schema: B's perk_decks.md. The deck throwable (perk.throwable
## item_id throwable.leech_ampule, ThrowableDef kind KIND) starts a window of duration_s: it heals
## activate_heal_fraction of max health, armor_off zeroes the armor for the window, and health counts in segments of
## segment_fraction x max health (a hit removes the top segment whole, whatever its damage); kills_per_segment kills
## restore one; each hit taken heals every teammate team_heal_on_damage_fraction of their max health. no_bleedout: no down
## during the window (the holder stays up at 0 health, moving at x zero_health_speed_mult, CrewBuffs); at 0 health when
## it ends, the down comes. cooldown_s starts when the window ends; kills then cut kill_cooldown_reduction_s.
## usable_while_downed: used while DOWNED it is a temporary revive for the window; at its end the holder goes back
## down (the down not spent again, the bleed-out it had) unless they revived a teammate or used a doctor bag meanwhile
## and have health left. Server only; the state goes to PerkItems (perk_item, segments: ui_hud v1.22).
class_name PerkLeech
extends PerkComponent

const KEY: StringName = &"perk.leech"
const KIND: StringName = &"leech_ampule"
const BUFF_ZERO_HP: StringName = &"leech_zero_health"

var active_left: float = 0.0
var cooldown_left: float = 0.0
var kills_toward_segment: int = 0
## Temporary revive (used while down): the down count and bleed-out it came from; kept = it no longer ends in a down.
var temp_revive: bool = false
var temp_kept: bool = false
var _temp_downs: int = 0
var _temp_bleedout: float = 0.0
var _connected: bool = false


func is_active() -> bool:
	return active_left > 0.0


func usable_while_down() -> bool:
	return bool(param("usable_while_downed", false))


func use_throwable(kind: StringName) -> bool:
	var h: CrewHealth = _health()
	if kind != KIND or h == null or is_active() or cooldown_left > 0.0:
		return false
	if crew.crew_state == Enums.CrewState.DOWNED:
		if not usable_while_down():
			return false
		_temp_downs = h.downs_used
		_temp_bleedout = h.bleedout_left
		h.revive(_slot())
		h.health = 0.0
		temp_revive = true
		temp_kept = false
	elif crew.crew_state != Enums.CrewState.NORMAL:
		return false
	_connect()
	active_left = num("duration_s")
	kills_toward_segment = 0
	h.health = minf(h.health + h.max_health * num("activate_heal_fraction"), h.max_health)
	if bool(param("armor_off", false)):
		h.armor = 0.0
	_publish()
	return true


func adjust_max_armor(value: float, _raw_health: float) -> float:
	return 0.0 if is_active() and bool(param("armor_off", false)) else value


func tick(delta: float) -> void:
	var h: CrewHealth = _health()
	if is_active():
		active_left = maxf(active_left - delta, 0.0)
		if h != null and temp_revive and h.downs_used < _temp_downs:
			temp_kept = true  # a doctor bag reset the downs
		_zero_health_buff(h)
		if not is_active():
			_end(h)
	else:
		tick_item_cooldown(delta)
	_publish()


## Its item cooldown: also while the holder is down (CrewPerks.tick_item_cooldowns, PD2 timers keep running).
func tick_item_cooldown(delta: float) -> void:
	if not is_active():
		cooldown_left = maxf(cooldown_left - delta, 0.0)


func incoming(_info: Dictionary, dmg: float) -> float:
	var h: CrewHealth = _health()
	if not is_active() or h == null or dmg <= 0.0:
		return dmg
	_team_heal()
	var seg: float = segment_size()
	var left: int = segments_left()
	return maxf(h.health - maxf(left - 1, 0) * seg, 0.0)  # the top segment, whole


func veto_down() -> bool:
	if not is_active() or not bool(param("no_bleedout", false)):
		return false
	_health().health = 0.0
	return true


func on_kill(_victim: Node, _info: Dictionary) -> void:
	if not is_active():
		cooldown_left = maxf(cooldown_left - num("kill_cooldown_reduction_s"), 0.0)
		return
	kills_toward_segment += 1
	if kills_toward_segment < maxi(int(num("kills_per_segment")), 1):
		return
	kills_toward_segment = 0
	var h: CrewHealth = _health()
	h.health = minf(float(segments_left() + 1) * segment_size(), h.max_health)


func segment_size() -> float:
	var h: CrewHealth = _health()
	return maxf(num("segment_fraction"), 0.01) * (h.max_health if h != null else 100.0)


func segment_total() -> int:
	return maxi(roundi(1.0 / maxf(num("segment_fraction"), 0.01)), 1)


## Segments with health in them (a partly filled top one counts).
func segments_left() -> int:
	var h: CrewHealth = _health()
	return ceili(h.health / segment_size() - 0.0001) if h != null and h.health > 0.0 else 0


func _end(h: CrewHealth) -> void:
	cooldown_left = num("cooldown_s")
	var buffs: CrewBuffs = CrewBuffs.of(HeistRuntime.of(crew))
	if buffs != null:
		buffs.end(_slot(), BUFF_ZERO_HP)
	var was_temp: bool = temp_revive
	temp_revive = false
	if h == null:
		return
	h.max_armor = h.compute_max_armor()
	h.armor = 0.0  # the armor comes back through its regen, not refilled
	if was_temp and not temp_kept:
		h.downs_used = _temp_downs - 1  # back to the down it came from (go_down counts it again)
		h.go_down()
		if crew.crew_state == Enums.CrewState.DOWNED:
			h.bleedout_left = _temp_bleedout
	elif h.health <= 0.0:
		h.go_down()


func _zero_health_buff(h: CrewHealth) -> void:
	var buffs: CrewBuffs = CrewBuffs.of(HeistRuntime.of(crew))
	if buffs == null or h == null:
		return
	var m: float = float(param("zero_health_speed_mult", 1.0))
	if h.health <= 0.0 and m != 1.0:
		buffs.grant(_slot(), BUFF_ZERO_HP, {&"movement.speed_mult": m}, active_left)
	elif buffs.active(_slot(), BUFF_ZERO_HP):
		buffs.end(_slot(), BUFF_ZERO_HP)


func _team_heal() -> void:
	var f: float = num("team_heal_on_damage_fraction")
	var rt: HeistRuntime = HeistRuntime.of(crew)
	if f <= 0.0 or rt == null:
		return
	for m: CrewController in rt.crew_members():
		if m != crew and m.health != null:
			m.health.heal(m.health.max_health * f)


func _connect() -> void:
	if not _connected:
		_connected = true
		EventBus.crew_revived.connect(_on_crew_revived)


func _on_crew_revived(crew_slot: int, by_slot: int) -> void:
	if temp_revive and is_active() and by_slot == _slot() and crew_slot != _slot():
		temp_kept = true  # the holder revived a teammate


func _publish() -> void:
	var items: PerkItems = PerkItems.of(HeistRuntime.of(crew))
	if items == null:
		return
	var seg: Dictionary = {"count": segments_left(), "size": segment_total()} if is_active() else {}
	items.publish(_slot(), key, PerkItems.entry(KIND, 0 if is_active() or cooldown_left > 0.0 else 1, 1,
		cooldown_left, active_left, -1, &"", seg))
