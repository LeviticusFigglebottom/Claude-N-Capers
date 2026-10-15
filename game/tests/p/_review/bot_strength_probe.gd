## PO6-15 bot strength probe (headless is fine: numbers, not pictures): a loud heist with AI teammates and a passive
## human (empty bot intent on slot 0, so the AI crew fights alone). Counts, per crew slot: kills, shots, hits, damage
## dealt, downs; police alive over time; assault phases. Prints `[BOTS] ...` lines and a RESULT summary.
##   /opt/godot/godot --headless --path game res://tests/p/_review/bot_strength_probe.tscn -- \
##     [--heist=glasshouse] [--seed=1002] [--bots=3] [--secs=240] [--set=ai_damage_mult:0.5,ai_reaction_time_s:0.6]
##   (--set overrides CrewTweak fields for this run)
## Owner: ENV P.
extends Node

var _heist: StringName = &"glasshouse"
var _seed: int = 1002
var _bots: int = 3
var _secs: float = 240.0
var _rt: HeistRuntime = null
## crew net_id -> slot
var _slot_of: Dictionary = {}
var _kills: Dictionary = {}
var _hits: Dictionary = {}
var _dmg: Dictionary = {}
var _shots: Dictionary = {}
var _downs: Dictionary = {}
var _police_kills_other: int = 0
var _t: float = 0.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"heist": _heist = StringName(v)
			"seed": _seed = int(v)
			"bots": _bots = int(v)
			"secs": _secs = float(v)
			"set":
				for pair: String in v.split(",", false):
					var f: PackedStringArray = pair.split(":")
					Tweak.crew().set(f[0], float(f[1]))
	_rt = await HeistLauncher.launch(_heist, _seed, Enums.Difficulty.ROUTINE, self, {"ai_teammates": _bots})
	await get_tree().physics_frame
	_rt.set_bot_intent(0, CrewIntent.new())  # the human stands still and never shoots
	for c: CrewController in _rt.crew_members():
		_slot_of[c.net_id] = c.slot
		for d: Dictionary in [_kills, _hits, _shots, _downs]:
			d[c.slot] = 0
		_dmg[c.slot] = 0.0
	EventBus.npc_killed.connect(_on_killed)
	EventBus.damage_applied.connect(_on_damage)
	EventBus.weapon_fired.connect(_on_fired)
	if EventBus.has_signal(&"crew_downed"):
		EventBus.connect(&"crew_downed", _on_downed)
	_rt.stealth.raise_alarm(&"test", 0)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var next_print: float = 0.0
	while _t < _secs:
		await get_tree().physics_frame
		_t += get_physics_process_delta_time()
		if _t >= next_print:
			next_print += 20.0
			print("[BOTS] t=%3.0f phase=%s police_alive=%d kills=%s downs=%s states=%s" % [_t,
				dir.assault_phase if dir != null else -1, _rt.npcs().size(), _kills, _downs, _states()])
	var bot_kills: int = 0
	var bot_shots: int = 0
	var bot_hits: int = 0
	var bot_dmg: float = 0.0
	for c: CrewController in _rt.crew_members():
		if c.is_ai:
			bot_kills += int(_kills[c.slot])
			bot_shots += int(_shots[c.slot])
			bot_hits += int(_hits[c.slot])
			bot_dmg += float(_dmg[c.slot])
	print(("[BOTS] RESULT heist=%s seed=%d bots=%d secs=%.0f bot_kills=%d kills_per_min=%.1f shots=%d hits=%d acc=%.2f"
		+ " dmg=%.0f dmg_per_hit=%.1f downs=%s police_alive_end=%d") % [
		_heist, _seed, _bots, _secs, bot_kills, bot_kills / (_secs / 60.0), bot_shots, bot_hits,
		float(bot_hits) / maxf(bot_shots, 1.0), bot_dmg, bot_dmg / maxf(bot_hits, 1.0), _downs, _rt.npcs().size()])
	_rt.teardown()
	get_tree().quit(0)


func _states() -> String:
	var out: PackedStringArray = []
	for c: CrewController in _rt.crew_members():
		out.append("%d:%d" % [c.slot, c.crew_state])
	return ",".join(out)


func _on_killed(_npc: int, killer: int, _info: Dictionary) -> void:
	if _slot_of.has(killer):
		_kills[_slot_of[killer]] += 1
	else:
		_police_kills_other += 1


func _on_damage(victim: int, attacker: int, info: Dictionary) -> void:
	if _slot_of.has(attacker) and not _slot_of.has(victim):
		_hits[_slot_of[attacker]] += 1
		_dmg[_slot_of[attacker]] += float(info.get("amount", info.get("damage", 0.0)))


func _on_fired(shooter: int, _w: StringName, _s: bool, _p: Vector3) -> void:
	if _slot_of.has(shooter):
		_shots[_slot_of[shooter]] += 1


func _on_downed(slot: int, _a: Variant = null, _b: Variant = null) -> void:
	if _downs.has(slot):
		_downs[slot] += 1
