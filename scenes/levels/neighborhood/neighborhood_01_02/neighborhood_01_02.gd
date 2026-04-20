extends Node3D
## Oakridge day one — Sunpetal Road (houses 735–740).
## Six deliveries with partially-obscured addresses. A neighbourhood kid greets
## the player, hints at using house features as clues, then heads off to join
## her friends at 739. The player uses visible props (boxes, a workshop garage,
## a window-cleaning van, kids' toys) to match senders to houses.

@export var next_level_path: String = "res://scenes/levels/neighborhood/neighborhood_01_03/neighborhood_01_03.tscn"

@onready var player:      CharacterBody3D = $Player
@onready var hud:         CanvasLayer     = $HUD
@onready var gossip:        Gossip        = $Gossip
@onready var side_camera: Camera3D        = $SideCamera
@onready var hi_bubble:   Label3D         = $KidsPlaying739/HiBubble
@onready var kids_root:   Node3D          = $KidsPlaying739

var _day_complete: bool = false
var _kid_walking: bool  = false
var _kid_target_z: float = -0.8  # house 739's Z
const HI_BUBBLE_RADIUS: float = 3.5

# ── letter data ───────────────────────────────────────────────────────────────

const LETTERS := [
	{   # Workshop garage at 736 is the clue.
		"id": "letter_01",
		"sender_name": "Jensen Woodworking Supplies",
		"recipient_name": "Lillian Brooks",
		"address_line": "7?? Sunpetal Road, Oakridge",
		"message": "",
		"correct_house_id": "house_736",
		"difficulty": 1,
	},
	{   # Window-cleaning van parked at 738.
		"id": "letter_02",
		"sender_name": "CrystalClear Window Service",
		"recipient_name": "Arthur C.",
		"address_line": "73? Sunpetal Road, Oakridge",
		"message": "",
		"correct_house_id": "house_738",
		"difficulty": 1,
	},
	{   # Fairview Public School → the kids-playing house, 739.
		"id": "letter_03",
		"sender_name": "Fairview Public School",
		"recipient_name": "Mildred Thompson",
		"address_line": "7??  Sunpetal Road, Oakridge",
		"message": "",
		"correct_house_id": "house_739",
		"difficulty": 1,
	},
	{   # Fully-addressed: 735 Sunpetal. The moving boxes at 735 also fit.
		"id": "letter_04",
		"sender_name": "A. O. Pamela",
		"recipient_name": "H. Jennings",
		"address_line": "735 Sunpetal Road, Oakridge",
		"message": "",
		"correct_house_id": "house_735",
		"difficulty": 1,
	},
	{   # No feature hint — player infers 740 by eliminating the other five.
		"id": "letter_05",
		"sender_name": "Marissa Cole",
		"recipient_name": "George Whitaker",
		"address_line": "7?? Sunpetal Road, Oakridge",
		"message": "",
		"correct_house_id": "house_740",
		"difficulty": 2,
	},
	{   # "73?" narrows to 735–739; everything else is taken, leaving 737.
		"id": "letter_06",
		"sender_name": "Sophie L.",
		"recipient_name": "Evelyn Parker",
		"address_line": "73? Sunpetal Road, Oakridge",
		"message": "",
		"correct_house_id": "house_737",
		"difficulty": 2,
	},
]

const OUTRO_LINES := [
	"Day one on Sunpetal — done and dusted.",
	"Keep at it. The street gets harder from here.",
]

# ── camera ────────────────────────────────────────────────────────────────────

@export var camera_follow_smoothing: float  = 6.0
@export var camera_position_offset: Vector3 = Vector3(17.0, 5.0, 0.0)
@export var camera_look_offset:     Vector3 = Vector3(-30.5, 1.5, 0.0)

# ── lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	hud.bind_player(player)
	GameState.start_day(2, _build_letters())
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
	_maybe_start_kid_walk()
	_update_hi_bubble()


func _update_hi_bubble() -> void:
	if not hi_bubble or not kids_root:
		return
	var dist := player.global_position.distance_to(kids_root.global_position)
	hi_bubble.visible = dist < HI_BUBBLE_RADIUS


func _maybe_start_kid_walk() -> void:
	if _kid_walking or _day_complete:
		return
	if not gossip._talked:
		return
	# Wait until the greeting dialogue has closed.
	var panel := hud.get_node_or_null("DialoguePanel")
	if panel and panel.visible:
		return
	_kid_walking = true
	# Stop in the front yard of 739, offset from the other two kids (at z≈0 and
	# z≈-1.2) and clear of the mailbox (at z≈-0.3) so she doesn't overlap them
	# or look like she's standing on top of the mailbox from the side camera.
	var target_pos := Vector3(-2.2, gossip.global_position.y, _kid_target_z + 1.2)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(gossip, "global_position", target_pos, 6.0)


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
