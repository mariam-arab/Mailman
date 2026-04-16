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


func _ready() -> void:
	# Don't capture the mouse in side-scroll mode — there's nothing to aim.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# Gravity always applies — even on a flat ground, this lets us jump.
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Map left/right inputs to motion along the world's Z axis. Right (+X
	# screen-space) maps to -Z because the camera looks down -X — pressing
	# right should move the player to screen-right regardless of axis polarity.
	var axis := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	velocity.z = -axis * walk_speed
	# X is locked. We zero it instead of letting drift accumulate.
	velocity.x = 0.0

	move_and_slide()
	# Hard-snap X back to the lock plane in case a collision nudged us.
	if absf(global_position.x - locked_x) > 0.001:
		global_position.x = locked_x


## Returns the closest InteractableObject currently inside the player's
## interact range, or null if nothing is in reach. Used by the level script to
## drive the HUD prompt and route E presses.
func closest_interactable():
	var best = null
	var best_dist := INF
	for body in interact_range.get_overlapping_bodies():
		if body is InteractableObject and body.enabled:
			var d := global_position.distance_to(body.global_position)
			if d < best_dist:
				best = body
				best_dist = d
	return best


## Compatibility shim for the HUD's mouse-release call. In 2D mode we don't
## capture the mouse, so this is a no-op — the HUD calls it on inspection
## open/close and on day-end, and we want the API to match the 3D version.
func set_input_active(_active: bool) -> void:
	pass
