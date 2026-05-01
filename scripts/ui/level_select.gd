extends Control
## Level selector for the side-scroller mode. Two worlds — Neighborhood and
## Apartment — each list their levels as buttons. Routes back to the start
## screen via the Back button.
##
## Levels are listed inline rather than scanned from disk so an empty stub
## scene (e.g. neighborhood_01_01) doesn't show up as a broken option.

const WORLDS := [
	{
		"name": "Neighborhood",
		"levels": [
			{ "label": "1-1  Willis Street",    "path": "res://scenes/levels/neighborhood/neighborhood_00_01/neighborhood_00_01.tscn" },
			{ "label": "1-2  Bluewater Drive",  "path": "res://scenes/levels/neighborhood/neighborhood_00_02/neighborhood_00_02.tscn" },
			{ "label": "1-3  Elmwood Avenue",   "path": "res://scenes/levels/neighborhood/neighborhood_00_03/neighborhood_00_03.tscn" },
			{ "label": "2-1  Sunpetal Road",    "path": "res://scenes/levels/neighborhood/neighborhood_01_02/neighborhood_01_02.tscn" },
			{ "label": "2-2  Juniper Crescent", "path": "res://scenes/levels/neighborhood/neighborhood_01_03/neighborhood_01_03.tscn" },
			{ "label": "2-3  Maple Street",     "path": "res://scenes/levels/neighborhood/neighborhood_01_04/neighborhood_01_04.tscn" },
		],
	},
	{
		"name": "Apartment",
		"levels": [
			{ "label": "1-1  Gomorda Drive",    "path": "res://scenes/levels/apartment/apartment_01/apartment_01.tscn" },
		],
	},
]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%BackButton.pressed.connect(_on_back_pressed)
	_populate()


func _populate() -> void:
	var first_button: Button = null
	for world in WORLDS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

		var header := Label.new()
		header.text = world["name"]
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 28)
		header.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08))
		col.add_child(header)

		for level in world["levels"]:
			var btn := Button.new()
			btn.text = level["label"]
			btn.custom_minimum_size = Vector2(300, 48)
			btn.add_theme_font_size_override("font_size", 18)
			var path: String = level["path"]
			btn.pressed.connect(func(): _on_level_pressed(path))
			col.add_child(btn)
			if first_button == null:
				first_button = btn

		%WorldsRow.add_child(col)

	if first_button:
		first_button.grab_focus()


func _on_level_pressed(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(SortingMode.START_SCREEN_SCENE)
