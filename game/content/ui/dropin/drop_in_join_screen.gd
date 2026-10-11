## Joining player's drop-in screen (B6-04, PD2 drop-in). Owner: ENV B.
## 1. Pick: the loadout screen in compact mode (LoadoutScreen.compact_mode: no skills / perks / workshop /
##    masks buttons; its Launch reads "Drop In"). Back leaves (back_requested).
## 2. Joining: request_join(summary) on the drop-in service (LobbyState.summary_from of the picked loadout),
##    then a progress panel: "waiting for the host" until the first join_progress, then the load percentage,
##    with Cancel (cancel_join, then back_requested). joined(slot) -> `joined`; join_failed -> the reason
##    (`ui.dropin.failed.<reason>`) and Cancel turns into Back.
## The service is duck-typed (DropInService interface); MockDropInService until ENV A's lands.
class_name DropInJoinScreen
extends UiScreen

signal joined(slot: int)
signal join_failed(reason: StringName)

enum Phase { PICK, JOINING, JOINED, FAILED }

const LOADOUT_SCENE: PackedScene = preload("res://content/ui/menus/loadout.tscn")

## Profile slot the loadout saves to.
var profile_slot: int = 0
var profile: PlayerProfile = null
## The drop-in service (duck-typed), or null.
var service: Object = null
var phase: Phase = Phase.PICK
var loadout_screen: LoadoutScreen
var progress_panel: Control
var status_label: Label
var progress_bar: ProgressBar
var cancel_button: Button


## Before entering the tree: the service and the profile whose loadout is picked.
func setup(p_service: Object, p: PlayerProfile = null) -> void:
	service = p_service
	if p != null:
		profile = p


func build_ui() -> void:
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	loadout_screen = LOADOUT_SCENE.instantiate() as LoadoutScreen
	loadout_screen.compact_mode = true
	loadout_screen.profile_slot = profile_slot
	loadout_screen.setup(profile)
	add_child(loadout_screen)
	loadout_screen.launch_button.text = UiText.t(&"ui.dropin.join_button")
	loadout_screen.launch_requested.connect(request_join)
	loadout_screen.back_requested.connect(back_requested.emit)
	progress_panel = _build_progress()
	add_child(progress_panel)
	_bind()
	_show_phase(Phase.PICK)


func _build_progress() -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v: VBoxContainer = UiBuild.vbox(18)
	v.add_child(UiBuild.label(&"ui.dropin.joining", UiBuild.HEADER))
	status_label = UiBuild.label(&"ui.dropin.waiting_host", UiBuild.DIM)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(640, 0)
	v.add_child(status_label)
	progress_bar = UiBuild.bar(UiBuild.theme().get_color(&"accent", &"Screen"), Vector2(640, 18))
	v.add_child(progress_bar)
	cancel_button = UiBuild.button(&"ui.dropin.cancel")
	cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_button.pressed.connect(cancel)
	v.add_child(cancel_button)
	center.add_child(UiBuild.panel(v))
	return center


func _bind() -> void:
	if service == null:
		return
	var pairs: Array = [[&"join_progress", _on_progress], [&"joined", _on_joined], [&"join_failed", _on_failed]]
	for p: Array in pairs:
		if service.has_signal(p[0]) and not service.is_connected(p[0], p[1]):
			service.connect(p[0], p[1])


## Send the join request with `loadout` (Launch on the compact loadout screen). False without a service.
func request_join(loadout: Loadout) -> bool:
	if service == null or not service.has_method(&"request_join") or phase == Phase.JOINING:
		return false
	service.call(&"request_join", LobbyState.summary_from(loadout, profile))
	_show_phase(Phase.JOINING)
	return true


## Cancel: while joining, cancel_join on the service; then leave the screen (back_requested).
func cancel() -> void:
	if phase == Phase.JOINING and service != null and service.has_method(&"cancel_join"):
		phase = Phase.FAILED  # the cancelled join_failed that follows must not re-show anything
		service.call(&"cancel_join")
	back_requested.emit()


func progress() -> float:
	return progress_bar.value


func _show_phase(p: Phase) -> void:
	phase = p
	loadout_screen.visible = p == Phase.PICK
	progress_panel.visible = p != Phase.PICK
	cancel_button.text = UiText.t(&"ui.menu.back" if p == Phase.FAILED else &"ui.dropin.cancel")
	cancel_button.visible = p != Phase.JOINED
	if p == Phase.JOINING:
		progress_bar.value = 0.0
		status_label.text = UiText.t(&"ui.dropin.waiting_host")
	focus_chain.clear()
	if p == Phase.PICK:
		loadout_screen.focus_default()
	elif cancel_button.visible:
		focus_chain.append(cancel_button)
		focus_default()


func _on_progress(_peer_id: int, frac: float) -> void:
	if phase != Phase.JOINING:
		return
	progress_bar.value = clampf(frac, 0.0, 1.0)
	status_label.text = UiText.t(&"ui.dropin.progress", {"pct": roundi(progress_bar.value * 100.0)})


func _on_joined(slot: int) -> void:
	if phase != Phase.JOINING:
		return
	progress_bar.value = 1.0
	_show_phase(Phase.JOINED)
	status_label.text = UiText.t(&"ui.dropin.joined")
	joined.emit(slot)


func _on_failed(_peer_id: int, reason: StringName) -> void:
	if phase != Phase.JOINING:
		return
	_show_phase(Phase.FAILED)
	var known: bool = DropInService.REASONS.has(reason)
	status_label.text = UiText.t(StringName("ui.dropin.failed.%s" % reason) if known else &"ui.dropin.failed.unknown")
	join_failed.emit(reason)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or phase == Phase.PICK or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if phase != Phase.JOINED:
		cancel()
