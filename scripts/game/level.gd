extends Node3D
## Top-level coordinator for a neighborhood scene. Holds the player, HUD, and
## all houses/mailboxes. Each frame it asks the player's RayCast3D what's in
## front of the camera, updates the HUD prompt, and routes E presses to the
## targeted interactable.

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD

## The Day 1 letters, assembled in code so we don't depend on .tres files
## existing yet. They reference house_id values that match the mailboxes
## spawned in the scene file.
const DAY_ONE_LETTERS := [
	{
		"id": "letter_01",
		"sender_name": "Fisherman's Digest",
		"sender_address": "14 Harbour Lane, Halifax",
		"recipient_name": "Thomas Heart",
		"address_line": "?? Maple Street",
		"message": "",
		"correct_house_id": "house_312",
		"difficulty": 2,
	},
	{
		"id": "letter_02",
		"sender_name": "Gardener's Digest",
		"sender_address": "8 Greenhouse Row, Burlington",
		"recipient_name": "Linda Michaels",
		"address_line": "?? Maple Street",
		"message": "",
		"correct_house_id": "house_316",
		"difficulty": 1,
	},
	{
		"id": "letter_03",
		"sender_name": "L. Sydney",
		"sender_address": "22 Birchwood Drive, Ottawa",
		"recipient_name": "J. Sydney",
		"address_line": "?? Maple Street",
		"message": "",
		"correct_house_id": "house_314",
		"difficulty": 2,
	},
	{
		"id": "letter_04",
		"sender_name": "XO XO Beauty Hair Salon",
		"sender_address": "5 Glamour Court, Toronto",
		"recipient_name": "M. Hughes",
		"address_line": "315 Maple Street",
		"message": "",
		"correct_house_id": "house_315",
		"difficulty": 1,
	},
	{
		"id": "letter_05",
		"sender_name": "A Friend",
		"sender_address": "— return address withheld —",
		"recipient_name": "K. Lyne",
		"address_line": "313 Maple Street",
		"message": "",
		"correct_house_id": "house_313",
		"difficulty": 1,
	},
	{
		"id": "letter_06",
		"sender_name": "M.",
		"sender_address": "— return address withheld —",
		"recipient_name": "L. Hughes",
		"address_line": "311 Maple Street",
		"message": "",
		"correct_house_id": "house_311",
		"difficulty": 1,
	},
]


func _ready() -> void:
	hud.bind_player(player)
	GameState.start_day(1, _build_day_one_letters())
	_update_camera_transform(1.0)


func _build_day_one_letters() -> Array:
	var letters: Array = []
	for data in DAY_ONE_LETTERS:
		var m := Mail.new()
		m.id = data["id"]
		m.sender_name = data["sender_name"]
		m.sender_address = data["sender_address"]
		m.recipient_name = data["recipient_name"]
		m.address_line = data["address_line"]
		m.message = data["message"]
		m.correct_house_id = data["correct_house_id"]
		m.difficulty = data["difficulty"]
		letters.append(m)
	return letters


## Diorama camera follow. The player still moves on a single gameplay axis,
## but the camera sits above and to the right of the street so the scene reads
## like a miniature paper set instead of a flat side elevation.
@export var camera_follow_smoothing: float = 6.0
@export var camera_position_offset := Vector3(30.0, 10.0, 0.0)
@export var camera_look_offset := Vector3(-30.5, 1.5, 0.0)
@onready var side_camera: Camera3D = $SideCamera


func _process(delta: float) -> void:
	# Update the HUD prompt based on the closest interactable in the player's
	# proximity bubble. Replaces the 3D camera-raycast — a side-scroll player
	# has no aim cursor, so proximity is the natural cue.
	var target = player.closest_interactable() if player.has_method("closest_interactable") else null
	hud.set_prompt(target.prompt_text() if target else "")
	hud.set_nearby_interactable(target)

	_update_camera_transform(delta)


func _update_camera_transform(delta: float) -> void:
	if not side_camera:
		return

	var target_position := Vector3(
		camera_position_offset.x,
		camera_position_offset.y,
		player.global_position.z + camera_position_offset.z
	)
	var weight := clampf(delta * camera_follow_smoothing, 0.0, 1.0)
	side_camera.global_position = side_camera.global_position.lerp(target_position, weight)

	var look_target := Vector3(
		camera_look_offset.x,
		camera_look_offset.y,
		side_camera.global_position.z + camera_look_offset.z
	)
	side_camera.look_at(look_target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var target = player.closest_interactable() if player.has_method("closest_interactable") else null
		if not target:
			return
		if target is Gossip:
			target.interact(player)
		else:
			hud.open_inspection()
