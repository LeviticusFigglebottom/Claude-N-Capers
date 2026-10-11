## Safehouse jukebox (B5-03, D-062). Owner: ENV B. Station `jukebox` (MenuFlow.open_station); Back returns
## to the hub. Lists every MusicCatalog track: name, Unlocked / locked with the Notoriety rank that
## unlocks it, and Play; Stop ends the preview. Playback is ENV C's: when the global class MusicDirector
## exists AND has `preview(track_id, stem := &"assault")`, one director is instanced as a child and driven
## with call(&"preview", id) / call(&"stop_preview") (Music bus). Without that API every Play is disabled
## and a notice says previews arrive with the music update. B never plays stems itself.
## Hiding or leaving the screen (Back, Esc / gamepad B, freed by MenuFlow) stops the preview.
## API: setup(profile) before or after entering the tree; play(id) -> bool; stop(); preview_available().
## 3D safehouse (B6-06, QC-48): MenuFlow sets `preview_target` (the safehouse's jukebox cabinet, same
## preview(id[, stem]) / stop_preview() duck API) before the screen enters the tree; previews then play
## positionally at the cabinet and no director is instanced. Without it (2D hub) the bare director is used.
class_name JukeboxScreen
extends UiScreen

const DIRECTOR_CLASS: StringName = &"MusicDirector"
const PREVIEW_METHOD: StringName = &"preview"
const STOP_METHOD: StringName = &"stop_preview"

@export var profile_slot: int = 0

var profile: PlayerProfile = null
## Preview target set by MenuFlow in the 3D safehouse (the cabinet, not owned by the screen), else null.
var preview_target: Node = null
## The node previews go through: preview_target, or ENV C's MusicDirector child (null while its preview
## API is missing).
var director: Node = null
## Track being previewed (&"" = none).
var now_playing: StringName = &""
var notice_label: Label
var now_label: Label
var list: VBoxContainer
var stop_button: Button
var back_button: Button
## Track id -> its Play button.
var play_buttons: Dictionary = {}
## Track id -> its status Label.
var status_labels: Dictionary = {}


func setup(p: PlayerProfile) -> void:
	profile = p
	if list != null:
		refresh()


## True when ENV C's MusicDirector exists and has preview() (looked up by name: no hard dependency).
static func preview_available() -> bool:
	var script: Script = UiNav.global_class(DIRECTOR_CLASS)
	if script == null:
		return false
	for m: Dictionary in script.get_script_method_list():
		if StringName(m["name"]) == PREVIEW_METHOD:
			return true
	return false


func build_ui() -> void:
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	if preview_target != null and is_instance_valid(preview_target) and preview_target.has_method(PREVIEW_METHOD):
		director = preview_target
	elif preview_available():
		director = (UiNav.global_class(DIRECTOR_CLASS).new()) as Node
		if director != null:
			if &"listen_to_event_bus" in director:
				director.set(&"listen_to_event_bus", false)
			director.name = "PreviewDirector"
			add_child(director)
	var root: VBoxContainer = UiBuild.vbox(18)
	UiBuild.screen_margin(self, root)
	root.add_child(UiBuild.label(&"ui.jukebox.title", UiBuild.HEADER))
	root.add_child(UiBuild.label(&"ui.jukebox.subtitle", UiBuild.DIM))
	notice_label = UiBuild.label(&"ui.jukebox.preview_missing", UiBuild.SUBHEADER)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.visible = director == null
	root.add_child(notice_label)
	now_label = UiBuild.label(&"", UiBuild.DIM)
	root.add_child(now_label)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	root.add_child(scroll)
	list = UiBuild.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var footer: HBoxContainer = UiBuild.hbox(16)
	stop_button = UiBuild.button(&"ui.jukebox.stop")
	stop_button.pressed.connect(stop)
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	footer.add_child(back_button)
	footer.add_child(stop_button)
	root.add_child(footer)
	back_requested.connect(stop)
	visibility_changed.connect(_on_hidden_check)
	refresh()


## Rebuilds the track rows from MusicCatalog and the profile's unlocks.
func refresh() -> void:
	for c: Node in list.get_children():
		list.remove_child(c)
		c.queue_free()
	play_buttons.clear()
	status_labels.clear()
	focus_chain.clear()
	for t: Dictionary in MusicCatalog.tracks():
		var id: StringName = t["id"]
		list.add_child(_row(id))
		var b: Button = play_buttons[id] as Button
		if not b.disabled:
			focus_chain.append(b)
	focus_chain.append(back_button)
	focus_chain.append(stop_button)
	UiNav.chain_vertical(focus_chain)
	_refresh_state()


## Starts previewing `track_id` through ENV C's MusicDirector. False when the preview API is missing,
## or the track is unknown or locked.
func play(track_id: StringName) -> bool:
	if director == null or not MusicCatalog.is_unlocked(profile, track_id):
		return false
	# C's preview() -> bool (D-062): false when the track has no stems yet; then nothing plays.
	if director.call(PREVIEW_METHOD, track_id) == false:
		now_label.text = UiText.t(&"ui.jukebox.no_stems", {"name": UiText.t(MusicCatalog.display_key(track_id))})
		return false
	now_playing = track_id
	_refresh_state()
	return true


## Stops the preview (no-op when nothing plays).
func stop() -> void:
	if now_playing == &"":
		return
	if director != null and director.has_method(STOP_METHOD):
		director.call(STOP_METHOD)
	now_playing = &""
	_refresh_state()


func _exit_tree() -> void:
	stop()


func _row(id: StringName) -> PanelContainer:
	var unlocked: bool = MusicCatalog.is_unlocked(profile, id)
	var h: HBoxContainer = UiBuild.hbox(16)
	var title: Label = UiBuild.label(MusicCatalog.display_key(id), UiBuild.SUBHEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(title)
	var status: Label = UiBuild.label(&"", &"" if unlocked else UiBuild.DIM)
	status.name = "Status"
	status.text = status_text(id, unlocked)
	h.add_child(status)
	status_labels[id] = status
	var b: Button = UiBuild.button(&"ui.jukebox.play")
	b.name = "Play"
	b.custom_minimum_size = Vector2(200, 0)
	b.disabled = director == null or not unlocked
	b.pressed.connect(play.bind(id))
	h.add_child(b)
	play_buttons[id] = b
	var panel: PanelContainer = UiBuild.panel(h)
	panel.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.8)
	return panel


## "Unlocked", or "Locked: Notoriety VII" (rank from the Notoriety table), or plain "Locked".
static func status_text(id: StringName, unlocked: bool) -> String:
	if unlocked:
		return UiText.t(&"ui.jukebox.unlocked")
	var rank: int = MusicCatalog.unlock_rank(id)
	if rank <= 0:
		return UiText.t(&"ui.jukebox.locked")
	return UiText.t(&"ui.jukebox.locked_rank", {"rank": Notoriety.roman(rank)})


func _refresh_state() -> void:
	stop_button.disabled = now_playing == &""
	if now_playing == &"":
		now_label.text = UiText.t(&"ui.jukebox.idle")
	else:
		now_label.text = UiText.t(&"ui.jukebox.now_playing", {"name": UiText.t(MusicCatalog.display_key(now_playing))})


func _on_hidden_check() -> void:
	if not is_visible_in_tree():
		stop()
