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


func _process(_delta: float) -> void:
	# Update the HUD prompt based on what the player is looking at. Keeping
	# this in _process (not signal-driven) is fine — the raycast is cheap and
	# the prompt should track head movement instantly.
	var ray: RayCast3D = player.get_node("Camera3D/InteractionRay")
	if ray.is_colliding():
		var hit = ray.get_collider()
		if hit and hit is InteractableObject and hit.enabled:
			hud.set_prompt(hit.prompt_text())
			return
	hud.set_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var ray: RayCast3D = player.get_node("Camera3D/InteractionRay")
		if ray.is_colliding():
			var hit = ray.get_collider()
			if hit and hit is InteractableObject and hit.enabled:
				hit.interact(player)
