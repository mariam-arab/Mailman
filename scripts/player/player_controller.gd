extends CharacterBody3D
## Side-scroll mailman controller.
##
## Movement is constrained to the Z axis so the world reads as a 2D
## side-scroller, but we stay in 3D so we can re-use the existing 3D house,
## mailbox, and tree meshes. The orthographic Camera3D in the level frames the
## player from the side (camera looks along -X).
##
## Inputs (see project.godot):
##   move_left  / move_right  → walk along Z
##   jump                     → jump (gravity always on)
##   interact (E)             → activate the closest InteractableObject
##                              currently inside InteractRange (Area3D)

@export var walk_speed: float = 4.0
@export var jump_velocity: float = 6.0
## Locks the player to a single X plane so they never drift sideways into the
## 3D world. The orthographic camera stays parallel to YZ so depth is hidden.
@export var locked_x: float = 0.0

@onready var interact_range: Area3D = $InteractRange

var _input_active: bool = true


func _ready() -> void:
	# Don't capture the mouse in side-scroll mode — there's nothing to aim.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# Gravity always applies — even on a flat ground, this lets us jump.
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	if _input_active:
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity

		# Map left/right inputs to motion along the world's Z axis. Right (+X
		# screen-space) maps to -Z because the camera looks down -X — pressing
		# right should move the player to screen-right regardless of axis polarity.
		var axis := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		velocity.z = -axis * walk_speed
	else:
		velocity.z = 0.0

	# X is locked. We zero it instead of letting drift accumulate.
	velocity.x = 0.0

	move_and_slide()
	# Hard-snap X back to the lock plane in case a collision nudged us.
	if absf(global_position.x - locked_x) > 0.001:
		global_position.x = locked_x


## Returns the closest enabled InteractableObject within INTERACT_RANGE units.
## Uses a group scan instead of Area3D so it works regardless of physics-layer
## timing or collision-mask mismatches.
const INTERACT_RANGE := 2.5
func closest_interactable():
	var best = null
	var best_dist := INTERACT_RANGE
	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is InteractableObject) or not node.enabled:
			continue
		var d := global_position.distance_to(node.global_position)
		if d < best_dist:
			best = node
			best_dist = d
	return best


## Called by the HUD when inspection opens/closes so A/D carousel keys don't
## also move the player.
func set_input_active(active: bool) -> void:
	_input_active = active
