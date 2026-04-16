extends CharacterBody3D
## First-person mailman controller. Slow, deliberate walk — no jump, no sprint,
## no crouch. Mouse captured on start, ESC toggles capture / pauses input.

# Tunable in the inspector. Spec calls for ~3.0 m/s deliberate walk.
@export var walk_speed: float = 3.0
@export var mouse_sensitivity: float = 0.0025
## Footstep cadence in seconds — recalculated when speed changes.
@export var step_interval: float = 0.55
## Subtle head bob — small amplitude on a sine wave keeps it cozy, not jarring.
@export var head_bob_amplitude: float = 0.04
@export var head_bob_frequency: float = 6.0

@onready var camera: Camera3D = $Camera3D
@onready var interaction_ray: RayCast3D = $Camera3D/InteractionRay
@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer

var _camera_base_y: float = 0.0
var _bob_phase: float = 0.0
var _step_timer: float = 0.0
var _mouse_captured: bool = true


func _ready() -> void:
	_camera_base_y = camera.position.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		# Yaw on the body so movement direction follows look direction. Pitch
		# only on the camera, clamped so the player can't flip upside-down.
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))

	if event.is_action_pressed("pause"):
		_toggle_mouse_capture()


func _physics_process(delta: float) -> void:
	# Gravity — even though we don't jump, the player needs to stick to slopes
	# and fall off ledges naturally if the level designer adds them.
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# Transform the 2D input into world-space movement relative to facing.
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction.length() > 0.01:
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	else:
		# No exponential damping — instant stop reads as more deliberate.
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()
	_update_head_bob(delta, direction.length() > 0.01)
	_update_footsteps(delta, direction.length() > 0.01)


func _update_head_bob(delta: float, moving: bool) -> void:
	if moving:
		_bob_phase += delta * head_bob_frequency
		var offset := sin(_bob_phase) * head_bob_amplitude
		camera.position.y = _camera_base_y + offset
	else:
		# Smoothly return to base height when we stop, instead of snapping.
		camera.position.y = lerp(camera.position.y, _camera_base_y, delta * 6.0)
		_bob_phase = 0.0


func _update_footsteps(delta: float, moving: bool) -> void:
	if not moving:
		_step_timer = 0.0
		return
	_step_timer += delta
	if _step_timer >= step_interval:
		_step_timer = 0.0
		if footstep_player and footstep_player.stream:
			footstep_player.pitch_scale = randf_range(0.92, 1.08)
			footstep_player.play()


func _toggle_mouse_capture() -> void:
	_mouse_captured = not _mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE


## Public — used by the mail inspection UI to release the mouse without
## toggling the player's intended state.
func set_input_active(active: bool) -> void:
	_mouse_captured = active
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE
