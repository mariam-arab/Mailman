extends Node3D
## Final Tutor-Yale tutorial — Elmwood Avenue (houses 1401–1406).
## Six deliveries where senders, names, and house numbers are each partly
## missing. Bauer briefs the player, the player works it out, then Bauer hands
## them off to Oakridge on their own.

@export var next_level_path: String = "res://scenes/levels/neighborhood/neighborhood_05/neighborhood_05.tscn"

@onready var player:      CharacterBody3D = $Player
@onready var hud:         CanvasLayer     = $HUD
@onready var boss:        Gossip          = $Boss
@onready var side_camera: Camera3D        = $SideCamera

var _day_complete: bool = false

# ── letter data ───────────────────────────────────────────────────────────────

const LETTERS := [
	{
		"id": "letter_01",
		"sender_name": "Harper’s Department Store",
		"recipient_name": "J. Dubois",
		"address_line": "1401 Elmwood Avenue, Tutor-Yale",
		"message": "",
		"correct_house_id": "house_1401",
		"difficulty": 1,
	},
	{
		"id": "letter_02",
		"sender_name": "Harborview Office Equipment",
		"recipient_name": "Nina Jane",
		"address_line": "1405 Elmwood Avenue, Tutor-Yale",
		"message": "",
		"correct_house_id": "house_1405",
		"difficulty": 1,
	},
	{
		"id": "letter_03",
		"sender_name": "Clara W.",
		"recipient_name": "Sarah L.",
		"address_line": "1403 Elmwood Avenue, Tutor-Yale",
		"message": "",
		"correct_house_id": "house_1403",
		"difficulty": 1,
	},
	{   # Recipient's first name is obscured; the "Trust Me" poster on #1402 hints at a political-party sender.
		"id": "letter_04",
		"sender_name": "Best Political Party",
		"recipient_name": "???? Garcia",
		"address_line": "1402 Elmwood Avenue, Tutoreal",
		"message": "Thank You for Your Support",
		"correct_house_id": "house_1402",
		"difficulty": 1,
	},
	{   # House number partially smudged ("XX06") — player infers 1406.
		"id": "letter_05",
		"sender_name": "Sugarplum Bakery",
		"recipient_name": "O. Farouk",
		"address_line": "XX06 Elmwood Avenue, Tutoreal",
		"message": "",
		"correct_house_id": "house_1406",
		"difficulty": 2,
	},
	{   # No number at all — elimination points to the one remaining house (1404).
		"id": "letter_06",
		"sender_name": "Albert Finley",
		"recipient_name": "Jane Lee",
		"address_line": "Elmwood Avenue, Tutoreal",
		"message": "",
		"correct_house_id": "house_1404",
		"difficulty": 2,
	},
]

const OUTRO_LINES := [
	"That's the lot — nicely done. You've passed Tutor-Yale.",
	"From here you're on your own. Next stop's Oakridge. Good luck out there.",
]

# ── camera ────────────────────────────────────────────────────────────────────

@export var camera_follow_smoothing: float  = 6.0
@export var camera_position_offset: Vector3 = Vector3(17.0, 5.0, 0.0)
@export var camera_look_offset:     Vector3 = Vector3(-30.5, 1.5, 0.0)

# ── lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	hud.bind_player(player)
	GameState.start_day(1, _build_letters())
	_update_camera_transform(1.0)
	GameState.day_ended.connect(_on_day_ended)


func _on_day_ended(_day: int, _results: Array) -> void:
	_day_complete = true
	var portrait := {
		"skin": boss.portrait_skin,
		"body": boss.portrait_body,
		"cap":  boss.portrait_cap,
	}
	hud.open_dialogue(OUTRO_LINES, boss.speaker_name, portrait)


func _build_letters() -> Array:
	var letters: Array = []
	for data in LETTERS:
		var m := Mail.new()
		m.id             = data["id"]
		m.sender_name    = data["sender_name"]
		m.recipient_name = data["recipient_name"]
		m.address_line   = data["address_line"]
		m.message        = data["message"]
		m.correct_house_id = data["correct_house_id"]
		m.difficulty     = data["difficulty"]
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
