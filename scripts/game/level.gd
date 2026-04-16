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
		"sender_name": "Boulangerie Saint-Laurent",
		"sender_address": "12 Rue du Pain, Trois-Rivières",
		"address_line": "?? Rue de l'Érable / Maple Street",
		"recipient_description":
			"For the one who always smells like cinnamon and butter.",
		"clue_text":
			"Pour Madame — votre tarte aux pommes habituelle, livrée avant qu'elle ne refroidisse. — J.B.",
		"correct_house_id": "house_a",
		"difficulty": 1,
	},
	{
		"id": "letter_02",
		"sender_name": "Habs Equipment Co.",
		"sender_address": "440 Rue Sainte-Catherine, Montréal",
		"address_line": "?? Rue de l'Érable / Maple Street",
		"recipient_description":
			"To the household that never seems to take their skates off.",
		"clue_text":
			"Replacement laces enclosed. Good luck at the regional tournament next weekend!",
		"correct_house_id": "house_b",
		"difficulty": 1,
	},
	{
		"id": "letter_03",
		"sender_name": "Université Laval — Department of Astronomy",
		"sender_address": "2325 Rue de l'Université, Québec",
		"address_line": "?? Rue de l'Érable / Maple Street",
		"recipient_description":
			"For the gentleman who watches the sky from his upper window.",
		"clue_text":
			"Professor — the new lens you ordered has arrived. Mind the packaging.",
		"correct_house_id": "house_e",
		"difficulty": 2,
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
		m.address_line = data["address_line"]
		m.recipient_description = data["recipient_description"]
		m.clue_text = data["clue_text"]
		m.correct_house_id = data["correct_house_id"]
		m.difficulty = data["difficulty"]
		letters.append(m)
	return letters


## Diorama camera follow. The player still moves on a single gameplay axis,
## but the camera sits above and to the right of the street so the scene reads
## like a miniature paper set instead of a flat side elevation.
@export var camera_follow_smoothing: float = 6.0
@export var camera_position_offset := Vector3(17.0, 5.0, 0.0)
@export var camera_look_offset := Vector3(-30.5, 1.5, 0.0)
@onready var side_camera: Camera3D = $SideCamera


func _process(delta: float) -> void:
	# Update the HUD prompt based on the closest interactable in the player's
	# proximity bubble. Replaces the 3D camera-raycast — a side-scroll player
	# has no aim cursor, so proximity is the natural cue.
	var target = player.closest_interactable() if player.has_method("closest_interactable") else null
	if target:
		hud.set_prompt(target.prompt_text())
	else:
		hud.set_prompt("")

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
		if target:
			target.interact(player)
