extends Node3D
## Tutorial level — Elmwood Avenue (houses 1401–1406).
## Six deliveries introducing the core mechanic: some addresses are complete,
## some are partially obscured. Walk up to Supervisor Bauer and press E to begin.

@onready var player:      CharacterBody3D = $Player
@onready var hud:         CanvasLayer     = $HUD
@onready var boss:        Gossip          = $Boss
@onready var side_camera: Camera3D        = $SideCamera

# ── letter data ───────────────────────────────────────────────────────────────

const TUTORIAL_LETTERS := [
	{   # Full address — straightforward.
		"id": "tut_01",
		"sender_name": "— unreadable —",
		"recipient_name": "J. Dubois",
		"address_line": "1401 Elmwood Avenue",
		"message": "",
		"correct_house_id": "house_1401",
		"difficulty": 1,
	},
	{   # Full address — straightforward.
		"id": "tut_02",
		"sender_name": "— unreadable —",
		"recipient_name": "Nina Jane",
		"address_line": "1405 Elmwood Avenue",
		"message": "",
		"correct_house_id": "house_1405",
		"difficulty": 1,
	},
	{   # No recipient name — only the house number.
		"id": "tut_03",
		"sender_name": "— unreadable —",
		"recipient_name": "Resident",
		"address_line": "1403 Elmwood Avenue",
		"message": "",
		"correct_house_id": "house_1403",
		"difficulty": 1,
	},
	{   # Sender is a political party — the "Trust Me" poster on #1402 is a clue.
		"id": "tut_04",
		"sender_name": "Best Political Party",
		"recipient_name": "X. Garcia",
		"address_line": "1402 Elmwood Avenue",
		"message": "",
		"correct_house_id": "house_1402",
		"difficulty": 1,
	},
	{   # House number partially smudged ("XX06") — player infers 1406.
		"id": "tut_05",
		"sender_name": "— unreadable —",
		"recipient_name": "O. Farouk",
		"address_line": "XX06 Elmwood Avenue",
		"message": "",
		"correct_house_id": "house_1406",
		"difficulty": 2,
	},
	{   # No number at all — elimination points to the one remaining house (1404).
		"id": "tut_06",
		"sender_name": "— unreadable —",
		"recipient_name": "Jane Lee",
		"address_line": "Elmwood Avenue",
		"message": "",
		"correct_house_id": "house_1404",
		"difficulty": 2,
	},
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


func _build_letters() -> Array:
	var letters: Array = []
	for data in TUTORIAL_LETTERS:
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
	if event.is_action_pressed("interact"):
		var target = player.closest_interactable() if player.has_method("closest_interactable") else null
		if not target:
			return
		if target is Gossip:
			target.interact(player)
		else:
			hud.open_inspection()
