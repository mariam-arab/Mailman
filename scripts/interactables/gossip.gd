extends "res://scripts/interactables/interactable_object.gd"
class_name Gossip
## Chatty neighbour / NPC. Set speaker_name and intro_lines in the Inspector
## (or via scene-property overrides) so each level can have its own character.

@export var speaker_name: String = "Neighbour"
@export var intro_lines: Array = []

var _talked: bool = false


func prompt_text() -> String:
	return "E: Talk again" if _talked else "E: Talk to %s" % speaker_name


func interact(_player: Node) -> void:
	_talked = true
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_dialogue"):
		hud.open_dialogue(intro_lines, speaker_name)
