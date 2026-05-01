extends Node
## Autoload: F1 toggles between the 2D sorting desk and the original 3D
## side-scroller without restarting. The flag in SortingMode is the durable
## source of truth on startup; this hotkey is a session-only override so both
## modes can be compared back-to-back.
##
## Intentionally minimal — it does not touch GameState, does not persist
## anything, and is a no-op outside of the two target scenes.

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_F1:
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var current_path: String = tree.current_scene.scene_file_path
	if current_path == SortingMode.SORTING_DESK_SCENE:
		tree.change_scene_to_file(SortingMode.SIDE_SCROLLER_ENTRY)
	else:
		tree.change_scene_to_file(SortingMode.SORTING_DESK_SCENE)
