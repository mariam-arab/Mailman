extends Node3D

@export var next_level_path: String = ""

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD

var _day_complete: bool = false

const DAY_TWO_LETTERS := [
	{
		"id": "letter_01",
		"sender_name": "Banana Repair Services Inc.",
		"recipient_name": "H. Klyne",
		"address_line": "Apt. 303, 131 Gomorda Drive, Oakridge",
		"message": "",
		"correct_house_id": "apt_303",
		"difficulty": 2,
	},
	{
		"id": "letter_02",
		"sender_name": "Field & Feather",
		"recipient_name": "A. Leone",
		"address_line": "131 Gomorda Drive, Oakridge",
		"message": "Something to Chirp About.",
		"correct_house_id": "apt_203",
		"difficulty": 1,
	},
	{
		"id": "letter_03",
		"sender_name": "Maple Trust Bank",
		"recipient_name": "M. Michaels",
		"address_line": "Apt. X01, 131 Gomorda Drive, Oakridge",
		"message": "",
		"correct_house_id": "apt_101",
		"difficulty": 2,
	},
	{
		"id": "letter_04",
		"sender_name": "SilentRoom Depot",
		"recipient_name": "Liam G.",
		"address_line": "Apt. X01, 131 Gomorda Drive, Oakridge",
		"message": "Earplugs enclosed.",
		"correct_house_id": "apt_201",
		"difficulty": 1,
	},
	{
		"id": "letter_05",
		"sender_name": "Mom",
		"recipient_name": "Kathy Higgs",
		"address_line": "Apt. 302, 131 Gomorda Drive, Oakridge",
		"message": "",
		"correct_house_id": "apt_302",
		"difficulty": 1,
	},
	{
		"id": "letter_06",
		"sender_name": "Daniel Singh",
		"recipient_name": "M. Lyne",
		"address_line": "Apt. 301, 131 Gomorda Drive, Oakridge",
		"message": "",
		"correct_house_id": "apt_301",
		"difficulty": 1,
	},
	{
		"id": "letter_07",
		"sender_name": "Northshore LandLord Association",
		"recipient_name": "To The Resident",
		"address_line": "131 Gomorda Drive, Oakridge",
		"message": "",
		"correct_house_id": "apt_102",
		"difficulty": 1,
	},
	{
		"id": "letter_08",
		"sender_name": "M. Lopez",
		"recipient_name": "A. Gene",
		"address_line": "131 Gomorda Drive, Oakridge",
		"message": "",
		"correct_house_id": "apt_103",
		"difficulty": 1,
	},
	{
		"id": "letter_09",
		"sender_name": "Dr. Nina P.",
		"recipient_name": "M. Hunter",
		"address_line": "Apt. 131, Gomorda Drive, Oakridge",
		"message": "",
		"correct_house_id": "apt_202",
		"difficulty": 1,
	},
]


func _ready() -> void:
	hud.bind_player(player)
	GameState.start_day(2, _build_day_two_letters())
	_update_camera_transform(1.0)
	GameState.day_ended.connect(_on_day_ended)


func _on_day_ended(_day: int, _results: Array) -> void:
	_day_complete = true


func _build_day_two_letters() -> Array:
	var letters: Array = []
	for data in DAY_TWO_LETTERS:
		var m := Mail.new()
		m.id = data["id"]
		m.sender_name = data["sender_name"]
		m.recipient_name = data["recipient_name"]
		m.address_line = data["address_line"]
		m.message = data["message"]
		m.correct_house_id = data["correct_house_id"]
		m.difficulty = data["difficulty"]
		letters.append(m)
	return letters


@export var camera_follow_smoothing: float = 6.0
@export var camera_position_offset := Vector3(10.0, 2.5, 0.0)
@export var camera_look_offset := Vector3(-10.5, 0.5, 0.0)
@onready var side_camera: Camera3D = $SideCamera


func _process(delta: float) -> void:
	var target = player.closest_interactable() if player.has_method("closest_interactable") else null
	hud.set_prompt(target.prompt_text() if target else "")
	hud.set_nearby_interactable(target)
	_update_camera_transform(delta)


func _update_camera_transform(delta: float) -> void:
	if not side_camera:
		return
	var target_position := Vector3(
		camera_position_offset.x,
		player.global_position.y + camera_position_offset.y,
		player.global_position.z + camera_position_offset.z
	)
	var weight := clampf(delta * camera_follow_smoothing, 0.0, 1.0)
	side_camera.global_position = side_camera.global_position.lerp(target_position, weight)
	var look_target := Vector3(
		camera_look_offset.x,
		player.global_position.y + camera_look_offset.y,
		side_camera.global_position.z + camera_look_offset.z
	)
	side_camera.look_at(look_target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if _day_complete and event.is_action_pressed("interact"):
		if next_level_path != "":
			get_tree().change_scene_to_file(next_level_path)
		return
	if event.is_action_pressed("interact"):
		var target = player.closest_interactable() if player.has_method("closest_interactable") else null
		if not target:
			return
		target.interact(player)
