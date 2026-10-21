## 3P motion coverage on loud play (D-130 follow-up, LEAD 2026-10-17): a heist launched as the game does
## (HeistLauncher), crew AI on, the alarm raised at once, then N seconds of game time with ENV P's AnimCoverage
## (tests/p/_review/anim_coverage.gd, unchanged) riding along. That records the clips that play per body class and
## the FROZEN / PLAYER_MISMATCH / SLIDE / STATIC flags (definitions in its header). Much faster than a real-menu pass:
## run it headless (animation and skeletons still update) or windowed for a sanity look.
##   /opt/godot/godot --headless --path game res://world/characters/_tools/loud_anim_coverage.tscn -- \
##     --heist=dockside_burn --anim-out=/abs/dir [--seconds=240] [--seed=1002] [--difficulty=4] [--bots=3]
## Stealth coverage (OF done check, D-150): `--stealth` keeps the alarm down (no crew AI; the player stands at the
## start), `--tie-manager-at=S` has the player shout down and tie the first civ_manager* civilian at S s (harness: the
## same CivilianBrain calls a shout and a cable tie make), `--alarm-at=S` raises the alarm at S s (the cower reactions).
## Writes <anim-out>/anim_coverage.json and prints "[LOUDCOV] RESULT ..." with the flag counts. Owner: ENV D.
extends Node

var _heist: String = "dockside_burn"
var _seconds: float = 240.0
var _seed: int = 1002
var _difficulty: int = Enums.Difficulty.LETHAL
var _bots: int = 3
var _stealth: bool = false
var _alarm_at: float = -1.0
var _tie_at: float = -1.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"heist": _heist = v
			"seconds": _seconds = float(v)
			"seed": _seed = int(v)
			"difficulty": _difficulty = int(v)
			"bots": _bots = int(v)
			"stealth": _stealth = true
			"alarm-at": _alarm_at = float(v)
			"tie-manager-at": _tie_at = float(v)
	if _stealth:
		_bots = 0
	var cov: Node = Node.new()
	cov.name = "AnimCoverage"
	cov.set_script(load("res://tests/p/_review/anim_coverage.gd"))
	get_tree().root.add_child.call_deferred(cov)   # outlives this scene, flushes on exit
	# every slot wears a heister body (CrewTweak.body_scenes), as the lobby assigns them; without one a bot is a capsule
	var heisters: Array = Tweak.crew().body_scenes.keys()
	heisters.sort()
	var loadouts: Dictionary = {}
	for slot: int in _bots + 1:
		var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
		l.heister = StringName(heisters[slot % heisters.size()]) if not heisters.is_empty() else &""
		loadouts[slot] = l
	var rt: HeistRuntime = await HeistLauncher.launch(StringName(_heist), _seed, _difficulty, self,
			{"ai_teammates": _bots, "crew_ai": not _stealth, "loadouts": loadouts})
	for _i: int in 30:
		await get_tree().physics_frame
	if not _stealth:
		rt.stealth.raise_alarm(&"d_loud_coverage")
	var start: int = Time.get_ticks_msec()
	var ticks: int = int(_seconds * Engine.physics_ticks_per_second)
	var hz: int = Engine.physics_ticks_per_second
	for i: int in ticks:
		await get_tree().physics_frame
		if _tie_at >= 0.0 and i == int(_tie_at * hz):
			_tie_manager(rt)
		if _alarm_at >= 0.0 and i == int(_alarm_at * hz):
			rt.stealth.raise_alarm(&"d_stealth_coverage")
			print("[LOUDCOV] alarm raised at t=%.0f s" % _alarm_at)
		if i % (Engine.physics_ticks_per_second * 30) == 0:
			print("[LOUDCOV] t=%.0f s game, %.0f s wall, npcs=%d" % [float(i) / Engine.physics_ticks_per_second,
				(Time.get_ticks_msec() - start) / 1000.0, rt.npcs().size()])
	cov.queue_free()
	await get_tree().process_frame
	print("[LOUDCOV] RESULT heist=%s seconds=%.0f done" % [_heist, _seconds])
	get_tree().quit(0)


## The player (slot 0) shouts the first civ_manager* civilian down and ties them (CivilianBrain.on_shouted, then the
## tie interaction's completion), as a player at the manager would.
func _tie_manager(rt: HeistRuntime) -> void:
	var cc: CrewController = rt.crew_controller(0) as CrewController
	for n: NpcBase in rt.npcs():
		var tags: Variant = n.spawn_info.get("tags", [])
		var mgr: bool = false
		for t: Variant in (tags as Array if tags is Array else []):
			mgr = mgr or String(t).begins_with("civ_manager")
		if not mgr:
			continue
		var brain: CivilianBrain = null
		for c: Node in n.find_children("*", "", true, false):
			if c is CivilianBrain:
				brain = c as CivilianBrain
				break
		if brain == null:
			continue
		var shouted: bool = brain.on_shouted(cc)
		brain.call(&"_on_tie_completed", cc)
		print("[LOUDCOV] manager %s: shouted=%s tied=%s" % [n.name, shouted, brain.is_tied()])
		return
	print("[LOUDCOV] no civ_manager civilian found")
