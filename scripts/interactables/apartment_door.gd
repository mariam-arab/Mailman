extends "res://scripts/interactables/interactable_object.gd"
class_name ApartmentDoor

@export var house_id: String = ""
@export var house_label: String = ""

@onready var _label: Label3D = $Label if has_node("Label") else null


func _ready() -> void:
	super._ready()
	if _label:
		_label.text = house_label


func prompt_text() -> String:
	if GameState.get_selected_letter() != null:
		return "E: Deliver to %s" % house_label
	return "E: Knock on %s" % house_label


func interact(player: Node) -> void:
	if not enabled:
		return
	if GameState.get_selected_letter() == null:
		return
	GameState.try_deliver(house_id)
