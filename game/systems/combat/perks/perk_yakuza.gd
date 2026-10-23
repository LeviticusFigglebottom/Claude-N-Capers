## D-162 perk.yakuza (PD2 Yakuza). Owner: ENV A. Below `threshold` of max health the holder's armor regen rate rises by
## up to armor_regen_bonus and its move speed by up to move_speed_bonus, linear from 0 at the threshold to the full
## bonus at 0 health (card 9 Oni moves the threshold 0.25 -> 0.5). Applied as a CrewBuffs grant (BUFF: replicated, so a
## client's own movement prediction gets the speed too), refreshed when the quantized bonus changes. blocks_regen
## (card 1): while the bonus is up, third-party health regen (defense.health_regen_per_sec) is off.
class_name PerkYakuza
extends PerkComponent

const KEY: StringName = &"perk.yakuza"
const BUFF: StringName = &"perk_yakuza"
## Bonus quantum (a regrant per change; health moves continuously) and the buff lifetime between refreshes.
const STEP: float = 0.01
const BUFF_S: float = 1.0

var _last: Vector2 = Vector2(-1.0, -1.0)


## 0..1: how far below the threshold the holder's health is.
func factor() -> float:
	var t: float = num("threshold")
	return clampf(1.0 - _health_frac() / t, 0.0, 1.0) if t > 0.0 else 0.0


func tick(_delta: float) -> void:
	var buffs: CrewBuffs = CrewBuffs.of(HeistRuntime.of(crew))
	if buffs == null:
		return
	var f: float = factor()
	var v: Vector2 = Vector2(snappedf(num("armor_regen_bonus") * f, STEP), snappedf(num("move_speed_bonus") * f, STEP))
	if v == Vector2.ZERO:
		if _last != Vector2.ZERO:
			buffs.end(_slot(), BUFF)
		_last = v
		return
	if v != _last or buffs.left(_slot(), BUFF) < BUFF_S * 0.5:
		buffs.grant(_slot(), BUFF, {&"defense.armor_regen_rate_mult": 1.0 + v.x, &"movement.speed_mult": 1.0 + v.y}, BUFF_S)
		_last = v


## CrewHealth: `crew` holds Yakuza with blocks_regen and is below its threshold.
static func blocks_regen(c: CrewController) -> bool:
	var perks: CrewPerks = PerkHooks.of(c)
	var y: PerkYakuza = perks.component(KEY) as PerkYakuza if perks != null else null
	return y != null and bool(y.param("blocks_regen", false)) and y.factor() > 0.0
