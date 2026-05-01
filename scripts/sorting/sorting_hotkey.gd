extends Node
## Autoload: F1 toggles between the 2D sorting desk and the 3D side-scroller
## without restarting; F2 returns to the start screen. Lets both modes be
## compared back-to-back without quitting to the menu first.
##
## Intentionally minimal — it does not touch GameState, does not persist
## anything, and is a no-op outside of the target scenes.

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	match event.keycode:
		KEY_F1:
			_toggle_mode(tree)
		KEY_F2:
			tree.change_scene_to_file(SortingMode.START_SCREEN_SCENE)


func _toggle_mode(tree: SceneTree) -> void:
	var current_path: String = tree.current_scene.scene_file_path
	if current_path == SortingMode.SORTING_DESK_SCENE:
		tree.change_scene_to_file(SortingMode.SIDE_SCROLLER_ENTRY)
	else:
		tree.change_scene_to_file(SortingMode.SORTING_DESK_SCENE)
