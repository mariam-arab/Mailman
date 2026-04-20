extends Node3D
## Oakridge day two — Juniper Crescent (houses 138–143).
## Six deliveries with partially-obscured addresses. Ms. Day greets the player
## in front of her red house, gossips about her neighbours, then walks home to
## her kids playing out front at 142. The player uses visible props (moving
## boxes, a woodworking garage, a window-cleaning van, kids' toys) plus Ms.
## Day's hints about Ms. Owens and Mr. Gray to match senders to houses.

@export var next_level_path: String = "res://scenes/levels/neighborhood/neighborhood_01_04/neighborhood_01_04.tscn"

@onready var player:      CharacterBody3D = $Player
@onready var hud:         CanvasLayer     = $HUD
@onready var gossip:        Gossip        = $Gossip
@onready var side_camera: Camera3D        = $SideCamera
@onready var hi_bubble:   Label3D         = $KidsPlaying142/HiBubble
@onready var play_bubble: Label3D         = $KidsPlaying142/PlayBubble
@onready var kids_root:   Node3D          = $KidsPlaying142

var _day_complete: bool = false
var _gossip_walking: bool = false
var _gossip_target_z: float = -0.8  # house 142's Z
const HI_BUBBLE_RADIUS: float = 3.5

# ── letter data ───────────────────────────────────────────────────────────────

const LETTERS := [
	{   # "Grumpy Goose" + Ms. Day's gossip about Mr. Gray's eyesore next door → 143.
		"id": "letter_01",
		"sender_name": "Grumpy Goose Logistics Co.",
		"recipient_name": "Mark Grey",
		"address_line": "1?? Juniper Crescent, Oakridge",
		"message": "",
		"correct_house_id": "house_143",
		"difficulty": 1,
	},
	{   # "M. Chen" → moving boxes at 138.
		"id": "letter_02",
		"sender_name": "Jane E.",
		"recipient_name": "M. Chen",
		"address_line": "1?? Juniper Crescent, Oakridge",
		"message": "",
		"correct_house_id": "house_138",
		"difficulty": 1,
	},
	{   # Mindy Day is the gossip — her red house is 142, where the kids play.
		"id": "letter_03",
		"sender_name": "Priya Nand",
		"recipient_name": "Mindy Day",
		"address_line": "1?? Juniper Crescent, Oakridge",
		"message": "",
		"correct_house_id": "house_142",
		"difficulty": 1,
	},
	{   # Book Nook → window-cleaning van at 141 (easy feature match).
		"id": "letter_04",
		"sender_name": "The Book Nook Care Co.",
		"recipient_name": "Chloe B.",
		"address_line": "1?? Juniper Crescent, Oakridge",
		"message": "",
		"correct_house_id": "house_141",
		"difficulty": 1,
	},
	{   # Fully-addressed 139 — the woodworking garage house.
		"id": "letter_05",
		"sender_name": "Calvin Hurst",
		"recipient_name": "Sophie Duval",
		"address_line": "139 Juniper Crescent, Oakridge",
		"message": "",
		"correct_house_id": "house_139",
		"difficulty": 2,
	},
	{   # J. Owens → 140: Ms. Day mentions Ms. Owens "puts in effort"; by
		# elimination once 138/139/141/142/143 are taken, 140 is the only one left.
		"id": "letter_06",
		"sender_name": "D. K.",
		"recipient_name": "J. Owens",
		"address_line": "1?? Juniper Crescent, Oakridge",
		"message": "",
		"correct_house_id": "house_140",
		"difficulty": 2,
	},
]

const OUTRO_LINES := [
	"All six sorted — nice round on Juniper.",
	"Next street over's waiting. Keep it moving.",
]

# ── camera ────────────────────────────────────────────────────────────────────

@export var camera_follow_smoothing: float  = 6.0
@export var camera_position_offset: Vector3 = Vector3(17.0, 5.0, 0.0)
@export var camera_look_offset:     Vector3 = Vector3(-30.5, 1.5, 0.0)

# ── lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	hud.bind_player(player)
	GameState.start_day(3, _build_letters())
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
	_maybe_start_gossip_walk()
	_update_kid_bubbles()


func _update_kid_bubbles() -> void:
	if not kids_root:
		return
	var near := player.global_position.distance_to(kids_root.global_position) < HI_BUBBLE_RADIUS
	if hi_bubble:
		hi_bubble.visible = near
	if play_bubble:
		play_bubble.visible = near


func _maybe_start_gossip_walk() -> void:
	if _gossip_walking or _day_complete:
		return
	if not gossip._talked:
		return
	var panel := hud.get_node_or_null("DialoguePanel")
	if panel and panel.visible:
		return
	_gossip_walking = true
	# Walk back to her own front yard at 142, offset from the kids and mailbox
	# so she doesn't overlap them from the side camera.
	var target_pos := Vector3(-2.2, gossip.global_position.y, _gossip_target_z + 1.2)
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
