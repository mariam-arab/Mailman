extends Control
## Start screen — pick between the 3D side-scroller and the 2D sorting desk.
## Both modes are reachable mid-session via the SortingHotkey autoload
## (F1 toggles between them, F2 returns here).

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%SideScrollerButton.pressed.connect(_on_side_scroller_pressed)
	%SortingButton.pressed.connect(_on_sorting_pressed)
	%SideScrollerButton.grab_focus()


func _on_side_scroller_pressed() -> void:
	get_tree().change_scene_to_file(SortingMode.SIDE_SCROLLER_ENTRY)


func _on_sorting_pressed() -> void:
	get_tree().change_scene_to_file(SortingMode.SORTING_DESK_SCENE)
