## PQ-B-22 / PQ-B-23 / PQ-B-24: contrast check that needs a real renderer (not run by the headless runner).
## Renders at 1280x720 into a SubViewport (own_world_3d, UPDATE_ALWAYS) and, per visible label, compares
## the brightest and darkest 3% of the pixels inside it (text vs outline / shadow / panel): WCAG ratio
## >= MIN_RATIO passes.
##   hud   : HUD (MockHudModel stealth + loud state) over dark, mid, bright and white backdrops.
##   menus : MenuFlow over its real 3D safehouse: hub, armory loadout, payday cards.
## Run (Env D's flags; from the clone root, NOT --headless, one render at a time):
##   flock /workspace/cnc-team/render.lock xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot \
##     --audio-driver Dummy --path game --script res://tests/b/render/hud_contrast_capture.gd -- hud|menus
## Prints "CONTRAST FAIL ..." lines and "CONTRAST PASS/FAIL", saves PNGs to user://contrast_<shot>.png,
## exits 0 / 1. Forward+ falls back to llvmpipe; `--rendering-driver opengl3` also works.
extends SceneTree
## Launcher only: autoloads are not compiled into a --script SceneTree, so the worker (which uses
## EventBus / UiText / ...) is loaded after the first frame, when the autoloads are in the tree.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var w: Node = Node.new()
	w.set_script(load("res://tests/b/render/contrast_worker.gd"))
	root.add_child(w)
