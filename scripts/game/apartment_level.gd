extends Node3D

@export var next_level_path: String = ""

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD

var _day_complete: bool = false

const DAY_TWO_LETTERS := [
	{
		"id": "apt_letter_01",
		"sender_name": "City Utilities",
		"recipient_name": "A. Martin",
		"address_line": "102 Elmwood Towers",
		"message": "",
		"correct_house_id": "apt_102",
		"difficulty": 1,
	},
	{
		"id": "apt_letter_02",
		"sender_name": "Online Shop",
		"recipient_name": "B. Patel",
		"address_line": "203 Elmwood Towers",
		"message": "",
		"correct_house_id": "apt_203",
		"difficulty": 1,
	},
	{
		"id": "apt_letter_03",
		"sender_name": "Friends Forever",
		"recipient_name": "C. Nguyen",
		"address_line": "301 Elmwood Towers",
		"message": "",
		"correct_house_id": "apt_301",
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
