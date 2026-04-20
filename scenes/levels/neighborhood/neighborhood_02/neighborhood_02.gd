extends Node3D
## Neighbourhood level — Bluewater Drive, Tutoreal (houses 321–324).
## Four identical-looking houses; the puzzle is the address smudges and
## missing recipient names, not the houses themselves. Boss intro previews
## the "mail comes in rough shape" quirk before the first delivery.

@export var next_level_path: String = "res://scenes/levels/neighborhood/neighborhood_03/neighborhood_03.tscn"

@onready var player:      CharacterBody3D = $Player
@onready var hud:         CanvasLayer     = $HUD
@onready var boss:        Gossip          = $Boss
@onready var side_camera: Camera3D        = $SideCamera

var _day_complete: bool = false

const LETTERS := [
	{
		"id": "letter_01",
		"sender_name": "J. Pike",
		"recipient_name": "XXXX Costa",
		"address_line": "322 Bluewater Drive, Tutoreal",
		"message": "",
		"correct_house_id": "house_322",
		"difficulty": 1,
	},
	{
		"id": "letter_02",
		"sender_name": "Marta ZXXXX",
		"recipient_name": "Owen Fischer",
		"address_line": "321 Bluewater Drive, Tutoreal",
		"message": "",
		"correct_house_id": "house_321",
		"difficulty": 1,
	},
	{
		"id": "letter_03",
		"sender_name": "Victor H.",
		"recipient_name": "S. Blake",
		"address_line": "324 Bluewater Drive, Tutoreal",
		"message": "",
		"correct_house_id": "house_324",
		"difficulty": 1,
	},
	{
		"id": "letter_04",
		"sender_name": "Shark Investors Group",
		"recipient_name": "Daphne Rodes",
		"address_line": "323 Bluewater Drive, Tutoreal",
		"message": "",
		"correct_house_id": "house_323",
		"difficulty": 1,
	},
]

@export var camera_follow_smoothing: float  = 6.0
@export var camera_position_offset: Vector3 = Vector3(17.0, 5.0, 0.0)
@export var camera_look_offset:     Vector3 = Vector3(-30.5, 1.5, 0.0)


func _ready() -> void:
	hud.bind_player(player)
	GameState.start_day(2, _build_letters())
	_update_camera_transform(1.0)
	GameState.day_ended.connect(_on_day_ended)


func _on_day_ended(_day: int, _results: Array) -> void:
	_day_complete = true


func _build_letters() -> Array:
	var letters: Array = []
	for data in LETTERS:
		var m := Mail.new()
		m.id               = data["id"]
		m.sender_name      = data["sender_name"]
		m.recipient_name   = data["recipient_name"]
		m.address_line     = data["address_line"]
		m.message          = data["message"]
		m.correct_house_id = data["correct_house_id"]
		m.difficulty       = data["difficulty"]
		letters.append(m)
	return letters


func _process(delta: float) -> void:
	var target = player.closest_interactable() if player.has_method("closest_interactable") else null
	hud.set_prompt(target.prompt_text() if target else "")
	hud.set_nearby_interactable(target)
	_update_camera_transform(delta)


func _update_camera_transform(delta: float) -> void:
	if not side_camera:
		return
	var target_pos := Vector3(
		camera_position_offset.x,
		camera_position_offset.y,
		player.global_position.z + camera_position_offset.z
	)
	var weight := clampf(delta * camera_follow_smoothing, 0.0, 1.0)
	side_camera.global_position = side_camera.global_position.lerp(target_pos, weight)
	var look_target := Vector3(
		camera_look_offset.x,
		camera_look_offset.y,
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
		if target is Gossip:
			target.interact(player)
		else:
			hud.open_inspection()
