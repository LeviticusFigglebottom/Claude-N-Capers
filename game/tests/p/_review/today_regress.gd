## LEAD (2026-10-23) windowed regression pass on the day's trunk features that had no real-input check, one shot each:
##   copycat  Copycat (perk.understudy, D-164) with per-card picks (armor / dodge / dodge / crouch speed) and a mimicked
##            card 9 (perk.ironclad) in a live heist: the resolved keys on the crew slot, PerkCopycat present, and a
##            real-input crouch walk at crouch_speed x the picked mult.
##   roster   D4-03: Juno as the local player (FP sleeves) with Hale as a bot teammate, then Hale local with Juno as the
##            bot (third-person bodies, animated); a shot of each (FP, and the bot from the front).
##   smoke    D-163 Veil (Sicario): G throws the smoke bomb (real input), the cloud lands (SmokeZones / VfxDirector
##            smoke_cloud_fx fired), a shot of the cloud.
##   tether   D-163 Buddy System (Tag Team): G with a bot teammate on the aim line (<= tag_range_m) tags it (TagPairs),
##            the gas tether links the two bodies (VfxDirector tethers), a shot.
## Stated shortcuts: the bot is placed by teleport in front of the player (tether, roster); crew AI off; NPCs isolated.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --resolution 960x540 --path game \
##     res://tests/p/_review/today_regress.tscn -- --test=copycat|roster|smoke|tether|all --out=/abs/dir
## Output: "[TDR] ROW <test> | <item> | PASS|FAIL | <detail>" and "[TDR] RESULT".
## Owner: ENV P.
extends Node

const SEED: int = 30301
const COPYCAT_CHOICES: Dictionary = {0: 1, 2: 2, 4: 2, 6: 3}

var _out: String = "user://today_regress"
var _test: String = "all"
var _rt: HeistRuntime = null
var _inp: PInputDriver = null
var _ok: bool = true


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			_out = kv[1]
		elif kv[0] == "test" and kv.size() > 1:
			_test = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var tests: Array[String] = []
	tests.assign(["copycat", "roster", "smoke", "tether"] if _test == "all" else [_test])
	for t: String in tests:
		print("[TDR] === %s ===" % t)
		var m: String = "_t_" + t
		if not has_method(m):
			print("[TDR] RESULT FAIL %s (unknown test)" % t)
			_ok = false
			continue
		await Callable(self, m).call()
		await _teardown()
	print("[TDR] RESULT %s" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)


func _row(test: String, item: String, good: bool, detail: String) -> void:
	_ok = _ok and good
	print("[TDR] ROW %s | %s | %s | %s" % [test, item, "PASS" if good else "FAIL", detail])


func _loadout(heister: StringName = &"") -> Loadout:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	if heister != &"":
		l.heister = heister
	return l


func _launch(loadouts: Dictionary, mates: int) -> CrewController:
	_rt = await HeistLauncher.launch(&"dev_sandbox", SEED, Enums.Difficulty.ROUTINE, self,
		{"skip_casing": true, "crew_ai": false, "ai_teammates": mates, "loadouts": loadouts})
	_rt.isolate_npc(null)
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(6.0, 0.05, 11.0)))  # facing the yard (-Z)
	await _frames(30)
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	await _frames(30)
	return c


func _teardown() -> void:
	if _inp != null:
		_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await _frames(5)


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(nm: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(PCaptureName.safe_path("%s/%s.png" % [_out, nm]))
	print("[TDR] shot %s/%s.png" % [_out, nm])


## Bot `slot` stood `ahead_m` in front of the player, facing it.
func _bot_ahead(slot: int, ahead_m: float) -> void:
	var p: Vector3 = Vector3(6.0, 0.05, 11.0 - ahead_m)
	_rt.teleport_crew(slot, Transform3D(Basis(Vector3.UP, PI), p))
	await _frames(20)


func _vfx() -> VfxDirector:
	var found: Array[Node] = get_tree().root.find_children("*", "VfxDirector", true, false)
	return found[0] as VfxDirector if not found.is_empty() else null


# --- copycat --------------------------------------------------------------------------------------------------------

func _t_copycat() -> void:
	var l: Loadout = _loadout()
	l.perk_deck = &"perk.understudy"
	l.perk_deck_cards = 9
	l.perk_choices = COPYCAT_CHOICES.duplicate()
	l.perk_mimic_deck = &"perk.ironclad"
	var c: CrewController = await _launch({0: l}, 0)
	var armor: float = Modifiers.mult(c.slot, &"defense.armor_mult")
	var dodge: float = Modifiers.add(c.slot, &"defense.dodge_add")
	var crouch: float = Modifiers.mult(c.slot, &"movement.crouch_speed_mult")
	# armor: the card-1 pick (x1.05) plus Ironclad's mimicked card 9 (mimic_grants x1.05), additive as PD2: x1.10.
	_row("copycat", "card picks + mimic applied in the heist (armor / 2 x dodge / crouch)", is_equal_approx(armor, 1.10)
		and is_equal_approx(dodge, 0.1) and is_equal_approx(crouch, 1.1), "armor x%.2f, dodge +%.2f, crouch x%.2f" % [
		armor, dodge, crouch])
	var perks: CrewPerks = PerkHooks.of(c)
	var cc: PerkComponent = perks.component(PerkCopycat.KEY) if perks != null else null
	_row("copycat", "PerkCopycat live (fixed behaviours)", cc != null, "component %s" % cc)
	var team: float = Modifiers.mult(c.slot, &"team.armor_regen_delay_mult")
	_row("copycat", "mimicked card 9 (Ironclad team armor regen)", team < 1.0, "team.armor_regen_delay_mult x%.2f" % team)
	_inp.press(&"crouch")
	_inp.press(&"move_forward")
	await _seconds(1.2)
	var v: Vector3 = c.velocity
	var speed: float = Vector2(v.x, v.z).length()
	_inp.release_all()
	var want: float = Tweak.crew().crouch_speed * crouch
	_row("copycat", "real-input crouch walk at the picked speed", absf(speed - want) < 0.15, "%.2f m/s (want %.2f)" % [
		speed, want])
	await _frames(20)
	await _shot("copycat_in_heist")


# --- roster ---------------------------------------------------------------------------------------------------------

func _t_roster() -> void:
	for pair: Array in [[&"juno", &"hale"], [&"hale", &"juno"]]:
		var c: CrewController = await _launch({0: _loadout(pair[0]), 1: _loadout(pair[1])}, 1)
		var vm: FpViewmodel = FpViewmodel.of(CrewView.of(c).camera())
		var sleeves: PackedScene = FpViewmodelTweak.data().sleeve_scenes.get(pair[0], null)
		_row("roster", "%s local: FP sleeves wired" % pair[0], vm != null and sleeves != null, "viewmodel %s, sleeves %s" % [
			vm != null, sleeves.resource_path if sleeves != null else "none"])
		await _shot("roster_%s_fp" % pair[0])
		await _bot_ahead(1, 3.0)
		var mate: CrewController = _rt.crew_controller(1) as CrewController
		var body: Node = mate.get_node(^"Visual").get_child(0)
		var is_body: bool = body.scene_file_path.contains("crew_%s" % pair[1])
		_row("roster", "%s bot: third-person body, animated" % pair[1], is_body and AnimDriver.of(mate) != null,
			"body %s" % body.scene_file_path)
		await _frames(20)
		await _shot("roster_%s_bot" % pair[1])
		await _teardown()


# --- smoke ----------------------------------------------------------------------------------------------------------

func _t_smoke() -> void:
	var l: Loadout = _loadout()
	l.perk_deck = &"perk.veil"
	l.perk_deck_cards = 9
	await _launch({0: l}, 0)
	var vfx: VfxDirector = _vfx()
	var fired0: int = vfx.smoke.fired if vfx != null and vfx.smoke != null else -1
	await _inp.tap(&"throw_item")
	await _seconds(2.5)
	var fired: int = vfx.smoke.fired if vfx != null and vfx.smoke != null else -1
	var zones: Array[Node] = get_tree().root.find_children("*", "ThrownItem", true, false)
	_row("smoke", "G throws the smoke bomb; the cloud fx fires", fired > fired0, "vfx %s, smoke fired %d -> %d, %d thrown" % [
		vfx != null, fired0, fired, zones.size()])
	await _shot("smoke_cloud")


# --- tether ---------------------------------------------------------------------------------------------------------

func _t_tether() -> void:
	var l: Loadout = _loadout()
	l.perk_deck = &"perk.buddy_system"
	l.perk_deck_cards = 9
	var c: CrewController = await _launch({0: l, 1: _loadout()}, 1)
	await _bot_ahead(1, 6.0)
	var vfx: VfxDirector = _vfx()
	await _inp.tap(&"throw_item")
	await _seconds(1.0)
	var tp: TagPairs = TagPairs.of(_rt)
	var tagged: int = tp.tagged_of(c.slot) if tp != null else -1
	var links: int = vfx.tethers.active_count() if vfx != null and vfx.tethers != null else -1
	_row("tether", "G tags the bot on the aim line; the tether links them", tagged == 1 and links > 0,
		"tagged slot %d, tethers %d" % [tagged, links])
	await _shot("tether_linked")
