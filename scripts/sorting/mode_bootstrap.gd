extends Node
## Top-level entry scene. Reads SortingMode.FLAG and swaps itself out for the
## appropriate real scene at startup. Also handles the F1 hotkey to toggle
## between modes at runtime for A/B comparison.
##
## Exists so project.godot's main_scene can stay pointed at a single file —
## no edits needed when flipping the experiment on/off.

func _ready() -> void:
	call_deferred("_enter_mode", SortingMode.FLAG)


func _enter_mode(mode: String) -> void:
	match mode:
		SortingMode.MODE_SORTING_DESK_2D:
			get_tree().change_scene_to_file(SortingMode.SORTING_DESK_SCENE)
		SortingMode.MODE_SIDE_SCROLLER_3D, _:
			get_tree().change_scene_to_file(SortingMode.SIDE_SCROLLER_ENTRY)


## F1 flips to the other mode's entry scene without editing the flag. The flag
## itself is the source of truth on startup; F1 is session-only.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			var tree := get_tree()
			if tree == null:
				return
			var current_path: String = tree.current_scene.scene_file_path if tree.current_scene else ""
			if current_path == SortingMode.SIDE_SCROLLER_ENTRY:
				tree.change_scene_to_file(SortingMode.SORTING_DESK_SCENE)
			else:
				tree.change_scene_to_file(SortingMode.SIDE_SCROLLER_ENTRY)
