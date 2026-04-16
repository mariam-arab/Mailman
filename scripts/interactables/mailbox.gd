extends "res://scripts/interactables/interactable_object.gd"
class_name Mailbox
## A heritage red Canada Post mailbox in front of a house. Each mailbox knows
## which house it belongs to, so deliveries can be checked against the letter's
## correct_house_id.

## Must match the matching letter's correct_house_id. Examples: "house_a", "house_b".
@export var house_id: String = ""
## Friendly label for HUD prompts ("The Baker", "The Hockey Family"). Optional.
@export var house_label: String = ""

@onready var flag_pivot: Node3D = $FlagPivot if has_node("FlagPivot") else null
@onready var success_sound: AudioStreamPlayer3D = $SuccessSound if has_node("SuccessSound") else null
@onready var reject_sound: AudioStreamPlayer3D = $RejectSound if has_node("RejectSound") else null

var _flag_up: bool = false


func prompt_text() -> String:
	if GameState.get_selected_letter() != null:
		return "E: Deliver letter"
	return "E: Open mailbox"


func interact(player: Node) -> void:
	if not enabled:
		return
	var letter = GameState.get_selected_letter()
	if letter == null:
		# Empty bag — just open the box. The spec calls for no harsh feedback.
		return
	var was_correct: bool = (letter.correct_house_id == house_id)
	if was_correct:
		_play_success()
	else:
		_play_reject()
	# GameState.try_deliver mutates the bag and emits letter_delivered, which
	# the HUD listens to. We call this AFTER the local SFX so the audio cue
	# lands at the same beat as the HUD update.
	GameState.try_deliver(house_id)


func _play_success() -> void:
	if success_sound:
		success_sound.play()
	if flag_pivot and not _flag_up:
		# Flip the flag up — small tween reads as a satisfying mechanical clunk.
		var tween := create_tween()
		tween.tween_property(flag_pivot, "rotation_degrees:z", 90.0, 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_flag_up = true


func _play_reject() -> void:
	if reject_sound:
		reject_sound.play()
