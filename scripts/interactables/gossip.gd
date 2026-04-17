extends "res://scripts/interactables/interactable_object.gd"
class_name Gossip
## Mr. Hughes — a chatty neighbour at the start of the route.
## Interact with E to hear his welcome and hints about the street.

const SPEAKER := "Mr. Hughes"

const LINES := [
	"Morning! New face on the route? Welcome to Maple Street. Name's Hughes, Mr. Gordon Hughes. Lived here thirty years.",
	"Now, most of these neighbours... well. They keep to themselves, some of them. I won't say more.",
	"But my neighbour Tom, heart of gold that one. Very friendly. You'll like him.",
	"Tab opens your mail bag. Drag a letter onto a mailbox slot to deliver.",
	"Right! Off you go. Mind the gardens!",
]

var _talked: bool = false


func prompt_text() -> String:
	return "E: Talk again" if _talked else "E: Talk to neighbour"


func interact(_player: Node) -> void:
	_talked = true
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_dialogue"):
		hud.open_dialogue(LINES, SPEAKER)
