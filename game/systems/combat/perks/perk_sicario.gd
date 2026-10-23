## D-163 perk.sicario (Veil; PD2 Sicario). Owner: ENV A. Schema: B's perk_decks.md. The deck throwable (perk.throwable
## item_id throwable.smoke_bomb, ThrowableDef kind ThrownItem.KIND_SMOKE) throws a smoke cloud (ThrownItem, SmokeZones)
## of smoke_radius_m for smoke_duration_s: crew inside avoid in_smoke_dodge_add of the bullets, enemies inside hit at
## x enemy_accuracy_mult. cooldown_s starts when the cloud ends; each holder kill cuts kill_cooldown_reduction_s.
##   Twitch (card 3): +twitch_dodge_add dodge per hit taken, stacking; a dodge resets it and blocks stacking for
##   twitch_lockout_s. Card 7: dodge_restores_armor refills the armor on a dodge (full, ◇).
##   Card 9: in_smoke_effect_mult scales Twitch and the deck's generic dodge (defense.dodge_add) while the holder stands
##   in smoke; ally_in_smoke_dodge_add for teammates inside the holder's cloud.
## No LOS blocking (PD2). Server only; the item state is published to PerkItems (HUD).
class_name PerkSicario
extends PerkComponent

const KEY: StringName = &"perk.sicario"

var twitch_stacks: int = 0
var twitch_lockout_left: float = 0.0
var cooldown_left: float = 0.0
## The holder's live cloud (null when none).
var cloud: ThrownItem = null


func use_throwable(kind: StringName) -> bool:
	if kind != ThrownItem.KIND_SMOKE or crew == null or cooldown_left > 0.0 or _cloud_live():
		return false
	var item_id: StringName = PerkHooks.throwable_id(crew)
	var def: ThrowableDef = ContentDB.throwable(item_id) if item_id != &"" else null
	if def == null:
		return false
	cloud = CrewThrowables.spawn(crew, def, 0, {
		"smoke_s": num("smoke_duration_s"), "radius_m": num("smoke_radius_m"),
		"crew_bullet_avoid": num("in_smoke_dodge_add"), "npc_accuracy_mult": num("enemy_accuracy_mult"),
	})
	cooldown_left = num("cooldown_s")
	return cloud != null


func tick(delta: float) -> void:
	twitch_lockout_left = maxf(twitch_lockout_left - delta, 0.0)
	if not _cloud_live():
		cloud = null
		cooldown_left = maxf(cooldown_left - delta, 0.0)  # the recharge runs once the cloud is gone
	var items: PerkItems = PerkItems.of(HeistRuntime.of(crew))
	if items != null:
		var active: float = cloud.pool_left if cloud != null and cloud.landed else 0.0
		items.publish(_slot(), key, PerkItems.entry(ThrownItem.KIND_SMOKE, 0 if cooldown_left > 0.0 else 1, 1,
			cooldown_left, active))



func on_kill(_victim: Node, _info: Dictionary) -> void:
	if not _cloud_live():
		cooldown_left = maxf(cooldown_left - num("kill_cooldown_reduction_s"), 0.0)


func after_hit(out: Dictionary) -> void:
	if twitch_lockout_left <= 0.0 and num("twitch_dodge_add") > 0.0 and float(out.get("amount", 0.0)) > 0.0:
		twitch_stacks += 1


func on_dodge() -> void:
	twitch_stacks = 0
	twitch_lockout_left = num("twitch_lockout_s")
	var h: CrewHealth = _health()
	if bool(param("dodge_restores_armor", false)) and h != null:
		h.armor = h.max_armor


func dodge_add() -> float:
	var m: float = effect_mult()
	var generic: float = maxf(Modifiers.add(_slot(), &"defense.dodge_add"), 0.0)
	return twitch_stacks * num("twitch_dodge_add") * m + generic * (m - 1.0)


## in_smoke_effect_mult while the holder stands in any smoke cloud, else 1.
func effect_mult() -> float:
	var m: float = float(param("in_smoke_effect_mult", 1.0))
	return m if m != 1.0 and SmokeZones.in_smoke(crew) else 1.0


func ally_dodge_add_for(target: CrewController) -> float:
	if target == crew or not _cloud_live() or num("ally_in_smoke_dodge_add") <= 0.0:
		return 0.0
	return num("ally_in_smoke_dodge_add") if SmokeZones.cloud_at(target, target.global_position) == cloud else 0.0


func _cloud_live() -> bool:
	return cloud != null and is_instance_valid(cloud) and not cloud.is_queued_for_deletion() \
		and (not cloud.landed or cloud.pool_left > 0.0)
