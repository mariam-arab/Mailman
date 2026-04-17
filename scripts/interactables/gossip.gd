extends "res://scripts/interactables/interactable_object.gd"
class_name Gossip
## Chatty neighbour / NPC. Set speaker_name and intro_lines in the Inspector
## (or via scene-property overrides) so each level can have its own character.

@export var speaker_name: String = "Neighbour"
@export var intro_lines: Array = []
## Portrait colours shown in the dialogue box. cap_color alpha = 0 means no cap.
@export var portrait_skin: Color = Color(0.88, 0.70, 0.54, 1)
@export var portrait_body: Color = Color(0.52, 0.62, 0.44, 1)
@export var portrait_cap:  Color = Color(0.0,  0.0,  0.0,  0.0)

var _talked: bool = false


func prompt_text() -> String:
	return "E: Talk again" if _talked else "E: Talk to %s" % speaker_name


func interact(_player: Node) -> void:
	_talked = true
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_dialogue"):
		var portrait := { "skin": portrait_skin, "body": portrait_body, "cap": portrait_cap }
		hud.open_dialogue(intro_lines, speaker_name, portrait)
