## D-162 perk.yakuza (Inkwork; PD2 Yakuza Irezumi). Owner: ENV A. Schema: B's perk_decks.md. s = 0 at full health,
## rising linearly to 1 at low_health_threshold and staying 1 below it (card 9 Oni: 0.25 -> 0.5). The armor regen delay
## counts down (1 + armor_regen_max_add x s) times as fast (defense.armor_regen_delay_mult = 1 / that) and move speed is
## x (1 + move_speed_max_add x s). Applied as a CrewBuffs grant (BUFF: replicated, so a client's own movement prediction
## gets the speed too), refreshed when the quantized bonus changes. blocks_regen (card 1): while s > 0, other health
## regeneration (defense.health_regen_per_sec) is off.
class_name PerkYakuza
extends PerkComponent

const KEY: StringName = &"perk.yakuza"
const BUFF: StringName = &"perk_yakuza"
## Bonus quantum (a regrant per change; health moves continuously) and the buff lifetime between refreshes.
const STEP: float = 0.01
const BUFF_S: float = 1.0

var _last: Vector2 = Vector2(-1.0, -1.0)


## s, 0..1: 0 at full health, 1 at low_health_threshold and below.
func factor() -> float:
	var t: float = num("low_health_threshold")
	return clampf((1.0 - _health_frac()) / maxf(1.0 - t, 0.001), 0.0, 1.0)


func tick(_delta: float) -> void:
	var buffs: CrewBuffs = CrewBuffs.of(HeistRuntime.of(crew))
	if buffs == null:
		return
	var f: float = factor()
	var v: Vector2 = Vector2(snappedf(num("armor_regen_max_add") * f, STEP), snappedf(num("move_speed_max_add") * f, STEP))
	if v == Vector2.ZERO:
		if _last != Vector2.ZERO:
			buffs.end(_slot(), BUFF)
		_last = v
		return
	if v != _last or buffs.left(_slot(), BUFF) < BUFF_S * 0.5:
		buffs.grant(_slot(), BUFF, {&"defense.armor_regen_delay_mult": 1.0 / (1.0 + v.x), &"movement.speed_mult": 1.0 + v.y},
			BUFF_S)
		_last = v


## CrewHealth: `crew` holds Yakuza with blocks_regen and s > 0.
static func blocks_regen(c: CrewController) -> bool:
	var perks: CrewPerks = PerkHooks.of(c)
	var y: PerkYakuza = perks.component(KEY) as PerkYakuza if perks != null else null
	return y != null and bool(y.param("blocks_regen", false)) and y.factor() > 0.0
