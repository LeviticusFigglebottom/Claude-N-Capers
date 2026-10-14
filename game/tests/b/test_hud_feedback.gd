## Lead round 62 gameplay feedback: hit marker kinds (headshot = palette armor role), only the local player's hits,
## and the low-health vignette + heartbeat.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")
const ME: int = 501

var _hud: Hud
var _model: MockHudModel


func before_each() -> void:
	_model = MockHudModel.new()
	_model.local_net_id = ME
	add_child(_model)
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)
	UiSfx.played.clear()


func after_each() -> void:
	_hud.queue_free()
	_model.queue_free()
	await wait_frames(1)


func _hit(victim: int, attacker: int, extra: Dictionary = {}) -> void:
	var info: Dictionary = {"amount": 30.0, "zone": Enums.HitZone.BODY, "killed": false, "crit": false,
		"direction": Vector3(0, 0, -1)}
	info.merge(extra, true)
	EventBus.damage_applied.emit(victim, attacker, info)


func test_hit_headshot_and_kill_markers() -> void:
	var hf: HitFeedback = _hud.hit_feedback
	_hit(900, ME)
	assert_eq(hf.kind, &"hit")
	assert_true(UiSfx.played.has(UiSfx.HIT), "hit cue requested")
	hf._process(1.0)
	_hit(900, ME, {"zone": Enums.HitZone.HEAD})
	assert_eq(hf.kind, &"headshot")
	_hit(900, ME, {"killed": true})
	assert_eq(hf.kind, &"kill")
	_hit(901, ME)
	assert_eq(hf.kind, &"kill", "the kill confirm is not cut short by the rest of the burst")
	hf._process(HitFeedback.T_KILL + 0.01)
	assert_eq(hf.kind, &"", "fades out")


func test_only_my_damage_counts() -> void:
	var hf: HitFeedback = _hud.hit_feedback
	_hit(900, 777)
	assert_eq(hf.kind, &"", "a teammate's hit shows nothing")
	_hit(900, ME, {"amount": 0.0})
	assert_eq(hf.kind, &"", "a blocked (0 damage) hit shows nothing")
	_model.local_net_id = 0
	_hit(900, ME)
	assert_eq(hf.kind, &"", "unknown local player: off")


func test_kill_event_confirms() -> void:
	EventBus.npc_killed.emit(900, ME, {})
	assert_eq(_hud.hit_feedback.kind, &"kill")


func test_damage_direction_arcs() -> void:
	var dd: DamageDirection = _hud.damage_direction
	_hit(ME, 900, {"health_damage": 0.0, "armor_damage": 30.0})
	assert_eq(dd.arcs.size(), 1)
	assert_false(bool(dd.arcs[0]["health"]), "armor-only hit")
	assert_true((dd.arcs[0]["dir"] as Vector3).is_equal_approx(Vector3(0, 0, 1)), "points back to the source")
	_hit(ME, 900, {"health_damage": 12.0})
	assert_true(bool(dd.arcs[1]["health"]))
	_hit(900, ME)
	assert_eq(dd.arcs.size(), 2, "my own outgoing hit adds no arc")
	dd._process(DamageDirection.FADE_S + 0.01)
	assert_eq(dd.arcs.size(), 0, "arcs fade")


func test_screen_angle() -> void:
	var b: Basis = Basis.IDENTITY  # camera looks down -Z
	assert_near(DamageDirection.screen_angle(b, Vector3(0, 0, -1)), 0.0, 0.001, "in front = up")
	assert_near(DamageDirection.screen_angle(b, Vector3(1, 0, 0)), PI * 0.5, 0.001, "right")
	assert_near(absf(DamageDirection.screen_angle(b, Vector3(0, 0, 1))), PI, 0.001, "behind = down")


func test_low_health_vignette_and_heartbeat() -> void:
	var v: LowHealthVignette = _hud.low_health
	_model.max_health = 100.0
	_model.health = 80.0
	assert_false(v.visible)
	_model.health = 20.0
	assert_true(v.visible)
	v._process(0.01)
	assert_eq(v.beats, 1, "first beat right away")
	assert_true(UiSfx.played.has(UiSfx.HEARTBEAT))
	var slow: float = v.beat_period()
	_model.health = 5.0
	assert_true(v.beat_period() < slow, "lower health beats faster")
	_model.crew_state = Enums.CrewState.DOWNED
	assert_false(v.visible, "downed has its own screen")
	_model.crew_state = Enums.CrewState.NORMAL
	_model.health = 60.0
	assert_false(v.visible)
