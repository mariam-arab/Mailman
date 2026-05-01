extends Node3D
## Oakridge — Maple Street (houses 311–316).
## Six identical-facade houses; only #316 stands out, with a planter, potted
## plants, wheelbarrow and other gardener's kit. Mr. Hughes — the bald old
## neighbour — greets the player, warns them off "some houses" on the street
## and puts in a good word for his next-door neighbour Tom.

@export var next_level_path: String = ""

@onready var player:      CharacterBody3D = $Player
@onready var hud:         CanvasLayer     = $HUD
@onready var gossip:      Gossip          = $Gossip
@onready var side_camera: Camera3D        = $SideCamera

var _day_complete: bool = false

# ── letter data ───────────────────────────────────────────────────────────────

const LETTERS := [
	{   # No house-specific clue — narrow by elimination once Linda/Hughes/Sydney are placed.
		"id": "letter_01",
		"sender_name": "Sport Angling Weekly",
		"recipient_name": "Marcus Harth",
		"address_line": "?? Maple Street, Oakridge",
		"message": "Reel news for real fishermen.",
		"correct_house_id": "house_312",
		"difficulty": 2,
	},
	{   # The planter, potted plants and gardener's kit at #316 are the tell.
		"id": "letter_02",
		"sender_name": "Gardener's Digest",
		"recipient_name": "Linda Michaels",
		"address_line": "?? Maple Street, Oakridge",
		"message": "Fresh Ideas Inside.",
		"correct_house_id": "house_316",
		"difficulty": 1,
	},
	{   # Family mail between Sydneys — pure elimination, no visual hint.
		"id": "letter_03",
		"sender_name": "L. Sydney",
		"recipient_name": "J. Sydney",
		"address_line": "?? Maple Street, Oakridge",
		"message": "",
		"correct_house_id": "house_314",
		"difficulty": 2,
	},
	{   # Fully addressed: M. Hughes at 315.
		"id": "letter_04",
		"sender_name": "XO XO Beauty Hair Salon",
		"recipient_name": "M. Hughes",
		"address_line": "315 Maple Street, Oakridge",
		"message": "Come Again Soon!",
		"correct_house_id": "house_315",
		"difficulty": 1,
	},
	{
		"id": "letter_05",
		"sender_name": "A Friend",
		"recipient_name": "K. Lyne",
		"address_line": "313 Maple Street, Oakridge",
		"message": "",
		"correct_house_id": "house_313",
		"difficulty": 1,
	},
	{
		"id": "letter_06",
		"sender_name": "M.",
		"recipient_name": "L. Hughes",
		"address_line": "311 Maple Street, Oakridge",
		"message": "",
		"correct_house_id": "house_311",
		"difficulty": 1,
	},
]

const OUTRO_LINES := [
	"Another round on Maple Street — done.",
	"Rest up. More of Oakridge tomorrow.",
]

# ── camera ────────────────────────────────────────────────────────────────────

@export var camera_follow_smoothing: float  = 6.0
@export var camera_position_offset: Vector3 = Vector3(17.0, 5.0, 0.0)
@export var camera_look_offset:     Vector3 = Vector3(-30.5, 1.5, 0.0)

# ── lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	hud.bind_player(player)
	GameState.start_day(4, _build_letters())
	_update_camera_transform(1.0)
	GameState.day_ended.connect(_on_day_ended)


func _on_day_ended(_day: int, _results: Array) -> void:
	_day_complete = true
	var portrait := {
		"skin": gossip.portrait_skin,
		"body": gossip.portrait_body,
		"cap":  gossip.portrait_cap,
	}
	hud.open_dialogue(OUTRO_LINES, gossip.speaker_name, portrait)


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

# ── process ───────────────────────────────────────────────────────────────────

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
