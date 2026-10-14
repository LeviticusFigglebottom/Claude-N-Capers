## Lead sweep (Options and settings persistence, windowed): three phases, each its own process, so the
## settings really come back from disk:
##   set    Options (the real screen) -> audio / video / FOV / sensitivities / subtitles / palette + rebind
##          mask_up to K -> Apply (saved to user://options_sweep/settings.cfg)
##   check  a fresh game: every value back and applied (AudioServer buses, InputMap, camera FOV), the HUD's
##          mask-up prompt shows the rebound key, pause -> Options -> back mid-heist with the tree never paused
##          and the heist clock running; then Reset Tab on every tab + Reset All Bindings -> Apply
##   reset  a fresh game: everything back at its defaults
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --resolution 1280x720 --script res://tests/b/render/options_capture.gd -- <out_dir> set|check|reset
## Prints "OPT ..." lines (PASS / FAIL per check) and saves PNGs to <out_dir>.
extends SceneTree
## Launcher only: the worker (uses autoloads) is loaded after the first frame.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/options_capture_worker.gd"))
	root.add_child(w)
