## PO6-17: RNG assault events on the HUD: a red world marker per live event (clamped off-screen) and their names on the
## assault banner; both clear on assault_event_ended.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _hud: Hud
var _model: MockHudModel
var _world: Node3D


func before_each() -> void:
	_world = Node3D.new()
	add_child(_world)
	var cam: Camera3D = Camera3D.new()
	_world.add_child(cam)
	cam.current = true
	_model = MockHudModel.new()
	add_child(_model)
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)
	_model.assault_phase = Enums.AssaultPhase.SUSTAIN


func after_each() -> void:
	_hud.queue_free()
	_model.queue_free()
	_world.queue_free()
	await wait_frames(2)


func _drawn(id: int) -> Dictionary:
	for d: Dictionary in _hud.assault_events.drawn:
		if int(d["net_id"]) == id:
			return d
	return {}


func test_events_show_markers_and_banner_names() -> void:
	assert_true(_hud.widgets().has(_hud.assault_events))
	EventBus.assault_event_started.emit(&"breach", 901, Vector3(0, 0, -10))
	await wait_frames(2)
	var d: Dictionary = _drawn(901)
	assert_false(d.is_empty(), "breach marker drawn")
	assert_eq(String(d["label"]), "BREACH")
	assert_false(bool(d["clamped"]), "in view")
	assert_true(_hud.assault.events_label.visible and _hud.assault.events_label.text == "BREACH")
	EventBus.assault_event_started.emit(&"heli", 902, Vector3(0, 30, 40))
	await wait_frames(2)
	assert_true(bool(_drawn(902)["clamped"]), "behind the camera -> clamped to an edge")
	assert_eq(_hud.assault.events_label.text, "BREACH · HELICOPTER")
	EventBus.assault_event_ended.emit(&"breach", 901)
	await wait_frames(2)
	assert_true(_drawn(901).is_empty(), "ended breach removed")
	assert_eq(_hud.assault.events_label.text, "HELICOPTER")
	EventBus.assault_event_ended.emit(&"heli", 902)
	await wait_frames(2)
	assert_true(_hud.assault_events.drawn.is_empty())
	assert_false(_hud.assault.events_label.visible, "line hidden with no events")


func test_turret_van_name() -> void:
	assert_eq(AssaultEventMarkers.kind_text(&"turret_van"), "TURRET VAN")
	assert_eq(AssaultEventMarkers.kind_text(&"unknown_thing"), "INCOMING")


## r227 crowding audit: with the captain present, his panel sits under the banner's real bottom, so the events line
## the banner grows ("TURRET VAN") stays visible; without events it keeps its usual spot.
func test_captain_panel_clears_the_events_line() -> void:
	_model.captain_present = true
	_model.captain_resistance = 0.25
	await wait_frames(3)
	var base_top: float = _hud.captain.get_global_rect().position.y
	EventBus.assault_event_started.emit(&"turret_van", 91, Vector3(0, 0, -10))
	await wait_frames(4)
	var banner: Rect2 = _hud.assault.panel.get_global_rect()
	var cap: Rect2 = _hud.captain.get_global_rect()
	assert_true(_hud.assault.events_label.is_visible_in_tree(), "events line shown")
	assert_true(cap.position.y >= banner.end.y - 0.5, "captain below the banner (%s vs %s)" % [cap, banner])
	EventBus.assault_event_ended.emit(&"turret_van", 91)
	await wait_frames(4)
	assert_near(_hud.captain.get_global_rect().position.y, base_top, 1.0, "back to its spot without events")
